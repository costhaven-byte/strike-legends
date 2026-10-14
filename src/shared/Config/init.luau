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
	Rank = 1, -- index into Config.Ranks (1 = Rookie); raised by passing Rank Trials
	BestStreak = 0,
	EquippedBall = "Rookie",
	OwnedBalls = { Rookie = true }, -- set of ball Ids
	CratesSinceRare = 0, -- pity counters, see Config.Pity
	CratesSinceEpic = 0,
	LifetimePins = 0, -- leaderboard: Most Pins
	WeeklyCoins = 0, -- leaderboard: coins earned from throws this week...
	WeeklyCoinsWeek = 0, -- ...and which week that was (see Calendar.Week)
	DailyDay = 0, -- last daily reward day claimed (1-7), 0 = never
	DailyLastClaim = 0, -- the day number (see Calendar.Day) it was claimed on
	CrateStrikes = 0, -- strikes toward the next free crate (see Config.FreeCrates)
	FreeCrates = 0, -- free crates waiting to be opened in the shop
}

-- Saving (DataStore)
Config.Data = {
	StoreName = "PlayerData",
	SchemaVersion = 5, -- v2 added balls and crates, v3 daily reward and leaderboard stats, v4 saved Rank (Rank Trials), v5 free crates. Bump when the save format changes, and add an upgrade step in SaveStore
	AutosaveInterval = 90, -- seconds between automatic saves
	MaxRetries = 5, -- attempts per load/save before giving up
	RetryDelay = 2, -- seconds; waits longer after each failed attempt
	LockTimeout = 300, -- a session lock older than this belongs to a crashed server and can be taken
	LockWaitTries = 6, -- if another server still holds the lock, wait and retry this many times...
	LockWaitDelay = 5, -- ...this many seconds apart, then take over
}

-- Strike streaks: the highest row you have reached sets the coin multiplier (Multiplier) and the XP multiplier
-- (XpMultiplier). A non-strike resets to 0.
-- Color tints the streak display and the player's alley lights.
Config.Streaks = {
	{ Streak = 1, Multiplier = 1.0, XpMultiplier = 1.0, Name = "", Color = Color3.fromRGB(255, 255, 255) },
	{ Streak = 2, Multiplier = 1.5, XpMultiplier = 1.5, Name = "DOUBLE", Color = Color3.fromRGB(60, 230, 255) },
	{ Streak = 3, Multiplier = 2.0, XpMultiplier = 2.0, Name = "TURKEY", Color = Color3.fromRGB(120, 255, 120) },
	{ Streak = 4, Multiplier = 2.5, XpMultiplier = 2.5, Name = "HAMBONE", Color = Color3.fromRGB(255, 200, 40) },
	{ Streak = 5, Multiplier = 3.0, XpMultiplier = 3.0, Name = "WILD TURKEY", Color = Color3.fromRGB(255, 130, 30) },
	{ Streak = 7, Multiplier = 4.0, XpMultiplier = 4.0, Name = "STREAK MASTER", Color = Color3.fromRGB(255, 60, 210) },
	{ Streak = 10, Multiplier = 5.0, XpMultiplier = 5.0, Name = "PERFECT RUN", Color = Color3.fromRGB(255, 240, 90) },
}

-- Pro Tiers. XP fills the bar; reaching the next rank's XP unlocks its Rank Trial (see Config.Trials),
-- and passing the trial gives the rank. Coin multiplier is permanent; gems are a one-time rank-up reward.
-- Tuned for roughly 180-390 XP a minute (more with strike streaks, see Config.Streaks XpMultiplier):
-- first rank-up after ~1-2 minutes, then each rank takes much longer.
-- (Before 9.5c: 100, 350, 1000, 3000, 9000, 25000, 70000, 200000, 550000.)
Config.Ranks = {
	{ Name = "Rookie", XP = 0, Multiplier = 1.0, Gems = 0, Color = Color3.fromRGB(200, 200, 210) },
	{ Name = "Amateur", XP = 300, Multiplier = 1.25, Gems = 5, Color = Color3.fromRGB(120, 230, 120) },
	{ Name = "Regular", XP = 600, Multiplier = 1.5, Gems = 10, Color = Color3.fromRGB(80, 200, 255) },
	{ Name = "Club", XP = 2000, Multiplier = 2.0, Gems = 15, Color = Color3.fromRGB(60, 120, 255) },
	{ Name = "Semi-Pro", XP = 6000, Multiplier = 2.5, Gems = 20, Color = Color3.fromRGB(170, 90, 255) },
	{ Name = "Pro", XP = 18000, Multiplier = 3.0, Gems = 30, Color = Color3.fromRGB(255, 60, 210) },
	{ Name = "Elite", XP = 50000, Multiplier = 4.0, Gems = 40, Color = Color3.fromRGB(255, 70, 70) },
	{ Name = "Master", XP = 140000, Multiplier = 5.0, Gems = 50, Color = Color3.fromRGB(255, 150, 30) },
	{ Name = "Legend", XP = 400000, Multiplier = 7.0, Gems = 75, Color = Color3.fromRGB(255, 220, 60) },
	{ Name = "Hall of Famer", XP = 1000000, Multiplier = 10.0, Gems = 100, Color = Color3.fromRGB(255, 255, 255) },
}

