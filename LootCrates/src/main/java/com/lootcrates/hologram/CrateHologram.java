package com.lootcrates.hologram;

import com.lootcrates.LootCrates;
import com.lootcrates.models.CustomCrate;
import com.lootcrates.util.ParticleUtil;
import java.util.ArrayList;
import java.util.List;
import org.bukkit.Location;
import org.bukkit.Particle;
import org.bukkit.World;
import org.bukkit.entity.ArmorStand;
import org.bukkit.entity.Entity;
import org.bukkit.entity.Player;
import org.bukkit.scheduler.BukkitRunnable;
import org.bukkit.scheduler.BukkitTask;

public class CrateHologram {
   private static final double PARTICLE_VIEW_DISTANCE_SQUARED = 900.0;
   private final Location blockLocation;
   private final String crateId;
   private final List<ArmorStand> armorStands = new ArrayList<>();
   private BukkitTask particleTask;
   private BukkitTask floatTask;

   public CrateHologram(Location blockLocation, String crateId) {
      this.blockLocation = blockLocation;
      this.crateId = crateId;
   }

   public void startParticles(LootCrates plugin, final CustomCrate crate) {
      if (this.particleTask != null) {
         this.particleTask.cancel();
      }

      if (this.floatTask != null) {
         this.floatTask.cancel();
      }

      if (crate.isFloatingAnimation()) {
         this.floatTask = (new BukkitRunnable() {
            double offset = 0.0;

            public void run() {
               if (CrateHologram.this.blockLocation.getWorld() == null) {
                  this.cancel();
               } else {
                  double floatOffset = Math.sin(this.offset) * 0.1;
                  Location base = CrateHologram.this.blockLocation.clone().add(0.5, 2.5 + floatOffset, 0.5);

                  for (int i = 0; i < CrateHologram.this.armorStands.size(); i++) {
                     ArmorStand stand = CrateHologram.this.armorStands.get(i);
                     if (stand != null && stand.isValid()) {
                        Location newLoc = base.clone().subtract(0.0, i * 0.3, 0.0);
                        stand.teleport(newLoc);
                     }
                  }

                  this.offset += 0.1;
               }
            }
         }).runTaskTimer(plugin, 0L, 2L);
      }

      if (!plugin.getConfig().getBoolean("settings.particles-enabled", true)) {
         return;
      }

      final Particle particle;
      if (ParticleUtil.isSupported(crate.getParticle())) {
         particle = crate.getParticle();
      } else {
         plugin.getLogger()
            .warning("Particle " + crate.getParticle().name() + " of crate " + crate.getId() + " needs block/item data and can't be used here, using DUST instead");
         particle = Particle.DUST;
      }

      this.particleTask = (new BukkitRunnable() {
         double angle = 0.0;

         public void run() {
            World world = CrateHologram.this.blockLocation.getWorld();
            if (world == null) {
               this.cancel();
            } else if (CrateHologram.this.hasPlayerNearby(world)) {
               Location center = CrateHologram.this.blockLocation.clone().add(0.5, 1.2, 0.5);
               double radius = crate.getParticleRadius();
               int count = crate.getParticleCount();

               for (int i = 0; i < count; i++) {
                  double offsetAngle = this.angle + i * ((Math.PI * 2) / count);
                  double x = Math.cos(offsetAngle) * radius;
                  double z = Math.sin(offsetAngle) * radius;
                  Location particleLoc = center.clone().add(x, 0.0, z);
                  ParticleUtil.spawn(world, particle, particleLoc, 1, 0.0, 0.0, 0.0, 0.0, crate.getParticleColor());
               }

               if (this.angle % 1.0 < 0.2) {
                  double rx = (Math.random() - 0.5) * 0.6;
                  double rz = (Math.random() - 0.5) * 0.6;
                  Location floatLoc = center.clone().add(rx, -0.5, rz);
                  world.spawnParticle(Particle.DUST, floatLoc, 1, 0.0, 0.15, 0.0, 0.05, new Particle.DustOptions(crate.getParticleColor(), 0.8F));
               }

               if (crate.getParticleCount() > 2) {
                  double helixY = this.angle % (Math.PI * 2) / (Math.PI * 2) * 2.0;
                  double helixX = Math.cos(this.angle * 2.0) * 0.4;
                  double helixZ = Math.sin(this.angle * 2.0) * 0.4;
                  Location helixLoc = center.clone().add(helixX, helixY, helixZ);
                  world.spawnParticle(Particle.DUST, helixLoc, 1, 0.0, 0.0, 0.0, 0.0, new Particle.DustOptions(crate.getParticleColor(), 0.6F));
               }

               this.angle += 0.15;
            }
         }
      }).runTaskTimer(plugin, 0L, 2L);
   }

   // The old check looked for any entity nearby, which always found the hologram's own armor stands.
   private boolean hasPlayerNearby(World world) {
      for (Player player : world.getPlayers()) {
         if (player.getLocation().distanceSquared(this.blockLocation) <= PARTICLE_VIEW_DISTANCE_SQUARED) {
            return true;
         }
      }

      return false;
   }

   public void setArmorStands(List<ArmorStand> stands) {
      this.armorStands.clear();
      this.armorStands.addAll(stands);
   }

   /** True while all hologram lines exist in the world (they vanish when their chunk unloads). */
   public boolean isSpawned() {
      if (this.armorStands.isEmpty()) {
         return false;
      }

      for (ArmorStand stand : this.armorStands) {
         if (stand == null || !stand.isValid()) {
            return false;
         }
      }

      return true;
   }

   public boolean ownsStand(Entity entity) {
      for (ArmorStand stand : this.armorStands) {
         if (stand != null && stand.getUniqueId().equals(entity.getUniqueId())) {
            return true;
         }
      }

      return false;
   }

   public boolean isInChunk(World world, int chunkX, int chunkZ) {
      return world.equals(this.blockLocation.getWorld()) && this.blockLocation.getBlockX() >> 4 == chunkX && this.blockLocation.getBlockZ() >> 4 == chunkZ;
   }

   public void remove() {
      if (this.particleTask != null) {
         this.particleTask.cancel();
         this.particleTask = null;
      }

      if (this.floatTask != null) {
         this.floatTask.cancel();
         this.floatTask = null;
      }

      for (ArmorStand stand : this.armorStands) {
         if (stand != null && stand.isValid()) {
            stand.remove();
         }
      }

      this.armorStands.clear();
   }

   public Location getBlockLocation() {
      return this.blockLocation;
   }

   public String getCrateId() {
      return this.crateId;
   }

   public List<ArmorStand> getArmorStands() {
      return this.armorStands;
   }
}
