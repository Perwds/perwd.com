--[[ Cash and index progress on the player list. ]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)

local LeaderstatsService = {}

local function build(player: Player, profile)
	local stats = player:FindFirstChild("leaderstats") :: Folder?
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		stats.Parent = player
	end

	local cash = stats:FindFirstChild("Cash") :: StringValue?
	if not cash then
		cash = Instance.new("StringValue")
		cash.Name = "Cash"
		cash.Parent = stats
	end

	local index = stats:FindFirstChild("Index") :: StringValue?
	if not index then
		index = Instance.new("StringValue")
		index.Name = "Index"
		index.Parent = stats
	end

	local function refresh()
		cash.Value = Format.abbreviate(profile.cash)
		index.Value = `{IndexService.totalUnlocked(profile)}/{IndexService.TOTAL}`
	end

	refresh()
	return refresh
end

function LeaderstatsService.start()
	local refreshers: { [Player]: () -> () } = {}

	DataService.ProfileLoaded:Connect(function(player, profile)
		refreshers[player] = build(player, profile)
	end)

	Players.PlayerRemoving:Connect(function(player)
		refreshers[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(2)
			for _, refresh in refreshers do
				pcall(refresh)
			end
		end
	end)
end

return LeaderstatsService
