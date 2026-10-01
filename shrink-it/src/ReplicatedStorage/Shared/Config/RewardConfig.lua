--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > RewardConfig (ModuleScript)

	Free playtime gifts, daily streak, Index completion rewards, Like-goal codes,
	reward codes, and the Infinite Pack generator settings.

	Reward table types (see RewardUtil):
	  { Type = "Coins", Amount = n }
	  { Type = "CoinsMinutes", Minutes = n, Floor = n }   -- n minutes of the player's income
	  { Type = "Gems", Amount = n }   { Type = "Tokens", Amount = n }
	  { Type = "LuckPotion", Minutes = n }   { Type = "IncomePotion", Minutes = n }
	  { Type = "RaySkin", Skin = "Galaxy" }
	  { Type = "Object", Id = "HugeTeddy", Variant = "Normal" }
	  { Type = "Mystery", Pool = "PackMystery" }   -- random; odds are shown in the UI
	  { Type = "Bundle", Rewards = { ... } }
]]

local RewardConfig = {}

-- ── Free playtime gifts (session playtime, resets each session) ──────────
RewardConfig.Gifts = {
	{ Time = 5 * 60, Size = "Small", Reward = { Type = "CoinsMinutes", Minutes = 3, Floor = 250 } },
	{ Time = 10 * 60, Size = "Small", Reward = { Type = "Gems", Amount = 10 } },
	{ Time = 15 * 60, Size = "Small", Reward = { Type = "CoinsMinutes", Minutes = 6, Floor = 500 } },
	{ Time = 20 * 60, Size = "Small", Reward = { Type = "LuckPotion", Minutes = 5 } },
	{ Time = 30 * 60, Size = "Medium", Reward = { Type = "Gems", Amount = 25 } },
	{ Time = 45 * 60, Size = "Medium", Reward = { Type = "CoinsMinutes", Minutes = 15, Floor = 2_000 } },
	{ Time = 60 * 60, Size = "Medium", Reward = { Type = "IncomePotion", Minutes = 10 } },
	{ Time = 75 * 60, Size = "Medium", Reward = { Type = "Gems", Amount = 50 } },
	{ Time = 90 * 60, Size = "Big", Reward = { Type = "CoinsMinutes", Minutes = 30, Floor = 10_000 } },
	{ Time = 120 * 60, Size = "Big", Reward = { Type = "Gems", Amount = 100 }, HugeChance = 0.03 },
	{ Time = 150 * 60, Size = "Big", Reward = { Type = "LuckPotion", Minutes = 30 }, HugeChance = 0.06 },
	{ Time = 180 * 60, Size = "Big", Reward = { Type = "Gems", Amount = 250 }, HugeChance = 0.12 },
}
RewardConfig.GiftHuge = { Type = "Object", Id = "HugeTeddy", Variant = "Normal" }

-- ── Daily login streak (cycles every 7 days; amounts scale with weeks) ───
RewardConfig.Daily = {
	{ Type = "CoinsMinutes", Minutes = 5, Floor = 500 },
	{ Type = "Gems", Amount = 15 },
	{ Type = "LuckPotion", Minutes = 10 },
	{ Type = "CoinsMinutes", Minutes = 15, Floor = 2_000 },
	{ Type = "Gems", Amount = 40 },
	{ Type = "IncomePotion", Minutes = 15 },
	{ Type = "Bundle", Rewards = { { Type = "Gems", Amount = 100 }, { Type = "Tokens", Amount = 1 } } },
}

-- ── Index completion rewards (per area/tier) ─────────────────────────
-- "Normal" = every Normal object of that tier. "Full" = every object in every variant.
-- Secret objects are a bonus and are never required.
RewardConfig.IndexRewards = {
	Normal = { GemsPerTier = 25, IncomeBonus = 0.05 },
	Full = { GemsPerTier = 250, IncomeBonus = 0.15 },
}

