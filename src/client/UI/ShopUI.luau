--[[
	The egg shop.

	Featured limited eggs sit at the top with their full drop table and Robux
	bundles; world eggs below are bought with cash. A bought egg attaches to
	your back the same as a stolen one, so the walk home is still a risk.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Eggs = require(ReplicatedStorage.Shared.Config.Eggs)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Worlds = require(ReplicatedStorage.Shared.Config.Worlds)

local Builder = require(script.Parent.Builder)
local Notify = require(script.Parent.Notify)
local Panel = require(script.Parent.Panel)
local PetViewport = require(script.Parent.PetViewport)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)

local ShopUI = {}

local panel
local refs = {}
local serverStart = os.time()

--- One drop-chance chip: the pet silhouette plus its percentage.
local function dropChip(parent: Instance, egg, entry, order: number)
	local pet = Pets.get(entry.petId)
	if not pet then
		return
	end

	local known = false
	for _, worldEntry in State.data.index.worlds do
		for _, slot in worldEntry.slots do
			if slot.id == pet.id and slot.known then
				known = true
			end
		end
	end
	for _, slot in State.data.index.limited do
		if slot.id == pet.id and slot.known then
			known = true
		end
	end

	local tile = PetViewport.tile(pet.id, pet.rarity, known, {
		Size = UDim2.fromOffset(78, 90),
		LayoutOrder = order,
		Parent = parent,
	})

	Builder.label(Format.percent(Eggs.chanceOf(egg, entry.petId) / 100), {
		Name = "Chance",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, -6, 0, 20),
		ZIndex = 5,
		TextColor3 = Rarity.get(pet.rarity).glow,
		Parent = tile,
	})
end

