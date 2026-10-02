--[[
	📍 LOCATION: ReplicatedStorage > Shared > ObjectModels (ModuleScript)
	(Shared: the server builds world objects with it, the client builds 3D previews for the menus.)

	Realistic, detailed models for EVERY object in ObjectConfig, built from parts with Roblox's
	materials (Metal, Glass, Rubber, Leather, Plaster, RoofShingles, Rock, Snow, Neon, ...), so no
	uploaded meshes or images are needed. Curves use sphere meshes (ellipsoids), smooth cones,
	rounded boxes and rings; small print (number plates, signs) uses SurfaceGui text.

	Each builder creates the object standing on y = 0, centered on x/z, front facing -Z.
	ModelFactory scales it to the size in ObjectConfig and strips details too small to see
	(ModelFactory.Simplify) when it is shown tiny on a pedestal.

	Want your own mesh instead? Put a Model named after the object id in
	ReplicatedStorage (or ServerStorage) > ShrinkableTemplates and it takes priority over these.
]]

local ObjectModels = {}

local C = Color3.fromRGB
local V = Vector3.new
local M = Enum.Material
local rad = math.rad

-- ── builder helpers ─────────────────────────────────────────────────
-- Newer Roblox materials (Rubber, Leather, Plaster, ...) with a safe fallback on older clients.
local function mat(name, fallback)
	local ok, m = pcall(function()
		return Enum.Material[name]
	end)
	return ok and m or fallback
end
local RUBBER = mat("Rubber", M.SmoothPlastic)
local LEATHER = mat("Leather", M.Fabric)
local PLASTER = mat("Plaster", M.SmoothPlastic)
local ROOF = mat("RoofShingles", M.Slate)
local ROCK = mat("Rock", M.Slate)

-- shape: "Block" | "Ball" (sphere) | "Ell" (ellipsoid, any size) | "Cyl" (vertical, size = (d, h, d)) |
--        "CylX" (size = (len, d, d)) | "CylZ" (size = (d, d, len)) | "Wedge" | "Corner"
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
	if shape == "Ball" and (size.X ~= size.Y or size.Y ~= size.Z) then
		shape = "Ell" -- a Ball part is always round; stretched spheres need a mesh
	end
	if shape == "Ball" then
		p.Shape = Enum.PartType.Ball
		p.Size = size
		p.CFrame = cf
	elseif shape == "Ell" then
		p.Size = size
		p.CFrame = cf
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
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

-- A block stretched between two points (bars, legs, frames).
local function beam(m, a, b, thick, color, material)
	local len = (b - a).Magnitude
	return add(m, "Block", V(thick, thick, len), CFrame.lookAt((a + b) / 2, b), color, material)
end

-- A round rod (cylinder) between two points.
local function rod(m, a, b, d, color, material, extra)
	local len = (b - a).Magnitude
	return add(m, "CylX", V(len, d, d), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, rad(90), 0), color, material, extra)
end

-- Smooth cone / frustum from many thin slices (radius r0 at the bottom → r1 at the top).
local function cone(m, baseY, height, r0, r1, steps, color, material, x, z)
	x, z = x or 0, z or 0
	steps = math.max(steps or 0, math.floor(height * 2.5), 10)
	local h = height / steps
	local parts = {}
	for i = 0, steps - 1 do
		local t = (i + 0.5) / steps
		local r = r0 + (r1 - r0) * t
		table.insert(parts, add(m, "Cyl", V(r * 2, h + 0.02, r * 2), V(x, baseY + h * (i + 0.5), z), color, material))
	end
	return parts
end

-- Ring (torus) made of rods: center CFrame's X axis is the ring's axis.
local function ring(m, cf, radius, thickness, segments, color, material)
	segments = segments or 16
	local chord = 2 * radius * math.sin(math.pi / segments)
	for i = 0, segments - 1 do
		local a = (i + 0.5) / segments * math.pi * 2
		add(m, "Block", V(thickness, thickness, chord + thickness * 0.35), cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, radius * math.cos(math.pi / segments), 0), color, material)
	end
end

-- Box with rounded vertical edges (soft, manufactured look).
local function rbox(m, size, cf, radius, color, material, extra)
	if typeof(cf) == "Vector3" then
		cf = CFrame.new(cf)
	end
	radius = math.min(radius, size.X / 2, size.Z / 2)
	local core = add(m, "Block", V(size.X - radius * 2, size.Y, size.Z), cf, color, material, extra)
	add(m, "Block", V(size.X, size.Y, size.Z - radius * 2), cf, color, material, extra)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			add(m, "Cyl", V(radius * 2, size.Y, radius * 2), cf * CFrame.new(sx * (size.X / 2 - radius), 0, sz * (size.Z / 2 - radius)), color, material, extra)
		end
	end
	return core
end

-- Realistic wheel: rubber tyre with rounded sidewalls, metal rim, hub and spokes. Axis along X.
local function wheel(m, pos, d, width, tire, hub)
	local cf = typeof(pos) == "CFrame" and pos or CFrame.new(pos)
	tire = tire or C(28, 28, 30)
	hub = hub or C(200, 202, 210)
	add(m, "CylX", V(width * 0.8, d, d), cf, tire, RUBBER)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ell", V(width * 0.35, d * 0.98, d * 0.98), cf * CFrame.new(s * width * 0.38, 0, 0), tire, RUBBER)
	end
	add(m, "CylX", V(width + 0.04, d * 0.62, d * 0.62), cf, hub, M.Metal, { Reflectance = 0.15 })
	add(m, "CylX", V(width + 0.06, d * 0.5, d * 0.5), cf, hub:Lerp(C(0, 0, 0), 0.45), M.Metal)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		add(m, "Block", V(width + 0.08, d * 0.07, d * 0.24), cf * CFrame.Angles(a, 0, 0) * CFrame.new(0, 0, d * 0.13), hub, M.Metal)
	end
	add(m, "CylX", V(width + 0.1, d * 0.14, d * 0.14), cf, hub:Lerp(C(255, 255, 255), 0.3), M.Metal)
end

-- Window: thin frame + tinted glass + mullion.
local function window(m, cf, w, h, frame)
	add(m, "Block", V(w + 0.3, h + 0.3, 0.12), cf, frame or C(255, 255, 255))
	add(m, "Block", V(w, h, 0.18), cf, C(120, 160, 190), M.Glass, { Transparency = 0.25, Reflectance = 0.35 })
	add(m, "Block", V(0.12, h, 0.2), cf, frame or C(255, 255, 255))
end

-- Tinted glass pane.
local function glass(m, size, cf, tint, transparency)
	return add(m, "Block", size, cf, tint or C(70, 95, 120), M.Glass, { Transparency = transparency or 0.3, Reflectance = 0.4 })
end

local function neon(m, shape, size, cf, color)
	return add(m, shape, size, cf, color, M.Neon)
end

