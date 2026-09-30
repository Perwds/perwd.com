--!nonstrict
-- Sculpts all six zones out of real Roblox terrain at boot, then dresses them
-- with piers, lanterns and props. Nothing in the place file is load-bearing, so
-- the repo still syncs into an empty baseplate and runs.
--
-- Water is genuine Terrain water — refractive, animated, and raycastable —
-- rather than a transparent part. Its colour and wave settings are per-zone and
-- applied client-side, since Terrain water properties are global but local
-- writes are not replicated.

local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Visuals = require(Shared.Config.Visuals)

local Props = require(script.Parent.Props)

local MapBuilder = {}

MapBuilder.WaterTag = "FishingWater"

local ROOT_NAME = "FishingWorld"

-- Vertical layout, shared by every zone so the pier and spawn heights are
-- predictable no matter which island you are on.
local WATER_TOP = 0
local WATER_DEPTH = 34
local ISLAND_TOP = 6
local PIER_TOP = ISLAND_TOP + 0.8
-- Fraction of the zone radius the pier spans. Kept well short of the water's
-- edge so there is open water to cast into from the pier head.
local PIER_REACH = 0.26

MapBuilder.IslandTop = ISLAND_TOP
MapBuilder.PierTop = PIER_TOP

-- kind -> how many, per zone. Kinds map to the generators in Props.
local DRESSING = {
	pond = { tree = 11, rock = 7, fan = 9 },
	reef = { tree = 6, rock = 6, fan = 12 },
	frost = { shard = 12, rock = 7, tree = 4 },
	volcano = { shard = 10, rock = 9, glowShard = 5 },
	abyss = { glowShard = 9, rock = 8, fan = 6 },
	rift = { glowShard = 14, fan = 8, rock = 4 },
}

local function islandRadius(zone): number
	return zone.radius * 0.45
end

local function part(parent: Instance, props): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.CanCollide = props.collide ~= false
	instance.CanQuery = props.query ~= false
	instance.CanTouch = false
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Size = props.size
	instance.CFrame = props.cframe
	instance.Color = props.color
	instance.Material = props.material or Enum.Material.Plastic
	instance.Name = props.name or "Part"
	instance.Parent = parent
	return instance
end

-- Terrain -----------------------------------------------------------------------

local function sculpt(zoneId: string, rng: Random)
	local zone = Zones.Get(zoneId)
	local visuals = Visuals.Get(zoneId)
	local terrain = Workspace.Terrain
	local origin = zone.origin
	local radius = islandRadius(zone)

	local ground = Visuals.Material(visuals.ground)
	local shore = Visuals.Material(visuals.shore)
	local underwater = Visuals.Material(visuals.underwater)

	-- Seabed under everything, so the water has a floor rather than a void.
	terrain:FillCylinder(
		CFrame.new(origin + Vector3.new(0, -WATER_DEPTH - 10, 0)),
		20,
		zone.radius + 40,
		underwater
	)

	-- The basin. Filled before the island so the island can cut into it.
	terrain:FillCylinder(
		CFrame.new(origin + Vector3.new(0, WATER_TOP - WATER_DEPTH / 2, 0)),
		WATER_DEPTH,
		zone.radius,
		Enum.Material.Water
	)

	-- Flat island core. Guarantees somewhere level to stand and spawn.
	terrain:FillCylinder(
		CFrame.new(origin + Vector3.new(0, ISLAND_TOP - (ISLAND_TOP + WATER_DEPTH) / 2, 0)),
		ISLAND_TOP + WATER_DEPTH,
		radius,
		ground
	)

	-- Organic coastline: overlapping balls biting in and out of the core edge,
	-- which is what stops the island reading as a cylinder.
	for index = 1, 22 do
		local angle = (index / 22) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local distance = radius + rng:NextNumber(-8, 12)
		local ballRadius = rng:NextNumber(9, 18)

		terrain:FillBall(
			origin + Vector3.new(
				math.cos(angle) * distance,
				rng:NextNumber(-3, 2),
				math.sin(angle) * distance
			),
			ballRadius,
			rng:NextNumber() < 0.55 and shore or ground
		)
	end

	-- A couple of headlands so the silhouette is not a circle either.
	for _ = 1, 3 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local distance = radius * rng:NextNumber(0.9, 1.15)
		terrain:FillBall(
			origin + Vector3.new(
				math.cos(angle) * distance,
				rng:NextNumber(1, 6),
				math.sin(angle) * distance
			),
			rng:NextNumber(16, 26),
			ground
		)
	end
