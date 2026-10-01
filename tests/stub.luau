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

function Vector3.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

function Vector3.__sub(a, b)
	return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

function Vector3.__mul(a, b)
	if type(b) == "number" then
		return Vector3.new(a.X * b, a.Y * b, a.Z * b)
	elseif type(a) == "number" then
		return Vector3.new(b.X * a, b.Y * a, b.Z * a)
	end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end

function Vector3:__index(key)
	if key == "Magnitude" then
		return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2)
	end
	return rawget(Vector3, key)
end

local Vector2 = {}
Vector2.__index = Vector2

function Vector2.new(x, y)
	return setmetatable({ X = x or 0, Y = y or 0 }, Vector2)
end

local CFrame = {}
CFrame.__index = CFrame

local function identity()
	return { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
end

local function matMul(a, b)
	local out = {}
	for row = 0, 2 do
		for col = 0, 2 do
			local sum = 0
			for k = 0, 2 do
				sum += a[row * 3 + k + 1] * b[k * 3 + col + 1]
			end
			out[row * 3 + col + 1] = sum
		end
	end
	return out
end

local function matApply(m, v)
	return Vector3.new(
		m[1] * v.X + m[2] * v.Y + m[3] * v.Z,
		m[4] * v.X + m[5] * v.Y + m[6] * v.Z,
		m[7] * v.X + m[8] * v.Y + m[9] * v.Z
	)
end

function CFrame.new(x, y, z)
	local position
	if type(x) == "table" then
		position = x
	else
		position = Vector3.new(x or 0, y or 0, z or 0)
	end
	return setmetatable({ Position = position, rot = identity() }, CFrame)
end

function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)

	local x = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local y = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local z = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }

	return setmetatable({ Position = Vector3.new(0, 0, 0), rot = matMul(matMul(x, y), z) }, CFrame)
end

CFrame.fromEulerAnglesXYZ = CFrame.Angles

function CFrame.__mul(a, b)
	if getmetatable(b) == Vector3 then
		return a.Position + matApply(a.rot, b)
	end
	return setmetatable({
		Position = a.Position + matApply(a.rot, b.Position),
		rot = matMul(a.rot, b.rot),
	}, CFrame)
end

-- Enum members, memoised so identity comparisons behave.
local Enum = setmetatable({}, {
	__index = function(self, namespace)
		local members = setmetatable({}, {
			__index = function(inner, item)
				local member = { Name = item, EnumType = namespace }
				rawset(inner, item, member)
				return member
			end,
		})
		rawset(self, namespace, members)
		return members
	end,
})

-- Enough of Instance to let the model builders run and be inspected.
local instanceMethods = {}

function instanceMethods:SetAttribute(name, value)
	rawget(self, "_attributes")[name] = value
end

function instanceMethods:GetAttribute(name)
	return rawget(self, "_attributes")[name]
end

function instanceMethods:IsA(className)
	return rawget(self, "ClassName") == className
end

function instanceMethods:GetChildren()
	local copy = {}
	for _, child in rawget(self, "_children") do
		table.insert(copy, child)
	end
	return copy
end

function instanceMethods:FindFirstChild(name)
	for _, child in rawget(self, "_children") do
		if rawget(child, "Name") == name then
			return child
		end
	end
	return nil
end

local Instance = {}

function Instance.new(className)
	local instance = {
		ClassName = className,
		Name = className,
		_children = {},
		_attributes = {},
	}

	return setmetatable(instance, {
		__index = function(_, key)
			return instanceMethods[key]
		end,
		__newindex = function(self, key, value)
			rawset(self, key, value)
			if key == "Parent" and type(value) == "table" then
				local siblings = rawget(value, "_children")
				if siblings then
					table.insert(siblings, self)
				end
			end
		end,
	})
end

local NumberRange = {}
NumberRange.__index = NumberRange

function NumberRange.new(min, max)
	return setmetatable({ Min = min, Max = max or min }, NumberRange)
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