-- Printed text on a part's face (labels, signs, number plates).
local function label(part, face, text, color, bg, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = bg and 0 or 1
	if bg then
		t.BackgroundColor3 = bg
	end
	t.Font = font or Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = color or C(255, 255, 255)
	t.Text = text
	t.Parent = gui
	return t
end

-- ── builders ─────────────────────────────────────────────────────────
local B = {}

-- Tier 1 ─────────────────────────────────────────
B.SodaCan = function(m)
	local red = C(200, 20, 32)
	local alu = C(205, 208, 214)
	-- body with a slightly narrower bottom and a tapered neck, like a real 330ml can
	add(m, "Cyl", V(1.3, 0.12, 1.3), V(0, 0.06, 0), alu, M.Metal, { Reflectance = 0.25 })
	add(m, "Cyl", V(1.38, 0.2, 1.38), V(0, 0.2, 0), alu, M.Metal, { Reflectance = 0.25 })
	add(m, "Cyl", V(1.44, 1.86, 1.44), V(0, 1.23, 0), red, M.SmoothPlastic, { Reflectance = 0.18 })
	add(m, "Cyl", V(1.45, 0.42, 1.45), V(0, 1.15, 0), C(245, 245, 245), M.SmoothPlastic, { Reflectance = 0.12 })
	add(m, "Cyl", V(1.452, 0.08, 1.452), V(0, 1.4, 0), C(20, 20, 24), M.SmoothPlastic)
	add(m, "Cyl", V(1.452, 0.05, 1.452), V(0, 0.92, 0), C(230, 180, 40), M.SmoothPlastic)
	add(m, "Cyl", V(1.34, 0.12, 1.34), V(0, 2.22, 0), alu, M.Metal, { Reflectance = 0.25 })
	add(m, "Cyl", V(1.2, 0.1, 1.2), V(0, 2.32, 0), alu, M.Metal, { Reflectance = 0.25 })
	add(m, "Cyl", V(1.24, 0.06, 1.24), V(0, 2.4, 0), alu:Lerp(C(255, 255, 255), 0.2), M.Metal, { Reflectance = 0.3 })
	add(m, "Cyl", V(1.04, 0.03, 1.04), V(0, 2.42, 0), alu:Lerp(C(0, 0, 0), 0.08), M.Metal)
	-- pull tab and drinking hole
	add(m, "Block", V(0.26, 0.03, 0.46), V(0, 2.45, 0.12), alu:Lerp(C(255, 255, 255), 0.3), M.Metal)
	add(m, "Block", V(0.28, 0.02, 0.22), V(0, 2.44, -0.28), C(40, 40, 45))
end

B.TrafficCone = function(m)
	local orange = C(245, 95, 20)
	add(m, "Block", V(2.3, 0.2, 2.3), V(0, 0.1, 0), C(35, 35, 38), RUBBER)
	add(m, "Block", V(1.9, 0.08, 1.9), V(0, 0.24, 0), C(45, 45, 48), RUBBER)
	cone(m, 0.24, 2.9, 0.82, 0.16, 26, orange, M.SmoothPlastic)
	-- two reflective sleeves
	for _, band in ipairs({ { 1.05, 0.34 }, { 1.95, 0.26 } }) do
		local y, h = band[1], band[2]
		local r = 0.82 + (0.16 - 0.82) * ((y - 0.24) / 2.9)
		add(m, "Cyl", V(r * 2 + 0.03, h, r * 2 + 0.03), V(0, y, 0), C(240, 242, 245), M.SmoothPlastic, { Reflectance = 0.35 })
	end
	add(m, "Cyl", V(0.34, 0.06, 0.34), V(0, 3.15, 0), orange:Lerp(C(0, 0, 0), 0.2))
end

B.Mailbox = function(m)
	local blue = C(30, 70, 165)
	-- concrete footing + wooden post
	add(m, "Block", V(1.1, 0.3, 1.1), V(0, 0.15, 0), C(150, 150, 150), M.Concrete)
	add(m, "Block", V(0.4, 2.7, 0.4), V(0, 1.6, 0), C(120, 85, 55), M.Wood)
	add(m, "Block", V(0.9, 0.18, 1.9), V(0, 2.98, 0), C(110, 78, 50), M.Wood)
	-- rural mailbox: box with a half-round top
	add(m, "Block", V(1.1, 0.75, 2.0), V(0, 3.45, 0), blue, M.SmoothPlastic, { Reflectance = 0.1 })
	add(m, "CylZ", V(1.1, 1.1, 2.0), V(0, 3.83, 0), blue, M.SmoothPlastic, { Reflectance = 0.1 })
	-- front door with handle
	add(m, "Block", V(1.12, 1.2, 0.06), V(0, 3.62, -1.02), blue:Lerp(C(0, 0, 0), 0.15))
	add(m, "Block", V(0.3, 0.1, 0.12), V(0, 3.75, -1.09), C(200, 200, 205), M.Metal)
	-- red flag (raised)
	add(m, "Block", V(0.06, 1.0, 0.12), V(0.6, 4.0, 0.3), C(200, 30, 30), M.Metal)
	add(m, "Block", V(0.06, 0.32, 0.5), V(0.6, 4.35, 0.08), C(220, 35, 35), M.Metal)
	add(m, "CylX", V(0.08, 0.16, 0.16), V(0.63, 3.55, 0.3), C(170, 170, 175), M.Metal)
	-- house number
	local plate = add(m, "Block", V(0.06, 0.32, 0.9), V(-0.58, 3.35, 0), C(245, 245, 240))
	label(plate, Enum.NormalId.Left, "42", C(20, 20, 20))
end

B.FireHydrant = function(m)
	local red = C(190, 25, 25)
	local dark = red:Lerp(C(0, 0, 0), 0.25)
	add(m, "Cyl", V(1.7, 0.25, 1.7), V(0, 0.12, 0), dark, M.Metal)
	for i = 0, 5 do -- flange bolts
		local a = i / 6 * math.pi * 2
		add(m, "Cyl", V(0.16, 0.12, 0.16), V(math.cos(a) * 0.72, 0.3, math.sin(a) * 0.72), C(150, 150, 150), M.Metal)
	end
	add(m, "Cyl", V(1.25, 1.9, 1.25), V(0, 1.2, 0), red, M.Metal, { Reflectance = 0.08 })
	add(m, "Cyl", V(1.45, 0.22, 1.45), V(0, 2.2, 0), dark, M.Metal)
	add(m, "Ell", V(1.3, 0.85, 1.3), V(0, 2.4, 0), red, M.Metal, { Reflectance = 0.08 })
	-- pentagon operating nut on top
	add(m, "Cyl", V(0.4, 0.3, 0.4), V(0, 2.9, 0), C(215, 175, 40), M.Metal)
	-- side nozzles + chains
	for _, s in ipairs({ -1, 1 }) do
		add(m, "CylX", V(0.45, 0.62, 0.62), V(s * 0.8, 1.6, 0), red, M.Metal)
		add(m, "CylX", V(0.2, 0.72, 0.72), V(s * 1.05, 1.6, 0), C(215, 175, 40), M.Metal)
		add(m, "CylX", V(0.08, 0.3, 0.3), V(s * 1.17, 1.6, 0), C(180, 145, 30), M.Metal)
	end
	-- big front pumper nozzle
	add(m, "CylZ", V(0.82, 0.82, 0.5), V(0, 1.35, -0.78), red, M.Metal)
	add(m, "CylZ", V(0.94, 0.94, 0.18), V(0, 1.35, -1.05), C(215, 175, 40), M.Metal)
end

B.GardenGnome = function(m)
	local skin = C(240, 195, 160)
	local blue = C(45, 85, 165)
	local red = C(195, 35, 40)
	-- grassy base
	add(m, "Cyl", V(1.9, 0.3, 1.9), V(0, 0.15, 0), C(95, 140, 60), M.Grass)
	-- boots
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ell", V(0.5, 0.35, 0.75), V(s * 0.3, 0.45, -0.12), C(70, 45, 30), LEATHER)
	end
	-- round body (blue coat) + belt
	add(m, "Ell", V(1.35, 1.35, 1.2), V(0, 1.2, 0), blue, M.SmoothPlastic)
	add(m, "Cyl", V(1.3, 0.16, 1.18), V(0, 1.22, 0), C(50, 35, 25), LEATHER)
	add(m, "Block", V(0.26, 0.2, 0.06), V(0, 1.22, -0.6), C(230, 190, 60), M.Metal)
	-- arms holding a little shovel
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ell", V(0.36, 0.75, 0.36), rot(V(s * 0.66, 1.35, -0.15), 20, 0, s * 15), blue)
		add(m, "Ball", V(0.3, 0.3, 0.3), V(s * 0.72, 1.0, -0.35), skin)
	end
	rod(m, V(0.72, 0.6, -0.4), V(0.72, 1.7, -0.4), 0.08, C(130, 90, 55), M.Wood)
	add(m, "Block", V(0.26, 0.34, 0.04), V(0.72, 0.5, -0.4), C(160, 160, 165), M.Metal)
	-- head, rosy nose, big white beard
	add(m, "Ball", V(0.85, 0.85, 0.85), V(0, 2.1, -0.05), skin)
	add(m, "Ball", V(0.28, 0.28, 0.28), V(0, 2.05, -0.48), C(235, 140, 120))
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ball", V(0.1, 0.1, 0.1), V(s * 0.17, 2.22, -0.4), C(30, 30, 40))
	end
	add(m, "Ell", V(0.9, 0.95, 0.5), V(0, 1.72, -0.3), C(245, 245, 245), M.Fabric)
	add(m, "Ell", V(0.7, 0.18, 0.2), V(0, 1.98, -0.46), C(245, 245, 245), M.Fabric)
	-- pointy hat (smooth cone, slightly bent)
	add(m, "Cyl", V(0.95, 0.14, 0.95), V(0, 2.42, 0), red)
	cone(m, 2.45, 1.25, 0.46, 0.04, 22, red, M.SmoothPlastic)
end

-- Tier 2 ─────────────────────────────────────────
B.Bench = function(m)
	local wood = C(150, 100, 60)
	local iron = C(40, 42, 45)
	-- cast-iron side frames
	for _, x in ipairs({ -2.9, 2.9 }) do
		beam(m, V(x, 0, -0.9), V(x, 1.55, -0.6), 0.22, iron, M.Metal)
		beam(m, V(x, 0, 0.9), V(x, 1.55, 0.7), 0.22, iron, M.Metal)
		beam(m, V(x, 1.55, -0.95), V(x, 1.55, 0.95), 0.2, iron, M.Metal)
		beam(m, V(x, 1.55, 0.85), V(x, 3.35, 1.2), 0.2, iron, M.Metal)
		-- curly armrest
		beam(m, V(x, 2.2, -0.9), V(x, 2.25, 0.8), 0.2, iron, M.Metal)
		add(m, "Ball", V(0.32, 0.32, 0.32), V(x, 2.2, -0.95), iron, M.Metal)
		beam(m, V(x, 1.6, -0.75), V(x, 2.2, -0.88), 0.16, iron, M.Metal)
	end
	-- seat slats with gaps
	for i = 0, 3 do
		add(m, "Block", V(6.4, 0.16, 0.4), V(0, 1.7, -0.75 + i * 0.5), wood:Lerp(C(0, 0, 0), (i % 2) * 0.08), M.Wood)
	end
	-- backrest slats (tilted)
	for i = 0, 2 do
		local y = 2.15 + i * 0.42
		add(m, "Block", V(6.4, 0.32, 0.12), rot(V(0, y, 1.0 + (y - 1.6) * 0.2), -12, 0, 0), wood:Lerp(C(0, 0, 0), (i % 2) * 0.08), M.Wood)
	end
	-- little brass plaque
	local plaque = add(m, "Block", V(0.8, 0.22, 0.04), rot(V(0, 2.75, 1.08), -12, 0, 0), C(200, 160, 70), M.Metal)
	label(plaque, Enum.NormalId.Front, "IN LOVING MEMORY", C(60, 40, 20))
end

B.TrashBin = function(m)
	local green = C(40, 80, 50)
	-- wheelie bin: tapered body, lid, wheels, handle
	add(m, "Block", V(2.5, 0.3, 2.6), V(0, 0.45, 0.1), green:Lerp(C(0, 0, 0), 0.2))
	for i = 0, 7 do
		local t = i / 7
		add(m, "Block", V(2.5 + t * 0.35, 3.6 / 8 + 0.02, 2.6 + t * 0.35), V(0, 0.6 + 3.6 / 8 * (i + 0.5), 0.1), green, M.SmoothPlastic)
	end
	add(m, "Block", V(3.1, 0.22, 3.15), V(0, 4.3, 0.12), green:Lerp(C(255, 255, 255), 0.05))
	add(m, "Block", V(3.1, 0.3, 0.2), rot(V(0, 4.25, -1.5), 0, 0, 0), green:Lerp(C(0, 0, 0), 0.1))
	-- handle at the back
	rod(m, V(-1.2, 4.05, 1.85), V(1.2, 4.05, 1.85), 0.18, C(30, 30, 30))
	for _, x in ipairs({ -1.2, 1.2 }) do
		beam(m, V(x, 4.05, 1.85), V(x, 3.8, 1.5), 0.16, green)
	end
	wheel(m, V(-1.25, 0.42, 1.25), 0.85, 0.3)
	wheel(m, V(1.25, 0.42, 1.25), 0.85, 0.3)
	rod(m, V(-1.3, 0.42, 1.25), V(1.3, 0.42, 1.25), 0.12, C(90, 90, 95), M.Metal)
	-- white number stencil
	local face = add(m, "Block", V(1.4, 0.7, 0.04), V(0, 2.6, -1.42), green)
	label(face, Enum.NormalId.Front, "♻ 7", C(230, 230, 230))
end

B.Bike = function(m)
	local frame = C(20, 140, 200)
	local black = C(25, 25, 28)
	local chrome = C(200, 202, 208)
	local rear, front = V(0, 1.35, 2.05), V(0, 1.35, -2.05)
	-- wheels: thin tyre ring + spokes
	for _, c in ipairs({ rear, front }) do
		ring(m, CFrame.new(c), 1.27, 0.2, 16, black, RUBBER)
		ring(m, CFrame.new(c), 1.12, 0.1, 16, chrome, M.Metal)
		for i = 0, 7 do
			local a = i / 8 * math.pi
			add(m, "Block", V(0.03, 0.03, 2.3), CFrame.new(c) * CFrame.Angles(a, 0, 0), chrome, M.Metal)
		end
		add(m, "CylX", V(0.3, 0.3, 0.3), c, chrome, M.Metal)
	end
	-- frame tubes (diamond frame)
	local bb = V(0, 1.15, 0.2) -- bottom bracket
	local seatTop = V(0, 3.0, 0.75)
	local headTop, headBottom = V(0, 3.05, -1.45), V(0, 2.45, -1.6)
	rod(m, bb, seatTop, 0.17, frame, M.SmoothPlastic, { Reflectance = 0.15 })
	rod(m, bb, headBottom, 0.2, frame, M.SmoothPlastic, { Reflectance = 0.15 })
	rod(m, seatTop, headTop, 0.17, frame, M.SmoothPlastic, { Reflectance = 0.15 })
	rod(m, bb, rear, 0.12, frame)
	rod(m, seatTop, rear, 0.12, frame)
	rod(m, headTop, headBottom, 0.22, frame)
	rod(m, headBottom, front, 0.12, chrome, M.Metal)
	-- seat, post, handlebar
	rod(m, seatTop, seatTop + V(0, 0.45, 0.1), 0.1, chrome, M.Metal)
	add(m, "Ell", V(0.45, 0.16, 0.95), V(0, 3.52, 0.85), black, LEATHER)
	rod(m, headTop, headTop + V(0, 0.4, 0.2), 0.12, chrome, M.Metal)
	rod(m, headTop + V(-0.85, 0.42, 0.25), headTop + V(0.85, 0.42, 0.25), 0.1, chrome, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "CylX", V(0.4, 0.16, 0.16), headTop + V(s * 0.75, 0.42, 0.25), black, RUBBER)
	end
	-- crank, chainring, pedals, chain
	add(m, "CylX", V(0.06, 0.75, 0.75), bb + V(0.2, 0, 0), C(80, 80, 85), M.Metal)
	rod(m, bb + V(0.25, 0, 0) + V(0, 0.45, 0.2), bb + V(0.25, 0, 0) - V(0, 0.45, 0.2), 0.08, chrome, M.Metal)
	add(m, "Block", V(0.4, 0.08, 0.25), bb + V(0.45, 0.45, 0.2), black)
	beam(m, bb + V(0.2, 0.35, 0), rear + V(0.2, 0.15, 0), 0.04, C(70, 70, 75), M.Metal)
	beam(m, bb + V(0.2, -0.35, 0), rear + V(0.2, -0.15, 0), 0.04, C(70, 70, 75), M.Metal)
	-- fenders and a bell
	add(m, "Block", V(0.4, 0.06, 1.2), rot(rear + V(0, 1.45, 0.2), 15, 0, 0), frame)
	add(m, "Ball", V(0.22, 0.22, 0.22), headTop + V(-0.55, 0.55, 0.25), chrome, M.Metal)
end

B.VendingMachine = function(m)
	local body = C(200, 25, 45)
	-- cabinet with rounded edges, dark side panels
	rbox(m, V(3.8, 6.6, 2.3), V(0, 3.4, 0.25), 0.25, body, M.SmoothPlastic, { Reflectance = 0.08 })
	-- front frame around the recessed drinks window
	add(m, "Block", V(3.8, 1.5, 0.5), V(0, 0.95, -1.1), body)
	add(m, "Block", V(3.8, 0.75, 0.5), V(0, 6.33, -1.1), body)
	add(m, "Block", V(0.2, 4.6, 0.5), V(-1.8, 4.0, -1.1), body)
	add(m, "Block", V(1.15, 4.6, 0.5), V(1.33, 4.0, -1.1), body)
	add(m, "Block", V(3.9, 0.2, 2.9), V(0, 0.1, 0), C(40, 40, 45), M.Metal)
	add(m, "Block", V(3.6, 0.5, 2.6), V(0, 6.95, 0), body:Lerp(C(0, 0, 0), 0.15))
	-- big glass front with shelves of drinks
	glass(m, V(2.4, 4.5, 0.08), V(-0.55, 4.0, -1.42), C(170, 200, 220), 0.7)
	add(m, "Block", V(2.6, 4.6, 0.04), V(-0.55, 4.0, -0.9), C(25, 25, 30))
	neon(m, "Block", V(2.3, 0.08, 0.08), V(-0.55, 6.15, -1.25), C(230, 240, 255))
	local colors = { C(220, 40, 40), C(30, 120, 220), C(250, 200, 40), C(40, 170, 80), C(240, 240, 245) }
	for row = 0, 4 do
		add(m, "Block", V(2.5, 0.06, 0.45), V(-0.55, 2.0 + row * 0.85, -1.12), C(150, 150, 155), M.Metal)
		for col = 0, 4 do
			add(m, "Cyl", V(0.32, 0.55, 0.32), V(-1.4 + col * 0.43, 2.32 + row * 0.85, -1.12), colors[(row + col) % 5 + 1], M.SmoothPlastic, { Reflectance = 0.2 })
		end
	end
	-- control panel: keypad, coin slot, display
	add(m, "Block", V(1.0, 4.5, 0.06), V(1.3, 4.0, -1.42), C(35, 35, 40))
	local disp = neon(m, "Block", V(0.7, 0.3, 0.05), V(1.3, 5.7, -1.46), C(120, 255, 140))
	label(disp, Enum.NormalId.Front, "$1.50", C(10, 60, 20), nil, Enum.Font.Code)
	for r = 0, 3 do
		for c = 0, 2 do
			add(m, "Block", V(0.17, 0.17, 0.05), V(1.12 + c * 0.2, 4.9 - r * 0.22, -1.46), C(210, 210, 215), M.Metal)
		end
	end
	add(m, "Block", V(0.08, 0.35, 0.05), V(1.3, 3.8, -1.46), C(10, 10, 10))
	-- pickup flap
	add(m, "Block", V(2.6, 0.8, 0.1), V(-0.3, 1.0, -1.42), C(25, 25, 28))
	add(m, "Block", V(2.4, 0.6, 0.05), V(-0.3, 1.0, -1.48), C(60, 60, 66), M.Glass, { Transparency = 0.3 })
	-- brand header
	local header = neon(m, "Block", V(3.4, 0.55, 0.06), V(0, 6.55, -1.43), C(255, 245, 230))
	label(header, Enum.NormalId.Front, "ICE COLD", C(200, 25, 45))
end

B.ArcadeCabinet = function(m)
	local purple = C(70, 35, 140)
	local black = C(20, 20, 25)
	-- side panels with the classic profile
	for _, x in ipairs({ -1.6, 1.6 }) do
		add(m, "Block", V(0.15, 4.0, 3.0), V(x, 2.0, 0.2), purple, M.SmoothPlastic)
		add(m, "Block", V(0.15, 2.2, 2.2), V(x, 5.1, 0.6), purple, M.SmoothPlastic)
		add(m, "Wedge", V(0.15, 1.0, 0.8), rot(V(x, 4.5, -0.9), 0, 180, 180), purple)
		neon(m, "Block", V(0.17, 6.2, 0.06), V(x, 3.1, -1.25), C(0, 230, 255))
	end
	add(m, "Block", V(3.1, 6.2, 2.0), V(0, 3.1, 0.75), black)
	-- coin door
	add(m, "Block", V(1.4, 1.6, 0.08), V(0, 1.3, -0.25), C(30, 30, 36), M.Metal)
	for _, x in ipairs({ -0.3, 0.3 }) do
		neon(m, "Block", V(0.18, 0.32, 0.05), V(x, 1.6, -0.3), C(255, 160, 40))
	end
	-- control deck: joystick + buttons
	add(m, "Block", V(3.1, 0.3, 1.1), rot(V(0, 3.6, -0.75), -12, 0, 0), C(30, 30, 35))
	rod(m, V(-0.8, 3.75, -0.85), V(-0.8, 4.15, -0.85), 0.1, C(40, 40, 40), M.Metal)
	add(m, "Ball", V(0.32, 0.32, 0.32), V(-0.8, 4.2, -0.85), C(220, 30, 30))
	local buttonColors = { C(255, 60, 60), C(60, 200, 255), C(255, 220, 40), C(80, 230, 80) }
	for i, col in ipairs(buttonColors) do
		add(m, "Cyl", V(0.24, 0.12, 0.24), V(0.05 + (i - 1) * 0.35, 3.82, -0.8 + (i % 2) * 0.2), col, M.SmoothPlastic, { Reflectance = 0.2 })
	end
	-- angled CRT screen with glow + bezel
	add(m, "Block", V(3.0, 2.2, 0.15), rot(V(0, 4.85, -0.25), -15, 0, 0), C(15, 15, 18))
	local screen = neon(m, "Block", V(2.4, 1.75, 0.06), rot(V(0, 4.87, -0.34), -15, 0, 0), C(40, 120, 255))
	label(screen, Enum.NormalId.Front, "INSERT COIN", C(255, 255, 120), nil, Enum.Font.Arcade)
	-- lit marquee on top
	add(m, "Block", V(3.3, 0.9, 0.9), V(0, 6.55, 0.15), black)
	local marquee = neon(m, "Block", V(3.0, 0.7, 0.06), V(0, 6.55, -0.33), C(255, 80, 200))
	label(marquee, Enum.NormalId.Front, "SPACE BLASTER", C(255, 255, 255), nil, Enum.Font.Arcade)
	add(m, "Block", V(3.1, 0.15, 2.1), V(0, 7.07, 0.6), purple)
end

-- Tier 3 ─────────────────────────────────────────
B.Car = function(m)
	B._car(m, {
		Paint = C(30, 90, 170),
		Length = 9.2,
		Width = 3.8,
		BodyH = 1.25,
		BodyY = 0.55,
		CabinZ = 0.45,
		CabinLen = 3.1,
		CabinH = 1.1,
		Wheel = 1.75,
		WheelZ = 2.95,
	})
end

B.Tree = function(m)
	local bark = C(105, 75, 50)
	local leafy = mat("LeafyGrass", M.Grass)
	-- tapered trunk with a flared base and roots
	cone(m, 0, 9.5, 1.1, 0.55, 16, bark, M.Wood)
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + 0.3
		rod(m, V(0, 0.6, 0), V(math.cos(a) * 1.7, 0.05, math.sin(a) * 1.7), 0.45, bark, M.Wood)
	end
	-- main branches
	local tips = {}
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local from = V(0, 6 + (i % 3) * 1.2, 0)
		local to = V(math.cos(a) * 3.4, 9.5 + (i % 2) * 1.6, math.sin(a) * 3.4)
		rod(m, from, to, 0.5 - (i % 3) * 0.06, bark, M.Wood)
		table.insert(tips, to)
	end
	-- leafy crown: overlapping clumps in a few greens
	local greens = { C(60, 120, 45), C(75, 140, 55), C(50, 105, 40), C(90, 150, 60) }
	local rng = Random.new(11)
	for i, tip in ipairs(tips) do
		add(m, "Ell", V(4.6, 3.6, 4.6), tip + V(0, 0.8, 0), greens[i % 4 + 1], leafy)
	end
	add(m, "Ell", V(7.5, 5.5, 7.5), V(0, 12, 0), greens[2], leafy)
	add(m, "Ell", V(5, 4, 5), V(0.5, 14.6, -0.3), greens[4], leafy)
	for _ = 1, 7 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(2.2, 3.8)
		add(m, "Ell", V(3, 2.4, 3) * rng:NextNumber(0.8, 1.2), V(math.cos(a) * r, rng:NextNumber(10, 14), math.sin(a) * r), greens[rng:NextInteger(1, 4)], leafy)
	end
end

B.FoodTruck = function(m)
	local yellow = C(245, 190, 40)
	local white = C(240, 240, 238)
	-- chassis + cab (front = -Z)
	add(m, "Block", V(4.6, 0.5, 13), V(0, 1.15, 0), C(40, 40, 44), M.Metal)
	rbox(m, V(4.6, 2.2, 3.4), V(0, 2.4, -4.6), 0.5, white, M.SmoothPlastic, { Reflectance = 0.12 })
	rbox(m, V(4.5, 1.5, 2.6), V(0, 4.25, -4.2), 0.4, white, M.SmoothPlastic, { Reflectance = 0.12 })
	glass(m, V(4.0, 1.1, 0.1), rot(V(0, 4.3, -5.55), -10, 0, 0), C(25, 35, 45))
	for _, s in ipairs({ -1, 1 }) do
		glass(m, V(0.08, 0.9, 1.6), V(s * 2.26, 4.3, -4.2), C(25, 35, 45))
		add(m, "Ell", V(0.7, 0.5, 0.15), V(s * 1.6, 2.6, -6.32), C(255, 250, 235), M.Neon)
		add(m, "Block", V(0.1, 0.5, 0.35), V(s * 2.5, 4.0, -5.3), C(30, 30, 30))
	end
	add(m, "Block", V(3.2, 0.7, 0.1), V(0, 1.9, -6.32), C(25, 25, 28))
	rbox(m, V(4.8, 0.45, 0.4), V(0, 1.2, -6.4), 0.2, C(160, 160, 165), M.Metal)
	-- cargo box
	rbox(m, V(4.8, 4.8, 8.6), V(0, 3.8, 1.6), 0.35, yellow, M.SmoothPlastic, { Reflectance = 0.1 })
	add(m, "Block", V(4.85, 0.3, 8.65), V(0, 1.55, 1.6), C(200, 40, 40))
	-- serving window with awning, counter and menu board (on the +X side)
	add(m, "Block", V(0.1, 2.0, 5.0), V(2.42, 4.3, 1.6), C(40, 30, 25))
	add(m, "Block", V(0.12, 1.8, 4.8), V(2.43, 4.3, 1.6), C(255, 230, 170), M.Neon, { Transparency = 0.6 })
	add(m, "Block", V(0.9, 0.12, 5.2), V(2.85, 3.25, 1.6), C(180, 180, 185), M.Metal)
	for i = 0, 7 do
		add(m, "Block", V(1.6, 0.08, 0.66), rot(V(3.1, 5.6, -0.7 + i * 0.66), 0, 0, -22), i % 2 == 0 and C(220, 40, 40) or white, M.Fabric)
	end
	local menu = add(m, "Block", V(0.1, 1.0, 2.0), V(2.42, 2.3, 4.6), C(30, 30, 32))
	label(menu, Enum.NormalId.Right, "BURGERS $5", C(255, 220, 80))
	-- giant burger on the roof
	add(m, "Cyl", V(2.6, 0.25, 2.6), V(0, 6.4, 1.6), C(60, 60, 64), M.Metal)
	add(m, "Ell", V(2.8, 0.9, 2.8), V(0, 6.85, 1.6), C(205, 140, 70))
	add(m, "Cyl", V(3.0, 0.2, 3.0), V(0, 7.25, 1.6), C(90, 180, 60))
	add(m, "Cyl", V(2.9, 0.4, 2.9), V(0, 7.5, 1.6), C(110, 60, 35))
	add(m, "Cyl", V(3.0, 0.12, 3.0), V(0, 7.75, 1.6), C(250, 200, 40))
	add(m, "Ell", V(2.8, 1.5, 2.8), V(0, 8.1, 1.6), C(215, 150, 75))
	-- wheels
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -4.5, 3.8 }) do
			wheel(m, V(s * 2.2, 1.0, z), 2.0, 0.8)
		end
	end
