--!strict
--[[ Toasts -- reward popups, bottom right. ]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Skin = require(script.Parent.Skin)

local Toasts = {}

local MAX = 4
local LIFETIME = 4

function Toasts.new(parent: Instance)
	local self = setmetatable({}, { __index = Toasts })

	self.root = Util.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(340, 460),
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
	if self.count >= MAX then
		for _, child in ipairs(self.root:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
				self.count -= 1
				break
			end
		end
	end
	self.count += 1

	local tint = payload.color or Theme.Color.green
	local cell, inner = Util.slot({ Size = UDim2.new(1, 0, 0, 74), Parent = self.root })

	local card = Util.card({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tint,
		radius = Theme.Radius.md,
		lip = Theme.Lip.base,
		Parent = inner,
	})

	Util.badge(card, payload.icon or "!", 44, Color3.new(1, 1, 1)).Position = UDim2.fromOffset(10, 11)

	Util.title({
		Position = UDim2.fromOffset(64, 8),
		Size = UDim2.new(1, -74, 0, 48),
		Text = payload.text or "",
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		ZIndex = 3,
		Parent = card,
	})

	if payload.coins then
		Util.title({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -10, 1, -10),
			Size = UDim2.fromOffset(120, 22),
			Text = "+" .. Format.comma(payload.coins),
			TextSize = 19,
			TextColor3 = Theme.Color.gold,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 3,
			Parent = card,
		})
	end

	card.Position = UDim2.fromOffset(80, 0)
	Util.tween(card, 0.3, { Position = UDim2.new() }, Theme.Motion.pop)
	Skin.pop(card, 0.08)

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
