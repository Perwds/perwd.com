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
	  • hides mystery boxes YOU already took (others can still see & take them)
	  • hover info on anyone's pedestal objects (income + weight + owner)
	  • PvP hit / steal / trap effects, chaser alarms, Global chat lines from other servers
	  • settings: low graphics, hide other players' trails, anti-AFK while training on the treadmill
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local Nameplate = require(Shared.Nameplate)

local Modules = script.Parent
local State = require(Modules.State)
local HUD = require(Modules.HUD)
local Audio = require(Modules.Audio)

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
	s.SoundGroup = game:GetService("SoundService"):FindFirstChild("SFX")
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
	model:SetAttribute("LocalShrinking", true)
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
		shakeCamera(0.6, 6)
		playSoundAt(root and root.Position or Vector3.zero, GameConfig.Sounds.TooBig, 0.8)
		if root then
			-- knocked back toward the base (client owns its own character physics)
			root.AssemblyLinearVelocity = Vector3.new(0, 45, -55)
		end
	elseif kind == "Placed" then
		if root then
			playSoundAt(root.Position, GameConfig.Sounds.Pop, 0.5)
		end
	elseif kind == "Deposit" then
		if root then
			burst(root.Position, Color3.fromRGB(255, 220, 60), 60, 1.6)
			burst(root.Position, Color3.fromRGB(120, 255, 140), 40, 1.2)
			playSoundAt(root.Position, GameConfig.Sounds.Reward, 0.7)
		end
	end
end

-- ── boxes on pedestals: countdown timers, unbox FX, owner-only prompts ──
local function onBoxOpened(pedestal, owner, itemName, variantName, income)
	local base = pedestal and pedestal.PrimaryPart
	local variant = RarityConfig.GetVariant(variantName)
	if base then
		local pos = base.Position + Vector3.new(0, 4, 0)
		burst(pos, variant.Color or Color3.fromRGB(255, 220, 80), 70, 1.6)
		burst(pos, Color3.fromRGB(255, 255, 255), 30, 1)
		playSoundAt(pos, GameConfig.Sounds.Pop, 0.9)
	end
	if owner == player then
		HUD.Splash(itemName .. "  +" .. Format.Coins(income) .. "/s", variant.Color or Color3.fromRGB(120, 255, 140))
		playSoundAt(base and base.Position or Vector3.zero, GameConfig.Sounds.Reward, 0.6)
	end
end

local function pedestalLoop()
	while true do
		task.wait(0.25)
		local now = State.Now()
		for _, pedestal in ipairs(CollectionService:GetTagged("MuseumPedestal")) do
			local base = pedestal.PrimaryPart
			if base then
				-- only the owner sees (and can use) the Place / Open now / Pick up prompt
				local mine = pedestal:GetAttribute("OwnerUserId") == player.UserId
				local empty = pedestal:GetAttribute("State") == "Empty"
				local prompt = base:FindFirstChild("PedestalPrompt")
				if prompt then
					prompt.Enabled = mine and not empty -- empty spots: use F / the Place button instead
				end
				local robuxPrompt = base:FindFirstChild("RobuxOpenPrompt")
				if robuxPrompt and not mine then
					robuxPrompt.Enabled = false
				end
				-- no fixed spots any more (you place things anywhere; HUD shows a green aim ring instead)
				local marker = pedestal:FindFirstChild("Marker")
				if marker then
					marker.Transparency = 1
				end
				-- an opening box slowly GROWS and GLOWS as it gets close to opening (just on your screen)
				local display = pedestal:FindFirstChild("Display")
				local readyAtGrow = pedestal:GetAttribute("State") == "Box" and pedestal:GetAttribute("BoxReadyAt")
				if display and display:IsA("Model") and readyAtGrow then
					local startAt = pedestal:GetAttribute("BoxStartAt") or (readyAtGrow - 60)
					local progress = math.clamp((now - startAt) / math.max(1, readyAtGrow - startAt), 0, 1)
					local baseScale = display:GetAttribute("_BaseScale")
					if not baseScale then
						baseScale = display:GetScale()
						display:SetAttribute("_BaseScale", baseScale)
					end
					local wobble = progress > 0.9 and math.sin(os.clock() * 25) * 0.02 or 0
					pcall(function()
						display:ScaleTo(baseScale * (0.8 + 0.35 * progress + wobble))
					end)
					local bodyPart = display.PrimaryPart
					local glow = bodyPart and bodyPart:FindFirstChild("OpenGlow")
					if bodyPart and not glow then
						glow = Instance.new("PointLight")
						glow.Name = "OpenGlow"
						glow.Color = Color3.fromRGB(255, 230, 120)
						glow.Parent = bodyPart
					end
					if glow then
						glow.Brightness = progress * 4 * (0.8 + 0.2 * math.sin(os.clock() * 6))
						glow.Range = 6 + progress * 14
					end
				end
				local timer = base:FindFirstChild("BoxTimer")
				local readyAt = pedestal:GetAttribute("State") == "Box" and pedestal:GetAttribute("BoxReadyAt")
				if readyAt and (base.Position - workspace.CurrentCamera.CFrame.Position).Magnitude < 160 then
					if not timer then
						timer = Instance.new("BillboardGui")
						timer.Name = "BoxTimer"
						timer.Size = UDim2.fromOffset(110, 36)
						timer.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
						timer.LightInfluence = 0
						timer.MaxDistance = 160
						timer.Parent = base
						local label = Instance.new("TextLabel")
						label.Name = "Label"
						label.Size = UDim2.fromScale(1, 1)
						label.BackgroundTransparency = 1
						label.Font = Enum.Font.FredokaOne
						label.TextScaled = true
						label.TextColor3 = Color3.fromRGB(255, 230, 120)
						label.Parent = timer
						local stroke = Instance.new("UIStroke")
						stroke.Thickness = 3
						stroke.Parent = label
					end
					timer.Label.Text = "⏳ " .. Format.Clock(math.max(0, readyAt - now))
				elseif timer then
					timer:Destroy()
				end
			end
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

