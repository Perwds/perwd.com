--[[
	📍 LOCATION: ServerScriptService > Services > UpgradeService (ModuleScript)

	Coin upgrades (Ray Power, Charge Speed, Range, Luck, Multi-Shrink, Museum Size)
	and Rebirth-Token upgrades. Costs come from UpgradeConfig via Formulas.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local TierConfig = require(Shared.Config.TierConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)

local UpgradeService = {}
local Svc

function UpgradeService.Init(registry)
	Svc = registry
end

function UpgradeService.Start()
	Svc.Net.Handle("BuyUpgrade", function(player, id)
		local data = Svc.Data.Get(player)
		local u = type(id) == "string" and UpgradeConfig.Upgrades[id]
		if not u then
			return { ok = false }
		end
		local level = data.Upgrades[id]
		local cost = Formulas.UpgradeCost(id, level)
		if not cost then
			return { ok = false, msg = "Maxed out!" }
		end
		if not Svc.Economy.Spend(player, "Coins", cost) then
			return { ok = false, msg = "Need " .. Format.Coins(cost) }
		end
		local oldTier = TierConfig.MaxTierForRayPower(data.Upgrades.RayPower)
		data.Upgrades[id] = level + 1
		if id == "RayPower" then
			local newTier = TierConfig.MaxTierForRayPower(data.Upgrades.RayPower)
			if newTier > oldTier then
				local t = TierConfig.Tiers[newTier]
				Svc.Net.Notify(player, "⚡ You can now shrink " .. t.Name .. " objects in " .. t.Area .. "!", "success")
			end
			if data.Upgrades.RayPower >= u.MaxLevel then
				Svc.Net.Notify(player, "🏴‍☠️ MAX RAY POWER! Museum Raids unlocked (opt-in in the Museum menu).", "success")
			end
		end
		if id == "MuseumSize" or id == "MultiShrink" then
			Svc.Museum.Recompute(player)
		end
		if id == "Speed" then
			Svc.Monetization.ApplyMovement(player)
		end
		Svc.Economy.UpdateIncome(player)
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)

	Svc.Net.Handle("BuyTokenUpgrade", function(player, id)
		local data = Svc.Data.Get(player)
		local u = type(id) == "string" and UpgradeConfig.TokenUpgrades[id]
		if not u then
			return { ok = false }
		end
		local level = data.TokenUpgrades[id]
		local cost = Formulas.TokenUpgradeCost(id, level)
		if not cost then
			return { ok = false, msg = "Maxed out!" }
		end
		if not Svc.Economy.Spend(player, "RebirthTokens", cost) then
			return { ok = false, msg = "Need " .. cost .. " Rebirth Tokens" }
		end
		data.TokenUpgrades[id] = level + 1
		Svc.Economy.UpdateIncome(player)
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)
end

return UpgradeService
