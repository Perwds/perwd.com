--[[
	📍 LOCATION: ReplicatedStorage > Shared > Format (ModuleScript)

	Number & time formatting: 14.3k, 1.2M, 4.5B ...
]]

local Format = {}

local SUFFIXES = { "", "k", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.Abbrev(n)
	n = tonumber(n) or 0
	local sign = n < 0 and "-" or ""
	n = math.abs(n)
	if n < 1000 then
		if n == math.floor(n) then
			return sign .. tostring(math.floor(n))
		end
		return sign .. string.format("%.1f", math.floor(n * 10) / 10)
	end
	local i = 1
	while n >= 1000 and i < #SUFFIXES do
		n /= 1000
		i += 1
	end
	local s
	if n >= 100 then
		s = tostring(math.floor(n))
	else
		s = string.format("%.1f", math.floor(n * 10) / 10)
		s = (string.gsub(s, "%.0$", ""))
	end
	return sign .. s .. SUFFIXES[i]
end

function Format.Coins(n)
	return "$" .. Format.Abbrev(n)
end

function Format.Time(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%dh %02dm", h, m)
	elseif m > 0 then
		return string.format("%dm %02ds", m, s)
	end
	return string.format("%ds", s)
end

function Format.Clock(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

-- Short duration label for gift timers: 5m, 1h 30m, 3h
function Format.Short(seconds)
	seconds = math.floor(seconds)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 and m > 0 then
		return h .. "h " .. m .. "m"
	elseif h > 0 then
		return h .. "h"
	end
	return m .. "m"
end

return Format
