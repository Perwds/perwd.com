--!strict
-- Draws this player's oranges on every tree and turns clicks, taps, prompts and R2 into pick requests.
-- Ripeness comes from the server (server-clock timestamps); the client only predicts which slot goes next.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local State = require(script.Parent.State)
local PickFx = require(script.Parent.PickFx)

local Orchard = {}

local player = Players.LocalPlayer
local remotes: Folder

type TreeView = {
	id: string,
	model: Model,
	trunk: BasePart,
	prompt: ProximityPrompt,
	slots: { Attachment },
	fruit: { BasePart },
	ripeAt: { number },
	phase: number,
}

local trees: { [string]: TreeView } = {}
local fruitOwner: { [BasePart]: string } = {}
local ripenSeconds = Config.Grove.ripenSeconds
local fruitFolder: Folder
local onPick: { () -> () } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function makeFruit(view: TreeView, index: number): BasePart
	local fruit = Instance.new("Part")
	fruit.Name = "Orange"
	fruit.Shape = Enum.PartType.Ball
	fruit.Size = Vector3.new(1.3, 1.3, 1.3)
	fruit.Color = Palette.orange
	fruit.Material = Enum.Material.SmoothPlastic
	fruit.Anchored = true
	fruit.CanCollide = false
	fruit.CastShadow = false
	fruit.Parent = fruitFolder
	fruitOwner[fruit] = view.id
	view.fruit[index] = fruit
	return fruit
end

local function ripeIndex(view: TreeView): number?
	local t = now()
	for i, ripeAt in view.ripeAt do
		if ripeAt <= t then
			return i
		end
	end
	return nil
end

local function hasAccess(view: TreeView): boolean
	return not view.model:GetAttribute("Vip") or State.zoneOpen("vip")
end

local function inRange(view: TreeView): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local d = (root.Position - view.trunk.Position) * Vector3.new(1, 0, 1)
	return d.Magnitude <= Config.Grove.pickRange - 1
end

-- Predict the server: it takes the first ripe slot, so hide that one now and let the reply correct us.
local function tryPick(view: TreeView)
	if not hasAccess(view) or not inRange(view) then
		return
	end
	local index = ripeIndex(view)
	if not index then
		return
	end
	local fruit = view.fruit[index]
	view.ripeAt[index] = now() + ripenSeconds
	if fruit then
		PickFx.picked(fruit.Position)
	end
	remotes.PickOrange:FireServer(view.id)
	for _, callback in onPick do
		task.spawn(callback)
	end
end

local function nearestRipe(): TreeView?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, view in trees do
		local d = (root.Position - view.trunk.Position).Magnitude
		if d < bestDistance and ripeIndex(view) and hasAccess(view) then
			best, bestDistance = view, d
		end
	end
	return best
end

function Orchard.nearestRipe(): Model?
	local view = nearestRipe()
	return if view then view.model else nil
end

function Orchard.onPick(callback: () -> ())
	table.insert(onPick, callback)
end

local function bindTree(model: Model)
	local id = model:GetAttribute("TreeId") :: string?
	if not id then
		return
	end
	local trunk = model:WaitForChild("Trunk") :: BasePart
	local canopy = model:WaitForChild("Canopy") :: BasePart
	local slots = {}
	for i = 1, 6 do
		local slot = canopy:WaitForChild("Slot" .. i) :: Attachment
		slots[i] = slot
	end
	local view: TreeView = {
		id = id,
		model = model,
		trunk = trunk,
		prompt = trunk:WaitForChild("Pick") :: ProximityPrompt,
		slots = slots,
		fruit = {},
		ripeAt = {},
		phase = math.random() * math.pi * 2,
	}
	view.prompt.Triggered:Connect(function()
		tryPick(view)
	end)
	trees[id] = view
end

