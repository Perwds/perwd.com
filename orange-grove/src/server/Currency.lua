--!strict
-- Balances live in the player's save. This module is the only writer, tracks per-second rates,
-- and pushes state snapshots to the owning client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Format)
local Data = require(script.Parent.Data)
local Remotes = require(script.Parent.Remotes)

local Currency = {}

local IDS = { "oranges", "vitamin", "zest", "crates", "seeds" }
local SEND_INTERVAL = 0.25
local RATE_SMOOTHING = 0.35

type Track = {
	dirty: boolean,
	flow: { [string]: number },
	rates: { [string]: number },
	grossOranges: number,
	grossOrangeRate: number,
}

local tracks: { [Player]: Track } = {}
local snapshotBuilder: ((Player) -> { [string]: any }?)? = nil

local function track(player: Player): Track
	local t = tracks[player]
	if not t then
		t = {
			dirty = true,
			flow = {},
			rates = {},
			grossOranges = 0,
			grossOrangeRate = 0,
		}
		for _, id in IDS do
			t.flow[id] = 0
			t.rates[id] = 0
		end
		tracks[player] = t
	end
	return t
end

function Currency.get(player: Player, id: string): number
	local data = Data.get(player)
	return if data then data.currencies[id] or 0 else 0
end

-- Production and picking. Negative amounts are machine consumption; both count toward the shown rate.
function Currency.add(player: Player, id: string, amount: number)
	local data = Data.get(player)
	if not data or amount ~= amount then
		return
	end
	data.currencies[id] = math.max(0, (data.currencies[id] or 0) + amount)
	local t = track(player)
	t.flow[id] += amount
	if id == "oranges" and amount > 0 then
		t.grossOranges += amount
	end
	t.dirty = true
end

-- Purchases. Not counted as a rate, so buying doesn't make the bar show a negative income.
function Currency.spend(player: Player, id: string, amount: number): boolean
	local data = Data.get(player)
	if not data or amount < 0 or (data.currencies[id] or 0) < amount then
		return false
	end
	data.currencies[id] -= amount
	track(player).dirty = true
	return true
end

-- Applies changes made directly to the save (Economy.step, Replant) and counts them as flow.
function Currency.recordDelta(player: Player, before: { [string]: number })
	local data = Data.get(player)
	if not data then
		return
	end
	local t = track(player)
	for _, id in IDS do
		local delta = (data.currencies[id] or 0) - (before[id] or 0)
		if delta ~= 0 then
			t.flow[id] += delta
			if id == "oranges" and delta > 0 then
				t.grossOranges += delta
			end
		end
	end
	t.dirty = true
end

function Currency.rates(player: Player): { [string]: number }
	return track(player).rates
end

-- Smoothed oranges gained per second, ignoring what the machines eat. Used for "10 minutes of production".
function Currency.grossOrangeRate(player: Player): number
	return track(player).grossOrangeRate
end

function Currency.format(n: number): string
	return Format.short(n)
end

function Currency.markDirty(player: Player)
	track(player).dirty = true
end

function Currency.setSnapshotBuilder(builder: (Player) -> { [string]: any }?)
	snapshotBuilder = builder
end

function Currency.pushNow(player: Player)
	if not snapshotBuilder then
		return
	end
	local snapshot = (snapshotBuilder :: (Player) -> { [string]: any }?)(player)
	if snapshot then
		snapshot.rates = track(player).rates
		Remotes.fire("State", player, snapshot)
		track(player).dirty = false
	end
end

function Currency.init()
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for _, t in tracks do
				for _, id in IDS do
					t.rates[id] += (t.flow[id] - t.rates[id]) * RATE_SMOOTHING
					if math.abs(t.rates[id]) < 1e-4 then
						t.rates[id] = 0
					end
					t.flow[id] = 0
				end
				t.grossOrangeRate += (t.grossOranges - t.grossOrangeRate) * RATE_SMOOTHING
				t.grossOranges = 0
				t.dirty = true
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(SEND_INTERVAL)
			for player, t in tracks do
				if t.dirty then
					Currency.pushNow(player)
				end
			end
		end
	end)
end

return Currency
