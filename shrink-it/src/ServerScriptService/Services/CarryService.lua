--[[
	📍 LOCATION: ServerScriptService > Services > CarryService (ModuleScript)

	Everything you carry goes into ONE tool in your backpack/hotbar (equip it to hold the top thing):
	  • BOXES you shrank in the zones ({ Kind = "Box", Box = { R, T, V } }).
	  • OBJECTS you picked up from a pedestal ({ Kind = "Item", U = uid }). These are shown at their
	    REAL size (GameConfig.HoldBaseSize x the object's size), on pedestals they all look the same size.

	The chase:
	  1. Shrink a box → that zone's chaser comes running after you.
	  2. Reach the SAFE ZONE (your base) and the chaser gives up.
	  3. Get caught → your boxes fall on the ground and the chaser walks back home, smug.
	     Grab a dropped box back before it disappears (ChaserConfig.DropLifetime) and the chaser gets
	     ENRAGED: faster with every grab (ChaserConfig.RageSpeed per level, up to MaxRage).
	Objects you hold are never lost to chasers (they go back to your pocket), but other players can
	steal them with a bat (PvPService) when you carry them outside the safe zone.

	Capacity = the "Carry Capacity" upgrade (3 → 10), x2 / x5 / Infinite with the carry gamepasses.
	Chasers are server-controlled NPCs (network owner = server), so clients can't cheat them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ChaserConfig = require(Shared.Config.ChaserConfig)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)
local ModelFactory = require(ServerScriptService.Services.ModelFactory)

local CarryService = {}
local Svc

local carrying = {} -- [player] = { Items = { entry }, Chaser = record?, Rage = { [tier] = { Level, CoolAt } } }
local returning = {} -- chasers walking back home after catching someone
local TRACKS = {} -- model → run animation track (handed to the chaser record)

function CarryService.Init(registry)
	Svc = registry
end

local function getState(player)
	local c = carrying[player]
	if not c then
		c = { Items = {}, Chaser = nil, Rage = {} }
		carrying[player] = c
	end
	return c
end

function CarryService.Count(player)
	local c = carrying[player]
	return c and #c.Items or 0
end

function CarryService.CountBoxes(player)
	local c = carrying[player]
	local n = 0
	for _, e in ipairs(c and c.Items or {}) do
		if e.Kind == "Box" then
			n += 1
		end
	end
	return n
end

function CarryService.Capacity(player)
	local stats = Svc.Shrink.GetStats(player)
	return stats and stats.Carry or 1
end

function CarryService.IsCarrying(player)
	return CarryService.Count(player) > 0
end

function CarryService.IsHolding(player, uid)
	local c = carrying[player]
	for _, e in ipairs(c and c.Items or {}) do
		if e.Kind == "Item" and e.U == uid then
			return true
		end
	end
	return false
end

-- ── visuals: carried things stacked above the head ──────────────────
local function entryHeight(entry)
	if entry.Kind == "Item" then
		return GameConfig.HoldBaseSize * (entry.Z or 1)
	end
	return GameConfig.CarryDisplaySize
end

local function buildVisual(entry)
	if entry.Kind == "Item" then
		local model = ModelFactory.Create(entry.Id)
		ModelFactory.FitToSize(model, entryHeight(entry))
		ModelFactory.Simplify(model, 0.06)
		ModelFactory.ApplyVariant(model, entry.V, false)
		ModelFactory.ApplyMutation(model, entry.M)
		return model
	end
	local model = ModelFactory.CreateBox(entry.Box)
	ModelFactory.FitToSize(model, ModelFactory.BoxStuds(entry.Box))
	return model
end

local function weldAll(model, anchor)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchor
			weld.Part1 = d
			weld.Parent = d
			d.Anchored = false
		end
	end
end

-- Everything you carry lives in ONE tool in your backpack/hotbar ("Rare Box  x3"). Equip it to hold
-- the top thing in your hand (at its real size).
local function lootTool(player)
	for _, holder in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		if holder then
			for _, t in ipairs(holder:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("LootTool") then
					return t
				end
			end
		end
	end
	return nil
end

local function entryName(entry)
	if entry.Kind == "Item" then
		return Formulas.ItemName({ Id = entry.Id, V = entry.V, Z = entry.Z, M = entry.M })
	end
	return Formulas.BoxName(entry.Box)
end

-- Big things are heavy: every carried box/object bigger than Normal slows you down a bit.
function CarryService.SpeedFactor(player)
	local c = carrying[player]
	local slow = 0
	for _, e in ipairs(c and c.Items or {}) do
		local z = e.Kind == "Box" and (e.Box.Z or 1) or (e.Z or 1)
		slow += math.max(0, z - 1) * GameConfig.CarrySlowPerSize
	end
	return math.max(GameConfig.CarrySlowMin, 1 - slow)
end

-- equip = put it in your hand right away (picking an object up in your base)
local function restack(player, c, equip)
	task.defer(function()
		if Svc.Monetization then
			Svc.Monetization.ApplyMovement(player) -- heavier load = slower
		end
	end)
	local tool = lootTool(player)
	if #c.Items == 0 then
		if tool then
			tool:Destroy()
		end
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not tool then
		if not backpack then
			return
		end
		tool = Instance.new("Tool")
		tool:SetAttribute("LootTool", true)
		tool.CanBeDropped = false
		tool.RequiresHandle = true
		tool.ToolTip = "What you're carrying: bring it to your plot!"
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = Vector3.new(0.6, 0.6, 0.6)
		handle.Transparency = 1
		handle.CanCollide = false
		handle.CanQuery = false
		handle.Massless = true
		handle.CFrame = CFrame.new()
		handle.Parent = tool
		tool.Parent = backpack
	end
	local top = c.Items[#c.Items]
	tool.Name = entryName(top) .. (#c.Items > 1 and ("  x" .. #c.Items) or "")
	-- the top thing, in front of your hand
	local key = top.Kind == "Item" and ("I" .. tostring(top.U)) or ("B" .. tostring(top.Box.R) .. tostring(top.Box.V) .. tostring(top.Box.Z) .. tostring(top.Box.T))
	if tool:GetAttribute("ShowKey") ~= key then
		local old = tool:FindFirstChild("Shown")
		if old then
			old:Destroy()
		end
		local ok, model = pcall(buildVisual, top)
		if ok and model then
			model.Name = "Shown"
			local handle = tool:FindFirstChild("Handle")
			local _, size = model:GetBoundingBox()
			model:PivotTo(handle.CFrame * CFrame.new(0, size.Y / 2 - 0.8, -(size.Z / 2 + 0.5)))
			weldAll(model, handle)
			model.Parent = tool
		elseif not ok then
			warn("[CarryService] can't show carried " .. tostring(top.Id or top.Kind) .. ": " .. tostring(model))
		end
		tool:SetAttribute("ShowKey", key)
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if equip and hum and tool.Parent ~= player.Character then
		hum:EquipTool(tool)
	end
end

local function clearVisuals(c, player)
	if player then
		local tool = lootTool(player)
		if tool then
			tool:Destroy()
		end
	end
	for _, entry in ipairs(c.Items) do
		if entry.Model then
			entry.Model:Destroy()
			entry.Model = nil
		end
	end
end

-- ── chaser NPCs ─────────────────────────────────────────────────────
-- chasers make sounds instead of talking
local function chaserSound(model, key, looped)
	local id = ChaserConfig.Sounds[key]
	local root = model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart)
	if not id or id == "" or not root then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = "Chaser" .. key
	sound.SoundId = id
	sound.Volume = ChaserConfig.Sounds.Volume or 0.8
	sound.Looped = looped == true
	sound.RollOffMaxDistance = 90
	sound.Parent = root
	sound:Play()
	if not looped then
		task.delay(4, function()
			sound:Destroy()
		end)
	end
	return sound
end

-- footsteps only while it's actually running
local function updateSteps(ch)
	local steps = ch.Root and ch.Root:FindFirstChild("ChaserFootsteps")
	if steps then
		local moving = (ch.Root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude > 3
		if steps.Playing ~= moving then
			steps.Playing = moving
		end
		steps.PlaybackSpeed = math.clamp(ch.Humanoid.WalkSpeed / 40, 0.9, 1.8)
	end
end

local function say(model, _text, _seconds)
	chaserSound(model, "Catch")
end

local function fallbackRig(cfg)
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Color = cfg.Shirt
	torso.Parent = model
	local legs = Instance.new("Part")
	legs.Name = "Legs"
	legs.Size = Vector3.new(2, 2, 1)
	legs.Color = cfg.Pants
	legs.CFrame = CFrame.new(0, -2, 0)
	legs.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Color = cfg.Skin
	head.CFrame = CFrame.new(0, 1.6, 0)
	head.Parent = model
	for _, p in ipairs({ torso, legs, head }) do
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
	end
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.RequiresNeck = false
	hum.HipHeight = 3
	hum.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildChaser(tier)
	local cfg = ChaserConfig.Get(tier)
	local folder = ServerStorage:FindFirstChild("Chasers")
	local custom = folder and folder:FindFirstChild("Tier" .. tier)
	local model
	local scripted = custom and custom:FindFirstChild("RunAndAttack", true) ~= nil
	if custom then
		model = custom:Clone()
		pcall(function()
			model:ScaleTo(model:GetScale() * (ChaserConfig.ModelScale or 1))
		end)
	else
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = cfg.Skin
		desc.LeftArmColor = cfg.Skin
		desc.RightArmColor = cfg.Skin
		desc.TorsoColor = cfg.Shirt
		desc.LeftLegColor = cfg.Pants
		desc.RightLegColor = cfg.Pants
		desc.HeightScale = cfg.Scale
		desc.WidthScale = cfg.Scale
		desc.DepthScale = cfg.Scale
		desc.HeadScale = cfg.Scale
		local ok, result = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
		model = ok and result or fallbackRig(cfg)
		local function attachProps(anchor, props)
			if not anchor then
				return
			end
			for _, prop in ipairs(props or {}) do
				local p = Instance.new("Part")
				p.Name = prop.Name
				p.Size = prop.Size * cfg.Scale
				p.Color = prop.Color
				p.Material = prop.Material or Enum.Material.SmoothPlastic
				p.CanCollide = false
				p.CanQuery = false
				p.Massless = true
				p.CFrame = anchor.CFrame * CFrame.new(prop.Offset * cfg.Scale)
				p.Parent = model
				local w = Instance.new("WeldConstraint")
				w.Part0 = anchor
				w.Part1 = p
				w.Parent = p
			end
		end
		attachProps(model:FindFirstChild("RightHand"), cfg.HandProps)
		local head = model:FindFirstChild("Head")
		if head then
			for _, prop in ipairs(cfg.HeadProps or {}) do
				local p = Instance.new("Part")
				p.Name = prop.Name
				p.Size = prop.Size * cfg.Scale
				p.Color = prop.Color
				p.Material = prop.Material or Enum.Material.SmoothPlastic
				p.CanCollide = false
				p.CanQuery = false
				p.Massless = true
				p.CFrame = head.CFrame * CFrame.new(prop.Offset * cfg.Scale)
				p.Parent = model
				local w = Instance.new("WeldConstraint")
				w.Part0 = head
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	model.Name = cfg.Name
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.Anchored = false
		elseif (d:IsA("LocalScript") or d:IsA("Script")) and not scripted then
			d:Destroy()
		end
	end
	if scripted then
		-- Your asset-pack chasers bring their own controller (RunAndAttack: running/attack poses +
		-- pathfinding). We steer it with its attributes: only the thief is chased, no damage
		-- (getting caught = dropping your boxes, handled here).
		model:SetAttribute("AttackDamage", 0)
		-- tiny attack range: inside it the controller stands still waiting for its attack cooldown,
		-- so a big range made chasers freeze next to you without ever catching you
		model:SetAttribute("AttackRange", 2)
		model:SetAttribute("AttackCooldown", 0.6)
		model:SetAttribute("DetectionRadius", 5)
		model:SetAttribute("LoseTargetRadius", 500)
		model:SetAttribute("HomeLeash", 1000)
		model:SetAttribute("ChaseSpeed", cfg.Speed)
		model:SetAttribute("ChaseEnabled", false)
		local override = Instance.new("ObjectValue")
		override.Name = "TargetOverride"
		override.Parent = model
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.WalkSpeed = cfg.Speed
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.MaxHealth = 1e9
	hum.Health = 1e9
	hum.BreakJointsOnDeath = false
	return model, hum, cfg
end


local function rageLevel(c, tier)
	local r = c.Rage[tier]
	if not r then
		return 0
	end
	-- cool down one level every RageCooldown seconds
	while r.Level > 0 and os.clock() >= r.CoolAt do
		r.Level -= 1
		r.CoolAt += ChaserConfig.RageCooldown
	end
	return r.Level
end

local function addRage(c, tier)
	local level = math.min(ChaserConfig.MaxRage, rageLevel(c, tier) + 1)
	c.Rage[tier] = { Level = level, CoolAt = os.clock() + ChaserConfig.RageCooldown }
	return level
end

local function despawnModel(model, line, delaySeconds)
	if line then
		say(model, line, 2)
	end
	task.delay(delaySeconds or (line and 2 or 0), function()
		if model then
			model:Destroy()
		end
	end)
end

-- pack chasers: tell their controller who to run after (nil = stand still) and how fast
local function steer(ch, target, speed)
	ch.Model:SetAttribute("ChaseSpeed", math.clamp(speed, 5, 120))
	if ch.Target then
		ch.Target.Value = target
	end
	ch.Model:SetAttribute("ChaseEnabled", target ~= nil)
end

-- an invisible "home" the controller can walk back to after a catch
local function homeMarker(ch)
	if ch.HomeMarker and ch.HomeMarker.Parent then
		return ch.HomeMarker
	end
	local marker = Instance.new("Model")
	marker.Name = "HomeMarker"
	local p = Instance.new("Part")
	p.Name = "HumanoidRootPart"
	p.Size = Vector3.new(1, 1, 1)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(ch.Home)
	p.Parent = marker
	local h = Instance.new("Humanoid")
	h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	h.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	h.Parent = marker
	marker.PrimaryPart = p
	marker.Parent = ch.Model
	ch.HomeMarker = marker
	return marker
end

local function despawnChaser(c, line)
	local ch = c.Chaser
	if not ch then
		return
	end
	c.Chaser = nil
	if not ch.Model.Parent then
		return
	end
	if ch.Scripted then
		steer(ch, nil, ch.Cfg.Speed)
	else
		ch.Humanoid:MoveTo(ch.Root.Position)
	end
	despawnModel(ch.Model, line)
end

-- After catching you the chaser walks back to where it came from, then vanishes.
local function sendHome(c, line)
	local ch = c.Chaser
	if not ch then
		return
	end
	c.Chaser = nil
	if not ch.Model.Parent then
		return
	end
	say(ch.Model, line, 2.5)
	ch.Humanoid.WalkSpeed = ch.Cfg.Speed * 0.6
	if ch.Scripted then
		steer(ch, homeMarker(ch), ch.Cfg.Speed * 0.6)
	end
	ch.ReturnUntil = os.clock() + ChaserConfig.DropLifetime + 2 -- stays around while your boxes are on the ground
	ch.Victim = c
	table.insert(returning, ch)
end

-- Makes `ch` (already in the world) chase `player` again with `rage` — the SAME person turns around.
local function setRage(player, ch, rage)
	ch.Rage = rage
	ch.Humanoid.WalkSpeed = ch.Cfg.Speed + rage * ChaserConfig.RageSpeed
	if ch.Track then
		pcall(function()
			ch.Track:AdjustSpeed(1 + rage * 0.15)
		end)
	end
	if rage > 0 then
		chaserSound(ch.Model, "Rage")
		local fire = ch.Root:FindFirstChild("RageFire") or Instance.new("Fire")
		fire.Name = "RageFire"
		fire.Size = 2 + rage
		fire.Heat = 0
		fire.Color = Color3.fromRGB(255, 60, 40)
		fire.Parent = ch.Root
	end
	Remotes.Event("ChaserFX"):FireClient(player, "Chase", { Name = ch.Cfg.Name, Emoji = ch.Cfg.Emoji, Rage = rage })
	Svc.Net.Notify(player, ch.Cfg.Name .. (rage > 0 and (" is ENRAGED (x" .. rage .. ")!") or " is chasing you!") .. " RUN HOME!", "error")
end

local function resumeChase(player, c, ch, rage)
	for i = #returning, 1, -1 do
		if returning[i] == ch then
			table.remove(returning, i)
		end
	end
	ch.Victim = nil
	c.Chaser = ch
	ch.StartAt = os.clock() + 0.2
	setRage(player, ch, rage)
end

-- the chaser of `tier` that is still walking home from catching this player (if any)
local function returningFor(c, tier)
	for _, ch in ipairs(returning) do
		if ch.Victim == c and ch.Tier == tier and ch.Model.Parent then
			return ch
		end
	end
	return nil
end

-- ── sleepers: each zone's owner dozes in its zone (your Sleeping_Character_Assets) ──────────
-- Grab a box → it WAKES UP and the chase starts from where it was sleeping. When nobody is being
-- chased by it any more (and it walked home), it goes back to sleep.
local sleepers = {} -- [tier] = { Model, Ground, Awake, IdleSince }
local speedSign -- defined with the sleepers below

local function setShown(model, shown)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if shown then
				local t = d:GetAttribute("_T")
				if t then
					d.Transparency = t
				end
			else
				if d:GetAttribute("_T") == nil then
					d:SetAttribute("_T", d.Transparency)
				end
				d.Transparency = 1
			end
		end
	end
end

local function wakeSleeper(tier)
	local sl = sleepers[tier]
	if not sl or sl.Awake or not sl.Model.Parent then
		return
	end
	sl.Awake = true
	sl.IdleSince = nil
	sl.Model:SetAttribute("Sleeping", false) -- stops the snoring / Zzz
	setShown(sl.Model, false) -- the running chaser takes its place
end

local function sleepAgain(tier)
	local sl = sleepers[tier]
	if not sl or not sl.Awake then
		return
	end
	sl.Awake = false
	setShown(sl.Model, true)
	sl.Model:SetAttribute("Sleeping", true)
end

local function spawnChaser(player, c, tier, fromPos, rage)
	local ok, model, hum, cfg = pcall(buildChaser, tier)
	if not ok then
		warn("[CarryService] chaser failed: " .. tostring(model))
		return
	end
	rage = rage or rageLevel(c, tier)
	hum.WalkSpeed = cfg.Speed + rage * ChaserConfig.RageSpeed
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	local target = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local spawnPos = Svc.Map.ClampToZone(tier, fromPos + Vector3.new(0, 0, ChaserConfig.SpawnBehind))
	if sleepers[tier] then
		spawnPos = sleepers[tier].Ground -- it wakes up and runs from its bed
		wakeSleeper(tier)
	end
	local _, size = model:GetBoundingBox()
	spawnPos += Vector3.new(0, size.Y / 2, 0)
	local lookAt = target and Vector3.new(target.Position.X, spawnPos.Y, target.Position.Z) or (spawnPos - Vector3.new(0, 0, 1))
	model:PivotTo(CFrame.lookAt(spawnPos, lookAt))
	model:SetAttribute("HomePosition", spawnPos)
	model.Parent = Svc.Map.ChaserFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	pcall(function()
		if model:FindFirstChild("TargetOverride") then
			return -- pack chasers animate themselves (RunAndAttack)
		end
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local anim = Instance.new("Animation")
		anim.AnimationId = ChaserConfig.RunAnimation
		local track = animator:LoadAnimation(anim)
		track.Looped = true
		track:Play(0.1, 1, 1 + rage * 0.15)
		TRACKS[model] = track
	end)
	chaserSound(model, "Footsteps", true)
	-- make the chaser easy to spot: red outline (seen through walls), red glow, bobbing "!" tag
	local outline = Instance.new("Highlight")
	outline.Name = "ChaserOutline"
	outline.FillColor = Color3.fromRGB(255, 40, 40)
	outline.FillTransparency = 0.82
	outline.OutlineColor = Color3.fromRGB(255, 60, 60)
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Parent = model
	local glow = Instance.new("PointLight")
	glow.Name = "ChaserGlow"
	glow.Color = Color3.fromRGB(255, 60, 50)
	glow.Brightness = 3
	glow.Range = 18
	glow.Parent = root
	local tag = Instance.new("BillboardGui")
	tag.Name = "ChaserTag"
	tag.Size = UDim2.fromOffset(140, 56)
	tag.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 2.5, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 250
	tag.LightInfluence = 0
	tag.Parent = root
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromScale(1, 0.62)
	mark.Font = Enum.Font.FredokaOne
	mark.TextScaled = true
	mark.Text = "!"
	mark.TextColor3 = Color3.fromRGB(255, 70, 60)
	mark.Parent = tag
	local markStroke = Instance.new("UIStroke")
	markStroke.Thickness = 3
	markStroke.Parent = mark
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromScale(0, 0.62)
	nameLabel.Size = UDim2.fromScale(1, 0.38)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.Text = cfg.Name
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.Parent = tag
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 2
	nameStroke.Parent = nameLabel
	if rage > 0 then
		chaserSound(model, "Rage")
		local fire = Instance.new("Fire")
		fire.Size = 2 + rage
		fire.Heat = 0
		fire.Color = Color3.fromRGB(255, 60, 40)
		fire.Parent = root
	else
		chaserSound(model, "Wake")
	end
	c.Chaser = { Model = model, Humanoid = hum, Root = root, Tier = tier, Cfg = cfg, Home = spawnPos, Rage = rage, Track = TRACKS[model], Scripted = model:FindFirstChild("TargetOverride") ~= nil, Target = model:FindFirstChild("TargetOverride"), StartAt = os.clock() + (rage > 0 and 0.2 or ChaserConfig.HeadStart) }
	TRACKS[model] = nil
	Remotes.Event("ChaserFX"):FireClient(player, "Chase", { Name = cfg.Name, Emoji = cfg.Emoji, Rage = rage })
	Svc.Net.Notify(player, cfg.Name .. (rage > 0 and (" is ENRAGED (x" .. rage .. ")!") or " is chasing you!") .. " RUN HOME!", "error")
end

local function chaseIfNeeded(player, c, tier, fromPos, forceRage)
	if not tier then
		return
	end
	if forceRage and c.Chaser and c.Chaser.Tier == tier then
		setRage(player, c.Chaser, rageLevel(c, tier)) -- same person, just angrier
		return
	end
	-- the one who caught you is still walking home → it turns around and comes back for you
	if not c.Chaser or c.Chaser.Tier < tier then
		local back = returningFor(c, tier)
		if back then
			if c.Chaser then
				despawnChaser(c, nil)
			end
			resumeChase(player, c, back, rageLevel(c, tier))
			return
		end
	end
	if not c.Chaser or c.Chaser.Tier < tier then
		if c.Chaser then
			despawnChaser(c, nil)
		end
		spawnChaser(player, c, tier, fromPos)
	end
end

-- ── dropped boxes (after being caught / dying / dropping) ────────────
local function dropBoxOnGround(box, position, droppedBy)
	local model = ModelFactory.CreateBox(box)
	ModelFactory.FitToSize(model, ModelFactory.BoxStuds(box))
	ModelFactory.PlaceOnGround(model, position, math.random() * math.pi * 2)
	ModelFactory.SetCollision(model, false)
	model.Name = "DroppedBox"
	model:SetAttribute("Dropped", true)
	local zoneTier = box.T
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = Formulas.BoxName(box)
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = model.PrimaryPart
	local taken = false
	prompt.Triggered:Connect(function(player)
		if taken or not Svc.Data.Get(player) then
			return
		end
		if CarryService.Count(player) >= CarryService.Capacity(player) then
			Svc.Net.Notify(player, "Your hands are full!", "error")
			return
		end
		taken = true
		model:Destroy()
		local c = getState(player)
		table.insert(c.Items, { Kind = "Box", Box = box })
		restack(player, c)
		Svc.Net.Sound("Grab", player)
		-- the chaser of that zone gets angrier every time you snatch a box back
		local where = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local tier = where and Svc.Map.GetAreaAt(where.Position) or nil
		if tier and zoneTier then
			addRage(c, zoneTier)
			chaseIfNeeded(player, c, zoneTier, where.Position, true)
		end
		Svc.Data.MarkDirty(player)
	end)
	model.Parent = Svc.Map.LiveObjects
	local _ = droppedBy
	task.delay(ChaserConfig.DropLifetime, function()
		if not taken and model.Parent then
			taken = true
			model:Destroy()
		end
	end)
	return model
end

-- ── public API ──────────────────────────────────────────────────────
-- A shrunk box goes on top of your stack. box = { R, T, V }; fromPos = where it was.
function CarryService.Add(player, box, fromPos)
	local c = getState(player)
	table.insert(c.Items, { Kind = "Box", Box = box })
	restack(player, c)
	chaseIfNeeded(player, c, Svc.Map.GetAreaAt(fromPos) or box.T, fromPos)
	Svc.Data.MarkDirty(player)
end

-- Holds an owned object above your head at its real size. item = the data.Items entry.
function CarryService.Hold(player, item)
	local c = getState(player)
	if #c.Items >= CarryService.Capacity(player) then
		return false
	end
	table.insert(c.Items, { Kind = "Item", U = item.U, Id = item.Id, V = item.V, Z = item.Z, M = item.M })
	restack(player, c, true) -- straight into your hand
	Svc.Data.MarkDirty(player)
	return true
end

-- Removes and returns the top entry ({ Kind = "Box", Box } | { Kind = "Item", U, ... }) or nil.
function CarryService.TakeTop(player)
	local c = carrying[player]
	if not c or #c.Items == 0 then
		return nil
	end
	local entry = table.remove(c.Items)
	if entry.Model then
		entry.Model:Destroy()
		entry.Model = nil
	end
	restack(player, c)
	if CarryService.CountBoxes(player) == 0 then
		despawnChaser(c, nil)
	end
	Svc.Data.MarkDirty(player)
	return entry
end

-- Removes the top-most BOX you carry (Lab turn-in). Returns the box table or nil.
function CarryService.TakeTopBox(player)
	local c = carrying[player]
	if not c then
		return nil
	end
	for i = #c.Items, 1, -1 do
		local e = c.Items[i]
		if e.Kind == "Box" then
			table.remove(c.Items, i)
			restack(player, c)
			if CarryService.CountBoxes(player) == 0 then
				despawnChaser(c, nil)
			end
			Svc.Data.MarkDirty(player)
			return e.Box
		end
	end
	return nil
end

-- Stops holding `uid` (it was sold / fused / stolen).
function CarryService.ForgetItem(player, uid)
	local c = carrying[player]
	if not c then
		return
	end
	for i = #c.Items, 1, -1 do
		local e = c.Items[i]
		if e.Kind == "Item" and e.U == uid then
			if e.Model then
				e.Model:Destroy()
			end
			table.remove(c.Items, i)
		end
	end
	restack(player, c)
end

-- reason: "caught" | "died" | "dropped" | "left" | "rebirth"
function CarryService.DropAll(player, reason)
	local c = carrying[player]
	if not c then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local where = root and root.Position
	local boxes = {}
	for _, e in ipairs(c.Items) do
		if e.Kind == "Box" then
			table.insert(boxes, e.Box)
		end
	end
	clearVisuals(c, player)
	c.Items = {} -- held objects simply go back to your pocket (they're still yours)
	local onGround = where and (reason == "caught" or reason == "died" or reason == "dropped") and not Svc.Map.IsInBase(where)
	if onGround then
		for i, box in ipairs(boxes) do
			local a = i / math.max(1, #boxes) * math.pi * 2
			dropBoxOnGround(box, Vector3.new(where.X + math.cos(a) * 4, where.Y - 3, where.Z + math.sin(a) * 4), player)
		end
	end
	local ch = c.Chaser
	if reason == "caught" and ch then
		sendHome(c, ch.Cfg.CaughtLine)
		Remotes.Event("CarryFX"):FireClient(player, "Caught", { By = ch.Cfg.Name, Emoji = ch.Cfg.Emoji, Count = #boxes })
		Svc.Net.Sound("Caught", player)
		Svc.Net.Notify(player, ch.Cfg.Name .. " got you! Your boxes are on the ground — grab them back quick! (it'll make them MAD )", "error")
	else
		despawnChaser(c, nil)
		if reason == "died" and #boxes > 0 then
			Svc.Net.Notify(player, "You dropped what you were carrying!", "error")
		end
	end
	if player.Parent then
		Svc.Data.MarkDirty(player)
	end
end

-- PvP: takes the top thing `victim` carries. Returns the entry (Box or Item) or nil.
function CarryService.StealTop(victim)
	local c = carrying[victim]
	if not c or #c.Items == 0 then
		return nil
	end
	local entry = table.remove(c.Items)
	if entry.Model then
		entry.Model:Destroy()
		entry.Model = nil
	end
	restack(victim, c)
	if CarryService.CountBoxes(victim) == 0 then
		despawnChaser(c, nil)
	end
	Svc.Data.MarkDirty(victim)
	return entry
end

-- Gives a stolen box to `thief` (or drops it at their feet when their hands are full).
function CarryService.GiveBox(player, box)
	local c = getState(player)
	if #c.Items >= CarryService.Capacity(player) then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			dropBoxOnGround(box, root.Position - Vector3.new(0, 3, 0) + root.CFrame.LookVector * 4, player)
		end
		return false
	end
	table.insert(c.Items, { Kind = "Box", Box = box })
	restack(player, c)
	Svc.Data.MarkDirty(player)
	return true
end

function CarryService.OnPlayerLoaded(player)
	local function hook(character)
		local hum = character:WaitForChild("Humanoid", 10)
		if hum then
			hum.Died:Connect(function()
				CarryService.DropAll(player, "died")
			end)
		end
	end
	player.CharacterAdded:Connect(function(character)
		local c = carrying[player]
		if c then
			clearVisuals(c, player)
			c.Items = {}
			despawnChaser(c, nil)
		end
		hook(character)
	end)
	if player.Character then
		task.spawn(hook, player.Character)
	end
end

function CarryService.OnPlayerRemoving(player)
	CarryService.DropAll(player, "left")
	carrying[player] = nil
end

-- Little orange sign next to each sleeper: how fast you should be to outrun it.
speedSign = function(tier, ground, side)
	local cfg = ChaserConfig.Get(tier)
	local speed = math.ceil(cfg.Speed * (ChaserConfig.RecommendedSpeedMargin or 1.1))
	local sign = Instance.new("Model")
	sign.Name = "SpeedSign"
	local wood = Color3.fromRGB(235, 140, 40)
	local function block(name, size, cf)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Color = wood
		p.Material = Enum.Material.Plastic
		p.TopSurface = Enum.SurfaceType.Studs
		p.Parent = sign
		return p
	end
	-- a few studs toward the zone entrance from the sleeper, facing the middle of the zone
	local base = CFrame.new(ground + Vector3.new(-side * 7, 0, -9)) * CFrame.Angles(0, side < 0 and -math.pi / 2 or math.pi / 2, 0)
	block("Post", Vector3.new(0.8, 3, 0.8), base * CFrame.new(0, 1.5, 0))
	local board = block("Board", Vector3.new(5.5, 2.4, 0.6), base * CFrame.new(0, 3.9, 0))
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(0.92, 0.86)
		label.Position = UDim2.fromScale(0.04, 0.07)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(230, 30, 30)
		label.Text = speed .. " speed\nrecommended"
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Parent = label
	end
	sign.Parent = Svc.Map.ChaserFolder
end

-- A sleeping copy of each zone's owner so you can see who you're about to rob.
local function spawnSleepers()
	local folder = ServerStorage:FindFirstChild("SleepingChasers")
	for tier, area in pairs(Svc.Map.Areas) do
		local f = area.Floor
		local side = (tier % 2 == 0) and 1 or -1
		local ground = Vector3.new(side * (f.Size.X / 2 - 40), f.Position.Y + f.Size.Y / 2, f.Position.Z)
		local template = folder and folder:FindFirstChild("Tier" .. tier)
		if template then
			-- your sleeping character (breathing, nodding, snoring); standing on the ground, facing the middle
			local model = template:Clone()
			pcall(function()
				model:ScaleTo(model:GetScale() * (ChaserConfig.ModelScale or 1))
			end)
			model.Name = ChaserConfig.Get(tier).Name .. " (asleep)"
			model:SetAttribute("Sleeping", true)
			local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanQuery = false
				end
			end
			if root then
				root.Anchored = true -- held in place until its sleep controller takes over
			end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
			model:PivotTo(CFrame.new(ground) * CFrame.Angles(0, side < 0 and -math.pi / 2 or math.pi / 2, 0))
			local cf, size = model:GetBoundingBox()
			model:PivotTo(model:GetPivot() + Vector3.new(0, ground.Y - (cf.Position.Y - size.Y / 2), 0))
			model.Parent = Svc.Map.ChaserFolder
			sleepers[tier] = { Model = model, Ground = ground, Awake = false }
			speedSign(tier, ground, side)
		else
			local ok, model = pcall(buildChaser, tier)
			if ok and model then
				local pos = Vector3.new(ground.X, 0, ground.Z)
				local _, size = model:GetBoundingBox()
				model.Name = model.Name .. " (asleep)"
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("Script") then
						d:Destroy() -- sleepers don't run their controller
					elseif d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
					end
				end
				-- lying on its back, head toward the corridor center
				model:PivotTo(CFrame.new(pos + Vector3.new(0, size.Z / 2 + 0.3, 0)) * CFrame.Angles(math.rad(-90), math.rad(side * 90), 0))
				model.Parent = Svc.Map.ChaserFolder
			end
		end
	end
end


function CarryService.Start()
	task.spawn(spawnSleepers)
	Svc.Net.Handle("DropCarry", function(player)
		if not CarryService.IsCarrying(player) then
			return { ok = false }
		end
		CarryService.DropAll(player, "dropped")
		return { ok = true, msg = "Dropped what you were carrying." }
	end)

	Svc.Data.AddSyncProvider(function(player, payload)
		local c = carrying[player]
		local plot = Svc.Museum.GetPlot(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local top = c and c.Items[#c.Items]
		payload.Carry = {
			AtPlot = (root and plot and plot.Floor and Svc.Map.IsInPart(plot.Floor, root.Position)) or false,
			Count = c and #c.Items or 0,
			Boxes = CarryService.CountBoxes(player),
			Capacity = CarryService.Capacity(player),
			TopKind = top and top.Kind or nil,
			Chaser = c and c.Chaser and (c.Chaser.Cfg.Name) or nil,
			Rage = c and c.Chaser and c.Chaser.Rage or 0,
		}
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			for player, c in pairs(carrying) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local hum = character and character:FindFirstChildOfClass("Humanoid")
				local alive = root and hum and hum.Health > 0
				if #c.Items > 0 and root then
					local plot = Svc.Museum.GetPlot(player)
					local atPlot = plot ~= nil and plot.Floor ~= nil and Svc.Map.IsInPart(plot.Floor, root.Position)
					if atPlot ~= c.AtPlot then
						c.AtPlot = atPlot
						Svc.Data.MarkDirty(player)
					end
				end
				if c.Chaser then
					local ch = c.Chaser
					updateSteps(ch)
					if not ch.Model.Parent or not alive or CarryService.CountBoxes(player) == 0 then
						despawnChaser(c, nil)
					elseif Svc.Map.IsInBase(root.Position) then
						sendHome(c, "Hmph! Safe zone... I'll get you next time!")
					elseif os.clock() < ch.StartAt then
						if ch.Scripted then
							steer(ch, nil, ch.Cfg.Speed)
						else
							ch.Humanoid:MoveTo(ch.Root.Position)
						end
					else
						-- catch-up sprint when you've pulled away
						local base = ch.Cfg.Speed + (ch.Rage or 0) * ChaserConfig.RageSpeed
						local far = (ch.Root.Position - root.Position).Magnitude > ChaserConfig.SprintDistance
						local speed = far and base * ChaserConfig.SprintMult or base
						if ch.Scripted then
							steer(ch, character, speed) -- its own pathfinding + run/attack animation
						else
							-- aim a little ahead of where you're running
							local lead = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * 0.35
							ch.Humanoid:MoveTo(root.Position + lead)
							ch.Humanoid.WalkSpeed = speed
							if ChaserConfig.ChaseJump and ch.Root.AssemblyLinearVelocity.Magnitude < 2 then
								ch.Humanoid.Jump = true
							end
						end
						-- caught = close on the ground plane (big chasers stand taller, so a 3D distance
						-- check used to miss even when they were touching you)
						local reach = ChaserConfig.CatchDistance * math.max(1, ch.Cfg.Scale) * (1 + ((ChaserConfig.ModelScale or 1) - 1) * 0.5)
						local flat = (ch.Root.Position - root.Position) * Vector3.new(1, 0, 1)
						if flat.Magnitude <= reach and math.abs(ch.Root.Position.Y - root.Position.Y) < 12 and not player:GetAttribute("AdminGod") then
							CarryService.DropAll(player, "caught")
						else
							-- stuck watchdog: not getting anywhere for a while → nudge, then hop behind you
							local now = os.clock()
							if not ch.LastProgressAt or (ch.LastPos and (ch.Root.Position - ch.LastPos).Magnitude > 4) then
								ch.LastProgressAt = now
								ch.LastPos = ch.Root.Position
							elseif now - ch.LastProgressAt > 1.5 then
								ch.Humanoid.Jump = true
								ch.Humanoid:MoveTo(root.Position)
								if now - ch.LastProgressAt > 3.5 then
									local back = root.Position - (root.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit * 28
									local _, size = ch.Model:GetBoundingBox()
									ch.Model:PivotTo(CFrame.lookAt(back + Vector3.new(0, size.Y / 2, 0), Vector3.new(root.Position.X, back.Y + size.Y / 2, root.Position.Z)))
									ch.LastProgressAt = now
									ch.LastPos = ch.Root.Position
								end
							end
						end
					end
				end
			end
			-- sleepers whose chasers are all gone go back to sleep
			for tier, sl in pairs(sleepers) do
				if sl.Awake then
					local busy = false
					for _, other in pairs(carrying) do
						if other.Chaser and other.Chaser.Tier == tier then
							busy = true
						end
					end
					for _, ch in ipairs(returning) do
						if ch.Tier == tier and ch.Model.Parent then
							busy = true
						end
					end
					if busy then
						sl.IdleSince = nil
					elseif not sl.IdleSince then
						sl.IdleSince = os.clock()
					elseif os.clock() - sl.IdleSince > 1.5 then
						sleepAgain(tier)
					end
				end
			end
			-- chasers walking home after a catch
			for i = #returning, 1, -1 do
				local ch = returning[i]
				updateSteps(ch)
				if not ch.Model.Parent then
					table.remove(returning, i)
				elseif os.clock() >= ch.ReturnUntil then
					table.remove(returning, i)
					despawnModel(ch.Model, nil, 0)
				elseif (ch.Root.Position - ch.Home).Magnitude < 6 then
					-- waits at home, watching its boxes
					if ch.Scripted then
						steer(ch, nil, ch.Cfg.Speed)
					else
						ch.Humanoid:MoveTo(ch.Root.Position)
					end
				elseif not ch.Scripted then
					ch.Humanoid:MoveTo(ch.Home)
				end
			end
		end
	end)
end

return CarryService
