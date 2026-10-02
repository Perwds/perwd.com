--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > ObjectConfig (ModuleScript)

	Every shrinkable object in the game.

	• Id (the table key) must match a model name in ServerStorage > ShrinkableTemplates if you
	  want a real model. If no template exists, the server builds a colored placeholder from
	  Size / Color / Shape so the game is playable immediately.
	• BaseIncome is coins per second BEFORE rarity, variant, and player multipliers.
	• Exclusive = true objects never spawn on the map (rewards / Robux only) and survive Rebirth.
	• FloatHeight lifts the object into the sky (used by the Moon).

	➕ Adding objects without code: tag any Model in Workspace with "Shrinkable" (CollectionService)
	   and give it attributes Tier (number), Rarity (string), BaseIncome (number),
	   optional ObjectId / DisplayName. See README for details.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ObjectConfig = {}

local V = Vector3.new
local C = Color3.fromRGB

ObjectConfig.Objects = {
	-- ── Zone 1 · Grandpa's Backyard ─────────────────────────────────
	SodaCan = { Name = "Soda Can", Tier = 1, Rarity = "Common", BaseIncome = 1, Size = V(1.4, 2.4, 1.4), Color = C(220, 40, 40), Shape = "Cylinder", Emoji = "🥫" },
	TrafficCone = { Name = "Traffic Cone", Tier = 1, Rarity = "Common", BaseIncome = 2, Size = V(2, 3.2, 2), Color = C(255, 120, 20), Shape = "Cylinder", Emoji = "🚧" },
	Mailbox = { Name = "Mailbox", Tier = 1, Rarity = "Uncommon", BaseIncome = 4, Size = V(1.6, 4.2, 2.4), Color = C(40, 80, 200), Shape = "Block", Emoji = "📫" },
	FireHydrant = { Name = "Fire Hydrant", Tier = 1, Rarity = "Rare", BaseIncome = 6, Size = V(1.8, 3.4, 1.8), Color = C(230, 30, 30), Shape = "Cylinder", Emoji = "🧯" },
	GardenGnome = { Name = "Garden Gnome", Tier = 1, Rarity = "Epic", BaseIncome = 14, Size = V(1.8, 3, 1.8), Color = C(60, 160, 60), Shape = "Block", Emoji = "🧙" },

	-- ── Zone 2 · Neighborhood ───────────────────────────────────────
	Bench = { Name = "Bench", Tier = 2, Rarity = "Common", BaseIncome = 25, Size = V(7, 3.5, 2.5), Color = C(140, 90, 50), Shape = "Block", Emoji = "🛋️" },
	TrashBin = { Name = "Trash Bin", Tier = 2, Rarity = "Common", BaseIncome = 30, Size = V(3, 4.5, 3), Color = C(70, 110, 70), Shape = "Cylinder", Emoji = "🗑️" },
	Bike = { Name = "Bike", Tier = 2, Rarity = "Uncommon", BaseIncome = 40, Size = V(1.5, 4, 6), Color = C(30, 170, 220), Shape = "Block", Emoji = "🚲" },
	VendingMachine = { Name = "Vending Machine", Tier = 2, Rarity = "Rare", BaseIncome = 90, Size = V(4, 7, 3), Color = C(220, 30, 90), Shape = "Block", Emoji = "🥤" },
	ArcadeCabinet = { Name = "Arcade Cabinet", Tier = 2, Rarity = "Epic", BaseIncome = 200, Size = V(3.5, 7, 3.5), Color = C(120, 40, 220), Shape = "Block", Emoji = "🕹️" },

	-- ── Zone 3 · Downtown ───────────────────────────────────────────
	Car = { Name = "Car", Tier = 3, Rarity = "Common", BaseIncome = 600, Size = V(7, 5, 14), Color = C(40, 120, 230), Shape = "Block", Emoji = "🚗" },
	Tree = { Name = "Tree", Tier = 3, Rarity = "Common", BaseIncome = 500, Size = V(10, 18, 10), Color = C(50, 150, 60), Shape = "Ball", Emoji = "🌳" },
	FoodTruck = { Name = "Food Truck", Tier = 3, Rarity = "Uncommon", BaseIncome = 1_000, Size = V(8, 10, 18), Color = C(255, 210, 60), Shape = "Block", Emoji = "🚚" },
	Statue = { Name = "Statue", Tier = 3, Rarity = "Rare", BaseIncome = 2_500, Size = V(6, 16, 6), Color = C(170, 170, 160), Shape = "Block", Emoji = "🗿" },
	SportsCar = { Name = "Sports Car", Tier = 3, Rarity = "Epic", BaseIncome = 6_000, Size = V(7, 4, 15), Color = C(255, 40, 40), Shape = "Block", Emoji = "🏎️" },

	-- ── Zone 4 · Harbor ─────────────────────────────────────────────
	House = { Name = "House", Tier = 4, Rarity = "Common", BaseIncome = 15_000, Size = V(20, 16, 20), Color = C(230, 200, 160), Shape = "Block", Emoji = "🏠" },
	Bus = { Name = "Bus", Tier = 4, Rarity = "Common", BaseIncome = 20_000, Size = V(8, 10, 26), Color = C(255, 200, 30), Shape = "Block", Emoji = "🚌" },
	Windmill = { Name = "Windmill", Tier = 4, Rarity = "Uncommon", BaseIncome = 35_000, Size = V(10, 28, 10), Color = C(240, 240, 240), Shape = "Cylinder", Emoji = "🌬️" },
	Boat = { Name = "Boat", Tier = 4, Rarity = "Rare", BaseIncome = 50_000, Size = V(10, 10, 24), Color = C(250, 250, 250), Shape = "Block", Emoji = "⛵" },
	Lighthouse = { Name = "Lighthouse", Tier = 4, Rarity = "Epic", BaseIncome = 120_000, Size = V(9, 32, 9), Color = C(230, 60, 60), Shape = "Cylinder", Emoji = "🗼" },

	-- ── Zone 5 · Desert ─────────────────────────────────────────────
	Cactus = { Name = "Cactus", Tier = 5, Rarity = "Common", BaseIncome = 250_000, Size = V(6, 12, 4), Color = C(80, 160, 70), Shape = "Block", Emoji = "🌵" },
	Tumbleweed = { Name = "Tumbleweed", Tier = 5, Rarity = "Uncommon", BaseIncome = 380_000, Size = V(6, 6, 6), Color = C(170, 130, 80), Shape = "Ball", Emoji = "🌾" },
	OilPump = { Name = "Oil Pump", Tier = 5, Rarity = "Rare", BaseIncome = 700_000, Size = V(6, 12, 16), Color = C(60, 60, 70), Shape = "Block", Emoji = "🛢️" },
	Pyramid = { Name = "Pyramid", Tier = 5, Rarity = "Legendary", BaseIncome = 2_000_000, Size = V(30, 20, 30), Color = C(230, 200, 120), Shape = "Block", Emoji = "🔺" },

	-- ── Zone 6 · Jungle ─────────────────────────────────────────────
	PalmTree = { Name = "Palm Tree", Tier = 6, Rarity = "Common", BaseIncome = 3_500_000, Size = V(10, 20, 10), Color = C(70, 170, 70), Shape = "Block", Emoji = "🌴" },
	TikiStatue = { Name = "Tiki Statue", Tier = 6, Rarity = "Rare", BaseIncome = 7_000_000, Size = V(6, 14, 6), Color = C(150, 100, 60), Shape = "Block", Emoji = "🗿" },
	Treehouse = { Name = "Treehouse", Tier = 6, Rarity = "Epic", BaseIncome = 15_000_000, Size = V(16, 24, 16), Color = C(140, 95, 55), Shape = "Block", Emoji = "🏡" },

	-- ── Zone 7 · Skyline ────────────────────────────────────────────
	Skyscraper = { Name = "Skyscraper", Tier = 7, Rarity = "Common", BaseIncome = 25_000_000, Size = V(16, 50, 16), Color = C(110, 150, 190), Shape = "Block", Emoji = "🏙️" },
	FerrisWheel = { Name = "Ferris Wheel", Tier = 7, Rarity = "Rare", BaseIncome = 45_000_000, Size = V(6, 40, 40), Color = C(255, 100, 180), Shape = "Cylinder", Emoji = "🎡" },
	CruiseShip = { Name = "Cruise Ship", Tier = 7, Rarity = "Epic", BaseIncome = 80_000_000, Size = V(16, 18, 46), Color = C(245, 245, 255), Shape = "Block", Emoji = "🛳️" },
	Rocket = { Name = "Rocket", Tier = 7, Rarity = "Legendary", BaseIncome = 180_000_000, Size = V(9, 44, 9), Color = C(230, 230, 240), Shape = "Cylinder", Emoji = "🚀" },

	-- ── Zone 8 · Volcano ────────────────────────────────────────────
	LavaRock = { Name = "Lava Rock", Tier = 8, Rarity = "Common", BaseIncome = 300_000_000, Size = V(12, 9, 12), Color = C(60, 40, 35), Shape = "Ball", Emoji = "🌑" },
	MagmaCrystal = { Name = "Magma Crystal", Tier = 8, Rarity = "Rare", BaseIncome = 650_000_000, Size = V(8, 16, 8), Color = C(255, 90, 30), Shape = "Block", Emoji = "🔥" },
	Volcano = { Name = "Volcano", Tier = 8, Rarity = "Legendary", BaseIncome = 1_500_000_000, Size = V(44, 36, 44), Color = C(90, 40, 30), Shape = "Ball", Emoji = "🌋" },

	-- ── Zone 9 · Summit ─────────────────────────────────────────────
	SnowCastle = { Name = "Snow Castle", Tier = 9, Rarity = "Uncommon", BaseIncome = 2_500_000_000, Size = V(24, 20, 24), Color = C(235, 245, 255), Shape = "Block", Emoji = "🏰" },
	Mountain = { Name = "Mountain", Tier = 9, Rarity = "Epic", BaseIncome = 5_000_000_000, Size = V(46, 40, 46), Color = C(120, 110, 100), Shape = "Ball", Emoji = "⛰️" },
	Glacier = { Name = "Glacier", Tier = 9, Rarity = "Mythic", BaseIncome = 12_000_000_000, Size = V(42, 28, 36), Color = C(170, 230, 255), Shape = "Block", Emoji = "❄️" },

	-- ── Zone 10 · Outer Space ───────────────────────────────────────
	Satellite = { Name = "Satellite", Tier = 10, Rarity = "Common", BaseIncome = 20_000_000_000, Size = V(20, 10, 8), Color = C(200, 200, 215), Shape = "Block", Emoji = "🛰️" },
	UFO = { Name = "UFO", Tier = 10, Rarity = "Rare", BaseIncome = 45_000_000_000, Size = V(20, 9, 20), Color = C(170, 180, 200), Shape = "Cylinder", Emoji = "🛸" },
	SpaceStation = { Name = "Space Station", Tier = 10, Rarity = "Legendary", BaseIncome = 120_000_000_000, Size = V(30, 14, 30), Color = C(220, 225, 235), Shape = "Block", Emoji = "🚉" },
	TheMoon = { Name = "The Moon", Tier = 10, Rarity = "Secret", BaseIncome = 900_000_000_000, Size = V(36, 36, 36), Color = C(220, 220, 210), Shape = "Ball", Emoji = "🌕" },

	-- ── Exclusives (never spawn; rewards & Robux only, kept through Rebirth) ──
	HugeTeddy = { Name = "Huge Teddy", Tier = 1, Rarity = "Mythic", BaseIncome = 50_000, Size = V(6, 7, 5), Color = C(190, 130, 80), Shape = "Ball", Exclusive = true, Emoji = "🧸" },
	HugeCrystal = { Name = "Huge Crystal", Tier = 1, Rarity = "Mythic", BaseIncome = 250_000, Size = V(4, 8, 4), Color = C(120, 255, 240), Shape = "Block", Exclusive = true, Emoji = "💎" },
	HugeDragon = { Name = "Huge Dragon", Tier = 1, Rarity = "Secret", BaseIncome = 2_000_000, Size = V(8, 7, 12), Color = C(60, 200, 90), Shape = "Block", Exclusive = true, Emoji = "🐉" },

	-- ── Robux-crate exclusives (only from the Royal Crate in the Shop) ──
	KingDuck = { Name = "King Duck", Tier = 1, Rarity = "Legendary", BaseIncome = 150_000, Size = V(4, 4.5, 4), Color = C(255, 215, 40), Shape = "Ball", Exclusive = true, Crate = true, Emoji = "🦆" },
	GoldenToilet = { Name = "Golden Toilet", Tier = 1, Rarity = "Legendary", BaseIncome = 300_000, Size = V(3.5, 5, 5), Color = C(255, 200, 40), Shape = "Block", Exclusive = true, Crate = true, Emoji = "🚽" },
	NeonUnicorn = { Name = "Neon Unicorn", Tier = 1, Rarity = "Mythic", BaseIncome = 900_000, Size = V(3, 6, 7), Color = C(255, 110, 220), Shape = "Block", Exclusive = true, Crate = true, Emoji = "🦄" },
	DragonEgg = { Name = "Dragon Egg", Tier = 1, Rarity = "Mythic", BaseIncome = 2_500_000, Size = V(4, 5.5, 4), Color = C(120, 40, 200), Shape = "Ball", Exclusive = true, Crate = true, Emoji = "🥚" },
	GalaxyOrb = { Name = "Galaxy Orb", Tier = 1, Rarity = "Secret", BaseIncome = 10_000_000, Size = V(5, 6, 5), Color = C(90, 40, 220), Shape = "Ball", Exclusive = true, Crate = true, Emoji = "🔮" },
}

