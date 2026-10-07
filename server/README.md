# Orange server

The Orange server jar: a fork of [Paper](https://papermc.io) built with PaperMC's
[paperweight](https://github.com/PaperMC/paperweight) toolchain, laid out like
[Purpur](https://github.com/PurpurMC/Purpur). Plugins for Paper run on it unchanged.

| | |
|---|---|
| Minecraft | 1.21.11 (runs on Java 21+) |
| Upstream | Paper `bd74bf6` (`paperCommit` in `gradle.properties`) |
| Patches | `orange-server/build.gradle.kts.patch` (branding), `orange-server/paper-patches/` and `orange-server/minecraft-patches/` (code changes) |

## Building

GitHub Actions builds it on every change ([`orange-server.yml`](../.github/workflows/orange-server.yml)).
Locally, with Java 21 and git:

```
cd server
./gradlew applyAllPatches
./gradlew createMojmapPaperclipJar
```

The jar is written to `orange-server/build/libs/`. Building needs access to repo.papermc.io and
Mojang's servers, so it can't be built offline.
