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
        int pendingFiles = 0;
        for (Map.Entry<String, Map<String, String>> entry : settings.entrySet()) {
            String name = entry.getKey();
            Path file = home.resolve(name);
            // State is tracked per key: a key is applied once per wanted value, so the user's later
            // edits stick, while a key the file doesn't have yet (e.g. not generated until the
            // server's first start) is retried on every launch until it shows up.
            Map<String, String> pending = new java.util.LinkedHashMap<>();
            entry.getValue().forEach((key, value) -> {
                if (!value.equals(state.getProperty(name + "|" + key))) {
                    pending.put(key, value);
                }
            });
            if (pending.isEmpty()) {
                continue;
            }
            if (Files.notExists(file)) {
                pendingFiles++;
                continue;
            }
            List<String> lines = Files.readAllLines(file, StandardCharsets.UTF_8);
            LineConfigEditor.Result result = name.endsWith(".properties")
                    ? LineConfigEditor.editProperties(lines, pending)
                    : LineConfigEditor.editYaml(lines, pending);
            if (result.changed() > 0 && !dryRun) {
                backup(file, name);
                Files.write(file, result.lines(), StandardCharsets.UTF_8);
            }
            List<String> newlyMissing = new java.util.ArrayList<>();
            for (Map.Entry<String, String> p : pending.entrySet()) {
                String stateKey = name + "|" + p.getKey();
                if (result.found().contains(p.getKey())) {
                    state.setProperty(stateKey, p.getValue());
                } else if (!("missing:" + p.getValue()).equals(state.getProperty(stateKey))) {
                    newlyMissing.add(p.getKey());
                    state.setProperty(stateKey, "missing:" + p.getValue());
                }
            }
            if (result.found().isEmpty() && newlyMissing.isEmpty()) {
                continue; // only keys we already reported as missing; stay quiet
            }
            Log.info((dryRun ? "Would tune " : "Tuned ") + name + " (" + id + "): " + result.changed() + " changed, "
                    + result.unchanged() + " already optimal"
                    + (newlyMissing.isEmpty() ? "" : ", " + newlyMissing.size() + " not present in this version"));
            if (!newlyMissing.isEmpty()) {
                Log.info("  not present in " + name + ": " + String.join(", ", newlyMissing));
            }
        }
        if (!dryRun) {
            saveState(state);
        }
        if (pendingFiles > 0) {
            Log.info(pendingFiles + " config file(s) don't exist yet; they'll be tuned on the next start after the server creates them.");
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
            p.store(out, "Config values Orange has applied (file|key=value). Delete a line to re-apply it.");
        }
    }
}
