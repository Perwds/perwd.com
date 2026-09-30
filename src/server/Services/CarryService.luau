--[[
	Carrying and stealing eggs.

	The loop: a wild egg lands on a pedestal -> you run over and hold to grab
	it -> it welds to your back and slows you down -> anyone can hold on YOU
	for three seconds to rip it off -> you get it home to a hatch pad.

	Carry state lives in one table here and is mirrored onto character
	attributes so the client can react (HUD, nameplate, footstep speed) without
	another remote.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local CarryService = {}

-- player -> { egg = Model, since = number, immuneUntil = number }
local carrying: { [Player]: any } = {}

CarryService.EggGrabbed = Signal.new()
CarryService.EggStolen = Signal.new()
CarryService.EggDropped = Signal.new()

local carryFeedback = Net.Event("CarryFeedback")

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildWhichIsA("Humanoid")
end

--- Carrying is a real cost: heavier eggs slow you more, so the good ones are
--- the hard ones to get home.
function CarryService.refreshSpeed(player: Player)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end

	local profile = DataService.get(player)
	local bonus = profile and (profile.speedBonus or 0) / Balance.Rewards.SPEED_DIVISOR or 0

	local state = carrying[player]
	if not state then
		humanoid.WalkSpeed = Balance.Carry.WALKSPEED_BASE + bonus
		return
	end

	local rank = Rarity.Rank[state.egg:GetAttribute("Rarity")] or 1
	local penalty = (rank - 1) * Balance.Carry.WALKSPEED_RARITY_PENALTY
	humanoid.WalkSpeed = math.max(8, Balance.Carry.WALKSPEED_CARRYING - penalty + bonus)
end

local function setCharacterAttributes(player: Player)
	local character = player.Character
	if not character then
		return
	end

	local state = carrying[player]
	character:SetAttribute("CarryingEgg", state and state.egg:GetAttribute("EggUid") or nil)
	character:SetAttribute("CarryRarity", state and state.egg:GetAttribute("Rarity") or nil)
	character:SetAttribute("CarryWorld", state and state.egg:GetAttribute("World") or nil)
end

--- The prompt other players hold to steal from this carrier.
local function ensureStealPrompt(player: Player)
	local root = rootOf(player)
	if not root then
		return
	end

	local prompt = root:FindFirstChild("StealPrompt") :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.ActionText = "Steal Egg"
		prompt.HoldDuration = Balance.Carry.STEAL_HOLD
		prompt.MaxActivationDistance = Balance.Carry.STEAL_RANGE
		prompt.RequiresLineOfSight = false
		prompt.Parent = root

		prompt.Triggered:Connect(function(thief)
			CarryService.steal(thief, player)
		end)
	end

	local state = carrying[player]
	prompt.Enabled = state ~= nil
	prompt.ObjectText = state and `{player.DisplayName}'s Egg` or ""
end

local function detach(player: Player): Model?
	local state = carrying[player]
	if not state then
		return nil
	end

	local egg = state.egg
	carrying[player] = nil

	for _, descendant in egg:GetDescendants() do
		if descendant:IsA("WeldConstraint") and descendant.Name == "CarryWeld" then
			descendant:Destroy()
		end
	end

	setCharacterAttributes(player)
	ensureStealPrompt(player)
	CarryService.refreshSpeed(player)

	return egg
end

--- Welds an egg to a player's back and marks them as the carrier.
local function attach(player: Player, egg: Model)
	local root = rootOf(player)
	if not root then
		return false
	end

	local shell = egg.PrimaryPart
	if not shell then
		return false
	end

	egg:SetAttribute("State", "carried")
	egg:SetAttribute("CarrierUserId", player.UserId)
	egg:SetAttribute("DroppedAt", nil)
	egg.Parent = MapBuilder.getRoot().Eggs

	for _, descendant in egg:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.Massless = true
		end
	end

	-- Sit it on the shoulders, tipped back, so it reads from behind.
	egg:PivotTo(root.CFrame * CFrame.new(0, 2.6, 0.9) * CFrame.Angles(math.rad(-20), 0, 0))

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = shell
	weld.Parent = egg

	local grabPrompt = shell:FindFirstChild("GrabPrompt") :: ProximityPrompt?
	if grabPrompt then
		grabPrompt.Enabled = false
	end

	carrying[player] = { egg = egg, since = os.clock(), immuneUntil = 0 }

	setCharacterAttributes(player)
	ensureStealPrompt(player)
	CarryService.refreshSpeed(player)

	return true
end

function CarryService.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function CarryService.carriedEgg(player: Player): Model?
	local state = carrying[player]
	return state and state.egg or nil
end

--- Picks up a loose egg. Fails if the player already has one.
function CarryService.grab(player: Player, egg: Model): boolean
	if carrying[player] then
		carryFeedback:FireClient(player, "full", "You are already carrying an egg!")
		return false
	end
	if not egg.Parent or egg:GetAttribute("State") ~= "loose" then
		return false
	end

	local root = rootOf(player)
	local shell = egg.PrimaryPart
	if not root or not shell then
		return false
	end

	-- Trust but verify: the prompt already range-gated this, but a replayed
	-- trigger should not let someone grab across the map.
	if (root.Position - shell.Position).Magnitude > 24 then
		return false
	end

	if not attach(player, egg) then
		return false
	end

	carryFeedback:FireClient(player, "grabbed", egg:GetAttribute("Rarity"))
	CarryService.EggGrabbed:Fire(player, egg)
	return true
end

--- Rips the egg off another player. The thief becomes the new carrier.
function CarryService.steal(thief: Player, victim: Player): boolean
	if thief == victim then
		return false
	end

	local state = carrying[victim]
	if not state then
		return false
	end
	if carrying[thief] then
		carryFeedback:FireClient(thief, "full", "Drop your egg first!")
		return false
	end
	if os.clock() < (state.immuneUntil or 0) then
		carryFeedback:FireClient(thief, "immune", `{victim.DisplayName} is protected right now`)
		return false
	end

	local thiefRoot, victimRoot = rootOf(thief), rootOf(victim)
	if not thiefRoot or not victimRoot then
		return false
	end
	if (thiefRoot.Position - victimRoot.Position).Magnitude > Balance.Carry.STEAL_RANGE + 6 then
		return false
	end

	local egg = detach(victim)
	if not egg then
		return false
	end

	if not attach(thief, egg) then
		-- Attaching failed mid-steal (victim's character went away); put the
		-- egg on the floor rather than deleting someone's progress.
		CarryService.dropAt(egg, victimRoot.CFrame)
		return false
	end

	-- Brief immunity for the thief so a crowd cannot chain-steal instantly.
	carrying[thief].immuneUntil = os.clock() + Balance.Carry.STEAL_IMMUNITY

	local victimProfile = DataService.get(victim)
	if victimProfile then
		victimProfile.stats.eggsLost += 1
		DataService.markDirty(victim)
	end
	local thiefProfile = DataService.get(thief)
	if thiefProfile then
		thiefProfile.stats.eggsStolen += 1
		DataService.markDirty(thief)
	end

	carryFeedback:FireClient(thief, "stole", victim.DisplayName)
	carryFeedback:FireClient(victim, "robbed", thief.DisplayName)
	CarryService.EggStolen:Fire(thief, victim, egg)

	return true
end

--- Puts an egg back on the ground as loose, free for anyone to take.
function CarryService.dropAt(egg: Model, cframe: CFrame)
	egg:SetAttribute("State", "loose")
	egg:SetAttribute("CarrierUserId", nil)
	egg:SetAttribute("Pedestal", nil)
	egg:SetAttribute("DroppedAt", os.clock())

	for _, descendant in egg:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanQuery = true
		end
	end

	egg:PivotTo(cframe * CFrame.new(0, 2, -3))
	egg.Parent = MapBuilder.getRoot().Eggs

	local shell = egg.PrimaryPart
	local grabPrompt = shell and shell:FindFirstChild("GrabPrompt") :: ProximityPrompt?
	if grabPrompt then
		grabPrompt.Enabled = true
	end
end

--- Voluntary or forced drop by the carrier.
function CarryService.drop(player: Player): boolean
	local state = carrying[player]
	if not state then
		return false
	end

	local root = rootOf(player)
	local egg = detach(player)
	if not egg then
		return false
	end

	CarryService.dropAt(egg, root and root.CFrame or egg:GetPivot())
	CarryService.EggDropped:Fire(player, egg)
	return true
end

--- Hands the carried egg off (to HatchService). Returns it detached.
function CarryService.consume(player: Player): Model?
	local egg = detach(player)
	if egg then
		egg:SetAttribute("State", "consumed")
	end
	return egg
end

local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 10)
	ensureStealPrompt(player)
	CarryService.refreshSpeed(player)

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if Balance.Carry.DROP_ON_DEATH and carrying[player] then
				CarryService.drop(player)
			end
		end)
	end
end

function CarryService.start()
	Net.handle("DropEgg", function(player)
		if not CarryService.isCarrying(player) then
			return { ok = false, error = "You are not carrying an egg" }
		end
		CarryService.drop(player)
		return { ok = true }
	end)

	-- Any egg's grab prompt routes here.
	MapBuilder.getRoot().Eggs.ChildAdded:Connect(function(egg)
		if not egg:IsA("Model") then
			return
		end
		local shell = egg.PrimaryPart or egg:WaitForChild("Shell", 5)
		local prompt = shell and shell:FindFirstChild("GrabPrompt") :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function(player)
				CarryService.grab(player, egg :: Model)
			end)
		end
	end)

	for _, egg in MapBuilder.getRoot().Eggs:GetChildren() do
		local shell = egg:IsA("Model") and egg.PrimaryPart
		local prompt = shell and shell:FindFirstChild("GrabPrompt") :: ProximityPrompt?
		if prompt then
			prompt.Triggered:Connect(function(player)
				CarryService.grab(player, egg :: Model)
			end)
		end
	end

	local function hook(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
	end

	Players.PlayerAdded:Connect(hook)
	for _, player in Players:GetPlayers() do
		hook(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local state = carrying[player]
		if state then
			-- Leave the egg behind rather than deleting it -- someone else
			-- watching you run should get the chance to take it.
			local root = rootOf(player)
			detach(player)
			CarryService.dropAt(state.egg, root and root.CFrame or state.egg:GetPivot())
		end
	end)
end

return CarryService
