--!strict
--[[
	App -- the HUD and the main menu.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StatConfig = require(Shared.StatConfig)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Skin = require(script.Parent.Skin)
local Sfx = require(script.Parent.Sfx)
local StatCard = require(script.Parent.StatCard)
local ShopPanel = require(script.Parent.ShopPanel)
local BoardPanel = require(script.Parent.BoardPanel)
local AchievementPanel = require(script.Parent.AchievementPanel)
local RebirthPanel = require(script.Parent.RebirthPanel)
local Toasts = require(script.Parent.Toasts)
local FlexFeed = require(script.Parent.FlexFeed)
local Store = require(script.Parent.Parent.Store)

local App = {}
App.__index = App

local PANEL = Vector2.new(1060, 790)
local CONTENT_TOP = 206
local FOOTER = 54

function App.new(callbacks)
	local self = setmetatable({}, App)

	self.callbacks = callbacks
	self.cards = {}
	self.category = "all"
	self.view = "stats"

	self.gui = Util.new("ScreenGui", {
		Name = "StatScanner",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})

	self:buildHud()
	self:buildModal()

	self.toasts = Toasts.new(self.gui)
	self.flexFeed = FlexFeed.new(self.gui)

	self.heartbeat = RunService.RenderStepped:Connect(function()
		self:tick()
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.E then
			self:setOpen(not self.modal.Visible)
		elseif input.KeyCode == Enum.KeyCode.Escape and self.modal.Visible then
			self:setOpen(false)
		end
	end)

	Store.subscribe(function(state)
		self:update(state)
	end)
	Store.subscribeLeaderboards(function(snapshot)
		self.boardPanel:update(snapshot)
	end)

	return self
end

-- HUD --------------------------------------------------------------------

function App:buildHud()
	self.hud = Util.new("Frame", {
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self.gui,
	})

	-- Coin pill
	local coins = Util.card({
		Position = UDim2.fromOffset(18, 18),
		Size = UDim2.fromOffset(212, 58),
		BackgroundColor3 = Theme.Color.gold,
		radius = Theme.Radius.full,
		lip = Theme.Lip.base,
		Parent = self.hud,
	})

	Util.badge(coins, "$", 40, Color3.new(1, 1, 1)).Position = UDim2.fromOffset(8, 6)

	self.coinLabel = Util.title({
		Position = UDim2.fromOffset(56, 0),
		Size = UDim2.new(1, -66, 1, -6),
		Text = "0",
		TextSize = 26,
		TextColor3 = Theme.Color.outline,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = coins,
	})

	-- Rank pill
	local rank = Util.card({
		Position = UDim2.fromOffset(240, 18),
		Size = UDim2.fromOffset(288, 58),
		BackgroundColor3 = Theme.Color.purple,
		radius = Theme.Radius.full,
		lip = Theme.Lip.base,
		Parent = self.hud,
	})

	self.rankLabel = Util.title({
		Position = UDim2.fromOffset(18, 4),
		Size = UDim2.new(1, -36, 0, 26),
		Text = "NOOB",
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = rank,
	})

	local track = Util.well({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(1, -36, 0, 12),
		ZIndex = 3,
		Parent = rank,
	})

	self.rankBar = Util.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Color.gold,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = track,
	})
	Util.corner(Theme.Radius.full, self.rankBar)

	-- Buttons
	self.openButton = Util.button({
		variant = "go",
		radius = Theme.Radius.lg,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 18, 1, -18),
		Size = UDim2.fromOffset(268, 72),
		Text = "MY STATS",
		TextSize = 28,
		lip = Theme.Lip.chunky,
		Parent = self.hud,
	})

	self.dailyButton = Util.button({
		variant = "gold",
		radius = Theme.Radius.lg,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 298, 1, -18),
		Size = UDim2.fromOffset(200, 72),
		Text = "DAILY",
		TextSize = 22,
		lip = Theme.Lip.chunky,
		Parent = self.hud,
	})

	Util.onClick(self.openButton, 0.2, function()
		self:setOpen(true)
	end)
	Util.onClick(self.dailyButton, 1, function()
		self.callbacks.claimDaily()
	end)
