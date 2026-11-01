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

-- Permanent coin and XP multipliers from rebirths done (Addendum 5 step C core loop: the rebirth multiplier)
function Rebirth.CoinMultiplier(rebirths: number?): number
	if Rebirth.CoreOn() then
		return Rebirth.CoreMultiplier(rebirths)
	end
	return 1 + FORMULA.RebirthBonus * (rebirths or 0)
end

-- ===== Addendum 5 step C: rebirth in the core loop (Config.CoreLoop.Rebirth) =====
local CORE_REBIRTH = Config.CoreLoop.Rebirth

-- Is the core loop rebirth on?
function Rebirth.CoreOn(): boolean
	return Config.CoreLoop.Enabled and CORE_REBIRTH ~= nil and CORE_REBIRTH.Enabled == true
end

-- Coins the next rebirth costs (rebirths = rebirths done so far): Prices, then the last one x Growth each, rounded
-- to 2 figures
function Rebirth.CorePrice(rebirths: number?): number
	local done = math.max(0, math.floor(tonumber(rebirths) or 0))
	local prices = CORE_REBIRTH.Prices
	local price = if done < #prices
		then prices[done + 1]
		else prices[#prices] * CORE_REBIRTH.Growth ^ (done + 1 - #prices)
	local unit = 10 ^ math.max(math.floor(math.log10(price)) - 1, 0)
	return math.floor(price / unit + 0.5) * unit
end

-- The rebirth multiplier on pins per swing and on what a sell pays: 1 + Bonus x rebirths
function Rebirth.CoreMultiplier(rebirths: number?): number
	return 1 + CORE_REBIRTH.Bonus * math.max(0, math.floor(tonumber(rebirths) or 0))
end

-- Addendum 6 1.1: the rebirth bonus that goes into the Add group of Config.CoreLoop.Boosts ("Coins" or "Pins"):
-- Bonus / PinBonus x rebirths (0.5 = +50%). 0 when the core rebirth is off.
function Rebirth.CoreBonus(rebirths: number?, kind: string): number
	if not Rebirth.CoreOn() then
		return 0
	end
	local per = if kind == "Pins" then CORE_REBIRTH.PinBonus or CORE_REBIRTH.Bonus else CORE_REBIRTH.Bonus
	return per * math.max(0, math.floor(tonumber(rebirths) or 0))
end

-- The tier row for a rebirth count ({ From, Name, Color }), nil before the first rebirth
function Rebirth.Tier(rebirths: number?): { [string]: any }?
	local done = math.max(0, math.floor(tonumber(rebirths) or 0))
	local found = nil
	for _, row in CORE_REBIRTH.Tiers or {} do
		if done >= row.From then
			found = row
		end
	end
	return found
end

function Rebirth.XpMultiplier(rebirths: number?): number
	return 1 + REBIRTH.XpBonus * (rebirths or 0)
end

return Rebirth