-- Rank Trials: the test you pass to reach a rank once your XP bar is full.
-- Types: what a trial counts. Counts = which throws count ("Strike" includes Perfect Strikes, "Perfect" only those).
-- InARow = they must come one after another (a miss starts the count again).
-- Text: %d = Goal, then Throws.
-- Ranks: one trial per rank you are trying to reach. A rank with no row here is given straight away.
Config.Trials = {
	Cooldown = 60, -- seconds to wait after failing before you can try again
	Types = {
		Strikes = { Counts = "Strike", InARow = false, Text = "Get %d strikes in %d throws" },
		Streak = { Counts = "Strike", InARow = true, Text = "Get %d strikes in a row within %d throws" },
		Perfects = { Counts = "Perfect", InARow = false, Text = "Hit %d Perfect Strikes in %d throws" },
		PerfectRow = { Counts = "Perfect", InARow = true, Text = "Hit %d Perfect Strikes in a row within %d throws" },
	},
	Ranks = {
		Amateur = { Type = "Strikes", Goal = 2, Throws = 6 },
		Regular = { Type = "Strikes", Goal = 3, Throws = 8 },
		Club = { Type = "Streak", Goal = 2, Throws = 8 },
		["Semi-Pro"] = { Type = "Strikes", Goal = 4, Throws = 8 },
		Pro = { Type = "Streak", Goal = 3, Throws = 10 },
		Elite = { Type = "Perfects", Goal = 2, Throws = 10 },
		Master = { Type = "Streak", Goal = 4, Throws = 10 },
		Legend = { Type = "PerfectRow", Goal = 2, Throws = 12 },
		["Hall of Famer"] = { Type = "Streak", Goal = 6, Throws = 12 },
	},
}

