package com.lootcrates.managers;

import com.lootcrates.LootCrates;
import com.lootcrates.models.HistoryEntry;
import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.Map.Entry;
import org.bukkit.configuration.file.FileConfiguration;
import org.bukkit.configuration.file.YamlConfiguration;

public class HistoryManager {
   private final LootCrates plugin;
   private final File historyFile;
   private FileConfiguration historyConfig;
   private final Map<UUID, List<HistoryEntry>> playerHistory;
   private static final int MAX_HISTORY_PER_PLAYER = 50;

   public HistoryManager(LootCrates plugin) {
      this.plugin = plugin;
      this.historyFile = new File(plugin.getDataFolder(), "history.yml");
      this.playerHistory = new HashMap<>();
      this.loadHistory();
   }

   private void loadHistory() {
      if (!this.historyFile.exists()) {
         try {
            this.historyFile.getParentFile().mkdirs();
            this.historyFile.createNewFile();
         } catch (IOException var9) {
            this.plugin.getLogger().severe("Could not create history.yml: " + var9.getMessage());
         }
      }

      this.historyConfig = YamlConfiguration.loadConfiguration(this.historyFile);
      if (this.historyConfig.contains("history")) {
         for (String uuidStr : this.historyConfig.getConfigurationSection("history").getKeys(false)) {
            try {
               UUID uuid = UUID.fromString(uuidStr);
               List<String> entries = this.historyConfig.getStringList("history." + uuidStr);
               List<HistoryEntry> historyEntries = new ArrayList<>();

               for (String entry : entries) {
                  HistoryEntry historyEntry = HistoryEntry.deserialize(entry);
                  if (historyEntry != null) {
                     historyEntries.add(historyEntry);
                  }
               }

               this.playerHistory.put(uuid, historyEntries);
            } catch (IllegalArgumentException var10) {
               this.plugin.getLogger().warning("Invalid UUID in history: " + uuidStr);
            }
         }
      }
   }

   public void saveAll() {
      for (Entry<UUID, List<HistoryEntry>> entry : this.playerHistory.entrySet()) {
         List<String> serialized = new ArrayList<>();

         for (HistoryEntry historyEntry : entry.getValue()) {
            serialized.add(historyEntry.serialize());
         }

         this.historyConfig.set("history." + entry.getKey().toString(), serialized);
      }

      try {
         this.historyConfig.save(this.historyFile);
      } catch (IOException var6) {
         this.plugin.getLogger().severe("Could not save history.yml: " + var6.getMessage());
      }
   }

   public void addEntry(UUID uuid, String crateId, String rewardName, int amount) {
      List<HistoryEntry> entries = this.playerHistory.computeIfAbsent(uuid, k -> new ArrayList<>());
      entries.add(0, new HistoryEntry(crateId, rewardName, amount));

      while (entries.size() > 50) {
         entries.remove(entries.size() - 1);
      }
   }

   public List<HistoryEntry> getHistory(UUID uuid) {
      return this.playerHistory.getOrDefault(uuid, new ArrayList<>());
   }

   public List<HistoryEntry> getHistory(UUID uuid, int limit) {
      List<HistoryEntry> entries = this.getHistory(uuid);
      return entries.size() <= limit ? entries : entries.subList(0, limit);
   }
}
