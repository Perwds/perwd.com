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

-- ── treadmill looks (ReplicatedStorage > TreadmillModels, TreadmillConfig) ─────────────
-- Your plot's treadmill uses the model for your Treadmill upgrade tier, or the skin you equipped.
-- The built-in Belt part stays underneath (invisible), so training works exactly the same.
-- (Older option still works: models in ServerStorage > CustomModels > Treadmills override the tiers.)
local HttpService = game:GetService("HttpService")
local TreadmillConfig = require(ReplicatedStorage.Shared.Config.TreadmillConfig)

local function findModel(name)
	local folder = ReplicatedStorage:FindFirstChild("TreadmillModels")
	return folder and folder:FindFirstChild(name)
end

local function customTiers()
	local holder = game:GetService("ServerStorage"):FindFirstChild("CustomModels")
	local folder = holder and holder:FindFirstChild("Treadmills", true)
	local list = {}
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		if m:IsA("Model") then
			table.insert(list, m)
		end
	end
	table.sort(list, function(x, y)
		return (tonumber(x.Name:match("%d+")) or 0) < (tonumber(y.Name:match("%d+")) or 0)
	end)
	return list
end

local function lookFor(data)
	local skin = data and data.EquippedTreadmill ~= "" and TreadmillConfig.Skins[data.EquippedTreadmill]
	if skin and data.TreadmillSkins and data.TreadmillSkins[data.EquippedTreadmill] then
		local m = findModel(skin.Model)
		if m then
			return m
		end
	end
	local max = require(ReplicatedStorage.Shared.Config.UpgradeConfig).Upgrades.Treadmill.MaxLevel or 30
	local level = data and data.Upgrades and data.Upgrades.Treadmill or 1
	local custom = customTiers()
	if #custom > 0 then
		return custom[math.clamp(math.ceil(level / max * #custom), 1, #custom)]
	end
	local tiers = TreadmillConfig.Tiers
	return findModel(tiers[math.clamp(math.ceil(level / max * #tiers), 1, #tiers)])
end

-- scales the belt numbers in the model's animation config so the moving belt matches the new size
local function scaleAnimation(look, k)
	for _, d in ipairs(look:GetDescendants()) do
		if d:IsA("StringValue") and d.Name == "AnimationConfig" then
			local ok, cfg = pcall(HttpService.JSONDecode, HttpService, d.Value)
			if ok and type(cfg) == "table" and type(cfg.belt) == "table" then
				local b = cfg.belt
				for _, key in ipairs({ "halfLength", "centerY", "radius", "speed" }) do
					if type(b[key]) == "number" then
						b[key] *= k
					end
				end
				if type(b.origin) == "table" then
					for i, v in ipairs(b.origin) do
						b.origin[i] = v * k
					end
				end
				for _, entry in ipairs(cfg.parts or {}) do
					local an = entry.animation
					if type(an) == "table" then
						for _, key in ipairs({ "amplitude", "radiusX", "radiusZ" }) do
							if type(an[key]) == "number" then
								an[key] *= k
							end
						end
					end
				end
				d.Value = HttpService:JSONEncode(cfg)
			end
		end
	end
	for _, key in ipairs({ "BeltHalfLength", "BeltCenterY", "BeltRadius", "BeltSpeed", "BeltLift" }) do
		local v = look:GetAttribute(key)
		if type(v) == "number" then
			look:SetAttribute(key, v * k)
		end
	end
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
	look.Name = "CustomLook"
	local scripts = {}
	for _, d in ipairs(look:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Script") and d.RunContext == Enum.RunContext.Client then
			table.insert(scripts, d) -- its own belt/roller animation (runs on each player's screen)
		elseif d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
	-- model space: the console end goes to -Z (the end you face while running), like the built-in one
	local pivot = look:GetPivot()
	local sumZ, n, top = 0, 0, -math.huge
	for _, d in ipairs(look:GetDescendants()) do
		if d:IsA("BasePart") then
			top = math.max(top, pivot:PointToObjectSpace(d.Position).Y)
		end
	end
	for _, d in ipairs(look:GetDescendants()) do
		if d:IsA("BasePart") then
			local lp = pivot:PointToObjectSpace(d.Position)
			if lp.Y > top * 0.6 then
				sumZ += lp.Z
				n += 1
			end
		end
	end
	local flip = (n > 0 and sumZ / n > 0) and CFrame.Angles(0, math.pi, 0) or CFrame.new()
	local _, ext = look:GetBoundingBox()
	local k = TreadmillConfig.Length / math.max(ext.Z, ext.X, 0.1)
	look:ScaleTo(look:GetScale() * k)
	scaleAnimation(look, k)
	-- the model's pivot is its base center: put it on the floor under the belt
	local ground = belt.CFrame * CFrame.new(0, -1.15, 0) -- the belt sits 1.15 studs above the floor
	look:PivotTo(ground * flip)
	look.Parent = treadmill
	for _, sc in ipairs(scripts) do
		sc.Enabled = true
	end
end

local function refreshTreadmillLooks()
	for _, plot in pairs(Svc.Map.Plots or {}) do
		local treadmill = plot.Model and plot.Model:FindFirstChild("Treadmill")
		if treadmill then
			local owner = game:GetService("Players"):GetPlayerByUserId(plot.Model:GetAttribute("OwnerUserId") or 0)
			local template = lookFor(owner and Svc.Data.Get(owner))
			if template and (treadmill:GetAttribute("LookName") ~= template:GetFullName() or not treadmill:FindFirstChild("CustomLook")) then
				treadmill:SetAttribute("LookName", template:GetFullName())
				local ok, err = pcall(dressTreadmill, treadmill, template)
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
