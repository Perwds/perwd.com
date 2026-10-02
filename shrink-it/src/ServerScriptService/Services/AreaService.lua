--[[
	📍 LOCATION: ServerScriptService > Services > AreaService (ModuleScript)

	Zones are always open (no gates, no coin cost). This service handles:
	  • Teleports (Teleport gamepass → start of any zone; anyone → base / own museum),
	    blocked while you're carrying loot so nobody can skip the run home.
	  • VIP lounge enforcement + VIP gem fountain.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TierConfig = require(Shared.Config.TierConfig)

local AreaService = {}
local Svc

function AreaService.Init(registry)
	Svc = registry
end

-- Zones are always open; kept so other services can ask.
function AreaService.IsTierUnlocked(_player, _tier)
	return true
end

local function baseCFrame()
	local spawn = Svc.Map.LobbySpawn
	return spawn and spawn.CFrame * CFrame.new(0, 4, 0) or CFrame.new(0, 5, -60)
end

function AreaService.Start()
	Svc.Net.Handle("Teleport", function(player, dest)
		if not Svc.Session.Throttle(player, "tp", 2) then
			return { ok = false, msg = "Slow down!" }
		end
		local character = player.Character
		if not character then
			return { ok = false }
		end
		if Svc.Carry.IsCarrying(player) then
			return { ok = false, msg = "No teleporting while carrying loot — run it home!" }
		end
		if dest == "Lobby" or dest == "Base" then
			character:PivotTo(baseCFrame())
			return { ok = true }
		elseif dest == "Museum" then
			Svc.Museum.TeleportHome(player)
			return { ok = true }
		elseif type(dest) == "number" and TierConfig.Tiers[dest] then
			if not Svc.Session.HasPass(player, "Teleport") then
				return { ok = false, msg = "Requires the Teleport gamepass!" }
			end
			local cf = Svc.Map.ZoneStartCFrame(dest)
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
			Svc.Net.Notify(player, "VIP Fountain: +" .. GameConfig.VIP.FountainGems .. " Gems!", "success")
			Svc.Data.MarkDirty(player)
		end)
	end

	-- VIP lounge enforcement (the door is only passable on VIP clients; this catches glitchers)
	task.spawn(function()
		while true do
			task.wait(1.5)
			for _, player in ipairs(Players:GetPlayers()) do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and Svc.Map.VIPRoom and not Svc.Session.HasPass(player, "VIP") and Svc.Map.IsInPart(Svc.Map.VIPRoom, root.Position) then
					character:PivotTo(baseCFrame())
					Svc.Net.Notify(player, "The VIP lounge is for VIP pass owners!", "error")
				end
			end
		end
	end)
end

return AreaService
