--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > MuseumMenu (ModuleScript)

	Pocket Museum: income summary, collection list (sell), Auto Shrink & Raid toggles,
	teleports, raid shield / revenge info.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local TierConfig = require(Shared.Config.TierConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local MuseumMenu = {}

local MAX_ROWS = 120

function MuseumMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Pocket Museum", Emoji = "🏛️", Size = UDim2.fromOffset(940, 620), Colors = UIKit.Colors.Orange })
	local content = panel.Content

	local summary = UIKit.Label({ Text = "", TextColor3 = Color3.fromRGB(255, 180, 60), StrokeThickness = 3, Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 16), Parent = content })

	-- controls row
	local controls = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 58), Parent = content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = controls })
	local autoButton, autoLabel = UIKit.Button({ Text = "", Colors = UIKit.Colors.Gray, Size = UDim2.fromOffset(200, 46), LayoutOrder = 1, Parent = controls, OnClick = function()
		local data = State.Data
		if not State.HasPass("AutoShrink") then
			ctx.HUD.Result(State.Action("PromptPass", "AutoShrink"))
			return
		end
		ctx.HUD.Result(State.Action("SetAutoShrink", not data.Settings.AutoShrink))
	end })
	local raidButton, raidLabel = UIKit.Button({ Text = "", Colors = UIKit.Colors.Gray, Size = UDim2.fromOffset(200, 46), LayoutOrder = 2, Parent = controls, OnClick = function()
		ctx.HUD.Result(State.Action("SetRaidEnabled", not State.Data.Settings.RaidEnabled))
	end })
	UIKit.Button({ Text = "🏠 My Museum", Colors = UIKit.Colors.Orange, Size = UDim2.fromOffset(190, 46), LayoutOrder = 3, Parent = controls, OnClick = function()
		ctx.HUD.Result(State.Action("Teleport", "Museum"))
		panel.Close()
	end })
	UIKit.Button({ Text = "🏙️ Lobby", Colors = UIKit.Colors.Blue, Size = UDim2.fromOffset(150, 46), LayoutOrder = 4, Parent = controls, OnClick = function()
		ctx.HUD.Result(State.Action("Teleport", "Lobby"))
		panel.Close()
	end })

	-- teleport row (Teleport gamepass)
	local tpRow = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 114), Parent = content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = tpRow })
	local tpButtons = {}
	for tier, t in ipairs(TierConfig.Tiers) do
		tpButtons[tier] = UIKit.Button({ Text = "🌀 " .. t.Area, Colors = { t.Color:Lerp(Color3.new(1, 1, 1), 0.3), t.Color }, Size = UDim2.fromOffset(138, 40), LayoutOrder = tier, Parent = tpRow, OnClick = function()
			if not State.HasPass("Teleport") then
				ctx.HUD.Result(State.Action("PromptPass", "Teleport"))
				return
			end
			local result = State.Action("Teleport", tier)
			ctx.HUD.Result(result)
			if result.ok then
				panel.Close()
			end
		end })
	end

	local raidInfo = UIKit.Label({ Text = "", TextColor3 = Color3.fromRGB(230, 80, 80), StrokeThickness = 0, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 162), Parent = content })

	local list = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -196), Position = UDim2.fromOffset(0, 194), Parent = content })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = list })

	local menu = { Panel = panel }
	local lastListKey = nil

	local function renderList(data)
		local displayed = {}
		for _, uid in ipairs(data.DisplayedUids or {}) do
			displayed[uid] = true
		end
		local key = #data.Items .. ":" .. (data.NextUid or 0) .. ":" .. #(data.DisplayedUids or {}) .. ":" .. math.floor((data.Multipliers and data.Multipliers.Income or 1) * 100)
		if key == lastListKey then
			return
		end
		lastListKey = key
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local mult = data.Multipliers and data.Multipliers.Income or 1
		local sorted = Formulas.SortItems(data.Items)
		for i = 1, math.min(#sorted, MAX_ROWS) do
			local item = sorted[i]
			local def = ObjectConfig.Get(item.Id)
			local variant = RarityConfig.GetVariant(item.V)
			local rarity = RarityConfig.GetRarity(def and def.Rarity)
			local onDisplay = displayed[item.U]
			local row = UIKit.Card({ Size = UDim2.new(1, -16, 0, 54), LayoutOrder = i, Colors = onDisplay and { Color3.fromRGB(255, 252, 235), Color3.fromRGB(255, 240, 200) } or nil, Parent = list, CornerRadius = 12 })
			UIKit.Label({ Text = def and def.Emoji or "📦", StrokeThickness = 0, Size = UDim2.fromOffset(40, 40), Position = UDim2.fromOffset(8, 7), Parent = row })
			UIKit.Label({ Text = Formulas.ItemName(item) .. (item.S and " 📋" or ""), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = variant.Color or rarity.Color, StrokeThickness = 2.5, Size = UDim2.fromOffset(330, 30), Position = UDim2.fromOffset(56, 4), Parent = row })
			UIKit.Label({ Text = (def and def.Rarity or "?") .. "  ·  +" .. Format.Coins(Formulas.ItemBaseIncome(item) * mult) .. "/s", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(100, 100, 120), StrokeThickness = 0, Size = UDim2.fromOffset(330, 20), Position = UDim2.fromOffset(56, 32), Parent = row })
			if onDisplay then
				UIKit.Label({ Text = "🏛️ ON DISPLAY", TextColor3 = Color3.fromRGB(255, 170, 40), StrokeThickness = 2, Size = UDim2.fromOffset(170, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -190, 0.5, 0), Parent = row })
			end
			if not (def and def.Exclusive) then
				local value = Formulas.ItemBaseIncome(item) * mult * GameConfig.SellSeconds
				UIKit.Button({ Text = "Sell " .. Format.Coins(value), Colors = UIKit.Colors.Red, Size = UDim2.fromOffset(170, 42), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = row, OnClick = function()
					UIKit.Confirm(ctx.Screen, "Sell?", "Sell " .. Formulas.ItemName(item) .. " for " .. Format.Coins(value) .. "?", function()
						ctx.HUD.Result(State.Action("SellItem", item.U))
					end)
				end })
			end
		end
		if #sorted > MAX_ROWS then
			UIKit.Label({ Text = "+" .. (#sorted - MAX_ROWS) .. " more in your pocket...", TextColor3 = Color3.fromRGB(110, 110, 130), StrokeThickness = 0, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = MAX_ROWS + 1, Parent = list })
		end
	end

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		local stats = data.Stats
		summary.Text = string.format("💰 %s/s   ·   🏛️ %d/%d displayed   ·   👜 %d/%d in pocket", Format.Coins(State.Income), math.min(#data.Items, stats.Pedestals), stats.Pedestals, #data.Items, GameConfig.MaxItems)

		if State.HasPass("AutoShrink") then
			autoLabel.Text = "🤖 Auto: " .. (data.Settings.AutoShrink and "ON" or "OFF")
			UIKit.SetButtonColors(autoButton, data.Settings.AutoShrink and UIKit.Colors.Green or UIKit.Colors.Gray)
		else
			autoLabel.Text = "🤖 Auto Shrink 🔒"
			UIKit.SetButtonColors(autoButton, UIKit.Colors.Dark)
		end
		raidLabel.Text = "🏴‍☠️ Raids: " .. (data.Settings.RaidEnabled and "ON" or "OFF")
		UIKit.SetButtonColors(raidButton, data.Settings.RaidEnabled and UIKit.Colors.Red or UIKit.Colors.Gray)

		for tier, b in pairs(tpButtons) do
			local unlocked = Formulas.IsTierUnlocked(data, tier)
			b.Visible = unlocked
		end

		local now = State.Now()
		local parts = {}
		if not stats.RaidReady then
			table.insert(parts, "Raiding requires MAX Ray Power")
		end
		if data.Raid.ShieldUntil > now then
			table.insert(parts, "🛡️ Shield " .. Format.Clock(data.Raid.ShieldUntil - now))
		end
		for _, r in ipairs(data.RevengeTargets or {}) do
			table.insert(parts, "😈 Revenge on " .. r.Name .. " " .. Format.Clock(r.Expires - now))
		end
		raidInfo.Text = table.concat(parts, "   ·   ")

		renderList(data)
	end

	menu.Tick = menu.Refresh

	panel.OnOpen:Connect(function()
		lastListKey = nil
	end)

	function menu.Badge()
		local data = State.Data
		local n = data and data.RevengeTargets and #data.RevengeTargets or 0
		return n > 0 and n or nil
	end

	return menu
end

return MuseumMenu
