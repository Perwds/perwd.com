package com.perwd.orange.launcher;

import java.awt.GraphicsEnvironment;
import java.io.Console;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Locale;

/**
 * Double-clicking a jar runs it with no console: no output, no way to type commands, and an
 * invisible server. When that happens, Orange writes a start script next to itself and opens
 * it in a terminal window instead.
 */
final class Terminal {
    private static final String OS = System.getProperty("os.name", "").toLowerCase(Locale.ROOT);

    private Terminal() {
    }

    /** True when someone can read our output and type into the console. */
    static boolean interactive() {
        Console console = System.console();
        if (console == null) {
            return false;
        }
        if (Runtime.version().feature() >= 22) {
            // From Java 22, System.console() also exists when nobody is attached; isTerminal() tells.
            try {
                return (boolean) Console.class.getMethod("isTerminal").invoke(console);
            } catch (ReflectiveOperationException e) {
                return true;
            }
        }
        return true;
    }

    /** Relaunches in a terminal if Orange was double-clicked. Returns true if it did. */
    static boolean relaunchIfDoubleClicked(Path home, Path selfJar, String javaBinary) {
        if (selfJar == null || interactive() || GraphicsEnvironment.isHeadless()
                || System.getenv("ORANGE_NO_TERMINAL") != null) {
            return false; // a terminal, a service, a hosting panel, or no desktop at all
        }
        boolean windows = OS.contains("win");
        // On Windows a double-click runs javaw.exe; anything else is a panel or service piping us.
        if (windows && !javaBinary.toLowerCase(Locale.ROOT).endsWith("javaw.exe")) {
            return false;
        }
        String java = windows ? javaBinary.replaceAll("(?i)javaw\\.exe$", "java.exe") : javaBinary;
        try {
            if (windows) {
                Path script = write(home.resolve("start.bat"), """
                        @echo off
                        title Orange
                        cd /d "%~dp0"
                        "JAVA" -jar "JAR"
                        pause
                        """, java, selfJar, "\r\n");
                new ProcessBuilder("cmd", "/c", "start", "\"Orange\"", script.toString()).directory(home.toFile()).start();
            } else if (OS.contains("mac")) {
                Path script = write(home.resolve("start.command"), """
                        #!/bin/sh
                        cd "$(dirname "$0")"
                        exec "JAVA" -jar "JAR"
                        """, java, selfJar, "\n");
                new ProcessBuilder("open", "-a", "Terminal", script.toString()).start();
            } else {
                Path script = write(home.resolve("start.sh"), """
                        #!/bin/sh
                        cd "$(dirname "$0")"
                        "JAVA" -jar "JAR"
                        echo; echo "Press Enter to close."; read _
                        """, java, selfJar, "\n");
                if (!openLinuxTerminal(script)) {
                    return false;
                }
            }
            return true;
        } catch (IOException e) {
            return false;
        }
    }

    /** Shown when there's no console and no terminal could be opened. */
    static void showError(String message) {
        if (interactive() || GraphicsEnvironment.isHeadless()) {
            return;
        }
        try {
            javax.swing.JOptionPane.showMessageDialog(null, message + "\n\nTip: run it from a terminal with:\n  java -jar orange.jar",
                    "Orange", javax.swing.JOptionPane.ERROR_MESSAGE);
        } catch (Throwable ignored) {
            // no desktop after all
        }
    }

    private static Path write(Path file, String template, String java, Path jar, String newline) throws IOException {
        String text = template.replace("JAVA", java).replace("JAR", jar.getFileName().toString()).replace("\n", newline);
        Files.writeString(file, text, StandardCharsets.UTF_8);
        file.toFile().setExecutable(true);
        return file;
    }

    private static boolean openLinuxTerminal(Path script) {
        List<List<String>> terminals = List.of(
                List.of("x-terminal-emulator", "-e"), List.of("gnome-terminal", "--"), List.of("konsole", "-e"),
                List.of("xfce4-terminal", "-x"), List.of("kitty"), List.of("alacritty", "-e"), List.of("xterm", "-e"));
        for (List<String> terminal : terminals) {
            try {
                List<String> cmd = new java.util.ArrayList<>(terminal);
                cmd.add(script.toString());
                new ProcessBuilder(cmd).start();
                return true;
            } catch (IOException notInstalled) {
                // try the next one
            }
        }
        return false;
    }
}
