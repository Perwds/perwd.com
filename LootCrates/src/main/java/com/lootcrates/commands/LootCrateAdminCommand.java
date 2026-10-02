package com.lootcrates.commands;

import com.lootcrates.LootCrates;
import com.lootcrates.models.CustomCrate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;
import org.bukkit.Bukkit;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.command.TabCompleter;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;

public class LootCrateAdminCommand implements CommandExecutor, TabCompleter {
   private final LootCrates plugin;

   public LootCrateAdminCommand(LootCrates plugin) {
      this.plugin = plugin;
      plugin.getCommand("lcadmin").setTabCompleter(this);
   }

   public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
      if (!sender.hasPermission("lootcrates.admin")) {
         sender.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("no-permission"));
         return true;
      } else if (args.length == 0) {
         this.sendHelp(sender);
         return true;
      } else {
         String subCommand = args[0].toLowerCase();
         switch (subCommand) {
            case "help":
               this.sendHelp(sender);
               break;
            case "give":
               this.handleGive(sender, args);
               break;
            case "givekey":
               this.handleGiveKey(sender, args);
               break;
            case "edit":
               this.handleEdit(sender);
               break;
            case "list":
               this.handleList(sender);
               break;
            case "reload":
               this.handleReload(sender);
               break;
            default:
               this.sendHelp(sender);
         }

         return true;
      }
   }

   private void sendHelp(CommandSender sender) {
      sender.sendMessage(LootCrates.colorize("&6&l=== LootCrates Admin Help ==="));
      sender.sendMessage(LootCrates.colorize("&e/lcadmin give <player> <crateId> [amount] &7- Give a crate"));
      sender.sendMessage(LootCrates.colorize("&e/lcadmin givekey <player> <crateId> [amount] &7- Give a key"));
      sender.sendMessage(LootCrates.colorize("&e/lcadmin edit &7- Open crate editor GUI"));
      sender.sendMessage(LootCrates.colorize("&e/lcadmin list &7- List all crate types"));
      sender.sendMessage(LootCrates.colorize("&e/lcadmin reload &7- Reload config"));
      sender.sendMessage(LootCrates.colorize("&7"));
      sender.sendMessage(LootCrates.colorize("&ePlacing Crates:"));
      sender.sendMessage(LootCrates.colorize("&7- Get a crate with /lcadmin give"));
      sender.sendMessage(LootCrates.colorize("&7- Place it as a block to create a crate station"));
      sender.sendMessage(LootCrates.colorize("&7- Holograms and particles will appear!"));
   }

   private void handleGive(CommandSender sender, String[] args) {
      if (!sender.hasPermission("lootcrates.admin.give")) {
         sender.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("no-permission"));
      } else if (args.length < 3) {
         sender.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cUsage: /lcadmin give <player> <crateId> [amount]"));
      } else {
         Player target = Bukkit.getPlayer(args[1]);
         if (target == null) {
            sender.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("player-not-found"));
         } else {
            String crateId = args[2].toLowerCase();
            CustomCrate crate = this.plugin.getCustomCrateManager().getCrate(crateId);
            if (crate == null) {
               sender.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cCrate not found: " + crateId));
               sender.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&7Use /lcadmin list to see available crates"));
            } else {
               int amount = 1;
               if (args.length > 3) {
                  try {
                     amount = Integer.parseInt(args[3]);
                     amount = Math.max(1, Math.min(amount, 64));
                  } catch (NumberFormatException var8) {
                     amount = 1;
                  }
               }

               ItemStack crateItem = crate.createCrateItem(amount);
               if (LootCrates.giveOrDrop(target, crateItem)) {
                  sender.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&ePlayer's inventory was full, dropped on ground."));
               }

               target.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("crate-received").replace("%crate%", LootCrates.colorize(crate.getDisplayName())));
               sender.sendMessage(
                  this.plugin.getPrefix() + LootCrates.colorize("&aGave " + amount + "x " + crate.getDisplayName() + " &ato " + target.getName())
               );
            }
         }
      }
   }

   private void handleGiveKey(CommandSender sender, String[] args) {
      if (!sender.hasPermission("lootcrates.admin.givekey")) {
         sender.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("no-permission"));
      } else if (args.length < 3) {
         sender.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cUsage: /lcadmin givekey <player> <crateId> [amount]"));
      } else {
         Player target = Bukkit.getPlayer(args[1]);
         if (target == null) {
            sender.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("player-not-found"));
         } else {
            String crateId = args[2].toLowerCase();
            CustomCrate crate = this.plugin.getCustomCrateManager().getCrate(crateId);
            if (crate == null) {
               sender.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cCrate not found: " + crateId));
               sender.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&7Use /lcadmin list to see available crates"));
            } else {
               int amount = 1;
               if (args.length > 3) {
                  try {
                     amount = Integer.parseInt(args[3]);
                     amount = Math.max(1, Math.min(amount, 64));
                  } catch (NumberFormatException var8) {
                     amount = 1;
                  }
               }

               ItemStack keyItem = crate.createKeyItem(amount);
               if (LootCrates.giveOrDrop(target, keyItem)) {
                  sender.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&ePlayer's inventory was full, dropped on ground."));
               }

               target.sendMessage(
                  this.plugin.getPrefix()
                     + this.plugin.getMessage("key-received").replace("%amount%", String.valueOf(amount)).replace("%key%", LootCrates.colorize(crate.getKeyName()))
               );
               sender.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&aGave " + amount + "x " + crate.getKeyName() + " &ato " + target.getName()));
            }
         }
      }
   }

   private void handleList(CommandSender sender) {
      sender.sendMessage(LootCrates.colorize("&6&l=== Available Crates ==="));

      for (CustomCrate crate : this.plugin.getCustomCrateManager().getAllCrates()) {
         int rewardCount = this.plugin.getRewardManager().getRewards(crate.getId()).size();
         sender.sendMessage(LootCrates.colorize("&e" + crate.getId() + " &7- " + crate.getDisplayName() + " &8(" + rewardCount + " rewards)"));
      }

      if (this.plugin.getCustomCrateManager().getAllCrates().isEmpty()) {
         sender.sendMessage(LootCrates.colorize("&7No crates configured! Use /lcadmin edit to create some."));
      }
   }

   private void handleReload(CommandSender sender) {
      if (!sender.hasPermission("lootcrates.admin.reload")) {
         sender.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("no-permission"));
      } else {
         this.plugin.reloadPlugin();
         sender.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("reload-success"));
      }
   }

   private void handleEdit(CommandSender sender) {
      if (sender instanceof Player player) {
         if (!player.hasPermission("lootcrates.admin.edit")) {
            player.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("no-permission"));
         } else {
            this.plugin.getCrateEditGUI().openCrateSelectGUI(player);
         }
      } else {
         sender.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cThis command can only be used by players!"));
      }
   }

   public List<String> onTabComplete(CommandSender sender, Command command, String alias, String[] args) {
      if (args.length == 1) {
         return this.filterCompletions(Arrays.asList("help", "give", "givekey", "edit", "list", "reload"), args[0]);
      } else if (args.length != 2 || !args[0].equalsIgnoreCase("give") && !args[0].equalsIgnoreCase("givekey")) {
         return (List<String>)(args.length != 3 || !args[0].equalsIgnoreCase("give") && !args[0].equalsIgnoreCase("givekey")
            ? new ArrayList<>()
            : this.filterCompletions(this.plugin.getCustomCrateManager().getAllCrates().stream().map(CustomCrate::getId).collect(Collectors.toList()), args[2]));
      } else {
         return this.filterCompletions(Bukkit.getOnlinePlayers().stream().<String>map(Player::getName).collect(Collectors.toList()), args[1]);
      }
   }

   private List<String> filterCompletions(List<String> completions, String input) {
      return completions.stream().filter(s -> s.toLowerCase().startsWith(input.toLowerCase())).collect(Collectors.toList());
   }
}
