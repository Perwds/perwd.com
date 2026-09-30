--[[
	The look: chunky cartoon panels, thick black outlines, bright header bars,
	heavy white text with a black stroke. Everything in the UI pulls its
	colours and metrics from here so a restyle is one file.
]]

local Theme = {}

Theme.Color = {
	-- Panel chrome
	panel = Color3.fromRGB(46, 52, 68),
	panelDeep = Color3.fromRGB(33, 37, 50),
	panelInset = Color3.fromRGB(26, 29, 40),
	stroke = Color3.fromRGB(11, 13, 19),

	-- Header bars
	headerBlue = Color3.fromRGB(78, 202, 247),
	headerGreen = Color3.fromRGB(96, 216, 88),
	headerGold = Color3.fromRGB(240, 186, 48),
	headerPurple = Color3.fromRGB(168, 96, 240),

	-- Accents
	red = Color3.fromRGB(214, 48, 48),
	redDeep = Color3.fromRGB(150, 26, 26),
	green = Color3.fromRGB(74, 206, 86),
	greenDeep = Color3.fromRGB(38, 140, 52),
	gold = Color3.fromRGB(248, 202, 52),
	blue = Color3.fromRGB(64, 148, 246),
	grey = Color3.fromRGB(126, 132, 152),

	text = Color3.fromRGB(255, 255, 255),
	textDim = Color3.fromRGB(186, 192, 210),
	textStroke = Color3.fromRGB(0, 0, 0),
	money = Color3.fromRGB(124, 232, 132),
}

Theme.Font = {
	title = Enum.Font.FredokaOne,
	body = Enum.Font.GothamBold,
	number = Enum.Font.FredokaOne,
}

Theme.Metric = {
	corner = 10,
	cornerSmall = 6,
	stroke = 3,
	strokeThin = 2,
	padding = 10,
	headerHeight = 54,
	rowHeight = 44,
}

--- Standard drop shadow offsets for the "sticker" look.
Theme.Shadow = {
	offset = UDim2.fromOffset(0, 4),
	transparency = 0.55,
}

Theme.Z = {
	hud = 1,
	panel = 10,
	overlay = 50,
	toast = 90,
	reveal = 100,
}

return Theme
