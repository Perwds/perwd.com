--!nonstrict
-- The five panels behind the HUD buttons. Each Render* function rebuilds its
-- tab from the latest profile snapshot; there is no incremental diffing, which
-- keeps the UI impossible to desync from the server's view.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local Fish = require(Shared.Config.Fish)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Util.Format)

local Theme = require(script.Parent.Theme)
local Widgets = require(script.Parent.Widgets)

local Panels = {}
Panels.__index = Panels

local TITLES = {
	bag = "Your Bag",
	rods = "Rods",
	zones = "Zones",
	index = "Fish Index",
	board = "Leaderboards",
}

function Panels.new(screenGui: ScreenGui, callbacks)
	local self = setmetatable({}, Panels)
	self.callbacks = callbacks or {}
	self.profile = nil
	self.leaderboards = {}
	self.current = nil

	self:Build(screenGui)
	return self
end

function Panels:Build(screenGui: ScreenGui)
	local root = Widgets.Glass({
		parent = screenGui,
		name = "Panel",
		size = UDim2.fromOffset(576, 442),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		tint = Theme.Accent,
		strokeThickness = 1.8,
		transparency = 0.02,
		visible = false,
		zIndex = 15,
	})
	self.root = root

	self.title = Widgets.Text({
		parent = root,
		name = "Title",
		text = "",
		font = Theme.FontBlack,
		textSize = 19,
		size = UDim2.new(1, -80, 0, 30),
		position = UDim2.fromOffset(20, 16),
	})

	Widgets.Button({
		parent = root,
		name = "Close",
		text = "✕",
		size = UDim2.fromOffset(30, 30),
		position = UDim2.new(1, -44, 0, 14),
		onClick = function()
			self:Close()
		end,
	})

	self.subtitle = Widgets.Text({
		parent = root,
		name = "Subtitle",
		text = "",
		textSize = 12,
		color = Theme.TextDim,
		size = UDim2.new(1, -36, 0, 16),
		position = UDim2.fromOffset(18, 42),
	})

	self.body = Widgets.Scroller({
		parent = root,
		name = "Body",
		size = UDim2.new(1, -36, 1, -110),
		position = UDim2.fromOffset(18, 66),
	})
	Widgets.List(self.body, 6)

	self.footer = Widgets.Frame({
		parent = root,
		name = "Footer",
		size = UDim2.new(1, -36, 0, 34),
		position = UDim2.new(0, 18, 1, -44),
		transparency = 1,
	})
end

-- Row helpers -------------------------------------------------------------------

function Panels:Row(order: number, height: number?, tint: Color3?)
	local row = Widgets.Glass({
		parent = self.body,
		name = "Row",
		size = UDim2.new(1, -8, 0, height or 44),
		corner = Theme.CornerSmall,
		tint = tint,
		transparency = tint and 0.1 or 0.16,
		order = order,
	})
	Widgets.Padding(row, 10, 12)
	return row
end

function Panels:Clear()
	for _, child in self.body:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	self.footer:ClearAllChildren()
end

-- Bag -------------------------------------------------------------------------

function Panels:RenderBag()
	local profile = self.profile
	self.subtitle.Text = string.format(
		"%d / %d slots · worth %s coins",
		#profile.inventory,
		profile.bagLimit,
		Format.Commas(profile.bagValue)
	)

	if #profile.inventory == 0 then
		Widgets.Text({
			parent = self.body,
			text = "Empty. Go catch something.",
			textSize = 13,
			color = Theme.TextDim,
			size = UDim2.new(1, 0, 0, 40),
			align = Enum.TextXAlignment.Center,
		})
	end

	-- Best fish first, so the sell-one button is always on something worth it.
	local sorted = table.clone(profile.inventory)
	table.sort(sorted, function(a, b)
		return a.value > b.value
	end)

	for order, entry in sorted do
		local record = Fish.ById[entry.fishId]
		if not record then
			continue
		end

		local tier = Rarities.Get(entry.rarity)
		local mutation = Mutations.Get(entry.mutation)
		local color = entry.mutation ~= "None" and mutation.color or tier.color

		local row = self:Row(order, 44, color)

		Widgets.Text({
			parent = row,
			text = (mutation.prefix ~= "" and mutation.prefix .. " " or "") .. record.name,
			font = Theme.FontMedium,
			textSize = 14,
			color = color,
			size = UDim2.new(0.55, 0, 0, 16),
		})

		Widgets.Text({
			parent = row,
			text = string.format("%s · %s", entry.rarity, Format.Weight(entry.weight)),
			textSize = 11,
			color = Theme.TextDim,
			size = UDim2.new(0.55, 0, 0, 14),
			position = UDim2.fromOffset(0, 18),
		})

		Widgets.Text({
			parent = row,
			text = Format.Commas(entry.value),
			font = Theme.FontBold,
			textSize = 14,
			color = Theme.Coin,
			align = Enum.TextXAlignment.Right,
			size = UDim2.new(0.25, 0, 1, 0),
			position = UDim2.new(0.5, 0, 0, 0),
		})

		Widgets.Button({
			parent = row,
			text = "Sell",
			size = UDim2.fromOffset(58, 26),
			position = UDim2.new(1, -58, 0.5, 0),
			anchor = Vector2.new(0, 0.5),
			onClick = function()
				if self.callbacks.onSell then
					self.callbacks.onSell(entry.uid)
				end
			end,
		})
	end

	Widgets.Button({
		parent = self.footer,
		text = string.format("Sell everything (%s coins)", Format.Abbreviate(profile.bagValue)),
		color = Theme.Good:Lerp(Theme.Background, 0.55),
		size = UDim2.fromScale(1, 1),
		onClick = function()
			if self.callbacks.onSell then
				self.callbacks.onSell("all")
			end
		end,
	})
