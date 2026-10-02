--[[
	📍 LOCATION: ServerScriptService > Services > DataService (ModuleScript)

	Session-locked DataStore saving (ProfileService-style), written from scratch:
	  • Load uses UpdateAsync to atomically claim a lock { SessionId, Time }.
	    If another live session holds the lock we retry, then kick (never load twice → no dupes).
	  • A lock that hasn't been refreshed for GameConfig.SessionLockStale seconds belongs to a
	    crashed server and may be taken over.
	  • Autosave refreshes the lock. Leaving / shutdown saves AND releases the lock.
	  • Saves for one profile never overlap (per-profile mutex).
	  • If the lock was stolen, we stop saving and kick (the other session is authoritative).
	  • In Studio without API access, data is temporary and never saved.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local DataService = {}

local TEMPLATE = {
	Coins = 0,
	Gems = 0,
	RebirthTokens = 0,
	Rebirths = 0,
	TotalShrinks = 0,
	RaidsWon = 0,
	NextUid = 1,
	Upgrades = { RayPower = 1, Treadmill = 1, ChargeSpeed = 1, Range = 1, Luck = 1, MultiShrink = 1, MuseumSize = 1 },
	SpeedPoints = 0, -- trained on the treadmill; walk speed = Base + bonus(points)
	TokenUpgrades = { Income = 0, Luck = 0, Charge = 0 },
	Items = {}, -- { { U = uid, Id = "SodaCan", V = "Golden", Z = size mult?, S = true? (stolen) } }
	Slots = {}, -- ["pedestal#"] = { U = uid } (object on display) | { Box = { R, T, V, ReadyAt } } (opening)
	SlotsMigrated = false,
	Index = {}, -- ["SodaCan:Golden"] = true
	IndexClaimed = {}, -- ["3:Normal"] = true
	IndexUnseen = 0,
	GatesOpened = {}, -- ["2"] = true
	Potions = { Luck = 0, Income = 0 }, -- os.time() expiry
	Daily = { LastDay = 0, Streak = 0 },
	InfinitePack = { Season = 0, Claimed = 0, Credits = {} },
	Settings = { RaidEnabled = false, AutoShrink = false, Music = 0.5, Sfx = 0.8, Ambient = 0.5, ShowTrails = true, LowGraphics = false, HideOthersBoxes = false },
	Raid = { ShieldUntil = 0, LastRaid = 0, LastToggle = 0, Revenge = {} }, -- Revenge[userIdString] = expiry
	RaySkins = { Default = true },
	EquippedSkin = "Default",
	Trails = {}, -- [trailKey] = true
	EquippedTrail = "",
	RedeemedCodes = {},
	VipFountainAt = 0,
	Receipts = {}, -- [purchaseId] = os.time()
	ReceiptOrder = {},
	LastOnline = 0,
	FirstJoin = 0,
}

-- keys never sent to the client
local PRIVATE = { Receipts = true, ReceiptOrder = true }

-- Fetched lazily: GetDataStore THROWS in an unpublished place, which would crash the whole server.
local store = nil
local function getStore()
	if not store then
		local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, GameConfig.DataStoreName)
		if not ok then
			error(result)
		end
		store = result
	end
	return store
end
local profiles = {} -- [player] = { Data, Key, SessionId, Saving, Released, NoSave }
local dirty = {}
local syncProviders = {}
local DataSync = Remotes.Event("DataSync")

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = deepCopy(v)
	end
	return out
end

local function reconcile(data, template)
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil and #v == 0 then
			reconcile(data[k], v)
		end
	end
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

function DataService.Init(_registry) end

function DataService.Load(player)
	local key = keyFor(player)
	local sessionId = HttpService:GenerateGUID(false)
	local loaded = nil
	local lastError = nil

	for attempt = 1, GameConfig.LoadRetries do
		if not player.Parent then
			return nil
		end
		local state = "error"
		local ok, err = pcall(function()
			getStore():UpdateAsync(key, function(old)
				old = old or {}
				local lock = old.Lock
				if lock and lock.SessionId ~= sessionId and (os.time() - (lock.Time or 0)) < GameConfig.SessionLockStale then
					state = "locked"
					return nil -- cancel write: someone else owns this profile right now
				end
				old.Lock = { SessionId = sessionId, JobId = game.JobId, Time = os.time() }
				old.Data = old.Data or deepCopy(TEMPLATE)
				loaded = old.Data
				state = "ok"
				return old
			end)
		end)
		if ok and state == "ok" then
			break
		end
		loaded = nil
		lastError = ok and state or err
		if RunService:IsStudio() and not ok then
			break -- no DataStore access in Studio: don't make the tester wait
		end
		task.wait(attempt <= 2 and 2 or 5)
	end

	local noSave = false
	if not loaded then
		if RunService:IsStudio() then
			warn("[DataService] DataStore unavailable in Studio (" .. tostring(lastError) .. "). Using TEMPORARY data. Enable 'Studio Access to API Services' to test saving.")
			loaded = deepCopy(TEMPLATE)
			noSave = true
		else
			player:Kick(lastError == "locked"
				and "Your data is still saving on another server. Please rejoin in a moment!"
				or "Couldn't load your data (Roblox DataStores may be down). Please rejoin!")
			return nil
		end
	end

	reconcile(loaded, TEMPLATE)
	if loaded.FirstJoin == 0 then
		loaded.FirstJoin = os.time()
	end

	local profile = { Data = loaded, Key = key, SessionId = sessionId, Saving = false, Released = false, NoSave = noSave }
	profiles[player] = profile

	if not player.Parent then
		-- left while loading: release immediately
		DataService.Release(player)
		return nil
	end
	return loaded
end

function DataService.Get(player)
	local p = profiles[player]
	return p and not p.Released and p.Data or nil
end

function DataService.WaitForData(player, timeout)
	local start = os.clock()
	while player.Parent and os.clock() - start < (timeout or 30) do
		local d = DataService.Get(player)
		if d then
			return d
		end
		task.wait(0.2)
	end
	return nil
end

-- Saves the profile. Returns true on success. Yields.
function DataService.Save(player, release)
	local p = profiles[player]
	if not p then
		return false
	end
	if p.NoSave then
		if release then
			p.Released = true
		end
		return true
	end
	while p.Saving do
		task.wait()
	end
	if p.Released then
		return release == true -- already saved & unlocked
	end
	p.Saving = true
	local stolen = false
	local ok, err = pcall(function()
		getStore():UpdateAsync(p.Key, function(old)
			old = old or {}
			local lock = old.Lock
			if lock and lock.SessionId ~= p.SessionId and (os.time() - (lock.Time or 0)) < GameConfig.SessionLockStale then
				stolen = true
				return nil
			end
			p.Data.LastOnline = os.time()
			old.Data = p.Data
			if release then
				old.Lock = nil
			else
				old.Lock = { SessionId = p.SessionId, JobId = game.JobId, Time = os.time() }
			end
			return old
		end)
	end)
	p.Saving = false

	if ok and not stolen then
		if release then
			p.Released = true
		end
		return true
	end
	if stolen then
		warn("[DataService] Session lock lost for " .. player.Name .. "; stopping saves.")
		p.Released = true
		if player.Parent then
			player:Kick("Your data was loaded on another server.")
		end
		return false
	end
	warn("[DataService] Save failed for " .. player.Name .. ": " .. tostring(err))
	return false
end

function DataService.Release(player)
	local p = profiles[player]
	if not p then
		return
	end
	for attempt = 1, 3 do
		if DataService.Save(player, true) or p.Released then
			break
		end
		task.wait(attempt * 2)
	end
	profiles[player] = nil
	dirty[player] = nil
end

function DataService.ReleaseAll()
	local pending = 0
	for player in pairs(profiles) do
		pending += 1
		task.spawn(function()
			DataService.Release(player)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
end

-- ── Client sync ──────────────────────────────────────────────────────
-- Providers add derived/session fields: fn(player, payload)
function DataService.AddSyncProvider(fn)
	table.insert(syncProviders, fn)
end

function DataService.MarkDirty(player)
	if profiles[player] then
		dirty[player] = true
	end
end

local function sendSync(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local payload = {}
	for k, v in pairs(data) do
		if not PRIVATE[k] then
			payload[k] = v
		end
	end
	for _, fn in ipairs(syncProviders) do
		local ok, err = pcall(fn, player, payload)
		if not ok then
			warn("[DataService] sync provider error: " .. tostring(err))
		end
	end
	DataSync:FireClient(player, payload)
end

function DataService.Start()
	-- throttled sync loop
	task.spawn(function()
		while true do
			task.wait(0.25)
			for player in pairs(dirty) do
				dirty[player] = nil
				if player.Parent and player:GetAttribute("DataLoaded") then
					sendSync(player)
				end
			end
		end
	end)

	-- autosave loop
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for player in pairs(profiles) do
				task.spawn(DataService.Save, player, false)
			end
		end
	end)
end

DataService.Template = TEMPLATE

return DataService
