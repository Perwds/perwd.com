--[[
	📍 LOCATION: ServerScriptService > Services > ChaserModels (ModuleScript)

	Blocky (voxel style) ANIMALS that guard each zone, like the sleeping chicken in Steal an Egg.
	ChaserConfig.Chasers[tier].Animal picks one of: Chicken, Dog, Raccoon, Crab, Camel, Gorilla,
	Eagle, Lizard, Yeti, Alien.

	Each animal is a Model with an invisible HumanoidRootPart + Humanoid (so it can run and MoveTo),
	every block welded to the root. Legs/arms hang on Motor6Ds named "LegA" / "LegB"; the client swings
	them while the animal runs (Effects, tag "AnimalChaser").
	Coordinates below: studs at scale 1, y measured from the ground, the animal faces -Z.
]]

local CollectionService = game:GetService("CollectionService")

local ChaserModels = {}

local RGB = Color3.fromRGB
local V = Vector3.new
local BLACK = RGB(25, 25, 30)
local WHITE = RGB(250, 250, 250)

-- one block: name, size, position, color, opts { Leg = "A"|"B", Rot = {x,y,z} degrees, Mat }
local function B(list, name, size, pos, color, opts)
	opts = opts or {}
	table.insert(list, { Name = name, Size = size, Pos = pos, Color = color, Leg = opts.Leg, Rot = opts.Rot, Mat = opts.Mat })
end

-- a pair of cartoon eyes on a face whose front is at z (white + pupil)
local function eyes(list, x, y, z, s)
	for _, sx in ipairs({ -1, 1 }) do
		B(list, "Eye", V(s, s * 1.15, 0.1), V(sx * x, y, z - 0.04), WHITE)
		B(list, "Pupil", V(s * 0.5, s * 0.7, 0.1), V(sx * x, y - s * 0.12, z - 0.1), BLACK)
	end
end

-- four legs: front/back pairs swing in opposite directions
local function quadLegs(list, w, h, x, z, color)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			B(list, "Leg", V(w, h, w), V(sx * x, h / 2, sz * z), color, { Leg = (sx * sz > 0) and "A" or "B" })
		end
	end
end

local ANIMALS = {}

ANIMALS.Chicken = function(L)
	local orange, red = RGB(255, 165, 40), RGB(230, 40, 40)
	for _, sx in ipairs({ -1, 1 }) do
		B(L, "Leg", V(0.35, 1.6, 0.35), V(sx * 0.6, 0.8, 0.2), orange, { Leg = sx < 0 and "A" or "B" })
	end
	B(L, "Body", V(2.6, 2.2, 3.0), V(0, 2.7, 0.1), WHITE)
	B(L, "Tail", V(2.0, 1.8, 0.9), V(0, 3.4, 1.75), WHITE, { Rot = { -20, 0, 0 } })
	for _, sx in ipairs({ -1, 1 }) do
		B(L, "Wing", V(0.35, 1.4, 2.2), V(sx * 1.45, 2.8, 0.1), RGB(232, 232, 236))
	end
	B(L, "Head", V(1.7, 1.9, 1.7), V(0, 4.6, -1.3), WHITE)
	B(L, "Beak", V(0.8, 0.5, 0.8), V(0, 4.5, -2.5), orange)
	B(L, "Comb", V(0.4, 0.8, 1.3), V(0, 5.9, -1.3), red)
	B(L, "Wattle", V(0.45, 0.6, 0.3), V(0, 3.95, -2.25), red)
	eyes(L, 0.45, 4.95, -2.15, 0.42)
end

