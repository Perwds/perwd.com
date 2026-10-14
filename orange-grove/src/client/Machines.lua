--!strict
-- Machine screens, machine controls, locked-zone dimming and barriers, and the little moving parts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Palette = require(Shared.Palette)
local Format = require(Shared.Format)
local State = require(script.Parent.State)
local Hud = require(script.Parent.Hud)
local Audio = require(script.Parent.Audio)

local Machines = {}

local player = Players.LocalPlayer
local remotes: Folder

type Screen = {
	id: string,
	zone: string,
	content: Frame,
	labels: { [string]: TextLabel },
	fill: Frame,
	prompt: ProximityPrompt?,
	on: boolean?,
	active: boolean,
}

local screens: { [string]: Screen } = {}
local zoneParts: { [string]: { { part: BasePart, color: Color3, material: Enum.Material } } } = {}
local zoneOpenState: { [string]: boolean } = {}
local barriers: { BasePart } = {}
local spinners: { { part: BasePart, base: CFrame, speed: number, axis: Vector3 } } = {}
local bobbers: { { part: BasePart, base: CFrame, height: number, phase: number } } = {}

local DIM = Color3.new(0, 0, 0)
local homePrompt: ProximityPrompt? = nil

local function screenText(screen: Screen, snapshot: { [string]: any })
	local s, c, rates = snapshot.s, snapshot.c, snapshot.rates or {}
	local style = snapshot.settings.numbers
	local L = screen.labels
	local function amount(id: string, name: string)
		L.Amount.Text = Format.number(c[id] or 0, style) .. " " .. name
		L.Rate.Text = "(" .. Format.rate(rates[id] or 0, style) .. ")"
	end
	local running = snapshot.machines[screen.id] ~= false
	screen.active = false

	if screen.id == "press" then
		amount("oranges", "Oranges")
		L.Detail.Text = string.format(
			"%d picker%s at work\n%s oranges per pick",
			s.totalPickers,
			if s.totalPickers == 1 then "" else "s",
			Format.number(s.pickValue, style)
		)
		L.Status.Text = if s.totalPickers > 0 then "WORKING" else "IDLE"
		screen.active = s.totalPickers > 0
	elseif screen.id == "lab" then
		amount("vitamin", "mg Vitamin C")
		local boost = if snapshot.labBoostLeft > 0
			then "\nLab Boost: " .. Format.duration(snapshot.labBoostLeft) .. " left"
			else ""
		L.Detail.Text = string.format(
			"%s oranges -> %s mg, %s batches/s%s",
			Format.number(s.labCost, style),
			Format.number(s.labYield * s.prodMult * s.labBoost, style),
			Format.number(s.labSpeed, style),
			boost
		)
		local starved = (c.oranges or 0) < s.labCost
		L.Status.Text = if not running then "PAUSED" elseif starved then "NEEDS ORANGES" else "RUNNING"
		screen.active = running and not starved
	elseif screen.id == "zester" then
		amount("zest", "Zest")
		L.Detail.Text = string.format(
			"%s peels waiting\n%s peels/s, %s Zest each",
			Format.number(snapshot.peels or 0, style),
			Format.number(s.zesterSpeed, style),
			Format.number(s.zestYield * s.prodMult, style)
		)
		local starved = (snapshot.peels or 0) < 0.05
		L.Status.Text = if not running then "PAUSED" elseif starved then "NEEDS PEELS" else "RUNNING"
		screen.active = running and not starved
	elseif screen.id == "juice" then
		amount("crates", "Juice Crates")
		L.Detail.Text = string.format(
			"%s oranges + %s mg -> %s crate\n%s batches/s",
			Format.number(s.juiceOrangeCost, style),
			Format.number(s.juiceVitCost, style),
			Format.number(s.juiceYield * s.prodMult, style),
			Format.number(s.juiceSpeed, style)
		)
		local status = "RUNNING"
		if not running then
			status = "PAUSED"
		elseif (c.oranges or 0) < s.juiceOrangeCost then
			status = "NEEDS ORANGES"
		elseif (c.vitamin or 0) < s.juiceVitCost then
			status = "NEEDS VITAMIN C"
		end
		L.Status.Text = status
		screen.active = status == "RUNNING"
	elseif screen.id == "golden" then
		L.Amount.Text = Format.number(c.seeds or 0, style) .. " Golden Seeds"
		local pending = snapshot.pendingSeeds or 0
		L.Rate.Text = if pending > 0 then "Replant now for +" .. Format.number(pending, style) else "No seeds ready yet"
		local divisor = Config.Prestige.crateDivisor
		local nextSeed = (snapshot.seedsClaimed or 0) + pending + 1
		local need = divisor * (nextSeed / s.seedMult) ^ 2
		L.Detail.Text = string.format(
			"%s crates made so far\nnext seed at %s crates",
			Format.number(snapshot.lifetimeCrates or 0, style),
			Format.number(math.ceil(need), style)
		)
		L.Status.Text = if pending > 0 then "READY" else "GROWING"
		screen.active = pending > 0
	end

	if screen.prompt then
		if screen.id == "golden" then
			screen.prompt.Enabled = State.zoneOpen("golden") and (snapshot.pendingSeeds or 0) > 0
		else
			screen.prompt.Enabled = State.zoneOpen(screen.zone)
			screen.prompt.ActionText = if running then "Pause" else "Run"
		end
	end
