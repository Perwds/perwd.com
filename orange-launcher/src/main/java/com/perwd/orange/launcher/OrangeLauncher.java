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
        try {
            System.exit(run(args));
        } catch (LauncherException | IllegalArgumentException e) {
            Log.error(e.getMessage(), null);
            System.exit(1);
        }
    }

    static int run(String[] args) throws Exception {
        List<String> argList = new ArrayList<>(Arrays.asList(args));
        boolean dryRun = argList.remove("--dry-run");

        Path home = Path.of("").toAbsolutePath();
        Path selfJar = selfJar();
        OrangeConfig config = OrangeConfig.loadOrCreate(home.resolve("orange.yml"));

        Path serverJar = ServerJarLocator.locate(home, config.serverJar(), selfJar);
        ServerType type = ServerType.detect(serverJar);
        long heapMb = JvmFlags.heapMegabytes(config.memory());
        String gc = JvmFlags.resolveGc(config.gc(), heapMb);

        Log.info("Orange " + version() + " | server: " + serverJar.getFileName() + " (" + type.displayName() + ")"
                + " | heap: " + heapMb + " MB | gc: " + gc + " | profile: " + config.profile().id()
                + " | ping tolerance: " + config.pingTolerance().id());

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

        List<String> command = new ArrayList<>();
        command.add(javaBinary());
        command.addAll(JvmFlags.build(heapMb, gc, type));
        if (config.agent() && selfJar != null) {
            command.add("-javaagent:" + selfJar);
            command.add("-Dorange.home=" + home);
        }
        command.addAll(config.extraJvmArgs());
        command.add("-jar");
        command.add(serverJar.toString());
        command.addAll(config.serverArgs());
        command.addAll(argList);

        if (dryRun) {
            Log.info("Dry run, would execute:\n  " + String.join(" ", command));
            return 0;
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
