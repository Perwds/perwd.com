--!strict
--[[
	WorldBuilder
	Lays out the village.

	    TOWN SQUARE     cobbled circle, the Scanner shrine in the middle,
	                    string lights overhead, banners, lamp posts
	    MARKET RING     seven stalls, one per stat category -- the scan stations
	    HOUSES          a ring of timber cottages and two towers facing in
	    GRAVESTONES     three carved leaderboards, west side
	    PORTALS         a glowing ring east that teleports to the Void Isle,
	                    once you have the scanner score for it
	    SKY RUINS       an obby climb north-west with a chest at the top
	    OUTSKIRTS       trees, fences, lanterns along the paths

	A scan takes time, so the town is built to give you somewhere to be while it
	runs: orbs along the paths, a climb, and a second island worth crossing to.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local Palette = require(Shared.Palette)
local StatConfig = require(Shared.StatConfig)

local Build = require(script.Parent.Build)
local DataService = require(script.Parent.DataService)
local DailyService = require(script.Parent.DailyService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local PickupService = require(script.Parent.PickupService)
local ScanService = require(script.Parent.ScanService)
local StateService = require(script.Parent.StateService)

local WorldBuilder = {}

local GROUND = 420
local SQUARE_RADIUS = 46
local VOID_CENTRE = Vector3.new(0, 140, -420)
local VOID_REQUIREMENT = 30
local BOARD_REFRESH = 30

local root: Folder
local boardLabels: { [string]: { TextLabel } } = {}

local ROOFS = {
	Color3.fromRGB(132, 86, 158), -- purple
	Color3.fromRGB(176, 72, 72), -- red
	Color3.fromRGB(86, 126, 178), -- blue
	Color3.fromRGB(196, 132, 68), -- amber
	Color3.fromRGB(96, 140, 104), -- green
}

local POD_COLOR = {
	core = Palette.cyan,
	movement = Palette.orange,
	combat = Palette.red,
	social = Palette.pink,
	economy = Palette.green,
	collection = Palette.purple,
	cursed = Palette.gold,
}

-- Ground -----------------------------------------------------------------

local function buildGround()
	-- Real terrain rather than a painted slab: with Terrain.Decoration on,
	-- grass material grows actual 3D blades that move in the wind.
	local terrain = workspace.Terrain
	terrain.Decoration = true
	terrain:FillBlock(CFrame.new(0, -10, 0), Vector3.new(GROUND, 20, GROUND), Enum.Material.Grass)

	-- A patch of packed dirt where the town has worn the grass down.
	-- FillCylinder runs its height along the CFrame's Y axis, so this one is
	-- left upright rather than rotated the way a cylinder Part would be.
	terrain:FillCylinder(CFrame.new(0, -4, 0), 8, SQUARE_RADIUS + 34, Enum.Material.Ground)

	Build.part({
		Name = "Square",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, SQUARE_RADIUS * 2, SQUARE_RADIUS * 2),
		CFrame = CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 140, 128),
		Material = Enum.Material.Cobblestone,
	}, root)

	-- Paths out to each quarter of the town.
	for _, angle in ipairs({ 0, 90, 180, 270 }) do
		local radians = math.rad(angle)
		local direction = Vector3.new(math.sin(radians), 0, math.cos(radians))
		Build.path(direction * SQUARE_RADIUS, direction * 170, 14, root)
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(16, 1, 16)
	spawnLocation.Position = Vector3.new(0, 0.9, 34)
	spawnLocation.Color = Palette.green
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Duration = 0
	spawnLocation.Parent = root
end

-- Scanner shrine ---------------------------------------------------------

local function buildShrine()
	Build.part({
		Name = "ShrineBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 34, 34),
		CFrame = CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(214, 204, 186),
		Material = Enum.Material.Marble,
	}, root)

	Build.part({
		Name = "ShrineStep",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 42, 42),
		CFrame = CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(196, 186, 170),
		Material = Enum.Material.Marble,
	}, root)

	-- Six pillars holding the canopy.
	for index = 1, 6 do
		local angle = math.rad(index * 60)
		Build.part({
			Name = "ShrinePillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(22, 3, 3),
			CFrame = CFrame.new(Vector3.new(math.sin(angle) * 13, 13, math.cos(angle) * 13))
				* CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(226, 218, 202),
			Material = Enum.Material.Marble,
		}, root)
	end

	Build.part({
		Name = "ShrineRing",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 32, 32),
		CFrame = CFrame.new(0, 24.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(214, 204, 186),
		Material = Enum.Material.Marble,
	}, root)

	local roof = Build.part({
		Name = "ShrineRoof",
		Size = Vector3.new(34, 12, 34),
		CFrame = CFrame.new(0, 31, 0),
		Color = ROOFS[1],
		Material = Enum.Material.Slate,
	}, root)
	local roofMesh = Instance.new("SpecialMesh")
	roofMesh.MeshType = Enum.MeshType.Pyramid
	roofMesh.Parent = roof

	local core = Build.part({
		Name = "ShrineCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		Position = Vector3.new(0, 14, 0),
		Color = Palette.cyan,
		Material = Enum.Material.Neon,
	}, root)

	local light = Instance.new("PointLight")
	light.Color = Palette.cyan
	light.Range = 46
	light.Brightness = 3.5
	light.Parent = core

	Build.hologram(Vector3.new(0, 44, 0), "STAT SCANNER", "press E at the shrine", Palette.cyan, root)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open scanner"
	prompt.ObjectText = "STAT SHRINE"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 28
	prompt.RequiresLineOfSight = false
	prompt.Parent = core

	prompt.Triggered:Connect(function(player)
		Remotes.event("OpenMenu"):FireClient(player, { view = "stats" })
	end)

	task.spawn(function()
		local angle = 0
		while core.Parent do
			angle += 0.02
			core.CFrame = CFrame.new(core.Position)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, math.sin(angle * 2) * 0.5, 0)
			task.wait(0.03)
		end
	end)
