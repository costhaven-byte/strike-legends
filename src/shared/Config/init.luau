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
	EquippedBall = "Rookie",
	OwnedBalls = { Rookie = true }, -- set of ball Ids
	CratesSinceRare = 0, -- pity counters, see Config.Pity
	CratesSinceEpic = 0,
}

-- Saving (DataStore)
Config.Data = {
	StoreName = "PlayerData",
	SchemaVersion = 2, -- v2 added balls and crates. Bump when the save format changes, and add an upgrade step in SaveStore
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

-- Ball rarities, lowest first. SellCoins = coins paid when a crate gives a ball you already own.
Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 210), SellCoins = 100 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 230, 110), SellCoins = 250 },
	{ Name = "Rare", Color = Color3.fromRGB(60, 160, 255), SellCoins = 750 },
	{ Name = "Epic", Color = Color3.fromRGB(180, 80, 255), SellCoins = 2500 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), SellCoins = 10000 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 50, 120), SellCoins = 50000 },
}

-- Every ball in the game. Adding a ball = adding a row.
-- Multiplier: coin multiplier while equipped. Forgiveness: widens the perfect-aim zone (meter is -1..1).
-- Color/Material: the ball itself. Trail: the streak it leaves down the lane.
-- InCrates = false keeps a ball out of crates (the starter ball).
Config.Balls = {
	-- Common
	{
		Id = "Rookie",
		Name = "Rookie Ball",
		Rarity = "Common",
		Multiplier = 1.0,
		Forgiveness = 0,
		Color = Color3.fromRGB(0, 220, 255),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(0, 220, 255),
		InCrates = false,
	},
	{
		Id = "Bubblegum",
		Name = "Bubblegum",
		Rarity = "Common",
		Multiplier = 1.05,
		Forgiveness = 0,
		Color = Color3.fromRGB(255, 130, 200),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(255, 170, 220),
	},
	{
		Id = "Lime",
		Name = "Lime Twist",
		Rarity = "Common",
		Multiplier = 1.1,
		Forgiveness = 0,
		Color = Color3.fromRGB(160, 255, 60),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(190, 255, 120),
	},
	{
		Id = "Tangerine",
		Name = "Tangerine",
		Rarity = "Common",
		Multiplier = 1.15,
		Forgiveness = 0,
		Color = Color3.fromRGB(255, 150, 40),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(255, 190, 90),
	},
	{
		Id = "Ocean",
		Name = "Deep Ocean",
		Rarity = "Common",
		Multiplier = 1.2,
		Forgiveness = 0.005,
		Color = Color3.fromRGB(30, 90, 200),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(60, 140, 255),
	},
	-- Uncommon
	{
		Id = "Electric",
		Name = "Electric Blue",
		Rarity = "Uncommon",
		Multiplier = 1.3,
		Forgiveness = 0.01,
		Color = Color3.fromRGB(40, 120, 255),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(120, 200, 255),
	},
	{
		Id = "Toxic",
		Name = "Toxic Slime",
		Rarity = "Uncommon",
		Multiplier = 1.4,
		Forgiveness = 0.01,
		Color = Color3.fromRGB(90, 255, 40),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(140, 255, 60),
	},
	{
		Id = "Sunset",
		Name = "Sunset Strip",
		Rarity = "Uncommon",
		Multiplier = 1.5,
		Forgiveness = 0.015,
		Color = Color3.fromRGB(255, 90, 60),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 200, 60),
	},
	{
		Id = "Frostbite",
		Name = "Frostbite",
		Rarity = "Uncommon",
		Multiplier = 1.6,
		Forgiveness = 0.015,
		Color = Color3.fromRGB(180, 240, 255),
		Material = Enum.Material.Ice,
		Trail = Color3.fromRGB(200, 250, 255),
	},
	-- Rare
	{
		Id = "Magma",
		Name = "Magma Core",
		Rarity = "Rare",
		Multiplier = 1.8,
		Forgiveness = 0.02,
		Color = Color3.fromRGB(255, 70, 20),
		Material = Enum.Material.CrackedLava,
		Trail = Color3.fromRGB(255, 120, 30),
	},
	{
		Id = "Galaxy",
		Name = "Galaxy",
		Rarity = "Rare",
		Multiplier = 2.0,
		Forgiveness = 0.02,
		Color = Color3.fromRGB(90, 40, 180),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(200, 120, 255),
	},
	{
		Id = "Thunder",
		Name = "Thunderstrike",
		Rarity = "Rare",
		Multiplier = 2.2,
		Forgiveness = 0.025,
		Color = Color3.fromRGB(255, 240, 60),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 255, 160),
	},
	{
		Id = "Phantom",
		Name = "Phantom",
		Rarity = "Rare",
		Multiplier = 2.5,
		Forgiveness = 0.025,
		Color = Color3.fromRGB(220, 220, 255),
		Material = Enum.Material.ForceField,
		Trail = Color3.fromRGB(180, 180, 255),
	},
	-- Epic
	{
		Id = "Plasma",
		Name = "Plasma Orb",
		Rarity = "Epic",
		Multiplier = 3.0,
		Forgiveness = 0.03,
		Color = Color3.fromRGB(255, 40, 220),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 120, 240),
	},
	{
		Id = "Nebula",
		Name = "Nebula",
		Rarity = "Epic",
		Multiplier = 4.0,
		Forgiveness = 0.035,
		Color = Color3.fromRGB(120, 60, 255),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 90, 200),
	},
	{
		Id = "Inferno",
		Name = "Inferno",
		Rarity = "Epic",
		Multiplier = 5.0,
		Forgiveness = 0.035,
		Color = Color3.fromRGB(255, 100, 0),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 40, 0),
	},
	-- Legendary
	{
		Id = "Golden",
		Name = "Golden Strike",
		Rarity = "Legendary",
		Multiplier = 7.0,
		Forgiveness = 0.04,
		Color = Color3.fromRGB(255, 200, 40),
		Material = Enum.Material.Foil,
		Trail = Color3.fromRGB(255, 230, 120),
	},
	{
		Id = "Dragon",
		Name = "Dragon's Eye",
		Rarity = "Legendary",
		Multiplier = 10.0,
		Forgiveness = 0.045,
		Color = Color3.fromRGB(200, 20, 40),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 160, 0),
	},
	-- Mythic
	{
		Id = "Void",
		Name = "The Void",
		Rarity = "Mythic",
		Multiplier = 20.0,
		Forgiveness = 0.05,
		Color = Color3.fromRGB(15, 0, 30),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(150, 0, 255),
	},
	{
		Id = "Supernova",
		Name = "Supernova",
		Rarity = "Mythic",
		Multiplier = 25.0,
		Forgiveness = 0.05,
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 220, 120),
	},
}

-- Crates, bought with coins. Odds are percentages per rarity and must add up to 100.
Config.Crates = {
	{
		Id = "Basic",
		Name = "Basic Crate",
		Price = 500,
		Color = Color3.fromRGB(60, 200, 255),
		Odds = { Common = 60, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 0.9, Mythic = 0.1 },
	},
	{
		Id = "Neon",
		Name = "Neon Crate",
		Price = 2500,
		Color = Color3.fromRGB(255, 60, 210),
		Odds = { Common = 35, Uncommon = 35, Rare = 20, Epic = 8, Legendary = 1.75, Mythic = 0.25 },
	},
}

-- Pity: guaranteed rarity after this many crates in a row without it (counts across both crates)
Config.Pity = {
	{ Rarity = "Rare", Crates = 20, Counter = "CratesSinceRare" },
	{ Rarity = "Epic", Crates = 100, Counter = "CratesSinceEpic" },
}

return Config
