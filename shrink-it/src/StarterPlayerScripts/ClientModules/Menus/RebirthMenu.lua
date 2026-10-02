--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > RebirthMenu (ModuleScript)

	Rebirth for a permanent multiplier + Gems + Rebirth Tokens, and the Token upgrade shop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)
local Prices = require(Modules.Prices)

local RebirthMenu = {}

function RebirthMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Rebirth", Emoji = "♻️", Size = UDim2.fromOffset(820, 620), Colors = UIKit.Colors.Green })
	local content = panel.Content

	local title = UIKit.Label({ Text = "", TextColor3 = Color3.fromRGB(110, 230, 120), StrokeThickness = 3.5, Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 16), Parent = content })
	local mult = UIKit.Label({ Text = "", TextColor3 = Color3.fromRGB(255, 210, 60), StrokeThickness = 3, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 64), Parent = content })
	local bar = UIKit.ProgressBar({ Size = UDim2.new(1, -80, 0, 38), Position = UDim2.fromOffset(40, 108), Colors = UIKit.Colors.Yellow, Parent = content })
	local rewards = UIKit.Label({ Text = "", TextColor3 = Color3.fromRGB(110, 200, 255), StrokeThickness = 3, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 154), Parent = content })
	UIKit.Label({ Text = "Resets Coins & upgrades. KEEPS all your objects, spots, speed, Gems & Tokens.", TextColor3 = Color3.fromRGB(110, 110, 130), StrokeThickness = 0, Size = UDim2.new(1, -40, 0, 26), Position = UDim2.fromOffset(20, 190), Parent = content })

	local rebirthButton, rebirthLabel = UIKit.Button({ Text = "REBIRTH!", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(260, 64), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(0.5, -10, 0, 226), Parent = content, OnClick = function()
		UIKit.Confirm(ctx.Screen, "Rebirth?", "Your coins, upgrades and museum will reset for a permanent boost. Continue?", function()
			ctx.HUD.Result(State.Action("Rebirth"))
		end)
	end })
	local instant = MonetizationConfig.Products.InstantRebirth
	local _, instantLabel = UIKit.Button({ Text = "", Colors = UIKit.Colors.Purple, Size = UDim2.fromOffset(260, 64), AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0.5, 10, 0, 226), Parent = content, OnClick = function()
		ctx.HUD.Result(State.Action("BuyInstantRebirth"))
	end })

	UIKit.Label({ Text = "♻️ Rebirth Token Upgrades (permanent)", TextColor3 = Color3.fromRGB(120, 255, 160), StrokeThickness = 3, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 304), Parent = content })
	local rows = {}
	for i, id in ipairs(UpgradeConfig.TokenOrder) do
		local u = UpgradeConfig.TokenUpgrades[id]
		local row = UIKit.Card({ Size = UDim2.new(1, -20, 0, 62), Position = UDim2.fromOffset(10, 342 + (i - 1) * 70), Parent = content, CornerRadius = 14 })
		UIKit.Label({ Text = u.Emoji, StrokeThickness = 0, Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(10, 9), Parent = row })
		UIKit.Label({ Text = u.Name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Outline, StrokeThickness = 0, Size = UDim2.fromOffset(260, 28), Position = UDim2.fromOffset(62, 4), Parent = row })
		local info = UIKit.Label({ Text = "", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(110, 110, 130), StrokeThickness = 0, Size = UDim2.fromOffset(360, 24), Position = UDim2.fromOffset(62, 32), Parent = row })
		local button, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(170, 46), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = row, OnClick = function()
			ctx.HUD.Result(State.Action("BuyTokenUpgrade", id))
		end })
		rows[id] = { Info = info, Button = button, Label = label, U = u }
	end

	local menu = { Panel = panel }

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		local cost = Formulas.RebirthCost(data.Rebirths)
		local r = Formulas.RebirthRewards(data.Rebirths)
		title.Text = "Rebirths: " .. data.Rebirths
		mult.Text = string.format("Income x%.1f  ➜  x%.1f", Formulas.RebirthMultiplier(data.Rebirths), Formulas.RebirthMultiplier(data.Rebirths + 1))
		bar.Set(State.Coins / cost, Format.Coins(State.Coins) .. " / " .. Format.Coins(cost))
		rewards.Text = "Rewards: +" .. r.Gems .. " 💎   +" .. r.Tokens .. " ♻️"
		local can = State.Coins >= cost
		rebirthLabel.Text = can and "REBIRTH!" or "Need " .. Format.Coins(cost)
		UIKit.SetButtonColors(rebirthButton, can and UIKit.Colors.Green or UIKit.Colors.Gray)
		instantLabel.Text = "⚡ Instant " .. Prices.Get(Enum.InfoType.Product, instant.Id, instant.PriceLabel)
		for id, row in pairs(rows) do
			local level = data.TokenUpgrades[id]
			local tcost = Formulas.TokenUpgradeCost(id, level)
			row.Info.Text = row.U.Description .. "  ·  Lv " .. level .. "/" .. row.U.MaxLevel
			if not tcost then
				row.Label.Text = "MAXED"
				UIKit.SetButtonColors(row.Button, UIKit.Colors.Gray)
			else
				row.Label.Text = "♻️ " .. tcost
				UIKit.SetButtonColors(row.Button, State.Tokens >= tcost and UIKit.Colors.Green or UIKit.Colors.Gray)
			end
		end
	end

	menu.Tick = menu.Refresh

	function menu.Badge()
		local data = State.Data
		if data and State.Coins >= Formulas.RebirthCost(data.Rebirths) then
			return "!"
		end
		return nil
	end

	return menu
end

return RebirthMenu
