--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > UIKit (ModuleScript)

	Original "simulator-style" UI kit: chunky rounded buttons, thick black outlines,
	bright gradients, big outlined FredokaOne text, bouncy tweens.
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local UIKit = {}

UIKit.Font = Enum.Font.FredokaOne
UIKit.Outline = Color3.fromRGB(22, 22, 32)

local RGB = Color3.fromRGB
UIKit.Colors = {
	Green = { RGB(130, 240, 95), RGB(40, 175, 45) },
	Blue = { RGB(110, 210, 255), RGB(35, 120, 235) },
	Red = { RGB(255, 115, 115), RGB(215, 40, 50) },
	Yellow = { RGB(255, 230, 95), RGB(245, 160, 20) },
	Purple = { RGB(205, 145, 255), RGB(125, 60, 225) },
	Pink = { RGB(255, 150, 215), RGB(235, 60, 150) },
	Orange = { RGB(255, 185, 90), RGB(240, 105, 30) },
	Cyan = { RGB(130, 255, 240), RGB(30, 190, 200) },
	Gray = { RGB(225, 225, 235), RGB(150, 150, 165) },
	Dark = { RGB(80, 80, 100), RGB(40, 40, 55) },
	White = { RGB(255, 255, 255), RGB(225, 230, 240) },
}

-- ── basics ────────────────────────────────────────────────────────────
function UIKit.Create(class, props)
	local inst = Instance.new(class)
	local parent = props and props.Parent
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" and k ~= "Children" then
				inst[k] = v
			end
		end
		if props.Children then
			for _, child in ipairs(props.Children) do
				child.Parent = inst
			end
		end
	end
	inst.Parent = parent
	return inst
end

function UIKit.Corner(parent, radius)
	return UIKit.Create("UICorner", { CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 16), Parent = parent })
end

function UIKit.Stroke(parent, thickness, color, border)
	return UIKit.Create("UIStroke", {
		Thickness = thickness or 3,
		Color = color or UIKit.Outline,
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = Enum.LineJoinMode.Round,
		Parent = parent,
	})
end

function UIKit.Gradient(parent, colors, rotation)
	return UIKit.Create("UIGradient", {
		Color = ColorSequence.new(colors[1], colors[2] or colors[1]),
		Rotation = rotation or 90,
		Parent = parent,
	})
end

function UIKit.Tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local soundCache = {}
function UIKit.PlaySound(name, volume)
	local id = GameConfig.Sounds[name]
	if not id then
		return
	end
	local sound = soundCache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Parent = SoundService
		soundCache[name] = sound
	end
	sound.Volume = volume or 0.5
	SoundService:PlayLocalSound(sound)
end

-- Big outlined text
function UIKit.Label(props)
	local label = UIKit.Create("TextLabel", {
		BackgroundTransparency = 1,
		Font = UIKit.Font,
		TextScaled = true,
		TextColor3 = props.TextColor3 or Color3.new(1, 1, 1),
		Text = props.Text or "",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center,
		ZIndex = props.ZIndex or 1,
		RichText = props.RichText or false,
		LayoutOrder = props.LayoutOrder or 0,
		Name = props.Name or "Label",
		Parent = props.Parent,
	})
	if props.StrokeThickness ~= 0 then
		UIKit.Stroke(label, props.StrokeThickness or 2.5, props.StrokeColor)
	end
	if props.MaxTextSize then
		UIKit.Create("UITextSizeConstraint", { MaxTextSize = props.MaxTextSize, Parent = label })
	end
	return label
end

-- Emoji or image icon. iconDef = { Emoji = "🎁", Image = "rbxassetid://123" }
function UIKit.Icon(props)
	local def = props.Icon or {}
	if def.Image and def.Image ~= "" and def.Image ~= "rbxassetid://0" then
		return UIKit.Create("ImageLabel", {
			BackgroundTransparency = 1,
			Image = def.Image,
			ScaleType = Enum.ScaleType.Fit,
			Size = props.Size or UDim2.fromScale(1, 1),
			Position = props.Position or UDim2.new(),
			AnchorPoint = props.AnchorPoint or Vector2.zero,
			ZIndex = props.ZIndex or 1,
			Parent = props.Parent,
		})
	end
	return UIKit.Label({
		Text = def.Emoji or "❔",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex,
		StrokeThickness = 0,
		Parent = props.Parent,
	})
