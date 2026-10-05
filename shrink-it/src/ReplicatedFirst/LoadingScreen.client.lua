--[[
	📍 LOCATION: ReplicatedFirst > LoadingScreen (LocalScript)

	Loading screen like a real game: the camera slowly flies around YOUR map behind the UI,
	a big logo, a slim loading bar, then a PLAY button (any key / click / tap / controller works too).
]]

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local RGB = Color3.fromRGB
local TITLE_FONT = Enum.Font.LuckiestGuy
local FONT = Enum.Font.FredokaOne
local OUTLINE = RGB(28, 22, 40)

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

-- solid sky until the map is there, then it fades to show the flyover
local cover = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 1 }, gui)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(RGB(90, 170, 255), RGB(40, 90, 200)) }, cover)
-- cinematic shading top + bottom so the text always reads
local topShade = new("Frame", { Size = UDim2.fromScale(1, 0.4), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 2 }, gui)
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.35, 1) }, topShade)
local bottomShade = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.45), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, ZIndex = 2 }, gui)
new("UIGradient", { Rotation = -90, Transparency = NumberSequence.new(0.25, 1) }, bottomShade)

-- logo
local logo = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.28), Size = UDim2.fromOffset(900, 220), BackgroundTransparency = 1, ZIndex = 10 }, gui)
local logoScale = new("UIScale", {}, logo)
local _shadow = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 10), Size = UDim2.fromScale(1, 0.8), Font = TITLE_FONT, TextScaled = true, Text = "SHRINK IT!", TextColor3 = OUTLINE, TextTransparency = 0.35, ZIndex = 10 }, logo)
local title = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.8), Font = TITLE_FONT, TextScaled = true, Text = "SHRINK IT!", TextColor3 = Color3.new(1, 1, 1), ZIndex = 11 }, logo)
stroke(title, 9)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, RGB(255, 246, 150)), ColorSequenceKeypoint.new(0.5, RGB(255, 196, 30)), ColorSequenceKeypoint.new(1, RGB(255, 110, 20)) }) }, title)
local tag = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromOffset(420, 46), BackgroundColor3 = RGB(255, 70, 90), ZIndex = 12, Rotation = -2 }, logo)
new("UICorner", { CornerRadius = UDim.new(0, 10) }, tag)
stroke(tag, 4)
local tagText = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, -20, 1, -10), Position = UDim2.fromOffset(10, 5), Font = FONT, TextScaled = true, Text = "STEAL • SHRINK • RUN HOME", TextColor3 = Color3.new(1, 1, 1), ZIndex = 13 }, tag)
stroke(tagText, 3)

-- loading bar (slim) + status text
local barBack = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -70), Size = UDim2.fromOffset(520, 18), BackgroundColor3 = RGB(20, 20, 30), BackgroundTransparency = 0.2, ZIndex = 10 }, gui)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, barBack)
stroke(barBack, 3)
local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 11 }, barBack)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
new("UIGradient", { Color = ColorSequence.new(RGB(255, 220, 60), RGB(255, 140, 30)) }, fill)
local status = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -94), Size = UDim2.fromOffset(520, 26), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "Loading the world...", TextColor3 = Color3.new(1, 1, 1), ZIndex = 10 }, gui)
stroke(status, 2.5)

-- PLAY button (appears when ready)
local play = new("TextButton", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.fromOffset(300, 96), BackgroundColor3 = Color3.new(1, 1, 1), Text = "", AutoButtonColor = false, Visible = false, ZIndex = 20 }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 18) }, play)
stroke(play, 6)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(RGB(140, 255, 90), RGB(40, 190, 50)) }, play)
local lip = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.18, 0), BackgroundColor3 = RGB(25, 120, 35), BorderSizePixel = 0, ZIndex = 20 }, play)
new("UICorner", { CornerRadius = UDim.new(0, 18) }, lip)
local playText = new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0.8, 0), Font = TITLE_FONT, TextScaled = true, Text = "PLAY", TextColor3 = Color3.new(1, 1, 1), ZIndex = 21 }, play)
new("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 4) }, playText)
stroke(playText, 5)
local playScale = new("UIScale", {}, play)
local hint = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -28), Size = UDim2.fromOffset(400, 24), BackgroundTransparency = 1, Font = FONT, TextScaled = true, Text = "or press any key", TextColor3 = RGB(230, 230, 240), Visible = false, ZIndex = 10 }, gui)
stroke(hint, 2)

