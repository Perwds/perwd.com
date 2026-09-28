--!strict
--[[
	WorldBuilder
	Builds the whole map from code.

	Layout:

	    HUB ISLAND          spawn, scanner tower, seven category pods,
	                        shop / rebirth / daily props, leaderboard wall,
	                        coin orbs scattered across the grass
	    OBBY TOWER (west)   sixteen platforms spiralling up to a chest
	    VOID ISLAND (north) gated behind scanner score, six-times orb value
	                        and a bigger chest

	The point of the pods and the orbs is that a scan takes time: instead of
	standing in a menu watching a bar, you walk a pod, start a scan, and go
	collect while it runs.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local Palette = require(Shared.Palette)
local StatConfig = require(Shared.StatConfig)

local DataService = require(script.Parent.DataService)
local DailyService = require(script.Parent.DailyService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local PickupService = require(script.Parent.PickupService)
local ScanService = require(script.Parent.ScanService)
local StateService = require(script.Parent.StateService)

local WorldBuilder = {}

local HUB = 200
local VOID_CENTRE = Vector3.new(0, 0, -300)
local VOID_SIZE = 150
local VOID_REQUIREMENT = 30 -- scanner score needed to cross the bridge
local BOARD_REFRESH = 30

local root: Folder
local boardLabels: { [string]: { TextLabel } } = {}

-- Helpers ----------------------------------------------------------------

local function part(props: { [string]: any }, parent: Instance?): BasePart
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.Material = Enum.Material.SmoothPlastic
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	instance.Parent = parent or root
	return instance
end

local function sign(parent: BasePart, text: string, tint: Color3, height: number, size: number): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromScale(13, 3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	billboard.MaxDistance = 220
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = tint
	label.TextStrokeColor3 = Palette.outline
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = billboard

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = size
	constraint.Parent = label

	return label
end

-- Hub --------------------------------------------------------------------

local function buildHub()
	part({
		Name = "HubGrass",
		Size = Vector3.new(HUB, 6, HUB),
		Position = Vector3.new(0, -3, 0),
		Color = Palette.grass,
		Material = Enum.Material.Grass,
	})

	part({
		Name = "HubRim",
		Size = Vector3.new(HUB + 12, 4, HUB + 12),
		Position = Vector3.new(0, -6, 0),
		Color = Palette.grassDeep,
		Material = Enum.Material.Grass,
	})

	-- Paved circle under the tower.
	part({
		Name = "Plaza",
		Size = Vector3.new(78, 0.6, 78),
		Position = Vector3.new(0, 0.3, 0),
		Color = Palette.path,
		Material = Enum.Material.Sand,
	})

	-- Four paths radiating out.
	for index, angle in ipairs({ 0, 90, 180, 270 }) do
		local radians = math.rad(angle)
		part({
			Name = "Path" .. index,
			Size = Vector3.new(12, 0.5, 74),
			CFrame = CFrame.new(Vector3.new(math.sin(radians) * 72, 0.3, math.cos(radians) * 72))
				* CFrame.Angles(0, radians, 0),
			Color = Palette.path,
			Material = Enum.Material.Sand,
		})
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(16, 1, 16)
	spawnLocation.Position = Vector3.new(0, 0.8, 74)
	spawnLocation.Color = Palette.green
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Duration = 0
	spawnLocation.Parent = root
	sign(spawnLocation, "SPAWN", Palette.green, 5, 30)
end

-- Scanner tower ----------------------------------------------------------

local function buildTower()
	part({
		Name = "TowerBase",
		Size = Vector3.new(26, 3, 26),
		Position = Vector3.new(0, 1.5, 0),
		Color = Palette.stone,
	})
	part({
		Name = "TowerMid",
		Size = Vector3.new(16, 14, 16),
		Position = Vector3.new(0, 10, 0),
		Color = Palette.panel,
	})

	local core = part({
		Name = "TowerCore",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(11, 11, 11),
		Position = Vector3.new(0, 23, 0),
		Color = Palette.cyan,
		Material = Enum.Material.Neon,
	})

	local light = Instance.new("PointLight")
	light.Color = Palette.cyan
	light.Range = 40
	light.Brightness = 3
	light.Parent = core

	sign(core, "STAT SCANNER", Palette.ink, 9, 58)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open scanner"
	prompt.ObjectText = "STAT SCANNER"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 26
	prompt.RequiresLineOfSight = false
	prompt.Parent = core

	prompt.Triggered:Connect(function(player)
		Remotes.event("OpenMenu"):FireClient(player, { view = "stats" })
	end)

	task.spawn(function()
		local angle = 0
		while core.Parent do
			angle += 0.02
			core.CFrame = CFrame.new(core.Position) * CFrame.Angles(0, angle, math.sin(angle) * 0.15)
			task.wait(0.03)
		end
	end)
end

-- Category scan pods -----------------------------------------------------

local POD_COLOR = {
	core = Palette.cyan,
	movement = Palette.orange,
	combat = Palette.red,
	social = Palette.pink,
	economy = Palette.green,
	collection = Palette.purple,
	cursed = Palette.gold,
}

--- Starts the next scannable stat in a category, so a pod is a real verb
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

local function buildPods()
	local categories = StatConfig.Categories
	local radius = 62

	for index, category in ipairs(categories) do
		local angle = math.rad((index - 1) * (360 / #categories))
		local position = Vector3.new(math.sin(angle) * radius, 0, math.cos(angle) * radius)
		local tint = POD_COLOR[category.id] or Palette.purple

		local pad = part({
			Name = "Pod_" .. category.id,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.2, 18, 18),
			CFrame = CFrame.new(position + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = tint,
			Material = Enum.Material.Neon,
		})

		local post = part({
			Name = "PodPost_" .. category.id,
			Size = Vector3.new(2, 9, 2),
			Position = position + Vector3.new(0, 5, 0),
			Color = Palette.stone,
		})

		sign(post, category.icon .. " " .. category.name:upper(), tint, 6.5, 40)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Scan next"
		prompt.ObjectText = category.name:upper()
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = post

		prompt.Triggered:Connect(function(player)
			scanCategory(player, category.id)
		end)

		-- A ring of orbs around every pod.
		PickupService.scatter(position, 16, 3, 18, tint)
	end
end

-- Props ------------------------------------------------------------------

local function kiosk(position: Vector3, label: string, tint: Color3, view: string?, onUse: ((Player) -> ())?)
	local body = part({
		Name = "Kiosk_" .. label,
		Size = Vector3.new(10, 9, 8),
		Position = position + Vector3.new(0, 4.5, 0),
		Color = tint,
	})

	part({
		Name = "KioskRoof",
		Size = Vector3.new(13, 1.4, 11),
		Position = position + Vector3.new(0, 9.7, 0),
		Color = Palette.outline,
	})

	sign(body, label, Palette.ink, 7.5, 44)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Use"
	prompt.ObjectText = label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	prompt.Triggered:Connect(function(player)
		if onUse then
			onUse(player)
		elseif view then
			Remotes.event("OpenMenu"):FireClient(player, { view = view })
		end
	end)

	return body
end

local function buildProps()
	kiosk(Vector3.new(-62, 0, 44), "SHOP", Palette.gold, "shop")
	kiosk(Vector3.new(62, 0, 44), "QUESTS", Palette.pink, "achievements")
	kiosk(Vector3.new(-62, 0, -44), "REBIRTH", Palette.purple, "rebirth")
	kiosk(Vector3.new(62, 0, -44), "DAILY", Palette.green, nil, function(player)
		DailyService.claim(player)
	end)
end

-- Leaderboard wall -------------------------------------------------------

local BOARD_ROWS = 10

local function buildBoard(key: string, title: string, position: Vector3)
	local frame = part({
		Name = "Board_" .. key,
		Size = Vector3.new(26, 18, 1.5),
		Position = position,
		Color = Palette.panel,
	})

	part({
		Name = "BoardLeg",
		Size = Vector3.new(3, 12, 3),
		Position = position - Vector3.new(0, 15, 0),
		Color = Palette.stone,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(620, 430)
	surface.LightInfluence = 0
	surface.Parent = frame

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Palette.panel
	background.BorderSizePixel = 0
	background.Parent = surface

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 62)
	header.BackgroundColor3 = Palette.purple
	header.BorderSizePixel = 0
	header.Font = Enum.Font.FredokaOne
	header.Text = title
	header.TextColor3 = Palette.ink
	header.TextScaled = true
	header.Parent = background

	local list = Instance.new("Frame")
	list.Position = UDim2.new(0, 10, 0, 70)
	list.Size = UDim2.new(1, -20, 1, -80)
	list.BackgroundTransparency = 1
	list.Parent = background

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local labels = {}
	for index = 1, BOARD_ROWS do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 32)
		row.LayoutOrder = index
		row.BackgroundColor3 = index <= 3 and Palette.gold or Palette.panelLite
		row.BackgroundTransparency = index <= 3 and 0.1 or 0.35
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamBold
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Palette.ink
		row.TextSize = 19
		row.Text = ""
		row.Parent = list

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = row

		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 10)
		padding.PaddingRight = UDim.new(0, 10)
		padding.Parent = row

		labels[index] = row
	end

	boardLabels[key] = labels
end

local function renderBoards()
	for _, board in ipairs(LeaderboardService.snapshot()) do
		local labels = boardLabels[board.key]
		if labels then
			for index, row in ipairs(labels) do
				local entry = board.rows[index]
				if entry then
					row.Text = ("#%d  %s   %s"):format(
						entry.rank,
						entry.name,
						Format.value(board.format, entry.value)
					)
					row.TextColor3 = Palette.ink
				else
					row.Text = "#" .. index
					row.TextColor3 = Palette.inkDim
				end
			end
		end
	end
end

-- Obby -------------------------------------------------------------------

local function buildObby()
	local centre = Vector3.new(-128, 0, 0)

	part({
		Name = "ObbyBase",
		Size = Vector3.new(40, 6, 40),
		Position = centre - Vector3.new(0, 3, 0),
		Color = Palette.stone,
	})

	local pillar = part({
		Name = "ObbyPillar",
		Size = Vector3.new(8, 96, 8),
		Position = centre + Vector3.new(0, 48, 0),
		Color = Palette.panel,
	})
	sign(pillar, "CLIMB ME", Palette.gold, 52, 46)

	local steps = 16
	for index = 1, steps do
		local angle = math.rad(index * 62)
		local height = 6 + index * 5.4
		local reach = 15

		part({
			Name = "Step" .. index,
			Size = Vector3.new(9, 1.2, 9),
			Position = centre + Vector3.new(math.sin(angle) * reach, height, math.cos(angle) * reach),
			Color = index % 2 == 0 and Palette.cyan or Palette.pink,
			Material = Enum.Material.SmoothPlastic,
		})

		-- An orb on every third step to pay for the climb.
		if index % 3 == 0 then
			PickupService.spawnOrb(
				centre + Vector3.new(math.sin(angle) * reach, height + 3.5, math.cos(angle) * reach),
				35,
				Palette.cyan
			)
		end
	end

	local top = part({
		Name = "ObbyTop",
		Size = Vector3.new(22, 2, 22),
		Position = centre + Vector3.new(0, 6 + steps * 5.4 + 4, 0),
		Color = Palette.gold,
	})
	sign(top, "SUMMIT", Palette.gold, 5, 40)

	PickupService.spawnChest(top.Position + Vector3.new(0, 3.5, 0), 900, 180, "SUMMIT CHEST")
end

-- Void island ------------------------------------------------------------

local function buildVoid()
	part({
		Name = "VoidIsland",
		Size = Vector3.new(VOID_SIZE, 6, VOID_SIZE),
		Position = VOID_CENTRE - Vector3.new(0, 3, 0),
		Color = Palette.purple,
		Material = Enum.Material.Slate,
	})

	-- Bridge from the hub edge to the island.
	part({
		Name = "VoidBridge",
		Size = Vector3.new(14, 1.5, 130),
		Position = Vector3.new(0, 0, -165),
		Color = Palette.stone,
	})

	local gate = part({
		Name = "VoidGate",
		Size = Vector3.new(16, 16, 2),
		Position = Vector3.new(0, 8, -108),
		Color = Palette.red,
		Material = Enum.Material.ForceField,
		Transparency = 0.35,
		CanCollide = false,
	})

	sign(gate, ("VOID ISLAND — %d SCORE"):format(VOID_REQUIREMENT), Palette.red, 11, 38)

	-- Unqualified players bounce off; qualified players walk straight through.
	local bouncing: { [number]: boolean } = {}

	gate.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player or bouncing[player.UserId] then
			return
		end

		local profile = DataService.get(player)
		if not profile then
			return
		end

		local score = StateService.scoreFor(profile)
		if score >= VOID_REQUIREMENT then
			return
		end

		bouncing[player.UserId] = true

		local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			rootPart.CFrame = CFrame.new(rootPart.Position + Vector3.new(0, 2, 14))
		end

		StateService.notify(
			player,
			("Void Island needs %d scanner score. You have %d."):format(VOID_REQUIREMENT, score),
			"!",
			Palette.red
		)

		task.delay(1.5, function()
			bouncing[player.UserId] = nil
		end)
	end)

	-- Richer orbs, and a bigger chest.
	PickupService.scatter(VOID_CENTRE, 60, 16, 120, Palette.purple)
	PickupService.spawnChest(VOID_CENTRE + Vector3.new(0, 3.5, 0), 4000, 300, "VOID CHEST")

	for index = 1, 8 do
		local angle = math.rad(index * 45)
		part({
			Name = "VoidSpire" .. index,
			Size = Vector3.new(4, math.random(12, 30), 4),
			Position = VOID_CENTRE + Vector3.new(math.sin(angle) * 62, 8, math.cos(angle) * 62),
			Color = Palette.pink,
			Material = Enum.Material.Neon,
			Transparency = 0.25,
		})
	end
end

-- Build ------------------------------------------------------------------

function WorldBuilder.build()
	if root then
		return
	end

	local placeholder = workspace:FindFirstChild("EditorPlaceholder")
	if placeholder then
		placeholder:Destroy()
	end

	root = Instance.new("Folder")
	root.Name = "StatScannerWorld"
	root.Parent = workspace

	buildHub()
	buildTower()
	buildPods()
	buildProps()
	buildObby()
	buildVoid()

	-- Loose orbs across the grass, away from the pods.
	PickupService.scatter(Vector3.new(0, 0, 0), 92, 22, 12)

	buildBoard("score", "SCANNER SCORE", Vector3.new(-30, 12, -96))
	buildBoard("playtime", "PLAYTIME", Vector3.new(0, 12, -96))
	buildBoard("accountValue", "ACCOUNT VALUE", Vector3.new(30, 12, -96))

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
