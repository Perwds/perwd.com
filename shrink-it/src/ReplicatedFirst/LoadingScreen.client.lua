--[[
	📍 LOCATION: ReplicatedFirst > LoadingScreen (LocalScript)

	Custom loading screen: animated sky, bouncing "SHRINK IT!" logo, falling mystery boxes, tips and
	a progress bar. When the game has loaded it shows "PRESS ANY BUTTON TO PLAY" (any key, click,
	tap or controller button), then fades away.
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local RGB = Color3.fromRGB
local FONT = Enum.Font.FredokaOne
local OUTLINE = RGB(24, 44, 78)

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
ReplicatedFirst:RemoveDefaultLoadingScreen()

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end
local function stroke(parent, thickness, color)
	return new("UIStroke", { Thickness = thickness, Color = color or OUTLINE, ApplyStrokeMode = parent:IsA("TextLabel") and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border }, parent)
end

-- sky
local bg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, gui)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, RGB(70, 150, 255)), ColorSequenceKeypoint.new(0.65, RGB(130, 210, 255)), ColorSequenceKeypoint.new(1, RGB(190, 240, 255)) }) }, bg)
-- soft sunburst behind the logo
local burst = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.9, 0.9), SizeConstraint = Enum.SizeConstraint.RelativeYY, BackgroundTransparency = 1 }, bg)
local rays = {}
for i = 0, 11 do
	local ray = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.09, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0, Rotation = i * 15 }, burst)
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }) }, ray)
	table.insert(rays, ray)
end
-- green hills at the bottom
for i, hill in ipairs({ { 0.15, 0.95, 0.7, RGB(110, 210, 70) }, { 0.6, 1.0, 0.85, RGB(90, 195, 60) }, { 0.95, 0.97, 0.6, RGB(120, 220, 80) } }) do
	local h = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(hill[1], hill[2] - 0.12), Size = UDim2.fromScale(hill[3], hill[3]), SizeConstraint = Enum.SizeConstraint.RelativeXX, BackgroundColor3 = hill[4], BorderSizePixel = 0, ZIndex = 2 + i % 2 }, bg)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, h)
	stroke(h, 4)
end

-- falling mystery boxes
local boxes = {}
local BOX_COLORS = { RGB(255, 200, 40), RGB(255, 90, 120), RGB(90, 200, 255), RGB(170, 110, 255), RGB(120, 230, 90) }
for i = 1, 14 do
	local b = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = BOX_COLORS[(i % #BOX_COLORS) + 1], BorderSizePixel = 0, ZIndex = 1 }, bg)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, b)
	stroke(b, 3)
	local q = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = FONT, TextScaled = true, Text = "?", TextColor3 = Color3.new(1, 1, 1), ZIndex = 1 }, b)
	stroke(q, 2)
	table.insert(boxes, { Frame = b, X = math.random(), Y = math.random() * 1.2 - 0.2, Speed = 0.05 + math.random() * 0.08, Spin = (math.random() - 0.5) * 120, Size = 30 + math.random(0, 30) })
end

-- logo
local logoHolder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.33), Size = UDim2.fromOffset(760, 200), BackgroundTransparency = 1, ZIndex = 10 }, bg)
local logoScale = new("UIScale", {}, logoHolder)
local logo = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.78), Font = FONT, TextScaled = true, Text = "SHRINK IT!", TextColor3 = Color3.new(1, 1, 1), ZIndex = 11 }, logoHolder)
stroke(logo, 8)
local logoGradient = new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, RGB(255, 245, 140)), ColorSequenceKeypoint.new(0.55, RGB(255, 190, 40)), ColorSequenceKeypoint.new(1, RGB(255, 120, 30)) }) }, logo)
local sub = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0, 0.78), Size = UDim2.fromScale(1, 0.22), Font = FONT, TextScaled = true, Text = "Shrink it. Grab it. Run home!", TextColor3 = Color3.new(1, 1, 1), ZIndex = 11 }, logoHolder)
stroke(sub, 4)

