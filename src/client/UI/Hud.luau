--!nonstrict
-- Persistent on-screen furniture: stat header, panel buttons, cast prompt,
-- notifications, the rare-catch feed, and the catch card.

local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)
local HudScale = require(script.Parent.HudScale)
local FishView = require(script.Parent.FishView)

local Hud = {}
Hud.__index = Hud

local PANEL_BUTTONS = {
	{ id = "bag", text = "BAG" },
	{ id = "rods", text = "RODS" },
	{ id = "zones", text = "ZONES" },
	{ id = "index", text = "INDEX" },
	{ id = "board", text = "BOARD" },
}

local HEADER_WIDTH = 286

function Hud.new(screenGui: ScreenGui)
	local self = setmetatable({}, Hud)
	self.gui = screenGui
	self.onPanelRequested = nil

	self:BuildFlash()
	self:BuildHeader()
	self:BuildPanelButtons()
	self:BuildPrompt()
	self:BuildNotifications()
	self:BuildFeed()

	return self
end

-- Full-screen tint, used only for the genuinely rare catches.
function Hud:BuildFlash()
	self.flash = Widgets.Frame({
		parent = self.gui,
		name = "Flash",
		size = UDim2.fromScale(1, 1),
		color = Color3.new(1, 1, 1),
		transparency = 1,
		zIndex = 40,
	})
	self.flash.Active = false
end

-- Header ------------------------------------------------------------------------

function Hud:BuildHeader()
	local header = Widgets.Glass({
		parent = self.gui,
		name = "Header",
		size = UDim2.fromOffset(HEADER_WIDTH, 104),
		position = UDim2.fromOffset(18, 18),
		tint = Theme.Accent,
	})
	HudScale.Attach(header)
	Widgets.Padding(header, 14)

	-- Coin readout.
	local coinDot = Widgets.Frame({
		parent = header,
		name = "CoinDot",
		size = UDim2.fromOffset(14, 14),
		position = UDim2.fromOffset(0, 7),
		color = Color3.new(1, 1, 1),
	})
	Widgets.Gradient(coinDot, { Theme.Coin:Lerp(Color3.new(1, 1, 1), 0.5), Theme.Coin }, 90)
	Widgets.Corner(coinDot, Theme.CornerPill)

	self.coinLabel = Widgets.Text({
		parent = header,
		name = "Coins",
		text = "0",
		font = Theme.FontBlack,
		textSize = 25,
		color = Theme.Coin,
		size = UDim2.new(1, -22, 0, 28),
		position = UDim2.fromOffset(22, 0),
		glow = Theme.Coin,
		glowTransparency = 0.78,
	})

	self.zoneLabel = Widgets.Text({
		parent = header,
		name = "Zone",
		text = "Starter Pond",
		font = Theme.FontMedium,
		textSize = 12,
		color = Theme.TextDim,
		size = UDim2.new(1, 0, 0, 16),
		position = UDim2.fromOffset(0, 30),
	})

	self.levelLabel = Widgets.Text({
		parent = header,
		name = "Level",
		text = "LV 1",
		font = Theme.FontBold,
		textSize = 12,
		size = UDim2.new(0.5, 0, 0, 16),
		position = UDim2.fromOffset(0, 52),
	})

	self.luckLabel = Widgets.Text({
		parent = header,
		name = "Luck",
		text = "×1.00 LUCK",
		font = Theme.FontBold,
		textSize = 12,
		color = Theme.Accent,
		align = Enum.TextXAlignment.Right,
		size = UDim2.new(0.5, 0, 0, 16),
		position = UDim2.new(0.5, 0, 0, 52),
		glow = Theme.Accent,
		glowTransparency = 0.82,
	})

	local _, fill = Widgets.Bar({
		parent = header,
		name = "XpBar",
		size = UDim2.new(1, 0, 0, 7),
		position = UDim2.fromOffset(0, 72),
		fillColor = Theme.Accent,
	})
	self.xpFill = fill

	self.bagLabel = Widgets.Text({
		parent = header,
		name = "Bag",
		text = "BAG 0/250",
		textSize = 11,
		color = Theme.TextFaint,
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 84),
	})
end

