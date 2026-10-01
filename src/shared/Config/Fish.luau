--!nonstrict
-- The roster. One line per fish so the whole game economy fits on one screen.
--   value  : base coin value before rarity / mutation / weight multipliers
--   kg     : { min, max } catch weight, rolled per catch
--   color  : the species' own colour, used to build its model
--   shape  : silhouette archetype, drives the procedural geometry

local Rarities = require(script.Parent.Rarities)
local Zones = require(script.Parent.Zones)

-- Every archetype here needs a builder in FishModel, or a catch renders as
-- nothing at all. tests/specs.luau asserts the two lists agree.
local SHAPES = {
	round = true,
	long = true,
	flat = true,
	bulb = true,
	orb = true,
	crab = true,
	squid = true,
	seahorse = true,
}

local ROSTER = {
	-- Starter Pond -----------------------------------------------------------
	{ id = "minnow", name = "Minnow", zone = "pond", rarity = "Common", value = 4, kg = { 0.05, 0.6 }, color = { 176, 188, 200 }, shape = "round" },
	{ id = "bluegill", name = "Bluegill", zone = "pond", rarity = "Common", value = 6, kg = { 0.2, 1.4 }, color = { 108, 156, 186 }, shape = "round" },
	{ id = "carp", name = "Common Carp", zone = "pond", rarity = "Common", value = 7, kg = { 1, 6 }, color = { 158, 142, 96 }, shape = "round" },
	{ id = "perch", name = "Yellow Perch", zone = "pond", rarity = "Uncommon", value = 12, kg = { 0.3, 2.2 }, color = { 206, 176, 74 }, shape = "round" },
	{ id = "bass", name = "Largemouth Bass", zone = "pond", rarity = "Uncommon", value = 15, kg = { 1.2, 7 }, color = { 104, 148, 92 }, shape = "round" },
	{ id = "pike", name = "Northern Pike", zone = "pond", rarity = "Rare", value = 26, kg = { 3, 16 }, color = { 92, 132, 82 }, shape = "long" },
	{ id = "golden_koi", name = "Golden Koi", zone = "pond", rarity = "Epic", value = 48, kg = { 2, 9 }, color = { 244, 176, 62 }, shape = "round" },
	{ id = "pond_leviathan", name = "Pond Leviathan", zone = "pond", rarity = "Legendary", value = 110, kg = { 40, 180 }, color = { 74, 96, 78 }, shape = "bulb" },
	{ id = "wishing_coin", name = "Wishing Coin", zone = "pond", rarity = "Mythic", value = 260, kg = { 0.01, 0.03 }, color = { 232, 208, 128 }, shape = "orb" },

	-- Coral Reef -------------------------------------------------------------
	{ id = "clownfish", name = "Clownfish", zone = "reef", rarity = "Common", value = 9, kg = { 0.05, 0.4 }, color = { 244, 138, 54 }, shape = "round" },
	{ id = "parrotfish", name = "Parrotfish", zone = "reef", rarity = "Common", value = 11, kg = { 0.8, 4 }, color = { 92, 198, 168 }, shape = "round" },
	{ id = "angelfish", name = "Emperor Angelfish", zone = "reef", rarity = "Uncommon", value = 18, kg = { 0.4, 2.6 }, color = { 240, 210, 88 }, shape = "flat" },
	{ id = "lionfish", name = "Lionfish", zone = "reef", rarity = "Uncommon", value = 21, kg = { 0.5, 2 }, color = { 226, 112, 120 }, shape = "round" },
	{ id = "reef_shark", name = "Reef Shark", zone = "reef", rarity = "Rare", value = 34, kg = { 20, 70 }, color = { 132, 146, 158 }, shape = "long" },
	{ id = "manta_ray", name = "Manta Ray", zone = "reef", rarity = "Rare", value = 38, kg = { 60, 300 }, color = { 66, 84, 104 }, shape = "flat" },
	{ id = "seahorse_king", name = "Seahorse King", zone = "reef", rarity = "Epic", value = 62, kg = { 0.1, 0.5 }, color = { 248, 172, 196 }, shape = "seahorse" },
	{ id = "coral_crown", name = "Coral Crown", zone = "reef", rarity = "Legendary", value = 140, kg = { 3, 12 }, color = { 255, 132, 148 }, shape = "orb" },
	{ id = "kraken_spawn", name = "Kraken Spawn", zone = "reef", rarity = "Mythic", value = 300, kg = { 80, 400 }, color = { 128, 66, 150 }, shape = "squid" },

	-- Frostbite Lake ---------------------------------------------------------
	{ id = "herring", name = "Frozen Herring", zone = "frost", rarity = "Common", value = 12, kg = { 0.2, 1 }, color = { 186, 202, 214 }, shape = "round" },
	{ id = "arctic_cod", name = "Arctic Cod", zone = "frost", rarity = "Common", value = 14, kg = { 1, 5 }, color = { 154, 170, 182 }, shape = "round" },
	{ id = "char", name = "Arctic Char", zone = "frost", rarity = "Uncommon", value = 24, kg = { 1.5, 8 }, color = { 218, 132, 116 }, shape = "round" },
	{ id = "ice_trout", name = "Ice Trout", zone = "frost", rarity = "Uncommon", value = 27, kg = { 2, 10 }, color = { 168, 206, 226 }, shape = "round" },
	{ id = "glacier_eel", name = "Glacier Eel", zone = "frost", rarity = "Rare", value = 44, kg = { 6, 24 }, color = { 132, 178, 198 }, shape = "long" },
	{ id = "frost_sturgeon", name = "Frost Sturgeon", zone = "frost", rarity = "Rare", value = 47, kg = { 30, 140 }, color = { 116, 140, 156 }, shape = "long" },
	{ id = "permafrost_pike", name = "Permafrost Pike", zone = "frost", rarity = "Epic", value = 78, kg = { 12, 48 }, color = { 190, 222, 238 }, shape = "long" },
	{ id = "wendigo_fin", name = "Wendigo Fin", zone = "frost", rarity = "Legendary", value = 170, kg = { 20, 90 }, color = { 226, 238, 246 }, shape = "flat" },
	{ id = "heart_of_winter", name = "Heart of Winter", zone = "frost", rarity = "Mythic", value = 340, kg = { 0.5, 3 }, color = { 146, 224, 255 }, shape = "orb" },

	-- Volcanic Depths --------------------------------------------------------
	{ id = "ember_minnow", name = "Ember Minnow", zone = "volcano", rarity = "Common", value = 20, kg = { 0.1, 0.8 }, color = { 240, 132, 60 }, shape = "round" },
	{ id = "ashfin", name = "Ashfin", zone = "volcano", rarity = "Common", value = 22, kg = { 1, 6 }, color = { 128, 112, 108 }, shape = "round" },
	{ id = "magma_crab", name = "Magma Crab", zone = "volcano", rarity = "Uncommon", value = 34, kg = { 2, 11 }, color = { 214, 82, 48 }, shape = "crab" },
	{ id = "obsidian_eel", name = "Obsidian Eel", zone = "volcano", rarity = "Uncommon", value = 38, kg = { 5, 22 }, color = { 48, 44, 52 }, shape = "long" },
	{ id = "cinder_ray", name = "Cinder Ray", zone = "volcano", rarity = "Rare", value = 58, kg = { 30, 120 }, color = { 176, 70, 44 }, shape = "flat" },
	{ id = "lava_sturgeon", name = "Lava Sturgeon", zone = "volcano", rarity = "Rare", value = 62, kg = { 45, 200 }, color = { 226, 108, 44 }, shape = "long" },
	{ id = "pyroclast", name = "Pyroclast", zone = "volcano", rarity = "Epic", value = 100, kg = { 15, 70 }, color = { 255, 156, 48 }, shape = "round" },
	{ id = "forge_serpent", name = "Forge Serpent", zone = "volcano", rarity = "Legendary", value = 210, kg = { 90, 420 }, color = { 255, 108, 40 }, shape = "long" },
	{ id = "phoenix_roe", name = "Phoenix Roe", zone = "volcano", rarity = "Mythic", value = 420, kg = { 0.02, 0.2 }, color = { 255, 196, 92 }, shape = "orb" },
	{ id = "molten_core", name = "Molten Core", zone = "volcano", rarity = "Exotic", value = 900, kg = { 5, 30 }, color = { 255, 232, 120 }, shape = "orb" },

	-- The Abyss --------------------------------------------------------------
	{ id = "lanternfish", name = "Lanternfish", zone = "abyss", rarity = "Common", value = 30, kg = { 0.05, 0.5 }, color = { 92, 118, 146 }, shape = "round" },
	{ id = "gulper_eel", name = "Gulper Eel", zone = "abyss", rarity = "Common", value = 32, kg = { 2, 9 }, color = { 54, 60, 82 }, shape = "bulb" },
	{ id = "anglerfish", name = "Anglerfish", zone = "abyss", rarity = "Uncommon", value = 52, kg = { 3, 16 }, color = { 70, 82, 108 }, shape = "bulb" },
	{ id = "viperfish", name = "Viperfish", zone = "abyss", rarity = "Uncommon", value = 55, kg = { 1, 6 }, color = { 86, 96, 128 }, shape = "long" },
	{ id = "bone_ray", name = "Bone Ray", zone = "abyss", rarity = "Rare", value = 82, kg = { 40, 180 }, color = { 206, 204, 190 }, shape = "flat" },
	{ id = "hadal_squid", name = "Hadal Squid", zone = "abyss", rarity = "Rare", value = 88, kg = { 25, 140 }, color = { 128, 90, 160 }, shape = "squid" },
	{ id = "pale_colossus", name = "Pale Colossus", zone = "abyss", rarity = "Epic", value = 140, kg = { 200, 900 }, color = { 222, 220, 226 }, shape = "bulb" },
	{ id = "trench_wyrm", name = "Trench Wyrm", zone = "abyss", rarity = "Legendary", value = 290, kg = { 300, 1400 }, color = { 62, 74, 132 }, shape = "long" },
	{ id = "the_unnamed", name = "The Unnamed", zone = "abyss", rarity = "Mythic", value = 560, kg = { 500, 2600 }, color = { 32, 38, 70 }, shape = "bulb" },
	{ id = "abyssal_eye", name = "Abyssal Eye", zone = "abyss", rarity = "Exotic", value = 1200, kg = { 8, 40 }, color = { 248, 238, 210 }, shape = "orb" },
	{ id = "leviathan_prime", name = "Leviathan Prime", zone = "abyss", rarity = "Secret", value = 3200, kg = { 2000, 9000 }, color = { 24, 200, 196 }, shape = "long" },

	-- Celestial Rift ---------------------------------------------------------
	{ id = "starlet", name = "Starlet", zone = "rift", rarity = "Uncommon", value = 80, kg = { 0.1, 1 }, color = { 244, 240, 200 }, shape = "orb" },
	{ id = "nebula_dart", name = "Nebula Dart", zone = "rift", rarity = "Rare", value = 120, kg = { 1, 8 }, color = { 186, 140, 244 }, shape = "round" },
	{ id = "quasar_ray", name = "Quasar Ray", zone = "rift", rarity = "Epic", value = 200, kg = { 20, 110 }, color = { 140, 190, 255 }, shape = "flat" },
	{ id = "comet_serpent", name = "Comet Serpent", zone = "rift", rarity = "Legendary", value = 400, kg = { 60, 320 }, color = { 210, 226, 255 }, shape = "long" },
	{ id = "astral_whale", name = "Astral Whale", zone = "rift", rarity = "Mythic", value = 780, kg = { 1200, 6000 }, color = { 118, 148, 236 }, shape = "bulb" },
	{ id = "singularity", name = "Singularity", zone = "rift", rarity = "Exotic", value = 1700, kg = { 0.001, 0.01 }, color = { 30, 26, 44 }, shape = "orb" },
	{ id = "god_of_still_water", name = "God of Still Water", zone = "rift", rarity = "Secret", value = 5000, kg = { 8000, 40000 }, color = { 255, 252, 236 }, shape = "bulb" },
}

