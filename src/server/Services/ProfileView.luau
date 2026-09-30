--!nonstrict
-- Turns a stored profile into the payload the client renders. Derived values
-- (level, luck, unlocks, odds) are computed here rather than on the client so
-- there is exactly one source of truth for them.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Rods = require(Shared.Config.Rods)
local Zones = require(Shared.Config.Zones)

local FishingService = require(script.Parent.FishingService)

local ProfileView = {}

function ProfileView.Build(profile)
	local level = GameConfig.LevelForXp(profile.xp)

	-- Spend the cumulative curve to find where we sit inside the current level.
	local remaining = profile.xp
	for pastLevel = 1, level - 1 do
		remaining -= GameConfig.XpForLevel(pastLevel)
	end
	local needed = GameConfig.XpForLevel(level)

	local rods = {}
	for _, rodId in Rods.Order do
		local rod = Rods.Get(rodId)
		table.insert(rods, {
			id = rodId,
			name = rod.name,
			cost = rod.cost,
			luck = rod.luck,
			owned = profile.rods[rodId] == true,
			equipped = profile.equippedRod == rodId,
		})
	end

	local zones = {}
	for _, zoneId in Zones.Order do
		local zone = Zones.Get(zoneId)
		table.insert(zones, {
			id = zoneId,
			name = zone.name,
			blurb = zone.blurb,
			unlockCoins = zone.unlockCoins,
			luckBonus = zone.luckBonus,
			unlocked = Zones.IsUnlocked(zoneId, profile.lifetimeCoins),
			current = profile.zone == zoneId,
		})
	end

	local inventory = {}
	local bagValue = 0
	for _, entry in profile.inventory do
		bagValue += entry.value
		table.insert(inventory, {
			uid = entry.uid,
			fishId = entry.fishId,
			rarity = entry.rarity,
			mutation = entry.mutation,
			weight = entry.weight,
			value = entry.value,
		})
	end

	return {
		coins = profile.coins,
		lifetimeCoins = profile.lifetimeCoins,
		level = level,
		xpInLevel = math.max(remaining, 0),
		xpForLevel = needed,
		luck = FishingService.LuckFor(profile),
		equippedRod = profile.equippedRod,
		zone = profile.zone,
		rods = rods,
		zones = zones,
		inventory = inventory,
		bagValue = bagValue,
		bagLimit = GameConfig.MaxInventory,
		index = profile.index,
		stats = profile.stats,
	}
end

return ProfileView
