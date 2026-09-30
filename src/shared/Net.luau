--[[
	Remote plumbing.

	The server creates every remote listed below on boot; the client waits for
	them. Both sides ask for remotes by name through the same two functions, so
	a typo fails loudly at startup instead of silently at runtime.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

local IS_SERVER = RunService:IsServer()
local FOLDER_NAME = "Net"
local WAIT_TIMEOUT = 20

-- Server -> client pushes.
Net.EVENTS = {
	"StateSync", -- full or partial profile state
	"Notify", -- toast message
	"HatchResult", -- a pet just popped; play the reveal
	"UgcUnlocked", -- a UGC item became claimable
	"WorldEvent", -- potion / day-night timers
	"CarryFeedback", -- grabbed, stolen from, lost the egg
	"FuseResult", -- fuse machine outcome
	"OpenUI", -- a world prop asked the client to open a panel
}

-- Client -> server requests that return a value.
Net.FUNCTIONS = {
	"RequestState",
	"BuyEgg",
	"EquipPet",
	"SellPets",
	"Fuse",
	"ClaimIndexReward",
	"ClaimUgc",
	"BuyUgc",
	"UnlockWorld",
	"DropEgg", -- put down the egg you are carrying
	"PlaceEgg", -- put a carried egg onto one of your hatch pads
	"CollectHatch", -- open a finished egg
}

local root: Folder

if IS_SERVER then
	root = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder
	if not root then
		root = Instance.new("Folder")
		root.Name = FOLDER_NAME
		root.Parent = ReplicatedStorage
	end

	local events = Instance.new("Folder")
	events.Name = "Events"
	events.Parent = root

	local functions = Instance.new("Folder")
	functions.Name = "Functions"
	functions.Parent = root

	for _, name in Net.EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = events
	end

	for _, name in Net.FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = functions
	end
else
	root = ReplicatedStorage:WaitForChild(FOLDER_NAME, WAIT_TIMEOUT) :: Folder
	assert(root, "Net folder never replicated -- is the server bootstrap running?")
end

local function fetch(category: string, name: string): Instance
	local folder = root:FindFirstChild(category)
	if not folder then
		folder = root:WaitForChild(category, WAIT_TIMEOUT)
	end
	assert(folder, `Net.{category} missing`)

	local remote = folder:FindFirstChild(name)
	if not remote then
		remote = folder:WaitForChild(name, WAIT_TIMEOUT)
	end
	assert(remote, `Net remote "{name}" missing from {category}`)

	return remote
end

function Net.Event(name: string): RemoteEvent
	return fetch("Events", name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return fetch("Functions", name) :: RemoteFunction
end

--[[
	Server helper: bind a handler to a RemoteFunction with the player always
	passed first, and errors contained so one bad request cannot take down the
	invocation thread for everyone.
]]
function Net.handle(name: string, handler: (Player, ...any) -> ...any)
	assert(IS_SERVER, "Net.handle is server-only")

	local remote = Net.Function(name)
	remote.OnServerInvoke = function(player, ...)
		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			warn(`[Net] "{name}" failed for {player.Name}: {results[2]}`)
			return { ok = false, error = "internal" }
		end
		return table.unpack(results, 2, results.n)
	end
end

return Net
