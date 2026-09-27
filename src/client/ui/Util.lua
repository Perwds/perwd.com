--!strict
--[[
	Util -- tiny declarative instance builder plus a few UI helpers.

	  Util.new("TextLabel", { Text = "hi" }, { child1, child2 })
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Util = {}

function Util.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)

	if props then
		local parent = props.Parent
		props.Parent = nil
		for key, value in pairs(props) do
			(instance :: any)[key] = value
		end
		if parent then
			instance.Parent = parent
		end
	end

	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end

	return instance
end

function Util.corner(radius: UDim, parent: Instance?): UICorner
	return Util.new("UICorner", { CornerRadius = radius, Parent = parent })
end

function Util.padding(amount: number, parent: Instance?): UIPadding
	return Util.new("UIPadding", {
		PaddingTop = UDim.new(0, amount),
		PaddingBottom = UDim.new(0, amount),
		PaddingLeft = UDim.new(0, amount),
		PaddingRight = UDim.new(0, amount),
		Parent = parent,
	})
end

function Util.stroke(color: Color3, thickness: number, parent: Instance?): UIStroke
	return Util.new("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function Util.listLayout(padding: number, parent: Instance?, direction: Enum.FillDirection?): UIListLayout
	return Util.new("UIListLayout", {
		Padding = UDim.new(0, padding),
		FillDirection = direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function Util.gradient(top: Color3, bottom: Color3, parent: Instance?): UIGradient
	return Util.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = 90,
		Parent = parent,
	})
end

function Util.tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local info = TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, goal)
	tween:Play()
	return tween
end

--- Button that pops slightly on hover and press.
function Util.button(props: { [string]: any }, children: { Instance }?): TextButton
	props.AutoButtonColor = props.AutoButtonColor ~= false
	props.Font = props.Font or Theme.Font.bold
	props.TextColor3 = props.TextColor3 or Theme.Color.text
	props.BorderSizePixel = 0

	local button: TextButton = Util.new("TextButton", props, children)
	local baseSize = button.Size

	button.MouseEnter:Connect(function()
		Util.tween(button, 0.12, {
			Size = UDim2.new(
				baseSize.X.Scale,
				baseSize.X.Offset + 4,
				baseSize.Y.Scale,
				baseSize.Y.Offset + 4
			),
		})
	end)
	button.MouseLeave:Connect(function()
		Util.tween(button, 0.12, { Size = baseSize })
	end)

	return button
end

--- Debounced click handler.
function Util.onClick(button: GuiButton, cooldown: number, callback: () -> ())
	local last = 0
	button.Activated:Connect(function()
		local now = os.clock()
		if now - last < cooldown then
			return
		end
		last = now
		callback()
	end)
end

return Util
