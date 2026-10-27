-- What each daily calendar day gives this player (Config.Daily). Rewards follow progress (owner 2026-10-28): coins by
-- zone, Power Level and your own income; your zone's egg and best crate; more gems in later zones.
-- The server pays it and the calendar shows it, both from here, so they always agree.
local Config = require(script.Parent.Parent.Config)
local Zones = require(script.Parent.Zones)
local PowerLevels = require(script.Parent.PowerLevels)

local DAILY = Config.Daily

local DailyRewards = {}

-- progress = { PowerLevel, ZonesOpen, AwayRate } (save fields; Player attributes on the client)
export type Progress = { PowerLevel: number?, ZonesOpen: number?, AwayRate: number? }

-- 4,134,000 -> 4,100,000
local function round(coins: number): number
	local unit = 10 ^ math.max(math.floor(math.log10(math.max(coins, 1))) - 1, 0)
	return math.floor(coins / unit) * unit
end

function DailyRewards.ZoneRow(zonesOpen: number?)
	local zone = Zones.Highest(zonesOpen)
	return DAILY.ByZone[zone] or DAILY.ByZone[#DAILY.ByZone], zone
end

-- The day's reward with everything filled in: { Coins, Gems, Potions, Egg, Crate } (Crate = an unlocked crate Id)
function DailyRewards.Resolve(day: number, progress: Progress)
	local reward = DAILY.Rewards[day]
	if not reward then
		return nil
	end
	local row, zone = DailyRewards.ZoneRow(progress.ZonesOpen)
	local out = { Potions = reward.Potions }
	if reward.Coins then
		local coins = math.max(
			reward.Coins * Zones.CoinPay(zone),
			PowerLevels.DailyCoins(reward, progress.PowerLevel),
			(reward.Minutes or 0) * 60 * (tonumber(progress.AwayRate) or 0)
		)
		out.Coins = round(coins)
	end
	if reward.Gems then
		out.Gems = math.floor(reward.Gems * (row.Gems or 1) + 0.5)
	end
	if reward.Egg then
		out.Egg = if reward.Egg == "Zone" then row.Egg else reward.Egg
	end
	if reward.Crate then
		-- a crate from a zone you haven't unlocked yet comes as your zone's crate
		out.Crate = Zones.RewardCrateId(if reward.Crate == "Zone" then row.Crate else reward.Crate, progress.ZonesOpen)
	end
	return out
end

return DailyRewards
