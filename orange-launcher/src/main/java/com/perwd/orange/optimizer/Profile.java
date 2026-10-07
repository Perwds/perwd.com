package com.perwd.orange.optimizer;

import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Config tuning profiles. Keys are dotted YAML paths (or server.properties keys).
 *
 * <p>Values only ever replace keys that already exist in a file, so a path that a server
 * version doesn't have is skipped rather than injected.
 */
public enum Profile {
    OFF,
    /** Vanilla gameplay, bit for bit as far as config allows: only optimizations with no gameplay effect. */
    VANILLA,
    BALANCED,
    AGGRESSIVE;

    public static Profile parse(String value) {
        try {
            return valueOf(value.trim().toUpperCase(Locale.ROOT));
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Unknown optimization-profile '" + value + "' (use off, vanilla, balanced or aggressive).");
        }
    }

    public String id() {
        return name().toLowerCase(Locale.ROOT);
    }

    /** file (relative to the server folder) -> path -> value */
    public Map<String, Map<String, String>> settings() {
        Map<String, Map<String, String>> out = new LinkedHashMap<>();
        if (this == OFF) {
            return out;
        }
        if (this == VANILLA) {
            vanilla(out);
            return out;
        }
        balanced(out);
        if (this == AGGRESSIVE) {
            aggressive(out);
        }
        return out;
    }

    private static Map<String, String> file(Map<String, Map<String, String>> out, String name) {
        return out.computeIfAbsent(name, k -> new LinkedHashMap<>());
    }

