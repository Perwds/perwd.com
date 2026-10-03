--[[
	📍 LOCATION: ReplicatedStorage > Shared > Nameplate (ModuleScript)

	Draws a Name Plate (NameplateConfig) out of plain frames: dark outline, colored frame, a banner
	that fades from light on the left to the plate's color on the right, a pattern, a pixel icon and
	the name. Everything is sized in scale, so the same plate works over a head (BillboardGui) and in
	the menu. Plates with a rainbow frame or a shine are tagged "NameplateFX"; the client animates
	them with Nameplate.Animate.
]]

local CollectionService = game:GetService("CollectionService")

local NameplateConfig = require(script.Parent.Config.NameplateConfig)

local Nameplate = {}

local RGB = Color3.fromRGB
local OUTLINE = RGB(22, 22, 32)
local FONT = Enum.Font.FredokaOne

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, RGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, RGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, RGB(255, 240, 60)),
	ColorSequenceKeypoint.new(0.6, RGB(60, 220, 90)),
	ColorSequenceKeypoint.new(0.8, RGB(60, 140, 255)),
	ColorSequenceKeypoint.new(1, RGB(190, 80, 255)),
})

-- ── pixel icons ───────────────────────────────────────────────────────
local PALETTE = {
	k = RGB(25, 20, 30),
	w = RGB(255, 255, 255),
	r = RGB(235, 50, 70),
	R = RGB(165, 25, 50),
	m = RGB(255, 150, 190),
	y = RGB(255, 215, 40),
	o = RGB(240, 135, 25),
	g = RGB(85, 205, 70),
	d = RGB(35, 130, 50),
	c = RGB(120, 230, 255),
	b = RGB(40, 120, 230),
	s = RGB(200, 205, 220),
	n = RGB(140, 85, 40),
}

Nameplate.Icons = {
	heart = { ".kk..kk.", "kmrkkrrk", "kmrrrrrk", "krrrrrRk", ".krrrRk.", "..krRk..", "...kk..." },
	star = { "....k....", "...kyk...", "kkkyyykkk", "kyyywyyyk", ".kyyyyyk.", "..kyyyk..", ".kyykyyk.", "kyok.koyk", "kkk...kkk" },
	clover = { ".kk..kk.", "kgwkkggk", "kggggggk", ".kggggk.", "kggggggk", "kgdkkdgk", ".kkknkk.", "....nk.." },
	gem = { "..kkkk..", ".kwccbk.", "kwcccbbk", "kccccbbk", ".kccbbk.", "..kcbk..", "...kk..." },
	crown = { "k...k...k", "kk.kyk.kk", "kykyyykyk", "kyyyyyyyk", "kyrywyryk", "kyyyyyyyk", "kkkkkkkkk" },
	bolt = { "....kkk.", "...kyyk.", "..kyyk..", ".kyyykk.", ".kkyyyk.", "..kyyk..", "..kyk...", "..kk...." },
	flame = { "...k....", "..kok...", "..korkk.", ".korrok.", "korryrok", "koryyrok", ".koyyok.", "..kkkk.." },
	skull = { ".kkkkkkk.", "kwwwwwwwk", "kwkkwkkwk", "kwkkwkkwk", "kwwwkwwwk", ".kwwwwwk.", ".kwkwkwk.", "..kkkkk.." },
	sword = { "......kk", ".....kwk", "....kwsk", "k..kwsk.", "kkkwsk..", ".knkk...", "knkkk...", "kk......" },
	coin = { "..kkkk..", ".kyyyyk.", "kywyyyok", "kyyyyyok", "kyyyyyok", "kyyyyook", ".kooook.", "..kkkk.." },
	potion = { "..kkkk..", "...nn...", "..kssk..", ".kggggk.", "kgwggggk", "kggggddk", ".kggddk.", "..kkkk.." },
}

