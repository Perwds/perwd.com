--!nonstrict
-- Boot order matters: remotes exist before any service tries to connect to
-- them, and the map exists before the first player can spawn onto it.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)

Net.Build()

local DataService = require(script.Services.DataService)
local FishingService = require(script.Services.FishingService)
local EconomyService = require(script.Services.EconomyService)
local LeaderboardService = require(script.Services.LeaderboardService)
local ProfileView = require(script.Services.ProfileView)
local MapBuilder = require(script.World.MapBuilder)

MapBuilder.Build()

DataService.Start()
FishingService.Start()
EconomyService.Start()
LeaderboardService.Start()

local profileChanged = Net.Event(Net.Events.ProfileChanged)

DataService.OnChanged(function(player, profile)
	profileChanged:FireClient(player, ProfileView.Build(profile))
end)

Net.Function(Net.Functions.FetchProfile).OnServerInvoke = function(player: Player)
	local profile = DataService.Get(player) or DataService.Load(player)
	return {
		profile = ProfileView.Build(profile),
		feed = FishingService.Feed(),
		leaderboards = LeaderboardService.Snapshot(),
	}
end

local function setupLeaderstats(player: Player, profile)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = math.clamp(math.floor(profile.coins), 0, 2 ^ 31 - 1)
	coins.Parent = stats

	local caught = Instance.new("IntValue")
	caught.Name = "Caught"
	caught.Value = math.clamp(math.floor(profile.stats.catches), 0, 2 ^ 31 - 1)
	caught.Parent = stats

	stats.Parent = player
end

local function onPlayerAdded(player: Player)
	local profile = DataService.Load(player)
	if not player.Parent then
		-- They left while the DataStore call was in flight.
		DataService.Release(player)
		return
	end

	setupLeaderstats(player, profile)

	player.CharacterAdded:Connect(function()
		-- Wait a beat so the character is fully assembled before moving it.
		task.wait(0.2)
		EconomyService.TeleportToZone(player, profile.zone)
	end)

	if player.Character then
		EconomyService.TeleportToZone(player, profile.zone)
	end

	DataService.MarkChanged(player)
end

DataService.OnChanged(function(player, profile)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		return
	end

	local coins = stats:FindFirstChild("Coins")
	if coins then
		coins.Value = math.clamp(math.floor(profile.coins), 0, 2 ^ 31 - 1)
	end

	local caught = stats:FindFirstChild("Caught")
	if caught then
		caught.Value = math.clamp(math.floor(profile.stats.catches), 0, 2 ^ 31 - 1)
	end
end)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
