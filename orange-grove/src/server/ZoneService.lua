--!strict
-- Keeps players out of zones they haven't opened and triggers the keeper's first-visit line.
-- Barriers are drawn and collided on the client; this is the server's backstop.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Data = require(script.Parent.Data)
local Remotes = require(script.Parent.Remotes)
local BoardBuilder = require(script.Parent.BoardBuilder)
local UpgradeService = require(script.Parent.UpgradeService)

local ZoneService = {}

local lastSafe: { [Player]: CFrame } = {}

function ZoneService.isOpen(player: Player, zoneId: string): boolean
	local unlock = Config.Zones[zoneId].unlock
	if unlock == nil then
		return true
	end
	if unlock == "vip" then
		return UpgradeService.mods(player).VIP == true
	end
	return UpgradeService.stats(player)[unlock] == true
end

local function check(player: Player)
	local data = Data.get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not data or not root then
		return
	end
	local zoneId = BoardBuilder.zoneAt(root.Position)
	if not zoneId then
		return
	end
	if not ZoneService.isOpen(player, zoneId) then
		local back = lastSafe[player] or BoardBuilder.spawnCFrame
		character:PivotTo(back)
		Remotes.fire("Notice", player, "zoneLocked", { zone = zoneId })
		return
	end
	lastSafe[player] = root.CFrame
	if not data.seenAreas[zoneId] then
		data.seenAreas[zoneId] = true
		Remotes.fire("KeeperLine", player, zoneId)
	end
end

function ZoneService.init()
	Players.PlayerRemoving:Connect(function(player)
		lastSafe[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				check(player)
			end
		end
	end)
end

return ZoneService
