package com.lootcrates.animation;

import com.lootcrates.LootCrates;
import com.lootcrates.managers.RewardManager;
import com.lootcrates.models.CustomCrate;
import com.lootcrates.util.ParticleUtil;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.function.Consumer;
import java.util.logging.Level;
import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.Material;
import org.bukkit.Particle;
import org.bukkit.Sound;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.inventory.InventoryClickEvent;
import org.bukkit.event.inventory.InventoryCloseEvent;
import org.bukkit.event.inventory.InventoryDragEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.InventoryHolder;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.scheduler.BukkitRunnable;
import org.bukkit.scheduler.BukkitTask;

public class CrateAnimationManager implements Listener {
   private final LootCrates plugin;
   private final Random random = new Random();
   private final Map<UUID, CrateAnimationManager.Session> sessions = new HashMap<>();

   public CrateAnimationManager(LootCrates plugin) {
      this.plugin = plugin;
   }

   public void playAnimation(Player player, CustomCrate crate, AnimationType type, RewardManager.Reward finalReward, Consumer<ItemStack> onComplete) {
      CrateAnimationManager.Session previous = this.sessions.get(player.getUniqueId());
      if (previous != null) {
         this.finish(previous);
      }

      CrateAnimationManager.Session session = new CrateAnimationManager.Session(player, finalReward.getItem(), onComplete);
      if (!this.plugin.getConfig().getBoolean("settings.animation-enabled", true)) {
         this.complete(session);
         return;
      }

      this.sessions.put(player.getUniqueId(), session);

      try {
         this.startAnimation(player, crate, type, finalReward);
      } catch (RuntimeException var9) {
         this.plugin.getLogger().log(Level.WARNING, "Crate animation " + type + " failed, giving the reward directly", var9);
         this.finish(session);
         return;
      }

      // Another plugin can stop the GUI from opening; give the reward instead of leaving the player with nothing.
      if (player.getOpenInventory().getTopInventory() != session.inventory) {
         this.complete(session);
      }
   }

   private void startAnimation(Player player, CustomCrate crate, AnimationType type, RewardManager.Reward finalReward) {
      switch (type) {
         case CLASSIC:
            this.playClassicAnimation(player, crate, finalReward);
            break;
         case SLOW_REVEAL:
            this.playSlowRevealAnimation(player, crate, finalReward);
            break;
         case FAST_SPIN:
            this.playFastSpinAnimation(player, crate, finalReward);
            break;
         case BOUNCE:
            this.playBounceAnimation(player, crate, finalReward);
            break;
         case SPIRAL:
            this.playSpiralAnimation(player, crate, finalReward);
            break;
         case PULSE:
            this.playPulseAnimation(player, crate, finalReward);
            break;
         case WAVE:
            this.playWaveAnimation(player, crate, finalReward);
            break;
         case CASCADE:
            this.playCascadeAnimation(player, crate, finalReward);
            break;
         case EXPLOSION:
            this.playExplosionAnimation(player, crate, finalReward);
            break;
         case VORTEX:
            this.playVortexAnimation(player, crate, finalReward);
            break;
         case RAINBOW:
            this.playRainbowAnimation(player, crate, finalReward);
            break;
         case METEOR:
            this.playMeteorAnimation(player, crate, finalReward);
            break;
         case LIGHTNING:
            this.playLightningAnimation(player, crate, finalReward);
            break;
         case FIREWORK:
            this.playFireworkAnimation(player, crate, finalReward);
            break;
         case GALAXY:
            this.playGalaxyAnimation(player, crate, finalReward);
            break;
         case PORTAL:
            this.playPortalAnimation(player, crate, finalReward);
            break;
         case TORNADO:
            this.playTornadoAnimation(player, crate, finalReward);
            break;
         case EARTHQUAKE:
            this.playEarthquakeAnimation(player, crate, finalReward);
            break;
         case BUBBLE:
            this.playBubbleAnimation(player, crate, finalReward);
            break;
         case CRYSTAL:
            this.playCrystalAnimation(player, crate, finalReward);
            break;
         case PHOENIX:
            this.playPhoenixAnimation(player, crate, finalReward);
            break;
         case DRAGON:
            this.playDragonAnimation(player, crate, finalReward);
            break;
         case MYSTIC:
            this.playMysticAnimation(player, crate, finalReward);
            break;
         case NEON:
            this.playNeonAnimation(player, crate, finalReward);
            break;
         case GLITCH:
            this.playGlitchAnimation(player, crate, finalReward);
            break;
         default:
            this.playClassicAnimation(player, crate, finalReward);
      }
   }

   private double getSpeedMultiplier() {
      // Zero or a negative value would turn every task period into "never" and freeze the animation.
      return Math.max(0.1, this.plugin.getConfig().getDouble("settings.animation-speed", 1.0));
   }

   private float getSoundVolume() {
      return (float)this.plugin.getConfig().getDouble("settings.sound-volume", 1.0);
   }

