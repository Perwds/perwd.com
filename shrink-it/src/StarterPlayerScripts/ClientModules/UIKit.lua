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
UIKit.Outline = Color3.fromRGB(30, 28, 40) -- dark outline (chunky cartoon style)
-- panel theme: bright sky-blue panels, deeper blue inner cards, red square X
UIKit.Theme = {
	Body = { Color3.fromRGB(100, 205, 248), Color3.fromRGB(62, 172, 232) },
	Header = { Color3.fromRGB(120, 215, 252), Color3.fromRGB(80, 188, 240) },
	Card = Color3.fromRGB(38, 128, 200),
}

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
		sound.SoundGroup = SoundService:FindFirstChild("SFX")
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

-- ── 3D previews (real object models rendered into the UI) ─────────────
local ObjectModels = require(Shared:WaitForChild("ObjectModels"))
local RarityConfig = require(Shared.Config.RarityConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local previewTemplates = {}

-- props: Id, Variant, Size, Position, AnchorPoint, ZIndex, LayoutOrder, Parent
function UIKit.ModelPreview(props)
	local vf = UIKit.Create("ViewportFrame", {
		Name = "Preview",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromOffset(64, 64),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1.4, -0.6),
		Parent = props.Parent,
	})
	local template = previewTemplates[props.Id]
	if template == nil then
		-- your own 3D model (ReplicatedStorage > ShrinkableTemplates) wins over the built-in one
		local custom = ReplicatedStorage:FindFirstChild("ShrinkableTemplates")
		custom = custom and custom:FindFirstChild(props.Id)
		if custom then
			local clone = custom:Clone()
			if clone:IsA("BasePart") then
				local wrap = Instance.new("Model")
				clone.Parent = wrap
				clone = wrap
			end
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("LuaSourceContainer") then
					d:Destroy()
				end
			end
			template = clone
		else
			local ok, built = pcall(ObjectModels.Build, props.Id)
			template = ok and built or false
		end
		previewTemplates[props.Id] = template
	end
	if not template then
		local def = ObjectConfig.Get(props.Id)
		UIKit.Label({ Text = def and def.Emoji or "📦", StrokeThickness = 0, Size = UDim2.fromScale(1, 1), Parent = vf })
		return vf
	end
	local model = template:Clone()
	model.Parent = vf
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = vf
	vf.CurrentCamera = camera
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(camera.FieldOfView / 2)) * 1.02
	camera.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0.55, 0.42, -1).Unit * distance, cf.Position)
	-- variants tint the render (golden, diamond, rainbow, cosmic)
	local variant = RarityConfig.GetVariant(props.Variant)
	if variant.Color then
		vf.ImageColor3 = variant.Color:Lerp(Color3.new(1, 1, 1), 0.45)
	end
	return vf
end

