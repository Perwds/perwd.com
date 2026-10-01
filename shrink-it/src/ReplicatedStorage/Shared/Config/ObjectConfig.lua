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
	-- ── Tier 1 · Tiny · Suburbs ──────────────────────────────────────
	SodaCan = { Name = "Soda Can", Tier = 1, Rarity = "Common", BaseIncome = 1, Size = V(1.4, 2.4, 1.4), Color = C(220, 40, 40), Shape = "Cylinder", Emoji = "🥫" },
	TrafficCone = { Name = "Traffic Cone", Tier = 1, Rarity = "Common", BaseIncome = 2, Size = V(2, 3.2, 2), Color = C(255, 120, 20), Shape = "Cylinder", Emoji = "🚧" },
	Mailbox = { Name = "Mailbox", Tier = 1, Rarity = "Uncommon", BaseIncome = 4, Size = V(1.6, 4.2, 2.4), Color = C(40, 80, 200), Shape = "Block", Emoji = "📫" },
	FireHydrant = { Name = "Fire Hydrant", Tier = 1, Rarity = "Uncommon", BaseIncome = 5, Size = V(1.8, 3.4, 1.8), Color = C(230, 30, 30), Shape = "Cylinder", Emoji = "🧯" },
	GardenGnome = { Name = "Garden Gnome", Tier = 1, Rarity = "Rare", BaseIncome = 12, Size = V(1.8, 3, 1.8), Color = C(60, 160, 60), Shape = "Block", Emoji = "🧙" },

	-- ── Tier 2 · Small · Park ───────────────────────────────────────
	Bench = { Name = "Bench", Tier = 2, Rarity = "Common", BaseIncome = 25, Size = V(7, 3.5, 2.5), Color = C(140, 90, 50), Shape = "Block", Emoji = "🛋️" },
	TrashBin = { Name = "Trash Bin", Tier = 2, Rarity = "Common", BaseIncome = 30, Size = V(3, 4.5, 3), Color = C(70, 110, 70), Shape = "Cylinder", Emoji = "🗑️" },
	Bike = { Name = "Bike", Tier = 2, Rarity = "Uncommon", BaseIncome = 40, Size = V(1.5, 4, 6), Color = C(30, 170, 220), Shape = "Block", Emoji = "🚲" },
	VendingMachine = { Name = "Vending Machine", Tier = 2, Rarity = "Rare", BaseIncome = 90, Size = V(4, 7, 3), Color = C(220, 30, 90), Shape = "Block", Emoji = "🥤" },
	ArcadeCabinet = { Name = "Arcade Cabinet", Tier = 2, Rarity = "Epic", BaseIncome = 200, Size = V(3.5, 7, 3.5), Color = C(120, 40, 220), Shape = "Block", Emoji = "🕹️" },

	-- ── Tier 3 · Medium · Downtown ──────────────────────────────────
	Car = { Name = "Car", Tier = 3, Rarity = "Common", BaseIncome = 600, Size = V(7, 5, 14), Color = C(40, 120, 230), Shape = "Block", Emoji = "🚗" },
	Tree = { Name = "Tree", Tier = 3, Rarity = "Common", BaseIncome = 500, Size = V(10, 18, 10), Color = C(50, 150, 60), Shape = "Ball", Emoji = "🌳" },
	FoodTruck = { Name = "Food Truck", Tier = 3, Rarity = "Uncommon", BaseIncome = 1_000, Size = V(8, 10, 18), Color = C(255, 210, 60), Shape = "Block", Emoji = "🚚" },
	Statue = { Name = "Statue", Tier = 3, Rarity = "Rare", BaseIncome = 2_500, Size = V(6, 16, 6), Color = C(170, 170, 160), Shape = "Block", Emoji = "🗿" },
	SportsCar = { Name = "Sports Car", Tier = 3, Rarity = "Epic", BaseIncome = 6_000, Size = V(7, 4, 15), Color = C(255, 40, 40), Shape = "Block", Emoji = "🏎️" },

	-- ── Tier 4 · Large · Harbor ─────────────────────────────────────
	House = { Name = "House", Tier = 4, Rarity = "Common", BaseIncome = 15_000, Size = V(24, 20, 24), Color = C(230, 200, 160), Shape = "Block", Emoji = "🏠" },
	Bus = { Name = "Bus", Tier = 4, Rarity = "Common", BaseIncome = 20_000, Size = V(9, 11, 32), Color = C(255, 200, 30), Shape = "Block", Emoji = "🚌" },
	Windmill = { Name = "Windmill", Tier = 4, Rarity = "Uncommon", BaseIncome = 35_000, Size = V(12, 34, 12), Color = C(240, 240, 240), Shape = "Cylinder", Emoji = "🌬️" },
	Boat = { Name = "Boat", Tier = 4, Rarity = "Rare", BaseIncome = 50_000, Size = V(12, 12, 30), Color = C(250, 250, 250), Shape = "Block", Emoji = "⛵" },
	Lighthouse = { Name = "Lighthouse", Tier = 4, Rarity = "Epic", BaseIncome = 120_000, Size = V(10, 40, 10), Color = C(230, 60, 60), Shape = "Cylinder", Emoji = "🗼" },

	-- ── Tier 5 · Huge · Skyline ─────────────────────────────────────
	Skyscraper = { Name = "Skyscraper", Tier = 5, Rarity = "Common", BaseIncome = 400_000, Size = V(22, 70, 22), Color = C(110, 150, 190), Shape = "Block", Emoji = "🏙️" },
	FerrisWheel = { Name = "Ferris Wheel", Tier = 5, Rarity = "Rare", BaseIncome = 700_000, Size = V(8, 55, 55), Color = C(255, 100, 180), Shape = "Cylinder", Emoji = "🎡" },
	CruiseShip = { Name = "Cruise Ship", Tier = 5, Rarity = "Epic", BaseIncome = 1_200_000, Size = V(22, 26, 70), Color = C(245, 245, 255), Shape = "Block", Emoji = "🛳️" },
	Rocket = { Name = "Rocket", Tier = 5, Rarity = "Legendary", BaseIncome = 3_000_000, Size = V(12, 60, 12), Color = C(230, 230, 240), Shape = "Cylinder", Emoji = "🚀" },

	-- ── Tier 6 · Colossal · Summit ──────────────────────────────────
	Mountain = { Name = "Mountain", Tier = 6, Rarity = "Epic", BaseIncome = 10_000_000, Size = V(85, 70, 85), Color = C(120, 110, 100), Shape = "Ball", Emoji = "⛰️" },
	Volcano = { Name = "Volcano", Tier = 6, Rarity = "Legendary", BaseIncome = 25_000_000, Size = V(80, 65, 80), Color = C(90, 40, 30), Shape = "Ball", Emoji = "🌋" },
	Glacier = { Name = "Glacier", Tier = 6, Rarity = "Mythic", BaseIncome = 80_000_000, Size = V(80, 45, 70), Color = C(170, 230, 255), Shape = "Block", Emoji = "❄️" },
	TheMoon = { Name = "The Moon", Tier = 6, Rarity = "Secret", BaseIncome = 500_000_000, Size = V(60, 60, 60), Color = C(220, 220, 210), Shape = "Ball", FloatHeight = 70, Emoji = "🌕" },

	-- ── Exclusives (never spawn; rewards & Robux only, kept through Rebirth) ──
	HugeTeddy = { Name = "Huge Teddy", Tier = 1, Rarity = "Mythic", BaseIncome = 50_000, Size = V(6, 7, 5), Color = C(190, 130, 80), Shape = "Ball", Exclusive = true, Emoji = "🧸" },
	HugeCrystal = { Name = "Huge Crystal", Tier = 1, Rarity = "Mythic", BaseIncome = 250_000, Size = V(4, 8, 4), Color = C(120, 255, 240), Shape = "Block", Exclusive = true, Emoji = "💎" },
	HugeDragon = { Name = "Huge Dragon", Tier = 1, Rarity = "Secret", BaseIncome = 2_000_000, Size = V(8, 7, 12), Color = C(60, 200, 90), Shape = "Block", Exclusive = true, Emoji = "🐉" },
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
