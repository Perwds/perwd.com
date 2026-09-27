--!strict
--[[ BoardPanel -- global leaderboards, one column per board. ]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

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
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = self.root,
	})
	local tabLayout = Util.listLayout(8, self.tabs, Enum.FillDirection.Horizontal)
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left

	self.list = Util.new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 48),
		Size = UDim2.new(1, 0, 1, -48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = self.root,
	})
	Util.listLayout(4, self.list)

	self.empty = Util.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
		Font = Theme.Font.body,
		Text = "Leaderboards are still warming up. Scan some stats!",
		TextColor3 = Theme.Color.muted,
		TextSize = 18,
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
			Size = UDim2.new(0, 152, 0, 34),
			BackgroundColor3 = Theme.Color.card,
			Text = board.icon .. " " .. board.name,
			TextSize = 15,
			Parent = self.tabs,
		})
		Util.corner(Theme.Radius.pill, button)

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
			button.BackgroundColor3 = candidate.key == self.selected and Theme.Color.accent or Theme.Color.card
		end
	end

	if not board then
		self.empty.Visible = true
		return
	end

	self.empty.Visible = #board.rows == 0

	local localName = Players.LocalPlayer.DisplayName

	for index = 1, math.min(ROWS, #board.rows) do
		local entry = board.rows[index]
		local isMe = entry.userId == Players.LocalPlayer.UserId

		local row = Util.new("Frame", {
			Size = UDim2.new(1, -8, 0, 40),
			BackgroundColor3 = isMe and Theme.shade(Theme.Color.accent, -0.35) or Theme.Color.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = self.list,
		})
		Util.corner(Theme.Radius.card, row)
		Util.padding(8, row)

		local medal = index == 1 and "🥇" or (index == 2 and "🥈" or (index == 3 and "🥉" or ("#" .. index)))

		Util.new("TextLabel", {
			Size = UDim2.new(0, 46, 1, 0),
			BackgroundTransparency = 1,
			Font = Theme.Font.bold,
			Text = medal,
			TextColor3 = index <= 3 and Theme.Color.coin or Theme.Color.subtext,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		Util.new("TextLabel", {
			Position = UDim2.new(0, 52, 0, 0),
			Size = UDim2.new(1, -220, 1, 0),
			BackgroundTransparency = 1,
			Font = Theme.Font.body,
			Text = isMe and (entry.name .. "  (you)") or entry.name,
			TextColor3 = Theme.Color.text,
			TextSize = 17,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})

		Util.new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 160, 1, 0),
			BackgroundTransparency = 1,
			Font = Theme.Font.bold,
			Text = Format.value(board.format, entry.value),
			TextColor3 = Theme.Color.coin,
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
	end

	if #board.rows == 0 then
		self.empty.Text = ("No one has scanned %s yet. Be first, %s!"):format(board.name, localName)
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
