--!strict
--[[
	Build
	The village construction kit: houses, towers, stalls, lanterns, banners,
	trees, fences, gravestone boards and portals.

	Everything is anchored, built from primitives, and takes a CFrame so a
	building can face wherever it is placed. WorldBuilder composes these into
	the actual town.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Palette = require(Shared.Palette)

local Build = {}

-- Primitives -------------------------------------------------------------

function Build.part(props: { [string]: any }, parent: Instance?): BasePart
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.Material = Enum.Material.SmoothPlastic
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		(instance :: any)[key] = value
	end
	instance.Parent = parent
	return instance
end

local function mesh(target: BasePart, meshType: Enum.MeshType)
	local special = Instance.new("SpecialMesh")
	special.MeshType = meshType
	special.Parent = target
	return special
end

function Build.sign(parent: BasePart, text: string, tint: Color3, height: number, size: number): TextLabel
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Sign"
	billboard.Size = UDim2.fromScale(13, 3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	billboard.MaxDistance = 220
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = tint
	label.TextStrokeColor3 = Palette.outline
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = billboard

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = size
	constraint.Parent = label

	return label
end

-- Buildings --------------------------------------------------------------

local WALL = Color3.fromRGB(226, 214, 191)
local BEAM = Color3.fromRGB(86, 58, 42)
local WINDOW = Color3.fromRGB(255, 214, 128)

--- A timber-framed cottage. `cf` puts the door on the +Z face.
function Build.house(cf: CFrame, roofColor: Color3, parent: Instance, scale: number?)
	local s = scale or 1
	local w, d, h = 18 * s, 15 * s, 12 * s

	Build.part({
		Name = "Walls",
		Size = Vector3.new(w, h, d),
		CFrame = cf * CFrame.new(0, h / 2, 0),
		Color = WALL,
		Material = Enum.Material.Plaster,
	}, parent)

	-- Corner posts and a belt rail, which is what sells "half-timbered".
	for _, corner in ipairs({
		Vector3.new(-w / 2, 0, -d / 2),
		Vector3.new(w / 2, 0, -d / 2),
		Vector3.new(-w / 2, 0, d / 2),
		Vector3.new(w / 2, 0, d / 2),
	}) do
		Build.part({
			Name = "Post",
			Size = Vector3.new(1.2, h, 1.2),
			CFrame = cf * CFrame.new(corner.X, h / 2, corner.Z),
			Color = BEAM,
			Material = Enum.Material.Wood,
		}, parent)
	end

	Build.part({
		Name = "Belt",
		Size = Vector3.new(w + 0.4, 1, d + 0.4),
		CFrame = cf * CFrame.new(0, h * 0.55, 0),
		Color = BEAM,
		Material = Enum.Material.Wood,
	}, parent)

	-- Gable roof: a single triangular prism, so it cannot end up inverted.
	local roof = Build.part({
		Name = "Roof",
		Size = Vector3.new(w + 3, 7 * s, d + 3),
		CFrame = cf * CFrame.new(0, h + 3.5 * s, 0),
		Color = roofColor,
		Material = Enum.Material.Slate,
	}, parent)
	mesh(roof, Enum.MeshType.Prism)

	-- Door and windows on the facing side.
	Build.part({
		Name = "Door",
		Size = Vector3.new(4, 7 * s, 0.6),
		CFrame = cf * CFrame.new(0, 3.5 * s, d / 2 + 0.2),
		Color = BEAM,
		Material = Enum.Material.Wood,
	}, parent)

	for _, offset in ipairs({ -w * 0.28, w * 0.28 }) do
		local window = Build.part({
			Name = "Window",
			Size = Vector3.new(3.4, 3.4, 0.5),
			CFrame = cf * CFrame.new(offset, h * 0.72, d / 2 + 0.2),
			Color = WINDOW,
			Material = Enum.Material.Neon,
		}, parent)

		local glow = Instance.new("PointLight")
		glow.Color = WINDOW
		glow.Range = 14
		glow.Brightness = 1.2
		glow.Parent = window
	end
end

--- Round stone tower with a spire.
function Build.tower(position: Vector3, radius: number, height: number, roofColor: Color3, parent: Instance)
	local body = Build.part({
		Name = "TowerBody",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(176, 168, 158),
		Material = Enum.Material.Brick,
	}, parent)

	local spire = Build.part({
		Name = "Spire",
		Size = Vector3.new(radius * 2.4, radius * 2.2, radius * 2.4),
		CFrame = CFrame.new(position + Vector3.new(0, height + radius * 1.1, 0)),
		Color = roofColor,
		Material = Enum.Material.Slate,
	}, parent)
	mesh(spire, Enum.MeshType.Pyramid)

	-- Lit windows spiralling up the tower.
	for step = 1, math.floor(height / 8) do
		local angle = step * 2.2
		local window = Build.part({
			Name = "TowerWindow",
			Size = Vector3.new(2.2, 3, 1),
			CFrame = CFrame.new(
				position + Vector3.new(math.sin(angle) * radius, step * 8, math.cos(angle) * radius)
			) * CFrame.Angles(0, angle, 0),
			Color = WINDOW,
			Material = Enum.Material.Neon,
		}, parent)

		local glow = Instance.new("PointLight")
		glow.Color = WINDOW
		glow.Range = 12
		glow.Brightness = 1
		glow.Parent = window
	end

	return body
end

--- Market stall with a striped awning. These are the scan stations.
function Build.stall(cf: CFrame, tint: Color3, label: string, parent: Instance): BasePart
	local counter = Build.part({
		Name = "Counter",
		Size = Vector3.new(12, 4, 6),
		CFrame = cf * CFrame.new(0, 2, 0),
		Color = BEAM,
		Material = Enum.Material.Wood,
	}, parent)

	for _, x in ipairs({ -5.5, 5.5 }) do
		for _, z in ipairs({ -2.5, 2.5 }) do
			Build.part({
				Name = "StallPost",
				Size = Vector3.new(0.8, 10, 0.8),
				CFrame = cf * CFrame.new(x, 5, z),
				Color = BEAM,
				Material = Enum.Material.Wood,
			}, parent)
		end
	end

	-- Striped canopy.
	for index = -3, 3 do
		Build.part({
			Name = "Awning",
			Size = Vector3.new(1.9, 0.6, 9),
			CFrame = cf * CFrame.new(index * 1.9, 10.3, 0) * CFrame.Angles(math.rad(-8), 0, 0),
			Color = index % 2 == 0 and tint or Color3.fromRGB(246, 240, 228),
			Material = Enum.Material.Fabric,
		}, parent)
	end

	local glow = Build.part({
		Name = "StallGlow",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.4, 2.4, 2.4),
		CFrame = cf * CFrame.new(0, 6.4, 0),
		Color = tint,
		Material = Enum.Material.Neon,
	}, parent)

	local light = Instance.new("PointLight")
	light.Color = tint
	light.Range = 18
	light.Brightness = 2
	light.Parent = glow

	Build.sign(glow, label, tint, 6, 42)

	return glow
end

-- Dressing ---------------------------------------------------------------

function Build.lanternPost(position: Vector3, parent: Instance)
	Build.part({
		Name = "LampPost",
		Size = Vector3.new(0.7, 12, 0.7),
		CFrame = CFrame.new(position + Vector3.new(0, 6, 0)),
		Color = Color3.fromRGB(58, 48, 44),
		Material = Enum.Material.Metal,
	}, parent)

	local lamp = Build.part({
		Name = "Lantern",
		Size = Vector3.new(2.4, 3, 2.4),
		CFrame = CFrame.new(position + Vector3.new(0, 12.6, 0)),
		Color = WINDOW,
		Material = Enum.Material.Neon,
	}, parent)

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 196, 120)
	light.Range = 26
	light.Brightness = 2.2
	light.Parent = lamp

	return lamp
end

--- Cable strung between two points with bulbs hanging off it.
function Build.stringLights(from: Vector3, to: Vector3, bulbs: number, parent: Instance)
	local span = to - from
	local mid = from + span * 0.5 - Vector3.new(0, 1.5, 0)

	Build.part({
		Name = "Cable",
		Size = Vector3.new(0.25, 0.25, span.Magnitude),
		CFrame = CFrame.lookAt(mid, mid + span.Unit),
		Color = Color3.fromRGB(32, 28, 26),
		Material = Enum.Material.Metal,
	}, parent)

	for index = 1, bulbs do
		local alpha = index / (bulbs + 1)
		local sag = math.sin(alpha * math.pi) * 2.5
		local hue = ({
			Color3.fromRGB(255, 196, 120),
			Palette.pink,
			Palette.cyan,
			Palette.green,
		})[(index % 4) + 1]

		local bulb = Build.part({
			Name = "Bulb",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(1.1, 1.1, 1.1),
			CFrame = CFrame.new(from:Lerp(to, alpha) - Vector3.new(0, 1.5 + sag, 0)),
			Color = hue,
			Material = Enum.Material.Neon,
		}, parent)

		if index % 2 == 0 then
			local light = Instance.new("PointLight")
			light.Color = hue
			light.Range = 12
			light.Brightness = 1.1
			light.Parent = bulb
		end
	end
end

function Build.banner(position: Vector3, tint: Color3, parent: Instance)
	Build.part({
		Name = "BannerPole",
		Size = Vector3.new(0.8, 22, 0.8),
		CFrame = CFrame.new(position + Vector3.new(0, 11, 0)),
		Color = BEAM,
		Material = Enum.Material.Wood,
	}, parent)

	Build.part({
		Name = "BannerCloth",
		Size = Vector3.new(0.4, 9, 5),
		CFrame = CFrame.new(position + Vector3.new(0, 16, 2.6)),
		Color = tint,
		Material = Enum.Material.Fabric,
	}, parent)

	local tip = Build.part({
		Name = "BannerTip",
		Size = Vector3.new(0.4, 3, 5),
		CFrame = CFrame.new(position + Vector3.new(0, 10.4, 2.6)),
		Color = tint,
		Material = Enum.Material.Fabric,
	}, parent)
	mesh(tip, Enum.MeshType.Wedge)
end

function Build.tree(position: Vector3, scale: number, parent: Instance)
	local s = scale

	Build.part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10 * s, 2.4 * s, 2.4 * s),
		CFrame = CFrame.new(position + Vector3.new(0, 5 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(94, 64, 44),
		Material = Enum.Material.Wood,
	}, parent)

	for tier = 0, 2 do
		local size = (14 - tier * 3.2) * s
		local foliage = Build.part({
			Name = "Foliage",
			Size = Vector3.new(size, size * 0.9, size),
			CFrame = CFrame.new(position + Vector3.new(0, (9 + tier * 4.6) * s, 0)),
			Color = tier == 2 and Color3.fromRGB(96, 178, 88) or Color3.fromRGB(74, 152, 74),
			Material = Enum.Material.Grass,
		}, parent)
		mesh(foliage, Enum.MeshType.Pyramid)
	end
