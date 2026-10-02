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
	[4] = { Material = Enum.Material.Plastic, Color = RGB(236, 214, 160) }, -- Harbor
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
local ZONE_PROPS = {
	[1] = { "bush", "flowers", "bush", "sunflower" },
	[2] = { "bush", "mailbox", "flowers", "bush" },
	[3] = { "cone", "lamp", "cone", "bush" },
	[4] = { "crate", "barrel", "crate", "rock" },
	[5] = { "cactus", "rock", "cactus", "bones" },
	[6] = { "bush", "palm", "bush", "flowers" },
	[7] = { "lamp", "cone", "crate", "lamp" },
	[8] = { "rock", "lava", "rock", "lava" },
	[9] = { "pine", "snowrock", "pine", "snowrock" },
	[10] = { "crystal", "moonrock", "crystal", "moonrock" },
}

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

function MapDecor.Zone(zoneModel, tier, z0, depth, width)
	local decor = folder(zoneModel, "Decor")
	local kinds = ZONE_PROPS[tier] or ZONE_PROPS[1]
	local edge = width / 2 - 6 -- props hug the walls
	local i = 0
	for z = z0 + 18, z0 + depth - 10, 34 do
		for _, s in ipairs({ -1, 1 }) do
			i += 1
			local kind = kinds[(i % #kinds) + 1]
			local ok, err = pcall(smallProp, decor, kind, Vector3.new(s * (edge - math.random(0, 6)), 0, z + math.random(-6, 6)))
			if not ok then
				warn("[MapDecor] prop " .. kind .. " failed: " .. tostring(err))
			end
		end
	end
	if tier == 10 then -- a starry sky feeling: little glowing dots on the walls
		for _ = 1, 30 do
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

local function floatingTitle(adornee, text, colors, height, sub)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(380, sub and 130 or 84)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.Adornee = adornee
	gui.MaxDistance = 260
	gui.LightInfluence = 0
	gui.Parent = adornee
	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.new(1, 0, 0, 84)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = RGB(255, 255, 255)
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 5
	stroke.Parent = label
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(colors[1], colors[2])
	grad.Rotation = 90
	grad.Parent = label
	if sub then
		local s = label:Clone()
		s.Name = "Sub"
		s.Text = sub
		s.Position = UDim2.fromOffset(0, 84)
		s.Size = UDim2.new(1, 0, 0, 46)
		s:FindFirstChildOfClass("UIGradient"):Destroy()
		s.Parent = gui
	end
	return gui
end
MapDecor.FloatingTitle = floatingTitle

-- ── stands (SELL / FUSE / TRAILS / SHOP) ──────────────────────────────
-- A market stall with a striped awning, a big floating label and a ProximityPrompt that
-- opens a menu on the client (the prompt's "OpensMenu" attribute = menu name).
function MapDecor.Stand(parent, name, label, colors, worldPos, menu, propFn)
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
	-- shopkeeper behind the counter
	pcall(function()
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = RGB(234, 184, 146)
		desc.LeftArmColor = RGB(234, 184, 146)
		desc.RightArmColor = RGB(234, 184, 146)
		desc.TorsoColor = colors[1]
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
		npc:PivotTo(CFrame.new(pos + Vector3.new(0, size.Y / 2, -1)) * CFrame.Angles(0, math.pi, 0))
		local head = npc:FindFirstChild("Head")
		if head then -- a little cap in the stand's color
			local cap = Instance.new("Part")
			cap.Anchored = true
			cap.CanCollide = false
			cap.Size = Vector3.new(1.3, 0.35, 1.4)
			cap.CFrame = head.CFrame * CFrame.new(0, 0.62, 0)
			cap.Color = colors[1]
			cap.Material = Enum.Material.Fabric
			cap.Parent = npc
		end
		npc.Parent = m
	end)
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
	m:PivotTo(CFrame.new(worldPos))
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
	MapDecor.Stand(stands, "ShopStand", "SHOP", { RGB(245, 170, 20), RGB(255, 225, 70) }, Vector3.new(100, 0, -40), "Shop", giftBox)

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
