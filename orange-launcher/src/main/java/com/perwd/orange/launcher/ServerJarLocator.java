package com.perwd.orange.launcher;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.stream.Stream;

final class ServerJarLocator {
    private ServerJarLocator() {
    }

    static Path locate(Path home, String configured, Path selfJar) throws IOException {
        if (!configured.equalsIgnoreCase("auto")) {
            Path jar = home.resolve(configured);
            if (Files.notExists(jar)) {
                throw new LauncherException("server-jar '" + configured + "' from orange.yml does not exist.");
            }
            return jar;
        }
        List<Path> candidates;
        try (Stream<Path> files = Files.list(home)) {
            candidates = files
                    .filter(p -> p.getFileName().toString().toLowerCase(Locale.ROOT).endsWith(".jar"))
                    .filter(p -> !isSelf(p, selfJar))
                    .filter(p -> !p.getFileName().toString().toLowerCase(Locale.ROOT).startsWith("orange"))
                    // Only real server jars: plugins and mods lying around don't count.
                    .filter(p -> ServerType.inspect(p) != null)
                    // Prefer the most specific fork, then the newest file.
                    .sorted(Comparator.<Path>comparingInt(p -> ServerType.inspect(p).ordinal())
                            .thenComparing(ServerJarLocator::lastModified, Comparator.reverseOrder()))
                    .toList();
        }
        if (candidates.isEmpty()) {
            throw new LauncherException("""
                    No server jar found next to orange.jar.
                      Put a server jar in this folder, for example from:
                        Paper       https://papermc.io/downloads/paper
                        Purpur      https://purpurmc.org/downloads
                        Pufferfish  https://pufferfish.host/downloads
                      or set server-jar in orange.yml.""");
        }
        return candidates.getFirst();
    }

    private static boolean isSelf(Path p, Path selfJar) {
        try {
            return selfJar != null && Files.isSameFile(p, selfJar);
        } catch (IOException e) {
            return false;
        }
    }

    private static long lastModified(Path p) {
        try {
            return Files.getLastModifiedTime(p).toMillis();
        } catch (IOException e) {
            return 0;
        }
    }
}
