-- The charge-bar rules that the server and the client must agree on: where the gold zone is,
-- how strong a release is, and how hard a ball hits. Numbers live in Config.Throw.
local Config = require(script.Parent.Parent.Config)
local Balls = require(script.Parent.Balls)

local THROW = Config.Throw

local ThrowRules = {}

-- The gold zone for this ball and lane modifier at a server time: its centre and width (shares of the bar)
-- withoutHeavy leaves out the Heavy trait (to tell whether Heavy made the difference).
function ThrowRules.SweetSpot(ball, modifier, serverTime: number, withoutHeavy: boolean?): (number, number)
	local bonus = (ball.Forgiveness or 0) * THROW.ForgivenessScale
		+ (if withoutHeavy then 0 else Balls.TraitValue(ball, "Heavy"))
		+ (modifier and modifier.SweetBonus or 0)
	local size = math.min(THROW.SweetSpotSize * (1 + bonus), THROW.SweetSpotMax)
	local center = THROW.SweetSpotCenter
	if modifier and modifier.SweetSway then
		-- Moving Gold: slides down the bar and back on the server clock, so everyone sees the same zone
		local wave = 0.5 - 0.5 * math.cos(serverTime / (modifier.SwayPeriod or 3) * math.pi * 2)
		center -= modifier.SweetSway * wave
	end
	-- Keep the whole zone on the bar
	center = math.clamp(center, size / 2, 1 - size / 2)
	return center, size
end

function ThrowRules.InSpot(charge: number, center: number, size: number): boolean
	return math.abs(charge - center) <= size / 2
end

-- Server check: was the release in the gold at any moment in the last `window` seconds?
-- (A sliding zone moves while the release travels to the server, so recent moments count too.)
function ThrowRules.WasInSpot(
	charge: number,
	ball,
	modifier,
	now: number,
	window: number,
	withoutHeavy: boolean?
): boolean
	local steps = if modifier and modifier.SweetSway then 6 else 0
	for i = 0, steps do
		local center, size = ThrowRules.SweetSpot(ball, modifier, now - window * i / math.max(steps, 1), withoutHeavy)
		if ThrowRules.InSpot(charge, center, size) then
			return true
		end
	end
	return false
end

-- How strong a release is: a quick tap still throws, a PERFECT is stronger than a full bar
function ThrowRules.Strength(charge: number, perfect: boolean): number
	if perfect then
		return THROW.PerfectPowerBonus
	end
	return THROW.WeakestThrow + (1 - THROW.WeakestThrow) * charge
end

-- Which Throw Lab level (1-12) a ball hits like
function ThrowRules.Level(ball): number
	return math.clamp(THROW.RarityLevel[ball.Rarity] or 1, 1, #THROW.Levels)
end

-- Seconds from release until the ball reaches the head pin, over `distance` studs
function ThrowRules.RollTime(distance: number, strength: number): number
	return distance / (THROW.BallSpeed * (0.55 + 0.45 * strength))
end

return ThrowRules
