--!strict
--[[
	LeaderboardService
	Global top-25 boards backed by OrderedDataStores, refreshed on a timer and
	pushed to clients. Also mirrors the player's headline numbers onto the
	classic Roblox leaderboard (the Tab list).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local StatConfig = require(Shared.StatConfig)

local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)

local LeaderboardService = {}

local REFRESH_SECONDS = 60
local TOP_COUNT = 25

-- Which stats get a global board. `score` is the scanner's own rank score.
local BOARDS = {
	{ key = "score", name = "Scanner Score", icon = "🏅" },
	{ key = "playtime", name = "Playtime", icon = "⏱️" },
	{ key = "accountValue", name = "Account Value", icon = "💎" },
	{ key = "walkDistance", name = "Walk Distance", icon = "🚶" },
	{ key = "badges", name = "Badges", icon = "🎖️" },
	{ key = "rebirths", name = "Rebirths", icon = "🌟" },
}

local stores: { [string]: OrderedDataStore } = {}
local snapshots: { [string]: { any } } = {}
local nameCache: { [number]: string } = {}
local enabled = true

local function storeFor(key: string): OrderedDataStore?
	if stores[key] then
		return stores[key]
	end
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore("Board_" .. key .. "_v1")
	end)
	if ok then
		stores[key] = store
		return store
	end
	return nil
end

local function nameFor(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
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

--- Writes one player's current numbers to every board.
function LeaderboardService.publish(player: Player)
	if not enabled or not DataService.isEnabled() then
		return
	end

	local profile = DataService.get(player)
	if not profile then
		return
	end

	local values = {
		score = StateService.scoreFor(profile),
		rebirths = profile.rebirths,
	}
	for _, board in ipairs(BOARDS) do
		if values[board.key] == nil then
			values[board.key] = profile.values[board.key]
		end
	end

	for _, board in ipairs(BOARDS) do
		local value = values[board.key]
		local store = storeFor(board.key)
		if store and type(value) == "number" and value > 0 then
			-- OrderedDataStore only takes integers within the 64-bit range.
			local clamped = math.clamp(math.floor(value), 0, 9_000_000_000_000)
			pcall(function()
				store:SetAsync(tostring(player.UserId), clamped)
			end)
		end
	end
end

local function refresh()
	if not enabled or not DataService.isEnabled() then
		return
	end

	for _, board in ipairs(BOARDS) do
		local store = storeFor(board.key)
		if store then
			local ok, pages = pcall(function()
				return store:GetSortedAsync(false, TOP_COUNT)
			end)
			if ok and pages then
				local rows = {}
				for rank, entry in ipairs(pages:GetCurrentPage()) do
					local userId = tonumber(entry.key) or 0
					table.insert(rows, {
						rank = rank,
						userId = userId,
						name = nameFor(userId),
						value = entry.value,
					})
				end
				snapshots[board.key] = rows
			end
		end
	end

	Remotes.event("LeaderboardUpdate"):FireAllClients(LeaderboardService.snapshot())
end

function LeaderboardService.snapshot()
	local out = {}
	for _, board in ipairs(BOARDS) do
		local stat = StatConfig.get(board.key)
		table.insert(out, {
			key = board.key,
			name = board.name,
			icon = board.icon,
			format = stat and stat.format or "number",
			rows = snapshots[board.key] or {},
		})
	end
	return out
end

--- Classic Tab leaderboard: scanner score + rebirths.
local function attachLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local score = Instance.new("IntValue")
	score.Name = "Score"
	score.Parent = folder

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder

	folder.Parent = player

	task.spawn(function()
		while player.Parent do
			local profile = DataService.get(player)
			if profile then
				score.Value = StateService.scoreFor(profile)
				rebirths.Value = profile.rebirths
			end
			task.wait(3)
		end
	end)
end

function LeaderboardService.init()
	Players.PlayerAdded:Connect(attachLeaderstats)
	for _, player in ipairs(Players:GetPlayers()) do
		attachLeaderstats(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		LeaderboardService.publish(player)
	end)

	task.spawn(function()
		while true do
			local ok, err = pcall(refresh)
			if not ok then
				warn("[LeaderboardService] refresh failed: " .. tostring(err))
				enabled = true
			end
			task.wait(REFRESH_SECONDS)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(90)
			for _, player in ipairs(Players:GetPlayers()) do
				LeaderboardService.publish(player)
			end
		end
	end)
end

return LeaderboardService
