-- Rebirth rules both server and client use (Phase X Part 6 stub, Config.Economy.Rebirth): what the next rebirth
-- needs and what rebirths give. Rebirths open the zones (Config.Economy.Zones Rebirths, owner 2026-10-27), so the
-- first one is reached in zone 1.
local Config = require(script.Parent.Parent.Config)
local Zones = require(script.Parent.Zones)

local REBIRTH = Config.Economy.Rebirth
local FORMULA = Config.Economy.Formula

local Rebirth = {}

-- Rank level the next rebirth needs (rebirths = rebirths done so far): its own level from the Levels list, then
-- RankStep more for each one after it (no list: Level + RankStep each)
function Rebirth.Level(rebirths: number): number
	if Config.CoreLoop.Enabled and Config.CoreLoop.NoLevels then
		return 0 -- (Addendum 5 A1: no levels; rebirth asks for coins only)
	end
	local levels = REBIRTH.Levels
	if not levels or #levels == 0 then
		return REBIRTH.Level + REBIRTH.RankStep * rebirths
	end
	if rebirths < #levels then
		return levels[rebirths + 1]
	end
	return levels[#levels] + REBIRTH.RankStep * (rebirths + 1 - #levels)
end

-- The zone the next rebirth opens, or nil when it opens none (rebirths = rebirths done so far)
function Rebirth.OpensZone(rebirths: number): number?
	local before, after = Zones.ForRebirths(rebirths), Zones.ForRebirths(rebirths + 1)
	return if after > before then after else nil
end

-- Coins the next rebirth costs: its own price from the Costs list, then the last one x CostGrowth each
function Rebirth.Cost(rebirths: number): number
	local costs = REBIRTH.Costs
	if not costs or #costs == 0 then
		return math.floor(REBIRTH.FirstCost * REBIRTH.CostGrowth ^ rebirths + 0.5)
	end
	if rebirths < #costs then
		return costs[rebirths + 1]
	end
	return math.floor(costs[#costs] * REBIRTH.CostGrowth ^ (rebirths + 1 - #costs) + 0.5)
end

-- Permanent coin and XP multipliers from rebirths done
function Rebirth.CoinMultiplier(rebirths: number?): number
	return 1 + FORMULA.RebirthBonus * (rebirths or 0)
end

function Rebirth.XpMultiplier(rebirths: number?): number
	return 1 + REBIRTH.XpBonus * (rebirths or 0)
end

return Rebirth