-- ── boxes you already took are hidden for you only ───────────────────
local function hideIfTaken(model)
	if model:GetAttribute("LocalShrinking") then
		return
	end
	if string.find(model:GetAttribute("Taken") or "", "," .. player.UserId .. ",", 1, true) then
		-- its light beam / ground ring go too (local only: other players still see them)
		local uid = model:GetAttribute("SpawnUid")
		local live = model.Parent
		if uid and live and model:GetAttribute("HasFX") then
			for _, fx in ipairs(live:GetChildren()) do
				if fx:GetAttribute("ForBox") == uid then
					fx:Destroy()
				end
			end
		end
		model:Destroy() -- local only: other players still see it
	end
end

-- boxes in the zones gently hover and spin (just on your screen)
local function boxHover()
	local base = setmetatable({}, { __mode = "k" })
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local t = os.clock()
		local camPos = camera.CFrame.Position
		for _, model in ipairs(CollectionService:GetTagged("Shrinkable")) do
			if model:IsA("Model") and model.Parent and model:GetAttribute("Landed") and not model:GetAttribute("LocalShrinking") then
				local b = base[model]
				if not b then
					b = { CF = model:GetPivot(), Phase = (model:GetAttribute("SpawnUid") or 0) % 7 }
					base[model] = b
				end
				if (b.CF.Position - camPos).Magnitude < 160 then
					model:PivotTo(b.CF * CFrame.new(0, 0.7 + math.sin(t * 2 + b.Phase) * 0.45, 0) * CFrame.Angles(0, (t * 0.7 + b.Phase) % (math.pi * 2), 0))
				end
			end
		end
	end)
end

local function watchBoxes()
	local function hook(model)
		if model:IsA("Model") then
			hideIfTaken(model)
			model:GetAttributeChangedSignal("Taken"):Connect(function()
				task.delay(GameConfig.ShrinkFxTime + 0.3, function()
					if model.Parent then
						model:SetAttribute("LocalShrinking", nil)
						hideIfTaken(model)
					end
				end)
			end)
		end
	end
	for _, m in ipairs(CollectionService:GetTagged("Shrinkable")) do
		hook(m)
	end
	CollectionService:GetInstanceAddedSignal("Shrinkable"):Connect(hook)
end

