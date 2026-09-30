--[[
	The window chrome every menu shares: a bright header bar with the title,
	a red X, and a dark inset body. Opening and closing is a short pop tween
	so the menus feel like the rest of the game.
]]

local TweenService = game:GetService("TweenService")

local Builder = require(script.Parent.Builder)
local Theme = require(script.Parent.Theme)

local Panel = {}
Panel.__index = Panel

local OPEN_TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CLOSE_TWEEN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

-- Only one panel is on screen at a time, like the reference game.
local openPanel: any = nil

function Panel.new(config: {
	name: string,
	title: string,
	size: UDim2,
	headerColor: Color3?,
	parent: Instance,
})
	local self = setmetatable({}, Panel)

	self.name = config.name
	self.isOpen = false

	self.root = Builder.make("Frame", {
		Name = config.name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = config.size,
		BackgroundColor3 = Theme.Color.panel,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = Theme.Z.panel,
		Parent = config.parent,
	}, {
		Builder.corner(14),
		Builder.stroke(4),
	})

	-- Header bar.
	local header = Builder.make("Frame", {
		Name = "Header",
		Size = UDim2.new(1, -16, 0, Theme.Metric.headerHeight),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = config.headerColor or Theme.Color.headerBlue,
		BorderSizePixel = 0,
		ZIndex = Theme.Z.panel + 1,
		Parent = self.root,
	}, {
		Builder.corner(),
		Builder.stroke(3),
		Builder.gradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 210), 90),
	})

	self.titleLabel = Builder.label(config.title, {
		Name = "Title",
		Size = UDim2.new(1, -80, 1, -10),
		Position = UDim2.fromOffset(16, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = Theme.Z.panel + 2,
		Parent = header,
	})

	self.closeButton = Builder.button("X", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(46, 38),
		BackgroundColor3 = Theme.Color.red,
		ZIndex = Theme.Z.panel + 2,
		Parent = header,
	}, function()
		self:close()
	end)

	-- Body: everything a panel adds goes in here.
	self.body = Builder.make("Frame", {
		Name = "Body",
		Position = UDim2.fromOffset(8, Theme.Metric.headerHeight + 16),
		Size = UDim2.new(1, -16, 1, -(Theme.Metric.headerHeight + 24)),
		BackgroundColor3 = Theme.Color.panelDeep,
		BorderSizePixel = 0,
		ZIndex = Theme.Z.panel,
		Parent = self.root,
	}, {
		Builder.corner(),
		Builder.stroke(3),
	})

	-- Vertical tab rail on the right, like World / Limited.
	self.rail = Builder.make("Frame", {
		Name = "Rail",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(1, 14, 0, 8),
		Size = UDim2.fromOffset(150, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = Theme.Z.panel,
		Parent = self.root,
	}, {
		Builder.list({ Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Left }),
	})

	self._targetSize = config.size

	return self
end

--- Adds a tab to the right-hand rail. Returns the button.
function Panel:addTab(text: string, color: Color3, onClick: () -> ())
	local button = Builder.button(text, {
		Size = UDim2.new(1, 0, 0, 46),
		BackgroundColor3 = color,
		ZIndex = Theme.Z.panel,
		Parent = self.rail,
	}, onClick)
	return button
end

function Panel:setTitle(text: string)
	self.titleLabel.Text = text
end

function Panel:open()
	if self.isOpen then
		return
	end

	if openPanel and openPanel ~= self then
		openPanel:close()
	end
	openPanel = self

	self.isOpen = true
	self.root.Visible = true
	self.root.Size = UDim2.new(
		self._targetSize.X.Scale * 0.8,
		self._targetSize.X.Offset * 0.8,
		self._targetSize.Y.Scale * 0.8,
		self._targetSize.Y.Offset * 0.8
	)

	TweenService:Create(self.root, OPEN_TWEEN, { Size = self._targetSize }):Play()

	if self.onOpen then
		self.onOpen()
	end
end

function Panel:close()
	if not self.isOpen then
		return
	end
	self.isOpen = false

	if openPanel == self then
		openPanel = nil
	end

	local tween = TweenService:Create(self.root, CLOSE_TWEEN, {
		Size = UDim2.new(
			self._targetSize.X.Scale * 0.85,
			self._targetSize.X.Offset * 0.85,
			self._targetSize.Y.Scale * 0.85,
			self._targetSize.Y.Offset * 0.85
		),
	})
	tween.Completed:Connect(function()
		if not self.isOpen then
			self.root.Visible = false
		end
	end)
	tween:Play()

	if self.onClose then
		self.onClose()
	end
end

function Panel:toggle()
	if self.isOpen then
		self:close()
	else
		self:open()
	end
end

function Panel.closeAll()
	if openPanel then
		openPanel:close()
	end
end

return Panel
