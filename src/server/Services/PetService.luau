--[[
	Pet inventory, equipping and income.

	Pets are stored as uid -> { id, shiny, locked }. Equipped uids live in a
	separate ordered array so the client can render them in a stable order.

	Income ticks on the server once a second for every equipped pet. The
	client renders the follow behaviour itself (see Controllers/PetFollow) so
	nothing about a pet's movement costs bandwidth.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local DataService = require(script.Parent.DataService)

local PetService = {}

PetService.PetAdded = Signal.new()
PetService.CashChanged = Signal.new()

local SHINY_CHANCE = 1 / 40
local SHINY_MULTIPLIER = 5

local notify = Net.Event("Notify")

local function uidFor(profile): string
	local uid = `p{profile.nextPetUid}`
	profile.nextPetUid += 1
	return uid
end

function PetService.countPets(profile): number
	local count = 0
	for _ in profile.pets do
		count += 1
	end
	return count
end

--- Cash per second from everything currently equipped.
function PetService.incomeOf(profile): number
	local total = 0
	for _, uid in profile.equipped do
		local entry = profile.pets[uid]
		if entry then
			local pet = Pets.get(entry.id)
			if pet then
				total += pet.income * (entry.shiny and SHINY_MULTIPLIER or 1)
			end
		end
	end
	return total
end

function PetService.addCash(player: Player, amount: number)
	local profile = DataService.get(player)
	if not profile then
		return
	end
	profile.cash = math.max(0, profile.cash + amount)
	DataService.markDirty(player)
	PetService.CashChanged:Fire(player, profile.cash)
end

function PetService.spendCash(player: Player, amount: number): boolean
	local profile = DataService.get(player)
	if not profile or profile.cash < amount then
		return false
	end
	profile.cash -= amount
	DataService.markDirty(player)
	PetService.CashChanged:Fire(player, profile.cash)
	return true
end

--[[
	Grants a pet. `forceShiny` is used by the fuse machine; everything else
	rolls it. Auto-equips while there is room so a new player sees their first
	pet following them without opening a menu.
]]
function PetService.grant(player: Player, petId: string, forceShiny: boolean?)
	local profile = DataService.get(player)
	local pet = Pets.get(petId)
	if not profile or not pet then
		return nil
	end

	if PetService.countPets(profile) >= Balance.Pets.INVENTORY_LIMIT then
		notify:FireClient(player, "warn", "Inventory full -- sell some pets!")
		return nil
	end

	local shiny = forceShiny or (math.random() < SHINY_CHANCE)
	local uid = uidFor(profile)
	profile.pets[uid] = { id = petId, shiny = shiny, locked = false }

	if #profile.equipped < Balance.Pets.EQUIP_LIMIT then
		table.insert(profile.equipped, uid)
	end

	DataService.markDirty(player)
	PetService.PetAdded:Fire(player, uid, petId, shiny)

	return uid, shiny
end

function PetService.setEquipped(player: Player, uid: string, equipped: boolean)
	local profile = DataService.get(player)
	if not profile or not profile.pets[uid] then
		return false, "no such pet"
	end

	local index = table.find(profile.equipped, uid)

	if equipped then
		if index then
			return true
		end
		if #profile.equipped >= Balance.Pets.EQUIP_LIMIT then
			return false, `You can only equip {Balance.Pets.EQUIP_LIMIT} pets`
		end
		table.insert(profile.equipped, uid)
	else
		if not index then
			return true
		end
		table.remove(profile.equipped, index)
	end

	DataService.markDirty(player)
	return true
end

--[[
	Sells pets for cash. Equipped and locked pets are protected so a
	mis-click at the Sell stand cannot wipe someone's best pet.
]]
function PetService.sell(player: Player, uids: { string })
	local profile = DataService.get(player)
	if not profile then
		return false, "no profile"
	end

	local payout, sold = 0, 0

	for _, uid in uids do
		local entry = profile.pets[uid]
		if not entry then
			continue
		end
		if entry.locked then
			continue
		end
		if Balance.Sell.PROTECT_EQUIPPED and table.find(profile.equipped, uid) then
			continue
		end

		local pet = Pets.get(entry.id)
		if pet then
			payout += pet.income * (entry.shiny and SHINY_MULTIPLIER or 1) * Balance.Sell.INCOME_MULTIPLE
		end

		profile.pets[uid] = nil
		sold += 1
	end

	if sold == 0 then
		return false, "Nothing sellable selected"
	end

	payout = math.floor(payout)
	profile.stats.petsSold += sold
	PetService.addCash(player, payout)

	return true, { sold = sold, payout = payout }
end

--- Drops a pet without paying out. Used by the fuse machine's inputs.
function PetService.consume(player: Player, uids: { string }): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end

	for _, uid in uids do
		local index = table.find(profile.equipped, uid)
		if index then
			table.remove(profile.equipped, index)
		end
		profile.pets[uid] = nil
	end

	DataService.markDirty(player)
	return true
end

function PetService.start()
	-- Income tick.
	task.spawn(function()
		while true do
			task.wait(Balance.Pets.INCOME_INTERVAL)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if not profile then
					continue
				end
				local income = PetService.incomeOf(profile)
				if income > 0 then
					profile.cash += income * Balance.Pets.INCOME_INTERVAL
					DataService.markDirty(player)
				end
			end
		end
	end)

	-- Equipped uids can go stale if a pet was sold on another server. Prune
	-- once on load so the client never renders a ghost.
	DataService.ProfileLoaded:Connect(function(_player, profile)
		local cleaned = {}
		for _, uid in profile.equipped do
			if profile.pets[uid] and #cleaned < Balance.Pets.EQUIP_LIMIT then
				table.insert(cleaned, uid)
			end
		end
		profile.equipped = cleaned
	end)
end

PetService.SHINY_MULTIPLIER = SHINY_MULTIPLIER

return PetService
