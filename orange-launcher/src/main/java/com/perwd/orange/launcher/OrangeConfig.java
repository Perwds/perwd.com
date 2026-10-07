package com.perwd.orange.launcher;

import com.perwd.orange.optimizer.PingTolerance;
import com.perwd.orange.optimizer.Profile;
import java.io.IOException;
import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.yaml.snakeyaml.LoaderOptions;
import org.yaml.snakeyaml.Yaml;
import org.yaml.snakeyaml.constructor.SafeConstructor;

/** Settings from {@code orange.yml}. */
public record OrangeConfig(
        String serverJar,
        String download,
        String minecraftVersion,
        boolean autoUpdate,
        String memory,
        String gc,
        Profile profile,
        PingTolerance pingTolerance,
        boolean installPlugin,
        String agent,
        boolean autoRestart,
        boolean fastStartup,
        int tntTickBudgetMs,
        List<String> serverArgs,
        List<String> extraJvmArgs) {

    static final String TEMPLATE = """
            # Orange launcher settings. Delete this file to get the defaults back.

            # Server jar to run. "auto" uses the jar Orange downloaded (see "download"), or else the first
            # Paper/Purpur/Pufferfish/Leaf/Spigot/Fabric/vanilla jar in this folder.
            # Otherwise give a file name, e.g. paper-26.2-132.jar
            server-jar: auto

            # When there's no server jar, download one:
            #   orange = the Orange server: Orange's own Paper fork (plugins work), built by this project
            #   paper | purpur = the upstream servers
            #   off    = never download
            download: orange

            # Minecraft version to download. "latest" picks the newest one your Java can run, once.
            # Orange never changes the Minecraft version by itself afterwards (that upgrades the world,
            # which can't be undone); set a version here, e.g. 26.2, to move to it.
            minecraft-version: latest

            # Check for a newer build of the same Minecraft version on every start (bug and security
            # fixes). Only applies to the jar Orange downloaded.
            auto-update: true

            # Heap size, e.g. 6G or 6144M. "auto" uses ~75% of the RAM this machine/container has,
            # leaving at least 2 GB for the OS. -Xms is set to the same value (no heap resizing pauses).
            memory: auto

            # Garbage collector: auto | g1 | zgc
            #   g1  = Aikar's flags, tuned for Minecraft. Best for most servers.
            #   zgc = generational ZGC. Sub-millisecond pauses, costs more CPU. Good for 16 GB+ heaps.
            #   auto = zgc for 16 GB+ heaps on 8+ cores, g1 otherwise.
            gc: auto

            # Server config tuning, applied once per config file per profile (your later edits stick):
            #   vanilla    = 100% vanilla gameplay. Undoes Paper/Spigot's mechanic changes (piston duping,
            #                bedrock breaking, entity activation range, item merging...) and only applies
            #                optimizations that have no gameplay effect. (default)
            #   balanced   = big TPS wins; changes things most players won't notice (spawn rates, far-away
            #                mob AI). Some farms get slower.
            #   aggressive = maximum TPS; changes vanilla mechanics (redstone engine, spawner AI, villager
            #                AI, armor stand ticking). Read the README before using it.
            #   off        = don't touch my configs
            optimization-profile: vanilla

            # How forgiving the server is towards players with high or unstable ping:
            #   normal = vanilla thresholds (on Purpur-based servers, also a keepalive that stops
            #            "Timed out" kicks on lossy connections)
            #   high   = also fewer "moved too quickly/wrongly" rubber-band snaps, and packet bursts after
            #            lag spikes aren't treated as spam. Slightly relaxes the server's own movement
            #            checks; anti-cheat plugins are unaffected.
            ping-tolerance: normal

            # Copy the Orange plugin (TPS governor, entity limiter, /orange) into plugins/.
            install-plugin: true

            # The Orange agent loads Orange mods from orange-mods/ and brands the server "Orange (Paper)".
            #   auto  = only when orange-mods/ has mods (keeps the JVM's startup cache fully supported)
            #   true  = always, for the branding too (the JVM then marks its startup cache "for testing")
            #   false = never
            agent: auto

            # Restart the server automatically if it crashes (exit code other than 0).
            auto-restart: false

            # Orange server only: the most time TNT explosions may take per tick (ms). TNT over the
            # budget waits for the next tick, so even 1,000 TNT can't lag the server; the blast just
            # ripples out over a few seconds. 0 = off (only Spigot's max-tnt-per-tick count applies).
            tnt-tick-budget-ms: 20

            # Faster starts for Paper-based servers: launch the unpacked server directly (skipping
            # Paperclip's re-hashing of every library) and keep a JVM class cache between runs
            # (the AOT cache on Java 25+, AppCDS on older Java). The first start records the cache.
            fast-startup: true

            server-args:
              - nogui

            extra-jvm-args: []
            """;

    public static OrangeConfig loadOrCreate(Path file) throws IOException {
        if (Files.notExists(file)) {
            Files.writeString(file, TEMPLATE, StandardCharsets.UTF_8);
            Log.info("Created " + file.getFileName() + " with default settings.");
        }
        Map<String, Object> map;
        try (Reader reader = Files.newBufferedReader(file, StandardCharsets.UTF_8)) {
            Object loaded = new Yaml(new SafeConstructor(new LoaderOptions())).load(reader);
            map = loaded instanceof Map<?, ?> m ? castMap(m) : Map.of();
        }
        return new OrangeConfig(
                string(map, "server-jar", "auto"),
                string(map, "download", "orange").toLowerCase(Locale.ROOT),
                string(map, "minecraft-version", "latest"),
                bool(map, "auto-update", true),
                string(map, "memory", "auto"),
                string(map, "gc", "auto").toLowerCase(Locale.ROOT),
                Profile.parse(string(map, "optimization-profile", "vanilla")),
                PingTolerance.parse(string(map, "ping-tolerance", "normal")),
                bool(map, "install-plugin", true),
                string(map, "agent", "auto").toLowerCase(Locale.ROOT),
                bool(map, "auto-restart", false),
                bool(map, "fast-startup", true),
                (int) JvmFlags.parseNonNegative(string(map, "tnt-tick-budget-ms", "20")),
                list(map, "server-args", List.of("nogui")),
                list(map, "extra-jvm-args", List.of()));
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> castMap(Map<?, ?> m) {
        return (Map<String, Object>) m;
    }

    private static String string(Map<String, Object> map, String key, String def) {
        Object v = map.get(key);
        return v == null ? def : String.valueOf(v).trim();
    }

    private static boolean bool(Map<String, Object> map, String key, boolean def) {
        Object v = map.get(key);
        return v == null ? def : Boolean.parseBoolean(String.valueOf(v));
    }

    private static List<String> list(Map<String, Object> map, String key, List<String> def) {
        Object v = map.get(key);
        if (!(v instanceof List<?> l)) {
            return def;
        }
        List<String> out = new ArrayList<>();
        for (Object o : l) {
            out.add(String.valueOf(o));
        }
        return out;
    }
}
