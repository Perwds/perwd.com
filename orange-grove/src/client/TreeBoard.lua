--!strict
-- Paints the upgrade board for this player: plate colours and text, path states, hover lift and
-- tooltip, buying (prompt, click, hold to repeat), the purchase pulse and the draw-in of new paths.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Palette = require(Shared.Palette)
local UpgradeTree = require(Shared.UpgradeTree)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)

local TreeBoard = {}

local player = Players.LocalPlayer
local remotes: Folder

type PlateView = {
	node: any,
	model: Model,
	plate: BasePart,
	edge: BasePart,
	face: Frame,
	prompt: ProximityPrompt,
	click: ClickDetector,
	basePivot: CFrame,
	lift: NumberValue,
	state: string?,
	level: number,
	buyable: boolean,
}

local views: { [string]: PlateView } = {}
local pathsByChild: { [string]: { Model } } = {}
local tooltip: BillboardGui
local tooltipTitle: TextLabel
local tooltipBody: TextLabel
local tooltipCost: TextLabel
local mouseHover: string? = nil
local hovered: string? = nil
local holding: { [string]: boolean } = {}
local firstRender = true

local function sendBuy(view: PlateView)
	if view.buyable then
		remotes.BuyNode:FireServer(view.node.id)
	end
end

local function setLift(view: PlateView, target: number)
	TweenService:Create(
		view.lift,
		TweenInfo.new(if target > 0 then 0.2 else 0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = target }
	):Play()
end

local function costText(node: any, level: number, max: number): string
	if level >= max then
		return if max == 1 then "OWNED" else "MAXED"
	end
	local price = State.econ:cost(node, level)
	return State.fmt(price) .. " " .. State.currencyName(node.currency)
end

local function paintPlate(view: PlateView, snapshot: { [string]: any })
	local node = view.node
	local levels = snapshot.levels
	local mods = snapshot.mods
	local zone = Palette.zones[node.zone]
	local state = State.econ:nodeState(levels, node.id, mods)
	local level = levels[node.id] or 0
	local max = State.econ:maxLevel(node, mods)
	local face = view.face
	local labels = {
		face:FindFirstChild("Title") :: TextLabel,
		face:FindFirstChild("Effect") :: TextLabel,
		face:FindFirstChild("Cost") :: TextLabel,
		face:FindFirstChild("Level") :: TextLabel,
	}
	local mystery = face:FindFirstChild("Mystery") :: TextLabel

	local color, ink
	if state == "hidden" or state == "locked" then
		color, ink = Palette.locked, Palette.lockedInk
	elseif level > 0 then
		color, ink = zone.bought, Palette.boughtInk
	else
		color, ink = zone.plate, zone.ink
	end
	view.plate.Color = color
	for _, l in labels do
		l.TextColor3 = ink
		l.Visible = state ~= "hidden"
	end
	mystery.Visible = state == "hidden"
	mystery.TextColor3 = Palette.lockedInk
	labels[3].Text = costText(node, level, max)
	labels[4].Text = level .. "/" .. max

	local open = state == "available" or state == "owned"
	local affordable = open and (snapshot.c[node.currency] or 0) >= State.econ:cost(node, level)
	view.buyable = open
	view.prompt.Enabled = open
	view.prompt.ActionText = if level > 0 then "Upgrade" else "Buy"
	-- A glowing edge means "you can buy this right now".
	view.edge.Color = if affordable then zone.neon else Palette.plateEdge
	view.edge.Material = if affordable then Enum.Material.Neon else Enum.Material.SmoothPlastic

	return state, level
end

local function segmentsOf(path: Model): { BasePart }
	local list = {}
	for i = 1, 4 do
		local seg = path:FindFirstChild("Seg" .. i) :: BasePart?
		if seg then
			table.insert(list, seg)
		end
	end
	return list
end

local function paintPaths(childId: string, state: string, level: number)
	local zone = Palette.zones[UpgradeTree.byId[childId].zone]
	for _, path in pathsByChild[childId] or {} do
		for _, seg in segmentsOf(path) do
			if level > 0 then
				seg.Color = zone.neon
				seg.Material = Enum.Material.Neon
			elseif state == "available" then
				seg.Color = zone.plate
				seg.Material = Enum.Material.SmoothPlastic
			else
				seg.Color = Palette.lockedPath
				seg.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

