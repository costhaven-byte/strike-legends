-- What each playtime gift gives this player (Config.Playtime). Gifts grow with progress (batch B4, owner 2026-10-29):
-- coins by zone, Power Level and your own income (like the daily reward), more potions and better crates and eggs in
-- later zones. The server pays it and the GIFTS window shows it, both from here, so they always agree.
local Config = require(script.Parent.Parent.Config)
local Zones = require(script.Parent.Zones)
local DailyRewards = require(script.Parent.DailyRewards)

local PLAYTIME = Config.Playtime

local PlaytimeRewards = {}

function PlaytimeRewards.ZoneRow(zonesOpen: number?)
	local zone = Zones.Highest(zonesOpen)
	return PLAYTIME.ByZone[zone] or PLAYTIME.ByZone[#PLAYTIME.ByZone]
end

-- Gift number index with everything filled in: { Coins?, Potion?, Count?, Egg?, Crate? } (Crate = a crate Id)
function PlaytimeRewards.Resolve(index: number, progress: DailyRewards.Progress)
	local reward = PLAYTIME.Rewards[index]
	if not reward then
		return nil
	end
	local row = PlaytimeRewards.ZoneRow(progress.ZonesOpen)
	local out: { [string]: any } = {}
	if reward.Coins then
		out.Coins = DailyRewards.Coins(reward, reward.IncomeMinutes, progress)
	elseif reward.Potion then
		out.Potion = reward.Potion
		out.Count = row.Potions or 1
	elseif reward.Egg then
		out.Egg = if reward.Egg == "Zone" then row.Egg else reward.Egg
	elseif reward.Crate then
		out.Crate = if type(reward.Crate) == "number" then row.Crates[reward.Crate] else reward.Crate
	end
	return out
end

return PlaytimeRewards
