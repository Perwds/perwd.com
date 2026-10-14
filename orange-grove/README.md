# Orange Grove

An upgrade-tree incremental game for Roblox. You run an orange operation on a board floating in space: pick oranges, walk the upgrade tree laid out on the floor, open new zones, and earn five currencies in turn (Oranges, Vitamin C, Zest, Juice Crates, Golden Seeds).

Written in Luau and synced into Studio with [Rojo](https://rojo.space).

## Getting started

Install the tools (any of these routes works):

```sh
# with Rokit or Aftman
rokit add rojo-rbx/rojo && rokit add Kampfkarren/selene && rokit add JohnnyMorganz/StyLua && rokit add lune-org/lune
# or with Cargo
cargo install rojo selene lune && cargo install stylua --features luau
```

Then:

```sh
rojo serve                      # live-sync into an open Studio place (Rojo plugin required)
rojo build -o OrangeGrove.rbxl  # or build a place file and open it
```

In Studio, open **Game Settings > Security** and turn on **Enable Studio Access to API Services** so saving works in playtests. Without it the game still runs; it just warns once that progress won't persist.

`Lighting.Technology = Future` and `Workspace.StreamingEnabled = false` are set in `default.project.json` (scripts can't set Technology). Everything else (board, lighting, sky, remotes) is built by the server when it starts. There's no Terrain, baseplate or default skybox.

## Filling in IDs

Nothing paid or uploaded is invented. Everything starts empty, and the game works without it.

| What | Where | If left empty |
|---|---|---|
| Game passes and developer products | `src/server/Monetization.lua` (`id = 0`) | The item is hidden. With all of them at 0 there's no Shop button, no VIP gate and no pink zone. |
| NPC looks (keeper, juice worker, farmhands) | `Config.Npc` in `src/shared/Config.lua`: Roblox user IDs, or outfits made only of real catalog asset IDs | NPCs use the default Roblox avatar and the server prints one warning. |
| Music, pick pop, chime, deny, replant sounds | `Config.Sounds` (IDs from the Creator Store, creator "Roblox") | That sound is silent. |
| Currency and button icons | `Config.Icons` (`rbxassetid://...`) | A plain one-colour shape is drawn instead. |

The NPC animations are the stock R15 ones from Roblox's default `Animate` script (`Config.Animations`).

## Publishing

1. `rojo build -o OrangeGrove.rbxl`, open it in Studio, then **File > Publish to Roblox**.
2. Create the game passes and developer products on the Creator Dashboard, paste their IDs into `Monetization.lua`, rebuild and publish again.
3. Under **Avatar** settings leave the defaults (R15, player's own avatar). The game never replaces player characters.

## Layout

```
default.project.json        Rojo tree for the game
test.project.json           Same game plus tools/studio/ExploitTest.client.lua
src/server/
  init.server.lua           boot: lighting, remotes, board, services, player join
  Remotes.lua               the Remotes folder, argument type checks, per-request flood limits
  Data.lua                  saves with a session lock inside the record (UpdateAsync), autosave, BindToClose, migrations
  Currency.lua              the only writer of balances; rates; State snapshots to each client
  UpgradeService.lua        buying nodes, cached stats per player, walk speed
  GroveService.lua          per-player tree ripeness, pick validation, auto-collect
  Production.lua            Lab, Zester, Juice Bar and picker ticks; offline catch-up
  Prestige.lua              Replant the Grove; the walk home from the Golden Tree
  Monetization.lua          passes, products, idempotent ProcessReceipt
  NpcService.lua            avatar NPCs from HumanoidDescriptions, pathing pickers
  ZoneService.lua           server backstop for locked zones; keeper first-visit lines
  BoardBuilder.lua          zones, borders, barriers, plates, paths, machine screens, trees
  Landmarks.lua             the big set pieces in each zone
  RateLimit.lua             token bucket
src/client/
  init.client.lua           wiring, notices, VIP chat tag
  State.lua                 latest server snapshot
  Hud.lua                   bottom currency bar, side buttons, toasts, guide line, dialogs
  TreeBoard.lua             plate states, hover lift and tooltip, buying, path pulse and draw-in
  Orchard.lua               this player's oranges on each tree, pick input
  PickFx.lua                arc into the basket, peel burst, pop, floating numbers
  Machines.lua              machine screens and controls, zone dimming, barriers, moving parts
  OverviewCam.lua           top-down board map (M, D-pad up, or the Map button)
  ShopUi.lua                optional shop (Shop button, D-pad right, or the VIP gate)
  Settings.lua              music, sounds, reduce motion, number style (D-pad left)
  Guide.lua                 one arrow and one line at a time; keeper lines
  Audio.lua, Ui.lua         sound and UI helpers
src/shared/
  UpgradeTree.lua           all 43 nodes: name, effect, cost curve, parents, board cell
  Economy.lua               stats, costs, node states, production step, seeds (shared with the sim)
  Config.lua                tuning, zone layout, NPC/sound/icon IDs, dialogue
  Palette.lua               every colour
  Format.lua                1.41K / 3.4M / 5.6B / 1.00e12, or 1,410
tools/
  simulate.lua              greedy pacing simulation
  checkboard.lua            plate/path/set-piece overlap and tree-shape check
  test.lua                  unit checks for the shared modules
  studio/ExploitTest.client.lua   fires every remote with bad input in a playtest
```

### How it fits together

- **The server owns everything.** Clients send only requests: `PickOrange(treeId)`, `BuyNode(nodeId)`, `ToggleMachine(id)`, `Replant()`, `GoHome()`, `SaveSettings(t)`, `TutorialStep(n)`, `RequestSync()`. Each is type-checked and flood-limited in `Remotes.lua` before any service sees it. Picks are also checked for distance (18 studs) and ripeness and capped at 12 per second. Buys are checked for distance to the plate, parents and cost.
- **Every player has their own grove.** Tree ripeness, plate colours, path glow, zone dimming and barriers are per player. The server tracks ripeness and sends timestamps. The client draws the fruit and colours the shared board locally. Locked-zone barriers collide on the client, and `ZoneService` walks anyone who slips through back out.
- **The board is data.** `BoardBuilder` reads `UpgradeTree.lua` at startup and lays a plate at each node's `gx, gy` cell and a right-angled path to each parent. Moving a node is a one-line edit. Run `lune run tools/checkboard.lua` afterwards to catch overlaps.
- **Saving.** One record per player with a `lock = { job, t }` field, written only through `UpdateAsync`. A server refuses a record another live server holds. A lock not refreshed for 150 s is treated as abandoned. Autosave runs every 60 s, plus on leave and on shutdown. `version` and `Data.migrate` handle future changes.
- **Receipts.** A product is granted, its `PurchaseId` is stored in the save, and `PurchaseGranted` is only returned once that save succeeds. A retried receipt whose ID is already recorded just re-confirms the save.

## The tree

43 nodes across five branches off the **Orange Seed** in the Orange Grove. The branches run Orange Grove (west) > Vitamin Lab (north) > Zest Works (east) > Juice Bar (east) > Golden Tree. They cross-link in two places: **Fine Grater** needs **Bigger Beakers** from the Lab, and **Fresh Squeezed Fame** needs **Marmalade Mondays** from the grove.

- Grey plate: locked, text dimmed. `???`: more than one step past what you own.
- Zone-coloured plate: available. A glowing edge means you can afford it right now.
- Bright plate with a neon path: owned. A spark runs down the path when you buy it.
- Gold ring: permanent (costs Golden Seeds, survives Replant).

Costs are `base * growth ^ level`, with growth between 1.3 and 1.6.

## Pacing

`lune run tools/simulate.lua` plays the tree greedily: about 2 hand picks per second, all machines running, always buying the cheapest affordable node. Add `--log` to see each purchase.

```
Orange Grove pacing (greedy, 2 hand picks/s)
--------------------------------------------------------
Lab opens          0:03:45   target 0:03:00 - 0:05:00   ok
Zester opens       0:14:01   target 0:12:00 - 0:18:00   ok
Juice Bar opens    0:40:05   target 0:34:00 - 0:46:00   ok
First Replant      2:21:01   target 2:00:00 - 3:00:00   ok
--------------------------------------------------------
Golden Seeds on first Replant: 6
Nodes bought: 34
```

Slower (1.5 picks/s) and faster (2.5 picks/s) players also land inside every target: the Lab opens at 4:21 and 3:20, the Juice Bar at 40:41 and 39:40, and the first Replant at 2:21:37 and 2:20:36.

## Checks

```sh
rojo build -o OrangeGrove.rbxl
selene generate-roblox-std     # once, writes roblox.yml
selene src tools
stylua --check src tools
lune run tools/test.lua
lune run tools/checkboard.lua
lune run tools/simulate.lua
```

In Studio, build `test.project.json` and Play Solo. The exploit test fires every remote with wrong types, NaN and infinity, oversized strings, far-away trees, a VIP tree without the pass, locked and unaffordable nodes, and 300 rapid repeats. It then prints PASS or FAIL for each thing that must not have changed.

### Studio playtest checklist

These need Studio (Play Solo, then a 2-player local server):

- [ ] Picking works by click, tap, prompt (E or X) and R2.
- [ ] Plates and paths match `UpgradeTree.lua`. Bought paths glow and the spark runs along them.
- [ ] Every node can be bought in order, and each zone unlocks: its screen flickers on and the keeper speaks the first time you walk in.
- [ ] Buy Lab Runs Overnight, leave for a few minutes, rejoin: the welcome-back card shows offline gains.
- [ ] Replant resets currencies and normal nodes and keeps gold-ringed nodes, the Golden Tree and anything Seed Memory or Long Memory keeps. Walk home works from the Golden Tree screen.
- [ ] Leave and rejoin: all progress is still there.
- [ ] With every monetization ID at 0: no Shop button, no VIP gate, no pink zone, and the game is playable to the first Replant.
- [ ] With an empty `Config.Npc`: NPCs are default avatars with exactly one warning in the output.
