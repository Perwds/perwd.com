package com.perwd.orange.api;

import java.util.Set;
import org.objectweb.asm.tree.ClassNode;

/**
 * A bytecode patch applied to a game class as it loads.
 *
 * <p>Patches must fail soft: if the method they target is missing (a different Minecraft
 * version, or a server that remaps names), return {@code false} and leave the class alone.
 */
public interface OrangePatch {
    /** Unique id used in logs, e.g. {@code "mymod:faster-hoppers"}. */
    String id();

    /** Fully qualified names of the classes this patch targets, e.g. {@code net.minecraft.server.MinecraftServer}. */
    Set<String> targets();

    /** Modifies {@code node} in place. Returns {@code true} if anything changed. */
    boolean apply(ClassNode node);

    /**
     * Return {@code true} if the patch changes control flow or local variables so that stack map
     * frames must be recomputed. Prefer patches that don't: frame computation has to look up
     * class hierarchies and is slower and more fragile.
     */
    default boolean requiresFrames() {
        return false;
    }
}
