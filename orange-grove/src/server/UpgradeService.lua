--!strict
-- Buying nodes and keeping each player's derived stats current.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local UpgradeTree = require(Shared.UpgradeTree)
local Economy = require(Shared.Economy)

local Data = require(script.Parent.Data)
local Currency = require(script.Parent.Currency)
local Remotes = require(script.Parent.Remotes)
local RateLimit = require(script.Parent.RateLimit)
local BoardBuilder = require(script.Parent.BoardBuilder)

local UpgradeService = {}

local econ = Economy.new(Config, UpgradeTree)
UpgradeService.econ = econ

local statsCache: { [Player]: Economy.Stats } = {}
local changedCallbacks: { (Player, Economy.Stats) -> () } = {}
local boughtCallbacks: { (Player, string, number) -> () } = {}
local modsProvider: (Player) -> Economy.Mods = function(_player: Player)
	return {}
end
local buyLimit = RateLimit.new(Config.Grove.buysPerSecond, Config.Grove.buysPerSecond)

function UpgradeService.setModsProvider(provider: (Player) -> Economy.Mods)
	modsProvider = provider
end

function UpgradeService.mods(player: Player): Economy.Mods
	return modsProvider(player)
end

function UpgradeService.stats(player: Player): Economy.Stats
	local cached = statsCache[player]
	if cached then
		return cached
	end
	local data = Data.get(player)
	local s = econ:stats(if data then data.levels else {}, modsProvider(player))
	if data then
		statsCache[player] = s
	end
	return s
end

local function applyWalkSpeed(player: Player, s: Economy.Stats)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = Config.Walk.baseSpeed + s.walkBonus
	end
end

-- Call whenever levels or mods change.
function UpgradeService.refresh(player: Player)
	statsCache[player] = nil
	local s = UpgradeService.stats(player)
	applyWalkSpeed(player, s)
	for _, callback in changedCallbacks do
		task.spawn(callback, player, s)
	end
	Currency.markDirty(player)
end

function UpgradeService.onChanged(callback: (Player, Economy.Stats) -> ())
	table.insert(changedCallbacks, callback)
end

function UpgradeService.onBought(callback: (Player, string, number) -> ())
	table.insert(boughtCallbacks, callback)
end

local function nearPlate(player: Player, nodeId: string): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plate = BoardBuilder.platePosition(nodeId)
	if not root or not plate then
		return false
	end
	return (root.Position - plate).Magnitude <= Config.Grove.plateRange
end

function UpgradeService.buy(player: Player, nodeId: string): (boolean, string)
	local data = Data.get(player)
	local node = UpgradeTree.byId[nodeId]
	if not data or not node then
		return false, "unknown"
	end
	local ok, reason, price = econ:canBuy(data, nodeId, modsProvider(player))
	if not ok then
		return false, reason
	end
	if not Currency.spend(player, node.currency, price) then
		return false, "afford"
	end
	data.levels[nodeId] = (data.levels[nodeId] or 0) + 1
	UpgradeService.refresh(player)
	for _, callback in boughtCallbacks do
		task.spawn(callback, player, nodeId, data.levels[nodeId])
	end
	return true, "ok"
end

function UpgradeService.init()
	Remotes.on("BuyNode", function(player: Player, nodeId: string)
		if not buyLimit:take(player) then
			return
		end
		if not UpgradeTree.byId[nodeId] then
			return
		end
		if not nearPlate(player, nodeId) then
			Remotes.fire("BuyResult", player, nodeId, false, "far")
			return
		end
		local ok, reason = UpgradeService.buy(player, nodeId)
		local data = Data.get(player)
		Remotes.fire("BuyResult", player, nodeId, ok, reason, if data then data.levels[nodeId] or 0 else 0)
		if ok then
			Currency.pushNow(player)
		end
	end)

	local function hookCharacter(player: Player)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
			if humanoid then
				humanoid.WalkSpeed = Config.Walk.baseSpeed + UpgradeService.stats(player).walkBonus
			end
		end)
	end
	Players.PlayerAdded:Connect(hookCharacter)
	for _, player in Players:GetPlayers() do
		hookCharacter(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		statsCache[player] = nil
	end)
end

return UpgradeService
