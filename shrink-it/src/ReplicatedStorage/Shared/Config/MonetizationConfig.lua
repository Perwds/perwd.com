--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > MonetizationConfig (ModuleScript)

	🔧 REPLACE every `Id = 0` with your real Gamepass / Developer Product ids
	   (Creator Dashboard → your experience → Monetization).
	   Anything left at 0 is shown as "Coming soon" and can't be purchased.
	🔧 REPLACE `Image = "rbxassetid://0"` with your own icon images (optional; emoji is the fallback).

	PriceLabel is only a fallback; the client fetches the real price from Roblox.
]]

local MonetizationConfig = {}

MonetizationConfig.PassOrder = {
	"DoubleCoins", "DoubleLuck", "VIP", "AutoShrink", "InstantCharge", "MultiShrink3",
	"ExtraPedestals", "GoldenRay", "CosmicHunter", "LongRange", "Teleport", "OfflineEarnings",
	"SpeedBoots", "RainbowRay", "RaidShield",
}

-- ── GAMEPASSES (one-time) ─────────────────────────────────────────────
MonetizationConfig.GamePasses = {
	DoubleCoins = { Id = 0, Name = "2x Coins", Emoji = "💰", Image = "rbxassetid://0", PriceLabel = "R$ 199", Description = "Double all coin income forever." }, -- 🔧 REPLACE Id
	DoubleLuck = { Id = 0, Name = "2x Luck", Emoji = "🍀", Image = "rbxassetid://0", PriceLabel = "R$ 249", Description = "Double variant luck forever." }, -- 🔧 REPLACE Id
	VIP = { Id = 0, Name = "VIP", Emoji = "👑", Image = "rbxassetid://0", PriceLabel = "R$ 399", Description = "Chat tag, VIP lounge & gem fountain, 1.5x everything." }, -- 🔧 REPLACE Id
	AutoShrink = { Id = 0, Name = "Auto Shrink", Emoji = "🤖", Image = "rbxassetid://0", PriceLabel = "R$ 299", Description = "Automatically zaps the nearest valid object." }, -- 🔧 REPLACE Id
	InstantCharge = { Id = 0, Name = "Instant Charge", Emoji = "⚡", Image = "rbxassetid://0", PriceLabel = "R$ 149", Description = "Your ray charges instantly." }, -- 🔧 REPLACE Id
	MultiShrink3 = { Id = 0, Name = "Multi-Shrink x3", Emoji = "✨", Image = "rbxassetid://0", PriceLabel = "R$ 349", Description = "Triple your Multi-Shrink targets." }, -- 🔧 REPLACE Id
	ExtraPedestals = { Id = 0, Name = "+20 Pedestals", Emoji = "🏛️", Image = "rbxassetid://0", PriceLabel = "R$ 249", Description = "20 extra museum pedestals." }, -- 🔧 REPLACE Id
	GoldenRay = { Id = 0, Name = "Golden Ray", Emoji = "🌟", Image = "rbxassetid://0", PriceLabel = "R$ 199", Description = "2x Golden & Diamond chance." }, -- 🔧 REPLACE Id
	CosmicHunter = { Id = 0, Name = "Cosmic Hunter", Emoji = "🌌", Image = "rbxassetid://0", PriceLabel = "R$ 299", Description = "2x Cosmic chance." }, -- 🔧 REPLACE Id
	LongRange = { Id = 0, Name = "Long Range Ray", Emoji = "🔭", Image = "rbxassetid://0", PriceLabel = "R$ 99", Description = "+50% ray range." }, -- 🔧 REPLACE Id
	Teleport = { Id = 0, Name = "Teleport", Emoji = "🌀", Image = "rbxassetid://0", PriceLabel = "R$ 149", Description = "Teleport to any unlocked area." }, -- 🔧 REPLACE Id
	OfflineEarnings = { Id = 0, Name = "Offline Earnings", Emoji = "😴", Image = "rbxassetid://0", PriceLabel = "R$ 199", Description = "Earn 50% income while offline (8h max)." }, -- 🔧 REPLACE Id
	SpeedBoots = { Id = 0, Name = "Speed Boots", Emoji = "👟", Image = "rbxassetid://0", PriceLabel = "R$ 79", Description = "Run much faster." }, -- 🔧 REPLACE Id
	RainbowRay = { Id = 0, Name = "Rainbow Ray Beam", Emoji = "🌈", Image = "rbxassetid://0", PriceLabel = "R$ 99", Description = "Cosmetic rainbow beam skin." }, -- 🔧 REPLACE Id
	RaidShield = { Id = 0, Name = "Raid Shield", Emoji = "🛡️", Image = "rbxassetid://0", PriceLabel = "R$ 149", Description = "3x longer raid protection, 2x revenge rewards." }, -- 🔧 REPLACE Id
}

