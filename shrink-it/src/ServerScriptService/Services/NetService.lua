--[[
	📍 LOCATION: ServerScriptService > Services > NetService (ModuleScript)

	Central dispatcher for the "Action" RemoteFunction + helpers for toasts/announcements.
	Every handler: fn(player, ...) -> { ok = bool, msg = string?, ... }
	Rate-limited per player. Handlers never trust arguments: they type-check everything.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local NetService = {}
local Svc

local handlers = {}
local buckets = {} -- [player] = { Tokens, Last }

local RATE = 12 -- requests per second (burst 24)
local BURST = 24

function NetService.Init(registry)
	Svc = registry
end

function NetService.Handle(action, fn)
	handlers[action] = fn
end

local lastNotify = setmetatable({}, { __mode = "k" }) -- [player] = { [text] = os.clock() }

function NetService.Notify(player, text, kind)
	-- the same error spammed (holding a button, several prompts at once) is sent once per 1.5s
	local seen = lastNotify[player]
	if not seen then
		seen = {}
		lastNotify[player] = seen
	end
	local now = os.clock()
	if kind == "error" and seen[text] and now - seen[text] < 1.5 then
		return
	end
	seen[text] = now
	Remotes.Event("Notify"):FireClient(player, text, kind or "info")
end

function NetService.NotifyAll(text, kind)
	Remotes.Event("Notify"):FireAllClients(text, kind or "info")
end

function NetService.Announce(text, color)
	Remotes.Event("Announce"):FireAllClients(text, color)
end

-- Plays a GameConfig.Sounds entry: for one player, or everyone; at `position` (3D) or as UI sound.
function NetService.Sound(name, player, position)
	if player then
		Remotes.Event("PlaySound"):FireClient(player, name, position)
	else
		Remotes.Event("PlaySound"):FireAllClients(name, position)
	end
end

function NetService.Popup(player, kind, payload)
	Remotes.Event("Popup"):FireClient(player, kind, payload)
end

local function allow(player)
	local b = buckets[player]
	local now = os.clock()
	if not b then
		b = { Tokens = BURST, Last = now }
		buckets[player] = b
	end
	b.Tokens = math.min(BURST, b.Tokens + (now - b.Last) * RATE)
	b.Last = now
	if b.Tokens < 1 then
		return false
	end
	b.Tokens -= 1
	return true
end

function NetService.Start()
	Remotes.Function("Action").OnServerInvoke = function(player, action, ...)
		if type(action) ~= "string" then
			return { ok = false }
		end
		if not allow(player) then
			return { ok = false, msg = "Slow down!" }
		end
		local handler = handlers[action]
		if not handler then
			return { ok = false, msg = "Unknown action" }
		end
		if not Svc.Data.Get(player) then
			return { ok = false, msg = "Still loading your data..." }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn("[NetService] " .. action .. " error: " .. tostring(result))
			return { ok = false, msg = "Something went wrong." }
		end
		return result or { ok = true }
	end
end

function NetService.OnPlayerRemoving(player)
	buckets[player] = nil
end

return NetService
