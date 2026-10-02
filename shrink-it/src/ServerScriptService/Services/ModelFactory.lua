--[[
	📍 LOCATION: ServerScriptService > Services > ModelFactory (ModuleScript)
	(Helper module, not a service: Main does not boot it.)

	Creates object models:
	  1. ServerStorage > ShrinkableTemplates > <ObjectId> (your real model), or
	  2. a colored placeholder built from ObjectConfig Size / Color / Shape.
	Also applies variant glow (Highlight + light + sparkles) and name labels.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectConfig = require(Shared.Config.ObjectConfig)
local ObjectModels = require(Shared.ObjectModels)
local RarityConfig = require(Shared.Config.RarityConfig)

local ModelFactory = {}

function ModelFactory.TemplatesFolder()
	local folder = ServerStorage:FindFirstChild("ShrinkableTemplates")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ShrinkableTemplates"
		folder.Parent = ServerStorage
	end
	return folder
end

local function placeholder(id, def)
	local model = Instance.new("Model")
	model.Name = id
	local size = def.Size or Vector3.new(3, 3, 3)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Anchored = true
	body.Color = def.Color or Color3.fromRGB(200, 200, 200)
	body.Material = Enum.Material.SmoothPlastic
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	if def.Shape == "Ball" then
		body.Shape = Enum.PartType.Ball
		local d = math.max(size.X, size.Y, size.Z)
		body.Size = Vector3.new(d, d, d)
		body.CFrame = CFrame.new()
	elseif def.Shape == "Cylinder" then
		body.Shape = Enum.PartType.Cylinder
		-- Roblox cylinders run along X; stand it upright
		body.Size = Vector3.new(size.Y, math.max(size.X, size.Z), math.max(size.X, size.Z))
		body.CFrame = CFrame.Angles(0, 0, math.rad(90))
	else
		body.Size = size
		body.CFrame = CFrame.new()
	end
	body.Parent = model
	-- a little accent stripe so placeholders read as "objects"
	local stripe = Instance.new("Part")
	stripe.Name = "Accent"
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.Material = Enum.Material.Neon
	stripe.Color = (def.Color or Color3.new(1, 1, 1)):Lerp(Color3.new(1, 1, 1), 0.6)
	stripe.Size = Vector3.new(math.max(size.X, 0.4) * 1.02, math.max(0.2, size.Y * 0.08), math.max(size.Z, 0.4) * 1.02)
	if def.Shape == "Ball" then
		stripe.Shape = Enum.PartType.Cylinder
		local d = body.Size.X * 1.02
		stripe.Size = Vector3.new(math.max(0.2, d * 0.08), d, d)
		stripe.CFrame = CFrame.Angles(0, 0, math.rad(90))
	elseif def.Shape == "Cylinder" then
		stripe.Shape = Enum.PartType.Cylinder
		stripe.Size = Vector3.new(math.max(0.2, size.Y * 0.08), body.Size.Y * 1.02, body.Size.Z * 1.02)
		stripe.CFrame = CFrame.Angles(0, 0, math.rad(90))
	else
		stripe.CFrame = CFrame.new()
	end
	stripe.Parent = model
	model.PrimaryPart = body
	return model
end

function ModelFactory.Create(id)
	local def = ObjectConfig.Get(id) or { Name = id }
	local template = ModelFactory.TemplatesFolder():FindFirstChild(id)
	local model
	if template then
		model = template:Clone()
		if model:IsA("BasePart") then
			local wrapper = Instance.new("Model")
			wrapper.Name = id
			model.Parent = wrapper
			wrapper.PrimaryPart = model
			model = wrapper
		end
		if not model.PrimaryPart then
			model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		end
		-- any model you drop in (e.g. a Toolbox mesh) is auto-scaled to the size in ObjectConfig
		if def.Size then
			ModelFactory.FitToSize(model, math.max(def.Size.X, def.Size.Y, def.Size.Z))
		end
	else
		-- detailed built-in model (ObjectModels), scaled to the size in ObjectConfig
		model = ObjectModels.Build(id)
		if model and def.Size then
			ModelFactory.FitToSize(model, math.max(def.Size.X, def.Size.Y, def.Size.Z))
		elseif not model then
			model = placeholder(id, def)
		end
	end
	CollectionService:RemoveTag(model, "Shrinkable")
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	return model
end

-- Moves a model so its bounding-box bottom-center sits at `position`, with a Y rotation.
-- Mystery box for a shrunk object: rarity-colored crate with gold edges, a ribbon and "?" faces.
-- Bigger tiers give bigger boxes; Golden/Diamond/... boxes sparkle in their variant color.
function ModelFactory.CreateBox(id, variantName)
	local def = ObjectConfig.Get(id) or { Tier = 1, Rarity = "Common" }
	local rarity = RarityConfig.GetRarity(def.Rarity)
	local size = 2.3 + 0.22 * (def.Tier or 1)
	local model = Instance.new("Model")
	model.Name = "Box"
	local function piece(name, sz, cf, color, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = sz
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local h = size / 2
	local body = piece("Body", Vector3.new(size, size, size), CFrame.new(0, h, 0), rarity.Color, Enum.Material.SmoothPlastic)
	local gold = Color3.fromRGB(240, 190, 60)
	local t = 0.22
	for _, x in ipairs({ -h, h }) do
		for _, z in ipairs({ -h, h }) do
			piece("Edge", Vector3.new(t, size + t, t), CFrame.new(x, h, z), gold, Enum.Material.Metal)
		end
	end
	for _, y in ipairs({ 0, size }) do
		for _, x in ipairs({ -h, h }) do
			piece("Edge", Vector3.new(t, t, size + t), CFrame.new(x, y, 0), gold, Enum.Material.Metal)
		end
		for _, z in ipairs({ -h, h }) do
			piece("Edge", Vector3.new(size + t, t, t), CFrame.new(0, y, z), gold, Enum.Material.Metal)
		end
	end
	piece("Lid", Vector3.new(size + 0.12, size * 0.14, size + 0.12), CFrame.new(0, size * 0.82, 0), rarity.Color:Lerp(Color3.new(0, 0, 0), 0.25))
	piece("RibbonX", Vector3.new(size + 0.06, size + 0.06, size * 0.16), CFrame.new(0, h, 0), Color3.new(1, 1, 1))
	piece("RibbonZ", Vector3.new(size * 0.16, size + 0.06, size + 0.06), CFrame.new(0, h, 0), Color3.new(1, 1, 1))
	piece("Bow", Vector3.new(size * 0.3, size * 0.3, size * 0.3), CFrame.new(0, size + size * 0.08, 0) * CFrame.Angles(0, math.rad(45), 0), Color3.new(1, 1, 1))
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Parent = body
		local q = Instance.new("TextLabel")
		q.BackgroundTransparency = 1
		q.Size = UDim2.fromScale(1, 1)
		q.Font = Enum.Font.FredokaOne
		q.TextScaled = true
		q.Text = "?"
		q.TextColor3 = Color3.new(1, 1, 1)
		q.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 6
		stroke.Parent = q
	end
	model.PrimaryPart = body
	ModelFactory.ApplyVariant(model, variantName, false)
	return model
end

function ModelFactory.PlaceOnGround(model, position, yaw)
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw or 0, 0))
	local cf, size = model:GetBoundingBox()
	local desired = position + Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (desired - cf.Position))
