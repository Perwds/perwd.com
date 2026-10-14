--!strict
-- Machine ticks (pickers, Lab, Zester, Juice Bar) and offline catch-up on join.

local Players = game:GetService("Players")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Data = require(script.Parent.Data)
local Currency = require(script.Parent.Currency)
local Remotes = require(script.Parent.Remotes)
local UpgradeService = require(script.Parent.UpgradeService)

local Production = {}

local TICK = 0.5
local TOGGLEABLE = { lab = true, zester = true, juice = true }

local econ = UpgradeService.econ
local ready: { [Player]: boolean } = {}
local boostWasActive: { [Player]: boolean } = {}

local function snapshot(currencies: { [string]: number }): { [string]: number }
	return table.clone(currencies)
end

function Production.offlineCatchUp(player: Player, data: { [string]: any })
	local s = UpgradeService.stats(player)
	local cap = s.offlineHours * 3600
	local away = if data.lastOnline > 0 then os.time() - data.lastOnline else 0
	if cap <= 0 or away < Config.Offline.minSeconds then
		return
	end
	local seconds = math.min(away, cap)
	local before = snapshot(data.currencies)
	local steps = Config.Offline.steps
	for _ = 1, steps do
		econ:step(data, s, seconds / steps)
	end
	local gains = {}
	for id, value in data.currencies do
		local delta = value - (before[id] or 0)
		if delta > 0.5 then
			gains[id] = delta
		end
	end
	Remotes.fire("Notice", player, "offline", { seconds = seconds, away = away, gains = gains })
end

function Production.init()
	Data.onLoaded(function(player, profile)
		-- Pass ownership changes pickers and multipliers, so wait for it before catching up.
		local started = os.clock()
		while not player:GetAttribute("PassesReady") and os.clock() - started < 8 and player.Parent do
			task.wait(0.1)
		end
		if not player.Parent then
			return
		end
		Production.offlineCatchUp(player, profile.data)
		ready[player] = true
		Currency.markDirty(player)
	end)

	Remotes.on("ToggleMachine", function(player: Player, machineId: string)
		local data = Data.get(player)
		if not data or not TOGGLEABLE[machineId] then
			return
		end
		data.machines[machineId] = not data.machines[machineId]
		Currency.pushNow(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		ready[player] = nil
		boostWasActive[player] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
			local dt = math.min(os.clock() - last, 2)
			last = os.clock()
			for player in ready do
				local data = Data.get(player)
				if data then
					local boosted = data.labBoostUntil > os.time()
					if boosted ~= (boostWasActive[player] or false) then
						boostWasActive[player] = boosted
						UpgradeService.refresh(player)
					end
					local before = snapshot(data.currencies)
					econ:step(data, UpgradeService.stats(player), dt)
					Currency.recordDelta(player, before)
				end
			end
		end
	end)
end

return Production
