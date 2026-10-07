package com.perwd.orange.launcher;

/** Minimal console logger shared by the launcher and the agent. */
public final class Log {
    private Log() {
    }

    public static void info(String message) {
        System.out.println("[Orange] " + message);
    }

    public static void warn(String message) {
        System.out.println("[Orange] WARN: " + message);
    }

    public static void error(String message, Throwable t) {
        System.err.println("[Orange] ERROR: " + message + (t == null ? "" : ": " + t));
    }
}
