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
	-- Keep the whole zone on the bar (and below the overcharge red cap)
	center = math.clamp(center, size / 2, ThrowRules.GoldCeiling() - size / 2)
	return center, size
end

-- The highest the gold zone may reach: the top of the bar, or just under the red cap when overcharge is on
function ThrowRules.GoldCeiling(): number
	local over = THROW.Overcharge
	return if over.Enabled then over.From - over.GoldGap else 1
end

-- Overcharge: was this release in the red cap at the top of the bar?
function ThrowRules.InOvercharge(charge: number): boolean
	return THROW.Overcharge.Enabled and charge >= THROW.Overcharge.From
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

-- Where the bar is after holding `seconds`: it fills, slides back down, and up again while you keep holding.
-- It runs a little faster at higher ranks. The server works the charge out with this from its own hold timing.
function ThrowRules.ChargeAt(seconds: number, rank: number): number
	local speed = 1 + THROW.MeterSpeedPerRank * (rank - 1)
	local t = (math.max(seconds, 0) / THROW.ChargeTime * speed) % 2
	return if t <= 1 then t else 2 - t
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

-- The look-and-hit level (1-12) for a player's Power Level (Config.Throw.Levels), kept on the ladder
function ThrowRules.Level(powerLevel: number?): number
	return math.clamp(math.floor(tonumber(powerLevel) or 1), 1, #THROW.Levels)
end

-- Seconds from release until the ball reaches the head pin, over `distance` studs
function ThrowRules.RollTime(distance: number, strength: number): number
	return distance / (THROW.BallSpeed * (0.55 + 0.45 * strength))
end

return ThrowRules