end

-- Uniformly scales a model so its largest extent equals `maxSize`.
function ModelFactory.FitToSize(model, maxSize)
	local ext = model:GetExtentsSize()
	local m = math.max(ext.X, ext.Y, ext.Z)
	if m > 0 then
		model:ScaleTo(model:GetScale() * (maxSize / m))
	end
end

function ModelFactory.SetCollision(model, canCollide)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = canCollide
			d.CanTouch = false
		end
	end
end

function ModelFactory.ClearVariant(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d.Name == "VariantFX" then
			d:Destroy()
		end
	end
end

-- useHighlight: Highlight instances are capped at 31 on screen, so museum displays skip them.
function ModelFactory.ApplyVariant(model, variantName, useHighlight)
	ModelFactory.ClearVariant(model)
	local variant = RarityConfig.GetVariant(variantName)
	if not variant.Color then
		return
	end
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return
	end
	local ext = model:GetExtentsSize()
	local big = math.max(ext.X, ext.Y, ext.Z)

	if useHighlight then
		local h = Instance.new("Highlight")
		h.Name = "VariantFX"
		h.FillColor = variant.Color
		h.OutlineColor = variant.Color
		h.FillTransparency = 0.55
		h.OutlineTransparency = 0
		h.DepthMode = (variant.Order >= 4) and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
		h.Parent = model
		if variant.Rainbow then
			CollectionService:AddTag(h, "RainbowFX")
		end
	end

	local light = Instance.new("PointLight")
	light.Name = "VariantFX"
	light.Color = variant.Color
	light.Brightness = 3
	light.Range = math.clamp(big * 1.5, 8, 60)
	light.Parent = root
	if variant.Rainbow then
		CollectionService:AddTag(light, "RainbowFX")
	end

	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "VariantFX"
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(variant.Color)
	sparkles.LightEmission = 1
	sparkles.Rate = 6 + variant.Order * 3
	sparkles.Lifetime = NumberRange.new(1, 2)
	sparkles.Speed = NumberRange.new(1, 4)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	local s = math.clamp(big * 0.12, 0.3, 6)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Parent = root
	if variant.Rainbow then
		CollectionService:AddTag(sparkles, "RainbowFX")
	end
end

-- Floating name label above a spawned object.
function ModelFactory.AddLabel(model, id, variantName)
	local old = model:FindFirstChild("NameLabel")
	if old then
		old:Destroy()
	end
	local def = ObjectConfig.Get(id) or { Name = id, Rarity = "Common" }
	local variant = RarityConfig.GetVariant(variantName)
	local rarity = RarityConfig.GetRarity(def.Rarity)
	local _, size = model:GetBoundingBox()
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameLabel"
	gui.Adornee = model.PrimaryPart
	gui.Size = UDim2.fromOffset(220, 54)
	gui.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 2, 0)
	gui.MaxDistance = 90 + math.max(size.X, size.Y, size.Z) * 2
	gui.LightInfluence = 0
	gui.Parent = model
	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.6)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = variant.Color or Color3.new(1, 1, 1)
	name.Text = variant.Prefix .. def.Name
	name.Parent = gui
	Instance.new("UIStroke", name).Thickness = 2
	local r = Instance.new("TextLabel")
	r.Size = UDim2.fromScale(1, 0.4)
	r.Position = UDim2.fromScale(0, 0.6)
	r.BackgroundTransparency = 1
	r.Font = Enum.Font.FredokaOne
	r.TextScaled = true
	r.TextColor3 = rarity.Color
	r.Text = def.Rarity
	r.Parent = gui
	Instance.new("UIStroke", r).Thickness = 2
end

return ModelFactory
