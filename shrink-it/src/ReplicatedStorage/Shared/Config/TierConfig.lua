--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > TierConfig (ModuleScript)

	Size tiers. Each tier lives in its own map area.
	The map is one long corridor: your base, then zone 1, zone 2 ... zone 6, each a bit longer than the last (10 zones).
	Every zone is open and EVERY object can be shrunk at any Ray Power. RayPowerRequired is the power
	at which that tier charges at normal speed: less power = slower charge, more power = faster
	(see GameConfig.PowerChargeExponent). Each zone has its own chaser (see ChaserConfig).
]]

local TierConfig = {}

TierConfig.Tiers = {
	{ Name = "Tiny", Area = "Grandpa's Backyard", RayPowerRequired = 1, Color = Color3.fromRGB(126, 214, 104), RespawnTime = 12, AreaDepth = 150, SpawnPoints = 16 },
	{ Name = "Small", Area = "Neighborhood", RayPowerRequired = 4, Color = Color3.fromRGB(92, 196, 230), RespawnTime = 18, AreaDepth = 160, SpawnPoints = 16 },
	{ Name = "Medium", Area = "Downtown", RayPowerRequired = 8, Color = Color3.fromRGB(255, 196, 70), RespawnTime = 26, AreaDepth = 170, SpawnPoints = 15 },
	{ Name = "Large", Area = "Harbor", RayPowerRequired = 12, Color = Color3.fromRGB(255, 130, 70), RespawnTime = 36, AreaDepth = 180, SpawnPoints = 14 },
	{ Name = "Big", Area = "Desert", RayPowerRequired = 15, Color = Color3.fromRGB(240, 200, 110), RespawnTime = 45, AreaDepth = 190, SpawnPoints = 13 },
	{ Name = "Huge", Area = "Jungle", RayPowerRequired = 18, Color = Color3.fromRGB(70, 190, 90), RespawnTime = 55, AreaDepth = 200, SpawnPoints = 12 },
	{ Name = "Giant", Area = "Skyline", RayPowerRequired = 21, Color = Color3.fromRGB(190, 110, 255), RespawnTime = 70, AreaDepth = 210, SpawnPoints = 11 },
	{ Name = "Mega", Area = "Volcano", RayPowerRequired = 24, Color = Color3.fromRGB(255, 90, 40), RespawnTime = 85, AreaDepth = 220, SpawnPoints = 10 },
	{ Name = "Titan", Area = "Summit", RayPowerRequired = 27, Color = Color3.fromRGB(220, 240, 255), RespawnTime = 100, AreaDepth = 230, SpawnPoints = 9 },
	{ Name = "Cosmic", Area = "Outer Space", RayPowerRequired = 30, Color = Color3.fromRGB(120, 90, 255), RespawnTime = 120, AreaDepth = 240, SpawnPoints = 8 },
}

function TierConfig.Get(tier)
	return TierConfig.Tiers[tier]
end

-- Highest tier a given Ray Power level can shrink.
function TierConfig.MaxTierForRayPower(level)
	local best = 1
	for i, t in ipairs(TierConfig.Tiers) do
		if level >= t.RayPowerRequired then
			best = i
		end
	end
	return best
end

return TierConfig
