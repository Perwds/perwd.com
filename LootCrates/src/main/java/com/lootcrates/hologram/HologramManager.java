package com.lootcrates.hologram;

import com.lootcrates.LootCrates;
import com.lootcrates.models.CustomCrate;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Map.Entry;
import org.bukkit.Chunk;
import org.bukkit.Location;
import org.bukkit.NamespacedKey;
import org.bukkit.World;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.ArmorStand;
import org.bukkit.entity.Entity;
import org.bukkit.entity.EntityType;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.world.ChunkLoadEvent;
import org.bukkit.event.world.ChunkUnloadEvent;
import org.bukkit.event.world.EntitiesLoadEvent;
import org.bukkit.event.world.WorldLoadEvent;
import org.bukkit.persistence.PersistentDataType;

/**
 * Hologram armor stands are spawned as non-persistent entities: they are never written to the world
 * save, disappear when their chunk unloads and are spawned again when it loads. Older versions saved
 * them, so every chunk reload or restart left an extra (frozen) set of stands behind; those leftovers
 * are cleaned up whenever their chunk loads.
 */
public class HologramManager implements Listener {
   private final LootCrates plugin;
   private final Map<Location, CrateHologram> holograms = new HashMap<>();
   // Crates in worlds that are not loaded yet (e.g. loaded later by a world manager plugin); kept so saving doesn't drop them.
   private final List<HologramManager.SavedCrate> unloadedWorldCrates = new ArrayList<>();
   private final NamespacedKey hologramKey;
   private final File dataFile;
   private FileConfiguration dataConfig;

   public HologramManager(LootCrates plugin) {
      this.plugin = plugin;
      this.hologramKey = new NamespacedKey(plugin, "hologram");
      this.dataFile = new File(plugin.getDataFolder(), "crate_locations.yml");
      this.loadHolograms();
   }

   public void createHologram(Location blockLocation, String crateId) {
      if (this.plugin.getCustomCrateManager().getCrate(crateId) != null && blockLocation.getWorld() != null) {
         CrateHologram previous = this.holograms.remove(blockLocation);
         if (previous != null) {
            previous.remove();
         }

         CrateHologram hologram = new CrateHologram(blockLocation, crateId);
         this.holograms.put(blockLocation, hologram);
         this.spawn(hologram);
         this.saveHolograms();
      }
   }

