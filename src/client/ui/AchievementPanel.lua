--!strict
--[[
	AchievementPanel -- the objective checklist. Each row is a module with a
	status LED: green once claimed, amber while outstanding.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AchievementConfig = require(Shared.AchievementConfig)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Bevel = require(script.Parent.Bevel)

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

	self.header = Util.stamp({
		Size = UDim2.new(1, 0, 0, 16),
		Text = "objectives",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.root,
	})

	local scroll = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 1, -24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.shadowDeep,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = self.root,
	})
	Util.listLayout(Theme.Space.gap, scroll)
	Util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = scroll,
	})

	for index, entry in ipairs(AchievementConfig.List) do
		local card = Util.panel({
			Size = UDim2.new(1, 0, 0, 68),
			LayoutOrder = index,
			Parent = scroll,
		})
		Util.padding(12, card)

		local housing = Util.iconHousing(card, entry.icon, 40, Theme.Color.accent)
		housing.Position = UDim2.fromOffset(0, 2)

		local name = Util.text({
			Position = UDim2.fromOffset(52, 0),
			Size = UDim2.new(1, -52 - 190, 0, 22),
			Font = Theme.Font.bold,
			Text = entry.name:upper(),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		Util.text({
			Position = UDim2.fromOffset(52, 22),
			Size = UDim2.new(1, -52 - 190, 0, 20),
			Text = entry.blurb,
			TextColor3 = Theme.Color.textMuted,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		local led = Bevel.led(card, Theme.Color.shadowDeep, nil, UDim2.new(1, -172, 0, 15))

		local status = Util.text({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(140, 44),
			Font = Theme.Font.mono,
			Text = "",
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = card,
		})

		self.rows[entry.id] = { card = card, status = status, name = name, led = led, entry = entry }
	end

	return self
end

function AchievementPanel:update(state)
	local done = 0

	for id, row in pairs(self.rows) do
		local earned = state.achievements and state.achievements[id]
		local diode = row.led:FindFirstChild("Diode")
		local bloom = row.led:FindFirstChild("Bloom")
		local color = earned and Theme.Color.ledGreen or Theme.Color.ledAmber

		if diode then
			(diode :: Frame).BackgroundColor3 = color
		end
		if bloom then
			(bloom :: Frame).BackgroundColor3 = color
		end

		if earned then
			done += 1
			row.status.Text = "CLAIMED"
			row.status.TextColor3 = Theme.Color.textMuted
			row.name.TextColor3 = Theme.Color.textMuted
			-- A completed objective sinks into the chassis.
			Bevel.invert(row.card, true)
		else
			row.status.Text = "+" .. Format.comma(row.entry.reward)
			row.status.TextColor3 = Theme.Color.accent
			row.name.TextColor3 = Theme.Color.text
			Bevel.invert(row.card, false)
		end
	end

	self.header.Text = Theme.stamp(("objectives %d of %d"):format(done, #AchievementConfig.List))
end

function AchievementPanel:setVisible(visible: boolean)
	self.root.Visible = visible
end

return AchievementPanel
