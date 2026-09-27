--!strict
--[[ FlexFeed -- top-centre ticker for server-wide flexes and rebirths. ]]

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local FlexFeed = {}

local LIFETIME = 6

function FlexFeed.new(parent: Instance)
	local self = setmetatable({}, { __index = FlexFeed })

	self.root = Util.new("Frame", {
		Name = "FlexFeed",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(0, 620, 0, 120),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	local layout = Util.listLayout(6, self.root)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	return self
end

function FlexFeed:push(payload)
	local text, color

	if payload.kind == "rebirth" then
		text = ("🌟 %s just hit REBIRTH %d!"):format(payload.player, payload.rebirths)
		color = Theme.Color.coin
	else
		text = ("%s %s: %s"):format(payload.icon or "📣", payload.player, payload.message or "")
		color = payload.color or Theme.Color.accent
	end

	local banner = Util.new("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Color.panelDark,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Parent = self.root,
	})
	Util.corner(Theme.Radius.pill, banner)
	Util.stroke(color, 2, banner)

	Util.new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.Font.body,
		Text = text,
		TextColor3 = Theme.Color.text,
		TextSize = 16,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = banner,
	})

	task.delay(LIFETIME, function()
		if banner.Parent then
			local fade = Util.tween(banner, 0.4, { BackgroundTransparency = 1 })
			fade.Completed:Wait()
			banner:Destroy()
		end
	end)
end

return FlexFeed
