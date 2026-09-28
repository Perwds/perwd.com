--!strict
--[[ RebirthPanel -- the big reset. ]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local StatConfig = require(Shared.StatConfig)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local RebirthPanel = {}
RebirthPanel.__index = RebirthPanel

local function statBox(parent: Instance, position: UDim2, label: string, fill: Color3)
	local box = Util.card({
		Position = position,
		Size = UDim2.fromOffset(176, 92),
		BackgroundColor3 = fill,
		radius = Theme.Radius.md,
		lip = Theme.Lip.base,
		ZIndex = 7,
		Parent = parent,
	})

	local value = Util.title({
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 36),
		Text = "-",
		TextSize = 30,
		TextColor3 = Theme.inkOn(fill),
		ZIndex = 8,
		Parent = box,
	})

	Util.text({
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 20),
		Font = Theme.Font.small,
		Text = label,
		TextColor3 = Theme.inkOn(fill),
		TextTransparency = 0.2,
		TextSize = 13,
		ZIndex = 8,
		Parent = box,
	})

	return value
end

function RebirthPanel.new(parent: Instance, callbacks)
	local self = setmetatable({}, RebirthPanel)

	self.root = Util.new("Frame", {
		Name = "RebirthPanel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})

	local card = Util.card({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(640, 400),
		BackgroundColor3 = Theme.Color.purple,
		radius = Theme.Radius.xl,
		weight = Theme.Outline.chunky,
		lip = Theme.Lip.chunky,
		ZIndex = 6,
		Parent = self.root,
	})

	Util.title({
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 48),
		Text = "REBIRTH",
		TextSize = 44,
		ZIndex = 7,
		Parent = card,
	})

	self.current = Util.text({
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 22),
		Text = "",
		TextColor3 = Theme.Color.ink,
		TextSize = 16,
		ZIndex = 7,
		Parent = card,
	})

	self.scanned = statBox(card, UDim2.fromOffset(42, 100), "stats scanned", Theme.Color.cyan)
	self.cost = statBox(card, UDim2.fromOffset(232, 100), "coin cost", Theme.Color.gold)
	self.bonus = statBox(card, UDim2.fromOffset(422, 100), "next speed", Theme.Color.green)

	self.detail = Util.text({
		Position = UDim2.fromOffset(42, 206),
		Size = UDim2.new(1, -84, 0, 46),
		Font = Theme.Font.small,
		Text = "you keep your coins, quests and every value you already found.\nyour scan progress resets, and rebirth-only stats unlock.",
		TextColor3 = Theme.Color.ink,
		TextTransparency = 0.15,
		TextSize = 14,
		ZIndex = 7,
		Parent = card,
	})

	self.button = Util.button({
		variant = "gold",
		radius = Theme.Radius.lg,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.fromOffset(400, 66),
		Text = "REBIRTH",
		TextSize = 26,
		lip = Theme.Lip.chunky,
		ZIndex = 7,
		Parent = card,
	})

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

	self.current.Text = ("rebirths: %d   %s"):format(
		state.rebirths,
		state.rebirthTitle ~= "" and state.rebirthTitle or ""
	)

	self.scanned.Text = ("%d/%d"):format(info.scannedCount, info.requirement)
	self.scanned.TextSize = 28
	self.cost.Text = Format.short(info.cost)
	self.bonus.Text = ("%.2fx"):format(info.nextSpeed)

	local blocked = info.blocker ~= nil
	self.button.Text = blocked and (info.blocker :: string) or "REBIRTH NOW"
	self.button.TextSize = blocked and 16 or 26
	self.button.BackgroundColor3 = blocked and Theme.Color.slot or Theme.Color.gold
	self.button.TextColor3 = blocked and Theme.Color.inkMuted or Theme.inkOn(Theme.Color.gold)

	local lip = self.button:FindFirstChild("Lip") :: Frame?
	if lip then
		lip.BackgroundColor3 = Theme.shade(self.button.BackgroundColor3, -0.32)
	end

	self.detail.Text = ("you keep your coins, quests and every value you already found.\nscan progress resets. %d stats exist in total."):format(
		StatConfig.Count
	)
end

function RebirthPanel:setVisible(visible: boolean)
	self.root.Visible = visible
end

return RebirthPanel