end

-- Modal ------------------------------------------------------------------

function App:buildModal()
	self.backdrop = Util.new("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.night,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = self.gui,
	})
	Util.onClick(self.backdrop, 0.1, function()
		self:setOpen(false)
	end)

	self.modal = Util.card({
		Name = "Modal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL.X, PANEL.Y),
		BackgroundColor3 = Theme.Color.panel,
		radius = Theme.Radius.xl,
		weight = Theme.Outline.chunky,
		lip = Theme.Lip.chunky,
		gloss = false,
		padding = Theme.Space.panel,
		ZIndex = 5,
		Visible = false,
		Parent = self.gui,
	})

	local scale = Util.new("UIScale", { Parent = self.modal })
	self.modalScale = scale
	local function fit()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.min(1, (viewport.X - 32) / PANEL.X, (viewport.Y - 32) / PANEL.Y)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	self.fit = fit

	self.title = Util.title({
		Size = UDim2.new(1, -80, 0, 52),
		Text = "MY STATS",
		TextSize = 46,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = self.modal,
	})

	self.subtitle = Util.text({
		Position = UDim2.fromOffset(4, 52),
		Size = UDim2.new(1, -80, 0, 20),
		Font = Theme.Font.small,
		Text = "pick a stat and scan it",
		TextColor3 = Theme.Color.inkMuted,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = self.modal,
	})

	local close = Util.button({
		variant = "danger",
		radius = Theme.Radius.full,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(54, 54),
		Text = "X",
		TextSize = 24,
		ZIndex = 6,
		Parent = self.modal,
	})
	Util.onClick(close, 0.1, function()
		self:setOpen(false)
	end)

	-- Stats strip
	local strip = Util.well({
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 34),
		radius = Theme.Radius.md,
		ZIndex = 6,
		Parent = self.modal,
	})

	self.status = Util.text({
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 1, 0),
		Font = Theme.Font.body,
		Text = "",
		TextColor3 = Theme.Color.inkMuted,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = strip,
	})

	-- Tabs
	self.navButtons = {}

	local function rail(y: number)
		local holder = Util.new("Frame", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundTransparency = 1,
			ZIndex = 6,
			Parent = self.modal,
		})
		Util.listLayout(Theme.Space.tight, holder, Enum.FillDirection.Horizontal)
		return holder
	end

	local categoryRail = rail(124)
	local sectionRail = rail(166)

	local function tab(parent: Instance, id: string, text: string, width: number, fill: Color3)
		local button = Util.button({
			variant = "dark",
			radius = Theme.Radius.full,
			Size = UDim2.fromOffset(width, 34),
			Text = text,
			TextSize = 14,
			lip = Theme.Lip.small,
			sound = "tab",
			ZIndex = 6,
			Parent = parent,
		})
		Util.onClick(button, 0.1, function()
			self:setView(id)
		end)
		self.navButtons[id] = { button = button, fill = fill }
		return button
	end

	tab(categoryRail, "stats", "ALL", 74, Theme.Color.green)
	local catColor = {
		core = Theme.Color.cyan,
		movement = Theme.Color.orange,
		combat = Theme.Color.red,
		social = Theme.Color.pink,
		economy = Theme.Color.green,
		collection = Theme.Color.purple,
		cursed = Theme.Color.gold,
	}
	for _, category in ipairs(StatConfig.Categories) do
		tab(
			categoryRail,
			"cat:" .. category.id,
			(category.icon .. " " .. category.name):upper(),
			126,
			catColor[category.id] or Theme.Color.purple
		)
	end

	tab(sectionRail, "shop", "SHOP", 158, Theme.Color.gold)
	tab(sectionRail, "boards", "LEADERBOARDS", 200, Theme.Color.cyan)
	tab(sectionRail, "achievements", "QUESTS", 158, Theme.Color.pink)
	tab(sectionRail, "rebirth", "REBIRTH", 158, Theme.Color.purple)

	-- Content
	self.content = Util.new("Frame", {
		Position = UDim2.fromOffset(0, CONTENT_TOP),
		Size = UDim2.new(1, 0, 1, -CONTENT_TOP - FOOTER),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = self.modal,
	})

	self.statList = Util.new("ScrollingFrame", {
		Name = "StatList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Color.purple,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 6,
		Parent = self.content,
	})
	Util.listLayout(Theme.Space.gap, self.statList)
	Util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 4),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 10),
		Parent = self.statList,
	})

	self.shopPanel = ShopPanel.new(self.content, self.callbacks)
	self.boardPanel = BoardPanel.new(self.content)
	self.achievementPanel = AchievementPanel.new(self.content)
	self.rebirthPanel = RebirthPanel.new(self.content, self.callbacks)

	-- Footer
	local footer = Util.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = self.modal,
	})
	Util.listLayout(Theme.Space.tight, footer, Enum.FillDirection.Horizontal)

	self.scanAllButton = Util.button({
		variant = "go",
		Size = UDim2.fromOffset(232, 44),
		Text = "SCAN EVERYTHING",
		TextSize = 17,
		lip = Theme.Lip.base,
		ZIndex = 6,
		Parent = footer,
	})
	Util.onClick(self.scanAllButton, 0.5, function()
		self.callbacks.scanAll()
	end)

	self.autoButton = Util.button({
		variant = "dark",
		Size = UDim2.fromOffset(200, 44),
		Text = "AUTO: OFF",
		TextSize = 16,
		lip = Theme.Lip.base,
		ZIndex = 6,
		Parent = footer,
	})
	Util.onClick(self.autoButton, 0.5, function()
		local state = Store.get()
		self.callbacks.setAutoScan(not (state and state.autoScan))
	end)

	self.resetButton = Util.button({
		variant = "dark",
		Size = UDim2.fromOffset(160, 44),
		Text = "RESET",
		TextSize = 16,
		lip = Theme.Lip.base,
		ZIndex = 6,
		Parent = footer,
	})
	Util.onClick(self.resetButton, 1, function()
		self.callbacks.resetScans()
	end)

	self.progressLabel = Util.title({
		Size = UDim2.fromOffset(260, 44),
		Text = "",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = footer,
	})

	for index, stat in ipairs(StatConfig.Stats) do
		local card = StatCard.new(stat, self.callbacks, index)
		card.root.Parent = self.statList
		self.cards[stat.id] = card
	end
