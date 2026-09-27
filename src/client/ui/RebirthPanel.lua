--!strict
--[[
	RebirthPanel -- requirements, rewards and the one control that matters.
	The data block is a recessed readout; the trigger is the only safety-orange
	key on the page.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local StatConfig = require(Shared.StatConfig)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Bevel = require(script.Parent.Bevel)

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

	local card = Util.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(600, 420),
		level = "floating",
		radius = Theme.Radius.xl,
		Parent = self.root,
	}, { padding = 24, ventPos = UDim2.new(1, -30, 0, 4) })
	Util.padding(24, card)

	Util.text({
		Size = UDim2.new(1, 0, 0, 40),
		Font = Theme.Font.display,
		Text = "REBIRTH",
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	Bevel.led(card, Theme.Color.ledAmber, "irreversible", UDim2.fromOffset(2, 44))

	self.current = Util.text({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 8),
		Size = UDim2.fromOffset(240, 28),
		Font = Theme.Font.mono,
		Text = "",
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})

	-- Recessed spec readout.
	local well = Util.well({
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 230),
		radius = Theme.Radius.md,
		Parent = card,
	})

	self.body = Util.text({
		Position = UDim2.fromOffset(16, 12),
		Size = UDim2.new(1, -32, 1, -24),
		Font = Theme.Font.mono,
		Text = "",
		TextColor3 = Theme.Color.textMuted,
		TextSize = 13,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = well,
	})

	self.button = Util.button({
		variant = "primary",
		radius = Theme.Radius.lg,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(340, 56),
		Text = "ENGAGE REBIRTH",
		TextSize = 18,
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

	self.current.Text = ("CYCLE %d%s"):format(
		state.rebirths,
		state.rebirthTitle ~= "" and ("  " .. state.rebirthTitle:upper()) or ""
	)

	self.body.Text = table.concat({
		("MODULES LOGGED   %d / %d      (%d total)"):format(info.scannedCount, info.requirement, StatConfig.Count),
		("COST             %s credits"):format(Format.comma(info.cost)),
		("BALANCE          %s credits"):format(Format.comma(state.coins)),
		"",
		"RETAINED   credits, objectives, every value already logged",
		"CLEARED    scan progress on all modules",
		"",
		("GRANTS     %.2fx scan speed (permanent)"):format(info.nextSpeed),
		("           %.2fx credit rate (permanent)"):format(info.nextCoins),
		"           access to rebirth-gated modules",
	}, "\n")

	local blocked = info.blocker ~= nil
	self.button.Text = blocked and (info.blocker :: string):upper() or "ENGAGE REBIRTH"
	self.button.BackgroundColor3 = blocked and Theme.Color.recess or Theme.Color.accent
	self.button.TextColor3 = blocked and Theme.Color.textMuted or Theme.Color.accentText
	self.button.TextSize = blocked and 13 or 18
	Bevel.invert(self.button, blocked)
end

function RebirthPanel:setVisible(visible: boolean)
	self.root.Visible = visible
end

return RebirthPanel
