# Shrink It! 🔬 — Roblox game (Luau)

Zap objects with your **Shrink Ray**, then **carry them back to your base** while the zone's owner chases you:
Grandpa Joe in his backyard, the Angry Neighbor, Officer Doug, Captain Barnacle, a Security Bot and the Yeti.
Reach the safe zone (the chaser gives up there), then **walk your loot onto your own plot** so it goes on your
pedestals in your **Pocket Museum**, earning coins every second. Red arrows on the ground show the way.
Upgrade your ray and your run speed, push further down the corridor (all the way to the Moon), rebirth,
complete the Index, and raid other museums in the endgame.

Everything is **server-authoritative**: the client only sends intent, and the server validates
cooldowns, power-scaled charge time, range, carry capacity, ownership and costs.

---

## 📁 File map (exact Studio locations)

`.server.lua` = **Script**, `.client.lua` = **LocalScript**, `.lua` = **ModuleScript**.
Names in Studio must match the file names (without the extensions).

| Studio location | Type | File |
|---|---|---|
| **ReplicatedStorage › Shared** | Folder | `src/ReplicatedStorage/Shared/` |
| ↳ Config › GameConfig | ModuleScript | `Config/GameConfig.lua`: global tuning, raid, sounds |
| ↳ Config › TierConfig | ModuleScript | `Config/TierConfig.lua`: the 10 zones (name, color, depth, spawn count) |
| ↳ Config › ObjectConfig | ModuleScript | `Config/ObjectConfig.lua`: every object + custom-object lookup |
| ↳ Config › RarityConfig | ModuleScript | `Config/RarityConfig.lua`: rarities + variants |
| ↳ Config › UpgradeConfig | ModuleScript | `Config/UpgradeConfig.lua`: upgrades, rebirth, token upgrades |
| ↳ Config › MonetizationConfig | ModuleScript | `Config/MonetizationConfig.lua`: 🔧 pass/product IDs, skins, gem shop |
| ↳ Config › RewardConfig | ModuleScript | `Config/RewardConfig.lua`: gifts, daily, index, likes, codes, Infinite Pack |
| ↳ Config › EventConfig | ModuleScript | `Config/EventConfig.lua`: rotating events, event objects |
| ↳ Config › ChaserConfig | ModuleScript | `Config/ChaserConfig.lua`: the 10 chasers (names, speeds, looks, lines) + rage settings |
| ↳ ObjectModels | ModuleScript | `ObjectModels.lua`: the 3D models for every object (world + menu previews) |
| ↳ Format | ModuleScript | `Format.lua`: 14.3k / 1.2M / 4.5B, timers |
| ↳ Formulas | ModuleScript | `Formulas.lua`: shared math (costs, stats, income) |
| ↳ RewardUtil | ModuleScript | `RewardUtil.lua`: reward descriptions + odds |
| ↳ InfinitePackGen | ModuleScript | `InfinitePackGen.lua`: deterministic endless tile chain |
| ↳ Remotes | ModuleScript | `Remotes.lua`: creates / finds all remotes |
| **ServerScriptService › Main** | Script | `src/ServerScriptService/Main.server.lua` |
| **ServerScriptService › Services** | Folder | `src/ServerScriptService/Services/` |
| ↳ SessionService, DataService, NetService, MapService, MonetizationService, EventService, EconomyService, MuseumService, IndexService, AreaService, SpawnService, ShrinkService, UpgradeService, RebirthService, RewardService, InfinitePackService, RaidService, LeaderboardService, CarryService, CosmeticService, SpeedService, PvPService, ChatService, ModelFactory, MapDecor | ModuleScripts | one file each |
| **StarterPlayer › StarterPlayerScripts › ClientMain** | LocalScript | `src/StarterPlayerScripts/ClientMain.client.lua` |
| **StarterPlayer › StarterPlayerScripts › ClientModules** | Folder | `src/StarterPlayerScripts/ClientModules/` |
| ↳ State, UIKit, HUD, Effects, RayController, Prices, Audio | ModuleScripts | one file each |
| ↳ Menus › GiftsMenu, InfinitePackMenu, ShopMenu, IndexMenu, RebirthMenu, MuseumMenu, UpgradesMenu, SellMenu, FuseMenu, TrailsMenu, SettingsMenu | ModuleScripts | one file each |
| **StarterGui** | (nothing) | The UI is built in code (`ScreenGui` with `ResetOnSpawn = false`), so StarterGui stays empty. |

