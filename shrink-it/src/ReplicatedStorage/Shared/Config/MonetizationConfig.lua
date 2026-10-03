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
	"Carry2x", "Carry5x", "CarryInfinite", "DoubleCoins", "DoubleLuck", "VIP", "AutoShrink", "InstantCharge",
	"ExtraPedestals", "FastBoxes", "BigSizes", "GoldenRay", "CosmicHunter", "LongRange", "Teleport", "OfflineEarnings",
	"DoubleSpeed", "SpeedBoots", "RainbowRay", "RaidShield",
}

-- ── GAMEPASSES (one-time) ─────────────────────────────────────────────
MonetizationConfig.GamePasses = {
	DoubleCoins = { Id = 0, Name = "2x Coins", Emoji = "💰", Image = "rbxassetid://0", PriceLabel = "R$ 199", Description = "Double all coin income forever." }, -- 🔧 REPLACE Id
	DoubleLuck = { Id = 0, Name = "2x Luck", Emoji = "🍀", Image = "rbxassetid://0", PriceLabel = "R$ 249", Description = "Double variant luck forever." }, -- 🔧 REPLACE Id
	VIP = { Id = 0, Name = "VIP", Emoji = "👑", Image = "rbxassetid://0", PriceLabel = "R$ 399", Description = "Chat tag, VIP lounge & gem fountain, 1.5x everything." }, -- 🔧 REPLACE Id
	AutoShrink = { Id = 0, Name = "Auto Shrink", Emoji = "🤖", Image = "rbxassetid://0", PriceLabel = "R$ 299", Description = "Automatically zaps the nearest valid object." }, -- 🔧 REPLACE Id
	InstantCharge = { Id = 0, Name = "Instant Charge", Emoji = "⚡", Image = "rbxassetid://0", PriceLabel = "R$ 149", Description = "Your ray charges instantly." }, -- 🔧 REPLACE Id
	Carry2x = { Id = 0, Name = "2x Carry", Emoji = "🎒", Image = "rbxassetid://0", PriceLabel = "R$ 199", Description = "Carry 2x more boxes per trip." }, -- 🔧 REPLACE Id
	Carry5x = { Id = 0, Name = "5x Carry", Emoji = "🧳", Image = "rbxassetid://0", PriceLabel = "R$ 799", Description = "Carry 5x more boxes per trip." }, -- 🔧 REPLACE Id
	CarryInfinite = { Id = 0, Name = "Infinite Carry", Emoji = "♾️", Image = "rbxassetid://0", PriceLabel = "R$ 4999", Description = "Carry as many boxes as you want. No limit. Ever." }, -- 🔧 REPLACE Id
	FastBoxes = { Id = 0, Name = "Fast Boxes", Emoji = "⏩", Image = "rbxassetid://0", PriceLabel = "R$ 249", Description = "Boxes in your base open 2x faster." }, -- 🔧 REPLACE Id
	BigSizes = { Id = 0, Name = "Big Sizes", Emoji = "📏", Image = "rbxassetid://0", PriceLabel = "R$ 299", Description = "Huge, Giant & Colossal sizes are 3x more likely." }, -- 🔧 REPLACE Id
	ExtraPedestals = { Id = 0, Name = "+20 Display Spots", Emoji = "🏛️", Image = "rbxassetid://0", PriceLabel = "R$ 249", Description = "20 extra spots in your plot." }, -- 🔧 REPLACE Id
	GoldenRay = { Id = 0, Name = "Golden Ray", Emoji = "🌟", Image = "rbxassetid://0", PriceLabel = "R$ 199", Description = "2x Golden & Diamond chance." }, -- 🔧 REPLACE Id
	CosmicHunter = { Id = 0, Name = "Cosmic Hunter", Emoji = "🌌", Image = "rbxassetid://0", PriceLabel = "R$ 299", Description = "2x Cosmic chance." }, -- 🔧 REPLACE Id
	LongRange = { Id = 0, Name = "Long Range Ray", Emoji = "🔭", Image = "rbxassetid://0", PriceLabel = "R$ 99", Description = "+50% ray range." }, -- 🔧 REPLACE Id
	Teleport = { Id = 0, Name = "Teleport", Emoji = "🌀", Image = "rbxassetid://0", PriceLabel = "R$ 149", Description = "Teleport to the start of any zone." }, -- 🔧 REPLACE Id
	OfflineEarnings = { Id = 0, Name = "Offline Earnings", Emoji = "😴", Image = "rbxassetid://0", PriceLabel = "R$ 199", Description = "Earn 50% income while offline (8h max)." }, -- 🔧 REPLACE Id
	DoubleSpeed = { Id = 0, Name = "2x Speed", Emoji = "⚡", Image = "rbxassetid://0", PriceLabel = "R$ 249", Description = "Double your trained speed AND train twice as fast." }, -- 🔧 REPLACE Id
	SpeedBoots = { Id = 0, Name = "Speed Boots", Emoji = "👟", Image = "rbxassetid://0", PriceLabel = "R$ 79", Description = "+8 run speed. Outrun every chaser!" }, -- 🔧 REPLACE Id
	RainbowRay = { Id = 0, Name = "Rainbow Ray Beam", Emoji = "🌈", Image = "rbxassetid://0", PriceLabel = "R$ 99", Description = "Rainbow ray beam + rainbow trail (cosmetic)." }, -- 🔧 REPLACE Id
	RaidShield = { Id = 0, Name = "Raid Shield", Emoji = "🛡️", Image = "rbxassetid://0", PriceLabel = "R$ 149", Description = "3x longer raid protection, 2x revenge rewards." }, -- 🔧 REPLACE Id
}

