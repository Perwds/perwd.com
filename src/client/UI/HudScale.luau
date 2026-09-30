--!nonstrict
-- Keeps every top-level HUD panel scaled to the viewport.
--
-- A UIScale is attached per panel rather than to one full-screen container: a
-- UIScale scales the object it sits on, so wrapping everything in one scaled
-- frame would shrink that frame and pull edge-anchored panels away from the
-- screen edges. Attached per panel, the panel's own Position is untouched (so
-- bottom/right anchoring still works) while its size and its children's offsets
-- scale together.

local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)

local HudScale = {}

local scales: { UIScale } = {}
local current = 1
local viewportConnection: RBXScriptConnection? = nil

local function compute(): number
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or GameConfig.HudReference
	return GameConfig.HudScale(viewport.X, viewport.Y, UserInputService.TouchEnabled)
end

local function apply()
	current = compute()

	for index = #scales, 1, -1 do
		local scale = scales[index]
		if scale.Parent then
			scale.Scale = current
		else
			table.remove(scales, index)
		end
	end
end

local function watchCamera()
	if viewportConnection then
		viewportConnection:Disconnect()
		viewportConnection = nil
	end

	local camera = Workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(apply)
	end
end

-- Attach to a top-level panel. Safe to call before Start.
function HudScale.Attach(target: GuiObject): UIScale
	local scale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = current
	scale.Parent = target

	table.insert(scales, scale)
	return scale
end

function HudScale.Current(): number
	return current
end

function HudScale.Start()
	watchCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		watchCamera()
		apply()
	end)

	apply()
end

return HudScale
