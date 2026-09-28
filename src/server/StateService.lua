--!strict
--[[
	StateService
	Builds the snapshot the client UI renders from, and pushes it on change.

	Other services register providers instead of StateService reaching into
	them, which keeps the require graph acyclic.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local StatConfig = require(Shared.StatConfig)
local RankConfig = require(Shared.RankConfig)
local RebirthConfig = require(Shared.RebirthConfig)
local GamepassConfig = require(Shared.GamepassConfig)

local DataService = require(script.Parent.DataService)
local GamepassService = require(script.Parent.GamepassService)

local StateService = {}

local providers: { [string]: (Player) -> any } = {}
local pushListeners: { (Player) -> () } = {}
local dirty: { [Player]: boolean } = {}

function StateService.registerProvider(name: string, fn: (Player) -> any)
	providers[name] = fn
end

--- Called after every state push. Used by NametagService, which has to
--- re-render the overhead plate whenever the rank or pinned value moves.
function StateService.onPush(listener: (Player) -> ())
	table.insert(pushListeners, listener)
end

--- Total rank score: heavier stats are worth more.
function StateService.scoreFor(profile): number
	local score = 0
	for statId in pairs(profile.scanned) do
		local stat = StatConfig.get(statId)
		if stat then
			score += math.max(1, math.floor(stat.scanTime / 4))
		end
	end
	score += profile.rebirths * 12
	return score
end

--- Combined scan-speed multiplier: passes x rebirth bonus.
function StateService.speedFor(player: Player, profile): number
	local passes = GamepassService.get(player)
	return GamepassConfig.speedFor(passes) * RebirthConfig.speedBonus(profile.rebirths)
end

function StateService.coinMultiplierFor(player: Player, profile): number
	local passes = GamepassService.get(player)
	return GamepassConfig.coinMultiplierFor(passes) * RebirthConfig.coinBonus(profile.rebirths)
end

function StateService.build(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end

	local passes = GamepassService.get(player)
	local score = StateService.scoreFor(profile)
	local rank, nextRank = RankConfig.forScore(score)

	local state = {
		coins = profile.coins,
		scanned = profile.scanned,
		values = profile.values,
		unlocked = profile.unlocked,
		achievements = profile.achievements,
		rebirths = profile.rebirths,
		totalScans = profile.totalScans,
		dailyStreak = profile.dailyStreak,
		lastDaily = profile.lastDaily,
		autoScan = profile.autoScan,
		displayStat = profile.displayStat or "",
		passes = passes,

		score = score,
		rank = { name = rank.name, icon = rank.icon, color = rank.color },
		nextRank = nextRank and { name = nextRank.name, icon = nextRank.icon, score = nextRank.score } or nil,
		rankProgress = RankConfig.progress(score),
		rebirthTitle = RebirthConfig.title(profile.rebirths),

		speed = StateService.speedFor(player, profile),
		coinMultiplier = StateService.coinMultiplierFor(player, profile),
		slots = GamepassConfig.slotsFor(passes),
		instant = GamepassConfig.hasFlag(passes, "instant"),

		rebirthCost = RebirthConfig.cost(profile.rebirths),
		rebirthRequirement = RebirthConfig.requirement(profile.rebirths),

		serverTime = workspace:GetServerTimeNow(),
	}

	for name, provider in pairs(providers) do
		local ok, result = pcall(provider, player)
		if ok then
			state[name] = result
		end
	end

	return state
end

function StateService.push(player: Player)
	local state = StateService.build(player)
	if state then
		Remotes.event("StateChanged"):FireClient(player, state)
	end

	for _, listener in ipairs(pushListeners) do
		task.spawn(listener, player)
	end
end

--- Coalesces many changes in one frame into a single network push.
function StateService.markDirty(player: Player)
	if dirty[player] then
		return
	end
	dirty[player] = true
	task.defer(function()
		dirty[player] = nil
		if player.Parent then
			StateService.push(player)
		end
	end)
end

function StateService.notify(player: Player, text: string, icon: string?, color: Color3?)
	Remotes.event("Notify"):FireClient(player, {
		text = text,
		icon = icon or "ℹ️",
		color = color or Color3.fromRGB(96, 220, 128),
	})
end

return StateService
