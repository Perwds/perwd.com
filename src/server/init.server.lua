--!strict
--[[
	StatScanner - server bootstrap.

	Wires the services together, owns player lifecycle and validates every
	inbound remote. Nothing the client sends is trusted: ids are looked up in
	config, costs are charged server-side and every handler is rate limited.
]]

local Players = game:GetService("Players")
local TextService = game:GetService("TextService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local StatConfig = require(Shared.StatConfig)
local GamepassConfig = require(Shared.GamepassConfig)
local Format = require(Shared.Format)

local DataService = require(script.DataService)
local StatEngine = require(script.StatEngine)
local GamepassService = require(script.GamepassService)
local StateService = require(script.StateService)
local ScanService = require(script.ScanService)
local AchievementService = require(script.AchievementService)
local DailyService = require(script.DailyService)
local RebirthService = require(script.RebirthService)
local LeaderboardService = require(script.LeaderboardService)
local NametagService = require(script.NametagService)
local PickupService = require(script.PickupService)
local WorldBuilder = require(script.WorldBuilder)

Remotes.init()

-- Rate limiting ----------------------------------------------------------

local lastCall: { [Player]: { [string]: number } } = {}

local function throttled(player: Player, tag: string, minInterval: number): boolean
	local map = lastCall[player]
	if not map then
		map = {}
		lastCall[player] = map
	end

	local now = os.clock()
	if map[tag] and now - map[tag] < minInterval then
		return true
	end

	map[tag] = now
	return false
end

-- Developer product effects ----------------------------------------------

local function grantProduct(player: Player, product): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end

	if product.coins then
		profile.coins += product.coins
		StateService.notify(
			player,
			("+%s coins!"):format(Format.comma(product.coins)),
			"🪙",
			Color3.fromRGB(255, 200, 80)
		)
	elseif product.resetScans then
		ScanService.resetScans(player, true)
		StateService.notify(player, "All scans reset.", "🔄", Color3.fromRGB(120, 200, 255))
	elseif product.instantRebirth then
		RebirthService.perform(player, true)
	else
		return false
	end

	AchievementService.evaluate(player)
	StateService.markDirty(player)
	-- Persist immediately so a crash can't eat a paid purchase.
	DataService.save(player)
	return true
end

-- Boot -------------------------------------------------------------------

DataService.init()
GamepassService.init(grantProduct)
ScanService.init()
DailyService.init()
RebirthService.init()
LeaderboardService.init()
NametagService.init()
PickupService.init()
WorldBuilder.build()

ScanService.onComplete(function(player)
	AchievementService.evaluate(player)
	LeaderboardService.publish(player)
end)

GamepassService.onPurchase(function(player, key)
	local pass = GamepassConfig.ByKey[key]
	StateService.notify(
		player,
		("Thanks for buying %s!"):format(pass and pass.name or key),
		pass and pass.icon or "🎉",
		Color3.fromRGB(255, 215, 80)
	)
	StateService.markDirty(player)
end)

-- Player lifecycle -------------------------------------------------------

local function onPlayerAdded(player: Player)
	local profile = DataService.load(player)
	if not profile then
		return
	end

	GamepassService.refresh(player)

	-- Base metrics need web calls; do them off the join thread.
	task.spawn(function()
		StatEngine.buildBase(player)
		AchievementService.evaluate(player)
		StateService.markDirty(player)
	end)

	StateService.push(player)
	Remotes.event("LeaderboardUpdate"):FireClient(player, LeaderboardService.snapshot())
end

local function onPlayerRemoving(player: Player)
	ScanService.cancelAll(player)
	LeaderboardService.publish(player)
	DataService.release(player)
	StatEngine.clear(player)
	GamepassService.clear(player)
	lastCall[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Remote handlers --------------------------------------------------------

Remotes.fn("GetState").OnServerInvoke = function(player)
	return StateService.build(player)
end

Remotes.fn("GetLeaderboards").OnServerInvoke = function()
	return LeaderboardService.snapshot()
end

Remotes.event("RequestScan").OnServerEvent:Connect(function(player, payload)
	if throttled(player, "scan", 0.15) then
		return
	end
	if type(payload) ~= "table" or type(payload.statId) ~= "string" then
		return
	end

	local ok, reason = ScanService.start(player, payload.statId)
	if not ok and reason then
		StateService.notify(player, reason, "🔒", Color3.fromRGB(255, 160, 90))
	end
end)

Remotes.event("CancelScan").OnServerEvent:Connect(function(player, payload)
	if throttled(player, "cancel", 0.15) then
		return
	end
	if type(payload) ~= "table" or type(payload.statId) ~= "string" then
		return
	end
	ScanService.cancel(player, payload.statId)
end)

Remotes.event("UnlockStat").OnServerEvent:Connect(function(player, payload)
	if throttled(player, "unlock", 0.25) then
		return
	end
	if type(payload) ~= "table" or type(payload.statId) ~= "string" then
		return
	end

	if ScanService.unlock(player, payload.statId) then
		AchievementService.evaluate(player)
	end
end)

Remotes.event("Rebirth").OnServerEvent:Connect(function(player)
	if throttled(player, "rebirth", 1) then
		return
	end
	if RebirthService.perform(player) then
		AchievementService.evaluate(player)
		LeaderboardService.publish(player)
	end
end)

Remotes.event("ClaimDaily").OnServerEvent:Connect(function(player)
	if throttled(player, "daily", 1) then
		return
	end
	if DailyService.claim(player) then
		AchievementService.evaluate(player)
	end
end)

Remotes.event("SetAutoScan").OnServerEvent:Connect(function(player, enabled)
	if throttled(player, "auto", 0.5) then
		return
	end
	ScanService.setAutoScan(player, enabled == true)
end)

Remotes.event("ResetScans").OnServerEvent:Connect(function(player)
	if throttled(player, "reset", 2) then
		return
	end
	ScanService.resetScans(player, true)
	StateService.notify(player, "Scans reset. Coins kept.", "🔄", Color3.fromRGB(120, 200, 255))
end)

Remotes.event("SetDisplayStat").OnServerEvent:Connect(function(player, payload)
	if throttled(player, "pin", 0.4) then
		return
	end
	if type(payload) ~= "table" or type(payload.statId) ~= "string" then
		return
	end
	NametagService.setDisplayStat(player, payload.statId)
end)

Remotes.event("PromptPurchase").OnServerEvent:Connect(function(player, payload)
	if throttled(player, "purchase", 0.5) then
		return
	end
	if type(payload) ~= "table" or type(payload.kind) ~= "string" or type(payload.key) ~= "string" then
		return
	end

	local ok, reason = GamepassService.prompt(player, payload.kind, payload.key)
	if not ok and reason then
		StateService.notify(player, reason, "🚫", Color3.fromRGB(255, 140, 90))
	end
end)

Remotes.event("Flex").OnServerEvent:Connect(function(player, payload)
	if throttled(player, "flex", 8) then
		StateService.notify(player, "Slow down with the flexing.", "⏳", Color3.fromRGB(255, 180, 90))
		return
	end
	if type(payload) ~= "table" or type(payload.statId) ~= "string" then
		return
	end

	local profile = DataService.get(player)
	local stat = StatConfig.get(payload.statId)
	if not profile or not stat then
		return
	end

	local value = profile.values[stat.id]
	if value == nil or not profile.scanned[stat.id] then
		StateService.notify(player, "Scan it before you flex it.", "🔒", Color3.fromRGB(255, 160, 90))
		return
	end

	profile.flexCount = (profile.flexCount or 0) + 1

	local message = stat.flex:format(Format.value(stat.format, value))

	-- Player-authored content never goes out unfiltered; here the text is
	-- entirely from config, but the name is still run through the filter.
	local safeName = player.DisplayName
	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(player.DisplayName, player.UserId)
	end)
	if ok and filtered then
		local okName, result = pcall(function()
			return filtered:GetNonChatStringForBroadcastAsync()
		end)
		if okName then
			safeName = result
		end
	end

	Remotes.event("FlexBroadcast"):FireAllClients({
		kind = "stat",
		player = safeName,
		statId = stat.id,
		icon = stat.icon,
		color = stat.color,
		message = message,
	})

	AchievementService.evaluate(player)
	StateService.markDirty(player)
end)

print("[StatScanner] server ready -", StatConfig.Count, "stats loaded")
