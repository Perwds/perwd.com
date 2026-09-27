--!strict
--[[
	Theme -- the single source of design tokens.

	INDUSTRIAL SKEUOMORPHISM
	Matte ABS chassis, machined recesses, safety-orange controls, and one
	immutable light source at the top-left (45 degrees). Every bevel, rim and
	cast shadow in the UI derives from the constants below -- nothing should
	hard-code a colour, radius or easing curve anywhere else.

	Light source
	------------
	LIGHT_ANGLE is the rotation handed to every rim gradient: white at the
	top-left, shadow at the bottom-right. PRESS_ANGLE is the same value plus
	180, which inverts the light and is what makes a pressed control read as
	pushed into the chassis rather than sitting on it.
]]

local Palette = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Palette)

local Theme = {}

-- Palette ----------------------------------------------------------------
-- Re-exported from Shared.Palette so the lobby geometry and the interface are
-- driven by the same tokens. Nothing below redefines a colour.

Theme.Color = Palette

-- Typography -------------------------------------------------------------
-- Inter is not a Roblox font; Gotham is the closest humanist sans available
-- built in. RobotoMono covers the technical/monospace role exactly.

Theme.Font = {
	display = Enum.Font.GothamBlack, -- hero + section headings (800)
	bold = Enum.Font.GothamBold, -- labels, buttons (700)
	body = Enum.Font.GothamMedium, -- body copy (500)
	-- Every number, every stamped label, every data readout.
	mono = Enum.Font.RobotoMono,
}

--- Tracking is not a Roblox property; wide-tracked stamped labels are faked
--- by spacing the characters, which is what the design system's uppercase
--- monospace metadata is really communicating.
function Theme.stamp(text: string): string
	return (text:upper():gsub(".", "%0 "):gsub(" $", ""))
end

-- Radius -----------------------------------------------------------------
-- Injection-moulded plastic, not machined metal: soft and organic.

Theme.Radius = {
	sm = UDim.new(0, 4), -- badges, small keys
	md = UDim.new(0, 8), -- inputs, small cards
	lg = UDim.new(0, 16), -- panels, cards
	xl = UDim.new(0, 24), -- device bezels, major sections
	xxl = UDim.new(0, 30), -- oversized containers
	full = UDim.new(1, 0), -- LEDs, icon housings
}

-- Elevation --------------------------------------------------------------
-- Roblox has no box-shadow, so each level is expressed as a rim thickness
-- plus a cast-shadow offset, applied by the Bevel module.

Theme.Elevation = {
	recessed = { rim = 2, cast = 0, inverted = true }, -- Level -1
	chassis = { rim = 0, cast = 0 }, -- Level  0
	panel = { rim = 2, cast = 8 }, -- Level +1
	floating = { rim = 3, cast = 12 }, -- Level +2
}

Theme.LIGHT_ANGLE = 45 -- top-left light source
Theme.PRESS_ANGLE = 225 -- inverted: pressed into the chassis

-- Spacing ----------------------------------------------------------------

Theme.Space = {
	tight = 6,
	gap = 12, -- gap-3
	panel = 16,
	section = 24, -- gap-6
	loose = 32, -- gap-8
}

--- Minimum interactive height. The design system mandates 48px touch targets.
Theme.TOUCH = 48

-- Motion -----------------------------------------------------------------
-- cubic-bezier(0.175, 0.885, 0.32, 1.275) is a spring with slight overshoot;
-- EasingStyle.Back out is Roblox's equivalent.

Theme.Motion = {
	mechanical = Enum.EasingStyle.Back, -- spring-loaded switch
	smooth = Enum.EasingStyle.Quad,
	press = 0.15, -- immediate tactile feedback
	hover = 0.2,
	settle = 0.3,
	slow = 0.5,
}

-- Helpers ----------------------------------------------------------------

function Theme.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

--- Readable ink for a given surface, so accent chips and dark panels both
--- stay legible without every call site deciding for itself.
function Theme.inkOn(surface: Color3): Color3
	local luminance = 0.299 * surface.R + 0.587 * surface.G + 0.114 * surface.B
	return luminance > 0.55 and Theme.Color.text or Theme.Color.highlight
end

return Theme