end

-- Hover / press bounce on any GuiButton
function UIKit.Bouncy(button, hoverScale)
	local scale = button:FindFirstChild("BounceScale") or UIKit.Create("UIScale", { Name = "BounceScale", Parent = button })
	hoverScale = hoverScale or 1.07
	button.MouseEnter:Connect(function()
		UIKit.Tween(scale, 0.18, { Scale = hoverScale }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.Tween(scale, 0.08, { Scale = 0.9 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.Tween(scale, 0.25, { Scale = hoverScale }, Enum.EasingStyle.Back)
	end)
	return scale
end

-- Pop a GUI object (e.g. after a value changes)
function UIKit.Pop(obj, amount)
	local scale = obj:FindFirstChild("PopScale") or UIKit.Create("UIScale", { Name = "PopScale", Parent = obj })
	scale.Scale = amount or 1.2
	UIKit.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

-- Chunky gradient button. Returns button, label
function UIKit.Button(props)
	local colors = props.Colors or UIKit.Colors.Green
	local button = UIKit.Create("TextButton", {
		Name = props.Name or "Button",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = props.Size or UDim2.fromOffset(160, 56),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	local radius = props.CornerRadius or 14
	UIKit.Corner(button, radius)
	UIKit.Stroke(button, props.StrokeThickness or 4, UIKit.Outline, true)
	UIKit.Gradient(button, colors, 90)
	-- chunky 3D look: darker "lip" along the bottom edge
	local lip = UIKit.Create("Frame", {
		Name = "Lip",
		BackgroundColor3 = (colors[2] or colors[1]):Lerp(Color3.new(0, 0, 0), 0.35),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0.16, 2),
		ZIndex = button.ZIndex,
		Parent = button,
	})
	UIKit.Corner(lip, radius)
	-- glossy top shine (soft white band that fades downward)
	local shine = UIKit.Create("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Size = UDim2.new(1, -12, 0.38, 0),
		Position = UDim2.new(0, 6, 0, 4),
		ZIndex = button.ZIndex,
		Parent = button,
	})
	UIKit.Corner(shine, math.max(4, radius - 4))
	UIKit.Create("UIGradient", { Transparency = NumberSequence.new(0.1, 1), Rotation = 90, Parent = shine })
	local label = UIKit.Label({
		Text = props.Text or "",
		Size = UDim2.new(1, -14, 0.84, -6),
		Position = UDim2.fromOffset(7, 3),
		ZIndex = button.ZIndex + 1,
		StrokeThickness = 3,
		MaxTextSize = props.MaxTextSize,
		Parent = button,
	})
	UIKit.Bouncy(button)
	button.Activated:Connect(function()
		UIKit.PlaySound("Click", 0.4)
		if props.OnClick then
			props.OnClick(button)
		end
	end)
	-- allows recoloring later: UIKit.SetButtonColors(button, colors)
	button:SetAttribute("Kit", true)
	return button, label
end

function UIKit.SetButtonColors(button, colors)
	local g = button:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(colors[1], colors[2] or colors[1])
	end
	local lip = button:FindFirstChild("Lip")
	if lip then
		lip.BackgroundColor3 = (colors[2] or colors[1]):Lerp(Color3.new(0, 0, 0), 0.35)
	end
end

-- Red circular badge for counts / "NEW". Returns setter(textOrNil)
function UIKit.Badge(parent)
	local badge = UIKit.Create("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(30, 30),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 20,
		Visible = false,
		Parent = parent,
	})
	UIKit.Corner(badge, UDim.new(1, 0))
	UIKit.Stroke(badge, 2.5, UIKit.Outline, true)
	UIKit.Gradient(badge, UIKit.Colors.Red)
	local label = UIKit.Label({ Text = "", Size = UDim2.new(1, -6, 1, -6), Position = UDim2.fromOffset(3, 3), ZIndex = 21, StrokeThickness = 2, Parent = badge })
	local last = nil
	return function(text)
		if text == nil or text == "" or text == 0 then
			badge.Visible = false
			last = nil
			return
		end
		text = tostring(text)
		badge.Size = UDim2.fromOffset(#text > 2 and 46 or 30, 30)
		label.Text = text
		badge.Visible = true
		if last ~= text then
			UIKit.Pop(badge, 1.4)
		end
		last = text
	end
end

-- Progress bar. Returns { Frame, Set(alpha, text) }
function UIKit.ProgressBar(props)
	local bg = UIKit.Create("Frame", {
		Name = props.Name or "Progress",
		BackgroundColor3 = Color3.fromRGB(40, 40, 55),
		Size = props.Size or UDim2.fromOffset(300, 28),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	UIKit.Corner(bg, UDim.new(1, 0))
	UIKit.Stroke(bg, 3, UIKit.Outline, true)
	local fill = UIKit.Create("Frame", {
		Name = "Fill",
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		ZIndex = bg.ZIndex + 1,
		Parent = bg,
	})
	UIKit.Corner(fill, UDim.new(1, 0))
	UIKit.Gradient(fill, props.Colors or UIKit.Colors.Green)
	local text = UIKit.Label({ Text = "", Size = UDim2.new(1, -10, 1, -4), Position = UDim2.fromOffset(5, 2), ZIndex = bg.ZIndex + 2, Parent = bg })
	return {
		Frame = bg,
		Fill = fill,
		Set = function(alpha, label)
			alpha = math.clamp(alpha or 0, 0, 1)
			fill.Visible = alpha > 0.001
			fill.Size = UDim2.fromScale(math.max(alpha, 0.04), 1)
			text.Text = label or ""
		end,
	}
end

function UIKit.Scroll(props)
	local scroll = UIKit.Create("ScrollingFrame", {
		Name = props.Name or "Scroll",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = props.Horizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y,
		ScrollingDirection = props.Horizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = UIKit.Outline,
		Parent = props.Parent,
	})
	return scroll
end

-- Rounded white card with dark border (for list rows / tiles)
function UIKit.Card(props)
	local card = UIKit.Create("Frame", {
		Name = props.Name or "Card",
		BackgroundColor3 = props.Color or Color3.fromRGB(245, 247, 255),
		Size = props.Size or UDim2.fromOffset(200, 100),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	})
	UIKit.Corner(card, props.CornerRadius or 16)
	UIKit.Stroke(card, props.StrokeThickness or 3, UIKit.Outline, true)
	if props.Colors then
		UIKit.Gradient(card, props.Colors)
	end
	return card
end

-- ── Screen-size scaling ───────────────────────────────────────────────
local scaled = {}
local function screenScale()
	local camera = workspace.CurrentCamera
	local y = camera and camera.ViewportSize.Y or 900
	return math.clamp(y / 950, 0.5, 1.25)
end
UIKit.ScreenScale = screenScale

function UIKit.AutoScale(guiObject)
	local s = UIKit.Create("UIScale", { Name = "ScreenScale", Scale = screenScale(), Parent = guiObject })
	table.insert(scaled, s)
	return s
end

task.spawn(function()
	while not workspace.CurrentCamera do
		task.wait()
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local v = screenScale()
		for _, s in ipairs(scaled) do
			s.Scale = v
		end
	end)
end)

-- ── Pop-up panel ──────────────────────────────────────────────────────
-- props: Parent (ScreenGui), Title, Emoji, Size (UDim2 offset), Colors (title accent)
-- returns panel { Holder, Frame, Content, Open(), Close(), Toggle(), IsOpen(), OnOpen, OnClose }
function UIKit.Panel(props)
	local size = props.Size or UDim2.fromOffset(760, 520)
	local holder = UIKit.Create("Frame", {
		Name = (props.Name or props.Title or "Panel") .. "Holder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = size,
		Visible = false,
		ZIndex = 50,
		Parent = props.Parent,
	})
	UIKit.AutoScale(holder)
	local frame = UIKit.Create("Frame", {
		Name = "Panel",
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = holder,
	})
	UIKit.Corner(frame, 26)
	UIKit.Stroke(frame, 6, UIKit.Outline, true)
	UIKit.Gradient(frame, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(228, 234, 248) })
	local anim = UIKit.Create("UIScale", { Name = "AnimScale", Scale = 1, Parent = frame })

	-- title pill overlapping the top-left edge
	local titleBar = UIKit.Create("Frame", {
		Name = "Title",
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(46, 0),
		Size = UDim2.fromOffset(math.max(260, #(props.Title or "") * 22 + 110), 62),
		ZIndex = 60,
		Parent = frame,
	})
	UIKit.Corner(titleBar, 18)
	UIKit.Stroke(titleBar, 5, UIKit.Outline, true)
	UIKit.Gradient(titleBar, props.Colors or UIKit.Colors.Blue)
	UIKit.Label({ Text = props.Title or "", Size = UDim2.new(1, -86, 1, -12), Position = UDim2.fromOffset(76, 6), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 61, StrokeThickness = 3.5, Parent = titleBar })
	local iconCircle = UIKit.Create("Frame", {
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(30, 31),
		Size = UDim2.fromOffset(84, 84),
		ZIndex = 62,
		Parent = titleBar,
	})
	UIKit.Corner(iconCircle, UDim.new(1, 0))
	UIKit.Stroke(iconCircle, 5, UIKit.Outline, true)
	UIKit.Gradient(iconCircle, UIKit.Colors.White)
	UIKit.Icon({ Icon = { Emoji = props.Emoji or "⭐", Image = props.Image }, Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8), ZIndex = 63, Parent = iconCircle })

	-- red X close button (top-right)
	local panel = {}
	UIKit.Button({
		Name = "Close",
		Text = "X",
		Colors = UIKit.Colors.Red,
		Size = UDim2.fromOffset(62, 62),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -14, 0, 14),
		ZIndex = 70,
		CornerRadius = 16,
		Parent = frame,
		OnClick = function()
			panel.Close()
		end,
	})

	local content = UIKit.Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(22, 48),
		Size = UDim2.new(1, -44, 1, -66),
		ZIndex = 51,
		Parent = frame,
	})

	local isOpen = false
	local openEvent = Instance.new("BindableEvent")
	local closeEvent = Instance.new("BindableEvent")
	panel.Holder = holder
	panel.Frame = frame
	panel.Content = content
	panel.OnOpen = openEvent.Event
	panel.OnClose = closeEvent.Event
	function panel.IsOpen()
		return isOpen
	end
	function panel.Open()
		if isOpen then
			return
		end
		isOpen = true
		holder.Visible = true
		anim.Scale = 0.55
		UIKit.Tween(anim, 0.38, { Scale = 1 }, Enum.EasingStyle.Back)
		openEvent:Fire()
	end
	function panel.Close()
		if not isOpen then
			return
		end
		isOpen = false
		closeEvent:Fire()
		local t = UIKit.Tween(anim, 0.16, { Scale = 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		t.Completed:Connect(function()
			if not isOpen then
				holder.Visible = false
			end
		end)
	end
	function panel.Toggle()
		if isOpen then
			panel.Close()
		else
			panel.Open()
		end
	end
	return panel
end

-- Simple confirm dialog. onYes called if confirmed.
function UIKit.Confirm(screen, title, text, onYes)
	local panel = UIKit.Panel({ Parent = screen, Title = title, Emoji = "❓", Size = UDim2.fromOffset(520, 300), Colors = UIKit.Colors.Orange })
	panel.Holder.ZIndex = 200
	UIKit.Label({ Text = text, TextColor3 = UIKit.Outline, StrokeThickness = 0, Size = UDim2.new(1, 0, 0.55, 0), Position = UDim2.fromScale(0, 0.05), Parent = panel.Content })
	UIKit.Button({ Text = "Yes!", Colors = UIKit.Colors.Green, Size = UDim2.fromOffset(170, 60), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -10, 1, -6), Parent = panel.Content, OnClick = function()
		panel.Close()
		onYes()
	end })
	UIKit.Button({ Text = "No", Colors = UIKit.Colors.Red, Size = UDim2.fromOffset(170, 60), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 10, 1, -6), Parent = panel.Content, OnClick = function()
		panel.Close()
	end })
	panel.OnClose:Connect(function()
		task.delay(0.3, function()
			panel.Holder:Destroy()
		end)
	end)
	panel.Open()
	return panel
end

return UIKit
