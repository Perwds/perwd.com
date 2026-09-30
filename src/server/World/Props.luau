--!nonstrict
-- Decorative geometry, built from primitives so the repo needs no uploaded
-- meshes. Each generator returns a Model so MapBuilder can place and forget.

local Props = {}

local function newPart(parent: Instance, props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.collide == true
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = props.size
	part.CFrame = props.cframe
	part.Color = props.color
	part.Material = props.material or Enum.Material.Plastic
	part.Transparency = props.transparency or 0
	part.Reflectance = props.reflectance or 0
	if props.shape then
		part.Shape = props.shape
	end
	part.Parent = parent
	return part
end

local function model(name: string, parent: Instance): Model
	local instance = Instance.new("Model")
	instance.Name = name
	instance.Parent = parent
	return instance
end

local function jitter(rng: Random, amount: number): number
	return rng:NextNumber(-amount, amount)
end

-- A trunk with a few canopy blobs. Reads as a tree at gameplay distance.
function Props.Tree(parent: Instance, base: CFrame, rng: Random, trunkColor: Color3, leafColor: Color3)
	local tree = model("Tree", parent)
	local height = rng:NextNumber(14, 24)

	newPart(tree, {
		size = Vector3.new(1.8, height, 1.8),
		cframe = base * CFrame.new(0, height / 2, 0) * CFrame.Angles(jitter(rng, 0.06), 0, jitter(rng, 0.06)),
		color = trunkColor,
		material = Enum.Material.Wood,
		collide = true,
	})

	for index = 1, 3 do
		local radius = rng:NextNumber(7, 11) * (1 - (index - 1) * 0.18)
		newPart(tree, {
			size = Vector3.new(radius, radius * 0.78, radius),
			cframe = base
				* CFrame.new(jitter(rng, 2.2), height - 2 + index * 3.1, jitter(rng, 2.2)),
			color = leafColor:Lerp(Color3.new(0, 0, 0), (index - 1) * 0.07),
			material = Enum.Material.Grass,
			shape = Enum.PartType.Ball,
		})
	end

	return tree
end

-- Stacked, tapering, slightly tilted blocks: ice spikes, obsidian, crystal.
function Props.Shard(parent: Instance, base: CFrame, rng: Random, color: Color3, material: Enum.Material, glow: boolean?)
	local shard = model("Shard", parent)
	local height = rng:NextNumber(10, 26)
	local width = height * rng:NextNumber(0.16, 0.3)
	local lean = CFrame.Angles(jitter(rng, 0.22), rng:NextNumber(0, math.pi * 2), jitter(rng, 0.22))

	local segments = 3
	local cursor = 0

	for index = 1, segments do
		local factor = 1 - (index - 1) / segments
		local segmentHeight = height / segments
		local part = newPart(shard, {
			size = Vector3.new(width * factor, segmentHeight, width * factor),
			cframe = base * lean * CFrame.new(0, cursor + segmentHeight / 2, 0),
			color = color:Lerp(Color3.new(1, 1, 1), (index - 1) * 0.12),
			material = material,
			transparency = material == Enum.Material.Ice and 0.35 or 0,
			reflectance = material == Enum.Material.Ice and 0.25 or 0,
			collide = index == 1,
		})
		cursor += segmentHeight * 0.92

		if glow and index == segments then
			local light = Instance.new("PointLight")
			light.Color = color
			light.Brightness = 2.4
			light.Range = 26
			light.Shadows = true
			light.Parent = part
		end
	end

	return shard
end

-- Overlapping squashed spheres. Cheap, reads as a boulder.
function Props.Rock(parent: Instance, base: CFrame, rng: Random, color: Color3, material: Enum.Material)
	local rock = model("Rock", parent)
	local scale = rng:NextNumber(4, 11)

	for index = 1, 3 do
		newPart(rock, {
			size = Vector3.new(scale, scale * rng:NextNumber(0.5, 0.8), scale) * (1 - (index - 1) * 0.22),
			cframe = base * CFrame.new(jitter(rng, scale * 0.3), jitter(rng, scale * 0.2), jitter(rng, scale * 0.3)),
			color = color:Lerp(Color3.new(0, 0, 0), jitter(rng, 0.08)),
			material = material,
			shape = Enum.PartType.Ball,
			collide = index == 1,
		})
	end

	return rock
end

-- A fan of thin blades. Coral, kelp, reeds.
function Props.Fan(parent: Instance, base: CFrame, rng: Random, color: Color3)
	local fan = model("Fan", parent)
	local blades = rng:NextInteger(4, 7)

	for index = 1, blades do
		local height = rng:NextNumber(4, 11)
		newPart(fan, {
			size = Vector3.new(rng:NextNumber(0.4, 1.4), height, 0.4),
			cframe = base
				* CFrame.Angles(0, (index / blades) * math.pi * 2, 0)
				* CFrame.new(rng:NextNumber(0.5, 2.4), height / 2, 0)
				* CFrame.Angles(jitter(rng, 0.3), 0, jitter(rng, 0.3)),
			color = color:Lerp(Color3.new(1, 1, 1), jitter(rng, 0.2)),
			material = Enum.Material.Neon,
			transparency = 0.15,
		})
	end

	return fan
end

-- Pier lantern. The PointLight is what sells the dark zones.
function Props.Lantern(parent: Instance, base: CFrame, color: Color3)
	local lantern = model("Lantern", parent)

	newPart(lantern, {
		size = Vector3.new(0.6, 9, 0.6),
		cframe = base * CFrame.new(0, 4.5, 0),
		color = Color3.fromRGB(62, 52, 44),
		material = Enum.Material.Metal,
		collide = true,
	})

	local bulb = newPart(lantern, {
		size = Vector3.new(1.7, 2.2, 1.7),
		cframe = base * CFrame.new(0, 9.6, 0),
		color = color,
		material = Enum.Material.Neon,
	})

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 3.2
	light.Range = 34
	light.Shadows = true
	light.Parent = bulb

	return lantern
end

-- Slow idle rotation for anything that should feel weightless.
function Props.Float(instance: Model, rng: Random)
	local primary = instance:FindFirstChildWhichIsA("BasePart")
	if not primary then
		return
	end

	instance.PrimaryPart = primary
	instance:SetAttribute("FloatSeed", rng:NextNumber(0, 100))
	instance:AddTag("FloatingProp")
end

return Props
