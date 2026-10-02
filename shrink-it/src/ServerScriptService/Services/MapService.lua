--[[
	📍 LOCATION: ServerScriptService > Services > MapService (ModuleScript)

	Layout (bird's-eye). Base and corridor are the SAME width, so every plot has an equally
	long, straight run to the zones (fair for everyone):

	  ┌───────────────────────────────────┐  ← end wall
	  │ ZONE 6 Summit … ZONE 1 Grandpa's  │  one long corridor, each zone longer than the last
	  ├────────────── SAFE LINE ──────────┤  ← z = 0 (chasers stop here)
	  │  SELL   FUSE   spawn  TRAILS  SHOP │  plaza with stands (ProximityPrompts open menus)
	  │ [P1] [P2] [P3] [P4] [P5] [P6]      │  6 fenced plots in one row, far back
	  └───────────────────────────────────┘

	Ground is Roblox Terrain (real grass blades) when GameConfig.Ground == "Terrain";
	the Floor parts then only mark the zone bounds (invisible, non-colliding).

	If Workspace has no "ShrinkItMap", this builds it all (with themed scenery from MapDecor).
	Build your own map later using the SAME names and this service will just read it:

	ShrinkItMap
	├─ Base (Model)  → Floor, SafeZone (invisible Part covering the base), SpawnLocation,
	│                  VIPRoom (invisible region Part), VIPDoor, VIPFountain, LikeSign, Board_<Stat>,
	│                  Stands (Folder: stalls with a ProximityPrompt that has attribute OpensMenu)
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

local CORRIDOR = 464 -- corridor width = base width (x from -232 to 232; multiple of 4 for terrain)
local BASE_W = CORRIDOR
local BASE_D = 184 -- base depth (z from -184 to 0)
local WALL_H = 46
local PLOT_W, PLOT_D = 70, 95
local PLOT_SPACING = 72
local PLOT_FRONT_Z = -70 -- plots sit far back; the plaza with the stands is in front of them
MapService.CorridorWidth = CORRIDOR
MapService.DecorBand = 30 -- outer strip of each zone reserved for scenery

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
-- Plot local space: +Z = front (faces the plaza / zones), temple at the back (-Z).
local MARBLE = Color3.fromRGB(246, 243, 236)
local GOLD = Color3.fromRGB(240, 190, 60)
local WOOD = Color3.fromRGB(150, 100, 60)

local function local_(floor, x, y, z)
	return floor.CFrame * CFrame.new(x, y, z)
end

local function buildPlot(parent, id, cframe)
	local plot = Instance.new("Model")
	plot.Name = "Plot_" .. id
	plot:SetAttribute("PlotId", id)
	plot:SetAttribute("OwnerUserId", 0)
	plot.Parent = parent
	local floor = part({ Name = "Floor", Size = Vector3.new(PLOT_W, 1, PLOT_D), CFrame = cframe * CFrame.new(0, -0.45, 0), Color = Color3.fromRGB(235, 228, 215), Material = Enum.Material.Marble, Parent = plot })
	local hw, hd = PLOT_W / 2, PLOT_D / 2
	local zb = -hd -- back edge (temple is built relative to this)

	-- wooden fence around the plot with an entrance gap at the front
	local function fenceRun(x1, z1, x2, z2)
		local a, b = Vector3.new(x1, 0, z1), Vector3.new(x2, 0, z2)
		local len = (b - a).Magnitude
		local mid = local_(floor, (x1 + x2) / 2, 0, (z1 + z2) / 2)
		local look = CFrame.lookAt(mid.Position, (local_(floor, x2, 0, z2)).Position)
		for _, y in ipairs({ 1.6, 3.0 }) do
			part({ Name = "FenceRail", Size = Vector3.new(0.35, 0.45, len), CFrame = look * CFrame.new(0, y, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, CanQuery = false, Parent = plot })
		end
		local posts = math.max(1, math.floor(len / 6))
		for i = 0, posts do
			local p = a:Lerp(b, i / posts)
			part({ Name = "FencePost", Size = Vector3.new(0.6, 3.8, 0.6), CFrame = local_(floor, p.X, 2.0, p.Z), Color = WOOD:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Wood, CanQuery = false, Parent = plot })
		end
	end
	fenceRun(-hw, -hd, hw, -hd)
	fenceRun(-hw, -hd, -hw, hd)
	fenceRun(hw, -hd, hw, hd)
	fenceRun(-hw, hd, -9, hd)
	fenceRun(9, hd, hw, hd)
	for _, s in ipairs({ -1, 1 }) do -- gate pillars with gold caps
		part({ Name = "GatePillar", Size = Vector3.new(1.6, 6, 1.6), CFrame = local_(floor, s * 9, 3, hd), Color = MARBLE, Material = Enum.Material.Marble, CanQuery = false, Parent = plot })
		part({ Name = "GateCap", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = local_(floor, s * 9, 6.6, hd), Color = GOLD, Material = Enum.Material.Metal, CanQuery = false, Parent = plot })
	end

	-- ── the museum building (Greek temple) at the back ──
	local building = Instance.new("Model")
	building.Name = "MuseumBuilding"
	building:SetAttribute("RaidBuilding", true)
	building:SetAttribute("PlotId", id)
	building.Parent = plot
	local function b(props)
		props.Parent = building
		return part(props)
	end
	local zf = zb + 22 -- temple front line (old layout: -18 with a back edge at -40)
	for i, step in ipairs({ { 50, 22, 0.5 }, { 48, 21, 1.0 }, { 46, 20, 1.5 } }) do
		b({ Name = "Step" .. i, Size = Vector3.new(step[1], 0.5, step[2]), CFrame = local_(floor, 0, step[3] + 0.25, zf - 11 + (22 - step[2]) / 2), Color = MARBLE:Lerp(Color3.new(0.6, 0.6, 0.6), 0.1 * (3 - i)), Material = Enum.Material.Marble })
	end
	local body = b({ Name = "Body", Size = Vector3.new(42, 18, 13), CFrame = local_(floor, 0, 11, zf - 15), Color = MARBLE, Material = Enum.Material.Marble })
	for c = 0, 5 do
		local x = -20 + c * 8
		b({ Name = "ColumnBase", Size = Vector3.new(3, 0.8, 3), CFrame = local_(floor, x, 2.4, zf - 5.5), Color = MARBLE, Material = Enum.Material.Marble })
		b({ Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(17, 2.2, 2.2), CFrame = local_(floor, x, 11.3, zf - 5.5) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Marble })
		for f = 0, 3 do
			b({ Name = "Flute", Size = Vector3.new(0.12, 16.6, 2.3), CFrame = local_(floor, x, 11.3, zf - 5.5) * CFrame.Angles(0, math.rad(f * 45), 0), Color = Color3.fromRGB(225, 222, 215), Material = Enum.Material.Marble, CanQuery = false })
		end
		b({ Name = "Capital", Size = Vector3.new(3.4, 1, 3.4), CFrame = local_(floor, x, 20.2, zf - 5.5), Color = MARBLE, Material = Enum.Material.Marble })
		b({ Name = "CapitalGold", Size = Vector3.new(3.5, 0.25, 3.5), CFrame = local_(floor, x, 19.6, zf - 5.5), Color = GOLD, Material = Enum.Material.Metal })
	end
	b({ Name = "Entablature", Size = Vector3.new(47, 2.6, 19), CFrame = local_(floor, 0, 22, zf - 13), Color = MARBLE, Material = Enum.Material.Marble })
	b({ Name = "GoldBand", Size = Vector3.new(47.3, 0.45, 19.3), CFrame = local_(floor, 0, 20.9, zf - 13), Color = GOLD, Material = Enum.Material.Metal })
	for _, s in ipairs({ -1, 1 }) do
		local roof = Instance.new("WedgePart")
		roof.Name = "Roof"
		roof.Anchored = true
		roof.Size = Vector3.new(19, 7, 23.5)
		roof.CFrame = local_(floor, s * -11.75, 26.8, zf - 13) * CFrame.Angles(0, math.rad(s * 90), 0)
		roof.Color = Color3.fromRGB(200, 70, 60)
		roof.Material = Enum.Material.Slate
		roof.Parent = building
		local tymp = Instance.new("WedgePart")
		tymp.Name = "Tympanum"
		tymp.Anchored = true
		tymp.CanQuery = false
		tymp.Size = Vector3.new(0.3, 5.6, 19)
		tymp.CFrame = local_(floor, s * -9.5, 26.1, zf - 3.4) * CFrame.Angles(0, math.rad(s * 90), 0)
		tymp.Color = Color3.fromRGB(40, 70, 150)
		tymp.Material = Enum.Material.Fabric
		tymp.Parent = building
	end
	b({ Name = "Emblem", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 2.6, 2.6), CFrame = local_(floor, 0, 25.8, zf - 3.1) * CFrame.Angles(0, math.rad(90), 0), Color = GOLD, Material = Enum.Material.Metal, CanQuery = false })
	b({ Name = "DoorFrame", Size = Vector3.new(9.5, 12, 0.4), CFrame = local_(floor, 0, 8, zf - 8.35), Color = GOLD, Material = Enum.Material.Metal })
	b({ Name = "Door", Size = Vector3.new(8.4, 11, 0.5), CFrame = local_(floor, 0, 7.6, zf - 8.25), Color = Color3.fromRGB(120, 180, 220), Material = Enum.Material.Glass, Transparency = 0.25, Reflectance = 0.3 })
	b({ Name = "DoorSplit", Size = Vector3.new(0.3, 11, 0.6), CFrame = local_(floor, 0, 7.6, zf - 8.2), Color = GOLD, Material = Enum.Material.Metal })
	for _, x in ipairs({ -16, 16 }) do
		b({ Name = "WindowFrame", Size = Vector3.new(4.6, 8.6, 0.3), CFrame = local_(floor, x, 10, zf - 8.4), Color = GOLD, Material = Enum.Material.Metal })
		b({ Name = "Window", Size = Vector3.new(4, 8, 0.4), CFrame = local_(floor, x, 10, zf - 8.3), Color = Color3.fromRGB(150, 205, 240), Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.3 })
		b({ Name = "Banner", Size = Vector3.new(3, 9, 0.2), CFrame = local_(floor, x * 0.5, 13, zf - 8.45), Color = Color3.fromRGB(190, 30, 45), Material = Enum.Material.Fabric })
		b({ Name = "BannerTrim", Size = Vector3.new(3.2, 0.4, 0.3), CFrame = local_(floor, x * 0.5, 17.4, zf - 8.45), Color = GOLD, Material = Enum.Material.Metal })
		b({ Name = "BannerStar", Size = Vector3.new(1.4, 1.4, 0.25), CFrame = local_(floor, x * 0.5, 13.5, zf - 8.55) * CFrame.Angles(0, 0, math.rad(45)), Color = GOLD, Material = Enum.Material.Metal, CanQuery = false })
	end
	building.PrimaryPart = body
	local sign = b({ Name = "Sign", Size = Vector3.new(30, 2.2, 0.3), CFrame = local_(floor, 0, 22, zf - 3.4), Color = Color3.fromRGB(35, 35, 55), Material = Enum.Material.SmoothPlastic })
	surfaceText(sign, Enum.NormalId.Back, "Empty Plot", Color3.fromRGB(255, 225, 120), 30)

	-- planters at the front corners, lamps by the temple
	for _, s in ipairs({ -1, 1 }) do
		part({ Name = "Planter", Size = Vector3.new(3.4, 2, 3.4), CFrame = local_(floor, s * (hw - 3), 1.5, hd - 3), Color = MARBLE, Material = Enum.Material.Marble, CanQuery = false, Parent = plot })
		part({ Name = "Shrub", Shape = Enum.PartType.Ball, Size = Vector3.new(3.2, 3.2, 3.2), CFrame = local_(floor, s * (hw - 3), 3.7, hd - 3), Color = Color3.fromRGB(70, 160, 70), Material = Enum.Material.SmoothPlastic, CanQuery = false, Parent = plot })
		local post = part({ Name = "LampPost", Size = Vector3.new(0.6, 10, 0.6), CFrame = local_(floor, s * (hw - 3), 5.5, zf), Color = Color3.fromRGB(40, 40, 50), Material = Enum.Material.Metal, CanQuery = false, Parent = plot })
		local bulb = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.8, 1.8, 1.8), CFrame = post.CFrame * CFrame.new(0, 5.6, 0), Color = Color3.fromRGB(255, 235, 170), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = plot })
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Color = Color3.fromRGB(255, 225, 170)
		light.Parent = bulb
	end

	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = plot
	part({ Name = "SpawnPad", Size = Vector3.new(10, 1, 10), CFrame = floor.CFrame * CFrame.new(0, 0.1, hd + 7), Color = Color3.fromRGB(90, 200, 255), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Transparency = 0.3, Parent = plot })
