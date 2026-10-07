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
 * Applies a {@link Profile} to the server's config files once per file per profile, backing up
 * the original first. After that, the user's own edits win.
 */
public final class ConfigOptimizer {
    private final Path home;
    private final Profile profile;
    private final Path stateFile;
    private final boolean dryRun;

    public ConfigOptimizer(Path home, Profile profile, boolean dryRun) {
        this.home = home;
        this.profile = profile;
        this.dryRun = dryRun;
        this.stateFile = home.resolve(".orange").resolve("optimizer-state.properties");
    }

    public void run() throws IOException {
        Properties state = loadState();
        int pending = 0;
        for (Map.Entry<String, Map<String, String>> entry : profile.settings().entrySet()) {
            String name = entry.getKey();
            Path file = home.resolve(name);
            if (profile.id().equals(state.getProperty(name))) {
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
            int skipped = entry.getValue().size() - result.changed() - result.unchanged();
            Log.info((dryRun ? "Would tune " : "Tuned ") + name + " (" + profile.id() + "): " + result.changed() + " changed, "
                    + result.unchanged() + " already optimal" + (skipped > 0 ? ", " + skipped + " not present in this version" : ""));
            state.setProperty(name, profile.id());
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
