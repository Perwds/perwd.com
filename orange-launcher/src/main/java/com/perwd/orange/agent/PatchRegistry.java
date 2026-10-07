package com.perwd.orange.agent;

import com.perwd.orange.api.OrangePatch;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;

/** Patches indexed by internal class name, so non-target classes cost one map lookup. */
final class PatchRegistry {
    private final Map<String, List<OrangePatch>> byTarget = new ConcurrentHashMap<>();
    private int size;

    void register(OrangePatch patch) {
        for (String target : patch.targets()) {
            byTarget.computeIfAbsent(target.replace('.', '/'), k -> new CopyOnWriteArrayList<>()).add(patch);
        }
        size++;
    }

    List<OrangePatch> forClass(String internalName) {
        return byTarget.getOrDefault(internalName, List.of());
    }

    int size() {
        return size;
    }
}