-- ── Lookup helpers (handle runtime-registered custom objects too) ─────
local customCache = {}

local function customFolder()
	return ReplicatedStorage:FindFirstChild("CustomObjects")
end

function ObjectConfig.Get(id)
	if type(id) ~= "string" then
		return nil
	end
	local def = ObjectConfig.Objects[id]
	if def then
		return def
	end
	if customCache[id] then
		return customCache[id]
	end
	local folder = customFolder()
	local entry = folder and folder:FindFirstChild(id)
	if entry then
		def = {
			Name = entry:GetAttribute("DisplayName") or id,
			Tier = entry:GetAttribute("Tier") or 1,
			Rarity = entry:GetAttribute("Rarity") or "Common",
			BaseIncome = entry:GetAttribute("BaseIncome") or 1,
			Emoji = entry:GetAttribute("Emoji") or "📦",
			Custom = true,
		}
		customCache[id] = def
		return def
	end
	return nil
end

-- All ids (static + custom), sorted by tier, then income.
function ObjectConfig.AllIds()
	local ids = {}
	for id in pairs(ObjectConfig.Objects) do
		table.insert(ids, id)
	end
	local folder = customFolder()
	if folder then
		for _, entry in ipairs(folder:GetChildren()) do
			if not ObjectConfig.Objects[entry.Name] then
				table.insert(ids, entry.Name)
			end
		end
	end
	table.sort(ids, function(a, b)
		local da, db = ObjectConfig.Get(a), ObjectConfig.Get(b)
		if da.Tier ~= db.Tier then
			return da.Tier < db.Tier
		end
		if (da.Exclusive and 1 or 0) ~= (db.Exclusive and 1 or 0) then
			return not da.Exclusive
		end
		if da.BaseIncome ~= db.BaseIncome then
			return da.BaseIncome < db.BaseIncome
		end
		return a < b
	end)
	return ids
end

-- Map-spawnable ids for one tier.
function ObjectConfig.IdsForTier(tier, includeExclusive)
	local out = {}
	for _, id in ipairs(ObjectConfig.AllIds()) do
		local def = ObjectConfig.Get(id)
		if def.Tier == tier and (includeExclusive or not def.Exclusive) then
			table.insert(out, id)
		end
	end
	return out
end

return ObjectConfig
