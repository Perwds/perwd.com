--[[
	Minimal signal for server-side service-to-service events. Avoids the
	BindableEvent round trip (and its argument serialisation) for things that
	never leave the server.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	local entry = { handler = handler, connected = true }
	table.insert(self._handlers, entry)

	return {
		Disconnect = function()
			if not entry.connected then
				return
			end
			entry.connected = false
			local index = table.find(self._handlers, entry)
			if index then
				table.remove(self._handlers, index)
			end
		end,
	}
end

function Signal:Once(handler: (...any) -> ())
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		handler(...)
	end)
	return connection
end

function Signal:Fire(...)
	-- Iterate a copy: a handler may disconnect itself or others mid-fire.
	local snapshot = table.clone(self._handlers)
	for _, entry in snapshot do
		if entry.connected then
			task.spawn(entry.handler, ...)
		end
	end
end

function Signal:Destroy()
	for _, entry in self._handlers do
		entry.connected = false
	end
	table.clear(self._handlers)
end

return Signal
