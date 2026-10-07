package com.perwd.orange.agent;

import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;
import org.objectweb.asm.ClassReader;
import org.objectweb.asm.ClassWriter;

/**
 * Computes frames by reading class files as resources instead of loading classes, which would
 * be unsafe (and could recurse) from inside a transformer.
 */
final class HierarchyClassWriter extends ClassWriter {
    private final ClassLoader loader;

    HierarchyClassWriter(ClassLoader loader, int flags) {
        super(flags);
        this.loader = loader == null ? ClassLoader.getPlatformClassLoader() : loader;
    }

    @Override
    protected String getCommonSuperClass(String a, String b) {
        List<String> ancestorsOfA = superChain(a);
        if (ancestorsOfA.contains(b)) {
            return b;
        }
        for (String candidate : superChain(b)) {
            if (ancestorsOfA.contains(candidate)) {
                return candidate;
            }
        }
        return "java/lang/Object";
    }

    private List<String> superChain(String name) {
        List<String> chain = new ArrayList<>();
        String current = name;
        while (current != null) {
            chain.add(current);
            current = superName(current);
        }
        return chain;
    }

    private String superName(String name) {
        if (name.equals("java/lang/Object")) {
            return null;
        }
        try (InputStream in = loader.getResourceAsStream(name + ".class")) {
            if (in == null) {
                return "java/lang/Object";
            }
            ClassReader reader = new ClassReader(in);
            return (reader.getAccess() & ACC_INTERFACE_FLAG) != 0 ? "java/lang/Object" : reader.getSuperName();
        } catch (IOException e) {
            return "java/lang/Object";
        }
    }

    private static final int ACC_INTERFACE_FLAG = org.objectweb.asm.Opcodes.ACC_INTERFACE;
}
