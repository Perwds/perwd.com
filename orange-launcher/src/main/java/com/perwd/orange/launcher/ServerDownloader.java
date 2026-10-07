package com.perwd.orange.launcher;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.security.DigestInputStream;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.yaml.snakeyaml.LoaderOptions;
import org.yaml.snakeyaml.Yaml;
import org.yaml.snakeyaml.constructor.SafeConstructor;

/**
 * Downloads and updates the server jar, so {@code orange.jar} is all a user needs.
 *
 * <p>Sources: the Orange server (this project's own Paper fork, published as a GitHub release by
 * the orange-server workflow), Paper (PaperMC's Fill API) and Purpur (Purpur's API).
 *
 * <p>Picks the newest stable build of the newest Minecraft version that runs on this Java
 * (1.x needs Java 21, 26.x needs Java 25), and verifies its checksum. Updates only ever move to
 * newer builds of the installed Minecraft version: changing the Minecraft version upgrades the
 * world, which can't be undone, so that only happens when {@code minecraft-version} is changed.
 */
final class ServerDownloader {
    private static final String USER_AGENT = "Orange/" + OrangeLauncher.version() + " (https://github.com/Perwds/perwd.com)";
    private static final Duration TIMEOUT = Duration.ofSeconds(20);
    static final String ORANGE_MANIFEST =
            "https://github.com/Perwds/perwd.com/releases/download/orange-server/orange-server.json";

    private final Path home;
    private final String project;
    private final String wantedVersion;
    private final Path stateFile;
    private final HttpClient http = HttpClient.newBuilder().connectTimeout(TIMEOUT)
            .followRedirects(HttpClient.Redirect.NORMAL).build();

    ServerDownloader(Path home, String project, String wantedVersion) {
        this.home = home;
        this.project = project.toLowerCase(Locale.ROOT);
        this.wantedVersion = wantedVersion;
        this.stateFile = home.resolve(".orange").resolve("download.properties");
    }

    /** What Orange downloaded before, whichever server it was: {project, version, file}, or null. */
    String[] previousDownload() {
        Properties state = state();
        String file = state.getProperty("file");
        if (file == null || !Files.isRegularFile(home.resolve(file))) {
            return null;
        }
        return new String[] {state.getProperty("project"), state.getProperty("version"), file};
    }

    /** Minecraft versions this server is available for. */
    List<String> availableVersions() throws IOException, InterruptedException {
        if (project.equals("orange")) {
            return new ArrayList<>(asMap(json(ORANGE_MANIFEST).get("versions")).keySet());
        }
        return List.of(newestUsableVersion());
    }

    /** The jar Orange downloaded earlier, if it's still there. */
    Path installed() {
        Properties state = state();
        String file = state.getProperty("file");
        if (file == null || !project.equals(state.getProperty("project"))) {
            return null;
        }
        Path jar = home.resolve(file);
        return Files.isRegularFile(jar) ? jar : null;
    }

    /** Downloads the server, or updates the one Orange downloaded before. Returns the jar to run. */
    Path ensure(boolean update) throws IOException, InterruptedException {
        Path current = installed();
        Properties state = state();
        String installedVersion = current == null ? null : state.getProperty("version");

        String version;
        if (!wantedVersion.equalsIgnoreCase("latest")) {
            version = wantedVersion;
        } else if (installedVersion != null) {
            version = installedVersion; // never jump Minecraft versions on its own
        } else {
            version = newestUsableVersion();
        }
        if (current != null && !update && version.equals(installedVersion)) {
            return current;
        }

        Build build = latestBuild(version);
        if (current != null && version.equals(installedVersion) && build.id().equals(state.getProperty("build"))) {
            return current; // already up to date
        }
        Path target = home.resolve(build.fileName());
        Log.info((current == null ? "Downloading " : "Updating to ") + displayName() + " " + version
                + " build " + build.id() + "...");
        download(build, target);
        if (current != null && !current.equals(target)) {
            Files.deleteIfExists(current);
        }
        state.setProperty("project", project);
        state.setProperty("version", version);
        state.setProperty("build", build.id());
        state.setProperty("file", build.fileName());
        Files.createDirectories(stateFile.getParent());
        try (OutputStream out = Files.newOutputStream(stateFile)) {
            state.store(out, "Server jar Orange downloaded and keeps updated");
        }
        Log.info("Downloaded " + build.fileName());
        return target;
    }

    private String displayName() {
        return project.substring(0, 1).toUpperCase(Locale.ROOT) + project.substring(1);
    }

    private record Build(String id, String fileName, URI url, String algorithm, String checksum) {
    }

    private String newestUsableVersion() throws IOException, InterruptedException {
        List<String> versions = new ArrayList<>();
        if (project.equals("orange")) {
            versions.addAll(asMap(json(ORANGE_MANIFEST).get("versions")).keySet());
        } else if (project.equals("purpur")) {
            versions.addAll(stringList(json("https://api.purpurmc.org/v2/purpur").get("versions")));
        } else {
            Object grouped = json(fill("")).get("versions");
            if (grouped instanceof Map<?, ?> m) {
                for (Object group : m.values()) {
                    versions.addAll(stringList(group));
                }
            }
        }
        int java = Runtime.version().feature();
        return versions.stream()
                .filter(v -> v.matches("[0-9.]+"))                 // no pre-releases / RCs
                .filter(v -> v.startsWith("1.") || java >= 25)     // 26.x needs Java 25
                .max(Comparator.comparing(ServerDownloader::versionKey, ServerDownloader::compareKeys))
                .orElseThrow(() -> new LauncherException("No " + displayName() + " version found for Java " + java + "."));
    }

