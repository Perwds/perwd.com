--!strict
--[[
	BoardPanel -- the leaderboards, rendered as a CRT readout.

	This is the one place the interface goes dark: a bezelled screen with
	scanlines and monospace rows, mounted in the chassis. The tab rail above it
	is a bank of recessed switches.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Bevel = require(script.Parent.Bevel)

local BoardPanel = {}
BoardPanel.__index = BoardPanel

local ROWS = 25

function BoardPanel.new(parent: Instance)
	local self = setmetatable({}, BoardPanel)

	self.root = Util.new("Frame", {
		Name = "BoardPanel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})

	self.tabs = Util.new("Frame", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Parent = self.root,
	})
	Util.listLayout(Theme.Space.tight, self.tabs, Enum.FillDirection.Horizontal)

	-- Screen bezel: recessed housing for the display.
	self.bezel = Util.well({
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -42),
		radius = Theme.Radius.lg,
		Parent = self.root,
	})

	self.screen = Util.new("Frame", {
		Name = "Screen",
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -16),
		BackgroundColor3 = Theme.Color.dark,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = self.bezel,
	})
	Util.corner(Theme.Radius.md, self.screen)

	Bevel.led(self.screen, Theme.Color.ledGreen, "live feed", UDim2.new(1, -150, 0, 10))

	self.list = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(10, 32),
		Size = UDim2.new(1, -20, 1, -42),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = Theme.Color.darkTextMuted,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 4,
		Parent = self.screen,
	})
	Util.listLayout(2, self.list)

	-- Scanlines sit above the rows but below nothing else.
	Bevel.scanlines(self.screen, 520, 4)

	self.empty = Util.text({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 0, 60),
		Font = Theme.Font.mono,
		Text = "NO DATA -- SCAN A MODULE TO REGISTER",
		TextColor3 = Theme.Color.darkTextMuted,
		TextSize = 14,
		ZIndex = 5,
		Parent = self.screen,
	})

	self.selected = nil
	self.tabButtons = {}
	self.snapshot = {}

	return self
end

function BoardPanel:buildTabs(snapshot)
	for _, button in pairs(self.tabButtons) do
		button:Destroy()
	end
	self.tabButtons = {}

	for _, board in ipairs(snapshot) do
		local button = Util.button({
			variant = "slot",
			radius = Theme.Radius.sm,
			Size = UDim2.fromOffset(148, 32),
			Text = board.name:upper(),
			TextSize = 12,
			Parent = self.tabs,
		})

		Util.onClick(button, 0.1, function()
			self.selected = board.key
			self:render()
		end)

		self.tabButtons[board.key] = button
	end
end

function BoardPanel:render()
	for _, child in ipairs(self.list:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	local board
	for _, candidate in ipairs(self.snapshot) do
		if candidate.key == self.selected then
			board = candidate
		end
		local button = self.tabButtons[candidate.key]
		if button then
			local selected = candidate.key == self.selected
			button.BackgroundColor3 = selected and Theme.Color.accent or Theme.Color.recess
			button.TextColor3 = selected and Theme.Color.accentText or Theme.Color.textMuted
		end
	end

	if not board then
		self.empty.Visible = true
		return
	end

	self.empty.Visible = #board.rows == 0
	if #board.rows == 0 then
		self.empty.Text = ("NO ENTRIES FOR %s"):format(board.name:upper())
	end

	for index = 1, math.min(ROWS, #board.rows) do
		local entry = board.rows[index]
		local isMe = entry.userId == Players.LocalPlayer.UserId

		local row = Util.new("Frame", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = isMe and Theme.Color.accent or Theme.Color.darkSlate,
			BackgroundTransparency = isMe and 0.15 or (index % 2 == 0 and 0.55 or 0.35),
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = self.list,
		})
		Util.corner(Theme.Radius.sm, row)
		Util.new("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			Parent = row,
		})

		Util.text({
			Size = UDim2.fromOffset(44, 34),
			Font = Theme.Font.mono,
			Text = ("%02d"):format(index),
			TextColor3 = index <= 3 and Theme.Color.accent or Theme.Color.darkTextMuted,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		Util.text({
			Position = UDim2.fromOffset(50, 0),
			Size = UDim2.new(1, -230, 1, 0),
			Text = isMe and (entry.name .. "  <YOU>") or entry.name,
			TextColor3 = Theme.Color.darkText,
			TextSize = 15,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		Util.text({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(176, 34),
			Font = Theme.Font.mono,
			Text = Format.value(board.format, entry.value),
			TextColor3 = index <= 3 and Theme.Color.accent or Theme.Color.darkText,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
	end
end

function BoardPanel:update(snapshot)
	self.snapshot = snapshot or {}
	if #self.snapshot == 0 then
		self.empty.Visible = true
		return
	end

	self:buildTabs(self.snapshot)
	if not self.selected or not self.tabButtons[self.selected] then
		self.selected = self.snapshot[1].key
	end
	self:render()
end

function BoardPanel:setVisible(visible: boolean)
	self.root.Visible = visible
end

return BoardPanel
