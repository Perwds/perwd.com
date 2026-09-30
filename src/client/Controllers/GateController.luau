--[[
	Zone gates.

	A gate is solid for everyone on the server, so letting one player through
	has to be a local decision: the server publishes ownership as a Player
	attribute, and this drops the local collision and fades the wall for the
	worlds this player has unlocked.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local player = Players.LocalPlayer

local GateController = {}

local function gateFor(world: string): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local zones = map and map:FindFirstChild("Zones")
	local zone = zones and zones:FindFirstChild(world)
	return zone and zone:FindFirstChild("Gate") :: BasePart?
end

local function apply(world: string)
	local gate = gateFor(world)
	if not gate then
		return
	end

	local unlocked = player:GetAttribute(`World_{world}`) == true

	-- Local-only change: it affects this client's physics and view, and is
	-- never replicated back to the server.
	gate.CanCollide = not unlocked

	TweenService:Create(gate, TweenInfo.new(0.4), {
		Transparency = unlocked and 0.9 or 0.45,
	}):Play()

	local label = gate:FindFirstChild("Label")
	if label then
		label.Enabled = not unlocked
	end

	local prompt = gate:FindFirstChildWhichIsA("ProximityPrompt")
	if prompt then
		prompt.Enabled = not unlocked
	end
end

function GateController.start()
	local function applyAll()
		for _, world in Worlds.Order do
			apply(world)
		end
	end

	for _, world in Worlds.Order do
		player:GetAttributeChangedSignal(`World_{world}`):Connect(function()
			apply(world)
		end)
	end

	-- The map streams in after the client starts, so retry until it is there.
	task.spawn(function()
		for _ = 1, 40 do
			if Workspace:FindFirstChild("Map") then
				applyAll()
				break
			end
			task.wait(0.25)
		end
	end)

	-- Gates also need re-applying whenever the character reloads.
	player.CharacterAdded:Connect(function()
		task.delay(0.5, applyAll)
	end)
end

return GateController
