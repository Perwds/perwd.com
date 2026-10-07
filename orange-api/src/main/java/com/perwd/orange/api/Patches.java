package com.perwd.orange.api;

import java.util.ArrayList;
import java.util.List;
import org.objectweb.asm.Opcodes;
import org.objectweb.asm.tree.AbstractInsnNode;
import org.objectweb.asm.tree.ClassNode;
import org.objectweb.asm.tree.InsnList;
import org.objectweb.asm.tree.MethodNode;

/** Small helpers for writing patches. */
public final class Patches {
    private Patches() {
    }

    /** Finds a method by name and descriptor, or {@code null}. */
    public static MethodNode method(ClassNode node, String name, String descriptor) {
        for (MethodNode method : node.methods) {
            if (method.name.equals(name) && method.desc.equals(descriptor)) {
                return method;
            }
        }
        return null;
    }

    /** Inserts {@code code} at the start of {@code method}. */
    public static void injectHead(MethodNode method, InsnList code) {
        method.instructions.insert(code);
    }

    /** Inserts a fresh copy of the code from {@code factory} before every return instruction. */
    public static int injectBeforeReturns(MethodNode method, int returnOpcode, java.util.function.Supplier<InsnList> factory) {
        List<AbstractInsnNode> returns = new ArrayList<>();
        for (AbstractInsnNode insn : method.instructions) {
            if (insn.getOpcode() == returnOpcode) {
                returns.add(insn);
            }
        }
        for (AbstractInsnNode ret : returns) {
            method.instructions.insertBefore(ret, factory.get());
        }
        return returns.size();
    }

    public static boolean isAbstractOrNative(MethodNode method) {
        return (method.access & (Opcodes.ACC_ABSTRACT | Opcodes.ACC_NATIVE)) != 0;
    }
}
