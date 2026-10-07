package com.perwd.orange.server;

import java.util.concurrent.atomic.AtomicLong;

/**
 * Records when blocks last changed, per chunk section, so caches that depend on blocks know when
 * they're stale.
 *
 * <p>Sections are hashed into a fixed table; two sections sharing a slot only make a cache
 * entry look stale sooner than needed, never valid when it isn't.
 */
public final class BlockEpoch {
    private static final int SLOTS = 1 << 14;
    private static final long[] CHANGED = new long[SLOTS];
    private static final AtomicLong STAMP = new AtomicLong();
    /** Set once LevelChunk#setBlockState reports block changes; caches stay off until then. */
    private static volatile boolean tracking;

    private BlockEpoch() {
    }

    /** Called from LevelChunk#setBlockState when the block at x, y, z actually changed. */
    public static void bump(Object level, int x, int y, int z) {
        tracking = true;
        CHANGED[slot(level, x >> 4, y >> 4, z >> 4)] = STAMP.incrementAndGet();
    }

    /** True once block changes are being counted, i.e. the LevelChunk hook is in place. */
    public static boolean tracking() {
        return tracking;
    }

    /** The current stamp; a block change after this moment gets a larger one. */
    public static long current() {
        return STAMP.get();
    }

    /** True if no block in the given block-coordinate box (inclusive) changed after {@code stamp}. */
    public static boolean unchangedSince(Object level, long stamp, int minX, int minY, int minZ, int maxX, int maxY, int maxZ) {
        for (int sx = minX >> 4; sx <= maxX >> 4; sx++) {
            for (int sy = minY >> 4; sy <= maxY >> 4; sy++) {
                for (int sz = minZ >> 4; sz <= maxZ >> 4; sz++) {
                    if (CHANGED[slot(level, sx, sy, sz)] > stamp) {
                        return false;
                    }
                }
            }
        }
        return true;
    }

    private static int slot(Object level, int sx, int sy, int sz) {
        int h = System.identityHashCode(level);
        h = h * 31 + sx;
        h = h * 31 + sy;
        h = h * 31 + sz;
        h ^= h >>> 16;
        h *= 0x45d9f3b;
        h ^= h >>> 16;
        return h & (SLOTS - 1);
    }
}
