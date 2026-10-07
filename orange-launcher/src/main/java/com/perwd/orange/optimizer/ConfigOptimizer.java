package com.perwd.orange.optimizer;

import com.perwd.orange.launcher.Log;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.Properties;

/**
 * Applies a {@link Profile} and {@link PingTolerance} to the server's config files once per file per profile, backing up
 * the original first. After that, the user's own edits win.
 */
public final class ConfigOptimizer {
    private final Path home;
    private final String id;
    private final Map<String, Map<String, String>> settings;
    private final Path stateFile;
    private final boolean dryRun;

    public ConfigOptimizer(Path home, Profile profile, PingTolerance ping, boolean dryRun) {
        this.home = home;
        this.id = profile.id() + "+ping-" + ping.id();
        this.settings = new java.util.LinkedHashMap<>(profile.settings());
        ping.settings().forEach((file, values) ->
                settings.computeIfAbsent(file, k -> new java.util.LinkedHashMap<>()).putAll(values));
        this.dryRun = dryRun;
        this.stateFile = home.resolve(".orange").resolve("optimizer-state.properties");
    }

    public void run() throws IOException {
        Properties state = loadState();
        int pending = 0;
        for (Map.Entry<String, Map<String, String>> entry : settings.entrySet()) {
            String name = entry.getKey();
            Path file = home.resolve(name);
            if (id.equals(state.getProperty(name))) {
                continue;
            }
            if (Files.notExists(file)) {
                pending++;
                continue;
            }
            List<String> lines = Files.readAllLines(file, StandardCharsets.UTF_8);
            LineConfigEditor.Result result = name.endsWith(".properties")
                    ? LineConfigEditor.editProperties(lines, entry.getValue())
                    : LineConfigEditor.editYaml(lines, entry.getValue());
            if (result.changed() > 0 && !dryRun) {
                backup(file, name);
                Files.write(file, result.lines(), StandardCharsets.UTF_8);
            }
            List<String> missing = entry.getValue().keySet().stream().filter(k -> !result.found().contains(k)).toList();
            Log.info((dryRun ? "Would tune " : "Tuned ") + name + " (" + id + "): " + result.changed() + " changed, "
                    + result.unchanged() + " already optimal" + (missing.isEmpty() ? "" : ", " + missing.size() + " not present in this version"));
            if (!missing.isEmpty()) {
                Log.info("  not present in " + name + ": " + String.join(", ", missing));
            }
            state.setProperty(name, id);
        }
        if (!dryRun) {
            saveState(state);
        }
        if (pending > 0) {
            Log.info(pending + " config file(s) don't exist yet; they'll be tuned on the next start after the server creates them.");
        }
    }

    private void backup(Path file, String name) throws IOException {
        String stamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss"));
        Path target = home.resolve(".orange").resolve("backups").resolve(name + "." + stamp);
        Files.createDirectories(target.getParent());
        Files.copy(file, target);
    }

    private Properties loadState() throws IOException {
        Properties p = new Properties();
        if (Files.exists(stateFile)) {
            try (InputStream in = Files.newInputStream(stateFile)) {
                p.load(in);
            }
        }
        return p;
    }

    private void saveState(Properties p) throws IOException {
        Files.createDirectories(stateFile.getParent());
        try (OutputStream out = Files.newOutputStream(stateFile)) {
            p.store(out, "Which Orange profile has been applied to each config file. Delete a line to re-apply.");
        }
    }
}
