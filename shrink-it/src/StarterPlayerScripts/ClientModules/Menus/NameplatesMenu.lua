--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > NameplatesMenu (ModuleScript)

	"Name Plates": pick the bar that floats over your head. Opened from the Trail Shop or the Shop.
	Big preview with your name on top, a grid of every plate below (buy with Coins / Gems / Robux,
	or unlock by beating the boss / rebirthing). Config: NameplateConfig.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NameplateConfig = require(Shared.Config.NameplateConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Nameplate = require(Shared.Nameplate)
local Format = require(Shared.Format)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)
local Prices = require(Modules.Prices)

local NameplatesMenu = {}

local RGB = Color3.fromRGB
local HEADER = { RGB(255, 170, 220), RGB(225, 70, 160) }
local GREEN = { RGB(130, 255, 60), RGB(50, 200, 20) }

local function owns(data, key)
	local cfg = NameplateConfig.Plates[key]
	if not cfg or not data then
		return false
	end
	if cfg.Free then
		return true
	end
	if cfg.Req then
		return (data[cfg.Req.Stat] or 0) >= cfg.Req.Amount
	end
	return data.Nameplates ~= nil and data.Nameplates[key] == true
end

local function priceText(cfg)
	if cfg.Product then
		local p = MonetizationConfig.Products[cfg.Product]
		return p and Prices.Get(Enum.InfoType.Product, p.Id, p.PriceLabel) or "R$ ?"
	elseif cfg.Req then
		return cfg.Req.Label
	elseif cfg.Currency == "Gems" then
		return Format.Abbrev(cfg.Cost) .. " Gems"
	end
	return Format.Coins(cfg.Cost or 0)
end

function NameplatesMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Name Plates", Animated = true, Style = "Header", Colors = HEADER, Size = UDim2.fromOffset(1060, 610) })
	local content = panel.Content
	local myName = Players.LocalPlayer and Players.LocalPlayer.DisplayName or "You"

	-- header shortcut back to trails
	local back = UIKit.Button({ Text = "TRAILS", Colors = UIKit.Colors.Purple, Size = UDim2.fromOffset(170, 52), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0, 42), CornerRadius = 6, ZIndex = 70, Parent = content.Parent, OnClick = function()
		ctx.HUD.OpenMenu("Trails")
	end })
	back.ZIndex = 70

	-- big preview of the equipped plate
	local previewHolder = UIKit.Create("Frame", { BackgroundColor3 = RGB(30, 32, 48), Size = UDim2.new(1, 0, 0, 110), ZIndex = 52, Parent = content })
	UIKit.Corner(previewHolder, 10)
	UIKit.Stroke(previewHolder, 4, UIKit.Outline, true)
	local previewLabel = UIKit.Label({ Text = "Equipped", Size = UDim2.fromOffset(200, 30), Position = UDim2.fromOffset(18, 40), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2.5, ZIndex = 54, Parent = previewHolder })
	previewLabel.TextColor3 = RGB(200, 205, 230)
	local preview = nil
	local previewKey = nil
	local function showPreview(key)
		if key == previewKey then
			return
		end
		previewKey = key
		if preview then
			preview:Destroy()
		end
		preview = Nameplate.Build(key, { Parent = previewHolder, Text = myName, Size = UDim2.fromOffset(450, 86), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 55 })
	end

	local grid = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -124), Position = UDim2.fromOffset(0, 124), Parent = content })
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(318, 176), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
	UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), Parent = grid })

	local cards = {}
	for i, key in ipairs(NameplateConfig.Order) do
		local cfg = NameplateConfig.Plates[key]
		local colors = NameplateConfig.RarityColors[cfg.Rarity] or UIKit.Colors.Gray
		local card = UIKit.Create("Frame", { Name = key, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, ZIndex = 52, Parent = grid })
		UIKit.Corner(card, 8)
		UIKit.Stroke(card, 4, UIKit.Outline, true)
		UIKit.Gradient(card, { colors[1]:Lerp(RGB(40, 42, 60), 0.55), colors[2]:Lerp(RGB(25, 26, 40), 0.6) }, 90)
		UIKit.Label({ Text = cfg.Name, Size = UDim2.new(0.62, -10, 0, 30), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3, ZIndex = 54, Parent = card })
		local rarity = UIKit.Label({ Text = cfg.Rarity, Size = UDim2.new(0.38, -10, 0, 24), Position = UDim2.new(0.62, 0, 0, 9), TextXAlignment = Enum.TextXAlignment.Right, StrokeThickness = 2.5, ZIndex = 54, Parent = card })
		rarity.TextColor3 = colors[1]
		Nameplate.Build(key, { Parent = card, Text = myName, Size = UDim2.new(1, -24, 0, 58), Position = UDim2.fromOffset(12, 42), ZIndex = 55 })
		local button, label = UIKit.Button({ Text = "", Colors = GREEN, CornerRadius = 4, Size = UDim2.new(1, -24, 0, 50), Position = UDim2.new(0, 12, 1, -60), ZIndex = 58, Parent = card, OnClick = function()
			local data = State.Data
			if owns(data, key) then
				if data.EquippedPlate ~= key then
					ctx.HUD.Result(State.Action("EquipPlate", key))
				end
			else
				ctx.HUD.Result(State.Action("BuyPlate", key))
			end
		end })
		cards[key] = { Cfg = cfg, Button = button, Label = label }
	end

	local menu = { Panel = panel }
	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		local equipped = owns(data, data.EquippedPlate) and data.EquippedPlate or NameplateConfig.Default
		showPreview(equipped)
		for key, c in pairs(cards) do
			if equipped == key then
				c.Label.Text = "EQUIPPED"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Gray)
			elseif owns(data, key) then
				c.Label.Text = "EQUIP"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Blue)
			else
				c.Label.Text = priceText(c.Cfg)
				local colors
				if c.Cfg.Product then
					colors = { RGB(235, 110, 255), RGB(165, 30, 230) }
				elseif c.Cfg.Req then
					colors = UIKit.Colors.Dark
				elseif c.Cfg.Currency == "Gems" then
					colors = (State.Gems or 0) >= c.Cfg.Cost and UIKit.Colors.Cyan or UIKit.Colors.Gray
				else
					colors = (State.Coins or 0) >= (c.Cfg.Cost or 0) and GREEN or UIKit.Colors.Gray
				end
				UIKit.SetButtonColors(c.Button, colors)
			end
		end
	end
	menu.Tick = menu.Refresh
	Prices.OnUpdated(function()
		if panel.IsOpen() then
			menu.Refresh()
		end
	end)
	return menu
end

return NameplatesMenu
