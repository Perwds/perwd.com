--!strict
-- The latest server snapshot plus a tiny change signal. The client never edits balances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local UpgradeTree = require(Shared.UpgradeTree)
local Economy = require(Shared.Economy)
local Format = require(Shared.Format)

local State = {}

State.econ = Economy.new(Config, UpgradeTree)
State.current = nil :: { [string]: any }?

local listeners: { (snapshot: { [string]: any }, previous: { [string]: any }?) -> () } = {}

function State.set(snapshot: { [string]: any })
	local previous = State.current
	State.current = snapshot
	for _, listener in listeners do
		task.spawn(listener, snapshot, previous)
	end
end

function State.onChange(listener: (snapshot: { [string]: any }, previous: { [string]: any }?) -> ())
	table.insert(listeners, listener)
	if State.current then
		task.spawn(listener, State.current, nil)
	end
end

function State.settings(): { [string]: any }
	local current = State.current
	return if current then current.settings else { music = 0.6, sfx = 0.8, reduceMotion = false, numbers = "short" }
end

function State.reduceMotion(): boolean
	return State.settings().reduceMotion == true
end

function State.fmt(n: number): string
	return Format.number(n, State.settings().numbers)
end

function State.rate(n: number): string
	return Format.rate(n, State.settings().numbers)
end

function State.zoneOpen(zoneId: string): boolean
	local current = State.current
	if not current then
		return zoneId == "orange"
	end
	local unlock = Config.Zones[zoneId].unlock
	if unlock == nil then
		return true
	elseif unlock == "vip" then
		return current.mods.VIP == true
	end
	return current.s[unlock] == true
end

function State.currencyName(id: string): string
	for _, currency in Config.Currencies do
		if currency.id == id then
			return currency.name
		end
	end
	return id
end

return State
