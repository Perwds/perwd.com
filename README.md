# Fishing RNG

A Roblox fishing RNG game. Cast, fight the fish on a reel bar, and roll against
two independent rarity ladders — an eight-tier fish table and an eight-tier
mutation table on top of it. Sell what you catch, buy better rods, unlock deeper
zones, and chase a 1-in-a-million Glitched catch.

Everything is source. The whole world, UI, and economy are built at runtime from
the modules in `src/`, so the repo syncs into an empty baseplate and runs.

---

## ⚠️ About API keys

**This repository is public. No Roblox API key is stored in it, and none ever
should be.**

`scripts/publish.mjs` reads credentials from the environment or from a local
`.env`, which `.gitignore` excludes. Copy `.env.example` to `.env` on your own
machine and fill it in there.

If a key has been pasted into a chat, an issue, a commit, a screenshot, or a log,
treat it as burned: delete it at
[create.roblox.com/dashboard/credentials](https://create.roblox.com/dashboard/credentials)
and issue a new one. Scope a new key to **Universe Places → write** for this
experience only, and set an IP allowlist if you can.

---

## Running it

```bash
aftman install                    # rojo, selene, stylua
rojo serve                        # then connect from Roblox Studio
```

Sync into a new baseplate and press Play. There is nothing to place by hand —
the server builds the map, the remotes, and the UI on boot.

To publish:

```bash
cp .env.example .env              # then fill in your own credentials
node scripts/publish.mjs          # build + publish live
node scripts/publish.mjs --saved  # build + save a version without going live
```

Publishing needs an existing experience. Open Cloud updates a place, it cannot
create one — make the experience once in Studio or on the creator dashboard, then
take its universe and place ids from the URL.

---

## The game

**Fish** roll on eight tiers, from Common (1 in 2) to Secret (1 in 1,000,000).
**Mutations** roll separately on their own eight tiers, from none through Shiny,
Golden, Void, Celestial and Glitched. A Glitched Minnow is worth more than almost
anything in the deepest zone, which is the point.

**Luck** is `rod × zone × level` and bends the tail of both tables without ever
helping Common, so more luck always means a better roll.

**Six zones**, each with its own fish, bite timing, water, and fog:

| Zone | Unlocks at | Zone luck |
| --- | --- | --- |
| Starter Pond | — | ×1.00 |
| Coral Reef | 2.5K lifetime | ×1.15 |
| Frostbite Lake | 25K | ×1.35 |
| Volcanic Depths | 150K | ×1.70 |
| The Abyss | 1.5M | ×2.40 |
| Celestial Rift | 6M | ×3.50 |

**Seven rods**, from the starter Wooden Rod to the Eventide Rod at ×7 luck. A
better rod widens your catch bar, fills it faster, drains it slower, and gets
bites sooner.

Progression, measured by the simulation in `tests/`:

```
pond  -> reef      ~56 catches
reef  -> frost     ~317 catches
frost -> volcano   ~1,451 catches
volcano -> abyss   ~4,465 catches
abyss -> rift      ~12,634 catches
```

---

## Graphics

Everything is built at runtime from config; no uploaded meshes, textures or
image assets, so the whole look lives in source.

**World.** Six islands sculpted out of real Roblox terrain — genuine terrain
water (refractive, animated, raycastable), organic coastlines built from
overlapping fills rather than cylinders, plank piers with pilings, railings and
lit lanterns, and per-zone dressing: trees, boulders, ice spikes, obsidian,
coral fans, and floating crystal shards in the Rift.

**Lighting.** The place runs `Future` lighting for real shadows and light
bleeding. Each zone then drives its own full stack, tweened on arrival:
`Atmosphere` density and haze, `Clouds` cover, bloom, sun rays, colour grading,
depth of field, clock time, exposure, and Terrain water colour, transparency,
reflectance and wave settings.

All of it is written client-side. Lighting and Terrain property writes are local
to a client, which is what lets two players standing in different zones each see
their own world — so the Abyss can be near-black with a 34-stud focus distance
while someone else is in bright tropical shallows.

**Feel.** A rod you actually hold, coloured by the one you have equipped, with a
sagging `Beam` fishing line that snaps taut when a fish bites. Splashes,
spreading ripples, a bobber that twitches on the hook. Catch effects scale with
how rare the catch was: a Common is a small plink, a Secret gets a particle
burst, a shaft of light, a screen flash, a colour-graded punch and an FOV kick.
Per-zone ambient particles — pollen, snow, embers, drifting motes, rift sparks.

**The fish.** Every species is a real model, built procedurally at runtime from
its own colour and one of eight silhouette archetypes — round, long, flat, bulb,
orb, crab, squid, seahorse — so 55 recognisable fish cost no uploaded meshes.
Mutations repaint the whole fish rather than tinting it: Golden turns it to gold
metal, Void makes it something that should not exist, and the glowing tiers cast
real light. Catch weight scales the model on a log curve, so a 50g Minnow and a
40-tonne God of Still Water can share a screen.

You see one on the catch card, turning slowly in a ViewportFrame; in the Fish
Index, which is the bestiary and so the place that question gets asked; and held
over your head for a few seconds after you land it, which is server-side, so
everyone on the pier sees what you pulled out. The bag deliberately has no
icons — it holds up to 250 entries and is a sell-list, not a gallery.

`preview/species.svg` is a contact sheet of the whole roster, generated by
`scripts/build_species_sheet.mjs` from the same silhouette builders.

**Interface.** Glass surfaces with vertical gradients and graded hairline
strokes, rarity-tinted panels, glow on the numbers that matter, and a catch card
that reacts to the tier it is showing. The reel bar tightens and glows when you
are on the fish and loosens when you are losing it.

The interface is authored in fixed pixels against 1280x720 and then scaled per
viewport by `GameConfig.HudScale`, because most Roblox players are on a phone.
Scaling down proportionally would leave 11px labels unreadable on a dense
screen, so small viewports stay near the authored size and touch devices get a
deliberate bump — then the result is capped so the reel bar and the panel, the
two largest fixed elements, always fit. `HudScale` is attached per panel rather
than to one full-screen container: a `UIScale` scales the object it sits on, so
one wrapper would shrink the wrapper and pull edge-anchored panels off the
screen edges.

| Viewport | HUD | Reel bar | Smallest label |
| --- | --- | --- | --- |
| 1920x1080 | 1.20x | 466px | 13.2px |
| 1280x720 | 1.00x | 388px | 11.0px |
| 1180x820 touch | 1.15x | 447px | 12.7px |
| 896x414 touch | 0.85x | 329px | 9.3px |
| 667x375 touch | 0.76x | 296px | 8.4px |

That table is printed by the test suite, which asserts both large elements fit
and no label drops below 7px on every viewport listed.

### Seeing it without Studio

`preview/` is a browser reproduction of the HUD, reel minigame and catch cards at
the exact pixel sizes the Luau builds them, with a canvas approximation of each
zone's grading. It is generated from the game's own config, so the odds, luck
maths and coin values on it are the real ones:

```bash
python3 scripts/build_preview.py      # -> preview/index.html
```

Its screen picker runs the same `HudScale` maths as the game, so choosing a
phone shows what a phone actually gets; a test asserts the two implementations
agree on every viewport.

It is an approximation of the scene, not a render of it — the game itself uses
terrain water, Future lighting and real post-processing, which a canvas can
suggest but not match.

---

## Layout

```
src/shared/          replicated to both sides
  Config/            all game data: fish, rarities, mutations, rods, zones,
                     per-zone visuals, tuning
  Util/              formatting and weighted rolling
  CatchRoll.luau     the catch roll, kept pure so tests can drive it
  FishModel.luau     procedural fish geometry, one builder per archetype
  Net.luau           remote definitions; built by the server, awaited by the client

src/server/
  Services/          data, fishing, economy, leaderboards, profile view
  World/             terrain sculpting, props, the holdable rod, the trophy pose

src/client/
  UI/                theme, widgets, HUD, reel minigame, panels, fish viewports
  Effects/           lighting and post-processing, tackle, catch effects
  Controllers/       casting input

tests/               runs the shared modules outside Roblox
preview/             browser reproduction of the UI, plus the species sheet
scripts/             config export, preview and sheet builds, Open Cloud publish
```

### How a catch works

1. Client raycasts the mouse onto tagged water and asks the server to cast.
2. Server checks cooldown, distance, and that the point is inside the player's
   current zone.
3. After a zone-and-rod dependent delay, **the server rolls the catch** and holds
   it. It tells the client only the minigame parameters.
4. Client plays the reel bar and reports won or lost.
5. Server checks the elapsed time is physically possible for the equipped rod,
   then awards the fish it already rolled.

The client never learns what it caught until it has caught it, and cannot change
the outcome. `GameConfig.MinReelSeconds` is the floor on a claimed win; a test
asserts it stays below what the fastest rod can legitimately do, so the
anti-cheat can never start rejecting honest players.

---

## Tests

The shared modules are free of Roblox services, so they run under the plain
[Luau CLI](https://github.com/luau-lang/luau/releases) against a small stub:

```bash
python3 tests/run_tests.py --luau /path/to/luau
```

249 assertions covering the roster, that each zone's effective odds sum to
exactly 1, that luck moves the tail the right way, a 300,000-sample check that
the empirical roll distribution matches the published odds, number formatting,
the level curve, the reel-timing anti-cheat margin, completeness of every zone's
visual profile, HUD scaling across seven real device viewports, the geometry of
all 440 fish models (every species in every mutation: nothing degenerate,
infinite, collapsed or flung off the body), and a 40,000-sample economy
simulation asserting every zone out-earns the last and no
unlock is a wall.

The balance table in this README is printed by that simulation.
