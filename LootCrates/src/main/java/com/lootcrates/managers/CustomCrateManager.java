package com.lootcrates.managers;

import com.lootcrates.LootCrates;
import com.lootcrates.animation.AnimationType;
import com.lootcrates.models.CustomCrate;
import java.io.File;
import java.io.IOException;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.bukkit.Color;
import org.bukkit.Material;
import org.bukkit.Particle;
import org.bukkit.Sound;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.inventory.ItemStack;

public class CustomCrateManager {
   private final LootCrates plugin;
   private final File cratesFile;
   private FileConfiguration cratesConfig;
   private final Map<String, CustomCrate> crates = new LinkedHashMap<>();

   public CustomCrateManager(LootCrates plugin) {
      this.plugin = plugin;
      this.cratesFile = new File(plugin.getDataFolder(), "crates.yml");
      this.loadCrates();
   }

   public void loadCrates() {
      this.crates.clear();
      if (!this.cratesFile.exists()) {
         this.createDefaultCrates();
      }

      this.cratesConfig = YamlConfiguration.loadConfiguration(this.cratesFile);
      ConfigurationSection cratesSection = this.cratesConfig.getConfigurationSection("crates");
      if (cratesSection == null) {
         this.createDefaultCrates();
         this.cratesConfig = YamlConfiguration.loadConfiguration(this.cratesFile);
         cratesSection = this.cratesConfig.getConfigurationSection("crates");
      }

      for (String crateId : cratesSection.getKeys(false)) {
         ConfigurationSection section = cratesSection.getConfigurationSection(crateId);
         if (section != null) {
            CustomCrate crate = new CustomCrate(crateId);
            crate.setDisplayName(section.getString("display-name", "&f" + crateId + " Crate"));
            crate.setKeyName(section.getString("key-name", "&f" + crateId + " Key"));

            try {
               crate.setCrateMaterial(Material.valueOf(section.getString("crate-material", "CHEST")));
            } catch (Exception var13) {
               crate.setCrateMaterial(Material.CHEST);
            }

            try {
               crate.setKeyMaterial(Material.valueOf(section.getString("key-material", "TRIPWIRE_HOOK")));
            } catch (Exception var12) {
               crate.setKeyMaterial(Material.TRIPWIRE_HOOK);
            }

            try {
               crate.setParticle(Particle.valueOf(section.getString("particle", "HAPPY_VILLAGER")));
            } catch (Exception var11) {
               crate.setParticle(Particle.HAPPY_VILLAGER);
            }

            String colorStr = section.getString("particle-color", "WHITE");
            crate.setParticleColor(this.parseColor(colorStr));

            try {
               crate.setOpenSound(Sound.valueOf(section.getString("open-sound", "BLOCK_CHEST_OPEN")));
            } catch (Exception var10) {
               crate.setOpenSound(Sound.BLOCK_CHEST_OPEN);
            }

            try {
               crate.setWinSound(Sound.valueOf(section.getString("win-sound", "ENTITY_PLAYER_LEVELUP")));
            } catch (Exception var9) {
               crate.setWinSound(Sound.ENTITY_PLAYER_LEVELUP);
            }

            crate.setHologramLine1(section.getString("hologram.line1", crate.getDisplayName()));
            crate.setHologramLine2(section.getString("hologram.line2", "&7Right-click with key to open!"));
            crate.setHologramLine3(section.getString("hologram.line3", "&e✦ " + crateId.toUpperCase() + " ✦"));
            crate.setFloatingAnimation(section.getBoolean("effects.floating", true));
            crate.setParticleRadius(section.getDouble("effects.particle-radius", 0.8));
            crate.setParticleCount(section.getInt("effects.particle-count", 2));

            try {
               String animStr = section.getString("animation-type", "CLASSIC");
               crate.setAnimationType(AnimationType.valueOf(animStr.toUpperCase()));
            } catch (Exception var8) {
               crate.setAnimationType(AnimationType.CLASSIC);
            }

            this.crates.put(crateId.toLowerCase(), crate);
            this.plugin.getLogger().info("Loaded crate: " + crateId);
         }
      }

      this.plugin.getLogger().info("Loaded " + this.crates.size() + " crates");
   }

