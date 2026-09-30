--!nonstrict
-- Client bootstrap: build the UI, pull the profile once, then keep it in sync
-- from ProfileChanged. The client renders state; it never decides it.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Zones = require(Shared.Config.Zones)

local Hud = require(script.UI.Hud)
local Panels = require(script.UI.Panels)
local FishingController = require(script.Controllers.FishingController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FishingHud"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local hud = Hud.new(screenGui)

local panels = Panels.new(screenGui, {
	onSell = function(selector)
		Net.Event(Net.Events.RequestSell):FireServer(selector)
	end,
	onBuyRod = function(rodId)
		Net.Event(Net.Events.RequestBuyRod):FireServer(rodId)
	end,
	onEquipRod = function(rodId)
		Net.Event(Net.Events.RequestEquipRod):FireServer(rodId)
	end,
	onTravel = function(zoneId)
		Net.Event(Net.Events.RequestTravel):FireServer(zoneId)
		panels:Close()
	end,
})

hud.onPanelRequested = function(id)
	panels:Open(id)
end

-- Zone atmosphere ---------------------------------------------------------------

local currentZone = nil

local function applyZoneAtmosphere(zoneId: string)
	if currentZone == zoneId then
		return
	end
	currentZone = zoneId

	local zone = Zones.Get(zoneId)
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(Lighting, info, {
		FogColor = zone.fogColor,
		FogEnd = zoneId == "abyss" and 320 or 1600,
		OutdoorAmbient = zone.fogColor:Lerp(Color3.new(0, 0, 0), 0.45),
	}):Play()
end

-- Profile sync ------------------------------------------------------------------

local function applyProfile(profile)
	applyZoneAtmosphere(profile.zone)
	hud:SetProfile(profile, Zones.Get(profile.zone).name)
	panels:SetProfile(profile)
end

Net.Event(Net.Events.ProfileChanged).OnClientEvent:Connect(applyProfile)

Net.Event(Net.Events.Notify).OnClientEvent:Connect(function(text, kind)
	hud:Notify(text, kind)
end)

Net.Event(Net.Events.GlobalFeed).OnClientEvent:Connect(function(entries)
	hud:SetFeed(entries)
end)

Net.Event(Net.Events.LeaderboardChanged).OnClientEvent:Connect(function(boards)
	panels:SetLeaderboards(boards)
end)

FishingController.Start({
	gui = screenGui,
	hud = hud,
	panels = panels,
})

-- Initial pull. ProfileChanged also fires on join, but fetching removes the
-- race where the client finishes loading after that first broadcast.
task.spawn(function()
	local ok, payload = pcall(function()
		return Net.Function(Net.Functions.FetchProfile):InvokeServer()
	end)

	if not ok or type(payload) ~= "table" then
		warn("[Client] failed to fetch profile:", payload)
		return
	end

	if payload.profile then
		applyProfile(payload.profile)
	end
	if payload.feed then
		hud:SetFeed(payload.feed)
	end
	if payload.leaderboards then
		panels:SetLeaderboards(payload.leaderboards)
	end
end)
