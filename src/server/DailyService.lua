--!strict
--[[
	DailyService
	One reward per UTC day, with a streak that grows the payout and resets if a
	day is missed. Uses os.time (server clock) so the client can't fast-forward.
]]

local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)

local DailyService = {}

local DAY = 86400
local BASE_REWARD = 750
local STREAK_BONUS = 250
local MAX_STREAK_BONUS = 10

local function dayNumber(unix: number): number
	return math.floor(unix / DAY)
end

function DailyService.rewardFor(streak: number): number
	return BASE_REWARD + math.min(streak, MAX_STREAK_BONUS) * STREAK_BONUS
end

function DailyService.canClaim(profile): boolean
	return dayNumber(os.time()) > dayNumber(profile.lastDaily or 0)
end

function DailyService.secondsUntilNext(profile): number
	local nextDay = (dayNumber(profile.lastDaily or 0) + 1) * DAY
	return math.max(0, nextDay - os.time())
end

function DailyService.claim(player: Player): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end

	if not DailyService.canClaim(profile) then
		StateService.notify(player, "Already claimed today.", "⏳", Color3.fromRGB(255, 180, 90))
		return false
	end

	local today = dayNumber(os.time())
	local last = dayNumber(profile.lastDaily or 0)

	if profile.lastDaily and profile.lastDaily > 0 and today - last == 1 then
		profile.dailyStreak += 1
	else
		profile.dailyStreak = 1
	end

	local multiplier = StateService.coinMultiplierFor(player, profile)
	local reward = math.floor(DailyService.rewardFor(profile.dailyStreak) * multiplier)

	profile.coins += reward
	profile.lastDaily = os.time()

	StateService.notify(
		player,
		("Daily reward: +%d coins (day %d streak)"):format(reward, profile.dailyStreak),
		"🎁",
		Color3.fromRGB(255, 200, 80)
	)
	StateService.markDirty(player)
	return true
end

function DailyService.init()
	StateService.registerProvider("daily", function(player)
		local profile = DataService.get(player)
		if not profile then
			return nil
		end
		return {
			canClaim = DailyService.canClaim(profile),
			streak = profile.dailyStreak,
			reward = DailyService.rewardFor(profile.dailyStreak + 1),
			secondsUntilNext = DailyService.secondsUntilNext(profile),
		}
	end)
end

return DailyService
