--!strict
--[[
	AchievementService
	Re-evaluates every unearned achievement whenever the profile changes and
	pays out the coin rewards.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AchievementConfig = require(Shared.AchievementConfig)

local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)

local AchievementService = {}

function AchievementService.evaluate(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local awarded = false

	for _, entry in ipairs(AchievementConfig.List) do
		if not profile.achievements[entry.id] then
			local ok, met = pcall(entry.check, profile)
			if ok and met then
				profile.achievements[entry.id] = true
				profile.coins += entry.reward
				awarded = true
				StateService.notify(
					player,
					("%s  +%d coins"):format(entry.name, entry.reward),
					entry.icon,
					Color3.fromRGB(255, 215, 80)
				)
			end
		end
	end

	if awarded then
		StateService.markDirty(player)
	end
end

return AchievementService
