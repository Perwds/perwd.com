package com.lootcrates.managers;

import com.lootcrates.LootCrates;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Map.Entry;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.inventory.ItemStack;

public class RewardManager {
   private final LootCrates plugin;
   private final File rewardsFile;
   private FileConfiguration rewardsConfig;
   private final Map<String, List<RewardManager.Reward>> rewards = new HashMap<>();
   private final Random random = new Random();

   public RewardManager(LootCrates plugin) {
      this.plugin = plugin;
      this.rewardsFile = new File(plugin.getDataFolder(), "rewards.yml");
      this.loadRewards();
   }

   public void addReward(String crateId, ItemStack item, int weight) {
      List<RewardManager.Reward> crateRewards = this.rewards.computeIfAbsent(crateId.toLowerCase(), k -> new ArrayList<>());
      crateRewards.add(new RewardManager.Reward(item.clone(), weight));
      this.saveRewards();
   }

   public void removeReward(String crateId, int index) {
      List<RewardManager.Reward> crateRewards = this.rewards.get(crateId.toLowerCase());
      if (crateRewards != null && index >= 0 && index < crateRewards.size()) {
         crateRewards.remove(index);
         this.saveRewards();
      }
   }

   public void updateRewardWeight(String crateId, int index, int newWeight) {
      List<RewardManager.Reward> crateRewards = this.rewards.get(crateId.toLowerCase());
      if (crateRewards != null && index >= 0 && index < crateRewards.size()) {
         crateRewards.get(index).setWeight(newWeight);
         this.saveRewards();
      }
   }

   public List<RewardManager.Reward> getRewards(String crateId) {
      return this.rewards.getOrDefault(crateId.toLowerCase(), new ArrayList<>());
   }

   public RewardManager.Reward rollReward(String crateId) {
      List<RewardManager.Reward> crateRewards = this.getRewards(crateId);
      if (crateRewards.isEmpty()) {
         return null;
      } else {
         int totalWeight = crateRewards.stream().mapToInt(RewardManager.Reward::getWeight).sum();
         if (totalWeight <= 0) {
            return crateRewards.get(0);
         } else {
            int roll = this.random.nextInt(totalWeight);
            int currentWeight = 0;

            for (RewardManager.Reward reward : crateRewards) {
               currentWeight += reward.getWeight();
               if (roll < currentWeight) {
                  return reward;
               }
            }

            return crateRewards.get(crateRewards.size() - 1);
         }
      }
   }

   public void clearRewards(String crateId) {
      this.rewards.remove(crateId.toLowerCase());
      this.saveRewards();
   }

   private void loadRewards() {
      if (!this.rewardsFile.exists()) {
         try {
            this.rewardsFile.getParentFile().mkdirs();
            this.rewardsFile.createNewFile();
         } catch (IOException var9) {
            this.plugin.getLogger().severe("Could not create rewards.yml");
         }
      } else {
         this.rewardsConfig = YamlConfiguration.loadConfiguration(this.rewardsFile);
         if (this.rewardsConfig.contains("rewards")) {
            for (String crateId : this.rewardsConfig.getConfigurationSection("rewards").getKeys(false)) {
               List<RewardManager.Reward> crateRewards = new ArrayList<>();

               for (String key : this.rewardsConfig.getConfigurationSection("rewards." + crateId).getKeys(false)) {
                  try {
                     String path = "rewards." + crateId + "." + key;
                     ItemStack item = this.rewardsConfig.getItemStack(path + ".item");
                     int weight = this.rewardsConfig.getInt(path + ".weight", 10);
                     if (item != null) {
                        crateRewards.add(new RewardManager.Reward(item, weight));
                     }
                  } catch (Exception var10) {
                     this.plugin.getLogger().warning("Failed to load reward: " + crateId + "." + key);
                  }
               }

               if (!crateRewards.isEmpty()) {
                  this.rewards.put(crateId.toLowerCase(), crateRewards);
               }
            }

            this.plugin.getLogger().info("Loaded rewards for " + this.rewards.size() + " crates");
         }
      }
   }

   public void saveRewards() {
      this.rewardsConfig = new YamlConfiguration();

      for (Entry<String, List<RewardManager.Reward>> entry : this.rewards.entrySet()) {
         String crateId = entry.getKey();
         List<RewardManager.Reward> crateRewards = entry.getValue();

         for (int i = 0; i < crateRewards.size(); i++) {
            RewardManager.Reward reward = crateRewards.get(i);
            String path = "rewards." + crateId + "." + i;
            this.rewardsConfig.set(path + ".item", reward.getItem());
            this.rewardsConfig.set(path + ".weight", reward.getWeight());
         }
      }

      try {
         this.rewardsConfig.save(this.rewardsFile);
      } catch (IOException var8) {
         this.plugin.getLogger().severe("Could not save rewards.yml");
      }
   }

   public void reloadRewards() {
      this.rewards.clear();
      this.loadRewards();
   }

   public static class Reward {
      private final ItemStack item;
      private int weight;

      public Reward(ItemStack item, int weight) {
         this.item = item;
         this.weight = weight;
      }

      public ItemStack getItem() {
         return this.item.clone();
      }

      public int getWeight() {
         return this.weight;
      }

      public void setWeight(int weight) {
         this.weight = Math.max(1, weight);
      }

      public String getDisplayName() {
         return this.item.getItemMeta() != null && this.item.getItemMeta().hasDisplayName()
            ? this.item.getItemMeta().getDisplayName()
            : this.item.getType().name().replace("_", " ");
      }
   }
}