-- ── treadmill: stepping on YOUR treadmill locks you in place and you RUN (AFK-able) ─────
-- Press jump (Space / jump button) to hop off.
local RUN_R15 = "rbxassetid://913376220"
local RUN_R6 = "rbxassetid://180426354"
local function treadmillLock()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TreadmillHint"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local hint = Instance.new("TextLabel")
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.new(0.5, 0, 0.2, 0) -- upper middle: clear of the bottom bar
	hint.Size = UDim2.fromOffset(420, 34)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.FredokaOne
	hint.TextScaled = true
	hint.TextColor3 = Color3.fromRGB(120, 255, 140)
	hint.Text = "TRAINING SPEED! Jump to get off"
	hint.Visible = false
	hint.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = hint

	local locked, track, exitUntil = nil, nil, 0
	local function unlock(hopOff)
		if not locked then
			return
		end
		local cf, len = locked.CF, locked.Len
		locked = nil
		hint.Visible = false
		if track then
			track:Stop(0.2)
			track = nil
		end
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if hum then
			hum.AutoRotate = true
		end
		if hopOff and root and cf then
			exitUntil = os.clock() + 2.5
			-- off the back end of the belt
			root.CFrame = cf * CFrame.new(0, 3.5, len / 2 + 3.5)
		end
	end
	UserInputService.JumpRequest:Connect(function()
		unlock(true)
	end)
	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local cf = player:GetAttribute("TreadmillCF")
		local want = player:GetAttribute("Training") == true and cf ~= nil and os.clock() > exitUntil and hum and root and hum.Health > 0
		if not want then
			unlock(false)
			return
		end
		if not locked then
			locked = { CF = cf, Len = player:GetAttribute("TreadmillLen") or 11 }
			hum.AutoRotate = false
			hint.Visible = true
			pcall(function()
				local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
				local anim = Instance.new("Animation")
				anim.AnimationId = hum.RigType == Enum.HumanoidRigType.R15 and RUN_R15 or RUN_R6
				track = animator:LoadAnimation(anim)
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = true
				track:Play(0.2)
			end)
		end
		-- pinned to the middle of the belt, facing the console
		local up = (player:GetAttribute("TreadmillTop") or 0.15) + hum.HipHeight + root.Size.Y / 2
		root.CFrame = locked.CF * CFrame.new(0, up, 0)
		root.AssemblyLinearVelocity = Vector3.zero
		if track then
			track:AdjustSpeed(math.clamp(hum.WalkSpeed / 24, 1, 2.5))
		end
	end)
end

-- ── floating stand titles: gentle bob + a shine sliding across ─────────
local function floatingTitles()
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		for _, plate in ipairs(CollectionService:GetTagged("NameplateFX")) do
			if plate:IsA("GuiObject") then
				Nameplate.Animate(plate, t)
			end
		end
		for i, gui in ipairs(CollectionService:GetTagged("FloatingTitle")) do
			local base = gui:GetAttribute("BaseHeight")
			if base and gui:IsA("BillboardGui") then
				gui.StudsOffsetWorldSpace = Vector3.new(0, base + math.sin(t * 1.6 + i) * 0.45, 0)
				local title = gui:FindFirstChild("Title")
				local shine = title and title:FindFirstChild("Shine")
				if shine then
					shine.Offset = Vector2.new(((t * 0.35 + i * 0.3) % 2.4) - 1.2, 0)
				end
			end
		end
	end)
end

-- ── hover info: point at anyone's pedestal object ────────────────────
local function hoverInfo()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HoverInfo"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromOffset(250, 92)
	frame.BackgroundColor3 = Color3.fromRGB(38, 40, 58)
	frame.BackgroundTransparency = 0.1
	frame.Visible = false
	frame.Parent = gui
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 20, 30)
	stroke.Parent = frame
	local lines = {}
	for i = 1, 4 do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, -16, 0, i == 1 and 26 or 20)
		l.Position = UDim2.fromOffset(8, i == 1 and 4 or (10 + (i - 1) * 20))
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Parent = frame
		local st = Instance.new("UIStroke")
		st.Thickness = 1.5
		st.Parent = l
		lines[i] = l
	end
	local mouse = player:GetMouse()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	RunService.RenderStepped:Connect(function()
		params.FilterDescendantsInstances = { player.Character }
		local ray = mouse.UnitRay
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 400, params)
		local node = hit and hit.Instance
		local pedestal
		while node and node ~= workspace do
			if node:GetAttribute("PedestalSlot") then
				pedestal = node
				break
			end
			node = node.Parent
		end
		if pedestal and pedestal:GetAttribute("State") == "Item" then
			local variant = RarityConfig.GetVariant(pedestal:GetAttribute("Variant"))
			lines[1].Text = pedestal:GetAttribute("ItemName") or "?"
			lines[1].TextColor3 = variant.Color or Color3.new(1, 1, 1)
			lines[2].Text = "💰 +" .. Format.Coins(pedestal:GetAttribute("Income") or 0) .. "/s"
			lines[2].TextColor3 = Color3.fromRGB(120, 255, 120)
			lines[3].Text = "⚖️ " .. (pedestal:GetAttribute("Weight") or "?") .. "  ·  📏 " .. (pedestal:GetAttribute("SizeName") or "Normal")
			local owner = pedestal:GetAttribute("OwnerUserId") == player.UserId and "You" or (pedestal:GetAttribute("OwnerName") or "?")
			lines[4].Text = "👤 " .. owner
			lines[4].TextColor3 = Color3.fromRGB(190, 200, 230)
			frame.Position = UDim2.fromOffset(mouse.X + 18, mouse.Y + 10)
			frame.Visible = true
		elseif pedestal and pedestal:GetAttribute("State") == "Box" then
			-- an opening box: shows its LUCK (and how big it is)
			local luck = pedestal:GetAttribute("BoxLuck")
			lines[1].Text = pedestal:GetAttribute("ItemName") or "Mystery Box"
			lines[1].TextColor3 = Color3.fromRGB(255, 230, 120)
			lines[2].Text = "Luck x" .. (luck and string.format("%.1f", luck) or "1.0")
			lines[2].TextColor3 = Color3.fromRGB(120, 255, 140)
			local readyAt = pedestal:GetAttribute("BoxReadyAt")
			local left = readyAt and math.max(0, readyAt - State.Now()) or 0
			lines[3].Text = "📏 " .. (pedestal:GetAttribute("SizeName") or "Normal") .. "  ·  ⏳ " .. (left > 0 and Format.Time(left) or "Ready!")
			local owner = pedestal:GetAttribute("OwnerUserId") == player.UserId and "You" or (pedestal:GetAttribute("OwnerName") or "?")
			lines[4].Text = "👤 " .. owner
			lines[4].TextColor3 = Color3.fromRGB(190, 200, 230)
			frame.Position = UDim2.fromOffset(mouse.X + 18, mouse.Y + 10)
			frame.Visible = true
		else
			frame.Visible = false
		end
	end)
