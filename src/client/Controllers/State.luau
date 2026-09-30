--[[
	Client-side mirror of the server's state payload.

	Every panel reads from here instead of holding its own copy, and
	subscribes to `changed` to re-render. `tick` payloads patch only the hot
	fields so a cash update does not force the Pet Index to rebuild 104 tiles.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local State = {}

State.data = {
	cash = 0,
	income = 0,
	pets = {},
	equipped = {},
	pads = {},
	index = { worlds = {}, limited = {}, totalFound = 0, total = 0 },
	ugc = {},
	worlds = {},
	limits = { equip = 6, inventory = 250, pads = 3, fuseInputs = 3 },
	stats = {},
	playtime = 0,
	dailyStreak = 0,
}

State.world = {
	isNight = false,
	phaseIn = 0,
	potionIn = 0,
	potionActive = false,
	luck = 1,
}

--- Fires on every sync. Payload kind is "full" or "tick".
State.changed = Signal.new()
--- Fires only when the heavy payloads (index, ugc, pets) changed.
State.fullChanged = Signal.new()
State.worldChanged = Signal.new()

local ready = false

function State.isReady(): boolean
	return ready
end

local function apply(payload)
	if type(payload) ~= "table" then
		return
	end

	if payload.kind == "tick" then
		State.data.cash = payload.cash or State.data.cash
		State.data.income = payload.income or State.data.income
		State.data.pads = payload.pads or State.data.pads
		State.changed:Fire("tick")
		return
	end

	for key, value in payload do
		if key ~= "kind" then
			State.data[key] = value
		end
	end

	ready = true
	State.changed:Fire("full")
	State.fullChanged:Fire()
end

function State.request()
	task.spawn(function()
		local ok, payload = pcall(function()
			return Net.Function("RequestState"):InvokeServer()
		end)
		if ok and payload then
			apply(payload)
		end
	end)
end

--- Convenience lookups the panels use constantly.
function State.petsByRarity(rarityName: string)
	local out = {}
	for _, pet in State.data.pets do
		if pet.rarity == rarityName then
			table.insert(out, pet)
		end
	end
	return out
end

function State.ugcById(id: string)
	for _, entry in State.data.ugc do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function State.indexForWorld(world: string)
	for _, entry in State.data.index.worlds do
		if entry.world == world then
			return entry
		end
	end
	return nil
end

function State.start()
	Net.Event("StateSync").OnClientEvent:Connect(apply)

	Net.Event("WorldEvent").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		for key, value in payload do
			State.world[key] = value
		end
		State.worldChanged:Fire()
	end)

	State.request()

	-- The countdowns tick locally between server broadcasts so they read
	-- smoothly instead of jumping every five seconds.
	task.spawn(function()
		while true do
			task.wait(1)
			State.world.phaseIn = math.max(0, State.world.phaseIn - 1)
			State.world.potionIn = math.max(0, State.world.potionIn - 1)
			State.worldChanged:Fire()
		end
	end)
end

return State
