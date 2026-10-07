package com.example.orangemod;

import com.perwd.orange.api.OrangePatch;
import com.perwd.orange.api.Patches;
import java.util.Set;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.ClassNode;
import org.objectweb.asm.tree.InsnList;
import org.objectweb.asm.tree.LdcInsnNode;
import org.objectweb.asm.tree.MethodInsnNode;
import org.objectweb.asm.tree.MethodNode;
import org.objectweb.asm.tree.VarInsnNode;

/** Injects {@code OrangeHooks.event("example:server-stopping", this)} at the start of stopServer(). */
public final class StopHookPatch implements OrangePatch {
    @Override
    public String id() {
        return "example-mod:stop-hook";
    }

    @Override
    public Set<String> targets() {
        return Set.of("net.minecraft.server.MinecraftServer");
    }

    @Override
    public boolean apply(ClassNode node) {
        MethodNode method = Patches.method(node, "stopServer", "()V");
        if (method == null || Patches.isAbstractOrNative(method)) {
            return false;
        }
        InsnList code = new InsnList();
        code.add(new LdcInsnNode("example:server-stopping"));
        code.add(new VarInsnNode(Opcodes.ALOAD, 0));
        code.add(new MethodInsnNode(Opcodes.INVOKESTATIC, "com/perwd/orange/hooks/OrangeHooks",
                "event", "(Ljava/lang/String;Ljava/lang/Object;)V", false));
        Patches.injectHead(method, code);
        return true;
    }
}
