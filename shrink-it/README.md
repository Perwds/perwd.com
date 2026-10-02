# Shrink It! 🔬 — Roblox game (Luau)

Zap objects with your **Shrink Ray**, then **carry them back to your base** while the zone's owner chases you:
Grandpa Joe in his backyard, the Angry Neighbor, Officer Doug, Captain Barnacle, a Security Bot and the Yeti.
Make it into the safe zone and your loot goes on display in your **Pocket Museum**, earning coins every second.
Upgrade your ray and your run speed, push further down the corridor (all the way to the Moon), rebirth,
complete the Index, and raid other museums in the endgame.

Everything is **server-authoritative**: the client only sends intent, and the server validates
cooldowns, charge time, range, Ray Power vs. object size, carry capacity, ownership and costs.

---

## 📁 File map (exact Studio locations)

`.server.lua` = **Script**, `.client.lua` = **LocalScript**, `.lua` = **ModuleScript**.
Names in Studio must match the file names (without the extensions).

| Studio location | Type | File |
|---|---|---|
| **ReplicatedStorage › Shared** | Folder | `src/ReplicatedStorage/Shared/` |
| ↳ Config › GameConfig | ModuleScript | `Config/GameConfig.lua`: global tuning, raid, sounds |
| ↳ Config › TierConfig | ModuleScript | `Config/TierConfig.lua`: 6 size tiers, areas, gate costs |
| ↳ Config › ObjectConfig | ModuleScript | `Config/ObjectConfig.lua`: every object + custom-object lookup |
| ↳ Config › RarityConfig | ModuleScript | `Config/RarityConfig.lua`: rarities + variants |
| ↳ Config › UpgradeConfig | ModuleScript | `Config/UpgradeConfig.lua`: upgrades, rebirth, token upgrades |
| ↳ Config › MonetizationConfig | ModuleScript | `Config/MonetizationConfig.lua`: 🔧 pass/product IDs, skins, gem shop |
| ↳ Config › RewardConfig | ModuleScript | `Config/RewardConfig.lua`: gifts, daily, index, likes, codes, Infinite Pack |
| ↳ Config › EventConfig | ModuleScript | `Config/EventConfig.lua`: rotating events, event objects |
| ↳ Config › ChaserConfig | ModuleScript | `Config/ChaserConfig.lua`: the 6 chasers (names, speeds, looks, lines) |
| ↳ Format | ModuleScript | `Format.lua`: 14.3k / 1.2M / 4.5B, timers |
| ↳ Formulas | ModuleScript | `Formulas.lua`: shared math (costs, stats, income) |
| ↳ RewardUtil | ModuleScript | `RewardUtil.lua`: reward descriptions + odds |
| ↳ InfinitePackGen | ModuleScript | `InfinitePackGen.lua`: deterministic endless tile chain |
| ↳ Remotes | ModuleScript | `Remotes.lua`: creates / finds all remotes |
| **ServerScriptService › Main** | Script | `src/ServerScriptService/Main.server.lua` |
| **ServerScriptService › Services** | Folder | `src/ServerScriptService/Services/` |
| ↳ SessionService, DataService, NetService, MapService, MonetizationService, EventService, EconomyService, MuseumService, IndexService, AreaService, SpawnService, ShrinkService, UpgradeService, RebirthService, RewardService, InfinitePackService, RaidService, LeaderboardService, CarryService, ModelFactory, MapDecor | ModuleScripts | one file each |
| **StarterPlayer › StarterPlayerScripts › ClientMain** | LocalScript | `src/StarterPlayerScripts/ClientMain.client.lua` |
| **StarterPlayer › StarterPlayerScripts › ClientModules** | Folder | `src/StarterPlayerScripts/ClientModules/` |
| ↳ State, UIKit, HUD, Effects, RayController, Prices | ModuleScripts | one file each |
| ↳ Menus › GiftsMenu, InfinitePackMenu, ShopMenu, IndexMenu, RebirthMenu, MuseumMenu, UpgradesMenu | ModuleScripts | one file each |
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
- [ ] **Server size ≤ 8** (Game Settings → Places → Server Fill / Max Players), because there are 8 museum plots.
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

### Optional: real art instead of placeholders
- [ ] **Object models**: put Models in **ServerStorage › ShrinkableTemplates** (create the folder), each **named
      exactly like its ObjectConfig id** (e.g. `FerrisWheel`, `SodaCan`, `TheMoon`). Set a PrimaryPart. The game
      anchors them, removes scripts, places them on the ground, and scales them down for museum display.
      Objects without a template get an auto-generated colored placeholder.
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

## 🎮 Feature overview

| Feature | Where |
|---|---|
| Hold-to-charge Shrink Ray, beam, squash + fly-to-pocket tween, pop sound, particles | `RayController`, `Effects`, `ShrinkService` |
| "TOO BIG!" popup + charge bar near the crosshair + hover info | `HUD`, `RayController` |
| One long walled corridor: base (safe zone) → 6 themed zones, each longer than the last; no gates or fees | `MapService`, `MapDecor`, `TierConfig` |
| Carry loop: shrunk objects stack above your head; run them back to base to put them on display | `CarryService` |
| Chasers: each zone's owner chases you when you grab something; get caught = drop everything | `CarryService`, `ChaserConfig` |
| Rarities, variants (Golden x5, Diamond x10, Rainbow x25, Cosmic x100) with glow; luck-weighted rolls | `RarityConfig`, `SpawnService`, `ModelFactory` |
| Event objects with server-wide announcement | `EventService`, `SpawnService` |
| Pocket Museum: plots, pedestals, glass cases, "+$" floating text | `MuseumService`, `Effects` |
| Upgrades: Ray Power, Run Speed, Carry Capacity, Charge Speed, Range, Luck, Museum Size | `UpgradeConfig`, `UpgradeService` |
| Rebirth (multiplier, Gems, Tokens) + permanent Token upgrades | `RebirthService` |
| The Index with per-area completion rewards (Normal set + full variant set) | `IndexService`, `IndexMenu` |
| Museum Raids (opt-in, max Ray Power, copies only, shield, revenge window + bonus) | `RaidService` |
| Free playtime gifts (12, session-based, Huge chance on the last ones) | `RewardService`, `GiftsMenu` |
| Infinite Pack (endless, FREE/R$ pattern, refresh timer, preview row, odds display) | `InfinitePackGen`, `InfinitePackService`, `InfinitePackMenu` |
| 15 Gamepasses, 11 Developer Products + 3 pack tiers, idempotent `ProcessReceipt` | `MonetizationService` |
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
