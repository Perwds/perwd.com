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

local function wedge(parent, size, cframe, color, material)
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.CanQuery = false
	w.Size = size
	w.CFrame = cframe
	w.Color = color
	w.Material = material or Enum.Material.SmoothPlastic
	w.Parent = parent
	return w
end

local function folder(parent, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function sign(target, face, text, color, ppS)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppS or 12
	gui.LightInfluence = 0
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 5
	stroke.Parent = label
	return label
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
	part(parent, Vector3.one * 9 * scale, CFrame.new(pos + Vector3.new(0, trunkH + 2.5 * scale, 0)), leafColor, Enum.Material.Grass, Enum.PartType.Ball)
	part(parent, Vector3.one * 6 * scale, CFrame.new(pos + Vector3.new(2.5 * scale, trunkH + 0.5 * scale, 1.5 * scale)), leafColor:Lerp(RGB(255, 255, 255), 0.1), Enum.Material.Grass, Enum.PartType.Ball)
	part(parent, Vector3.one * 5 * scale, CFrame.new(pos + Vector3.new(-2 * scale, trunkH + 1 * scale, -2 * scale)), leafColor:Lerp(RGB(0, 0, 0), 0.08), Enum.Material.Grass, Enum.PartType.Ball)
end

local function pine(parent, pos, scale)
	scale = scale or 1
	part(parent, Vector3.new(6 * scale, 1.5 * scale, 1.5 * scale), upright(pos, 6 * scale), RGB(100, 70, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
	for i, s in ipairs({ 9, 7, 5, 3 }) do
		part(parent, Vector3.new(s * scale, 3 * scale, s * scale), CFrame.new(pos + Vector3.new(0, (4 + i * 2.6) * scale, 0)) * CFrame.Angles(0, math.rad(45 * i), 0), RGB(35, 110, 60), Enum.Material.Grass)
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
	deco(parent, Vector3.new(7, 0.4, 0.4), upright(pos, 7), RGB(70, 150, 60), Enum.Material.Grass, Enum.PartType.Cylinder)
	deco(parent, Vector3.new(0.4, 2.6, 2.6), CFrame.new(pos + Vector3.new(0, 7.2, 0)) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, 0), RGB(255, 210, 40), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	deco(parent, Vector3.new(0.5, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 7.2, 0)) * CFrame.Angles(0, math.rad(90), 0), RGB(110, 70, 30), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
end

local function gardenBed(parent, pos, length)
	part(parent, Vector3.new(6, 1, length), CFrame.new(pos + Vector3.new(0, 0.5, 0)), RGB(120, 80, 50), Enum.Material.Ground)
	for z = -length / 2 + 2, length / 2 - 2, 2.5 do
		deco(parent, Vector3.new(1, 1.6, 1), CFrame.new(pos + Vector3.new(-1.5, 1.6, z)), RGB(80, 180, 70), Enum.Material.Grass)
		deco(parent, Vector3.new(1, 1.2, 1), CFrame.new(pos + Vector3.new(1.5, 1.4, z + 1)), RGB(255, 120, 60), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
end

local function fence(parent, fromPos, toPos, color)
	color = color or RGB(250, 250, 250)
	local delta = toPos - fromPos
	local len = delta.Magnitude
	local cf = CFrame.lookAt(fromPos + delta / 2, toPos)
	part(parent, Vector3.new(0.4, 0.5, len), cf * CFrame.new(0, 2.4, 0), color)
	part(parent, Vector3.new(0.4, 0.5, len), cf * CFrame.new(0, 1.1, 0), color)
	for i = 0, math.floor(len / 3) do
		part(parent, Vector3.new(0.6, 3.4, 0.9), CFrame.new(fromPos + delta.Unit * i * 3 + Vector3.new(0, 1.7, 0)), color)
	end
end

local function house(parent, pos, facingSign, color, roofColor)
	-- facingSign: +1 = front faces +X, -1 = faces -X
	local body = Vector3.new(16, 11, 18)
	local base = CFrame.new(pos + Vector3.new(0, body.Y / 2, 0)) * CFrame.Angles(0, facingSign > 0 and math.rad(-90) or math.rad(90), 0)
	part(parent, body, base, color, Enum.Material.SmoothPlastic)
	roofColor = roofColor or RGB(190, 60, 55)
	-- a WedgePart is tallest at its back (+Z): front half unrotated, back half flipped
	wedge(parent, Vector3.new(body.X + 1, 6, body.Z / 2 + 1), base * CFrame.new(0, body.Y / 2 + 3, -body.Z / 4), roofColor)
	wedge(parent, Vector3.new(body.X + 1, 6, body.Z / 2 + 1), base * CFrame.new(0, body.Y / 2 + 3, body.Z / 4) * CFrame.Angles(0, math.pi, 0), roofColor)
	part(parent, Vector3.new(3.5, 6, 0.4), base * CFrame.new(0, -body.Y / 2 + 3, -body.Z / 2 - 0.1), RGB(110, 70, 40), Enum.Material.Wood)
	for _, x in ipairs({ -5, 5 }) do
		local w = part(parent, Vector3.new(3, 3, 0.4), base * CFrame.new(x, 1, -body.Z / 2 - 0.1), RGB(170, 220, 255), Enum.Material.Glass)
		w.Transparency = 0.2
		part(parent, Vector3.new(3.8, 0.4, 0.6), base * CFrame.new(x, -0.7, -body.Z / 2 - 0.2), RGB(255, 255, 255))
	end
	part(parent, Vector3.new(2, 5, 2), base * CFrame.new(4, body.Y / 2 + 4, 3), RGB(140, 90, 80), Enum.Material.Brick)
	return base
end

local function mailbox(parent, pos, color)
	part(parent, Vector3.new(3.4, 0.4, 0.4), upright(pos, 3.4), RGB(90, 70, 50), Enum.Material.Wood, Enum.PartType.Cylinder)
	part(parent, Vector3.new(1, 1, 1.8), CFrame.new(pos + Vector3.new(0, 3.8, 0)), color or RGB(40, 80, 200))
	deco(parent, Vector3.new(0.1, 0.8, 0.3), CFrame.new(pos + Vector3.new(0.55, 4.2, 0.4)), RGB(230, 40, 40))
end

local function tower(parent, pos, w, h, d, color, windowColor, material)
	local body = part(parent, Vector3.new(w, h, d), CFrame.new(pos + Vector3.new(0, h / 2, 0)), color, material or Enum.Material.SmoothPlastic)
	for i = 1, math.floor(h / 9) do
		local band = deco(parent, Vector3.new(w + 0.3, 2.2, d + 0.3), body.CFrame * CFrame.new(0, i * 9 - h / 2 - 2, 0), windowColor, Enum.Material.Neon)
		band.Transparency = 0.25
	end
	part(parent, Vector3.new(w * 0.6, 3, d * 0.6), body.CFrame * CFrame.new(0, h / 2 + 1.5, 0), color:Lerp(RGB(0, 0, 0), 0.3), Enum.Material.Metal)
	return body
end

local function road(parent, z0, depth, width, color, dashes)
	part(parent, Vector3.new(width, 0.2, depth), CFrame.new(0, 0.1, z0 + depth / 2), color or RGB(55, 55, 65), Enum.Material.Asphalt)
	if dashes ~= false then
		for z = z0 + 6, z0 + depth - 10, 14 do
			deco(parent, Vector3.new(1, 0.22, 7), CFrame.new(0, 0.12, z + 3.5), RGB(255, 210, 60), Enum.Material.SmoothPlastic)
		end
	end
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
	[1] = { Material = Enum.Material.SmoothPlastic, Color = RGB(110, 210, 80) },
	[2] = { Material = Enum.Material.SmoothPlastic, Color = RGB(95, 195, 75) },
	[3] = { Material = Enum.Material.Concrete, Color = RGB(170, 170, 180) },
	[4] = { Material = Enum.Material.Sand, Color = RGB(238, 216, 160) },
	[5] = { Material = Enum.Material.Pavement, Color = RGB(110, 105, 140) },
	[6] = { Material = Enum.Material.Snow, Color = RGB(235, 242, 252) },
}

local WALL_STYLE = {
	Base = { A = RGB(90, 175, 225), B = RGB(70, 150, 205), Cap = RGB(110, 210, 80), Material = Enum.Material.SmoothPlastic },
	[1] = { A = RGB(205, 125, 75), B = RGB(180, 100, 58), Cap = RGB(110, 210, 80), Material = Enum.Material.SmoothPlastic },
	[2] = { A = RGB(185, 85, 65), B = RGB(160, 70, 55), Cap = RGB(95, 195, 75), Material = Enum.Material.Brick },
	[3] = { A = RGB(150, 150, 162), B = RGB(128, 128, 140), Cap = RGB(80, 80, 92), Material = Enum.Material.Concrete },
	[4] = { A = RGB(160, 112, 65), B = RGB(135, 92, 52), Cap = RGB(60, 150, 220), Material = Enum.Material.WoodPlanks },
	[5] = { A = RGB(62, 72, 112), B = RGB(46, 54, 90), Cap = RGB(200, 90, 255), Material = Enum.Material.Glass },
	[6] = { A = RGB(205, 222, 242), B = RGB(182, 202, 228), Cap = RGB(250, 252, 255), Material = Enum.Material.Ice },
}

-- One straight wall from a to b (XZ), built from alternating checker panels + a cap.
local function wallRun(parent, a, b, height, style)
	local delta = b - a
	local len = delta.Magnitude
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
	part(parent, Vector3.new(3, 2, len + 1), cf * CFrame.new(0, height + 1, 0), style.Cap, Enum.Material.SmoothPlastic)
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

-- Arch + sign at the start of each zone.
function MapDecor.ZoneArch(zone, tier, t, z, width)
	local ChaserConfig = require(game:GetService("ReplicatedStorage").Shared.Config.ChaserConfig)
	local chaser = ChaserConfig.Get(tier)
	local arch = folder(zone, "Arch")
	local color = t.Color
	for _, side in ipairs({ -1, 1 }) do
		part(arch, Vector3.new(8, 40, 8), CFrame.new(side * (width / 2 - 6), 20, z), color, Enum.Material.SmoothPlastic)
		deco(arch, Vector3.new(9, 2, 9), CFrame.new(side * (width / 2 - 6), 41, z), RGB(255, 255, 255), Enum.Material.Neon)
	end
	local beam = part(arch, Vector3.new(width - 4, 14, 3), CFrame.new(0, 36, z), RGB(40, 40, 60), Enum.Material.SmoothPlastic)
	beam.CanCollide = false
	sign(beam, Enum.NormalId.Front, string.format("ZONE %d · %s\n%s Watch out for %s!  ·  Full speed at Ray Power %d", tier, string.upper(t.Area), chaser.Emoji, chaser.Name, t.RayPowerRequired), color:Lerp(RGB(255, 255, 255), 0.35), 8)
	sign(beam, Enum.NormalId.Back, tier == 1 and "🏠 SAFE ZONE ⬇  drop off your loot!" or "⬇ BACK TO BASE ⬇", RGB(120, 255, 140), 8)
	-- floor line
	deco(arch, Vector3.new(width - 4, 0.25, 3), CFrame.new(0, 0.12, z), tier == 1 and RGB(255, 60, 60) or color, Enum.Material.Neon)
end

-- ── zones ────────────────────────────────────────────────────────────
function MapDecor.Zone(zoneModel, tier, z0, depth, width)
	local decor = folder(zoneModel, "Decor")
	local zEnd = z0 + depth
	local edge = width / 2 -- 100
	local function sides(fn)
		fn(-1)
		fn(1)
	end

	if tier == 1 then -- Grandpa's Backyard
		sides(function(s)
			fence(decor, Vector3.new(s * 73, 0, z0 + 8), Vector3.new(s * 73, 0, zEnd - 8))
		end)
		local i = 0
		for z = z0 + 20, zEnd - 20, 26 do
			i += 1
			sides(function(s)
				if (i + (s > 0 and 1 or 0)) % 3 == 0 then
					tree(decor, Vector3.new(s * 88, 0, z), 1.1)
				elseif (i + (s > 0 and 1 or 0)) % 3 == 1 then
					gardenBed(decor, Vector3.new(s * 86, 0, z), 16)
				else
					for k = 0, 2 do
						sunflower(decor, Vector3.new(s * (82 + k * 5), 0, z + k * 2))
					end
				end
			end)
		end
		-- Grandpa's cottage + rocking chair near the end of the yard
		local cf = house(decor, Vector3.new(-86, 0, zEnd - 40), 1, RGB(255, 240, 210), RGB(120, 80, 60))
		local signPart = part(decor, Vector3.new(12, 3, 0.5), cf * CFrame.new(0, 8.5, -9.4), RGB(120, 80, 50), Enum.Material.Wood)
		sign(signPart, Enum.NormalId.Front, "👴 GRANDPA'S HOUSE", RGB(255, 230, 160), 20)
		part(decor, Vector3.new(3, 0.5, 3), CFrame.new(-75, 1.5, zEnd - 52), RGB(140, 90, 50), Enum.Material.Wood)
		part(decor, Vector3.new(3, 3, 0.5), CFrame.new(-75, 3, zEnd - 50.8), RGB(140, 90, 50), Enum.Material.Wood)
		-- garden shed on the other side
		local shed = part(decor, Vector3.new(12, 9, 10), CFrame.new(87, 4.5, z0 + 60), RGB(120, 160, 110), Enum.Material.WoodPlanks)
		wedge(decor, Vector3.new(12.5, 3, 10.5), shed.CFrame * CFrame.new(0, 6, 0) * CFrame.Angles(0, math.rad(90), 0), RGB(150, 70, 60))
		mailbox(decor, Vector3.new(-70, 0, zEnd - 25))
		-- scattered grass tufts & flowers across the yard
		for _ = 1, 60 do
			local p = Vector3.new(math.random(-70, 70), 0, math.random(z0 + 5, zEnd - 5))
			deco(decor, Vector3.new(0.6, 1, 0.6), CFrame.new(p + Vector3.new(0, 0.5, 0)), RGB(70, 170, 60), Enum.Material.Grass)
			if math.random() < 0.35 then
				deco(decor, Vector3.one * 0.9, CFrame.new(p + Vector3.new(0.6, 0.8, 0.3)), FLOWER_COLORS[math.random(1, #FLOWER_COLORS)], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			end
		end
	elseif tier == 2 then -- Neighborhood
		road(decor, z0, depth, 30)
		sides(function(s)
			part(decor, Vector3.new(8, 0.6, depth), CFrame.new(s * 19, 0.3, z0 + depth / 2), RGB(200, 200, 205), Enum.Material.Concrete) -- sidewalk
			part(decor, Vector3.new(0.6, 0.8, depth), CFrame.new(s * 15.2, 0.4, z0 + depth / 2), RGB(240, 240, 245), Enum.Material.Concrete) -- curb
		end)
		local colors = { RGB(255, 245, 220), RGB(190, 225, 255), RGB(255, 210, 220), RGB(210, 255, 210), RGB(255, 235, 170), RGB(230, 210, 255) }
		local roofs = { RGB(190, 60, 55), RGB(70, 80, 110), RGB(120, 80, 60), RGB(60, 120, 80) }
		local i = 0
		for z = z0 + 24, zEnd - 18, 34 do
			sides(function(s)
				i += 1
				house(decor, Vector3.new(s * 88, 0, z), -s, colors[(i % #colors) + 1], roofs[(i % #roofs) + 1])
				mailbox(decor, Vector3.new(s * 76, 0, z - 8), colors[((i + 2) % #colors) + 1]:Lerp(RGB(0, 0, 0), 0.4))
				fence(decor, Vector3.new(s * 75, 0, z + 4), Vector3.new(s * 75, 0, z + 15))
				tree(decor, Vector3.new(s * 84, 0, z + 17), 0.8)
			end)
			sides(function(s)
				lamp(decor, Vector3.new(s * 23, 0, z))
			end)
		end
	elseif tier == 3 then -- Downtown
		road(decor, z0, depth, 44)
		sides(function(s)
			part(decor, Vector3.new(10, 0.6, depth), CFrame.new(s * 27, 0.3, z0 + depth / 2), RGB(195, 195, 200), Enum.Material.Concrete)
		end)
		for z = z0 + 40, zEnd - 30, 120 do -- crosswalks
			for x = -18, 18, 6 do
				deco(decor, Vector3.new(3, 0.24, 10), CFrame.new(x, 0.14, z), RGB(250, 250, 250))
			end
		end
		local palette = { RGB(200, 120, 100), RGB(150, 160, 190), RGB(220, 200, 160), RGB(120, 130, 150), RGB(180, 150, 200), RGB(110, 170, 160) }
		for z = z0 + 16, zEnd - 14, 28 do
			sides(function(s)
				tower(decor, Vector3.new(s * 87, 0, z), 22, math.random(36, 90), 24, palette[math.random(1, #palette)], RGB(255, 230, 150))
			end)
		end
		for z = z0 + 10, zEnd - 10, 36 do
			sides(function(s)
				lamp(decor, Vector3.new(s * 31, 0, z), RGB(255, 245, 210))
			end)
		end
		for _ = 1, 10 do
			cone(decor, Vector3.new(math.random(-20, 20), 0, math.random(z0 + 10, zEnd - 10)))
		end
	elseif tier == 4 then -- Harbor
		local sea = deco(decor, Vector3.new(30, 1, depth), CFrame.new(edge - 15, 0.1, z0 + depth / 2), RGB(40, 140, 220), Enum.Material.Glass)
		sea.Transparency = 0.2
		sea.CanCollide = true
		for z = z0 + 30, zEnd - 30, 60 do
			part(decor, Vector3.new(34, 1, 8), CFrame.new(edge - 22, 1, z), RGB(150, 105, 60), Enum.Material.WoodPlanks)
			barrel(decor, Vector3.new(edge - 30, 1.5, z + 1))
		end
		for z = z0 + 30, zEnd - 30, 52 do
			tower(decor, Vector3.new(-86, 0, z), 24, 18, 34, RGB(150, 70, 60), RGB(255, 220, 140), Enum.Material.Brick)
			crate(decor, Vector3.new(-71, 0, z + 8))
			crate(decor, Vector3.new(-71, 5, z + 8))
			crate(decor, Vector3.new(-72, 0, z - 6))
			barrel(decor, Vector3.new(-70, 0, z + 20))
		end
		-- lighthouse at the far end
		local base = Vector3.new(80, 0, zEnd - 30)
		part(decor, Vector3.new(36, 12, 12), upright(base, 36), RGB(245, 245, 245), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		for _, y in ipairs({ 6, 18, 30 }) do
			part(decor, Vector3.new(5, 12.4, 12.4), CFrame.new(base + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(220, 50, 50), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
		local light = deco(decor, Vector3.one * 7, CFrame.new(base + Vector3.new(0, 40, 0)), RGB(255, 240, 150), Enum.Material.Neon, Enum.PartType.Ball)
		local pl = Instance.new("PointLight")
		pl.Range = 60
		pl.Brightness = 2
		pl.Parent = light
	elseif tier == 5 then -- Skyline
		local neon = { RGB(255, 80, 200), RGB(80, 220, 255), RGB(180, 120, 255), RGB(255, 200, 80) }
		for z = z0 + 24, zEnd - 20, 40 do
			sides(function(s)
				local body = tower(decor, Vector3.new(s * 87, 0, z), 22, math.random(100, 220), 30, RGB(70, 90, 130), neon[math.random(1, #neon)], Enum.Material.Glass)
				body.Reflectance = 0.15
			end)
		end
		sides(function(s)
			deco(decor, Vector3.new(1, 0.3, depth), CFrame.new(s * 73, 0.2, z0 + depth / 2), RGB(200, 90, 255), Enum.Material.Neon)
		end)
	elseif tier == 6 then -- Summit
		for z = z0 + 30, zEnd - 30, 55 do
			sides(function(s)
				rock(decor, Vector3.new(s * 92, 16, z), Vector3.new(30, 44, 40), RGB(110, 105, 105), true)
				pine(decor, Vector3.new(s * 79, 0, z + 26), 1.1)
			end)
		end
		for _ = 1, 25 do
			deco(decor, Vector3.new(math.random(3, 8), 1, math.random(3, 8)), CFrame.new(math.random(-65, 65), 0.4, math.random(z0 + 10, zEnd - 10)), RGB(250, 252, 255), Enum.Material.Snow)
		end
	end
end

-- ── base ─────────────────────────────────────────────────────────────
function MapDecor.Base(base, width, depth)
	local decor = folder(base, "Decor")
	-- stone path from the back of the base to the corridor
	part(decor, Vector3.new(30, 0.2, depth), CFrame.new(0, 0.1, -depth / 2), RGB(205, 200, 190), Enum.Material.Cobblestone)
	-- side paths to each column of plots
	for _, z in ipairs({ -60, -155, -250, -345 }) do
		part(decor, Vector3.new(120, 0.2, 10), CFrame.new(0, 0.11, z), RGB(205, 200, 190), Enum.Material.Cobblestone)
	end

	-- fountain
	local center = Vector3.new(0, 0, -205)
	part(decor, Vector3.new(2, 26, 26), CFrame.new(center + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(225, 225, 235), Enum.Material.Marble, Enum.PartType.Cylinder)
	local water = deco(decor, Vector3.new(0.4, 23, 23), CFrame.new(center + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(80, 190, 255), Enum.Material.Glass, Enum.PartType.Cylinder)
	water.Transparency = 0.2
	part(decor, Vector3.new(9, 3, 3), CFrame.new(center + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(235, 235, 245), Enum.Material.Marble, Enum.PartType.Cylinder)
	local orb = deco(decor, Vector3.one * 5, CFrame.new(center + Vector3.new(0, 12.5, 0)), RGB(120, 230, 255), Enum.Material.Neon, Enum.PartType.Ball)
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(RGB(160, 230, 255))
	spray.Rate = 25
	spray.Speed = NumberRange.new(8, 12)
	spray.SpreadAngle = Vector2.new(25, 25)
	spray.Acceleration = Vector3.new(0, -25, 0)
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Size = NumberSequence.new(0.6, 0)
	spray.Parent = orb

	-- title above the spawn
	local title = part(decor, Vector3.new(70, 16, 2), CFrame.lookAt(Vector3.new(0, 34, -110), Vector3.new(0, 34, 0)), RGB(40, 40, 70), Enum.Material.SmoothPlastic)
	title.CanCollide = false
	sign(title, Enum.NormalId.Front, "SHRINK IT! 🔬", RGB(255, 220, 60), 14)
	for _, x in ipairs({ -33, 33 }) do
		part(decor, Vector3.new(3, 42, 3), CFrame.new(x, 21, -110), RGB(255, 200, 60), Enum.Material.SmoothPlastic)
	end
	local how = part(decor, Vector3.new(60, 8, 1), CFrame.lookAt(Vector3.new(0, 22, -110.5), Vector3.new(0, 22, 0)), RGB(255, 255, 255), Enum.Material.SmoothPlastic)
	how.CanCollide = false
	how.Transparency = 1
	sign(how, Enum.NormalId.Front, "🔬 Shrink stuff → 🎒 run it back here → 💰 cash every second!", RGB(255, 255, 255), 14)

	-- trees along the outer edges, flowers & lamps along the path
	for z = -20, -depth + 20, -40 do
		tree(decor, Vector3.new(-width / 2 + 16, 0, z), 1.1)
		tree(decor, Vector3.new(width / 2 - 16, 0, z), 1.1)
	end
	for z = -30, -depth + 60, -50 do
		lamp(decor, Vector3.new(-19, 0, z))
		lamp(decor, Vector3.new(19, 0, z))
	end
	flowers(decor, Vector3.new(-40, 0, -40), 6)
	flowers(decor, Vector3.new(40, 0, -40), 6)
	flowers(decor, Vector3.new(40, 0, -150), 6)
	flowers(decor, Vector3.new(-40, 0, -260), 5)
	flowers(decor, Vector3.new(40, 0, -260), 5)
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
