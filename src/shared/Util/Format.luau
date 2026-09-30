--[[ Number and duration formatting for the HUD. ]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

--- 1234567 -> "1.23M". Keeps three significant digits, like the shop cards.
function Format.abbreviate(value: number): string
	if value ~= value or value == math.huge then
		return "?"
	end

	local sign = value < 0 and "-" or ""
	value = math.abs(value)

	if value < 1000 then
		-- Whole numbers below 1K read better without decimals.
		return sign .. tostring(math.floor(value + 0.5))
	end

	local tier = math.floor(math.log(value, 1000))
	tier = math.clamp(tier, 1, #SUFFIXES - 1)

	local scaled = value / (1000 ^ tier)

	-- Rounding can push a value to "1000K"; promote it to "1M" instead.
	if scaled >= 999.5 and tier < #SUFFIXES - 1 then
		tier += 1
		scaled = value / (1000 ^ tier)
	end
	local text
	if scaled < 10 then
		text = string.format("%.2f", scaled)
	elseif scaled < 100 then
		text = string.format("%.1f", scaled)
	else
		text = string.format("%.0f", scaled)
	end

	-- Trim "1.20" -> "1.2", "1.00" -> "1"
	text = text:gsub("%.?0+$", "")

	return sign .. text .. SUFFIXES[tier + 1]
end

--- 1234567 -> "1,234,567"
function Format.comma(value: number): string
	local whole = tostring(math.floor(math.abs(value)))
	local out = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (value < 0 and "-" or "") .. out
end

--- 1285 -> "21m 25s". Matches the HUD countdown style.
function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))

	local days = math.floor(seconds / 86400)
	local hours = math.floor(seconds % 86400 / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	local secs = seconds % 60

	if days > 0 then
		return string.format("%dd %dh %dm %ds", days, hours, minutes, secs)
	elseif hours > 0 then
		return string.format("%dh %dm %ds", hours, minutes, secs)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

--- Short form for tight spaces: "21:25"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	local secs = seconds % 60
	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

--- 0.065 -> "6.5%"
function Format.percent(fraction: number): string
	local value = fraction * 100
	if value >= 10 then
		return string.format("%d%%", math.floor(value + 0.5))
	elseif value >= 1 then
		return (string.format("%.1f", value):gsub("%.0$", "")) .. "%"
	end
	return (string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")) .. "%"
end

return Format