end

-- Rods -------------------------------------------------------------------------

function Panels:RenderRods()
	local profile = self.profile
	self.subtitle.Text = "Better rods mean better luck and an easier reel."

	for order, rod in profile.rods do
		local row = self:Row(order, 48, rod.equipped and Theme.Good or nil)

		Widgets.Text({
			parent = row,
			text = rod.name,
			font = Theme.FontMedium,
			textSize = 14,
			color = rod.owned and Theme.Text or Theme.TextDim,
			size = UDim2.new(0.6, 0, 0, 16),
		})

		Widgets.Text({
			parent = row,
			text = string.format(
				"x%.2f luck · %s",
				rod.luck,
				rod.cost == 0 and "starter" or (Format.Abbreviate(rod.cost) .. " coins")
			),
			textSize = 11,
			color = Theme.TextDim,
			size = UDim2.new(0.6, 0, 0, 14),
			position = UDim2.fromOffset(0, 18),
		})

		if rod.equipped then
			Widgets.Text({
				parent = row,
				text = "EQUIPPED",
				font = Theme.FontBold,
				textSize = 11,
				color = Theme.Good,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0.35, 0, 1, 0),
				position = UDim2.new(0.65, 0, 0, 0),
			})
		elseif rod.owned then
			Widgets.Button({
				parent = row,
				text = "Equip",
				size = UDim2.fromOffset(78, 28),
				position = UDim2.new(1, -78, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				onClick = function()
					if self.callbacks.onEquipRod then
						self.callbacks.onEquipRod(rod.id)
					end
				end,
			})
		else
			local affordable = profile.coins >= rod.cost
			Widgets.Button({
				parent = row,
				text = affordable and "Buy" or Format.Abbreviate(rod.cost),
				color = affordable and Theme.Accent:Lerp(Theme.Background, 0.5) or Theme.PanelRaised,
				textColor = affordable and Theme.Text or Theme.TextDim,
				size = UDim2.fromOffset(78, 28),
				position = UDim2.new(1, -78, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				onClick = function()
					if self.callbacks.onBuyRod then
						self.callbacks.onBuyRod(rod.id)
					end
				end,
			})
		end
	end
end

-- Zones -------------------------------------------------------------------------

function Panels:RenderZones()
	local profile = self.profile
	self.subtitle.Text = string.format(
		"Unlocks track lifetime coins: %s earned so far.",
		Format.Abbreviate(profile.lifetimeCoins)
	)

	for order, zone in profile.zones do
		local row = self:Row(order, 54, zone.current and Theme.Good or nil)

		Widgets.Text({
			parent = row,
			text = zone.name,
			font = Theme.FontMedium,
			textSize = 14,
			color = zone.unlocked and Theme.Text or Theme.TextDim,
			size = UDim2.new(0.62, 0, 0, 16),
		})

		Widgets.Text({
			parent = row,
			text = zone.blurb,
			textSize = 11,
			color = Theme.TextDim,
			size = UDim2.new(0.62, 0, 0, 14),
			position = UDim2.fromOffset(0, 18),
		})

		Widgets.Text({
			parent = row,
			text = string.format("x%.2f zone luck", zone.luckBonus),
			textSize = 11,
			color = Theme.Accent,
			size = UDim2.new(0.62, 0, 0, 14),
			position = UDim2.fromOffset(0, 34),
		})

		if zone.current then
			Widgets.Text({
				parent = row,
				text = "HERE",
				font = Theme.FontBold,
				textSize = 11,
				color = Theme.Good,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0.3, 0, 1, 0),
				position = UDim2.new(0.7, 0, 0, 0),
			})
		elseif zone.unlocked then
			Widgets.Button({
				parent = row,
				text = "Travel",
				size = UDim2.fromOffset(82, 28),
				position = UDim2.new(1, -82, 0.5, 0),
				anchor = Vector2.new(0, 0.5),
				onClick = function()
					if self.callbacks.onTravel then
						self.callbacks.onTravel(zone.id)
					end
				end,
			})
		else
			Widgets.Text({
				parent = row,
				text = string.format("%s lifetime", Format.Abbreviate(zone.unlockCoins)),
				font = Theme.FontMedium,
				textSize = 11,
				color = Theme.Warn,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0.3, 0, 1, 0),
				position = UDim2.new(0.7, 0, 0, 0),
			})
		end
	end
