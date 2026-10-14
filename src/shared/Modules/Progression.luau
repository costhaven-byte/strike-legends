-- Looks up ranks and streak tiers from the tables in Config. Used by both server and client.
local Config = require(script.Parent.Parent.Config)

local Progression = {}

function Progression.GetRank(index: number)
	return Config.Ranks[math.clamp(index, 1, #Config.Ranks)]
end

-- The streak tier you are in (highest tier whose Streak you have reached), or nil at streak 0.
function Progression.GetStreakTier(streak: number)
	local tier = nil
	for _, entry in Config.Streaks do
		if streak >= entry.Streak then
			tier = entry
		end
	end
	return tier
end

-- Position of that tier in Config.Streaks (1 = first tier), or 0 at streak 0.
function Progression.GetStreakTierIndex(streak: number): number
	local index = 0
	for i, entry in Config.Streaks do
		if streak >= entry.Streak then
			index = i
		end
	end
	return index
end

function Progression.GetStreakMultiplier(streak: number): number
	local tier = Progression.GetStreakTier(streak)
	return if tier then tier.Multiplier else 1
end

function Progression.GetStreakXpMultiplier(streak: number): number
	local tier = Progression.GetStreakTier(streak)
	return if tier then tier.XpMultiplier or 1 else 1
end

return Progression
