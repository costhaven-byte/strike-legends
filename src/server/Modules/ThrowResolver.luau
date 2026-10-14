-- Turns an aim and power value into a throw result. Pure math, no side effects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local PinRack = require(Shared.Modules.PinRack)

local THROW = Config.Throw
local LANE = Config.Lane

local ThrowResolver = {}

export type Result = {
	Count: number,
	Tier: string, -- Gutter, Weak, Good, Nine, Strike, PerfectStrike
	Pins: { number }, -- which pins fall (1 = head pin)
	HitX: number, -- where the ball meets the pins, studs from lane centre
	Gutter: boolean,
	RollTime: number,
	CurveFromX: number?, -- Curve balls: where the ball heads before it hooks back to HitX
	Traits: { string }, -- ball traits that made a difference on this throw (for effects)
}

-- 1 inside the sweet spot, falling to 0 at the gutter edge. forgiveness widens the sweet spot.
local function aimQuality(aim: number, forgiveness: number): number
	local sweet = THROW.AimSweetSpot + forgiveness
	local off = math.abs(aim)
	if off <= sweet then
		return 1
	end
	return math.clamp(1 - (off - sweet) / (THROW.GutterAim - sweet), 0, 1)
end

-- 1 inside the sweet zone; drops slowly when weak, quickly when overpowered.
-- heavy (the Heavy trait) widens the zone by that share, half on each side.
local function powerQuality(power: number, heavy: number): number
	local widen = (THROW.PowerSweetMax - THROW.PowerSweetMin) * heavy / 2
	local sweetMin, sweetMax = THROW.PowerSweetMin - widen, THROW.PowerSweetMax + widen
	if power < sweetMin then
		return math.clamp(1 - (sweetMin - power) / sweetMin * THROW.WeakPowerPenalty, 0, 1)
	elseif power > sweetMax then
		return math.clamp(1 - (power - sweetMax) * THROW.OverPowerPenalty, 0, 1)
	end
	return 1
end

-- Where the ball meets the pins for an aim value, in studs from lane centre
local function aimToX(aim: number): number
	return aim / THROW.GutterAim * LANE.LaneHalfWidth * 0.9
end

-- Pins closest to the ball's line fall first, with a little shuffle so patterns vary.
local function pickPins(count: number, hitX: number): { number }
	local scored = {}
	for index, offset in PinRack.Offsets() do
		local row = -offset.Z / (LANE.PinSpacing * math.sqrt(3) / 2)
		local score = math.abs(offset.X - hitX) + row * 0.3 + math.random() * 0.8
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

-- ball: the equipped ball row from Config.Balls (its Forgiveness and Traits change the result)
function ThrowResolver.Resolve(aim: number, power: number, ball): Result
	local rollTime = THROW.RollTimeSlow + (THROW.RollTimeFast - THROW.RollTimeSlow) * power
	local forgiveness = ball.Forgiveness or 0

	local function gutterBall(): Result
		return {
			Count = 0,
			Tier = "Gutter",
			Pins = {},
			HitX = math.sign(aim) * LANE.GutterOffset,
			Gutter = true,
			RollTime = rollTime,
			Traits = {},
		}
	end

	if math.abs(aim) >= THROW.GutterAim then
		return gutterBall()
	end

	local fired = {}

	-- Curve: an off-centre aim on the hook side curls back toward the pocket
	local aimUsed = aim
	local curve = Balls.TraitValue(ball, "Curve")
	local hookSide = (Balls.GetTrait("Curve") or {}).HookSide or 1
	if curve > 0 and math.sign(aim) == hookSide and math.abs(aim) > THROW.AimSweetSpot + forgiveness then
		aimUsed = aim * (1 - curve)
		table.insert(fired, "Curve")
	end

	-- Heavy: a wider power sweet zone
	local heavy = Balls.TraitValue(ball, "Heavy")
	local power1 = powerQuality(power, heavy)
	if power1 > powerQuality(power, 0) then
		table.insert(fired, "Heavy")
	end

	local quality = aimQuality(aimUsed, forgiveness) * power1
	local count
	if quality >= 0.999 then
		count = 10 -- a perfect throw always strikes
	else
		local variance = (math.random() * 2 - 1) * THROW.RandomVariance
		count = math.clamp(math.round(10 * quality ^ THROW.QualityCurve * (1 + variance)), 0, 10)
	end
	if count == 0 then
		return gutterBall() -- missing every pin always reads (and rolls) as a gutter ball
	end

	-- Blast: a chance that a hit knocks down extra pins
	local blast = Balls.TraitValue(ball, "Blast")
	if blast > 0 and count < 10 and math.random() < blast then
		count = math.min(10, count + ((Balls.GetTrait("Blast") or {}).ExtraPins or 1))
		table.insert(fired, "Blast")
	end

	-- Perfect Strikes still need truly perfect timing: traits never make them easier
	local perfect = count == 10
		and math.abs(aim) <= THROW.PerfectStrikeAim
		and power >= THROW.PerfectStrikePowerMin
		and power <= THROW.PerfectStrikePowerMax

	local tier = if perfect
		then "PerfectStrike"
		elseif count == 10 then "Strike"
		elseif count == 9 then "Nine"
		elseif count >= 7 then "Good"
		else "Weak"

	local hitX = aimToX(aimUsed)
	return {
		Count = count,
		Tier = tier,
		Pins = pickPins(count, hitX),
		HitX = hitX,
		Gutter = false,
		RollTime = rollTime,
		CurveFromX = if aimUsed ~= aim then aimToX(aim) else nil,
		Traits = fired,
	}
end

return ThrowResolver
