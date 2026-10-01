--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > EventConfig (ModuleScript)

	Rotating server events. A new event starts every Interval seconds, aligned to the clock,
	so every server runs the same event at the same time.
]]

local EventConfig = {}

EventConfig.Interval = 30 * 60
EventConfig.Rotation = { "GoldenHour", "GiantRush", "MeteorShower" }

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
