package com.perwd.orange.launcher;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.List;
import java.util.stream.Stream;

/**
 * JVM class cache for faster starts. Only works when the server is on the normal class path
 * (see {@link DirectLaunch}).
 *
 * <ul>
 *   <li>Java 25+: the AOT cache (JEP 483/514/515). The first start records which classes load
 *       and how hot code behaves; later starts get those classes pre-parsed, pre-linked and
 *       with JIT profiles ready.</li>
 *   <li>Java 21-24: dynamic AppCDS, which caches the parsed classes.</li>
 * </ul>
 *
 * The cache file is keyed by the Java version and the exact class path, so updating the server
 * or Java simply records a new one.
 */
final class StartupCache {
    private StartupCache() {
    }

    static List<String> flags(Path home, DirectLaunch launch, Path agentJar) throws IOException {
        Path dir = home.resolve(".orange").resolve("cache").resolve("jvm");
        Files.createDirectories(dir);
        String key = key(launch, agentJar);
        boolean aot = Runtime.version().feature() >= 25;
        Path file = dir.resolve(key + (aot ? ".aot" : ".jsa"));
        removeStale(dir, file);
        // The JVM refuses to write a class cache while a Java agent is attached unless told it may.
        List<String> agentFlags = new java.util.ArrayList<>(agentJar == null ? List.of()
                : List.of("-XX:+UnlockDiagnosticVMOptions", "-XX:+AllowArchivingWithJavaAgent"));
        // Writing the cache lists every class it can't store (signed jars, proxies, ...) as a
        // warning: hundreds of harmless lines at the first shutdown. Keep errors only.
        agentFlags.add("-Xlog:cds=error");
        if (aot) {
            agentFlags.add("-Xlog:aot=error");
        }
        if (!aot) {
            return concat(agentFlags, List.of("-XX:+AutoCreateSharedArchive", "-XX:SharedArchiveFile=" + file));
        }
        if (Files.isRegularFile(file)) {
            return concat(agentFlags, List.of("-XX:AOTCache=" + file));
        }
        Log.info("Recording a startup cache during this run; the next start will be faster.");
        return concat(agentFlags, List.of("-XX:AOTCacheOutput=" + file));
    }

    private static List<String> concat(List<String> a, List<String> b) {
        List<String> out = new java.util.ArrayList<>(a);
        out.addAll(b);
        return out;
    }

    private static String key(DirectLaunch launch, Path agentJar) throws IOException {
        try {
            MessageDigest sha = MessageDigest.getInstance("SHA-256");
            sha.update(Runtime.version().toString().getBytes(StandardCharsets.UTF_8));
            for (Path p : launch.classpath()) {
                sha.update((p + "|" + Files.size(p) + "|" + Files.getLastModifiedTime(p).toMillis()).getBytes(StandardCharsets.UTF_8));
            }
            if (agentJar != null) {
                sha.update((agentJar + "|" + Files.size(agentJar) + "|" + Files.getLastModifiedTime(agentJar).toMillis())
                        .getBytes(StandardCharsets.UTF_8));
            }
            return "server-" + HexFormat.of().formatHex(sha.digest(), 0, 8);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static void removeStale(Path dir, Path keep) throws IOException {
        try (Stream<Path> files = Files.list(dir)) {
            for (Path f : files.toList()) {
                if (!f.equals(keep) && f.getFileName().toString().startsWith("server-")) {
                    Files.deleteIfExists(f);
                }
            }
        }
    }
}
