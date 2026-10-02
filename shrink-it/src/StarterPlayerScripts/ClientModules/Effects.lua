--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Effects (ModuleScript)

	Purely visual, client-side effects:
	  • shrink tween → fly into the shooter's pocket → "pop" sound + particle burst
	  • other players' charging beams
	  • floating "+$" income text above museum pedestals
	  • rainbow color cycling for Rainbow variants / Rainbow Ray
	  • local gate & VIP-door passability (server still enforces positions)
	  • raid visuals (museum building shrinks during a raid)
	  • VIP chat tag
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)

local Modules = script.Parent
local State = require(Modules.State)
local HUD = require(Modules.HUD)

local Effects = {}

local player = Players.LocalPlayer

-- ── helpers ───────────────────────────────────────────────────────────
local function rainbow(offset)
	return Color3.fromHSV(((os.clock() * 0.35) + (offset or 0)) % 1, 0.8, 1)
end
Effects.Rainbow = rainbow

local function playSoundAt(position, soundId, volume)
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = volume or 0.6
	s.RollOffMaxDistance = 250
	s.PlaybackSpeed = 0.9 + math.random() * 0.3
	s.Parent = att
	s:Play()
	task.delay(3, function()
		att:Destroy()
	end)
end

local function burst(position, color, amount, size)
	local att = Instance.new("Attachment")
	att.WorldPosition = position
	att.Parent = workspace.Terrain
	local p = Instance.new("ParticleEmitter")
	p.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	p.Color = ColorSequence.new(color or Color3.new(1, 1, 1))
	p.LightEmission = 1
	p.Rate = 0
	p.Speed = NumberRange.new(8, 20)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Lifetime = NumberRange.new(0.4, 0.9)
	p.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 1.2), NumberSequenceKeypoint.new(1, 0) })
	p.Drag = 4
	p.Parent = att
	p:Emit(amount or 30)
	task.delay(2, function()
		att:Destroy()
	end)
end
Effects.Burst = burst

local function skinColors(skinName)
	local skin = MonetizationConfig.RaySkins[skinName or "Default"] or MonetizationConfig.RaySkins.Default
	return skin.Colors[1], skin.Colors[2], skin.Rainbow == true
end

-- Beam from an attachment to a world point. Returns { SetTarget(pos), SetWidth(w), Destroy() }
local activeRainbowBeams = {}
function Effects.CreateBeam(fromAttachment, skinName)
	local target = Instance.new("Attachment")
	target.Parent = workspace.Terrain
	local beam = Instance.new("Beam")
	beam.Attachment0 = fromAttachment
	beam.Attachment1 = target
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 12
	beam.Width0 = 0.25
	beam.Width1 = 0.6
	beam.Transparency = NumberSequence.new(0.1)
	beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = 3
	beam.TextureSpeed = 3
	local c1, c2, isRainbow = skinColors(skinName)
	beam.Color = ColorSequence.new(c1, c2)
	beam.Parent = workspace.Terrain
	if isRainbow then
		activeRainbowBeams[beam] = true
	end
	return {
		SetTarget = function(pos)
			target.WorldPosition = pos
		end,
		SetWidth = function(w)
			beam.Width0 = w * 0.4
			beam.Width1 = w
		end,
		Destroy = function()
			activeRainbowBeams[beam] = nil
			beam:Destroy()
			target:Destroy()
		end,
	}
end

