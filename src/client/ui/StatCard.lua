--!strict
--[[
	StatCard
	One row in the stat list. Handles all four visual states:
	locked / ready / scanning / revealed.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local GamepassConfig = require(Shared.GamepassConfig)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Store = require(script.Parent.Parent.Store)

local StatCard = {}
StatCard.__index = StatCard

local CARD_HEIGHT = 118
local DISCLAIMER = "*Uses estimation based on player stats*"

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

	self.root = Util.new("Frame", {
		Name = "Card_" .. stat.id,
		Size = UDim2.new(1, 0, 0, CARD_HEIGHT),
		BackgroundColor3 = stat.color,
		BorderSizePixel = 0,
		LayoutOrder = order,
		ClipsDescendants = true,
	})
	Util.corner(Theme.Radius.card, self.root)
	Util.padding(Theme.Padding.card, self.root)

	-- Title row -----------------------------------------------------------
	self.title = Util.new("TextLabel", {
		Name = "Title",
		Size = UDim2.new(1, -120, 0, 34),
		BackgroundTransparency = 1,
		Font = Theme.Font.title,
		Text = stat.icon .. "  " .. stat.name,
		TextColor3 = Theme.Color.text,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.75,
		Parent = self.root,
	})

	-- Value / status line -------------------------------------------------
	self.value = Util.new("TextLabel", {
		Name = "Value",
		Position = UDim2.new(0, 0, 0, 38),
		Size = UDim2.new(1, -120, 0, 28),
		BackgroundTransparency = 1,
		Font = Theme.Font.bold,
		Text = "",
		TextColor3 = Theme.Color.text,
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = self.root,
	})

	-- Progress bar (hidden unless scanning) -------------------------------
	self.barBack = Util.new("Frame", {
		Name = "BarBack",
		Position = UDim2.new(0, 0, 0, 44),
		Size = UDim2.new(1, -130, 0, 16),
		BackgroundColor3 = Color3.fromRGB(30, 30, 30),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		Parent = self.root,
	})
	Util.corner(Theme.Radius.pill, self.barBack)

	self.barFill = Util.new("Frame", {
		Name = "BarFill",
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Theme.Color.text,
		BorderSizePixel = 0,
		Parent = self.barBack,
	})
	Util.corner(Theme.Radius.pill, self.barFill)

	self.barText = Util.new("TextLabel", {
		Name = "BarText",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.Font.bold,
		Text = "",
		TextColor3 = Color3.fromRGB(20, 20, 20),
		TextSize = 13,
		Parent = self.barBack,
	})

	-- Footer --------------------------------------------------------------
	self.footer = Util.new("TextLabel", {
		Name = "Footer",
		Position = UDim2.new(0, 0, 1, -26),
		Size = UDim2.new(1, -120, 0, 22),
		BackgroundTransparency = 1,
		Font = Theme.Font.body,
		Text = DISCLAIMER,
		TextColor3 = Theme.shade(stat.color, -0.45),
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self.root,
	})

	-- Action button -------------------------------------------------------
	self.action = Util.button({
		Name = "Action",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.new(0, 104, 0, 46),
		BackgroundColor3 = Theme.shade(stat.color, -0.35),
		Font = Theme.Font.bold,
		Text = "SCAN",
		TextSize = 19,
		Parent = self.root,
	})
	Util.corner(Theme.Radius.card, self.action)

	-- Secondary button (flex / cancel) ------------------------------------
	self.secondary = Util.button({
		Name = "Secondary",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 34),
		Size = UDim2.new(0, 104, 0, 26),
		BackgroundColor3 = Theme.shade(stat.color, -0.55),
		Font = Theme.Font.body,
		Text = "",
		TextSize = 15,
		Visible = false,
		Parent = self.root,
	})
	Util.corner(Theme.Radius.card, self.secondary)

	Util.onClick(self.action, 0.2, function()
		self:onAction()
	end)
	Util.onClick(self.secondary, 0.2, function()
		self:onSecondary()
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
		return "locked-coins", ("🔒 Unlock for %s coins"):format(Format.comma(unlock.amount))
	elseif unlock.kind == "scans" then
		if state.totalScans < unlock.amount then
			return "locked-progress", ("🔒 %d / %d scans completed"):format(state.totalScans, unlock.amount)
		end
	elseif unlock.kind == "rebirth" then
		if state.rebirths < unlock.amount then
			return "locked-progress", ("🔒 Needs %d rebirth(s)"):format(unlock.amount)
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
			return "locked-pass", ("🔒 %s gamepass"):format(pass and pass.name or "?")
		end
	end

	return Store.isScanned(stat.id) and "revealed" or "ready"
end

function StatCard:update(state)
	local stat = self.stat
	local mode, lockText = self:resolveMode(state)
	self.mode = mode

	local locked = mode:sub(1, 6) == "locked"

	self.root.BackgroundColor3 = locked and Theme.Color.locked or stat.color
	self.footer.TextColor3 = Theme.shade(locked and Theme.Color.locked or stat.color, -0.45)
	self.action.BackgroundColor3 = Theme.shade(locked and Theme.Color.locked or stat.color, -0.35)
	self.secondary.BackgroundColor3 = Theme.shade(locked and Theme.Color.locked or stat.color, -0.55)

	self.barBack.Visible = mode == "scanning"
	self.secondary.Visible = mode == "revealed"

	if mode == "scanning" then
		self.value.Text = ""
		self.action.Text = "CANCEL"
		self.footer.Text = "Scanning..."
	elseif mode == "revealed" then
		local value = state.values[stat.id]
		self.value.Text = "✓ " .. (value ~= nil and Format.value(stat.format, value) or "?")
		self.action.Text = "RESCAN"
		self.secondary.Text = "📣 FLEX"
		self.footer.Text = DISCLAIMER
	elseif mode == "ready" then
		self.value.Text = "Not scanned yet"
		self.action.Text = "SCAN"
		local estimate = state.instant and "instantly"
			or Format.clock(stat.scanTime / math.max(state.speed or 1, 0.01))
		self.footer.Text = ("Takes %s  •  %s"):format(estimate, stat.blurb)
	elseif mode == "locked-coins" then
		self.value.Text = lockText or "Locked"
		self.action.Text = "UNLOCK"
		self.action.BackgroundColor3 = state.coins >= stat.unlock.amount and Theme.Color.good or Theme.Color.bad
		self.footer.Text = stat.blurb
	elseif mode == "locked-pass" then
		self.value.Text = lockText or "Locked"
		self.action.Text = "BUY"
		self.action.BackgroundColor3 = Theme.Color.coin
		self.footer.Text = stat.blurb
	else -- locked-progress
		self.value.Text = lockText or "Locked"
		self.action.Text = "LOCKED"
		self.footer.Text = stat.blurb
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

	self.barFill.Size = UDim2.fromScale(progress, 1)
	self.barText.Text = ("%d%%   %s left"):format(math.floor(progress * 100), Format.clock(remaining))
end

function StatCard:destroy()
	self.root:Destroy()
end

return StatCard
