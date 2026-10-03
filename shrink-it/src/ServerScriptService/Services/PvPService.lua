--[[
	📍 LOCATION: ServerScriptService > Services > PvPService (ModuleScript)

	Everyone gets a 🏏 Bat and a 🪤 Trap (tools in the backpack).
	• Bat: swing at a player in front of you. Outside the safe zone they get knocked back and stunned,
	  and if they're CARRYING something (a box or a held object) you STEAL the top one.
	  Requirements (GameConfig.PvP): victim has MinRebirthsToBeStolenFrom rebirths, attacker has
	  MinRebirthsToSteal; nobody can be hit inside the safe zone; a robbed player is protected for a
	  few seconds. Exclusive objects can't be stolen.
	• Trap: drop a bear trap at your feet (not in the safe zone). The next OTHER player who steps on
	  it is stuck for TrapStunSeconds — perfect for a bat follow-up.
	Everything is checked on the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local PvPService = {}
local Svc

local cfg = GameConfig.PvP
local lastSwing = {} -- [player] = os.clock()
local lastTrap = {}
local traps = {} -- [player] = { Part }
local protectedUntil = {} -- [player] = os.clock()
local stunnedUntil = {} -- [player] = os.clock()

function PvPService.Init(registry)
	Svc = registry
end

local function rootOf(player)
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil, nil
	end
	return character:FindFirstChild("HumanoidRootPart"), hum
end

local function part(parent, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.Massless = true
	p.Parent = parent
	return p
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- ── tools ────────────────────────────────────────────────────────────
-- Tools are held with the Handle's +Y axis pointing forward out of the hand.
local function makeBat()
	local tool = Instance.new("Tool")
	tool.Name = "Bat"
	tool.ToolTip = "Whack players to steal what they carry!"
	tool.CanBeDropped = false
	local wood = Color3.fromRGB(214, 160, 98)
	local handle = part(tool, Vector3.new(0.38, 1.3, 0.38), CFrame.new(), Color3.fromRGB(35, 35, 40), Enum.Material.Fabric) -- grip tape
	handle.Name = "Handle"
	local knob = part(tool, Vector3.new(0.6, 0.18, 0.6), CFrame.new(0, -0.74, 0), Color3.fromRGB(35, 35, 40), Enum.Material.Fabric, Enum.PartType.Cylinder)
	knob.CFrame = CFrame.new(0, -0.74, 0) * CFrame.Angles(0, 0, math.rad(90))
	weld(handle, knob)
	-- tapered barrel (thin → thick), then a rounded end
	local widths = { 0.42, 0.5, 0.6, 0.7, 0.78 }
	for i, w in ipairs(widths) do
		local seg = part(tool, Vector3.new(0.75, w, w), CFrame.new(0, 0.65 + (i - 0.5) * 0.72, 0) * CFrame.Angles(0, 0, math.rad(90)), wood, Enum.Material.Wood, Enum.PartType.Cylinder)
		weld(handle, seg)
	end
	local cap = part(tool, Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 0.65 + 5 * 0.72, 0), wood, Enum.Material.Wood, Enum.PartType.Ball)
	weld(handle, cap)
	-- swing trail along the barrel
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailBottom"
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = handle
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailTop"
	a1.Position = Vector3.new(0, 4.2, 0)
	a1.Parent = handle
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.2
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Enabled = false
	trail.Parent = handle
	tool.Grip = CFrame.new(0, -0.45, 0)
	return tool
end

-- a bear trap model (used in your hand and on the ground). open = jaws flat, closed = jaws up.
local function bearTrap(parent, center, size, open)
	local metal = Color3.fromRGB(95, 95, 105)
	local steel = Color3.fromRGB(205, 205, 215)
	local r = size
	local plate = part(parent, Vector3.new(0.18 * r, 1.6 * r, 1.6 * r), center * CFrame.Angles(0, 0, math.rad(90)), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	plate.Name = "Plate"
	local pad = part(parent, Vector3.new(0.7 * r, 0.12 * r, 0.7 * r), center * CFrame.new(0, 0.12 * r, 0), Color3.fromRGB(230, 60, 60), Enum.Material.Neon)
	pad.Name = "Pad"
	local jaws = {}
	for _, side in ipairs({ -1, 1 }) do
		local jaw = Instance.new("Model")
		jaw.Name = side < 0 and "JawA" or "JawB"
		jaw.Parent = parent
		-- a half ring of bars + teeth, hinged on the x axis through the center
		for k = 0, 6 do
			local a = math.rad(-90 + k * 30)
			local x, z = math.sin(a) * 1.25 * r, side * math.cos(a) * 1.25 * r
			part(jaw, Vector3.new(0.62 * r, 0.14 * r, 0.14 * r), center * CFrame.new(x, 0.1 * r, z) * CFrame.Angles(0, a * side, 0), metal, Enum.Material.Metal)
			part(jaw, Vector3.new(0.12 * r, 0.34 * r, 0.12 * r), center * CFrame.new(x * 0.92, 0.3 * r, z * 0.92), steel, Enum.Material.Metal)
		end
		jaws[side] = jaw
		if not open then
			jaw:PivotTo(center * CFrame.Angles(-side * math.rad(85), 0, 0) * center:Inverse() * jaw:GetPivot())
		end
	end
	return plate, jaws
end

-- YOUR bear trap model (ServerStorage > BearTrap, imported in Studio) replaces the built-in one.
-- It's scaled to fit, its bottom sits on the ground; a quick squash plays when it snaps.
local function customTrap(parent, center, size)
	local ss = game:GetService("ServerStorage")
	local holder = ss:FindFirstChild("CustomModels")
	local template = (holder and holder:FindFirstChild("BearTrap")) or ss:FindFirstChild("BearTrap")
	if not template then
		return nil
	end
	local model = template:Clone()
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.Massless = true
		end
	end
	if model:IsA("BasePart") then
		local wrap = Instance.new("Model")
		model.Parent = wrap
		wrap.PrimaryPart = model
		model = wrap
	end
	local ext = model:GetExtentsSize()
	local biggest = math.max(ext.X, ext.Z)
	if biggest > 0 then
		model:ScaleTo(model:GetScale() * (3.4 * size / biggest))
	end
	model:PivotTo(center)
	local cf, box = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (center.Position - Vector3.new(cf.Position.X, cf.Position.Y - box.Y / 2, cf.Position.Z)))
	model.Parent = parent
	local biggestPart, vol = nil, -1
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Size.X * d.Size.Y * d.Size.Z > vol then
			biggestPart, vol = d, d.Size.X * d.Size.Y * d.Size.Z
		end
	end
	return biggestPart, {}, model
end

local function makeTrapTool()
	local tool = Instance.new("Tool")
	tool.Name = "Trap"
	tool.ToolTip = "Drop a bear trap. The next player who steps on it gets stuck!"
	tool.CanBeDropped = false
	local handle = part(tool, Vector3.new(0.3, 0.9, 0.3), CFrame.new(), Color3.fromRGB(70, 70, 80), Enum.Material.Metal) -- chain grip
	handle.Name = "Handle"
	-- a closed trap carried in front of the hand
	local holder = Instance.new("Model")
	holder.Parent = tool
	if not customTrap(holder, CFrame.new(0, 1.1, 0) * CFrame.Angles(math.rad(90), 0, 0), 0.55) then
		bearTrap(holder, CFrame.new(0, 1.1, 0) * CFrame.Angles(math.rad(90), 0, 0), 0.55, false)
	end
	for _, d in ipairs(holder:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
			weld(handle, d)
		end
	end
	tool.Grip = CFrame.new(0, -0.2, 0)
	return tool
end

local function giveTools(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local character = player.Character
	for name, maker in pairs({ Bat = makeBat, Trap = makeTrapTool }) do
		if not backpack:FindFirstChild(name) and not (character and character:FindFirstChild(name)) then
			local tool = maker()
			tool.Parent = backpack
			tool.Activated:Connect(function()
				if name == "Bat" then
					PvPService.Swing(player, tool)
				else
					PvPService.PlaceTrap(player)
				end
			end)
		end
	end
end

-- ── stun ─────────────────────────────────────────────────────────────
function PvPService.IsStunned(player)
	return (stunnedUntil[player] or 0) > os.clock()
end

local function stun(player, seconds)
	local _, hum = rootOf(player)
	if not hum then
		return
	end
	stunnedUntil[player] = os.clock() + seconds
	player:SetAttribute("StunnedUntil", workspace:GetServerTimeNow() + seconds)
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	task.delay(seconds, function()
		if (stunnedUntil[player] or 0) <= os.clock() + 0.05 then
			local _, h = rootOf(player)
			if h then
				h.JumpPower = 50
				Svc.Monetization.ApplyMovement(player)
			end
		end
	end)
end

-- ── stealing ─────────────────────────────────────────────────────────
local function canBeRobbed(victim, attacker)
	local vData, aData = Svc.Data.Get(victim), Svc.Data.Get(attacker)
	if not vData or not aData then
		return false, nil
	end
	if (vData.Rebirths or 0) < cfg.MinRebirthsToBeStolenFrom then
		return false, victim.DisplayName .. " is protected until they rebirth."
	end
	if (aData.Rebirths or 0) < cfg.MinRebirthsToSteal then
		return false, "You need " .. cfg.MinRebirthsToSteal .. " rebirth(s) to steal!"
	end
	if (protectedUntil[victim] or 0) > os.clock() then
		return false, nil
	end
	return true, nil
end

local function steal(attacker, victim)
	local entry = Svc.Carry.StealTop(victim)
	if not entry then
		return nil
	end
	protectedUntil[victim] = os.clock() + cfg.ProtectAfterSteal
	if entry.Kind == "Box" then
		Svc.Carry.GiveBox(attacker, entry.Box)
		return Formulas.BoxName(entry.Box)
	end
	local item = Svc.Museum.TransferItem(victim, attacker, entry.U)
	if not item then
		return nil -- exclusive: it just goes back to the victim's pocket
	end
	Svc.Carry.Hold(attacker, item)
	return Formulas.ItemName(item)
end

function PvPService.Swing(player, tool)
	local now = os.clock()
	if (lastSwing[player] or 0) + cfg.BatCooldown > now or PvPService.IsStunned(player) then
		return
	end
	lastSwing[player] = now
	local root = rootOf(player)
	if not root then
		return
	end
	-- the default Animate script plays a swing when a Tool gets a "toolanim" = "Slash" value
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = tool
	game:GetService("Debris"):AddItem(anim, 1)
	local trail = tool:FindFirstChild("Handle") and tool.Handle:FindFirstChild("SwingTrail")
	if trail then
		trail.Enabled = true
		task.delay(0.35, function()
			trail.Enabled = false
		end)
	end
	Svc.Net.Sound("Swing", nil, root.Position)

	-- closest player in front of you within range
	local best, bestDist = nil, math.huge
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local oRoot = rootOf(other)
			if oRoot then
				local offset = oRoot.Position - root.Position
				local dist = offset.Magnitude
				if dist <= cfg.BatRange and (dist < 3 or root.CFrame.LookVector:Dot(offset.Unit) > 0.2) and dist < bestDist then
					best, bestDist = other, dist
				end
			end
		end
	end
	if not best then
		return
	end
	local vRoot = rootOf(best)
	if Svc.Map.IsInBase(vRoot.Position) or Svc.Map.IsInBase(root.Position) then
		Svc.Net.Notify(player, "No fighting in the safe zone!", "error")
		return
	end
	-- knockback + stun
	local push = (vRoot.Position - root.Position) * Vector3.new(1, 0, 1)
	if push.Magnitude > 0.01 then
		vRoot.AssemblyLinearVelocity = push.Unit * cfg.BatKnockback + Vector3.new(0, 25, 0)
	end
	stun(best, cfg.StunSeconds)
	Svc.Net.Sound("Whack", nil, vRoot.Position)
	Remotes.Event("PvPFX"):FireAllClients("Hit", { Victim = best, Attacker = player, Position = vRoot.Position })

	if Svc.Carry.IsCarrying(best) then
		local ok, why = canBeRobbed(best, player)
		if ok then
			local what = steal(player, best)
			if what then
				Svc.Net.Notify(player, "You stole " .. what .. " from " .. best.DisplayName .. "! Run!", "success")
				Svc.Net.Notify(best, "😱 " .. player.DisplayName .. " stole your " .. what .. "!", "error")
				Remotes.Event("PvPFX"):FireAllClients("Steal", { Victim = best, Attacker = player, What = what })
			end
		elseif why then
			Svc.Net.Notify(player, why, "error")
		end
	end
end

-- ── traps ────────────────────────────────────────────────────────────
local activeTraps = {} -- { Model, Owner, Center, Jaws, Sprung, Expires }

local function snap(trap)
	if trap.Custom then
		-- your model: a quick squash "SNAP"
		local start = trap.Custom:GetScale()
		pcall(function()
			trap.Custom:ScaleTo(start * 0.8)
			task.wait(0.08)
			trap.Custom:ScaleTo(start * 1.05)
			task.wait(0.06)
			trap.Custom:ScaleTo(start)
		end)
		return
	end
	-- jaws close up around the victim's legs
	for step = 1, 4 do
		for side, jaw in pairs(trap.Jaws) do
			jaw:PivotTo(trap.Center * CFrame.Angles(-side * math.rad(85 / 4), 0, 0) * trap.Center:Inverse() * jaw:GetPivot())
		end
		if step < 4 then
			task.wait(0.02)
		end
	end
end

function PvPService.PlaceTrap(player)
	local now = os.clock()
	local root = rootOf(player)
	if not root then
		return
	end
	if (lastTrap[player] or 0) + cfg.TrapCooldown > now then
		Svc.Net.Notify(player, string.format("Trap ready in %ds", math.ceil(lastTrap[player] + cfg.TrapCooldown - now)), "error")
		return
	end
	if Svc.Map.IsInBase(root.Position) then
		Svc.Net.Notify(player, "No traps in the safe zone!", "error")
		return
	end
	-- find the real ground under you (a little behind you, so the chaser / thief runs into it)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, Svc.Map.LiveObjects }
	local from = root.Position - root.CFrame.LookVector * 3
	local hit = workspace:Raycast(from, Vector3.new(0, -12, 0), params)
	local ground = hit and hit.Position or (root.Position - Vector3.new(0, 3, 0))
	lastTrap[player] = now
	local list = traps[player] or {}
	traps[player] = list
	while #list >= cfg.MaxTraps do
		local old = table.remove(list, 1)
		if old then
			old:Destroy()
		end
	end
	local model = Instance.new("Model")
	model.Name = "Trap"
	model:SetAttribute("OwnerUserId", player.UserId)
	local center = CFrame.new(ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, math.random() * math.pi, 0)
	local plate, jaws, custom = customTrap(model, center, 1)
	if not plate then
		plate, jaws = bearTrap(model, center, 1, true)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model.PrimaryPart = plate
	model.Parent = Svc.Map.LiveObjects
	table.insert(list, model)
	table.insert(activeTraps, { Model = model, Owner = player, Center = center, Jaws = jaws, Custom = custom, Sprung = false, Expires = now + cfg.TrapLifetime })
	Svc.Net.Sound("Trap", player)
	Svc.Net.Notify(player, "Trap set!", "info")
end

local function trapLoop()
	while true do
		task.wait(0.1)
		local now = os.clock()
		for i = #activeTraps, 1, -1 do
			local trap = activeTraps[i]
			if not trap.Model.Parent or now >= trap.Expires then
				table.remove(activeTraps, i)
				if trap.Model.Parent then
					trap.Model:Destroy()
				end
			elseif not trap.Sprung then
				for _, victim in ipairs(Players:GetPlayers()) do
					local vRoot = rootOf(victim)
					if victim ~= trap.Owner and vRoot then
						local offset = vRoot.Position - trap.Center.Position
						if Vector3.new(offset.X, 0, offset.Z).Magnitude < 2.4 and math.abs(offset.Y) < 6 and not Svc.Map.IsInBase(vRoot.Position) then
							trap.Sprung = true
							trap.Expires = now + cfg.TrapStunSeconds + 0.5
							stun(victim, cfg.TrapStunSeconds)
							task.spawn(snap, trap)
							Svc.Net.Sound("Trap", nil, trap.Center.Position)
							Remotes.Event("PvPFX"):FireAllClients("Trap", { Victim = victim, Attacker = trap.Owner, Position = trap.Center.Position })
							Svc.Net.Notify(victim, "You stepped in " .. trap.Owner.DisplayName .. "'s trap!", "error")
							Svc.Net.Notify(trap.Owner, victim.DisplayName .. " is stuck in your trap! Go get 'em!", "success")
							break
						end
					end
				end
			end
		end
	end
end

function PvPService.OnPlayerLoaded(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.15)
		giveTools(player)
	end)
	if player.Character then
		giveTools(player)
	end
end

function PvPService.OnPlayerRemoving(player)
	for _, t in ipairs(traps[player] or {}) do
		t:Destroy()
	end
	traps[player] = nil
	lastSwing[player] = nil
	lastTrap[player] = nil
	protectedUntil[player] = nil
	stunnedUntil[player] = nil
end

function PvPService.Start()
	task.spawn(trapLoop)
end

return PvPService
