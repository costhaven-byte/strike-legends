-- Turns an aim and power value into a throw result. Pure math, no side effects.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
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
local function powerQuality(power: number): number
	if power < THROW.PowerSweetMin then
		return math.clamp(1 - (THROW.PowerSweetMin - power) / THROW.PowerSweetMin * THROW.WeakPowerPenalty, 0, 1)
	elseif power > THROW.PowerSweetMax then
		return math.clamp(1 - (power - THROW.PowerSweetMax) * THROW.OverPowerPenalty, 0, 1)
	end
	return 1
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

function ThrowResolver.Resolve(aim: number, power: number, forgiveness: number?): Result
	local rollTime = THROW.RollTimeSlow + (THROW.RollTimeFast - THROW.RollTimeSlow) * power

	if math.abs(aim) >= THROW.GutterAim then
		return {
			Count = 0,
			Tier = "Gutter",
			Pins = {},
			HitX = math.sign(aim) * LANE.GutterOffset,
			Gutter = true,
			RollTime = rollTime,
		}
	end

	local quality = aimQuality(aim, forgiveness or 0) * powerQuality(power)
	local count
	if quality >= 0.999 then
		count = 10 -- a perfect throw always strikes
	else
		local variance = (math.random() * 2 - 1) * THROW.RandomVariance
		count = math.clamp(math.round(10 * quality ^ THROW.QualityCurve * (1 + variance)), 0, 10)
	end

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

	local hitX = aim / THROW.GutterAim * LANE.LaneHalfWidth * 0.9
	return {
		Count = count,
		Tier = tier,
		Pins = pickPins(count, hitX),
		HitX = hitX,
		Gutter = false,
		RollTime = rollTime,
	}
end

return ThrowResolver
