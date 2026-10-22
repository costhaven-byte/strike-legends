-- Rebirth rules both server and client use (Phase X Part 6 stub, Config.Economy.Rebirth): what the next rebirth
-- needs and what rebirths give. The live game unlocks the first rebirth at zone 4's level.
local Config = require(script.Parent.Parent.Config)
local Zones = require(script.Parent.Zones)

local REBIRTH = Config.Economy.Rebirth
local FORMULA = Config.Economy.Formula

local Rebirth = {}

-- Rank level the next rebirth needs (rebirths = rebirths done so far)
function Rebirth.Level(rebirths: number): number
	return Zones.UnlockLevel(REBIRTH.Zone) + REBIRTH.RankStep * rebirths
end

-- Coins the next rebirth costs
function Rebirth.Cost(rebirths: number): number
	return math.floor(REBIRTH.FirstCost * REBIRTH.CostGrowth ^ rebirths + 0.5)
end

-- Permanent coin and XP multipliers from rebirths done
function Rebirth.CoinMultiplier(rebirths: number?): number
	return 1 + FORMULA.RebirthBonus * (rebirths or 0)
end

function Rebirth.XpMultiplier(rebirths: number?): number
	return 1 + REBIRTH.XpBonus * (rebirths or 0)
end

return Rebirth
