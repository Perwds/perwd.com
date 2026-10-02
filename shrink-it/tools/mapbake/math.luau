-- Minimal Roblox stand-in with REAL CFrame math, used to dump ObjectModels to JSON for previews.
local V3 = {}
V3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z); if m == 0 then return Vector3.new(0, 0, 0) end return Vector3.new(t.X / m, t.Y / m, t.Z / m) end
	if k == "Lerp" then return function(a, b, al) return a + (b - a) * al end end
	if k == "Dot" then return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end end
	if k == "Cross" then return function(a, b) return Vector3.new(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end end
	if k == "Abs" then return function(a) return Vector3.new(math.abs(a.X), math.abs(a.Y), math.abs(a.Z)) end end
	error("Vector3." .. tostring(k), 2)
end
local function isV(a) return type(a) == "table" and getmetatable(a) == V3 end
V3.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b)
	if type(b) == "number" then return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3 = { new = function(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3) end }
Vector3.one = Vector3.new(1, 1, 1)
Vector3.zero = Vector3.new(0, 0, 0)
Vector3.xAxis = Vector3.new(1, 0, 0)
Vector3.yAxis = Vector3.new(0, 1, 0)
Vector3.zAxis = Vector3.new(0, 0, 1)

-- CFrame: p + rotation matrix rows r[1..9] (row-major: R00 R01 R02 R10 ...)
local CF = {}
local function mk(p, r) return setmetatable({ p = p, r = r }, CF) end
local function rotMul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do s += a[i * 3 + k + 1] * b[k * 3 + j + 1] end
			r[i * 3 + j + 1] = s
		end
	end
	return r
end
local function rotVec(r, v)
	return Vector3.new(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function transpose(r) return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] } end
CF.__index = function(t, k)
	if k == "Position" or k == "p" then return rawget(t, "p") end
	if k == "X" then return t.p.X end
	if k == "Y" then return t.p.Y end
	if k == "Z" then return t.p.Z end
	if k == "LookVector" then return rotVec(t.r, Vector3.new(0, 0, -1)) end
	if k == "RightVector" then return rotVec(t.r, Vector3.new(1, 0, 0)) end
	if k == "UpVector" then return rotVec(t.r, Vector3.new(0, 1, 0)) end
	if k == "Rotation" then return mk(Vector3.zero, t.r) end
	if k == "Inverse" then return function(self) local rt = transpose(self.r); return mk(-rotVec(rt, self.p), rt) end end
	if k == "PointToObjectSpace" then return function(self, v) return rotVec(transpose(self.r), v - self.p) end end
	if k == "PointToWorldSpace" then return function(self, v) return self.p + rotVec(self.r, v) end end
	if k == "VectorToWorldSpace" then return function(self, v) return rotVec(self.r, v) end end
	if k == "ToObjectSpace" then return function(self, o) return self:Inverse() * o end end
	if k == "Lerp" then return function(a, b, al) return mk(a.p:Lerp(b.p, al), al < 0.5 and a.r or b.r) end end
	if k == "GetComponents" then return function(self) local r = self.r; return self.p.X, self.p.Y, self.p.Z, r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] end end
	error("CFrame." .. tostring(k), 2)
end
CF.__mul = function(a, b)
	if isV(b) then return a.p + rotVec(a.r, b) end
	return mk(a.p + rotVec(a.r, b.p), rotMul(a.r, b.r))
end
CF.__add = function(a, v) return mk(a.p + v, a.r) end
CF.__sub = function(a, v) return mk(a.p - v, a.r) end
local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function rx(a) local c, s = math.cos(a), math.sin(a); return { 1, 0, 0, 0, c, -s, 0, s, c } end
local function ry(a) local c, s = math.cos(a), math.sin(a); return { c, 0, s, 0, 1, 0, -s, 0, c } end
local function rz(a) local c, s = math.cos(a), math.sin(a); return { c, -s, 0, s, c, 0, 0, 0, 1 } end
CFrame = {}
CFrame.new = function(a, b, c, ...)
	if a == nil then return mk(Vector3.zero, I) end
	if isV(a) and b == nil then return mk(a, I) end
	if isV(a) and isV(b) then return CFrame.lookAt(a, b) end
	local rest = { ... }
	if #rest == 9 then return mk(Vector3.new(a, b, c), rest) end
	return mk(Vector3.new(a, b, c), I)
