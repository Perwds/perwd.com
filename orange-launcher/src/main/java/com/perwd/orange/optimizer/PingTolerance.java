package com.perwd.orange.optimizer;

import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

/**
 * How forgiving the server is towards players on slow or unstable connections. None of this
 * touches game mechanics; it only changes when the server decides a connection is bad.
 */
public enum PingTolerance {
    /** Vanilla thresholds. */
    NORMAL,
    /**
     * Fewer "moved too quickly/wrongly" rubber-band corrections, and packet bursts after a lag
     * spike are no longer mistaken for spam. Relaxes the built-in movement checks a little;
     * an anti-cheat plugin still does its own checks.
     */
    HIGH;

    public static PingTolerance parse(String value) {
        try {
            return valueOf(value.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Unknown ping-tolerance '" + value + "' (use normal or high).");
        }
    }

    public String id() {
        return name().toLowerCase(Locale.ROOT);
    }

    Map<String, Map<String, String>> settings() {
        Map<String, Map<String, String>> out = new LinkedHashMap<>();
        // Purpur's keepalive sends a ping every second and only times a player out if none of the
        // last 30 seconds' worth were answered, instead of vanilla's single ping every 15 seconds.
        // Players on lossy Wi-Fi or mobile data stop getting "Timed out" kicks.
        out.computeIfAbsent("purpur.yml", k -> new LinkedHashMap<>()).put("settings.use-alternate-keepalive", "true");
        if (this == HIGH) {
            Map<String, String> spigot = out.computeIfAbsent("spigot.yml", k -> new LinkedHashMap<>());
            spigot.put("settings.moved-wrongly-threshold", "0.25");
            spigot.put("settings.moved-too-quickly-multiplier", "20.0");
            Map<String, String> paper = out.computeIfAbsent("config/paper-global.yml", k -> new LinkedHashMap<>());
            paper.put("packet-limiter.all-packets.max-packet-rate", "1000.0");
        }
        return out;
    }
}
