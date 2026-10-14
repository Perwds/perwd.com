--!strict
-- Builds the board from data: zone floors, borders, barriers, upgrade plates and their paths,
-- machine screens, orange trees and the void dressing. Runs once at server start.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local UpgradeTree = require(Shared.UpgradeTree)
local Landmarks = require(script.Parent.Landmarks)

local GRID = Config.Grid
local CELL = GRID.cell
local ZONE = GRID.zoneCells
local BOARD_W = GRID.zonesWide * ZONE * CELL
local BOARD_H = GRID.zonesHigh * ZONE * CELL

export type TreeInfo = { id: string, position: Vector3, vip: boolean, model: Model }

local BoardBuilder = {
	trees = {} :: { [string]: TreeInfo },
	plates = {} :: { [string]: Vector3 },
	machines = {} :: { [string]: Model },
	npcSpots = {} :: { [string]: CFrame },
	pressDrop = Vector3.zero,
	spawnCFrame = CFrame.identity,
	vipEnabled = false,
}

local root: Folder

function BoardBuilder.cellToWorld(gx: number, gy: number): Vector3
	return Vector3.new((gx + 0.5) * CELL - BOARD_W / 2, 0, (gy + 0.5) * CELL - BOARD_H / 2)
end

function BoardBuilder.zoneAt(position: Vector3): string?
	local gx = math.floor((position.X + BOARD_W / 2) / CELL)
	local gy = math.floor((position.Z + BOARD_H / 2) / CELL)
	if gx < 0 or gy < 0 or gx >= GRID.zonesWide * ZONE or gy >= GRID.zonesHigh * ZONE then
		return nil
	end
	local zx, zy = gx // ZONE, gy // ZONE
	for id, zone in Config.Zones do
		if zone.zx == zx and zone.zy == zy then
			if id == "vip" and not BoardBuilder.vipEnabled then
				return nil
			end
			return id
		end
	end
	return nil
end

local function zoneOrigin(zoneId: string): (number, number)
	local zone = Config.Zones[zoneId]
	return zone.zx * ZONE, zone.zy * ZONE
end

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = false
	l.TextWrapped = true
	l.Font = Enum.Font.Arcade
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

------------------------------------------------------------------------------
-- Floors, borders, barriers

local function buildZoneFloor(zoneId: string, folder: Model)
	local colors = Palette.zones[zoneId]
	local ox, oy = zoneOrigin(zoneId)
	local floor = Instance.new("Folder")
	floor.Name = "Floor"
	floor.Parent = folder
	for lx = 0, ZONE - 1 do
		for ly = 0, ZONE - 1 do
			local center = BoardBuilder.cellToWorld(ox + lx, oy + ly)
			part({
				Name = "Tile",
				Size = Vector3.new(CELL, GRID.boardThickness, CELL),
				Position = center - Vector3.new(0, GRID.boardThickness / 2, 0),
				Color = if (lx + ly) % 2 == 0 then colors.floorA else colors.floorB,
				CastShadow = false,
				Parent = floor,
			})
		end
	end
end

