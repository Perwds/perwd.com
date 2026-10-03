--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > NameplateConfig (ModuleScript)

	Name Plates: the bar with your name that floats over your head (bought in the Name Plates menu,
	opened from the Trail Shop or the Shop). Drawn by Shared > Nameplate, no images needed.

	Colors   = the bar from left to right (it always starts lighter on the left, like a banner)
	Border   = frame color (Rainbow = true → animated rainbow frame)
	Pattern  = "Dots" / "Bubbles" / "Scallop" / "Stripes" / "Diamonds" / "Fire" / "Bars" / "Stars" / "Hearts" / "Rainbow"
	Accent   = color of the pattern
	Icon     = a pixel icon on the left: heart, star, clover, gem, crown, bolt, flame, skull, sword, coin, potion,
	           ghost, cherry, moon, sakura, snowflake, computer, cake  (IconBoth = true → on both ends)
	Blinkie extras: Font = "Arcade" (pixel font) · BorderStyle = "Dashed" / "Dotted" (+ DashColor) · Blink = true
	           more patterns: "Hazard", "Checker", "Equalizer", "Skyline", "Drip", "Glitter", "Sparkle", "Matrix"
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
	-- blinkies (pixel font, dashed frames, some of them blink)
	"Sweetheart", "Cherry", "Sakura", "SnowDay", "Spooky", "Slime", "Crimson", "Hazard", "NightCity", "Matrix",
	"ComputerLove", "Party", "Stargazer", "Sparkling", "GlitterGold", "Nightcore", "Rave",
	-- glossy studded panels + your own color
	"StudOrange", "StudRed", "StudLime", "StudPurple", "StudIce", "StudRainbow", "Custom",
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

-- ── blinkies ──
local function blinkie(t)
	t.Font = t.Font or "Arcade"
	return t
end
local P = NameplateConfig.Plates
P.Sweetheart = blinkie({ Name = "Sweetheart", Rarity = "Uncommon", Cost = 50_000, Currency = "Coins", Colors = { RGB(255, 225, 240), RGB(255, 170, 210) }, Border = RGB(235, 110, 170), BorderStyle = "Dashed", DashColor = RGB(255, 255, 255), Pattern = "Hearts", Accent = RGB(255, 255, 255), Icon = "heart", IconBoth = true })
P.Cherry = blinkie({ Name = "Cherry Kisses", Rarity = "Rare", Cost = 1_500_000, Currency = "Coins", Colors = { RGB(255, 255, 255), RGB(255, 225, 235) }, Border = RGB(200, 30, 60), BorderStyle = "Dotted", DashColor = RGB(255, 200, 215), Icon = "cherry", IconBoth = true, TextColor = RGB(255, 80, 120) })
P.Sakura = blinkie({ Name = "Sakura", Rarity = "Rare", Cost = 6_000_000, Currency = "Coins", Colors = { RGB(255, 240, 248), RGB(250, 160, 200) }, Border = RGB(180, 70, 130), BorderStyle = "Dashed", DashColor = RGB(255, 225, 240), Pattern = "Bubbles", Accent = RGB(255, 205, 225), Icon = "sakura", IconBoth = true })
P.SnowDay = blinkie({ Name = "Snow Day", Rarity = "Epic", Cost = 80_000_000, Currency = "Coins", Colors = { RGB(140, 200, 255), RGB(60, 130, 230) }, Border = RGB(255, 255, 255), BorderStyle = "Dotted", DashColor = RGB(60, 130, 230), Pattern = "Glitter", Accent = RGB(255, 255, 255), Accent2 = RGB(200, 235, 255), Icon = "snowflake", IconBoth = true })
P.Spooky = blinkie({ Name = "Stay Spooky", Rarity = "Epic", Cost = 400_000_000, Currency = "Coins", Colors = { RGB(30, 25, 35), RGB(10, 8, 15) }, Border = RGB(25, 20, 30), BorderStyle = "Dashed", DashColor = RGB(255, 140, 30), Icon = "ghost", IconBoth = true, TextColor = RGB(255, 150, 40), Blink = true, Pattern = "Sparkle", Accent = RGB(255, 140, 30) })
P.Slime = blinkie({ Name = "Slime", Rarity = "Legendary", Cost = 3_000_000_000, Currency = "Coins", Colors = { RGB(40, 70, 35), RGB(15, 30, 15) }, Border = RGB(10, 20, 10), Pattern = "Drip", Accent = RGB(130, 255, 60), TextColor = RGB(170, 255, 110) })
P.Crimson = blinkie({ Name = "Crimson Drip", Rarity = "Legendary", Cost = 30_000_000_000, Currency = "Coins", Colors = { RGB(35, 10, 15), RGB(10, 0, 5) }, Border = RGB(120, 0, 15), Pattern = "Drip", Accent = RGB(210, 20, 40), Icon = "moon", TextColor = RGB(255, 70, 80) })
P.Hazard = blinkie({ Name = "Under Construction", Rarity = "Mythic", Cost = 150_000_000_000, Currency = "Coins", Colors = { RGB(255, 225, 40), RGB(255, 205, 20) }, Border = RGB(20, 20, 20), Pattern = "Hazard", Accent = RGB(25, 25, 25) })
P.NightCity = blinkie({ Name = "Night City", Rarity = "Mythic", Cost = 800_000_000_000, Currency = "Coins", Colors = { RGB(40, 45, 70), RGB(10, 12, 25) }, Border = RGB(255, 255, 255), BorderStyle = "Dotted", DashColor = RGB(20, 20, 30), Pattern = "Skyline", Accent = RGB(70, 75, 100), Icon = "heart" })
P.Matrix = blinkie({ Name = "Matrix", Rarity = "Cosmic", Cost = 10_000_000_000_000, Currency = "Coins", Colors = { RGB(10, 25, 12), RGB(0, 5, 0) }, Border = RGB(40, 200, 70), BorderStyle = "Dashed", DashColor = RGB(10, 30, 10), Pattern = "Matrix", Accent = RGB(60, 255, 100), Icon = "computer", TextColor = RGB(120, 255, 140) })
P.ComputerLove = blinkie({ Name = "I Love My Computer", Rarity = "Gems", Cost = 250, Currency = "Gems", Colors = { RGB(255, 255, 255), RGB(250, 235, 255) }, Border = RGB(150, 60, 220), BorderStyle = "Dashed", DashColor = RGB(255, 255, 255), Pattern = "Hearts", Accent = RGB(255, 120, 200), Icon = "computer", IconBoth = true, TextColor = RGB(220, 80, 200) })
P.Party = blinkie({ Name = "Party Time", Rarity = "Gems", Cost = 450, Currency = "Gems", Colors = { RGB(255, 245, 250), RGB(255, 200, 230) }, Border = RGB(70, 140, 255), BorderStyle = "Dotted", DashColor = RGB(255, 230, 80), Pattern = "Glitter", Accent = RGB(255, 90, 160), Accent2 = RGB(80, 200, 255), Icon = "cake", IconBoth = true, Blink = true })
P.Stargazer = blinkie({ Name = "Stargazer", Rarity = "Gems", Cost = 800, Currency = "Gems", Colors = { RGB(25, 20, 50), RGB(5, 5, 15) }, Border = RGB(120, 90, 255), BorderStyle = "Dotted", DashColor = RGB(255, 255, 255), Pattern = "Stars", Accent = RGB(255, 255, 255), Icon = "moon", IconBoth = true, Blink = true })
P.Sparkling = blinkie({ Name = "Never Stop Sparkling", Rarity = "Gems", Cost = 1_200, Currency = "Gems", Colors = { RGB(255, 120, 200), RGB(235, 40, 150) }, Border = RGB(255, 255, 255), BorderStyle = "Dashed", DashColor = RGB(235, 40, 150), Pattern = "Sparkle", Accent = RGB(255, 255, 255), Blink = true })
P.GlitterGold = blinkie({ Name = "Glitter Gold", Rarity = "Robux", Product = "PlateGlitter", Colors = { RGB(255, 235, 150), RGB(210, 160, 40) }, Border = RGB(120, 80, 10), Pattern = "Glitter", Accent = RGB(255, 250, 210), Accent2 = RGB(170, 120, 20), Icon = "crown", IconBoth = true, Blink = true, Shine = true })
P.Nightcore = blinkie({ Name = "Nightcore", Rarity = "Robux", Product = "PlateNightcore", Colors = { RGB(25, 25, 35), RGB(10, 10, 15) }, Border = RGB(255, 255, 255), Rainbow = true, Pattern = "Equalizer", Blink = true, TextColor = RGB(255, 240, 120) })
P.Rave = blinkie({ Name = "Rave", Rarity = "Robux", Product = "PlateRave", Colors = { RGB(0, 0, 0), RGB(0, 0, 0) }, Border = RGB(255, 255, 255), Rainbow = true, Pattern = "Checker", Icon = "star", IconBoth = true, Shine = true })

