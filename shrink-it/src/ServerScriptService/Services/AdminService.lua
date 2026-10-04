--[[
	📍 LOCATION: ServerScriptService > Services > AdminService (ModuleScript)

	Admin panel (GameConfig.Admins). Every request is checked HERE on the server, so nobody else can
	use it even with exploits. Infinite cash, gems/tokens, spawn any item (variant, mutation, size),
	summon the boss, start any event.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local EventConfig = require(Shared.Config.EventConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local TierConfig = require(Shared.Config.TierConfig)

local AdminService = {}
local Svc

local INFINITE = 1e18

function AdminService.Init(registry)
	Svc = registry
end

function AdminService.IsAdmin(player)
	local cfg = GameConfig.Admins or {}
	for _, id in ipairs(cfg.UserIds or {}) do
		if player.UserId == id then
			return true
		end
	end
	local name = string.lower(player.Name) -- the USERNAME (unique), never the display name
	for _, n in ipairs(cfg.Names or {}) do
		if name == string.lower(n) then
			return true
		end
	end
	return false
end

local infinite = {} -- [player] = true while Infinite Cash is on

local function admin(fn)
	return function(player, ...)
		if not AdminService.IsAdmin(player) then
			return { ok = false, msg = "Admins only." }
		end
		return fn(player, ...)
	end
end

-- who an admin action is for: the chosen player (by UserId) if they're in the server, else the admin
local function targetOf(admin, userId)
	local target = type(userId) == "number" and Players:GetPlayerByUserId(userId)
	return target or admin
end

local function topUp(player)
	local data = Svc.Data.Get(player)
	if data and (data.Coins or 0) < INFINITE then
		Svc.Economy.AddCoins(player, INFINITE - (data.Coins or 0))
	end
end

function AdminService.OnPlayerLoaded(player)
	if AdminService.IsAdmin(player) then
		player:SetAttribute("IsAdmin", true)
	end
end

function AdminService.OnPlayerRemoving(player)
	infinite[player] = nil
end

function AdminService.Start()
	Svc.Net.Handle("AdminCheck", function(player)
		return { ok = AdminService.IsAdmin(player) }
	end)

	Svc.Net.Handle("AdminInfiniteCash", admin(function(player, on)
		infinite[player] = on == true or nil
		if on then
			topUp(player)
		end
		return { ok = true, msg = on and "Infinite Cash ON" or "Infinite Cash OFF" }
	end))

	Svc.Net.Handle("AdminGive", admin(function(adminPlayer, kind, amount, userId)
		local player = targetOf(adminPlayer, userId)
		amount = tonumber(amount)
		if not amount or amount ~= amount or amount <= 0 then
			return { ok = false }
		end
		amount = math.min(amount, INFINITE)
		if kind == "Coins" then
			Svc.Economy.AddCoins(player, amount)
		elseif kind == "Gems" then
			Svc.Economy.AddGems(player, amount)
		elseif kind == "Tokens" then
			Svc.Economy.AddTokens(player, amount)
		elseif kind == "Samples" then
			local data = Svc.Data.Get(player)
			data.Samples = (data.Samples or 0) + amount
			Svc.Data.MarkDirty(player)
		else
			return { ok = false }
		end
		return { ok = true, msg = "+" .. amount .. " " .. kind .. (player ~= adminPlayer and (" to " .. player.DisplayName) or "") }
	end))

	Svc.Net.Handle("AdminSpawnItem", admin(function(adminPlayer, id, variant, mutation, size, count, userId)
		local player = targetOf(adminPlayer, userId)
		if type(id) ~= "string" or not ObjectConfig.Get(id) then
			return { ok = false, msg = "Unknown item" }
		end
		variant = (type(variant) == "string" and RarityConfig.Variants[variant]) and variant or "Normal"
		if type(mutation) ~= "string" or not MutationConfig.Mutations[mutation] then
			mutation = nil
		end
		size = math.clamp(tonumber(size) or 1, 0.25, 100)
		count = math.clamp(math.floor(tonumber(count) or 1), 1, 50)
		local last
		for _ = 1, count do
			last = Svc.Museum.AddItem(player, id, variant, { Z = size, M = mutation }, true)
		end
		if Svc.Museum.Recompute then
			pcall(Svc.Museum.Recompute, player)
		end
		Svc.Data.MarkDirty(player)
		return { ok = last ~= nil, msg = last and ("Spawned " .. count .. "x " .. (ObjectConfig.Get(id).Name or id) .. (player ~= adminPlayer and (" for " .. player.DisplayName) or "")) or "Couldn't spawn (pocket full?)" }
	end))

	-- give a gamepass for free (kept forever, like a gift)
	Svc.Net.Handle("AdminGrantPass", admin(function(adminPlayer, passKey, userId)
		local player = targetOf(adminPlayer, userId)
		if type(passKey) ~= "string" or not MonetizationConfig.GamePasses[passKey] then
			return { ok = false }
		end
		local data = Svc.Data.Get(player)
		local s = Svc.Session.Get(player)
		if not data or not s then
			return { ok = false }
		end
		data.GiftedPasses[passKey] = true
		s.Passes[passKey] = true
		Svc.Monetization.ApplyMovement(player)
		Svc.Museum.Recompute(player)
		Svc.Data.MarkDirty(player)
		return { ok = true, msg = MonetizationConfig.GamePasses[passKey].Name .. " given to " .. player.DisplayName }
	end))

	-- every upgrade to max
	Svc.Net.Handle("AdminMaxUpgrades", admin(function(adminPlayer, userId)
		local player = targetOf(adminPlayer, userId)
		local data = Svc.Data.Get(player)
		if not data then
			return { ok = false }
		end
		for id, u in pairs(UpgradeConfig.Upgrades) do
			if u.MaxLevel then
				data.Upgrades[id] = u.MaxLevel
			end
		end
		Svc.Museum.Recompute(player)
		Svc.Economy.UpdateIncome(player)
		Svc.Monetization.ApplyMovement(player)
		Svc.Data.MarkDirty(player)
		return { ok = true, msg = "Maxed every upgrade for " .. player.DisplayName }
	end))

	-- clear every unplaced item
	Svc.Net.Handle("AdminClearPocket", admin(function(adminPlayer, userId)
		local player = targetOf(adminPlayer, userId)
		local data = Svc.Data.Get(player)
		if not data then
			return { ok = false }
		end
		local placed = {}
		for _, slot in pairs(data.Slots) do
			if slot.U then
				placed[slot.U] = true
			end
		end
		local kept = {}
		for _, item in ipairs(data.Items) do
			if placed[item.U] then
				table.insert(kept, item)
			end
		end
		local removed = #data.Items - #kept
		data.Items = kept
		Svc.Museum.Recompute(player)
		Svc.Data.MarkDirty(player)
		return { ok = true, msg = "Removed " .. removed .. " unplaced items" }
	end))

	-- teleport yourself to a zone (or to a player)
	Svc.Net.Handle("AdminTeleport", admin(function(player, dest)
		local character = player.Character
		if not character then
			return { ok = false }
		end
		if type(dest) == "number" and TierConfig.Tiers[dest] then
			local cf = Svc.Map.ZoneStartCFrame(dest)
			if cf then
				character:PivotTo(cf)
				return { ok = true }
			end
		elseif type(dest) == "string" then
			local other = Players:GetPlayerByUserId(tonumber(dest) or 0)
			local root = other and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if root then
				character:PivotTo(root.CFrame * CFrame.new(0, 0, 5))
				return { ok = true }
			end
		end
		return { ok = false }
	end))

	-- chasers can't catch you
	Svc.Net.Handle("AdminGod", admin(function(player, on)
		player:SetAttribute("AdminGod", on == true or nil)
		return { ok = true, msg = on and "Chasers can't catch you now" or "God mode off" }
	end))

	Svc.Net.Handle("AdminSummonBoss", admin(function()
		local ok = Svc.Boss.SummonNow and Svc.Boss.SummonNow()
		return { ok = ok == true, msg = ok and "Boss incoming!" or "Boss is already here." }
	end))

	Svc.Net.Handle("AdminStartEvent", admin(function(_player, key)
		local ev = type(key) == "string" and EventConfig.Events[key]
		if not ev then
			return { ok = false }
		end
		Svc.Event._forced = { Key = key, Until = os.time() + (ev.Duration or 300) }
		return { ok = true, msg = ev.Name .. " started!" }
	end))

	-- Infinite Cash: keep the wallet full
	task.spawn(function()
		while true do
			task.wait(1)
			for player in pairs(infinite) do
				if player.Parent == Players then
					pcall(topUp, player)
				else
					infinite[player] = nil
				end
			end
		end
	end)
end

return AdminService
