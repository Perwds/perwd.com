--[[
	📍 LOCATION: ServerScriptService > Services > MuseumService (ModuleScript)

	Pocket Museum. Each player owns a plot with spots on the ground (no pedestals). YOU decide what goes there:

	  • Shrinking a mystery BOX in a zone puts it above your head.
	  • Inside your plot press F (or the 📦 Place button): the box is set on the ground at the free spot
	    nearest to you and starts opening
	    (time depends on box rarity / zone / variant, see GameConfig.Boxes).
	  • "Open now" on an opening box skips the wait for Gems.
	  • When it opens, a RANDOM object is rolled (SpawnService.RollContents: object, variant, SIZE),
	    appears on the pedestal and earns coins every second.
	  • "Pick up" (hold E) lifts the object above your head at its REAL size (bigger = bigger!).
	    Carry it to another pedestal and "Place" it, or keep it safe (others can steal what you
	    carry outside the safe zone). "Place" with empty hands puts your best pocket object there.
	  • "Equip Best" (right side of the screen) fills your pedestals with your best objects.

	data.Items  = every object you own: { U = uid, Id, V = variant, Z = size multiplier, S = stolen? }
	data.Slots  = ["pedestal#"] = { U = uid } | { Box = { R, T, V, ReadyAt } }  (old saves: Box = { Id, V, ReadyAt })
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local Remotes = require(Shared.Remotes)
local ModelFactory = require(ServerScriptService.Services.ModelFactory)

local MuseumService = {}
local Svc

local plotOf = {} -- [player] = plot record from MapService.Plots
local slots = {} -- [player] = { [i] = { Model = pedestalModel, Key = string? } }
local refreshQueued = {}

local COLS = 8
local SPACING_X = 7.6
local SPACING_Z = 7


function MuseumService.Init(registry)
	Svc = registry
end

-- ── helpers ─────────────────────────────────────────────────────────
local function findItem(data, uid)
	for i, item in ipairs(data.Items) do
		if item.U == uid then
			return item, i
		end
	end
	return nil
end

-- set of uids currently on a pedestal
local function slottedSet(data)
	local set = {}
	for _, slot in pairs(data.Slots) do
		if slot.U then
			set[slot.U] = true
		end
	end
	return set
end

-- clears any pedestal holding `uid` (used when that object is sold / fused away)
local function unslot(data, uid)
	for key, slot in pairs(data.Slots) do
		if slot.U == uid then
			data.Slots[key] = nil
		end
	end
end

local function pedestalCFrame(plot, i)
	local floor = plot.Floor
	local row = math.floor((i - 1) / COLS)
	local col = (i - 1) % COLS
	local x = (col - (COLS - 1) / 2) * SPACING_X
	local z = floor.Size.Z / 2 - 5 - row * SPACING_Z
	return floor.CFrame * CFrame.new(x, floor.Size.Y / 2, z)
end

-- Where slot i sits: your own spot if you placed it freely (slot.P = { x, z, yaw } on the plot floor),
-- otherwise the default grid.
local function slotCFrame(plot, i, slot)
	local p = slot and slot.P
	if p and type(p[1]) == "number" and type(p[2]) == "number" then
		local floor = plot.Floor
		return floor.CFrame * CFrame.new(p[1], floor.Size.Y / 2, p[2]) * CFrame.Angles(0, p[3] or 0, 0)
	end
	return pedestalCFrame(plot, i)
end

-- Free placement area on the plot floor (local coordinates): everything except the museum building at the back.
local PLACE_MARGIN = 2
local TEMPLE_DEPTH = 25
local MIN_SPACING = 3.6

-- ── pedestals ────────────────────────────────────────────────────────
local onPrompt -- forward declaration

local function makePedestal(player, plot, i)
	local model = Instance.new("Model")
	model.Name = "Pedestal_" .. i
	local origin = pedestalCFrame(plot, i)
	local function piece(name, size, offset, color, material, extra)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = origin * CFrame.new(offset)
		p.Color = color
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if extra then
			for k, v in pairs(extra) do
				p[k] = v
			end
		end
		p.Parent = model
		return p
	end
	-- No pedestal: just an invisible spot on the ground ("Base" is the PrimaryPart; things sit on top of it)
	-- plus a ring marker the owner sees while carrying something (Effects).
	local base = piece("Base", Vector3.new(4.2, 0.1, 4.2), Vector3.new(0, 0.05, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, { Transparency = 1, CanCollide = false, CanQuery = false })
	local marker = piece("Marker", Vector3.new(0.06, 3.8, 3.8), Vector3.new(0, 0.08, 0), Color3.fromRGB(120, 230, 255), Enum.Material.Neon, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	marker.Shape = Enum.PartType.Cylinder
	marker.CFrame = origin * CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.rad(90))
	model.PrimaryPart = base
	model:SetAttribute("PedestalSlot", i)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("OwnerName", player.DisplayName)
	model:SetAttribute("Income", 0)
	model:SetAttribute("State", "Empty")
	CollectionService:AddTag(model, "MuseumPedestal")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PedestalPrompt"
	prompt.ActionText = "Place"
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = base
	prompt.Triggered:Connect(function(who)
		if who == player then
			onPrompt(player, i)
		end
	end)
	-- second prompt on an opening box: open it right now with Robux (Instant Open product)
	local robux = Instance.new("ProximityPrompt")
	robux.Name = "RobuxOpenPrompt"
	robux.ActionText = "Open now (Robux)"
	robux.ObjectText = ""
	robux.HoldDuration = 0
	robux.MaxActivationDistance = 8
	robux.RequiresLineOfSight = false
	robux.KeyboardKeyCode = Enum.KeyCode.R
	robux.UIOffset = Vector2.new(0, 70)
	robux.Enabled = false
	robux.Parent = base
	robux.Triggered:Connect(function(who)
		if who == player then
			local s = Svc.Session.Get(player)
			if s then
				s.InstantOpenSlot = i
			end
			local r = Svc.Monetization.PromptProduct(player, "InstantOpen")
			if not r.ok and r.msg then
				Svc.Net.Notify(player, r.msg, "error")
			end
		end
	end)

	model.Parent = plot.Pedestals
	return model
end

local function setPrompt(pedestal, action, hold)
	local prompt = pedestal.PrimaryPart and pedestal.PrimaryPart:FindFirstChild("PedestalPrompt")
	if prompt then
		prompt.ActionText = action
		prompt.HoldDuration = hold or 0
	end
	local robux = pedestal.PrimaryPart and pedestal.PrimaryPart:FindFirstChild("RobuxOpenPrompt")
	if robux then
		robux.Enabled = action == "Open now" -- only while a box is opening
	end
end

-- Instant Open (Robux): opens the box the player picked (or their oldest opening box).
function MuseumService.InstantOpen(player)
	local data = Svc.Data.Get(player)
	local s = Svc.Session.Get(player)
	if not data then
		return
	end
	local key = s and s.InstantOpenSlot and tostring(s.InstantOpenSlot)
	local slot = key and data.Slots[key]
	if not (slot and slot.Box) then
		slot = nil
		for _, other in pairs(data.Slots) do
			if other.Box and (not slot or other.Box.ReadyAt < slot.Box.ReadyAt) then
				slot = other
			end
		end
	end
	if slot then
		slot.Box.ReadyAt = os.time()
		MuseumService.OpenReadyBoxes(player)
	end
end

local function yawOf(part)
	local look = part.CFrame.LookVector
	return math.atan2(-look.X, -look.Z)
end

-- Shows what's on a pedestal: nothing, an opening box, or the object.
local function setDisplay(pedestal, slot, data)
	local old = pedestal:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	pedestal:SetAttribute("ItemName", nil)
	pedestal:SetAttribute("Variant", nil)
	pedestal:SetAttribute("ItemUid", nil)
	pedestal:SetAttribute("ItemId", nil)
	pedestal:SetAttribute("BoxReadyAt", nil)
	pedestal:SetAttribute("BoxStartAt", nil)
	pedestal:SetAttribute("Weight", nil)
	pedestal:SetAttribute("SizeName", nil)
	pedestal:SetAttribute("BoxLuck", nil)
	pedestal:SetAttribute("Income", 0)
	local base = pedestal.PrimaryPart
	local top = base.Position + Vector3.new(0, base.Size.Y / 2, 0) -- right on the ground

	if slot and slot.Box then
		local box = ModelFactory.CreateBox(slot.Box)
		box.Name = "Display"
		ModelFactory.FitToSize(box, ModelFactory.BoxStuds(slot.Box))
		ModelFactory.SetCollision(box, false)
		ModelFactory.PlaceOnGround(box, top, yawOf(base))
		pedestal:SetAttribute("BoxLuck", slot.Box.L)
		pedestal:SetAttribute("SizeName", Formulas.SizeInfo(slot.Box.Z).Name)
		pedestal:SetAttribute("ItemName", Formulas.BoxName(slot.Box))
		box.Parent = pedestal
		pedestal:SetAttribute("State", "Box")
		pedestal:SetAttribute("BoxReadyAt", slot.Box.ReadyAt)
		pedestal:SetAttribute("BoxStartAt", slot.Box.StartAt or (slot.Box.ReadyAt - 60))
		setPrompt(pedestal, "Open now", 0)
		return
	end

	local item = slot and slot.U and findItem(data, slot.U)
	if item then
		local display = ModelFactory.Create(item.Id)
		display.Name = "Display"
		-- exactly as big as when you hold it (real size), standing where you put it
		ModelFactory.FitToSize(display, GameConfig.HoldBaseSize * (item.Z or 1))
		ModelFactory.Simplify(display, 0.06)
		ModelFactory.SetCollision(display, false)
		ModelFactory.PlaceOnGround(display, top, yawOf(base))
		ModelFactory.ApplyVariant(display, item.V, false)
		ModelFactory.ApplyMutation(display, item.M)
		display.Parent = pedestal
		pedestal:SetAttribute("State", "Item")
		pedestal:SetAttribute("ItemName", Formulas.ItemName(item))
		pedestal:SetAttribute("Variant", item.V)
		pedestal:SetAttribute("ItemUid", item.U)
		pedestal:SetAttribute("ItemId", item.Id)
		pedestal:SetAttribute("Weight", Formulas.FormatWeight(Formulas.ItemWeight(item)))
		pedestal:SetAttribute("SizeName", Formulas.SizeInfo(item.Z).Name)
		setPrompt(pedestal, "Pick up", 0.5)
		return
	end

	pedestal:SetAttribute("State", "Empty")
	setPrompt(pedestal, "Place", 0)
end

local function slotKey(slot)
	local pos = slot and slot.P and ("@" .. slot.P[1] .. "," .. slot.P[2]) or ""
	if not slot then
		return "E"
	elseif slot.Box then
		return "B|" .. tostring(slot.Box.R or slot.Box.Id) .. "|" .. tostring(slot.Box.V) .. "|" .. slot.Box.ReadyAt .. pos
	elseif slot.U then
		return "I|" .. slot.U .. pos
	end
	return "E"
end

-- ── income / state ───────────────────────────────────────────────────
-- Recomputes which objects are on display + base income. Cheap; call after any change.
function MuseumService.Recompute(player)
	local data = Svc.Data.Get(player)
	local s = Svc.Session.Get(player)
	if not data or not s then
		return
	end
	local stats = Formulas.RayStats(data, s.Passes)
	-- drop slots that point at objects you no longer own, or pedestals you no longer have
	for key, slot in pairs(data.Slots) do
		local index = tonumber(key)
		if not index or index > stats.Pedestals or (slot.U and not findItem(data, slot.U)) then
			if slot.Box and index then
				-- pedestal gone but the box isn't lost: it opens straight into your pocket
				local id, variant, size, mutation = Svc.Spawn.RollContents(player, slot.Box)
				MuseumService.AddItem(player, id, variant, { Z = size, M = mutation }, true)
			end
			data.Slots[key] = nil
		end
	end
	local displayed, base = {}, 0
	for i = 1, stats.Pedestals do
		local slot = data.Slots[tostring(i)]
		local item = slot and slot.U and findItem(data, slot.U)
		if item then
			table.insert(displayed, item)
			base += Formulas.ItemBaseIncome(item)
		end
	end
	s.Displayed = displayed
	s.PedestalCount = stats.Pedestals
	s.BaseIncome = base
	Svc.Economy.UpdateIncome(player)
	Svc.Data.MarkDirty(player)
	MuseumService.QueueRefresh(player)
end

function MuseumService.UpdateIncomeAttributes(player)
	local data = Svc.Data.Get(player)
	local mySlots = slots[player]
	if not data or not mySlots then
		return
	end
	local mult = Svc.Economy.GetIncomeMultiplier(player)
	for i, slotRec in pairs(mySlots) do
		local slot = data.Slots[tostring(i)]
		local item = slot and slot.U and findItem(data, slot.U)
		local income = item and Formulas.ItemBaseIncome(item) * mult or 0
		if slotRec.Model:GetAttribute("Income") ~= income then
			slotRec.Model:SetAttribute("Income", income)
		end
	end
end

local function refreshVisuals(player)
	local plot = plotOf[player]
	local s = Svc.Session.Get(player)
	local data = Svc.Data.Get(player)
	if not plot or not s or not data then
		return
	end
	local mySlots = slots[player]
	local count = s.PedestalCount or 0
	for i = 1, count do
		if not mySlots[i] then
			mySlots[i] = { Model = makePedestal(player, plot, i), Key = nil }
		end
	end
	for i, rec in pairs(mySlots) do
		if i > count then
			rec.Model:Destroy()
			mySlots[i] = nil
		end
	end
	for i = 1, count do
		local slot = data.Slots[tostring(i)]
		local key = slotKey(slot)
		local rec = mySlots[i]
		if rec.Key ~= key then
			rec.Key = key
			rec.Model:PivotTo(slotCFrame(plot, i, slot))
			local ok, err = pcall(setDisplay, rec.Model, slot, data)
			if not ok then
				rec.Key = nil -- try again on the next refresh
				warn("[MuseumService] can't show spot " .. i .. ": " .. tostring(err))
			end
		end
	end
	MuseumService.UpdateIncomeAttributes(player)
end

function MuseumService.QueueRefresh(player)
	if refreshQueued[player] then
		return
	end
	refreshQueued[player] = true
	task.delay(0.2, function()
		refreshQueued[player] = nil
		if player.Parent then
			refreshVisuals(player)
		end
	end)
end

-- Adds an object to the player's POCKET (rewards, raid copies, opened boxes...).
-- flags = { Stolen = bool, Z = size multiplier }. skipRecompute is used internally.
function MuseumService.AddItem(player, id, variant, flags, skipRecompute)
	local data = Svc.Data.Get(player)
	if not data or not ObjectConfig.Get(id) then
		return nil
	end
	variant = RarityConfig.Variants[variant] and variant or "Normal"
	local item = { U = data.NextUid, Id = id, V = variant }
	data.NextUid += 1
	if flags and flags.Stolen then
		item.S = true
	end
	if flags and flags.Z and flags.Z ~= 1 then
		item.Z = flags.Z
	end
	if flags and flags.M then
		item.M = flags.M
	end
	table.insert(data.Items, item)
	Svc.Index.Mark(player, id, variant)

	-- pocket overflow → auto-sell the lowest earner (never displayed, exclusive, or the new one)
	local slotted = slottedSet(data)
	while #data.Items > GameConfig.MaxItems do
		local worstIndex, worstIncome = nil, math.huge
		for i, it in ipairs(data.Items) do
			local def = ObjectConfig.Get(it.Id)
			if it ~= item and not slotted[it.U] and not (def and def.Exclusive) and not Svc.Carry.IsHolding(player, it.U) then
				local inc = Formulas.ItemBaseIncome(it)
				if inc < worstIncome then
					worstIndex, worstIncome = i, inc
				end
			end
		end
		if not worstIndex then
			break
		end
		table.remove(data.Items, worstIndex)
		Svc.Economy.AddCoins(player, worstIncome * Svc.Economy.GetIncomeMultiplier(player) * GameConfig.SellSeconds)
	end

	if not skipRecompute then
		MuseumService.Recompute(player)
	end
	return item
end

-- ── pedestal actions ─────────────────────────────────────────────────
local function pedestalModel(player, i)
	local rec = slots[player] and slots[player][i]
	return rec and rec.Model
end

local function bestPocketItem(player, data)
	local slotted = slottedSet(data)
	local best, bestIncome = nil, -1
	for _, item in ipairs(data.Items) do
		if not slotted[item.U] and not Svc.Carry.IsHolding(player, item.U) then
			local inc = Formulas.ItemBaseIncome(item)
			if inc > bestIncome then
				best, bestIncome = item, inc
			end
		end
	end
	return best
end

function onPrompt(player, i, placeAt)
	local data = Svc.Data.Get(player)
	local s = Svc.Session.Get(player)
	if not data or not s or not Svc.Session.Throttle(player, "pedestal", 0.25) then
		return
	end
	if i > (s.PedestalCount or 0) then
		return
	end
	local key = tostring(i)
	local slot = data.Slots[key]

	if not slot then
		-- EMPTY: place what's on top of your stack (box or held object), otherwise your best pocket object
		local entry = Svc.Carry.TakeTop(player)
		if entry and entry.Kind == "Box" then
			local box = entry.Box
			local seconds = Formulas.BoxOpenSeconds(box, data, Svc.Session.Get(player).Passes)
			if (data.Serums or 0) > 0 then
				-- a Mutation Serum from the Lab goes into this box
				data.Serums -= 1
				box.MB = math.max(box.MB or 1, GameConfig.Lab.SerumBoost)
				Svc.Net.Notify(player, "Mutation Serum used: this box is much more likely to mutate!", "success")
			end
			data.Slots[key] = { Box = { R = box.R, T = box.T, V = box.V, Z = box.Z, L = box.L, MB = box.MB, FM = box.FM, FMName = box.FMName, Id = box.Id, StartAt = os.time(), ReadyAt = os.time() + seconds }, P = placeAt }
			Remotes.Event("CarryFX"):FireClient(player, "Placed", { Seconds = seconds })
		elseif entry and entry.Kind == "Item" and findItem(data, entry.U) and not slottedSet(data)[entry.U] then
			data.Slots[key] = { U = entry.U, P = placeAt }
			Remotes.Event("CarryFX"):FireClient(player, "Placed", { Seconds = 0 })
		else
			local item = bestPocketItem(player, data)
			if not item then
				Svc.Net.Notify(player, "Shrink a box in the zones and bring it here!", "info")
				return
			end
			data.Slots[key] = { U = item.U, P = placeAt }
		end
		MuseumService.Recompute(player)
	elseif slot.Box then
		-- OPENING: skip the wait with Gems
		local left = slot.Box.ReadyAt - os.time()
		if left <= 0 then
			return
		end
		local cost = Formulas.BoxSkipGems(left)
		if not Svc.Economy.Spend(player, "Gems", cost) then
			Svc.Net.Notify(player, "Need " .. cost .. " Gems to open it now (" .. Format.Clock(left) .. " left)", "error")
			return
		end
		slot.Box.ReadyAt = os.time()
		MuseumService.OpenReadyBoxes(player)
	elseif slot.U then
		-- OBJECT: lift it above your head (real size!), or into your pocket if your hands are full
		local item = findItem(data, slot.U)
		data.Slots[key] = nil
		if item and Svc.Carry.Hold(player, item) then
			Svc.Net.Notify(player, "Holding your " .. Formulas.ItemName(item) .. " (" .. Formulas.FormatWeight(Formulas.ItemWeight(item)) .. ")", "info")
		else
			Svc.Net.Notify(player, "Hands full — put it in your pocket.", "info")
		end
		MuseumService.Recompute(player)
	end
end

-- Opens every box whose timer has run out (called every second and right after a skip).
function MuseumService.OpenReadyBoxes(player)
	local data = Svc.Data.Get(player)
	if not data then
		return
	end
	local now = os.time()
	local opened = false
	for key, slot in pairs(data.Slots) do
		if slot.Box and slot.Box.ReadyAt <= now then
			local id, rolledVariant, size, mutation = Svc.Spawn.RollContents(player, slot.Box)
			local item = MuseumService.AddItem(player, id, rolledVariant, { Z = size, M = mutation }, true)
			if item then
				data.Slots[key] = { U = item.U, P = slot.P } -- stays exactly where you put the box
				opened = true
				local pedestal = pedestalModel(player, tonumber(key))
				local income = Formulas.ItemBaseIncome(item) * Svc.Economy.GetIncomeMultiplier(player)
				Remotes.Event("BoxOpened"):FireAllClients(pedestal, player, Formulas.ItemName(item), item.V, income)
				local def = ObjectConfig.Get(item.Id)
				local variant = RarityConfig.GetVariant(item.V)
				local rarity = RarityConfig.GetRarity(def.Rarity)
				local mutationCfg = MutationConfig.Get(item.M)
				if variant.Order >= 4 or rarity.Order >= 6 or (item.Z or 1) >= 3 or (mutationCfg and mutationCfg.Mult >= 3) then
					Svc.Net.Announce("🎉 " .. player.DisplayName .. " unboxed a " .. Formulas.ItemName(item) .. "!", variant.Color or rarity.Color)
				end
			end
		end
	end
	if opened then
		MuseumService.Recompute(player)
	end
end

-- ── queries ──────────────────────────────────────────────────────────
function MuseumService.GetDisplayed(player)
	local s = Svc.Session.Get(player)
	return s and s.Displayed or {}
end

function MuseumService.GetPlot(player)
	return plotOf[player]
end

function MuseumService.GetPlotOwner(plotId)
	for player, plot in pairs(plotOf) do
		if plot.Id == plotId then
			return player
		end
	end
	return nil
end

-- Moves object `uid` from `from` to `to` (PvP steal). Returns the new item of `to`, or nil.
function MuseumService.TransferItem(from, to, uid)
	local fromData = Svc.Data.Get(from)
	if not fromData or not Svc.Data.Get(to) then
		return nil
	end
	local item, index = findItem(fromData, uid)
	if not item then
		return nil
	end
	local def = ObjectConfig.Get(item.Id)
	if def and def.Exclusive then
		return nil -- exclusives can't be stolen
	end
	table.remove(fromData.Items, index)
	unslot(fromData, uid)
	MuseumService.Recompute(from)
	return MuseumService.AddItem(to, item.Id, item.V, { Stolen = true, Z = item.Z, M = item.M })
end

function MuseumService.FindItem(player, uid)
	local data = Svc.Data.Get(player)
	return data and findItem(data, uid) or nil
end

-- Object on pedestal #slotIndex (used by raids), or nil.
function MuseumService.GetSlotItem(player, slotIndex)
	local data = Svc.Data.Get(player)
	local slot = data and data.Slots[tostring(slotIndex)]
	return slot and slot.U and findItem(data, slot.U) or nil
end

function MuseumService.TeleportHome(player)
	local plot = plotOf[player]
	local character = player.Character
	if plot and plot.SpawnPad and character then
		character:PivotTo(plot.SpawnPad.CFrame * CFrame.new(0, 4, 0)) -- faces the museum building
	end
end

local function setSign(plot, text)
	local building = plot.Building
	local sign = building and building:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
	local label = gui and gui:FindFirstChild("Label")
	if label then
		label.Text = text
	end
end

-- ── lifecycle ────────────────────────────────────────────────────────
function MuseumService.OnPlayerLoaded(player, data)
	local s = Svc.Session.Get(player)
	for _, plot in pairs(Svc.Map.Plots) do
		local taken = false
		for _, p in pairs(plotOf) do
			if p == plot then
				taken = true
				break
			end
		end
		if not taken then
			plotOf[player] = plot
			break
		end
	end
	slots[player] = {}

	-- one-time migration from the old "auto display" museum: put the best objects on pedestals
	if not data.SlotsMigrated then
		data.SlotsMigrated = true
		local stats = Formulas.RayStats(data, s.Passes)
		local sorted = Formulas.SortItems(data.Items)
		for i = 1, math.min(stats.Pedestals, #sorted) do
			data.Slots[tostring(i)] = { U = sorted[i].U }
		end
	end

	local plot = plotOf[player]
	if plot then
		s.Plot = plot.Id
		plot.Model:SetAttribute("OwnerUserId", player.UserId)
		if plot.Building then
			plot.Building:SetAttribute("OwnerUserId", player.UserId)
		end
		setSign(plot, player.DisplayName)
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			MuseumService.TeleportHome(player)
		end)
		if player.Character then
			MuseumService.TeleportHome(player)
		end
	else
		warn("[Museum] No free plot for " .. player.Name .. " (set Max Players <= GameConfig.PlotCount)")
	end
	MuseumService.OpenReadyBoxes(player) -- boxes keep opening while you're offline
	MuseumService.Recompute(player)
end

function MuseumService.OnPlayerRemoving(player)
	local plot = plotOf[player]
	if plot then
		plot.Pedestals:ClearAllChildren()
		plot.Model:SetAttribute("OwnerUserId", 0)
		if plot.Building then
			plot.Building:SetAttribute("OwnerUserId", 0)
		end
		setSign(plot, "")
	end
	plotOf[player] = nil
	slots[player] = nil
	refreshQueued[player] = nil
end

function MuseumService.Start()
	-- open boxes whose timers ran out
	task.spawn(function()
		while true do
			task.wait(1)
			for player in pairs(slots) do
				if player.Parent then
					MuseumService.OpenReadyBoxes(player)
				end
			end
		end
	end)

	Svc.Net.Handle("SellItem", function(player, uid)
		local data = Svc.Data.Get(player)
		if type(uid) ~= "number" then
			return { ok = false }
		end
		local item, index = findItem(data, uid)
		if not item then
			return { ok = false, msg = "Item not found" }
		end
		local def = ObjectConfig.Get(item.Id)
		if def and def.Exclusive then
			return { ok = false, msg = "Exclusive objects can't be sold!" }
		end
		table.remove(data.Items, index)
		unslot(data, uid)
		Svc.Carry.ForgetItem(player, uid)
		local coins = Formulas.ItemBaseIncome(item) * Svc.Economy.GetIncomeMultiplier(player) * GameConfig.SellSeconds
		Svc.Economy.AddCoins(player, coins)
		MuseumService.Recompute(player)
		return { ok = true, msg = "Sold for " .. Format.Coins(coins) }
	end)

	-- FUSE: GameConfig.Fuse.Count identical objects (same id + variant) → 1 of the next variant (into your pocket)
	Svc.Net.Handle("FuseItems", function(player, id, variant)
		local data = Svc.Data.Get(player)
		if type(id) ~= "string" or type(variant) ~= "string" or not RarityConfig.Variants[variant] then
			return { ok = false }
		end
		local nextVariant
		for i, v in ipairs(RarityConfig.VariantOrder) do
			if v == variant then
				nextVariant = RarityConfig.VariantOrder[i + 1]
			end
		end
		if not nextVariant then
			return { ok = false, msg = "Cosmic is already the best variant!" }
		end
		local need = GameConfig.Fuse.Count
		local slotted = slottedSet(data)
		local pocket, shown = {}, {}
		for _, item in ipairs(data.Items) do
			if item.Id == id and item.V == variant then
				table.insert(slotted[item.U] and shown or pocket, item.U)
			end
		end
		if #pocket + #shown < need then
			return { ok = false, msg = string.format("Need %d to fuse (you have %d)", need, #pocket + #shown) }
		end
		-- use pocket copies first, then displayed ones
		local remove = {}
		for _, uid in ipairs(pocket) do
			if #remove < need then
				table.insert(remove, uid)
			end
		end
		for _, uid in ipairs(shown) do
			if #remove < need then
				table.insert(remove, uid)
			end
		end
		local sizeSum, bestMutation = 0, nil
		for _, uid in ipairs(remove) do
			local old, index = findItem(data, uid)
			if index then
				sizeSum += old.Z or 1
				local m = MutationConfig.Get(old.M)
				if m and (not bestMutation or m.Mult > MutationConfig.Get(bestMutation).Mult) then
					bestMutation = old.M -- the best mutation survives the fuse
				end
				table.remove(data.Items, index)
			end
			unslot(data, uid)
			Svc.Carry.ForgetItem(player, uid)
		end
		-- the fused object is as big as the average of the three
		local item = MuseumService.AddItem(player, id, nextVariant, { Z = Formulas.SizeInfo(sizeSum / #remove).Mult, M = bestMutation })
		return { ok = true, msg = "Fused into " .. Formulas.ItemName(item) .. "! (in your pocket)" }
	end)

	-- SELL ALL: sells every pocket object that is NOT on a pedestal (exclusives are kept)
	Svc.Net.Handle("SellPocket", function(player)
		local data = Svc.Data.Get(player)
		local slotted = slottedSet(data)
		local kept, total, count = {}, 0, 0
		local mult = Svc.Economy.GetIncomeMultiplier(player)
		for _, item in ipairs(data.Items) do
			local def = ObjectConfig.Get(item.Id)
			if slotted[item.U] or (def and def.Exclusive) or Svc.Carry.IsHolding(player, item.U) then
				table.insert(kept, item)
			else
				total += Formulas.ItemBaseIncome(item) * mult * GameConfig.SellSeconds
				count += 1
			end
		end
		if count == 0 then
			return { ok = false, msg = "Nothing to sell — everything is on display!" }
		end
		data.Items = kept
		Svc.Economy.AddCoins(player, total)
		MuseumService.Recompute(player)
		return { ok = true, msg = string.format("Sold %d object%s for %s", count, count == 1 and "" or "s", Format.Coins(total)) }
	end)

	-- EQUIP BEST: fills every pedestal that isn't opening a box with your best objects
	Svc.Net.Handle("EquipBest", function(player)
		local data = Svc.Data.Get(player)
		local s = Svc.Session.Get(player)
		if not data or not s or not Svc.Session.Throttle(player, "equipbest", 1) then
			return { ok = false }
		end
		local candidates = {}
		for _, item in ipairs(data.Items) do
			if not Svc.Carry.IsHolding(player, item.U) then
				table.insert(candidates, item)
			end
		end
		table.sort(candidates, function(a, b)
			return Formulas.ItemBaseIncome(a) > Formulas.ItemBaseIncome(b)
		end)
		local freeSlots, keepPos = {}, {}
		for i = 1, s.PedestalCount or 0 do
			local slot = data.Slots[tostring(i)]
			if not (slot and slot.Box) then
				keepPos[i] = slot and slot.P -- objects you placed yourself stay where they were
				data.Slots[tostring(i)] = nil
				table.insert(freeSlots, i)
			end
		end
		local placed = 0
		for i, index in ipairs(freeSlots) do
			local item = candidates[i]
			if not item then
				break
			end
			data.Slots[tostring(index)] = { U = item.U, P = keepPos[index] }
			placed += 1
		end
		MuseumService.Recompute(player)
		return { ok = true, msg = placed > 0 and ("Equipped your best " .. placed .. " object" .. (placed == 1 and "" or "s") .. "!") or "Nothing to equip yet!" }
	end)

	-- Inventory: put one item from your pocket into your plot (first free spot) / take it back out
	Svc.Net.Handle("PlaceItem", function(player, uid)
		local data = Svc.Data.Get(player)
		local s = Svc.Session.Get(player)
		if not data or not s or type(uid) ~= "number" or not Svc.Session.Throttle(player, "placeitem", 0.25) then
			return { ok = false }
		end
		local item
		for _, it in ipairs(data.Items) do
			if it.U == uid then
				item = it
			end
		end
		if not item then
			return { ok = false, msg = "You don't have that item." }
		end
		if Svc.Carry.IsHolding(player, uid) then
			return { ok = false, msg = "You're holding that one!" }
		end
		for _, slot in pairs(data.Slots) do
			if slot.U == uid then
				return { ok = false, msg = "It's already in your plot." }
			end
		end
		for i = 1, s.PedestalCount or 0 do
			if not data.Slots[tostring(i)] then
				data.Slots[tostring(i)] = { U = uid }
				MuseumService.Recompute(player)
				return { ok = true, msg = "Placed " .. Formulas.ItemName(item) .. "!" }
			end
		end
		return { ok = false, msg = "Your plot is full! Unplace something or upgrade Museum Size." }
	end)

	Svc.Net.Handle("UnplaceItem", function(player, uid)
		local data = Svc.Data.Get(player)
		if not data or type(uid) ~= "number" or not Svc.Session.Throttle(player, "placeitem", 0.25) then
			return { ok = false }
		end
		for key, slot in pairs(data.Slots) do
			if slot.U == uid then
				data.Slots[key] = nil
				MuseumService.Recompute(player)
				return { ok = true }
			end
		end
		return { ok = false, msg = "That item isn't in your plot." }
	end)

	-- PLACE ANYWHERE (F key / Place button): puts what you carry exactly where you aim (or in front of you),
	-- anywhere on your plot's floor except inside the museum building.
	Svc.Net.Handle("PlaceGround", function(player, target)
		local plot = plotOf[player]
		local s = Svc.Session.Get(player)
		local data = Svc.Data.Get(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not plot or not s or not data or not root then
			return { ok = false }
		end
		if not Svc.Map.IsInPart(plot.Floor, root.Position) then
			return { ok = false, msg = "Go inside YOUR plot to put things down!" }
		end
		if not Svc.Carry.IsCarrying(player) then
			return { ok = false, msg = "You're not carrying anything." }
		end
		local floor = plot.Floor
		-- where: the aimed point (if it's close and on your floor) or 4 studs in front of you
		local world = root.Position + root.CFrame.LookVector * 4
		if typeof(target) == "Vector3" and (target - root.Position).Magnitude <= 30 then
			world = target
		end
		local rel = floor.CFrame:PointToObjectSpace(world)
		local hw, hd = floor.Size.X / 2 - PLACE_MARGIN, floor.Size.Z / 2 - PLACE_MARGIN
		local x = math.clamp(rel.X, -hw, hw)
		local z = math.clamp(rel.Z, -floor.Size.Z / 2 + TEMPLE_DEPTH, hd)
		-- not on top of something else
		for i = 1, s.PedestalCount or 0 do
			local other = data.Slots[tostring(i)]
			if other then
				local o = floor.CFrame:PointToObjectSpace(slotCFrame(plot, i, other).Position)
				if (Vector3.new(o.X - x, 0, o.Z - z)).Magnitude < MIN_SPACING then
					return { ok = false, msg = "Too close to another object — move a little!" }
				end
			end
		end
		local free
		for i = 1, s.PedestalCount or 0 do
			if not data.Slots[tostring(i)] then
				free = i
				break
			end
		end
		if not free then
			return { ok = false, msg = "Your plot is full! Upgrade Museum Size or sell something." }
		end
		-- face the player who put it down
		local toPlayer = floor.CFrame:PointToObjectSpace(root.Position) - Vector3.new(x, 0, z)
		local yaw = math.atan2(-toPlayer.X, -toPlayer.Z)
		onPrompt(player, free, { math.floor(x * 10) / 10, math.floor(z * 10) / 10, math.floor(yaw * 100) / 100 })
		return { ok = true }
	end)

	Svc.Net.Handle("TeleportMuseum", function(player)
		if not Svc.Session.Throttle(player, "tp", 2) then
			return { ok = false, msg = "Slow down!" }
		end
		if Svc.Carry.IsCarrying(player) then
			return { ok = false, msg = "No teleporting while carrying loot — run it home!" }
		end
		MuseumService.TeleportHome(player)
		return { ok = true }
	end)

	Svc.Data.AddSyncProvider(function(player, payload)
		local s = Svc.Session.Get(player)
		local data = Svc.Data.Get(player)
		payload.PlotId = s and s.Plot or nil
		local uids = {}
		local boxes = 0
		if data then
			for _, slot in pairs(data.Slots) do
				if slot.U then
					table.insert(uids, slot.U)
				elseif slot.Box then
					boxes += 1
				end
			end
		end
		payload.DisplayedUids = uids
		payload.OpeningBoxes = boxes
	end)
end

return MuseumService
