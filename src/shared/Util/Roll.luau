--!nonstrict
-- Weighted selection. Every roll that decides player reward runs on the server
-- against a server-owned Random, so nothing here is seeded from client input.

local Roll = {}

-- entries: array of { weight = number, ... }. Returns the chosen entry.
function Roll.Weighted(entries, rng: Random)
	local total = 0
	for _, entry in entries do
		total += math.max(entry.weight, 0)
	end

	if total <= 0 then
		return entries[1]
	end

	local target = rng:NextNumber() * total
	local cursor = 0

	for _, entry in entries do
		cursor += math.max(entry.weight, 0)
		if target <= cursor then
			return entry
		end
	end

	-- Float drift only; the last entry is the correct fallback.
	return entries[#entries]
end

-- Picks a key from { [key] = weight }. Order is made deterministic by `order`
-- so the same rng stream gives the same answer across servers.
function Roll.WeightedKeys(weights: { [string]: number }, order: { string }, rng: Random): string
	local entries = {}
	for _, key in order do
		local weight = weights[key]
		if weight and weight > 0 then
			table.insert(entries, { key = key, weight = weight })
		end
	end

	if #entries == 0 then
		return order[1]
	end

	return Roll.Weighted(entries, rng).key
end

-- Biased toward the light end so a max-weight fish stays a story.
function Roll.Weight(minWeight: number, maxWeight: number, rng: Random): number
	local t = rng:NextNumber() ^ 2.2
	return minWeight + (maxWeight - minWeight) * t
end

return Roll
