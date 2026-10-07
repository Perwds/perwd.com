package com.perwd.orange.server;

import java.util.concurrent.atomic.AtomicLong;

/** Counts block changes on loaded chunks, so caches that depend on blocks know when they're stale. */
public final class BlockEpoch {
    private static final AtomicLong EPOCH = new AtomicLong();
    /** Set once LevelChunk#setBlockState reports block changes; caches stay off until then. */
    private static volatile boolean tracking;

    private BlockEpoch() {
    }

    /** Called from LevelChunk#setBlockState. */
    public static void bump() {
        tracking = true;
        EPOCH.incrementAndGet();
    }

    /** True once block changes are being counted, i.e. the LevelChunk hook is in place. */
    public static boolean tracking() {
        return tracking;
    }

    public static long current() {
        return EPOCH.get();
    }
}
