--[[
	Renders a pet into a ViewportFrame.

	Undiscovered pets are drawn as a flat black silhouette of the real model
	on the rarity colour, which is exactly what the index tiles show before
	you find one -- the shape is a hint, the identity is not.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelFactory = require(ReplicatedStorage.Shared.Util.ModelFactory)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)

local Builder = require(script.Parent.Builder)

local PetViewport = {}

local cache: { [string]: Model } = {}

local function template(petId: string): Model?
	if cache[petId] then
		return cache[petId]
	end
	local model = ModelFactory.buildPet(petId)
	if model then
		ModelFactory.configure(model, true)
		cache[petId] = model
	end
	return model
end

--- Flattens a model to pure black with no lights or particles.
local function silhouette(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Color = Color3.new(0, 0, 0)
			descendant.Material = Enum.Material.SmoothPlastic
			descendant.Reflectance = 0
		elseif descendant:IsA("Light") or descendant:IsA("ParticleEmitter") then
			descendant:Destroy()
		end
	end
end

--[[
	Builds a viewport showing `petId`. Pass known = false for the silhouette.
	Returns the ViewportFrame so the caller can parent and position it.
]]
function PetViewport.create(petId: string, known: boolean, props: { [string]: any }?): ViewportFrame
	local viewport = Builder.make(
		"ViewportFrame",
		Builder.merge({
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Ambient = known and Color3.fromRGB(190, 190, 200) or Color3.new(0, 0, 0),
			LightColor = known and Color3.fromRGB(255, 255, 255) or Color3.new(0, 0, 0),
			LightDirection = Vector3.new(-0.4, -1, -0.6),
		}, props)
	)

	local source = template(petId)
	if not source then
		return viewport
	end

	local model = source:Clone()
	if not known then
		silhouette(model)
	end
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Frame the whole model, whatever its proportions.
	local cf, size = model:GetBoundingBox()
	local extent = math.max(size.X, size.Y, size.Z)
	local distance = extent * 2.1 + 2

	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(distance * 0.55, distance * 0.42, -distance), cf.Position)

	return viewport
end

--- A rarity-tinted tile with the pet inside. Used by the index and the shop.
function PetViewport.tile(petId: string, rarityName: string, known: boolean, props: { [string]: any }?)
	local info = Rarity.get(rarityName)

	local tile = Builder.frame(
		Builder.merge({
			BackgroundColor3 = info.color,
			Size = UDim2.fromOffset(96, 96),
		}, props),
		{
			Builder.gradient(info.glow, info.color, 90),
		}
	)

	PetViewport.create(petId, known, { Parent = tile, ZIndex = 2 })

	local caption = Builder.label(known and "" or "???", {
		Name = "Caption",
		Size = UDim2.new(1, -8, 0, 22),
		Position = UDim2.fromOffset(4, 2),
		ZIndex = 3,
		Parent = tile,
	})

	return tile, caption
end

return PetViewport
