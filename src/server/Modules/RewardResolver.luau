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
}

-- multipliers: named coin multipliers (Ball, Rank, Streak, and later gamepasses). All are multiplied together.
function RewardResolver.Calculate(count: number, tier: string, multipliers: { [string]: number }): Reward
	local multiplier = 1
	for _, value in multipliers do
		multiplier *= value
	end

	local coins = count * REWARDS.BaseCoinsPerPin * multiplier
	local xp = count * REWARDS.XpPerPin
	local gems = 0

	if tier == "PerfectStrike" then
		coins *= 1 + REWARDS.PerfectStrikeBonus
		xp = REWARDS.PerfectStrikeXp
		if math.random() < REWARDS.PerfectGemChance then
			gems = REWARDS.PerfectGemAmount
		end
	elseif tier == "Strike" then
		coins *= 1 + REWARDS.StrikeBonus
		xp = REWARDS.StrikeXp
	end

	return {
		Coins = math.floor(coins + 0.5),
		XP = xp,
		Gems = gems,
	}
end

return RewardResolver
