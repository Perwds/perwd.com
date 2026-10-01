--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Prices (ModuleScript)

	Fetches real Robux prices for gamepasses / developer products (cached).
	Falls back to the PriceLabel from MonetizationConfig.
]]

local MarketplaceService = game:GetService("MarketplaceService")

local Prices = {}
local cache = {}
local listeners = {}

-- infoType: Enum.InfoType.GamePass | Enum.InfoType.Product
function Prices.Get(infoType, id, fallback)
	if not id or id == 0 then
		return fallback or "Soon"
	end
	local key = tostring(infoType) .. ":" .. id
	local cached = cache[key]
	if cached then
		return cached
	end
	if cached == nil then
		cache[key] = false
		task.spawn(function()
			local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
			if ok and info and info.PriceInRobux then
				cache[key] = "R$ " .. info.PriceInRobux
				for _, fn in ipairs(listeners) do
					task.spawn(fn)
				end
			end
		end)
	end
	return fallback or "R$ ?"
end

-- fn is called whenever a new price arrives (to re-render)
function Prices.OnUpdated(fn)
	table.insert(listeners, fn)
end

return Prices
