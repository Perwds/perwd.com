--!strict
--[[
	Toasts -- notification modules that slide out from the right edge, as if
	ejected from a slot. Each carries the stat's identity stripe and a
	monospace readout.
]]

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Bevel = require(script.Parent.Bevel)

local Toasts = {}

local MAX_VISIBLE = 5
local LIFETIME = 4.5

function Toasts.new(parent: Instance)
	local self = setmetatable({}, { __index = Toasts })

	self.root = Util.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.fromOffset(350, 420),
		BackgroundTransparency = 1,
		Parent = parent,
	})

	local layout = Util.listLayout(Theme.Space.tight, self.root)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right

	self.count = 0
	return self
end

function Toasts:push(payload)
	if self.count >= MAX_VISIBLE then
		-- Drop the oldest so a burst of objectives cannot flood the screen.
		for _, child in ipairs(self.root:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
				self.count -= 1
				break
			end
		end

	end

	self.count += 1

	local accent = payload.color or Theme.Color.accent

	-- The cell is what the list lays out; the card slides inside it.
	local cell, inner = Util.slot({
		Size = UDim2.new(1, 0, 0, 58),
		Parent = self.root,
	})

	local card = Util.panel({
		Size = UDim2.fromScale(1, 1),
		Parent = inner,
	})
	Util.padding(10, card)

	-- Identity stripe down the left edge.
	local stripe = Util.new("Frame", {
		Position = UDim2.fromOffset(-4, 6),
		Size = UDim2.new(0, 4, 1, -12),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = card,
	})
	Util.corner(Theme.Radius.full, stripe)

	local housing = Util.iconHousing(card, payload.icon or "*", 34, accent)
	housing.Position = UDim2.fromOffset(2, 2)

	Util.text({
		Position = UDim2.fromOffset(44, 0),
		Size = UDim2.new(1, -52, 1, 0),
		Font = Theme.Font.mono,
		Text = payload.text or "",
		TextColor3 = Theme.Color.text,
		TextSize = 12,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	})

	-- Ejected from the slot, then settles.
	card.Position = UDim2.fromOffset(70, 0)
	Util.tween(card, 0.22, { Position = UDim2.new() }, Theme.Motion.mechanical)
	Bevel.invert(card, true)
	task.delay(0.16, function()
		if card.Parent then
			Bevel.invert(card, false)
		end
	end)

	task.delay(LIFETIME, function()
		if cell.Parent then
			Util.fadeOut(card, 0.3, function()
				if cell.Parent then
					cell:Destroy()
					self.count -= 1
				end
			end)
		end
	end)
end

return Toasts