-- ── Like-the-game goals ───────────────────────────────────────────────
-- 🔧 Update CurrentLikes by hand whenever you want the sign to move.
RewardConfig.Likes = {
	CurrentLikes = 0, -- 🔧 SET MANUALLY
	Goals = {
		{ Goal = 50, Code = "LIKES50" },
		{ Goal = 250, Code = "LIKES250" },
		{ Goal = 1000, Code = "LIKES1K" },
		{ Goal = 5000, Code = "LIKES5K" },
		{ Goal = 25000, Code = "LIKES25K" },
	},
}

-- ── Codes (case-insensitive). RequiresLikes locks a code behind a like goal. ──
RewardConfig.Codes = {
	RELEASE = { Rewards = { { Type = "Gems", Amount = 50 }, { Type = "LuckPotion", Minutes = 15 } } },
	SHRINK = { Rewards = { { Type = "CoinsMinutes", Minutes = 10, Floor = 1_000 } } },
	LIKES50 = { RequiresLikes = 50, Rewards = { { Type = "Gems", Amount = 75 } } },
	LIKES250 = { RequiresLikes = 250, Rewards = { { Type = "Gems", Amount = 150 }, { Type = "IncomePotion", Minutes = 15 } } },
	LIKES1K = { RequiresLikes = 1000, Rewards = { { Type = "Gems", Amount = 300 }, { Type = "LuckPotion", Minutes = 30 } } },
	LIKES5K = { RequiresLikes = 5000, Rewards = { { Type = "Gems", Amount = 600 }, { Type = "RaySkin", Skin = "Galaxy" } } },
	LIKES25K = { RequiresLikes = 25000, Rewards = { { Type = "Object", Id = "HugeCrystal", Variant = "Golden" } } },
}

-- ── Mystery pools (random rewards; odds are DISPLAYED in the UI) ─────────
RewardConfig.MysteryPools = {
	PackMystery = {
		Name = "Mystery Crate",
		Entries = {
			{ Weight = 50, Reward = { Type = "CoinsMinutes", Minutes = 90, Floor = 20_000 } },
			{ Weight = 30, Reward = { Type = "Gems", Amount = 400 } },
			{ Weight = 15, Reward = { Type = "LuckPotion", Minutes = 45 } },
			{ Weight = 4, Reward = { Type = "Object", Id = "HugeCrystal", Variant = "Normal" } },
			{ Weight = 1, Reward = { Type = "Object", Id = "HugeDragon", Variant = "Normal" } },
		},
	},
}

-- ── Infinite Pack ─────────────────────────────────────────────────────
RewardConfig.InfinitePack = {
	RefreshSeconds = 6 * 3600, -- new chain + progress reset every 6 hours (purchased credits are kept)
	Pattern = { false, true, false, false, false, true }, -- false = FREE, true = Robux (repeats forever)
	VisibleTiles = 8,
	PreviewTiles = 10,
	MilestoneEvery = 10, -- every Nth tile is a big milestone
	ScalePerTile = 0.18, -- reward amounts grow by this fraction each tile
	PaidTiers = { -- which Developer Product a paid tile uses, by tile index
		{ FromIndex = 1, Product = "PackTier1" },
		{ FromIndex = 13, Product = "PackTier2" },
		{ FromIndex = 31, Product = "PackTier3" },
	},
	FreePool = {
		{ Weight = 40, Kind = "CoinsMinutes", Base = 3 },
		{ Weight = 30, Kind = "Gems", Base = 8 },
		{ Weight = 15, Kind = "LuckPotion", Base = 5 },
		{ Weight = 15, Kind = "IncomePotion", Base = 5 },
	},
	PaidPool = {
		{ Weight = 30, Kind = "Gems", Base = 120 },
		{ Weight = 25, Kind = "CoinsMinutes", Base = 45 },
		{ Weight = 15, Kind = "LuckPotion", Base = 30 },
		{ Weight = 10, Kind = "RaySkin" },
		{ Weight = 12, Kind = "Mystery", Pool = "PackMystery" },
		{ Weight = 8, Kind = "Object", Id = "HugeCrystal" },
	},
}

return RewardConfig
