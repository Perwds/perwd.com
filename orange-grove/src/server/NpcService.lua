--!strict
-- NPCs are real Roblox avatars built from HumanoidDescriptions (user IDs or catalog IDs in Config.Npc).
-- Pickers are the visible side of "Hire a Picker"; their oranges are credited by Production, not by these walks.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Palette = require(ReplicatedStorage.Shared.Palette)
local BoardBuilder = require(script.Parent.BoardBuilder)
local UpgradeService = require(script.Parent.UpgradeService)

local NpcService = {}

local PICKER_NAMES = { "Junie", "Bram", "Ottilie", "Rey", "Pip", "Ines", "Mo", "Tavi", "Wren", "Sol", "Hattie", "Kofi" }

type Npc = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	tracks: { [string]: AnimationTrack },
	alive: boolean,
	owner: Player?,
}

local folder: Folder
local looks: { HumanoidDescription } = {}
local looksReady = false
local warnedDefault = false
local pickers: { [Player]: { Npc } } = {}
local nameCursor = 0

local function warnDefaultOnce(reason: string)
	if not warnedDefault then
		warnedDefault = true
		warn("[NpcService] " .. reason .. " NPCs will use the default Roblox avatar.")
	end
end

local function fromUserId(userId: number): HumanoidDescription?
	if userId == 0 then
		return nil
	end
	local ok, desc = pcall(Players.GetHumanoidDescriptionFromUserId, Players, userId)
	if ok and desc then
		return desc
	end
	warnDefaultOnce("Couldn't load the avatar for user " .. userId .. ".")
	return nil
end

local function fromOutfit(outfit: { [string]: any }): HumanoidDescription
	local desc = Instance.new("HumanoidDescription")
	for property, value in outfit do
		local ok = pcall(function()
			(desc :: any)[property] = value
		end)
		if not ok then
			warnDefaultOnce("Config.Npc.outfits has an unknown field '" .. tostring(property) .. "'.")
		end
	end
	return desc
end

local function loadLooks()
	for _, userId in Config.Npc.farmhandUserIds do
		local desc = fromUserId(userId)
		if desc then
			table.insert(looks, desc)
		end
	end
	for _, outfit in Config.Npc.outfits do
		table.insert(looks, fromOutfit(outfit))
	end
	if #looks == 0 then
		warnDefaultOnce("Config.Npc has no farmhand user IDs or outfits.")
	end
end

local function lookFor(index: number): HumanoidDescription
	if #looks == 0 then
		return Instance.new("HumanoidDescription")
	end
	return looks[(index - 1) % #looks + 1]:Clone()
end

local function loadTrack(
	animator: Animator,
	id: string,
	priority: Enum.AnimationPriority,
	looped: boolean
): AnimationTrack
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local track = animator:LoadAnimation(animation)
	track.Priority = priority
	track.Looped = looped
	return track
end

local function spawnNpc(desc: HumanoidDescription, displayName: string, cframe: CFrame): Npc?
	local ok, model = pcall(Players.CreateHumanoidModelFromDescription, Players, desc, Enum.HumanoidRigType.R15)
	if not ok then
		warnDefaultOnce("A configured look failed to build (" .. tostring(model) .. ").")
		ok, model = pcall(
			Players.CreateHumanoidModelFromDescription,
			Players,
			Instance.new("HumanoidDescription"),
			Enum.HumanoidRigType.R15
		)
		if not ok then
			return nil
		end
	end
	local npc = model :: Model
	npc.Name = displayName
	local animate = npc:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = npc:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = npc:FindFirstChild("HumanoidRootPart") :: BasePart
	humanoid.DisplayName = displayName
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.NameDisplayDistance = 40
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = Config.Npc.walkSpeed
	humanoid.BreakJointsOnDeath = false
	npc:PivotTo(cframe)
	npc.Parent = folder
	root:SetNetworkOwner(nil)

	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = humanoid
	local anims = Config.Animations
	local tracks = {
		idle = loadTrack(animator, anims.idle, Enum.AnimationPriority.Idle, true),
		walk = loadTrack(animator, anims.walk, Enum.AnimationPriority.Movement, true),
		reach = loadTrack(animator, anims.reach, Enum.AnimationPriority.Action, false),
		carry = loadTrack(animator, anims.carry, Enum.AnimationPriority.Action, true),
		wave = loadTrack(animator, anims.wave, Enum.AnimationPriority.Action, false),
	}
	tracks.idle:Play()
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			if not tracks.walk.IsPlaying then
				tracks.walk:Play(0.15)
				tracks.idle:Stop(0.15)
			end
			tracks.walk:AdjustSpeed(speed / 12)
		elseif tracks.walk.IsPlaying then
			tracks.walk:Stop(0.15)
			tracks.idle:Play(0.15)
		end
	end)

	return { model = npc, humanoid = humanoid, root = root, tracks = tracks, alive = true, owner = nil }
