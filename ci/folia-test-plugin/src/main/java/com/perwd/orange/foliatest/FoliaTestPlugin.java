package com.perwd.orange.foliatest;

import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.World;
import org.bukkit.entity.Entity;
import org.bukkit.entity.EntityType;
import org.bukkit.plugin.java.JavaPlugin;

/** Uses every Folia scheduler and logs "FOLIA-TEST ... ok" for each one that runs. */
public final class FoliaTestPlugin extends JavaPlugin {
    @Override
    public void onEnable() {
        Bukkit.getAsyncScheduler().runNow(this, task -> getLogger().info("FOLIA-TEST async scheduler ok"));

        Bukkit.getGlobalRegionScheduler().runDelayed(this, task -> {
            getLogger().info("FOLIA-TEST global region scheduler ok");
            World world = Bukkit.getWorlds().getFirst();
            Location spawn = world.getSpawnLocation();
            Bukkit.getRegionScheduler().run(this, spawn, regionTask -> {
                getLogger().info("FOLIA-TEST region scheduler ok");
                Entity marker = world.spawnEntity(spawn, EntityType.ARMOR_STAND);
                marker.getScheduler().run(this, entityTask -> {
                    getLogger().info("FOLIA-TEST entity scheduler ok");
                    marker.remove();
                }, null);
            });
        }, 20L);
    }
}
