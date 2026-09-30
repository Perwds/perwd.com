--[[
	The Fuse Machine.

	Feed it three pets of the same rarity and it rolls for one tier up. A
	failed roll still returns a pet of the same rarity, so a fuse is never a
	total loss -- it is a re-roll with upside rather than a gamble you can
	zero out.

	Results are drawn from worlds the player has actually unlocked, so fusing
	cannot hand out a Cyber pet to someone still in the Forest.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Net = require(ReplicatedStorage.Shared.Net)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

local FuseService = {}

local fuseResult = Net.Event("FuseResult")
local rng = Random.new()

local busy: { [Player]: boolean } = {}

--- Candidate pets of a rarity, limited to the player's unlocked worlds.
local function candidates(profile, rarityName: string)
	local out = {}
	for _, pet in Pets.List do
		if pet.limited or pet.rarity ~= rarityName then
			continue
		end
		if profile.worlds[pet.world] then
			table.insert(out, pet)
		end
	end
	return out
end

function FuseService.fuse(player: Player, uids: { string })
	local profile = DataService.get(player)
	if not profile then
		return { ok = false, error = "Still loading" }
	end
	if busy[player] then
		return { ok = false, error = "The machine is already running" }
	end

	if type(uids) ~= "table" or #uids ~= Balance.Fuse.INPUT_COUNT then
		return { ok = false, error = `Needs exactly {Balance.Fuse.INPUT_COUNT} pets` }
	end

	-- Validate every input before consuming anything.
	local seen, rarityName = {}, nil
	for _, uid in uids do
		if type(uid) ~= "string" or seen[uid] then
			return { ok = false, error = "Pick three different pets" }
		end
		seen[uid] = true

		local entry = profile.pets[uid]
		if not entry then
			return { ok = false, error = "You do not own one of those pets" }
		end
		if entry.locked then
			return { ok = false, error = "One of those pets is locked" }
		end

		local pet = Pets.get(entry.id)
		if not pet then
			return { ok = false, error = "Unknown pet" }
		end
		if rarityName and pet.rarity ~= rarityName then
			return { ok = false, error = "All three must be the same rarity" }
		end
		rarityName = pet.rarity
	end

	if rarityName == Rarity.Order[#Rarity.Order] then
		return { ok = false, error = "Already the top rarity" }
	end

	local upgraded = rng:NextNumber() < Balance.Fuse.UPGRADE_CHANCE
	local targetRarity = upgraded and Rarity.next(rarityName) or rarityName

	local pool = candidates(profile, targetRarity)
	if #pool == 0 then
		-- Nothing at the higher tier in their unlocked worlds; fall back.
		targetRarity = rarityName
		upgraded = false
		pool = candidates(profile, targetRarity)
	end
	if #pool == 0 then
		return { ok = false, error = "No fuse results available yet" }
	end

	busy[player] = true
	PetService.consume(player, uids)

	local chosen = pool[rng:NextInteger(1, #pool)]

	task.delay(Balance.Fuse.DURATION, function()
		busy[player] = nil

		if not player.Parent then
			return
		end

		-- They may have left and rejoined during the animation; the captured
		-- profile would then be a released table.
		local current = DataService.get(player)
		if not current then
			return
		end

		local uid, shiny = PetService.grant(player, chosen.id)
		if not uid then
			return
		end

		current.stats.fused += 1
		DataService.markDirty(player)

		fuseResult:FireClient(player, {
			petId = chosen.id,
			name = chosen.name,
			rarity = chosen.rarity,
			uid = uid,
			shiny = shiny,
			upgraded = upgraded,
		})
	end)

	return { ok = true, duration = Balance.Fuse.DURATION, upgraded = upgraded }
end

function FuseService.start()
	Net.handle("Fuse", function(player, uids)
		return FuseService.fuse(player, uids)
	end)

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return FuseService
