package com.perwd.orange.plugin;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import org.bukkit.Bukkit;
import org.bukkit.World;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.scheduler.BukkitTask;

/**
 * Sheds load when MSPT climbs, one step per check: simulation distance first (if allowed, since
 * it means fewer ticking chunks), then view distance. Restores in reverse order once MSPT is low.
 */
final class TickGovernor {
    private final OrangePlugin plugin;
    private final TickMonitor monitor;
    private final boolean supported;
    /** Each world's distances before Orange touched them: [simulation, view]. */
    private final Map<UUID, int[]> original = new HashMap<>();

    private BukkitTask task;
    private double msptHigh;
    private double msptLow;
    private int minSimulation;
    private int minView;
    private boolean adjustSimulation;
    private String lastAction = "none yet";

    TickGovernor(OrangePlugin plugin, TickMonitor monitor) {
        this.plugin = plugin;
        this.monitor = monitor;
        this.supported = PaperSupport.hasDistanceSetters();
    }

    void configure(ConfigurationSection config) {
        stop();
        if (config == null || !config.getBoolean("enabled", true)) {
            return;
        }
        if (!supported) {
            plugin.getLogger().info("Governor needs Paper's World#setSimulationDistance; disabled on this server.");
            return;
        }
        msptHigh = config.getDouble("mspt-high", 45.0);
        msptLow = config.getDouble("mspt-low", 30.0);
        minSimulation = Math.max(2, config.getInt("min-simulation-distance", 3));
        minView = Math.max(2, config.getInt("min-view-distance", 5));
        adjustSimulation = config.getBoolean("adjust-simulation-distance", false);
        long period = Math.max(1, config.getLong("check-interval-seconds", 10)) * 20L;
        task = Bukkit.getScheduler().runTaskTimer(plugin, this::check, period, period);
    }

    boolean active() {
        return task != null;
    }

    String lastAction() {
        return lastAction;
    }

    void stop() {
        if (task != null) {
            task.cancel();
            task = null;
        }
        for (World world : Bukkit.getWorlds()) {
            int[] o = original.get(world.getUID());
            if (o != null) {
                world.setSimulationDistance(o[0]);
                world.setViewDistance(o[1]);
            }
        }
        original.clear();
    }

    private void check() {
        double mspt = PaperSupport.averageTickTime(monitor);
        for (World world : Bukkit.getWorlds()) {
            if (world.getPlayers().isEmpty()) {
                continue;
            }
            int[] o = original.computeIfAbsent(world.getUID(),
                    id -> new int[] {world.getSimulationDistance(), world.getViewDistance()});
            int sim = world.getSimulationDistance();
            int view = world.getViewDistance();
            if (mspt > msptHigh) {
                if (adjustSimulation && sim > minSimulation) {
                    world.setSimulationDistance(sim - 1);
                    record(world, "simulation-distance " + sim + " -> " + (sim - 1), mspt);
                } else if (view > minView) {
                    world.setViewDistance(view - 1);
                    record(world, "view-distance " + view + " -> " + (view - 1), mspt);
                }
            } else if (mspt < msptLow) {
                if (view < o[1]) {
                    world.setViewDistance(view + 1);
                    record(world, "view-distance " + view + " -> " + (view + 1), mspt);
                } else if (sim < o[0]) {
                    world.setSimulationDistance(sim + 1);
                    record(world, "simulation-distance " + sim + " -> " + (sim + 1), mspt);
                }
            }
        }
    }

    private void record(World world, String change, double mspt) {
        lastAction = world.getName() + ": " + change + String.format(" (%.1f mspt)", mspt);
        plugin.getLogger().info("Governor " + lastAction);
    }
}
