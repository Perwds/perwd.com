--!strict
--[[
	WorldBuilder
	Generates the whole lobby from code so the place file stays empty and
	everything lives in version control.

	It is deliberately a small arena -- an 84x84 walled plaza you can cross in a
	few seconds -- because every menu is one keypress away and nothing is gained
	by making players walk. The layout:

	    spawn pad (south)  ->  scanner podium (centre)
	    three kiosks (north): Shop / Rebirth / Awards
	    three leaderboard boards on the north wall

	Each kiosk carries a ProximityPrompt and a floating sign, and opens the
	matching tab of the screen UI through the OpenMenu remote.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Format = require(Shared.Format)
local Palette = require(Shared.Palette)

local DailyService = require(script.Parent.DailyService)
local LeaderboardService = require(script.Parent.LeaderboardService)

local WorldBuilder = {}

local FLOOR_SIZE = 84
local WALL_HEIGHT = 14
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

--- Floating label above a part.
local function sign(parent: BasePart, text: string, color: Color3, height: number, size: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromScale(11, 2.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 140
	billboard.Parent = parent

	local backing = Instance.new("Frame")
	backing.Size = UDim2.fromScale(1, 1)
	backing.BackgroundColor3 = Palette.dark
	backing.BackgroundTransparency = 0.25
	backing.BorderSizePixel = 0
	backing.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = backing

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = backing

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = backing

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = size
	constraint.Parent = label

	return label
end

-- Plaza ------------------------------------------------------------------

local function buildPlaza()
	part({
		Name = "Floor",
		Size = Vector3.new(FLOOR_SIZE, 4, FLOOR_SIZE),
		Position = Vector3.new(0, -2, 0),
		Color = Palette.recess,
		Material = Enum.Material.Concrete,
	})

	-- Grass border so the plaza reads as a platform, not a void.
	part({
		Name = "Lawn",
		Size = Vector3.new(FLOOR_SIZE + 24, 3, FLOOR_SIZE + 24),
		Position = Vector3.new(0, -3, 0),
		Color = Palette.shadowDeep,
		Material = Enum.Material.Concrete,
	})

	-- Neon inlay ring under the podium.
	part({
		Name = "Inlay",
		Size = Vector3.new(26, 0.4, 26),
		Position = Vector3.new(0, 0.2, 0),
		Color = Palette.accent,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
	})

	local walls = {
		{ size = Vector3.new(FLOOR_SIZE, WALL_HEIGHT, 2), pos = Vector3.new(0, WALL_HEIGHT / 2, -FLOOR_SIZE / 2) },
		{ size = Vector3.new(FLOOR_SIZE, WALL_HEIGHT, 2), pos = Vector3.new(0, WALL_HEIGHT / 2, FLOOR_SIZE / 2) },
		{ size = Vector3.new(2, WALL_HEIGHT, FLOOR_SIZE), pos = Vector3.new(-FLOOR_SIZE / 2, WALL_HEIGHT / 2, 0) },
		{ size = Vector3.new(2, WALL_HEIGHT, FLOOR_SIZE), pos = Vector3.new(FLOOR_SIZE / 2, WALL_HEIGHT / 2, 0) },
	}

	for index, wall in ipairs(walls) do
		part({
			Name = "Wall" .. index,
			Size = wall.size,
			Position = wall.pos,
			Color = Palette.dark,
		})
		-- Neon cap along the top of each wall.
		part({
			Name = "WallTrim" .. index,
			Size = Vector3.new(wall.size.X, 0.5, wall.size.Z),
			Position = wall.pos + Vector3.new(0, WALL_HEIGHT / 2, 0),
			Color = Palette.accent,
			Material = Enum.Material.Neon,
		})
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Spawn"
	spawnLocation.Anchored = true
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.Position = Vector3.new(0, 0.5, 28)
	spawnLocation.Color = Palette.ledGreen
	spawnLocation.Material = Enum.Material.Neon
	spawnLocation.Duration = 0
	spawnLocation.Parent = root

	sign(spawnLocation, "SPAWN", Palette.ledGreen, 4, 26)
end

-- Scanner podium ---------------------------------------------------------

local function buildPodium()
	part({
		Name = "PodiumBase",
		Size = Vector3.new(14, 2, 14),
		Position = Vector3.new(0, 1, 0),
		Color = Palette.dark,
	})

	local core = part({
		Name = "PodiumCore",
		Size = Vector3.new(5, 8, 5),
		Position = Vector3.new(0, 6, 0),
		Color = Palette.accent,
		Material = Enum.Material.Neon,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Check your stats"
	prompt.ObjectText = "STAT SCANNER"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Parent = core

	prompt.Triggered:Connect(function(player)
		Remotes.event("OpenMenu"):FireClient(player, { view = "stats" })
	end)

	sign(core, "STAT SCANNER", Palette.highlight, 6.5, 42)

	task.spawn(function()
		local angle = 0
		while core.Parent do
			angle += 0.015
			core.CFrame = CFrame.new(core.Position) * CFrame.Angles(0, angle, 0)
			task.wait(0.03)
		end
	end)
end

-- Kiosks -----------------------------------------------------------------

local KIOSKS = {
	{
		name = "Shop",
		label = "SHOP",
		action = "Open the shop",
		color = Palette.accent,
		position = Vector3.new(-18, 0, -18),
		view = "shop",
	},
	{
		name = "Rebirth",
		label = "REBIRTH",
		action = "Rebirth",
		color = Palette.accent,
		position = Vector3.new(0, 0, -22),
		view = "rebirth",
	},
	{
		name = "Awards",
		label = "AWARDS",
		action = "View achievements",
		color = Palette.ledAmber,
		position = Vector3.new(18, 0, -18),
		view = "achievements",
	},
	{
		name = "Daily",
		label = "DAILY REWARD",
		action = "Claim today's coins",
		color = Palette.ledGreen,
		position = Vector3.new(-28, 0, 6),
		view = nil, -- claims directly instead of opening a tab
	},
}

local function buildKiosk(config)
	local pad = part({
		Name = "Kiosk" .. config.name,
		Size = Vector3.new(10, 1, 10),
		Position = config.position + Vector3.new(0, 0.5, 0),
		Color = config.color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
	})

	local post = part({
		Name = "Post" .. config.name,
		Size = Vector3.new(1.4, 7, 1.4),
		Position = config.position + Vector3.new(0, 4, 0),
		Color = Palette.dark,
	})

	sign(post, config.label, config.color, 5, 34)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = config.action
	prompt.ObjectText = config.label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = post

	prompt.Triggered:Connect(function(player)
		if config.view then
			Remotes.event("OpenMenu"):FireClient(player, { view = config.view })
		else
			DailyService.claim(player)
		end
	end)

	return pad
end

-- Leaderboard boards -----------------------------------------------------

local BOARD_ROWS = 10

local function buildBoard(key: string, title: string, icon: string, position: Vector3)
	local frame = part({
		Name = "Board_" .. key,
		Size = Vector3.new(22, 16, 1),
		Position = position,
		Color = Palette.dark,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Display"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(560, 420)
	surface.LightInfluence = 0
	surface.Parent = frame

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Palette.dark
	background.BorderSizePixel = 0
	background.Parent = surface

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 56)
	header.BackgroundColor3 = Palette.darkSlate
	header.BorderSizePixel = 0
	header.Font = Enum.Font.GothamBlack
	header.Text = icon .. "  " .. title
	header.TextColor3 = Palette.darkText
	header.TextScaled = true
	header.Parent = background

	local list = Instance.new("Frame")
	list.Position = UDim2.new(0, 8, 0, 62)
	list.Size = UDim2.new(1, -16, 1, -70)
	list.BackgroundTransparency = 1
	list.Parent = background

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local labels = {}
	for index = 1, BOARD_ROWS do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 33)
		row.LayoutOrder = index
		row.BackgroundColor3 = index % 2 == 0 and Palette.dark or Palette.darkSlate
		row.BorderSizePixel = 0
		row.Font = Enum.Font.RobotoMono
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Palette.darkText
		row.TextSize = 20
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
					row.TextColor3 = index <= 3 and Palette.accent or Palette.darkText
				else
					row.Text = ("#%d  —"):format(index)
					row.TextColor3 = Palette.darkTextMuted
				end
			end
		end
	end
end

-- Build ------------------------------------------------------------------

function WorldBuilder.build()
	if root then
		return
	end

	root = Instance.new("Folder")
	root.Name = "StatScannerWorld"
	root.Parent = workspace

	buildPlaza()
	buildPodium()

	for _, config in ipairs(KIOSKS) do
		buildKiosk(config)
	end

	-- Three boards flat against the north wall. The remaining boards live in
	-- the Boards tab of the menu, so the plaza stays uncluttered.
	local wallZ = -FLOOR_SIZE / 2 + 1.5
	buildBoard("score", "SCANNER SCORE", "01", Vector3.new(-24, 9, wallZ))
	buildBoard("playtime", "PLAYTIME", "02", Vector3.new(0, 9, wallZ))
	buildBoard("accountValue", "ACCOUNT VALUE", "03", Vector3.new(24, 9, wallZ))

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
