--[[
	📍 LOCATION: ServerScriptService > Services > EventService (ModuleScript)

	• Rotating server events every 30 min (clock-aligned): Golden Hour, Giant Rush, Meteor Shower.
	• Random "Event Objects" with a server-wide announcement.
	• Server Luck Boost (Developer Product), announced to everyone.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventConfig = require(Shared.Config.EventConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local EventService = {}
local Svc

local currentKey = nil
local serverLuckUntil = 0

function EventService.Init(registry)
	Svc = registry
end

local function compute(now)
	local interval = EventConfig.Interval
	local block = math.floor(now / interval)
	local key = EventConfig.Rotation[(block % #EventConfig.Rotation) + 1]
	local nextKey = EventConfig.Rotation[((block + 1) % #EventConfig.Rotation) + 1]
	local startT = block * interval
	local ev = EventConfig.Events[key]
	local active = now - startT < ev.Duration
	return active and key or nil, startT + ev.Duration, nextKey, (block + 1) * interval
end

local function payload()
	local now = os.time()
	local key, endsAt, nextKey, nextAt = compute(now)
	return {
		Current = key,
		EndsAt = endsAt,
		Next = nextKey,
		NextAt = nextAt,
		ServerLuckUntil = serverLuckUntil,
	}
end

local function broadcast()
	Remotes.Event("EventSync"):FireAllClients(payload())
end

function EventService.GetCurrent()
	if currentKey then
		return EventConfig.Events[currentKey], currentKey
	end
	return nil, nil
end

function EventService.GetServerLuckMult()
	return os.time() < serverLuckUntil and GameConfig.ServerLuckMult or 1
end

function EventService.ActivateServerLuck(minutes, byPlayer)
	serverLuckUntil = math.max(serverLuckUntil, os.time()) + minutes * 60
	Svc.Net.Announce(string.format("%s activated a %dm SERVER LUCK BOOST! 2x luck for everyone!", byPlayer and byPlayer.DisplayName or "Someone", minutes), Color3.fromRGB(120, 200, 255))
	broadcast()
end

-- Extra variant multipliers from events (applies to every spawn).
function EventService.VariantMults()
	local m = { Golden = 1, Diamond = 1, Rainbow = 1, Cosmic = 1 }
	local ev = EventService.GetCurrent()
	if ev and ev.VariantMults then
		for k, v in pairs(ev.VariantMults) do
			m[k] *= v
		end
	end
	return m
end

function EventService.ForcedVariant()
	local ev = EventService.GetCurrent()
	return ev and ev.ForceVariant or nil
end

function EventService.MutationMult()
	local ev = EventService.GetCurrent()
	return ev and ev.MutationMult or 1
end

function EventService.SizeLuck()
	local ev = EventService.GetCurrent()
	return ev and ev.SizeLuck or 1
end

function EventService.RespawnMult(tier)
	local ev = EventService.GetCurrent()
	if ev and ev.RespawnMultForTier and ev.RespawnMultForTier[tier] then
		return ev.RespawnMultForTier[tier]
	end
	return 1
end

function EventService.OnPlayerLoaded(player)
	Remotes.Event("EventSync"):FireClient(player, payload())
end

function EventService.Start()
	currentKey = compute(os.time())

	-- event rotation
	task.spawn(function()
		local nextBonus = 0
		while true do
			task.wait(1)
			local key = compute(os.time())
			if key ~= currentKey then
				local old = currentKey
				currentKey = key
				if key then
					local ev = EventConfig.Events[key]
					Svc.Net.Announce(string.upper(ev.Name) .. " has begun! " .. ev.Description, ev.Color)
					if ev.MegaBox then
						task.spawn(function()
							local ok, err = pcall(Svc.Spawn.SpawnMegaBox)
							if not ok then
								warn("[EventService] mega box failed: " .. tostring(err))
							end
						end)
					end
				elseif old then
					Svc.Net.Announce(EventConfig.Events[old].Name .. " has ended.", Color3.fromRGB(200, 200, 200))
				end
				broadcast()
			end
			-- Box Rain: boxes fall from the sky
			local ev = EventService.GetCurrent()
			if ev and ev.RainEvery and os.clock() >= (EventService._nextRain or 0) then
				EventService._nextRain = os.clock() + ev.RainEvery
				task.spawn(function()
					pcall(Svc.Spawn.RainBox)
				end)
			end
			-- Giant Rush bonus spawns
			if ev and ev.BonusSpawnTier and os.clock() >= nextBonus then
				nextBonus = os.clock() + ev.BonusSpawnInterval
				Svc.Spawn.SpawnExtra(ev.BonusSpawnTier, nil, 90)
			end
		end
	end)

	-- random event objects
	task.spawn(function()
		local cfg = EventConfig.EventObjects
		while true do
			task.wait(math.random(cfg.MinInterval, cfg.MaxInterval))
			local ok, err = pcall(Svc.Spawn.SpawnEventObject)
			if not ok then
				warn("[EventService] event object failed: " .. tostring(err))
			end
		end
	end)

end

return EventService
