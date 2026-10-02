--[[
	📍 LOCATION: ServerScriptService > Services > ShrinkService (ModuleScript)

	Server-authoritative Shrink Ray.
	Client flow:  ChargeStart(target) → (hold) → FireShrink(target, extraTargets)  or ChargeCancel()
	Server checks: tool equipped, charge actually lasted long enough (server clock), shot cooldown,
	target is a live shrinkable, not reserved for someone else, area unlocked, tier <= Ray Power tier,
	within range, extras within Multi-Shrink radius and count. Raid targets are delegated to RaidService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local ShrinkService = {}
local Svc

local TOOL_NAME = "Shrink Ray"

function ShrinkService.Init(registry)
	Svc = registry
end

function ShrinkService.GetStats(player)
	local data = Svc.Data.Get(player)
	local s = Svc.Session.Get(player)
	if not data or not s then
		return nil
	end
	return Formulas.RayStats(data, s.Passes)
end

local function makeTool()
	local custom = ServerStorage:FindFirstChild("ShrinkRay")
	local tool
	if custom and custom:IsA("Tool") then
		tool = custom:Clone()
	else
		tool = Instance.new("Tool")
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		tool.ToolTip = "Hold to charge on an object!"
		-- Handle = the grip; every other piece is welded to it. Barrel points toward -Z.
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.45, 1.2, 0.6)
		handle.Color = Color3.fromRGB(35, 35, 45)
		handle.Material = Enum.Material.Fabric
		handle.CanCollide = false
		handle.Massless = true
		handle.CFrame = CFrame.new()
		handle.Parent = tool
		local function piece(name, shape, size, cf, color, material, extra)
			local p = Instance.new("Part")
			p.Name = name
			if shape then
				p.Shape = shape
			end
			p.Size = size
			p.CFrame = cf
			p.Color = color
			p.Material = material
			p.CanCollide = false
			p.CanQuery = false
			p.Massless = true
			if extra then
				for k, v in pairs(extra) do
					p[k] = v
				end
			end
			p.Parent = tool
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
			return p
		end
		local cyl = Enum.PartType.Cylinder
		local alongZ = CFrame.Angles(0, math.rad(90), 0) -- cylinders run along X; turn them to point down the barrel
		local metal = Color3.fromRGB(200, 205, 220)
		local dark = Color3.fromRGB(45, 45, 60)
		local glow = Color3.fromRGB(80, 230, 255)
		piece("Body", nil, Vector3.new(0.7, 0.75, 2.2), CFrame.new(0, 0.85, -0.5), metal, Enum.Material.Metal)
		piece("BodyStripe", nil, Vector3.new(0.72, 0.15, 2.0), CFrame.new(0, 0.85, -0.5), Color3.fromRGB(255, 90, 160), Enum.Material.Neon)
		piece("Trigger", nil, Vector3.new(0.12, 0.35, 0.15), CFrame.new(0, 0.3, -0.45), dark, Enum.Material.Metal)
		piece("TriggerGuard", nil, Vector3.new(0.14, 0.12, 0.6), CFrame.new(0, 0.1, -0.4), dark, Enum.Material.Metal)
		piece("Barrel", cyl, Vector3.new(1.8, 0.45, 0.45), CFrame.new(0, 0.95, -2.3) * alongZ, metal, Enum.Material.Metal)
		for i = 0, 2 do
			piece("Coil", cyl, Vector3.new(0.14, 0.62, 0.62), CFrame.new(0, 0.95, -1.75 - i * 0.42) * alongZ, glow, Enum.Material.Neon)
		end
		piece("Emitter", cyl, Vector3.new(0.25, 0.95, 0.95), CFrame.new(0, 0.95, -3.2) * alongZ, dark, Enum.Material.Metal)
		piece("EmitterGlow", Enum.PartType.Ball, Vector3.new(0.55, 0.55, 0.55), CFrame.new(0, 0.95, -3.3), glow, Enum.Material.Neon)
		piece("Scope", cyl, Vector3.new(0.9, 0.22, 0.22), CFrame.new(0, 1.4, -0.7) * alongZ, dark, Enum.Material.Metal)
		piece("ScopeLens", cyl, Vector3.new(0.05, 0.2, 0.2), CFrame.new(0, 1.4, -1.16) * alongZ, Color3.fromRGB(255, 80, 80), Enum.Material.Neon)
		piece("Tank", cyl, Vector3.new(0.8, 0.42, 0.42), CFrame.new(0, 0.95, 0.75) * alongZ, Color3.fromRGB(180, 230, 255), Enum.Material.Glass, { Transparency = 0.4 })
		piece("TankFluid", cyl, Vector3.new(0.7, 0.3, 0.3), CFrame.new(0, 0.95, 0.75) * alongZ, Color3.fromRGB(140, 255, 120), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = glow
		light.Range = 6
		light.Brightness = 1.5
		light.Parent = tool:FindFirstChild("EmitterGlow")
		local tip = Instance.new("Attachment")
		tip.Name = "Tip"
		tip.Position = Vector3.new(0, 0.95, -3.45)
		tip.Parent = handle
		tool.Grip = CFrame.new(0, -0.1, 0.1)
	end
	tool.Name = TOOL_NAME
	tool:SetAttribute("ShrinkRay", true)
	return tool
end

local function giveTool(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	if backpack:FindFirstChild(TOOL_NAME) or (player.Character and player.Character:FindFirstChild(TOOL_NAME)) then
		return
	end
	makeTool().Parent = backpack
end

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function surfaceDistance(root, model)
	local cf, size = model:GetBoundingBox()
	local rel = cf:PointToObjectSpace(root.Position)
	local half = size / 2
	local clamped = Vector3.new(math.clamp(rel.X, -half.X, half.X), math.clamp(rel.Y, -half.Y, half.Y), math.clamp(rel.Z, -half.Z, half.Z))
	return (rel - clamped).Magnitude
end

-- Returns kind ("object" | "building" | "pedestal") for a valid instance, else nil.
local function targetKind(target)
	if typeof(target) ~= "Instance" or not target:IsA("Model") or not target:IsDescendantOf(workspace) then
		return nil
	end
	if target:GetAttribute("RaidBuilding") then
		return "building"
	elseif target:GetAttribute("PedestalSlot") then
		return "pedestal"
	elseif Svc.Spawn.GetInfo(target) then
		return "object"
	end
	return nil
end

-- Validates a normal shrink target. Returns info or nil, reason.
function ShrinkService.CheckObject(player, model, stats, root)
	local info = Svc.Spawn.GetInfo(model)
	if not info then
		return nil, "gone"
	end
	if info.ReservedFor and info.ReservedFor ~= player.UserId then
		return nil, "reserved"
	end
	local pos = model:GetPivot().Position
	local areaTier = Svc.Map.GetAreaAt(pos)
	if areaTier and not Svc.Area.IsTierUnlocked(player, areaTier) then
		return nil, "locked"
	end
	if surfaceDistance(root, model) > stats.Range + GameConfig.RangeTolerance then
		return nil, "range"
	end
	return info
end

-- Shrinks a validated object for `player`.
function ShrinkService.Capture(player, model)
	local claimed = Svc.Spawn.Claim(model)
	if not claimed then
		return false
	end
	local data = Svc.Data.Get(player)
	local fromPos = model:GetPivot().Position
	Remotes.Event("ShrinkFX"):FireAllClients(model, player, claimed.Variant, false)
	Svc.Spawn.Remove(model, claimed, GameConfig.ShrinkFxTime)
	-- you now CARRY it; it only goes into the museum once you run it back to base
	local session = Svc.Session.Get(player)
	session.PendingCarry = (session.PendingCarry or 0) + 1
	task.delay(GameConfig.ShrinkFxTime * 0.85, function()
		session.PendingCarry -= 1
		if player.Parent then
			Svc.Carry.Add(player, claimed.Id, claimed.Variant, fromPos)
		end
	end)
	data.TotalShrinks += 1
	Svc.Data.MarkDirty(player)

	local item = { Id = claimed.Id, V = claimed.Variant }
	do
		local income = Formulas.ItemBaseIncome(item) * Svc.Economy.GetIncomeMultiplier(player)
		Svc.Net.Notify(player, "🎒 " .. Formulas.ItemName(item) .. " (+" .. Format.Coins(income) .. "/s) — bring it back to base!", "shrink")
		local def = ObjectConfig.Get(claimed.Id)
		local variant = RarityConfig.GetVariant(claimed.Variant)
		local rarity = RarityConfig.GetRarity(def.Rarity)
		if variant.Order >= 4 or rarity.Order >= 6 then
			Svc.Net.Announce("🔬 " .. player.DisplayName .. " shrank a " .. Formulas.ItemName(item) .. "!", variant.Color or rarity.Color)
		end
	end
	return true
end

local function requiredChargeTime(kind, stats, target)
	if kind == "building" then
		return GameConfig.Raid.BuildingChargeTime
	elseif kind == "object" then
		local info = Svc.Spawn.GetInfo(target)
		return Formulas.ObjectChargeTime(stats, info and info.Tier or 1)
	end
	return stats.ChargeTime
end

local function onChargeStart(player, target)
	local s = Svc.Session.Get(player)
	local stats = ShrinkService.GetStats(player)
	if not s or not stats or not Svc.Session.Throttle(player, "charge", 0.1) then
		return
	end
	local kind = targetKind(target)
	if not kind then
		return
	end
	if not (player.Character and player.Character:FindFirstChild(TOOL_NAME)) then
		return
	end
	s.Charge = { Target = target, Kind = kind, Start = os.clock(), Time = requiredChargeTime(kind, stats, target) }
	Remotes.Event("ChargeFX"):FireAllClients(player, target, true)
end

local function onChargeCancel(player)
	local s = Svc.Session.Get(player)
	if s and s.Charge then
		s.Charge = nil
		Remotes.Event("ChargeFX"):FireAllClients(player, nil, false)
	end
end

local function onFire(player, target, extras)
	local s = Svc.Session.Get(player)
	local stats = ShrinkService.GetStats(player)
	local root = rootOf(player)
	if not s or not stats or not root then
		return
	end
	local charge = s.Charge
	s.Charge = nil
	Remotes.Event("ChargeFX"):FireAllClients(player, nil, false)
	if not charge or charge.Target ~= target then
		return
	end
	if os.clock() - charge.Start < charge.Time * GameConfig.ChargeTolerance then
		return -- fired too early (possible exploit or lag): ignore
	end
	if os.clock() - s.LastShot < GameConfig.ShrinkCooldown then
		return
	end
	if not (player.Character and player.Character:FindFirstChild(TOOL_NAME)) then
		return
	end
	s.LastShot = os.clock()

	if charge.Kind == "building" then
		Svc.Raid.TryStartRaid(player, target, root)
		return
	elseif charge.Kind == "pedestal" then
		Svc.Raid.TryZap(player, target, root)
		return
	end

	local room = stats.Carry - Svc.Carry.Count(player) - (s.PendingCarry or 0)
	if room <= 0 then
		Svc.Net.Notify(player, "🎒 Hands full! Run back to base to drop off your loot.", "error")
		return
	end

	local info, reason = ShrinkService.CheckObject(player, target, stats, root)
	if not info then
		if reason == "range" then
			Svc.Net.Notify(player, "Too far away!", "error")
		elseif reason == "reserved" then
			Svc.Net.Notify(player, "That one is reserved for someone else!", "error")
		elseif reason == "locked" then
			Svc.Net.Notify(player, "🔒 Unlock this area first!", "error")
		end
		return
	end
	ShrinkService.Capture(player, target)

	-- Multi-Shrink extras (limited by how much room you have left to carry)
	if type(extras) == "table" and room > 1 then
		local origin = target:GetPivot().Position
		local seen = { [target] = true }
		local count = 1
		for i = 1, math.min(#extras, room - 1) do
			local extra = extras[i]
			if typeof(extra) == "Instance" and not seen[extra] and targetKind(extra) == "object" then
				seen[extra] = true
				if (extra:GetPivot().Position - origin).Magnitude <= GameConfig.MultiShrinkRadius + 10 then
					local extraInfo = ShrinkService.CheckObject(player, extra, stats, root)
					if extraInfo and extraInfo.Tier <= info.Tier and count < room then
						count += 1
						ShrinkService.Capture(player, extra)
					end
				end
			end
		end
	end
end

-- Auto Shrink gamepass: zaps the nearest valid object on its own.
local function autoShrinkLoop()
	while true do
		task.wait(0.3)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local s = Svc.Session.Get(player)
			local data = Svc.Data.Get(player)
			if s and data and s.Passes.AutoShrink and data.Settings.AutoShrink and now >= s.NextAuto and Svc.Carry.Count(player) < Svc.Carry.Capacity(player) then
				local root = rootOf(player)
				local stats = ShrinkService.GetStats(player)
				if root and stats then
					local best, bestScore = nil, math.huge
					Svc.Spawn.ForEachActive(function(model, _info)
						local d = (model:GetPivot().Position - root.Position).Magnitude
						if d < stats.Range + 200 then
							local info = ShrinkService.CheckObject(player, model, stats, root)
							if info then
								local score = Formulas.ObjectChargeTime(stats, info.Tier) * 10 + d
								if score < bestScore then
									best, bestScore = model, score
								end
							end
						end
					end)
					local locked = s.AutoTarget
					if locked and locked.Model.Parent and Svc.Spawn.GetInfo(locked.Model) then
						-- keep charging the locked target until its (power-scaled) charge time has passed
						if now >= locked.ReadyAt then
							s.AutoTarget = nil
							if ShrinkService.CheckObject(player, locked.Model, stats, root) then
								ShrinkService.Capture(player, locked.Model)
							end
							s.NextAuto = now + GameConfig.AutoShrinkExtraDelay
						end
					elseif best then
						local info = Svc.Spawn.GetInfo(best)
						s.AutoTarget = { Model = best, ReadyAt = now + Formulas.ObjectChargeTime(stats, info and info.Tier or 1) }
					else
						s.AutoTarget = nil
						s.NextAuto = now + 1
					end
				end
			end
		end
	end
end

function ShrinkService.OnPlayerLoaded(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		giveTool(player)
	end)
	if player.Character then
		giveTool(player)
	end
end

function ShrinkService.Start()
	Remotes.Event("ChargeStart").OnServerEvent:Connect(onChargeStart)
	Remotes.Event("ChargeCancel").OnServerEvent:Connect(onChargeCancel)
	Remotes.Event("FireShrink").OnServerEvent:Connect(onFire)

	Svc.Net.Handle("SetAutoShrink", function(player, on)
		local data = Svc.Data.Get(player)
		if not Svc.Session.HasPass(player, "AutoShrink") then
			return { ok = false, msg = "Requires the Auto Shrink gamepass!" }
		end
		data.Settings.AutoShrink = on == true
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)

	task.spawn(autoShrinkLoop)
end

return ShrinkService