### Install option A: Rojo (recommended)
1. Install [Rojo](https://rojo.space) (VS Code extension or CLI) and the Rojo Studio plugin.
2. In this folder run `rojo serve`, then click **Connect** in the Studio plugin.

### Install option B: copy and paste by hand
Create each Folder/Script/LocalScript/ModuleScript in the locations above **with the exact names**,
then paste in each file's contents. Every file starts with a `📍 LOCATION:` comment as a reminder.

---

## ✅ Setup checklist (things you must do in Studio by hand)

### Required
- [ ] **Publish the place** (File → Publish to Roblox). DataStores only work in published places.
- [ ] **Game Settings → Security → Enable Studio Access to API Services**, so saving works while testing in Studio.
      Without it, Studio uses temporary data and prints a warning. That's fine for quick tests.
- [ ] **Max Players = 6**: this is a 6-player game (6 plots in one fair row). In Studio: **Game Settings → Places →
      ⋯ next to your place → Edit → Server Size / Max Players = 6**. (The server also kicks a 7th player as a safety net,
      see `GameConfig.MaxPlayers`.)
      (To allow more players, raise `GameConfig.PlotCount` and build or allow more plots.)
- [ ] **Create the 15 Gamepasses** (Creator Dashboard → your experience → Monetization → Passes) and paste their
      IDs into `MonetizationConfig.GamePasses` (every line marked `-- 🔧 REPLACE Id`).
- [ ] **Create the 14 Developer Products** (Monetization → Developer Products) and paste their IDs into
      `MonetizationConfig.Products`. This includes **PackTier1 / PackTier2 / PackTier3** for the Infinite Pack paid tiles.
      These MUST be Developer Products (repeatable), not passes.
- [ ] Keep **TextChatService** as the chat system (the default for new places). The VIP chat tag uses it.

### Recommended
- [ ] **Icons**: replace `Image = "rbxassetid://0"` in `MonetizationConfig` with your own uploaded images.
      Until then, emoji icons are shown.
- [ ] **Sounds**: replace the `GameConfig.Sounds` placeholders (pop, charge, click, reward, error) with your own sound IDs.
- [ ] **Likes**: update `RewardConfig.Likes.CurrentLikes` by hand whenever you want the lobby sign to move.
      Each reached goal reveals its code on the sign.
- [ ] **Codes**: edit `RewardConfig.Codes` (case-insensitive; `RequiresLikes` locks a code until that goal is reached).

### Models & textures
Every object, the museum, pedestals, chasers and the Shrink Ray are **built in code with detailed, realistic part
models** (curves from sphere meshes, smooth cones, rounded boxes, rubber tyres with rims & spokes, tinted glass,
printed number plates/signs) using Roblox's materials (metal, glass, rubber, leather, plaster, roof shingles, rock,
snow, neon, …), so nothing needs uploading. Tiny details are stripped automatically when an object is shown small on
a pedestal (`ModelFactory.Simplify`) to keep full museums fast. See `ObjectModels` (all 31 objects), `MapService` (museum temple), `MuseumService`
(pedestals), `ShrinkService` (ray gun) and `ChaserConfig` (chaser outfits & props).

### ⭐ Real 3D models for the objects (2 minutes, recommended)
- [ ] Open the place in Studio → **View › Command Bar** → paste all of **`tools/ImportToolboxModels.lua`** → Enter.
      For every object it searches the Toolbox, takes the first free model that loads, **strips all scripts/sounds/seats**
      and saves it as **ReplicatedStorage › ShrinkableTemplates › `<ObjectId>`**. They're used in the world, on the
      pedestals AND in the menu previews, auto-scaled. Look them over: delete or replace any you don't like (keep the
      name), tweak `SEARCH` in the script and run it again for the missing ones. Then **Publish/Save**.
