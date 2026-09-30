--[[
	Keeps you from seeing the "Steal Egg" prompt on your own back.

	A ProximityPrompt is visible to every client in range, including the
	player it is parented to, and there is no server-side per-player filter.
	The server still owns whether the prompt is enabled (it only is while you
	are carrying), so this re-applies the local override every time the
	server flips it back on.
]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer

local PromptController = {}

local function guard(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end

	local prompt = root:WaitForChild("StealPrompt", 10) :: ProximityPrompt?
	if not prompt then
		return
	end

	local function enforce()
		if prompt.Enabled then
			prompt.Enabled = false
		end
	end

	prompt:GetPropertyChangedSignal("Enabled"):Connect(enforce)
	enforce()
end

function PromptController.start()
	player.CharacterAdded:Connect(function(character)
		task.spawn(guard, character)
	end)

	if player.Character then
		task.spawn(guard, player.Character)
	end
end

return PromptController
