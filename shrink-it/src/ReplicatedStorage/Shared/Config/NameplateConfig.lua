--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > NameplateConfig (ModuleScript)

	Name Plates: the bar with your name that floats over your head (bought in the Name Plates menu,
	opened from the Trail Shop or the Shop). Drawn by Shared > Nameplate, no images needed.

	Colors   = the bar from left to right (it always starts lighter on the left, like a banner)
	Border   = frame color (Rainbow = true → animated rainbow frame)
	Pattern  = "Dots" / "Bubbles" / "Scallop" / "Stripes" / "Diamonds" / "Fire" / "Bars" / "Stars" / "Hearts" / "Rainbow"
	Accent   = color of the pattern
	Icon     = a pixel icon on the left: heart, star, clover, gem, crown, bolt, flame, skull, sword, coin, potion
	Shine    = a white shine sweeps across it
	Cost + Currency ("Coins" / "Gems") · Product = Developer Product key (Robux) · Req = unlock by a stat
]]

local RGB = Color3.fromRGB

local NameplateConfig = {}

NameplateConfig.Default = "Classic"

NameplateConfig.Order = {
	"Classic", "Mint", "Bubblegum", "Ocean", "Sunset", "Jungle", "Candy", "Lava", "Frost", "Royal", "Toxic", "Galaxy",
	"Heartbeat", "Thunder", "BossSlayer", "Reborn",
	"Rainbow", "Champion", "Void",
}

