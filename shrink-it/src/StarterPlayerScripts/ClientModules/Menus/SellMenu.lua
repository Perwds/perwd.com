--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > SellMenu (ModuleScript)

	Opened from the 💰 SELL stand. Sell everything in your pocket (not on display) in one click,
	or sell single objects. Exclusive "Huge" objects are never sold.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local SellMenu = {}

local MAX_ROWS = 80

function SellMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Sell", Style = "Header", Size = UDim2.fromOffset(840, 640), Colors = { Color3.fromRGB(255, 90, 80), Color3.fromRGB(200, 20, 30) } })
	local content = panel.Content

	local summary = UIKit.Label({ Text = "", TextColor3 = Color3.fromRGB(255, 120, 110), StrokeThickness = 3, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 18), Parent = content })
	local sellAll, sellAllLabel = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(460, 64), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Parent = content, OnClick = function()
		ctx.HUD.Result(State.Action("SellPocket"))
	end })
	UIKit.Label({ Text = "Objects on display are kept. Huge exclusives are never sold.", TextColor3 = Color3.fromRGB(210, 210, 225), StrokeThickness = 2, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 128), Parent = content })

	local list = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -164), Position = UDim2.fromOffset(0, 160), Parent = content })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = list })

	local menu = { Panel = panel }
	local lastKey

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		local displayed = {}
		for _, uid in ipairs(data.DisplayedUids or {}) do
			displayed[uid] = true
		end
		local mult = data.Multipliers and data.Multipliers.Income or 1
		local pocket, total = {}, 0
		for _, item in ipairs(data.Items) do
			local def = ObjectConfig.Get(item.Id)
			if not displayed[item.U] and not (def and def.Exclusive) then
				table.insert(pocket, item)
				total += Formulas.ItemBaseIncome(item) * mult * GameConfig.SellSeconds
			end
		end
		summary.Text = string.format("👜 %d object%s in your pocket (not on display)", #pocket, #pocket == 1 and "" or "s")
		sellAllLabel.Text = #pocket > 0 and ("💰 SELL ALL for " .. Format.Coins(total)) or "Nothing to sell"
		UIKit.SetButtonColors(sellAll, #pocket > 0 and UIKit.Colors.Green or UIKit.Colors.Gray)

		local key = #data.Items .. ":" .. (data.NextUid or 0) .. ":" .. #pocket
		if key == lastKey then
			return
		end
		lastKey = key
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local sorted = Formulas.SortItems(pocket)
		for i = 1, math.min(#sorted, MAX_ROWS) do
			local item = sorted[i]
			local variant = RarityConfig.GetVariant(item.V)
			local value = Formulas.ItemBaseIncome(item) * mult * GameConfig.SellSeconds
			local row = UIKit.Card({ Size = UDim2.new(1, -16, 0, 52), LayoutOrder = i, Parent = list, CornerRadius = 12 })
			UIKit.ModelPreview({ Id = item.Id, Variant = item.V, Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(6, 3), Parent = row })
			UIKit.Label({ Text = Formulas.ItemName(item), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = variant.Color or Color3.fromRGB(60, 60, 80), StrokeThickness = variant.Color and 2 or 0, Size = UDim2.fromOffset(420, 32), Position = UDim2.fromOffset(56, 10), Parent = row })
			UIKit.Button({ Text = "Sell " .. Format.Coins(value), Colors = UIKit.Colors.Red, Size = UDim2.fromOffset(180, 40), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = row, OnClick = function()
				ctx.HUD.Result(State.Action("SellItem", item.U))
			end })
		end
	end

	panel.OnOpen:Connect(function()
		lastKey = nil
	end)

	return menu
end

return SellMenu
