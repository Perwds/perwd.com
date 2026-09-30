--!nonstrict
-- Small constructors so the panel code reads as layout rather than as a wall of
-- Instance.new. Everything is plain Roblox UI; no framework.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Widgets = {}

function Widgets.Corner(parent: Instance, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Corner
	corner.Parent = parent
	return corner
end

function Widgets.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Stroke
	stroke.Thickness = thickness or 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Widgets.Padding(parent: Instance, px: number): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, px)
	padding.PaddingBottom = UDim.new(0, px)
	padding.PaddingLeft = UDim.new(0, px)
	padding.PaddingRight = UDim.new(0, px)
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

function Widgets.Frame(props): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = props.color or Theme.Panel
	frame.BackgroundTransparency = props.transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.size or UDim2.fromScale(1, 1)
	frame.Position = props.position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = props.anchor or Vector2.zero
	frame.LayoutOrder = props.order or 0
	frame.Name = props.name or "Frame"
	frame.Visible = props.visible ~= false
	frame.Parent = props.parent
	return frame
end

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
	label.LayoutOrder = props.order or 0
	label.Name = props.name or "Text"
	label.Parent = props.parent
	return label
end

function Widgets.Button(props): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = props.color or Theme.PanelRaised
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Size = props.size or UDim2.new(1, 0, 0, 34)
	button.Position = props.position or UDim2.fromScale(0, 0)
	button.AnchorPoint = props.anchor or Vector2.zero
	button.Font = props.font or Theme.FontMedium
	button.Text = props.text or ""
	button.TextColor3 = props.textColor or Theme.Text
	button.TextSize = props.textSize or 14
	button.LayoutOrder = props.order or 0
	button.Name = props.name or "Button"
	button.Parent = props.parent

	Widgets.Corner(button, props.corner or Theme.CornerSmall)

	local base = button.BackgroundColor3
	local hover = base:Lerp(Color3.new(1, 1, 1), 0.12)

	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = hover }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), { BackgroundColor3 = base }):Play()
	end)

	if props.onClick then
		button.Activated:Connect(props.onClick)
	end

	return button
end

function Widgets.Scroller(props): ScrollingFrame
	local scroller = Instance.new("ScrollingFrame")
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = props.size or UDim2.fromScale(1, 1)
	scroller.Position = props.position or UDim2.fromScale(0, 0)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.ScrollBarImageColor3 = Theme.Stroke
	scroller.LayoutOrder = props.order or 0
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
		order = props.order,
		name = props.name or "Bar",
	})
	Widgets.Corner(track, UDim.new(1, 0))

	local fill = Widgets.Frame({
		parent = track,
		size = UDim2.fromScale(0, 1),
		color = props.fillColor or Theme.Accent,
		name = "Fill",
	})
	Widgets.Corner(fill, UDim.new(1, 0))

	return track, fill
end

function Widgets.Tween(instance: Instance, seconds: number, goal, style: Enum.EasingStyle?)
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

return Widgets
