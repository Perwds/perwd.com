--[[
	📍 LOCATION: ServerScriptService > Services > SpawnService (ModuleScript)

	Fills every zone with MYSTERY BOXES and respawns them.
	• Box rarity (its color): weighted by RarityConfig SpawnWeight. Rare boxes (GameConfig.Boxes.AnnounceFrom
	  and up) are announced to the whole server with the zone they're in.
	• Everyone sees the SAME boxes. When you shrink one it vanishes for YOU only (the "Taken" attribute
	  lists who took it and each client hides it locally); up to GameConfig.Boxes.MaxClaims players can
	  take the same box before it's gone for everyone and respawns.
	• What's inside is rolled when the box OPENS on a pedestal (SpawnService.RollContents):
	  a random object of that zone (rarer objects likelier in rarer boxes), a variant (your Luck)
	  and a size (your Luck).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local TierConfig = require(Shared.Config.TierConfig)
local EventConfig = require(Shared.Config.EventConfig)
local Formulas = require(Shared.Formulas)
local ModelFactory = require(ServerScriptService.Services.ModelFactory)

local SpawnService = {}
local Svc

local active = {} -- [model] = info
local points = {} -- { Part, Tier, Model, RespawnAt }
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

-- world size of a box in zone `tier` (studs)
local function worldBoxSize(tier)
	return 4.5 + 0.45 * tier
end

local function pickBoxRarity(tier)
	local entries = {}
	-- only rarities that actually have objects in this zone (or rarer, so the box is still worth it)
	local best = 1
	for _, id in ipairs(ObjectConfig.IdsForTier(tier, false)) do
		best = math.max(best, RarityConfig.GetRarity(ObjectConfig.Get(id).Rarity).Order)
	end
	for _, name in ipairs(RarityConfig.RarityOrder) do
		local r = RarityConfig.Rarities[name]
		if r.Order <= best + 1 then
			table.insert(entries, { name, r.SpawnWeight })
		end
	end
	return weightedPick(entries)
end

-- ── what's inside (rolled when the box opens) ─────────────────────────
local function variantMults(player)
	local mults = { Golden = 1, Diamond = 1, Rainbow = 1, Cosmic = 1 }
	if player then
		for k, v in pairs(Svc.Economy.GetVariantMults(player)) do
			mults[k] = v
		end
	end
	local ev = Svc.Event.VariantMults()
	local serverLuck = Svc.Event.GetServerLuckMult()
	for k in pairs(mults) do
		mults[k] *= (ev[k] or 1) * serverLuck
	end
	return mults
end

function SpawnService.RollVariant(player)
	local forced = Svc.Event.ForcedVariant()
	if forced then
		return forced
	end
	local mults = variantMults(player)
	local entries = {}
	for _, name in ipairs(RarityConfig.VariantOrder) do
		local v = RarityConfig.Variants[name]
		table.insert(entries, { name, v.Weight * (mults[name] or 1) })
	end
	return weightedPick(entries)
end

-- player = nil → no Luck (world boxes roll their size when they spawn, the same for everyone)
function SpawnService.RollSize(player)
	local luck = player and math.sqrt(variantMults(player).Golden) or Svc.Event.SizeLuck()
	if player and Svc.Session.HasPass(player, "BigSizes") then
		luck *= 3
	end
	local entries = {}
	for _, entry in ipairs(GameConfig.Sizes) do
		table.insert(entries, { entry.Mult, entry.Weight * (entry.Lucky and luck or 1) })
	end
	return weightedPick(entries)
end

-- Mutation roll (nil = none): the box zone's own mutation first, then a global one.
-- Luck raises the chance AND tilts the roll toward the rarer mutations. box.MutationBoost (Lab serum /
-- boss boxes) multiplies the chance; box.ForceMutation guarantees one.
function SpawnService.RollMutation(player, box)
	if box and box.FMName and MutationConfig.Get(box.FMName) then
		return box.FMName -- a box that always has this mutation (limited event box)
	end
	local luck = math.sqrt(variantMults(player).Golden)
	local boost = ((box and box.MB) or 1) * Svc.Event.MutationMult()
	local zoneName = box and box.T and MutationConfig.ZoneMutation(box.T)
	if zoneName and math.random() < MutationConfig.ZoneChance * luck * boost then
		return zoneName
	end
	local chance = math.min(MutationConfig.MaxChance, MutationConfig.BaseChance * luck ^ 0.6 * boost)
	if not (box and box.FM) and math.random() >= chance then
		return nil
	end
	local entries = {}
	for i, name in ipairs(MutationConfig.Order) do
		table.insert(entries, { name, MutationConfig.Mutations[name].Weight * luck ^ ((i - 1) * 0.15) })
	end
	return weightedPick(entries)
end

-- box = { R, T, V, Z } → id, variant, size, mutation
function SpawnService.RollContents(player, box)
	if box.Id then -- old save: the object was decided when it was shrunk
		return box.Id, box.V or "Normal", 1, nil
	end
	local boxRarity = RarityConfig.GetRarity(box.R)
	local boost = GameConfig.Boxes.RarityBoost[box.R] or 1
	local entries = {}
	for _, id in ipairs(ObjectConfig.IdsForTier(box.T or 1, false)) do
		local r = RarityConfig.GetRarity(ObjectConfig.Get(id).Rarity)
		-- never more than 2 steps rarer than the box itself
		if r.Order <= boxRarity.Order + 2 then
			table.insert(entries, { id, r.SpawnWeight * boost ^ (r.Order - 1) })
		end
	end
	local id = weightedPick(entries) or ObjectConfig.IdsForTier(1, false)[1]
	return id, box.V or SpawnService.RollVariant(player), box.Z or SpawnService.RollSize(player), SpawnService.RollMutation(player, box)
end

-- ── world boxes ───────────────────────────────────────────────────────
local function announceIfRare(box, tier)
	local r = RarityConfig.GetRarity(box.R)
	local from = RarityConfig.GetRarity(GameConfig.Boxes.AnnounceFrom)
	local variant = RarityConfig.GetVariant(box.V)
	if r.Order >= from.Order or variant.Order >= 3 then
		local area = TierConfig.Tiers[tier] and TierConfig.Tiers[tier].Area or ("Zone " .. tier)
		Svc.Net.Announce(string.format("A %s spawned in %s!", Formulas.BoxName(box), area), variant.Color or r.Color)
		Svc.Net.Sound("Alarm")
	end
end

-- Spawns a box of `tier` with its bottom at `position`. opts: { R, V, Point, Expires, ReservedFor, ReservedUntil, Quiet }
function SpawnService.SpawnAt(tier, position, opts)
	opts = opts or {}
	-- the SIZE is decided now, so everyone can see the big boxes in the zone and pick a target
	local box = { R = opts.R or pickBoxRarity(tier), T = tier, V = opts.V, Z = opts.Z or SpawnService.RollSize(nil), FM = opts.FM, MB = opts.MB }
	local model = ModelFactory.CreateBox(box)
	ModelFactory.FitToSize(model, worldBoxSize(tier) * box.Z ^ 0.6)
	ModelFactory.PlaceOnGround(model, position, math.random() * math.pi * 2)
	uidCounter += 1
	local info = {
		Box = box,
		Tier = tier,
		Variant = box.V or "Normal",
		Point = opts.Point,
		Expires = opts.Expires or (os.clock() + GameConfig.Boxes.Lifetime + math.random() * 60),
		ReservedFor = opts.ReservedFor,
		ReservedUntil = opts.ReservedUntil,
		Claims = {},
		ClaimCount = 0,
		Uid = uidCounter,
	}
	model.Name = "MysteryBox"
	model:SetAttribute("Tier", tier)
	model:SetAttribute("BoxRarity", box.R)
	model:SetAttribute("BoxSize", box.Z)
	model:SetAttribute("Variant", info.Variant)
	model:SetAttribute("SpawnUid", info.Uid)
	model:SetAttribute("ReservedFor", info.ReservedFor)
	model:SetAttribute("Taken", ",")
	CollectionService:AddTag(model, "Shrinkable")
	ModelFactory.SetCollision(model, false) -- never block players running home
	model:SetAttribute("Landed", opts.Falling ~= true)
	if opts.Mega then
		model:SetAttribute("Mega", true)
	end
	model.Parent = Svc.Map.LiveObjects
	SpawnService.AddRarityFX(model, box, opts.Mega)
	active[model] = info
	if not opts.Quiet then
		announceIfRare(box, tier)
	end
	return model, info
end

-- ── crate effects by rarity: sparkles (Rare), ground ring (Epic), light beam to the sky (Legendary+) ──
function SpawnService.AddRarityFX(model, box, mega)
	local r = RarityConfig.GetRarity(box.R)
	local body = model.PrimaryPart
	if not body then
		return
	end
	local cf, size = model:GetBoundingBox()
	local ground = Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
	local extras = {}
	if r.Order >= 3 or mega then
		local p = Instance.new("ParticleEmitter")
		p.Name = "RarityFX"
		p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		p.Color = ColorSequence.new(r.Color)
		p.LightEmission = 1
		p.Size = NumberSequence.new(0.6, 0)
		p.Lifetime = NumberRange.new(1, 2)
		p.Rate = 6 + r.Order * 2
		p.Speed = NumberRange.new(1, 3)
		p.SpreadAngle = Vector2.new(180, 180)
		p.Parent = body
	end
	if r.Order >= 4 or mega then
		local ring = Instance.new("Part")
		ring.Name = "RarityRing"
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(0.12, size.X * 1.8, size.X * 1.8)
		ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
		ring.Material = Enum.Material.Neon
		ring.Color = r.Color
		ring.Transparency = 0.55
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.CastShadow = false
		table.insert(extras, ring)
	end
	if r.Order >= 5 or mega then
		local beam = Instance.new("Part")
		beam.Name = "RarityBeam"
		local h = mega and 160 or 90
		beam.Size = Vector3.new(mega and 4 or 2, h, mega and 4 or 2)
		beam.CFrame = CFrame.new(ground + Vector3.new(0, h / 2, 0))
		beam.Material = Enum.Material.Neon
		beam.Color = mega and Color3.fromRGB(255, 120, 230) or r.Color
		beam.Transparency = 0.6
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		local light = Instance.new("PointLight")
		light.Color = beam.Color
		light.Range = 30
		light.Brightness = 2
		light.Parent = beam
		table.insert(extras, beam)
	end
	for _, e in ipairs(extras) do
		e:SetAttribute("ForBox", model:GetAttribute("SpawnUid"))
		e.Parent = Svc.Map.LiveObjects
	end
	if #extras > 0 then
		model.Destroying:Connect(function()
			for _, e in ipairs(extras) do
				e:Destroy()
			end
		end)
		-- gone for you = its beam/ring too (the client hides them with the box)
		model:SetAttribute("HasFX", true)
	end
end

-- MEGA BOX event: a giant, always-mutated box in a random zone (shared by up to MaxClaims players)
function SpawnService.SpawnMegaBox()
	local tiers = {}
	for tier in pairs(Svc.Map.Areas) do
		table.insert(tiers, tier)
	end
	local tier = tiers[math.random(1, #tiers)]
	local pos = Svc.Map.RandomPointInArea(tier, 20)
	if not pos then
		return
	end
	local rarity = RarityConfig.RarityOrder[math.min(#RarityConfig.RarityOrder, 5 + math.random(0, 1))]
	SpawnService.SpawnAt(tier, pos, { R = rarity, Z = 5, FM = true, MB = 3, Mega = true, Quiet = true, Expires = os.clock() + 180 })
	local area = TierConfig.Tiers[tier] and TierConfig.Tiers[tier].Area or ("Zone " .. tier)
	Svc.Net.Announce("A MEGA BOX landed in " .. area .. "! Follow the pink beam!", Color3.fromRGB(255, 120, 230))
	Svc.Net.Sound("Alarm")
end

-- BOX RAIN event: a box drops from the sky somewhere in a random zone
function SpawnService.RainBox()
	local tiers = {}
	for tier in pairs(Svc.Map.Areas) do
		table.insert(tiers, tier)
	end
	local tier = tiers[math.random(1, #tiers)]
	local pos = Svc.Map.RandomPointInArea(tier, 10)
	if not pos then
		return
	end
	local model = SpawnService.SpawnAt(tier, pos, { Quiet = true, Falling = true, Expires = os.clock() + 90 })
	if not model then
		return
	end
	local landed = model:GetPivot()
	for i = 1, 12 do
		if not model.Parent then
			return
		end
		model:PivotTo(landed + Vector3.new(0, 60 * (1 - i / 12) ^ 2, 0))
		task.wait(0.04)
	end
	if model.Parent then
		model:PivotTo(landed)
		model:SetAttribute("Landed", true)
	end
end

local function spawnPoint(pt)
	local ground = pt.Part.Position - Vector3.new(0, pt.Part.Size.Y / 2, 0)
	pt.Model = SpawnService.SpawnAt(pt.Tier, ground, { Point = pt })
end

-- info for a live box; with `player`, nil if that player already took it
function SpawnService.GetInfo(model, player)
	local info = active[model]
	if not info or info.Gone then
		return nil
	end
	if player and info.Claims[player.UserId] then
		return nil
	end
	return info
end

function SpawnService.ForEachActive(fn, player)
	for model, info in pairs(active) do
		if not info.Gone and model.Parent and not (player and info.Claims[player.UserId]) then
			fn(model, info)
		end
	end
end

local function retire(model, info, delaySeconds)
	info.Gone = true
	active[model] = nil
	local respawn = TierConfig.Tiers[info.Tier] and TierConfig.Tiers[info.Tier].RespawnTime or 30
	respawn *= Svc.Event.RespawnMult(info.Tier)
	if info.Point and info.Point.Model == model then
		info.Point.Model = nil
		info.Point.RespawnAt = os.clock() + respawn
	end
	task.delay(delaySeconds or 0, function()
		if model then
			model:Destroy()
		end
	end)
end

-- `player` takes the box. Returns a copy of the box ({ R, T, V }) or nil if they can't.
function SpawnService.Claim(model, player)
	local info = SpawnService.GetInfo(model, player)
	if not info then
		return nil
	end
	info.Claims[player.UserId] = true
	info.ClaimCount += 1
	model:SetAttribute("Taken", (model:GetAttribute("Taken") or ",") .. player.UserId .. ",")
	if info.ClaimCount >= GameConfig.Boxes.MaxClaims then
		retire(model, info, GameConfig.ShrinkFxTime + 0.2)
	end
	-- your copy of the box already knows its SIZE (the box is that big) and your LUCK when you grabbed it
	return { R = info.Box.R, T = info.Box.T, V = info.Box.V, Z = info.Box.Z or SpawnService.RollSize(player), L = SpawnService.LuckOf(player, info.Box) }, info
end

-- Luck shown when hovering a box: your luck (upgrades, passes, events) x how good the box rarity is.
function SpawnService.LuckOf(player, box)
	local luck = math.sqrt(variantMults(player).Golden)
	return math.floor(luck * (GameConfig.Boxes.RarityBoost[box.R] or 1) * 10 + 0.5) / 10
end

-- Bonus box that is not tied to a spawn point (Giant Rush, events).
function SpawnService.SpawnExtra(tier, variant, lifetime)
	local pos = Svc.Map.RandomPointInArea(tier, worldBoxSize(tier) / 2 + 6)
	if not pos then
		return nil
	end
	return SpawnService.SpawnAt(tier, pos, { V = variant, Expires = os.clock() + (lifetime or 120) })
end

function SpawnService.SpawnEventObject()
	local occupied = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local t = root and Svc.Map.GetAreaAt(root.Position)
		if t then
			table.insert(occupied, t)
		end
	end
	local tier = #occupied > 0 and occupied[math.random(1, #occupied)] or math.random(1, math.min(3, #TierConfig.Tiers))
	local entries = {}
	for name, w in pairs(RarityConfig.EventVariantWeights) do
		table.insert(entries, { name, w })
	end
	SpawnService.SpawnExtra(tier, weightedPick(entries), EventConfig.EventObjects.Lifetime)
end

-- Developer Product: a Golden box right next to the buyer (reserved for them for 60s).
function SpawnService.SpawnNear(player, variant)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local tier = (root and Svc.Map.GetAreaAt(root.Position)) or 1
	local origin = root and (root.Position + root.CFrame.LookVector * 8) or Svc.Map.LobbySpawn.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, Svc.Map.LiveObjects }
	local hit = workspace:Raycast(origin + Vector3.new(0, 20, 0), Vector3.new(0, -200, 0), params)
	local ground = hit and hit.Position or Vector3.new(origin.X, 0, origin.Z)
	SpawnService.SpawnAt(tier, ground, {
		V = variant,
		Expires = os.clock() + 300,
		ReservedFor = player.UserId,
		ReservedUntil = os.clock() + 60,
		Quiet = true,
	})
	Svc.Net.Notify(player, "A " .. variant .. " box appeared next to you! (Reserved for 60s)", "success")
end

-- ── NIGHT: the wall comes down over the zone entrance, every box is replaced, the wall goes up ──
local function buildWall()
	local area = Svc.Map.Areas[1]
	local width = area and area.Floor and area.Floor.Size.X or 200
	local wall = Instance.new("Part")
	wall.Name = "NightWall"
	wall.Anchored = true
	wall.CanCollide = false
	wall.Size = Vector3.new(width, 70, 3)
	wall.Color = Color3.fromRGB(235, 236, 242)
	wall.Material = Enum.Material.SmoothPlastic
	wall.TopSurface = Enum.SurfaceType.Smooth
	wall:SetAttribute("Down", Vector3.new(0, -36, 1.5))
	wall:SetAttribute("Up", Vector3.new(0, 35, 1.5))
	wall.CFrame = CFrame.new(wall:GetAttribute("Down"))
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Countdown"
	gui.Face = Enum.NormalId.Front -- faces the base (-Z)
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 10
	gui.LightInfluence = 0
	gui.Parent = wall
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.45)
	label.Size = UDim2.fromScale(0.6, 0.35)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(60, 62, 75)
	label.Text = "NIGHT"
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 6
	stroke.Color = Color3.fromRGB(25, 25, 35)
	stroke.Parent = label
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	local back = gui:Clone()
	back.Face = Enum.NormalId.Back
	back.Parent = wall
	wall.Parent = Svc.Map.LiveObjects
	return wall
end

local function moveWall(wall, up)
	local TweenService = game:GetService("TweenService")
	local goal = CFrame.new(wall:GetAttribute(up and "Up" or "Down"))
	wall.CanCollide = up
	TweenService:Create(wall, TweenInfo.new(1.6, Enum.EasingStyle.Quad, up and Enum.EasingDirection.Out or Enum.EasingDirection.In), { CFrame = goal }):Play()
end

local function setWallText(wall, text)
	for _, gui in ipairs(wall:GetChildren()) do
		if gui:IsA("SurfaceGui") then
			gui.Text.Text = text
		end
	end
end

-- replaces every box in every zone (spawned behind the wall, so it's fair for everyone)
function SpawnService.ResetAll()
	for model, info in pairs(active) do
		if info.Point then
			retire(model, info, 0)
		end
	end
	for _, pt in ipairs(points) do
		pt.RespawnAt = 0
	end
end

local function nightLoop()
	local cfg = GameConfig.Night
	if not cfg or (cfg.Every or 0) <= 0 then
		return
	end
	local wall = buildWall()
	workspace:SetAttribute("NightAt", os.time() + cfg.Every)
	while true do
		task.wait(cfg.Every - cfg.Warning)
		while workspace:GetAttribute("BossActive") or workspace:GetAttribute("BossIn") do
			task.wait(5) -- no night during a boss fight
		end
		Svc.Net.Announce("Night is coming! The zones close in " .. cfg.Warning .. " seconds - get back to base!", Color3.fromRGB(150, 160, 255))
		for i = cfg.Warning, 1, -1 do
			workspace:SetAttribute("NightIn", i)
			task.wait(1)
		end
		workspace:SetAttribute("NightIn", nil)
		-- close: everyone still in the zones goes back to base (with what they carry)
		moveWall(wall, true)
		local spawn = Svc.Map.LobbySpawn
		for _, player in ipairs(Players:GetPlayers()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root and spawn and root.Position.Z > 0 then
				player.Character:PivotTo(spawn.CFrame * CFrame.new(math.random(-6, 6), 4, math.random(-6, 6)))
				Svc.Net.Notify(player, "Night! You were sent back to the base.", "info")
			end
		end
		SpawnService.ResetAll()
		for i = cfg.Closed, 1, -1 do
			setWallText(wall, "NIGHT  " .. i .. "s")
			workspace:SetAttribute("NightLeft", i)
			task.wait(1)
		end
		workspace:SetAttribute("NightLeft", nil)
		setWallText(wall, "NIGHT")
		moveWall(wall, false)
		workspace:SetAttribute("NightAt", os.time() + cfg.Every)
		Svc.Net.Announce("Morning! Fresh boxes in every zone!", Color3.fromRGB(255, 220, 90))
		Svc.Net.Sound("Alarm")
	end
end

function SpawnService.Start()
	task.spawn(nightLoop)
	for tier, area in pairs(Svc.Map.Areas) do
		for _, part in ipairs(area.SpawnPoints) do
			local pt = { Part = part, Tier = tier, Model = nil, RespawnAt = 0 }
			table.insert(points, pt)
		end
	end
	for _, pt in ipairs(points) do
		local ok, err = pcall(function()
			local ground = pt.Part.Position - Vector3.new(0, pt.Part.Size.Y / 2, 0)
			pt.Model = SpawnService.SpawnAt(pt.Tier, ground, { Point = pt, Quiet = true })
		end)
		if not ok then
			warn("[SpawnService] first spawn failed: " .. tostring(err))
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
				if info.Expires and now >= info.Expires then
					retire(model, info, 0)
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
