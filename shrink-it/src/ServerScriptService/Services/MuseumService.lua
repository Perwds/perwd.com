--[[
	📍 LOCATION: ServerScriptService > Services > MuseumService (ModuleScript)

	Pocket Museum: each player owns a plot. Their best N items (N = pedestal count)
	are displayed on pedestals inside glass cases and earn coins every second.
	Extra items wait in the "pocket" (up to GameConfig.MaxItems).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ObjectConfig = require(Shared.Config.ObjectConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Formulas = require(Shared.Formulas)
local Format = require(Shared.Format)
local ModelFactory = require(ServerScriptService.Services.ModelFactory)

local MuseumService = {}
local Svc

local plotOf = {} -- [player] = plot record from MapService.Plots
local slots = {} -- [player] = { [i] = { Model = pedestalModel, Uid = number? } }
local refreshQueued = {}

local COLS = 10
local SPACING_X = 12
local SPACING_Z = 10

function MuseumService.Init(registry)
	Svc = registry
end

local function pedestalCFrame(plot, i)
	local floor = plot.Floor
	local row = math.floor((i - 1) / COLS)
	local col = (i - 1) % COLS
	local x = (col - (COLS - 1) / 2) * SPACING_X
	local z = floor.Size.Z / 2 - 10 - row * SPACING_Z
	return floor.CFrame * CFrame.new(x, floor.Size.Y / 2, z)
end

local function makePedestal(player, plot, i)
	local model = Instance.new("Model")
	model.Name = "Pedestal_" .. i
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Anchored = true
	base.Size = Vector3.new(5, 2.4, 5)
	base.Material = Enum.Material.Marble
	base.Color = Color3.fromRGB(245, 245, 250)
	base.CFrame = pedestalCFrame(plot, i) * CFrame.new(0, 1.2, 0)
	base.Parent = model
	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Anchored = true
	trim.CanCollide = false
	trim.Size = Vector3.new(5.3, 0.3, 5.3)
	trim.Material = Enum.Material.Neon
	trim.Color = Color3.fromRGB(90, 200, 255)
	trim.CFrame = base.CFrame * CFrame.new(0, 1.05, 0)
	trim.Parent = model
	local glass = Instance.new("Part")
	glass.Name = "Glass"
	glass.Anchored = true
	glass.CanCollide = false
	glass.Size = Vector3.new(4.6, 4.6, 4.6)
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.8
	glass.Color = Color3.fromRGB(200, 240, 255)
	glass.CFrame = base.CFrame * CFrame.new(0, 1.2 + 2.3, 0)
	glass.Parent = model
	model.PrimaryPart = base
	model:SetAttribute("PedestalSlot", i)
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("Income", 0)
	CollectionService:AddTag(model, "MuseumPedestal")
	model.Parent = plot.Pedestals
	return model
end

local function setDisplay(pedestal, item)
	local old = pedestal:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	if not item then
		pedestal:SetAttribute("ItemName", nil)
		pedestal:SetAttribute("Variant", nil)
		pedestal:SetAttribute("ItemUid", nil)
		pedestal:SetAttribute("Income", 0)
		return
	end
	local display = ModelFactory.Create(item.Id)
	display.Name = "Display"
	ModelFactory.FitToSize(display, GameConfig.DisplayMaxSize)
	ModelFactory.SetCollision(display, false)
	local base = pedestal.PrimaryPart
	ModelFactory.PlaceOnGround(display, base.Position + Vector3.new(0, base.Size.Y / 2 + 0.3, 0), math.rad(-20))
	ModelFactory.ApplyVariant(display, item.V, false)
	display.Parent = pedestal
	pedestal:SetAttribute("ItemName", Formulas.ItemName(item))
	pedestal:SetAttribute("Variant", item.V)
	pedestal:SetAttribute("ItemUid", item.U)
	pedestal:SetAttribute("ItemId", item.Id)
end

-- Recomputes which items are displayed + base income. Cheap; call after any item change.
function MuseumService.Recompute(player)
	local data = Svc.Data.Get(player)
	local s = Svc.Session.Get(player)
	if not data or not s then
		return
	end
	local stats = Formulas.RayStats(data, s.Passes)
	local sorted = Formulas.SortItems(data.Items)
	local displayed = {}
	local base = 0
	for i = 1, math.min(stats.Pedestals, #sorted) do
		displayed[i] = sorted[i]
		base += Formulas.ItemBaseIncome(sorted[i])
	end
	s.Displayed = displayed
	s.PedestalCount = stats.Pedestals
	s.BaseIncome = base
	Svc.Economy.UpdateIncome(player)
	Svc.Data.MarkDirty(player)
	MuseumService.QueueRefresh(player)
end

function MuseumService.UpdateIncomeAttributes(player)
	local s = Svc.Session.Get(player)
	local mySlots = slots[player]
	if not s or not mySlots or not s.Displayed then
		return
	end
	local mult = Svc.Economy.GetIncomeMultiplier(player)
	for i, slot in pairs(mySlots) do
		local item = s.Displayed[i]
		local income = item and Formulas.ItemBaseIncome(item) * mult or 0
		if slot.Model:GetAttribute("Income") ~= income then
			slot.Model:SetAttribute("Income", income)
		end
	end
end

local function refreshVisuals(player)
	local plot = plotOf[player]
	local s = Svc.Session.Get(player)
	if not plot or not s or not s.Displayed then
		return
	end
	local mySlots = slots[player]
	local count = s.PedestalCount or 0
	-- create / remove pedestals
	for i = 1, count do
		if not mySlots[i] then
			mySlots[i] = { Model = makePedestal(player, plot, i), Uid = nil }
		end
	end
	for i, slot in pairs(mySlots) do
		if i > count then
			slot.Model:Destroy()
			mySlots[i] = nil
		end
	end
	-- update displays only where the item changed
	for i = 1, count do
		local item = s.Displayed[i]
		local slot = mySlots[i]
		local uid = item and item.U or nil
		if slot.Uid ~= uid then
			slot.Uid = uid
			setDisplay(slot.Model, item)
		end
	end
	MuseumService.UpdateIncomeAttributes(player)
end

function MuseumService.QueueRefresh(player)
	if refreshQueued[player] then
		return
	end
	refreshQueued[player] = true
	task.delay(0.3, function()
		refreshQueued[player] = nil
		if player.Parent then
			refreshVisuals(player)
		end
	end)
end

-- Adds an item to the player's collection. flags = { Stolen = bool }
function MuseumService.AddItem(player, id, variant, flags)
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
	table.insert(data.Items, item)
	Svc.Index.Mark(player, id, variant)

	-- pocket overflow → auto-sell the lowest earner (never exclusives, never the new item)
	while #data.Items > GameConfig.MaxItems do
		local worstIndex, worstIncome = nil, math.huge
		for i, it in ipairs(data.Items) do
			local def = ObjectConfig.Get(it.Id)
			if it ~= item and not (def and def.Exclusive) then
				local inc = Formulas.ItemBaseIncome(it)
				if inc < worstIncome then
					worstIndex, worstIncome = i, inc
				end
			end
		end
		if not worstIndex then
			break
		end
		local sold = table.remove(data.Items, worstIndex)
		local coins = worstIncome * Svc.Economy.GetIncomeMultiplier(player) * GameConfig.SellSeconds
		Svc.Economy.AddCoins(player, coins)
		Svc.Net.Notify(player, "Pocket full! Auto-sold " .. Formulas.ItemName(sold) .. " for " .. Format.Coins(coins), "info")
	end

	MuseumService.Recompute(player)
	return item
end

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

function MuseumService.GetSlotItem(player, slotIndex)
	local s = Svc.Session.Get(player)
	return s and s.Displayed and s.Displayed[slotIndex] or nil
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

function MuseumService.OnPlayerLoaded(player)
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
	local plot = plotOf[player]
	if plot then
		s.Plot = plot.Id
		plot.Model:SetAttribute("OwnerUserId", player.UserId)
		if plot.Building then
			plot.Building:SetAttribute("OwnerUserId", player.UserId)
		end
		setSign(plot, player.DisplayName .. "'s Museum")
		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			MuseumService.TeleportHome(player)
		end)
		if player.Character then
			MuseumService.TeleportHome(player)
		end
	else
		warn("[Museum] No free plot for " .. player.Name .. " (increase GameConfig.PlotCount / build more plots, and set Players.MaxPlayers <= plots)")
	end
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
		setSign(plot, "Empty Plot")
	end
	plotOf[player] = nil
	slots[player] = nil
	refreshQueued[player] = nil
end

function MuseumService.Start()
	Svc.Net.Handle("SellItem", function(player, uid)
		local data = Svc.Data.Get(player)
		if type(uid) ~= "number" then
			return { ok = false }
		end
		for i, item in ipairs(data.Items) do
			if item.U == uid then
				local def = ObjectConfig.Get(item.Id)
				if def and def.Exclusive then
					return { ok = false, msg = "Exclusive objects can't be sold!" }
				end
				table.remove(data.Items, i)
				local coins = Formulas.ItemBaseIncome(item) * Svc.Economy.GetIncomeMultiplier(player) * GameConfig.SellSeconds
				Svc.Economy.AddCoins(player, coins)
				MuseumService.Recompute(player)
				return { ok = true, msg = "Sold for " .. Format.Coins(coins) }
			end
		end
		return { ok = false, msg = "Item not found" }
	end)

	Svc.Net.Handle("TeleportMuseum", function(player)
		if not Svc.Session.Throttle(player, "tp", 2) then
			return { ok = false, msg = "Slow down!" }
		end
		MuseumService.TeleportHome(player)
		return { ok = true }
	end)

	Svc.Data.AddSyncProvider(function(player, payload)
		local s = Svc.Session.Get(player)
		payload.PlotId = s and s.Plot or nil
		local uids = {}
		if s and s.Displayed then
			for _, item in ipairs(s.Displayed) do
				table.insert(uids, item.U)
			end
		end
		payload.DisplayedUids = uids
	end)
end

return MuseumService
