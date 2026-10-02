--[[
	📍 LOCATION: StarterPlayer > StarterPlayerScripts > ClientModules > Menus > GiftsMenu (ModuleScript)

	"Free Rewards!" — 12 playtime gifts in a 4×3 grid with countdowns. Resets every session.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RewardConfig = require(Shared.Config.RewardConfig)
local Format = require(Shared.Format)
local RewardUtil = require(Shared.RewardUtil)

local Modules = script.Parent.Parent
local UIKit = require(Modules.UIKit)
local State = require(Modules.State)

local GiftsMenu = {}

local SIZE_STYLE = {
	Small = { Colors = UIKit.Colors.Blue, Icon = 0.42 },
	Medium = { Colors = UIKit.Colors.Purple, Icon = 0.52 },
	Big = { Colors = UIKit.Colors.Yellow, Icon = 0.62 },
}

function GiftsMenu.Build(ctx)
	local panel = UIKit.Panel({ Parent = ctx.Screen, Title = "Free Rewards!", Emoji = "🎁", Size = UDim2.fromOffset(780, 590), Colors = UIKit.Colors.Pink })
	local content = panel.Content

	local header = UIKit.Label({ Text = "0/12 Gifts Claimed", TextColor3 = Color3.fromRGB(255, 120, 190), StrokeThickness = 3, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 10), Parent = content })

	local grid = UIKit.Create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -64), Position = UDim2.fromOffset(0, 60), Parent = content })
	UIKit.Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(170, 145),
		CellPadding = UDim2.fromOffset(12, 12),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})

	local cells = {}
	for i, gift in ipairs(RewardConfig.Gifts) do
		local style = SIZE_STYLE[gift.Size] or SIZE_STYLE.Small
		local card = UIKit.Card({ LayoutOrder = i, Colors = style.Colors, Parent = grid, CornerRadius = 18 })
		local icon = UIKit.Label({ Text = "🎁", StrokeThickness = 0, Size = UDim2.fromScale(style.Icon, style.Icon), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Parent = card })
		local rewardText = UIKit.Label({ Text = "", Size = UDim2.new(1, -10, 0, 20), Position = UDim2.new(0, 5, 0.58, -8), StrokeThickness = 2, Parent = card })
		if gift.HugeChance then
			UIKit.Label({ Text = string.format("%g%% HUGE", gift.HugeChance * 100), TextColor3 = Color3.fromRGB(255, 230, 90), Size = UDim2.new(1, -10, 0, 18), Position = UDim2.fromOffset(5, 4), TextXAlignment = Enum.TextXAlignment.Left, StrokeThickness = 2, Parent = card })
		end
		local button, buttonLabel = UIKit.Button({
			Text = "",
			Colors = UIKit.Colors.Gray,
			Size = UDim2.new(1, -20, 0, 38),
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Parent = card,
			OnClick = function()
				local result = State.Action("ClaimGift", i)
				ctx.HUD.Result(result)
				if result.ok then
					UIKit.Pop(card, 1.25)
				end
			end,
		})
		cells[i] = { Card = card, Icon = icon, Reward = rewardText, Button = button, ButtonLabel = buttonLabel, Gift = gift }
	end

	local menu = { Panel = panel }

	local function readyCount(data)
		local elapsed = State.Now() - (data.SessionStart or State.Now())
		local claimed, ready = 0, 0
		for i, gift in ipairs(RewardConfig.Gifts) do
			if data.GiftsClaimed and data.GiftsClaimed[tostring(i)] then
				claimed += 1
			elseif elapsed >= gift.Time then
				ready += 1
			end
		end
		return claimed, ready, elapsed
	end

	function menu.Refresh()
		local data = State.Data
		if not data then
			return
		end
		local claimed, _, elapsed = readyCount(data)
		header.Text = claimed .. "/" .. #RewardConfig.Gifts .. " Gifts Claimed"
		for i, cell in ipairs(cells) do
			local isClaimed = data.GiftsClaimed and data.GiftsClaimed[tostring(i)]
			cell.Reward.Text = (RewardUtil.Describe(cell.Gift.Reward, State.Income))
			if isClaimed then
				cell.ButtonLabel.Text = "Claimed"
				UIKit.SetButtonColors(cell.Button, UIKit.Colors.Dark)
				cell.Icon.Text = "📭"
			elseif elapsed >= cell.Gift.Time then
				cell.ButtonLabel.Text = "CLAIM!"
				UIKit.SetButtonColors(cell.Button, UIKit.Colors.Green)
				cell.Icon.Text = "🎁"
			else
				cell.ButtonLabel.Text = Format.Clock(cell.Gift.Time - elapsed)
				UIKit.SetButtonColors(cell.Button, UIKit.Colors.Gray)
				cell.Icon.Text = "🎁"
			end
		end
	end

	menu.Tick = menu.Refresh

	function menu.Badge()
		local data = State.Data
		if not data then
			return nil
		end
		local _, ready = readyCount(data)
		return ready > 0 and ready or nil
	end

	return menu
end

return GiftsMenu
