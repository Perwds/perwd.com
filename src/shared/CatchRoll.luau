--!nonstrict
-- The catch roll, kept pure and free of services so it can be exercised
-- directly by the balance tests in tests/. The server is the only caller that
-- matters; it owns the Random passed in.

local Rarities = require(script.Parent.Config.Rarities)
local Mutations = require(script.Parent.Config.Mutations)
local Fish = require(script.Parent.Config.Fish)
local Rods = require(script.Parent.Config.Rods)
local Zones = require(script.Parent.Config.Zones)
local GameConfig = require(script.Parent.Config.GameConfig)
local Roll = require(script.Parent.Util.Roll)

local CatchRoll = {}

function CatchRoll.Luck(rodId: string, zoneId: string, level: number): number
	local rod = Rods.Get(rodId)
	local zone = Zones.Get(zoneId)
	return rod.luck * zone.luckBonus * (1 + (math.max(level, 1) - 1) * GameConfig.LuckPerLevel)
end

function CatchRoll.Roll(zoneId: string, luck: number, rng: Random)
	local pool = Fish.PoolFor(zoneId)
	local availableTiers = Fish.TiersFor(zoneId)

	local tierWeights = {}
	for tierName in availableTiers do
		tierWeights[tierName] = Rarities.WeightWithLuck(tierName, luck)
	end

	local rarity = Roll.WeightedKeys(tierWeights, Rarities.Order, rng)
	local candidates = pool[rarity]
	local record = candidates[rng:NextInteger(1, #candidates)]

	local mutationWeights = {}
	for _, mutationName in Mutations.Order do
		mutationWeights[mutationName] = Mutations.WeightWithLuck(mutationName, luck)
	end
	local mutation = Roll.WeightedKeys(mutationWeights, Mutations.Order, rng)

	local weight = Roll.Weight(record.minWeight, record.maxWeight, rng)
	local span = math.max(record.maxWeight - record.minWeight, 1e-6)
	local normalized = math.clamp((weight - record.minWeight) / span, 0, 1)
	local weightFactor = 1 + normalized * (GameConfig.WeightValueSpread - 1)

	local rarityData = Rarities.Get(rarity)
	local mutationData = Mutations.Get(mutation)

	local value = math.max(
		1,
		math.floor(record.baseValue * rarityData.valueMult * mutationData.valueMult * weightFactor)
	)

	return {
		fishId = record.id,
		name = record.name,
		rarity = rarity,
		mutation = mutation,
		weight = weight,
		value = value,
		score = rarityData.score * mutationData.scoreMult,
		zone = zoneId,
		odds = Rarities.EffectiveOdds(rarity, luck, availableTiers),
	}
end

-- Display name with the mutation prefix applied.
function CatchRoll.DisplayName(catch): string
	local prefix = Mutations.Get(catch.mutation).prefix
	if prefix == "" then
		return catch.name
	end
	return prefix .. " " .. catch.name
end

return CatchRoll
