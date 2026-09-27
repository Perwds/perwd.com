--!strict
--[[
	RebirthConfig
	Rebirth wipes your scans but keeps coins and grants a permanent speed and
	coin boost, plus access to rebirth-locked stats.
]]

local StatConfig = require(script.Parent.StatConfig)

local RebirthConfig = {}

--- Scans you must have completed to rebirth at a given level.
function RebirthConfig.requirement(rebirths: number): number
	local base = math.floor(StatConfig.Count * 0.5)
	return math.min(StatConfig.Count, base + rebirths * 4)
end

--- Coin cost of the next rebirth.
function RebirthConfig.cost(rebirths: number): number
	return math.floor(10000 * (1.85 ^ rebirths))
end

--- Permanent scan-speed multiplier from rebirths (soft-capped).
function RebirthConfig.speedBonus(rebirths: number): number
	return 1 + math.min(rebirths, 25) * 0.12
end

--- Permanent coin multiplier from rebirths.
function RebirthConfig.coinBonus(rebirths: number): number
	return 1 + rebirths * 0.25
end

RebirthConfig.Titles = {
	[0] = "",
	[1] = "Reborn",
	[3] = "Ascended",
	[5] = "Transcendent",
	[10] = "Singularity",
	[20] = "Beyond Stats",
}

function RebirthConfig.title(rebirths: number): string
	local best, bestThreshold = "", -1
	for threshold, title in pairs(RebirthConfig.Titles) do
		if rebirths >= threshold and threshold > bestThreshold then
			bestThreshold = threshold
			best = title
		end
	end
	return best
end

return RebirthConfig
