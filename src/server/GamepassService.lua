--!strict
--[[
	GamepassService
	Ownership checks (cached, refreshed on purchase), purchase prompts and the
	developer-product receipt handler.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GamepassConfig = require(Shared.GamepassConfig)

local GamepassService = {}

local owned: { [number]: { [string]: boolean } } = {}
local callbacks: { (Player, string) -> () } = {}

--- Registered by other services so they can react to a new purchase.
function GamepassService.onPurchase(callback: (Player, string) -> ())
	table.insert(callbacks, callback)
end

local function fire(player: Player, key: string)
	for _, callback in ipairs(callbacks) do
		task.spawn(callback, player, key)
	end
end

function GamepassService.refresh(player: Player)
	local map = {}

	for _, pass in ipairs(GamepassConfig.Passes) do
		if pass.id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			map[pass.key] = ok and has or false
		else
			map[pass.key] = false
		end
	end

	owned[player.UserId] = map
	return map
end

function GamepassService.get(player: Player): { [string]: boolean }
	return owned[player.UserId] or GamepassService.refresh(player)
end

function GamepassService.has(player: Player, key: string): boolean
	return GamepassService.get(player)[key] == true
end

function GamepassService.clear(player: Player)
	owned[player.UserId] = nil
end

--- Prompts a gamepass or developer product by config key.
function GamepassService.prompt(player: Player, kind: string, key: string)
	if kind == "pass" then
		local pass = GamepassConfig.ByKey[key]
		if not pass or pass.id == 0 then
			return false, "That pass isn't set up yet."
		end
		if GamepassService.has(player, key) then
			return false, "You already own that."
		end
		local ok = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		end)
		return ok
	elseif kind == "product" then
		local product = GamepassConfig.ProductByKey[key]
		if not product or product.id == 0 then
			return false, "That product isn't set up yet."
		end
		local ok = pcall(function()
			MarketplaceService:PromptProductPurchase(player, product.id)
		end)
		return ok
	end

	return false, "Unknown purchase kind."
end

--- Wires up the marketplace signals. `grant` handles product effects and must
--- return true only once the effect is durably saved, otherwise the receipt is
--- retried by Roblox.
function GamepassService.init(grant: (Player, any) -> boolean)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		local pass = GamepassConfig.ById[passId]
		GamepassService.refresh(player)
		if pass then
			fire(player, pass.key)
		end
	end)

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			-- Player left; let Roblox retry when they come back.
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local product = GamepassConfig.ProductById[receiptInfo.ProductId]
		if not product then
			warn("[GamepassService] unknown product id: " .. tostring(receiptInfo.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local ok, granted = pcall(grant, player, product)
		if ok and granted then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		warn("[GamepassService] failed to grant " .. product.key)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Players.PlayerRemoving:Connect(function(player)
		GamepassService.clear(player)
	end)
end

return GamepassService
