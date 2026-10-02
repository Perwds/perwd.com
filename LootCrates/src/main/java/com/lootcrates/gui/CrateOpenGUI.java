package com.lootcrates.gui;

import com.lootcrates.LootCrates;
import com.lootcrates.managers.RewardManager;
import com.lootcrates.models.CustomCrate;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.function.Consumer;
import org.bukkit.Bukkit;
import org.bukkit.Material;
import org.bukkit.Sound;
import org.bukkit.entity.Player;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.scheduler.BukkitRunnable;

public class CrateOpenGUI {
   private final LootCrates plugin;
   private static final Random random = new Random();

   public CrateOpenGUI(LootCrates plugin) {
      this.plugin = plugin;
   }

   public void openCrateAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward, final Consumer<ItemStack> onComplete) {
      final Inventory gui = Bukkit.createInventory(null, 27, LootCrates.colorize(crate.getDisplayName() + " &8- Opening..."));
      ItemStack borderGlass = this.createGlass(crate);

      for (int i = 0; i < 27; i++) {
         if (i < 9 || i >= 18 || i == 9 || i == 17) {
            gui.setItem(i, borderGlass);
         }
      }

      ItemStack selector = new ItemStack(Material.ARROW);
      ItemMeta selectorMeta = selector.getItemMeta();
      selectorMeta.setDisplayName(LootCrates.colorize("&e▼ &lYOUR REWARD &e▼"));
      selector.setItemMeta(selectorMeta);
      gui.setItem(4, selector);
      player.openInventory(gui);
      (new BukkitRunnable() {
            int ticks = 0;
            final int maxTicks = 60;
            int currentSlot = 0;
            List<RewardManager.Reward> displayRewards = CrateOpenGUI.this.generateDisplayRewards(crate.getId(), finalReward);

            public void run() {
               if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
                  this.cancel();
               } else if (this.ticks < 60) {
                  int delay = CrateOpenGUI.this.getDelay(this.ticks, 60);
                  if (this.ticks % delay == 0) {
                     CrateOpenGUI.this.shiftItems(gui, this.displayRewards, this.currentSlot);
                     this.currentSlot++;
                     float pitch = 1.0F + this.ticks / 60.0F * 0.5F;
                     player.playSound(player.getLocation(), Sound.BLOCK_NOTE_BLOCK_PLING, 0.5F, pitch);
                  }

                  this.ticks++;
               } else {
                  this.cancel();

                  for (int ix = 10; ix <= 16; ix++) {
                     gui.setItem(ix, null);
                  }

                  final ItemStack rewardItem = finalReward.getItem();
                  gui.setItem(13, rewardItem);
                  player.playSound(player.getLocation(), crate.getWinSound(), 1.0F, 1.0F);
                  (new BukkitRunnable() {
                        int flashes = 0;

                        public void run() {
                           if (this.flashes >= 6) {
                              this.cancel();
                              Bukkit.getScheduler().runTaskLater(CrateOpenGUI.this.plugin, () -> {
                                 player.closeInventory();
                                 onComplete.accept(rewardItem);
                              }, 20L);
                           } else {
                              ItemStack flash = this.flashes % 2 == 0
                                 ? CrateOpenGUI.this.createGlass(Material.YELLOW_STAINED_GLASS_PANE)
                                 : CrateOpenGUI.this.createGlass(crate);

                              for (int i = 0; i < 27; i++) {
                                 if (i < 9 || i >= 18 || i == 9 || i == 17) {
                                    gui.setItem(i, flash);
                                 }
                              }

                              this.flashes++;
                           }
                        }
                     })
                     .runTaskTimer(CrateOpenGUI.this.plugin, 0L, 3L);
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, 1L);
   }

   private List<RewardManager.Reward> generateDisplayRewards(String crateId, RewardManager.Reward finalReward) {
      List<RewardManager.Reward> rewards = new ArrayList<>();
      List<RewardManager.Reward> available = this.plugin.getRewardManager().getRewards(crateId);
      if (!available.isEmpty()) {
         for (int i = 0; i < 50; i++) {
            if (i == 43) {
               rewards.add(finalReward);
            } else {
               rewards.add(available.get(random.nextInt(available.size())));
            }
         }

         return rewards;
      } else {
         for (int ix = 0; ix < 50; ix++) {
            rewards.add(finalReward);
         }

         return rewards;
      }
   }

   private void shiftItems(Inventory gui, List<RewardManager.Reward> rewards, int offset) {
      for (int i = 0; i < 7; i++) {
         int rewardIndex = (offset + i) % rewards.size();
         RewardManager.Reward reward = rewards.get(rewardIndex);
         gui.setItem(10 + i, reward.getItem());
      }
   }

   private int getDelay(int tick, int maxTicks) {
      double progress = (double)tick / maxTicks;
      if (progress < 0.5) {
         return 1;
      } else if (progress < 0.7) {
         return 2;
      } else if (progress < 0.85) {
         return 3;
      } else {
         return progress < 0.95 ? 5 : 8;
      }
   }

   private ItemStack createGlass(CustomCrate crate) {
      Material glass = Material.WHITE_STAINED_GLASS_PANE;
      String colorName = crate.getParticleColor().toString();
      if (colorName.contains("BLUE")) {
         glass = Material.BLUE_STAINED_GLASS_PANE;
      } else if (colorName.contains("RED")) {
         glass = Material.RED_STAINED_GLASS_PANE;
      } else if (colorName.contains("GREEN") || colorName.contains("LIME")) {
         glass = Material.LIME_STAINED_GLASS_PANE;
      } else if (colorName.contains("PURPLE") || colorName.contains("FUCHSIA")) {
         glass = Material.PURPLE_STAINED_GLASS_PANE;
      } else if (colorName.contains("ORANGE")) {
         glass = Material.ORANGE_STAINED_GLASS_PANE;
      } else if (colorName.contains("YELLOW")) {
         glass = Material.YELLOW_STAINED_GLASS_PANE;
      } else if (colorName.contains("AQUA") || colorName.contains("CYAN")) {
         glass = Material.CYAN_STAINED_GLASS_PANE;
      } else if (colorName.contains("PINK")) {
         glass = Material.PINK_STAINED_GLASS_PANE;
      }

      return this.createGlass(glass);
   }

   private ItemStack createGlass(Material material) {
      ItemStack glass = new ItemStack(material);
      ItemMeta meta = glass.getItemMeta();
      meta.setDisplayName(" ");
      glass.setItemMeta(meta);
      return glass;
   }
}
