package com.perwd.orange.agent;

import com.perwd.orange.api.OrangePatch;
import com.perwd.orange.launcher.Log;
import java.lang.instrument.ClassFileTransformer;
import java.security.ProtectionDomain;
import java.util.List;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;
import org.objectweb.asm.tree.ClassNode;

final class OrangeTransformer implements ClassFileTransformer {
    private final PatchRegistry registry;

    OrangeTransformer(PatchRegistry registry) {
        this.registry = registry;
    }

    @Override
    public byte[] transform(ClassLoader loader, String className, Class<?> redefined,
                            ProtectionDomain domain, byte[] bytes) {
        if (className == null) {
            return null;
        }
        List<OrangePatch> patches = registry.forClass(className);
        if (patches.isEmpty()) {
            return null;
        }
        byte[] current = bytes;
        boolean changed = false;
        // Each patch works on a fresh parse of the last good bytes, so a patch that throws
        // halfway can't leave a half-edited class behind.
        for (OrangePatch patch : patches) {
            try {
                ClassNode node = new ClassNode();
                new ClassReader(current).accept(node, 0);
                if (!patch.apply(node)) {
                    Log.warn("Patch " + patch.id() + " did not match " + className.replace('/', '.') + " (different version or mappings?); skipped.");
                    continue;
                }
                ClassWriter writer = patch.requiresFrames()
                        ? new HierarchyClassWriter(loader, ClassWriter.COMPUTE_FRAMES)
                        : new ClassWriter(ClassWriter.COMPUTE_MAXS);
                node.accept(writer);
                current = writer.toByteArray();
                changed = true;
                Log.info("Applied patch " + patch.id() + " to " + className.replace('/', '.'));
            } catch (Throwable t) {
                Log.error("Patch " + patch.id() + " failed on " + className + "; skipped", t);
            }
        }
        return changed ? current : null;
    }
}