-- A spark runs from the parent plate to the one just bought.
local function pulse(childId: string)
	for _, path in pathsByChild[childId] or {} do
		local points = {}
		for _, seg in segmentsOf(path) do
			if #points == 0 then
				table.insert(points, seg:GetAttribute("From") :: Vector3)
			end
			table.insert(points, seg:GetAttribute("To") :: Vector3)
		end
		if #points >= 2 then
			local spark = Instance.new("Part")
			spark.Shape = Enum.PartType.Ball
			spark.Size = Vector3.new(2.6, 2.6, 2.6)
			spark.Material = Enum.Material.Neon
			spark.Color = Color3.new(1, 1, 1)
			spark.Anchored = true
			spark.CanCollide = false
			spark.CanQuery = false
			spark.CastShadow = false
			spark.Position = points[1]
			spark.Parent = workspace
			task.spawn(function()
				local total = 0
				for i = 2, #points do
					total += (points[i] - points[i - 1]).Magnitude
				end
				local duration = 0.4
				for i = 2, #points do
					local leg = (points[i] - points[i - 1]).Magnitude
					local t = TweenService:Create(
						spark,
						TweenInfo.new(duration * leg / math.max(total, 1), Enum.EasingStyle.Linear),
						{ Position = points[i] }
					)
					t:Play()
					t.Completed:Wait()
				end
				TweenService:Create(spark, TweenInfo.new(0.2), { Size = Vector3.new(5, 5, 5), Transparency = 1 }):Play()
				task.wait(0.2)
				spark:Destroy()
			end)
		end
	end
end

-- New reachable paths grow out from the parent instead of popping in.
local function drawIn(childId: string)
	for _, path in pathsByChild[childId] or {} do
		task.spawn(function()
			for _, seg in segmentsOf(path) do
				local full = seg.Size
				local finalCF = seg.CFrame
				local from = seg:GetAttribute("From") :: Vector3
				local alongX = full.X > full.Z
				seg.Size = if alongX then Vector3.new(0.1, full.Y, full.Z) else Vector3.new(full.X, full.Y, 0.1)
				seg.CFrame = CFrame.new(Vector3.new(from.X, finalCF.Position.Y, from.Z))
				local t = TweenService:Create(
					seg,
					TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = full, CFrame = finalCF }
				)
				t:Play()
				t.Completed:Wait()
			end
		end)
	end
end

local function showTooltip(view: PlateView?)
	if not view or view.state == "hidden" then
		tooltip.Enabled = false
		return
	end
	local node = view.node
	tooltip.Adornee = view.plate
	tooltipTitle.Text = node.name
	tooltipBody.Text = node.desc
	local snapshot = State.current
	if snapshot then
		local max = State.econ:maxLevel(node, snapshot.mods)
		local level = snapshot.levels[node.id] or 0
		local status = if view.state == "locked" then "Needs the plate before it" else costText(node, level, max)
		tooltipCost.Text = status
			.. "   "
			.. level
			.. "/"
			.. max
			.. (if node.permanent then "   Kept on Replant" else "")
	end
	tooltip.Enabled = true
end

local function setHovered(id: string?)
	if hovered == id then
		return
	end
	if hovered and views[hovered] then
		setLift(views[hovered], 0)
	end
	hovered = id
	if id and views[id] then
		setLift(views[id], 0.6)
	end
	showTooltip(if id then views[id] else nil)
end

local function render(snapshot: { [string]: any })
	for id, view in views do
		local before = view.state
		local beforeLevel = view.level
		local state, level = paintPlate(view, snapshot)
		paintPaths(id, state, level)
		if not firstRender then
			if beforeLevel == 0 and level > 0 then
				pulse(id)
			elseif before ~= "available" and state == "available" and not State.reduceMotion() then
				drawIn(id)
			end
		end
		view.state = state
		view.level = level
	end
	firstRender = false
	if hovered then
		showTooltip(views[hovered])
	end
end

