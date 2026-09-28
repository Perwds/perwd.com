--!strict
--[[
	Theme -- design tokens for the arcade skin.

	Chunky, saturated, outlined. The look comes from four moves, applied
	everywhere by the Skin module:

	  1. A thick near-black outline on every surface.
	  2. A darker "lip" along the bottom edge, which reads as thickness.
	  3. A white gloss band across the top.
	  4. Everything squashes when you press it.
]]

local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Palette)

local Theme = {}

Theme.Color = Palette

-- Typography -------------------------------------------------------------
-- FredokaOne is the chunky rounded face Roblox games live on. Gotham carries
-- the small print, and RobotoMono only appears where digits must line up.

Theme.Font = {
	display = Enum.Font.FredokaOne,
	heading = Enum.Font.GothamBlack,
	body = Enum.Font.GothamBold,
	small = Enum.Font.GothamMedium,
	mono = Enum.Font.RobotoMono,
}

Theme.Radius = {
	sm = UDim.new(0, 8),
	md = UDim.new(0, 14),
	lg = UDim.new(0, 20),
	xl = UDim.new(0, 28),
	full = UDim.new(1, 0),
}

--- Outline weight by element size.
Theme.Outline = {
	thin = 2,
	base = 3,
	chunky = 4,
}

--- How far the bottom lip sticks out, i.e. how thick the object looks.
Theme.Lip = {
	small = 4,
	base = 6,
	chunky = 9,
}

Theme.Space = {
	tight = 6,
	gap = 10,
	panel = 16,
	section = 22,
}

Theme.TOUCH = 48

Theme.Motion = {
	pop = Enum.EasingStyle.Back, -- overshoot, for anything appearing
	snap = Enum.EasingStyle.Quart,
	press = 0.08,
	hover = 0.12,
	settle = 0.25,
}

function Theme.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

--- Black or white ink, whichever survives on the given fill.
function Theme.inkOn(surface: Color3): Color3
	local luminance = 0.299 * surface.R + 0.587 * surface.G + 0.114 * surface.B
	return luminance > 0.62 and Palette.outline or Palette.ink
end

return Theme