    private Build latestBuild(String version) throws IOException, InterruptedException {
        if (project.equals("orange")) {
            Map<String, Object> build = asMap(asMap(json(ORANGE_MANIFEST).get("versions")).get(version));
            if (build.isEmpty()) {
                throw new LauncherException("There's no Orange server for Minecraft " + version + " yet.");
            }
            return new Build(String.valueOf(build.get("build")), String.valueOf(build.get("file")),
                    URI.create(String.valueOf(build.get("url"))), "SHA-256", String.valueOf(build.get("sha256")));
        }
        if (project.equals("purpur")) {
            String base = "https://api.purpurmc.org/v2/purpur/" + version;
            Object latest = asMap(json(base).get("builds")).get("latest");
            String id = String.valueOf(latest);
            Object md5 = json(base + "/" + id).get("md5");
            return new Build(id, "purpur-" + version + "-" + id + ".jar", URI.create(base + "/" + id + "/download"),
                    md5 == null ? null : "MD5", md5 == null ? null : String.valueOf(md5));
        }
        Map<String, Object> build = json(fill("/versions/" + version + "/builds/latest"));
        if (!"STABLE".equalsIgnoreCase(String.valueOf(build.get("channel")))) {
            Log.warn(displayName() + " " + version + " has no stable build yet; using the newest one ("
                    + build.get("channel") + ").");
        }
        Map<String, Object> download = asMap(asMap(build.get("downloads")).get("server:default"));
        Object sha256 = asMap(download.get("checksums")).get("sha256");
        return new Build(String.valueOf(build.get("id")), String.valueOf(download.get("name")),
                URI.create(String.valueOf(download.get("url"))),
                sha256 == null ? null : "SHA-256", sha256 == null ? null : String.valueOf(sha256));
    }

    private String fill(String path) {
        return "https://fill.papermc.io/v3/projects/" + project + path;
    }

    private void download(Build build, Path target) throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder(build.url()).header("User-Agent", USER_AGENT)
                .timeout(Duration.ofMinutes(5)).build();
        HttpResponse<InputStream> response = http.send(request, HttpResponse.BodyHandlers.ofInputStream());
        if (response.statusCode() != 200) {
            throw new IOException("download failed: HTTP " + response.statusCode() + " from " + build.url());
        }
        Path tmp = target.resolveSibling(target.getFileName() + ".part");
        MessageDigest digest = digest(build.algorithm());
        try (InputStream in = digest == null ? response.body() : new DigestInputStream(response.body(), digest)) {
            Files.copy(in, tmp, StandardCopyOption.REPLACE_EXISTING);
        }
        if (digest != null) {
            String actual = HexFormat.of().formatHex(digest.digest());
            if (!actual.equalsIgnoreCase(build.checksum())) {
                Files.deleteIfExists(tmp);
                throw new IOException("checksum mismatch for " + build.fileName() + " (expected " + build.checksum()
                        + ", got " + actual + ")");
            }
        }
        Files.move(tmp, target, StandardCopyOption.REPLACE_EXISTING);
    }

    private static MessageDigest digest(String algorithm) {
        if (algorithm == null) {
            return null;
        }
        try {
            return MessageDigest.getInstance(algorithm);
        } catch (NoSuchAlgorithmException e) {
            return null;
        }
    }

    private Map<String, Object> json(String url) throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder(URI.create(url)).header("User-Agent", USER_AGENT)
                .header("Accept", "application/json").timeout(TIMEOUT).build();
        HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new IOException("HTTP " + response.statusCode() + " from " + url);
        }
        // JSON is valid YAML, and SnakeYAML is already on board.
        return asMap(new Yaml(new SafeConstructor(new LoaderOptions())).load(response.body()));
    }

    @SuppressWarnings("unchecked")
    private static Map<String, Object> asMap(Object o) {
        return o instanceof Map<?, ?> m ? (Map<String, Object>) m : Map.of();
    }

    private static List<String> stringList(Object o) {
        List<String> out = new ArrayList<>();
        if (o instanceof List<?> l) {
            for (Object x : l) {
                out.add(String.valueOf(x));
            }
        }
        return out;
    }

    private Properties state() {
        Properties p = new Properties();
        if (Files.exists(stateFile)) {
            try (InputStream in = Files.newInputStream(stateFile)) {
                p.load(in);
            } catch (IOException ignored) {
                // treat as nothing downloaded
            }
        }
        return p;
    }

    private static final Pattern NUMBER = Pattern.compile("\\d+");

    private static List<Integer> versionKey(String v) {
        List<Integer> key = new ArrayList<>();
        Matcher m = NUMBER.matcher(v);
        while (m.find()) {
            key.add(Integer.parseInt(m.group()));
        }
        return key;
    }

    private static int compareKeys(List<Integer> a, List<Integer> b) {
        for (int i = 0; i < Math.max(a.size(), b.size()); i++) {
            int x = i < a.size() ? a.get(i) : 0;
            int y = i < b.size() ? b.get(i) : 0;
            if (x != y) {
                return Integer.compare(x, y);
            }
        }
        return 0;
    }
}
