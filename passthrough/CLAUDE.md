# RDR2 x Minecraft passthrough mod

## Goal

Play Red Dead Redemption 2 (story mode) with Minecraft gameplay inside it: place and
break Minecraft blocks in the RDR2 world, carry a Minecraft hotbar and inventory, and
later see Minecraft blocks, items and mobs rendered properly in RDR2's frame.

This is a **passthrough mod**. Two real games run at the same time on this Windows PC:

- **RDR2 is the host.** It renders everything the player sees and owns the camera,
  movement, horse, NPCs and terrain.
- **Minecraft Java Edition is the hidden gameplay engine.** It runs with its window
  hidden or minimized and owns block state, inventory, crafting and Minecraft mobs.
- **A bridge connects them.** An ASI plugin inside RDR2 and a Fabric mod inside
  Minecraft exchange state every frame, over shared memory by the end.

The person you're working with owns both games on this PC and is new to modding.
Explain in plain words, keep steps small, and ask them to playtest after every
milestone. They describe what they see; ask for screenshots when something looks wrong.

## Hard rules

- **Story mode and offline only.** Never connect to Red Dead Online with any of these
  files installed; Rockstar bans for modded Online play. ScriptHookRDR2 closes the game
  if you go online, but don't rely on that. Tell the player this before the first launch.
- **Only add files to the RDR2 folder; never edit or replace the game's own files.**
  Before the first install, list every file you add (script hook DLL, ASI loader, our
  `.asi`) in `INSTALLED_FILES.md` so they can all be removed cleanly.
- **Back up RDR2 save games** before the first modded launch.
- **Never commit game files**, game binaries, decompiled game code or downloaded
  third-party binaries to this repo. Only our own source code and docs go in git.
- **Downloads of the script hook come from their official pages.** Have the player
  download them in their browser if a site blocks scripted downloads.
- **Keep `STATUS.md` current.** Update it at the end of every session: what works, what
  is broken, the exact game and tool versions, and the next step. Read it first in
  every new session.

## Toolchain (confirm versions on this PC before using them)

- **RDR2 side:** C++ ASI plugin built with Visual Studio 2022 (or its Build Tools), x64,
  against the ScriptHookRDR2 SDK (`natives.h`, `main.h`). Script hook options:
  Alexander Blade's ScriptHookRDR2 (dev-c.com) or the community ScriptHookRDR2 V2, which
  keeps the same API. Pick whichever supports the installed game build, and record the
  build in `STATUS.md`. An ASI loader (`dinput8.dll` ships with the script hook) loads
  the plugin. Look native names and hashes up in the SDK headers or a natives database.
  Don't guess them.
- **Minecraft side:** a Fabric mod (Fabric Loader + Fabric API, Loom/Gradle) for one
  pinned Minecraft Java version, using the JDK that version requires (Java 21 for
  1.21.x). Use a dedicated world for the link (superflat or void) so terrain doesn't
  fight with RDR2's.
- **Bridge:** a named shared-memory block (`CreateFileMapping`/`MapViewOfFile` on the
  C++ side; JNA or Java's Foreign Function & Memory API on the Java side) with a
  versioned header and a sequence counter so readers never see half-written data.
  A localhost socket is fine for milestone 1 if that is faster to get working, but move
  to shared memory before rendering work.

## Coordinates

RDR2 is Z-up in meters; Minecraft is Y-up with 1 block = 1 meter. Start with
`mc.x = rdr.x`, `mc.y = rdr.z + OFFSET`, `mc.z = -rdr.y`, and keep the mapping in one
function on each side. Minecraft's world height is limited, so choose `OFFSET` (and
possibly a horizontal recentering origin) from the player's actual RDR2 heights.
Record whatever you settle on in `STATUS.md`.

## Milestones (finish and playtest each before starting the next)

0. **Setup.** Confirm the RDR2 build, install the script hook and ASI loader, and get a
   minimal "hello" ASI to draw text on screen in story mode. Separately, get a minimal
   Fabric mod to log a message. Back up saves. Write `INSTALLED_FILES.md`.
1. **The link.** Launch both games. RDR2 shows "Minecraft linked" plus live data from
   Minecraft (world time, block under the mirrored player). The hidden Minecraft player
   follows the RDR2 player's position and look direction. Disconnects are handled
   cleanly on both sides, and either game can be closed first without crashing the other.
2. **Place and break blocks.** A Minecraft-style hotbar overlay in RDR2. Raycast from
   the RDR2 camera; placing or breaking sends a request to Minecraft, which applies it
   to its world and streams back the block changes near the player. RDR2 shows those
   blocks with the simplest method that works reliably (debug-drawn boxes or spawned
   props). Blocks must be solid enough to stand on if possible, or note why not.
3. **Minecraft gameplay.** Inventory and crafting backed by the real Minecraft
   inventory, mining drops, day/night synced between the two clocks, then Minecraft
   mobs mirrored into RDR2.
4. **Real rendering.** Render Minecraft's view of the same camera offscreen and
   composite it into RDR2's frame using depth, so textured blocks and mobs sit correctly
   behind and in front of RDR2 geometry. This is the hardest part: research how RDR2's
   renderer (Vulkan or DirectX 12) can be hooked before writing code, and keep the
   simple milestone-2 drawing as a fallback toggle.
5. **Polish.** Performance (both games at once is heavy), a config file, an in-game
   toggle, and a short install guide for other players.

## Working style

- Small steps, each with a build, an install, and a playtest the player can do in a
  few minutes.
- Log generously on both sides (one log file per side, timestamped) so problems can be
  found from logs instead of guesses.
- When something crashes, read the logs and the script hook's own log before changing
  code.
