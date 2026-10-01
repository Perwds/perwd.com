--!nonstrict
-- Procedural fish. Every species is built from primitives at runtime from its
-- own colour and silhouette archetype, so 55 recognisable fish cost no uploaded
-- meshes and no artist time.
--
-- Models are built around the origin facing +Z, nose forward, with the body as
-- PrimaryPart. Parts are unanchored, massless and welded to the body, so the
-- caller can weld the model to a character or drop it in a ViewportFrame
-- without either case needing special handling.

local Fish = require(script.Parent.Config.Fish)
local Mutations = require(script.Parent.Config.Mutations)

local FishModel = {}

-- Each model is roughly 8-14 parts. The index panel renders one ViewportFrame
-- per discovered species, so this budget is what keeps that screen affordable.
FishModel.MaxParts = 18

-- Appearance -------------------------------------------------------------------

-- Mutations repaint the whole fish rather than tinting it, so a Golden Carp
-- reads as gold metal and a Void Eel reads as something that should not exist.
local TREATMENTS = {
	None = { material = Enum.Material.SmoothPlastic, reflectance = 0.04 },
	Shiny = { material = Enum.Material.Glass, reflectance = 0.42, lighten = 0.18 },
	Albino = { toward = Color3.fromRGB(248, 246, 250), blend = 0.86, material = Enum.Material.SmoothPlastic, reflectance = 0.06 },
	Golden = { toward = Color3.fromRGB(255, 190, 40), blend = 0.92, material = Enum.Material.Metal, reflectance = 0.45 },
	Radioactive = { toward = Color3.fromRGB(140, 255, 70), blend = 0.64, material = Enum.Material.Neon, glow = true },
	Void = { toward = Color3.fromRGB(44, 18, 78), blend = 0.8, material = Enum.Material.Neon, glow = true, accent = Color3.fromRGB(150, 90, 255) },
	Celestial = { toward = Color3.fromRGB(150, 230, 255), blend = 0.7, material = Enum.Material.Neon, glow = true, accent = Color3.fromRGB(240, 250, 255) },
	Glitched = { toward = Color3.fromRGB(255, 60, 220), blend = 0.95, material = Enum.Material.Neon, glow = true, accent = Color3.fromRGB(90, 255, 230) },
}

function FishModel.Palette(record, mutation: string)
	local treatment = TREATMENTS[mutation] or TREATMENTS.None
	local body = record.color

	if treatment.toward then
		body = body:Lerp(treatment.toward, treatment.blend)
	end
	if treatment.lighten then
		body = body:Lerp(Color3.new(1, 1, 1), treatment.lighten)
	end

	return {
		body = body,
		fin = treatment.accent or body:Lerp(Color3.new(0, 0, 0), 0.26),
		belly = body:Lerp(Color3.new(1, 1, 1), 0.34),
		accent = treatment.accent or body:Lerp(Color3.new(1, 1, 1), 0.5),
		material = treatment.material,
		reflectance = treatment.reflectance or 0,
		glow = treatment.glow and (treatment.accent or body) or nil,
	}
end

-- Size -------------------------------------------------------------------------

-- Catch weights span six orders of magnitude (a 50g Minnow to a 40-tonne God of
-- Still Water), so display length is log-mapped: true scale would make every
-- small fish an invisible speck next to the big ones. Weight within a species
-- then nudges it, which is what makes a near-max catch look like one.
function FishModel.DisplayLength(record, weight: number): number
	local median = math.sqrt(math.max(record.minWeight, 1e-4) * math.max(record.maxWeight, 1e-4))
	local t = math.clamp((math.log10(median) + 3) / 7.6, 0, 1)
	local base = 0.9 + (t ^ 1.6) * 7.1

	local span = math.max(record.maxWeight - record.minWeight, 1e-6)
	local within = math.clamp((weight - record.minWeight) / span, 0, 1)

	return base * (0.84 + within * 0.32)
end

-- Geometry ----------------------------------------------------------------------

local function piece(ctx, props): Part
	local part = Instance.new("Part")
	part.Name = props.name or "Piece"
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color or ctx.palette.body
	part.Material = props.material or ctx.palette.material
	part.Reflectance = props.reflectance or ctx.palette.reflectance
	part.Transparency = props.transparency or 0
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.shape then
		part.Shape = props.shape
	end
	part.Parent = ctx.model

	if ctx.body and part ~= ctx.body then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = ctx.body
		weld.Part1 = part
		weld.Parent = part
	end

	return part
end

local BALL = Enum.PartType.Ball
local WEDGE = Enum.PartType.Wedge
local CYLINDER = Enum.PartType.Cylinder

