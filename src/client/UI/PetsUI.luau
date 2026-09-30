--[[
	Inventory, and the two things you do with it: sell and fuse.

	One panel with three modes rather than three panels, because the selection
	model is identical in all of them -- tap pets, then act. `mode` only
	changes which pets are selectable and what the footer button does.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Config.Balance)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)

local Builder = require(script.Parent.Builder)
local Notify = require(script.Parent.Notify)
local Panel = require(script.Parent.Panel)
local PetViewport = require(script.Parent.PetViewport)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)

local PetsUI = {}

local panel
local refs = {}
local mode = "equip" -- equip | sell | fuse
local selected: { [string]: boolean } = {}

local MODE_TITLE = { equip = "My Pets", sell = "Sell Pets", fuse = "Fuse Machine" }

local function selectedList(): { string }
	local out = {}
	for uid, isOn in selected do
		if isOn then
			table.insert(out, uid)
		end
	end
	return out
end

local function selectionValue(): number
	local total = 0
	for _, pet in State.data.pets do
		if selected[pet.uid] then
			total += pet.income * Balance.Sell.INCOME_MULTIPLE
		end
	end
	return total
end

--- Sell protects equipped and locked pets; fuse needs a matching rarity.
local function isSelectable(pet): (boolean, string?)
	if mode == "equip" then
		return true
	end
	if pet.locked then
		return false, "Locked"
	end
	if mode == "sell" then
		if Balance.Sell.PROTECT_EQUIPPED and pet.equipped then
			return false, "Equipped"
		end
		return true
	end
	if mode == "fuse" then
		if pet.equipped then
			return false, "Equipped"
		end
		-- Once one is picked, only the same rarity stays selectable.
		for uid, isOn in selected do
			if isOn and uid ~= pet.uid then
				for _, other in State.data.pets do
					if other.uid == uid and other.rarity ~= pet.rarity then
						return false, "Rarity"
					end
				end
			end
		end
		if pet.rarity == Rarity.Order[#Rarity.Order] then
			return false, "Max"
		end
		return true
	end
	return true
end

local function refreshFooter()
	local count = #selectedList()

	if mode == "equip" then
		refs.footerText.Text = `Equipped {#State.data.equipped}/{State.data.limits.equip}`
			.. `   ·   {Format.abbreviate(State.data.income)}/s`
		refs.actionButton.Visible = false
	elseif mode == "sell" then
		refs.footerText.Text = `{count} selected   ·   {Format.abbreviate(selectionValue())}`
		refs.actionButton.Visible = true
		refs.actionButton.Text = count > 0 and `SELL {count}` or "SELL"
		refs.actionButton.BackgroundColor3 = count > 0 and Theme.Color.red or Theme.Color.grey
	else
		local needed = State.data.limits.fuseInputs
		refs.footerText.Text = `Fuse Machine {count}/{needed}`
			.. `   ·   {math.floor(Balance.Fuse.UPGRADE_CHANCE * 100)}% to tier up`
		refs.actionButton.Visible = true
		refs.actionButton.Text = "FUSE"
		refs.actionButton.BackgroundColor3 = count == needed and Theme.Color.headerPurple or Theme.Color.grey
	end
end

local render

local function petCard(pet, order: number)
	local selectable, reason = isSelectable(pet)
	local isSelected = selected[pet.uid] == true

	local tile = PetViewport.tile(pet.id, pet.rarity, true, {
		Name = pet.uid,
		Size = UDim2.fromOffset(120, 148),
		LayoutOrder = order,
		Parent = refs.grid,
	})

	if isSelected then
		local stroke = tile:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			stroke.Color = Theme.Color.gold
			stroke.Thickness = 5
		end
	elseif not selectable then
		Builder.make("Frame", {
			Name = "Dim",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.6,
			Size = UDim2.fromScale(1, 1),
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = tile,
		}, { Builder.corner() })
	end

	Builder.label(pet.shiny and `* {pet.name}` or pet.name, {
		Name = "Name",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		Size = UDim2.new(1, -8, 0, 20),
		TextScaled = false,
		TextSize = 14,
		Font = Theme.Font.body,
		ZIndex = 7,
		TextColor3 = pet.shiny and Theme.Color.gold or Theme.Color.text,
		Parent = tile,
	})

	Builder.label(`{Format.abbreviate(pet.income)}/s`, {
		Name = "Income",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.new(1, -8, 0, 18),
		TextScaled = false,
		TextSize = 13,
		Font = Theme.Font.body,
		TextColor3 = Theme.Color.money,
		ZIndex = 7,
		Parent = tile,
	})

	if pet.equipped then
		Builder.label("E", {
			Name = "Equipped",
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(22, 22),
			BackgroundColor3 = Theme.Color.green,
			TextColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 1,
			BackgroundTransparency = 0,
			ZIndex = 8,
			Parent = tile,
		})
	end

	if not selectable and reason then
		Builder.label(reason, {
			Name = "Reason",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(60, 18),
			TextScaled = false,
			TextSize = 12,
			Font = Theme.Font.body,
			TextColor3 = Theme.Color.textDim,
			ZIndex = 8,
			Parent = tile,
		})
	end

	Builder.make("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = tile,
	}).MouseButton1Click:Connect(function()
		if mode == "equip" then
			local result = Net.Function("EquipPet"):InvokeServer(pet.uid, not pet.equipped)
			if result and not result.ok then
				Notify.push("warn", result.error or "Could not equip")
			end
			return
		end

		if not selectable then
			return
		end

		if mode == "fuse" and not selected[pet.uid] and #selectedList() >= State.data.limits.fuseInputs then
			Notify.push("warn", `Only {State.data.limits.fuseInputs} pets fit in the machine`)
			return
		end

		selected[pet.uid] = not selected[pet.uid] or nil
		render()
	end)

	return tile