-- ── DEVELOPER PRODUCTS (repeatable) ───────────────────────────────────
-- Grant = the reward table given on purchase (see RewardUtil for reward types).
-- Handler = special server logic instead of / in addition to Grant.
MonetizationConfig.ProductOrder = {
	"CoinsSmall", "CoinsMedium", "CoinsLarge", "GemsSmall", "GemsMedium", "GemsLarge",
	"LuckPotion", "IncomePotion", "ServerLuck", "InstantRebirth", "SpawnGolden",
}

MonetizationConfig.Products = {
	CoinsSmall = { Id = 0, Name = "Pile of Coins", Emoji = "💵", Image = "rbxassetid://0", PriceLabel = "R$ 49", Grant = { Type = "CoinsMinutes", Minutes = 30, Floor = 2_500 } }, -- 🔧 REPLACE Id
	CoinsMedium = { Id = 0, Name = "Bag of Coins", Emoji = "💰", Image = "rbxassetid://0", PriceLabel = "R$ 149", Grant = { Type = "CoinsMinutes", Minutes = 120, Floor = 15_000 } }, -- 🔧 REPLACE Id
	CoinsLarge = { Id = 0, Name = "Vault of Coins", Emoji = "🏦", Image = "rbxassetid://0", PriceLabel = "R$ 399", Grant = { Type = "CoinsMinutes", Minutes = 480, Floor = 100_000 } }, -- 🔧 REPLACE Id
	GemsSmall = { Id = 0, Name = "Handful of Gems", Emoji = "💎", Image = "rbxassetid://0", PriceLabel = "R$ 49", Grant = { Type = "Gems", Amount = 100 } }, -- 🔧 REPLACE Id
	GemsMedium = { Id = 0, Name = "Sack of Gems", Emoji = "💎", Image = "rbxassetid://0", PriceLabel = "R$ 199", Grant = { Type = "Gems", Amount = 550 } }, -- 🔧 REPLACE Id
	GemsLarge = { Id = 0, Name = "Chest of Gems", Emoji = "💎", Image = "rbxassetid://0", PriceLabel = "R$ 399", Grant = { Type = "Gems", Amount = 1_200 } }, -- 🔧 REPLACE Id
	LuckPotion = { Id = 0, Name = "Luck Potion (15m)", Emoji = "🧪", Image = "rbxassetid://0", PriceLabel = "R$ 39", Grant = { Type = "LuckPotion", Minutes = 15 } }, -- 🔧 REPLACE Id
	IncomePotion = { Id = 0, Name = "2x Income Potion (15m)", Emoji = "⚗️", Image = "rbxassetid://0", PriceLabel = "R$ 39", Grant = { Type = "IncomePotion", Minutes = 15 } }, -- 🔧 REPLACE Id
	ServerLuck = { Id = 0, Name = "Server Luck Boost (30m)", Emoji = "🌠", Image = "rbxassetid://0", PriceLabel = "R$ 149", Grant = { Type = "ServerLuck", Minutes = 30 } }, -- 🔧 REPLACE Id
	InstantRebirth = { Id = 0, Name = "Instant Rebirth", Emoji = "♻️", Image = "rbxassetid://0", PriceLabel = "R$ 99", Handler = "InstantRebirth" }, -- 🔧 REPLACE Id
	SpawnGolden = { Id = 0, Name = "Spawn a Golden Object", Emoji = "🌟", Image = "rbxassetid://0", PriceLabel = "R$ 29", Handler = "SpawnGolden" }, -- 🔧 REPLACE Id

	-- Infinite Pack paid tiles (repeatable). Price tier is picked by tile position.
	PackTier1 = { Id = 0, Name = "Infinite Pack Tile", Emoji = "🎟️", Image = "rbxassetid://0", PriceLabel = "R$ 25", Handler = "InfinitePack", Hidden = true }, -- 🔧 REPLACE Id
	PackTier2 = { Id = 0, Name = "Infinite Pack Tile+", Emoji = "🎟️", Image = "rbxassetid://0", PriceLabel = "R$ 59", Handler = "InfinitePack", Hidden = true }, -- 🔧 REPLACE Id
	PackTier3 = { Id = 0, Name = "Infinite Pack Tile++", Emoji = "🎟️", Image = "rbxassetid://0", PriceLabel = "R$ 99", Handler = "InfinitePack", Hidden = true }, -- 🔧 REPLACE Id
}

