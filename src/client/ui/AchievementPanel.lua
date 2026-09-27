--!strict
--[[ AchievementPanel -- checklist of bonus objectives and their payouts. ]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AchievementConfig = require(Shared.AchievementConfig)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local AchievementPanel = {}
AchievementPanel.__index = AchievementPanel

function AchievementPanel.new(parent: Instance)
	local self = setmetatable({}, AchievementPanel)

	self.rows = {}

	self.root = Util.new("Frame", {
		Name = "AchievementPanel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})

	self.header = Util.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Font = Theme.Font.heading,
		Text = "🏆 Achievements",
		TextColor3 = Theme.Color.text,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.root,
	})

	local scroll = Util.new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = self.root,
	})
	Util.listLayout(8, scroll)

	for index, entry in ipairs(AchievementConfig.List) do
		local card = Util.new("Frame", {
			Size = UDim2.new(1, -8, 0, 64),
			BackgroundColor3 = Theme.Color.card,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = scroll,
		})
		Util.corner(Theme.Radius.card, card)
		Util.padding(10, card)

		Util.new("TextLabel", {
			Size = UDim2.new(0, 40, 1, 0),
			BackgroundTransparency = 1,
			Font = Theme.Font.body,
			Text = entry.icon,
			TextSize = 26,
			Parent = card,
		})

		local name = Util.new("TextLabel", {
			Position = UDim2.new(0, 46, 0, 0),
			Size = UDim2.new(1, -200, 0, 24),
			BackgroundTransparency = 1,
			Font = Theme.Font.bold,
			Text = entry.name,
			TextColor3 = Theme.Color.text,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		Util.new("TextLabel", {
			Position = UDim2.new(0, 46, 0, 24),
			Size = UDim2.new(1, -200, 0, 20),
			BackgroundTransparency = 1,
			Font = Theme.Font.body,
			Text = entry.blurb,
			TextColor3 = Theme.Color.subtext,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		local status = Util.new("TextLabel", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 150, 1, 0),
			BackgroundTransparency = 1,
			Font = Theme.Font.bold,
			Text = "",
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = card,
		})

		self.rows[entry.id] = { card = card, status = status, name = name, entry = entry }
	end

	return self
end

function AchievementPanel:update(state)
	local done = 0

	for id, row in pairs(self.rows) do
		local earned = state.achievements and state.achievements[id]
		if earned then
			done += 1
			row.status.Text = "✓ CLAIMED"
			row.status.TextColor3 = Theme.Color.good
			row.card.BackgroundColor3 = Theme.shade(Theme.Color.good, -0.65)
		else
			row.status.Text = "+" .. Format.comma(row.entry.reward) .. " 🪙"
			row.status.TextColor3 = Theme.Color.coin
			row.card.BackgroundColor3 = Theme.Color.card
		end
	end

	self.header.Text = ("🏆 Achievements   (%d / %d)"):format(done, #AchievementConfig.List)
end

function AchievementPanel:setVisible(visible: boolean)
	self.root.Visible = visible
end

return AchievementPanel
