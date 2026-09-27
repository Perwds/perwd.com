--!strict
--[[
	StatCard -- a module bolted onto the chassis.

	One row per stat, in four states: locked / ready / scanning / revealed.

	A note on colour discipline: the design system reserves saturated colour
	for function, so the card body stays chassis grey and each stat's identity
	colour is carried by a thin vertical stripe, the icon housing tint and the
	status LED -- not by flooding the whole panel. Safety orange is kept for
	the interactive key and the active progress fill.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local GamepassConfig = require(Shared.GamepassConfig)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Bevel = require(script.Parent.Bevel)
local Store = require(script.Parent.Parent.Store)

local StatCard = {}
StatCard.__index = StatCard

local CARD_HEIGHT = 126
local DISCLAIMER = "est. from player stats"

export type Callbacks = {
	scan: (string) -> (),
	unlock: (string) -> (),
	cancel: (string) -> (),
	flex: (string) -> (),
	buyPass: (string) -> (),
}

function StatCard.new(stat, callbacks: Callbacks, order: number)
	local self = setmetatable({}, StatCard)

	self.stat = stat
	self.callbacks = callbacks

	self.root = Util.panel({
		Name = "Card_" .. stat.id,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		LayoutOrder = order,
	}, {
		-- Screws sit in the 16px border margin; vents tuck in to the left of
		-- the action key so they never sit under it.
		padding = Theme.Space.panel,
		ventPos = UDim2.new(1, -140, 0, 4),
	})

	Util.padding(Theme.Space.panel, self.root)

	-- Identity stripe: the stat's colour, kept to a machined edge strip.
	self.stripe = Util.new("Frame", {
		Name = "Stripe",
		Position = UDim2.fromOffset(-6, 8),
		Size = UDim2.new(0, 5, 1, -16),
		BackgroundColor3 = stat.color,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = self.root,
	})
	Util.corner(Theme.Radius.full, self.stripe)

	-- Icon housing, so the glyph is mounted rather than floating.
	self.housing = Util.iconHousing(self.root, stat.icon, 44, stat.color)
	self.housing.Position = UDim2.fromOffset(6, 4)

	-- Status LED. Diode only, no label: the footer already says the state in
	-- words, and the LED's 150px labelled holder overlapped it.
	self.led = Bevel.led(self.root, Theme.Color.shadowDeep, nil, UDim2.new(0, 62, 1, -19))

	-- Title -- uppercase, tight, mounted next to the housing.
	self.title = Util.text({
		Name = "Title",
		Position = UDim2.fromOffset(62, 2),
		Size = UDim2.new(1, -62 - 132, 0, 26),
		Font = Theme.Font.display,
		Text = stat.name,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.root,
	})

	-- Value readout -- always monospace, as all numeric displays are.
	self.value = Util.text({
		Name = "Value",
		Position = UDim2.fromOffset(62, 30),
		Size = UDim2.new(1, -62 - 132, 0, 30),
		Font = Theme.Font.mono,
		Text = "",
		TextSize = 21,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = self.root,
	})

	-- Progress well: a machined track with the bar riding inside it.
	self.track = Util.well({
		Name = "Track",
		Position = UDim2.fromOffset(62, 36),
		Size = UDim2.new(1, -62 - 142, 0, 18),
		radius = Theme.Radius.full,
		Visible = false,
		Parent = self.root,
	})

	self.fill = Util.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Color.accent,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = self.track,
	})
	Util.corner(Theme.Radius.full, self.fill)

	self.trackText = Util.new("TextLabel", {
		Name = "TrackText",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.Font.mono,
		Text = "",
		TextColor3 = Theme.Color.text,
		TextSize = 11,
		ZIndex = 3,
		Parent = self.track,
	})

	-- Footer: stamped metadata.
	self.footer = Util.stamp({
		Name = "Footer",
		Position = UDim2.new(0, 82, 1, -20),
		Size = UDim2.new(1, -82 - 132, 0, 16),
		Text = DISCLAIMER,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.root,
	})

	-- Primary key. TOUCH-tall so it clears the 48px minimum.
	self.action = Util.button({
		Name = "Action",
		variant = "primary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.new(0, 118, 0, Theme.TOUCH),
		Text = "SCAN",
		TextSize = 15,
		Parent = self.root,
	})

	-- Secondary keys, only present once a value exists: broadcast it, or pin it
	-- above your character.
	self.secondary = Util.button({
		Name = "Secondary",
		variant = "secondary",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -60, 1, -2),
		Size = UDim2.new(0, 58, 0, 34),
		Text = "FLEX",
		TextSize = 12,
		Visible = false,
		Parent = self.root,
	})

	self.pin = Util.button({
		Name = "Pin",
		variant = "secondary",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, -2),
		Size = UDim2.new(0, 58, 0, 34),
		Text = "PIN",
		TextSize = 12,
		Visible = false,
		Parent = self.root,
	})

	Util.onClick(self.action, 0.2, function()
		self:onAction()
	end)
	Util.onClick(self.secondary, 0.2, function()
		self:onSecondary()
	end)
	Util.onClick(self.pin, 0.3, function()
		if self.mode == "revealed" then
			-- Pinning the already-pinned stat clears it.
			local pinned = self.pinned and "" or self.stat.id
			self.callbacks.setDisplayStat(pinned)
		end
	end)

	return self
