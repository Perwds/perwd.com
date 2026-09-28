--!strict
--[[
	Palette -- arcade colour tokens, shared by the UI and the world.

	Deep purple night, candy accents, near-black outlines. Every card, sign and
	pad reads from here so the menu and the map look like one game.
]]

local C = Color3.fromRGB

return {
	-- Surfaces
	night = C(27, 16, 51), -- deepest backdrop
	panel = C(42, 27, 77), -- menu body
	panelLite = C(58, 38, 104), -- raised rows
	slot = C(33, 21, 62), -- recessed wells

	-- The outline that makes everything read as a sticker.
	outline = C(20, 11, 38),

	ink = C(255, 255, 255),
	inkMuted = C(185, 167, 232),
	inkDim = C(132, 115, 178),

	-- Accents
	green = C(61, 220, 132), -- go / success
	gold = C(255, 197, 61), -- coins / rewards
	pink = C(255, 95, 162),
	cyan = C(52, 213, 240),
	orange = C(255, 138, 61),
	red = C(255, 77, 94), -- danger / locked
	purple = C(164, 107, 255),

	-- World
	grass = C(104, 208, 112),
	grassDeep = C(72, 168, 88),
	path = C(232, 214, 176),
	stone = C(86, 74, 120),
	water = C(64, 176, 224),
}
