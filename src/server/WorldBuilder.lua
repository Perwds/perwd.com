--!strict
--[[
	WorldBuilder
	Generates the lobby entirely from code so the place file stays empty and
	everything lives in version control: a floor, spawn, the scanner podium
	that opens the menu, and six physical leaderboard pillars.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)

local LeaderboardService = require(script.Parent.LeaderboardService)

local WorldBuilder = {}

local FLOOR_SIZE = 220
local BOARD_REFRESH = 30

local root: Folder
local boardLabels: { [string]: { TextLabel } } = {}

local function part(props: { [string]: any }): BasePart
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.Material = Enum.Material.SmoothPlastic
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	instance.Parent = root
	return instance
end

local function buildFloor()
	part({
		Name = "Floor",
		Size = Vector3.new(FLOOR_SIZE, 4, FLOOR_SIZE),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(64, 200, 84),
		Material = Enum.Material.Grass,
	})

	-- A darker inlay under the podium so the centre reads as a stage.
	part({
		Name = "Stage",
		Size = Vector3.new(60, 1, 60),
		Position = Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(48, 54, 72),
	})

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(14, 1, 14)
	spawnLocation.Position = Vector3.new(0, 1.5, 22)
	spawnLocation.Color = Color3.fromRGB(96, 220, 128)
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Duration = 0
	spawnLocation.Parent = root
end

local function buildPodium()
	local base = part({
		Name = "PodiumBase",
		Size = Vector3.new(16, 3, 16),
		Position = Vector3.new(0, 2.5, 0),
		Color = Color3.fromRGB(38, 42, 56),
	})

	local core = part({
		Name = "PodiumCore",
		Size = Vector3.new(6, 9, 6),
		Position = Vector3.new(0, 8.5, 0),
		Color = Color3.fromRGB(96, 186, 255),
		Material = Enum.Material.Neon,
		Shape = Enum.PartType.Block,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Check your stats"
	prompt.ObjectText = "STAT SCANNER"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 22
	prompt.RequiresLineOfSight = false
	prompt.Parent = core

	prompt.Triggered:Connect(function(player)
		Remotes.event("OpenMenu"):FireClient(player)
	end)

	local sign = Instance.new("BillboardGui")
	sign.Name = "PodiumSign"
	sign.Size = UDim2.fromScale(18, 4)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 200
	sign.Parent = core

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "STAT SCANNER"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Parent = sign

	-- Slow spin: purely cosmetic, cheap enough to run every frame on the server
	-- because it is one CFrame write.
	task.spawn(function()
		local angle = 0
		while core.Parent do
			angle += 0.01
			core.CFrame = CFrame.new(core.Position) * CFrame.Angles(0, angle, 0)
			task.wait(0.03)
		end
	end)

	return base
end

local function buildBoard(key: string, title: string, icon: string, position: Vector3, rotation: number)
	local pillar = part({
		Name = "Board_" .. key,
		Size = Vector3.new(18, 22, 1.5),
		CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0),
		Color = Color3.fromRGB(30, 33, 44),
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Display"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(540, 660)
	surface.LightInfluence = 0
	surface.Parent = pillar

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
	background.BorderSizePixel = 0
	background.Parent = surface

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 70)
	header.BackgroundColor3 = Color3.fromRGB(38, 44, 62)
	header.BorderSizePixel = 0
	header.Font = Enum.Font.FredokaOne
	header.Text = icon .. " " .. title
	header.TextColor3 = Color3.new(1, 1, 1)
	header.TextScaled = true
	header.Parent = background

	local list = Instance.new("Frame")
	list.Position = UDim2.new(0, 8, 0, 78)
	list.Size = UDim2.new(1, -16, 1, -86)
	list.BackgroundTransparency = 1
	list.Parent = background

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local labels = {}
	for index = 1, 15 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 36)
		row.LayoutOrder = index
		row.BackgroundColor3 = index % 2 == 0 and Color3.fromRGB(30, 33, 44) or Color3.fromRGB(35, 39, 52)
		row.BorderSizePixel = 0
		row.Font = Enum.Font.GothamMedium
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(230, 235, 245)
		row.TextSize = 22
		row.Text = ""
		row.Parent = list

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
					row.Text = ("#%d  %s  —  %s"):format(
						entry.rank,
						entry.name,
						Format.value(board.format, entry.value)
					)
					row.TextColor3 = index <= 3 and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(230, 235, 245)
				else
					row.Text = ("#%d  —"):format(index)
					row.TextColor3 = Color3.fromRGB(110, 118, 136)
				end
			end
		end
	end
end

function WorldBuilder.build()
	if root then
		return
	end

	root = Instance.new("Folder")
	root.Name = "StatScannerWorld"
	root.Parent = workspace

	buildFloor()
	buildPodium()

	local boards = {
		{ key = "score", title = "SCANNER SCORE", icon = "🏅" },
		{ key = "playtime", title = "PLAYTIME", icon = "⏱️" },
		{ key = "accountValue", title = "ACCOUNT VALUE", icon = "💎" },
		{ key = "walkDistance", title = "WALK DISTANCE", icon = "🚶" },
		{ key = "badges", title = "BADGES", icon = "🎖️" },
		{ key = "rebirths", title = "REBIRTHS", icon = "🌟" },
	}

	local radius = 52
	for index, board in ipairs(boards) do
		local angle = math.rad(180 + (index - 1) * (360 / #boards))
		local position = Vector3.new(math.sin(angle) * radius, 12, math.cos(angle) * radius)
		local facing = math.deg(math.atan2(-position.X, -position.Z))
		buildBoard(board.key, board.title, board.icon, position, facing)
	end

	task.spawn(function()
		while true do
			pcall(renderBoards)
			task.wait(BOARD_REFRESH)
		end
	end)

	-- Give late joiners a board refresh so they never see empty pillars.
	Players.PlayerAdded:Connect(function()
		task.delay(3, function()
			pcall(renderBoards)
		end)
	end)
end

return WorldBuilder
