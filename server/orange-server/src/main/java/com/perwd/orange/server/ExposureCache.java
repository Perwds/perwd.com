package com.perwd.orange.server;

import java.util.HashMap;
import java.util.Map;

/**
 * Exact cache for how much of an entity an explosion "sees" (the exposure that scales damage and
 * knockback).
 *
 * <p>Exposure is a pure function of the explosion centre, the entity's bounding box, the blocks in
 * between and - only for a few blocks such as scaffolding or powder snow - the entity itself. So a
 * value is reused only for the same level, centre and bounding box, and only while no block
 * between them (the box spanning centre and entity, plus a block of margin) has changed; values
 * whose rays touched an entity-dependent block shape are never stored. With 1,000 stacked TNT
 * nearly every entity in range shares one box and one centre, so exposure is computed about once
 * instead of once per entity per explosion, with vanilla results.
 *
 * <p>Everything is also dropped every two seconds, so the cache never keeps unloaded worlds alive
 * and plugins that write chunk data directly (bypassing setBlockState) can't leave stale values.
 *
 * <p>Main thread only, like explosions.
 */
public final class ExposureCache {
    private static final int MAX_ENTRIES = 65_536;
    private static final long MAX_AGE_NANOS = 2_000_000_000L;
    private static final Map<Key, Entry> CACHE = new HashMap<>();
    private static long clearedAt = System.nanoTime();

    private ExposureCache() {
    }

    private record Key(Object level, double cx, double cy, double cz,
                       double minX, double minY, double minZ, double maxX, double maxY, double maxZ) {
    }

    private record Entry(float exposure, long stamp) {
    }

    /** The cached exposure, or -1 if there is none. */
    public static float get(Object level, double cx, double cy, double cz,
                            double minX, double minY, double minZ, double maxX, double maxY, double maxZ) {
        if (!BlockEpoch.tracking()) {
            return -1.0F; // without block-change tracking a cached value could be stale: stay off
        }
        expire();
        Key key = new Key(level, cx, cy, cz, minX, minY, minZ, maxX, maxY, maxZ);
        Entry entry = CACHE.get(key);
        if (entry == null) {
            return -1.0F;
        }
        if (!BlockEpoch.unchangedSince(level, entry.stamp(),
                floor(Math.min(cx, minX)) - 1, floor(Math.min(cy, minY)) - 1, floor(Math.min(cz, minZ)) - 1,
                floor(Math.max(cx, maxX)) + 1, floor(Math.max(cy, maxY)) + 1, floor(Math.max(cz, maxZ)) + 1)) {
            CACHE.remove(key);
            return -1.0F;
        }
        return entry.exposure();
    }

    public static void put(Object level, double cx, double cy, double cz,
                           double minX, double minY, double minZ, double maxX, double maxY, double maxZ, float exposure) {
        if (!BlockEpoch.tracking()) {
            return;
        }
        expire();
        if (CACHE.size() >= MAX_ENTRIES) {
            CACHE.clear();
        }
        CACHE.put(new Key(level, cx, cy, cz, minX, minY, minZ, maxX, maxY, maxZ), new Entry(exposure, BlockEpoch.current()));
    }

    private static void expire() {
        long now = System.nanoTime();
        if (now - clearedAt > MAX_AGE_NANOS) {
            CACHE.clear();
            clearedAt = now;
        }
    }

    private static int floor(double value) {
        return (int) Math.floor(value);
    }
}
