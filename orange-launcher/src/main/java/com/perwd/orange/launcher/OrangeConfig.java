package com.perwd.orange.launcher;

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
        String memory,
        String gc,
        Profile profile,
        boolean installPlugin,
        boolean agent,
        boolean autoRestart,
        List<String> serverArgs,
        List<String> extraJvmArgs) {

    static final String TEMPLATE = """
            # Orange launcher settings. Delete this file to get the defaults back.

            # Server jar to run. "auto" picks the first Paper/Purpur/Pufferfish/Leaf/Spigot/Fabric/vanilla
            # jar in this folder. Otherwise give a file name, e.g. paper-1.21.10-130.jar
            server-jar: auto

            # Heap size, e.g. 6G or 6144M. "auto" uses ~75% of the RAM this machine/container has,
            # leaving at least 2 GB for the OS. -Xms is set to the same value (no heap resizing pauses).
            memory: auto

            # Garbage collector: auto | g1 | zgc
            #   g1  = Aikar's flags, tuned for Minecraft. Best for most servers.
            #   zgc = generational ZGC. Sub-millisecond pauses, costs more CPU. Good for 16 GB+ heaps.
            #   auto = zgc for 16 GB+ heaps on 8+ cores, g1 otherwise.
            gc: auto

            # Server config tuning, applied once per config file per profile (your later edits stick):
            #   off        = don't touch my configs
            #   balanced   = big wins, no gameplay changes players notice (recommended)
            #   aggressive = maximum TPS; changes some vanilla mechanics (redstone engine, spawner AI,
            #                villager AI, armor stand ticking). Read the README before using it.
            optimization-profile: balanced

            # Copy the Orange plugin (TPS governor, entity limiter, /orange) into plugins/.
            install-plugin: true

            # Load the Orange agent: server branding and Orange mods from orange-mods/.
            agent: true

            # Restart the server automatically if it crashes (exit code other than 0).
            auto-restart: false

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
                string(map, "memory", "auto"),
                string(map, "gc", "auto").toLowerCase(Locale.ROOT),
                Profile.parse(string(map, "optimization-profile", "balanced")),
                bool(map, "install-plugin", true),
                bool(map, "agent", true),
                bool(map, "auto-restart", false),
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
