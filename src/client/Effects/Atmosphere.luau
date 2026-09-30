--!nonstrict
-- Owns everything about how a zone looks: lighting, atmosphere, clouds, the
-- post-processing stack, Terrain water, and ambient particles.
--
-- All of it is created and written client-side. Lighting and Terrain property
-- writes are local to this client, which is what lets two players standing in
-- different zones each see their own world.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Visuals = require(Shared.Config.Visuals)

local Atmosphere = {}

local TRANSITION = TweenInfo.new(1.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
-- Water properties do not tween (they are not animatable on Terrain), so they
-- snap. Hidden behind the fade the travel teleport already causes.
local AMBIENT_VOLUME = Vector3.new(190, 110, 190)

local player = Players.LocalPlayer

local effects = {}
local ambientPart: Part? = nil
local ambientEmitter: ParticleEmitter? = nil
local currentZone = nil

-- Construction ------------------------------------------------------------------

local function ensure(className: string, name: string, parent: Instance): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function build()
	effects.atmosphere = ensure("Atmosphere", "ZoneAtmosphere", Lighting)
	effects.clouds = ensure("Clouds", "ZoneClouds", Workspace.Terrain)

	effects.bloom = ensure("BloomEffect", "ZoneBloom", Lighting)
	effects.sunRays = ensure("SunRaysEffect", "ZoneSunRays", Lighting)
	effects.correction = ensure("ColorCorrectionEffect", "ZoneCorrection", Lighting)
	effects.dof = ensure("DepthOfFieldEffect", "ZoneDof", Lighting)

	for _, effect in { effects.bloom, effects.sunRays, effects.correction, effects.dof } do
		effect.Enabled = true
	end

	-- Ambient particle volume, kept over the player's head.
	local part = Instance.new("Part")
	part.Name = "AmbientVolume"
	part.Size = AMBIENT_VOLUME
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Locked = true
	part.Parent = Workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = part

	ambientPart = part
	ambientEmitter = emitter
end

-- Ambient particles ---------------------------------------------------------------

local function applyAmbient(profile)
	local emitter = ambientEmitter
	if not emitter then
		return
	end

	local config = profile.ambient
	local style = Visuals.AmbientStyles[config.kind]

	if not style then
		emitter.Enabled = false
		return
	end

	emitter.Enabled = true
	emitter.Rate = config.rate
	emitter.Lifetime = style.lifetime
	emitter.Speed = style.speed
	emitter.Acceleration = style.acceleration
	emitter.LightEmission = style.lightEmission
	emitter.RotSpeed = style.spin
	emitter.Color = ColorSequence.new(config.color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.25, style.size),
		NumberSequenceKeypoint.new(0.8, style.size * 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, style.transparency),
		NumberSequenceKeypoint.new(0.75, style.transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- Application ---------------------------------------------------------------------

function Atmosphere.Apply(zoneId: string, instant: boolean?)
	if currentZone == zoneId then
		return
	end
	currentZone = zoneId

	local profile = Visuals.Get(zoneId)
	local info = instant and TweenInfo.new(0) or TRANSITION

	local function tween(instance: Instance, goal)
		TweenService:Create(instance, info, goal):Play()
	end

	tween(Lighting, {
		ClockTime = profile.lighting.clockTime,
		Brightness = profile.lighting.brightness,
		ExposureCompensation = profile.lighting.exposure,
		Ambient = profile.lighting.ambient,
		OutdoorAmbient = profile.lighting.outdoorAmbient,
		ShadowSoftness = profile.lighting.shadowSoftness,
	})

	tween(effects.atmosphere, {
		Density = profile.atmosphere.density,
		Offset = profile.atmosphere.offset,
		Color = profile.atmosphere.color,
		Decay = profile.atmosphere.decay,
		Glare = profile.atmosphere.glare,
		Haze = profile.atmosphere.haze,
	})

	tween(effects.clouds, {
		Cover = profile.clouds.cover,
		Density = profile.clouds.density,
		Color = profile.clouds.color,
	})

	tween(effects.bloom, {
		Intensity = profile.bloom.intensity,
		Size = profile.bloom.size,
		Threshold = profile.bloom.threshold,
	})

	tween(effects.sunRays, {
		Intensity = profile.sunRays.intensity,
		Spread = profile.sunRays.spread,
	})

	tween(effects.correction, {
		Brightness = profile.correction.brightness,
		Contrast = profile.correction.contrast,
		Saturation = profile.correction.saturation,
		TintColor = profile.correction.tint,
	})

	tween(effects.dof, {
		FarIntensity = profile.dof.far,
		FocusDistance = profile.dof.focus,
		InFocusRadius = profile.dof.radius,
		NearIntensity = profile.dof.near,
	})

	-- Terrain water. Not tweenable, so it snaps.
	local terrain = Workspace.Terrain
	terrain.WaterColor = profile.water.color
	terrain.WaterTransparency = profile.water.transparency
	terrain.WaterReflectance = profile.water.reflectance
	terrain.WaterWaveSize = profile.water.waveSize
	terrain.WaterWaveSpeed = profile.water.waveSpeed

	applyAmbient(profile)
end

function Atmosphere.Start()
	build()

	-- Keep the ambient volume over the player, and idle-rotate floating props.
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if ambientPart and root then
			ambientPart.Position = root.Position + Vector3.new(0, 34, 0)
		end

		local clock = os.clock()
		for _, prop in CollectionService:GetTagged("FloatingProp") do
			-- PivotTo, not PrimaryPart.CFrame: these props are several parts and
			-- moving only the primary would tear them apart.
			if prop.PrimaryPart then
				local seed = prop:GetAttribute("FloatSeed") or 0
				local origin = prop:GetAttribute("FloatOrigin")
				if not origin then
					origin = prop:GetPivot()
					prop:SetAttribute("FloatOrigin", origin)
				end

				prop:PivotTo(
					origin
						* CFrame.new(0, math.sin(clock * 0.6 + seed) * 1.8, 0)
						* CFrame.Angles(0, clock * 0.25 + seed, 0)
				)
			end
		end
	end)
end

return Atmosphere
