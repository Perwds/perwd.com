--[[
	📍 LOCATION: ReplicatedStorage > Shared > ObjectModels (ModuleScript)
	(Shared: the server builds world objects with it, the client builds 3D previews for the menus.)

	Detailed, textured models for EVERY object in ObjectConfig, built from parts with Roblox's
	built-in materials (WoodPlanks, Brick, Marble, Metal, Glass, Fabric, Slate, Ice, Neon, ...),
	so no uploaded meshes or images are needed.

	Each builder creates the object standing on y = 0, centered on x/z, front facing -Z.
	ModelFactory then scales it uniformly to the size in ObjectConfig.

	Want your own mesh instead? Put a Model named after the object id in
	ServerStorage > ShrinkableTemplates and it takes priority over these.
]]

local ObjectModels = {}

local C = Color3.fromRGB
local V = Vector3.new
local M = Enum.Material
local rad = math.rad

-- ── builder helpers ─────────────────────────────────────────────────
-- shape: "Block" | "Ball" | "Cyl" (vertical, size = (d, h, d)) | "CylX" (size = (len, d, d)) |
--        "CylZ" (size = (d, d, len)) | "Wedge" | "Corner"
local function add(m, shape, size, cf, color, material, extra)
	local p
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	elseif shape == "Corner" then
		p = Instance.new("CornerWedgePart")
	else
		p = Instance.new("Part")
	end
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if typeof(cf) == "Vector3" then
		cf = CFrame.new(cf)
	end
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
		p.Size = size
		p.CFrame = cf
	elseif shape == "Cyl" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = V(size.Y, size.X, size.Z)
		p.CFrame = cf * CFrame.Angles(0, 0, rad(90))
	elseif shape == "CylX" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.CFrame = cf
	elseif shape == "CylZ" then
		p.Shape = Enum.PartType.Cylinder
		p.Size = V(size.Z, size.X, size.Y)
		p.CFrame = cf * CFrame.Angles(0, rad(90), 0)
	else
		p.Size = size
		p.CFrame = cf
	end
	p.Color = color
	p.Material = material or M.SmoothPlastic
	if extra then
		for k, v in pairs(extra) do
			p[k] = v
		end
	end
	p.Parent = m
	return p
end

local function rot(pos, x, y, z)
	return CFrame.new(pos) * CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0))
end

-- A block stretched between two points (bars, spokes, legs, frames).
local function beam(m, a, b, thick, color, material)
	local len = (b - a).Magnitude
	return add(m, "Block", V(thick, thick, len), CFrame.lookAt((a + b) / 2, b), color, material)
end

-- Stack of cylinders tapering from radius r0 to r1 (cones, towers, hats).
local function cone(m, baseY, height, r0, r1, steps, color, material, x, z)
	x, z = x or 0, z or 0
	local h = height / steps
	local parts = {}
	for i = 0, steps - 1 do
		local t = i / math.max(1, steps - 1)
		local r = r0 + (r1 - r0) * t
		table.insert(parts, add(m, "Cyl", V(r * 2, h + 0.02, r * 2), V(x, baseY + h * (i + 0.5), z), color, material))
	end
	return parts
end

-- Wheel with tire, rim and hub; axis along X.
local function wheel(m, pos, d, width, tire, hub)
	add(m, "CylX", V(width, d, d), pos, tire or C(30, 30, 35), M.Fabric)
	add(m, "CylX", V(width + 0.05, d * 0.55, d * 0.55), pos, hub or C(190, 190, 200), M.Metal)
	add(m, "CylX", V(width + 0.1, d * 0.18, d * 0.18), pos, C(90, 90, 100), M.Metal)
end

local function window(m, cf, w, h, frame)
	add(m, "Block", V(w + 0.3, h + 0.3, 0.12), cf, frame or C(255, 255, 255))
	add(m, "Block", V(w, h, 0.18), cf, C(150, 205, 240), M.Glass, { Transparency = 0.15, Reflectance = 0.2 })
	add(m, "Block", V(0.12, h, 0.2), cf, frame or C(255, 255, 255))
end

local function neon(m, shape, size, cf, color)
	return add(m, shape, size, cf, color, M.Neon)
end

-- ── builders ─────────────────────────────────────────────────────────
local B = {}

-- Tier 1 ─────────────────────────────────────────
B.SodaCan = function(m)
	local red = C(220, 35, 45)
	add(m, "Cyl", V(1.4, 2.1, 1.4), V(0, 1.2, 0), red, M.SmoothPlastic, { Reflectance = 0.15 })
	add(m, "Cyl", V(1.42, 0.55, 1.42), V(0, 1.25, 0), C(250, 250, 250))
	add(m, "Cyl", V(1.43, 0.12, 1.43), V(0, 1.6, 0), C(255, 210, 60))
	add(m, "Cyl", V(1.25, 0.18, 1.25), V(0, 0.09, 0), C(200, 200, 210), M.Metal)
	add(m, "Cyl", V(1.25, 0.18, 1.25), V(0, 2.33, 0), C(200, 200, 210), M.Metal)
	add(m, "Block", V(0.35, 0.05, 0.22), V(0.15, 2.44, 0), C(220, 220, 230), M.Metal)
end

B.TrafficCone = function(m)
	local orange = C(255, 110, 20)
	add(m, "Block", V(2.2, 0.25, 2.2), V(0, 0.125, 0), C(35, 35, 40), M.Fabric)
	cone(m, 0.25, 2.9, 0.85, 0.12, 9, orange, M.SmoothPlastic)
	add(m, "Cyl", V(1.4, 0.32, 1.4), V(0, 1.35, 0), C(255, 255, 255), M.SmoothPlastic, { Reflectance = 0.3 })
	add(m, "Cyl", V(0.95, 0.28, 0.95), V(0, 2.15, 0), C(255, 255, 255), M.SmoothPlastic, { Reflectance = 0.3 })
end

B.Mailbox = function(m)
	local blue = C(40, 85, 200)
	add(m, "Block", V(0.4, 3.1, 0.4), V(0, 1.55, 0), C(120, 85, 55), M.Wood)
	add(m, "Block", V(1.1, 0.25, 1.1), V(0, 0.12, 0), C(100, 100, 105), M.Concrete)
	add(m, "Block", V(1.1, 0.8, 1.9), V(0, 3.45, 0), blue, M.Metal)
	add(m, "CylZ", V(1.1, 1.1, 1.9), V(0, 3.85, 0), blue, M.Metal)
	add(m, "CylZ", V(1.0, 1.0, 0.1), V(0, 3.75, -0.98), blue:Lerp(C(0, 0, 0), 0.25), M.Metal)
	add(m, "Block", V(0.25, 0.12, 0.1), V(0, 3.6, -1.05), C(220, 220, 230), M.Metal)
	add(m, "Block", V(0.08, 0.8, 0.12), V(0.6, 3.9, 0.3), C(220, 40, 40))
	add(m, "Block", V(0.08, 0.35, 0.5), V(0.6, 4.15, 0.5), C(220, 40, 40))
end

