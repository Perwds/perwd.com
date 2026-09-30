--[[
	Builds the whole map at runtime.

	Nothing here needs a .rbxl: drop the project on an empty baseplate and you
	get 13 zones laid out along +X, a row of player plots behind spawn, and the
	Shop / Sell / Fuse props. Replace any of it with real geometry later by
	tagging your own parts -- the services look up by name, not by position.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local MapBuilder = {}

local ZONE_SIZE = 220
local ZONE_GAP = 40
local ZONE_STRIDE = ZONE_SIZE + ZONE_GAP
local PLOT_COUNT = 12
local PLOT_SIZE = Vector3.new(44, 1, 52)
local PLOT_GAP = 12
local PLOT_Z = 190 -- behind the Forest zone

MapBuilder.zones = {} :: { [string]: Folder }
MapBuilder.pedestals = {} :: { [string]: { BasePart } }
MapBuilder.plots = {} :: { Folder }

local root: Folder

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

--[[
	`maxDistance` matters more than it looks: twelve plots of six labels each
	all drawing at once turns the base area into unreadable soup. Keep local
	props short-range and save the long distances for landmarks.
]]
local function billboard(
	adornee: BasePart,
	text: string,
	subtext: string?,
	color: Color3?,
	maxDistance: number?
)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(14, 4.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, adornee.Size.Y / 2 + 3.5, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ClipsDescendants = false
	gui.MaxDistance = maxDistance or 120
	gui.Parent = adornee

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, subtext and 0.6 or 1)
	title.Font = Enum.Font.FredokaOne
	title.Text = text
	title.TextColor3 = color or Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.new(0, 0, 0)
	title.TextScaled = true
	title.Parent = gui

	if subtext then
		local sub = Instance.new("TextLabel")
		sub.Name = "Sub"
		sub.BackgroundTransparency = 1
		sub.Position = UDim2.fromScale(0, 0.6)
		sub.Size = UDim2.fromScale(1, 0.4)
		sub.Font = Enum.Font.GothamBold
		sub.Text = subtext
		sub.TextColor3 = Color3.fromRGB(235, 235, 240)
		sub.TextStrokeTransparency = 0.2
		sub.TextStrokeColor3 = Color3.new(0, 0, 0)
		sub.TextScaled = true
		sub.Parent = gui
	end

	return gui
end

MapBuilder.billboard = billboard

--- Zone origin on the X axis.
local function zoneOrigin(world: string): Vector3
	local info = Worlds.get(world)
	return Vector3.new((info.order - 1) * ZONE_STRIDE, 0, 0)
end

MapBuilder.zoneOrigin = zoneOrigin

local function buildZone(world: string): Folder
	local info = Worlds.get(world)
	local origin = zoneOrigin(world)

	local folder = Instance.new("Folder")
	folder.Name = world
	folder:SetAttribute("World", world)
	folder.Parent = root.Zones

	part({
		Name = "Ground",
		Size = Vector3.new(ZONE_SIZE, 2, ZONE_SIZE),
		Position = origin - Vector3.new(0, 1, 0),
		Color = info.ground,
		Material = Enum.Material.Grass,
	}, folder)

	-- Low border wall so players read the zone edge.
	for _, offset in {
		Vector3.new(0, 0, -ZONE_SIZE / 2),
		Vector3.new(0, 0, ZONE_SIZE / 2),
		Vector3.new(-ZONE_SIZE / 2, 0, 0),
		Vector3.new(ZONE_SIZE / 2, 0, 0),
	} do
		local along = math.abs(offset.X) > 0
		part({
			Name = "Border",
			Size = along and Vector3.new(2, 9, ZONE_SIZE) or Vector3.new(ZONE_SIZE, 9, 2),
			Position = origin + offset + Vector3.new(0, 4, 0),
			Color = info.accent,
			Transparency = 0.25,
		}, folder)
	end

	-- Pedestals: wild eggs spawn on these and you run in to take one.
	local pedestals = {}
	local count = info.pedestals
	for i = 1, count do
		local angle = (i - 1) / count * math.pi * 2
		local radius = ZONE_SIZE * 0.3
		local position = origin + Vector3.new(math.cos(angle) * radius, 2, math.sin(angle) * radius)

		local pedestal = part({
			Name = "Pedestal",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 7, 7),
			CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
			Color = info.accent,
			Material = Enum.Material.Slate,
		}, folder)
		pedestal:SetAttribute("World", world)
		pedestal:SetAttribute("SpawnIndex", i)

		table.insert(pedestals, pedestal)
	end
	MapBuilder.pedestals[world] = pedestals

	-- Shop pad: buying eggs for cash happens here.
	local shop = part({
		Name = "ShopPad",
		Size = Vector3.new(14, 1, 14),
		Position = origin + Vector3.new(0, 0.5, -ZONE_SIZE * 0.32),
		Color = Color3.fromRGB(64, 200, 96),
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	}, folder)
	shop:SetAttribute("World", world)
	billboard(shop, `{info.display} Egg`, `{Format.abbreviate(info.eggCost)} cash`, Color3.fromRGB(150, 255, 170), 150)

	-- Zone gate on the -X edge, unlocked with cash.
	if info.unlockCost > 0 then
		local gate = part({
			Name = "Gate",
			Size = Vector3.new(4, 26, 70),
			Position = origin - Vector3.new(ZONE_SIZE / 2 + ZONE_GAP / 2, -12, 0),
			Color = info.accent,
			Material = Enum.Material.ForceField,
			Transparency = 0.45,
			CanCollide = true,
		}, folder)
		gate:SetAttribute("World", world)
		billboard(gate, info.display, `Unlock: {Format.abbreviate(info.unlockCost)}`, Color3.fromRGB(255, 225, 120), 260)
	end

	-- Bridge to the previous zone.
	if info.order > 1 then
		part({
			Name = "Bridge",
			Size = Vector3.new(ZONE_GAP + 4, 2, 24),
			Position = origin - Vector3.new(ZONE_SIZE / 2 + ZONE_GAP / 2, 1, 0),
			Color = info.accent,
			Material = Enum.Material.WoodPlanks,
		}, folder)
	end

	MapBuilder.zones[world] = folder
	return folder
end

--[[
	A player plot: three hatch pads, a Sell stand and a Fuse Machine, matching
	the props in the reference shots. Assigned on join by PlotService.
]]
local function buildPlot(index: number): Folder
	local x = (index - 1 - (PLOT_COUNT - 1) / 2) * (PLOT_SIZE.X + PLOT_GAP)
	local origin = Vector3.new(x, 0, PLOT_Z)

	local folder = Instance.new("Folder")
	folder.Name = `Plot{index}`
	folder:SetAttribute("PlotIndex", index)
	folder:SetAttribute("OwnerUserId", 0)
	folder.Parent = root.Plots

	part({
		Name = "Floor",
		Size = PLOT_SIZE,
		Position = origin - Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(118, 196, 96),
		Material = Enum.Material.Grass,
	}, folder)

	local sign = part({
		Name = "Sign",
		Size = Vector3.new(PLOT_SIZE.X - 8, 1, 1),
		Position = origin + Vector3.new(0, 8, PLOT_SIZE.Z / 2 - 1),
		Color = Color3.fromRGB(60, 62, 78),
	}, folder)
	billboard(sign, "Empty Plot", "Walk in to claim", Color3.fromRGB(200, 205, 220), 120)

	-- Hatch pads.
	local pads = Instance.new("Folder")
	pads.Name = "HatchPads"
	pads.Parent = folder

	for i = 1, Balance.Hatch.PADS_PER_PLOT do
		local padX = (i - (Balance.Hatch.PADS_PER_PLOT + 1) / 2) * 12
		local pad = part({
			Name = `Pad{i}`,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.4, 9, 9),
			CFrame = CFrame.new(origin + Vector3.new(padX, 0.7, -8)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(86, 92, 120),
			Material = Enum.Material.Metal,
		}, folder)
		pad.Name = `Pad{i}`
		pad:SetAttribute("PadIndex", i)
		pad.Parent = pads
		billboard(pad, "Empty", "Carry an egg here", Color3.fromRGB(190, 195, 215), 70)
	end

	-- Sell stand.
	local sell = part({
		Name = "SellStand",
		Size = Vector3.new(12, 1, 12),
		Position = origin + Vector3.new(PLOT_SIZE.X / 2 - 9, 0.6, 12),
		Color = Color3.fromRGB(226, 66, 66),
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	}, folder)
	billboard(sell, "SELL", "Unequipped pets", Color3.fromRGB(255, 120, 120), 80)

	local canopy = part({
		Name = "Canopy",
		Size = Vector3.new(14, 0.8, 14),
		Position = sell.Position + Vector3.new(0, 9, 0),
		Color = Color3.fromRGB(240, 240, 245),
	}, folder)
	canopy.Parent = folder

	-- Fuse machine.
	local fuse = part({
		Name = "FuseMachine",
		Size = Vector3.new(8, 11, 6),
		Position = origin + Vector3.new(-PLOT_SIZE.X / 2 + 8, 5.5, 12),
		Color = Color3.fromRGB(52, 60, 96),
		Material = Enum.Material.Metal,
	}, folder)
	part({
		Name = "FuseScreen",
		Size = Vector3.new(5.5, 6, 0.4),
		Position = fuse.Position + Vector3.new(0, 0.5, -3.1),
		Color = Color3.fromRGB(120, 220, 255),
		Material = Enum.Material.Neon,
	}, folder)
	billboard(fuse, "Fuse Machine", `0/{Balance.Fuse.INPUT_COUNT}`, Color3.fromRGB(150, 220, 255), 80)

	-- Spawn point so a claimed plot is where you respawn.
	local spawnPad = Instance.new("SpawnLocation")
	spawnPad.Name = "PlotSpawn"
	spawnPad.Size = Vector3.new(8, 1, 8)
	spawnPad.Position = origin + Vector3.new(0, 0.6, PLOT_SIZE.Z / 2 - 8)
	spawnPad.Anchored = true
	spawnPad.Neutral = true
	spawnPad.Enabled = false -- enabled once the plot is claimed
	spawnPad.Transparency = 0.4
	spawnPad.BrickColor = BrickColor.new("Bright blue")
	spawnPad.TopSurface = Enum.SurfaceType.Smooth
	spawnPad.Parent = folder

	table.insert(MapBuilder.plots, folder)
	return folder
end

function MapBuilder.build()
	if Workspace:FindFirstChild("Map") then
		Workspace.Map:Destroy()
	end

	root = Instance.new("Folder")
	root.Name = "Map"
	root.Parent = Workspace

	for _, name in { "Zones", "Plots", "Eggs", "Pets", "Effects" } do
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = root
	end

	for _, world in Worlds.Order do
		buildZone(world)
	end

	-- Plaza: the plot row sits behind the Forest zone, and without this the
	-- walk home from the zone edge crosses open void.
	local plazaWidth = PLOT_COUNT * (PLOT_SIZE.X + PLOT_GAP) + 60
	local zoneEdge = ZONE_SIZE / 2
	local plazaFar = PLOT_Z + PLOT_SIZE.Z / 2 + 20
	local plazaDepth = plazaFar - zoneEdge + 20

	part({
		Name = "Plaza",
		Size = Vector3.new(plazaWidth, 2, plazaDepth),
		Position = zoneOrigin("Forest") + Vector3.new(0, -1, (zoneEdge - 20 + plazaFar) / 2),
		Color = Color3.fromRGB(150, 156, 172),
		Material = Enum.Material.Concrete,
	}, root)

	for i = 1, PLOT_COUNT do
		buildPlot(i)
	end

	-- Main spawn, in the Forest zone.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "MainSpawn"
	spawn.Size = Vector3.new(18, 1, 18)
	spawn.Position = zoneOrigin("Forest") + Vector3.new(0, 0.6, 60)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Transparency = 0.3
	spawn.BrickColor = BrickColor.new("Lime green")
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = root

	-- Kill plane: falling off the map respawns rather than falls forever.
	part({
		Name = "Void",
		Size = Vector3.new(ZONE_STRIDE * #Worlds.Order + 400, 4, 800),
		Position = Vector3.new(ZONE_STRIDE * (#Worlds.Order - 1) / 2, -120, 60),
		Transparency = 1,
		CanCollide = false,
		CanTouch = true,
	}, root).Touched:Connect(function(hit)
		local humanoid = hit.Parent and hit.Parent:FindFirstChildWhichIsA("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end)

	root:SetAttribute("PlotCount", PLOT_COUNT)
	return root
end

function MapBuilder.getRoot(): Folder
	return root
end

MapBuilder.PLOT_COUNT = PLOT_COUNT

return MapBuilder
