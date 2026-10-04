--[[
	📍 LOCATION: ServerScriptService > Services > RebirthService (ModuleScript)

	Rebirth: resets Coins and upgrades for a permanent income multiplier, Gems and Rebirth Tokens.
	Your objects, pedestals, speed, Index, Gems, Tokens, token upgrades, skins and potions are KEPT.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local RebirthService = {}
local Svc

function RebirthService.Init(registry)
	Svc = registry
end

-- free = true for the Instant Rebirth product (skips the coin requirement). Must not yield.
function RebirthService.DoRebirth(player, free)
	local data = Svc.Data.Get(player)
	if not data then
		return false, "No data"
	end
	if not free then
		local cost = Formulas.RebirthCost(data.Rebirths)
		if data.Coins < cost then
			return false, "Need " .. Format.Coins(cost)
		end
	end
	if Svc.Raid.IsInRaid(player) then
		-- never reset mid-raid; product purchases still go through after the raid ends
		Svc.Raid.EndRaidsFor(player)
	end

	Svc.Carry.DropAll(player, "rebirth")
	local rewards = Formulas.RebirthRewards(data.Rebirths)
	data.Rebirths += 1
	data.Coins = 0
	for id in pairs(data.Upgrades) do
		if id ~= "MuseumSize" and id ~= "Treadmill" then -- your pedestals & treadmill stay
			data.Upgrades[id] = 1
		end
	end
	data.GatesOpened = {}
	-- your objects and pedestals are KEPT (only Coins & upgrades reset)
	data.Gems += rewards.Gems
	data.RebirthTokens += rewards.Tokens

	Svc.Museum.Recompute(player)
	Svc.Monetization.ApplyMovement(player)
	Svc.Economy.AddCoins(player, 0) -- push currency
	Svc.Data.MarkDirty(player)
	Svc.Net.Popup(player, "Rebirth", {
		Rebirths = data.Rebirths,
		Multiplier = Formulas.RebirthMultiplier(data.Rebirths),
		Gems = rewards.Gems,
		Tokens = rewards.Tokens,
	})
	if data.Rebirths % 5 == 0 then
		Svc.Net.Announce("♻️ " .. player.DisplayName .. " reached Rebirth " .. data.Rebirths .. "!", Color3.fromRGB(120, 255, 160))
	end
	-- send them home (their upgrades reset, they may be standing in a now-locked area)
	task.defer(Svc.Museum.TeleportHome, player)
	return true
end

function RebirthService.Start()
	Svc.Net.Handle("Rebirth", function(player)
		if not Svc.Session.Throttle(player, "rebirth", 2) then
			return { ok = false, msg = "Slow down!" }
		end
		local ok, msg = RebirthService.DoRebirth(player, false)
		return { ok = ok, msg = msg }
	end)

	-- Auto Rebirth gamepass: rebirths for you as soon as you can afford it (never while carrying
	-- boxes, so a run home isn't wiped). Toggle: Settings > Auto Rebirth.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
				local data = Svc.Data.Get(player)
				if data and Svc.Session.HasPass(player, "AutoRebirth") and data.Settings.AutoRebirth ~= false
					and not Svc.Carry.IsCarrying(player) and not Svc.Raid.IsInRaid(player)
					and data.Coins >= Formulas.RebirthCost(data.Rebirths) then
					local ok = RebirthService.DoRebirth(player, false)
					if ok then
						Svc.Net.Notify(player, "Auto Rebirth! You are now Rebirth " .. data.Rebirths, "success")
					end
				end
			end
		end
	end)

	Svc.Net.Handle("BuyInstantRebirth", function(player)
		return Svc.Monetization.PromptProduct(player, "InstantRebirth")
	end)
end

return RebirthService
