--!strict
-- Tuning numbers and owner-filled IDs. Kept free of Roblox types so tools/simulate.lua can load it under Lune.

local Config = {}

Config.Grid = {
	cell = 16, -- studs per grid cell; UpgradeTree gx/gy are in cells
	zoneCells = 12,
	zonesWide = 3,
	zonesHigh = 2,
	plateWidth = 12,
	plateDepth = 8,
	plateTilt = 12, -- degrees, far edge raised so text faces the player
	boardThickness = 4,
}

-- Zone placement on the board, in zone units (each zone is zoneCells x zoneCells).
Config.Zones = {
	orange = { zx = 1, zy = 1, unlock = nil, title = "Orange Grove" },
	vitamin = { zx = 0, zy = 1, unlock = "labOpen", title = "Vitamin Lab" },
	zest = { zx = 0, zy = 0, unlock = "zesterOpen", title = "Zest Works" },
	juice = { zx = 1, zy = 0, unlock = "juiceOpen", title = "Juice Bar" },
	golden = { zx = 2, zy = 0, unlock = "goldenOpen", title = "Golden Tree" },
	vip = { zx = 2, zy = 1, unlock = "vip", title = "Back Orchard" },
}
Config.ZoneOrder = { "orange", "vitamin", "zest", "juice", "golden", "vip" }

Config.Currencies = {
	{ id = "oranges", name = "Oranges", unit = "", zone = "orange", unlock = nil },
	{ id = "vitamin", name = "Vitamin C", unit = "mg", zone = "vitamin", unlock = "labOpen" },
	{ id = "zest", name = "Zest", unit = "", zone = "zest", unlock = "zesterOpen" },
	{ id = "crates", name = "Juice Crates", unit = "", zone = "juice", unlock = "juiceOpen" },
	{ id = "seeds", name = "Golden Seeds", unit = "", zone = "golden", unlock = "goldenOpen" },
}

-- Starting stats before any upgrade. Upgrade effects in UpgradeTree modify these by name.
Config.Base = {
	pickFlat = 1,
	pickMult = 1,
	orangeMult = 1,
	treeCapacity = 3,
	ripenSpeed = 1,
	pickers = 0,
	freePickers = 0,
	pickerSpeed = 1,
	collectRange = 0,
	walkBonus = 0,
	labSpeed = 0.25, -- batches per second
	labYield = 1, -- mg per batch
	labCost = 25, -- oranges per batch
	peelPerBatch = 1,
	zesterSpeed = 0.3, -- peels per second
	zestYield = 1,
	juiceSpeed = 0.04, -- batches per second
	juiceYield = 1,
	juiceOrangeCost = 200,
	juiceVitCost = 5,
	prodMult = 1, -- Vitamin C, Zest and crates
	offlineHours = 0,
	seedMult = 1,
	startOranges = 0,
	labOpen = false,
	zesterOpen = false,
	juiceOpen = false,
	goldenOpen = false,
}

Config.Grove = {
	ripenSeconds = 7,
	pickRange = 18, -- studs from the character to the trunk
	plateRange = 24, -- server-side slack over the 20 stud click range
	picksPerSecond = 12,
	pickBurst = 6,
	buysPerSecond = 10,
	vipTreeBonus = 1.5,
	autoPickerRange = 30,
	pickerPicksPerSecond = 0.5,
}

-- Orange tree cells. The sim counts these to estimate how fast a player can pick.
Config.Orchard = {
	{ 13, 20 },
	{ 15, 20 },
	{ 17, 20 },
	{ 19, 20 },
	{ 13, 22 },
	{ 15, 22 },
	{ 17, 22 },
	{ 19, 22 },
}
Config.VipOrchard = {
	{ 27, 15 },
	{ 29, 15 },
	{ 31, 15 },
	{ 33, 15 },
	{ 27, 17 },
	{ 29, 17 },
	{ 31, 17 },
	{ 33, 17 },
}

Config.Prestige = {
	crateDivisor = 50,
	minSeeds = 1,
}

Config.Offline = {
	minSeconds = 60, -- shorter absences are not worth a popup
	steps = 240,
}

Config.Save = {
	storeName = "OrangeGrove_Profiles_v1",
	autosaveSeconds = 60,
	lockStaleSeconds = 150, -- a lock older than this is treated as abandoned
	loadRetries = 6,
	keepPurchaseIds = 60,
}

Config.Walk = {
	baseSpeed = 16,
}

-- NPC looks. Fill in real Roblox user IDs (their avatar is copied), or real catalog asset IDs.
-- Leave everything empty and NPCs use the default Roblox avatar, with one warning in the output.
Config.Npc = {
	keeperName = "Ruth",
	keeperUserId = 0,
	juiceWorkerName = "Dev",
	juiceWorkerUserId = 0,
	farmhandUserIds = {} :: { number },
	-- Each outfit: { Shirt = id, Pants = id, Face = id, HairAccessory = "id,id", HatAccessory = "id" }
	-- Only use IDs copied from the Roblox catalog.
	outfits = {} :: { { [string]: any } },
	maxPickerNpcs = 12,
	eatChance = 0.12,
	walkSpeed = 10,
}

-- The stock R15 animations from Roblox's default Animate script.
Config.Animations = {
	idle = "rbxassetid://507766666",
	idleAlt = "rbxassetid://507766951",
	walk = "rbxassetid://507777826",
	reach = "rbxassetid://507770453", -- point, used for picking
	carry = "rbxassetid://507768375", -- toolnone, arm out holding the basket
	wave = "rbxassetid://507770239",
	cheer = "rbxassetid://507770677",
}

-- Sound IDs from Roblox's free audio library (Creator Store, "Roblox" as creator). 0 means silent.
Config.Sounds = {
	music = 0,
	pop = 0,
	chime = 0,
	deny = 0,
	replant = 0,
	musicVolume = 0.35,
	popVolume = 0.5,
}

-- Flat single-colour icons. Upload them and paste the IDs here; until then a plain shape is drawn.
Config.Icons = {
	oranges = "",
	vitamin = "",
	zest = "",
	crates = "",
	seeds = "",
	map = "",
	shop = "",
	settings = "",
}

Config.Dialogue = {
	orange = "Morning. The bright ones are ripe, go grab a few.",
	vitamin = "The Lab's open. It eats 25 oranges a batch, so keep those trees busy.",
	zest = "Don't bin the peels. The Zester turns them into Zest.",
	juice = "Juice Bar's running. It needs oranges and Vitamin C, so watch both.",
	golden = "That's the Golden Tree. Replant when you're ready, the gold-ringed plates stay with you.",
	vip = "Welcome to the back orchard. Trees out here give a little extra.",
}

Config.Tutorial = {
	{ id = "pick", text = "Click a bright orange to pick it.", touchText = "Tap a bright orange to pick it." },
	{
		id = "seed",
		text = "Buy the Orange Seed plate. Walk up and press E.",
		touchText = "Buy the Orange Seed plate. Walk up and tap.",
	},
	{ id = "riper", text = "Riper Oranges is next. Keep picking." },
	{ id = "picker", text = "Hire a Picker. They work while you don't." },
	{ id = "openlab", text = "Save up and open the Lab." },
}

return Config
