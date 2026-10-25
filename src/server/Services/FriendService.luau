-- Friend coin bonus (Addendum 2 step 11a, Config.Friends): +BonusPerFriend coins for each Roblox friend in the same
-- server, up to MaxBonus. MultiplierService adds it as the FRIENDS multiplier. Friendships are checked once when a
-- player joins (IsFriendsWith asks Roblox, so it can be slow or fail; a failed check counts as not friends).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local FRIENDS = Config.Friends

local FriendService = {}

-- friends[a][b] = true when a and b are friends (both directions are stored)
local friends: { [Player]: { [Player]: boolean } } = {}

-- 1 + the bonus for this player's friends in the server
function FriendService.Multiplier(player: Player): number
	if not FRIENDS.Enabled then
		return 1
	end
	local count = 0
	for other in friends[player] or {} do
		if other.Parent then
			count += 1
		end
	end
	return 1 + math.min(count * FRIENDS.BonusPerFriend, FRIENDS.MaxBonus)
end

local function onPlayerAdded(player: Player)
	friends[player] = friends[player] or {}
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(player.IsFriendsWith, player, other.UserId)
			if ok and isFriend and player.Parent and other.Parent then
				friends[player][other] = true
				friends[other] = friends[other] or {}
				friends[other][player] = true
			end
		end
	end
end

function FriendService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		for _, list in friends do
			list[player] = nil
		end
		friends[player] = nil
	end)
end

return FriendService
