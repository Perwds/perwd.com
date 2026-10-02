package com.lootcrates.animation;

public enum AnimationType {
   CLASSIC("Classic Spin", "Standard spinning animation"),
   SLOW_REVEAL("Slow Reveal", "Slowly reveals the reward"),
   FAST_SPIN("Fast Spin", "Quick spinning action"),
   BOUNCE("Bounce", "Items bounce into place"),
   SPIRAL("Spiral", "Spiral pattern reveal"),
   PULSE("Pulse", "Pulsing glow effect"),
   WAVE("Wave", "Wave motion animation"),
   CASCADE("Cascade", "Items cascade down"),
   EXPLOSION("Explosion", "Explosive reveal"),
   VORTEX("Vortex", "Swirling vortex effect"),
   RAINBOW("Rainbow", "Colorful rainbow spin"),
   METEOR("Meteor", "Meteor shower effect"),
   LIGHTNING("Lightning", "Electric lightning bolts"),
   FIREWORK("Firework", "Firework burst reveal"),
   GALAXY("Galaxy", "Cosmic galaxy swirl"),
   PORTAL("Portal", "Mystical portal opening"),
   TORNADO("Tornado", "Tornado spin effect"),
   EARTHQUAKE("Earthquake", "Shaking reveal"),
   BUBBLE("Bubble", "Floating bubble pop"),
   CRYSTAL("Crystal", "Crystal formation"),
   PHOENIX("Phoenix", "Rising phoenix flames"),
   DRAGON("Dragon", "Dragon breath reveal"),
   MYSTIC("Mystic", "Magical mystic aura"),
   NEON("Neon", "Neon glow trail"),
   GLITCH("Glitch", "Digital glitch effect");

   private final String displayName;
   private final String description;

   private AnimationType(String displayName, String description) {
      this.displayName = displayName;
      this.description = description;
   }

   public String getDisplayName() {
      return this.displayName;
   }

   public String getDescription() {
      return this.description;
   }

   public static AnimationType fromString(String name) {
      try {
         return valueOf(name.toUpperCase());
      } catch (Exception var2) {
         return CLASSIC;
      }
   }
}
