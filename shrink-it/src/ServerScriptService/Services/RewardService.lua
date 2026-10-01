--[[
	📍 LOCATION: ServerScriptService > Services > RewardService (ModuleScript)

	• Grant(): the ONE place every reward type is given out (never yields; safe inside ProcessReceipt).
	• Free playtime gifts (12, session-based), daily login streak, codes, Like-goal sign,
	  Gem shop, ray skins, offline earnings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local RewardConfig = require(Shared.Config.RewardConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local RewardUtil = require(Shared.RewardUtil)

local RewardService = {}
local Svc

function RewardService.Init(registry)
	Svc = registry
end

local function rollMystery(poolName)
	local pool = RewardConfig.MysteryPools[poolName]
	if not pool then
		return nil
	end
	local total = 0
	for _, e in ipairs(pool.Entries) do
		total += e.Weight
	end
	local roll = math.random() * total
	for _, e in ipairs(pool.Entries) do
		roll -= e.Weight
		if roll <= 0 then
			return e.Reward
		end
	end
	return pool.Entries[#pool.Entries].Reward
end

-- Gives a reward. Returns a description string. Never yields.
function RewardService.Grant(player, reward, source)
	local data = Svc.Data.Get(player)
	if not data or type(reward) ~= "table" then
		return ""
	end
	local t = reward.Type
	if t == "Coins" then
		Svc.Economy.AddCoins(player, reward.Amount)
	elseif t == "CoinsMinutes" then
		local amount = Formulas.CoinsFromMinutes(Svc.Economy.GetIncomePerSec(player), reward.Minutes, reward.Floor)
		Svc.Economy.AddCoins(player, amount)
		Svc.Data.MarkDirty(player)
		return Format.Coins(amount)
	elseif t == "Gems" then
		Svc.Economy.AddGems(player, reward.Amount)
	elseif t == "Tokens" then
		Svc.Economy.AddTokens(player, reward.Amount)
	elseif t == "LuckPotion" then
		Svc.Economy.AddPotion(player, "Luck", reward.Minutes)
	elseif t == "IncomePotion" then
		Svc.Economy.AddPotion(player, "Income", reward.Minutes)
	elseif t == "ServerLuck" then
		Svc.Event.ActivateServerLuck(reward.Minutes, player)
	elseif t == "RaySkin" then
		if data.RaySkins[reward.Skin] then
			Svc.Economy.AddGems(player, 100)
			Svc.Data.MarkDirty(player)
			return "Duplicate skin → 100 Gems"
		end
		data.RaySkins[reward.Skin] = true
	elseif t == "Object" then
		Svc.Museum.AddItem(player, reward.Id, reward.Variant or "Normal")
		local def = ObjectConfig.Get(reward.Id)
		if def and def.Exclusive then
			Svc.Net.Announce("🎉 " .. player.DisplayName .. " got a " .. Formulas.ItemName({ Id = reward.Id, V = reward.Variant or "Normal" }) .. "!", Color3.fromRGB(255, 120, 200))
		end
	elseif t == "Mystery" then
		local rolled = rollMystery(reward.Pool)
		if rolled then
			local text = RewardService.Grant(player, rolled, source)
			Svc.Net.Notify(player, "❓ Mystery → " .. text, "success")
			return text
		end
	elseif t == "Bundle" then
		local parts = {}
		for _, r in ipairs(reward.Rewards) do
			table.insert(parts, RewardService.Grant(player, r, source))
		end
		return table.concat(parts, " + ")
	end
	Svc.Data.MarkDirty(player)
	return (RewardUtil.Describe(reward, Svc.Economy.GetIncomePerSec(player)))
end

local function today()
	return math.floor(os.time() / 86400)
end

local function processDaily(player, data)
	local day = today()
	if data.Daily.LastDay >= day then
		return
	end
	if data.Daily.LastDay == day - 1 then
		data.Daily.Streak += 1
	else
		data.Daily.Streak = 1
	end
	data.Daily.LastDay = day
	local streak = data.Daily.Streak
	local reward = RewardConfig.Daily[((streak - 1) % #RewardConfig.Daily) + 1]
	local text = RewardService.Grant(player, reward, "daily")
	Svc.Net.Popup(player, "Daily", { Streak = streak, Text = text })
end

local function processOffline(player, data)
	if not Svc.Session.HasPass(player, "OfflineEarnings") or data.LastOnline <= 0 then
		return
	end
	local elapsed = math.min(os.time() - data.LastOnline, GameConfig.Offline.MaxSeconds)
	if elapsed < 60 then
		return
	end
	local amount = math.floor(Svc.Economy.GetIncomePerSec(player) * elapsed * GameConfig.Offline.Rate)
	if amount > 0 then
		Svc.Economy.AddCoins(player, amount)
		Svc.Net.Popup(player, "Offline", { Seconds = elapsed, Amount = amount })
	end
end

local function updateLikeSign()
	local sign = Svc.Map.LikeSign
	if not sign then
		return
	end
	local likes = RewardConfig.Likes.CurrentLikes
	local goal, reachedCodes = nil, {}
	for _, g in ipairs(RewardConfig.Likes.Goals) do
		if likes >= g.Goal then
			table.insert(reachedCodes, g.Code)
		elseif not goal then
			goal = g
		end
	end
	local gui = sign:FindFirstChild("LikeGui") or Instance.new("SurfaceGui")
	gui.Name = "LikeGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	gui:ClearAllChildren()
	gui.Parent = sign
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	bg.Parent = gui
	local function label(text, y, h, color)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(0.9, 0, h, 0)
		l.Position = UDim2.new(0.05, 0, y, 0)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = color or Color3.new(1, 1, 1)
		l.Text = text
		l.Parent = bg
		Instance.new("UIStroke", l).Thickness = 3
		return l
	end
	label("👍 LIKE THE GAME!", 0.04, 0.16, Color3.fromRGB(120, 230, 120))
	if goal then
		label(string.format("%s / %s likes", Format.Abbrev(likes), Format.Abbrev(goal.Goal)), 0.22, 0.1)
		local barBg = Instance.new("Frame")
		barBg.Size = UDim2.new(0.86, 0, 0.08, 0)
		barBg.Position = UDim2.new(0.07, 0, 0.35, 0)
		barBg.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
		barBg.Parent = bg
		Instance.new("UICorner", barBg).CornerRadius = UDim.new(0.5, 0)
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(likes / goal.Goal, 0.02, 1), 1)
		fill.BackgroundColor3 = Color3.fromRGB(90, 220, 90)
		fill.Parent = barBg
		Instance.new("UICorner", fill).CornerRadius = UDim.new(0.5, 0)
		label("Next goal unlocks a NEW CODE!", 0.46, 0.08, Color3.fromRGB(255, 220, 90))
	else
		label("ALL GOALS REACHED! THANK YOU! 💖", 0.24, 0.12, Color3.fromRGB(255, 220, 90))
	end
	label("Unlocked codes:", 0.58, 0.08)
	label(#reachedCodes > 0 and table.concat(reachedCodes, "  •  ") or "none yet...", 0.68, 0.12, Color3.fromRGB(120, 220, 255))
	label("Redeem codes in the Shop!", 0.85, 0.08, Color3.fromRGB(200, 200, 200))
end

function RewardService.OnPlayerLoaded(player, data)
	player:SetAttribute("RaySkin", data.EquippedSkin) -- every client reads this to color beams
	processOffline(player, data)
	task.delay(3, function()
		if player.Parent and Svc.Data.Get(player) then
			processDaily(player, data)
		end
	end)
end

function RewardService.Start()
	updateLikeSign()

	Svc.Net.Handle("ClaimGift", function(player, index)
		local s = Svc.Session.Get(player)
		local gift = type(index) == "number" and RewardConfig.Gifts[index]
		if not gift then
			return { ok = false }
		end
		local giftKey = tostring(index) -- string keys survive remote serialization
		if s.GiftsClaimed[giftKey] then
			return { ok = false, msg = "Already claimed!" }
		end
		if os.clock() - s.JoinClock + 2 < gift.Time then
			return { ok = false, msg = "Not ready yet!" }
		end
		s.GiftsClaimed[giftKey] = true
		local text = RewardService.Grant(player, gift.Reward, "gift")
		if gift.HugeChance and math.random() < gift.HugeChance then
			RewardService.Grant(player, RewardConfig.GiftHuge, "gift")
			text ..= " + 🎉 HUGE!"
		end
		Svc.Data.MarkDirty(player)
		return { ok = true, msg = "🎁 " .. text }
	end)

	Svc.Net.Handle("RedeemCode", function(player, code)
		local data = Svc.Data.Get(player)
		if type(code) ~= "string" or #code > 32 then
			return { ok = false, msg = "Invalid code" }
		end
		if not Svc.Session.Throttle(player, "code", 1) then
			return { ok = false, msg = "Slow down!" }
		end
		code = string.upper((string.gsub(code, "%s", "")))
		local cfg = RewardConfig.Codes[code]
		if not cfg then
			return { ok = false, msg = "Invalid code" }
		end
		if cfg.RequiresLikes and RewardConfig.Likes.CurrentLikes < cfg.RequiresLikes then
			return { ok = false, msg = "This code unlocks at " .. Format.Abbrev(cfg.RequiresLikes) .. " likes!" }
		end
		if data.RedeemedCodes[code] then
			return { ok = false, msg = "Already redeemed!" }
		end
		data.RedeemedCodes[code] = true
		local parts = {}
		for _, r in ipairs(cfg.Rewards) do
			table.insert(parts, RewardService.Grant(player, r, "code"))
		end
		return { ok = true, msg = "Code redeemed: " .. table.concat(parts, " + ") }
	end)

	Svc.Net.Handle("GemShopBuy", function(player, key)
		if type(key) ~= "string" then
			return { ok = false }
		end
		for _, item in ipairs(MonetizationConfig.GemShop) do
			if item.Key == key then
				local data = Svc.Data.Get(player)
				if item.Reward.Type == "RaySkin" and data.RaySkins[item.Reward.Skin] then
					return { ok = false, msg = "You already own this skin!" }
				end
				if not Svc.Economy.Spend(player, "Gems", item.Cost) then
					return { ok = false, msg = "Need " .. item.Cost .. " Gems" }
				end
				local text = RewardService.Grant(player, item.Reward, "gemshop")
				return { ok = true, msg = "Bought " .. text }
			end
		end
		return { ok = false }
	end)

	Svc.Net.Handle("EquipSkin", function(player, skin)
		local data = Svc.Data.Get(player)
		local cfg = type(skin) == "string" and MonetizationConfig.RaySkins[skin]
		if not cfg then
			return { ok = false }
		end
		local owned = data.RaySkins[skin] or (cfg.Pass and Svc.Session.HasPass(player, cfg.Pass))
		if not owned then
			return { ok = false, msg = "You don't own this skin!" }
		end
		data.EquippedSkin = skin
		player:SetAttribute("RaySkin", skin)
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)

	Svc.Data.AddSyncProvider(function(player, payload)
		local s = Svc.Session.Get(player)
		payload.GiftsClaimed = s and s.GiftsClaimed or {}
		payload.SessionStart = s and s.JoinServerTime or 0
		payload.Likes = RewardConfig.Likes.CurrentLikes
	end)
end

return RewardService
