--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > HUD (ModuleScript)

	Builds the whole on-screen UI in code (nothing to place in StarterGui):
	left icon stack + badges, currency display, toasts, announcements, event banner,
	boost timers, raid banner, charge bar, hover info, "TOO BIG!" popup, modal popups,
	and the menu manager (only one menu open at a time).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local EventConfig = require(Shared.Config.EventConfig)
local TierConfig = require(Shared.Config.TierConfig)

local Modules = script.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local HUD = {}

local player = Players.LocalPlayer
local screen
local menus = {} -- [name] = menu
local menuOrder = {}
local badgeSetters = {}
local carryFrame, carryLabel, splashLabel, dropButton
local placeButton
local speedLabel
local splashToken = 0

-- ── helpers ───────────────────────────────────────────────────────────
local KIND_COLORS = {
	success = UIKit.Colors.Green,
	error = UIKit.Colors.Red,
	info = UIKit.Colors.Blue,
	new = UIKit.Colors.Purple,
	shrink = UIKit.Colors.Yellow,
}

local toastHolder
local recentToasts = {} -- [text] = { Toast, Label, Count, Until }

function HUD.Notify(text, kind)
	if not toastHolder or type(text) ~= "string" then
		return
	end
	-- the same message again while it's still on screen: no new popup, just "x2", "x3"...
	local recent = recentToasts[text]
	if recent and recent.Toast.Parent and os.clock() < recent.Until then
		recent.Count += 1
		recent.Until = os.clock() + 3.2
		recent.Label.Text = text .. "  x" .. recent.Count
		if recent.Count <= 2 then
			UIKit.Pop(recent.Toast, 0.9)
		end
		return
	end
	local colors = KIND_COLORS[kind] or KIND_COLORS.info
	local toast, label = UIKit.StripeBar({ Text = text, Colors = colors, Size = UDim2.fromOffset(math.clamp(#text * 13 + 70, 280, 720), 48), Parent = toastHolder, ZIndex = 85 })
	toast.LayoutOrder = -math.floor(os.clock() * 100)
	label.Size = UDim2.new(1, -24, 1, -14)
	label.Position = UDim2.fromOffset(12, 7)
	local entry = { Toast = toast, Label = label, Count = 1, Until = os.clock() + 3.2 }
	recentToasts[text] = entry
	UIKit.Pop(toast, 0.6)
	local children = {}
	for _, c in ipairs(toastHolder:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(children, c)
		end
	end
	if #children > 5 then
		table.sort(children, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		children[#children]:Destroy()
	end
	task.spawn(function()
		repeat
			task.wait(math.max(0.1, entry.Until - os.clock()))
		until os.clock() >= entry.Until or not toast.Parent
		if recentToasts[text] == entry then
			recentToasts[text] = nil
		end
		if toast.Parent then
			UIKit.Tween(toast, 0.25, { BackgroundTransparency = 1 })
			task.wait(0.25)
			toast:Destroy()
		end
	end)
	if kind == "error" then
		UIKit.PlaySound("TooBig", 0.25)
	elseif kind == "success" then
		UIKit.PlaySound("Reward", 0.3)
	end
end

-- Show the result of a State.Action call as a toast.
function HUD.Result(result)
	if result and result.msg then
		HUD.Notify(result.msg, result.ok and "success" or "error")
	end
end

-- ── announcements ─────────────────────────────────────────────────────
local announceQueue = {}
local announcing = false
local announceFrame, announceLabel
local function nextAnnouncement()
	if announcing or #announceQueue == 0 then
		return
	end
	announcing = true
	local a = table.remove(announceQueue, 1)
	local c = a.Color or Color3.fromRGB(255, 210, 60)
	local bar = announceFrame:FindFirstChild("Bar")
	if bar then
		UIKit.SetButtonColors(bar, { c:Lerp(Color3.new(1, 1, 1), 0.35), c })
		local stroke = bar:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = c:Lerp(Color3.new(0, 0, 0), 0.5)
		end
	end
	announceLabel.Text = a.Text
	announceFrame.Visible = true
	announceFrame.Position = UDim2.new(0.5, 0, 0, -140)
	UIKit.Tween(announceFrame, 0.45, { Position = UDim2.new(0.5, 0, 0, 150) }, Enum.EasingStyle.Back)
	UIKit.PlaySound("Reward", 0.35)
	task.delay(4.5, function()
		local t = UIKit.Tween(announceFrame, 0.3, { Position = UDim2.new(0.5, 0, 0, -140) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		t.Completed:Wait()
		announceFrame.Visible = false
		announcing = false
		nextAnnouncement()
	end)
end
function HUD.Announce(text, color)
	table.insert(announceQueue, { Text = text, Color = color })
	nextAnnouncement()
end

-- ── menus ─────────────────────────────────────────────────────────────
-- Opens a menu (never toggles it closed). Used by the stands.
function HUD.ShowMenu(name)
	local m = menus[name]
	if m and not m.Panel.IsOpen() then
		HUD.OpenMenu(name)
	end
end

function HUD.OpenMenu(name)
	for n, m in pairs(menus) do
		if n ~= name and m.Panel.IsOpen() then
			m.Panel.Close()
		end
	end
	local m = menus[name]
	if m then
		m.Panel.Toggle()
		if m.Panel.IsOpen() and m.Refresh then
			m.Refresh()
		end
	end
end

function HUD.GetScreen()
	return screen
end

-- ── modal popups (daily, offline, rebirth) ─────────────────────────────
local function popup(title, emoji, lines, colors)
	local panel = UIKit.Panel({ Parent = screen, Title = title, Emoji = emoji, Size = UDim2.fromOffset(560, 340), Colors = colors })
	panel.Holder.ZIndex = 150
	for i, line in ipairs(lines) do
		UIKit.Label({ Text = line, TextColor3 = i == 1 and Color3.fromRGB(255, 200, 40) or Color3.new(1, 1, 1), StrokeThickness = 3, Size = UDim2.new(1, 0, 0, i == 1 and 64 or 44), Position = UDim2.fromOffset(0, 20 + (i - 1) * 62 + (i > 1 and 16 or 0)), Parent = panel.Content })
	end
	UIKit.Button({ Text = "Awesome!", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(220, 64), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Parent = panel.Content, OnClick = function()
		panel.Close()
	end })
	panel.OnClose:Connect(function()
		task.delay(0.3, function()
			panel.Holder:Destroy()
		end)
	end)
	panel.Open()
	UIKit.PlaySound("Reward", 0.5)
end

local function onPopup(kind, p)
	if kind == "Daily" then
		popup("Daily Reward!", "📅", { "Day " .. p.Streak .. " streak", "You got: " .. p.Text, "Come back tomorrow for more!" }, UIKit.Colors.Orange)
	elseif kind == "Offline" then
		popup("Welcome Back!", "😴", { "+" .. Format.Coins(p.Amount), "Earned while offline for " .. Format.Time(p.Seconds) }, UIKit.Colors.Blue)
	elseif kind == "Rebirth" then
		popup("REBIRTH " .. p.Rebirths .. "!", "♻️", { "x" .. string.format("%.1f", p.Multiplier) .. " income forever!", "+" .. p.Gems .. " Gems  •  +" .. p.Tokens .. " Rebirth Tokens" }, UIKit.Colors.Green)
	elseif kind == "Crate" then
		popup("Royal Crate!", "👑", { "You got a " .. p.Name .. "!", "It's in your pocket — press Equip Best!" }, UIKit.Colors.Yellow)
	end
end

-- ── ray HUD (used by RayController) ────────────────────────────────────
local chargeBar, chargeHolder, hoverLabel, tooBig, tooBigSub, crosshair
local tooBigToken = 0

local function cursorPos(pos)
	if pos then
		return pos
	end
	return UserInputService:GetMouseLocation()
end

function HUD.SetCharge(alpha, screenPos)
	if not alpha then
		chargeHolder.Visible = false
		return
	end
	local p = cursorPos(screenPos)
	chargeHolder.Visible = true
	chargeHolder.Position = UDim2.fromOffset(p.X, p.Y + 44)
	chargeBar.Set(alpha, alpha >= 1 and "ZAP!" or math.floor(alpha * 100) .. "%")
end

function HUD.SetHover(text, color, screenPos)
	if not text then
		hoverLabel.Visible = false
		return
	end
	local p = cursorPos(screenPos)
	hoverLabel.Visible = true
	hoverLabel.Text = text
	hoverLabel.TextColor3 = color or Color3.new(1, 1, 1)
	hoverLabel.Position = UDim2.fromOffset(p.X, p.Y - 46)
end

function HUD.SetCrosshair(visible)
	crosshair.Visible = visible
	if visible then
		local p = UserInputService:GetMouseLocation()
		crosshair.Position = UDim2.fromOffset(p.X, p.Y)
	end
end

function HUD.UpdateCrosshair()
	if crosshair.Visible then
		local p = UserInputService:GetMouseLocation()
		crosshair.Position = UDim2.fromOffset(p.X, p.Y)
	end
end

function HUD.ShowTooBig(needRayPower, screenPos)
	local p = cursorPos(screenPos)
	tooBig.Position = UDim2.fromOffset(p.X, p.Y - 90)
	tooBigSub.Text = needRayPower and ("Need Ray Power " .. needRayPower) or ""
	tooBig.Visible = true
	tooBig.GroupTransparency = 0
	UIKit.Pop(tooBig, 1.6)
	UIKit.PlaySound("TooBig", 0.4)
	tooBigToken += 1
	local token = tooBigToken
	task.delay(1.2, function()
		if token ~= tooBigToken then
			return
		end
		UIKit.Tween(tooBig, 0.3, { GroupTransparency = 1 })
		task.wait(0.3)
		if token == tooBigToken then
			tooBig.Visible = false
		end
	end)
end

-- Big centered text that pops and fades (CAUGHT!, DELIVERED!, ...)
function HUD.Splash(text, color)
	splashToken += 1
	local token = splashToken
	splashLabel.Text = text
	splashLabel.TextColor3 = color or Color3.new(1, 1, 1)
	splashLabel.TextTransparency = 0
	splashLabel.Visible = true
	UIKit.Pop(splashLabel, 1.15)
	task.delay(1.6, function()
		if token ~= splashToken then
			return
		end
		UIKit.Tween(splashLabel, 0.35, { TextTransparency = 1 })
		task.wait(0.35)
		if token == splashToken then
			splashLabel.Visible = false
		end
	end)
end

-- ── build ─────────────────────────────────────────────────────────────
local LEFT_BUTTONS = {
	{ Menu = "Gifts", Label = "Gifts", Emoji = "🎁", Colors = UIKit.Colors.Pink },
	{ Menu = "InfinitePack", Label = "Pack", Emoji = "♾️", Colors = UIKit.Colors.Purple },
	{ Menu = "Shop", Label = "Shop", Emoji = "🛒", Colors = UIKit.Colors.Yellow },
	{ Menu = "Index", Label = "Index", Emoji = "📖", Colors = UIKit.Colors.Blue },
	{ Menu = "Rebirth", Label = "Rebirth", Emoji = "♻️", Colors = UIKit.Colors.Green },
	{ Menu = "Museum", Label = "Museum", Emoji = "🏛️", Colors = UIKit.Colors.Orange },
	{ Menu = "Upgrades", Label = "Upgrades", Emoji = "⚡", Colors = UIKit.Colors.Cyan },
	{ Menu = "Nameplates", Label = "Custom", Emoji = "🎨", Colors = UIKit.Colors.Red },
}

local currencyLabels = {}
local incomeLabel
local eventLabel, eventFrame
local boostHolder
local raidFrame, raidLabel

-- Wide "pill" buttons: a big icon that pops out of the left edge + a bold label.
-- Big icon buttons with a label under each (no button background), down the left side.
local function buildLeftStack()
	local CELL_W, ICON, LABEL_H, GAP, COLS = 96, 78, 26, 6, 2
	local rows = math.ceil(#LEFT_BUTTONS / COLS)
	local stack = UIKit.Create("Frame", {
		Name = "LeftStack",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.45, 0),
		Size = UDim2.fromOffset(COLS * CELL_W + (COLS - 1) * GAP, rows * (ICON + LABEL_H) + (rows - 1) * GAP),
		Parent = screen,
	})
	UIKit.AutoScale(stack)
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(CELL_W, ICON + LABEL_H), CellPadding = UDim2.fromOffset(GAP, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stack })
	for i, def in ipairs(LEFT_BUTTONS) do
		local button = UIKit.Create("TextButton", { Name = def.Menu, Text = "", AutoButtonColor = false, BackgroundTransparency = 1, LayoutOrder = i, Parent = stack })
		-- soft colored glow behind the icon
		local glow = UIKit.Create("Frame", { BackgroundColor3 = def.Colors[1], BackgroundTransparency = 0.55, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, ICON / 2), Size = UDim2.fromOffset(ICON - 10, ICON - 10), ZIndex = 1, Parent = button })
		UIKit.Corner(glow, UDim.new(1, 0))
		UIKit.Create("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }), Rotation = 90, Parent = glow })
		local iconHolder = UIKit.Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(ICON, ICON), ZIndex = 3, Parent = button })
		UIKit.Icon({ Icon = { Emoji = def.Emoji }, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = iconHolder })
		UIKit.Label({ Text = def.Label, Size = UDim2.new(1, 10, 0, LABEL_H), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, ICON - 4), ZIndex = 4, StrokeThickness = 3.5, Parent = button })
		UIKit.Bouncy(button, 1.12)
		button.MouseEnter:Connect(function()
			UIKit.Tween(iconHolder, 0.15, { Rotation = -8 })
		end)
		button.MouseLeave:Connect(function()
			UIKit.Tween(iconHolder, 0.2, { Rotation = 0 })
		end)
		button.Activated:Connect(function()
			UIKit.PlaySound("Click", 0.4)
			HUD.OpenMenu(def.Menu)
		end)
		badgeSetters[def.Menu] = UIKit.Badge(iconHolder)
	end
end

local speedFill
-- Bottom-center stats: gems | big coins | tokens, a studded speed bar, and three quick buttons.
local function buildCurrencies()
	local holder = UIKit.Create("Frame", {
		Name = "BottomBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(860, 176),
		Parent = screen,
	})
	UIKit.AutoScale(holder)
	-- stats row
	local function stat(key, emoji, color, x, anchorX, width, height)
		local box = UIKit.Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(anchorX, 0), Position = UDim2.new(x, 0, 0, 52 - height), Size = UDim2.fromOffset(width, height), Parent = holder })
		UIKit.Icon({ Icon = { Emoji = emoji }, Size = UDim2.fromOffset(height, height), ZIndex = 2, Parent = box })
		local label = UIKit.Label({ Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(1, 1, 1), StrokeThickness = 4, Size = UDim2.new(1, -(height + 6), 1, 0), Position = UDim2.fromOffset(height + 6, 0), ZIndex = 2, Parent = box })
		UIKit.Create("UIGradient", { Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.45), color), Rotation = 90, Parent = label })
		currencyLabels[key] = label
		return box
	end
	stat("Gems", "💎", Color3.fromRGB(110, 210, 255), 0.02, 0, 220, 42)
	stat("Coins", "💵", Color3.fromRGB(255, 200, 40), 0.5, 0.5, 360, 54)
	stat("Tokens", "♻️", Color3.fromRGB(240, 100, 220), 0.98, 1, 200, 42)
	incomeLabel = UIKit.Label({ Text = "+$0/s", TextColor3 = Color3.fromRGB(140, 255, 120), StrokeThickness = 3, AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(300, 26), Position = UDim2.new(0.5, 0, 0, -2), Parent = holder })

	-- studded yellow speed bar (fills toward the next speed point while you train)
	local bar = UIKit.Create("Frame", { Name = "SpeedBar", BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 58), ClipsDescendants = true, Parent = holder })
	UIKit.Corner(bar, 8)
	UIKit.Stroke(bar, 5, UIKit.Outline, true)
	UIKit.Gradient(bar, { Color3.fromRGB(150, 110, 40), Color3.fromRGB(110, 70, 20) }, 90)
	speedFill = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0.3, 1), ZIndex = 2, Parent = bar })
	UIKit.Gradient(speedFill, { Color3.fromRGB(255, 235, 70), Color3.fromRGB(255, 175, 20) }, 90)
	local studs = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = bar })
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(16, 16), CellPadding = UDim2.fromOffset(22, 6), Parent = studs })
	UIKit.Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 9), Parent = studs })
	for _ = 1, 44 do
		local stud = UIKit.Create("Frame", { BackgroundTransparency = 1, ZIndex = 3, Parent = studs })
		UIKit.Corner(stud, 3)
		UIKit.Create("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.8, Parent = stud })
	end
	speedLabel = UIKit.Label({ Name = "Speed", Text = "Speed", TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 4, Size = UDim2.new(0.6, 0, 1, -10), Position = UDim2.fromOffset(18, 5), ZIndex = 5, Parent = bar })

	-- quick buttons under the bar
	local quick = UIKit.Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 122), Size = UDim2.fromOffset(700, 54), Parent = holder })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 18), Parent = quick })
	UIKit.Button({ Name = "EquipBest", Text = "Equip Best", Colors = UIKit.Colors.Yellow, Size = UDim2.fromOffset(210, 54), CornerRadius = 8, Parent = quick, OnClick = function()
		HUD.Result(State.Action("EquipBest"))
	end })
	UIKit.Button({ Name = "Home", Text = "My Plot", Colors = UIKit.Colors.Orange, Size = UDim2.fromOffset(210, 54), CornerRadius = 8, Parent = quick, OnClick = function()
		HUD.Result(State.Action("TeleportMuseum"))
	end })
	UIKit.Button({ Name = "GetCoins", Text = "+ Coins", Colors = UIKit.Colors.Red, Size = UDim2.fromOffset(210, 54), CornerRadius = 8, Parent = quick, OnClick = function()
		HUD.OpenMenu("Shop")
	end })
