-- ===== serialize an instance tree to a Rojo .model.json =====
local SKIP = { Name = true, Parent = true, WorldPivot = true, PrimaryPart = true, Adornee = true, Attachment0 = true, Attachment1 = true, CurrentCamera = true, Position = true }
local function num(x)
	if x ~= x or x == math.huge or x == -math.huge then return "0" end
	local s = string.format("%.5f", x)
	s = s:gsub("0+$", ""):gsub("%.$", "")
	if s == "-0" then s = "0" end
	return s
end
local function str(s)
	return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
end
local function vec(v) return "[" .. num(v.X) .. "," .. num(v.Y) .. "," .. num(v.Z) .. "]" end
local function col(c) return "[" .. num(c.R) .. "," .. num(c.G) .. "," .. num(c.B) .. "]" end

local function value(v)
	local t = typeof(v)
	if t == "number" then return num(v) end
	if t == "boolean" then return tostring(v) end
	if t == "string" then return str(v) end
	if t == "Vector3" then return vec(v) end
	if t == "Color3" then return col(v) end
	if t == "CFrame" then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = v:GetComponents()
		return '{"CFrame":{"position":[' .. num(x) .. "," .. num(y) .. "," .. num(z) .. '],"orientation":[[' .. num(r00) .. "," .. num(r01) .. "," .. num(r02) .. "],[" .. num(r10) .. "," .. num(r11) .. "," .. num(r12) .. "],[" .. num(r20) .. "," .. num(r21) .. "," .. num(r22) .. "]]}}"
	end
	if type(v) == "table" and v._enum then return str(v.Name) end
	if type(v) == "table" and v.__t then
		local k = v.__t
		if k == "UDim2" then return '{"UDim2":[[' .. num(v.v[1][1]) .. "," .. num(v.v[1][2]) .. "],[" .. num(v.v[2][1]) .. "," .. num(v.v[2][2]) .. "]]}" end
		if k == "UDim" then return '{"UDim":[' .. num(v.v[1]) .. "," .. num(v.v[2]) .. "]}" end
		if k == "Vector2" then return '{"Vector2":[' .. num(v.v[1]) .. "," .. num(v.v[2]) .. "]}" end
		if k == "NumberRange" then return '{"NumberRange":[' .. num(v.v[1]) .. "," .. num(v.v[2]) .. "]}" end
		if k == "NumberSequence" then
			local kps = {}
			for _, kp in ipairs(v.v) do table.insert(kps, '{"time":' .. num(kp.time) .. ',"value":' .. num(kp.value) .. ',"envelope":' .. num(kp.envelope or 0) .. "}") end
			return '{"NumberSequence":{"keypoints":[' .. table.concat(kps, ",") .. "]}}"
		end
		if k == "ColorSequence" then
			local kps = {}
			for _, kp in ipairs(v.v) do table.insert(kps, '{"time":' .. num(kp.time) .. ',"color":' .. col(kp.color) .. "}") end
			return '{"ColorSequence":{"keypoints":[' .. table.concat(kps, ",") .. "]}}"
		end
	end
	return nil
end

local function attrValue(v)
	local t = typeof(v)
	if t == "number" then return '{"Float64":' .. num(v) .. "}" end
	if t == "string" then return '{"String":' .. str(v) .. "}" end
	if t == "boolean" then return '{"Bool":' .. tostring(v) .. "}" end
	if t == "Color3" then return '{"Color3":' .. col(v) .. "}" end
	if t == "Vector3" then return '{"Vector3":' .. vec(v) .. "}" end
	return nil
end

SKIPPED = {}
function serialize(inst)
	local props = {}
	local keys = {}
	for k in pairs(inst) do
		if type(k) == "string" and k:sub(1, 1) ~= "_" and not SKIP[k] then table.insert(keys, k) end
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local v = rawget(inst, k)
		if type(v) ~= "function" then
			local s = value(v)
			if s then
				table.insert(props, str(k) .. ":" .. s)
			else
				SKIPPED[rawget(inst, "_class") .. "." .. k] = true
			end
		end
	end
	local attrs = {}
	for k, v in pairs(rawget(inst, "_attrs")) do
		local s = attrValue(v)
		if s then table.insert(attrs, str(k) .. ":" .. s) end
	end
	if #attrs > 0 then
		table.sort(attrs)
		table.insert(props, '"Attributes":{"Attributes":{' .. table.concat(attrs, ",") .. "}}")
	end
	local tags = rawget(inst, "_tags")
	if tags and #tags > 0 then
		local t = {}
		for _, tag in ipairs(tags) do table.insert(t, str(tag)) end
		table.insert(props, '"Tags":[' .. table.concat(t, ",") .. "]")
	end
	local kids = {}
	for _, c in ipairs(rawget(inst, "_children")) do table.insert(kids, serialize(c)) end
	local out = '{"Name":' .. str(rawget(inst, "Name")) .. ',"ClassName":' .. str(rawget(inst, "_class"))
	if #props > 0 then out ..= ',"Properties":{' .. table.concat(props, ",") .. "}" end
	if #kids > 0 then out ..= ',"Children":[' .. table.concat(kids, ",") .. "]" end
	return out .. "}"
end