end

-- Built structures ------------------------------------------------------------------

local function buildPier(folder: Folder, zoneId: string)
	local zone = Zones.Get(zoneId)
	local visuals = Visuals.Get(zoneId)
	local origin = zone.origin
	local start = islandRadius(zone) - 6
	local length = zone.radius * PIER_REACH

	local deckColor = Color3.fromRGB(104, 76, 52)

	-- Walkway, in planks so it reads as built rather than extruded.
	local planks = math.floor(length / 4)
	for index = 0, planks do
		local z = start + index * 4
		part(folder, {
			name = "Plank",
			size = Vector3.new(13, 0.8, 3.6),
			cframe = CFrame.new(origin + Vector3.new(0, PIER_TOP, z)),
			color = deckColor:Lerp(Color3.new(0, 0, 0), (index % 2) * 0.07),
			material = Enum.Material.WoodPlanks,
		})
	end

	-- Pilings and railings.
	for index = 0, planks, 3 do
		local z = start + index * 4
		for _, side in { -1, 1 } do
			part(folder, {
				name = "Piling",
				size = Vector3.new(1.1, PIER_TOP + WATER_DEPTH, 1.1),
				cframe = CFrame.new(
					origin + Vector3.new(side * 6, PIER_TOP - (PIER_TOP + WATER_DEPTH) / 2, z)
				),
				color = Color3.fromRGB(78, 58, 42),
				material = Enum.Material.Wood,
				collide = false,
			})
			part(folder, {
				name = "Post",
				size = Vector3.new(0.9, 3.6, 0.9),
				cframe = CFrame.new(origin + Vector3.new(side * 6, PIER_TOP + 2.2, z)),
				color = deckColor,
				material = Enum.Material.Wood,
			})
		end
	end

	for _, side in { -1, 1 } do
		part(folder, {
			name = "Rail",
			size = Vector3.new(0.7, 0.7, length + 4),
			cframe = CFrame.new(origin + Vector3.new(side * 6, PIER_TOP + 3.9, start + length / 2)),
			color = deckColor,
			material = Enum.Material.Wood,
			collide = false,
		})
	end

	-- Lanterns. In the dark zones these do most of the visual work.
	local lanternColor = visuals.ambient.color
	for _, offset in { 0.25, 0.75 } do
		local z = start + length * offset
		Props.Lantern(folder, CFrame.new(origin + Vector3.new(-6, PIER_TOP + 0.4, z)), lanternColor)
		Props.Lantern(folder, CFrame.new(origin + Vector3.new(6, PIER_TOP + 0.4, z)), lanternColor)
	end

	-- Head of the pier, where you actually fish from.
	part(folder, {
		name = "PierHead",
		size = Vector3.new(22, 0.8, 12),
		cframe = CFrame.new(origin + Vector3.new(0, PIER_TOP, start + length + 5)),
		color = deckColor,
		material = Enum.Material.WoodPlanks,
	})

	return start + length + 5
end

