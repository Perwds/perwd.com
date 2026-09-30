--!nonstrict
-- Persistent on-screen furniture: stat header, panel buttons, the cast prompt,
-- notifications, the rare-catch feed, and the catch card.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Hud = {}
Hud.__index = Hud

local PANEL_BUTTONS = {
	{ id = "bag", text = "Bag" },
	{ id = "rods", text = "Rods" },
	{ id = "zones", text = "Zones" },
	{ id = "index", text = "Index" },
	{ id = "board", text = "Board" },
}

function Hud.new(screenGui: ScreenGui)
	local self = setmetatable({}, Hud)
	self.gui = screenGui
	self.notifications = {}
	self.onPanelRequested = nil

	self:BuildHeader()
	self:BuildPanelButtons()
	self:BuildPrompt()
	self:BuildNotifications()
	self:BuildFeed()

	return self
end

-- Header ------------------------------------------------------------------------

function Hud:BuildHeader()
	local header = Widgets.Frame({
		parent = self.gui,
		name = "Header",
		size = UDim2.fromOffset(268, 96),
		position = UDim2.fromOffset(16, 16),
		color = Theme.Background,
		transparency = 0.12,
	})
	Widgets.Corner(header)
	Widgets.Stroke(header)
	Widgets.Padding(header, 12)

	self.coinLabel = Widgets.Text({
		parent = header,
		name = "Coins",
		text = "0",
		font = Theme.FontBold,
		textSize = 22,
		color = Theme.Coin,
		size = UDim2.new(1, 0, 0, 26),
	})

	self.zoneLabel = Widgets.Text({
		parent = header,
		name = "Zone",
		text = "Starter Pond",
		textSize = 12,
		color = Theme.TextDim,
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 28),
	})

	self.levelLabel = Widgets.Text({
		parent = header,
		name = "Level",
		text = "Lv 1",
		font = Theme.FontMedium,
		textSize = 12,
		size = UDim2.new(0.5, 0, 0, 16),
		position = UDim2.fromOffset(0, 48),
	})

	self.luckLabel = Widgets.Text({
		parent = header,
		name = "Luck",
		text = "x1.00 luck",
		font = Theme.FontMedium,
		textSize = 12,
		color = Theme.Accent,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0.5, 0, 0, 16),
		position = UDim2.new(0.5, 0, 0, 48),
	})

	local _, fill = Widgets.Bar({
		parent = header,
		name = "XpBar",
		size = UDim2.new(1, 0, 0, 6),
		position = UDim2.fromOffset(0, 70),
		fillColor = Theme.Accent,
	})
	self.xpFill = fill

	self.bagLabel = Widgets.Text({
		parent = header,
		name = "Bag",
		text = "Bag 0/250",
		textSize = 11,
		color = Theme.TextDim,
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 80),
	})
end

