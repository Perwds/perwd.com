--!strict
-- Music and sound volume, reduce motion, and number style. Saved with the player's progress.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Palette)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)
local Ui = require(script.Parent.Ui)
local Audio = require(script.Parent.Audio)

local Settings = {}

local remotes: Folder
local window: Frame?
local local_: { [string]: any } = {}

local function save()
	remotes.SaveSettings:FireServer(local_)
	if State.current then
		State.current.settings = table.clone(local_)
		State.set(State.current)
	end
	Audio.applyVolumes()
end

local function row(parent: Instance, order: number, title: string): Frame
	local frame = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Ui.MIN_TAP),
		LayoutOrder = order,
		ZIndex = 11,
		Parent = parent,
	})
	Ui.text({
		Text = title,
		Font = Ui.TITLE,
		TextSize = 18,
		Size = UDim2.fromScale(0.45, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
		Parent = frame,
	})
	return frame
end

local function stepper(parent: Frame, key: string)
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.55, 1),
		ZIndex = 12,
		Parent = parent,
	})
	local value = Ui.text({
		Font = Ui.TITLE,
		TextSize = 20,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(1, -2 * Ui.MIN_TAP - 16, 1, 0),
		ZIndex = 12,
		Parent = holder,
	})
	local function show()
		value.Text = math.floor(local_[key] * 100 + 0.5) .. "%"
	end
	local function nudge(delta: number)
		local_[key] = math.clamp(math.floor((local_[key] + delta) * 10 + 0.5) / 10, 0, 1)
		show()
		save()
	end
	Ui.button(
		{ Text = "-", TextSize = 24, Size = UDim2.fromOffset(Ui.MIN_TAP, Ui.MIN_TAP), ZIndex = 13, Parent = holder },
		function()
			nudge(-0.1)
		end
	)
	Ui.button({
		Text = "+",
		TextSize = 24,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(Ui.MIN_TAP, Ui.MIN_TAP),
		ZIndex = 13,
		Parent = holder,
	}, function()
		nudge(0.1)
	end)
	show()
end

local function choice(parent: Frame, key: string, options: { { label: string, value: any } })
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0.55, 1),
		ZIndex = 12,
		Parent = parent,
	})
	Ui.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 8),
		Parent = holder,
	})
	local buttons = {}
	local function paint()
		for i, option in options do
			local on = local_[key] == option.value
			buttons[i].BackgroundColor3 = if on then Palette.zones.orange.plate else Palette.hudEdge
			buttons[i].TextColor3 = if on then Palette.dark else Palette.white
		end
	end
	for i, option in options do
		buttons[i] = Ui.button({
			Text = option.label,
			TextSize = 16,
			Size = UDim2.fromOffset(84, Ui.MIN_TAP),
			LayoutOrder = i,
			ZIndex = 13,
			Parent = holder,
		}, function()
			local_[key] = option.value
			paint()
			save()
		end)
	end
	paint()
end

function Settings.close()
	if window then
		window:Destroy()
		window = nil
	end
end

function Settings.open()
	Settings.close()
	local_ = table.clone(State.settings())
	local frame = Ui.panel({
		Name = "Settings",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.48),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 10,
		Parent = Hud.gui(),
	})
	window = frame
	Ui.padding(18).Parent = frame
	Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	local header = row(frame, 0, "SETTINGS")
	local title = header:FindFirstChildOfClass("TextLabel") :: TextLabel
	title.TextSize = 28
	title.TextColor3 = Palette.gold
	Ui.button({
		Text = "X",
		TextSize = 22,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(Ui.MIN_TAP, Ui.MIN_TAP),
		ZIndex = 12,
		Parent = header,
	}, Settings.close)

	stepper(row(frame, 1, "Music"), "music")
	stepper(row(frame, 2, "Sounds"), "sfx")
	choice(
		row(frame, 3, "Reduce motion"),
		"reduceMotion",
		{ { label = "Off", value = false }, { label = "On", value = true } }
	)
	choice(
		row(frame, 4, "Numbers"),
		"numbers",
		{ { label = "1.4K", value = "short" }, { label = "1,400", value = "full" } }
	)
end

function Settings.init(remoteFolder: Folder)
	remotes = remoteFolder
	Hud.buttons.settings.Activated:Connect(function()
		if window then
			Settings.close()
		else
			Settings.open()
		end
	end)
	ContextActionService:BindAction("SettingsMenu", function(_, state)
		if state == Enum.UserInputState.Begin then
			if window then
				Settings.close()
			else
				Settings.open()
			end
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.DPadLeft)
end

return Settings
