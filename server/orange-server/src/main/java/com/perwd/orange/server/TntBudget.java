package com.perwd.orange.server;

/**
 * Caps how much time TNT explosions may take per server tick.
 *
 * <p>Like Spigot's {@code max-tnt-per-tick}, TNT that would go over the budget simply skips its
 * tick and explodes on a following one, so lighting 1,000 TNT makes the blast ripple out over a
 * few seconds instead of freezing the server. Unlike a fixed count, a time budget keeps every tick
 * smooth however expensive each explosion is (big stacks, many entities nearby, ...).
 *
 * <p>Set with {@code -Dorange.tnt.budgetMs=<ms>} (orange.yml {@code tnt-tick-budget-ms}); 0 turns it off.
 */
public final class TntBudget {
    private static final long BUDGET_NANOS = Math.max(0L, Long.getLong("orange.tnt.budgetMs", 20L)) * 1_000_000L;

    private static int tick = Integer.MIN_VALUE;
    private static long spentNanos;

    private TntBudget() {
    }

    /** True if TNT may tick (and so maybe explode) now. Called on the main thread only. */
    public static boolean allow(int currentTick) {
        if (BUDGET_NANOS == 0L) {
            return true;
        }
        if (currentTick != tick) {
            tick = currentTick;
            spentNanos = 0L;
        }
        return spentNanos < BUDGET_NANOS;
    }

    /** Adds the time one explosion took to this tick's total. */
    public static void spent(long nanos) {
        spentNanos += nanos;
    }
}