end

local lastShown = {}
local function refreshCurrencies()
	local values = { Coins = State.Coins, Gems = State.Gems, Tokens = State.Tokens }
	for key, label in pairs(currencyLabels) do
		local text = (key == "Coins" and "$" or "") .. Format.Abbrev(values[key] or 0)
		if lastShown[key] ~= text then
			if key ~= "Coins" and lastShown[key] then
				UIKit.Pop(label, 1.15)
			end
			label.Text = text
			lastShown[key] = text
		end
	end
	incomeLabel.Text = "+" .. Format.Coins(State.Income or 0) .. "/s"
end

local function buildTopBits()
	toastHolder = UIKit.Create("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200),
		Size = UDim2.fromOffset(720, 300),
		Parent = screen,
	})
	UIKit.AutoScale(toastHolder)
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = toastHolder })

	announceFrame = UIKit.Create("Frame", { Name = "Announcement", BackgroundTransparency = 1, Size = UDim2.fromOffset(760, 70), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -140), ZIndex = 80, Parent = screen })
	announceFrame.Visible = false
	UIKit.AutoScale(announceFrame)
	local bannerBar
	bannerBar, announceLabel = UIKit.StripeBar({ Text = "", Colors = UIKit.Colors.Yellow, Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(30, 0), ZIndex = 81, Parent = announceFrame })
	bannerBar.Name = "Bar"
	announceLabel.Size = UDim2.new(1, -40, 1, -16)
	announceLabel.Position = UDim2.fromOffset(20, 8)
	UIKit.Gem(announceFrame, UIKit.GemColors[3], 64, UDim2.new(0, 22, 0.5, 0), 90, -15)
	UIKit.Gem(announceFrame, UIKit.GemColors[2], 64, UDim2.new(1, -22, 0.5, 0), 90, 15)
	local announceScale = UIKit.Create("UIScale", { Parent = announceFrame })
	announceFrame:GetPropertyChangedSignal("Visible"):Connect(function()
		if announceFrame.Visible then
			announceScale.Scale = 0.6
			UIKit.Tween(announceScale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)

	eventFrame = UIKit.Card({ Name = "EventBanner", Size = UDim2.fromOffset(480, 48), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Colors = { UIKit.Stone.Light, UIKit.Stone.Dark }, Parent = screen, CornerRadius = 12, StrokeThickness = 5 })
	UIKit.AutoScale(eventFrame)
	eventLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), StrokeThickness = 2.5, Parent = eventFrame })

	carryFrame = UIKit.Card({ Name = "CarryBanner", Size = UDim2.fromOffset(420, 34), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Colors = UIKit.Colors.Orange, Parent = screen, CornerRadius = 27 })
	carryFrame.Visible = false
	UIKit.AutoScale(carryFrame)
	carryLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), StrokeThickness = 3, Parent = carryFrame })

	splashLabel = UIKit.Label({ Name = "Splash", Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(420, 38), StrokeThickness = 3, ZIndex = 120, Parent = screen })
	splashLabel.Visible = false
	UIKit.AutoScale(splashLabel)

	raidFrame = UIKit.Card({ Name = "RaidBanner", Size = UDim2.fromOffset(560, 50), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 124), Colors = UIKit.Colors.Red, Parent = screen, CornerRadius = 25 })
	raidFrame.Visible = false
	UIKit.AutoScale(raidFrame)
	raidLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), StrokeThickness = 3, Parent = raidFrame })

	boostHolder = UIKit.Create("Frame", {
		Name = "Boosts",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 64),
		Size = UDim2.fromOffset(240, 200),
		Parent = screen,
	})
	UIKit.AutoScale(boostHolder)
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Parent = boostHolder })

	-- boss health bar (while Dr. Grow's robot is in the base)
	local bossBar = UIKit.Card({ Name = "BossBar", Size = UDim2.fromOffset(420, 40), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Colors = UIKit.Colors.Dark, Parent = screen, CornerRadius = 14 })
	UIKit.AutoScale(bossBar)
	bossBar.Visible = false
	local bossFill = UIKit.Create("Frame", { BackgroundColor3 = Color3.fromRGB(110, 255, 90), BorderSizePixel = 0, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -12), Parent = bossBar })
	UIKit.Corner(bossFill, 10)
	local bossLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), StrokeThickness = 2.5, ZIndex = 3, Parent = bossBar })
	task.spawn(function()
		while true do
			task.wait(0.2)
			local active = workspace:GetAttribute("BossActive") == true
			bossBar.Visible = active
			if active then
				local hp, max = workspace:GetAttribute("BossHP") or 0, workspace:GetAttribute("BossMax") or 1
				bossFill.Size = UDim2.new(math.clamp(hp / max, 0, 1), -12, 1, -12)
				local left = math.max(0, (workspace:GetAttribute("BossEndsAt") or 0) - os.time())
				bossLabel.Text = string.format("Dr. Grow's Robot  %d / %d  ·  %d:%02d", hp, max, left // 60, left % 60)
			end
		end
	end)

	-- 📍 which area you're in (top-right)
	local areaPill = UIKit.Card({ Name = "AreaPill", Size = UDim2.fromOffset(260, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 12), Colors = { UIKit.Stone.Light, UIKit.Stone.Dark }, Parent = screen, CornerRadius = 12, StrokeThickness = 5 })
	UIKit.AutoScale(areaPill)
	local areaLabel = UIKit.Label({ Text = "Safe Zone", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), StrokeThickness = 2.5, Parent = areaPill })
	local lastArea
	task.spawn(function()
		while true do
			task.wait(0.4)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local name, color = "Safe Zone", Color3.fromRGB(120, 230, 255)
				if root.Position.Z >= 0 then
					local z = 0
					for _, t in ipairs(TierConfig.Tiers) do
						z += t.AreaDepth
						name, color = "📍 " .. t.Area, t.Color
						if root.Position.Z < z then
							break
						end
					end
				end
				-- night / boss countdowns take over the pill
				local nightIn, nightLeft = workspace:GetAttribute("NightIn"), workspace:GetAttribute("NightLeft")
				local bossIn = workspace:GetAttribute("BossIn")
				if bossIn then
					name, color = "Boss in " .. bossIn .. "s", Color3.fromRGB(110, 255, 90)
				elseif nightIn then
					name, color = "Night in " .. nightIn .. "s", Color3.fromRGB(170, 180, 255)
				elseif nightLeft then
					name, color = "New boxes in " .. nightLeft .. "s", Color3.fromRGB(255, 220, 90)
				end
				if name ~= lastArea then
					lastArea = name
					areaLabel.Text = name
					areaLabel.TextColor3 = color
					UIKit.Pop(areaPill, 1.08)
				end
			end
		end
	end)
