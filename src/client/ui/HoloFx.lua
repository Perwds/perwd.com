--!strict
--[[
	HoloFx
	Animates every hologram in the world from the client.

	The panels are built by the server, but animating a GuiObject server-side
	replicates every property write to every player. Driving the sweep, bob and
	flicker locally is smoother, costs the network nothing, and lets the effect
	run per-frame instead of per-tick.

	Panels are found by CollectionService tag, so holograms created later (or
	streamed in) are picked up automatically.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local HoloFx = {}

local TAG = "Hologram"
local SWEEP_SECONDS = 2.6

type Panel = {
	gui: BillboardGui,
	plate: Frame,
	scan: Frame,
	rim: UIStroke?,
	phase: number,
	flickerAt: number,
}

local panels: { [BillboardGui]: Panel } = {}

local function track(instance: Instance)
	if not instance:IsA("BillboardGui") then
		return
	end

	local plate = instance:FindFirstChild("Plate") :: Frame?
	if not plate then
		return
	end

	local scan = plate:FindFirstChild("Scanline") :: Frame?
	if not scan then
		return
	end

	panels[instance] = {
		gui = instance,
		plate = plate,
		scan = scan,
		rim = plate:FindFirstChildOfClass("UIStroke"),
		-- Offset each panel so a street of them does not pulse in lockstep.
		phase = math.random() * math.pi * 2,
		flickerAt = os.clock() + math.random(3, 9),
	}
end

local function untrack(instance: Instance)
	panels[instance :: BillboardGui] = nil
end

function HoloFx.start()
	for _, instance in ipairs(CollectionService:GetTagged(TAG)) do
		track(instance)
	end

	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(untrack)

	RunService.RenderStepped:Connect(function()
		local now = os.clock()

		for gui, panel in pairs(panels) do
			if not gui.Parent then
				panels[gui] = nil
				continue
			end

			-- Scanline sweeps top to bottom on a loop.
			local sweep = ((now / SWEEP_SECONDS) + panel.phase) % 1
			panel.scan.Position = UDim2.fromScale(0, sweep)

			-- Slow bob, so the panel feels projected rather than pinned.
			gui.StudsOffsetWorldSpace = Vector3.new(0, math.sin(now * 1.4 + panel.phase) * 0.35, 0)

			-- Breathing rim.
			if panel.rim then
				panel.rim.Transparency = 0.1 + math.abs(math.sin(now * 1.1 + panel.phase)) * 0.25
			end

			-- Occasional flicker.
			if now >= panel.flickerAt then
				panel.flickerAt = now + math.random(4, 11)
				task.spawn(function()
					for _ = 1, 2 do
						panel.plate.BackgroundTransparency = 0.88
						task.wait(0.04)
						panel.plate.BackgroundTransparency = 0.62
						task.wait(0.05)
					end
				end)
			end
		end
	end)
end

return HoloFx