end

B.Statue = function(m)
	local stone = C(190, 185, 175)
	local patina = C(105, 165, 140)
	-- stepped granite pedestal with a plaque
	add(m, "Block", V(6, 0.6, 6), V(0, 0.3, 0), stone:Lerp(C(0, 0, 0), 0.1), M.Granite)
	add(m, "Block", V(5, 0.6, 5), V(0, 0.9, 0), stone, M.Granite)
	add(m, "Block", V(3.6, 3.6, 3.6), V(0, 2.95, 0), stone, M.Granite)
	add(m, "Block", V(4.0, 0.4, 4.0), V(0, 4.9, 0), stone:Lerp(C(255, 255, 255), 0.1), M.Granite)
	local plaque = add(m, "Block", V(1.8, 0.8, 0.08), V(0, 3.0, -1.84), C(180, 140, 60), M.Metal)
	label(plaque, Enum.NormalId.Front, "LIBERTY", C(60, 40, 15))
	-- robed figure (copper patina): flowing robe, torso, head with crown
	cone(m, 5.1, 4.2, 1.15, 0.75, 14, patina, M.Metal)
	add(m, "Ell", V(1.8, 2.2, 1.3), V(0, 9.9, 0), patina, M.Metal)
	add(m, "Ell", V(0.7, 0.6, 0.6), V(0, 10.8, -0.1), patina, M.Metal)
	add(m, "Ball", V(0.95, 0.95, 0.95), V(0, 11.5, 0), patina, M.Metal)
	add(m, "Cyl", V(1.05, 0.25, 1.05), V(0, 11.85, 0), patina, M.Metal)
	for i = 0, 6 do
		local a = math.rad(-90 + (i - 3) * 28)
		add(m, "Wedge", V(0.12, 0.7, 0.18), CFrame.new(math.cos(a) * 0.55, 12.2, math.sin(a) * 0.55) * CFrame.Angles(0, -a + math.pi / 2, 0), patina, M.Metal)
	end
	-- raised right arm with torch
	local shoulder = V(0.85, 10.6, 0)
	local hand = V(1.3, 13.8, -0.2)
	rod(m, shoulder, hand, 0.55, patina, M.Metal)
	add(m, "Cyl", V(0.45, 1.0, 0.45), hand + V(0, 0.6, 0), patina, M.Metal)
	add(m, "Cyl", V(0.8, 0.25, 0.8), hand + V(0, 1.15, 0), C(190, 150, 60), M.Metal)
	add(m, "Ell", V(0.6, 1.0, 0.6), hand + V(0, 1.75, 0), C(255, 190, 60), M.Neon)
	-- left arm holding a tablet
	rod(m, V(-0.85, 10.6, 0), V(-1.0, 9.2, -0.5), 0.5, patina, M.Metal)
	add(m, "Block", V(0.3, 1.5, 0.9), rot(V(-1.05, 9.3, -0.6), 0, 0, 10), patina, M.Metal)
	-- robe folds
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		add(m, "Block", V(0.15, 4.2, 0.35), CFrame.new(math.cos(a) * 0.95, 7.2, math.sin(a) * 0.95) * CFrame.Angles(0, -a, math.rad(6)), patina:Lerp(C(0, 0, 0), 0.1), M.Metal)
	end
end

B.SportsCar = function(m)
	B._car(m, {
		Paint = C(210, 20, 25),
		Length = 9.8,
		Width = 4.1,
		BodyH = 0.95,
		BodyY = 0.45,
		CabinZ = 0.9,
		CabinLen = 2.6,
		CabinH = 0.85,
		Wheel = 1.75,
		WheelZ = 3.2,
		Sport = true,
	})
end

-- Shared car body (front = -Z). Rounded lower body, sloped windshield & rear glass, wheels, lights.

-- Tier 4 ─────────────────────────────────────────
B.House = function(m)
	local siding = C(235, 230, 215)
	local trim = C(250, 250, 250)
	local roofC = C(80, 60, 55)
	-- foundation, walls (siding), corner boards
	add(m, "Block", V(16.4, 0.8, 12.4), V(0, 0.4, 0), C(150, 145, 140), M.Concrete)
	add(m, "Block", V(16, 7, 12), V(0, 4.3, 0), siding, M.WoodPlanks)
	for _, x in ipairs({ -8, 8 }) do
		for _, z in ipairs({ -6, 6 }) do
			add(m, "Block", V(0.4, 7, 0.4), V(x, 4.3, z), trim)
		end
	end
	-- gable roof with shingles + overhang + gable ends
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(17.4, 0.35, 7.6), CFrame.new(0, 10.0, s * 3.2) * CFrame.Angles(math.rad(s * 33), 0, 0), roofC, ROOF)
		add(m, "Wedge", V(0.3, 3.9, 6.0), CFrame.new(s * 7.85, 9.75, 0 - 3.0) * CFrame.Angles(0, 0, 0), siding, M.WoodPlanks)
		add(m, "Wedge", V(0.3, 3.9, 6.0), CFrame.new(s * 7.85, 9.75, 3.0) * CFrame.Angles(0, math.pi, 0), siding, M.WoodPlanks)
	end
	add(m, "Block", V(17.6, 0.3, 0.5), V(0, 11.95, 0), roofC:Lerp(C(0, 0, 0), 0.2), ROOF)
	-- brick chimney
	add(m, "Block", V(1.6, 4.5, 1.6), V(5, 11.3, 2.5), C(150, 70, 55), M.Brick)
	add(m, "Block", V(1.9, 0.3, 1.9), V(5, 13.6, 2.5), C(120, 120, 120), M.Concrete)
	-- front (-Z): door with porch, windows with shutters
	add(m, "Block", V(2.2, 3.8, 0.15), V(-1.5, 2.7, -6.05), C(130, 35, 40), M.Wood)
	add(m, "Block", V(2.6, 4.1, 0.1), V(-1.5, 2.85, -6.02), trim)
	add(m, "Ball", V(0.2, 0.2, 0.2), V(-0.7, 2.6, -6.18), C(220, 180, 60), M.Metal)
	add(m, "Block", V(4.5, 0.3, 2.4), V(-1.5, 0.95, -7.2), C(160, 150, 140), M.Concrete)
	add(m, "Block", V(4.5, 0.3, 1.2), V(-1.5, 0.5, -8.6), C(160, 150, 140), M.Concrete)
	add(m, "Block", V(5.0, 0.25, 2.8), rot(V(-1.5, 5.4, -7.2), 8, 0, 0), roofC, ROOF)
	for _, x in ipairs({ -3.6, 0.6 }) do
		add(m, "Cyl", V(0.3, 4.3, 0.3), V(x, 3.2, -8.4), trim)
	end
	for _, x in ipairs({ 3.2, 6.2 }) do
		window(m, CFrame.new(x, 4.4, -6.05), 1.8, 2.4, trim)
		for _, s in ipairs({ -1, 1 }) do
			add(m, "Block", V(0.7, 2.6, 0.1), V(x + s * 1.35, 4.4, -6.08), C(45, 70, 90), M.Wood)
		end
		add(m, "Block", V(2.2, 0.15, 0.4), V(x, 3.1, -6.2), trim)
	end
	-- dormer-style upstairs window in the gable + side windows
	window(m, CFrame.new(-8.05, 9.3, 0) * CFrame.Angles(0, math.rad(90), 0), 1.6, 1.6, trim)
	for _, z in ipairs({ -2.5, 2.5 }) do
		window(m, CFrame.new(-8.05, 4.4, z) * CFrame.Angles(0, math.rad(90), 0), 1.8, 2.4, trim)
		window(m, CFrame.new(8.05, 4.4, z) * CFrame.Angles(0, math.rad(90), 0), 1.8, 2.4, trim)
	end
	-- gutters + bushes
	add(m, "Block", V(17.4, 0.25, 0.3), V(0, 7.9, -6.5), trim)
	for _, x in ipairs({ -6.5, 4.7 }) do
		add(m, "Ell", V(2.4, 1.6, 1.4), V(x, 1.4, -7), C(60, 120, 50), mat("LeafyGrass", M.Grass))
	end
end

B.Bus = function(m)
	local yellow = C(250, 185, 20)
	local black = C(25, 25, 25)
	-- body (front = -Z): long box with rounded edges and a short hood
	rbox(m, V(5.4, 5.6, 19), V(0, 4.0, 1.5), 0.6, yellow, M.SmoothPlastic, { Reflectance = 0.1 })
	rbox(m, V(5.4, 0.3, 18.8), V(0, 6.9, 1.5), 1.0, C(245, 245, 240))
	rbox(m, V(4.6, 2.4, 3.2), V(0, 2.4, -9.2), 0.6, yellow, M.SmoothPlastic, { Reflectance = 0.1 })
	add(m, "Block", V(3.0, 1.4, 0.1), V(0, 2.4, -10.82), black)
	for i = -3, 3 do
		add(m, "Block", V(3.0, 0.06, 0.12), V(0, 2.4 + i * 0.18, -10.83), C(200, 200, 205), M.Metal)
	end
	-- black rub rails + windows
	for _, y in ipairs({ 2.0, 3.3 }) do
		add(m, "Block", V(5.46, 0.18, 19), V(0, y, 1.5), black)
	end
	glass(m, V(4.6, 2.0, 0.1), rot(V(0, 5.2, -8.0), -6, 0, 0), C(30, 40, 50))
	for _, s in ipairs({ -1, 1 }) do
		for i = 0, 7 do
			glass(m, V(0.1, 1.6, 1.8), V(s * 2.72, 5.2, -6.3 + i * 2.15), C(40, 55, 70))
			add(m, "Block", V(0.12, 1.8, 0.2), V(s * 2.73, 5.2, -5.25 + i * 2.15), black)
		end
		add(m, "Block", V(0.1, 0.5, 9), V(s * 2.73, 3.9, 2), C(20, 20, 20))
		add(m, "Ell", V(0.8, 0.6, 0.15), V(s * 1.7, 2.9, -10.82), C(255, 250, 230), M.Neon)
		add(m, "Ell", V(0.5, 0.5, 0.15), V(s * 2.0, 6.5, -7.78), C(255, 120, 20), M.Neon)
		add(m, "Ell", V(0.5, 0.5, 0.15), V(s * 2.0, 6.5, 11.03), C(255, 30, 30), M.Neon)
		-- mirrors on arms
		beam(m, V(s * 2.3, 3.6, -10.5), V(s * 3.2, 4.2, -10.9), 0.12, black)
		add(m, "Block", V(0.2, 0.9, 0.4), V(s * 3.25, 4.2, -10.95), black)
		for _, z in ipairs({ -7.6, 7.0 }) do
			wheel(m, V(s * 2.35, 1.35, z), 2.7, 1.0)
		end
	end
	-- side text, stop sign arm, door
	local side = add(m, "Block", V(0.06, 0.7, 9), V(-2.73, 6.25, 2), yellow)
	label(side, Enum.NormalId.Left, "SCHOOL BUS", black)
	add(m, "Block", V(0.1, 3.2, 1.8), V(2.73, 3.1, -6.4), C(40, 55, 70), M.Glass, { Transparency = 0.2 })
	local stop = add(m, "Cyl", V(1.1, 0.06, 1.1), rot(V(-3.2, 4.0, -5), 0, 0, 90), C(200, 20, 20))
	label(stop, Enum.NormalId.Top, "STOP", C(255, 255, 255))
	add(m, "Block", V(5.6, 0.5, 0.4), V(0, 1.4, -10.95), black)
	add(m, "Block", V(5.6, 0.5, 0.4), V(0, 1.4, 11.1), black)
end

B.Windmill = function(m)
	local wood = C(120, 85, 55)
	local plaster = C(225, 220, 205)
	-- stone base, tapering tower, wooden gallery
	add(m, "Cyl", V(9.5, 1.5, 9.5), V(0, 0.75, 0), C(130, 125, 120), mat("Cobblestone", M.Slate))
	cone(m, 1.5, 16, 4.2, 2.8, 20, plaster, PLASTER)
	add(m, "Cyl", V(8.6, 0.3, 8.6), V(0, 9, 0), wood, M.WoodPlanks)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		add(m, "Block", V(0.15, 1.1, 0.15), V(math.cos(a) * 4.2, 9.6, math.sin(a) * 4.2), wood, M.Wood)
	end
	ring(m, CFrame.new(0, 10.15, 0) * CFrame.Angles(0, 0, math.rad(90)), 4.2, 0.12, 20, wood, M.Wood)
	-- door + small windows
	add(m, "Block", V(1.6, 2.8, 0.3), V(0, 2.9, -4.05), C(80, 55, 35), M.Wood)
	for _, y in ipairs({ 6, 13 }) do
		window(m, CFrame.new(0, y, -(4.2 - (y - 1.5) / 16 * 1.4) - 0.05), 1.0, 1.3, C(240, 240, 235))
	end
	-- thatched cap
	cone(m, 17.4, 4.2, 3.2, 0.3, 14, C(110, 90, 60), mat("Ground", M.Fabric))
	-- sails: axle, 4 lattice blades with cloth
	local hubCF = CFrame.new(0, 16, -3.6)
	add(m, "CylZ", V(1.0, 1.0, 1.6), hubCF, C(60, 45, 30), M.Wood)
	for i = 0, 3 do
		local a = math.rad(i * 90 + 20)
		local blade = hubCF * CFrame.new(0, 0, -0.9) * CFrame.Angles(0, 0, a)
		add(m, "Block", V(0.35, 10, 0.3), blade * CFrame.new(0, 5.3, 0), wood, M.Wood)
		add(m, "Block", V(1.8, 7.5, 0.06), blade * CFrame.new(0.95, 6.3, 0.05), C(235, 230, 215), M.Fabric)
		for k = 0, 6 do
			add(m, "Block", V(2.0, 0.08, 0.12), blade * CFrame.new(0.95, 2.8 + k * 1.15, -0.05), wood, M.Wood)
		end
		add(m, "Block", V(0.08, 7.5, 0.12), blade * CFrame.new(1.9, 6.3, -0.05), wood, M.Wood)
	end
end

