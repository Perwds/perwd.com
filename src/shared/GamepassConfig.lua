--!strict
--[[
	GamepassConfig
	Every monetisation product in one place.

	Set the `id` fields to the real asset ids from the Creator Dashboard before
	publishing. An id of 0 means "not configured yet" -- GamepassService treats
	those as never-owned and PurchaseService refuses to prompt for them, so the
	game still runs fine in Studio with placeholders.
]]

local GamepassConfig = {}

export type Pass = {
	key: string,
	id: number,
	name: string,
	icon: string,
	color: Color3,
	price: number,
	blurb: string,
	perks: { string },
	-- effects
	scanSpeed: number?, -- multiplier applied to scan speed
	coinMultiplier: number?,
	extraSlots: number?,
	autoScan: boolean?,
	instant: boolean?,
	unlockAll: boolean?,
}

local C = Color3.fromRGB

GamepassConfig.Passes = {
	{
		key = "speed2x",
		id = 0,
		name = "2x Scan Speed",
		icon = "⚡",
		color = C(120, 200, 255),
		price = 49,
		blurb = "Every scan finishes twice as fast.",
		perks = { "2x scanning speed on all stats" },
		scanSpeed = 2,
	},
	{
		key = "speed5x",
		id = 0,
		name = "5x Scan Speed",
		icon = "⚡⚡",
		color = C(150, 150, 255),
		price = 149,
		blurb = "Rip through the whole catalogue.",
		perks = { "5x scanning speed on all stats", "Stacks over 2x (highest wins)" },
		scanSpeed = 5,
	},
	{
		key = "speed10x",
		id = 0,
		name = "10x Scan Speed",
		icon = "🌀",
		color = C(190, 130, 255),
		price = 399,
		blurb = "Barely a loading bar left.",
		perks = { "10x scanning speed on all stats" },
		scanSpeed = 10,
	},
	{
		key = "instant",
		id = 0,
		name = "Instant Scan",
		icon = "✨",
		color = C(255, 205, 90),
		price = 799,
		blurb = "No waiting. Ever. Results appear the moment you click.",
		perks = { "All scans complete instantly", "Includes 10x speed as a fallback" },
		scanSpeed = 10,
		instant = true,
	},
	{
		key = "autoScan",
		id = 0,
		name = "Auto Scanner",
		icon = "🤖",
		color = C(130, 230, 180),
		price = 299,
		blurb = "Queues every unscanned stat and works through them for you.",
		perks = { "Auto-scans the whole catalogue", "Keeps running while you AFK" },
		autoScan = true,
	},
	{
		key = "slots",
		id = 0,
		name = "+3 Scan Slots",
		icon = "🧩",
		color = C(255, 160, 120),
		price = 199,
		blurb = "Run four scans side by side instead of one.",
		perks = { "3 extra simultaneous scan slots" },
		extraSlots = 3,
	},
	{
		key = "doubleCoins",
		id = 0,
		name = "2x Scan Coins",
		icon = "🪙",
		color = C(255, 200, 80),
		price = 149,
		blurb = "Double the coins from every completed scan.",
		perks = { "2x coins from scans", "2x coins from daily rewards" },
		coinMultiplier = 2,
	},
	{
		key = "vip",
		id = 0,
		name = "VIP",
		icon = "👑",
		color = C(255, 215, 0),
		price = 499,
		blurb = "Unlocks the VIP-only stats, a golden nametag and a permanent boost.",
		perks = {
			"Unlocks all VIP-locked stats",
			"Golden nametag + chat tag",
			"1.5x scan speed",
			"2x coins",
			"VIP-only leaderboard",
		},
		scanSpeed = 1.5,
		coinMultiplier = 2,
		unlockAll = true,
	},
}

GamepassConfig.Products = {
	{ key = "coins1k", id = 0, name = "1,000 Coins", icon = "🪙", price = 25, coins = 1000 },
	{ key = "coins5k", id = 0, name = "5,500 Coins", icon = "💰", price = 99, coins = 5500 },
	{ key = "coins15k", id = 0, name = "16,000 Coins", icon = "💎", price = 249, coins = 16000 },
	{ key = "coins50k", id = 0, name = "60,000 Coins", icon = "🏦", price = 799, coins = 60000 },
	{ key = "rescanAll", id = 0, name = "Reset All Scans", icon = "🔄", price = 49, resetScans = true },
	{ key = "freeRebirth", id = 0, name = "Instant Rebirth", icon = "🌟", price = 399, instantRebirth = true },
}

GamepassConfig.ByKey = {}
GamepassConfig.ById = {}
for _, pass in ipairs(GamepassConfig.Passes) do
	GamepassConfig.ByKey[pass.key] = pass
	if pass.id ~= 0 then
		GamepassConfig.ById[pass.id] = pass
	end
end

GamepassConfig.ProductByKey = {}
GamepassConfig.ProductById = {}
for _, product in ipairs(GamepassConfig.Products) do
	GamepassConfig.ProductByKey[product.key] = product
	if product.id ~= 0 then
		GamepassConfig.ProductById[product.id] = product
	end
end

--- Highest scan-speed multiplier granted by the passes a player owns.
function GamepassConfig.speedFor(owned: { [string]: boolean }): number
	local best = 1
	for key, has in pairs(owned) do
		local pass = GamepassConfig.ByKey[key]
		if has and pass and pass.scanSpeed and pass.scanSpeed > best then
			best = pass.scanSpeed
		end
	end
	return best
end

--- Coin multipliers stack multiplicatively (2x coins + VIP = 4x).
function GamepassConfig.coinMultiplierFor(owned: { [string]: boolean }): number
	local mult = 1
	for key, has in pairs(owned) do
		local pass = GamepassConfig.ByKey[key]
		if has and pass and pass.coinMultiplier then
			mult *= pass.coinMultiplier
		end
	end
	return mult
end

function GamepassConfig.slotsFor(owned: { [string]: boolean }): number
	local slots = 1
	for key, has in pairs(owned) do
		local pass = GamepassConfig.ByKey[key]
		if has and pass and pass.extraSlots then
			slots += pass.extraSlots
		end
	end
	return slots
end

function GamepassConfig.hasFlag(owned: { [string]: boolean }, flag: string): boolean
	for key, has in pairs(owned) do
		local pass = GamepassConfig.ByKey[key]
		if has and pass and (pass :: any)[flag] then
			return true
		end
	end
	return false
end

return GamepassConfig
