package com.perwd.orange.launcher;

import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/** Builds tuned JVM arguments. */
final class JvmFlags {
    private static final long MB = 1024L * 1024L;
    private static final long GB = 1024L * MB;

    private JvmFlags() {
    }

    /** Heap size in megabytes. */
    static long heapMegabytes(String memory) {
        if (!memory.equalsIgnoreCase("auto")) {
            return parseMegabytes(memory);
        }
        long total = totalMemoryBytes();
        long heap = Math.min((long) (total * 0.75), total - 2 * GB);
        // Stay under 32 GB so the JVM keeps compressed object pointers.
        heap = Math.min(heap, 30 * GB);
        heap = Math.max(heap, GB);
        return (heap / (512 * MB)) * 512; // round down to 512 MB
    }

    static long parseMegabytes(String value) {
        String v = value.trim().toUpperCase(Locale.ROOT);
        try {
            if (v.endsWith("G")) {
                return Math.round(Double.parseDouble(v.substring(0, v.length() - 1)) * 1024);
            }
            if (v.endsWith("M")) {
                return Long.parseLong(v.substring(0, v.length() - 1));
            }
            return Long.parseLong(v);
        } catch (NumberFormatException e) {
            throw new LauncherException("Invalid memory value '" + value + "' in orange.yml (use e.g. 6G or 6144M).");
        }
    }

    /** A plain non-negative whole number from orange.yml. */
    static long parseNonNegative(String value) {
        try {
            return Math.max(0, Long.parseLong(value.trim()));
        } catch (NumberFormatException e) {
            throw new LauncherException("Expected a number in orange.yml, got '" + value + "'.");
        }
    }

    static String resolveGc(String gc, long heapMb) {
        return switch (gc) {
            case "g1", "zgc" -> gc;
            case "auto" -> heapMb >= 16 * 1024 && Runtime.getRuntime().availableProcessors() >= 8 ? "zgc" : "g1";
            default -> throw new LauncherException("Unknown gc '" + gc + "' in orange.yml (use auto, g1 or zgc).");
        };
    }

    static List<String> build(long heapMb, String gc, ServerType type) {
        List<String> flags = new ArrayList<>();
        flags.add("-Xms" + heapMb + "M");
        flags.add("-Xmx" + heapMb + "M");
        if (gc.equals("zgc")) {
            flags.add("-XX:+UseZGC");
            // Generational ZGC is the default (and only mode) from JDK 23 on.
            if (Runtime.version().feature() < 23) {
                flags.add("-XX:+ZGenerational");
            }
        } else {
            flags.addAll(aikarG1(heapMb));
            // JEP 519: 8-byte object headers instead of 12. Minecraft allocates millions of small
            // objects (BlockPos, Vec3, ...), so this shrinks the live heap and improves cache hits.
            if (Runtime.version().feature() >= 25) {
                flags.add("-XX:+UseCompactObjectHeaders");
            }
        }
        // Huge pages cut TLB misses when the GC walks a multi-GB heap. Only when the kernel allows it,
        // so the JVM never prints a warning about it.
        if (transparentHugePagesAvailable()) {
            flags.add("-XX:+UseTransparentHugePages");
        }
        flags.add("-XX:+AlwaysPreTouch");
        flags.add("-XX:+DisableExplicitGC");
        flags.add("-XX:+PerfDisableSharedMem");
        flags.add("-XX:+UseStringDeduplication");
        // A Paper server JIT-compiles far more code than the 240 MB default cache comfortably holds,
        // and starts with ~200 MB of class metadata; both thresholds otherwise trigger extra GC pauses
        // (measured in CI: "CodeCache GC Threshold" / "Metadata GC Threshold" pauses of 20-50 ms).
        flags.add("-XX:ReservedCodeCacheSize=512m");
        flags.add("-XX:MetaspaceSize=256m");
        if (type.usesVectorApi()) {
            flags.add("--add-modules=jdk.incubator.vector");
        }
        return flags;
    }

    /** Aikar's flags: https://docs.papermc.io/paper/aikars-flags */
    private static List<String> aikarG1(long heapMb) {
        boolean large = heapMb >= 12 * 1024;
        return List.of(
                "-XX:+UseG1GC",
                "-XX:+ParallelRefProcEnabled",
                "-XX:MaxGCPauseMillis=200",
                "-XX:+UnlockExperimentalVMOptions",
                "-XX:G1NewSizePercent=" + (large ? 40 : 30),
                "-XX:G1MaxNewSizePercent=" + (large ? 50 : 40),
                "-XX:G1HeapRegionSize=" + (large ? "16M" : "8M"),
                "-XX:G1ReservePercent=" + (large ? 15 : 20),
                "-XX:G1HeapWastePercent=5",
                "-XX:G1MixedGCCountTarget=4",
                "-XX:InitiatingHeapOccupancyPercent=" + (large ? 20 : 15),
                "-XX:G1MixedGCLiveThresholdPercent=90",
                "-XX:G1RSetUpdatingPauseTimePercent=5",
                "-XX:SurvivorRatio=32",
                "-XX:MaxTenuringThreshold=1",
                "-Dusing.aikars.flags=https://mcflags.emc.gs",
                "-Daikars.new.flags=true");
    }

    static boolean transparentHugePagesAvailable() {
        try {
            String mode = Files.readString(Path.of("/sys/kernel/mm/transparent_hugepage/enabled"));
            return mode.contains("[always]") || mode.contains("[madvise]");
        } catch (IOException | SecurityException e) {
            return false;
        }
    }

    private static long totalMemoryBytes() {
        // Container-aware: reports the cgroup limit inside Docker/Pterodactyl.
        if (ManagementFactory.getOperatingSystemMXBean() instanceof com.sun.management.OperatingSystemMXBean os) {
            return os.getTotalMemorySize();
        }
        return 4 * GB;
    }
}
