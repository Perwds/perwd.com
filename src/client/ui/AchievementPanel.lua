--!strict
--[[ AchievementPanel -- quests and their coin payouts. ]]

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

	self.header = Util.title({
		Size = UDim2.new(1, 0, 0, 28),
		Text = "QUESTS",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = self.root,
	})

	local scroll = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 7,
		ScrollBarImageColor3 = Theme.Color.purple,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 6,
		Parent = self.root,
	})
	Util.listLayout(Theme.Space.gap, scroll)
	Util.new("UIPadding", { PaddingRight = UDim.new(0, 12), PaddingBottom = UDim.new(0, 10), Parent = scroll })

	for index, entry in ipairs(AchievementConfig.List) do
		local card = Util.card({
			Size = UDim2.new(1, 0, 0, 76),
			BackgroundColor3 = Theme.Color.panelLite,
			radius = Theme.Radius.md,
			lip = Theme.Lip.base,
			LayoutOrder = index,
			ZIndex = 6,
			Parent = scroll,
		})

		local badge = Util.badge(card, entry.icon, 46, Theme.Color.purple)
		badge.Position = UDim2.fromOffset(12, 13)

		local name = Util.title({
			Position = UDim2.fromOffset(72, 12),
			Size = UDim2.new(1, -72 - 180, 0, 24),
			Text = entry.name:upper(),
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
			Parent = card,
		})

		Util.text({
			Position = UDim2.fromOffset(72, 36),
			Size = UDim2.new(1, -72 - 180, 0, 22),
			Font = Theme.Font.small,
			Text = entry.blurb,
			TextColor3 = Theme.Color.inkMuted,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
			Parent = card,
		})

		local status = Util.title({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -16, 0.5, -3),
			Size = UDim2.fromOffset(160, 40),
			Text = "",
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 7,
			Parent = card,
		})

		self.rows[entry.id] = { card = card, status = status, name = name, badge = badge, entry = entry }
	end

	return self
end

function AchievementPanel:update(state)
	local done = 0

	for id, row in pairs(self.rows) do
		local earned = state.achievements and state.achievements[id]
		local fill = earned and Theme.Color.green or Theme.Color.panelLite

		row.card.BackgroundColor3 = fill
		local lip = row.card:FindFirstChild("Lip") :: Frame?
		if lip then
			lip.BackgroundColor3 = Theme.shade(fill, -0.32)
		end

		local ink = Theme.inkOn(fill)
		row.name.TextColor3 = ink

		if earned then
			done += 1
			row.status.Text = "DONE"
			row.status.TextColor3 = ink
		else
			row.status.Text = "+" .. Format.comma(row.entry.reward)
			row.status.TextColor3 = Theme.Color.gold
		end
	end

	self.header.Text = ("QUESTS   %d / %d"):format(done, #AchievementConfig.List)
end

function AchievementPanel:setVisible(visible: boolean)
	self.root.Visible = visible
end

return AchievementPanel
