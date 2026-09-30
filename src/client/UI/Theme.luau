--!nonstrict
-- One place for every colour and size the UI uses.

local Theme = {}

Theme.Background = Color3.fromRGB(14, 17, 24)
Theme.Panel = Color3.fromRGB(22, 26, 36)
Theme.PanelRaised = Color3.fromRGB(30, 35, 48)
Theme.Stroke = Color3.fromRGB(52, 60, 78)
Theme.Text = Color3.fromRGB(236, 240, 248)
Theme.TextDim = Color3.fromRGB(148, 158, 176)
Theme.Accent = Color3.fromRGB(86, 176, 255)
Theme.Good = Color3.fromRGB(98, 214, 134)
Theme.Warn = Color3.fromRGB(255, 186, 76)
Theme.Bad = Color3.fromRGB(255, 104, 112)
Theme.Coin = Color3.fromRGB(255, 202, 84)

Theme.Corner = UDim.new(0, 10)
Theme.CornerSmall = UDim.new(0, 6)

Theme.FontBold = Enum.Font.GothamBold
Theme.FontMedium = Enum.Font.GothamMedium
Theme.Font = Enum.Font.Gotham

Theme.NotifyColors = {
	info = Theme.Accent,
	good = Theme.Good,
	warn = Theme.Warn,
	bad = Theme.Bad,
}

return Theme