end

-- Market ring ------------------------------------------------------------

--- Starts the next scannable stat in a category, so a stall is a real verb
--- rather than a shortcut into the menu.
local function scanCategory(player: Player, categoryId: string)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local locked = 0

	for _, stat in ipairs(StatConfig.inCategory(categoryId)) do
		if not profile.scanned[stat.id] then
			if ScanService.isAvailable(player, stat) then
				local started, reason = ScanService.start(player, stat.id)
				if started then
					StateService.notify(player, ("Scanning %s..."):format(stat.name), ">", POD_COLOR[categoryId])
				elseif reason then
					StateService.notify(player, reason, "!", Palette.red)
				end
				return
			end
			locked += 1
		end
	end

	if locked > 0 then
		StateService.notify(
			player,
			("%d %s stats left, all locked. Open the scanner to unlock one."):format(locked, categoryId),
			"!",
			Palette.gold
		)
	else
		StateService.notify(player, ("All %s stats scanned!"):format(categoryId), "*", Palette.green)
	end
end

local function buildMarket()
	local categories = StatConfig.Categories
	local radius = 68

	for index, category in ipairs(categories) do
		local angle = math.rad((index - 1) * (360 / #categories))
		local position = Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
		local tint = POD_COLOR[category.id] or Palette.purple

		-- Face the stall back towards the square.
		local cf = CFrame.lookAt(position, Vector3.new(0, 0, 0))
		local glow = Build.stall(cf, tint, root)

		Build.hologram(
			position + Vector3.new(0, 17, 0),
			category.name:upper(),
			"scan next stat",
			tint,
			root
		)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Scan next"
		prompt.ObjectText = category.name:upper()
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = glow

		prompt.Triggered:Connect(function(player)
			scanCategory(player, category.id)
		end)

		PickupService.scatter(position, 15, 2, 18, tint)

		-- Market clutter around the stall.
		Build.barrel(position + Vector3.new(8, 0, 4), root)
		Build.crate(position + Vector3.new(-8, 0, 3), math.rad(math.random(0, 90)), root)
		Build.flowers(position + Vector3.new(0, 0, 10), 5, root)
	end
end

-- Town -------------------------------------------------------------------

--- CFrame.lookAt aims an object's -Z at its target, but Build.house puts the
--- door on +Z. Looking AWAY from the square is what turns the door towards it.
local function facingSquare(position: Vector3): CFrame
	return CFrame.lookAt(position, position + position.Unit * 10)
end

local function buildTown()
	-- Cottages in a ring, doors onto the square.
	local houses = 10
	for index = 1, houses do
		local angle = math.rad((index - 1) * (360 / houses) + 18)
		local distance = 122 + (index % 3) * 10
		local position = Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance)
		Build.house(facingSquare(position), ROOFS[(index % #ROOFS) + 1], root, index % 4 == 0 and 1.25 or 1)
	end

	Build.tower(Vector3.new(-96, 0, 96), 9, 42, ROOFS[1], root)
	Build.tower(Vector3.new(96, 0, 96), 7, 32, ROOFS[3], root)

	-- Banners and lamp posts around the square.
	for index = 1, 8 do
		local angle = math.rad(index * 45 + 22)
		local position = Vector3.new(math.sin(angle) * (SQUARE_RADIUS + 6), 0, math.cos(angle) * (SQUARE_RADIUS + 6))
		Build.banner(position, ROOFS[(index % #ROOFS) + 1], root)
	end

	for index = 1, 10 do
		local angle = math.rad(index * 36)
		Build.lanternPost(
			Vector3.new(math.sin(angle) * 92, 0, math.cos(angle) * 92),
			root
		)
	end

	-- String lights criss-crossing above the square.
	for index = 1, 6 do
		local a = math.rad(index * 60)
		local b = a + math.rad(150)
		Build.stringLights(
			Vector3.new(math.sin(a) * (SQUARE_RADIUS + 4), 20, math.cos(a) * (SQUARE_RADIUS + 4)),
			Vector3.new(math.sin(b) * (SQUARE_RADIUS + 4), 20, math.cos(b) * (SQUARE_RADIUS + 4)),
			7,
			root
		)
	end

	-- Trees and fences on the outskirts.
	for index = 1, 46 do
		local angle = math.rad(index * 7.83)
		local distance = 165 + (index % 5) * 14
		Build.tree(
			Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance),
			0.85 + (index % 4) * 0.2,
			root
		)
	end

	for index = 1, 4 do
		local angle = math.rad(index * 90 + 45)
		local a = Vector3.new(math.sin(angle) * 100, 0, math.cos(angle) * 100)
		local b = Vector3.new(math.sin(angle + math.rad(45)) * 100, 0, math.cos(angle + math.rad(45)) * 100)
		Build.fence(a, b, root)
	end

	-- Fountains in the corners of the square.
	for index = 1, 4 do
		local angle = math.rad(index * 90 + 45)
		Build.fountain(Vector3.new(math.sin(angle) * 34, 0, math.cos(angle) * 34), root)
	end

	-- Hedges lining the four paths out of town.
	for _, angle in ipairs({ 0, 90, 180, 270 }) do
		local radians = math.rad(angle)
		local direction = Vector3.new(math.sin(radians), 0, math.cos(radians))
		local side = Vector3.new(direction.Z, 0, -direction.X) * 9
		Build.hedge(direction * 58 + side, direction * 150 + side, root)
		Build.hedge(direction * 58 - side, direction * 150 - side, root)
	end

	-- Flowers, long grass and farm clutter scattered over the green.
	for index = 1, 40 do
		local angle = math.rad(index * 9.1)
		local distance = 74 + (index % 7) * 13
		local spot = Vector3.new(math.sin(angle) * distance, 0, math.cos(angle) * distance)

		Build.flowers(spot, 4, root)
		if index % 2 == 0 then
			Build.grassTufts(spot + Vector3.new(6, 0, -4), 3, 7, root)
		end
		if index % 7 == 0 then
			Build.hayBale(spot + Vector3.new(-10, 0, 6), math.rad(math.random(0, 180)), root)
		end
		if index % 9 == 0 then
			Build.crate(spot + Vector3.new(9, 0, 9), math.rad(math.random(0, 90)), root)
		end
	end

	-- Signpost by the spawn so the town explains itself.
	Build.signpost(Vector3.new(16, 0, 44), {
		{ text = "SKY RUINS", angle = 135, tint = Palette.gold },
		{ text = "VOID ISLE", angle = 180, tint = Palette.purple },
		{ text = "MARKET", angle = 0, tint = Palette.green },
	}, root)

	-- Pollen drifting over the green.
	for index = 1, 5 do
		local angle = math.rad(index * 72)
		Build.pollen(Vector3.new(math.sin(angle) * 80, 16, math.cos(angle) * 80), root)
	end
end

-- Kiosks -----------------------------------------------------------------

local function kiosk(position: Vector3, label: string, subtitle: string, tint: Color3, view: string?, onUse: ((Player) -> ())?)
	local cf = CFrame.lookAt(position, Vector3.new(0, 0, 0))
	local glow = Build.stall(cf, tint, root)

	Build.hologram(position + Vector3.new(0, 17, 0), label, subtitle, tint, root)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = glow

	prompt.Triggered:Connect(function(player)
		if onUse then
			onUse(player)
		elseif view then
			Remotes.event("OpenMenu"):FireClient(player, { view = view })
		end
	end)
end

local function buildKiosks()
	kiosk(Vector3.new(-40, 0, 96), "SHOP", "gamepasses & coins", Palette.gold, "shop")
	kiosk(Vector3.new(40, 0, 96), "QUESTS", "free coin rewards", Palette.pink, "achievements")
	kiosk(Vector3.new(-40, 0, -96), "REBIRTH", "reset for power", Palette.purple, "rebirth")
	kiosk(Vector3.new(40, 0, -96), "DAILY", "claim once a day", Palette.green, nil, function(player)
		DailyService.claim(player)
	end)
end

-- Leaderboards -----------------------------------------------------------

local BOARD_ROWS = 14

local function renderBoards()
	for _, board in ipairs(LeaderboardService.snapshot()) do
		local labels = boardLabels[board.key]
		if labels then
			for index, row in ipairs(labels) do
				local entry = board.rows[index]
				if entry then
					row.Text = ("%d. %s  %s"):format(
						entry.rank,
						entry.name,
						Format.value(board.format, entry.value)
					)
					row.TextColor3 = index <= 3 and Palette.gold or Color3.fromRGB(238, 232, 216)
				else
					row.Text = ("%d. —"):format(index)
					row.TextColor3 = Color3.fromRGB(128, 122, 112)
				end
			end
		end
	end
end

local function buildGraveyard()
	local boards = {
		{ key = "score", title = "Top Scanners", offset = -26 },
		{ key = "playtime", title = "Most Playtime", offset = 0 },
		{ key = "accountValue", title = "Richest", offset = 26 },
	}

	for _, board in ipairs(boards) do
		-- Rotated to face +X, i.e. back towards the square, so they spread
		-- along Z to stand side by side rather than one behind another.
		local cf = CFrame.new(Vector3.new(-120, 0, board.offset)) * CFrame.Angles(0, math.rad(90), 0)
		boardLabels[board.key] = Build.gravestone(cf, board.title, BOARD_ROWS, root)
	end
end

-- Sky ruins (obby) -------------------------------------------------------

local function buildRuins()
	local centre = Vector3.new(-150, 0, -140)

	Build.part({
		Name = "RuinBase",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 52, 52),
		CFrame = CFrame.new(centre + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(150, 142, 130),
		Material = Enum.Material.Slate,
	}, root)

	local pillar = Build.part({
		Name = "RuinPillar",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(118, 12, 12),
		CFrame = CFrame.new(centre + Vector3.new(0, 59, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(176, 168, 152),
		Material = Enum.Material.Brick,
	}, root)
	Build.hologram(centre + Vector3.new(0, 30, 0), "SKY RUINS", "climb for the chest", Palette.gold, root)

	local steps = 18
	for index = 1, steps do
		local angle = math.rad(index * 58)
		local height = 6 + index * 5.8
		local reach = 19

		Build.part({
			Name = "RuinStep" .. index,
			Size = Vector3.new(11, 1.4, 11),
			CFrame = CFrame.new(centre + Vector3.new(math.sin(angle) * reach, height, math.cos(angle) * reach))
				* CFrame.Angles(0, angle, 0),
			Color = Color3.fromRGB(196, 188, 170),
			Material = Enum.Material.Slate,
		}, root)

		if index % 3 == 0 then
			PickupService.spawnOrb(
				centre + Vector3.new(math.sin(angle) * reach, height + 3.5, math.cos(angle) * reach),
				40,
				Palette.cyan
			)
		end
	end

	local top = Build.part({
		Name = "RuinTop",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.4, 30, 30),
		CFrame = CFrame.new(centre + Vector3.new(0, 6 + steps * 5.8 + 4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Palette.gold,
		Material = Enum.Material.Marble,
	}, root)

	PickupService.spawnChest(top.Position + Vector3.new(0, 4, 0), 900, 180, "RUINS CHEST")
end

-- Void isle + portals ----------------------------------------------------

local function teleporter(position: Vector3, destination: Vector3, tint: Color3, label: string, requirement: number?)
	local pad = Build.portal(position, tint, label, root)
	local busy: { [number]: boolean } = {}

	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or busy[player.UserId] then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not rootPart then
			return
		end

		busy[player.UserId] = true
		task.delay(2, function()
			busy[player.UserId] = nil
		end)

		if requirement then
			local profile = DataService.get(player)
			local score = profile and StateService.scoreFor(profile) or 0
			if score < requirement then
				StateService.notify(
					player,
					("Void Isle needs %d scanner score. You have %d."):format(requirement, score),
					"!",
					Palette.red
				)
				return
			end
		end

		rootPart.CFrame = CFrame.new(destination)
		StateService.notify(player, label, "*", tint)
	end)
end

local function buildVoid()
	Build.part({
		Name = "VoidIsle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(8, 170, 170),
		CFrame = CFrame.new(VOID_CENTRE - Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Palette.purple,
		Material = Enum.Material.Slate,
	}, root)

	for index = 1, 10 do
		local angle = math.rad(index * 36)
		Build.part({
			Name = "VoidSpire" .. index,
			Size = Vector3.new(6, math.random(18, 44), 6),
			Position = VOID_CENTRE + Vector3.new(math.sin(angle) * 70, 14, math.cos(angle) * 70),
			Color = index % 2 == 0 and Palette.pink or Palette.cyan,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
		}, root)
	end

	PickupService.scatter(VOID_CENTRE, 66, 18, 120, Palette.purple)
	PickupService.spawnChest(VOID_CENTRE + Vector3.new(0, 4, 0), 4000, 300, "VOID CHEST")

	-- Out and back.
	teleporter(
		Vector3.new(0, 0, -110),
		VOID_CENTRE + Vector3.new(0, 6, 40),
		Palette.purple,
		("VOID ISLE  ·  %d SCORE"):format(VOID_REQUIREMENT),
		VOID_REQUIREMENT
	)
	teleporter(
		VOID_CENTRE + Vector3.new(0, 0, 62),
		Vector3.new(0, 6, -92),
		Palette.cyan,
		"BACK TO TOWN",
		nil
	)
end

-- Build ------------------------------------------------------------------

function WorldBuilder.build()
	if root then
		return
	end

	root = Instance.new("Folder")
	root.Name = "StatScannerWorld"
	root.Parent = workspace

	-- Ground and spawn go down before the editor placeholder is removed, so
	-- there is never an instant with nothing underneath a spawning player.
	buildGround()

	local placeholder = workspace:FindFirstChild("EditorPlaceholder")
	if placeholder then
		placeholder:Destroy()
	end

	buildShrine()
	buildMarket()
	buildTown()
	buildKiosks()
	buildGraveyard()
	buildRuins()
	buildVoid()

	-- Orbs along the paths so there is always something to run for.
	for _, angle in ipairs({ 0, 90, 180, 270 }) do
		local radians = math.rad(angle)
		local direction = Vector3.new(math.sin(radians), 0, math.cos(radians))
		for step = 1, 7 do
			PickupService.spawnOrb(direction * (55 + step * 15) + Vector3.new(0, 3, 0), 14)
		end
	end

	PickupService.scatter(Vector3.new(0, 0, 0), 100, 14, 12)

	task.spawn(function()
		while true do
			pcall(renderBoards)
			task.wait(BOARD_REFRESH)
		end
	end)

	Players.PlayerAdded:Connect(function()
		task.delay(3, function()
			pcall(renderBoards)
		end)
	end)
end

return WorldBuilder