B.Boat = function(m)
	local hull = C(245, 245, 248)
	local teak = C(170, 120, 70)
	-- hull (front = -Z): body + pointed bow (a square turned 45°) + navy stripe + red antifouling
	local bowCF = CFrame.new(0, 0, -4) * CFrame.Angles(0, math.rad(45), 0)
	local d = 5.6 / math.sqrt(2)
	add(m, "Block", V(5.6, 2.4, 11), V(0, 1.8, 1.5), hull, M.SmoothPlastic, { Reflectance = 0.15 })
	add(m, "Block", V(d, 2.4, d), bowCF + V(0, 1.8, 0), hull, M.SmoothPlastic, { Reflectance = 0.15 })
	add(m, "Block", V(5.65, 0.35, 11), V(0, 2.6, 1.5), C(20, 40, 90))
	add(m, "Block", V(d + 0.04, 0.35, d + 0.04), bowCF + V(0, 2.6, 0), C(20, 40, 90))
	add(m, "Block", V(5.0, 0.8, 10.6), V(0, 0.7, 1.7), C(170, 40, 40))
	add(m, "Block", V(d - 0.4, 0.8, d - 0.4), bowCF + V(0, 0.7, 0), C(170, 40, 40))
	add(m, "Block", V(0.4, 1.2, 4), V(0, 0.3, 2), C(40, 40, 45))
	add(m, "Block", V(d - 0.15, 0.15, d - 0.15), bowCF + V(0, 3.05, 0), teak, M.WoodPlanks)
	-- teak deck, cabin with portholes, cockpit
	add(m, "Block", V(5.4, 0.15, 10.8), V(0, 3.05, 1.5), teak, M.WoodPlanks)
	rbox(m, V(3.6, 1.6, 4.5), V(0, 3.9, 0.5), 0.5, hull)
	add(m, "Block", V(3.7, 0.15, 4.6), V(0, 4.75, 0.5), teak, M.WoodPlanks)
	for _, s in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			add(m, "CylX", V(0.1, 0.45, 0.45), V(s * 1.81, 3.9, -0.8 + i * 1.3), C(40, 60, 80), M.Glass, { Reflectance = 0.4 })
		end
		-- stanchions + lifelines
		for i = 0, 4 do
			add(m, "Cyl", V(0.08, 1.2, 0.08), V(s * 2.6, 3.7, -3.3 + i * 2.2), C(200, 200, 205), M.Metal)
		end
		rod(m, V(s * 2.6, 4.25, -3.3), V(s * 2.6, 4.25, 5.5), 0.05, C(200, 200, 205), M.Metal)
	end
	-- mast, boom, sails, rigging
	rod(m, V(0, 3.1, -1.6), V(0, 15.5, -1.6), 0.35, C(210, 210, 215), M.Metal)
	rod(m, V(0, 5.0, -1.6), V(0, 5.0, 5.0), 0.25, C(210, 210, 215), M.Metal)
	add(m, "Wedge", V(0.08, 10, 6.2), CFrame.new(0, 10.2, 1.6) * CFrame.Angles(0, math.pi, 0), C(250, 250, 245), M.Fabric)
	add(m, "Wedge", V(0.08, 10.5, 5), CFrame.new(0.15, 9.0, -4.3), C(250, 250, 245), M.Fabric)
	beam(m, V(0, 15.5, -1.6), V(0, 3.2, -8.8), 0.05, C(150, 150, 155), M.Metal)
	beam(m, V(0, 15.5, -1.6), V(0, 3.2, 6.9), 0.05, C(150, 150, 155), M.Metal)
	-- wheel at the stern
	ring(m, CFrame.new(0, 4.2, 5.4) * CFrame.Angles(0, math.rad(90), 0), 0.6, 0.1, 10, teak, M.Wood)
	local name = add(m, "Block", V(3, 0.5, 0.05), V(0, 2.0, 7.02), hull)
	label(name, Enum.NormalId.Back, "SEA SHRINK", C(20, 40, 90))
end

B.Lighthouse = function(m)
	local white = C(245, 245, 240)
	local red = C(200, 30, 35)
	-- rock base + keeper's door
	add(m, "Cyl", V(9, 1.6, 9), V(0, 0.8, 0), C(120, 115, 110), ROCK)
	-- tapered striped tower
	local h, steps = 22, 22
	for i = 0, steps - 1 do
		local t = (i + 0.5) / steps
		local r = 3.4 + (2.2 - 3.4) * t
		local band = math.floor(i / (steps / 6)) % 2 == 0
		add(m, "Cyl", V(r * 2, h / steps + 0.02, r * 2), V(0, 1.6 + h / steps * (i + 0.5), 0), band and white or red, PLASTER)
	end
	add(m, "Block", V(1.6, 2.6, 0.4), V(0, 2.9, -3.3), C(30, 50, 80), M.Wood)
	for _, y in ipairs({ 8, 14, 19 }) do
		window(m, CFrame.new(0, y, -(3.4 - (y - 1.6) / h * 1.2) - 0.05), 0.7, 1.1, C(240, 240, 240))
	end
	-- gallery deck + railing
	add(m, "Cyl", V(6.6, 0.4, 6.6), V(0, 23.8, 0), C(40, 40, 45), M.Metal)
	for i = 0, 19 do
		local a = i / 20 * math.pi * 2
		add(m, "Cyl", V(0.1, 1.2, 0.1), V(math.cos(a) * 3.15, 24.6, math.sin(a) * 3.15), C(40, 40, 45), M.Metal)
	end
	ring(m, CFrame.new(0, 25.2, 0) * CFrame.Angles(0, 0, math.rad(90)), 3.15, 0.12, 20, C(40, 40, 45), M.Metal)
	-- lantern room: glass + glowing lamp + red dome
	add(m, "Cyl", V(4.2, 0.6, 4.2), V(0, 24.3, 0), red, M.Metal)
	glass(m, V(3.6, 3.2, 3.6), CFrame.new(0, 26.2, 0), C(200, 230, 255), 0.6)
	add(m, "Ball", V(1.8, 1.8, 1.8), V(0, 26.2, 0), C(255, 240, 180), M.Neon)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		add(m, "Block", V(0.12, 3.2, 0.12), V(math.cos(a) * 1.85, 26.2, math.sin(a) * 1.85), C(30, 30, 35), M.Metal)
	end
	add(m, "Cyl", V(4.4, 0.4, 4.4), V(0, 27.95, 0), red, M.Metal)
	add(m, "Ell", V(4.0, 2.6, 4.0), V(0, 28.2, 0), red, M.Metal)
	add(m, "Cyl", V(0.3, 1.2, 0.3), V(0, 29.9, 0), C(40, 40, 45), M.Metal)
	add(m, "Ball", V(0.45, 0.45, 0.45), V(0, 30.6, 0), C(40, 40, 45), M.Metal)
	local light = Instance.new("PointLight")
	light.Range = 40
	light.Brightness = 2
	light.Color = C(255, 240, 190)
	light.Parent = m:GetChildren()[#m:GetChildren()]
end

-- Tier 5 ─────────────────────────────────────────
B.Skyscraper = function(m)
	local glassC = C(70, 110, 150)
	local frame = C(200, 205, 212)
	-- three setback tiers of glass curtain wall with vertical mullions and floor bands
	local tiers = { { 14, 26, 0 }, { 11, 18, 26 }, { 8, 10, 44 } }
	for _, t in ipairs(tiers) do
		local w, h, y0 = t[1], t[2], t[3]
		add(m, "Block", V(w, h, w), V(0, y0 + h / 2, 0), glassC, M.Glass, { Reflectance = 0.45, Transparency = 0.05 })
		for i = 0, 6 do
			local off = -w / 2 + i * (w / 6)
			for _, side in ipairs({ -1, 1 }) do
				add(m, "Block", V(0.25, h, 0.3), V(off, y0 + h / 2, side * w / 2), frame, M.Metal)
				add(m, "Block", V(0.3, h, 0.25), V(side * w / 2, y0 + h / 2, off), frame, M.Metal)
			end
		end
		for y = y0 + 2, y0 + h - 1, 2.6 do
			add(m, "Block", V(w + 0.15, 0.25, w + 0.15), V(0, y, 0), frame:Lerp(C(0, 0, 0), 0.25), M.Metal)
		end
		add(m, "Block", V(w + 0.6, 0.6, w + 0.6), V(0, y0 + h, 0), frame, M.Concrete)
	end
	-- lobby, entrance canopy, rooftop mechanicals and spire
	add(m, "Block", V(15, 2.2, 15), V(0, 1.1, 0), C(60, 60, 65), M.Granite)
	add(m, "Block", V(5, 0.3, 2.5), V(0, 3.2, -8.2), frame, M.Metal)
	glass(m, V(4, 2.4, 0.1), V(0, 1.4, -7.55), C(40, 60, 80))
	add(m, "Block", V(4, 2, 4), V(-1.5, 55.5, 1.5), C(120, 120, 128), M.Metal)
	add(m, "Cyl", V(2.2, 1.6, 2.2), V(2.2, 55.3, -2), C(150, 150, 158), M.Metal)
	cone(m, 54.5, 9, 0.6, 0.12, 12, frame, M.Metal)
	neon(m, "Ball", V(0.6, 0.6, 0.6), V(0, 63.8, 0), C(255, 40, 40))
end

B.FerrisWheel = function(m)
	local white = C(240, 240, 245)
	local steel = C(170, 175, 185)
	local hubY, r = 21, 17
	local axisCF = CFrame.new(0, hubY, 0) -- wheel spins around X
	-- base platform + A-frame legs on both sides
	add(m, "Block", V(10, 1, 26), V(0, 0.5, 0), C(130, 130, 135), M.Concrete)
	for _, sx in ipairs({ -2.6, 2.6 }) do
		for _, sz in ipairs({ -8, 8 }) do
			rod(m, V(sx, 1, sz), V(sx * 0.8, hubY, 0), 0.8, white, M.Metal)
		end
		rod(m, V(sx, 6, -6.2), V(sx, 6, 6.2), 0.4, white, M.Metal)
	end
	add(m, "CylX", V(6, 1.6, 1.6), axisCF, steel, M.Metal)
	-- double rim + spokes
	for _, x in ipairs({ -1.2, 1.2 }) do
		ring(m, axisCF * CFrame.new(x, 0, 0), r, 0.45, 18, white, M.Metal)
		ring(m, axisCF * CFrame.new(x, 0, 0), r * 0.55, 0.25, 12, white, M.Metal)
	end
	local cars = { C(230, 60, 60), C(60, 140, 230), C(250, 200, 50), C(80, 200, 110), C(200, 90, 220), C(255, 140, 50) }
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local tip = (axisCF * CFrame.new(0, math.cos(a) * r, math.sin(a) * r)).Position
		for _, x in ipairs({ -1.2, 1.2 }) do
			rod(m, V(x, hubY, 0), tip + V(x, 0, 0), 0.18, steel, M.Metal)
		end
		rod(m, tip + V(-1.3, 0, 0), tip + V(1.3, 0, 0), 0.25, steel, M.Metal)
		-- hanging gondola
		rod(m, tip, tip - V(0, 1.4, 0), 0.15, steel, M.Metal)
		add(m, "Ell", V(2.3, 2.2, 2.0), tip - V(0, 2.4, 0), cars[i % 6 + 1], M.SmoothPlastic, { Reflectance = 0.1 })
		glass(m, V(2.35, 0.6, 1.4), CFrame.new(tip - V(0, 2.1, 0)), C(60, 80, 100))
	end
	-- ticket booth
	rbox(m, V(3, 3, 3), V(3, 2.5, -10), 0.4, C(240, 80, 80))
	add(m, "Block", V(3.6, 0.4, 3.6), V(3, 4.2, -10), white)
end

B.CruiseShip = function(m)
	local white = C(245, 246, 248)
	local navy = C(20, 35, 80)
	-- hull (front = -Z): long block + pointed bow, navy lower hull, red waterline
	local bowCF = CFrame.new(0, 0, -17) * CFrame.Angles(0, math.rad(45), 0)
	local d = 10 / math.sqrt(2)
	add(m, "Block", V(10, 5, 34), V(0, 3.0, 0), navy)
	add(m, "Block", V(d, 5, d), bowCF + V(0, 3.0, 0), navy)
	add(m, "Block", V(10.05, 0.6, 34), V(0, 0.8, 0), C(170, 35, 35))
	add(m, "Block", V(10.05, 1.2, 34), V(0, 5.9, 0), white)
	add(m, "Block", V(d + 0.04, 1.2, d + 0.04), bowCF + V(0, 5.9, 0), white)
	-- stacked white decks with balconies (glass) getting shorter toward the top
	local decks = { { 9.6, 30, 0.5 }, { 9.0, 26, 1.5 }, { 8.2, 21, 2.5 }, { 7.0, 14, 3.5 } }
	local y = 6.5
	for i, dk in ipairs(decks) do
		local w, len, zOff = dk[1], dk[2], dk[3]
		add(m, "Block", V(w, 1.7, len), V(0, y + 0.85, zOff), white, M.SmoothPlastic, { Reflectance = 0.1 })
		for _, s in ipairs({ -1, 1 }) do
			add(m, "Block", V(0.08, 0.7, len - 1), V(s * (w / 2 + 0.02), y + 0.95, zOff), C(40, 70, 110), M.Glass, { Reflectance = 0.4 })
			add(m, "Block", V(0.1, 0.12, len - 0.6), V(s * (w / 2 + 0.05), y + 0.25, zOff), C(200, 200, 205), M.Metal)
		end
		y += 1.7
		if i == 1 then
			-- lifeboats along the first deck
			for k = 0, 5 do
				for _, s in ipairs({ -1, 1 }) do
					add(m, "Ell", V(1.2, 0.9, 3.0), V(s * 5.2, 7.6, -10 + k * 4), C(255, 140, 30))
				end
			end
		end
	end
	-- bridge with wraparound windows
	add(m, "Block", V(9.4, 1.6, 3), V(0, y + 0.8, -6), white)
	add(m, "Block", V(9.45, 0.7, 3.05), V(0, y + 1.0, -6), C(30, 50, 80), M.Glass, { Reflectance = 0.4 })
	-- pool deck, funnels
	add(m, "Block", V(4, 0.2, 5), V(0, y + 0.1, 4), C(60, 170, 230), M.Glass, { Transparency = 0.2 })
	for _, z in ipairs({ 9, 13 }) do
		add(m, "Ell", V(3.0, 5, 3.6), V(0, y + 2.4, z), C(200, 30, 35))
		add(m, "Cyl", V(2.6, 0.6, 2.6), V(0, y + 4.6, z), C(25, 25, 28))
	end
	-- anchor + name
	add(m, "Block", V(0.2, 1.2, 0.8), V(-4.6, 4.6, -13), C(60, 60, 65), M.Metal)
	local nameplate = add(m, "Block", V(0.06, 0.8, 8), V(5.03, 4.5, -8), navy)
	label(nameplate, Enum.NormalId.Right, "SHRINK SEAS", C(240, 240, 240))
end

B.Rocket = function(m)
	local white = C(240, 240, 238)
	local black = C(25, 25, 28)
	-- launch pad + umbilical tower
	add(m, "Block", V(14, 1, 14), V(0, 0.5, 0), C(120, 120, 125), M.Concrete)
	for _, x in ipairs({ 5.4, 7.6 }) do
		for _, z in ipairs({ -1.1, 1.1 }) do
			add(m, "Block", V(0.4, 34, 0.4), V(x, 17.5, z), C(200, 60, 40), M.Metal)
		end
	end
	for yy = 3, 33, 3 do
		add(m, "Block", V(2.6, 0.25, 2.6), V(6.5, yy, 0), C(200, 60, 40), M.Metal)
	end
	rod(m, V(5.4, 24, 0), V(2.2, 24, 0), 0.4, C(90, 90, 95), M.Metal)
	-- engines (5 bells) and first stage with black roll pattern
	for _, p in ipairs({ V(0, 0, 0), V(1.4, 0, 1.4), V(-1.4, 0, 1.4), V(1.4, 0, -1.4), V(-1.4, 0, -1.4) }) do
		cone(m, 1.0, 2.0, 0.9, 0.45, 8, C(60, 60, 65), M.Metal, p.X, p.Z)
	end
	add(m, "Cyl", V(4.4, 13, 4.4), V(0, 9.5, 0), white, M.SmoothPlastic)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		add(m, "Block", V(1.6, 4, 0.06), CFrame.new(math.cos(a) * 2.21, 9, math.sin(a) * 2.21) * CFrame.Angles(0, -a + math.pi / 2, 0), black)
		-- fins
		add(m, "Wedge", V(0.25, 3.2, 2.2), CFrame.new(math.cos(a) * 3.2, 4.2, math.sin(a) * 3.2) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(0, math.pi / 2, 0), black)
	end
	add(m, "Cyl", V(4.45, 0.8, 4.45), V(0, 16.4, 0), black)
	-- interstage, second & third stage
	cone(m, 16.0, 1.2, 2.2, 2.0, 4, white)
	add(m, "Cyl", V(4.0, 8, 4.0), V(0, 21.2, 0), white)
	add(m, "Cyl", V(4.05, 0.6, 4.05), V(0, 25.4, 0), black)
	cone(m, 25.7, 1.2, 2.0, 1.4, 4, white)
	add(m, "Cyl", V(2.8, 4.8, 2.8), V(0, 29.3, 0), white)
	local flag = add(m, "Block", V(0.06, 2.6, 1.6), V(-2.0, 19.5, 0), white)
	label(flag, Enum.NormalId.Left, "SHRINK", C(30, 30, 30))
	-- capsule, escape tower
	cone(m, 31.7, 2.4, 1.4, 0.5, 10, C(200, 200, 205), M.Metal)
	rod(m, V(0, 34, 0), V(0, 37.5, 0), 0.25, C(200, 60, 40), M.Metal)
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		beam(m, V(math.cos(a) * 0.5, 34.1, math.sin(a) * 0.5), V(0, 36.2, 0), 0.12, C(200, 60, 40), M.Metal)
	end
	cone(m, 37.5, 1.2, 0.3, 0.05, 6, C(200, 60, 40), M.Metal)
end

-- Tier 6 ─────────────────────────────────────────
B.Mountain = function(m)
	local rockC = C(118, 110, 102)
	local dark = C(84, 79, 76)
	local snow = C(245, 248, 252)
	local rng = Random.new(3)
	-- grassy foothills
	add(m, "Ell", V(46, 5, 42), V(0, 0.6, 0), C(85, 120, 60), M.Grass)
	-- a peak = smooth concave cone (rock → snow) + rocky outcrops sitting on the slope
	local K = 1.35
	local function peak(x, z, h, r0, snowFrom, crags)
		local layers = math.floor(h / 1.3)
		for i = 0, layers - 1 do
			local t = (i + 0.5) / layers
			local r = r0 * (1 - t) ^ K + 0.2
			local isSnow = t > snowFrom
			add(m, "Cyl", V(r * 2, h / layers + 0.04, r * 2), V(x, 2 + h / layers * (i + 0.5), z), isSnow and snow or rockC:Lerp(dark, t * 0.4), isSnow and M.Snow or ROCK)
		end
		for _ = 1, crags do
			local a = rng:NextNumber(0, math.pi * 2)
			local rho = r0 * rng:NextNumber(0.2, 0.75)
			local t = 1 - (rho / r0) ^ (1 / K)
			local s = r0 * rng:NextNumber(0.14, 0.24)
			local snowy = t > snowFrom - 0.05
			add(m, "Block", V(s, s * 0.8, s * 1.2), CFrame.new(x + math.cos(a) * rho, 2 + t * h, z + math.sin(a) * rho) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.5, 0.5)), snowy and snow or dark, snowy and M.Snow or ROCK)
		end
	end
	peak(0, 0, 36, 19, 0.6, 12)
	peak(-12, 7, 22, 10, 0.55, 6)
	peak(12, 8, 15, 8, 0.7, 4)
	-- little pine trees at the foot
	for i = 0, 10 do
		local a = i / 11 * math.pi * 2
		local p = V(math.cos(a) * 20, 2.2, math.sin(a) * 18)
		add(m, "Cyl", V(0.5, 1.2, 0.5), p, C(90, 60, 40), M.Wood)
		for k = 0, 2 do
			local w = 2.6 - k * 0.8
			add(m, "Block", V(w, 1.2, w), CFrame.new(p.X, p.Y + 1.1 + k * 1.0, p.Z) * CFrame.Angles(0, math.rad(k * 30 + i * 13), 0), C(40, 90, 55))
		end
	end