end
CFrame.Angles = function(x, y, z) return mk(Vector3.zero, rotMul(rotMul(rx(x or 0), ry(y or 0)), rz(z or 0))) end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
CFrame.fromEulerAnglesYXZ = function(x, y, z) return mk(Vector3.zero, rotMul(rotMul(ry(y or 0), rx(x or 0)), rz(z or 0))) end
CFrame.fromOrientation = CFrame.fromEulerAnglesYXZ
CFrame.fromAxisAngle = function(axis, ang)
	local u = axis.Unit
	local c, s, t = math.cos(ang), math.sin(ang), 1 - math.cos(ang)
	local x, y, z = u.X, u.Y, u.Z
	return mk(Vector3.zero, { t * x * x + c, t * x * y - s * z, t * x * z + s * y, t * x * y + s * z, t * y * y + c, t * y * z - s * x, t * x * z - s * y, t * y * z + s * x, t * z * z + c })
end
CFrame.lookAt = function(pos, target, up)
	up = up or Vector3.new(0, 1, 0)
	local look = (target - pos).Unit
	if look.Magnitude < 1e-9 then return mk(pos, I) end
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then right = look:Cross(Vector3.new(0, 0, 1)) end
	right = right.Unit
	local upv = right:Cross(look).Unit
	local back = -look
	-- columns: right, up, back
	return mk(pos, { right.X, upv.X, back.X, right.Y, upv.Y, back.Y, right.Z, upv.Z, back.Z })
end
CFrame.identity = mk(Vector3.zero, I)

local C3 = {}
C3.__index = function(t, k)
	if k == "Lerp" then return function(a, b, al) return Color3.new(a.R + (b.R - a.R) * al, a.G + (b.G - a.G) * al, a.B + (b.B - a.B) * al) end end
	if k == "ToHSV" then return function(c) return 0, 0, math.max(c.R, c.G, c.B) end end
	error("Color3." .. tostring(k), 2)
end
Color3 = {
	new = function(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3) end,
}
Color3.fromRGB = function(r, g, b) return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
Color3.fromHSV = function(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return Color3.new(v, t, p) elseif i == 1 then return Color3.new(q, v, p) elseif i == 2 then return Color3.new(p, v, t)
	elseif i == 3 then return Color3.new(p, q, v) elseif i == 4 then return Color3.new(t, p, v) end
	return Color3.new(v, p, q)
end

-- Enums: any Enum.X.Y returns a tag table
local enumMeta = { __index = function(t, k) local v = { _enum = true, Name = k, EnumType = rawget(t, "_name") }; rawset(t, k, v); return v end }
Enum = setmetatable({}, { __index = function(t, k) local e = setmetatable({ _name = k }, enumMeta); rawset(t, k, e); return e end })

-- Random
Random = { new = function(seed)
	local state = (seed or 1) % 2147483647
	if state <= 0 then state += 2147483646 end
	local function nxt() state = (state * 16807) % 2147483647; return state / 2147483647 end
	return {
		NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + (b - a) * nxt() end,
		NextInteger = function(_, a, b) return a + math.floor(nxt() * (b - a + 1)) end,
	}
end }

function typeof(v)
	local mt = type(v) == "table" and getmetatable(v)
	if mt == V3 then return "Vector3" end
	if mt == CF then return "CFrame" end
	if mt == C3 then return "Color3" end
	if type(v) == "table" and v._class then return "Instance" end
	return type(v)
end

