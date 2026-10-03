--[[
	📍 LOCATION: ServerScriptService > Services > MapService (ModuleScript)

	Layout (bird's-eye). The 6 plots stand in a SEMICIRCLE around the base's single gate, so every
	plot is exactly the same distance from the shrink zones (fair for everyone):

	            ┌────────┐  ZONE 6 … ZONE 1 (short corridor, ~960 studs total)
	  ┌─────────┴─ GATE ─┴─────────┐  ← z = 0 (safe line)
	  │   [P1]    stands     [P6]   │
	  │ [P2]      ⛲ spawn     [P5] │  plaza with SELL / FUSE / TRAILS / SHOP stands
	  │      [P3]  VIP   [P4]       │
	  └─────────────────────────────┘

	Ground: GameConfig.Ground == "Stylized" (default) = bright studded bricks (GameConfig.Studs);
	"Terrain" = Roblox terrain (Floor parts then only mark the zone bounds, invisible).

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
local GameConfig = require(Shared.Config.GameConfig)
local MapDecor = require(script.Parent.MapDecor)

local MapService = {}
MapService.Areas = {} -- [tier] = { Tier, Model, Floor, SpawnPoints = {Part}, StartZ, EndZ }
MapService.Plots = {} -- [id] = { Id, Model, Floor, Building, Pedestals (Folder), SpawnPad }
MapService.Boards = {} -- [stat] = Part

local CORRIDOR = 200 -- shrink-zone corridor width (x from -100 to 100); the base gate is this wide
local BASE_W = 500 -- base width
local BASE_D = 260 -- base depth (z from -260 to 0)
local WALL_H = 40
local PLOT_W, PLOT_D = 70, 95
local PLOT_RADIUS = 190 -- plot centers sit on this circle around the gate (0, 0, 0)
local PLOT_ARC = { 195, 345 } -- degrees (x = cos, z = sin): a semicircle behind the gate
MapService.CorridorWidth = CORRIDOR
MapService.DecorBand = 20 -- outer strip of each zone reserved for scenery

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


-- ── plots ─────────────────────────────────────────────────────────────
-- Plot local space: +Z = front (faces the plaza / zones), temple at the back (-Z).
local MARBLE = Color3.fromRGB(246, 243, 236)
local GOLD = Color3.fromRGB(240, 190, 60)

local function local_(floor, x, y, z)
	return floor.CFrame * CFrame.new(x, y, z)
end

local function buildPlot(parent, id, cframe)
	local plot = Instance.new("Model")
	plot.Name = "Plot_" .. id
	plot:SetAttribute("PlotId", id)
	plot:SetAttribute("OwnerUserId", 0)
	plot.Parent = parent
	local floor = part({ Name = "Floor", Size = Vector3.new(PLOT_W, 1, PLOT_D), CFrame = cframe * CFrame.new(0, -0.38, 0), Color = Color3.fromRGB(125, 225, 70), Material = Enum.Material.Plastic, Parent = plot })
	local hw, hd = PLOT_W / 2, PLOT_D / 2
	local zb = -hd -- back edge (temple is built relative to this)

	-- chunky wooden X-fence around the plot (stone posts) with an entrance gap at the front
	local POST = Color3.fromRGB(78, 78, 88)
	local PLANK = Color3.fromRGB(205, 112, 48)
	local function fenceRun(x1, z1, x2, z2)
		local a, b = Vector3.new(x1, 0, z1), Vector3.new(x2, 0, z2)
		local len = (b - a).Magnitude
		local panels = math.max(1, math.floor(len / 10 + 0.5))
		for i = 0, panels do
			local p = a:Lerp(b, i / panels)
			part({ Name = "FencePost", Size = Vector3.new(1.8, 5.6, 1.8), CFrame = local_(floor, p.X, 2.8, p.Z), Color = POST, Material = Enum.Material.Plastic, CanQuery = false, Parent = plot })
			part({ Name = "PostCap", Size = Vector3.new(2.1, 0.6, 2.1), CFrame = local_(floor, p.X, 5.9, p.Z), Color = POST:Lerp(Color3.new(0, 0, 0), 0.2), Material = Enum.Material.Plastic, CanQuery = false, Parent = plot })
		end
		for i = 0, panels - 1 do
			local p0, p1 = a:Lerp(b, i / panels), a:Lerp(b, (i + 1) / panels)
			local mid = (p0 + p1) / 2
			local seg = (p1 - p0).Magnitude - 1.8
			local look = CFrame.lookAt(local_(floor, mid.X, 0, mid.Z).Position, local_(floor, p1.X, 0, p1.Z).Position)
			for _, y in ipairs({ 1.1, 4.5 }) do -- top & bottom rails
				part({ Name = "FenceRail", Size = Vector3.new(0.7, 0.8, seg), CFrame = look * CFrame.new(0, y, 0), Color = PLANK, Material = Enum.Material.Plastic, CanQuery = false, Parent = plot })
			end
			local diag = math.sqrt(seg * seg + 3.4 * 3.4)
			local angle = math.atan2(3.4, seg)
			for _, sgn in ipairs({ 1, -1 }) do -- the X
				part({ Name = "FenceBrace", Size = Vector3.new(0.6, 0.7, diag), CFrame = look * CFrame.new(0, 2.8, 0) * CFrame.Angles(sgn * angle, 0, 0), Color = PLANK:Lerp(Color3.new(0, 0, 0), 0.1), Material = Enum.Material.Plastic, CanQuery = false, Parent = plot })
			end
		end
	end
	fenceRun(-hw, -hd, hw, -hd)
	fenceRun(-hw, -hd, -hw, hd)
	fenceRun(hw, -hd, hw, hd)
	fenceRun(-hw, hd, -9, hd)
	fenceRun(9, hd, hw, hd)

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
	surfaceText(sign, Enum.NormalId.Back, "", Color3.fromRGB(255, 225, 120), 30)

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

	-- 🏃 treadmill just outside the entrance: stand on it (AFK is fine) to train speed (SpeedService)
	local treadmill = Instance.new("Model")
	treadmill.Name = "Treadmill"
	treadmill.Parent = plot
	local tcf = local_(floor, hw - 8, 0, hd + 9)
	part({ Name = "Frame", Size = Vector3.new(7, 1, 12), CFrame = tcf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(50, 52, 64), Material = Enum.Material.Plastic, Parent = treadmill })
	part({ Name = "Belt", Size = Vector3.new(5.4, 0.3, 11), CFrame = tcf * CFrame.new(0, 1.15, 0), Color = Color3.fromRGB(30, 30, 36), Material = Enum.Material.Fabric, Parent = treadmill })
	for _, sx in ipairs({ -1, 1 }) do
		part({ Name = "Rail", Size = Vector3.new(0.4, 0.4, 5), CFrame = tcf * CFrame.new(sx * 3.1, 4.2, -3.5), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal, Parent = treadmill })
		part({ Name = "Post", Size = Vector3.new(0.4, 3.4, 0.4), CFrame = tcf * CFrame.new(sx * 3.1, 2.6, -5.8), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal, Parent = treadmill })
	end
	local console = part({ Name = "Console", Size = Vector3.new(6.6, 1.6, 0.6), CFrame = tcf * CFrame.new(0, 4.6, -5.9) * CFrame.Angles(math.rad(-25), 0, 0), Color = Color3.fromRGB(40, 140, 255), Material = Enum.Material.Neon, CanQuery = false, Parent = treadmill })
	surfaceText(console, Enum.NormalId.Back, "SPEED", Color3.new(1, 1, 1), 20)

	local pedestals = Instance.new("Folder")
	pedestals.Name = "Pedestals"
	pedestals.Parent = plot
	part({ Name = "SpawnPad", Size = Vector3.new(10, 1, 10), CFrame = floor.CFrame * CFrame.new(0, 0.1, hd + 7), Color = Color3.fromRGB(90, 200, 255), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Transparency = 0.3, Parent = plot })
end

-- ── build ─────────────────────────────────────────────────────────────
-- Runs a decoration step; a failure is reported but never stops the map from being built.
local function safe(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		warn("[MapService] " .. label .. " failed (map still builds): " .. tostring(err))
	end
	return ok
end

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
	floorPart({ Name = "Floor", Size = Vector3.new(BASE_W, 2, BASE_D), CFrame = CFrame.new(0, -1, -BASE_D / 2), Color = Color3.fromRGB(105, 215, 50), Material = Enum.Material.Plastic, Parent = base })
	part({ Name = "SafeZone", Size = Vector3.new(BASE_W, 200, BASE_D), CFrame = CFrame.new(0, 99, -BASE_D / 2), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = base })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, -30)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(90, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.3
	spawn.Parent = base

	-- small VIP lounge tucked in the back-right corner (keeps the middle of the base open)
	local vip = Vector3.new(212, 0, -228)
	local gold = Color3.fromRGB(255, 205, 60)
	part({ Name = "VIPRoom", Size = Vector3.new(32, 18, 26), CFrame = CFrame.new(vip + Vector3.new(0, 9, 0)), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(32, 18, 1.5), CFrame = CFrame.new(vip + Vector3.new(0, 9, -13)), Color = gold, Material = Enum.Material.Marble, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(1.5, 18, 26), CFrame = CFrame.new(vip + Vector3.new(-16, 9, 0)), Color = gold, Material = Enum.Material.Marble, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(1.5, 18, 26), CFrame = CFrame.new(vip + Vector3.new(16, 9, 0)), Color = gold, Material = Enum.Material.Marble, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(9.5, 18, 1.5), CFrame = CFrame.new(vip + Vector3.new(-11.25, 9, 13)), Color = gold, Material = Enum.Material.Marble, Parent = base })
	part({ Name = "VIPWall", Size = Vector3.new(9.5, 18, 1.5), CFrame = CFrame.new(vip + Vector3.new(11.25, 9, 13)), Color = gold, Material = Enum.Material.Marble, Parent = base })
	part({ Name = "VIPRoof", Size = Vector3.new(34, 1.5, 28), CFrame = CFrame.new(vip + Vector3.new(0, 18.7, 0)), Color = gold, Material = Enum.Material.Marble, Parent = base })
	local door = part({ Name = "VIPDoor", Size = Vector3.new(13, 18, 1.5), CFrame = CFrame.new(vip + Vector3.new(0, 9, 13)), Color = Color3.fromRGB(255, 230, 120), Material = Enum.Material.ForceField, Transparency = 0.3, Parent = base })
	surfaceText(door, Enum.NormalId.Back, "VIP", gold)
	part({ Name = "VIPFountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 9, 9), CFrame = CFrame.new(vip + Vector3.new(0, 1, -3)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Neon, Parent = base })

	-- Like sign on the back wall, leaderboards on the front wall either side of the gate (facing in)
	part({ Name = "LikeSign", Size = Vector3.new(40, 22, 2), CFrame = CFrame.lookAt(Vector3.new(0, 30, -BASE_D + 1), Vector3.new(0, 30, 0)), Color = Color3.fromRGB(40, 40, 60), Parent = base })
	local stats = { { "MuseumValue", -205 }, { "TotalShrinks", -140 }, { "Rebirths", 140 }, { "RaidsWon", 205 } }
	for _, st in ipairs(stats) do
		part({ Name = "Board_" .. st[1], Size = Vector3.new(30, 22, 2), CFrame = CFrame.lookAt(Vector3.new(st[2], 20, -1.5), Vector3.new(st[2], 20, -100)), Color = Color3.fromRGB(30, 30, 45), Parent = base })
	end

	-- plots: a semicircle around the gate, every plot facing it from the same distance
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = map
	local count = GameConfig.PlotCount
	local plotCFrames = {}
	for id = 1, count do
		local t = count == 1 and 0.5 or (id - 1) / (count - 1)
		local angle = math.rad(PLOT_ARC[1] + (PLOT_ARC[2] - PLOT_ARC[1]) * t)
		local pos = Vector3.new(math.cos(angle) * PLOT_RADIUS, 0, math.sin(angle) * PLOT_RADIUS)
		-- local +Z (the plot's front) points at the gate
		local cf = CFrame.lookAt(pos, pos + pos.Unit)
		plotCFrames[id] = cf
		buildPlot(plotsFolder, id, cf)
	end

	safe("Base decor", MapDecor.Base, base, BASE_W, BASE_D, PLOT_RADIUS, plotCFrames)

	-- ── Zones (a short corridor through the gate) ─────────────────────────
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
		safe("Zone arch " .. tier, MapDecor.ZoneArch, zone, tier, t, z, CORRIDOR)
		safe("Zone decor " .. tier, MapDecor.Zone, zone, tier, z, depth, CORRIDOR)

		local points = Instance.new("Folder")
		points.Name = "SpawnPoints"
		points.Parent = zone
		local size = 7 + 0.5 * tier -- mystery boxes (see SpawnService) + some room
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
	if terrainGround and not safe("Terrain ground", MapDecor.Terrain, BASE_W, BASE_D, CORRIDOR, z) then
		-- terrain failed: make the floors visible & solid so nobody falls through the world
		for _, d in ipairs(map:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == "Floor" and d.Transparency == 1 then
				d.Transparency = 0
				d.CanCollide = true
			end
		end
	end

	-- ── Walls ────────────────────────────────────────────
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = map
	safe("Walls", MapDecor.Walls, walls, {
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

	if GameConfig.Studs ~= false then
		safe("Studs", MapDecor.Studify, map)
	end
	safe("Lighting", MapDecor.Lighting)
	map:SetAttribute("GeneratedMapVersion", GameConfig.MapVersion)
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

-- An older auto-generated map saved into the place would hide every map update, so replace it.
-- (A map YOU built has no GeneratedMapVersion attribute and no old-style "Lobby"/"Areas" children,
-- so it is always kept.)
local function isOutdatedGeneratedMap(map)
	local version = map:GetAttribute("GeneratedMapVersion")
	if version then
		return version < GameConfig.MapVersion
	end
	return map:FindFirstChild("Lobby") ~= nil or map:FindFirstChild("Areas") ~= nil
end

-- Puts YOUR textures (TextureConfig) on the ground, plot floors and shop counters.
local function texture(partObj, id, tile)
	for _, face in ipairs({ Enum.NormalId.Top }) do
		local t = Instance.new("Texture")
		t.Name = "CustomTexture"
		t.Texture = id
		t.Face = face
		t.StudsPerTileU = tile or 16
		t.StudsPerTileV = tile or 16
		t.Parent = partObj
	end
end

function MapService.ApplyTextures(map)
	local TextureConfig = require(ReplicatedStorage.Shared.Config.TextureConfig)
	local base = map:FindFirstChild("Base")
	local g = TextureConfig.Ground
	if base and base:FindFirstChild("Floor") and TextureConfig.Has(g.Base.Id) then
		texture(base.Floor, g.Base.Id, g.Base.Tile)
	end
	local zones = map:FindFirstChild("Zones")
	for _, zone in ipairs(zones and zones:GetChildren() or {}) do
		local cfg = g[zone:GetAttribute("Tier")]
		if cfg and TextureConfig.Has(cfg.Id) and zone:FindFirstChild("Floor") then
			texture(zone.Floor, cfg.Id, cfg.Tile)
		end
	end
	local plots = map:FindFirstChild("Plots")
	if TextureConfig.Has(TextureConfig.PlotFloor.Id) then
		for _, plot in ipairs(plots and plots:GetChildren() or {}) do
			local floor = plot:FindFirstChild("Floor")
			if floor then
				texture(floor, TextureConfig.PlotFloor.Id, TextureConfig.PlotFloor.Tile)
			end
		end
	end
	local stands = base and base:FindFirstChild("Stands")
	if stands and TextureConfig.Has(TextureConfig.StandCounter.Id) then
		for _, stand in ipairs(stands:GetChildren()) do
			local prompt = stand:FindFirstChildWhichIsA("ProximityPrompt", true)
			local counter = prompt and prompt.Parent
			if counter and counter:IsA("BasePart") then
				for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
					local t = Instance.new("Texture")
					t.Texture = TextureConfig.StandCounter.Id
					t.Face = face
					t.StudsPerTileU = TextureConfig.StandCounter.Tile
					t.StudsPerTileV = TextureConfig.StandCounter.Tile
					t.Parent = counter
				end
			end
		end
	end
end

function MapService.Init(_registry)
	local existing = workspace:FindFirstChild("ShrinkItMap")
	if existing and isOutdatedGeneratedMap(existing) then
		warn("[MapService] Found an OUTDATED generated ShrinkItMap saved in Workspace - replacing it with map v" .. GameConfig.MapVersion .. ". (Delete Workspace > ShrinkItMap in Studio and save to stop seeing this.)")
		existing:Destroy()
		existing = nil
	end
	-- The map is normally already saved in the place (so you can see it in Studio while editing);
	-- it's only generated here if it's missing.
	local map = existing or buildMap()
	safe("Shopkeepers", MapDecor.AddShopkeepers, map)
	safe("Shopkeeper naps", MapDecor.ShopkeeperNaps, map)
	safe("Textures", MapService.ApplyTextures, map)
	safe("Asset pack decor", MapDecor.PackDecor, map)
	-- a map saved in the place file doesn't keep PrimaryPart links: restore them
	for _, d in ipairs(map:GetDescendants()) do
		if d:IsA("Model") and d.Name == "MuseumBuilding" and not d.PrimaryPart then
			d.PrimaryPart = d:FindFirstChild("Body")
		end
	end
	if existing then
		safe("Lighting", MapDecor.Lighting)
	end
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
