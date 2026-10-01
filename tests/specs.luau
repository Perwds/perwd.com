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
local Visuals = require(Shared.Config.Visuals)
local CatchRoll = require(Shared.CatchRoll)
local FishModel = require(Shared.FishModel)

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

print("== visuals ==")

-- Every zone must have a complete visual profile, or it renders as an untinted
-- grey void with no water.
local REQUIRED_SECTIONS = { "water", "lighting", "atmosphere", "clouds", "bloom", "sunRays", "correction", "dof", "ambient" }
local REQUIRED_MATERIALS = { "ground", "shore", "underwater", "prop" }

for _, zoneId in Zones.Order do
	local profile = Visuals.Data[zoneId]
	check(zoneId .. " has a visual profile", profile ~= nil)

	if profile then
		for _, section in REQUIRED_SECTIONS do
			check(
				string.format("%s.%s present", zoneId, section),
				type(profile[section]) == "table",
				"missing or not a table"
			)
		end

		for _, field in REQUIRED_MATERIALS do
			check(
				string.format("%s.%s names a material", zoneId, field),
				type(profile[field]) == "string" and #profile[field] > 0,
				tostring(profile[field])
			)
		end

		-- The ambient kind is the one cross-module reference in the visuals:
		-- Atmosphere looks the zone's kind up in Visuals.AmbientStyles.
		check(
			string.format("%s ambient kind %q resolves", zoneId, tostring(profile.ambient.kind)),
			Visuals.AmbientStyles[profile.ambient.kind] ~= nil
		)

		check(
			zoneId .. " water transparency in range",
			profile.water.transparency >= 0 and profile.water.transparency <= 1,
			tostring(profile.water.transparency)
		)
		check(
			zoneId .. " atmosphere density in range",
			profile.atmosphere.density >= 0 and profile.atmosphere.density <= 1,
			tostring(profile.atmosphere.density)
		)
		check(
			zoneId .. " clouds cover in range",
			profile.clouds.cover >= 0 and profile.clouds.cover <= 1,
			tostring(profile.clouds.cover)
		)
		check(zoneId .. " bloom is positive", profile.bloom.intensity > 0)
	end
end

-- The deeper zones should be visibly darker than the shallow ones; a flat
-- brightness curve is the clearest sign the profiles got shuffled.
check(
	"the abyss is the darkest zone",
	(function()
		local darkest, lowest = nil, math.huge
		for zoneId, profile in Visuals.Data do
			if profile.lighting.brightness < lowest then
				lowest = profile.lighting.brightness
				darkest = zoneId
			end
		end
		return darkest == "abyss"
	end)()
)

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

print("== fish models ==")

-- The roster's archetype list and FishModel's builder list must agree exactly,
-- in both directions: a fish with no builder renders as nothing, and a builder
-- nothing uses is dead code.
do
	local declared = Fish.Shapes()

	for shape in declared do
		check(
			string.format("shape %q has a builder", shape),
			type(FishModel.Shapes[shape]) == "function"
		)
	end

	for shape in FishModel.Shapes do
		check(string.format("builder %q is declared in the roster", shape), declared[shape] == true)
	end

	local used = {}
	for _, record in Fish.All do
		used[record.shape] = true
	end
	for shape in declared do
		check(string.format("shape %q is used by at least one fish", shape), used[shape] == true)
	end
end

