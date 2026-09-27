--!strict
--[[
	RankConfig
	Titles awarded from total scan score. Score is the sum of every scanned
	stat's tier weight, so completionists climb even without spending Robux.
]]

local RankConfig = {}

local C = Color3.fromRGB

RankConfig.Ranks = {
	{ score = 0, name = "Noob", icon = "🥚", color = C(180, 180, 180) },
	{ score = 3, name = "Curious", icon = "🔍", color = C(160, 200, 230) },
	{ score = 8, name = "Scanner", icon = "📡", color = C(120, 200, 255) },
	{ score = 15, name = "Analyst", icon = "📈", color = C(120, 230, 190) },
	{ score = 24, name = "Statistician", icon = "🧮", color = C(150, 220, 120) },
	{ score = 34, name = "Flexer", icon = "💪", color = C(255, 200, 100) },
	{ score = 44, name = "Grinder", icon = "⛏️", color = C(255, 160, 90) },
	{ score = 55, name = "Veteran", icon = "🎗️", color = C(255, 130, 130) },
	{ score = 70, name = "Obsessed", icon = "🌀", color = C(220, 130, 255) },
	{ score = 90, name = "Data Hoarder", icon = "🗄️", color = C(180, 140, 255) },
	{ score = 115, name = "No Life", icon = "💀", color = C(255, 110, 160) },
	{ score = 145, name = "Legend", icon = "🏆", color = C(255, 215, 80) },
	{ score = 190, name = "Omniscient", icon = "👁️", color = C(255, 255, 255) },
}

function RankConfig.forScore(score: number)
	local current = RankConfig.Ranks[1]
	local nextRank = nil

	for index, rank in ipairs(RankConfig.Ranks) do
		if score >= rank.score then
			current = rank
			nextRank = RankConfig.Ranks[index + 1]
		else
			break
		end
	end

	return current, nextRank
end

--- 0..1 progress towards the next rank (1 when maxed).
function RankConfig.progress(score: number): number
	local current, nextRank = RankConfig.forScore(score)
	if not nextRank then
		return 1
	end
	local span = nextRank.score - current.score
	if span <= 0 then
		return 1
	end
	return math.clamp((score - current.score) / span, 0, 1)
end

return RankConfig
