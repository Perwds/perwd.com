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

	Svc.Net.Handle("AdminGive", admin(function(player, kind, amount)
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
		return { ok = true, msg = "+" .. amount .. " " .. kind }
	end))

	Svc.Net.Handle("AdminSpawnItem", admin(function(player, id, variant, mutation, size, count)
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
		return { ok = last ~= nil, msg = last and ("Spawned " .. count .. "x " .. (ObjectConfig.Get(id).Name or id)) or "Couldn't spawn (pocket full?)" }
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
