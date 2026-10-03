--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > EventConfig (ModuleScript)

	Rotating server events. A new event starts every Interval seconds, aligned to the clock,
	so every server runs the same event at the same time.
]]

local EventConfig = {}

EventConfig.Interval = 15 * 60
EventConfig.Rotation = { "BoxRain", "GoldenHour", "MutationFrenzy", "MegaBox", "GiantRush", "SizeSurge", "MeteorShower" }

EventConfig.Events = {
	GoldenHour = {
		Name = "Golden Hour",
		Emoji = "🌟",
		Duration = 5 * 60,
		Description = "5x Golden chance on every spawn!",
		Color = Color3.fromRGB(255, 205, 40),
		VariantMults = { Golden = 5 },
	},
	GiantRush = {
		Name = "Giant Rush",
		Emoji = "🦖",
		Duration = 5 * 60,
		Description = "Huge & Colossal objects respawn 4x faster + bonus spawns!",
		Color = Color3.fromRGB(255, 110, 60),
		RespawnMultForTier = { [5] = 0.25, [6] = 0.25 },
		BonusSpawnTier = 5,
		BonusSpawnInterval = 20,
	},
	BoxRain = {
		Name = "Box Rain",
		Emoji = "📦",
		Duration = 2 * 60,
		Description = "Boxes are falling from the sky in every zone!",
		Color = Color3.fromRGB(110, 210, 255),
		RainEvery = 2.5, -- seconds between falling boxes
	},
	MutationFrenzy = {
		Name = "Mutation Frenzy",
		Emoji = "🧬",
		Duration = 4 * 60,
		Description = "3x mutation chance on every box you open!",
		Color = Color3.fromRGB(120, 255, 140),
		MutationMult = 3,
	},
	MegaBox = {
		Name = "Mega Box",
		Emoji = "🎁",
		Duration = 3 * 60,
		Description = "A giant MEGA BOX landed in a zone! Always mutated. Up to 4 players can grab it!",
		Color = Color3.fromRGB(255, 120, 230),
		MegaBox = true,
	},
	SizeSurge = {
		Name = "Size Surge",
		Emoji = "📏",
		Duration = 4 * 60,
		Description = "Every new box spawns bigger!",
		Color = Color3.fromRGB(255, 170, 60),
		SizeLuck = 6,
	},
	MeteorShower = {
		Name = "Meteor Shower",
		Emoji = "☄️",
		Duration = 2 * 60,
		Description = "Every new spawn is COSMIC!",
		Color = Color3.fromRGB(140, 80, 255),
		ForceVariant = "Cosmic",
	},
}

-- Random "Event Objects" (fancy variant, announced to the server)
EventConfig.EventObjects = {
	MinInterval = 3 * 60,
	MaxInterval = 7 * 60,
	Lifetime = 120,
}

return EventConfig
