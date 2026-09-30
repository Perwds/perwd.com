--!nonstrict
-- Selling, rod purchases, and zone travel. Every price and unlock check is
-- re-derived here from the config; the client's request only names *what* it
-- wants, never what it costs.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Net = require(Shared.Net)
local Rods = require(Shared.Config.Rods)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Util.Format)

local DataService = require(script.Parent.DataService)
local MapBuilder = require(script.Parent.Parent.World.MapBuilder)

local EconomyService = {}

local function notify(player: Player, text: string, kind: string?)
	Net.Event(Net.Events.Notify):FireClient(player, text, kind or "info")
end

local function credit(profile, amount: number)
	profile.coins += amount
	profile.lifetimeCoins += amount
end

local function onRequestSell(player: Player, selector: unknown)
	local profile = DataService.Get(player)
	if not profile then
		return
	end

	if #profile.inventory == 0 then
		notify(player, "Nothing to sell.", "warn")
		return
	end

	local earned = 0
	local sold = 0

	if selector == "all" then
		for _, entry in profile.inventory do
			earned += entry.value
			sold += 1
		end
		table.clear(profile.inventory)
	elseif type(selector) == "number" then
		for index, entry in profile.inventory do
			if entry.uid == selector then
				earned = entry.value
				sold = 1
				table.remove(profile.inventory, index)
				break
			end
		end
	else
		return
	end

	if sold == 0 then
		return
	end

	credit(profile, earned)
	DataService.MarkChanged(player)

	notify(
		player,
		string.format("Sold %d fish for %s coins.", sold, Format.Commas(earned)),
		"good"
	)
end

local function onRequestBuyRod(player: Player, rodId: unknown)
	local profile = DataService.Get(player)
	if not profile then
		return
	end

	if type(rodId) ~= "string" or not Rods.Data[rodId] then
		return
	end

	if profile.rods[rodId] then
		notify(player, "You already own that rod.", "warn")
		return
	end

	local rod = Rods.Get(rodId)
	if profile.coins < rod.cost then
		notify(
			player,
			string.format("Need %s more coins.", Format.Abbreviate(rod.cost - profile.coins)),
			"warn"
		)
		return
	end

	profile.coins -= rod.cost
	profile.rods[rodId] = true
	profile.equippedRod = rodId

	DataService.MarkChanged(player)
	notify(player, string.format("Bought and equipped the %s.", rod.name), "good")
end

local function onRequestEquipRod(player: Player, rodId: unknown)
	local profile = DataService.Get(player)
	if not profile then
		return
	end

	if type(rodId) ~= "string" or not profile.rods[rodId] then
		return
	end

	profile.equippedRod = rodId
	DataService.MarkChanged(player)
	notify(player, string.format("Equipped the %s.", Rods.Get(rodId).name), "info")
end

local function onRequestTravel(player: Player, zoneId: unknown)
	local profile = DataService.Get(player)
	if not profile then
		return
	end

	if type(zoneId) ~= "string" or not Zones.Data[zoneId] then
		return
	end

	if not Zones.IsUnlocked(zoneId, profile.lifetimeCoins) then
		local zone = Zones.Get(zoneId)
		notify(
			player,
			string.format(
				"%s unlocks at %s lifetime coins.",
				zone.name,
				Format.Abbreviate(zone.unlockCoins)
			),
			"warn"
		)
		return
	end

	profile.zone = zoneId
	DataService.MarkChanged(player)

	EconomyService.TeleportToZone(player, zoneId)
	notify(player, string.format("Travelled to %s.", Zones.Get(zoneId).name), "good")
end

function EconomyService.TeleportToZone(player: Player, zoneId: string)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	-- Face out over the water from the head of the pier.
	local arrival = MapBuilder.ArrivalPoint(zoneId)
	root.CFrame = CFrame.new(arrival, arrival + Vector3.new(0, -0.2, 1))
end

function EconomyService.Start()
	Net.Event(Net.Events.RequestSell).OnServerEvent:Connect(onRequestSell)
	Net.Event(Net.Events.RequestBuyRod).OnServerEvent:Connect(onRequestBuyRod)
	Net.Event(Net.Events.RequestEquipRod).OnServerEvent:Connect(onRequestEquipRod)
	Net.Event(Net.Events.RequestTravel).OnServerEvent:Connect(onRequestTravel)
end

return EconomyService
