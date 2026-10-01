--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > RarityConfig (ModuleScript)

	Base rarities (decide which objects spawn and how much they earn)
	and Variants (rolled on every spawn, modified by Luck).
]]

local RarityConfig = {}

RarityConfig.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

RarityConfig.Rarities = {
	Common = { Order = 1, SpawnWeight = 100, IncomeMult = 1, Color = Color3.fromRGB(210, 210, 210) },
	Uncommon = { Order = 2, SpawnWeight = 45, IncomeMult = 1.5, Color = Color3.fromRGB(110, 230, 110) },
	Rare = { Order = 3, SpawnWeight = 18, IncomeMult = 2.5, Color = Color3.fromRGB(80, 160, 255) },
	Epic = { Order = 4, SpawnWeight = 6, IncomeMult = 5, Color = Color3.fromRGB(190, 90, 255) },
	Legendary = { Order = 5, SpawnWeight = 2, IncomeMult = 10, Color = Color3.fromRGB(255, 170, 30) },
	Mythic = { Order = 6, SpawnWeight = 0.5, IncomeMult = 25, Color = Color3.fromRGB(255, 60, 110) },
	Secret = { Order = 7, SpawnWeight = 0.05, IncomeMult = 100, Color = Color3.fromRGB(30, 30, 30) },
}

RarityConfig.VariantOrder = { "Normal", "Golden", "Diamond", "Rainbow", "Cosmic" }

-- Weight is the base chance (relative). Luck multiplies every weight except Normal.
RarityConfig.Variants = {
	Normal = { Order = 1, Mult = 1, Weight = 1000, Color = nil, Prefix = "" },
	Golden = { Order = 2, Mult = 5, Weight = 30, Color = Color3.fromRGB(255, 205, 40), Prefix = "Golden " },
	Diamond = { Order = 3, Mult = 10, Weight = 8, Color = Color3.fromRGB(120, 235, 255), Prefix = "Diamond " },
	Rainbow = { Order = 4, Mult = 25, Weight = 2, Color = Color3.fromRGB(255, 120, 200), Prefix = "Rainbow ", Rainbow = true },
	Cosmic = { Order = 5, Mult = 100, Weight = 0.3, Color = Color3.fromRGB(140, 80, 255), Prefix = "Cosmic " },
}

-- Weights used for random "Event Objects" (always a fancy variant)
RarityConfig.EventVariantWeights = { Golden = 60, Diamond = 25, Rainbow = 12, Cosmic = 3 }

function RarityConfig.GetRarity(name)
	return RarityConfig.Rarities[name] or RarityConfig.Rarities.Common
end

function RarityConfig.GetVariant(name)
	return RarityConfig.Variants[name] or RarityConfig.Variants.Normal
end

return RarityConfig
