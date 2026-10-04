--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > ShopMenu (ModuleScript)

	The Shop, Steal-an-Egg style: one long scrolling page with colored "-- SECTION --" headers and a
	tab column on the right that jumps to each section.
	  FEATURED  limited Festive Box (countdown) + Royal Crate (odds)
	  PASSES    big x2 Open Speed / x2 Money cards + every other gamepass
	  SPEED     Double Your Speed, Upgrade Treadmill (Robux or coins), speed packs
	  MONEY     coin packs + boosts
	  GEMS      gem packs, gem shop, ray skins
	  CODES     redeem a code
	Animated: banners shimmer and slide, a shine sweeps across cards, buy buttons pulse, icons bob.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local NameplateConfig = require(Shared.Config.NameplateConfig)
local Nameplate = require(Shared.Nameplate)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local RewardUtil = require(Shared.RewardUtil)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)
local Prices = require(Modules.Prices)

local ShopMenu = {}

local RGB = Color3.fromRGB
local WHITE = Color3.new(1, 1, 1)
local ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, RGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, RGB(255, 180, 60)),
	ColorSequenceKeypoint.new(0.4, RGB(255, 245, 90)),
	ColorSequenceKeypoint.new(0.6, RGB(90, 235, 120)),
	ColorSequenceKeypoint.new(0.8, RGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, RGB(200, 90, 255)),
})

local function seq(colors)
	local kps = {}
	for i, c in ipairs(colors) do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), c))
	end
	return ColorSequence.new(kps)
end

function ShopMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Shop", Animated = true, Style = "Header", Size = UDim2.fromOffset(1060, 700), Colors = { RGB(140, 255, 80), RGB(40, 190, 40) } })
	local content = panel.Content

	-- ── animation registry (runs only while the shop is open) ─────────
	local anims = {}
	local function anim(fn)
		table.insert(anims, fn)
	end
	RunService.RenderStepped:Connect(function()
		if not panel.IsOpen() then
			return
		end
		local t = os.clock()
		for _, fn in ipairs(anims) do
			fn(t)
		end
	end)

	-- ── building blocks ──────────────────────────────────────────────
	local page = UIKit.Scroll({ Name = "Page", Size = UDim2.new(1, -150, 1, -12), Position = UDim2.fromOffset(0, 8), Parent = content })
	page.ScrollBarThickness = 10
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = page })
	UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 20), Parent = page })
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	local function text(parent, str, size, pos, color, stroke, props)
		local l = UIKit.Label({ Text = str, TextColor3 = color or WHITE, StrokeThickness = stroke or 3, Size = size, Position = pos or UDim2.new(), Parent = parent, ZIndex = 4 })
		for k, v in pairs(props or {}) do
			l[k] = v
		end
		return l
	end

	-- a white bar that sweeps across a frame every few seconds
	local function shine(frame, every)
		local bar = UIKit.Create("Frame", { Name = "Sweep", BackgroundColor3 = WHITE, BackgroundTransparency = 0.75, BorderSizePixel = 0, Size = UDim2.new(0, 46, 2, 0), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 20, ZIndex = 3, Parent = frame })
		UIKit.Create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }), Parent = bar })
		local offset = math.random() * 3
		anim(function(t)
			local p = ((t + offset) % (every or 3.5)) / 0.9
			bar.Position = UDim2.new(-0.2 + p * 1.4, 0, 0.5, 0)
			bar.Visible = p <= 1
		end)
	end

	-- big rounded card with a (moving) gradient
	local function banner(parent, size, colors, opts)
		opts = opts or {}
		local f = UIKit.Create("Frame", { BackgroundColor3 = WHITE, Size = size, Position = opts.Position or UDim2.new(), LayoutOrder = opts.LayoutOrder or 0, ZIndex = opts.ZIndex or 1, ClipsDescendants = true, Parent = parent })
		UIKit.Corner(f, opts.Radius or 12)
		-- thick border in a darker shade of the card's own color (like the reference shop cards)
		local last
		if typeof(colors) == "ColorSequence" then
			local kps = colors.Keypoints
			last = kps and kps[#kps] and kps[#kps].Value
		elseif type(colors) == "table" then
			last = colors[#colors]
		end
		last = last or RGB(60, 60, 70)
		local stroke = UIKit.Stroke(f, opts.Stroke or 5, last:Lerp(Color3.new(0, 0, 0), 0.5), true)
		local g = UIKit.Create("UIGradient", { Color = typeof(colors) == "ColorSequence" and colors or seq(colors), Rotation = opts.Rotation or 25, Parent = f })
		if opts.Move == "slide" then
			anim(function(t)
				g.Offset = Vector2.new(math.sin(t * 0.8) * 0.25, 0)
			end)
		elseif opts.Move == "spin" then
			anim(function(t)
				g.Rotation = (t * 25) % 360
			end)
		end
		if opts.RainbowBorder and stroke then
			local sg = UIKit.Create("UIGradient", { Color = RAINBOW, Parent = stroke })
			stroke.Color = WHITE
			anim(function(t)
				sg.Rotation = (t * 120) % 360
			end)
		end
		-- comic halftone dots + a soft light burst in the middle
		local dots = UIKit.Halftone(f, WHITE, true)
		dots.ZIndex = 2
		for _, d in ipairs(dots:GetChildren()) do
			d.ZIndex = 2
		end
		local burst = UIKit.Create("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 1.6), ZIndex = 2, Parent = f })
		UIKit.Corner(burst, UDim.new(1, 0))
		UIKit.Create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(1, 1) }), Parent = burst })
		if opts.Shine ~= false then
			shine(f, opts.ShineEvery)
		end
		return f
	end

	-- icon (emoji or image) that gently bobs
	local function bobIcon(parent, icon, size, pos, amp)
		local holder = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = size, Position = pos, ZIndex = 4, Parent = parent })
		local inner = UIKit.Icon({ Icon = icon, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = holder })
		local phase = math.random() * 6
		anim(function(t)
			inner.Position = UDim2.new(0, 0, 0, math.sin(t * 2 + phase) * (amp or 5))
			inner.Rotation = math.sin(t * 1.3 + phase) * 4
		end)
		return holder
	end

	local function priceNumber(str)
		return (tostring(str):gsub("^R%$%s*", ""))
	end

	-- green Robux button with the Robux icon + price; pulses gently
	local function robuxButton(parent, size, pos, anchor, onClick, colors)
		local button, label = UIKit.Button({ Text = "", Colors = colors or UIKit.Colors.Green, Size = size, Position = pos, AnchorPoint = anchor or Vector2.zero, CornerRadius = 12, Parent = parent, OnClick = onClick })
		button.ZIndex = 6
		label.Size = UDim2.new(0.62, 0, 0.78, -4)
		label.Position = UDim2.new(0.34, 0, 0, 3)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 8
		UIKit.Create("ImageLabel", { BackgroundTransparency = 1, Image = ROBUX_ICON, ScaleType = Enum.ScaleType.Fit, Size = UDim2.new(0.22, 0, 0.62, 0), Position = UDim2.new(0.1, 0, 0.12, 0), ZIndex = 8, Parent = button })
		local scale = UIKit.Create("UIScale", { Name = "Pulse", Parent = label })
		local phase = math.random() * 6
		anim(function(t)
			scale.Scale = 1 + math.sin(t * 3 + phase) * 0.035
		end)
		return button, label
	end

	-- striped gradient section bar ("Gamepasses", "Currency"...) that gently pulses
	local function sectionHeader(name, color)
		local holder = UIKit.Create("Frame", { Name = "Section_" .. name, BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 66), LayoutOrder = nextOrder(), Parent = page })
		local bar = UIKit.StripeBar({ Text = name .. "!", Colors = { color:Lerp(WHITE, 0.3), color:Lerp(Color3.new(0, 0, 0), 0.12) }, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = holder })
		local scale = UIKit.Create("UIScale", { Parent = bar })
		local stripes = bar:FindFirstChildWhichIsA("Frame")
		local g = stripes and stripes:FindFirstChildOfClass("UIGradient")
		anim(function(t)
			scale.Scale = 1 + math.sin(t * 1.6) * 0.012
			if g then
				g.Offset = Vector2.new((t * 0.08) % 0.222, 0)
			end
		end)
		return holder
	end

	local function gridHolder(cell, cols)
		local holder = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), Parent = page })
		UIKit.Create("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(14, 14), FillDirectionMaxCells = cols or 3, SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = holder })
		return holder
	end

	local refreshers = {}
	local function onRefresh(fn)
		table.insert(refreshers, fn)
	end
	local function productPrice(key)
		local p = MonetizationConfig.Products[key]
		return p and priceNumber(Prices.Get(Enum.InfoType.Product, p.Id, p.PriceLabel)) or "?"
	end
	local function passPrice(key)
		local p = MonetizationConfig.GamePasses[key]
		return p and priceNumber(Prices.Get(Enum.InfoType.GamePass, p.Id, p.PriceLabel)) or "?"
	end
	local function buyProduct(key)
		return function()
			ctx.HUD.Result(State.Action("PromptProduct", key))
		end
	end
	local function buyPass(key)
		return function()
			ctx.HUD.Result(State.Action("PromptPass", key))
		end
	end

	local sections = {}

	-- ════════════════════ FEATURED ════════════════════
	sections.Featured = sectionHeader("Featured", RGB(255, 225, 60))

	-- limited Festive Box
	local festive = banner(page, UDim2.new(1, -16, 0, 300), { RGB(120, 10, 20), RGB(230, 60, 30), RGB(255, 150, 40), RGB(200, 30, 40) }, { Move = "slide", LayoutOrder = nextOrder(), RainbowBorder = true })
	local newTag = UIKit.Card({ Size = UDim2.fromOffset(150, 52), Position = UDim2.fromOffset(18, 16), Colors = UIKit.Colors.Red, Parent = festive, CornerRadius = 10 })
	newTag.ZIndex = 5
	text(newTag, "New!", UDim2.new(1, -10, 1, -8), UDim2.fromOffset(5, 4), WHITE, 3)
	local title = text(festive, "FESTIVE BOX", UDim2.fromOffset(460, 62), UDim2.fromOffset(182, 12), RGB(255, 225, 60), 5, { TextXAlignment = Enum.TextXAlignment.Left })
	UIKit.Create("UIGradient", { Color = seq({ RGB(255, 250, 170), RGB(255, 200, 40) }), Rotation = 90, Parent = title })
	text(festive, "Limited Time!", UDim2.fromOffset(300, 32), UDim2.fromOffset(186, 72), WHITE, 3, { TextXAlignment = Enum.TextXAlignment.Left })
	local countdown = text(festive, "", UDim2.fromOffset(330, 44), UDim2.new(1, -350, 0, 18), WHITE, 4, { TextXAlignment = Enum.TextXAlignment.Right })
	bobIcon(festive, { Emoji = "🎁" }, UDim2.fromOffset(150, 150), UDim2.fromOffset(24, 96), 8)
	local festiveInfo = {
		{ "FESTIVE", "x4 income, only here", RGB(255, 90, 90) },
		{ "SECRET", "rarity box", RGB(255, 120, 230) },
		{ "HUGE+", "always big", RGB(120, 230, 255) },
	}
	for i, info in ipairs(festiveInfo) do
		local tile = banner(festive, UDim2.fromOffset(170, 112), { RGB(40, 15, 25), RGB(80, 25, 35) }, { Position = UDim2.fromOffset(190 + (i - 1) * 182, 112), Stroke = 3, Radius = 12, ShineEvery = 4 + i, ZIndex = 4 })
		text(tile, info[1], UDim2.new(1, -12, 0, 44), UDim2.fromOffset(6, 14), info[3], 3)
		text(tile, info[2], UDim2.new(1, -12, 0, 26), UDim2.fromOffset(6, 64), RGB(230, 225, 235), 2)
	end
	local _, festive3Label = robuxButton(festive, UDim2.fromOffset(200, 64), UDim2.new(1, -440, 1, -84), nil, buyProduct("LimitedBox3"), { RGB(255, 120, 255), RGB(150, 40, 220) })
	text(festive, "3 Boxes", UDim2.fromOffset(200, 22), UDim2.new(1, -440, 1, -20), WHITE, 2)
	local strike = text(festive, "", UDim2.fromOffset(120, 24), UDim2.new(1, -400, 1, -110), RGB(255, 80, 80), 2)
	UIKit.Create("Frame", { BackgroundColor3 = RGB(255, 60, 60), BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3), Position = UDim2.fromScale(0, 0.5), Rotation = -8, ZIndex = 6, Parent = strike })
	local _, festive1Label = robuxButton(festive, UDim2.fromOffset(200, 64), UDim2.new(1, -220, 1, -84), nil, buyProduct("LimitedBox"))
	text(festive, "1 Box", UDim2.fromOffset(200, 22), UDim2.new(1, -220, 1, -20), WHITE, 2)
	onRefresh(function()
		festive1Label.Text = productPrice("LimitedBox")
		festive3Label.Text = productPrice("LimitedBox3")
		local one = tonumber(productPrice("LimitedBox"))
		strike.Text = one and tostring(one * 3) or ""
	end)
	anim(function()
		local weekEnd = (math.floor(os.time() / 604800) + 1) * 604800
		local left = weekEnd - os.time()
		countdown.Text = string.format("%dd %02dh %02dm %02ds", left // 86400, (left % 86400) // 3600, (left % 3600) // 60, left % 60)
	end)

	-- Royal Crate
	local crate = MonetizationConfig.RoyalCrate
	local crateCard = banner(page, UDim2.new(1, -16, 0, 360), { RGB(60, 20, 120), RGB(150, 60, 230), RGB(255, 170, 60) }, { Move = "spin", LayoutOrder = nextOrder() })
	local crateTitle = text(crateCard, "ROYAL CRATE", UDim2.fromOffset(460, 58), UDim2.fromOffset(20, 12), RGB(255, 225, 60), 5, { TextXAlignment = Enum.TextXAlignment.Left })
	UIKit.Create("UIGradient", { Color = seq({ RGB(255, 250, 170), RGB(255, 190, 40) }), Rotation = 90, Parent = crateTitle })
	text(crateCard, "5 exclusive objects that never spawn on the map", UDim2.fromOffset(560, 28), UDim2.fromOffset(22, 68), WHITE, 2.5, { TextXAlignment = Enum.TextXAlignment.Left })
	local rarest
	for _, entry in ipairs(crate.Items) do
		if not rarest or entry.Chance < rarest.Chance then
			rarest = entry
		end
	end
	for i, entry in ipairs(crate.Items) do
		local def = ObjectConfig.Get(entry.Id)
		local rarity = RarityConfig.GetRarity(def.Rarity)
		local tile = banner(crateCard, UDim2.fromOffset(160, 176), { rarity.Color:Lerp(WHITE, 0.35), rarity.Color:Lerp(Color3.new(0, 0, 0), 0.25) }, { Position = UDim2.fromOffset(20 + (i - 1) * 172, 104), Stroke = 3, Radius = 12, RainbowBorder = entry == rarest, ShineEvery = 3 + i * 0.7, ZIndex = 4 })
		local preview = UIKit.ModelPreview({ Id = entry.Id, Size = UDim2.new(1, -12, 0, 116), Position = UDim2.fromOffset(6, 6), Parent = tile })
		preview.ZIndex = 4
		text(tile, def.Name, UDim2.new(1, -10, 0, 24), UDim2.fromOffset(5, 118), WHITE, 2.5)
		text(tile, entry.Chance .. "%", UDim2.new(1, -10, 0, 30), UDim2.fromOffset(5, 142), entry == rarest and RGB(255, 235, 90) or WHITE, 3)
	end
	local crateNote = text(crateCard, "", UDim2.fromOffset(420, 24), UDim2.new(0, 22, 1, -34), RGB(235, 225, 255), 2, { TextXAlignment = Enum.TextXAlignment.Left })
	local crate3, crate3Label = robuxButton(crateCard, UDim2.fromOffset(190, 60), UDim2.new(1, -420, 1, -76), nil, function()
		ctx.HUD.Result(State.Action("BuyRoyalCrate", 3))
	end, { RGB(255, 120, 255), RGB(150, 40, 220) })
	text(crateCard, "3 Crates", UDim2.fromOffset(190, 20), UDim2.new(1, -420, 1, -18), WHITE, 2)
	local crate1, crate1Label = robuxButton(crateCard, UDim2.fromOffset(190, 60), UDim2.new(1, -210, 1, -76), nil, function()
		ctx.HUD.Result(State.Action("BuyRoyalCrate", 1))
	end)
	text(crateCard, "1 Crate", UDim2.fromOffset(190, 20), UDim2.new(1, -210, 1, -18), WHITE, 2)
	onRefresh(function(data)
		local restricted = data.PaidRandomRestricted ~= false
		crateNote.Text = restricted and "Crates aren't available in your region." or "Each crate gives ONE object (random size)."
		crate1Label.Text = productPrice("RoyalCrate")
		crate3Label.Text = productPrice("RoyalCrate3")
		UIKit.SetButtonColors(crate1, restricted and UIKit.Colors.Gray or UIKit.Colors.Green)
		UIKit.SetButtonColors(crate3, restricted and UIKit.Colors.Gray or { RGB(255, 120, 255), RGB(150, 40, 220) })
	end)

	-- ════════════════════ PASSES ════════════════════
	sections.Passes = sectionHeader("Passes", RGB(255, 200, 40))
	local bigPasses = gridHolder(UDim2.fromOffset(420, 220), 2)
	local passButtons = {}
	local function bigPassCard(key, titleText, line1, line2, colors, move)
		local pass = MonetizationConfig.GamePasses[key]
		local card = banner(bigPasses, UDim2.fromScale(1, 1), colors, { Move = move })
		bobIcon(card, { Emoji = pass.Emoji, Image = pass.Image }, UDim2.fromOffset(120, 120), UDim2.fromOffset(18, 30), 6)
		text(card, titleText, UDim2.new(1, -160, 0, 50), UDim2.fromOffset(150, 12), WHITE, 4)
		text(card, line1 .. " <font color=\"#5CFF5C\">x2</font> " .. line2, UDim2.new(1, -170, 0, 72), UDim2.fromOffset(152, 64), WHITE, 3, { RichText = true })
		local button, label = robuxButton(card, UDim2.new(1, -170, 0, 60), UDim2.new(0, 152, 1, -74), nil, buyPass(key))
		passButtons[key] = { Button = button, Label = label }
	end
	bigPassCard("FastBoxes", "x2 Open Speed", "Boxes open", "faster!", RAINBOW, "spin")
	bigPassCard("DoubleCoins", "x2 Money", "Get", "coins!", { RGB(255, 245, 140), RGB(255, 200, 40), RGB(240, 150, 20) }, "slide")

	local passGrid = gridHolder(UDim2.fromOffset(276, 230), 3)
	local PALETTE = {
		{ RGB(120, 200, 255), RGB(40, 110, 230) }, { RGB(210, 150, 255), RGB(120, 50, 220) }, { RGB(255, 160, 220), RGB(230, 60, 150) },
		{ RGB(255, 190, 100), RGB(240, 110, 30) }, { RGB(140, 245, 110), RGB(40, 170, 50) }, { RGB(130, 255, 240), RGB(30, 180, 200) },
		{ RGB(255, 130, 130), RGB(210, 40, 50) },
	}
	local n = 0
	for _, key in ipairs(MonetizationConfig.PassOrder) do
		if key ~= "FastBoxes" and key ~= "DoubleCoins" and key ~= "DoubleSpeed" then
			n += 1
			local pass = MonetizationConfig.GamePasses[key]
			local card = banner(passGrid, UDim2.fromScale(1, 1), PALETTE[(n - 1) % #PALETTE + 1], { LayoutOrder = n, Move = n % 3 == 0 and "slide" or nil, RainbowBorder = key == "CarryInfinite" })
			bobIcon(card, { Emoji = pass.Emoji, Image = pass.Image }, UDim2.fromOffset(72, 72), UDim2.new(0.5, -36, 0, 10), 4)
			text(card, pass.Name, UDim2.new(1, -16, 0, 32), UDim2.fromOffset(8, 86), WHITE, 3)
			text(card, pass.Description or "", UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 118), RGB(250, 250, 255), 2)
			local button, label = robuxButton(card, UDim2.new(1, -30, 0, 52), UDim2.new(0, 15, 1, -62), nil, buyPass(key))
			passButtons[key] = { Button = button, Label = label }
		end
	end
	onRefresh(function()
		for key, c in pairs(passButtons) do
			if State.HasPass(key) then
				c.Label.Text = "OWNED"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Gray)
			else
				c.Label.Text = passPrice(key)
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Green)
			end
		end
	end)

	-- ════════════════════ SPEED ════════════════════
	sections.Speed = sectionHeader("Speed", RGB(60, 210, 255))
	local double = banner(page, UDim2.new(1, -16, 0, 190), { RGB(60, 190, 255), RGB(110, 240, 200), RGB(60, 190, 255) }, { Move = "slide", LayoutOrder = nextOrder() })
	text(double, "<font color=\"#3CFF3C\">DOUBLE</font> Your SPEED", UDim2.new(1, -40, 0, 54), UDim2.fromOffset(20, 10), WHITE, 4, { RichText = true })
	bobIcon(double, { Emoji = "👟" }, UDim2.fromOffset(120, 120), UDim2.fromOffset(30, 60), 6)
	text(double, "x1", UDim2.fromOffset(120, 90), UDim2.new(0.5, -200, 0, 74), WHITE, 5)
	text(double, "▶", UDim2.fromOffset(60, 60), UDim2.new(0.5, -60, 0, 90), WHITE, 3)
	local x2 = text(double, "x2", UDim2.fromOffset(150, 100), UDim2.new(0.5, 10, 0, 68), RGB(255, 220, 50), 5)
	UIKit.Create("UIGradient", { Color = seq({ RGB(255, 250, 160), RGB(255, 190, 30) }), Rotation = 90, Parent = x2 })
	local x2Scale = UIKit.Create("UIScale", { Parent = x2 })
	anim(function(t)
		x2Scale.Scale = 1 + math.sin(t * 3) * 0.06
	end)
	local doubleButton, doubleLabel = robuxButton(double, UDim2.fromOffset(220, 70), UDim2.new(1, -244, 1, -92), nil, buyPass("DoubleSpeed"))
	onRefresh(function()
		if State.HasPass("DoubleSpeed") then
			doubleLabel.Text = "OWNED"
			UIKit.SetButtonColors(doubleButton, UIKit.Colors.Gray)
		else
			doubleLabel.Text = passPrice("DoubleSpeed")
			UIKit.SetButtonColors(doubleButton, UIKit.Colors.Green)
		end
	end)

	local tread = banner(page, UDim2.new(1, -16, 0, 200), { RGB(120, 220, 255), RGB(190, 245, 255), RGB(120, 210, 255) }, { Move = "slide", LayoutOrder = nextOrder() })
	local up = text(tread, "UPGRADE", UDim2.fromOffset(300, 56), UDim2.new(0.5, -330, 0, 10), WHITE, 4)
	local upGrad = UIKit.Create("UIGradient", { Color = RAINBOW, Parent = up })
	anim(function(t)
		upGrad.Offset = Vector2.new(math.sin(t * 1.2) * 0.5, 0)
	end)
	text(tread, "TREADMILL!", UDim2.fromOffset(340, 56), UDim2.new(0.5, -20, 0, 10), WHITE, 4)
	bobIcon(tread, { Emoji = "🏃" }, UDim2.fromOffset(100, 100), UDim2.fromOffset(40, 76), 5)
	local levels = text(tread, "", UDim2.fromOffset(300, 46), UDim2.new(0.5, -150, 0, 70), RGB(30, 60, 120), 0)
	local _, treadRobuxLabel = robuxButton(tread, UDim2.fromOffset(200, 62), UDim2.new(0.5, -210, 1, -76), nil, buyProduct("TreadmillLevel"))
	local treadCoins, treadCoinsLabel = UIKit.Button({ Text = "", Colors = UIKit.Colors.Red, Size = UDim2.fromOffset(200, 62), Position = UDim2.new(0.5, 10, 1, -76), CornerRadius = 12, Parent = tread, OnClick = function()
		ctx.HUD.Result(State.Action("BuyUpgrade", "Treadmill"))
	end })
	treadCoins.ZIndex = 6
	treadCoinsLabel.ZIndex = 8
	onRefresh(function(data)
		local lv = data.Upgrades.Treadmill or 1
		local max = UpgradeConfig.Upgrades.Treadmill.MaxLevel
		levels.Text = lv >= max and ("Lv " .. lv .. "  (MAX)") or ("Lv " .. lv .. "  ▶  Lv " .. (lv + 1))
		treadRobuxLabel.Text = productPrice("TreadmillLevel")
		local cost = Formulas.UpgradeCost("Treadmill", lv)
		treadCoinsLabel.Text = cost and Format.Coins(cost) or "MAX"
	end)

	local speedGrid = gridHolder(UDim2.fromOffset(276, 230), 3)
	local packs = { "SpeedPoints", "SpeedPack2", "SpeedPack3", "SpeedPack4", "SpeedPack5", "SpeedPack6" }
	local packLabels = {}
	for i, key in ipairs(packs) do
		local product = MonetizationConfig.Products[key]
		local card = banner(speedGrid, UDim2.fromScale(1, 1), { RGB(90, 200, 255), RGB(30, 120, 230) }, { LayoutOrder = i, RainbowBorder = i == #packs, Move = i >= 5 and "slide" or nil })
		bobIcon(card, { Emoji = i >= 5 and "🧰" or "👟" }, UDim2.fromOffset(80 + i * 6, 80 + i * 6), UDim2.new(0.5, -(40 + i * 3), 0, 8), 5)
		local amount = text(card, "", UDim2.new(1, -16, 0, 40), UDim2.fromOffset(8, 104), WHITE, 3.5)
		text(card, product.Name, UDim2.new(1, -16, 0, 22), UDim2.fromOffset(8, 144), RGB(220, 240, 255), 2)
		local _, label = robuxButton(card, UDim2.new(1, -30, 0, 52), UDim2.new(0, 15, 1, -62), nil, buyProduct(key))
		packLabels[key] = { Amount = amount, Price = label, Minutes = product.Minutes or 30 }
	end
	onRefresh(function(data)
		local passes = { DoubleSpeed = State.HasPass("DoubleSpeed") or nil }
		local rate = Formulas.TrainingRate(data, passes)
		for key, c in pairs(packLabels) do
			c.Amount.Text = "+" .. Format.Abbrev(math.floor(rate * 60 * c.Minutes)) .. " SPEED"
			c.Price.Text = productPrice(key)
		end
	end)

	-- ════════════════════ MONEY ════════════════════
	sections.Money = sectionHeader("Money", RGB(110, 255, 90))
	local moneyGrid = gridHolder(UDim2.fromOffset(276, 230), 3)
	local MONEY = {}
	for _, key in ipairs(MonetizationConfig.ProductOrder) do
		if not key:find("^Gems") then
			table.insert(MONEY, key)
		end
	end
	local moneyLabels = {}
	for i, key in ipairs(MONEY) do
		local product = MonetizationConfig.Products[key]
		local coin = key:find("^Coins") ~= nil
		local colors = coin and { RGB(150, 255, 110), RGB(40, 170, 60) } or PALETTE[(i + 2) % #PALETTE + 1]
		local card = banner(moneyGrid, UDim2.fromScale(1, 1), colors, { LayoutOrder = i, RainbowBorder = key == "CoinsLarge", Move = key == "ServerLuck" and "spin" or nil })
		bobIcon(card, { Emoji = product.Emoji, Image = product.Image }, UDim2.fromOffset(78, 78), UDim2.new(0.5, -39, 0, 8), 5)
		text(card, product.Name, UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 90), WHITE, 3)
		local detail = text(card, "", UDim2.new(1, -16, 0, 34), UDim2.fromOffset(8, 122), RGB(255, 255, 200), 2.5)
		local _, label = robuxButton(card, UDim2.new(1, -30, 0, 52), UDim2.new(0, 15, 1, -62), nil, buyProduct(key))
		moneyLabels[key] = { Detail = detail, Price = label, Product = product }
	end
	onRefresh(function()
		for key, c in pairs(moneyLabels) do
			c.Price.Text = productPrice(key)
			if c.Product.Grant then
				c.Detail.Text = RewardUtil.Describe(c.Product.Grant, State.Income)
			elseif c.Product.Handler == "InstantRebirth" then
				c.Detail.Text = "Rebirth now, no coins needed"
			elseif c.Product.Handler == "SpawnGolden" then
				c.Detail.Text = "Spawns next to you!"
			elseif c.Product.Handler == "OpenAllBoxes" then
				c.Detail.Text = "Every box in your base, now"
			end
		end
	end)

	-- ════════════════════ GEMS & SKINS ════════════════════
	sections.Gems = sectionHeader("Gems & Skins", RGB(120, 200, 255))
	local gemGrid = gridHolder(UDim2.fromOffset(276, 210), 3)
	local gemLabels = {}
	local gi = 0
	for _, key in ipairs(MonetizationConfig.ProductOrder) do
		if key:find("^Gems") then
			gi += 1
			local product = MonetizationConfig.Products[key]
			local card = banner(gemGrid, UDim2.fromScale(1, 1), { RGB(140, 230, 255), RGB(50, 120, 240) }, { LayoutOrder = gi, RainbowBorder = key == "GemsLarge" })
			bobIcon(card, { Emoji = "💎" }, UDim2.fromOffset(64 + gi * 8, 64 + gi * 8), UDim2.new(0.5, -(32 + gi * 4), 0, 8), 5)
			text(card, product.Name, UDim2.new(1, -16, 0, 30), UDim2.fromOffset(8, 100), WHITE, 3)
			local detail = text(card, "", UDim2.new(1, -16, 0, 26), UDim2.fromOffset(8, 130), RGB(220, 245, 255), 2.5)
			local _, label = robuxButton(card, UDim2.new(1, -30, 0, 48), UDim2.new(0, 15, 1, -58), nil, buyProduct(key))
			gemLabels[key] = { Detail = detail, Price = label, Product = product }
		end
	end
	onRefresh(function()
		for key, c in pairs(gemLabels) do
			c.Price.Text = productPrice(key)
			c.Detail.Text = c.Product.Grant and RewardUtil.Describe(c.Product.Grant, State.Income) or ""
		end
	end)

	local gemShop = banner(page, UDim2.new(1, -16, 0, 70 + #MonetizationConfig.GemShop * 62), { RGB(40, 60, 110), RGB(60, 90, 160) }, { LayoutOrder = nextOrder(), Shine = false })
	text(gemShop, "Gem Shop", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 12), RGB(120, 210, 255), 3.5)
	for i, item in ipairs(MonetizationConfig.GemShop) do
		local row = UIKit.Card({ Size = UDim2.new(1, -32, 0, 54), Position = UDim2.fromOffset(16, 56 + (i - 1) * 62), Colors = { RGB(70, 95, 160), RGB(50, 70, 125) }, Parent = gemShop, CornerRadius = 12 })
		row.ZIndex = 4
		text(row, item.Name, UDim2.new(0.6, 0, 1, -14), UDim2.fromOffset(14, 7), WHITE, 2.5, { TextXAlignment = Enum.TextXAlignment.Left })
		local b = UIKit.Button({ Text = item.Cost .. " Gems", Colors = UIKit.Colors.Blue, Size = UDim2.fromOffset(170, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Parent = row, OnClick = function()
			ctx.HUD.Result(State.Action("GemShopBuy", item.Key))
		end })
		b.ZIndex = 6
	end

	local skinGrid = gridHolder(UDim2.fromOffset(200, 150), 4)
	local skinButtons = {}
	for i, skinKey in ipairs(MonetizationConfig.SkinOrder) do
		local skin = MonetizationConfig.RaySkins[skinKey]
		local card = banner(skinGrid, UDim2.fromScale(1, 1), skin.Rainbow and RAINBOW or { skin.Colors[1], skin.Colors[2] }, { LayoutOrder = i, Move = skin.Rainbow and "spin" or nil })
		text(card, skin.Name .. " Ray", UDim2.new(1, -12, 0, 34), UDim2.fromOffset(6, 14), WHITE, 3)
		local button, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, Size = UDim2.new(1, -24, 0, 50), Position = UDim2.new(0, 12, 1, -62), CornerRadius = 12, Parent = card, OnClick = function()
			ctx.HUD.Result(State.Action("EquipSkin", skinKey))
		end })
		button.ZIndex = 6
		label.ZIndex = 8
		skinButtons[skinKey] = { Button = button, Label = label, Skin = skin }
	end
	onRefresh(function(data)
		for key, c in pairs(skinButtons) do
			local owned = data.RaySkins[key] or (c.Skin.Pass and State.HasPass(c.Skin.Pass))
			if data.EquippedSkin == key then
				c.Label.Text = "EQUIPPED"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Gray)
			elseif owned then
				c.Label.Text = "EQUIP"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Green)
			else
				c.Label.Text = c.Skin.Pass and "Pass" or "Locked"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Dark)
			end
		end
	end)

	-- ════════════════════ NAME PLATES ════════════════════
	sections.Plates = sectionHeader("Name Plates", RGB(255, 150, 210))
	local plateBanner = banner(page, UDim2.new(1, -16, 0, 300), { RGB(70, 30, 90), RGB(150, 50, 140), RGB(70, 30, 90) }, { Move = "slide", LayoutOrder = nextOrder(), RainbowBorder = true })
	text(plateBanner, "Show off over your head!", UDim2.new(1, -40, 0, 40), UDim2.fromOffset(20, 12), WHITE, 3.5)
	local localPlayer = game:GetService("Players").LocalPlayer
	local myName = localPlayer and localPlayer.DisplayName or "You"
	for i, key in ipairs({ "Rainbow", "Champion", "Void" }) do
		local cfg = NameplateConfig.Plates[key]
		local y = 62 + (i - 1) * 74
		local plate = Nameplate.Build(key, { Parent = plateBanner, Text = myName, Size = UDim2.fromOffset(380, 64), Position = UDim2.fromOffset(28, y), ZIndex = 5 })
		plate.Name = "Plate_" .. key
		local product = MonetizationConfig.Products[cfg.Product]
		if product then
			local _, label = robuxButton(plateBanner, UDim2.fromOffset(150, 56), UDim2.fromOffset(424, y + 4), nil, function()
				ctx.HUD.Result(State.Action("BuyPlate", key))
			end, { RGB(255, 120, 255), RGB(150, 40, 220) })
			onRefresh(function(data)
				label.Text = (data.Nameplates and data.Nameplates[key]) and "Owned" or productPrice(cfg.Product)
			end)
		end
	end
	local browse = UIKit.Button({ Text = "ALL PLATES", Colors = { RGB(255, 170, 220), RGB(225, 70, 160) }, Size = UDim2.fromOffset(200, 120), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.55, 0), CornerRadius = 14, Parent = plateBanner, OnClick = function()
		ctx.HUD.OpenMenu("Nameplates")
	end })
	browse.ZIndex = 6

	-- ════════════════════ CODES ════════════════════
	sections.Codes = sectionHeader("Codes", RGB(255, 140, 210))
	local codes = banner(page, UDim2.new(1, -16, 0, 210), { RGB(255, 150, 215), RGB(200, 60, 160) }, { LayoutOrder = nextOrder() })
	local box = UIKit.Create("TextBox", {
		PlaceholderText = "CODE HERE",
		Text = "",
		Font = UIKit.Font,
		TextScaled = true,
		ClearTextOnFocus = false,
		TextColor3 = UIKit.Outline,
		BackgroundColor3 = RGB(250, 245, 255),
		Size = UDim2.fromOffset(460, 64),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 30),
		ZIndex = 6,
		Parent = codes,
	})
	UIKit.Corner(box, 14)
	UIKit.Stroke(box, 4, UIKit.Outline, true)
	UIKit.Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = box })
	local redeem = UIKit.Button({ Text = "REDEEM", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(240, 60), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 116), Parent = codes, OnClick = function()
		local result = State.Action("RedeemCode", box.Text)
		ctx.HUD.Result(result)
		if result.ok then
			box.Text = ""
		end
	end })
	redeem.ZIndex = 6

	-- ── tab column on the right: jump to a section ───────────────────
	local tabs = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 136, 1, -16), Position = UDim2.new(1, -136, 0, 8), Parent = content })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = tabs })
	local TABS = {
		{ "Featured", "🏷️", UIKit.Colors.Red },
		{ "Passes", "🎟️", UIKit.Colors.Yellow },
		{ "Speed", "👟", UIKit.Colors.Blue },
		{ "Money", "💵", UIKit.Colors.Green },
		{ "Gems", "💎", UIKit.Colors.Cyan },
		{ "Codes", "🎁", UIKit.Colors.Pink },
	}
	for i, t in ipairs(TABS) do
		local b = UIKit.Button({ Text = "", Colors = t[3], Size = UDim2.fromOffset(126, 88), LayoutOrder = i, CornerRadius = 16, Parent = tabs, OnClick = function()
			local target = sections[t[1]]
			if target then
				local y = target.AbsolutePosition.Y - page.AbsolutePosition.Y + page.CanvasPosition.Y
				TweenService:Create(page, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CanvasPosition = Vector2.new(0, math.max(0, y - 4)) }):Play()
			end
		end })
		bobIcon(b, { Emoji = t[2] }, UDim2.fromOffset(46, 46), UDim2.new(0.5, -23, 0, 6), 3)
		text(b, t[1], UDim2.new(1, -8, 0, 26), UDim2.new(0, 4, 1, -34), WHITE, 2.5)
	end

	local menu = { Panel = panel }
	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		for _, fn in ipairs(refreshers) do
			local ok, err = pcall(fn, data)
			if not ok then
				warn("[ShopMenu] " .. tostring(err))
			end
		end
	end
	Prices.OnUpdated(function()
		if panel.IsOpen() then
			menu.Refresh()
		end
	end)
	return menu
end

return ShopMenu
