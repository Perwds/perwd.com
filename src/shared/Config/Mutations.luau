--!nonstrict
-- Mutations are the second, independent roll layered on top of the fish roll.
-- They are what makes a Common worth chasing: a Glitched Minnow beats almost
-- anything you can pull out of the Abyss.

local Mutations = {}

Mutations.Order = {
	"None",
	"Shiny",
	"Albino",
	"Golden",
	"Radioactive",
	"Void",
	"Celestial",
	"Glitched",
}

Mutations.Data = {
	None = {
		chance = 1,
		valueMult = 1,
		scoreMult = 1,
		color = Color3.fromRGB(215, 220, 230),
		prefix = "",
		luckExponent = 0,
	},
	Shiny = {
		chance = 50,
		valueMult = 3,
		scoreMult = 2.5,
		color = Color3.fromRGB(255, 236, 130),
		prefix = "Shiny",
		luckExponent = 0.3,
	},
	Albino = {
		chance = 200,
		valueMult = 6,
		scoreMult = 5,
		color = Color3.fromRGB(246, 246, 250),
		prefix = "Albino",
		luckExponent = 0.4,
	},
	Golden = {
		chance = 1000,
		valueMult = 15,
		scoreMult = 12,
		color = Color3.fromRGB(255, 190, 40),
		prefix = "Golden",
		luckExponent = 0.55,
	},
	Radioactive = {
		chance = 5000,
		valueMult = 45,
		scoreMult = 40,
		color = Color3.fromRGB(140, 255, 70),
		prefix = "Radioactive",
		luckExponent = 0.7,
	},
	Void = {
		chance = 25000,
		valueMult = 150,
		scoreMult = 140,
		color = Color3.fromRGB(120, 60, 220),
		prefix = "Void",
		luckExponent = 0.8,
	},
	Celestial = {
		chance = 250000,
		valueMult = 800,
		scoreMult = 900,
		color = Color3.fromRGB(120, 230, 255),
		prefix = "Celestial",
		luckExponent = 0.9,
	},
	Glitched = {
		chance = 1000000,
		valueMult = 4000,
		scoreMult = 5000,
		color = Color3.fromRGB(255, 60, 220),
		prefix = "Glitched",
		luckExponent = 1,
	},
}

function Mutations.Get(name: string)
	local mutation = Mutations.Data[name]
	assert(mutation, string.format("unknown mutation %q", tostring(name)))
	return mutation
end

function Mutations.WeightWithLuck(name: string, luck: number): number
	local mutation = Mutations.Get(name)
	return (1 / mutation.chance) * (math.max(luck, 0.01) ^ mutation.luckExponent)
end

function Mutations.IndexOf(name: string): number
	for index, mutationName in Mutations.Order do
		if mutationName == name then
			return index
		end
	end
	return 0
end

return Mutations