-- ── DEVELOPER PRODUCTS (repeatable) ───────────────────────────────────
-- Grant = the reward table given on purchase (see RewardUtil for reward types).
-- Handler = special server logic instead of / in addition to Grant.
MonetizationConfig.ProductOrder = {
	"CoinsSmall", "CoinsMedium", "CoinsLarge", "GemsSmall", "GemsMedium", "GemsLarge",
	"LuckPotion", "IncomePotion", "ServerLuck", "OpenAllBoxes", "LimitedBox", "SpeedPoints", "InstantRebirth", "SpawnGolden",
}
-- (RoyalCrate is shown on its own "Crates" tab in the Shop, with its odds)

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
	InstantOpen = { Id = 0, Name = "Instant Open (1 box)", Emoji = "📦", PriceLabel = "R$ 9", Handler = "InstantOpen", Hidden = true }, -- 🔧 REPLACE Id (bought from the box itself)
	LimitedBox = { Id = 0, Name = "LIMITED Festive Box", Emoji = "🎁", Image = "rbxassetid://0", PriceLabel = "R$ 149", Handler = "LimitedBox", Limited = true }, -- 🔧 REPLACE Id (Robux only, always Festive-mutated)
	OpenAllBoxes = { Id = 0, Name = "Open All Boxes Now", Emoji = "📦", Image = "rbxassetid://0", PriceLabel = "R$ 29", Handler = "OpenAllBoxes" }, -- 🔧 REPLACE Id
	SpeedPoints = { Id = 0, Name = "+30 Min of Training", Emoji = "🏃", Image = "rbxassetid://0", PriceLabel = "R$ 49", Handler = "SpeedPoints", Minutes = 30 }, -- 🔧 REPLACE Id
	InstantRebirth = { Id = 0, Name = "Instant Rebirth", Emoji = "♻️", Image = "rbxassetid://0", PriceLabel = "R$ 99", Handler = "InstantRebirth" }, -- 🔧 REPLACE Id
	SpawnGolden = { Id = 0, Name = "Spawn a Golden Object", Emoji = "🌟", Image = "rbxassetid://0", PriceLabel = "R$ 29", Handler = "SpawnGolden" }, -- 🔧 REPLACE Id

	-- Royal Crate: one random exclusive from MonetizationConfig.RoyalCrate (odds shown in the Shop)
	RoyalCrate = { Id = 0, Name = "Royal Crate", Emoji = "👑", PriceLabel = "R$ 99", Handler = "RoyalCrate", Hidden = true }, -- 🔧 REPLACE Id
	RoyalCrate3 = { Id = 0, Name = "3x Royal Crate", Emoji = "👑", PriceLabel = "R$ 249", Handler = "RoyalCrate", Count = 3, Hidden = true }, -- 🔧 REPLACE Id

	-- Trails bought with Robux (Trail Shop purple buttons). Hidden from the Shop list.
	TrailGreen = { Id = 0, Name = "Green Trail", Emoji = "🟩", PriceLabel = "R$ 19", Handler = "Trail", Trail = "Green", Hidden = true }, -- 🔧 REPLACE Id
	TrailBlue = { Id = 0, Name = "Blue Trail", Emoji = "🟦", PriceLabel = "R$ 29", Handler = "Trail", Trail = "Blue", Hidden = true }, -- 🔧 REPLACE Id
	TrailPurple = { Id = 0, Name = "Purple Trail", Emoji = "🟪", PriceLabel = "R$ 49", Handler = "Trail", Trail = "Purple", Hidden = true }, -- 🔧 REPLACE Id
	TrailGold = { Id = 0, Name = "Gold Trail", Emoji = "🟨", PriceLabel = "R$ 79", Handler = "Trail", Trail = "Gold", Hidden = true }, -- 🔧 REPLACE Id
	TrailRed = { Id = 0, Name = "Red Trail", Emoji = "🟥", PriceLabel = "R$ 119", Handler = "Trail", Trail = "Red", Hidden = true }, -- 🔧 REPLACE Id
	TrailGalaxy = { Id = 0, Name = "Galaxy Trail", Emoji = "🌌", PriceLabel = "R$ 199", Handler = "Trail", Trail = "Galaxy", Hidden = true }, -- 🔧 REPLACE Id
	TrailSecret = { Id = 0, Name = "Secret Trail", Emoji = "🦓", PriceLabel = "R$ 349", Handler = "Trail", Trail = "Secret", Hidden = true }, -- 🔧 REPLACE Id
	TrailEternal = { Id = 0, Name = "Eternal Trail", Emoji = "♾️", PriceLabel = "R$ 499", Handler = "Trail", Trail = "Eternal", Hidden = true }, -- 🔧 REPLACE Id

	-- Infinite Pack paid tiles (repeatable). Price tier is picked by tile position.
	PackTier1 = { Id = 0, Name = "Infinite Pack Tile", Emoji = "🎟️", Image = "rbxassetid://0", PriceLabel = "R$ 25", Handler = "InfinitePack", Hidden = true }, -- 🔧 REPLACE Id
	PackTier2 = { Id = 0, Name = "Infinite Pack Tile+", Emoji = "🎟️", Image = "rbxassetid://0", PriceLabel = "R$ 59", Handler = "InfinitePack", Hidden = true }, -- 🔧 REPLACE Id
	PackTier3 = { Id = 0, Name = "Infinite Pack Tile++", Emoji = "🎟️", Image = "rbxassetid://0", PriceLabel = "R$ 99", Handler = "InfinitePack", Hidden = true }, -- 🔧 REPLACE Id
}

