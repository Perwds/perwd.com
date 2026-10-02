package com.lootcrates.listeners;

import com.lootcrates.LootCrates;
import com.lootcrates.managers.RewardManager;
import com.lootcrates.models.CustomCrate;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.bukkit.Bukkit;
import org.bukkit.GameMode;
import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.block.data.type.Chest;
import org.bukkit.block.data.type.Chest.Type;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.Action;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockExplodeEvent;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.entity.EntityExplodeEvent;
import org.bukkit.event.player.PlayerInteractEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.inventory.EquipmentSlot;
import org.bukkit.inventory.ItemStack;

public class CratePlaceListener implements Listener {
   private final LootCrates plugin;
   private final Set<UUID> openingCrate = new HashSet<>();

   public CratePlaceListener(LootCrates plugin) {
      this.plugin = plugin;
   }

   @EventHandler(
      priority = EventPriority.HIGH,
      ignoreCancelled = true
   )
   public void onBlockPlace(BlockPlaceEvent event) {
      Player player = event.getPlayer();
      ItemStack item = event.getItemInHand();
      CustomCrate crate = this.plugin.getCustomCrateManager().getCrateFromItem(item);
      if (crate != null) {
         if (!player.hasPermission("lootcrates.admin.place")) {
            event.setCancelled(true);
            player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cYou don't have permission to place crates!"));
         } else {
            Block placedBlock = event.getBlock();
            if (this.wouldFormDoubleChest(placedBlock)) {
               event.setCancelled(true);
               player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cCannot place crate next to another chest!"));
            } else {
               Location loc = placedBlock.getLocation();
               Bukkit.getScheduler().runTaskLater(this.plugin, () -> {
                  if (placedBlock.getType() != crate.getCrateMaterial()) {
                     return;
                  }

                  if (placedBlock.getBlockData() instanceof Chest chestData) {
                     chestData.setType(Type.SINGLE);
                     placedBlock.setBlockData(chestData);
                  }

                  this.plugin.getHologramManager().createHologram(loc, crate.getId());
                  player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&aCrate placed! &7(" + crate.getDisplayName() + "&7)"));
               }, 1L);
            }
         }
      }
   }

   private boolean wouldFormDoubleChest(Block block) {
      BlockFace[] faces = new BlockFace[]{BlockFace.NORTH, BlockFace.SOUTH, BlockFace.EAST, BlockFace.WEST};

      for (BlockFace face : faces) {
         Block adjacent = block.getRelative(face);
         if (adjacent.getType() == Material.CHEST || adjacent.getType() == Material.TRAPPED_CHEST) {
            return true;
         }
      }

      return false;
   }

   @EventHandler(
      priority = EventPriority.HIGH,
      ignoreCancelled = true
   )
   public void onBlockBreak(BlockBreakEvent event) {
      Location loc = event.getBlock().getLocation();
      if (this.plugin.getHologramManager().isCrateLocation(loc)) {
         Player player = event.getPlayer();
         if (!player.hasPermission("lootcrates.admin.break")) {
            event.setCancelled(true);
            player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cYou don't have permission to break crates!"));
         } else if (player.getGameMode() == GameMode.CREATIVE && !player.isSneaking()) {
            event.setCancelled(true);
            String crateId = this.plugin.getHologramManager().getCrateIdAt(loc);
            if (!player.hasPermission("lootcrates.admin.edit")) {
               player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&eSneak + break to remove this crate."));
            } else if (crateId != null) {
               this.plugin.getCrateEditGUI().openEditGUI(player, crateId);
            }
         } else if (!player.isSneaking()) {
            event.setCancelled(true);
            player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&eSneak + break to remove this crate."));
         } else {
            this.plugin.getHologramManager().removeHologram(loc);
            player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&eCrate removed."));
         }
      }
   }

