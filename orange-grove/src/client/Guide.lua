--!strict
-- First-session teaching, one arrow and one line at a time, plus the grove keeper's first-visit lines.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(ReplicatedStorage.Shared.Palette)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)
local Orchard = require(script.Parent.Orchard)

local Guide = {}

local remotes: Folder
local step = 1
local picked = false
local arrow: Model

-- When each step counts as done.
local DONE: { [string]: (snapshot: { [string]: any }) -> boolean } = {
	pick = function(snapshot)
		return picked or (snapshot.c.oranges or 0) >= 10 or (snapshot.levels.seed or 0) > 0
	end,
	seed = function(snapshot)
		return (snapshot.levels.seed or 0) > 0
	end,
	riper = function(snapshot)
		return (snapshot.levels.riper or 0) > 0
	end,
	picker = function(snapshot)
		return (snapshot.levels.picker or 0) > 0
	end,
	openlab = function(snapshot)
		return (snapshot.levels.openlab or 0) > 0
	end,
}

local function buildArrow(): Model
	local model = Instance.new("Model")
	model.Name = "GuideArrow"
	local function piece(size: Vector3, offset: CFrame)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = Palette.gold
		p.Material = Enum.Material.Neon
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.CFrame = offset
		p.Parent = model
		return p
	end
	local stem = piece(Vector3.new(0.8, 2.4, 0.8), CFrame.new(0, 2.2, 0))
	piece(Vector3.new(0.8, 2, 0.8), CFrame.new(-0.62, 0.62, 0) * CFrame.Angles(0, 0, math.rad(-45)))
	piece(Vector3.new(0.8, 2, 0.8), CFrame.new(0.62, 0.62, 0) * CFrame.Angles(0, 0, math.rad(45)))
	model.PrimaryPart = stem
	model.Parent = nil
	return model
end

local function lineFor(entry: any): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and entry.touchText then
		return entry.touchText
	end
	local text = entry.text
	if UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		text = string.gsub(text, "press E", "press X")
		text = string.gsub(text, "Click", "Press R2 near")
	end
	return text
end

local function targetFor(id: string): BasePart?
	if id == "pick" then
		local tree = Orchard.nearestRipe()
		return tree and tree:FindFirstChild("Canopy") :: BasePart?
	end
	local plate = workspace.Board.Plates:FindFirstChild(id)
	return plate and plate:FindFirstChild("Plate") :: BasePart?
end

local function refresh(snapshot: { [string]: any })
	step = math.max(step, snapshot.tutorial or 1)
	while Config.Tutorial[step] and DONE[Config.Tutorial[step].id](snapshot) do
		step += 1
		remotes.TutorialStep:FireServer(step)
	end
	local entry = Config.Tutorial[step]
	Hud.setGuide(if entry then lineFor(entry) else nil)
	if not entry then
		arrow.Parent = nil
	end
end

local function keeperLine(zoneId: string)
	local line = (Config.Dialogue :: any)[zoneId]
	if not line then
		return
	end
	Hud.say(Config.Npc.keeperName, line)
	local npcs = workspace:FindFirstChild("Npcs")
	local keeper = npcs and npcs:FindFirstChild(Config.Npc.keeperName)
	local head = keeper and keeper:FindFirstChild("Head")
	if head then
		pcall(function()
			TextChatService:DisplayBubble(head, line)
		end)
	end
end

function Guide.init(remoteFolder: Folder)
	remotes = remoteFolder
	arrow = buildArrow()
	Orchard.onPick(function()
		picked = true
		if State.current then
			refresh(State.current)
		end
	end)
	State.onChange(refresh)
	remotes.KeeperLine.OnClientEvent:Connect(keeperLine)

	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local entry = Config.Tutorial[step]
		local target = entry and targetFor(entry.id)
		if not target then
			arrow.Parent = nil
			return
		end
		arrow.Parent = workspace
		local bob = if State.reduceMotion() then 0 else math.sin(t * 4) * 0.6
		local top = target.Position + Vector3.new(0, target.Size.Y / 2 + 3.5 + bob, 0)
		arrow:PivotTo(CFrame.new(top) * CFrame.Angles(0, t * 1.5, 0))
	end)
end

return Guide
