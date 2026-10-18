-- Works out the coins, XP and gems for one throw. Pure math, no side effects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local REWARDS = Config.Rewards

local RewardResolver = {}

export type Reward = {
	Coins: number,
	XP: number,
	Gems: number,
	GemHunter: boolean, -- the ball's Gem Hunter trait paid out (a gem, or bonus coins while gems are off)
	HunterCoins: number, -- coins of this throw's total that came from Gem Hunter (only while gems are off)
}

-- multipliers: named coin multipliers (Ball, Rank, Streak, and later gamepasses). All are multiplied together.
-- xpMultipliers: named XP multipliers (Streak, and later boosts like a 2x XP gamepass), multiplied together.
-- gemBonus: the ball's Gem Hunter strength, an extra chance of a gem on a Perfect Strike
-- (while Config.Gems.Enabled is false: a chance of bonus coins instead, and no gems at all).
function RewardResolver.Calculate(
	count: number,
	tier: string,
	multipliers: { [string]: number },
	xpMultipliers: { [string]: number },
	gemBonus: number?
): Reward
	local multiplier = 1
	for _, value in multipliers do
		multiplier *= value
	end
	local xpMultiplier = 1
	for _, value in xpMultipliers do
		xpMultiplier *= value
	end

	local coins = count * REWARDS.BaseCoinsPerPin * multiplier
	local xp = count * REWARDS.XpPerPin
	local gems = 0
	local gemHunter = false
	local hunterShare = 0

	if tier == "PerfectStrike" then
		coins *= 1 + REWARDS.PerfectStrikeBonus
		xp = REWARDS.PerfectStrikeXp
		if not Config.Gems.Enabled then
			if (gemBonus or 0) > 0 and math.random() < (gemBonus :: number) then
				hunterShare = Config.Gems.HunterCoinBonus
				gemHunter = true
			end
		elseif math.random() < REWARDS.PerfectGemChance then
			gems = REWARDS.PerfectGemAmount
		elseif (gemBonus or 0) > 0 and math.random() < (gemBonus :: number) then
			-- Gem Hunter: a second roll, so its strength adds to the normal chance
			gems = REWARDS.PerfectGemAmount
			gemHunter = true
		end
	elseif tier == "Strike" then
		coins *= 1 + REWARDS.StrikeBonus
		xp = REWARDS.StrikeXp
	end

	local hunterCoins = math.floor(coins * hunterShare + 0.5)
	return {
		Coins = math.floor(coins + 0.5) + hunterCoins,
		HunterCoins = hunterCoins,
		XP = math.floor(xp * xpMultiplier + 0.5),
		Gems = gems,
		GemHunter = gemHunter,
	}
end

return RewardResolver
