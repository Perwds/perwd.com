--!strict
-- Feedback for a pick: the orange arcs into the player's basket, a puff of peel bits, a pop,
-- and a "+3" that floats up and fades.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local State = require(script.Parent.State)
local Audio = require(script.Parent.Audio)

local PickFx = {}

local player = Players.LocalPlayer
local fxFolder: Folder

local function basketPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position + Vector3.new(0, 0.5, 0) else nil
end

function PickFx.arc(from: Vector3)
	local target = basketPosition()
	if not target then
		return
	end
	local orange = Instance.new("Part")
	orange.Shape = Enum.PartType.Ball
	orange.Size = Vector3.new(1, 1, 1)
	orange.Color = Palette.orange
	orange.Material = Enum.Material.SmoothPlastic
	orange.Anchored = true
	orange.CanCollide = false
	orange.CanQuery = false
	orange.CastShadow = false
	orange.Position = from
	orange.Parent = fxFolder

	local progress = Instance.new("NumberValue")
	local peak = math.max(from.Y, target.Y) + 3
	progress.Changed:Connect(function(t)
		local live = basketPosition() or target
		local flat = from:Lerp(live, t)
		local height = (1 - t) * (1 - t) * from.Y + 2 * (1 - t) * t * peak + t * t * live.Y
		orange.Position = Vector3.new(flat.X, height, flat.Z)
		orange.Size = Vector3.one * (1 - 0.5 * t)
	end)
	local tween = TweenService:Create(
		progress,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Value = 1 }
	)
	tween:Play()
	tween.Completed:Once(function()
		orange:Destroy()
		progress:Destroy()
	end)
end

function PickFx.burst(at: Vector3)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = at
	anchor.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Palette.orange, Palette.zones.zest.plate)
	emitter.Size = NumberSequence.new(0.5, 0)
	emitter.Lifetime = NumberRange.new(0.25, 0.4)
	emitter.Speed = NumberRange.new(6, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.LightEmission = 0.4
	emitter.Enabled = false
	emitter.Parent = anchor
	emitter:Emit(7)
	task.delay(0.5, function()
		anchor:Destroy()
	end)
end

function PickFx.popup(at: Vector3, text: string, color: Color3?)
	if State.reduceMotion() then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = at
	anchor.Parent = workspace.Terrain
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(140, 40)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Adornee = anchor
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Arcade
	label.TextSize = 30
	label.Text = text
	label.TextColor3 = color or Palette.zones.orange.bought
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Palette.dark
	label.Parent = billboard
	TweenService:Create(billboard, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
	task.delay(0.45, function()
		anchor:Destroy()
	end)
end

function PickFx.picked(from: Vector3)
	PickFx.arc(from)
	PickFx.burst(from)
	Audio.pop()
end

function PickFx.init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "PickFx"
	fxFolder.Parent = workspace
end

return PickFx
