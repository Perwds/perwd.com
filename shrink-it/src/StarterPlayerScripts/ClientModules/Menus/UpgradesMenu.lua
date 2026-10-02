--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > UpgradesMenu (ModuleScript)

	Ray upgrades: Ray Power, Run Speed, Carry Capacity, Charge Speed, Range, Luck, Museum Size.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local TierConfig = require(Shared.Config.TierConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local UpgradesMenu = {}

function UpgradesMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Upgrades", Emoji = "⚡", Size = UDim2.fromOffset(900, 620), Colors = UIKit.Colors.Cyan })
	local list = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -18), Position = UDim2.fromOffset(0, 18), Parent = panel.Content })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = list })
	UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8), Parent = list })

	local rows = {}
	for i, id in ipairs(UpgradeConfig.Order) do
		local u = UpgradeConfig.Upgrades[id]
		local row = UIKit.Card({ Size = UDim2.new(1, -20, 0, 74), LayoutOrder = i, Parent = list, CornerRadius = 16 })
		UIKit.Label({ Text = u.Emoji, StrokeThickness = 0, Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(10, 10), Parent = row })
		UIKit.Label({ Text = u.Name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(60, 180, 230), StrokeThickness = 2.5, Size = UDim2.fromOffset(300, 32), Position = UDim2.fromOffset(74, 4), Parent = row })
		local info = UIKit.Label({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(90, 90, 110), StrokeThickness = 0, Size = UDim2.fromOffset(470, 28), Position = UDim2.fromOffset(74, 38), Parent = row })
		local button, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(200, 54), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Parent = row, OnClick = function()
			local result = State.Action("BuyUpgrade", id)
			if not result.ok then
				ctx.HUD.Result(result)
			else
				UIKit.PlaySound("Reward", 0.3)
			end
		end })
		rows[id] = { Info = info, Button = button, Label = label, U = u }
	end

	local menu = { Panel = panel }

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		for id, row in pairs(rows) do
			local level = data.Upgrades[id]
			local cost = Formulas.UpgradeCost(id, level)
			local now = row.U.Format(row.U.Value(level))
			if cost then
				row.Info.Text = string.format("Lv %d/%d  ·  %s ➜ %s", level, row.U.MaxLevel, now, row.U.Format(row.U.Value(level + 1)))
				row.Label.Text = Format.Coins(cost)
				UIKit.SetButtonColors(row.Button, State.Coins >= cost and UIKit.Colors.Green or UIKit.Colors.Gray)
			else
				row.Info.Text = string.format("Lv %d/%d  ·  %s", level, row.U.MaxLevel, now)
				row.Label.Text = "MAXED"
				UIKit.SetButtonColors(row.Button, UIKit.Colors.Yellow)
			end
			if id == "RayPower" then
				local tier = TierConfig.MaxTierForRayPower(level)
				row.Info.Text ..= "  ·  shrinks " .. TierConfig.Tiers[tier].Name
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
			local cost = Formulas.UpgradeCost(id, data.Upgrades[id])
			if cost and State.Coins >= cost then
				n += 1
			end
		end
		return n > 0 and n or nil
	end

	return menu
end

return UpgradesMenu
