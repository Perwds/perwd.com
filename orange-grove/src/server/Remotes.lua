--!strict
-- Builds ReplicatedStorage.Remotes and checks every client argument before a handler sees it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RateLimit = require(script.Parent.RateLimit)

local Remotes = {}

-- Client -> server requests, with the exact argument types each one accepts.
local REQUESTS: { [string]: { string } } = {
	PickOrange = { "id" },
	BuyNode = { "id" },
	ToggleMachine = { "id" },
	Replant = {},
	GoHome = {},
	SaveSettings = { "table" },
	TutorialStep = { "int" },
	RequestSync = {},
}

-- Backstop flood limits per request (calls per second). Services add tighter limits of their own.
local LIMITS: { [string]: number } = {
	PickOrange = 20,
	BuyNode = 15,
	ToggleMachine = 4,
	Replant = 1,
	GoHome = 1,
	SaveSettings = 4,
	TutorialStep = 4,
	RequestSync = 0.5,
}

-- Server -> client pushes.
local PUSHES = {
	"State",
	"Trees",
	"TreeUpdate",
	"Picked",
	"BuyResult",
	"Notice",
	"KeeperLine",
	"Shop",
}

local folder: Folder
local events: { [string]: RemoteEvent } = {}

local MAX_ID_LENGTH = 40

local function valid(kind: string, value: any): boolean
	if kind == "id" then
		return type(value) == "string" and #value > 0 and #value <= MAX_ID_LENGTH and not string.find(value, "[^%w_]")
	elseif kind == "int" then
		return type(value) == "number" and value == value and value == math.floor(value) and math.abs(value) < 1e6
	elseif kind == "table" then
		return type(value) == "table"
	end
	return false
end

function Remotes.init()
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for name in REQUESTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		events[name] = remote
	end
	for _, name in PUSHES do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		events[name] = remote
	end
	folder.Parent = ReplicatedStorage
end

-- Handlers only run when the argument count and types match; anything else is dropped silently.
function Remotes.on(name: string, handler: (Player, ...any) -> ())
	local spec = REQUESTS[name]
	assert(spec, "unknown request " .. name)
	local rate = LIMITS[name] or 4
	local limiter = RateLimit.new(rate, math.max(2, rate))
	events[name].OnServerEvent:Connect(function(player: Player, ...)
		if not limiter:take(player) then
			return
		end
		if select("#", ...) > #spec then
			return
		end
		local args = table.pack(...)
		for i, kind in spec do
			if not valid(kind, args[i]) then
				return
			end
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(string.format("[Remotes] %s from %s failed: %s", name, player.Name, tostring(err)))
		end
	end)
end

function Remotes.fire(name: string, player: Player, ...: any)
	if player.Parent then
		events[name]:FireClient(player, ...)
	end
end

function Remotes.fireAll(name: string, ...: any)
	events[name]:FireAllClients(...)
end

return Remotes