B.FireHydrant = function(m)
	local red = C(220, 35, 35)
	local dark = C(150, 25, 25)
	add(m, "Cyl", V(1.7, 0.3, 1.7), V(0, 0.15, 0), dark, M.Metal)
	add(m, "Cyl", V(1.15, 2.1, 1.15), V(0, 1.35, 0), red, M.Metal)
	add(m, "Cyl", V(1.4, 0.25, 1.4), V(0, 2.45, 0), dark, M.Metal)
	add(m, "Ball", V(1.15, 1.15, 1.15), V(0, 2.62, 0), red, M.Metal)
	add(m, "Cyl", V(0.4, 0.35, 0.4), V(0, 3.2, 0), C(200, 190, 60), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "CylX", V(0.6, 0.5, 0.5), V(s * 0.75, 1.85, 0), red, M.Metal)
		add(m, "CylX", V(0.15, 0.62, 0.62), V(s * 1.05, 1.85, 0), C(200, 190, 60), M.Metal)
	end
	add(m, "CylZ", V(0.7, 0.7, 0.6), V(0, 1.6, -0.75), red, M.Metal)
	add(m, "CylZ", V(0.82, 0.82, 0.15), V(0, 1.6, -1.05), C(200, 190, 60), M.Metal)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		add(m, "Ball", V(0.18, 0.18, 0.18), V(math.cos(a) * 0.72, 0.32, math.sin(a) * 0.72), C(90, 90, 95), M.Metal)
	end
end

B.GardenGnome = function(m)
	local skin = C(245, 200, 170)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ball", V(0.55, 0.45, 0.55), V(s * 0.25, 0.22, -0.1), C(110, 70, 40), M.SmoothPlastic)
		add(m, "Block", V(0.25, 0.65, 0.25), V(s * 0.58, 1.15, 0), C(60, 90, 200), M.Fabric)
		add(m, "Ball", V(0.3, 0.3, 0.3), V(s * 0.58, 0.8, -0.05), skin)
	end
	cone(m, 0.3, 1.2, 0.68, 0.45, 5, C(60, 90, 200), M.Fabric)
	add(m, "Cyl", V(1.0, 0.15, 1.0), V(0, 1.0, 0), C(35, 30, 30), M.Fabric)
	add(m, "Block", V(0.3, 0.22, 0.1), V(0, 1.0, -0.5), C(255, 210, 60), M.Metal)
	add(m, "Ball", V(0.85, 0.85, 0.85), V(0, 1.8, 0), skin)
	add(m, "Ball", V(0.85, 0.85, 0.85), V(0, 1.5, -0.22), C(245, 245, 245), M.Fabric)
	add(m, "Ball", V(0.28, 0.28, 0.28), V(0, 1.82, -0.42), C(250, 150, 140))
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ball", V(0.12, 0.12, 0.12), V(s * 0.17, 1.95, -0.37), C(20, 20, 20))
	end
	cone(m, 2.08, 1.2, 0.5, 0.05, 8, C(215, 40, 40), M.Fabric)
end

-- Tier 2 ─────────────────────────────────────────
B.Bench = function(m)
	local wood = C(160, 105, 60)
	local iron = C(35, 40, 45)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(0.3, 1.5, 0.3), V(s * 3.2, 0.75, -0.9), iron, M.Metal)
		add(m, "Block", V(0.3, 1.5, 0.3), V(s * 3.2, 0.75, 0.9), iron, M.Metal)
		add(m, "Block", V(0.3, 0.25, 2.1), V(s * 3.2, 1.45, 0), iron, M.Metal)
		add(m, "Block", V(0.32, 0.22, 1.8), V(s * 3.2, 2.2, -0.1), iron, M.Metal)
		add(m, "Block", V(0.3, 2.0, 0.25), rot(V(s * 3.2, 2.45, 1.05), -10, 0, 0), iron, M.Metal)
	end
	for _, z in ipairs({ -0.7, 0, 0.7 }) do
		add(m, "Block", V(7, 0.22, 0.55), V(0, 1.65, z), wood, M.WoodPlanks)
	end
	for _, y in ipairs({ 2.35, 3.05 }) do
		add(m, "Block", V(7, 0.5, 0.18), rot(V(0, y, 1.0 + (y - 2.35) * 0.18), -10, 0, 0), wood, M.WoodPlanks)
	end
end

B.TrashBin = function(m)
	local green = C(55, 120, 70)
	add(m, "Cyl", V(2.8, 3.8, 2.8), V(0, 2.0, 0), green, M.Metal)
	for _, y in ipairs({ 1.1, 2.5 }) do
		add(m, "Cyl", V(2.95, 0.18, 2.95), V(0, y, 0), green:Lerp(C(0, 0, 0), 0.25), M.Metal)
	end
	add(m, "Cyl", V(3.05, 0.4, 3.05), V(0, 4.05, 0), green:Lerp(C(0, 0, 0), 0.35), M.Metal)
	add(m, "Block", V(1.0, 0.3, 0.25), V(0, 4.38, 0), C(40, 40, 45), M.Metal)
	add(m, "Block", V(1.2, 0.5, 0.15), V(0, 3.1, -1.42), C(250, 250, 250))
	for _, s in ipairs({ -1, 1 }) do
		wheel(m, V(s * 1.0, 0.35, 1.25), 0.7, 0.3)
	end
end

B.Bike = function(m)
	local frame = C(30, 170, 220)
	local wz = 1.85
	for _, z in ipairs({ -wz, wz }) do
		add(m, "CylX", V(0.22, 2.6, 2.6), V(0, 1.3, z), C(30, 30, 35), M.Fabric)
		add(m, "CylX", V(0.26, 2.2, 2.2), V(0, 1.3, z), C(200, 200, 210), M.Metal, { Transparency = 0.6 })
		add(m, "CylX", V(0.3, 0.35, 0.35), V(0, 1.3, z), C(150, 150, 160), M.Metal)
		for k = 0, 3 do
			add(m, "Block", V(0.05, 2.2, 0.06), CFrame.new(0, 1.3, z) * CFrame.Angles(rad(k * 45), 0, 0), C(210, 210, 220), M.Metal)
		end
	end
	local bb, seat, head = V(0, 1.3, 0.25), V(0, 2.6, 0.6), V(0, 2.55, -1.35)
	beam(m, bb, head, 0.2, frame, M.Metal)
	beam(m, V(0, 2.45, 0.55), head, 0.2, frame, M.Metal)
	beam(m, bb, seat, 0.2, frame, M.Metal)
	beam(m, bb, V(0, 1.3, wz), 0.16, frame, M.Metal)
	beam(m, V(0, 2.45, 0.55), V(0, 1.3, wz), 0.16, frame, M.Metal)
	beam(m, head, V(0, 1.3, -wz), 0.18, frame, M.Metal)
	beam(m, head, V(0, 3.0, -1.45), 0.15, C(50, 50, 55), M.Metal)
	add(m, "Block", V(1.5, 0.12, 0.12), V(0, 3.0, -1.45), C(50, 50, 55), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "CylX", V(0.35, 0.18, 0.18), V(s * 0.85, 3.0, -1.45), C(30, 30, 30), M.Fabric)
		add(m, "Block", V(0.5, 0.08, 0.25), V(s * 0.35, 1.05 + s * 0.25, 0.25), C(40, 40, 40), M.Metal)
	end
	add(m, "Block", V(0.45, 0.18, 0.85), V(0, 2.72, 0.65), C(30, 30, 30), M.Fabric)
	add(m, "Cyl", V(0.7, 0.08, 0.7), V(0.15, 1.3, 0.25), C(120, 120, 130), M.Metal)
	add(m, "Block", V(0.6, 0.3, 0.5), V(0, 2.75, -1.55), C(250, 250, 250), M.Metal)
