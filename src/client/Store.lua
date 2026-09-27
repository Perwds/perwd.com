--!strict
--[[
	Store
	The client's copy of the server state, plus a change signal the UI subscribes
	to. Single source of truth so panels never read from each other.
]]

local Store = {}

local state: any = nil
local listeners: { (any) -> () } = {}
local leaderboards: { any } = {}
local boardListeners: { (any) -> () } = {}

function Store.get()
	return state
end

function Store.set(newState: any)
	state = newState
	for _, listener in ipairs(listeners) do
		task.spawn(listener, state)
	end
end

function Store.subscribe(listener: (any) -> ()): () -> ()
	table.insert(listeners, listener)
	if state then
		task.spawn(listener, state)
	end
	return function()
		local index = table.find(listeners, listener)
		if index then
			table.remove(listeners, index)
		end
	end
end

function Store.setLeaderboards(snapshot: { any })
	leaderboards = snapshot
	for _, listener in ipairs(boardListeners) do
		task.spawn(listener, leaderboards)
	end
end

function Store.getLeaderboards()
	return leaderboards
end

function Store.subscribeLeaderboards(listener: (any) -> ()): () -> ()
	table.insert(boardListeners, listener)
	if #leaderboards > 0 then
		task.spawn(listener, leaderboards)
	end
	return function()
		local index = table.find(boardListeners, listener)
		if index then
			table.remove(boardListeners, index)
		end
	end
end

-- Convenience readers ----------------------------------------------------

function Store.isScanning(statId: string): boolean
	return state ~= nil and state.activeScans ~= nil and state.activeScans[statId] ~= nil
end

function Store.scanSession(statId: string)
	if state and state.activeScans then
		return state.activeScans[statId]
	end
	return nil
end

function Store.isScanned(statId: string): boolean
	return state ~= nil and state.scanned[statId] == true
end

function Store.valueOf(statId: string): number?
	return state and state.values[statId] or nil
end

function Store.coins(): number
	return state and state.coins or 0
end

function Store.owns(passKey: string): boolean
	return state ~= nil and state.passes ~= nil and state.passes[passKey] == true
end

return Store
