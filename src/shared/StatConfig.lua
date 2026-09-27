--!strict
--[[
	StatConfig
	The master catalogue of every stat the scanner can check.

	Each entry is pure presentation + progression data. The actual number for a
	stat is produced by StatService (server) which owns a computer function per
	id -- keeping the maths off the client means the values can't be spoofed.

	Fields
	------
	id          unique key, also the DataStore key for the cached value
	name        big label shown on the scan card
	icon        emoji shown in the pill to the left of the name
	color       card colour
	category    groups the stat in the menu tabs
	format      how Format.value should render the number
	scanTime    seconds a scan takes at 1x speed (before gamepass multipliers)
	unlock      how the stat becomes available, see UNLOCK KINDS below
	blurb       one-liner under the value once revealed
	flex        template used when the player shares the stat in chat

	UNLOCK KINDS
	------------
	{ kind = "free" }                        available from the start
	{ kind = "coins",   amount = 2500 }      bought with scan coins
	{ kind = "scans",   amount = 10 }        unlocked after N distinct scans
	{ kind = "rebirth", amount = 2 }         needs N rebirths
	{ kind = "gamepass", pass = "vip" }      needs a gamepass
]]

local StatConfig = {}

local C = Color3.fromRGB

export type Unlock = {
	kind: string,
	amount: number?,
	pass: string?,
}

export type Stat = {
	id: string,
	name: string,
	icon: string,
	color: Color3,
	category: string,
	format: string,
	scanTime: number,
	unlock: Unlock,
	blurb: string,
	flex: string,
}

StatConfig.Categories = {
	{ id = "core", name = "Core", icon = "⭐" },
	{ id = "movement", name = "Movement", icon = "🏃" },
	{ id = "combat", name = "Combat", icon = "⚔️" },
	{ id = "social", name = "Social", icon = "👥" },
	{ id = "economy", name = "Economy", icon = "💰" },
	{ id = "collection", name = "Collection", icon = "🎒" },
	{ id = "cursed", name = "Cursed", icon = "💀" },
}

