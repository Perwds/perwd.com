--!strict
--[[ Theme -- one place for colours, fonts and spacing. ]]

local Theme = {}

local C = Color3.fromRGB

Theme.Color = {
	backdrop = C(0, 0, 0),
	panel = C(58, 58, 58),
	panelDark = C(42, 42, 42),
	header = C(72, 72, 72),
	card = C(70, 70, 70),
	locked = C(88, 88, 88),
	text = C(255, 255, 255),
	subtext = C(196, 196, 196),
	muted = C(150, 150, 150),
	good = C(96, 220, 128),
	warn = C(255, 178, 90),
	bad = C(240, 86, 86),
	coin = C(255, 205, 70),
	robux = C(120, 230, 150),
	accent = C(96, 186, 255),
}

Theme.Font = {
	title = Enum.Font.FredokaOne,
	heading = Enum.Font.FredokaOne,
	body = Enum.Font.GothamMedium,
	bold = Enum.Font.GothamBold,
}

Theme.Radius = {
	panel = UDim.new(0, 18),
	card = UDim.new(0, 14),
	pill = UDim.new(1, 0),
}

Theme.Padding = {
	panel = 16,
	card = 14,
	gap = 10,
}

--- Darkens or lightens a colour by `amount` (-1..1).
function Theme.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), amount)
	end
	return color:Lerp(Color3.new(0, 0, 0), -amount)
end

return Theme
