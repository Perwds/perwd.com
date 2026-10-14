--!strict
-- The optional shop. Only items with a real ID are listed; with none configured there is no shop at all.
-- Never pops up on its own: it opens from the Shop button or the VIP gate.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)

local ShopUi = {}

local player = Players.LocalPlayer
local items: { { [string]: any } } = {}
local window: Frame?
local prices: { [string]: string } = {}

local function priceOf(item: { [string]: any }): string
	local key = item.kind .. item.id
	if prices[key] then
		return prices[key]
	end
	local ok, info = pcall(
		MarketplaceService.GetProductInfo,
		MarketplaceService,
		item.id,
		if item.kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
	)
	local text = if ok and info and info.PriceInRobux then tostring(info.PriceInRobux) .. " R$" else "Buy"
	prices[key] = text
	return text
end

local function buy(item: { [string]: any })
	if item.kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, item.id)
	else
		MarketplaceService:PromptProductPurchase(player, item.id)
	end
end

function ShopUi.close()
	if window then
		window:Destroy()
		window = nil
	end
end

function ShopUi.open(focusKey: string?)
	if #items == 0 then
		return
	end
	ShopUi.close()
	local frame = Ui.panel({
		Name = "Shop",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(520, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 10,
		Parent = Hud.gui(),
	})
	window = frame
	Ui.padding(18).Parent = frame
	Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })

	local header = Ui.new(
		"Frame",
		{ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, Ui.MIN_TAP), ZIndex = 10, Parent = frame }
	)
	Ui.text({
		Text = "SHOP",
		Font = Ui.TITLE,
		TextSize = 30,
		TextColor3 = Palette.zones.vip.neon,
		Size = UDim2.new(1, -60, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
		Parent = header,
	})
	Ui.button({
		Text = "X",
		TextSize = 22,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(Ui.MIN_TAP, Ui.MIN_TAP),
		ZIndex = 11,
		Parent = header,
	}, ShopUi.close)
	Ui.text({
		Text = "Optional extras. Everything in the grove can be reached without them.",
		TextSize = 14,
		TextColor3 = Palette.lockedInk,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		ZIndex = 11,
		Parent = frame,
	})

	for i, item in items do
		local row = Ui.panel({
			BackgroundColor3 = if item.key == focusKey then Palette.zones.vip.floorB else Palette.screen,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = i + 1,
			ZIndex = 11,
			Parent = frame,
		})
		Ui.padding(12).Parent = row
		Ui.text({
			Text = item.name,
			Font = Ui.TITLE,
			TextSize = 20,
			Size = UDim2.new(1, -150, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = row,
		})
		Ui.text({
			Text = item.desc,
			TextSize = 14,
			TextWrapped = true,
			Position = UDim2.fromOffset(0, 26),
			Size = UDim2.new(1, -150, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 12,
			Parent = row,
		})
		local owned = item.kind == "pass" and item.owned
		local button = Ui.button({
			Text = if owned then "OWNED" else "...",
			TextSize = 18,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(130, Ui.MIN_TAP),
			BackgroundColor3 = if owned then Palette.hudEdge else Palette.zones.vip.plate,
			ZIndex = 12,
			Parent = row,
		}, function()
			if not owned then
				buy(item)
			end
		end)
		if not owned then
			task.spawn(function()
				button.Text = priceOf(item)
			end)
		end
	end
end

function ShopUi.init(remotes: Folder)
	local shopButton = Hud.buttons.shop
	shopButton.Activated:Connect(function()
		if window then
			ShopUi.close()
		else
			ShopUi.open()
		end
	end)
	remotes.Shop.OnClientEvent:Connect(function(list: { { [string]: any } })
		items = list
		shopButton.Visible = #items > 0
		if window then
			ShopUi.open()
		end
	end)
	ContextActionService:BindAction("ShopMenu", function(_, state)
		if state == Enum.UserInputState.Begin and #items > 0 then
			if window then
				ShopUi.close()
			else
				ShopUi.open()
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.DPadRight)

	-- The VIP gate only exists when the VIP pass has an ID.
	local gate = workspace:WaitForChild("Board"):FindFirstChild("VipGate", true) :: ProximityPrompt?
	if gate then
		gate.Triggered:Connect(function()
			local vip = player:GetAttribute("VIP")
			if vip then
				Hud.toast("THE BACK ORCHARD IS OPEN TO YOU")
			else
				ShopUi.open("VIP")
			end
		end)
	end
end

return ShopUi
