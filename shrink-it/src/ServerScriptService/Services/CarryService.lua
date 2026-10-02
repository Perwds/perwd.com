--[[
	📍 LOCATION: ServerScriptService > Services > CarryService (ModuleScript)

	The core loop:
	  1. Shrink an object → it's stacked above your head (you're CARRYING it).
	  2. The zone's chaser (Grandpa Joe, the Angry Neighbor, Officer Doug, ...) comes running after you.
	  3. Run back into the SAFE ZONE (your base) → everything you carry goes into your museum
	     and starts earning coins every second.
	  4. Get caught (or die) → you drop everything you were carrying.

	Carry capacity = the "Carry Capacity" upgrade (x3 with the Multi-Shrink gamepass).
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
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local ModelFactory = require(ServerScriptService.Services.ModelFactory)

local CarryService = {}
local Svc

local carrying = {} -- [player] = { Items = { { Id, V, Model } }, Chaser = record? }

function CarryService.Init(registry)
	Svc = registry
end

local function getState(player)
	local c = carrying[player]
	if not c then
		c = { Items = {}, Chaser = nil }
		carrying[player] = c
	end
	return c
end

function CarryService.Count(player)
	local c = carrying[player]
	return c and #c.Items or 0
end

function CarryService.Capacity(player)
	local stats = Svc.Shrink.GetStats(player)
	return stats and stats.Carry or 1
end

function CarryService.IsCarrying(player)
	return CarryService.Count(player) > 0
end

-- ── visuals: carried objects stacked above the head ─────────────────
local function attachVisual(player, item, index)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local model = ModelFactory.Create(item.Id)
	model.Name = "Carried"
	ModelFactory.FitToSize(model, GameConfig.CarryDisplaySize)
	ModelFactory.ApplyVariant(model, item.V, false)
	local step = GameConfig.CarryDisplaySize + 0.4
	model:PivotTo(head.CFrame * CFrame.new(0, 1.4 + step / 2 + (index - 1) * step, 0))
	model.Parent = character
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = d
			weld.Parent = d
			d.Anchored = false
		end
	end
	item.Model = model
end

local function clearVisuals(c)
	for _, item in ipairs(c.Items) do
		if item.Model then
			item.Model:Destroy()
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
	billboard(model, "NameTag", cfg.Emoji .. " " .. cfg.Name, Color3.fromRGB(255, 120, 120), 3.5)
	return model, hum, cfg
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
	if line then
		say(ch.Model, line, 2)
	end
	task.delay(line and 2 or 0, function()
		if ch.Model then
			ch.Model:Destroy()
		end
	end)
end

local function spawnChaser(player, c, tier, fromPos)
	local ok, model, hum, cfg = pcall(buildChaser, tier)
	if not ok then
		warn("[CarryService] chaser failed: " .. tostring(model))
		return
	end
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
	-- run animation (Roblox default R15 run)
	pcall(function()
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local anim = Instance.new("Animation")
		anim.AnimationId = ChaserConfig.RunAnimation
		local track = animator:LoadAnimation(anim)
		track.Looped = true
		track:Play()
	end)
	say(model, "❗ " .. cfg.Shout, 3)
	c.Chaser = { Model = model, Humanoid = hum, Root = root, Tier = tier, Cfg = cfg, StartAt = os.clock() + ChaserConfig.HeadStart }
	Svc.Net.Notify(player, cfg.Emoji .. " " .. cfg.Name .. " is chasing you! RUN BACK TO BASE! 🏃", "error")
end

-- ── public API ──────────────────────────────────────────────────────
-- Called right after a successful shrink. fromPos = where the object was.
function CarryService.Add(player, id, variant, fromPos)
	local c = getState(player)
	local item = { Id = id, V = variant }
	table.insert(c.Items, item)
	attachVisual(player, item, #c.Items)
	local tier = Svc.Map.GetAreaAt(fromPos)
	if tier and (not c.Chaser or c.Chaser.Tier < tier) then
		if c.Chaser then
			despawnChaser(c, nil)
		end
		spawnChaser(player, c, tier, fromPos)
	end
	Svc.Data.MarkDirty(player)
end

function CarryService.Deposit(player)
	local c = carrying[player]
	if not c or #c.Items == 0 then
		return
	end
	local mult = Svc.Economy.GetIncomeMultiplier(player)
	local income = 0
	local count = #c.Items
	for _, item in ipairs(c.Items) do
		Svc.Museum.AddItem(player, item.Id, item.V)
		income += Formulas.ItemBaseIncome(item) * mult
	end
	clearVisuals(c)
	c.Items = {}
	despawnChaser(c, "Darn! They got away...")
	Remotes.Event("CarryFX"):FireClient(player, "Deposit", { Count = count, Income = income })
	Svc.Net.Notify(player, string.format("🏛️ Delivered %d object%s! +%s/s", count, count == 1 and "" or "s", Format.Coins(income)), "success")
	Svc.Data.MarkDirty(player)
end

-- reason: "caught" | "died" | "left" | "rebirth"
function CarryService.DropAll(player, reason)
	local c = carrying[player]
	if not c then
		return
	end
	local count = #c.Items
	local ch = c.Chaser
	clearVisuals(c)
	c.Items = {}
	if reason == "caught" and ch then
		despawnChaser(c, ch.Cfg.Emoji .. " " .. ch.Cfg.CaughtLine)
		Remotes.Event("CarryFX"):FireClient(player, "Caught", { By = ch.Cfg.Name, Emoji = ch.Cfg.Emoji, Count = count })
		Svc.Net.Notify(player, ch.Cfg.Emoji .. " " .. ch.Cfg.Name .. " caught you! You dropped " .. count .. " object" .. (count == 1 and "" or "s") .. ".", "error")
	else
		despawnChaser(c, nil)
		if reason == "died" and count > 0 then
			Svc.Net.Notify(player, "💀 You dropped what you were carrying!", "error")
		end
	end
	if player.Parent then
		Svc.Data.MarkDirty(player)
	end
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
		CarryService.DropAll(player, "died")
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

function CarryService.Start()
	Svc.Data.AddSyncProvider(function(player, payload)
		local c = carrying[player]
		payload.Carry = {
			Count = c and #c.Items or 0,
			Capacity = CarryService.Capacity(player),
			Chaser = c and c.Chaser and (c.Chaser.Cfg.Emoji .. " " .. c.Chaser.Cfg.Name) or nil,
		}
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			for player, c in pairs(carrying) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local hum = character and character:FindFirstChildOfClass("Humanoid")
				if #c.Items > 0 and root and hum and hum.Health > 0 and Svc.Map.IsInBase(root.Position) then
					CarryService.Deposit(player)
				elseif c.Chaser then
					local ch = c.Chaser
					if not ch.Model.Parent or not root or #c.Items == 0 then
						despawnChaser(c, nil)
					elseif os.clock() < ch.StartAt then
						ch.Humanoid:MoveTo(ch.Root.Position)
					else
						ch.Humanoid:MoveTo(root.Position)
						local reach = ChaserConfig.CatchDistance * math.max(1, ch.Cfg.Scale)
						if (ch.Root.Position - root.Position).Magnitude <= reach then
							CarryService.DropAll(player, "caught")
						end
					end
				end
			end
		end
	end)
end

return CarryService
