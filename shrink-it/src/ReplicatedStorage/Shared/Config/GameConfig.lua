--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > GameConfig (ModuleScript)

	Global tuning knobs for Shrink It! 🔬
	Everything here is safe to tweak. Numbers are read by both server and client.
]]

local GameConfig = {}

GameConfig.GameName = "Shrink It!"
GameConfig.Version = "v19.2 (lime studded checker ground)" -- shown bottom-right in game so you can tell which build you are running
GameConfig.MapVersion = 18 -- bump when the generated map layout changes; older generated maps get rebuilt

-- ── DataStore / saving ────────────────────────────────────────────────
GameConfig.DataStoreName = "ShrinkIt_PlayerData_v1" -- change the suffix to wipe all data
GameConfig.AutosaveInterval = 60 -- seconds between autosaves (also refreshes the session lock)
GameConfig.SessionLockStale = 300 -- a lock not refreshed for this long is treated as a crashed server
GameConfig.LoadRetries = 8
GameConfig.MaxReceiptHistory = 200 -- purchase ids remembered per player for idempotency

-- ── Museum / items ────────────────────────────────────────────────────
GameConfig.MaxItems = 400 -- pocket cap; lowest-earning item is auto-sold when exceeded
GameConfig.SellSeconds = 120 -- selling an item gives this many seconds of its income
GameConfig.DisplayMaxSize = 2.9 -- studs; displayed objects are scaled to fit this
-- Admin panel: ONLY these accounts get it (checked on the server by username / UserId — display
-- names are NOT used because anyone can set any display name).
GameConfig.Admins = { Names = { "huskey08", "mulvadbase" }, UserIds = {} }

-- fewer boxes in the zones: only this share of each zone's spawn spots get a box, and they come back slower
GameConfig.BoxSpawnFraction = 0.5
GameConfig.RespawnTimeMult = 1.4

GameConfig.PlotCount = 6
GameConfig.MaxPlayers = 6 -- one museum plot per player, all in one fair row. ALSO set Max Players = 6 in Game Settings (see README)

