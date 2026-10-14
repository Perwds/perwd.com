--!strict
-- Player saves on DataStoreService with a session lock kept inside the record (UpdateAsync only).
-- A server holds a save while the lock carries its JobId; a lock nobody refreshed for lockStaleSeconds is free.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local VERSION = 1

export type Profile = {
	key: string,
	data: { [string]: any },
	released: boolean,
	lastSave: number,
}

local Data = {}

local profiles: { [Player]: Profile } = {}
local loadedCallbacks: { (Player, Profile) -> () } = {}
local beforeSaveCallbacks: { (Player, Profile) -> () } = {}

-- Studio playtests without API access still get a working session, just not a persistent one.
local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.Save.storeName)
	end)
	if ok then
		store = result
	end
	if not ok or (RunService:IsStudio() and not pcall(function()
		(result :: DataStore):GetAsync("__probe")
	end)) then
		store = nil
		warn("[Data] DataStores are unavailable (enable Studio API access to test saving). Progress won't persist.")
	end
end

function Data.defaults(): { [string]: any }
	return {
		version = VERSION,
		currencies = { oranges = 0, vitamin = 0, zest = 0, crates = 0, seeds = 0 },
		peels = 0,
		levels = {},
		lifetimeCrates = 0,
		seedsClaimed = 0,
		replants = 0,
		machines = { lab = true, zester = true, juice = true },
		labBoostUntil = 0,
		seenAreas = {},
		tutorial = 1,
		settings = { music = 0.6, sfx = 0.8, reduceMotion = false, numbers = "short" },
		purchases = {},
		lastOnline = 0,
		totalPicks = 0,
		created = os.time(),
	}
end

-- One function per version step. Add `[1] = function(data) ... end` when VERSION becomes 2.
local migrations: { [number]: (data: { [string]: any }) -> () } = {}

local function reconcile(target: { [string]: any }, template: { [string]: any })
	for key, value in template do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil then
			reconcile(target[key], value)
		end
	end
end

function Data.migrate(data: { [string]: any }): { [string]: any }
	data.version = data.version or 1
	while data.version < VERSION do
		local step = migrations[data.version]
		if step then
			step(data)
		end
		data.version += 1
	end
	reconcile(data, Data.defaults())
	return data
end

local function lockIsLive(lock: any): boolean
	return type(lock) == "table" and lock.job ~= jobId and os.time() - (lock.t or 0) < Config.Save.lockStaleSeconds
end

local function loadRecord(key: string): ({ [string]: any }?, string?)
	if not store then
		return Data.defaults(), nil
	end
	local liveStore = store :: DataStore
	for attempt = 1, Config.Save.loadRetries do
		local busy = false
		local ok, result = pcall(function()
			return liveStore:UpdateAsync(key, function(old)
				local record = old or Data.defaults()
				if lockIsLive(record.lock) then
					busy = true
					return nil
				end
				record.lock = { job = jobId, t = os.time() }
				return record
			end)
		end)
		if ok and not busy and result then
			return result, nil
		end
		if not ok then
			warn("[Data] load failed for " .. key .. ": " .. tostring(result))
		end
		task.wait(2 * attempt)
	end
	return nil, "Your save is still open on another server. Give it a minute and rejoin."
end

function Data.load(player: Player): Profile?
	local key = "p_" .. player.UserId
	local record, err = loadRecord(key)
	if not record then
		player:Kick(err)
		return nil
	end
	record.lock = nil
	if (record.version or 1) > VERSION then
		-- Written by a newer server: give the lock back untouched and let the player find a fresh server.
		Data.release({ key = key, data = record, released = false, lastSave = os.clock() })
		player:Kick("This server is running an older version of the game. Please rejoin.")
		return nil
	end
	local profile: Profile = {
		key = key,
		data = Data.migrate(record),
		released = false,
		lastSave = os.clock(),
	}
	if not player.Parent then
		-- Left while loading: hand the lock straight back.
		Data.release(profile)
		return nil
	end
	profiles[player] = profile
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profile)
	end
	return profile
end

local function writeRecord(profile: Profile, release: boolean): boolean
	if not store then
		return true
	end
	local liveStore = store :: DataStore
	local lost = false
	local ok, err = pcall(function()
		liveStore:UpdateAsync(profile.key, function(old)
			if old and lockIsLive(old.lock) then
				lost = true
				return nil
			end
			local out = table.clone(profile.data)
			out.lock = if release then nil else { job = jobId, t = os.time() }
			return out
		end)
	end)
	if not ok then
		warn("[Data] save failed for " .. profile.key .. ": " .. tostring(err))
		return false
	end
	if lost then
		warn("[Data] " .. profile.key .. " was claimed by another server; not overwriting")
		return false
	end
	profile.lastSave = os.clock()
	return true
end

function Data.release(profile: Profile)
	if profile.released then
		return
	end
	profile.released = true
	writeRecord(profile, true)
end

function Data.save(player: Player): boolean
	local profile = profiles[player]
	if not profile or profile.released then
		return false
	end
	-- Stamp first so a DataStore outage doesn't turn the autosave loop into a retry storm.
	profile.lastSave = os.clock()
	for _, callback in beforeSaveCallbacks do
		callback(player, profile)
	end
	profile.data.lastOnline = os.time()
	return writeRecord(profile, false)
end

function Data.get(player: Player): { [string]: any }?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

function Data.onLoaded(callback: (Player, Profile) -> ())
	table.insert(loadedCallbacks, callback)
end

function Data.onBeforeSave(callback: (Player, Profile) -> ())
	table.insert(beforeSaveCallbacks, callback)
end

local function releasePlayer(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, callback in beforeSaveCallbacks do
		callback(player, profile)
	end
	profile.data.lastOnline = os.time()
	Data.release(profile)
	profiles[player] = nil
end

function Data.init()
	Players.PlayerRemoving:Connect(releasePlayer)

	task.spawn(function()
		while true do
			task.wait(5)
			for player, profile in profiles do
				if os.clock() - profile.lastSave >= Config.Save.autosaveSeconds then
					task.spawn(Data.save, player)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				releasePlayer(player)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return Data
