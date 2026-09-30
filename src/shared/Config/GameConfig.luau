--!nonstrict
-- Tuning knobs and the anti-exploit bounds the server enforces. Anything the
-- client is allowed to assert is bounded here.

local GameConfig = {}

GameConfig.DataStoreName = "PerwdFishing_Profiles_v1"
GameConfig.LeaderboardStoreName = "PerwdFishing_Boards_v1"

GameConfig.AutosaveInterval = 120
GameConfig.SaveRetries = 4
GameConfig.SaveRetryBackoff = 2

-- Fishing loop ---------------------------------------------------------------
GameConfig.CastCooldown = 0.65
-- A cast that is never reeled expires on its own so a player cannot hoard casts.
GameConfig.CastLifetime = 90
-- The reel bar starts here and must reach 1. Client and server both need it:
-- the client to draw it, the server to know how fast a win is even possible.
GameConfig.ReelStartProgress = 0.35
-- Floor on a claimed win. The fastest legitimate reel is
-- (1 - ReelStartProgress) / <best rod fillRate> = 0.65s, so this sits below it
-- with margin. tests/specs.luau asserts the two never cross.
GameConfig.MinReelSeconds = 0.5
GameConfig.MaxReelSeconds = 45
-- Grace added to MaxReelSeconds before the server stops believing the client.
GameConfig.ReelGrace = 3

-- Economy --------------------------------------------------------------------
GameConfig.StartingCoins = 0
GameConfig.MaxInventory = 250
-- Weight scales value: a fish at max weight is worth this much more than at min.
GameConfig.WeightValueSpread = 1.5

-- Progression ----------------------------------------------------------------
GameConfig.XpPerCatch = 3
GameConfig.XpRarityBonus = 0.5 -- multiplied by the tier's score
GameConfig.LevelCurve = 85 -- xp needed for level n = LevelCurve * n ^ 1.45
GameConfig.LuckPerLevel = 0.012 -- additive luck per level

-- Feed / announcements -------------------------------------------------------
GameConfig.AnnounceRarities = { Mythic = true, Exotic = true, Secret = true }
GameConfig.AnnounceMutations = { Radioactive = true, Void = true, Celestial = true, Glitched = true }
GameConfig.FeedLength = 12

-- Leaderboards ---------------------------------------------------------------
GameConfig.LeaderboardRefresh = 90
GameConfig.LeaderboardSize = 25

-- HUD scaling ----------------------------------------------------------------
-- The interface is authored in fixed pixels against a 1280x720 reference. Most
-- Roblox players are on a phone, where the viewport is far smaller: scaling
-- down proportionally would leave 11px labels unreadable on a dense screen,
-- while leaving it at authored size runs the reel bar and the panel off the
-- edge. So small viewports stay near the authored size, touch devices get a
-- deliberate bump for thumbs, and the result is then capped so the two largest
-- fixed elements always fit on screen.
GameConfig.HudReference = Vector2.new(1280, 720)
-- The tallest and widest fixed-size elements, plus breathing room: the panel
-- (576x442) and the reel bar (158x388).
GameConfig.HudTallest = 460
GameConfig.HudWidest = 620
GameConfig.TouchScaleBoost = 1.25

function GameConfig.HudScale(viewportX: number, viewportY: number, touch: boolean?): number
	if viewportX <= 0 or viewportY <= 0 then
		return 1
	end

	local proportional = math.min(
		viewportX / GameConfig.HudReference.X,
		viewportY / GameConfig.HudReference.Y
	)

	local scale = math.clamp(proportional, 0.8, 1.2)
	if touch then
		scale *= GameConfig.TouchScaleBoost
	end

	-- Nothing may hang off the edge, whatever the above worked out to.
	local fitsHeight = (viewportY - 24) / GameConfig.HudTallest
	local fitsWidth = (viewportX - 24) / GameConfig.HudWidest

	return math.clamp(math.min(scale, fitsHeight, fitsWidth), 0.5, 1.4)
end

function GameConfig.XpForLevel(level: number): number
	return math.floor(GameConfig.LevelCurve * (level ^ 1.45))
end

function GameConfig.LevelForXp(xp: number): number
	local level = 1
	while level < 500 and xp >= GameConfig.XpForLevel(level) do
		xp -= GameConfig.XpForLevel(level)
		level += 1
	end
	return level
end

return GameConfig
