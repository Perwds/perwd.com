--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > GiftingMenu (ModuleScript)

	"Gift": buy a Robux item for another player in this server. Pick a player (left), pick an item
	(right), press its price. The server remembers who it's for and gives it to them when the
	purchase goes through (gamepasses are gifted with their GiftPass_ product).
	Config: MonetizationConfig.GiftOrder.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)
local Prices = require(Modules.Prices)

local GiftingMenu = {}

local RGB = Color3.fromRGB

function GiftingMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Send a Gift", Emoji = "💝", Size = UDim2.fromOffset(1000, 600) })
	local content = panel.Content
	local selected = nil -- Player

	-- players
	local left = UIKit.Create("Frame", { BackgroundColor3 = UIKit.PanelCard, Size = UDim2.new(0, 300, 1, 0), ZIndex = 52, Parent = content })
	UIKit.Corner(left, 10)
	UIKit.Stroke(left, 4, UIKit.Outline, true)
	UIKit.Label({ Text = "1. Pick a player", Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 8), StrokeThickness = 3, ZIndex = 54, Parent = left })
	local list = UIKit.Scroll({ Size = UDim2.new(1, -16, 1, -56), Position = UDim2.fromOffset(8, 48), Parent = left })
	list.ZIndex = 54
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.Name, Parent = list })
	local empty = UIKit.Label({ Text = "Nobody else is in this server yet.", Size = UDim2.new(1, -20, 0, 60), Position = UDim2.fromOffset(10, 60), StrokeThickness = 2.5, ZIndex = 55, Parent = left })

	-- items
	local right = UIKit.Create("Frame", { BackgroundColor3 = UIKit.PanelCard, Size = UDim2.new(1, -316, 1, 0), Position = UDim2.fromOffset(316, 0), ZIndex = 52, Parent = content })
	UIKit.Corner(right, 10)
	UIKit.Stroke(right, 4, UIKit.Outline, true)
	local header = UIKit.Label({ Text = "2. Pick a gift", Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 8), StrokeThickness = 3, ZIndex = 54, Parent = right })
	local grid = UIKit.Scroll({ Size = UDim2.new(1, -16, 1, -56), Position = UDim2.fromOffset(8, 48), Parent = right })
	grid.ZIndex = 54
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(196, 132), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })

	local giftButtons = {}
	for i, key in ipairs(MonetizationConfig.GiftOrder) do
		local product = MonetizationConfig.Products[key]
		if product then
			local isPass = product.Handler == "GiftPass"
			local pass = isPass and MonetizationConfig.GamePasses[product.Pass]
			local name = isPass and pass and pass.Name or product.Name
			local emoji = (pass and pass.Emoji) or (product.Emoji ~= "" and product.Emoji) or "🎁"
			local colors = isPass and { RGB(255, 225, 90), RGB(240, 150, 20) } or { RGB(150, 220, 255), RGB(60, 130, 230) }
			local card = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, ZIndex = 55, Parent = grid })
			UIKit.Corner(card, 10)
			UIKit.Stroke(card, 4, colors[2]:Lerp(Color3.new(0, 0, 0), 0.5), true)
			UIKit.Gradient(card, colors, 90)
			UIKit.Icon({ Icon = { Emoji = emoji }, Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(8, 8), ZIndex = 56, Parent = card })
			UIKit.Label({ Text = name, Size = UDim2.new(1, -66, 0, 46), Position = UDim2.fromOffset(58, 8), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3, ZIndex = 56, Parent = card })
			local button, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.new(0, 10, 1, -60), CornerRadius = 8, ZIndex = 57, Parent = card, OnClick = function()
				if not selected or not selected.Parent then
					ctx.HUD.Notify("Pick a player first!", "error")
					return
				end
				ctx.HUD.Result(State.Action("GiftProduct", selected.UserId, key))
			end })
			local function price()
				label.Text = tostring(Prices.Get(Enum.InfoType.Product, product.Id, product.PriceLabel))
			end
			price()
			Prices.OnUpdated(price)
			giftButtons[key] = button
		end
	end

	local rows = {}
	local function rebuild()
		for _, r in pairs(rows) do
			r:Destroy()
		end
		table.clear(rows)
		local count = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= Players.LocalPlayer then
				count += 1
				local row = UIKit.Create("TextButton", { Name = p.DisplayName, Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -10, 0, 64), ZIndex = 56, Parent = list })
				UIKit.Corner(row, 10)
				local stroke = UIKit.Stroke(row, 4, UIKit.Outline, true)
				UIKit.Gradient(row, selected == p and { RGB(140, 255, 120), RGB(40, 190, 60) } or { RGB(230, 232, 240), RGB(170, 175, 195) }, 90)
				local head = UIKit.Create("ImageLabel", { BackgroundColor3 = RGB(60, 64, 80), Size = UDim2.fromOffset(50, 50), Position = UDim2.fromOffset(7, 7), Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", p.UserId), ZIndex = 57, Parent = row })
				UIKit.Corner(head, UDim.new(1, 0))
				UIKit.Label({ Text = p.DisplayName, Size = UDim2.new(1, -72, 0, 30), Position = UDim2.fromOffset(66, 6), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2.5, ZIndex = 57, Parent = row })
				UIKit.Label({ Text = "@" .. p.Name, Size = UDim2.new(1, -72, 0, 20), Position = UDim2.fromOffset(66, 36), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2, ZIndex = 57, Parent = row })
				stroke.Color = selected == p and RGB(20, 90, 20) or UIKit.Outline
				row.Activated:Connect(function()
					selected = p
					header.Text = "2. Pick a gift for " .. p.DisplayName
					rebuild()
				end)
				rows[p] = row
			end
		end
		empty.Visible = count == 0
		if selected and not selected.Parent then
			selected = nil
			header.Text = "2. Pick a gift"
		end
	end
	Players.PlayerAdded:Connect(function()
		if panel.IsOpen() then
			rebuild()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			if panel.IsOpen() then
				rebuild()
			end
		end)
	end)

	local menu = { Panel = panel }
	function menu.Refresh()
		rebuild()
	end
	return menu
end

return GiftingMenu
