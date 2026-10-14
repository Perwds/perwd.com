--!strict
-- Server boot. Lighting.Technology is set in default.project.json because scripts can't change it.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Remotes = require(script.Remotes)
local Data = require(script.Data)
local Currency = require(script.Currency)
local BoardBuilder = require(script.BoardBuilder)
local UpgradeService = require(script.UpgradeService)
local GroveService = require(script.GroveService)
local Production = require(script.Production)
local Prestige = require(script.Prestige)
local Monetization = require(script.Monetization)
local ZoneService = require(script.ZoneService)
local NpcService = require(script.NpcService)

local function setupLighting()
	for _, child in Lighting:GetChildren() do
		if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("Clouds") or child:IsA("PostEffect") then
			child:Destroy()
		end
	end
	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(128, 126, 140)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 148, 165)
	Lighting.EnvironmentDiffuseScale = 0.35
	Lighting.EnvironmentSpecularScale = 0.15
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	Lighting.FogEnd = 100000
	Lighting.ExposureCompensation = 0

	local sky = Instance.new("Sky")
	sky.CelestialBodiesShown = false
	sky.StarCount = 5000
	sky.Parent = Lighting

	-- Neon reads as glow; GUI text tops out at 1.0 and stays under the threshold, so it never smears.
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 22
	bloom.Threshold = 1.25
	bloom.Parent = Lighting

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Saturation = 0.08
	grade.Contrast = 0.06
	grade.Parent = Lighting
end

local function snapshot(player: Player): { [string]: any }?
	local data = Data.get(player)
	if not data then
		return nil
	end
	local s = UpgradeService.stats(player)
	return {
		c = data.currencies,
		peels = data.peels,
		levels = data.levels,
		s = s,
		machines = data.machines,
		mods = UpgradeService.mods(player),
		labBoostLeft = math.max(0, data.labBoostUntil - os.time()),
		pendingSeeds = UpgradeService.econ:pendingSeeds(data, s),
		lifetimeCrates = data.lifetimeCrates,
		seedsClaimed = data.seedsClaimed,
		replants = data.replants,
		settings = data.settings,
		tutorial = data.tutorial,
		ready = player:GetAttribute("PassesReady") == true,
	}
end

local function sanitizeSettings(input: { [any]: any }, current: { [string]: any })
	local function volume(value: any): number?
		return if type(value) == "number" and value == value then math.clamp(value, 0, 1) else nil
	end
	current.music = volume(input.music) or current.music
	current.sfx = volume(input.sfx) or current.sfx
	if type(input.reduceMotion) == "boolean" then
		current.reduceMotion = input.reduceMotion
	end
	if input.numbers == "short" or input.numbers == "full" then
		current.numbers = input.numbers
	end
end

setupLighting()
Remotes.init()
BoardBuilder.build({ vip = Monetization.enabled("VIP") })

Data.init()
Currency.init()
UpgradeService.init()
Monetization.init()
GroveService.init()
Production.init()
Prestige.init()
ZoneService.init()
NpcService.init()

Currency.setSnapshotBuilder(snapshot)

Remotes.on("SaveSettings", function(player: Player, input: { [any]: any })
	local data = Data.get(player)
	if data then
		sanitizeSettings(input, data.settings)
	end
end)

Remotes.on("TutorialStep", function(player: Player, step: number)
	local data = Data.get(player)
	if data then
		data.tutorial = math.clamp(step, data.tutorial, #Config.Tutorial + 1)
	end
end)

local function onPlayer(player: Player)
	local profile = Data.load(player)
	if profile then
		UpgradeService.refresh(player)
		Currency.pushNow(player)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
