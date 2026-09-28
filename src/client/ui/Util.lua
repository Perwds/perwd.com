--!strict
--[[
	Util -- instance builder plus the composed arcade controls.

	Every colour, radius and motion curve comes from Theme, and every surface
	treatment from Skin, so restyling the game means editing those two files.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Skin = require(script.Parent.Skin)
local Sfx = require(script.Parent.Sfx)

local Util = {}

--- Keys owned by these helpers, not by Roblox instances. Util.new skips them
--- so a helper that forgets to strip one loses a lip, not the whole UI.
local RESERVED = {
	radius = true,
	variant = true,
	weight = true,
	lip = true,
	gloss = true,
	sound = true,
	padding = true,
}

function Util.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)

	if props then
		local parent = props.Parent
		props.Parent = nil
		for key, value in pairs(props) do
			if not RESERVED[key] then
				(instance :: any)[key] = value
			end
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

function Util.tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local info = TweenInfo.new(seconds, style or Theme.Motion.snap, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

-- Text -------------------------------------------------------------------

function Util.text(props: { [string]: any }): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Theme.Font.body
	props.TextColor3 = props.TextColor3 or Theme.Color.ink
	props.BorderSizePixel = 0
	return Util.new("TextLabel", props)
end

--- Heavy display text with the dark outline that keeps it readable on any fill.
function Util.title(props: { [string]: any }): TextLabel
	props.Font = props.Font or Theme.Font.display
	local label = Util.text(props)
	Util.new("UIStroke", {
		Thickness = props.TextSize and math.max(2, props.TextSize / 12) or 2,
		Color = Theme.Color.outline,
		Transparency = 0.15,
		Parent = label,
	})
	return label
end

-- Controls ---------------------------------------------------------------

local VARIANTS = {
	go = { fill = Theme.Color.green, sound = "click" },
	gold = { fill = Theme.Color.gold, sound = "click" },
	danger = { fill = Theme.Color.red, sound = "deny" },
	plain = { fill = Theme.Color.panelLite, sound = "click" },
	dark = { fill = Theme.Color.slot, sound = "tab" },
	pink = { fill = Theme.Color.pink, sound = "click" },
	cyan = { fill = Theme.Color.cyan, sound = "click" },
}

--- A chunky key: outline, lip, gloss, and a squash on press.
function Util.button(props: { [string]: any }, children: { Instance }?): TextButton
	local variant = VARIANTS[props.variant or "plain"]
	local radius = props.radius or Theme.Radius.md
	local lip = props.lip
	local sound = props.sound or variant.sound

	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	props.Font = props.Font or Theme.Font.display
	props.BackgroundColor3 = props.BackgroundColor3 or variant.fill
	props.TextColor3 = props.TextColor3 or Theme.inkOn(props.BackgroundColor3)

	local button: TextButton = Util.new("TextButton", props, children)

	Skin.card(button, { radius = radius, lip = lip, gloss = true })

	-- Outlines the label text (Contextual stroke mode), which is a different
	-- job from the border outline Skin.card already applied.
	Util.new("UIStroke", {
		Thickness = 2,
		Color = Theme.Color.outline,
		Transparency = 0.25,
		Parent = button:FindFirstChildOfClass("TextLabel") or button,
	})

	Skin.pressable(button)

	button.Activated:Connect(function()
		Sfx.play(sound)
	end)

	return button
end

--- Recessed track or strip.
function Util.well(props: { [string]: any }): Frame
	local radius = props.radius or Theme.Radius.full
	props.BorderSizePixel = 0
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.slot

	local frame: Frame = Util.new("Frame", props)
	Skin.well(frame, radius)
	return frame
end

--- A solid card. Pass `padding` here rather than adding a UIPadding
--- afterwards: the lip and gloss measure the padding when they are built.
function Util.card(props: { [string]: any }): Frame
	local radius = props.radius or Theme.Radius.md
	local weight = props.weight
	local lip = props.lip
	local gloss = props.gloss
	local padding = props.padding

	props.BorderSizePixel = 0
	props.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.panelLite

	local frame: Frame = Util.new("Frame", props)
	if padding then
		Util.padding(padding, frame)
	end
	Skin.card(frame, { radius = radius, weight = weight, lip = lip, gloss = gloss })
	return frame
end

--- Round badge for an icon or a number.
function Util.badge(parent: Instance, glyph: string, size: number, fill: Color3?): Frame
	local badge = Util.new("Frame", {
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = fill or Theme.Color.panel,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Skin.card(badge, { radius = Theme.Radius.full, lip = Theme.Lip.small, gloss = true })

	Util.text({
		Size = UDim2.fromScale(1, 1),
		Text = glyph,
		TextSize = math.floor(size * 0.52),
		Font = Theme.Font.display,
		Parent = badge,
	})

	return badge
end

--- A layout-safe animation cell: the list positions the cell, you move what is
--- inside it.
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

--- Fades an element and everything inside it.
function Util.fadeOut(instance: GuiObject, seconds: number, done: (() -> ())?)
	local targets: { Instance } = { instance }
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
