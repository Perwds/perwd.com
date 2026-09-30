--[[
	The UGC tab.

	Every item shows its requirement and live progress toward it, so a locked
	card is a goal rather than a dead end. Three states:

	  LOCKED    requirement not met -- shows progress
	  CLAIM     earned, not yet delivered
	  OWNED     delivered

	Items whose asset id is still 0 show a "Coming Soon" badge but can still
	be unlocked and will become claimable the moment the id is filled in.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)
local Ugc = require(ReplicatedStorage.Shared.Config.Ugc)

local Builder = require(script.Parent.Builder)
local Notify = require(script.Parent.Notify)
local Panel = require(script.Parent.Panel)
local State = require(script.Parent.Parent.Controllers.State)
local Theme = require(script.Parent.Theme)

local UgcUI = {}

local panel
local refs = {}
local activeFilter = "all"

local SOURCE_LABEL = {
	hatch = "Egg Drop",
	index = "Index",
	playtime = "Playtime",
	daily = "Daily",
	shop = "Shop",
}

--[[
	Progress toward an item's requirement, as (current, goal). Returns nil for
	sources that are not a countable progression.
]]
local function progressFor(entry): (number?, number?)
	if entry.source == "playtime" then
		local config = Ugc.get(entry.id)
		return State.data.playtime, config and config.seconds
	elseif entry.source == "daily" then
		local config = Ugc.get(entry.id)
		return State.data.dailyStreak, config and config.days
	elseif entry.source == "index" then
		local config = Ugc.get(entry.id)
		if not config then
			return nil, nil
		end
		if config.world == "All" then
			return State.data.index.totalFound, State.data.index.total
		end
		local worldEntry = State.indexForWorld(config.world)
		return worldEntry and worldEntry.found, worldEntry and worldEntry.total
	end
	return nil, nil
end

local function progressText(entry): string
	local current, goal = progressFor(entry)
	if not current or not goal then
		return entry.requirement
	end

	if entry.source == "playtime" then
		return `{Format.duration(math.min(current, goal))} / {Format.duration(goal)}`
	end
	return `{math.min(current, goal)} / {goal}`
end

local function card(entry, order: number)
	local info = Rarity.get(entry.rarity)

	local frame = Builder.frame({
		Name = entry.id,
		Size = UDim2.fromOffset(200, 250),
		BackgroundColor3 = Theme.Color.panelInset,
		LayoutOrder = order,
		Parent = refs.grid,
	}, {
		Builder.stroke(3, entry.unlocked and info.glow or Theme.Color.stroke),
	})

	-- Preview swatch. Swap for an ImageLabel with the item's thumbnail once
	-- assetId is real: rbxthumb://type=Asset&id=<assetId>&w=420&h=420
	local preview = Builder.frame({
		Name = "Preview",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 110),
		BackgroundColor3 = info.color,
		Parent = frame,
	}, { Builder.gradient(info.glow, info.color, 90) })

	if entry.assetId and entry.assetId ~= 0 then
		Builder.make("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = `rbxthumb://type=Asset&id={entry.assetId}&w=420&h=420`,
			ZIndex = 2,
			Parent = preview,
		})
	else
		Builder.label("?", {
			Size = UDim2.fromScale(1, 1),
			TextTransparency = 0.35,
			ZIndex = 2,
			Parent = preview,
		})
	end

	if not entry.unlocked then
		Builder.make("Frame", {
			Name = "Dim",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.55,
			Size = UDim2.fromScale(1, 1),
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = preview,
		}, { Builder.corner() })
	end

	-- Source badge.
	Builder.label(SOURCE_LABEL[entry.source] or entry.source, {
		Name = "Source",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(86, 22),
		BackgroundColor3 = Theme.Color.panelDeep,
		BackgroundTransparency = 0.15,
		TextScaled = false,
		TextSize = 14,
		Font = Theme.Font.body,
		ZIndex = 5,
		Parent = frame,
	})

	if entry.placeholder then
		Builder.label("Coming Soon", {
			Name = "Soon",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(94, 22),
			BackgroundColor3 = Theme.Color.headerGold,
			TextScaled = false,
			TextSize = 13,
			Font = Theme.Font.body,
			TextColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 1,
			BackgroundTransparency = 0,
			ZIndex = 5,
			Parent = frame,
		})
	end

	Builder.label(entry.name, {
		Position = UDim2.fromOffset(10, 126),
		Size = UDim2.new(1, -20, 0, 26),
		TextColor3 = info.glow,
		Parent = frame,
	})

	Builder.label(entry.rarity, {
		Position = UDim2.fromOffset(10, 152),
		Size = UDim2.new(1, -20, 0, 20),
		TextScaled = false,
		TextSize = 15,
		Font = Theme.Font.body,
		TextColor3 = Theme.Color.textDim,
		Parent = frame,
	})

	Builder.label(entry.unlocked and entry.requirement or progressText(entry), {
		Position = UDim2.fromOffset(10, 172),
		Size = UDim2.new(1, -20, 0, 32),
		TextScaled = false,
		TextSize = 14,
		Font = Theme.Font.body,
		TextWrapped = true,
		TextColor3 = Theme.Color.textDim,
		Parent = frame,
	})

	-- Action button.
	local text, color, action

	if entry.claimed then
		text, color = "OWNED", Theme.Color.grey
	elseif entry.unlocked then
		text, color = "CLAIM", Theme.Color.green
		action = function()
			local result = Net.Function("ClaimUgc"):InvokeServer(entry.id)
			if not result then
				return
			end
			if result.ok then
				if result.mode == "prompted" then
					Notify.push("info", "Accept the Roblox prompt to receive your item")
				else
					Notify.push("success", `{entry.name} is yours!`)
				end
				State.request()
			else
				Notify.push(result.placeholder and "info" or "warn", result.error or "Could not claim")
			end
		end
	elseif entry.source == "shop" then
		local affordable = State.data.cash >= (entry.price or math.huge)
		text = Format.abbreviate(entry.price or 0)
		color = affordable and Theme.Color.gold or Theme.Color.grey
		action = function()
			local result = Net.Function("BuyUgc"):InvokeServer(entry.id)
			if result and result.ok then
				Notify.push("success", `Unlocked {entry.name}! Hit CLAIM to receive it.`)
				State.request()
			elseif result then
				Notify.push("warn", result.error or "Could not buy")
			end
		end
	else
		text, color = "LOCKED", Theme.Color.grey
	end

	Builder.button(text, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 42),
		BackgroundColor3 = color,
		Parent = frame,
	}, action)
