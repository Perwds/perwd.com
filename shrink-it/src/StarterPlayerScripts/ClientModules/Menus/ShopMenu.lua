--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > ShopMenu (ModuleScript)

	Shop tabs: Royal Crate (Robux-only objects, odds shown) · Gamepasses · Boosts (Developer Products) · Gems & Skins · Codes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Format = require(Shared.Format)
local RewardUtil = require(Shared.RewardUtil)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)
local Prices = require(Modules.Prices)

local ShopMenu = {}

function ShopMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Shop", Animated = true, Style = "Header", Size = UDim2.fromOffset(960, 660), Colors = { Color3.fromRGB(255, 225, 70), Color3.fromRGB(245, 150, 20) } })
	local content = panel.Content

	local tabsBar = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 18), Parent = content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabsBar })

	local pages = {}
	local tabButtons = {}
	local current = "Crates"
	local TABS = {
		{ Key = "Crates", Text = "Crates", Colors = UIKit.Colors.Orange },
		{ Key = "Passes", Text = "Passes", Colors = UIKit.Colors.Yellow },
		{ Key = "Boosts", Text = "Boosts", Colors = UIKit.Colors.Green },
		{ Key = "Gems", Text = "Gems & Skins", Colors = UIKit.Colors.Blue },
		{ Key = "Codes", Text = "Codes", Colors = UIKit.Colors.Pink },
	}

	local function showTab(key)
		current = key
		for k, page in pairs(pages) do
			page.Visible = k == key
		end
		for k, b in pairs(tabButtons) do
			b.BounceScale.Scale = k == key and 1.08 or 1
		end
	end

	for i, t in ipairs(TABS) do
		tabButtons[t.Key] = UIKit.Button({ Text = t.Text, Colors = t.Colors, Size = UDim2.fromOffset(172, 48), LayoutOrder = i, Parent = tabsBar, OnClick = function()
			showTab(t.Key)
		end })
		local page = UIKit.Scroll({ Name = t.Key, Size = UDim2.new(1, 0, 1, -82), Position = UDim2.fromOffset(0, 80), Parent = content })
		page.Visible = false
		UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), Parent = page })
		pages[t.Key] = page
	end

	local function grid(page, cell)
		UIKit.Create("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = page })
	end

	-- ── Royal Crate (Robux-only exclusives, odds shown) ─────────────
	local crate = MonetizationConfig.RoyalCrate
	local cratePage = pages.Crates
	local crateCard = UIKit.Card({ Size = UDim2.new(1, -16, 0, 420), Colors = { Color3.fromRGB(255, 215, 90), Color3.fromRGB(235, 130, 20) }, Parent = cratePage, CornerRadius = 18, StrokeThickness = 5 })
	UIKit.Label({ Text = "👑 " .. crate.Name, Size = UDim2.new(1, -20, 0, 48), Position = UDim2.fromOffset(10, 8), StrokeThickness = 4, Parent = crateCard })
	UIKit.Label({ Text = "5 EXCLUSIVE objects that never spawn on the map!", Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 54), StrokeThickness = 2.5, Parent = crateCard })
	local crateRow = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 0, 220), Position = UDim2.fromOffset(10, 92), Parent = crateCard })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = crateRow })
	for i, entry in ipairs(crate.Items) do
		local def = ObjectConfig.Get(entry.Id)
		local rarity = RarityConfig.GetRarity(def.Rarity)
		local tile = UIKit.Card({ Size = UDim2.fromOffset(160, 210), LayoutOrder = i, Colors = { rarity.Color:Lerp(Color3.new(1, 1, 1), 0.35), rarity.Color }, Parent = crateRow, CornerRadius = 12, StrokeThickness = 4 })
		UIKit.ModelPreview({ Id = entry.Id, Size = UDim2.new(1, -16, 0, 120), Position = UDim2.fromOffset(8, 6), Parent = tile })
		UIKit.Label({ Text = def.Name, Size = UDim2.new(1, -10, 0, 28), Position = UDim2.fromOffset(5, 126), StrokeThickness = 2.5, Parent = tile })
		UIKit.Label({ Text = entry.Chance .. "%", TextColor3 = Color3.fromRGB(255, 255, 140), Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 152), StrokeThickness = 2.5, Parent = tile })
		UIKit.Label({ Text = "+" .. Format.Coins(def.BaseIncome * rarity.IncomeMult) .. "/s", TextColor3 = Color3.fromRGB(150, 255, 150), Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 180), StrokeThickness = 2, Parent = tile })
	end
	local crateNote = UIKit.Label({ Text = "", Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 318), StrokeThickness = 2, Parent = crateCard })
	local crateButtons = {}
	for k, count in ipairs({ 1, 3 }) do
		local key = count == 3 and "RoyalCrate3" or "RoyalCrate"
		local button, label = UIKit.Button({ Text = "", Colors = { Color3.fromRGB(235, 110, 255), Color3.fromRGB(165, 30, 230) }, Size = UDim2.fromOffset(250, 58), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(k == 1 and 0.32 or 0.68, 0, 1, -12), CornerRadius = 10, Parent = crateCard, OnClick = function()
			ctx.HUD.Result(State.Action("BuyRoyalCrate", count))
		end })
		crateButtons[key] = { Button = button, Label = label, Count = count }
	end

	-- ── Passes ─────────────────────────────────────────────────────
	grid(pages.Passes, UDim2.fromOffset(204, 236))
	local PALETTE = { UIKit.Colors.Blue, UIKit.Colors.Purple, UIKit.Colors.Pink, UIKit.Colors.Orange, UIKit.Colors.Green, UIKit.Colors.Cyan, UIKit.Colors.Red, UIKit.Colors.Yellow }
	local POPULAR = { VIP = "POPULAR", DoubleCoins = "POPULAR", AutoShrink = "BEST" }

	-- colorful shop card: gradient body, icon bubble, name, small description, price button
	local function shopCard(parent, order, colors, emoji, image, name, description, ribbon, onClick)
		local card = UIKit.Card({ LayoutOrder = order, Colors = { colors[1]:Lerp(Color3.new(1, 1, 1), 0.25), colors[2] }, Parent = parent, CornerRadius = 22, StrokeThickness = 4 })
		local bubble = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(84, 84), Parent = card })
		UIKit.Corner(bubble, UDim.new(1, 0))
		UIKit.Stroke(bubble, 4, UIKit.Outline, true)
		UIKit.Gradient(bubble, { Color3.new(1, 1, 1), colors[1]:Lerp(Color3.new(1, 1, 1), 0.5) })
		UIKit.Icon({ Icon = { Emoji = emoji, Image = image }, Size = UDim2.new(0.72, 0, 0.72, 0), Position = UDim2.fromScale(0.14, 0.14), Parent = bubble })
		UIKit.Label({ Text = name, StrokeThickness = 3, Size = UDim2.new(1, -14, 0, 30), Position = UDim2.fromOffset(7, 102), Parent = card })
		local detail = UIKit.Label({ Text = description or "", TextColor3 = Color3.fromRGB(255, 255, 255), StrokeThickness = 2, Size = UDim2.new(1, -18, 0, 36), Position = UDim2.fromOffset(9, 134), Parent = card })
		if ribbon then
			local tag = UIKit.Card({ Size = UDim2.fromOffset(110, 28), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -30, 0, 8), Colors = UIKit.Colors.Red, Parent = card, CornerRadius = 10, StrokeThickness = 3 })
			tag.Rotation = 12
			tag.ZIndex = 5
			UIKit.Label({ Text = ribbon, Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), ZIndex = 6, StrokeThickness = 2, Parent = tag })
		end
		local button, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, Size = UDim2.new(1, -24, 0, 46), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), CornerRadius = 14, Parent = card, OnClick = onClick })
		return card, button, label, detail
	end

	local passCards = {}
	for i, key in ipairs(MonetizationConfig.PassOrder) do
		local pass = MonetizationConfig.GamePasses[key]
		local _, button, label = shopCard(pages.Passes, i, PALETTE[(i - 1) % #PALETTE + 1], pass.Emoji, pass.Image, pass.Name, pass.Description, POPULAR[key], function()
			ctx.HUD.Result(State.Action("PromptPass", key))
		end)
		passCards[key] = { Button = button, Label = label, Pass = pass }
	end

	-- ── Boosts (developer products) ─────────────────────────────────
	grid(pages.Boosts, UDim2.fromOffset(204, 236))
	local BEST = { CoinsLarge = "BEST VALUE", GemsLarge = "BEST VALUE", ServerLuck = "SERVER!" }
	local productCards = {}
	for i, key in ipairs(MonetizationConfig.ProductOrder) do
		local product = MonetizationConfig.Products[key]
		local _, _, label, detail = shopCard(pages.Boosts, i, PALETTE[(i + 3) % #PALETTE + 1], product.Emoji, product.Image, product.Name, "", BEST[key], function()
			ctx.HUD.Result(State.Action("PromptProduct", key))
		end)
		productCards[key] = { Label = label, Detail = detail, Product = product }
	end

	-- ── Gems & Skins ────────────────────────────────────────────────
	local gemsList = pages.Gems
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = gemsList })
	UIKit.Label({ Text = "Gem Shop", TextColor3 = Color3.fromRGB(90, 190, 255), StrokeThickness = 3, Size = UDim2.new(1, -20, 0, 36), LayoutOrder = 0, Parent = gemsList })
	for i, item in ipairs(MonetizationConfig.GemShop) do
		local row = UIKit.Card({ Size = UDim2.new(1, -24, 0, 58), LayoutOrder = i, Parent = gemsList, CornerRadius = 14 })
		UIKit.Label({ Text = item.Emoji .. "  " .. item.Name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Outline, StrokeThickness = 0, Size = UDim2.new(0.6, 0, 1, -16), Position = UDim2.fromOffset(14, 8), Parent = row })
		UIKit.Button({ Text = "💎 " .. item.Cost, Colors = UIKit.Colors.Blue, Size = UDim2.fromOffset(150, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = row, OnClick = function()
			ctx.HUD.Result(State.Action("GemShopBuy", item.Key))
		end })
	end
	UIKit.Label({ Text = "Ray Skins", TextColor3 = Color3.fromRGB(255, 120, 200), StrokeThickness = 3, Size = UDim2.new(1, -20, 0, 36), LayoutOrder = 100, Parent = gemsList })
	local skinButtons = {}
	for i, skinKey in ipairs(MonetizationConfig.SkinOrder) do
		local skin = MonetizationConfig.RaySkins[skinKey]
		local row = UIKit.Card({ Size = UDim2.new(1, -24, 0, 58), LayoutOrder = 100 + i, Parent = gemsList, CornerRadius = 14 })
		local swatch = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(120, 26), Position = UDim2.new(0, 14, 0.5, -13), Parent = row })
		UIKit.Corner(swatch, UDim.new(1, 0))
		UIKit.Stroke(swatch, 2.5, UIKit.Outline, true)
		if skin.Rainbow then
			UIKit.Create("UIGradient", { Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(0, 120, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 255)),
			}), Parent = swatch })
		else
			UIKit.Gradient(swatch, skin.Colors, 0)
		end
		UIKit.Label({ Text = skin.Name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Outline, StrokeThickness = 0, Size = UDim2.new(0.4, 0, 1, -16), Position = UDim2.fromOffset(150, 8), Parent = row })
		local button, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(150, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = row, OnClick = function()
			ctx.HUD.Result(State.Action("EquipSkin", skinKey))
		end })
		skinButtons[skinKey] = { Button = button, Label = label, Skin = skin }
	end

	-- ── Codes ───────────────────────────────────────────────────────
	local codesPage = pages.Codes
	UIKit.Label({ Text = "Enter a code:", StrokeThickness = 3, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 30), Parent = codesPage })
	local box = UIKit.Create("TextBox", {
		PlaceholderText = "CODE HERE",
		Text = "",
		Font = UIKit.Font,
		TextScaled = true,
		ClearTextOnFocus = false,
		TextColor3 = UIKit.Outline,
		BackgroundColor3 = Color3.fromRGB(245, 245, 255),
		Size = UDim2.fromOffset(460, 64),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 84),
		Parent = codesPage,
	})
	UIKit.Corner(box, 16)
	UIKit.Stroke(box, 4, UIKit.Outline, true)
	UIKit.Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = box })
	UIKit.Button({ Text = "REDEEM", Colors = UIKit.Colors.Pink, Size = UDim2.fromOffset(240, 60), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 166), Parent = codesPage, OnClick = function()
		local result = State.Action("RedeemCode", box.Text)
		ctx.HUD.Result(result)
		if result.ok then
			box.Text = ""
		end
	end })
	UIKit.Label({ Text = "Like the game! Like goals unlock new codes — check the sign in the lobby.", TextColor3 = Color3.fromRGB(220, 220, 235), StrokeThickness = 2, Size = UDim2.new(1, -40, 0, 50), Position = UDim2.fromOffset(20, 250), Parent = codesPage })

	showTab(current)

	local menu = { Panel = panel }

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		for key, c in pairs(passCards) do
			if State.HasPass(key) then
				c.Label.Text = "OWNED"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Gray)
			else
				c.Label.Text = Prices.Get(Enum.InfoType.GamePass, c.Pass.Id, c.Pass.PriceLabel)
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Green)
			end
		end
		for _, c in pairs(productCards) do
			c.Label.Text = Prices.Get(Enum.InfoType.Product, c.Product.Id, c.Product.PriceLabel)
			if c.Product.Grant then
				c.Detail.Text = (RewardUtil.Describe(c.Product.Grant, State.Income))
			elseif c.Product.Handler == "InstantRebirth" then
				c.Detail.Text = "Rebirth now, no coins needed"
			elseif c.Product.Handler == "SpawnGolden" then
				c.Detail.Text = "Spawns next to you!"
			end
		end
		local restricted = data.PaidRandomRestricted ~= false
		crateNote.Text = restricted and "Crates aren't available in your region." or "Odds are shown above. Each crate gives ONE object (random size)."
		for key, c in pairs(crateButtons) do
			local product = MonetizationConfig.Products[key]
			c.Label.Text = "Open " .. c.Count .. "  ·  " .. Prices.Get(Enum.InfoType.Product, product.Id, product.PriceLabel)
			UIKit.SetButtonColors(c.Button, restricted and UIKit.Colors.Gray or { Color3.fromRGB(235, 110, 255), Color3.fromRGB(165, 30, 230) })
		end
		for key, c in pairs(skinButtons) do
			local owned = data.RaySkins[key] or (c.Skin.Pass and State.HasPass(c.Skin.Pass))
			if data.EquippedSkin == key then
				c.Label.Text = "EQUIPPED"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Gray)
			elseif owned then
				c.Label.Text = "EQUIP"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Green)
			else
				c.Label.Text = c.Skin.Pass and "Pass" or "Locked"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Dark)
			end
		end
	end

	Prices.OnUpdated(function()
		if panel.IsOpen() then
			menu.Refresh()
		end
	end)

	return menu
end

return ShopMenu