local function eyes(ctx, forward: number, spread: number, height: number, scale: number)
	for _, side in { -1, 1 } do
		piece(ctx, {
			name = "Eye",
			size = Vector3.new(1, 1, 1) * ctx.length * 0.07 * scale,
			cframe = CFrame.new(side * ctx.length * spread, ctx.length * height, ctx.length * forward),
			color = Color3.fromRGB(248, 250, 255),
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.2,
			shape = BALL,
		})
		piece(ctx, {
			name = "Pupil",
			size = Vector3.new(1, 1, 1) * ctx.length * 0.036 * scale,
			cframe = CFrame.new(side * ctx.length * (spread + 0.018), ctx.length * height, ctx.length * (forward + 0.02)),
			color = Color3.fromRGB(16, 16, 22),
			material = Enum.Material.SmoothPlastic,
			shape = BALL,
		})
	end
end

-- A forked tail: two wedges mirrored around the spine.
local function forkedTail(ctx, at: number, size: number)
	for _, side in { -1, 1 } do
		piece(ctx, {
			name = "Tail",
			size = Vector3.new(ctx.length * 0.03, ctx.length * size, ctx.length * size * 0.9),
			cframe = CFrame.new(0, ctx.length * size * 0.42 * side, ctx.length * at)
				* CFrame.Angles(math.rad(side * 26), 0, 0),
			color = ctx.palette.fin,
			shape = WEDGE,
		})
	end
end

local function dorsal(ctx, at: number, size: number)
	piece(ctx, {
		name = "Dorsal",
		size = Vector3.new(ctx.length * 0.028, ctx.length * size, ctx.length * size * 1.5),
		cframe = CFrame.new(0, ctx.length * (size * 0.5 + 0.12), ctx.length * at)
			* CFrame.Angles(0, 0, 0),
		color = ctx.palette.fin,
		shape = WEDGE,
	})
end

local function pectorals(ctx, at: number, size: number)
	for _, side in { -1, 1 } do
		piece(ctx, {
			name = "Fin",
			size = Vector3.new(ctx.length * 0.022, ctx.length * size, ctx.length * size * 1.2),
			cframe = CFrame.new(side * ctx.length * 0.09, -ctx.length * 0.02, ctx.length * at)
				* CFrame.Angles(0, 0, math.rad(side * 58)),
			color = ctx.palette.fin,
			shape = WEDGE,
		})
	end
end

local SHAPES = {}

-- Standard fish: a tapered body, forked tail, dorsal and pectoral fins.
function SHAPES.round(ctx)
	local L = ctx.length
	ctx.body = piece(ctx, {
		name = "Body",
		size = Vector3.new(L * 0.26, L * 0.4, L * 0.62),
		cframe = CFrame.new(0, 0, 0),
		shape = BALL,
	})
	piece(ctx, {
		name = "Head",
		size = Vector3.new(L * 0.2, L * 0.28, L * 0.3),
		cframe = CFrame.new(0, -L * 0.01, L * 0.33),
		shape = BALL,
	})
	piece(ctx, {
		name = "Belly",
		size = Vector3.new(L * 0.2, L * 0.16, L * 0.44),
		cframe = CFrame.new(0, -L * 0.14, L * 0.02),
		color = ctx.palette.belly,
		shape = BALL,
	})
	forkedTail(ctx, -0.42, 0.24)
	dorsal(ctx, 0.02, 0.17)
	pectorals(ctx, 0.14, 0.14)
	eyes(ctx, 0.4, 0.07, 0.06, 1)
end

-- Eels, pikes, serpents: a tapering segmented spine with a gentle S-curve.
function SHAPES.long(ctx)
	local L = ctx.length
	local segments = 7

	ctx.body = piece(ctx, {
		name = "Body",
		size = Vector3.new(L * 0.17, L * 0.19, L * 0.2),
		cframe = CFrame.new(0, 0, L * 0.26),
		shape = BALL,
	})

	for index = 1, segments do
		local t = index / segments
		local taper = 1 - t * 0.78
		piece(ctx, {
			name = "Segment" .. index,
			size = Vector3.new(L * 0.16 * taper, L * 0.18 * taper, L * 0.2),
			cframe = CFrame.new(
				math.sin(t * 4.2) * L * 0.045,
				math.sin(t * 3.1) * L * 0.03,
				L * (0.26 - t * 0.78)
			),
			shape = BALL,
		})
	end

	piece(ctx, {
		name = "Snout",
		size = Vector3.new(L * 0.12, L * 0.11, L * 0.18),
		cframe = CFrame.new(0, -L * 0.01, L * 0.42),
		shape = BALL,
	})
	forkedTail(ctx, -0.56, 0.15)
	eyes(ctx, 0.37, 0.055, 0.045, 0.85)
end

