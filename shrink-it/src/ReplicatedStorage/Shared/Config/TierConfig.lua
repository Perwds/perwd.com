--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > TierConfig (ModuleScript)

	Size tiers. Each tier lives in its own map area.
	The map is one long corridor: your base, then zone 1, zone 2 ... zone 6, each longer than the last.
	Every zone is open and EVERY object can be shrunk at any Ray Power. RayPowerRequired is the power
	at which that tier charges at normal speed: less power = slower charge, more power = faster
	(see GameConfig.PowerChargeExponent). Each zone has its own chaser (see ChaserConfig).
]]

local TierConfig = {}

TierConfig.Tiers = {
	{
		Name = "Tiny",
		Area = "Grandpa's Backyard",
		RayPowerRequired = 1,
		Color = Color3.fromRGB(126, 214, 104),
		RespawnTime = 12,
		AreaDepth = 160, -- studs along the corridor (corridor width is fixed, see MapService)
		SpawnPoints = 18,
	},
	{
		Name = "Small",
		Area = "Neighborhood",
		RayPowerRequired = 5,
		Color = Color3.fromRGB(92, 196, 230),
		RespawnTime = 20,
		AreaDepth = 190,
		SpawnPoints = 18,
	},
	{
		Name = "Medium",
		Area = "Downtown",
		RayPowerRequired = 10,
		Color = Color3.fromRGB(255, 196, 70),
		RespawnTime = 35,
		AreaDepth = 220,
		SpawnPoints = 16,
	},
	{
		Name = "Large",
		Area = "Harbor",
		RayPowerRequired = 16,
		Color = Color3.fromRGB(255, 130, 70),
		RespawnTime = 55,
		AreaDepth = 250,
		SpawnPoints = 13,
	},
	{
		Name = "Huge",
		Area = "Skyline",
		RayPowerRequired = 23,
		Color = Color3.fromRGB(190, 110, 255),
		RespawnTime = 80,
		AreaDepth = 280,
		SpawnPoints = 10,
	},
	{
		Name = "Colossal",
		Area = "Summit",
		RayPowerRequired = 30,
		Color = Color3.fromRGB(255, 80, 120),
		RespawnTime = 120,
		AreaDepth = 310,
		SpawnPoints = 8,
	},
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
