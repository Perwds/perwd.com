--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > AdminMenu (ModuleScript)

	Admin panel — only built for the accounts in GameConfig.Admins (the server checks every
	request again, so hiding this UI is just for looks). Opened with the red ADMIN button.
	Tabs: Items (3D grid, filters, variant/mutation/size/amount), Money, Passes, Players, World.
	"Target" at the top picks who gets things: you or anyone in the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local EventConfig = require(Shared.Config.EventConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local TierConfig = require(Shared.Config.TierConfig)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local AdminMenu = {}

local RGB = Color3.fromRGB
local PER_PAGE = 18

function AdminMenu.Build(ctx)
	local check = State.Action("AdminCheck")
	if not (check and check.ok) then
		return nil
	end

	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Admin Panel", Emoji = "🛠️", Size = UDim2.fromOffset(1100, 680) })
	local content = panel.Content

	local opener = UIKit.Button({ Text = "ADMIN", Colors = UIKit.Colors.Red, Size = UDim2.fromOffset(120, 46), Position = UDim2.new(0, 236, 0, 10), CornerRadius = 10, Parent = ctx.Screen, OnClick = function()
		ctx.HUD.OpenMenu("Admin")
	end })
	UIKit.AutoScale(opener)

	-- ── target (who receives things) ──────────────────────────────────
	local targetId = nil -- nil = me
	local targetLabel
	local function targetName()
		local p = targetId and Players:GetPlayerByUserId(targetId)
		if not p then
			targetId = nil
			return "Me"
		end
		return p.DisplayName
	end
	local targetButton
	targetButton, targetLabel = UIKit.Button({ Text = "Target: Me", Colors = UIKit.Colors.Purple, Size = UDim2.fromOffset(280, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), CornerRadius = 8, ZIndex = 60, Parent = content, OnClick = function()
		-- cycle: me → each other player → me
		local list = { false }
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= Players.LocalPlayer then
				table.insert(list, p.UserId)
			end
		end
		local index = 1
		for i, id in ipairs(list) do
			if (id or nil) == targetId then
				index = i
			end
		end
		local nextId = list[index % #list + 1]
		targetId = nextId or nil
		targetLabel.Text = "Target: " .. targetName()
	end })
	local _ = targetButton
	local function act(name, ...)
		ctx.HUD.Result(State.Action(name, ...))
	end

	-- ── tabs ─────────────────────────────────────────────────────────
	local pages = {}
	local tabButtons = {}
	local tabColumn = UIKit.Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(0, 150, 1, -56), ZIndex = 55, Parent = content })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 10), Parent = tabColumn })
	local body = UIKit.Create("Frame", { BackgroundColor3 = UIKit.PanelCard, Position = UDim2.fromOffset(162, 56), Size = UDim2.new(1, -162, 1, -56), ZIndex = 52, Parent = content })
	UIKit.Corner(body, 10)
	UIKit.Stroke(body, 4, UIKit.Outline, true)
	local function showTab(name)
		for n, f in pairs(pages) do
			f.Visible = n == name
		end
		for n, b in pairs(tabButtons) do
			UIKit.SetButtonColors(b, n == name and UIKit.Colors.Yellow or UIKit.Colors.Gray)
		end
	end
	local function tab(name, order)
		tabButtons[name] = UIKit.Button({ Text = name, Colors = UIKit.Colors.Gray, Size = UDim2.new(1, 0, 0, 52), LayoutOrder = order, CornerRadius = 8, ZIndex = 56, Parent = tabColumn, OnClick = function()
			showTab(name)
		end })
		local page = UIKit.Create("Frame", { Name = name, BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 1, -24), Visible = false, ZIndex = 53, Parent = body })
		pages[name] = page
		return page
	end
	local function buttonGrid(page, cell)
		local g = UIKit.Scroll({ Size = UDim2.fromScale(1, 1), Parent = page })
		g.ZIndex = 54
		UIKit.Create("UIGridLayout", { CellSize = cell or UDim2.fromOffset(250, 56), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = g })
		return g
	end

	-- ══ ITEMS ══
	local items = tab("Items", 1)
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
	local sizes = { 1, 1.5, 2, 3, 5, 10 }
	local counts = { 1, 5, 10, 25 }
	local pick = { V = 1, M = 1, S = 1, C = 1 }
	local optRow = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), ZIndex = 55, Parent = items })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = optRow })
	local function cycler(key, list, fmt, colors)
		local b, label
		b, label = UIKit.Button({ Text = fmt(list[1]), Colors = colors, Size = UDim2.fromOffset(196, 42), CornerRadius = 8, ZIndex = 56, Parent = optRow, OnClick = function()
			pick[key] = pick[key] % #list + 1
			label.Text = fmt(list[pick[key]])
		end })
		return b
	end
	cycler("V", variants, function(v)
		return "Variant: " .. v
	end, UIKit.Colors.Yellow)
	cycler("M", mutations, function(m)
		return "Mutation: " .. m
	end, UIKit.Colors.Purple)
	cycler("S", sizes, function(z)
		return "Size: x" .. z
	end, UIKit.Colors.Blue)
	cycler("C", counts, function(c)
		return "Amount: " .. c
	end, UIKit.Colors.Green)

	local filterRow = UIKit.Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 40), ZIndex = 55, Parent = items })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = filterRow })
	local zone = 0 -- 0 = all, 99 = exclusives
	local query = ""
	local page = 1
	local renderItems
	local zoneButtons = {}
	for _, z in ipairs({ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 99 }) do
		zoneButtons[z] = UIKit.Button({ Text = z == 0 and "All" or z == 99 and "Excl." or tostring(z), Colors = UIKit.Colors.Gray, Size = UDim2.fromOffset(z == 0 and 56 or z == 99 and 66 or 40, 38), CornerRadius = 6, ZIndex = 56, Parent = filterRow, OnClick = function()
			zone = z
			page = 1
			renderItems()
		end })
	end
	local search = UIKit.Create("TextBox", { PlaceholderText = "Search items...", Text = "", Font = UIKit.Font, TextScaled = true, ClearTextOnFocus = false, TextColor3 = UIKit.Outline, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(200, 38), ZIndex = 56, Parent = filterRow })
	UIKit.Corner(search, 6)
	UIKit.Stroke(search, 3, UIKit.Outline)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		query = string.lower(search.Text)
		page = 1
		renderItems()
	end)

	local itemGrid = UIKit.Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 1, -150), ZIndex = 54, Parent = items })
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(140, 136), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = itemGrid })
	local pager = UIKit.Create("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(380, 44), ZIndex = 55, Parent = items })
	local pageLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -200, 1, -8), Position = UDim2.fromOffset(100, 4), StrokeThickness = 3, ZIndex = 56, Parent = pager })
	UIKit.Button({ Text = "<", Colors = UIKit.Colors.Blue, Size = UDim2.fromOffset(90, 42), CornerRadius = 8, ZIndex = 56, Parent = pager, OnClick = function()
		page = math.max(1, page - 1)
		renderItems()
	end })
	UIKit.Button({ Text = ">", Colors = UIKit.Colors.Blue, Size = UDim2.fromOffset(90, 42), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), CornerRadius = 8, ZIndex = 56, Parent = pager, OnClick = function()
		page += 1
		renderItems()
	end })

	function renderItems()
		for z, b in pairs(zoneButtons) do
			UIKit.SetButtonColors(b, z == zone and UIKit.Colors.Yellow or UIKit.Colors.Gray)
		end
		local list = {}
		for _, id in ipairs(ObjectConfig.AllIds()) do
			local def = ObjectConfig.Get(id)
			local keep = zone == 0 or (zone == 99 and def.Exclusive) or (not def.Exclusive and def.Tier == zone)
			if keep and query ~= "" then
				keep = string.find(string.lower((def.Name or id) .. " " .. id .. " " .. (def.Rarity or "")), query, 1, true) ~= nil
			end
			if keep then
				table.insert(list, id)
			end
		end
		local pages = math.max(1, math.ceil(#list / PER_PAGE))
		page = math.clamp(page, 1, pages)
		pageLabel.Text = "Page " .. page .. " / " .. pages .. "  (" .. #list .. ")"
		for _, ch in ipairs(itemGrid:GetChildren()) do
			if ch:IsA("GuiObject") then
				ch:Destroy()
			end
		end
		for i = (page - 1) * PER_PAGE + 1, math.min(#list, page * PER_PAGE) do
			local id = list[i]
			local def = ObjectConfig.Get(id)
			local color = (RarityConfig.Rarities[def.Rarity] or RarityConfig.Rarities.Common).Color
			local card = UIKit.Create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, ZIndex = 55, Parent = itemGrid })
			UIKit.Corner(card, 10)
			UIKit.Stroke(card, 4, color:Lerp(Color3.new(0, 0, 0), 0.45), true)
			UIKit.Gradient(card, { color:Lerp(RGB(60, 64, 82), 0.5), RGB(34, 36, 50) }, 90)
			UIKit.ModelPreview({ Id = id, Size = UDim2.new(1, -12, 0, 84), Position = UDim2.fromOffset(6, 4), ZIndex = 56, Parent = card })
			UIKit.Label({ Text = def.Name or id, Size = UDim2.new(1, -10, 0, 22), Position = UDim2.fromOffset(5, 88), StrokeThickness = 2.5, ZIndex = 57, Parent = card })
			UIKit.Label({ Text = (def.Rarity or "") .. (def.Exclusive and "  ·  Excl." or ("  ·  Zone " .. tostring(def.Tier))), Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 110), TextColor3 = color, StrokeThickness = 2, ZIndex = 57, Parent = card })
			UIKit.Bouncy(card, 1.05)
			card.Activated:Connect(function()
				UIKit.PlaySound("Click", 0.4)
				local mut = mutations[pick.M]
				act("AdminSpawnItem", id, variants[pick.V], mut ~= "None" and mut or nil, sizes[pick.S], counts[pick.C], targetId)
			end)
		end
	end

	-- ══ MONEY ══
	local money = buttonGrid(tab("Money", 2))
	local infOn = false
	local infButton, infLabel
	infButton, infLabel = UIKit.Button({ Text = "Infinite Cash: OFF", Colors = UIKit.Colors.Gray, LayoutOrder = 0, CornerRadius = 8, ZIndex = 56, Parent = money, OnClick = function()
		infOn = not infOn
		infLabel.Text = infOn and "Infinite Cash: ON" or "Infinite Cash: OFF"
		UIKit.SetButtonColors(infButton, infOn and UIKit.Colors.Green or UIKit.Colors.Gray)
		act("AdminInfiniteCash", infOn)
	end })
	local gifts = {
		{ "+1 Million Coins", "Coins", 1e6, UIKit.Colors.Yellow }, { "+1 Billion Coins", "Coins", 1e9, UIKit.Colors.Yellow },
		{ "+1 Trillion Coins", "Coins", 1e12, UIKit.Colors.Yellow }, { "+1 Quadrillion", "Coins", 1e15, UIKit.Colors.Orange },
		{ "+1,000 Gems", "Gems", 1000, UIKit.Colors.Cyan }, { "+100,000 Gems", "Gems", 100000, UIKit.Colors.Cyan },
		{ "+10 Rebirth Tokens", "Tokens", 10, UIKit.Colors.Green }, { "+1,000 Tokens", "Tokens", 1000, UIKit.Colors.Green },
		{ "+1,000 Samples", "Samples", 1000, UIKit.Colors.Purple },
	}
	for i, g in ipairs(gifts) do
		UIKit.Button({ Text = g[1], Colors = g[4], LayoutOrder = i, CornerRadius = 8, ZIndex = 56, Parent = money, OnClick = function()
			act("AdminGive", g[2], g[3], targetId)
		end })
	end

	-- ══ PASSES ══
	local passes = buttonGrid(tab("Passes", 3))
	for i, key in ipairs(MonetizationConfig.PassOrder) do
		local pass = MonetizationConfig.GamePasses[key]
		if pass then
			UIKit.Button({ Text = "Give " .. pass.Name, Colors = UIKit.Colors.Yellow, LayoutOrder = i, CornerRadius = 8, ZIndex = 56, Parent = passes, OnClick = function()
				act("AdminGrantPass", key, targetId)
			end })
		end
	end

	-- ══ PLAYERS ══
	local playersPage = tab("Players", 4)
	local playerGrid = buttonGrid(playersPage, UDim2.fromOffset(250, 56))
	local tools = {
		{ "Max All Upgrades", function()
			act("AdminMaxUpgrades", targetId)
		end, UIKit.Colors.Green },
		{ "Clear Unplaced Items", function()
			UIKit.Confirm(ctx.Screen, "Clear?", "Remove every unplaced item from " .. targetName() .. "?", function()
				act("AdminClearPocket", targetId)
			end)
		end, UIKit.Colors.Red },
		{ "Teleport To Target", function()
			if targetId then
				act("AdminTeleport", tostring(targetId))
			end
		end, UIKit.Colors.Blue },
	}
	local godOn = false
	for i, t in ipairs(tools) do
		UIKit.Button({ Text = t[1], Colors = t[3], LayoutOrder = i, CornerRadius = 8, ZIndex = 56, Parent = playerGrid, OnClick = t[2] })
	end
	local godButton, godLabel
	godButton, godLabel = UIKit.Button({ Text = "God Mode: OFF", Colors = UIKit.Colors.Gray, LayoutOrder = 10, CornerRadius = 8, ZIndex = 56, Parent = playerGrid, OnClick = function()
		godOn = not godOn
		godLabel.Text = godOn and "God Mode: ON" or "God Mode: OFF"
		UIKit.SetButtonColors(godButton, godOn and UIKit.Colors.Green or UIKit.Colors.Gray)
		act("AdminGod", godOn)
	end })

	-- ══ WORLD ══
	local world = buttonGrid(tab("World", 5))
	UIKit.Button({ Text = "Summon Boss Now", Colors = UIKit.Colors.Red, LayoutOrder = 0, CornerRadius = 8, ZIndex = 56, Parent = world, OnClick = function()
		act("AdminSummonBoss")
	end })
	for i, key in ipairs(EventConfig.Rotation) do
		local ev = EventConfig.Events[key]
		UIKit.Button({ Text = "Start " .. (ev and ev.Name or key), Colors = UIKit.Colors.Pink, LayoutOrder = i, CornerRadius = 8, ZIndex = 56, Parent = world, OnClick = function()
			act("AdminStartEvent", key)
		end })
	end
	for tier, t in ipairs(TierConfig.Tiers) do
		UIKit.Button({ Text = "Go to " .. t.Area, Colors = { t.Color:Lerp(Color3.new(1, 1, 1), 0.3), t.Color }, LayoutOrder = 100 + tier, CornerRadius = 8, ZIndex = 56, Parent = world, OnClick = function()
			act("AdminTeleport", tier)
		end })
	end

	showTab("Items")
	local menu = { Panel = panel }
	local built = false
	function menu.Refresh()
		targetLabel.Text = "Target: " .. targetName()
		if not built then
			built = true
			renderItems()
		end
	end
	return menu
end

return AdminMenu