end

B.Volcano = function(m)
	local rock = C(70, 55, 50)
	local ash = C(110, 100, 95)
	local lava = C(255, 95, 20)
	-- broad cone with uneven ridges, glowing crater, lava rivers and smoke
	local h, r0, r1 = 26, 21, 5
	local layers = 30
	for i = 0, layers - 1 do
		local t = (i + 0.5) / layers
		local r = r0 + (r1 - r0) * t ^ 0.8
		add(m, "Cyl", V(r * 2, h / layers + 0.03, r * 2), V(0, h / layers * (i + 0.5), 0), rock:Lerp(ash, t * 0.6), ROCK)
	end
	local rng = Random.new(9)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		add(m, "Wedge", V(4, h * 0.75, 9), CFrame.new(math.cos(a) * 13, h * 0.37, math.sin(a) * 13) * CFrame.Angles(0, -a - math.pi / 2, 0), rock:Lerp(C(0, 0, 0), 0.15), ROCK)
	end
	-- crater rim + lava pool
	add(m, "Cyl", V(11, 1.4, 11), V(0, h + 0.2, 0), C(55, 42, 38), M.Basalt)
	neon(m, "Cyl", V(8.4, 0.6, 8.4), V(0, h + 0.75, 0), lava)
	-- lava rivers down the slopes
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2 + 0.4
		local prev = V(math.cos(a) * 4.5, h + 0.4, math.sin(a) * 4.5)
		for k = 1, 5 do
			local t = k / 5
			local rr = 4.5 + t * 15.5
			local p = V(math.cos(a + math.sin(k) * 0.08) * rr, h * (1 - t) ^ 1.15 + 0.8, math.sin(a + math.sin(k) * 0.08) * rr)
			neon(m, "Block", V(1.0 - t * 0.4, 0.4, (p - prev).Magnitude + 0.3), CFrame.lookAt((prev + p) / 2, p), lava:Lerp(C(255, 40, 0), t))
			prev = p
		end
	end
	local smoke = Instance.new("Smoke")
	smoke.Color = C(80, 75, 72)
	smoke.Size = 8
	smoke.RiseVelocity = 6
	smoke.Opacity = 0.25
	smoke.Parent = m:GetChildren()[#m:GetChildren()]
	local light = Instance.new("PointLight")
	light.Color = lava
	light.Range = 30
	light.Brightness = 2
	light.Parent = smoke.Parent
end

B.Glacier = function(m)
	local ice = C(185, 225, 250)
	local deep = C(90, 160, 220)
	-- dark sea, then a big blocky ice shelf with sheer cut faces, blue crevasses and snow on top
	add(m, "Block", V(46, 0.6, 40), V(0, 0.3, 0), C(30, 70, 110), M.Glass, { Transparency = 0.15, Reflectance = 0.3 })
	local blocks = {
		{ V(18, 18, 14), V(-8, 9, -2), 4 }, { V(14, 22, 12), V(6, 11, 3), -6 }, { V(10, 14, 10), V(12, 7, -9), 12 },
		{ V(12, 10, 14), V(-12, 5, 9), -10 }, { V(8, 26, 8), V(-2, 13, 8), 3 },
	}
	for i, b in ipairs(blocks) do
		local cf = CFrame.new(b[2]) * CFrame.Angles(0, math.rad(b[3]), 0)
		add(m, "Block", b[1], cf, ice:Lerp(C(255, 255, 255), (i % 3) * 0.1), M.Glacier)
		add(m, "Block", V(b[1].X + 0.4, 1.2, b[1].Z + 0.4), cf * CFrame.new(0, b[1].Y / 2 + 0.3, 0), C(250, 252, 255), M.Snow)
		-- crevasses
		add(m, "Block", V(0.4, b[1].Y * 0.7, b[1].Z + 0.1), cf * CFrame.new(b[1].X * 0.2, b[1].Y * 0.1, 0), deep, M.Ice)
		-- icicle overhang
		for k = -2, 2 do
			add(m, "Wedge", V(0.6, 2.2, 0.8), cf * CFrame.new(k * b[1].X / 6, b[1].Y / 2 - 1.2, -b[1].Z / 2 - 0.35) * CFrame.Angles(math.pi, 0, 0), C(220, 240, 255), M.Ice)
		end
	end
	-- floating ice chunks + a penguin
	for _, p in ipairs({ V(16, 0.8, -14), V(-17, 0.8, -13), V(18, 0.8, 12) }) do
		add(m, "Block", V(3, 1.4, 2.5), rot(p, 0, 30, 4), ice, M.Glacier)
	end
	add(m, "Ell", V(0.9, 1.4, 0.8), V(16, 2.2, -14), C(25, 25, 30))
	add(m, "Ell", V(0.6, 1.0, 0.4), V(16, 2.1, -14.35), C(245, 245, 245))
	add(m, "Ball", V(0.6, 0.6, 0.6), V(16, 3.1, -14), C(25, 25, 30))
	add(m, "Block", V(0.25, 0.12, 0.3), V(16, 3.05, -14.35), C(255, 160, 40))
end

B.TheMoon = function(m)
	local r = 18
	local center = V(0, r, 0)
	local rng = Random.new(42)
	add(m, "Ball", V(r * 2, r * 2, r * 2), center, C(200, 200, 195), ROCK)
	-- darker "maria" plains
	for _ = 1, 6 do
		local dir = V(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 1), rng:NextNumber(-1, 1)).Unit
		local d = rng:NextNumber(9, 15)
		add(m, "Ell", V(d, d, d * 0.2), CFrame.lookAt(center + dir * (r - 0.3), center + dir * (r + 5)), C(150, 150, 148), ROCK)
	end
	-- craters: raised rim + dark floor
	for _ = 1, 16 do
		local dir = V(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local d = rng:NextNumber(2.5, 6.5)
		local cf = CFrame.lookAt(center + dir * (r - d * 0.08), center + dir * (r + 5))
		add(m, "Ell", V(d * 1.25, d * 1.25, d * 0.35), cf, C(215, 215, 210), ROCK)
		add(m, "Ell", V(d, d, d * 0.3), cf * CFrame.new(0, 0, -0.12 * d), C(140, 140, 136), ROCK)
	end
	local glow = Instance.new("PointLight")
	glow.Range = 50
	glow.Brightness = 1
	glow.Color = C(220, 230, 255)
	glow.Parent = m:FindFirstChildWhichIsA("BasePart")
end

-- Exclusives ─────────────────────────────────────
B.HugeTeddy = function(m)
	local fur = C(165, 110, 65)
	local light = C(230, 195, 150)
	local fabric = mat("Fabric", M.Fabric)
	-- sitting plush bear: round belly, stubby legs out front, arms, round head with muzzle and ears
	add(m, "Ell", V(4.4, 4.2, 3.6), V(0, 2.7, 0.2), fur, fabric)
	add(m, "Ell", V(2.8, 3.0, 1.0), V(0, 2.6, -1.4), light, fabric)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ell", V(1.6, 1.6, 2.6), V(s * 1.3, 1.0, -1.0), fur, fabric)
		add(m, "Ell", V(1.3, 1.4, 0.4), V(s * 1.3, 1.0, -2.25), light, fabric)
		add(m, "Ell", V(1.2, 2.6, 1.3), rot(V(s * 2.2, 3.0, -0.4), -25, 0, s * 25), fur, fabric)
		add(m, "Ell", V(1.1, 1.1, 1.0), V(s * 1.45, 7.25, 0), fur, fabric)
		add(m, "Ell", V(0.7, 0.7, 0.5), V(s * 1.45, 7.25, -0.3), light, fabric)
		add(m, "Ball", V(0.4, 0.4, 0.4), V(s * 0.55, 6.15, -1.35), C(20, 15, 15), M.SmoothPlastic, { Reflectance = 0.35 })
	end
	add(m, "Ell", V(3.4, 3.1, 3.0), V(0, 5.9, 0), fur, fabric)
	add(m, "Ell", V(1.6, 1.2, 1.2), V(0, 5.5, -1.3), light, fabric)
	add(m, "Ell", V(0.6, 0.4, 0.3), V(0, 5.75, -1.9), C(40, 25, 20))
	add(m, "Block", V(0.08, 0.35, 0.08), V(0, 5.35, -1.88), C(40, 25, 20))
	-- satin bow
	add(m, "Ball", V(0.5, 0.5, 0.5), V(0, 4.45, -1.3), C(200, 30, 50), M.Fabric)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ell", V(1.0, 0.7, 0.4), rot(V(s * 0.6, 4.45, -1.3), 0, 0, s * 15), C(200, 30, 50), M.Fabric)
	end
	-- stitching seam
	add(m, "Block", V(0.06, 2.6, 0.06), V(0, 2.6, -1.9), light:Lerp(C(0, 0, 0), 0.3))
end

B.HugeCrystal = function(m)
	local crystal = C(120, 240, 230)
	-- geode base + cluster of hexagonal prisms with pointed tips and inner glow
	add(m, "Ell", V(5, 1.8, 4.6), V(0, 0.6, 0), C(70, 60, 80), ROCK)
	add(m, "Ell", V(4.2, 1.2, 3.8), V(0, 1.0, 0), C(130, 90, 170), M.Glass, { Transparency = 0.2 })
	local pieces = { { 1.5, 7, 0, 0, 0, 0 }, { 1.1, 4.8, 1.2, 0.4, -22, 20 }, { 1.1, 5.2, -1.1, 0.3, 20, 60 }, { 0.8, 3.4, 0.3, -1.3, -10, 10 }, { 0.8, 3.2, -0.4, 1.4, 12, -30 } }
	for _, p in ipairs(pieces) do
		local d, h = p[1], p[2]
		local cf = CFrame.new(p[3], 1.2, p[4]) * CFrame.Angles(math.rad(p[6] * 0.3), math.rad(p[6]), math.rad(p[5])) * CFrame.new(0, h / 2, 0)
		for k = 0, 2 do
			add(m, "Block", V(d, h, d * 0.58), cf * CFrame.Angles(0, math.rad(k * 60), 0), crystal, M.Glass, { Transparency = 0.15, Reflectance = 0.35 })
		end
		neon(m, "Block", V(d * 0.35, h * 0.85, d * 0.2), cf, C(200, 255, 250))
		for k = 0, 5 do
			add(m, "Wedge", V(d * 0.58, d * 0.9, d * 0.5), cf * CFrame.new(0, h / 2 + d * 0.45, 0) * CFrame.Angles(0, math.rad(k * 60), 0) * CFrame.new(0, 0, d * 0.25) * CFrame.Angles(0, math.pi, 0), crystal, M.Glass, { Transparency = 0.1, Reflectance = 0.35 })
		end
	end
	local light = Instance.new("PointLight")
	light.Color = crystal
	light.Range = 18
	light.Brightness = 2
	light.Parent = m:FindFirstChildWhichIsA("BasePart")
end

B.HugeDragon = function(m)
	local green = C(45, 140, 75)
	local belly = C(230, 210, 140)
	local horn = C(235, 230, 215)
	local scales = mat("Slate", M.SmoothPlastic)
	-- body, belly plates, legs with claws
	add(m, "Ell", V(4.2, 3.6, 6.6), V(0, 3.6, 0.6), green, scales)
	for i = 0, 4 do
		add(m, "Ell", V(2.6, 0.5, 1.2), V(0, 2.05 + i * 0.05, -1.6 + i * 1.1), belly, M.SmoothPlastic)
	end
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1.6, 2.6 }) do
			add(m, "Ell", V(1.4, 2.2, 1.6), V(s * 1.7, 2.6, z), green, scales)
			add(m, "Ell", V(1.0, 1.6, 1.0), V(s * 1.8, 1.0, z - 0.2), green, scales)
			for c = -1, 1 do
				add(m, "Wedge", V(0.22, 0.35, 0.5), CFrame.new(s * 1.8 + c * 0.32, 0.18, z - 0.85) * CFrame.Angles(0, math.pi, 0), horn)
			end
		end
		-- bat wings: arm bone + membrane panels
		local shoulder = V(s * 1.6, 5.0, 0)
		local elbow = V(s * 4.2, 7.6, 0.8)
		local tip = V(s * 7.2, 6.6, 2.2)
		rod(m, shoulder, elbow, 0.35, green:Lerp(C(0, 0, 0), 0.2), scales)
		rod(m, elbow, tip, 0.25, green:Lerp(C(0, 0, 0), 0.2), scales)
		for k = 0, 2 do
			local fingerEnd = V(s * (3.2 + k * 1.6), 4.4 - k * 0.2, 2.6 + k * 0.6)
			rod(m, elbow, fingerEnd, 0.12, green:Lerp(C(0, 0, 0), 0.2), scales)
			add(m, "Wedge", V(0.08, 2.4, 2.6), CFrame.lookAt((elbow + fingerEnd) / 2 + V(s * 0.4, 0, 0.6), fingerEnd + V(0, 0, 1)) * CFrame.Angles(0, math.rad(90), 0), C(170, 60, 60), M.Fabric, { Transparency = 0.1 })
		end
		add(m, "Wedge", V(0.08, 3.2, 3.4), CFrame.new(s * 3.0, 5.6, 1.4) * CFrame.Angles(0, math.rad(s * 70), 0), C(170, 60, 60), M.Fabric)
	end
	-- neck, head with snout, horns, glowing eyes, nostrils
	rod(m, V(0, 4.6, -2.2), V(0, 6.8, -3.6), 1.6, green, scales)
	add(m, "Ell", V(2.2, 2.0, 2.6), V(0, 7.3, -4.2), green, scales)
	add(m, "Ell", V(1.7, 1.2, 2.2), V(0, 6.9, -5.6), green, scales)
	add(m, "Ell", V(1.5, 0.4, 1.9), V(0, 6.35, -5.5), C(160, 40, 40))
	for _, s in ipairs({ -1, 1 }) do
		rod(m, V(s * 0.6, 8.0, -3.6), V(s * 1.0, 9.4, -2.6), 0.32, horn)
		neon(m, "Ell", V(0.45, 0.3, 0.2), V(s * 0.65, 7.65, -5.0), C(255, 220, 40))
		add(m, "Ball", V(0.18, 0.18, 0.18), V(s * 0.35, 7.1, -6.62), C(20, 20, 20))
	end
	-- spines down the back + tail with spade tip
	for i = 0, 6 do
		add(m, "Wedge", V(0.2, 0.8 - i * 0.05, 0.9), CFrame.new(0, 5.6 - i * 0.12, -1.8 + i * 1.0), C(200, 60, 50))
	end
	local tail = { V(0, 3.5, 3.6), V(0.4, 3.0, 5.6), V(1.2, 2.2, 7.2), V(2.4, 1.6, 8.3), V(3.6, 1.4, 9.0) }
	for i = 1, #tail - 1 do
		rod(m, tail[i], tail[i + 1], 1.3 - i * 0.22, green, scales)
	end
	add(m, "Wedge", V(0.2, 1.4, 1.6), CFrame.lookAt(V(4.2, 1.4, 9.4), V(5, 1.4, 10)), C(200, 60, 50))
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 4
	fire.Parent = m:FindFirstChildWhichIsA("BasePart")
