-- ===== Instances with enough behaviour to run MapService.buildMap offline =====
local BASEPART = { Part = true, WedgePart = true, CornerWedgePart = true, SpawnLocation = true, MeshPart = true, TrussPart = true }
local InstMeta = {}
local methods = {}
InstMeta.__index = function(t, k)
	local m = methods[k]
	if m then return m end
	if k == "Position" then
		local cf = rawget(t, "CFrame")
		return cf and cf.Position
	end
	if k == "Orientation" or k == "Rotation" then return Vector3.zero end
	if k == "ClassName" then return rawget(t, "_class") end
	if k == "Parent" then return rawget(t, "_parent") end
	local kids = rawget(t, "_children")
	for _, c in ipairs(kids) do if rawget(c, "Name") == k then return c end end
	return nil
end
InstMeta.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_parent")
		if old then
			local kids = rawget(old, "_children")
			for i, c in ipairs(kids) do if c == t then table.remove(kids, i) break end end
		end
		rawset(t, "_parent", v)
		if v then table.insert(rawget(v, "_children"), t) end
		return
	end
	if k == "Position" then
		local cf = rawget(t, "CFrame") or CFrame.new()
		rawset(t, "CFrame", CFrame.new(v) * cf.Rotation)
		return
	end
	if k == "Shape" and BASEPART[rawget(t, "_class")] and v and v.Name == "Ball" then
		-- Roblox makes balls uniform
		local s = rawget(t, "Size")
		if s then
			local d = math.min(s.X, s.Y, s.Z)
			rawset(t, "Size", Vector3.new(d, d, d))
		end
	end
	rawset(t, k, v)
end
InstMeta.__tostring = function(t) return rawget(t, "Name") end

local function isBasePart(t) return BASEPART[rawget(t, "_class")] == true end

methods.IsA = function(self, cls)
	local c = rawget(self, "_class")
	if cls == c or cls == "Instance" then return true end
	if cls == "BasePart" or cls == "PVInstance" then return BASEPART[c] == true or (cls == "PVInstance" and c == "Model") end
	if cls == "Part" then return c == "Part" or c == "SpawnLocation" end
	if cls == "Light" then return c == "PointLight" or c == "SpotLight" or c == "SurfaceLight" end
	if cls == "GuiObject" then return c == "TextLabel" or c == "Frame" or c == "ImageLabel" or c == "TextButton" end
	if cls == "LuaSourceContainer" then return c == "Script" or c == "LocalScript" or c == "ModuleScript" end
	return false
end
methods.GetChildren = function(self) return table.clone(rawget(self, "_children")) end
methods.GetDescendants = function(self)
	local out = {}
	local function rec(n) for _, c in ipairs(rawget(n, "_children")) do table.insert(out, c); rec(c) end end
	rec(self)
	return out
end
methods.FindFirstChild = function(self, name, recursive)
	for _, c in ipairs(rawget(self, "_children")) do if rawget(c, "Name") == name then return c end end
	if recursive then for _, c in ipairs(rawget(self, "_children")) do local f = c:FindFirstChild(name, true); if f then return f end end end
	return nil
end
methods.WaitForChild = function(self, name) return methods.FindFirstChild(self, name) end
methods.FindFirstChildWhichIsA = function(self, cls, recursive)
	for _, c in ipairs(rawget(self, "_children")) do if c:IsA(cls) then return c end end
	if recursive then for _, c in ipairs(rawget(self, "_children")) do local f = c:FindFirstChildWhichIsA(cls, true); if f then return f end end end
	return nil
end
methods.FindFirstChildOfClass = function(self, cls) for _, c in ipairs(rawget(self, "_children")) do if rawget(c, "_class") == cls then return c end end return nil end
methods.FindFirstAncestorWhichIsA = function(self, cls)
	local p = rawget(self, "_parent")
	while p do if p:IsA(cls) then return p end p = rawget(p, "_parent") end
	return nil
end
methods.FindFirstAncestor = function(self, name)
	local p = rawget(self, "_parent")
	while p do if rawget(p, "Name") == name then return p end p = rawget(p, "_parent") end
	return nil
