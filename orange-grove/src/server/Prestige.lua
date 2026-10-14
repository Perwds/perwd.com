--!strict
-- Replant the Grove: trade this run's progress for Golden Seeds. Gold-ringed nodes stay.

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Data = require(script.Parent.Data)
local Currency = require(script.Parent.Currency)
local Remotes = require(script.Parent.Remotes)
local UpgradeService = require(script.Parent.UpgradeService)
local BoardBuilder = require(script.Parent.BoardBuilder)

local Prestige = {}

local RESET_CURRENCIES = { "oranges", "vitamin", "zest", "crates" }
local REACH = 22

local econ = UpgradeService.econ

local function nearGoldenTree(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local machine = BoardBuilder.machinePosition("golden")
	return root ~= nil and machine ~= nil and (root.Position - machine).Magnitude <= REACH
end

function Prestige.replant(player: Player): (boolean, number)
	local data = Data.get(player)
	if not data then
		return false, 0
	end
	local s = UpgradeService.stats(player)
	if not s.goldenOpen then
		return false, 0
	end
	local seeds = econ:pendingSeeds(data, s)
	if seeds < Config.Prestige.minSeeds then
		return false, 0
	end

	local kept = econ:keptNodes(data.levels)
	local levels = {}
	for id, level in data.levels do
		local rule = kept[id]
		if rule == "full" then
			levels[id] = level
		elseif rule == "one" and level > 0 then
			levels[id] = 1
		end
	end
	data.levels = levels

	local before = table.clone(data.currencies)
	for _, id in RESET_CURRENCIES do
		data.currencies[id] = 0
	end
	data.peels = 0
	data.currencies.seeds += seeds
	data.seedsClaimed += seeds
	data.replants += 1
	data.machines = { lab = true, zester = true, juice = true }

	UpgradeService.refresh(player)
	data.currencies.oranges = UpgradeService.stats(player).startOranges
	-- Keep the resets out of the rate display.
	before.oranges = data.currencies.oranges
	for _, id in RESET_CURRENCIES do
		if id ~= "oranges" then
			before[id] = 0
		end
	end
	before.seeds = data.currencies.seeds
	Currency.recordDelta(player, before)
	Currency.pushNow(player)
	task.spawn(Data.save, player)
	return true, seeds
end

function Prestige.init()
	-- The Golden Tree sits past the Juice Bar, which a Replant locks again, so it offers a way home.
	Remotes.on("GoHome", function(player: Player)
		local character = player.Character
		if character and nearGoldenTree(player) then
			character:PivotTo(BoardBuilder.spawnCFrame)
		end
	end)

	Remotes.on("Replant", function(player: Player)
		if not nearGoldenTree(player) then
			return
		end
		local ok, seeds = Prestige.replant(player)
		Remotes.fire("Notice", player, if ok then "replanted" else "replantDenied", { seeds = seeds })
	end)
end

return Prestige
