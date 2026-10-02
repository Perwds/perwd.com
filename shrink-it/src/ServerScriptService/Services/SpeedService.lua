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
	return math.abs(rel.X) <= belt.Size.X / 2 + 0.5 and math.abs(rel.Z) <= belt.Size.Z / 2 + 0.5 and rel.Y > -1 and rel.Y < 8
end

function SpeedService.Start()
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
						local belt = treadmillOf(player)
						player:SetAttribute("TreadmillCF", training and belt and belt.CFrame or nil)
						player:SetAttribute("TreadmillTop", training and belt and belt.Size.Y / 2 or nil)
						player:SetAttribute("TreadmillLen", training and belt and belt.Size.Z or nil)
						player:SetAttribute("Training", training)
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
