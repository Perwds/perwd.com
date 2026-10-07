package com.perwd.orange.agent;

import com.perwd.orange.api.ModContext;
import com.perwd.orange.api.ModInfo;
import com.perwd.orange.api.ModLogger;
import com.perwd.orange.api.OrangeMod;
import com.perwd.orange.api.OrangePatch;
import com.perwd.orange.launcher.Log;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.net.URL;
import java.net.URLClassLoader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Properties;
import java.util.Set;
import java.util.jar.JarFile;
import java.util.stream.Stream;

/**
 * Loads Orange mods: jars in {@code orange-mods/} with an {@code orange.mod.properties} file.
 *
 * <pre>
 * id=my-mod
 * name=My Mod
 * version=1.0.0
 * entrypoint=com.example.MyMod          # optional, implements OrangeMod
 * patches=com.example.FastHopperPatch   # optional, comma separated, implement OrangePatch
 * </pre>
 */
final class ModLoader {
    private static final String DESCRIPTOR = "orange.mod.properties";

    private final Path directory;
    private final PatchRegistry registry;

    ModLoader(Path directory, PatchRegistry registry) {
        this.directory = directory;
        this.registry = registry;
    }

    void loadAll() {
        List<Path> jars;
        try {
            Files.createDirectories(directory);
            try (Stream<Path> files = Files.list(directory)) {
                jars = files.filter(p -> p.toString().endsWith(".jar")).sorted().toList();
            }
        } catch (IOException e) {
            Log.error("Could not read " + directory, e);
            return;
        }
        if (jars.isEmpty()) {
            return;
        }

        List<Candidate> candidates = new ArrayList<>();
        Set<String> ids = new HashSet<>();
        for (Path jar : jars) {
            try {
                Candidate c = read(jar);
                if (c == null) {
                    Log.warn(jar.getFileName() + " has no " + DESCRIPTOR + "; not an Orange mod, skipped.");
                } else if (!ids.add(c.info.id())) {
                    Log.warn("Duplicate mod id '" + c.info.id() + "' in " + jar.getFileName() + "; skipped.");
                } else {
                    candidates.add(c);
                }
            } catch (IOException | IllegalArgumentException e) {
                Log.error("Could not read mod " + jar.getFileName(), e);
            }
        }

        // One shared loader so mods can use each other's classes.
        URL[] urls = candidates.stream().map(c -> toUrl(c.info.source())).toArray(URL[]::new);
        URLClassLoader loader = new URLClassLoader("orange-mods", urls, OrangeAgent.class.getClassLoader());
        for (Candidate c : candidates) {
            try {
                Context context = new Context(c.info, directory);
                for (String patchClass : c.patches) {
                    context.registerPatch(instantiate(loader, patchClass, OrangePatch.class));
                }
                if (c.entrypoint != null) {
                    instantiate(loader, c.entrypoint, OrangeMod.class).onLoad(context);
                }
                Log.info("Loaded mod " + c.info.name() + " " + c.info.version());
            } catch (Throwable t) {
                Log.error("Mod " + c.info.id() + " failed to load", t);
            }
        }
    }

    private Candidate read(Path jar) throws IOException {
        try (JarFile file = new JarFile(jar.toFile())) {
            var entry = file.getJarEntry(DESCRIPTOR);
            if (entry == null) {
                return null;
            }
            Properties p = new Properties();
            try (InputStream in = file.getInputStream(entry)) {
                p.load(in);
            }
            String id = p.getProperty("id", "").trim();
            if (!id.matches("[a-z0-9_\\-]+")) {
                throw new IllegalArgumentException("id must be lowercase letters, digits, - or _ (got '" + id + "')");
            }
            ModInfo info = new ModInfo(id, p.getProperty("name", id).trim(), p.getProperty("version", "0").trim(), jar);
            String entrypoint = p.getProperty("entrypoint", "").trim();
            List<String> patches = new ArrayList<>();
            for (String s : p.getProperty("patches", "").split(",")) {
                if (!s.isBlank()) {
                    patches.add(s.trim());
                }
            }
            return new Candidate(info, entrypoint.isEmpty() ? null : entrypoint, patches);
        }
    }

    private static <T> T instantiate(ClassLoader loader, String name, Class<T> type) throws ReflectiveOperationException {
        Class<?> cls = Class.forName(name, true, loader);
        if (!type.isAssignableFrom(cls)) {
            throw new ClassCastException(name + " does not implement " + type.getName());
        }
        return type.cast(cls.getDeclaredConstructor().newInstance());
    }

    private static URL toUrl(Path p) {
        try {
            return p.toUri().toURL();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private record Candidate(ModInfo info, String entrypoint, List<String> patches) {
    }

    private final class Context implements ModContext {
        private final ModInfo info;
        private final Path data;
        private final ModLogger logger;

        Context(ModInfo info, Path modsDir) {
            this.info = info;
            this.data = modsDir.resolve(info.id());
            String prefix = info.id() + ": ";
            this.logger = new ModLogger() {
                @Override
                public void info(String message) {
                    Log.info(prefix + message);
                }

                @Override
                public void warn(String message) {
                    Log.warn(prefix + message);
                }

                @Override
                public void error(String message, Throwable error) {
                    Log.error(prefix + message, error);
                }
            };
        }

        @Override
        public ModInfo info() {
            return info;
        }

        @Override
        public ModLogger logger() {
            return logger;
        }

        @Override
        public Path dataDirectory() {
            try {
                return Files.createDirectories(data);
            } catch (IOException e) {
                throw new UncheckedIOException(e);
            }
        }

        @Override
        public void registerPatch(OrangePatch patch) {
            registry.register(patch);
        }
    }
}
