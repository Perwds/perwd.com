--!strict
-- Music and effects. IDs live in Config.Sounds; a 0 means that sound is silent.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.State)

local Audio = {}

local sounds: { [string]: Sound } = {}
local music: Sound? = nil
local popStreak = 0
local lastPop = 0

local function make(name: string, id: number, volume: number, looped: boolean): Sound?
	if id == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. id
	sound.Volume = volume
	sound.Looped = looped
	sound.Parent = SoundService
	return sound
end

function Audio.init()
	local ids = Config.Sounds
	music = make("Music", ids.music, ids.musicVolume, true)
	for _, name in { "pop", "chime", "deny", "replant" } do
		local sound = make(name, (ids :: any)[name], ids.popVolume, false)
		if sound then
			sounds[name] = sound
		end
	end
	if music then
		music:Play()
	end
	State.onChange(function()
		Audio.applyVolumes()
	end)
end

function Audio.applyVolumes()
	local settings = State.settings()
	if music then
		music.Volume = Config.Sounds.musicVolume * settings.music
	end
end

local function play(name: string, pitch: number)
	local template = sounds[name]
	if not template then
		return
	end
	local sound = template:Clone()
	sound.PlaybackSpeed = pitch
	sound.Volume = Config.Sounds.popVolume * State.settings().sfx
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

-- A quick run of picks climbs a little in pitch, with a touch of randomness so no two pops match.
function Audio.pop()
	local now = os.clock()
	popStreak = if now - lastPop < 0.8 then (popStreak + 1) % 6 else 0
	lastPop = now
	play("pop", 0.94 + popStreak * 0.035 + math.random() * 0.05)
end

function Audio.chime()
	play("chime", 1 + math.random() * 0.04)
end

function Audio.deny()
	play("deny", 1)
end

function Audio.replant()
	play("replant", 1)
end

return Audio
