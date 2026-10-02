--[[
	📍 LOCATION: ServerScriptService > Services > UpgradeService (ModuleScript)

	Coin upgrades (Ray Power, Treadmill, Charge Speed, Range, Luck, Carry Capacity, Museum Size)
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
	-- Buys one level of a coin upgrade. Returns ok, message.
	local function buyOne(player, id)
		local data = Svc.Data.Get(player)
		local u = type(id) == "string" and UpgradeConfig.Upgrades[id]
		if not u or not data then
			return false
		end
		local level = data.Upgrades[id] or 1
		local cost = Formulas.UpgradeCost(id, level)
		if not cost then
			return false, "Maxed out!"
		end
		if not Svc.Economy.Spend(player, "Coins", cost) then
			return false, "Need " .. Format.Coins(cost)
		end
		local oldTier = TierConfig.MaxTierForRayPower(data.Upgrades.RayPower)
		data.Upgrades[id] = level + 1
		if id == "RayPower" then
			local newTier = TierConfig.MaxTierForRayPower(data.Upgrades.RayPower)
			if newTier > oldTier then
				local t = TierConfig.Tiers[newTier]
				Svc.Net.Notify(player, "⚡ " .. t.Name .. " objects in " .. t.Area .. " now shrink at full speed!", "success")
			end
			if data.Upgrades.RayPower >= u.MaxLevel then
				Svc.Net.Notify(player, "MAX RAY POWER! Museum Raids unlocked (opt-in in the Museum menu).", "success")
			end
		end
		return true
	end

	local function afterBuy(player, ids)
		if ids.MuseumSize or ids.MultiShrink then
			Svc.Museum.Recompute(player)
		end
		Svc.Economy.UpdateIncome(player)
		Svc.Data.MarkDirty(player)
	end

	Svc.Net.Handle("BuyUpgrade", function(player, id)
		local ok, msg = buyOne(player, id)
		if not ok then
			return { ok = false, msg = msg }
		end
		afterBuy(player, { [id] = true })
		return { ok = true }
	end)

	-- BUY ALL: keeps buying the cheapest upgrade you can afford until you can't afford any more.
	Svc.Net.Handle("BuyAllUpgrades", function(player)
		local data = Svc.Data.Get(player)
		if not data then
			return { ok = false }
		end
		local bought, ids = 0, {}
		for _ = 1, 1000 do
			local bestId, bestCost
			for _, id in ipairs(UpgradeConfig.Order) do
				local cost = Formulas.UpgradeCost(id, data.Upgrades[id] or 1)
				if cost and (not bestCost or cost < bestCost) then
					bestId, bestCost = id, cost
				end
			end
			if not bestId or not buyOne(player, bestId) then
				break
			end
			bought += 1
			ids[bestId] = true
		end
		if bought == 0 then
			return { ok = false, msg = "Not enough coins for any upgrade!" }
		end
		afterBuy(player, ids)
		return { ok = true, msg = "Bought " .. bought .. " upgrade level" .. (bought == 1 and "" or "s") .. "!", Count = bought }
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