end
methods.IsDescendantOf = function(self, other)
	local p = rawget(self, "_parent")
	while p do if p == other then return true end p = rawget(p, "_parent") end
	return false
end
methods.Destroy = function(self) self.Parent = nil end
methods.ClearAllChildren = function(self) for _, c in ipairs(table.clone(rawget(self, "_children"))) do c.Parent = nil end end
methods.SetAttribute = function(self, k, v) rawget(self, "_attrs")[k] = v end
methods.GetAttribute = function(self, k) return rawget(self, "_attrs")[k] end
methods.GetAttributeChangedSignal = function() return { Connect = function() end } end
methods.Clone = function(self)
	local copy = setmetatable({ _children = {}, _attrs = table.clone(rawget(self, "_attrs")) }, InstMeta)
	for k, v in pairs(self) do
		if k ~= "_children" and k ~= "_attrs" and k ~= "_parent" then rawset(copy, k, v) end
	end
	for _, c in ipairs(rawget(self, "_children")) do c:Clone().Parent = copy end
	return copy
end

-- ── PVInstance / Model ──
local function parts(self)
	if isBasePart(self) then return { self } end
	local out = {}
	for _, d in ipairs(self:GetDescendants()) do if isBasePart(d) then table.insert(out, d) end end
	return out
end
local function bounds(self)
	local lo, hi
	for _, p in ipairs(parts(self)) do
		local h = p.Size / 2
		for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
			local w = p.CFrame * Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)
			if not lo then lo, hi = w, w else
				lo = Vector3.new(math.min(lo.X, w.X), math.min(lo.Y, w.Y), math.min(lo.Z, w.Z))
				hi = Vector3.new(math.max(hi.X, w.X), math.max(hi.Y, w.Y), math.max(hi.Z, w.Z))
			end
		end end end
	end
	if not lo then return CFrame.new(), Vector3.zero end
	return CFrame.new((lo + hi) / 2), hi - lo
end
methods.GetBoundingBox = function(self) return bounds(self) end
methods.GetExtentsSize = function(self) local _, s = bounds(self); return s end
methods.GetPivot = function(self)
	if isBasePart(self) then return self.CFrame end
	local wp = rawget(self, "WorldPivot")
	if wp then return wp end
	local pp = rawget(self, "PrimaryPart")
	if pp then return pp.CFrame end
	local cf = bounds(self)
	return cf
end
methods.PivotTo = function(self, cf)
	local delta = cf * methods.GetPivot(self):Inverse()
	for _, p in ipairs(parts(self)) do rawset(p, "CFrame", delta * p.CFrame) end
	if not isBasePart(self) then rawset(self, "WorldPivot", cf) end
end
methods.GetScale = function(self) return rawget(self, "_scale") or 1 end
methods.ScaleTo = function(self, s)
	local factor = s / (rawget(self, "_scale") or 1)
	local pivot = methods.GetPivot(self)
	local inv = pivot:Inverse()
	for _, p in ipairs(parts(self)) do
		local rel = inv * p.CFrame
		rawset(p, "CFrame", pivot * (CFrame.new(rel.Position * factor) * rel.Rotation))
		rawset(p, "Size", p.Size * factor)
	end
	for _, d in ipairs(self:GetDescendants()) do
		local c = rawget(d, "_class")
		if c == "PointLight" and rawget(d, "Range") then rawset(d, "Range", d.Range * factor) end
		if c == "Fire" and rawget(d, "Size") then rawset(d, "Size", d.Size * factor) end
	end
	rawset(self, "_scale", s)
end

Instance = { new = function(cls, parent)
	local t = setmetatable({ _class = cls, _children = {}, _attrs = {}, Name = cls }, InstMeta)
	if BASEPART[cls] then
		rawset(t, "Size", Vector3.new(4, 1, 2))
		rawset(t, "CFrame", CFrame.new())
		rawset(t, "Color", Color3.fromRGB(163, 162, 165))
		rawset(t, "Transparency", 0)
		rawset(t, "Reflectance", 0)
		rawset(t, "Material", Enum.Material.Plastic)
		rawset(t, "Anchored", true)
	end
	if parent then t.Parent = parent end
	return t
end }

