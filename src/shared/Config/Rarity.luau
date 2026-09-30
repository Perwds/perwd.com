--[[
	Rarity tiers. Order matters: index 1 is the most common.
	Colours here drive the Pet Index tile backgrounds and the hatch burst.
]]

local Rarity = {}

Rarity.Order = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Secret",
}

Rarity.Info = {
	Common = {
		color = Color3.fromRGB(125, 125, 130),
		glow = Color3.fromRGB(180, 180, 190),
		-- Income multiplier applied on top of the world's base rate.
		incomeMultiplier = 1,
		-- How many of this pet it takes to matter at the Fuse Machine.
		fuseValue = 1,
		burstParticles = 12,
	},
	Uncommon = {
		color = Color3.fromRGB(60, 200, 70),
		glow = Color3.fromRGB(150, 255, 160),
		incomeMultiplier = 2.6,
		fuseValue = 3,
		burstParticles = 18,
	},
	Rare = {
		color = Color3.fromRGB(45, 110, 235),
		glow = Color3.fromRGB(140, 190, 255),
		incomeMultiplier = 7,
		fuseValue = 9,
		burstParticles = 26,
	},
	Epic = {
		color = Color3.fromRGB(170, 55, 220),
		glow = Color3.fromRGB(225, 160, 255),
		incomeMultiplier = 19,
		fuseValue = 27,
		burstParticles = 36,
	},
	Legendary = {
		color = Color3.fromRGB(235, 55, 190),
		glow = Color3.fromRGB(255, 165, 235),
		incomeMultiplier = 52,
		fuseValue = 81,
		burstParticles = 50,
	},
	Mythic = {
		color = Color3.fromRGB(245, 195, 35),
		glow = Color3.fromRGB(255, 240, 150),
		incomeMultiplier = 145,
		fuseValue = 243,
		burstParticles = 70,
	},
	Secret = {
		color = Color3.fromRGB(20, 20, 24),
		glow = Color3.fromRGB(255, 255, 255),
		incomeMultiplier = 420,
		fuseValue = 729,
		burstParticles = 100,
	},
}

Rarity.Rank = {}
for index, name in Rarity.Order do
	Rarity.Rank[name] = index
end

function Rarity.get(name: string)
	return Rarity.Info[name] or Rarity.Info.Common
end

function Rarity.color(name: string): Color3
	return Rarity.get(name).color
end

--- True when `a` is strictly rarer than `b`.
function Rarity.isHigher(a: string, b: string): boolean
	return (Rarity.Rank[a] or 0) > (Rarity.Rank[b] or 0)
end

--- The tier one step above `name`, or `name` itself if already at the top.
function Rarity.next(name: string): string
	local rank = Rarity.Rank[name]
	if not rank then
		return "Common"
	end
	return Rarity.Order[math.min(rank + 1, #Rarity.Order)]
end

return Rarity
