--[[ Toast messages, stacked bottom-left and auto-dismissed. ]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)

local Builder = require(script.Parent.Builder)
local Theme = require(script.Parent.Theme)

local Notify = {}

local KIND_COLOR = {
	info = Theme.Color.blue,
	success = Theme.Color.green,
	warn = Theme.Color.red,
	index = Theme.Color.headerPurple,
}

local container: Frame

function Notify.build(screen: ScreenGui)
	container = Builder.make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = Theme.Z.toast,
		Parent = screen,
	}, {
		Builder.list({
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
	})
	return container
end

function Notify.push(kind: string, message: string)
	if not container then
		return
	end

	local color = KIND_COLOR[kind] or Theme.Color.blue

	local toast = Builder.frame({
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Color.panelDeep,
		ZIndex = Theme.Z.toast,
		Parent = container,
	}, {
		Builder.padding(10),
		Builder.make("Frame", {
			Name = "Accent",
			Size = UDim2.new(0, 5, 1, 0),
			Position = UDim2.fromOffset(-6, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = Theme.Z.toast + 1,
		}, { Builder.corner(3) }),
	})

	Builder.label(message, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextSize = 18,
		Font = Theme.Font.body,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		ZIndex = Theme.Z.toast + 1,
		Parent = toast,
	})

	-- Slide in, hold, fade out.
	toast.BackgroundTransparency = 1
	TweenService:Create(toast, TweenInfo.new(0.15), { BackgroundTransparency = 0 }):Play()

	task.delay(4, function()
		if not toast.Parent then
			return
		end
		local out = TweenService:Create(toast, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		out.Completed:Connect(function()
			toast:Destroy()
		end)
		out:Play()
	end)

	-- Keep the stack short.
	local children = container:GetChildren()
	local count = 0
	for _, child in children do
		if child:IsA("Frame") then
			count += 1
		end
	end
	if count > 5 then
		for _, child in children do
			if child:IsA("Frame") then
				child:Destroy()
				break
			end
		end
	end
end

function Notify.start()
	Net.Event("Notify").OnClientEvent:Connect(function(kind, message)
		Notify.push(tostring(kind), tostring(message))
	end)

	Net.Event("CarryFeedback").OnClientEvent:Connect(function(kind, detail)
		if kind == "grabbed" then
			Notify.push("success", `Grabbed a {detail} egg! Run!`)
		elseif kind == "stole" then
			Notify.push("success", `You stole {detail}'s egg!`)
		elseif kind == "robbed" then
			Notify.push("warn", `{detail} stole your egg!`)
		elseif kind == "full" or kind == "immune" then
			Notify.push("warn", tostring(detail))
		end
	end)
end

return Notify
