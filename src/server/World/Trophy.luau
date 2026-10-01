--!nonstrict
-- Holds the catch up over the player's head for a few seconds. Server-side, so
-- everyone on the pier sees what you landed, not just you.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local FishModel = require(Shared.FishModel)
local Fish = require(Shared.Config.Fish)

local Trophy = {}

local HOLD_SECONDS = 3.4
local NAME = "CatchTrophy"

local active: { [Player]: Model } = {}

local function clear(player: Player)
	local existing = active[player]
	if existing then
		existing:Destroy()
		active[player] = nil
	end
end

function Trophy.Show(player: Player, fishId: string, mutation: string, weight: number)
	local character = player.Character
	if not character then
		return
	end

	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	clear(player)

	local ok, model = pcall(FishModel.Build, fishId, mutation, weight)
	if not ok or not model.PrimaryPart then
		warn(string.format("[Trophy] could not build %s: %s", tostring(fishId), tostring(model)))
		return
	end

	model.Name = NAME

	local record = Fish.Get(fishId)
	local length = FishModel.DisplayLength(record, weight)

	-- Sat above the head, turned side-on so the silhouette reads, and tipped
	-- back slightly so it looks held rather than floating.
	model:PivotTo(
		head.CFrame
			* CFrame.new(0, length * 0.42 + 1.6, 0)
			* CFrame.Angles(0, math.rad(-74), math.rad(14))
	)

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart

	model.Parent = character
	active[player] = model

	Debris:AddItem(model, HOLD_SECONDS)
	task.delay(HOLD_SECONDS, function()
		if active[player] == model then
			active[player] = nil
		end
	end)
end

function Trophy.Start()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterRemoving:Connect(function()
			clear(player)
		end)
	end)

	Players.PlayerRemoving:Connect(clear)
end

return Trophy
