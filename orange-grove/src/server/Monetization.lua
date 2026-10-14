--!strict
-- Game passes and developer products. Every ID starts at 0; items with ID 0 are hidden everywhere.
-- Paid items only speed things up. Nothing here is needed to reach any part of the tree.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Data = require(script.Parent.Data)
local Currency = require(script.Parent.Currency)
local Remotes = require(script.Parent.Remotes)
local UpgradeService = require(script.Parent.UpgradeService)

local Monetization = {}

-- Owner fills these in from the Creator Dashboard.
Monetization.Passes = {
	VIP = {
		id = 0,
		name = "VIP Orchard",
		desc = "Opens the pink Back Orchard. Its trees give 1.5x oranges, and you get the lounge and a VIP chat tag.",
	},
	DoubleOranges = {
		id = 0,
		name = "2x Oranges",
		desc = "Doubles oranges from every source: your picks, your pickers and auto-collect.",
	},
	AutoPicker = {
		id = 0,
		name = "Auto-Picker",
		desc = "Picks every ripe orange within 30 studs of you as you walk around.",
	},
	ExtraPickers = {
		id = 0,
		name = "Extra Picker Slots",
		desc = "Raises the Hire a Picker limit from 5 to 8. You still hire them with oranges.",
	},
}

Monetization.Products = {
	CrateOfOranges = {
		id = 0,
		name = "Crate of Oranges",
		desc = "Gives oranges equal to 10 minutes of your current production.",
	},
	LabBoost = {
		id = 0,
		name = "Lab Boost",
		desc = "The Lab makes 2x Vitamin C for 30 minutes. Buying it again adds another 30 minutes.",
	},
}

local LAB_BOOST_SECONDS = 30 * 60
local CRATE_SECONDS = 10 * 60
local CRATE_MINIMUM = 500

local owned: { [Player]: { [string]: boolean } } = {}

local function passKeyForId(id: number): string?
	for key, pass in Monetization.Passes do
		if pass.id ~= 0 and pass.id == id then
			return key
		end
	end
	return nil
end

local function productKeyForId(id: number): string?
	for key, product in Monetization.Products do
		if product.id ~= 0 and product.id == id then
			return key
		end
	end
	return nil
end

function Monetization.enabled(key: string): boolean
	local pass = Monetization.Passes[key]
	local product = Monetization.Products[key]
	return (pass ~= nil and pass.id ~= 0) or (product ~= nil and product.id ~= 0)
end

function Monetization.owns(player: Player, key: string): boolean
	local mine = owned[player]
	return mine ~= nil and mine[key] == true
end

function Monetization.mods(player: Player): { [string]: boolean }
	local mine = owned[player] or {}
	local data = Data.get(player)
	return {
		VIP = mine.VIP == true,
		DoubleOranges = mine.DoubleOranges == true,
		AutoPicker = mine.AutoPicker == true,
		ExtraPickers = mine.ExtraPickers == true,
		LabBoost = data ~= nil and data.labBoostUntil > os.time(),
	}
end

local function catalog(player: Player): { { [string]: any } }
	local items = {}
	for key, pass in Monetization.Passes do
		if pass.id ~= 0 then
			table.insert(items, {
				key = key,
				kind = "pass",
				id = pass.id,
				name = pass.name,
				desc = pass.desc,
				owned = Monetization.owns(player, key),
			})
		end
	end
	for key, product in Monetization.Products do
		if product.id ~= 0 then
			table.insert(
				items,
				{ key = key, kind = "product", id = product.id, name = product.name, desc = product.desc }
			)
		end
	end
	table.sort(items, function(a, b)
		if a.kind ~= b.kind then
			return a.kind == "pass"
		end
		return a.name < b.name
	end)
	return items
end

local function setOwned(player: Player, key: string)
	owned[player] = owned[player] or {}
	owned[player][key] = true
	if key == "VIP" then
		player:SetAttribute("VIP", true)
	end
end

local function loadPasses(player: Player)
	owned[player] = owned[player] or {}
	for key, pass in Monetization.Passes do
		if pass.id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.id)
			if ok and has then
				setOwned(player, key)
			end
		end
	end
	player:SetAttribute("PassesReady", true)
	UpgradeService.refresh(player)
	Remotes.fire("Shop", player, catalog(player))
end

local grants: { [string]: (Player, { [string]: any }) -> () } = {
	CrateOfOranges = function(player)
		local s = UpgradeService.stats(player)
		local perSecond = math.max(Currency.grossOrangeRate(player), s.pickerPicks * s.pickValue)
		local amount = math.max(CRATE_MINIMUM, math.floor(perSecond * CRATE_SECONDS))
		Currency.add(player, "oranges", amount)
		Remotes.fire("Notice", player, "product", { name = "Crate of Oranges", oranges = amount })
	end,
	LabBoost = function(player, data)
		data.labBoostUntil = math.max(os.time(), data.labBoostUntil) + LAB_BOOST_SECONDS
		UpgradeService.refresh(player)
		Remotes.fire("Notice", player, "product", { name = "Lab Boost", untilTime = data.labBoostUntil })
	end,
}

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = Data.get(player)
	local waited = 0
	while not data and waited < 10 and player.Parent do
		task.wait(0.5)
		waited += 0.5
		data = Data.get(player)
	end
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Already granted in an earlier attempt: only confirm once that grant is safely saved.
	if table.find(data.purchases, receipt.PurchaseId) then
		return if Data.save(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local key = productKeyForId(receipt.ProductId)
	local grant = key and grants[key]
	if not grant then
		warn("[Monetization] receipt for unknown product " .. tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	grant(player, data)
	table.insert(data.purchases, receipt.PurchaseId)
	while #data.purchases > Config.Save.keepPurchaseIds do
		table.remove(data.purchases, 1)
	end

	return if Data.save(player)
		then Enum.ProductPurchaseDecision.PurchaseGranted
		else Enum.ProductPurchaseDecision.NotProcessedYet
end

function Monetization.init()
	UpgradeService.setModsProvider(Monetization.mods)

	Data.onLoaded(function(player)
		loadPasses(player)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key = passKeyForId(passId)
		if key then
			setOwned(player, key)
			UpgradeService.refresh(player)
			Remotes.fire("Shop", player, catalog(player))
			Remotes.fire("Notice", player, "pass", { key = key, name = Monetization.Passes[key].name })
		end
	end)

	MarketplaceService.ProcessReceipt = processReceipt

	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
end

return Monetization
