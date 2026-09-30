--!nonstrict
-- Global boards backed by OrderedDataStore. Writes are throttled per player and
-- reads happen on a timer, so a busy server does not burn its request budget.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)

local DataService = require(script.Parent.DataService)

local LeaderboardService = {}

local BOARDS = {
	{ id = "bestCatch", title = "Rarest Catch", store = "BestCatch" },
	{ id = "lifetimeCoins", title = "Lifetime Coins", store = "LifetimeCoins" },
}

-- OrderedDataStore only stores integers, and very large values are not worth
-- the precision risk.
local MAX_ORDERED_VALUE = 2 ^ 40
local WRITE_THROTTLE = 60

local stores = {}
local lastWrite: { [Player]: { [string]: number } } = {}
local cached = {}
local nameCache: { [number]: string } = {}

local function storeFor(board)
	if not stores[board.id] then
		stores[board.id] = DataStoreService:GetOrderedDataStore(
			GameConfig.LeaderboardStoreName .. "_" .. board.store
		)
	end
	return stores[board.id]
end

local function clampValue(value: number): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_ORDERED_VALUE)
end

local function valueFor(board, profile): number
	if board.id == "bestCatch" then
		return clampValue(profile.stats.bestScore)
	end
	return clampValue(profile.lifetimeCoins)
end

local function write(player: Player, profile)
	local now = os.clock()
	local playerWrites = lastWrite[player]
	if not playerWrites then
		playerWrites = {}
		lastWrite[player] = playerWrites
	end

	for _, board in BOARDS do
		if now - (playerWrites[board.id] or -math.huge) >= WRITE_THROTTLE then
			playerWrites[board.id] = now

			local value = valueFor(board, profile)
			task.spawn(function()
				local ok, err = pcall(function()
					storeFor(board):SetAsync(tostring(player.UserId), value)
				end)
				if not ok then
					warn(string.format("[Leaderboard] %s write failed: %s", board.id, tostring(err)))
				end
			end)
		end
	end
end

local function resolveName(userId: number): string
	local cachedName = nameCache[userId]
	if cachedName then
		return cachedName
	end

	local player = Players:GetPlayerByUserId(userId)
	if player then
		nameCache[userId] = player.DisplayName
		return player.DisplayName
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	local resolved = ok and name or ("User " .. userId)
	nameCache[userId] = resolved
	return resolved
end

local function refresh()
	local snapshot = {}

	for _, board in BOARDS do
		local ok, pages = pcall(function()
			return storeFor(board):GetSortedAsync(false, GameConfig.LeaderboardSize)
		end)

		if not ok then
			warn(string.format("[Leaderboard] %s read failed: %s", board.id, tostring(pages)))
			continue
		end

		local rows = {}
		local okPage, page = pcall(function()
			return pages:GetCurrentPage()
		end)

		if okPage then
			for rank, entry in page do
				local userId = tonumber(entry.key)
				if userId then
					table.insert(rows, {
						rank = rank,
						name = resolveName(userId),
						value = entry.value,
					})
				end
			end
		end

		snapshot[board.id] = { title = board.title, rows = rows }
	end

	cached = snapshot
	Net.Event(Net.Events.LeaderboardChanged):FireAllClients(cached)
end

function LeaderboardService.Snapshot()
	return cached
end

function LeaderboardService.Start()
	DataService.OnChanged(function(player, profile)
		write(player, profile)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastWrite[player] = nil

		-- Final write, unthrottled, so a session's best catch is not lost.
		local profile = DataService.Get(player)
		if profile then
			for _, board in BOARDS do
				local value = valueFor(board, profile)
				task.spawn(function()
					pcall(function()
						storeFor(board):SetAsync(tostring(player.UserId), value)
					end)
				end)
			end
		end
	end)

	task.spawn(function()
		while true do
			refresh()
			task.wait(GameConfig.LeaderboardRefresh)
		end
	end)
end

return LeaderboardService