end

local function buildRayBits()
	chargeHolder = UIKit.Create("Frame", { Name = "Charge", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(190, 26), Visible = false, ZIndex = 90, Parent = screen })
	chargeBar = UIKit.ProgressBar({ Size = UDim2.fromScale(1, 1), Colors = UIKit.Colors.Cyan, ZIndex = 90, Parent = chargeHolder })

	hoverLabel = UIKit.Label({ Name = "Hover", Text = "", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(420, 30), ZIndex = 90, StrokeThickness = 3, Parent = screen })
	hoverLabel.Visible = false

	crosshair = UIKit.Create("Frame", { Name = "Crosshair", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(34, 34), Visible = false, ZIndex = 89, Parent = screen })
	local ring = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = crosshair })
	UIKit.Corner(ring, UDim.new(1, 0))
	UIKit.Stroke(ring, 3, Color3.new(1, 1, 1), true)
	local dot = UIKit.Create("Frame", { BackgroundColor3 = Color3.fromRGB(90, 220, 255), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8), Parent = crosshair })
	UIKit.Corner(dot, UDim.new(1, 0))
	UIKit.Stroke(dot, 2, UIKit.Outline, true)

	tooBig = UIKit.Create("CanvasGroup", { Name = "TooBig", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(200, 64), Visible = false, ZIndex = 95, Parent = screen })
	UIKit.Label({ Text = "TOO BIG!", TextColor3 = Color3.fromRGB(255, 70, 70), StrokeThickness = 5, Size = UDim2.new(1, 0, 0.65, 0), Parent = tooBig })
	tooBigSub = UIKit.Label({ Name = "Sub", Text = "", Size = UDim2.new(1, 0, 0.32, 0), Position = UDim2.fromScale(0, 0.66), StrokeThickness = 3, Parent = tooBig })
