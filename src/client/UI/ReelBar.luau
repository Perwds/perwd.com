--!nonstrict
-- The reel minigame. Hold to push the catch bar up, release to let it fall,
-- keep the fish inside it. Progress fills while overlapping and drains while
-- not; hit the top and it's yours, hit the bottom and it's gone.
--
-- Purely presentational: the fish was already decided server-side before this
-- appeared. All this reports back is whether the player kept up.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)
local HudScale = require(script.Parent.HudScale)

local ReelBar = {}
ReelBar.__index = ReelBar

local TRACK_HEIGHT = 320
local TRACK_WIDTH = 54
local START_PROGRESS = GameConfig.ReelStartProgress
local PUSH_ACCEL = 2.6
local FALL_ACCEL = -2.3
local DAMPING = 0.88

local HOLD_INPUTS = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}

local active = nil

function ReelBar.Cancel()
	if active then
		active:Destroy()
	end
end

function ReelBar.Start(parent: ScreenGui, config, onFinished: (boolean) -> ())
	ReelBar.Cancel()

	local self = setmetatable({}, ReelBar)
	self.finished = false
	self.onFinished = onFinished
	self.connections = {}

	self.barSize = math.clamp(config.barSize or 0.22, 0.05, 0.9)
	self.fillRate = config.fillRate or 0.55
	self.drainRate = config.drainRate or 0.38
	self.fishSpeed = config.fishSpeed or 1
	self.timeout = config.timeout or 30

	self.progress = START_PROGRESS
	self.barPos = 0.5
	self.barVel = 0
	self.fishPos = 0.5
	self.fishTarget = 0.5
	self.retargetIn = 0
	self.holding = false
	self.elapsed = 0

	self:BuildUi(parent)
	self:BindInput()

	self.connections.step = RunService.RenderStepped:Connect(function(dt)
		self:Step(math.min(dt, 0.1))
	end)

	active = self
	return self
end

function ReelBar:BuildUi(parent: ScreenGui)
	local root = Widgets.Glass({
		parent = parent,
		name = "ReelBar",
		size = UDim2.fromOffset(TRACK_WIDTH + 104, TRACK_HEIGHT + 68),
		position = UDim2.new(1, -34, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		tint = Theme.Accent,
		strokeThickness = 1.8,
		zIndex = 10,
	})
	HudScale.Attach(root)
	self.root = root
	Widgets.PopIn(root, 0.88)

	Widgets.Text({
		parent = root,
		text = "REEL IT IN",
		font = Theme.FontBlack,
		textSize = 12,
		color = Theme.TextDim,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 30),
	})

	-- The track the fish swims in.
	local track = Widgets.Frame({
		parent = root,
		name = "Track",
		size = UDim2.fromOffset(TRACK_WIDTH, TRACK_HEIGHT),
		position = UDim2.new(0, 18, 0, 46),
		color = Color3.new(1, 1, 1),
		transparency = 0.08,
		clip = true,
		zIndex = 2,
	})
	Widgets.Gradient(track, { Theme.Background, Theme.Panel }, 90)
	Widgets.Corner(track)
	local trackStroke = Widgets.Stroke(track, nil, 1.2)
	Widgets.StrokeGradient(trackStroke)
	self.track = track

	-- The player's catch bar.
	self.catchBar = Widgets.Frame({
		parent = track,
		name = "CatchBar",
		size = UDim2.new(1, -10, self.barSize, 0),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchor = Vector2.new(0.5, 0.5),
		color = Color3.new(1, 1, 1),
		transparency = 0.38,
		zIndex = 3,
	})
	self.catchGradient = Widgets.Gradient(
		self.catchBar,
		{ Theme.Good:Lerp(Color3.new(1, 1, 1), 0.4), Theme.Good },
		90
	)
	Widgets.Corner(self.catchBar, Theme.CornerSmall)
	self.catchStroke = Widgets.Stroke(self.catchBar, Theme.Good, 1.6)

	-- The fish.
	self.fish = Widgets.Frame({
		parent = track,
		name = "Fish",
		size = UDim2.fromOffset(TRACK_WIDTH - 26, 16),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchor = Vector2.new(0.5, 0.5),
		color = Color3.new(1, 1, 1),
		zIndex = 5,
	})
	Widgets.Gradient(self.fish, { Color3.fromRGB(255, 255, 255), Color3.fromRGB(198, 214, 240) }, 90)
	Widgets.Corner(self.fish, Theme.CornerPill)
	self.fishStroke = Widgets.Stroke(self.fish, Theme.Text, 1.4)

	-- Progress meter.
	local meter = Widgets.Frame({
		parent = root,
		name = "Meter",
		size = UDim2.fromOffset(20, TRACK_HEIGHT),
		position = UDim2.new(0, TRACK_WIDTH + 40, 0, 46),
		color = Color3.new(1, 1, 1),
		transparency = 0.08,
		clip = true,
		zIndex = 2,
	})
	Widgets.Gradient(meter, { Theme.Background, Theme.Panel }, 90)
	Widgets.Corner(meter, Theme.CornerSmall)
	Widgets.StrokeGradient(Widgets.Stroke(meter, nil, 1.2))

	self.meterFill = Widgets.Frame({
		parent = meter,
		name = "Fill",
		size = UDim2.fromScale(1, START_PROGRESS),
		position = UDim2.fromScale(0, 1),
		anchor = Vector2.new(0, 1),
		color = Color3.new(1, 1, 1),
		zIndex = 3,
	})
	self.meterGradient = Widgets.Gradient(
		self.meterFill,
		{ Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.4), Theme.Accent },
		90
	)
	Widgets.Corner(self.meterFill, Theme.CornerSmall)

	self.hint = Widgets.Text({
		parent = root,
		text = "hold to reel",
		font = Theme.FontMedium,
		textSize = 11,
		color = Theme.TextFaint,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.new(0, 0, 1, -24),
	})
