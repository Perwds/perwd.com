package com.perwd.orange.launcher;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;

/** Asks the user to accept the Minecraft EULA on the first start, instead of making them edit eula.txt. */
final class Eula {
    private Eula() {
    }

    static void askIfNeeded(Path home) throws IOException {
        Path file = home.resolve("eula.txt");
        if (Files.exists(file) && Files.readString(file).contains("eula=true")) {
            return;
        }
        if (System.console() == null) {
            return; // not interactive (service, panel, CI): the server will explain what to do
        }
        System.out.println("[Orange] To run a Minecraft server you must accept the Minecraft EULA:");
        System.out.println("[Orange]   https://aka.ms/MinecraftEULA");
        System.out.print("[Orange] Do you accept it? (yes/no): ");
        System.out.flush();
        // Don't close: this is the server console's stdin too.
        String answer = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8)).readLine();
        if (answer != null && answer.trim().toLowerCase(Locale.ROOT).matches("y|yes")) {
            Files.writeString(file, "# Accepted through Orange (https://aka.ms/MinecraftEULA)\neula=true\n");
            Log.info("EULA accepted.");
        } else {
            throw new LauncherException("The EULA wasn't accepted, so the server can't start.");
        }
    }
}