local function buildBorders(parent: Folder, zones: { [string]: boolean })
	local borders = Instance.new("Folder")
	borders.Name = "Borders"
	borders.Parent = parent

	local barriers = Instance.new("Folder")
	barriers.Name = "Barriers"
	barriers.Parent = parent

	local zoneW = ZONE * CELL
	local function zoneIdAt(zx: number, zy: number): string?
		for id, zone in Config.Zones do
			if zone.zx == zx and zone.zy == zy and zones[id] then
				return id
			end
		end
		return nil
	end

	-- Every shared edge between two built zones gets a dark seam and a barrier the client switches on.
	for zx = 0, GRID.zonesWide - 1 do
		for zy = 0, GRID.zonesHigh - 1 do
			local here = zoneIdAt(zx, zy)
			if here then
				for _, dir in { { 1, 0 }, { 0, 1 } } do
					local there = zoneIdAt(zx + dir[1], zy + dir[2])
					if there then
						local cx = (zx + 0.5 + dir[1] * 0.5) * zoneW - BOARD_W / 2
						local cz = (zy + 0.5 + dir[2] * 0.5) * zoneW - BOARD_H / 2
						local along = if dir[1] == 1 then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
						local size = along * zoneW + (Vector3.new(1, 0, 1) - along) * 1
						part({
							Name = "Seam",
							Size = size + Vector3.new(0, 0.1, 0),
							Position = Vector3.new(cx, 0.03, cz),
							Color = Palette.border,
							CastShadow = false,
							Parent = borders,
						})
						local barrier = part({
							Name = "Barrier",
							Size = Vector3.new(size.X, 14, size.Z),
							Position = Vector3.new(cx, 7, cz),
							Color = Palette.white,
							Material = Enum.Material.Neon,
							Transparency = 1,
							CanCollide = false,
							CanQuery = false,
							CanTouch = false,
							CastShadow = false,
							Parent = barriers,
						})
						barrier:SetAttribute("ZoneA", here)
						barrier:SetAttribute("ZoneB", there)
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------------
-- Plates and paths

local PLATE_Y = 0.55

local function plateCFrame(node: any): CFrame
	local center = BoardBuilder.cellToWorld(node.gx, node.gy)
	return CFrame.new(center + Vector3.new(0, PLATE_Y, 0)) * CFrame.Angles(math.rad(GRID.plateTilt), 0, 0)
end

