--!strict
--[[
	StatEngine
	Produces the number behind every stat id.

	Two sources feed it:

	  * REAL data the server can actually read -- account age, friend count,
	    group count, Premium membership, worn avatar assets.
	  * DETERMINISTIC ESTIMATES for everything Roblox exposes no server API for
	    (total playtime, walk distance, Robux spent, ...). These are seeded from
	    the player's UserId, so a given account always gets the same answer on
	    every server and every rejoin -- which is what makes the leaderboards and
	    the saved values coherent. This is exactly what the "*Uses estimation
	    based on player stats*" line on each card is telling the player.

	Everything runs server-side; the client only ever receives finished numbers.
]]

local Players = game:GetService("Players")
local GroupService = game:GetService("GroupService")

local StatEngine = {}

local SECONDS_PER_DAY = 86400
local ROBUX_PER_USD = 80 -- ~$0.0125 per Robux at the 1000-for-$12.50 rate
local EARTH_CIRCUMFERENCE_STUDS = 1_312_336_000 -- 40,075 km at 28 studs/metre
local MARATHON_STUDS = 1_181_736 -- 42.195 km in studs

local cache: { [number]: any } = {}

-- Deterministic per-player, per-topic randomness -------------------------

local function hash(text: string): number
	local h = 2166136261
	for index = 1, #text do
		h = bit32.bxor(h, string.byte(text, index))
		h = (h * 16777619) % 4294967296
	end
	return h
end

local function rng(userId: number, topic: string): Random
	return Random.new((userId * 7919 + hash(topic)) % 2147483647)
end

--- Stable 0..1 roll for a player/topic pair.
local function roll(userId: number, topic: string): number
	return rng(userId, topic):NextNumber()
end

--- Stable value in [min, max].
local function between(userId: number, topic: string, min: number, max: number): number
	return min + roll(userId, topic) * (max - min)
end

-- Real data fetchers (all guarded) ---------------------------------------

local function fetchFriendCount(userId: number): number
	local ok, count = pcall(function()
		local pages = Players:GetFriendsAsync(userId)
		local total = 0
		repeat
			for _ in ipairs(pages:GetCurrentPage()) do
				total += 1
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		-- Friend lists cap at 200; the guard stops a runaway loop on error.
		until total >= 400
		return total
	end)
	return ok and count or -1
end

local function fetchGroupCount(userId: number): number
	local ok, groups = pcall(function()
		return GroupService:GetGroupsAsync(userId)
	end)
	if ok and type(groups) == "table" then
		return #groups
	end
	return -1
end

local function fetchAvatarAssetCount(userId: number): number
	local ok, info = pcall(function()
		return Players:GetCharacterAppearanceInfoAsync(userId)
	end)
	if ok and type(info) == "table" and type(info.assets) == "table" then
		return #info.assets
	end
	return -1
end

-- Base profile -----------------------------------------------------------

--- Gathers the raw inputs once per player per server. Yields (web calls).
function StatEngine.buildBase(player: Player)
	local userId = player.UserId

	local accountAgeDays = math.max(player.AccountAge, 1)
	local premium = player.MembershipType == Enum.MembershipType.Premium

	local friends = fetchFriendCount(userId)
	if friends < 0 then
		friends = math.floor(between(userId, "friends", 2, 180))
	end

	local groups = fetchGroupCount(userId)
	if groups < 0 then
		groups = math.floor(between(userId, "groups", 0, 45))
	end

	local avatarAssets = fetchAvatarAssetCount(userId)
	if avatarAssets < 0 then
		avatarAssets = math.floor(between(userId, "avatarAssets", 4, 22))
	end

	-- "Engagement" is the single knob most estimates hang off: how heavily this
	-- account actually plays, relative to an average account of the same age.
	local engagement = between(userId, "engagement", 0.18, 1.55)
	if premium then
		engagement *= 1.25
	end
	if friends > 100 then
		engagement *= 1.15
	end

	-- Hours per day averaged over the account's whole life.
	local hoursPerDay = math.clamp(between(userId, "hoursPerDay", 0.25, 5.5) * engagement, 0.05, 9)
	local playtime = math.floor(accountAgeDays * hoursPerDay)

	local base = {
		userId = userId,
		accountAgeDays = accountAgeDays,
		joinedAt = os.time() - accountAgeDays * SECONDS_PER_DAY,
		premium = premium,
		friends = friends,
		groups = groups,
		avatarAssets = avatarAssets,
		engagement = engagement,
		playtime = playtime,
	}

	cache[userId] = base
	return base
end

