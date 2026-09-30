--[[
	Hatch pads.

	Carry an egg to one of your three pads, drop it on, and wait. Time is
	tracked as `remaining` plus a `lastTick` stamp rather than a fixed end
	time, which gives two things for free: the timer keeps running while you
	are offline, and standing near your pad can make it tick faster without
	the maths falling apart.

	When it opens, the egg's world pool is rolled with the egg's luck applied,
	so a Golden egg is far more likely to land on the rare end.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local ModelFactory = require(ReplicatedStorage.Shared.Util.ModelFactory)
local Net = require(ReplicatedStorage.Shared.Net)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local WeightedPicker = require(ReplicatedStorage.Shared.Util.WeightedPicker)

local CarryService = require(script.Parent.CarryService)
local DataService = require(script.Parent.DataService)
local PetService = require(script.Parent.PetService)
local PlotService = require(script.Parent.PlotService)

local HatchService = {}

HatchService.Hatched = Signal.new()

local hatchResult = Net.Event("HatchResult")
local notify = Net.Event("Notify")
local rng = Random.new()

local function padLabel(pad: BasePart, title: string, subtitle: string, color: Color3)
	local gui = pad:FindFirstChild("Label")
	if not gui then
		return
	end
	local titleLabel = gui:FindFirstChild("Title") :: TextLabel?
	local subLabel = gui:FindFirstChild("Sub") :: TextLabel?
	if titleLabel then
		titleLabel.Text = title
		titleLabel.TextColor3 = color
	end
	if subLabel then
		subLabel.Text = subtitle
	end
end

--- Rebuilds the visible egg sitting on a pad from the saved pad state.
local function renderPad(player: Player, padIndex: number)
	local pad = PlotService.padFor(player, padIndex)
	if not pad then
		return
	end

	local existing = pad:FindFirstChild("PadEgg")
	if existing then
		existing:Destroy()
	end

	local profile = DataService.get(player)
	local state = profile and profile.hatchPads[tostring(padIndex)]

	if not state then
		padLabel(pad, "Empty", "Carry an egg here", Color3.fromRGB(190, 195, 215))
		return
	end

	local model = ModelFactory.buildEgg(state.rarity)
	model.Name = "PadEgg"
	ModelFactory.configure(model, true)
	model:PivotTo(CFrame.new(pad.Position + Vector3.new(0, 4, 0)))
	model.Parent = pad

	padLabel(pad, state.rarity, Format.duration(state.remaining), Rarity.get(state.rarity).glow)
end

--- Applies elapsed time to every pad on a profile. Safe to call any time.
local function tickProfile(player: Player, profile)
	local now = os.time()
	local changed = false

	for key, state in profile.hatchPads do
		local elapsed = math.max(0, now - (state.lastTick or now))
		state.lastTick = now

		if elapsed <= 0 or state.remaining <= 0 then
			continue
		end

		local rate = 1
		if Balance.Hatch.PROXIMITY_BOOST > 1 then
			local pad = PlotService.padFor(player, tonumber(key) or 0)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if pad and root and (pad.Position - root.Position).Magnitude <= Balance.Hatch.PROXIMITY_RANGE then
				rate = Balance.Hatch.PROXIMITY_BOOST
			end
		end

		state.remaining = math.max(0, state.remaining - elapsed * rate)
		changed = true
	end

	if changed then
		DataService.markDirty(player)
	end
end

--- Seconds left on a pad, or nil if the pad is empty.
function HatchService.remaining(profile, padIndex: number): number?
	local state = profile.hatchPads[tostring(padIndex)]
	return state and state.remaining or nil
end

--[[
	Puts the carried egg on a pad. Returns a result table for the client.
]]
function HatchService.place(player: Player, padIndex: number)
	local profile = DataService.get(player)
	if not profile then
		return { ok = false, error = "Still loading" }
	end

	padIndex = math.floor(tonumber(padIndex) or 0)
	if padIndex < 1 or padIndex > Balance.Hatch.PADS_PER_PLOT then
		return { ok = false, error = "No such pad" }
	end

	local key = tostring(padIndex)
	if profile.hatchPads[key] then
		return { ok = false, error = "That pad is busy" }
	end

	local pad = PlotService.padFor(player, padIndex)
	if not pad then
		return { ok = false, error = "You have no plot" }
	end

	local egg = CarryService.carriedEgg(player)
	if not egg then
		return { ok = false, error = "You are not carrying an egg" }
	end

	-- Must actually walk it home.
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - pad.Position).Magnitude > 18 then
		return { ok = false, error = "Get closer to the pad" }
	end

	local eggId = egg:GetAttribute("EggId")
	local duration = tonumber(egg:GetAttribute("HatchTime")) or 60

	profile.hatchPads[key] = {
		eggId = eggId,
		world = egg:GetAttribute("World"),
		rarity = egg:GetAttribute("Rarity") or "Common",
		luck = tonumber(egg:GetAttribute("Luck")) or 1,
		total = duration,
		remaining = duration,
		lastTick = os.time(),
	}

	local consumed = CarryService.consume(player)
	if consumed then
		consumed:Destroy()
	end

	DataService.markDirty(player)
	renderPad(player, padIndex)

	return { ok = true, padIndex = padIndex, remaining = duration }
end

--[[
	Opens a finished egg and grants the pet.

	Luck multiplies the weight of every entry above Uncommon -- it never adds
	pets that were not in the pool, so an egg always keeps its identity.
]]
function HatchService.collect(player: Player, padIndex: number)
	local profile = DataService.get(player)
	if not profile then
		return { ok = false, error = "Still loading" }
	end

	tickProfile(player, profile)

	local key = tostring(math.floor(tonumber(padIndex) or 0))
	local state = profile.hatchPads[key]
	if not state then
		return { ok = false, error = "That pad is empty" }
	end
	if state.remaining > 0 then
		return { ok = false, error = `Not ready -- {Format.duration(state.remaining)} left` }
	end

	local egg = Eggs.get(state.eggId)
	if not egg then
		profile.hatchPads[key] = nil
		DataService.markDirty(player)
		return { ok = false, error = "That egg no longer exists" }
	end

	local luck = state.luck or 1
	local entry = WeightedPicker.pick(egg.pool, rng, function(poolEntry)
		local pet = Pets.get(poolEntry.petId)
		if not pet then
			return 1
		end
		return (Rarity.Rank[pet.rarity] or 1) >= 3 and luck or 1
	end)

	if not entry then
		return { ok = false, error = "Empty egg pool" }
	end

	profile.hatchPads[key] = nil
	profile.stats.hatched += 1

	local uid, shiny = PetService.grant(player, entry.petId)
	if not uid then
		-- Inventory was full. Put the egg back so nothing is lost.
		profile.hatchPads[key] = state
		state.remaining = 0
		DataService.markDirty(player)
		return { ok = false, error = "Inventory full -- sell some pets first" }
	end

	DataService.markDirty(player)
	renderPad(player, tonumber(key) or 1)

	local pet = Pets.get(entry.petId)
	HatchService.Hatched:Fire(player, entry.petId, uid, shiny)

	hatchResult:FireClient(player, {
		petId = entry.petId,
		uid = uid,
		shiny = shiny,
		rarity = pet and pet.rarity or "Common",
		name = pet and pet.name or entry.petId,
	})

	return { ok = true, petId = entry.petId, uid = uid, shiny = shiny }
end

local function ensurePadPrompt(player: Player, padIndex: number)
	local pad = PlotService.padFor(player, padIndex)
	if not pad then
		return
	end

	local prompt = pad:FindFirstChild("PadPrompt") :: ProximityPrompt?
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "PadPrompt"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 14
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad

		prompt.Triggered:Connect(function(triggering)
			-- Only the plot owner can use their own pads.
			if PlotService.forPlayer(triggering) ~= PlotService.plotOf(pad) then
				notify:FireClient(triggering, "warn", "That is not your plot")
				return
			end

			local profile = DataService.get(triggering)
			if not profile then
				return
			end

			if profile.hatchPads[tostring(padIndex)] then
				local result = HatchService.collect(triggering, padIndex)
				if not result.ok then
					notify:FireClient(triggering, "warn", result.error)
				end
			else
				local result = HatchService.place(triggering, padIndex)
				if not result.ok then
					notify:FireClient(triggering, "warn", result.error)
				end
			end
		end)
	end

	local profile = DataService.get(player)
	local state = profile and profile.hatchPads[tostring(padIndex)]

	if state then
		prompt.ActionText = state.remaining > 0 and "Waiting..." or "Open!"
		prompt.ObjectText = state.rarity
		prompt.Enabled = state.remaining <= 0
	else
		prompt.ActionText = "Place Egg"
		prompt.ObjectText = "Hatch Pad"
		prompt.Enabled = CarryService.isCarrying(player)
	end
end

function HatchService.start()
	Net.handle("PlaceEgg", function(player, padIndex)
		return HatchService.place(player, padIndex)
	end)

	Net.handle("CollectHatch", function(player, padIndex)
		return HatchService.collect(player, padIndex)
	end)

	-- Catch up offline progress the moment a profile lands.
	DataService.ProfileLoaded:Connect(function(player, profile)
		if not Balance.Hatch.OFFLINE_PROGRESS then
			for key in profile.hatchPads do
				profile.hatchPads[key].lastTick = os.time()
			end
		end
		tickProfile(player, profile)

		task.defer(function()
			for i = 1, Balance.Hatch.PADS_PER_PLOT do
				renderPad(player, i)
				ensurePadPrompt(player, i)
			end
		end)
	end)

	-- One shared loop drives every pad's countdown and label.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local profile = DataService.get(player)
				if not profile then
					continue
				end

				tickProfile(player, profile)

				for i = 1, Balance.Hatch.PADS_PER_PLOT do
					local pad = PlotService.padFor(player, i)
					if not pad then
						continue
					end

					local state = profile.hatchPads[tostring(i)]
					if state then
						if pad:FindFirstChild("PadEgg") == nil then
							renderPad(player, i)
						end
						padLabel(
							pad,
							state.rarity,
							state.remaining > 0 and Format.duration(state.remaining) or "READY!",
							state.remaining > 0 and Rarity.get(state.rarity).glow or Color3.fromRGB(120, 255, 140)
						)
					end

					ensurePadPrompt(player, i)
				end
			end
		end
	end)
end

return HatchService
