--[[
	The Pet Index.

	Discovering a pet for the first time flips its slot on permanently, even
	if the pet is later sold. Completing a world's eight unlocks a claimable
	cash + speed reward, and may unlock a UGC item.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

local IndexService = {}

IndexService.TOTAL = Pets.INDEXED_COUNT

local notify = Net.Event("Notify")

function IndexService.totalUnlocked(profile): number
	local count = 0
	for petId in profile.index do
		local pet = Pets.get(petId)
		if pet and not pet.limited then
			count += 1
		end
	end
	return count
end

function IndexService.worldProgress(profile, world: string): (number, number)
	local roster = Pets.forWorld(world)
	if not roster then
		return 0, 0
	end
	local found = 0
	for _, pet in roster do
		if profile.index[pet.id] then
			found += 1
		end
	end
	return found, #roster
end

function IndexService.isWorldComplete(profile, world: string): boolean
	local found, total = IndexService.worldProgress(profile, world)
	return total > 0 and found >= total
end

--- Marks a pet discovered. Returns true only the first time.
function IndexService.discover(player: Player, petId: string): boolean
	local profile = DataService.get(player)
	local pet = Pets.get(petId)
	if not profile or not pet then
		return false
	end
	if profile.index[petId] then
		return false
	end

	profile.index[petId] = true
	DataService.markDirty(player)

	notify:FireClient(player, "index", `New in the index: {pet.name}!`)

	-- Deferred so UgcService sees the freshly written index entry.
	task.defer(function()
		local UgcService = require(script.Parent.UgcService)
		UgcService.checkIndex(player)
		UgcService.checkHatch(player, petId)
	end)

	return true
end

--[[
	Claims a completed world's reward: the cash and speed shown on the Pet
	Index reward panel. Claimable once per world.
]]
function IndexService.claimReward(player: Player, world: string)
	local profile = DataService.get(player)
	if not profile then
		return { ok = false, error = "Still loading" }
	end
	if not Worlds.get(world) then
		return { ok = false, error = "Unknown world" }
	end
	if profile.indexClaimed[world] then
		return { ok = false, error = "Already claimed" }
	end

	local found, total = IndexService.worldProgress(profile, world)
	if found < total then
		return { ok = false, error = `{found}/{total} -- keep hatching` }
	end

	local order = Worlds.get(world).order
	local cash = Balance.Rewards.INDEX_CASH * (10 ^ (order - 1))
	local speed = Balance.Rewards.INDEX_SPEED

	profile.indexClaimed[world] = true
	profile.speedBonus += speed
	PetService.addCash(player, cash)
	DataService.markDirty(player)

	-- Apply the new speed immediately rather than on next respawn.
	task.defer(function()
		local CarryService = require(script.Parent.CarryService)
		CarryService.refreshSpeed(player)
	end)

	return { ok = true, cash = cash, speed = speed }
end

--- Everything the Pet Index UI needs for one world.
function IndexService.snapshot(profile)
	local worlds = {}

	for _, world in Worlds.Order do
		local found, total = IndexService.worldProgress(profile, world)
		local slots = {}
		for _, pet in Pets.forWorld(world) do
			table.insert(slots, {
				id = pet.id,
				name = pet.name,
				rarity = pet.rarity,
				income = pet.income,
				known = profile.index[pet.id] == true,
			})
		end

		table.insert(worlds, {
			world = world,
			display = Worlds.get(world).display,
			found = found,
			total = total,
			claimed = profile.indexClaimed[world] == true,
			unlocked = profile.worlds[world] == true,
			slots = slots,
		})
	end

	local limited = {}
	for _, pet in Pets.Limited do
		table.insert(limited, {
			id = pet.id,
			name = pet.name,
			rarity = pet.rarity,
			income = pet.income,
			known = profile.index[pet.id] == true,
		})
	end

	return {
		worlds = worlds,
		limited = limited,
		totalFound = IndexService.totalUnlocked(profile),
		total = IndexService.TOTAL,
	}
end

function IndexService.start()
	PetService.PetAdded:Connect(function(player, _uid, petId)
		IndexService.discover(player, petId)
	end)

	Net.handle("ClaimIndexReward", function(player, world)
		return IndexService.claimReward(player, tostring(world))
	end)
end

return IndexService
