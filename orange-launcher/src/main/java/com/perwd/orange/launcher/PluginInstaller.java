package com.perwd.orange.launcher;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.Arrays;

/** Keeps plugins/Orange.jar in sync with the copy embedded in orange.jar. */
final class PluginInstaller {
    private PluginInstaller() {
    }

    static void install(Path home) throws IOException {
        byte[] embedded;
        try (InputStream in = PluginInstaller.class.getResourceAsStream("/META-INF/orange/orange-plugin.jar")) {
            if (in == null) {
                Log.warn("This orange.jar was built without the Orange plugin; skipping install.");
                return;
            }
            embedded = in.readAllBytes();
        }
        Path target = home.resolve("plugins").resolve("Orange.jar");
        if (Files.exists(target) && Arrays.equals(Files.readAllBytes(target), embedded)) {
            return;
        }
        Files.createDirectories(target.getParent());
        Path tmp = target.resolveSibling("Orange.jar.tmp");
        Files.write(tmp, embedded);
        Files.move(tmp, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        Log.info("Installed the Orange plugin to plugins/Orange.jar");
    }
}