-- ── Screen-size scaling ───────────────────────────────────────────────
local scaled = {}
UIKit.UIScale = 0.82 -- overall size of the whole UI (smaller = more of the game visible)
local function screenScale()
	local camera = workspace.CurrentCamera
	local y = camera and camera.ViewportSize.Y or 900
	return math.clamp(y / 950, 0.45, 1.15) * UIKit.UIScale
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
-- Lego-style studs over a panel background. animated = the studs slowly slide (shops).
local movingStuds = {}
function UIKit.Studs(frame, animated, radius, onDark)
	local STEP, DOT = 44, 24
	local clip = UIKit.Create("Frame", {
		Name = "Studs",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = 50,
		Parent = frame,
	})
	UIKit.Corner(clip, radius or 26)
	local grid = UIKit.Create("Frame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-STEP, -STEP),
		Size = UDim2.new(1, STEP * 2, 1, STEP * 2),
		ZIndex = 50,
		Parent = clip,
	})
	UIKit.Create("UIGridLayout", { CellSize = UDim2.fromOffset(DOT, DOT), CellPadding = UDim2.fromOffset(STEP - DOT, STEP - DOT), Parent = grid })
	local TextureConfig = require(game:GetService("ReplicatedStorage").Shared.Config.TextureConfig)
	local custom = TextureConfig.UI.PanelStuds
	if animated and TextureConfig.Has(TextureConfig.UI.ShopBackground) then
		custom = TextureConfig.UI.ShopBackground
	end
	if TextureConfig.Has(custom) then
		-- your own tiled picture instead of the drawn studs
		grid:ClearAllChildren()
		local tile = TextureConfig.UI.PanelStudsTile or 64
		UIKit.Create("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = custom, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(tile, tile), ImageTransparency = 0.6, ZIndex = 50, Parent = grid })
		if animated then
			table.insert(movingStuds, { Grid = grid, Frame = frame, Step = tile })
		end
		return clip
	end
	local size = frame.AbsoluteSize.Magnitude > 0 and frame.AbsoluteSize or Vector2.new(1000, 760)
	local count = math.ceil((size.X + STEP * 3) / STEP) * math.ceil((size.Y + STEP * 3) / STEP)
	for _ = 1, math.min(count, 900) do
		local stud = UIKit.Create("Frame", { BackgroundColor3 = onDark and Color3.new(1, 1, 1) or Color3.fromRGB(70, 90, 140), BackgroundTransparency = onDark and 0.93 or 0.9, ZIndex = 50, Parent = grid })
		UIKit.Corner(stud, UDim.new(1, 0))
		UIKit.Create("UIStroke", { Thickness = 2, Color = onDark and Color3.new(0, 0, 0) or Color3.fromRGB(40, 50, 90), Transparency = onDark and 0.7 or 0.82, Parent = stud })
	end
	if animated then
		table.insert(movingStuds, { Grid = grid, Frame = frame, Step = STEP })
	end
	return clip
end

task.spawn(function()
	local RunService = game:GetService("RunService")
	RunService.RenderStepped:Connect(function()
		if #movingStuds == 0 then
			return
		end
		local t = os.clock() * 14
		for _, m in ipairs(movingStuds) do
			if m.Frame.Parent and m.Frame.Visible then
				local o = t % m.Step
				m.Grid.Position = UDim2.fromOffset(-m.Step + o, -m.Step + o)
			end
		end
	end)
end)

function UIKit.Panel(props)
	-- every menu uses the same chunky STONE frame (gems in the corners, stone title plaque, red X)
	local size = (props.Size or UDim2.fromOffset(760, 520)) + UDim2.fromOffset(40, 40)
	local holder = UIKit.Create("Frame", {
		Name = (props.Name or props.Title or "Panel") .. "Holder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
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
	local anim = UIKit.Create("UIScale", { Name = "AnimScale", Scale = 1, Parent = frame })
	local panel = {}
	UIKit.StoneFrame(frame, { Seed = #(props.Title or "") * 7 + 3 })
	-- (no stud grid inside: the stone frame is busy enough, and it saves thousands of UI objects)
	UIKit.TitlePlaque(frame, props.Title or "", props.Emoji)

	UIKit.Button({
		Name = "Close",
		Text = "X",
		Colors = UIKit.Colors.Red,
		Size = UDim2.fromOffset(54, 54),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -10, 0, 10),
		ZIndex = 72,
		CornerRadius = 12,
		Parent = frame,
		OnClick = function()
			panel.Close()
		end,
	})

	local content = UIKit.Create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(36, 52),
		Size = UDim2.new(1, -72, 1, -88),
		ZIndex = 51,
		Parent = frame,
	})
	return UIKit._FinishPanel(holder, content, anim, panel)
end

-- ── stone frame pieces (shared by panels, the shop, announcements) ─────────
UIKit.Stone = {
	Light = Color3.fromRGB(150, 150, 160),
	Mid = Color3.fromRGB(112, 112, 124),
	Dark = Color3.fromRGB(78, 78, 90),
	Edge = Color3.fromRGB(34, 34, 44),
	Inner = Color3.fromRGB(48, 50, 62),
}
UIKit.GemColors = {
	Color3.fromRGB(60, 220, 160), -- emerald
	Color3.fromRGB(255, 160, 40), -- amber
	Color3.fromRGB(170, 100, 255), -- amethyst
	Color3.fromRGB(80, 160, 255), -- sapphire
	Color3.fromRGB(255, 80, 120), -- ruby
}

-- a faceted gem (diamond shape with a shine), centered on pos
function UIKit.Gem(parent, color, size, pos, zIndex, rotation)
	local z = zIndex or 70
	local holder = UIKit.Create("Frame", { Name = "Gem", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(size, size), Rotation = rotation or 0, ZIndex = z, Parent = parent })
	local body = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.72, 0.72), Rotation = 45, ZIndex = z, Parent = holder })
	UIKit.Corner(body, math.max(3, size // 8))
	UIKit.Stroke(body, math.max(2, size // 16), UIKit.Outline, true)
	UIKit.Create("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.55)), ColorSequenceKeypoint.new(0.5, color), ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.35)) }), Rotation = 45, Parent = body })
	local facet = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.65, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.42, 0.42), Rotation = 45, ZIndex = z, Parent = holder })
	UIKit.Corner(facet, 3)
	local shine = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.36, 0.34), Size = UDim2.fromScale(0.14, 0.14), ZIndex = z, Parent = holder })
	UIKit.Corner(shine, UDim.new(1, 0))
	return holder