-- ── glossy studded panels ──
local function stud(name, rarity, cost, top, bottom, border, accent)
	return { Name = name, Rarity = rarity, Cost = cost, Currency = "Coins", Colors = { top, bottom }, Vertical = true, Border = border, Pattern = "Studs", Accent = accent }
end
P.StudOrange = stud("Orange Panel", "Common", 10_000, RGB(255, 210, 60), RGB(255, 140, 20), RGB(150, 70, 0), RGB(255, 240, 150))
P.StudRed = stud("Red Panel", "Uncommon", 150_000, RGB(255, 120, 130), RGB(225, 30, 55), RGB(120, 0, 20), RGB(255, 190, 200))
P.StudLime = stud("Lime Panel", "Rare", 2_500_000, RGB(220, 255, 60), RGB(70, 210, 20), RGB(20, 100, 0), RGB(240, 255, 170))
P.StudPurple = stud("Purple Panel", "Epic", 60_000_000, RGB(150, 110, 255), RGB(90, 30, 230), RGB(50, 0, 140), RGB(200, 180, 255))
P.StudIce = stud("Ice Panel", "Legendary", 1_000_000_000, RGB(235, 255, 255), RGB(110, 225, 255), RGB(20, 130, 170), RGB(255, 255, 255))
P.StudRainbow = { Name = "Rainbow Panel", Rarity = "Gems", Cost = 1_500, Currency = "Gems", Colors = { RGB(255, 255, 255), RGB(255, 255, 255) }, Vertical = true, RainbowBody = true, Border = RGB(255, 255, 255), Pattern = "Studs", Accent = RGB(255, 255, 255), Shine = true }
-- Custom: pick ANY color (all 16,777,216) with the color picker in the Name Plates menu
P.Custom = { Name = "Custom Color", Rarity = "Robux", Product = "PlateCustom", CustomColor = true, Colors = { RGB(255, 200, 150), RGB(255, 120, 40) }, Vertical = true, Border = RGB(140, 60, 10), Pattern = "Studs", Accent = RGB(255, 220, 190), Shine = true }

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
