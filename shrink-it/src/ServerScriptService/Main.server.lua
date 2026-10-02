--[[
	📍 LOCATION: ServerScriptService > Main (Script)

	Boots every service in order, then drives the player lifecycle:
	  PlayerAdded → Session.Create → Data.Load (session-locked) → each service's OnPlayerLoaded
	  PlayerRemoving → each service's OnPlayerRemoving → Data.Release (save + unlock)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))

local ServicesFolder = ServerScriptService:WaitForChild("Services")

-- Order matters: earlier services are loaded/started first.
local ORDER = {
	"Session",
	"Data",
	"Net",
	"Map",
	"Monetization", -- checks gamepasses before income is computed
	"Event",
	"Economy",
	"Museum",
	"Carry",
	"Index",
	"Area",
	"Spawn",
	"Shrink",
	"Upgrade",
	"Rebirth",
	"Reward",
	"Cosmetic",
	"InfinitePack",
	"Raid",
	"Leaderboard",
}

-- Every step is pcall-wrapped so one broken service can't take the whole server down.
local Registry = {}
for _, name in ipairs(ORDER) do
	local ok, result = pcall(require, ServicesFolder:WaitForChild(name .. "Service"))
	if ok then
		Registry[name] = result
	else
		warn("[ShrinkIt] Failed to load " .. name .. "Service: " .. tostring(result))
		Registry[name] = {}
	end
end

for _, name in ipairs(ORDER) do
	local svc = Registry[name]
	if svc.Init then
		local ok, err = pcall(svc.Init, Registry)
		if not ok then
			warn("[ShrinkIt] " .. name .. "Service.Init failed: " .. tostring(err))
		end
	end
end

for _, name in ipairs(ORDER) do
	local svc = Registry[name]
	if svc.Start then
		local ok, err = pcall(svc.Start)
		if not ok then
			warn("[ShrinkIt] " .. name .. "Service.Start failed: " .. tostring(err))
		end
	end
end

local function onPlayerAdded(player)
	-- 8-player game (one plot each). Roblox's Max Players setting should already stop a 9th player;
	-- this is a safety net in case it was left at the default.
	if #Players:GetPlayers() > GameConfig.MaxPlayers then
		player:Kick("This server is full (" .. GameConfig.MaxPlayers .. " players max). Please join another server!")
		return
	end
	Registry.Session.Create(player)
	local data = Registry.Data.Load(player)
	if not data or not player.Parent then
		return
	end
	for _, name in ipairs(ORDER) do
		local svc = Registry[name]
		if svc.OnPlayerLoaded then
			local ok, err = pcall(svc.OnPlayerLoaded, player, data)
			if not ok then
				warn("[ShrinkIt] " .. name .. "Service.OnPlayerLoaded failed: " .. tostring(err))
			end
		end
	end
	player:SetAttribute("DataLoaded", true)
	Registry.Data.MarkDirty(player)
end

local function onPlayerRemoving(player)
	for i = #ORDER, 1, -1 do
		local svc = Registry[ORDER[i]]
		if svc.OnPlayerRemoving then
			local ok, err = pcall(svc.OnPlayerRemoving, player)
			if not ok then
				warn("[ShrinkIt] " .. ORDER[i] .. "Service.OnPlayerRemoving failed: " .. tostring(err))
			end
		end
	end
	Registry.Data.Release(player)
	Registry.Session.Remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	Registry.Data.ReleaseAll()
end)

print("[ShrinkIt] Server ready 🔬 " .. GameConfig.Version)
