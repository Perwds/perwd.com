package com.perwd.orange.api;

/**
 * Optional entrypoint of an Orange mod, named by {@code entrypoint} in {@code orange.mod.properties}.
 *
 * <p>{@link #onLoad(ModContext)} runs inside the Java agent, before the server's main class starts
 * and before any game class is loaded. Don't touch game classes from here: register patches and
 * {@link com.perwd.orange.hooks.OrangeHooks} listeners instead.
 */
public interface OrangeMod {
    void onLoad(ModContext context);
}
