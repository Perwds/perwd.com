--!strict
-- Greedy pacing check: lune run tools/simulate.lua [--log]
-- Picks by hand at a steady human rate, keeps every machine running and buys the cheapest affordable node.

local process = require("@lune/process")

local Config = require("../src/shared/Config")
local UpgradeTree = require("../src/shared/UpgradeTree")
local Economy = require("../src/shared/Economy")
local Format = require("../src/shared/Format")

local HAND_PICKS_PER_SECOND = 2 -- clicking plus walking between trees and plates
local DT = 1
local LIMIT = 6 * 3600

local logPurchases = table.find(process.args, "--log") ~= nil

local econ = Economy.new(Config, UpgradeTree)

local save = {
	currencies = { oranges = 0, vitamin = 0, zest = 0, crates = 0, seeds = 0 },
	peels = 0,
	levels = {} :: { [string]: number },
	machines = { lab = true, zester = true, juice = true },
	lifetimeCrates = 0,
	seedsClaimed = 0,
}

local targets = {
	{ id = "openlab", label = "Lab opens", lo = 3 * 60, hi = 5 * 60 },
	{ id = "openzest", label = "Zester opens", lo = 12 * 60, hi = 18 * 60 },
	{ id = "openjuice", label = "Juice Bar opens", lo = 34 * 60, hi = 46 * 60 },
	{ id = "goldentree", label = "First Replant", lo = 120 * 60, hi = 180 * 60 },
}
local reached: { [string]: number } = {}

local function clock(seconds: number): string
	return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

local function buyGreedy(t: number)
	while true do
		local best, bestCost = nil, math.huge
		for _, node in UpgradeTree.nodes do
			local ok, _, price = econ:canBuy(save, node.id, nil)
			if ok and price < bestCost then
				best, bestCost = node, price
			end
		end
		if not best then
			return
		end
		save.currencies[best.currency] -= bestCost
		save.levels[best.id] = (save.levels[best.id] or 0) + 1
		if logPurchases then
			print(
				string.format(
					"%s  %-22s -> %d  (%s %s)",
					clock(t),
					best.name,
					save.levels[best.id],
					Format.short(bestCost),
					best.currency
				)
			)
		end
		if not reached[best.id] then
			reached[best.id] = t
		end
	end
end

local trees = #Config.Orchard
local t = 0
while t < LIMIT and not reached.goldentree do
	local s = econ:stats(save.levels, nil)
	local supply = trees * s.treeCapacity / s.ripenSeconds
	local picks = math.min(HAND_PICKS_PER_SECOND, supply) * DT
	save.currencies.oranges += picks * s.pickValue
	econ:step(save, s, DT)
	t += DT
	buyGreedy(t)
end

print("Orange Grove pacing (greedy, " .. HAND_PICKS_PER_SECOND .. " hand picks/s)")
print(string.rep("-", 56))
local allOk = true
for _, target in targets do
	local at = reached[target.id]
	local ok = at ~= nil and at >= target.lo and at <= target.hi
	allOk = allOk and ok
	print(
		string.format(
			"%-16s %9s   target %s - %s   %s",
			target.label,
			if at then clock(at) else "never",
			clock(target.lo),
			clock(target.hi),
			if ok then "ok" else "MISS"
		)
	)
end

local s = econ:stats(save.levels, nil)
print(string.rep("-", 56))
print(string.format("Golden Seeds on first Replant: %d", econ:pendingSeeds(save, s)))
print(string.format(
	"Nodes bought: %d",
	(function()
		local n = 0
		for _ in save.levels do
			n += 1
		end
		return n
	end)()
))

if not allOk then
	process.exit(1)
end
