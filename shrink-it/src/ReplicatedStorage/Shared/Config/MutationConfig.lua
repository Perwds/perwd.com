--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > MutationConfig (ModuleScript)

	MUTATIONS: when a box opens, the object can come out MUTATED, which multiplies its income.
	  • Global mutations can come from any box. Chance = BaseChance, raised by your Luck.
	    Luck also tilts the roll toward the rarer mutations.
	  • Zone mutations only come from boxes of THAT zone (rolled first, ZoneChance), so late-game
	    players still have a reason to go back to the early zones.
	Mutated objects glow in the mutation's color and show its name.
]]

local RGB = Color3.fromRGB

local MutationConfig = {}

MutationConfig.BaseChance = 0.12 -- chance that a box rolls a global mutation (before Luck)
MutationConfig.MaxChance = 0.6
MutationConfig.ZoneChance = 0.04 -- chance of that zone's own mutation (before Luck)

MutationConfig.Order = { "Silver", "Shiny", "Gilded", "Crystal", "Neon", "Shadow", "Prism" }
MutationConfig.Mutations = {
	Silver = { Mult = 1.2, Weight = 60, Color = RGB(215, 220, 230) },
	Shiny = { Mult = 1.5, Weight = 30, Color = RGB(255, 245, 170) },
	Gilded = { Mult = 2, Weight = 14, Color = RGB(255, 195, 40) },
	Crystal = { Mult = 2.5, Weight = 7, Color = RGB(120, 230, 255) },
	Neon = { Mult = 3, Weight = 3, Color = RGB(80, 255, 140) },
	Shadow = { Mult = 3.2, Weight = 1.6, Color = RGB(120, 60, 200) },
	Prism = { Mult = 3.5, Weight = 0.8, Color = RGB(255, 110, 200), Rainbow = true },

	-- zone-only mutations (Zone = the zone they come from)
	Blossom = { Mult = 2.2, Zone = 1, Color = RGB(255, 160, 210) },
	Candy = { Mult = 2.2, Zone = 2, Color = RGB(255, 120, 170) },
	Electric = { Mult = 2.4, Zone = 3, Color = RGB(255, 240, 60) },
	Pearl = { Mult = 2.4, Zone = 4, Color = RGB(240, 235, 255) },
	Sandstorm = { Mult = 2.5, Zone = 5, Color = RGB(230, 180, 90) },
	Tropical = { Mult = 2.5, Zone = 6, Color = RGB(60, 220, 120) },
	Chrome = { Mult = 2.6, Zone = 7, Color = RGB(190, 200, 220) },
	Molten = { Mult = 2.8, Zone = 8, Color = RGB(255, 110, 30) },
	Frozen = { Mult = 3, Zone = 9, Color = RGB(150, 220, 255) },
	Galactic = { Mult = 3, Zone = 10, Color = RGB(150, 100, 255) },

	-- LIMITED: only from the Robux "Festive Box" (GameConfig.LimitedBox)
	Festive = { Mult = 4, Limited = true, Color = RGB(255, 80, 80), Rainbow = true },
}

function MutationConfig.Get(name)
	return name and MutationConfig.Mutations[name] or nil
end

function MutationConfig.ZoneMutation(tier)
	for name, m in pairs(MutationConfig.Mutations) do
		if m.Zone == tier then
			return name, m
		end
	end
	return nil
end

return MutationConfig
