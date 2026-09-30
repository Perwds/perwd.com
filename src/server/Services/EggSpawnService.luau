--[[
	Wild eggs.

	Every world drops eggs onto its pedestals on a timer. An egg sitting on a
	pedestal is free for anyone to take -- that is the whole hook: you see a
	Golden one land across the zone and you run.

	Tiers bias the hatch roll rather than changing which pets can appear, so a
	Golden Forest egg is still a Forest egg, just far more likely to be the
	good end of the pool.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local ModelFactory = require(ReplicatedStorage.Shared.Util.ModelFactory)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local WeightedPicker = require(ReplicatedStorage.Shared.Util.WeightedPicker)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local EggSpawnService = {}

--[[
	Wild egg tiers.
	`luck` multiplies the weight of every pool entry above Uncommon when the
	egg finally hatches, so higher tiers skew rare without ever guaranteeing.
]]
EggSpawnService.TIERS = {
	{ id = "normal", name = "Egg", weight = 74, luck = 1, rarity = "Common" },
	{ id = "lucky", name = "Lucky Egg", weight = 21, luck = 4, rarity = "Rare" },
	{ id = "golden", name = "Golden Egg", weight = 4.4, luck = 14, rarity = "Mythic" },
	{ id = "void", name = "Void Egg", weight = 0.6, luck = 45, rarity = "Secret" },
}

local rng = Random.new()
local nextEggUid = 0

--- Global rarity bias, raised at night by WorldEventService.
local globalLuck = 1

function EggSpawnService.setGlobalLuck(value: number)
	globalLuck = math.max(0.1, value)
end

function EggSpawnService.getGlobalLuck(): number
	return globalLuck
end

local function newUid(): string
	nextEggUid += 1
	return `egg_{nextEggUid}`
end

--- Builds the physical egg and tags it with everything hatching needs later.
function EggSpawnService.createEgg(world: string, tier, cframe: CFrame): Model
	local eggConfig = Eggs.forWorld(world)
	local worldInfo = Worlds.get(world)

	local model = ModelFactory.buildEgg(tier.rarity, worldInfo.accent:Lerp(Rarity.color(tier.rarity), 0.55))
	model.Name = newUid()

	model:SetAttribute("EggUid", model.Name)
	model:SetAttribute("EggId", eggConfig.id)
	model:SetAttribute("World", world)
	model:SetAttribute("Tier", tier.id)
	model:SetAttribute("Luck", tier.luck)
	model:SetAttribute("Rarity", tier.rarity)
	model:SetAttribute("HatchTime", eggConfig.hatchTime)
	model:SetAttribute("State", "loose")

	ModelFactory.configure(model, true)
	model:PivotTo(cframe)
	model.Parent = MapBuilder.getRoot().Eggs

	local shell = model.PrimaryPart :: BasePart
	-- Long range on purpose: spotting a Golden egg land across the zone is
	-- what starts the race for it.
	MapBuilder.billboard(shell, tier.name, worldInfo.display, Rarity.get(tier.rarity).glow, 200)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GrabPrompt"
	prompt.ActionText = "Steal"
	prompt.ObjectText = tier.name
	prompt.HoldDuration = Balance.Carry.GRAB_HOLD
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell

	return model
end

--- Gentle idle bob so a fresh egg catches the eye from across the zone.
local function animate(model: Model, pedestal: BasePart)
	task.spawn(function()
		local phase = rng:NextNumber() * math.pi * 2
		while model.Parent and model:GetAttribute("State") == "loose" do
			local t = os.clock() * 1.6 + phase
			model:PivotTo(
				CFrame.new(pedestal.Position + Vector3.new(0, 4.4 + math.sin(t) * 0.35, 0))
					* CFrame.Angles(0, t * 0.5, 0)
			)
			task.wait(0.05)
		end
	end)
end

local function pedestalOccupied(pedestal: BasePart): boolean
	for _, model in MapBuilder.getRoot().Eggs:GetChildren() do
		if model:GetAttribute("Pedestal") == pedestal:GetFullName() and model:GetAttribute("State") == "loose" then
			return true
		end
	end
	return false
end

local function spawnOn(world: string, pedestal: BasePart)
	if pedestalOccupied(pedestal) then
		return
	end

	local tier = WeightedPicker.pick(EggSpawnService.TIERS, rng, function(entry)
		-- Night and potions push the roll toward the rarer tiers only.
		return entry.luck > 1 and globalLuck or 1
	end)

	local model = EggSpawnService.createEgg(world, tier, CFrame.new(pedestal.Position + Vector3.new(0, 4.4, 0)))
	model:SetAttribute("Pedestal", pedestal:GetFullName())
	animate(model, pedestal)
end

function EggSpawnService.start()
	for _, world in Worlds.Order do
		local info = Worlds.get(world)
		local pedestals = MapBuilder.pedestals[world]
		if not pedestals then
			continue
		end

		task.spawn(function()
			-- Seed each pedestal so the map is not empty on the first join.
			for _, pedestal in pedestals do
				spawnOn(world, pedestal)
				task.wait(0.15)
			end

			while true do
				task.wait(info.spawnEvery / globalLuck)
				local pedestal = pedestals[rng:NextInteger(1, #pedestals)]
				spawnOn(world, pedestal)
			end
		end)
	end

	-- Sweep loose eggs that nobody picked up off the floor.
	task.spawn(function()
		while true do
			task.wait(10)
			local now = os.clock()
			for _, model in MapBuilder.getRoot().Eggs:GetChildren() do
				local droppedAt = model:GetAttribute("DroppedAt")
				if droppedAt and now - droppedAt > Balance.Carry.LOOSE_DESPAWN then
					model:Destroy()
				end
			end
		end
	end)
end

return EggSpawnService
