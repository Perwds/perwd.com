--!strict
--[[
	FlexFeed -- a dark data strip along the top for server-wide events.
	Monospace, LED-prefixed, deliberately terse: it reads as telemetry rather
	than as chat.
]]

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local FlexFeed = {}

local LIFETIME = 6

function FlexFeed.new(parent: Instance)
	local self = setmetatable({}, { __index = FlexFeed })

	self.root = Util.new("Frame", {
		Name = "FlexFeed",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 14),
		Size = UDim2.fromOffset(660, 140),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	local layout = Util.listLayout(Theme.Space.tight, self.root)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	return self
end

function FlexFeed:push(payload)
	local text, accent

	if payload.kind == "rebirth" then
		text = ("%s COMPLETED REBIRTH CYCLE %d"):format(payload.player:upper(), payload.rebirths)
		accent = Theme.Color.accent
	else
		text = ("%s // %s"):format(payload.player:upper(), payload.message or "")
		accent = payload.color or Theme.Color.ledGreen
	end

	local cell, inner = Util.slot({
		Size = UDim2.new(1, 0, 0, 34),
		Parent = self.root,
	})

	local strip = Util.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Color.dark,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Parent = inner,
	})
	Util.corner(Theme.Radius.sm, strip)
	Util.stroke(accent, 2, strip)

	-- Indicator bar in place of an icon, so the strip stays machine-like.
	local pip = Util.new("Frame", {
		Position = UDim2.fromOffset(8, 10),
		Size = UDim2.fromOffset(4, 14),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = strip,
	})
	Util.corner(Theme.Radius.full, pip)

	Util.text({
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -32, 1, 0),
		Font = Theme.Font.mono,
		Text = text,
		TextColor3 = Theme.Color.darkText,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = strip,
	})

	strip.Position = UDim2.fromOffset(0, -18)
	Util.tween(strip, 0.25, { Position = UDim2.new() }, Theme.Motion.mechanical)

	task.delay(LIFETIME, function()
		if cell.Parent then
			Util.fadeOut(strip, 0.4, function()
				if cell.Parent then
					cell:Destroy()
				end
			end)
		end
	end)
end

return FlexFeed
