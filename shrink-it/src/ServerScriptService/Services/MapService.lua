--[[
	📍 LOCATION: ServerScriptService > Services > MapService (ModuleScript)

	If Workspace has no "ShrinkItMap" model, this builds a complete placeholder world:
	lobby, 6 gated tier areas with spawn points, 8 museum plots, VIP lounge, Like sign
	and 4 leaderboard boards. Build your own map later using the SAME names (see README),
	and this service will just read it instead of generating one.

	ShrinkItMap
	├─ Lobby (Model)          → SpawnLocation, VIPRoom (Part, region), VIPDoor, VIPFountain, LikeSign, Board_<Stat>
	├─ Areas (Folder)
	│   └─ Area_<tier> (Model, attr Tier) → Floor (Part), Gate (Part, attr Tier), SpawnPoints (Folder of Parts)
	├─ Plots (Folder)
	│   └─ Plot_<n> (Model, attr PlotId) → Floor (Part), MuseumBuilding (Model: Body, Sign), SpawnPad (Part)
	└─ LiveObjects (Folder)   → spawned shrinkables live here
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TierConfig = require(Shared.Config.TierConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local GameConfig = require(Shared.Config.GameConfig)

local MapService = {}
MapService.Areas = {} -- [tier] = { Tier, Model, Floor, Gate, SpawnPoints = {Part} }
MapService.Plots = {} -- [id] = { Id, Model, Floor, Building, Pedestals (Folder), SpawnPad }
MapService.Boards = {} -- [stat] = Part

local WIDTH = 300
local LOBBY_DEPTH = 160

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

local function surfaceText(target, face, text, color, bg)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 20
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bg or Color3.fromRGB(30, 30, 40)
	label.BackgroundTransparency = bg and 0 or 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text
	label.Name = "Label"
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
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

local function buildMap()
	local map = Instance.new("Model")
	map.Name = "ShrinkItMap"

	-- ── Lobby ─────────────────────────────────────────────
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = map
	part({ Name = "Floor", Size = Vector3.new(WIDTH, 2, LOBBY_DEPTH), CFrame = CFrame.new(0, -1, 0), Color = Color3.fromRGB(235, 235, 245), Material = Enum.Material.SmoothPlastic, Parent = lobby })
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(0, 0.5, -20)
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Color = Color3.fromRGB(90, 200, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Parent = lobby

	-- VIP lounge (corner of the lobby)
	local vipCenter = Vector3.new(120, 0, 52)
	part({ Name = "VIPRoom", Size = Vector3.new(56, 24, 52), CFrame = CFrame.new(vipCenter + Vector3.new(0, 12, 0)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = lobby })
	local wallColor = Color3.fromRGB(255, 205, 60)
	part({ Name = "VIPWall", Size = Vector3.new(56, 24, 2), CFrame = CFrame.new(vipCenter + Vector3.new(0, 12, 26)), Color = wallColor, Parent = lobby })
	part({ Name = "VIPWall", Size = Vector3.new(56, 24, 2), CFrame = CFrame.new(vipCenter + Vector3.new(0, 12, -26)), Color = wallColor, Parent = lobby })
	part({ Name = "VIPWall", Size = Vector3.new(2, 24, 52), CFrame = CFrame.new(vipCenter + Vector3.new(28, 12, 0)), Color = wallColor, Parent = lobby })
	part({ Name = "VIPWall", Size = Vector3.new(2, 24, 16), CFrame = CFrame.new(vipCenter + Vector3.new(-28, 12, 18)), Color = wallColor, Parent = lobby })
	part({ Name = "VIPWall", Size = Vector3.new(2, 24, 16), CFrame = CFrame.new(vipCenter + Vector3.new(-28, 12, -18)), Color = wallColor, Parent = lobby })
	part({ Name = "VIPRoof", Size = Vector3.new(56, 2, 52), CFrame = CFrame.new(vipCenter + Vector3.new(0, 25, 0)), Color = wallColor, Parent = lobby })
	local door = part({ Name = "VIPDoor", Size = Vector3.new(2, 24, 20), CFrame = CFrame.new(vipCenter + Vector3.new(-28, 12, 0)), Color = Color3.fromRGB(255, 230, 120), Material = Enum.Material.ForceField, Transparency = 0.3, Parent = lobby })
	surfaceText(door, Enum.NormalId.Left, "👑 VIP ONLY", Color3.fromRGB(255, 220, 60))
	local fountain = part({ Name = "VIPFountain", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 12, 12), CFrame = CFrame.new(vipCenter + Vector3.new(6, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(120, 230, 255), Material = Enum.Material.Neon, Parent = lobby })
	local fb = Instance.new("BillboardGui")
	fb.Size = UDim2.fromOffset(220, 60)
	fb.StudsOffset = Vector3.new(0, 6, 0)
	fb.AlwaysOnTop = true
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

	-- Like sign
	part({ Name = "LikeSign", Size = Vector3.new(30, 18, 2), CFrame = CFrame.lookAt(Vector3.new(146, 10, -30), Vector3.new(0, 10, -30)), Color = Color3.fromRGB(40, 40, 60), Parent = lobby })

	-- Leaderboards
	local stats = { "MuseumValue", "TotalShrinks", "Rebirths", "RaidsWon" }
	for i, stat in ipairs(stats) do
		local z = -55 + (i - 1) * 34
		part({ Name = "Board_" .. stat, Size = Vector3.new(30, 26, 2), CFrame = CFrame.lookAt(Vector3.new(-146, 14, z), Vector3.new(0, 14, z)), Color = Color3.fromRGB(30, 30, 45), Parent = lobby })
	end

	-- ── Areas ─────────────────────────────────────────────
	local areas = Instance.new("Folder")
	areas.Name = "Areas"
	areas.Parent = map
	local z = LOBBY_DEPTH / 2
	local rng = Random.new(1337)
	for tier, t in ipairs(TierConfig.Tiers) do
		local area = Instance.new("Model")
		area.Name = "Area_" .. tier
		area:SetAttribute("Tier", tier)
		area:SetAttribute("AreaName", t.Area)
		area.Parent = areas
		local depth = t.AreaDepth
		part({ Name = "Floor", Size = Vector3.new(WIDTH, 2, depth), CFrame = CFrame.new(0, -1, z + depth / 2), Color = t.Color, Material = Enum.Material.Grass, Parent = area })
		local sign = part({ Name = "AreaSign", Size = Vector3.new(40, 8, 1), CFrame = CFrame.new(0, 30, z + 2), Transparency = 1, CanCollide = false, CanQuery = false, Parent = area })
		surfaceText(sign, Enum.NormalId.Front, t.Area .. " · " .. t.Name, t.Color)
		if tier > 1 then
			local gate = part({ Name = "Gate", Size = Vector3.new(WIDTH, 300, 2), CFrame = CFrame.new(0, 150, z), Color = t.Color, Material = Enum.Material.ForceField, Transparency = 0.35, CanQuery = false, Parent = area })
			gate:SetAttribute("Tier", tier)
			CollectionService:AddTag(gate, "AreaGate")
			local _, label = surfaceText(gate, Enum.NormalId.Front, "", Color3.new(1, 1, 1))
			label.Parent.PixelsPerStud = 4
			label.Size = UDim2.new(0, 220 * 4, 0, 40 * 4)
			label.Position = UDim2.new(0.5, -110 * 4, 1, -50 * 4)
			label.Text = "🔒 " .. t.Area .. "\nRay Power " .. t.RayPowerRequired .. " or pay coins (Upgrades menu)"
		end
		-- spawn points
		local points = Instance.new("Folder")
		points.Name = "SpawnPoints"
		points.Parent = area
		local size = maxObjectSize(tier)
		local spacing = size + 10
		local margin = size / 2 + 8
		local placed = {}
		local tries = 0
		while #placed < t.SpawnPoints and tries < 2000 do
			tries += 1
			local px = rng:NextNumber(-WIDTH / 2 + margin, WIDTH / 2 - margin)
			local pz = rng:NextNumber(z + margin + 10, z + depth - margin)
			local okSpot = true
			for _, p in ipairs(placed) do
				if (Vector2.new(px, pz) - p).Magnitude < spacing then
					okSpot = false
					break
				end
			end
			if okSpot then
				table.insert(placed, Vector2.new(px, pz))
				part({ Name = "SpawnPoint", Size = Vector3.new(2, 1, 2), CFrame = CFrame.new(px, 0.5, pz), Transparency = 1, CanCollide = false, CanQuery = false, Parent = points })
			end
		end
		z += depth
	end

	-- invisible boundary walls for the area strip (no walking around gates)
	local boundary = Instance.new("Folder")
	boundary.Name = "Boundary"
	boundary.Parent = map
	local stripStart = -LOBBY_DEPTH / 2
	local stripLen = z - stripStart
	for _, x in ipairs({ -WIDTH / 2 - 1, WIDTH / 2 + 1 }) do
		part({ Name = "Wall", Size = Vector3.new(2, 400, stripLen), CFrame = CFrame.new(x, 200, stripStart + stripLen / 2), Transparency = 1, CanQuery = false, Parent = boundary })
	end
	part({ Name = "Wall", Size = Vector3.new(WIDTH, 400, 2), CFrame = CFrame.new(0, 200, z + 1), Transparency = 1, CanQuery = false, Parent = boundary })

	-- ── Plots ─────────────────────────────────────────────
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = map
	part({ Name = "Plaza", Size = Vector3.new(640, 2, 340), CFrame = CFrame.new(0, -1.05, -LOBBY_DEPTH / 2 - 170), Color = Color3.fromRGB(200, 205, 215), Material = Enum.Material.Concrete, Parent = plotsFolder })
	local xs = { -225, -75, 75, 225 }
	local zs = { -LOBBY_DEPTH / 2 - 90, -LOBBY_DEPTH / 2 - 250 }
	local id = 0
	for _, pz in ipairs(zs) do
		for _, px in ipairs(xs) do
			id += 1
			if id > GameConfig.PlotCount then
				break
			end
			local plot = Instance.new("Model")
			plot.Name = "Plot_" .. id
			plot:SetAttribute("PlotId", id)
			plot:SetAttribute("OwnerUserId", 0)
			plot.Parent = plotsFolder
			part({ Name = "Floor", Size = Vector3.new(140, 1, 150), CFrame = CFrame.new(px, -0.45, pz), Color = Color3.fromRGB(250, 245, 230), Material = Enum.Material.WoodPlanks, Parent = plot })
			local building = Instance.new("Model")
			building.Name = "MuseumBuilding"
			building:SetAttribute("RaidBuilding", true)
			building:SetAttribute("PlotId", id)
			building.Parent = plot
			local body = part({ Name = "Body", Size = Vector3.new(60, 28, 26), CFrame = CFrame.new(px, 14, pz - 75 + 14), Color = Color3.fromRGB(245, 240, 255), Material = Enum.Material.Marble, Parent = building })
			part({ Name = "Roof", Size = Vector3.new(66, 4, 32), CFrame = CFrame.new(px, 30, pz - 75 + 14), Color = Color3.fromRGB(255, 90, 90), Parent = building })
			for c = -2, 2 do
				part({ Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(26, 3, 3), CFrame = CFrame.new(px + c * 12, 13, pz - 75 + 29) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 255, 255), Material = Enum.Material.Marble, Parent = building })
			end
			building.PrimaryPart = body
			local signPart = part({ Name = "Sign", Size = Vector3.new(40, 6, 1), CFrame = CFrame.new(px, 24, pz - 75 + 27.6), Color = Color3.fromRGB(40, 40, 60), Parent = building })
			surfaceText(signPart, Enum.NormalId.Back, "Empty Plot", Color3.new(1, 1, 1))
			local pedestals = Instance.new("Folder")
			pedestals.Name = "Pedestals"
			pedestals.Parent = plot
			part({ Name = "SpawnPad", Size = Vector3.new(10, 1, 10), CFrame = CFrame.new(px, 0.1, pz + 70), Color = Color3.fromRGB(90, 200, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = plot })
		end
	end

	local live = Instance.new("Folder")
	live.Name = "LiveObjects"
	live.Parent = map

	map.Parent = workspace
	return map
end

local function readMap(map)
	local lobby = map:WaitForChild("Lobby")
	MapService.Lobby = lobby
	MapService.LobbySpawn = lobby:FindFirstChild("SpawnLocation")
	MapService.VIPRoom = lobby:FindFirstChild("VIPRoom")
	MapService.VIPDoor = lobby:FindFirstChild("VIPDoor")
	MapService.VIPFountain = lobby:FindFirstChild("VIPFountain")
	MapService.LikeSign = lobby:FindFirstChild("LikeSign")
	if MapService.VIPDoor then
		CollectionService:AddTag(MapService.VIPDoor, "VIPDoor")
	end
	for _, child in ipairs(lobby:GetChildren()) do
		local stat = string.match(child.Name, "^Board_(%w+)$")
		if stat then
			MapService.Boards[stat] = child
		end
	end

	for _, area in ipairs(map:WaitForChild("Areas"):GetChildren()) do
		local tier = area:GetAttribute("Tier") or tonumber(string.match(area.Name, "%d+"))
		if tier then
			local points = {}
			local folder = area:FindFirstChild("SpawnPoints")
			if folder then
				for _, p in ipairs(folder:GetChildren()) do
					if p:IsA("BasePart") then
						table.insert(points, p)
					end
				end
			end
			local gate = area:FindFirstChild("Gate")
			if gate then
				gate:SetAttribute("Tier", tier)
				CollectionService:AddTag(gate, "AreaGate")
			end
			MapService.Areas[tier] = { Tier = tier, Model = area, Floor = area:FindFirstChild("Floor"), Gate = gate, SpawnPoints = points }
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

	MapService.LiveObjects = map:FindFirstChild("LiveObjects")
	if not MapService.LiveObjects then
		local live = Instance.new("Folder")
		live.Name = "LiveObjects"
		live.Parent = map
		MapService.LiveObjects = live
	end
end

function MapService.Init(_registry)
	local map = workspace:FindFirstChild("ShrinkItMap") or buildMap()
	readMap(map)
end

-- Returns the tier of the area containing `position`, or nil (lobby / plots).
function MapService.GetAreaAt(position)
	for tier, area in pairs(MapService.Areas) do
		local floor = area.Floor
		if floor then
			local rel = floor.CFrame:PointToObjectSpace(position)
			if math.abs(rel.X) <= floor.Size.X / 2 and math.abs(rel.Z) <= floor.Size.Z / 2 and rel.Y > -10 and rel.Y < 400 then
				return tier
			end
		end
	end
	return nil
end

function MapService.IsInPart(region, position)
	if not region then
		return false
	end
	local rel = region.CFrame:PointToObjectSpace(position)
	local s = region.Size / 2
	return math.abs(rel.X) <= s.X and math.abs(rel.Y) <= s.Y and math.abs(rel.Z) <= s.Z
end

function MapService.RandomPointInArea(tier, margin)
	local area = MapService.Areas[tier]
	if not area or not area.Floor then
		return nil
	end
	local f = area.Floor
	local hx = math.max(1, f.Size.X / 2 - (margin or 10))
	local hz = math.max(1, f.Size.Z / 2 - (margin or 10))
	local offset = Vector3.new(math.random() * 2 * hx - hx, f.Size.Y / 2, math.random() * 2 * hz - hz)
	return (f.CFrame * CFrame.new(offset)).Position
end

return MapService