end

-- grey stone border made of chunky rocks + a dark inner panel; returns the inner frame
function UIKit.StoneFrame(frame, opts)
	opts = opts or {}
	local S = UIKit.Stone
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	UIKit.Corner(frame, 20)
	UIKit.Stroke(frame, 6, S.Edge, true)
	UIKit.Gradient(frame, { S.Light, S.Dark }, 90)
	local rng = Random.new(opts.Seed or 7)
	local z = frame.ZIndex
	-- rocks around the edge (drawn over the border band)
	local rocks = UIKit.Create("Frame", { Name = "Rocks", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z, Parent = frame })
	local function rock(x, y, w, h)
		local r = UIKit.Create("Frame", { BackgroundColor3 = S.Mid:Lerp(rng:NextNumber() < 0.5 and S.Light or S.Dark, rng:NextNumber(0.1, 0.6)), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(x, 0, y, 0), Size = UDim2.fromOffset(w, h), Rotation = rng:NextNumber(-6, 6), ZIndex = z, Parent = rocks })
		UIKit.Corner(r, 9)
		UIKit.Stroke(r, 3, S.Edge, true)
		local top = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0, Size = UDim2.new(1, -8, 0.35, 0), Position = UDim2.fromOffset(4, 3), ZIndex = z, Parent = r })
		UIKit.Corner(top, 6)
	end
	local edge = 0.012
	for i = 0, 13 do
		local x = (i + 0.5) / 14
		rock(x, edge + 0.01, rng:NextInteger(54, 82), rng:NextInteger(22, 30))
		rock(x, 1 - edge - 0.01, rng:NextInteger(54, 82), rng:NextInteger(22, 30))
	end
	for i = 0, 7 do
		local y = (i + 0.5) / 8
		rock(edge + 0.006, y, rng:NextInteger(22, 30), rng:NextInteger(50, 74))
		rock(1 - edge - 0.006, y, rng:NextInteger(22, 30), rng:NextInteger(50, 74))
	end
	-- dark inner panel
	local inner = UIKit.Create("Frame", { Name = "Inner", BackgroundColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(22, 22), Size = UDim2.new(1, -44, 1, -44), ZIndex = z + 1, Parent = frame })
	UIKit.Corner(inner, 12)
	UIKit.Stroke(inner, 4, S.Edge, true)
	UIKit.Gradient(inner, { S.Inner:Lerp(Color3.new(1, 1, 1), 0.06), S.Inner:Lerp(Color3.new(0, 0, 0), 0.15) }, 90)
	-- gems wedged into the frame
	local G = UIKit.GemColors
	UIKit.Gem(frame, G[1], 46, UDim2.new(0, 34, 0, 26), z + 20, -12)
	UIKit.Gem(frame, G[1], 22, UDim2.new(0, 64, 0, 18), z + 20, 10)
	UIKit.Gem(frame, G[2], 54, UDim2.new(0, 6, 0.62, 0), z + 20, -18)
	UIKit.Gem(frame, G[2], 20, UDim2.new(0, 14, 0.4, 0), z + 20, 8)
	UIKit.Gem(frame, G[3], 56, UDim2.new(1, -4, 0.7, 0), z + 20, 15)
	UIKit.Gem(frame, G[3], 22, UDim2.new(1, -14, 0.45, 0), z + 20, -10)
	UIKit.Gem(frame, G[4], 34, UDim2.new(0.25, 0, 1, -8), z + 20, 20)
	UIKit.Gem(frame, G[4], 30, UDim2.new(0.75, 0, 1, -8), z + 20, -14)
	return inner
end

-- stone plaque with the title, sitting on the top edge of a panel
function UIKit.TitlePlaque(frame, title, emoji)
	local S = UIKit.Stone
	local width = math.max(260, #title * 26 + (emoji and 120 or 80))
	local plaque = UIKit.Create("Frame", { Name = "Title", BackgroundColor3 = Color3.new(1, 1, 1), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(width, 66), ZIndex = 74, Parent = frame })
	UIKit.Corner(plaque, 14)
	UIKit.Stroke(plaque, 5, S.Edge, true)
	UIKit.Gradient(plaque, { S.Light:Lerp(Color3.new(1, 1, 1), 0.1), S.Dark }, 90)
	local bevel = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, Size = UDim2.new(1, -16, 0.4, 0), Position = UDim2.fromOffset(8, 5), ZIndex = 74, Parent = plaque })
	UIKit.Corner(bevel, 8)
	local left = 18
	if emoji then
		UIKit.Icon({ Icon = { Emoji = emoji }, Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(16, 10), ZIndex = 76, Parent = plaque })
		left = 70
	end
	UIKit.Label({ Text = title, Size = UDim2.new(1, -(left + 18), 1, -14), Position = UDim2.fromOffset(left, 7), ZIndex = 76, StrokeThickness = 4, Parent = plaque })
	return plaque