end

-- Zone 5 · Desert ─────────────────────────────────
B.Cactus = function(m)
	local g = C(70, 125, 60)
	local g2 = C(55, 105, 50)
	-- sandy mound + pebbles
	add(m, "Ell", V(4, 0.8, 3.4), V(0, 0.1, 0), C(215, 180, 125), M.Sand)
	add(m, "Ball", V(0.4, 0.4, 0.4), V(1.3, 0.35, -0.8), C(150, 130, 110), ROCK)
	-- ribbed saguaro trunk: core + 8 ribs
	local function column(base, top, d)
		local len = (top - base).Magnitude
		local cf = CFrame.lookAt((base + top) / 2, top) * CFrame.Angles(math.rad(90), 0, 0)
		add(m, "Cyl", V(d, len, d), cf, g)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			add(m, "Block", V(d * 0.22, len, d * 0.22), cf * CFrame.new(math.cos(a) * d * 0.44, 0, math.sin(a) * d * 0.44) * CFrame.Angles(0, -a, 0), i % 2 == 0 and g2 or g)
		end
		add(m, "Ell", V(d * 1.02, d * 0.8, d * 1.02), top, g)
	end
	column(V(0, 0.2, 0), V(0, 10.5, 0), 2.1)
	-- arms: out, then up
	column(V(0.8, 4.2, 0), V(2.6, 4.6, 0), 1.3)
	column(V(2.6, 4.4, 0), V(2.7, 8.0, 0), 1.3)
	column(V(-0.8, 5.6, 0.1), V(-2.3, 6.0, 0.2), 1.15)
	column(V(-2.3, 5.8, 0.2), V(-2.4, 8.4, 0.2), 1.15)
	-- spines
	local rng = Random.new(5)
	for _ = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local y = rng:NextNumber(1, 10)
		add(m, "Block", V(0.05, 0.05, 0.4), CFrame.new(math.cos(a) * 1.08, y, math.sin(a) * 1.08) * CFrame.Angles(0, -a + math.pi / 2, 0), C(245, 240, 210))
	end
	-- flowers on top
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		add(m, "Ell", V(0.5, 0.3, 0.5), V(math.cos(a) * 0.45, 11.3, math.sin(a) * 0.45), C(240, 90, 150))
	end
end

B.Tumbleweed = function(m)
	local rng = Random.new(7)
	local colors = { C(165, 125, 75), C(140, 100, 60), C(185, 150, 95) }
	-- tangled ball of curved twigs
	local center = V(0, 3, 0)
	for i = 1, 15 do
		local axis = V(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local cf = CFrame.lookAt(center, center + axis)
		local r = rng:NextNumber(1.8, 2.8)
		local segs = 6
		local start = rng:NextNumber(0, math.pi * 2)
		local prev
		for k = 0, segs do
			local a = start + k / segs * math.pi * 1.4
			local p = (cf * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0)).Position
			if prev then
				rod(m, prev, p, 0.12, colors[i % 3 + 1], M.Wood)
			end
			prev = p
		end
	end
	add(m, "Ball", V(2.4, 2.4, 2.4), center, C(130, 95, 55), M.Wood, { Transparency = 0.3 })
end

B.OilPump = function(m)
	local yellow = C(235, 175, 30)
	local dark = C(50, 52, 58)
	local steel = C(140, 142, 148)
	-- concrete pad + steel skid
	add(m, "Block", V(6, 0.4, 15), V(0, 0.2, 0), C(160, 155, 150), M.Concrete)
	add(m, "Block", V(4.2, 0.4, 13.5), V(0, 0.6, 0), dark, M.Metal)
	-- samson post (A-frame)
	for _, s in ipairs({ -1, 1 }) do
		rod(m, V(s * 1.7, 0.8, -1.2), V(0.3 * s, 8.6, 0), 0.35, dark, M.Metal)
		rod(m, V(s * 1.7, 0.8, 1.6), V(0.3 * s, 8.6, 0), 0.3, dark, M.Metal)
	end
	add(m, "CylX", V(1.2, 0.8, 0.8), V(0, 8.8, 0), steel, M.Metal)
	-- walking beam + horse head (front = -Z) + bridle
	add(m, "Block", V(0.7, 1.1, 11), rot(V(0, 9.3, 0.3), -6, 0, 0), yellow, M.Metal)
	add(m, "Block", V(0.9, 3.2, 1.2), rot(V(0, 8.9, -5.6), -6, 0, 0), yellow, M.Metal)
	add(m, "CylX", V(0.9, 3.2, 3.2), V(0, 8.9, -5.4), yellow, M.Metal)
	rod(m, V(0, 7.4, -6.6), V(0, 2.2, -6.6), 0.12, steel, M.Metal)
	-- polished rod + wellhead
	rod(m, V(0, 2.2, -6.6), V(0, 0.8, -6.6), 0.2, C(220, 222, 228), M.Metal)
	add(m, "Cyl", V(1.1, 1.4, 1.1), V(0, 1.1, -6.6), dark, M.Metal)
	add(m, "CylX", V(2.4, 0.4, 0.4), V(1.0, 1.3, -6.6), steel, M.Metal)
	add(m, "CylX", V(0.3, 0.8, 0.8), V(2.2, 1.3, -6.6), C(200, 40, 40), M.Metal)
	-- gearbox, cranks with counterweights, pitman arms
	add(m, "Block", V(2.0, 2.4, 2.4), V(0, 2.2, 4.4), dark, M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(0.4, 4.5, 1.6), rot(V(s * 1.3, 3.2, 4.4), 30, 0, 0), C(200, 45, 40), M.Metal)
		add(m, "CylX", V(0.45, 2.6, 2.6), V(s * 1.3, 1.8, 5.3), C(200, 45, 40), M.Metal)
		rod(m, V(s * 1.0, 4.9, 3.3), V(s * 0.4, 8.6, 5.6), 0.25, dark, M.Metal)
	end
	add(m, "Block", V(1.6, 0.4, 0.6), V(0, 8.6, 5.7), dark, M.Metal)
	-- electric motor + belt guard
	add(m, "CylZ", V(1.4, 1.4, 2.0), V(0, 1.5, 6.8), C(60, 100, 160), M.Metal)
	add(m, "Block", V(0.5, 2.2, 3), V(-1.2, 2.0, 5.6), steel, M.DiamondPlate)
end

B.Pyramid = function(m)
	local sand = C(215, 185, 125)
	-- smooth-ish sides from many thin layers, a darker weathered base, gold capstone
	local layers, size, h = 26, 30, 19
	for i = 0, layers - 1 do
		local t = i / layers
		local w = size * (1 - t)
		add(m, "Block", V(w, h / layers + 0.02, w), V(0, h / layers * (i + 0.5), 0), sand:Lerp(C(245, 225, 175), t * 0.5), M.Sandstone)
	end
	add(m, "Block", V(size + 1, 0.4, size + 1), V(0, 0.2, 0), C(200, 170, 115), M.Sand)
	-- capstone
	for i = 0, 3 do
		local w = 1.6 * (1 - i / 4)
		add(m, "Block", V(w, 0.35, w), V(0, h + 0.17 + i * 0.35, 0), C(255, 205, 70), M.Foil, { Reflectance = 0.3 })
	end
	-- entrance on the north face
	add(m, "Block", V(2.4, 2.8, 2), V(0, 4.6, -11.2), C(60, 45, 30))
	add(m, "Wedge", V(3.2, 1.2, 2.2), CFrame.new(0, 6.6, -11.2) * CFrame.Angles(0, math.pi, 0), C(200, 170, 115), M.Sandstone)
	-- a few broken blocks at the foot
	for _, p in ipairs({ V(-13, 0.6, -14), V(12, 0.5, -15), V(15, 0.6, 9) }) do
		add(m, "Block", V(1.4, 1.1, 1.2), rot(p, 0, 25, 8), sand, M.Sandstone)
	end
end

-- Zone 6 · Jungle ─────────────────────────────────
B.PalmTree = function(m)
	local trunk = C(140, 110, 75)
	-- curved, ringed trunk
	local pts = {}
	for i = 0, 10 do
		local t = i / 10
		table.insert(pts, V(math.sin(t * 1.4) * 2.6, t * 17, 0))
	end
	for i = 1, #pts - 1 do
		local d = 1.5 - i * 0.06
		rod(m, pts[i], pts[i + 1], d, trunk, M.Wood)
		add(m, "Cyl", V(d + 0.25, 0.25, d + 0.25), CFrame.lookAt(pts[i], pts[i + 1]) * CFrame.Angles(math.rad(-90), 0, 0), trunk:Lerp(C(0, 0, 0), 0.25), M.Wood)
	end
	local top = pts[#pts]
	-- coconuts
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		add(m, "Ball", V(0.9, 0.9, 0.9), top + V(math.cos(a) * 0.6, -0.7, math.sin(a) * 0.6), C(95, 70, 40))
	end
	-- 11 drooping fronds: 3 segments each
	for i = 0, 10 do
		local a = i / 11 * math.pi * 2 + 0.2
		local dir = V(math.cos(a), 0, math.sin(a))
		local p0 = top + V(0, 0.4, 0)
		local p1 = p0 + dir * 2.6 + V(0, 1.0, 0)
		local p2 = p1 + dir * 2.8 + V(0, -0.4, 0)
		local p3 = p2 + dir * 2.4 + V(0, -1.9, 0)
		for k, seg in ipairs({ { p0, p1 }, { p1, p2 }, { p2, p3 } }) do
			local a0, b0 = seg[1], seg[2]
			local w = 2.0 - k * 0.45
			local cf = CFrame.lookAt((a0 + b0) / 2, b0)
			add(m, "Block", V(w, 0.08, (b0 - a0).Magnitude + 0.1), cf, C(60, 145, 55):Lerp(C(110, 170, 70), k / 4))
			add(m, "Block", V(0.12, 0.12, (b0 - a0).Magnitude), cf, C(90, 120, 55))
		end
	end
end

B.TikiStatue = function(m)
	local wood = C(130, 85, 50)
	local dark = wood:Lerp(C(0, 0, 0), 0.35)
	-- carved log body with grooves
	add(m, "Cyl", V(4.2, 11, 4.2), V(0, 5.5, 0), wood, M.Wood)
	for _, y in ipairs({ 1.5, 4.8, 10.6 }) do
		add(m, "Cyl", V(4.35, 0.25, 4.35), V(0, y, 0), dark, M.Wood)
	end
	-- headdress
	add(m, "Cyl", V(4.8, 0.8, 4.8), V(0, 11.3, 0), C(190, 60, 40), M.Wood)
	for i = 0, 6 do
		local a = math.rad(-150 + i * 20)
		add(m, "Wedge", V(0.5, 2.2, 0.6), CFrame.new(math.cos(a) * 2.0, 12.7, math.sin(a) * 2.0) * CFrame.Angles(0, -a - math.pi / 2, 0), i % 2 == 0 and C(60, 150, 70) or C(240, 200, 60))
	end
	-- face (front = -Z): heavy brow, big eyes, wide nose, grimacing mouth with teeth
	add(m, "Block", V(3.4, 0.6, 0.6), V(0, 9.1, -1.95), dark, M.Wood)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ell", V(1.0, 0.9, 0.3), V(s * 0.9, 8.3, -2.05), C(240, 230, 200))
		add(m, "Ell", V(0.45, 0.45, 0.2), V(s * 0.9, 8.3, -2.18), C(25, 20, 15))
		add(m, "Block", V(0.4, 2.2, 1.4), V(s * 2.15, 7.5, -0.3), wood, M.Wood)
	end
	add(m, "Wedge", V(1.0, 1.4, 0.7), CFrame.new(0, 7.3, -2.25) * CFrame.Angles(0, math.pi, 0), wood, M.Wood)
	add(m, "Block", V(2.6, 1.0, 0.4), V(0, 5.9, -2.05), C(30, 20, 15))
	for i = -2, 2 do
		add(m, "Block", V(0.35, 0.35, 0.2), V(i * 0.48, 6.25, -2.22), C(240, 235, 220))
	end
	-- arms on the belly + grass skirt
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(1.6, 0.6, 0.5), V(s * 0.9, 3.7, -2.1), dark, M.Wood)
	end
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		add(m, "Block", V(0.4, 2.2, 0.12), CFrame.new(math.cos(a) * 2.2, 1.6, math.sin(a) * 2.2) * CFrame.Angles(0, -a + math.pi / 2, math.rad(5)), C(170, 160, 80), M.Fabric)
	end
end

B.Treehouse = function(m)
	local bark = C(105, 75, 50)
	local plank = C(160, 115, 70)
	local leafy = mat("LeafyGrass", M.Grass)
	-- big trunk + branches
	cone(m, 0, 22, 2.2, 1.2, 14, bark, M.Wood)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + 0.4
		rod(m, V(0, 0.5, 0), V(math.cos(a) * 3, 0, math.sin(a) * 3), 0.9, bark, M.Wood)
		rod(m, V(0, 16, 0), V(math.cos(a) * 5, 21, math.sin(a) * 5), 0.8, bark, M.Wood)
	end
	-- platform with supports and railing
	add(m, "Block", V(12, 0.5, 12), V(0, 10, 0), plank, M.WoodPlanks)
	for _, s in ipairs({ -1, 1 }) do
		rod(m, V(s * 1.1, 6.5, 0), V(s * 5.5, 9.8, 0), 0.4, bark, M.Wood)
		rod(m, V(0, 6.5, s * 1.1), V(0, 9.8, s * 5.5), 0.4, bark, M.Wood)
	end
	for i = 0, 11 do
		local x = -5.6 + i * (11.2 / 11)
		for _, z in ipairs({ -5.8, 5.8 }) do
			add(m, "Block", V(0.2, 1.4, 0.2), V(x, 10.9, z), plank, M.Wood)
		end
		add(m, "Block", V(0.2, 1.4, 0.2), V(5.8, 10.9, x), plank, M.Wood)
	end
	add(m, "Block", V(11.6, 0.25, 0.25), V(0, 11.6, -5.8), plank, M.Wood)
	add(m, "Block", V(11.6, 0.25, 0.25), V(0, 11.6, 5.8), plank, M.Wood)
	add(m, "Block", V(0.25, 0.25, 11.6), V(5.8, 11.6, 0), plank, M.Wood)
	-- the hut: plank walls, door, window, shingle roof
	add(m, "Block", V(6.5, 4.5, 6), V(-1.6, 12.5, 0.5), plank:Lerp(C(255, 255, 255), 0.08), M.WoodPlanks)
	add(m, "Block", V(1.6, 2.6, 0.2), V(-0.4, 11.55, -2.55), C(80, 55, 35), M.Wood)
	window(m, CFrame.new(-3.2, 13, -2.55), 1.3, 1.1, C(130, 90, 55))
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(7.4, 0.3, 4.0), CFrame.new(-1.6, 15.6, 0.5 + s * 1.6) * CFrame.Angles(math.rad(s * 32), 0, 0), C(140, 55, 45), ROOF)
	end
	-- rope ladder
	for _, x in ipairs({ 3.5, 4.5 }) do
		rod(m, V(x, 0.2, -6), V(x, 10, -6), 0.08, C(200, 180, 130), M.Fabric)
	end
	for i = 0, 8 do
		add(m, "Block", V(1.2, 0.15, 0.3), V(4, 0.8 + i * 1.05, -6), plank, M.Wood)
	end
	-- leafy canopy
	local greens = { C(60, 120, 45), C(75, 140, 55), C(50, 105, 40) }
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		add(m, "Ell", V(6, 4.4, 6), V(math.cos(a) * 4.5, 21.5 + (i % 2), math.sin(a) * 4.5), greens[i % 3 + 1], leafy)
	end
	add(m, "Ell", V(9, 6, 9), V(0, 23.5, 0), greens[2], leafy)