-- a square frame holding the icon as pixel runs (one frame per run of the same color)
function Nameplate.Icon(name, props)
	local grid = Nameplate.Icons[name]
	if not grid then
		return nil
	end
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.Size = props.Size or UDim2.fromScale(1, 1)
	holder.Position = props.Position or UDim2.new()
	holder.AnchorPoint = props.AnchorPoint or Vector2.zero
	holder.SizeConstraint = props.SizeConstraint or Enum.SizeConstraint.RelativeXY
	holder.ZIndex = props.ZIndex or 1
	local rows = #grid
	local cols = 0
	for _, row in ipairs(grid) do
		cols = math.max(cols, #row)
	end
	local cell = 1 / math.max(rows, cols)
	local ox = (1 - cols * cell) / 2
	local oy = (1 - rows * cell) / 2
	for y, row in ipairs(grid) do
		local x = 1
		while x <= #row do
			local ch = row:sub(x, x)
			local run = 1
			while row:sub(x + run, x + run) == ch do
				run += 1
			end
			local color = PALETTE[ch]
			if color then
				local px = Instance.new("Frame")
				px.BorderSizePixel = 0
				px.BackgroundColor3 = color
				px.Position = UDim2.fromScale(ox + (x - 1) * cell, oy + (y - 1) * cell)
				px.Size = UDim2.fromScale(run * cell + 0.004, cell + 0.004)
				px.ZIndex = holder.ZIndex
				px.Parent = holder
			end
			x += run
		end
	end
	holder.Parent = props.Parent
	return holder
end

-- ── plate ─────────────────────────────────────────────────────────────
local function frame(parent, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function round(f)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
end

-- circle of `size` (fraction of the bar's height) centered at (x, y) in the bar
local function dot(parent, x, y, size, color, transparency, z)
	local f = frame(parent, {
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.fromScale(size, size),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		ZIndex = z,
	})
	round(f)
	return f
end

local function glyph(parent, text, x, y, size, color, transparency, z)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = color
	l.TextTransparency = transparency or 0
	l.SizeConstraint = Enum.SizeConstraint.RelativeYY
	l.Size = UDim2.fromScale(size, size)
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(x, y)
	l.ZIndex = z
	l.Parent = parent
	return l
end

local PATTERNS = {}

function PATTERNS.Dots(body, cfg, z)
	for i = 0, 6 do
		dot(body, 0.62 + i * 0.058, 0.5, 0.12 + i * 0.045, cfg.Accent, 0.15, z)
	end
end

function PATTERNS.Bubbles(body, cfg, z)
	for _, b in ipairs({ { 0.48, 0.25, 0.25 }, { 0.6, 0.6, 0.35 }, { 0.58, 0.95, 0.7 }, { 0.7, 0.15, 0.9 }, { 0.8, 0.9, 1.1 }, { 0.92, 0.3, 1.0 }, { 1.0, 0.85, 0.9 } }) do
		dot(body, b[1], b[2], b[3], cfg.Accent, 0.1, z)
	end
end

function PATTERNS.Scallop(body, cfg, z)
	frame(body, { BackgroundColor3 = cfg.Accent, Position = UDim2.fromScale(0.64, 0), Size = UDim2.fromScale(0.36, 1), ZIndex = z })
	for _, y in ipairs({ 0, 0.33, 0.66, 1 }) do
		dot(body, 0.64, y, 0.42, cfg.Accent, 0, z)
	end
	dot(body, 0.56, 0.5, 0.22, cfg.Accent, 0.1, z)
	dot(body, 0.5, 0.3, 0.14, cfg.Accent, 0.2, z)
	dot(body, 0.46, 0.7, 0.1, cfg.Accent, 0.3, z)
end

function PATTERNS.Stripes(body, cfg, z)
	local overlay = frame(body, { BackgroundColor3 = cfg.Accent, Position = UDim2.fromScale(0.45, 0), Size = UDim2.fromScale(0.55, 1), ZIndex = z })
	local bands = 8
	local kps = {}
	for i = 0, bands - 1 do
		local t0, t1 = i / bands, (i + 1) / bands
		local a = (i % 2 == 0) and 0.35 or 1
		table.insert(kps, NumberSequenceKeypoint.new(t0 == 0 and 0 or t0 + 0.001, a))
		table.insert(kps, NumberSequenceKeypoint.new(t1, a))
	end
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new(kps)
	g.Rotation = 35
	g.Parent = overlay
end

function PATTERNS.Diamonds(body, cfg, z)
	for i = 0, 6 do
		frame(body, {
			BackgroundColor3 = cfg.Accent,
			BackgroundTransparency = 0.2 + (6 - i) * 0.08,
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Size = UDim2.fromScale(0.36, 0.36),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.4 + i * 0.09, 0.5),
			Rotation = 45,
			ZIndex = z,
		})
	end
end

function PATTERNS.Fire(body, cfg, z)
	local light = cfg.Accent:Lerp(RGB(255, 240, 120), 0.6)
	for i = 0, 9 do
		local x = 0.38 + i * 0.07
		dot(body, x, 1.1, 0.75 + ((i * 7) % 4) * 0.12, cfg.Accent, 0, z)
		dot(body, x + 0.03, 1.15, 0.45 + ((i * 5) % 3) * 0.1, light, 0, z)
	end
	dot(body, 0.33, 0.55, 0.12, cfg.Accent, 0.2, z)
	dot(body, 0.3, 0.3, 0.08, cfg.Accent, 0.4, z)
end

function PATTERNS.Bars(body, cfg, z)
	for _, b in ipairs({ { 0.58, 0.035 }, { 0.64, 0.03 }, { 0.7, 0.04 }, { 0.76, 0.02 }, { 0.8, 0.03 }, { 0.85, 0.015 }, { 0.88, 0.02 }, { 0.92, 0.015 }, { 0.95, 0.012 } }) do
		frame(body, { BackgroundColor3 = cfg.Accent, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(b[1], 0.5), Size = UDim2.fromScale(b[2], 0.6), ZIndex = z })
	end
end

function PATTERNS.Stars(body, cfg, z)
	local rng = Random.new(42)
	for _ = 1, 16 do
		dot(body, rng:NextNumber(0.25, 0.99), rng:NextNumber(0.12, 0.88), rng:NextNumber(0.05, 0.12), cfg.Accent, rng:NextNumber(0, 0.4), z)
	end
	glyph(body, "✦", 0.7, 0.5, 0.7, cfg.Accent, 0.1, z)
	glyph(body, "✦", 0.9, 0.35, 0.45, cfg.Accent, 0.2, z)
end

function PATTERNS.Hearts(body, cfg, z)
	for _, h in ipairs({ { 0.5, 0.35, 0.4 }, { 0.62, 0.65, 0.55 }, { 0.75, 0.35, 0.65 }, { 0.88, 0.62, 0.8 }, { 0.97, 0.3, 0.55 } }) do
		glyph(body, "♥", h[1], h[2], h[3], cfg.Accent, 0.1, z)
	end
end

function PATTERNS.Rainbow(_body, _cfg, _z)
	-- the bar itself is the rainbow (see Build)
end

-- Builds a plate. props: Parent, Size, Position, AnchorPoint, ZIndex, Text
function Nameplate.Build(key, props)
	local cfg = NameplateConfig.Plates[key] or NameplateConfig.Plates[NameplateConfig.Default]
	local z = props.ZIndex or 1
	local outline = frame(nil, {
		Name = "Nameplate",
		BackgroundColor3 = OUTLINE,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = z,
	})
	outline:SetAttribute("Plate", key)
	local oc = Instance.new("UICorner")
	oc.CornerRadius = UDim.new(0.3, 0)
	oc.Parent = outline

	local border = frame(outline, { Name = "Border", BackgroundColor3 = cfg.Border, Position = UDim2.fromScale(0.012, 0.08), Size = UDim2.fromScale(0.976, 0.84), ZIndex = z + 1 })
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0.3, 0)
	bc.Parent = border
	if cfg.Rainbow then
		border.BackgroundColor3 = Color3.new(1, 1, 1)
		local g = Instance.new("UIGradient")
		g.Name = "RainbowSpin"
		g.Color = RAINBOW
		g.Parent = border
	end

	local body = frame(border, { Name = "Body", BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromScale(0.012, 0.13), Size = UDim2.fromScale(0.976, 0.74), ClipsDescendants = true, ZIndex = z + 2 })
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0.25, 0)
	cc.Parent = body
	local bg = Instance.new("UIGradient")
	if cfg.Pattern == "Rainbow" then
		bg.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, RGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.28, RGB(255, 235, 235)),
			ColorSequenceKeypoint.new(0.42, RGB(255, 90, 90)),
			ColorSequenceKeypoint.new(0.55, RGB(255, 180, 50)),
			ColorSequenceKeypoint.new(0.67, RGB(255, 235, 70)),
			ColorSequenceKeypoint.new(0.78, RGB(80, 220, 100)),
			ColorSequenceKeypoint.new(0.89, RGB(70, 150, 255)),
			ColorSequenceKeypoint.new(1, RGB(180, 90, 255)),
		})
	else
		local c1, c2 = cfg.Colors[1], cfg.Colors[#cfg.Colors]
		bg.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, c1),
			ColorSequenceKeypoint.new(0.3, c1:Lerp(c2, 0.15)),
			ColorSequenceKeypoint.new(1, c2),
		})
	end
	bg.Parent = body
	local pattern = cfg.Pattern and PATTERNS[cfg.Pattern]
	if pattern then
		pattern(body, cfg, z + 3)
	end
	if cfg.Shine then
		local shine = frame(body, { Name = "Shine", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.35, Size = UDim2.fromScale(0.07, 1), Position = UDim2.fromScale(-0.2, 0), ZIndex = z + 4 })
		local sg = Instance.new("UIGradient")
		sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		sg.Parent = shine
	end

	local textLeft = 0.05
	if cfg.Icon then
		local icon = Nameplate.Icon(cfg.Icon, { Parent = outline, SizeConstraint = Enum.SizeConstraint.RelativeYY, Size = UDim2.fromScale(0.95, 0.95), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0.035, 0.5), ZIndex = z + 6 })
		if icon then
			textLeft = 0.24
		end
	end
	local label = Instance.new("TextLabel")
	label.Name = "PlayerName"
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = props.Text or ""
	label.TextScaled = true
	label.TextColor3 = cfg.TextColor or Color3.new(1, 1, 1)
	label.TextStrokeColor3 = OUTLINE
	label.TextStrokeTransparency = 0
	label.Position = UDim2.fromScale(textLeft, 0.22)
	label.Size = UDim2.fromScale(0.9 - textLeft, 0.56)
	label.ZIndex = z + 7
	label.Parent = outline

	if cfg.Rainbow or cfg.Shine then
		CollectionService:AddTag(outline, "NameplateFX")
	end
	outline.Parent = props.Parent
	return outline
end

-- moves the rainbow frame + the shine (call every frame on the client)
function Nameplate.Animate(plate, t)
	local border = plate:FindFirstChild("Border")
	local spin = border and border:FindFirstChild("RainbowSpin")
	if spin then
		spin.Rotation = (t * 120) % 360
	end
	local body = border and border:FindFirstChild("Body")
	local shine = body and body:FindFirstChild("Shine")
	if shine then
		local p = (t * 0.6 + (plate.AbsolutePosition.X % 7) * 0.1) % 2.4
		shine.Position = UDim2.fromScale(-0.1 + p, 0)
		shine.Visible = p < 1.2
	end
end

return Nameplate
