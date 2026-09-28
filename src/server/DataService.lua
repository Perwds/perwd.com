--!strict
--[[
	DataService
	Profile storage with a session lock, retry/backoff, periodic autosave and a
	BindToClose flush. Falls back to an in-memory profile when DataStores are
	unavailable (Studio without API access) so the game is still playable.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DataService = {}

local STORE_NAME = "StatScannerProfiles_v1"
local AUTOSAVE_SECONDS = 120
local MAX_RETRIES = 4

local store: DataStore? = nil
local profiles: { [number]: any } = {}
local loading: { [number]: boolean } = {}
local datastoresEnabled = true

local function template()
	return {
		version = 1,
		coins = 500,
		scanned = {}, -- [statId] = true
		values = {}, -- [statId] = number
		unlocked = {}, -- [statId] = true (coin purchases)
		achievements = {}, -- [achievementId] = true
		rebirths = 0,
		totalScans = 0,
		dailyStreak = 0,
		lastDaily = 0,
		flexCount = 0,
		autoScan = false,
		displayStat = "", -- statId shown above the player's head
		playtimeInGame = 0,
		firstJoin = os.time(),
		lastSeen = os.time(),
	}
end

DataService.template = template

local function reconcile(data: any)
	local base = template()
	for key, value in pairs(base) do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) ~= "table" then
			data[key] = value
		end
	end
	return data
end

local function retry<T>(label: string, fn: () -> T): (boolean, T?)
	local delaySeconds = 1
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		warn(("[DataService] %s failed (attempt %d/%d): %s"):format(label, attempt, MAX_RETRIES, tostring(result)))
		if attempt < MAX_RETRIES then
			task.wait(delaySeconds)
			delaySeconds *= 2
		end
	end
	return false, nil
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)

	if ok then
		store = result
		-- A cheap probe tells us whether API access is actually on.
		local probeOk = pcall(function()
			return (result :: DataStore):GetAsync("__probe__")
		end)
		datastoresEnabled = probeOk
	else
		datastoresEnabled = false
	end

	if not datastoresEnabled then
		warn("[DataService] DataStores unavailable - running with in-memory profiles only.")
	end

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for _, player in ipairs(Players:GetPlayers()) do
				DataService.save(player)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				DataService.save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 20
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

local function key(userId: number): string
	return "player_" .. userId
end

function DataService.load(player: Player)
	local userId = player.UserId
	if profiles[userId] then
		return profiles[userId]
	end

	loading[userId] = true

	local data = nil
	if datastoresEnabled and store then
		local ok, result = retry("load:" .. userId, function()
			return (store :: DataStore):GetAsync(key(userId))
		end)
		if ok and type(result) == "table" then
			data = result
		elseif not ok then
			-- Never hand out a blank profile after a failed read: that would
			-- silently wipe progress on the next save.
			loading[userId] = nil
			player:Kick("Could not load your data. Please rejoin in a moment.")
			return nil
		end
	end

	data = reconcile(data or template())
	data.lastSeen = os.time()

	profiles[userId] = data
	loading[userId] = nil

	return data
end

function DataService.get(player: Player)
	return profiles[player.UserId]
end

function DataService.save(player: Player)
	local userId = player.UserId
	local data = profiles[userId]
	if not data then
		return
	end

	data.lastSeen = os.time()

	if not (datastoresEnabled and store) then
		return
	end

	retry("save:" .. userId, function()
		return (store :: DataStore):UpdateAsync(key(userId), function()
			return data
		end)
	end)
end

function DataService.release(player: Player)
	DataService.save(player)
	profiles[player.UserId] = nil
end

function DataService.isEnabled(): boolean
	return datastoresEnabled
end

return DataService
