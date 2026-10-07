# 🍊 Orange

**Vanilla gameplay, as fast as it can go.** Orange is a performance layer that runs *on top of*
the server you already use (Paper, Purpur, Pufferfish, Leaf, Leaves, Spigot, Fabric or vanilla).
By default it **undoes the vanilla changes Paper and Spigot make** (piston duping, headless
pistons, bedrock breaking, frozen far-away mobs, item merging...) and only adds optimizations
that don't change gameplay.
Because the real server still runs underneath, **every plugin that works on your server keeps
working**, and you get each new Minecraft version the day your server software supports it.

```
java -jar orange.jar
```

## What it does

| Layer | What you get |
|---|---|
| **Launcher** (`orange.jar`) | Starts your server with tuned JVM flags: [Aikar's G1 flags](https://docs.papermc.io/paper/aikars-flags) or generational ZGC, picked for your heap size. On Java 25+ it adds compact object headers (a smaller heap and less GC work), and transparent huge pages when the kernel supports them. Sizes the heap from your RAM (container-aware), sets `-Xms = -Xmx`, adds the SIMD Vector API for Pufferfish-based forks, optionally restarts after crashes, and shuts the server down cleanly on Ctrl+C or SIGTERM. |
| **Config optimizer** | Edits `server.properties`, `bukkit.yml`, `spigot.yml`, `config/paper-global.yml`, `config/paper-world-defaults.yml`, `purpur.yml` and `pufferfish.yml` for the profile you pick (below). It keeps comments, backs every file up to `.orange/backups/`, only changes keys that already exist, and applies each profile **once** so your later edits stick. |
| **Orange plugin** (auto-installed) | **`/orange pregen <world> <radius>`**: generates the world ahead of time. Chunk generation is the biggest single source of lag, and pre-generating changes nothing about the world. It spirals out from spawn and pauses while the server is busy. **TPS governor**: lowers *view* distance while MSPT is above 45 and puts it back when the server recovers. **High-ping helper**: tracks every player's ping and jitter (`/orange ping`). When a player's ping stays above 250 ms, it sends them fewer chunks so their connection has room for movement and combat updates. It restores them when their ping recovers, and the world simulates exactly as before. **`/orange status`**: TPS, MSPT, memory, chunks and entities per world. The entity limiter and the simulation-distance governor change gameplay, so they're **off by default**. |
| **Orange mods** (agent) | Fabric-style bytecode patches (ASM) loaded from `orange-mods/`, on any server software. Also brands the server as `Orange (Paper)` in the server list and F3. |

### Profiles

Set `optimization-profile` in `orange.yml`:

- **`vanilla`** (default): 100% vanilla gameplay.
  - *Restores vanilla:* piston/TNT/carpet/rail duplication, headless pistons, bedrock breaking,
    unsafe end portal teleports, tripwire tricks, grindstone overstacking, overstacked loot,
    pearls in unloaded chunks, player cramming damage, unlimited entity collision checks, hopper
    timing, vanilla redstone, vanilla mob caps, and **no entity activation range** (Spigot freezes
    far-away mobs, which breaks farms). On Pufferfish-based forks it also turns off DAB and goal
    throttling, which slow down far-away mob AI.
  - *Optimizes (no gameplay effect):* async chunk writes, auto-saves spread over more ticks,
    tuned JVM/GC, the Purpur alternate keepalive, plus everything Paper does internally that
    doesn't change behaviour (its chunk system, lighting engine and so on).
- **`balanced`**: big TPS wins with changes most players won't notice: lower spawn caps, entity
  activation range, bigger item/XP merging, view distance 8 / simulation distance 6. Some farms
  get slower.
- **`aggressive`**: maximum TPS. This **changes vanilla mechanics**: Alternate Current redstone,
  mobs from spawners have no AI, armor stands don't tick, Purpur villager lobotomizing,
  Pufferfish DAB, view distance 7 / simulation distance 4.
- **`off`**: leave my configs alone.

### High-ping players

Set `ping-tolerance` in `orange.yml`:

- **`normal`** (default): vanilla thresholds. On Purpur-based servers it also turns on the
  alternate keepalive (one ping per second, timeout only after 30 s of silence), which stops
  "Timed out" kicks on lossy Wi-Fi and mobile connections.
- **`high`**: also raises the "moved too quickly/wrongly" thresholds, so laggy players get far
  fewer rubber-band snaps, and doubles Paper's packet limit so the burst of packets that
  arrives after a lag spike isn't kicked as spam. This relaxes the server's own movement
  checks a little. Anti-cheat plugins still run their own.

The biggest ping win isn't software, though: host the server close to your players, and keep it
at 20 TPS. Every millisecond a tick runs over 50 ms adds to *everyone's* ping.

> **The honest trade-off:** most of what config tuning can do (activation range, spawn caps,
> merge radius) works by *changing* the game. `vanilla` refuses all of that, so its speed comes
> from the JVM, I/O, Paper's behaviour-neutral internals, pre-generation and the view-distance
> governor. Going faster while staying exactly vanilla takes code-level optimizations, the way
> Lithium does it. That's the next step on the [roadmap](#roadmap).

## Quick start

1. Download your server jar (for example [Paper](https://papermc.io/downloads/paper) or
   [Purpur](https://purpurmc.org/downloads)) and put it in a folder with `orange.jar`.
2. Run `java -jar orange.jar`. It creates `orange.yml`, detects the server jar, and starts it.
3. The server creates its config files on the first start. **Restart once** and Orange tunes them.

4. Pre-generate the world (in-game or from the console):
   ```
   /orange pregen world 5000
   /orange pregen world_nether 2000
   /orange pregen world_the_end 2000
   ```

Check what Orange would change and run, without changing anything or starting the server:

```
java -jar orange.jar --dry-run
```

### Which server should I put under Orange?

- **Vanilla gameplay with plugins (the Orange default):** **Paper** works well. **Leaves** is
  even better: it's a Paper fork built to restore vanilla mechanics in code (update suppression
  and more) that config can't reach.
- **Strictly vanilla, no plugins needed:** Fabric + **Lithium**, FerriteCore, ScalableLux and
  C2ME. Lithium optimizes without changing any behaviour, which makes this the gold standard for
  vanilla parity. Orange's launcher and agent work on Fabric too.
- **Big servers that accept small gameplay changes:** Pufferfish or Leaf with `balanced` (Orange
  adds the SIMD flag they need automatically).
- **Folia / Canvas:** the launcher and agent work. The plugin skips itself because it isn't
  region-thread-safe yet.
- **Fabric:** the launcher and agent work. Pair it with Lithium, FerriteCore and C2ME for the
  best modded performance.
- **Forge / NeoForge:** these start from `run.sh` rather than a jar. Add
  `-javaagent:orange.jar` to `user_jvm_args.txt` to get Orange mods, and copy the flags from
  `java -jar orange.jar --dry-run`.

## orange.yml

```yaml
server-jar: auto                 # or a file name
memory: auto                     # e.g. 8G
gc: auto                         # auto | g1 | zgc
optimization-profile: vanilla    # vanilla | balanced | aggressive | off
ping-tolerance: normal           # normal | high
install-plugin: true
agent: true
auto-restart: false
server-args: [nogui]
extra-jvm-args: []
```

The plugin's settings are in `plugins/Orange/config.yml` (`/orange reload` applies them).

## Writing an Orange mod

An Orange mod is a jar in `orange-mods/` with an `orange.mod.properties` file:

```properties
id=example-mod
name=Example Mod
version=1.0.0
entrypoint=com.example.orangemod.ExampleMod     # optional, implements OrangeMod
patches=com.example.orangemod.StopHookPatch     # optional, implement OrangePatch
```

Patches receive the ASM `ClassNode` of their target class as it loads:

```java
public final class StopHookPatch implements OrangePatch {
    public String id() { return "example-mod:stop-hook"; }
    public Set<String> targets() { return Set.of("net.minecraft.server.MinecraftServer"); }

    public boolean apply(ClassNode node) {
        MethodNode m = Patches.method(node, "stopServer", "()V");
        if (m == null) return false;               // fail soft on other versions
        InsnList code = new InsnList();
        code.add(new LdcInsnNode("example:server-stopping"));
        code.add(new VarInsnNode(Opcodes.ALOAD, 0));
        code.add(new MethodInsnNode(Opcodes.INVOKESTATIC, "com/perwd/orange/hooks/OrangeHooks",
                "event", "(Ljava/lang/String;Ljava/lang/Object;)V", false));
        Patches.injectHead(m, code);
        return true;
    }
}
```

Patched code can call `com.perwd.orange.hooks.OrangeHooks`. It sits on the bootstrap class path,
so it's reachable from any server's class loader. See [`examples/example-mod`](examples/example-mod).

**Names:** patches target the names the server *runs* with. Paper 1.20.5+ runs with Mojang
names, and since 26.1 Minecraft itself ships unobfuscated, so `MinecraftServer#stopServer` is
just that. On older Fabric (intermediary names) or Spigot (obfuscated method names), patches
don't match and are skipped with a warning.

## Building

```
./gradlew build
```

Output: `orange-launcher/build/libs/orange.jar` (launcher + agent + embedded plugin).
Use `./gradlew build -PwithoutPlugin` to build without the plugin if `repo.papermc.io` can't be reached.

| Module | Purpose |
|---|---|
| `orange-launcher` | `orange.jar`: launcher, config optimizer and Java agent |
| `orange-plugin` | Bukkit/Paper plugin bundled inside `orange.jar` |
| `orange-api` | API for Orange mods (`OrangeMod`, `OrangePatch`, `Patches`) |
| `orange-hooks` | Dependency-free runtime hooks that patched game code calls |
| `examples/example-mod` | A sample mod |

## Tested on real servers

Every push runs [`ci/server_test.py`](ci/server_test.py) in GitHub Actions against the newest
**Paper on Java 21** (1.21.x), **Paper on Java 25** (26.x) and **Purpur on Java 25**. It boots
each server through `orange.jar` twice and checks that:

- the server starts, the branding patch applies to the real `MinecraftServer`, and the plugin
  enables;
- `/orange status`, `/orange ping` and `/orange pregen` work (pregen generates 441 chunks);
- the optimizer tunes the configs the server generated, and lists any key that doesn't exist;
- compact object headers are on with Java 25;
- nothing logs an Orange error.

It also prints the real configs, `javap` signatures and Vineflower-decompiled source of
optimization candidates, so patches are written against the code the server actually runs.

## Roadmap

- **Vanilla-exact code optimizations, only where they pay off.** Reading the decompiled
  Paper 26.2 source showed it already contains the main Lithium-style optimizations for
  explosions (block-resistance caches, precomputed rays), hoppers (cached slots, full/empty
  shortcuts, event skipping) and furnaces (idle furnaces do almost no work). Orange only adds
  a patch where profiling a real server shows a hot spot Paper hasn't covered, and each one has
  to pass the server test above.
- **Orange server (Paper fork):** built-in source patches (faster entity tracking, async
  pathfinding and more) using Paper's `paperweight` toolchain, with this launcher and plugin as
  its front end.
- Folia-safe plugin using region schedulers.
- Automatic server jar download (PaperMC / Purpur APIs).
- Built-in performance patches through the agent, version-gated per Minecraft release.
