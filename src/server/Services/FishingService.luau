--!nonstrict
-- The fishing loop.
--
-- The one rule that matters: the client never decides what it caught. The roll
-- happens on the server the moment the fish bites, is held server-side for the
-- duration of the reel minigame, and is awarded only if the client reports a
-- win inside a plausible time window. The client's only input is "I won" or
-- "I lost", and it cannot fake the fish either way.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Rods = require(Shared.Config.Rods)
local Zones = require(Shared.Config.Zones)
local CatchRoll = require(Shared.CatchRoll)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)

local MAX_CAST_DISTANCE = 140

local FishingService = {}

local rng = Random.new()
local casts: { [Player]: any } = {}
local lastCastAt: { [Player]: number } = {}
local nextCastId = 1

local feed = {}

-- Luck ------------------------------------------------------------------------

function FishingService.LuckFor(profile): number
	return CatchRoll.Luck(profile.equippedRod, profile.zone, GameConfig.LevelForXp(profile.xp))
end

local function displayName(catch): string
	return CatchRoll.DisplayName(catch)
end

-- Awarding ----------------------------------------------------------------------

local function pushFeed(player: Player, catch)
	table.insert(feed, {
		player = player.DisplayName,
		fish = displayName(catch),
		rarity = catch.rarity,
		mutation = catch.mutation,
		odds = catch.odds,
		at = os.time(),
	})

	while #feed > GameConfig.FeedLength do
		table.remove(feed, 1)
	end

	Net.Event(Net.Events.GlobalFeed):FireAllClients(feed)
end

local function recordInIndex(profile, catch)
	local entry = profile.index[catch.fishId]
	if not entry then
		entry = { count = 0, best = 0, mutations = {} }
		profile.index[catch.fishId] = entry
	end

	entry.count += 1
	entry.best = math.max(entry.best, catch.weight)
	entry.mutations[catch.mutation] = (entry.mutations[catch.mutation] or 0) + 1
end

local function award(player: Player, catch)
	local profile = DataService.Get(player)
	if not profile then
		return
	end

	local autoSold = false

	if #profile.inventory >= GameConfig.MaxInventory then
		-- Losing a Secret to a full bag would be miserable; bank it instead.
		profile.coins += catch.value
		profile.lifetimeCoins += catch.value
		autoSold = true
	else
		local uid = profile.nextUid
		profile.nextUid += 1

		table.insert(profile.inventory, {
			uid = uid,
			fishId = catch.fishId,
			rarity = catch.rarity,
			mutation = catch.mutation,
			weight = catch.weight,
			value = catch.value,
			caughtAt = os.time(),
		})
	end

	recordInIndex(profile, catch)

	profile.stats.catches += 1
	profile.xp += GameConfig.XpPerCatch
		+ math.floor(Rarities.Get(catch.rarity).score * GameConfig.XpRarityBonus)

	if catch.score > profile.stats.bestScore then
		profile.stats.bestScore = catch.score
		profile.stats.bestLabel = string.format(
			"%s (%s)",
			displayName(catch),
			Format.Weight(catch.weight)
		)
	end

	DataService.MarkChanged(player)

	Net.Event(Net.Events.CatchResult):FireClient(player, {
		escaped = false,
		autoSold = autoSold,
		fishId = catch.fishId,
		name = displayName(catch),
		baseName = catch.name,
		rarity = catch.rarity,
		mutation = catch.mutation,
		weight = catch.weight,
		value = catch.value,
		odds = catch.odds,
	})

	if GameConfig.AnnounceRarities[catch.rarity] or GameConfig.AnnounceMutations[catch.mutation] then
		pushFeed(player, catch)
	end
end

-- Cast lifecycle ------------------------------------------------------------------

local function clearCast(player: Player)
	casts[player] = nil
end