- [ ] **Royal Crate**: create 2 Developer Products (1 crate, 3 crates) and paste their ids into
      `MonetizationConfig.Products.RoyalCrate` / `RoyalCrate3`. Also the **2x Speed** gamepass id (`GamePasses.DoubleSpeed`).
      (In Studio the crate shows as unavailable: Studio can't check PolicyService. It works in a live game.)
- [ ] **Ambient sounds** (optional): Toolbox → Audio → creator "Roblox", search "birds", "city", "ocean", "wind"…,
      copy the ids into `GameConfig.Ambient` (one per zone, `Base` = safe zone).
- [ ] **Trail Robux products**: create 8 Developer Products (Green … Eternal Trail) and paste their ids into
      `MonetizationConfig.Products.TrailGreen … TrailEternal` (purple buttons in the Trail Shop).

### Optional: your own meshes instead of the built-in models
- [ ] **Object models**: put Models in **ReplicatedStorage › ShrinkableTemplates** (or ServerStorage › ShrinkableTemplates), each **named
      exactly like its ObjectConfig id** (e.g. `FerrisWheel`, `SodaCan`, `TheMoon`). Set a PrimaryPart. The game
      anchors them, removes scripts, places them on the ground, and scales them down for museum display.
      Objects without a template use the built-in detailed models from `ObjectModels`. Any model you drop in (e.g. a free
      Toolbox mesh) is automatically scaled to that object's size, so you don't need to resize it.
- [ ] **Shrink Ray tool**: put a Tool named **`ShrinkRay`** in ServerStorage with a `Handle` part and an
      **Attachment named `Tip`** inside the Handle (where the beam starts). Otherwise a simple ray is generated.
- [ ] **Chaser NPCs**: put Models (with a `Humanoid` + `HumanoidRootPart`) in **ServerStorage › Chasers** named
      `Tier1` … `Tier6` to replace the generated characters. Names, speeds and lines live in `ChaserConfig`.
- [ ] **Your own map**: build a Model in Workspace named **`ShrinkItMap`** with this structure, and the game will
      use it instead of generating one:
      ```
      ShrinkItMap (Model)
      ├─ Base (Model): Floor, SafeZone (invisible Part covering the whole base: entering it delivers loot),
      │                SpawnLocation, LikeSign, Board_MuseumValue / Board_TotalShrinks / Board_Rebirths /
      │                Board_RaidsWon (Parts), VIPRoom (invisible region Part), VIPDoor, VIPFountain
      ├─ Zones (Folder)
      │   └─ Zone_1 … Zone_6 (Model, attribute Tier = 1..6)
      │        ├─ Floor (Part: defines the zone bounds)
      │        └─ SpawnPoints (Folder of small invisible Parts)
      ├─ Plots (Folder)
      │   └─ Plot_1 … Plot_8 (Model, attribute PlotId = n)
      │        ├─ Floor (Part 90×80; local +Z = front. Pedestals fill the front, building at the back)
      │        ├─ MuseumBuilding (Model with a "Sign" Part that has a SurfaceGui with a TextLabel named "Label")
      │        └─ SpawnPad (Part)
      └─ LiveObjects (Folder), Chasers (Folder) — may be empty
      ```
      Tip: press Play once with no `ShrinkItMap`, then copy the generated map from the running game, paste it into
      Workspace in edit mode and decorate it.

### ➕ Add new shrinkable objects without code
Place any Model in Workspace and:
1. Add the tag **`Shrinkable`** (Properties → Tags, or the Tag Editor).
2. Add these attributes: **`Tier`** (number 1-6), **`Rarity`** (`Common`…`Secret`), **`BaseIncome`** (number),
   and optionally **`ObjectId`** (unique id, defaults to the model name) and **`DisplayName`**.

It becomes shrinkable, respawns after the tier's cooldown with a fresh variant roll, shows up in the Index,
and can be displayed in museums. To add an object to the random spawn pool instead, add an entry in
`ObjectConfig.Objects` (and optionally a template model with the same id).

---


### 🗺️ The map is saved in the place file
`map/ShrinkItMap.model.json` is the whole generated map, pre-built so you can SEE and EDIT it in Studio without pressing
Play. Edit it freely in Studio and save. If you change `MapService`/`MapDecor` code, re-bake it with
`bash tools/mapbake/bake.sh` (needs the `luau` CLI) or just delete Workspace › ShrinkItMap and the game regenerates it.
Shopkeepers are added when the server starts.

## 🎮 Feature overview

| Feature | Where |
|---|---|
| Hold-to-charge Shrink Ray, beam, squash + fly-to-pocket tween, pop sound, particles | `RayController`, `Effects`, `ShrinkService` |
| Shrink ANY object at any Ray Power — more power = faster charge (hover shows the charge time) | `Formulas`, `RayController`, `ShrinkService` |
| Map: a walled base with ONE gate into a corridor of **10 themed zones** (Backyard → Outer Space), only small props along the walls so the middle is wide open | `MapService`, `MapDecor`, `TierConfig` |
| **Mystery boxes everywhere**: zones are full of rarity-colored boxes. Everyone sees the same boxes; when you take one it disappears only for you (up to `GameConfig.Boxes.MaxClaims` players can take each). Rare boxes are announced with their zone | `SpawnService`, `Effects` |
| Put a box down **anywhere in your plot** (F = where your mouse points, with a green aim ring; Place button = right in front of you) → it opens after a timer (skip with Gems) into a **random** object of that zone (rarer box = rarer objects) with a random **size & weight** (Tiny 0.6x … Colossal 5x income) | `MuseumService`, `SpawnService.RollContents`, `GameConfig.Sizes` |
| Pick up an object from a pedestal → you **hold it above your head at its real size**; put it down anywhere else in your plot. ⭐ Equip Best (right side) fills your display spots (things you placed yourself keep their position) | `CarryService`, `MuseumService`, `HUD` |
| Hover over anyone's pedestal object to see its income, weight, size and owner | `Effects` |
| Fair base: 6 fenced plots in a semicircle around the gate, all exactly the same distance from it | `MapService` |
| Base: SELL stall, a big blue **Fuse Machine** (3 slots → pipes → result), TRAILS & SHOP stalls (ProximityPrompts) | `MapDecor`, `SellMenu`, `FuseMenu`, `TrailsMenu`, `CosmeticService` |
| **Trail Shop**: 10 trails that make you run faster (x1.05 … x1.6), bought with Coins or Robux; sideways card row | `TrailsMenu`, `CosmeticService`, `MonetizationConfig.Trails` |
| Studded LEGO-style map (bright green studs, brown dirt walls, X-fences, painted SAFE ZONE line); `GameConfig.Studs = false` turns studs off | `MapDecor.Studify`, `MapService` |
| **Chasers** (10, VERY fast: 38 → 96 speed + catch-up sprint): each zone's owner chases you. Caught → your boxes fall on the ground and the chaser walks home; grab them back before they vanish and the chaser gets **ENRAGED** (faster every time) | `CarryService`, `ChaserConfig` |
| **Speed training**: stand on the treadmill outside your plot (AFK works, anti-idle included) to earn speed; upgrade the Treadmill to train faster; **2x Speed** gamepass | `SpeedService`, `UpgradeConfig.Treadmill`, `GameConfig.Training` |
| **Bat & Trap** for everyone: whack a player carrying something outside the safe zone to steal it; traps freeze whoever steps in them | `PvPService`, `GameConfig.PvP` |
| **Chat tabs**: 🌍 Global (all servers, filtered), 📍 Here (nearby), 👥 Friends | `ChatService` |
| **Royal Crate** (Robux): 5 exclusive objects that never spawn, odds shown in the Shop, blocked where paid random items are restricted | `MonetizationService`, `ShopMenu`, `MonetizationConfig.RoyalCrate` |
| ⚙️ Settings (top bar): sound / ambience / music volume, other players' trails, low graphics, auto shrink | `SettingsMenu`, `Audio`, `Effects` |
| Sound effects (built-in Roblox sounds) + ambient loops per zone (paste ids in `GameConfig.Ambient`) | `Audio`, `GameConfig.Sounds` |
| Rebirth keeps ALL your objects, pedestals and speed | `RebirthService` |
| Sleeping zone owners (💤) in every zone | `CarryService` |
| Rarities, variants (Golden x5, Diamond x10, Rainbow x25, Cosmic x100) with glow; luck-weighted rolls | `RarityConfig`, `SpawnService`, `ModelFactory` |
| Event objects with server-wide announcement | `EventService`, `SpawnService` |
| Pocket Museum: plots, pedestals, glass cases, "+$" floating text | `MuseumService`, `Effects` |
| Upgrades: Ray Power, Treadmill, Carry Capacity (3 → 10), Income Boost, Box Opening, Charge Speed, Range, Luck, Museum Size + **⚡ Buy All** (keeps buying the cheapest affordable upgrade) | `UpgradeConfig`, `UpgradeService` |
| Carry gamepasses: **2x Carry**, **5x Carry**, **Infinite Carry** (R$ 4999); also **Fast Boxes**, **Big Sizes** passes and **Open All Boxes Now** / **+30 Min of Training** products | `MonetizationConfig`, `Formulas.RayStats` |
| You hold the top thing **in your hands** (rest on your back). Boxes are as big as the size inside them (sparkles + "HUGE!" tag); hover a box in a base to see its 🍀 luck | `CarryService`, `ModelFactory.CreateBox`, `Effects` |
| Treadmill locks you in place and you run (jump to get off); 📍 area name top-right; studded menu backgrounds (animated in shops) | `Effects`, `HUD`, `UIKit.Studs` |
| **Night** (like Steal an Egg): every 4 min a big wall closes off the zones, everyone inside goes back to base, ALL boxes are replaced, then the wall lifts (countdown on the wall + top-right) | `SpawnService` (night loop), `GameConfig.Night` |
| **Your asset pack** (`assets/`, imported with `python3 tools/import_assets.py <Individual_Assets folder>`): the 10 animated chasers (ServerStorage > Chasers > Tier1..10, their RunAndAttack controller steered by the game: only the thief is chased, no damage), all 49 object models (ReplicatedStorage > ShrinkableTemplates), ray guns per skin, the 4 shopkeepers, and each zone's environment kit, landmark and props (ServerStorage > AssetPack, placed at server start) | `CarryService`, `ModelFactory`, `ShrinkService`, `MapDecor.PackDecor` |
| **Sleeping characters** (`assets/Sleeping`, `python3 tools/import_assets.py --sleeping <folder>`): each zone's owner snores in its zone and wakes up to chase you from its spot when you grab a box, then goes back to sleep; shopkeepers nap until a player walks up | `CarryService` (sleepers), `MapDecor.ShopkeeperNaps` |
| **Your own textures**: paste asset IDs into `TextureConfig` (ground per zone, plot floors, shop counters, box faces, menu backgrounds) | `TextureConfig`, `MapService.ApplyTextures` |
| Rebirth (multiplier, Gems, Tokens) + permanent Token upgrades | `RebirthService` |
| The Index with per-area completion rewards (Normal set + full variant set) | `IndexService`, `IndexMenu` |
| Museum Raids (opt-in, max Ray Power, copies only, shield, revenge window + bonus) | `RaidService` |
| Free playtime gifts (12, session-based, Huge chance on the last ones) | `RewardService`, `GiftsMenu` |
| Infinite Pack (endless, FREE/R$ pattern, refresh timer, preview row, odds display) | `InfinitePackGen`, `InfinitePackService`, `InfinitePackMenu` |
| 16 Gamepasses, 11 Developer Products + Royal Crate + 8 trail products + 3 pack tiers, idempotent `ProcessReceipt` | `MonetizationService` |
| Like-goal sign → codes, global leaderboards, rotating 30-minute events, daily streak | `RewardService`, `LeaderboardService`, `EventService` |
| Session-locked saving with autosave, save on leave, and BindToClose | `DataService` |

### How purchases stay safe (ProcessReceipt)
- The purchase is granted, and its `PurchaseId` is recorded, **in the same player profile**, which is then saved immediately.
  `PurchaseGranted` is returned **only after that save succeeds**.
- A retried receipt whose `PurchaseId` is already recorded is never granted again. It only re-attempts the save.
- If the player isn't in the server or their data isn't loaded yet, it returns `NotProcessedYet` and Roblox retries later.
- Infinite Pack purchases become a **credit** for that pack tier. If the chain moved on or refreshed before the receipt
  arrived, the credit is kept and auto-applies to the next matching paid tile, so a purchase is never lost.

### Policy notes
- Paid tiles that contain a random reward show a **🎲 Odds** button with exact percentages.
- Players for whom `PolicyService` reports `ArePaidRandomItemsRestricted` (or when the policy can't be read) never
  see random rewards on paid tiles. Those tiles give a fixed Gems reward instead.
- Raids are opt-in only, and the victim never loses anything; raiders only get copies.

### Testing tips
- Studio test purchases are free and run the real `ProcessReceipt` code once your product IDs are set.
- To test progression quickly, temporarily raise `BaseIncome` values in `ObjectConfig` or lower costs in `UpgradeConfig`.
- Change `GameConfig.DataStoreName` to wipe all saves (for example, before release).
- Known engine limit: only ~31 `Highlight`s render at once. Variant glows on the map use them; museum displays use
  lights and sparkles instead.
