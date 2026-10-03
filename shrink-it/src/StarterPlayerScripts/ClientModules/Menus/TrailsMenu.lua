--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > TrailsMenu (ModuleScript)

	"Trail Shop" (opened from the TRAILS stand): a row of big rarity-colored cards you scroll sideways.
	Every trail gives a Speed multiplier. Buy with Coins (green button) or Robux (purple button),
	then equip. Config: MonetizationConfig.Trails / TrailOrder / TrailRarityColors.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Format = require(Shared.Format)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)
local Prices = require(Modules.Prices)

local TrailsMenu = {}

local RGB = Color3.fromRGB
local PURPLE = { RGB(235, 110, 255), RGB(165, 30, 230) }
local GREEN = { RGB(130, 255, 60), RGB(50, 200, 20) }

-- A little blocky runner in the trail's colors with a swoosh behind it, rendered in 3D.
local function runnerPreview(parent, cfg)
	local vf = UIKit.Create("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 230),
		Position = UDim2.fromOffset(0, 70),
		Ambient = RGB(170, 170, 180),
		LightColor = RGB(255, 255, 255),
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		ZIndex = 53,
		Parent = parent,
	})
	local model = Instance.new("Model")
	local c1, c2 = cfg.Colors[1], cfg.Colors[2]
	local function block(size, cf, color, material)
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	local body = c1:Lerp(c2, 0.3)
	local root = CFrame.Angles(0, math.rad(-35), 0) * CFrame.Angles(math.rad(-12), 0, 0)
	block(Vector3.new(2, 2, 1), root * CFrame.new(0, 3, 0), body)
	local head = block(Vector3.new(1.25, 1.25, 1.25), root * CFrame.new(0, 4.65, 0), body)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = head
	block(Vector3.new(1, 2, 1), root * CFrame.new(-1.5, 3.2, 0) * CFrame.Angles(math.rad(50), 0, 0), body:Lerp(c2, 0.2))
	block(Vector3.new(1, 2, 1), root * CFrame.new(1.5, 3.2, 0) * CFrame.Angles(math.rad(-50), 0, 0), body:Lerp(c2, 0.2))
	block(Vector3.new(1, 2, 1), root * CFrame.new(-0.5, 1, 0.3) * CFrame.Angles(math.rad(-40), 0, 0), body:Lerp(c2, 0.35))
	block(Vector3.new(1, 2, 1), root * CFrame.new(0.5, 1, -0.3) * CFrame.Angles(math.rad(45), 0, 0), body:Lerp(c2, 0.35))
	-- the swoosh: a curved ribbon of thin panels behind the runner
	local segments = 14
	for i = 0, segments - 1 do
		local t = i / segments
		local x = 1.2 + t * 7
		local y = 3 - math.sin(t * math.pi) * 1.2 + t * 0.6
		local color
		if cfg.Rainbow then
			color = Color3.fromHSV(t, 0.75, 1)
		elseif cfg.Pattern == "Zebra" then
			color = (i % 2 == 0) and c1 or c2
		else
			color = c1:Lerp(c2, t)
		end
		local p = block(Vector3.new(7 / segments + 0.05, 2.6 - t * 1.6, 0.2), root * CFrame.new(x, y, 0.8 + t * 1.5) * CFrame.Angles(0, math.rad(-12), 0), color, cfg.Pattern == "Galaxy" and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		p.Transparency = t * 0.35
	end
	model.Parent = vf
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = vf
	vf.CurrentCamera = camera
	local cf, size = model:GetBoundingBox()
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 0.6, -1).Unit * size.Magnitude * 1.25, cf.Position)
	return vf
end

local function rarityColors(cfg)
	return MonetizationConfig.TrailRarityColors[cfg.Rarity] or UIKit.Colors.Gray
end

function TrailsMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Trail Shop", Animated = true, Style = "Header", Colors = PURPLE, Size = UDim2.fromOffset(1060, 590) })
	local content = panel.Content
	local plates = UIKit.Button({ Text = "NAME PLATES", Colors = { RGB(255, 170, 220), RGB(225, 70, 160) }, Size = UDim2.fromOffset(230, 52), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -96, 0, 42), CornerRadius = 6, ZIndex = 70, Parent = content.Parent, OnClick = function()
		ctx.HUD.OpenMenu("Nameplates")
	end })
	plates.ZIndex = 70
	local row = UIKit.Scroll({ Size = UDim2.fromScale(1, 1), Horizontal = true, Parent = content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = row })
	UIKit.Create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = row })

	local cards = {}
	for i, key in ipairs(MonetizationConfig.TrailOrder) do
		local cfg = MonetizationConfig.Trails[key]
		local card = UIKit.Create("Frame", { Name = key, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromOffset(310, 440), LayoutOrder = i, ZIndex = 52, Parent = row })
		UIKit.Corner(card, 8)
		UIKit.Stroke(card, 5, UIKit.Outline, true)
		UIKit.Gradient(card, rarityColors(cfg), 90)
		-- soft light burst behind the runner
		local burst = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(155, 190), Size = UDim2.fromOffset(220, 220), ZIndex = 52, Parent = card })
		UIKit.Corner(burst, UDim.new(1, 0))
		UIKit.Create("UIGradient", { Transparency = NumberSequence.new(0.2, 1), Parent = burst })
		UIKit.Label({ Text = cfg.Name, Size = UDim2.new(1, -16, 0, 44), Position = UDim2.fromOffset(8, 10), StrokeThickness = 3.5, ZIndex = 54, Parent = card })
		UIKit.Label({ Text = cfg.Rarity, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 50), StrokeThickness = 2.5, ZIndex = 54, Parent = card })
		runnerPreview(card, cfg)
		-- "x1.5 Speed" plate
		local plate = UIKit.Create("Frame", { BackgroundColor3 = RGB(30, 30, 40), BackgroundTransparency = 0.35, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 300), Size = UDim2.new(1, -36, 0, 56), ZIndex = 54, Parent = card })
		UIKit.Corner(plate, 6)
		UIKit.Stroke(plate, 3, UIKit.Outline, true)
		local speed = UIKit.Label({ Text = "", RichText = true, Size = UDim2.new(1, -12, 1, -8), Position = UDim2.fromOffset(6, 4), StrokeThickness = 3, ZIndex = 55, Parent = plate })
		speed.Text = string.format('<font color="#5CFF3C">x%s</font> Speed', tostring(cfg.Speed))
		-- buttons: coins (green) + Robux (purple), or equip
		local buyCoins, coinsLabel = UIKit.Button({ Text = cfg.Cost and Format.Coins(cfg.Cost) or "", Colors = GREEN, CornerRadius = 4, Size = UDim2.fromOffset(cfg.Product and 160 or 200, 58), Position = UDim2.fromOffset(cfg.Product and 14 or 14, 370), ZIndex = 56, Parent = card, OnClick = function()
			ctx.HUD.Result(State.Action("BuyTrail", key))
		end })
		local buyRobux, robuxLabel
		if cfg.Product then
			local product = MonetizationConfig.Products[cfg.Product]
			local function price()
				return Prices.Get(Enum.InfoType.Product, product.Id, product.PriceLabel)
			end
			buyRobux, robuxLabel = UIKit.Button({ Text = price(), Colors = PURPLE, CornerRadius = 4, Size = UDim2.fromOffset(112, 58), Position = UDim2.fromOffset(184, 370), ZIndex = 56, Parent = card, OnClick = function()
				ctx.HUD.Result(State.Action("BuyTrailRobux", key))
			end })
			Prices.OnUpdated(function()
				robuxLabel.Text = price()
			end)
		end
		local equip, equipLabel = UIKit.Button({ Text = "EQUIP", Colors = UIKit.Colors.Blue, CornerRadius = 4, Size = UDim2.new(1, -28, 0, 58), Position = UDim2.fromOffset(14, 370), ZIndex = 56, Parent = card, OnClick = function()
			local data = State.Data
			if data and data.EquippedTrail == key then
				ctx.HUD.Result(State.Action("EquipTrail", ""))
			elseif cfg.Pass and not State.HasPass(cfg.Pass) then
				ctx.HUD.Result(State.Action("PromptPass", cfg.Pass))
			else
				ctx.HUD.Result(State.Action("EquipTrail", key))
			end
		end })
		cards[key] = { Cfg = cfg, Coins = buyCoins, CoinsLabel = coinsLabel, Robux = buyRobux, Equip = equip, EquipLabel = equipLabel }
	end

	local menu = { Panel = panel }

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		for key, c in pairs(cards) do
			local owned = c.Cfg.Pass and State.HasPass(c.Cfg.Pass) or (data.Trails and data.Trails[key])
			local showEquip = owned or c.Cfg.Pass ~= nil
			c.Equip.Visible = showEquip
			c.Coins.Visible = not showEquip
			if c.Robux then
				c.Robux.Visible = not showEquip
			end
			if data.EquippedTrail == key and owned then
				c.EquipLabel.Text = "EQUIPPED"
				UIKit.SetButtonColors(c.Equip, UIKit.Colors.Gray)
			elseif owned then
				c.EquipLabel.Text = "EQUIP"
				UIKit.SetButtonColors(c.Equip, UIKit.Colors.Blue)
			elseif c.Cfg.Pass then
				c.EquipLabel.Text = "GET PASS"
				UIKit.SetButtonColors(c.Equip, PURPLE)
			end
			if not showEquip then
				UIKit.SetButtonColors(c.Coins, State.Coins >= c.Cfg.Cost and GREEN or UIKit.Colors.Gray)
			end
		end
	end

	menu.Tick = menu.Refresh
	return menu
end

return TrailsMenu
