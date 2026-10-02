package com.lootcrates.hologram;

import com.lootcrates.LootCrates;
import com.lootcrates.models.CustomCrate;
import java.util.List;
import org.bukkit.Location;
import org.bukkit.Particle;
import org.bukkit.Particle.DustOptions;
import org.bukkit.entity.ArmorStand;
import org.bukkit.scheduler.BukkitRunnable;
import org.bukkit.scheduler.BukkitTask;

public class CrateHologram {
   private final Location blockLocation;
   private final String crateId;
   private final List<ArmorStand> armorStands;
   private BukkitTask particleTask;
   private BukkitTask floatTask;

   public CrateHologram(Location blockLocation, String crateId, List<ArmorStand> armorStands) {
      this.blockLocation = blockLocation;
      this.crateId = crateId;
      this.armorStands = armorStands;
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
                     if (stand != null && !stand.isDead()) {
                        Location newLoc = base.clone().subtract(0.0, i * 0.3, 0.0);
                        stand.teleport(newLoc);
                     }
                  }

                  this.offset += 0.1;
               }
            }
         }).runTaskTimer(plugin, 0L, 2L);
      }

      this.particleTask = (new BukkitRunnable() {
         double angle = 0.0;

         public void run() {
            if (CrateHologram.this.blockLocation.getWorld() == null) {
               this.cancel();
            } else if (!CrateHologram.this.blockLocation.getWorld().getNearbyEntities(CrateHologram.this.blockLocation, 30.0, 30.0, 30.0).isEmpty()) {
               Location center = CrateHologram.this.blockLocation.clone().add(0.5, 1.2, 0.5);
               double radius = crate.getParticleRadius();
               int count = crate.getParticleCount();

               for (int i = 0; i < count; i++) {
                  double offsetAngle = this.angle + i * ((Math.PI * 2) / count);
                  double x = Math.cos(offsetAngle) * radius;
                  double z = Math.sin(offsetAngle) * radius;
                  Location particleLoc = center.clone().add(x, 0.0, z);
                  Particle particle = crate.getParticle();
                  if (particle == Particle.DUST) {
                     DustOptions dust = new DustOptions(crate.getParticleColor(), 1.0F);
                     CrateHologram.this.blockLocation.getWorld().spawnParticle(Particle.DUST, particleLoc, 1, 0.0, 0.0, 0.0, 0.0, dust);
                  } else {
                     CrateHologram.this.blockLocation.getWorld().spawnParticle(particle, particleLoc, 1, 0.0, 0.0, 0.0, 0.0);
                  }
               }

               if (this.angle % 1.0 < 0.2) {
                  double rx = (Math.random() - 0.5) * 0.6;
                  double rz = (Math.random() - 0.5) * 0.6;
                  Location floatLoc = center.clone().add(rx, -0.5, rz);
                  DustOptions dust = new DustOptions(crate.getParticleColor(), 0.8F);
                  CrateHologram.this.blockLocation.getWorld().spawnParticle(Particle.DUST, floatLoc, 1, 0.0, 0.15, 0.0, 0.05, dust);
               }

               if (crate.getParticleCount() > 2) {
                  double helixY = this.angle % (Math.PI * 2) / (Math.PI * 2) * 2.0;
                  double helixX = Math.cos(this.angle * 2.0) * 0.4;
                  double helixZ = Math.sin(this.angle * 2.0) * 0.4;
                  Location helixLoc = center.clone().add(helixX, helixY, helixZ);
                  DustOptions dust = new DustOptions(crate.getParticleColor(), 0.6F);
                  CrateHologram.this.blockLocation.getWorld().spawnParticle(Particle.DUST, helixLoc, 1, 0.0, 0.0, 0.0, 0.0, dust);
               }

               this.angle += 0.15;
            }
         }
      }).runTaskTimer(plugin, 0L, 2L);
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
         if (stand != null && !stand.isDead()) {
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
