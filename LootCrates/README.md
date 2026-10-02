# LootCrates

Paper plugin for placeable loot crates with keys, holograms, opening animations,
daily rewards and history. Source recovered from the released `LootCrates-1.0.0.jar`.

## Building

```sh
mvn package
```

The jar is written to `target/LootCrates-<version>.jar` (needs Java 21 and access to
`repo.papermc.io` for `paper-api`).

## Changelog

### 1.0.1

Reported bugs:

- **`&r` shown in the "You won" message.** The reward text (`<reward> &rx<amount>`) was
  inserted after the message had already been colorized, so `&r` was never translated.
  The amount now continues in the message's own color/style instead (also in the
  broadcast and `/lootcrate history`).
- **Pressing Esc during an opening lost the reward** (the key was already used up).
  Closing the GUI early now skips the animation and gives the reward right away. The
  reward is also given if the player disconnects, the server shuts down mid-opening,
  another plugin blocks the GUI from opening, or an animation errors.
- **Hologram armor stands multiplied** (one floating copy plus frozen copies that had to
  be killed). The stands were saved into the world, so after a chunk reload or restart
  the plugin lost track of the saved copies and spawned new ones on top. Hologram stands
  are now never saved: they despawn with their chunk and respawn when it loads.
  Leftover stands from 1.0.0 are removed automatically when their chunk loads.

Also fixed:

- `DRAGON_BREATH` (Epic crate hologram, Dragon animation) needs extra particle data on
  newer Minecraft versions; spawning it threw an error every few ticks and froze the
  Dragon animation so it never paid out. Particles that need data now get it.
- Crate/key names showed raw `&` codes in the no-key, crate-received and key-received
  messages.
- Rewards and given items were deleted when the inventory had no free slot but the item
  didn't fully stack (only checked for an empty slot); leftovers are now dropped.
  `/lootcrate daily` could delete the key when only one slot was free.
- GUI borders were always white: the crate color was matched against
  `Color.toString()`, which never contains color names.
- Clicks were cancelled in *any* inventory whose title contained "- Wave", "- Dragon",
  "Opening..." etc. Animation GUIs are now recognised by the GUI itself.
- Daily cooldowns and history were only saved on a clean shutdown, so a crash let
  everyone claim their daily reward again. They are now saved on claim / every 5 minutes.
- The daily reward ignored `daily-reward.reward-tier` from the shipped config (the code
  read `reward-crate`). Both keys work now; the default config uses `reward-crate`.
- Explosions destroyed crate blocks but left the hologram and the crate registration.
- Deleting a crate in the editor left its holograms behind.
- Crates in worlds loaded after the plugin (e.g. by Multiverse) were dropped from
  `crate_locations.yml` the next time it was saved.
- `/lcadmin reload` didn't update placed holograms.
- Placing a crate where another plugin cancelled the placement still registered a crate.
- Hologram particles ran even with no players nearby (the "anyone nearby" check always
  found the hologram's own armor stands).
- `settings.animation-enabled`, `settings.particles-enabled` and `auto-close-delay: -1`
  had no effect; `animation-speed: 0` froze animations.
- Creating a crate whose name had no letters/digits produced an empty crate ID.
- History entries whose reward name contained `;` were dropped on load.
- Leaving the server mid-rename kept the chat prompt active after rejoining.
