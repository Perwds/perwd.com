--!strict
--[[
	App
	Assembles the whole interface: HUD, the scanner modal, the category rail,
	the stat list and the four side panels.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StatConfig = require(Shared.StatConfig)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
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

local PANEL_SIZE = Vector2.new(1040, 780)

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

	-- Progress bars need a frame loop; everything else is event driven.
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
	self.coinPill = Util.new("Frame", {
		Position = UDim2.new(0, 16, 0, 16),
		Size = UDim2.new(0, 190, 0, 44),
		BackgroundColor3 = Theme.Color.panelDark,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Parent = self.hud,
	})
	Util.corner(Theme.Radius.pill, self.coinPill)
	Util.stroke(Theme.Color.coin, 2, self.coinPill)

	self.coinLabel = Util.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.Font.bold,
		Text = "🪙 0",
		TextColor3 = Theme.Color.coin,
		TextSize = 20,
		Parent = self.coinPill,
	})

	-- Rank pill
	self.rankPill = Util.new("Frame", {
		Position = UDim2.new(0, 216, 0, 16),
		Size = UDim2.new(0, 250, 0, 44),
		BackgroundColor3 = Theme.Color.panelDark,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Parent = self.hud,
	})
	Util.corner(Theme.Radius.pill, self.rankPill)
	Util.stroke(Theme.Color.accent, 2, self.rankPill)

	self.rankLabel = Util.new("TextLabel", {
		Position = UDim2.new(0, 12, 0, 2),
		Size = UDim2.new(1, -24, 0, 24),
		BackgroundTransparency = 1,
		Font = Theme.Font.bold,
		Text = "Rank",
		TextColor3 = Theme.Color.text,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.rankPill,
	})

	local rankBarBack = Util.new("Frame", {
		Position = UDim2.new(0, 12, 1, -14),
		Size = UDim2.new(1, -24, 0, 8),
		BackgroundColor3 = Color3.fromRGB(28, 28, 28),
		BorderSizePixel = 0,
		Parent = self.rankPill,
	})
	Util.corner(Theme.Radius.pill, rankBarBack)

	self.rankBar = Util.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Color.accent,
		BorderSizePixel = 0,
		Parent = rankBarBack,
	})
	Util.corner(Theme.Radius.pill, self.rankBar)

	-- Open button
	self.openButton = Util.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.new(0, 230, 0, 62),
		BackgroundColor3 = Theme.Color.accent,
		Text = "📊  CHECK MY STATS",
		TextSize = 21,
		Parent = self.hud,
	})
	Util.corner(Theme.Radius.card, self.openButton)
	Util.onClick(self.openButton, 0.2, function()
		self:setOpen(true)
	end)

	-- Daily reward button
	self.dailyButton = Util.button({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 256, 1, -16),
		Size = UDim2.new(0, 170, 0, 62),
		BackgroundColor3 = Theme.Color.coin,
		Text = "🎁 DAILY",
		TextColor3 = Color3.fromRGB(30, 30, 30),
		TextSize = 19,
		Parent = self.hud,
	})
	Util.corner(Theme.Radius.card, self.dailyButton)
	Util.onClick(self.dailyButton, 1, function()
		self.callbacks.claimDaily()
	end)
end

-- Modal ------------------------------------------------------------------

