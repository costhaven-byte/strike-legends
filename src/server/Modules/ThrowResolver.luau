-- Turns a charge-bar release into a throw result. Pure math, no side effects.
-- Rules from the Throw Lab: a release in the gold is a PERFECT and always a strike;
-- otherwise the fuller the bar, the more pins, but never all ten (a strike only comes from the gold).
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
	Tier: string, -- Weak, Good, Nine, Strike, PerfectStrike, or Gutter (only from a failed overcharge)
	Pins: { number }, -- which pins fall (1 = head pin)
	HitX: number, -- where the ball meets the pins, studs from lane centre
	Gutter: boolean,
	RollTime: number,
	CurveFromX: number?, -- Curve balls: where the ball heads before it hooks back to HitX
	Traits: { string }, -- ball traits that made a difference on this throw (for effects)
	Perfect: boolean,
	Strength: number, -- how hard the release was (Config.Throw.PerfectPowerBonus for a PERFECT)
	Overcharge: string?, -- released in the red cap: "Blast" (paid off) or "Wasted" (gutter)
}

local OVER = THROW.Overcharge

-- A failed overcharge: the ball overcooks and drops into the gutter. No pins, no traits.
local function wasted(distance: number): Result
	return {
		Count = 0,
		Tier = "Gutter",
		Pins = {},
		HitX = LANE.GutterOffset * (if math.random() < 0.5 then -1 else 1),
		Gutter = true,
		RollTime = ThrowRules.RollTime(distance, 1),
		CurveFromX = nil,
		Traits = {},
		Perfect = false,
		Strength = 1,
		Overcharge = "Wasted",
	}
end

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
-- perfect: released in the gold. hooked: missed the gold but landed in a Curve ball's hook band (also a PERFECT)
-- overcharged: missed the gold and the hook band but landed in the red cap (only when overcharge is on)
-- ball: the equipped ball row from Config.Balls; distance: studs from the ball start to the head pin
function ThrowResolver.Resolve(
	charge: number,
	perfect: boolean,
	hooked: boolean,
	overcharged: boolean,
	ball,
	distance: number
): Result
	-- The gamble: a huge strike or the gutter
	local blasted = false
	if overcharged and not (perfect or hooked) then
		if math.random() >= OVER.SuccessChance then
			return wasted(distance)
		end
		blasted = true
	end
	local fired = {}
	perfect = perfect or hooked or blasted
	if hooked then
		table.insert(fired, "Curve")
	end

	local strike = perfect or math.random() < THROW.StrikeChanceWithoutPerfect * charge ^ 3
	local count = PINS
	if not strike then
		local fewest = THROW.FewestPinsKnocked
		local wanted = fewest + (PINS - 1 - fewest) * charge + (math.random() * 2 - 1)
		count = math.clamp(math.floor(wanted + 0.5), math.max(fewest, 2), PINS - 1)
	end

	-- Blast: a chance on every throw. A miss knocks down extra pins (up to 9: it can't turn a miss into a strike);
	-- a strike gets a giant explosion.
	local blast = Balls.TraitValue(ball, "Blast")
	if blast > 0 and math.random() < blast then
		if count < PINS then
			count = math.min(PINS - 1, count + ((Balls.GetTrait("Blast") or {}).ExtraPins or 1))
		end
		table.insert(fired, "Blast")
	end

	-- Heavy: every strike lands a heavy hit
	if count == PINS and Balls.TraitValue(ball, "Heavy") > 0 then
		table.insert(fired, "Heavy")
	end

	-- Curve balls always hook down the lane (from the hook side back into the pocket)
	local curveFromX = nil
	if Balls.TraitValue(ball, "Curve") > 0 then
		local side = (Balls.GetTrait("Curve") or {}).HookSide or 1
		curveFromX = side * LANE.LaneHalfWidth * 0.6
	end

	local tier = if perfect
		then "PerfectStrike"
		elseif count == PINS then "Strike"
		elseif count == PINS - 1 then "Nine"
		elseif count >= PINS * THROW.GoodShare then "Good"
		else "Weak"

	local strength = ThrowRules.Strength(charge, perfect) * (if blasted then OVER.PowerMultiplier else 1)
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
		Overcharge = if blasted then "Blast" else nil,
	}
end

return ThrowResolver
