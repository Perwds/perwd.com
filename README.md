# Stat Scanner — a Roblox "check all your stats" game

A full Roblox experience in the style of *Flex Your Stats*, built entirely in
code so the place file stays empty and everything is reviewable in git.

**48 scannable stats**, each with its own scan timer, unlock condition and
flex message — plus gamepasses that speed the scanning up, a coin economy,
rebirths, achievements, global leaderboards, daily rewards and a
server-wide flex feed.

---

## Running it

The project syncs into Studio with [Rojo](https://rojo.space).

```bash
aftman install          # installs rojo, stylua and selene from aftman.toml
rojo serve              # then hit "Connect" in the Rojo Studio plugin
```

Or build a place file directly:

```bash
rojo build -o StatScanner.rbxlx
```

Nothing needs to be placed in Studio by hand — the lobby (floor, spawn,
scanner podium and six leaderboard pillars) is generated at runtime by
`src/server/WorldBuilder.lua`.

### Before publishing

1. **Turn on API access** — Game Settings → Security → *Enable Studio Access
   to API Services*. Without it the game still runs, but nothing saves and the
   global leaderboards stay empty.
2. **Create the products** on the Creator Dashboard and paste their asset ids
   into `src/shared/GamepassConfig.lua`. Every `id = 0` is treated as
   "not configured": the shop shows the item but refuses to prompt, so
   placeholders are safe to leave in during development.

---

## What a player does

1. Walks up to the podium (or presses <kbd>E</kbd>, or clicks **CHECK MY
   STATS**) to open the scanner.
2. Picks a stat. A progress bar runs for that stat's scan time, then the value
   is revealed and coins are paid out.
3. Spends coins unlocking more stats, or Robux on gamepasses that cut the wait.
4. Flexes a revealed stat to the whole server, climbs the leaderboards, and
   eventually rebirths for a permanent multiplier.

### Scan speed

| Source | Effect |
| --- | --- |
| 2x / 5x / 10x Scan Speed | highest owned multiplier applies |
| Instant Scan | results appear immediately |
| VIP | 1.5x speed, 2x coins, unlocks the VIP-only stats |
| +3 Scan Slots | run four scans at once instead of one |
| Auto Scanner | works through the whole catalogue while you AFK |
| 2x Scan Coins | doubles scan and daily payouts |
| Rebirths | +12% speed and +25% coins each, permanently |

Speed multipliers take the highest owned; coin multipliers stack.

### Stat catalogue

48 stats across seven categories — Core, Movement, Combat, Social, Economy,
Collection and Cursed. A few of them:

- **Core** — playtime, games played, account age, join date, sessions, average
  and longest session, best login streak, time in lobbies
- **Movement** — walk / fall / swim distance, total jumps, time seated,
  marathons run, laps of Earth
- **Combat** — deaths, kills, K/D, damage dealt, void falls, best killstreak
- **Social** — friends, followers, following, groups, messages sent, ignored
  friend requests, social score
- **Economy** — account value, avatar value, Robux spent, real money spent,
  gamepasses owned, Premium months, richest item
- **Collection** — badges, items owned, limiteds, favourites, rarest badge,
  collection score
- **Cursed** — hours wasted, % of life played, sleep lost, rage quits, grass
  touched, brainrot level

Stats unlock in four ways: free from the start, bought with coins, earned after
N completed scans, gated behind a rebirth count, or gated behind VIP.

### Where the numbers come from

Two sources, both server-side:

- **Real data** the server can actually read — account age, friend count,
  group count, Premium membership, worn avatar assets.
- **Deterministic estimates** for everything Roblox exposes no server API for.
  These are seeded from the player's `UserId`, so an account always gets the
  same answer on every server and every rejoin — which is what makes saved
  values and leaderboards coherent. That is what the *"Uses estimation based on
  player stats"* line on each card is telling the player.

All of it lives in `src/server/StatEngine.lua`, and the client only ever
receives finished numbers.

---

## Layout

```
src/shared/          replicated config + helpers
  StatConfig         the 48 stats: colours, scan times, unlocks, flex lines
  GamepassConfig     passes and developer products, and how their effects stack
  AchievementConfig  15 achievements with their predicates
  RebirthConfig      costs, requirements and multipliers
  RankConfig         13 rank titles driven by scan score
  Format             number -> display string
  Remotes            declares every remote in one place

src/server/
  init.server.lua    bootstrap, remote validation, rate limiting
  DataService        DataStore profiles: retry, autosave, BindToClose
  StatEngine         real data + deterministic estimates
  ScanService        slots, timers, rewards, auto-scan
  StateService       the snapshot the UI renders from
  GamepassService    ownership cache, prompts, ProcessReceipt
  AchievementService predicate evaluation and payouts
  DailyService       daily reward with a streak
  RebirthService     requirements and the reset
  LeaderboardService OrderedDataStore boards + the Tab leaderboard
  WorldBuilder       generates the lobby

src/client/
  init.client.lua    remote wiring
  Store              client state + change signal
  ui/                App, StatCard, ShopPanel, BoardPanel,
                     AchievementPanel, RebirthPanel, Toasts, FlexFeed,
                     Theme, Util
```

## Server authority

Nothing the client sends is trusted:

- Scan timers run on server `task.delay`; the client is told the end time only
  so it can animate a bar.
- Stat ids are looked up in config, and coin costs are charged server-side.
- Every remote handler is rate limited per player.
- Values are computed on the server and pushed down; the client never computes
  a stat.
- A failed DataStore read kicks with a rejoin message rather than handing out a
  blank profile that would overwrite real progress on the next save.
