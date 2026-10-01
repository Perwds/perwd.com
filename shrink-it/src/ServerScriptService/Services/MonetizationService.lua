--[[
	📍 LOCATION: ServerScriptService > Services > MonetizationService (ModuleScript)

	Gamepasses (one-time) + Developer Products (repeatable) with an idempotent ProcessReceipt:
	  1. Player not in this server / profile not loaded  → NotProcessedYet (Roblox retries later).
	  2. PurchaseId already recorded in the player's profile → do NOT grant again; just make sure
	     it is saved, then PurchaseGranted.
	  3. Otherwise grant, record the PurchaseId IN THE SAME PROFILE, save immediately.
	     PurchaseGranted only if that save succeeded. If the save fails we return NotProcessedYet;
	     the retry hits case 2 (already granted in memory) and just retries the save.
	  Because the grant and the receipt id live in the same saved document, a crash can never
	  persist one without the other → never granted twice, never lost.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)

local MonetizationService = {}
local Svc

function MonetizationService.Init(registry)
	Svc = registry
end

local function applyPassEffects(player)
	local s = Svc.Session.Get(player)
	if not s then
		return
	end
	player:SetAttribute("VIP", s.Passes.VIP == true)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = s.Passes.SpeedBoots and GameConfig.SpeedBootsWalkSpeed or GameConfig.BaseWalkSpeed
	end
end

function MonetizationService.HasPass(player, key)
	return Svc.Session.HasPass(player, key)
end

local function grantPass(player, key)
	local s = Svc.Session.Get(player)
	if not s or s.Passes[key] then
		return
	end
	s.Passes[key] = true
	applyPassEffects(player)
	Svc.Museum.Recompute(player) -- pedestals / income may change
	Svc.Data.MarkDirty(player)
end

function MonetizationService.OnPlayerLoaded(player)
	local s = Svc.Session.Get(player)
	-- Paid random items must be disabled where Roblox policy restricts them (fail safe = restricted)
	local okPolicy, policy = pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
	s.PaidRandomRestricted = not okPolicy or not policy or policy.ArePaidRandomItemsRestricted == true
	local pending = 0
	for key, pass in pairs(MonetizationConfig.GamePasses) do
		if pass.Id ~= 0 then
			pending += 1
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
				if ok and owns then
					s.Passes[key] = true
				end
				pending -= 1
			end)
		end
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 10 do
		task.wait(0.1)
	end
	applyPassEffects(player)
	player.CharacterAdded:Connect(function()
		task.defer(applyPassEffects, player)
	end)
end

-- ── Product handlers (key → fn(player, data)) ───────────────────────
local productHandlers = {
	InstantRebirth = function(player)
		Svc.Rebirth.DoRebirth(player, true)
	end,
	SpawnGolden = function(player)
		Svc.Spawn.SpawnNear(player, "Golden")
	end,
	InfinitePack = function(player, _data, key)
		Svc.InfinitePack.OnPurchased(player, key)
	end,
}

local function grantProduct(player, data, key)
	local product = MonetizationConfig.Products[key]
	if product.Grant then
		Svc.Reward.Grant(player, product.Grant, "purchase")
	end
	if product.Handler then
		productHandlers[product.Handler](player, data, key)
	end
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = Svc.Data.WaitForData(player, 15)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(info.PurchaseId)
	if data.Receipts[purchaseId] then
		-- already granted (maybe the previous save failed) → just make sure it's persisted
		if Svc.Data.Save(player) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local key = MonetizationConfig.ProductKeyById(info.ProductId)
	if not key then
		warn("[Monetization] Unknown product id " .. tostring(info.ProductId) .. " - add it to MonetizationConfig.Products")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, err = pcall(grantProduct, player, data, key)
	if not ok then
		warn("[Monetization] Grant failed for " .. key .. ": " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	data.Receipts[purchaseId] = os.time()
	table.insert(data.ReceiptOrder, purchaseId)
	while #data.ReceiptOrder > GameConfig.MaxReceiptHistory do
		local oldest = table.remove(data.ReceiptOrder, 1)
		data.Receipts[oldest] = nil
	end
	Svc.Data.MarkDirty(player)
	Svc.Net.Notify(player, "Thanks for your purchase! 💖", "success")

	if Svc.Data.Save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService.PromptProduct(player, key)
	local product = MonetizationConfig.Products[key]
	if not product then
		return { ok = false, msg = "Unknown product" }
	end
	if product.Id == 0 then
		return { ok = false, msg = "Coming soon! (Product ID not set yet)" }
	end
	MarketplaceService:PromptProductPurchase(player, product.Id)
	return { ok = true }
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in pairs(MonetizationConfig.GamePasses) do
			if pass.Id == passId then
				grantPass(player, key)
				Svc.Net.Notify(player, "Unlocked " .. pass.Name .. "! 🎉", "success")
			end
		end
	end)

	Svc.Net.Handle("PromptPass", function(player, key)
		local pass = type(key) == "string" and MonetizationConfig.GamePasses[key]
		if not pass then
			return { ok = false, msg = "Unknown pass" }
		end
		if Svc.Session.HasPass(player, key) then
			return { ok = false, msg = "You already own this!" }
		end
		if pass.Id == 0 then
			return { ok = false, msg = "Coming soon! (Gamepass ID not set yet)" }
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		return { ok = true }
	end)

	Svc.Net.Handle("PromptProduct", function(player, key)
		if type(key) ~= "string" then
			return { ok = false }
		end
		local product = MonetizationConfig.Products[key]
		if not product or product.Hidden then
			return { ok = false, msg = "Unknown product" }
		end
		return MonetizationService.PromptProduct(player, key)
	end)

	Svc.Data.AddSyncProvider(function(player, payload)
		local s = Svc.Session.Get(player)
		payload.Passes = s and s.Passes or {}
	end)
end

return MonetizationService
