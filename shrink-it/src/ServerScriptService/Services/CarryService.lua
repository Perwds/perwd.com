--[[
	📍 LOCATION: ServerScriptService > Services > CarryService (ModuleScript)

	Everything you carry (the top thing in your HANDS, the rest on your back):
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
local ChaserModels = require(ServerScriptService.Services.ChaserModels)

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
		return model
	end
	local model = ModelFactory.CreateBox(entry.Box)
	ModelFactory.FitToSize(model, ModelFactory.BoxStuds(entry.Box))
	return model
end

local HOLD_ANIM = "rbxassetid://507768375" -- default R15 "holding a tool" pose (arm out)

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

local function setHoldPose(player, c, on)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if on and hum and not (c.HoldTrack and c.HoldTrack.IsPlaying) then
		pcall(function()
			local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
			local anim = Instance.new("Animation")
			anim.AnimationId = HOLD_ANIM
			c.HoldTrack = animator:LoadAnimation(anim)
			c.HoldTrack.Priority = Enum.AnimationPriority.Action
			c.HoldTrack.Looped = true
			c.HoldTrack:Play(0.15)
		end)
	elseif not on and c.HoldTrack then
		pcall(function()
			c.HoldTrack:Stop(0.2)
		end)
		c.HoldTrack = nil
	end
end

-- The top thing is held in your HANDS in front of you (at its real size); the rest ride on your back.
local function restack(player, c)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local back = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) or root
	local y = 0
	for i, entry in ipairs(c.Items) do
		if entry.Model then
			entry.Model:Destroy()
			entry.Model = nil
		end
		local okBuild, built = false, nil
		if root then
			okBuild, built = pcall(buildVisual, entry)
			if not okBuild then
				warn("[CarryService] can't show carried " .. tostring(entry.Id or entry.Kind) .. ": " .. tostring(built))
			end
		end
		if okBuild and built then
			local model = built
			model.Name = "Carried"
			if i == #c.Items then
				-- in your hands: bottom at waist height, just in front of your chest
				local _, size = model:GetBoundingBox()
				model:PivotTo(root.CFrame * CFrame.new(0, -0.6 + size.Y / 2, -(size.Z / 2 + 1.4)))
				weldAll(model, root)
			else
				-- small copies stacked on your back like a backpack
				local _, size0 = model:GetBoundingBox()
				local scale = math.min(1, 1.8 / math.max(size0.X, size0.Y, size0.Z))
				pcall(function()
					model:ScaleTo(model:GetScale() * scale)
				end)
				local _, size = model:GetBoundingBox()
				model:PivotTo(back.CFrame * CFrame.new(0, -0.4 + y + size.Y / 2, 0.6 + size.Z / 2))
				y += size.Y + 0.1
				weldAll(model, back)
			end
			model.Parent = character
			entry.Model = model
		end
	end
	setHoldPose(player, c, #c.Items > 0)
end

local function clearVisuals(c)
	if c.HoldTrack then
		pcall(function()
			c.HoldTrack:Stop(0.2)
		end)
		c.HoldTrack = nil
	end
	for _, entry in ipairs(c.Items) do
		if entry.Model then
			entry.Model:Destroy()
			entry.Model = nil
		end
	end
end

-- ── chaser NPCs ─────────────────────────────────────────────────────
local function billboard(model, name, text, color, offset)
	local head = model:FindFirstChild("Head") or model.PrimaryPart
	if not head then
		return nil
	end
	local old = head:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(text and #text > 20 and 360 or 220, 50)
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	return gui
end

local function say(model, text, seconds)
	local gui = billboard(model, "Bubble", text, Color3.fromRGB(255, 255, 255), 5.5)
	if gui and seconds then
		task.delay(seconds, function()
			if gui.Parent then
				gui:Destroy()
			end
		end)
	end
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
	if custom then
		model = custom:Clone()
	elseif ChaserModels.Has(cfg.Animal) then
		model = ChaserModels.Build(cfg.Animal, cfg.Scale)
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
		elseif d:IsA("LocalScript") or d:IsA("Script") then
			d:Destroy()
		end
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

local function despawnChaser(c, line)
	local ch = c.Chaser
	if not ch then
		return
	end
	c.Chaser = nil
	if not ch.Model.Parent then
		return
	end
	ch.Humanoid:MoveTo(ch.Root.Position)
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
		say(ch.Model, string.rep("😡", rage) .. " GIVE THAT BACK!!", 3)
		billboard(ch.Model, "Rage", string.rep("💢", rage), Color3.fromRGB(255, 60, 60), 7.5)
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
	local _, size = model:GetBoundingBox()
	spawnPos += Vector3.new(0, size.Y / 2, 0)
	local lookAt = target and Vector3.new(target.Position.X, spawnPos.Y, target.Position.Z) or (spawnPos - Vector3.new(0, 0, 1))
	model:PivotTo(CFrame.lookAt(spawnPos, lookAt))
	model.Parent = Svc.Map.ChaserFolder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	pcall(function()
		if model:GetAttribute("Animal") then
			return -- animals swing their legs on the client (Effects)
		end
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local anim = Instance.new("Animation")
		anim.AnimationId = ChaserConfig.RunAnimation
		local track = animator:LoadAnimation(anim)
		track.Looped = true
		track:Play(0.1, 1, 1 + rage * 0.15)
		TRACKS[model] = track
	end)
	if rage > 0 then
		say(model, string.rep("😡", rage) .. " GIVE THAT BACK!!", 3)
		billboard(model, "Rage", string.rep("💢", rage), Color3.fromRGB(255, 60, 60), 7.5)
		local fire = Instance.new("Fire")
		fire.Size = 2 + rage
		fire.Heat = 0
		fire.Color = Color3.fromRGB(255, 60, 40)
		fire.Parent = root
	else
		say(model, "❗ " .. cfg.Shout, 3)
	end
	c.Chaser = { Model = model, Humanoid = hum, Root = root, Tier = tier, Cfg = cfg, Home = spawnPos, Rage = rage, Track = TRACKS[model], StartAt = os.clock() + (rage > 0 and 0.2 or ChaserConfig.HeadStart) }
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
	table.insert(c.Items, { Kind = "Item", U = item.U, Id = item.Id, V = item.V, Z = item.Z })
	restack(player, c)
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
	clearVisuals(c)
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
			clearVisuals(c)
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

-- A sleeping copy of each zone's owner (💤) so you can see who you're about to rob.
local function spawnSleepers()
	for tier, area in pairs(Svc.Map.Areas) do
		local ok, model = pcall(buildChaser, tier)
		if ok and model then
			local f = area.Floor
			local side = (tier % 2 == 0) and 1 or -1
			local pos = Vector3.new(side * (f.Size.X / 2 - 40), 0, f.Position.Z)
			local _, size = model:GetBoundingBox()
			model.Name = model.Name .. " (asleep)"
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			if model:GetAttribute("Animal") then
				-- animals nap standing on the ground, facing the corridor
				local rootPart = model.PrimaryPart
				local up = rootPart and rootPart.Position.Y or size.Y / 2
				model:PivotTo(CFrame.new(pos + Vector3.new(0, up, 0)) * CFrame.Angles(0, math.rad(-side * 90), 0))
			else
				-- lying on its back, head toward the corridor center
				model:PivotTo(CFrame.new(pos + Vector3.new(0, size.Z / 2 + 0.3, 0)) * CFrame.Angles(math.rad(-90), math.rad(side * 90), 0))
			end
			model.Parent = Svc.Map.ChaserFolder
			say(model, "💤", nil)
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
					if not ch.Model.Parent or not alive or CarryService.CountBoxes(player) == 0 then
						despawnChaser(c, nil)
					elseif Svc.Map.IsInBase(root.Position) then
						sendHome(c, "Hmph! Safe zone... I'll get you next time!")
					elseif os.clock() < ch.StartAt then
						ch.Humanoid:MoveTo(ch.Root.Position)
					else
						-- aim a little ahead of where you're running
						local lead = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1) * 0.35
						ch.Humanoid:MoveTo(root.Position + lead)
						-- catch-up sprint when you've pulled away
						local base = ch.Cfg.Speed + (ch.Rage or 0) * ChaserConfig.RageSpeed
						local far = (ch.Root.Position - root.Position).Magnitude > ChaserConfig.SprintDistance
						ch.Humanoid.WalkSpeed = far and base * ChaserConfig.SprintMult or base
						if ChaserConfig.ChaseJump and ch.Root.AssemblyLinearVelocity.Magnitude < 2 then
							ch.Humanoid.Jump = true
						end
						local reach = ChaserConfig.CatchDistance * math.max(1, ch.Cfg.Scale)
						if (ch.Root.Position - root.Position).Magnitude <= reach then
							CarryService.DropAll(player, "caught")
						end
					end
				end
			end
			-- chasers walking home after a catch
			for i = #returning, 1, -1 do
				local ch = returning[i]
				if not ch.Model.Parent then
					table.remove(returning, i)
				elseif os.clock() >= ch.ReturnUntil then
					table.remove(returning, i)
					despawnModel(ch.Model, nil, 0)
				elseif (ch.Root.Position - ch.Home).Magnitude < 6 then
					ch.Humanoid:MoveTo(ch.Root.Position) -- waits at home, watching its boxes
				else
					ch.Humanoid:MoveTo(ch.Home)
				end
			end
		end
	end)
end

return CarryService
