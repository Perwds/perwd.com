--[[
	📍 LOCATION: ServerScriptService > Services > InfinitePackService (ModuleScript)

	Never-ending reward chain. Tiles come from the shared deterministic generator (InfinitePackGen).
	Progress (Season + Claimed) is saved in the player's profile.

	Paid tiles = REPEATABLE Developer Products (PackTier1/2/3), never gamepasses.
	A purchase is stored as a "credit" for that product tier inside the SAME profile write that
	records the receipt (see MonetizationService), then immediately spent on the next tile if it
	matches. If the chain moved on / refreshed in between, the credit is kept and auto-applies to
	the next paid tile of that tier → a purchase can never be lost or double-granted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gen = require(Shared.InfinitePackGen)

local InfinitePackService = {}
local Svc

function InfinitePackService.Init(registry)
	Svc = registry
end

local function restricted(player)
	local s = Svc.Session.Get(player)
	return s == nil or s.PaidRandomRestricted ~= false
end

local function ensureSeason(data)
	local season = Gen.Season(os.time())
	if data.InfinitePack.Season ~= season then
		data.InfinitePack.Season = season
		data.InfinitePack.Claimed = 0
	end
	return season
end

-- Claims the next tile. Never yields. Returns ok, message
local function claimNext(player, data)
	local pack = data.InfinitePack
	local season = ensureSeason(data)
	local tile = Gen.GetTile(season, pack.Claimed + 1, restricted(player))
	if tile.Paid then
		local credits = pack.Credits[tile.Product] or 0
		if credits <= 0 then
			return false, "needPurchase"
		end
		pack.Credits[tile.Product] = credits - 1
	end
	pack.Claimed += 1
	local text = Svc.Reward.Grant(player, tile.Reward, "infinitepack")
	Svc.Data.MarkDirty(player)
	return true, text
end

-- Called from ProcessReceipt (never yields).
function InfinitePackService.OnPurchased(player, productKey)
	local data = Svc.Data.Get(player)
	local pack = data.InfinitePack
	pack.Credits[productKey] = (pack.Credits[productKey] or 0) + 1
	local season = ensureSeason(data)
	local tile = Gen.GetTile(season, pack.Claimed + 1, restricted(player))
	if tile.Paid and tile.Product == productKey then
		local ok, text = claimNext(player, data)
		if ok then
			Svc.Net.Notify(player, "Infinite Pack: " .. text, "success")
		end
	else
		Svc.Net.Notify(player, "Pack credit saved! It will unlock your next matching paid tile.", "info")
	end
	Svc.Data.MarkDirty(player)
end

function InfinitePackService.OnPlayerLoaded(_player, data)
	ensureSeason(data)
end

function InfinitePackService.Start()
	Svc.Net.Handle("PackClaim", function(player)
		local data = Svc.Data.Get(player)
		if not Svc.Session.Throttle(player, "pack", 0.3) then
			return { ok = false, msg = "Slow down!" }
		end
		local ok, text = claimNext(player, data)
		if not ok then
			return { ok = false, needPurchase = text == "needPurchase", msg = text == "needPurchase" and "This tile costs Robux!" or text }
		end
		return { ok = true, msg = "🎟️ " .. text }
	end)

	Svc.Net.Handle("PackBuy", function(player)
		local data = Svc.Data.Get(player)
		local season = ensureSeason(data)
		local tile = Gen.GetTile(season, data.InfinitePack.Claimed + 1, restricted(player))
		if not tile.Paid then
			return { ok = false, msg = "This tile is FREE - just claim it!" }
		end
		if (data.InfinitePack.Credits[tile.Product] or 0) > 0 then
			local ok, text = claimNext(player, data)
			return { ok = ok, msg = ok and ("🎟️ " .. text) or text }
		end
		return Svc.Monetization.PromptProduct(player, tile.Product)
	end)

	Svc.Data.AddSyncProvider(function(player, payload)
		local data = Svc.Data.Get(player)
		if data then
			ensureSeason(data)
		end
		payload.PaidRandomRestricted = restricted(player)
	end)
end

return InfinitePackService
