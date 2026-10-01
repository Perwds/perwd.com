--[[
	📍 LOCATION: ServerScriptService > Services > EconomyService (ModuleScript)

	Currencies, multipliers, luck, potions and the 1-second income tick.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local EconomyService = {}
local Svc

local MAX_SAFE = 2 ^ 53

function EconomyService.Init(registry)
	Svc = registry
end

function EconomyService.GetIncomeMultiplier(player)
	local data = Svc.Data.Get(player)
	if not data then
		return 1
	end
	local m = Formulas.RebirthMultiplier(data.Rebirths)
	m *= 1 + data.TokenUpgrades.Income * UpgradeConfig.TokenUpgrades.Income.PerLevel
	m *= 1 + Formulas.IndexIncomeBonus(data)
	if Svc.Session.HasPass(player, "DoubleCoins") then
		m *= 2
	end
	if Svc.Session.HasPass(player, "VIP") then
		m *= GameConfig.VIP.IncomeMult
	end
	if data.Potions.Income > os.time() then
		m *= GameConfig.IncomePotionMult
	end
	return m
end

function EconomyService.GetLuckMultiplier(player)
	local data = Svc.Data.Get(player)
	if not data then
		return 1
	end
	local luck = Formulas.UpgradeValue("Luck", data.Upgrades.Luck)
	luck *= 1 + data.TokenUpgrades.Luck * UpgradeConfig.TokenUpgrades.Luck.PerLevel
	if Svc.Session.HasPass(player, "DoubleLuck") then
		luck *= 2
	end
	if Svc.Session.HasPass(player, "VIP") then
		luck *= GameConfig.VIP.LuckMult
	end
	if data.Potions.Luck > os.time() then
		luck *= GameConfig.LuckPotionMult
	end
	luck *= Svc.Event.GetServerLuckMult()
	return luck
end

-- Per-variant multipliers this player contributes to spawns near them.
function EconomyService.GetVariantMults(player)
	local luck = EconomyService.GetLuckMultiplier(player)
	local m = { Golden = luck, Diamond = luck, Rainbow = luck, Cosmic = luck }
	if Svc.Session.HasPass(player, "GoldenRay") then
		m.Golden *= 2
		m.Diamond *= 2
	end
	if Svc.Session.HasPass(player, "CosmicHunter") then
		m.Cosmic *= 2
	end
	return m
end

function EconomyService.GetIncomePerSec(player)
	local s = Svc.Session.Get(player)
	if not s then
		return 0
	end
	return s.BaseIncome * EconomyService.GetIncomeMultiplier(player)
end

local function pushCurrency(player)
	local data = Svc.Data.Get(player)
	local s = Svc.Session.Get(player)
	if not data or not s then
		return
	end
	Remotes.Event("CurrencySync"):FireClient(player, data.Coins, data.Gems, data.RebirthTokens, s.IncomePerSec)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Coins.Value = Format.Abbrev(data.Coins)
		ls.Rebirths.Value = data.Rebirths
	end
end

function EconomyService.AddCoins(player, amount)
	local data = Svc.Data.Get(player)
	if not data or amount ~= amount then
		return
	end
	data.Coins = math.min(MAX_SAFE * 1e6, math.max(0, data.Coins + amount))
	pushCurrency(player)
end

function EconomyService.AddGems(player, amount)
	local data = Svc.Data.Get(player)
	if not data then
		return
	end
	data.Gems = math.max(0, math.floor(data.Gems + amount))
	pushCurrency(player)
end

function EconomyService.AddTokens(player, amount)
	local data = Svc.Data.Get(player)
	if not data then
		return
	end
	data.RebirthTokens = math.max(0, math.floor(data.RebirthTokens + amount))
	pushCurrency(player)
end

-- currency: "Coins" | "Gems" | "RebirthTokens". Returns true if paid.
function EconomyService.Spend(player, currency, amount)
	local data = Svc.Data.Get(player)
	if not data or type(amount) ~= "number" or amount < 0 then
		return false
	end
	if (data[currency] or 0) < amount then
		return false
	end
	data[currency] -= amount
	pushCurrency(player)
	return true
end

function EconomyService.AddPotion(player, kind, minutes)
	local data = Svc.Data.Get(player)
	if not data or not data.Potions[kind] then
		return
	end
	data.Potions[kind] = math.max(data.Potions[kind], os.time()) + minutes * 60
	EconomyService.UpdateIncome(player)
	Svc.Data.MarkDirty(player)
end

function EconomyService.UpdateIncome(player)
	local s = Svc.Session.Get(player)
	if s then
		s.IncomePerSec = EconomyService.GetIncomePerSec(player)
	end
end

function EconomyService.OnPlayerLoaded(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Parent = ls
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = ls
	ls.Parent = player
end

function EconomyService.Start()
	Svc.Data.AddSyncProvider(function(player, payload)
		local s = Svc.Session.Get(player)
		local data = Svc.Data.Get(player)
		payload.IncomePerSec = s and s.IncomePerSec or 0
		payload.Multipliers = {
			Income = EconomyService.GetIncomeMultiplier(player),
			Luck = EconomyService.GetLuckMultiplier(player),
		}
		payload.Stats = Formulas.RayStats(data, s and s.Passes or {})
		payload.ServerTime = os.time()
	end)

	task.spawn(function()
		local tick = 0
		while true do
			task.wait(1)
			tick += 1
			for player, s in pairs(Svc.Session.All()) do
				local data = Svc.Data.Get(player)
				if data and player.Parent then
					s.IncomePerSec = EconomyService.GetIncomePerSec(player)
					data.Coins = math.min(MAX_SAFE * 1e6, data.Coins + s.IncomePerSec)
					pushCurrency(player)
					if tick % 5 == 0 then
						Svc.Museum.UpdateIncomeAttributes(player)
					end
					if tick % 10 == 0 then
						Svc.Data.MarkDirty(player) -- keeps potion timers / multipliers fresh
					end
				end
			end
		end
	end)
end

return EconomyService
