package com.perwd.orange.launcher;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Locale;
import java.util.jar.JarFile;

/** The kind of server jar Orange is wrapping. Order matters: forks come before their parents. */
public enum ServerType {
    LEAF("leaf", Family.PAPER, true),
    GALE("gale", Family.PAPER, true),
    CANVAS("canvas", Family.FOLIA, true),
    PUFFERFISH("pufferfish", Family.PAPER, true),
    PURPUR("purpur", Family.PAPER, true),
    LEAVES("leaves", Family.PAPER, false),
    FOLIA("folia", Family.FOLIA, false),
    PAPER("paper", Family.PAPER, false),
    SPIGOT("spigot", Family.BUKKIT, false),
    CRAFTBUKKIT("craftbukkit", Family.BUKKIT, false),
    QUILT("quilt", Family.MODDED, false),
    FABRIC("fabric", Family.MODDED, false),
    VANILLA("minecraft_server", Family.VANILLA, false),
    UNKNOWN("", Family.VANILLA, false);

    public enum Family { PAPER, FOLIA, BUKKIT, MODDED, VANILLA }

    private final String token;
    private final Family family;
    private final boolean usesVectorApi;

    ServerType(String token, Family family, boolean usesVectorApi) {
        this.token = token;
        this.family = family;
        this.usesVectorApi = usesVectorApi;
    }

    public Family family() {
        return family;
    }

    /** Pufferfish and its descendants use the incubating Vector API (SIMD) when it's enabled. */
    public boolean usesVectorApi() {
        return usesVectorApi;
    }

    public boolean runsBukkitPlugins() {
        return family == Family.PAPER || family == Family.BUKKIT || family == Family.FOLIA;
    }

    public String displayName() {
        String n = name().toLowerCase(Locale.ROOT);
        return Character.toUpperCase(n.charAt(0)) + n.substring(1);
    }

    /** True if the file name looks like a server jar Orange knows. */
    static boolean matchesName(String fileName) {
        return fromName(fileName) != UNKNOWN || fileName.toLowerCase(Locale.ROOT).equals("server.jar");
    }

    static ServerType fromName(String fileName) {
        String lower = fileName.toLowerCase(Locale.ROOT);
        for (ServerType type : values()) {
            if (!type.token.isEmpty() && lower.contains(type.token)) {
                return type;
            }
        }
        return UNKNOWN;
    }

    public static ServerType detect(Path jar) {
        ServerType byName = fromName(jar.getFileName().toString());
        if (byName != UNKNOWN) {
            return byName;
        }
        try (JarFile file = new JarFile(jar.toFile())) {
            if (file.getEntry("io/papermc/paperclip/") != null || file.getEntry("io/papermc/paperclip/Main.class") != null) {
                return PAPER;
            }
            if (file.getEntry("org/bukkit/") != null || file.getEntry("org/bukkit/craftbukkit/bootstrap/Main.class") != null) {
                return SPIGOT;
            }
            if (file.getEntry("net/fabricmc/") != null || file.getEntry("fabric-server-launch.properties") != null) {
                return FABRIC;
            }
            if (file.getEntry("net/minecraft/bundler/Main.class") != null) {
                return VANILLA;
            }
        } catch (IOException e) {
            Log.warn("Could not inspect " + jar.getFileName() + ": " + e.getMessage());
        }
        return UNKNOWN;
    }
}