   private void spawn(CrateHologram hologram) {
      hologram.remove();
      CustomCrate crate = this.plugin.getCustomCrateManager().getCrate(hologram.getCrateId());
      Location blockLocation = hologram.getBlockLocation();
      World world = blockLocation.getWorld();
      if (crate != null && world != null && world.isChunkLoaded(blockLocation.getBlockX() >> 4, blockLocation.getBlockZ() >> 4)) {
         this.removeStrayStands(Arrays.asList(world.getChunkAt(blockLocation.getBlockX() >> 4, blockLocation.getBlockZ() >> 4).getEntities()));
         List<ArmorStand> stands = new ArrayList<>();
         Location hologramLoc = blockLocation.clone().add(0.5, 2.5, 0.5);
         stands.add(this.createArmorStand(hologramLoc, LootCrates.colorize(crate.getHologramLine1())));
         stands.add(this.createArmorStand(hologramLoc.clone().subtract(0.0, 0.3, 0.0), LootCrates.colorize(crate.getHologramLine2())));
         stands.add(this.createArmorStand(hologramLoc.clone().subtract(0.0, 0.6, 0.0), LootCrates.colorize(crate.getHologramLine3())));
         hologram.setArmorStands(stands);
         hologram.startParticles(this.plugin, crate);
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
      stand.setPersistent(false);
      stand.getPersistentDataContainer().set(this.hologramKey, PersistentDataType.BYTE, (byte)1);
      return stand;
   }

   private void removeStrayStands(Collection<Entity> entities) {
      for (Entity entity : entities) {
         if (entity instanceof ArmorStand stand && stand.isValid() && this.isStrayStand(stand)) {
            stand.remove();
         }
      }
   }

   private boolean isStrayStand(ArmorStand stand) {
      for (CrateHologram hologram : this.holograms.values()) {
         if (hologram.ownsStand(stand)) {
            return false;
         }
      }

      if (stand.getPersistentDataContainer().has(this.hologramKey, PersistentDataType.BYTE)) {
         return true;
      }

      // Untagged stands saved by older versions: invisible name-tag stands centered on a block, above a crate or showing a crate hologram line.
      if (stand.isMarker() && stand.isInvisible() && stand.isSmall() && stand.getCustomName() != null) {
         Location location = stand.getLocation();
         boolean centered = Math.abs(location.getX() - Math.floor(location.getX()) - 0.5) < 0.01 && Math.abs(location.getZ() - Math.floor(location.getZ()) - 0.5) < 0.01;
         return centered && (this.isAboveCrate(location) || this.isHologramLine(stand.getCustomName()));
      } else {
         return false;
      }
   }

   private boolean isAboveCrate(Location location) {
      for (Location crateLocation : this.holograms.keySet()) {
         if (Objects.equals(crateLocation.getWorld(), location.getWorld())
            && crateLocation.getBlockX() == location.getBlockX()
            && crateLocation.getBlockZ() == location.getBlockZ()
            && location.getY() >= crateLocation.getBlockY() + 1.5
            && location.getY() <= crateLocation.getBlockY() + 3.0) {
            return true;
         }
      }

      return false;
   }

   private boolean isHologramLine(String name) {
      for (CustomCrate crate : this.plugin.getCustomCrateManager().getAllCrates()) {
         if (name.equals(LootCrates.colorize(crate.getHologramLine1()))
            || name.equals(LootCrates.colorize(crate.getHologramLine2()))
            || name.equals(LootCrates.colorize(crate.getHologramLine3()))) {
            return true;
         }
      }

      return false;
   }

   @EventHandler
   public void onEntitiesLoad(EntitiesLoadEvent event) {
      List<Entity> stands = new ArrayList<>();

      for (Entity entity : event.getEntities()) {
         if (entity instanceof ArmorStand) {
            stands.add(entity);
         }
      }

      Chunk chunk = event.getChunk();
      if (!stands.isEmpty() || this.hasHologramIn(chunk)) {
         this.plugin.getServer().getScheduler().runTask(this.plugin, () -> {
            this.removeStrayStands(stands);
            this.spawnMissing(chunk);
         });
      }
   }

   @EventHandler
   public void onChunkLoad(ChunkLoadEvent event) {
      Chunk chunk = event.getChunk();
      if (this.hasHologramIn(chunk)) {
         this.plugin.getServer().getScheduler().runTask(this.plugin, () -> this.spawnMissing(chunk));
      }
   }

   private boolean hasHologramIn(Chunk chunk) {
      World world = chunk.getWorld();

      for (CrateHologram hologram : this.holograms.values()) {
         if (hologram.isInChunk(world, chunk.getX(), chunk.getZ())) {
            return true;
         }
      }

      return false;
   }

   @EventHandler
   public void onChunkUnload(ChunkUnloadEvent event) {
      Chunk chunk = event.getChunk();

      for (CrateHologram hologram : this.holograms.values()) {
         if (hologram.isInChunk(chunk.getWorld(), chunk.getX(), chunk.getZ())) {
            hologram.remove();
         }
      }
   }

   @EventHandler
   public void onWorldLoad(WorldLoadEvent event) {
      World world = event.getWorld();
      Iterator<HologramManager.SavedCrate> iterator = this.unloadedWorldCrates.iterator();

      while (iterator.hasNext()) {
         HologramManager.SavedCrate saved = iterator.next();
         if (saved.world().equals(world.getName())) {
            iterator.remove();
            this.register(new Location(world, saved.x(), saved.y(), saved.z()), saved.crateId());
         }
      }
   }

   private void spawnMissing(Chunk chunk) {
      for (CrateHologram hologram : this.holograms.values()) {
         if (hologram.isInChunk(chunk.getWorld(), chunk.getX(), chunk.getZ()) && !hologram.isSpawned()) {
            this.spawn(hologram);
         }
      }
   }

   private void register(Location blockLocation, String crateId) {
      CrateHologram hologram = new CrateHologram(blockLocation, crateId);
      this.holograms.put(blockLocation, hologram);
      this.spawn(hologram);
   }

   public void removeHologram(Location blockLocation) {
      CrateHologram hologram = this.holograms.remove(blockLocation);
      if (hologram != null) {
         hologram.remove();
         this.saveHolograms();
      }
   }

   public void removeHolograms(String crateId) {
      boolean removed = this.holograms.values().removeIf(hologram -> {
         if (hologram.getCrateId().equals(crateId)) {
            hologram.remove();
            return true;
         } else {
            return false;
         }
      });
      if (removed) {
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
      for (CrateHologram hologram : this.holograms.values()) {
         if (hologram.getCrateId().equals(crateId)) {
            this.spawn(hologram);
         }
      }
   }

   /** Respawns every hologram with the current crate settings, dropping crates that no longer exist. */
   public void refreshAllHolograms() {
      List<String> missing = new ArrayList<>();

      for (CrateHologram hologram : this.holograms.values()) {
         if (this.plugin.getCustomCrateManager().getCrate(hologram.getCrateId()) == null) {
            missing.add(hologram.getCrateId());
         } else {
            this.spawn(hologram);
         }
      }

      for (String crateId : missing) {
         this.removeHolograms(crateId);
      }
   }

   private void loadHolograms() {
      if (!this.dataFile.exists()) {
         try {
            this.dataFile.getParentFile().mkdirs();
            this.dataFile.createNewFile();
         } catch (IOException var13) {
            this.plugin.getLogger().severe("Could not create crate_locations.yml");
         }
      } else {
         this.dataConfig = YamlConfiguration.loadConfiguration(this.dataFile);
         ConfigurationSection section = this.dataConfig.getConfigurationSection("crates");
         if (section != null) {
            for (String key : section.getKeys(false)) {
               try {
                  String path = "crates." + key;
                  String worldName = this.dataConfig.getString(path + ".world");
                  int x = (int)Math.floor(this.dataConfig.getDouble(path + ".x"));
                  int y = (int)Math.floor(this.dataConfig.getDouble(path + ".y"));
                  int z = (int)Math.floor(this.dataConfig.getDouble(path + ".z"));
                  String crateId = this.dataConfig.getString(path + ".crate-id");
                  if (worldName != null && crateId != null && this.plugin.getCustomCrateManager().getCrate(crateId) != null) {
                     World world = this.plugin.getServer().getWorld(worldName);
                     if (world != null) {
                        this.register(new Location(world, x, y, z), crateId);
                     } else {
                        this.unloadedWorldCrates.add(new HologramManager.SavedCrate(worldName, x, y, z, crateId));
                     }
                  }
               } catch (Exception var14) {
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
         this.writeCrate(index++, loc.getWorld().getName(), loc.getBlockX(), loc.getBlockY(), loc.getBlockZ(), entry.getValue().getCrateId());
      }

      for (HologramManager.SavedCrate saved : this.unloadedWorldCrates) {
         this.writeCrate(index++, saved.world(), saved.x(), saved.y(), saved.z(), saved.crateId());
      }

      try {
         this.dataConfig.save(this.dataFile);
      } catch (IOException var7) {
         this.plugin.getLogger().severe("Could not save crate_locations.yml");
      }
   }

   private void writeCrate(int index, String world, int x, int y, int z, String crateId) {
      String path = "crates." + index;
      this.dataConfig.set(path + ".world", world);
      this.dataConfig.set(path + ".x", x);
      this.dataConfig.set(path + ".y", y);
      this.dataConfig.set(path + ".z", z);
      this.dataConfig.set(path + ".crate-id", crateId);
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

   private record SavedCrate(String world, int x, int y, int z, String crateId) {
   }
}