-- value types we have to serialize later
UDim2 = {
	new = function(sx, ox, sy, oy) return { __t = "UDim2", v = { { sx or 0, ox or 0 }, { sy or 0, oy or 0 } } } end,
	fromScale = function(x, y) return { __t = "UDim2", v = { { x or 0, 0 }, { y or 0, 0 } } } end,
	fromOffset = function(x, y) return { __t = "UDim2", v = { { 0, x or 0 }, { 0, y or 0 } } } end,
}
UDim = { new = function(s, o) return { __t = "UDim", v = { s or 0, o or 0 } } end }
local V2 = {}
V2.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y) end
	return nil
end
V2.__sub = function(a, b) return Vector2.new(a.X - b.X, a.Y - b.Y) end
V2.__add = function(a, b) return Vector2.new(a.X + b.X, a.Y + b.Y) end
Vector2 = { new = function(x, y) return setmetatable({ __t = "Vector2", v = { x or 0, y or 0 }, X = x or 0, Y = y or 0 }, V2) end }
NumberRange = { new = function(a, b) return { __t = "NumberRange", v = { a, b or a } } end }
NumberSequenceKeypoint = { new = function(t, v, e) return { time = t, value = v, envelope = e or 0 } end }
ColorSequenceKeypoint = { new = function(t, c) return { time = t, color = c } end }
NumberSequence = { new = function(a, b)
	if type(a) == "table" and rawget(a, 1) ~= nil then return { __t = "NumberSequence", v = a } end
	return { __t = "NumberSequence", v = { NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b or a) } }
end }
ColorSequence = { new = function(a, b)
	if typeof(a) ~= "Color3" and type(a) == "table" then return { __t = "ColorSequence", v = a } end
	return { __t = "ColorSequence", v = { ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b or a) } }
end }
TweenInfo = { new = function() return {} end }

-- services
local services = {}
local function svc(name)
	if not services[name] then
		services[name] = Instance.new(name)
		rawset(services[name], "Name", name)
	end
	return services[name]
end
local cs = svc("CollectionService")
rawset(cs, "AddTag", function(_, inst, tag) local tags = rawget(inst, "_tags") or {}; table.insert(tags, tag); rawset(inst, "_tags", tags) end)
rawset(cs, "HasTag", function(_, inst, tag) for _, t in ipairs(rawget(inst, "_tags") or {}) do if t == tag then return true end end return false end)
rawset(cs, "GetTagged", function() return {} end)
rawset(cs, "RemoveTag", function() end)
local players = svc("Players")
rawset(players, "CreateHumanoidModelFromDescription", function() error("no characters offline") end)
rawset(players, "GetPlayers", function() return {} end)
workspace = Instance.new("Workspace")
rawset(workspace, "Name", "Workspace")
local terrain = Instance.new("Terrain")
rawset(terrain, "Name", "Terrain")
terrain.Parent = workspace
rawset(terrain, "FillBlock", function() end)
game = Instance.new("DataModel")
rawset(game, "GetService", function(_, name) if name == "Workspace" then return workspace end return svc(name) end)

MODULES = {}
LOADED = {}
function require(inst)
	local name = rawget(inst, "_module")
	assert(name, "require of non-module " .. tostring(inst))
	if LOADED[name] == nil then LOADED[name] = MODULES[name](inst) end
	return LOADED[name]
end
function mountModule(parent, name)
	local m = Instance.new("ModuleScript")
	rawset(m, "Name", name)
	rawset(m, "_module", name)
	m.Parent = parent
	return m
end
function folderUnder(parent, name)
	local f = Instance.new("Folder")
	rawset(f, "Name", name)
	f.Parent = parent
	return f
end
task = { wait = function() end, spawn = function(f, ...) f(...) end, delay = function() end, defer = function(f, ...) f(...) end }
function warn(...) print("WARN", ...) end
