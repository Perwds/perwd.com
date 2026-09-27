--!strict
--[[
	ShopPanel
	Gamepasses on the left, coin/utility developer products on the right.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GamepassConfig = require(Shared.GamepassConfig)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local ShopPanel = {}
ShopPanel.__index = ShopPanel

local function scroller(parent: Instance, title: string, position: UDim2, size: UDim2)
	local holder = Util.new("Frame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Parent = parent,
	})

	Util.new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		Font = Theme.Font.heading,
		Text = title,
		TextColor3 = Theme.Color.text,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local scroll = Util.new("ScrollingFrame", {
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = holder,
	})
	Util.listLayout(10, scroll)
	Util.padding(2, scroll)

	return scroll
end

function ShopPanel.new(parent: Instance, callbacks)
	local self = setmetatable({}, ShopPanel)

	self.callbacks = callbacks
	self.passRows = {}

	self.root = Util.new("Frame", {
		Name = "ShopPanel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})

	local passes = scroller(self.root, "⚡ Gamepasses", UDim2.new(0, 0, 0, 0), UDim2.new(0.5, -8, 1, 0))
	local products = scroller(self.root, "🪙 Coins & Utilities", UDim2.new(0.5, 8, 0, 0), UDim2.new(0.5, -8, 1, 0))

	for _, pass in ipairs(GamepassConfig.Passes) do
		local card = Util.new("Frame", {
			Size = UDim2.new(1, -8, 0, 116),
			BackgroundColor3 = Theme.Color.card,
			BorderSizePixel = 0,
			Parent = passes,
		})
		Util.corner(Theme.Radius.card, card)
		Util.padding(12, card)
		Util.stroke(pass.color, 2, card)

		Util.new("TextLabel", {
			Size = UDim2.new(1, -110, 0, 26),
			BackgroundTransparency = 1,
			Font = Theme.Font.heading,
			Text = pass.icon .. "  " .. pass.name,
			TextColor3 = pass.color,
			TextSize = 22,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		Util.new("TextLabel", {
			Position = UDim2.new(0, 0, 0, 28),
			Size = UDim2.new(1, -110, 0, 22),
			BackgroundTransparency = 1,
			Font = Theme.Font.body,
			Text = pass.blurb,
			TextColor3 = Theme.Color.subtext,
			TextSize = 15,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		Util.new("TextLabel", {
			Position = UDim2.new(0, 0, 1, -44),
			Size = UDim2.new(1, -110, 0, 44),
			BackgroundTransparency = 1,
			Font = Theme.Font.body,
			Text = "• " .. table.concat(pass.perks, "\n• "),
			TextColor3 = Theme.Color.muted,
			TextSize = 13,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		local buy = Util.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.new(0, 96, 0, 44),
			BackgroundColor3 = pass.color,
			Text = "R$ " .. pass.price,
			TextColor3 = Color3.fromRGB(20, 20, 20),
			TextSize = 18,
			Parent = card,
		})
		Util.corner(Theme.Radius.card, buy)

		Util.onClick(buy, 0.5, function()
			callbacks.buyPass(pass.key)
		end)

		self.passRows[pass.key] = { card = card, buy = buy, pass = pass }
	end

	for _, product in ipairs(GamepassConfig.Products) do
		local card = Util.new("Frame", {
			Size = UDim2.new(1, -8, 0, 62),
			BackgroundColor3 = Theme.Color.card,
			BorderSizePixel = 0,
			Parent = products,
		})
		Util.corner(Theme.Radius.card, card)
		Util.padding(10, card)

		Util.new("TextLabel", {
			Size = UDim2.new(1, -110, 1, 0),
			BackgroundTransparency = 1,
			Font = Theme.Font.bold,
			Text = product.icon .. "  " .. product.name,
			TextColor3 = Theme.Color.text,
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		local buy = Util.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.new(0, 96, 0, 40),
			BackgroundColor3 = Theme.Color.robux,
			Text = "R$ " .. product.price,
			TextColor3 = Color3.fromRGB(20, 20, 20),
			TextSize = 18,
			Parent = card,
		})
		Util.corner(Theme.Radius.card, buy)

		Util.onClick(buy, 0.5, function()
			callbacks.buyProduct(product.key)
		end)
	end

	-- Live multiplier summary --------------------------------------------
	self.summary = Util.new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = Theme.Font.body,
		Text = "",
		TextColor3 = Theme.Color.coin,
		TextSize = 16,
		Parent = self.root,
	})

	return self
end

function ShopPanel:update(state)
	for key, row in pairs(self.passRows) do
		local owned = state.passes and state.passes[key]
		row.buy.Text = owned and "OWNED ✓" or ("R$ " .. row.pass.price)
		row.buy.BackgroundColor3 = owned and Theme.Color.good or row.pass.color
		row.buy.Active = not owned
	end

	self.summary.Text = ("Current bonuses:  %.2fx scan speed   •   %.2fx coins   •   %d scan slot(s)   •   %s coins"):format(
		state.speed or 1,
		state.coinMultiplier or 1,
		state.slots or 1,
		Format.comma(state.coins or 0)
	)
end

function ShopPanel:setVisible(visible: boolean)
	self.root.Visible = visible
end

return ShopPanel
