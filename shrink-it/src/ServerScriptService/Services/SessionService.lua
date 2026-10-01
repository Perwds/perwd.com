--[[
	📍 LOCATION: ServerScriptService > Services > SessionService (ModuleScript)

	Per-player, per-session (NOT saved) state: owned passes, plot, charge state,
	playtime-gift claims, cached income, rate-limit timers...
]]

local SessionService = {}

local sessions = {}

function SessionService.Create(player)
	local s = {
		Passes = {},
		JoinClock = os.clock(),
		JoinServerTime = workspace:GetServerTimeNow(),
		GiftsClaimed = {},
		BaseIncome = 0, -- sum of displayed items, before multipliers
		IncomePerSec = 0,
		Charge = nil, -- { Target = Instance, Start = os.clock(), Time = seconds }
		LastShot = 0,
		NextAuto = 0,
		Plot = nil,
		ActionTimes = {},
	}
	sessions[player] = s
	return s
end

function SessionService.Get(player)
	return sessions[player]
end

function SessionService.Remove(player)
	sessions[player] = nil
end

function SessionService.HasPass(player, key)
	local s = sessions[player]
	return s ~= nil and s.Passes[key] == true
end

-- Simple per-action cooldown. Returns true if allowed.
function SessionService.Throttle(player, key, seconds)
	local s = sessions[player]
	if not s then
		return false
	end
	local now = os.clock()
	if s.ActionTimes[key] and now - s.ActionTimes[key] < seconds then
		return false
	end
	s.ActionTimes[key] = now
	return true
end

function SessionService.All()
	return sessions
end

return SessionService
