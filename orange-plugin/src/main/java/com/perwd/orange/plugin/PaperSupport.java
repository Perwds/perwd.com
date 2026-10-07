package com.perwd.orange.plugin;

import org.bukkit.Bukkit;
import org.bukkit.World;

/** Paper-only API, probed once so the plugin still loads on Spigot. */
final class PaperSupport {
    private static final boolean TICK_TIME = hasMethod(org.bukkit.Server.class, "getAverageTickTime");
    private static final boolean DISTANCE_SETTERS = hasMethod(World.class, "setSimulationDistance", int.class)
            && hasMethod(World.class, "setViewDistance", int.class);
    private static final boolean SEND_VIEW_DISTANCE = hasMethod(org.bukkit.entity.Player.class, "setSendViewDistance", int.class);
    private static final boolean ASYNC_CHUNKS = hasMethod(World.class, "getChunkAtAsync", int.class, int.class, boolean.class);

    private PaperSupport() {
    }

    static boolean hasDistanceSetters() {
        return DISTANCE_SETTERS;
    }

    /** Paper's average MSPT, or an estimate from our own TPS measurement elsewhere. */
    static double averageTickTime(TickMonitor monitor) {
        if (TICK_TIME) {
            return Bukkit.getServer().getAverageTickTime();
        }
        double tps = monitor.tps(200);
        return tps >= 19.9 ? 0 : 1000.0 / tps;
    }

    static boolean hasSendViewDistance() {
        return SEND_VIEW_DISTANCE;
    }

    static boolean hasAsyncChunks() {
        return ASYNC_CHUNKS;
    }

    static boolean hasPaperTickTime() {
        return TICK_TIME;
    }

    private static boolean hasMethod(Class<?> type, String name, Class<?>... params) {
        try {
            type.getMethod(name, params);
            return true;
        } catch (NoSuchMethodException e) {
            return false;
        }
    }
}
