--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Audio (ModuleScript)

	All game audio on the client:
	  • sound effects (GameConfig.Sounds) → "SFX" SoundGroup
	  • ambient loops per area (GameConfig.Ambient) → "Ambient" SoundGroup, cross-faded as you walk
	  • volumes come from your Settings (⚙️ menu) and are saved on the server
	The server can trigger sounds with the "PlaySound" remote (NetService.Sound).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local TierConfig = require(Shared.Config.TierConfig)
local Remotes = require(Shared.Remotes)

local Audio = {}

local player = Players.LocalPlayer
local groups = {}
local cache = {}
local ambientSounds = {} -- [areaKey] = Sound
local currentArea

local function group(name, volume)
	local g = SoundService:FindFirstChild(name)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	g.Volume = volume
	groups[name] = g
	return g
end

local function resolve(nameOrId)
	return GameConfig.Sounds[nameOrId] or nameOrId
end

-- UI / 2D sound
function Audio.Play(name, volume)
	local id = resolve(name)
	if not id or id == "" then
		return
	end
	local sound = cache[id]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = id
		sound.SoundGroup = groups.SFX
		sound.Parent = SoundService
		cache[id] = sound
	end
	sound.Volume = volume or 0.6
	SoundService:PlayLocalSound(sound)
end

-- 3D sound at a world position
function Audio.PlayAt(position, name, volume)
	local id = resolve(name)
	if not id or id == "" then
		return
	end
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.RollOffMaxDistance = 250
	s.PlaybackSpeed = 0.9 + math.random() * 0.3
	s.SoundGroup = groups.SFX
	s.Parent = att
	s:Play()
	task.delay(4, function()
		att:Destroy()
	end)
end

-- Applies the volume settings (0..1 each).
function Audio.ApplySettings(settings)
	if not settings then
		return
	end
	groups.SFX.Volume = settings.Sfx or 0.8
	groups.Ambient.Volume = settings.Ambient or 0.5
	groups.Music.Volume = settings.Music or 0.5
end

local function areaAt(position)
	if position.Z < 0 then
		return "Base"
	end
	local z = 0
	for tier, t in ipairs(TierConfig.Tiers) do
		z += t.AreaDepth
		if position.Z < z then
			return tier
		end
	end
	return #TierConfig.Tiers
end

local function ambientFor(key)
	local id = GameConfig.Ambient[key]
	if not id or id == "" then
		return nil
	end
	local s = ambientSounds[key]
	if not s then
		s = Instance.new("Sound")
		s.Name = "Ambient_" .. tostring(key)
		s.SoundId = id
		s.Looped = true
		s.Volume = 0
		s.SoundGroup = groups.Ambient
		s.Parent = SoundService
		s:Play()
		ambientSounds[key] = s
	end
	return s
end

local function ambientLoop()
	while true do
		task.wait(1)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local key = root and areaAt(root.Position)
		if key ~= currentArea then
			currentArea = key
			for k, s in pairs(ambientSounds) do
				if k ~= key then
					TweenService:Create(s, TweenInfo.new(1.5), { Volume = 0 }):Play()
				end
			end
			local s = key and ambientFor(key)
			if s then
				TweenService:Create(s, TweenInfo.new(1.5), { Volume = GameConfig.Ambient.Volume or 0.35 }):Play()
			end
		end
	end
end

function Audio.Init()
	group("SFX", 0.8)
	group("Ambient", 0.5)
	group("Music", 0.5)
	Remotes.Event("PlaySound").OnClientEvent:Connect(function(name, position)
		if typeof(position) == "Vector3" then
			Audio.PlayAt(position, name, 0.8)
		else
			Audio.Play(name, 0.7)
		end
	end)
	task.spawn(ambientLoop)
end

return Audio