-- fit to the screen
local function fit()
	local cam = workspace.CurrentCamera
	local w = cam and cam.ViewportSize.X or 1280
	local s = math.clamp(w / 1400, 0.42, 1.1)
	for _, o in ipairs({ logo, barBack, status, play, hint }) do
		local sc = o:FindFirstChild("Fit") or new("UIScale", { Name = "Fit" }, o)
		sc.Scale = s
	end
end
fit()

-- camera flyover around the base once the map exists
local camera = workspace.CurrentCamera
local flying = false
local orbitCenter = Vector3.new(0, 0, -120)
local t0 = os.clock()
local conn = RunService.RenderStepped:Connect(function()
	local t = os.clock() - t0
	logoScale.Scale = 1 + math.sin(t * 1.8) * 0.025
	logo.Rotation = math.sin(t * 1.1) * 1.2
	playScale.Scale = 1 + math.sin(t * 4) * 0.04
	if flying then
		local a = t * 0.06
		local eye = orbitCenter + Vector3.new(math.cos(a) * 230, 95 + math.sin(t * 0.3) * 10, math.sin(a) * 230)
		camera.CFrame = CFrame.lookAt(eye, orbitCenter + Vector3.new(0, 10, 0))
	end
end)
task.spawn(function()
	local map = workspace:WaitForChild("ShrinkItMap", 60)
	if not map then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	flying = true
	TweenService:Create(cover, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
end)

-- progress
local shown = 0
local start = os.clock()
while true do
	local ready = game:IsLoaded() and player:GetAttribute("ClientReady") == true
	local target = ready and 1 or math.clamp(0.1 + (game:IsLoaded() and 0.5 or 0) + (os.clock() - start) / 40 - ContentProvider.RequestQueueSize * 0.002, 0.05, 0.95)
	shown += (target - shown) * 0.15
	fill.Size = UDim2.fromScale(math.max(shown, 0.04), 1)
	status.Text = (game:IsLoaded() and "Getting your plot ready..." or "Loading the world...") .. "  " .. math.floor(shown * 100 + 0.5) .. "%"
	if (ready and shown > 0.985) or os.clock() - start > 45 then
		break
	end
	task.wait(0.05)
end
barBack.Visible = false
status.Visible = false
play.Visible = true
hint.Visible = true
playScale.Scale = 0.3

-- wait for PLAY / any key / click / tap / controller button
local pressed = Instance.new("BindableEvent")
play.Activated:Connect(function()
	pressed:Fire()
end)
local inputConn = UserInputService.InputBegan:Connect(function(input)
	local kind = input.UserInputType
	if kind == Enum.UserInputType.Keyboard or kind.Name:find("Gamepad") then
		pressed:Fire()
	end
end)
pressed.Event:Wait()
inputConn:Disconnect()

-- hand the camera back and fade out
flying = false
camera.CameraType = Enum.CameraType.Custom
local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
if hum then
	camera.CameraSubject = hum
end
local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad)
for _, d in ipairs(gui:GetDescendants()) do
	if d:IsA("GuiObject") then
		local props = { BackgroundTransparency = 1 }
		if d:IsA("TextLabel") then
			props.TextTransparency = 1
		end
		TweenService:Create(d, info, props):Play()
	elseif d:IsA("UIStroke") then
		TweenService:Create(d, info, { Transparency = 1 }):Play()
	end
end
task.wait(0.55)
conn:Disconnect()
gui:Destroy()
