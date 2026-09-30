--[[
	Prompts on world props: the Shop pad, the Sell stand, the Fuse Machine and
	the zone gates. Each one either performs its action directly or asks the
	client to open the matching panel.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)
local PlotService = require(script.Parent.PlotService)
local ShopService = require(script.Parent.ShopService)

local PropService = {}

local openUI = Net.Event("OpenUI")
local notify = Net.Event("Notify")

local function attachPrompt(part: BasePart, config: { [string]: any }, onTrigger: (Player) -> ())
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = config.name or "Prompt"
	prompt.ActionText = config.actionText
	prompt.ObjectText = config.objectText
	prompt.HoldDuration = config.hold or 0.2
	prompt.MaxActivationDistance = config.distance or 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(onTrigger)
	return prompt
end

local function setupZone(world: string, zone: Folder)
	local info = Worlds.get(world)

	local shopPad = zone:FindFirstChild("ShopPad") :: BasePart?
	if shopPad then
		attachPrompt(shopPad, {
			name = "ShopPrompt",
			actionText = "Open Shop",
			objectText = `{info.display} Egg`,
			distance = 14,
		}, function(player)
			openUI:FireClient(player, "shop", { world = world })
		end)
	end

	local gate = zone:FindFirstChild("Gate") :: BasePart?
	if gate then
		attachPrompt(gate, {
			name = "GatePrompt",
			actionText = "Unlock",
			objectText = `{info.display} -- {Format.abbreviate(info.unlockCost)}`,
			hold = 0.8,
			distance = 16,
		}, function(player)
			local result = ShopService.unlockWorld(player, world)
			if not result.ok then
				notify:FireClient(player, "warn", result.error)
			end
		end)
	end
end

local function setupPlot(plot: Folder)
	local sell = plot:FindFirstChild("SellStand") :: BasePart?
	if sell then
		attachPrompt(sell, {
			name = "SellPrompt",
			actionText = "Sell Pets",
			objectText = "Sell Stand",
			distance = 14,
		}, function(player)
			if PlotService.forPlayer(player) ~= plot then
				notify:FireClient(player, "warn", "Use your own stand")
				return
			end
			openUI:FireClient(player, "sell")
		end)
	end

	local fuse = plot:FindFirstChild("FuseMachine") :: BasePart?
	if fuse then
		attachPrompt(fuse, {
			name = "FusePrompt",
			actionText = "Fuse",
			objectText = `Fuse Machine 0/{Balance.Fuse.INPUT_COUNT}`,
			distance = 14,
		}, function(player)
			if PlotService.forPlayer(player) ~= plot then
				notify:FireClient(player, "warn", "Use your own machine")
				return
			end
			openUI:FireClient(player, "fuse")
		end)
	end
end

--[[
	Gates are solid for everyone on the server. Making one pass-through for a
	single player has to happen on that player's client, so the server only
	publishes ownership as a Player attribute and the client acts on it.
]]
local function publishWorlds(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	for _, world in Worlds.Order do
		player:SetAttribute(`World_{world}`, profile.worlds[world] == true)
	end
end

function PropService.start()
	for world, zone in MapBuilder.zones do
		setupZone(world, zone)
	end

	for _, plot in MapBuilder.plots do
		setupPlot(plot)
	end

	DataService.ProfileLoaded:Connect(publishWorlds)
	for _, player in Players:GetPlayers() do
		publishWorlds(player)
	end
end

return PropService
