--!strict
--[[
	Bevel -- the physics engine of the interface.

	Roblox has no box-shadow, so the neumorphic dual-shadow signature is built
	from what the engine does give us:

	  * A UIStroke with a child UIGradient, rotated to LIGHT_ANGLE, so the rim
	    runs white at the top-left and shadow at the bottom-right. This is the
	    bevel, and rotating it by 180 degrees inverts the light -- which is how
	    a pressed control reads as pushed INTO the chassis.
	  * Two inset hairlines (white along the top, shadow along the bottom) that
	    thicken the bevel without needing a blurred shadow.
	  * A real cast shadow, for elements that are absolutely positioned. A
	    Roblox child always draws in front of its parent's background, so a cast
	    shadow has to be a SIBLING -- which would fight a UIListLayout. Panels
	    inside a list therefore use rim + hairlines only, and carry their depth
	    through surface contrast instead.

	Everything else in here is the manufacturing detail the design system treats
	as mandatory rather than decorative: corner screws, vent slots, status LEDs,
	CRT scanlines.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Bevel = {}

-- Rim --------------------------------------------------------------------

--- Gradient rim: white top-left, shadow bottom-right. The core bevel.
function Bevel.rim(frame: GuiObject, thickness: number?, inverted: boolean?): UIStroke
	local existing = frame:FindFirstChild("Rim")
	if existing then
		return existing :: UIStroke
	end

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Rim"
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)

	local gradient = Instance.new("UIGradient")
	gradient.Name = "RimLight"
	gradient.Color = ColorSequence.new(Theme.Color.highlight, Theme.Color.shadowDeep)
	gradient.Rotation = inverted and Theme.PRESS_ANGLE or Theme.LIGHT_ANGLE
	gradient.Parent = stroke

	stroke.Parent = frame
	return stroke
end

--- Flips the light source. Used for pressed and recessed states.
function Bevel.invert(frame: GuiObject, pressed: boolean)
	local stroke = frame:FindFirstChild("Rim")
	if not stroke then
		return
	end
	local gradient = stroke:FindFirstChild("RimLight")
	if gradient then
		(gradient :: UIGradient).Rotation = pressed and Theme.PRESS_ANGLE or Theme.LIGHT_ANGLE
	end
end

--- Inset hairlines that deepen the bevel. Inset horizontally by the corner
--- radius so they never poke past a rounded corner.
function Bevel.hairlines(frame: GuiObject, radius: number, inverted: boolean?)
	local top = inverted and Theme.Color.shadowDeep or Theme.Color.highlight
	local bottom = inverted and Theme.Color.highlight or Theme.Color.shadow

	local topLine = Instance.new("Frame")
	topLine.Name = "HairTop"
	topLine.BackgroundColor3 = top
	topLine.BackgroundTransparency = 0.25
	topLine.BorderSizePixel = 0
	topLine.Position = UDim2.new(0, radius, 0, 1)
	topLine.Size = UDim2.new(1, -radius * 2, 0, 2)
	topLine.ZIndex = 0
	topLine.Parent = frame

	local bottomLine = Instance.new("Frame")
	bottomLine.Name = "HairBottom"
	bottomLine.BackgroundColor3 = bottom
	bottomLine.BackgroundTransparency = 0.35
	bottomLine.BorderSizePixel = 0
	bottomLine.AnchorPoint = Vector2.new(0, 1)
	bottomLine.Position = UDim2.new(0, radius, 1, -1)
	bottomLine.Size = UDim2.new(1, -radius * 2, 0, 2)
	bottomLine.ZIndex = 0
	bottomLine.Parent = frame
end

-- Elevation --------------------------------------------------------------

--- Level +1 / +2: a panel bolted onto the chassis.
function Bevel.panel(frame: GuiObject, level: string?, radius: UDim?)
	local elevation = Theme.Elevation[level or "panel"]
	local corner = radius or Theme.Radius.lg

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = corner
	uiCorner.Parent = frame

	Bevel.rim(frame, elevation.rim)
	Bevel.hairlines(frame, corner.Offset)

	return frame
end

--- Level -1: a well machined into the surface. Inputs, screens, grooves.
function Bevel.recess(frame: GuiObject, radius: UDim?)
	local corner = radius or Theme.Radius.md

	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = corner
	uiCorner.Parent = frame

	frame.BackgroundColor3 = Theme.Color.recess
	Bevel.rim(frame, 2, true)
	Bevel.hairlines(frame, corner.Offset, true)

	return frame
end

--- A genuine cast shadow. ONLY for absolutely positioned elements -- it adds
--- siblings, which a UIListLayout would try to lay out.
function Bevel.cast(frame: GuiObject, spread: number?)
	local parent = frame.Parent
	if not parent or not parent:IsA("GuiObject") and not parent:IsA("ScreenGui") then
		return
	end

	local offset = spread or 10
	local corner = frame:FindFirstChildOfClass("UICorner")
	local radius = corner and corner.CornerRadius or Theme.Radius.lg

	-- Dark half, bottom-right.
	local shadow = Instance.new("Frame")
	shadow.Name = "CastShadow"
	shadow.BackgroundColor3 = Theme.Color.shadowDeep
	shadow.BackgroundTransparency = 0.45
	shadow.BorderSizePixel = 0
	shadow.AnchorPoint = frame.AnchorPoint
	shadow.Position = frame.Position + UDim2.fromOffset(offset, offset)
	shadow.Size = frame.Size
	shadow.ZIndex = frame.ZIndex - 2
	shadow.Parent = parent

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = radius
	shadowCorner.Parent = shadow

	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.85),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	fade.Rotation = Theme.LIGHT_ANGLE
	fade.Parent = shadow

	-- Light half, top-left.
	local glow = Instance.new("Frame")
	glow.Name = "CastHighlight"
	glow.BackgroundColor3 = Theme.Color.highlight
	glow.BackgroundTransparency = 0.35
	glow.BorderSizePixel = 0
	glow.AnchorPoint = frame.AnchorPoint
	glow.Position = frame.Position - UDim2.fromOffset(offset, offset)
	glow.Size = frame.Size
	glow.ZIndex = frame.ZIndex - 3
	glow.Parent = parent

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = radius
	glowCorner.Parent = glow

	local glowFade = Instance.new("UIGradient")
	glowFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	glowFade.Rotation = Theme.LIGHT_ANGLE
	glowFade.Parent = glow

	return shadow, glow
