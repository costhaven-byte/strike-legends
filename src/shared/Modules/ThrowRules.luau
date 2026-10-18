-- The charge-bar rules that the server and the client must agree on: where the gold zone is,
-- how strong a release is, and how hard a ball hits. Numbers live in Config.Throw.
local Config = require(script.Parent.Parent.Config)
local Balls = require(script.Parent.Balls)

local THROW = Config.Throw

local ThrowRules = {}

-- The gold zone for this ball and lane modifier at a server time: its centre and width (shares of the bar).
-- center: where the lane's gold sits right now (the lane's GoldCenter attribute; it jumps after every throw)
-- streak: strikes in a row; each one makes the gold narrower
function ThrowRules.SweetSpot(ball, modifier, serverTime: number, center: number?, streak: number?): (number, number)
	local bonus = (ball.Forgiveness or 0) * THROW.ForgivenessScale
		+ Balls.TraitValue(ball, "Heavy")
		+ (modifier and modifier.SweetBonus or 0)
	local size = math.min(THROW.SweetSpotSize * (1 + bonus), THROW.SweetSpotMax)
	size = math.max(size * (1 - THROW.GoldShrinkPerStrike) ^ (streak or 0), math.min(size, THROW.GoldSpotSmallest))
	center = center or THROW.SweetSpotCenter
	if modifier and modifier.SweetSway then
		-- Moving Gold: slides down the bar and back on the server clock, so everyone sees the same zone
		local wave = 0.5 - 0.5 * math.cos(serverTime / (modifier.SwayPeriod or 3) * math.pi * 2)
		center -= modifier.SweetSway * wave
	end
	-- Keep the whole zone on the bar
	center = math.clamp(center, size / 2, 1 - size / 2)
	return center, size
end

-- Server: where the gold jumps to after a throw (always a clear move away from the last spot)
function ThrowRules.NextGoldCenter(previous: number?): number
	local low, high = THROW.GoldSpotLowest, THROW.GoldSpotHighest
	if not previous then
		return low + math.random() * (high - low)
	end
	-- The spots far enough away: below the last one and above it. Pick a point along both stretches.
	local jump = THROW.GoldSpotMinJump
	local below = math.max(0, (previous - jump) - low)
	local above = math.max(0, high - (previous + jump))
	if below + above <= 0 then
		return low + math.random() * (high - low)
	end
	local pick = math.random() * (below + above)
	return if pick < below then low + pick else previous + jump + (pick - below)
end

-- extra: more bar on each side that also counts (a Curve ball's hook band)
function ThrowRules.InSpot(charge: number, center: number, size: number, extra: number?): boolean
	return math.abs(charge - center) <= size / 2 + (extra or 0)
end

-- Curve: how much bar on each side of the gold hooks into a PERFECT
function ThrowRules.HookWidth(ball): number
	return Balls.TraitValue(ball, "Curve") * THROW.CurveHookWindow
end

-- Server check: was the release in the gold at any moment in the last `window` seconds?
-- (A sliding zone moves while the release travels to the server, so recent moments count too.)
function ThrowRules.WasInSpot(
	charge: number,
	ball,
	modifier,
	now: number,
	window: number,
	extra: number?,
	center: number?,
	streak: number?
): boolean
	local steps = if modifier and modifier.SweetSway then 6 else 0
	for i = 0, steps do
		local spot, size = ThrowRules.SweetSpot(ball, modifier, now - window * i / math.max(steps, 1), center, streak)
		if ThrowRules.InSpot(charge, spot, size, extra) then
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

-- Which Throw Lab level (1-12) a ball hits like: its rarity's level, one higher for the better half of that rarity
local levels: { [string]: number } = {}
do
	local byRarity = {}
	for _, ball in Config.Balls do
		byRarity[ball.Rarity] = byRarity[ball.Rarity] or {}
		table.insert(byRarity[ball.Rarity], ball)
	end
	for rarity, list in byRarity do
		table.sort(list, function(a, b)
			return a.Multiplier < b.Multiplier
		end)
		for i, ball in list do
			local upper = #list > 1 and i > #list / 2
			levels[ball.Id] = (THROW.RarityLevel[rarity] or 1) + (if upper then 1 else 0)
		end
	end
end
function ThrowRules.Level(ball): number
	return math.clamp(levels[ball.Id] or THROW.RarityLevel[ball.Rarity] or 1, 1, #THROW.Levels)
end

-- Seconds from release until the ball reaches the head pin, over `distance` studs
function ThrowRules.RollTime(distance: number, strength: number): number
	return distance / (THROW.BallSpeed * (0.55 + 0.45 * strength))
end

return ThrowRules