local Fish = {}

Fish.All = {}
Fish.ById = {}

local poolsByZone = {}
local tiersByZone = {}

for _, entry in ROSTER do
	assert(Fish.ById[entry.id] == nil, string.format("duplicate fish id %q", entry.id))
	Rarities.Get(entry.rarity) -- validates the tier name
	Zones.Get(entry.zone) -- validates the zone id
	assert(SHAPES[entry.shape], string.format("fish %q has unknown shape %q", entry.id, tostring(entry.shape)))

	local record = {
		id = entry.id,
		name = entry.name,
		zone = entry.zone,
		rarity = entry.rarity,
		baseValue = entry.value,
		minWeight = entry.kg[1],
		maxWeight = entry.kg[2],
		color = Color3.fromRGB(entry.color[1], entry.color[2], entry.color[3]),
		shape = entry.shape,
	}

	table.insert(Fish.All, record)
	Fish.ById[entry.id] = record

	local pool = poolsByZone[entry.zone]
	if not pool then
		pool = {}
		poolsByZone[entry.zone] = pool
	end

	local byRarity = pool[entry.rarity]
	if not byRarity then
		byRarity = {}
		pool[entry.rarity] = byRarity
	end
	table.insert(byRarity, record)

	local tiers = tiersByZone[entry.zone]
	if not tiers then
		tiers = {}
		tiersByZone[entry.zone] = tiers
	end
	tiers[entry.rarity] = true
end

-- Every zone must be fishable, or a player can strand themselves in it.
for _, zoneId in Zones.Order do
	assert(poolsByZone[zoneId], string.format("zone %q has no fish", zoneId))
end

function Fish.Get(id: string)
	local record = Fish.ById[id]
	assert(record, string.format("unknown fish %q", tostring(id)))
	return record
end

-- { [rarity] = { fishRecord, ... } } for the zone.
function Fish.PoolFor(zoneId: string)
	local pool = poolsByZone[zoneId]
	assert(pool, string.format("no pool for zone %q", tostring(zoneId)))
	return pool
end

-- Set of rarity tiers actually obtainable in the zone, for honest odds display.
function Fish.TiersFor(zoneId: string): { [string]: boolean }
	local tiers = tiersByZone[zoneId]
	assert(tiers, string.format("no tiers for zone %q", tostring(zoneId)))
	return tiers
end

function Fish.Count(): number
	return #Fish.All
end

function Fish.Shapes(): { [string]: boolean }
	return SHAPES
end

return Fish
