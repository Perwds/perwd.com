--[[
	📍 LOCATION: ServerScriptService > Services > BossService (ModuleScript)

	DR. GROW'S ROBOT (every GameConfig.Boss.Every seconds):
	  • A warning, then a giant robot lands in the base arena. Its pilot, Dr. Grow, has a GROWTH ray:
	    it zaps players, who get big and slow for a few seconds.
	  • Everyone shrinks it down together with their Shrink Rays (hold on the robot, like a box).
	    The robot visibly shrinks as it loses HP.
	  • Beat it before the time limit: everyone who helped gets SAMPLES (more for more damage) and
	    +1 Boss Mastery. Mastery milestones (GameConfig.Boss.MasteryMilestones) give a MASTERY BOX:
	    always mutated, at least Huge, a box you can't get anywhere else.

	THE LAB (stand in the base): turn in unopened boxes you carry for Samples, buy a Mutation Serum
	(your next placed box is much more likely to mutate) or a Mastery Box with Samples.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TierConfig = require(Shared.Config.TierConfig)
local RarityConfig = require(Shared.Config.RarityConfig)

local BossService = {}
local Svc

local boss = nil -- { Model, Body, Muzzle, HP, Max, Damage = { [userId] = n }, EndsAt }

function BossService.Init(registry)
	Svc = registry
end

local function cfg()
	return GameConfig.Boss
end

-- ── the robot ────────────────────────────────────────────────────────
local function buildRobot()
	local model = Instance.new("Model")
	model.Name = "Dr. Grow's Robot"
	local function p(name, size, cf, color, material, shape)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = cf
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = name == "Body" or name:find("Leg") ~= nil
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			part.Shape = shape
		end
		part.Parent = model
		return part
	end
	local metal = Color3.fromRGB(120, 130, 150)
	local dark = Color3.fromRGB(45, 50, 65)
	local green = Color3.fromRGB(110, 255, 90)
	for _, s in ipairs({ -1, 1 }) do
		p("Leg", Vector3.new(4, 12, 4), CFrame.new(s * 5, 6, 0), dark, Enum.Material.Metal)
		p("Foot", Vector3.new(6, 2, 8), CFrame.new(s * 5, 1, -1), metal, Enum.Material.Metal)
		p("Knee", Vector3.new(5, 3, 5), CFrame.new(s * 5, 9, -0.5), metal, Enum.Material.Metal)
		p("Arm", Vector3.new(3.5, 10, 3.5), CFrame.new(s * 10.5, 18, 0), dark, Enum.Material.Metal)
		p("Shoulder", Vector3.new(6, 5, 6), CFrame.new(s * 10, 24, 0), metal, Enum.Material.Metal)
	end
	local body = p("Body", Vector3.new(16, 14, 11), CFrame.new(0, 19, 0), metal, Enum.Material.Metal)
	p("Belly", Vector3.new(10, 6, 0.6), CFrame.new(0, 17, -5.7), dark, Enum.Material.Metal)
	p("Light", Vector3.new(8, 1, 0.4), CFrame.new(0, 21.5, -5.8), green, Enum.Material.Neon)
	-- glass cockpit with Dr. Grow inside
	p("Cockpit", Vector3.new(9, 9, 9), CFrame.new(0, 29, 0), Color3.fromRGB(170, 230, 255), Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.45
	p("DrGrowHead", Vector3.new(2.6, 2.6, 2.6), CFrame.new(0, 29.5, 0), Color3.fromRGB(240, 200, 170), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	p("DrGrowHair", Vector3.new(3, 1.2, 3), CFrame.new(0, 31, 0.2), Color3.fromRGB(240, 240, 245), Enum.Material.SmoothPlastic)
	p("DrGrowGoggles", Vector3.new(2.4, 0.6, 0.3), CFrame.new(0, 29.8, -1.3), green, Enum.Material.Neon)
	p("DrGrowCoat", Vector3.new(3, 2.4, 2), CFrame.new(0, 27.4, 0), Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic)
	-- the growth ray cannon on the right arm
	local cannon = p("Cannon", Vector3.new(7, 3, 3), CFrame.new(10.5, 13, -3) * CFrame.Angles(0, math.rad(90), 0), dark, Enum.Material.Metal, Enum.PartType.Cylinder)
	p("CannonGlow", Vector3.new(0.6, 3.2, 3.2), CFrame.new(10.5, 13, -6.6) * CFrame.Angles(0, math.rad(90), 0), green, Enum.Material.Neon, Enum.PartType.Cylinder)
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = cannon.CFrame:PointToObjectSpace(Vector3.new(10.5, 13, -7))
	muzzle.Parent = cannon
	local light = Instance.new("PointLight")
	light.Color = green
	light.Range = 18
	light.Brightness = 2
	light.Parent = body
	model.PrimaryPart = body
	model:SetAttribute("Boss", true)
	return model, body, muzzle
end

local function setStatus()
	workspace:SetAttribute("BossActive", boss ~= nil)
	workspace:SetAttribute("BossHP", boss and math.max(0, math.ceil(boss.HP)) or nil)
	workspace:SetAttribute("BossMax", boss and boss.Max or nil)
	workspace:SetAttribute("BossEndsAt", boss and boss.EndsAt or nil)
end

-- ── growth ray on players ────────────────────────────────────────────
local function grow(player)
	local character = player.Character
	if not character or player:GetAttribute("Grown") then
		return
	end
	player:SetAttribute("Grown", true)
	pcall(function()
		character:ScaleTo(cfg().GrowScale)
	end)
	Svc.Monetization.ApplyMovement(player)
	Svc.Net.Notify(player, "Dr. Grow made you BIG and slow!", "error")
	task.delay(cfg().GrowSeconds, function()
		player:SetAttribute("Grown", nil)
		if player.Character == character then
			pcall(function()
				character:ScaleTo(1)
			end)
		end
		Svc.Monetization.ApplyMovement(player)
	end)
end

local function shoot()
	if not boss then
		return
	end
	local arena = cfg().Arena
	local targets = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - arena).Magnitude < 140 and not player:GetAttribute("Grown") then
			table.insert(targets, { player, root })
		end
	end
	if #targets == 0 then
		return
	end
	local pick = targets[math.random(1, #targets)]
	local player, root = pick[1], pick[2]
	-- turn toward the target, then fire a green beam
	local pivot = boss.Model:GetPivot()
	local look = Vector3.new(root.Position.X, pivot.Position.Y, root.Position.Z)
	if (look - pivot.Position).Magnitude > 1 then
		boss.Model:PivotTo(CFrame.lookAt(pivot.Position, look))
	end
	local from = boss.Muzzle.WorldPosition
	local to = root.Position
	local beam = Instance.new("Part")
	beam.Name = "GrowthRay"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(110, 255, 90)
	beam.Size = Vector3.new(1.2, 1.2, (to - from).Magnitude)
	beam.CFrame = CFrame.lookAt((from + to) / 2, to)
	beam.Parent = Svc.Map.LiveObjects
	TweenService:Create(beam, TweenInfo.new(0.5), { Transparency = 1, Size = Vector3.new(0.2, 0.2, beam.Size.Z) }):Play()
	task.delay(0.6, function()
		beam:Destroy()
	end)
	Svc.Net.Sound("Charge", nil, to)
	grow(player)
end

-- ── rewards ─────────────────────────────────────────────────────────
function BossService.MasteryBox(player)
	local data = Svc.Data.Get(player)
	local tier = data and TierConfig.MaxTierForRayPower(data.Upgrades.RayPower) or 1
	local z = math.max(GameConfig.MasteryBox.MinSize, Svc.Spawn.RollSize(player))
	return { R = GameConfig.MasteryBox.R, T = tier, Z = z, FM = true, MB = 3, L = Svc.Spawn.LuckOf(player, { R = GameConfig.MasteryBox.R }) }
end

local function giveMasteryBox(player)
	Svc.Carry.GiveBox(player, BossService.MasteryBox(player))
	Svc.Net.Notify(player, "You got a MASTERY BOX! (always mutated) Put it in your base.", "success")
end

local function finish(defeated)
	if not boss then
		return
	end
	local b = boss
	boss = nil
	setStatus()
	if defeated then
		local total = 0
		for _, dmg in pairs(b.Damage) do
			total += dmg
		end
		for userId, dmg in pairs(b.Damage) do
			local player = Players:GetPlayerByUserId(userId)
			local data = player and Svc.Data.Get(player)
			if data then
				local samples = math.floor(cfg().SamplesBase + cfg().SamplesShare * dmg / math.max(1, total))
				data.Samples = (data.Samples or 0) + samples
				data.BossKills = (data.BossKills or 0) + 1
				Svc.Net.Notify(player, "Robot defeated! +" .. samples .. " Samples, Boss Mastery " .. data.BossKills, "success")
				for _, milestone in ipairs(cfg().MasteryMilestones) do
					if data.BossKills == milestone then
						giveMasteryBox(player)
					end
				end
				Svc.Data.MarkDirty(player)
			end
		end
		Svc.Net.Announce("Dr. Grow's robot was shrunk down! Everyone who helped got Samples.", Color3.fromRGB(120, 255, 120))
		-- shrink to nothing and pop
		local start = b.Model:GetScale()
		for i = 1, 10 do
			pcall(function()
				b.Model:ScaleTo(math.max(0.05, start * (1 - i / 10)))
			end)
			task.wait(0.05)
		end
	else
		Svc.Net.Announce("Dr. Grow's robot flew away... next time!", Color3.fromRGB(255, 160, 80))
		TweenService:Create(b.Body, TweenInfo.new(2), { CFrame = b.Body.CFrame + Vector3.new(0, 200, 0) }):Play()
		task.wait(1)
	end
	b.Model:Destroy()
end

-- Called by ShrinkService when a charged shot hits the robot.
function BossService.Hit(player, target, root, stats)
	if not boss or target ~= boss.Model then
		return
	end
	local cf, size = target:GetBoundingBox()
	if (cf.Position - root.Position).Magnitude > stats.Range + math.max(size.X, size.Z) / 2 + 20 then
		Svc.Net.Notify(player, "Get closer to the robot!", "error")
		return
	end
	local dmg = cfg().DamageBase + cfg().DamagePerRayPower * (stats.RayPower or 1)
	boss.HP -= dmg
	boss.Damage[player.UserId] = (boss.Damage[player.UserId] or 0) + dmg
	-- the robot shrinks as it loses HP
	local frac = math.clamp(boss.HP / boss.Max, 0, 1)
	pcall(function()
		boss.Model:ScaleTo(0.45 + 0.55 * frac)
		local cf2, size2 = boss.Model:GetBoundingBox()
		boss.Model:PivotTo(boss.Model:GetPivot() + Vector3.new(0, cfg().Arena.Y - (cf2.Position.Y - size2.Y / 2), 0))
	end)
	Svc.Net.Sound("Pop", nil, cf.Position)
	setStatus()
	if boss.HP <= 0 then
		task.spawn(finish, true)
	end
end

function BossService.IsActive()
	return boss ~= nil
end

local function arrive()
	local arena = cfg().Arena
	local model, body, muzzle = buildRobot()
	local count = math.max(1, #Players:GetPlayers())
	local hp = cfg().BaseHP + cfg().HPPerPlayer * count
	local standY = body.Position.Y -- the robot is built standing on y = 0; its pivot is the body
	model:PivotTo(CFrame.new(arena + Vector3.new(0, standY + 160, 0)))
	model.Parent = workspace
	boss = { Model = model, Body = body, Muzzle = muzzle, HP = hp, Max = hp, Damage = {}, EndsAt = os.time() + cfg().TimeLimit }
	-- drop from the sky
	for i = 1, 20 do
		model:PivotTo(CFrame.new(arena + Vector3.new(0, standY + 160 * (1 - i / 20), 0)))
		task.wait(0.04)
	end
	Svc.Net.Sound("Alarm", nil, arena)
	setStatus()
	Svc.Net.Announce("Dr. Grow's robot has landed! Everyone zap it with your Shrink Ray!", Color3.fromRGB(110, 255, 90))
	local nextShot = os.clock() + cfg().ShotEvery
	while boss and boss.Model == model do
		task.wait(0.25)
		if os.time() >= boss.EndsAt then
			finish(false)
			break
		end
		if os.clock() >= nextShot then
			nextShot = os.clock() + cfg().ShotEvery
			pcall(shoot)
		end
	end
end

local function loop()
	task.wait(cfg().FirstAfter)
	while true do
		Svc.Net.Announce("Dr. Grow is coming to the base in " .. cfg().Warning .. " seconds!", Color3.fromRGB(110, 255, 90))
		for i = cfg().Warning, 1, -1 do
			workspace:SetAttribute("BossIn", i)
			task.wait(1)
		end
		workspace:SetAttribute("BossIn", nil)
		local ok, err = pcall(arrive)
		if not ok then
			warn("[BossService] " .. tostring(err))
			boss = nil
			setStatus()
		end
		task.wait(math.max(60, cfg().Every - cfg().Warning))
	end
end

-- ── the Lab ─────────────────────────────────────────────────────────
local function labHandlers()
	Svc.Net.Handle("LabTurnIn", function(player)
		local data = Svc.Data.Get(player)
		if not data then
			return { ok = false }
		end
		local samples, count = 0, 0
		while Svc.Carry.CountBoxes(player) > 0 do
			local entry = Svc.Carry.TakeTopBox(player)
			if not entry then
				break
			end
			local per = GameConfig.Lab.SamplesPerRarity[RarityConfig.GetRarity(entry.R) and entry.R or "Common"] or 1
			samples += math.ceil(per * (entry.Z or 1))
			count += 1
		end
		if count == 0 then
			return { ok = false, msg = "Bring unopened boxes to turn them in." }
		end
		data.Samples = (data.Samples or 0) + samples
		Svc.Data.MarkDirty(player)
		return { ok = true, msg = "Turned in " .. count .. " box" .. (count == 1 and "" or "es") .. " for " .. samples .. " Samples!" }
	end)

	Svc.Net.Handle("LabBuy", function(player, what)
		local data = Svc.Data.Get(player)
		if not data then
			return { ok = false }
		end
		local cost = what == "Serum" and GameConfig.Lab.SerumCost or what == "MasteryBox" and GameConfig.Lab.MasteryBoxCost or nil
		if not cost then
			return { ok = false }
		end
		if (data.Samples or 0) < cost then
			return { ok = false, msg = "Need " .. cost .. " Samples" }
		end
		data.Samples -= cost
		if what == "Serum" then
			data.Serums = (data.Serums or 0) + 1
			Svc.Data.MarkDirty(player)
			return { ok = true, msg = "Mutation Serum ready: your next placed box is much more likely to mutate!" }
		end
		giveMasteryBox(player)
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)
end

function BossService.Start()
	labHandlers()
	setStatus()
	Svc.Data.AddSyncProvider(function(player, payload)
		local data = Svc.Data.Get(player)
		if data then
			local nextMilestone
			for _, m in ipairs(cfg().MasteryMilestones) do
				if m > (data.BossKills or 0) then
					nextMilestone = m
					break
				end
			end
			payload.Boss = { Samples = data.Samples or 0, Kills = data.BossKills or 0, Serums = data.Serums or 0, NextMilestone = nextMilestone }
		end
	end)
	task.spawn(loop)
end

return BossService
