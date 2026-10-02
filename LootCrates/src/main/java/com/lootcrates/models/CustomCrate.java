package com.lootcrates.models;

import com.lootcrates.LootCrates;
import com.lootcrates.animation.AnimationType;
import java.util.ArrayList;
import java.util.List;
import org.bukkit.Color;
import org.bukkit.Material;
import org.bukkit.Particle;
import org.bukkit.Sound;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;

public class CustomCrate {
   private final String id;
   private String displayName;
   private Material crateMaterial;
   private Material keyMaterial;
   private String keyName;
   private Particle particle;
   private Color particleColor;
   private Sound openSound;
   private Sound winSound;
   private int customModelData;
   private AnimationType animationType;
   private String hologramLine1;
   private String hologramLine2;
   private String hologramLine3;
   private boolean floatingAnimation;
   private double particleRadius;
   private int particleCount;

   public CustomCrate(String id) {
      this.id = id.toLowerCase();
      this.displayName = "&f" + id + " Crate";
      this.crateMaterial = Material.CHEST;
      this.keyMaterial = Material.TRIPWIRE_HOOK;
      this.keyName = "&f" + id + " Key";
      this.particle = Particle.HAPPY_VILLAGER;
      this.particleColor = Color.WHITE;
      this.openSound = Sound.BLOCK_CHEST_OPEN;
      this.winSound = Sound.ENTITY_PLAYER_LEVELUP;
      this.customModelData = id.hashCode() & 65535;
      this.animationType = AnimationType.CLASSIC;
      this.hologramLine1 = this.displayName;
      this.hologramLine2 = "&7Right-click with key to open!";
      this.hologramLine3 = "&e✦ " + id.toUpperCase() + " ✦";
      this.floatingAnimation = true;
      this.particleRadius = 0.8;
      this.particleCount = 2;
   }

   public ItemStack createCrateItem(int amount) {
      ItemStack item = new ItemStack(this.crateMaterial, amount);
      ItemMeta meta = item.getItemMeta();
      if (meta != null) {
         meta.setDisplayName(LootCrates.colorize(this.displayName));
         List<String> lore = new ArrayList<>();
         lore.add("");
         lore.add(LootCrates.colorize("&7Crate: " + this.displayName));
         lore.add(LootCrates.colorize("&7Right-click to open!"));
         lore.add("");
         lore.add(LootCrates.colorize("&eRequires: " + this.keyName));
         lore.add("");
         lore.add(LootCrates.colorize("&8ID: " + this.id));
         meta.setLore(lore);
         meta.setCustomModelData(this.customModelData);
         item.setItemMeta(meta);
      }

      return item;
   }

   public ItemStack createKeyItem(int amount) {
      ItemStack item = new ItemStack(this.keyMaterial, amount);
      ItemMeta meta = item.getItemMeta();
      if (meta != null) {
         meta.setDisplayName(LootCrates.colorize(this.keyName));
         List<String> lore = new ArrayList<>();
         lore.add("");
         lore.add(LootCrates.colorize("&7Use this key to open a"));
         lore.add(LootCrates.colorize(this.displayName));
         lore.add("");
         lore.add(LootCrates.colorize("&eRight-click a crate to use!"));
         lore.add(LootCrates.colorize("&8ID: " + this.id));
         meta.setLore(lore);
         meta.setCustomModelData(this.customModelData + 10000);
         item.setItemMeta(meta);
      }

      return item;
   }

   public boolean isCrateItem(ItemStack item) {
      if (item != null && item.getType() == this.crateMaterial) {
         ItemMeta meta = item.getItemMeta();
         return meta != null && meta.hasCustomModelData() ? meta.getCustomModelData() == this.customModelData : false;
      } else {
         return false;
      }
   }

   public boolean isKeyItem(ItemStack item) {
      if (item != null && item.getType() == this.keyMaterial) {
         ItemMeta meta = item.getItemMeta();
         return meta != null && meta.hasCustomModelData() ? meta.getCustomModelData() == this.customModelData + 10000 : false;
      } else {
         return false;
      }
   }

   public String getId() {
      return this.id;
   }

   public String getDisplayName() {
      return this.displayName;
   }

   public void setDisplayName(String displayName) {
      this.displayName = displayName;
      this.hologramLine1 = displayName;
   }

   public Material getCrateMaterial() {
      return this.crateMaterial;
   }

   public void setCrateMaterial(Material crateMaterial) {
      this.crateMaterial = crateMaterial;
   }

   public Material getKeyMaterial() {
      return this.keyMaterial;
   }

   public void setKeyMaterial(Material keyMaterial) {
      this.keyMaterial = keyMaterial;
   }

   public String getKeyName() {
      return this.keyName;
   }

   public void setKeyName(String keyName) {
      this.keyName = keyName;
   }

   public Particle getParticle() {
      return this.particle;
   }

   public void setParticle(Particle particle) {
      this.particle = particle;
   }

   public Color getParticleColor() {
      return this.particleColor;
   }

   public void setParticleColor(Color particleColor) {
      this.particleColor = particleColor;
   }

   public Sound getOpenSound() {
      return this.openSound;
   }

   public void setOpenSound(Sound openSound) {
      this.openSound = openSound;
   }

   public Sound getWinSound() {
      return this.winSound;
   }

   public void setWinSound(Sound winSound) {
      this.winSound = winSound;
   }

   public int getCustomModelData() {
      return this.customModelData;
   }

   public void setCustomModelData(int customModelData) {
      this.customModelData = customModelData;
   }

   public String getHologramLine1() {
      return this.hologramLine1;
   }

   public void setHologramLine1(String hologramLine1) {
      this.hologramLine1 = hologramLine1;
   }

   public String getHologramLine2() {
      return this.hologramLine2;
   }

   public void setHologramLine2(String hologramLine2) {
      this.hologramLine2 = hologramLine2;
   }

   public String getHologramLine3() {
      return this.hologramLine3;
   }

   public void setHologramLine3(String hologramLine3) {
      this.hologramLine3 = hologramLine3;
   }

   public boolean isFloatingAnimation() {
      return this.floatingAnimation;
   }

   public void setFloatingAnimation(boolean floatingAnimation) {
      this.floatingAnimation = floatingAnimation;
   }

   public double getParticleRadius() {
      return this.particleRadius;
   }

   public void setParticleRadius(double particleRadius) {
      this.particleRadius = particleRadius;
   }

   public int getParticleCount() {
      return this.particleCount;
   }

   public void setParticleCount(int particleCount) {
      this.particleCount = particleCount;
   }

   public AnimationType getAnimationType() {
      return this.animationType;
   }

   public void setAnimationType(AnimationType animationType) {
      this.animationType = animationType;
   }
}
