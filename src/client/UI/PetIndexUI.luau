--[[
	The Pet Index.

	Left rail lists the worlds, the middle is that world's eight tiles plus a
	progress bar, the right shows the selected pet and the claimable reward.
	Undiscovered pets render as silhouettes on their rarity colour.
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

local PetIndexUI = {}

local panel
local selectedWorld = "Forest"
local selectedTab = "World"
local selectedPet = nil

local refs = {}

local function selectPet(entry)
	selectedPet = entry
	if not entry then
		return
	end

	refs.detailViewport:ClearAllChildren()
	PetViewport.create(entry.id, entry.known, { Parent = refs.detailViewport })

	refs.detailName.Text = entry.known and entry.name or "???"
	refs.detailRarity.Text = entry.rarity
	refs.detailRarity.TextColor3 = Rarity.get(entry.rarity).glow
	refs.detailIncome.Text = entry.known and `{Format.abbreviate(entry.income)}/s` or "???"
end

local function renderGrid()
	local data = selectedTab == "World" and State.indexForWorld(selectedWorld) or nil
	local slots = data and data.slots or State.data.index.limited or {}

	refs.grid:ClearAllChildren()
	Builder.grid(UDim2.fromOffset(108, 108), { Parent = refs.grid })

	for order, entry in slots do
		local tile, caption = PetViewport.tile(entry.id, entry.rarity, entry.known, {
			LayoutOrder = order,
			Parent = refs.grid,
		})
		caption.Text = entry.known and entry.name or "???"
		caption.TextScaled = false
		caption.TextSize = 13
		caption.Font = Theme.Font.body

		local button = Builder.make("TextButton", {
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 10,
			Parent = tile,
		})
		button.MouseButton1Click:Connect(function()
			selectPet(entry)
		end)

		if order == 1 and not selectedPet then
			selectPet(entry)
		end
	end

	-- Progress bar + totals.
	local found = data and data.found or 0
	local total = data and data.total or #slots

	refs.progressText.Text = `{found}/{total}`
	refs.progressFill.Size = UDim2.fromScale(total > 0 and found / total or 0, 1)
	refs.totalText.Text = `Unlocked: {State.data.index.totalFound}/{State.data.index.total}`

	-- Reward panel.
	local complete = data ~= nil and data.found >= data.total
	local claimed = data ~= nil and data.claimed

	refs.claimButton.Visible = selectedTab == "World"
	refs.rewardBox.Visible = selectedTab == "World"

	if claimed then
		refs.claimButton.Text = "CLAIMED"
		refs.claimButton.BackgroundColor3 = Theme.Color.grey
	elseif complete then
		refs.claimButton.Text = "CLAIM!"
		refs.claimButton.BackgroundColor3 = Theme.Color.green
	else
		refs.claimButton.Text = "LOCKED"
		refs.claimButton.BackgroundColor3 = Theme.Color.grey
	end
end

local function renderWorldList()
	refs.worldList:ClearAllChildren()
	Builder.list({ Padding = UDim.new(0, 6), Parent = refs.worldList })

	for order, entry in State.data.index.worlds do
		local isSelected = entry.world == selectedWorld and selectedTab == "World"

		local button = Builder.button(entry.display, {
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = isSelected and Theme.Color.headerBlue
				or (entry.unlocked and Theme.Color.panel or Theme.Color.panelInset),
			TextColor3 = entry.unlocked and Theme.Color.text or Theme.Color.textDim,
			LayoutOrder = order,
			Parent = refs.worldList,
		}, function()
			selectedTab = "World"
			selectedWorld = entry.world
			selectedPet = nil
			renderWorldList()
			renderGrid()
		end)

		Builder.label(`{entry.found}/{entry.total}`, {
			Name = "Count",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -4, 1, 0),
			Size = UDim2.fromOffset(46, 16),
			TextScaled = true,
			TextColor3 = entry.found >= entry.total and Theme.Color.money or Theme.Color.textDim,
			Parent = button,
		})
	end
end

function PetIndexUI.build(screen: ScreenGui)
	panel = Panel.new({
		name = "PetIndex",
		title = "Pet Index",
		size = UDim2.fromOffset(880, 540),
		headerColor = Theme.Color.headerBlue,
		parent = screen,
	})

	local body = panel.body

	-- ---------- left: world list ----------
	local left = Builder.make("Frame", {
		Name = "Worlds",
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(0, 140, 1, -20),
		BackgroundTransparency = 1,
		Parent = body,
	})
	refs.worldList = Builder.scroller({ Parent = left })

	-- ---------- middle: grid + progress ----------
	local middle = Builder.make("Frame", {
		Name = "Grid",
		Position = UDim2.fromOffset(160, 10),
		Size = UDim2.new(1, -420, 1, -20),
		BackgroundTransparency = 1,
		Parent = body,
	})

	refs.grid = Builder.scroller({
		Size = UDim2.new(1, 0, 1, -90),
		Parent = middle,
	})

	local bar, fill, text = Builder.progressBar({
		Position = UDim2.new(0, 0, 1, -80),
		Size = UDim2.new(1, 0, 0, 40),
		Parent = middle,
	})
	refs.progressBar, refs.progressFill, refs.progressText = bar, fill, text

	refs.totalText = Builder.label("Unlocked: 0/0", {
		Position = UDim2.new(0, 0, 1, -34),
		Size = UDim2.new(1, 0, 0, 34),
		Parent = middle,
	})

	-- ---------- right: detail + reward ----------
	local right = Builder.make("Frame", {
		Name = "Detail",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.new(0, 240, 1, -20),
		BackgroundTransparency = 1,
		Parent = body,
	})

	local detailCard = Builder.frame({
		Size = UDim2.new(1, 0, 0, 260),
		BackgroundColor3 = Theme.Color.panelInset,
		Parent = right,
	})

	refs.detailViewport = Builder.make("Frame", {
		Name = "Preview",
		Size = UDim2.new(1, -20, 0, 170),
		Position = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		Parent = detailCard,
	})

	refs.detailName = Builder.label("???", {
		Position = UDim2.new(0, 0, 0, 182),
		Size = UDim2.new(1, 0, 0, 30),
		Parent = detailCard,
	})

	refs.detailRarity = Builder.label("Common", {
		Position = UDim2.new(0, 0, 0, 210),
		Size = UDim2.new(1, 0, 0, 24),
		Parent = detailCard,
	})

	refs.detailIncome = Builder.label("???", {
		Position = UDim2.new(0, 0, 0, 232),
		Size = UDim2.new(1, 0, 0, 24),
		TextColor3 = Theme.Color.money,
		Parent = detailCard,
	})

	refs.rewardBox = Builder.frame({
		Position = UDim2.new(0, 0, 0, 270),
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundColor3 = Theme.Color.panelInset,
		Parent = right,
	}, { Builder.stroke(3, Theme.Color.green) })

	Builder.label("Rewards:", {
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = refs.rewardBox,
	})

	Builder.label(
		`$ {Balance.Rewards.INDEX_CASH}   +{Balance.Rewards.INDEX_SPEED} speed`,
		{
			Position = UDim2.fromOffset(10, 30),
			Size = UDim2.new(1, -20, 0, 26),
			TextColor3 = Theme.Color.money,
			Parent = refs.rewardBox,
		}
	)

	refs.claimButton = Builder.button("CLAIM!", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -20, 0, 46),
		BackgroundColor3 = Theme.Color.green,
		Parent = refs.rewardBox,
	}, function()
		local result = Net.Function("ClaimIndexReward"):InvokeServer(selectedWorld)
		if result and result.ok then
			Notify.push("success", `Claimed! +{Format.abbreviate(result.cash)} and +{result.speed} speed`)
			State.request()
		elseif result then
			Notify.push("warn", result.error or "Cannot claim yet")
		end
	end)

	-- ---------- tabs ----------
	panel:addTab("World", Theme.Color.headerBlue, function()
		selectedTab = "World"
		selectedPet = nil
		renderWorldList()
		renderGrid()
	end)

	panel:addTab("Limited", Theme.Color.headerGold, function()
		selectedTab = "Limited"
		selectedPet = nil
		renderWorldList()
		renderGrid()
	end)

	panel.onOpen = function()
		renderWorldList()
		renderGrid()
	end

	State.fullChanged:Connect(function()
		if panel.isOpen then
			renderWorldList()
			renderGrid()
		end
	end)

	return panel
end

function PetIndexUI.toggle()
	if panel then
		panel:toggle()
	end
end

return PetIndexUI
