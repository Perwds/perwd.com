--!strict
--[[
	Remotes
	Creates (server) or waits for (client) the network objects. Every remote is
	declared here so both sides agree on names without magic strings.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()

local EVENTS = {
	"StateChanged", -- server -> client: full or partial profile state
	"ScanStarted", -- server -> client: { statId, duration, endsAt }
	"ScanFinished", -- server -> client: { statId, value, coins, isNew }
	"Notify", -- server -> client: { text, color, icon }
	"LeaderboardUpdate", -- server -> client: board snapshots
	"Flex", -- client -> server: broadcast a stat to the server
	"FlexBroadcast", -- server -> client: someone flexed
	"RequestScan", -- client -> server: { statId }
	"CancelScan", -- client -> server: { statId }
	"UnlockStat", -- client -> server: { statId }
	"Rebirth", -- client -> server
	"ClaimDaily", -- client -> server
	"SetAutoScan", -- client -> server: boolean
	"PromptPurchase", -- client -> server: { kind = "pass"|"product", key }
	"ResetScans", -- client -> server
	"OpenMenu", -- server -> client: the podium prompt was triggered
	"SetDisplayStat", -- client -> server: { statId } ("" clears it)
}

local FUNCTIONS = {
	"GetState", -- client -> server: initial snapshot
	"GetLeaderboards",
}

local Remotes = {}
local cache: { [string]: Instance } = {}

local function container(): Folder
	if IS_SERVER then
		local folder = ReplicatedStorage:FindFirstChild("StatScannerRemotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "StatScannerRemotes"
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild("StatScannerRemotes", 30) :: Folder
end

local function resolve(name: string, className: string): Instance
	if cache[name] then
		return cache[name]
	end

	local folder = container()
	local object

	if IS_SERVER then
		object = folder:FindFirstChild(name)
		if not object then
			object = Instance.new(className)
			object.Name = name
			object.Parent = folder
		end
	else
		object = folder:WaitForChild(name, 30)
	end

	cache[name] = object
	return object
end

--- Build every declared remote. Call once on the server during boot.
function Remotes.init()
	assert(IS_SERVER, "Remotes.init is server-only")
	for _, name in ipairs(EVENTS) do
		resolve(name, "RemoteEvent")
	end
	for _, name in ipairs(FUNCTIONS) do
		resolve(name, "RemoteFunction")
	end
end

function Remotes.event(name: string): RemoteEvent
	return resolve(name, "RemoteEvent") :: RemoteEvent
end

function Remotes.fn(name: string): RemoteFunction
	return resolve(name, "RemoteFunction") :: RemoteFunction
end

return Remotes
