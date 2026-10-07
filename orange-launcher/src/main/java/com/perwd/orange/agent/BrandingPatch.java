package com.perwd.orange.agent;

import com.perwd.orange.api.OrangePatch;
import com.perwd.orange.api.Patches;
import java.util.Set;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.InsnList;
import org.objectweb.asm.tree.MethodInsnNode;
import org.objectweb.asm.tree.MethodNode;

/**
 * Wraps {@code MinecraftServer#getServerModName()} so the server list and F3 show
 * "Orange (Paper)", "Orange (Purpur)", "Orange (fabric)", ... Works wherever the server
 * runs with Mojang names (Paper 1.20.5+, and every server from 26.1 on).
 */
final class BrandingPatch implements OrangePatch {
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
        return Patches.injectBeforeReturns(method, Opcodes.ARETURN, () -> {
            InsnList code = new InsnList();
            code.add(new MethodInsnNode(Opcodes.INVOKESTATIC, "com/perwd/orange/hooks/OrangeHooks",
                    "brand", "(Ljava/lang/String;)Ljava/lang/String;", false));
            return code;
        }) > 0;
    }
}
