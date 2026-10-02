--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > FuseMenu (ModuleScript)

	"Fuse Machine" (opened from the FUSE machine in the base). Press a green + to pick an object,
	the 3 slots fill with your copies of it, the pipes feed the result in the middle, then FUSE.
	3 identical objects (same object + variant) → 1 of the next variant:
	Normal → Golden (x5) → Diamond (x10) → Rainbow (x25) → Cosmic (x100).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Formulas = require(Shared.Formulas)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local FuseMenu = {}

local RGB = Color3.fromRGB
local GREEN = { RGB(130, 255, 60), RGB(50, 200, 20) }
local PIPE = RGB(30, 30, 38)

local function nextVariant(v)
	for i, name in ipairs(RarityConfig.VariantOrder) do
		if name == v then
			return RarityConfig.VariantOrder[i + 1]
		end
	end
	return nil
end

local function clear(frame)
	for _, c in ipairs(frame:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function box(parent, size, pos, z)
	local f = UIKit.Create("Frame", { BackgroundColor3 = UIKit.PanelCard, Size = size, Position = pos, ZIndex = z or 53, Parent = parent })
	UIKit.Corner(f, 6)
	UIKit.Stroke(f, 4, UIKit.Outline, true)
	return f
end

local function pipe(parent, size, pos)
	local f = UIKit.Create("Frame", { BackgroundColor3 = PIPE, BorderSizePixel = 0, Size = size, Position = pos, ZIndex = 52, Parent = parent })
	return f
end

local function glowCap(parent, size, pos)
	local f = UIKit.Create("Frame", { BackgroundColor3 = RGB(110, 255, 60), BorderSizePixel = 0, Size = size, Position = pos, ZIndex = 54, Parent = parent })
	UIKit.Corner(f, UDim.new(1, 0))
	UIKit.Stroke(f, 3, UIKit.Outline, true)
	return f
end

function FuseMenu.Build(ctx)
	local need = GameConfig.Fuse.Count
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Fuse Machine", Style = "Header", Colors = { RGB(235, 110, 255), RGB(165, 30, 230) }, Size = UDim2.fromOffset(1000, 640) })
	local content = panel.Content
	local W = 1000 - 32

	local head = UIKit.Label({ Text = "", RichText = true, Size = UDim2.new(1, 0, 0, 46), Position = UDim2.fromOffset(0, 0), StrokeThickness = 3, ZIndex = 54, Parent = content })
	head.Text = string.format('Bring <font color="#FF3838">%d</font> same objects to Fuse', need)
	local sub = UIKit.Label({ Text = "", RichText = true, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 46), StrokeThickness = 3, ZIndex = 54, Parent = content })
	sub.Text = '<i><font color="#5CFF3C">Fused objects</font> earn <font color="#5CFF3C">WAY more</font>!</i>'

	-- 3 input slots
	local slotW, slotH, gap = 260, 130, 30
	local resultTop = 92 + slotH + 40
	local midY = resultTop + 70
	local left = (W - (slotW * 3 + gap * 2)) / 2
	local slots = {}
	local picker -- forward
	for i = 1, need do
		local x = left + (i - 1) * (slotW + gap)
		local f = box(content, UDim2.fromOffset(slotW, slotH), UDim2.fromOffset(x, 92))
		local name = UIKit.Label({ Text = "Empty", Size = UDim2.new(1, -12, 0, 36), Position = UDim2.fromOffset(6, 6), StrokeThickness = 3, ZIndex = 55, Parent = f })
		local holder = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -44), Position = UDim2.fromOffset(0, 42), ZIndex = 55, Parent = f })
		local plus = UIKit.Button({ Text = "+", Colors = GREEN, CornerRadius = 4, Size = UDim2.fromOffset(170, 74), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), ZIndex = 56, Parent = f, OnClick = function()
			picker.Visible = true
		end })
		-- pipe from the slot down into the result box
		local cx = x + slotW / 2
		local y0 = 92 + slotH + 16
		glowCap(content, UDim2.fromOffset(70, 14), UDim2.fromOffset(cx - 35, 92 + slotH + 4))
		slots[i] = { Name = name, Holder = holder, Plus = plus }
		if i == 2 then
			pipe(content, UDim2.fromOffset(26, resultTop - y0), UDim2.fromOffset(cx - 13, y0))
		else
			local edgeX = i < 2 and (W / 2 - 130) or (W / 2 + 130)
			pipe(content, UDim2.fromOffset(22, midY + 11 - y0), UDim2.fromOffset(cx - 11, y0))
			pipe(content, UDim2.fromOffset(math.abs(edgeX - cx) + 11, 22), UDim2.fromOffset(math.min(cx, edgeX) - (i < 2 and 11 or 0), midY - 11))
			glowCap(content, UDim2.fromOffset(14, 56), UDim2.fromOffset(edgeX - 7 + (i < 2 and -10 or 10), midY - 28))
		end
	end

	-- result in the middle
	local result = box(content, UDim2.fromOffset(260, 170), UDim2.fromOffset(W / 2 - 130, resultTop))
	local resultHolder = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), ZIndex = 55, Parent = result })
	local resultName = UIKit.Label({ Text = "", Size = UDim2.new(1, -12, 0, 30), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -4), StrokeThickness = 3, ZIndex = 57, Parent = result })

	local selected -- { Id, V }
	local fuseButton, fuseLabel = UIKit.Button({ Text = need .. " Left", Colors = GREEN, CornerRadius = 4, Size = UDim2.fromOffset(380, 76), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), ZIndex = 56, Parent = content, OnClick = function()
		if selected then
			ctx.HUD.Result(State.Action("FuseItems", selected.Id, selected.V))
		else
			picker.Visible = true
		end
	end })

	-- hint card on the left: "3 small ≈ 1 better"  [OK!]
	local hint = box(panel.Holder, UDim2.fromOffset(280, 190), UDim2.new(0, -300, 0.5, -95), 52)
	hint.BackgroundColor3 = UIKit.PanelBody
	UIKit.Label({ Text = "x3", Size = UDim2.fromOffset(80, 60), Position = UDim2.fromOffset(18, 28), TextColor3 = RGB(255, 255, 255), StrokeThickness = 3, ZIndex = 55, Parent = hint })
	UIKit.Label({ Text = "≈", Size = UDim2.fromOffset(50, 60), Position = UDim2.fromOffset(110, 28), StrokeThickness = 3, ZIndex = 55, Parent = hint })
	UIKit.Label({ Text = "🌟", StrokeThickness = 0, Size = UDim2.fromOffset(80, 70), Position = UDim2.fromOffset(170, 22), ZIndex = 55, Parent = hint })
	UIKit.Button({ Text = "OK!", Colors = GREEN, CornerRadius = 4, Size = UDim2.fromOffset(150, 56), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), ZIndex = 56, Parent = hint, OnClick = function()
		hint.Visible = false
	end })

	-- picker overlay: every object you own, grouped by object + variant
	picker = UIKit.Create("Frame", { Name = "Picker", BackgroundColor3 = UIKit.PanelBody, Visible = false, Size = UDim2.fromScale(1, 1), ZIndex = 80, Parent = content })
	UIKit.Corner(picker, 8)
	UIKit.Stroke(picker, 4, UIKit.Outline, true)
	UIKit.Label({ Text = "Pick an object to fuse", Size = UDim2.new(1, -120, 0, 44), Position = UDim2.fromOffset(16, 8), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3, ZIndex = 81, Parent = picker })
	UIKit.Button({ Text = "Back", Colors = UIKit.Colors.Red, CornerRadius = 4, Size = UDim2.fromOffset(110, 46), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), ZIndex = 82, Parent = picker, OnClick = function()
		picker.Visible = false
	end })
	local grid = UIKit.Scroll({ Size = UDim2.new(1, -20, 1, -70), Position = UDim2.fromOffset(10, 62), Parent = picker })
	grid.ZIndex = 81
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(170, 190), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })

	local menu = { Panel = panel }
	local lastKey

	local function groups()
		local data = State.Data
		local map, order = {}, {}
		for _, item in ipairs(data and data.Items or {}) do
			local k = item.Id .. ":" .. item.V
			if not map[k] then
				map[k] = { Id = item.Id, V = item.V, Count = 0 }
				table.insert(order, map[k])
			end
			map[k].Count += 1
		end
		table.sort(order, function(a, b)
			local fa, fb = a.Count >= need and nextVariant(a.V) ~= nil, b.Count >= need and nextVariant(b.V) ~= nil
			if fa ~= fb then
				return fa
			end
			return Formulas.ItemBaseIncome(a) > Formulas.ItemBaseIncome(b)
		end)
		return map, order
	end

	local function render()
		local map, order = groups()
		local g = selected and map[selected.Id .. ":" .. selected.V]
		if selected and not g then
			selected = nil
		end
		local have = g and math.min(g.Count, need) or 0
		for i, s in ipairs(slots) do
			clear(s.Holder)
			local filled = g and i <= have
			s.Plus.Visible = not filled
			s.Name.Text = filled and Formulas.ItemName({ Id = g.Id, V = g.V }) or "Empty"
			if filled then
				UIKit.ModelPreview({ Id = g.Id, Variant = g.V, Size = UDim2.fromScale(1, 1), ZIndex = 56, Parent = s.Holder })
			end
		end
		clear(resultHolder)
		local nv = g and nextVariant(g.V)
		if g and nv then
			local vf = UIKit.ModelPreview({ Id = g.Id, Variant = nv, Size = UDim2.new(1, 0, 1, -30), ZIndex = 56, Parent = resultHolder })
			if have < need then
				vf.ImageColor3 = RGB(0, 0, 0) -- mystery silhouette until all slots are full
				resultName.Text = "???"
			else
				resultName.Text = Formulas.ItemName({ Id = g.Id, V = nv })
			end
		else
			resultName.Text = g and "MAX!" or ""
			UIKit.Label({ Text = "❔", StrokeThickness = 0, Size = UDim2.fromScale(1, 1), ZIndex = 56, Parent = resultHolder })
		end
		if g and not nv then
			fuseLabel.Text = "Already Cosmic!"
			UIKit.SetButtonColors(fuseButton, UIKit.Colors.Gray)
		elseif g and have >= need then
			fuseLabel.Text = "FUSE!"
			UIKit.SetButtonColors(fuseButton, GREEN)
		else
			fuseLabel.Text = (need - have) .. " Left"
			UIKit.SetButtonColors(fuseButton, g and GREEN or UIKit.Colors.Gray)
		end

		-- picker tiles
		clear(grid)
		if #order == 0 then
			UIKit.Label({ Text = "Shrink some objects first!", StrokeThickness = 2, Size = UDim2.fromOffset(400, 40), ZIndex = 82, Parent = grid })
		end
		for i, entry in ipairs(order) do
			local ready = entry.Count >= need and nextVariant(entry.V) ~= nil
			local tile = UIKit.Create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = ready and RGB(70, 110, 60) or UIKit.PanelCard, LayoutOrder = i, ZIndex = 82, Parent = grid })
			UIKit.Corner(tile, 6)
			UIKit.Stroke(tile, 4, ready and RGB(110, 255, 60) or UIKit.Outline, true)
			UIKit.ModelPreview({ Id = entry.Id, Variant = entry.V, Size = UDim2.new(1, -20, 0, 120), Position = UDim2.fromOffset(10, 6), ZIndex = 83, Parent = tile })
			local variant = RarityConfig.GetVariant(entry.V)
			UIKit.Label({ Text = Formulas.ItemName({ Id = entry.Id, V = entry.V }), TextColor3 = variant.Color or RGB(255, 255, 255), Size = UDim2.new(1, -10, 0, 28), Position = UDim2.fromOffset(5, 126), StrokeThickness = 2.5, ZIndex = 83, Parent = tile })
			UIKit.Label({ Text = math.min(entry.Count, 999) .. "/" .. need .. (ready and "  ✔" or ""), TextColor3 = ready and RGB(130, 255, 90) or RGB(220, 220, 230), Size = UDim2.new(1, -10, 0, 26), Position = UDim2.fromOffset(5, 156), StrokeThickness = 2.5, ZIndex = 83, Parent = tile })
			UIKit.Bouncy(tile)
			tile.Activated:Connect(function()
				UIKit.PlaySound("Click", 0.4)
				selected = { Id = entry.Id, V = entry.V }
				picker.Visible = false
				lastKey = nil
			end)
		end
	end

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		local key = #data.Items .. ":" .. (data.NextUid or 0) .. ":" .. (selected and (selected.Id .. selected.V) or "")
		if key == lastKey then
			return
		end
		lastKey = key
		render()
	end
	menu.Tick = menu.Refresh

	panel.OnOpen:Connect(function()
		lastKey = nil
		picker.Visible = false
		hint.Visible = true
		-- auto-select the best thing you can fuse right now
		local _, order = groups()
		local best = order[1]
		if best and best.Count >= need and nextVariant(best.V) then
			selected = { Id = best.Id, V = best.V }
		end
	end)

	return menu
end

return FuseMenu