end

-- Manufacturing details --------------------------------------------------

--- Four corner screws, 12px in from each edge, as the design system specifies.
---
--- `padding` is the panel's own UIPadding. A UIPadding shifts every child
--- inward, so without subtracting it the screws land on top of the content
--- instead of in the border margin where they belong.
function Bevel.screws(frame: GuiObject, inset: number?, padding: number?)
	local pad = (inset or 12) - (padding or 0)
	local spots = {
		{ UDim2.fromScale(0, 0), UDim2.fromOffset(pad, pad) },
		{ UDim2.fromScale(1, 0), UDim2.fromOffset(-pad, pad) },
		{ UDim2.fromScale(0, 1), UDim2.fromOffset(pad, -pad) },
		{ UDim2.fromScale(1, 1), UDim2.fromOffset(-pad, -pad) },
	}

	for index, spot in ipairs(spots) do
		local screw = Instance.new("Frame")
		screw.Name = "Screw" .. index
		screw.AnchorPoint = Vector2.new(0.5, 0.5)
		screw.Position = spot[1] + spot[2]
		screw.Size = UDim2.fromOffset(6, 6)
		screw.BackgroundColor3 = Theme.Color.recess
		screw.BorderSizePixel = 0
		screw.ZIndex = 4
		screw.Parent = frame

		local corner = Instance.new("UICorner")
		corner.CornerRadius = Theme.Radius.full
		corner.Parent = screw

		-- Radial screw indentation, faked with a 45-degree gradient.
		local depth = Instance.new("UIGradient")
		depth.Color = ColorSequence.new(Theme.Color.shadowDeep, Theme.Color.highlight)
		depth.Rotation = Theme.LIGHT_ANGLE
		depth.Parent = screw

		local ring = Instance.new("UIStroke")
		ring.Thickness = 1
		ring.Color = Theme.Color.shadowDeep
		ring.Transparency = 0.4
		ring.Parent = screw
	end
end

--- Three recessed ventilation slots. Top-right by convention.
function Bevel.vents(frame: GuiObject, count: number?, position: UDim2?)
	local holder = Instance.new("Frame")
	holder.Name = "Vents"
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = position or UDim2.new(1, -22, 0, 14)
	holder.Size = UDim2.fromOffset(20, 24)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 4
	holder.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = holder

	for index = 1, count or 3 do
		local slot = Instance.new("Frame")
		slot.Name = "Slot" .. index
		slot.Size = UDim2.fromOffset(2, 24)
		slot.BackgroundColor3 = Theme.Color.shadowDeep
		slot.BackgroundTransparency = 0.25
		slot.BorderSizePixel = 0
		slot.Parent = holder

		local corner = Instance.new("UICorner")
		corner.CornerRadius = Theme.Radius.full
		corner.Parent = slot
	end

	return holder
