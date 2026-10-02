package com.lootcrates.gui;

import com.lootcrates.LootCrates;
import com.lootcrates.animation.AnimationType;
import com.lootcrates.managers.RewardManager;
import com.lootcrates.models.CustomCrate;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.bukkit.Bukkit;
import org.bukkit.Material;
import org.bukkit.entity.Player;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;

public class CrateEditGUI {
   private final LootCrates plugin;
   private final Map<UUID, String> editingSessions = new HashMap<>();
   private final Map<UUID, Map<Integer, Integer>> slotToIndexMap = new HashMap<>();
   private final Map<UUID, String> pendingCrateCreation = new HashMap<>();
   private final Map<UUID, String> renamingSessions = new HashMap<>();
   private final Map<UUID, String> keyRenamingSessions = new HashMap<>();

   public CrateEditGUI(LootCrates plugin) {
      this.plugin = plugin;
   }

   public void startCrateCreation(Player player, String color) {
      this.pendingCrateCreation.put(player.getUniqueId(), color);
      player.closeInventory();
      player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&e&lEnter a name for your new crate:"));
      player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&7Type the name in chat (supports &colors&7!)"));
      player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&7Type &c'cancel'&7 to cancel."));
   }

   public boolean hasPendingCreation(UUID uuid) {
      return this.pendingCrateCreation.containsKey(uuid);
   }

   public String getPendingColor(UUID uuid) {
      return this.pendingCrateCreation.get(uuid);
   }

   public void removePendingCreation(UUID uuid) {
      this.pendingCrateCreation.remove(uuid);
   }

   public void startRename(Player player, String crateId) {
      this.renamingSessions.put(player.getUniqueId(), crateId);
      player.closeInventory();
      player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&e&lEnter a new name for this crate:"));
      player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&7Type the name in chat (supports &colors&7!)"));
      player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&7Type &c'cancel'&7 to cancel."));
   }

   public boolean hasRenamingSession(UUID uuid) {
      return this.renamingSessions.containsKey(uuid);
   }

   public String getRenamingCrate(UUID uuid) {
      return this.renamingSessions.get(uuid);
   }

   public void removeRenamingSession(UUID uuid) {
      this.renamingSessions.remove(uuid);
   }

   public void openCrateSelectGUI(Player player) {
      Collection<CustomCrate> crates = this.plugin.getCustomCrateManager().getAllCrates();
      int size = Math.min(54, (crates.size() / 9 + 1) * 9 + 9);
      size = Math.max(27, size);
      Inventory gui = Bukkit.createInventory(null, size, LootCrates.colorize("&6&lSelect Crate to Edit"));
      ItemStack glass = this.createGlass(Material.GRAY_STAINED_GLASS_PANE);

      for (int i = 0; i < 9; i++) {
         gui.setItem(i, glass);
      }

      for (int i = size - 9; i < size; i++) {
         gui.setItem(i, glass);
      }

      int slot = 9;

      for (CustomCrate crate : crates) {
         if (slot >= size - 9) {
            break;
         }

         ItemStack item = crate.createCrateItem(1);
         ItemMeta meta = item.getItemMeta();
         List<String> lore = new ArrayList<>();
         lore.add("");
         lore.add(LootCrates.colorize("&7ID: &f" + crate.getId()));
         lore.add(LootCrates.colorize("&7Rewards: &e" + this.plugin.getRewardManager().getRewards(crate.getId()).size()));
         lore.add("");
         lore.add(LootCrates.colorize("&aClick to edit rewards!"));
         meta.setLore(lore);
         item.setItemMeta(meta);
         gui.setItem(slot++, item);
      }

      ItemStack createBtn = new ItemStack(Material.EMERALD);
      ItemMeta createMeta = createBtn.getItemMeta();
      createMeta.setDisplayName(LootCrates.colorize("&a&l+ Create New Crate"));
      createMeta.setLore(Arrays.asList("", LootCrates.colorize("&7Click to create a new"), LootCrates.colorize("&7custom crate type!")));
      createBtn.setItemMeta(createMeta);
      gui.setItem(size - 5, createBtn);
      player.openInventory(gui);
   }