-- ── shrink animation ─────────────────────────────────────────────────
local function playShrink(model, shooter, variantName, isCopy)
	if not model or not model.Parent or not model:IsA("Model") then
		return
	end
	local subject = model
	if isCopy then
		subject = model:Clone()
		subject.Parent = workspace
	end
	local variant = RarityConfig.GetVariant(variantName)
	local color = variant.Color or Color3.fromRGB(120, 230, 255)
	local label = subject:FindFirstChild("NameLabel")
	if label then
		label.Enabled = false
	end
	local ok, startScale = pcall(function()
		return subject:GetScale()
	end)
	if not ok then
		return
	end
	local startPivot = subject:GetPivot()
	local value = Instance.new("NumberValue")
	value.Value = 0
	local function targetPos()
		local root = shooter and shooter.Character and shooter.Character:FindFirstChild("HumanoidRootPart")
		return root and root.Position or startPivot.Position
	end
	-- phase 1 (0 → 0.5): squash down to 15%   |   phase 2 (0.5 → 1): fly into the pocket
	local conn = value.Changed:Connect(function(t)
		if not subject.Parent then
			return
		end
		local s
		if t < 0.5 then
			local a = t / 0.5
			s = 1 - 0.85 * (1 - (1 - a) ^ 3) + math.sin(a * math.pi) * 0.08
		else
			s = 0.15 * (1 - (t - 0.5) / 0.5) + 0.01
		end
		pcall(function()
			subject:ScaleTo(math.max(0.001, startScale * s))
		end)
		local fly = t < 0.5 and 0 or ((t - 0.5) / 0.5) ^ 2
		local pos = startPivot.Position:Lerp(targetPos(), fly) + Vector3.new(0, math.sin(fly * math.pi) * 6, 0)
		subject:PivotTo(CFrame.new(pos) * (startPivot - startPivot.Position) * CFrame.Angles(0, t * 6, 0))
	end)
	local duration = GameConfig.ShrinkFxTime * 0.85
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Value = 1 })
	burst(startPivot.Position, color, 25, 1.5)
	tween:Play()
	tween.Completed:Connect(function()
		conn:Disconnect()
		value:Destroy()
		local pos = targetPos()
		playSoundAt(pos, GameConfig.Sounds.Pop, 0.8)
		burst(pos, color, 40, 1)
		if isCopy or shooter == player then
			subject:Destroy() -- server removes the real one; hide locally right away
		else
			for _, d in ipairs(subject:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 1
				end
			end
		end
	end)
end

-- ── other players' charging beams ────────────────────────────────────
local otherBeams = {} -- [player] = { Beam, Target }
local function onChargeFX(shooter, target, on)
	if shooter == player then
		return
	end
	local old = otherBeams[shooter]
	if old then
		old.Beam.Destroy()
		otherBeams[shooter] = nil
	end
	if not on or not target then
		return
	end
	local character = shooter.Character
	local tool = character and character:FindFirstChildWhichIsA("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local tip = handle and (handle:FindFirstChild("Tip") or handle:FindFirstChildWhichIsA("Attachment"))
	if not tip then
		return
	end
	local beam = Effects.CreateBeam(tip, shooter:GetAttribute("RaySkin"))
	beam.SetWidth(0.6)
	otherBeams[shooter] = { Beam = beam, Target = target }
end

-- ── income floaters ──────────────────────────────────────────────────
local function floater(pedestal, amount)
	local base = pedestal.PrimaryPart
	if not base then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 36)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	gui.Adornee = base
	gui.LightInfluence = 0
	gui.MaxDistance = 110
	gui.Parent = base
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(140, 255, 120)
	label.Text = "+" .. Format.Coins(amount)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Parent = label
	TweenService:Create(gui, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { StudsOffsetWorldSpace = Vector3.new(0, 11, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	task.delay(1.7, function()
		gui:Destroy()
	end)
end

local FLOAT_INTERVAL = 3
local function floaterLoop()
	while true do
		task.wait(FLOAT_INTERVAL)
		local camera = workspace.CurrentCamera
		if camera then
			local shown = 0
			for _, pedestal in ipairs(CollectionService:GetTagged("MuseumPedestal")) do
				local income = pedestal:GetAttribute("Income") or 0
				local base = pedestal.PrimaryPart
				if income > 0 and base and (base.Position - camera.CFrame.Position).Magnitude < 100 then
					task.delay(math.random() * 1.2, floater, pedestal, income * FLOAT_INTERVAL)
					shown += 1
					if shown >= 30 then
						break
					end
				end
			end
		end
	end
end

-- ── gates & VIP door (local passability) ────────────────────────────
local function refreshGates()
	local data = State.Data
	if not data then
		return
	end
	for _, gate in ipairs(CollectionService:GetTagged("AreaGate")) do
		local tier = gate:GetAttribute("Tier") or 1
		local open = Formulas.IsTierUnlocked(data, tier)
		gate.CanCollide = not open
		gate.LocalTransparencyModifier = open and 0.75 or 0
	end
	local vip = State.HasPass("VIP")
	for _, door in ipairs(CollectionService:GetTagged("VIPDoor")) do
		door.CanCollide = not vip
	end
end

-- ── raid visuals ─────────────────────────────────────────────────────
local raidedBuildings = {}
local function onRaidSync(p)
	local plots = workspace:FindFirstChild("ShrinkItMap") and workspace.ShrinkItMap:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild("Plot_" .. tostring(p.PlotId))
	local building = plot and plot:FindFirstChild("MuseumBuilding")
	if p.Type == "Start" and building then
		raidedBuildings[building] = building:GetScale()
		local value = Instance.new("NumberValue")
		value.Value = 1
		value.Changed:Connect(function(v)
			pcall(function()
				local pivot = building:GetPivot()
				building:ScaleTo(raidedBuildings[building] * v)
				building:PivotTo(pivot)
			end)
		end)
		local t = TweenService:Create(value, TweenInfo.new(1.2, Enum.EasingStyle.Back), { Value = 0.45 })
		t:Play()
		t.Completed:Connect(function()
			value:Destroy()
		end)
		burst(building:GetPivot().Position, Color3.fromRGB(255, 80, 80), 60, 3)
		playSoundAt(building:GetPivot().Position, GameConfig.Sounds.Pop, 1)
	elseif p.Type == "End" and building and raidedBuildings[building] then
		local original = raidedBuildings[building]
		raidedBuildings[building] = nil
		pcall(function()
			local pivot = building:GetPivot()
			building:ScaleTo(original)
			building:PivotTo(pivot)
		end)
		burst(building:GetPivot().Position, Color3.fromRGB(120, 255, 160), 40, 3)
	end
end

-- ── carry results (caught by a chaser / delivered at base) ─────────────
local function shakeCamera(seconds, strength)
	local camera = workspace.CurrentCamera
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t > seconds then
			conn:Disconnect()
			return
		end
		local a = strength * (1 - t / seconds)
		camera.CFrame *= CFrame.Angles(math.rad((math.random() - 0.5) * a), math.rad((math.random() - 0.5) * a), 0)
	end)
end

local function onCarryFX(kind, p)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if kind == "Caught" then
		HUD.Splash(p.Emoji .. " CAUGHT!", Color3.fromRGB(255, 70, 70))
		shakeCamera(0.6, 6)
		playSoundAt(root and root.Position or Vector3.zero, GameConfig.Sounds.TooBig, 0.8)
		if root then
			-- knocked back toward the base (client owns its own character physics)
			root.AssemblyLinearVelocity = Vector3.new(0, 45, -55)
		end
	elseif kind == "Deposit" then
		HUD.Splash("DELIVERED! +" .. Format.Coins(p.Income) .. "/s", Color3.fromRGB(120, 255, 120))
		if root then
			burst(root.Position, Color3.fromRGB(255, 220, 60), 60, 1.6)
			burst(root.Position, Color3.fromRGB(120, 255, 140), 40, 1.2)
			playSoundAt(root.Position, GameConfig.Sounds.Reward, 0.7)
		end
	end
end

-- ── guide arrows: red chevrons on the ground pointing to YOUR plot while carrying ──
local ARROW_COUNT, ARROW_STEP = 12, 7
local arrowParts = {}
local function guideArrows()
	local folder = Instance.new("Folder")
	folder.Name = "GuideArrows"
	folder.Parent = workspace.CurrentCamera
	for i = 1, ARROW_COUNT do
		arrowParts[i] = {}
		for s = 1, 2 do
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = Color3.fromRGB(255, 50, 50)
			p.Size = Vector3.new(0.7, 0.35, 3)
			p.Transparency = 1
			p.Parent = folder
			arrowParts[i][s] = p
		end
	end
	while true do
		task.wait(0.05)
		local data = State.Data
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local carrying = data and data.Carry and data.Carry.Count > 0
		local target
		if carrying and root and data.PlotId then
			local map = workspace:FindFirstChild("ShrinkItMap")
			local plot = map and map:FindFirstChild("Plots") and map.Plots:FindFirstChild("Plot_" .. data.PlotId)
			local pad = plot and (plot:FindFirstChild("Floor") or plot:FindFirstChild("SpawnPad"))
			target = pad and pad.Position
		end
		local show = 0
		if target then
			local from = Vector3.new(root.Position.X, 0, root.Position.Z)
			local to = Vector3.new(target.X, 0, target.Z)
			local total = (to - from).Magnitude
			if total > 8 then
				local dir = (to - from).Unit
				local groundY = root.Position.Y - 2.7
				local pulse = (os.clock() * 2) % 1
				for i = 1, ARROW_COUNT do
					local dist = 4 + (i - 1 + pulse) * ARROW_STEP
					if dist < total - 2 then
						show = i
						local tip = from + dir * dist
						local base = CFrame.lookAt(Vector3.new(tip.X, groundY, tip.Z), Vector3.new(tip.X, groundY, tip.Z) + dir)
						for s, sign in ipairs({ -1, 1 }) do
							local part = arrowParts[i][s]
							part.CFrame = base * CFrame.Angles(0, sign * math.rad(38), 0) * CFrame.new(0, 0, 1.3)
							part.Transparency = 0.15 + (i / ARROW_COUNT) * 0.5
						end
					end
				end
			end
		end
		for i = show + 1, ARROW_COUNT do
			for s = 1, 2 do
				arrowParts[i][s].Transparency = 1
			end
		end
	end
end

function Effects.Init()
	task.spawn(guideArrows)
	Remotes.Event("CarryFX").OnClientEvent:Connect(onCarryFX)
	Remotes.Event("ShrinkFX").OnClientEvent:Connect(playShrink)
	Remotes.Event("ChargeFX").OnClientEvent:Connect(onChargeFX)
	Remotes.Event("RaidSync").OnClientEvent:Connect(onRaidSync)

	State.Observe(refreshGates)
	CollectionService:GetInstanceAddedSignal("AreaGate"):Connect(refreshGates)
	CollectionService:GetInstanceAddedSignal("VIPDoor"):Connect(refreshGates)

	task.spawn(floaterLoop)

	-- per-frame: rainbow cycling + other players' beams
	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		for shooter, info in pairs(otherBeams) do
			if info.Target and info.Target.Parent then
				info.Beam.SetTarget(info.Target:GetPivot().Position)
			else
				info.Beam.Destroy()
				otherBeams[shooter] = nil
			end
		end
		acc += dt
		if acc < 1 / 20 then
			return
		end
		acc = 0
		local c = rainbow()
		for _, inst in ipairs(CollectionService:GetTagged("RainbowFX")) do
			if inst:IsA("Highlight") then
				inst.FillColor = c
				inst.OutlineColor = c
			elseif inst:IsA("PointLight") then
				inst.Color = c
			elseif inst:IsA("ParticleEmitter") then
				inst.Color = ColorSequence.new(c, rainbow(0.3))
			end
		end
		for beam in pairs(activeRainbowBeams) do
			beam.Color = ColorSequence.new(c, rainbow(0.5))
		end
	end)

	-- VIP chat tag (TextChatService)
	TextChatService.OnIncomingMessage = function(message)
		local props = Instance.new("TextChatMessageProperties")
		local source = message.TextSource
		local speaker = source and Players:GetPlayerByUserId(source.UserId)
		if speaker and speaker:GetAttribute("VIP") then
			props.PrefixText = "<font color='#FFD23F'>[👑 VIP]</font> " .. message.PrefixText
		end
		return props
	end
end

return Effects
