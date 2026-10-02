--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > UpgradeConfig (ModuleScript)

	Coin upgrades, Rebirth settings and Rebirth-Token upgrades.
	Cost to go from level L to L+1 = floor(BaseCost * CostGrowth ^ (L - 1))
]]

local UpgradeConfig = {}

UpgradeConfig.Order = { "RayPower", "Treadmill", "MultiShrink", "ChargeSpeed", "Range", "Luck", "MuseumSize" }

UpgradeConfig.Upgrades = {
	RayPower = {
		Name = "Ray Power",
		Description = "Shrink everything faster. Big objects charge MUCH faster with more power.",
		Emoji = "⚡",
		MaxLevel = 30, -- reaching max also unlocks Museum Raids
		BaseCost = 100,
		CostGrowth = 2.2,
		Value = function(level)
			return level
		end,
		Format = function(v)
			return "Lv " .. v
		end,
	},
	Treadmill = {
		Name = "Treadmill",
		Description = "Stand on the treadmill in your plot (AFK works!) to train speed. Upgrade = faster training.",
		Emoji = "🏃",
		MaxLevel = 30,
		BaseCost = 150,
		CostGrowth = 2.05,
		Value = function(level) -- speed points per second while on the treadmill
			return math.floor(level ^ 1.7 * 10 + 0.5) / 10
		end,
		Format = function(v)
			return v .. " pts/s"
		end,
	},
	ChargeSpeed = {
		Name = "Charge Speed",
		Description = "Charge your ray faster.",
		Emoji = "⏱️",
		MaxLevel = 20,
		BaseCost = 50,
		CostGrowth = 1.9,
		Value = function(level) -- seconds to fully charge
			return math.max(0.25, 2.0 * 0.9 ^ (level - 1))
		end,
		Format = function(v)
			return string.format("%.2fs", v)
		end,
	},
	Range = {
		Name = "Range",
		Description = "Zap objects from further away.",
		Emoji = "🎯",
		MaxLevel = 20,
		BaseCost = 75,
		CostGrowth = 1.85,
		Value = function(level)
			return 35 + 6 * (level - 1)
		end,
		Format = function(v)
			return math.floor(v) .. " studs"
		end,
	},
	Luck = {
		Name = "Luck",
		Description = "More Golden, Diamond, Rainbow & Cosmic spawns near you.",
		Emoji = "🍀",
		MaxLevel = 25,
		BaseCost = 200,
		CostGrowth = 2.0,
		Value = function(level)
			return 1 + 0.12 * (level - 1)
		end,
		Format = function(v)
			return string.format("x%.2f", v)
		end,
	},
	MultiShrink = {
		Name = "Carry Capacity",
		Description = "Carry more objects per trip (and zap several at once).",
		Emoji = "🎒",
		MaxLevel = 8,
		BaseCost = 1_500,
		CostGrowth = 7,
		Value = function(level)
			return level
		end,
		Format = function(v)
			return v .. " object" .. (v == 1 and "" or "s")
		end,
	},
	MuseumSize = {
		Name = "Museum Size",
		Description = "More pedestals = more displayed objects = more coins.",
		Emoji = "🏛️",
		MaxLevel = 20,
		BaseCost = 300,
		CostGrowth = 2.1,
		Value = function(level)
			return 8 + 2 * (level - 1) -- max 46 (+20 with the pass = 66 = 11 x 6 grid)
		end,
		Format = function(v)
			return v .. " pedestals"
		end,
	},
}

-- ── Rebirth ─────────────────────────────────────────────────────────
UpgradeConfig.Rebirth = {
	BaseCost = 5_000_000,
	CostGrowth = 4,
	MultiplierPerRebirth = 0.5, -- permanent income multiplier = 1 + rebirths * this
	GemsBase = 100, -- gems = GemsBase * (rebirths after this one)
	TokensBase = 1, -- tokens = TokensBase + floor(rebirths / 2)
}

-- ── Rebirth Token upgrades (permanent, survive rebirth) ─────────────
UpgradeConfig.TokenOrder = { "Income", "Luck", "Charge" }
UpgradeConfig.TokenUpgrades = {
	Income = { Name = "Eternal Income", Emoji = "💰", Description = "+10% income per level", MaxLevel = 50, Cost = function(l) return 1 + math.floor(l / 3) end, PerLevel = 0.10 },
	Luck = { Name = "Eternal Luck", Emoji = "🍀", Description = "+10% luck per level", MaxLevel = 50, Cost = function(l) return 1 + math.floor(l / 3) end, PerLevel = 0.10 },
	Charge = { Name = "Eternal Charge", Emoji = "⚡", Description = "-3% charge time per level", MaxLevel = 15, Cost = function(l) return 2 + math.floor(l / 2) end, PerLevel = 0.03 },
}

return UpgradeConfig
