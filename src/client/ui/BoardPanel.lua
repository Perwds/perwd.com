--!strict
--[[ BoardPanel -- global leaderboards. ]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local BoardPanel = {}
BoardPanel.__index = BoardPanel

local ROWS = 25
local MEDALS = { Theme.Color.gold, Color3.fromRGB(205, 212, 228), Color3.fromRGB(214, 140, 84) }

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
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = self.root,
	})
	Util.listLayout(Theme.Space.tight, self.tabs, Enum.FillDirection.Horizontal)

	self.list = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 7,
		ScrollBarImageColor3 = Theme.Color.purple,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 6,
		Parent = self.root,
	})
	Util.listLayout(Theme.Space.tight, self.list)
	Util.new("UIPadding", { PaddingRight = UDim.new(0, 12), Parent = self.list })

	self.empty = Util.title({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -40, 0, 60),
		Text = "nobody here yet — go scan something",
		TextColor3 = Theme.Color.inkMuted,
		TextSize = 22,
		ZIndex = 7,
		Parent = self.root,
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
			variant = "dark",
			radius = Theme.Radius.full,
			Size = UDim2.fromOffset(156, 34),
			Text = (board.icon .. " " .. board.name):upper(),
			TextSize = 13,
			lip = Theme.Lip.small,
			sound = "tab",
			ZIndex = 6,
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
			button.BackgroundColor3 = selected and Theme.Color.cyan or Theme.Color.slot
			button.TextColor3 = selected and Theme.inkOn(Theme.Color.cyan) or Theme.Color.inkMuted
			local lip = button:FindFirstChild("Lip") :: Frame?
			if lip then
				lip.BackgroundColor3 = Theme.shade(button.BackgroundColor3, -0.32)
			end
		end
	end

	if not board then
		self.empty.Visible = true
		return
	end

	self.empty.Visible = #board.rows == 0
	if #board.rows == 0 then
		self.empty.Text = ("no one has scanned %s yet — be first"):format(board.name:lower())
	end

	for index = 1, math.min(ROWS, #board.rows) do
		local entry = board.rows[index]
		local isMe = entry.userId == Players.LocalPlayer.UserId
		local fill = MEDALS[index] or (isMe and Theme.Color.purple or Theme.Color.panelLite)

		local row = Util.card({
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundColor3 = fill,
			radius = Theme.Radius.md,
			lip = Theme.Lip.small,
			LayoutOrder = index,
			ZIndex = 6,
			Parent = self.list,
		})

		local ink = Theme.inkOn(fill)

		Util.title({
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.fromOffset(60, 46),
			Text = "#" .. index,
			TextSize = 22,
			TextColor3 = ink,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
			Parent = row,
		})

		Util.title({
			Position = UDim2.fromOffset(80, 0),
			Size = UDim2.new(1, -300, 0, 46),
			Text = isMe and (entry.name .. "  (you)") or entry.name,
			TextSize = 20,
			TextColor3 = ink,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
			Parent = row,
		})

		Util.title({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -16, 0, 0),
			Size = UDim2.fromOffset(210, 46),
			Text = Format.value(board.format, entry.value),
			TextSize = 20,
			TextColor3 = ink,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 7,
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
