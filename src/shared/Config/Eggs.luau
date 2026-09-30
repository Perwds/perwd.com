--[[
	Eggs. One per world, plus limited event eggs.

	Every egg carries a weighted pool. Weights are relative, not percentages --
	the shop UI converts them to percentages for display, so you can retune a
	single entry without rebalancing the rest.

	`hatchTime` is how long the egg sits on your hatch pad after you carry it
	home. It is real elapsed time and survives leaving the game.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local Eggs = {}

Eggs.List = {}
Eggs.ById = {}

-- One egg per world, pool built from that world's eight pets.
for _, world in Worlds.Order do
	local info = Worlds.get(world)
	local pool = {}

	for _, pet in Pets.forWorld(world) do
		table.insert(pool, { petId = pet.id, weight = pet.weight })
	end

	local egg = {
		id = world:lower() .. "_egg",
		name = info.display .. " Egg",
		world = world,
		cost = info.eggCost,
		robuxCost = nil,
		hatchTime = info.hatchTime,
		limited = false,
		color = info.accent,
		pool = pool,
	}

	table.insert(Eggs.List, egg)
	Eggs.ById[egg.id] = egg
end

--[[
	Limited event eggs. Set `endsAt` to a unix timestamp to run the countdown
	in the shop; nil means "no timer". Sold for Robux in bundles.
]]
local LIMITED_EGGS = {
	{
		id = "extinction",
		name = "Extinction Egg",
		world = "Limited",
		cost = nil,
		robuxCost = 99,
		hatchTime = 900,
		limited = true,
		featured = true,
		color = Color3.fromRGB(214, 62, 38),
		-- Robux bundles shown on the shop card, cheapest last.
		bundles = {
			{ amount = 50, robux = 3499, wasRobux = 5959 },
			{ amount = 10, robux = 799 },
			{ amount = 3, robux = 249 },
			{ amount = 1, robux = 99 },
		},
		-- Seconds this egg stays in the shop from server start. Swap for a
		-- fixed unix timestamp once you know your launch time.
		durationSeconds = 10 * 86400 + 11 * 3600,
	},
}

for _, egg in LIMITED_EGGS do
	local pool = {}
	for _, pet in Pets.Limited do
		if pet.egg == egg.id then
			table.insert(pool, { petId = pet.id, weight = pet.weight })
		end
	end
	egg.pool = pool

	table.insert(Eggs.List, egg)
	Eggs.ById[egg.id] = egg
end

function Eggs.get(id: string)
	return Eggs.ById[id]
end

function Eggs.forWorld(world: string)
	return Eggs.ById[world:lower() .. "_egg"]
end

--- Total weight of an egg's pool, used for percentage display and rolling.
function Eggs.totalWeight(egg): number
	local total = 0
	for _, entry in egg.pool do
		total += entry.weight
	end
	return total
end

--- Drop chance of one pool entry, as a 0-100 percentage.
function Eggs.chanceOf(egg, petId: string): number
	local total = Eggs.totalWeight(egg)
	if total <= 0 then
		return 0
	end
	for _, entry in egg.pool do
		if entry.petId == petId then
			return entry.weight / total * 100
		end
	end
	return 0
end

return Eggs