end

B.VendingMachine = function(m)
	local red = C(210, 30, 60)
	add(m, "Block", V(4, 7, 3), V(0, 3.5, 0), red, M.Metal)
	add(m, "Block", V(4.05, 0.7, 3.05), V(0, 6.6, 0), C(250, 250, 250))
	neon(m, "Block", V(3.2, 0.4, 0.1), V(0, 6.6, -1.55), C(255, 220, 80))
	add(m, "Block", V(2.7, 4.8, 0.1), V(-0.55, 3.9, -1.5), C(40, 40, 50))
	add(m, "Block", V(2.6, 4.7, 0.12), V(-0.55, 3.9, -1.55), C(180, 220, 255), M.Glass, { Transparency = 0.4 })
	local can = { C(220, 40, 40), C(40, 120, 220), C(60, 180, 60), C(255, 170, 30) }
	for row = 0, 3 do
		add(m, "Block", V(2.6, 0.08, 0.6), V(-0.55, 2.0 + row * 1.15, -1.15), C(200, 200, 210), M.Metal)
		for col = 0, 3 do
			add(m, "Cyl", V(0.45, 0.7, 0.45), V(-1.5 + col * 0.63, 2.4 + row * 1.15, -1.15), can[(row + col) % 4 + 1])
		end
	end
	add(m, "Block", V(0.9, 4.8, 0.1), V(1.45, 3.9, -1.52), C(50, 50, 60), M.Metal)
	for i = 0, 5 do
		neon(m, "Block", V(0.25, 0.25, 0.08), V(1.3 + (i % 2) * 0.3, 5.5 - math.floor(i / 2) * 0.45, -1.58), C(120, 255, 140))
	end
	add(m, "Block", V(0.3, 0.6, 0.08), V(1.45, 3.4, -1.58), C(20, 20, 20))
	add(m, "Block", V(2.7, 0.7, 0.12), V(-0.55, 0.85, -1.52), C(20, 20, 25))
end

B.ArcadeCabinet = function(m)
	local purple = C(110, 40, 210)
	add(m, "Block", V(3.1, 7, 2.8), V(0, 3.5, 0.1), purple, M.SmoothPlastic)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(0.18, 7.1, 3.3), V(s * 1.62, 3.55, 0), C(25, 20, 35), M.SmoothPlastic)
		neon(m, "Block", V(0.05, 6.8, 0.1), V(s * 1.72, 3.5, -1.5), C(0, 230, 255))
	end
	neon(m, "Block", V(2.9, 0.9, 0.3), V(0, 6.55, -1.35), C(255, 60, 180))
	add(m, "Block", V(2.8, 2.3, 0.2), rot(V(0, 4.9, -1.25), -12, 0, 0), C(20, 20, 25))
	neon(m, "Block", V(2.4, 1.9, 0.1), rot(V(0, 4.9, -1.38), -12, 0, 0), C(60, 140, 255))
	add(m, "Block", V(3, 0.3, 1.2), rot(V(0, 3.45, -1.85), 12, 0, 0), C(30, 25, 40))
	add(m, "Cyl", V(0.12, 0.45, 0.12), V(-0.8, 3.75, -1.9), C(40, 40, 40), M.Metal)
	add(m, "Ball", V(0.35, 0.35, 0.35), V(-0.8, 4.0, -1.9), C(230, 40, 40))
	for i, col in ipairs({ C(255, 220, 40), C(60, 220, 90), C(60, 140, 255) }) do
		add(m, "Cyl", V(0.3, 0.12, 0.3), V(0.0 + i * 0.4, 3.68, -1.95), col)
	end
	add(m, "Block", V(1, 1.1, 0.1), V(0, 1.5, -1.32), C(30, 30, 35), M.Metal)
	neon(m, "Block", V(0.15, 0.35, 0.05), V(-0.2, 1.6, -1.38), C(255, 140, 40))
	neon(m, "Block", V(0.15, 0.35, 0.05), V(0.2, 1.6, -1.38), C(255, 140, 40))
end

-- Tier 3 ─────────────────────────────────────────
local function car(m, body, opts)
	opts = opts or {}
	local L, W = 13, 6.6
	add(m, "Block", V(W, 1.8, L), V(0, 1.9, 0), body, M.SmoothPlastic, { Reflectance = 0.1 })
	add(m, "Block", V(W - 0.8, 1.9, 6.5), V(0, 3.75, 0.6), body, M.SmoothPlastic, { Reflectance = 0.1 })
	add(m, "Block", V(W - 0.7, 1.25, 6.2), V(0, 3.85, 0.6), C(40, 60, 90), M.Glass, { Transparency = 0.1, Reflectance = 0.3 })
	add(m, "Block", V(W - 0.8, 0.3, 6.5), V(0, 4.85, 0.6), body:Lerp(C(0, 0, 0), 0.15))
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -4.2, 4.2 }) do
			wheel(m, V(s * 3.1, 1.2, z), 2.4, 0.9)
		end
		neon(m, "Block", V(1.1, 0.5, 0.1), V(s * 2.3, 2.3, -6.52), C(255, 250, 200))
		neon(m, "Block", V(1.1, 0.4, 0.1), V(s * 2.3, 2.3, 6.52), C(255, 40, 40))
		add(m, "Block", V(0.35, 0.3, 0.6), V(s * 3.1, 3.8, -2.4), body)
		add(m, "Block", V(0.05, 0.05, 2.5), V(s * 3.31, 2.4, 0.3), C(220, 220, 230), M.Metal)
	end
	add(m, "Block", V(W + 0.2, 0.5, 0.4), V(0, 1.15, -6.6), C(180, 180, 190), M.Metal)
	add(m, "Block", V(W + 0.2, 0.5, 0.4), V(0, 1.15, 6.6), C(180, 180, 190), M.Metal)
	add(m, "Block", V(3, 0.7, 0.1), V(0, 2.0, -6.53), C(30, 30, 35), M.Metal)
	add(m, "Block", V(1.6, 0.4, 0.08), V(0, 1.4, 6.82), C(250, 250, 250))
	if opts.Taxi then
		add(m, "Block", V(1.6, 0.6, 0.8), V(0, 5.3, 0.6), C(255, 255, 255))
	end
end

B.Car = function(m)
	car(m, C(40, 120, 230))
end

B.Tree = function(m)
	local trunk = C(115, 78, 45)
	add(m, "Cyl", V(1.8, 9, 1.8), V(0, 4.5, 0), trunk, M.Wood)
	add(m, "Cyl", V(2.6, 0.8, 2.6), V(0, 0.4, 0), trunk, M.Wood)
	beam(m, V(0, 6, 0), V(2.5, 9, 0.5), 0.7, trunk, M.Wood)
	beam(m, V(0, 7, 0), V(-2.2, 9.5, -0.8), 0.7, trunk, M.Wood)
	local g = C(70, 165, 65)
	add(m, "Ball", V(8, 8, 8), V(0, 12, 0), g, M.SmoothPlastic)
	add(m, "Ball", V(6, 6, 6), V(2.8, 10.5, 1), g:Lerp(C(255, 255, 255), 0.08), M.SmoothPlastic)
	add(m, "Ball", V(6, 6, 6), V(-2.6, 10.8, -1.2), g:Lerp(C(0, 0, 0), 0.08), M.SmoothPlastic)
	add(m, "Ball", V(5.5, 5.5, 5.5), V(0.5, 15, -0.5), g:Lerp(C(255, 255, 255), 0.12), M.SmoothPlastic)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		add(m, "Ball", V(0.6, 0.6, 0.6), V(math.cos(a) * 3.6, 11 + (i % 2), math.sin(a) * 3.6), C(230, 50, 50))
	end
