--[[
	Always-on screen furniture: the cash readout, the side button rail, the
	world-event countdowns and the carry banner.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)

local Builder = require(script.Parent.Builder)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)

local player = Players.LocalPlayer

local Hud = {}

local buttons = {}

local function statChip(parent: Instance, order: number, name: string, icon: string, color: Color3)
	local chip = Builder.frame({
		Name = name,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.Color.panelDeep,
		LayoutOrder = order,
		Parent = parent,
	})

	Builder.label(icon, {
		Name = "Icon",
		Size = UDim2.fromOffset(38, 34),
		Position = UDim2.fromOffset(6, 5),
		TextColor3 = color,
		Parent = chip,
	})

	local value = Builder.label("0", {
		Name = "Value",
		Size = UDim2.new(1, -52, 1, -10),
		Position = UDim2.fromOffset(46, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = color,
		Parent = chip,
	})

	return value
end

function Hud.build(screen: ScreenGui)
	local root = Builder.make("Frame", {
		Name = "Hud",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = Theme.Z.hud,
		Parent = screen,
	})

	-- ---------- top-left: cash and income ----------
	local stats = Builder.make("Frame", {
		Name = "Stats",
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(220, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	}, { Builder.list({ Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Left }) })

	Hud.cashLabel = statChip(stats, 1, "Cash", "$", Theme.Color.money)
	Hud.incomeLabel = statChip(stats, 2, "Income", "+", Theme.Color.gold)

	-- ---------- right rail: menu buttons ----------
	local rail = Builder.make("Frame", {
		Name = "Rail",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(112, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	}, { Builder.list({ Padding = UDim.new(0, 10) }) })

	Hud.rail = rail

	-- ---------- bottom-right: world event timers ----------
	local timers = Builder.make("Frame", {
		Name = "Timers",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(240, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	}, { Builder.list({ Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }) })

	local function timerRow(order: number, name: string, color: Color3)
		local row = Builder.frame({
			Name = name,
			Size = UDim2.new(1, 0, 0, 40),
			BackgroundColor3 = Theme.Color.panelDeep,
			BackgroundTransparency = 0.15,
			LayoutOrder = order,
			Parent = timers,
		})

		Builder.label(name, {
			Size = UDim2.fromOffset(58, 26),
			Position = UDim2.fromOffset(8, 7),
			TextColor3 = color,
			Parent = row,
		})

		return Builder.label("--", {
			Name = "Value",
			Size = UDim2.new(1, -78, 1, -10),
			Position = UDim2.fromOffset(72, 5),
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Theme.Font.title,
			Parent = row,
		})
	end

	Hud.potionLabel = timerRow(1, "Potion", Color3.fromRGB(150, 245, 150))
	Hud.nightLabel = timerRow(2, "Cycle", Color3.fromRGB(175, 195, 255))

	-- ---------- bottom-centre: carry banner ----------
	Hud.carryBanner = Builder.frame({
		Name = "CarryBanner",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(420, 56),
		BackgroundColor3 = Theme.Color.panelDeep,
		Visible = false,
		Parent = root,
	})

	Hud.carryLabel = Builder.label("", {
		Name = "Text",
		Size = UDim2.new(1, -20, 1, -12),
		Position = UDim2.fromOffset(10, 6),
		Parent = Hud.carryBanner,
	})

	return root
end

--[[
	Adds a button to the right rail. The word is the button -- emoji and
	symbol glyphs do not render reliably across Roblox's fonts, and a label
	people can read beats an icon they have to learn.
]]
function Hud.addButton(label: string, color: Color3, onClick: () -> ())
	local order = #buttons + 1

	local button = Builder.button(label, {
		Name = label,
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = color,
		LayoutOrder = order,
		Parent = Hud.rail,
	}, onClick)

	table.insert(buttons, button)
	return button
end

local function refreshCarry()
	local character = player.Character
	local eggUid = character and character:GetAttribute("CarryingEgg")

	if not eggUid then
		Hud.carryBanner.Visible = false
		return
	end

	local rarityName = character:GetAttribute("CarryRarity") or "Common"
	Hud.carryBanner.Visible = true
	Hud.carryLabel.Text = `Carrying a {rarityName} egg -- get it to a hatch pad!`
	Hud.carryLabel.TextColor3 = Rarity.get(rarityName).glow
end

function Hud.start()
	State.changed:Connect(function()
		Hud.cashLabel.Text = Format.abbreviate(State.data.cash)
		Hud.incomeLabel.Text = Format.abbreviate(State.data.income) .. "/s"
	end)

	State.worldChanged:Connect(function()
		local world = State.world
		Hud.potionLabel.Text = world.potionActive and "Potion active!"
			or `in {Format.duration(world.potionIn)}`
		Hud.potionLabel.TextColor3 = world.potionActive and Theme.Color.money or Theme.Color.text

		Hud.nightLabel.Text = `{world.isNight and "day" or "night"} in {Format.duration(world.phaseIn)}`
	end)

	-- Carry state arrives as a character attribute, so watch for it.
	local function hook(character: Model)
		character:GetAttributeChangedSignal("CarryingEgg"):Connect(refreshCarry)
		refreshCarry()
	end

	player.CharacterAdded:Connect(hook)
	if player.Character then
		hook(player.Character)
	end
end

return Hud
