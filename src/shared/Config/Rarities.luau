--!nonstrict
-- Rarity tiers. `chance` is the flavour "1 in N" printed on the UI; the roller
-- works off `weight`, which is derived from it. Effective odds drift from the
-- printed number once weights are normalised, so `EffectiveOdds` recomputes the
-- real figure for the index screen rather than lying to the player.

local Rarities = {}

Rarities.Order = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Exotic",
	"Secret",
}

-- luckExponent: how hard the player's luck stat bends this tier. Common sits at
-- 0 so luck only ever moves share *away* from it and into the tail.
Rarities.Data = {
	Common = {
		chance = 2,
		color = Color3.fromRGB(198, 205, 216),
		valueMult = 1,
		luckExponent = 0,
		score = 1,
	},
	Uncommon = {
		chance = 8,
		color = Color3.fromRGB(116, 210, 124),
		valueMult = 2.2,
		luckExponent = 0.25,
		score = 5,
	},
	Rare = {
		chance = 40,
		color = Color3.fromRGB(88, 158, 255),
		valueMult = 5.5,
		luckExponent = 0.45,
		score = 25,
	},
	Epic = {
		chance = 250,
		color = Color3.fromRGB(172, 108, 255),
		valueMult = 16,
		luckExponent = 0.6,
		score = 150,
	},
	Legendary = {
		chance = 1500,
		color = Color3.fromRGB(255, 176, 54),
		valueMult = 60,
		luckExponent = 0.75,
		score = 900,
	},
	Mythic = {
		chance = 12000,
		color = Color3.fromRGB(255, 84, 110),
		valueMult = 240,
		luckExponent = 0.85,
		score = 7000,
	},
	Exotic = {
		chance = 100000,
		color = Color3.fromRGB(80, 245, 230),
		valueMult = 1400,
		luckExponent = 0.95,
		score = 60000,
	},
	Secret = {
		chance = 1000000,
		color = Color3.fromRGB(255, 255, 255),
		valueMult = 9000,
		luckExponent = 1,
		score = 600000,
	},
}

function Rarities.Get(name: string)
	local tier = Rarities.Data[name]
	assert(tier, string.format("unknown rarity %q", tostring(name)))
	return tier
end

-- Base weight before luck is applied.
function Rarities.BaseWeight(name: string): number
	return 1 / Rarities.Get(name).chance
end

-- Weight for a player with the given luck multiplier (1 = no bonus).
function Rarities.WeightWithLuck(name: string, luck: number): number
	local tier = Rarities.Get(name)
	return (1 / tier.chance) * (math.max(luck, 0.01) ^ tier.luckExponent)
end

-- Real "1 in N" for a tier at a given luck level, across the tiers actually
-- reachable in `availableTiers` (a set, or nil for all of them).
function Rarities.EffectiveOdds(name: string, luck: number, availableTiers: { [string]: boolean }?): number
	local total = 0
	for _, tierName in Rarities.Order do
		if availableTiers == nil or availableTiers[tierName] then
			total += Rarities.WeightWithLuck(tierName, luck)
		end
	end

	local own = Rarities.WeightWithLuck(name, luck)
	if own <= 0 or total <= 0 then
		return math.huge
	end

	return total / own
end

function Rarities.IndexOf(name: string): number
	for index, tierName in Rarities.Order do
		if tierName == name then
			return index
		end
	end
	return 0
end

return Rarities