local function buildPlate(node: any, parent: Folder)
	local model = Instance.new("Model")
	model.Name = node.id
	model:SetAttribute("NodeId", node.id)
	model:SetAttribute("Zone", node.zone)

	local cf = plateCFrame(node)
	local plate = part({
		Name = "Plate",
		Size = Vector3.new(GRID.plateWidth, 0.6, GRID.plateDepth),
		CFrame = cf,
		Color = Palette.locked,
		Parent = model,
	})
	part({
		Name = "Edge",
		Size = Vector3.new(GRID.plateWidth + 0.8, 0.5, GRID.plateDepth + 0.8),
		CFrame = cf * CFrame.new(0, -0.2, 0),
		Color = Palette.plateEdge,
		Parent = model,
	})
	model.PrimaryPart = plate

	if node.permanent then
		local w, d = GRID.plateWidth + 1.2, GRID.plateDepth + 1.2
		for i, spec in
			{
				{ Vector3.new(w, 0.3, 0.4), Vector3.new(0, 0, -d / 2) },
				{ Vector3.new(w, 0.3, 0.4), Vector3.new(0, 0, d / 2) },
				{ Vector3.new(0.4, 0.3, d), Vector3.new(-w / 2, 0, 0) },
				{ Vector3.new(0.4, 0.3, d), Vector3.new(w / 2, 0, 0) },
			}
		do
			part({
				Name = "Ring" .. i,
				Size = spec[1],
				CFrame = cf * CFrame.new(spec[2] + Vector3.new(0, 0.05, 0)),
				Color = Palette.gold,
				Material = Enum.Material.Neon,
				Parent = model,
			})
		end
	end

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Face"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.MaxDistance = 160
	gui.Parent = plate

	local frame = Instance.new("Frame")
	frame.Name = "Content"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 22)
	pad.PaddingRight = UDim.new(0, 22)
	pad.PaddingTop = UDim.new(0, 18)
	pad.PaddingBottom = UDim.new(0, 16)
	pad.Parent = frame

	label(frame, {
		Name = "Title",
		Text = node.name,
		TextSize = 46,
		Size = UDim2.new(1, 0, 0, 96),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	label(frame, {
		Name = "Effect",
		Text = node.short,
		Font = Enum.Font.RobotoMono,
		TextSize = 34,
		Position = UDim2.fromOffset(0, 104),
		Size = UDim2.new(1, 0, 0, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	label(frame, {
		Name = "Cost",
		Text = "",
		TextSize = 40,
		Position = UDim2.new(0, 0, 1, -48),
		Size = UDim2.new(0.72, 0, 0, 48),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
	})
	label(frame, {
		Name = "Level",
		Text = "0/" .. node.max,
		TextSize = 40,
		Position = UDim2.new(0.72, 0, 1, -48),
		Size = UDim2.new(0.28, 0, 0, 48),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
	})
	label(frame, {
		Name = "Mystery",
		Text = "???",
		TextSize = 72,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Buy"
	prompt.ActionText = "Buy"
	prompt.ObjectText = node.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = plate

	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 20
	click.CursorIcon = ""
	click.Parent = plate

	model.Parent = parent
	BoardBuilder.plates[node.id] = cf.Position
end

local PATH_WIDTH = 2
local PATH_Y = 0.12

local function buildPath(child: any, parentNode: any, parent: Folder)
	local a = BoardBuilder.cellToWorld(parentNode.gx, parentNode.gy)
	local b = BoardBuilder.cellToWorld(child.gx, child.gy)
	local vertical = child.bend and child.bend[parentNode.id] == "v"
	local corner = if vertical then Vector3.new(a.X, 0, b.Z) else Vector3.new(b.X, 0, a.Z)

	local model = Instance.new("Model")
	model.Name = child.id .. "__" .. parentNode.id
	model:SetAttribute("Child", child.id)
	model:SetAttribute("Parent", parentNode.id)
	model:SetAttribute("Zone", child.zone)

	local index = 0
	for _, seg in { { a, corner }, { corner, b } } do
		local from, to = seg[1], seg[2]
		local length = (to - from).Magnitude
		if length > 0.01 then
			index += 1
			local mid = (from + to) / 2
			local isX = math.abs(to.X - from.X) > 0.01
			local p = part({
				Name = "Seg" .. index,
				Size = if isX
					then Vector3.new(length + PATH_WIDTH, 0.24, PATH_WIDTH)
					else Vector3.new(PATH_WIDTH, 0.24, length + PATH_WIDTH),
				Position = mid + Vector3.new(0, PATH_Y, 0),
				Color = Palette.lockedPath,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Parent = model,
			})
			p:SetAttribute("From", from + Vector3.new(0, PATH_Y + 0.2, 0))
			p:SetAttribute("To", to + Vector3.new(0, PATH_Y + 0.2, 0))
		end
	end
	model.Parent = parent
end

------------------------------------------------------------------------------
-- Machines: framed screens standing at an angle

local MACHINES = {
	{ id = "press", zone = "orange", title = "ORANGE PRESS", at = { 22, 17.6 }, face = { 17.5, 17 } },
	{ id = "lab", zone = "vitamin", title = "VITAMIN LAB", at = { 7, 20.2 }, face = { 7, 15 } },
	{ id = "zester", zone = "zest", title = "THE ZESTER", at = { 7.5, 3.6 }, face = { 6, 9 } },
	{ id = "juice", zone = "juice", title = "JUICE BAR", at = { 19.6, 2.8 }, face = { 17, 8 } },
	{ id = "golden", zone = "golden", title = "THE GOLDEN TREE", at = { 31.2, 8.6 }, face = { 26, 8 } },
}

local function buildMachine(spec: any, parent: Instance)
	local colors = Palette.zones[spec.zone]
	local base = BoardBuilder.cellToWorld(spec.at[1], spec.at[2])
	local look = BoardBuilder.cellToWorld(spec.face[1], spec.face[2])
	local facing = CFrame.lookAt(base, Vector3.new(look.X, base.Y, look.Z))

	local model = Instance.new("Model")
	model.Name = spec.id
	model:SetAttribute("Machine", spec.id)
	model:SetAttribute("Zone", spec.zone)

	local W, H = 15, 9.5
	local screenCF = facing * CFrame.new(0, 7.6, 0) * CFrame.Angles(math.rad(14), 0, 0)

	part({
		Name = "Plinth",
		Size = Vector3.new(W + 2, 1.2, 6),
		CFrame = facing * CFrame.new(0, 0.6, 0.6),
		Color = Palette.plateEdge,
		Parent = model,
	})
	part({
		Name = "PlinthTrim",
		Size = Vector3.new(W + 2.2, 0.25, 6.2),
		CFrame = facing * CFrame.new(0, 1.2, 0.6),
		Color = colors.trim,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	for _, x in { -W / 2 + 1.5, W / 2 - 1.5 } do
		part({
			Name = "Leg",
			Size = Vector3.new(1.4, 5, 1.4),
			CFrame = facing * CFrame.new(x, 3.4, 1.4),
			Color = Palette.plateEdge,
			Parent = model,
		})
	end
	part({
		Name = "Bezel",
		Size = Vector3.new(W + 2.4, H + 2.4, 1.6),
		CFrame = screenCF * CFrame.new(0, 0, 0.9),
		Color = colors.plate,
		Parent = model,
	})
	part({
		Name = "BezelTrim",
		Size = Vector3.new(W + 2.6, 0.35, 1.7),
		CFrame = screenCF * CFrame.new(0, H / 2 + 1.25, 0.9),
		Color = colors.trim,
		Material = Enum.Material.Neon,
		Parent = model,
	})
	local screen = part({
		Name = "Screen",
		Size = Vector3.new(W, H, 0.4),
		CFrame = screenCF,
		Color = Palette.screen,
		Parent = model,
	})
	model.PrimaryPart = screen

	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.MaxDistance = 220
	gui.Parent = screen

	local frame = Instance.new("Frame")
	frame.Name = "Content"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 30)
	pad.PaddingRight = UDim.new(0, 30)
	pad.PaddingTop = UDim.new(0, 24)
	pad.PaddingBottom = UDim.new(0, 24)
	pad.Parent = frame

	label(frame, {
		Name = "Title",
		Text = spec.title,
		TextSize = 54,
		TextColor3 = colors.neon,
		Size = UDim2.new(1, 0, 0, 60),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label(frame, {
		Name = "Status",
		Text = "",
		TextSize = 34,
		TextColor3 = Palette.screenDim,
		Size = UDim2.new(0.4, 0, 0, 60),
		Position = UDim2.fromScale(0.6, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	label(frame, {
		Name = "Amount",
		Text = "",
		TextSize = 78,
		TextColor3 = Palette.white,
		Position = UDim2.fromOffset(0, 92),
		Size = UDim2.new(1, 0, 0, 84),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = false,
	})
	label(frame, {
		Name = "Rate",
		Text = "",
		TextSize = 44,
		TextColor3 = colors.neon,
		Position = UDim2.fromOffset(0, 180),
		Size = UDim2.new(1, 0, 0, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	label(frame, {
		Name = "Detail",
		Text = "",
		Font = Enum.Font.RobotoMono,
		TextSize = 30,
		TextColor3 = Palette.white,
		Position = UDim2.fromOffset(0, 250),
		Size = UDim2.new(1, 0, 0, 80),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Palette.hudEdge
	bar.BorderSizePixel = 0
	bar.Position = UDim2.new(0, 0, 1, -26)
	bar.Size = UDim2.new(1, 0, 0, 26)
	bar.Parent = frame
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = colors.neon
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = bar

	if spec.id ~= "press" then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Control"
		prompt.ActionText = if spec.id == "golden" then "Replant" else "Pause"
		prompt.ObjectText = spec.title
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		prompt.HoldDuration = if spec.id == "golden" then 1 else 0
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt.Parent = screen
	end

	if spec.id == "golden" then
		local home = Instance.new("ProximityPrompt")
		home.Name = "Home"
		home.ActionText = "Walk home"
		home.ObjectText = "Back to the Orange Grove"
		home.KeyboardKeyCode = Enum.KeyCode.G
		home.GamepadKeyCode = Enum.KeyCode.ButtonB
		home.HoldDuration = 0.5
		home.MaxActivationDistance = 14
		home.RequiresLineOfSight = false
		home.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
		home.Enabled = false
		home.Parent = model:FindFirstChild("Plinth")
	end

	model.Parent = parent
	BoardBuilder.machines[spec.id] = model
	return model
end

------------------------------------------------------------------------------
-- Orange trees

local SLOT_OFFSETS = {
	Vector3.new(3.2, 0.6, 1.4),
	Vector3.new(-2.8, 1.2, 2.2),
	Vector3.new(0.6, -0.4, -3.4),
	Vector3.new(-1.8, 2.6, -1.6),
	Vector3.new(2.4, 2.4, -1.2),
	Vector3.new(-3.2, -0.2, -0.6),
}

local function buildTree(id: string, cell: { number }, vip: boolean, parent: Instance)
	local base = BoardBuilder.cellToWorld(cell[1], cell[2])
	local turn = CFrame.Angles(0, math.rad((#id * 37 + cell[1] * 53 + cell[2] * 29) % 360), 0)
	local cf = CFrame.new(base) * turn

	local model = Instance.new("Model")
	model.Name = id
	model:SetAttribute("TreeId", id)
	model:SetAttribute("Vip", vip)

	local trunk = part({
		Name = "Trunk",
		Size = Vector3.new(1.8, 6, 1.8),
		CFrame = cf * CFrame.new(0, 3, 0),
		Color = Palette.bark,
		Parent = model,
	})
	part({
		Name = "Root",
		Size = Vector3.new(3, 0.8, 3),
		CFrame = cf * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = Palette.bark,
		Parent = model,
	})
	local canopy = part({
		Name = "Canopy",
		Size = Vector3.new(8, 5, 8),
		CFrame = cf * CFrame.new(0, 8, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = if vip then Color3.fromRGB(48, 120, 70) else Palette.leaf,
		Parent = model,
	})
	part({
		Name = "Crown",
		Size = Vector3.new(5, 3, 5),
		CFrame = cf * CFrame.new(0.6, 11.4, -0.4) * CFrame.Angles(0, math.rad(20), 0),
		Color = Palette.leafDark,
		Parent = model,
	})
	part({
		Name = "Tuft",
		Size = Vector3.new(4, 3, 4),
		CFrame = cf * CFrame.new(-2.4, 9.4, 1.8) * CFrame.Angles(0, math.rad(-15), 0),
		Color = Palette.leafDark,
		Parent = model,
	})
	for i, offset in SLOT_OFFSETS do
		local attachment = Instance.new("Attachment")
		attachment.Name = "Slot" .. i
		attachment.WorldPosition = (cf * CFrame.new(0, 8, 0)).Position + (turn:VectorToWorldSpace(offset) * 1.12)
		attachment.Parent = canopy
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Pick"
	prompt.ActionText = "Pick"
	prompt.ObjectText = if vip then "Back Orchard Tree" else "Orange Tree"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = trunk

	model.PrimaryPart = trunk
	model.Parent = parent
	BoardBuilder.trees[id] = { id = id, position = base, vip = vip, model = model }
end

------------------------------------------------------------------------------
-- Void dressing

local function buildVoid(parent: Instance)
	local drift = part({
		Name = "Drift",
		Size = Vector3.new(BOARD_W + 200, 1, BOARD_H + 200),
		Position = Vector3.new(0, 70, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = parent,
	})
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Rate = 14
	motes.Lifetime = NumberRange.new(18, 26)
	motes.Speed = NumberRange.new(0.4, 1.2)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.Size = NumberSequence.new(0.35)
	motes.LightEmission = 1
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.55),
		NumberSequenceKeypoint.new(0.8, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	motes.Color = ColorSequence.new(Color3.fromRGB(200, 200, 255))
	motes.Acceleration = Vector3.new(0, -0.05, 0)
	motes.Parent = drift

	for i, depth in { -160, -320 } do
		local deep = part({
			Name = "Stars" .. i,
			Size = Vector3.new(BOARD_W * 3, 1, BOARD_H * 3),
			Position = Vector3.new(0, depth, 0),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Parent = parent,
		})
		local twinkle = Instance.new("ParticleEmitter")
		twinkle.Name = "Twinkle"
		twinkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		twinkle.Rate = 40
		twinkle.Lifetime = NumberRange.new(6, 12)
		twinkle.Speed = NumberRange.new(0)
		twinkle.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 2.2 * i),
			NumberSequenceKeypoint.new(1, 0),
		})
		twinkle.LightEmission = 1
		twinkle.Color = ColorSequence.new(Color3.fromRGB(235, 235, 255))
		twinkle.Parent = deep
	end
end

------------------------------------------------------------------------------

function BoardBuilder.build(options: { vip: boolean })
	BoardBuilder.vipEnabled = options.vip

	root = Instance.new("Folder")
	root.Name = "Board"

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = root

	local built: { [string]: boolean } = {}
	for _, zoneId in Config.ZoneOrder do
		if zoneId ~= "vip" or options.vip then
			built[zoneId] = true
			local model = Instance.new("Model")
			model.Name = zoneId
			model:SetAttribute("Zone", zoneId)
			buildZoneFloor(zoneId, model)
			local landmarks = Instance.new("Model")
			landmarks.Name = "Landmarks"
			landmarks.Parent = model
			Landmarks.build(zoneId, landmarks, BoardBuilder.cellToWorld, part)
			model.Parent = zonesFolder
		end
	end
	buildBorders(root, built)

	local plates = Instance.new("Folder")
	plates.Name = "Plates"
	plates.Parent = root
	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = root
	for _, node in UpgradeTree.nodes do
		buildPlate(node, plates)
		for _, parentId in node.parents do
			buildPath(node, UpgradeTree.byId[parentId], paths)
		end
	end

	local machines = Instance.new("Folder")
	machines.Name = "Machines"
	machines.Parent = root
	for _, spec in MACHINES do
		buildMachine(spec, zonesFolder:FindFirstChild(spec.zone) or machines)
	end

	local trees = Instance.new("Folder")
	trees.Name = "Trees"
	trees.Parent = root
	for i, cell in Config.Orchard do
		buildTree("t" .. i, cell, false, trees)
	end
	if options.vip then
		for i, cell in Config.VipOrchard do
			buildTree("v" .. i, cell, true, trees)
		end
	end

	local spawnPos = BoardBuilder.cellToWorld(17, 18) + Vector3.new(CELL / 2, 0, 0)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 0.4, 8)
	spawn.Position = spawnPos + Vector3.new(0, 0.2, 0)
	spawn.Color = Palette.zones.orange.plate
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Neutral = true
	spawn.Duration = 0
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = root
	BoardBuilder.spawnCFrame = CFrame.lookAt(spawnPos + Vector3.new(0, 3, 0), spawnPos + Vector3.new(0, 3, -10))

	BoardBuilder.npcSpots.keeper =
		CFrame.lookAt(BoardBuilder.cellToWorld(20.6, 18.4) + Vector3.new(0, 3, 0), spawnPos + Vector3.new(0, 3, 0))
	BoardBuilder.npcSpots.juiceWorker = CFrame.lookAt(
		BoardBuilder.cellToWorld(14.5, 1.6) + Vector3.new(0, 3, 0),
		BoardBuilder.cellToWorld(14.5, 4) + Vector3.new(0, 3, 0)
	)
	BoardBuilder.pressDrop = BoardBuilder.cellToWorld(21, 19)

	buildVoid(root)
	root.Parent = workspace
	return root
end

function BoardBuilder.platePosition(nodeId: string): Vector3?
	return BoardBuilder.plates[nodeId]
end

function BoardBuilder.machinePosition(machineId: string): Vector3?
	local model = BoardBuilder.machines[machineId]
	return if model and model.PrimaryPart then model.PrimaryPart.Position else nil
end

return BoardBuilder
