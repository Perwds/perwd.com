--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > IndexMenu (ModuleScript)

	"The Index": every object × variant per area, with completion rewards.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local TierConfig = require(Shared.Config.TierConfig)
local RewardConfig = require(Shared.Config.RewardConfig)
local Formulas = require(Shared.Formulas)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local IndexMenu = {}

local VARIANT_EMOJI = { Normal = "⚪", Golden = "⭐", Diamond = "🔷", Rainbow = "🌈", Cosmic = "🌌" }

function IndexMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "The Index", Emoji = "📖", Size = UDim2.fromOffset(940, 620), Colors = UIKit.Colors.Blue })
	local content = panel.Content
	local selectedTier = 1

	-- 10 zones: the tab row scrolls sideways
	local tabs = UIKit.Scroll({ Horizontal = true, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 14), Parent = content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tabs })
	UIKit.Create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 3), Parent = tabs })

	local list = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -204), Position = UDim2.fromOffset(0, 80), Parent = content })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = list })
	UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 4), Parent = list })

	local footer = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 116), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Parent = content })
	local function milestoneRow(y, kind)
		local cfg = RewardConfig.IndexRewards[kind]
		UIKit.Label({ Text = kind == "Normal" and "All objects" or "All variants", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Outline, StrokeThickness = 0, Size = UDim2.fromOffset(170, 40), Position = UDim2.fromOffset(4, y), Parent = footer })
		local bar = UIKit.ProgressBar({ Size = UDim2.new(1, -420, 0, 36), Position = UDim2.fromOffset(180, y + 2), Colors = kind == "Normal" and UIKit.Colors.Green or UIKit.Colors.Purple, Parent = footer })
		local button, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Yellow, Size = UDim2.fromOffset(220, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, y - 3), Parent = footer, OnClick = function()
			ctx.HUD.Result(State.Action("ClaimIndex", selectedTier, kind))
		end })
		return { Bar = bar, Button = button, Label = label, Cfg = cfg }
	end
	local normalRow = milestoneRow(6, "Normal")
	local fullRow = milestoneRow(62, "Full")

	local tabButtons = {}
	local menu = { Panel = panel }

	local function renderList()
		local data = State.Data
		if not data then
			return
		end
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local ids = ObjectConfig.IdsForTier(selectedTier, false)
		-- exclusives are shown on the Tiny tab as a bonus section
		if selectedTier == 1 then
			for _, id in ipairs(ObjectConfig.AllIds()) do
				if ObjectConfig.Get(id).Exclusive then
					table.insert(ids, id)
				end
			end
		end
		for i, id in ipairs(ids) do
			local def = ObjectConfig.Get(id)
			local rarity = RarityConfig.GetRarity(def.Rarity)
			local anyOwned = false
			for _, v in ipairs(RarityConfig.VariantOrder) do
				if data.Index[Formulas.IndexKey(id, v)] then
					anyOwned = true
				end
			end
			local hidden = def.Rarity == "Secret" and not anyOwned
			local row = UIKit.Card({ Size = UDim2.new(1, -16, 0, 60), LayoutOrder = i, Parent = list, CornerRadius = 14 })
			if hidden then
				UIKit.Label({ Text = "❓", StrokeThickness = 0, Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(8, 7), Parent = row })
			else
				local preview = UIKit.ModelPreview({ Id = id, Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(4, 3), Parent = row })
				if not anyOwned then
					preview.ImageTransparency = 0.55 -- not collected yet
				end
			end
			UIKit.Label({ Text = hidden and "???" or def.Name, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rarity.Color, StrokeThickness = 2.5, Size = UDim2.fromOffset(250, 30), Position = UDim2.fromOffset(62, 4), Parent = row })
			UIKit.Label({ Text = def.Rarity .. (def.Exclusive and " · Exclusive" or ""), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.fromRGB(110, 110, 130), StrokeThickness = 0, Size = UDim2.fromOffset(250, 22), Position = UDim2.fromOffset(62, 34), Parent = row })
			for vi, v in ipairs(RarityConfig.VariantOrder) do
				local owned = data.Index[Formulas.IndexKey(id, v)]
				local variant = RarityConfig.Variants[v]
				local chip = UIKit.Card({ Size = UDim2.fromOffset(92, 44), Position = UDim2.new(1, -(6 - vi) * 100 - 4, 0, 8), Colors = owned and { (variant.Color or Color3.fromRGB(230, 230, 240)):Lerp(Color3.new(1, 1, 1), 0.3), variant.Color or Color3.fromRGB(190, 190, 205) } or UIKit.Colors.Dark, Parent = row, CornerRadius = 12 })
				UIKit.Label({ Text = owned and (VARIANT_EMOJI[v] .. " ✔") or "?", Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), StrokeThickness = 2, Parent = chip })
			end
		end
	end

	local function renderFooter()
		local data = State.Data
		if not data then
			return
		end
		local nh, nn, fh, fn = Formulas.IndexProgress(data, selectedTier)
		for _, pair in ipairs({ { normalRow, "Normal", nh, nn }, { fullRow, "Full", fh, fn } }) do
			local row, kind, have, need = pair[1], pair[2], pair[3], pair[4]
			row.Bar.Set(need > 0 and have / need or 0, have .. "/" .. need)
			local claimed = data.IndexClaimed[selectedTier .. ":" .. kind]
			local gems = row.Cfg.GemsPerTier * selectedTier
			if claimed then
				row.Label.Text = "✔ Claimed"
				UIKit.SetButtonColors(row.Button, UIKit.Colors.Gray)
			elseif have >= need and need > 0 then
				row.Label.Text = "CLAIM!"
				UIKit.SetButtonColors(row.Button, UIKit.Colors.Green)
			else
				row.Label.Text = string.format("💎%d +%d%%", gems, row.Cfg.IncomeBonus * 100)
				UIKit.SetButtonColors(row.Button, UIKit.Colors.Yellow)
			end
		end
	end

	for tier, t in ipairs(TierConfig.Tiers) do
		tabButtons[tier] = UIKit.Button({ Text = t.Area, Colors = { t.Color:Lerp(Color3.new(1, 1, 1), 0.3), t.Color }, Size = UDim2.fromOffset(138, 46), LayoutOrder = tier, Parent = tabs, OnClick = function()
			selectedTier = tier
			for k, b in pairs(tabButtons) do
				b.BounceScale.Scale = k == tier and 1.08 or 1
			end
			renderList()
			renderFooter()
		end })
	end

	local lastIndexCount = -1
	local seenPending = false
	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		local count = 0
		for _ in pairs(data.Index) do
			count += 1
		end
		if count ~= lastIndexCount then
			lastIndexCount = count
			renderList()
		end
		renderFooter()
		if data.IndexUnseen > 0 and not seenPending then
			seenPending = true
			task.spawn(function()
				State.Action("SeenIndex")
				seenPending = false
			end)
		end
	end

	panel.OnOpen:Connect(function()
		lastIndexCount = -1
	end)

	function menu.Badge()
		local data = State.Data
		if not data then
			return nil
		end
		local claimable = 0
		for tier in ipairs(TierConfig.Tiers) do
			local nh, nn, fh, fn = Formulas.IndexProgress(data, tier)
			if nn > 0 and nh >= nn and not data.IndexClaimed[tier .. ":Normal"] then
				claimable += 1
			end
			if fn > 0 and fh >= fn and not data.IndexClaimed[tier .. ":Full"] then
				claimable += 1
			end
		end
		if claimable > 0 then
			return claimable
		end
		return data.IndexUnseen > 0 and "NEW" or nil
	end

	return menu
end

return IndexMenu
