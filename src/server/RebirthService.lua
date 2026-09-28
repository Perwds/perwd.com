--!strict
--[[
	RebirthService
	Spends coins + scan progress for a permanent speed and coin multiplier and
	access to rebirth-gated stats.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RebirthConfig = require(Shared.RebirthConfig)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local ScanService = require(script.Parent.ScanService)
local StateService = require(script.Parent.StateService)

local RebirthService = {}

local function scannedCount(profile): number
	local count = 0
	for _ in pairs(profile.scanned) do
		count += 1
	end
	return count
end

--- nil when the player may rebirth, otherwise the blocking reason.
function RebirthService.blocker(profile): string?
	local needed = RebirthConfig.requirement(profile.rebirths)
	local have = scannedCount(profile)
	if have < needed then
		return ("Scan %d stats first (%d/%d)."):format(needed, have, needed)
	end

	local cost = RebirthConfig.cost(profile.rebirths)
	if profile.coins < cost then
		return ("Costs %d coins (you have %d)."):format(cost, profile.coins)
	end

	return nil
end

function RebirthService.perform(player: Player, free: boolean?): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end

	if not free then
		local blocker = RebirthService.blocker(profile)
		if blocker then
			StateService.notify(player, blocker, "🚫", Color3.fromRGB(255, 110, 110))
			return false
		end
		profile.coins -= RebirthConfig.cost(profile.rebirths)
	end

	profile.rebirths += 1
	-- Scan flags reset; cached values stay so the collection log keeps history.
	ScanService.resetScans(player, true)

	local title = RebirthConfig.title(profile.rebirths)
	StateService.notify(
		player,
		("REBIRTH %d! %s"):format(profile.rebirths, title ~= "" and title or ""),
		"🌟",
		Color3.fromRGB(255, 215, 80)
	)

	Remotes.event("FlexBroadcast"):FireAllClients({
		kind = "rebirth",
		player = player.Name,
		rebirths = profile.rebirths,
	})

	StateService.markDirty(player)
	return true
end

function RebirthService.init()
	StateService.registerProvider("rebirth", function(player)
		local profile = DataService.get(player)
		if not profile then
			return nil
		end
		return {
			blocker = RebirthService.blocker(profile),
			cost = RebirthConfig.cost(profile.rebirths),
			requirement = RebirthConfig.requirement(profile.rebirths),
			scannedCount = scannedCount(profile),
			nextSpeed = RebirthConfig.speedBonus(profile.rebirths + 1),
			nextCoins = RebirthConfig.coinBonus(profile.rebirths + 1),
		}
	end)
end

return RebirthService
