--!strict
--[[ RebirthPanel -- requirements, rewards and the big button. ]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local StatConfig = require(Shared.StatConfig)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local RebirthPanel = {}
RebirthPanel.__index = RebirthPanel

function RebirthPanel.new(parent: Instance, callbacks)
	local self = setmetatable({}, RebirthPanel)

	self.root = Util.new("Frame", {
		Name = "RebirthPanel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})

	local card = Util.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(0, 560, 0, 380),
		BackgroundColor3 = Theme.Color.card,
		BorderSizePixel = 0,
		Parent = self.root,
	})
	Util.corner(Theme.Radius.panel, card)
	Util.padding(20, card)
	Util.stroke(Theme.Color.coin, 2, card)

	Util.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Font = Theme.Font.title,
		Text = "🌟 REBIRTH",
		TextColor3 = Theme.Color.coin,
		TextSize = 34,
		Parent = card,
	})

	self.current = Util.new("TextLabel", {
		Position = UDim2.new(0, 0, 0, 44),
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		Font = Theme.Font.bold,
		Text = "",
		TextColor3 = Theme.Color.text,
		TextSize = 20,
		Parent = card,
	})

	self.body = Util.new("TextLabel", {
		Position = UDim2.new(0, 0, 0, 78),
		Size = UDim2.new(1, 0, 0, 180),
		BackgroundTransparency = 1,
		Font = Theme.Font.body,
		Text = "",
		TextColor3 = Theme.Color.subtext,
		TextSize = 17,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = card,
	})

	self.button = Util.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0, 300, 0, 56),
		BackgroundColor3 = Theme.Color.coin,
		Text = "REBIRTH",
		TextColor3 = Color3.fromRGB(30, 30, 30),
		TextSize = 24,
		Parent = card,
	})
	Util.corner(Theme.Radius.card, self.button)

	Util.onClick(self.button, 1, function()
		callbacks.rebirth()
	end)

	return self
end

function RebirthPanel:update(state)
	local info = state.rebirth
	if not info then
		return
	end

	self.current.Text = ("Rebirths: %d   %s"):format(
		state.rebirths,
		state.rebirthTitle ~= "" and ("(" .. state.rebirthTitle .. ")") or ""
	)

	self.body.Text = table.concat({
		("Progress: %d / %d stats scanned  (of %d total)"):format(
			info.scannedCount,
			info.requirement,
			StatConfig.Count
		),
		("Cost: %s coins  (you have %s)"):format(Format.comma(info.cost), Format.comma(state.coins)),
		"",
		"Rebirthing clears your scan progress but KEEPS your coins,",
		"achievements and every value you have already discovered.",
		"",
		("Next rebirth gives you a permanent %.2fx scan speed"):format(info.nextSpeed),
		("and %.2fx coin multiplier, and unlocks rebirth-gated stats."):format(info.nextCoins),
	}, "\n")

	local blocked = info.blocker ~= nil
	self.button.Text = blocked and (info.blocker :: string) or "REBIRTH NOW"
	self.button.BackgroundColor3 = blocked and Theme.Color.locked or Theme.Color.coin
	self.button.TextSize = blocked and 16 or 24
end

function RebirthPanel:setVisible(visible: boolean)
	self.root.Visible = visible
end

return RebirthPanel
