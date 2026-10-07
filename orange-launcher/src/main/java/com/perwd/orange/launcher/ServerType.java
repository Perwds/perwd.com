package com.perwd.orange.launcher;

import java.io.IOException;
import java.nio.file.Path;
import java.util.Locale;
import java.util.jar.JarFile;

/** The kind of server jar Orange is wrapping. Order matters: forks come before their parents. */
public enum ServerType {
    ORANGE("orange", Family.PAPER, false),
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

    /**
     * The fork a file name points to, e.g. {@code leaf-1.21.11-42.jar} or {@code purpur-26.3.jar}.
     * The name has to start with the fork's name followed by a separator or digit, so a plugin
     * like {@code LeafInventory-3.1.0.jar} doesn't count.
     */
    static ServerType fromName(String fileName) {
        String lower = fileName.toLowerCase(Locale.ROOT);
        for (ServerType type : values()) {
            if (!type.token.isEmpty() && lower.matches(java.util.regex.Pattern.quote(type.token) + "([-_.0-9].*)?\\.jar")) {
                return type;
            }
        }
        return UNKNOWN;
    }

    /**
     * What kind of server {@code jar} is, judged by what's inside it, or {@code null} if it isn't a
     * server jar at all (a plugin, a mod, a library...).
     */
    public static ServerType inspect(Path jar) {
        try (JarFile file = new JarFile(jar.toFile())) {
            var manifest = file.getManifest();
            boolean runnable = manifest != null && manifest.getMainAttributes().getValue("Main-Class") != null;
            if (!runnable) {
                return null;
            }
            ServerType byName = fromName(jar.getFileName().toString());
            if (file.getEntry("META-INF/patches.list") != null || has(file, "io/papermc/paperclip/")) {
                // A Paperclip jar: Paper or one of its forks; only the name tells which.
                return byName != UNKNOWN && byName.runsBukkitPlugins() ? byName : PAPER;
            }
            if (has(file, "org/bukkit/craftbukkit/")) {
                return byName == CRAFTBUKKIT ? CRAFTBUKKIT : SPIGOT;
            }
            if (has(file, "net/fabricmc/loader/") || file.getEntry("fabric-server-launch.properties") != null) {
                return byName == QUILT ? QUILT : FABRIC;
            }
            if (has(file, "org/quiltmc/loader/")) {
                return QUILT;
            }
            if (file.getEntry("net/minecraft/bundler/Main.class") != null
                    || file.getEntry("net/minecraft/server/MinecraftServer.class") != null) {
                return VANILLA;
            }
            return null;
        } catch (IOException e) {
            return null;
        }
    }

    /** For a jar the user named explicitly: whatever it is, run it. */
    public static ServerType detect(Path jar) {
        ServerType type = inspect(jar);
        return type != null ? type : fromName(jar.getFileName().toString());
    }

    private static boolean has(JarFile file, String prefix) {
        if (file.getEntry(prefix) != null) {
            return true;
        }
        var entries = file.entries();
        while (entries.hasMoreElements()) {
            if (entries.nextElement().getName().startsWith(prefix)) {
                return true;
            }
        }
        return false;
    }
}
