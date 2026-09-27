--!strict
--[[ Toasts -- bottom-right notification stack. ]]

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local Toasts = {}

local MAX_VISIBLE = 5
local LIFETIME = 4.5

function Toasts.new(parent: Instance)
	local self = setmetatable({}, { __index = Toasts })

	self.root = Util.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.new(0, 330, 0, 400),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	local layout = Util.listLayout(8, self.root)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	self.count = 0
	return self
end

function Toasts:push(payload)
	if self.count >= MAX_VISIBLE then
		-- Drop the oldest so a burst of achievements can't flood the screen.
		local children = self.root:GetChildren()
		for _, child in ipairs(children) do
			if child:IsA("Frame") then
				child:Destroy()
				self.count -= 1
				break
			end
		end
	end

	self.count += 1

	local color = payload.color or Theme.Color.good

	local card = Util.new("Frame", {
		Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = Theme.Color.panelDark,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Parent = self.root,
	})
	Util.corner(Theme.Radius.card, card)
	Util.stroke(color, 2, card)

	Util.new("Frame", {
		Size = UDim2.new(0, 6, 1, 0),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Parent = card,
	})

	Util.new("TextLabel", {
		Position = UDim2.new(0, 14, 0, 0),
		Size = UDim2.new(0, 34, 1, 0),
		BackgroundTransparency = 1,
		Font = Theme.Font.body,
		Text = payload.icon or "ℹ️",
		TextSize = 24,
		TextColor3 = Theme.Color.text,
		Parent = card,
	})

	Util.new("TextLabel", {
		Position = UDim2.new(0, 52, 0, 0),
		Size = UDim2.new(1, -62, 1, 0),
		BackgroundTransparency = 1,
		Font = Theme.Font.body,
		Text = payload.text or "",
		TextColor3 = Theme.Color.text,
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	card.Position = UDim2.new(0, 60, 0, 0)
	Util.tween(card, 0.18, { Position = UDim2.new() }, Enum.EasingStyle.Back)

	task.delay(LIFETIME, function()
		if card.Parent then
			local fade = Util.tween(card, 0.25, { BackgroundTransparency = 1 })
			fade.Completed:Wait()
			card:Destroy()
			self.count -= 1
		end
	end)
end

return Toasts