end

function Build.fence(from: Vector3, to: Vector3, parent: Instance)
	local span = to - from
	local posts = math.max(2, math.floor(span.Magnitude / 8))

	for index = 0, posts do
		Build.part({
			Name = "FencePost",
			Size = Vector3.new(0.9, 5, 0.9),
			CFrame = CFrame.new(from:Lerp(to, index / posts) + Vector3.new(0, 2.5, 0)),
			Color = BEAM,
			Material = Enum.Material.Wood,
		}, parent)
	end

	local mid = from + span * 0.5
	for _, height in ipairs({ 2, 3.8 }) do
		Build.part({
			Name = "FenceRail",
			Size = Vector3.new(0.5, 0.5, span.Magnitude),
			CFrame = CFrame.lookAt(mid + Vector3.new(0, height, 0), mid + Vector3.new(0, height, 0) + span.Unit),
			Color = BEAM,
			Material = Enum.Material.Wood,
		}, parent)
	end
end

--- Cobbled path segment between two points.
function Build.path(from: Vector3, to: Vector3, width: number, parent: Instance)
	local span = to - from
	local mid = from + span * 0.5

	Build.part({
		Name = "Path",
		Size = Vector3.new(width, 0.6, span.Magnitude),
		CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.3, 0), mid + Vector3.new(0, 0.3, 0) + span.Unit),
		Color = Color3.fromRGB(150, 140, 128),
		Material = Enum.Material.Cobblestone,
	}, parent)