ANIMALS.Dog = function(L)
	local brown, dark, light = RGB(175, 115, 60), RGB(110, 70, 40), RGB(230, 200, 160)
	quadLegs(L, 0.7, 1.8, 0.65, 1.25, brown)
	B(L, "Body", V(2.0, 1.7, 3.4), V(0, 2.6, 0), brown)
	B(L, "Collar", V(2.05, 0.4, 0.6), V(0, 3.15, -1.55), RGB(220, 40, 40))
	B(L, "Tag", V(0.35, 0.35, 0.1), V(0, 2.85, -1.9), RGB(255, 215, 60), { Mat = Enum.Material.Metal })
	B(L, "Head", V(1.9, 1.8, 1.8), V(0, 3.9, -2.1), brown)
	B(L, "Snout", V(1.0, 0.8, 1.0), V(0, 3.45, -3.4), light)
	B(L, "Nose", V(0.5, 0.35, 0.2), V(0, 3.8, -3.95), BLACK)
	for _, sx in ipairs({ -1, 1 }) do
		B(L, "Ear", V(0.45, 1.0, 0.6), V(sx * 0.8, 4.6, -1.9), dark, { Rot = { 0, 0, sx * 20 } })
	end
	B(L, "Tail", V(0.35, 0.35, 1.4), V(0, 3.3, 2.3), dark, { Rot = { 35, 0, 0 } })
	eyes(L, 0.45, 4.2, -3.0, 0.4)
end

ANIMALS.Raccoon = function(L)
	local grey, dark, light = RGB(140, 140, 150), RGB(45, 45, 52), RGB(225, 225, 230)
	quadLegs(L, 0.6, 1.4, 0.6, 1.1, dark)
	B(L, "Body", V(2.1, 1.6, 3.0), V(0, 2.2, 0), grey)
	B(L, "Head", V(1.9, 1.6, 1.6), V(0, 3.3, -1.9), grey)
	B(L, "Mask", V(1.95, 0.55, 0.1), V(0, 3.45, -2.72), dark)
	B(L, "Snout", V(0.8, 0.6, 0.7), V(0, 2.95, -3.0), light)
	B(L, "Nose", V(0.35, 0.3, 0.15), V(0, 3.15, -3.38), dark)
	for _, sx in ipairs({ -1, 1 }) do
		B(L, "Ear", V(0.5, 0.6, 0.3), V(sx * 0.65, 4.35, -1.9), grey)
	end
	for i = 0, 3 do
		B(L, "Tail", V(0.9 - i * 0.08, 0.9 - i * 0.08, 0.7), V(0, 2.6 + i * 0.3, 1.8 + i * 0.68), i % 2 == 0 and grey or dark)
	end
	eyes(L, 0.45, 3.5, -2.78, 0.32)
end

ANIMALS.Crab = function(L)
	local red, dark, light = RGB(225, 65, 45), RGB(170, 40, 30), RGB(255, 150, 120)
	for i = -1, 1 do
		for _, sx in ipairs({ -1, 1 }) do
			B(L, "Leg", V(0.3, 1.9, 0.3), V(sx * 2.1, 0.8, i * 0.8), dark, { Leg = ((i + sx) % 2 == 0) and "A" or "B", Rot = { 0, 0, sx * 50 } })
		end
	end
	B(L, "Body", V(3.6, 1.3, 2.6), V(0, 1.9, 0), red)
	B(L, "Head", V(3.0, 0.5, 2.2), V(0, 2.75, 0.1), dark)
	for _, sx in ipairs({ -1, 1 }) do
		B(L, "Arm", V(0.5, 0.5, 1.2), V(sx * 1.9, 2.0, -1.5), red)
		B(L, "Claw", V(1.3, 1.0, 1.4), V(sx * 2.3, 2.3, -2.4), red)
		B(L, "ClawTip", V(0.5, 0.4, 0.8), V(sx * 2.0, 2.3, -3.25), light)
		B(L, "Stalk", V(0.25, 1.0, 0.25), V(sx * 0.6, 3.1, -0.9), red)
		B(L, "Eye", V(0.55, 0.55, 0.55), V(sx * 0.6, 3.75, -0.9), WHITE)
		B(L, "Pupil", V(0.3, 0.35, 0.1), V(sx * 0.6, 3.72, -1.2), BLACK)
	end
end

