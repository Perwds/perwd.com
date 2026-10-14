--!strict
-- Token bucket per player and action.

local Players = game:GetService("Players")

local RateLimit = {}
RateLimit.__index = RateLimit

export type RateLimit = typeof(setmetatable(
	{} :: { rate: number, burst: number, buckets: { [Player]: { tokens: number, at: number } } },
	RateLimit
))

function RateLimit.new(perSecond: number, burst: number): RateLimit
	local self = setmetatable({ rate = perSecond, burst = burst, buckets = {} }, RateLimit)
	Players.PlayerRemoving:Connect(function(player)
		self.buckets[player] = nil
	end)
	return self
end

function RateLimit.take(self: RateLimit, player: Player): boolean
	local now = os.clock()
	local bucket = self.buckets[player]
	if not bucket then
		bucket = { tokens = self.burst, at = now }
		self.buckets[player] = bucket
	end
	bucket.tokens = math.min(self.burst, bucket.tokens + (now - bucket.at) * self.rate)
	bucket.at = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

return RateLimit