   private void createDefaultCrates() {
      this.cratesConfig = new YamlConfiguration();
      this.createDefaultCrate(
         "common", "&fCommon Crate", "&fCommon Key", "WHITE", "HAPPY_VILLAGER", Material.CHEST, "BLOCK_CHEST_OPEN", "ENTITY_PLAYER_LEVELUP", "&f✦ COMMON ✦"
      );
      this.createDefaultCrate(
         "rare", "&9Rare Crate", "&9Rare Key", "BLUE", "ENCHANT", Material.CHEST, "BLOCK_CHEST_OPEN", "ENTITY_PLAYER_LEVELUP", "&9✦ RARE ✦"
      );
      this.createDefaultCrate(
         "epic",
         "&5Epic Crate",
         "&5Epic Key",
         "PURPLE",
         "DRAGON_BREATH",
         Material.ENDER_CHEST,
         "BLOCK_ENDER_CHEST_OPEN",
         "UI_TOAST_CHALLENGE_COMPLETE",
         "&5✦ EPIC ✦"
      );
      this.createDefaultCrate(
         "legendary",
         "&6&lLegendary Crate",
         "&6&lLegendary Key",
         "ORANGE",
         "FLAME",
         Material.ENDER_CHEST,
         "BLOCK_ENDER_CHEST_OPEN",
         "UI_TOAST_CHALLENGE_COMPLETE",
         "&6&l✦ LEGENDARY ✦"
      );
      this.createDefaultCrate(
         "mythic",
         "&d&lMythic Crate",
         "&d&lMythic Key",
         "FUCHSIA",
         "TOTEM_OF_UNDYING",
         Material.ENDER_CHEST,
         "ENTITY_ENDER_DRAGON_GROWL",
         "UI_TOAST_CHALLENGE_COMPLETE",
         "&d&l✦ MYTHIC ✦"
      );
      this.saveCrates();
   }

   private void createDefaultCrate(
      String id, String displayName, String keyName, String color, String particle, Material material, String openSound, String winSound, String tierText
   ) {
      String path = "crates." + id;
      this.cratesConfig.set(path + ".display-name", displayName);
      this.cratesConfig.set(path + ".key-name", keyName);
      this.cratesConfig.set(path + ".crate-material", material.name());
      this.cratesConfig.set(path + ".key-material", "TRIPWIRE_HOOK");
      this.cratesConfig.set(path + ".particle", particle);
      this.cratesConfig.set(path + ".particle-color", color);
      this.cratesConfig.set(path + ".open-sound", openSound);
      this.cratesConfig.set(path + ".win-sound", winSound);
      this.cratesConfig.set(path + ".hologram.line1", displayName);
      this.cratesConfig.set(path + ".hologram.line2", "&7Right-click with key to open!");
      this.cratesConfig.set(path + ".hologram.line3", tierText);
      this.cratesConfig.set(path + ".effects.floating", true);
      this.cratesConfig.set(path + ".effects.particle-radius", 0.8);
      this.cratesConfig.set(path + ".effects.particle-count", 2);
      this.cratesConfig.set(path + ".animation-type", "CLASSIC");
   }

   public void createCrate(String id, String displayName, String color) {
      CustomCrate crate = new CustomCrate(id);
      crate.setDisplayName(displayName);
      crate.setKeyName(displayName.replace("Crate", "Key"));
      crate.setParticleColor(this.parseColor(color));
      crate.setHologramLine3("&e✦ " + id.toUpperCase() + " ✦");
      this.crates.put(id.toLowerCase(), crate);
      String path = "crates." + id.toLowerCase();
      this.cratesConfig.set(path + ".display-name", displayName);
      this.cratesConfig.set(path + ".key-name", crate.getKeyName());
      this.cratesConfig.set(path + ".crate-material", crate.getCrateMaterial().name());
      this.cratesConfig.set(path + ".key-material", crate.getKeyMaterial().name());
      this.cratesConfig.set(path + ".particle", crate.getParticle().name());
      this.cratesConfig.set(path + ".particle-color", color);
      this.cratesConfig.set(path + ".open-sound", crate.getOpenSound().name());
      this.cratesConfig.set(path + ".win-sound", crate.getWinSound().name());
      this.cratesConfig.set(path + ".hologram.line1", crate.getHologramLine1());
      this.cratesConfig.set(path + ".hologram.line2", crate.getHologramLine2());
      this.cratesConfig.set(path + ".hologram.line3", crate.getHologramLine3());
      this.cratesConfig.set(path + ".effects.floating", true);
      this.cratesConfig.set(path + ".effects.particle-radius", 0.8);
      this.cratesConfig.set(path + ".effects.particle-count", 2);
      this.cratesConfig.set(path + ".animation-type", crate.getAnimationType().name());
      this.saveCrates();
   }