end

-- ── PvP / chaser effects ─────────────────────────────────────────────
local function popText(position, text, color)
	local att = Instance.new("Attachment")
	att.WorldPosition = position + Vector3.new(0, 3, 0)
	att.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 50)
	gui.AlwaysOnTop = true
	gui.Adornee = att
	gui.Parent = att
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = gui
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Parent = l
	TweenService:Create(gui, TweenInfo.new(1.2), { StudsOffsetWorldSpace = Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(l, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
	task.delay(1.3, function()
		att:Destroy()
	end)
end

local function onPvPFX(kind, p)
	if kind == "Hit" then
		burst(p.Position, Color3.fromRGB(255, 220, 80), 18, 1)
		popText(p.Position, "BONK!", Color3.fromRGB(255, 220, 80))
	elseif kind == "Steal" then
		local root = p.Victim and p.Victim.Character and p.Victim.Character:FindFirstChild("HumanoidRootPart")
		if root then
			popText(root.Position, "STOLEN!", Color3.fromRGB(255, 90, 90))
		end
	elseif kind == "Trap" then
		burst(p.Position, Color3.fromRGB(200, 200, 210), 20, 0.8)
		popText(p.Position, "SNAP!", Color3.fromRGB(230, 230, 240))
	end
end

local function onChaserFX(kind, p)
	if kind == "Chase" then
		Audio.Play("Alarm", 0.6)
	end
end

-- ── chat: Global tab is the default + lines from other servers ───────
local function setupChat()
	task.spawn(function()
		local channels = TextChatService:WaitForChild("TextChannels", 20)
		local global = channels and channels:WaitForChild("Global", 20)
		local server = channels and channels:WaitForChild("Server", 20)
		if not global then
			return
		end
		pcall(function()
			TextChatService.ChatInputBarConfiguration.TargetTextChannel = server or global -- Server is the default tab
		end)
		Remotes.Event("GlobalChat").OnClientEvent:Connect(function(name, text)
			pcall(function()
				global:DisplaySystemMessage("<font color='#7FD4FF'>[ " .. name .. "]</font> " .. text)
			end)
		end)
	end)
end

-- ── settings: graphics / trails / anti-AFK ───────────────────────────
local function settingsLoop()
	local VirtualUser = game:GetService("VirtualUser")
	player.Idled:Connect(function()
		-- keep AFK speed-training players in the game (Roblox kicks after 20 idle minutes)
		if player:GetAttribute("Training") then
			pcall(function()
				VirtualUser:CaptureController()
				VirtualUser:ClickButton2(Vector2.new())
			end)
		end
	end)
	while true do
		task.wait(1.5)
		local settings = State.Data and State.Data.Settings
		if settings then
			Audio.ApplySettings(settings)
			for _, other in ipairs(Players:GetPlayers()) do
				local root = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
				local trail = root and root:FindFirstChild("ShrinkTrail")
				if trail then
					trail.Enabled = settings.ShowTrails ~= false
				end
			end
			local low = settings.LowGraphics == true
			if low ~= Effects.LowGraphics then
				Effects.LowGraphics = low
				local lighting = game:GetService("Lighting")
				lighting.GlobalShadows = not low
				for _, e in ipairs(lighting:GetChildren()) do
					if e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect") then
						e.Enabled = not low
					end
				end
			end
			if low then
				local map = workspace:FindFirstChild("ShrinkItMap")
				for _, d in ipairs(map and map:GetDescendants() or {}) do
					if d:IsA("ParticleEmitter") or d:IsA("Sparkles") or d:IsA("Fire") then
						d.Enabled = false
					end
				end
			end
		end
	end
end

-- floating owner badge over every plot: avatar headshot + "Your Plot" / "Name's Plot"
local function plotBadges()
	local map = workspace:WaitForChild("ShrinkItMap", 60)
	local plots = map and map:WaitForChild("Plots", 30)
	if not plots then
		return
	end
	local badges = {}
	local function badgeFor(plot)
		local building = plot:FindFirstChild("MuseumBuilding")
		local anchor = building and (building.PrimaryPart or building:FindFirstChild("Body")) or plot:FindFirstChild("Floor")
		if not anchor then
			return nil
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "OwnerBadge"
		gui.Size = UDim2.fromOffset(240, 150)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 26, 0)
		gui.MaxDistance = 300
		gui.LightInfluence = 0
		gui.Adornee = anchor
		gui.Parent = player:WaitForChild("PlayerGui")
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0)
		ring.Position = UDim2.fromScale(0.5, 0)
		ring.Size = UDim2.fromOffset(96, 96)
		ring.BackgroundColor3 = Color3.fromRGB(30, 28, 40)
		ring.Parent = gui
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(1, 0)
		rc.Parent = ring
		local rs = Instance.new("UIStroke")
		rs.Thickness = 4
		rs.Parent = ring
		local head = Instance.new("ImageLabel")
		head.BackgroundTransparency = 1
		head.Size = UDim2.new(1, -8, 1, -8)
		head.Position = UDim2.fromOffset(4, 4)
		head.Parent = ring
		local hc = Instance.new("UICorner")
		hc.CornerRadius = UDim.new(1, 0)
		hc.Parent = head
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, 100)
		label.Size = UDim2.new(1, 0, 0, 40)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Parent = gui
		local ls = Instance.new("UIStroke")
		ls.Thickness = 3
		ls.Parent = label
		return { Gui = gui, Head = head, Label = label, Stroke = rs, Owner = nil }
	end
	while true do
		for _, plot in ipairs(plots:GetChildren()) do
			local b = badges[plot]
			if b == nil then
				b = badgeFor(plot) or false
				badges[plot] = b
			end
			if b then
				local owner = plot:GetAttribute("OwnerUserId") or 0
				if owner ~= b.Owner then
					b.Owner = owner
					b.Gui.Enabled = owner ~= 0
					local who = owner ~= 0 and Players:GetPlayerByUserId(owner)
					if owner == player.UserId then
						b.Label.Text = "Your Plot"
						b.Stroke.Color = Color3.fromRGB(90, 255, 120)
					elseif who then
						b.Label.Text = who.DisplayName .. "'s Plot"
						b.Stroke.Color = Color3.fromRGB(255, 80, 80)
					end
					if owner ~= 0 then
						b.Head.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", owner)
					end
				end
			end
		end
		task.wait(1)
	end
