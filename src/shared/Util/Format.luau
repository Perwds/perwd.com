--!nonstrict
-- Display helpers. Coin values run to the billions, so everything the player
-- reads goes through here.

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp" }

function Format.Abbreviate(value: number): string
	if value ~= value or value == math.huge then
		return "?"
	end

	local negative = value < 0
	value = math.abs(value)

	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end

	local text
	if index == 1 then
		text = string.format("%d", math.floor(value))
	elseif value < 10 then
		text = string.format("%.2f", value)
	elseif value < 100 then
		text = string.format("%.1f", value)
	else
		text = string.format("%.0f", value)
	end

	-- Trim "1.50K" down to "1.5K". Only ever touches a decimal tail, so plain
	-- integers like "100" survive intact.
	if text:find("%.") then
		text = text:gsub("0+$", "")
		text = text:gsub("%.$", "")
	end

	return (negative and "-" or "") .. text .. SUFFIXES[index]
end

function Format.Commas(value: number): string
	local whole = string.format("%d", math.floor(math.abs(value)))
	local withCommas = whole:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	withCommas = withCommas:gsub("^,", "")
	return (value < 0 and "-" or "") .. withCommas
end

function Format.Weight(kg: number): string
	if kg < 0.01 then
		return string.format("%.1f g", kg * 1000)
	elseif kg < 1 then
		return string.format("%.0f g", kg * 1000)
	elseif kg < 100 then
		return string.format("%.2f kg", kg)
	end
	return string.format("%s kg", Format.Abbreviate(kg))
end

-- "1 in 12.0K"
function Format.Odds(oneInN: number): string
	if oneInN == math.huge then
		return "never"
	elseif oneInN < 100 then
		return string.format("1 in %.1f", oneInN)
	end
	return "1 in " .. Format.Abbreviate(oneInN)
end

function Format.Duration(seconds: number): string
	seconds = math.max(math.floor(seconds), 0)
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	local secs = seconds % 60

	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, secs)
	end
	return string.format("%ds", secs)
end

return Format
