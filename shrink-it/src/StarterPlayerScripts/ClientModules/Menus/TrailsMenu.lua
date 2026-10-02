--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > TrailsMenu (ModuleScript)

	Opened from the 🌈 TRAILS stand. Buy trails with Coins or Gems (Rainbow comes with the Rainbow Ray pass),
	then equip one. Config: MonetizationConfig.Trails.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Format = require(Shared.Format)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local TrailsMenu = {}

function TrailsMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Trails", Emoji = "🌈", Size = UDim2.fromOffset(880, 600), Colors = UIKit.Colors.Green })
	local content = panel.Content
	local grid = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -84), Position = UDim2.fromOffset(0, 18), Parent = content })
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(196, 200), CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 6), Parent = grid })

	UIKit.Button({ Text = "Unequip trail", Colors = UIKit.Colors.Gray, Size = UDim2.fromOffset(240, 52), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Parent = content, OnClick = function()
		ctx.HUD.Result(State.Action("EquipTrail", ""))
	end })

	local cards = {}
	for i, key in ipairs(MonetizationConfig.TrailOrder) do
		local cfg = MonetizationConfig.Trails[key]
		local card = UIKit.Card({ LayoutOrder = i, Colors = UIKit.Colors.White, Parent = grid, CornerRadius = 18 })
		local swatch = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -30, 0, 60), Position = UDim2.fromOffset(15, 14), Parent = card })
		UIKit.Corner(swatch, UDim.new(1, 0))
		UIKit.Stroke(swatch, 3, UIKit.Outline, true)
		if cfg.Rainbow then
			UIKit.Create("UIGradient", { Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 60)),
				ColorSequenceKeypoint.new(0.66, Color3.fromRGB(60, 160, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 80, 255)),
			}), Parent = swatch })
		else
			UIKit.Gradient(swatch, cfg.Colors, 0)
		end
		UIKit.Label({ Text = cfg.Name, TextColor3 = Color3.fromRGB(60, 60, 80), StrokeThickness = 0, Size = UDim2.new(1, -16, 0, 30), Position = UDim2.fromOffset(8, 82), Parent = card })
		local price = cfg.Pass and ("🎟️ " .. MonetizationConfig.GamePasses[cfg.Pass].Name) or (cfg.Currency == "Coins" and Format.Coins(cfg.Cost) or ("💎 " .. Format.Abbrev(cfg.Cost)))
		UIKit.Label({ Text = price, TextColor3 = Color3.fromRGB(110, 110, 130), StrokeThickness = 0, Size = UDim2.new(1, -16, 0, 24), Position = UDim2.fromOffset(8, 112), Parent = card })
		local button, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, Size = UDim2.new(1, -24, 0, 44), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Parent = card, OnClick = function()
			local data = State.Data
			local owned = cfg.Pass and State.HasPass(cfg.Pass) or (data and data.Trails and data.Trails[key])
			if owned then
				ctx.HUD.Result(State.Action("EquipTrail", key))
			elseif cfg.Pass then
				ctx.HUD.Result(State.Action("PromptPass", cfg.Pass))
			else
				ctx.HUD.Result(State.Action("BuyTrail", key))
			end
		end })
		cards[key] = { Button = button, Label = label, Cfg = cfg }
	end

	local menu = { Panel = panel }

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		for key, c in pairs(cards) do
			local owned = c.Cfg.Pass and State.HasPass(c.Cfg.Pass) or (data.Trails and data.Trails[key])
			if data.EquippedTrail == key then
				c.Label.Text = "EQUIPPED ✔"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Gray)
			elseif owned then
				c.Label.Text = "EQUIP"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Blue)
			elseif c.Cfg.Pass then
				c.Label.Text = "GET PASS"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Yellow)
			else
				local have = c.Cfg.Currency == "Coins" and State.Coins or State.Gems
				c.Label.Text = "BUY"
				UIKit.SetButtonColors(c.Button, have >= c.Cfg.Cost and UIKit.Colors.Green or UIKit.Colors.Gray)
			end
		end
	end

	menu.Tick = menu.Refresh
	return menu
end

return TrailsMenu
