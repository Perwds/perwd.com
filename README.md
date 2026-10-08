# 🍊 Orange

**Vanilla gameplay, as fast as it can go.** Orange is two things:

- **The Orange server** ([`server/`](server/)): Orange's own server jar, a Paper fork, so Paper
  plugins work on it. `orange.jar` downloads it for you.
- **The launcher** (`orange.jar`): starts the Orange server, or any server you already have
  (Paper, Purpur, Pufferfish, Leaf, Leaves, Spigot, Fabric or vanilla), with tuned JVM flags, fast
  startup and tuned configs. By default it **undoes the vanilla changes Paper and Spigot make**
  (piston duping, headless pistons, bedrock breaking, frozen far-away mobs, item merging...) and
  only adds optimizations that don't change gameplay.

```
java -jar orange.jar
```

## What it does

| Layer | What you get |
|---|---|
| **Launcher** (`orange.jar`) | Starts your server with tuned JVM flags: [Aikar's G1 flags](https://docs.papermc.io/paper/aikars-flags) or generational ZGC, picked for your heap size. On Java 25+ it adds compact object headers (a smaller heap and less GC work), and transparent huge pages when the kernel supports them. Sizes the heap from your RAM (container-aware), sets `-Xms = -Xmx`, adds the SIMD Vector API for Pufferfish-based forks, optionally restarts after crashes, and shuts the server down cleanly on Ctrl+C or SIGTERM. |
| **Config optimizer** | Edits `server.properties`, `bukkit.yml`, `spigot.yml`, `config/paper-global.yml`, `config/paper-world-defaults.yml`, `purpur.yml` and `pufferfish.yml` for the profile you pick (below). It keeps comments, backs every file up to `.orange/backups/`, only changes keys that already exist, and applies each profile **once** so your later edits stick. |
| **Orange plugin** (auto-installed) | **`/orange pregen <world> <radius>`**: generates the world ahead of time. Chunk generation is the biggest single source of lag, and pre-generating changes nothing about the world. It spirals out from spawn and pauses while the server is busy. **TPS governor**: lowers *view* distance while MSPT is above 45 and puts it back when the server recovers. **High-ping helper**: tracks every player's ping and jitter (`/orange ping`). When a player's ping stays above 250 ms, it sends them fewer chunks so their connection has room for movement and combat updates. It restores them when their ping recovers, and the world simulates exactly as before. **`/orange status`**: TPS, MSPT, memory, chunks and entities per world. The entity limiter and the simulation-distance governor change gameplay, so they're **off by default**. |
| **Fast startup** | For Paper-based servers, Orange launches the unpacked server directly, so Paperclip doesn't re-hash every library on each start. It also keeps a JVM class cache between runs: the AOT cache on Java 25+, AppCDS on Java 21–24. The first start records the cache, and later starts reuse it. Turn it off with `fast-startup: false`. |
| **Orange mods** (agent) | Fabric-style bytecode patches (ASM) loaded from `orange-mods/`, on any server software. The agent attaches only when mods are installed (`agent: auto`). Set `agent: true` to also brand the server as `Orange (Paper)` in the server list and F3. |

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

All you need is Java 25 (or 21) and `orange.jar`:

1. Put `orange.jar` in an empty folder and double-click it, or run `java -jar orange.jar`.
   A double-click opens Orange in a terminal window and leaves a `start.bat` (Windows),
   `start.command` (macOS) or `start.sh` (Linux) next to it for the next time.
2. Orange downloads the **Orange server** (Orange's own Paper fork, see [`server/`](server/)),
   verifies its checksum, asks you to accept the Minecraft EULA, and starts it.
3. Restart once after the first start: the server creates its config files on the first start,
   and Orange tunes them on the next one.

Want upstream Paper or Purpur instead? Set `download: paper` or `download: purpur` in `orange.yml`. Already have a server jar? Put it next
to `orange.jar` and Orange uses it. Orange keeps the jar it downloaded up to date with new builds
of the same Minecraft version (`auto-update: true`). It never changes the Minecraft version by itself,
because that upgrades your world, which can't be undone. Set `minecraft-version` to move to a new one.

Then pre-generate the world (in-game or from the console):
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

## Plugins

The Orange server uses Paper's plugin loader, so it runs:

- **Bukkit/Spigot plugins** (`plugin.yml`) and **Paper plugins** (`paper-plugin.yml`);
- **Folia-compatible plugins** (`folia-supported: true`) *next to* the regular ones. Folia's
  scheduler API (global region, region, entity and async schedulers) is part of Paper's API; on
  Orange those schedulers run tasks on the server thread. CI proves it: a Folia-style test plugin
  ([`ci/folia-test-plugin`](ci/folia-test-plugin)) runs every scheduler next to the Orange plugin on
  the Orange server, Paper and Purpur.

Not supported: plugins that refuse to start unless the server *is* Folia, Fabric/Forge mods, and
proxy (Velocity/BungeeCord) plugins. Running regular plugins on Folia itself isn't possible: they
aren't written to be called from several threads at once.

## orange.yml

```yaml
server-jar: auto                 # or a file name
download: orange                 # orange | paper | purpur | off
minecraft-version: latest        # or e.g. 26.2
auto-update: true
memory: auto                     # e.g. 8G
gc: auto                         # auto | g1 | zgc
optimization-profile: vanilla    # vanilla | balanced | aggressive | off
ping-tolerance: normal           # normal | high
install-plugin: true
agent: auto                      # auto | true | false
fast-startup: true
tnt-tick-budget-ms: 20           # Orange server: max explosion time per tick (0 = off)
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

## Benchmark

[`ci/benchmark.py`](ci/benchmark.py) runs plain Paper and Paper through Orange one after another on
the same GitHub Actions machine: 8 GB heap, same seed, TAB and spark, 256 force-loaded chunks and
~2,000 mobs. Paper 26.2 on Java 25:

| | Paper | Orange (vanilla) |
|---|---|---|
| Startup, wall clock | 10.6 s | **6.3 s** |
| Startup, Paper's "Done" timer | 10.1 s | **5.0 s** |
| MSPT median under load | 37.7 ms | 38.3 ms |

Startup is faster from the second start on (the first start records the class cache, about
200 MB in `.orange/cache/jvm/`). Under load the two are within run-to-run noise: Paper itself
is already very well optimized, and Orange's `vanilla` profile turns off its gameplay-changing
shortcuts.

### 1,000 TNT

[`ci/tnt_benchmark.py`](ci/tnt_benchmark.py) summons 1,000 primed TNT in one spot on the Orange
server (1.21.11, Java 21, 6 GB) and measures every tick until the last one has gone off
(spark 10 s windows, plus a GC log and a per-explosion timer):

| | No TNT budget (like Paper) | Orange default (20 ms budget) |
|---|---|---|
| Worst tick during the blast | 392-800 ms | **100-110 ms** |
| 95th percentile tick | 7-17 ms | 24-28 ms |
| Median tick | ~1 ms | ~1 ms |
| TNT left / items left at the end | 0 / 0 | 0 / 0 |

What the Orange server does, without changing explosion results:

- **TNT time budget.** Once explosions have used `tnt-tick-budget-ms` of a tick, the remaining
  TNT waits a tick instead of exploding in the same one. One explosion per tick always goes
  through, so nothing is ever starved.
- **Exact exposure cache.** For every entity in range an explosion casts dozens of rays to see
  how exposed it is. Results are reused for the same centre and bounding box until a block
  changes in a chunk section between them; anything whose rays touched an entity-dependent
  block shape is never cached. With stacked TNT 99.9 % of lookups hit.
- **JVM flags.** A 512 MB code cache and 256 MB initial metaspace stop the extra
  "CodeCache/Metadata GC Threshold" pauses the GC log showed during the blast.

The remaining worst tick is the blast's *first* explosion (60-70 ms the first time that code
runs) plus that tick's other TNT work; GC pauses are the next biggest (ZGC removes them, but
didn't improve the worst tick in this test, so `gc: auto` still picks G1 below 16 GB).
Spigot's `max-tnt-per-tick: 100` (also Paper's default) is why 1,000 TNT takes ~140 s to go
off. To see slow explosions on your own server, add
`extra-jvm-args: ["-Dorange.debug.explosionMs=15"]`.

### Chunk generation

[`ci/chunkgen_benchmark.py`](ci/chunkgen_benchmark.py) generates 3,721 chunks (radius 480 blocks)
on a 4-core machine. Paper uses one chunk worker thread by default; Orange's optimizer sets
`chunk-system.worker-threads` to cores - 1 (every profile except `off`; world generation is
identical, only done in parallel):

| | Paper default (1 worker) | Orange (cores - 1) | Every core |
|---|---|---|---|
| Chunks per second | 32 | **60** | 64 |
| Time | 116 s | **62 s** | 58 s |
| Worst tick | 92 ms | **71 ms** | 70 ms (higher median tick) |

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
