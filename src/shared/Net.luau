--!nonstrict
-- Remote plumbing. The server builds the folder at boot and the client waits on
-- it, so the whole game syncs from source with no instances to set up by hand.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "FishingNet"

local Net = {}

Net.Events = {
	-- client -> server
	RequestCast = "RequestCast",
	SubmitReel = "SubmitReel",
	CancelCast = "CancelCast",
	RequestSell = "RequestSell",
	RequestBuyRod = "RequestBuyRod",
	RequestEquipRod = "RequestEquipRod",
	RequestTravel = "RequestTravel",

	-- server -> client
	BiteAlert = "BiteAlert",
	CatchResult = "CatchResult",
	ProfileChanged = "ProfileChanged",
	Notify = "Notify",
	GlobalFeed = "GlobalFeed",
	LeaderboardChanged = "LeaderboardChanged",
}

Net.Functions = {
	FetchProfile = "FetchProfile",
}

local function container(): Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if existing then
			return existing
		end

		local folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
		return folder
	end

	return ReplicatedStorage:WaitForChild(FOLDER_NAME, 30)
		or error("FishingNet never replicated; is the server script running?")
end

-- Server-only. Idempotent.
function Net.Build()
	assert(RunService:IsServer(), "Net.Build is server-only")

	local folder = container()

	for _, name in Net.Events do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end

	for _, name in Net.Functions do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end

	return folder
end

function Net.Event(name: string): RemoteEvent
	local remote = container():WaitForChild(name, 30)
	assert(remote and remote:IsA("RemoteEvent"), string.format("missing RemoteEvent %q", tostring(name)))
	return remote
end

function Net.Function(name: string): RemoteFunction
	local remote = container():WaitForChild(name, 30)
	assert(remote and remote:IsA("RemoteFunction"), string.format("missing RemoteFunction %q", tostring(name)))
	return remote
end

return Net
