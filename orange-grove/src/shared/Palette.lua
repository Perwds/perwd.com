--!strict
-- Every colour in the game. Plate ink is checked for 4.5:1 contrast against its plate colour.

local rgb = Color3.fromRGB

export type ZoneColors = {
	floorA: Color3,
	floorB: Color3,
	plate: Color3,
	ink: Color3,
	bought: Color3,
	neon: Color3,
	trim: Color3,
}

local DARK_INK = rgb(22, 18, 16)
local LIGHT_INK = rgb(246, 244, 240)

local Palette = {
	zones = {
		orange = {
			floorA = rgb(226, 124, 38),
			floorB = rgb(214, 112, 30),
			plate = rgb(255, 152, 62),
			ink = DARK_INK,
			bought = rgb(255, 210, 130),
			neon = rgb(255, 136, 24),
			trim = rgb(255, 120, 20),
		},
		vitamin = {
			floorA = rgb(118, 178, 50),
			floorB = rgb(106, 164, 42),
			plate = rgb(162, 222, 82),
			ink = DARK_INK,
			bought = rgb(218, 255, 160),
			neon = rgb(140, 255, 60),
			trim = rgb(150, 240, 70),
		},
		zest = {
			floorA = rgb(228, 192, 46),
			floorB = rgb(214, 178, 34),
			plate = rgb(255, 228, 96),
			ink = DARK_INK,
			bought = rgb(255, 246, 178),
			neon = rgb(255, 222, 40),
			trim = rgb(255, 214, 30),
		},
		juice = {
			floorA = rgb(30, 146, 138),
			floorB = rgb(24, 132, 125),
			plate = rgb(66, 202, 190),
			ink = DARK_INK,
			bought = rgb(166, 246, 236),
			neon = rgb(40, 240, 220),
			trim = rgb(50, 230, 210),
		},
		golden = {
			floorA = rgb(72, 42, 120),
			floorB = rgb(63, 36, 107),
			plate = rgb(122, 82, 194),
			ink = LIGHT_INK,
			bought = rgb(255, 206, 84),
			neon = rgb(176, 112, 255),
			trim = rgb(255, 196, 60),
		},
		vip = {
			floorA = rgb(142, 36, 86),
			floorB = rgb(128, 30, 76),
			plate = rgb(188, 50, 118),
			ink = LIGHT_INK,
			bought = rgb(255, 160, 206),
			neon = rgb(255, 80, 170),
			trim = rgb(255, 90, 176),
		},
	} :: { [string]: ZoneColors },

	boughtInk = DARK_INK,
	locked = rgb(52, 52, 58),
	lockedInk = rgb(172, 172, 178),
	lockedPath = rgb(64, 64, 72),
	plateEdge = rgb(28, 26, 32),
	border = rgb(20, 18, 26),
	boardSide = rgb(14, 13, 18),
	screen = rgb(12, 12, 16),
	screenDim = rgb(110, 110, 120),
	gold = rgb(255, 200, 64),
	white = LIGHT_INK,
	dark = DARK_INK,
	leaf = rgb(58, 132, 62),
	leafDark = rgb(44, 108, 50),
	bark = rgb(92, 60, 40),
	orange = rgb(255, 140, 26),
	unripe = rgb(150, 190, 70),
	hud = rgb(16, 15, 20),
	hudEdge = rgb(48, 46, 58),
	deny = rgb(255, 96, 96),
}

Palette.currency = {
	oranges = Palette.zones.orange.neon,
	vitamin = Palette.zones.vitamin.neon,
	zest = Palette.zones.zest.neon,
	crates = Palette.zones.juice.neon,
	seeds = Palette.gold,
}

return Palette
