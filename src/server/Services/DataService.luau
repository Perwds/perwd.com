--[[
	Profile persistence.

	One DataStore key per player, session-locked so two servers cannot fight
	over the same profile. Autosaves on an interval, on leave, and on
	BindToClose. Every other service reads and writes through `get(player)`
	and then calls `markDirty`, so saving stays in one place.

	`Template` is the schema. New fields added there are reconciled into old
	profiles on load, so shipping a new feature never wipes anyone.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DataService = {}

local STORE_NAME = "StealAPet_Profiles_v1"
local KEY_PREFIX = "player_"
local AUTOSAVE_INTERVAL = 90
local LOCK_STALE_AFTER = 300

-- In Studio without API access, fall back to memory so the game still runs.
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable; running with in-memory profiles")
	end
end

DataService.Template = {
	version = 1,

	cash = 0,
	-- Bonus walkspeed earned from index rewards, before the carry penalty.
	speedBonus = 0,

	-- uid -> { id = petId, shiny = boolean, locked = boolean }
	pets = {},
	-- Array of uids, capped at Balance.Pets.EQUIP_LIMIT.
	equipped = {},
	nextPetUid = 1,

	-- petId -> true. Drives the Pet Index tiles and the 0/104 counter.
	index = {},
	-- world -> true once its completion reward has been claimed.
	indexClaimed = {},

	-- world -> true. Forest is granted on first join.
	worlds = { Forest = true },

	-- padIndex -> { eggId, startedAt, duration, rarity }
	hatchPads = {},

	-- ugcId -> { unlockedAt = number, claimed = boolean, claimedAt = number? }
	ugc = {},

	-- Seconds played, accumulated across sessions.
	playtime = 0,
	daily = { streak = 0, lastClaimAt = 0 },

	stats = { hatched = 0, eggsStolen = 0, eggsLost = 0, petsSold = 0, fused = 0 },
}

local profiles: { [Player]: any } = {}
local dirty: { [Player]: boolean } = {}
local loading: { [Player]: boolean } = {}

DataService.ProfileLoaded = Signal.new()
DataService.ProfileReleasing = Signal.new()

local function keyFor(player: Player): string
	return KEY_PREFIX .. player.UserId
end

--- Copies missing keys from template into data, recursively. Never overwrites.
local function reconcile(data: any, template: any)
	for key, value in template do
		if data[key] == nil then
			if type(value) == "table" then
				data[key] = table.clone(value)
				reconcile(data[key], value)
			else
				data[key] = value
			end
		elseif type(value) == "table" and type(data[key]) == "table" then
			reconcile(data[key], value)
		end
	end
end

local function freshProfile()
	local data = {}
	reconcile(data, DataService.Template)
	return data
end

function DataService.get(player: Player)
	return profiles[player]
end

--- Blocks until the profile is loaded, or returns nil if the player left.
function DataService.await(player: Player, timeout: number?)
	local deadline = os.clock() + (timeout or 10)
	while not profiles[player] and player.Parent and os.clock() < deadline do
		task.wait(0.1)
	end
	return profiles[player]
end

function DataService.markDirty(player: Player)
	if profiles[player] then
		dirty[player] = true
	end
end

local function save(player: Player, release: boolean)
	local data = profiles[player]
	if not data or not store then
		dirty[player] = false
		return
	end

	local payload = {
		data = data,
		lock = release and 0 or os.time(),
		savedAt = os.time(),
	}

	local ok, err = pcall(function()
		store:UpdateAsync(keyFor(player), function()
			return payload
		end)
	end)

	if ok then
		dirty[player] = false
	else
		warn(`[DataService] save failed for {player.Name}: {err}`)
	end
end

DataService.save = save

local function load(player: Player)
	if loading[player] or profiles[player] then
		return
	end
	loading[player] = true

	local data
	if store then
		local ok, result = pcall(function()
			return store:GetAsync(keyFor(player))
		end)

		if ok and type(result) == "table" then
			-- Respect an active session lock unless it has gone stale, which
			-- means the other server crashed without releasing.
			local lock = tonumber(result.lock) or 0
			if lock > 0 and os.time() - lock < LOCK_STALE_AFTER then
				-- Another server still holds this profile. Wait, then read
				-- again: `result` is from before the wait and would be stale.
				warn(`[DataService] {player.Name} profile is session-locked; waiting`)
				task.wait(6)

				local retryOk, retry = pcall(function()
					return store:GetAsync(keyFor(player))
				end)
				if retryOk and type(retry) == "table" then
					result = retry
				end
			end
			data = result.data
		elseif not ok then
			warn(`[DataService] load failed for {player.Name}: {result}`)
			-- Do not hand out a blank profile after a read error -- that would
			-- overwrite real progress on the next save. Kick instead.
			loading[player] = nil
			player:Kick("Could not load your data. Please rejoin.")
			return
		end
	end

	if type(data) ~= "table" then
		data = freshProfile()
	else
		reconcile(data, DataService.Template)
	end

	if not player.Parent then
		loading[player] = nil
		return
	end

	profiles[player] = data
	loading[player] = nil

	-- Claim the session lock immediately so another server sees it.
	dirty[player] = true
	task.spawn(save, player, false)

	DataService.ProfileLoaded:Fire(player, data)
end

local function release(player: Player)
	local data = profiles[player]
	if not data then
		loading[player] = nil
		return
	end

	DataService.ProfileReleasing:Fire(player, data)

	save(player, true)

	profiles[player] = nil
	dirty[player] = nil
end

function DataService.start()
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(release)

	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	-- Autosave loop. Only writes profiles a service actually touched.
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				if dirty[player] then
					task.spawn(save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = {}
		for player in profiles do
			table.insert(pending, player)
		end
		for _, player in pending do
			task.spawn(release, player)
		end
		-- Give the writes a moment to land before the server dies.
		task.wait(math.min(#pending * 0.3 + 1, 10))
	end)
end

return DataService
