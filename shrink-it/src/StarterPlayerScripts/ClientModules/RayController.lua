--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > RayController (ModuleScript)

	Shrink Ray input (PC mouse, mobile touch, gamepad trigger via Tool.Activated):
	  aim → hold to charge (bar near the crosshair) → auto-fires at 100% → server validates.
	Releasing early cancels. The client pre-checks size/range only for instant feedback
	("TOO BIG!"); the server re-checks everything.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TierConfig = require(Shared.Config.TierConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local State = require(Modules.State)
local HUD = require(Modules.HUD)
local Effects = require(Modules.Effects)

local RayController = {}

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local tool = nil
local hovered, hoveredKind = nil, nil
local charging = nil -- { Target, Kind, Start, Time, Beam }
local nextShotAt = 0
local selection
local chargeSound

local function findTarget(instance)
	local node = instance
	while node and node ~= workspace do
		if node:IsA("Model") then
			if CollectionService:HasTag(node, "Shrinkable") then
				return node, "object"
			end
			if node:GetAttribute("RaidBuilding") then
				return node, "building"
			end
			if node:GetAttribute("PedestalSlot") then
				return node, "pedestal"
			end
		end
		node = node.Parent
	end
	return nil, nil
end

local function raycastTarget()
	local character = player.Character
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local ray = mouse.UnitRay
	local result = workspace:Raycast(ray.Origin, ray.Direction * 2500, params)
	if not result then
		return nil, nil
	end
	local target, kind = findTarget(result.Instance)
	local data = State.Data
	if not data then
		return nil, nil
	end
	-- raid targets only matter when they're actually usable
	if kind == "building" then
		local owner = target:GetAttribute("OwnerUserId")
		if not data.Settings.RaidEnabled or not owner or owner == 0 or owner == player.UserId then
			return nil, nil
		end
	elseif kind == "pedestal" then
		if not data.ActiveRaid or target:GetAttribute("OwnerUserId") == player.UserId then
			return nil, nil
		end
	end
	return target, kind
end

local function rootPart()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function surfaceDistance(model)
	local root = rootPart()
	if not root then
		return math.huge
	end
	local cf, size = model:GetBoundingBox()
	local rel = cf:PointToObjectSpace(root.Position)
	local half = size / 2
	local clamped = Vector3.new(math.clamp(rel.X, -half.X, half.X), math.clamp(rel.Y, -half.Y, half.Y), math.clamp(rel.Z, -half.Z, half.Z))
	return (rel - clamped).Magnitude
end

local function describe(target, kind)
	local data = State.Data
	local stats = data and data.Stats
	if not stats then
		return nil
	end
	if kind == "building" then
		return "🏴‍☠️ RAID this museum (hold " .. GameConfig.Raid.BuildingChargeTime .. "s)", Color3.fromRGB(255, 90, 90)
	elseif kind == "pedestal" then
		local name = target:GetAttribute("ItemName")
		return name and ("📋 Copy " .. name) or nil, Color3.fromRGB(255, 200, 80)
	end
	local id = target:GetAttribute("ObjectId")
	local def = ObjectConfig.Get(id)
	if not def then
		return nil
	end
	local variant = RarityConfig.GetVariant(target:GetAttribute("Variant"))
	local rarity = RarityConfig.GetRarity(def.Rarity)
	local tier = target:GetAttribute("Tier") or def.Tier
	if tier > stats.MaxTier then
		return "🚫 " .. variant.Prefix .. def.Name .. " — TOO BIG (Ray Power " .. TierConfig.Tiers[tier].RayPowerRequired .. ")", Color3.fromRGB(255, 80, 80)
	end
	local income = Formulas.ItemBaseIncome({ Id = id, V = target:GetAttribute("Variant") or "Normal" })
	income *= (data.Multipliers and data.Multipliers.Income or 1)
	local text = string.format("%s%s · %s · +%s/s", variant.Prefix, def.Name, def.Rarity, Format.Coins(income))
	if surfaceDistance(target) > stats.Range then
		text ..= "  (too far)"
	end
	return text, variant.Color or rarity.Color
end

local function stopCharge(fire)
	if not charging then
		return
	end
	local c = charging
	charging = nil
	if c.Beam then
		c.Beam.Destroy()
	end
	if chargeSound then
		chargeSound:Stop()
	end
	HUD.SetCharge(nil)
	if fire then
		local extras = {}
		local stats = State.Data and State.Data.Stats
		if c.Kind == "object" and stats and stats.Multi > 1 then
			local origin = c.Target:GetPivot().Position
			local candidates = {}
			for _, model in ipairs(CollectionService:GetTagged("Shrinkable")) do
				if model ~= c.Target and model:IsA("Model") and model:IsDescendantOf(workspace) then
					local tier = model:GetAttribute("Tier") or 99
					local d = (model:GetPivot().Position - origin).Magnitude
					if tier <= stats.MaxTier and d <= GameConfig.MultiShrinkRadius and surfaceDistance(model) <= stats.Range then
						table.insert(candidates, { Model = model, D = d })
					end
				end
			end
			table.sort(candidates, function(a, b)
				return a.D < b.D
			end)
			for i = 1, math.min(#candidates, stats.Multi - 1) do
				table.insert(extras, candidates[i].Model)
			end
		end
		Remotes.Event("FireShrink"):FireServer(c.Target, extras)
		nextShotAt = os.clock() + GameConfig.ShrinkCooldown
	else
		Remotes.Event("ChargeCancel"):FireServer()
	end
end

local function startCharge()
	if charging or os.clock() < nextShotAt or not State.Data then
		return
	end
	-- re-raycast now (touch screens update the aim on tap)
	local target, kind = raycastTarget()
	target, kind = target or hovered, kind or hoveredKind
	if not target then
		return
	end
	local stats = State.Data.Stats
	if kind == "object" then
		local tier = target:GetAttribute("Tier") or 1
		if tier > stats.MaxTier then
			HUD.ShowTooBig(TierConfig.Tiers[tier] and TierConfig.Tiers[tier].RayPowerRequired)
			return
		end
		if surfaceDistance(target) > stats.Range then
			HUD.Notify("Too far away! Upgrade Range ⚡", "error")
			return
		end
		local reserved = target:GetAttribute("ReservedFor")
		if reserved and reserved ~= player.UserId then
			HUD.Notify("That one is reserved for someone else!", "error")
			return
		end
	end
	local chargeTime = kind == "building" and GameConfig.Raid.BuildingChargeTime or stats.ChargeTime
	local handle = tool and tool:FindFirstChild("Handle")
	local tip = handle and (handle:FindFirstChild("Tip") or handle:FindFirstChildWhichIsA("Attachment"))
	local beam = tip and Effects.CreateBeam(tip, State.Data.EquippedSkin) or nil
	charging = { Target = target, Kind = kind, Start = os.clock(), Time = chargeTime, Beam = beam }
	Remotes.Event("ChargeStart"):FireServer(target)
	if chargeSound then
		chargeSound.PlaybackSpeed = math.clamp(1.5 / math.max(chargeTime, 0.1), 0.6, 2)
		SoundService:PlayLocalSound(chargeSound)
	end
end

local function bindTool(newTool)
	tool = newTool
	HUD.SetCrosshair(true)
	newTool.Activated:Connect(startCharge)
	newTool.Deactivated:Connect(function()
		if charging and newTool == tool then
			stopCharge(false)
		end
	end)
end

local function watchCharacter(character)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and child:GetAttribute("ShrinkRay") then
			bindTool(child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child == tool then
			stopCharge(false)
			tool = nil
			HUD.SetCrosshair(false)
			HUD.SetHover(nil)
			if selection then
				selection.Adornee = nil
			end
		end
	end)
	local existing = character:FindFirstChildWhichIsA("Tool")
	if existing and existing:GetAttribute("ShrinkRay") then
		bindTool(existing)
	end
end

function RayController.Init()
	selection = Instance.new("SelectionBox")
	selection.Name = "ShrinkHover"
	selection.LineThickness = 0.08
	selection.SurfaceTransparency = 0.85
	selection.Color3 = Color3.fromRGB(90, 220, 255)
	selection.SurfaceColor3 = Color3.fromRGB(90, 220, 255)
	selection.Parent = player:WaitForChild("PlayerGui")

	chargeSound = Instance.new("Sound")
	chargeSound.SoundId = GameConfig.Sounds.Charge
	chargeSound.Volume = 0.35
	chargeSound.Parent = SoundService

	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	RunService.RenderStepped:Connect(function()
		if not tool then
			return
		end
		HUD.UpdateCrosshair()
		-- hover
		local target, kind = raycastTarget()
		hovered, hoveredKind = target, kind
		if target and State.Data then
			local text, color = describe(target, kind)
			HUD.SetHover(text, color)
			selection.Adornee = target
			local tooBig = kind == "object" and (target:GetAttribute("Tier") or 1) > State.Data.Stats.MaxTier
			selection.Color3 = tooBig and Color3.fromRGB(255, 70, 70) or (color or Color3.fromRGB(90, 220, 255))
			selection.SurfaceColor3 = selection.Color3
		else
			HUD.SetHover(nil)
			selection.Adornee = nil
		end
		-- charge
		if charging then
			local c = charging
			if not c.Target.Parent or (c.Kind == "object" and not CollectionService:HasTag(c.Target, "Shrinkable")) then
				stopCharge(false)
				return
			end
			local alpha = math.clamp((os.clock() - c.Start) / math.max(c.Time, 0.05), 0, 1)
			HUD.SetCharge(alpha)
			if c.Beam then
				c.Beam.SetTarget(c.Target:GetPivot().Position)
				c.Beam.SetWidth(0.3 + alpha * 1.4)
			end
			if alpha >= 1 then
				stopCharge(true)
			end
		end
	end)
end

return RayController
