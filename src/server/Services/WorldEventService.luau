--[[
	Server-wide events: the day/night cycle and the luck potion drop, which
	are the two countdowns on the HUD.

	Night and an active potion both raise the global luck multiplier, which
	EggSpawnService reads when rolling wild egg tiers. That is the whole
	point of showing the timers: players learn to bank their runs for the
	window when Golden eggs are likely.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Net = require(ReplicatedStorage.Shared.Net)

local EggSpawnService = require(script.Parent.EggSpawnService)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local WorldEventService = {}

local worldEvent = Net.Event("WorldEvent")
local notify = Net.Event("Notify")

local state = {
	isNight = false,
	phaseEndsAt = 0,
	potionAt = 0,
	potionEndsAt = 0,
	luck = 1,
}

local function recomputeLuck()
	local luck = 1
	if state.isNight then
		luck *= Balance.Events.NIGHT_RARITY_BOOST
	end
	if os.time() < state.potionEndsAt then
		luck *= 3
	end
	state.luck = luck
	EggSpawnService.setGlobalLuck(luck)
end

local function broadcast()
	local now = os.time()
	worldEvent:FireAllClients({
		isNight = state.isNight,
		phaseIn = math.max(0, state.phaseEndsAt - now),
		potionIn = math.max(0, state.potionAt - now),
		potionActive = now < state.potionEndsAt,
		potionEndsIn = math.max(0, state.potionEndsAt - now),
		luck = state.luck,
	})
end

local function setPhase(isNight: boolean)
	state.isNight = isNight
	state.phaseEndsAt = os.time() + (isNight and Balance.Events.NIGHT_LENGTH or Balance.Events.DAY_LENGTH)
	recomputeLuck()

	-- Keep these in step with the Lighting block in default.project.json.
	TweenService:Create(Lighting, TweenInfo.new(6), {
		ClockTime = isNight and 0 or 14,
		Brightness = isNight and 0.8 or 2,
		OutdoorAmbient = isNight and Color3.fromRGB(44, 46, 70) or Color3.fromRGB(105, 105, 118),
	}):Play()

	for _, player in Players:GetPlayers() do
		notify:FireClient(
			player,
			isNight and "index" or "info",
			isNight and `Night! Rare eggs are {Balance.Events.NIGHT_RARITY_BOOST}x more likely` or "Morning."
		)
	end

	broadcast()
end

--- Drops a luck potion somewhere in the Forest for anyone to grab.
local function dropPotion()
	local root = MapBuilder.getRoot()
	local origin = MapBuilder.zoneOrigin("Forest")

	local existing = root.Effects:FindFirstChild("LuckPotion")
	if existing then
		existing:Destroy()
	end

	local bottle = Instance.new("Part")
	bottle.Name = "LuckPotion"
	bottle.Size = Vector3.new(3, 4.5, 3)
	bottle.Position = origin + Vector3.new(math.random(-70, 70), 4, math.random(-70, 70))
	bottle.Color = Color3.fromRGB(120, 235, 120)
	bottle.Material = Enum.Material.Neon
	bottle.Anchored = true
	bottle.CanCollide = false
	bottle.Parent = root.Effects

	MapBuilder.billboard(bottle, "Luck Potion", "Grab it!", Color3.fromRGB(180, 255, 180), 220)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drink"
	prompt.ObjectText = "Luck Potion"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = bottle

	prompt.Triggered:Connect(function(player)
		if not bottle.Parent then
			return
		end
		bottle:Destroy()

		state.potionEndsAt = os.time() + Balance.Events.POTION_DURATION
		state.potionAt = os.time() + Balance.Events.POTION_INTERVAL
		recomputeLuck()
		broadcast()

		for _, other in Players:GetPlayers() do
			notify:FireClient(
				other,
				"success",
				`{player.DisplayName} drank the Luck Potion -- 3x rare eggs for everyone!`
			)
		end
	end)

	task.delay(120, function()
		if bottle.Parent then
			bottle:Destroy()
		end
	end)
end

function WorldEventService.getLuck(): number
	return state.luck
end

function WorldEventService.start()
	state.potionAt = os.time() + Balance.Events.POTION_INTERVAL
	setPhase(false)

	-- Phase clock.
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.time()

			if now >= state.phaseEndsAt then
				setPhase(not state.isNight)
			end

			if now >= state.potionAt and now >= state.potionEndsAt then
				dropPotion()
				-- Push the next drop out; grabbing it re-schedules too.
				state.potionAt = now + Balance.Events.POTION_INTERVAL
			end

			-- Cheap, and never misses the moment a potion expires.
			recomputeLuck()
		end
	end)

	-- Keep clients' countdowns honest without spamming.
	task.spawn(function()
		while true do
			broadcast()
			task.wait(5)
		end
	end)

	Players.PlayerAdded:Connect(function()
		task.delay(2, broadcast)
	end)
end

return WorldEventService
