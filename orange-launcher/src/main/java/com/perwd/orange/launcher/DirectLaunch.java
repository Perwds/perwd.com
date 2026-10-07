package com.perwd.orange.launcher;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Properties;
import java.util.concurrent.TimeUnit;
import java.util.jar.JarFile;
import java.util.zip.ZipEntry;

/**
 * Starts a Paperclip server (Paper, Purpur, Pufferfish, ...) straight from the files Paperclip
 * unpacked, instead of through Paperclip itself.
 *
 * <p>Paperclip re-hashes the whole server and every library on each start, then loads the game
 * through its own class loader, which the JVM can't cache. Launching the unpacked jars on the
 * normal class path skips the hashing and lets the JVM's class cache (AOT cache / AppCDS) work.
 * Paperclip still runs whenever the server jar changes, so updates are unpacked as usual.
 */
record DirectLaunch(List<Path> classpath, String mainClass) {
    private static final String MARKER = "paperclip.properties";

    /** The direct launch for {@code serverJar}, or {@code null} to fall back to {@code java -jar}. */
    static DirectLaunch prepare(Path home, Path serverJar, String javaBinary, boolean dryRun) {
        try (JarFile jar = new JarFile(serverJar.toFile())) {
            if (jar.getEntry("META-INF/patches.list") == null || jar.getEntry("META-INF/versions.list") == null
                    || jar.getEntry("META-INF/main-class") == null) {
                return null; // not a Paperclip jar
            }
            String mainClass = read(jar, "META-INF/main-class").getFirst().trim();
            List<Path> classpath = new ArrayList<>();
            for (String line : read(jar, "META-INF/versions.list")) {
                classpath.add(home.resolve("versions").resolve(path(line)));
            }
            for (String line : read(jar, "META-INF/libraries.list")) {
                classpath.add(home.resolve("libraries").resolve(path(line)));
            }
            DirectLaunch launch = new DirectLaunch(classpath, mainClass);

            Path marker = home.resolve(".orange").resolve("cache").resolve(MARKER);
            String fingerprint = fingerprint(serverJar);
            if (fingerprint.equals(readMarker(marker)) && launch.filesPresent()) {
                return launch;
            }
            if (dryRun) {
                Log.info("Paperclip hasn't unpacked " + serverJar.getFileName() + " yet; the first start will.");
                return null;
            }
            // New or updated server jar: let Paperclip download, patch and unpack it, then stop.
            Log.info("Unpacking " + serverJar.getFileName() + " (only after the server jar changes)...");
            Process p = new ProcessBuilder(javaBinary, "-Dpaperclip.patchonly=true", "-jar", serverJar.toString())
                    .directory(home.toFile()).inheritIO().start();
            if (!p.waitFor(15, TimeUnit.MINUTES)) {
                p.destroyForcibly();
                Log.warn("Paperclip did not finish unpacking; starting the normal way.");
                return null;
            }
            if (p.exitValue() != 0 || !launch.filesPresent()) {
                Log.warn("Paperclip unpacking failed (exit " + p.exitValue() + "); starting the normal way.");
                return null;
            }
            writeMarker(marker, fingerprint);
            return launch;
        } catch (IOException | RuntimeException e) {
            Log.warn("Can't launch " + serverJar.getFileName() + " directly (" + e.getMessage() + "); starting the normal way.");
            return null;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return null;
        }
    }

    String classpathString() {
        List<String> parts = new ArrayList<>();
        for (Path p : classpath) {
            parts.add(p.toString());
        }
        return String.join(java.io.File.pathSeparator, parts);
    }

    private boolean filesPresent() {
        for (Path p : classpath) {
            if (!Files.isRegularFile(p)) {
                return false;
            }
        }
        return true;
    }

    /** Lines look like {@code <sha256>\t<id>\t<relative path>}. */
    private static String path(String line) {
        String[] parts = line.split("\t");
        if (parts.length < 3) {
            throw new IllegalStateException("unexpected Paperclip list entry: " + line);
        }
        return parts[2].trim();
    }

    private static List<String> read(JarFile jar, String name) throws IOException {
        ZipEntry entry = jar.getEntry(name);
        List<String> lines = new ArrayList<>();
        if (entry == null) {
            return lines;
        }
        try (BufferedReader r = new BufferedReader(new InputStreamReader(jar.getInputStream(entry), StandardCharsets.UTF_8))) {
            for (String line = r.readLine(); line != null; line = r.readLine()) {
                if (!line.isBlank()) {
                    lines.add(line);
                }
            }
        }
        return lines;
    }

    private static String fingerprint(Path jar) throws IOException {
        return jar.toAbsolutePath() + "|" + Files.size(jar) + "|" + Files.getLastModifiedTime(jar).toMillis();
    }

    private static String readMarker(Path marker) {
        Properties p = new Properties();
        try (InputStream in = Files.newInputStream(marker)) {
            p.load(in);
            return p.getProperty("unpacked");
        } catch (IOException e) {
            return null;
        }
    }

    private static void writeMarker(Path marker, String fingerprint) throws IOException {
        Files.createDirectories(marker.getParent());
        Properties p = new Properties();
        p.setProperty("unpacked", fingerprint);
        try (OutputStream out = Files.newOutputStream(marker)) {
            p.store(out, "Server jar Paperclip last unpacked; Orange launches it directly while this matches.");
        }
    }
}
