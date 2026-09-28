--!strict
--[[
	StatCard -- one fat, brightly coloured row per stat.

	States: locked / ready / scanning / revealed. A locked card drains to a
	muted purple so the colour itself tells you what you can and cannot touch.
]]

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Format = require(Shared.Format)
local GamepassConfig = require(Shared.GamepassConfig)

local Theme = require(script.Parent.Theme)
local Util = require(script.Parent.Util)
local Skin = require(script.Parent.Skin)
local Sfx = require(script.Parent.Sfx)
local Store = require(script.Parent.Parent.Store)

local StatCard = {}
StatCard.__index = StatCard

local HEIGHT = 120

export type Callbacks = {
	scan: (string) -> (),
	unlock: (string) -> (),
	cancel: (string) -> (),
	flex: (string) -> (),
	buyPass: (string) -> (),
	setDisplayStat: (string) -> (),
}

function StatCard.new(stat, callbacks: Callbacks, order: number)
	local self = setmetatable({}, StatCard)

	self.stat = stat
	self.callbacks = callbacks

	self.root = Util.card({
		Name = "Card_" .. stat.id,
		Size = UDim2.new(1, 0, 0, HEIGHT),
		BackgroundColor3 = stat.color,
		LayoutOrder = order,
		radius = Theme.Radius.lg,
		weight = Theme.Outline.chunky,
		lip = Theme.Lip.chunky,
	})

	self.badge = Util.badge(self.root, stat.icon, 58, Color3.new(1, 1, 1))
	self.badge.Position = UDim2.fromOffset(14, 20)
	self.badge.ZIndex = 3

	self.title = Util.title({
		Position = UDim2.fromOffset(86, 12),
		Size = UDim2.new(1, -86 - 190, 0, 30),
		Text = stat.name,
		TextSize = 25,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = self.root,
	})

	self.value = Util.title({
		Position = UDim2.fromOffset(86, 42),
		Size = UDim2.new(1, -86 - 190, 0, 34),
		Text = "",
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = self.root,
	})

	-- Progress track, only while scanning.
	self.track = Util.well({
		Position = UDim2.fromOffset(86, 50),
		Size = UDim2.new(1, -86 - 200, 0, 24),
		Visible = false,
		ZIndex = 3,
		Parent = self.root,
	})

	self.fill = Util.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Color.green,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = self.track,
	})
	Util.corner(Theme.Radius.full, self.fill)
	Skin.gloss(self.fill, Theme.Radius.full)

	self.trackText = Util.text({
		Size = UDim2.fromScale(1, 1),
		Font = Theme.Font.display,
		Text = "",
		TextSize = 14,
		TextColor3 = Theme.Color.ink,
		ZIndex = 6,
		Parent = self.track,
	})

	self.footer = Util.text({
		Position = UDim2.new(0, 86, 1, -34),
		Size = UDim2.new(1, -86 - 190, 0, 18),
		Font = Theme.Font.small,
		Text = "",
		TextSize = 14,
		TextTransparency = 0.15,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = self.root,
	})

	self.action = Util.button({
		Name = "Action",
		variant = "go",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(164, Theme.TOUCH),
		Text = "SCAN",
		TextSize = 20,
		ZIndex = 3,
		Parent = self.root,
	})

	self.flexButton = Util.button({
		Name = "Flex",
		variant = "pink",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -92, 1, -14),
		Size = UDim2.fromOffset(78, 36),
		Text = "FLEX",
		TextSize = 15,
		lip = Theme.Lip.small,
		ZIndex = 3,
		Visible = false,
		Parent = self.root,
	})

	self.pin = Util.button({
		Name = "Pin",
		variant = "cyan",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -14, 1, -14),
		Size = UDim2.fromOffset(72, 36),
		Text = "PIN",
		TextSize = 15,
		lip = Theme.Lip.small,
		ZIndex = 3,
		Visible = false,
		Parent = self.root,
	})

	Util.onClick(self.action, 0.15, function()
		self:onAction()
	end)
	Util.onClick(self.flexButton, 0.2, function()
		if self.mode == "revealed" then
			self.callbacks.flex(self.stat.id)
		end
	end)
	Util.onClick(self.pin, 0.25, function()
		if self.mode == "revealed" then
			self.callbacks.setDisplayStat(self.pinned and "" or self.stat.id)
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
	else
		Sfx.play("deny")
		Skin.shake(self.root)
	end
end

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
		return "locked-coins", ("%s coins to unlock"):format(Format.comma(unlock.amount))
	elseif unlock.kind == "scans" then
		if state.totalScans < unlock.amount then
			return "locked-progress", ("%d / %d scans done"):format(state.totalScans, unlock.amount)
		end
	elseif unlock.kind == "rebirth" then
		if state.rebirths < unlock.amount then
			return "locked-progress", ("needs %d rebirth"):format(unlock.amount)
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
			return "locked-pass", ("%s only"):format(pass and pass.name or "?")
		end
	end

	return Store.isScanned(stat.id) and "revealed" or "ready"
end

local function paint(card, fill: Color3)
	card.root.BackgroundColor3 = fill
	local lip = card.root:FindFirstChild("Lip") :: Frame?
	if lip then
		lip.BackgroundColor3 = Theme.shade(fill, -0.32)
	end
end

function StatCard:update(state)
	local stat = self.stat
	local mode, lockText = self:resolveMode(state)
	self.mode = mode

	local locked = mode:sub(1, 6) == "locked"
	paint(self, locked and Theme.Color.panelLite or stat.color)

	self.track.Visible = mode == "scanning"
	self.value.Visible = mode ~= "scanning"
	self.flexButton.Visible = mode == "revealed"
	self.pin.Visible = mode == "revealed"

	self.pinned = state.displayStat == stat.id
	self.pin.Text = self.pinned and "PINNED" or "PIN"
	self.pin.BackgroundColor3 = self.pinned and Theme.Color.gold or Theme.Color.cyan
	self.pin.TextColor3 = Theme.inkOn(self.pin.BackgroundColor3)

	if mode == "scanning" then
		self.action.Text = "STOP"
		self.action.BackgroundColor3 = Theme.Color.red
		self.footer.Text = "scanning..."
	elseif mode == "revealed" then
		local value = state.values[stat.id]
		self.value.Text = value ~= nil and Format.value(stat.format, value) or "?"
		self.action.Text = "SCAN AGAIN"
		self.action.TextSize = 17
		self.action.BackgroundColor3 = Theme.Color.panel
		self.action.TextColor3 = Theme.Color.ink
		self.footer.Text = stat.blurb
	elseif mode == "ready" then
		local wait = state.instant and "instant" or Format.clock(stat.scanTime / math.max(state.speed or 1, 0.01))
		self.value.Text = "? ? ?"
		self.action.Text = "SCAN"
		self.action.TextSize = 20
		self.action.BackgroundColor3 = Theme.Color.green
		self.action.TextColor3 = Theme.inkOn(Theme.Color.green)
		self.footer.Text = ("takes %s  ·  %s"):format(wait, stat.blurb)
	elseif mode == "locked-coins" then
		local affordable = state.coins >= stat.unlock.amount
		self.value.Text = "LOCKED"
		self.action.Text = "UNLOCK"
		self.action.TextSize = 18
		self.action.BackgroundColor3 = affordable and Theme.Color.gold or Theme.Color.slot
		self.action.TextColor3 = Theme.inkOn(self.action.BackgroundColor3)
		self.footer.Text = lockText or ""
	elseif mode == "locked-pass" then
		self.value.Text = "LOCKED"
		self.action.Text = "GET PASS"
		self.action.TextSize = 17
		self.action.BackgroundColor3 = Theme.Color.gold
		self.action.TextColor3 = Theme.inkOn(Theme.Color.gold)
		self.footer.Text = lockText or ""
	else
		self.value.Text = "LOCKED"
		self.action.Text = "LOCKED"
		self.action.TextSize = 17
		self.action.BackgroundColor3 = Theme.Color.slot
		self.action.TextColor3 = Theme.Color.inkDim
		self.footer.Text = lockText or ""
	end
end

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
	self.trackText.Text = ("%d%%   %s"):format(math.floor(progress * 100), Format.clock(remaining))
end

--- Celebration when a scan lands on this card.
function StatCard:celebrate()
	Skin.pop(self.root, 0.06)
	Skin.confetti(self.root, self.stat.color, 16)
end

function StatCard:destroy()
	self.root:Destroy()
end

return StatCard
