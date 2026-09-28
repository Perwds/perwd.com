--!strict
--[[
	Sfx -- UI sound.

	One built-in rbxasset clip, pitched differently per event. Using a single
	guaranteed-present asset avoids shipping ids that may not resolve, and
	pitch alone is enough to tell a click from a reward from a refusal.
]]

local SoundService = game:GetService("SoundService")

local Sfx = {}

local CLIP = "rbxasset://sounds/electronicpingshort.wav"

local PITCH = {
	click = 1.6,
	tab = 1.9,
	scan = 1.2,
	reward = 1.0,
	big = 0.75,
	deny = 0.55,
}

local pool: { Sound } = {}

local function borrow(): Sound
	for _, sound in ipairs(pool) do
		if not sound.IsPlaying then
			return sound
		end
	end

	local sound = Instance.new("Sound")
	sound.SoundId = CLIP
	sound.Volume = 0.35
	sound.Parent = SoundService
	table.insert(pool, sound)
	return sound
end

function Sfx.play(kind: string, volume: number?)
	local pitch = PITCH[kind]
	if not pitch then
		return
	end

	-- A missing asset should never take down a click handler.
	pcall(function()
		local sound = borrow()
		sound.PlaybackSpeed = pitch + math.random(-3, 3) / 100
		sound.Volume = volume or 0.35
		sound:Play()
	end)
end

return Sfx
