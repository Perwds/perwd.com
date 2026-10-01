--[[
	📍 LOCATION: ReplicatedStorage > Shared > RewardUtil (ModuleScript)

	Human-readable descriptions & odds for reward tables (shared by server + UI).
	Granting happens on the server in RewardService.
]]

local Shared = script.Parent
local Config = Shared:WaitForChild("Config")
local Format = require(Shared:WaitForChild("Format"))
local Formulas = require(Shared:WaitForChild("Formulas"))
local ObjectConfig = require(Config:WaitForChild("ObjectConfig"))
local RarityConfig = require(Config:WaitForChild("RarityConfig"))
local RewardConfig = require(Config:WaitForChild("RewardConfig"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))

local RewardUtil = {}

-- Returns: text, emoji
function RewardUtil.Describe(reward, incomePerSec)
	local t = reward.Type
	if t == "Coins" then
		return Format.Coins(reward.Amount), "💵"
	elseif t == "CoinsMinutes" then
		local amount = Formulas.CoinsFromMinutes(incomePerSec or 0, reward.Minutes, reward.Floor)
		return Format.Coins(amount), "💵"
	elseif t == "Gems" then
		return Format.Abbrev(reward.Amount) .. " Gems", "💎"
	elseif t == "Tokens" then
		return reward.Amount .. " Rebirth Token" .. (reward.Amount == 1 and "" or "s"), "♻️"
	elseif t == "LuckPotion" then
		return "Luck Potion " .. reward.Minutes .. "m", "🧪"
	elseif t == "IncomePotion" then
		return "2x Income " .. reward.Minutes .. "m", "⚗️"
	elseif t == "ServerLuck" then
		return "Server Luck " .. reward.Minutes .. "m", "🌠"
	elseif t == "RaySkin" then
		local skin = MonetizationConfig.RaySkins[reward.Skin]
		return (skin and skin.Name or reward.Skin) .. " Ray Skin", "🔫"
	elseif t == "Object" then
		local def = ObjectConfig.Get(reward.Id)
		local variant = RarityConfig.GetVariant(reward.Variant)
		return variant.Prefix .. (def and def.Name or reward.Id), def and def.Emoji or "📦"
	elseif t == "Mystery" then
		local pool = RewardConfig.MysteryPools[reward.Pool]
		return pool and pool.Name or "Mystery", "❓"
	elseif t == "Bundle" then
		local parts = {}
		local emoji = "🎁"
		for i, r in ipairs(reward.Rewards) do
			local text, e = RewardUtil.Describe(r, incomePerSec)
			table.insert(parts, text)
			if i == 1 then
				emoji = e
			end
		end
		return table.concat(parts, " + "), emoji
	end
	return "???", "❔"
end

-- Odds for a mystery pool: { { Text, Emoji, Percent } }
function RewardUtil.Odds(poolName, incomePerSec)
	local pool = RewardConfig.MysteryPools[poolName]
	if not pool then
		return {}
	end
	local total = 0
	for _, e in ipairs(pool.Entries) do
		total += e.Weight
	end
	local out = {}
	for _, e in ipairs(pool.Entries) do
		local text, emoji = RewardUtil.Describe(e.Reward, incomePerSec)
		table.insert(out, { Text = text, Emoji = emoji, Percent = e.Weight / total * 100 })
	end
	return out
end

-- Does this reward (or anything inside it) involve randomness?
function RewardUtil.IsRandom(reward)
	if reward.Type == "Mystery" then
		return true
	end
	if reward.Type == "Bundle" then
		for _, r in ipairs(reward.Rewards) do
			if RewardUtil.IsRandom(r) then
				return true
			end
		end
	end
	return false
end

return RewardUtil