local function buildSign(folder: Folder, zoneId: string)
	local zone = Zones.Get(zoneId)
	local visuals = Visuals.Get(zoneId)
	local origin = zone.origin
	local base = origin + Vector3.new(-14, ISLAND_TOP, islandRadius(zone) - 10)

	part(folder, {
		name = "SignPost",
		size = Vector3.new(1, 12, 1),
		cframe = CFrame.new(base + Vector3.new(0, 6, 0)),
		color = Color3.fromRGB(74, 54, 40),
		material = Enum.Material.Wood,
	})

	local board = part(folder, {
		name = "SignBoard",
		size = Vector3.new(15, 4.4, 0.6),
		cframe = CFrame.new(base + Vector3.new(0, 12.4, 0)) * CFrame.Angles(0, math.rad(18), 0),
		color = Color3.fromRGB(56, 42, 32),
		material = Enum.Material.Wood,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(600, 176)
	surface.LightInfluence = 0
	surface.Parent = board

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = string.upper(zone.name)
	label.TextColor3 = visuals.ambient.color
	label.TextScaled = true
	label.Parent = surface

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 84
	constraint.Parent = label

	return board
end

local function dress(folder: Folder, zoneId: string, rng: Random)
	local zone = Zones.Get(zoneId)
	local visuals = Visuals.Get(zoneId)
	local origin = zone.origin
	local radius = islandRadius(zone)
	local propMaterial = Visuals.Material(visuals.prop)

	local function scatter(count: number, place: (CFrame) -> ())
		for _ = 1, count do
			local angle = rng:NextNumber(0, math.pi * 2)
			-- Kept inside the flat core so nothing ends up floating over the
			-- sculpted coastline.
			local distance = rng:NextNumber(radius * 0.3, radius * 0.86)
			-- Leave the pier corridor clear.
			if math.abs(math.cos(angle)) < 0.24 and math.sin(angle) > 0 then
				angle += 0.9
			end

			place(CFrame.new(
				origin + Vector3.new(math.cos(angle) * distance, ISLAND_TOP - 1, math.sin(angle) * distance)
			) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		end
	end

	local plan = DRESSING[zoneId] or {}

	scatter(plan.tree or 0, function(cframe)
		Props.Tree(folder, cframe, rng, Color3.fromRGB(84, 60, 42), visuals.propColor)
	end)

	scatter(plan.rock or 0, function(cframe)
		Props.Rock(folder, cframe, rng, visuals.propColor:Lerp(Color3.new(0, 0, 0), 0.4), propMaterial)
	end)

	scatter(plan.fan or 0, function(cframe)
		Props.Fan(folder, cframe, rng, visuals.ambient.color)
	end)

	scatter(plan.shard or 0, function(cframe)
		Props.Shard(folder, cframe, rng, visuals.propColor, propMaterial, false)
	end)

	scatter(plan.glowShard or 0, function(cframe)
		local shard = Props.Shard(folder, cframe, rng, visuals.ambient.color, Enum.Material.Neon, true)
		if zoneId == "rift" then
			Props.Float(shard, rng)
		end
	end)
end

-- Build ----------------------------------------------------------------------------

function MapBuilder.Build(): Folder
	local existing = Workspace:FindFirstChild(ROOT_NAME)
	if existing then
		existing:Destroy()
	end

	-- Start from nothing so a rebuild in Studio is idempotent.
	Workspace.Terrain:Clear()

	local root = Instance.new("Folder")
	root.Name = ROOT_NAME
	root.Parent = Workspace

	local rng = Random.new(20260930)

	for _, zoneId in Zones.Order do
		local folder = Instance.new("Folder")
		folder.Name = zoneId
		folder.Parent = root

		sculpt(zoneId, rng)
		buildPier(folder, zoneId)
		buildSign(folder, zoneId)
		dress(folder, zoneId, rng)
	end

	local startZone = Zones.Get(Zones.Default())
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.new(
		startZone.origin + Vector3.new(0, ISLAND_TOP + 0.5, islandRadius(startZone) * 0.2)
	)
	spawn.Color = Color3.fromRGB(96, 76, 56)
	spawn.Material = Enum.Material.WoodPlanks
	spawn.Parent = root

	return root
end

-- Where a player should stand when they arrive in a zone: the head of the pier.
function MapBuilder.ArrivalPoint(zoneId: string): Vector3
	local zone = Zones.Get(zoneId)
	local start = islandRadius(zone) - 6
	local length = zone.radius * PIER_REACH
	return zone.origin + Vector3.new(0, PIER_TOP + 4, start + length)
end

return MapBuilder