   private List<RewardManager.Reward> generateDisplayRewards(String crateId, RewardManager.Reward finalReward) {
      List<RewardManager.Reward> rewards = new ArrayList<>();
      List<RewardManager.Reward> available = this.plugin.getRewardManager().getRewards(crateId);
      if (!available.isEmpty()) {
         for (int i = 0; i < 50; i++) {
            if (i == 43) {
               rewards.add(finalReward);
            } else {
               rewards.add(available.get(this.random.nextInt(available.size())));
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

   private ItemStack createGlass(Material material) {
      ItemStack glass = new ItemStack(material);
      ItemMeta meta = glass.getItemMeta();
      meta.setDisplayName(" ");
      glass.setItemMeta(meta);
      return glass;
   }

   private void finishAnimation(final Player player, final Inventory gui, final CustomCrate crate, RewardManager.Reward finalReward) {
      for (int i = 10; i <= 16; i++) {
         gui.setItem(i, null);
      }

      gui.setItem(13, finalReward.getItem());
      player.playSound(player.getLocation(), crate.getWinSound(), this.getSoundVolume(), 1.0F);
      (new BukkitRunnable() {
            int flashes = 0;

            public void run() {
               if (this.flashes >= 6) {
                  this.cancel();
                  CrateAnimationManager.this.scheduleAutoClose(gui);
               } else {
                  ItemStack flash = this.flashes % 2 == 0
                     ? CrateAnimationManager.this.createGlass(Material.YELLOW_STAINED_GLASS_PANE)
                     : CrateAnimationManager.this.createGlass(crate.getGlassPane());

                  for (int i = 0; i < 27; i++) {
                     if (i < 9 || i >= 18 || i == 9 || i == 17) {
                        gui.setItem(i, flash);
                     }
                  }

                  this.flashes++;
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, 3L);
   }

   private void playClassicAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Classic"));
      this.fillBorders(gui, crate);
      this.addSelector(gui);
      player.openInventory(gui);
      final List<RewardManager.Reward> displayRewards = this.generateDisplayRewards(crate.getId(), finalReward);
      final double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
            int ticks = 0;
            final int maxTicks = (int)(60.0 / speed);
            int currentSlot = 0;

            public void run() {
               if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
                  this.cancel();
               } else if (this.ticks >= this.maxTicks) {
                  this.cancel();
                  CrateAnimationManager.this.finishAnimation(player, gui, crate, finalReward);
               } else {
                  int delay = CrateAnimationManager.this.getDelay(this.ticks, this.maxTicks);
                  if (this.ticks % delay == 0) {
                     CrateAnimationManager.this.shiftItems(gui, displayRewards, this.currentSlot++);
                     player.playSound(
                        player.getLocation(),
                        Sound.BLOCK_NOTE_BLOCK_PLING,
                        CrateAnimationManager.this.getSoundVolume() * 0.5F,
                        1.0F + (float)this.ticks / this.maxTicks * 0.5F
                     );
                  }

                  this.ticks++;
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, 1L);
   }

   private void playSlowRevealAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Slow Reveal"));
      ItemStack mystery = new ItemStack(Material.BLACK_STAINED_GLASS_PANE);
      ItemMeta meta = mystery.getItemMeta();
      meta.setDisplayName(LootCrates.colorize("&5&l???"));
      mystery.setItemMeta(meta);

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, mystery);
      }

      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
            int stage = 0;
            final int[] revealOrder = new int[]{0, 8, 18, 26, 1, 7, 19, 25, 2, 6, 20, 24, 3, 5, 21, 23, 4, 22, 9, 17, 10, 16, 11, 15, 12, 14, 13};

            public void run() {
               if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
                  this.cancel();
               } else if (this.stage >= this.revealOrder.length) {
                  this.cancel();
                  gui.setItem(13, finalReward.getItem());
                  player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                  CrateAnimationManager.this.scheduleAutoClose(gui);
               } else {
                  int slot = this.revealOrder[this.stage];
                  if (slot == 13) {
                     gui.setItem(slot, finalReward.getItem());
                  } else if (slot >= 9 && slot < 18 && slot != 9 && slot != 17) {
                     gui.setItem(slot, null);
                  } else {
                     gui.setItem(slot, CrateAnimationManager.this.createGlass(crate.getGlassPane()));
                  }

                  player.playSound(
                     player.getLocation(), Sound.BLOCK_AMETHYST_BLOCK_CHIME, CrateAnimationManager.this.getSoundVolume() * 0.3F, 0.5F + this.stage * 0.05F
                  );
                  this.stage++;
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, (long)(3.0 / speed));
   }

   private void playFastSpinAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Fast Spin"));
      this.fillBorders(gui, crate);
      this.addSelector(gui);
      player.openInventory(gui);
      final List<RewardManager.Reward> displayRewards = this.generateDisplayRewards(crate.getId(), finalReward);
      final double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int ticks = 0;
         final int maxTicks = (int)(30.0 / speed);
         int currentSlot = 0;

         public void run() {
            if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
               this.cancel();
            } else if (this.ticks >= this.maxTicks) {
               this.cancel();
               CrateAnimationManager.this.finishAnimation(player, gui, crate, finalReward);
            } else {
               CrateAnimationManager.this.shiftItems(gui, displayRewards, this.currentSlot++);
               player.playSound(player.getLocation(), Sound.UI_BUTTON_CLICK, CrateAnimationManager.this.getSoundVolume() * 0.3F, 2.0F);
               this.ticks++;
            }
         }
      }).runTaskTimer(this.plugin, 0L, 1L);
   }

   private void playBounceAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Bounce"));
      this.fillBorders(gui, crate);
      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      final int[] bounceSlots = new int[]{10, 11, 12, 13, 14, 15, 16};
      (new BukkitRunnable() {
            int bounces = 0;
            final int maxBounces = 15;
            int currentPos = 0;
            boolean goingRight = true;

            public void run() {
               if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
                  for (int slot : bounceSlots) {
                     gui.setItem(slot, null);
                  }

                  if (this.bounces >= 15) {
                     this.cancel();
                     gui.setItem(13, finalReward.getItem());
                     player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                     CrateAnimationManager.this.scheduleAutoClose(gui);
                  } else {
                     gui.setItem(bounceSlots[this.currentPos], finalReward.getItem());
                     player.playSound(
                        player.getLocation(),
                        Sound.BLOCK_NOTE_BLOCK_XYLOPHONE,
                        CrateAnimationManager.this.getSoundVolume() * 0.5F,
                        0.5F + this.currentPos * 0.2F
                     );
                     if (this.goingRight) {
                        this.currentPos++;
                        if (this.currentPos >= bounceSlots.length - 1) {
                           this.goingRight = false;
                           this.bounces++;
                        }
                     } else {
                        this.currentPos--;
                        if (this.currentPos <= 0) {
                           this.goingRight = true;
                           this.bounces++;
                        }
                     }
                  }
               } else {
                  this.cancel();
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, (long)(3.0 / speed));
   }

   private void playSpiralAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Spiral"));
      ItemStack mystery = this.createGlass(Material.GRAY_STAINED_GLASS_PANE);

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, mystery);
      }

      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      final int[] spiralOrder = new int[]{0, 1, 2, 3, 4, 5, 6, 7, 8, 17, 26, 25, 24, 23, 22, 21, 20, 19, 18, 9, 10, 11, 12, 14, 15, 16, 13};
      (new BukkitRunnable() {
            int index = 0;

            public void run() {
               if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
                  this.cancel();
               } else if (this.index >= spiralOrder.length) {
                  this.cancel();
                  gui.setItem(13, finalReward.getItem());
                  player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                  CrateAnimationManager.this.scheduleAutoClose(gui);
               } else {
                  int slot = spiralOrder[this.index];
                  gui.setItem(slot, CrateAnimationManager.this.createGlass(crate.getGlassPane()));
                  player.playSound(
                     player.getLocation(), Sound.BLOCK_NOTE_BLOCK_CHIME, CrateAnimationManager.this.getSoundVolume() * 0.3F, 1.0F + this.index * 0.03F
                  );
                  this.index++;
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, (long)(2.0 / speed));
   }

   private void playPulseAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Pulse"));
      this.fillBorders(gui, crate);
      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      final Material[] pulseColors = new Material[]{
         Material.WHITE_STAINED_GLASS_PANE, Material.LIGHT_GRAY_STAINED_GLASS_PANE, Material.GRAY_STAINED_GLASS_PANE, Material.BLACK_STAINED_GLASS_PANE
      };
      (new BukkitRunnable() {
         int pulses = 0;
         final int maxPulses = 10;
         int colorIndex = 0;

         public void run() {
            if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
               if (this.pulses >= 10) {
                  this.cancel();
                  gui.setItem(13, finalReward.getItem());
                  player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                  CrateAnimationManager.this.scheduleAutoClose(gui);
               } else {
                  ItemStack glass = CrateAnimationManager.this.createGlass(pulseColors[this.colorIndex % pulseColors.length]);

                  for (int i = 0; i < 27; i++) {
                     if (i < 9 || i >= 18 || i == 9 || i == 17) {
                        gui.setItem(i, glass);
                     }
                  }

                  gui.setItem(13, this.pulses % 2 == 0 ? finalReward.getItem() : null);
                  player.playSound(player.getLocation(), Sound.BLOCK_BEACON_AMBIENT, CrateAnimationManager.this.getSoundVolume() * 0.5F, 1.0F);
                  this.colorIndex++;
                  if (this.colorIndex >= pulseColors.length * 2) {
                     this.colorIndex = 0;
                     this.pulses++;
                  }
               }
            } else {
               this.cancel();
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(4.0 / speed));
   }

   private void playWaveAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Wave"));
      this.fillBorders(gui, crate);
      player.openInventory(gui);
      final List<RewardManager.Reward> displayRewards = this.generateDisplayRewards(crate.getId(), finalReward);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int wave = 0;
         final int maxWaves = 40;
         double offset = 0.0;

         public void run() {
            if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
               if (this.wave >= 40) {
                  this.cancel();
                  CrateAnimationManager.this.finishAnimation(player, gui, crate, finalReward);
               } else {
                  for (int i = 0; i < 7; i++) {
                     int slot = 10 + i;
                     double waveOffset = Math.sin(this.offset + i * 0.5);
                     int rewardIndex = (this.wave + i) % displayRewards.size();
                     if (waveOffset > 0.0) {
                        gui.setItem(slot, displayRewards.get(rewardIndex).getItem());
                     } else {
                        gui.setItem(slot, null);
                     }
                  }

                  player.playSound(player.getLocation(), Sound.BLOCK_WATER_AMBIENT, CrateAnimationManager.this.getSoundVolume() * 0.2F, 1.0F);
                  this.offset += 0.3;
                  this.wave++;
               }
            } else {
               this.cancel();
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(2.0 / speed));
   }

   private void playCascadeAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Cascade"));
      this.fillBorders(gui, crate);
      player.openInventory(gui);
      final List<RewardManager.Reward> displayRewards = this.generateDisplayRewards(crate.getId(), finalReward);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int tick = 0;
         final int maxTicks = 50;
         int[] positions = new int[]{0, 0, 0, 0, 0, 0, 0};

         public void run() {
            if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
               if (this.tick >= 50) {
                  this.cancel();
                  CrateAnimationManager.this.finishAnimation(player, gui, crate, finalReward);
               } else {
                  for (int i = 0; i < 7; i++) {
                     int slot = 10 + i;
                     int rewardIndex = (this.positions[i] + this.tick) % displayRewards.size();
                     gui.setItem(slot, displayRewards.get(rewardIndex).getItem());
                     if (this.tick % 3 == i % 3) {
                        this.positions[i]++;
                     }
                  }

                  player.playSound(player.getLocation(), Sound.BLOCK_SAND_FALL, CrateAnimationManager.this.getSoundVolume() * 0.3F, 1.5F);
                  this.tick++;
               }
            } else {
               this.cancel();
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(2.0 / speed));
   }

   private void playExplosionAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Explosion"));

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, this.createGlass(Material.BLACK_STAINED_GLASS_PANE));
      }

      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int stage = 0;

         public void run() {
            if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
               switch (this.stage) {
                  case 0:
                     gui.setItem(13, CrateAnimationManager.this.createGlass(Material.RED_STAINED_GLASS_PANE));
                     player.playSound(player.getLocation(), Sound.ENTITY_CREEPER_PRIMED, CrateAnimationManager.this.getSoundVolume(), 1.0F);
                     break;
                  case 1:
                     gui.setItem(13, CrateAnimationManager.this.createGlass(Material.ORANGE_STAINED_GLASS_PANE));
                     gui.setItem(12, CrateAnimationManager.this.createGlass(Material.RED_STAINED_GLASS_PANE));
                     gui.setItem(14, CrateAnimationManager.this.createGlass(Material.RED_STAINED_GLASS_PANE));
                     gui.setItem(4, CrateAnimationManager.this.createGlass(Material.RED_STAINED_GLASS_PANE));
                     gui.setItem(22, CrateAnimationManager.this.createGlass(Material.RED_STAINED_GLASS_PANE));
                     break;
                  case 2:
                     gui.setItem(13, CrateAnimationManager.this.createGlass(Material.YELLOW_STAINED_GLASS_PANE));

                     for (int i = 10; i <= 16; i++) {
                        gui.setItem(i, CrateAnimationManager.this.createGlass(Material.ORANGE_STAINED_GLASS_PANE));
                     }

                     for (int i = 3; i <= 5; i++) {
                        gui.setItem(i, CrateAnimationManager.this.createGlass(Material.ORANGE_STAINED_GLASS_PANE));
                     }

                     for (int i = 21; i <= 23; i++) {
                        gui.setItem(i, CrateAnimationManager.this.createGlass(Material.ORANGE_STAINED_GLASS_PANE));
                     }
                     break;
                  case 3:
                     player.playSound(player.getLocation(), Sound.ENTITY_GENERIC_EXPLODE, CrateAnimationManager.this.getSoundVolume(), 1.0F);

                     for (int i = 0; i < 27; i++) {
                        gui.setItem(i, CrateAnimationManager.this.createGlass(Material.YELLOW_STAINED_GLASS_PANE));
                     }

                     CrateAnimationManager.this.spawnParticle(player, Particle.EXPLOSION, player.getLocation().add(0.0, 1.0, 0.0), 1, 0.0, 0.0, 0.0, 1.0);
                     break;
                  case 4:
                     for (int i = 0; i < 27; i++) {
                        gui.setItem(i, CrateAnimationManager.this.createGlass(Material.WHITE_STAINED_GLASS_PANE));
                     }
                     break;
                  case 5:
                     CrateAnimationManager.this.fillBorders(gui, crate);

                     for (int i = 10; i <= 16; i++) {
                        gui.setItem(i, null);
                     }

                     gui.setItem(13, finalReward.getItem());
                     player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                     break;
                  default:
                     this.cancel();
                     CrateAnimationManager.this.scheduleAutoClose(gui);
                     return;
               }

               this.stage++;
            } else {
               this.cancel();
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(5.0 / speed));
   }

   private void playVortexAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Vortex"));
      this.fillBorders(gui, crate);
      player.openInventory(gui);
      final List<RewardManager.Reward> displayRewards = this.generateDisplayRewards(crate.getId(), finalReward);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int tick = 0;
         final int maxTicks = 60;
         double angle = 0.0;

         public void run() {
            if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
               this.cancel();
            } else if (this.tick >= 60) {
               this.cancel();
               CrateAnimationManager.this.finishAnimation(player, gui, crate, finalReward);
            } else {
               for (int i = 0; i < 7; i++) {
                  int slot = 10 + i;
                  double offset = this.angle + i * 0.9;
                  int rewardIndex = (int)Math.abs(Math.sin(offset) * displayRewards.size()) % displayRewards.size();
                  gui.setItem(slot, displayRewards.get(rewardIndex).getItem());
               }

               player.playSound(player.getLocation(), Sound.ENTITY_ENDERMAN_TELEPORT, CrateAnimationManager.this.getSoundVolume() * 0.1F, 1.5F);
               this.angle += 0.3;
               this.tick++;
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(1.0 / speed));
   }

   private void playRainbowAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Rainbow"));
      player.openInventory(gui);
      final Material[] rainbow = new Material[]{
         Material.RED_STAINED_GLASS_PANE,
         Material.ORANGE_STAINED_GLASS_PANE,
         Material.YELLOW_STAINED_GLASS_PANE,
         Material.LIME_STAINED_GLASS_PANE,
         Material.CYAN_STAINED_GLASS_PANE,
         Material.BLUE_STAINED_GLASS_PANE,
         Material.PURPLE_STAINED_GLASS_PANE
      };
      final List<RewardManager.Reward> displayRewards = this.generateDisplayRewards(crate.getId(), finalReward);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
            int tick = 0;
            final int maxTicks = 60;
            int colorOffset = 0;

            public void run() {
               if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
                  this.cancel();
               } else if (this.tick >= 60) {
                  this.cancel();
                  CrateAnimationManager.this.finishAnimation(player, gui, crate, finalReward);
               } else {
                  for (int i = 0; i < 9; i++) {
                     gui.setItem(i, CrateAnimationManager.this.createGlass(rainbow[(i + this.colorOffset) % rainbow.length]));
                     gui.setItem(18 + i, CrateAnimationManager.this.createGlass(rainbow[(i + this.colorOffset + 3) % rainbow.length]));
                  }

                  gui.setItem(9, CrateAnimationManager.this.createGlass(rainbow[this.colorOffset % rainbow.length]));
                  gui.setItem(17, CrateAnimationManager.this.createGlass(rainbow[(this.colorOffset + 4) % rainbow.length]));
                  int rewardIndex = this.tick % displayRewards.size();

                  for (int i = 10; i <= 16; i++) {
                     gui.setItem(i, displayRewards.get((rewardIndex + i) % displayRewards.size()).getItem());
                  }

                  player.playSound(
                     player.getLocation(), Sound.BLOCK_NOTE_BLOCK_CHIME, CrateAnimationManager.this.getSoundVolume() * 0.3F, 0.5F + this.tick % 7 * 0.2F
                  );
                  this.colorOffset++;
                  this.tick++;
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, (long)(2.0 / speed));
   }

   private void playMeteorAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Meteor"));

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, this.createGlass(Material.BLACK_STAINED_GLASS_PANE));
      }

      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int meteor = 0;
         final int maxMeteors = 7;
         int[] meteorSlots = new int[]{2, 5, 8, 11, 14, 17, 13};

         public void run() {
            if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
               this.cancel();
            } else if (this.meteor >= 7) {
               this.cancel();
               gui.setItem(13, finalReward.getItem());
               player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
               CrateAnimationManager.this.scheduleAutoClose(gui);
            } else {
               int slot = this.meteorSlots[this.meteor];
               gui.setItem(slot, CrateAnimationManager.this.createGlass(Material.ORANGE_STAINED_GLASS_PANE));
               if (this.meteor > 0) {
                  gui.setItem(this.meteorSlots[this.meteor - 1], CrateAnimationManager.this.createGlass(Material.YELLOW_STAINED_GLASS_PANE));
               }

               if (this.meteor > 1) {
                  gui.setItem(this.meteorSlots[this.meteor - 2], CrateAnimationManager.this.createGlass(Material.RED_STAINED_GLASS_PANE));
               }

               if (this.meteor > 2) {
                  gui.setItem(this.meteorSlots[this.meteor - 3], CrateAnimationManager.this.createGlass(Material.GRAY_STAINED_GLASS_PANE));
               }

               player.playSound(player.getLocation(), Sound.ENTITY_FIREWORK_ROCKET_LAUNCH, CrateAnimationManager.this.getSoundVolume() * 0.5F, 1.5F);
               this.meteor++;
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(5.0 / speed));
   }

   private void playLightningAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Lightning"));
      this.fillBorders(gui, crate);
      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int strikes = 0;
         final int maxStrikes = 8;

         public void run() {
            if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
               if (this.strikes >= 8) {
                  this.cancel();

                  for (int i = 10; i <= 16; i++) {
                     gui.setItem(i, null);
                  }

                  gui.setItem(13, finalReward.getItem());
                  player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                  CrateAnimationManager.this.scheduleAutoClose(gui);
               } else {
                  boolean isFlash = this.strikes % 2 == 0;

                  for (int i = 0; i < 27; i++) {
                     if (i < 9 || i >= 18 || i == 9 || i == 17) {
                        gui.setItem(i, CrateAnimationManager.this.createGlass(isFlash ? Material.YELLOW_STAINED_GLASS_PANE : Material.CYAN_STAINED_GLASS_PANE));
                     }
                  }

                  if (isFlash) {
                     int randomSlot = 10 + CrateAnimationManager.this.random.nextInt(7);
                     gui.setItem(randomSlot, CrateAnimationManager.this.createGlass(Material.WHITE_STAINED_GLASS_PANE));
                     player.playSound(player.getLocation(), Sound.ENTITY_LIGHTNING_BOLT_THUNDER, CrateAnimationManager.this.getSoundVolume() * 0.5F, 1.0F);
                  }

                  this.strikes++;
               }
            } else {
               this.cancel();
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(4.0 / speed));
   }

   private void playFireworkAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Firework"));

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, this.createGlass(Material.BLACK_STAINED_GLASS_PANE));
      }

      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      final Material[] fireworkColors = new Material[]{
         Material.RED_STAINED_GLASS_PANE,
         Material.ORANGE_STAINED_GLASS_PANE,
         Material.YELLOW_STAINED_GLASS_PANE,
         Material.LIME_STAINED_GLASS_PANE,
         Material.MAGENTA_STAINED_GLASS_PANE,
         Material.CYAN_STAINED_GLASS_PANE
      };
      (new BukkitRunnable() {
            int stage = 0;
            final int maxStages = 10;

            public void run() {
               if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
                  if (this.stage < 10) {
                     for (int i = 0; i < 27; i++) {
                        if (CrateAnimationManager.this.random.nextFloat() < 0.3F) {
                           gui.setItem(
                              i, CrateAnimationManager.this.createGlass(fireworkColors[CrateAnimationManager.this.random.nextInt(fireworkColors.length)])
                           );
                        } else {
                           gui.setItem(i, CrateAnimationManager.this.createGlass(Material.BLACK_STAINED_GLASS_PANE));
                        }
                     }

                     player.playSound(player.getLocation(), Sound.ENTITY_FIREWORK_ROCKET_BLAST, CrateAnimationManager.this.getSoundVolume() * 0.5F, 1.0F);
                     CrateAnimationManager.this.spawnParticle(player, Particle.FIREWORK, player.getLocation().add(0.0, 1.0, 0.0), 5, 0.5, 0.5, 0.5, 0.1);
                     this.stage++;
                  } else {
                     this.cancel();

                     for (int ix = 0; ix < 27; ix++) {
                        gui.setItem(ix, null);
                     }

                     CrateAnimationManager.this.fillBorders(gui, crate);
                     gui.setItem(13, finalReward.getItem());
                     player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                     CrateAnimationManager.this.scheduleAutoClose(gui);
                  }
               } else {
                  this.cancel();
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, (long)(5.0 / speed));
   }

   private void playGalaxyAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Galaxy"));
      player.openInventory(gui);
      final Material[] stars = new Material[]{
         Material.WHITE_STAINED_GLASS_PANE,
         Material.LIGHT_BLUE_STAINED_GLASS_PANE,
         Material.PURPLE_STAINED_GLASS_PANE,
         Material.MAGENTA_STAINED_GLASS_PANE,
         Material.BLACK_STAINED_GLASS_PANE
      };
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int tick = 0;
         final int maxTicks = 50;
         double rotation = 0.0;

         public void run() {
            if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
               if (this.tick < 50) {
                  for (int i = 0; i < 27; i++) {
                     int row = i / 9;
                     int col = i % 9;
                     double dist = Math.sqrt(Math.pow(row - 1, 2.0) + Math.pow(col - 4, 2.0));
                     double angle = Math.atan2(row - 1, col - 4) + this.rotation;
                     int colorIndex = (int)((dist + angle) * 2.0) % stars.length;
                     if (colorIndex < 0) {
                        colorIndex += stars.length;
                     }

                     gui.setItem(i, CrateAnimationManager.this.createGlass(stars[colorIndex]));
                  }

                  player.playSound(player.getLocation(), Sound.BLOCK_AMETHYST_BLOCK_CHIME, CrateAnimationManager.this.getSoundVolume() * 0.2F, 0.5F);
                  this.rotation += 0.2;
                  this.tick++;
               } else {
                  this.cancel();
                  CrateAnimationManager.this.fillBorders(gui, crate);

                  for (int i = 10; i <= 16; i++) {
                     gui.setItem(i, null);
                  }

                  gui.setItem(13, finalReward.getItem());
                  player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                  CrateAnimationManager.this.scheduleAutoClose(gui);
               }
            } else {
               this.cancel();
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(2.0 / speed));
   }

   private void playPortalAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Portal"));

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, this.createGlass(Material.BLACK_STAINED_GLASS_PANE));
      }

      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int ring = 0;
         final int[][] rings = new int[][]{{13}, {12, 14, 4, 22}, {11, 15, 3, 5, 21, 23}, {10, 16, 2, 6, 20, 24, 9, 17}, {1, 7, 19, 25, 0, 8, 18, 26}};

         public void run() {
            if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
               this.cancel();
            } else if (this.ring >= this.rings.length) {
               this.cancel();
               gui.setItem(13, finalReward.getItem());
               player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
               CrateAnimationManager.this.scheduleAutoClose(gui);
            } else {
               for (int slot : this.rings[this.ring]) {
                  gui.setItem(slot, CrateAnimationManager.this.createGlass(Material.PURPLE_STAINED_GLASS_PANE));
               }

               player.playSound(player.getLocation(), Sound.BLOCK_PORTAL_AMBIENT, CrateAnimationManager.this.getSoundVolume() * 0.3F, 1.0F + this.ring * 0.2F);
               CrateAnimationManager.this.spawnParticle(player, Particle.PORTAL, player.getLocation().add(0.0, 1.0, 0.0), 20, 0.5, 0.5, 0.5, 0.5);
               this.ring++;
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(8.0 / speed));
   }

   private void playTornadoAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Tornado"));
      this.fillBorders(gui, crate);
      player.openInventory(gui);
      final List<RewardManager.Reward> displayRewards = this.generateDisplayRewards(crate.getId(), finalReward);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int tick = 0;
         final int maxTicks = 60;
         double spin = 0.0;

         public void run() {
            if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
               if (this.tick >= 60) {
                  this.cancel();
                  CrateAnimationManager.this.finishAnimation(player, gui, crate, finalReward);
               } else {
                  int center = 3 + (int)(Math.sin(this.spin) * 3.0);

                  for (int i = 0; i < 7; i++) {
                     int slot = 10 + i;
                     int dist = Math.abs(i - center);
                     if (dist < 2) {
                        int rewardIndex = (this.tick + i) % displayRewards.size();
                        gui.setItem(slot, displayRewards.get(rewardIndex).getItem());
                     } else {
                        gui.setItem(slot, CrateAnimationManager.this.createGlass(Material.GRAY_STAINED_GLASS_PANE));
                     }
                  }

                  player.playSound(player.getLocation(), Sound.ENTITY_PHANTOM_FLAP, CrateAnimationManager.this.getSoundVolume() * 0.3F, 1.5F);
                  this.spin += 0.4;
                  this.tick++;
               }
            } else {
               this.cancel();
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(1.0 / speed));
   }

   private void playEarthquakeAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Earthquake"));
      this.fillBorders(gui, crate);
      player.openInventory(gui);
      final List<RewardManager.Reward> displayRewards = this.generateDisplayRewards(crate.getId(), finalReward);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
            int tick = 0;
            final int maxTicks = 50;

            public void run() {
               if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
                  this.cancel();
               } else if (this.tick >= 50) {
                  this.cancel();
                  CrateAnimationManager.this.finishAnimation(player, gui, crate, finalReward);
               } else {
                  for (int i = 0; i < 7; i++) {
                     int slot = 10 + i;
                     if (CrateAnimationManager.this.random.nextBoolean()) {
                        int rewardIndex = CrateAnimationManager.this.random.nextInt(displayRewards.size());
                        gui.setItem(slot, displayRewards.get(rewardIndex).getItem());
                     } else {
                        gui.setItem(slot, null);
                     }
                  }

                  if (this.tick % 3 == 0) {
                     Material shakeMat = CrateAnimationManager.this.random.nextBoolean()
                        ? Material.BROWN_STAINED_GLASS_PANE
                        : crate.getGlassPane();

                     for (int ix = 0; ix < 9; ix++) {
                        gui.setItem(ix, CrateAnimationManager.this.createGlass(shakeMat));
                        gui.setItem(18 + ix, CrateAnimationManager.this.createGlass(shakeMat));
                     }
                  }

                  player.playSound(player.getLocation(), Sound.ENTITY_ZOMBIE_ATTACK_WOODEN_DOOR, CrateAnimationManager.this.getSoundVolume() * 0.3F, 0.5F);
                  this.tick++;
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, (long)(1.0 / speed));
   }

   private void playBubbleAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Bubble"));

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, this.createGlass(Material.LIGHT_BLUE_STAINED_GLASS_PANE));
      }

      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int tick = 0;
         final int maxTicks = 30;
         List<Integer> bubbles = new ArrayList<>();

         public void run() {
            if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
               this.cancel();
            } else if (this.tick >= 30) {
               this.cancel();
               CrateAnimationManager.this.fillBorders(gui, crate);

               for (int i = 10; i <= 16; i++) {
                  gui.setItem(i, null);
               }

               gui.setItem(13, finalReward.getItem());
               player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
               CrateAnimationManager.this.scheduleAutoClose(gui);
            } else {
               if (this.tick % 2 == 0 && this.bubbles.size() < 27) {
                  int newBubble;
                  do {
                     newBubble = CrateAnimationManager.this.random.nextInt(27);
                  } while (this.bubbles.contains(newBubble));

                  this.bubbles.add(newBubble);
                  gui.setItem(newBubble, CrateAnimationManager.this.createGlass(Material.WHITE_STAINED_GLASS_PANE));
                  player.playSound(player.getLocation(), Sound.BLOCK_BUBBLE_COLUMN_BUBBLE_POP, CrateAnimationManager.this.getSoundVolume() * 0.3F, 1.5F);
               }

               this.tick++;
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(3.0 / speed));
   }

   private void playCrystalAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Crystal"));

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, this.createGlass(Material.BLACK_STAINED_GLASS_PANE));
      }

      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      final Material[] crystals = new Material[]{
         Material.LIGHT_BLUE_STAINED_GLASS_PANE, Material.CYAN_STAINED_GLASS_PANE, Material.BLUE_STAINED_GLASS_PANE, Material.PURPLE_STAINED_GLASS_PANE
      };
      (new BukkitRunnable() {
            int stage = 0;
            final int maxStages = 12;

            public void run() {
               if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
                  if (this.stage < 12) {
                     for (int i = 0; i < 27; i++) {
                        int row = i / 9;
                        int col = i % 9;
                        double dist = Math.sqrt(Math.pow(row - 1, 2.0) + Math.pow(col - 4, 2.0));
                        if (dist <= this.stage * 0.5) {
                           int crystalIndex = (int)dist % crystals.length;
                           gui.setItem(i, CrateAnimationManager.this.createGlass(crystals[crystalIndex]));
                        }
                     }

                     player.playSound(
                        player.getLocation(), Sound.BLOCK_AMETHYST_CLUSTER_BREAK, CrateAnimationManager.this.getSoundVolume() * 0.5F, 0.8F + this.stage * 0.1F
                     );
                     this.stage++;
                  } else {
                     this.cancel();
                     CrateAnimationManager.this.fillBorders(gui, crate);

                     for (int ix = 10; ix <= 16; ix++) {
                        gui.setItem(ix, null);
                     }

                     gui.setItem(13, finalReward.getItem());
                     player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                     CrateAnimationManager.this.scheduleAutoClose(gui);
                  }
               } else {
                  this.cancel();
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, (long)(4.0 / speed));
   }

   private void playPhoenixAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Phoenix"));

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, this.createGlass(Material.BLACK_STAINED_GLASS_PANE));
      }

      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
         int flame = 0;
         final int maxFlames = 15;

         public void run() {
            if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
               if (this.flame >= 15) {
                  this.cancel();

                  for (int i = 0; i < 27; i++) {
                     gui.setItem(i, CrateAnimationManager.this.createGlass(Material.YELLOW_STAINED_GLASS_PANE));
                  }

                  gui.setItem(13, finalReward.getItem());
                  player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                  CrateAnimationManager.this.spawnParticle(player, Particle.FLAME, player.getLocation().add(0.0, 1.0, 0.0), 30, 0.5, 0.5, 0.5, 0.1);
                  CrateAnimationManager.this.scheduleAutoClose(gui);
               } else {
                  Material[] flames = new Material[]{Material.RED_STAINED_GLASS_PANE, Material.ORANGE_STAINED_GLASS_PANE, Material.YELLOW_STAINED_GLASS_PANE};

                  for (int col = 0; col < 9; col++) {
                     int height = (this.flame + col) % 4;

                     for (int row = 2; row >= 0; row--) {
                        int slot = row * 9 + col;
                        int rowFromBottom = 2 - row;
                        if (rowFromBottom <= height) {
                           gui.setItem(slot, CrateAnimationManager.this.createGlass(flames[Math.min(rowFromBottom, flames.length - 1)]));
                        }
                     }
                  }

                  player.playSound(player.getLocation(), Sound.BLOCK_FIRE_AMBIENT, CrateAnimationManager.this.getSoundVolume() * 0.5F, 1.0F);
                  CrateAnimationManager.this.spawnParticle(player, Particle.FLAME, player.getLocation().add(0.0, 0.5, 0.0), 5, 0.3, 0.1, 0.3, 0.02);
                  this.flame++;
               }
            } else {
               this.cancel();
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(3.0 / speed));
   }

   private void playDragonAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Dragon"));

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, this.createGlass(Material.PURPLE_STAINED_GLASS_PANE));
      }

      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      (new BukkitRunnable() {
            int breath = 0;
            final int maxBreaths = 12;

            public void run() {
               if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
                  this.cancel();
               } else if (this.breath >= 12) {
                  this.cancel();
                  CrateAnimationManager.this.fillBorders(gui, crate);

                  for (int i = 10; i <= 16; i++) {
                     gui.setItem(i, null);
                  }

                  gui.setItem(13, finalReward.getItem());
                  player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                  CrateAnimationManager.this.scheduleAutoClose(gui);
               } else {
                  Material breathColor = this.breath % 3 == 0
                     ? Material.PURPLE_STAINED_GLASS_PANE
                     : (this.breath % 3 == 1 ? Material.MAGENTA_STAINED_GLASS_PANE : Material.PINK_STAINED_GLASS_PANE);
                  int col = this.breath % 9;

                  for (int row = 0; row < 3; row++) {
                     gui.setItem(row * 9 + col, CrateAnimationManager.this.createGlass(breathColor));
                  }

                  player.playSound(player.getLocation(), Sound.ENTITY_ENDER_DRAGON_GROWL, CrateAnimationManager.this.getSoundVolume() * 0.2F, 1.5F);
                  CrateAnimationManager.this.spawnParticle(player, Particle.DRAGON_BREATH, player.getLocation().add(0.0, 1.0, 0.0), 10, 0.5, 0.3, 0.5, 0.02);
                  this.breath++;
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, (long)(4.0 / speed));
   }

   private void playMysticAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Mystic"));
      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      final Material[] mysticColors = new Material[]{
         Material.PURPLE_STAINED_GLASS_PANE, Material.BLUE_STAINED_GLASS_PANE, Material.CYAN_STAINED_GLASS_PANE, Material.MAGENTA_STAINED_GLASS_PANE
      };
      (new BukkitRunnable() {
         int tick = 0;
         final int maxTicks = 50;
         double phase = 0.0;

         public void run() {
            if (!player.isOnline() || player.getOpenInventory().getTopInventory() != gui) {
               this.cancel();
            } else if (this.tick >= 50) {
               this.cancel();
               CrateAnimationManager.this.fillBorders(gui, crate);

               for (int i = 10; i <= 16; i++) {
                  gui.setItem(i, null);
               }

               gui.setItem(13, finalReward.getItem());
               player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
               CrateAnimationManager.this.scheduleAutoClose(gui);
            } else {
               for (int i = 0; i < 27; i++) {
                  double wave = Math.sin(this.phase + i * 0.3);
                  int colorIndex = (int)((wave + 1.0) * 2.0) % mysticColors.length;
                  gui.setItem(i, CrateAnimationManager.this.createGlass(mysticColors[colorIndex]));
               }

               player.playSound(player.getLocation(), Sound.BLOCK_ENCHANTMENT_TABLE_USE, CrateAnimationManager.this.getSoundVolume() * 0.2F, 1.0F);
               this.phase += 0.2;
               this.tick++;
            }
         }
      }).runTaskTimer(this.plugin, 0L, (long)(2.0 / speed));
   }

   private void playNeonAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Neon"));

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, this.createGlass(Material.BLACK_STAINED_GLASS_PANE));
      }

      player.openInventory(gui);
      double speed = this.getSpeedMultiplier();
      final Material[] neonColors = new Material[]{
         Material.MAGENTA_STAINED_GLASS_PANE, Material.LIME_STAINED_GLASS_PANE, Material.CYAN_STAINED_GLASS_PANE, Material.YELLOW_STAINED_GLASS_PANE
      };
      (new BukkitRunnable() {
            int tick = 0;
            final int maxTicks = 45;
            int trailPos = 0;

            public void run() {
               if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
                  if (this.tick < 45) {
                     int[] border = new int[]{0, 1, 2, 3, 4, 5, 6, 7, 8, 17, 26, 25, 24, 23, 22, 21, 20, 19, 18, 9};

                     for (int i = 0; i < border.length; i++) {
                        int dist = (this.trailPos - i + border.length) % border.length;
                        if (dist < 5) {
                           gui.setItem(border[i], CrateAnimationManager.this.createGlass(neonColors[dist % neonColors.length]));
                        } else {
                           gui.setItem(border[i], CrateAnimationManager.this.createGlass(Material.BLACK_STAINED_GLASS_PANE));
                        }
                     }

                     player.playSound(
                        player.getLocation(), Sound.BLOCK_NOTE_BLOCK_BIT, CrateAnimationManager.this.getSoundVolume() * 0.3F, 1.0F + this.tick % 8 * 0.1F
                     );
                     this.trailPos = (this.trailPos + 1) % border.length;
                     this.tick++;
                  } else {
                     this.cancel();
                     CrateAnimationManager.this.fillBorders(gui, crate);

                     for (int ix = 10; ix <= 16; ix++) {
                        gui.setItem(ix, null);
                     }

                     gui.setItem(13, finalReward.getItem());
                     player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                     CrateAnimationManager.this.scheduleAutoClose(gui);
                  }
               } else {
                  this.cancel();
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, (long)(2.0 / speed));
   }

   private void playGlitchAnimation(final Player player, final CustomCrate crate, final RewardManager.Reward finalReward) {
      final Inventory gui = this.createGui(player, LootCrates.colorize(crate.getDisplayName() + " &8- Glitch"));
      player.openInventory(gui);
      final List<RewardManager.Reward> displayRewards = this.generateDisplayRewards(crate.getId(), finalReward);
      double speed = this.getSpeedMultiplier();
      final Material[] glitchColors = new Material[]{
         Material.LIME_STAINED_GLASS_PANE, Material.BLACK_STAINED_GLASS_PANE, Material.WHITE_STAINED_GLASS_PANE, Material.GREEN_STAINED_GLASS_PANE
      };
      (new BukkitRunnable() {
            int tick = 0;
            final int maxTicks = 40;

            public void run() {
               if (player.isOnline() && player.getOpenInventory().getTopInventory() == gui) {
                  if (this.tick >= 40) {
                     this.cancel();
                     CrateAnimationManager.this.fillBorders(gui, crate);

                     for (int i = 10; i <= 16; i++) {
                        gui.setItem(i, null);
                     }

                     gui.setItem(13, finalReward.getItem());
                     player.playSound(player.getLocation(), crate.getWinSound(), CrateAnimationManager.this.getSoundVolume(), 1.0F);
                     CrateAnimationManager.this.scheduleAutoClose(gui);
                  } else {
                     for (int i = 0; i < 27; i++) {
                        if (CrateAnimationManager.this.random.nextFloat() < 0.3F) {
                           gui.setItem(i, CrateAnimationManager.this.createGlass(glitchColors[CrateAnimationManager.this.random.nextInt(glitchColors.length)]));
                        } else if (CrateAnimationManager.this.random.nextFloat() < 0.2F && !displayRewards.isEmpty()) {
                           gui.setItem(i, displayRewards.get(CrateAnimationManager.this.random.nextInt(displayRewards.size())).getItem());
                        } else {
                           gui.setItem(i, null);
                        }
                     }

                     if (this.tick % 10 == 0) {
                        CrateAnimationManager.this.fillBorders(gui, crate);
                        gui.setItem(13, finalReward.getItem());
                     }

                     player.playSound(
                        player.getLocation(),
                        Sound.BLOCK_NOTE_BLOCK_BIT,
                        CrateAnimationManager.this.getSoundVolume() * 0.2F,
                        CrateAnimationManager.this.random.nextFloat() * 2.0F
                     );
                     this.tick++;
                  }
               } else {
                  this.cancel();
               }
            }
         })
         .runTaskTimer(this.plugin, 0L, (long)(2.0 / speed));
   }

   private Inventory createGui(Player player, String title) {
      CrateAnimationManager.Session session = this.sessions.get(player.getUniqueId());
      Inventory gui = Bukkit.createInventory(session, 27, title);
      if (session != null) {
         session.inventory = gui;
      }

      return gui;
   }

   private CrateAnimationManager.Session getSession(Inventory inventory) {
      for (CrateAnimationManager.Session session : this.sessions.values()) {
         if (session.inventory == inventory) {
            return session;
         }
      }

      return null;
   }

   private void scheduleAutoClose(Inventory gui) {
      CrateAnimationManager.Session session = this.getSession(gui);
      if (session != null && session.closeTask == null) {
         int closeDelay = this.plugin.getConfig().getInt("settings.auto-close-delay", 20);
         // -1 leaves the GUI open; the reward is handed out when the player closes it.
         if (closeDelay >= 0) {
            session.closeTask = Bukkit.getScheduler().runTaskLater(this.plugin, () -> this.finish(session), closeDelay);
         }
      }
   }

   /** Closes the animation GUI if it is still open and hands out the reward. */
   private void finish(CrateAnimationManager.Session session) {
      if (session.player.isOnline() && session.player.getOpenInventory().getTopInventory() == session.inventory) {
         session.player.closeInventory();
      }

      this.complete(session);
   }

   /** Hands out the reward exactly once, however the animation ended. */
   private void complete(CrateAnimationManager.Session session) {
      if (session != null && !session.completed) {
         session.completed = true;
         if (session.closeTask != null) {
            session.closeTask.cancel();
         }

         this.sessions.remove(session.player.getUniqueId(), session);
         session.onComplete.accept(session.reward.clone());
      }
   }

   public void completeAll() {
      for (CrateAnimationManager.Session session : new ArrayList<>(this.sessions.values())) {
         this.finish(session);
      }
   }

   @EventHandler
   public void onInventoryClose(InventoryCloseEvent event) {
      // Closing the GUI early (e.g. pressing Esc) skips the rest of the animation and gives the reward right away.
      this.complete(this.getSession(event.getInventory()));
   }

   @EventHandler
   public void onPlayerQuit(PlayerQuitEvent event) {
      this.complete(this.sessions.get(event.getPlayer().getUniqueId()));
   }

   @EventHandler(
      priority = EventPriority.LOWEST
   )
   public void onInventoryClick(InventoryClickEvent event) {
      if (this.getSession(event.getView().getTopInventory()) != null) {
         event.setCancelled(true);
      }
   }

   @EventHandler(
      priority = EventPriority.LOWEST
   )
   public void onInventoryDrag(InventoryDragEvent event) {
      if (this.getSession(event.getView().getTopInventory()) != null) {
         event.setCancelled(true);
      }
   }

   private void spawnParticle(Player player, Particle particle, Location location, int count, double offsetX, double offsetY, double offsetZ, double extra) {
      if (this.plugin.getConfig().getBoolean("settings.particles-enabled", true)) {
         ParticleUtil.spawn(player, particle, location, count, offsetX, offsetY, offsetZ, extra);
      }
   }

   private void fillBorders(Inventory gui, CustomCrate crate) {
      ItemStack borderGlass = this.createGlass(crate.getGlassPane());

      for (int i = 0; i < 27; i++) {
         if (i < 9 || i >= 18 || i == 9 || i == 17) {
            gui.setItem(i, borderGlass);
         }
      }
   }

   private void addSelector(Inventory gui) {
      ItemStack selector = new ItemStack(Material.ARROW);
      ItemMeta selectorMeta = selector.getItemMeta();
      selectorMeta.setDisplayName(LootCrates.colorize("&e▼ &lYOUR REWARD &e▼"));
      selector.setItemMeta(selectorMeta);
      gui.setItem(4, selector);
   }

   private void shiftItems(Inventory gui, List<RewardManager.Reward> rewards, int offset) {
      for (int i = 0; i < 7; i++) {
         int rewardIndex = (offset + i) % rewards.size();
         gui.setItem(10 + i, rewards.get(rewardIndex).getItem());
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

   private static final class Session implements InventoryHolder {
      private final Player player;
      private final ItemStack reward;
      private final Consumer<ItemStack> onComplete;
      private Inventory inventory;
      private BukkitTask closeTask;
      private boolean completed;

      private Session(Player player, ItemStack reward, Consumer<ItemStack> onComplete) {
         this.player = player;
         this.reward = reward;
         this.onComplete = onComplete;
      }

      public Inventory getInventory() {
         return this.inventory;
      }
   }
}
