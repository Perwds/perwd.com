--[[
	Playtime and daily login streak -- two of the four UGC unlock paths.

	Playtime accumulates in real seconds across sessions. The daily streak
	advances once per PERIOD and resets if the player is away longer than
	GRACE, so "3 days in a row" cannot be farmed by rejoining.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Net = require(ReplicatedStorage.Shared.Net)

local DataService = require(script.Parent.DataService)
local UgcService = require(script.Parent.UgcService)

local PlaytimeService = {}

local TICK = 15

local notify = Net.Event("Notify")

local function rollDaily(player: Player, profile)
	local now = os.time()
	local last = profile.daily.lastClaimAt or 0
	local elapsed = now - last

	if last == 0 then
		profile.daily.streak = 1
		profile.daily.lastClaimAt = now
	elseif elapsed >= Balance.Daily.GRACE then
		-- Away too long; start over.
		profile.daily.streak = 1
		profile.daily.lastClaimAt = now
	elseif elapsed >= Balance.Daily.PERIOD then
		profile.daily.streak += 1
		profile.daily.lastClaimAt = now
	else
		return false
	end

	DataService.markDirty(player)
	notify:FireClient(player, "success", `Day {profile.daily.streak} streak!`)
	UgcService.checkDaily(player)
	return true
end

function PlaytimeService.start()
	DataService.ProfileLoaded:Connect(function(player, profile)
		rollDaily(player, profile)
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if not profile then
					continue
				end
				profile.playtime += TICK
				DataService.markDirty(player)
				UgcService.checkPlaytime(player)
			end
		end
	end)
end

return PlaytimeService
