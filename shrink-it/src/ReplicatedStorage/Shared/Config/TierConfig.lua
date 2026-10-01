--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > TierConfig (ModuleScript)

	Size tiers. Each tier lives in its own map area.
	An area opens when your Ray Power level reaches RayPowerRequired, OR when you pay GateCost coins.
	You can only SHRINK objects whose tier <= your Ray Power tier (otherwise: "TOO BIG!").
]]

local TierConfig = {}

TierConfig.Tiers = {
	{
		Name = "Tiny",
		Area = "Suburbs",
		RayPowerRequired = 1,
		GateCost = 0,
		Color = Color3.fromRGB(126, 214, 104),
		RespawnTime = 12,
		AreaDepth = 170, -- studs along the map strip (map width is fixed, see MapService)
		SpawnPoints = 22,
	},
	{
		Name = "Small",
		Area = "Park",
		RayPowerRequired = 5,
		GateCost = 2_500,
		Color = Color3.fromRGB(92, 196, 230),
		RespawnTime = 20,
		AreaDepth = 200,
		SpawnPoints = 18,
	},
	{
		Name = "Medium",
		Area = "Downtown",
		RayPowerRequired = 10,
		GateCost = 60_000,
		Color = Color3.fromRGB(255, 196, 70),
		RespawnTime = 35,
		AreaDepth = 250,
		SpawnPoints = 14,
	},
	{
		Name = "Large",
		Area = "Harbor",
		RayPowerRequired = 16,
		GateCost = 5_000_000,
		Color = Color3.fromRGB(255, 130, 70),
		RespawnTime = 55,
		AreaDepth = 320,
		SpawnPoints = 10,
	},
	{
		Name = "Huge",
		Area = "Skyline",
		RayPowerRequired = 23,
		GateCost = 1_000_000_000,
		Color = Color3.fromRGB(190, 110, 255),
		RespawnTime = 80,
		AreaDepth = 400,
		SpawnPoints = 8,
	},
	{
		Name = "Colossal",
		Area = "Summit",
		RayPowerRequired = 30,
		GateCost = 100_000_000_000,
		Color = Color3.fromRGB(255, 80, 120),
		RespawnTime = 120,
		AreaDepth = 480,
		SpawnPoints = 6,
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