end

function StatCard:onAction()
	local stat = self.stat
	local mode = self.mode

	if mode == "locked-coins" then
		self.callbacks.unlock(stat.id)
	elseif mode == "locked-pass" then
		self.callbacks.buyPass(stat.unlock.pass)
	elseif mode == "scanning" then
		self.callbacks.cancel(stat.id)
	elseif mode == "ready" or mode == "revealed" then
		self.callbacks.scan(stat.id)
	end
end

function StatCard:onSecondary()
	if self.mode == "revealed" then
		self.callbacks.flex(self.stat.id)
	end
end

--- Decides which of the four states applies, from the current store state.
function StatCard:resolveMode(state): (string, string?)
	local stat = self.stat

	if Store.isScanning(stat.id) then
		return "scanning"
	end

	if state.unlocked[stat.id] then
		return Store.isScanned(stat.id) and "revealed" or "ready"
	end

	local unlock = stat.unlock

	if unlock.kind == "coins" then
		return "locked-coins", ("LOCKED / %s COINS"):format(Format.comma(unlock.amount))
	elseif unlock.kind == "scans" then
		if state.totalScans < unlock.amount then
			return "locked-progress", ("LOCKED / %d OF %d SCANS"):format(state.totalScans, unlock.amount)
		end
	elseif unlock.kind == "rebirth" then
		if state.rebirths < unlock.amount then
			return "locked-progress", ("LOCKED / %d REBIRTH"):format(unlock.amount)
		end
	elseif unlock.kind == "gamepass" then
		local pass = GamepassConfig.ByKey[unlock.pass]
		local unlockAll = false
		for key, owned in pairs(state.passes or {}) do
			local candidate = GamepassConfig.ByKey[key]
			if owned and candidate and candidate.unlockAll then
				unlockAll = true
			end
		end
		if not (state.passes and state.passes[unlock.pass]) and not unlockAll then
			return "locked-pass", ("LOCKED / %s"):format(pass and pass.name:upper() or "?")
		end
	end

	return Store.isScanned(stat.id) and "revealed" or "ready"
end

local function setLed(card, color: Color3)
	local diode = card.led:FindFirstChild("Diode")
	local bloom = card.led:FindFirstChild("Bloom")
	if diode then
		(diode :: Frame).BackgroundColor3 = color
	end
	if bloom then
		(bloom :: Frame).BackgroundColor3 = color
	end
end

