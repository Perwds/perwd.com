--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > InfinitePackMenu (ModuleScript)

	Infinite Pack: horizontal chain of FREE / R$ tiles connected by arrows, refresh countdown,
	"NEW Rewards & Buffed Odds!" subtitle, preview row of upcoming rewards, and an ODDS view
	for any tile with a random reward (Roblox policy).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardConfig = require(Shared.Config.RewardConfig)
local Format = require(Shared.Format)
local RewardUtil = require(Shared.RewardUtil)
local Gen = require(Shared.InfinitePackGen)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)
local Prices = require(Modules.Prices)

local InfinitePackMenu = {}

local cfg = RewardConfig.InfinitePack

local function showOdds(ctx, reward)
	-- collect mystery pools inside the reward
	local pools = {}
	local function walk(r)
		if r.Type == "Mystery" then
			table.insert(pools, r.Pool)
		elseif r.Type == "Bundle" then
			for _, sub in ipairs(r.Rewards) do
				walk(sub)
			end
		end
	end
	walk(reward)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Odds", Emoji = "🎲", Size = UDim2.fromOffset(560, 460), Colors = UIKit.Colors.Orange })
	panel.Holder.ZIndex = 160
	local list = UIKit.Scroll({ Size = UDim2.new(1, 0, 1, -10), Position = UDim2.fromOffset(0, 16), Parent = panel.Content })
	UIKit.Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local order = 0
	for _, poolName in ipairs(pools) do
		local pool = RewardConfig.MysteryPools[poolName]
		order += 1
		UIKit.Label({ Text = pool and pool.Name or poolName, TextColor3 = Color3.fromRGB(255, 170, 60), StrokeThickness = 3, Size = UDim2.new(1, -10, 0, 36), LayoutOrder = order, Parent = list })
		for _, entry in ipairs(RewardUtil.Odds(poolName, State.Income)) do
			order += 1
			local row = UIKit.Card({ Size = UDim2.new(1, -12, 0, 44), LayoutOrder = order, Parent = list, CornerRadius = 12 })
			UIKit.Label({ Text = entry.Emoji .. "  " .. entry.Text, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Outline, StrokeThickness = 0, Size = UDim2.new(0.72, 0, 1, -12), Position = UDim2.fromOffset(12, 6), Parent = row })
			UIKit.Label({ Text = string.format("%.2f%%", entry.Percent), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Color3.fromRGB(40, 160, 60), StrokeThickness = 0, Size = UDim2.new(0.25, 0, 1, -12), Position = UDim2.new(0.73, 0, 0, 6), Parent = row })
		end
	end
	panel.OnClose:Connect(function()
		task.delay(0.3, function()
			panel.Holder:Destroy()
		end)
	end)
	panel.Open()
end

function InfinitePackMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Infinite Pack", Animated = true, Emoji = "♾️", Size = UDim2.fromOffset(940, 600), Colors = UIKit.Colors.Purple })
	local content = panel.Content

	local timer = UIKit.Label({ Text = "", TextColor3 = Color3.new(1, 1, 1), StrokeThickness = 3.5, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 12), Parent = content })
	UIKit.Label({ Text = "✨ NEW Rewards & Buffed Odds! ✨", TextColor3 = Color3.fromRGB(255, 220, 70), StrokeThickness = 3, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 52), Parent = content })

	local chain = UIKit.Scroll({ Horizontal = true, Size = UDim2.new(1, 0, 0, 262), Position = UDim2.fromOffset(0, 92), Parent = content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chain })
	UIKit.Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = chain })

	local credits = UIKit.Label({ Text = "", TextColor3 = Color3.fromRGB(120, 255, 140), StrokeThickness = 2.5, Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 360), Parent = content })

	UIKit.Label({ Text = "Coming up:", TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Outline, StrokeThickness = 0, Size = UDim2.fromOffset(160, 30), Position = UDim2.fromOffset(6, 392), Parent = content })
	local preview = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -170, 0, 58), Position = UDim2.fromOffset(166, 386), Parent = content })
	UIKit.Create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center, Parent = preview })

	UIKit.Label({
		Text = "Claim a tile to unlock the next one. Paid tiles are repeatable Developer Products. Tiles with 🎲 show their odds.",
		TextColor3 = Color3.fromRGB(90, 90, 110),
		StrokeThickness = 0,
		Size = UDim2.new(1, 0, 0, 40),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Parent = content,
	})

	local menu = { Panel = panel }
	local lastKey = nil

	local function currentProgress()
		local data = State.Data
		local season = Gen.Season(math.floor(State.Now()))
		local claimed = 0
		if data and data.InfinitePack.Season == season then
			claimed = data.InfinitePack.Claimed
		end
		return season, claimed
	end

	local function tileCard(tile, isNext, order)
		local paid = tile.Paid
		local card = UIKit.Card({
			Size = UDim2.fromOffset(160, 236),
			LayoutOrder = order,
			Colors = tile.Milestone and UIKit.Colors.Yellow or (paid and UIKit.Colors.Green or UIKit.Colors.Blue),
			Parent = chain,
			CornerRadius = 18,
			StrokeThickness = isNext and 5 or 3,
		})
		-- price tag
		local tag = UIKit.Card({ Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, -12), Colors = paid and UIKit.Colors.Dark or UIKit.Colors.Green, Parent = card, CornerRadius = 12 })
		local product = paid and Gen.ProductInfo(tile.Product)
		local priceText = paid and Prices.Get(Enum.InfoType.Product, product and product.Id, product and product.PriceLabel) or "FREE"
		UIKit.Label({ Text = priceText, Size = UDim2.new(1, -8, 1, -6), Position = UDim2.fromOffset(4, 3), StrokeThickness = 2.5, Parent = tag })

		local text, emoji = RewardUtil.Describe(tile.Reward, State.Income)
		UIKit.Label({ Text = emoji, StrokeThickness = 0, Size = UDim2.fromOffset(84, 84), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 30), Parent = card })
		UIKit.Label({ Text = text, Size = UDim2.new(1, -12, 0, 46), Position = UDim2.fromOffset(6, 118), StrokeThickness = 2.5, Parent = card })
		if tile.Milestone then
			UIKit.Label({ Text = "⭐ MILESTONE", TextColor3 = Color3.fromRGB(255, 240, 120), Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 162), StrokeThickness = 2, Parent = card })
		end
		if RewardUtil.IsRandom(tile.Reward) then
			UIKit.Button({ Text = "🎲 Odds", Colors = UIKit.Colors.Orange, Size = UDim2.fromOffset(80, 28), Position = UDim2.new(1, -86, 0, 30), Parent = card, OnClick = function()
				showOdds(ctx, tile.Reward)
			end })
		end
		if isNext then
			local data = State.Data
			local hasCredit = paid and data and (data.InfinitePack.Credits[tile.Product] or 0) > 0
			UIKit.Button({
				Text = (not paid) and "CLAIM!" or (hasCredit and "USE CREDIT" or "BUY"),
				Colors = paid and UIKit.Colors.Yellow or UIKit.Colors.Green,
				Size = UDim2.new(1, -20, 0, 44),
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Parent = card,
				OnClick = function()
					local result = State.Action(paid and "PackBuy" or "PackClaim")
					if result.msg or not result.ok then
						ctx.HUD.Result(result)
					end
				end,
			})
			UIKit.Pop(card, 1.08)
		else
			local lock = UIKit.Create("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = card })
			UIKit.Corner(lock, 18)
			UIKit.Label({ Text = "🔒", StrokeThickness = 0, Size = UDim2.fromOffset(44, 44), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), ZIndex = 6, Parent = lock })
		end
		return card
	end

	local function rebuild()
		local season, claimed = currentProgress()
		local data = State.Data
		local creditKey = ""
		if data then
			for k, v in pairs(data.InfinitePack.Credits) do
				creditKey ..= k .. v
			end
		end
		local key = season .. ":" .. claimed .. ":" .. math.floor(State.Income) .. ":" .. creditKey
		if key == lastKey then
			return
		end
		lastKey = key
		for _, c in ipairs(chain:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for _, c in ipairs(preview:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local order = 0
		local noRandom = not data or data.PaidRandomRestricted ~= false
		for i = claimed + 1, claimed + cfg.VisibleTiles do
			order += 1
			tileCard(Gen.GetTile(season, i, noRandom), i == claimed + 1, order)
			if i < claimed + cfg.VisibleTiles then
				order += 1
				UIKit.Label({ Text = "➜", TextColor3 = Color3.fromRGB(255, 255, 255), StrokeThickness = 3, Size = UDim2.fromOffset(34, 40), LayoutOrder = order, Parent = chain })
			end
		end
		chain.CanvasPosition = Vector2.zero
		for i = claimed + cfg.VisibleTiles + 1, claimed + cfg.VisibleTiles + cfg.PreviewTiles do
			local tile = Gen.GetTile(season, i, noRandom)
			local _, emoji = RewardUtil.Describe(tile.Reward, State.Income)
			local chip = UIKit.Card({ Size = UDim2.fromOffset(52, 52), Colors = tile.Paid and UIKit.Colors.Green or UIKit.Colors.Blue, LayoutOrder = i, Parent = preview, CornerRadius = 12 })
			UIKit.Label({ Text = emoji, StrokeThickness = 0, Size = UDim2.new(1, -10, 1, -10), Position = UDim2.fromOffset(5, 5), Parent = chip })
		end
		local creditLines = {}
		if data then
			for productKey, count in pairs(data.InfinitePack.Credits) do
				if count > 0 then
					local p = Gen.ProductInfo(productKey)
					table.insert(creditLines, count .. "x " .. (p and p.Name or productKey))
				end
			end
		end
		credits.Text = #creditLines > 0 and ("🎟️ Saved credits: " .. table.concat(creditLines, ", ")) or ""
	end

	function menu.Refresh()
		rebuild()
		menu.Tick()
	end

	function menu.Tick()
		timer.Text = "⏰ Refreshes in " .. Format.Clock(Gen.SecondsUntilRefresh(math.floor(State.Now())))
		local season = Gen.Season(math.floor(State.Now()))
		if State.Data and State.Data.InfinitePack.Season ~= season then
			rebuild()
		end
	end

	function menu.Badge()
		if not State.Data then
			return nil
		end
		local season, claimed = currentProgress()
		local tile = Gen.GetTile(season, claimed + 1, State.Data.PaidRandomRestricted ~= false)
		if not tile.Paid then
			return "FREE"
		end
		return nil
	end

	Prices.OnUpdated(function()
		lastKey = nil
		if panel.IsOpen() then
			rebuild()
		end
	end)

	return menu
end

return InfinitePackMenu