end

-- Fixtures ---------------------------------------------------------------

--- A carved stone slab, the way hub leaderboards are usually done.
function Build.gravestone(cf: CFrame, title: string, rows: number, parent: Instance): { TextLabel }
	Build.part({
		Name = "GraveBase",
		Size = Vector3.new(20, 2, 6),
		CFrame = cf * CFrame.new(0, 1, 0),
		Color = Color3.fromRGB(122, 120, 116),
		Material = Enum.Material.Slate,
	}, parent)

	local slab = Build.part({
		Name = "GraveSlab",
		Size = Vector3.new(18, 24, 2),
		CFrame = cf * CFrame.new(0, 14, 0),
		Color = Color3.fromRGB(138, 136, 130),
		Material = Enum.Material.Slate,
	}, parent)

	local top = Build.part({
		Name = "GraveTop",
		Size = Vector3.new(18, 5, 2),
		CFrame = cf * CFrame.new(0, 26, 0),
		Color = Color3.fromRGB(138, 136, 130),
		Material = Enum.Material.Slate,
	}, parent)
	mesh(top, Enum.MeshType.Prism)

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(460, 620)
	surface.LightInfluence = 0.35
	surface.Parent = slab

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(28, 26, 24)
	background.BackgroundTransparency = 0.25
	background.BorderSizePixel = 0
	background.Parent = surface

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundTransparency = 1
	header.Font = Enum.Font.FredokaOne
	header.Text = title
	header.TextColor3 = Color3.fromRGB(245, 238, 220)
	header.TextScaled = true
	header.Parent = background

	local list = Instance.new("Frame")
	list.Position = UDim2.new(0, 12, 0, 64)
	list.Size = UDim2.new(1, -24, 1, -74)
	list.BackgroundTransparency = 1
	list.Parent = background

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local labels = {}
	for index = 1, rows do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.LayoutOrder = index
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamBold
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(238, 232, 216)
		row.TextSize = 18
		row.Text = ""
		row.Parent = list
		labels[index] = row
	end

	return labels
