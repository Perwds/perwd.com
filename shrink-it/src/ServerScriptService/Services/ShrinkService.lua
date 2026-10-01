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
local TierConfig = require(Shared.Config.TierConfig)
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
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.8, 1, 3)
		handle.Color = Color3.fromRGB(60, 60, 80)
		handle.Material = Enum.Material.SmoothPlastic
		handle.CanCollide = false
		handle.Massless = true
		handle.Parent = tool
		local barrel = Instance.new("Part")
		barrel.Name = "Barrel"
		barrel.Shape = Enum.PartType.Cylinder
		barrel.Size = Vector3.new(1.4, 0.7, 0.7)
		barrel.Color = Color3.fromRGB(80, 220, 255)
		barrel.Material = Enum.Material.Neon
		barrel.CanCollide = false
		barrel.Massless = true
		barrel.CFrame = handle.CFrame * CFrame.new(0, 0.1, -1.9) * CFrame.Angles(0, math.rad(90), 0)
		barrel.Parent = tool
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = barrel
		weld.Parent = handle
		local tip = Instance.new("Attachment")
		tip.Name = "Tip"
		tip.Position = Vector3.new(0, 0.1, -2.7)
		tip.Parent = handle
		tool.Grip = CFrame.new(0, -0.2, 0.6)
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
	if info.Tier > stats.MaxTier then
		return nil, "toobig", info
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
	Remotes.Event("ShrinkFX"):FireAllClients(model, player, claimed.Variant, false)
	Svc.Spawn.Remove(model, claimed, GameConfig.ShrinkFxTime)
	local item = Svc.Museum.AddItem(player, claimed.Id, claimed.Variant)
	data.TotalShrinks += 1
	Svc.Data.MarkDirty(player)

	if item then
		local income = Formulas.ItemBaseIncome(item) * Svc.Economy.GetIncomeMultiplier(player)
		Svc.Net.Notify(player, "+ " .. Formulas.ItemName(item) .. "  (+" .. Format.Coins(income) .. "/s)", "shrink")
		local def = ObjectConfig.Get(claimed.Id)
		local variant = RarityConfig.GetVariant(claimed.Variant)
		local rarity = RarityConfig.GetRarity(def.Rarity)
		if variant.Order >= 4 or rarity.Order >= 6 then
			Svc.Net.Announce("🔬 " .. player.DisplayName .. " shrank a " .. Formulas.ItemName(item) .. "!", variant.Color or rarity.Color)
		end
	end
	return true
end

local function requiredChargeTime(kind, stats)
	if kind == "building" then
		return GameConfig.Raid.BuildingChargeTime
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
	s.Charge = { Target = target, Kind = kind, Start = os.clock(), Time = requiredChargeTime(kind, stats) }
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

	local info, reason, tooBigInfo = ShrinkService.CheckObject(player, target, stats, root)
	if not info then
		if reason == "toobig" then
			local need = TierConfig.Tiers[tooBigInfo.Tier].RayPowerRequired
			Remotes.Event("TooBig"):FireClient(player, need)
		elseif reason == "range" then
			Svc.Net.Notify(player, "Too far away!", "error")
		elseif reason == "reserved" then
			Svc.Net.Notify(player, "That one is reserved for someone else!", "error")
		elseif reason == "locked" then
			Svc.Net.Notify(player, "🔒 Unlock this area first!", "error")
		end
		return
	end
	ShrinkService.Capture(player, target)

	-- Multi-Shrink extras
	if type(extras) == "table" and stats.Multi > 1 then
		local origin = target:GetPivot().Position
		local seen = { [target] = true }
		local count = 1
		for i = 1, math.min(#extras, stats.Multi - 1) do
			local extra = extras[i]
			if typeof(extra) == "Instance" and not seen[extra] and targetKind(extra) == "object" then
				seen[extra] = true
				if (extra:GetPivot().Position - origin).Magnitude <= GameConfig.MultiShrinkRadius + 10 then
					local extraInfo = ShrinkService.CheckObject(player, extra, stats, root)
					if extraInfo and count < stats.Multi then
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
			if s and data and s.Passes.AutoShrink and data.Settings.AutoShrink and now >= s.NextAuto then
				local root = rootOf(player)
				local stats = ShrinkService.GetStats(player)
				if root and stats then
					local best, bestDist = nil, math.huge
					Svc.Spawn.ForEachActive(function(model, _info)
						local d = (model:GetPivot().Position - root.Position).Magnitude
						if d < bestDist and d < stats.Range + 200 then
							local info = ShrinkService.CheckObject(player, model, stats, root)
							if info then
								best, bestDist = model, d
							end
						end
					end)
					if best then
						s.NextAuto = now + stats.ChargeTime + GameConfig.AutoShrinkExtraDelay
						ShrinkService.Capture(player, best)
					else
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