end

B.FoodTruck = function(m)
	local yellow = C(255, 205, 50)
	add(m, "Block", V(7.6, 5.5, 4.5), V(0, 3.75, -6.5), C(250, 250, 250))
	add(m, "Block", V(7.0, 2.2, 0.12), V(0, 5.0, -8.78), C(50, 80, 110), M.Glass, { Transparency = 0.1, Reflectance = 0.3 })
	add(m, "Block", V(8, 8, 12.5), V(0, 5.1, 2.0), yellow)
	add(m, "Block", V(8.05, 0.6, 12.55), V(0, 2.0, 2.0), C(230, 60, 50))
	add(m, "Block", V(0.12, 3, 6.5), V(-4.03, 5.8, 2.0), C(60, 40, 30))
	add(m, "Block", V(0.9, 0.3, 6.5), V(-4.45, 4.25, 2.0), C(200, 200, 210), M.Metal)
	for i = 0, 6 do
		local col = (i % 2 == 0) and C(230, 50, 50) or C(255, 255, 255)
		add(m, "Block", V(1.9, 0.18, 0.95), rot(V(-4.85, 7.55, -1.0 + i * 0.95), 0, 0, -18), col, M.Fabric)
	end
	neon(m, "Block", V(0.3, 1.4, 7), V(0, 9.8, 2.0), C(255, 80, 160))
	-- giant burger on the roof
	add(m, "Cyl", V(4, 1, 4), V(0, 9.6, 6.2), C(210, 150, 80))
	add(m, "Cyl", V(4.3, 0.5, 4.3), V(0, 10.3, 6.2), C(90, 180, 60), M.SmoothPlastic)
	add(m, "Cyl", V(4.1, 0.7, 4.1), V(0, 10.85, 6.2), C(110, 60, 40))
	add(m, "Ball", V(4.2, 3, 4.2), V(0, 11.6, 6.2), C(220, 160, 90))
	for _, s in ipairs({ -1, 1 }) do
		wheel(m, V(s * 3.9, 1.3, -6.2), 2.6, 1)
		wheel(m, V(s * 3.9, 1.3, 5.2), 2.6, 1)
		neon(m, "Block", V(1, 0.6, 0.1), V(s * 2.6, 3.0, -8.78), C(255, 250, 200))
	end
end

B.Statue = function(m)
	local stone = C(210, 205, 195)
	local copper = C(110, 175, 155)
	add(m, "Block", V(6, 1, 6), V(0, 0.5, 0), stone, M.Marble)
	add(m, "Block", V(5, 1, 5), V(0, 1.5, 0), stone, M.Marble)
	add(m, "Block", V(4, 3, 4), V(0, 3.5, 0), stone, M.Marble)
	add(m, "Block", V(2.2, 0.9, 0.1), V(0, 3.5, -2.03), C(200, 160, 60), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(0.8, 3, 0.9), V(s * 0.5, 6.5, 0), copper, M.Marble)
	end
	add(m, "Cyl", V(2.4, 3.6, 2.0), V(0, 9.6, 0), copper, M.Marble)
	add(m, "Block", V(0.7, 0.7, 0.7), V(0, 11.5, 0), copper, M.Marble)
	add(m, "Ball", V(1.4, 1.4, 1.4), V(0, 12.4, 0), copper, M.Marble)
	for i = 0, 6 do
		local a = rad(-60 + i * 20)
		add(m, "Block", V(0.2, 0.6, 0.2), CFrame.new(math.sin(a) * 0.6, 13.15, -math.cos(a) * 0.3) * CFrame.Angles(0, -a, 0), copper, M.Marble)
	end
	add(m, "Block", V(0.6, 3.2, 0.6), rot(V(1.25, 12.2, 0), 0, 0, -12), copper, M.Marble)
	add(m, "Cyl", V(0.6, 1.0, 0.6), V(1.55, 14.1, 0), copper, M.Marble)
	neon(m, "Ball", V(0.9, 1.2, 0.9), V(1.55, 14.9, 0), C(255, 190, 60))
	add(m, "Block", V(0.6, 2.2, 0.6), rot(V(-1.2, 9.6, -0.2), 20, 0, 10), copper, M.Marble)
	add(m, "Block", V(0.9, 1.3, 0.25), V(-1.4, 9.0, -0.6), copper, M.Marble)
end

B.SportsCar = function(m)
	local red = C(235, 30, 35)
	add(m, "Block", V(6.8, 1.4, 14.5), V(0, 1.45, 0), red, M.SmoothPlastic, { Reflectance = 0.2 })
	add(m, "Wedge", V(6.8, 0.9, 4.2), V(0, 2.6, -4.9), red, M.SmoothPlastic, { Reflectance = 0.2 })
	add(m, "Wedge", V(6.8, 0.9, 3.6), rot(V(0, 2.6, 4.9), 0, 180, 0), red, M.SmoothPlastic, { Reflectance = 0.2 })
	add(m, "Block", V(5.6, 1.3, 4.6), V(0, 2.75, 0.4), C(30, 40, 60), M.Glass, { Transparency = 0.1, Reflectance = 0.35 })
	add(m, "Block", V(5.4, 0.25, 3.2), V(0, 3.45, 0.6), red)
	add(m, "Block", V(1.0, 0.06, 14.6), V(0, 2.18, 0), C(255, 255, 255))
	add(m, "Block", V(6.6, 0.25, 1.1), V(0, 3.75, 6.7), C(25, 25, 30), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(0.25, 1.4, 0.3), V(s * 2.4, 3.0, 6.7), C(25, 25, 30), M.Metal)
		wheel(m, V(s * 3.35, 1.1, -4.6), 2.2, 0.9, nil, C(255, 200, 40))
		wheel(m, V(s * 3.35, 1.1, 4.6), 2.2, 0.9, nil, C(255, 200, 40))
		neon(m, "Block", V(1.4, 0.3, 0.1), V(s * 2.3, 1.75, -7.27), C(220, 245, 255))
		neon(m, "Block", V(1.6, 0.3, 0.1), V(s * 2.3, 1.75, 7.27), C(255, 30, 30))
		add(m, "Block", V(0.1, 0.5, 2.5), V(s * 3.42, 1.6, -0.6), C(20, 20, 20))
	end
	add(m, "CylZ", V(0.35, 0.35, 0.5), V(-0.6, 0.9, 7.3), C(180, 180, 190), M.Metal)
	add(m, "CylZ", V(0.35, 0.35, 0.5), V(0.6, 0.9, 7.3), C(180, 180, 190), M.Metal)
end

