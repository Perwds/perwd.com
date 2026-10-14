--!strict
-- Top-down view of the whole board for planning. View only: buying still happens on foot.

local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(ReplicatedStorage.Shared.Palette)
local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)
local TreeBoard = require(script.Parent.TreeBoard)

local OverviewCam = {}

local player = Players.LocalPlayer
local open = false
local savedType: Enum.CameraType = Enum.CameraType.Custom
local savedCFrame = CFrame.identity
local height = 0
local focus = Vector3.zero
local marker: BillboardGui?
local closeButton: TextButton?
local connections: { RBXScriptConnection } = {}

local GRID = Config.Grid
local BOARD_W = GRID.zonesWide * GRID.zoneCells * GRID.cell
local BOARD_H = GRID.zonesHigh * GRID.zoneCells * GRID.cell

local function fitHeight(): number
	local camera = workspace.CurrentCamera
	local aspect = camera.ViewportSize.X / math.max(1, camera.ViewportSize.Y)
	local halfV = math.rad(camera.FieldOfView / 2)
	local needV = (BOARD_H / 2 + 30) / math.tan(halfV)
	local needH = (BOARD_W / 2 + 30) / (math.tan(halfV) * aspect)
	return math.max(needV, needH)
end

local function cameraCFrame(): CFrame
	return CFrame.new(focus + Vector3.new(0, height, 0)) * CFrame.Angles(-math.pi / 2, 0, 0)
end

local function controls(enabled: boolean)
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
	end)
	if ok and module then
		local c = module:GetControls()
		if enabled then
			c:Enable()
		else
			c:Disable()
		end
	end
end

function OverviewCam.close()
	if not open then
		return
	end
	open = false
	for _, c in connections do
		c:Disconnect()
	end
	connections = {}
	if marker then
		marker:Destroy()
		marker = nil
	end
	if closeButton then
		closeButton:Destroy()
		closeButton = nil
	end
	TreeBoard.setTextDistance(160)
	local camera = workspace.CurrentCamera
	local tween = TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { CFrame = savedCFrame })
	tween:Play()
	tween.Completed:Wait()
	camera.CameraType = savedType
	controls(true)
end

function OverviewCam.open()
	if open then
		return
	end
	open = true
	local camera = workspace.CurrentCamera
	savedType = camera.CameraType
	savedCFrame = camera.CFrame
	camera.CameraType = Enum.CameraType.Scriptable
	controls(false)
	height = fitHeight()
	focus = Vector3.zero
	TreeBoard.setTextDistance(0)
	TweenService:Create(camera, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { CFrame = cameraCFrame() }):Play()

	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head then
		marker = Ui.new("BillboardGui", {
			Size = UDim2.fromOffset(60, 28),
			AlwaysOnTop = true,
			Adornee = head,
			StudsOffsetWorldSpace = Vector3.new(0, 6, 0),
			Parent = Hud.gui(),
		})
		Ui.text({
			Text = "YOU",
			Font = Ui.TITLE,
			TextSize = 22,
			TextColor3 = Palette.gold,
			TextStrokeTransparency = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = marker,
		})
	end
	closeButton = Ui.button({
		Text = "CLOSE MAP",
		TextSize = 18,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(160, Ui.MIN_TAP),
		BackgroundColor3 = Palette.hud,
		Parent = Hud.gui(),
	}, OverviewCam.close)

	-- Wheel or pinch to zoom, drag to pan.
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input, processed)
			if processed or not open then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				height = math.clamp(height * (1 - input.Position.Z * 0.12), 60, fitHeight() * 1.2)
			elseif
				input.UserInputType == Enum.UserInputType.MouseMovement
				and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			then
				local scale = height / 500
				focus += Vector3.new(-input.Delta.X * scale, 0, -input.Delta.Y * scale)
			elseif input.UserInputType == Enum.UserInputType.Gamepad1 and input.KeyCode == Enum.KeyCode.Thumbstick1 then
				focus += Vector3.new(input.Position.X, 0, -input.Position.Y) * height / 60
			end
			focus = Vector3.new(
				math.clamp(focus.X, -BOARD_W / 2, BOARD_W / 2),
				0,
				math.clamp(focus.Z, -BOARD_H / 2, BOARD_H / 2)
			)
			camera.CFrame = cameraCFrame()
		end)
	)
	table.insert(
		connections,
		UserInputService.TouchPinch:Connect(function(_, scale, _, state)
			if open and state == Enum.UserInputState.Change then
				height = math.clamp(height / math.max(scale, 0.01) ^ 0.05, 60, fitHeight() * 1.2)
				camera.CFrame = cameraCFrame()
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.TouchPan:Connect(function(_, delta, _, state)
			if open and state == Enum.UserInputState.Change then
				local scale = height / 500
				focus += Vector3.new(-delta.X * scale, 0, -delta.Y * scale)
				camera.CFrame = cameraCFrame()
			end
		end)
	)
end

function OverviewCam.toggle()
	if open then
		OverviewCam.close()
	else
		OverviewCam.open()
	end
end

function OverviewCam.init()
	Hud.buttons.map.Activated:Connect(OverviewCam.toggle)
	ContextActionService:BindAction("OverviewMap", function(_, state)
		if state == Enum.UserInputState.Begin then
			OverviewCam.toggle()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.M, Enum.KeyCode.DPadUp)
	player.CharacterAdded:Connect(function()
		if open then
			OverviewCam.close()
		end
	end)
end

return OverviewCam
