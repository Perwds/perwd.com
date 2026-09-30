--[[
	Server bootstrap.

	Order matters twice: the map has to exist before anything looks up a
	pedestal or a plot, and DataService has to be listening before the first
	PlayerAdded fires. Everything after that is independent.
]]

local MapBuilder = require(script.World.MapBuilder)

local Services = script.Services

-- Started in order. Each module exposes a `start()` and nothing else that
-- runs at require time, so requiring them all first is safe.
local ORDER = {
	"DataService",
	"PlotService",
	"PetService",
	"IndexService",
	"UgcService",
	"EggSpawnService",
	"CarryService",
	"HatchService",
	"ShopService",
	"FuseService",
	"PropService",
	"WorldEventService",
	"PlaytimeService",
	"StateService",
	"LeaderstatsService",
}

local started = os.clock()

MapBuilder.build()

for _, name in ORDER do
	local module = Services:FindFirstChild(name)
	if not module then
		warn(`[Server] missing service "{name}"`)
		continue
	end

	local service = require(module)
	if type(service.start) ~= "function" then
		warn(`[Server] service "{name}" has no start()`)
		continue
	end

	local ok, err = pcall(service.start)
	if not ok then
		warn(`[Server] "{name}" failed to start: {err}`)
	end
end

print(string.format("[StealAPet] server ready in %.2fs", os.clock() - started))