ANIMALS.Camel = function(L)
	local tan, dark = RGB(210, 165, 105), RGB(150, 110, 65)
	quadLegs(L, 0.6, 3.0, 0.75, 1.4, tan)
	B(L, "Body", V(2.2, 1.9, 3.8), V(0, 3.9, 0), tan)
	B(L, "Hump", V(1.6, 1.2, 1.6), V(0, 5.3, 0.2), tan)
	B(L, "Neck", V(0.9, 2.2, 0.9), V(0, 5.1, -2.0), tan, { Rot = { -20, 0, 0 } })
	B(L, "Head", V(1.0, 1.0, 1.9), V(0, 6.4, -2.7), tan)
	B(L, "Lips", V(0.9, 0.35, 0.4), V(0, 6.0, -3.5), dark)
	for _, sx in ipairs({ -1, 1 }) do
		B(L, "Ear", V(0.25, 0.45, 0.25), V(sx * 0.4, 7.05, -2.2), dark)
	end
	B(L, "Tail", V(0.3, 1.2, 0.3), V(0, 3.6, 2.0), dark)
	eyes(L, 0.33, 6.6, -3.65, 0.3)
end

local function ape(L, fur, face, extra)
	for _, sx in ipairs({ -1, 1 }) do
		B(L, "Leg", V(1.0, 1.6, 1.0), V(sx * 0.75, 0.8, 0.3), fur, { Leg = sx < 0 and "A" or "B" })
		B(L, "Arm", V(0.9, 3.0, 0.9), V(sx * 1.95, 2.6, -0.2), fur, { Leg = sx < 0 and "B" or "A" })
	end
	B(L, "Body", V(3.0, 2.8, 2.0), V(0, 3.0, 0), fur)
	B(L, "Chest", V(2.0, 1.6, 0.1), V(0, 3.2, -1.03), face)
	B(L, "Head", V(1.7, 1.6, 1.6), V(0, 5.2, -0.3), fur)
	B(L, "Face", V(1.3, 1.0, 0.1), V(0, 5.05, -1.12), face)
	B(L, "Brow", V(1.6, 0.3, 0.3), V(0, 5.6, -1.1), fur)
	eyes(L, 0.33, 5.25, -1.18, 0.3)
	if extra then
		extra(L)
	end
end

ANIMALS.Gorilla = function(L)
	ape(L, RGB(45, 45, 52), RGB(100, 100, 110))
end

ANIMALS.Yeti = function(L)
	ape(L, RGB(238, 242, 250), RGB(140, 185, 230), function(list)
		for _, sx in ipairs({ -1, 1 }) do
			B(list, "Horn", V(0.3, 0.7, 0.3), V(sx * 0.65, 6.25, -0.3), RGB(200, 200, 210))
		end
	end)
end

ANIMALS.Eagle = function(L)
	local brown, yellow = RGB(110, 75, 45), RGB(250, 200, 50)
	for _, sx in ipairs({ -1, 1 }) do
		B(L, "Leg", V(0.3, 1.3, 0.3), V(sx * 0.5, 0.65, 0.2), yellow, { Leg = sx < 0 and "A" or "B" })
		B(L, "Wing", V(3.2, 0.3, 2.2), V(sx * 2.4, 3.1, 0.3), brown, { Rot = { 0, 0, sx * 20 } })
	end
	B(L, "Body", V(2.0, 2.2, 3.0), V(0, 2.4, 0.2), brown)
	B(L, "Tail", V(1.6, 0.3, 1.4), V(0, 2.6, 2.2), WHITE)
	B(L, "Head", V(1.5, 1.5, 1.5), V(0, 4.1, -1.1), WHITE)
	B(L, "Beak", V(0.6, 0.6, 0.9), V(0, 3.9, -2.2), yellow)
	B(L, "BeakTip", V(0.6, 0.3, 0.3), V(0, 3.55, -2.55), yellow)
	eyes(L, 0.45, 4.35, -1.85, 0.32)
end

