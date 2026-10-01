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

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local EventConfig = require(Shared.Config.EventConfig)

local Modules = script.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local HUD = {}

local player = Players.LocalPlayer
local screen
local menus = {} -- [name] = menu
local menuOrder = {}
local badgeSetters = {}

-- ── helpers ───────────────────────────────────────────────────────────
local KIND_COLORS = {
	success = UIKit.Colors.Green,
	error = UIKit.Colors.Red,
	info = UIKit.Colors.Blue,
	new = UIKit.Colors.Purple,
	shrink = UIKit.Colors.Yellow,
}

local toastHolder
function HUD.Notify(text, kind)
	if not toastHolder then
		return
	end
	local colors = KIND_COLORS[kind] or KIND_COLORS.info
	local toast = UIKit.Card({ Size = UDim2.fromOffset(math.clamp(#text * 13 + 60, 260, 720), 46), Colors = colors, Parent = toastHolder, CornerRadius = 14 })
	toast.LayoutOrder = -math.floor(os.clock() * 100)
	UIKit.Label({ Text = text, Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), StrokeThickness = 2.5, Parent = toast })
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
	task.delay(3.2, function()
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
	UIKit.SetButtonColors(announceFrame, { c:Lerp(Color3.new(1, 1, 1), 0.35), c })
	announceLabel.Text = a.Text
	announceFrame.Visible = true
	announceFrame.Position = UDim2.new(0.5, 0, 0, -120)
	UIKit.Tween(announceFrame, 0.45, { Position = UDim2.new(0.5, 0, 0, 118) }, Enum.EasingStyle.Back)
	UIKit.PlaySound("Reward", 0.35)
	task.delay(4.5, function()
		local t = UIKit.Tween(announceFrame, 0.3, { Position = UDim2.new(0.5, 0, 0, -120) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
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
		popup("Daily Reward!", "📅", { "Day " .. p.Streak .. " streak 🔥", "You got: " .. p.Text, "Come back tomorrow for more!" }, UIKit.Colors.Orange)
	elseif kind == "Offline" then
		popup("Welcome Back!", "😴", { "+" .. Format.Coins(p.Amount), "Earned while offline for " .. Format.Time(p.Seconds) }, UIKit.Colors.Blue)
	elseif kind == "Rebirth" then
		popup("REBIRTH " .. p.Rebirths .. "!", "♻️", { "x" .. string.format("%.1f", p.Multiplier) .. " income forever!", "+" .. p.Gems .. " Gems  •  +" .. p.Tokens .. " Rebirth Tokens" }, UIKit.Colors.Green)
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

-- ── build ─────────────────────────────────────────────────────────────
local LEFT_BUTTONS = {
	{ Menu = "Gifts", Label = "Gifts", Emoji = "🎁", Colors = UIKit.Colors.Pink },
	{ Menu = "InfinitePack", Label = "Pack", Emoji = "♾️", Colors = UIKit.Colors.Purple },
	{ Menu = "Shop", Label = "Shop", Emoji = "🛒", Colors = UIKit.Colors.Yellow },
	{ Menu = "Index", Label = "Index", Emoji = "📖", Colors = UIKit.Colors.Blue },
	{ Menu = "Rebirth", Label = "Rebirth", Emoji = "♻️", Colors = UIKit.Colors.Green },
	{ Menu = "Museum", Label = "Museum", Emoji = "🏛️", Colors = UIKit.Colors.Orange },
	{ Menu = "Upgrades", Label = "Upgrades", Emoji = "⚡", Colors = UIKit.Colors.Cyan },
}

local currencyLabels = {}
local incomeLabel
local eventLabel, eventFrame
local boostHolder
local raidFrame, raidLabel

local function buildLeftStack()
	local stack = UIKit.Create("Frame", {
		Name = "LeftStack",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.46, 0),
		Size = UDim2.fromOffset(92, #LEFT_BUTTONS * 98),
		Parent = screen,
	})
	UIKit.AutoScale(stack)
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = stack })
	for i, def in ipairs(LEFT_BUTTONS) do
		local button = UIKit.Button({
			Name = def.Menu,
			Text = "",
			Colors = def.Colors,
			Size = UDim2.fromOffset(88, 88),
			LayoutOrder = i,
			CornerRadius = 20,
			StrokeThickness = 4,
			Parent = stack,
			OnClick = function()
				HUD.OpenMenu(def.Menu)
			end,
		})
		UIKit.Icon({ Icon = { Emoji = def.Emoji }, Size = UDim2.new(0.7, 0, 0.62, 0), Position = UDim2.fromScale(0.15, 0.04), ZIndex = 3, Parent = button })
		UIKit.Label({ Text = def.Label, Size = UDim2.new(1, -6, 0.3, 0), Position = UDim2.new(0, 3, 0.68, 0), ZIndex = 3, StrokeThickness = 2.5, Parent = button })
		badgeSetters[def.Menu] = UIKit.Badge(button)
	end
end

local function buildCurrencies()
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local holder = UIKit.Create("Frame", {
		Name = "Currencies",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = touchOnly and UDim2.new(0, 120, 1, -14) or UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(380, 186),
		Parent = screen,
	})
	UIKit.AutoScale(holder)
	local rows = {
		{ Key = "Tokens", Emoji = "♻️", Color = Color3.fromRGB(140, 255, 170), Y = 0 },
		{ Key = "Gems", Emoji = "💎", Color = Color3.fromRGB(120, 220, 255), Y = 58 },
		{ Key = "Coins", Emoji = "💵", Color = Color3.fromRGB(255, 220, 70), Y = 116 },
	}
	for _, r in ipairs(rows) do
		local big = r.Key == "Coins"
		local size = big and 68 or 52
		local icon = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(size, size), Position = UDim2.fromOffset(0, r.Y + (big and 0 or 2)), Parent = holder })
		UIKit.Corner(icon, UDim.new(1, 0))
		UIKit.Stroke(icon, 3.5, UIKit.Outline, true)
		UIKit.Gradient(icon, { r.Color:Lerp(Color3.new(1, 1, 1), 0.4), r.Color })
		UIKit.Icon({ Icon = { Emoji = r.Emoji }, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), ZIndex = 2, Parent = icon })
		local label = UIKit.Label({ Text = "0", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = r.Color, StrokeThickness = 4, Size = UDim2.fromOffset(300, big and 60 or 46), Position = UDim2.fromOffset(size + 10, r.Y + (big and 0 or 4)), Parent = holder })
		currencyLabels[r.Key] = label
	end
	incomeLabel = UIKit.Label({ Text = "+$0/s", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(160, 255, 140), StrokeThickness = 3, Size = UDim2.fromOffset(240, 30), Position = UDim2.fromOffset(80, 176), Parent = holder })
	holder.Size = UDim2.fromOffset(380, 206)
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

	announceFrame = UIKit.Card({ Name = "Announcement", Size = UDim2.fromOffset(900, 74), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -120), Colors = UIKit.Colors.Yellow, Parent = screen, StrokeThickness = 5, CornerRadius = 22 })
	announceFrame.Visible = false
	announceFrame.ZIndex = 80
	UIKit.AutoScale(announceFrame)
	announceLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -30, 1, -14), Position = UDim2.fromOffset(15, 7), ZIndex = 81, StrokeThickness = 3.5, Parent = announceFrame })

	eventFrame = UIKit.Card({ Name = "EventBanner", Size = UDim2.fromOffset(460, 46), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Colors = UIKit.Colors.Dark, Parent = screen, CornerRadius = 23 })
	UIKit.AutoScale(eventFrame)
	eventLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), StrokeThickness = 2.5, Parent = eventFrame })

	raidFrame = UIKit.Card({ Name = "RaidBanner", Size = UDim2.fromOffset(560, 50), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Colors = UIKit.Colors.Red, Parent = screen, CornerRadius = 25 })
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

	tooBig = UIKit.Create("CanvasGroup", { Name = "TooBig", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(320, 110), Visible = false, ZIndex = 95, Parent = screen })
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
			eventLabel.Text = cfg.Emoji .. " " .. string.upper(cfg.Name) .. " · " .. Format.Clock(ev.EndsAt - now)
			UIKit.SetButtonColors(eventFrame, { cfg.Color:Lerp(Color3.new(1, 1, 1), 0.3), cfg.Color })
		else
			local nextCfg = EventConfig.Events[ev.Next]
			eventLabel.Text = "Next: " .. nextCfg.Emoji .. " " .. nextCfg.Name .. " in " .. Format.Clock(ev.NextAt - now)
			UIKit.SetButtonColors(eventFrame, UIKit.Colors.Dark)
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
			boostChip(1, "🍀 2x Luck " .. Format.Clock(data.Potions.Luck - now), UIKit.Colors.Green)
		end
		if data.Potions.Income > now then
			boostChip(2, "⚗️ 2x Income " .. Format.Clock(data.Potions.Income - now), UIKit.Colors.Yellow)
		end
	end
	if ev and ev.ServerLuckUntil and ev.ServerLuckUntil > now then
		boostChip(3, "🌠 Server Luck " .. Format.Clock(ev.ServerLuckUntil - now), UIKit.Colors.Blue)
	end
	-- raid banner
	if data and data.ActiveRaid then
		raidFrame.Visible = true
		raidLabel.Text = string.format("🏴‍☠️ RAIDING %s · %s · %d/%d copies", data.ActiveRaid.VictimName, Format.Clock(data.ActiveRaid.EndsAt - now), data.ActiveRaid.Copies, data.ActiveRaid.Max)
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
	buildTopBits()
	buildRayBits()

	-- menus
	local ctx = { Screen = screen, HUD = HUD }
	local menuFolder = Modules:WaitForChild("Menus")
	for _, def in ipairs(LEFT_BUTTONS) do
		local module = menuFolder:FindFirstChild(def.Menu .. "Menu")
		if module then
			local ok, menu = pcall(function()
				return require(module).Build(ctx)
			end)
			if ok and menu then
				menus[def.Menu] = menu
				table.insert(menuOrder, def.Menu)
			else
				warn("[HUD] menu " .. def.Menu .. " failed: " .. tostring(menu))
			end
		end
	end

	-- remotes
	Remotes.Event("Notify").OnClientEvent:Connect(HUD.Notify)
	Remotes.Event("Announce").OnClientEvent:Connect(HUD.Announce)
	Remotes.Event("Popup").OnClientEvent:Connect(onPopup)
	Remotes.Event("TooBig").OnClientEvent:Connect(function(need)
		HUD.ShowTooBig(need)
	end)

	State.CurrencyChanged:Connect(refreshCurrencies)
	State.Changed:Connect(function()
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
