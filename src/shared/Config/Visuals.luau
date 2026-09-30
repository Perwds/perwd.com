--!nonstrict
-- Per-zone visual identity: terrain, water, atmosphere, post-processing and
-- ambient particles. The client owns all of it (lighting and Terrain property
-- writes are local), so two players in different zones each see their own.
--
-- Materials are stored as strings and resolved through Visuals.Material so this
-- module loads outside Roblox and stays testable.

local Visuals = {}

Visuals.Data = {
	pond = {
		ground = "Grass",
		shore = "Sand",
		underwater = "Mud",
		prop = "Wood",
		propColor = Color3.fromRGB(96, 128, 72),

		water = {
			color = Color3.fromRGB(28, 104, 130),
			transparency = 0.62,
			reflectance = 0.28,
			waveSize = 0.11,
			waveSpeed = 7,
		},

		lighting = {
			clockTime = 14.4,
			brightness = 2.4,
			exposure = 0,
			ambient = Color3.fromRGB(58, 64, 74),
			outdoorAmbient = Color3.fromRGB(122, 134, 152),
			shadowSoftness = 0.22,
		},

		atmosphere = {
			density = 0.32,
			offset = 0.1,
			color = Color3.fromRGB(202, 216, 226),
			decay = Color3.fromRGB(122, 140, 158),
			glare = 0.2,
			haze = 1.1,
		},

		clouds = { cover = 0.52, density = 0.55, color = Color3.fromRGB(240, 246, 252) },

		bloom = { intensity = 0.55, size = 22, threshold = 1.05 },
		sunRays = { intensity = 0.1, spread = 0.9 },
		correction = {
			brightness = 0.015,
			contrast = 0.07,
			saturation = 0.1,
			tint = Color3.fromRGB(255, 252, 244),
		},
		dof = { far = 0.08, focus = 90, radius = 60, near = 0 },

		ambient = { kind = "pollen", color = Color3.fromRGB(255, 244, 200), rate = 14 },
	},

	reef = {
		ground = "Sand",
		shore = "Sand",
		underwater = "Sand",
		prop = "Sandstone",
		propColor = Color3.fromRGB(255, 152, 162),

		water = {
			color = Color3.fromRGB(16, 180, 186),
			transparency = 0.74,
			reflectance = 0.34,
			waveSize = 0.14,
			waveSpeed = 9,
		},

		lighting = {
			clockTime = 13.2,
			brightness = 3,
			exposure = 0.08,
			ambient = Color3.fromRGB(64, 76, 82),
			outdoorAmbient = Color3.fromRGB(140, 168, 176),
			shadowSoftness = 0.18,
		},

		atmosphere = {
			density = 0.28,
			offset = 0.16,
			color = Color3.fromRGB(216, 240, 240),
			decay = Color3.fromRGB(128, 180, 186),
			glare = 0.45,
			haze = 1.3,
		},

		clouds = { cover = 0.36, density = 0.4, color = Color3.fromRGB(255, 255, 255) },

		bloom = { intensity = 0.85, size = 26, threshold = 0.95 },
		sunRays = { intensity = 0.2, spread = 1 },
		correction = {
			brightness = 0.03,
			contrast = 0.1,
			saturation = 0.26,
			tint = Color3.fromRGB(246, 255, 255),
		},
		dof = { far = 0.1, focus = 110, radius = 70, near = 0 },

		ambient = { kind = "pollen", color = Color3.fromRGB(190, 255, 250), rate = 10 },
	},

	frost = {
		ground = "Snow",
		shore = "Glacier",
		underwater = "Slate",
		prop = "Ice",
		propColor = Color3.fromRGB(222, 240, 252),

		water = {
			color = Color3.fromRGB(96, 150, 176),
			transparency = 0.5,
			reflectance = 0.42,
			waveSize = 0.05,
			waveSpeed = 4,
		},

		lighting = {
			clockTime = 9.4,
			brightness = 2,
			exposure = 0.05,
			ambient = Color3.fromRGB(74, 82, 92),
			outdoorAmbient = Color3.fromRGB(150, 166, 182),
			shadowSoftness = 0.5,
		},

		atmosphere = {
			density = 0.44,
			offset = 0.05,
			color = Color3.fromRGB(226, 236, 246),
			decay = Color3.fromRGB(150, 168, 190),
			glare = 0.1,
			haze = 2.4,
		},

		clouds = { cover = 0.86, density = 0.72, color = Color3.fromRGB(228, 236, 246) },

		bloom = { intensity = 0.7, size = 30, threshold = 1 },
		sunRays = { intensity = 0.06, spread = 0.7 },
		correction = {
			brightness = 0.02,
			contrast = 0.04,
			saturation = -0.22,
			tint = Color3.fromRGB(236, 246, 255),
		},
		dof = { far = 0.16, focus = 70, radius = 45, near = 0 },

		ambient = { kind = "snow", color = Color3.fromRGB(246, 252, 255), rate = 60 },
	},

	volcano = {
		ground = "Basalt",
		shore = "CrackedLava",
		underwater = "Basalt",
		prop = "Rock",
		propColor = Color3.fromRGB(58, 48, 48),

		water = {
			color = Color3.fromRGB(150, 44, 18),
			transparency = 0.3,
			reflectance = 0.2,
			waveSize = 0.09,
			waveSpeed = 5,
		},

		lighting = {
			clockTime = 19.4,
			brightness = 1.5,
			exposure = -0.05,
			ambient = Color3.fromRGB(58, 34, 28),
			outdoorAmbient = Color3.fromRGB(84, 48, 38),
			shadowSoftness = 0.35,
		},

		atmosphere = {
			density = 0.52,
			offset = 0.02,
			color = Color3.fromRGB(150, 96, 74),
			decay = Color3.fromRGB(96, 44, 30),
			glare = 0.6,
			haze = 3.2,
		},

		clouds = { cover = 0.94, density = 0.9, color = Color3.fromRGB(90, 62, 58) },

		bloom = { intensity = 1.5, size = 34, threshold = 0.82 },
		sunRays = { intensity = 0.3, spread = 1 },
		correction = {
			brightness = -0.01,
			contrast = 0.2,
			saturation = 0.2,
			tint = Color3.fromRGB(255, 226, 206),
		},
		dof = { far = 0.24, focus = 55, radius = 35, near = 0 },

		ambient = { kind = "embers", color = Color3.fromRGB(255, 142, 52), rate = 34 },
	},

	abyss = {
		ground = "Rock",
		shore = "Slate",
		underwater = "Rock",
		prop = "Marble",
		propColor = Color3.fromRGB(44, 56, 96),

		water = {
			color = Color3.fromRGB(6, 14, 40),
			transparency = 0.18,
			reflectance = 0.12,
			waveSize = 0.04,
			waveSpeed = 3,
		},

		lighting = {
			clockTime = 0.6,
			brightness = 0.7,
			exposure = 0.22,
			ambient = Color3.fromRGB(16, 22, 44),
			outdoorAmbient = Color3.fromRGB(26, 34, 62),
			shadowSoftness = 0.85,
		},

		atmosphere = {
			density = 0.62,
			offset = 0,
			color = Color3.fromRGB(38, 52, 96),
			decay = Color3.fromRGB(10, 16, 36),
			glare = 0.05,
			haze = 5,
		},

		clouds = { cover = 1, density = 0.95, color = Color3.fromRGB(20, 26, 48) },

		bloom = { intensity = 1.9, size = 40, threshold = 0.6 },
		sunRays = { intensity = 0, spread = 0.4 },
		correction = {
			brightness = 0.04,
			contrast = 0.26,
			saturation = -0.1,
			tint = Color3.fromRGB(196, 214, 255),
		},
		dof = { far = 0.5, focus = 34, radius = 20, near = 0.02 },

		ambient = { kind = "motes", color = Color3.fromRGB(98, 150, 255), rate = 26 },
	},

	rift = {
		ground = "Marble",
		shore = "Glacier",
		underwater = "Marble",
		prop = "Neon",
		propColor = Color3.fromRGB(176, 150, 255),

		water = {
			color = Color3.fromRGB(78, 46, 180),
			transparency = 0.46,
			reflectance = 0.6,
			waveSize = 0.08,
			waveSpeed = 6,
		},

		lighting = {
			clockTime = 2.4,
			brightness = 1.1,
			exposure = 0.2,
			ambient = Color3.fromRGB(38, 28, 66),
			outdoorAmbient = Color3.fromRGB(62, 48, 104),
			shadowSoftness = 0.6,
		},

		atmosphere = {
			density = 0.48,
			offset = 0.24,
			color = Color3.fromRGB(128, 104, 220),
			decay = Color3.fromRGB(52, 34, 104),
			glare = 1.2,
			haze = 3.6,
		},

		clouds = { cover = 0.7, density = 0.6, color = Color3.fromRGB(150, 126, 226) },

		bloom = { intensity = 2.2, size = 44, threshold = 0.55 },
		sunRays = { intensity = 0.36, spread = 1 },
		correction = {
			brightness = 0.05,
			contrast = 0.22,
			saturation = 0.3,
			tint = Color3.fromRGB(226, 214, 255),
		},
		dof = { far = 0.3, focus = 80, radius = 50, near = 0 },

		ambient = { kind = "sparks", color = Color3.fromRGB(198, 172, 255), rate = 40 },
	},
}

