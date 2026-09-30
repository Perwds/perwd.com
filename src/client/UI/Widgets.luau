--!nonstrict
-- UI constructors. Plain Roblox instances, no framework and no uploaded image
-- assets: depth comes from gradients and stroke gradients rather than sprites,
-- which keeps the whole interface in source.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Widgets = {}

-- Primitives ---------------------------------------------------------------------

function Widgets.Corner(parent: Instance, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Corner
	corner.Parent = parent
	return corner
end

function Widgets.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.StrokeTop
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Widgets.Padding(parent: Instance, px: number, horizontal: number?): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, px)
	padding.PaddingBottom = UDim.new(0, px)
	padding.PaddingLeft = UDim.new(0, horizontal or px)
	padding.PaddingRight = UDim.new(0, horizontal or px)
	padding.Parent = parent
	return padding
end

function Widgets.List(parent: Instance, gap: number, direction: Enum.FillDirection?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = direction or Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent
	return layout
end

function Widgets.Gradient(parent: Instance, colors, rotation: number?, transparency): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation or 90

	if typeof(colors) == "ColorSequence" then
		gradient.Color = colors
	elseif type(colors) == "table" then
		gradient.Color = ColorSequence.new(colors[1], colors[2])
	end

	if transparency then
		gradient.Transparency = transparency
	end

	gradient.Parent = parent
	return gradient
end

-- A lit top lip fading to a dark bottom edge. Used on every raised surface.
function Widgets.StrokeGradient(stroke: UIStroke, top: Color3?, bottom: Color3?): UIGradient
	return Widgets.Gradient(stroke, { top or Theme.StrokeTop, bottom or Theme.StrokeBottom }, 90)
end

-- Frames -------------------------------------------------------------------------

function Widgets.Frame(props): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = props.color or Theme.Panel
	frame.BackgroundTransparency = props.transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.size or UDim2.fromScale(1, 1)
	frame.Position = props.position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = props.anchor or Vector2.zero
	frame.LayoutOrder = props.order or 0
	frame.ZIndex = props.zIndex or 1
	frame.Name = props.name or "Frame"
	frame.Visible = props.visible ~= false
	frame.ClipsDescendants = props.clip == true
	frame.Parent = props.parent
	return frame
end

-- The house surface: translucent, vertically graded, with a graded hairline
-- border. `tint` bleeds a colour into the top edge for rarity emphasis.
function Widgets.Glass(props): Frame
	local frame = Widgets.Frame({
		parent = props.parent,
		name = props.name or "Glass",
		size = props.size,
		position = props.position,
		anchor = props.anchor,
		order = props.order,
		zIndex = props.zIndex,
		visible = props.visible,
		clip = props.clip,
		color = Color3.new(1, 1, 1),
		transparency = props.transparency or 0.04,
	})

	local top = props.tint and Theme.GlassTop:Lerp(props.tint, 0.45) or Theme.GlassTop
	Widgets.Gradient(frame, { top, Theme.GlassBottom }, 90)
	Widgets.Corner(frame, props.corner or Theme.Corner)

	local stroke = Widgets.Stroke(frame, nil, props.strokeThickness or 1.4)
	Widgets.StrokeGradient(stroke, props.tint or Theme.StrokeTop, Theme.StrokeBottom)

	return frame
end

-- Text -------------------------------------------------------------------------

function Widgets.Text(props): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = props.size or UDim2.fromScale(1, 1)
	label.Position = props.position or UDim2.fromScale(0, 0)
	label.AnchorPoint = props.anchor or Vector2.zero
	label.Font = props.font or Theme.Font
	label.Text = props.text or ""
	label.TextColor3 = props.color or Theme.Text
	label.TextSize = props.textSize or 14
	label.TextXAlignment = props.align or Enum.TextXAlignment.Left
	label.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	label.TextTruncate = props.truncate or Enum.TextTruncate.AtEnd
	label.RichText = props.richText or false
	label.TextTransparency = props.textTransparency or 0
	label.LayoutOrder = props.order or 0
	label.ZIndex = props.zIndex or 1
	label.Name = props.name or "Text"
	label.Parent = props.parent

	if props.glow then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.glow
		stroke.Thickness = props.glowThickness or 2
		stroke.Transparency = props.glowTransparency or 0.55
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Parent = label
	end

	return label
end

-- Buttons -------------------------------------------------------------------------

function Widgets.Button(props): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0.04
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Size = props.size or UDim2.new(1, 0, 0, 34)
	button.Position = props.position or UDim2.fromScale(0, 0)
	button.AnchorPoint = props.anchor or Vector2.zero
	button.Font = props.font or Theme.FontBold
	button.Text = props.text or ""
	button.TextColor3 = props.textColor or Theme.Text
	button.TextSize = props.textSize or 14
	button.LayoutOrder = props.order or 0
	button.ZIndex = props.zIndex or 2
	button.Name = props.name or "Button"
	button.AutomaticSize = Enum.AutomaticSize.None
	button.Parent = props.parent

	local base = props.color or Theme.PanelRaised
	local gradient = Widgets.Gradient(button, { base:Lerp(Color3.new(1, 1, 1), 0.16), base }, 90)
	Widgets.Corner(button, props.corner or Theme.CornerSmall)

	local stroke = Widgets.Stroke(button, nil, 1.2)
	Widgets.StrokeGradient(stroke, props.tint or base:Lerp(Color3.new(1, 1, 1), 0.4), Theme.StrokeBottom)

	local function grade(lift: number)
		gradient.Color = ColorSequence.new(base:Lerp(Color3.new(1, 1, 1), 0.16 + lift), base:Lerp(Color3.new(1, 1, 1), lift))
	end

	button.MouseEnter:Connect(function()
		grade(0.12)
	end)
	button.MouseLeave:Connect(function()
		grade(0)
		TweenService:Create(button, Theme.Quick, { Size = props.size or UDim2.new(1, 0, 0, 34) }):Play()
	end)

	-- Presses read as a small squash rather than a colour flip.
	button.MouseButton1Down:Connect(function()
		grade(0.22)
	end)
	button.MouseButton1Up:Connect(function()
		grade(0.12)
	end)

	if props.onClick then
		button.Activated:Connect(props.onClick)
	end

	return button
end

-- Containers -------------------------------------------------------------------------

function Widgets.Scroller(props): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = props.size or UDim2.fromScale(1, 1)
	scroller.Position = props.position or UDim2.fromScale(0, 0)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 3
	scroller.ScrollBarImageColor3 = Theme.StrokeTop
	scroller.ScrollBarImageTransparency = 0.4
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.LayoutOrder = props.order or 0
	scroller.ZIndex = props.zIndex or 1
	scroller.Name = props.name or "Scroller"
	scroller.Parent = props.parent
	return scroller
end

function Widgets.Bar(props)
	local track = Widgets.Frame({
		parent = props.parent,
		size = props.size or UDim2.new(1, 0, 0, 6),
		position = props.position,
		anchor = props.anchor,
		color = props.trackColor or Theme.Background,
		transparency = props.trackTransparency or 0.25,
		order = props.order,
		zIndex = props.zIndex,
		name = props.name or "Bar",
		clip = true,
	})
	Widgets.Corner(track, Theme.CornerPill)

	local fillColor = props.fillColor or Theme.Accent
	local fill = Widgets.Frame({
		parent = track,
		size = UDim2.fromScale(0, 1),
		color = Color3.new(1, 1, 1),
		name = "Fill",
		zIndex = 2,
	})
	Widgets.Gradient(fill, { fillColor:Lerp(Color3.new(1, 1, 1), 0.35), fillColor }, 90)
	Widgets.Corner(fill, Theme.CornerPill)

	return track, fill
end

-- Motion -------------------------------------------------------------------------

function Widgets.Tween(instance: Instance, seconds: number, goal, style: Enum.EasingStyle?)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- Scale-in entrance, used by the catch card and the panel.
function Widgets.PopIn(frame: GuiObject, from: number?)
	local scale = frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = from or 0.86
	scale.Parent = frame

	TweenService:Create(scale, Theme.Pop, { Scale = 1 }):Play()
	return scale
end

return Widgets
