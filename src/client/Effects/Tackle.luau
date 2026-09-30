--!nonstrict
-- Bobber, fishing line and water impact. Purely cosmetic and entirely local.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Tackle = {}

local player = Players.LocalPlayer

local bobber: BasePart? = nil
local beam: Beam? = nil
local lineOrigin: Attachment? = nil
local render: RBXScriptConnection? = nil
local anchor = Vector3.zero
local tense = false
local startedAt = 0

local function rodTip(): Attachment?
	local character = player.Character
	if not character then
		return nil
	end

	local rod = character:FindFirstChild("FishingRod")
	local handle = rod and rod:FindFirstChild("Handle")
	local tip = handle and handle:FindFirstChild("Tip")
	if tip and tip:IsA("Attachment") then
		return tip
	end

	-- No rod equipped yet: hang the line off the right hand so the cast still
	-- reads instead of drawing from nowhere.
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if hand and hand:IsA("BasePart") then
		local fallback = hand:FindFirstChild("LineOrigin")
		if not fallback then
			fallback = Instance.new("Attachment")
			fallback.Name = "LineOrigin"
			fallback.Position = Vector3.new(0, -1, 0)
			fallback.Parent = hand
		end
		return fallback
	end

	return nil
end

-- A spreading, fading ring on the water. Cheap and sells the impact.
local function ripple(position: Vector3, color: Color3, scale: number)
	local ring = Instance.new("Part")
	ring.Name = "Ripple"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 2, 2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.35
	ring.Parent = Workspace

	TweenService:Create(ring, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 2 + 26 * scale, 2 + 26 * scale),
		Transparency = 1,
	}):Play()

	Debris:AddItem(ring, 1.3)
end

local function splash(position: Vector3, intensity: number)
	local emitterPart = Instance.new("Part")
	emitterPart.Size = Vector3.new(1, 1, 1)
	emitterPart.Transparency = 1
	emitterPart.Anchored = true
	emitterPart.CanCollide = false
	emitterPart.CanQuery = false
	emitterPart.CanTouch = false
	emitterPart.Position = position
	emitterPart.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(6 * intensity, 16 * intensity)
	emitter.SpreadAngle = Vector2.new(38, 38)
	emitter.Acceleration = Vector3.new(0, -62, 0)
	emitter.LightEmission = 0.6
	emitter.Color = ColorSequence.new(Workspace.Terrain.WaterColor:Lerp(Color3.new(1, 1, 1), 0.65))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5 * intensity),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = emitterPart

	emitter:Emit(math.floor(26 * intensity))
	Debris:AddItem(emitterPart, 1.6)

	ripple(position, Workspace.Terrain.WaterColor:Lerp(Color3.new(1, 1, 1), 0.5), intensity)
end

function Tackle.Cast(position: Vector3)
	Tackle.Clear()

	anchor = position
	tense = false
	startedAt = os.clock()

	local part = Instance.new("Part")
	part.Name = "Bobber"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.9, 0.9, 0.9)
	part.Color = Color3.fromRGB(255, 88, 88)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = position
	part.Parent = Workspace

	local glow = Instance.new("PointLight")
	glow.Color = part.Color
	glow.Brightness = 2
	glow.Range = 14
	glow.Parent = part

	local bobberAttachment = Instance.new("Attachment")
	bobberAttachment.Name = "LineEnd"
	bobberAttachment.Parent = part

	bobber = part
	splash(position, 1)

	local origin = rodTip()
	if origin then
		lineOrigin = origin

		local line = Instance.new("Beam")
		line.Name = "FishingLine"
		line.Attachment0 = origin
		line.Attachment1 = bobberAttachment
		line.Width0 = 0.05
		line.Width1 = 0.05
		line.FaceCamera = true
		line.LightInfluence = 1
		line.Color = ColorSequence.new(Color3.fromRGB(242, 246, 255))
		line.Transparency = NumberSequence.new(0.25)
		line.Segments = 14
		line.Parent = origin

		beam = line
	end

	render = RunService.RenderStepped:Connect(function()
		local current = bobber
		if not current then
			return
		end

		local elapsed = os.clock() - startedAt
		-- Idle bob, then a sharp twitch once something is on the line.
		local offset = tense
			and (math.sin(elapsed * 26) * 0.42 + math.sin(elapsed * 41) * 0.18)
			or math.sin(elapsed * 2.6) * 0.16

		current.Position = anchor + Vector3.new(
			tense and math.sin(elapsed * 17) * 0.25 or 0,
			offset,
			tense and math.cos(elapsed * 13) * 0.25 or 0
		)

		if beam then
			-- Line sags when slack, pulls straight when the fish fights.
			local sag = tense and -0.4 or -2.6
			beam.CurveSize0 = sag
			beam.CurveSize1 = sag
			beam.Width0 = tense and 0.09 or 0.05
			beam.Width1 = tense and 0.09 or 0.05
		end
	end)
end

function Tackle.SetTense(value: boolean)
	if tense == value then
		return
	end
	tense = value

	if value and bobber then
		splash(bobber.Position, 0.55)
	end
end

function Tackle.Landed(): Vector3
	return anchor
end

function Tackle.Clear(withSplash: boolean?)
	if render then
		render:Disconnect()
		render = nil
	end

	if withSplash and bobber then
		splash(bobber.Position, 0.8)
	end

	if beam then
		beam:Destroy()
		beam = nil
	end

	if lineOrigin then
		local stale = lineOrigin:FindFirstChild("FishingLine")
		if stale then
			stale:Destroy()
		end
		lineOrigin = nil
	end

	if bobber then
		bobber:Destroy()
		bobber = nil
	end

	tense = false
end

return Tackle
