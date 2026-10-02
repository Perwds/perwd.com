--[[
	📍 LOCATION: ReplicatedStorage > Shared > Remotes (ModuleScript)

	Creates (server) or waits for (client) every RemoteEvent / RemoteFunction.
	The client only ever sends INTENT; the server validates everything.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local EVENTS = {
	-- server → client
	"DataSync", -- full player state
	"CurrencySync", -- lightweight coins/gems/tokens tick
	"Notify", -- toast
	"Announce", -- big server-wide banner
	"Popup", -- modal popups (daily streak, offline earnings, ...)
	"ShrinkFX", -- play shrink animation
	"ChargeFX", -- show other players' charging beams
	"TooBig", -- server rejected: object too big
	"EventSync", -- current server event / server luck
	"RaidSync", -- raid start / zap / end
	"CarryFX", -- caught by a chaser / delivered loot
	-- client → server
	"ChargeStart",
	"ChargeCancel",
	"FireShrink",
}

local FUNCTIONS = {
	"Action", -- generic request: Action:InvokeServer("BuyUpgrade", "Range")
}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
	end
	for _, name in ipairs(EVENTS) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	for _, name in ipairs(FUNCTIONS) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteFunction")
			r.Name = name
			r.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

function Remotes.Event(name)
	return folder:WaitForChild(name)
end

function Remotes.Function(name)
	return folder:WaitForChild(name)
end

return Remotes
