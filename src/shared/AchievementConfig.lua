--!strict
--[[
	AchievementConfig
	Bonus objectives that pay out coins. Each has a `check(profile)` predicate
	evaluated server-side after every scan, unlock, purchase or rebirth.
]]

local StatConfig = require(script.Parent.StatConfig)

local AchievementConfig = {}

local function scannedCount(profile): number
	local count = 0
	for _ in pairs(profile.scanned) do
		count += 1
	end
	return count
end

AchievementConfig.List = {
	{
		id = "firstScan",
		name = "First Contact",
		icon = "🔎",
		blurb = "Complete your first scan.",
		reward = 250,
		check = function(profile)
			return scannedCount(profile) >= 1
		end,
	},
	{
		id = "tenScans",
		name = "Getting Nosy",
		icon = "🧐",
		blurb = "Scan 10 different stats.",
		reward = 1000,
		check = function(profile)
			return scannedCount(profile) >= 10
		end,
	},
	{
		id = "halfway",
		name = "Halfway There",
		icon = "🪜",
		blurb = "Scan half of every stat in the game.",
		reward = 3500,
		check = function(profile)
			return scannedCount(profile) >= math.floor(StatConfig.Count / 2)
		end,
	},
	{
		id = "completionist",
		name = "Completionist",
		icon = "🏁",
		blurb = "Scan every single stat.",
		reward = 15000,
		check = function(profile)
			return scannedCount(profile) >= StatConfig.Count
		end,
	},
	{
		id = "categoryCore",
		name = "Core Curriculum",
		icon = "⭐",
		blurb = "Scan every Core stat.",
		reward = 1500,
		check = function(profile)
			for _, stat in ipairs(StatConfig.inCategory("core")) do
				if not profile.scanned[stat.id] then
					return false
				end
			end
			return true
		end,
	},
	{
		id = "categoryCursed",
		name = "No Going Back",
		icon = "💀",
		blurb = "Scan every Cursed stat.",
		reward = 6000,
		check = function(profile)
			for _, stat in ipairs(StatConfig.inCategory("cursed")) do
				if not profile.scanned[stat.id] then
					return false
				end
			end
			return true
		end,
	},
	{
		id = "rich",
		name = "Coin Hoarder",
		icon = "🪙",
		blurb = "Hold 25,000 coins at once.",
		reward = 2500,
		check = function(profile)
			return profile.coins >= 25000
		end,
	},
	{
		id = "rebirth1",
		name = "Born Again",
		icon = "🌟",
		blurb = "Rebirth for the first time.",
		reward = 5000,
		check = function(profile)
			return profile.rebirths >= 1
		end,
	},
	{
		id = "rebirth5",
		name = "Cycle of Stats",
		icon = "♾️",
		blurb = "Reach 5 rebirths.",
		reward = 25000,
		check = function(profile)
			return profile.rebirths >= 5
		end,
	},
	{
		id = "streak7",
		name = "Week Warrior",
		icon = "📆",
		blurb = "Claim the daily reward 7 days in a row.",
		reward = 4000,
		check = function(profile)
			return profile.dailyStreak >= 7
		end,
	},
	{
		id = "flexer",
		name = "Look At Me",
		icon = "📣",
		blurb = "Flex a stat to the whole server 5 times.",
		reward = 1200,
		check = function(profile)
			return (profile.flexCount or 0) >= 5
		end,
	},
	{
		id = "oldAccount",
		name = "Ancient One",
		icon = "🏺",
		blurb = "Scan an account age above 5 years.",
		reward = 3000,
		check = function(profile)
			local value = profile.values.accountAge
			return value ~= nil and value >= 365 * 5
		end,
	},
	{
		id = "richAccount",
		name = "Whale Watch",
		icon = "🐋",
		blurb = "Scan an account value above 100,000 Robux.",
		reward = 5000,
		check = function(profile)
			local value = profile.values.accountValue
			return value ~= nil and value >= 100000
		end,
	},
	{
		id = "marathonRunner",
		name = "Marathon Man",
		icon = "🏅",
		blurb = "Scan more than 500 marathons of walking.",
		reward = 3500,
		check = function(profile)
			local value = profile.values.marathons
			return value ~= nil and value >= 500
		end,
	},
	{
		id = "nolife",
		name = "Touch Grass Challenge (Failed)",
		icon = "🌱",
		blurb = "Scan over 10,000 hours of playtime.",
		reward = 10000,
		check = function(profile)
			local value = profile.values.playtime
			return value ~= nil and value >= 10000
		end,
	},
}

AchievementConfig.ById = {}
for _, entry in ipairs(AchievementConfig.List) do
	AchievementConfig.ById[entry.id] = entry
end

return AchievementConfig