end

--- Status LED with a bloom ring and an optional stamped monospace label.
function Bevel.led(parent: GuiObject, color: Color3, label: string?, position: UDim2?)
	local holder = Instance.new("Frame")
	holder.Name = "Led"
	holder.Position = position or UDim2.fromOffset(0, 0)
	holder.Size = UDim2.fromOffset(label and 150 or 14, 14)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 5
	holder.Parent = parent

	-- Bloom: a larger translucent disc behind the diode.
	local bloom = Instance.new("Frame")
	bloom.Name = "Bloom"
	bloom.AnchorPoint = Vector2.new(0.5, 0.5)
	bloom.Position = UDim2.fromOffset(7, 7)
	bloom.Size = UDim2.fromOffset(20, 20)
	bloom.BackgroundColor3 = color
	bloom.BackgroundTransparency = 0.72
	bloom.BorderSizePixel = 0
	bloom.Parent = holder

	local bloomCorner = Instance.new("UICorner")
	bloomCorner.CornerRadius = Theme.Radius.full
	bloomCorner.Parent = bloom

	local diode = Instance.new("Frame")
	diode.Name = "Diode"
	diode.Size = UDim2.fromOffset(10, 10)
	diode.Position = UDim2.fromOffset(2, 2)
	diode.BackgroundColor3 = color
	diode.BorderSizePixel = 0
	diode.Parent = holder

	local diodeCorner = Instance.new("UICorner")
	diodeCorner.CornerRadius = Theme.Radius.full
	diodeCorner.Parent = diode

	local text
	if label then
		text = Instance.new("TextLabel")
		text.Name = "Label"
		text.Position = UDim2.fromOffset(20, 0)
		text.Size = UDim2.new(1, -20, 1, 0)
		text.BackgroundTransparency = 1
		text.Font = Theme.Font.mono
		text.Text = Theme.stamp(label)
		text.TextColor3 = Theme.Color.textMuted
		text.TextSize = 11
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Parent = holder
	end

	-- Breathing pulse, the animate-pulse equivalent.
	task.spawn(function()
		while holder.Parent do
			TweenService:Create(
				bloom,
				TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ BackgroundTransparency = 0.9 }
			):Play()
			task.wait(1)
			TweenService:Create(
				bloom,
				TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
				{ BackgroundTransparency = 0.68 }
			):Play()
			task.wait(1)
		end
	end)

	return holder, text
end

--- CRT scanlines. No repeating-texture support in Roblox, so the lines are
--- real (thin) frames -- fine for one small display panel.
function Bevel.scanlines(frame: GuiObject, height: number, spacing: number?)
	local gap = spacing or 4
	local holder = Instance.new("Frame")
	holder.Name = "Scanlines"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 3
	holder.ClipsDescendants = true
	holder.Parent = frame

	for offset = 0, height, gap do
		local line = Instance.new("Frame")
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BackgroundTransparency = 0.78
		line.BorderSizePixel = 0
		line.Position = UDim2.fromOffset(0, offset)
		line.Size = UDim2.new(1, 0, 0, 2)
		line.Parent = holder
	end

	return holder
end

-- Interaction physics ----------------------------------------------------

--- Wires the press metaphor onto a button: it travels 2px down the light
--- direction and its rim inverts, then springs back on release.
function Bevel.pressable(button: GuiButton, restPosition: UDim2?)
	local rest = restPosition or button.Position
	local down = rest + UDim2.fromOffset(0, 2)
	local held = false

	local function press()
		if held then
			return
		end
		held = true
		TweenService:Create(
			button,
			TweenInfo.new(Theme.Motion.press, Theme.Motion.smooth, Enum.EasingDirection.Out),
			{ Position = down }
		):Play()
		Bevel.invert(button, true)
	end

	local function release()
		if not held then
			return
		end
		held = false
		TweenService:Create(
			button,
			TweenInfo.new(Theme.Motion.press, Theme.Motion.mechanical, Enum.EasingDirection.Out),
			{ Position = rest }
		):Play()
		Bevel.invert(button, false)
	end

	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			press()
		end
	end)

	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			release()
		end
	end)

	button.MouseLeave:Connect(release)

	return function()
		-- Lets a caller re-baseline the rest position after a layout change.
		rest = button.Position
		down = rest + UDim2.fromOffset(0, 2)
	end
end

return Bevel