ANIMALS.Lizard = function(L)
	local red, orange = RGB(200, 60, 30), RGB(255, 140, 40)
	quadLegs(L, 0.6, 1.0, 1.0, 1.3, red)
	B(L, "Body", V(2.0, 1.2, 3.6), V(0, 1.6, 0), red)
	B(L, "Head", V(1.5, 1.1, 1.8), V(0, 1.9, -2.5), red)
	B(L, "Jaw", V(1.3, 0.4, 1.6), V(0, 1.25, -2.6), orange)
	B(L, "Tail", V(1.0, 0.8, 1.4), V(0, 1.4, 2.4), red)
	B(L, "Tail", V(0.7, 0.6, 1.4), V(0, 1.2, 3.7), red)
	B(L, "Tail", V(0.4, 0.4, 1.2), V(0, 1.0, 4.9), orange)
	for i = 0, 4 do
		B(L, "Spike", V(0.25, 0.6, 0.5), V(0, 2.5, -1.2 + i * 0.7), RGB(255, 210, 60), { Mat = Enum.Material.Neon })
	end
	eyes(L, 0.45, 2.25, -3.4, 0.32)
end

ANIMALS.Alien = function(L)
	local green, pink = RGB(110, 220, 90), RGB(255, 90, 200)
	for _, sx in ipairs({ -1, 1 }) do
		B(L, "Leg", V(0.7, 1.8, 0.7), V(sx * 0.55, 0.9, 0), green, { Leg = sx < 0 and "A" or "B" })
		B(L, "Arm", V(0.5, 2.0, 0.5), V(sx * 1.2, 2.9, 0), green, { Leg = sx < 0 and "B" or "A" })
		B(L, "BigEye", V(0.8, 0.55, 0.1), V(sx * 0.55, 5.1, -1.12), BLACK)
		B(L, "Antenna", V(0.15, 1.0, 0.15), V(sx * 0.5, 6.5, 0), green)
		B(L, "Bulb", V(0.4, 0.4, 0.4), V(sx * 0.5, 7.1, 0), pink, { Mat = Enum.Material.Neon })
	end
	B(L, "Body", V(1.8, 2.2, 1.4), V(0, 2.9, 0), green)
	B(L, "Head", V(2.4, 2.0, 2.2), V(0, 5.0, 0), green)
end

function ChaserModels.Has(kind)
	return kind ~= nil and ANIMALS[kind] ~= nil
end

-- Builds the animal at the origin (ground = y 0). Returns the Model (PrimaryPart = HumanoidRootPart).
function ChaserModels.Build(kind, scale)
	scale = scale or 1
	local list = {}
	ANIMALS[kind](list)
	local model = Instance.new("Model")
	model.Name = kind
	local hip = 1 * scale
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = V(2, 1, 2) * scale
	root.CFrame = CFrame.new(0, hip + root.Size.Y / 2, 0)
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model
	for _, b in ipairs(list) do
		local p = Instance.new("Part")
		p.Name = b.Name
		p.Size = b.Size * scale
		local rot = b.Rot and CFrame.Angles(math.rad(b.Rot[1]), math.rad(b.Rot[2]), math.rad(b.Rot[3])) or CFrame.new()
		p.CFrame = CFrame.new(b.Pos * scale) * rot
		p.Color = b.Color
		p.Material = b.Mat or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.Parent = model
		if b.Leg then
			-- hinge at the top of the leg so it swings from the hip/shoulder
			local joint = p.CFrame * CFrame.new(0, p.Size.Y / 2, 0)
			local motor = Instance.new("Motor6D")
			motor.Name = "Leg" .. b.Leg
			motor.Part0 = root
			motor.Part1 = p
			motor.C0 = root.CFrame:Inverse() * joint
			motor.C1 = CFrame.new(0, p.Size.Y / 2, 0)
			motor.Parent = root
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end
	end
	local hum = Instance.new("Humanoid")
	hum.RequiresNeck = false
	hum.HipHeight = hip
	hum.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("Animal", kind)
	CollectionService:AddTag(model, "AnimalChaser")
	return model
end

return ChaserModels
