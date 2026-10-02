package com.lootcrates.util;

import org.bukkit.Color;
import org.bukkit.Location;
import org.bukkit.Particle;
import org.bukkit.World;
import org.bukkit.Particle.DustOptions;
import org.bukkit.entity.Player;

public final class ParticleUtil {
   private ParticleUtil() {
   }

   /**
    * Some particles need extra data or spawning them throws (DUST needs DustOptions, and on newer
    * Minecraft versions DRAGON_BREATH needs a Float). Returns that data, or null if none is needed.
    *
    * @throws IllegalArgumentException if the particle needs data we cannot make up (e.g. block or item particles)
    */
   public static Object createData(Particle particle, Color color) {
      Class<?> dataType = particle.getDataType();
      if (dataType == Void.class) {
         return null;
      } else if (dataType == DustOptions.class) {
         return new DustOptions(color, 1.0F);
      } else if (dataType == Color.class) {
         return color;
      } else if (dataType == Float.class) {
         return 1.0F;
      } else if (dataType == Integer.class) {
         return 0;
      } else {
         throw new IllegalArgumentException("Particle " + particle.name() + " needs " + dataType.getSimpleName() + " data");
      }
   }

   public static boolean isSupported(Particle particle) {
      try {
         createData(particle, Color.WHITE);
         return true;
      } catch (IllegalArgumentException ignored) {
         return false;
      }
   }

   public static void spawn(World world, Particle particle, Location location, int count, double offsetX, double offsetY, double offsetZ, double extra, Color color) {
      world.spawnParticle(particle, location, count, offsetX, offsetY, offsetZ, extra, createData(particle, color));
   }

   /** Purely cosmetic player particles: never let them break the animation that spawns them. */
   public static void spawn(Player player, Particle particle, Location location, int count, double offsetX, double offsetY, double offsetZ, double extra) {
      try {
         player.spawnParticle(particle, location, count, offsetX, offsetY, offsetZ, extra, createData(particle, Color.WHITE));
      } catch (IllegalArgumentException ignored) {
         // A missing particle is better than a stuck animation.
      }
   }
}
