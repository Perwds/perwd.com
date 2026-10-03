--[[
	📍 LOCATION: ServerScriptService > Services > MapDecor (ModuleScript)
	(Helper module used by MapService when it generates the map; not a service.)

	Themed scenery for the generated corridor map:
	  Base       · stone path, fountain, trees, flowers, lamps, safe-zone line
	  Zone 1     · Grandpa's Backyard: picket fences, garden beds, sunflowers, shed, Grandpa's cottage
	  Zone 2     · Neighborhood: road + sidewalks, rows of houses, mailboxes, street lamps
	  Zone 3     · Downtown: wide road, crosswalks, city blocks with glowing windows, cones
	  Zone 4     · Harbor: sand, sea with docks, warehouses, crates & barrels, lighthouse
	  Zone 5     · Skyline: giant glass towers, neon edge lights
	  Zone 6     · Summit: snow, rocky peaks, pine forest
	  Walls      · tall checkered walls in each zone's colors with a grass/ice cap
	  Arches     · a sign at the start of every zone (name, Ray Power, who's chasing you)

	Style: bright studded LEGO-like bricks everywhere (MapDecor.Studify runs over the finished map).

	Everything here has CanQuery = false so the Shrink Ray aims straight through it,
	and it stays in the outer strips (|x| > 74) so it never overlaps object spawn points.
]]

local Lighting = game:GetService("Lighting")

local MapDecor = {}

local RGB = Color3.fromRGB

local function part(parent, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

local function deco(parent, size, cframe, color, material, shape)
	local p = part(parent, size, cframe, color, material, shape)
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- vertical cylinder helper (Roblox cylinders run along X)
local function upright(pos, height)
	return CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

-- ── props ─────────────────────────────────────────────────────────────
local function tree(parent, pos, scale, leaf)
	scale = scale or 1
	local trunkH = 8 * scale
	part(parent, Vector3.new(trunkH, 1.8 * scale, 1.8 * scale), upright(pos, trunkH), RGB(120, 80, 45), Enum.Material.Wood, Enum.PartType.Cylinder)
	local leafColor = leaf or RGB(70, 170, 70)
	part(parent, Vector3.one * 9 * scale, CFrame.new(pos + Vector3.new(0, trunkH + 2.5 * scale, 0)), leafColor, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(parent, Vector3.one * 6 * scale, CFrame.new(pos + Vector3.new(2.5 * scale, trunkH + 0.5 * scale, 1.5 * scale)), leafColor:Lerp(RGB(255, 255, 255), 0.1), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(parent, Vector3.one * 5 * scale, CFrame.new(pos + Vector3.new(-2 * scale, trunkH + 1 * scale, -2 * scale)), leafColor:Lerp(RGB(0, 0, 0), 0.08), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

local function pine(parent, pos, scale)
	scale = scale or 1
	part(parent, Vector3.new(6 * scale, 1.5 * scale, 1.5 * scale), upright(pos, 6 * scale), RGB(100, 70, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
	for i, s in ipairs({ 9, 7, 5, 3 }) do
		part(parent, Vector3.new(s * scale, 3 * scale, s * scale), CFrame.new(pos + Vector3.new(0, (4 + i * 2.6) * scale, 0)) * CFrame.Angles(0, math.rad(45 * i), 0), RGB(35, 110, 60), Enum.Material.SmoothPlastic)
	end
	part(parent, Vector3.new(2.4, 1.2, 2.4) * scale, CFrame.new(pos + Vector3.new(0, 15.6 * scale, 0)), RGB(245, 250, 255), Enum.Material.Snow)
end

local function lamp(parent, pos, color)
	part(parent, Vector3.new(14, 0.8, 0.8), upright(pos, 14), RGB(50, 50, 60), Enum.Material.Metal, Enum.PartType.Cylinder)
	local bulb = deco(parent, Vector3.one * 2, CFrame.new(pos + Vector3.new(0, 14.5, 0)), color or RGB(255, 240, 190), Enum.Material.Neon, Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Brightness = 1.3
	light.Color = color or RGB(255, 230, 180)
	light.Parent = bulb
end

local FLOWER_COLORS = { RGB(255, 90, 120), RGB(255, 220, 60), RGB(170, 110, 255), RGB(255, 255, 255), RGB(255, 140, 60) }
local function flowers(parent, pos, radius)
	deco(parent, Vector3.new(0.4, radius * 2, radius * 2), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(90, 60, 40), Enum.Material.Ground, Enum.PartType.Cylinder)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local r = radius * (0.3 + (i % 3) * 0.22)
		deco(parent, Vector3.one * 1.2, CFrame.new(pos + Vector3.new(math.cos(a) * r, 0.9, math.sin(a) * r)), FLOWER_COLORS[(i % #FLOWER_COLORS) + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

local function sunflower(parent, pos)
	deco(parent, Vector3.new(7, 0.4, 0.4), upright(pos, 7), RGB(70, 150, 60), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	deco(parent, Vector3.new(0.4, 2.6, 2.6), CFrame.new(pos + Vector3.new(0, 7.2, 0)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, 0), RGB(255, 210, 40), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	deco(parent, Vector3.new(0.5, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 7.2, 0)) * CFrame.Angles(0, math.rad(90), 0), RGB(110, 70, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
end

local function mailbox(parent, pos, color)
	part(parent, Vector3.new(3.4, 0.4, 0.4), upright(pos, 3.4), RGB(90, 70, 50), Enum.Material.Wood, Enum.PartType.Cylinder)
	part(parent, Vector3.new(1, 1, 1.8), CFrame.new(pos + Vector3.new(0, 3.8, 0)), color or RGB(40, 80, 200))
	deco(parent, Vector3.new(0.1, 0.8, 0.3), CFrame.new(pos + Vector3.new(0.55, 4.2, 0.4)), RGB(230, 40, 40))
end

local function rock(parent, pos, size, color, snow)
	part(parent, size, CFrame.new(pos) * CFrame.Angles(math.rad(math.random(-15, 15)), math.rad(math.random(0, 359)), math.rad(math.random(-15, 15))), color, Enum.Material.Slate)
	if snow then
		part(parent, Vector3.new(size.X * 0.55, size.Y * 0.18, size.Z * 0.55), CFrame.new(pos + Vector3.new(0, size.Y * 0.42, 0)), RGB(245, 250, 255), Enum.Material.Snow)
	end
end

local function crate(parent, pos)
	part(parent, Vector3.one * 5, CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.rad(math.random(0, 90)), 0), RGB(170, 120, 70), Enum.Material.WoodPlanks)
end

local function barrel(parent, pos)
	part(parent, Vector3.new(4.5, 3.2, 3.2), upright(pos, 4.5), RGB(140, 90, 50), Enum.Material.Wood, Enum.PartType.Cylinder)
	for _, y in ipairs({ 1, 3.5 }) do
		deco(parent, Vector3.new(0.3, 3.35, 3.35), CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(70, 70, 75), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

local function cone(parent, pos)
	deco(parent, Vector3.new(2, 0.3, 2), CFrame.new(pos + Vector3.new(0, 0.15, 0)), RGB(255, 120, 20))
	deco(parent, Vector3.new(2.2, 1.2, 1.2), upright(pos, 2.2), RGB(255, 120, 20), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	deco(parent, Vector3.new(0.4, 1.25, 1.25), CFrame.new(pos + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
end

-- ── floor & wall styles ──────────────────────────────────────────────
MapDecor.FloorStyle = {
	[1] = { Material = Enum.Material.Plastic, Color = RGB(105, 215, 50) }, -- Backyard
	[2] = { Material = Enum.Material.Plastic, Color = RGB(120, 222, 70) }, -- Neighborhood
	[3] = { Material = Enum.Material.Plastic, Color = RGB(165, 168, 178) }, -- Downtown
	[4] = { Material = Enum.Material.Plastic, Color = RGB(45, 95, 205) }, -- Harbor (water, with sand islands)
	[5] = { Material = Enum.Material.Plastic, Color = RGB(245, 205, 110) }, -- Desert
	[6] = { Material = Enum.Material.Plastic, Color = RGB(60, 160, 60) }, -- Jungle
	[7] = { Material = Enum.Material.Plastic, Color = RGB(120, 125, 160) }, -- Skyline
	[8] = { Material = Enum.Material.Plastic, Color = RGB(70, 45, 45) }, -- Volcano
	[9] = { Material = Enum.Material.Plastic, Color = RGB(236, 244, 252) }, -- Summit
	[10] = { Material = Enum.Material.Plastic, Color = RGB(55, 40, 95) }, -- Outer Space
}

-- brown "dirt" walls with a grass top (the Steal-an-Egg look), themed per zone
local DIRT = { A = RGB(204, 146, 96), B = RGB(186, 128, 80), Cap = RGB(105, 215, 50), Material = Enum.Material.Plastic }
local WALL_STYLE = {
	Base = DIRT,
	[1] = DIRT,
	[2] = DIRT,
	[3] = { A = RGB(150, 150, 162), B = RGB(130, 130, 142), Cap = RGB(90, 90, 100), Material = Enum.Material.Plastic },
	[4] = { A = RGB(165, 115, 70), B = RGB(145, 100, 60), Cap = RGB(60, 150, 220), Material = Enum.Material.Plastic },
	[5] = { A = RGB(225, 180, 110), B = RGB(205, 160, 95), Cap = RGB(240, 210, 130), Material = Enum.Material.Plastic },
	[6] = { A = RGB(150, 105, 65), B = RGB(130, 90, 55), Cap = RGB(50, 150, 50), Material = Enum.Material.Plastic },
	[7] = { A = RGB(80, 90, 130), B = RGB(66, 74, 112), Cap = RGB(200, 90, 255), Material = Enum.Material.Plastic },
	[8] = { A = RGB(60, 40, 38), B = RGB(48, 32, 30), Cap = RGB(255, 90, 30), Material = Enum.Material.Plastic },
	[9] = { A = RGB(205, 222, 242), B = RGB(182, 202, 228), Cap = RGB(250, 252, 255), Material = Enum.Material.Plastic },
	[10] = { A = RGB(40, 30, 75), B = RGB(30, 22, 60), Cap = RGB(140, 100, 255), Material = Enum.Material.Plastic },
}

-- One straight wall from a to b (XZ), built from alternating checker panels + a cap.
local function wallRun(parent, a, b, height, style)
	local delta = b - a
	local len = delta.Magnitude
	if len < 1 then
		return -- nothing to build (e.g. base and corridor are the same width)
	end
	local dir = delta.Unit
	local panel = 20
	local count = math.max(1, math.floor(len / panel + 0.5))
	local seg = len / count
	for i = 0, count - 1 do
		local mid = a + dir * (seg * (i + 0.5))
		local cf = CFrame.lookAt(mid, mid + dir)
		local lower = part(parent, Vector3.new(2, height / 2, seg), cf * CFrame.new(0, height / 4, 0), (i % 2 == 0) and style.A or style.B, style.Material)
		lower.CanQuery = false
		part(parent, Vector3.new(2, height / 2, seg), cf * CFrame.new(0, height * 3 / 4, 0), (i % 2 == 0) and style.B or style.A, style.Material)
	end
	local cf = CFrame.lookAt(a + delta / 2, b)
	part(parent, Vector3.new(4, 3, len + 2), cf * CFrame.new(0, height + 1.5, 0), style.Cap, Enum.Material.Plastic)
end

-- opts: { BaseWidth, BaseDepth, Corridor, Height, Zones = { {Tier, StartZ, Depth} } }
function MapDecor.Walls(parent, opts)
	local h = opts.Height
	local bw, bd, cw = opts.BaseWidth / 2 + 1, opts.BaseDepth, opts.Corridor / 2 + 1
	local base = WALL_STYLE.Base
	wallRun(parent, Vector3.new(-bw, 0, 0), Vector3.new(-bw, 0, -bd), h, base)
	wallRun(parent, Vector3.new(bw, 0, 0), Vector3.new(bw, 0, -bd), h, base)
	wallRun(parent, Vector3.new(-bw, 0, -bd - 1), Vector3.new(bw, 0, -bd - 1), h, base)
	wallRun(parent, Vector3.new(-bw, 0, 0), Vector3.new(-cw, 0, 0), h, base)
	wallRun(parent, Vector3.new(cw, 0, 0), Vector3.new(bw, 0, 0), h, base)
	local endZ = 0
	for _, z in ipairs(opts.Zones) do
		local style = WALL_STYLE[z.Tier] or base
		wallRun(parent, Vector3.new(-cw, 0, z.StartZ), Vector3.new(-cw, 0, z.StartZ + z.Depth), h, style)
		wallRun(parent, Vector3.new(cw, 0, z.StartZ), Vector3.new(cw, 0, z.StartZ + z.Depth), h, style)
		endZ = z.StartZ + z.Depth
	end
	wallRun(parent, Vector3.new(-cw, 0, endZ + 1), Vector3.new(cw, 0, endZ + 1), h, WALL_STYLE[#opts.Zones] or base)
	-- invisible ceiling-height blockers so nobody climbs out
	for _, x in ipairs({ -cw, cw }) do
		local p = part(parent, Vector3.new(2, 400, endZ), CFrame.new(x, 200 + h, endZ / 2), RGB(0, 0, 0))
		p.Transparency = 1
	end
	for _, x in ipairs({ -bw, bw }) do
		local p = part(parent, Vector3.new(2, 400, bd), CFrame.new(x, 200 + h, -bd / 2), RGB(0, 0, 0))
		p.Transparency = 1
	end
end

-- Floor line at the start of each zone (no big signs: the zones speak for themselves).
function MapDecor.ZoneArch(zone, tier, t, z, width)
	local arch = folder(zone, "Arch")
	local color = t.Color
	-- floor line
	deco(arch, Vector3.new(width - 4, 0.25, tier == 1 and 1 or 3), CFrame.new(0, 0.12, z), tier == 1 and RGB(230, 40, 40) or color, Enum.Material.Neon)
	if tier == 1 then
		-- "SAFE ZONE" painted on the ground just inside the base
		-- turned 180° so the words read the right way up from inside the base (looking out at the zones)
		local paint = deco(arch, Vector3.new(60, 0.1, 9), CFrame.new(0, 0.06, z - 7) * CFrame.Angles(0, math.pi, 0), RGB(255, 255, 255), Enum.Material.SmoothPlastic)
		paint.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 0.3
		gui.Parent = paint
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = RGB(255, 255, 255)
		label.Text = "SAFE ZONE"
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 8
		stroke.Parent = label
		for _, sx in ipairs({ -1, 1 }) do -- blue pills either side
			local pill = deco(arch, Vector3.new(0.12, 3, 7), CFrame.new(sx * 36, 0.07, z - 7) * CFrame.Angles(0, 0, math.rad(90)), RGB(70, 170, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			pill.Name = "SafePill"
		end
	end
end

-- ── zones ────────────────────────────────────────────────────────────
-- Builds a prop at the origin, then shrinks it uniformly and moves it into place (bottom stays on the ground).
local function prop(parent, pos, scale, yaw, build)
	local m = Instance.new("Model")
	m.Name = "Prop"
	build(m)
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	if scale ~= 1 then
		m:ScaleTo(scale)
	end
	m:PivotTo(CFrame.new(pos) * CFrame.Angles(0, math.rad(yaw or 0), 0))
	return m
end
MapDecor.Prop = prop

-- Two-tone "mowed lawn" stripes (alternate stripes slightly lighter), running along Z.
function MapDecor.LawnStripes(parent, x0, x1, z0, z1, color, stripe)
	stripe = stripe or 16
	local f = folder(parent, "LawnStripes")
	local i = 0
	for x = x0, x1 - stripe, stripe do
		i += 1
		if i % 2 == 0 then
			local p = deco(f, Vector3.new(stripe, 0.04, z1 - z0), CFrame.new(x + stripe / 2, 0.02, (z0 + z1) / 2), color, Enum.Material.SmoothPlastic)
			p.CanCollide = false
		end
	end
end

-- Short grass patches: little tufts of 4-6 thin blades (purely visual).
local GRASS_COLORS = { RGB(70, 165, 55), RGB(85, 185, 65), RGB(60, 150, 50) }
function MapDecor.GrassPatches(parent, count, picker)
	local f = folder(parent, "GrassPatches")
	for _ = 1, count do
		local center = picker()
		if center then
			local blades = math.random(4, 6)
			for k = 1, blades do
				local a = k / blades * math.pi * 2 + math.random() * 0.6
				local r = math.random() * 0.7
				local h = 0.6 + math.random() * 0.6
				local pos = center + Vector3.new(math.cos(a) * r, h / 2, math.sin(a) * r)
				deco(f, Vector3.new(0.18, h, 0.18), CFrame.new(pos) * CFrame.Angles(math.rad(math.random(-18, 18)), math.random() * 6, math.rad(math.random(-18, 18))), GRASS_COLORS[math.random(1, #GRASS_COLORS)], Enum.Material.SmoothPlastic)
			end
		end
	end
end

-- Blocky studded bush (a few stacked green bricks).
local function bush(parent, pos, scale, color)
	scale = scale or 1
	color = color or RGB(70, 165, 50)
	local s = scale
	part(parent, Vector3.new(6, 2, 4) * s, CFrame.new(pos + Vector3.new(0, 1 * s, 0)), color, Enum.Material.Plastic)
	part(parent, Vector3.new(4, 2, 3) * s, CFrame.new(pos + Vector3.new(-0.5 * s, 3 * s, 0)), color:Lerp(RGB(0, 0, 0), 0.06), Enum.Material.Plastic)
	part(parent, Vector3.new(2, 2, 2) * s, CFrame.new(pos + Vector3.new(2.6 * s, 1 * s, 2.4 * s)), color:Lerp(RGB(255, 255, 255), 0.06), Enum.Material.Plastic)
end

-- A few SMALL props along the walls only, so the middle of every zone stays wide open.

local function smallProp(decor, kind, pos)
	if kind == "bush" then
		bush(decor, pos, 0.6)
	elseif kind == "flowers" then
		flowers(decor, pos, 1.4)
	elseif kind == "sunflower" then
		sunflower(decor, pos)
	elseif kind == "mailbox" then
		mailbox(decor, pos)
	elseif kind == "cone" then
		cone(decor, pos)
	elseif kind == "lamp" then
		prop(decor, pos, 0.6, 0, function(m)
			lamp(m, Vector3.zero)
		end)
	elseif kind == "crate" then
		prop(decor, pos, 0.6, math.random(0, 90), function(m)
			crate(m, Vector3.zero)
		end)
	elseif kind == "barrel" then
		prop(decor, pos, 0.7, 0, function(m)
			barrel(m, Vector3.zero)
		end)
	elseif kind == "rock" then
		rock(decor, pos + Vector3.new(0, 1, 0), Vector3.new(3, 2.2, 2.6), RGB(120, 110, 105))
	elseif kind == "snowrock" then
		rock(decor, pos + Vector3.new(0, 1, 0), Vector3.new(3, 2.2, 2.6), RGB(140, 145, 160), true)
	elseif kind == "moonrock" then
		rock(decor, pos + Vector3.new(0, 1, 0), Vector3.new(3, 2, 3), RGB(150, 140, 175))
	elseif kind == "pine" then
		pine(decor, pos, 0.45)
	elseif kind == "palm" then
		prop(decor, pos, 0.5, math.random(0, 359), function(m)
			part(m, Vector3.new(10, 1, 1), upright(Vector3.zero, 10), RGB(140, 100, 60), Enum.Material.Wood, Enum.PartType.Cylinder)
			for i = 0, 4 do
				local a = i / 5 * math.pi * 2
				part(m, Vector3.new(6, 0.3, 1.6), CFrame.new(math.cos(a) * 2.6, 9.6, math.sin(a) * 2.6) * CFrame.Angles(0, -a, math.rad(-18)), RGB(60, 170, 60), Enum.Material.Plastic)
			end
		end)
	elseif kind == "cactus" then
		part(decor, Vector3.new(1.4, 4.5, 1.4), CFrame.new(pos + Vector3.new(0, 2.25, 0)), RGB(70, 160, 70), Enum.Material.Plastic)
		part(decor, Vector3.new(1, 2, 1), CFrame.new(pos + Vector3.new(1.1, 2.8, 0)), RGB(70, 160, 70), Enum.Material.Plastic)
		part(decor, Vector3.new(1, 1.6, 1), CFrame.new(pos + Vector3.new(-1.1, 2.2, 0)), RGB(70, 160, 70), Enum.Material.Plastic)
	elseif kind == "bones" then
		deco(decor, Vector3.new(2.4, 0.4, 0.4), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, math.rad(30), 0), RGB(245, 240, 225))
		deco(decor, Vector3.new(0.8, 0.8, 0.8), CFrame.new(pos + Vector3.new(1.3, 0.4, 0.7)), RGB(245, 240, 225), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	elseif kind == "lava" then
		local pool = deco(decor, Vector3.new(0.2, 5, 5), CFrame.new(pos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(255, 100, 20), Enum.Material.Neon, Enum.PartType.Cylinder)
		local light = Instance.new("PointLight")
		light.Color = RGB(255, 120, 40)
		light.Range = 14
		light.Parent = pool
	elseif kind == "crystal" then
		local c = deco(decor, Vector3.new(1.2, 3.4, 1.2), CFrame.new(pos + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, math.rad(45), math.rad(10)), RGB(150, 110, 255), Enum.Material.Neon)
		c.CanCollide = true
	end
end

-- ── more props (v10.4) ─────────────────────────────────────────────────
local function extraProp(decor, kind, pos)
	local rotY = math.rad(math.random(0, 359))
	if kind == "bench" then
		prop(decor, pos, 0.55, math.random(0, 1) * 180 + 90, function(m)
			for i = 0, 2 do
				part(m, Vector3.new(6, 0.25, 0.5), CFrame.new(0, 1.7, -0.6 + i * 0.6), RGB(150, 100, 60), Enum.Material.Wood)
			end
			part(m, Vector3.new(6, 1.2, 0.25), CFrame.new(0, 2.6, 0.75) * CFrame.Angles(math.rad(-10), 0, 0), RGB(150, 100, 60), Enum.Material.Wood)
			for _, x in ipairs({ -2.6, 2.6 }) do
				part(m, Vector3.new(0.3, 1.7, 1.6), CFrame.new(x, 0.85, 0), RGB(40, 40, 45), Enum.Material.Metal)
			end
		end)
	elseif kind == "hydrant" then
		part(decor, Vector3.new(1.4, 1, 1), CFrame.new(pos + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(200, 30, 30), Enum.Material.Metal, Enum.PartType.Cylinder)
		deco(decor, Vector3.new(0.8, 0.8, 0.8), CFrame.new(pos + Vector3.new(0, 1.5, 0)), RGB(200, 30, 30), Enum.Material.Metal, Enum.PartType.Ball)
	elseif kind == "hay" then
		part(decor, Vector3.new(3, 2.2, 2.2), CFrame.new(pos + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, rotY, 0), RGB(225, 190, 90), Enum.Material.Fabric)
		deco(decor, Vector3.new(0.2, 2.25, 2.25), CFrame.new(pos + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, rotY, 0), RGB(150, 110, 60), Enum.Material.Fabric)
	elseif kind == "fern" then
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			deco(decor, Vector3.new(0.2, 2.2, 0.8), CFrame.new(pos + Vector3.new(math.cos(a) * 0.6, 1, math.sin(a) * 0.6)) * CFrame.Angles(0, -a, math.rad(35)), RGB(50, 140, 60), Enum.Material.Plastic)
		end
	elseif kind == "torch" then
		part(decor, Vector3.new(0.4, 4, 0.4), CFrame.new(pos + Vector3.new(0, 2, 0)), RGB(110, 75, 45), Enum.Material.Wood)
		local flame = deco(decor, Vector3.new(0.7, 0.9, 0.7), CFrame.new(pos + Vector3.new(0, 4.3, 0)), RGB(255, 170, 50), Enum.Material.Neon)
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Parent = flame
		local light = Instance.new("PointLight")
		light.Color = RGB(255, 170, 80)
		light.Range = 14
		light.Parent = flame
	elseif kind == "sign" then
		part(decor, Vector3.new(0.3, 4, 0.3), CFrame.new(pos + Vector3.new(0, 2, 0)), RGB(110, 80, 50), Enum.Material.Wood)
		part(decor, Vector3.new(2.6, 1.2, 0.2), CFrame.new(pos + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, rotY, math.rad(4)), RGB(160, 115, 70), Enum.Material.WoodPlanks)
	elseif kind == "flowerpot" then
		part(decor, Vector3.new(1.6, 1.2, 1.6), CFrame.new(pos + Vector3.new(0, 0.6, 0)), RGB(190, 100, 70), Enum.Material.Brick)
		for i = 0, 3 do
			deco(decor, Vector3.new(0.6, 0.6, 0.6), CFrame.new(pos + Vector3.new(math.cos(i * 1.6) * 0.4, 1.5, math.sin(i * 1.6) * 0.4)), ({ RGB(255, 90, 120), RGB(255, 220, 60), RGB(170, 110, 255), RGB(255, 255, 255) })[i + 1], Enum.Material.Plastic, Enum.PartType.Ball)
		end
	elseif kind == "rockcluster" then
		for i = 0, 2 do
			rock(decor, pos + Vector3.new(i * 1.4 - 1.4, 0.6, (i % 2) * 1.2), Vector3.new(1.8, 1.4, 1.6) * (1 - i * 0.2), RGB(125, 118, 112))
		end
	elseif kind == "barrelstack" then
		prop(decor, pos, 0.55, math.random(0, 90), function(m)
			barrel(m, Vector3.new(-1.7, 0, 0))
			barrel(m, Vector3.new(1.7, 0, 0))
			barrel(m, Vector3.new(0, 4.5, 0))
		end)
	elseif kind == "trashcan" then
		part(decor, Vector3.new(2.6, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(90, 95, 100), Enum.Material.DiamondPlate, Enum.PartType.Cylinder)
		deco(decor, Vector3.new(0.3, 1.8, 1.8), CFrame.new(pos + Vector3.new(0, 2.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(70, 75, 80), Enum.Material.Metal, Enum.PartType.Cylinder)
	elseif kind == "tire" then
		part(decor, Vector3.new(0.9, 2.4, 2.4), CFrame.new(pos + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(30, 30, 32), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	elseif kind == "anchor" then
		part(decor, Vector3.new(0.5, 4, 0.5), CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, rotY, math.rad(15)), RGB(70, 70, 78), Enum.Material.Metal)
		part(decor, Vector3.new(3, 0.5, 0.5), CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, rotY, 0), RGB(70, 70, 78), Enum.Material.Metal)
	elseif kind == "skull" then
		deco(decor, Vector3.new(1.4, 1.2, 1.5), CFrame.new(pos + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, rotY, 0), RGB(245, 240, 225), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		deco(decor, Vector3.new(3, 0.3, 0.3), CFrame.new(pos + Vector3.new(1, 0.15, 0.8)) * CFrame.Angles(0, rotY, 0), RGB(245, 240, 225))
	elseif kind == "snowman" then
		for i, d in ipairs({ 2.6, 2.0, 1.4 }) do
			part(decor, Vector3.new(d, d, d), CFrame.new(pos + Vector3.new(0, 1.1 + (i - 1) * 1.7, 0)), RGB(250, 252, 255), Enum.Material.Snow, Enum.PartType.Ball)
		end
		deco(decor, Vector3.new(0.25, 0.25, 0.8), CFrame.new(pos + Vector3.new(0, 4.5, -0.8)), RGB(255, 140, 40))
		deco(decor, Vector3.new(1.3, 0.8, 1.3), CFrame.new(pos + Vector3.new(0, 5.6, 0)), RGB(30, 30, 35))
	elseif kind == "icicle" then
		local c = deco(decor, Vector3.new(1, 3, 1), CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rotY, math.rad(8)), RGB(190, 230, 255), Enum.Material.Ice)
		c.CanCollide = true
	elseif kind == "satdish" then
		part(decor, Vector3.new(0.4, 2.5, 0.4), CFrame.new(pos + Vector3.new(0, 1.25, 0)), RGB(170, 170, 180), Enum.Material.Metal)
		local dish = part(decor, Vector3.new(0.4, 3, 3), CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, rotY, math.rad(-35)), RGB(220, 220, 230), Enum.Material.Metal, Enum.PartType.Cylinder)
		dish.CanCollide = false
	elseif kind == "meteor" then
		rock(decor, pos + Vector3.new(0, 1, 0), Vector3.new(3, 2.4, 2.8), RGB(70, 60, 80))
		local glow = deco(decor, Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0.6, 1.8, -0.6)), RGB(170, 110, 255), Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = RGB(170, 110, 255)
		light.Range = 10
		light.Parent = glow
	else
		smallProp(decor, kind, pos)
	end
end

local EDGE_PROPS = {
	[1] = { "bush", "flowerpot", "hay", "flowers", "bench", "sunflower", "sign", "bush" },
	[2] = { "bush", "mailbox", "trashcan", "flowerpot", "bench", "hydrant", "flowers", "lamp" },
	[3] = { "cone", "lamp", "hydrant", "trashcan", "bench", "tire", "cone", "flowerpot" },
	[4] = { "crate", "barrel", "barrelstack", "anchor", "rock", "crate", "tire", "lamp" },
	[5] = { "cactus", "rock", "skull", "rockcluster", "cactus", "torch", "bones", "hay" },
	[6] = { "fern", "palm", "bush", "torch", "fern", "flowers", "rockcluster", "palm" },
	[7] = { "lamp", "cone", "crate", "trashcan", "bench", "satdish", "barrelstack", "lamp" },
	[8] = { "rock", "lava", "torch", "rockcluster", "skull", "lava", "rock", "torch" },
	[9] = { "pine", "snowrock", "snowman", "icicle", "pine", "rockcluster", "snowrock", "icicle" },
	[10] = { "crystal", "moonrock", "satdish", "meteor", "crystal", "moonrock", "meteor", "crystal" },
}

-- Things mounted on the walls (inner face), themed per zone.
local function wallPiece(decor, tier, side, x, y, z)
	local face = CFrame.new(x, y, z) * CFrame.Angles(0, side > 0 and -math.pi / 2 or math.pi / 2, 0) -- -Z faces into the corridor
	if tier == 1 or tier == 6 then -- ivy
		for i = 0, 3 do
			deco(decor, Vector3.new(0.9, 3 + i, 0.2), face * CFrame.new(i * 0.9 - 1.3, -i * 0.5, -0.1), RGB(60, 140, 60):Lerp(RGB(30, 90, 40), i / 4), Enum.Material.Plastic)
		end
	elseif tier == 2 or tier == 3 or tier == 7 then -- wall lamp
		deco(decor, Vector3.new(0.6, 0.6, 1.2), face * CFrame.new(0, 0, -0.6), RGB(50, 50, 55), Enum.Material.Metal)
		local bulb = deco(decor, Vector3.new(0.9, 0.9, 0.9), face * CFrame.new(0, -0.5, -1.2), tier == 7 and RGB(200, 120, 255) or RGB(255, 235, 170), Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = bulb.Color
		light.Range = 14
		light.Parent = bulb
		if tier == 7 then
			deco(decor, Vector3.new(14, 0.3, 0.2), face * CFrame.new(0, 4, -0.1), RGB(80, 220, 255), Enum.Material.Neon)
		end
	elseif tier == 4 then -- life ring
		deco(decor, Vector3.new(0.4, 2.4, 2.4), face * CFrame.new(0, 0, -0.2) * CFrame.Angles(0, math.rad(90), 0), RGB(240, 90, 40), Enum.Material.Plastic, Enum.PartType.Cylinder)
		deco(decor, Vector3.new(0.45, 1.2, 1.2), face * CFrame.new(0, 0, -0.25) * CFrame.Angles(0, math.rad(90), 0), RGB(204, 146, 96), Enum.Material.Plastic, Enum.PartType.Cylinder)
	elseif tier == 5 or tier == 8 then -- wall torch
		deco(decor, Vector3.new(0.3, 1.6, 0.3), face * CFrame.new(0, 0, -0.5) * CFrame.Angles(math.rad(-25), 0, 0), RGB(110, 75, 45), Enum.Material.Wood)
		local flame = deco(decor, Vector3.new(0.6, 0.8, 0.6), face * CFrame.new(0, 1.0, -0.9), RGB(255, 160, 50), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = RGB(255, 160, 80)
		light.Range = 12
		light.Parent = flame
		if tier == 8 then
			deco(decor, Vector3.new(0.4, 8, 0.15), face * CFrame.new(3, -2, -0.05) * CFrame.Angles(0, 0, math.rad(20)), RGB(255, 90, 20), Enum.Material.Neon)
		end
	elseif tier == 9 then -- icicles under the top
		for i = -2, 2 do
			deco(decor, Vector3.new(0.5, 1.6 + (i % 2), 0.5), face * CFrame.new(i * 1.4, 8, -0.3), RGB(200, 235, 255), Enum.Material.Ice)
		end
	elseif tier == 10 then -- glowing panel
		deco(decor, Vector3.new(3, 1.6, 0.2), face * CFrame.new(0, 0, -0.1), RGB(40, 30, 80), Enum.Material.Metal)
		deco(decor, Vector3.new(2.6, 0.3, 0.1), face * CFrame.new(0, 0.3, -0.22), RGB(90, 255, 200), Enum.Material.Neon)
	end
end

-- One or two bigger set pieces per zone, tucked against a wall.
local function landmark(decor, tier, pos, side)
	local yaw = side > 0 and -90 or 90
	if tier == 1 then -- doghouse
		prop(decor, pos, 0.7, yaw, function(m)
			part(m, Vector3.new(5, 4, 5), CFrame.new(0, 2, 0), RGB(170, 90, 60), Enum.Material.WoodPlanks)
			for _, s in ipairs({ -1, 1 }) do
				part(m, Vector3.new(5.6, 0.3, 3.4), CFrame.new(0, 5, s * 1.4) * CFrame.Angles(math.rad(s * 35), 0, 0), RGB(150, 50, 40), Enum.Material.Slate)
			end
			part(m, Vector3.new(2, 2.6, 0.2), CFrame.new(0, 1.3, -2.55), RGB(30, 20, 15))
			part(m, Vector3.new(1.4, 0.4, 1.4), CFrame.new(1.5, 0.2, -4), RGB(200, 40, 40), Enum.Material.Metal)
		end)
	elseif tier == 2 then -- garden swing set
		prop(decor, pos, 0.7, yaw, function(m)
			for _, x in ipairs({ -4, 4 }) do
				part(m, Vector3.new(0.4, 7, 0.4), CFrame.new(x, 3.4, -1) * CFrame.Angles(math.rad(-12), 0, 0), RGB(200, 60, 60), Enum.Material.Metal)
				part(m, Vector3.new(0.4, 7, 0.4), CFrame.new(x, 3.4, 1) * CFrame.Angles(math.rad(12), 0, 0), RGB(200, 60, 60), Enum.Material.Metal)
			end
			part(m, Vector3.new(8.6, 0.4, 0.4), CFrame.new(0, 6.8, 0), RGB(200, 60, 60), Enum.Material.Metal)
			for _, x in ipairs({ -1.6, 1.6 }) do
				deco(m, Vector3.new(0.08, 4.5, 0.08), CFrame.new(x - 0.6, 4.5, 0), RGB(80, 80, 85), Enum.Material.Metal)
				deco(m, Vector3.new(0.08, 4.5, 0.08), CFrame.new(x + 0.6, 4.5, 0), RGB(80, 80, 85), Enum.Material.Metal)
				part(m, Vector3.new(1.6, 0.2, 0.8), CFrame.new(x, 2.2, 0), RGB(40, 40, 45))
			end
		end)
	elseif tier == 3 then -- bus stop shelter
		prop(decor, pos, 0.75, yaw, function(m)
			part(m, Vector3.new(8, 0.3, 3.4), CFrame.new(0, 6, 0), RGB(60, 60, 66), Enum.Material.Metal)
			local back = part(m, Vector3.new(8, 5, 0.2), CFrame.new(0, 3, 1.6), RGB(160, 200, 230), Enum.Material.Glass)
			back.Transparency = 0.4
			for _, x in ipairs({ -3.9, 3.9 }) do
				part(m, Vector3.new(0.3, 6, 0.3), CFrame.new(x, 3, 1.5), RGB(60, 60, 66), Enum.Material.Metal)
			end
			part(m, Vector3.new(6, 0.3, 1), CFrame.new(0, 1.6, 1), RGB(150, 100, 60), Enum.Material.Wood)
			deco(m, Vector3.new(1.4, 1.4, 0.2), CFrame.new(5, 6.5, 0), RGB(40, 120, 220), Enum.Material.Neon)
		end)
	elseif tier == 4 then -- rowboat on the shore
		prop(decor, pos, 0.8, yaw + 20, function(m)
			part(m, Vector3.new(3.4, 1.2, 8), CFrame.new(0, 0.6, 0), RGB(120, 80, 50), Enum.Material.WoodPlanks)
			part(m, Vector3.new(3.6, 0.3, 8.2), CFrame.new(0, 1.3, 0), RGB(230, 230, 225), Enum.Material.Wood)
			part(m, Vector3.new(3.2, 0.25, 0.8), CFrame.new(0, 1.2, 0), RGB(140, 95, 60), Enum.Material.Wood)
			part(m, Vector3.new(0.25, 0.25, 5), CFrame.new(1.4, 1.5, 1) * CFrame.Angles(0, math.rad(10), 0), RGB(170, 120, 70), Enum.Material.Wood)
		end)
	elseif tier == 5 then -- covered wagon
		prop(decor, pos, 0.75, yaw, function(m)
			part(m, Vector3.new(4.4, 1.6, 8), CFrame.new(0, 2.2, 0), RGB(130, 90, 55), Enum.Material.WoodPlanks)
			part(m, Vector3.new(4.6, 4.2, 8.2), CFrame.new(0, 4.6, 0), RGB(240, 230, 205), Enum.Material.Fabric, Enum.PartType.Cylinder).CFrame = CFrame.new(0, 4.2, 0) * CFrame.Angles(0, math.rad(90), 0)
			for _, x in ipairs({ -2.4, 2.4 }) do
				for _, z in ipairs({ -2.8, 2.8 }) do
					part(m, Vector3.new(0.4, 2.6, 2.6), CFrame.new(x, 1.3, z), RGB(100, 70, 45), Enum.Material.Wood, Enum.PartType.Cylinder)
				end
			end
		end)
	elseif tier == 6 then -- giant jungle tree
		prop(decor, pos, 0.9, 0, function(m)
			tree(m, Vector3.zero, 1.2, RGB(45, 125, 50))
		end)
	elseif tier == 7 then -- billboard
		prop(decor, pos, 0.8, yaw, function(m)
			for _, x in ipairs({ -4, 4 }) do
				part(m, Vector3.new(0.6, 10, 0.6), CFrame.new(x, 5, 0), RGB(70, 70, 78), Enum.Material.Metal)
			end
			local board = part(m, Vector3.new(12, 6, 0.4), CFrame.new(0, 12, 0), RGB(30, 30, 40))
			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Front
			gui.LightInfluence = 0
			gui.Parent = board
			local t = Instance.new("TextLabel")
			t.Size = UDim2.fromScale(1, 1)
			t.BackgroundColor3 = RGB(255, 60, 160)
			t.Font = Enum.Font.FredokaOne
			t.TextScaled = true
			t.TextColor3 = RGB(255, 255, 255)
			t.Text = "SHRINK IT!"
			t.Parent = gui
		end)
	elseif tier == 8 then -- lava pool with rocks
		local pool = deco(decor, Vector3.new(0.3, 10, 10), CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(255, 90, 20), Enum.Material.Neon, Enum.PartType.Cylinder)
		local light = Instance.new("PointLight")
		light.Color = RGB(255, 110, 40)
		light.Range = 22
		light.Brightness = 2
		light.Parent = pool
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			rock(decor, pos + Vector3.new(math.cos(a) * 5.5, 0.8, math.sin(a) * 5.5), Vector3.new(2.4, 1.8, 2.2), RGB(50, 38, 35))
		end
	elseif tier == 9 then -- ski rack + snowmen
		extraProp(decor, "snowman", pos)
		extraProp(decor, "snowman", pos + Vector3.new(0, 0, 5))
		for i = 0, 3 do
			part(decor, Vector3.new(0.25, 5, 0.5), CFrame.new(pos + Vector3.new(-side * 3, 2.5, -3 + i * 0.8)) * CFrame.Angles(0, 0, math.rad(-side * 10)), ({ RGB(220, 40, 40), RGB(40, 120, 220), RGB(250, 200, 40), RGB(40, 180, 90) })[i + 1])
		end
	elseif tier == 10 then -- crashed rocket
		prop(decor, pos, 0.7, yaw, function(m)
			part(m, Vector3.new(10, 3, 3), CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(25)), RGB(230, 230, 235), Enum.Material.Metal, Enum.PartType.Cylinder)
			part(m, Vector3.new(3, 3.2, 3.2), CFrame.new(4.3, 4.6, 0) * CFrame.Angles(0, 0, math.rad(25)), RGB(220, 40, 40), Enum.Material.Metal, Enum.PartType.Ball)
			local fire = deco(m, Vector3.new(2, 2, 2), CFrame.new(-4.6, 0.8, 0), RGB(255, 140, 40), Enum.Material.Neon, Enum.PartType.Ball)
			local smoke = Instance.new("Smoke")
			smoke.Size = 3
			smoke.Opacity = 0.2
			smoke.Parent = fire
		end)
	end
end

-- ── floor details (flat, never in the way): islands, ponds, lava, road lines ... ─────────────────
local function flat(parent, size, x, z, angle, color, material, y)
	local p = deco(parent, Vector3.new(size.X, 0.12, size.Y), CFrame.new(x, y or 0.07, z) * CFrame.Angles(0, angle or 0, 0), color, material or Enum.Material.Plastic)
	p.CanQuery = false
	return p
end

local function disc(parent, d, x, z, color, material, y)
	local p = deco(parent, Vector3.new(0.12, d, d), CFrame.new(x, y or 0.08, z) * CFrame.Angles(0, 0, math.rad(90)), color, material or Enum.Material.Plastic, Enum.PartType.Cylinder)
	p.CanQuery = false
	return p
end

-- an angular "island" made of a few rotated slabs (the Steal-an-Egg look)
local function blob(parent, x, z, r, color, material, y)
	local rng = Random.new(math.floor(x * 7 + z * 13))
	for k = 1, 4 do
		local a = rng:NextNumber(0, math.pi)
		flat(parent, Vector2.new(r * rng:NextNumber(1.4, 2.1), r * rng:NextNumber(0.8, 1.3)), x + rng:NextNumber(-r, r) * 0.35, z + rng:NextNumber(-r, r) * 0.35, a, color, material, (y or 0.07) + k * 0.002)
	end
end

local function zigzag(parent, x, z, len, color, material, y)
	local rng = Random.new(math.floor(x * 3 + z * 5))
	local px, pz = x, z
	local a = rng:NextNumber(0, math.pi * 2)
	for _ = 1, 5 do
		a += rng:NextNumber(-0.9, 0.9)
		local seg = len / 5
		local nx, nz = px + math.cos(a) * seg, pz + math.sin(a) * seg
		flat(parent, Vector2.new(seg + 0.4, 0.45), (px + nx) / 2, (pz + nz) / 2, -a, color, material, y)
		if rng:NextNumber() < 0.5 then -- a little branch
			local b = a + rng:NextNumber(-1.4, 1.4)
			flat(parent, Vector2.new(seg * 0.6, 0.3), nx + math.cos(b) * seg * 0.3, nz + math.sin(b) * seg * 0.3, -b, color, material, y)
		end
		px, pz = nx, nz
	end
end

function MapDecor.FloorDetails(zoneModel, tier, z0, depth, width)
	local f = folder(zoneModel, "FloorDecor")
	local rng = Random.new(tier * 101)
	local hw = width / 2
	local function rz(a, b)
		return z0 + depth * rng:NextNumber(a or 0.06, b or 0.94)
	end
	local function rx(edgeGap)
		return rng:NextNumber(-hw + (edgeGap or 12), hw - (edgeGap or 12))
	end
	if tier == 1 then
		for _ = 1, 7 do
			blob(f, rx(), rz(), rng:NextNumber(5, 9), RGB(135, 232, 75))
		end
		for _ = 1, 18 do
			local x, z = rx(8), rz()
			local c = ({ RGB(255, 120, 200), RGB(255, 230, 80), RGB(255, 255, 255) })[rng:NextInteger(1, 3)]
			for k = 0, 3 do
				flat(f, Vector2.new(0.7, 0.7), x + math.cos(k * math.pi / 2) * 0.55, z + math.sin(k * math.pi / 2) * 0.55, 0, c, nil, 0.1)
			end
			flat(f, Vector2.new(0.5, 0.5), x, z, 0, RGB(255, 200, 40), nil, 0.11)
		end
	elseif tier == 2 then
		for _, side in ipairs({ -1, 1 }) do -- stepping-stone paths
			for z = z0 + 6, z0 + depth - 6, 7 do
				flat(f, Vector2.new(4, 4), side * hw * 0.3 + math.sin(z * 0.08) * 6, z, rng:NextNumber(-0.3, 0.3), RGB(200, 200, 205))
			end
		end
	elseif tier == 3 then
		for z = z0 + 4, z0 + depth - 6, 12 do -- dashed center line
			flat(f, Vector2.new(0.8, 6), 0, z, 0, RGB(255, 210, 40))
		end
		for _, frac in ipairs({ 0.3, 0.7 }) do -- crosswalks
			for x = -hw + 20, hw - 20, 5 do
				flat(f, Vector2.new(2.6, 9), x, z0 + depth * frac, 0, RGB(245, 245, 245))
			end
		end
		for _ = 1, 6 do
			disc(f, 3, rx(), rz(), RGB(90, 92, 100))
		end
	elseif tier == 4 then
		for k = 1, 7 do -- sand islands on the water
			local side = k % 2 == 0 and 1 or -1
			blob(f, side * rng:NextNumber(hw * 0.35, hw * 0.7), z0 + depth * (k - 0.5) / 7, rng:NextNumber(9, 15), RGB(236, 214, 160))
		end
		for _ = 1, 30 do -- ripples
			flat(f, Vector2.new(rng:NextNumber(3, 7), 0.35), rx(6), rz(), 0, RGB(110, 160, 240), nil, 0.065)
		end
	elseif tier == 5 then
		for _ = 1, 8 do
			blob(f, rx(), rz(), rng:NextNumber(7, 12), RGB(228, 182, 92))
		end
		for _ = 1, 8 do
			zigzag(f, rx(), rz(), rng:NextNumber(10, 18), RGB(170, 120, 60), nil, 0.09)
		end
	elseif tier == 6 then
		for _ = 1, 6 do -- ponds with lily pads
			local x, z = rx(18), rz()
			blob(f, x, z, rng:NextNumber(6, 9), RGB(70, 150, 230), Enum.Material.Glass)
			for _ = 1, 4 do
				disc(f, rng:NextNumber(1.4, 2.2), x + rng:NextNumber(-5, 5), z + rng:NextNumber(-4, 4), RGB(60, 190, 70), nil, 0.12)
			end
			flat(f, Vector2.new(0.8, 0.8), x + 2, z + 1, 0.6, RGB(255, 120, 210), nil, 0.16)
		end
	elseif tier == 7 then
		for x = -hw + 20, hw - 20, 20 do -- big floor tiles
			flat(f, Vector2.new(0.4, depth), x, z0 + depth / 2, 0, RGB(150, 155, 190))
		end
		for z = z0 + 20, z0 + depth - 10, 20 do
			flat(f, Vector2.new(width, 0.4), 0, z, 0, RGB(150, 155, 190))
		end
		for _, side in ipairs({ -1, 1 }) do -- neon edge lines
			flat(f, Vector2.new(0.8, depth), side * (hw - 2), z0 + depth / 2, 0, RGB(80, 230, 255), Enum.Material.Neon, 0.09)
		end
	elseif tier == 8 then
		for _, side in ipairs({ -1, 1 }) do -- lava rivers along the walls
			flat(f, Vector2.new(9, depth - 8), side * (hw - 14), z0 + depth / 2, 0, RGB(255, 120, 30), Enum.Material.Neon)
			flat(f, Vector2.new(11, depth - 6), side * (hw - 14), z0 + depth / 2, 0, RGB(60, 40, 40), nil, 0.05)
		end
		for _ = 1, 9 do -- glowing cracks
			zigzag(f, rng:NextNumber(-hw * 0.5, hw * 0.5), rz(), rng:NextNumber(12, 22), RGB(255, 200, 60), Enum.Material.Neon, 0.09)
		end
	elseif tier == 9 then
		for _ = 1, 7 do
			blob(f, rx(), rz(), rng:NextNumber(6, 11), RGB(175, 220, 255), Enum.Material.Ice)
		end
		for _ = 1, 10 do
			local p = deco(f, Vector3.new(rng:NextNumber(4, 7), 1.6, rng:NextNumber(4, 7)), CFrame.new(rx(10), 0.2, rz()), RGB(255, 255, 255), Enum.Material.Snow, Enum.PartType.Ball)
			p.CanQuery = false
		end
	elseif tier == 10 then
		for _ = 1, 8 do -- craters
			local x, z, d = rx(), rz(), rng:NextNumber(7, 13)
			disc(f, d + 2, x, z, RGB(80, 65, 125))
			disc(f, d, x, z, RGB(35, 25, 65), nil, 0.1)
		end
		for _, side in ipairs({ -1, 1 }) do
			for z = z0 + 10, z0 + depth - 10, 14 do -- glowing runway lights
				flat(f, Vector2.new(1.2, 3), side * (hw * 0.25), z, 0, RGB(200, 120, 255), Enum.Material.Neon, 0.09)
			end
		end
	end
end

function MapDecor.Zone(zoneModel, tier, z0, depth, width)
	local decor = folder(zoneModel, "Decor")
	local kinds = EDGE_PROPS[tier] or EDGE_PROPS[1]
	local edge = width / 2 - 5 -- props hug the walls; the middle stays open for running
	local i = 0
	local function place(kind, pos)
		local ok, err = pcall(extraProp, decor, kind, pos)
		if not ok then
			warn("[MapDecor] prop " .. kind .. " failed: " .. tostring(err))
		end
	end
	-- front row along each wall (dense) + a second, sparser row a little further in
	for z = z0 + 12, z0 + depth - 8, 16 do
		for _, s in ipairs({ -1, 1 }) do
			i += 1
			place(kinds[(i % #kinds) + 1], Vector3.new(s * (edge - math.random(0, 3)), 0, z + math.random(-4, 4)))
			if i % 3 == 0 then
				place(kinds[((i + 3) % #kinds) + 1], Vector3.new(s * (edge - 10 - math.random(0, 3)), 0, z + 8 + math.random(-3, 3)))
			end
		end
	end
	-- wall decorations
	for z = z0 + 10, z0 + depth - 6, 24 do
		for _, s in ipairs({ -1, 1 }) do
			pcall(wallPiece, decor, tier, s, s * (width / 2 - 0.1), 9 + math.random(-1, 2), z + (s > 0 and 12 or 0))
		end
	end
	pcall(MapDecor.FloorDetails, zoneModel, tier, z0, depth, width)
	-- landmarks against the walls
	pcall(landmark, decor, tier, Vector3.new(-(edge - 4), 0, z0 + depth * 0.35), -1)
	pcall(landmark, decor, tier, Vector3.new(edge - 4, 0, z0 + depth * 0.72), 1)
	if tier == 10 then -- a starry sky feeling: little glowing dots on the walls
		for _ = 1, 40 do
			local s = math.random() < 0.5 and -1 or 1
			deco(decor, Vector3.one * 0.6, CFrame.new(s * (width / 2 - 0.5), math.random(6, 36), math.random(z0 + 4, z0 + depth - 4)), RGB(255, 255, 255), Enum.Material.Neon, Enum.PartType.Ball)
		end
	end
end

-- ── shared helpers for stands & machines ──
local function pipeSegment(parent, a, b, d, color)
	local len = (b - a).Magnitude
	return part(parent, Vector3.new(len + d * 0.5, d, d), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Plastic, Enum.PartType.Cylinder)
end

local function screenText(target, face, text, color, ppS)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppS or 30
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	return label
end

-- Floating "hologram" title over a stand. Sized in STUDS (so far-away titles get small instead of
-- piling on top of each other), with a soft drop shadow and a shine; the client makes it bob
-- and shimmer (Effects, tag "FloatingTitle").
local function floatingTitle(adornee, text, colors, height, sub)
	local w = math.max(9, #text * 1.9 + 2)
	local gui = Instance.new("BillboardGui")
	gui.Name = "FloatingTitle"
	gui.Size = UDim2.fromScale(w, sub and 6.6 or 4.6)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.Adornee = adornee
	gui.MaxDistance = 320
	gui.LightInfluence = 0
	gui:SetAttribute("BaseHeight", height)
	gui.Parent = adornee
	game:GetService("CollectionService"):AddTag(gui, "FloatingTitle")
	local function textLabel(name, pos, size, txt)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Position = pos
		label.Size = size
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = RGB(255, 255, 255)
		label.Text = txt
		label.Parent = gui
		return label
	end
	local titleH = sub and 0.68 or 1
	-- shadow: same text, dark, nudged down-right
	local shadow = textLabel("Shadow", UDim2.fromScale(0.012, 0.05), UDim2.fromScale(1, titleH), text)
	shadow.TextColor3 = RGB(20, 20, 35)
	shadow.TextTransparency = 0.45
	shadow.ZIndex = 1
	local label = textLabel("Title", UDim2.fromScale(0, 0), UDim2.fromScale(1, titleH), text)
	label.ZIndex = 2
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 4
	stroke.Color = RGB(25, 25, 40)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	-- colour gradient with a bright shine band (the client slides the band across)
	local grad = Instance.new("UIGradient")
	grad.Name = "Shine"
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colors[1]:Lerp(RGB(255, 255, 255), 0.35)),
		ColorSequenceKeypoint.new(0.45, colors[1]),
		ColorSequenceKeypoint.new(0.5, RGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, colors[2]),
		ColorSequenceKeypoint.new(1, colors[2]),
	})
	grad.Rotation = 75
	grad.Parent = label
	if sub then
		local sl = textLabel("Sub", UDim2.fromScale(0.15, 0.7), UDim2.fromScale(0.7, 0.28), sub)
		sl.ZIndex = 2
		local st = Instance.new("UIStroke")
		st.Thickness = 3
		st.Color = RGB(25, 25, 40)
		st.Parent = sl
	end
	return gui
end
MapDecor.FloatingTitle = floatingTitle

-- ── stands (SELL / FUSE / TRAILS / SHOP) ──────────────────────────────
-- A market stall with a striped awning, a big floating label and a ProximityPrompt that
-- opens a menu on the client (the prompt's "OpensMenu" attribute = menu name).
function MapDecor.Stand(parent, name, label, colors, worldPos, menu, propFn, yaw)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	local pos = Vector3.zero -- built at the origin, then scaled up and moved into place
	local ring = deco(m, Vector3.new(0.3, 22, 22), CFrame.new(pos + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), colors[1], Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency = 0.6
	local counter = part(m, Vector3.new(12, 3.4, 4), CFrame.new(pos + Vector3.new(0, 1.7, 2)), RGB(170, 115, 70), Enum.Material.WoodPlanks)
	part(m, Vector3.new(12.6, 0.4, 4.6), CFrame.new(pos + Vector3.new(0, 3.6, 2)), RGB(250, 248, 240), Enum.Material.Marble)
	for _, x in ipairs({ -5.8, 5.8 }) do
		for _, z in ipairs({ -2.6, 3.6 }) do
			part(m, Vector3.new(0.6, 9.4, 0.6), CFrame.new(pos + Vector3.new(x, 4.7, z)), RGB(240, 240, 245), Enum.Material.SmoothPlastic)
		end
	end
	local stripes = 8
	for i = 0, stripes - 1 do
		local x = -6.6 + (i + 0.5) * (13.2 / stripes)
		part(m, Vector3.new(13.2 / stripes, 0.35, 8), CFrame.new(pos + Vector3.new(x, 9.7, 0.5)) * CFrame.Angles(math.rad(-14), 0, 0), (i % 2 == 0) and colors[1] or RGB(255, 255, 255), Enum.Material.Fabric)
	end
	for i = 0, stripes - 1 do -- scalloped front edge
		local x = -6.6 + (i + 0.5) * (13.2 / stripes)
		deco(m, Vector3.new(0.3, 1.2, 1.2), CFrame.new(pos + Vector3.new(x, 8.6, 4.5)) * CFrame.Angles(0, 0, math.rad(90)), (i % 2 == 0) and colors[1] or RGB(255, 255, 255), Enum.Material.Fabric, Enum.PartType.Cylinder)
	end
	if propFn then
		propFn(m, pos + Vector3.new(0, 3.8, 2))
	end
	-- hanging lanterns on the front posts
	for _, x in ipairs({ -5.8, 5.8 }) do
		part(m, Vector3.new(0.12, 1.4, 0.12), CFrame.new(pos + Vector3.new(x, 8.3, 4.2)), RGB(40, 40, 45), Enum.Material.Metal)
		local lantern = deco(m, Vector3.new(0.9, 1.1, 0.9), CFrame.new(pos + Vector3.new(x, 7.3, 4.2)), RGB(255, 210, 120), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = RGB(255, 210, 140)
		light.Range = 12
		light.Brightness = 1.2
		light.Parent = lantern
	end
	-- sparkles drifting up from the glowing ring
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(colors[2])
	sparkle.LightEmission = 1
	sparkle.Rate = 5
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(30, 30)
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Parent = ring
	-- shopkeeper behind the counter (added by MapDecor.AddShopkeepers, so it also works on a saved map)
	local spot = deco(m, Vector3.new(1, 1, 1), CFrame.new(pos + Vector3.new(0, 0.5, -1)) * CFrame.Angles(0, math.pi, 0), colors[1])
	spot.Name = "KeeperSpot"
	spot.Transparency = 1
	m:SetAttribute("KeeperColor", colors[1])
	floatingTitle(counter, label, { colors[2]:Lerp(RGB(255, 255, 255), 0.25), colors[1] }, 15)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("OpensMenu", menu)
	prompt.Parent = counter
	m.WorldPivot = CFrame.new()
	m:ScaleTo(1.25)
	m:PivotTo(CFrame.new(worldPos) * CFrame.Angles(0, yaw or 0, 0))
	return m
end

-- ── the Fuse Machine (a big blue machine with a glowing "?" screen) ───

function MapDecor.FuseMachine(parent, worldPos)
	local m = Instance.new("Model")
	m.Name = "FuseStand"
	m.Parent = parent
	local BLUE = RGB(45, 110, 235)
	local DARK = RGB(62, 66, 84)
	local DARKER = RGB(44, 47, 62)
	local GLOW = RGB(140, 225, 255)
	-- platform with a step in front
	part(m, Vector3.new(22, 1, 15), CFrame.new(1, 0.5, 0), DARK, Enum.Material.Plastic)
	part(m, Vector3.new(14, 0.6, 3), CFrame.new(3, 0.3, 8.8), DARK, Enum.Material.Plastic)
	-- main body + glowing "?" screen
	local body = part(m, Vector3.new(11, 10, 9), CFrame.new(4, 6, -0.5), BLUE, Enum.Material.Plastic)
	body.Name = "Body"
	for _, x in ipairs({ -1.2, 9.2 }) do -- dark frame pillars
		part(m, Vector3.new(1, 10.4, 9.4), CFrame.new(x, 6, -0.5), DARKER, Enum.Material.Plastic)
	end
	local screen = part(m, Vector3.new(8.4, 7.8, 0.4), CFrame.new(4, 6, 4.1), GLOW, Enum.Material.Neon)
	screen.Name = "Screen"
	screenText(screen, Enum.NormalId.Back, "?", RGB(35, 90, 190), 40)
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 18
	light.Brightness = 1.6
	light.Parent = screen
	-- domed lid with a little window
	part(m, Vector3.new(1.4, 10, 10), CFrame.new(4, 11.7, -0.5) * CFrame.Angles(0, 0, math.rad(90)), DARK, Enum.Material.Plastic, Enum.PartType.Cylinder)
	part(m, Vector3.new(1.4, 7.6, 7.6), CFrame.new(4, 13.1, -0.5) * CFrame.Angles(0, 0, math.rad(90)), DARKER, Enum.Material.Plastic, Enum.PartType.Cylinder)
	part(m, Vector3.new(1, 4.6, 4.6), CFrame.new(4, 14.3, -0.5) * CFrame.Angles(0, 0, math.rad(90)), DARK, Enum.Material.Plastic, Enum.PartType.Cylinder)
	deco(m, Vector3.new(3.4, 1.4, 0.3), CFrame.new(4, 12.6, 3.3) * CFrame.Angles(math.rad(-20), 0, 0), GLOW, Enum.Material.Neon)
	-- side unit: star screen, heart gauge, antennas
	part(m, Vector3.new(6, 7, 6.5), CFrame.new(-5.5, 4.5, 0), RGB(36, 80, 190), Enum.Material.Plastic)
	local star = part(m, Vector3.new(3.4, 3.4, 0.3), CFrame.new(-6, 5, 3.3), RGB(235, 245, 255), Enum.Material.Neon)
	screenText(star, Enum.NormalId.Back, "★", RGB(60, 120, 230), 40)
	local gauge = part(m, Vector3.new(1.4, 4.4, 0.4), CFrame.new(-3.2, 5, 3.4), RGB(230, 40, 50), Enum.Material.Neon)
	screenText(gauge, Enum.NormalId.Back, "♥\n♥\n♥", RGB(255, 210, 215), 40)
	for _, x in ipairs({ -7.6, -6.4 }) do
		local h = x < -7 and 6 or 4
		part(m, Vector3.new(h, 0.5, 0.5), CFrame.new(x, 8 + h / 2, -1.5) * CFrame.Angles(0, 0, math.rad(90)), DARKER, Enum.Material.Plastic, Enum.PartType.Cylinder)
		part(m, Vector3.one * 0.9, CFrame.new(x, 8 + h, -1.5), DARKER, Enum.Material.Plastic, Enum.PartType.Ball)
	end
	-- curved pipe from the side unit into the lid
	local prev
	for i = 0, 6 do
		local a = math.rad(180 - i * 30)
		local p = Vector3.new(-1.3 + math.cos(a) * 4.2, 8 + math.sin(a) * 4.6, -0.5)
		if prev then
			pipeSegment(m, prev, p, 1.5, DARKER)
		end
		prev = p
	end
	-- red guide arrows on the ground pointing at the step
	for i = 0, 1 do
		local arrow = deco(m, Vector3.new(1.6, 0.2, 1.6), CFrame.new(-1 + i * 2.2, 1.15, 8) * CFrame.Angles(0, math.rad(45), 0), RGB(235, 30, 30), Enum.Material.Neon)
		arrow.Name = "Arrow"
	end
	floatingTitle(body, "Fuse Machine", { RGB(90, 220, 255), RGB(30, 110, 230) }, 13)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Fuse"
	prompt.ObjectText = "Fuse Machine"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt:SetAttribute("OpensMenu", "Fuse")
	prompt.Parent = screen
	m.WorldPivot = CFrame.new()
	m:PivotTo(CFrame.new(worldPos))
	return m
end

-- Puts a shopkeeper NPC behind every stand that has a "KeeperSpot" (and no keeper yet).
-- Runs when the server starts, because Roblox characters can only be created in a live game.
-- ── your asset pack in the zones (ServerStorage > AssetPack, placed when the server starts) ──────
-- Each zone: its environment kit on the left edge, its landmark on the right edge and a few props
-- along both sides (the middle stays clear for the boxes). Old decor in the way is removed.
MapDecor.PACK_ZONES = {
	[1] = { Walls = { "ivy" }, Kit = "zone_1_environment_kit", Landmark = "doghouse", Props = { "bush", "flower_pot", "hay_bale", "flower_patch", "bench", "sunflower", "wooden_sign", "mailbox", "fire_hydrant", "traffic_cone" } },
	[2] = { Walls = { "wall_lamp" }, Kit = "zone_2_environment_kit", Landmark = "swing_set", Props = { "bush", "flower_pot", "bench", "mailbox", "trash_can", "fire_hydrant", "garden_lamp" } },
	[3] = { Walls = { "wall_lamp" }, Kit = "zone_3_environment_kit", Landmark = "bus_stop_shelter", Props = { "bench", "trash_can", "fire_hydrant", "traffic_cone", "street_lamp", "tyre" } },
	[4] = { Walls = { "life_ring" }, Kit = "zone_4_environment_kit", Landmark = "rowboat", Props = { "tyre", "crate", "barrel", "barrel_stack", "anchor", "rock" } },
	[5] = { Walls = { "wall_torch" }, Kit = "zone_5_environment_kit", Landmark = "covered_wagon", Props = { "rock", "cactus", "skull", "bones", "torch", "hay" } },
	[6] = { Walls = { "ivy" }, Kit = "zone_6_environment_kit", Landmark = "giant_jungle_tree", Props = { "bush", "torch", "fern", "palm_tree", "rock_cluster" } },
	[7] = { Walls = { "neon_strip", "neon_wall_lamp" }, Kit = "zone_7_environment_kit", Landmark = "shrink_billboard", Props = { "bench", "traffic_cone", "crate", "skyline_lamp", "satellite_dish" } },
	[8] = { Walls = { "wall_torch", "lava_cracks" }, Kit = "zone_8_environment_kit", Landmark = "large_lava_pool", Props = { "rock", "skull", "torch", "small_lava_pool" } },
	[9] = { Walls = { "icicles" }, Kit = "zone_9_environment_kit", Landmark = "snowmen_ski_rack", Props = { "pine_tree", "snowy_rock", "snowman", "ice_spike" } },
	[10] = { Walls = { "glowing_panel", "wall_stars" }, Kit = "zone_10_environment_kit", Landmark = "crashed_rocket", Props = { "satellite_dish", "purple_crystal", "moon_rock", "meteor" } },
}
local PACK_RENAMES = { trash_can = "TrashBin", ufo = "UFO", moon = "TheMoon" }
-- how high the bottom of each wall piece sits (studs above the floor); icicles hang from the top
local WALL_BOTTOM = { ivy = 0.2, lava_cracks = 0.5, neon_strip = 14, wall_stars = 18, glowing_panel = 6, life_ring = 7, wall_lamp = 9, neon_wall_lamp = 9, wall_torch = 8 }
local WALL_TOP = 40

local function packArt(name)
	local pack = game:GetService("ServerStorage"):FindFirstChild("AssetPack")
	local templates = game:GetService("ReplicatedStorage"):FindFirstChild("ShrinkableTemplates")
	local camel = PACK_RENAMES[name]
	if not camel then
		camel = name:gsub("_(%w)", string.upper)
		camel = camel:gsub("^%l", string.upper)
	end
	local src = (pack and pack:FindFirstChild(name)) or (templates and templates:FindFirstChild(camel))
	return src and src:Clone() or nil
end

-- puts `model` on the ground at (x, z) turned by `yaw`; returns its footprint half-size (x, z)
local function placeArt(model, parent, x, groundY, z, yaw)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanQuery = false
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	model:PivotTo(CFrame.new(x, groundY, z) * CFrame.Angles(0, yaw, 0))
	local cf, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + Vector3.new(x - cf.Position.X, groundY - (cf.Position.Y - size.Y / 2), z - cf.Position.Z))
	model.Parent = parent
	local turned = math.abs(math.sin(yaw)) > 0.7
	return turned and size.Z / 2 or size.X / 2, turned and size.X / 2 or size.Z / 2
end

local function clearAround(zone, x, z, hx, hz)
	local decor = zone:FindFirstChild("Decor")
	for _, c in ipairs(decor and decor:GetChildren() or {}) do
		local p = (c:IsA("Model") and c:GetPivot().Position) or (c:IsA("BasePart") and c.Position) or nil
		if p and math.abs(p.X - x) < hx + 2 and math.abs(p.Z - z) < hz + 2 then
			c:Destroy()
		end
	end
end

local function blocksSpawn(zone, x, z, hx, hz)
	local points = zone:FindFirstChild("SpawnPoints")
	for _, sp in ipairs(points and points:GetChildren() or {}) do
		if math.abs(sp.Position.X - x) < hx + 7 and math.abs(sp.Position.Z - z) < hz + 7 then
			return true
		end
	end
	return false
end

function MapDecor.PackDecor(map)
	local zones = map:FindFirstChild("Zones")
	for _, zone in ipairs(zones and zones:GetChildren() or {}) do
		local tier = zone:GetAttribute("Tier")
		local cfg = MapDecor.PACK_ZONES[tier]
		local floor = zone:FindFirstChild("Floor")
		if cfg and floor and not zone:FindFirstChild("PackDecor") then
			local folder = Instance.new("Folder")
			folder.Name = "PackDecor"
			folder.Parent = zone
			local w, d = floor.Size.X, floor.Size.Z
			local z0 = floor.Position.Z - d / 2
			local groundY = floor.Position.Y + floor.Size.Y / 2
			local placed = {}
			local function overlapsPlaced(x, z, hx, hz)
				for _, p in ipairs(placed) do
					if math.abs(p[1] - x) < p[3] + hx + 2 and math.abs(p[2] - z) < p[4] + hz + 2 then
						return true
					end
				end
				return false
			end
			local function put(name, side, frac)
				local model = packArt(name)
				if not model then
					return
				end
				local yaw = side < 0 and -math.pi / 2 or math.pi / 2 -- face the middle of the zone
				-- try a few spots along the edge until it doesn't sit on a box spawn
				for _, nudge in ipairs({ 0, 0.08, -0.08, 0.16, -0.16 }) do
					local z = z0 + d * math.clamp(frac + nudge, 0.06, 0.94)
					local hx, hz = placeArt(model, folder, 0, groundY, z, yaw)
					local x = side * (w / 2 - hx - 3)
					if not blocksSpawn(zone, x, z, hx, hz) and not overlapsPlaced(x, z, hx, hz) then
						placeArt(model, folder, x, groundY, z, yaw)
						clearAround(zone, x, z, hx, hz)
						table.insert(placed, { x, z, hx, hz })
						return
					end
				end
				model:Destroy()
			end
			put(cfg.Kit, -1, 0.32)
			put(cfg.Landmark, 1, 0.62)
			for i, name in ipairs(cfg.Props) do
				if i > 6 then
					break
				end
				put(name, i % 2 == 0 and -1 or 1, 0.1 + (i - 1) * 0.14)
			end
			-- wall pieces hung along both walls
			local k = 0
			for z = z0 + 16, z0 + d - 10, 22 do
				for _, side in ipairs({ -1, 1 }) do
					k += 1
					local name = cfg.Walls[(k % #cfg.Walls) + 1]
					local model = packArt(name)
					if model then
						local yaw = side < 0 and -math.pi / 2 or math.pi / 2
						local hx = placeArt(model, folder, 0, groundY, z, yaw)
						local _, size = model:GetBoundingBox()
						local bottom = name == "icicles" and (WALL_TOP - size.Y - 0.5) or (WALL_BOTTOM[name] or 8)
						placeArt(model, folder, side * (w / 2 - hx - 0.05), groundY + bottom, z + (side > 0 and 11 or 0), yaw)
					end
				end
			end
		end
	end
end

-- Sleeping shopkeepers wake up when a player comes close and doze off again when everyone leaves.
function MapDecor.ShopkeeperNaps(root)
	local keepers = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("NapKeeper") then
			table.insert(keepers, d)
		end
	end
	if #keepers == 0 then
		return
	end
	local Players = game:GetService("Players")
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, npc in ipairs(keepers) do
				if npc.Parent then
					local pos = npc:GetPivot().Position
					local near = false
					for _, player in ipairs(Players:GetPlayers()) do
						local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
						if r and (r.Position - pos).Magnitude < 20 then
							near = true
							break
						end
					end
					if npc:GetAttribute("Sleeping") == near then
						npc:SetAttribute("Sleeping", not near)
					end
				end
			end
		end
	end)
end

function MapDecor.AddShopkeepers(root)
	for _, stand in ipairs(root:GetDescendants()) do
		local spot = stand:IsA("Model") and stand:FindFirstChild("KeeperSpot")
		if spot and not stand:FindFirstChild("Shopkeeper") then
			-- your shopkeeper: the sleeping version (ServerStorage > SleepingShopkeepers, naps until someone
			-- walks up) or the awake one (ServerStorage > AssetPack > shopkeeper_sell / _shop / _trails / _rewards)
			local storage = game:GetService("ServerStorage")
			local key = stand.Name:gsub("Stand$", ""):lower()
			local art
			for _, folderName in ipairs({ "SleepingShopkeepers", "AssetPack" }) do
				local f = storage:FindFirstChild(folderName)
				art = art or (f and (f:FindFirstChild("shopkeeper_" .. key) or f:FindFirstChild("shopkeeper_rewards")))
			end
			if art then
				local npc = art:Clone()
				npc.Name = "Shopkeeper"
				for _, d in ipairs(npc:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CanQuery = false
					elseif d:IsA("LuaSourceContainer") then
						d:Destroy()
					end
				end
				-- stand on the spot (feet on the ground), facing the customers
				local base = spot.CFrame * CFrame.new(0, -spot.Size.Y / 2, 0)
				npc:PivotTo(base)
				local cf, size = npc:GetBoundingBox()
				npc:PivotTo(npc:GetPivot() + Vector3.new(base.Position.X - cf.Position.X, base.Position.Y - (cf.Position.Y - size.Y / 2), base.Position.Z - cf.Position.Z))
				if npc:FindFirstChild("SetSleeping") then
					npc:SetAttribute("Sleeping", true)
					npc:SetAttribute("NapKeeper", true)
				end
				npc.Parent = stand
				continue
			end
			pcall(function()
				local shirt = stand:GetAttribute("KeeperColor") or RGB(200, 60, 60)
				local desc = Instance.new("HumanoidDescription")
				desc.HeadColor = RGB(234, 184, 146)
				desc.LeftArmColor = RGB(234, 184, 146)
				desc.RightArmColor = RGB(234, 184, 146)
				desc.TorsoColor = shirt
				desc.LeftLegColor = RGB(50, 50, 70)
				desc.RightLegColor = RGB(50, 50, 70)
				local npc = game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
				npc.Name = "Shopkeeper"
				for _, d in ipairs(npc:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.CanQuery = false
					elseif d:IsA("LocalScript") or d:IsA("Script") then
						d:Destroy()
					end
				end
				local hum = npc:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				end
				local _, size = npc:GetBoundingBox()
				npc:PivotTo(spot.CFrame * CFrame.new(0, size.Y / 2 - spot.Size.Y / 2, 0))
				local head = npc:FindFirstChild("Head")
				if head then -- a little cap in the stand's color
					local cap = Instance.new("Part")
					cap.Anchored = true
					cap.CanCollide = false
					cap.Size = Vector3.new(1.3, 0.35, 1.4)
					cap.CFrame = head.CFrame * CFrame.new(0, 0.62, 0)
					cap.Color = shirt
					cap.Material = Enum.Material.Fabric
					cap.Parent = npc
				end
				npc.Parent = stand
			end)
		end
	end
end

local function coinStack(m, top)
	for i = 0, 4 do
		deco(m, Vector3.new(0.35, 1.6, 1.6), CFrame.new(top + Vector3.new(-2 + (i % 2) * 0.2, 0.2 + i * 0.36, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(255, 205, 50), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	deco(m, Vector3.one * 1.4, CFrame.new(top + Vector3.new(2, 0.7, 0)), RGB(110, 220, 255), Enum.Material.Glass, Enum.PartType.Ball)
end

local function trailSwirl(m, top)
	local colors = { RGB(255, 80, 120), RGB(255, 200, 60), RGB(80, 220, 255), RGB(160, 100, 255) }
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		deco(m, Vector3.one * 0.6, CFrame.new(top + Vector3.new(math.cos(a) * 1.6, 1 + i * 0.3, math.sin(a) * 1.0)), colors[(i % 4) + 1], Enum.Material.Neon, Enum.PartType.Ball)
	end
end

local function giftBox(m, top)
	deco(m, Vector3.new(2.4, 2, 2.4), CFrame.new(top + Vector3.new(0, 1, 0)), RGB(255, 80, 120), Enum.Material.SmoothPlastic)
	deco(m, Vector3.new(2.5, 2.05, 0.5), CFrame.new(top + Vector3.new(0, 1, 0)), RGB(255, 220, 60), Enum.Material.SmoothPlastic)
	deco(m, Vector3.new(0.5, 2.05, 2.5), CFrame.new(top + Vector3.new(0, 1, 0)), RGB(255, 220, 60), Enum.Material.SmoothPlastic)
	deco(m, Vector3.one * 0.9, CFrame.new(top + Vector3.new(0, 2.3, 0)), RGB(255, 220, 60), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
end

-- ── base ─────────────────────────────────────────────────────────────
function MapDecor.Base(base, width, depth, plotRadius, plotCFrames)
	local decor = folder(base, "Decor")
	local stands = folder(base, "Stands")
	MapDecor.Stand(stands, "SellStand", "SELL", { RGB(230, 30, 30), RGB(255, 70, 60) }, Vector3.new(-100, 0, -40), "Sell", coinStack)
	MapDecor.FuseMachine(stands, Vector3.new(-50, 0, -84))
	MapDecor.Stand(stands, "TrailsStand", "TRAILS", { RGB(190, 50, 240), RGB(240, 120, 255) }, Vector3.new(48, 0, -82), "Trails", trailSwirl)
	-- the SHOP is right next to where you spawn, facing you
	MapDecor.Stand(stands, "ShopStand", "SHOP", { RGB(245, 170, 20), RGB(255, 225, 70) }, Vector3.new(36, 0, -30), "Shop", giftBox, -math.pi / 2)

	-- cobblestone ring path past every plot's gate + a path from the ring to the zone gate
	local ringR = plotRadius - 58
	local segments = 28
	for k = 0, segments - 1 do
		local a0 = math.rad(180 + 180 * k / segments)
		local a1 = math.rad(180 + 180 * (k + 1) / segments)
		local p0 = Vector3.new(math.cos(a0) * ringR, 0.12, math.sin(a0) * ringR)
		local p1 = Vector3.new(math.cos(a1) * ringR, 0.12, math.sin(a1) * ringR)
		local len = (p1 - p0).Magnitude + 1
		local stone = deco(decor, Vector3.new(10, 0.16, len), CFrame.lookAt((p0 + p1) / 2, p1), RGB(205, 198, 185), Enum.Material.Cobblestone)
		stone.CanCollide = false
	end
	deco(decor, Vector3.new(16, 0.16, ringR), CFrame.new(0, 0.12, -ringR / 2), RGB(205, 198, 185), Enum.Material.Cobblestone)
	-- little paths from the ring to each plot gate
	for _, cf in ipairs(plotCFrames or {}) do
		local gate = (cf * CFrame.new(0, 0, 47.5)).Position
		local toward = Vector3.new(gate.X, 0, gate.Z).Unit * ringR
		deco(decor, Vector3.new(8, 0.15, (Vector3.new(gate.X, 0, gate.Z) - toward).Magnitude + 2), CFrame.lookAt((Vector3.new(gate.X, 0.12, gate.Z) + toward + Vector3.new(0, 0.12, 0)) / 2 + Vector3.new(0, 0.06, 0), toward + Vector3.new(0, 0.18, 0)), RGB(205, 198, 185), Enum.Material.Cobblestone)
	end

	-- small lamps around the ring, bushes & flowers in the plaza, a row of trees along the back wall
	for k = 0, 6 do
		local a = math.rad(195 + k * 25)
		lamp(decor, Vector3.new(math.cos(a) * (ringR - 8), 0, math.sin(a) * (ringR - 8)))
	end
	for _, p in ipairs({ Vector3.new(-205, 0, -20), Vector3.new(205, 0, -20) }) do
		bush(decor, p, 0.9)
	end
	flowers(decor, Vector3.new(-22, 0, -48), 3)
	flowers(decor, Vector3.new(22, 0, -48), 3)
	for x = -width / 2 + 18, width / 2 - 18, 32 do
		tree(decor, Vector3.new(x, 0, -depth + 9), 0.65)
	end
	-- trimmed hedges along both side walls, with flower pots between them
	for z = -30, -depth + 20, -16 do
		for _, s in ipairs({ -1, 1 }) do
			local x = s * (width / 2 - 4)
			part(decor, Vector3.new(3, 3, 10), CFrame.new(x, 1.5, z), RGB(60, 135, 55), Enum.Material.Plastic)
			pcall(extraProp, decor, "flowerpot", Vector3.new(x, 0, z - 8))
		end
	end
	-- slim lamp posts lining the main path (thin, out of the way)
	for z = -20, -120, -25 do
		for _, s in ipairs({ -1, 1 }) do
			prop(decor, Vector3.new(s * 11, 0, z), 0.75, 0, function(m)
				lamp(m, Vector3.zero, RGB(255, 235, 170))
			end)
		end
	end
	-- planters + benches beside every stand
	for _, p in ipairs({ Vector3.new(-100, 0, -40), Vector3.new(-50, 0, -84), Vector3.new(48, 0, -82), Vector3.new(100, 0, -40) }) do
		for _, s in ipairs({ -1, 1 }) do
			pcall(extraProp, decor, "flowerpot", p + Vector3.new(s * 13, 0, 4))
		end
	end
	-- flower beds near the gate (not on the path)
	for _, x in ipairs({ -60, -40, 40, 60 }) do
		flowers(decor, Vector3.new(x, 0, -10), 2.4)
	end
end

-- ── terrain ground (only when GameConfig.Ground == "Terrain") ─────────
MapDecor.UsingTerrain = false
local ZONE_TERRAIN = {
	[1] = Enum.Material.Grass,
	[2] = Enum.Material.Grass,
	[3] = Enum.Material.Pavement,
	[4] = Enum.Material.Sand,
	[5] = Enum.Material.Pavement,
	[6] = Enum.Material.Snow,
}

function MapDecor.Terrain(baseW, baseD, corridor, _corridorEnd)
	local terrain = workspace.Terrain
	-- NOTE: Terrain.Decoration (grass blades) can NOT be set from a script; toggle it in Studio.
	pcall(function()
		terrain.WaterColor = RGB(40, 150, 220)
		terrain.WaterTransparency = 0.4
		terrain.WaterWaveSize = 0.08
	end)
	local function fill(x0, x1, z0, z1, material, thick)
		thick = thick or 12
		terrain:FillBlock(CFrame.new((x0 + x1) / 2, -thick / 2, (z0 + z1) / 2), Vector3.new(x1 - x0, thick, z1 - z0), material)
	end
	fill(-baseW / 2, baseW / 2, -baseD, 0, Enum.Material.Grass)
	local TierConfig = require(game:GetService("ReplicatedStorage").Shared.Config.TierConfig)
	local z = 0
	local hw = corridor / 2
	for tier, t in ipairs(TierConfig.Tiers) do
		fill(-hw, hw, z, z + t.AreaDepth, ZONE_TERRAIN[tier] or Enum.Material.Grass)
		if tier == 4 then
			fill(hw - 16, hw, z, z + t.AreaDepth, Enum.Material.Water, 4)
		end
		z += t.AreaDepth
	end
end

-- ── studs ────────────────────────────────────────────────────────────
-- Turns the finished map into studded plastic bricks (classic LEGO look, like Steal an Egg):
-- every visible block/wedge gets Plastic + Studs on top (and on the sides of big walls/floors).
-- Glass, neon, metal, force fields, see-through parts and characters are left alone.
local KEEP = {
	[Enum.Material.Glass] = true,
	[Enum.Material.Neon] = true,
	[Enum.Material.Metal] = true,
	[Enum.Material.DiamondPlate] = true,
	[Enum.Material.ForceField] = true,
	[Enum.Material.Ice] = true,
	[Enum.Material.Foil] = true,
}
function MapDecor.Studify(root)
	for _, p in ipairs(root:GetDescendants()) do
		local owner = p:FindFirstAncestorWhichIsA("Model")
		local isCharacter = owner ~= nil and owner:FindFirstChildOfClass("Humanoid") ~= nil
		if p:IsA("BasePart") and not KEEP[p.Material] and p.Transparency < 0.5 and not isCharacter then
			local block = p:IsA("WedgePart") or (p:IsA("Part") and p.Shape == Enum.PartType.Block)
			p.Material = Enum.Material.Plastic
			if block then
				p.TopSurface = Enum.SurfaceType.Studs
				p.BottomSurface = Enum.SurfaceType.Inlet
				local big = math.max(p.Size.X, p.Size.Z) >= 12 or p.Size.Y >= 12
				if big then
					p.FrontSurface = Enum.SurfaceType.Studs
					p.BackSurface = Enum.SurfaceType.Studs
					p.LeftSurface = Enum.SurfaceType.Studs
					p.RightSurface = Enum.SurfaceType.Studs
				end
			end
		end
	end
end

function MapDecor.Lighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.5
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.OutdoorAmbient = RGB(150, 150, 165)
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.25
		atmosphere.Haze = 0.8
		atmosphere.Color = RGB(200, 220, 255)
		atmosphere.Decay = RGB(120, 160, 220)
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.2
		cc.Contrast = 0.06
		cc.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.4
		bloom.Size = 24
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
end

return MapDecor
