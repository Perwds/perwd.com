package com.lootcrates.commands;

import com.lootcrates.LootCrates;
import com.lootcrates.models.CustomCrate;
import com.lootcrates.models.HistoryEntry;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.command.TabCompleter;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;

public class LootCrateCommand implements CommandExecutor, TabCompleter {
   private final LootCrates plugin;

   public LootCrateCommand(LootCrates plugin) {
      this.plugin = plugin;
      plugin.getCommand("lootcrate").setTabCompleter(this);
   }

   public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
      if (sender instanceof Player player) {
         if (args.length == 0) {
            this.sendHelp(player);
            return true;
         } else {
            String subCommand = args[0].toLowerCase();
            switch (subCommand) {
               case "help":
                  this.sendHelp(player);
                  break;
               case "daily":
                  this.handleDaily(player);
                  break;
               case "history":
                  this.handleHistory(player, args);
                  break;
               case "list":
                  this.handleList(player);
                  break;
               default:
                  this.sendHelp(player);
            }

            return true;
         }
      } else {
         sender.sendMessage("This command can only be used by players!");
         return true;
      }
   }

   private void sendHelp(Player player) {
      player.sendMessage(LootCrates.colorize("&6&l=== LootCrates Help ==="));
      player.sendMessage(LootCrates.colorize("&e/lootcrate daily &7- Claim your daily reward"));
      player.sendMessage(LootCrates.colorize("&e/lootcrate history [page] &7- View your loot history"));
      player.sendMessage(LootCrates.colorize("&e/lootcrate list &7- View available crate types"));
      player.sendMessage(LootCrates.colorize("&7"));
      player.sendMessage(LootCrates.colorize("&7Right-click a placed crate with the matching key to open!"));
   }

   private void handleDaily(Player player) {
      if (!player.hasPermission("lootcrates.daily")) {
         player.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("no-permission"));
      } else if (!this.plugin.getConfig().getBoolean("daily-reward.enabled", true)) {
         player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cDaily rewards are disabled!"));
      } else if (!this.plugin.getDataManager().canClaimDaily(player.getUniqueId())) {
         String time = this.plugin.getDataManager().getRemainingCooldownFormatted(player.getUniqueId());
         player.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("daily-cooldown").replace("%time%", time));
      } else {
         // config.yml shipped with "reward-tier", but only "reward-crate" was ever read.
         String crateId = this.plugin.getConfig().getString("daily-reward.reward-crate", this.plugin.getConfig().getString("daily-reward.reward-tier", "common"));
         CustomCrate crate = this.plugin.getCustomCrateManager().getCrate(crateId);
         if (crate == null && !this.plugin.getCustomCrateManager().getAllCrates().isEmpty()) {
            crate = this.plugin.getCustomCrateManager().getAllCrates().iterator().next();
         }

         if (crate == null) {
            player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cNo crates configured!"));
         } else {
            ItemStack crateItem = crate.createCrateItem(1);
            ItemStack keyItem = crate.createKeyItem(1);
            if (player.getInventory().firstEmpty() == -1) {
               player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cYour inventory is full!"));
            } else {
               // Two items but only one free slot used to delete the key; drop whatever doesn't fit instead.
               boolean dropped = LootCrates.giveOrDrop(player, crateItem);
               dropped |= LootCrates.giveOrDrop(player, keyItem);
               this.plugin.getDataManager().setDailyCooldown(player.getUniqueId(), System.currentTimeMillis());
               player.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("daily-claimed"));
               player.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("crate-received").replace("%crate%", LootCrates.colorize(crate.getDisplayName())));
               player.sendMessage(
                  this.plugin.getPrefix()
                     + this.plugin.getMessage("key-received").replace("%amount%", "1").replace("%key%", LootCrates.colorize(crate.getKeyName()))
               );
               if (dropped) {
                  player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&eInventory full! Dropped on ground."));
               }
            }
         }
      }
   }

   private void handleHistory(Player player, String[] args) {
      if (!player.hasPermission("lootcrates.history")) {
         player.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("no-permission"));
      } else {
         int page = 1;
         if (args.length > 1) {
            try {
               page = Integer.parseInt(args[1]);
            } catch (NumberFormatException var14) {
               page = 1;
            }
         }

         List<HistoryEntry> history = this.plugin.getHistoryManager().getHistory(player.getUniqueId());
         if (history.isEmpty()) {
            player.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("history-empty"));
         } else {
            int entriesPerPage = 10;
            int totalPages = (int)Math.ceil((double)history.size() / entriesPerPage);
            page = Math.max(1, Math.min(page, totalPages));
            int startIndex = (page - 1) * entriesPerPage;
            int endIndex = Math.min(startIndex + entriesPerPage, history.size());
            player.sendMessage(
               this.plugin.getPrefix() + this.plugin.getMessage("history-header") + LootCrates.colorize(" &7(Page " + page + "/" + totalPages + ")")
            );

            for (int i = startIndex; i < endIndex; i++) {
               HistoryEntry entry = history.get(i);
               CustomCrate crate = this.plugin.getCustomCrateManager().getCrate(entry.getCrateId());
               String crateName = crate != null ? crate.getDisplayName() : entry.getCrateId();
               String message = this.plugin.getMessage("history-entry");
               message = message.replace("%reward%", LootCrates.rewardWithAmount(message, "%reward%", entry.getRewardName(), entry.getAmount()))
                  .replace("%date%", entry.getFormattedDate())
                  .replace("%tier%", LootCrates.colorize(crateName));
               player.sendMessage(message);
            }
         }
      }
   }

   private void handleList(Player player) {
      player.sendMessage(LootCrates.colorize("&6&l=== Available Crate Types ==="));

      for (CustomCrate crate : this.plugin.getCustomCrateManager().getAllCrates()) {
         int rewardCount = this.plugin.getRewardManager().getRewards(crate.getId()).size();
         player.sendMessage(LootCrates.colorize("&7- " + crate.getDisplayName() + " &8(" + rewardCount + " rewards)"));
      }

      if (this.plugin.getCustomCrateManager().getAllCrates().isEmpty()) {
         player.sendMessage(LootCrates.colorize("&7No crates available yet!"));
      }
   }

   public List<String> onTabComplete(CommandSender sender, Command command, String alias, String[] args) {
      return (List<String>)(args.length == 1 ? this.filterCompletions(Arrays.asList("help", "daily", "history", "list"), args[0]) : new ArrayList<>());
   }

   private List<String> filterCompletions(List<String> completions, String input) {
      return completions.stream().filter(s -> s.toLowerCase().startsWith(input.toLowerCase())).collect(Collectors.toList());
   }
}
