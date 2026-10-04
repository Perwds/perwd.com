--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > TreadmillsMenu (ModuleScript)

	"Treadmills" (Custom menu tab): 3D previews of every treadmill skin. Buy with Gems, equip one,
	or go back to the look for your Treadmill upgrade tier. Config: TreadmillConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TreadmillConfig = require(Shared.Config.TreadmillConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local TreadmillsMenu = {}

local RGB = Color3.fromRGB

-- 3D preview of a treadmill model in a ViewportFrame
local function preview(parent, modelName)
	local vf = UIKit.Create("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.new(1, -16, 0, 150), Position = UDim2.fromOffset(8, 40), Ambient = RGB(170, 170, 180), LightColor = RGB(255, 255, 255), LightDirection = Vector3.new(-0.5, -1, -0.7), ZIndex = 54, Parent = parent })
	local folder = ReplicatedStorage:FindFirstChild("TreadmillModels")
	local template = folder and folder:FindFirstChild(modelName)
	if not template then
		return vf
	end
	local model = template:Clone()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	model:PivotTo(CFrame.Angles(0, math.rad(35), 0))
	model.Parent = vf
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = vf
	vf.CurrentCamera = camera
	local cf, size = model:GetBoundingBox()
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(1, 0.7, 1).Unit * size.Magnitude * 1.45, cf.Position)
	return vf
end

function TreadmillsMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Treadmills", Emoji = "🏃", Size = UDim2.fromOffset(1060, 610) })
	local content = panel.Content
	UIKit.Button({ Text = "NAME PLATES", Colors = UIKit.Colors.Pink, Size = UDim2.fromOffset(200, 50), Position = UDim2.fromOffset(0, -6), CornerRadius = 8, ZIndex = 60, Parent = content, OnClick = function()
		ctx.HUD.OpenMenu("Nameplates")
	end })
	local info = UIKit.Label({ Text = "", Size = UDim2.new(1, -230, 0, 40), Position = UDim2.fromOffset(220, -1), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 3, ZIndex = 60, Parent = content })

	local grid = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -56), Position = UDim2.fromOffset(0, 56), Parent = content })
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(236, 262), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = grid })
	UIKit.Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 10), Parent = grid })

	local cards = {}
	local function card(order, key, title, modelName, colors)
		local c = UIKit.Create("Frame", { Name = key, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = order, ZIndex = 52, Parent = grid })
		UIKit.Corner(c, 10)
		UIKit.Stroke(c, 5, colors[2]:Lerp(Color3.new(0, 0, 0), 0.5), true)
		UIKit.Gradient(c, colors, 90)
		UIKit.Halftone(c, Color3.new(1, 1, 1), true)
		UIKit.Label({ Text = title, Size = UDim2.new(1, -14, 0, 32), Position = UDim2.fromOffset(7, 6), StrokeThickness = 3, ZIndex = 55, Parent = c })
		local vf = preview(c, modelName)
		local button, label = UIKit.Button({ Text = "", Colors = UIKit.Colors.Green, CornerRadius = 6, Size = UDim2.new(1, -20, 0, 50), Position = UDim2.new(0, 10, 1, -60), ZIndex = 58, Parent = c, OnClick = function()
			local data = State.Data
			if key == "" then
				ctx.HUD.Result(State.Action("EquipTreadmillSkin", ""))
			elseif data and data.TreadmillSkins and data.TreadmillSkins[key] then
				ctx.HUD.Result(State.Action("EquipTreadmillSkin", key))
			else
				ctx.HUD.Result(State.Action("BuyTreadmillSkin", key))
			end
		end })
		cards[key] = { Button = button, Label = label, Preview = vf }
	end
	-- first card: the tier look (changes with your upgrade)
	card(0, "", "Upgrade Tier", TreadmillConfig.Tiers[1], { RGB(140, 220, 255), RGB(40, 120, 220) })
	for i, key in ipairs(TreadmillConfig.SkinOrder) do
		local skin = TreadmillConfig.Skins[key]
		card(i, key, skin.Name, skin.Model, { RGB(255, 225, 120), RGB(240, 140, 30) })
	end

	local shownTier
	local menu = { Panel = panel }
	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		local max = UpgradeConfig.Upgrades.Treadmill.MaxLevel or 30
		local level = data.Upgrades and data.Upgrades.Treadmill or 1
		local tier = math.clamp(math.ceil(level / max * #TreadmillConfig.Tiers), 1, #TreadmillConfig.Tiers)
		info.Text = string.format("Your tier: %s (Treadmill level %d). Skins replace the look, training stays the same.", TreadmillConfig.TierNames[tier], level)
		if shownTier ~= tier then
			shownTier = tier
			local c = cards[""]
			c.Preview:Destroy()
			c.Preview = preview(c.Button.Parent, TreadmillConfig.Tiers[tier])
		end
		local equipped = data.EquippedTreadmill or ""
		for key, c in pairs(cards) do
			local owned = key == "" or (data.TreadmillSkins and data.TreadmillSkins[key])
			if equipped == key then
				c.Label.Text = "EQUIPPED"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Gray)
			elseif owned then
				c.Label.Text = "EQUIP"
				UIKit.SetButtonColors(c.Button, UIKit.Colors.Blue)
			else
				local cost = TreadmillConfig.Skins[key].Cost
				c.Label.Text = cost .. " Gems"
				UIKit.SetButtonColors(c.Button, (State.Gems or 0) >= cost and UIKit.Colors.Cyan or UIKit.Colors.Gray)
			end
		end
	end
	menu.Tick = menu.Refresh
	return menu
end

return TreadmillsMenu
