--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > UpgradesMenu (ModuleScript)

	Upgrades as a 2-column grid of colorful cards: icon bubble, name, level bar, "now ➜ next" and a
	big price button (gold "MAX" when maxed).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local UpgradesMenu = {}

local CARD_COLORS = {
	RayPower = UIKit.Colors.Yellow,
	Treadmill = UIKit.Colors.Green,
	MultiShrink = UIKit.Colors.Orange,
	ChargeSpeed = UIKit.Colors.Cyan,
	Range = UIKit.Colors.Red,
	Luck = UIKit.Colors.Purple,
	MuseumSize = UIKit.Colors.Blue,
}

function UpgradesMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Upgrades", Emoji = "⚡", Size = UDim2.fromOffset(920, 640), Colors = UIKit.Colors.Cyan })
	local grid = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -18), Position = UDim2.fromOffset(0, 18), Parent = panel.Content })
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(420, 168), CellPadding = UDim2.fromOffset(14, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = grid })

	local cards = {}
	for i, id in ipairs(UpgradeConfig.Order) do
		local u = UpgradeConfig.Upgrades[id]
		local colors = CARD_COLORS[id] or UIKit.Colors.Blue
		local card = UIKit.Card({ LayoutOrder = i, Colors = { colors[1]:Lerp(Color3.new(1, 1, 1), 0.55), colors[1]:Lerp(Color3.new(1, 1, 1), 0.2) }, Parent = grid, CornerRadius = 22, StrokeThickness = 4 })
		-- icon bubble
		local bubble = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(92, 92), Position = UDim2.fromOffset(14, 14), Parent = card })
		UIKit.Corner(bubble, UDim.new(1, 0))
		UIKit.Stroke(bubble, 4, UIKit.Outline, true)
		UIKit.Gradient(bubble, colors)
		UIKit.Label({ Text = u.Emoji, StrokeThickness = 0, Size = UDim2.new(0.7, 0, 0.7, 0), Position = UDim2.fromScale(0.15, 0.15), Parent = bubble })
		local level = UIKit.Card({ Size = UDim2.fromOffset(70, 28), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(60, 108), Colors = UIKit.Colors.Dark, Parent = card, CornerRadius = 14, StrokeThickness = 3 })
		local levelLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), StrokeThickness = 2, Parent = level })
		-- text
		UIKit.Label({ Text = u.Name, TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3.5, Size = UDim2.fromOffset(290, 34), Position = UDim2.fromOffset(120, 12), Parent = card })
		local value = UIKit.Label({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(255, 250, 200), StrokeThickness = 2.5, Size = UDim2.fromOffset(290, 26), Position = UDim2.fromOffset(120, 48), Parent = card })
		local bar = UIKit.ProgressBar({ Size = UDim2.fromOffset(280, 18), Position = UDim2.fromOffset(122, 82), Colors = colors, Parent = card })
		local button, buttonLabel = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(280, 50), Position = UDim2.fromOffset(122, 106), CornerRadius = 16, Parent = card, OnClick = function()
			local result = State.Action("BuyUpgrade", id)
			if result.ok then
				UIKit.PlaySound("Reward", 0.3)
				UIKit.Pop(card, 1.06)
			else
				ctx.HUD.Result(result)
			end
		end })
		cards[id] = { U = u, Value = value, Bar = bar, Level = levelLabel, Button = button, ButtonLabel = buttonLabel }
	end

	local menu = { Panel = panel }

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		for id, c in pairs(cards) do
			local lv = data.Upgrades[id] or 1
			local cost = Formulas.UpgradeCost(id, lv)
			local now = c.U.Format(c.U.Value(lv))
			c.Level.Text = "Lv " .. lv
			c.Bar.Set(lv / c.U.MaxLevel, lv .. " / " .. c.U.MaxLevel)
			if cost then
				c.Value.Text = now .. "  ➜  " .. c.U.Format(c.U.Value(lv + 1))
				c.ButtonLabel.Text = Format.Coins(cost)
				UIKit.SetButtonColors(c.Button, State.Coins >= cost and UIKit.Colors.Green or UIKit.Colors.Gray)
			else
				c.Value.Text = now
				c.ButtonLabel.Text = "⭐ MAX"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Yellow)
			end
		end
	end

	menu.Tick = menu.Refresh

	function menu.Badge()
		local data = State.Data
		if not data then
			return nil
		end
		local n = 0
		for _, id in ipairs(UpgradeConfig.Order) do
			local cost = Formulas.UpgradeCost(id, data.Upgrades[id] or 1)
			if cost and State.Coins >= cost then
				n += 1
			end
		end
		return n > 0 and n or nil
	end

	return menu
end

return UpgradesMenu
