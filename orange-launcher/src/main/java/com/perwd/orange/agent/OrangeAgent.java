package com.perwd.orange.agent;

import com.perwd.orange.launcher.Log;
import java.io.IOException;
import java.io.InputStream;
import java.lang.instrument.Instrumentation;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.jar.JarFile;

/**
 * Java agent attached by the launcher with {@code -javaagent:orange.jar}. It can also be attached
 * by hand to any server start command, e.g. in a Forge/NeoForge {@code user_jvm_args.txt}.
 *
 * <p>Using an agent instead of a custom class loader is what lets Orange sit on top of Paper,
 * Purpur, Fabric and friends unchanged: every class any loader defines passes through our
 * transformer.
 */
public final class OrangeAgent {
    private OrangeAgent() {
    }

    public static void premain(String args, Instrumentation inst) {
        Path home = Path.of(System.getProperty("orange.home", ".")).toAbsolutePath();
        try {
            Path hooks = extractHooks(home);
            // Bootstrap visibility: patched game classes can reach OrangeHooks from any class loader.
            inst.appendToBootstrapClassLoaderSearch(new JarFile(hooks.toFile()));
        } catch (IOException e) {
            Log.error("Could not set up Orange hooks; the agent is disabled", e);
            return;
        }

        PatchRegistry registry = new PatchRegistry();
        registry.register(new BrandingPatch());
        if (!Boolean.getBoolean("orange.mods.disable")) {
            new ModLoader(home.resolve("orange-mods"), registry).loadAll();
        }
        inst.addTransformer(new OrangeTransformer(registry), false);
        Log.info("Agent ready: " + registry.size() + " patch(es) registered.");
    }

    private static Path extractHooks(Path home) throws IOException {
        Path target = home.resolve(".orange").resolve("cache").resolve("orange-hooks.jar");
        try (InputStream in = OrangeAgent.class.getResourceAsStream("/META-INF/orange/orange-hooks.jar")) {
            if (in == null) {
                throw new IOException("orange-hooks.jar is missing from orange.jar");
            }
            Files.createDirectories(target.getParent());
            Path tmp = Files.createTempFile(target.getParent(), "orange-hooks", ".tmp");
            Files.copy(in, tmp, StandardCopyOption.REPLACE_EXISTING);
            Files.move(tmp, target, StandardCopyOption.REPLACE_EXISTING);
        }
        return target;
    }
}
