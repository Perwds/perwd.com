--!nonstrict
-- Assertions and a balance simulation over the real shared modules.
-- `Shared` and `require` are provided by the generated harness.

local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Fish = require(Shared.Config.Fish)
local Rods = require(Shared.Config.Rods)
local Zones = require(Shared.Config.Zones)
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)
local CatchRoll = require(Shared.CatchRoll)

local passed, failed = 0, 0

local function check(name, condition, detail)
	if condition then
		passed += 1
	else
		failed += 1
		print(string.format("  FAIL  %s%s", name, detail and ("  -> " .. detail) or ""))
	end
end

local function near(a, b, tolerance)
	return math.abs(a - b) <= tolerance
end

print("== roster ==")

check("55 fish defined", Fish.Count() == 55, "got " .. Fish.Count())

local perZone = {}
for _, record in Fish.All do
	perZone[record.zone] = (perZone[record.zone] or 0) + 1
end
for _, zoneId in Zones.Order do
	check(
		zoneId .. " has at least 7 fish",
		(perZone[zoneId] or 0) >= 7,
		tostring(perZone[zoneId]) .. " fish"
	)
end

check("every zone reachable by coin progression", (function()
	local previous = -1
	for _, zoneId in Zones.Order do
		local unlock = Zones.Get(zoneId).unlockCoins
		if unlock <= previous then
			return false
		end
		previous = unlock
	end
	return true
end)(), "unlock costs must strictly increase")

check("every rod cost strictly increases", (function()
	local previous = -1
	for _, rodId in Rods.Order do
		local cost = Rods.Get(rodId).cost
		if cost <= previous and cost ~= 0 then
			return false
		end
		previous = cost
	end
	return true
end)())

print("== odds ==")

-- The per-zone effective odds must be a complete probability distribution.
for _, zoneId in Zones.Order do
	local tiers = Fish.TiersFor(zoneId)
	local total = 0
	for tierName in tiers do
		total += 1 / Rarities.EffectiveOdds(tierName, 1, tiers)
	end
	check(
		zoneId .. " odds sum to 1",
		near(total, 1, 1e-9),
		string.format("%.12f", total)
	)
end

-- Luck must make rare things rarer-to-find, never the reverse.
for _, zoneId in Zones.Order do
	local tiers = Fish.TiersFor(zoneId)
	local rarest
	for _, tierName in Rarities.Order do
		if tiers[tierName] then
			rarest = tierName
		end
	end

	local atOne = Rarities.EffectiveOdds(rarest, 1, tiers)
	local atFive = Rarities.EffectiveOdds(rarest, 5, tiers)
	check(
		zoneId .. " luck improves " .. rarest,
		atFive < atOne,
		string.format("1 in %.0f -> 1 in %.0f", atOne, atFive)
	)
end

check("common is never improved by luck", (function()
	local tiers = Fish.TiersFor("pond")
	return Rarities.EffectiveOdds("Common", 6, tiers) > Rarities.EffectiveOdds("Common", 1, tiers)
end)(), "luck should shift share out of Common, not into it")

print("== empirical roll distribution ==")

local rng = Random.new(20260930)
local SAMPLES = 300000
local counts = {}
local mutationCounts = {}

for _ = 1, SAMPLES do
	local catch = CatchRoll.Roll("pond", 1, rng)
	counts[catch.rarity] = (counts[catch.rarity] or 0) + 1
	mutationCounts[catch.mutation] = (mutationCounts[catch.mutation] or 0) + 1
end

local pondTiers = Fish.TiersFor("pond")
for _, tierName in Rarities.Order do
	if not pondTiers[tierName] then
		continue
	end

	local expected = SAMPLES / Rarities.EffectiveOdds(tierName, 1, pondTiers)
	local observed = counts[tierName] or 0

	if expected >= 400 then
		local drift = math.abs(observed - expected) / expected
		check(
			string.format("%s within 10%% of expected", tierName),
			drift < 0.1,
			string.format("expected %.0f, observed %d (%.1f%% off)", expected, observed, drift * 100)
		)
	else
		print(string.format("  note  %s: expected %.1f, observed %d (too rare to assert)", tierName, expected, observed))
	end
end

do
	local expectedShiny = SAMPLES / (1 / Mutations.WeightWithLuck("Shiny", 1) * (function()
		local total = 0
		for _, name in Mutations.Order do
			total += Mutations.WeightWithLuck(name, 1)
		end
		return total
	end)())
	local observed = mutationCounts.Shiny or 0
	check(
		"shiny rate within 12% of expected",
		math.abs(observed - expectedShiny) / expectedShiny < 0.12,
		string.format("expected %.0f, observed %d", expectedShiny, observed)
	)
end

print("== formatting ==")

