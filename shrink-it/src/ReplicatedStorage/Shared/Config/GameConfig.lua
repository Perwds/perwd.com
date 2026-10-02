--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > GameConfig (ModuleScript)

	Global tuning knobs for Shrink It! 🔬
	Everything here is safe to tweak. Numbers are read by both server and client.
]]

local GameConfig = {}

GameConfig.GameName = "Shrink It! 🔬"

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
GameConfig.PlotCount = 8
GameConfig.MaxPlayers = 8 -- one museum plot per player. ALSO set Max Players = 8 in Game Settings (see README)

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
GameConfig.CarryDisplaySize = 2.6 -- size of each object stacked above your head -- extra targets must be within this distance of the main target
GameConfig.ShrinkFxTime = 0.9 -- seconds the tween plays before the server removes the object
GameConfig.AutoShrinkExtraDelay = 0.75

-- ── Movement ────────────────────────────────────────────────────────
GameConfig.BaseWalkSpeed = 16
GameConfig.SpeedBootsBonus = 8 -- added on top of the Run Speed upgrade

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

-- ── Sounds (🔧 REPLACE with your own asset ids if you like) ───────────
GameConfig.Sounds = {
	Pop = "rbxasset://sounds/electronicpingshort.wav", -- 🔧 REPLACE: satisfying "pop"
	Charge = "rbxasset://sounds/swoosh.wav", -- 🔧 REPLACE: charging hum
	Click = "rbxasset://sounds/button.wav", -- 🔧 REPLACE: UI click
	Reward = "rbxasset://sounds/victory.wav", -- 🔧 REPLACE: reward jingle
	TooBig = "rbxasset://sounds/uuhhh.mp3", -- 🔧 REPLACE: error buzz
}

return GameConfig
