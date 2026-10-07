package com.perwd.orange.launcher;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/** Asks the user to accept the Minecraft EULA on the first start, instead of making them edit eula.txt. */
final class Eula {
    private Eula() {
    }

    static void askIfNeeded(Path home) throws IOException {
        Path file = home.resolve("eula.txt");
        if (Files.exists(file) && Files.readString(file).contains("eula=true")) {
            return;
        }
        if (!Terminal.interactive()) {
            return; // not interactive (service, panel, CI): the server will explain what to do
        }
        System.out.println("[Orange] To run a Minecraft server you must accept the Minecraft EULA:");
        System.out.println("[Orange]   https://aka.ms/MinecraftEULA");
        if (Terminal.ask("Do you accept it?")) {
            Files.writeString(file, "# Accepted through Orange (https://aka.ms/MinecraftEULA)\neula=true\n");
            Log.info("EULA accepted.");
        } else {
            throw new LauncherException("The EULA wasn't accepted, so the server can't start.");
        }
    }
}
