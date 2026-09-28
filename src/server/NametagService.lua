--!strict
--[[
	NametagService
	Replaces the default Roblox name label with a mounted plate above the
	character: display name, rank, rebirth title, and whichever stat the player
	has pinned from the scanner.

	Built server-side and parented into the character, so every player sees
	every other player's plate without any client work.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Palette = require(Shared.Palette)
local Format = require(Shared.Format)
local StatConfig = require(Shared.StatConfig)
local RankConfig = require(Shared.RankConfig)
local RebirthConfig = require(Shared.RebirthConfig)

local DataService = require(script.Parent.DataService)
local StateService = require(script.Parent.StateService)

local NametagService = {}

local PLATE_NAME = "StatPlate"

local function build(character: Model, player: Player)
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end

	local existing = head:FindFirstChild(PLATE_NAME)
	if existing then
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = PLATE_NAME
	billboard.Size = UDim2.fromOffset(240, 66)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 120
	billboard.LightInfluence = 0
	billboard.Parent = head

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.AnchorPoint = Vector2.new(0.5, 1)
	plate.Position = UDim2.fromScale(0.5, 1)
	plate.Size = UDim2.fromOffset(240, 62)
	plate.BackgroundColor3 = Palette.dark
	plate.BackgroundTransparency = 0.12
	plate.BorderSizePixel = 0
	plate.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = plate

	local rim = Instance.new("UIStroke")
	rim.Name = "Rim"
	rim.Thickness = 2
	rim.Color = Palette.shadowDeep
	rim.Parent = plate

	-- Name
	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.Position = UDim2.fromOffset(10, 4)
	name.Size = UDim2.new(1, -20, 0, 20)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.Text = player.DisplayName
	name.TextColor3 = Palette.darkText
	name.TextSize = 16
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = plate

	-- Rank / rebirth line
	local rank = Instance.new("TextLabel")
	rank.Name = "Rank"
	rank.Position = UDim2.fromOffset(10, 23)
	rank.Size = UDim2.new(1, -20, 0, 14)
	rank.BackgroundTransparency = 1
	rank.Font = Enum.Font.RobotoMono
	rank.Text = ""
	rank.TextColor3 = Palette.darkTextMuted
	rank.TextSize = 11
	rank.Parent = plate

	-- The pinned stat, in a recessed strip.
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.AnchorPoint = Vector2.new(0.5, 1)
	strip.Position = UDim2.new(0.5, 0, 1, -5)
	strip.Size = UDim2.new(1, -20, 0, 18)
	strip.BackgroundColor3 = Palette.darkSlate
	strip.BorderSizePixel = 0
	strip.Visible = false
	strip.Parent = plate

	local stripCorner = Instance.new("UICorner")
	stripCorner.CornerRadius = UDim.new(1, 0)
	stripCorner.Parent = strip

	local stat = Instance.new("TextLabel")
	stat.Name = "Stat"
	stat.Size = UDim2.fromScale(1, 1)
	stat.BackgroundTransparency = 1
	stat.Font = Enum.Font.RobotoMono
	stat.Text = ""
	stat.TextColor3 = Palette.accent
	stat.TextSize = 12
	stat.TextTruncate = Enum.TextTruncate.AtEnd
	stat.Parent = strip

	-- Our plate carries the name, so switch off the built-in one.
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	return billboard
end

local function plateFor(player: Player): BillboardGui?
	local character = player.Character
	if not character then
		return nil
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return nil
	end
	return head:FindFirstChild(PLATE_NAME) :: BillboardGui?
end

function NametagService.refresh(player: Player)
	local billboard = plateFor(player)
	local profile = DataService.get(player)
	if not billboard or not profile then
		return
	end

	local plate = billboard:FindFirstChild("Plate")
	if not plate then
		return
	end

	local rankLabel = plate:FindFirstChild("Rank") :: TextLabel?
	local strip = plate:FindFirstChild("Strip") :: Frame?
	local statLabel = strip and strip:FindFirstChild("Stat") :: TextLabel?
	local rim = plate:FindFirstChild("Rim") :: UIStroke?

	local score = StateService.scoreFor(profile)
	local rank = RankConfig.forScore(score)
	local title = RebirthConfig.title(profile.rebirths)

	if rankLabel then
		local pieces = { rank.name:upper() }
		if profile.rebirths > 0 then
			table.insert(pieces, ("R%d"):format(profile.rebirths))
		end
		if title ~= "" then
			table.insert(pieces, title:upper())
		end
		rankLabel.Text = table.concat(pieces, "  /  ")
		rankLabel.TextColor3 = rank.color
	end

	if rim then
		rim.Color = profile.rebirths > 0 and Palette.accent or Palette.shadowDeep
	end

	-- Pinned stat
	local pinnedId = profile.displayStat or ""
	local stat = pinnedId ~= "" and StatConfig.get(pinnedId) or nil
	local value = stat and profile.values[stat.id] or nil

	if strip and statLabel then
		if stat and value ~= nil and profile.scanned[stat.id] then
			statLabel.Text = ("%s  %s"):format(stat.name, Format.value(stat.format, value))
			strip.Visible = true
		else
			strip.Visible = false
		end
	end
end

--- Sets which stat rides above the player's head. An empty string clears it.
function NametagService.setDisplayStat(player: Player, statId: string): boolean
	local profile = DataService.get(player)
	if not profile then
		return false
	end

	if statId == "" then
		profile.displayStat = ""
		NametagService.refresh(player)
		StateService.markDirty(player)
		return true
	end

	local stat = StatConfig.get(statId)
	if not stat then
		return false
	end

	-- You can only display something you have actually scanned.
	if not profile.scanned[statId] or profile.values[statId] == nil then
		StateService.notify(player, "Scan it before you pin it.", "PIN", Palette.ledAmber)
		return false
	end

	profile.displayStat = statId
	NametagService.refresh(player)
	StateService.notify(player, ("Pinned %s above your head."):format(stat.name), "PIN", Palette.accent)
	StateService.markDirty(player)
	return true
end

function NametagService.init()
	local function attach(player: Player)
		local function onCharacter(character: Model)
			-- The head can take a moment to replicate on a fresh spawn.
			task.defer(function()
				if build(character, player) then
					NametagService.refresh(player)
				end
			end)
		end

		player.CharacterAdded:Connect(onCharacter)
		if player.Character then
			onCharacter(player.Character)
		end
	end

	Players.PlayerAdded:Connect(attach)
	for _, player in ipairs(Players:GetPlayers()) do
		attach(player)
	end

	-- Any state change can move the rank or the pinned value.
	StateService.onPush(function(player)
		NametagService.refresh(player)
	end)
end

return NametagService