end

-- Views ------------------------------------------------------------------

local TITLES = {
	stats = { "MY STATS", "pick a stat and scan it" },
	shop = { "SHOP", "spend robux, scan faster" },
	boards = { "LEADERBOARDS", "who is the biggest no-lifer" },
	achievements = { "QUESTS", "finish these for free coins" },
	rebirth = { "REBIRTH", "wipe your scans, keep the power" },
}

function App:setView(view: string)
	self.view = view

	local isStats = view == "stats" or view:sub(1, 4) == "cat:"
	self.category = view:sub(1, 4) == "cat:" and view:sub(5) or "all"

	self.statList.Visible = isStats
	self.shopPanel:setVisible(view == "shop")
	self.boardPanel:setVisible(view == "boards")
	self.achievementPanel:setVisible(view == "achievements")
	self.rebirthPanel:setVisible(view == "rebirth")

	for id, entry in pairs(self.navButtons) do
		local selected = id == view
		entry.button.BackgroundColor3 = selected and entry.fill or Theme.Color.slot
		entry.button.TextColor3 = selected and Theme.inkOn(entry.fill) or Theme.Color.inkMuted
		local lip = entry.button:FindFirstChild("Lip") :: Frame?
		if lip then
			lip.BackgroundColor3 = Theme.shade(entry.button.BackgroundColor3, -0.32)
		end
	end

	local heading = TITLES[isStats and "stats" or view]
	if heading then
		self.title.Text = isStats and self.category ~= "all" and self.category:upper() or heading[1]
		self.subtitle.Text = heading[2]
	end

	if isStats then
		self:applyFilter()
		self.statList.CanvasPosition = Vector2.new()
	end

	if view == "boards" then
		self.callbacks.refreshBoards()
	end
