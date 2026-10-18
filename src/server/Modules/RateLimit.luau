-- Stops a player from firing the same request faster than Config.RateLimits allows (throws, crate opens, ...).
-- Anything sent too fast is simply ignored, so spam-clicking or a cheat script can't flood the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local RateLimit = {}

local last: { [Player]: { [string]: number } } = {}

-- True (and the clock starts again) if this player's last `key` request was at least Config.RateLimits[key] seconds ago
function RateLimit.Allow(player: Player, key: string): boolean
	local now = os.clock()
	local times = last[player]
	if not times then
		times = {}
		last[player] = times
	end
	if now - (times[key] or -math.huge) < (Config.RateLimits[key] or 0) then
		return false
	end
	times[key] = now
	return true
end

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)

return RateLimit
