--!strict
-- Orange trees. Every player has their own ripeness per tree, so nobody steals anyone's oranges.
-- The client draws the fruit; the server decides what is ripe and what a pick is worth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Parent.Data)
local Currency = require(script.Parent.Currency)
local Remotes = require(script.Parent.Remotes)
local RateLimit = require(script.Parent.RateLimit)
local BoardBuilder = require(script.Parent.BoardBuilder)
local UpgradeService = require(script.Parent.UpgradeService)

local GroveService = {}

local MAX_SLOTS = 6
local AUTO_INTERVAL = 0.3

local slots: { [Player]: { [string]: { number } } } = {}
local pickLimit = RateLimit.new(Config.Grove.picksPerSecond, Config.Grove.pickBurst)

local function now(): number
	return workspace:GetServerTimeNow()
end

local function capacity(player: Player): number
	return math.clamp(math.floor(UpgradeService.stats(player).treeCapacity), 1, MAX_SLOTS)
end

local function sendAll(player: Player)
	local s = UpgradeService.stats(player)
	Remotes.fire("Trees", player, slots[player], s.ripenSeconds)
end

local function ensure(player: Player): { [string]: { number } }
	local mine = slots[player]
	local cap = capacity(player)
	if not mine then
		mine = {}
		slots[player] = mine
	end
	local t = now()
	for id in BoardBuilder.trees do
		local list = mine[id] or {}
		while #list < cap do
			table.insert(list, t - 1)
		end
		while #list > cap do
			table.remove(list)
		end
		mine[id] = list
	end
	return mine
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Returns the amount gained, or nil if nothing on that tree is ripe for this player.
local function pickOne(player: Player, treeId: string, auto: boolean): number?
	local tree = BoardBuilder.trees[treeId]
	local data = Data.get(player)
	local mine = slots[player]
	if not tree or not data or not mine then
		return nil
	end
	if tree.vip and not UpgradeService.mods(player).VIP then
		return nil
	end
	local list = mine[treeId]
	local t = now()
	for index, ripeAt in list do
		if ripeAt <= t then
			local s = UpgradeService.stats(player)
			local value = s.pickValue * (if tree.vip then Config.Grove.vipTreeBonus else 1)
			list[index] = t + s.ripenSeconds
			Currency.add(player, "oranges", value)
			data.totalPicks += 1
			Remotes.fire("Picked", player, treeId, index, value, list[index], auto)
			return value
		end
	end
	return nil
end

function GroveService.pick(player: Player, treeId: string, auto: boolean): number?
	return pickOne(player, treeId, auto)
end

function GroveService.init()
	Remotes.on("PickOrange", function(player: Player, treeId: string)
		if not pickLimit:take(player) then
			return
		end
		local tree = BoardBuilder.trees[treeId]
		local root = rootOf(player)
		if not tree or not root or not slots[player] then
			return
		end
		if flatDistance(root.Position, tree.position) > Config.Grove.pickRange then
			return
		end
		if not pickOne(player, treeId, false) then
			-- The client thought something was ripe; set it straight.
			Remotes.fire("TreeUpdate", player, treeId, slots[player][treeId])
		end
	end)

	Data.onLoaded(function(player)
		ensure(player)
		sendAll(player)
	end)

	UpgradeService.onChanged(function(player)
		if slots[player] then
			local before = 0
			for _, list in slots[player] do
				before = #list
				break
			end
			ensure(player)
			if before ~= capacity(player) then
				sendAll(player)
			else
				Remotes.fire("Trees", player, nil, UpgradeService.stats(player).ripenSeconds)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		slots[player] = nil
	end)

	Remotes.on("RequestSync", function(player: Player)
		if slots[player] then
			sendAll(player)
		end
	end)

	-- Auto-collect: Long Arms and the Auto-Picker pass.
	task.spawn(function()
		while true do
			task.wait(AUTO_INTERVAL)
			for player, mine in slots do
				local range = UpgradeService.stats(player).collectRange
				local root = rootOf(player)
				if range > 0 and root then
					local t = now()
					for id, tree in BoardBuilder.trees do
						if flatDistance(root.Position, tree.position) <= range then
							for _, ripeAt in mine[id] do
								if ripeAt <= t then
									if not pickOne(player, id, true) then
										break
									end
								end
							end
						end
					end
				end
			end
		end
	end)
end

return GroveService
