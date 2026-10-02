package com.lootcrates.hologram;

import com.lootcrates.LootCrates;
import com.lootcrates.models.CustomCrate;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import org.bukkit.Location;
import org.bukkit.World;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.ArmorStand;
import org.bukkit.entity.EntityType;

public class HologramManager {
   private final LootCrates plugin;
   private final Map<Location, CrateHologram> holograms = new HashMap<>();
   private final File dataFile;
   private FileConfiguration dataConfig;

   public HologramManager(LootCrates plugin) {
      this.plugin = plugin;
      this.dataFile = new File(plugin.getDataFolder(), "crate_locations.yml");
      this.loadHolograms();
   }

   public void createHologram(Location blockLocation, String crateId) {
      this.removeHologram(blockLocation);
      CustomCrate crate = this.plugin.getCustomCrateManager().getCrate(crateId);
      if (crate != null) {
         World world = blockLocation.getWorld();
         if (world != null) {
            List<ArmorStand> stands = new ArrayList<>();
            Location hologramLoc = blockLocation.clone().add(0.5, 2.5, 0.5);
            ArmorStand line1 = this.createArmorStand(hologramLoc, LootCrates.colorize(crate.getHologramLine1()));
            stands.add(line1);
            ArmorStand line2 = this.createArmorStand(hologramLoc.clone().subtract(0.0, 0.3, 0.0), LootCrates.colorize(crate.getHologramLine2()));
            stands.add(line2);
            ArmorStand line3 = this.createArmorStand(hologramLoc.clone().subtract(0.0, 0.6, 0.0), LootCrates.colorize(crate.getHologramLine3()));
            stands.add(line3);
            CrateHologram hologram = new CrateHologram(blockLocation, crateId, stands);
            this.holograms.put(blockLocation, hologram);
            hologram.startParticles(this.plugin, crate);
            this.saveHolograms();
         }
      }
   }

   private ArmorStand createArmorStand(Location location, String name) {
      ArmorStand stand = (ArmorStand)location.getWorld().spawnEntity(location, EntityType.ARMOR_STAND);
      stand.setCustomName(name);
      stand.setCustomNameVisible(true);
      stand.setGravity(false);
      stand.setInvisible(true);
      stand.setInvulnerable(true);
      stand.setMarker(true);
      stand.setSmall(true);
      stand.setPersistent(true);
      return stand;
   }

   public void removeHologram(Location blockLocation) {
      CrateHologram hologram = this.holograms.remove(blockLocation);
      if (hologram != null) {
         hologram.remove();
         this.saveHolograms();
      }
   }

   public CrateHologram getHologram(Location location) {
      return this.holograms.get(location);
   }

   public boolean isCrateLocation(Location location) {
      return this.holograms.containsKey(location);
   }

   public String getCrateIdAt(Location location) {
      CrateHologram hologram = this.holograms.get(location);
      return hologram != null ? hologram.getCrateId() : null;
   }

   public void refreshHolograms(String crateId) {
      List<Location> locations = new ArrayList<>();

      for (Entry<Location, CrateHologram> entry : this.holograms.entrySet()) {
         if (entry.getValue().getCrateId().equals(crateId)) {
            locations.add(entry.getKey());
         }
      }

      for (Location loc : locations) {
         this.removeHologram(loc);
         this.createHologram(loc, crateId);
      }
   }

   private void loadHolograms() {
      if (!this.dataFile.exists()) {
         try {
            this.dataFile.getParentFile().mkdirs();
            this.dataFile.createNewFile();
         } catch (IOException var14) {
            this.plugin.getLogger().severe("Could not create crate_locations.yml");
         }
      } else {
         this.dataConfig = YamlConfiguration.loadConfiguration(this.dataFile);
         if (this.dataConfig.contains("crates")) {
            for (String key : this.dataConfig.getConfigurationSection("crates").getKeys(false)) {
               try {
                  String path = "crates." + key;
                  String worldName = this.dataConfig.getString(path + ".world");
                  double x = this.dataConfig.getDouble(path + ".x");
                  double y = this.dataConfig.getDouble(path + ".y");
                  double z = this.dataConfig.getDouble(path + ".z");
                  String crateId = this.dataConfig.getString(path + ".crate-id");
                  World world = this.plugin.getServer().getWorld(worldName);
                  if (world != null) {
                     Location loc = new Location(world, x, y, z);
                     if (crateId != null && this.plugin.getCustomCrateManager().getCrate(crateId) != null) {
                        this.createHologram(loc, crateId);
                     }
                  }
               } catch (Exception var15) {
                  this.plugin.getLogger().warning("Failed to load crate hologram: " + key);
               }
            }

            this.plugin.getLogger().info("Loaded " + this.holograms.size() + " crate holograms");
         }
      }
   }

   public void saveHolograms() {
      this.dataConfig = new YamlConfiguration();
      int index = 0;

      for (Entry<Location, CrateHologram> entry : this.holograms.entrySet()) {
         Location loc = entry.getKey();
         CrateHologram hologram = entry.getValue();
         String path = "crates." + index;
         this.dataConfig.set(path + ".world", loc.getWorld().getName());
         this.dataConfig.set(path + ".x", loc.getBlockX());
         this.dataConfig.set(path + ".y", loc.getBlockY());
         this.dataConfig.set(path + ".z", loc.getBlockZ());
         this.dataConfig.set(path + ".crate-id", hologram.getCrateId());
         index++;
      }

      try {
         this.dataConfig.save(this.dataFile);
      } catch (IOException var7) {
         this.plugin.getLogger().severe("Could not save crate_locations.yml");
      }
   }

   public void removeAllHolograms() {
      for (CrateHologram hologram : this.holograms.values()) {
         hologram.remove();
      }

      this.holograms.clear();
   }

   public Collection<CrateHologram> getAllHolograms() {
      return this.holograms.values();
   }
}
