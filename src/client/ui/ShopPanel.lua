--!strict
--[[
	ShopPanel -- gamepasses on the left, coin and utility products on the right.
	Each product is its own bolted module; prices are monospace, as all numeric
	displays are.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GamepassConfig = require(Shared.GamepassConfig)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Bevel = require(script.Parent.Bevel)

local ShopPanel = {}
ShopPanel.__index = ShopPanel

local function column(parent: Instance, title: string, position: UDim2, size: UDim2)
	local holder = Util.new("Frame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Parent = parent,
	})

	Util.stamp({
		Size = UDim2.new(1, 0, 0, 16),
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local scroll = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 1, -24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Color.shadowDeep,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = holder,
	})
	Util.listLayout(Theme.Space.gap, scroll)
	Util.new("UIPadding", {
		PaddingLeft = UDim.new(0, 6),
		PaddingRight = UDim.new(0, 12),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 4),
		Parent = scroll,
	})

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

	local passes = column(self.root, "gamepasses", UDim2.new(), UDim2.new(0.56, -10, 1, -34))
	local products = column(self.root, "credits & utilities", UDim2.new(0.56, 10, 0, 0), UDim2.new(0.44, -10, 1, -34))

	for _, pass in ipairs(GamepassConfig.Passes) do
		local card = Util.panel({
			Size = UDim2.new(1, 0, 0, 124),
			Parent = passes,
		}, { padding = Theme.Space.panel, ventPos = UDim2.new(1, -134, 0, 2) })
		Util.padding(Theme.Space.panel, card)

		local housing = Util.iconHousing(card, pass.icon, 40, pass.color)
		housing.Position = UDim2.fromOffset(2, 2)

		Util.text({
			Position = UDim2.fromOffset(52, 0),
			Size = UDim2.new(1, -52 - 120, 0, 24),
			Font = Theme.Font.display,
			Text = pass.name:upper(),
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		Util.text({
			Position = UDim2.fromOffset(52, 24),
			Size = UDim2.new(1, -52 - 120, 0, 20),
			Text = pass.blurb,
			TextColor3 = Theme.Color.textMuted,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		-- Perks in a recessed spec well.
		local well = Util.well({
			Position = UDim2.new(0, 0, 1, -46),
			Size = UDim2.new(1, -6, 0, 44),
			AnchorPoint = Vector2.new(0, 1),
			Parent = card,
		})

		Util.text({
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -20, 1, 0),
			Font = Theme.Font.mono,
			Text = "- " .. table.concat(pass.perks, "\n- "),
			TextColor3 = Theme.Color.textMuted,
			TextSize = 11,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
			Parent = well,
		})

		local buy = Util.button({
			variant = "primary",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 0),
			Size = UDim2.fromOffset(112, Theme.TOUCH),
			Font = Theme.Font.mono,
			Text = "R$ " .. pass.price,
			TextSize = 15,
			Parent = card,
		})

		Util.onClick(buy, 0.5, function()
			callbacks.buyPass(pass.key)
		end)

		self.passRows[pass.key] = { card = card, buy = buy, pass = pass }
	end

	for _, product in ipairs(GamepassConfig.Products) do
		local card = Util.panel({
			Size = UDim2.new(1, 0, 0, 62),
			Parent = products,
		})
		Util.padding(10, card)

		Util.text({
			Position = UDim2.fromOffset(4, 0),
			Size = UDim2.new(1, -120, 1, 0),
			Font = Theme.Font.bold,
			Text = product.name:upper(),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = card,
		})

		local buy = Util.button({
			variant = "secondary",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(104, 40),
			Font = Theme.Font.mono,
			Text = "R$ " .. product.price,
			TextSize = 14,
			Parent = card,
		})

		Util.onClick(buy, 0.5, function()
			callbacks.buyProduct(product.key)
		end)
	end

	-- Live multiplier readout along the bottom.
	local strip = Util.well({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 28),
		Parent = self.root,
	})

	self.summary = Util.text({
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		Font = Theme.Font.mono,
		Text = "",
		TextColor3 = Theme.Color.textMuted,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = strip,
	})

	return self
end

function ShopPanel:update(state)
	for key, row in pairs(self.passRows) do
		local owned = state.passes and state.passes[key]
		row.buy.Text = owned and "OWNED" or ("R$ " .. row.pass.price)
		row.buy.BackgroundColor3 = owned and Theme.Color.recess or Theme.Color.accent
		row.buy.TextColor3 = owned and Theme.Color.textMuted or Theme.Color.accentText
		row.buy.Active = not owned
		if owned then
			Bevel.invert(row.buy, true)
		end
	end

	self.summary.Text = ("ACTIVE: SPD %.2fx   COIN %.2fx   SLOTS %d   BALANCE %s"):format(
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
