--[[
	UGC unlocks and claiming.

	An item moves through two states:

	  UNLOCKED  the player met the requirement. Recorded on the profile and
	            saved forever, so the item is theirs whether or not the real
	            asset exists yet.
	  CLAIMED   the player actually took delivery of the Roblox item.

	Splitting the two is what lets you ship the game before the UGC is live:
	players earn items today, and the moment you paste a real asset id into
	Ugc.luau every existing unlock becomes claimable with no migration.

	Delivery uses MarketplaceService:PromptPurchase, which is the supported
	path for handing someone a UGC item you publish for free. The server never
	marks an item claimed on the client's word -- it re-checks ownership with
	PlayerOwnsAsset after the prompt closes.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Ugc = require(ReplicatedStorage.Shared.Config.Ugc)

local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)

local UgcService = {}

UgcService.Unlocked = Signal.new()

local unlockedEvent = Net.Event("UgcUnlocked")
local notify = Net.Event("Notify")

-- player -> ugcId currently being prompted, so PromptPurchaseFinished knows
-- which entry to verify.
local pendingClaim: { [Player]: string } = {}

-- Ownership is a web call; cache per session so the UGC tab is not chatty.
local ownsCache: { [Player]: { [number]: boolean } } = {}

local function ownsAsset(player: Player, assetId: number): boolean
	if assetId == 0 then
		return false
	end

	local cache = ownsCache[player]
	if cache and cache[assetId] ~= nil then
		return cache[assetId]
	end

	local ok, result = pcall(function()
		return MarketplaceService:PlayerOwnsAsset(player, assetId)
	end)

	local owns = ok and result == true
	if ok then
		ownsCache[player] = ownsCache[player] or {}
		ownsCache[player][assetId] = owns
	end

	return owns
end

function UgcService.isUnlocked(profile, ugcId: string): boolean
	return profile.ugc[ugcId] ~= nil
end

--[[
	Records an unlock. Idempotent -- calling it again for an item the player
	already has is a no-op, so the requirement checks below can run as often
	as they like.
]]
function UgcService.unlock(player: Player, ugcId: string, reason: string?): boolean
	local profile = DataService.get(player)
	local entry = Ugc.get(ugcId)
	if not profile or not entry then
		return false
	end
	if profile.ugc[ugcId] then
		return false
	end

	profile.ugc[ugcId] = { unlockedAt = os.time(), claimed = false }
	DataService.markDirty(player)

	unlockedEvent:FireClient(player, {
		id = entry.id,
		name = entry.name,
		rarity = entry.rarity,
		reason = reason or Ugc.requirementText(entry),
		placeholder = Ugc.isPlaceholder(entry),
	})

	UgcService.Unlocked:Fire(player, ugcId, entry)
	return true
end

--[[
	Hands the item over. Called from the UGC tab's Claim button.
]]
function UgcService.claim(player: Player, ugcId: string)
	local profile = DataService.get(player)
	local entry = Ugc.get(ugcId)
	if not profile or not entry then
		return { ok = false, error = "Unknown item" }
	end

	local record = profile.ugc[ugcId]
	if not record then
		return { ok = false, error = "You have not unlocked this yet" }
	end
	if record.claimed then
		return { ok = false, error = "Already claimed" }
	end

	if Ugc.isPlaceholder(entry) then
		return {
			ok = false,
			placeholder = true,
			error = "This item is not live yet -- it is saved to your account and you can claim it the moment it drops.",
		}
	end

	if entry.grantMode == "record" then
		record.claimed = true
		record.claimedAt = os.time()
		DataService.markDirty(player)
		return { ok = true, mode = "record" }
	end

	if ownsAsset(player, entry.assetId) then
		record.claimed = true
		record.claimedAt = os.time()
		DataService.markDirty(player)
		return { ok = true, mode = "already-owned" }
	end

	pendingClaim[player] = ugcId

	local ok = pcall(function()
		if entry.assetType == "Bundle" then
			MarketplaceService:PromptBundlePurchase(player, entry.assetId)
		else
			MarketplaceService:PromptPurchase(player, entry.assetId)
		end
	end)

	if not ok then
		pendingClaim[player] = nil
		return { ok = false, error = "Could not open the Roblox prompt. Try again." }
	end

	return { ok = true, mode = "prompted" }
end

--- The cash-purchase path. Buying unlocks; the player still claims after.
function UgcService.buy(player: Player, ugcId: string)
	local profile = DataService.get(player)
	local entry = Ugc.get(ugcId)
	if not profile or not entry then
		return { ok = false, error = "Unknown item" }
	end
	if entry.source ~= Ugc.Sources.SHOP then
		return { ok = false, error = "That item is not for sale" }
	end
	if profile.ugc[ugcId] then
		return { ok = false, error = "You already own this" }
	end

	local price = entry.price or 0
	if not PetService.spendCash(player, price) then
		return { ok = false, error = "Not enough cash" }
	end

	UgcService.unlock(player, ugcId, "Bought from the UGC shop")
	return { ok = true }
end

-- ========================= requirement checks =========================

--- Pet Index completion, per world and for the full 104.
function UgcService.checkIndex(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	local IndexService = require(script.Parent.IndexService)

	for _, entry in Ugc.ofSource(Ugc.Sources.INDEX) do
		if profile.ugc[entry.id] then
			continue
		end

		if entry.world == "All" then
			if IndexService.totalUnlocked(profile) >= IndexService.TOTAL then
				UgcService.unlock(player, entry.id, "Completed the Pet Index")
			end
		elseif IndexService.isWorldComplete(profile, entry.world) then
			UgcService.unlock(player, entry.id, `Completed the {entry.world} index`)
		end
	end
end

function UgcService.checkPlaytime(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	for _, entry in Ugc.ofSource(Ugc.Sources.PLAYTIME) do
		if not profile.ugc[entry.id] and profile.playtime >= (entry.seconds or math.huge) then
			UgcService.unlock(player, entry.id, Ugc.requirementText(entry))
		end
	end
end

function UgcService.checkDaily(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	for _, entry in Ugc.ofSource(Ugc.Sources.DAILY) do
		if not profile.ugc[entry.id] and profile.daily.streak >= (entry.days or math.huge) then
			UgcService.unlock(player, entry.id, `{profile.daily.streak} day streak`)
		end
	end
end

--- Called whenever a pet hatches. Pets carrying a `ugcId` unlock on hatch.
function UgcService.checkHatch(player: Player, petId: string)
	local Pets = require(ReplicatedStorage.Shared.Config.Pets)
	local pet = Pets.get(petId)
	if pet and pet.ugcId then
		UgcService.unlock(player, pet.ugcId, `Hatched the {pet.name}`)
	end
end

--- Everything the UGC tab needs, in one payload.
function UgcService.snapshot(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return {}
	end

	local out = {}
	for _, entry in Ugc.List do
		local record = profile.ugc[entry.id]
		table.insert(out, {
			id = entry.id,
			name = entry.name,
			description = entry.description,
			rarity = entry.rarity,
			source = entry.source,
			price = entry.price,
			assetId = entry.assetId,
			requirement = Ugc.requirementText(entry),
			placeholder = Ugc.isPlaceholder(entry),
			unlocked = record ~= nil,
			claimed = record ~= nil and record.claimed == true,
		})
	end
	return out
end

function UgcService.start()
	Net.handle("ClaimUgc", function(player, ugcId)
		return UgcService.claim(player, tostring(ugcId))
	end)

	Net.handle("BuyUgc", function(player, ugcId)
		return UgcService.buy(player, tostring(ugcId))
	end)

	-- Confirm delivery after the Roblox prompt closes.
	MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
		local ugcId = pendingClaim[player]
		pendingClaim[player] = nil
		if not ugcId or not isPurchased then
			return
		end

		local entry = Ugc.get(ugcId)
		if not entry or entry.assetId ~= assetId then
			return
		end

		-- Bust the cache: they just bought it.
		if ownsCache[player] then
			ownsCache[player][assetId] = nil
		end

		local profile = DataService.get(player)
		local record = profile and profile.ugc[ugcId]
		if not record then
			return
		end

		if ownsAsset(player, assetId) then
			record.claimed = true
			record.claimedAt = os.time()
			DataService.markDirty(player)
			notify:FireClient(player, "success", `{entry.name} is yours!`)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		pendingClaim[player] = nil
		ownsCache[player] = nil
	end)

	-- Re-run every check on load so a requirement met on an older version of
	-- the game (or added to Ugc.luau since) unlocks retroactively.
	DataService.ProfileLoaded:Connect(function(player)
		task.defer(function()
			UgcService.checkIndex(player)
			UgcService.checkPlaytime(player)
			UgcService.checkDaily(player)
		end)
	end)
end

return UgcService