function StatCard:update(state)
	local stat = self.stat
	local mode, lockText = self:resolveMode(state)
	self.mode = mode

	local locked = mode:sub(1, 6) == "locked"

	-- A locked module reads as unpowered: grey stripe, dead LED, muted ink.
	self.stripe.BackgroundColor3 = locked and Theme.Color.shadowDeep or stat.color
	self.title.TextColor3 = locked and Theme.Color.textMuted or Theme.Color.text

	self.track.Visible = mode == "scanning"
	self.value.Visible = mode ~= "scanning"
	self.secondary.Visible = mode == "revealed"
	self.pin.Visible = mode == "revealed"

	self.pinned = state.displayStat == stat.id
	self.pin.Text = self.pinned and "PINNED" or "PIN"
	self.pin.BackgroundColor3 = self.pinned and Theme.Color.accent or Theme.Color.chassis
	self.pin.TextColor3 = self.pinned and Theme.Color.accentText or Theme.Color.text

	if mode == "scanning" then
		self.action.Text = "ABORT"
		self.action.BackgroundColor3 = Theme.Color.dark
		self.footer.Text = Theme.stamp("scanning")
		setLed(self, Theme.Color.ledAmber)
	elseif mode == "revealed" then
		local value = state.values[stat.id]
		self.value.Text = value ~= nil and Format.value(stat.format, value) or "--"
		self.value.TextColor3 = Theme.Color.text
		self.action.Text = "RESCAN"
		self.action.BackgroundColor3 = Theme.Color.chassis
		self.action.TextColor3 = Theme.Color.text
		self.footer.Text = Theme.stamp(DISCLAIMER)
		setLed(self, Theme.Color.ledGreen)
	elseif mode == "ready" then
		local estimate = state.instant and "instant"
			or Format.clock(stat.scanTime / math.max(state.speed or 1, 0.01))
		self.value.Text = "-- -- --"
		self.value.TextColor3 = Theme.Color.textMuted
		self.action.Text = "SCAN"
		self.action.BackgroundColor3 = Theme.Color.accent
		self.action.TextColor3 = Theme.Color.accentText
		self.footer.Text = Theme.stamp("ready / " .. estimate)
		setLed(self, Theme.Color.ledGreen)
	elseif mode == "locked-coins" then
		local affordable = state.coins >= stat.unlock.amount
		self.value.Text = lockText or "LOCKED"
		self.value.TextColor3 = Theme.Color.textMuted
		self.action.Text = "UNLOCK"
		self.action.BackgroundColor3 = affordable and Theme.Color.accent or Theme.Color.recess
		self.action.TextColor3 = affordable and Theme.Color.accentText or Theme.Color.textMuted
		self.footer.Text = Theme.stamp(stat.category .. " module")
		setLed(self, affordable and Theme.Color.ledAmber or Theme.Color.shadowDeep)
	elseif mode == "locked-pass" then
		self.value.Text = lockText or "LOCKED"
		self.value.TextColor3 = Theme.Color.textMuted
		self.action.Text = "GET PASS"
		self.action.BackgroundColor3 = Theme.Color.accent
		self.action.TextColor3 = Theme.Color.accentText
		self.footer.Text = Theme.stamp(stat.category .. " module")
		setLed(self, Theme.Color.ledRed)
	else -- locked-progress
		self.value.Text = lockText or "LOCKED"
		self.value.TextColor3 = Theme.Color.textMuted
		self.action.Text = "LOCKED"
		self.action.BackgroundColor3 = Theme.Color.recess
		self.action.TextColor3 = Theme.Color.textMuted
		self.footer.Text = Theme.stamp(stat.category .. " module")
		setLed(self, Theme.Color.shadowDeep)
	end
end

--- Called every frame while a scan is running.
function StatCard:tick(now: number)
	if self.mode ~= "scanning" then
		return
	end

	local session = Store.scanSession(self.stat.id)
	if not session then
		return
	end

	local remaining = math.max(0, session.endsAt - now)
	local progress = session.duration > 0 and math.clamp(1 - remaining / session.duration, 0, 1) or 1

	self.fill.Size = UDim2.fromScale(progress, 1)
	self.trackText.Text = ("%3d%%   %s"):format(math.floor(progress * 100), Format.clock(remaining))
end

function StatCard:destroy()
	self.root:Destroy()
end

return StatCard
