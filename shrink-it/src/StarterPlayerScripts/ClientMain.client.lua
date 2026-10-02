--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientMain (LocalScript)

	Boots the client: State → HUD (+ menus) → Effects → RayController.
	The whole UI is created in code, so StarterGui can stay empty.
]]

local Modules = script.Parent:WaitForChild("ClientModules")

local State = require(Modules:WaitForChild("State"))
local HUD = require(Modules:WaitForChild("HUD"))
local Effects = require(Modules:WaitForChild("Effects"))
local RayController = require(Modules:WaitForChild("RayController"))

State.Init()
HUD.Init()
Effects.Init()
RayController.Init()

print("[ShrinkIt] Client ready")
