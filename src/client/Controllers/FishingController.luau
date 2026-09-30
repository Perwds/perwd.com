--!nonstrict
-- Casting input. Owns the client half of the fishing state machine:
-- idle -> waiting for a bite -> reeling -> idle.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Zones = require(Shared.Config.Zones)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local GameConfig = require(Shared.Config.GameConfig)

local ReelBar = require(script.Parent.Parent.UI.ReelBar)
local Theme = require(script.Parent.Parent.UI.Theme)
local Tackle = require(script.Parent.Parent.Effects.Tackle)
local CatchFx = require(script.Parent.Parent.Effects.CatchFx)

local FishingController = {}

local MAX_CAST_DISTANCE = 140

local player = Players.LocalPlayer

local state = "idle"
local activeCastId = nil
local castedAt = 0
local zoneId = Zones.Default()

local hud = nil
local panels = nil
local waterTag = "FishingWater"

local function setState(next: string)
	state = next

	if not hud then
		return
	end

	if state == "idle" then
		hud:SetPrompt("Click the water to cast")
	elseif state == "waiting" then
		hud:SetPrompt("Waiting for a bite…", Theme.TextDim)
	elseif state == "reeling" then
		hud:SetPrompt("Hold to reel!", Theme.Good)
	end
end

-- Terrain water is what the zones are actually made of now, so a raycast hit is
-- identified by its material rather than by the instance it struck. The tag
-- check is a fallback for any part-built water.
local function waterUnderMouse(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }
	params.IgnoreWater = false

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	if not result then
		return nil
	end

	local isWater = result.Material == Enum.Material.Water
		or CollectionService:HasTag(result.Instance, waterTag)

	if not isWater then
		return nil
	end

	return result.Position
end

local function tryCast()
	if state ~= "idle" then
		return
	end

	if panels and panels:IsOpen() then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local position = waterUnderMouse()
	if not position then
		return
	end

	-- Mirror the server's checks so the failure is explained here rather than
	-- silently dropped. The server still re-validates both.
	if (root.Position - position).Magnitude > MAX_CAST_DISTANCE then
		hud:Notify("Too far — get closer to the water.", "warn")
		return
	end

	local zone = Zones.Get(zoneId)
	local flat = Vector3.new(position.X - zone.origin.X, 0, position.Z - zone.origin.Z)
	if flat.Magnitude > zone.radius then
		hud:Notify("Cast into the water in your zone.", "warn")
		return
	end

	castedAt = os.clock()
	setState("waiting")
	Tackle.Cast(position)
	Net.Event(Net.Events.RequestCast):FireServer(position)
end

local function onBite(config)
	if state ~= "waiting" then
		return
	end

	activeCastId = config.castId
	setState("reeling")
	Tackle.SetTense(true)

	ReelBar.Start(FishingController.gui, config, function(won)
		if activeCastId == nil then
			return
		end
		Net.Event(Net.Events.SubmitReel):FireServer(activeCastId, won)
	end)
end

local function onCatchResult(result)
	local landed = Tackle.Landed()

	activeCastId = nil
	ReelBar.Cancel()
	Tackle.Clear(true)
	setState("idle")

	if not hud then
		return
	end

	if result.escaped then
		hud:Notify(result.reason == "timeout" and "It got away." or "It slipped the hook.", "bad")
		return
	end

	local tier = Rarities.Data[result.rarity]
	local mutation = Mutations.Data[result.mutation]
	local color = (result.mutation ~= "None" and mutation and mutation.color)
		or (tier and tier.color)
		or Theme.Text

	CatchFx.Play(
		landed,
		color,
		Rarities.IndexOf(result.rarity),
		Mutations.IndexOf(result.mutation)
	)

	hud:ShowCatch(result)
end

function FishingController.SetZone(nextZone: string)
	zoneId = nextZone
end

function FishingController.Start(config)
	FishingController.gui = config.gui
	hud = config.hud
	panels = config.panels
	waterTag = config.waterTag or waterTag

	setState("idle")

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			tryCast()
		end
	end)

	Net.Event(Net.Events.BiteAlert).OnClientEvent:Connect(onBite)
	Net.Event(Net.Events.CatchResult).OnClientEvent:Connect(onCatchResult)

	-- A cast that never resolves (server restart, dropped packet) should not
	-- strand the player unable to cast again.
	task.spawn(function()
		while true do
			task.wait(5)
			if state == "waiting" and os.clock() - castedAt > GameConfig.CastLifetime + 5 then
				Net.Event(Net.Events.CancelCast):FireServer()
				Tackle.Clear()
				setState("idle")
			end
		end
	end)

	player.CharacterAdded:Connect(function()
		activeCastId = nil
		ReelBar.Cancel()
		Tackle.Clear()
		CatchFx.Reset()
		setState("idle")
	end)
end

return FishingController
