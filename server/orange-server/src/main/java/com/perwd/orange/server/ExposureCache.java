package com.perwd.orange.server;

import java.util.HashMap;
import java.util.Map;

/**
 * Exact cache for how much of an entity an explosion "sees" (the exposure that scales damage and
 * knockback).
 *
 * <p>Exposure is a pure function of the explosion centre, the entity's bounding box, the blocks in
 * between and - only for a few blocks such as scaffolding or powder snow - the entity itself. So a
 * value is reused only for the same level, centre and bounding box, while no block has changed
 * and within the same tick; values whose rays touched an entity-dependent block shape are never
 * stored. With 1,000 stacked TNT nearly every entity in range shares one box and one centre, so
 * each explosion computes exposure about once instead of about 1,000 times, with vanilla results.
 *
 * <p>Main thread only, like explosions.
 */
public final class ExposureCache {
    private static final int MAX_ENTRIES = 65_536;
    private static final Map<Key, Float> CACHE = new HashMap<>();
    private static long epoch = Long.MIN_VALUE;
    private static int tick = Integer.MIN_VALUE;

    private ExposureCache() {
    }

    private record Key(Object level, double cx, double cy, double cz,
                       double minX, double minY, double minZ, double maxX, double maxY, double maxZ) {
    }

    /** The cached exposure, or -1 if there is none. */
    public static float get(Object level, int currentTick, double cx, double cy, double cz,
                            double minX, double minY, double minZ, double maxX, double maxY, double maxZ) {
        if (!BlockEpoch.tracking()) {
            return -1.0F; // without block-change tracking a cached value could be stale: stay off
        }
        sync(currentTick);
        Float value = CACHE.get(new Key(level, cx, cy, cz, minX, minY, minZ, maxX, maxY, maxZ));
        return value == null ? -1.0F : value;
    }

    public static void put(Object level, int currentTick, double cx, double cy, double cz,
                           double minX, double minY, double minZ, double maxX, double maxY, double maxZ, float exposure) {
        if (!BlockEpoch.tracking()) {
            return;
        }
        sync(currentTick);
        if (CACHE.size() >= MAX_ENTRIES) {
            CACHE.clear();
        }
        CACHE.put(new Key(level, cx, cy, cz, minX, minY, minZ, maxX, maxY, maxZ), exposure);
    }

    private static void sync(int currentTick) {
        long currentEpoch = BlockEpoch.current();
        if (currentEpoch != epoch || currentTick != tick) {
            CACHE.clear();
            epoch = currentEpoch;
            tick = currentTick;
        }
    }
}