end

local function walkTo(npc: Npc, target: Vector3)
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
	local ok = pcall(function()
		path:ComputeAsync(npc.root.Position, target)
	end)
	local points = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for _, waypoint in path:GetWaypoints() do
			table.insert(points, waypoint.Position)
		end
	else
		points = { target }
	end
	for _, point in points do
		if not npc.alive then
			return
		end
		npc.humanoid:MoveTo(point)
		local reached = false
		local connection = npc.humanoid.MoveToFinished:Connect(function()
			reached = true
		end)
		local started = os.clock()
		while not reached and npc.alive and os.clock() - started < 6 do
			task.wait(0.1)
		end
		connection:Disconnect()
	end
end

local function face(npc: Npc, point: Vector3)
	local pos = npc.root.Position
	npc.root.CFrame = CFrame.lookAt(pos, Vector3.new(point.X, pos.Y, point.Z))
end

local function handProp(npc: Npc, handName: string, size: Vector3, color: Color3): BasePart?
	local hand = npc.model:FindFirstChild(handName) :: BasePart?
	if not hand then
		return nil
	end
	local prop = Instance.new("Part")
	prop.Name = "Prop"
	prop.Size = size
	prop.Color = color
	prop.Material = Enum.Material.SmoothPlastic
	prop.CanCollide = false
	prop.Massless = true
	prop.CFrame = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2 - size.Y / 2, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = prop
	weld.Parent = prop
	prop.Parent = npc.model
	return prop
end

local function eatOrange(npc: Npc)
	local head = npc.model:FindFirstChild("Head") :: BasePart?
	local hand = npc.model:FindFirstChild("RightHand") :: BasePart?
	if not head or not hand then
		return
	end
	local orange = Instance.new("Part")
	orange.Shape = Enum.PartType.Ball
	orange.Size = Vector3.new(0.8, 0.8, 0.8)
	orange.Color = Palette.orange
	orange.Anchored = true
	orange.CanCollide = false
	orange.CFrame = hand.CFrame
	orange.Parent = npc.model
	npc.tracks.reach:Play(0.2)
	local toMouth = TweenService:Create(
		orange,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = head.CFrame * CFrame.new(0, -0.3, -0.7) }
	)
	toMouth:Play()
	toMouth.Completed:Wait()
	for _ = 1, 3 do
		task.wait(0.5)
		orange.Size *= 0.75
	end
	orange:Destroy()
	task.wait(0.6)
end

local function orchardTrees(): { BoardBuilder.TreeInfo }
	local list = {}
	for _, tree in BoardBuilder.trees do
		if not tree.vip then
			table.insert(list, tree)
		end
	end
	return list
end

