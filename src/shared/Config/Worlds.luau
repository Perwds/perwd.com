--[[
	Worlds (zones). Each world owns one egg, eight pets, and a patch of map.
	`unlockCost` is paid once in cash to open the gate to that zone.

	13 worlds x 8 pets = the 104 slots the Pet Index counts.
]]

local Worlds = {}

Worlds.Order = {
	"Forest",
	"Desert",
	"Ocean",
	"Tundra",
	"Volcano",
	"Jungle",
	"Sky",
	"Candy",
	"Space",
	"Haunted",
	"Crystal",
	"Cyber",
	"Mythic",
}

--[[
	incomeBase  cash/sec granted by a Common pet from this world
	eggCost     cash price of one egg at the world's hatch pad
	hatchTime   seconds the egg sits on your pad before it opens
	unlockCost  cash to open the zone gate (0 = open from spawn)
	spawnEvery  seconds between wild egg spawns on this world's pedestals
	pedestals   how many pedestals the world builds
]]
Worlds.Info = {
	Forest = { display = "Forest", incomeBase = 1, eggCost = 100, hatchTime = 45, unlockCost = 0,
		spawnEvery = 14, pedestals = 6, ground = Color3.fromRGB(86, 171, 74), accent = Color3.fromRGB(56, 130, 48) },
	Desert = { display = "Desert", incomeBase = 4, eggCost = 750, hatchTime = 70, unlockCost = 2500,
		spawnEvery = 16, pedestals = 6, ground = Color3.fromRGB(222, 196, 124), accent = Color3.fromRGB(190, 158, 86) },
	Ocean = { display = "Ocean", incomeBase = 16, eggCost = 5000, hatchTime = 100, unlockCost = 20000,
		spawnEvery = 18, pedestals = 6, ground = Color3.fromRGB(70, 150, 205), accent = Color3.fromRGB(42, 108, 160) },
	Tundra = { display = "Tundra", incomeBase = 62, eggCost = 32000, hatchTime = 135, unlockCost = 140000,
		spawnEvery = 20, pedestals = 6, ground = Color3.fromRGB(216, 232, 244), accent = Color3.fromRGB(160, 194, 220) },
	Volcano = { display = "Volcano", incomeBase = 240, eggCost = 210000, hatchTime = 175, unlockCost = 900000,
		spawnEvery = 22, pedestals = 6, ground = Color3.fromRGB(96, 52, 48), accent = Color3.fromRGB(198, 74, 36) },
	Jungle = { display = "Jungle", incomeBase = 930, eggCost = 1.3e6, hatchTime = 220, unlockCost = 5.6e6,
		spawnEvery = 24, pedestals = 6, ground = Color3.fromRGB(46, 120, 62), accent = Color3.fromRGB(28, 82, 44) },
	Sky = { display = "Sky", incomeBase = 3600, eggCost = 8.2e6, hatchTime = 270, unlockCost = 35e6,
		spawnEvery = 26, pedestals = 6, ground = Color3.fromRGB(196, 224, 248), accent = Color3.fromRGB(136, 180, 232) },
	Candy = { display = "Candy", incomeBase = 14000, eggCost = 52e6, hatchTime = 325, unlockCost = 220e6,
		spawnEvery = 28, pedestals = 6, ground = Color3.fromRGB(248, 168, 210), accent = Color3.fromRGB(226, 104, 164) },
	Space = { display = "Space", incomeBase = 54000, eggCost = 330e6, hatchTime = 385, unlockCost = 1.4e9,
		spawnEvery = 30, pedestals = 6, ground = Color3.fromRGB(38, 34, 62), accent = Color3.fromRGB(96, 78, 176) },
	Haunted = { display = "Haunted", incomeBase = 210000, eggCost = 2.1e9, hatchTime = 450, unlockCost = 8.8e9,
		spawnEvery = 32, pedestals = 6, ground = Color3.fromRGB(58, 50, 66), accent = Color3.fromRGB(120, 210, 130) },
	Crystal = { display = "Crystal", incomeBase = 820000, eggCost = 13e9, hatchTime = 520, unlockCost = 56e9,
		spawnEvery = 34, pedestals = 6, ground = Color3.fromRGB(150, 216, 232), accent = Color3.fromRGB(86, 172, 208) },
	Cyber = { display = "Cyber", incomeBase = 3.2e6, eggCost = 84e9, hatchTime = 600, unlockCost = 360e9,
		spawnEvery = 36, pedestals = 6, ground = Color3.fromRGB(26, 30, 44), accent = Color3.fromRGB(0, 224, 200) },
	Mythic = { display = "Mythic", incomeBase = 12.5e6, eggCost = 540e9, hatchTime = 720, unlockCost = 2.3e12,
		spawnEvery = 40, pedestals = 6, ground = Color3.fromRGB(240, 226, 176), accent = Color3.fromRGB(226, 172, 62) },
}

Worlds.Index = {}
for i, name in Worlds.Order do
	Worlds.Index[name] = i
	Worlds.Info[name].id = name
	Worlds.Info[name].order = i
end

function Worlds.get(name: string)
	return Worlds.Info[name]
end

--- The world a player must already own before `name` can be unlocked.
function Worlds.previous(name: string): string?
	local i = Worlds.Index[name]
	if not i or i <= 1 then
		return nil
	end
	return Worlds.Order[i - 1]
end

return Worlds
