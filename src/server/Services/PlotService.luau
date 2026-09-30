--[[
	Assigns one plot per player on join and hands it back on leave.

	A plot owns the player's three hatch pads, their Sell stand and their Fuse
	Machine, so most other services start from `PlotService.forPlayer`.
]]

local Players = game:GetService("Players")

local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local PlotService = {}

local byPlayer: { [Player]: Folder } = {}
local byPlot: { [Folder]: Player } = {}

local function label(plot: Folder, title: string, subtitle: string, color: Color3)
	local sign = plot:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("Label")
	if not gui then
		return
	end
	local titleLabel = gui:FindFirstChild("Title") :: TextLabel?
	local subLabel = gui:FindFirstChild("Sub") :: TextLabel?
	if titleLabel then
		titleLabel.Text = title
		titleLabel.TextColor3 = color
	end
	if subLabel then
		subLabel.Text = subtitle
	end
end

local function assign(player: Player)
	if byPlayer[player] then
		return byPlayer[player]
	end

	for _, plot in MapBuilder.plots do
		if not byPlot[plot] then
			byPlot[plot] = player
			byPlayer[player] = plot
			plot:SetAttribute("OwnerUserId", player.UserId)

			label(plot, player.DisplayName, "Carry eggs here", Color3.fromRGB(150, 230, 255))

			local spawnPad = plot:FindFirstChild("PlotSpawn") :: SpawnLocation?
			if spawnPad then
				spawnPad.Enabled = true
			end

			player.RespawnLocation = spawnPad
			return plot
		end
	end

	warn(`[PlotService] no free plot for {player.Name}`)
	return nil
end

local function unassign(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end

	byPlayer[player] = nil
	byPlot[plot] = nil
	plot:SetAttribute("OwnerUserId", 0)
	label(plot, "Empty Plot", "Walk in to claim", Color3.fromRGB(200, 205, 220))

	local spawnPad = plot:FindFirstChild("PlotSpawn") :: SpawnLocation?
	if spawnPad then
		spawnPad.Enabled = false
	end

	-- Clear anything left on the pads.
	local pads = plot:FindFirstChild("HatchPads")
	if pads then
		for _, pad in pads:GetChildren() do
			local egg = pad:FindFirstChild("Egg")
			if egg then
				egg:Destroy()
			end
		end
	end
end

function PlotService.forPlayer(player: Player): Folder?
	return byPlayer[player]
end

function PlotService.ownerOf(plot: Folder): Player?
	return byPlot[plot]
end

--- The pad instance for a given index on a player's plot.
function PlotService.padFor(player: Player, padIndex: number): BasePart?
	local plot = byPlayer[player]
	if not plot then
		return nil
	end
	local pads = plot:FindFirstChild("HatchPads")
	return pads and pads:FindFirstChild(`Pad{padIndex}`) :: BasePart?
end

--- Walks up from any descendant to the plot folder that contains it.
function PlotService.plotOf(instance: Instance): Folder?
	local current = instance
	while current and current.Parent do
		if current:GetAttribute("PlotIndex") then
			return current :: Folder
		end
		current = current.Parent
	end
	return nil
end

function PlotService.start()
	Players.PlayerAdded:Connect(assign)
	Players.PlayerRemoving:Connect(unassign)

	for _, player in Players:GetPlayers() do
		assign(player)
	end
end

return PlotService