   public void openEditGUI(Player player, String crateId) {
      CustomCrate crate = this.plugin.getCustomCrateManager().getCrate(crateId);
      if (crate != null) {
         this.editingSessions.put(player.getUniqueId(), crateId);
         Map<Integer, Integer> indexMap = new HashMap<>();
         this.slotToIndexMap.put(player.getUniqueId(), indexMap);
         Inventory gui = Bukkit.createInventory(null, 54, LootCrates.colorize("&6Edit: " + crate.getDisplayName()));
         ItemStack glass = this.createGlass(this.getGlassColor(crate));

         for (int i = 0; i < 9; i++) {
            gui.setItem(i, glass);
         }

         for (int i = 45; i < 54; i++) {
            gui.setItem(i, glass);
         }

         for (int i = 9; i < 45; i += 9) {
            gui.setItem(i, glass);
         }

         for (int i = 17; i < 45; i += 9) {
            gui.setItem(i, glass);
         }

         List<RewardManager.Reward> rewards = this.plugin.getRewardManager().getRewards(crateId);
         int slot = 10;
         int rewardIndex = 0;

         for (RewardManager.Reward reward : rewards) {
            if (slot >= 44) {
               break;
            }

            if (slot % 9 != 0 && slot % 9 != 8) {
               ItemStack item = reward.getItem();
               ItemMeta meta = item.getItemMeta();
               List<String> lore = meta.getLore() != null ? new ArrayList<>(meta.getLore()) : new ArrayList<>();
               lore.add("");
               lore.add(LootCrates.colorize("&7Weight: &e" + reward.getWeight()));
               lore.add(LootCrates.colorize("&aLeft-click: &7Edit weight"));
               lore.add(LootCrates.colorize("&cRight-click: &7Remove"));
               meta.setLore(lore);
               item.setItemMeta(meta);
               gui.setItem(slot, item);
               indexMap.put(slot, rewardIndex);
               slot++;
               rewardIndex++;
               if (slot % 9 == 8) {
                  slot += 2;
               }
            } else {
               slot++;
            }
         }

         ItemStack addItem = new ItemStack(Material.LIME_STAINED_GLASS_PANE);
         ItemMeta addMeta = addItem.getItemMeta();
         addMeta.setDisplayName(LootCrates.colorize("&a&l+ Add Reward"));
         addMeta.setLore(
            Arrays.asList(
               "",
               LootCrates.colorize("&7Hold an item and click"),
               LootCrates.colorize("&7to add it as a reward!"),
               "",
               LootCrates.colorize("&eAll NBT data preserved!")
            )
         );
         addItem.setItemMeta(addMeta);
         gui.setItem(49, addItem);
         ItemStack backItem = new ItemStack(Material.ARROW);
         ItemMeta backMeta = backItem.getItemMeta();
         backMeta.setDisplayName(LootCrates.colorize("&c&l← Back"));
         backItem.setItemMeta(backMeta);
         gui.setItem(45, backItem);
         ItemStack infoItem = new ItemStack(Material.BOOK);
         ItemMeta infoMeta = infoItem.getItemMeta();
         infoMeta.setDisplayName(LootCrates.colorize("&e&lHow to Add Items"));
         infoMeta.setLore(
            Arrays.asList(
               "",
               LootCrates.colorize("&71. Get any item with NBT"),
               LootCrates.colorize("&72. Hold it in your hand"),
               LootCrates.colorize("&73. Click the green '+' button"),
               LootCrates.colorize("&74. Set the weight (rarity)"),
               "",
               LootCrates.colorize("&d&lQUICK ADD:"),
               LootCrates.colorize("&7Shift-click any item in your"),
               LootCrates.colorize("&7inventory to instantly add it!"),
               "",
               LootCrates.colorize("&aHigher weight = more common")
            )
         );
         infoItem.setItemMeta(infoMeta);
         gui.setItem(47, infoItem);
         ItemStack deleteBtn = new ItemStack(Material.BARRIER);
         ItemMeta deleteMeta = deleteBtn.getItemMeta();
         deleteMeta.setDisplayName(LootCrates.colorize("&c&lDelete Crate"));
         deleteMeta.setLore(Arrays.asList("", LootCrates.colorize("&7Shift+Click to delete"), LootCrates.colorize("&7this crate permanently!")));
         deleteBtn.setItemMeta(deleteMeta);
         gui.setItem(53, deleteBtn);
         ItemStack renameBtn = new ItemStack(Material.NAME_TAG);
         ItemMeta renameMeta = renameBtn.getItemMeta();
         renameMeta.setDisplayName(LootCrates.colorize("&e&l✎ Rename Crate"));
         renameMeta.setLore(Arrays.asList("", LootCrates.colorize("&7Current: " + crate.getDisplayName()), "", LootCrates.colorize("&aClick to rename!")));
         renameBtn.setItemMeta(renameMeta);
         gui.setItem(46, renameBtn);
         ItemStack animBtn = new ItemStack(Material.NETHER_STAR);
         ItemMeta animMeta = animBtn.getItemMeta();
         animMeta.setDisplayName(LootCrates.colorize("&d&l✦ Animation Style"));
         animMeta.setLore(
            Arrays.asList(
               "", LootCrates.colorize("&7Current: &e" + crate.getAnimationType().getDisplayName()), "", LootCrates.colorize("&aClick to change animation!")
            )
         );
         animBtn.setItemMeta(animMeta);
         gui.setItem(51, animBtn);
         ItemStack keyBtn = new ItemStack(crate.getKeyMaterial());
         ItemMeta keyMeta = keyBtn.getItemMeta();
         keyMeta.setDisplayName(LootCrates.colorize("&b&l\ud83d\udd11 Customize Key"));
         keyMeta.setLore(
            Arrays.asList(
               "",
               LootCrates.colorize("&7Current Key: " + crate.getKeyName()),
               LootCrates.colorize("&7Material: &f" + crate.getKeyMaterial().name()),
               "",
               LootCrates.colorize("&aClick to customize!")
            )
         );
         keyBtn.setItemMeta(keyMeta);
         gui.setItem(48, keyBtn);
         player.openInventory(gui);
      }
   }

