--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > ShopMenu (ModuleScript)

	Shop tabs: Gamepasses · Boosts (Developer Products) · Gems & Skins · Codes
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local RewardUtil = require(Shared.RewardUtil)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)
local Prices = require(Modules.Prices)

local ShopMenu = {}

function ShopMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Shop", Emoji = "🛒", Size = UDim2.fromOffset(940, 620), Colors = UIKit.Colors.Yellow })
	local content = panel.Content

	local tabsBar = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), Position = UDim2.fromOffset(0, 18), Parent = content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabsBar })

	local pages = {}
	local tabButtons = {}
	local current = "Passes"
	local TABS = {
		{ Key = "Passes", Text = "⭐ Passes", Colors = UIKit.Colors.Yellow },
		{ Key = "Boosts", Text = "🧪 Boosts", Colors = UIKit.Colors.Green },
		{ Key = "Gems", Text = "💎 Gems & Skins", Colors = UIKit.Colors.Blue },
		{ Key = "Codes", Text = "🎟️ Codes", Colors = UIKit.Colors.Pink },
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
		tabButtons[t.Key] = UIKit.Button({ Text = t.Text, Colors = t.Colors, Size = UDim2.fromOffset(200, 48), LayoutOrder = i, Parent = tabsBar, OnClick = function()
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

	-- ── Passes ─────────────────────────────────────────────────────
	grid(pages.Passes, UDim2.fromOffset(204, 214))
	local passCards = {}
	for i, key in ipairs(MonetizationConfig.PassOrder) do
		local pass = MonetizationConfig.GamePasses[key]
		local card = UIKit.Card({ LayoutOrder = i, Colors = UIKit.Colors.White, Parent = pages.Passes, CornerRadius = 18 })
		UIKit.Icon({ Icon = { Emoji = pass.Emoji, Image = pass.Image }, Size = UDim2.fromOffset(64, 64), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Parent = card })
		UIKit.Label({ Text = pass.Name, TextColor3 = Color3.fromRGB(255, 190, 40), StrokeThickness = 2.5, Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 74), Parent = card })
		UIKit.Label({ Text = pass.Description, TextColor3 = Color3.fromRGB(70, 70, 90), StrokeThickness = 0, Size = UDim2.new(1, -16, 0, 50), Position = UDim2.fromOffset(8, 104), Parent = card })
		local button, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, Size = UDim2.new(1, -24, 0, 42), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Parent = card, OnClick = function()
			ctx.HUD.Result(State.Action("PromptPass", key))
		end })
		passCards[key] = { Button = button, Label = label, Pass = pass }
	end

	-- ── Boosts (developer products) ─────────────────────────────────
	grid(pages.Boosts, UDim2.fromOffset(204, 196))
	local productCards = {}
	for i, key in ipairs(MonetizationConfig.ProductOrder) do
		local product = MonetizationConfig.Products[key]
		local card = UIKit.Card({ LayoutOrder = i, Colors = UIKit.Colors.White, Parent = pages.Boosts, CornerRadius = 18 })
		UIKit.Icon({ Icon = { Emoji = product.Emoji, Image = product.Image }, Size = UDim2.fromOffset(64, 64), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 8), Parent = card })
		UIKit.Label({ Text = product.Name, TextColor3 = Color3.fromRGB(70, 200, 90), StrokeThickness = 2.5, Size = UDim2.new(1, -12, 0, 28), Position = UDim2.fromOffset(6, 74), Parent = card })
		local detail = UIKit.Label({ Text = "", TextColor3 = Color3.fromRGB(70, 70, 90), StrokeThickness = 0, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 104), Parent = card })
		local _, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, Size = UDim2.new(1, -24, 0, 42), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Parent = card, OnClick = function()
			ctx.HUD.Result(State.Action("PromptProduct", key))
		end })
		productCards[key] = { Label = label, Detail = detail, Product = product }
	end

	-- ── Gems & Skins ────────────────────────────────────────────────
	local gemsList = pages.Gems
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = gemsList })
	UIKit.Label({ Text = "💎 Gem Shop", TextColor3 = Color3.fromRGB(90, 190, 255), StrokeThickness = 3, Size = UDim2.new(1, -20, 0, 36), LayoutOrder = 0, Parent = gemsList })
	for i, item in ipairs(MonetizationConfig.GemShop) do
		local row = UIKit.Card({ Size = UDim2.new(1, -24, 0, 58), LayoutOrder = i, Parent = gemsList, CornerRadius = 14 })
		UIKit.Label({ Text = item.Emoji .. "  " .. item.Name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Outline, StrokeThickness = 0, Size = UDim2.new(0.6, 0, 1, -16), Position = UDim2.fromOffset(14, 8), Parent = row })
		UIKit.Button({ Text = "💎 " .. item.Cost, Colors = UIKit.Colors.Blue, Size = UDim2.fromOffset(150, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = row, OnClick = function()
			ctx.HUD.Result(State.Action("GemShopBuy", item.Key))
		end })
	end
	UIKit.Label({ Text = "🔫 Ray Skins", TextColor3 = Color3.fromRGB(255, 120, 200), StrokeThickness = 3, Size = UDim2.new(1, -20, 0, 36), LayoutOrder = 100, Parent = gemsList })
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
	UIKit.Label({ Text = "Enter a code:", TextColor3 = UIKit.Outline, StrokeThickness = 0, Size = UDim2.new(1, -20, 0, 40), Position = UDim2.fromOffset(10, 30), Parent = codesPage })
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
	UIKit.Label({ Text = "👍 Like the game! Like goals unlock new codes — check the sign in the lobby.", TextColor3 = Color3.fromRGB(90, 90, 110), StrokeThickness = 0, Size = UDim2.new(1, -40, 0, 50), Position = UDim2.fromOffset(20, 250), Parent = codesPage })

	showTab(current)

	local menu = { Panel = panel }

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		for key, c in pairs(passCards) do
			if State.HasPass(key) then
				c.Label.Text = "OWNED ✔"
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
		for key, c in pairs(skinButtons) do
			local owned = data.RaySkins[key] or (c.Skin.Pass and State.HasPass(c.Skin.Pass))
			if data.EquippedSkin == key then
				c.Label.Text = "EQUIPPED"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Gray)
			elseif owned then
				c.Label.Text = "EQUIP"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Green)
			else
				c.Label.Text = c.Skin.Pass and "🔒 Pass" or "🔒 Locked"
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