end

local function boostChip(order, text, colors)
	local chip = UIKit.Card({ Size = UDim2.fromOffset(230, 40), Colors = colors, LayoutOrder = order, Parent = boostHolder, CornerRadius = 20 })
	UIKit.Label({ Text = text, Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), StrokeThickness = 2.5, Parent = chip })
end

local function refreshTimers()
	-- event banner
	local now = State.Now()
	local ev = State.Event
	if ev then
		if ev.Current then
			local cfg = EventConfig.Events[ev.Current]
			eventLabel.Text = string.upper(cfg.Name) .. " · " .. Format.Clock(ev.EndsAt - now)
			UIKit.SetButtonColors(eventFrame, { cfg.Color:Lerp(Color3.new(1, 1, 1), 0.3), cfg.Color })
		else
			local nextCfg = EventConfig.Events[ev.Next]
			eventLabel.Text = "Next: " .. nextCfg.Name .. " in " .. Format.Clock(ev.NextAt - now)
			UIKit.SetButtonColors(eventFrame, { UIKit.Stone.Light, UIKit.Stone.Dark })
		end
	end
	-- boosts
	for _, c in ipairs(boostHolder:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local data = State.Data
	if data then
		if data.Potions.Luck > now then
			boostChip(1, "2x Luck " .. Format.Clock(data.Potions.Luck - now), UIKit.Colors.Green)
		end
		if data.Potions.Income > now then
			boostChip(2, "2x Income " .. Format.Clock(data.Potions.Income - now), UIKit.Colors.Yellow)
		end
	end
	if ev and ev.ServerLuckUntil and ev.ServerLuckUntil > now then
		boostChip(3, "Server Luck " .. Format.Clock(ev.ServerLuckUntil - now), UIKit.Colors.Blue)
	end
	-- carry banner
	local carry = data and data.Carry
	if carry and carry.Count > 0 then
		carryFrame.Visible = true
		local chaser = carry.Chaser and ("  ·  " .. carry.Chaser .. " is chasing you!") or ""
		local what = carry.TopKind == "Item" and "it" or "your box"
		local goal = carry.Chaser and "RUN!! Get to the SAFE ZONE" or (carry.AtPlot and ("Press F to put " .. what .. " down anywhere") or "Bring it to YOUR plot")
		if (carry.Rage or 0) > 0 then
			goal = string.rep("😡", carry.Rage) .. " " .. goal
		end
		carryLabel.Text = string.format("%d/%s · %s%s", carry.Count, carry.Capacity >= 999 and "∞" or tostring(carry.Capacity), goal, chaser)
		UIKit.SetButtonColors(carryFrame, carry.Chaser and UIKit.Colors.Red or UIKit.Colors.Orange)
		if dropButton then
			dropButton.Visible = true
		end
		if placeButton then
			placeButton.Visible = carry.AtPlot == true
		end
	else
		carryFrame.Visible = false
		if dropButton then
			dropButton.Visible = false
		end
		if placeButton then
			placeButton.Visible = false
		end
	end
	-- speed (trained on the treadmill)
	local speed = data and data.Speed
	if speed and speedLabel then
		speedLabel.Text = string.format("Speed %d", math.floor(speed.Walk)) .. (speed.Training and string.format("   +%s pts/s", Format.Abbrev(speed.Rate)) or "   Train on your treadmill!")
		speedLabel.TextColor3 = speed.Training and Color3.fromRGB(190, 255, 170) or Color3.new(1, 1, 1)
		if speedFill then
			speedFill.Size = UDim2.fromScale(math.clamp(speed.Walk % 1, 0.03, 1), 1)
		end
	end
	-- raid banner
	if data and data.ActiveRaid then
		raidFrame.Visible = true
		raidLabel.Text = string.format("RAIDING %s · %s · %d/%d copies", data.ActiveRaid.VictimName, Format.Clock(data.ActiveRaid.EndsAt - now), data.ActiveRaid.Copies, data.ActiveRaid.Max)
	elseif data and data.BeingRaidedBy then
		raidFrame.Visible = true
		raidLabel.Text = "⚠️ " .. data.BeingRaidedBy .. " is raiding you! (you lose nothing)"
	else
		raidFrame.Visible = false
	end
end

local function refreshBadges()
	for name, menu in pairs(menus) do
		if menu.Badge and badgeSetters[name] then
			badgeSetters[name](menu.Badge())
		end
	end
end

function HUD.Init()
	screen = UIKit.Create("ScreenGui", {
		Name = "ShrinkItHUD",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	buildLeftStack()
	buildCurrencies()
	-- build version, bottom-right (tells you which file you're running)
	UIKit.Label({ Name = "Version", Text = "Shrink It! " .. require(Shared.Config.GameConfig).Version, TextColor3 = Color3.fromRGB(255, 255, 255), StrokeThickness = 1.5, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -6), Size = UDim2.fromOffset(260, 18), Parent = screen })
	buildTopBits()
	buildRayBits()

	-- menus
	local ctx = { Screen = screen, HUD = HUD }
	local menuFolder = Modules:WaitForChild("Menus")
	local menuDefs = table.clone(LEFT_BUTTONS)
	for _, extra in ipairs({ "Sell", "Fuse", "Trails", "Settings", "Lab", "Admin" }) do -- opened from the stands / top bar
		table.insert(menuDefs, { Menu = extra })
	end
	for _, def in ipairs(menuDefs) do
		local module = menuFolder:FindFirstChild(def.Menu .. "Menu")
		if module then
			local ok, menu = pcall(function()
				return require(module).Build(ctx)
			end)
			if ok and menu then
				menus[def.Menu] = menu
				table.insert(menuOrder, def.Menu)
			elseif ok then
				-- the menu chose not to exist for this player (e.g. Admin for non-admins)
			else
				warn("[HUD] menu " .. def.Menu .. " failed: " .. tostring(menu))
			end
		end
	end

	-- stands in the base (ProximityPrompts with an "OpensMenu" attribute)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local menuName = prompt:GetAttribute("OpensMenu")
		if menuName then
			HUD.ShowMenu(menuName)
		end
	end)

	-- ⚙️ Settings button (top bar, next to Roblox's buttons)
	local settingsButton = UIKit.Button({
		Name = "SettingsButton",
		Text = "⚙️",
		Colors = { Color3.fromRGB(150, 150, 165), Color3.fromRGB(90, 90, 105) },
		Size = UDim2.fromOffset(56, 56),
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 168, 0, 6),
		CornerRadius = 26,
		Parent = screen,
		OnClick = function()
			HUD.OpenMenu("Settings")
		end,
	})
	UIKit.AutoScale(settingsButton)

	-- right side: FREE REWARDS gift + gamepass offer cards (hidden once you own them)
	local right = UIKit.Create("Frame", {
		Name = "RightStack",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 10),
		Size = UDim2.fromOffset(230, 470),
		Parent = screen,
	})
	UIKit.AutoScale(right)
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = right })
	local gift = UIKit.Create("TextButton", { Name = "FreeRewards", Text = "", AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.fromOffset(150, 132), LayoutOrder = 0, Parent = right })
	local giftIcon = UIKit.Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(92, 92), Parent = gift })
	UIKit.Icon({ Icon = { Emoji = "🎁" }, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = giftIcon })
	UIKit.Label({ Text = "FREE REWARDS!", Size = UDim2.new(1, 20, 0, 34), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 92), StrokeThickness = 4, ZIndex = 3, Parent = gift })
	badgeSetters.Gifts = badgeSetters.Gifts or UIKit.Badge(giftIcon)
	UIKit.Bouncy(gift, 1.1)
	gift.Activated:Connect(function()
		UIKit.PlaySound("Click", 0.4)
		HUD.OpenMenu("Gifts")
	end)
	task.spawn(function()
		while gift.Parent do
			UIKit.Tween(giftIcon, 0.6, { Rotation = 8 }, Enum.EasingStyle.Sine)
			task.wait(0.6)
			UIKit.Tween(giftIcon, 0.6, { Rotation = -8 }, Enum.EasingStyle.Sine)
			task.wait(0.6)
		end
	end)
	local MonetizationConfig = require(Shared.Config.MonetizationConfig)
	local Prices = require(Modules.Prices)
	local offers = {}
	for i, key in ipairs({ "DoubleSpeed", "DoubleCoins", "SpeedBoots" }) do
		local pass = MonetizationConfig.GamePasses[key]
		if pass then
			local card = UIKit.Create("TextButton", { Name = "Offer_" .. key, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(220, 92), LayoutOrder = i, Parent = right })
			UIKit.Corner(card, 12)
			UIKit.Stroke(card, 5, Color3.fromRGB(150, 90, 0), true)
			UIKit.Gradient(card, { Color3.fromRGB(255, 240, 90), Color3.fromRGB(255, 185, 20) }, 90)
			UIKit.Halftone(card, Color3.fromRGB(255, 255, 255), true)
			UIKit.Icon({ Icon = { Emoji = pass.Emoji }, Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(-14, -16), ZIndex = 3, Parent = card })
			UIKit.Label({ Text = pass.Name, Size = UDim2.new(1, -60, 0, 38), Position = UDim2.fromOffset(52, 8), StrokeThickness = 3.5, ZIndex = 3, Parent = card })
			local price = UIKit.Label({ Text = "", RichText = true, Size = UDim2.new(1, -16, 0, 34), Position = UDim2.fromOffset(8, 50), StrokeThickness = 3.5, ZIndex = 3, Parent = card })
			local function setPrice()
				local p = Prices.Get(Enum.InfoType.GamePass, pass.Id, pass.PriceLabel)
				price.Text = 'Only <font color="#FF5CF0">' .. tostring(p):gsub("^R%$%s*", "") .. ' R$</font>!'
			end
			setPrice()
			Prices.OnUpdated(setPrice)
			UIKit.Bouncy(card, 1.06)
			card.Activated:Connect(function()
				UIKit.PlaySound("Click", 0.4)
				HUD.Result(State.Action("PromptPass", key))
			end)
			offers[key] = card
		end
	end
	task.spawn(function()
		while right.Parent do
			for key, card in pairs(offers) do
				card.Visible = not State.HasPass(key)
			end
			task.wait(2)
		end
	end)

	-- Place button (in your plot while carrying) + F key: puts it down ANYWHERE in your plot.
	-- Keyboard/mouse: where your mouse points (a green ring shows the spot). Touch/button: right in front of you.
	local ghost = Instance.new("Part")
	ghost.Name = "PlaceGhost"
	ghost.Shape = Enum.PartType.Cylinder
	ghost.Size = Vector3.new(0.2, 4.2, 4.2)
	ghost.Anchored, ghost.CanCollide, ghost.CanQuery, ghost.CanTouch = true, false, false, false
	ghost.Material = Enum.Material.Neon
	ghost.Color = Color3.fromRGB(90, 255, 120)
	ghost.Transparency = 0.5
	local function aimPoint()
		if not UserInputService.MouseEnabled then
			return nil
		end
		local camera = workspace.CurrentCamera
		local m = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(m.X, m.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character, ghost }
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if hit and root and (hit.Position - root.Position).Magnitude <= 30 then
			return hit.Position
		end
		return nil
	end
	local function placeOnGround(useMouse)
		HUD.Result(State.Action("PlaceGround", useMouse and aimPoint() or nil))
	end
	game:GetService("RunService").RenderStepped:Connect(function()
		local show = placeButton and placeButton.Visible
		local p = show and aimPoint()
		if p then
			ghost.CFrame = CFrame.new(p + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
			ghost.Parent = workspace
		else
			ghost.Parent = nil
		end
	end)
	placeButton = UIKit.Button({
		Name = "Place",
		Text = "Place (F)",
		Colors = UIKit.Colors.Green,
		Size = UDim2.fromOffset(260, 72),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -290),
		Parent = screen,
		OnClick = function()
			placeOnGround(false)
		end,
	})
	placeButton.Visible = false
	UIKit.AutoScale(placeButton)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F then
			local carry = State.Data and State.Data.Carry
			if carry and carry.Count > 0 and carry.AtPlot then
				placeOnGround(true)
			end
		end
	end)

	-- Drop button (only while carrying)
	dropButton = UIKit.Button({
		Name = "Drop",
		Text = "Drop",
		Colors = UIKit.Colors.Red,
		Size = UDim2.fromOffset(220, 66),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -210),
		Parent = screen,
		OnClick = function()
			HUD.Result(State.Action("DropCarry"))
		end,
	})
	dropButton.Visible = false
	UIKit.AutoScale(dropButton)

	-- remotes
	Remotes.Event("Notify").OnClientEvent:Connect(HUD.Notify)
	Remotes.Event("Announce").OnClientEvent:Connect(HUD.Announce)
	Remotes.Event("Popup").OnClientEvent:Connect(onPopup)
	Remotes.Event("TooBig").OnClientEvent:Connect(function(need)
		HUD.ShowTooBig(need)
	end)

	State.CurrencyChanged:Connect(refreshCurrencies)
	State.Changed:Connect(function()
		refreshTimers()
		refreshCurrencies()
		refreshBadges()
		for _, m in pairs(menus) do
			if m.Panel.IsOpen() and m.Refresh then
				m.Refresh()
			end
		end
	end)
	State.EventChanged:Connect(refreshTimers)

	task.spawn(function()
		while true do
			refreshTimers()
			refreshBadges()
			for _, m in pairs(menus) do
				if m.Panel.IsOpen() and m.Tick then
					m.Tick()
				end
			end
			task.wait(1)
		end
	end)

	-- keyboard shortcuts
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			for _, m in pairs(menus) do
				m.Panel.Close()
			end
		end
	end)
end

return HUD