-- loading bar + tip
local barHolder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.64), Size = UDim2.fromOffset(560, 40), BackgroundColor3 = RGB(30, 50, 90), ZIndex = 10 }, bg)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, barHolder)
stroke(barHolder, 5)
local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 11 }, barHolder)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
new("UIGradient", { Color = ColorSequence.new(RGB(130, 255, 90), RGB(40, 200, 60)) }, fill)
local barText = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = FONT, TextScaled = true, Text = "Loading...", TextColor3 = Color3.new(1, 1, 1), ZIndex = 12 }, barHolder)
new("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, barText)
stroke(barText, 3)
local TIPS = {
	"Tip: Shrink a box with your ray, then carry it home before the chaser catches you!",
	"Tip: Bigger boxes are worth more, but they slow you down.",
	"Tip: Train on your treadmill to run faster.",
	"Tip: Mutations like Shiny and Prism multiply an item's income!",
	"Tip: Dr. Grow lands at the end of the map every 30 minutes. Team up!",
	"Tip: Customize your name plate in the Custom menu.",
}
local tip = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.71), Size = UDim2.fromOffset(820, 30), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = TIPS[math.random(#TIPS)], TextColor3 = Color3.new(1, 1, 1), ZIndex = 10 }, bg)
stroke(tip, 3)
local press = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.84), Size = UDim2.fromOffset(700, 64), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "PRESS ANY BUTTON TO PLAY", TextColor3 = Color3.new(1, 1, 1), Visible = false, ZIndex = 10 }, bg)
stroke(press, 5)
local pressScale = new("UIScale", {}, press)

-- keep everything readable on small screens
local function fit()
	local cam = workspace.CurrentCamera
	local w = cam and cam.ViewportSize.X or 1280
	local s = math.clamp(w / 1280, 0.45, 1.2)
	for _, o in ipairs({ logoHolder, barHolder, tip, press }) do
		local sc = o:FindFirstChild("FitScale") or new("UIScale", { Name = "FitScale" }, o)
		sc.Scale = s
	end
end
fit()

-- animation
local t0 = os.clock()
local conn = RunService.RenderStepped:Connect(function(dt)
	local t = os.clock() - t0
	burst.Rotation = (t * 8) % 360
	logoScale.Scale = 1 + math.sin(t * 2.2) * 0.04
	logo.Rotation = math.sin(t * 1.3) * 2
	logoGradient.Offset = Vector2.new(0, math.sin(t * 2) * 0.08)
	pressScale.Scale = 1 + math.sin(t * 5) * 0.06
	press.TextTransparency = 0.15 + math.sin(t * 5) * 0.15
	for _, b in ipairs(boxes) do
		b.Y += b.Speed * dt
		if b.Y > 1.15 then
			b.Y = -0.1
			b.X = math.random()
		end
		b.Frame.Position = UDim2.fromScale(b.X, b.Y)
		b.Frame.Size = UDim2.fromOffset(b.Size, b.Size)
		b.Frame.Rotation = (b.Frame.Rotation + b.Spin * dt) % 360
	end
end)

-- progress: assets downloading + the game's own UI being built
local shown = 0
local start = os.clock()
local tipAt = os.clock()
while true do
	local queue = ContentProvider.RequestQueueSize
	local ready = game:IsLoaded() and player:GetAttribute("ClientReady") == true
	local target = ready and 1 or math.clamp(0.15 + (game:IsLoaded() and 0.45 or 0) + (os.clock() - start) / 40 - queue * 0.002, 0.05, 0.95)
	shown += (target - shown) * 0.15
	fill.Size = UDim2.fromScale(math.max(shown, 0.06), 1)
	barText.Text = string.format("Loading... %d%%", math.floor(shown * 100 + 0.5))
	if os.clock() - tipAt > 4 then
		tipAt = os.clock()
		tip.Text = TIPS[math.random(#TIPS)]
	end
	if (ready and shown > 0.985) or os.clock() - start > 45 then
		break
	end
	task.wait(0.05)
end
fill.Size = UDim2.fromScale(1, 1)
barText.Text = "Ready!"
press.Visible = true

-- wait for any key / click / tap / controller button
local pressed = Instance.new("BindableEvent")
local inputConn = UserInputService.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.Keyboard or kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.MouseButton2
		or kind == Enum.UserInputType.Touch or kind.Name:find("Gamepad") then
		pressed:Fire()
	end
end)
pressed.Event:Wait()
inputConn:Disconnect()

-- fade out
local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
TweenService:Create(bg, info, { BackgroundTransparency = 1 }):Play()
TweenService:Create(logoScale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 }):Play()
for _, d in ipairs(bg:GetDescendants()) do
	if d:IsA("GuiObject") and d ~= logoHolder then
		local props = { BackgroundTransparency = 1 }
		if d:IsA("TextLabel") then
			props.TextTransparency = 1
		end
		TweenService:Create(d, info, props):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, info, { Transparency = 1 }):Play()
	end
end
task.wait(0.65)
conn:Disconnect()
gui:Destroy()