end

local function setScreenPower(screen: Screen, on: boolean, animate: boolean)
	if screen.on == on then
		return
	end
	screen.on = on
	local function show(visible: boolean)
		for name, label in screen.labels do
			label.Visible = visible or name == "Title"
		end
		screen.fill.Parent.Visible = visible
	end
	if on and animate and not State.reduceMotion() then
		-- Old screens never come on cleanly.
		task.spawn(function()
			for _, step in { true, false, true, false, true } do
				show(step)
				task.wait(0.07)
			end
		end)
	else
		show(on)
	end
end

local function bindMachine(model: Model)
	local id = model:GetAttribute("Machine") :: string?
	if not id then
		return
	end
	local screenPart = model:WaitForChild("Screen") :: BasePart
	local content = (screenPart:WaitForChild("Display") :: SurfaceGui):WaitForChild("Content") :: Frame
	local labels = {}
	for _, name in { "Title", "Status", "Amount", "Rate", "Detail" } do
		labels[name] = content:WaitForChild(name) :: TextLabel
	end
	local screen: Screen = {
		id = id,
		zone = model:GetAttribute("Zone") :: string,
		content = content,
		labels = labels,
		fill = (content:WaitForChild("Bar") :: Frame):WaitForChild("Fill") :: Frame,
		prompt = screenPart:FindFirstChild("Control") :: ProximityPrompt?,
		on = nil,
		active = false,
	}
	if screen.prompt then
		screen.prompt.Triggered:Connect(function()
			if id == "golden" then
				local snapshot = State.current
				local seeds = if snapshot then snapshot.pendingSeeds else 0
				Hud.confirm(
					"REPLANT THE GROVE?",
					"You get "
						.. seeds
						.. " Golden Seed"
						.. (if seeds == 1 then "" else "s")
						.. ". Oranges, Vitamin C, Zest, crates and their upgrades start over. Gold-ringed plates stay. Spend your seeds here, then walk home from this screen.",
					"Replant",
					"Not yet",
					function()
						remotes.Replant:FireServer()
					end
				)
			else
				remotes.ToggleMachine:FireServer(id)
			end
		end)
	end
	screens[id] = screen

	local plinth = model:FindFirstChild("Plinth")
	local home = plinth and plinth:FindFirstChild("Home") :: ProximityPrompt?
	if home then
		homePrompt = home
		home.Triggered:Connect(function()
			remotes.GoHome:FireServer()
		end)
	end
end

local function collectZone(model: Model)
	local id = model:GetAttribute("Zone") :: string
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(list, { part = d, color = d.Color, material = d.Material })
		end
	end
	zoneParts[id] = list
end

