--[[
	The hatch reveal.

	A short full-screen moment when an egg opens: rarity-coloured burst, the
	pet spinning in the middle, its name and income. Rarer pets get a longer
	hold and more rays, so a Mythic feels different from a Common without a
	separate cutscene.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)
local Rarity = require(ReplicatedStorage.Shared.Config.Rarity)

local Builder = require(script.Parent.Builder)
local PetViewport = require(script.Parent.PetViewport)
local Theme = require(script.Parent.Theme)

local HatchReveal = {}

local root: Frame
local refs = {}
local playing = false
local queue = {}

local function buildRays(parent: Instance, count: number, color: Color3)
	for i = 1, count do
		Builder.make("Frame", {
			Name = `Ray{i}`,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(6, 560),
			Rotation = (i / count) * 180,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.72,
			BorderSizePixel = 0,
			ZIndex = Theme.Z.reveal,
			Parent = parent,
		})
	end
end

local function play(payload)
	local pet = Pets.get(payload.petId)
	local rarityName = payload.rarity or (pet and pet.rarity) or "Common"
	local info = Rarity.get(rarityName)
	local rank = Rarity.Rank[rarityName] or 1

	playing = true
	root.Visible = true
	root.BackgroundTransparency = 1

	refs.burst:ClearAllChildren()
	buildRays(refs.burst, math.min(24, 6 + rank * 3), info.glow)

	refs.preview:ClearAllChildren()
	PetViewport.create(payload.petId, true, { Parent = refs.preview })

	refs.name.Text = payload.shiny and `* {payload.name} *` or payload.name
	refs.name.TextColor3 = payload.shiny and Theme.Color.gold or info.glow
	refs.rarity.Text = rarityName:upper()
	refs.rarity.TextColor3 = info.glow
	refs.income.Text = pet
			and `{Format.abbreviate(pet.income * (payload.shiny and 5 or 1))}/s`
		or ""

	TweenService:Create(root, TweenInfo.new(0.2), { BackgroundTransparency = 0.35 }):Play()

	refs.card.Size = UDim2.fromOffset(0, 0)
	TweenService
		:Create(
			refs.card,
			TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(360, 420) }
		)
		:Play()

	-- Spin the burst for as long as the card is up.
	local spin
	spin = RunService.RenderStepped:Connect(function(dt)
		refs.burst.Rotation += dt * (12 + rank * 4)
	end)

	task.delay(1.4 + rank * 0.25, function()
		spin:Disconnect()

		local fade = TweenService:Create(root, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		TweenService:Create(refs.card, TweenInfo.new(0.2), { Size = UDim2.fromOffset(0, 0) }):Play()
		fade.Completed:Connect(function()
			root.Visible = false
			playing = false

			local next = table.remove(queue, 1)
			if next then
				play(next)
			end
		end)
		fade:Play()
	end)
end

function HatchReveal.build(screen: ScreenGui)
	root = Builder.make("Frame", {
		Name = "HatchReveal",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = Theme.Z.reveal,
		Parent = screen,
	})

	refs.burst = Builder.make("Frame", {
		Name = "Burst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(600, 600),
		BackgroundTransparency = 1,
		ZIndex = Theme.Z.reveal,
		Parent = root,
	})

	refs.card = Builder.frame({
		Name = "Card",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 420),
		BackgroundColor3 = Theme.Color.panel,
		ZIndex = Theme.Z.reveal + 2,
		Parent = root,
	}, { Builder.stroke(4) })

	refs.preview = Builder.make("Frame", {
		Name = "Preview",
		Position = UDim2.fromOffset(20, 20),
		Size = UDim2.new(1, -40, 0, 250),
		BackgroundTransparency = 1,
		ZIndex = Theme.Z.reveal + 3,
		Parent = refs.card,
	})

	refs.name = Builder.label("", {
		Position = UDim2.new(0, 10, 0, 276),
		Size = UDim2.new(1, -20, 0, 42),
		ZIndex = Theme.Z.reveal + 3,
		Parent = refs.card,
	})

	refs.rarity = Builder.label("", {
		Position = UDim2.new(0, 10, 0, 320),
		Size = UDim2.new(1, -20, 0, 30),
		ZIndex = Theme.Z.reveal + 3,
		Parent = refs.card,
	})

	refs.income = Builder.label("", {
		Position = UDim2.new(0, 10, 0, 354),
		Size = UDim2.new(1, -20, 0, 32),
		TextColor3 = Theme.Color.money,
		ZIndex = Theme.Z.reveal + 3,
		Parent = refs.card,
	})

	return root
end

function HatchReveal.start()
	Net.Event("HatchResult").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if playing then
			-- Never drop a reveal; queue it so a 10x hatch plays in order.
			if #queue < 12 then
				table.insert(queue, payload)
			end
			return
		end
		play(payload)
	end)
end

return HatchReveal
