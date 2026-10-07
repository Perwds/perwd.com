package com.perwd.orange.launcher;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Locale;
import java.util.Set;
import java.util.stream.Stream;

/**
 * A server fills its folder with a world, logs, plugins and configs. If orange.jar was started
 * from somewhere like Downloads, offer to move into a folder of its own first.
 */
final class ServerFolder {
    private static final Set<String> SHARED_FOLDERS = Set.of("downloads", "desktop", "documents", "home", "users");
    private static final String FOLDER_NAME = "Orange Server";

    private ServerFolder() {
    }

    /** Returns the server's exit code if it ran from a new folder, or -1 to carry on here. */
    static int offerOwnFolder(Path home, Path selfJar, String javaBinary, String[] args) throws IOException, InterruptedException {
        if (selfJar == null || Files.exists(home.resolve("server.properties")) || Files.exists(home.resolve("world"))) {
            return -1; // already a server folder
        }
        String name = home.getFileName() == null ? "" : home.getFileName().toString().toLowerCase(Locale.ROOT);
        long otherFiles;
        try (Stream<Path> files = Files.list(home)) {
            otherFiles = files.filter(p -> !p.getFileName().toString().toLowerCase(Locale.ROOT).matches(
                    "orange.*|start\\.(bat|sh|command)|eula\\.txt|\\.orange")).count();
        }
        if (!SHARED_FOLDERS.contains(name) && otherFiles < 15) {
            return -1;
        }
        Path target = home.resolve(FOLDER_NAME);
        Log.warn("orange.jar is in " + home + ", which has other files in it. A server creates a world, logs, plugins");
        Log.warn("and config files next to it, so it's best kept in a folder of its own.");
        if (!Terminal.interactive()) {
            Log.warn("Move orange.jar into an empty folder to keep things tidy. Starting here for now.");
            return -1;
        }
        if (!Terminal.ask("Create \"" + target + "\" and run the server there?")) {
            Log.info("OK, running here.");
            return -1;
        }
        Files.createDirectories(target);
        Path newJar = target.resolve(selfJar.getFileName());
        Files.copy(selfJar, newJar, StandardCopyOption.REPLACE_EXISTING);
        Path eula = home.resolve("eula.txt");
        if (Files.exists(eula)) {
            Files.copy(eula, target.resolve("eula.txt"), StandardCopyOption.REPLACE_EXISTING);
        }
        // Bring along a server jar that's lying next to orange.jar, so it isn't downloaded again.
        try (Stream<Path> files = Files.list(home)) {
            for (Path jar : files.filter(f -> f.toString().endsWith(".jar") && !f.equals(selfJar)).toList()) {
                if (ServerType.inspect(jar) != null) {
                    Files.copy(jar, target.resolve(jar.getFileName()), StandardCopyOption.REPLACE_EXISTING);
                    Log.info("Copied " + jar.getFileName() + " into the new folder.");
                }
            }
        }
        Path config = home.resolve("orange.yml");
        if (Files.exists(config)) {
            Files.move(config, target.resolve("orange.yml"), StandardCopyOption.REPLACE_EXISTING);
        }
        Log.info("Created " + target + ". From now on, start the server from there (orange.jar or start script).");
        Log.info("You can delete the orange.jar in " + home + ".");
        java.util.List<String> command = new java.util.ArrayList<>(java.util.List.of(javaBinary, "-jar", newJar.toString()));
        command.addAll(java.util.Arrays.asList(args));
        Process p = new ProcessBuilder(command).directory(target.toFile()).inheritIO().start();
        return p.waitFor();
    }
}
