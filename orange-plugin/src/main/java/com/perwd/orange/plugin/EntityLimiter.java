package com.perwd.orange.plugin;

import java.util.EnumMap;
import java.util.EnumSet;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.logging.Logger;
import org.bukkit.Chunk;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.entity.Entity;
import org.bukkit.entity.EntityType;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.entity.CreatureSpawnEvent;

/** Caps how many entities of one type can pile up in a single chunk. */
final class EntityLimiter implements Listener {
    private volatile boolean enabled;
    private volatile int defaultMax;
    private volatile Map<EntityType, Integer> overrides = Map.of();
    private volatile Set<CreatureSpawnEvent.SpawnReason> reasons = Set.of();
    private long blocked;

    void configure(ConfigurationSection config, Logger logger) {
        if (config == null) {
            enabled = false;
            return;
        }
        enabled = config.getBoolean("enabled", true);
        defaultMax = config.getInt("max-per-type-per-chunk", 40);

        Map<EntityType, Integer> o = new EnumMap<>(EntityType.class);
        ConfigurationSection section = config.getConfigurationSection("overrides");
        if (section != null) {
            for (String key : section.getKeys(false)) {
                try {
                    o.put(EntityType.valueOf(key.toUpperCase(Locale.ROOT)), section.getInt(key));
                } catch (IllegalArgumentException e) {
                    logger.warning("entity-limiter: unknown entity type " + key);
                }
            }
        }
        overrides = o;

        Set<CreatureSpawnEvent.SpawnReason> r = EnumSet.noneOf(CreatureSpawnEvent.SpawnReason.class);
        for (String name : config.getStringList("reasons")) {
            try {
                r.add(CreatureSpawnEvent.SpawnReason.valueOf(name.toUpperCase(Locale.ROOT)));
            } catch (IllegalArgumentException e) {
                logger.warning("entity-limiter: unknown spawn reason " + name);
            }
        }
        reasons = r;
    }

    boolean enabled() {
        return enabled;
    }

    long blocked() {
        return blocked;
    }

    @EventHandler(priority = EventPriority.HIGH, ignoreCancelled = true)
    public void onSpawn(CreatureSpawnEvent event) {
        if (!enabled || !reasons.contains(event.getSpawnReason())) {
            return;
        }
        EntityType type = event.getEntityType();
        int max = overrides.getOrDefault(type, defaultMax);
        if (max < 0) {
            return;
        }
        Chunk chunk = event.getLocation().getChunk();
        int count = 0;
        for (Entity entity : chunk.getEntities()) {
            if (entity.getType() == type && ++count >= max) {
                event.setCancelled(true);
                blocked++;
                return;
            }
        }
    }
}
