--[[
	================== UGC REGISTRY ==================

	This is the only file you need to edit when your UGC items are ready.
	Everything else -- unlock tracking, the claim prompt, the UGC shop tab,
	ownership checks, saving -- reads from this table.

	To add an item:

		1. Publish the UGC item on Roblox and copy its catalog asset id
		   (the number in roblox.com/catalog/<ID>/name).
		2. Add an entry below with that id in `assetId`.
		3. Pick how it is earned with `source` (see the five kinds below).
		4. Done. It appears in the UGC tab and the unlock fires itself.

	Entries with `assetId = 0` are treated as PLACEHOLDERS: they still show
	up and still unlock, but claiming them tells the player the item is not
	live yet instead of opening a broken purchase prompt. That means you can
	ship and playtest the whole loop today and fill in ids later.

	---------------------------------------------------------------
	source      what earns it                  extra fields
	---------------------------------------------------------------
	"hatch"     hatching a specific pet        set `ugcId` on that pet in
	                                           Pets.luau to this entry's id
	"index"     Pet Index completion           `world` = a world name, or
	                                           "All" for the full 104
	"playtime"  time played, in seconds        `seconds`
	"daily"     consecutive login days         `days`
	"shop"      bought with in-game cash       `price`
	---------------------------------------------------------------

	grantMode controls what "claim" does once an item is unlocked:
	  "prompt"  -> MarketplaceService:PromptPurchase for the asset. This is
	               the right mode for free (0 Robux) UGC you own. The server
	               verifies ownership afterwards before marking it claimed.
	  "record"  -> only record the unlock. Use for items you hand out
	               manually or through an off-platform flow.
]]

local Ugc = {}

Ugc.Sources = { HATCH = "hatch", INDEX = "index", PLAYTIME = "playtime", DAILY = "daily", SHOP = "shop" }

Ugc.List = {
	-- ============ RARE EGG DROP ============
	-- Linked from Pets.luau -> limited_skeletal_raptor.ugcId
	{
		id = "skeletal_crown",
		name = "Skeletal Crown",
		description = "Hatch the Skeletal Raptor from the Extinction Egg.",
		assetId = 0, -- << your UGC catalog id
		assetType = "Asset",
		rarity = "Secret",
		source = Ugc.Sources.HATCH,
		grantMode = "prompt",
	},

	-- ============ PET INDEX COMPLETION ============
	{
		id = "forest_wreath",
		name = "Forest Wreath",
		description = "Unlock all 8 Forest pets.",
		assetId = 0,
		assetType = "Asset",
		rarity = "Rare",
		source = Ugc.Sources.INDEX,
		world = "Forest",
		grantMode = "prompt",
	},
	{
		id = "volcano_horns",
		name = "Volcano Horns",
		description = "Unlock all 8 Volcano pets.",
		assetId = 0,
		assetType = "Asset",
		rarity = "Epic",
		source = Ugc.Sources.INDEX,
		world = "Volcano",
		grantMode = "prompt",
	},
	{
		id = "index_master_halo",
		name = "Index Master Halo",
		description = "Unlock all 104 pets.",
		assetId = 0,
		assetType = "Asset",
		rarity = "Secret",
		source = Ugc.Sources.INDEX,
		world = "All",
		grantMode = "prompt",
	},

	-- ============ PLAYTIME ============
	{
		id = "rookie_cap",
		name = "Rookie Cap",
		description = "Play for 15 minutes.",
		assetId = 0,
		assetType = "Asset",
		rarity = "Uncommon",
		source = Ugc.Sources.PLAYTIME,
		seconds = 15 * 60,
		grantMode = "prompt",
	},
	{
		id = "veteran_wings",
		name = "Veteran Wings",
		description = "Play for 3 hours.",
		assetId = 0,
		assetType = "Asset",
		rarity = "Legendary",
		source = Ugc.Sources.PLAYTIME,
		seconds = 3 * 3600,
		grantMode = "prompt",
	},

	-- ============ DAILY LOGIN ============
	{
		id = "loyal_badge",
		name = "Loyal Badge",
		description = "Log in 3 days in a row.",
		assetId = 0,
		assetType = "Asset",
		rarity = "Rare",
		source = Ugc.Sources.DAILY,
		days = 3,
		grantMode = "prompt",
	},
	{
		id = "week_one_crown",
		name = "Week One Crown",
		description = "Log in 7 days in a row.",
		assetId = 0,
		assetType = "Asset",
		rarity = "Mythic",
		source = Ugc.Sources.DAILY,
		days = 7,
		grantMode = "prompt",
	},

	-- ============ BOUGHT WITH CASH ============
	{
		id = "gold_chain",
		name = "Gold Chain",
		description = "Bought from the UGC shop.",
		assetId = 0,
		assetType = "Asset",
		rarity = "Epic",
		source = Ugc.Sources.SHOP,
		price = 2.5e6,
		grantMode = "prompt",
	},
	{
		id = "egg_backpack",
		name = "Egg Backpack",
		description = "Bought from the UGC shop.",
		assetId = 0,
		assetType = "Asset",
		rarity = "Legendary",
		source = Ugc.Sources.SHOP,
		price = 180e6,
		grantMode = "prompt",
	},
	{
		id = "diamond_visor",
		name = "Diamond Visor",
		description = "Bought from the UGC shop.",
		assetId = 0,
		assetType = "Asset",
		rarity = "Mythic",
		source = Ugc.Sources.SHOP,
		price = 40e9,
		grantMode = "prompt",
	},
}

Ugc.ById = {}
Ugc.BySource = {}

for _, entry in Ugc.List do
	Ugc.ById[entry.id] = entry
	Ugc.BySource[entry.source] = Ugc.BySource[entry.source] or {}
	table.insert(Ugc.BySource[entry.source], entry)
end

function Ugc.get(id: string)
	return Ugc.ById[id]
end

function Ugc.ofSource(source: string)
	return Ugc.BySource[source] or {}
end

--- An item with no real asset id yet. Still unlockable, just not claimable.
function Ugc.isPlaceholder(entry): boolean
	return entry == nil or entry.assetId == nil or entry.assetId == 0
end

--- Human-readable requirement, shown on the locked card in the UGC tab.
function Ugc.requirementText(entry): string
	if entry.source == Ugc.Sources.PLAYTIME then
		local minutes = math.floor(entry.seconds / 60)
		if minutes >= 60 then
			return string.format("Play %d hours", math.floor(minutes / 60))
		end
		return string.format("Play %d minutes", minutes)
	elseif entry.source == Ugc.Sources.DAILY then
		return string.format("Log in %d days in a row", entry.days)
	elseif entry.source == Ugc.Sources.INDEX then
		if entry.world == "All" then
			return "Unlock every pet"
		end
		return string.format("Complete the %s index", entry.world)
	elseif entry.source == Ugc.Sources.HATCH then
		return entry.description or "Hatch a secret pet"
	elseif entry.source == Ugc.Sources.SHOP then
		return "Buy from the UGC shop"
	end
	return entry.description or ""
end

return Ugc
