--!strict
-- Small builders and motion helpers shared by every screen. One look: dark panels, Arcade numbers,
-- RobotoMono body text, no transparency tricks.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local Config = require(ReplicatedStorage.Shared.Config)

local Ui = {}

Ui.TITLE = Enum.Font.Arcade
Ui.BODY = Enum.Font.RobotoMono
Ui.MIN_TAP = 48

function Ui.new(className: string, props: { [string]: any }, children: { Instance }?): any
	local object = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(object :: any)[key] = value
		end
	end
	for _, child in children or {} do
		child.Parent = object
	end
	if props.Parent then
		object.Parent = props.Parent
	end
	return object
end

function Ui.corner(radius: number?): UICorner
	return Ui.new("UICorner", { CornerRadius = UDim.new(0, radius or 6) })
end

function Ui.stroke(color: Color3?, thickness: number?): UIStroke
	return Ui.new("UIStroke", {
		Color = color or Palette.hudEdge,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Ui.padding(px: number): UIPadding
	local u = UDim.new(0, px)
	return Ui.new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

function Ui.panel(props: { [string]: any }): Frame
	local frame = Ui.new("Frame", props)
	frame.BackgroundColor3 = props.BackgroundColor3 or Palette.hud
	frame.BorderSizePixel = 0
	Ui.corner(8).Parent = frame
	Ui.stroke().Parent = frame
	return frame
end

function Ui.text(props: { [string]: any }): TextLabel
	local label = Ui.new("TextLabel", props)
	label.BackgroundTransparency = 1
	label.Font = props.Font or Ui.BODY
	label.TextColor3 = props.TextColor3 or Palette.white
	label.TextSize = props.TextSize or 16
	return label
end

function Ui.tween(
	object: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local tween = TweenService:Create(
		object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- Buttons squash on press and spring back.
function Ui.button(props: { [string]: any }, onClick: () -> ()): TextButton
	local button = Ui.new("TextButton", props)
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.Font = props.Font or Ui.TITLE
	button.TextColor3 = props.TextColor3 or Palette.white
	button.BackgroundColor3 = props.BackgroundColor3 or Palette.hudEdge
	Ui.corner(6).Parent = button
	local scale = Ui.new("UIScale", { Scale = 1, Parent = button })
	button.MouseButton1Down:Connect(function()
		Ui.tween(scale, 0.08, { Scale = 0.92 })
	end)
	local function release()
		Ui.tween(scale, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	button.Activated:Connect(onClick)
	return button
end

-- Flat single-colour icon: the uploaded image if Config.Icons has one, otherwise a plain shape.
function Ui.icon(kind: string, color: Color3, size: number): GuiObject
	local imageId = (Config.Icons :: any)[kind]
	if type(imageId) == "string" and imageId ~= "" then
		return Ui.new("ImageLabel", {
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Image = imageId,
			ImageColor3 = color,
		})
	end
	local holder = Ui.new("Frame", { Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1 })
	local function shape(props: { [string]: any }, radius: UDim?): Frame
		local f = Ui.new("Frame", props)
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
		f.Position = props.Position or UDim2.fromScale(0.5, 0.5)
		if radius then
			Ui.new("UICorner", { CornerRadius = radius, Parent = f })
		end
		f.Parent = holder
		return f
	end
	if kind == "oranges" then
		shape({ Size = UDim2.fromScale(0.86, 0.86) }, UDim.new(0.5, 0))
	elseif kind == "vitamin" then
		shape({ Size = UDim2.fromScale(0.5, 0.9), Rotation = 35 }, UDim.new(0.5, 0))
	elseif kind == "zest" then
		shape({ Size = UDim2.fromScale(0.62, 0.62), Rotation = 45 })
	elseif kind == "crates" then
		shape({ Size = UDim2.fromScale(0.8, 0.7) }, UDim.new(0.12, 0))
	elseif kind == "seeds" then
		shape({ Size = UDim2.fromScale(0.6, 0.6), Rotation = 45 }, UDim.new(0.5, 0))
		shape({ Size = UDim2.fromScale(0.42, 0.42), Rotation = 45, Position = UDim2.fromScale(0.62, 0.38) })
	elseif kind == "map" then
		for x = 0, 1 do
			for y = 0, 1 do
				shape(
					{ Size = UDim2.fromScale(0.38, 0.38), Position = UDim2.fromScale(0.29 + x * 0.42, 0.29 + y * 0.42) },
					UDim.new(0.15, 0)
				)
			end
		end
	elseif kind == "shop" then
		shape({ Size = UDim2.fromScale(0.8, 0.56), Position = UDim2.fromScale(0.5, 0.64) }, UDim.new(0.1, 0))
		local handle =
			shape({ Size = UDim2.fromScale(0.44, 0.4), Position = UDim2.fromScale(0.5, 0.32) }, UDim.new(0.5, 0))
		handle.BackgroundTransparency = 1
		Ui.new("UIStroke", { Color = color, Thickness = math.max(2, size // 12), Parent = handle })
	elseif kind == "settings" then
		for i = 0, 2 do
			shape(
				{ Size = UDim2.fromScale(0.86, 0.12), Position = UDim2.fromScale(0.5, 0.22 + i * 0.28) },
				UDim.new(0.5, 0)
			)
			shape(
				{ Size = UDim2.fromScale(0.2, 0.2), Position = UDim2.fromScale(0.3 + (i % 2) * 0.4, 0.22 + i * 0.28) },
				UDim.new(0.5, 0)
			)
		end
	else
		shape({ Size = UDim2.fromScale(0.7, 0.7) }, UDim.new(0.2, 0))
	end
	return holder
end

-- Keeps the UI a sensible size on phones, tablets, monitors and TVs while tap targets stay >= 44 px.
function Ui.autoScale(gui: ScreenGui)
	local scale = Ui.new("UIScale", { Parent = gui })
	local camera = workspace.CurrentCamera
	local function update()
		local size = camera.ViewportSize
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.92, 1.4)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
	return scale
end

return Ui
