--!strict
--[[
	Util -- declarative instance builder plus the composed control primitives.

	Nothing here invents styling. Every colour, radius, easing curve and
	elevation comes from Theme, and every bevel comes from Bevel, so a token
	change propagates to the whole interface.

	  Util.new("TextLabel", { Text = "hi" }, { child1, child2 })
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Bevel = require(script.Parent.Bevel)

local Util = {}

function Util.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)

	if props then
		local parent = props.Parent
		props.Parent = nil
		for key, value in pairs(props) do
			(instance :: any)[key] = value
		end
		if parent then
			instance.Parent = parent
		end
	end

	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end

	return instance
end

function Util.corner(radius: UDim, parent: Instance?): UICorner
	return Util.new("UICorner", { CornerRadius = radius, Parent = parent })
end

function Util.padding(amount: number, parent: Instance?): UIPadding
	return Util.new("UIPadding", {
		PaddingTop = UDim.new(0, amount),
		PaddingBottom = UDim.new(0, amount),
		PaddingLeft = UDim.new(0, amount),
		PaddingRight = UDim.new(0, amount),
		Parent = parent,
	})
end

function Util.stroke(color: Color3, thickness: number, parent: Instance?): UIStroke
	return Util.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Util.listLayout(padding: number, parent: Instance?, direction: Enum.FillDirection?): UIListLayout
	return Util.new("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Util.gradient(top: Color3, bottom: Color3, parent: Instance?): UIGradient
	return Util.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = Theme.LIGHT_ANGLE,
		Parent = parent,
	})
end

