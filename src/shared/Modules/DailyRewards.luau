-- What each daily calendar day gives this player (Config.Daily). Rewards follow progress (owner 2026-10-28): coins by
-- zone, Power Level and your own income; your zone's egg and best crate; more gems in later zones.
-- The server pays it and the calendar shows it, both from here, so they always agree.
local Config = require(script.Parent.Parent.Config)
local Zones = require(script.Parent.Zones)
local CoreLadder = require(script.Parent.CoreLadder)
local PowerLevels = require(script.Parent.PowerLevels)

local DAILY = Config.Daily

local DailyRewards = {}

-- progress = { PowerLevel, ZonesOpen, AwayRate, BallStep, BagLevel } (save fields; Player attributes on the client)
export type Progress = {
	PowerLevel: number?,
	ZonesOpen: number?,
	AwayRate: number?,
	BallStep: number?, -- (Addendum 4 core loop: gifts follow the ball + bag ladder)
	BagLevel: number?,
	Rebirths: number?, -- (Addendum 5 F: gift coins grow with the rebirth prices)
}

-- 4,134,000 -> 4,100,000
local function round(coins: number): number
	local unit = 10 ^ math.max(math.floor(math.log10(math.max(coins, 1))) - 1, 0)
	return math.floor(coins / unit) * unit
end

-- Coins that grow with progress: the biggest of reward.Coins x your zone's coin pay, reward.LevelShare of your next
-- Power Level's price, or incomeMinutes of your own bowling income (AwayRate). Playtime gifts use it too.
function DailyRewards.Coins(reward, incomeMinutes: number?, progress: Progress): number
	if Config.CoreLoop.Enabled then
		local minutes = reward.CoreMinutes or Config.CoreLoop.Gifts.RewardMinutes
		return CoreLadder.GiftCoins(minutes, progress.BallStep, progress.BagLevel, progress.Rebirths)
	end
	local zone = Zones.Highest(progress.ZonesOpen)
	local coins = math.max(
		(reward.Coins or 0) * Zones.CoinPay(zone),
		PowerLevels.DailyCoins(reward, progress.PowerLevel),
		(incomeMinutes or 0) * 60 * (tonumber(progress.AwayRate) or 0)
	)
	return round(coins)
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
	local row = DailyRewards.ZoneRow(progress.ZonesOpen)
	local out = { Potions = reward.Potions }
	if reward.Coins then
		out.Coins = DailyRewards.Coins(reward, reward.Minutes, progress)
	end
	if reward.Gems then
		out.Gems = math.floor(reward.Gems * (row.Gems or 1) + 0.5)
	end
	if reward.Egg and Config.CoreLoop.Enabled then
		-- (core loop: no egg stand until Stage 5, so an egg day pays coins)
		out.Coins = (out.Coins or 0)
			+ CoreLadder.GiftCoins(Config.CoreLoop.Gifts.CrateMinutes, progress.BallStep, progress.BagLevel, progress.Rebirths)
	elseif reward.Egg then
		out.Egg = if reward.Egg == "Zone" then row.Egg else reward.Egg
	end
	if reward.Crate and Config.CoreLoop.Enabled then
		-- (core loop: crates no longer give balls, so a crate day pays coins)
		out.Coins = (out.Coins or 0)
			+ CoreLadder.GiftCoins(Config.CoreLoop.Gifts.CrateMinutes, progress.BallStep, progress.BagLevel, progress.Rebirths)
	elseif reward.Crate then
		-- a crate from a zone you haven't unlocked yet comes as your zone's crate
		out.Crate = Zones.RewardCrateId(if reward.Crate == "Zone" then row.Crate else reward.Crate, progress.ZonesOpen)
	end
	return out
end

return DailyRewards