function Hud:BuildPanelButtons()
	local holder = Widgets.Frame({
		parent = self.gui,
		name = "PanelButtons",
		size = UDim2.fromOffset(104, #PANEL_BUTTONS * 40),
		position = UDim2.fromOffset(18, 136),
		transparency = 1,
	})
	HudScale.Attach(holder)
	Widgets.List(holder, 7)

	for order, entry in PANEL_BUTTONS do
		Widgets.Button({
			parent = holder,
			name = entry.id,
			text = entry.text,
			textSize = 12,
			order = order,
			size = UDim2.fromOffset(104, 33),
			color = Theme.PanelRaised,
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
	local prompt = Widgets.Glass({
		parent = self.gui,
		name = "Prompt",
		size = UDim2.fromOffset(330, 40),
		position = UDim2.new(0.5, 0, 1, -42),
		anchor = Vector2.new(0.5, 1),
		corner = Theme.CornerPill,
	})

	self.promptLabel = Widgets.Text({
		parent = prompt,
		name = "Label",
		text = "Click the water to cast",
		font = Theme.FontBold,
		textSize = 14,
		align = Enum.TextXAlignment.Center,
	})

	HudScale.Attach(prompt)
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
		size = UDim2.fromOffset(340, 200),
		position = UDim2.new(0.5, 0, 0, 18),
		anchor = Vector2.new(0.5, 0),
		transparency = 1,
		zIndex = 20,
	})

	local layout = Widgets.List(holder, 7)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center

	HudScale.Attach(holder)
	self.notifyHolder = holder
end

function Hud:Notify(text: string, kind: string?)
	local color = Theme.NotifyColors[kind or "info"] or Theme.Accent

	local card = Widgets.Glass({
		parent = self.notifyHolder,
		name = "Notification",
		size = UDim2.fromOffset(318, 34),
		corner = Theme.CornerSmall,
		tint = color,
		zIndex = 20,
	})

	Widgets.Text({
		parent = card,
		text = text,
		font = Theme.FontMedium,
		textSize = 13,
		color = color,
		align = Enum.TextXAlignment.Center,
	})

	Widgets.PopIn(card, 0.9)

	task.delay(3.2, function()
		if card.Parent then
			Widgets.Tween(card, 0.25, { BackgroundTransparency = 1 })
			for _, child in card:GetDescendants() do
				if child:IsA("TextLabel") then
					Widgets.Tween(child, 0.25, { TextTransparency = 1 })
				elseif child:IsA("UIStroke") then
					Widgets.Tween(child, 0.25, { Transparency = 1 })
				end
			end
			task.wait(0.28)
			card:Destroy()
		end
	end)
end

-- Rare catch feed --------------------------------------------------------------------

function Hud:BuildFeed()
	local holder = Widgets.Frame({
		parent = self.gui,
		name = "Feed",
		size = UDim2.fromOffset(330, 170),
		position = UDim2.new(0, 18, 1, -18),
		anchor = Vector2.new(0, 1),
		transparency = 1,
	})

	local layout = Widgets.List(holder, 5)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	HudScale.Attach(holder)
	self.feedLayout = layout
	self.feedHolder = holder
end

function Hud:SetFeed(entries)
	for _, child in self.feedHolder:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	local start = math.max(#entries - 5, 0) + 1
	for index = start, #entries do
		local entry = entries[index]
		local tier = Rarities.Data[entry.rarity]
		local mutation = Mutations.Data[entry.mutation]
		local color = (mutation and entry.mutation ~= "None" and mutation.color)
			or (tier and tier.color)
			or Theme.Text

		local row = Widgets.Glass({
			parent = self.feedHolder,
			name = "FeedRow",
			size = UDim2.fromOffset(330, 26),
			corner = Theme.CornerSmall,
			tint = color,
			transparency = 0.18,
			order = index,
		})
		Widgets.Padding(row, 4, 9)

		Widgets.Text({
			parent = row,
			text = string.format(
				'<font color="#%s">%s</font>  hooked  <font color="#%s"><b>%s</b></font>',
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
	local mutated = result.mutation ~= "None"
	local color = (mutated and mutation and mutation.color) or (tier and tier.color) or Theme.Text

	local rarityIndex = Rarities.IndexOf(result.rarity)
	local mutationIndex = Mutations.IndexOf(result.mutation)
	local peak = math.max(rarityIndex, mutationIndex)

	local card = Widgets.Glass({
		parent = self.gui,
		name = "CatchCard",
		size = UDim2.fromOffset(330, 236),
		position = UDim2.new(0.5, 0, 0.5, 96),
		anchor = Vector2.new(0.5, 0.5),
		tint = color,
		strokeThickness = 2,
		zIndex = 30,
	})
	HudScale.Attach(card)
	Widgets.Padding(card, 14)
	self.catchCard = card

	-- A light sweep across the card. Only for the top tiers, where it reads as
	-- an event rather than noise.
	if peak >= 6 then
		local sweep = Widgets.Frame({
			parent = card,
			name = "Sweep",
			size = UDim2.fromScale(1, 1),
			color = Color3.new(1, 1, 1),
			transparency = 0.86,
			zIndex = 1,
		})
		Widgets.Corner(sweep, Theme.Corner)

		local gradient = Widgets.Gradient(sweep, { color, color }, 18, NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.45, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(0.55, 0.55),
			NumberSequenceKeypoint.new(1, 1),
		}))
		gradient.Offset = Vector2.new(-1, 0)

		TweenService:Create(
			gradient,
			TweenInfo.new(1.6, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1),
			{ Offset = Vector2.new(1, 0) }
		):Play()
	end

	-- The fish itself, slowly turning.
	FishView.Create({
		parent = card,
		name = "Catch",
		fishId = result.fishId,
		mutation = result.mutation,
		weight = result.weight,
		size = UDim2.new(1, 0, 0, 100),
		position = UDim2.fromOffset(0, 2),
		spin = true,
		spinSpeed = 0.55,
		tint = color,
		zIndex = 3,
	})

	Widgets.Text({
		parent = card,
		text = result.name,
		font = Theme.FontBlack,
		textSize = 21,
		color = color,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 26),
		position = UDim2.fromOffset(0, 108),
		zIndex = 3,
		glow = color,
		glowTransparency = peak >= 5 and 0.45 or 0.75,
	})

	Widgets.Text({
		parent = card,
		text = string.format(
			"%s%s  ·  %s",
			mutated and (string.upper(result.mutation) .. "  ·  ") or "",
			string.upper(result.rarity),
			Format.Odds(result.odds)
		),
		font = Theme.FontBold,
		textSize = 11,
		color = Theme.TextDim,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 138),
		zIndex = 3,
	})

	Widgets.Text({
		parent = card,
		text = Format.Weight(result.weight),
		font = Theme.FontMedium,
		textSize = 15,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 20),
		position = UDim2.fromOffset(0, 158),
		zIndex = 3,
	})

	Widgets.Text({
		parent = card,
		text = string.format("+%s", Format.Commas(result.value)),
		font = Theme.FontBlack,
		textSize = 19,
		color = Theme.Coin,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 24),
		position = UDim2.fromOffset(0, 182),
		zIndex = 3,
		glow = Theme.Coin,
		glowTransparency = 0.7,
	})

	Widgets.Text({
		parent = card,
		text = result.autoSold and "bag full — sold automatically" or "added to your bag",
		textSize = 11,
		color = result.autoSold and Theme.Warn or Theme.TextFaint,
		align = Enum.TextXAlignment.Center,
		size = UDim2.new(1, 0, 0, 14),
		position = UDim2.fromOffset(0, 208),
		zIndex = 3,
	})

	Widgets.PopIn(card, 0.8)

	if peak >= 6 then
		self:Flash(color, 0.16 + (peak - 6) * 0.06)
	end

	task.delay(3.6, function()
		if card.Parent then
			Widgets.Tween(card, 0.3, { BackgroundTransparency = 1 })
			for _, child in card:GetDescendants() do
				if child:IsA("TextLabel") then
					Widgets.Tween(child, 0.3, { TextTransparency = 1 })
				elseif child:IsA("UIStroke") then
					Widgets.Tween(child, 0.3, { Transparency = 1 })
				elseif child:IsA("Frame") then
					Widgets.Tween(child, 0.3, { BackgroundTransparency = 1 })
				end
			end
			task.wait(0.34)
			card:Destroy()
			if self.catchCard == card then
				self.catchCard = nil
			end
		end
	end)
end

function Hud:Flash(color: Color3, strength: number)
	self.flash.BackgroundColor3 = color
	self.flash.BackgroundTransparency = 1 - math.clamp(strength, 0, 0.5)
	Widgets.Tween(self.flash, 0.75, { BackgroundTransparency = 1 })
end

-- Stats --------------------------------------------------------------------

function Hud:SetProfile(profile, zoneName: string)
	self.coinLabel.Text = Format.Commas(profile.coins)
	self.zoneLabel.Text = zoneName
	self.levelLabel.Text = string.format("LV %d", profile.level)
	self.luckLabel.Text = string.format("×%.2f LUCK", profile.luck)
	self.bagLabel.Text = string.format(
		"BAG %d/%d  ·  WORTH %s",
		#profile.inventory,
		profile.bagLimit,
		Format.Abbreviate(profile.bagValue)
	)

	local ratio = profile.xpForLevel > 0 and profile.xpInLevel / profile.xpForLevel or 0
	Widgets.Tween(self.xpFill, 0.3, { Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1) })
end

return Hud
