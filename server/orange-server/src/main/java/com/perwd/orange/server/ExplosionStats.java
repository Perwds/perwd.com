package com.perwd.orange.server;

/**
 * Optional timing for explosions: with {@code -Dorange.debug.explosionMs=<ms>}, every explosion
 * slower than that is logged with how long each phase took and how often the exposure cache hit.
 * Off by default (only a few nanoTime calls then). Main thread only, like explosions.
 */
public final class ExplosionStats {
    private static final long THRESHOLD_NANOS = Long.getLong("orange.debug.explosionMs", 0L) * 1_000_000L;

    private static int hits;
    private static int misses;

    private ExplosionStats() {
    }

    public static long start() {
        hits = 0;
        misses = 0;
        return System.nanoTime();
    }

    public static void cacheHit() {
        hits++;
    }

    public static void cacheMiss() {
        misses++;
    }

    /** t0 = start, t1 = after ray-casting blocks, t2 = after hurting entities; now = after breaking blocks. */
    public static void finish(long t0, long t1, long t2, int blocks) {
        if (THRESHOLD_NANOS <= 0L) {
            return;
        }
        long now = System.nanoTime();
        if (now - t0 < THRESHOLD_NANOS) {
            return;
        }
        System.out.printf("[Orange] slow explosion %.1f ms: rays %.1f ms, entities %.1f ms (exposure cache %d hits, %d misses), blocks %.1f ms (%d blocks)%n",
                (now - t0) / 1e6, (t1 - t0) / 1e6, (t2 - t1) / 1e6, hits, misses, (now - t2) / 1e6, blocks);
    }
}