   public void openKeyCustomizeGUI(Player player, String crateId) {
      CustomCrate crate = this.plugin.getCustomCrateManager().getCrate(crateId);
      if (crate != null) {
         Inventory gui = Bukkit.createInventory(null, 45, LootCrates.colorize("&b&lCustomize Key"));
         ItemStack glass = this.createGlass(Material.CYAN_STAINED_GLASS_PANE);

         for (int i = 0; i < 9; i++) {
            gui.setItem(i, glass);
         }

         for (int i = 36; i < 45; i++) {
            gui.setItem(i, glass);
         }

         ItemStack currentKey = crate.createKeyItem(1);
         ItemMeta currentMeta = currentKey.getItemMeta();
         currentMeta.setDisplayName(LootCrates.colorize("&b&lCurrent Key"));
         List<String> lore = new ArrayList<>();
         lore.add("");
         lore.add(LootCrates.colorize("&7Name: " + crate.getKeyName()));
         lore.add(LootCrates.colorize("&7Material: &f" + crate.getKeyMaterial().name()));
         currentMeta.setLore(lore);
         currentKey.setItemMeta(currentMeta);
         gui.setItem(4, currentKey);
         Material[] keyMaterials = new Material[]{
            Material.TRIPWIRE_HOOK,
            Material.GOLD_INGOT,
            Material.IRON_INGOT,
            Material.DIAMOND,
            Material.EMERALD,
            Material.AMETHYST_SHARD,
            Material.ECHO_SHARD,
            Material.NETHER_STAR,
            Material.HEART_OF_THE_SEA,
            Material.PRISMARINE_SHARD,
            Material.BLAZE_ROD,
            Material.BREEZE_ROD,
            Material.END_ROD,
            Material.PHANTOM_MEMBRANE,
            Material.GHAST_TEAR,
            Material.DRAGON_BREATH,
            Material.FEATHER,
            Material.BONE
         };
         String[] materialNames = new String[]{
            "&fTripwire Hook",
            "&6Gold Ingot",
            "&7Iron Ingot",
            "&bDiamond",
            "&aEmerald",
            "&dAmethyst Shard",
            "&8Echo Shard",
            "&eNether Star",
            "&3Heart of the Sea",
            "&3Prismarine Shard",
            "&6Blaze Rod",
            "&fBreeze Rod",
            "&fEnd Rod",
            "&7Phantom Membrane",
            "&fGhast Tear",
            "&5Dragon Breath",
            "&fFeather",
            "&fBone"
         };
         int slot = 9;

         for (int i = 0; i < keyMaterials.length && slot < 36; i++) {
            ItemStack matItem = new ItemStack(keyMaterials[i]);
            ItemMeta matMeta = matItem.getItemMeta();
            boolean isSelected = crate.getKeyMaterial() == keyMaterials[i];
            matMeta.setDisplayName(LootCrates.colorize((isSelected ? "&a✓ " : "&e") + materialNames[i]));
            matMeta.setLore(Arrays.asList("", isSelected ? LootCrates.colorize("&a▶ Currently Selected") : LootCrates.colorize("&7Click to select!")));
            matItem.setItemMeta(matMeta);
            gui.setItem(slot++, matItem);
         }

         ItemStack renameKeyBtn = new ItemStack(Material.NAME_TAG);
         ItemMeta renameKeyMeta = renameKeyBtn.getItemMeta();
         renameKeyMeta.setDisplayName(LootCrates.colorize("&e&l✎ Rename Key"));
         renameKeyMeta.setLore(Arrays.asList("", LootCrates.colorize("&7Current: " + crate.getKeyName()), "", LootCrates.colorize("&aClick to rename!")));
         renameKeyBtn.setItemMeta(renameKeyMeta);
         gui.setItem(40, renameKeyBtn);
         ItemStack backItem = new ItemStack(Material.ARROW);
         ItemMeta backMeta = backItem.getItemMeta();
         backMeta.setDisplayName(LootCrates.colorize("&c&l← Back"));
         backItem.setItemMeta(backMeta);
         gui.setItem(36, backItem);
         this.editingSessions.put(player.getUniqueId(), crateId);
         player.openInventory(gui);
      }
   }