local function pickerLoop(npc: Npc)
	local trees = orchardTrees()
	local rng = Random.new()
	while npc.alive do
		local tree = trees[rng:NextInteger(1, #trees)]
		local side = rng:NextUnitVector() * Vector3.new(1, 0, 1)
		local stand = tree.position + (if side.Magnitude > 0.1 then side.Unit else Vector3.xAxis) * 3.5
		walkTo(npc, stand)
		if not npc.alive then
			break
		end
		face(npc, tree.position)
		for _ = 1, rng:NextInteger(2, 3) do
			npc.tracks.reach:Play(0.15)
			task.wait(0.9)
		end
		if rng:NextNumber() < Config.Npc.eatChance then
			eatOrange(npc)
		end
		local basket = handProp(npc, "LeftHand", Vector3.new(1.4, 1, 1.4), Color3.fromRGB(170, 120, 70))
		npc.tracks.carry:Play(0.2)
		walkTo(npc, BoardBuilder.pressDrop + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-2, 2)))
		npc.tracks.carry:Stop(0.2)
		if basket then
			basket:Destroy()
		end
		task.wait(rng:NextNumber(0.6, 1.6))
	end
end

local function despawn(npc: Npc)
	npc.alive = false
	npc.model:Destroy()
end

local function totalPickerNpcs(): number
	local n = 0
	for _, list in pickers do
		n += #list
	end
	return n
end

local function syncPickers(player: Player)
	if not looksReady or not player.Parent then
		return
	end
	local list = pickers[player] or {}
	pickers[player] = list
	local want = math.floor(UpgradeService.stats(player).totalPickers)
	-- Share the NPC cap fairly: nobody gets more than the cap split across players.
	local share = math.max(1, math.floor(Config.Npc.maxPickerNpcs / math.max(1, #Players:GetPlayers())))
	want = math.min(want, share)
	while #list > want do
		despawn(table.remove(list) :: Npc)
	end
	while #list < want and totalPickerNpcs() < Config.Npc.maxPickerNpcs do
		nameCursor += 1
		local name = PICKER_NAMES[(nameCursor - 1) % #PICKER_NAMES + 1]
		local start = CFrame.new(BoardBuilder.pressDrop + Vector3.new(0, 3, 0))
		local npc = spawnNpc(lookFor(nameCursor), name, start)
		if not npc then
			break
		end
		npc.owner = player
		npc.humanoid.DisplayName = name .. " (" .. player.DisplayName .. ")"
		table.insert(list, npc)
		task.spawn(pickerLoop, npc)
	end
end

local function standingNpc(userId: number, name: string, spot: CFrame?, index: number): Npc?
	if not spot then
		return nil
	end
	local desc = fromUserId(userId) or lookFor(index)
	local npc = spawnNpc(desc, name, spot)
	if npc then
		npc.root.Anchored = true
	end
	return npc
end

function NpcService.init()
	folder = Instance.new("Folder")
	folder.Name = "Npcs"
	folder.Parent = workspace

	task.spawn(function()
		loadLooks()
		looksReady = true
		local keeper = standingNpc(Config.Npc.keeperUserId, Config.Npc.keeperName, BoardBuilder.npcSpots.keeper, 1)
		if keeper then
			keeper.model:SetAttribute("Keeper", true)
			task.spawn(function()
				while keeper.alive do
					task.wait(math.random(9, 16))
					for _, player in Players:GetPlayers() do
						local character = player.Character
						local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and (root.Position - keeper.root.Position).Magnitude < 18 then
							keeper.tracks.wave:Play(0.2)
							break
						end
					end
				end
			end)
		end
		local worker =
			standingNpc(Config.Npc.juiceWorkerUserId, Config.Npc.juiceWorkerName, BoardBuilder.npcSpots.juiceWorker, 2)
		if worker then
			task.spawn(function()
				while worker.alive do
					task.wait(math.random(4, 8))
					worker.tracks.reach:Play(0.2)
				end
			end)
		end
		for _, player in Players:GetPlayers() do
			syncPickers(player)
		end
	end)

	UpgradeService.onChanged(function(player)
		syncPickers(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		for _, npc in pickers[player] or {} do
			despawn(npc)
		end
		pickers[player] = nil
		for _, other in Players:GetPlayers() do
			if other ~= player then
				task.defer(syncPickers, other)
			end
		end
	end)
end

return NpcService
