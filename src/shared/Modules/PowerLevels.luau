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

-- What the shop says the level adds ("SPARKS", "ON FIRE"...)
function PowerLevels.NewText(level: number): string
	local look = Config.Throw.Levels[level]
	return look and look.New or ""
end

return PowerLevels
