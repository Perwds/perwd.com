--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > TextureConfig (ModuleScript)

	YOUR OWN TEXTURES (ShrinkIt_Individual_Assets folder).
	How to use them:
	  1. Roblox Studio → View → Asset Manager → Bulk Import → pick the images from your
	     ShrinkIt_Individual_Assets folder.
	  2. Right-click each uploaded image → "Copy ID" (or Copy Asset ID).
	  3. Paste it below as "rbxassetid://123456789". Leave "" to keep the built-in look.
	Everything is applied while the game runs, so you never have to rebuild the map.
]]

local TextureConfig = {}

-- Menus: tiled image behind every menu / shop panel (replaces the drawn studs)
TextureConfig.UI = {
	PanelStuds = "", -- e.g. a stud / brick pattern image
	PanelStudsTile = 64, -- pixels per tile on screen
	ShopBackground = "", -- extra background only for the Shop, Trail Shop & Fuse menus
}

-- Mystery boxes: picture on every side of a box (replaces the "?")
TextureConfig.Box = {
	Face = "",
	TileStuds = 0, -- 0 = one picture per side
}

-- Ground of each zone (1 = Grandpa's Backyard … 10 = Outer Space) and the safe-zone base.
-- Tile = how many studs one copy of the picture covers.
TextureConfig.Ground = {
	Base = { Id = "", Tile = 16 },
	[1] = { Id = "", Tile = 16 },
	[2] = { Id = "", Tile = 16 },
	[3] = { Id = "", Tile = 16 },
	[4] = { Id = "", Tile = 16 },
	[5] = { Id = "", Tile = 16 },
	[6] = { Id = "", Tile = 16 },
	[7] = { Id = "", Tile = 16 },
	[8] = { Id = "", Tile = 16 },
	[9] = { Id = "", Tile = 16 },
	[10] = { Id = "", Tile = 16 },
}

-- Your plot floor and the shop stands' counters
TextureConfig.PlotFloor = { Id = "", Tile = 12 }
TextureConfig.StandCounter = { Id = "", Tile = 6 }

function TextureConfig.Has(id)
	return type(id) == "string" and id ~= ""
end

return TextureConfig
