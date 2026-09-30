--[[
	Client state sync.

	Two shapes go over the wire:

	  full   everything the UI needs, sent on request and after any mutation
	         that changes inventory, the index or UGC
	  tick   cash, income and pad countdowns, pushed on a short loop

	Splitting them keeps the per-second traffic to a handful of numbers while
	the expensive index/UGC payloads only move when they actually change.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)

local DataService = require(script.Parent.DataService)
local IndexService = require(script.Parent.IndexService)
local PetService = require(script.Parent.PetService)
local UgcService = require(script.Parent.UgcService)

local StateService = {}

local TICK_INTERVAL = 2

local stateSync = Net.Event("StateSync")
local notify = Net.Event("Notify")

local function petList(profile)
	local out = {}
	for uid, entry in profile.pets do
		local pet = Pets.get(entry.id)
		if not pet then
			continue
		end
		table.insert(out, {
			uid = uid,
			id = entry.id,
			name = pet.name,
			rarity = pet.rarity,
			world = pet.world,
			income = pet.income * (entry.shiny and PetService.SHINY_MULTIPLIER or 1),
			shiny = entry.shiny == true,
			locked = entry.locked == true,
			equipped = table.find(profile.equipped, uid) ~= nil,
		})
	end

	table.sort(out, function(a, b)
		if a.income == b.income then
			return a.uid < b.uid
		end
		return a.income > b.income
	end)

	return out
end

local function padList(profile)
	local out = {}
	for i = 1, Balance.Hatch.PADS_PER_PLOT do
		local state = profile.hatchPads[tostring(i)]
		table.insert(out, {
			index = i,
			busy = state ~= nil,
			rarity = state and state.rarity or nil,
			remaining = state and state.remaining or 0,
			total = state and state.total or 0,
		})
	end
	return out
end

function StateService.full(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end

	return {
		kind = "full",
		cash = profile.cash,
		income = PetService.incomeOf(profile),
		speedBonus = profile.speedBonus,
		playtime = profile.playtime,
		dailyStreak = profile.daily.streak,
		stats = profile.stats,
		worlds = profile.worlds,
		pets = petList(profile),
		equipped = profile.equipped,
		pads = padList(profile),
		index = IndexService.snapshot(profile),
		ugc = UgcService.snapshot(player),
		limits = {
			equip = Balance.Pets.EQUIP_LIMIT,
			inventory = Balance.Pets.INVENTORY_LIMIT,
			pads = Balance.Hatch.PADS_PER_PLOT,
			fuseInputs = Balance.Fuse.INPUT_COUNT,
		},
	}
end

function StateService.push(player: Player)
	local payload = StateService.full(player)
	if payload then
		stateSync:FireClient(player, payload)
	end
end

--- Coalesces bursts of mutations into one full sync on the next frame.
local queued: { [Player]: boolean } = {}

function StateService.invalidate(player: Player)
	if queued[player] then
		return
	end
	queued[player] = true
	task.defer(function()
		queued[player] = nil
		if player.Parent then
			StateService.push(player)
		end
	end)
end

function StateService.start()
	Net.handle("RequestState", function(player)
		DataService.await(player, 8)
		return StateService.full(player)
	end)

	Net.handle("EquipPet", function(player, uid, equipped)
		local ok, err = PetService.setEquipped(player, tostring(uid), equipped == true)
		if not ok then
			return { ok = false, error = err }
		end
		StateService.invalidate(player)
		return { ok = true }
	end)

	Net.handle("SellPets", function(player, uids)
		if type(uids) ~= "table" then
			return { ok = false, error = "Nothing selected" }
		end
		-- Bound the request so a malformed client cannot stall the server.
		if #uids > Balance.Pets.INVENTORY_LIMIT then
			return { ok = false, error = "Too many pets at once" }
		end

		local ok, result = PetService.sell(player, uids)
		if not ok then
			return { ok = false, error = result }
		end

		StateService.invalidate(player)
		notify:FireClient(player, "success", `Sold {result.sold} pets`)
		return { ok = true, sold = result.sold, payout = result.payout }
	end)

	-- Anything that changes the heavy payloads triggers a full resync.
	PetService.PetAdded:Connect(StateService.invalidate)
	UgcService.Unlocked:Connect(StateService.invalidate)
	DataService.ProfileLoaded:Connect(function(player)
		task.defer(StateService.push, player)
	end)

	-- Light tick for the HUD numbers and pad countdowns.
	task.spawn(function()
		while true do
			task.wait(TICK_INTERVAL)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if not profile then
					continue
				end
				stateSync:FireClient(player, {
					kind = "tick",
					cash = profile.cash,
					income = PetService.incomeOf(profile),
					pads = padList(profile),
				})
			end
		end
	end)
end

return StateService
