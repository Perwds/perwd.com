--!strict
--[[ FlexFeed -- server-wide brags across the top. ]]

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Skin = require(script.Parent.Skin)

local FlexFeed = {}

local LIFETIME = 6

function FlexFeed.new(parent: Instance)
	local self = setmetatable({}, { __index = FlexFeed })

	self.root = Util.new("Frame", {
		Name = "FlexFeed",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(720, 160),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	local layout = Util.listLayout(Theme.Space.tight, self.root)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	return self
end

function FlexFeed:push(payload)
	local text, tint

	if payload.kind == "rebirth" then
		text = ("%s just REBIRTHED (x%d)!"):format(payload.player, payload.rebirths)
		tint = Theme.Color.gold
	else
		text = ("%s  %s"):format(payload.player, payload.message or "")
		tint = payload.color or Theme.Color.cyan
	end

	local cell, inner = Util.slot({ Size = UDim2.new(1, 0, 0, 42), Parent = self.root })

	local strip = Util.card({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tint,
		radius = Theme.Radius.full,
		lip = Theme.Lip.small,
		Parent = inner,
	})

	Util.title({
		Size = UDim2.new(1, -28, 1, -6),
		Position = UDim2.fromOffset(14, 0),
		Text = text,
		TextSize = 18,
		TextColor3 = Theme.inkOn(tint),
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = strip,
	})

	strip.Position = UDim2.fromOffset(0, -30)
	Util.tween(strip, 0.3, { Position = UDim2.new() }, Theme.Motion.pop)
	Skin.pop(strip, 0.06)

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
