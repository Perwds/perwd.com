--[[
	Weighted random selection, used for egg pools and wild egg rarity.

	Rolls come from a caller-supplied Random so the server can keep one
	stream per purpose and stay deterministic under test.
]]

local WeightedPicker = {}

-- Fallback stream for callers that do not bring their own. Shared rather
-- than allocated per call, since picking runs on every hatch.
local defaultRandom = Random.new()

--[[
	entries: array of tables that each carry a numeric `weight`
	rng:     optional Random
	bias:    optional function(entry) -> number multiplier on that entry's
	         weight. Used for luck potions and the night rarity boost.
]]
function WeightedPicker.pick(entries: { any }, rng: Random?, bias: ((any) -> number)?)
	if #entries == 0 then
		return nil
	end

	local random = rng or defaultRandom

	local total = 0
	for _, entry in entries do
		local weight = entry.weight or 0
		if bias then
			weight *= bias(entry)
		end
		total += math.max(0, weight)
	end

	if total <= 0 then
		return entries[math.max(1, random:NextInteger(1, #entries))]
	end

	local roll = random:NextNumber() * total
	local cursor = 0

	for _, entry in entries do
		local weight = entry.weight or 0
		if bias then
			weight *= bias(entry)
		end
		cursor += math.max(0, weight)
		if roll <= cursor then
			return entry
		end
	end

	return entries[#entries]
end

--- Pick `count` times with replacement. Used by the 3x / 10x / 50x buttons.
function WeightedPicker.pickMany(entries: { any }, count: number, rng: Random?, bias: ((any) -> number)?)
	local out = table.create(count)
	for _ = 1, count do
		table.insert(out, WeightedPicker.pick(entries, rng, bias))
	end
	return out
end

return WeightedPicker
