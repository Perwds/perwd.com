--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > InventoryMenu (ModuleScript)

	Inventory: what you own, as cards (3D preview, name in its variant color, rarity, size, weight,
	income). Identical items stack into one card ("x25"). Placed ones (earning in your plot) get a
	green "PLACED" badge with how many. Tabs: All / Placed / Pocket, a search box, and pages.
	Per card: Place / Unplace one + Sell one.
	Top: Place Best, Sell Unplaced, and a shortcut to the old Plot & Raids page.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local InventoryMenu = {}

local RGB = Color3.fromRGB
local PER_PAGE = 20
local GREEN = RGB(90, 230, 110)

function InventoryMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Inventory", Emoji = "🎒", Size = UDim2.fromOffset(1080, 660) })
	local content = panel.Content

	-- ── top bar: counts + actions ────────────────────────────────────
	local counts = UIKit.Label({ Text = "", Size = UDim2.new(0, 420, 0, 34), Position = UDim2.fromOffset(4, 0), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3, ZIndex = 55, Parent = content })
	local income = UIKit.Label({ Text = "", Size = UDim2.new(0, 420, 0, 24), Position = UDim2.fromOffset(4, 34), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = RGB(150, 255, 130), StrokeThickness = 2.5, ZIndex = 55, Parent = content })
	local actions = UIKit.Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(600, 52), ZIndex = 55, Parent = content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 10), Parent = actions })
	UIKit.Button({ Text = "Place Best", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(170, 50), CornerRadius = 8, ZIndex = 56, Parent = actions, OnClick = function()
		ctx.HUD.Result(State.Action("EquipBest"))
	end })
	UIKit.Button({ Text = "Sell Unplaced", Colors = UIKit.Colors.Red, Size = UDim2.fromOffset(190, 50), CornerRadius = 8, ZIndex = 56, Parent = actions, OnClick = function()
		UIKit.Confirm(ctx.Screen, "Sell?", "Sell everything that isn't placed in your plot? (Exclusives are kept.)", function()
			ctx.HUD.Result(State.Action("SellPocket"))
		end)
	end })
	UIKit.Button({ Text = "Plot & Raids", Colors = UIKit.Colors.Orange, Size = UDim2.fromOffset(190, 50), CornerRadius = 8, ZIndex = 56, Parent = actions, OnClick = function()
		ctx.HUD.OpenMenu("Museum")
	end })

	-- ── tabs + search ────────────────────────────────────────────────
	local filter = "All"
	local query = ""
	local page = 1
	local tabButtons = {}
	local tabRow = UIKit.Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 64), Size = UDim2.new(1, 0, 0, 46), ZIndex = 55, Parent = content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = tabRow })
	local render -- forward
	for i, name in ipairs({ "All", "Placed", "Pocket" }) do
		local b, label = UIKit.Button({ Text = name, Colors = UIKit.Colors.Gray, Size = UDim2.fromOffset(140, 44), LayoutOrder = i, CornerRadius = 8, ZIndex = 56, Parent = tabRow, OnClick = function()
			filter = name
			page = 1
			render(true)
		end })
		tabButtons[name] = { Button = b, Label = label }
	end
	local search = UIKit.Create("TextBox", { PlaceholderText = "Search...", Text = "", Font = UIKit.Font, TextScaled = true, ClearTextOnFocus = false, TextColor3 = UIKit.Outline, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(260, 42), LayoutOrder = 4, ZIndex = 56, Parent = tabRow })
	UIKit.Corner(search, 8)
	UIKit.Stroke(search, 3, UIKit.Outline)
	UIKit.Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), Parent = search })
	search:GetPropertyChangedSignal("Text"):Connect(function()
		query = string.lower(search.Text)
		page = 1
		render(true)
	end)

	-- ── grid + pager ─────────────────────────────────────────────────
	local grid = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -172), Position = UDim2.fromOffset(0, 118), Parent = content })
	grid.ZIndex = 54
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(190, 246), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
	UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), Parent = grid })
	local emptyLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 220), StrokeThickness = 3, ZIndex = 55, Parent = content })
	local pager = UIKit.Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(420, 48), ZIndex = 55, Parent = content })
	local pageLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -220, 1, -8), Position = UDim2.fromOffset(110, 4), StrokeThickness = 3, ZIndex = 56, Parent = pager })
	UIKit.Button({ Text = "<", Colors = UIKit.Colors.Blue, Size = UDim2.fromOffset(96, 46), CornerRadius = 8, ZIndex = 56, Parent = pager, OnClick = function()
		page = math.max(1, page - 1)
		render(true)
	end })
	UIKit.Button({ Text = ">", Colors = UIKit.Colors.Blue, Size = UDim2.fromOffset(96, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), CornerRadius = 8, ZIndex = 56, Parent = pager, OnClick = function()
		page += 1
		render(true)
	end })

	-- stack = { Item (first), Count, Placed = {uids}, Pocket = {uids} }
	local function card(stack, order, mult)
		local item = stack.Item
		local placed = #stack.Placed > 0
		local def = ObjectConfig.Get(item.Id)
		local rarity = RarityConfig.GetRarity(def and def.Rarity)
		local variant = RarityConfig.GetVariant(item.V)
		local mutation = item.M and MutationConfig.Get(item.M)
		local accent = rarity.Color or RGB(200, 200, 210)
		-- very dark rarity colors (Secret) would be unreadable on the dark card
		local textAccent = accent
		if accent.R + accent.G + accent.B < 0.9 then
			textAccent = RGB(225, 225, 235)
		end
		local c = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, ZIndex = 55, Parent = grid })
		UIKit.Corner(c, 12)
		UIKit.Stroke(c, 4, placed and RGB(40, 150, 60) or accent:Lerp(Color3.new(0, 0, 0), 0.45), true)
		UIKit.Gradient(c, { accent:Lerp(RGB(60, 64, 82), 0.55), RGB(36, 38, 52) }, 90)
		-- preview square
		local box = UIKit.Create("Frame", { BackgroundColor3 = RGB(28, 30, 42), Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 104), ZIndex = 56, Parent = c })
		UIKit.Corner(box, 10)
		UIKit.ModelPreview({ Id = item.Id, Variant = item.V, Size = UDim2.fromScale(1, 1), ZIndex = 57, Parent = box })
		if placed then
			local badge = UIKit.Create("Frame", { BackgroundColor3 = GREEN, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(stack.Count > 1 and 96 or 76, 22), ZIndex = 58, Parent = box })
			UIKit.Corner(badge, 6)
			UIKit.Stroke(badge, 2, UIKit.Outline, true)
			UIKit.Label({ Text = stack.Count > 1 and (#stack.Placed .. " PLACED") or "PLACED", Size = UDim2.new(1, -6, 1, -4), Position = UDim2.fromOffset(3, 2), StrokeThickness = 2, ZIndex = 59, Parent = badge })
		end
		if stack.Count > 1 then
			local count = UIKit.Create("Frame", { BackgroundColor3 = RGB(255, 210, 60), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -6), Size = UDim2.fromOffset(52, 24), ZIndex = 58, Parent = box })
			UIKit.Corner(count, 6)
			UIKit.Stroke(count, 2, UIKit.Outline, true)
			UIKit.Label({ Text = "x" .. stack.Count, Size = UDim2.new(1, -6, 1, -4), Position = UDim2.fromOffset(3, 2), StrokeThickness = 2, ZIndex = 59, Parent = count })
		end
		if mutation then
			local tag = UIKit.Create("Frame", { BackgroundColor3 = mutation.Color or RGB(255, 255, 255), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(70, 22), ZIndex = 58, Parent = box })
			UIKit.Corner(tag, 6)
			UIKit.Stroke(tag, 2, UIKit.Outline, true)
			UIKit.Label({ Text = "x" .. tostring(mutation.Mult), Size = UDim2.new(1, -6, 1, -4), Position = UDim2.fromOffset(3, 2), StrokeThickness = 2, ZIndex = 59, Parent = tag })
		end
		UIKit.Label({ Text = Formulas.FormatWeight(Formulas.ItemWeight(item)), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -4), Size = UDim2.fromOffset(80, 20), TextXAlignment = Enum.TextXAlignment.Right, StrokeThickness = 2, ZIndex = 58, Parent = box })
		-- text
		local name = UIKit.Label({ Text = Formulas.ItemName(item), Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 118), StrokeThickness = 2.5, ZIndex = 56, Parent = c })
		name.TextColor3 = variant.Color or Color3.new(1, 1, 1)
		UIKit.Label({ Text = (def and def.Rarity or "?") .. "  ·  size x" .. string.format("%.1f", item.Z or 1), Size = UDim2.new(1, -16, 0, 20), Position = UDim2.fromOffset(8, 144), TextColor3 = textAccent, StrokeThickness = 2, ZIndex = 56, Parent = c })
		UIKit.Label({ Text = "+" .. Format.Coins(Formulas.ItemBaseIncome(item) * mult) .. "/s", Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 164), TextColor3 = RGB(150, 255, 130), StrokeThickness = 2.5, ZIndex = 56, Parent = c })
		-- buttons
		local exclusive = def and def.Exclusive
		local wide = UDim2.new(exclusive and 1 or 0.62, exclusive and -16 or -12, 0, 44)
		-- Place while some are still in your pocket, otherwise Unplace
		local canPlace = #stack.Pocket > 0
		UIKit.Button({ Text = canPlace and "Place" or "Unplace", Colors = canPlace and UIKit.Colors.Green or UIKit.Colors.Red, Size = wide, Position = UDim2.new(0, 8, 1, -52), CornerRadius = 8, ZIndex = 57, Parent = c, OnClick = function()
			if canPlace then
				ctx.HUD.Result(State.Action("PlaceItem", stack.Pocket[1]))
			else
				ctx.HUD.Result(State.Action("UnplaceItem", stack.Placed[1]))
			end
		end })
		if not exclusive then
			local value = Formulas.ItemBaseIncome(item) * mult * GameConfig.SellSeconds
			UIKit.Button({ Text = "Sell", Colors = UIKit.Colors.Yellow, Size = UDim2.new(0.38, -8, 0, 44), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 1, -52), CornerRadius = 8, ZIndex = 57, Parent = c, OnClick = function()
				local uid = stack.Pocket[1] or stack.Placed[1]
				UIKit.Confirm(ctx.Screen, "Sell?", "Sell 1 " .. Formulas.ItemName(item) .. " for " .. Format.Coins(value) .. "?", function()
					ctx.HUD.Result(State.Action("SellItem", uid))
				end)
			end })
		end
	end

	local lastKey
	function render(force)
		local data = State.Data
		if not data then
			return
		end
		local placedSet = {}
		for _, uid in ipairs(data.DisplayedUids or {}) do
			placedSet[uid] = true
		end
		local mult = data.Multipliers and data.Multipliers.Income or 1
		local stats = data.Stats or {}
		local placedCount = #(data.DisplayedUids or {})
		counts.Text = string.format("Placed %d / %d   ·   Pocket %d / %d", placedCount, stats.Pedestals or 0, #data.Items, GameConfig.MaxItems)
		income.Text = "Earning " .. Format.Coins(State.Income or 0) .. "/s"
		for name, t in pairs(tabButtons) do
			UIKit.SetButtonColors(t.Button, name == filter and UIKit.Colors.Blue or UIKit.Colors.Gray)
		end
		-- what to show
		-- identical items stack into one card
		local stacks, byKey = {}, {}
		for _, item in ipairs(Formulas.SortItems(data.Items)) do
			local k = table.concat({ item.Id, item.V or "", item.M or "", string.format("%.2f", item.Z or 1), item.S and "S" or "" }, "|")
			local st = byKey[k]
			if not st then
				st = { Item = item, Count = 0, Placed = {}, Pocket = {} }
				byKey[k] = st
				table.insert(stacks, st)
			end
			st.Count += 1
			table.insert(placedSet[item.U] and st.Placed or st.Pocket, item.U)
		end
		local list = {}
		for _, st in ipairs(stacks) do
			local keep = filter == "All" or (filter == "Placed" and #st.Placed > 0) or (filter == "Pocket" and #st.Pocket > 0)
			if keep and query ~= "" then
				keep = string.find(string.lower(Formulas.ItemName(st.Item)), query, 1, true) ~= nil
			end
			if keep then
				table.insert(list, st)
			end
		end
		local pages = math.max(1, math.ceil(#list / PER_PAGE))
		page = math.clamp(page, 1, pages)
		local key = table.concat({ filter, query, page, #data.Items, data.NextUid or 0, placedCount, math.floor(mult * 100) }, "|")
		if not force and key == lastKey then
			return
		end
		lastKey = key
		for _, ch in ipairs(grid:GetChildren()) do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		if force then
			grid.CanvasPosition = Vector2.zero
		end
		for i = (page - 1) * PER_PAGE + 1, math.min(#list, page * PER_PAGE) do
			card(list[i], i, mult)
		end
		pageLabel.Text = "Page " .. page .. " / " .. pages
		pager.Visible = pages > 1
		emptyLabel.Text = #list == 0 and (filter == "Placed" and "Nothing placed yet: press Place on an item!" or "Nothing here yet. Go shrink some boxes!") or ""
	end

	local menu = { Panel = panel }
	function menu.Refresh()
		render(false)
	end
	menu.Tick = menu.Refresh
	panel.OnOpen:Connect(function()
		lastKey = nil
	end)
	return menu
end

return InventoryMenu