--- Every stat, in menu order.
StatConfig.Stats = {
	-------------------------------------------------- CORE
	{
		id = "playtime",
		name = "PLAYTIME",
		icon = "⏱️",
		color = C(64, 186, 240),
		category = "core",
		format = "hours",
		scanTime = 6,
		unlock = { kind = "free" },
		blurb = "Total hours you have spent on Roblox.",
		flex = "I've played for %s. Touch grass? Never heard of it.",
	},
	{
		id = "gamesPlayed",
		name = "GAMES PLAYED",
		icon = "🎮",
		color = C(157, 130, 247),
		category = "core",
		format = "number",
		scanTime = 6,
		unlock = { kind = "free" },
		blurb = "Separate experiences you have joined.",
		flex = "I've played %s different games.",
	},
	{
		id = "accountAge",
		name = "ACCOUNT AGE",
		icon = "🎂",
		color = C(255, 178, 102),
		category = "core",
		format = "days",
		scanTime = 4,
		unlock = { kind = "free" },
		blurb = "How long your account has existed.",
		flex = "My account is %s old.",
	},
	{
		id = "joinDate",
		name = "JOIN DATE",
		icon = "📅",
		color = C(120, 200, 190),
		category = "core",
		format = "date",
		scanTime = 5,
		unlock = { kind = "free" },
		blurb = "The day you first signed up.",
		flex = "I joined Roblox on %s.",
	},
	{
		id = "sessions",
		name = "SESSIONS",
		icon = "🔁",
		color = C(96, 170, 255),
		category = "core",
		format = "number",
		scanTime = 8,
		unlock = { kind = "coins", amount = 1200 },
		blurb = "Times you have launched the Roblox client.",
		flex = "I've opened Roblox %s times.",
	},
	{
		id = "avgSession",
		name = "AVG SESSION",
		icon = "📊",
		color = C(88, 200, 220),
		category = "core",
		format = "minutes",
		scanTime = 9,
		unlock = { kind = "coins", amount = 2000 },
		blurb = "Average length of one play session.",
		flex = "My average session is %s.",
	},
	{
		id = "longestSession",
		name = "LONGEST SESSION",
		icon = "🌙",
		color = C(126, 140, 255),
		category = "core",
		format = "hours",
		scanTime = 12,
		unlock = { kind = "scans", amount = 6 },
		blurb = "Your single longest unbroken session.",
		flex = "My longest session was %s straight.",
	},
	{
		id = "loginStreak",
		name = "BEST LOGIN STREAK",
		icon = "🔥",
		color = C(255, 130, 96),
		category = "core",
		format = "days",
		scanTime = 10,
		unlock = { kind = "coins", amount = 3500 },
		blurb = "Longest run of consecutive days played.",
		flex = "My best login streak is %s.",
	},
	{
		id = "timeInLobbies",
		name = "TIME IN LOBBIES",
		icon = "🚪",
		color = C(150, 160, 190),
		category = "core",
		format = "hours",
		scanTime = 14,
		unlock = { kind = "scans", amount = 12 },
		blurb = "Hours spent waiting in menus and lobbies.",
		flex = "I've spent %s just sitting in lobbies.",
	},

	-------------------------------------------------- MOVEMENT
	{
		id = "walkDistance",
		name = "WALK DISTANCE",
		icon = "🚶",
		color = C(255, 168, 64),
		category = "movement",
		format = "studs",
		scanTime = 8,
		unlock = { kind = "free" },
		blurb = "Total studs walked across every game.",
		flex = "I've walked %s.",
	},
	{
		id = "jumps",
		name = "TOTAL JUMPS",
		icon = "⬆️",
		color = C(255, 200, 80),
		category = "movement",
		format = "number",
		scanTime = 7,
		unlock = { kind = "free" },
		blurb = "Every time you pressed space.",
		flex = "I've jumped %s times.",
	},
	{
		id = "fallDistance",
		name = "FALL DISTANCE",
		icon = "🪂",
		color = C(220, 150, 255),
		category = "movement",
		format = "studs",
		scanTime = 11,
		unlock = { kind = "coins", amount = 1500 },
		blurb = "Studs fallen, voluntarily or otherwise.",
		flex = "I've fallen %s. Gravity hates me.",
	},
	{
		id = "swimDistance",
		name = "SWIM DISTANCE",
		icon = "🏊",
		color = C(90, 200, 255),
		category = "movement",
		format = "studs",
		scanTime = 12,
		unlock = { kind = "coins", amount = 2200 },
		blurb = "Studs travelled through water.",
		flex = "I've swum %s.",
	},
	{
		id = "seatTime",
		name = "TIME SEATED",
		icon = "🪑",
		color = C(190, 160, 120),
		category = "movement",
		format = "hours",
		scanTime = 10,
		unlock = { kind = "scans", amount = 8 },
		blurb = "Hours spent sitting in a seat or vehicle.",
		flex = "I've been sitting down for %s.",
	},
	{
		id = "marathons",
		name = "MARATHONS RUN",
		icon = "🏅",
		color = C(255, 120, 150),
		category = "movement",
		format = "number",
		scanTime = 13,
		unlock = { kind = "scans", amount = 15 },
		blurb = "Your walk distance converted to real marathons.",
		flex = "My avatar has run %s marathons.",
	},
	{
		id = "lapsOfEarth",
		name = "LAPS OF EARTH",
		icon = "🌍",
		color = C(120, 220, 160),
		category = "movement",
		format = "decimal",
		scanTime = 18,
		unlock = { kind = "rebirth", amount = 1 },
		blurb = "Times you could have circled the planet.",
		flex = "I've walked around the Earth %s times.",
	},

	-------------------------------------------------- COMBAT
	{
		id = "deaths",
		name = "TOTAL DEATHS",
		icon = "💀",
		color = C(255, 96, 96),
		category = "combat",
		format = "number",
		scanTime = 7,
		unlock = { kind = "free" },
		blurb = "Every respawn you have ever had.",
		flex = "I've died %s times.",
	},
	{
		id = "kills",
		name = "TOTAL KILLS",
		icon = "🗡️",
		color = C(230, 80, 80),
		category = "combat",
		format = "number",
		scanTime = 9,
		unlock = { kind = "coins", amount = 1800 },
		blurb = "Players you have eliminated.",
		flex = "I've got %s kills.",
	},
	{
		id = "kdr",
		name = "K/D RATIO",
		icon = "⚖️",
		color = C(255, 140, 110),
		category = "combat",
		format = "decimal",
		scanTime = 10,
		unlock = { kind = "coins", amount = 2600 },
		blurb = "Kills divided by deaths. Be honest.",
		flex = "My lifetime K/D is %s.",
	},
	{
		id = "damageDealt",
		name = "DAMAGE DEALT",
		icon = "💥",
		color = C(255, 110, 60),
		category = "combat",
		format = "number",
		scanTime = 12,
		unlock = { kind = "scans", amount = 10 },
		blurb = "Total hit points removed from other players.",
		flex = "I've dealt %s damage.",
	},
	{
		id = "voidFalls",
		name = "VOID FALLS",
		icon = "🕳️",
		color = C(120, 110, 180),
		category = "combat",
		format = "number",
		scanTime = 11,
		unlock = { kind = "coins", amount = 3000 },
		blurb = "Times you fell out of the map.",
		flex = "I've fallen into the void %s times.",
	},
	{
		id = "longestKillstreak",
		name = "BEST KILLSTREAK",
		icon = "🔫",
		color = C(255, 90, 140),
		category = "combat",
		format = "number",
		scanTime = 14,
		unlock = { kind = "rebirth", amount = 1 },
		blurb = "Your highest streak without dying.",
		flex = "My best killstreak is %s.",
	},

	-------------------------------------------------- SOCIAL
	{
		id = "friends",
		name = "FRIENDS",
		icon = "🤝",
		color = C(110, 210, 255),
		category = "social",
		format = "number",
		scanTime = 5,
		unlock = { kind = "free" },
		blurb = "People on your friends list right now.",
		flex = "I have %s friends.",
	},
	{
		id = "followers",
		name = "FOLLOWERS",
		icon = "📣",
		color = C(255, 150, 200),
		category = "social",
		format = "number",
		scanTime = 8,
		unlock = { kind = "coins", amount = 900 },
		blurb = "Accounts following your profile.",
		flex = "I have %s followers.",
	},
	{
		id = "following",
		name = "FOLLOWING",
		icon = "👀",
		color = C(200, 170, 255),
		category = "social",
		format = "number",
		scanTime = 8,
		unlock = { kind = "coins", amount = 900 },
		blurb = "Accounts you follow.",
		flex = "I follow %s people.",
	},
	{
		id = "groups",
		name = "GROUPS JOINED",
		icon = "🏛️",
		color = C(150, 190, 255),
		category = "social",
		format = "number",
		scanTime = 7,
		unlock = { kind = "free" },
		blurb = "Groups your account belongs to.",
		flex = "I'm in %s groups.",
	},
	{
		id = "messagesSent",
		name = "MESSAGES SENT",
		icon = "💬",
		color = C(120, 220, 210),
		category = "social",
		format = "number",
		scanTime = 12,
		unlock = { kind = "scans", amount = 10 },
		blurb = "Chat messages typed in-game.",
		flex = "I've sent %s chat messages.",
	},
	{
		id = "friendRequests",
		name = "REQUESTS IGNORED",
		icon = "🙈",
		color = C(190, 190, 200),
		category = "social",
		format = "number",
		scanTime = 13,
		unlock = { kind = "coins", amount = 4000 },
		blurb = "Friend requests you never answered.",
		flex = "I've ignored %s friend requests. Oops.",
	},
	{
		id = "friendScore",
		name = "SOCIAL SCORE",
		icon = "🌟",
		color = C(255, 210, 120),
		category = "social",
		format = "number",
		scanTime = 15,
		unlock = { kind = "gamepass", pass = "vip" },
		blurb = "Weighted score from friends, followers and groups.",
		flex = "My social score is %s.",
	},

	-------------------------------------------------- ECONOMY
	{
		id = "accountValue",
		name = "ACCOUNT VALUE",
		icon = "💎",
		color = C(96, 220, 128),
		category = "economy",
		format = "robux",
		scanTime = 10,
		unlock = { kind = "free" },
		blurb = "Estimated Robux value of everything you own.",
		flex = "My account is worth %s.",
	},
	{
		id = "avatarValue",
		name = "AVATAR VALUE",
		icon = "🧍",
		color = C(120, 230, 160),
		category = "economy",
		format = "robux",
		scanTime = 9,
		unlock = { kind = "coins", amount = 1400 },
		blurb = "Value of the items you are currently wearing.",
		flex = "My fit is worth %s.",
	},
	{
		id = "robuxSpent",
		name = "ROBUX SPENT",
		icon = "🧾",
		color = C(255, 140, 140),
		category = "economy",
		format = "robux",
		scanTime = 13,
		unlock = { kind = "coins", amount = 3200 },
		blurb = "Lifetime Robux you have burned.",
		flex = "I've spent %s on Roblox.",
	},
	{
		id = "realMoney",
		name = "REAL MONEY SPENT",
		icon = "💸",
		color = C(255, 110, 110),
		category = "economy",
		format = "usd",
		scanTime = 16,
		unlock = { kind = "scans", amount = 14 },
		blurb = "Your Robux spend converted to actual dollars.",
		flex = "I've spent about %s of real money. Please don't tell my parents.",
	},
	{
		id = "gamepassesOwned",
		name = "GAMEPASSES OWNED",
		icon = "🎟️",
		color = C(255, 190, 90),
		category = "economy",
		format = "number",
		scanTime = 11,
		unlock = { kind = "coins", amount = 2400 },
		blurb = "Gamepasses sitting in your inventory.",
		flex = "I own %s gamepasses.",
	},
	{
		id = "premiumMonths",
		name = "PREMIUM MONTHS",
		icon = "👑",
		color = C(255, 215, 100),
		category = "economy",
		format = "number",
		scanTime = 10,
		unlock = { kind = "coins", amount = 2800 },
		blurb = "Months you have held a Premium subscription.",
		flex = "I've had Premium for %s months.",
	},
	{
		id = "richestItem",
		name = "RICHEST ITEM",
		icon = "🏆",
		color = C(255, 225, 130),
		category = "economy",
		format = "robux",
		scanTime = 17,
		unlock = { kind = "rebirth", amount = 2 },
		blurb = "The single most valuable thing you own.",
		flex = "My rarest item is worth %s.",
	},

	-------------------------------------------------- COLLECTION
	{
		id = "badges",
		name = "BADGES EARNED",
		icon = "🎖️",
		color = C(255, 200, 120),
		category = "collection",
		format = "number",
		scanTime = 9,
		unlock = { kind = "free" },
		blurb = "Badges collected across all experiences.",
		flex = "I've earned %s badges.",
	},
	{
		id = "itemsOwned",
		name = "ITEMS OWNED",
		icon = "📦",
		color = C(180, 200, 255),
		category = "collection",
		format = "number",
		scanTime = 12,
		unlock = { kind = "coins", amount = 1600 },
		blurb = "Hats, shirts, gear and everything else.",
		flex = "I own %s items.",
	},
	{
		id = "limiteds",
		name = "LIMITEDS OWNED",
		icon = "🔒",
		color = C(255, 170, 200),
		category = "collection",
		format = "number",
		scanTime = 14,
		unlock = { kind = "coins", amount = 4500 },
		blurb = "Limited and collectible items in your inventory.",
		flex = "I own %s limiteds.",
	},
	{
		id = "favorites",
		name = "GAMES FAVOURITED",
		icon = "❤️",
		color = C(255, 130, 170),
		category = "collection",
		format = "number",
		scanTime = 10,
		unlock = { kind = "scans", amount = 9 },
		blurb = "Experiences you hit the favourite button on.",
		flex = "I've favourited %s games.",
	},
	{
		id = "rarestBadge",
		name = "RAREST BADGE",
		icon = "🧿",
		color = C(190, 150, 255),
		category = "collection",
		format = "percent",
		scanTime = 16,
		unlock = { kind = "scans", amount = 18 },
		blurb = "Win rate of the hardest badge you hold.",
		flex = "My rarest badge is owned by only %s of players.",
	},
	{
		id = "completion",
		name = "COLLECTION SCORE",
		icon = "🧮",
		color = C(150, 220, 255),
		category = "collection",
		format = "percent",
		scanTime = 20,
		unlock = { kind = "gamepass", pass = "vip" },
		blurb = "How complete your account is versus the top 1%.",
		flex = "My collection score is %s.",
	},

	-------------------------------------------------- CURSED
	{
		id = "hoursWasted",
		name = "HOURS WASTED",
		icon = "🫠",
		color = C(200, 110, 110),
		category = "cursed",
		format = "hours",
		scanTime = 15,
		unlock = { kind = "scans", amount = 20 },
		blurb = "Playtime minus anything remotely productive.",
		flex = "I've wasted %s of my life here.",
	},
	{
		id = "lifePercent",
		name = "% OF LIFE PLAYED",
		icon = "⏳",
		color = C(230, 120, 160),
		category = "cursed",
		format = "percent",
		scanTime = 18,
		unlock = { kind = "rebirth", amount = 1 },
		blurb = "Share of your entire life spent on Roblox.",
		flex = "I've spent %s of my whole life on Roblox.",
	},
	{
		id = "sleepLost",
		name = "SLEEP LOST",
		icon = "😴",
		color = C(140, 140, 220),
		category = "cursed",
		format = "hours",
		scanTime = 17,
		unlock = { kind = "coins", amount = 6000 },
		blurb = "Estimated sleep sacrificed for one more round.",
		flex = "I've lost %s of sleep to this game.",
	},
	{
		id = "ragequits",
		name = "RAGE QUITS",
		icon = "🤬",
		color = C(255, 100, 80),
		category = "cursed",
		format = "number",
		scanTime = 13,
		unlock = { kind = "coins", amount = 5000 },
		blurb = "Times you alt-F4'd out of pure frustration.",
		flex = "I've rage quit %s times.",
	},
	{
		id = "touchGrass",
		name = "GRASS TOUCHED",
		icon = "🌱",
		color = C(120, 220, 120),
		category = "cursed",
		format = "number",
		scanTime = 22,
		unlock = { kind = "rebirth", amount = 3 },
		blurb = "Scientifically measured. Results may hurt.",
		flex = "I have touched grass %s times.",
	},
	{
		id = "brainrot",
		name = "BRAINROT LEVEL",
		icon = "🧠",
		color = C(255, 120, 220),
		category = "cursed",
		format = "percent",
		scanTime = 25,
		unlock = { kind = "gamepass", pass = "vip" },
		blurb = "Composite score of every cursed stat above.",
		flex = "My brainrot level is %s. It's over.",
	},
}

-- Index for O(1) lookups -------------------------------------------------

StatConfig.ById = {} :: { [string]: Stat }
StatConfig.Order = {} :: { string }

for index, stat in ipairs(StatConfig.Stats) do
	stat.index = index
	StatConfig.ById[stat.id] = stat
	table.insert(StatConfig.Order, stat.id)
end

StatConfig.Count = #StatConfig.Stats

function StatConfig.get(id: string): Stat?
	return StatConfig.ById[id]
end

function StatConfig.inCategory(categoryId: string)
	local out = {}
	for _, stat in ipairs(StatConfig.Stats) do
		if stat.category == categoryId then
			table.insert(out, stat)
		end
	end
	return out
end

return StatConfig
