--!strict
-- Number formatting: 99.2, 1.41K, 76.55K, 120.4K, 3.4M, 5.6B, then 1.00e12.

local Format = {}

local SUFFIXES = { "K", "M", "B" }

local function trim(text: string): string
	if string.find(text, "%.") then
		text = string.gsub(text, "0+$", "")
		text = string.gsub(text, "%.$", "")
	end
	return text
end

function Format.short(n: number): string
	if n ~= n then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		if n >= 100 or n == math.floor(n) then
			return sign .. tostring(math.floor(n))
		end
		return sign .. trim(string.format("%.1f", math.floor(n * 10) / 10))
	end
	if n >= 1e12 then
		local exponent = math.floor(math.log10(n))
		return sign .. string.format("%.2fe%d", math.floor(n / 10 ^ exponent * 100) / 100, exponent)
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES)
	local scaled = n / 10 ^ (tier * 3)
	-- Floor rather than round so a cost never shows as affordable before it is.
	local text = if scaled >= 100
		then string.format("%.1f", math.floor(scaled * 10) / 10)
		else string.format("%.2f", math.floor(scaled * 100) / 100)
	return sign .. trim(text) .. SUFFIXES[tier]
end

function Format.full(n: number): string
	if n ~= n then
		return "0"
	end
	if math.abs(n) >= 1e15 then
		return Format.short(n)
	end
	local sign = if n < 0 then "-" else ""
	local whole = tostring(math.floor(math.abs(n)))
	local grouped = string.reverse((string.gsub(string.reverse(whole), "(%d%d%d)", "%1,")))
	grouped = string.gsub(grouped, "^,", "")
	if math.abs(n) < 100 and math.abs(n) ~= math.floor(math.abs(n)) then
		return sign .. trim(string.format("%.1f", math.floor(math.abs(n) * 10) / 10))
	end
	return sign .. grouped
end

function Format.number(n: number, style: string?): string
	if style == "full" then
		return Format.full(n)
	end
	return Format.short(n)
end

function Format.rate(n: number, style: string?): string
	local sign = if n < 0 then "-" else "+"
	return sign .. Format.number(math.abs(n), style) .. "/s"
end

function Format.duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds // 60) % 60)
	elseif seconds >= 60 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	end
	return string.format("%ds", seconds)
end

return Format
