package com.perwd.orange.agent;

import com.perwd.orange.api.OrangePatch;
import com.perwd.orange.api.Patches;
import java.util.Set;
import org.objectweb.asm.Handle;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.InsnList;
import org.objectweb.asm.tree.InvokeDynamicInsnNode;
import org.objectweb.asm.tree.MethodNode;

/**
 * Wraps {@code MinecraftServer#getServerModName()} so the server list and F3 show
 * "Orange (Paper)", "Orange (Purpur)", "Orange (fabric)", ... Works wherever the server
 * runs with Mojang names (Paper 1.20.5+, and every server from 26.1 on).
 *
 * <p>The new name is built with the JDK's own string concatenation ({@code invokedynamic} to
 * {@code StringConcatFactory}), so the patched class needs nothing from Orange at run time and
 * the agent doesn't have to touch the boot class path, which would switch off the JVM's class
 * cache.
 */
final class BrandingPatch implements OrangePatch {
    private static final Handle CONCAT_FACTORY = new Handle(Opcodes.H_INVOKESTATIC,
            "java/lang/invoke/StringConcatFactory", "makeConcatWithConstants",
            "(Ljava/lang/invoke/MethodHandles$Lookup;Ljava/lang/String;Ljava/lang/invoke/MethodType;"
                    + "Ljava/lang/String;[Ljava/lang/Object;)Ljava/lang/invoke/CallSite;", false);

    @Override
    public String id() {
        return "orange:branding";
    }

    @Override
    public Set<String> targets() {
        return Set.of("net.minecraft.server.MinecraftServer");
    }

    @Override
    public boolean apply(org.objectweb.asm.tree.ClassNode node) {
        MethodNode method = Patches.method(node, "getServerModName", "()Ljava/lang/String;");
        if (method == null || Patches.isAbstractOrNative(method)) {
            return false;
        }
        String recipe = System.getProperty("orange.brand", "Orange") + " (\u0001)";
        return Patches.injectBeforeReturns(method, Opcodes.ARETURN, () -> {
            InsnList code = new InsnList();
            code.add(new InvokeDynamicInsnNode("makeConcatWithConstants", "(Ljava/lang/String;)Ljava/lang/String;",
                    CONCAT_FACTORY, recipe));
            return code;
        }) > 0;
    }
}
