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
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))

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
	return def.BaseIncome * rarity.IncomeMult * variant.Mult * (item.Z or 1)
end

-- Size entry ({ Name, Mult, ... } from GameConfig.Sizes) closest to a size multiplier.
function Formulas.SizeInfo(z)
	z = z or 1
	local best, bestDiff = GameConfig.Sizes[3], math.huge
	for _, entry in ipairs(GameConfig.Sizes) do
		local d = math.abs(entry.Mult - z)
		if d < bestDiff then
			best, bestDiff = entry, d
		end
	end
	return best
end

function Formulas.ItemName(item)
	local def = ObjectConfig.Get(item.Id)
	local variant = RarityConfig.GetVariant(item.V)
	local size = Formulas.SizeInfo(item.Z)
	local sizePrefix = size.Name ~= "Normal" and (size.Name .. " ") or ""
	return sizePrefix .. variant.Prefix .. (def and def.Name or item.Id)
end

-- Weight in kg (just for show: bigger objects weigh a LOT more).
function Formulas.ItemWeight(item)
	local def = ObjectConfig.Get(item.Id)
	local size = def and def.Size or Vector3.new(3, 3, 3)
	local base = def and def.WeightKg or (size.X * size.Y * size.Z * 0.5)
	local z = item.Z or 1
	return base * z * z * z
end

function Formulas.FormatWeight(kg)
	if kg >= 1000 then
		local t = kg / 1000
		return (t >= 100 and string.format("%d", math.floor(t)) or string.format("%.1f", t)) .. " t"
	end
	return (kg >= 10 and string.format("%d", math.floor(kg)) or string.format("%.1f", kg)) .. " kg"
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

-- Walk-speed multiplier of the equipped trail (1 if none / not owned).
function Formulas.OwnsTrail(data, passes, key)
	local cfg = MonetizationConfig.Trails[key]
	if not cfg then
		return false
	end
	if cfg.Pass then
		return (passes or {})[cfg.Pass] == true
	end
	return data.Trails ~= nil and data.Trails[key] == true
end

function Formulas.TrailSpeed(data, passes)
	local key = data.EquippedTrail
	local cfg = key and MonetizationConfig.Trails[key]
	if cfg and Formulas.OwnsTrail(data, passes, key) then
		return cfg.Speed or 1
	end
	return 1
end

-- ── Speed training ───────────────────────────────────────────────────
-- Extra walk speed from training points (x2 with the 2x Speed pass).
function Formulas.SpeedBonus(data, passes)
	local cfg = GameConfig.Training
	local bonus = math.min(cfg.MaxBonus, cfg.PointsFactor * math.sqrt(math.max(0, data.SpeedPoints or 0)))
	if passes and passes.DoubleSpeed then
		bonus *= 2
	end
	return bonus
end

-- Speed points per second while standing on your treadmill.
function Formulas.TrainingRate(data, passes)
	local rate = Formulas.UpgradeValue("Treadmill", data.Upgrades.Treadmill or 1)
	if passes and passes.DoubleSpeed then
		rate *= 2
	end
	return rate
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
	local carry = Formulas.UpgradeValue("MultiShrink", up.MultiShrink) -- carry capacity (3 → 10)
	if passes.CarryInfinite then
		carry = GameConfig.InfiniteCarry
	elseif passes.Carry5x then
		carry *= 5
	elseif passes.Carry2x then
		carry *= 2
	end
	local multi = math.min(carry, 10) -- zap several at once
	local pedestals = Formulas.UpgradeValue("MuseumSize", up.MuseumSize)
	if passes.ExtraPedestals then
		pedestals += 20
	end
	local walk = GameConfig.BaseWalkSpeed + Formulas.SpeedBonus(data, passes)
	if passes.SpeedBoots then
		walk += GameConfig.SpeedBootsBonus
	end
	walk *= Formulas.TrailSpeed(data, passes)
	return {
		WalkSpeed = walk,
		Carry = carry,
		ChargeTime = charge,
		Range = range,
		Multi = multi,
		MaxTier = TierConfig.MaxTierForRayPower(up.RayPower), -- tier you shrink at full (1x) speed
		RayPower = up.RayPower,
		Pedestals = pedestals,
		RaidReady = up.RayPower >= UpgradeConfig.Upgrades.RayPower.MaxLevel,
	}
end

-- Every zone is open to walk into (no gates). Kept as a hook in case you want locked zones later.
-- How much slower (>1) or faster (<1) than normal your ray charges on an object of `tier`.
function Formulas.PowerChargeMult(rayPower, tier)
	local t = TierConfig.Tiers[tier]
	local required = t and t.RayPowerRequired or 1
	local mult = (required / math.max(1, rayPower)) ^ GameConfig.PowerChargeExponent
	return math.clamp(mult, GameConfig.MinChargeMult, GameConfig.MaxChargeMult)
end

-- Seconds to fully charge the ray on an object of `tier` (stats from Formulas.RayStats).
function Formulas.ObjectChargeTime(stats, tier)
	return stats.ChargeTime * Formulas.PowerChargeMult(stats.RayPower or 1, tier or 1)
end

function Formulas.IsTierUnlocked(_data, _tier)
	return true
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

-- ── Boxes ────────────────────────────────────────────────────────────
-- box = { R = box rarity, T = zone tier, V = variant or nil }  (old saves: { Id, V })
function Formulas.BoxRarity(box)
	if box.R then
		return box.R, box.T or 1
	end
	local def = ObjectConfig.Get(box.Id)
	return def and def.Rarity or "Common", def and def.Tier or 1
end

-- data/passes optional: the "Box Opening" upgrade and the "Fast Boxes" pass make it quicker.
function Formulas.BoxOpenSeconds(box, data, passes)
	local cfg = GameConfig.Boxes
	local rarity, tier = Formulas.BoxRarity(box)
	local seconds = (cfg.OpenSeconds[rarity] or 10) + cfg.SecondsPerTier * tier
	seconds += cfg.VariantExtra[box.V or "Normal"] or 0
	if data and data.Upgrades then
		seconds *= Formulas.UpgradeValue("BoxSpeed", data.Upgrades.BoxSpeed or 1)
	end
	if passes and passes.FastBoxes then
		seconds *= 0.5
	end
	return math.max(1, math.floor(seconds + 0.5))
end

function Formulas.BoxName(box)
	local rarity = Formulas.BoxRarity(box)
	local variant = RarityConfig.GetVariant(box.V)
	return variant.Prefix .. rarity .. " Box"
end

function Formulas.BoxSkipGems(secondsLeft)
	return math.max(1, math.ceil(secondsLeft / GameConfig.Boxes.SecondsPerGem))
end

-- ── Misc ─────────────────────────────────────────────────────────────
function Formulas.CoinsFromMinutes(incomePerSec, minutes, floor)
	return math.max(floor or 0, math.floor((incomePerSec or 0) * 60 * minutes))
end

return Formulas