    /**
     * Undoes every Spigot/Paper/Pufferfish change to vanilla mechanics we can reach through config,
     * and keeps only optimizations that change how fast the server works, not what it does.
     */
    private static void vanilla(Map<String, Map<String, String>> out) {
        // Disk and network only.
        Map<String, String> props = file(out, "server.properties");
        props.put("sync-chunk-writes", "false");
        props.put("network-compression-threshold", "256");

        // Bukkit: vanilla mob caps and spawn timing (undoes the balanced/aggressive profiles).
        Map<String, String> bukkit = file(out, "bukkit.yml");
        bukkit.put("spawn-limits.monsters", "70");
        bukkit.put("spawn-limits.animals", "10");
        bukkit.put("spawn-limits.water-animals", "5");
        bukkit.put("spawn-limits.water-ambient", "20");
        bukkit.put("spawn-limits.water-underground-creature", "5");
        bukkit.put("spawn-limits.axolotls", "5");
        bukkit.put("spawn-limits.ambient", "15");
        bukkit.put("ticks-per.monster-spawns", "1");
        bukkit.put("ticks-per.animal-spawns", "400");
        for (String kind : new String[] {"water", "water-ambient", "water-underground-creature", "axolotl", "ambient"}) {
            bukkit.put("ticks-per." + kind + "-spawns", "1");
        }

        // Spigot: entity activation range freezes far-away mobs (breaks farms); 0 = always active.
        Map<String, String> spigot = file(out, "spigot.yml");
        String w = "world-settings.default.";
        for (String group : new String[] {"animals", "monsters", "raiders", "misc", "water", "villagers", "flying-monsters"}) {
            spigot.put(w + "entity-activation-range." + group, "0");
        }
        spigot.put(w + "entity-activation-range.tick-inactive-villagers", "true");
        spigot.put(w + "merge-radius.item", "0.5");   // vanilla item merge distance
        spigot.put(w + "merge-radius.exp", "-1");     // vanilla XP orb merging only
        spigot.put(w + "nerf-spawner-mobs", "false");
        spigot.put(w + "mob-spawn-range", "8");
        spigot.put(w + "hopper-amount", "1");
        spigot.put(w + "ticks-per.hopper-transfer", "8");
        spigot.put(w + "ticks-per.hopper-check", "1");
        spigot.put(w + "item-despawn-rate", "6000");
        spigot.put(w + "arrow-despawn-rate", "1200");
        spigot.put(w + "trident-despawn-rate", "1200");
        spigot.put(w + "zombie-aggressive-towards-villager", "true");

        // Paper: re-allow the vanilla mechanics technical players depend on.
        Map<String, String> global = file(out, "config/paper-global.yml");
        global.put("unsupported-settings.allow-piston-duplication", "true");
        global.put("unsupported-settings.allow-headless-pistons", "true");
        global.put("unsupported-settings.allow-permanent-block-break-exploits", "true");
        global.put("unsupported-settings.allow-unsafe-end-portal-teleportation", "true");
        global.put("unsupported-settings.allow-tripwire-disarming-exploits", "true");
        global.put("unsupported-settings.allow-grindstone-overstacking", "true");
        global.put("unsupported-settings.skip-tripwire-hook-placement-validation", "true");

        Map<String, String> paper = file(out, "config/paper-world-defaults.yml");
        paper.put("misc.redstone-implementation", "VANILLA");
        paper.put("collisions.max-entity-collisions", "2147483647");
        paper.put("collisions.allow-player-cramming-damage", "true");
        paper.put("fixes.disable-unloaded-chunk-enderpearl-exploit", "false");
        paper.put("fixes.split-overstacked-loot", "false");
        paper.put("fixes.fix-curing-zombie-villager-discount-exploit", "false");
        paper.put("fixes.prevent-tnt-from-moving-in-water", "false");
        paper.put("fixes.falling-block-height-nerf", "disabled");
        paper.put("fixes.tnt-entity-height-nerf", "disabled");
        paper.put("hopper.cooldown-when-full", "false");
        paper.put("hopper.ignore-occluding-blocks", "false");
        paper.put("entities.armor-stands.tick", "true");
        paper.put("entities.armor-stands.do-collision-entity-lookups", "true");
        paper.put("misc.update-pathfinding-on-block-update", "true");
        paper.put("environment.optimize-explosions", "false");
        paper.put("tick-rates.grass-spread", "1");
        paper.put("tick-rates.mob-spawner", "1");
        paper.put("chunks.entity-per-chunk-save-limit.arrow", "-1");
        paper.put("chunks.entity-per-chunk-save-limit.ender_pearl", "-1");
        paper.put("chunks.entity-per-chunk-save-limit.experience_orb", "-1");
        paper.put("chunks.entity-per-chunk-save-limit.snowball", "-1");
        // Spreads world saves over more ticks: same data on disk, no save-tick lag spikes.
        paper.put("chunks.max-auto-save-chunks-per-tick", "8");

        // Pufferfish and its forks: DAB and goal throttling slow down far-away mob AI.
        Map<String, String> pufferfish = file(out, "pufferfish.yml");
        pufferfish.put("dab.enabled", "false");
        pufferfish.put("inactive-goal-selector-throttle", "false");
        Map<String, String> purpur = file(out, "purpur.yml");
        purpur.put("settings.use-alternate-keepalive", "true"); // network only
    }

