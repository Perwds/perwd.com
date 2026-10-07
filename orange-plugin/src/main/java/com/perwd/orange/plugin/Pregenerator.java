package com.perwd.orange.plugin;

import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import org.bukkit.Location;
import org.bukkit.World;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.scheduler.BukkitTask;

/**
 * Generates a square of chunks around spawn using Paper's async chunk API, spiralling outwards
 * so the area near spawn is done first. Pauses while the server is busy.
 */
final class Pregenerator {
    private final OrangePlugin plugin;
    private final TickMonitor monitor;
    private int parallel = 16;
    private double pauseAboveMspt = 40.0;
    private Job job;

    Pregenerator(OrangePlugin plugin, TickMonitor monitor) {
        this.plugin = plugin;
        this.monitor = monitor;
    }

    void configure(ConfigurationSection config) {
        if (config != null) {
            parallel = Math.max(1, config.getInt("parallel-chunks", 16));
            pauseAboveMspt = config.getDouble("pause-above-mspt", 40.0);
        }
    }

    static boolean supported() {
        return PaperSupport.hasAsyncChunks();
    }

    boolean running() {
        return job != null;
    }

    /** Starts a job; {@code radius} is in blocks. */
    String start(World world, int radius) {
        if (job != null) {
            return "Already generating " + job.world.getName() + ". Use /orange pregen stop first.";
        }
        Location spawn = world.getSpawnLocation();
        job = new Job(world, spawn.getBlockX() >> 4, spawn.getBlockZ() >> 4, Math.max(0, radius >> 4));
        job.task = plugin.getServer().getScheduler().runTaskTimer(plugin, job, 1L, 1L);
        return "Generating " + job.total + " chunks in " + world.getName() + " (radius " + radius + " blocks around spawn).";
    }

    String stop() {
        if (job == null) {
            return "No pre-generation is running.";
        }
        String message = "Stopped at " + job.progress() + ".";
        job.finish();
        return message;
    }

    String status() {
        return job == null ? "idle" : job.world.getName() + " " + job.progress() + (job.paused ? " (paused, server busy)" : "");
    }

    private final class Job implements Runnable {
        final World world;
        final int centerX;
        final int centerZ;
        final int radius;
        final long total;
        final AtomicLong done = new AtomicLong();
        final AtomicInteger inFlight = new AtomicInteger();
        final long started = System.nanoTime();
        BukkitTask task;
        boolean paused;
        long lastReport = System.nanoTime();

        // Spiral state: ring r, position i along the ring's perimeter of 8r cells.
        int ring;
        int index;

        Job(World world, int centerX, int centerZ, int radius) {
            this.world = world;
            this.centerX = centerX;
            this.centerZ = centerZ;
            this.radius = radius;
            long side = 2L * radius + 1;
            this.total = side * side;
        }

        @Override
        public void run() {
            paused = PaperSupport.averageTickTime(monitor) > pauseAboveMspt;
            if (!paused) {
                // Already-generated chunks are cheap to skip, but cap the work per tick anyway.
                int budget = 512;
                while (inFlight.get() < parallel && budget-- > 0 && ring <= radius) {
                    int[] offset = next();
                    int x = centerX + offset[0];
                    int z = centerZ + offset[1];
                    if (world.isChunkGenerated(x, z)) {
                        done.incrementAndGet();
                        continue;
                    }
                    inFlight.incrementAndGet();
                    world.getChunkAtAsync(x, z, true).whenComplete((chunk, error) -> {
                        inFlight.decrementAndGet();
                        done.incrementAndGet();
                    });
                }
            }
            if (ring > radius && inFlight.get() == 0) {
                plugin.getLogger().info("Pre-generation of " + world.getName() + " finished: " + progress());
                finish();
                return;
            }
            if (System.nanoTime() - lastReport > 15_000_000_000L) {
                lastReport = System.nanoTime();
                plugin.getLogger().info("Pre-generating " + world.getName() + ": " + progress() + (paused ? " (paused, server busy)" : ""));
            }
        }

        private int[] next() {
            int[] offset;
            if (ring == 0) {
                offset = new int[] {0, 0};
                ring = 1;
                index = 0;
                return offset;
            }
            int side = 2 * ring;
            int i = index;
            if (i < side) {
                offset = new int[] {-ring + i, -ring};             // top edge, left to right
            } else if (i < 2 * side) {
                offset = new int[] {ring, -ring + (i - side)};     // right edge, top to bottom
            } else if (i < 3 * side) {
                offset = new int[] {ring - (i - 2 * side), ring};  // bottom edge, right to left
            } else {
                offset = new int[] {-ring, ring - (i - 3 * side)}; // left edge, bottom to top
            }
            if (++index == 4 * side) {
                ring++;
                index = 0;
            }
            return offset;
        }

        String progress() {
            long d = done.get();
            double seconds = (System.nanoTime() - started) / 1e9;
            double rate = seconds > 0 ? d / seconds : 0;
            return String.format("%d/%d chunks (%.1f%%, %.0f chunks/s)", d, total, 100.0 * d / total, rate);
        }

        void finish() {
            if (task != null) {
                task.cancel();
            }
            job = null;
        }
    }
}
