--[[
	Every pet in the game.

	The 104 indexed pets are eight per world, laid out by slot:
		1 Common    2 Common    3 Uncommon  4 Rare
		5 Rare      6 Epic      7 Legendary 8 Mythic

	Limited pets live outside the 104 and only drop from event eggs -- they
	fill the "Limited" tab of the Pet Index.

	Income and drop weight are derived from the slot so the curve stays
	consistent across every world. Override either per pet with `income`
	or `weight` if you want a one-off.

	To attach art: set `modelId` to a rbxassetid of a Model. Leave it nil and
	the game builds a tinted placeholder so everything is playable today.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local Pets = {}

-- Slot -> rarity. Mirrors the eight tiles shown per world in the Pet Index.
local SLOT_RARITY = { "Common", "Common", "Uncommon", "Rare", "Rare", "Epic", "Legendary", "Mythic" }

-- Slot -> drop weight out of 100.
local SLOT_WEIGHT = { 30, 25, 20, 12, 7, 4, 1.5, 0.5 }

-- Eight names per world, in slot order.
local ROSTERS = {
	Forest = { "Bunny", "Squirrel", "Fox", "Owl", "Boar", "Stag", "Grizzly", "Treant" },
	Desert = { "Gecko", "Meerkat", "Scorpion", "Camel", "Vulture", "Cobra", "Sphinx Cat", "Sandworm" },
	Ocean = { "Clownfish", "Crab", "Turtle", "Dolphin", "Octopus", "Shark", "Anglerfish", "Kraken" },
	Tundra = { "Snow Hare", "Penguin", "Seal", "Arctic Fox", "Walrus", "Snow Owl", "Polar Bear", "Yeti" },
	Volcano = { "Ember Rat", "Magma Slug", "Lava Toad", "Cinder Hound", "Ash Ram", "Obsidian Golem", "Magma Drake", "Phoenix" },
	Jungle = { "Dart Frog", "Toucan", "Monkey", "Panther", "Anaconda", "Gorilla", "Jaguar God", "Jungle Titan" },
	Sky = { "Sparrow", "Cloud Pup", "Kite Fish", "Falcon", "Storm Crow", "Griffin", "Thunderbird", "Sky Whale" },
	Candy = { "Gumdrop", "Jelly Bean", "Lollipop Pup", "Choco Bunny", "Taffy Cat", "Cupcake Dragon", "Candy King", "Sugar Serpent" },
	Space = { "Moon Mouse", "Star Slug", "Comet Cat", "Rocket Pup", "Alien Grey", "Nebula Fox", "Event Horizon", "Galaxy Dragon" },
	Haunted = { "Bat", "Ghost Rat", "Pumpkin Pup", "Skeleton Dog", "Wraith", "Reaper Cat", "Vampire Lord", "Soul Devourer" },
	Crystal = { "Quartz Mole", "Geode Beetle", "Prism Bird", "Amethyst Wolf", "Diamond Deer", "Crystal Golem", "Opal Phoenix", "Prism Dragon" },
	Cyber = { "Data Mite", "Circuit Rat", "Drone Pup", "Neon Cat", "Mech Hound", "Firewall Golem", "Quantum Fox", "Mainframe Dragon" },
	Mythic = { "Pixie", "Imp", "Unicorn Foal", "Chimera", "Basilisk", "Hydra", "Leviathan", "Celestial Dragon" },
}

--- "Sphinx Cat" -> "desert_sphinx_cat"
local function makeId(world: string, name: string): string
	local slug = name:lower():gsub("[^%a%d]+", "_"):gsub("^_+", ""):gsub("_+$", "")
	return string.format("%s_%s", world:lower(), slug)
end

Pets.List = {}
Pets.ById = {}
Pets.ByWorld = {}

for _, world in Worlds.Order do
	local info = Worlds.get(world)
	local roster = ROSTERS[world]
	assert(roster and #roster == 8, `world "{world}" needs exactly 8 pets`)

	Pets.ByWorld[world] = {}

	for slot, name in roster do
		local rarityName = SLOT_RARITY[slot]
		local pet = {
			id = makeId(world, name),
			name = name,
			world = world,
			slot = slot,
			rarity = rarityName,
			limited = false,
			-- Cash per second while equipped.
			income = math.floor(info.incomeBase * Rarity.get(rarityName).incomeMultiplier + 0.5),
			weight = SLOT_WEIGHT[slot],
			-- Placeholder tint, replaced by `modelId` art when you supply it.
			color = info.accent:Lerp(Rarity.color(rarityName), 0.65),
			modelId = nil,
			-- Set to a Ugc entry id to make this pet carry a UGC unlock on hatch.
			ugcId = nil,
		}

		table.insert(Pets.List, pet)
		Pets.ById[pet.id] = pet
		table.insert(Pets.ByWorld[world], pet)
	end
end

--[[
	Limited pets. These are NOT part of the 104 -- they show in the Limited
	tab and only come from event eggs. `ugcId` links a pet to a UGC unlock:
	hatching the pet unlocks the item (the "rare egg drop" path).
]]
local LIMITED = {
	{
		id = "limited_skeletal_raptor",
		name = "Skeletal Raptor",
		rarity = "Secret",
		income = 900e6,
		weight = 1,
		egg = "extinction",
		color = Color3.fromRGB(238, 238, 228),
		ugcId = "skeletal_crown",
	},
	{
		id = "limited_sabertooth",
		name = "Sabertooth",
		rarity = "Mythic",
		income = 240e6,
		weight = 0.5,
		egg = "extinction",
		color = Color3.fromRGB(226, 158, 70),
	},
	{
		id = "limited_mammoth",
		name = "Woolly Mammoth",
		rarity = "Legendary",
		income = 64e6,
		weight = 6.5,
		egg = "extinction",
		color = Color3.fromRGB(150, 110, 78),
	},
	{
		id = "limited_megalodon",
		name = "Megalodon",
		rarity = "Epic",
		income = 22e6,
		weight = 11,
		egg = "extinction",
		color = Color3.fromRGB(64, 104, 178),
	},
	{
		id = "limited_giant_sloth",
		name = "Giant Sloth",
		rarity = "Rare",
		income = 7e6,
		weight = 18,
		egg = "extinction",
		color = Color3.fromRGB(140, 112, 86),
	},
	{
		id = "limited_terror_bird",
		name = "Terror Bird",
		rarity = "Uncommon",
		income = 2.4e6,
		weight = 24,
		egg = "extinction",
		color = Color3.fromRGB(180, 70, 60),
	},
	{
		id = "limited_glyptodon",
		name = "Glyptodon",
		rarity = "Common",
		income = 900e3,
		weight = 39,
		egg = "extinction",
		color = Color3.fromRGB(196, 150, 96),
	},
}

for _, entry in LIMITED do
	entry.limited = true
	entry.world = "Limited"
	entry.modelId = entry.modelId or nil
	table.insert(Pets.List, entry)
	Pets.ById[entry.id] = entry
end

Pets.Limited = LIMITED

--- Total slots the Pet Index counts. Limited pets are excluded on purpose.
Pets.INDEXED_COUNT = 0
for _, pet in Pets.List do
	if not pet.limited then
		Pets.INDEXED_COUNT += 1
	end
end

function Pets.get(id: string)
	return Pets.ById[id]
end

function Pets.forWorld(world: string)
	return Pets.ByWorld[world]
end

--- Income after shiny/mutation multipliers are applied.
function Pets.incomeOf(petId: string, multiplier: number?): number
	local pet = Pets.ById[petId]
	if not pet then
		return 0
	end
	return pet.income * (multiplier or 1)
end

return Pets
