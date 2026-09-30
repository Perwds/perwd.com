--[[
	Builds placeholder egg and pet models in code.

	The point is that the game is fully playable before any art exists. Every
	pet and egg gets a distinct, rarity-tinted blockout. When you set `modelId`
	on a pet in Pets.luau, that asset is cloned instead and the blockout is
	skipped entirely -- no other code changes.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)

local ModelFactory = {}

local assetCache: { [number]: Model } = {}

local function newPart(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Anchored = true
	part.Parent = parent
	return part
end

local function weldTo(root: BasePart, part: Part, offset: CFrame)
	part.Anchored = false
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

--[[
	A pet blockout: body, head, two ears, four stubby legs, a tail. Proportions
	shift with rarity rank so a Mythic reads as bigger and chunkier than a
	Common at a glance, the way the silhouettes in the index do.
]]
function ModelFactory.buildPet(petId: string): Model?
	local pet = Pets.get(petId)
	if not pet then
		return nil
	end

	if pet.modelId and pet.modelId ~= 0 then
		local cached = assetCache[pet.modelId]
		if cached then
			return cached:Clone()
		end
		local ok, asset = pcall(function()
			return InsertService:LoadAsset(pet.modelId)
		end)
		if ok and asset then
			local model = asset:FindFirstChildWhichIsA("Model")
			if model then
				model.Parent = nil
				assetCache[pet.modelId] = model
				asset:Destroy()
				return model:Clone()
			end
		end
		warn(`[ModelFactory] could not load modelId {pet.modelId} for {petId}; using blockout`)
	end

	local rank = Rarity.Rank[pet.rarity] or 1
	local scale = 0.85 + rank * 0.07
	local body = pet.color
	local shade = body:Lerp(Color3.new(0, 0, 0), 0.25)
	local light = body:Lerp(Color3.new(1, 1, 1), 0.35)

	local model = Instance.new("Model")
	model.Name = pet.id

	local torso = newPart("Torso", Vector3.new(1.6, 1.2, 2.2) * scale, body, model)
	model.PrimaryPart = torso

	local head = newPart("Head", Vector3.new(1.3, 1.2, 1.2) * scale, light, model)
	weldTo(torso, head, CFrame.new(0, 0.75 * scale, -1.3 * scale))

	for _, side in { -1, 1 } do
		local ear = newPart("Ear", Vector3.new(0.3, 0.7, 0.25) * scale, shade, model)
		weldTo(torso, ear, CFrame.new(side * 0.42 * scale, 1.5 * scale, -1.35 * scale))

		local eye = newPart("Eye", Vector3.new(0.22, 0.22, 0.12) * scale, Color3.new(0.05, 0.05, 0.07), model)
		weldTo(torso, eye, CFrame.new(side * 0.33 * scale, 0.9 * scale, -1.92 * scale))
	end

	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local leg = newPart("Leg", Vector3.new(0.38, 0.75, 0.38) * scale, shade, model)
			weldTo(torso, leg, CFrame.new(x * 0.52 * scale, -0.95 * scale, z * 0.72 * scale))
		end
	end

	local tail = newPart("Tail", Vector3.new(0.35, 0.35, 0.9) * scale, light, model)
	weldTo(torso, tail, CFrame.new(0, 0.2 * scale, 1.45 * scale))

	-- Rarity glow. Reads clearly even on the dark Secret tint.
	local info = Rarity.get(pet.rarity)
	if rank >= 3 then
		local light2 = Instance.new("PointLight")
		light2.Color = info.glow
		light2.Brightness = 0.6 + rank * 0.25
		light2.Range = 4 + rank
		light2.Parent = torso
	end

	if rank >= 5 then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(info.glow)
		sparkle.Size = NumberSequence.new(0.25, 0)
		sparkle.Lifetime = NumberRange.new(0.5, 0.9)
		sparkle.Rate = 8 + rank * 3
		sparkle.Speed = NumberRange.new(0.4, 1.2)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.LightEmission = 0.8
		sparkle.Parent = torso
	end

	torso.Anchored = false
	return model
end

--[[
	An egg blockout: a stacked ovoid with a rarity band and a crack decal
	that widens as the hatch timer runs down.
]]
function ModelFactory.buildEgg(rarityName: string, tint: Color3?): Model
	local info = Rarity.get(rarityName)
	local base = tint or info.color

	local model = Instance.new("Model")
	model.Name = "Egg"

	local shell = Instance.new("Part")
	shell.Name = "Shell"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(2.6, 3.2, 2.6)
	shell.Color = base
	shell.Material = Enum.Material.SmoothPlastic
	shell.TopSurface = Enum.SurfaceType.Smooth
	shell.BottomSurface = Enum.SurfaceType.Smooth
	shell.CanCollide = false
	shell.Anchored = true
	shell.Parent = model
	model.PrimaryPart = shell

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 1.28, 1)
	mesh.Parent = shell

	local band = newPart("Band", Vector3.new(2.72, 0.5, 2.72), info.glow, model)
	local bandMesh = Instance.new("SpecialMesh")
	bandMesh.MeshType = Enum.MeshType.Sphere
	bandMesh.Scale = Vector3.new(1.02, 0.16, 1.02)
	bandMesh.Parent = band
	weldTo(shell, band, CFrame.new(0, -0.2, 0))

	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = info.glow
	glow.Brightness = 1.2
	glow.Range = 7
	glow.Parent = shell

	shell.Anchored = false
	return model
end

--- Puts a whole model into one CollisionGroup and (un)anchors it in one pass.
function ModelFactory.configure(model: Model, anchored: boolean, collisionGroup: string?)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			if collisionGroup then
				descendant.CollisionGroup = collisionGroup
			end
		end
	end
	if model.PrimaryPart then
		model.PrimaryPart.Anchored = anchored
	end
end

--- Scales a model about its PrimaryPart. Used for index viewports and pickups.
function ModelFactory.scale(model: Model, factor: number)
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	local origin = primary.CFrame

	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local offset = origin:ToObjectSpace(descendant.CFrame)
			descendant.Size *= factor
			descendant.CFrame = origin * CFrame.new(offset.Position * factor) * (offset - offset.Position)
		elseif descendant:IsA("SpecialMesh") then
			-- Mesh scale is already relative to part size, leave it alone.
		end
	end
end

if RunService:IsStudio() then
	ModelFactory._debugRarityOf = function(model: Model)
		return model:GetAttribute("Rarity")
	end
end

return ModelFactory
