--[[
	📍 LOCATION: ServerScriptService > Services > RaidService (ModuleScript)

	Endgame "Museum Raid" (opt-in PvP):
	  • Both players must have Raids ENABLED (toggle in Museum menu).
	  • Raider needs MAX Ray Power (or an active revenge window against the target).
	  • Raider charges the ray on the target's MuseumBuilding (GameConfig.Raid.BuildingChargeTime).
	  • For Raid.Duration seconds the raider zaps the victim's pedestals to steal COPIES
	    (victim loses NOTHING). Max copies per raid; revenge raids get a bonus.
	  • Afterwards the victim gets a shield (longer with Raid Shield pass) and a revenge window.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local RaidService = {}
local Svc

local raids = {} -- [raider] = { Victim, Plot, EndsAt, Copies, Max, Revenge, Copied = {uid=true}, Token }
local beingRaided = {} -- [victim] = raider

local CFG = GameConfig.Raid

function RaidService.Init(registry)
	Svc = registry
end

function RaidService.IsInRaid(player)
	return raids[player] ~= nil or beingRaided[player] ~= nil
end

local function hasRevenge(raiderData, victim)
	local expiry = raiderData.Raid.Revenge[tostring(victim.UserId)]
	return expiry ~= nil and expiry > os.time()
end

local function endRaid(raider, reason)
	local raid = raids[raider]
	if not raid then
		return
	end
	raids[raider] = nil
	local victim = raid.Victim
	beingRaided[victim] = nil

	local raiderData = Svc.Data.Get(raider)
	local victimData = Svc.Data.Get(victim)
	if raiderData and raid.Copies > 0 then
		raiderData.RaidsWon += 1
		if raid.Revenge then
			local gems = CFG.RevengeGemBonus * (Svc.Session.HasPass(raider, "RaidShield") and 2 or 1)
			Svc.Economy.AddGems(raider, gems)
			Svc.Net.Notify(raider, "😈 REVENGE! +" .. gems .. " Gems", "success")
		end
		Svc.Data.MarkDirty(raider)
	end
	if raiderData and raid.Revenge then
		raiderData.Raid.Revenge[tostring(victim.UserId)] = nil
	end
	Svc.Data.MarkDirty(raider)
	if victimData then
		local shield = Svc.Session.HasPass(victim, "RaidShield") and CFG.ShieldTimeWithPass or CFG.ShieldTime
		victimData.Raid.ShieldUntil = os.time() + shield
		if not raid.Revenge and raider.Parent then
			victimData.Raid.Revenge[tostring(raider.UserId)] = os.time() + CFG.RevengeWindow
			Svc.Net.Notify(victim, "🛡️ Raid over! You lost nothing. REVENGE window open on " .. raider.DisplayName .. " for " .. math.floor(CFG.RevengeWindow / 60) .. "m (bonus Gems!)", "info")
		end
		Svc.Data.MarkDirty(victim)
	end
	Remotes.Event("RaidSync"):FireAllClients({
		Type = "End",
		Raider = raider,
		Victim = victim,
		PlotId = raid.Plot.Id,
		Copies = raid.Copies,
		Reason = reason,
	})
end

function RaidService.EndRaidsFor(player)
	if raids[player] then
		endRaid(player, "left")
	end
	local raider = beingRaided[player]
	if raider then
		endRaid(raider, "left")
	end
end

function RaidService.TryStartRaid(raider, building, root)
	local raiderData = Svc.Data.Get(raider)
	local plotId = building:GetAttribute("PlotId")
	local plot = plotId and Svc.Map.Plots[plotId]
	local victim = plot and Svc.Museum.GetPlotOwner(plotId)
	if not raiderData or not victim then
		return
	end
	local victimData = Svc.Data.Get(victim)
	local function fail(msg)
		Svc.Net.Notify(raider, msg, "error")
	end
	if victim == raider then
		return fail("You can't raid your own museum!")
	end
	if not victimData then
		return
	end
	if not raiderData.Settings.RaidEnabled then
		return fail("Turn on Raids in the Museum menu first!")
	end
	if not victimData.Settings.RaidEnabled then
		return fail(victim.DisplayName .. " has raids turned OFF.")
	end
	local revenge = hasRevenge(raiderData, victim)
	local stats = Formulas.RayStats(raiderData, Svc.Session.Get(raider).Passes)
	if not stats.RaidReady and not revenge then
		return fail("Raids require MAX Ray Power!")
	end
	if not revenge and victimData.Raid.ShieldUntil > os.time() then
		return fail("🛡️ " .. victim.DisplayName .. " is shielded for " .. math.ceil((victimData.Raid.ShieldUntil - os.time()) / 60) .. "m")
	end
	if not revenge and os.time() - raiderData.Raid.LastRaid < CFG.Cooldown then
		return fail("Raid cooldown: " .. math.ceil((CFG.Cooldown - (os.time() - raiderData.Raid.LastRaid)) / 60) .. "m")
	end
	if raids[raider] or beingRaided[raider] or beingRaided[victim] or raids[victim] then
		return fail("Someone is already in a raid!")
	end
	local _, size = building:GetBoundingBox()
	if (building:GetPivot().Position - root.Position).Magnitude > CFG.ZapRange + size.Magnitude / 2 then
		return fail("Too far away!")
	end

	raiderData.Raid.LastRaid = os.time()
	local token = {}
	raids[raider] = {
		Victim = victim,
		Plot = plot,
		EndsAt = os.time() + CFG.Duration,
		Copies = 0,
		Max = CFG.MaxCopies * (revenge and CFG.RevengeCopyBonus or 1),
		Revenge = revenge,
		Copied = {},
		Token = token,
	}
	beingRaided[victim] = raider
	Remotes.Event("RaidSync"):FireAllClients({
		Type = "Start",
		Raider = raider,
		Victim = victim,
		PlotId = plotId,
		EndsAt = os.time() + CFG.Duration,
		Max = raids[raider].Max,
		Revenge = revenge,
	})
	Svc.Net.Notify(victim, "⚠️ " .. raider.DisplayName .. " is RAIDING your museum! (You lose nothing - they only copy)", "error")
	Svc.Net.Notify(raider, "🏴‍☠️ Raid started! Zap their objects to copy them!", "success")
	Svc.Data.MarkDirty(raider)
	Svc.Data.MarkDirty(victim)
	task.delay(CFG.Duration, function()
		local raid = raids[raider]
		if raid and raid.Token == token then
			endRaid(raider, "time")
		end
	end)
end

function RaidService.TryZap(raider, pedestal, root)
	local raid = raids[raider]
	if not raid then
		return
	end
	if not pedestal:IsDescendantOf(raid.Plot.Model) then
		return Svc.Net.Notify(raider, "That's not the museum you're raiding!", "error")
	end
	if (pedestal:GetPivot().Position - root.Position).Magnitude > CFG.ZapRange then
		return Svc.Net.Notify(raider, "Too far away!", "error")
	end
	local slot = pedestal:GetAttribute("PedestalSlot")
	local item = Svc.Museum.GetSlotItem(raid.Victim, slot)
	if not item then
		return
	end
	if raid.Copied[item.U] then
		return Svc.Net.Notify(raider, "You already copied that one!", "error")
	end
	raid.Copied[item.U] = true
	raid.Copies += 1
	Svc.Museum.AddItem(raider, item.Id, item.V, { Stolen = true })
	local display = pedestal:FindFirstChild("Display")
	if display then
		Remotes.Event("ShrinkFX"):FireAllClients(display, raider, item.V, true)
	end
	Remotes.Event("RaidSync"):FireAllClients({ Type = "Zap", Raider = raider, Victim = raid.Victim, Copies = raid.Copies, Max = raid.Max })
	Svc.Net.Notify(raider, "📋 Copied " .. Formulas.ItemName(item) .. "! (" .. raid.Copies .. "/" .. raid.Max .. ")", "shrink")
	if raid.Copies >= raid.Max then
		endRaid(raider, "max")
	end
end

function RaidService.OnPlayerRemoving(player)
	RaidService.EndRaidsFor(player)
end

function RaidService.Start()
	Svc.Net.Handle("SetRaidEnabled", function(player, on)
		local data = Svc.Data.Get(player)
		if os.time() - data.Raid.LastToggle < CFG.ToggleCooldown then
			return { ok = false, msg = "Wait a bit before toggling again." }
		end
		if RaidService.IsInRaid(player) then
			return { ok = false, msg = "Can't toggle during a raid!" }
		end
		data.Raid.LastToggle = os.time()
		data.Settings.RaidEnabled = on == true
		player:SetAttribute("RaidEnabled", data.Settings.RaidEnabled)
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)

	Svc.Data.AddSyncProvider(function(player, payload)
		local raid = raids[player]
		payload.ActiveRaid = raid and { VictimName = raid.Victim.DisplayName, EndsAt = raid.EndsAt, Copies = raid.Copies, Max = raid.Max } or nil
		local raider = beingRaided[player]
		payload.BeingRaidedBy = raider and raider.DisplayName or nil
		-- revenge targets with names (only players in this server)
		local revenge = {}
		local data = Svc.Data.Get(player)
		if data then
			for uid, expiry in pairs(data.Raid.Revenge) do
				local target = Players:GetPlayerByUserId(tonumber(uid))
				if expiry > os.time() and target then
					table.insert(revenge, { Name = target.DisplayName, Expires = expiry })
				end
			end
		end
		payload.RevengeTargets = revenge
	end)
end

function RaidService.OnPlayerLoaded(player, data)
	player:SetAttribute("RaidEnabled", data.Settings.RaidEnabled)
	-- prune expired revenge entries
	for uid, expiry in pairs(data.Raid.Revenge) do
		if expiry <= os.time() then
			data.Raid.Revenge[uid] = nil
		end
	end
end

return RaidService
