--!nonstrict
-- Casting input and the bobber. Owns the client half of the fishing state
-- machine: idle -> waiting for a bite -> reeling -> idle.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

local ReelBar = require(script.Parent.Parent.UI.ReelBar)

local FishingController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local state = "idle"
local activeCastId = nil
local bobber: BasePart? = nil
local bobberStart = 0
local bobberConnection: RBXScriptConnection? = nil

local hud = nil
local panels = nil
local waterTag = "FishingWater"

local function clearBobber()
	if bobberConnection then
		bobberConnection:Disconnect()
		bobberConnection = nil
	end
	if bobber then
		bobber:Destroy()
		bobber = nil
	end
end

local function spawnBobber(position: Vector3)
	clearBobber()

	local part = Instance.new("Part")
	part.Name = "Bobber"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.Color = Color3.fromRGB(255, 96, 96)
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = position
	part.Parent = Workspace

	bobber = part
	bobberStart = os.clock()

	bobberConnection = RunService.RenderStepped:Connect(function()
		if not bobber then
			return
		end
		local t = os.clock() - bobberStart
		local bob = math.sin(t * 3) * 0.25
		-- Twitchier once something is on the line.
		if state == "reeling" then
			bob = math.sin(t * 22) * 0.55
		end
		bobber.Position = Vector3.new(position.X, position.Y + bob, position.Z)
	end)
end

local function setState(next: string)
	state = next

	if not hud then
		return
	end

	if state == "idle" then
		hud:SetPrompt("Click the water to cast")
	elseif state == "waiting" then
		hud:SetPrompt("Waiting for a bite…")
	elseif state == "reeling" then
		hud:SetPrompt("Hold to reel!")
	end
end

local function waterUnderMouse(): (BasePart?, Vector3?)
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }

	local result = Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
	if not result then
		return nil, nil
	end

	if not CollectionService:HasTag(result.Instance, waterTag) then
		return nil, nil
	end

	return result.Instance, result.Position
end

local function tryCast()
	if state ~= "idle" then
		return
	end

	if panels and panels:IsOpen() then
		return
	end

	local water, position = waterUnderMouse()
	if not water or not position then
		return
	end

	setState("waiting")
	spawnBobber(position)
	Net.Event(Net.Events.RequestCast):FireServer(position)
end

local function onBite(config)
	if state ~= "waiting" then
		return
	end

	activeCastId = config.castId
	setState("reeling")

	ReelBar.Start(FishingController.gui, config, function(won)
		if activeCastId == nil then
			return
		end
		Net.Event(Net.Events.SubmitReel):FireServer(activeCastId, won)
	end)
end

local function onCatchResult(result)
	activeCastId = nil
	ReelBar.Cancel()
	clearBobber()
	setState("idle")

	if not hud then
		return
	end

	if result.escaped then
		hud:Notify(result.reason == "timeout" and "It got away." or "It slipped the hook.", "bad")
	else
		hud:ShowCatch(result)
	end
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
	-- strand the player in a state where they cannot cast again.
	task.spawn(function()
		while true do
			task.wait(5)
			if state == "waiting" and bobber and os.clock() - bobberStart > 95 then
				Net.Event(Net.Events.CancelCast):FireServer()
				clearBobber()
				setState("idle")
			end
		end
	end)

	player.CharacterAdded:Connect(function()
		activeCastId = nil
		ReelBar.Cancel()
		clearBobber()
		setState("idle")
	end)
end

return FishingController