local function featuredCard(parent: Instance, egg, order: number)
	local card = Builder.frame({
		Name = egg.id,
		Size = UDim2.new(1, 0, 0, 260),
		BackgroundColor3 = egg.color or Theme.Color.panelInset,
		LayoutOrder = order,
		Parent = parent,
	}, {
		Builder.stroke(3, Theme.Color.gold),
		Builder.gradient(egg.color or Theme.Color.panel, Theme.Color.panelDeep, 70),
	})

	Builder.label("New!", {
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(70, 28),
		BackgroundColor3 = Theme.Color.red,
		BackgroundTransparency = 0,
		Parent = card,
	})

	Builder.label(egg.name:upper(), {
		Position = UDim2.fromOffset(92, 8),
		Size = UDim2.new(0.5, 0, 0, 34),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Color.gold,
		Parent = card,
	})

	local timer = Builder.label("", {
		Name = "Timer",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(240, 32),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = card,
	})
	refs.timers[egg.id] = { label = timer, egg = egg }

	-- Drop table.
	local drops = Builder.make("Frame", {
		Name = "Drops",
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.new(1, -24, 0, 96),
		BackgroundTransparency = 1,
		Parent = card,
	}, { Builder.grid(UDim2.fromOffset(78, 90), { CellPadding = UDim2.fromOffset(6, 6) }) })

	local sorted = table.clone(egg.pool)
	table.sort(sorted, function(a, b)
		return a.weight > b.weight
	end)
	for order2, entry in sorted do
		dropChip(drops, egg, entry, order2)
	end

	-- Robux bundles.
	local bundles = Builder.make("Frame", {
		Name = "Bundles",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(1, -24, 0, 72),
		BackgroundTransparency = 1,
		Parent = card,
	}, {
		Builder.list({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
	})

	for order2, bundle in egg.bundles or {} do
		local button = Builder.button(`R$ {bundle.robux}`, {
			Size = UDim2.fromOffset(150, 52),
			BackgroundColor3 = order2 == 1 and Theme.Color.red or Theme.Color.green,
			LayoutOrder = order2,
			Parent = bundles,
		}, function()
			-- Wired once you fill ShopService.PRODUCTS with real product ids.
			local productId = bundle.productId
			if not productId then
				Notify.push("warn", "This bundle is not live yet")
				return
			end
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
		end)

		Builder.label(`{bundle.amount} Egg{bundle.amount > 1 and "s" or ""}`, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(1, 0, 0, 16),
			TextScaled = true,
			Parent = button,
		})
	end
end

local function worldRow(parent: Instance, egg, order: number)
	local info = Worlds.get(egg.world)
	local unlocked = State.data.worlds[egg.world] == true
	local affordable = State.data.cash >= (egg.cost or math.huge)

	local row = Builder.frame({
		Name = egg.id,
		Size = UDim2.new(1, 0, 0, 108),
		BackgroundColor3 = Theme.Color.panelInset,
		LayoutOrder = order,
		Parent = parent,
	})

	Builder.label(egg.name, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(0.4, 0, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = unlocked and Theme.Color.text or Theme.Color.textDim,
		Parent = row,
	})

	Builder.label(`Hatches in {Format.duration(egg.hatchTime)}`, {
		Position = UDim2.fromOffset(12, 38),
		Size = UDim2.new(0.4, 0, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 16,
		Font = Theme.Font.body,
		TextColor3 = Theme.Color.textDim,
		Parent = row,
	})

	-- Best three drops as a teaser.
	local drops = Builder.make("Frame", {
		Position = UDim2.new(0.42, 0, 0, 10),
		Size = UDim2.new(0.3, 0, 0, 88),
		BackgroundTransparency = 1,
		Parent = row,
	}, {
		Builder.list({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
		}),
	})

	local sorted = table.clone(egg.pool)
	table.sort(sorted, function(a, b)
		return a.weight < b.weight
	end)
	local indexEntry = State.indexForWorld(egg.world)
	for i = 1, math.min(3, #sorted) do
		local pet = Pets.get(sorted[i].petId)
		if not pet then
			continue
		end
		local known = false
		if indexEntry then
			for _, slot in indexEntry.slots do
				if slot.id == pet.id then
					known = slot.known
				end
			end
		end
		local tile = PetViewport.tile(pet.id, pet.rarity, known, {
			Size = UDim2.fromOffset(72, 84),
			LayoutOrder = i,
			Parent = drops,
		})
		Builder.label(Format.percent(Eggs.chanceOf(egg, pet.id) / 100), {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -2),
			Size = UDim2.new(1, -6, 0, 18),
			ZIndex = 5,
			Parent = tile,
		})
	end

	local buy = Builder.button(Format.abbreviate(egg.cost or 0), {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(150, 54),
		BackgroundColor3 = (unlocked and affordable) and Theme.Color.green or Theme.Color.grey,
		Parent = row,
	}, function()
		if not unlocked then
			Notify.push("warn", `Unlock {info.display} first`)
			return
		end
		local result = Net.Function("BuyEgg"):InvokeServer(egg.id)
		if result and result.ok then
			Notify.push("success", `Bought a {egg.name}! Carry it to a hatch pad.`)
			State.request()
		elseif result then
			Notify.push("warn", result.error or "Could not buy")
		end
	end)

	if not unlocked then
		buy.Text = "LOCKED"
	end
end

local function render()
	-- Clearing the scroller drops its layout and padding too, so both are
	-- rebuilt here rather than once at construction.
	refs.list:ClearAllChildren()
	refs.timers = {}
	Builder.padding(10).Parent = refs.list
	Builder.list({ Padding = UDim.new(0, 10), Parent = refs.list })

	local order = 0

	Builder.label("-- FEATURED --", {
		Size = UDim2.new(1, 0, 0, 32),
		TextColor3 = Theme.Color.gold,
		LayoutOrder = 0,
		Parent = refs.list,
	})

	for _, egg in Eggs.List do
		if egg.featured then
			order += 1
			featuredCard(refs.list, egg, order)
		end
	end

	Builder.label("-- EGGS --", {
		Size = UDim2.new(1, 0, 0, 32),
		TextColor3 = Theme.Color.headerGreen,
		LayoutOrder = 500,
		Parent = refs.list,
	})

	for _, world in Worlds.Order do
		local egg = Eggs.forWorld(world)
		if egg then
			order += 1
			worldRow(refs.list, egg, 500 + order)
		end
	end
end

function ShopUI.build(screen: ScreenGui)
	refs.timers = {}

	panel = Panel.new({
		name = "Shop",
		title = "Shop",
		size = UDim2.fromOffset(900, 560),
		headerColor = Theme.Color.headerGreen,
		parent = screen,
	})

	refs.list = Builder.scroller({ Parent = panel.body })

	panel.onOpen = render
	State.fullChanged:Connect(function()
		if panel.isOpen then
			render()
		end
	end)

	-- Limited-egg countdowns.
	task.spawn(function()
		while true do
			task.wait(1)
			if not panel.isOpen then
				continue
			end
			for _, entry in refs.timers do
				local duration = entry.egg.durationSeconds
				if duration then
					local remaining = math.max(0, serverStart + duration - os.time())
					entry.label.Text = Format.duration(remaining)
				end
			end
		end
	end)

	return panel
end

function ShopUI.toggle()
	if panel then
		panel:toggle()
	end
end

function ShopUI.open()
	if panel then
		panel:open()
	end
end

return ShopUI
