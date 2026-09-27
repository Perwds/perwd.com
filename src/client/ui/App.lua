--!strict
--[[
	App -- the console.

	Assembles the HUD and the scanner chassis: header, the two nav rails, the
	stat rack and the four side panels.

	Layout note: the nav used to be one row of eleven keys, which overflowed
	the chassis. It is now split into a category rail and a section rail, which
	both fits and reads as two banks of switches.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local StatConfig = require(Shared.StatConfig)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Bevel = require(script.Parent.Bevel)
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
local CONTENT_TOP = 198
local FOOTER_HEIGHT = 44

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

--- A small mounted read-out: stamped label above a monospace value.
local function readout(parent: Instance, position: UDim2, width: number, label: string)
	local module = Util.panel({
		Position = position,
		Size = UDim2.fromOffset(width, 56),
		Parent = parent,
	})

	Util.stamp({
		Position = UDim2.fromOffset(14, 7),
		Size = UDim2.new(1, -28, 0, 12),
		Text = label,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = module,
	})

	local value = Util.text({
		Position = UDim2.fromOffset(14, 20),
		Size = UDim2.new(1, -28, 0, 26),
		Font = Theme.Font.mono,
		Text = "--",
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = module,
	})

	return module, value
end

function App:buildHud()
	self.hud = Util.new("Frame", {
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = self.gui,
	})

	local _, coinValue = readout(self.hud, UDim2.fromOffset(16, 16), 196, "credits")
	self.coinLabel = coinValue

	local rankModule, rankValue = readout(self.hud, UDim2.fromOffset(222, 16), 268, "operator rank")
	self.rankLabel = rankValue
	self.rankLabel.TextSize = 17

	-- Rank progress rides in a machined track along the bottom of the module.
	local track = Util.well({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -7),
		Size = UDim2.new(1, -28, 0, 6),
		radius = Theme.Radius.full,
		Parent = rankModule,
	})

	self.rankBar = Util.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Color.accent,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track,
	})
	Util.corner(Theme.Radius.full, self.rankBar)

	Bevel.led(self.hud, Theme.Color.ledGreen, "system operational", UDim2.fromOffset(500, 36))

	self.openButton = Util.button({
		variant = "primary",
		radius = Theme.Radius.lg,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -16),
		Size = UDim2.fromOffset(248, 62),
		Text = "OPEN SCANNER",
		TextSize = 18,
		Parent = self.hud,
	})

	self.dailyButton = Util.button({
		variant = "secondary",
		radius = Theme.Radius.lg,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 276, 1, -16),
		Size = UDim2.fromOffset(190, 62),
		Text = "DAILY",
		TextSize = 16,
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
		BackgroundColor3 = Theme.Color.dark,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Visible = false,
		Parent = self.gui,
	})
	Util.onClick(self.backdrop, 0.1, function()
		self:setOpen(false)
	end)

	-- The shell exists so the chassis and its cast shadow are siblings that
	-- move as one. A Roblox child always draws in front of its parent's
	-- background, so a cast shadow cannot live inside the panel it falls from.
	self.shell = Util.new("Frame", {
		Name = "Shell",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Visible = false,
		Parent = self.gui,
	})

	self.modal = Util.new("Frame", {
		Name = "Modal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PANEL_SIZE.X, PANEL_SIZE.Y),
		BackgroundColor3 = Theme.Color.chassis,
		BorderSizePixel = 0,
		ZIndex = 5,
		Visible = false,
		Parent = self.shell,
	})
	Bevel.panel(self.modal, "floating", Theme.Radius.xl)
	Bevel.screws(self.modal, 12, Theme.Space.panel)
	Bevel.vents(self.modal, 4, UDim2.new(1, -64, 0, 6))
	Bevel.cast(self.modal, 14)
	Util.padding(Theme.Space.panel, self.modal)

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
	self.title = Util.text({
		Size = UDim2.new(1, -70, 0, 50),
		Font = Theme.Font.display,
		Text = "STAT SCANNER",
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.modal,
	})

	Util.stamp({
		Position = UDim2.fromOffset(2, 52),
		Size = UDim2.new(0, 460, 0, 14),
		Text = "select a module to begin analysis",
		Parent = self.modal,
	})

	Bevel.led(self.modal, Theme.Color.ledGreen, "online", UDim2.new(1, -240, 0, 52))

	local close = Util.button({
		variant = "primary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(Theme.TOUCH, Theme.TOUCH),
		Text = "X",
		TextSize = 20,
		Parent = self.modal,
	})
	Util.onClick(close, 0.1, function()
		self:setOpen(false)
	end)

	-- Status strip: a recessed data well, monospace throughout.
	local strip = Util.well({
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = self.modal,
	})

	self.status = Util.text({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Font = Theme.Font.mono,
		Text = "",
		TextColor3 = Theme.Color.textMuted,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = strip,
	})

	-- Two banks of switches.
	self.navButtons = {}

	local function rail(y: number)
		local holder = Util.new("Frame", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			Parent = self.modal,
		})
		Util.listLayout(Theme.Space.tight, holder, Enum.FillDirection.Horizontal)
		return holder
	end

	local categoryRail = rail(120)
	local sectionRail = rail(158)

	local function navButton(parent: Instance, id: string, text: string, width: number)
		local button = Util.button({
			variant = "slot",
			radius = Theme.Radius.sm,
			Size = UDim2.fromOffset(width, 32),
			Text = text,
			TextSize = 12,
			Parent = parent,
		})
		Util.onClick(button, 0.1, function()
			self:setView(id)
		end)
		self.navButtons[id] = button
		return button
	end

	navButton(categoryRail, "stats", "ALL", 76)
	for _, category in ipairs(StatConfig.Categories) do
		navButton(categoryRail, "cat:" .. category.id, category.name:upper(), 122)
	end

	navButton(sectionRail, "shop", "SHOP", 150)
	navButton(sectionRail, "boards", "LEADERBOARDS", 180)
	navButton(sectionRail, "achievements", "AWARDS", 150)
	navButton(sectionRail, "rebirth", "REBIRTH", 150)

	-- Content host
	self.content = Util.new("Frame", {
		Position = UDim2.fromOffset(0, CONTENT_TOP),
		Size = UDim2.new(1, 0, 1, -CONTENT_TOP - FOOTER_HEIGHT - 8),
		BackgroundTransparency = 1,
		Parent = self.modal,
	})

	self.statList = Util.new("ScrollingFrame", {
		Name = "StatList",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.shadowDeep,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = self.content,
	})
	Util.listLayout(Theme.Space.gap, self.statList)
	Util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
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
		Size = UDim2.new(1, 0, 0, FOOTER_HEIGHT),
		BackgroundTransparency = 1,
		Parent = self.modal,
	})
	Util.listLayout(Theme.Space.tight, footer, Enum.FillDirection.Horizontal)

	self.scanAllButton = Util.button({
		variant = "primary",
		Size = UDim2.fromOffset(210, 40),
		Text = "SCAN EVERYTHING",
		TextSize = 14,
		Parent = footer,
	})
	Util.onClick(self.scanAllButton, 0.5, function()
		self.callbacks.scanAll()
	end)

	self.autoButton = Util.button({
		variant = "secondary",
		Size = UDim2.fromOffset(196, 40),
		Text = "AUTO SCAN / OFF",
		TextSize = 13,
		Parent = footer,
	})
	Util.onClick(self.autoButton, 0.5, function()
		local state = Store.get()
		self.callbacks.setAutoScan(not (state and state.autoScan))
	end)

	self.resetButton = Util.button({
		variant = "ghost",
		Size = UDim2.fromOffset(160, 40),
		Text = "RESET SCANS",
		TextSize = 13,
		Parent = footer,
	})
	Util.onClick(self.resetButton, 1, function()
		self.callbacks.resetScans()
	end)

	self.progressLabel = Util.text({
		Size = UDim2.fromOffset(280, 40),
		Font = Theme.Font.mono,
		Text = "",
		TextColor3 = Theme.Color.textMuted,
		TextSize = 14,
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

	-- The selected switch lights up; the rest stay recessed and unlit.
	for id, button in pairs(self.navButtons) do
		local selected = id == view
		button.BackgroundColor3 = selected and Theme.Color.accent or Theme.Color.recess
		button.TextColor3 = selected and Theme.Color.accentText or Theme.Color.textMuted
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

	self.shell.Visible = open

	if open then
		-- The whole shell slides up and settles with the mechanical overshoot,
		-- so the chassis and its shadow stay locked together.
		self.shell.Position = UDim2.fromOffset(0, 26)
		Util.tween(self.shell, Theme.Motion.settle, { Position = UDim2.new() }, Theme.Motion.mechanical)
		self:setView(view or self.view)
	end
end

-- Updates ----------------------------------------------------------------

function App:update(state)
	if not state then
		return
	end

	self.coinLabel.Text = Format.comma(state.coins)

	local rank = state.rank or { name = "?", icon = "" }
	self.rankLabel.Text = ("%s / %d"):format(rank.name:upper(), state.score or 0)
	self.rankBar.Size = UDim2.fromScale(state.rankProgress or 0, 1)

	local scannedCount = 0
	for _ in pairs(state.scanned) do
		scannedCount += 1
	end

	self.status.Text = ("SPD %.2fx   COIN %.2fx   SLOTS %d   MODULES %d/%d   REBIRTH %d"):format(
		state.speed or 1,
		state.coinMultiplier or 1,
		state.slots or 1,
		scannedCount,
		StatConfig.Count,
		state.rebirths or 0
	)

	self.progressLabel.Text = ("%d / %d LOGGED"):format(scannedCount, StatConfig.Count)

	local auto = state.autoScan == true
	self.autoButton.Text = auto and "AUTO SCAN / ON" or "AUTO SCAN / OFF"
	self.autoButton.BackgroundColor3 = auto and Theme.Color.accent or Theme.Color.chassis
	self.autoButton.TextColor3 = auto and Theme.Color.accentText or Theme.Color.text

	local daily = state.daily
	if daily then
		self.dailyButton.Text = daily.canClaim and ("DAILY / +" .. Format.comma(daily.reward))
			or ("DAILY / " .. Format.clock(daily.secondsUntilNext))
		self.dailyButton.BackgroundColor3 = daily.canClaim and Theme.Color.accent or Theme.Color.chassis
		self.dailyButton.TextColor3 = daily.canClaim and Theme.Color.accentText or Theme.Color.textMuted
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

--- The module clunks when a scan lands.
function App:onScanFinished(payload)
	local card = self.cards[payload.statId]
	if not card then
		return
	end

	local stat = card.stat
	self.toasts:push({
		text = ("%s  %s   +%s"):format(
			stat.name,
			Format.value(stat.format, payload.value),
			Format.comma(payload.coins)
		),
		icon = stat.icon,
		color = stat.color,
	})

	-- The stat rack is a UIListLayout, which owns each card's Position, so the
	-- clunk is expressed by briefly inverting the module's light instead.
	Bevel.invert(card.root, true)
	task.delay(0.12, function()
		if card.root.Parent then
			Bevel.invert(card.root, false)
		end
	end)
end

return App
