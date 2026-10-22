-- Looks up Power Levels (Config.Economy.PowerLevels: price, Power, Value) for the server and the client.
-- How each level looks and sounds is in Config.Throw.Levels.
local Config = require(script.Parent.Parent.Config)

local LEVELS = Config.Economy.PowerLevels

local PowerLevels = {}

PowerLevels.Max = #LEVELS

-- The row for a level (clamped, so a bad number still gives a real row)
function PowerLevels.Get(level: number?)
	return LEVELS[math.clamp(math.floor(tonumber(level) or 1), 1, #LEVELS)]
end

-- The next level's row, or nil at the top
function PowerLevels.Next(level: number?)
	return LEVELS[math.floor(tonumber(level) or 1) + 1]
end

-- Coins a daily reward day gives at this Power Level: its Coins, or LevelShare of the next level's price if that's
-- more (at the top level: of the top level's price). Rounded to 2 significant digits (4,134,000 -> 4,100,000).
function PowerLevels.DailyCoins(reward, level: number?): number
	local coins = reward.Coins or 0
	if reward.LevelShare then
		local row = PowerLevels.Next(level) or LEVELS[#LEVELS]
		local share = row.Price * reward.LevelShare
		if share > coins then
			local unit = 10 ^ math.max(math.floor(math.log10(share)) - 1, 0)
			coins = math.floor(share / unit) * unit
		end
	end
	return coins
end

-- What the shop says the level adds ("SPARKS", "ON FIRE"...)
function PowerLevels.NewText(level: number): string
	local look = Config.Throw.Levels[level]
	return look and look.New or ""
end

return PowerLevels
