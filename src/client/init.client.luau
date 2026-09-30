--!nonstrict
-- Client bootstrap: build the UI, pull the profile once, then keep it in sync
-- from ProfileChanged. The client renders state; it never decides it.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Zones = require(Shared.Config.Zones)

local Hud = require(script.UI.Hud)
local Panels = require(script.UI.Panels)
local Atmosphere = require(script.Effects.Atmosphere)
local FishingController = require(script.Controllers.FishingController)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FishingHud"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

Atmosphere.Start()

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

-- Profile sync ------------------------------------------------------------------

local firstProfile = true

local function applyProfile(profile)
	-- Snap the look on the first payload, cross-fade it on every later change.
	Atmosphere.Apply(profile.zone, firstProfile)
	firstProfile = false

	FishingController.SetZone(profile.zone)
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
