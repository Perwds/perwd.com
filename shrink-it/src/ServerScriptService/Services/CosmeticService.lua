--[[
	📍 LOCATION: ServerScriptService > Services > CosmeticService (ModuleScript)

	Trails (bought at the TRAILS stand): buy with Coins or Robux (Developer Product), or unlock with
	a gamepass (Rainbow = Rainbow Ray pass). Every trail makes you run faster (Trail.Speed multiplier).
	The equipped trail is attached to your character on every spawn.
	Config: MonetizationConfig.Trails / TrailOrder.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local NameplateConfig = require(Shared.Config.NameplateConfig)
local TreadmillConfig = require(Shared.Config.TreadmillConfig)
local Nameplate = require(Shared.Nameplate)
local Format = require(Shared.Format)

local CosmeticService = {}
local Svc

function CosmeticService.Init(registry)
	Svc = registry
end

local function owns(player, data, key)
	local cfg = MonetizationConfig.Trails[key]
	if not cfg then
		return false
	end
	if cfg.Pass then
		return Svc.Session.HasPass(player, cfg.Pass)
	end
	return data.Trails[key] == true
end

local function stripes(a, b, count)
	local kps = {}
	for i = 0, count do
		local t = i / count
		local c = (i % 2 == 0) and a or b
		table.insert(kps, ColorSequenceKeypoint.new(t, c))
		if i < count then
			table.insert(kps, ColorSequenceKeypoint.new(math.min(1, t + 1 / count - 0.001), c))
		end
	end
	return ColorSequence.new(kps)
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 220, 90)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 140, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 80, 255)),
})

function CosmeticService.ApplyTrail(player)
	local data = Svc.Data.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not data or not root then
		return
	end
	for _, name in ipairs({ "ShrinkTrail", "TrailTop", "TrailBottom" }) do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local key = data.EquippedTrail
	local cfg = key ~= "" and MonetizationConfig.Trails[key]
	if not cfg or not owns(player, data, key) then
		return
	end
	local top = Instance.new("Attachment")
	top.Name = "TrailTop"
	top.Position = Vector3.new(0, 0.9, 0.4)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Name = "TrailBottom"
	bottom.Position = Vector3.new(0, -1.4, 0.4)
	bottom.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "ShrinkTrail"
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.7
	trail.MinLength = 0.1
	trail.LightEmission = 0.8
	trail.FaceCamera = true
	if cfg.Rainbow then
		trail.Color = RAINBOW
	elseif cfg.Pattern == "Zebra" then
		trail.Color = stripes(cfg.Colors[1], cfg.Colors[2], 9)
		trail.LightEmission = 0
	elseif cfg.Pattern == "Galaxy" then
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, cfg.Colors[1]),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 60, 255)),
			ColorSequenceKeypoint.new(1, cfg.Colors[2]),
		})
		local stars = Instance.new("ParticleEmitter")
		stars.Name = "TrailStars"
		stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		stars.Rate = 12
		stars.Lifetime = NumberRange.new(0.5, 0.9)
		stars.Speed = NumberRange.new(0.5, 1.5)
		stars.Size = NumberSequence.new(0.35, 0)
		stars.LightEmission = 1
		stars.Parent = bottom
	else
		trail.Color = ColorSequence.new(cfg.Colors[1], cfg.Colors[2])
	end
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Parent = root
end

-- ── Name Plates (NameplateConfig) ─────────────────────────────────────
local function ownsPlate(player, data, key)
	local cfg = NameplateConfig.Plates[key]
	if not cfg or not data then
		return false
	end
	if cfg.Free then
		return true
	end
	if cfg.Req then
		return (data[cfg.Req.Stat] or 0) >= cfg.Req.Amount
	end
	return data.Nameplates and data.Nameplates[key] == true
end
CosmeticService.OwnsPlate = ownsPlate