-- Tier 4 ─────────────────────────────────────────
B.House = function(m)
	local wall = C(245, 230, 200)
	local roof = C(185, 60, 55)
	add(m, "Block", V(18, 0.6, 16), V(0, 0.3, 0), C(150, 145, 140), M.Concrete)
	add(m, "Block", V(18, 10, 16), V(0, 5.6, 0), wall, M.Brick)
	add(m, "Wedge", V(19, 6, 8.6), V(0, 13.6, -4.3), roof, M.Slate)
	add(m, "Wedge", V(19, 6, 8.6), rot(V(0, 13.6, 4.3), 0, 180, 0), roof, M.Slate)
	add(m, "Block", V(2.2, 5, 2.2), V(5, 15, 3), C(150, 80, 70), M.Brick)
	add(m, "Block", V(3, 6, 0.3), V(0, 3.6, -8.1), C(130, 75, 40), M.WoodPlanks)
	add(m, "Ball", V(0.35, 0.35, 0.35), V(1, 3.6, -8.3), C(220, 190, 60), M.Metal)
	for _, x in ipairs({ -5.5, 5.5 }) do
		window(m, CFrame.new(x, 6, -8.05), 3, 3)
		add(m, "Block", V(4, 0.8, 0.8), V(x, 4.2, -8.4), C(130, 75, 40), M.Wood)
		for i = 0, 2 do
			add(m, "Ball", V(0.7, 0.7, 0.7), V(x - 1.2 + i * 1.2, 4.8, -8.4), ({ C(255, 90, 120), C(255, 220, 60), C(170, 110, 255) })[i + 1])
		end
	end
	for _, x in ipairs({ -9.05, 9.05 }) do
		window(m, CFrame.new(x, 6, 0) * CFrame.Angles(0, rad(90), 0), 3, 3)
	end
	add(m, "Block", V(7, 0.6, 3.5), V(0, 0.9, -9.6), C(160, 110, 70), M.WoodPlanks)
	for _, x in ipairs({ -3.2, 3.2 }) do
		add(m, "Cyl", V(0.5, 5.6, 0.5), V(x, 3.8, -11), C(255, 255, 255), M.Wood)
	end
	add(m, "Block", V(7.6, 0.4, 4), V(0, 6.8, -9.9), roof, M.Slate)
	window(m, CFrame.new(0, 13.0, -8.4), 2.2, 2.2)
end

B.Bus = function(m)
	local yellow = C(255, 200, 30)
	add(m, "Block", V(7.6, 7, 25), V(0, 4.6, 0), yellow, M.SmoothPlastic)
	add(m, "Block", V(7.4, 0.5, 24.6), V(0, 8.35, 0), yellow:Lerp(C(255, 255, 255), 0.3))
	add(m, "Block", V(7.7, 0.45, 25.1), V(0, 3.4, 0), C(30, 30, 30))
	add(m, "Block", V(7.7, 2.3, 21), V(0, 6.2, 1.2), C(40, 50, 70), M.Glass, { Transparency = 0.1, Reflectance = 0.3 })
	for i = 0, 6 do
		add(m, "Block", V(7.75, 2.3, 0.3), V(0, 6.2, -9 + i * 3.4), yellow)
	end
	add(m, "Block", V(7, 3.2, 0.12), V(0, 6.0, -12.55), C(40, 50, 70), M.Glass, { Transparency = 0.1, Reflectance = 0.3 })
	neon(m, "Block", V(4.5, 0.8, 0.12), V(0, 7.9, -12.56), C(255, 150, 40))
	add(m, "Block", V(7.8, 0.7, 0.5), V(0, 1.6, -12.7), C(40, 40, 40), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		wheel(m, V(s * 3.7, 1.4, -8), 2.8, 1)
		wheel(m, V(s * 3.7, 1.4, 8), 2.8, 1)
		neon(m, "Block", V(1, 0.6, 0.1), V(s * 2.9, 2.5, -12.57), C(255, 250, 200))
		neon(m, "Block", V(0.9, 0.9, 0.1), V(s * 2.9, 6.0, 12.55), C(255, 40, 40))
	end
	add(m, "Cyl", V(1.6, 0.12, 1.6), rot(V(-3.95, 4.8, -9), 0, 0, 90), C(220, 30, 30))
	add(m, "Block", V(0.12, 4.2, 2.0), V(3.86, 3.8, -10.5), C(40, 40, 45), M.Metal)
end

B.Windmill = function(m)
	add(m, "Cyl", V(10, 1, 10), V(0, 0.5, 0), C(140, 135, 125), M.Cobblestone)
	cone(m, 1, 18, 4.5, 3.2, 6, C(245, 240, 230), M.Brick)
	add(m, "Block", V(2, 3.5, 0.3), V(0, 2.75, -4.45), C(120, 75, 40), M.WoodPlanks)
	window(m, CFrame.new(0, 9, -3.9), 1.4, 1.8)
	window(m, CFrame.new(0, 14, -3.55), 1.2, 1.6)
	add(m, "Cyl", V(7.4, 0.6, 7.4), V(0, 19.2, 0), C(120, 75, 40), M.Wood)
	cone(m, 19.4, 4.5, 3.7, 0.4, 7, C(200, 60, 50), M.WoodPlanks)
	local hub = CFrame.new(0, 17.5, -4.3)
	add(m, "CylZ", V(1.6, 1.6, 2), hub, C(90, 60, 35), M.Wood)
	for k = 0, 3 do
		local arm = hub * CFrame.Angles(0, 0, rad(k * 90 + 20))
		add(m, "Block", V(0.35, 10, 0.35), arm * CFrame.new(0, 5.2, -0.6), C(110, 75, 45), M.Wood)
		add(m, "Block", V(1.8, 8, 0.12), arm * CFrame.new(1.0, 5.8, -0.65), C(250, 248, 240), M.Fabric)
		for j = 0, 3 do
			add(m, "Block", V(2.0, 0.12, 0.14), arm * CFrame.new(1.0, 2.5 + j * 2.2, -0.75), C(110, 75, 45), M.Wood)
		end
	end
end

B.Boat = function(m)
	local white = C(250, 250, 252)
	add(m, "Block", V(8, 3, 16), V(0, 1.5, 1), white, M.SmoothPlastic)
	add(m, "Wedge", V(8, 3, 6), rot(V(0, 1.5, -10), 0, 0, 180), white, M.SmoothPlastic)
	add(m, "Block", V(8.1, 0.6, 16.1), V(0, 2.4, 1), C(40, 90, 190))
	add(m, "Block", V(8.1, 0.8, 16.1), V(0, 0.4, 1), C(190, 40, 40))
	add(m, "Block", V(7.5, 0.2, 15.5), V(0, 3.1, 1), C(170, 120, 75), M.WoodPlanks)
	add(m, "Block", V(5, 3, 6), V(0, 4.7, 3.5), white)
	add(m, "Block", V(5.1, 1.2, 6.1), V(0, 5.2, 3.5), C(40, 60, 90), M.Glass, { Transparency = 0.1, Reflectance = 0.3 })
	add(m, "Block", V(5.6, 0.35, 6.6), V(0, 6.35, 3.5), C(30, 50, 100))
	add(m, "Cyl", V(0.45, 8.5, 0.45), V(0, 7.3, -2), C(150, 105, 60), M.Wood)
	add(m, "Wedge", V(0.12, 6.5, 4.5), V(0, 7.0, -4.35), C(250, 250, 245), M.Fabric)
	add(m, "Block", V(0.2, 0.2, 5), V(0, 4.0, -4.3), C(150, 105, 60), M.Wood)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(0.15, 0.15, 15), V(s * 3.9, 3.9, 1), C(200, 200, 210), M.Metal)
		for i = 0, 6 do
			add(m, "Block", V(0.12, 0.8, 0.12), V(s * 3.9, 3.5, -6 + i * 2.4), C(200, 200, 210), M.Metal)
		end
	end
	add(m, "CylX", V(0.3, 1.6, 1.6), V(4.1, 2.4, 6), C(255, 120, 30))
	add(m, "Block", V(1.4, 0.15, 0.6), V(0, 6.6, 1), C(255, 255, 255))