NameplateConfig.Plates = {
	Classic = { Name = "Classic", Rarity = "Common", Colors = { RGB(255, 255, 255), RGB(150, 160, 180) }, Border = RGB(90, 95, 115), Free = true },
	Mint = { Name = "Mint", Rarity = "Common", Cost = 2_500, Currency = "Coins", Colors = { RGB(255, 255, 255), RGB(40, 200, 140) }, Border = RGB(20, 110, 80), Pattern = "Dots", Accent = RGB(255, 255, 255), Icon = "clover" },
	Bubblegum = { Name = "Bubblegum", Rarity = "Uncommon", Cost = 25_000, Currency = "Coins", Colors = { RGB(255, 245, 250), RGB(255, 130, 175) }, Border = RGB(200, 60, 115), Pattern = "Bubbles", Accent = RGB(255, 195, 215), Icon = "heart" },
	Ocean = { Name = "Ocean", Rarity = "Uncommon", Cost = 100_000, Currency = "Coins", Colors = { RGB(240, 250, 255), RGB(70, 150, 255) }, Border = RGB(25, 70, 170), Pattern = "Scallop", Accent = RGB(40, 95, 210), Icon = "gem" },
	Sunset = { Name = "Sunset", Rarity = "Rare", Cost = 750_000, Currency = "Coins", Colors = { RGB(255, 235, 160), RGB(255, 120, 60) }, Border = RGB(190, 70, 25), Pattern = "Bubbles", Accent = RGB(255, 175, 90), Icon = "star" },
	Jungle = { Name = "Jungle", Rarity = "Rare", Cost = 3_000_000, Currency = "Coins", Colors = { RGB(245, 235, 190), RGB(95, 150, 60) }, Border = RGB(45, 80, 30), Pattern = "Stripes", Accent = RGB(50, 95, 35), Icon = "clover" },
	Candy = { Name = "Candy Stripe", Rarity = "Epic", Cost = 40_000_000, Currency = "Coins", Colors = { RGB(255, 255, 255), RGB(255, 105, 150) }, Border = RGB(175, 35, 90), Pattern = "Stripes", Accent = RGB(255, 255, 255), Icon = "heart" },
	Lava = { Name = "Lava", Rarity = "Epic", Cost = 250_000_000, Currency = "Coins", Colors = { RGB(255, 220, 90), RGB(230, 45, 40) }, Border = RGB(110, 20, 10), Pattern = "Fire", Accent = RGB(255, 140, 30), Icon = "flame" },
	Frost = { Name = "Frost", Rarity = "Legendary", Cost = 2_000_000_000, Currency = "Coins", Colors = { RGB(255, 255, 255), RGB(140, 215, 255) }, Border = RGB(35, 115, 200), Pattern = "Diamonds", Accent = RGB(255, 255, 255), Icon = "gem", Shine = true },
	Royal = { Name = "Royal", Rarity = "Legendary", Cost = 20_000_000_000, Currency = "Coins", Colors = { RGB(255, 240, 175), RGB(165, 85, 230) }, Border = RGB(235, 175, 30), Pattern = "Dots", Accent = RGB(255, 215, 70), Icon = "crown", Shine = true },
	Toxic = { Name = "Toxic", Rarity = "Mythic", Cost = 300_000_000_000, Currency = "Coins", Colors = { RGB(70, 75, 70), RGB(25, 30, 25) }, Border = RGB(15, 15, 15), Pattern = "Bars", Accent = RGB(210, 255, 40), Icon = "skull" },
	Galaxy = { Name = "Galaxy", Rarity = "Cosmic", Cost = 5_000_000_000_000, Currency = "Coins", Colors = { RGB(90, 50, 170), RGB(15, 10, 45) }, Border = RGB(150, 95, 255), Pattern = "Stars", Accent = RGB(255, 255, 255), Icon = "star", Shine = true },

	Heartbeat = { Name = "Heartbeat", Rarity = "Gems", Cost = 300, Currency = "Gems", Colors = { RGB(255, 240, 245), RGB(230, 55, 120) }, Border = RGB(140, 20, 70), Pattern = "Hearts", Accent = RGB(255, 200, 220), Icon = "heart" },
	Thunder = { Name = "Thunder", Rarity = "Gems", Cost = 600, Currency = "Gems", Colors = { RGB(255, 250, 205), RGB(255, 195, 40) }, Border = RGB(150, 95, 10), Pattern = "Bars", Accent = RGB(120, 70, 10), Icon = "bolt", Shine = true },
	BossSlayer = { Name = "Boss Slayer", Rarity = "Mastery", Colors = { RGB(230, 235, 245), RGB(120, 130, 155) }, Border = RGB(200, 40, 40), Pattern = "Diamonds", Accent = RGB(220, 60, 60), Icon = "sword", Req = { Stat = "BossKills", Amount = 5, Label = "Beat the boss 5 times" } },
	Reborn = { Name = "Reborn", Rarity = "Mastery", Colors = { RGB(255, 250, 220), RGB(60, 210, 160) }, Border = RGB(20, 120, 90), Pattern = "Scallop", Accent = RGB(30, 160, 120), Icon = "potion", Req = { Stat = "Rebirths", Amount = 3, Label = "Rebirth 3 times" } },

	Rainbow = { Name = "Rainbow", Rarity = "Robux", Product = "PlateRainbow", Colors = { RGB(255, 255, 255), RGB(255, 255, 255) }, Border = RGB(255, 255, 255), Rainbow = true, Pattern = "Rainbow", Icon = "star", Shine = true },
	Champion = { Name = "Champion", Rarity = "Robux", Product = "PlateChampion", Colors = { RGB(255, 245, 170), RGB(235, 150, 20) }, Border = RGB(255, 255, 255), Rainbow = true, Pattern = "Diamonds", Accent = RGB(255, 250, 220), Icon = "crown", Shine = true },
	Void = { Name = "Void", Rarity = "Robux", Product = "PlateVoid", Colors = { RGB(60, 25, 95), RGB(5, 5, 15) }, Border = RGB(255, 255, 255), Rainbow = true, Pattern = "Stars", Accent = RGB(200, 140, 255), Icon = "skull", Shine = true, TextColor = RGB(230, 200, 255) },
}

-- card colors per rarity (menu)
NameplateConfig.RarityColors = {
	Common = { RGB(250, 250, 252), RGB(190, 190, 200) },
	Uncommon = { RGB(110, 255, 60), RGB(40, 190, 30) },
	Rare = { RGB(80, 200, 255), RGB(20, 110, 230) },
	Epic = { RGB(200, 110, 255), RGB(110, 30, 210) },
	Legendary = { RGB(255, 225, 80), RGB(245, 140, 10) },
	Mythic = { RGB(255, 90, 80), RGB(170, 10, 20) },
	Cosmic = { RGB(170, 70, 255), RGB(50, 20, 170) },
	Gems = { RGB(140, 230, 255), RGB(50, 120, 240) },
	Mastery = { RGB(255, 120, 100), RGB(150, 40, 60) },
	Robux = { RGB(120, 255, 140), RGB(30, 170, 60) },
}

return NameplateConfig
