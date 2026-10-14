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
	MeterSpeedPerRank = 0.05, -- meters get 5% faster for every rank above Rookie

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

-- What a player starts with the first time they join
Config.StartingData = {
	Coins = 0,
	Gems = 0,
	XP = 0,
	BestStreak = 0,
}

-- Saving (DataStore)
Config.Data = {
	StoreName = "PlayerData",
	SchemaVersion = 1, -- bump when the save format changes, and add an upgrade step in SaveStore
	AutosaveInterval = 90, -- seconds between automatic saves
	MaxRetries = 5, -- attempts per load/save before giving up
	RetryDelay = 2, -- seconds; waits longer after each failed attempt
	LockTimeout = 300, -- a session lock older than this belongs to a crashed server and can be taken
	LockWaitTries = 6, -- if another server still holds the lock, wait and retry this many times...
	LockWaitDelay = 5, -- ...this many seconds apart, then take over
}

-- Strike streaks: the highest row you have reached sets the coin multiplier. A non-strike resets to 0.
Config.Streaks = {
	{ Streak = 1, Multiplier = 1.0, Name = "" },
	{ Streak = 2, Multiplier = 1.5, Name = "DOUBLE" },
	{ Streak = 3, Multiplier = 2.0, Name = "TURKEY" },
	{ Streak = 4, Multiplier = 2.5, Name = "HAMBONE" },
	{ Streak = 5, Multiplier = 3.0, Name = "WILD TURKEY" },
	{ Streak = 7, Multiplier = 4.0, Name = "STREAK MASTER" },
	{ Streak = 10, Multiplier = 5.0, Name = "PERFECT RUN" },
}

-- Pro Tiers, unlocked by lifetime XP. Coin multiplier is permanent; gems are a one-time rank-up reward.
-- Tuned so Rookie to Club takes about 15-20 minutes (roughly 60 XP per minute).
Config.Ranks = {
	{ Name = "Rookie", XP = 0, Multiplier = 1.0, Gems = 0, Color = Color3.fromRGB(200, 200, 210) },
	{ Name = "Amateur", XP = 100, Multiplier = 1.25, Gems = 5, Color = Color3.fromRGB(120, 230, 120) },
	{ Name = "Regular", XP = 350, Multiplier = 1.5, Gems = 10, Color = Color3.fromRGB(80, 200, 255) },
	{ Name = "Club", XP = 1000, Multiplier = 2.0, Gems = 15, Color = Color3.fromRGB(60, 120, 255) },
	{ Name = "Semi-Pro", XP = 3000, Multiplier = 2.5, Gems = 20, Color = Color3.fromRGB(170, 90, 255) },
	{ Name = "Pro", XP = 9000, Multiplier = 3.0, Gems = 30, Color = Color3.fromRGB(255, 60, 210) },
	{ Name = "Elite", XP = 25000, Multiplier = 4.0, Gems = 40, Color = Color3.fromRGB(255, 70, 70) },
	{ Name = "Master", XP = 70000, Multiplier = 5.0, Gems = 50, Color = Color3.fromRGB(255, 150, 30) },
	{ Name = "Legend", XP = 200000, Multiplier = 7.0, Gems = 75, Color = Color3.fromRGB(255, 220, 60) },
	{ Name = "Hall of Famer", XP = 550000, Multiplier = 10.0, Gems = 100, Color = Color3.fromRGB(255, 255, 255) },
}

-- Rewards per throw:
-- coins = pins * BaseCoinsPerPin * (every multiplier: ball, rank, streak, future boosts), plus tier bonus
Config.Rewards = {
	BaseCoinsPerPin = 10,
	StrikeBonus = 0.5, -- +50% coins on a Strike
	PerfectStrikeBonus = 1.5, -- +150% coins on a Perfect Strike (instead of the Strike bonus)

	XpPerPin = 1,
	StrikeXp = 10,
	PerfectStrikeXp = 20,

	PerfectGemChance = 0.1, -- chance a Perfect Strike also drops gems
	PerfectGemAmount = 1,
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
