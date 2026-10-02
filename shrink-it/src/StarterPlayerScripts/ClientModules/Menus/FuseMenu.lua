--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > FuseMenu (ModuleScript)

	Opened from the ✨ FUSE stand. Fuse GameConfig.Fuse.Count identical objects (same object + variant)
	into ONE of the next variant: Normal → Golden (x5) → Diamond (x10) → Rainbow (x25) → Cosmic (x100).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Formulas = require(Shared.Formulas)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local FuseMenu = {}

local function nextVariant(v)
	for i, name in ipairs(RarityConfig.VariantOrder) do
		if name == v then
			return RarityConfig.VariantOrder[i + 1]
		end
	end
	return nil
end

function FuseMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Fuse", Emoji = "✨", Size = UDim2.fromOffset(860, 600), Colors = UIKit.Colors.Purple })
	local content = panel.Content
	local need = GameConfig.Fuse.Count
	UIKit.Label({ Text = string.format("Fuse %d of the same object → 1 of the next variant!", need), TextColor3 = Color3.fromRGB(150, 80, 230), StrokeThickness = 0, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 18), Parent = content })
	UIKit.Label({ Text = "Normal → 🌟 Golden x5 → 💎 Diamond x10 → 🌈 Rainbow x25 → 🌌 Cosmic x100", TextColor3 = Color3.fromRGB(110, 110, 130), StrokeThickness = 0, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 54), Parent = content })

	local list = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -96), Position = UDim2.fromOffset(0, 92), Parent = content })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = list })

	local menu = { Panel = panel }
	local lastKey

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		local key = #data.Items .. ":" .. (data.NextUid or 0)
		if key == lastKey then
			return
		end
		lastKey = key
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		-- group by object + variant
		local groups, order = {}, {}
		for _, item in ipairs(data.Items) do
			local k = item.Id .. ":" .. item.V
			if not groups[k] then
				groups[k] = { Id = item.Id, V = item.V, Count = 0 }
				table.insert(order, groups[k])
			end
			groups[k].Count += 1
		end
		table.sort(order, function(a, b)
			local fa, fb = a.Count >= need and nextVariant(a.V) ~= nil, b.Count >= need and nextVariant(b.V) ~= nil
			if fa ~= fb then
				return fa
			end
			return Formulas.ItemBaseIncome(a) > Formulas.ItemBaseIncome(b)
		end)
		if #order == 0 then
			UIKit.Label({ Text = "Shrink some objects first!", TextColor3 = Color3.fromRGB(110, 110, 130), StrokeThickness = 0, Size = UDim2.new(1, 0, 0, 40), Parent = list })
		end
		for i, g in ipairs(order) do
			local variant = RarityConfig.GetVariant(g.V)
			local nv = nextVariant(g.V)
			local ready = nv and g.Count >= need
			local row = UIKit.Card({ Size = UDim2.new(1, -16, 0, 60), LayoutOrder = i, Colors = ready and { Color3.fromRGB(250, 240, 255), Color3.fromRGB(230, 210, 255) } or nil, Parent = list, CornerRadius = 12 })
			UIKit.ModelPreview({ Id = g.Id, Variant = g.V, Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(4, 4), Parent = row })
			UIKit.Label({ Text = Formulas.ItemName({ Id = g.Id, V = g.V }) .. "  x" .. g.Count, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = variant.Color or Color3.fromRGB(60, 60, 80), StrokeThickness = variant.Color and 2 or 0, Size = UDim2.fromOffset(380, 30), Position = UDim2.fromOffset(60, 4), Parent = row })
			local bar = UIKit.ProgressBar({ Size = UDim2.fromOffset(260, 18), Position = UDim2.fromOffset(60, 36), Colors = UIKit.Colors.Purple, Parent = row })
			bar.Set(math.min(1, g.Count / need), math.min(g.Count, need) .. "/" .. need)
			local label = not nv and "MAX ✔" or ("FUSE → " .. RarityConfig.Variants[nv].Prefix:gsub(" $", ""))
			UIKit.Button({ Text = label, Colors = ready and UIKit.Colors.Purple or UIKit.Colors.Gray, Size = UDim2.fromOffset(220, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Parent = row, OnClick = function()
				if ready then
					ctx.HUD.Result(State.Action("FuseItems", g.Id, g.V))
				end
			end })
		end
	end

	panel.OnOpen:Connect(function()
		lastKey = nil
	end)

	return menu
end

return FuseMenu
