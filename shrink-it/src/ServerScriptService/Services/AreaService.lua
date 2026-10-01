--[[
	📍 LOCATION: ServerScriptService > Services > AreaService (ModuleScript)

	Area gates (Ray Power OR coins), teleports, VIP lounge & fountain.
	Gates are solid on the server; the client makes UNLOCKED gates passable locally.
	The server also checks positions so nobody can glitch into a locked area or the VIP room.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TierConfig = require(Shared.Config.TierConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local AreaService = {}
local Svc

function AreaService.Init(registry)
	Svc = registry
end

function AreaService.IsTierUnlocked(player, tier)
	local data = Svc.Data.Get(player)
	return data ~= nil and Formulas.IsTierUnlocked(data, tier)
end

local function lobbyCFrame()
	local spawn = Svc.Map.LobbySpawn
	return spawn and spawn.CFrame * CFrame.new(0, 4, 0) or CFrame.new(0, 5, 0)
end

local function areaEntryCFrame(tier)
	local area = Svc.Map.Areas[tier]
	if not area or not area.Floor then
		return nil
	end
	local f = area.Floor
	return f.CFrame * CFrame.new(0, f.Size.Y / 2 + 4, -f.Size.Z / 2 + 15)
end

function AreaService.Start()
	Svc.Net.Handle("OpenGate", function(player, tier)
		local data = Svc.Data.Get(player)
		local t = type(tier) == "number" and TierConfig.Tiers[tier]
		if not t or tier <= 1 then
			return { ok = false }
		end
		if Formulas.IsTierUnlocked(data, tier) then
			return { ok = false, msg = "Already open!" }
		end
		if not Formulas.IsTierUnlocked(data, tier - 1) then
			return { ok = false, msg = "Open " .. TierConfig.Tiers[tier - 1].Area .. " first!" }
		end
		if not Svc.Economy.Spend(player, "Coins", t.GateCost) then
			return { ok = false, msg = "Need " .. Format.Coins(t.GateCost) }
		end
		data.GatesOpened[tostring(tier)] = true
		Svc.Data.MarkDirty(player)
		Svc.Net.Notify(player, "🔓 " .. t.Area .. " is open!", "success")
		return { ok = true }
	end)

	Svc.Net.Handle("Teleport", function(player, dest)
		if not Svc.Session.Throttle(player, "tp", 2) then
			return { ok = false, msg = "Slow down!" }
		end
		local character = player.Character
		if not character then
			return { ok = false }
		end
		if dest == "Lobby" then
			character:PivotTo(lobbyCFrame())
			return { ok = true }
		elseif dest == "Museum" then
			Svc.Museum.TeleportHome(player)
			return { ok = true }
		elseif type(dest) == "number" and TierConfig.Tiers[dest] then
			if not Svc.Session.HasPass(player, "Teleport") then
				return { ok = false, msg = "Requires the Teleport gamepass!" }
			end
			if not AreaService.IsTierUnlocked(player, dest) then
				return { ok = false, msg = "That area is locked!" }
			end
			local cf = areaEntryCFrame(dest)
			if cf then
				character:PivotTo(cf)
			end
			return { ok = true }
		end
		return { ok = false }
	end)

	-- VIP fountain
	local fountain = Svc.Map.VIPFountain
	if fountain then
		fountain.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player or not Svc.Session.HasPass(player, "VIP") then
				return
			end
			local data = Svc.Data.Get(player)
			if not data or os.time() < data.VipFountainAt then
				return
			end
			data.VipFountainAt = os.time() + GameConfig.VIP.FountainCooldown
			Svc.Economy.AddGems(player, GameConfig.VIP.FountainGems)
			Svc.Net.Notify(player, "👑 VIP Fountain: +" .. GameConfig.VIP.FountainGems .. " Gems!", "success")
			Svc.Data.MarkDirty(player)
		end)
	end

	-- position enforcement (anti-glitch for gates & VIP room)
	task.spawn(function()
		while true do
			task.wait(1.5)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = Svc.Data.Get(player)
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if data and root then
					local tier = Svc.Map.GetAreaAt(root.Position)
					if tier and not Formulas.IsTierUnlocked(data, tier) then
						character:PivotTo(areaEntryCFrame(tier - 1) or lobbyCFrame())
						Svc.Net.Notify(player, "🔒 That area is locked!", "error")
					elseif Svc.Map.VIPRoom and not Svc.Session.HasPass(player, "VIP") and Svc.Map.IsInPart(Svc.Map.VIPRoom, root.Position) then
						character:PivotTo(lobbyCFrame())
						Svc.Net.Notify(player, "👑 VIP lounge is for VIP pass owners!", "error")
					end
				end
			end
		end
	end)
end

return AreaService