end

-- Zone 8 · Volcano ────────────────────────────────
B.LavaRock = function(m)
	local rock = C(45, 35, 33)
	local lava = C(255, 95, 20)
	-- craggy basalt boulder from overlapping tilted chunks, glowing cracks
	local rng = Random.new(21)
	add(m, "Ell", V(9, 7, 8.5), V(0, 3.4, 0), rock, M.Basalt)
	for _ = 1, 9 do
		local dir = V(rng:NextNumber(-1, 1), rng:NextNumber(-0.1, 1), rng:NextNumber(-1, 1)).Unit
		local s = rng:NextNumber(2.4, 4)
		add(m, "Block", V(s, s * 0.8, s * 0.9), CFrame.new(V(0, 3.4, 0) + dir * 3.2) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)), rock:Lerp(C(0, 0, 0), rng:NextNumber(0, 0.3)), M.Basalt)
	end
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2
		local p = V(math.cos(a) * 4.3, 2.5 + (i % 3) * 1.2, math.sin(a) * 4.0)
		neon(m, "Block", V(0.25, 2.6, 0.25), CFrame.lookAt(p, V(0, 3.4, 0)) * CFrame.Angles(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)), lava)
	end
	neon(m, "Ell", V(2.4, 0.4, 2.0), V(0.6, 6.9, -0.4), lava)
	local light = Instance.new("PointLight")
	light.Color = lava
	light.Range = 16
	light.Brightness = 1.5
	light.Parent = m:FindFirstChildWhichIsA("BasePart")
end

B.MagmaCrystal = function(m)
	local glow = C(255, 110, 30)
	-- basalt base
	add(m, "Ell", V(7, 1.8, 6.5), V(0, 0.6, 0), C(40, 32, 30), M.Basalt)
	-- cluster of hexagonal crystals: dark glassy shell + glowing core + pointed tip
	local pieces = { { 1.8, 11, 0, 0, 0 }, { 1.3, 7.5, 1.9, 0.6, -22 }, { 1.3, 6.5, -1.7, -0.5, 24 }, { 1.0, 5, 0.4, -1.8, -15 }, { 1.0, 4.4, -0.6, 1.7, 18 } }
	for _, p in ipairs(pieces) do
		local d, h, x, z, tilt = p[1], p[2], p[3], p[4], p[5]
		local cf = CFrame.new(x, 1.0, z) * CFrame.Angles(math.rad(tilt * 0.4), math.rad(tilt * 3), math.rad(tilt)) * CFrame.new(0, h / 2, 0)
		for k = 0, 2 do
			add(m, "Block", V(d, h, d * 0.58), cf * CFrame.Angles(0, math.rad(k * 60), 0), C(120, 30, 15), M.Glass, { Transparency = 0.25, Reflectance = 0.3 })
		end
		neon(m, "Block", V(d * 0.5, h * 0.92, d * 0.3), cf, glow)
		for k = 0, 2 do
			add(m, "Wedge", V(d * 0.58, d * 0.9, d * 0.5), cf * CFrame.new(0, h / 2 + d * 0.45, 0) * CFrame.Angles(0, math.rad(k * 120), 0) * CFrame.new(0, 0, d * 0.25) * CFrame.Angles(0, math.pi, 0), C(255, 140, 50), M.Neon)
		end
	end
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 22
	light.Brightness = 2
	light.Parent = m:FindFirstChildWhichIsA("BasePart")
end

-- Zone 9 · Summit ─────────────────────────────────
B.SnowCastle = function(m)
	local snow = C(240, 246, 255)
	local ice = C(170, 215, 245)
	-- snowy hill, curtain walls with crenellations, 4 round towers with ice cones, central keep
	add(m, "Ell", V(30, 3, 30), V(0, 0.3, 0), snow, M.Snow)
	local function crenel(cf, len)
		local n = math.floor(len / 2.4)
		for i = 0, n - 1 do
			add(m, "Block", V(0.9, 0.9, 1.0), cf * CFrame.new(-len / 2 + (i + 0.5) * (len / n), 0, 0), snow, M.Snow)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(18, 7, 1.6), V(0, 4.8, s * 9), snow, M.Snow)
		add(m, "Block", V(1.6, 7, 18), V(s * 9, 4.8, 0), snow, M.Snow)
		crenel(CFrame.new(0, 8.75, s * 9), 16)
		crenel(CFrame.new(s * 9, 8.75, 0) * CFrame.Angles(0, math.rad(90), 0), 16)
	end
	for _, x in ipairs({ -9, 9 }) do
		for _, z in ipairs({ -9, 9 }) do
			add(m, "Cyl", V(4.4, 12, 4.4), V(x, 7.3, z), snow, M.Snow)
			add(m, "Cyl", V(5.0, 0.8, 5.0), V(x, 13.6, z), C(225, 235, 250), M.Snow)
			cone(m, 14.0, 5.5, 2.6, 0.1, 14, ice, M.Ice, x, z)
			window(m, CFrame.new(x, 10, z - 2.25), 0.7, 1.2, C(200, 220, 240))
		end
	end
	add(m, "Block", V(8, 13, 8), V(0, 7.8, 2), snow, M.Snow)
	crenel(CFrame.new(0, 14.75, -2), 7)
	cone(m, 14.3, 7, 4.6, 0.2, 16, ice, M.Ice, 0, 2)
	-- gate with ice portcullis, icicles, flag
	add(m, "Block", V(4, 5, 0.6), V(0, 3.5, -9.6), C(120, 170, 220), M.Ice, { Transparency = 0.2 })
	add(m, "Ell", V(4, 2.0, 0.65), V(0, 6.0, -9.6), C(120, 170, 220), M.Ice, { Transparency = 0.2 })
	for i = -7, 7, 2 do
		add(m, "Wedge", V(0.4, 1.2, 0.4), CFrame.new(i, 7.6, -9.95) * CFrame.Angles(math.pi, 0, 0), C(210, 235, 255), M.Ice)
	end
	rod(m, V(0, 21, 2), V(0, 25, 2), 0.15, C(120, 120, 130), M.Metal)
	add(m, "Block", V(0.06, 1.2, 2), V(0, 24.3, 1), C(80, 160, 255), M.Fabric)
end

-- Zone 10 · Outer Space ───────────────────────────
B.Satellite = function(m)
	local gold = C(215, 175, 70)
	local panel = C(30, 45, 110)
	-- bus wrapped in gold foil, solar wings with cells, dish, antennas, thrusters
	add(m, "Block", V(4, 4.4, 4), V(0, 4.6, 0), gold, M.Foil, { Reflectance = 0.25 })
	add(m, "Block", V(4.1, 0.3, 4.1), V(0, 6.9, 0), C(220, 220, 225), M.Metal)
	add(m, "Block", V(4.1, 0.3, 4.1), V(0, 2.3, 0), C(220, 220, 225), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		rod(m, V(s * 2, 4.6, 0), V(s * 3.2, 4.6, 0), 0.3, C(180, 180, 190), M.Metal)
		for k = 0, 2 do
			local x = s * (3.4 + k * 2.6 + 1.25)
			add(m, "Block", V(2.5, 0.12, 3.6), V(x, 4.6, 0), panel, M.Glass, { Reflectance = 0.35 })
			add(m, "Block", V(2.55, 0.1, 3.65), V(x, 4.55, 0), C(200, 200, 210), M.Metal)
			for c = -1, 1 do
				add(m, "Block", V(0.05, 0.14, 3.6), V(x + c * 0.83, 4.62, 0), C(150, 160, 190), M.Metal)
			end
		end
	end
	-- high-gain dish
	rod(m, V(0, 6.9, 0), V(0, 8.2, 0), 0.25, C(200, 200, 210), M.Metal)
	add(m, "Ell", V(3.6, 0.9, 3.6), CFrame.new(0, 8.6, -0.3) * CFrame.Angles(math.rad(-25), 0, 0), C(235, 235, 240), M.Metal)
	rod(m, V(0, 8.7, -0.4), V(0, 9.9, -1.0), 0.1, C(150, 150, 160), M.Metal)
	-- antennas + thrusters
	for _, p in ipairs({ V(1.6, 7.0, 1.6), V(-1.6, 7.0, -1.6) }) do
		rod(m, p, p + V(0, 2.2, 0), 0.08, C(220, 220, 225), M.Metal)
	end
	for _, p in ipairs({ V(1.4, 2.0, 1.4), V(-1.4, 2.0, 1.4), V(1.4, 2.0, -1.4), V(-1.4, 2.0, -1.4) }) do
		cone(m, p.Y - 0.8, 0.8, 0.35, 0.15, 4, C(90, 90, 95), M.Metal, p.X, p.Z)
	end
	neon(m, "Ball", V(0.3, 0.3, 0.3), V(1.6, 9.3, 1.6), C(255, 50, 50))
	add(m, "Cyl", V(1.6, 1.4, 1.6), V(0, 0.7, 0), C(120, 120, 130), M.Metal)
end

B.UFO = function(m)
	local hull = C(175, 180, 192)
	-- classic saucer: two stacked lens shapes, rim lights, glass dome with pilot, landing legs, tractor beam
	add(m, "Ell", V(20, 3.0, 20), V(0, 4.0, 0), hull, M.Metal, { Reflectance = 0.25 })
	add(m, "Ell", V(14, 2.4, 14), V(0, 5.2, 0), hull:Lerp(C(255, 255, 255), 0.15), M.Metal, { Reflectance = 0.25 })
	add(m, "Ell", V(9, 1.8, 9), V(0, 2.9, 0), hull:Lerp(C(0, 0, 0), 0.25), M.Metal)
	add(m, "Cyl", V(20.2, 0.3, 20.2), V(0, 4.0, 0), C(80, 85, 100), M.Metal)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		neon(m, "Ball", V(0.7, 0.7, 0.7), V(math.cos(a) * 9.6, 4.0, math.sin(a) * 9.6), i % 2 == 0 and C(255, 220, 60) or C(80, 255, 170))
	end
	add(m, "Ell", V(7.5, 6, 7.5), V(0, 6.6, 0), C(140, 230, 255), M.Glass, { Transparency = 0.45, Reflectance = 0.35 })
	-- little green pilot
	add(m, "Ell", V(1.4, 1.6, 1.2), V(0, 7.0, 0), C(110, 220, 110))
	add(m, "Ell", V(1.5, 1.3, 1.3), V(0, 8.2, 0), C(110, 220, 110))
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ell", V(0.5, 0.35, 0.15), V(s * 0.35, 8.3, -0.62), C(15, 15, 20))
	end
	-- landing legs + glowing beam emitter
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		rod(m, V(math.cos(a) * 5, 3, math.sin(a) * 5), V(math.cos(a) * 6.5, 0.4, math.sin(a) * 6.5), 0.4, C(120, 120, 130), M.Metal)
		add(m, "Cyl", V(1.2, 0.3, 1.2), V(math.cos(a) * 6.5, 0.2, math.sin(a) * 6.5), C(90, 90, 100), M.Metal)
	end
	neon(m, "Cyl", V(4, 0.3, 4), V(0, 2.0, 0), C(140, 255, 180))
	add(m, "Cyl", V(3.6, 1.8, 3.6), V(0, 1.0, 0), C(140, 255, 180), M.Neon, { Transparency = 0.7 })
end

B.SpaceStation = function(m)
	local white = C(232, 234, 240)
	local panel = C(35, 50, 120)
	-- long truss with solar arrays, pressurized modules in a cross, radiators
	rod(m, V(-15, 9, 0), V(15, 9, 0), 0.8, C(170, 172, 180), M.Metal)
	for x = -14, 14, 2 do
		add(m, "Block", V(0.15, 1.1, 1.1), V(x, 9, 0), C(150, 152, 160), M.Metal)
	end
	for _, x in ipairs({ -12, -8, 8, 12 }) do
		for _, s in ipairs({ -1, 1 }) do
			add(m, "Block", V(2.6, 0.12, 7), V(x, 9, s * 4.2), panel, M.Glass, { Reflectance = 0.35 })
			add(m, "Block", V(2.65, 0.1, 7.05), V(x, 8.94, s * 4.2), C(210, 180, 80), M.Foil)
			for k = -3, 3 do
				add(m, "Block", V(2.6, 0.14, 0.06), V(x, 9.01, s * 4.2 + k * 1), C(160, 170, 200), M.Metal)
			end
		end
	end
	-- modules
	for _, z in ipairs({ -6, -2, 2 }) do
		add(m, "CylZ", V(2.6, 2.6, 3.6), V(0, 7.2, z), white, M.Metal)
		add(m, "CylZ", V(2.7, 2.7, 0.3), V(0, 7.2, z - 1.8), C(190, 192, 200), M.Metal)
	end
	add(m, "Ball", V(3.2, 3.2, 3.2), V(0, 7.2, 4.2), white, M.Metal)
	add(m, "CylX", V(5, 2.4, 2.4), V(-3.6, 7.2, 4.2), white, M.Metal)
	add(m, "CylX", V(5, 2.4, 2.4), V(3.6, 7.2, 4.2), white, M.Metal)
	add(m, "CylZ", V(2.2, 2.2, 3), V(0, 7.2, 7.2), C(210, 180, 80), M.Foil)
	-- radiators + docked capsule + robotic arm
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(0.1, 3.4, 2.2), V(s * 5, 10.6, 0), C(245, 245, 248), M.Metal)
	end
	add(m, "Ball", V(1.6, 1.6, 1.6), V(0, 7.2, -8.6), C(240, 240, 245), M.Metal)
	cone(m, 6.6, 1.2, 0.9, 0.4, 5, C(60, 60, 65), M.Metal, 0, -9.6)
	rod(m, V(1.6, 8.4, 2), V(3.5, 11, 0), 0.25, white, M.Metal)
	rod(m, V(3.5, 11, 0), V(5.5, 10, -2), 0.25, white, M.Metal)
	neon(m, "Ball", V(0.4, 0.4, 0.4), V(15, 9, 0), C(255, 60, 60))
	neon(m, "Ball", V(0.4, 0.4, 0.4), V(-15, 9, 0), C(60, 255, 60))
	add(m, "Cyl", V(1.2, 6, 1.2), V(0, 3, 0), C(110, 110, 120), M.Metal)
end

-- Royal Crate exclusives (Robux only) ──────────────
B.KingDuck = function(m)
	local yellow = C(255, 205, 40)
	local orange = C(255, 130, 20)
	-- rubber duck: rounded body with a raised tail, head, flat beak, wing bumps
	add(m, "Ell", V(4.2, 3.0, 5.0), V(0, 1.6, 0.2), yellow, RUBBER, { Reflectance = 0.15 })
	add(m, "Ell", V(1.6, 1.6, 1.8), rot(V(0, 2.4, 2.5), -30, 0, 0), yellow, RUBBER, { Reflectance = 0.15 })
	add(m, "Ball", V(2.7, 2.7, 2.7), V(0, 4.1, -1.2), yellow, RUBBER, { Reflectance = 0.15 })
	add(m, "Ell", V(1.5, 0.45, 1.3), V(0, 3.8, -2.7), orange, RUBBER)
	add(m, "Ell", V(1.3, 0.3, 1.1), V(0, 3.55, -2.6), orange:Lerp(C(0, 0, 0), 0.15), RUBBER)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ell", V(0.5, 1.6, 2.6), rot(V(s * 2.0, 1.9, 0.4), 10, 0, s * -10), yellow:Lerp(C(255, 160, 0), 0.15), RUBBER)
		add(m, "Ell", V(0.55, 0.7, 0.3), V(s * 0.65, 4.55, -2.35), C(255, 255, 255))
		add(m, "Ell", V(0.3, 0.42, 0.2), V(s * 0.68, 4.5, -2.48), C(20, 20, 25), M.SmoothPlastic, { Reflectance = 0.4 })
	end
	-- golden crown with jewels + red cape
	add(m, "Cyl", V(1.9, 0.6, 1.9), V(0, 5.6, -1.2), C(255, 200, 40), M.Foil, { Reflectance = 0.3 })
	for i = 0, 4 do
		local a = i / 5 * math.pi * 2
		add(m, "Wedge", V(0.45, 0.8, 0.35), CFrame.new(math.cos(a) * 0.8, 6.2, -1.2 + math.sin(a) * 0.8) * CFrame.Angles(0, -a + math.pi / 2, 0), C(255, 200, 40), M.Foil)
		neon(m, "Ball", V(0.22, 0.22, 0.22), V(math.cos(a) * 0.98, 5.6, -1.2 + math.sin(a) * 0.98), i % 2 == 0 and C(255, 40, 80) or C(60, 140, 255))
	end
	add(m, "Ell", V(3.6, 2.2, 0.3), rot(V(0, 2.6, 2.0), 20, 0, 0), C(170, 20, 40), M.Fabric)
	add(m, "Ell", V(3.7, 0.4, 0.4), rot(V(0, 3.6, 1.6), 20, 0, 0), C(250, 250, 250), M.Fabric)
