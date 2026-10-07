package com.perwd.orange.plugin;

/**
 * Measures TPS from the time between ticks. Works on every Bukkit server, unlike Paper's
 * getTPS(), and costs one System.nanoTime() call per tick.
 */
final class TickMonitor implements Runnable {
    private static final int WINDOW = 1200; // one minute at 20 TPS
    private final long[] intervals = new long[WINDOW];
    private int index;
    private int filled;
    private long last;

    @Override
    public void run() {
        long now = System.nanoTime();
        if (last != 0) {
            intervals[index] = now - last;
            index = (index + 1) % WINDOW;
            if (filled < WINDOW) {
                filled++;
            }
        }
        last = now;
    }

    /** TPS over the last {@code ticks} ticks (at most one minute), capped at 20. */
    double tps(int ticks) {
        int n = Math.min(ticks, filled);
        if (n == 0) {
            return 20.0;
        }
        long total = 0;
        for (int i = 1; i <= n; i++) {
            total += intervals[(index - i + WINDOW) % WINDOW];
        }
        return Math.min(20.0, n * 1_000_000_000.0 / total);
    }
}