end

function App:applyFilter()
	for _, card in pairs(self.cards) do
		card.root.Visible = self.category == "all" or card.stat.category == self.category
	end
end

function App:setOpen(open: boolean, view: string?)
	self.modal.Visible = open
	self.backdrop.Visible = open
	self.hud.Visible = not open

	if open then
		Sfx.play("tab")
		self:setView(view or self.view)
		self.fit()
		local target = self.modalScale.Scale
		self.modalScale.Scale = target * 0.88
		Util.tween(self.modalScale, 0.28, { Scale = target }, Theme.Motion.pop)
	end
end

-- Updates ----------------------------------------------------------------

function App:update(state)
	if not state then
		return
	end

	if self.lastCoins and state.coins > self.lastCoins then
		Skin.pop(self.coinLabel, 0.25)
	end
	self.lastCoins = state.coins
	self.coinLabel.Text = Format.comma(state.coins)

	local rank = state.rank or { name = "?", icon = "" }
	self.rankLabel.Text = ("%s %s"):format(rank.icon, rank.name:upper())
	self.rankBar.Size = UDim2.fromScale(state.rankProgress or 0, 1)

	local scanned = 0
	for _ in pairs(state.scanned) do
		scanned += 1
	end

	self.status.Text = ("%.1fx speed   ·   %.1fx coins   ·   %d slot%s   ·   %d rebirths"):format(
		state.speed or 1,
		state.coinMultiplier or 1,
		state.slots or 1,
		(state.slots or 1) == 1 and "" or "s",
		state.rebirths or 0
	)

	self.progressLabel.Text = ("%d / %d"):format(scanned, StatConfig.Count)

	local auto = state.autoScan == true
	self.autoButton.Text = auto and "AUTO: ON" or "AUTO: OFF"
	self.autoButton.BackgroundColor3 = auto and Theme.Color.cyan or Theme.Color.slot
	self.autoButton.TextColor3 = auto and Theme.inkOn(Theme.Color.cyan) or Theme.Color.inkMuted

	local daily = state.daily
	if daily then
		self.dailyButton.Text = daily.canClaim and ("DAILY +" .. Format.comma(daily.reward))
			or Format.clock(daily.secondsUntilNext)
		self.dailyButton.BackgroundColor3 = daily.canClaim and Theme.Color.gold or Theme.Color.slot
		self.dailyButton.TextColor3 = daily.canClaim and Theme.inkOn(Theme.Color.gold) or Theme.Color.inkMuted
	end

	for _, card in pairs(self.cards) do
		card:update(state)
	end

	self.shopPanel:update(state)
	self.achievementPanel:update(state)
	self.rebirthPanel:update(state)
end

function App:tick()
	if not self.modal.Visible then
		return
	end
	local now = workspace:GetServerTimeNow()
	for _, card in pairs(self.cards) do
		card:tick(now)
	end
end

function App:notify(payload)
	self.toasts:push(payload)
end

function App:flex(payload)
	self.flexFeed:push(payload)
end

function App:onScanFinished(payload)
	local card = self.cards[payload.statId]
	if not card then
		return
	end

	Sfx.play(payload.isNew and "reward" or "scan")

	self.toasts:push({
		text = ("%s\n%s"):format(card.stat.name, Format.value(card.stat.format, payload.value)),
		coins = payload.coins,
		icon = card.stat.icon,
		color = card.stat.color,
	})

	if self.modal.Visible then
		card:celebrate()
	end
end

return App