local function buildTooltip()
	tooltip = Ui.new("BillboardGui", {
		Name = "PlateTooltip",
		Size = UDim2.fromOffset(320, 120),
		StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0),
		AlwaysOnTop = true,
		LightInfluence = 0,
		MaxDistance = 60,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local card = Ui.panel({ Size = UDim2.fromScale(1, 1), Parent = tooltip })
	Ui.padding(10).Parent = card
	tooltipTitle = Ui.text({
		Font = Ui.TITLE,
		TextSize = 20,
		TextColor3 = Palette.gold,
		Size = UDim2.new(1, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
	tooltipBody = Ui.text({
		TextSize = 15,
		TextWrapped = true,
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 54),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})
	tooltipCost = Ui.text({
		Font = Ui.TITLE,
		TextSize = 16,
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})
end

local function bindPlate(model: Model)
	local id = model:GetAttribute("NodeId") :: string?
	local node = id and UpgradeTree.byId[id]
	if not node then
		return
	end
	local plate = model:WaitForChild("Plate") :: BasePart
	local face = (plate:WaitForChild("Face") :: SurfaceGui):WaitForChild("Content") :: Frame
	local view: PlateView = {
		node = node,
		model = model,
		plate = plate,
		edge = model:WaitForChild("Edge") :: BasePart,
		face = face,
		prompt = plate:WaitForChild("Buy") :: ProximityPrompt,
		click = plate:WaitForChild("ClickDetector") :: ClickDetector,
		basePivot = model:GetPivot(),
		lift = Instance.new("NumberValue"),
		state = nil,
		level = 0,
		buyable = false,
	}
	view.lift.Changed:Connect(function(value)
		model:PivotTo(view.basePivot + Vector3.new(0, value, 0))
	end)

	-- Hold the prompt to keep buying: one on press, then a steady repeat after a short pause.
	view.prompt.Triggered:Connect(function()
		sendBuy(view)
		holding[id :: string] = true
		task.delay(0.35, function()
			while holding[id :: string] and view.buyable do
				sendBuy(view)
				task.wait(0.12)
			end
		end)
	end)
	view.prompt.TriggerEnded:Connect(function()
		holding[id :: string] = nil
	end)
	view.click.MouseClick:Connect(function()
		sendBuy(view)
	end)
	view.click.MouseHoverEnter:Connect(function()
		mouseHover = id
	end)
	view.click.MouseHoverLeave:Connect(function()
		if mouseHover == id then
			mouseHover = nil
		end
	end)
	views[id :: string] = view
end

local function onBuyResult(nodeId: string, ok: boolean, reason: string)
	local view = views[nodeId]
	if not view then
		return
	end
	if ok then
		Audio.chime()
		-- A quick press-down so the plate feels pushed.
		view.lift.Value = -0.35
		setLift(view, if hovered == nodeId then 0.6 else 0)
	elseif reason == "afford" then
		holding[nodeId] = nil
		Audio.deny()
		local cost = view.face:FindFirstChild("Cost") :: TextLabel
		local ink = cost.TextColor3
		cost.TextColor3 = Palette.deny
		task.delay(0.3, function()
			cost.TextColor3 = ink
		end)
		if not State.reduceMotion() then
			local base = view.basePivot
			task.spawn(function()
				for _, dx in { 0.25, -0.25, 0.15, 0 } do
					view.model:PivotTo(base * CFrame.new(dx, view.lift.Value, 0))
					task.wait(0.04)
				end
			end)
		end
	elseif reason == "maxed" or reason == "locked" then
		holding[nodeId] = nil
	end
end

function TreeBoard.views(): { [string]: any }
	return views
end

function TreeBoard.setTextDistance(distance: number)
	for _, view in views do
		local gui = view.plate:FindFirstChild("Face") :: SurfaceGui?
		if gui then
			gui.MaxDistance = distance
		end
	end
end

function TreeBoard.init(remoteFolder: Folder)
	remotes = remoteFolder
	local board = workspace:WaitForChild("Board")
	local plates = board:WaitForChild("Plates")
	local paths = board:WaitForChild("Paths")

	buildTooltip()
	for _, model in plates:GetChildren() do
		bindPlate(model :: Model)
	end
	plates.ChildAdded:Connect(function(model)
		bindPlate(model :: Model)
	end)
	local function addPath(path: Instance)
		local child = path:GetAttribute("Child") :: string?
		if child then
			pathsByChild[child] = pathsByChild[child] or {}
			table.insert(pathsByChild[child], path :: Model)
		end
	end
	for _, path in paths:GetChildren() do
		addPath(path)
	end
	paths.ChildAdded:Connect(addPath)

	remotes.BuyResult.OnClientEvent:Connect(onBuyResult)
	State.onChange(render)

	-- Standing on or next to a plate counts as hovering it, so touch and gamepad players get tooltips too.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local nearest, best = nil, 7.5
		if root then
			for id, view in views do
				local d = (view.basePivot.Position - root.Position) * Vector3.new(1, 0, 1)
				if d.Magnitude < best then
					nearest, best = id, d.Magnitude
				end
			end
		end
		setHovered(mouseHover or nearest)
	end)
end

return TreeBoard
