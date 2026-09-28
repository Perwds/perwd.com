--!strict
--[[
	Format
	Number -> display string. Shared so the server's flex messages and the
	client's cards always read identically.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }
local MONTHS = {
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}

--- 1234567 -> "1,234,567"
function Format.comma(n: number): string
	local negative = n < 0
	local whole = math.floor(math.abs(n) + 0.5)
	local text = tostring(whole)
	local out = ""

	while #text > 3 do
		out = "," .. text:sub(-3) .. out
		text = text:sub(1, -4)
	end
	out = text .. out

	return (negative and "-" or "") .. out
end

--- 1234567 -> "1.23M". Used where a full comma string would overflow the card.
function Format.short(n: number, places: number?): string
	local negative = n < 0
	local value = math.abs(n)
	local tier = 0

	while value >= 1000 and tier < #SUFFIXES - 1 do
		value /= 1000
		tier += 1
	end

	local decimals = places or (value < 10 and 2 or (value < 100 and 1 or 0))
	local text = string.format("%." .. decimals .. "f", value)

	-- trim trailing zeros so "1.00M" reads as "1M"
	if text:find("%.") then
		text = text:gsub("0+$", ""):gsub("%.$", "")
	end

	return (negative and "-" or "") .. text .. SUFFIXES[tier + 1]
end

--- Hours as a human duration: "52,605h" with a friendly sub-line elsewhere.
function Format.hours(hours: number): string
	if hours < 1 then
		return string.format("%dm", math.floor(hours * 60 + 0.5))
	end
	return Format.comma(hours) .. "h"
end

function Format.minutes(minutes: number): string
	if minutes < 60 then
		return string.format("%dm", math.floor(minutes + 0.5))
	end
	local h = math.floor(minutes / 60)
	local m = math.floor(minutes % 60 + 0.5)
	if m == 0 then
		return h .. "h"
	end
	return string.format("%dh %dm", h, m)
end

function Format.days(days: number): string
	local whole = math.floor(days + 0.5)
	if whole < 365 then
		return Format.comma(whole) .. (whole == 1 and " day" or " days")
	end
	local years = whole / 365.25
	return string.format("%s days (%.1f yrs)", Format.comma(whole), years)
end

--- Unix seconds -> "14 March 2016"
function Format.date(unixSeconds: number): string
	local t = os.date("!*t", math.floor(unixSeconds))
	return string.format("%d %s %d", t.day, MONTHS[t.month], t.year)
end

function Format.studs(studs: number): string
	return Format.comma(studs) .. " studs"
end

function Format.robux(amount: number): string
	return "R$ " .. Format.comma(amount)
end

function Format.usd(amount: number): string
	if amount >= 1000 then
		return "$" .. Format.comma(amount)
	end
	return string.format("$%.2f", amount)
end

function Format.percent(value: number): string
	if value < 0.01 and value > 0 then
		return string.format("%.4f%%", value)
	elseif value < 1 then
		return string.format("%.2f%%", value)
	end
	return string.format("%.1f%%", value)
end

function Format.decimal(value: number): string
	return string.format("%.2f", value)
end

--- Dispatch on a StatConfig `format` field.
function Format.value(kind: string, value: number): string
	if kind == "hours" then
		return Format.hours(value)
	elseif kind == "minutes" then
		return Format.minutes(value)
	elseif kind == "days" then
		return Format.days(value)
	elseif kind == "date" then
		return Format.date(value)
	elseif kind == "studs" then
		return Format.studs(value)
	elseif kind == "robux" then
		return Format.robux(value)
	elseif kind == "usd" then
		return Format.usd(value)
	elseif kind == "percent" then
		return Format.percent(value)
	elseif kind == "decimal" then
		return Format.decimal(value)
	end
	return Format.comma(value)
end

--- Seconds remaining -> "1:04" / "12s"
function Format.clock(seconds: number): string
	if seconds <= 0 then
		return "0.0s"
	elseif seconds < 10 then
		return string.format("%.1fs", seconds)
	elseif seconds < 60 then
		return string.format("%ds", math.floor(seconds))
	end
	return string.format("%d:%02d", math.floor(seconds / 60), math.floor(seconds % 60))
end

return Format
