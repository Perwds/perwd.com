--[[
	📍 LOCATION: ReplicatedStorage > Shared > Config > ChaserConfig (ModuleScript)

	When you shrink something, the zone's owner comes running after you!
	Make it back to the SAFE ZONE (your base) to keep your loot. Get caught and you drop it all.

	Speed is in studs/sec (players start at 24; TRAIN speed on your plot's treadmill to outrun later chasers).
	Colors / HeadProps build a simple look on a standard R15 body. To use your own NPC instead,
	put a Model with a Humanoid + HumanoidRootPart in ServerStorage > Chasers named "Tier1".."Tier10".
]]

local ChaserConfig = {}

local RGB = Color3.fromRGB

ChaserConfig.CatchDistance = 5.5 -- studs
ChaserConfig.HeadStart = 0.8 -- seconds the chaser waits ("!") before running
ChaserConfig.SpawnBehind = 30 -- studs deeper into the zone than the shrunk object
ChaserConfig.ChaseJump = true -- chasers jump over small things

-- Getting caught: you DROP your boxes on the ground and the chaser walks back home with a smug line.
-- The boxes stay there for DropLifetime seconds. If you (or anyone) grabs one back, that zone's
-- chaser gets ENRAGED: +RageSpeed studs/sec per rage level (max MaxRage) and comes after you again.
-- Rage cools down by one level every RageCooldown seconds.
ChaserConfig.DropLifetime = 20
ChaserConfig.RageSpeed = 5
ChaserConfig.MaxRage = 5
ChaserConfig.RageCooldown = 90
ChaserConfig.RunAnimation = "rbxassetid://913376220" -- Roblox default R15 run

ChaserConfig.Chasers = {
	[1] = {
		Name = "Grandpa Joe",
		Emoji = "👴",
		Speed = 28,
		Shout = "HEY! THAT'S MY STUFF, YOU WHIPPERSNAPPER!",
		CaughtLine = "Hah! Back to my yard!",
		Skin = RGB(234, 184, 146),
		Shirt = RGB(150, 110, 80),
		Pants = RGB(90, 90, 110),
		Scale = 0.95,
		HeadProps = {
			{ Name = "FlatCap", Size = Vector3.new(1.3, 0.35, 1.4), Offset = Vector3.new(0, 0.62, -0.05), Color = RGB(110, 85, 60), Material = Enum.Material.Fabric },
			{ Name = "Beard", Size = Vector3.new(1, 0.7, 0.4), Offset = Vector3.new(0, -0.45, -0.55), Color = RGB(240, 240, 240), Material = Enum.Material.Fabric },
			{ Name = "Glasses", Size = Vector3.new(1.05, 0.22, 0.08), Offset = Vector3.new(0, 0.12, -0.62), Color = RGB(30, 30, 30), Material = Enum.Material.Metal },
			{ Name = "Mustache", Size = Vector3.new(0.8, 0.18, 0.15), Offset = Vector3.new(0, -0.18, -0.64), Color = RGB(240, 240, 240), Material = Enum.Material.Fabric },
		},
		HandProps = {
			{ Name = "Cane", Size = Vector3.new(0.22, 3.4, 0.22), Offset = Vector3.new(0, -1.3, -0.25), Color = RGB(110, 70, 40), Material = Enum.Material.Wood },
			{ Name = "CaneTop", Size = Vector3.new(0.22, 0.22, 0.7), Offset = Vector3.new(0, 0.35, -0.5), Color = RGB(110, 70, 40), Material = Enum.Material.Wood },
		},
	},
	[2] = {
		Name = "Angry Neighbor",
		Emoji = "😠",
		Speed = 32,
		Shout = "GET OFF MY LAWN!",
		CaughtLine = "And STAY out!",
		Skin = RGB(200, 140, 100),
		Shirt = RGB(230, 70, 70),
		Pants = RGB(60, 80, 140),
		Scale = 1,
		HeadProps = {
			{ Name = "Cap", Size = Vector3.new(1.3, 0.35, 1.5), Offset = Vector3.new(0, 0.62, -0.1), Color = RGB(40, 120, 220), Material = Enum.Material.Fabric },
			{ Name = "Brim", Size = Vector3.new(1.1, 0.1, 0.6), Offset = Vector3.new(0, 0.48, -0.85), Color = RGB(40, 120, 220), Material = Enum.Material.Fabric },
		},
		HandProps = {
			{ Name = "RakeHandle", Size = Vector3.new(0.2, 5, 0.2), Offset = Vector3.new(0, 0.6, -0.2), Color = RGB(150, 105, 60), Material = Enum.Material.Wood },
			{ Name = "RakeHead", Size = Vector3.new(1.6, 0.25, 0.3), Offset = Vector3.new(0, 3.1, -0.2), Color = RGB(90, 90, 100), Material = Enum.Material.Metal },
		},
	},
	[3] = {
		Name = "Officer Doug",
		Emoji = "👮",
		Speed = 36,
		Shout = "STOP RIGHT THERE!",
		CaughtLine = "You're under arrest... for shrinking!",
		Skin = RGB(160, 110, 80),
		Shirt = RGB(30, 50, 110),
		Pants = RGB(25, 30, 60),
		Scale = 1.05,
		HeadProps = {
			{ Name = "PoliceHat", Size = Vector3.new(1.35, 0.45, 1.45), Offset = Vector3.new(0, 0.66, 0), Color = RGB(25, 35, 80), Material = Enum.Material.SmoothPlastic },
			{ Name = "Badge", Size = Vector3.new(0.3, 0.3, 0.1), Offset = Vector3.new(0, 0.7, -0.75), Color = RGB(255, 210, 60), Material = Enum.Material.Neon },
			{ Name = "Visor", Size = Vector3.new(1.2, 0.08, 0.5), Offset = Vector3.new(0, 0.46, -0.8), Color = RGB(15, 15, 20), Material = Enum.Material.SmoothPlastic },
			{ Name = "Shades", Size = Vector3.new(1.0, 0.22, 0.08), Offset = Vector3.new(0, 0.12, -0.62), Color = RGB(15, 15, 20), Material = Enum.Material.Glass },
		},
		HandProps = {
			{ Name = "Baton", Size = Vector3.new(0.25, 2.2, 0.25), Offset = Vector3.new(0, -0.6, -0.3), Color = RGB(20, 20, 25), Material = Enum.Material.SmoothPlastic },
		},
	},
	[4] = {
		Name = "Captain Barnacle",
		Emoji = "🏴‍☠️",
		Speed = 40,
		Shout = "ARRR! THIEF ON DECK!",
		CaughtLine = "Walk the plank, landlubber!",
		Skin = RGB(210, 160, 120),
		Shirt = RGB(150, 30, 30),
		Pants = RGB(40, 30, 25),
		Scale = 1.1,
		HeadProps = {
			{ Name = "PirateHat", Size = Vector3.new(1.8, 0.5, 1.2), Offset = Vector3.new(0, 0.7, 0), Color = RGB(25, 25, 25), Material = Enum.Material.Fabric },
			{ Name = "EyePatch", Size = Vector3.new(0.35, 0.3, 0.1), Offset = Vector3.new(0.25, 0.1, -0.6), Color = RGB(10, 10, 10), Material = Enum.Material.SmoothPlastic },
			{ Name = "Skull", Size = Vector3.new(0.3, 0.3, 0.05), Offset = Vector3.new(0, 0.75, -0.62), Color = RGB(250, 250, 250), Material = Enum.Material.SmoothPlastic },
			{ Name = "Beard", Size = Vector3.new(1, 0.6, 0.4), Offset = Vector3.new(0, -0.45, -0.5), Color = RGB(60, 35, 25), Material = Enum.Material.Fabric },
		},
		HandProps = {
			{ Name = "Cutlass", Size = Vector3.new(0.12, 2.8, 0.45), Offset = Vector3.new(0, -1.5, -0.3), Color = RGB(215, 220, 230), Material = Enum.Material.Metal },
			{ Name = "Hilt", Size = Vector3.new(0.5, 0.15, 0.6), Offset = Vector3.new(0, -0.1, -0.3), Color = RGB(220, 180, 60), Material = Enum.Material.Metal },
		},
	},
	[5] = {
		Name = "Sheriff Sandy",
		Emoji = "🤠",
		Speed = 44,
		Shout = "YEEHAW! STOP, VARMINT!",
		CaughtLine = "This town ain't big enough for the both of us!",
		Skin = RGB(225, 175, 130),
		Shirt = RGB(200, 140, 70),
		Pants = RGB(70, 80, 120),
		Scale = 1.05,
		HeadProps = {
			{ Name = "CowboyHat", Size = Vector3.new(2.2, 0.25, 2.2), Offset = Vector3.new(0, 0.55, 0), Color = RGB(150, 100, 50), Material = Enum.Material.Fabric },
			{ Name = "HatTop", Size = Vector3.new(1.2, 0.6, 1.2), Offset = Vector3.new(0, 0.85, 0), Color = RGB(150, 100, 50), Material = Enum.Material.Fabric },
			{ Name = "Star", Size = Vector3.new(0.35, 0.35, 0.1), Offset = Vector3.new(0, 0.85, -0.62), Color = RGB(255, 210, 60), Material = Enum.Material.Metal },
		},
		HandProps = {
			{ Name = "Lasso", Size = Vector3.new(1.4, 0.2, 1.4), Offset = Vector3.new(0, -0.5, -0.4), Color = RGB(200, 170, 110), Material = Enum.Material.Fabric },
		},
	},
	[6] = {
		Name = "Jungle Jim",
		Emoji = "🦁",
		Speed = 48,
		Shout = "NOBODY ROBS MY JUNGLE!",
		CaughtLine = "Ha! The jungle always wins!",
		Skin = RGB(190, 130, 90),
		Shirt = RGB(110, 140, 70),
		Pants = RGB(150, 120, 70),
		Scale = 1.1,
		HeadProps = {
			{ Name = "SafariHat", Size = Vector3.new(1.9, 0.3, 1.9), Offset = Vector3.new(0, 0.55, 0), Color = RGB(220, 200, 150), Material = Enum.Material.Fabric },
			{ Name = "HatDome", Size = Vector3.new(1.3, 0.5, 1.3), Offset = Vector3.new(0, 0.8, 0), Color = RGB(220, 200, 150), Material = Enum.Material.Fabric },
		},
		HandProps = {
			{ Name = "Net", Size = Vector3.new(1.4, 1.4, 0.15), Offset = Vector3.new(0, 1.6, -0.3), Color = RGB(240, 240, 240), Material = Enum.Material.Fabric },
			{ Name = "NetPole", Size = Vector3.new(0.18, 3, 0.18), Offset = Vector3.new(0, 0, -0.3), Color = RGB(120, 80, 40), Material = Enum.Material.Wood },
		},
	},
	[7] = {
		Name = "Security Bot",
		Emoji = "🤖",
		Speed = 52,
		Shout = "INTRUDER DETECTED. INITIATING PURSUIT.",
		CaughtLine = "TARGET NEUTRALIZED. BEEP BOOP.",
		Skin = RGB(170, 175, 190),
		Shirt = RGB(90, 95, 110),
		Pants = RGB(60, 65, 80),
		Scale = 1.15,
		HeadProps = {
			{ Name = "Visor", Size = Vector3.new(1.1, 0.3, 0.2), Offset = Vector3.new(0, 0.1, -0.6), Color = RGB(255, 40, 40), Material = Enum.Material.Neon },
			{ Name = "Antenna", Size = Vector3.new(0.15, 0.8, 0.15), Offset = Vector3.new(0, 0.95, 0), Color = RGB(255, 40, 40), Material = Enum.Material.Neon },
		},
	},
	[8] = {
		Name = "Magma Golem",
		Emoji = "🔥",
		Speed = 56,
		Shout = "YOU... WILL... BURN!",
		CaughtLine = "Toasty!",
		Skin = RGB(70, 45, 40),
		Shirt = RGB(60, 40, 35),
		Pants = RGB(50, 35, 30),
		Scale = 1.5,
		HeadProps = {
			{ Name = "LavaEyes", Size = Vector3.new(1.0, 0.25, 0.1), Offset = Vector3.new(0, 0.12, -0.62), Color = RGB(255, 120, 20), Material = Enum.Material.Neon },
			{ Name = "LavaCrown", Size = Vector3.new(1.3, 0.3, 1.3), Offset = Vector3.new(0, 0.7, 0), Color = RGB(255, 80, 20), Material = Enum.Material.Neon },
		},
	},
	[9] = {
		Name = "The Yeti",
		Emoji = "🦍",
		Speed = 60,
		Shout = "ROOOOAAAARRR!!!",
		CaughtLine = "*happy yeti noises*",
		Skin = RGB(235, 240, 250),
		Shirt = RGB(235, 240, 250),
		Pants = RGB(225, 232, 245),
		Scale = 1.7,
		HeadProps = {
			{ Name = "Horns", Size = Vector3.new(1.6, 0.3, 0.3), Offset = Vector3.new(0, 0.6, 0), Color = RGB(140, 140, 150), Material = Enum.Material.Slate },
		},
	},
	[10] = {
		Name = "Alien Overlord",
		Emoji = "👽",
		Speed = 66,
		Shout = "EARTHLING! RETURN OUR TREASURE!",
		CaughtLine = "Probing complete. Bye bye!",
		Skin = RGB(120, 230, 120),
		Shirt = RGB(70, 60, 140),
		Pants = RGB(50, 45, 110),
		Scale = 1.3,
		HeadProps = {
			{ Name = "Eyes", Size = Vector3.new(1.1, 0.4, 0.1), Offset = Vector3.new(0, 0.12, -0.62), Color = RGB(10, 10, 20), Material = Enum.Material.Glass },
			{ Name = "Antenna", Size = Vector3.new(0.12, 1.0, 0.12), Offset = Vector3.new(0, 1.0, 0), Color = RGB(120, 230, 120), Material = Enum.Material.SmoothPlastic },
			{ Name = "AntennaBall", Size = Vector3.new(0.35, 0.35, 0.35), Offset = Vector3.new(0, 1.55, 0), Color = RGB(255, 80, 200), Material = Enum.Material.Neon },
		},
		HandProps = {
			{ Name = "RayGun", Size = Vector3.new(0.4, 0.5, 1.6), Offset = Vector3.new(0, -0.6, -0.6), Color = RGB(200, 200, 220), Material = Enum.Material.Metal },
		},
	},
}

function ChaserConfig.Get(tier)
	return ChaserConfig.Chasers[tier] or ChaserConfig.Chasers[1]
end

return ChaserConfig
