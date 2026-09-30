--!nonstrict
-- Builds the rod the player visibly holds, coloured by whichever rod they have
-- equipped. A Tool so it inherits the character's hold animation, with a Tip
-- attachment the client anchors the fishing line to.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rods = require(Shared.Config.Rods)

local RodModel = {}

RodModel.ToolName = "FishingRod"

local SEGMENTS = 5
local SEGMENT_LENGTH = 2.6

local function weld(handle: BasePart, part: BasePart)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = handle
	joint.Part1 = part
	joint.Parent = part
end

local function piece(parent: Instance, handle: BasePart, props): Part
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = props.size
	part.CFrame = handle.CFrame * props.offset
	part.Color = props.color
	part.Material = props.material or Enum.Material.Plastic
	part.Reflectance = props.reflectance or 0
	part.Name = props.name or "Piece"
	if props.shape then
		part.Shape = props.shape
	end
	part.Parent = parent
	weld(handle, part)
	return part
end

function RodModel.Build(rodId: string): Tool
	local rod = Rods.Get(rodId)

	local tool = Instance.new("Tool")
	tool.Name = RodModel.ToolName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true
	tool.ToolTip = rod.name

	-- Grip. The rod extends along the handle's +Y, which is the convention the
	-- default hold animation expects.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 2.4, 0.45)
	handle.Color = Color3.fromRGB(46, 38, 34)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.Parent = tool

	-- Reel housing.
	piece(tool, handle, {
		name = "Reel",
		size = Vector3.new(1.1, 0.7, 0.7),
		offset = CFrame.new(0.35, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = rod.color:Lerp(Color3.new(0, 0, 0), 0.25),
		material = Enum.Material.Metal,
		reflectance = 0.15,
		shape = Enum.PartType.Cylinder,
	})

	-- Tapering shaft.
	local cursor = 1.2
	for index = 1, SEGMENTS do
		local factor = 1 - (index - 1) / SEGMENTS
		piece(tool, handle, {
			name = "Shaft" .. index,
			size = Vector3.new(0.17 * factor + 0.05, SEGMENT_LENGTH, 0.17 * factor + 0.05),
			offset = CFrame.new(0, cursor + SEGMENT_LENGTH / 2, 0),
			color = rod.color:Lerp(Color3.new(1, 1, 1), (index - 1) * 0.08),
			material = index == SEGMENTS and Enum.Material.Neon or Enum.Material.Metal,
			reflectance = 0.08,
		})
		cursor += SEGMENT_LENGTH * 0.98
	end

	-- Where the line leaves the rod.
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, cursor, 0)
	tip.Parent = handle

	return tool
end

-- Gives the player the rod for their current loadout, replacing any older one.
function RodModel.Equip(player: Player, rodId: string)
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	for _, container in { character, player:FindFirstChildOfClass("Backpack") } do
		if container then
			local existing = container:FindFirstChild(RodModel.ToolName)
			if existing then
				existing:Destroy()
			end
		end
	end

	local tool = RodModel.Build(rodId)
	tool.Parent = player:FindFirstChildOfClass("Backpack")

	-- EquipTool throws if the humanoid is dead or mid-respawn.
	pcall(function()
		humanoid:EquipTool(tool)
	end)
end

return RodModel