end

B.Lighthouse = function(m)
	add(m, "Cyl", V(9, 1, 9), V(0, 0.5, 0), C(130, 125, 120), M.Cobblestone)
	local bands = 6
	for i = 0, bands - 1 do
		local t = i / bands
		local d = 8 - 2 * t
		add(m, "Cyl", V(d, 4.02, d), V(0, 1 + 4 * (i + 0.5), 0), (i % 2 == 0) and C(250, 250, 250) or C(220, 40, 45), M.SmoothPlastic)
	end
	add(m, "Block", V(1.6, 2.8, 0.3), V(0, 2.4, -3.95), C(60, 45, 35), M.WoodPlanks)
	add(m, "Cyl", V(8, 0.6, 8), V(0, 25.3, 0), C(40, 40, 45), M.Metal)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		add(m, "Cyl", V(0.12, 1.1, 0.12), V(math.cos(a) * 3.8, 26.1, math.sin(a) * 3.8), C(40, 40, 45), M.Metal)
	end
	add(m, "Cyl", V(8, 0.15, 8), V(0, 26.65, 0), C(40, 40, 45), M.Metal)
	add(m, "Cyl", V(4.5, 3.2, 4.5), V(0, 27.2, 0), C(255, 250, 210), M.Glass, { Transparency = 0.4 })
	local lamp = neon(m, "Ball", V(2.4, 2.4, 2.4), V(0, 27.2, 0), C(255, 240, 150))
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 2
	light.Color = C(255, 240, 180)
	light.Parent = lamp
	cone(m, 28.8, 2.6, 2.8, 0.3, 6, C(220, 40, 45), M.Metal)
	add(m, "Ball", V(0.6, 0.6, 0.6), V(0, 31.6, 0), C(40, 40, 45), M.Metal)
end

-- Tier 5 ─────────────────────────────────────────
B.Skyscraper = function(m)
	local glass = C(90, 140, 200)
	local frame = C(40, 50, 65)
	local tiers = { { 16, 30, 0 }, { 13, 13, 30 }, { 9, 5, 43 } }
	for _, t in ipairs(tiers) do
		local w, h, y = t[1], t[2], t[3]
		add(m, "Block", V(w, h, w), V(0, y + h / 2, 0), glass, M.Glass, { Reflectance = 0.25 })
		for yy = y + 1.5, y + h - 0.5, 2.5 do
			add(m, "Block", V(w + 0.15, 0.35, w + 0.15), V(0, yy, 0), frame, M.Metal)
		end
		for k = -1, 1 do
			local off = k * w / 3
			add(m, "Block", V(0.3, h, w + 0.2), V(off, y + h / 2, 0), frame, M.Metal)
			add(m, "Block", V(w + 0.2, h, 0.3), V(0, y + h / 2, off), frame, M.Metal)
		end
		add(m, "Block", V(w + 0.6, 0.6, w + 0.6), V(0, y + h, 0), C(200, 205, 215), M.Concrete)
	end
	add(m, "Block", V(5, 3.5, 0.3), V(0, 1.75, -8.1), C(30, 30, 35), M.Glass)
	add(m, "Cyl", V(0.5, 5, 0.5), V(0, 50.5, 0), C(180, 180, 190), M.Metal)
	neon(m, "Ball", V(0.8, 0.8, 0.8), V(0, 53.1, 0), C(255, 40, 40))
end

