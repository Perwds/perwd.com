--!strict
-- Unit checks for the shared modules: lune run tools/test.lua

local process = require("@lune/process")

local Config = require("../src/shared/Config")
local UpgradeTree = require("../src/shared/UpgradeTree")
local Economy = require("../src/shared/Economy")
local Format = require("../src/shared/Format")

local failures = 0
local function check(name: string, got: any, want: any)
	if got ~= want then
		failures += 1
		print(string.format("FAIL %s: got %s, want %s", name, tostring(got), tostring(want)))
	end
end

-- Format
check("short 0", Format.short(0), "0")
check("short 99.25", Format.short(99.25), "99.2")
check("short 120", Format.short(120.7), "120")
check("short 1410", Format.short(1410), "1.41K")
check("short 76550", Format.short(76550), "76.55K")
check("short 120400", Format.short(120400), "120.4K")
check("short 3.4M", Format.short(3.4e6), "3.4M")
check("short 5.6B", Format.short(5.6e9), "5.6B")
check("short 1e12", Format.short(1e12), "1.00e12")
check("short 2.5e15", Format.short(2.5e15), "2.50e15")
check("full 1410", Format.full(1410), "1,410")
check("full 1234567", Format.full(1234567), "1,234,567")
check("rate", Format.rate(10600), "+10.6K/s")
check("rate negative", Format.rate(-25), "-25/s")

local econ = Economy.new(Config, UpgradeTree)

local function blank()
	return {
		currencies = { oranges = 0, vitamin = 0, zest = 0, crates = 0, seeds = 0 },
		peels = 0,
		levels = {} :: { [string]: number },
		machines = { lab = true, zester = true, juice = true },
		lifetimeCrates = 0,
		seedsClaimed = 0,
	}
end

-- Buying rules
local save = blank()
check("root available", econ:nodeState(save.levels, "seed", nil), "available")
check("child locked", econ:nodeState(save.levels, "riper", nil), "locked")
check("grandchild hidden", econ:nodeState(save.levels, "marmalade", nil), "hidden")
local ok, reason = econ:canBuy(save, "seed", nil)
check("cannot afford root", ok, false)
check("reason afford", reason, "afford")
save.currencies.oranges = 10
ok = econ:canBuy(save, "seed", nil)
check("can afford root", ok, true)
ok, reason = econ:canBuy(save, "riper", nil)
check("parent missing", reason, "locked")
save.levels.seed = 1
ok, reason = econ:canBuy(save, "seed", nil)
check("root maxed", reason, "maxed")
check("unknown node", (econ:canBuy(save, "nope", nil)), false)

-- Multi-parent node needs every parent
save.levels.pressure = 1
check("grater needs beakers too", econ:nodeState(save.levels, "grater", nil), "locked")
save.levels.beakers = 1
check("grater open with both", econ:nodeState(save.levels, "grater", nil), "available")

-- Pass raises the picker cap
local picker = UpgradeTree.byId.picker
check("picker max", econ:maxLevel(picker, nil), 5)
check("picker max with pass", econ:maxLevel(picker, { ExtraPickers = true }), 8)

-- Costs grow and stay whole
check("cost level 0", econ:cost(UpgradeTree.byId.riper, 0), 20)
check("cost grows", econ:cost(UpgradeTree.byId.riper, 5) > econ:cost(UpgradeTree.byId.riper, 4), true)

-- Stats
local s = econ:stats({ seed = 1, riper = 2, marmalade = 1 }, { DoubleOranges = true })
check("pick value", s.pickValue, 2 * 1.5 * 4)
check("auto picker range", econ:stats({}, { AutoPicker = true }).collectRange, Config.Grove.autoPickerRange)
check("lab boost", econ:stats({}, { LabBoost = true }).labBoost, 2)

-- Machines never drive a balance negative
local run = blank()
run.levels = { seed = 1, picker = 1, openlab = 1, flasks = 1, openzest = 1, openjuice = 1 }
run.currencies.oranges = 30
local rs = econ:stats(run.levels, nil)
for _ = 1, 600 do
	econ:step(run, rs, 0.5)
	for id, value in run.currencies do
		if value < -1e-9 then
			check("negative " .. id, value, 0)
		end
	end
end
check("peels non-negative", run.peels >= 0, true)

-- Paused machines don't run
local paused = blank()
paused.levels = { openlab = 1 }
paused.machines.lab = false
paused.currencies.oranges = 1000
econ:step(paused, econ:stats(paused.levels, nil), 10)
check("paused lab keeps oranges", paused.currencies.oranges, 1000)

-- Replant keeps the right things
local levels = { seed = 1, picker = 5, openlab = 1, goldentree = 1, oldroots = 3, seedmemory = 1, riper = 4 }
local kept = econ:keptNodes(levels)
check("permanent kept", kept.oldroots, "full")
check("golden tree kept", kept.goldentree, "full")
check("seed memory keeps lab", kept.openlab, "one")
check("lab ancestors kept at one", kept.picker, "one")
check("riper not kept", kept.riper, nil)
check("zester not kept without Long Memory", kept.openzest, nil)

-- Golden Seeds
local prestige = blank()
prestige.lifetimeCrates = 450
local ps = econ:stats({ goldentree = 1 }, nil)
check("seeds from 450 crates", econ:pendingSeeds(prestige, ps), 3)
prestige.seedsClaimed = 3
check("no double claim", econ:pendingSeeds(prestige, ps), 0)

-- Data sanity
local ids = {}
for _, node in UpgradeTree.nodes do
	check("duplicate id " .. node.id, ids[node.id], nil)
	ids[node.id] = true
	check("one-line desc " .. node.id, string.find(node.desc, "\n"), nil)
end

if failures > 0 then
	print(failures .. " check(s) failed")
	process.exit(1)
end
print("All shared-module checks passed")
