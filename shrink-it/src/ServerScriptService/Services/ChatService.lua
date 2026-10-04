--[[
	📍 LOCATION: ServerScriptService > Services > ChatService (ModuleScript)

	Three chat tabs (TextChatService channels):
	  💬 Server  – everyone in this server (the default tab).
	  🌍 Global  – everyone in this server AND every other server (filtered, via MessagingService).
	  👥 Friends – only you and your Roblox friends in this server.
	The default Roblox channels are turned off in default.project.json (CreateDefaultTextChannels = false)
	so these three are the only tabs. All text goes through Roblox's filtering.
]]

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local ChatService = {}
local Svc

local TOPIC = "ShrinkItGlobalChat"
local channels = {}
local friends = {} -- [userIdA][userIdB] = true
local published = {} -- MessageId → true (publish each Global message once)

function ChatService.Init(registry)
	Svc = registry
end

local function channelsFolder()
	local folder = TextChatService:FindFirstChild("TextChannels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TextChannels"
		folder.Parent = TextChatService
	end
	return folder
end

local function makeChannel(name)
	local folder = channelsFolder()
	local channel = folder:FindFirstChild(name)
	if not channel then
		channel = Instance.new("TextChannel")
		channel.Name = name
		channel.Parent = folder
	end
	channels[name] = channel
	return channel
end

local function playerOf(textSource)
	return textSource and Players:GetPlayerByUserId(textSource.UserId)
end

local function publishGlobal(message)
	if not GameConfig.Chat.GlobalCrossServer or not message.MessageId or published[message.MessageId] then
		return
	end
	published[message.MessageId] = true
	task.delay(30, function()
		published[message.MessageId] = nil
	end)
	local sender = playerOf(message.TextSource)
	local raw = message.Text
	if not sender or type(raw) ~= "string" or #raw == 0 then
		return
	end
	task.spawn(function()
		local ok, result = pcall(function()
			local filtered = TextService:FilterStringAsync(string.sub(raw, 1, 200), sender.UserId)
			return filtered:GetNonChatStringForBroadcastAsync()
		end)
		if ok and result and #result > 0 then
			pcall(MessagingService.PublishAsync, MessagingService, TOPIC, { Job = game.JobId, Name = sender.DisplayName, Text = result })
		end
	end)
end

function ChatService.OnPlayerLoaded(player)
	for _, channel in pairs(channels) do
		pcall(channel.AddUserAsync, channel, player.UserId)
	end
	-- cache friendships (IsFriendsWith yields, delivery callbacks must not)
	friends[player.UserId] = friends[player.UserId] or {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			task.spawn(function()
				local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
				if ok and isFriend then
					friends[player.UserId][other.UserId] = true
					friends[other.UserId] = friends[other.UserId] or {}
					friends[other.UserId][player.UserId] = true
				end
			end)
		end
	end
end

function ChatService.OnPlayerRemoving(player)
	friends[player.UserId] = nil
	for _, set in pairs(friends) do
		set[player.UserId] = nil
	end
end

function ChatService.Start()
	pcall(function()
		local tabs = TextChatService:FindFirstChildOfClass("ChannelTabsConfiguration")
		if not tabs then
			tabs = Instance.new("ChannelTabsConfiguration")
			tabs.Parent = TextChatService
		end
		tabs.Enabled = true
	end)

	local server = makeChannel("Server")
	local global = makeChannel("Global")
	local friendsChannel = makeChannel("Friends")
	-- (old saved places may still have the "Here" channel: remove it)
	local oldHere = channelsFolder():FindFirstChild("Here")
	if oldHere then
		oldHere:Destroy()
	end

	global.ShouldDeliverCallback = function(message, _target)
		publishGlobal(message)
		return true
	end
	server.ShouldDeliverCallback = function(_message, _target)
		return true
	end
	friendsChannel.ShouldDeliverCallback = function(message, target)
		local a, b = playerOf(message.TextSource), playerOf(target)
		if not a or not b then
			return false
		end
		return a == b or (friends[a.UserId] ~= nil and friends[a.UserId][b.UserId] == true)
	end

	if GameConfig.Chat.GlobalCrossServer then
		task.spawn(function()
			pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, function(packet)
				local data = packet and packet.Data
				if type(data) == "table" and data.Job ~= game.JobId and type(data.Name) == "string" and type(data.Text) == "string" then
					Remotes.Event("GlobalChat"):FireAllClients(data.Name, data.Text)
				end
			end)
		end)
	end
	local _ = Svc
end

return ChatService