end

-- ── build ─────────────────────────────────────────────────────────────
local function buildMap()
	local map = Instance.new("Model")
	map.Name = "ShrinkItMap"
	local rng = Random.new(1337)
	local terrainGround = GameConfig.Ground == "Terrain"
	MapDecor.UsingTerrain = terrainGround
	local hiddenFloor = terrainGround and { Transparency = 1, CanCollide = false } or {}
	local function floorPart(props)
		for k, v in pairs(hiddenFloor) do
			props[k] = v
		end
		return part(props)
	end

	-- ── Base (safe zone) ──────────────────────────────────
	local base = Instance.new("Model")
	base.Name = "Base"
	base.Parent = map
	floorPart({ Name = "Floor", Size = Vector3.new(BASE_W, 2, BASE_D), CFrame = CFrame.new(0, -1, -BASE_D / 2), Color = Color3.fromRGB(105, 205, 80), Material = Enum.Material.SmoothPlastic, Parent = base })
	part({ Name = "SafeZone", Size = Vector3.new(BASE_W, 200, BASE_D), CFrame = CFrame.new(0, 99, -BASE_D / 2), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = base })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, -36)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(90, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.3
	spawn.Parent = base

	-- VIP corner (right side of the plaza), door faces the plaza
	local vip = Vector3.new(BASE_W / 2 - 24, 0, -38)
	local gold = Color3.fromRGB(255, 205, 60)
	part({ Name = "VIPRoom", Size = Vector3.new(44, 24, 52), CFrame = CFrame.new(vip + Vector3.new(0, 12, 0)), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(44, 24, 2), CFrame = CFrame.new(vip + Vector3.new(0, 12, -26)), Color = gold, Material = Enum.Material.Marble, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(44, 24, 2), CFrame = CFrame.new(vip + Vector3.new(0, 12, 26)), Color = gold, Material = Enum.Material.Marble, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(2, 24, 15), CFrame = CFrame.new(vip + Vector3.new(-22, 12, -18.5)), Color = gold, Material = Enum.Material.Marble, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(2, 24, 15), CFrame = CFrame.new(vip + Vector3.new(-22, 12, 18.5)), Color = gold, Material = Enum.Material.Marble, Parent = base })
	part({ Name = "VIPRoof", Size = Vector3.new(46, 2, 54), CFrame = CFrame.new(vip + Vector3.new(0, 25, 0)), Color = gold, Material = Enum.Material.Marble, Parent = base })
	local door = part({ Name = "VIPDoor", Size = Vector3.new(2, 24, 22), CFrame = CFrame.new(vip + Vector3.new(-22, 12, 0)), Color = Color3.fromRGB(255, 230, 120), Material = Enum.Material.ForceField, Transparency = 0.3, Parent = base })
	surfaceText(door, Enum.NormalId.Left, "👑 VIP ONLY", gold)
	local fountain = part({ Name = "VIPFountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 12, 12), CFrame = CFrame.new(vip + Vector3.new(6, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Neon, Parent = base })
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

	-- Like sign on the back wall (center), leaderboards on the side walls
	part({ Name = "LikeSign", Size = Vector3.new(44, 24, 2), CFrame = CFrame.lookAt(Vector3.new(0, 40, -BASE_D + 1), Vector3.new(0, 40, 0)), Color = Color3.fromRGB(40, 40, 60), Parent = base })
	local stats = { { "MuseumValue", -1, -100 }, { "TotalShrinks", -1, -150 }, { "Rebirths", 1, -100 }, { "RaidsWon", 1, -150 } }
	for _, st in ipairs(stats) do
		local x = st[2] * (BASE_W / 2 - 1.5)
		part({ Name = "Board_" .. st[1], Size = Vector3.new(34, 26, 2), CFrame = CFrame.lookAt(Vector3.new(x, 24, st[3]), Vector3.new(0, 24, st[3])), Color = Color3.fromRGB(30, 30, 45), Parent = base })
	end

	-- plots: one row along the back, all the same distance from the safe line
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = map
	local count = GameConfig.PlotCount
	for id = 1, count do
		local x = (id - (count + 1) / 2) * PLOT_SPACING
		buildPlot(plotsFolder, id, CFrame.new(x, 0, PLOT_FRONT_Z - PLOT_D / 2))
	end

	MapDecor.Base(base, BASE_W, BASE_D, PLOT_FRONT_Z)

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
		floorPart({ Name = "Floor", Size = Vector3.new(CORRIDOR, 2, depth), CFrame = CFrame.new(0, -1, z + depth / 2), Color = style.Color, Material = style.Material, Parent = zone })
		MapDecor.ZoneArch(zone, tier, t, z, CORRIDOR)
		MapDecor.Zone(zone, tier, z, depth, CORRIDOR)

		local points = Instance.new("Folder")
		points.Name = "SpawnPoints"
		points.Parent = zone
		local size = maxObjectSize(tier)
		local halfX = math.max(8, CORRIDOR / 2 - MapService.DecorBand - size / 2)
		local spacing = size + 12
		local placed = {}
		local tries = 0
		while #placed < t.SpawnPoints and tries < 4000 do
			tries += 1
			local px = rng:NextNumber(-halfX, halfX)
			local pz = rng:NextNumber(z + size / 2 + 24, z + depth - size / 2 - 10)
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
	if terrainGround then
		MapDecor.Terrain(BASE_W, BASE_D, z, PLOT_FRONT_Z)
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