end

local function render()
	refs.grid:ClearAllChildren()
	Builder.grid(UDim2.fromOffset(200, 250), { CellPadding = UDim2.fromOffset(10, 10), Parent = refs.grid })

	local owned, total = 0, 0

	for order, entry in State.data.ugc do
		total += 1
		if entry.unlocked then
			owned += 1
		end
		if activeFilter == "all" or entry.source == activeFilter then
			card(entry, order)
		end
	end

	refs.summary.Text = `Unlocked: {owned}/{total}`
end

function UgcUI.build(screen: ScreenGui)
	panel = Panel.new({
		name = "Ugc",
		title = "UGC Rewards",
		size = UDim2.fromOffset(880, 560),
		headerColor = Theme.Color.headerPurple,
		parent = screen,
	})

	refs.summary = Builder.label("Unlocked: 0/0", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = panel.body,
	})

	refs.grid = Builder.scroller({
		Position = UDim2.fromOffset(10, 42),
		Size = UDim2.new(1, -20, 1, -52),
		Parent = panel.body,
	})

	local filters = {
		{ id = "all", label = "All", color = Theme.Color.headerPurple },
		{ id = "hatch", label = "Drops", color = Theme.Color.headerGold },
		{ id = "index", label = "Index", color = Theme.Color.headerBlue },
		{ id = "playtime", label = "Playtime", color = Theme.Color.headerGreen },
		{ id = "daily", label = "Daily", color = Theme.Color.blue },
		{ id = "shop", label = "Shop", color = Theme.Color.gold },
	}

	for _, filter in filters do
		panel:addTab(filter.label, filter.color, function()
			activeFilter = filter.id
			render()
		end)
	end

	panel.onOpen = render
	State.fullChanged:Connect(function()
		if panel.isOpen then
			render()
		end
	end)

	-- A fresh unlock pops a toast even when the panel is shut.
	Net.Event("UgcUnlocked").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		Notify.push(
			"success",
			payload.placeholder and `UGC unlocked: {payload.name} (claimable when it drops)`
				or `UGC unlocked: {payload.name}! Open the UGC tab to claim.`
		)
	end)

	return panel
end

function UgcUI.toggle()
	if panel then
		panel:toggle()
	end
end

return UgcUI
