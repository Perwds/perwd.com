--[[
	📍 LOCATION: ServerScriptService > Services > MapService (ModuleScript)

	Layout (bird's-eye; you run "up" the corridor and back down to the base):

	          ┌──────────┐  ← end wall
	          │ ZONE 6   │  Summit (820 long)
	          │ ZONE 5   │  Skyline (720)
	          │ ZONE 4   │  Harbor (620)
	          │ ZONE 3   │  Downtown (520)
	          │ ZONE 2   │  Neighborhood (420)
	          │ ZONE 1   │  Grandpa's Backyard (320)
	   ┌──────┴──SAFE────┴──────┐  ← z = 0 (safe-zone line)
	   │ plots   BASE     plots │  spawn, fountain, like sign, leaderboards, VIP lounge
	   └────────────────────────┘

	If Workspace has no "ShrinkItMap", this builds it all (with themed scenery from MapDecor).
	Build your own map later using the SAME names and this service will just read it:

	ShrinkItMap
	├─ Base (Model)  → Floor, SafeZone (invisible Part covering the base), SpawnLocation,
	│                  VIPRoom (invisible region Part), VIPDoor, VIPFountain, LikeSign, Board_<Stat>
	├─ Zones (Folder) → Zone_1..Zone_6 (Model, attr Tier) → Floor (Part), SpawnPoints (Folder of Parts)
	├─ Plots (Folder) → Plot_1..Plot_8 (Model, attr PlotId) → Floor, MuseumBuilding (Model w/ "Sign"), SpawnPad
	└─ LiveObjects (Folder), Chasers (Folder)
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TierConfig = require(Shared.Config.TierConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local GameConfig = require(Shared.Config.GameConfig)
local MapDecor = require(script.Parent.MapDecor)

local MapService = {}
MapService.Areas = {} -- [tier] = { Tier, Model, Floor, SpawnPoints = {Part}, StartZ, EndZ }
MapService.Plots = {} -- [id] = { Id, Model, Floor, Building, Pedestals (Folder), SpawnPad }
MapService.Boards = {} -- [stat] = Part

local CORRIDOR = 200 -- corridor width (x from -100 to 100)
local BASE_W = 420 -- base width
local BASE_D = 420 -- base depth (z from -420 to 0)
local WALL_H = 46
MapService.CorridorWidth = CORRIDOR
MapService.DecorBand = 26 -- outer strip of each zone reserved for scenery

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function surfaceText(target, face, text, color, ppS)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppS or 20
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Parent = label
	return gui, label
end

local function maxObjectSize(tier)
	local m = 4
	for _, id in ipairs(ObjectConfig.IdsForTier(tier, false)) do
		local def = ObjectConfig.Get(id)
		if def.Size then
			m = math.max(m, def.Size.X, def.Size.Z)
		end
	end
	return m
end

-- ── plots ─────────────────────────────────────────────────────────────
-- Plot local space: +Z = front (faces the base's center path), building at the back (-Z).
local function buildPlot(parent, id, cframe)
	local plot = Instance.new("Model")
	plot.Name = "Plot_" .. id
	plot:SetAttribute("PlotId", id)
	plot:SetAttribute("OwnerUserId", 0)
	plot.Parent = parent
	local floor = part({ Name = "Floor", Size = Vector3.new(90, 1, 80), CFrame = cframe * CFrame.new(0, -0.45, 0), Color = Color3.fromRGB(250, 240, 215), Material = Enum.Material.WoodPlanks, Parent = plot })
	-- colored border
	for _, side in ipairs({ -1, 1 }) do
		part({ Name = "Border", Size = Vector3.new(1.5, 1.4, 80), CFrame = floor.CFrame * CFrame.new(side * 45.5, 0.3, 0), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.SmoothPlastic, CanQuery = false, Parent = plot })
	end
	local building = Instance.new("Model")
	building.Name = "MuseumBuilding"
	building:SetAttribute("RaidBuilding", true)
	building:SetAttribute("PlotId", id)
	building.Parent = plot
	local body = part({ Name = "Body", Size = Vector3.new(46, 22, 16), CFrame = floor.CFrame * CFrame.new(0, 11.5, -31), Color = Color3.fromRGB(245, 240, 255), Material = Enum.Material.Marble, Parent = building })
	part({ Name = "Roof", Size = Vector3.new(50, 3, 20), CFrame = floor.CFrame * CFrame.new(0, 24, -31), Color = Color3.fromRGB(255, 95, 95), Parent = building })
	local pediment = Instance.new("WedgePart")
	pediment.Name = "Pediment"
	pediment.Anchored = true
	pediment.Size = Vector3.new(50, 6, 6)
	pediment.CFrame = floor.CFrame * CFrame.new(0, 28.5, -24) * CFrame.Angles(0, math.pi, 0)
	pediment.Color = Color3.fromRGB(255, 95, 95)
	pediment.Parent = building
	for c = -2, 2 do
		part({ Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(22, 2.6, 2.6), CFrame = floor.CFrame * CFrame.new(c * 10, 11.5, -21.5) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Marble, Parent = building })
	end
	building.PrimaryPart = body
	local sign = part({ Name = "Sign", Size = Vector3.new(34, 5, 1), CFrame = floor.CFrame * CFrame.new(0, 19, -22.4), Color = Color3.fromRGB(40, 40, 60), Parent = building })
	surfaceText(sign, Enum.NormalId.Back, "Empty Plot", Color3.new(1, 1, 1))
	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = plot
	part({ Name = "SpawnPad", Size = Vector3.new(10, 1, 10), CFrame = floor.CFrame * CFrame.new(0, 0.1, 47), Color = Color3.fromRGB(90, 200, 255), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = plot })
end

-- ── build ─────────────────────────────────────────────────────────────
local function buildMap()
	local map = Instance.new("Model")
	map.Name = "ShrinkItMap"
	local rng = Random.new(1337)

	-- ── Base (safe zone) ──────────────────────────────────
	local base = Instance.new("Model")
	base.Name = "Base"
	base.Parent = map
	part({ Name = "Floor", Size = Vector3.new(BASE_W, 2, BASE_D), CFrame = CFrame.new(0, -1, -BASE_D / 2), Color = Color3.fromRGB(105, 205, 80), Material = Enum.Material.SmoothPlastic, Parent = base })
	part({ Name = "SafeZone", Size = Vector3.new(BASE_W, 200, BASE_D), CFrame = CFrame.new(0, 99, -BASE_D / 2), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = base })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, -70)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(90, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = base

	-- VIP lounge (back center)
	local vip = Vector3.new(0, 0, -BASE_D + 32)
	local gold = Color3.fromRGB(255, 205, 60)
	part({ Name = "VIPRoom", Size = Vector3.new(70, 24, 52), CFrame = CFrame.new(vip + Vector3.new(0, 12, 0)), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(70, 24, 2), CFrame = CFrame.new(vip + Vector3.new(0, 12, -26)), Color = gold, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(2, 24, 52), CFrame = CFrame.new(vip + Vector3.new(-35, 12, 0)), Color = gold, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(2, 24, 52), CFrame = CFrame.new(vip + Vector3.new(35, 12, 0)), Color = gold, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(23, 24, 2), CFrame = CFrame.new(vip + Vector3.new(-23.5, 12, 26)), Color = gold, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(23, 24, 2), CFrame = CFrame.new(vip + Vector3.new(23.5, 12, 26)), Color = gold, Parent = base })
	part({ Name = "VIPRoof", Size = Vector3.new(72, 2, 54), CFrame = CFrame.new(vip + Vector3.new(0, 25, 0)), Color = gold, Parent = base })
	local door = part({ Name = "VIPDoor", Size = Vector3.new(24, 24, 2), CFrame = CFrame.new(vip + Vector3.new(0, 12, 26)), Color = Color3.fromRGB(255, 230, 120), Material = Enum.Material.ForceField, Transparency = 0.3, Parent = base })
	surfaceText(door, Enum.NormalId.Back, "👑 VIP ONLY", gold)
	local fountain = part({ Name = "VIPFountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 12, 12), CFrame = CFrame.new(vip + Vector3.new(0, 1.5, -6)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Neon, Parent = base })
	local fb = Instance.new("BillboardGui")
	fb.Size = UDim2.fromOffset(220, 60)
	fb.StudsOffset = Vector3.new(0, 6, 0)
	fb.Parent = fountain
	local fl = Instance.new("TextLabel")
	fl.Size = UDim2.fromScale(1, 1)
	fl.BackgroundTransparency = 1
	fl.Font = Enum.Font.FredokaOne
	fl.TextScaled = true
	fl.TextColor3 = Color3.fromRGB(120, 230, 255)
	fl.Text = "💎 VIP Gem Fountain"
	fl.Parent = fb
	Instance.new("UIStroke", fl).Thickness = 2

	-- Like sign & leaderboards (center strip, facing the spawn)
	part({ Name = "LikeSign", Size = Vector3.new(34, 20, 2), CFrame = CFrame.lookAt(Vector3.new(-45, 11, -150), Vector3.new(-45, 11, -60)), Color = Color3.fromRGB(40, 40, 60), Parent = base })
	local stats = { "MuseumValue", "TotalShrinks", "Rebirths", "RaidsWon" }
	for i, stat in ipairs(stats) do
		local x = -57 + (i - 1) * 38
		part({ Name = "Board_" .. stat, Size = Vector3.new(34, 26, 2), CFrame = CFrame.lookAt(Vector3.new(x, 14, -300), Vector3.new(x, 14, 0)), Color = Color3.fromRGB(30, 30, 45), Parent = base })
	end

	-- plots: 4 down each side of the base, fronts facing the center path
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = map
	local id = 0
	for _, zc in ipairs({ -60, -155, -250, -345 }) do
		for _, side in ipairs({ -1, 1 }) do
			id += 1
			if id <= GameConfig.PlotCount then
				-- left plots face +X, right plots face -X
				local cf = CFrame.new(side * 135, 0, zc) * CFrame.Angles(0, side < 0 and math.rad(90) or math.rad(-90), 0)
				buildPlot(plotsFolder, id, cf)
			end
		end
	end

	MapDecor.Base(base, BASE_W, BASE_D)

	-- ── Zones (one long corridor) ─────────────────────────
	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = map
	local z = 0
	for tier, t in ipairs(TierConfig.Tiers) do
		local zone = Instance.new("Model")
		zone.Name = "Zone_" .. tier
		zone:SetAttribute("Tier", tier)
		zone:SetAttribute("AreaName", t.Area)
		zone.Parent = zones
		local depth = t.AreaDepth
		local style = MapDecor.FloorStyle[tier]
		part({ Name = "Floor", Size = Vector3.new(CORRIDOR, 2, depth), CFrame = CFrame.new(0, -1, z + depth / 2), Color = style.Color, Material = style.Material, Parent = zone })
		MapDecor.ZoneArch(zone, tier, t, z, CORRIDOR)
		MapDecor.Zone(zone, tier, z, depth, CORRIDOR)

		-- spawn points (kept out of the scenery strips along the walls)
		local points = Instance.new("Folder")
		points.Name = "SpawnPoints"
		points.Parent = zone
		local size = maxObjectSize(tier)
		local halfX = math.max(8, CORRIDOR / 2 - MapService.DecorBand - size / 2)
		local spacing = size + 10
		local placed = {}
		local tries = 0
		while #placed < t.SpawnPoints and tries < 3000 do
			tries += 1
			local px = rng:NextNumber(-halfX, halfX)
			local pz = rng:NextNumber(z + size / 2 + 22, z + depth - size / 2 - 10)
			local ok = true
			for _, p in ipairs(placed) do
				if (Vector2.new(px, pz) - p).Magnitude < spacing then
					ok = false
					break
				end
			end
			if ok then
				table.insert(placed, Vector2.new(px, pz))
				part({ Name = "SpawnPoint", Size = Vector3.new(2, 1, 2), CFrame = CFrame.new(px, 0.5, pz), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = points })
			end
		end
		z += depth
	end

	-- ── Walls ────────────────────────────────────────────
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = map
	MapDecor.Walls(walls, {
		BaseWidth = BASE_W,
		BaseDepth = BASE_D,
		Corridor = CORRIDOR,
		Height = WALL_H,
		Zones = (function()
			local list, zz = {}, 0
			for tier, t in ipairs(TierConfig.Tiers) do
				table.insert(list, { Tier = tier, StartZ = zz, Depth = t.AreaDepth })
				zz += t.AreaDepth
			end
			return list
		end)(),
	})

	local live = Instance.new("Folder")
	live.Name = "LiveObjects"
	live.Parent = map
	local chasers = Instance.new("Folder")
	chasers.Name = "Chasers"
	chasers.Parent = map

	MapDecor.Lighting()
	map.Parent = workspace
	return map
end

local function readMap(map)
	local base = map:FindFirstChild("Base") or map:WaitForChild("Lobby")
	MapService.Base = base
	MapService.SafeZone = base:FindFirstChild("SafeZone") or base:FindFirstChild("Floor")
	MapService.LobbySpawn = base:FindFirstChild("SpawnLocation")
	MapService.VIPRoom = base:FindFirstChild("VIPRoom")
	MapService.VIPDoor = base:FindFirstChild("VIPDoor")
	MapService.VIPFountain = base:FindFirstChild("VIPFountain")
	MapService.LikeSign = base:FindFirstChild("LikeSign")
	if MapService.VIPDoor then
		CollectionService:AddTag(MapService.VIPDoor, "VIPDoor")
	end
	for _, child in ipairs(base:GetChildren()) do
		local stat = string.match(child.Name, "^Board_(%w+)$")
		if stat then
			MapService.Boards[stat] = child
		end
	end

	local zones = map:FindFirstChild("Zones") or map:FindFirstChild("Areas")
	for _, zone in ipairs(zones and zones:GetChildren() or {}) do
		local tier = zone:GetAttribute("Tier") or tonumber(string.match(zone.Name, "%d+"))
		local floor = zone:FindFirstChild("Floor")
		if tier and floor then
			local points = {}
			local folder = zone:FindFirstChild("SpawnPoints")
			if folder then
				for _, p in ipairs(folder:GetChildren()) do
					if p:IsA("BasePart") then
						table.insert(points, p)
					end
				end
			end
			MapService.Areas[tier] = {
				Tier = tier,
				Model = zone,
				Floor = floor,
				SpawnPoints = points,
				StartZ = floor.Position.Z - floor.Size.Z / 2,
				EndZ = floor.Position.Z + floor.Size.Z / 2,
			}
		end
	end

	for _, plot in ipairs(map:WaitForChild("Plots"):GetChildren()) do
		local id = plot:GetAttribute("PlotId")
		if id then
			local building = plot:FindFirstChild("MuseumBuilding")
			if building then
				building:SetAttribute("RaidBuilding", true)
				building:SetAttribute("PlotId", id)
			end
			local pedestals = plot:FindFirstChild("Pedestals")
			if not pedestals then
				pedestals = Instance.new("Folder")
				pedestals.Name = "Pedestals"
				pedestals.Parent = plot
			end
			MapService.Plots[id] = { Id = id, Model = plot, Floor = plot:FindFirstChild("Floor"), Building = building, Pedestals = pedestals, SpawnPad = plot:FindFirstChild("SpawnPad") }
		end
	end

	local function ensureFolder(name)
		local f = map:FindFirstChild(name)
		if not f then
			f = Instance.new("Folder")
			f.Name = name
			f.Parent = map
		end
		return f
	end
	MapService.LiveObjects = ensureFolder("LiveObjects")
	MapService.ChaserFolder = ensureFolder("Chasers")
end

function MapService.Init(_registry)
	local map = workspace:FindFirstChild("ShrinkItMap") or buildMap()
	readMap(map)
end

function MapService.IsInPart(region, position)
	if not region then
		return false
	end
	local rel = region.CFrame:PointToObjectSpace(position)
	local s = region.Size / 2
	return math.abs(rel.X) <= s.X and math.abs(rel.Y) <= s.Y + 50 and math.abs(rel.Z) <= s.Z
end

-- Is this position inside the base / safe zone?
function MapService.IsInBase(position)
	return MapService.IsInPart(MapService.SafeZone, position)
end

-- Returns the tier of the zone containing `position`, or nil (base).
function MapService.GetAreaAt(position)
	for tier, area in pairs(MapService.Areas) do
		local floor = area.Floor
		local rel = floor.CFrame:PointToObjectSpace(position)
		if math.abs(rel.X) <= floor.Size.X / 2 and math.abs(rel.Z) <= floor.Size.Z / 2 and rel.Y > -10 and rel.Y < 400 then
			return tier
		end
	end
	return nil
end

-- Where you appear when teleporting to a zone.
function MapService.ZoneStartCFrame(tier)
	local area = MapService.Areas[tier]
	if not area then
		return nil
	end
	local f = area.Floor
	return f.CFrame * CFrame.new(0, f.Size.Y / 2 + 4, -f.Size.Z / 2 + 14)
end

-- Random point on a zone's floor, outside the scenery strips. margin = half the object's footprint.
function MapService.RandomPointInArea(tier, margin)
	local area = MapService.Areas[tier]
	if not area then
		return nil
	end
	local f = area.Floor
	local hx = math.max(1, f.Size.X / 2 - MapService.DecorBand - (margin or 10))
	local hz = math.max(1, f.Size.Z / 2 - (margin or 10) - 10)
	local offset = Vector3.new(math.random() * 2 * hx - hx, f.Size.Y / 2, math.random() * 2 * hz - hz)
	return (f.CFrame * CFrame.new(offset)).Position
end

-- Clamps a position into a zone's walkable floor (used to place chasers).
function MapService.ClampToZone(tier, position)
	local area = MapService.Areas[tier]
	if not area then
		return position
	end
	local f = area.Floor
	local rel = f.CFrame:PointToObjectSpace(position)
	local hx, hz = f.Size.X / 2 - 8, f.Size.Z / 2 - 8
	rel = Vector3.new(math.clamp(rel.X, -hx, hx), f.Size.Y / 2 + 3, math.clamp(rel.Z, -hz, hz))
	return (f.CFrame * CFrame.new(rel)).Position
end

return MapService