local function applyTree(view: TreeView, list: { number })
	view.ripeAt = table.clone(list)
	for i = #list + 1, #view.fruit do
		local fruit = view.fruit[i]
		if fruit then
			fruitOwner[fruit] = nil
			fruit:Destroy()
		end
		view.fruit[i] = nil
	end
	for i = 1, #list do
		if not view.fruit[i] then
			makeFruit(view, i)
		end
	end
end

local function render()
	local t = now()
	local still = State.reduceMotion()
	for _, view in trees do
		local any = false
		local visible = hasAccess(view)
		for i, fruit in view.fruit do
			local ripeAt = view.ripeAt[i] or 0
			local slot = view.slots[i]
			if not visible then
				fruit.Transparency = 1
			elseif ripeAt <= t then
				any = true
				fruit.Transparency = 0
				fruit.Color = Palette.orange
				fruit.Size = Vector3.new(1.3, 1.3, 1.3)
				local bob = if still then 0 else math.sin(t * 2.2 + view.phase + i) * 0.12
				fruit.CFrame = CFrame.new(slot.WorldPosition + Vector3.new(0, bob, 0))
			else
				local grown = math.clamp(1 - (ripeAt - t) / ripenSeconds, 0, 1)
				fruit.Transparency = if grown < 0.05 then 1 else 0
				fruit.Color = Palette.unripe:Lerp(Palette.orange, grown * grown)
				fruit.Size = Vector3.one * (0.35 + 0.6 * grown)
				fruit.CFrame = CFrame.new(slot.WorldPosition)
			end
		end
		view.prompt.Enabled = any
	end
end

local function onInput(input: InputObject, processed: boolean)
	if processed then
		return
	end
	local isClick = input.UserInputType == Enum.UserInputType.MouseButton1
	local isTap = input.UserInputType == Enum.UserInputType.Touch
	if not isClick and not isTap then
		return
	end
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 250, params)
	if not hit then
		return
	end
	local id = fruitOwner[hit.Instance :: BasePart]
	if not id then
		local model = hit.Instance:FindFirstAncestorOfClass("Model")
		id = model and model:GetAttribute("TreeId") :: string?
	end
	if id and trees[id] then
		tryPick(trees[id])
	end
end

function Orchard.init(remoteFolder: Folder)
	remotes = remoteFolder
	fruitFolder = Instance.new("Folder")
	fruitFolder.Name = "MyOranges"
	fruitFolder.Parent = workspace

	local treeFolder = workspace:WaitForChild("Board"):WaitForChild("Trees")
	for _, model in treeFolder:GetChildren() do
		bindTree(model :: Model)
	end
	treeFolder.ChildAdded:Connect(function(model)
		bindTree(model :: Model)
	end)

	remotes.Trees.OnClientEvent:Connect(function(all: { [string]: { number } }?, seconds: number)
		ripenSeconds = seconds
		if all then
			for id, list in all do
				local view = trees[id]
				if view then
					applyTree(view, list)
				end
			end
		end
	end)
	remotes.TreeUpdate.OnClientEvent:Connect(function(id: string, list: { number })
		local view = trees[id]
		if view then
			applyTree(view, list)
		end
	end)
	remotes.Picked.OnClientEvent:Connect(
		function(id: string, index: number, value: number, ripeAt: number, auto: boolean)
			local view = trees[id]
			if not view then
				return
			end
			local fruit = view.fruit[index]
			local at = if fruit then fruit.Position else view.trunk.Position + Vector3.new(0, 8, 0)
			if auto then
				PickFx.picked(at)
			end
			view.ripeAt[index] = ripeAt
			PickFx.popup(at, "+" .. State.fmt(value))
		end
	)
	remotes.RequestSync:FireServer()

	UserInputService.InputBegan:Connect(onInput)
	ContextActionService:BindAction("PickNearest", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			local view = nearestRipe()
			if view then
				tryPick(view)
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.ButtonR2)

	RunService.RenderStepped:Connect(render)
end

return Orchard
