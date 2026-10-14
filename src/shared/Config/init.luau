-- All tunable numbers live here. Change values, not logic.
local Config = {}

-- Lane and pin sizes (studs). Arcade scale: bigger than real life so pins read well on mobile.
Config.Lane = {
	PinHeight = 2.8,
	PinWidth = 0.9,
	PinSpacing = 2.3, -- distance between neighbouring pins
	PinDensity = 0.35,
	BallDiameter = 1.8,

	LaneHalfWidth = 4, -- playable wood, centre to edge
	GutterOffset = 4.7, -- centre of the gutter, from lane centre
	GutterDepth = 0.6, -- how far below the lane surface the gutter is

	-- How hard knocked pins fly (studs per second)
	PinKnockSpeedMin = 14,
	PinKnockSpeedMax = 28,
	PinKnockUpSpeed = 10,

	-- Seconds from the ball reaching the pins until they reset
	PinResetDelay = 1.4,

	-- How far (studs) a player can be from the lane's approach and still throw
	ThrowZoneMargin = 0.7, -- small, so it never reaches a neighbouring lane
}

Config.Throw = {
	-- Meters: full back-and-forth sweeps per second
	AimMeterSpeed = 0.7,
	PowerMeterSpeed = 0.9,
	MeterSpeedPerRank = 0.05, -- extra speed per rank (used from Milestone 4)

	-- Aim: 0 is dead centre, 1 is the edge of the meter
	AimSweetSpot = 0.1, -- inside this, aim counts as perfect
	GutterAim = 0.85, -- at or past this, the ball goes in the gutter
	PerfectStrikeAim = 0.04, -- tighter window for a Perfect Strike

	-- Power: the ideal zone. Too low = weak hit, too high = loses control.
	PowerSweetMin = 0.8,
	PowerSweetMax = 0.95,
	PerfectStrikePowerMin = 0.85,
	PerfectStrikePowerMax = 0.92,
	WeakPowerPenalty = 1.2, -- how fast quality drops below the sweet zone
	OverPowerPenalty = 8, -- how fast quality drops above the sweet zone

	-- Pins = 10 * quality^QualityCurve, then +/- RandomVariance
	QualityCurve = 0.7,
	RandomVariance = 0.1,

	-- Roll duration (seconds): full power is fastest
	RollTimeSlow = 2.2,
	RollTimeFast = 1.1,

	-- Server waits this long after a roll before the lane takes another throw
	CooldownBuffer = 0.3,
}

-- Camera that follows your own ball down the lane
Config.Camera = {
	FollowDistance = 10, -- studs behind the ball
	FollowHeight = 5,
	LookAhead = 20,
	StopBeforePins = 16, -- camera stops this far before the head pin
	Smoothness = 8, -- higher = snappier
}

return Config
