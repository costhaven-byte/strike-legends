-- Looks up ranks and streak tiers from the tables in Config. Used by both server and client.
local Config = require(script.Parent.Parent.Config)

local Progression = {}

function Progression.GetRank(index: number)
	return Config.Ranks[math.clamp(index, 1, #Config.Ranks)]
end

-- Rank levels 1-60 (Config.Economy.Ranks). Same curve as tools/EconomySim.
local LEVELS = Config.Economy.Ranks
local levelXp = { 0 } -- levelXp[n] = total XP needed for level n
for level = 1, LEVELS.MaxRank - 1 do
	local step = if level <= LEVELS.LateFrom
		then math.floor(LEVELS.Base * LEVELS.Growth ^ (level - 1))
		else math.floor(LEVELS.Base * LEVELS.Growth ^ (LEVELS.LateFrom - 1) * LEVELS.LateGrowth ^ (level - LEVELS.LateFrom))
	levelXp[level + 1] = levelXp[level] + step
end

-- Total XP needed for a rank level
function Progression.LevelXP(level: number): number
	return levelXp[math.clamp(level, 1, LEVELS.MaxRank)]
end

-- First rank level of a Pro Tier (Rookie = 1, Amateur = 7, ...)
function Progression.TierStartLevel(tier: number): number
	return (math.clamp(tier, 1, #Config.Ranks) - 1) * LEVELS.LevelsPerTier + 1
end

-- Total XP needed for a Pro Tier (the XP of its first level)
function Progression.TierXP(tier: number): number
	return Progression.LevelXP(Progression.TierStartLevel(tier))
end

-- Highest rank level this XP reaches, but never past the last level of the player's tier
-- (the next tier's first level needs its Rank Trial)
function Progression.LevelFromXP(xp: number, tier: number): number
	local cap = if tier >= #Config.Ranks then LEVELS.MaxRank else Progression.TierStartLevel(tier + 1) - 1
	local level = Progression.TierStartLevel(tier)
	while level < cap and xp >= levelXp[level + 1] do
		level += 1
	end
	return level
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