-- ── Royal Crate (Robux only) ──────────────────────────────────────────
-- 5 exclusive objects that NEVER spawn on the map. Chance = percent (must add up to 100; shown in the Shop).
-- Players where Roblox restricts paid random items (PolicyService) can't buy it.
MonetizationConfig.RoyalCrate = {
	Name = "Royal Crate",
	Items = {
		{ Id = "KingDuck", Chance = 40 },
		{ Id = "GoldenToilet", Chance = 30 },
		{ Id = "NeonUnicorn", Chance = 18 },
		{ Id = "DragonEgg", Chance = 9 },
		{ Id = "GalaxyOrb", Chance = 3 },
	},
}

-- ── Ray skins (cosmetic beam colors) ──────────────────────────────────
-- Model = the ray gun from your asset pack (ServerStorage > AssetPack) you hold with this skin.
MonetizationConfig.SkinOrder = { "Default", "Bubblegum", "Toxic", "Sunset", "Galaxy", "Rainbow" }
MonetizationConfig.RaySkins = {
	Default = { Name = "Classic", Model = "ray_blue", Colors = { Color3.fromRGB(80, 220, 255), Color3.fromRGB(30, 120, 255) } },
	Bubblegum = { Name = "Bubblegum", Model = "ray_purple", Colors = { Color3.fromRGB(255, 140, 220), Color3.fromRGB(255, 60, 160) } },
	Toxic = { Name = "Toxic", Model = "ray_green", Colors = { Color3.fromRGB(170, 255, 60), Color3.fromRGB(40, 200, 40) } },
	Sunset = { Name = "Sunset", Model = "ray_gold", Colors = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 70, 50) } },
	Galaxy = { Name = "Galaxy", Model = "ray_galaxy", Colors = { Color3.fromRGB(150, 90, 255), Color3.fromRGB(20, 10, 80) } },
	Rainbow = { Name = "Rainbow", Model = "ray_rainbow", Colors = { Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 0, 255) }, Rainbow = true, Pass = "RainbowRay" },
}