check("Abbreviate(0)", Format.Abbreviate(0) == "0", Format.Abbreviate(0))
check("Abbreviate(100)", Format.Abbreviate(100) == "100", Format.Abbreviate(100))
check("Abbreviate(999)", Format.Abbreviate(999) == "999", Format.Abbreviate(999))
check("Abbreviate(1500)", Format.Abbreviate(1500) == "1.5K", Format.Abbreviate(1500))
check("Abbreviate(1000000)", Format.Abbreviate(1000000) == "1M", Format.Abbreviate(1000000))
check("Abbreviate(2500000000)", Format.Abbreviate(2500000000) == "2.5B", Format.Abbreviate(2500000000))
check("Abbreviate(-4200)", Format.Abbreviate(-4200) == "-4.2K", Format.Abbreviate(-4200))
check("Commas(0)", Format.Commas(0) == "0", Format.Commas(0))
check("Commas(999)", Format.Commas(999) == "999", Format.Commas(999))
check("Commas(1234567)", Format.Commas(1234567) == "1,234,567", Format.Commas(1234567))
check("Weight(0.5)", Format.Weight(0.5) == "500 g", Format.Weight(0.5))
check("Odds(1200)", Format.Odds(1200) == "1 in 1.2K", Format.Odds(1200))

print("== progression ==")

check("level 1 at 0 xp", GameConfig.LevelForXp(0) == 1)
check("levels increase with xp", (function()
	local previous = 0
	for xp = 0, 400000, 4000 do
		local level = GameConfig.LevelForXp(xp)
		if level < previous then
			return false
		end
		previous = level
	end
	return true
end)())

check("base luck is exactly 1", near(CatchRoll.Luck("wooden", "pond", 1), 1, 1e-12))
check(
	"best rod in best zone beats 20x luck",
	CatchRoll.Luck("eventide", "rift", 50) > 20,
	string.format("%.2f", CatchRoll.Luck("eventide", "rift", 50))
)

-- The server rejects a claimed win faster than MinReelSeconds. If a rod ever
-- gets fast enough to beat that honestly, the best rod in the game silently
-- stops working. Catch it here instead.
do
	local bestFill = 0
	local bestRod
	for _, rodId in Rods.Order do
		local fill = Rods.Get(rodId).fillRate
		if fill > bestFill then
			bestFill = fill
			bestRod = rodId
		end
	end

	local fastestLegitimate = (1 - GameConfig.ReelStartProgress) / bestFill
	check(
		"anti-cheat floor sits below the fastest legitimate reel",
		GameConfig.MinReelSeconds < fastestLegitimate,
		string.format(
			"%s can win in %.2fs but the floor is %.2fs",
			bestRod,
			fastestLegitimate,
			GameConfig.MinReelSeconds
		)
	)
	check(
		"anti-cheat floor keeps at least 15% margin",
		GameConfig.MinReelSeconds <= fastestLegitimate * 0.85,
		string.format("floor %.2fs vs fastest %.2fs", GameConfig.MinReelSeconds, fastestLegitimate)
	)
	check(
		"reel timeout is longer than any honest reel",
		GameConfig.MaxReelSeconds > fastestLegitimate * 10
	)
end

print("== economy simulation ==")

-- Average coins per cast in each zone with the rod a player would plausibly
-- hold there, then how many casts the next unlock costs at that rate.
local simRng = Random.new(1337)
local SIM = 40000
local rodForZone = {
	pond = "wooden",
	reef = "fiberglass",
	frost = "carbon",
	volcano = "enchanted",
	abyss = "abyssal",
	rift = "celestial",
}

local averages = {}
for _, zoneId in Zones.Order do
	local rodId = rodForZone[zoneId]
	local luck = CatchRoll.Luck(rodId, zoneId, 20)
	local total = 0
	for _ = 1, SIM do
		total += CatchRoll.Roll(zoneId, luck, simRng).value
	end

	local average = total / SIM
	averages[zoneId] = average

	print(string.format(
		"  %-9s %-11s luck x%-6.2f avg %s coins/catch",
		zoneId,
		Rods.Get(rodId).name,
		luck,
		Format.Commas(math.floor(average))
	))
end

for index = 1, #Zones.Order - 1 do
	local here = Zones.Order[index]
	local next = Zones.Order[index + 1]
	local casts = Zones.Get(next).unlockCoins / averages[here]

	print(string.format(
		"  %-9s -> %-9s ~%s catches to unlock",
		here,
		next,
		Format.Commas(math.floor(casts))
	))

	check(
		string.format("%s -> %s is reachable in under 20k catches", here, next),
		casts < 20000,
		string.format("%.0f catches", casts)
	)
	check(
		string.format("%s -> %s is not trivial", here, next),
		casts > 30,
		string.format("%.0f catches", casts)
	)
end

check("each zone out-earns the one before it", (function()
	for index = 2, #Zones.Order do
		if averages[Zones.Order[index]] <= averages[Zones.Order[index - 1]] then
			return false
		end
	end
	return true
end)())

print("")
print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	error(string.format("%d assertion(s) failed", failed), 0)
end
