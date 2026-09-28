--!strict
--[[ ShopPanel -- gamepasses and coin packs. ]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GamepassConfig = require(Shared.GamepassConfig)
local Format = require(Shared.Format)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)

local ShopPanel = {}
ShopPanel.__index = ShopPanel

local function column(parent: Instance, title: string, position: UDim2, size: UDim2)
	local holder = Util.new("Frame", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = parent,
	})

	Util.title({
		Size = UDim2.new(1, 0, 0, 26),
		Text = title,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 6,
		Parent = holder,
	})

	local scroll = Util.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 7,
		ScrollBarImageColor3 = Theme.Color.purple,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ZIndex = 6,
		Parent = holder,
	})
	Util.listLayout(Theme.Space.gap, scroll)
	Util.new("UIPadding", {
		PaddingRight = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 10),
		Parent = scroll,
	})

	return scroll
end

function ShopPanel.new(parent: Instance, callbacks)
	local self = setmetatable({}, ShopPanel)

	self.passRows = {}

	self.root = Util.new("Frame", {
		Name = "ShopPanel",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = parent,
	})

	local passes = column(self.root, "GAMEPASSES", UDim2.new(), UDim2.new(0.58, -10, 1, -40))
	local packs = column(self.root, "COIN PACKS", UDim2.new(0.58, 10, 0, 0), UDim2.new(0.42, -10, 1, -40))

	for _, pass in ipairs(GamepassConfig.Passes) do
		local card = Util.card({
			Size = UDim2.new(1, 0, 0, 108),
			BackgroundColor3 = pass.color,
			radius = Theme.Radius.lg,
			lip = Theme.Lip.base,
			ZIndex = 6,
			Parent = passes,
		})

		Util.badge(card, pass.icon, 46, Color3.new(1, 1, 1)).Position = UDim2.fromOffset(12, 14)

		Util.title({
			Position = UDim2.fromOffset(70, 10),
			Size = UDim2.new(1, -70 - 140, 0, 26),
			Text = pass.name:upper(),
			TextSize = 21,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
			Parent = card,
		})

		Util.text({
			Position = UDim2.fromOffset(70, 36),
			Size = UDim2.new(1, -70 - 140, 0, 38),
			Font = Theme.Font.small,
			Text = pass.blurb .. "\n" .. table.concat(pass.perks, " · "),
			TextSize = 13,
			TextTransparency = 0.1,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
			Parent = card,
		})

		local buy = Util.button({
			variant = "go",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -12, 0, 14),
			Size = UDim2.fromOffset(122, Theme.TOUCH),
			Text = "R$ " .. pass.price,
			TextSize = 19,
			ZIndex = 7,
			Parent = card,
		})
		Util.onClick(buy, 0.5, function()
			callbacks.buyPass(pass.key)
		end)

		self.passRows[pass.key] = { card = card, buy = buy, pass = pass }
	end

	for _, product in ipairs(GamepassConfig.Products) do
		local card = Util.card({
			Size = UDim2.new(1, 0, 0, 68),
			BackgroundColor3 = Theme.Color.panelLite,
			radius = Theme.Radius.md,
			lip = Theme.Lip.base,
			ZIndex = 6,
			Parent = packs,
		})

		Util.badge(card, product.icon, 40, Theme.Color.gold).Position = UDim2.fromOffset(10, 12)

		Util.title({
			Position = UDim2.fromOffset(60, 12),
			Size = UDim2.new(1, -60 - 120, 0, 28),
			Text = product.name:upper(),
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 7,
			Parent = card,
		})

		local buy = Util.button({
			variant = "gold",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 11),
			Size = UDim2.fromOffset(108, 42),
			Text = "R$ " .. product.price,
			TextSize = 17,
			lip = Theme.Lip.small,
			ZIndex = 7,
			Parent = card,
		})
		Util.onClick(buy, 0.5, function()
			callbacks.buyProduct(product.key)
		end)
	end

	local strip = Util.well({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 32),
		radius = Theme.Radius.md,
		ZIndex = 6,
		Parent = self.root,
	})

	self.summary = Util.text({
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 1, 0),
		Text = "",
		TextColor3 = Theme.Color.inkMuted,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 7,
		Parent = strip,
	})

	return self
end

function ShopPanel:update(state)
	for key, row in pairs(self.passRows) do
		local owned = state.passes and state.passes[key]
		row.buy.Text = owned and "OWNED" or ("R$ " .. row.pass.price)
		row.buy.BackgroundColor3 = owned and Theme.Color.slot or Theme.Color.green
		row.buy.TextColor3 = owned and Theme.Color.inkMuted or Theme.inkOn(Theme.Color.green)
		row.buy.Active = not owned
		local lip = row.buy:FindFirstChild("Lip") :: Frame?
		if lip then
			lip.BackgroundColor3 = Theme.shade(row.buy.BackgroundColor3, -0.32)
		end
	end

	self.summary.Text = ("you have %s coins  ·  %.1fx speed  ·  %.1fx coins  ·  %d scan slots"):format(
		Format.comma(state.coins or 0),
		state.speed or 1,
		state.coinMultiplier or 1,
		state.slots or 1
	)
end

function ShopPanel:setVisible(visible: boolean)
	self.root.Visible = visible
end

return ShopPanel
