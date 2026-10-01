--!nonstrict
-- Renders a fish model inside the UI with a ViewportFrame, so a catch can
-- actually be looked at. The model is built procedurally, so this needs no
-- uploaded assets and works for every species and mutation.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Fish = require(Shared.Config.Fish)
local FishModel = require(Shared.FishModel)

local Theme = require(script.Parent.Theme)

local FishView = {}

-- Framed slightly above and to the side, which reads better than a side-on
-- profile and shows the dorsal fin.
local VIEW_DIRECTION = Vector3.new(0.52, 0.34, 1).Unit

local spinning: { { frame: ViewportFrame, model: Model, speed: number, seed: number } } = {}
local spinConnection: RBXScriptConnection? = nil

local function frameModel(camera: Camera, model: Model, length: number, zoom: number)
	-- Distance from the model's own size, so a Minnow and a Leviathan both fill
	-- the frame rather than one being a speck.
	local distance = length * 1.75 * zoom
	local target = Vector3.zero

	camera.CFrame = CFrame.lookAt(VIEW_DIRECTION * distance, target)
	camera.FieldOfView = 50
end

local function ensureSpin()
	if spinConnection then
		return
	end

	spinConnection = RunService.RenderStepped:Connect(function()
		local clock = os.clock()

		for index = #spinning, 1, -1 do
			local entry = spinning[index]
			if not entry.frame.Parent or not entry.model.PrimaryPart then
				table.remove(spinning, index)
			else
				entry.model:PivotTo(
					CFrame.Angles(0, clock * entry.speed + entry.seed, 0)
						* CFrame.Angles(math.sin(clock * 0.8 + entry.seed) * 0.08, 0, 0)
				)
			end
		end

		if #spinning == 0 and spinConnection then
			spinConnection:Disconnect()
			spinConnection = nil
		end
	end)
end

-- props: parent, fishId, mutation, weight, size, position, anchor, order,
--        zIndex, spin, zoom, tint
function FishView.Create(props): ViewportFrame
	local record = Fish.Get(props.fishId)
	local length = FishModel.DisplayLength(record, props.weight or record.minWeight)
	local palette = FishModel.Palette(record, props.mutation or "None")

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = props.name or "FishView"
	viewport.Size = props.size or UDim2.fromOffset(96, 96)
	viewport.Position = props.position or UDim2.fromScale(0, 0)
	viewport.AnchorPoint = props.anchor or Vector2.zero
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.LayoutOrder = props.order or 0
	viewport.ZIndex = props.zIndex or 1
	-- Lit from the fish's own colour so a Void Eel is lit like one.
	viewport.Ambient = palette.body:Lerp(Color3.fromRGB(120, 140, 170), 0.55)
	viewport.LightColor = (props.tint or palette.accent):Lerp(Color3.new(1, 1, 1), 0.4)
	viewport.LightDirection = Vector3.new(-0.4, -1, -0.6)
	viewport.Parent = props.parent

	local world = Instance.new("WorldModel")
	world.Parent = viewport

	local model = FishModel.Build(record.id, props.mutation or "None", props.weight or record.minWeight)
	model.Parent = world

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	frameModel(camera, model, length, props.zoom or 1)

	if model.PrimaryPart then
		-- A fixed three-quarter pose for static icons; the spinner overrides it.
		model:PivotTo(CFrame.Angles(0, math.rad(-28), 0))
	end

	if props.spin and model.PrimaryPart then
		table.insert(spinning, {
			frame = viewport,
			model = model,
			speed = props.spinSpeed or 0.7,
			seed = 0,
		})
		ensureSpin()
	end

	return viewport
end

-- A small framed icon, for list rows.
function FishView.Icon(props): Frame
	local holder = Instance.new("Frame")
	holder.Name = props.name or "FishIcon"
	holder.Size = props.size or UDim2.fromOffset(40, 34)
	holder.Position = props.position or UDim2.fromScale(0, 0)
	holder.AnchorPoint = props.anchor or Vector2.zero
	holder.BackgroundColor3 = Theme.Background
	holder.BackgroundTransparency = 0.45
	holder.BorderSizePixel = 0
	holder.LayoutOrder = props.order or 0
	holder.Parent = props.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = Theme.CornerSmall
	corner.Parent = holder

	FishView.Create({
		parent = holder,
		fishId = props.fishId,
		mutation = props.mutation,
		weight = props.weight,
		size = UDim2.fromScale(1, 1),
		zoom = props.zoom or 1.05,
	})

	return holder
end

return FishView