end

-- Index -------------------------------------------------------------------------

function Panels:RenderIndex()
	local profile = self.profile

	local discovered = 0
	for _ in profile.index do
		discovered += 1
	end

	self.subtitle.Text = string.format("%d / %d species discovered", discovered, Fish.Count())

	local order = 0
	for _, zoneId in Zones.Order do
		local zone = Zones.Get(zoneId)

		order += 1
		Widgets.Text({
			parent = self.body,
			text = string.upper(zone.name),
			font = Theme.FontBlack,
			textSize = 12,
			color = Theme.TextFaint,
			size = UDim2.new(1, 0, 0, 22),
			order = order,
		})

		for _, record in Fish.All do
			if record.zone ~= zoneId then
				continue
			end

			order += 1
			local found = profile.index[record.id]
			local tier = Rarities.Get(record.rarity)
			local row = self:Row(order, 38, found and tier.color or nil)

			Widgets.Text({
				parent = row,
				text = found and record.name or "???",
				font = Theme.FontMedium,
				textSize = 13,
				color = found and tier.color or Theme.TextDim,
				size = UDim2.new(0.5, 0, 1, 0),
			})

			Widgets.Text({
				parent = row,
				text = record.rarity,
				textSize = 11,
				color = tier.color,
				align = Enum.TextXAlignment.Center,
				size = UDim2.new(0.25, 0, 1, 0),
				position = UDim2.new(0.5, 0, 0, 0),
			})

			Widgets.Text({
				parent = row,
				text = found
					and string.format("x%d · best %s", found.count, Format.Weight(found.best))
					or "undiscovered",
				textSize = 11,
				color = Theme.TextDim,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0.25, 0, 1, 0),
				position = UDim2.new(0.75, 0, 0, 0),
			})
		end
	end
end

-- Leaderboards -------------------------------------------------------------------

function Panels:RenderBoard()
	self.subtitle.Text = "Refreshed from the global store every couple of minutes."

	local order = 0
	local any = false

	for _, boardId in { "bestCatch", "lifetimeCoins" } do
		local board = self.leaderboards[boardId]
		if not board then
			continue
		end

		any = true
		order += 1
		Widgets.Text({
			parent = self.body,
			text = string.upper(board.title),
			font = Theme.FontBlack,
			textSize = 12,
			color = Theme.TextFaint,
			size = UDim2.new(1, 0, 0, 22),
			order = order,
		})

		for _, entry in board.rows do
			order += 1
			local row = self:Row(order, 30)

			Widgets.Text({
				parent = row,
				text = string.format("#%d  %s", entry.rank, entry.name),
				textSize = 12,
				size = UDim2.new(0.7, 0, 1, 0),
			})

			Widgets.Text({
				parent = row,
				text = Format.Abbreviate(entry.value),
				font = Theme.FontMedium,
				textSize = 12,
				color = Theme.Coin,
				align = Enum.TextXAlignment.Right,
				size = UDim2.new(0.3, 0, 1, 0),
				position = UDim2.new(0.7, 0, 0, 0),
			})
		end
	end

	if not any then
		Widgets.Text({
			parent = self.body,
			text = "No scores yet — the boards fill in as people play.",
			textSize = 13,
			color = Theme.TextDim,
			align = Enum.TextXAlignment.Center,
			size = UDim2.new(1, 0, 0, 40),
		})
	end
end

-- Lifecycle -------------------------------------------------------------------

function Panels:Refresh()
	if not self.current or not self.profile then
		return
	end

	self:Clear()
	self.title.Text = TITLES[self.current] or ""

	if self.current == "bag" then
		self:RenderBag()
	elseif self.current == "rods" then
		self:RenderRods()
	elseif self.current == "zones" then
		self:RenderZones()
	elseif self.current == "index" then
		self:RenderIndex()
	elseif self.current == "board" then
		self:RenderBoard()
	end
end

function Panels:Open(id: string)
	if self.current == id and self.root.Visible then
		self:Close()
		return
	end

	self.current = id
	self.root.Visible = true
	Widgets.PopIn(self.root, 0.9)
	self:Refresh()
end

function Panels:Close()
	self.root.Visible = false
	self.current = nil
end

function Panels:IsOpen(): boolean
	return self.root.Visible
end

function Panels:SetProfile(profile)
	self.profile = profile
	if self.root.Visible then
		self:Refresh()
	end
end

function Panels:SetLeaderboards(boards)
	self.leaderboards = boards or {}
	if self.root.Visible and self.current == "board" then
		self:Refresh()
	end
end

return Panels