B.FerrisWheel = function(m)
	local center = V(0, 21, 0)
	local r = 17.5
	local white = C(245, 245, 250)
	add(m, "Block", V(7, 0.8, 22), V(0, 0.4, 0), C(150, 150, 160), M.Concrete)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			beam(m, V(sx * 2.6, 0.8, sz * 8.5), center + V(sx * 1.6, 0, 0), 0.8, C(80, 90, 110), M.Metal)
		end
	end
	add(m, "CylX", V(4.2, 2.6, 2.6), center, C(80, 90, 110), M.Metal)
	local segs = 28
	for _, x in ipairs({ -1.3, 1.3 }) do
		for k = 0, segs - 1 do
			local a = k / segs * math.pi * 2
			local pos = center + V(x, r * math.cos(a), r * math.sin(a))
			add(m, "Block", V(0.5, 0.5, 2 * math.pi * r / segs * 1.08), CFrame.new(pos) * CFrame.Angles(a, 0, 0), white, M.Metal)
		end
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			beam(m, center + V(x, 0, 0), center + V(x, r * math.cos(a), r * math.sin(a)), 0.25, white, M.Metal)
		end
	end
	local colors = { C(255, 80, 120), C(80, 180, 255), C(255, 210, 60), C(120, 220, 120), C(200, 120, 255), C(255, 150, 60) }
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		local pos = center + V(0, r * math.cos(a), r * math.sin(a))
		add(m, "CylX", V(2.8, 0.25, 0.25), pos, C(60, 60, 70), M.Metal)
		add(m, "Block", V(2.2, 2.1, 2.4), pos - V(0, 1.6, 0), colors[k % #colors + 1], M.SmoothPlastic)
		add(m, "Block", V(2.4, 0.3, 2.6), pos - V(0, 0.45, 0), C(250, 250, 250))
		neon(m, "Ball", V(0.6, 0.6, 0.6), center + V(0, (r + 0.6) * math.cos(a + 0.26), (r + 0.6) * math.sin(a + 0.26)), C(255, 240, 150))
	end
end

B.CruiseShip = function(m)
	local navy = C(30, 45, 90)
	local white = C(250, 250, 252)
	add(m, "Block", V(16, 6, 38), V(0, 3, 2), navy)
	add(m, "Wedge", V(16, 6, 7), rot(V(0, 3, -20.5), 0, 0, 180), navy)
	add(m, "Block", V(16.1, 0.5, 38.1), V(0, 1.0, 2), C(200, 40, 40))
	add(m, "Block", V(15, 3, 38), V(0, 7.5, 2), white)
	add(m, "Wedge", V(15, 3, 6), V(0, 7.5, -20), white)
	add(m, "Block", V(13, 3, 30), V(0, 10.5, 4), white)
	add(m, "Block", V(10.5, 3, 20), V(0, 13.5, 6), white)
	for _, deck in ipairs({ { 15, 7.6, 37 }, { 13, 10.6, 29 }, { 10.5, 13.6, 19 } }) do
		for _, s in ipairs({ -1, 1 }) do
			add(m, "Block", V(0.1, 1.0, deck[3]), V(s * (deck[1] / 2 + 0.03), deck[2], 2 + (38 - deck[3]) / 2 - 1), C(60, 110, 160), M.Glass, { Transparency = 0.1 })
		end
	end
	for i = 0, 5 do
		for _, s in ipairs({ -1, 1 }) do
			add(m, "Block", V(1, 0.9, 2.2), V(s * 6.8, 9.6, -6 + i * 4), C(255, 120, 30))
		end
	end
	for _, z in ipairs({ 6, 11 }) do
		add(m, "Cyl", V(3, 4, 3), V(0, 17, z), C(210, 40, 40))
		add(m, "Cyl", V(3.1, 0.8, 3.1), V(0, 18.8, z), C(25, 25, 30))
	end
	add(m, "Block", V(5, 0.3, 6), V(0, 15.1, 0), C(60, 170, 230), M.Glass, { Transparency = 0.2 })
	add(m, "Block", V(0.4, 3, 0.4), V(0, 16.5, -5), C(200, 200, 210), M.Metal)
end

B.Rocket = function(m)
	local white = C(245, 245, 250)
	add(m, "Cyl", V(4.2, 3, 4.2), V(0, 1.5, 0), C(70, 70, 80), M.Metal)
	add(m, "Cyl", V(3, 0.6, 3), V(0, 0.3, 0), C(40, 40, 45), M.Metal)
	add(m, "Cyl", V(6, 26, 6), V(0, 16, 0), white, M.Metal)
	for _, y in ipairs({ 6, 26 }) do
		add(m, "Cyl", V(6.1, 1.2, 6.1), V(0, y, 0), C(220, 40, 45), M.Metal)
	end
	add(m, "Cyl", V(6.1, 0.3, 6.1), V(0, 18, 0), C(40, 40, 45), M.Metal)
	for _, y in ipairs({ 21, 15 }) do
		add(m, "CylZ", V(1.8, 1.8, 0.4), V(0, y, -2.95), C(40, 40, 45), M.Metal)
		add(m, "CylZ", V(1.3, 1.3, 0.45), V(0, y, -3.0), C(120, 200, 255), M.Glass, { Transparency = 0.1, Reflectance = 0.4 })
	end
	cone(m, 29, 12, 3, 0.35, 10, white, M.Metal)
	neon(m, "Ball", V(0.7, 0.7, 0.7), V(0, 41.2, 0), C(255, 60, 60))
	for k = 0, 3 do
		local a = rad(k * 90 + 45)
		local dir = V(math.cos(a), 0, math.sin(a))
		local pos = dir * 3.9 + V(0, 6.5, 0)
		-- a WedgePart's tall face is +Z; lookAt(outward) puts that face against the rocket body
		add(m, "Wedge", V(0.4, 7, 3.2), CFrame.lookAt(pos, pos + dir), C(220, 40, 45), M.Metal)
	end
	add(m, "Block", V(0.1, 6, 1.5), V(3.02, 14, 0), C(40, 80, 200))
end

-- Tier 6 ─────────────────────────────────────────
local function pyramid(m, baseY, w, h, color, material, offset)
	offset = offset or V(0, 0, 0)
	for k = 0, 3 do
		local a = rad(k * 90)
		local dir = V(math.sin(a), 0, math.cos(a))
		local pos = offset + V(0, baseY + h / 2, 0) + dir * (w / 4)
		add(m, "Wedge", V(w, h, w / 2), CFrame.lookAt(pos, pos + dir), color, material)
	end
end

B.Mountain = function(m)
	local rock = C(115, 110, 108)
	pyramid(m, 0, 40, 34, rock, M.Slate)
	pyramid(m, 0, 22, 20, rock:Lerp(C(0, 0, 0), 0.08), M.Slate, V(13, 0, 9))
	pyramid(m, 0, 18, 15, rock:Lerp(C(255, 255, 255), 0.05), M.Slate, V(-12, 0, -11))
	pyramid(m, 22, 12.5, 12.6, C(248, 250, 255), M.Snow)
	pyramid(m, 13, 5.5, 7.4, C(248, 250, 255), M.Snow, V(13, 0, 9))
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		add(m, "Ball", V(4, 4, 4) * (0.7 + (i % 3) * 0.25), V(math.cos(a) * 19, 1, math.sin(a) * 19), rock:Lerp(C(0, 0, 0), 0.15), M.Slate)
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.3
		add(m, "Cyl", V(1.2, 4, 1.2), V(math.cos(a) * 21, 2, math.sin(a) * 21), C(35, 110, 60), M.SmoothPlastic)
	end
end

B.Volcano = function(m)
	local rock = C(70, 45, 40)
	local layers = 8
	for i = 0, layers - 1 do
		local t = i / (layers - 1)
		local d = 44 - 28 * t
		add(m, "Cyl", V(d, 4.02, d), V(0, 2 + i * 4, 0), rock:Lerp(C(30, 25, 25), t * 0.6), M.Basalt)
	end
	add(m, "Cyl", V(14, 1, 14), V(0, 31.5, 0), C(40, 30, 30), M.Basalt)
	local lava = neon(m, "Cyl", V(12, 0.6, 12), V(0, 31.9, 0), C(255, 110, 30))
	local smoke = Instance.new("Smoke")
	smoke.Color = C(90, 80, 80)
	smoke.Size = 12
	smoke.RiseVelocity = 12
	smoke.Opacity = 0.25
	smoke.Parent = lava
	local light = Instance.new("PointLight")
	light.Color = C(255, 120, 40)
	light.Range = 40
	light.Brightness = 3
	light.Parent = lava
	for k = 0, 4 do
		local a = rad(k * 72 + 10)
		local top = V(math.cos(a) * 6.5, 31.5, math.sin(a) * 6.5)
		local bottom = V(math.cos(a) * 20, 1.5, math.sin(a) * 20)
		local mid = (top + bottom) / 2 + V(math.cos(a), 0, math.sin(a)) * 3.5
		beam(m, top, mid, 1.4, C(255, 90, 20), M.Neon)
		beam(m, mid, bottom, 1.2, C(255, 60, 20), M.Neon)
	end
end

B.Glacier = function(m)
	local ice = C(170, 225, 255)
	local blocks = {
		{ V(30, 14, 26), V(0, 7, 0), V(0, 10, 0) },
		{ V(16, 22, 14), V(-6, 11, -4), V(5, -15, 8) },
		{ V(14, 26, 12), V(7, 13, 3), V(-6, 25, -5) },
		{ V(10, 18, 10), V(12, 9, -9), V(8, 40, 6) },
		{ V(12, 12, 16), V(-13, 6, 8), V(-4, -20, 0) },
	}
	for i, b in ipairs(blocks) do
		add(m, "Block", b[1], rot(b[2], b[3].X, b[3].Y, b[3].Z), ice:Lerp(C(255, 255, 255), (i % 3) * 0.12), i % 2 == 0 and M.Glacier or M.Ice, { Transparency = 0.05 })
	end
	add(m, "Block", V(31, 1.2, 27), rot(V(0, 14.4, 0), 0, 10, 0), C(250, 252, 255), M.Snow)
	add(m, "Block", V(15, 1.4, 12.5), rot(V(7, 26.4, 3), 0, 25, 0), C(250, 252, 255), M.Snow)
	add(m, "Block", V(34, 0.5, 30), V(0, 0.25, 0), C(80, 170, 230), M.Glass, { Transparency = 0.2 })
end

B.TheMoon = function(m)
	local r = 18
	local center = V(0, r, 0)
	add(m, "Ball", V(r * 2, r * 2, r * 2), center, C(215, 215, 205), M.Slate)
	local rng = Random.new(42)
	for _ = 1, 16 do
		local dir = V(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local d = rng:NextNumber(3, 8)
		add(m, "Ball", V(d, d, d), center + dir * (r - d * 0.32), C(160, 160, 150), M.Slate)
		add(m, "Ball", V(d * 0.75, d * 0.75, d * 0.75), center + dir * (r - d * 0.2), C(130, 130, 122), M.Slate)
	end
	local glow = Instance.new("PointLight")
	glow.Range = 50
	glow.Brightness = 1
	glow.Color = C(220, 230, 255)
	glow.Parent = m:FindFirstChildWhichIsA("BasePart")
end

-- Exclusives ─────────────────────────────────────
B.HugeTeddy = function(m)
	local fur = C(185, 125, 75)
	local light = C(235, 200, 160)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ball", V(1.8, 1.8, 1.8), V(s * 1.1, 0.9, -0.6), fur, M.Fabric)
		add(m, "Ball", V(1.0, 1.0, 1.0), V(s * 1.1, 0.9, -1.4), light, M.Fabric)
		add(m, "Ball", V(1.4, 1.4, 1.4), V(s * 2.0, 3.1, -0.4), fur, M.Fabric)
		add(m, "Ball", V(1.1, 1.1, 1.1), V(s * 1.3, 6.6, 0), fur, M.Fabric)
		add(m, "Ball", V(0.6, 0.6, 0.6), V(s * 1.3, 6.6, -0.35), light, M.Fabric)
		add(m, "Ball", V(0.35, 0.35, 0.35), V(s * 0.5, 5.6, -1.25), C(20, 20, 25), M.SmoothPlastic, { Reflectance = 0.3 })
	end
	add(m, "Ball", V(4, 4, 4), V(0, 2.8, 0), fur, M.Fabric)
	add(m, "Ball", V(2.8, 2.8, 2.8), V(0, 2.6, -0.8), light, M.Fabric)
	add(m, "Ball", V(3.2, 3.2, 3.2), V(0, 5.4, 0), fur, M.Fabric)
	add(m, "Ball", V(1.3, 1.1, 1.1), V(0, 5.0, -1.3), light, M.Fabric)
	add(m, "Ball", V(0.5, 0.4, 0.4), V(0, 5.25, -1.85), C(40, 25, 20))
	add(m, "Block", V(0.9, 0.9, 0.4), V(0, 4.0, -1.55), C(220, 40, 60), M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Wedge", V(0.4, 0.9, 0.9), rot(V(s * 0.65, 4.0, -1.55), 0, s * 90, 0), C(220, 40, 60), M.Fabric)
	end
end

B.HugeCrystal = function(m)
	add(m, "Cyl", V(4.5, 1, 4.5), V(0, 0.5, 0), C(60, 55, 70), M.Slate)
	local crystal = C(120, 255, 240)
	local pieces = {
		{ V(1.4, 7, 1.4), V(0, 4.2, 0), V(0, 45, 0) },
		{ V(1.0, 4.5, 1.0), V(1.2, 2.9, 0.5), V(0, 20, -22) },
		{ V(1.0, 5, 1.0), V(-1.1, 3.1, 0.4), V(10, 60, 20) },
		{ V(0.8, 3.5, 0.8), V(0.3, 2.4, -1.3), V(-25, 10, 5) },
		{ V(0.8, 3.2, 0.8), V(-0.4, 2.2, 1.4), V(25, 30, -5) },
	}
	for _, p in ipairs(pieces) do
		local part = add(m, "Block", p[1], rot(p[2], p[3].X, p[3].Y, p[3].Z), crystal, M.Glass, { Transparency = 0.15, Reflectance = 0.3 })
		local tipPos = (part.CFrame * CFrame.new(0, p[1].Y / 2 + p[1].X * 0.35, 0)).Position
		add(m, "Block", V(p[1].X * 0.7, p[1].X * 0.7, p[1].X * 0.7), CFrame.new(tipPos) * (part.CFrame - part.CFrame.Position) * CFrame.Angles(0, 0, rad(45)), crystal, M.Glass, { Transparency = 0.15, Reflectance = 0.3 })
		neon(m, "Block", p[1] * V(0.35, 0.85, 0.35), part.CFrame, C(200, 255, 250))
	end
	local light = Instance.new("PointLight")
	light.Color = crystal
	light.Range = 18
	light.Brightness = 2
	light.Parent = m:FindFirstChildWhichIsA("BasePart")
end

B.HugeDragon = function(m)
	local green = C(55, 175, 85)
	local belly = C(235, 220, 140)
	add(m, "Block", V(4, 3.4, 6), V(0, 3.3, 0.5), green, M.Slate)
	add(m, "Block", V(3, 0.4, 5.2), V(0, 1.6, 0.5), belly, M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1.5, 2.5 }) do
			add(m, "Block", V(1.1, 2.2, 1.2), V(s * 1.6, 1.1, z), green, M.Slate)
			for c = -1, 1 do
				add(m, "Wedge", V(0.25, 0.3, 0.5), V(s * 1.6 + c * 0.35, 0.15, z - 0.8), C(240, 240, 230))
			end
		end
		add(m, "Wedge", V(0.2, 4.5, 5.5), rot(V(s * 3.2, 5.6, 1), 0, 0, s * -35), green:Lerp(C(0, 0, 0), 0.15), M.Fabric)
		add(m, "Wedge", V(0.4, 1.0, 0.5), rot(V(s * 0.6, 8.0, -3.7), -30, 0, 0), C(240, 240, 230))
		neon(m, "Ball", V(0.45, 0.45, 0.45), V(s * 0.65, 7.35, -4.55), C(255, 220, 40))
	end
	beam(m, V(0, 4.2, -2.0), V(0, 6.6, -3.6), 1.6, green, M.Slate)
	add(m, "Block", V(2.2, 1.8, 2.6), V(0, 7.0, -4.2), green, M.Slate)
	add(m, "Block", V(1.6, 1.0, 1.8), V(0, 6.6, -5.6), green, M.Slate)
	add(m, "Block", V(1.4, 0.3, 1.6), V(0, 6.0, -5.6), C(170, 40, 40))
	local tail = { V(0, 3.5, 3.5), V(0, 3.0, 5.5), V(0, 2.4, 7.2), V(0.6, 1.8, 8.6), V(1.4, 1.4, 9.6) }
	for i = 1, #tail - 1 do
		beam(m, tail[i], tail[i + 1], 1.4 - i * 0.22, green, M.Slate)
	end
	add(m, "Wedge", V(0.2, 1.2, 1.4), V(1.4, 2.0, 9.9), C(220, 60, 60))
	for i = 0, 4 do
		add(m, "Wedge", V(0.25, 0.9, 0.9), V(0, 5.4, -1.5 + i * 1.3), C(220, 60, 60))
	end
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 4
	fire.Parent = m:FindFirstChildWhichIsA("BasePart")
end

-- ── public ───────────────────────────────────────────────────────────
function ObjectModels.Has(id)
	return B[id] ~= nil
end

-- Returns a Model (PrimaryPart set, standing on y=0) or nil if there is no builder for `id`.
function ObjectModels.Build(id)
	local builder = B[id]
	if not builder then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = id
	builder(model)
	-- the biggest part becomes the PrimaryPart (used for labels, lights, sparkles)
	local best, bestVol = nil, -1
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			local vol = p.Size.X * p.Size.Y * p.Size.Z
			if vol > bestVol then
				best, bestVol = p, vol
			end
		end
	end
	model.PrimaryPart = best
	return model
end

return ObjectModels