   @EventHandler(
      priority = EventPriority.HIGH
   )
   public void onPlayerInteract(PlayerInteractEvent event) {
      if (event.getAction() == Action.RIGHT_CLICK_BLOCK) {
         if (event.getHand() == EquipmentSlot.HAND) {
            Block block = event.getClickedBlock();
            if (block != null) {
               Location loc = block.getLocation();
               String crateId = this.plugin.getHologramManager().getCrateIdAt(loc);
               if (crateId != null) {
                  event.setCancelled(true);
                  Player player = event.getPlayer();
                  CustomCrate crate = this.plugin.getCustomCrateManager().getCrate(crateId);
                  if (crate != null) {
                     ItemStack mainHand = player.getInventory().getItemInMainHand();
                     ItemStack offHand = player.getInventory().getItemInOffHand();
                     ItemStack keyItem = null;
                     if (crate.isKeyItem(mainHand)) {
                        keyItem = mainHand;
                     } else if (crate.isKeyItem(offHand)) {
                        keyItem = offHand;
                     }

                     if (keyItem == null) {
                        String message = this.plugin.getMessage("no-key").replace("%key%", LootCrates.colorize(crate.getKeyName()));
                        player.sendMessage(this.plugin.getPrefix() + message);
                     } else if (!player.hasPermission("lootcrates.use")) {
                        player.sendMessage(this.plugin.getPrefix() + this.plugin.getMessage("no-permission"));
                     } else if (this.openingCrate.contains(player.getUniqueId())) {
                        player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cPlease wait for your current crate to finish!"));
                     } else {
                        List<RewardManager.Reward> rewards = this.plugin.getRewardManager().getRewards(crateId);
                        if (rewards.isEmpty()) {
                           player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cThis crate has no rewards configured!"));
                        } else {
                           this.openingCrate.add(player.getUniqueId());
                           keyItem.setAmount(keyItem.getAmount() - 1);
                           RewardManager.Reward reward = this.plugin.getRewardManager().rollReward(crateId);
                           if (reward == null) {
                              this.openingCrate.remove(player.getUniqueId());
                              player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&cError rolling reward!"));
                           } else {
                              this.plugin
                                 .getAnimationManager()
                                 .playAnimation(
                                    player,
                                    crate,
                                    crate.getAnimationType(),
                                    reward,
                                    wonItem -> {
                                       this.openingCrate.remove(player.getUniqueId());
                                       if (LootCrates.giveOrDrop(player, wonItem)) {
                                          player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&eInventory full! Dropped on ground."));
                                       }

                                       String rewardName = reward.getDisplayName();
                                       String wonMessage = this.plugin.getMessage("reward-won");
                                       player.sendMessage(
                                          this.plugin.getPrefix()
                                             + wonMessage.replace("%reward%", LootCrates.rewardWithAmount(wonMessage, "%reward%", rewardName, wonItem.getAmount()))
                                       );
                                       this.plugin.getHistoryManager().addEntry(player.getUniqueId(), crateId, rewardName, wonItem.getAmount());
                                       int broadcastThreshold = this.plugin.getConfig().getInt("settings.broadcast-rarity-threshold", 5);
                                       if (this.plugin.getConfig().getBoolean("settings.broadcast-legendary", true)
                                          && (
                                             reward.getWeight() <= broadcastThreshold
                                                || crateId.toLowerCase().contains("legendary")
                                                || crateId.toLowerCase().contains("mythic")
                                          )) {
                                          String broadcast = this.plugin.getMessage("legendary-broadcast");
                                          broadcast = broadcast.replace("%reward%", LootCrates.rewardWithAmount(broadcast, "%reward%", rewardName, wonItem.getAmount()))
                                             .replace("%player%", player.getName())
                                             .replace("%crate%", LootCrates.colorize(crate.getDisplayName()));

                                          for (Player online : Bukkit.getOnlinePlayers()) {
                                             online.sendMessage(this.plugin.getPrefix() + broadcast);
                                          }
                                       }
                                    }
                                 );
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }

   @EventHandler
   public void onPlayerQuit(PlayerQuitEvent event) {
      this.openingCrate.remove(event.getPlayer().getUniqueId());
   }

   // Explosions used to destroy crate blocks while leaving the hologram and the registered crate behind.
   @EventHandler(
      ignoreCancelled = true
   )
   public void onEntityExplode(EntityExplodeEvent event) {
      event.blockList().removeIf(block -> this.plugin.getHologramManager().isCrateLocation(block.getLocation()));
   }

   @EventHandler(
      ignoreCancelled = true
   )
   public void onBlockExplode(BlockExplodeEvent event) {
      event.blockList().removeIf(block -> this.plugin.getHologramManager().isCrateLocation(block.getLocation()));
   }
}
