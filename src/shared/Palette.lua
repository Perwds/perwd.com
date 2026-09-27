--!strict
--[[
	Palette -- the industrial colour tokens, shared across the client/server
	boundary.

	The UI theme and the physical lobby have to agree: a chassis-grey menu
	floating over a lime-green baseplate reads as two different products. This
	module is the single definition, re-exported by the client's Theme and
	consumed directly by WorldBuilder.

	Hex values are from the design system, converted to Color3.
]]

local C = Color3.fromRGB

return {
	chassis = C(224, 229, 236), -- #e0e5ec  Level 0, the base material
	panel = C(240, 242, 245), -- #f0f2f5  raised surface
	recess = C(209, 217, 230), -- #d1d9e6  sunken areas

	text = C(45, 52, 54), -- #2d3436
	textMuted = C(74, 85, 104), -- #4a5568

	accent = C(255, 71, 87), -- #ff4757  safety orange, used sparingly
	accentText = C(255, 255, 255),
	accentDeep = C(166, 50, 60),
	accentLift = C(255, 100, 110),

	shadow = C(186, 190, 204), -- #babecc
	highlight = C(255, 255, 255),
	shadowDeep = C(163, 177, 198), -- #a3b1c6

	dark = C(45, 52, 54), -- #2d3436  technical panels
	darkSlate = C(44, 62, 80), -- #2c3e50
	darkText = C(224, 229, 236),
	darkTextMuted = C(168, 178, 209), -- #a8b2d1

	ledGreen = C(34, 197, 94),
	ledAmber = C(250, 204, 21),
	ledRed = C(255, 71, 87),
}
