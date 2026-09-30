--!nonstrict
-- Fishing zones. `origin` is where MapBuilder drops the island; everything
-- visual about the zone (water colour, fog, dock size) is derived from here so
-- the map and the data can never disagree.

local Zones = {}

Zones.Order = { "pond", "reef", "frost", "volcano", "abyss", "rift" }

Zones.Data = {
	pond = {
		name = "Starter Pond",
		blurb = "Still water, friendly fish, no surprises.",
		unlockCoins = 0,
		luckBonus = 1,
		-- Seconds between the cast landing and the fish biting.
		biteRange = { min = 1.4, max = 4.2 },
		origin = Vector3.new(0, 0, 0),
		waterColor = Color3.fromRGB(58, 132, 168),
		accentColor = Color3.fromRGB(126, 200, 120),
		fogColor = Color3.fromRGB(176, 202, 216),
		radius = 90,
	},
	reef = {
		name = "Coral Reef",
		blurb = "Warm shallows. The colours here are worth money.",
		unlockCoins = 2500,
		luckBonus = 1.15,
		biteRange = { min = 1.6, max = 4.8 },
		origin = Vector3.new(520, 0, -140),
		waterColor = Color3.fromRGB(40, 186, 190),
		accentColor = Color3.fromRGB(255, 142, 156),
		fogColor = Color3.fromRGB(168, 226, 226),
		radius = 100,
	},
	frost = {
		name = "Frostbite Lake",
		blurb = "Cut a hole, drop a line, hope something is still alive.",
		unlockCoins = 25000,
		luckBonus = 1.35,
		biteRange = { min = 2.2, max = 6 },
		origin = Vector3.new(-480, 0, -420),
		waterColor = Color3.fromRGB(122, 190, 214),
		accentColor = Color3.fromRGB(226, 244, 255),
		fogColor = Color3.fromRGB(214, 232, 242),
		radius = 105,
	},
	volcano = {
		name = "Volcanic Depths",
		blurb = "The water boils. Whatever lives in it is angry.",
		unlockCoins = 150000,
		luckBonus = 1.7,
		biteRange = { min = 2.4, max = 6.5 },
		origin = Vector3.new(300, 0, 620),
		waterColor = Color3.fromRGB(198, 78, 40),
		accentColor = Color3.fromRGB(255, 122, 40),
		fogColor = Color3.fromRGB(96, 52, 44),
		radius = 100,
	},
	abyss = {
		name = "The Abyss",
		blurb = "No light reaches the bottom. Something down there has teeth.",
		unlockCoins = 1500000,
		luckBonus = 2.4,
		biteRange = { min = 3, max = 8 },
		origin = Vector3.new(-700, 0, 480),
		waterColor = Color3.fromRGB(18, 26, 54),
		accentColor = Color3.fromRGB(76, 108, 220),
		fogColor = Color3.fromRGB(12, 16, 32),
		radius = 115,
	},
	rift = {
		name = "Celestial Rift",
		blurb = "Not water. Not really. It still takes bait.",
		unlockCoins = 6000000,
		luckBonus = 3.5,
		biteRange = { min = 3.5, max = 9 },
		origin = Vector3.new(120, 0, -860),
		waterColor = Color3.fromRGB(96, 68, 200),
		accentColor = Color3.fromRGB(180, 160, 255),
		fogColor = Color3.fromRGB(48, 32, 96),
		radius = 120,
	},
}

function Zones.Get(id: string)
	local zone = Zones.Data[id]
	assert(zone, string.format("unknown zone %q", tostring(id)))
	return zone
end

function Zones.IsUnlocked(id: string, lifetimeCoins: number): boolean
	return lifetimeCoins >= Zones.Get(id).unlockCoins
end

function Zones.Default(): string
	return "pond"
end

return Zones