-- the plate over your head (a BillboardGui in the Head, sized in studs so it shrinks with distance)
function CosmeticService.ApplyPlate(player)
	local data = Svc.Data.Get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not data or not head then
		return
	end
	local old = head:FindFirstChild("NameplateGui")
	if old then
		old:Destroy()
	end
	local key = data.EquippedPlate
	if not ownsPlate(player, data, key) then
		key = NameplateConfig.Default
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "NameplateGui"
	gui.Size = UDim2.fromScale(6, 1.15)
	gui.StudsOffset = Vector3.new(0, 2.3, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.ResetOnSpawn = false
	gui.Adornee = head
	local pc = data.PlateColor or {}
	Nameplate.Build(key, { Parent = gui, Text = player.DisplayName, Color = Color3.fromRGB(pc[1] or 255, pc[2] or 120, pc[3] or 40) })
	gui.Parent = head
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
end

function CosmeticService.GrantPlate(player, key)
	local data = Svc.Data.Get(player)
	local cfg = NameplateConfig.Plates[key]
	if not data or not cfg then
		return
	end
	data.Nameplates[key] = true
	data.EquippedPlate = key
	CosmeticService.ApplyPlate(player)
	Svc.Data.MarkDirty(player)
	Svc.Net.Notify(player, cfg.Name .. " Name Plate unlocked!", "success")
end

function CosmeticService.OnPlayerLoaded(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		CosmeticService.ApplyTrail(player)
		character:WaitForChild("Head", 10)
		CosmeticService.ApplyPlate(player)
	end)
	if player.Character then
		CosmeticService.ApplyTrail(player)
		CosmeticService.ApplyPlate(player)
	end
end

-- Unlocks + equips a trail (coins purchase, Robux product, or admin grant).
function CosmeticService.GrantTrail(player, key)
	local data = Svc.Data.Get(player)
	local cfg = MonetizationConfig.Trails[key]
	if not data or not cfg then
		return
	end
	data.Trails[key] = true
	data.EquippedTrail = key
	CosmeticService.Refresh(player)
	Svc.Data.MarkDirty(player)
	Svc.Net.Notify(player, "🌈 " .. cfg.Name .. " unlocked! x" .. cfg.Speed .. " Speed", "success")
end

function CosmeticService.Refresh(player)
	CosmeticService.ApplyTrail(player)
	Svc.Monetization.ApplyMovement(player) -- trails change walk speed
end

function CosmeticService.Start()
	Svc.Net.Handle("BuyTrail", function(player, key)
		local data = Svc.Data.Get(player)
		local cfg = type(key) == "string" and MonetizationConfig.Trails[key]
		if not cfg then
			return { ok = false }
		end
		if owns(player, data, key) then
			return { ok = false, msg = "You already own this trail!" }
		end
		if cfg.Pass then
			return { ok = false, msg = "Unlocked by the " .. MonetizationConfig.GamePasses[cfg.Pass].Name .. " gamepass (Shop)!" }
		end
		if not Svc.Economy.Spend(player, "Coins", cfg.Cost) then
			return { ok = false, msg = "Need " .. Format.Coins(cfg.Cost) }
		end
		CosmeticService.GrantTrail(player, key)
		return { ok = true }
	end)

	Svc.Net.Handle("BuyTrailRobux", function(player, key)
		local data = Svc.Data.Get(player)
		local cfg = type(key) == "string" and MonetizationConfig.Trails[key]
		if not cfg or not cfg.Product then
			return { ok = false }
		end
		if owns(player, data, key) then
			return { ok = false, msg = "You already own this trail!" }
		end
		return Svc.Monetization.PromptProduct(player, cfg.Product)
	end)

	Svc.Net.Handle("BuyPlate", function(player, key)
		local data = Svc.Data.Get(player)
		local cfg = type(key) == "string" and NameplateConfig.Plates[key]
		if not data or not cfg then
			return { ok = false }
		end
		if ownsPlate(player, data, key) then
			return { ok = false, msg = "You already own this plate!" }
		end
		if cfg.Product then
			return Svc.Monetization.PromptProduct(player, cfg.Product)
		end
		if cfg.Req then
			return { ok = false, msg = cfg.Req.Label .. " to unlock it!" }
		end
		if not cfg.Cost or not Svc.Economy.Spend(player, cfg.Currency or "Coins", cfg.Cost) then
			local need = cfg.Currency == "Gems" and (tostring(cfg.Cost) .. " Gems") or Format.Coins(cfg.Cost or 0)
			return { ok = false, msg = "Need " .. need }
		end
		CosmeticService.GrantPlate(player, key)
		return { ok = true }
	end)

	-- treadmill skins (Gems), shown on your plot by SpeedService
	Svc.Net.Handle("BuyTreadmillSkin", function(player, key)
		local data = Svc.Data.Get(player)
		local cfg = type(key) == "string" and TreadmillConfig.Skins[key]
		if not data or not cfg then
			return { ok = false }
		end
		if data.TreadmillSkins[key] then
			return { ok = false, msg = "You already own this treadmill!" }
		end
		if not Svc.Economy.Spend(player, "Gems", cfg.Cost) then
			return { ok = false, msg = "Need " .. cfg.Cost .. " Gems" }
		end
		data.TreadmillSkins[key] = true
		data.EquippedTreadmill = key
		Svc.Data.MarkDirty(player)
		return { ok = true, msg = cfg.Name .. " treadmill unlocked!" }
	end)
	Svc.Net.Handle("EquipTreadmillSkin", function(player, key)
		local data = Svc.Data.Get(player)
		if not data then
			return { ok = false }
		end
		if key == "" or key == nil then
			data.EquippedTreadmill = ""
		elseif type(key) == "string" and TreadmillConfig.Skins[key] and data.TreadmillSkins[key] then
			data.EquippedTreadmill = key
		else
			return { ok = false, msg = "You don't own that treadmill!" }
		end
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)

	-- Custom Color plate: any RGB color
	Svc.Net.Handle("SetPlateColor", function(player, r, g, b)
		local data = Svc.Data.Get(player)
		if not data or not ownsPlate(player, data, "Custom") then
			return { ok = false, msg = "Get the Custom Color plate first!" }
		end
		if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" or r ~= r or g ~= g or b ~= b then
			return { ok = false }
		end
		data.PlateColor = { math.clamp(math.floor(r), 0, 255), math.clamp(math.floor(g), 0, 255), math.clamp(math.floor(b), 0, 255) }
		data.EquippedPlate = "Custom"
		CosmeticService.ApplyPlate(player)
		Svc.Data.MarkDirty(player)
		return { ok = true, msg = "Color saved!" }
	end)

	Svc.Net.Handle("EquipPlate", function(player, key)
		local data = Svc.Data.Get(player)
		if not data or type(key) ~= "string" or not ownsPlate(player, data, key) then
			return { ok = false, msg = "You don't own that plate!" }
		end
		data.EquippedPlate = key
		CosmeticService.ApplyPlate(player)
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)

	-- ⚙️ Settings menu (volumes 0..1, toggles true/false)
	local SETTINGS = { Sfx = "number", Ambient = "number", Music = "number", ShowTrails = "boolean", LowGraphics = "boolean" }
	Svc.Net.Handle("SetSetting", function(player, key, value)
		local data = Svc.Data.Get(player)
		local kind = type(key) == "string" and SETTINGS[key]
		if not data or not kind or type(value) ~= kind then
			return { ok = false }
		end
		if kind == "number" then
			value = math.clamp(value, 0, 1)
		end
		data.Settings[key] = value
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)

	Svc.Net.Handle("EquipTrail", function(player, key)
		local data = Svc.Data.Get(player)
		if key == "" or key == nil then
			data.EquippedTrail = ""
		elseif type(key) == "string" and owns(player, data, key) then
			data.EquippedTrail = key
		else
			return { ok = false, msg = "You don't own that trail!" }
		end
		CosmeticService.Refresh(player)
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)
end

return CosmeticService
