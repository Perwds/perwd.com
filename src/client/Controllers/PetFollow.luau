--[[
	Renders the local player's equipped pets following them.

	Entirely client-side: the server owns which pets are equipped, the client
	owns where they float. That keeps pet movement off the wire completely,
	which matters once six pets per player are bobbing around.

	Other players' pets are rendered from their equipped list too, read off a
	player attribute the server publishes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local ModelFactory = require(ReplicatedStorage.Shared.Util.ModelFactory)

local State = require(script.Parent.State)

local player = Players.LocalPlayer

local PetFollow = {}

local container: Folder
-- uid -> { model, petId, offsetAngle }
local rendered: { [string]: any } = {}

--- Equipped pets in the server's order, so slots stay put between syncs.
local function desired(): { any }
	local out = {}
	for _, uid in State.data.equipped do
		for _, pet in State.data.pets do
			if pet.uid == uid then
				table.insert(out, pet)
				break
			end
		end
	end
	return out
end

local function despawn(uid: string)
	local entry = rendered[uid]
	if not entry then
		return
	end
	if entry.model then
		entry.model:Destroy()
	end
	rendered[uid] = nil
end

local function sync()
	local want = desired()

	local wanted: { [string]: boolean } = {}
	for _, pet in want do
		wanted[pet.uid] = true
	end

	for uid in rendered do
		if not wanted[uid] then
			despawn(uid)
		end
	end

	for slot, pet in want do
		local entry = rendered[pet.uid]
		if entry and entry.petId ~= pet.id then
			despawn(pet.uid)
			entry = nil
		end

		if not entry then
			local model = ModelFactory.buildPet(pet.id)
			if not model then
				continue
			end
			ModelFactory.configure(model, true)
			model.Name = pet.uid
			model.Parent = container

			entry = { model = model, petId = pet.id }
			rendered[pet.uid] = entry
		end

		entry.slot = slot
		entry.total = #want
	end
end

local function update(dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	local now = os.clock()

	for _, entry in rendered do
		local model = entry.model
		if not model or not model.Parent or not model.PrimaryPart then
			continue
		end

		local total = math.max(1, entry.total or 1)
		local slot = (entry.slot or 1) - 1
		local angle = (slot / total) * math.pi * 2

		-- Sit behind the player, spread around a small arc.
		local offset = Vector3.new(
			math.sin(angle) * Balance.Pets.FOLLOW_RADIUS,
			Balance.Pets.FOLLOW_HEIGHT + math.sin(now * Balance.Pets.BOB_SPEED + slot) * Balance.Pets.BOB_AMPLITUDE,
			Balance.Pets.FOLLOW_RADIUS * 0.8 + math.cos(angle) * 2
		)

		local target = root.CFrame * CFrame.new(offset)
		-- Face the way the player is facing rather than snapping to them.
		local goal = CFrame.lookAt(target.Position, target.Position + root.CFrame.LookVector)

		local alpha = math.clamp(Balance.Pets.FOLLOW_SPEED * dt * 60, 0, 1)
		model:PivotTo(model:GetPivot():Lerp(goal, alpha))
	end
end

function PetFollow.start()
	container = Instance.new("Folder")
	container.Name = "LocalPets"
	container.Parent = Workspace:FindFirstChild("Map") or Workspace

	State.changed:Connect(function(kind)
		if kind == "full" then
			sync()
		end
	end)

	-- Snap pets to the player on respawn instead of letting them drift in.
	player.CharacterAdded:Connect(function(character)
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if not root then
			return
		end
		for _, entry in rendered do
			if entry.model then
				entry.model:PivotTo(root.CFrame * CFrame.new(0, 3, 6))
			end
		end
	end)

	RunService.RenderStepped:Connect(update)
end

return PetFollow
