--[[
	📍 LOCATION: ServerScriptService > Services > IndexService (ModuleScript)

	"The Index": collection book of every object × variant, with completion rewards per area.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardConfig = require(Shared.Config.RewardConfig)
local TierConfig = require(Shared.Config.TierConfig)
local Formulas = require(Shared.Formulas)

local IndexService = {}
local Svc

function IndexService.Init(registry)
	Svc = registry
end

function IndexService.Mark(player, id, variant)
	local data = Svc.Data.Get(player)
	if not data then
		return
	end
	local key = Formulas.IndexKey(id, variant)
	if not data.Index[key] then
		data.Index[key] = true
		data.IndexUnseen += 1
		Svc.Data.MarkDirty(player)
	end
end

function IndexService.Start()
	Svc.Net.Handle("ClaimIndex", function(player, tier, kind)
		local data = Svc.Data.Get(player)
		if type(tier) ~= "number" or not TierConfig.Tiers[tier] or (kind ~= "Normal" and kind ~= "Full") then
			return { ok = false }
		end
		local claimKey = tier .. ":" .. kind
		if data.IndexClaimed[claimKey] then
			return { ok = false, msg = "Already claimed!" }
		end
		local nh, nn, fh, fn = Formulas.IndexProgress(data, tier)
		local have, need = nh, nn
		if kind == "Full" then
			have, need = fh, fn
		end
		if need == 0 or have < need then
			return { ok = false, msg = string.format("Collect them all first! (%d/%d)", have, need) }
		end
		local cfg = RewardConfig.IndexRewards[kind]
		data.IndexClaimed[claimKey] = true
		Svc.Economy.AddGems(player, cfg.GemsPerTier * tier)
		Svc.Economy.UpdateIncome(player)
		Svc.Data.MarkDirty(player)
		return { ok = true, msg = string.format("Index reward: +%d Gems & +%d%% income forever!", cfg.GemsPerTier * tier, cfg.IncomeBonus * 100) }
	end)

	Svc.Net.Handle("SeenIndex", function(player)
		local data = Svc.Data.Get(player)
		data.IndexUnseen = 0
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)
end

return IndexService
