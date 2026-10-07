package com.perwd.orange.launcher;

import com.perwd.orange.optimizer.ConfigOptimizer;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.TimeUnit;

/**
 * {@code java -jar orange.jar}: tunes the configs, then runs the real server jar in a child JVM
 * with tuned flags and the Orange agent attached.
 */
public final class OrangeLauncher {
    private static volatile Process server;
    private static volatile boolean stopping;

    private OrangeLauncher() {
    }

    public static void main(String[] args) throws Exception {
        Path selfJar = selfJar();
        if (selfJar != null && Terminal.relaunchIfDoubleClicked(selfJar.getParent(), selfJar, javaBinary())) {
            return; // continues in the terminal window
        }
        try {
            System.exit(run(args));
        } catch (LauncherException | IllegalArgumentException e) {
            Log.error(e.getMessage(), null);
            Terminal.showError(e.getMessage());
            System.exit(1);
        }
    }

    static int run(String[] args) throws Exception {
        List<String> argList = new ArrayList<>(Arrays.asList(args));
        boolean dryRun = argList.remove("--dry-run");

        Path selfJar = selfJar();
        // Work next to orange.jar, so double-clicking it from any folder behaves the same.
        Path home = selfJar != null ? selfJar.getParent() : Path.of("").toAbsolutePath();
        if (!dryRun) {
            int exit = ServerFolder.offerOwnFolder(home, selfJar, javaBinary(), argList.toArray(String[]::new));
            if (exit >= 0) {
                return exit;
            }
        }
        OrangeConfig config = OrangeConfig.loadOrCreate(home.resolve("orange.yml"));

        Path serverJar = resolveServerJar(home, config, selfJar, dryRun);
        ServerType type = ServerType.detect(serverJar);
        long heapMb = JvmFlags.heapMegabytes(config.memory());
        String gc = JvmFlags.resolveGc(config.gc(), heapMb);

        Log.info("Orange " + version() + " | server: " + serverJar.getFileName() + " (" + type.displayName() + ")"
                + " | heap: " + heapMb + " MB | gc: " + gc + " | profile: " + config.profile().id()
                + " | ping tolerance: " + config.pingTolerance().id());

        if (!dryRun) {
            Eula.askIfNeeded(home);
        }

        if (Runtime.version().feature() < 25) {
            Log.info("Tip: run Orange on Java 25 (LTS) or newer to enable compact object headers (smaller heap, faster GC).");
        }

        if (config.installPlugin() && type.runsBukkitPlugins() && !dryRun) {
            if (type.family() == ServerType.Family.FOLIA) {
                Log.warn(type.displayName() + " is region-threaded; the Orange plugin isn't Folia-ready yet, so it won't be installed.");
            } else {
                PluginInstaller.install(home);
            }
        }
        new ConfigOptimizer(home, config.profile(), config.pingTolerance(), dryRun).run();

        String java = javaBinary();
        DirectLaunch direct = config.fastStartup() ? DirectLaunch.prepare(home, serverJar, java, dryRun) : null;
        boolean agent = selfJar != null && switch (config.agent()) {
            case "true" -> true;
            case "false" -> false;
            default -> hasMods(home.resolve("orange-mods"));
        };

        List<String> command = new ArrayList<>();
        command.add(java);
        command.addAll(JvmFlags.build(heapMb, gc, type));
        if (direct != null) {
            command.addAll(StartupCache.flags(home, direct, agent ? selfJar : null));
        }
        if (agent) {
            command.add("-javaagent:" + selfJar);
            command.add("-Dorange.home=" + home);
        }
        command.addAll(config.extraJvmArgs());
        if (direct != null) {
            command.add("-cp");
            command.add(direct.classpathString());
            command.add(direct.mainClass());
        } else {
            command.add("-jar");
            command.add(serverJar.toString());
        }
        command.addAll(config.serverArgs());
        command.addAll(argList);

        if (dryRun) {
            Log.info("Dry run, would execute:\n  " + String.join(" ", command));
            return 0;
        }
        Log.info("Starting " + serverJar.getFileName() + ": " + (direct != null ? "direct launch" : "java -jar")
                + ", class cache " + (direct != null ? (Runtime.version().feature() >= 25 ? "AOT" : "AppCDS") : "off")
                + ", agent " + (agent ? "on" : "off"));
        if (System.getenv("ORANGE_DEBUG") != null) {
            Log.info("Command: " + String.join(" ", command));
        }

        Runtime.getRuntime().addShutdownHook(new Thread(OrangeLauncher::stopServer, "orange-shutdown"));
        while (true) {
            server = new ProcessBuilder(command).directory(home.toFile()).inheritIO().start();
            int exit = server.waitFor();
            if (stopping || exit == 0 || !config.autoRestart()) {
                return exit;
            }
            Log.warn("Server exited with code " + exit + ", restarting in 5 seconds (auto-restart is on)...");
            Thread.sleep(5000);
        }
    }