-- Rewards per throw:
-- coins = pins * BaseCoinsPerPin * (every multiplier: ball, rank, streak, future boosts), plus tier bonus
Config.Rewards = {
	BaseCoinsPerPin = 10,
	StrikeBonus = 0.5, -- +50% coins on a Strike
	PerfectStrikeBonus = 1.5, -- +150% coins on a Perfect Strike (instead of the Strike bonus)

	-- XP = (pins * XpPerPin, or the Strike / Perfect Strike amount) * every XP multiplier (streak, future boosts)
	XpPerPin = 1.5, -- was 1 before 9.5c
	StrikeXp = 15, -- was 10
	PerfectStrikeXp = 30, -- was 20

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

-- Effects ("juice"). Only changes how things look and sound, never rewards.
Config.Juice = {
	SlowMoScale = 0.25, -- strike slow-motion speed (1 = normal speed)
	SlowMoTime = 0.3, -- seconds of slow-motion when your ball hits the pins for a strike
	SlowMoFov = 58, -- the camera zooms in a little during slow-motion (normal is 70)

	ShakePerPin = 0.05, -- camera shake strength for each pin knocked
	ShakeStrikeBonus = 0.35, -- extra shake on a strike
	ShakeDecay = 3, -- how fast the shake dies down (higher = shorter)

	ConfettiAmount = 60, -- confetti pieces in the alley on a strike
	PerfectFireworks = 3, -- firework bursts on a Perfect Strike

	CoinIconsMin = 3, -- coins that fly to the counter after a throw...
	CoinIconsMax = 14,
	CoinsPerIcon = 30, -- ...one icon per this many coins earned, between Min and Max
	CoinPitchStep = 0.05, -- each coin's "ding" is this much higher than the last

	StreakSparkleRate = 4, -- sparkles per second on your alley's light strips, per streak tier from Turkey up
}

-- Screen layout
Config.Ui = {
	CompactHeight = 500, -- screens shorter than this (phones held sideways) use the compact phone layout
}

-- Sound effects. Placeholders from the Creator Store: change an Id to swap a sound.
Config.Sounds = {
	Click = { Id = 114782931135220, Volume = 0.4 }, -- any UI button
	Tap = { Id = 127036696152728, Volume = 0.7 }, -- locking aim / power
	Throw = { Id = 9114156499, Volume = 0.5 }, -- ball released
	Roll = { Id = 9118661490, Volume = 0.6 }, -- ball rolling down the lane
	PinHit = { Id = 9113559266, Volume = 0.9 },
	StrikeCrash = { Id = 4692687595, Volume = 1 },
	PerfectSting = { Id = 1840076509, Volume = 0.6 },
	Cheer = { Id = 9120974378, Volume = 0.45 },
	Firework = { Id = 134947109312227, Volume = 0.6 },
	Coin = { Id = 135483737426662, Volume = 0.3 },
	StreakUp = { Id = 112485797063762, Volume = 0.6 },
	StreakLost = { Id = 97861773515321, Volume = 0.45 },
	RankUp = { Id = 1841488866, Volume = 0.8 },
	ReelTick = { Id = 88442833509532, Volume = 0.6 },
	Reveal = { Id = 6079105785, Volume = 0.6 },
	RevealBig = { Id = 128460880879263, Volume = 0.8 },
}

-- Ball traits: special powers that change how a ball plays. Adding a trait = adding a row here
-- (and, for a brand-new kind of power, a few lines where the server applies it).
-- A ball's strength number means something different per trait, see Value below.
-- Text: full description (%s = the strength, already scaled by Display). Short: the tag on inventory tiles.
-- Popup: the text that flashes on screen when the trait kicks in. Fx: which 3D effect plays
-- (Swirl, Ring, Dome, Burst). Sound: a name from Config.Sounds, played at Pitch.
Config.Traits = {
	{
		Id = "Curve", -- Value: share of an off-centre aim the hook takes back (0.3 = 30% closer to the pocket)
		Name = "Curve",
		Text = "Hooks into the pocket: aiming right is %s%% more forgiving",
		Short = "CURVE %s%%",
		Display = 100,
		Popup = "HOOK!",
		Color = Color3.fromRGB(80, 220, 255),
		Fx = "Swirl",
		Sound = "Throw",
		Pitch = 1.5,
		HookSide = 1, -- 1 = aims right of centre hook back in, -1 = left
	},
	{
		Id = "Blast", -- Value: chance (0-1) that a throw which hits pins knocks down ExtraPins more
		Name = "Blast",
		Text = "%s%% chance to blast down an extra pin",
		Short = "BLAST %s%%",
		Display = 100,
		ExtraPins = 1,
		Popup = "BLAST!",
		Color = Color3.fromRGB(255, 120, 40),
		Fx = "Ring",
		FxSize = 24, -- ring width in studs
		Sound = "StrikeCrash",
		Pitch = 0.7,
	},
	{
		Id = "StreakSaver", -- Value: seconds between saves
		Name = "Streak Saver",
		Text = "A miss won't break your streak (once every %ss)",
		Short = "SAVER %ss",
		Display = 1,
		Popup = "STREAK SAVED!",
		Color = Color3.fromRGB(90, 160, 255),
		Fx = "Dome",
		Sound = "StreakUp",
		Pitch = 1.3,
		MinStreak = 2, -- only saves streaks of at least this many strikes
	},
	{
		Id = "Lucky", -- Value: extra Golden Pin chance (1 = twice as likely). Golden Pins arrive in 9.5d.
		Name = "Lucky",
		Text = "+%s%% Golden Pin chance",
		Short = "LUCKY +%s%%",
		Display = 100,
		Popup = "LUCKY!",
		Color = Color3.fromRGB(255, 215, 60),
		Fx = "Burst",
		Sound = "Coin",
		Pitch = 1.2,
	},
	{
		Id = "GemHunter", -- Value: extra chance of a gem on a Perfect Strike (0.1 = +10%)
		Name = "Gem Hunter",
		Text = "+%s%% gem chance on Perfect Strikes",
		Short = "GEMS +%s%%",
		Display = 100,
		Popup = "GEM HUNTER! +1 GEM",
		Color = Color3.fromRGB(255, 90, 200),
		Fx = "Burst",
		Sound = "Coin",
		Pitch = 1.6,
	},
	{
		Id = "Heavy", -- Value: how much wider the power sweet zone gets (0.5 = 50% wider)
		Name = "Heavy",
		Text = "Power sweet zone %s%% wider",
		Short = "HEAVY +%s%%",
		Display = 100,
		Popup = "HEAVY HIT!",
		Color = Color3.fromRGB(190, 190, 215),
		Fx = "Ring",
		FxSize = 12,
		Sound = "PinHit",
		Pitch = 0.6,
	},
}

-- Golden Pin: sometimes one pin in your rack is golden. Knock it down for a big bonus on that throw.
-- The Lucky ball trait raises the chance: Chance * (1 + Lucky strength).
Config.GoldenPin = {
	Chance = 1 / 15, -- chance for each new rack
	MaxChance = 0.5, -- never more than this, however lucky
	CoinMultiplier = 5, -- that throw's coins are multiplied by this
	GemChance = 0.3, -- chance of gems too...
	GemAmount = 2,
	CrateChance = 0.1, -- ...and chance of a free crate (see Config.FreeCrates)
	Color = Color3.fromRGB(255, 200, 40),
}

-- Free crates: earned from strikes (every StrikesPerCrate strikes) and Golden Pins.
-- They wait in the shop until the player opens them.
Config.FreeCrates = {
	CrateId = "Basic", -- which crate a free crate is
	StrikesPerCrate = 15,
}

-- The "almost there" bar above the throw meter: always shows the nearest reward.
Config.AlmostThere = {
	PulseAt = 0.8, -- the bar pulses once you are this far (80%) toward the reward
}

-- Lane modifiers: every Interval seconds the server picks a new one for the whole alley.
-- Adding a modifier = adding a row. Each row can use any of these (leave out what it doesn't need):
--   CoinMultiplier  coins on every throw are multiplied by this
--   StrikeGemChance / StrikeGemAmount  every strike has this chance of gems
--   PinSway / SwayPeriod  the pins slide side to side this many studs, one full slide every SwayPeriod seconds
--   PinScale / AimBonus  bigger pins (looks), and the perfect-aim zone grows by AimBonus (meter is -1..1)
-- Weight: how often it is picked compared to the others.
Config.LaneModifiers = {
	Interval = 90,
	List = {
		{
			Id = "DoubleCoins",
			Name = "DOUBLE COINS",
			Text = "Every throw pays x2 coins!",
			Color = Color3.fromRGB(255, 200, 40),
			Weight = 1,
			CoinMultiplier = 2,
		},
		{
			Id = "MovingPins",
			Name = "MOVING PINS",
			Text = "The pins slide side to side. Time your aim!",
			Color = Color3.fromRGB(60, 230, 255),
			Weight = 1,
			PinSway = 1.6,
			SwayPeriod = 3,
		},
		{
			Id = "BonusGems",
			Name = "BONUS GEMS",
			Text = "Every strike has a 20% chance of a gem!",
			Color = Color3.fromRGB(255, 90, 200),
			Weight = 1,
			StrikeGemChance = 0.2,
			StrikeGemAmount = 1,
		},
		{
			Id = "GiantPins",
			Name = "GIANT PINS",
			Text = "Huge pins are easier to hit, but pay x0.6 coins",
			Color = Color3.fromRGB(120, 255, 120),
			Weight = 1,
			PinScale = 1.4,
			AimBonus = 0.08,
			CoinMultiplier = 0.6,
		},
	},
}

-- Lobby showcase: display cases for the best balls, built from Config.Balls on the slots in Workspace.Showcase.Slots.
-- Every ball of MinRarity or better gets a case (best balls on the first slots). More balls than slots = add slots in Studio.
Config.Showcase = {
	MinRarity = "Epic",
	SpinSpeed = 0.8, -- ball turns per second
	BobHeight = 0.35, -- studs the ball floats up and down
	OrbitSpeed = 0.5, -- turns per second for the glowing trails around the ball
	OrbitsFromRarity = 3, -- orbiting trails = rarity number minus this (Epic 1, Legendary 2, Mythic 3)
	SparkleRate = 4, -- trait sparkles per second, per trait
	AnimateDistance = 110, -- only animate while your camera is this close (saves phone battery)
}

-- Your equipped ball, shown on your character so everyone can see it
Config.BallFx = {
	HeldSize = 1.1, -- the ball in your right hand (studs)
	TrailLifetime = 0.35, -- the ball's trail behind you while you move
	AuraFromRarity = "Rare", -- this rarity and better also get a sparkle aura...
	AuraRatePerRarity = 3, -- ...with this many sparkles per second for every rarity step above Uncommon
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
-- Traits: { TraitId = strength } using the rows in Config.Traits. Leave it out for no trait.
-- Keep each trait on a ladder so higher rarities are always clearly stronger:
--   Curve      Common 5%   Uncommon 12%  Rare 25%   Epic 35%   Mythic 60%
--   Blast      Uncommon 15%  Rare 35%  Epic 50%  Legendary 75%  Mythic 100%
--   Heavy      Common 5%   Uncommon 15%  Epic 40%   Mythic 80%
--   Lucky      Common 10%  Uncommon 30%  Rare 75%   Epic 125%  Legendary 200%
--   GemHunter  Common 1%   Epic 6-8%     Legendary 15%
--   StreakSaver (seconds between saves, lower = better)  Rare 60  Legendary 45  Mythic 30
-- Epic and up get two traits.
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
		Traits = { Lucky = 0.1 },
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
		Traits = { Curve = 0.05 },
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
		Traits = { Heavy = 0.05 },
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
		Traits = { GemHunter = 0.01 },
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
		Traits = { Curve = 0.12 },
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
		Traits = { Blast = 0.15 },
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
		Traits = { Lucky = 0.3 },
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
		Traits = { Heavy = 0.15 },
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
		Traits = { Blast = 0.35 },
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
		Traits = { Lucky = 0.75 },
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
		Traits = { StreakSaver = 60 },
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
		Traits = { Curve = 0.25 },
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
		Traits = { Heavy = 0.4, GemHunter = 0.06 },
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
		Traits = { Lucky = 1.25, GemHunter = 0.08 },
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
		Traits = { Blast = 0.5, Curve = 0.35 },
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
		Traits = { Lucky = 2.0, GemHunter = 0.15 },
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
		Traits = { Blast = 0.75, StreakSaver = 45 },
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
		Traits = { Curve = 0.6, StreakSaver = 30 },
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
		Traits = { Blast = 1, Heavy = 0.8 },
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

-- Daily reward: a 7-day calendar. Claim once per day (days change at midnight UTC).
-- Missing a whole day starts you back at day 1. After day 7 it loops back to day 1.
-- Each day can give Coins, Gems and/or a free Crate (a crate Id from Config.Crates).
Config.Daily = {
	Rewards = {
		{ Coins = 250 },
		{ Coins = 500 },
		{ Gems = 5 },
		{ Coins = 1000 },
		{ Coins = 1500 },
		{ Gems = 10 },
		{ Crate = "Neon", Gems = 15 },
	},
	CheckInterval = 30, -- seconds between checks for a new day while playing
}

-- Leaderboards (OrderedDataStores). Boards are read every RefreshInterval and
-- each player's scores are written every WriteInterval and when they leave, never per throw.
-- Stat = the saved player value the board ranks. Weekly boards start fresh every Monday 00:00 UTC.
Config.Leaderboards = {
	RefreshInterval = 90,
	WriteInterval = 120,
	FetchSize = 100, -- how many top scores to read; your position shows as "100+" below this
	ShowTop = 10,
	Boards = {
		{ Id = "Pins", Title = "MOST PINS", Stat = "LifetimePins", Store = "LB_LifetimePins" },
		{ Id = "Streak", Title = "BEST STREAK", Stat = "BestStreak", Store = "LB_BestStreak" },
		{
			Id = "Weekly",
			Title = "WEEKLY COINS",
			Stat = "WeeklyCoins",
			Store = "LB_WeeklyCoins",
			Weekly = true,
		},
	},
}

return Config
