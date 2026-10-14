--!strict
-- Big chunky set pieces, one set per zone, so each zone reads from across the board.
-- Parts tagged with Spin (deg/s) and SpinAxis, or Bob (studs), are animated on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage.Shared.Palette)

type PartFn = ({ [string]: any }) -> Part
type CellFn = (number, number) -> Vector3

local Landmarks = {}

local rgb = Color3.fromRGB

-- A faceted "low-poly" sphere: three blocks rotated against each other.
local function chunkyBall(make: PartFn, parent: Instance, cf: CFrame, size: number, color: Color3, name: string)
	local parts = {}
	for i, angles in
		{
			CFrame.Angles(0, 0, 0),
			CFrame.Angles(0, math.rad(45), 0),
			CFrame.Angles(math.rad(45), 0, math.rad(45)),
		}
	do
		table.insert(
			parts,
			make({
				Name = name .. i,
				Size = Vector3.new(size, size * 0.86, size),
				CFrame = cf * angles,
				Color = color,
				Parent = parent,
			})
		)
	end
	return parts
end

local function sign(parent: Instance, make: PartFn, cf: CFrame, size: Vector2, text: string, color: Color3, ink: Color3)
	local board = make({
		Name = "Sign",
		Size = Vector3.new(size.X, size.Y, 0.6),
		CFrame = cf,
		Color = color,
		Parent = parent,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.Arcade
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = ink
	l.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.14, 0)
	pad.PaddingBottom = UDim.new(0.14, 0)
	pad.Parent = l
	return board
end

local builders: { [string]: (Instance, CellFn, PartFn) -> () } = {}

builders.orange = function(parent, cell, make)
	local colors = Palette.zones.orange
	local base = CFrame.new(cell(22.2, 21.3))

	make({
		Name = "Footing",
		Size = Vector3.new(14, 1.6, 14),
		CFrame = base * CFrame.new(0, 0.8, 0),
		Color = Palette.plateEdge,
		Parent = parent,
	})
	make({
		Name = "FootingTrim",
		Size = Vector3.new(14.3, 0.3, 14.3),
		CFrame = base * CFrame.new(0, 1.6, 0),
		Color = colors.trim,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	make({
		Name = "Tower",
		Size = Vector3.new(7, 16, 7),
		CFrame = base * CFrame.new(0, 9.6, 0),
		Color = rgb(240, 236, 228),
		Parent = parent,
	})
	make({
		Name = "TowerBand",
		Size = Vector3.new(7.3, 1.4, 7.3),
		CFrame = base * CFrame.new(0, 13, 0),
		Color = colors.plate,
		Parent = parent,
	})
	-- Reamer: stacked turned blocks narrowing to a point.
	for i = 0, 4 do
		local s = 10 - i * 2
		make({
			Name = "Reamer" .. i,
			Size = Vector3.new(s, 1.2, s),
			CFrame = base * CFrame.new(0, 18.2 + i * 1.2, 0) * CFrame.Angles(0, math.rad(i * 18), 0),
			Color = if i % 2 == 0 then rgb(250, 248, 242) else rgb(226, 222, 214),
			Parent = parent,
		})
	end
	local orangeCF = base * CFrame.new(0, 29.5, 0)
	chunkyBall(make, parent, orangeCF, 11, Palette.orange, "BigOrange")
	make({
		Name = "Leaf",
		Size = Vector3.new(4.5, 0.6, 2.2),
		CFrame = orangeCF * CFrame.new(1.8, 5.4, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		Color = Palette.leaf,
		Parent = parent,
	})
	make({
		Name = "Stem",
		Size = Vector3.new(0.8, 1.6, 0.8),
		CFrame = orangeCF * CFrame.new(0, 5.6, 0),
		Color = Palette.bark,
		Parent = parent,
	})
	-- Spout pouring toward the press.
	make({
		Name = "Spout",
		Size = Vector3.new(1.6, 1.6, 5),
		CFrame = base * CFrame.new(0, 12, -5.5),
		Color = rgb(240, 236, 228),
		Parent = parent,
	})
	make({
		Name = "Pour",
		Size = Vector3.new(0.8, 10.4, 0.8),
		CFrame = base * CFrame.new(0, 6.6, -7.6),
		Color = colors.neon,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		CanCollide = false,
		Parent = parent,
	})
end

builders.vitamin = function(parent, cell, make)
	local colors = Palette.zones.vitamin
	local base = CFrame.new(cell(2.6, 20.4))
	local body = rgb(232, 236, 228)

	make({
		Name = "Footing",
		Size = Vector3.new(16, 1.4, 16),
		CFrame = base * CFrame.new(0, 0.7, 0),
		Color = Palette.plateEdge,
		Parent = parent,
	})
	make({
		Name = "Tower",
		Size = Vector3.new(11, 34, 11),
		CFrame = base * CFrame.new(0, 18.4, 0),
		Color = body,
		Parent = parent,
	})
	make({
		Name = "Cap",
		Size = Vector3.new(13, 1.6, 13),
		CFrame = base * CFrame.new(0, 36.2, 0),
		Color = colors.plate,
		Parent = parent,
	})
	make({
		Name = "Mast",
		Size = Vector3.new(0.8, 9, 0.8),
		CFrame = base * CFrame.new(2.5, 41.5, 2),
		Color = Palette.plateEdge,
		Parent = parent,
	})
	make({
		Name = "MastLight",
		Size = Vector3.new(1.4, 1.4, 1.4),
		CFrame = base * CFrame.new(2.5, 46.4, 2),
		Color = colors.neon,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	-- Glowing windows on the two faces players see first.
	for row = 0, 5 do
		for col = -1, 1 do
			local lit = (row * 3 + col) % 4 ~= 0
			for _, face in
				{
					{ Vector3.new(col * 3.2, 0, -5.55), Vector3.new(2, 2.6, 0.2) },
					{ Vector3.new(5.55, 0, col * 3.2), Vector3.new(0.2, 2.6, 2) },
				}
			do
				make({
					Name = "Window",
					Size = face[2],
					CFrame = base * CFrame.new(face[1] + Vector3.new(0, 7 + row * 4.6, 0)),
					Color = if lit then colors.neon else rgb(40, 52, 36),
					Material = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic,
					Parent = parent,
				})
			end
		end
	end
	-- A giant flask beside the tower.
	local flask = base * CFrame.new(10, 0, -3)
	make({
		Name = "FlaskBase",
		Size = Vector3.new(7, 5, 7),
		CFrame = flask * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = colors.plate,
		Parent = parent,
	})
	make({
		Name = "FlaskNeck",
		Size = Vector3.new(2.4, 6, 2.4),
		CFrame = flask * CFrame.new(0, 8, 0),
		Color = body,
		Parent = parent,
	})
	make({
		Name = "FlaskLip",
		Size = Vector3.new(3.2, 0.8, 3.2),
		CFrame = flask * CFrame.new(0, 11.2, 0),
		Color = body,
		Parent = parent,
	})
end

builders.zest = function(parent, cell, make)
	local colors = Palette.zones.zest
	local base = CFrame.new(cell(2.8, 3.2)) * CFrame.Angles(0, math.rad(20), 0)
	local metal = rgb(214, 214, 222)

	make({
		Name = "Footing",
		Size = Vector3.new(18, 1.4, 14),
		CFrame = base * CFrame.new(0, 0.7, 0),
		Color = Palette.plateEdge,
		Parent = parent,
	})
	make({
		Name = "Body",
		Size = Vector3.new(14, 12, 10),
		CFrame = base * CFrame.new(0, 7.4, 0),
		Color = colors.plate,
		Parent = parent,
	})
	make({
		Name = "Hopper",
		Size = Vector3.new(10, 5, 8),
		CFrame = base * CFrame.new(0, 15.9, 0),
		Color = metal,
		Parent = parent,
	})
	make({
		Name = "HopperTrim",
		Size = Vector3.new(10.3, 0.4, 8.3),
		CFrame = base * CFrame.new(0, 18.4, 0),
		Color = colors.trim,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	-- Two grater drums on the front and a gear on the side, spun by the client.
	for i, x in { -3.2, 3.2 } do
		local drum = make({
			Name = "Drum" .. i,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(4, 5, 5),
			CFrame = base * CFrame.new(x, 6, -5.6) * CFrame.Angles(0, math.rad(90), 0),
			Color = metal,
			Parent = parent,
		})
		drum:SetAttribute("Spin", if i == 1 then 120 else -120)
		drum:SetAttribute("SpinAxis", Vector3.xAxis)
	end
	local gear = make({
		Name = "Gear",
		Size = Vector3.new(1, 7, 7),
		CFrame = base * CFrame.new(7.4, 9, 0),
		Color = rgb(70, 66, 80),
		Parent = parent,
	})
	gear:SetAttribute("Spin", 45)
	gear:SetAttribute("SpinAxis", Vector3.xAxis)
	local gear2 = make({
		Name = "GearCross",
		Size = Vector3.new(1, 7, 7),
		CFrame = base * CFrame.new(7.4, 9, 0) * CFrame.Angles(math.rad(45), 0, 0),
		Color = rgb(70, 66, 80),
		Parent = parent,
	})
	gear2:SetAttribute("Spin", 45)
	gear2:SetAttribute("SpinAxis", Vector3.xAxis)
	-- A curl of peel coming off the front.
	for i = 0, 3 do
		make({
			Name = "Peel" .. i,
			Size = Vector3.new(1.2, 0.5, 2.2),
			CFrame = base * CFrame.new(-1 + i * 0.7, 3 - i * 0.6, -8 - i * 1.4) * CFrame.Angles(math.rad(i * 25), 0, 0),
			Color = Palette.orange,
			Parent = parent,
		})
	end
end

builders.juice = function(parent, cell, make)
	local colors = Palette.zones.juice
	local base = CFrame.new(cell(14.5, 2.4))
	local wood = rgb(236, 230, 218)

	make({
		Name = "Floor",
		Size = Vector3.new(16, 0.6, 10),
		CFrame = base * CFrame.new(0, 0.3, -1),
		Color = Palette.plateEdge,
		Parent = parent,
	})
	make({
		Name = "Counter",
		Size = Vector3.new(14, 4, 2.6),
		CFrame = base * CFrame.new(0, 2.6, 2),
		Color = wood,
		Parent = parent,
	})
	make({
		Name = "CounterFront",
		Size = Vector3.new(14.2, 1.2, 2.8),
		CFrame = base * CFrame.new(0, 3, 2),
		Color = colors.plate,
		Parent = parent,
	})
	make({
		Name = "CounterTop",
		Size = Vector3.new(14.6, 0.4, 3.2),
		CFrame = base * CFrame.new(0, 4.8, 2),
		Color = Palette.plateEdge,
		Parent = parent,
	})
	for _, x in { -6.6, 6.6 } do
		make({
			Name = "Post",
			Size = Vector3.new(0.8, 11, 0.8),
			CFrame = base * CFrame.new(x, 5.5, 2.8),
			Color = wood,
			Parent = parent,
		})
		make({
			Name = "BackPost",
			Size = Vector3.new(0.8, 13, 0.8),
			CFrame = base * CFrame.new(x, 6.5, -4.4),
			Color = wood,
			Parent = parent,
		})
	end
	make({
		Name = "Back",
		Size = Vector3.new(14, 12, 0.6),
		CFrame = base * CFrame.new(0, 6.6, -4.6),
		Color = colors.floorB,
		Parent = parent,
	})
	-- Striped awning, sloped toward the customer.
	local stripes = 8
	for i = 0, stripes - 1 do
		local w = 15 / stripes
		make({
			Name = "Awning" .. i,
			Size = Vector3.new(w, 0.4, 9),
			CFrame = base * CFrame.new(-7.5 + w * (i + 0.5), 12, -0.6) * CFrame.Angles(math.rad(-16), 0, 0),
			Color = if i % 2 == 0 then colors.plate else Palette.white,
			Parent = parent,
		})
		make({
			Name = "Flap" .. i,
			Size = Vector3.new(w, 1.4, 0.3),
			CFrame = base * CFrame.new(-7.5 + w * (i + 0.5), 10.1, 3.7),
			Color = if i % 2 == 0 then Palette.white else colors.plate,
			Parent = parent,
		})
	end
	-- A giant cup on the roof.
	local cup = base * CFrame.new(0, 14.5, -2)
	make({
		Name = "Cup",
		Size = Vector3.new(5, 6, 5),
		CFrame = cup * CFrame.new(0, 3, 0),
		Color = Palette.white,
		Parent = parent,
	})
	make({
		Name = "Juice",
		Size = Vector3.new(5.2, 3.6, 5.2),
		CFrame = cup * CFrame.new(0, 2.2, 0),
		Color = Palette.orange,
		Parent = parent,
	})
	make({
		Name = "Straw",
		Size = Vector3.new(0.6, 6, 0.6),
		CFrame = cup * CFrame.new(1, 7, 0) * CFrame.Angles(0, 0, math.rad(-14)),
		Color = colors.neon,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	for i = 0, 2 do
		make({
			Name = "Crate" .. i,
			Size = Vector3.new(3, 2.4, 3),
			CFrame = base * CFrame.new(9.4, 1.2 + i * 2.4, -2 + (i % 2) * 0.4) * CFrame.Angles(0, math.rad(i * 9), 0),
			Color = if i % 2 == 0 then rgb(176, 126, 74) else rgb(160, 112, 64),
			Parent = parent,
		})
	end
end

builders.golden = function(parent, cell, make)
	local colors = Palette.zones.golden
	local base = CFrame.new(cell(30.6, 5.2))
	local bark = rgb(54, 32, 86)

	make({
		Name = "Mound",
		Size = Vector3.new(16, 2, 16),
		CFrame = base * CFrame.new(0, 1, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = colors.floorB,
		Parent = parent,
	})
	make({
		Name = "MoundTrim",
		Size = Vector3.new(16.3, 0.3, 16.3),
		CFrame = base * CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = Palette.gold,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	make({
		Name = "Trunk",
		Size = Vector3.new(3.4, 14, 3.4),
		CFrame = base * CFrame.new(0, 9, 0),
		Color = bark,
		Parent = parent,
	})
	make({
		Name = "Branch1",
		Size = Vector3.new(2, 8, 2),
		CFrame = base * CFrame.new(-2.6, 15, 0) * CFrame.Angles(0, 0, math.rad(35)),
		Color = bark,
		Parent = parent,
	})
	make({
		Name = "Branch2",
		Size = Vector3.new(2, 8, 2),
		CFrame = base * CFrame.new(2.4, 16, 0.6) * CFrame.Angles(math.rad(-10), 0, math.rad(-38)),
		Color = bark,
		Parent = parent,
	})
	local leaves = {
		{ Vector3.new(0, 21, 0), 11, 0 },
		{ Vector3.new(-6, 18.5, 1), 7, 30 },
		{ Vector3.new(6, 19.5, -1), 8, 60 },
		{ Vector3.new(1, 25.5, 1.5), 6, 15 },
		{ Vector3.new(-2.5, 20, -4.5), 6, 75 },
	}
	for i, leaf in leaves do
		make({
			Name = "Crown" .. i,
			Size = Vector3.new(leaf[2], leaf[2] * 0.7, leaf[2]),
			CFrame = base * CFrame.new(leaf[1]) * CFrame.Angles(math.rad(leaf[3] * 0.3), math.rad(leaf[3]), 0),
			Color = if i % 2 == 0 then rgb(255, 214, 92) else Palette.gold,
			Parent = parent,
		})
	end
	-- Seeds floating around the crown.
	for i = 1, 6 do
		local angle = math.rad(i * 60)
		local seed = make({
			Name = "Seed" .. i,
			Size = Vector3.new(1.1, 1.5, 1.1),
			CFrame = base
				* CFrame.new(math.cos(angle) * 10, 14 + (i % 3) * 3, math.sin(angle) * 10)
				* CFrame.Angles(0, angle, math.rad(20)),
			Color = Palette.gold,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = parent,
		})
		seed:SetAttribute("Bob", 0.8)
	end
end

builders.vip = function(parent, cell, make)
	local colors = Palette.zones.vip
	-- Gate on the border with the Orange Grove.
	local gate = CFrame.lookAt(cell(23.5, 18.5), cell(22, 18.5))
	for _, z in { -6, 6 } do
		make({
			Name = "GatePost",
			Size = Vector3.new(2.4, 16, 2.4),
			CFrame = gate * CFrame.new(z, 8, 0),
			Color = Palette.plateEdge,
			Parent = parent,
		})
		make({
			Name = "GatePostTrim",
			Size = Vector3.new(2.6, 0.4, 2.6),
			CFrame = gate * CFrame.new(z, 14, 0),
			Color = colors.neon,
			Material = Enum.Material.Neon,
			Parent = parent,
		})
	end
	make({
		Name = "GateBeam",
		Size = Vector3.new(15, 2.4, 2.4),
		CFrame = gate * CFrame.new(0, 16.6, 0),
		Color = Palette.plateEdge,
		Parent = parent,
	})
	local plaque = sign(
		parent,
		make,
		gate * CFrame.new(0, 16.6, -1.4),
		Vector2.new(12, 2),
		"VIP ORCHARD",
		colors.floorB,
		Palette.white
	)
	plaque.Name = "GateSign"
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VipGate"
	prompt.ActionText = "See VIP Orchard"
	prompt.ObjectText = "Back Orchard"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	local anchor = make({
		Name = "GateAnchor",
		Size = Vector3.new(1, 1, 1),
		CFrame = gate * CFrame.new(0, 4, -2),
		Transparency = 1,
		CanCollide = false,
		Parent = parent,
	})
	prompt.Parent = anchor

	-- Lounge: a sunken rug, two sofas and a neon sign.
	local lounge = CFrame.new(cell(31.5, 21))
	make({
		Name = "Rug",
		Size = Vector3.new(22, 0.3, 12),
		CFrame = lounge * CFrame.new(0, 0.15, 0),
		Color = colors.floorB,
		Parent = parent,
	})
	make({
		Name = "RugTrim",
		Size = Vector3.new(22.4, 0.2, 12.4),
		CFrame = lounge * CFrame.new(0, 0.1, 0),
		Color = colors.neon,
		Material = Enum.Material.Neon,
		Parent = parent,
	})
	for i, x in { -6, 6 } do
		local sofa = lounge * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(if i == 1 then 90 else -90), 0)
		make({
			Name = "Seat",
			Size = Vector3.new(8, 2, 3.6),
			CFrame = sofa * CFrame.new(0, 1.3, 0),
			Color = rgb(244, 236, 240),
			Parent = parent,
		})
		make({
			Name = "SofaBack",
			Size = Vector3.new(8, 3, 1.2),
			CFrame = sofa * CFrame.new(0, 3, 1.8),
			Color = colors.plate,
			Parent = parent,
		})
		local seat = Instance.new("Seat")
		seat.Name = "Cushion"
		seat.Anchored = true
		seat.Size = Vector3.new(3, 0.4, 3)
		seat.CFrame = sofa * CFrame.new(0, 2.5, 0)
		seat.Transparency = 1
		seat.Parent = parent
	end
	make({
		Name = "Table",
		Size = Vector3.new(4, 1.6, 4),
		CFrame = lounge * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, math.rad(45), 0),
		Color = Palette.plateEdge,
		Parent = parent,
	})
	sign(
		parent,
		make,
		CFrame.lookAt(cell(31.5, 23.2) + Vector3.new(0, 9, 0), cell(31.5, 20) + Vector3.new(0, 9, 0)),
		Vector2.new(18, 4),
		"BACK ORCHARD",
		Palette.screen,
		colors.neon
	)
end

function Landmarks.build(zoneId: string, parent: Instance, cell: CellFn, make: PartFn)
	local builder = builders[zoneId]
	if builder then
		builder(parent, cell, make)
	end
end

return Landmarks
