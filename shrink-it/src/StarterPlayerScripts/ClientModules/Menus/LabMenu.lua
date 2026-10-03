--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > LabMenu (ModuleScript)

	Opened from the LAB stand. Turn in the unopened boxes you're carrying for SAMPLES, then spend
	Samples on a Mutation Serum or a Mastery Box. Shows your Boss Mastery progress too.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local LabMenu = {}

function LabMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Lab", Style = "Header", Animated = true, Size = UDim2.fromOffset(760, 560), Colors = { Color3.fromRGB(120, 255, 120), Color3.fromRGB(30, 170, 80) } })
	local content = panel.Content

	local samples = UIKit.Label({ Text = "", TextColor3 = Color3.fromRGB(140, 255, 150), StrokeThickness = 3, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 16), Parent = content })
	local mastery = UIKit.Label({ Text = "", TextColor3 = Color3.fromRGB(220, 225, 240), StrokeThickness = 2, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 58), Parent = content })

	UIKit.Button({ Text = "Turn in my carried boxes", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(460, 64), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 100), Parent = content, OnClick = function()
		ctx.HUD.Result(State.Action("LabTurnIn"))
	end })
	UIKit.Label({ Text = "Unopened boxes become Samples (rarer and bigger boxes give more).", TextColor3 = Color3.fromRGB(200, 205, 220), StrokeThickness = 2, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 172), Parent = content })

	local function shopCard(x, title, text, cost, what)
		local card = UIKit.Card({ Size = UDim2.fromOffset(320, 230), Position = UDim2.new(0.5, x, 0, 214), Colors = UIKit.Colors.Dark, Parent = content, CornerRadius = 18 })
		UIKit.Label({ Text = title, StrokeThickness = 3, Size = UDim2.new(1, -20, 0, 36), Position = UDim2.fromOffset(10, 12), Parent = card })
		UIKit.Label({ Text = text, TextWrapped = true, TextColor3 = Color3.fromRGB(205, 210, 225), StrokeThickness = 1.5, Size = UDim2.new(1, -24, 0, 92), Position = UDim2.fromOffset(12, 54), Parent = card })
		UIKit.Button({ Text = cost .. " Samples", Colors = UIKit.Colors.Purple, Size = UDim2.new(1, -40, 0, 56), Position = UDim2.new(0, 20, 1, -72), Parent = card, OnClick = function()
			ctx.HUD.Result(State.Action("LabBuy", what))
		end })
	end
	shopCard(-330, "Mutation Serum", "Your next box placed in your base is " .. GameConfig.Lab.SerumBoost .. "x more likely to mutate.", GameConfig.Lab.SerumCost, "Serum")
	shopCard(10, "Mastery Box", "A box you can't find in the zones: always mutated and at least Huge.", GameConfig.Lab.MasteryBoxCost, "MasteryBox")

	local menu = { Panel = panel }
	function menu.Refresh()
		local b = State.Data and State.Data.Boss
		if not b then
			return
		end
		samples.Text = b.Samples .. " Samples" .. ((b.Serums or 0) > 0 and ("   ·   " .. b.Serums .. " Serum ready") or "")
		mastery.Text = "Boss Mastery: " .. b.Kills .. (b.NextMilestone and ("  ·  next Mastery Box at " .. b.NextMilestone) or "")
	end
	menu.Tick = menu.Refresh
	return menu
end

return LabMenu