function StatEngine.getBase(player: Player)
	return cache[player.UserId] or StatEngine.buildBase(player)
end

function StatEngine.clear(player: Player)
	cache[player.UserId] = nil
end

-- Computers --------------------------------------------------------------
-- Each returns the raw number for one stat id. `b` is the base table above.

local Computers: { [string]: (any) -> number } = {}

----------------------------------------------------------------- core
Computers.playtime = function(b)
	return b.playtime
end

Computers.accountAge = function(b)
	return b.accountAgeDays
end

Computers.joinDate = function(b)
	return b.joinedAt
end

Computers.gamesPlayed = function(b)
	local perHour = between(b.userId, "gamesPerHour", 0.12, 0.55)
	return math.max(1, math.floor(b.playtime * perHour))
end

Computers.sessions = function(b)
	local perDay = between(b.userId, "sessionsPerDay", 0.3, 3.4) * b.engagement
	return math.max(1, math.floor(b.accountAgeDays * perDay))
end

Computers.avgSession = function(b)
	local sessions = Computers.sessions(b)
	return (b.playtime * 60) / math.max(sessions, 1)
end

Computers.longestSession = function(b)
	local avgHours = Computers.avgSession(b) / 60
	return avgHours * between(b.userId, "longestMult", 4, 14)
end

Computers.loginStreak = function(b)
	return math.floor(math.min(b.accountAgeDays, between(b.userId, "streak", 3, 260) * b.engagement) + 1)
end

Computers.timeInLobbies = function(b)
	return math.floor(b.playtime * between(b.userId, "lobbyShare", 0.06, 0.24))
end

------------------------------------------------------------- movement
Computers.walkDistance = function(b)
	-- Roughly 16 studs/second of walk speed, moving maybe half the time.
	local movingShare = between(b.userId, "movingShare", 0.28, 0.62)
	return math.floor(b.playtime * 3600 * 16 * movingShare)
end

Computers.jumps = function(b)
	local perMinute = between(b.userId, "jumpsPerMinute", 1.5, 9)
	return math.floor(b.playtime * 60 * perMinute)
end

Computers.fallDistance = function(b)
	return math.floor(Computers.walkDistance(b) * between(b.userId, "fallShare", 0.004, 0.03))
end

Computers.swimDistance = function(b)
	return math.floor(Computers.walkDistance(b) * between(b.userId, "swimShare", 0.002, 0.02))
end

Computers.seatTime = function(b)
	return math.floor(b.playtime * between(b.userId, "seatShare", 0.03, 0.18))
end

Computers.marathons = function(b)
	return math.floor(Computers.walkDistance(b) / MARATHON_STUDS)
end

Computers.lapsOfEarth = function(b)
	return Computers.walkDistance(b) / EARTH_CIRCUMFERENCE_STUDS
end

--------------------------------------------------------------- combat
Computers.deaths = function(b)
	local perHour = between(b.userId, "deathsPerHour", 1.4, 7.5)
	return math.floor(b.playtime * perHour)
end

Computers.kills = function(b)
	return math.floor(Computers.deaths(b) * between(b.userId, "kdrRaw", 0.35, 2.6))
end

Computers.kdr = function(b)
	local deaths = Computers.deaths(b)
	if deaths <= 0 then
		return Computers.kills(b)
	end
	return Computers.kills(b) / deaths
end

Computers.damageDealt = function(b)
	return math.floor(Computers.kills(b) * between(b.userId, "damagePerKill", 110, 420))
end

Computers.voidFalls = function(b)
	return math.floor(Computers.deaths(b) * between(b.userId, "voidShare", 0.04, 0.22))
end

Computers.longestKillstreak = function(b)
	return math.floor(math.max(1, Computers.kdr(b) * between(b.userId, "streakMult", 3, 16)))
end

--------------------------------------------------------------- social
Computers.friends = function(b)
	return b.friends
end

Computers.groups = function(b)
	return b.groups
end

Computers.followers = function(b)
	return math.floor(b.friends * between(b.userId, "followerRatio", 0.2, 6.5) + between(b.userId, "followerFlat", 0, 40))
end

Computers.following = function(b)
	return math.floor(b.friends * between(b.userId, "followingRatio", 0.1, 2.2) + between(b.userId, "followingFlat", 0, 25))
end

Computers.messagesSent = function(b)
	return math.floor(b.playtime * between(b.userId, "messagesPerHour", 2, 26))
end

Computers.friendRequests = function(b)
	return math.floor(between(b.userId, "ignoredRequests", 0, 340) * b.engagement)
end

