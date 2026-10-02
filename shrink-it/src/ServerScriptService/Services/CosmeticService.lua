--[[
	📍 LOCATION: ServerScriptService > Services > CosmeticService (ModuleScript)

	Trails (bought at the TRAILS stand): buy with Coins / Gems, or unlock with a gamepass
	(Rainbow = Rainbow Ray pass). The equipped trail is attached to your character on every spawn.
	Config: MonetizationConfig.Trails / TrailOrder.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
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
	trail.Color = cfg.Rainbow and RAINBOW or ColorSequence.new(cfg.Colors[1], cfg.Colors[2])
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
	trail.Parent = root
end

function CosmeticService.OnPlayerLoaded(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		CosmeticService.ApplyTrail(player)
	end)
	if player.Character then
		CosmeticService.ApplyTrail(player)
	end
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
		if not Svc.Economy.Spend(player, cfg.Currency, cfg.Cost) then
			local label = cfg.Currency == "Coins" and Format.Coins(cfg.Cost) or (Format.Abbrev(cfg.Cost) .. " Gems")
			return { ok = false, msg = "Need " .. label }
		end
		data.Trails[key] = true
		data.EquippedTrail = key
		CosmeticService.ApplyTrail(player)
		Svc.Data.MarkDirty(player)
		return { ok = true, msg = "🌈 " .. cfg.Name .. " trail unlocked & equipped!" }
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
		CosmeticService.ApplyTrail(player)
		Svc.Data.MarkDirty(player)
		return { ok = true }
	end)
end

return CosmeticService