    /** The configured jar, the jar Orange downloaded (updated if allowed), any jar in the folder, or a fresh download. */
    private static Path resolveServerJar(Path home, OrangeConfig config, Path selfJar, boolean dryRun) throws Exception {
        if (!config.serverJar().equalsIgnoreCase("auto")) {
            return ServerJarLocator.locate(home, config.serverJar(), selfJar);
        }
        boolean downloads = !config.download().equals("off");
        if (downloads && !config.download().matches("orange|paper|purpur")) {
            throw new LauncherException("Unknown download '" + config.download() + "' in orange.yml (use orange, paper, purpur or off).");
        }
        ServerDownloader downloader = downloads ? new ServerDownloader(home, config.download(), config.minecraftVersion()) : null;
        Path downloaded = downloader == null ? null : downloader.installed();
        if (downloaded != null) {
            if (dryRun) {
                return downloaded;
            }
            try {
                return downloader.ensure(config.autoUpdate());
            } catch (java.io.IOException e) {
                Log.warn("Couldn't check for server updates (" + e.getMessage() + "); starting " + downloaded.getFileName() + ".");
                return downloaded;
            }
        }
        // Orange downloaded a different server here before (e.g. Paper, before the Orange server
        // existed): switch, but only to the same Minecraft version, since an older version can't
        // safely load a newer world.
        String[] previous = downloader == null ? null : downloader.previousDownload();
        if (previous != null && !dryRun) {
            Path previousJar = home.resolve(previous[2]);
            try {
                if (!downloader.availableVersions().contains(previous[1])) {
                    Log.info("The " + config.download() + " server isn't available for Minecraft " + previous[1]
                            + " yet; keeping " + previous[2] + ".");
                    return previousJar;
                }
                Log.info("Switching from " + previous[2] + " to the " + config.download() + " server (same Minecraft "
                        + previous[1] + "; your world and plugins stay as they are).");
                Path jar = new ServerDownloader(home, config.download(), previous[1]).ensure(false);
                java.nio.file.Files.deleteIfExists(previousJar);
                return jar;
            } catch (java.io.IOException e) {
                Log.warn("Couldn't switch to the " + config.download() + " server (" + e.getMessage() + "); starting "
                        + previous[2] + ".");
                return previousJar;
            }
        }
        try {
            return ServerJarLocator.locate(home, "auto", selfJar);
        } catch (LauncherException noJar) {
            if (downloader == null) {
                throw noJar;
            }
            if (dryRun) {
                throw new LauncherException("No server jar yet; the first real start will download " + config.download() + ".");
            }
            try {
                return downloader.ensure(false);
            } catch (java.io.IOException e) {
                throw new LauncherException("Couldn't download the server (" + e.getMessage() + "). Check the internet "
                        + "connection, or put a server jar next to orange.jar.");
            }
        }
    }

    /** Gives the server time to save worlds when the launcher itself is asked to stop. */
    private static void stopServer() {
        stopping = true;
        Process p = server;
        if (p == null || !p.isAlive()) {
            return;
        }
        try {
            // Ctrl+C already reached the server through the shared terminal; otherwise send SIGTERM.
            if (!p.waitFor(2, TimeUnit.SECONDS)) {
                p.destroy();
            }
            if (!p.waitFor(90, TimeUnit.SECONDS)) {
                Log.warn("Server did not stop within 90 seconds, killing it.");
                p.destroyForcibly();
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }

    private static boolean hasMods(Path dir) {
        try (var files = java.nio.file.Files.list(dir)) {
            return files.anyMatch(p -> p.toString().endsWith(".jar"));
        } catch (java.io.IOException e) {
            return false;
        }
    }

    private static String javaBinary() {
        return ProcessHandle.current().info().command()
                .orElse(Path.of(System.getProperty("java.home"), "bin", "java").toString());
    }

    private static Path selfJar() {
        try {
            Path p = Path.of(OrangeLauncher.class.getProtectionDomain().getCodeSource().getLocation().toURI());
            return p.toString().endsWith(".jar") ? p : null;
        } catch (Exception e) {
            return null;
        }
    }

    static String version() {
        String v = OrangeLauncher.class.getPackage().getImplementationVersion();
        return v == null ? "dev" : v;
    }
}