Computers.friendScore = function(b)
	return math.floor(b.friends * 3 + Computers.followers(b) * 1.5 + b.groups * 8 + Computers.messagesSent(b) * 0.02)
end

-------------------------------------------------------------- economy
Computers.robuxSpent = function(b)
	local spendRate = between(b.userId, "spendRate", 0.4, 34) -- Robux per hour played
	local spent = b.playtime * spendRate
	if b.premium then
		spent *= 2.1
	end
	return math.floor(spent)
end

Computers.avatarValue = function(b)
	local perAsset = between(b.userId, "perAsset", 45, 900)
	return math.floor(b.avatarAssets * perAsset)
end

Computers.itemsOwned = function(b)
	return math.floor(b.avatarAssets * between(b.userId, "inventoryMult", 3, 26) + between(b.userId, "inventoryFlat", 5, 60))
end

Computers.accountValue = function(b)
	local inventory = Computers.itemsOwned(b) * between(b.userId, "itemValue", 25, 310)
	return math.floor(inventory + Computers.avatarValue(b) + Computers.robuxSpent(b) * 0.35)
end

Computers.realMoney = function(b)
	return Computers.robuxSpent(b) / ROBUX_PER_USD
end

Computers.gamepassesOwned = function(b)
	return math.floor(Computers.robuxSpent(b) / between(b.userId, "passPrice", 120, 900))
end

Computers.premiumMonths = function(b)
	if not b.premium then
		return 0
	end
	return math.max(1, math.floor(b.accountAgeDays / 30 * between(b.userId, "premiumShare", 0.08, 0.9)))
end

Computers.richestItem = function(b)
	return math.floor(Computers.accountValue(b) * between(b.userId, "richestShare", 0.05, 0.45))
end

----------------------------------------------------------- collection
Computers.badges = function(b)
	return math.floor(Computers.gamesPlayed(b) * between(b.userId, "badgesPerGame", 0.15, 1.8))
end

Computers.limiteds = function(b)
	return math.floor(Computers.itemsOwned(b) * between(b.userId, "limitedShare", 0, 0.09))
end

Computers.favorites = function(b)
	return math.floor(Computers.gamesPlayed(b) * between(b.userId, "favShare", 0.01, 0.09))
end

Computers.rarestBadge = function(b)
	-- Lower is rarer. Heavy players find rarer badges.
	return math.max(0.0001, between(b.userId, "rarest", 0.02, 4.5) / math.max(b.engagement, 0.2))
end

Computers.completion = function(b)
	local score = (Computers.itemsOwned(b) / 900) * 40
		+ (Computers.badges(b) / 900) * 25
		+ (b.playtime / 20000) * 25
		+ (b.friends / 200) * 10
	return math.clamp(score, 0.1, 100)
end

--------------------------------------------------------------- cursed
Computers.hoursWasted = function(b)
	return math.floor(b.playtime * between(b.userId, "wastedShare", 0.55, 0.97))
end

Computers.lifePercent = function(b)
	-- Assume the player is at least as old as their account plus ~10 years.
	local lifeHours = (b.accountAgeDays + 3650) * 24
	return math.clamp(b.playtime / lifeHours * 100, 0.01, 100)
end

Computers.sleepLost = function(b)
	return math.floor(b.playtime * between(b.userId, "sleepShare", 0.05, 0.35))
end

Computers.ragequits = function(b)
	return math.floor(Computers.deaths(b) * between(b.userId, "rageShare", 0.003, 0.04))
end

Computers.touchGrass = function(b)
	-- Inversely proportional to how much they play. Yes, it's a joke stat.
	return math.max(0, math.floor(between(b.userId, "grass", 0, 60) / math.max(b.engagement, 0.25)))
end

Computers.brainrot = function(b)
	local score = Computers.lifePercent(b) * 4
		+ (Computers.hoursWasted(b) / 15000) * 30
		+ (Computers.sleepLost(b) / 2000) * 20
		+ (30 - math.min(Computers.touchGrass(b), 30))
	return math.clamp(score, 1, 100)
end

StatEngine.Computers = Computers

--- Compute one stat. Returns nil when the id has no computer (bad config).
function StatEngine.compute(player: Player, statId: string): number?
	local computer = Computers[statId]
	if not computer then
		warn("[StatEngine] no computer for stat id: " .. tostring(statId))
		return nil
	end

	local base = StatEngine.getBase(player)
	local ok, value = pcall(computer, base)
	if not ok then
		warn(("[StatEngine] computing %s failed: %s"):format(statId, tostring(value)))
		return nil
	end

	if type(value) ~= "number" or value ~= value or value == math.huge then
		return nil
	end

	return value
end

return StatEngine