end

function Effects.Init()
	Audio.Init()
	task.spawn(watchBoxes)
	task.spawn(hoverInfo)
	task.spawn(treadmillLock)
	task.spawn(floatingTitles)
	task.spawn(boxHover)
	task.spawn(settingsLoop)
	setupChat()
	Remotes.Event("PvPFX").OnClientEvent:Connect(onPvPFX)
	Remotes.Event("ChaserFX").OnClientEvent:Connect(onChaserFX)
	task.spawn(guideArrows)
	task.spawn(pedestalLoop)
	Remotes.Event("BoxOpened").OnClientEvent:Connect(onBoxOpened)
	Remotes.Event("CarryFX").OnClientEvent:Connect(onCarryFX)
	Remotes.Event("ShrinkFX").OnClientEvent:Connect(playShrink)
	Remotes.Event("ChargeFX").OnClientEvent:Connect(onChargeFX)
	Remotes.Event("RaidSync").OnClientEvent:Connect(onRaidSync)

	State.Observe(refreshGates)
	CollectionService:GetInstanceAddedSignal("AreaGate"):Connect(refreshGates)
	CollectionService:GetInstanceAddedSignal("VIPDoor"):Connect(refreshGates)

	task.spawn(floaterLoop)
	task.spawn(plotBadges)

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
			props.PrefixText = "<font color='#FFD23F'>[ VIP]</font> " .. message.PrefixText
		end
		return props
	end
end

return Effects