-- Rays and anything that swims like a flag: a flat disc with two wings.
function SHAPES.flat(ctx)
	local L = ctx.length
	ctx.body = piece(ctx, {
		name = "Body",
		size = Vector3.new(L * 0.4, L * 0.12, L * 0.5),
		cframe = CFrame.new(0, 0, 0),
		shape = BALL,
	})

	for _, side in { -1, 1 } do
		piece(ctx, {
			name = "Wing",
			size = Vector3.new(L * 0.04, L * 0.42, L * 0.5),
			cframe = CFrame.new(side * L * 0.3, L * 0.02, -L * 0.02)
				* CFrame.Angles(0, 0, math.rad(side * 76)),
			color = ctx.palette.body,
			shape = WEDGE,
		})
	end

	piece(ctx, {
		name = "Tail",
		size = Vector3.new(L * 0.04, L * 0.04, L * 0.6),
		cframe = CFrame.new(0, L * 0.02, -L * 0.48),
		color = ctx.palette.fin,
		shape = CYLINDER,
	})
	piece(ctx, {
		name = "Snout",
		size = Vector3.new(L * 0.16, L * 0.08, L * 0.18),
		cframe = CFrame.new(0, 0, L * 0.26),
		shape = BALL,
	})
	eyes(ctx, 0.2, 0.07, 0.05, 0.9)
end

-- Deep-sea heads: mostly jaw, with a lure that actually glows.
function SHAPES.bulb(ctx)
	local L = ctx.length
	ctx.body = piece(ctx, {
		name = "Body",
		size = Vector3.new(L * 0.42, L * 0.44, L * 0.46),
		cframe = CFrame.new(0, 0, L * 0.12),
		shape = BALL,
	})
	piece(ctx, {
		name = "Rear",
		size = Vector3.new(L * 0.22, L * 0.24, L * 0.34),
		cframe = CFrame.new(0, -L * 0.02, -L * 0.22),
		shape = BALL,
	})
	piece(ctx, {
		name = "Jaw",
		size = Vector3.new(L * 0.34, L * 0.1, L * 0.26),
		cframe = CFrame.new(0, -L * 0.17, L * 0.24) * CFrame.Angles(math.rad(-12), 0, 0),
		color = ctx.palette.belly,
	})

	-- Teeth, which is most of why these read as frightening.
	for index = -2, 2 do
		piece(ctx, {
			name = "Tooth",
			size = Vector3.new(L * 0.018, L * 0.07, L * 0.018),
			cframe = CFrame.new(index * L * 0.055, -L * 0.1, L * 0.33),
			color = Color3.fromRGB(242, 240, 230),
			material = Enum.Material.SmoothPlastic,
		})
	end

	piece(ctx, {
		name = "LureStalk",
		size = Vector3.new(L * 0.02, L * 0.3, L * 0.02),
		cframe = CFrame.new(0, L * 0.34, L * 0.16) * CFrame.Angles(math.rad(26), 0, 0),
		color = ctx.palette.fin,
	})
	local lure = piece(ctx, {
		name = "Lure",
		size = Vector3.new(1, 1, 1) * L * 0.1,
		cframe = CFrame.new(0, L * 0.48, L * 0.28),
		color = ctx.palette.accent,
		material = Enum.Material.Neon,
		shape = BALL,
	})

	local light = Instance.new("PointLight")
	light.Color = ctx.palette.accent
	light.Brightness = 2.6
	light.Range = ctx.length * 2.4
	light.Parent = lure

	forkedTail(ctx, -0.44, 0.2)
	eyes(ctx, 0.3, 0.13, 0.12, 1.3)
end

-- Coins, roe, cores, eyes: not fish at all, so they get a ring instead of fins.
function SHAPES.orb(ctx)
	local L = ctx.length
	ctx.body = piece(ctx, {
		name = "Body",
		size = Vector3.new(1, 1, 1) * L * 0.46,
		cframe = CFrame.new(0, 0, 0),
		shape = BALL,
	})
	piece(ctx, {
		name = "Ring",
		size = Vector3.new(L * 0.04, L * 0.66, L * 0.66),
		cframe = CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(18), 0),
		color = ctx.palette.accent,
		material = Enum.Material.Neon,
		transparency = 0.25,
		shape = CYLINDER,
	})
	piece(ctx, {
		name = "Core",
		size = Vector3.new(1, 1, 1) * L * 0.2,
		cframe = CFrame.new(0, 0, L * 0.16),
		color = ctx.palette.accent,
		material = Enum.Material.Neon,
		shape = BALL,
	})
end