local function beginBite(player: Player, castId: number)
	local cast = casts[player]
	if not cast or cast.id ~= castId or cast.state ~= "waiting" then
		return
	end

	local profile = DataService.Get(player)
	if not profile then
		return
	end

	-- Rolled now, held here, handed over only on a valid reel report.
	cast.pending = CatchRoll.Roll(profile.zone, FishingService.LuckFor(profile), rng)
	cast.state = "biting"
	cast.biteAt = os.clock()

	local rod = Rods.Get(profile.equippedRod)
	local rarityIndex = Rarities.IndexOf(cast.pending.rarity)
	local mutationIndex = Mutations.IndexOf(cast.pending.mutation)

	-- Rarer things fight harder. Jittered so the exact tier is not readable
	-- off the bar.
	local fight = 1 + (rarityIndex - 1) * 0.16 + (mutationIndex - 1) * 0.05
	fight *= rng:NextNumber(0.92, 1.12)

	Net.Event(Net.Events.BiteAlert):FireClient(player, {
		castId = castId,
		barSize = rod.barSize,
		fillRate = rod.fillRate,
		drainRate = rod.drainRate,
		fishSpeed = rod.fishSpeed * fight,
		timeout = GameConfig.MaxReelSeconds,
	})

	task.delay(GameConfig.MaxReelSeconds + GameConfig.ReelGrace, function()
		local current = casts[player]
		if current and current.id == castId then
			clearCast(player)
			if player.Parent then
				Net.Event(Net.Events.CatchResult):FireClient(player, { escaped = true, reason = "timeout" })
			end
		end
	end)
end

local function onRequestCast(player: Player, target: unknown)
	local profile = DataService.Get(player)
	if not profile then
		return
	end

	if typeof(target) ~= "Vector3" then
		return
	end

	local now = os.clock()
	if now - (lastCastAt[player] or -math.huge) < GameConfig.CastCooldown then
		return
	end

	if casts[player] then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	if (root.Position - target).Magnitude > MAX_CAST_DISTANCE then
		return
	end

	local zone = Zones.Get(profile.zone)
	local flatOffset = Vector3.new(target.X - zone.origin.X, 0, target.Z - zone.origin.Z)
	if flatOffset.Magnitude > zone.radius then
		Net.Event(Net.Events.Notify):FireClient(player, "Cast into the water in your zone.", "warn")
		return
	end

	lastCastAt[player] = now
	profile.stats.casts += 1

	local castId = nextCastId
	nextCastId += 1

	local rod = Rods.Get(profile.equippedRod)
	local delay = rng:NextNumber(zone.biteRange.min, zone.biteRange.max) * rod.biteSpeed

	casts[player] = {
		id = castId,
		state = "waiting",
		startedAt = now,
		target = target,
	}

	task.delay(delay, function()
		beginBite(player, castId)
	end)

	task.delay(GameConfig.CastLifetime, function()
		local current = casts[player]
		if current and current.id == castId and current.state == "waiting" then
			clearCast(player)
		end
	end)
end

local function onSubmitReel(player: Player, castId: unknown, success: unknown)
	local cast = casts[player]
	if not cast then
		return
	end

	if type(castId) ~= "number" or castId ~= cast.id or cast.state ~= "biting" then
		return
	end

	local elapsed = os.clock() - cast.biteAt
	if elapsed > GameConfig.MaxReelSeconds + GameConfig.ReelGrace then
		clearCast(player)
		return
	end

	local caught = success == true

	-- No rod can legitimately fill the bar this fast. Treat the claim as a
	-- miss rather than trusting it.
	if caught and elapsed < GameConfig.MinReelSeconds then
		caught = false
	end

	local pending = cast.pending
	clearCast(player)

	if not caught then
		local profile = DataService.Get(player)
		if profile then
			profile.stats.escapes += 1
			DataService.MarkChanged(player)
		end

		Net.Event(Net.Events.CatchResult):FireClient(player, { escaped = true, reason = "lost" })
		return
	end

	if pending then
		award(player, pending)
	end
end

local function onCancelCast(player: Player)
	clearCast(player)
end

function FishingService.Feed()
	return feed
end

function FishingService.Start()
	Net.Event(Net.Events.RequestCast).OnServerEvent:Connect(onRequestCast)
	Net.Event(Net.Events.SubmitReel).OnServerEvent:Connect(onSubmitReel)
	Net.Event(Net.Events.CancelCast).OnServerEvent:Connect(onCancelCast)

	Players.PlayerRemoving:Connect(function(player)
		casts[player] = nil
		lastCastAt[player] = nil
	end)
end

return FishingService
