--!strict
-- Pure game maths shared by the server and tools/simulate.lua. No Roblox APIs in here.

export type Stats = { [string]: any }
export type Mods = { [string]: boolean }

local Economy = {}
Economy.__index = Economy

export type Economy = typeof(setmetatable({} :: { config: any, tree: any }, Economy))

function Economy.new(config: any, tree: any): Economy
	return setmetatable({ config = config, tree = tree }, Economy)
end

function Economy.cost(_self: Economy, node: any, level: number): number
	local raw = node.base * node.growth ^ level
	if raw < 100 then
		return math.max(1, math.floor(raw + 0.5))
	end
	-- Round big costs to three significant figures so plates read cleanly.
	local magnitude = 10 ^ (math.floor(math.log10(raw)) - 2)
	return math.floor(raw / magnitude + 0.5) * magnitude
end

function Economy.maxLevel(_self: Economy, node: any, mods: Mods?): number
	local passMax = node.passMax
	if passMax and mods and mods[passMax.pass] then
		return node.max + passMax.add
	end
	return node.max
end

function Economy.stats(self: Economy, levels: { [string]: number }, mods: Mods?): Stats
	local s: Stats = table.clone(self.config.Base)
	local scaled = {}

	for _, node in self.tree.nodes do
		local level = levels[node.id] or 0
		if level > 0 then
			for _, effect in node.effects do
				if effect.op == "add" then
					s[effect.stat] += effect.value * level
				elseif effect.op == "unlock" then
					s[effect.stat] = true
				elseif effect.op == "pct" or effect.op == "mul" then
					table.insert(scaled, { effect = effect, level = level })
				end
			end
		end
	end
	for _, entry in scaled do
		local effect = entry.effect
		if effect.op == "pct" then
			s[effect.stat] *= 1 + effect.value * entry.level
		else
			s[effect.stat] *= effect.value ^ entry.level
		end
	end

	if mods then
		if mods.DoubleOranges then
			s.orangeMult *= 2
		end
		if mods.LabBoost then
			s.labBoost = 2
		end
		if mods.AutoPicker then
			s.collectRange = math.max(s.collectRange, self.config.Grove.autoPickerRange)
		end
	end
	s.labBoost = s.labBoost or 1

	local grove = self.config.Grove
	s.totalPickers = s.pickers + s.freePickers
	s.pickValue = s.pickFlat * s.pickMult * s.orangeMult
	s.ripenSeconds = grove.ripenSeconds / s.ripenSpeed
	s.pickerPicks = s.totalPickers * grove.pickerPicksPerSecond * s.pickerSpeed
	return s
end

function Economy.owns(_self: Economy, levels: { [string]: number }, id: string): boolean
	return (levels[id] or 0) > 0
end

-- "bought" = maxed, "owned" = has levels but can go higher, "available" = parents owned,
-- "locked" = one step past the frontier (grey, text dimmed), "hidden" = further out (shown as ???).
function Economy.nodeState(self: Economy, levels: { [string]: number }, id: string, mods: Mods?): string
	local node = self.tree.byId[id]
	local level = levels[id] or 0
	if level >= self:maxLevel(node, mods) then
		return "bought"
	end
	local allParents = true
	local anyParentSeen = #node.parents == 0
	for _, parent in node.parents do
		if self:owns(levels, parent) then
			anyParentSeen = true
		else
			allParents = false
			local grand = self.tree.byId[parent]
			local parentReachable = true
			for _, gp in grand.parents do
				if not self:owns(levels, gp) then
					parentReachable = false
				end
			end
			if parentReachable then
				anyParentSeen = true
			end
		end
	end
	if level > 0 then
		return "owned"
	end
	if allParents then
		return "available"
	end
	return if anyParentSeen then "locked" else "hidden"
end

function Economy.canBuy(self: Economy, save: any, id: string, mods: Mods?): (boolean, string, number)
	local node = self.tree.byId[id]
	if not node then
		return false, "unknown", 0
	end
	local state = self:nodeState(save.levels, id, mods)
	if state == "bought" then
		return false, "maxed", 0
	end
	if state ~= "available" and state ~= "owned" then
		return false, "locked", 0
	end
	local price = self:cost(node, save.levels[id] or 0)
	if (save.currencies[node.currency] or 0) < price then
		return false, "afford", price
	end
	return true, "ok", price
end

-- Advances machines and pickers by dt seconds. Returns oranges gained from pickers.
function Economy.step(_self: Economy, save: any, s: Stats, dt: number): number
	local c = save.currencies
	local machines = save.machines

	local pickerGain = s.pickerPicks * s.pickValue * dt
	c.oranges += pickerGain

	if s.labOpen and machines.lab ~= false then
		local batches = math.min(s.labSpeed * dt, c.oranges / s.labCost)
		if batches > 0 then
			c.oranges -= batches * s.labCost
			c.vitamin += batches * s.labYield * s.prodMult * s.labBoost
			save.peels += batches * s.peelPerBatch
		end
	end

	if s.zesterOpen and machines.zester ~= false then
		local peels = math.min(s.zesterSpeed * dt, save.peels)
		if peels > 0 then
			save.peels -= peels
			c.zest += peels * s.zestYield * s.prodMult
		end
	end

	if s.juiceOpen and machines.juice ~= false then
		local batches = math.min(s.juiceSpeed * dt, c.oranges / s.juiceOrangeCost, c.vitamin / s.juiceVitCost)
		if batches > 0 then
			c.oranges -= batches * s.juiceOrangeCost
			c.vitamin -= batches * s.juiceVitCost
			local made = batches * s.juiceYield * s.prodMult
			c.crates += made
			save.lifetimeCrates += made
		end
	end

	return pickerGain
end

function Economy.pendingSeeds(self: Economy, save: any, s: Stats): number
	local total = math.floor(math.sqrt(save.lifetimeCrates / self.config.Prestige.crateDivisor) * s.seedMult)
	return math.max(0, total - (save.seedsClaimed or 0))
end

-- What survives a Replant: "full" keeps every level (permanent and keep nodes), "one" keeps a single
-- level (unlocks named by keep effects, plus their ancestors so the board stays connected).
function Economy.keptNodes(self: Economy, levels: { [string]: number }): { [string]: string }
	local kept: { [string]: string } = {}
	for _, node in self.tree.nodes do
		if node.permanent or node.keep then
			kept[node.id] = "full"
		end
	end
	for _, node in self.tree.nodes do
		if (levels[node.id] or 0) > 0 then
			for _, effect in node.effects do
				if effect.op == "keep" and effect.nodes then
					for _, id in effect.nodes do
						kept[id] = kept[id] or "one"
						local stack = { id }
						while #stack > 0 do
							local current = table.remove(stack) :: string
							for _, parent in self.tree.byId[current].parents do
								if not kept[parent] then
									kept[parent] = "one"
									table.insert(stack, parent)
								end
							end
						end
					end
				end
			end
		end
	end
	return kept
end

return Economy