-- How each ambient particle kind behaves. Zone profiles reference these by
-- name; tests/specs.luau asserts every name resolves.
Visuals.AmbientStyles = {
	pollen = {
		lifetime = NumberRange.new(5, 9),
		speed = NumberRange.new(0.4, 1.6),
		size = 0.22,
		acceleration = Vector3.new(0.6, 0.35, 0),
		lightEmission = 0.55,
		spin = NumberRange.new(-20, 20),
		transparency = 0.45,
	},
	snow = {
		lifetime = NumberRange.new(6, 10),
		speed = NumberRange.new(0.5, 1.4),
		size = 0.32,
		acceleration = Vector3.new(2.2, -7.5, 0.8),
		lightEmission = 0.35,
		spin = NumberRange.new(-45, 45),
		transparency = 0.2,
	},
	embers = {
		lifetime = NumberRange.new(3.2, 6),
		speed = NumberRange.new(1.4, 3.6),
		size = 0.26,
		acceleration = Vector3.new(0.8, 5.5, 0),
		lightEmission = 1,
		spin = NumberRange.new(-90, 90),
		transparency = 0.1,
	},
	motes = {
		lifetime = NumberRange.new(7, 12),
		speed = NumberRange.new(0.2, 0.9),
		size = 0.3,
		acceleration = Vector3.new(0, 0.4, 0),
		lightEmission = 0.9,
		spin = NumberRange.new(-10, 10),
		transparency = 0.25,
	},
	sparks = {
		lifetime = NumberRange.new(2.4, 5),
		speed = NumberRange.new(2, 5),
		size = 0.22,
		acceleration = Vector3.new(0, 1.4, 0),
		lightEmission = 1,
		spin = NumberRange.new(-180, 180),
		transparency = 0.05,
	},
}

function Visuals.Get(zoneId: string)
	local profile = Visuals.Data[zoneId]
	assert(profile, string.format("no visual profile for zone %q", tostring(zoneId)))
	return profile
end

-- Resolves a stored material name, with a readable failure if Roblox ever
-- renames one out from under us.
function Visuals.Material(name: string): Enum.Material
	local material = (Enum.Material :: any)[name]
	assert(material, string.format("unknown Enum.Material %q", tostring(name)))
	return material
end

return Visuals
