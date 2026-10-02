--[[
	Shrink It! · Toolbox model importer  (run ONCE in Roblox Studio's COMMAND BAR, not in-game)

	View → Command Bar, paste this whole file, press Enter.

	For every object in ObjectConfig it searches the Roblox Toolbox (free models), takes the first
	result that loads, CLEANS it (removes every script, sound, seat, click/prompt, humanoid) and
	saves it as ReplicatedStorage > ShrinkableTemplates > <ObjectId>.
	The game then uses those real 3D models in the world, on pedestals and in the menu previews,
	scaled automatically to the right size.

	• Objects that already have a template are skipped. Delete one to re-import it, or replace it by
	  hand with any model you like better (just keep the name = the object id, e.g. "Car").
	• Look over the results! Free models vary in quality. Change SEARCH below and run again for
	  any that look wrong.
	• Then File → Publish (or Save) so the templates are stored in your place.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- better search words for some objects (default = the object's display name)
local SEARCH = {
	SodaCan = "soda can",
	GardenGnome = "garden gnome",
	Tree = "low poly tree",
	Statue = "statue",
	House = "low poly house",
	Mountain = "low poly mountain",
	Volcano = "low poly volcano",
	Glacier = "iceberg",
	TheMoon = "moon",
	HugeTeddy = "teddy bear",
	HugeCrystal = "crystal",
	HugeDragon = "dragon",
}
local RESULTS_TO_TRY = 6

local ObjectConfig = require(ReplicatedStorage.Shared.Config.ObjectConfig)

local folder = ReplicatedStorage:FindFirstChild("ShrinkableTemplates")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "ShrinkableTemplates"
	folder.Parent = ReplicatedStorage
end

local REMOVE = { "LuaSourceContainer", "Sound", "ClickDetector", "ProximityPrompt", "Humanoid", "Tool", "BodyMover", "Constraint", "Explosion", "Fire", "Smoke", "ForceField", "Dialog" }

local function clean(model)
	for _, d in ipairs(model:GetDescendants()) do
		for _, class in ipairs(REMOVE) do
			if d:IsA(class) then
				d:Destroy()
				break
			end
		end
	end
	local parts = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			d.Disabled = true
		end
		if d:IsA("BasePart") then
			parts += 1
			d.Anchored = true
			d.CanCollide = false
		end
	end
	return parts
end

local function tryAsset(assetId, id)
	local ok, objects = pcall(function()
		return game:GetObjects("rbxassetid://" .. assetId)
	end)
	if not ok or not objects or #objects == 0 then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = id
	for _, obj in ipairs(objects) do
		obj.Parent = model
	end
	if clean(model) == 0 then
		model:Destroy()
		return nil
	end
	local _, size = model:GetBoundingBox()
	if size.Magnitude < 0.5 or size.Magnitude > 5000 then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
	return model
end

local imported, skipped, failed = 0, 0, {}
for _, id in ipairs(ObjectConfig.AllIds()) do
	local def = ObjectConfig.Get(id)
	if folder:FindFirstChild(id) then
		skipped += 1
	elseif def then
		local query = SEARCH[id] or def.Name
		local ok, pages = pcall(function()
			return InsertService:GetFreeModels(query, 0)
		end)
		local results = ok and pages and pages[1] and pages[1].Results or {}
		local model
		for i = 1, math.min(RESULTS_TO_TRY, #results) do
			model = tryAsset(results[i].AssetId, id)
			if model then
				model:SetAttribute("SourceAssetId", results[i].AssetId)
				model:SetAttribute("SourceName", results[i].Name)
				break
			end
		end
		if model then
			model.Parent = folder
			imported += 1
			print(string.format("✅ %s ← \"%s\" (asset %s)", id, model:GetAttribute("SourceName") or "?", tostring(model:GetAttribute("SourceAssetId"))))
		else
			table.insert(failed, id)
			warn("❌ " .. id .. ": nothing usable found for \"" .. query .. "\"" .. (ok and "" or (" (" .. tostring(pages) .. ")")))
		end
		task.wait(0.2)
	end
end
print(string.format("Shrink It! importer: %d imported, %d already had a model, %d not found%s", imported, skipped, #failed, #failed > 0 and (" → " .. table.concat(failed, ", ")) or ""))
print("Look them over in ReplicatedStorage > ShrinkableTemplates, then Publish / Save your place.")
