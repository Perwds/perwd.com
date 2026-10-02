package com.lootcrates.managers;

import com.lootcrates.LootCrates;
import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.Map.Entry;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.configuration.file.YamlConfiguration;

public class DataManager {
   private final LootCrates plugin;
   private final File dataFile;
   private FileConfiguration dataConfig;
   private final Map<UUID, Long> dailyCooldowns;

   public DataManager(LootCrates plugin) {
      this.plugin = plugin;
      this.dataFile = new File(plugin.getDataFolder(), "playerdata.yml");
      this.dailyCooldowns = new HashMap<>();
      this.loadData();
   }

   private void loadData() {
      if (!this.dataFile.exists()) {
         try {
            this.dataFile.getParentFile().mkdirs();
            this.dataFile.createNewFile();
         } catch (IOException var7) {
            this.plugin.getLogger().severe("Could not create playerdata.yml: " + var7.getMessage());
         }
      }

      this.dataConfig = YamlConfiguration.loadConfiguration(this.dataFile);
      if (this.dataConfig.contains("daily-cooldowns")) {
         for (String uuidStr : this.dataConfig.getConfigurationSection("daily-cooldowns").getKeys(false)) {
            try {
               UUID uuid = UUID.fromString(uuidStr);
               long timestamp = this.dataConfig.getLong("daily-cooldowns." + uuidStr);
               this.dailyCooldowns.put(uuid, timestamp);
            } catch (IllegalArgumentException var6) {
               this.plugin.getLogger().warning("Invalid UUID in playerdata: " + uuidStr);
            }
         }
      }
   }

   public void saveAll() {
      for (Entry<UUID, Long> entry : this.dailyCooldowns.entrySet()) {
         this.dataConfig.set("daily-cooldowns." + entry.getKey().toString(), entry.getValue());
      }

      try {
         this.dataConfig.save(this.dataFile);
      } catch (IOException var3) {
         this.plugin.getLogger().severe("Could not save playerdata.yml: " + var3.getMessage());
      }
   }

   public long getDailyCooldown(UUID uuid) {
      return this.dailyCooldowns.getOrDefault(uuid, 0L);
   }

   public void setDailyCooldown(UUID uuid, long timestamp) {
      this.dailyCooldowns.put(uuid, timestamp);
      // Save right away; otherwise a crash lets everyone claim their daily reward again.
      this.saveAll();
   }

   public boolean canClaimDaily(UUID uuid) {
      long lastClaim = this.getDailyCooldown(uuid);
      if (lastClaim == 0L) {
         return true;
      } else {
         int cooldownHours = this.plugin.getConfig().getInt("daily-reward.cooldown-hours", 24);
         long cooldownMillis = cooldownHours * 60 * 60 * 1000L;
         return System.currentTimeMillis() >= lastClaim + cooldownMillis;
      }
   }

   public String getRemainingCooldownFormatted(UUID uuid) {
      long lastClaim = this.getDailyCooldown(uuid);
      int cooldownHours = this.plugin.getConfig().getInt("daily-reward.cooldown-hours", 24);
      long cooldownMillis = cooldownHours * 60 * 60 * 1000L;
      long remaining = lastClaim + cooldownMillis - System.currentTimeMillis();
      if (remaining <= 0L) {
         return "0s";
      } else {
         long hours = remaining / 3600000L;
         long minutes = remaining % 3600000L / 60000L;
         long seconds = remaining % 60000L / 1000L;
         StringBuilder sb = new StringBuilder();
         if (hours > 0L) {
            sb.append(hours).append("h ");
         }

         if (minutes > 0L) {
            sb.append(minutes).append("m ");
         }

         sb.append(seconds).append("s");
         return sb.toString().trim();
      }
   }
}