end

-- gradient bar with wide diagonal stripes and a big outlined title (shop section headers)
function UIKit.StripeBar(props)
	local colors = props.Colors or UIKit.Colors.Orange
	local bar = UIKit.Create("Frame", { Name = props.Name or "StripeBar", BackgroundColor3 = Color3.new(1, 1, 1), Size = props.Size or UDim2.new(1, 0, 0, 62), Position = props.Position or UDim2.new(), LayoutOrder = props.LayoutOrder or 0, ZIndex = props.ZIndex or 3, ClipsDescendants = true, Parent = props.Parent })
	UIKit.Corner(bar, 10)
	UIKit.Stroke(bar, 4, colors[2]:Lerp(Color3.new(0, 0, 0), 0.45), true)
	UIKit.Gradient(bar, { colors[1], colors[2] }, 90)
	local stripes = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = bar.ZIndex, Parent = bar })
	local kps = {}
	local bands = 9
	for i = 0, bands - 1 do
		local a = (i % 2 == 0) and 0.8 or 1
		table.insert(kps, NumberSequenceKeypoint.new(i == 0 and 0 or i / bands + 0.001, a))
		table.insert(kps, NumberSequenceKeypoint.new((i + 1) / bands, a))
	end
	UIKit.Create("UIGradient", { Transparency = NumberSequence.new(kps), Rotation = 25, Parent = stripes })
	local label = UIKit.Label({ Text = props.Text or "", Size = UDim2.new(1, -24, 1, -10), Position = UDim2.fromOffset(12, 4), ZIndex = bar.ZIndex + 1, StrokeThickness = 4, Parent = bar })
	label.TextColor3 = Color3.new(1, 1, 1)
	UIKit.Create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 230), colors[1]:Lerp(Color3.new(1, 1, 1), 0.5)), Rotation = 90, Parent = label })
	return bar, label
end

-- comic-book halftone dots fading in from one side (cards)
function UIKit.Halftone(frame, color, fromRight)
	local holder = UIKit.Create("Frame", { Name = "Halftone", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = frame.ZIndex, ClipsDescendants = true, Parent = frame })
	local cols, rows = 7, 3
	for cx = 0, cols - 1 do
		local t = cx / (cols - 1)
		local s = 0.05 + (fromRight == false and (1 - t) or t) * 0.11
		for cy = 0, rows - 1 do
			local d = UIKit.Create("Frame", { BackgroundColor3 = color or Color3.new(1, 1, 1), BackgroundTransparency = 0.78, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((cx + 0.5 + (cy % 2) * 0.5) / cols, (cy + 0.5) / rows), Size = UDim2.fromScale(s, s), SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = frame.ZIndex, Parent = holder })
			UIKit.Corner(d, UDim.new(1, 0))
		end
	end
	return holder
end

UIKit.OpenPanels = {} -- every panel ever built (used to close the others when one opens)
-- Open/close behaviour shared by both panel styles.
function UIKit._FinishPanel(holder, content, anim, panel)
	local frame = holder:FindFirstChild("Panel")
	local isOpen = false
	local openEvent = Instance.new("BindableEvent")
	local closeEvent = Instance.new("BindableEvent")
	panel.Holder = holder
	panel.Frame = frame
	panel.Content = content
	panel.OnOpen = openEvent.Event
	panel.OnClose = closeEvent.Event
	table.insert(UIKit.OpenPanels, panel)
	function panel.IsOpen()
		return isOpen
	end
	function panel.Open()
		if isOpen then
			return
		end
		-- only one menu at a time: opening this one closes every other open menu
		for _, other in ipairs(UIKit.OpenPanels) do
			if other ~= panel and other.IsOpen() then
				other.Close()
			end
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

-- (kept for old callers: every panel is the stone style now)
UIKit.PanelBody = UIKit.Stone.Inner
UIKit.PanelCard = Color3.fromRGB(66, 70, 88)
function UIKit._HeaderPanel(props)
	return UIKit.Panel(props)
end

-- Big chunky label with a thick black outline (the "Steal an Egg" look).
function UIKit.Title(props)
	props.StrokeThickness = props.StrokeThickness or 3.5
	return UIKit.Label(props)
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
