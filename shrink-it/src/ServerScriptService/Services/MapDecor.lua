--[[
	📍 LOCATION: ServerScriptService > Services > MapDecor (ModuleScript)
	(Helper module used by MapService when it generates the map; not a service.)

	Themed scenery for the generated world:
	  Lobby (fountain, title sign, trees, flower beds) · Plot plaza (trees, lamps)
	  1 Suburbs (road, houses, fences) · 2 Park (paths, trees, hedges, flowers)
	  3 Downtown (road, city blocks, street lamps) · 4 Harbor (sand, water, docks, crates)
	  5 Skyline (huge glass towers with neon) · 6 Summit (rocky peaks, snow, pines)

	All decoration has CanQuery = false so the Shrink Ray aims straight through it,
	and it stays in the border strips (|x| > 110) so it never blocks object spawns.
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

-- ── props ─────────────────────────────────────────────────────────────
local function tree(parent, pos, scale, leaf)
	scale = scale or 1
	local trunkH = 8 * scale
	part(parent, Vector3.new(trunkH, 1.8 * scale, 1.8 * scale), CFrame.new(pos + Vector3.new(0, trunkH / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(120, 80, 45), Enum.Material.Wood, Enum.PartType.Cylinder)
	local leafColor = leaf or RGB(70, 170, 70)
	part(parent, Vector3.one * 9 * scale, CFrame.new(pos + Vector3.new(0, trunkH + 2.5 * scale, 0)), leafColor, Enum.Material.Grass, Enum.PartType.Ball)
	part(parent, Vector3.one * 6 * scale, CFrame.new(pos + Vector3.new(2.5 * scale, trunkH + 0.5 * scale, 1.5 * scale)), leafColor:Lerp(RGB(255, 255, 255), 0.1), Enum.Material.Grass, Enum.PartType.Ball)
end

local function pine(parent, pos, scale)
	scale = scale or 1
	part(parent, Vector3.new(6 * scale, 1.5 * scale, 1.5 * scale), CFrame.new(pos + Vector3.new(0, 3 * scale, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(100, 70, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
	for i, s in ipairs({ 9, 7, 5, 3 }) do
		part(parent, Vector3.new(s * scale, 3 * scale, s * scale), CFrame.new(pos + Vector3.new(0, (4 + i * 2.6) * scale, 0)) * CFrame.Angles(0, math.rad(45 * i), 0), RGB(35, 110, 60), Enum.Material.Grass)
	end
	part(parent, Vector3.new(2.4, 1.2, 2.4) * scale, CFrame.new(pos + Vector3.new(0, 15.6 * scale, 0)), RGB(245, 250, 255), Enum.Material.Snow)
end

local function lamp(parent, pos)
	part(parent, Vector3.new(14, 0.8, 0.8), CFrame.new(pos + Vector3.new(0, 7, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(50, 50, 60), Enum.Material.Metal, Enum.PartType.Cylinder)
	local bulb = part(parent, Vector3.one * 2, CFrame.new(pos + Vector3.new(0, 14.5, 0)), RGB(255, 240, 190), Enum.Material.Neon, Enum.PartType.Ball)
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 22
	light.Brightness = 1.5
	light.Color = RGB(255, 230, 180)
	light.Parent = bulb
end

local function flowers(parent, pos, radius)
	local colors = { RGB(255, 90, 120), RGB(255, 220, 60), RGB(170, 110, 255), RGB(255, 255, 255), RGB(255, 140, 60) }
	part(parent, Vector3.new(0.4, radius * 2, radius * 2), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(90, 60, 40), Enum.Material.Ground, Enum.PartType.Cylinder)
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local r = radius * (0.3 + (i % 3) * 0.22)
		local f = part(parent, Vector3.one * 1.2, CFrame.new(pos + Vector3.new(math.cos(a) * r, 0.9, math.sin(a) * r)), colors[(i % #colors) + 1], Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		f.CanCollide = false
	end
end

local function house(parent, pos, facingSign, color)
	-- facingSign: +1 = front faces +X, -1 = faces -X
	local body = Vector3.new(16, 11, 18)
	local base = CFrame.new(pos + Vector3.new(0, body.Y / 2, 0)) * CFrame.Angles(0, facingSign > 0 and math.rad(-90) or math.rad(90), 0)
	part(parent, body, base, color, Enum.Material.SmoothPlastic)
	-- gable roof (two wedges)
	local roofColor = RGB(190, 60, 55)
	-- a WedgePart is tallest at its back (+Z), so the front half is unrotated and the back half is flipped
	wedge(parent, Vector3.new(body.X + 1, 6, body.Z / 2 + 1), base * CFrame.new(0, body.Y / 2 + 3, -body.Z / 4), roofColor)
	wedge(parent, Vector3.new(body.X + 1, 6, body.Z / 2 + 1), base * CFrame.new(0, body.Y / 2 + 3, body.Z / 4) * CFrame.Angles(0, math.pi, 0), roofColor)
	-- door + windows on the front (-Z of `base`)
	part(parent, Vector3.new(3.5, 6, 0.4), base * CFrame.new(0, -body.Y / 2 + 3, -body.Z / 2 - 0.1), RGB(110, 70, 40), Enum.Material.Wood)
	for _, x in ipairs({ -5, 5 }) do
		part(parent, Vector3.new(3, 3, 0.4), base * CFrame.new(x, 1, -body.Z / 2 - 0.1), RGB(170, 220, 255), Enum.Material.Glass).Transparency = 0.2
	end
	-- chimney
	part(parent, Vector3.new(2, 5, 2), base * CFrame.new(4, body.Y / 2 + 4, 3), RGB(140, 90, 80), Enum.Material.Brick)
end

local function fence(parent, fromPos, toPos)
	local delta = toPos - fromPos
	local len = delta.Magnitude
	local mid = fromPos + delta / 2
	local cf = CFrame.lookAt(mid, toPos)
	part(parent, Vector3.new(0.5, 0.6, len), cf * CFrame.new(0, 2.2, 0), RGB(250, 250, 250))
	part(parent, Vector3.new(0.5, 0.6, len), cf * CFrame.new(0, 1.0, 0), RGB(250, 250, 250))
	for i = 0, math.floor(len / 4) do
		part(parent, Vector3.new(0.6, 3.2, 0.6), CFrame.new(fromPos + delta.Unit * i * 4 + Vector3.new(0, 1.6, 0)), RGB(255, 255, 255))
	end
end

local function tower(parent, pos, w, h, d, color, windowColor, material)
	local body = part(parent, Vector3.new(w, h, d), CFrame.new(pos + Vector3.new(0, h / 2, 0)), color, material or Enum.Material.SmoothPlastic)
	-- glowing window bands
	local bands = math.floor(h / 9)
	for i = 1, bands do
		local y = i * 9 - h / 2 - 2
		local band = part(parent, Vector3.new(w + 0.3, 2.2, d + 0.3), body.CFrame * CFrame.new(0, y, 0), windowColor, Enum.Material.Neon)
		band.Transparency = 0.25
		band.CanCollide = false
	end
	-- roof cap
	part(parent, Vector3.new(w * 0.6, 3, d * 0.6), body.CFrame * CFrame.new(0, h / 2 + 1.5, 0), color:Lerp(RGB(0, 0, 0), 0.3), Enum.Material.Metal)
	return body
end

local function road(parent, z0, depth, width, color)
	part(parent, Vector3.new(width, 0.2, depth), CFrame.new(0, 0.1, z0 + depth / 2), color or RGB(55, 55, 65), Enum.Material.Asphalt)
	for z = z0 + 6, z0 + depth - 6, 14 do
		local dash = part(parent, Vector3.new(1, 0.22, 7), CFrame.new(0, 0.12, z + 3.5), RGB(255, 210, 60), Enum.Material.SmoothPlastic)
		dash.CanCollide = false
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

-- iterate both border strips: fn(x, sideSign) for x on left (-1) and right (+1)
local function bothSides(width, inset, fn)
	fn(-(width / 2 - inset), -1)
	fn(width / 2 - inset, 1)
end

-- ── public ────────────────────────────────────────────────────────────
MapDecor.FloorStyle = {
	[1] = { Material = Enum.Material.Grass, Color = RGB(120, 200, 95) },
	[2] = { Material = Enum.Material.Grass, Color = RGB(95, 185, 85) },
	[3] = { Material = Enum.Material.Concrete, Color = RGB(165, 165, 175) },
	[4] = { Material = Enum.Material.Sand, Color = RGB(235, 215, 160) },
	[5] = { Material = Enum.Material.Pavement, Color = RGB(120, 115, 150) },
	[6] = { Material = Enum.Material.Slate, Color = RGB(130, 125, 125) },
}

-- Max |x| object spawn points may use, so decor in the border never overlaps spawns.
MapDecor.SpawnHalfWidth = 105

function MapDecor.Area(areaModel, tier, z0, depth, width)
	local decor = folder(areaModel, "Decor")
	local zEnd = z0 + depth
	if tier == 1 then -- Suburbs
		road(decor, z0, depth, 26)
		local colors = { RGB(255, 245, 220), RGB(190, 225, 255), RGB(255, 210, 220), RGB(210, 255, 210), RGB(255, 235, 170) }
		local i = 0
		for z = z0 + 18, zEnd - 14, 32 do
			bothSides(width, 18, function(x, side)
				i += 1
				house(decor, Vector3.new(x, 0, z), -side, colors[(i % #colors) + 1])
				fence(decor, Vector3.new(x - side * 12, 0, z - 13), Vector3.new(x - side * 12, 0, z + 13))
			end)
			bothSides(width, 34, function(x)
				tree(decor, Vector3.new(x, 0, z + 16), 0.9)
			end)
		end
	elseif tier == 2 then -- Park
		road(decor, z0, depth, 14, RGB(215, 190, 140))
		for z = z0 + 10, zEnd - 8, 16 do
			bothSides(width, 10, function(x)
				tree(decor, Vector3.new(x + math.random(-3, 3), 0, z), 1 + math.random() * 0.4, math.random() < 0.3 and RGB(240, 150, 190) or nil)
			end)
		end
		for z = z0 + 24, zEnd - 20, 40 do
			bothSides(width, 30, function(x)
				flowers(decor, Vector3.new(x, 0, z), 5)
				part(decor, Vector3.new(4, 3, 16), CFrame.new(x, 1.5, z + 18), RGB(60, 140, 60), Enum.Material.Grass) -- hedge
			end)
		end
	elseif tier == 3 then -- Downtown
		road(decor, z0, depth, 34)
		local palette = { RGB(200, 120, 100), RGB(150, 160, 190), RGB(220, 200, 160), RGB(120, 130, 150), RGB(180, 150, 200) }
		for z = z0 + 16, zEnd - 14, 30 do
			bothSides(width, 18, function(x)
				tower(decor, Vector3.new(x, 0, z), 24, math.random(36, 80), 24, palette[math.random(1, #palette)], RGB(255, 230, 150))
			end)
			bothSides(width, 38, function(x)
				lamp(decor, Vector3.new(x, 0, z + 15))
			end)
		end
	elseif tier == 4 then -- Harbor
		-- right side: sea + docks, left side: warehouses & crates
		local sea = part(decor, Vector3.new(36, 1, depth), CFrame.new(width / 2 - 18, 0.05, z0 + depth / 2), RGB(40, 140, 220), Enum.Material.Glass)
		sea.Transparency = 0.25
		sea.CanCollide = false
		for z = z0 + 20, zEnd - 20, 50 do
			part(decor, Vector3.new(30, 1, 8), CFrame.new(width / 2 - 22, 1, z), RGB(150, 105, 60), Enum.Material.WoodPlanks)
			for _, dx in ipairs({ -12, 0, 12 }) do
				part(decor, Vector3.new(6, 1.2, 1.2), CFrame.new(width / 2 - 22 + dx, -1.5, z + 4) * CFrame.Angles(0, 0, math.rad(90)), RGB(110, 80, 50), Enum.Material.Wood, Enum.PartType.Cylinder)
			end
		end
		for z = z0 + 24, zEnd - 24, 44 do
			tower(decor, Vector3.new(-(width / 2 - 20), 0, z), 28, 18, 32, RGB(150, 70, 60), RGB(255, 220, 140), Enum.Material.Brick)
			crate(decor, Vector3.new(-(width / 2 - 42), 0, z + 6))
			crate(decor, Vector3.new(-(width / 2 - 40), 5, z + 6))
			crate(decor, Vector3.new(-(width / 2 - 44), 0, z - 4))
		end
	elseif tier == 5 then -- Skyline
		local neon = { RGB(255, 80, 200), RGB(80, 220, 255), RGB(180, 120, 255), RGB(255, 200, 80) }
		for z = z0 + 22, zEnd - 20, 42 do
			bothSides(width, 22, function(x)
				local body = tower(decor, Vector3.new(x, 0, z), 32, math.random(110, 220), 32, RGB(70, 90, 130), neon[math.random(1, #neon)], Enum.Material.Glass)
				body.Reflectance = 0.15
			end)
		end
	elseif tier == 6 then -- Summit
		for z = z0 + 30, zEnd - 30, 60 do
			bothSides(width, 22, function(x)
				rock(decor, Vector3.new(x, 18, z), Vector3.new(44, 50, 48), RGB(110, 105, 105), true)
				rock(decor, Vector3.new(x - (x > 0 and 6 or -6), 8, z + 30), Vector3.new(24, 20, 24), RGB(125, 120, 118), false)
			end)
			bothSides(width, 46, function(x)
				pine(decor, Vector3.new(x, 0, z + 18), 1.1)
			end)
		end
	end
end

function MapDecor.Lobby(lobby, depth)
	local decor = folder(lobby, "Decor")
	-- fountain
	local center = Vector3.new(0, 0, 28)
	part(decor, Vector3.new(2, 26, 26), CFrame.new(center + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(225, 225, 235), Enum.Material.Marble, Enum.PartType.Cylinder)
	local water = part(decor, Vector3.new(0.4, 23, 23), CFrame.new(center + Vector3.new(0, 2.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(80, 190, 255), Enum.Material.Glass, Enum.PartType.Cylinder)
	water.Transparency = 0.2
	part(decor, Vector3.new(9, 3, 3), CFrame.new(center + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90)), RGB(235, 235, 245), Enum.Material.Marble, Enum.PartType.Cylinder)
	local orb = part(decor, Vector3.one * 5, CFrame.new(center + Vector3.new(0, 12.5, 0)), RGB(120, 230, 255), Enum.Material.Neon, Enum.PartType.Ball)
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

	-- big title sign over the path into the Suburbs
	local sign = part(decor, Vector3.new(90, 22, 2), CFrame.lookAt(Vector3.new(0, 40, depth / 2 - 4), Vector3.new(0, 40, 0)), RGB(40, 40, 70), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 15
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = RGB(255, 220, 60)
	label.Text = "SHRINK IT! 🔬\n➜ Suburbs"
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Parent = label
	for _, x in ipairs({ -46, 46 }) do
		part(decor, Vector3.new(4, 52, 4), CFrame.new(x, 26, depth / 2 - 4), RGB(255, 200, 60), Enum.Material.SmoothPlastic)
	end

	-- trees & flowers around the edges (avoiding boards, VIP room and like sign)
	for _, x in ipairs({ -110, -80, 80 }) do
		tree(decor, Vector3.new(x, 0, depth / 2 - 10), 1.1)
	end
	for _, x in ipairs({ -110, -60, 60, 110 }) do
		tree(decor, Vector3.new(x, 0, -depth / 2 + 10), 1.1)
	end
	flowers(decor, Vector3.new(-40, 0, 28), 6)
	flowers(decor, Vector3.new(40, 0, 28), 6)
	for _, z in ipairs({ -60, -30, 0 }) do
		lamp(decor, Vector3.new(-26, 0, z))
		lamp(decor, Vector3.new(26, 0, z))
	end
end

function MapDecor.Plaza(plotsFolder, centerZ, width, depth)
	local decor = folder(plotsFolder, "Decor")
	for x = -width / 2 + 10, width / 2 - 10, 40 do
		tree(decor, Vector3.new(x, 0, centerZ - depth / 2 + 6), 1)
	end
	for z = centerZ - depth / 2 + 30, centerZ + depth / 2 - 30, 50 do
		tree(decor, Vector3.new(-width / 2 + 6, 0, z), 1)
		tree(decor, Vector3.new(width / 2 - 6, 0, z), 1)
	end
	-- lamps along the walkways between plots
	for _, x in ipairs({ -150, 0, 150 }) do
		for z = centerZ - depth / 2 + 20, centerZ + depth / 2 - 20, 45 do
			lamp(decor, Vector3.new(x, 0, z))
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
		atmosphere.Density = 0.28
		atmosphere.Haze = 1
		atmosphere.Color = RGB(200, 220, 255)
		atmosphere.Decay = RGB(120, 160, 220)
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.18
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
