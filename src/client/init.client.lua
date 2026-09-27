--!strict
--[[
	StatScanner - client bootstrap.

	Owns the remote wiring and hands everything to the Store; the UI only ever
	reads from the Store, never from remotes directly.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local StatConfig = require(Shared.StatConfig)

local Store = require(script.Store)
local App = require(script.ui.App)

local player = Players.LocalPlayer

local function fire(name: string, payload: any?)
	Remotes.event(name):FireServer(payload)
end

local app

local callbacks = {
	scan = function(statId: string)
		fire("RequestScan", { statId = statId })
	end,

	cancel = function(statId: string)
		fire("CancelScan", { statId = statId })
	end,

	unlock = function(statId: string)
		fire("UnlockStat", { statId = statId })
	end,

	flex = function(statId: string)
		fire("Flex", { statId = statId })
	end,

	buyPass = function(key: string)
		fire("PromptPurchase", { kind = "pass", key = key })
	end,

	buyProduct = function(key: string)
		fire("PromptPurchase", { kind = "product", key = key })
	end,

	rebirth = function()
		fire("Rebirth")
	end,

	claimDaily = function()
		fire("ClaimDaily")
	end,

	setAutoScan = function(enabled: boolean)
		fire("SetAutoScan", enabled)
	end,

	resetScans = function()
		fire("ResetScans")
	end,

	--- Queues every scannable stat, letting the server reject the ones that
	--- don't fit in the player's slots.
	scanAll = function()
		local state = Store.get()
		if not state then
			return
		end
		for _, stat in ipairs(StatConfig.Stats) do
			if not state.scanned[stat.id] and not (state.activeScans and state.activeScans[stat.id]) then
				fire("RequestScan", { statId = stat.id })
				task.wait(0.05)
			end
		end
	end,

	refreshBoards = function()
		task.spawn(function()
			local ok, snapshot = pcall(function()
				return Remotes.fn("GetLeaderboards"):InvokeServer()
			end)
			if ok and snapshot then
				Store.setLeaderboards(snapshot)
			end
		end)
	end,
}

app = App.new(callbacks)

-- Remote wiring ----------------------------------------------------------

Remotes.event("StateChanged").OnClientEvent:Connect(function(state)
	Store.set(state)
end)

Remotes.event("Notify").OnClientEvent:Connect(function(payload)
	app:notify(payload)
end)

Remotes.event("ScanFinished").OnClientEvent:Connect(function(payload)
	app:onScanFinished(payload)
end)

Remotes.event("ScanStarted").OnClientEvent:Connect(function()
	-- StateChanged carries the authoritative session list; this signal just
	-- exists so the UI can react instantly on high-latency connections.
end)

Remotes.event("FlexBroadcast").OnClientEvent:Connect(function(payload)
	app:flex(payload)
end)

Remotes.event("LeaderboardUpdate").OnClientEvent:Connect(function(snapshot)
	Store.setLeaderboards(snapshot)
end)

Remotes.event("OpenMenu").OnClientEvent:Connect(function(payload)
	-- Kiosks pass the tab they belong to; the podium just opens the stat list.
	local view = type(payload) == "table" and payload.view or nil
	app:setOpen(true, view)
end)

-- Initial snapshot -------------------------------------------------------

task.spawn(function()
	for attempt = 1, 10 do
		local ok, state = pcall(function()
			return Remotes.fn("GetState"):InvokeServer()
		end)
		if ok and state then
			Store.set(state)
			callbacks.refreshBoards()
			return
		end
		task.wait(attempt * 0.5)
	end
	warn("[StatScanner] could not fetch initial state")
end)

print("[StatScanner] client ready for", player.Name)