-- ── Ray skins (cosmetic beam colors) ──────────────────────────────────
MonetizationConfig.SkinOrder = { "Default", "Bubblegum", "Toxic", "Sunset", "Galaxy", "Rainbow" }
MonetizationConfig.RaySkins = {
	Default = { Name = "Classic", Colors = { Color3.fromRGB(80, 220, 255), Color3.fromRGB(30, 120, 255) } },
	Bubblegum = { Name = "Bubblegum", Colors = { Color3.fromRGB(255, 140, 220), Color3.fromRGB(255, 60, 160) } },
	Toxic = { Name = "Toxic", Colors = { Color3.fromRGB(170, 255, 60), Color3.fromRGB(40, 200, 40) } },
	Sunset = { Name = "Sunset", Colors = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 70, 50) } },
	Galaxy = { Name = "Galaxy", Colors = { Color3.fromRGB(150, 90, 255), Color3.fromRGB(20, 10, 80) } },
	Rainbow = { Name = "Rainbow", Colors = { Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 0, 255) }, Rainbow = true, Pass = "RainbowRay" },
}

-- ── Gem shop (spend Gems in-game) ─────────────────────────────────────
MonetizationConfig.GemShop = {
	{ Key = "Luck10", Name = "Luck Potion (10m)", Emoji = "🧪", Cost = 150, Reward = { Type = "LuckPotion", Minutes = 10 } },
	{ Key = "Income10", Name = "2x Income Potion (10m)", Emoji = "⚗️", Cost = 150, Reward = { Type = "IncomePotion", Minutes = 10 } },
	{ Key = "Coins60", Name = "1 Hour of Coins", Emoji = "💵", Cost = 250, Reward = { Type = "CoinsMinutes", Minutes = 60, Floor = 5_000 } },
	{ Key = "SkinBubblegum", Name = "Bubblegum Ray", Emoji = "🍬", Cost = 400, Reward = { Type = "RaySkin", Skin = "Bubblegum" } },
	{ Key = "SkinToxic", Name = "Toxic Ray", Emoji = "☢️", Cost = 600, Reward = { Type = "RaySkin", Skin = "Toxic" } },
	{ Key = "SkinSunset", Name = "Sunset Ray", Emoji = "🌅", Cost = 900, Reward = { Type = "RaySkin", Skin = "Sunset" } },
}

function MonetizationConfig.ProductKeyById(productId)
	for key, p in pairs(MonetizationConfig.Products) do
		if p.Id ~= 0 and p.Id == productId then
			return key
		end
	end
	return nil
end

return MonetizationConfig
