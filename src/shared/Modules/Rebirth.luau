-- Rebirth rules both server and client use (Phase X Part 6 stub, Config.Economy.Rebirth): what the next rebirth
-- needs and what rebirths give. Rebirths open the zones (Config.Economy.Zones Rebirths, owner 2026-10-27), so the
-- first one is reached in zone 1.
local Config = require(script.Parent.Parent.Config)
local Zones = require(script.Parent.Zones)

local REBIRTH = Config.Economy.Rebirth
local FORMULA = Config.Economy.Formula

local Rebirth = {}

-- Rank level the next rebirth needs (rebirths = rebirths done so far)
function Rebirth.Level(rebirths: number): number
	return REBIRTH.Level + REBIRTH.RankStep * rebirths
end

-- The zone the next rebirth opens, or nil when it opens none (rebirths = rebirths done so far)
function Rebirth.OpensZone(rebirths: number): number?
	local before, after = Zones.ForRebirths(rebirths), Zones.ForRebirths(rebirths + 1)
	return if after > before then after else nil
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