function App:buildModal()
	self.backdrop = Util.new("TextButton", {
		Name = "Backdrop",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.backdrop,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = self.gui,
	})
	Util.onClick(self.backdrop, 0.1, function()
		self:setOpen(false)
	end)

	self.modal = Util.new("Frame", {
		Name = "Modal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundColor3 = Theme.Color.panel,
		BorderSizePixel = 0,
		Visible = false,
		Parent = self.gui,
	})
	Util.corner(Theme.Radius.panel, self.modal)
	Util.stroke(Color3.fromRGB(20, 20, 20), 3, self.modal)
	Util.padding(Theme.Padding.panel, self.modal)

	-- Scale down on small screens instead of overflowing.
	local scale = Util.new("UIScale", { Parent = self.modal })
	local function fit()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.min(1, (viewport.X - 40) / PANEL_SIZE.X, (viewport.Y - 40) / PANEL_SIZE.Y)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- Header
	self.title = Util.new("TextLabel", {
		Size = UDim2.new(1, -60, 0, 54),
		BackgroundTransparency = 1,
		Font = Theme.Font.title,
		Text = "Click what stats you want to check",
		TextColor3 = Theme.Color.text,
		TextSize = 44,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		Parent = self.modal,
	})

	local close = Util.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 46, 0, 46),
		BackgroundColor3 = Theme.Color.bad,
		Text = "✕",
		TextSize = 26,
		Parent = self.modal,
	})
	Util.corner(Theme.Radius.card, close)
	Util.onClick(close, 0.1, function()
		self:setOpen(false)
	end)

	-- Status strip
	self.status = Util.new("TextLabel", {
		Position = UDim2.new(0, 2, 0, 56),
		Size = UDim2.new(1, -4, 0, 24),
		BackgroundTransparency = 1,
		Font = Theme.Font.body,
		Text = "",
		TextColor3 = Theme.Color.subtext,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.modal,
	})

	-- Nav rail
	local nav = Util.new("Frame", {
		Position = UDim2.new(0, 0, 0, 86),
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Parent = self.modal,
	})
	Util.listLayout(6, nav, Enum.FillDirection.Horizontal)

	self.navButtons = {}

	local function navButton(id: string, text: string, color: Color3)
		local button = Util.button({
			Size = UDim2.new(0, 116, 0, 32),
			BackgroundColor3 = Theme.Color.card,
			Text = text,
			TextSize = 14,
			Parent = nav,
		})
		Util.corner(Theme.Radius.pill, button)
		Util.onClick(button, 0.1, function()
			self:setView(id)
		end)
		self.navButtons[id] = { button = button, color = color }
		return button
	end

	navButton("stats", "⭐ All Stats", Theme.Color.accent)
	for _, category in ipairs(StatConfig.Categories) do
		navButton("cat:" .. category.id, category.icon .. " " .. category.name, Theme.Color.accent)
	end
	navButton("shop", "⚡ Shop", Theme.Color.coin)
	navButton("boards", "🏅 Boards", Theme.Color.good)
	navButton("achievements", "🏆 Awards", Theme.Color.warn)
	navButton("rebirth", "🌟 Rebirth", Theme.Color.coin)

	-- Content host
	self.content = Util.new("Frame", {
		Position = UDim2.new(0, 0, 0, 132),
		Size = UDim2.new(1, 0, 1, -178),
		BackgroundTransparency = 1,
		Parent = self.modal,
	})

	self.statList = Util.new("ScrollingFrame", {
		Name = "StatList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = self.content,
	})
	Util.listLayout(Theme.Padding.gap, self.statList)
	Util.padding(4, self.statList)

	self.shopPanel = ShopPanel.new(self.content, self.callbacks)
	self.boardPanel = BoardPanel.new(self.content)
	self.achievementPanel = AchievementPanel.new(self.content)
	self.rebirthPanel = RebirthPanel.new(self.content, self.callbacks)

	-- Footer
	local footer = Util.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = self.modal,
	})
	Util.listLayout(8, footer, Enum.FillDirection.Horizontal)

	self.scanAllButton = Util.button({
		Size = UDim2.new(0, 190, 0, 36),
		BackgroundColor3 = Theme.Color.good,
		Text = "▶ SCAN EVERYTHING",
		TextColor3 = Color3.fromRGB(25, 25, 25),
		TextSize = 16,
		Parent = footer,
	})
	Util.corner(Theme.Radius.card, self.scanAllButton)
	Util.onClick(self.scanAllButton, 0.5, function()
		self.callbacks.scanAll()
	end)

	self.autoButton = Util.button({
		Size = UDim2.new(0, 180, 0, 36),
		BackgroundColor3 = Theme.Color.card,
		Text = "🤖 AUTO SCAN: OFF",
		TextSize = 15,
		Parent = footer,
	})
	Util.corner(Theme.Radius.card, self.autoButton)
	Util.onClick(self.autoButton, 0.5, function()
		local state = Store.get()
		self.callbacks.setAutoScan(not (state and state.autoScan))
	end)

	self.resetButton = Util.button({
		Size = UDim2.new(0, 150, 0, 36),
		BackgroundColor3 = Theme.Color.card,
		Text = "🔄 RESET SCANS",
		TextSize = 15,
		Parent = footer,
	})
	Util.corner(Theme.Radius.card, self.resetButton)
	Util.onClick(self.resetButton, 1, function()
		self.callbacks.resetScans()
	end)

	self.progressLabel = Util.new("TextLabel", {
		Size = UDim2.new(0, 300, 0, 36),
		BackgroundTransparency = 1,
		Font = Theme.Font.bold,
		Text = "",
		TextColor3 = Theme.Color.subtext,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footer,
	})

	-- Cards
	for index, stat in ipairs(StatConfig.Stats) do
		local card = StatCard.new(stat, self.callbacks, index)
		card.root.Parent = self.statList
		self.cards[stat.id] = card
	end
