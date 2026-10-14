--!strict
-- Client boot. Everything here is display and input; the server decides every outcome.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Palette = require(ReplicatedStorage.Shared.Palette)

local State = require(script.State)
local Audio = require(script.Audio)
local Hud = require(script.Hud)
local PickFx = require(script.PickFx)
local Orchard = require(script.Orchard)
local TreeBoard = require(script.TreeBoard)
local Machines = require(script.Machines)
local OverviewCam = require(script.OverviewCam)
local ShopUi = require(script.ShopUi)
local Settings = require(script.Settings)
local Guide = require(script.Guide)

local remotes = ReplicatedStorage:WaitForChild("Remotes") :: Folder

Hud.init()
Audio.init()
PickFx.init()
TreeBoard.init(remotes)
Orchard.init(remotes)
Machines.init(remotes)
OverviewCam.init()
ShopUi.init(remotes)
Settings.init(remotes)
Guide.init(remotes)

remotes.State.OnClientEvent:Connect(function(snapshot)
	State.set(snapshot)
end)

remotes.Notice.OnClientEvent:Connect(function(kind: string, info: { [string]: any })
	if kind == "offline" then
		Hud.offline(info)
	elseif kind == "zoneLocked" then
		Hud.toast("THAT AREA ISN'T OPEN YET", Palette.deny)
	elseif kind == "replanted" then
		Audio.replant()
		Hud.toast("REPLANTED. +" .. State.fmt(info.seeds) .. " GOLDEN SEEDS", Palette.gold)
	elseif kind == "replantDenied" then
		Hud.toast("NO GOLDEN SEEDS READY YET", Palette.deny)
	elseif kind == "product" then
		if info.oranges then
			Hud.toast("CRATE OF ORANGES: +" .. State.fmt(info.oranges), Palette.zones.orange.neon)
		else
			Hud.toast("LAB BOOST IS ON", Palette.zones.vitamin.neon)
		end
	elseif kind == "pass" then
		Audio.chime()
		Hud.toast(string.upper(info.name) .. " UNLOCKED. THANK YOU!", Palette.zones.vip.neon)
	end
end)

-- VIP chat tag.
TextChatService.OnIncomingMessage = function(message: TextChatMessage)
	local properties = Instance.new("TextChatMessageProperties")
	local source = message.TextSource
	local sender = source and Players:GetPlayerByUserId(source.UserId)
	if sender and sender:GetAttribute("VIP") then
		properties.PrefixText =
			string.format('<font color="#%s">[VIP]</font> %s', Palette.zones.vip.neon:ToHex(), message.PrefixText)
	end
	return properties
end
