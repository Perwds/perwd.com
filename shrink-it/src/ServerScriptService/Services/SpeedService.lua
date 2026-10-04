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

-- ── your treadmill models (ServerStorage > CustomModels > Treadmills, or models named Treadmill1..5) ──
-- The better your Treadmill upgrade, the fancier the model on your plot: levels are split evenly
-- across however many models you imported (sorted by name). The invisible Belt part stays, so
-- training works exactly the same. No models imported → the built-in treadmill is used.
local function treadmillModels()
	local holder = game:GetService("ServerStorage"):FindFirstChild("CustomModels")
	if not holder then
		return {}
	end
	local list = {}
	local folder = holder:FindFirstChild("Treadmills", true)
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:IsA("Model") or m:IsA("BasePart") then
				table.insert(list, m)
			end
		end
	else
		for _, m in ipairs(holder:GetDescendants()) do
			if m.Name:match("^Treadmill%s*_?%d+$") and (m:IsA("Model") or m:IsA("BasePart")) then
				table.insert(list, m)
			end
		end
	end
	table.sort(list, function(a, b)
		local na, nb = tonumber(a.Name:match("%d+")) or 0, tonumber(b.Name:match("%d+")) or 0
		if na ~= nb then
			return na < nb
		end
		return a.Name < b.Name
	end)
	return list
end

local function dressTreadmill(treadmill, template)
	local belt = treadmill:FindFirstChild("Belt")
	if not belt then
		return
	end
	local old = treadmill:FindFirstChild("CustomLook")
	if old then
		old:Destroy()
	end
	for _, d in ipairs(treadmill:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1 -- built-in parts hidden; the Belt keeps working underneath
		elseif d:IsA("SurfaceGui") then
			d.Enabled = false
		end
	end
	local look = template:Clone()
	if look:IsA("BasePart") then
		local wrap = Instance.new("Model")
		look.Parent = wrap
		look = wrap
	end
	look.Name = "CustomLook"
	for _, d in ipairs(look:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	-- longest flat side along the belt, 13 studs long, standing on the ground under the belt
	local ground = belt.CFrame * CFrame.new(0, -1.15, 0) -- the belt sits 1.15 studs above the floor
	look:PivotTo(CFrame.new())
	local _, ext = look:GetBoundingBox()
	local turn = ext.X > ext.Z and CFrame.Angles(0, math.rad(90), 0) or CFrame.new()
	local long = math.max(ext.X, ext.Z)
	if long > 0 then
		look:ScaleTo(look:GetScale() * (13 / long))
	end
	look:PivotTo(ground * turn)
	local cf, size = look:GetBoundingBox()
	local floorY = ground.Position.Y
	look:PivotTo(look:GetPivot() + Vector3.new(belt.Position.X - cf.Position.X, floorY - (cf.Position.Y - size.Y / 2), belt.Position.Z - cf.Position.Z))
	look.Parent = treadmill
end

local function refreshTreadmillLooks()
	local models = treadmillModels()
	if #models == 0 then
		return
	end
	local max = (require(ReplicatedStorage.Shared.Config.UpgradeConfig).Upgrades.Treadmill.MaxLevel) or 30
	for _, plot in pairs(Svc.Map.Plots or {}) do
		local treadmill = plot.Model and plot.Model:FindFirstChild("Treadmill")
		if treadmill then
			local level = 1
			local owner = game:GetService("Players"):GetPlayerByUserId(plot.Model:GetAttribute("OwnerUserId") or 0)
			local data = owner and Svc.Data.Get(owner)
			if data and data.Upgrades then
				level = data.Upgrades.Treadmill or 1
			end
			local index = math.clamp(math.ceil(level / max * #models), 1, #models)
			if treadmill:GetAttribute("LookIndex") ~= index or not treadmill:FindFirstChild("CustomLook") then
				treadmill:SetAttribute("LookIndex", index)
				local ok, err = pcall(dressTreadmill, treadmill, models[index])
				if not ok then
					warn("[SpeedService] treadmill model failed: " .. tostring(err))
				end
			end
		end
	end
end

function SpeedService.Start()
	task.spawn(function()
		while true do
			pcall(refreshTreadmillLooks)
			task.wait(2)
		end
	end)

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
