--!nonstrict
-- One place for every colour, radius and easing the UI uses.

local Theme = {}

-- Surfaces -------------------------------------------------------------------
Theme.Background = Color3.fromRGB(10, 12, 18)
Theme.Panel = Color3.fromRGB(19, 23, 32)
Theme.PanelRaised = Color3.fromRGB(28, 33, 45)
Theme.Row = Color3.fromRGB(24, 29, 40)

-- The two ends of a glass surface's vertical gradient. Light at the top edge,
-- falling away below, which is what makes a flat frame read as a lit surface.
Theme.GlassTop = Color3.fromRGB(42, 50, 68)
Theme.GlassBottom = Color3.fromRGB(12, 15, 22)

-- Stroke gradient, same idea: a bright top lip and a dark bottom.
Theme.StrokeTop = Color3.fromRGB(104, 118, 148)
Theme.StrokeBottom = Color3.fromRGB(32, 38, 52)

-- Ink ------------------------------------------------------------------------
Theme.Text = Color3.fromRGB(238, 242, 250)
Theme.TextDim = Color3.fromRGB(140, 151, 172)
Theme.TextFaint = Color3.fromRGB(94, 103, 122)

-- Accents --------------------------------------------------------------------
Theme.Accent = Color3.fromRGB(86, 168, 255)
Theme.Good = Color3.fromRGB(88, 216, 140)
Theme.Warn = Color3.fromRGB(255, 186, 76)
Theme.Bad = Color3.fromRGB(255, 96, 108)
Theme.Coin = Color3.fromRGB(255, 202, 84)

-- Geometry -------------------------------------------------------------------
Theme.Corner = UDim.new(0, 14)
Theme.CornerSmall = UDim.new(0, 8)
Theme.CornerPill = UDim.new(1, 0)

-- Type -----------------------------------------------------------------------
Theme.FontBlack = Enum.Font.GothamBlack
Theme.FontBold = Enum.Font.GothamBold
Theme.FontMedium = Enum.Font.GothamMedium
Theme.Font = Enum.Font.Gotham

-- Motion ---------------------------------------------------------------------
Theme.Quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Theme.Smooth = TweenInfo.new(0.24, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
Theme.Pop = TweenInfo.new(0.34, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

Theme.NotifyColors = {
	info = Theme.Accent,
	good = Theme.Good,
	warn = Theme.Warn,
	bad = Theme.Bad,
}

return Theme