function Hud:BuildPanelButtons()
	local holder = Widgets.Frame({
		parent = self.gui,
		name = "PanelButtons",
		size = UDim2.fromOffset(96, #PANEL_BUTTONS * 38),
		position = UDim2.new(0, 16, 0, 128),
		color = Theme.Background,
		transparency = 1,
	})
	Widgets.List(holder, 6)

	for order, entry in PANEL_BUTTONS do
		Widgets.Button({
			parent = holder,
			name = entry.id,
			text = entry.text,
			order = order,
			size = UDim2.fromOffset(96, 32),
			onClick = function()
				if self.onPanelRequested then
					self.onPanelRequested(entry.id)
				end
			end,
		})
	end
end

-- Cast prompt --------------------------------------------------------------------

function Hud:BuildPrompt()
	local prompt = Widgets.Frame({
		parent = self.gui,
		name = "Prompt",
		size = UDim2.fromOffset(340, 38),
		position = UDim2.new(0.5, 0, 1, -48),
		anchor = Vector2.new(0.5, 1),
		color = Theme.Background,
		transparency = 0.2,
	})
	Widgets.Corner(prompt)
	Widgets.Stroke(prompt)

	self.promptLabel = Widgets.Text({
		parent = prompt,
		name = "Label",
		text = "Click the water to cast",
		font = Theme.FontMedium,
		textSize = 14,
		align = Enum.TextXAlignment.Center,
	})

	self.prompt = prompt
end

function Hud:SetPrompt(text: string, color: Color3?)
	self.promptLabel.Text = text
	self.promptLabel.TextColor3 = color or Theme.Text
end

-- Notifications --------------------------------------------------------------------

function Hud:BuildNotifications()
	local holder = Widgets.Frame({
		parent = self.gui,
		name = "Notifications",
		size = UDim2.fromOffset(320, 180),
		position = UDim2.new(0.5, 0, 0, 16),
		anchor = Vector2.new(0.5, 0),
		transparency = 1,
	})

	local layout = Widgets.List(holder, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	self.notifyHolder = holder
end

function Hud:Notify(text: string, kind: string?)
	local color = Theme.NotifyColors[kind or "info"] or Theme.Accent

	local card = Widgets.Frame({
		parent = self.notifyHolder,
		name = "Notification",
		size = UDim2.fromOffset(300, 32),
		color = Theme.Background,
		transparency = 0.1,
	})
	Widgets.Corner(card, Theme.CornerSmall)
	Widgets.Stroke(card, color)

	Widgets.Text({
		parent = card,
		text = text,
		font = Theme.FontMedium,
		textSize = 13,
		color = color,
		align = Enum.TextXAlignment.Center,
	})

	task.delay(3.2, function()
		if card.Parent then
			Widgets.Tween(card, 0.25, { BackgroundTransparency = 1 })
			task.wait(0.25)
			card:Destroy()
		end
	end)
end

-- Rare catch feed --------------------------------------------------------------------

function Hud:BuildFeed()
	local holder = Widgets.Frame({
		parent = self.gui,
		name = "Feed",
		size = UDim2.fromOffset(300, 150),
		position = UDim2.new(0, 16, 1, -16),
		anchor = Vector2.new(0, 1),
		transparency = 1,
	})

	local layout = Widgets.List(holder, 4)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	self.feedHolder = holder
end

function Hud:SetFeed(entries)
	self.feedHolder:ClearAllChildren()
	Widgets.List(self.feedHolder, 4).VerticalAlignment = Enum.VerticalAlignment.Bottom

	-- Newest at the bottom, oldest trimmed off the top.
	local start = math.max(#entries - 5, 0) + 1
	for index = start, #entries do
		local entry = entries[index]
		local tier = Rarities.Data[entry.rarity]
		local color = tier and tier.color or Theme.Text

		local row = Widgets.Frame({
			parent = self.feedHolder,
			name = "FeedRow",
			size = UDim2.fromOffset(300, 22),
			color = Theme.Background,
			transparency = 0.35,
			order = index,
		})
		Widgets.Corner(row, Theme.CornerSmall)
		Widgets.Padding(row, 6)

		Widgets.Text({
			parent = row,
			text = string.format(
				'<font color="#%s">%s</font>  caught  <font color="#%s">%s</font>',
				Theme.TextDim:ToHex(),
				entry.player,
				color:ToHex(),
				entry.fish
			),
			textSize = 12,
			richText = true,
		})
	end
end

-- Catch card --------------------------------------------------------------------

function Hud:ShowCatch(result)
	if self.catchCard then
		self.catchCard:Destroy()
		self.catchCard = nil
	end

	local tier = Rarities.Data[result.rarity]
	local mutation = Mutations.Data[result.mutation]
	local color = (mutation and result.mutation ~= "None" and mutation.color)
		or (tier and tier.color)
		or Theme.Text

	local card = Widgets.Frame({
		parent = self.gui,
		name = "CatchCard",
		size = UDim2.fromOffset(300, 128),
		position = UDim2.new(0.5, 0, 0.5, 40),
		anchor = Vector2.new(0.5, 0.5),
		color = Theme.Background,
		transparency = 0.08,
	})
	Widgets.Corner(card)
	Widgets.Stroke(card, color, 2)
	Widgets.Padding(card, 12)
	self.catchCard = card

	Widgets.Text({
		parent = card,
		text = result.name,
		font = Theme.FontBold,
		textSize = 19,
		color = color,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 24),
	})

	Widgets.Text({
		parent = card,
		text = string.format("%s · %s", result.rarity, Format.Odds(result.odds)),
		font = Theme.FontMedium,
		textSize = 12,
		color = Theme.TextDim,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 28),
	})

	Widgets.Text({
		parent = card,
		text = Format.Weight(result.weight),
		font = Theme.FontMedium,
		textSize = 14,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 18),
		position = UDim2.fromOffset(0, 50),
	})

	Widgets.Text({
		parent = card,
		text = string.format("+%s coins", Format.Commas(result.value)),
		font = Theme.FontBold,
		textSize = 16,
		color = Theme.Coin,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.fromOffset(0, 72),
	})

	if result.autoSold then
		Widgets.Text({
			parent = card,
			text = "bag full — sold automatically",
			textSize = 11,
			color = Theme.Warn,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 14),
			position = UDim2.fromOffset(0, 92),
		})
	end

	card.BackgroundTransparency = 1
	TweenService:Create(card, TweenInfo.new(0.18), { BackgroundTransparency = 0.08 }):Play()

	task.delay(3.4, function()
		if card.Parent then
			Widgets.Tween(card, 0.3, { BackgroundTransparency = 1 })
			task.wait(0.3)
			card:Destroy()
			if self.catchCard == card then
				self.catchCard = nil
			end
		end
	end)
end

-- Stats --------------------------------------------------------------------

function Hud:SetProfile(profile, zoneName: string)
	self.coinLabel.Text = Format.Commas(profile.coins)
	self.zoneLabel.Text = zoneName
	self.levelLabel.Text = string.format("Lv %d", profile.level)
	self.luckLabel.Text = string.format("x%.2f luck", profile.luck)
	self.bagLabel.Text = string.format(
		"Bag %d/%d · worth %s",
		#profile.inventory,
		profile.bagLimit,
		Format.Abbreviate(profile.bagValue)
	)

	local ratio = profile.xpForLevel > 0 and profile.xpInLevel / profile.xpForLevel or 0
	Widgets.Tween(self.xpFill, 0.2, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) })
end

return Hud