function Util.tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local info = TweenInfo.new(seconds, style or Theme.Motion.smooth, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

-- Text -------------------------------------------------------------------

--- Body / heading text. `mono` routes numbers and data through RobotoMono.
function Util.text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Theme.Font.body
	props.TextColor3 = props.TextColor3 or Theme.Color.text
	props.BorderSizePixel = 0
	return Util.new("TextLabel", props)
end

--- Stamped uppercase monospace metadata -- the printed-label look.
function Util.stamp(props: { [string]: any }): TextLabel
	props.Font = Theme.Font.mono
	props.Text = Theme.stamp(props.Text or "")
	props.TextColor3 = props.TextColor3 or Theme.Color.textMuted
	props.TextSize = props.TextSize or 11
	return Util.text(props)
end

-- Controls ---------------------------------------------------------------

local VARIANTS = {
	-- Safety orange. The emergency-stop control: use sparingly.
	primary = {
		fill = Theme.Color.accent,
		ink = Theme.Color.accentText,
		level = "floating",
	},
	-- Chassis-coloured key. The default.
	secondary = {
		fill = Theme.Color.chassis,
		ink = Theme.Color.text,
		level = "panel",
	},
	-- Flat label until touched.
	ghost = {
		fill = Theme.Color.chassis,
		ink = Theme.Color.textMuted,
		level = "chassis",
	},
	-- Recessed well that lights up when selected (nav rail, tabs).
	slot = {
		fill = Theme.Color.recess,
		ink = Theme.Color.textMuted,
		level = "recessed",
	},
}

--- A physical key. Depresses 2px and inverts its rim on press, springs back
--- on release, and never changes size -- real buttons do not grow when you
--- point at them.
function Util.button(props: { [string]: any }, children: { Instance }?): TextButton
	local variant = VARIANTS[props.variant or "secondary"]
	local radius = props.radius or Theme.Radius.md
	props.variant = nil
	props.radius = nil

	props.AutoButtonColor = false
	props.Font = props.Font or Theme.Font.bold
	props.BackgroundColor3 = props.BackgroundColor3 or variant.fill
	props.TextColor3 = props.TextColor3 or variant.ink
	props.BorderSizePixel = 0

	if props.Text then
		props.Text = props.Text
	end

	local button: TextButton = Util.new("TextButton", props, children)

	if variant.level == "recessed" then
		Bevel.recess(button, radius)
		button.BackgroundColor3 = props.BackgroundColor3
	elseif variant.level == "chassis" then
		Util.corner(radius, button)
	else
		Bevel.panel(button, variant.level, radius)
	end

	-- Hover raises the ink towards the accent rather than resizing the key.
	-- The rest colour is sampled on enter, not at construction, because
	-- selection state (the nav rail) rewrites TextColor3 after the fact.
	local restInk = button.TextColor3
	button.MouseEnter:Connect(function()
		restInk = button.TextColor3
		Util.tween(button, Theme.Motion.hover, { TextColor3 = Theme.Color.accent })
	end)
	button.MouseLeave:Connect(function()
		Util.tween(button, Theme.Motion.hover, { TextColor3 = restInk })
	end)

	Bevel.pressable(button)

	return button
end

--- Recessed data well: inputs, progress tracks, screen bezels.
function Util.well(props: { [string]: any }): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.recess
	props.BorderSizePixel = 0
	local frame: Frame = Util.new("Frame", props)
	Bevel.recess(frame, props.radius or Theme.Radius.md)
	return frame
end

--- Panel bolted to the chassis.
---
--- `details` turns on the manufacturing marks. Pass `true` for the defaults,
--- or a table to place them: { padding = 16, ventPos = UDim2..., screws =,
--- vents = }. Panels that carry a UIPadding must declare it so the screws sit
--- in the border margin rather than over the content.
function Util.panel(props: { [string]: any }, details: (boolean | { [string]: any })?): Frame
	local radius = props.radius or Theme.Radius.lg
	local level = props.level or "panel"
	props.radius = nil
	props.level = nil

	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.chassis
	props.BorderSizePixel = 0

	local frame: Frame = Util.new("Frame", props)
	Bevel.panel(frame, level, radius)

	if details then
		local options = type(details) == "table" and details or {}
		if options.screws ~= false then
			Bevel.screws(frame, options.inset, options.padding)
		end
		if options.vents ~= false then
			Bevel.vents(frame, options.ventCount, options.ventPos)
		end
	end

	return frame
end

--- Fades an element and everything inside it, then runs the callback. Tweening
--- only BackgroundTransparency would leave the text and stripes visible until
--- the instance is destroyed.
function Util.fadeOut(instance: GuiObject, seconds: number, done: (() -> ())?)
	local targets = { instance }
	for _, descendant in ipairs(instance:GetDescendants()) do
		table.insert(targets, descendant)
	end

	for _, target in ipairs(targets) do
		if target:IsA("TextLabel") or target:IsA("TextButton") then
			Util.tween(target, seconds, { BackgroundTransparency = 1, TextTransparency = 1 })
		elseif target:IsA("GuiObject") then
			Util.tween(target, seconds, { BackgroundTransparency = 1 })
		elseif target:IsA("UIStroke") then
			Util.tween(target, seconds, { Transparency = 1 })
		end
	end

	task.delay(seconds, function()
		if done then
			done()
		end
	end)
end

--- A layout-safe animation slot. A UIListLayout owns its children's Position,
--- so anything that needs to slide has to move INSIDE a cell the layout owns.
function Util.slot(props: { [string]: any }): (Frame, Frame)
	local cell = Util.new("Frame", {
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
		BackgroundTransparency = 1,
		Parent = props.Parent,
	})

	local inner = Util.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = cell,
	})

	return cell, inner
end

--- Circular recessed housing for an icon, so icons are never left floating.
function Util.iconHousing(parent: Instance, glyph: string, size: number, color: Color3?): Frame
	local housing = Util.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = Theme.Color.chassis,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Bevel.panel(housing, "floating", Theme.Radius.full)

	Util.text({
		Size = UDim2.fromScale(1, 1),
		Text = glyph,
		TextSize = math.floor(size * 0.5),
		TextColor3 = color or Theme.Color.accent,
		Parent = housing,
	})

	return housing
end

--- Debounced click handler.
function Util.onClick(button: GuiButton, cooldown: number, callback: () -> ())
	local last = 0
	button.Activated:Connect(function()
		local now = os.clock()
		if now - last < cooldown then
			return
		end
		last = now
		callback()
	end)
end

return Util