end

B.GoldenToilet = function(m)
	local gold = C(255, 200, 60)
	local shiny = { Reflectance = 0.35 }
	-- pedestal base, rounded bowl, seat + lid, tank with flush lever
	add(m, "Ell", V(2.2, 2.4, 2.6), V(0, 1.0, 0.5), gold, M.Foil, shiny)
	add(m, "Cyl", V(2.0, 0.3, 2.4), V(0, 0.15, 0.5), gold, M.Foil, shiny)
	add(m, "Ell", V(3.2, 1.6, 3.8), V(0, 2.4, -0.2), gold, M.Foil, shiny)
	add(m, "Ell", V(2.6, 0.4, 3.1), V(0, 3.15, -0.25), C(255, 250, 240), M.Marble)
	add(m, "Ell", V(2.0, 0.3, 2.4), V(0, 3.25, -0.3), C(90, 160, 220), M.Glass, { Transparency = 0.2 })
	add(m, "Ell", V(2.9, 2.6, 0.3), rot(V(0, 4.4, 1.25), -12, 0, 0), gold, M.Foil, shiny)
	rbox(m, V(3.0, 2.8, 1.3), V(0, 4.6, 2.1), 0.3, gold, M.Foil, shiny)
	rbox(m, V(3.2, 0.3, 1.5), V(0, 6.1, 2.1), 0.3, gold:Lerp(C(255, 255, 255), 0.2), M.Foil, shiny)
	add(m, "Block", V(0.6, 0.15, 0.2), V(1.1, 5.4, 1.4), C(240, 240, 245), M.Metal)
	-- jewels on the tank
	for i = -1, 1 do
		neon(m, "Ball", V(0.3, 0.3, 0.3), V(i * 0.7, 4.8, 1.43), i == 0 and C(255, 40, 80) or C(60, 220, 255))
	end
	local sparkle = Instance.new("Sparkles")
	sparkle.SparkleColor = gold
	sparkle.Parent = m:FindFirstChildWhichIsA("BasePart")
end

B.NeonUnicorn = function(m)
	local body = C(255, 140, 225)
	local glow = { Transparency = 0 }
	-- horse body (front = -Z): barrel, chest, rump, slender legs with hooves
	add(m, "Ell", V(2.3, 2.3, 4.4), V(0, 3.6, 0), body, M.Neon, glow)
	add(m, "Ell", V(2.1, 2.2, 1.8), V(0, 3.9, -1.7), body, M.Neon)
	add(m, "Ell", V(2.2, 2.2, 1.9), V(0, 3.8, 1.8), body, M.Neon)
	for _, x in ipairs({ -0.65, 0.65 }) do
		for _, z in ipairs({ -1.6, 1.7 }) do
			rod(m, V(x, 3.0, z), V(x, 1.4, z + 0.1), 0.55, body, M.Neon)
			rod(m, V(x, 1.4, z + 0.1), V(x, 0.35, z), 0.42, body, M.Neon)
			add(m, "Cyl", V(0.55, 0.35, 0.55), V(x, 0.18, z), C(255, 230, 120), M.Neon)
		end
	end
	-- neck, head, muzzle, ears, horn
	rod(m, V(0, 4.5, -2.0), V(0, 6.2, -2.9), 1.1, body, M.Neon)
	add(m, "Ell", V(1.1, 1.2, 2.0), rot(V(0, 6.4, -3.5), 25, 0, 0), body, M.Neon)
	add(m, "Ell", V(0.9, 0.8, 0.9), V(0, 5.9, -4.3), body:Lerp(C(255, 255, 255), 0.3), M.Neon)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Wedge", V(0.25, 0.6, 0.35), V(s * 0.35, 7.2, -3.0), body, M.Neon)
		add(m, "Ell", V(0.12, 0.3, 0.2), V(s * 0.52, 6.6, -3.9), C(30, 20, 40))
	end
	for i = 0, 4 do
		local t = i / 4
		add(m, "Cyl", V(0.38 - t * 0.3, 0.4, 0.38 - t * 0.3), rot(V(0, 7.3 + i * 0.36, -3.6 - i * 0.18), -25, 0, 0), C(255, 235, 120), M.Neon)
	end
	-- rainbow mane and tail
	for i = 0, 5 do
		local col = Color3.fromHSV(i / 6, 0.75, 1)
		add(m, "Ell", V(0.35, 0.9, 0.6), rot(V(0, 6.9 - i * 0.42, -3.0 + i * 0.25), 30, 0, 0), col, M.Neon)
		add(m, "Ell", V(0.35, 1.0, 0.5), rot(V(0, 3.9 - i * 0.35, 3.0 + i * 0.12), -30, 0, 0), col, M.Neon)
	end
end

B.DragonEgg = function(m)
	local shell = C(90, 30, 160)
	-- nest of twigs, egg with overlapping scale plates and glowing cracks
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		rod(m, V(math.cos(a) * 2.2, 0.5, math.sin(a) * 2.2), V(math.cos(a + 1.2) * 2.0, 0.9, math.sin(a + 1.2) * 2.0), 0.3, C(120, 85, 50), M.Wood)
	end
	add(m, "Cyl", V(3.8, 0.6, 3.8), V(0, 0.3, 0), C(90, 65, 40), M.Wood)
	add(m, "Ell", V(3.4, 4.8, 3.4), V(0, 3.0, 0), shell, M.Slate)
	local rng = Random.new(8)
	for row = 0, 4 do
		local y = 1.4 + row * 0.75
		local rr = 1.7 * math.sqrt(math.max(0.05, 1 - ((y - 3.0) / 2.4) ^ 2))
		for k = 0, 7 do
			local a = (k + (row % 2) * 0.5) / 8 * math.pi * 2
			add(m, "Ell", V(0.9, 0.9, 0.25), CFrame.lookAt(V(math.cos(a) * rr, y, math.sin(a) * rr), V(math.cos(a) * rr * 2, y + 0.4, math.sin(a) * rr * 2)), shell:Lerp(C(200, 120, 255), rng:NextNumber(0, 0.35)), M.Slate)
		end
	end
	for _, seg in ipairs({ { V(0.6, 4.6, -1.3), V(0.1, 3.6, -1.6) }, { V(0.1, 3.6, -1.6), V(0.7, 2.7, -1.55) }, { V(0.7, 2.7, -1.55), V(0.2, 1.9, -1.35) } }) do
		neon(m, "Block", V(0.12, 0.12, (seg[2] - seg[1]).Magnitude), CFrame.lookAt((seg[1] + seg[2]) / 2, seg[2]), C(255, 160, 40))
	end
	local fire = Instance.new("Fire")
	fire.Size = 2
	fire.Heat = 2
	fire.Color = C(170, 80, 255)
	fire.Parent = m:FindFirstChildWhichIsA("BasePart")
end

B.GalaxyOrb = function(m)
	-- ornate stand with claws holding a swirling galaxy sphere
	add(m, "Cyl", V(3.4, 0.6, 3.4), V(0, 0.3, 0), C(40, 30, 60), M.Metal)
	cone(m, 0.6, 1.4, 1.2, 0.6, 6, C(200, 170, 80), M.Foil)
	add(m, "Cyl", V(1.9, 0.3, 1.9), V(0, 2.1, 0), C(200, 170, 80), M.Foil)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2
		rod(m, V(math.cos(a) * 0.8, 2.1, math.sin(a) * 0.8), V(math.cos(a) * 1.9, 3.6, math.sin(a) * 1.9), 0.22, C(200, 170, 80), M.Foil)
	end
	add(m, "Ball", V(4.4, 4.4, 4.4), V(0, 4.3, 0), C(40, 20, 110), M.Glass, { Transparency = 0.3, Reflectance = 0.3 })
	-- spiral arms of stars inside
	for arm = 0, 2 do
		for k = 0, 8 do
			local t = k / 8
			local a = arm / 3 * math.pi * 2 + t * 3.2
			local rr = 0.2 + t * 1.6
			neon(m, "Ball", V(0.3 - t * 0.15, 0.3 - t * 0.15, 0.3 - t * 0.15), V(math.cos(a) * rr, 4.3 + math.sin(t * 6) * 0.15, math.sin(a) * rr), Color3.fromHSV(0.7 + t * 0.2, 0.5, 1))
		end
	end
	neon(m, "Ball", V(0.8, 0.8, 0.8), V(0, 4.3, 0), C(255, 230, 255))
	add(m, "Ell", V(5.8, 0.12, 5.8), rot(V(0, 4.3, 0), 18, 0, 10), C(200, 160, 255), M.Neon, { Transparency = 0.5 })
	local light = Instance.new("PointLight")
	light.Color = C(170, 110, 255)
	light.Range = 16
	light.Brightness = 2
	light.Parent = m:FindFirstChildWhichIsA("BasePart")
end

B._car = function(m, o)
	local paint = o.Paint
	local L, Wd, bh, by = o.Length, o.Width, o.BodyH, o.BodyY
	local top = by + bh
	local trim = C(30, 30, 33)
	local chrome = C(205, 208, 214)
	local shiny = { Reflectance = 0.18 }
	-- lower body with rounded corners, a slightly narrower "shoulder" on top
	rbox(m, V(Wd, bh, L), V(0, by + bh / 2, 0), 0.5, paint, M.SmoothPlastic, shiny)
	rbox(m, V(Wd - 0.1, 0.12, L - 0.3), V(0, top + 0.03, 0), 0.5, paint, M.SmoothPlastic, shiny)
	-- hood bulge and trunk lid
	add(m, "Ell", V(Wd - 0.5, 0.35, L * 0.32), V(0, top, -L * 0.3), paint, M.SmoothPlastic, shiny)
	-- cabin: glass block + sloped windshield/rear glass + roof
	local cz, cl, ch = o.CabinZ, o.CabinLen, o.CabinH
	local cw = Wd - 0.35
	local cy = top + ch / 2
	local tint = C(25, 35, 45)
	add(m, "Block", V(cw, ch, cl), V(0, cy, cz), tint, M.Glass, { Transparency = 0.15, Reflectance = 0.4 })
	local slope = o.Sport and 2.2 or 1.4
	add(m, "Wedge", V(cw, ch, slope), CFrame.new(0, cy, cz - cl / 2 - slope / 2), tint, M.Glass, { Transparency = 0.15, Reflectance = 0.4 })
	add(m, "Wedge", V(cw, ch, slope * 0.9), CFrame.new(0, cy, cz + cl / 2 + slope * 0.45) * CFrame.Angles(0, math.pi, 0), tint, M.Glass, { Transparency = 0.15, Reflectance = 0.4 })
	rbox(m, V(cw + 0.06, 0.14, cl + 0.2), V(0, top + ch + 0.05, cz), 0.4, paint, M.SmoothPlastic, shiny)
	-- pillars (A front, B middle, C rear)
	for _, s in ipairs({ -1, 1 }) do
		local x = s * (cw / 2 + 0.02)
		beam(m, V(x, top, cz - cl / 2 - slope), V(x, top + ch, cz - cl / 2), 0.16, paint)
		beam(m, V(x, top, cz + cl / 2 + slope * 0.9), V(x, top + ch, cz + cl / 2), 0.16, paint)
		if not o.Sport then
			add(m, "Block", V(0.12, ch, 0.22), V(x, cy, cz + 0.1), paint)
		end
		-- door seams, handles, mirrors, side skirt
		add(m, "Block", V(0.03, bh * 0.85, 0.05), V(s * (Wd / 2 + 0.01), by + bh * 0.55, cz - 0.1), trim)
		if not o.Sport then
			add(m, "Block", V(0.03, bh * 0.85, 0.05), V(s * (Wd / 2 + 0.01), by + bh * 0.55, cz + cl / 2 + 0.2), trim)
		end
		add(m, "Block", V(0.08, 0.1, 0.4), V(s * (Wd / 2 + 0.05), top - 0.25, cz - 0.6), chrome, M.Metal)
		add(m, "Ell", V(0.25, 0.32, 0.5), V(s * (cw / 2 + 0.3), top + 0.25, cz - cl / 2 - 0.2), paint, M.SmoothPlastic, shiny)
		add(m, "Block", V(0.06, 0.12, L * 0.55), V(s * (Wd / 2 + 0.02), by + 0.12, 0), trim)
		-- wheel arches (dark) + wheels
		for _, wz in ipairs({ -o.WheelZ, o.WheelZ }) do
			add(m, "CylX", V(0.1, o.Wheel + 0.35, o.Wheel + 0.35), V(s * (Wd / 2 - 0.02), o.Wheel / 2, wz), C(15, 15, 17))
			wheel(m, V(s * (Wd / 2 - 0.25), o.Wheel / 2, wz), o.Wheel, 0.75, nil, o.Sport and C(40, 40, 45) or chrome)
		end
	end
	-- front: bumper, grille, headlights, plate
	local fz = -L / 2
	rbox(m, V(Wd + 0.1, 0.45, 0.5), V(0, by + 0.25, fz - 0.05), 0.25, o.Sport and paint or trim)
	add(m, "Block", V(Wd * 0.45, 0.4, 0.1), V(0, by + bh * 0.55, fz - 0.02), C(18, 18, 20))
	for i = -2, 2 do
		add(m, "Block", V(Wd * 0.45, 0.04, 0.12), V(0, by + bh * 0.55 + i * 0.08, fz - 0.03), chrome, M.Metal)
	end
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Ell", V(0.75, 0.3, 0.2), V(s * (Wd / 2 - 0.55), by + bh * 0.68, fz + 0.02), C(255, 252, 235), M.Neon)
		add(m, "Ell", V(0.85, 0.38, 0.16), V(s * (Wd / 2 - 0.55), by + bh * 0.68, fz + 0.06), chrome, M.Metal)
		add(m, "Block", V(0.4, 0.12, 0.08), V(s * (Wd / 2 - 0.5), by + 0.3, fz - 0.31), C(255, 170, 40), M.Neon)
	end
	local plate = add(m, "Block", V(1.0, 0.32, 0.05), V(0, by + 0.28, fz - 0.33), C(245, 245, 240))
	label(plate, Enum.NormalId.Front, "SHRNK 1", C(20, 40, 120), nil, Enum.Font.Code)
	-- rear: bumper, tail lights, plate, exhaust
	local rz = L / 2
	rbox(m, V(Wd + 0.1, 0.45, 0.5), V(0, by + 0.25, rz + 0.05), 0.25, o.Sport and paint or trim)
	for _, s in ipairs({ -1, 1 }) do
		add(m, "Block", V(0.9, 0.28, 0.08), V(s * (Wd / 2 - 0.6), by + bh * 0.7, rz + 0.01), C(220, 20, 25), M.Neon)
		add(m, "CylZ", V(0.2, 0.2, 0.4), V(s * 0.7, by + 0.1, rz + 0.25), chrome, M.Metal)
	end
	local rplate = add(m, "Block", V(1.0, 0.32, 0.05), V(0, by + bh * 0.55, rz + 0.02), C(245, 245, 240))
	label(rplate, Enum.NormalId.Back, "SHRNK 1", C(20, 40, 120), nil, Enum.Font.Code)
	if o.Sport then
		-- rear wing, side intakes, racing stripes
		for _, s in ipairs({ -1, 1 }) do
			beam(m, V(s * 1.2, top, rz - 0.6), V(s * 1.2, top + 0.6, rz - 0.4), 0.15, trim)
			add(m, "Block", V(0.06, 0.4, 1.2), V(s * (Wd / 2 + 0.02), by + bh * 0.5, 1.6), C(15, 15, 15))
			add(m, "Block", V(0.45, 0.02, L - 0.4), V(s * 0.35, top + 0.1, 0), C(245, 245, 245))
		end
		add(m, "Block", V(Wd - 0.2, 0.1, 0.8), V(0, top + 0.65, rz - 0.45), trim)
	end
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