   public void deleteCrate(String id) {
      this.crates.remove(id.toLowerCase());
      this.cratesConfig.set("crates." + id.toLowerCase(), null);
      this.saveCrates();
   }

   public void saveCrates() {
      for (CustomCrate crate : this.crates.values()) {
         String path = "crates." + crate.getId().toLowerCase();
         this.cratesConfig.set(path + ".display-name", crate.getDisplayName());
         this.cratesConfig.set(path + ".key-name", crate.getKeyName());
         this.cratesConfig.set(path + ".crate-material", crate.getCrateMaterial().name());
         this.cratesConfig.set(path + ".key-material", crate.getKeyMaterial().name());
         this.cratesConfig.set(path + ".particle", crate.getParticle().name());
         this.cratesConfig.set(path + ".particle-color", this.colorToString(crate.getParticleColor()));
         this.cratesConfig.set(path + ".open-sound", crate.getOpenSound().name());
         this.cratesConfig.set(path + ".win-sound", crate.getWinSound().name());
         this.cratesConfig.set(path + ".hologram.line1", crate.getHologramLine1());
         this.cratesConfig.set(path + ".hologram.line2", crate.getHologramLine2());
         this.cratesConfig.set(path + ".hologram.line3", crate.getHologramLine3());
         this.cratesConfig.set(path + ".effects.floating", crate.isFloatingAnimation());
         this.cratesConfig.set(path + ".effects.particle-radius", crate.getParticleRadius());
         this.cratesConfig.set(path + ".effects.particle-count", crate.getParticleCount());
         this.cratesConfig.set(path + ".animation-type", crate.getAnimationType().name());
      }

      try {
         this.cratesConfig.save(this.cratesFile);
      } catch (IOException var4) {
         this.plugin.getLogger().severe("Could not save crates.yml: " + var4.getMessage());
      }
   }

   private String colorToString(Color color) {
      if (color.equals(Color.RED)) {
         return "RED";
      } else if (color.equals(Color.BLUE)) {
         return "BLUE";
      } else if (color.equals(Color.GREEN)) {
         return "GREEN";
      } else if (color.equals(Color.YELLOW)) {
         return "YELLOW";
      } else if (color.equals(Color.ORANGE)) {
         return "ORANGE";
      } else if (color.equals(Color.PURPLE)) {
         return "PURPLE";
      } else if (color.equals(Color.FUCHSIA)) {
         return "FUCHSIA";
      } else if (color.equals(Color.AQUA)) {
         return "AQUA";
      } else if (color.equals(Color.LIME)) {
         return "LIME";
      } else {
         return color.equals(Color.BLACK) ? "BLACK" : "WHITE";
      }
   }

   public CustomCrate getCrate(String id) {
      return this.crates.get(id.toLowerCase());
   }

   public Collection<CustomCrate> getAllCrates() {
      return this.crates.values();
   }

   public Set<String> getCrateIds() {
      return this.crates.keySet();
   }

   public CustomCrate getCrateFromItem(ItemStack item) {
      for (CustomCrate crate : this.crates.values()) {
         if (crate.isCrateItem(item)) {
            return crate;
         }
      }

      return null;
   }

   public CustomCrate getCrateFromKey(ItemStack item) {
      for (CustomCrate crate : this.crates.values()) {
         if (crate.isKeyItem(item)) {
            return crate;
         }
      }

      return null;
   }

   private Color parseColor(String colorStr) {
      String var2 = colorStr.toUpperCase();

      return switch (var2) {
         case "RED" -> Color.RED;
         case "BLUE" -> Color.BLUE;
         case "GREEN" -> Color.GREEN;
         case "YELLOW" -> Color.YELLOW;
         case "ORANGE" -> Color.ORANGE;
         case "PURPLE" -> Color.PURPLE;
         case "FUCHSIA", "PINK" -> Color.FUCHSIA;
         case "AQUA", "CYAN" -> Color.AQUA;
         case "LIME" -> Color.LIME;
         case "BLACK" -> Color.BLACK;
         case "GRAY" -> Color.GRAY;
         case "SILVER" -> Color.SILVER;
         default -> Color.WHITE;
      };
   }

   public void reloadCrates() {
      this.loadCrates();
   }
}
