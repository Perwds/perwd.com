package com.perwd.orange.api;

/**
 * Console logger for mods. (Orange doesn't hand out java.util.logging loggers because mods load
 * before the server sets up its own logging, and touching JUL that early can break it.)
 */
public interface ModLogger {
    void info(String message);

    void warn(String message);

    void error(String message, Throwable error);
}
