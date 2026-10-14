--!strict
-- Static check of UpgradeTree.lua against the board: lune run tools/checkboard.lua
-- Plates must not overlap each other or the set pieces, every path must route clear of other plates,
-- parents must exist with no cycles, and each node must sit in the zone it claims.

local process = require("@lune/process")

local Config = require("../src/shared/Config")
local UpgradeTree = require("../src/shared/UpgradeTree")

type Rect = { x0: number, y0: number, x1: number, y1: number, what: string }

local GRID = Config.Grid
local HALF_W = GRID.plateWidth / GRID.cell / 2 + 0.03
local HALF_D = GRID.plateDepth / GRID.cell / 2 + 0.03
local PATH_HALF = 1 / GRID.cell

local problems: { string } = {}
local function fail(message: string)
	table.insert(problems, message)
end

local function around(x: number, y: number, rx: number, ry: number, what: string): Rect
	return { x0 = x - rx, y0 = y - ry, x1 = x + rx, y1 = y + ry, what = what }
end

local function overlaps(a: Rect, b: Rect): boolean
	return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1
end

-- Set pieces, machines and trees, in cells (mirrors BoardBuilder and Landmarks).
local props: { Rect } = {
	around(22, 17.6, 0.6, 0.6, "Orange Press"),
	around(7, 20.2, 0.6, 0.45, "Vitamin Lab screen"),
	around(7.5, 3.6, 0.6, 0.45, "Zester screen"),
	around(19.6, 2.8, 0.6, 0.45, "Juice Bar screen"),
	around(31.2, 8.6, 0.45, 0.6, "Golden Tree screen"),
	around(22.2, 21.3, 0.5, 0.5, "juicer tower"),
	around(2.6, 20.4, 0.55, 0.55, "lab tower"),
	around(3.2, 20.2, 0.3, 0.3, "flask"),
	around(2.8, 3.2, 0.75, 0.65, "zester landmark"),
	around(14.5, 2.4, 0.6, 0.45, "juice stand"),
	around(30.6, 5.2, 0.75, 0.75, "golden tree"),
	around(31.5, 21, 0.75, 0.45, "VIP lounge"),
	around(17.5, 18, 0.3, 0.3, "spawn"),
	around(20.6, 18.4, 0.2, 0.2, "keeper"),
}
for i, cell in Config.Orchard do
	table.insert(props, around(cell[1], cell[2], 0.35, 0.35, "orange tree " .. i))
end
for i, cell in Config.VipOrchard do
	table.insert(props, around(cell[1], cell[2], 0.35, 0.35, "VIP tree " .. i))
end

local function zoneOf(gx: number, gy: number): string?
	local zx, zy = gx // GRID.zoneCells, gy // GRID.zoneCells
	for id, zone in Config.Zones do
		if zone.zx == zx and zone.zy == zy then
			return id
		end
	end
	return nil
end

local plates: { [string]: Rect } = {}
local count = 0
for _, node in UpgradeTree.nodes do
	count += 1
	if node.growth < 1.12 or node.growth > 1.6 then
		fail(node.id .. ": growth " .. node.growth .. " is outside 1.12-1.6")
	end
	if node.max < 1 then
		fail(node.id .. ": max level must be at least 1")
	end
	local zone = zoneOf(node.gx, node.gy)
	if zone ~= node.zone then
		fail(string.format("%s: sits in %s but says %s", node.id, tostring(zone), node.zone))
	end
	if node.permanent and node.currency ~= "seeds" then
		fail(node.id .. ": permanent nodes must cost Golden Seeds")
	end
	local rect = around(node.gx, node.gy, HALF_W, HALF_D, node.id)
	for otherId, other in plates do
		if overlaps(rect, other) then
			fail(node.id .. " overlaps plate " .. otherId)
		end
	end
	for _, prop in props do
		if overlaps(rect, prop) then
			fail(node.id .. " overlaps the " .. prop.what)
		end
	end
	plates[node.id] = rect
	for _, parent in node.parents do
		if not UpgradeTree.byId[parent] then
			fail(node.id .. ": unknown parent " .. parent)
		end
	end
end

-- Paths: L-shaped, horizontal first unless the node asks for vertical first.
local pathCount = 0
for _, node in UpgradeTree.nodes do
	for _, parentId in node.parents do
		local parent = UpgradeTree.byId[parentId]
		if parent then
			pathCount += 1
			local vertical = node.bend and node.bend[parentId] == "v"
			local corner = if vertical then { parent.gx, node.gy } else { node.gx, parent.gy }
			for _, seg in { { { parent.gx, parent.gy }, corner }, { corner, { node.gx, node.gy } } } do
				local a, b = seg[1], seg[2]
				local rect = {
					x0 = math.min(a[1], b[1]) - PATH_HALF,
					x1 = math.max(a[1], b[1]) + PATH_HALF,
					y0 = math.min(a[2], b[2]) - PATH_HALF,
					y1 = math.max(a[2], b[2]) + PATH_HALF,
					what = "path",
				}
				for otherId, other in plates do
					if otherId ~= node.id and otherId ~= parentId and overlaps(rect, other) then
						fail(string.format("path %s -> %s runs under plate %s", parentId, node.id, otherId))
					end
				end
				for _, prop in props do
					if overlaps(rect, prop) then
						fail(string.format("path %s -> %s runs into the %s", parentId, node.id, prop.what))
					end
				end
			end
		end
	end
end

-- Every node must trace back to the root without loops.
local function reachesRoot(id: string, seen: { [string]: boolean }): boolean
	if id == UpgradeTree.root then
		return true
	end
	if seen[id] then
		fail("cycle through " .. id)
		return false
	end
	seen[id] = true
	local node = UpgradeTree.byId[id]
	if not node or #node.parents == 0 then
		return false
	end
	for _, parent in node.parents do
		if not reachesRoot(parent, table.clone(seen)) then
			return false
		end
	end
	return true
end
for _, node in UpgradeTree.nodes do
	if not reachesRoot(node.id, {}) then
		fail(node.id .. " does not connect back to " .. UpgradeTree.root)
	end
end

print(string.format("%d nodes, %d paths, %d set pieces checked", count, pathCount, #props))
if #problems > 0 then
	for _, problem in problems do
		print("  " .. problem)
	end
	process.exit(1)
end
print("Board layout OK")
