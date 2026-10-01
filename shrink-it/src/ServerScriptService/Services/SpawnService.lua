--[[
	📍 LOCATION: ServerScriptService > Services > SpawnService (ModuleScript)

	Spawns shrinkable objects at every area spawn point and respawns them after a cooldown.
	• Object choice: weighted by rarity SpawnWeight within the area's tier.
	• Variant roll: weighted RNG. Non-Normal weights are multiplied by the BEST luck of the
	  players currently standing in that area (luck, 2x Luck, Golden Ray, Cosmic Hunter, potions,
	  VIP), plus server-wide modifiers (Server Luck Boost, Golden Hour). Meteor Shower forces Cosmic.
	• Hand-placed models tagged "Shrinkable" are registered too (static: they hide & return).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local TierConfig = require(Shared.Config.TierConfig)
local EventConfig = require(Shared.Config.EventConfig)
local Formulas = require(Shared.Formulas)
local ModelFactory = require(ServerScriptService.Services.ModelFactory)

local SpawnService = {}
local Svc

local active = {} -- [model] = info
local points = {} -- { Part, Tier, Model, RespawnAt }
local hiddenFolder
local uidCounter = 0

function SpawnService.Init(registry)
	Svc = registry
end

local function weightedPick(entries) -- { {Key, Weight} }
	local total = 0
	for _, e in ipairs(entries) do
		total += e[2]
	end
	if total <= 0 then
		return entries[1] and entries[1][1]
	end
	local roll = math.random() * total
	for _, e in ipairs(entries) do
		roll -= e[2]
		if roll <= 0 then
			return e[1]
		end
	end
	return entries[#entries][1]
end

local function pickObject(tier)
	local entries = {}
	for _, id in ipairs(ObjectConfig.IdsForTier(tier, false)) do
		local def = ObjectConfig.Get(id)
		table.insert(entries, { id, RarityConfig.GetRarity(def.Rarity).SpawnWeight })
	end
	return weightedPick(entries)
end

-- Best variant multipliers among players in this area, times event modifiers.
local function areaVariantMults(tier)
	local best = { Golden = 1, Diamond = 1, Rainbow = 1, Cosmic = 1 }
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and Svc.Data.Get(player) and Svc.Map.GetAreaAt(root.Position) == tier then
			local m = Svc.Economy.GetVariantMults(player)
			for k, v in pairs(m) do
				best[k] = math.max(best[k], v)
			end
		end
	end
	local ev = Svc.Event.VariantMults()
	local serverLuck = Svc.Event.GetServerLuckMult()
	for k in pairs(best) do
		best[k] *= ev[k] * serverLuck
	end
	return best
end

function SpawnService.RollVariant(tier)
	local forced = Svc.Event.ForcedVariant()
	if forced then
		return forced
	end
	local mults = areaVariantMults(tier)
	local entries = {}
	for _, name in ipairs(RarityConfig.VariantOrder) do
		local v = RarityConfig.Variants[name]
		table.insert(entries, { name, v.Weight * (mults[name] or 1) })
	end
	return weightedPick(entries)
end

local function decorate(model, id, variant, info)
	uidCounter += 1
	info.Uid = uidCounter
	local def = ObjectConfig.Get(id)
	model:SetAttribute("ObjectId", id)
	model:SetAttribute("Tier", def.Tier)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("BaseIncome", def.BaseIncome)
	model:SetAttribute("Variant", variant)
	model:SetAttribute("SpawnUid", info.Uid)
	model:SetAttribute("ReservedFor", info.ReservedFor)
	ModelFactory.ApplyVariant(model, variant, true)
	ModelFactory.AddLabel(model, id, variant)
	CollectionService:AddTag(model, "Shrinkable")
end

-- Spawns an object of `tier` with its bottom at `position`. opts: { Id, Variant, Point, Expires, ReservedFor, ReservedUntil }
function SpawnService.SpawnAt(tier, position, opts)
	opts = opts or {}
	local id = opts.Id or pickObject(tier)
	if not id then
		return nil
	end
	local def = ObjectConfig.Get(id)
	local variant = opts.Variant or SpawnService.RollVariant(tier)
	local model = ModelFactory.Create(id)
	ModelFactory.PlaceOnGround(model, position + Vector3.new(0, def.FloatHeight or 0, 0), math.random() * math.pi * 2)
	local info = {
		Id = id,
		Tier = def.Tier,
		Variant = variant,
		Point = opts.Point,
		Expires = opts.Expires,
		ReservedFor = opts.ReservedFor,
		ReservedUntil = opts.ReservedUntil,
		Static = false,
	}
	decorate(model, id, variant, info)
	model.Parent = Svc.Map.LiveObjects
	active[model] = info
	return model, info
end

local function spawnPoint(pt)
	local ground = pt.Part.Position - Vector3.new(0, pt.Part.Size.Y / 2, 0)
	pt.Model = SpawnService.SpawnAt(pt.Tier, ground, { Point = pt })
end

function SpawnService.GetInfo(model)
	local info = active[model]
	if info and not info.Claimed then
		return info
	end
	return nil
end

function SpawnService.ForEachActive(fn)
	for model, info in pairs(active) do
		if not info.Claimed and model.Parent then
			fn(model, info)
		end
	end
end

-- Marks an object as taken. Returns info (or nil if someone else got it first).
function SpawnService.Claim(model)
	local info = active[model]
	if not info or info.Claimed then
		return nil
	end
	info.Claimed = true
	active[model] = nil
	local respawn = TierConfig.Tiers[info.Tier] and TierConfig.Tiers[info.Tier].RespawnTime or 30
	respawn *= Svc.Event.RespawnMult(info.Tier)
	if info.Point then
		info.Point.Model = nil
		info.Point.RespawnAt = os.clock() + respawn
	end
	if info.Static then
		task.delay(respawn + 1, function()
			if model and info.HomeParent then
				local variant = SpawnService.RollVariant(info.Tier)
				local newInfo = { Id = info.Id, Tier = info.Tier, Variant = variant, Static = true, HomeParent = info.HomeParent }
				decorate(model, info.Id, variant, newInfo)
				model.Parent = info.HomeParent
				active[model] = newInfo
			end
		end)
	end
	return info
end

-- Removes the model after the client tween finished.
function SpawnService.Remove(model, info, delaySeconds)
	task.delay(delaySeconds or 0, function()
		if not model then
			return
		end
		if info and info.Static then
			CollectionService:RemoveTag(model, "Shrinkable")
			model.Parent = hiddenFolder
		else
			model:Destroy()
		end
	end)
end

local function objectFootprint(id)
	local def = ObjectConfig.Get(id)
	local size = def and def.Size or Vector3.new(10, 10, 10)
	return math.max(size.X, size.Z)
end

-- Bonus object that is not tied to a spawn point (Giant Rush, events).
function SpawnService.SpawnExtra(tier, variant, lifetime, id)
	id = id or pickObject(tier)
	if not id then
		return nil
	end
	local pos = Svc.Map.RandomPointInArea(tier, objectFootprint(id) / 2 + 6)
	if not pos then
		return nil
	end
	return SpawnService.SpawnAt(tier, pos, { Id = id, Variant = variant, Expires = os.clock() + (lifetime or 120) })
end

function SpawnService.SpawnEventObject()
	-- prefer areas that players are standing in
	local occupied = {}
	local maxUnlocked = 1
	for _, player in ipairs(Players:GetPlayers()) do
		local data = Svc.Data.Get(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if data then
			maxUnlocked = math.max(maxUnlocked, TierConfig.MaxTierForRayPower(data.Upgrades.RayPower))
		end
		if root then
			local t = Svc.Map.GetAreaAt(root.Position)
			if t then
				table.insert(occupied, t)
			end
		end
	end
	local tier = #occupied > 0 and occupied[math.random(1, #occupied)] or math.random(1, maxUnlocked)
	local entries = {}
	for name, w in pairs(RarityConfig.EventVariantWeights) do
		table.insert(entries, { name, w })
	end
	local variant = weightedPick(entries)
	local model, info = SpawnService.SpawnExtra(tier, variant, EventConfig.EventObjects.Lifetime)
	if model then
		local name = RarityConfig.GetVariant(variant).Prefix .. ObjectConfig.Get(info.Id).Name
		local area = TierConfig.Tiers[tier].Area
		local article = string.match(name, "^[AEIOUaeiou]") and "An" or "A"
		Svc.Net.Announce(string.format("✨ %s %s appeared in %s!", article, name, area), RarityConfig.GetVariant(variant).Color)
	end
end

-- Developer Product: spawn a Golden object right next to the buyer (reserved for them for 60s).
function SpawnService.SpawnNear(player, variant)
	local data = Svc.Data.Get(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local tier = data and TierConfig.MaxTierForRayPower(data.Upgrades.RayPower) or 1
	local id = pickObject(tier)
	local footprint = objectFootprint(id)
	local origin = root and (root.Position + root.CFrame.LookVector * (footprint / 2 + 8)) or Svc.Map.LobbySpawn.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, Svc.Map.LiveObjects }
	local hit = workspace:Raycast(origin + Vector3.new(0, 20, 0), Vector3.new(0, -200, 0), params)
	local ground = hit and hit.Position or Vector3.new(origin.X, 0, origin.Z)
	SpawnService.SpawnAt(tier, ground, {
		Id = id,
		Variant = variant,
		Expires = os.clock() + 300,
		ReservedFor = player.UserId,
		ReservedUntil = os.clock() + 60,
	})
	Svc.Net.Notify(player, "🌟 A " .. Formulas.ItemName({ Id = id, V = variant }) .. " appeared next to you! (Reserved for 60s)", "success")
end

local function registerStatics()
	local folder = ReplicatedStorage:FindFirstChild("CustomObjects")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CustomObjects"
		folder.Parent = ReplicatedStorage
	end
	for _, model in ipairs(CollectionService:GetTagged("Shrinkable")) do
		if model:IsA("Model") and model:IsDescendantOf(workspace) and not model:IsDescendantOf(Svc.Map.LiveObjects) then
			local id = model:GetAttribute("ObjectId") or model.Name
			if not ObjectConfig.Objects[id] and not folder:FindFirstChild(id) then
				local entry = Instance.new("Configuration")
				entry.Name = id
				entry:SetAttribute("DisplayName", model:GetAttribute("DisplayName") or model.Name)
				entry:SetAttribute("Tier", model:GetAttribute("Tier") or 1)
				entry:SetAttribute("Rarity", model:GetAttribute("Rarity") or "Common")
				entry:SetAttribute("BaseIncome", model:GetAttribute("BaseIncome") or 1)
				entry.Parent = folder
			end
			local templates = ModelFactory.TemplatesFolder()
			if not templates:FindFirstChild(id) then
				local tpl = model:Clone()
				tpl.Name = id
				CollectionService:RemoveTag(tpl, "Shrinkable")
				tpl.Parent = templates
			end
			if not model.PrimaryPart then
				model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
			end
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
				end
			end
			local def = ObjectConfig.Get(id)
			local info = { Id = id, Tier = def.Tier, Static = true, HomeParent = model.Parent }
			info.Variant = SpawnService.RollVariant(def.Tier)
			decorate(model, id, info.Variant, info)
			active[model] = info
		end
	end
end

function SpawnService.Start()
	hiddenFolder = Instance.new("Folder")
	hiddenFolder.Name = "ShrunkStatics"
	hiddenFolder.Parent = ServerStorage

	registerStatics()

	for tier, area in pairs(Svc.Map.Areas) do
		for _, part in ipairs(area.SpawnPoints) do
			local pt = { Part = part, Tier = tier, Model = nil, RespawnAt = 0 }
			table.insert(points, pt)
			spawnPoint(pt)
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()
			for _, pt in ipairs(points) do
				if not pt.Model and now >= pt.RespawnAt then
					local ok, err = pcall(spawnPoint, pt)
					if not ok then
						warn("[SpawnService] spawn failed: " .. tostring(err))
						pt.RespawnAt = now + 10
					end
				end
			end
			for model, info in pairs(active) do
				if info.Expires and now >= info.Expires and not info.Claimed then
					active[model] = nil
					model:Destroy()
				elseif info.ReservedUntil and now >= info.ReservedUntil then
					info.ReservedFor = nil
					info.ReservedUntil = nil
					model:SetAttribute("ReservedFor", nil)
				end
			end
		end
	end)
end

return SpawnService
