--!nonstrict
-- Rods drive both the roll (luck) and the reel minigame (everything else).
--   barSize   : fraction of the track your catch bar covers
--   fillRate  : progress per second while the fish is inside your bar
--   drainRate : progress per second while it is not
--   fishSpeed : multiplier on how hard the fish jerks around
--   biteSpeed : multiplier on the zone's bite delay (lower is faster)

local Rods = {}

Rods.Order = { "wooden", "fiberglass", "carbon", "enchanted", "abyssal", "celestial", "eventide" }

Rods.Data = {
	wooden = {
		name = "Wooden Rod",
		cost = 0,
		luck = 1,
		barSize = 0.22,
		fillRate = 0.55,
		drainRate = 0.38,
		fishSpeed = 1,
		biteSpeed = 1,
		color = Color3.fromRGB(146, 110, 68),
	},
	fiberglass = {
		name = "Fiberglass Rod",
		cost = 750,
		luck = 1.15,
		barSize = 0.24,
		fillRate = 0.6,
		drainRate = 0.36,
		fishSpeed = 0.95,
		biteSpeed = 0.92,
		color = Color3.fromRGB(120, 168, 196),
	},
	carbon = {
		name = "Carbon Rod",
		cost = 12000,
		luck = 1.4,
		barSize = 0.26,
		fillRate = 0.65,
		drainRate = 0.34,
		fishSpeed = 0.9,
		biteSpeed = 0.85,
		color = Color3.fromRGB(70, 74, 82),
	},
	enchanted = {
		name = "Enchanted Rod",
		cost = 180000,
		luck = 1.9,
		barSize = 0.28,
		fillRate = 0.72,
		drainRate = 0.3,
		fishSpeed = 0.85,
		biteSpeed = 0.78,
		color = Color3.fromRGB(150, 116, 224),
	},
	abyssal = {
		name = "Abyssal Rod",
		cost = 2500000,
		luck = 2.8,
		barSize = 0.3,
		fillRate = 0.8,
		drainRate = 0.27,
		fishSpeed = 0.8,
		biteSpeed = 0.7,
		color = Color3.fromRGB(48, 62, 118),
	},
	celestial = {
		name = "Celestial Rod",
		cost = 30000000,
		luck = 4.2,
		barSize = 0.33,
		fillRate = 0.9,
		drainRate = 0.24,
		fishSpeed = 0.75,
		biteSpeed = 0.6,
		color = Color3.fromRGB(186, 168, 255),
	},
	eventide = {
		name = "Eventide Rod",
		cost = 150000000,
		luck = 7,
		barSize = 0.36,
		fillRate = 1,
		drainRate = 0.2,
		fishSpeed = 0.7,
		biteSpeed = 0.5,
		color = Color3.fromRGB(255, 244, 196),
	},
}

function Rods.Get(id: string)
	local rod = Rods.Data[id]
	assert(rod, string.format("unknown rod %q", tostring(id)))
	return rod
end

function Rods.Default(): string
	return "wooden"
end

function Rods.IndexOf(id: string): number
	for index, rodId in Rods.Order do
		if rodId == id then
			return index
		end
	end
	return 0
end

return Rods
