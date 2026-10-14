--!strict
-- Bottom currency bar, side buttons, toasts, the one-line guide strip and simple dialogs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Format = require(Shared.Format)
local State = require(script.Parent.State)
local Ui = require(script.Parent.Ui)

local Hud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local bar: Frame
local segments: { [string]: { frame: Frame, label: TextLabel, divider: TextLabel? } } = {}
local toasts: Frame
local strip: Frame
local stripLabel: TextLabel
local sideButtons: Frame
local guideText: string? = nil
local sayUntil = 0
local compact = false

Hud.buttons = {} :: { [string]: TextButton }

local function currencyVisible(snapshot: { [string]: any }, currency: any): boolean
	if currency.unlock == nil then
		return true
	end
	return snapshot.s[currency.unlock] == true or (currency.id == "seeds" and (snapshot.c.seeds or 0) > 0)
end

local function buildBar()
	bar = Ui.panel({
		Name = "CurrencyBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(0, 38),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = gui,
	})
	Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = bar })
	Ui.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
		Parent = bar,
	})
	for i, currency in Config.Currencies do
		local divider: TextLabel? = nil
		if i > 1 then
			divider = Ui.text({
				Name = "Divider" .. i,
				Text = "/",
				Font = Ui.TITLE,
				TextSize = 20,
				TextColor3 = Palette.screenDim,
				Size = UDim2.fromOffset(10, 30),
				LayoutOrder = i * 2 - 1,
				Visible = false,
				Parent = bar,
			})
		end
		local frame = Ui.new("Frame", {
			Name = currency.id,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			LayoutOrder = i * 2,
			Visible = currency.unlock == nil,
			Parent = bar,
		})
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			Parent = frame,
		})
		local icon = Ui.icon(currency.id, Palette.currency[currency.id], 16)
		icon.Parent = frame
		local label = Ui.text({
			Name = "Amount",
			Text = "0",
			Font = Ui.TITLE,
			TextSize = 20,
			TextColor3 = Palette.white,
			Size = UDim2.fromOffset(0, 30),
			AutomaticSize = Enum.AutomaticSize.X,
			Parent = frame,
		})
		segments[currency.id] = { frame = frame, label = label, divider = divider }
	end
end

local function updateBar(snapshot: { [string]: any })
	local style = snapshot.settings.numbers
	local first = true
	for _, currency in Config.Currencies do
		local seg = segments[currency.id]
		local visible = currencyVisible(snapshot, currency)
		seg.frame.Visible = visible
		if seg.divider then
			seg.divider.Visible = visible and not first
		end
		if visible then
			first = false
			local amount = Format.number(snapshot.c[currency.id] or 0, style)
			local rate = (snapshot.rates and snapshot.rates[currency.id]) or 0
			local name = if compact then "" else " " .. currency.name
			local rateText = if currency.id == "seeds" then "" else " (" .. Format.rate(rate, style) .. ")"
			seg.label.Text = amount .. name .. rateText
			seg.label.TextColor3 = Palette.white
		end
	end
	-- Drop the currency names when the bar would run off a narrow screen.
	local viewport = workspace.CurrentCamera.ViewportSize.X
	local scale = (gui:FindFirstChildOfClass("UIScale") :: UIScale).Scale
	local tooWide = bar.AbsoluteSize.X > viewport - 40
	if tooWide and not compact then
		compact = true
	elseif compact and (bar.AbsoluteSize.X + 120 * #Config.Currencies * scale) < viewport - 40 then
		compact = false
	end
end

local function buildSideButtons()
	sideButtons = Ui.new("Frame", {
		Name = "Side",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(64, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Ui.new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = sideButtons })
	for i, spec in { { "map", "MAP" }, { "shop", "SHOP" }, { "settings", "SETTINGS" } } do
		local button = Ui.button({
			Name = spec[1],
			Text = "",
			Size = UDim2.fromOffset(64, 64),
			BackgroundColor3 = Palette.hud,
			LayoutOrder = i,
			Visible = spec[1] ~= "shop",
			Parent = sideButtons,
		}, function() end)
		Ui.stroke().Parent = button
		local icon = Ui.icon(spec[1], Palette.white, 26)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 10)
		icon.Parent = button
		Ui.text({
			Text = spec[2],
			Font = Ui.TITLE,
			TextSize = 12,
			Size = UDim2.new(1, 0, 0, 14),
			Position = UDim2.new(0, 0, 1, -20),
			Parent = button,
		})
		Hud.buttons[spec[1]] = button
	end
end

local function buildStrip()
	strip = Ui.panel({
		Name = "Guide",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -58),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		Parent = gui,
	})
	Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = strip })
	stripLabel = Ui.text({
		Text = "",
		TextSize = 17,
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		RichText = true,
		Parent = strip,
	})
end

