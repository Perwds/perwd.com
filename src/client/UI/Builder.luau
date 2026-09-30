--[[
	Thin declarative wrapper over Instance.new.

	`Builder.make(class, props, children)` keeps the UI code readable without
	pulling in a full UI library -- props are applied in order, children are
	parented after, and the `Parent` prop is applied last so nothing renders
	half-built.
]]

local Theme = require(script.Parent.Theme)

local Builder = {}

function Builder.make(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil

	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				(instance :: any)[key] = value
			end
		end
	end

	if children then
		for _, child in children do
			child.Parent = instance
		end
	end

	if parent then
		instance.Parent = parent
	end

	return instance
end

local make = Builder.make

function Builder.corner(radius: number?): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius or Theme.Metric.corner) })
end

function Builder.stroke(thickness: number?, color: Color3?): UIStroke
	return make("UIStroke", {
		Thickness = thickness or Theme.Metric.stroke,
		Color = color or Theme.Color.stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

function Builder.padding(all: number?, overrides: { [string]: number }?): UIPadding
	local value = all or Theme.Metric.padding
	local padding = make("UIPadding", {
		PaddingTop = UDim.new(0, value),
		PaddingBottom = UDim.new(0, value),
		PaddingLeft = UDim.new(0, value),
		PaddingRight = UDim.new(0, value),
	})
	if overrides then
		for key, override in overrides do
			(padding :: any)[key] = UDim.new(0, override)
		end
	end
	return padding
end

function Builder.list(props: { [string]: any }?): UIListLayout
	return make(
		"UIListLayout",
		Builder.merge({
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}, props)
	)
end

function Builder.grid(cellSize: UDim2, props: { [string]: any }?): UIGridLayout
	return make(
		"UIGridLayout",
		Builder.merge({
			CellSize = cellSize,
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}, props)
	)
end

function Builder.gradient(from: Color3, to: Color3, rotation: number?): UIGradient
	return make("UIGradient", {
		Color = ColorSequence.new(from, to),
		Rotation = rotation or 90,
	})
end

function Builder.merge(base: { [string]: any }, overrides: { [string]: any }?)
	if not overrides then
		return base
	end
	local out = table.clone(base)
	for key, value in overrides do
		out[key] = value
	end
	return out
end

--- Heavy white text with a black stroke -- the game's default label.
function Builder.label(text: string, props: { [string]: any }?): TextLabel
	return make(
		"TextLabel",
		Builder.merge({
			BackgroundTransparency = 1,
			Font = Theme.Font.title,
			Text = text,
			TextColor3 = Theme.Color.text,
			TextStrokeTransparency = 0,
			TextStrokeColor3 = Theme.Color.textStroke,
			TextScaled = true,
			Size = UDim2.fromScale(1, 1),
		}, props)
	)
end

--- A chunky pill button with a stroke, a gradient and a press animation.
function Builder.button(text: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local color = (props and props.BackgroundColor3) or Theme.Color.green

	local button = make(
		"TextButton",
		Builder.merge({
			BackgroundColor3 = color,
			AutoButtonColor = false,
			Font = Theme.Font.title,
			Text = text,
			TextColor3 = Theme.Color.text,
			TextStrokeTransparency = 0,
			TextStrokeColor3 = Theme.Color.textStroke,
			TextScaled = true,
			Size = UDim2.fromOffset(120, 44),
		}, props),
		{
			Builder.corner(),
			Builder.stroke(),
			Builder.gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)),
			make("UIPadding", {
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
				PaddingLeft = UDim.new(0, 10),
				PaddingRight = UDim.new(0, 10),
			}),
		}
	)

	-- Press feedback without a tween service round trip.
	local base = button.Size
	button.MouseButton1Down:Connect(function()
		button.Size = UDim2.new(base.X.Scale, base.X.Offset - 4, base.Y.Scale, base.Y.Offset - 4)
	end)
	local function restore()
		button.Size = base
	end
	button.MouseButton1Up:Connect(restore)
	button.MouseLeave:Connect(restore)

	if onClick then
		button.MouseButton1Click:Connect(onClick)
	end

	return button
end

--- Rounded container with the standard panel treatment.
function Builder.frame(props: { [string]: any }?, children: { Instance }?): Frame
	local all = children and table.clone(children) or {}
	table.insert(all, 1, Builder.stroke())
	table.insert(all, 1, Builder.corner())

	return make(
		"Frame",
		Builder.merge({
			BackgroundColor3 = Theme.Color.panel,
			BorderSizePixel = 0,
		}, props),
		all
	)
end

--- A horizontal progress bar, e.g. the 0/8 index bar.
function Builder.progressBar(props: { [string]: any }?)
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = Theme.Color.green,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, { Builder.corner(Theme.Metric.cornerSmall) })

	local text = Builder.label("0/0", {
		Name = "Text",
		ZIndex = 3,
		TextStrokeTransparency = 0,
	})

	local bar = make(
		"Frame",
		Builder.merge({
			BackgroundColor3 = Theme.Color.panelInset,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 40),
			ClipsDescendants = true,
		}, props),
		{ Builder.corner(Theme.Metric.cornerSmall), Builder.stroke(Theme.Metric.strokeThin), fill, text }
	)

	return bar, fill, text
end

function Builder.scroller(props: { [string]: any }?): ScrollingFrame
	return make(
		"ScrollingFrame",
		Builder.merge({
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Color.textDim,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			Size = UDim2.fromScale(1, 1),
		}, props)
	)
end

return Builder
