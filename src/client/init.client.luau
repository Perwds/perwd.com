--[[
	Client bootstrap.

	Builds one ScreenGui, hands it to every panel, wires the HUD rail and the
	keyboard shortcuts, then starts the controllers.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local GateController = require(script.Controllers.GateController)
local HatchReveal = require(script.UI.HatchReveal)
local Hud = require(script.UI.Hud)
local Notify = require(script.UI.Notify)
local Panel = require(script.UI.Panel)
local PetFollow = require(script.Controllers.PetFollow)
local PetIndexUI = require(script.UI.PetIndexUI)
local PetsUI = require(script.UI.PetsUI)
local PromptController = require(script.Controllers.PromptController)
local ShopUI = require(script.UI.ShopUI)
local State = require(script.Controllers.State)
local Theme = require(script.UI.Theme)
local UgcUI = require(script.UI.UgcUI)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "StealAPet"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- Order matters only in that Notify has to exist before anything can toast.
Notify.build(screen)
Hud.build(screen)
HatchReveal.build(screen)

PetIndexUI.build(screen)
ShopUI.build(screen)
UgcUI.build(screen)
PetsUI.build(screen)

-- ---------------- HUD rail ----------------

Hud.addButton("Index", Theme.Color.headerBlue, PetIndexUI.toggle)
Hud.addButton("Shop", Theme.Color.headerGreen, ShopUI.toggle)
Hud.addButton("UGC", Theme.Color.headerPurple, UgcUI.toggle)
Hud.addButton("Pets", Theme.Color.headerGold, PetsUI.toggle)

-- ---------------- world props open panels ----------------

Net.Event("OpenUI").OnClientEvent:Connect(function(which, _payload)
	if which == "shop" then
		ShopUI.open()
	elseif which == "sell" then
		PetsUI.open("sell")
	elseif which == "fuse" then
		PetsUI.open("fuse")
	elseif which == "pets" then
		PetsUI.open("equip")
	elseif which == "index" then
		PetIndexUI.toggle()
	elseif which == "ugc" then
		UgcUI.toggle()
	end
end)

-- ---------------- keyboard shortcuts ----------------

local SHORTCUTS = {
	[Enum.KeyCode.E] = PetIndexUI.toggle,
	[Enum.KeyCode.B] = ShopUI.toggle,
	[Enum.KeyCode.U] = UgcUI.toggle,
	[Enum.KeyCode.P] = PetsUI.toggle,
}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		Panel.closeAll()
		return
	end

	local handler = SHORTCUTS[input.KeyCode]
	if handler then
		handler()
	end
end)

-- Drop the egg you are carrying. Bound through ContextActionService so it
-- also gets a touch button on mobile.
ContextActionService:BindAction("DropEgg", function(_name, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end

	local character = player.Character
	if not character or not character:GetAttribute("CarryingEgg") then
		return Enum.ContextActionResult.Pass
	end

	-- Frees you up when you are being chased and would rather lose the egg
	-- than lose the race. It lands on the ground for anyone to take.
	task.spawn(function()
		Net.Function("DropEgg"):InvokeServer()
	end)
	return Enum.ContextActionResult.Sink
end, true, Enum.KeyCode.Q)

ContextActionService:SetTitle("DropEgg", "Drop")

-- ---------------- controllers ----------------

State.start()
Hud.start()
Notify.start()
HatchReveal.start()
PetFollow.start()
GateController.start()
PromptController.start()

print("[StealAPet] client ready")