local function refreshStrip()
	if os.clock() < sayUntil then
		return
	end
	strip.Visible = guideText ~= nil
	if guideText then
		stripLabel.Text = guideText
	end
end

-- The tutorial's single line. nil hides it.
function Hud.setGuide(text: string?)
	guideText = text
	refreshStrip()
end

-- A named character speaking one line, shown for a few seconds over the guide line.
function Hud.say(name: string, text: string)
	local token = os.clock() + 6
	sayUntil = token
	stripLabel.Text =
		string.format('<font color="#%s">%s:</font> %s', Palette.zones.orange.neon:ToHex(), string.upper(name), text)
	strip.Visible = true
	strip.Position = UDim2.new(0.5, 0, 1, -50)
	Ui.tween(strip, 0.25, { Position = UDim2.new(0.5, 0, 1, -58) }, Enum.EasingStyle.Back)
	task.delay(6.05, function()
		if sayUntil == token then
			sayUntil = 0
			refreshStrip()
		end
	end)
end

function Hud.toast(text: string, color: Color3?)
	local toast = Ui.panel({
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = toasts,
	})
	Ui.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14), Parent = toast })
	Ui.text({
		Text = text,
		Font = Ui.TITLE,
		TextSize = 18,
		TextColor3 = color or Palette.white,
		Size = UDim2.fromOffset(0, 36),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = toast,
	})
	local scale = Ui.new("UIScale", { Scale = 0.85, Parent = toast })
	Ui.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.2, function()
		Ui.tween(scale, 0.18, { Scale = 0.85 })
		task.wait(0.18)
		toast:Destroy()
	end)
end

local modalOpen: Frame? = nil

local function modal(title: string, body: string, buttons: { { text: string, color: Color3?, onClick: () -> () } })
	if modalOpen then
		modalOpen:Destroy()
	end
	local shade = Ui.new("TextButton", {
		Name = "Shade",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, -60),
		ZIndex = 20,
		Parent = gui,
	})
	shade.Size = UDim2.new(1, 0, 1, 120)
	local card = Ui.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 21,
		Parent = shade,
	})
	Ui.padding(20).Parent = card
	Ui.new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = card })
	Ui.text({
		Text = title,
		Font = Ui.TITLE,
		TextSize = 28,
		TextColor3 = Palette.gold,
		Size = UDim2.new(1, 0, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		ZIndex = 22,
		Parent = card,
	})
	Ui.text({
		Text = body,
		TextSize = 17,
		TextWrapped = true,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		ZIndex = 22,
		Parent = card,
	})
	local row = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Ui.MIN_TAP),
		LayoutOrder = 3,
		ZIndex = 22,
		Parent = card,
	})
	Ui.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 10),
		Parent = row,
	})
	local function close()
		shade:Destroy()
		if modalOpen == card then
			modalOpen = nil
		end
	end
	for i, spec in buttons do
		Ui.button({
			Text = spec.text,
			TextSize = 20,
			Size = UDim2.fromOffset(150, Ui.MIN_TAP),
			BackgroundColor3 = spec.color or Palette.hudEdge,
			TextColor3 = if spec.color then Palette.dark else Palette.white,
			LayoutOrder = i,
			ZIndex = 23,
			Parent = row,
		}, function()
			close()
			spec.onClick()
		end)
	end
	local scale = Ui.new("UIScale", { Scale = 0.9, Parent = card })
	Ui.tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	modalOpen = card
end

function Hud.confirm(title: string, body: string, yes: string, no: string, onYes: () -> ())
	modal(title, body, {
		{ text = no, onClick = function() end },
		{ text = yes, color = Palette.gold, onClick = onYes },
	})
end

function Hud.card(title: string, body: string)
	modal(title, body, { { text = "OK", color = Palette.zones.orange.plate, onClick = function() end } })
end

function Hud.offline(info: { [string]: any })
	local lines = {}
	for _, currency in Config.Currencies do
		local gain = info.gains[currency.id]
		if gain then
			table.insert(lines, "+" .. State.fmt(gain) .. " " .. currency.name)
		end
	end
	if #lines == 0 then
		return
	end
	local capped = if info.away > info.seconds then " (capped at " .. Format.duration(info.seconds) .. ")" else ""
	Hud.card(
		"WELCOME BACK",
		"You were away " .. Format.duration(info.away) .. capped .. ".\n" .. table.concat(lines, "\n")
	)
end

function Hud.gui(): ScreenGui
	return gui
end

function Hud.init()
	gui = Ui.new("ScreenGui", {
		Name = "Hud",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})
	Ui.autoScale(gui)
	buildBar()
	buildSideButtons()
	buildStrip()
	toasts = Ui.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(600, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Ui.new("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = toasts,
	})
	State.onChange(updateBar)
end

return Hud