-- Build every species in every mutation. These models cannot be eyeballed from
-- here, so the geometry is checked instead: nothing degenerate, nothing
-- infinite, and no part flung away from the body.
do
	local builds, worstParts, worstReach = 0, 0, 0
	local degenerate, flung, nonFinite, noPrimary, tooManyParts, collapsed = 0, 0, 0, 0, 0, 0
	local thinnest, thinnestId = math.huge, ""

	for _, record in Fish.All do
		for _, mutation in Mutations.Order do
			local weight = (record.minWeight + record.maxWeight) / 2
			local ok, model = pcall(FishModel.Build, record.id, mutation, weight)

			if not ok then
				check(
					string.format("%s / %s builds", record.id, mutation),
					false,
					tostring(model)
				)
				continue
			end

			builds += 1
			local length = FishModel.DisplayLength(record, weight)

			if model.PrimaryPart == nil then
				noPrimary += 1
			end

			local parts = 0
			local reach = 0
			local low = { math.huge, math.huge, math.huge }
			local high = { -math.huge, -math.huge, -math.huge }

			for _, child in model:GetChildren() do
				if child.ClassName ~= "Part" then
					continue
				end
				parts += 1

				local size = child.Size
				local position = child.CFrame.Position

				if
					size.X ~= size.X or size.Y ~= size.Y or size.Z ~= size.Z
					or position.X ~= position.X or position.Y ~= position.Y or position.Z ~= position.Z
					or size.X == math.huge or size.Y == math.huge or size.Z == math.huge
				then
					nonFinite += 1
				end

				if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
					degenerate += 1
				end

				local distance = position.Magnitude
				reach = math.max(reach, distance)
				if distance > length * 1.2 then
					flung += 1
				end

				local axes = { position.X, position.Y, position.Z }
				for axis = 1, 3 do
					low[axis] = math.min(low[axis], axes[axis])
					high[axis] = math.max(high[axis], axes[axis])
				end
			end

			worstParts = math.max(worstParts, parts)
			worstReach = math.max(worstReach, reach / length)

			if parts > FishModel.MaxParts then
				tooManyParts += 1
			end

			-- A fish should have real extent along its longest axis. Measured
			-- per axis rather than front-to-back, because an upright shape like
			-- the seahorse is legitimately shallow in Z.
			local span = 0
			for axis = 1, 3 do
				span = math.max(span, high[axis] - low[axis])
			end

			if span / length < thinnest then
				thinnest = span / length
				thinnestId = record.id .. "/" .. mutation
			end

			if record.shape ~= "orb" and span < length * 0.3 then
				collapsed += 1
			end
		end
	end

	check("every species builds in every mutation", builds == Fish.Count() * #Mutations.Order,
		string.format("%d of %d", builds, Fish.Count() * #Mutations.Order))
	check("every model has a PrimaryPart", noPrimary == 0, string.format("%d without", noPrimary))
	check("no part has a zero or negative dimension", degenerate == 0, string.format("%d bad", degenerate))
	check("no model collapses to a blob", collapsed == 0, string.format("%d collapsed", collapsed))
	check("no part size or position is NaN or infinite", nonFinite == 0, string.format("%d bad", nonFinite))
	check("no part sits further than 1.2x the body length from the origin", flung == 0,
		string.format("%d flung, worst reach %.2fx", flung, worstReach))
	check("every model stays within the part budget", tooManyParts == 0,
		string.format("%d over, worst %d of %d", tooManyParts, worstParts, FishModel.MaxParts))

	print(string.format(
		"  %d models built · worst %d/%d parts · worst reach %.2fx · thinnest %s at %.2fx length",
		builds, worstParts, FishModel.MaxParts, worstReach, thinnestId, thinnest
	))
end

-- Display length is log-mapped, so check the mapping behaves rather than the
-- raw weights.
do
	local minnow = Fish.Get("minnow")
	local god = Fish.Get("god_of_still_water")

	check(
		"a 40-tonne fish is bigger than a 50g one",
		FishModel.DisplayLength(god, 20000) > FishModel.DisplayLength(minnow, 0.3),
		string.format(
			"%.2f vs %.2f",
			FishModel.DisplayLength(god, 20000),
			FishModel.DisplayLength(minnow, 0.3)
		)
	)
	check(
		"but not 100,000x bigger, or it would not fit on screen",
		FishModel.DisplayLength(god, 20000) / FishModel.DisplayLength(minnow, 0.3) < 8
	)
	check(
		"a heavier catch of the same species is longer",
		FishModel.DisplayLength(minnow, minnow.maxWeight) > FishModel.DisplayLength(minnow, minnow.minWeight)
	)

	local shortest, longest = math.huge, 0
	for _, record in Fish.All do
		for _, weight in { record.minWeight, record.maxWeight } do
			local length = FishModel.DisplayLength(record, weight)
			shortest = math.min(shortest, length)
			longest = math.max(longest, length)
		end
	end
	check("every species lands in a usable size range", shortest > 0.4 and longest < 12,
		string.format("%.2f to %.2f studs", shortest, longest))
	print(string.format("  display length spans %.2f to %.2f studs", shortest, longest))
end

-- A mutation must visibly repaint the fish, or the rarest rolls look identical
-- to a plain one.
do
	local record = Fish.Get("carp")
	local plain = FishModel.Palette(record, "None")

	for _, mutation in Mutations.Order do
		if mutation == "None" then
			continue
		end
		local palette = FishModel.Palette(record, mutation)
		local shift = math.abs(palette.body.R - plain.body.R)
			+ math.abs(palette.body.G - plain.body.G)
			+ math.abs(palette.body.B - plain.body.B)
		local repainted = shift > 0.05 or palette.material ~= plain.material

		check(string.format("%s visibly changes the fish", mutation), repainted,
			string.format("colour shift %.3f, same material", shift))
	end

	check("the top mutations glow", FishModel.Palette(record, "Glitched").glow ~= nil)
	check("a plain fish does not glow", plain.glow == nil)
end

print("== hud scaling ==")

-- Real element footprints, from the code that builds them. If a panel grows,
-- these move and the fit assertions below catch it.
local REEL_HEIGHT = 320 + 68   -- ReelBar TRACK_HEIGHT + chrome
local REEL_WIDTH = 54 + 104    -- ReelBar TRACK_WIDTH + chrome
local PANEL_HEIGHT = 442       -- Panels root
local PANEL_WIDTH = 576

check(
	"HudTallest covers the tallest real element",
	GameConfig.HudTallest >= math.max(REEL_HEIGHT, PANEL_HEIGHT),
	string.format("%d vs %d", GameConfig.HudTallest, math.max(REEL_HEIGHT, PANEL_HEIGHT))
)
check(
	"HudWidest covers the widest real element",
	GameConfig.HudWidest >= math.max(REEL_WIDTH, PANEL_WIDTH),
	string.format("%d vs %d", GameConfig.HudWidest, math.max(REEL_WIDTH, PANEL_WIDTH))
)

-- Viewports the game will actually meet. Roblox mobile is landscape by default.
local VIEWPORTS = {
	{ name = "desktop 1080p", x = 1920, y = 1080, touch = false },
	{ name = "desktop 720p", x = 1280, y = 720, touch = false },
	{ name = "small window", x = 900, y = 500, touch = false },
	{ name = "tablet landscape", x = 1180, y = 820, touch = true },
	{ name = "phone landscape", x = 896, y = 414, touch = true },
	{ name = "small phone", x = 667, y = 375, touch = true },
	{ name = "very short phone", x = 800, y = 340, touch = true },
}

for _, viewport in VIEWPORTS do
	local scale = GameConfig.HudScale(viewport.x, viewport.y, viewport.touch)

	print(string.format(
		"  %-18s %4dx%-4d %-7s %.2fx  reel %.0fpx  label %.1fpx",
		viewport.name,
		viewport.x,
		viewport.y,
		viewport.touch and "touch" or "mouse",
		scale,
		REEL_HEIGHT * scale,
		11 * scale
	))

	check(
		string.format("%s: reel bar fits on screen", viewport.name),
		REEL_HEIGHT * scale <= viewport.y and REEL_WIDTH * scale <= viewport.x,
		string.format("%.0fpx tall in a %dpx viewport at %.2fx", REEL_HEIGHT * scale, viewport.y, scale)
	)
	check(
		string.format("%s: panel fits on screen", viewport.name),
		PANEL_HEIGHT * scale <= viewport.y and PANEL_WIDTH * scale <= viewport.x,
		string.format("%.0fx%.0f in %dx%d at %.2fx", PANEL_WIDTH * scale, PANEL_HEIGHT * scale, viewport.x, viewport.y, scale)
	)
	check(
		string.format("%s: scale stays in bounds", viewport.name),
		scale >= 0.5 and scale <= 1.4,
		string.format("%.3f", scale)
	)
	-- Text must not end up microscopic: the smallest label is 11px.
	check(
		string.format("%s: smallest label stays above 7px", viewport.name),
		11 * scale >= 7,
		string.format("%.1fpx", 11 * scale)
	)
end

check("a touch device never scales smaller than the same viewport on desktop", (function()
	for _, viewport in VIEWPORTS do
		if GameConfig.HudScale(viewport.x, viewport.y, true) < GameConfig.HudScale(viewport.x, viewport.y, false) then
			return false
		end
	end
	return true
end)())

check(
	"a degenerate viewport falls back to 1x rather than dividing by zero",
	GameConfig.HudScale(0, 0, false) == 1
)

check(
	"a bigger screen never scales the HUD smaller",
	GameConfig.HudScale(1920, 1080, false) >= GameConfig.HudScale(1280, 720, false)
)

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