end

function ReelBar:BindInput()
	self.connections.began = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if HOLD_INPUTS[input.UserInputType] or input.KeyCode == Enum.KeyCode.Space then
			self.holding = true
		end
	end)

	self.connections.ended = UserInputService.InputEnded:Connect(function(input)
		if HOLD_INPUTS[input.UserInputType] or input.KeyCode == Enum.KeyCode.Space then
			self.holding = false
		end
	end)
end

function ReelBar:Step(dt: number)
	if self.finished then
		return
	end

	self.elapsed += dt
	if self.elapsed >= self.timeout then
		self:Finish(false)
		return
	end

	-- Catch bar: held up, otherwise falls.
	local accel = self.holding and PUSH_ACCEL or FALL_ACCEL
	self.barVel = (self.barVel + accel * dt) * DAMPING
	self.barPos += self.barVel * dt

	local half = self.barSize / 2
	if self.barPos < half then
		self.barPos = half
		self.barVel = math.max(self.barVel, 0)
	elseif self.barPos > 1 - half then
		self.barPos = 1 - half
		self.barVel = math.min(self.barVel, 0)
	end

	-- Fish: darts toward a new target at random intervals.
	self.retargetIn -= dt
	if self.retargetIn <= 0 then
		self.retargetIn = math.random() * 0.9 / self.fishSpeed + 0.2
		self.fishTarget = math.random()
	end

	local travel = self.fishSpeed * 1.35 * dt
	self.fishPos += math.clamp(self.fishTarget - self.fishPos, -travel, travel)
	self.fishPos = math.clamp(self.fishPos, 0.02, 0.98)

	-- Progress.
	local inside = math.abs(self.fishPos - self.barPos) <= half
	self.progress += (inside and self.fillRate or -self.drainRate) * dt
	self.progress = math.clamp(self.progress, 0, 1)

	self:Render(inside)

	if self.progress >= 1 then
		self:Finish(true)
	elseif self.progress <= 0 then
		self:Finish(false)
	end
end

function ReelBar:Render(inside: boolean)
	-- The track's 0 is the top, so flip for a "rising" feel.
	self.catchBar.Position = UDim2.new(0.5, 0, 1 - self.barPos, 0)
	self.fish.Position = UDim2.new(0.5, 0, 1 - self.fishPos, 0)
	self.meterFill.Size = UDim2.fromScale(1, self.progress)

	local color = inside and Theme.Good or Theme.Bad
	self.catchGradient.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), color)
	self.catchStroke.Color = color
	-- Tightens up when you are on the fish, loosens when you are losing it.
	self.catchStroke.Transparency = inside and 0 or 0.45
	self.catchBar.BackgroundTransparency = inside and 0.3 or 0.48

	local meterColor = inside and Theme.Good or Theme.Warn
	self.meterGradient.Color =
		ColorSequence.new(meterColor:Lerp(Color3.new(1, 1, 1), 0.4), meterColor)

	self.fishStroke.Color = inside and Theme.Good or Theme.Text
end

function ReelBar:Finish(won: boolean)
	if self.finished then
		return
	end
	self.finished = true

	local callback = self.onFinished
	self:Destroy()

	if callback then
		task.spawn(callback, won)
	end
end

function ReelBar:Destroy()
	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)

	if self.root then
		self.root:Destroy()
		self.root = nil
	end

	if active == self then
		active = nil
	end
end

return ReelBar