-- ── Shrink Ray ───────────────────────────────────────────────────────
GameConfig.ShrinkCooldown = 0.25 -- min seconds between shots
-- Any object can be shrunk at any Ray Power. Charge time is multiplied by
--   (object's RayPowerRequired / your Ray Power) ^ PowerChargeExponent,
-- clamped between MinChargeMult (way overpowered = fast) and MaxChargeMult (way underpowered = slow).
GameConfig.PowerChargeExponent = 1.3
GameConfig.MinChargeMult = 0.35
GameConfig.MaxChargeMult = 45
GameConfig.ChargeTolerance = 0.8 -- server accepts a shot after chargeTime * this (latency allowance)
GameConfig.RangeTolerance = 8 -- extra studs the server allows over the client's range
GameConfig.MultiShrinkRadius = 30

-- Ground look: "Stylized" = bright studded plastic ground (default),
-- "Terrain" = Roblox terrain with long swaying grass blades.
GameConfig.Ground = "Stylized"
-- true = the whole generated map is built from studded LEGO-style bricks (the Steal-an-Egg look)
GameConfig.Studs = true

-- Fusing: this many identical objects (same object + same variant) fuse into ONE of the next variant
-- (Normal → Golden → Diamond → Rainbow → Cosmic).
GameConfig.Fuse = { Count = 3 }

-- ── Mystery boxes ───────────────────────────────────────────────────
-- The zones are full of mystery BOXES (crates). A box has a rarity (its color) but you don't know
-- what's inside. Shrink it, carry it home, place it on one of your pedestals and it opens after
--   OpenSeconds[box rarity] + SecondsPerTier * zone + VariantExtra[variant]   seconds.
-- When it opens, a RANDOM object of that zone is rolled: better boxes (RarityBoost) make rarer
-- objects more likely, your Luck makes Golden/Diamond/... variants and bigger sizes more likely.
-- "Open now" on the pedestal skips the wait for 1 Gem per SecondsPerGem seconds left.
-- ── Night (like Steal an Egg): a big wall closes off the zones while ALL boxes respawn ──
-- Every `Every` seconds: warning `Warning` seconds before, then the wall stays up `Closed` seconds.
-- Anyone still in the zones is sent back to the base (they keep what they carry).
GameConfig.Night = { Every = 240, Warning = 15, Closed = 10 }

-- ── Boss: Dr. Grow and his giant robot (every 30 minutes, everyone shrinks it down together) ──
-- Zap the robot with your Shrink Ray (it takes Damage = DamageBase + DamagePerRayPower x Ray Power).
-- It fires a GROWTH ray at players (they get big and slow for GrowSeconds). Beat it before
-- TimeLimit and everyone who helped gets SAMPLES (more for more damage) + 1 Boss Mastery point.
GameConfig.Boss = {
	Every = 1800,
	FirstAfter = 600, -- first visit this many seconds after the server starts
	Warning = 30,
	TimeLimit = 240,
	Arena = Vector3.new(0, 0, -140),
	BaseHP = 80,
	HPPerPlayer = 45,
	ChargeTime = 0.45,
	DamageBase = 2,
	DamagePerRayPower = 0.35,
	ShotEvery = 3.5,
	GrowSeconds = 6,
	GrowScale = 1.6,
	GrowSlow = 0.55,
	SamplesBase = 15,
	SamplesShare = 60, -- split by damage dealt
	-- Boss Mastery: at these kill counts you get a MASTERY BOX (only from bosses / the Lab)
	MasteryMilestones = { 1, 3, 5, 10, 25, 50, 100 },
}
-- ── Lab (turn in unopened boxes for Samples; spend Samples) ──
GameConfig.Lab = {
	SamplesPerRarity = { Common = 1, Uncommon = 2, Rare = 3, Epic = 5, Legendary = 8, Mythic = 12, Secret = 20 },
	SerumCost = 25, -- Mutation Serum: your next placed box is 4x more likely to mutate
	SerumBoost = 4,
	MasteryBoxCost = 150,
}
-- A Mastery Box: very rare rarity, from your best zone, always mutated and at least Huge.
GameConfig.MasteryBox = { R = "Mythic", MinSize = 2 }
-- LIMITED event box (Robux product "LimitedBox"): always the Festive mutation, which you can't get any other way.
GameConfig.LimitedBox = { Name = "Festive Box", Rarity = "Secret", Mutation = "Festive" }

GameConfig.MultiShrinkExtras = false -- true = one zap also grabs nearby boxes (felt like a bug, so off)

GameConfig.Boxes = {
	OpenSeconds = { Common = 8, Uncommon = 15, Rare = 30, Epic = 60, Legendary = 120, Mythic = 240, Secret = 480 },
	SecondsPerTier = 4,
	VariantExtra = { Golden = 10, Diamond = 20, Rainbow = 40, Cosmic = 90 },
	SecondsPerGem = 10,
	-- object-rarity weights are multiplied by RarityBoost[box] ^ (objectRarityOrder - 1)
	RarityBoost = { Common = 1, Uncommon = 1.5, Rare = 2.2, Epic = 3.2, Legendary = 4.5, Mythic = 6.5, Secret = 9 },
	AnnounceFrom = "Legendary", -- boxes this rare (or rarer) are announced to the whole server when they spawn
	-- Everyone sees the SAME boxes. When someone shrinks one it disappears only for THEM;
	-- up to MaxClaims different players can take the same box before it's gone for everybody.
	MaxClaims = 4,
	Lifetime = 240, -- seconds a box stays before it's replaced by a new one
}

-- ── Sizes & weight ─────────────────────────────────────────────────
-- Every opened object gets a random SIZE. Bigger = earns more (Mult) and weighs more.
-- On a pedestal everything is shown at the same size; when you HOLD it above your head
-- (pick it up from a pedestal) it's shown at its real size.
-- Luck makes the sizes marked Lucky = true more likely.
GameConfig.Sizes = {
	{ Name = "Tiny", Mult = 0.6, Weight = 18 },
	{ Name = "Small", Mult = 0.8, Weight = 26 },
	{ Name = "Normal", Mult = 1, Weight = 36 },
	{ Name = "Big", Mult = 1.4, Weight = 12, Lucky = true },
	{ Name = "Huge", Mult = 2, Weight = 5, Lucky = true },
	{ Name = "Giant", Mult = 3, Weight = 1.5, Lucky = true },
	{ Name = "Colossal", Mult = 5, Weight = 0.3, Lucky = true },
}
GameConfig.HoldBaseSize = 6 -- studs: a Normal object is this big in your hands AND on the ground in your base (x its size Mult)
GameConfig.CarrySlowPerSize = 0.06 -- walk speed -6% for every size step above Normal you carry (Colossal box = -24%)
GameConfig.CarrySlowMin = 0.6 -- never slower than 60%
GameConfig.InfiniteCarry = 999 -- "Infinite Carry" gamepass (shown as ∞)
GameConfig.BoxBaseSize = 4 -- studs: a Normal-size box in your hands / on your base floor (x its size ^ 0.75)

GameConfig.CarryDisplaySize = 2.6 -- size of each object stacked above your head -- extra targets must be within this distance of the main target
GameConfig.ShrinkFxTime = 0.9 -- seconds the tween plays before the server removes the object
GameConfig.AutoShrinkExtraDelay = 0.75

-- ── Movement & speed training ───────────────────────────────────────
GameConfig.BaseWalkSpeed = 28
GameConfig.SpeedBootsBonus = 8 -- gamepass, added on top
-- Speed is TRAINED, not bought: stand on the treadmill in your plot (AFK is fine) to earn Speed
-- points. Points per second = the Treadmill upgrade. Walk speed = Base + bonus, where
--   bonus = min(MaxBonus, PointsFactor * sqrt(points))   (x2 with the "2x Speed" gamepass).
GameConfig.Training = {
	PointsFactor = 0.35,
	MaxBonus = 120,
	Tick = 1, -- seconds between point awards
	OfflineFraction = 0, -- set e.g. 0.25 to keep training a bit while offline
}

-- ── PvP: bat & trap ────────────────────────────────────────────────
-- Everyone gets a Bat and a Trap. Hitting a player who is CARRYING something outside the safe
-- zone steals the top thing they carry (box or held object). They must meet the requirement:
GameConfig.PvP = {
	MinRebirthsToBeStolenFrom = 0, -- victim needs at least this many rebirths (0 = everyone)
	MinRebirthsToSteal = 0, -- attacker needs at least this many rebirths
	BatRange = 8,
	BatCooldown = 1.2,
	BatKnockback = 45,
	StunSeconds = 1.2,
	TrapStunSeconds = 2.5,
	TrapCooldown = 20,
	TrapLifetime = 60,
	MaxTraps = 2,
	ProtectAfterSteal = 5, -- seconds a robbed player can't be robbed again
}

-- ── Chat ──────────────────────────────────────────────────────────
GameConfig.Chat = {
	HereRadius = 90, -- "Here" channel: only players this close hear you
	GlobalCrossServer = true, -- "Global" also reaches every other server (filtered, via MessagingService)
}

-- ── VIP ─────────────────────────────────────────────────────────────
GameConfig.VIP = {
	IncomeMult = 1.5,
	LuckMult = 1.5,
	ChargeMult = 1 / 1.5, -- "1.5x everything": charge is 1.5x faster
	FountainGems = 25,
	FountainCooldown = 15 * 60,
}

-- ── Potions & boosts ────────────────────────────────────────────────
GameConfig.LuckPotionMult = 2
GameConfig.IncomePotionMult = 2
GameConfig.ServerLuckMult = 2

-- ── Offline earnings (gamepass) ─────────────────────────────────────
GameConfig.Offline = {
	MaxSeconds = 8 * 3600,
	Rate = 0.5, -- fraction of normal income earned while offline
}

-- ── Museum Raid (endgame PvP, opt-in) ───────────────────────────────
GameConfig.Raid = {
	Duration = 60, -- seconds a raid lasts
	MaxCopies = 3, -- copies a raider can take per raid
	RevengeCopyBonus = 2, -- revenge raids allow MaxCopies * this
	RevengeGemBonus = 75, -- gems for a successful revenge raid (x2 with Raid Shield pass)
	BuildingChargeTime = 4, -- seconds to charge the ray on a museum building
	ZapRange = 140, -- studs
	Cooldown = 600, -- seconds between raids for the raider
	ShieldTime = 30 * 60, -- victim protection after being raided
	ShieldTimeWithPass = 90 * 60,
	RevengeWindow = 10 * 60,
	ToggleCooldown = 30,
}

-- ── Leaderboards ────────────────────────────────────────────────────
GameConfig.LeaderboardRefresh = 120
GameConfig.LeaderboardSize = 10

-- ── Sounds ───────────────────────────────────────────────────────────
-- Sound effects use Roblox's BUILT-IN sounds (work right away). 🔧 REPLACE with your own ids if you like.
GameConfig.Sounds = {
	Pop = "rbxasset://sounds/electronicpingshort.wav",
	Charge = "rbxasset://sounds/swoosh.wav",
	Click = "rbxasset://sounds/button.wav",
	Reward = "rbxasset://sounds/victory.wav",
	TooBig = "rbxasset://sounds/uuhhh.mp3",
	Hit = "rbxasset://sounds/swordslash.wav",
	Whack = "rbxasset://sounds/collide.wav",
	Trap = "rbxasset://sounds/snap.wav",
	Swing = "rbxasset://sounds/swordlunge.wav",
	Caught = "rbxasset://sounds/uuhhh.mp3",
	Grab = "rbxasset://sounds/clickfast.wav",
	Open = "rbxasset://sounds/electronicpingshort.wav",
	Footstep = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Alarm = "rbxasset://sounds/electronicpingshort.wav",
}
-- Ambient (environment) loops per area. Roblox's own ambience sounds are in the Creator Store
-- (Toolbox → Audio, creator "Roblox": search "birds", "wind", "city", "ocean", ...). 🔧 Paste ids here.
-- Empty = no loop for that area. "Base" plays in the safe zone.
GameConfig.Ambient = {
	Base = "",
	[1] = "", [2] = "", [3] = "", [4] = "", [5] = "",
	[6] = "", [7] = "", [8] = "", [9] = "", [10] = "",
	Volume = 0.35,
}

return GameConfig
