-- Turns a charge-bar release into a throw result. Pure math, no side effects.
-- Rules from the Throw Lab: a release in the gold is a PERFECT and always a strike;
-- otherwise the fuller the bar, the more pins (and a small strike chance on a full bar).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local PinRack = require(Shared.Modules.PinRack)
local ThrowRules = require(Shared.Modules.ThrowRules)

local THROW = Config.Throw
local LANE = Config.Lane
local PINS = LANE.PinCount

local ThrowResolver = {}

export type Result = {
	Count: number,
	Tier: string, -- Weak, Good, Nine, Strike, PerfectStrike (Gutter is no longer possible)
	Pins: { number }, -- which pins fall (1 = head pin)
	HitX: number, -- where the ball meets the pins, studs from lane centre
	Gutter: boolean,
	RollTime: number,
	CurveFromX: number?, -- Curve balls: where the ball heads before it hooks back to HitX
	Traits: { string }, -- ball traits that made a difference on this throw (for effects)
	Perfect: boolean,
	Strength: number, -- how hard the release was (Config.Throw.PerfectPowerBonus for a PERFECT)
}

-- Pins on the ball's path always fall; the rest are picked front-to-back with some luck.
local function pickPins(count: number): { number }
	local half = LANE.PinSpacing / 2
	local rowDepth = LANE.PinSpacing * math.sqrt(3) / 2
	local scored = {}
	for index, offset in PinRack.Offsets() do
		local onPath = math.abs(offset.X) < 0.1
		local row = -offset.Z / rowDepth
		local score = if onPath then -100 else math.abs(offset.X) / half + row * 0.6 + math.random() * 2.2
		table.insert(scored, { Index = index, Score = score })
	end
	table.sort(scored, function(a, b)
		return a.Score < b.Score
	end)
	local pins = {}
	for i = 1, count do
		table.insert(pins, scored[i].Index)
	end
	return pins
end

-- charge: where the bar was on release (0-1)
-- perfect / perfectWithoutHeavy: was it in the gold (worked out by ThrowRules, with and without the Heavy trait)
-- ball: the equipped ball row from Config.Balls; distance: studs from the ball start to the head pin
function ThrowResolver.Resolve(
	charge: number,
	perfect: boolean,
	perfectWithoutHeavy: boolean,
	ball,
	distance: number
): Result
	local fired = {}
	if perfect and not perfectWithoutHeavy then
		table.insert(fired, "Heavy")
	end

	local strike = perfect
	local curveFromX = nil
	if not strike then
		local chance = THROW.StrikeChanceWithoutPerfect * charge ^ 3
		local roll = math.random()
		if roll < chance then
			strike = true
		else
			-- Curve: a near miss can hook into the pocket for a strike
			local curve = Balls.TraitValue(ball, "Curve") * THROW.CurveStrikeShare * charge ^ 3
			if curve > 0 and roll < chance + curve then
				strike = true
				table.insert(fired, "Curve")
				local side = (Balls.GetTrait("Curve") or {}).HookSide or 1
				curveFromX = side * LANE.LaneHalfWidth * 0.6
			end
		end
	end

	local count = PINS
	if not strike then
		local fewest = THROW.FewestPinsKnocked
		local wanted = fewest + (PINS - 1 - fewest) * charge + (math.random() * 2 - 1)
		count = math.clamp(math.floor(wanted + 0.5), math.max(fewest, 2), PINS - 1)

		-- Blast: a chance that a hit knocks down extra pins
		local blast = Balls.TraitValue(ball, "Blast")
		if blast > 0 and math.random() < blast then
			count = math.min(PINS, count + ((Balls.GetTrait("Blast") or {}).ExtraPins or 1))
			table.insert(fired, "Blast")
		end
	end

	local tier = if perfect
		then "PerfectStrike"
		elseif count == PINS then "Strike"
		elseif count == PINS - 1 then "Nine"
		elseif count >= PINS * THROW.GoodShare then "Good"
		else "Weak"

	local strength = ThrowRules.Strength(charge, perfect)
	return {
		Count = count,
		Tier = tier,
		Pins = pickPins(count),
		HitX = 0,
		Gutter = false,
		RollTime = ThrowRules.RollTime(distance, strength),
		CurveFromX = curveFromX,
		Traits = fired,
		Perfect = perfect,
		Strength = strength,
	}
end

return ThrowResolver