local function paintZone(id: string, open: boolean, animate: boolean)
	if zoneOpenState[id] == open then
		return
	end
	local first = zoneOpenState[id] == nil
	zoneOpenState[id] = open
	for _, entry in zoneParts[id] or {} do
		if open then
			entry.part.Color = entry.color
			entry.part.Material = entry.material
		else
			entry.part.Color = entry.color:Lerp(DIM, 0.62)
			if entry.material == Enum.Material.Neon then
				entry.part.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	if open and not first and animate then
		Audio.chime()
		Hud.toast(string.upper(Config.Zones[id].title) .. " IS OPEN", Palette.zones[id].neon)
		if not State.reduceMotion() then
			local camera = workspace.CurrentCamera
			task.spawn(function()
				for i = 1, 6 do
					camera.CFrame *= CFrame.new((math.random() - 0.5) * 0.3 / i, (math.random() - 0.5) * 0.3 / i, 0)
					task.wait()
				end
			end)
		end
	end
end

local function paintBarriers()
	for _, barrier in barriers do
		local a = barrier:GetAttribute("ZoneA") :: string
		local b = barrier:GetAttribute("ZoneB") :: string
		local openA, openB = State.zoneOpen(a), State.zoneOpen(b)
		local blocking = not (openA and openB)
		local lockedZone = if openA then b else a
		barrier.CanCollide = blocking
		barrier.Transparency = if blocking then 0.55 else 1
		barrier.Color = Palette.zones[lockedZone].neon
	end
end

local function render(snapshot: { [string]: any }, previous: { [string]: any }?)
	for id in zoneParts do
		paintZone(id, State.zoneOpen(id), previous ~= nil)
	end
	paintBarriers()
	if homePrompt then
		-- Only needed when the Juice Bar is shut and the way back is blocked.
		homePrompt.Enabled = State.zoneOpen("golden") and not State.zoneOpen("juice")
	end
	for _, screen in screens do
		local open = State.zoneOpen(screen.zone)
		setScreenPower(screen, open, previous ~= nil)
		if open then
			screenText(screen, snapshot)
		elseif screen.prompt then
			screen.prompt.Enabled = false
		end
	end
end

function Machines.init(remoteFolder: Folder)
	remotes = remoteFolder
	local board = workspace:WaitForChild("Board")
	local zones = board:WaitForChild("Zones")
	for _, zone in zones:GetChildren() do
		collectZone(zone :: Model)
		for _, d in zone:GetDescendants() do
			if d:IsA("Model") and d:GetAttribute("Machine") then
				bindMachine(d)
			end
		end
	end
	for _, barrier in board:WaitForChild("Barriers"):GetChildren() do
		table.insert(barriers, barrier :: BasePart)
	end
	for _, d in board:GetDescendants() do
		if d:IsA("BasePart") then
			local spin = d:GetAttribute("Spin") :: number?
			if spin then
				table.insert(spinners, {
					part = d,
					base = d.CFrame,
					speed = math.rad(spin),
					axis = (d:GetAttribute("SpinAxis") :: Vector3?) or Vector3.yAxis,
				})
			end
			local bob = d:GetAttribute("Bob") :: number?
			if bob then
				table.insert(bobbers, { part = d, base = d.CFrame, height = bob, phase = math.random() * 6 })
			end
		end
	end

	State.onChange(render)

	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		for _, s in spinners do
			s.part.CFrame = s.base * CFrame.fromAxisAngle(s.axis, t * s.speed)
		end
		for _, b in bobbers do
			b.part.CFrame = b.base
				* CFrame.new(0, math.sin(t * 1.4 + b.phase) * b.height, 0)
				* CFrame.Angles(0, t * 0.8, 0)
		end
		-- Busy machines run their progress bar; idle ones sit empty.
		for _, screen in screens do
			if screen.on then
				local period = 1.6
				screen.fill.Size = if screen.active
					then UDim2.fromScale((t % period) / period, 1)
					else UDim2.fromScale(0, 1)
			end
		end
	end)
	player.CharacterAdded:Connect(function()
		paintBarriers()
	end)
end

return Machines
