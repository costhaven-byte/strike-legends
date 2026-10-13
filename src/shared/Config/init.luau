-- All tunable numbers live here. Change values, not logic.
local Config = {}

-- Lane and pin sizes (studs). Arcade scale: bigger than real life so pins read well on mobile.
Config.Lane = {
	PinHeight = 2.8,
	PinWidth = 0.9,
	PinSpacing = 2.3, -- distance between neighbouring pins
	PinDensity = 0.35, -- light pins fly nicely when hit
	BallDiameter = 1.8,
	BallDensity = 3,

	-- A pin counts as knocked down when it tilts past this (1 = upright, 0 = lying flat)
	FallenUprightThreshold = 0.75,
	-- ...or slides this far from its spot
	FallenMoveDistance = 1.2,

	-- Seconds to wait after the ball reaches the pins before counting
	SettleTime = 1.2,
	-- Longest a roll may take before we stop waiting for it
	MaxRollTime = 6,
}

-- Temporary test roll for Milestone 1 (replaced by the meters in Milestone 2)
Config.TestRoll = {
	Speed = 70, -- studs per second
	MaxSideDrift = 0.6, -- random side offset so rolls are not identical
}

return Config
