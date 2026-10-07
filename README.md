# 🍊 Orange

**A performance layer for Minecraft servers.** Orange runs *on top of* the server you already
use (Paper, Purpur, Pufferfish, Leaf, Spigot, Fabric or vanilla) and makes it faster.
Because the real server still runs underneath, **every plugin that works on your server keeps
working**, and you get each new Minecraft version the day your server software supports it.

```
java -jar orange.jar
```

## What it does

| Layer | What you get |
|---|---|
| **Launcher** (`orange.jar`) | Starts your server with tuned JVM flags: [Aikar's G1 flags](https://docs.papermc.io/paper/aikars-flags) or generational ZGC, picked for your heap size. Sizes the heap from your RAM (container-aware), sets `-Xms = -Xmx`, adds the SIMD Vector API for Pufferfish-based forks, optionally restarts after crashes, and shuts the server down cleanly on Ctrl+C or SIGTERM. |
| **Config optimizer** | Tunes `server.properties`, `bukkit.yml`, `spigot.yml`, `config/paper-world-defaults.yml`, `purpur.yml` and `pufferfish.yml` with proven values (entity activation ranges, spawn rates, item/XP merging, auto-save smoothing, explosion optimization...). It keeps comments, backs every file up to `.orange/backups/`, only changes keys that already exist, and applies each profile **once** so your later edits stick. |
| **Orange plugin** (auto-installed) | **TPS governor**: when MSPT climbs past 45 it lowers simulation distance, then view distance, one step at a time, and puts them back when the server recovers. **Entity limiter**: caps same-type mobs per chunk so farms and breeding pens can't pile up 500 cows. **`/orange status`**: TPS, MSPT, memory, chunks, entities and governor state per world. |
| **Orange mods** (agent) | Fabric-style bytecode patches (ASM) loaded from `orange-mods/`, on any server software. Also brands the server as `Orange (Paper)` in the server list and F3. |

### Profiles

Set `optimization-profile` in `orange.yml`:

- **`balanced`** (default): large gains, nothing players will notice. Farms keep working.
- **`aggressive`**: maximum TPS. This **changes vanilla mechanics**: Alternate Current redstone,
  mobs from spawners have no AI, armor stands don't tick, Purpur villager lobotomizing,
  Pufferfish DAB, lower spawn caps, view distance 7 / simulation distance 4. Don't use it on
  technical/redstone servers.
- **`off`**: leave my configs alone.

## Quick start

1. Download your server jar (for example [Paper](https://papermc.io/downloads/paper) or
   [Purpur](https://purpurmc.org/downloads)) and put it in a folder with `orange.jar`.
2. Run `java -jar orange.jar`. It creates `orange.yml`, detects the server jar, and starts it.
3. The server creates its config files on the first start. **Restart once** and Orange tunes them.

Check what Orange would run without starting anything:

```
java -jar orange.jar --dry-run
```

### Which server should I put under Orange?

- **Most servers:** Paper, or **Purpur** if you want its gameplay toggles. Both are excellent with Orange.
- **Big servers:** Pufferfish or Leaf (Orange adds the SIMD flag they need automatically).
- **Technical/redstone servers:** Leaves or vanilla, with `optimization-profile: off` or `balanced`.
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
optimization-profile: balanced   # off | balanced | aggressive
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

## Roadmap

- **Orange server (Paper fork):** built-in source patches (faster entity tracking, async
  pathfinding and more) using Paper's `paperweight` toolchain, with this launcher and plugin as
  its front end.
- Folia-safe plugin using region schedulers.
- Automatic server jar download (PaperMC / Purpur APIs).
- Built-in performance patches through the agent, version-gated per Minecraft release.