-- Crabs: a flat shell on legs, with claws out front.
function SHAPES.crab(ctx)
	local L = ctx.length
	ctx.body = piece(ctx, {
		name = "Body",
		size = Vector3.new(L * 0.46, L * 0.2, L * 0.36),
		cframe = CFrame.new(0, 0, 0),
		shape = BALL,
	})

	for index = 0, 2 do
		for _, side in { -1, 1 } do
			piece(ctx, {
				name = "Leg",
				size = Vector3.new(L * 0.04, L * 0.04, L * 0.3),
				cframe = CFrame.new(side * L * 0.22, -L * 0.08, (index - 1) * L * 0.14)
					* CFrame.Angles(0, math.rad(side * 70), math.rad(side * 24)),
				color = ctx.palette.fin,
			})
		end
	end

	for _, side in { -1, 1 } do
		piece(ctx, {
			name = "Claw",
			size = Vector3.new(L * 0.1, L * 0.1, L * 0.2),
			cframe = CFrame.new(side * L * 0.2, -L * 0.02, L * 0.28)
				* CFrame.Angles(0, math.rad(side * -24), 0),
			color = ctx.palette.accent,
		})
	end

	eyes(ctx, 0.14, 0.08, 0.11, 0.9)
end

-- Squid and kraken: a mantle with tentacles trailing behind.
function SHAPES.squid(ctx)
	local L = ctx.length
	ctx.body = piece(ctx, {
		name = "Body",
		size = Vector3.new(L * 0.28, L * 0.3, L * 0.5),
		cframe = CFrame.new(0, 0, L * 0.16),
		shape = BALL,
	})
	piece(ctx, {
		name = "Mantle",
		size = Vector3.new(L * 0.16, L * 0.18, L * 0.3),
		cframe = CFrame.new(0, 0, L * 0.44),
		shape = BALL,
	})

	for index = 1, 8 do
		local angle = (index / 8) * math.pi * 2
		piece(ctx, {
			name = "Tentacle" .. index,
			size = Vector3.new(L * 0.045, L * 0.045, L * 0.44),
			cframe = CFrame.new(
				math.cos(angle) * L * 0.09,
				math.sin(angle) * L * 0.09,
				-L * 0.3
			) * CFrame.Angles(math.rad(math.sin(angle) * 20), math.rad(math.cos(angle) * 20), 0),
			color = ctx.palette.fin,
			shape = CYLINDER,
		})
	end

	eyes(ctx, 0.3, 0.14, 0.02, 1.5)
end

-- Seahorses: an upright curled spine with a snout.
function SHAPES.seahorse(ctx)
	local L = ctx.length
	ctx.body = piece(ctx, {
		name = "Body",
		size = Vector3.new(L * 0.18, L * 0.26, L * 0.2),
		cframe = CFrame.new(0, L * 0.1, 0),
		shape = BALL,
	})

	for index = 1, 5 do
		local t = index / 5
		piece(ctx, {
			name = "Coil" .. index,
			size = Vector3.new(L * 0.15 * (1 - t * 0.55), L * 0.15 * (1 - t * 0.5), L * 0.16),
			cframe = CFrame.new(0, L * (0.02 - t * 0.2), L * math.sin(t * 2.6) * 0.14),
			shape = BALL,
		})
	end

	piece(ctx, {
		name = "Head",
		size = Vector3.new(L * 0.14, L * 0.16, L * 0.18),
		cframe = CFrame.new(0, L * 0.3, L * 0.02),
		shape = BALL,
	})
	piece(ctx, {
		name = "Snout",
		size = Vector3.new(L * 0.07, L * 0.07, L * 0.22),
		cframe = CFrame.new(0, L * 0.28, L * 0.16),
		color = ctx.palette.belly,
		shape = CYLINDER,
	})
	piece(ctx, {
		name = "Crest",
		size = Vector3.new(L * 0.02, L * 0.14, L * 0.16),
		cframe = CFrame.new(0, L * 0.4, -L * 0.04),
		color = ctx.palette.fin,
		shape = WEDGE,
	})
	eyes(ctx, 0.08, 0.06, 0.32, 0.8)
end

FishModel.Shapes = SHAPES

-- Build -------------------------------------------------------------------------

function FishModel.Build(fishId: string, mutation: string, weight: number): Model
	local record = Fish.Get(fishId)
	Mutations.Get(mutation) -- validates the mutation name

	local builder = SHAPES[record.shape]
	assert(builder, string.format("no builder for shape %q", tostring(record.shape)))

	local model = Instance.new("Model")
	model.Name = record.id

	local ctx = {
		model = model,
		length = FishModel.DisplayLength(record, weight),
		palette = FishModel.Palette(record, mutation),
		body = nil,
	}

	builder(ctx)

	model.PrimaryPart = ctx.body
	model:SetAttribute("FishId", record.id)
	model:SetAttribute("Mutation", mutation)

	-- A glowing mutation lights the whole fish, not just a lure.
	if ctx.palette.glow and ctx.body then
		local light = Instance.new("PointLight")
		light.Name = "MutationGlow"
		light.Color = ctx.palette.glow
		light.Brightness = 3
		light.Range = ctx.length * 3.5
		light.Parent = ctx.body
	end

	return model
end

return FishModel
