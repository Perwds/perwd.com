--[[
	📍 LOCATION: ReplicatedStorage > Shared > InfinitePackGen (ModuleScript)

	Deterministic, never-ending Infinite Pack chain.
	The same (season, index) ALWAYS produces the same tile, on server and client,
	so the UI can preview tiles and the server can trust its own generation.
]]

local Shared = script.Parent
local Config = Shared:WaitForChild("Config")
local RewardConfig = require(Config:WaitForChild("RewardConfig"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))

local Gen = {}

local cfg = RewardConfig.InfinitePack

function Gen.Season(now)
	return math.floor(now / cfg.RefreshSeconds)
end

function Gen.SecondsUntilRefresh(now)
	return cfg.RefreshSeconds - (now % cfg.RefreshSeconds)
end

function Gen.IsPaid(index)
	return cfg.Pattern[((index - 1) % #cfg.Pattern) + 1] == true
end

function Gen.ProductFor(index)
	local product = cfg.PaidTiers[1].Product
	for _, tier in ipairs(cfg.PaidTiers) do
		if index >= tier.FromIndex then
			product = tier.Product
		end
	end
	return product
end

local function pickWeighted(rng, pool)
	local total = 0
	for _, e in ipairs(pool) do
		total += e.Weight
	end
	local roll = rng:NextNumber() * total
	for _, e in ipairs(pool) do
		roll -= e.Weight
		if roll <= 0 then
			return e
		end
	end
	return pool[#pool]
end

local SKIN_CHOICES = { "Bubblegum", "Toxic", "Sunset", "Galaxy" }

local function buildReward(entry, scale, paid, index, rng)
	local kind = entry.Kind
	if kind == "CoinsMinutes" then
		return { Type = "CoinsMinutes", Minutes = math.floor(entry.Base * scale + 0.5), Floor = math.floor((paid and 10_000 or 500) * scale) }
	elseif kind == "Gems" then
		return { Type = "Gems", Amount = math.floor(entry.Base * scale) }
	elseif kind == "LuckPotion" or kind == "IncomePotion" then
		return { Type = kind, Minutes = math.min(120, math.floor(entry.Base * (1 + (scale - 1) * 0.35) + 0.5)) }
	elseif kind == "RaySkin" then
		return { Type = "RaySkin", Skin = SKIN_CHOICES[rng:NextInteger(1, #SKIN_CHOICES)] }
	elseif kind == "Mystery" then
		return { Type = "Mystery", Pool = entry.Pool }
	elseif kind == "Object" then
		return { Type = "Object", Id = entry.Id, Variant = index >= 30 and "Golden" or "Normal" }
	end
	return { Type = "Gems", Amount = 5 }
end

-- Returns { Index, Paid, Product, Reward, Milestone }
-- noPaidRandom = true for players where PolicyService says paid random items are restricted:
-- their paid tiles never contain random (Mystery) rewards.
function Gen.GetTile(season, index, noPaidRandom)
	local rng = Random.new(season * 100_003 + index * 7_919)
	local paid = Gen.IsPaid(index)
	local scale = 1 + (index - 1) * cfg.ScalePerTile
	local entry = pickWeighted(rng, paid and cfg.PaidPool or cfg.FreePool)
	local reward = buildReward(entry, scale, paid, index, rng)
	if paid and noPaidRandom and reward.Type == "Mystery" then
		reward = { Type = "Gems", Amount = math.floor(150 * scale) }
	end
	local milestone = index % cfg.MilestoneEvery == 0
	if milestone then
		reward = {
			Type = "Bundle",
			Rewards = {
				reward,
				{ Type = "Gems", Amount = math.floor(50 * scale) },
				{ Type = "Tokens", Amount = 1 },
			},
		}
	end
	return {
		Index = index,
		Paid = paid,
		Product = paid and Gen.ProductFor(index) or nil,
		Reward = reward,
		Milestone = milestone,
	}
end

function Gen.ProductInfo(productKey)
	return MonetizationConfig.Products[productKey]
end

return Gen
