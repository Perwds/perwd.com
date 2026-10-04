--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > AdminMenu (ModuleScript)

	Admin panel — only built for the accounts in GameConfig.Admins (the server checks every
	request again, so hiding this UI is just for looks). Opened with the red ADMIN button.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local EventConfig = require(Shared.Config.EventConfig)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local AdminMenu = {}

local _RGB = Color3.fromRGB

function AdminMenu.Build(ctx)
	local check = State.Action("AdminCheck")
	if not (check and check.ok) then
		return nil
	end

	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Admin Panel", Emoji = "🛠️", Size = UDim2.fromOffset(1000, 600) })
	local content = panel.Content

	-- opener button (top right, under the top bar)
	local opener = UIKit.Button({ Text = "ADMIN", Colors = UIKit.Colors.Red, Size = UDim2.fromOffset(120, 46), AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, 236, 0, 10), CornerRadius = 10, Parent = ctx.Screen, OnClick = function()
		ctx.HUD.OpenMenu("Admin")
	end })
	UIKit.AutoScale(opener)

	local function act(name, ...)
		ctx.HUD.Result(State.Action(name, ...))
	end

	-- ── left column: money + world ─────────────────────────────────
	local left = UIKit.Create("Frame", { BackgroundColor3 = UIKit.PanelCard, Size = UDim2.new(0, 300, 1, 0), ZIndex = 52, Parent = content })
	UIKit.Corner(left, 10)
	UIKit.Stroke(left, 4, UIKit.Outline, true)
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = left })
	UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 10), Parent = left })
	local order = 0
	local function title(text)
		order += 1
		UIKit.Label({ Text = text, Size = UDim2.new(1, -20, 0, 28), LayoutOrder = order, StrokeThickness = 3, ZIndex = 54, Parent = left })
	end
	local function button(text, colors, onClick)
		order += 1
		local b, label = UIKit.Button({ Text = text, Colors = colors, Size = UDim2.new(1, -24, 0, 44), LayoutOrder = order, CornerRadius = 8, ZIndex = 54, Parent = left, OnClick = onClick })
		return b, label
	end
	title("Money")
	local infOn = false
	local infButton, infLabel
	infButton, infLabel = button("Infinite Cash: OFF", UIKit.Colors.Gray, function()
		infOn = not infOn
		infLabel.Text = infOn and "Infinite Cash: ON" or "Infinite Cash: OFF"
		UIKit.SetButtonColors(infButton, infOn and UIKit.Colors.Green or UIKit.Colors.Gray)
		act("AdminInfiniteCash", infOn)
	end)
	button("+1 Trillion Coins", UIKit.Colors.Yellow, function()
		act("AdminGive", "Coins", 1e12)
	end)
	button("+10,000 Gems", UIKit.Colors.Cyan, function()
		act("AdminGive", "Gems", 10000)
	end)
	button("+100 Rebirth Tokens", UIKit.Colors.Green, function()
		act("AdminGive", "Tokens", 100)
	end)
	button("+1,000 Samples", UIKit.Colors.Purple, function()
		act("AdminGive", "Samples", 1000)
	end)
	title("World")
	button("Summon Boss", UIKit.Colors.Red, function()
		act("AdminSummonBoss")
	end)
	local eventKeys = table.clone(EventConfig.Rotation)
	local eventIndex = 1
	local _, eventLabel
	local eventButton
	eventButton, eventLabel = button("Event: " .. (EventConfig.Events[eventKeys[1]].Name or eventKeys[1]), UIKit.Colors.Orange, function()
		eventIndex = eventIndex % #eventKeys + 1
		eventLabel.Text = "Event: " .. (EventConfig.Events[eventKeys[eventIndex]].Name or eventKeys[eventIndex])
	end)
	button("Start That Event", UIKit.Colors.Pink, function()
		act("AdminStartEvent", eventKeys[eventIndex])
	end)
	local _ = eventButton

	-- ── right side: spawn any item ─────────────────────────────────
	local right = UIKit.Create("Frame", { BackgroundColor3 = UIKit.PanelCard, Size = UDim2.new(1, -316, 1, 0), Position = UDim2.fromOffset(316, 0), ZIndex = 52, Parent = content })
	UIKit.Corner(right, 10)
	UIKit.Stroke(right, 4, UIKit.Outline, true)
	UIKit.Label({ Text = "Spawn Any Item (click one)", Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 8), StrokeThickness = 3, ZIndex = 54, Parent = right })

	-- option cyclers
	local variants = RarityConfig.VariantOrder
	local mutations = { "None" }
	for _, m in ipairs(MutationConfig.Order) do
		table.insert(mutations, m)
	end
	local extra = {}
	for name in pairs(MutationConfig.Mutations) do
		if not table.find(mutations, name) then
			table.insert(extra, name)
		end
	end
	table.sort(extra)
	for _, name in ipairs(extra) do
		table.insert(mutations, name)
	end
	local sizes = { 1, 2, 3, 5, 10 }
	local counts = { 1, 5, 10, 25 }
	local pick = { V = 1, M = 1, S = 1, C = 1 }
	local function cycler(x, key, list, fmt, colors)
		local b, label
		b, label = UIKit.Button({ Text = fmt(list[1]), Colors = colors, Size = UDim2.fromOffset(150, 40), Position = UDim2.fromOffset(x, 44), CornerRadius = 8, ZIndex = 54, Parent = right, OnClick = function()
			pick[key] = pick[key] % #list + 1
			label.Text = fmt(list[pick[key]])
		end })
		return b
	end
	cycler(10, "V", variants, function(v)
		return "Variant: " .. v
	end, UIKit.Colors.Yellow)
	cycler(168, "M", mutations, function(m)
		return "Mut: " .. m
	end, UIKit.Colors.Purple)
	cycler(326, "S", sizes, function(z)
		return "Size: x" .. z
	end, UIKit.Colors.Blue)
	cycler(484, "C", counts, function(c)
		return "Amount: " .. c
	end, UIKit.Colors.Green)

	local search = UIKit.Create("TextBox", { PlaceholderText = "Search items...", Text = "", Font = UIKit.Font, TextScaled = true, ClearTextOnFocus = false, TextColor3 = UIKit.Outline, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, -20, 0, 38), Position = UDim2.fromOffset(10, 92), ZIndex = 54, Parent = right })
	UIKit.Corner(search, 8)
	UIKit.Stroke(search, 3, UIKit.Outline)

	local list = UIKit.Scroll({ Size = UDim2.new(1, -20, 1, -144), Position = UDim2.fromOffset(10, 138), Parent = right })
	list.ZIndex = 54
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(150, 46), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local entries = {}
	for i, id in ipairs(ObjectConfig.AllIds()) do
		local def = ObjectConfig.Get(id)
		local colors = RarityConfig.Rarities and RarityConfig.Rarities[def.Rarity] and RarityConfig.Rarities[def.Rarity].Color
		local c = typeof(colors) == "Color3" and { colors:Lerp(Color3.new(1, 1, 1), 0.3), colors } or UIKit.Colors.Gray
		local b = UIKit.Button({ Text = def.Name or id, Colors = c, Size = UDim2.fromOffset(150, 46), LayoutOrder = i, CornerRadius = 8, ZIndex = 56, Parent = list, OnClick = function()
			local mut = mutations[pick.M]
			act("AdminSpawnItem", id, variants[pick.V], mut ~= "None" and mut or nil, sizes[pick.S], counts[pick.C])
		end })
		table.insert(entries, { Button = b, Text = string.lower((def.Name or id) .. " " .. id .. " " .. (def.Rarity or "")) })
	end
	search:GetPropertyChangedSignal("Text"):Connect(function()
		local q = string.lower(search.Text)
		for _, e in ipairs(entries) do
			e.Button.Visible = q == "" or string.find(e.Text, q, 1, true) ~= nil
		end
	end)

	return { Panel = panel }
end

return AdminMenu
