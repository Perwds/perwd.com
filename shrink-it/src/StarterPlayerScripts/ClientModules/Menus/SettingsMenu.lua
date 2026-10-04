--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > SettingsMenu (ModuleScript)

	⚙️ Settings (button in the top bar). Saved on the server (data.Settings, "SetSetting" action):
	  Sound effects / Ambience / Music volume, other players' trails, low graphics, auto shrink.
]]

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local SettingsMenu = {}

local RGB = Color3.fromRGB
local VOLUMES = { 0, 0.25, 0.5, 0.75, 1 }

local ROWS = {
	{ Key = "Sfx", Label = "Sound Effects", Kind = "Volume" },
	{ Key = "Ambient", Label = "Ambience", Kind = "Volume" },
	{ Key = "Music", Label = "Music", Kind = "Volume" },
	{ Key = "ShowTrails", Label = "Other players' trails", Kind = "Toggle" },
	{ Key = "LowGraphics", Label = "Low graphics (faster)", Kind = "Toggle" },
	{ Key = "AutoRebirth", Label = "Auto Rebirth (gamepass)", Kind = "Toggle" },
	{ Key = "AutoShrink", Label = "Auto Shrink (gamepass)", Kind = "Toggle" },
}

function SettingsMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Settings", Style = "Header", Colors = { RGB(150, 160, 190), RGB(80, 90, 120) }, Size = UDim2.fromOffset(720, 640) })
	local content = panel.Content
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = content })

	local controls = {}
	for i, row in ipairs(ROWS) do
		local card = UIKit.Create("Frame", { BackgroundColor3 = UIKit.PanelCard, Size = UDim2.new(1, 0, 0, 64), LayoutOrder = i, ZIndex = 52, Parent = content })
		UIKit.Corner(card, 8)
		UIKit.Stroke(card, 3, UIKit.Outline, true)
		UIKit.Label({ Text = row.Label, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(0.48, 0, 0, 40), Position = UDim2.fromOffset(16, 12), StrokeThickness = 2.5, ZIndex = 53, Parent = card })
		if row.Kind == "Volume" then
			local buttons = {}
			for k, v in ipairs(VOLUMES) do
				local b, label = UIKit.Button({ Text = v == 0 and "OFF" or (math.floor(v * 100) .. "%"), Colors = UIKit.Colors.Gray, CornerRadius = 6, Size = UDim2.fromOffset(62, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10 - (#VOLUMES - k) * 68, 0.5, 0), ZIndex = 54, Parent = card, OnClick = function()
					ctx.HUD.Result(State.Action("SetSetting", row.Key, v))
				end })
				buttons[k] = { Button = b, Label = label, Value = v }
			end
			controls[row.Key] = { Kind = "Volume", Buttons = buttons }
		else
			local b, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Gray, CornerRadius = 6, Size = UDim2.fromOffset(140, 44), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), ZIndex = 54, Parent = card, OnClick = function()
				local settings = State.Data and State.Data.Settings or {}
				local action = row.Key == "AutoShrink" and "SetAutoShrink" or "SetSetting"
				if action == "SetAutoShrink" then
					ctx.HUD.Result(State.Action(action, not settings.AutoShrink))
				else
					ctx.HUD.Result(State.Action(action, row.Key, not (settings[row.Key] == true or (row.Key == "ShowTrails" and settings[row.Key] == nil))))
				end
			end })
			controls[row.Key] = { Kind = "Toggle", Button = b, Label = label }
		end
	end

	local menu = { Panel = panel }
	function menu.Refresh()
		local settings = State.Data and State.Data.Settings
		if not settings then
			return
		end
		for key, c in pairs(controls) do
			local value = settings[key]
			if c.Kind == "Volume" then
				for _, b in ipairs(c.Buttons) do
					local on = math.abs((value or 0.5) - b.Value) < 0.01
					UIKit.SetButtonColors(b.Button, on and UIKit.Colors.Green or UIKit.Colors.Gray)
				end
			else
				local on = value == true or (key == "ShowTrails" and value == nil)
				c.Label.Text = on and "ON" or "OFF"
				UIKit.SetButtonColors(c.Button, on and UIKit.Colors.Green or UIKit.Colors.Red)
			end
		end
	end
	panel.OnOpen:Connect(menu.Refresh)
	return menu
end

return SettingsMenu