   public void startKeyRename(Player player, String crateId) {
      this.keyRenamingSessions.put(player.getUniqueId(), crateId);
      player.closeInventory();
      player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&e&lEnter a new name for the key:"));
      player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&7Type the name in chat (supports &colors&7!)"));
      player.sendMessage(this.plugin.getPrefix() + LootCrates.colorize("&7Type &c'cancel'&7 to cancel."));
   }

   public boolean hasKeyRenamingSession(UUID uuid) {
      return this.keyRenamingSessions.containsKey(uuid);
   }

   public String getKeyRenamingCrate(UUID uuid) {
      return this.keyRenamingSessions.get(uuid);
   }

   public void removeKeyRenamingSession(UUID uuid) {
      this.keyRenamingSessions.remove(uuid);
   }

   public void openWeightEditGUI(Player player, ItemStack item, int currentWeight) {
      Inventory gui = Bukkit.createInventory(null, 27, LootCrates.colorize("&6Set Weight (Drop Chance)"));
      ItemStack glass = this.createGlass(Material.GRAY_STAINED_GLASS_PANE);

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, glass);
      }

      gui.setItem(4, item.clone());
      int[] decreaseAmounts = new int[]{-10, -5, -1};
      int[] decreaseSlots = new int[]{10, 11, 12};
      int[] increaseAmounts = new int[]{1, 5, 10};
      int[] increaseSlots = new int[]{14, 15, 16};

      for (int i = 0; i < 3; i++) {
         ItemStack decrease = new ItemStack(Material.RED_STAINED_GLASS_PANE);
         ItemMeta decMeta = decrease.getItemMeta();
         decMeta.setDisplayName(LootCrates.colorize("&c" + decreaseAmounts[i]));
         decrease.setItemMeta(decMeta);
         gui.setItem(decreaseSlots[i], decrease);
         ItemStack increase = new ItemStack(Material.LIME_STAINED_GLASS_PANE);
         ItemMeta incMeta = increase.getItemMeta();
         incMeta.setDisplayName(LootCrates.colorize("&a+" + increaseAmounts[i]));
         increase.setItemMeta(incMeta);
         gui.setItem(increaseSlots[i], increase);
      }

      ItemStack weightDisplay = new ItemStack(Material.GOLD_INGOT);
      ItemMeta weightMeta = weightDisplay.getItemMeta();
      weightMeta.setDisplayName(LootCrates.colorize("&eWeight: &6" + currentWeight));
      weightMeta.setLore(Arrays.asList("", LootCrates.colorize("&7Higher = more common"), LootCrates.colorize("&7Lower = more rare")));
      weightDisplay.setItemMeta(weightMeta);
      gui.setItem(13, weightDisplay);
      ItemStack confirm = new ItemStack(Material.EMERALD);
      ItemMeta confirmMeta = confirm.getItemMeta();
      confirmMeta.setDisplayName(LootCrates.colorize("&a&lConfirm"));
      confirm.setItemMeta(confirmMeta);
      gui.setItem(22, confirm);
      player.openInventory(gui);
   }

   public void openCreateCrateGUI(Player player) {
      Inventory gui = Bukkit.createInventory(null, 27, LootCrates.colorize("&6&lCreate New Crate"));
      ItemStack glass = this.createGlass(Material.GRAY_STAINED_GLASS_PANE);

      for (int i = 0; i < 27; i++) {
         gui.setItem(i, glass);
      }

      Material[] colors = new Material[]{
         Material.WHITE_STAINED_GLASS_PANE,
         Material.RED_STAINED_GLASS_PANE,
         Material.ORANGE_STAINED_GLASS_PANE,
         Material.YELLOW_STAINED_GLASS_PANE,
         Material.LIME_STAINED_GLASS_PANE,
         Material.CYAN_STAINED_GLASS_PANE,
         Material.BLUE_STAINED_GLASS_PANE,
         Material.PURPLE_STAINED_GLASS_PANE,
         Material.PINK_STAINED_GLASS_PANE
      };
      String[] colorNames = new String[]{"WHITE", "RED", "ORANGE", "YELLOW", "LIME", "CYAN", "BLUE", "PURPLE", "PINK"};
      ItemStack info = new ItemStack(Material.NAME_TAG);
      ItemMeta infoMeta = info.getItemMeta();
      infoMeta.setDisplayName(LootCrates.colorize("&e&lCreate New Crate"));
      infoMeta.setLore(
         Arrays.asList(
            "",
            LootCrates.colorize("&7Select a color below."),
            LootCrates.colorize("&7You'll be asked to enter"),
            LootCrates.colorize("&7a custom name in chat!"),
            "",
            LootCrates.colorize("&aSupports color codes!")
         )
      );
      info.setItemMeta(infoMeta);
      gui.setItem(4, info);

      for (int i = 0; i < colors.length; i++) {
         ItemStack colorItem = new ItemStack(colors[i]);
         ItemMeta colorMeta = colorItem.getItemMeta();
         colorMeta.setDisplayName(LootCrates.colorize("&f" + colorNames[i] + " Crate"));
         colorMeta.setLore(Arrays.asList("", LootCrates.colorize("&7Click to create!")));
         colorItem.setItemMeta(colorMeta);
         gui.setItem(9 + i, colorItem);
      }

      player.openInventory(gui);
   }

   public void openAnimationSelectGUI(Player player, String crateId) {
      Inventory gui = Bukkit.createInventory(null, 54, LootCrates.colorize("&d&lSelect Animation Style"));
      ItemStack glass = this.createGlass(Material.MAGENTA_STAINED_GLASS_PANE);

      for (int i = 0; i < 9; i++) {
         gui.setItem(i, glass);
      }

      for (int i = 45; i < 54; i++) {
         gui.setItem(i, glass);
      }

      CustomCrate crate = this.plugin.getCustomCrateManager().getCrate(crateId);
      AnimationType currentAnim = crate != null ? crate.getAnimationType() : AnimationType.CLASSIC;
      AnimationType[] animations = AnimationType.values();
      int slot = 9;

      for (AnimationType anim : animations) {
         if (slot >= 45) {
            break;
         }

         Material iconMaterial = this.getAnimationIcon(anim);
         ItemStack item = new ItemStack(iconMaterial);
         ItemMeta meta = item.getItemMeta();
         String prefix = anim == currentAnim ? "&a✓ " : "&e";
         meta.setDisplayName(LootCrates.colorize(prefix + anim.getDisplayName()));
         meta.setLore(
            Arrays.asList(
               "",
               LootCrates.colorize("&7" + anim.getDescription()),
               "",
               anim == currentAnim ? LootCrates.colorize("&a▶ Currently Selected") : LootCrates.colorize("&eClick to select!")
            )
         );
         item.setItemMeta(meta);
         gui.setItem(slot++, item);
      }

      ItemStack backItem = new ItemStack(Material.ARROW);
      ItemMeta backMeta = backItem.getItemMeta();
      backMeta.setDisplayName(LootCrates.colorize("&c&l← Back"));
      backItem.setItemMeta(backMeta);
      gui.setItem(45, backItem);
      this.editingSessions.put(player.getUniqueId(), crateId);
      player.openInventory(gui);
   }

   private Material getAnimationIcon(AnimationType anim) {
      return switch (anim) {
         case CLASSIC -> Material.CHEST;
         case SLOW_REVEAL -> Material.CLOCK;
         case FAST_SPIN -> Material.FEATHER;
         case BOUNCE -> Material.SLIME_BALL;
         case SPIRAL -> Material.NAUTILUS_SHELL;
         case PULSE -> Material.HEART_OF_THE_SEA;
         case WAVE -> Material.KELP;
         case CASCADE -> Material.WATER_BUCKET;
         case EXPLOSION -> Material.TNT;
         case VORTEX -> Material.END_PORTAL_FRAME;
         case RAINBOW -> Material.PRISMARINE_SHARD;
         case METEOR -> Material.FIRE_CHARGE;
         case LIGHTNING -> Material.LIGHTNING_ROD;
         case FIREWORK -> Material.FIREWORK_ROCKET;
         case GALAXY -> Material.END_CRYSTAL;
         case PORTAL -> Material.OBSIDIAN;
         case TORNADO -> Material.PHANTOM_MEMBRANE;
         case EARTHQUAKE -> Material.GRAVEL;
         case BUBBLE -> Material.PUFFERFISH;
         case CRYSTAL -> Material.AMETHYST_SHARD;
         case PHOENIX -> Material.BLAZE_POWDER;
         case DRAGON -> Material.DRAGON_HEAD;
         case MYSTIC -> Material.ENCHANTED_BOOK;
         case NEON -> Material.GLOW_INK_SAC;
         case GLITCH -> Material.BARRIER;
      };
   }

   public String getEditingCrate(UUID uuid) {
      return this.editingSessions.get(uuid);
   }

   public void removeEditingSession(UUID uuid) {
      this.editingSessions.remove(uuid);
      this.slotToIndexMap.remove(uuid);
   }

   public Map<Integer, Integer> getSlotToIndexMap(UUID uuid) {
      return this.slotToIndexMap.get(uuid);
   }

   private ItemStack createGlass(Material material) {
      ItemStack glass = new ItemStack(material);
      ItemMeta meta = glass.getItemMeta();
      meta.setDisplayName(" ");
      glass.setItemMeta(meta);
      return glass;
   }

   private Material getGlassColor(CustomCrate crate) {
      String colorName = crate.getParticleColor().toString();
      if (colorName.contains("BLUE")) {
         return Material.BLUE_STAINED_GLASS_PANE;
      } else if (colorName.contains("RED")) {
         return Material.RED_STAINED_GLASS_PANE;
      } else if (colorName.contains("GREEN") || colorName.contains("LIME")) {
         return Material.LIME_STAINED_GLASS_PANE;
      } else if (colorName.contains("PURPLE") || colorName.contains("FUCHSIA")) {
         return Material.PURPLE_STAINED_GLASS_PANE;
      } else if (colorName.contains("ORANGE")) {
         return Material.ORANGE_STAINED_GLASS_PANE;
      } else if (colorName.contains("YELLOW")) {
         return Material.YELLOW_STAINED_GLASS_PANE;
      } else if (colorName.contains("AQUA") || colorName.contains("CYAN")) {
         return Material.CYAN_STAINED_GLASS_PANE;
      } else {
         return colorName.contains("PINK") ? Material.PINK_STAINED_GLASS_PANE : Material.WHITE_STAINED_GLASS_PANE;
      }
   }
}
