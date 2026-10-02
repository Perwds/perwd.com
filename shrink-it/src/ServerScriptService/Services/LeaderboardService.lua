--[[
	📍 LOCATION: ServerScriptService > Services > LeaderboardService (ModuleScript)

	Global leaderboards (OrderedDataStores): Museum Value (income/sec), Total Shrinks,
	Rebirths, Raids Won. Rendered on the Board_<Stat> parts in the lobby.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Format)

local LeaderboardService = {}
local Svc

local BOARDS = {
	{ Stat = "MuseumValue", Title = "Museum Value", Suffix = "/s", Get = function(player)
		local s = Svc.Session.Get(player)
		return s and s.IncomePerSec or 0
	end },
	{ Stat = "TotalShrinks", Title = "Total Shrinks", Suffix = "", Get = function(_, data)
		return data.TotalShrinks
	end },
	{ Stat = "Rebirths", Title = "Rebirths", Suffix = "", Get = function(_, data)
		return data.Rebirths
	end },
	{ Stat = "RaidsWon", Title = "Raids Won", Suffix = "", Get = function(_, data)
		return data.RaidsWon
	end },
}

local stores = {}
local nameCache = {}

function LeaderboardService.Init(registry)
	Svc = registry
end

local function nameFor(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	nameCache[userId] = ok and name or ("User " .. userId)
	return nameCache[userId]
end

local function buildBoardGui(part, title)
	local gui = part:FindFirstChild("BoardGui") or Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui:ClearAllChildren()
	gui.Parent = part
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	bg.Parent = gui
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 0.12)
	t.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Text = title
	t.Parent = bg
	Instance.new("UIStroke", t).Thickness = 4
	local list = Instance.new("Frame")
	list.Name = "List"
	list.Size = UDim2.fromScale(0.94, 0.84)
	list.Position = UDim2.fromScale(0.03, 0.14)
	list.BackgroundTransparency = 1
	list.Parent = bg
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0.01, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

local function render(board, entries)
	local part = Svc.Map.Boards[board.Stat]
	if not part then
		return
	end
	local list = buildBoardGui(part, board.Title)
	for i, e in ipairs(entries) do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = i
		row.Size = UDim2.fromScale(1, 1 / GameConfig.LeaderboardSize - 0.01)
		row.BackgroundColor3 = i == 1 and Color3.fromRGB(255, 215, 80) or i == 2 and Color3.fromRGB(210, 210, 225) or i == 3 and Color3.fromRGB(220, 150, 90) or Color3.fromRGB(50, 50, 75)
		row.Font = Enum.Font.FredokaOne
		row.TextScaled = true
		row.TextColor3 = Color3.new(1, 1, 1)
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = string.format("  #%d  %s  —  %s%s", i, e.Name, Format.Abbrev(e.Value), board.Suffix)
		row.Parent = list
		Instance.new("UICorner", row).CornerRadius = UDim.new(0.25, 0)
		Instance.new("UIStroke", row).Thickness = 2
	end
end

local function refresh()
	-- write current players
	for _, player in ipairs(Players:GetPlayers()) do
		local data = Svc.Data.Get(player)
		if data then
			for _, board in ipairs(BOARDS) do
				local value = math.clamp(math.floor(board.Get(player, data) or 0), 0, 2 ^ 53)
				pcall(function()
					stores[board.Stat]:SetAsync(tostring(player.UserId), value)
				end)
			end
		end
	end
	-- read top N
	for _, board in ipairs(BOARDS) do
		local ok, pages = pcall(function()
			return stores[board.Stat]:GetSortedAsync(false, GameConfig.LeaderboardSize)
		end)
		if ok and pages then
			local entries = {}
			for _, row in ipairs(pages:GetCurrentPage()) do
				table.insert(entries, { Name = nameFor(tonumber(row.key)), Value = row.value })
			end
			render(board, entries)
		end
	end
end

function LeaderboardService.Start()
	local available = true
	for _, board in ipairs(BOARDS) do
		render(board, {})
		local ok, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "ShrinkIt_LB_" .. board.Stat)
		if ok then
			stores[board.Stat] = store
		else
			available = false
		end
	end
	if not available then
		warn("[Leaderboard] DataStores unavailable (publish the place + enable API access). Leaderboards disabled for this session.")
		return
	end
	task.spawn(function()
		task.wait(10)
		while true do
			local ok, err = pcall(refresh)
			if not ok then
				warn("[Leaderboard] " .. tostring(err))
			end
			task.wait(GameConfig.LeaderboardRefresh)
		end
	end)
end

return LeaderboardService
