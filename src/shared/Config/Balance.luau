--[[
	Tunables for the steal-and-carry loop. Everything a playtest would want
	to nudge lives here rather than being buried in a service.
]]

return {
	Carry = {
		-- Holding the prompt on a loose egg on a pedestal.
		GRAB_HOLD = 0.6,
		-- Holding the prompt on ANOTHER PLAYER to rip the egg off their back.
		-- Deliberately long: stealing should be a commitment, not a drive-by.
		STEAL_HOLD = 3.0,
		-- You have to be this close to steal.
		STEAL_RANGE = 9,
		-- Carrying slows you down. Rarer eggs are heavier.
		WALKSPEED_BASE = 24,
		WALKSPEED_CARRYING = 15,
		-- Extra slowdown per rarity rank above Common, subtracted from the above.
		WALKSPEED_RARITY_PENALTY = 0.7,
		-- After you lose an egg you cannot be stolen from again for this long,
		-- so a pack of players cannot chain-strip a new carrier.
		STEAL_IMMUNITY = 4,
		-- Dropping on death/reset leaves the egg where you fell.
		DROP_ON_DEATH = true,
		-- A loose egg on the ground despawns after this, back to a pedestal.
		LOOSE_DESPAWN = 45,
	},

	Hatch = {
		-- Hatch pads per player plot. More pads = more eggs cooking at once.
		PADS_PER_PLOT = 3,
		-- Robux-free speed-up: watching the egg on your pad ticks it down
		-- faster while you stand near it.
		PROXIMITY_BOOST = 1.35,
		PROXIMITY_RANGE = 18,
		-- Hatching persists across leaving the game.
		OFFLINE_PROGRESS = true,
	},

	Pets = {
		-- Equipped pets that actually generate cash.
		EQUIP_LIMIT = 6,
		-- Total pets you can hold before the Sell stand is mandatory.
		INVENTORY_LIMIT = 250,
		-- Cash tick interval, in seconds.
		INCOME_INTERVAL = 1,
		-- Follow behaviour.
		FOLLOW_RADIUS = 6,
		FOLLOW_HEIGHT = 2.5,
		FOLLOW_SPEED = 0.18,
		BOB_AMPLITUDE = 0.35,
		BOB_SPEED = 2.2,
	},

	Fuse = {
		-- Feed this many pets of the same rarity to roll one tier up.
		INPUT_COUNT = 3,
		-- Chance the fuse lands on the next tier. Otherwise you get a
		-- same-tier pet back, so a fuse is never a total loss.
		UPGRADE_CHANCE = 0.55,
		DURATION = 6,
	},

	Sell = {
		-- Cash for selling a pet, as a multiple of its per-second income.
		INCOME_MULTIPLE = 90,
		-- You cannot sell your last pet or anything equipped.
		PROTECT_EQUIPPED = true,
	},

	Events = {
		-- The bottle timer from the HUD: a potion drops somewhere in the map.
		POTION_INTERVAL = 25 * 60,
		POTION_DURATION = 5 * 60,
		-- Day/night cycle. Night doubles wild egg spawn rarity.
		DAY_LENGTH = 20 * 60,
		NIGHT_LENGTH = 5 * 60,
		NIGHT_RARITY_BOOST = 2,
	},

	Rewards = {
		-- Claiming a completed world index.
		INDEX_CASH = 100,
		INDEX_SPEED = 420,
		-- Speed is additive on top of WALKSPEED_BASE, divided by 100.
		SPEED_DIVISOR = 100,
	},

	Daily = {
		-- A login "day" is this long. Miss two in a row and the streak resets.
		PERIOD = 20 * 3600,
		GRACE = 48 * 3600,
	},
}
