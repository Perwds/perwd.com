--[[
	Buying eggs and unlocking worlds.

	A bought egg is not a shortcut past the carry loop: it attaches to your
	back exactly like one you stole off a pedestal, and it is just as
	stealable on the walk home. The shop buys you certainty about WHICH egg,
	never safety.

	Robux bundles are wired through ProcessReceipt so a purchase that lands
	while the server is dying is granted on the next join instead of lost.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local EggSpawnService = require(script.Parent.EggSpawnService)
local PetService = require(script.Parent.PetService)

local ShopService = {}

local notify = Net.Event("Notify")

--[[
	Developer Product ids for the Robux egg bundles.
	Fill these in from the Creator Dashboard; until then the Robux buttons
	tell the player the bundle is not live rather than failing silently.

		[<developerProductId>] = { eggId = "extinction", amount = 10 },
]]
ShopService.PRODUCTS = {}

local function tierFor(eggId: string)
	-- Shop eggs always roll the normal tier; the luck comes from the pool.
	for _, tier in EggSpawnService.TIERS do
		if tier.id == "normal" then
			return tier
		end
	end
	return EggSpawnService.TIERS[1]
end

--[[
	Attaches a freshly bought egg to the buyer.
]]
local function giveEgg(player: Player, eggId: string): (boolean, string?)
	local egg = Eggs.get(eggId)
	if not egg then
		return false, "Unknown egg"
	end
	if CarryService.isCarrying(player) then
		return false, "Drop the egg you are holding first"
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "Respawning"
	end

	local world = egg.limited and "Forest" or egg.world
	local model = EggSpawnService.createEgg(world, tierFor(eggId), root.CFrame * CFrame.new(0, 2, -4))

	-- Override the world-derived identity with the purchased egg's.
	model:SetAttribute("EggId", egg.id)
	model:SetAttribute("World", egg.world)
	model:SetAttribute("HatchTime", egg.hatchTime)

	if not CarryService.grab(player, model) then
		-- Could not attach; leave it loose at their feet rather than voiding
		-- a purchase.
		CarryService.dropAt(model, root.CFrame)
	end

	return true
end

ShopService.giveEgg = giveEgg

function ShopService.buyEgg(player: Player, eggId: string)
	local profile = DataService.get(player)
	local egg = Eggs.get(tostring(eggId))
	if not profile or not egg then
		return { ok = false, error = "Unknown egg" }
	end

	if egg.limited or not egg.cost then
		return { ok = false, error = "That egg is Robux only" }
	end

	if not profile.worlds[egg.world] then
		return { ok = false, error = `Unlock {egg.world} first` }
	end

	if profile.cash < egg.cost then
		return { ok = false, error = `Need {Format.abbreviate(egg.cost)} cash` }
	end

	local ok, err = giveEgg(player, egg.id)
	if not ok then
		return { ok = false, error = err }
	end

	PetService.spendCash(player, egg.cost)
	return { ok = true, eggId = egg.id }
end

function ShopService.unlockWorld(player: Player, world: string)
	local profile = DataService.get(player)
	local info = Worlds.get(tostring(world))
	if not profile or not info then
		return { ok = false, error = "Unknown world" }
	end
	if profile.worlds[world] then
		return { ok = true, already = true }
	end

	local previous = Worlds.previous(world)
	if previous and not profile.worlds[previous] then
		return { ok = false, error = `Unlock {previous} first` }
	end

	if not PetService.spendCash(player, info.unlockCost) then
		return { ok = false, error = `Need {Format.abbreviate(info.unlockCost)} cash` }
	end

	profile.worlds[world] = true
	DataService.markDirty(player)

	-- Drives the client-side gate pass-through.
	player:SetAttribute(`World_{world}`, true)

	notify:FireClient(player, "success", `{info.display} unlocked!`)
	return { ok = true }
end

local function syncWorldAttributes(player: Player, profile)
	for _, world in Worlds.Order do
		player:SetAttribute(`World_{world}`, profile.worlds[world] == true)
	end
end

function ShopService.start()
	Net.handle("BuyEgg", function(player, eggId)
		return ShopService.buyEgg(player, eggId)
	end)

	Net.handle("UnlockWorld", function(player, world)
		return ShopService.unlockWorld(player, world)
	end)

	DataService.ProfileLoaded:Connect(syncWorldAttributes)
	for _, player in Players:GetPlayers() do
		local profile = DataService.get(player)
		if profile then
			syncWorldAttributes(player, profile)
		end
	end

	MarketplaceService.ProcessReceipt = function(receipt)
		local product = ShopService.PRODUCTS[receipt.ProductId]
		if not product then
			warn(`[ShopService] unknown product {receipt.ProductId}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			-- They left mid-purchase; Roblox will re-deliver on their return.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local profile = DataService.await(player, 8)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		for _ = 1, product.amount do
			local ok = giveEgg(player, product.eggId)
			if not ok then
				break
			end
		end

		DataService.save(player, false)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
end

return ShopService
