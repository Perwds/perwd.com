--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > NameplatesMenu (ModuleScript)

	"Name Plates": pick the bar that floats over your head. Opened from the Trail Shop or the Shop.
	Big preview with your name on top, a grid of every plate below (buy with Coins / Gems / Robux,
	or unlock by beating the boss / rebirthing). Config: NameplateConfig.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local NameplateConfig = require(Shared.Config.NameplateConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Nameplate = require(Shared.Nameplate)
local Format = require(Shared.Format)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)
local Prices = require(Modules.Prices)

local NameplatesMenu = {}

local RGB = Color3.fromRGB
local HEADER = { RGB(255, 170, 220), RGB(225, 70, 160) }
local GREEN = { RGB(130, 255, 60), RGB(50, 200, 20) }

local function owns(data, key)
	local cfg = NameplateConfig.Plates[key]
	if not cfg or not data then
		return false
	end
	if cfg.Free then
		return true
	end
	if cfg.Req then
		return (data[cfg.Req.Stat] or 0) >= cfg.Req.Amount
	end
	return data.Nameplates ~= nil and data.Nameplates[key] == true
end

local function priceText(cfg)
	if cfg.Product then
		local p = MonetizationConfig.Products[cfg.Product]
		return p and Prices.Get(Enum.InfoType.Product, p.Id, p.PriceLabel) or "R$ ?"
	elseif cfg.Req then
		return cfg.Req.Label
	elseif cfg.Currency == "Gems" then
		return Format.Abbrev(cfg.Cost) .. " Gems"
	end
	return Format.Coins(cfg.Cost or 0)
end

local function plateColor(data)
	local pc = data and data.PlateColor or {}
	return Color3.fromRGB(pc[1] or 255, pc[2] or 120, pc[3] or 40)
end

local function toHex(c)
	return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

-- ── color picker (Custom Color plate): saturation/brightness square + hue bar + hex box ──
local SWATCHES = {
	RGB(235, 30, 40), RGB(255, 140, 20), RGB(255, 225, 30), RGB(140, 230, 30), RGB(30, 200, 60), RGB(30, 200, 170),
	RGB(40, 200, 255), RGB(40, 90, 240), RGB(120, 50, 230), RGB(220, 50, 220), RGB(255, 110, 180), RGB(150, 90, 50),
	RGB(255, 255, 255), RGB(160, 160, 170), RGB(60, 60, 70), RGB(15, 15, 20), RGB(255, 200, 150), RGB(212, 175, 55),
}