end

function render()
	refs.grid:ClearAllChildren()
	Builder.grid(UDim2.fromOffset(120, 148), { CellPadding = UDim2.fromOffset(8, 8), Parent = refs.grid })

	-- Drop selections for pets that no longer exist.
	for uid in selected do
		local found = false
		for _, pet in State.data.pets do
			if pet.uid == uid then
				found = true
				break
			end
		end
		if not found then
			selected[uid] = nil
		end
	end

	for order, pet in State.data.pets do
		petCard(pet, order)
	end

	refs.countText.Text = `{#State.data.pets}/{State.data.limits.inventory} pets`
	refreshFooter()
end

local function act()
	local uids = selectedList()
	if #uids == 0 then
		return
	end

	if mode == "sell" then
		local result = Net.Function("SellPets"):InvokeServer(uids)
		if result and result.ok then
			Notify.push("success", `Sold {result.sold} pets for {Format.abbreviate(result.payout)}`)
			table.clear(selected)
			State.request()
		elseif result then
			Notify.push("warn", result.error or "Could not sell")
		end
	elseif mode == "fuse" then
		if #uids ~= State.data.limits.fuseInputs then
			Notify.push("warn", `Pick exactly {State.data.limits.fuseInputs} pets`)
			return
		end
		local result = Net.Function("Fuse"):InvokeServer(uids)
		if result and result.ok then
			Notify.push("info", "Fusing...")
			table.clear(selected)
			State.request()
		elseif result then
			Notify.push("warn", result.error or "Could not fuse")
		end
	end
end

function PetsUI.setMode(newMode: string)
	mode = newMode
	table.clear(selected)
	if panel then
		panel:setTitle(MODE_TITLE[mode] or "My Pets")
		render()
	end
end

function PetsUI.build(screen: ScreenGui)
	panel = Panel.new({
		name = "Pets",
		title = MODE_TITLE.equip,
		size = UDim2.fromOffset(820, 540),
		headerColor = Theme.Color.headerGold,
		parent = screen,
	})

	refs.countText = Builder.label("0/0 pets", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel.body,
	})

	refs.grid = Builder.scroller({
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 1, -106),
		Parent = panel.body,
	})

	local footer = Builder.frame({
		Name = "Footer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 56),
		BackgroundColor3 = Theme.Color.panelInset,
		Parent = panel.body,
	})

	refs.footerText = Builder.label("", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -180, 1, -16),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footer,
	})

	refs.actionButton = Builder.button("SELL", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(150, 42),
		BackgroundColor3 = Theme.Color.red,
		Visible = false,
		Parent = footer,
	}, act)

	for _, entry in {
		{ id = "equip", label = "Equip", color = Theme.Color.headerGold },
		{ id = "sell", label = "Sell", color = Theme.Color.red },
		{ id = "fuse", label = "Fuse", color = Theme.Color.headerPurple },
	} do
		panel:addTab(entry.label, entry.color, function()
			PetsUI.setMode(entry.id)
		end)
	end

	panel.onOpen = render
	State.changed:Connect(function()
		if panel.isOpen then
			render()
		end
	end)

	Net.Event("FuseResult").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		Notify.push(
			payload.upgraded and "success" or "info",
			payload.upgraded and `Fuse succeeded -- {payload.name} ({payload.rarity})!`
				or `Fuse returned a {payload.name}`
		)
		State.request()
	end)

	return panel
end

function PetsUI.open(withMode: string?)
	if not panel then
		return
	end
	if withMode then
		PetsUI.setMode(withMode)
	end
	panel:open()
end

function PetsUI.toggle()
	if panel then
		panel:toggle()
	end
end

return PetsUI
