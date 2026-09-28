--!strict
--[[
	ScanService
	Owns the scan loop: availability, slots, timers, rewards and auto-scanning.

	The server holds the authoritative timer. The client is told when a scan
	will finish purely so it can animate a progress bar; it can't shorten one by
	lying, because completion is driven by a server-side task.delay.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local StatConfig = require(Shared.StatConfig)
local GamepassConfig = require(Shared.GamepassConfig)

local DataService = require(script.Parent.DataService)
local GamepassService = require(script.Parent.GamepassService)
local StateService = require(script.Parent.StateService)
local StatEngine = require(script.Parent.StatEngine)

local ScanService = {}

local MIN_DURATION = 0.35 -- keeps the bar visible even at 10x
local COINS_PER_SECOND = 55
local FIRST_TIME_BONUS = 2
local RESCAN_PENALTY = 0.25

-- [userId] = { [statId] = { endsAt, duration, thread } }
local active: { [number]: { [string]: any } } = {}
local onScanComplete: { (Player, string, number, boolean) -> () } = {}

function ScanService.onComplete(callback)
	table.insert(onScanComplete, callback)
end

local function activeFor(player: Player)
	local map = active[player.UserId]
	if not map then
		map = {}
		active[player.UserId] = map
	end
	return map
end

local function activeCount(player: Player): number
	local count = 0
	for _ in pairs(activeFor(player)) do
		count += 1
	end
	return count
end

-- Availability -----------------------------------------------------------

--- Why a stat can't be scanned yet, or nil when it is available.
function ScanService.lockReason(player: Player, stat): string?
	local profile = DataService.get(player)
	if not profile then
		return "Profile still loading."
	end

	if profile.unlocked[stat.id] then
		return nil
	end

	local unlock = stat.unlock

	if unlock.kind == "free" then
		return nil
	elseif unlock.kind == "coins" then
		return ("Unlock for %d coins."):format(unlock.amount or 0)
	elseif unlock.kind == "scans" then
		if profile.totalScans >= (unlock.amount or 0) then
			return nil
		end
		return ("Complete %d scans to unlock (%d/%d)."):format(
			unlock.amount or 0,
			profile.totalScans,
			unlock.amount or 0
		)
	elseif unlock.kind == "rebirth" then
		if profile.rebirths >= (unlock.amount or 0) then
			return nil
		end
		return ("Requires %d rebirth(s)."):format(unlock.amount or 0)
	elseif unlock.kind == "gamepass" then
		local passes = GamepassService.get(player)
		if passes[unlock.pass or ""] or GamepassConfig.hasFlag(passes, "unlockAll") then
			return nil
		end
		local pass = GamepassConfig.ByKey[unlock.pass or ""]
		return ("Requires the %s gamepass."):format(pass and pass.name or "?")
	end

	return "Locked."
end

function ScanService.isAvailable(player: Player, stat): boolean
	return ScanService.lockReason(player, stat) == nil
end

--- Buys a coin-locked stat.
function ScanService.unlock(player: Player, statId: string)
	local stat = StatConfig.get(statId)
	local profile = DataService.get(player)
	if not stat or not profile then
		return false
	end

	if profile.unlocked[statId] or stat.unlock.kind ~= "coins" then
		return false
	end

	local cost = stat.unlock.amount or 0
	if profile.coins < cost then
		StateService.notify(player, "Not enough coins.", "🚫", Color3.fromRGB(255, 110, 110))
		return false
	end

	profile.coins -= cost
	profile.unlocked[statId] = true

	StateService.notify(player, ("Unlocked %s!"):format(stat.name), stat.icon, stat.color)
	StateService.markDirty(player)
	return true
end

-- Duration ---------------------------------------------------------------

function ScanService.durationFor(player: Player, stat): number
	local profile = DataService.get(player)
	if not profile then
		return stat.scanTime
	end

	local passes = GamepassService.get(player)
	if GamepassConfig.hasFlag(passes, "instant") then
		return 0
	end

	local speed = StateService.speedFor(player, profile)
	return math.max(MIN_DURATION, stat.scanTime / speed)
end

-- Running a scan ---------------------------------------------------------

local function finish(player: Player, statId: string)
	local map = activeFor(player)
	local session = map[statId]
	map[statId] = nil

	local profile = DataService.get(player)
	local stat = StatConfig.get(statId)
	if not profile or not stat or not session then
		return
	end

	local value = StatEngine.compute(player, statId)
	if value == nil then
		StateService.notify(player, "Scan failed, try again.", "⚠️", Color3.fromRGB(255, 140, 90))
		StateService.markDirty(player)
		return
	end

	local isNew = not profile.scanned[statId]

	profile.scanned[statId] = true
	profile.values[statId] = value
	profile.totalScans += 1

	local multiplier = StateService.coinMultiplierFor(player, profile)
	local reward = stat.scanTime * COINS_PER_SECOND * multiplier
	reward *= isNew and FIRST_TIME_BONUS or RESCAN_PENALTY
	reward = math.floor(reward)

	profile.coins += reward

	Remotes.event("ScanFinished"):FireClient(player, {
		statId = statId,
		value = value,
		coins = reward,
		isNew = isNew,
	})

	for _, callback in ipairs(onScanComplete) do
		task.spawn(callback, player, statId, value, isNew)
	end

	StateService.markDirty(player)
end

function ScanService.start(player: Player, statId: string): (boolean, string?)
	local stat = StatConfig.get(statId)
	if not stat then
		return false, "Unknown stat."
	end

	local profile = DataService.get(player)
	if not profile then
		return false, "Still loading your data."
	end

	local map = activeFor(player)
	if map[statId] then
		return false, "Already scanning that."
	end

	local reason = ScanService.lockReason(player, stat)
	if reason then
		return false, reason
	end

	local slots = GamepassConfig.slotsFor(GamepassService.get(player))
	if activeCount(player) >= slots then
		return false, ("All %d scan slot(s) busy."):format(slots)
	end

	local duration = ScanService.durationFor(player, stat)

	if duration <= 0 then
		map[statId] = { endsAt = workspace:GetServerTimeNow(), duration = 0 }
		finish(player, statId)
		return true
	end

	local endsAt = workspace:GetServerTimeNow() + duration
	local session = { endsAt = endsAt, duration = duration }
	map[statId] = session

	session.thread = task.delay(duration, function()
		if player.Parent and activeFor(player)[statId] == session then
			finish(player, statId)
		end
	end)

	Remotes.event("ScanStarted"):FireClient(player, {
		statId = statId,
		duration = duration,
		endsAt = endsAt,
	})

	StateService.markDirty(player)
	return true
end

function ScanService.cancel(player: Player, statId: string)
	local map = activeFor(player)
	local session = map[statId]
	if not session then
		return false
	end

	if session.thread then
		task.cancel(session.thread)
	end
	map[statId] = nil

	StateService.markDirty(player)
	return true
end

function ScanService.cancelAll(player: Player)
	for statId in pairs(activeFor(player)) do
		ScanService.cancel(player, statId)
	end
end

-- Auto scan --------------------------------------------------------------

local function autoScanLoop(player: Player)
	while player.Parent do
		task.wait(0.75)

		local profile = DataService.get(player)
		if not profile or not profile.autoScan then
			continue
		end
		if not GamepassService.has(player, "autoScan") then
			continue
		end

		local slots = GamepassConfig.slotsFor(GamepassService.get(player))
		local free = slots - activeCount(player)
		if free <= 0 then
			continue
		end

		for _, stat in ipairs(StatConfig.Stats) do
			if free <= 0 then
				break
			end
			if not profile.scanned[stat.id] and ScanService.isAvailable(player, stat) then
				local started = ScanService.start(player, stat.id)
				if started then
					free -= 1
				end
			end
		end
	end
end

function ScanService.setAutoScan(player: Player, enabled: boolean)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	if enabled and not GamepassService.has(player, "autoScan") then
		StateService.notify(player, "Auto Scanner gamepass required.", "🤖", Color3.fromRGB(255, 160, 90))
		return
	end

	profile.autoScan = enabled
	StateService.notify(
		player,
		enabled and "Auto scanner ON." or "Auto scanner OFF.",
		"🤖",
		Color3.fromRGB(130, 230, 180)
	)
	StateService.markDirty(player)
end

--- Wipes scan progress (rebirth, or the reset developer product).
function ScanService.resetScans(player: Player, keepValues: boolean?)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	ScanService.cancelAll(player)
	profile.scanned = {}
	if not keepValues then
		profile.values = {}
	end
	StateService.markDirty(player)
end

function ScanService.init()
	StateService.registerProvider("activeScans", function(player)
		local out = {}
		for statId, session in pairs(activeFor(player)) do
			out[statId] = { endsAt = session.endsAt, duration = session.duration }
		end
		return out
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(autoScanLoop, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(autoScanLoop, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		ScanService.cancelAll(player)
		active[player.UserId] = nil
	end)
end

return ScanService
