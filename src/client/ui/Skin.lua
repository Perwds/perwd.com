--!strict
--[[
	Skin -- the sticker look, as reusable parts.

	Every surface in the game is built the same way:

	    outline   a thick near-black UIStroke
	    lip       a darker strip along the bottom edge, inside the frame, which
	              is what makes it read as a solid object rather than a rectangle
	    gloss     a white band across the top that fades out
	    squash    a UIScale that dips when you press it

	The lip and gloss are CHILDREN, never siblings, and the press animation is
	a UIScale rather than a position offset -- both so that any of this can live
	inside a UIListLayout, which owns its children's positions.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Skin = {}

-- Surfaces ---------------------------------------------------------------

function Skin.outline(gui: GuiObject, weight: number?, color: Color3?): UIStroke
	local existing = gui:FindFirstChild("Outline")
	if existing then
		return existing :: UIStroke
	end

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Thickness = weight or Theme.Outline.base
	stroke.Color = color or Theme.Color.outline
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = gui
	return stroke
end

--- A UIPadding insets every child, which would pull the lip and gloss away
--- from the edges they are supposed to sit on. This reads the padding back out
--- so they can be grown to compensate.
local function insets(gui: GuiObject): (number, number, number, number)
	local padding = gui:FindFirstChildOfClass("UIPadding")
	if not padding then
		return 0, 0, 0, 0
	end
	return padding.PaddingLeft.Offset,
		padding.PaddingRight.Offset,
		padding.PaddingTop.Offset,
		padding.PaddingBottom.Offset
end

--- The darker strip along the bottom that gives an object its thickness.
function Skin.lip(gui: GuiObject, depth: number?, radius: UDim?): Frame
	local existing = gui:FindFirstChild("Lip")
	if existing then
		return existing :: Frame
	end

	local height = depth or Theme.Lip.base
	local fill = gui.BackgroundColor3

	local left, right, _, bottom = insets(gui)

	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.AnchorPoint = Vector2.new(0.5, 1)
	lip.Position = UDim2.new(0.5, 0, 1, bottom)
	lip.Size = UDim2.new(1, left + right, 0, height)
	lip.BackgroundColor3 = Theme.shade(fill, -0.32)
	lip.BorderSizePixel = 0
	lip.ZIndex = gui.ZIndex
	lip.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Radius.md
	corner.Parent = lip

	return lip
end

--- Glossy highlight across the top third.
function Skin.gloss(gui: GuiObject, radius: UDim?): Frame
	local left, right, top = insets(gui)

	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.Position = UDim2.fromOffset(-left, -top)
	gloss.Size = UDim2.new(1, left + right, 0.42, 0)
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.82
	gloss.BorderSizePixel = 0
	gloss.ZIndex = gui.ZIndex
	gloss.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Radius.md
	corner.Parent = gloss

	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Rotation = 90
	fade.Parent = gloss

	return gloss
end

--- The full treatment. `opts.lip`, `opts.gloss`, `opts.weight`, `opts.radius`.
function Skin.card(gui: GuiObject, opts: { [string]: any }?): GuiObject
	local options = opts or {}
	local radius = options.radius or Theme.Radius.md

	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = gui

	Skin.outline(gui, options.weight)

	if options.lip ~= false then
		Skin.lip(gui, options.lip, radius)
	end
	if options.gloss ~= false then
		Skin.gloss(gui, radius)
	end

	return gui
end

--- Recessed well: progress tracks, data strips, list backgrounds.
function Skin.well(gui: GuiObject, radius: UDim?): GuiObject
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Radius.full
	corner.Parent = gui

	gui.BackgroundColor3 = Theme.Color.slot
	Skin.outline(gui, Theme.Outline.thin)
	return gui
end

-- Motion -----------------------------------------------------------------

local function scaleOf(gui: GuiObject): UIScale
	local existing = gui:FindFirstChildOfClass("UIScale")
	if existing then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	return scale
end

--- Squash-and-release. Scale is used rather than a position offset so this
--- works identically for a button inside a UIListLayout.
function Skin.pressable(button: GuiButton)
	local scale = scaleOf(button)
	local lip = button:FindFirstChild("Lip") :: Frame?
	local restLip = lip and lip.Size or nil
	local held = false

	local function down()
		if held then
			return
		end
		held = true
		TweenService:Create(scale, TweenInfo.new(Theme.Motion.press), { Scale = 0.94 }):Play()
		if lip and restLip then
			TweenService:Create(lip, TweenInfo.new(Theme.Motion.press), {
				Size = UDim2.new(restLip.X.Scale, restLip.X.Offset, 0, 2),
			}):Play()
		end
	end

	local function up()
		if not held then
			return
		end
		held = false
		TweenService:Create(
			scale,
			TweenInfo.new(Theme.Motion.settle, Theme.Motion.pop, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		if lip and restLip then
			TweenService:Create(lip, TweenInfo.new(Theme.Motion.settle), { Size = restLip }):Play()
		end
	end

	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			down()
		end
	end)
	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			up()
		end
	end)
	button.MouseLeave:Connect(up)

	button.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(Theme.Motion.hover), { Scale = 1.03 }):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(Theme.Motion.hover), { Scale = 1 }):Play()
	end)
end

--- One-shot attention pop.
function Skin.pop(gui: GuiObject, strength: number?)
	local scale = scaleOf(gui)
	scale.Scale = 1 + (strength or 0.12)
	TweenService:Create(
		scale,
		TweenInfo.new(0.3, Theme.Motion.pop, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()
end

--- Quick shake for refusals.
function Skin.shake(gui: GuiObject)
	local rest = gui.Rotation
	local step = 0
	task.spawn(function()
		while step < 6 do
			step += 1
			gui.Rotation = rest + (step % 2 == 0 and 3 or -3)
			task.wait(0.03)
		end
		gui.Rotation = rest
	end)
end

--- Confetti burst inside `parent`, used when a scan lands.
function Skin.confetti(parent: GuiObject, tint: Color3, count: number?)
	local colors = { tint, Theme.Color.gold, Theme.Color.green, Theme.Color.pink, Theme.Color.cyan }

	for index = 1, count or 14 do
		local bit = Instance.new("Frame")
		bit.Name = "Confetti"
		bit.AnchorPoint = Vector2.new(0.5, 0.5)
		bit.Position = UDim2.fromScale(0.5, 0.5)
		bit.Size = UDim2.fromOffset(math.random(5, 9), math.random(7, 13))
		bit.BackgroundColor3 = colors[(index % #colors) + 1]
		bit.BorderSizePixel = 0
		bit.Rotation = math.random(0, 360)
		bit.ZIndex = 20
		bit.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 2)
		corner.Parent = bit

		local angle = math.rad(math.random(0, 360))
		local distance = math.random(70, 190)

		TweenService:Create(bit, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, math.cos(angle) * distance, 0.5, math.sin(angle) * distance),
			Rotation = bit.Rotation + math.random(-220, 220),
			BackgroundTransparency = 1,
		}):Play()

		task.delay(0.75, function()
			bit:Destroy()
		end)
	end
end

return Skin