end

--- Glowing ground ring, the shape every hub uses for "go somewhere".
function Build.portal(position: Vector3, tint: Color3, label: string, parent: Instance): BasePart
	local segments = 22
	local radius = 9

	for index = 1, segments do
		local angle = (index / segments) * math.pi * 2
		Build.part({
			Name = "RingSegment",
			Size = Vector3.new(2.6, 1.2, 1.6),
			CFrame = CFrame.new(position + Vector3.new(math.sin(angle) * radius, 0.6, math.cos(angle) * radius))
				* CFrame.Angles(0, angle, 0),
			Color = tint,
			Material = Enum.Material.Neon,
		}, parent)
	end

	local pad = Build.part({
		Name = "PortalPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, radius * 2, radius * 2),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = tint,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
	}, parent)

	local light = Instance.new("PointLight")
	light.Color = tint
	light.Range = 34
	light.Brightness = 3
	light.Parent = pad

	local beam = Build.part({
		Name = "PortalBeam",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(40, radius * 1.7, radius * 1.7),
		CFrame = CFrame.new(position + Vector3.new(0, 20, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = tint,
		Material = Enum.Material.Neon,
		Transparency = 0.88,
		CanCollide = false,
	}, parent)

	Build.sign(beam, label, tint, 22, 46)

	return pad
end

return Build
