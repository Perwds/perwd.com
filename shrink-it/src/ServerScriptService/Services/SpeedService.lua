--[[
	📍 LOCATION: ServerScriptService > Services > SpeedService (ModuleScript)

	Speed TRAINING (replaces buying speed): every plot has a treadmill. Stand on YOUR treadmill
	(going AFK on it is fine) and you earn Speed points every second:
	    points/sec = Treadmill upgrade value (x2 with the "2x Speed" gamepass)
	    walk speed = BaseWalkSpeed + min(MaxBonus, PointsFactor * sqrt(points)) (bonus x2 with the pass)
	Tune it in GameConfig.Training and UpgradeConfig.Upgrades.Treadmill.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Formulas)

local SpeedService = {}
local Svc

function SpeedService.Init(registry)
	Svc = registry
end

local function treadmillOf(player)
	local plot = Svc.Museum.GetPlot(player)
	local model = plot and plot.Model:FindFirstChild("Treadmill")
	return model and model:FindFirstChild("Belt")
end

function SpeedService.IsTraining(player)
	local belt = treadmillOf(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not belt or not root then
		return false
	end
	local rel = belt.CFrame:PointToObjectSpace(root.Position)
	-- generous area: anywhere on (or just next to) the belt counts
	return math.abs(rel.X) <= belt.Size.X / 2 + 2 and math.abs(rel.Z) <= belt.Size.Z / 2 + 2 and rel.Y > -2 and rel.Y < 9
end

-- "Train" prompt on every treadmill: puts you straight onto the belt (yours only).
local function setTraining(player, on)
	local belt = treadmillOf(player)
	player:SetAttribute("TreadmillCF", on and belt and belt.CFrame or nil)
	player:SetAttribute("TreadmillTop", on and belt and belt.Size.Y / 2 or nil)
	player:SetAttribute("TreadmillLen", on and belt and belt.Size.Z or nil)
	player:SetAttribute("Training", on)
end

local function addTrainPrompts()
	for _, plot in pairs(Svc.Map.Plots or {}) do
		local model = plot.Model and plot.Model:FindFirstChild("Treadmill")
		local belt = model and model:FindFirstChild("Belt")
		if belt and not belt:FindFirstChild("TrainPrompt") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "TrainPrompt"
			prompt.ActionText = "Train Speed"
			prompt.ObjectText = "Treadmill"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 16
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Parent = belt
			prompt.Triggered:Connect(function(player)
				if treadmillOf(player) ~= belt then
					Svc.Net.Notify(player, "That's not your treadmill! Yours is next to your plot.", "error")
					return
				end
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root then
					character:PivotTo(belt.CFrame * CFrame.new(0, belt.Size.Y / 2 + 3, 0))
				end
				setTraining(player, true)
			end)
		end
	end
end

function SpeedService.Start()
	task.spawn(addTrainPrompts)
	local tick = GameConfig.Training.Tick
	task.spawn(function()
		local beat = 0
		while true do
			task.wait(tick)
			beat += 1
			for _, player in ipairs(Players:GetPlayers()) do
				local data = Svc.Data.Get(player)
				local s = Svc.Session.Get(player)
				if data and s then
					local training = SpeedService.IsTraining(player)
					if player:GetAttribute("Training") ~= training then
						-- the client locks you onto the belt and plays a running animation (Effects.treadmillLock)
						setTraining(player, training)
					end
					if training then
						local rate = Formulas.TrainingRate(data, s.Passes)
						local before = math.floor(Formulas.SpeedBonus(data, s.Passes))
						data.SpeedPoints = (data.SpeedPoints or 0) + rate * tick
						player:SetAttribute("TrainingRate", rate)
						Svc.Data.MarkDirty(player)
						local after = math.floor(Formulas.SpeedBonus(data, s.Passes))
						if after ~= before or beat % 5 == 0 then
							Svc.Monetization.ApplyMovement(player)
						end
					end
				end
			end
		end
	end)

	Svc.Data.AddSyncProvider(function(player, payload)
		local data = Svc.Data.Get(player)
		local s = Svc.Session.Get(player)
		if data and s then
			payload.Speed = {
				Points = data.SpeedPoints or 0,
				Walk = Formulas.RayStats(data, s.Passes).WalkSpeed,
				Rate = Formulas.TrainingRate(data, s.Passes),
				Training = player:GetAttribute("Training") == true,
			}
		end
	end)
end

return SpeedService