-- ── Trails (bought at the TRAILS stand) ───────────────────────────────
-- Every trail makes you run faster (Speed = walk-speed multiplier while equipped).
-- Cost = price in Coins; Product = a Developer Product key to buy it with Robux instead (optional);
-- Pass = a gamepass key that unlocks it. Pattern = "Zebra" / "Galaxy" for striped / starry trails.
MonetizationConfig.TrailOrder = { "Grey", "Green", "Blue", "Purple", "Gold", "Red", "Galaxy", "Secret", "Eternal", "Rainbow" }
MonetizationConfig.Trails = {
	Grey = { Name = "Grey Trail", Rarity = "Common", Speed = 1.05, Cost = 100, Colors = { Color3.fromRGB(235, 235, 240), Color3.fromRGB(150, 150, 160) } },
	Green = { Name = "Green Trail", Rarity = "Uncommon", Speed = 1.1, Cost = 5_000, Product = "TrailGreen", Colors = { Color3.fromRGB(120, 255, 90), Color3.fromRGB(30, 190, 40) } },
	Blue = { Name = "Blue Trail", Rarity = "Rare", Speed = 1.15, Cost = 75_000, Product = "TrailBlue", Colors = { Color3.fromRGB(110, 230, 255), Color3.fromRGB(20, 120, 240) } },
	Purple = { Name = "Purple Trail", Rarity = "Epic", Speed = 1.2, Cost = 1_000_000, Product = "TrailPurple", Colors = { Color3.fromRGB(215, 140, 255), Color3.fromRGB(130, 40, 230) } },
	Gold = { Name = "Gold Trail", Rarity = "Legendary", Speed = 1.25, Cost = 50_000_000, Product = "TrailGold", Colors = { Color3.fromRGB(255, 240, 120), Color3.fromRGB(240, 160, 20) } },
	Red = { Name = "Red Trail", Rarity = "Mythic", Speed = 1.3, Cost = 1_000_000_000, Product = "TrailRed", Colors = { Color3.fromRGB(255, 110, 90), Color3.fromRGB(210, 20, 30) } },
	Galaxy = { Name = "Galaxy Trail", Rarity = "Cosmic", Speed = 1.4, Cost = 20_000_000_000, Product = "TrailGalaxy", Pattern = "Galaxy", Colors = { Color3.fromRGB(230, 120, 255), Color3.fromRGB(40, 20, 140) } },
	Secret = { Name = "Secret Trail", Rarity = "Secret", Speed = 1.5, Cost = 500_000_000_000, Product = "TrailSecret", Pattern = "Zebra", Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 25) } },
	Eternal = { Name = "Eternal Trail", Rarity = "Eternal", Speed = 1.6, Cost = 12_500_000_000_000, Product = "TrailEternal", Colors = { Color3.fromRGB(255, 120, 230), Color3.fromRGB(60, 230, 255) } },
	Rainbow = { Name = "Rainbow Trail", Rarity = "Gamepass", Speed = 1.3, Rainbow = true, Pass = "RainbowRay", Colors = { Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 120, 255) } },
}
-- card colors per trail rarity (Trail Shop)
MonetizationConfig.TrailRarityColors = {
	Common = { Color3.fromRGB(250, 250, 252), Color3.fromRGB(190, 190, 200) },
	Uncommon = { Color3.fromRGB(110, 255, 60), Color3.fromRGB(40, 190, 30) },
	Rare = { Color3.fromRGB(80, 200, 255), Color3.fromRGB(20, 110, 230) },
	Epic = { Color3.fromRGB(200, 110, 255), Color3.fromRGB(110, 30, 210) },
	Legendary = { Color3.fromRGB(255, 225, 80), Color3.fromRGB(245, 140, 10) },
	Mythic = { Color3.fromRGB(255, 90, 80), Color3.fromRGB(170, 10, 20) },
	Cosmic = { Color3.fromRGB(170, 70, 255), Color3.fromRGB(50, 20, 170) },
	Secret = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 160) },
	Eternal = { Color3.fromRGB(40, 245, 255), Color3.fromRGB(255, 60, 220) },
	Gamepass = { Color3.fromRGB(255, 120, 120), Color3.fromRGB(120, 120, 255) },
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