local function buildPicker(content, myName, onSave)
	local overlay = UIKit.Create("Frame", { Name = "ColorPicker", BackgroundColor3 = RGB(30, 32, 48), Size = UDim2.fromScale(1, 1), ZIndex = 80, Visible = false, Active = true, Parent = content })
	UIKit.Corner(overlay, 10)
	UIKit.Stroke(overlay, 4, UIKit.Outline, true)
	UIKit.Label({ Text = "Pick ANY color (16,777,216 to choose from!)", Size = UDim2.new(1, -40, 0, 34), Position = UDim2.fromOffset(20, 10), StrokeThickness = 3, ZIndex = 82, Parent = overlay })

	local h, sat, val = 0.05, 0.85, 1
	-- saturation (left→right) × brightness (top→bottom)
	local sv = UIKit.Create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHSV(h, 1, 1), Size = UDim2.fromOffset(300, 300), Position = UDim2.fromOffset(24, 56), ZIndex = 82, Parent = overlay })
	UIKit.Corner(sv, 8)
	local white = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 83, Parent = sv })
	UIKit.Corner(white, 8)
	UIKit.Create("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
	local black = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Size = UDim2.fromScale(1, 1), ZIndex = 84, Parent = sv })
	UIKit.Corner(black, 8)
	UIKit.Create("UIGradient", { Transparency = NumberSequence.new(1, 0), Rotation = 90, Parent = black })
	local svDot = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), ZIndex = 86, Parent = sv })
	UIKit.Corner(svDot, UDim.new(1, 0))
	UIKit.Stroke(svDot, 3, UIKit.Outline)
	-- hue bar
	local hue = UIKit.Create("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(44, 300), Position = UDim2.fromOffset(342, 56), ZIndex = 82, Parent = overlay })
	UIKit.Corner(hue, 8)
	local kps = {}
	for i = 0, 6 do
		table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1)))
	end
	UIKit.Create("UIGradient", { Color = ColorSequence.new(kps), Rotation = 90, Parent = hue })
	local hueBar = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.new(1, 10, 0, 8), Position = UDim2.fromScale(0.5, 0), ZIndex = 86, Parent = hue })
	UIKit.Stroke(hueBar, 3, UIKit.Outline)

	-- right side: preview, hex, swatches, buttons
	local previewHolder = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(560, 100), Position = UDim2.fromOffset(410, 56), ZIndex = 82, Parent = overlay })
	local hexLabel = UIKit.Label({ Text = "HEX #", Size = UDim2.fromOffset(110, 44), Position = UDim2.fromOffset(410, 170), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2.5, ZIndex = 82, Parent = overlay })
	hexLabel.TextColor3 = RGB(200, 205, 230)
	local hexBox = UIKit.Create("TextBox", { Text = "", Font = UIKit.Font, TextScaled = true, ClearTextOnFocus = false, TextColor3 = UIKit.Outline, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(170, 44), Position = UDim2.fromOffset(510, 170), ZIndex = 82, Parent = overlay })
	UIKit.Corner(hexBox, 6)
	UIKit.Stroke(hexBox, 3, UIKit.Outline)
	local rgbLabel = UIKit.Label({ Text = "", Size = UDim2.fromOffset(260, 44), Position = UDim2.fromOffset(700, 170), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2.5, ZIndex = 82, Parent = overlay })
	local swatchHolder = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(560, 100), Position = UDim2.fromOffset(410, 228), ZIndex = 82, Parent = overlay })
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(52, 44), CellPadding = UDim2.fromOffset(9, 9), Parent = swatchHolder })

	local preview
	local function current()
		return Color3.fromHSV(h, sat, val)
	end
	local function redraw(skipHex)
		local c = current()
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svDot.Position = UDim2.fromScale(sat, 1 - val)
		hueBar.Position = UDim2.fromScale(0.5, h)
		if not skipHex then
			hexBox.Text = toHex(c)
		end
		rgbLabel.Text = string.format("R %d  G %d  B %d", c.R * 255 + 0.5, c.G * 255 + 0.5, c.B * 255 + 0.5)
		if preview then
			preview:Destroy()
		end
		preview = Nameplate.Build("Custom", { Parent = previewHolder, Text = myName, Color = c, Size = UDim2.fromOffset(480, 92), ZIndex = 83 })
	end
	local function setColor(c, skipHex)
		h, sat, val = c:ToHSV()
		redraw(skipHex)
	end
	for _, c in ipairs(SWATCHES) do
		local b = UIKit.Create("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = c, ZIndex = 83, Parent = swatchHolder })
		UIKit.Corner(b, 6)
		UIKit.Stroke(b, 3, UIKit.Outline)
		b.MouseButton1Click:Connect(function()
			setColor(c)
		end)
	end
	hexBox.FocusLost:Connect(function()
		local hex = hexBox.Text:gsub("[^%x]", "")
		if #hex == 6 then
			setColor(Color3.fromRGB(tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)))
		else
			redraw()
		end
	end)

	-- dragging on the square / bar (mouse or touch)
	local dragging = nil
	local lastTouch = nil
	local function pointer()
		if lastTouch then
			return lastTouch + GuiService:GetGuiInset()
		end
		return UserInputService:GetMouseLocation()
	end
	local function begin(target)
		return function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = target
				lastTouch = input.UserInputType == Enum.UserInputType.Touch and Vector2.new(input.Position.X, input.Position.Y) or nil
			end
		end
	end
	sv.InputBegan:Connect(begin(sv))
	hue.InputBegan:Connect(begin(hue))
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.Touch then
			lastTouch = Vector2.new(input.Position.X, input.Position.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = nil
			lastTouch = nil
		end
	end)
	local lastDraw = 0
	RunService.RenderStepped:Connect(function()
		if not dragging or not overlay.Visible then
			return
		end
		local p = pointer()
		local rel = (p - dragging.AbsolutePosition) / dragging.AbsoluteSize
		local x, y = math.clamp(rel.X, 0, 1), math.clamp(rel.Y, 0, 1)
		if dragging == sv then
			sat, val = x, 1 - y
		else
			h = math.min(y, 0.999)
		end
		svDot.Position = UDim2.fromScale(sat, 1 - val)
		hueBar.Position = UDim2.fromScale(0.5, h)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		if os.clock() - lastDraw > 0.08 then -- rebuilding the preview every frame is wasteful
			lastDraw = os.clock()
			redraw()
		end
	end)

	UIKit.Button({ Text = "SAVE", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(250, 64), Position = UDim2.fromOffset(410, 330), ZIndex = 84, Parent = overlay, OnClick = function()
		local c = current()
		onSave(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
		overlay.Visible = false
	end })
	UIKit.Button({ Text = "CANCEL", Colors = UIKit.Colors.Red, Size = UDim2.fromOffset(250, 64), Position = UDim2.fromOffset(676, 330), ZIndex = 84, Parent = overlay, OnClick = function()
		overlay.Visible = false
	end })

	return {
		Open = function(color)
			overlay.Visible = true
			setColor(color)
		end,
	}
end

function NameplatesMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Name Plates", Animated = true, Style = "Header", Colors = HEADER, Size = UDim2.fromOffset(1060, 610) })
	local content = panel.Content
	local myName = Players.LocalPlayer and Players.LocalPlayer.DisplayName or "You"

	-- header shortcut back to trails
	local back = UIKit.Button({ Text = "TRAILS", Colors = UIKit.Colors.Purple, Size = UDim2.fromOffset(170, 52), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0, 42), CornerRadius = 6, ZIndex = 70, Parent = content.Parent, OnClick = function()
		ctx.HUD.OpenMenu("Trails")
	end })
	back.ZIndex = 70

	-- big preview of the equipped plate
	local previewHolder = UIKit.Create("Frame", { BackgroundColor3 = RGB(30, 32, 48), Size = UDim2.new(1, 0, 0, 110), ZIndex = 52, Parent = content })
	UIKit.Corner(previewHolder, 10)
	UIKit.Stroke(previewHolder, 4, UIKit.Outline, true)
	local previewLabel = UIKit.Label({ Text = "Equipped", Size = UDim2.fromOffset(200, 30), Position = UDim2.fromOffset(18, 40), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2.5, ZIndex = 54, Parent = previewHolder })
	previewLabel.TextColor3 = RGB(200, 205, 230)
	local preview = nil
	local previewKey = nil
	local function showPreview(key)
		if key == "Custom" then
			key = "Custom#" .. toHex(plateColor(State.Data))
		end
		if key == previewKey then
			return
		end
		previewKey = key
		key = key:gsub("#.*", "")
		if preview then
			preview:Destroy()
		end
		preview = Nameplate.Build(key, { Parent = previewHolder, Text = myName, Color = plateColor(State.Data), Size = UDim2.fromOffset(450, 86), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 55 })
	end

	local grid = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -124), Position = UDim2.fromOffset(0, 124), Parent = content })
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(318, 176), CellPadding = UDim2.fromOffset(14, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
	UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 10), Parent = grid })

	local picker = buildPicker(content, myName, function(r, g, b)
		ctx.HUD.Result(State.Action("SetPlateColor", r, g, b))
	end)
	local cards = {}
	for i, key in ipairs(NameplateConfig.Order) do
		local cfg = NameplateConfig.Plates[key]
		local colors = NameplateConfig.RarityColors[cfg.Rarity] or UIKit.Colors.Gray
		local card = UIKit.Create("Frame", { Name = key, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = i, ZIndex = 52, Parent = grid })
		UIKit.Corner(card, 8)
		UIKit.Stroke(card, 4, UIKit.Outline, true)
		UIKit.Gradient(card, { colors[1]:Lerp(RGB(40, 42, 60), 0.55), colors[2]:Lerp(RGB(25, 26, 40), 0.6) }, 90)
		UIKit.Label({ Text = cfg.Name, Size = UDim2.new(0.62, -10, 0, 30), Position = UDim2.fromOffset(10, 6), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3, ZIndex = 54, Parent = card })
		local rarity = UIKit.Label({ Text = cfg.Rarity, Size = UDim2.new(0.38, -10, 0, 24), Position = UDim2.new(0.62, 0, 0, 9), TextXAlignment = Enum.TextXAlignment.Right, StrokeThickness = 2.5, ZIndex = 54, Parent = card })
		rarity.TextColor3 = colors[1]
		local cardPlate = Nameplate.Build(key, { Parent = card, Text = myName, Color = plateColor(State.Data), Size = UDim2.new(1, -24, 0, 58), Position = UDim2.fromOffset(12, 42), ZIndex = 55 })
		local button, label = UIKit.Button({ Text = "", Colors = GREEN, CornerRadius = 4, Size = UDim2.new(1, -24, 0, 50), Position = UDim2.new(0, 12, 1, -60), ZIndex = 58, Parent = card, OnClick = function()
			local data = State.Data
			if owns(data, key) then
				if cfg.CustomColor then
					picker.Open(plateColor(data))
				elseif data.EquippedPlate ~= key then
					ctx.HUD.Result(State.Action("EquipPlate", key))
				end
			else
				ctx.HUD.Result(State.Action("BuyPlate", key))
			end
		end })
		cards[key] = { Cfg = cfg, Button = button, Label = label, Card = card, Plate = cardPlate }
	end

	local menu = { Panel = panel, Picker = picker }
	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		local equipped = owns(data, data.EquippedPlate) and data.EquippedPlate or NameplateConfig.Default
		showPreview(equipped)
		local custom = cards.Custom
		local hex = toHex(plateColor(data))
		if custom and custom.Hex ~= hex then -- the Custom card shows your current color
			custom.Hex = hex
			custom.Plate:Destroy()
			custom.Plate = Nameplate.Build("Custom", { Parent = custom.Card, Text = myName, Color = plateColor(data), Size = UDim2.new(1, -24, 0, 58), Position = UDim2.fromOffset(12, 42), ZIndex = 55 })
		end
		for key, c in pairs(cards) do
			if c.Cfg.CustomColor and owns(data, key) then
				c.Label.Text = equipped == key and "EDIT COLOR" or "PICK COLOR"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Orange)
			elseif equipped == key then
				c.Label.Text = "EQUIPPED"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Gray)
			elseif owns(data, key) then
				c.Label.Text = "EQUIP"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Blue)
			else
				c.Label.Text = priceText(c.Cfg)
				local colors
				if c.Cfg.Product then
					colors = { RGB(235, 110, 255), RGB(165, 30, 230) }
				elseif c.Cfg.Req then
					colors = UIKit.Colors.Dark
				elseif c.Cfg.Currency == "Gems" then
					colors = (State.Gems or 0) >= c.Cfg.Cost and UIKit.Colors.Cyan or UIKit.Colors.Gray
				else
					colors = (State.Coins or 0) >= (c.Cfg.Cost or 0) and GREEN or UIKit.Colors.Gray
				end
				UIKit.SetButtonColors(c.Button, colors)
			end
		end
	end
	menu.Tick = menu.Refresh
	Prices.OnUpdated(function()
		if panel.IsOpen() then
			menu.Refresh()
		end
	end)
	return menu
end

return NameplatesMenu
