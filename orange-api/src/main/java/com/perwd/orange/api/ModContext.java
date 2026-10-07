package com.perwd.orange.api;

import java.nio.file.Path;

public interface ModContext {
    ModInfo info();

    ModLogger logger();

    /** {@code orange-mods/<mod id>/}, created on first access. */
    Path dataDirectory();

    void registerPatch(OrangePatch patch);
}