end

-- View switching ---------------------------------------------------------

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
		entry.button.BackgroundColor3 = id == view and entry.color or Theme.Color.card
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

function App:setOpen(open: boolean)
	self.modal.Visible = open
	self.backdrop.Visible = open
	self.hud.Visible = not open

	if open then
		self.modal.Size = UDim2.fromOffset(PANEL_SIZE.X * 0.9, PANEL_SIZE.Y * 0.9)
		Util.tween(self.modal, 0.16, { Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y) }, Enum.EasingStyle.Back)
		self:setView(self.view)
	end
end

-- Updates ----------------------------------------------------------------

function App:update(state)
	if not state then
		return
	end

	self.coinLabel.Text = "🪙 " .. Format.comma(state.coins)

	local rank = state.rank or { name = "?", icon = "" }
	self.rankLabel.Text = ("%s %s  •  %d pts"):format(rank.icon, rank.name, state.score or 0)
	self.rankBar.Size = UDim2.fromScale(state.rankProgress or 0, 1)
	if rank.color then
		self.rankLabel.TextColor3 = rank.color
	end

	local scannedCount = 0
	for _ in pairs(state.scanned) do
		scannedCount += 1
	end

	self.status.Text = ("%.2fx speed  •  %.2fx coins  •  %d scan slot(s)  •  %d/%d stats found%s"):format(
		state.speed or 1,
		state.coinMultiplier or 1,
		state.slots or 1,
		scannedCount,
		StatConfig.Count,
		state.rebirths > 0 and ("  •  " .. state.rebirths .. " rebirths") or ""
	)

	self.progressLabel.Text = ("%d / %d scanned"):format(scannedCount, StatConfig.Count)

	self.autoButton.Text = state.autoScan and "🤖 AUTO SCAN: ON" or "🤖 AUTO SCAN: OFF"
	self.autoButton.BackgroundColor3 = state.autoScan and Theme.Color.good or Theme.Color.card

	local daily = state.daily
	if daily then
		self.dailyButton.Text = daily.canClaim and ("🎁 DAILY +" .. Format.comma(daily.reward))
			or ("🎁 " .. Format.clock(daily.secondsUntilNext))
		self.dailyButton.BackgroundColor3 = daily.canClaim and Theme.Color.coin or Theme.Color.locked
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

--- Pops the card and shows the reveal toast when a scan lands.
function App:onScanFinished(payload)
	local card = self.cards[payload.statId]
	if not card then
		return
	end

	local stat = card.stat
	self.toasts:push({
		text = ("%s: %s   (+%s coins)"):format(
			stat.name,
			Format.value(stat.format, payload.value),
			Format.comma(payload.coins)
		),
		icon = stat.icon,
		color = stat.color,
	})

	local base = card.root.Size
	card.root.Size = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset + 10)
	Util.tween(card.root, 0.2, { Size = base }, Enum.EasingStyle.Back)
end

return App
