--!nonstrict
-- The reward moment. Scales with how rare the catch actually was, so a Common
-- is a small plink and a Secret takes over the screen.

local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CatchFx = {}

local BASE_FOV = 70

local flash: ColorCorrectionEffect? = nil
local fovTween: Tween? = nil

local function ensureFlash(): ColorCorrectionEffect
	if flash and flash.Parent then
		return flash
	end

	-- Its own effect, so the zone's colour grading tween never fights it.
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "CatchFlash"
	effect.Brightness = 0
	effect.Contrast = 0
	effect.Saturation = 0
	effect.TintColor = Color3.new(1, 1, 1)
	effect.Parent = Lighting

	flash = effect
	return effect
end

local function burst(position: Vector3, color: Color3, power: number)
	local host = Instance.new("Part")
	host.Size = Vector3.new(1, 1, 1)
	host.Transparency = 1
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CanTouch = false
	host.Position = position
	host.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Lifetime = NumberRange.new(0.5, 1.2 + power)
	emitter.Speed = NumberRange.new(9 + 16 * power, 22 + 40 * power)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -34, 0)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Drag = 2.4
	emitter.RotSpeed = NumberRange.new(-220, 220)
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.35, color),
		ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.4)),
	})
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3 + 0.9 * power),
		NumberSequenceKeypoint.new(0.6, 0.2 + 0.5 * power),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = host

	emitter:Emit(math.floor(30 + 150 * power))

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 4 + 14 * power
	light.Range = 26 + 50 * power
	light.Parent = host

	TweenService:Create(light, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	Debris:AddItem(host, 2.6 + power)
end

-- A shaft of light for anything genuinely rare.
local function pillar(position: Vector3, color: Color3, power: number)
	local shaft = Instance.new("Part")
	shaft.Name = "CatchPillar"
	shaft.Shape = Enum.PartType.Cylinder
	shaft.Size = Vector3.new(0.4, 3, 3)
	shaft.CFrame = CFrame.new(position + Vector3.new(0, 90, 0)) * CFrame.Angles(0, 0, math.rad(90))
	shaft.Anchored = true
	shaft.CanCollide = false
	shaft.CanQuery = false
	shaft.CanTouch = false
	shaft.Color = color
	shaft.Material = Enum.Material.Neon
	shaft.Transparency = 0.25
	shaft.Parent = Workspace

	TweenService:Create(shaft, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = Vector3.new(190, 8 + 18 * power, 8 + 18 * power),
	}):Play()

	task.delay(0.3, function()
		if shaft.Parent then
			TweenService:Create(shaft, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
				Transparency = 1,
				Size = Vector3.new(190, 1, 1),
			}):Play()
		end
	end)

	Debris:AddItem(shaft, 2)
end

local function punch(camera: Camera, power: number)
	if fovTween then
		fovTween:Cancel()
	end

	-- FOV only. Nudging Camera.CFrame would fight the default camera scripts
	-- and read as jitter rather than impact.
	camera.FieldOfView = BASE_FOV - 9 * power

	fovTween = TweenService:Create(
		camera,
		TweenInfo.new(0.55 + power * 0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ FieldOfView = BASE_FOV }
	)
	fovTween:Play()
end

local function grade(color: Color3, power: number)
	local effect = ensureFlash()

	effect.TintColor = color:Lerp(Color3.new(1, 1, 1), 0.45)
	effect.Brightness = 0.06 + 0.16 * power
	effect.Contrast = 0.1 * power
	effect.Saturation = 0.2 * power

	TweenService:Create(effect, TweenInfo.new(0.7 + power * 0.6, Enum.EasingStyle.Quad), {
		Brightness = 0,
		Contrast = 0,
		Saturation = 0,
		TintColor = Color3.new(1, 1, 1),
	}):Play()
end

-- rarityIndex / mutationIndex are 1-based positions in their config Order.
function CatchFx.Play(position: Vector3, color: Color3, rarityIndex: number, mutationIndex: number)
	-- Take whichever ladder the catch scored higher on, so a Glitched Minnow
	-- gets the fireworks its odds deserve.
	local tier = math.max(rarityIndex or 1, mutationIndex or 1)
	local power = math.clamp((tier - 1) / 7, 0, 1)

	burst(position, color, power)

	if tier >= 5 then
		pillar(position, color, power)
	end

	local camera = Workspace.CurrentCamera
	if camera then
		punch(camera, power)
	end

	if power > 0 then
		grade(color, power)
	end
end

function CatchFx.Reset()
	local camera = Workspace.CurrentCamera
	if camera then
		if fovTween then
			fovTween:Cancel()
			fovTween = nil
		end
		camera.FieldOfView = BASE_FOV
	end
end

return CatchFx
