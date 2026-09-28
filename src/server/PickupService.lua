--!strict
--[[
	PickupService
	Everything you physically collect in the world: coin orbs and chests.

	Orbs are the moment-to-moment loop -- they respawn, so there is always
	something to run towards while a scan ticks down. Chests are the reward for
	reaching somewhere awkward, and are on a per-player cooldown so they cannot
	be farmed by standing still.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Palette = require(Shared.Palette)
local Format = require(Shared.Format)

local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)

local PickupService = {}

local ORB_RESPAWN = 7
local root: Folder

-- [userId] = { [chestName] = os.clock() when it may be opened again }
local chestReady: { [number]: { [string]: number } } = {}

local function container(): Folder
	if not root then
		root = Instance.new("Folder")
		root.Name = "Pickups"
		root.Parent = workspace
	end
	return root
end

--- Credits coins through the player's multipliers and tells them about it.
function PickupService.award(player: Player, base: number, label: string, icon: string, tint: Color3)
	local profile = DataService.get(player)
	if not profile then
		return 0
	end

	local amount = math.floor(base * StateService.coinMultiplierFor(player, profile))
	profile.coins += amount

	StateService.notify(player, ("%s  +%s coins"):format(label, Format.comma(amount)), icon, tint)
	StateService.markDirty(player)
	return amount
end

-- Orbs -------------------------------------------------------------------

function PickupService.spawnOrb(position: Vector3, value: number, tint: Color3?)
	local orb = Instance.new("Part")
	orb.Name = "CoinOrb"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(3, 3, 3)
	orb.Position = position
	orb.Anchored = true
	orb.CanCollide = false
	orb.Material = Enum.Material.Neon
	orb.Color = tint or Palette.gold
	orb.Parent = container()

	local glow = Instance.new("PointLight")
	glow.Color = orb.Color
	glow.Range = 9
	glow.Brightness = 2
	glow.Parent = orb

	-- Bob and spin so it reads as collectable from across the map.
	local base = position
	local phase = math.random() * math.pi * 2
	local alive = true

	task.spawn(function()
		while alive and orb.Parent do
			local t = os.clock() * 2 + phase
			orb.CFrame = CFrame.new(base + Vector3.new(0, math.sin(t) * 0.6, 0))
				* CFrame.Angles(0, os.clock() * 2, 0)
			task.wait(0.05)
		end
	end)

	local busy = false
	orb.Touched:Connect(function(hit)
		if busy or orb.Transparency > 0 then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		busy = true
		PickupService.award(player, value, "Coin orb", "O", Palette.gold)

		-- Shrink away, then come back.
		TweenService:Create(orb, TweenInfo.new(0.2), { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }):Play()
		glow.Enabled = false

		task.delay(ORB_RESPAWN, function()
			if orb.Parent then
				orb.Size = Vector3.new(0.2, 0.2, 0.2)
				orb.Transparency = 0
				glow.Enabled = true
				TweenService:Create(
					orb,
					TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Size = Vector3.new(3, 3, 3) }
				):Play()
				busy = false
			end
		end)
	end)

	return orb
end

--- Scatters `count` orbs inside a square patch, skipping the middle so they
--- do not spawn inside whatever the patch is centred on.
function PickupService.scatter(centre: Vector3, spread: number, count: number, value: number, tint: Color3?)
	for _ = 1, count do
		local offset
		repeat
			offset = Vector3.new(math.random(-spread, spread), 0, math.random(-spread, spread))
		until offset.Magnitude > spread * 0.28
		PickupService.spawnOrb(centre + offset + Vector3.new(0, 3, 0), value, tint)
	end
end

-- Chests -----------------------------------------------------------------

function PickupService.spawnChest(position: Vector3, reward: number, cooldown: number, label: string)
	local chest = Instance.new("Part")
	chest.Name = "Chest_" .. label
	chest.Size = Vector3.new(6, 5, 4)
	chest.Position = position
	chest.Anchored = true
	chest.Material = Enum.Material.WoodPlanks
	chest.Color = Palette.gold
	chest.Parent = container()

	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(6.3, 1.4, 4.3)
	lid.Position = position + Vector3.new(0, 3.1, 0)
	lid.Anchored = true
	lid.Material = Enum.Material.WoodPlanks
	lid.Color = Palette.orange
	lid.Parent = chest

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(12, 3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	billboard.MaxDistance = 160
	billboard.Parent = chest

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.Text = label
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.1
	text.TextScaled = true
	text.Parent = billboard

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = label
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = chest

	prompt.Triggered:Connect(function(player)
		local ready = chestReady[player.UserId]
		if not ready then
			ready = {}
			chestReady[player.UserId] = ready
		end

		local now = os.clock()
		local readyAt = ready[chest.Name] or 0
		if now < readyAt then
			StateService.notify(
				player,
				("%s reopens in %s"):format(label, Format.clock(readyAt - now)),
				"X",
				Palette.red
			)
			return
		end

		ready[chest.Name] = now + cooldown
		PickupService.award(player, reward, label, "$", Palette.gold)

		-- Lid flips open and drops back.
		TweenService:Create(lid, TweenInfo.new(0.25), {
			CFrame = CFrame.new(lid.Position + Vector3.new(0, 1, -1.6)) * CFrame.Angles(math.rad(-70), 0, 0),
		}):Play()
		task.delay(1.2, function()
			if lid.Parent then
				TweenService:Create(lid, TweenInfo.new(0.35), { CFrame = CFrame.new(lid.Position) }):Play()
			end
		end)
	end)

	return chest
end

function PickupService.init()
	Players.PlayerRemoving:Connect(function(player)
		chestReady[player.UserId] = nil
	end)
end

return PickupService
