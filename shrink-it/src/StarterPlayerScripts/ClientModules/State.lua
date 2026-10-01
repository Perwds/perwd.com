--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > State (ModuleScript)

	Client-side mirror of the server's data (READ-ONLY for display).
	All changes go through State.Action(...) → server validates.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local State = {
	Data = nil,
	Loaded = false,
	Coins = 0,
	Gems = 0,
	Tokens = 0,
	Income = 0,
	Event = nil,
}

local changed = Instance.new("BindableEvent")
local currencyChanged = Instance.new("BindableEvent")
local eventChanged = Instance.new("BindableEvent")
State.Changed = changed.Event
State.CurrencyChanged = currencyChanged.Event
State.EventChanged = eventChanged.Event

local actionRemote

function State.Init()
	actionRemote = Remotes.Function("Action")
	Remotes.Event("DataSync").OnClientEvent:Connect(function(payload)
		State.Data = payload
		State.Coins = payload.Coins
		State.Gems = payload.Gems
		State.Tokens = payload.RebirthTokens
		State.Income = payload.IncomePerSec or 0
		State.Loaded = true
		changed:Fire()
		currencyChanged:Fire()
	end)
	Remotes.Event("CurrencySync").OnClientEvent:Connect(function(coins, gems, tokens, income)
		State.Coins, State.Gems, State.Tokens, State.Income = coins, gems, tokens, income
		if State.Data then
			State.Data.Coins, State.Data.Gems, State.Data.RebirthTokens = coins, gems, tokens
			State.Data.IncomePerSec = income
		end
		currencyChanged:Fire()
	end)
	Remotes.Event("EventSync").OnClientEvent:Connect(function(payload)
		State.Event = payload
		eventChanged:Fire()
	end)
end

-- Calls fn now (if loaded) and on every data change.
function State.Observe(fn)
	if State.Loaded then
		task.spawn(fn)
	end
	return State.Changed:Connect(fn)
end

-- Sends a request to the server. Returns { ok, msg, ... }
function State.Action(name, ...)
	local ok, result = pcall(actionRemote.InvokeServer, actionRemote, name, ...)
	if not ok then
		return { ok = false, msg = "Connection problem, try again." }
	end
	return result or { ok = false }
end

function State.Now()
	return workspace:GetServerTimeNow()
end

function State.HasPass(key)
	return State.Data ~= nil and State.Data.Passes ~= nil and State.Data.Passes[key] == true
end

return State
