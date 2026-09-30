--!nonstrict
-- Builds the whole map from Zones config at boot. Nothing in the place file is
-- load-bearing, so the game syncs from source into an empty baseplate and runs.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)

local MapBuilder = {}

MapBuilder.WaterTag = "FishingWater"

local ROOT_NAME = "FishingWorld"
local WATER_LEVEL = 0
local DECK_HEIGHT = 7

local function part(props): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth

	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end

	instance.Parent = props.Parent
	return instance
end

-- A Cylinder part points down its X axis, so a flat disc needs the roll.
local function disc(props): Part
	local instance = part(props)
	instance.Shape = Enum.PartType.Cylinder
	return instance
end

local function discCFrame(position: Vector3): CFrame
	return CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
end

local function label(parent: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(18, 3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 400
	gui.Parent = parent

	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextStrokeTransparency = 0.4
	textLabel.TextScaled = true
	textLabel.Parent = gui
end

local function buildZone(root: Folder, zoneId: string)
	local zone = Zones.Get(zoneId)

	local folder = Instance.new("Folder")
	folder.Name = zoneId
	folder.Parent = root

	-- Water ------------------------------------------------------------------
	local water = disc({
		Name = "Water",
		Size = Vector3.new(6, zone.radius * 2, zone.radius * 2),
		CFrame = discCFrame(zone.origin + Vector3.new(0, WATER_LEVEL, 0)),
		Color = zone.waterColor,
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		Reflectance = 0.15,
		CanCollide = true,
		Parent = folder,
	})
	water:SetAttribute("Zone", zoneId)
	CollectionService:AddTag(water, MapBuilder.WaterTag)

	-- Deck the player stands on ----------------------------------------------
	local deckRadius = zone.radius * 0.42
	local deck = disc({
		Name = "Deck",
		Size = Vector3.new(DECK_HEIGHT, deckRadius * 2, deckRadius * 2),
		CFrame = discCFrame(zone.origin + Vector3.new(0, DECK_HEIGHT / 2, 0)),
		Color = zone.accentColor,
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})

	-- Rim so nobody walks off the edge by accident.
	disc({
		Name = "Rim",
		Size = Vector3.new(1.4, deckRadius * 2 + 6, deckRadius * 2 + 6),
		CFrame = discCFrame(zone.origin + Vector3.new(0, DECK_HEIGHT + 0.7, 0)),
		Color = zone.accentColor:Lerp(Color3.new(0, 0, 0), 0.35),
		Material = Enum.Material.Wood,
		Parent = folder,
	})

	-- Pier out over the water, so casting has an obvious direction ------------
	local pierLength = zone.radius * 0.5
	part({
		Name = "Pier",
		Size = Vector3.new(14, 1.5, pierLength),
		CFrame = CFrame.new(zone.origin + Vector3.new(0, DECK_HEIGHT, deckRadius + pierLength / 2)),
		Color = zone.accentColor:Lerp(Color3.new(0, 0, 0), 0.2),
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})

	-- Sign --------------------------------------------------------------------
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(2, 10, 2),
		CFrame = CFrame.new(zone.origin + Vector3.new(-deckRadius * 0.6, DECK_HEIGHT + 5, 0)),
		Color = Color3.fromRGB(92, 68, 48),
		Material = Enum.Material.Wood,
		Parent = folder,
	})
	label(sign, zone.name, zone.accentColor)

	return folder
end

function MapBuilder.Build(): Folder
	local existing = Workspace:FindFirstChild(ROOT_NAME)
	if existing then
		existing:Destroy()
	end

	local root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root.Parent = Workspace

	for _, zoneId in Zones.Order do
		buildZone(root, zoneId)
	end

	-- Spawn on the starter deck.
	local startZone = Zones.Get(Zones.Default())
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(startZone.origin + Vector3.new(0, DECK_HEIGHT + 0.5, -20))
	spawn.Color = startZone.accentColor
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.25
	spawn.Parent = root

	return root
end

return MapBuilder
