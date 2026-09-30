--!nonstrict
-- Profile storage. Everything the player owns lives in one DataStore key,
-- loaded on join, autosaved, and flushed on leave and on shutdown.
--
-- Studio without API access will fail every DataStore call; that is expected
-- and the service falls back to an in-memory profile so the game is still
-- playable while you iterate.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Rods = require(Shared.Config.Rods)
local Zones = require(Shared.Config.Zones)
local Fish = require(Shared.Config.Fish)

local DataService = {}

local store = DataStoreService:GetDataStore(GameConfig.DataStoreName)
local profiles: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}
local releasing: { [Player]: boolean } = {}
local changedCallbacks: { (Player, any) -> () } = {}

local PROFILE_VERSION = 1

local function defaultProfile()
	return {
		version = PROFILE_VERSION,
		coins = GameConfig.StartingCoins,
		lifetimeCoins = GameConfig.StartingCoins,
		xp = 0,
		inventory = {},
		rods = { [Rods.Default()] = true },
		equippedRod = Rods.Default(),
		zone = Zones.Default(),
		index = {},
		stats = {
			casts = 0,
			catches = 0,
			escapes = 0,
			bestScore = 0,
			bestLabel = "",
			playtime = 0,
		},
		nextUid = 1,
	}
end

-- Anything coming back from a DataStore is untrusted: it may be from an older
-- build, hand-edited, or half-written. Coerce it into shape rather than trusting it.
local function sanitize(raw)
	local profile = defaultProfile()
	if type(raw) ~= "table" then
		return profile
	end

	local function num(value, fallback, min)
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return fallback
		end
		return math.max(value, min or 0)
	end

	profile.coins = num(raw.coins, 0)
	profile.lifetimeCoins = math.max(num(raw.lifetimeCoins, 0), profile.coins)
	profile.xp = num(raw.xp, 0)
	profile.nextUid = math.max(num(raw.nextUid, 1), 1)

	if type(raw.rods) == "table" then
		for rodId in raw.rods do
			if Rods.Data[rodId] then
				profile.rods[rodId] = true
			end
		end
	end

	if type(raw.equippedRod) == "string" and profile.rods[raw.equippedRod] then
		profile.equippedRod = raw.equippedRod
	end

	if type(raw.zone) == "string" and Zones.Data[raw.zone] and Zones.IsUnlocked(raw.zone, profile.lifetimeCoins) then
		profile.zone = raw.zone
	end

	if type(raw.inventory) == "table" then
		for _, entry in raw.inventory do
			if #profile.inventory >= GameConfig.MaxInventory then
				break
			end
			if type(entry) == "table" and Fish.ById[entry.fishId] then
				table.insert(profile.inventory, {
					uid = num(entry.uid, profile.nextUid),
					fishId = entry.fishId,
					rarity = type(entry.rarity) == "string" and entry.rarity or Fish.Get(entry.fishId).rarity,
					mutation = type(entry.mutation) == "string" and entry.mutation or "None",
					weight = num(entry.weight, 1, 0.0001),
					value = math.floor(num(entry.value, 1)),
					caughtAt = num(entry.caughtAt, 0),
				})
			end
		end
	end

	if type(raw.index) == "table" then
		for fishId, record in raw.index do
			if Fish.ById[fishId] and type(record) == "table" then
				local mutations = {}
				if type(record.mutations) == "table" then
					for mutationName, count in record.mutations do
						if type(mutationName) == "string" and type(count) == "number" then
							mutations[mutationName] = math.floor(math.max(count, 0))
						end
					end
				end
				profile.index[fishId] = {
					count = math.floor(num(record.count, 0)),
					best = num(record.best, 0),
					mutations = mutations,
				}
			end
		end
	end

	if type(raw.stats) == "table" then
		for key, fallback in profile.stats do
			if type(fallback) == "number" then
				profile.stats[key] = num(raw.stats[key], fallback)
			end
		end
		if type(raw.stats.bestLabel) == "string" then
			profile.stats.bestLabel = string.sub(raw.stats.bestLabel, 1, 120)
		end
	end

	-- Keep uids strictly ahead of anything already in the bag.
	for _, entry in profile.inventory do
		profile.nextUid = math.max(profile.nextUid, entry.uid + 1)
	end

	return profile
end

local function keyFor(player: Player): string
	return string.format("player_%d", player.UserId)
end

local function retrying(label: string, fn)
	local lastError
	for attempt = 1, GameConfig.SaveRetries do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end

		lastError = result
		if attempt < GameConfig.SaveRetries then
			task.wait(GameConfig.SaveRetryBackoff * attempt)
		end
	end

	warn(string.format("[DataService] %s failed: %s", label, tostring(lastError)))
	return false, lastError
end

function DataService.Load(player: Player)
	if profiles[player] then
		return profiles[player]
	end

	-- Join and the client's own FetchProfile can both land here before the
	-- first GetAsync returns. Let the second caller wait on the first.
	if loading[player] then
		while loading[player] do
			task.wait()
		end
		return profiles[player]
	end

	loading[player] = true

	local ok, raw = retrying("load " .. player.Name, function()
		return store:GetAsync(keyFor(player))
	end)

	if not ok then
		-- Do not hand the player a blank profile we might then save over the
		-- top of real data. Mark it so Save refuses to write.
		local profile = defaultProfile()
		profile.__readOnly = true
		profiles[player] = profile
		loading[player] = nil
		warn(string.format("[DataService] %s is on a read-only session; progress will not save", player.Name))
		return profile
	end

	local profile = sanitize(raw)
	profiles[player] = profile
	loading[player] = nil
	return profile
end

function DataService.Get(player: Player)
	return profiles[player]
end

function DataService.Save(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.__readOnly then
		return false
	end

	local snapshot = table.clone(profile)
	snapshot.__readOnly = nil

	local ok = retrying("save " .. player.Name, function()
		store:SetAsync(keyFor(player), snapshot, { player.UserId })
	end)

	return ok
end

function DataService.Release(player: Player)
	if releasing[player] then
		return
	end
	releasing[player] = true

	DataService.Save(player)

	profiles[player] = nil
	loading[player] = nil
	releasing[player] = nil
end

-- Anything that mutates a profile calls this so the client and the leaderboards
-- see the change without every service knowing about every other service.
function DataService.MarkChanged(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end

	for _, callback in changedCallbacks do
		task.spawn(callback, player, profile)
	end
end

function DataService.OnChanged(callback: (Player, any) -> ())
	table.insert(changedCallbacks, callback)
end

function DataService.Start()
	Players.PlayerRemoving:Connect(function(player)
		DataService.Release(player)
	end)

	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for player in profiles do
				if player.Parent then
					task.spawn(DataService.Save, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end

		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataService.Release(player)
				pending -= 1
			end)
		end

		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return DataService
