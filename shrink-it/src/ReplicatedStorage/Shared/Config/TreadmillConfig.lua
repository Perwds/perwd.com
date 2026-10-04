--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > TreadmillConfig (ModuleScript)

	Treadmill looks (models in ReplicatedStorage > TreadmillModels).
	• Tiers: the treadmill on your plot gets fancier as your Treadmill upgrade goes up
	  (levels split evenly over the 5 tiers).
	• Skins: themed cosmetic treadmills, bought with Gems in the Custom menu (Treadmills tab).
	  Equip one to replace your tier look (training works exactly the same).
]]

local TreadmillConfig = {}

TreadmillConfig.Tiers = { "Tier_01_Basic", "Tier_02_Improved", "Tier_03_Advanced", "Tier_04_Pro", "Tier_05_Ultimate" }
TreadmillConfig.TierNames = { "Basic", "Improved", "Advanced", "Pro", "Ultimate" }

-- treadmills are scaled to this length so they match the plot's training belt
TreadmillConfig.Length = 13

TreadmillConfig.SkinOrder = {
	"spring_blossom", "valentine", "easter-bloom", "summer-beach", "ocean-abyss", "winter_frost", "halloween", "christmas",
	"toxic", "storm-surge", "inferno", "new-year", "cyberpunk", "galaxy", "royal-gold",
}
TreadmillConfig.Skins = {
	["spring_blossom"] = { Name = "Spring Blossom", Model = "Cosmetic_05_Spring_Blossom", Cost = 250 },
	["valentine"] = { Name = "Valentine", Model = "Cosmetic_04_Valentine", Cost = 250 },
	["easter-bloom"] = { Name = "Easter Bloom", Model = "Cosmetic_06_Easter-Bloom", Cost = 300 },
	["summer-beach"] = { Name = "Summer Beach", Model = "Cosmetic_07_Summer-Beach", Cost = 300 },
	["ocean-abyss"] = { Name = "Ocean Abyss", Model = "Cosmetic_08_Ocean-Abyss", Cost = 400 },
	["winter_frost"] = { Name = "Winter Frost", Model = "Cosmetic_03_Winter_Frost", Cost = 400 },
	["halloween"] = { Name = "Halloween", Model = "Cosmetic_01_Halloween", Cost = 500 },
	["christmas"] = { Name = "Christmas", Model = "Cosmetic_02_Christmas", Cost = 500 },
	["toxic"] = { Name = "Toxic", Model = "Cosmetic_11_Toxic", Cost = 650 },
	["storm-surge"] = { Name = "Storm Surge", Model = "Cosmetic_10_Storm-Surge", Cost = 650 },
	["inferno"] = { Name = "Inferno", Model = "Cosmetic_09_Inferno", Cost = 800 },
	["new-year"] = { Name = "New Year", Model = "Cosmetic_15_New-Year", Cost = 800 },
	["cyberpunk"] = { Name = "Cyberpunk", Model = "Cosmetic_13_Cyberpunk", Cost = 1_000 },
	["galaxy"] = { Name = "Galaxy", Model = "Cosmetic_12_Galaxy", Cost = 1_200 },
	["royal-gold"] = { Name = "Royal Gold", Model = "Cosmetic_14_Royal-Gold", Cost = 1_500 },
}

return TreadmillConfig
