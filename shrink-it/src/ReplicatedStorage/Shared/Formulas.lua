--[[
	📍 LOCATION: ReplicatedStorage > Shared > Formulas (ModuleScript)

	Shared math used by BOTH server (authoritative) and client (display only).
	Keeping it in one place guarantees the UI shows exactly what the server will do.
]]

local Shared = script.Parent
local Config = Shared:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local UpgradeConfig = require(Config:WaitForChild("UpgradeConfig"))
local TierConfig = require(Config:WaitForChild("TierConfig"))
local ObjectConfig = require(Config:WaitForChild("ObjectConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local RewardConfig = require(Config:WaitForChild("RewardConfig"))

local Formulas = {}

-- ── Upgrades ─────────────────────────────────────────────────────────
function Formulas.UpgradeValue(id, level)
	local u = UpgradeConfig.Upgrades[id]
	return u and u.Value(level) or 0
end

-- Cost to go from `level` to `level + 1` (nil if maxed)
function Formulas.UpgradeCost(id, level)
	local u = UpgradeConfig.Upgrades[id]
	if not u or level >= u.MaxLevel then
		return nil
	end
	return math.floor(u.BaseCost * u.CostGrowth ^ (level - 1))
end

function Formulas.TokenUpgradeCost(id, level)
	local u = UpgradeConfig.TokenUpgrades[id]
	if not u or level >= u.MaxLevel then
		return nil
	end
	return u.Cost(level)
end

-- ── Items ────────────────────────────────────────────────────────────
-- Coins/sec of one item BEFORE player multipliers.
function Formulas.ItemBaseIncome(item)
	local def = ObjectConfig.Get(item.Id)
	if not def then
		return 0
	end
	local rarity = RarityConfig.GetRarity(def.Rarity)
	local variant = RarityConfig.GetVariant(item.V)
	return def.BaseIncome * rarity.IncomeMult * variant.Mult
end

function Formulas.ItemName(item)
	local def = ObjectConfig.Get(item.Id)
	local variant = RarityConfig.GetVariant(item.V)
	return variant.Prefix .. (def and def.Name or item.Id)
end

-- Items sorted best-first (stable on uid). Returns a new array.
function Formulas.SortItems(items)
	local sorted = table.clone(items)
	table.sort(sorted, function(a, b)
		local ia, ib = Formulas.ItemBaseIncome(a), Formulas.ItemBaseIncome(b)
		if ia ~= ib then
			return ia > ib
		end
		return a.U < b.U
	end)
	return sorted
end

-- ── Ray stats ────────────────────────────────────────────────────────
-- passes: set of owned gamepass keys
function Formulas.RayStats(data, passes)
	passes = passes or {}
	local up = data.Upgrades
	local tokens = data.TokenUpgrades or {}
	local charge = Formulas.UpgradeValue("ChargeSpeed", up.ChargeSpeed)
	charge *= math.max(0.2, 1 - (tokens.Charge or 0) * UpgradeConfig.TokenUpgrades.Charge.PerLevel)
	if passes.VIP then
		charge *= GameConfig.VIP.ChargeMult
	end
	if passes.InstantCharge then
		charge = 0.1
	end
	local range = Formulas.UpgradeValue("Range", up.Range)
	if passes.LongRange then
		range *= 1.5
	end
	local multi = Formulas.UpgradeValue("MultiShrink", up.MultiShrink)
	if passes.MultiShrink3 then
		multi *= 3
	end
	local pedestals = Formulas.UpgradeValue("MuseumSize", up.MuseumSize)
	if passes.ExtraPedestals then
		pedestals += 20
	end
	return {
		ChargeTime = charge,
		Range = range,
		Multi = multi,
		MaxTier = TierConfig.MaxTierForRayPower(up.RayPower),
		Pedestals = pedestals,
		RaidReady = up.RayPower >= UpgradeConfig.Upgrades.RayPower.MaxLevel,
	}
end

function Formulas.IsTierUnlocked(data, tier)
	if tier <= 1 then
		return true
	end
	if TierConfig.MaxTierForRayPower(data.Upgrades.RayPower) >= tier then
		return true
	end
	return data.GatesOpened[tostring(tier)] == true
end

-- ── Rebirth ──────────────────────────────────────────────────────────
function Formulas.RebirthCost(rebirths)
	local r = UpgradeConfig.Rebirth
	return math.floor(r.BaseCost * r.CostGrowth ^ rebirths)
end

function Formulas.RebirthMultiplier(rebirths)
	return 1 + rebirths * UpgradeConfig.Rebirth.MultiplierPerRebirth
end

function Formulas.RebirthRewards(rebirths) -- rewards for performing rebirth number (rebirths + 1)
	local r = UpgradeConfig.Rebirth
	return {
		Gems = r.GemsBase * (rebirths + 1),
		Tokens = r.TokensBase + math.floor(rebirths / 2),
	}
end

-- ── Index ────────────────────────────────────────────────────────────
function Formulas.IndexKey(id, variant)
	return id .. ":" .. (variant or "Normal")
end

function Formulas.IndexProgress(data, tier)
	local normalHave, normalNeed, fullHave, fullNeed = 0, 0, 0, 0
	for _, id in ipairs(ObjectConfig.IdsForTier(tier, false)) do
		local def = ObjectConfig.Get(id)
		if def.Rarity ~= "Secret" then
			normalNeed += 1
			if data.Index[Formulas.IndexKey(id, "Normal")] then
				normalHave += 1
			end
			for _, v in ipairs(RarityConfig.VariantOrder) do
				fullNeed += 1
				if data.Index[Formulas.IndexKey(id, v)] then
					fullHave += 1
				end
			end
		end
	end
	return normalHave, normalNeed, fullHave, fullNeed
end

function Formulas.IndexIncomeBonus(data)
	local bonus = 0
	for key in pairs(data.IndexClaimed) do
		local kind = string.match(key, ":(%a+)$")
		local cfg = RewardConfig.IndexRewards[kind]
		if cfg then
			bonus += cfg.IncomeBonus
		end
	end
	return bonus
end

-- ── Misc ─────────────────────────────────────────────────────────────
function Formulas.CoinsFromMinutes(incomePerSec, minutes, floor)
	return math.max(floor or 0, math.floor((incomePerSec or 0) * 60 * minutes))
end

return Formulas
