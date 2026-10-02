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
local function makeBat()
	local tool = Instance.new("Tool")
	tool.Name = "Bat"
	tool.ToolTip = "Whack players to steal what they carry!"
	tool.CanBeDropped = false
	tool.TextureId = ""
	local handle = part(tool, Vector3.new(0.4, 1.4, 0.4), CFrame.new(), Color3.fromRGB(60, 40, 30), Enum.Material.Fabric)
	handle.Name = "Handle"
	local barrel = part(tool, Vector3.new(0.7, 3, 0.7), handle.CFrame * CFrame.new(0, 2.1, 0), Color3.fromRGB(205, 150, 90), Enum.Material.Wood)
	weld(handle, barrel)
	local cap = part(tool, Vector3.new(0.72, 0.72, 0.72), handle.CFrame * CFrame.new(0, 3.6, 0), Color3.fromRGB(205, 150, 90), Enum.Material.Wood, Enum.PartType.Ball)
	weld(handle, cap)
	local knob = part(tool, Vector3.new(0.6, 0.2, 0.6), handle.CFrame * CFrame.new(0, -0.75, 0), Color3.fromRGB(40, 30, 25), Enum.Material.Wood)
	weld(handle, knob)
	tool.Grip = CFrame.new(0, -0.3, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	return tool
end

local function makeTrapTool()
	local tool = Instance.new("Tool")
	tool.Name = "Trap"
	tool.ToolTip = "Drop a trap that stops the next player who steps on it."
	tool.CanBeDropped = false
	local handle = part(tool, Vector3.new(1.6, 0.3, 1.6), CFrame.new(), Color3.fromRGB(110, 110, 120), Enum.Material.Metal, Enum.PartType.Cylinder)
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 1.6, 1.6)
	tool.Grip = CFrame.Angles(0, 0, math.rad(90))
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
		Svc.Net.Notify(player, "🛡️ No fighting in the safe zone!", "error")
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
				Svc.Net.Notify(player, "💰 You stole " .. what .. " from " .. best.DisplayName .. "! Run!", "success")
				Svc.Net.Notify(best, "😱 " .. player.DisplayName .. " stole your " .. what .. "!", "error")
				Remotes.Event("PvPFX"):FireAllClients("Steal", { Victim = best, Attacker = player, What = what })
			end
		elseif why then
			Svc.Net.Notify(player, why, "error")
		end
	end
end

-- ── traps ────────────────────────────────────────────────────────────
local function buildTrap(owner, position)
	local model = Instance.new("Model")
	model.Name = "Trap"
	model:SetAttribute("OwnerUserId", owner.UserId)
	local base = Instance.new("Part")
	base.Name = "Plate"
	base.Anchored = true
	base.CanCollide = false
	base.Size = Vector3.new(0.3, 3.4, 3.4)
	base.Shape = Enum.PartType.Cylinder
	base.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	base.Color = Color3.fromRGB(90, 90, 100)
	base.Material = Enum.Material.Metal
	base.Parent = model
	for i = 0, 9 do -- teeth
		local a = i / 10 * math.pi * 2
		local tooth = Instance.new("WedgePart")
		tooth.Anchored = true
		tooth.CanCollide = false
		tooth.CanTouch = false
		tooth.Size = Vector3.new(0.25, 0.6, 0.35)
		tooth.CFrame = CFrame.new(position + Vector3.new(math.cos(a) * 1.5, 0.55, math.sin(a) * 1.5)) * CFrame.Angles(0, -a, 0)
		tooth.Color = Color3.fromRGB(200, 200, 210)
		tooth.Material = Enum.Material.Metal
		tooth.Parent = model
	end
	local center = Instance.new("Part")
	center.Anchored = true
	center.CanCollide = false
	center.CanTouch = false
	center.Size = Vector3.new(0.9, 0.2, 0.9)
	center.CFrame = CFrame.new(position + Vector3.new(0, 0.35, 0))
	center.Color = Color3.fromRGB(230, 60, 60)
	center.Material = Enum.Material.Neon
	center.Parent = model
	model.PrimaryPart = base
	return model, base
end

function PvPService.PlaceTrap(player)
	local now = os.clock()
	local root = rootOf(player)
	if not root then
		return
	end
	if (lastTrap[player] or 0) + cfg.TrapCooldown > now then
		Svc.Net.Notify(player, string.format("🪤 Trap ready in %ds", math.ceil(lastTrap[player] + cfg.TrapCooldown - now)), "error")
		return
	end
	if Svc.Map.IsInBase(root.Position) then
		Svc.Net.Notify(player, "🛡️ No traps in the safe zone!", "error")
		return
	end
	lastTrap[player] = now
	local list = traps[player] or {}
	traps[player] = list
	while #list >= cfg.MaxTraps do
		local old = table.remove(list, 1)
		if old then
			old:Destroy()
		end
	end
	local model, plate = buildTrap(player, root.Position - Vector3.new(0, 3, 0))
	model.Parent = Svc.Map.LiveObjects
	table.insert(list, model)
	local sprung = false
	plate.Touched:Connect(function(hit)
		if sprung then
			return
		end
		local victim = Players:GetPlayerFromCharacter(hit.Parent)
		if victim and victim ~= player then
			local vRoot = rootOf(victim)
			if vRoot and not Svc.Map.IsInBase(vRoot.Position) then
				sprung = true
				stun(victim, cfg.TrapStunSeconds)
				Svc.Net.Sound("Trap", nil, plate.Position)
				Remotes.Event("PvPFX"):FireAllClients("Trap", { Victim = victim, Attacker = player, Position = plate.Position })
				Svc.Net.Notify(victim, "🪤 You stepped in " .. player.DisplayName .. "'s trap!", "error")
				Svc.Net.Notify(player, "🪤 " .. victim.DisplayName .. " is stuck in your trap! Go get 'em!", "success")
				task.delay(cfg.TrapStunSeconds, function()
					model:Destroy()
				end)
			end
		end
	end)
	task.delay(cfg.TrapLifetime, function()
		if model.Parent then
			model:Destroy()
		end
	end)
	Svc.Net.Sound("Trap", player)
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

function PvPService.Start() end

return PvPService