    private static void balanced(Map<String, Map<String, String>> out) {
        Map<String, String> props = file(out, "server.properties");
        props.put("view-distance", "8");
        props.put("simulation-distance", "6");
        props.put("network-compression-threshold", "256");
        props.put("sync-chunk-writes", "false");

        Map<String, String> bukkit = file(out, "bukkit.yml");
        bukkit.put("spawn-limits.monsters", "50");
        bukkit.put("spawn-limits.animals", "8");
        bukkit.put("spawn-limits.water-animals", "4");
        bukkit.put("spawn-limits.water-ambient", "10");
        bukkit.put("spawn-limits.water-underground-creature", "4");
        bukkit.put("spawn-limits.axolotls", "4");
        bukkit.put("spawn-limits.ambient", "3");
        bukkit.put("ticks-per.monster-spawns", "2");
        bukkit.put("ticks-per.animal-spawns", "400");
        bukkit.put("ticks-per.water-spawns", "400");
        bukkit.put("ticks-per.water-ambient-spawns", "400");
        bukkit.put("ticks-per.water-underground-creature-spawns", "400");
        bukkit.put("ticks-per.axolotl-spawns", "400");
        bukkit.put("ticks-per.ambient-spawns", "400");
        bukkit.put("chunk-gc.period-in-ticks", "400");

        Map<String, String> spigot = file(out, "spigot.yml");
        String w = "world-settings.default.";
        spigot.put(w + "mob-spawn-range", "5");
        spigot.put(w + "merge-radius.item", "3.5");
        spigot.put(w + "merge-radius.exp", "4.0");
        spigot.put(w + "entity-activation-range.animals", "16");
        spigot.put(w + "entity-activation-range.monsters", "24");
        spigot.put(w + "entity-activation-range.raiders", "48");
        spigot.put(w + "entity-activation-range.misc", "8");
        spigot.put(w + "entity-activation-range.water", "8");
        spigot.put(w + "entity-activation-range.villagers", "16");
        spigot.put(w + "entity-activation-range.flying-monsters", "48");
        spigot.put(w + "entity-activation-range.tick-inactive-villagers", "false");

        Map<String, String> paper = file(out, "config/paper-world-defaults.yml");
        paper.put("chunks.max-auto-save-chunks-per-tick", "8");
        paper.put("chunks.prevent-moving-into-unloaded-chunks", "true");
        paper.put("chunks.entity-per-chunk-save-limit.arrow", "16");
        paper.put("chunks.entity-per-chunk-save-limit.ender_pearl", "8");
        paper.put("chunks.entity-per-chunk-save-limit.experience_orb", "16");
        paper.put("chunks.entity-per-chunk-save-limit.fireball", "8");
        paper.put("chunks.entity-per-chunk-save-limit.small_fireball", "8");
        paper.put("chunks.entity-per-chunk-save-limit.snowball", "8");
        paper.put("collisions.max-entity-collisions", "2");
        paper.put("entities.armor-stands.do-collision-entity-lookups", "false");
        paper.put("environment.optimize-explosions", "true");
        paper.put("tick-rates.mob-spawner", "2");
        paper.put("tick-rates.grass-spread", "4");
        paper.put("tick-rates.container-update", "1");

        Map<String, String> purpur = file(out, "purpur.yml");
        purpur.put("settings.use-alternate-keepalive", "true");
        purpur.put("world-settings.default.mobs.dolphin.disable-treasure-searching", "true");
    }

    /** Trades some vanilla behaviour for TPS. */
    private static void aggressive(Map<String, Map<String, String>> out) {
        Map<String, String> props = file(out, "server.properties");
        props.put("view-distance", "7");
        props.put("simulation-distance", "4");

        Map<String, String> bukkit = file(out, "bukkit.yml");
        bukkit.put("spawn-limits.monsters", "20");
        bukkit.put("spawn-limits.animals", "5");
        bukkit.put("spawn-limits.water-animals", "2");
        bukkit.put("spawn-limits.water-ambient", "2");
        bukkit.put("spawn-limits.water-underground-creature", "3");
        bukkit.put("spawn-limits.axolotls", "3");
        bukkit.put("spawn-limits.ambient", "1");
        bukkit.put("ticks-per.monster-spawns", "10");

        Map<String, String> spigot = file(out, "spigot.yml");
        spigot.put("world-settings.default.mob-spawn-range", "3");
        spigot.put("world-settings.default.nerf-spawner-mobs", "true");

        Map<String, String> paper = file(out, "config/paper-world-defaults.yml");
        paper.put("misc.redstone-implementation", "ALTERNATE_CURRENT");
        paper.put("entities.armor-stands.tick", "false");
        paper.put("misc.update-pathfinding-on-block-update", "false");
        paper.put("hopper.disable-move-event", "true");
        paper.put("hopper.ignore-occluding-blocks", "true");
        paper.put("environment.treasure-maps.enabled", "false");
        paper.put("tick-rates.behavior.villager.validatenearbypoi", "60");

        Map<String, String> purpur = file(out, "purpur.yml");
        purpur.put("world-settings.default.mobs.villager.lobotomize.enabled", "true");

        Map<String, String> pufferfish = file(out, "pufferfish.yml");
        pufferfish.put("dab.enabled", "true");
    }
}
