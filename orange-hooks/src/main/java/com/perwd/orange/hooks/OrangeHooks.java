package com.perwd.orange.hooks;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

/**
 * Static entry points that patched game code calls into.
 *
 * <p>This class lives on the bootstrap class path, so it must only depend on the JDK.
 * Keep every method cheap: some of them may end up on hot paths.
 */
public final class OrangeHooks {
    private static final Map<String, List<Consumer<Object[]>>> LISTENERS = new ConcurrentHashMap<>();
    private static volatile String brand = System.getProperty("orange.brand", "Orange");

    private OrangeHooks() {
    }

    /** Called by the branding patch in place of the server's own mod name. */
    public static String brand(String original) {
        if (original == null || original.isEmpty() || original.equalsIgnoreCase(brand)) {
            return brand;
        }
        return brand + " (" + original + ")";
    }

    public static void setBrand(String newBrand) {
        brand = newBrand;
    }

    /** Registers a listener for an event fired from patched code. */
    public static void on(String event, Consumer<Object[]> listener) {
        LISTENERS.computeIfAbsent(event, k -> new CopyOnWriteArrayList<>()).add(listener);
    }

    /** Bytecode-friendly single-argument form of {@link #fire(String, Object...)}. */
    public static void event(String event, Object arg) {
        fire(event, arg);
    }

    public static void fire(String event, Object... args) {
        List<Consumer<Object[]>> listeners = LISTENERS.get(event);
        if (listeners == null) {
            return;
        }
        for (Consumer<Object[]> listener : listeners) {
            try {
                listener.accept(args);
            } catch (Throwable t) {
                System.err.println("[Orange] Listener for '" + event + "' failed: " + t);
            }
        }
    }
}
