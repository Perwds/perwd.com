--!nonstrict
-- Enough of the Roblox API for the pure shared modules to load outside Studio.
-- Only the datatypes the config and roll code actually touch.

local Color3 = {}
Color3.__index = Color3

function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3)
end

function Color3.fromRGB(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end

function Color3:Lerp(other, alpha)
	return Color3.new(
		self.R + (other.R - self.R) * alpha,
		self.G + (other.G - self.G) * alpha,
		self.B + (other.B - self.B) * alpha
	)
end

function Color3:ToHex()
	return string.format(
		"%02X%02X%02X",
		math.floor(self.R * 255 + 0.5),
		math.floor(self.G * 255 + 0.5),
		math.floor(self.B * 255 + 0.5)
	)
end

local Vector3 = {}
Vector3.__index = Vector3

function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end

local RandomProto = {}
RandomProto.__index = RandomProto

function RandomProto:NextNumber(low, high)
	if low == nil then
		return math.random()
	end
	return low + math.random() * (high - low)
end

function RandomProto:NextInteger(low, high)
	return math.random(low, high)
end

local Random = {}

function Random.new(seed)
	if seed then
		math.randomseed(seed)
	end
	return setmetatable({}, RandomProto)
end
