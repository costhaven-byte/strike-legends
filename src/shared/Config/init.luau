-- All tunable numbers live here. Change values, not logic.
local Config = {}

-- Lane and pin sizes (studs). Arcade scale: bigger than real life so pins read well on mobile.
Config.Lane = {
	PinHeight = 2.8,
	PinWidth = 0.9,
	PinSpacing = 2.3, -- distance between neighbouring pins
	PinDensity = 0.35,
	BallDiameter = 1.8,
	PinCount = 10, -- pins in one rack (bigger racks per zone arrive in Milestone 12, see Config.Economy.Zones)

	LaneHalfWidth = 4, -- playable wood, centre to edge
	GutterOffset = 4.7, -- centre of the gutter, from lane centre
	GutterDepth = 0.6, -- how far below the lane surface the gutter is

	-- How hard knocked pins fly (studs per second)
	PinKnockSpeedMin = 14,
	PinKnockSpeedMax = 28,
	PinKnockUpSpeed = 10,

	-- Seconds from the ball reaching the pins until they reset
	PinResetDelay = 0.9, -- (strikes add the slow-motion time on top)

	-- How far (studs) a player can be from the lane's approach and still throw
	ThrowZoneMargin = 0.7, -- small, so it never reaches a neighbouring lane
}

-- The throw (from the Throw Lab, approved 2026-10-18): hold to charge, let go in the gold.
-- Lab sizes were bigger than the alley's, so pin speeds and pin gravity are scaled down to match automatically.
Config.Throw = {
	-- Charging
	ChargeTime = 0.75, -- seconds for the bar to fill. Lower = faster bar = harder
	MeterSpeedPerRank = 0.05, -- the bar gets 5% faster for every rank above Rookie
	-- The server times every hold itself (the client only says "started holding" and "let go").
	-- Internet lag makes the two clocks differ a little, so the client's own hold time is trusted
	-- only within this many seconds of the server's. Bigger = kinder to laggy players, easier to cheat.
	HoldTolerance = 0.1,
	MaxHoldTime = 30, -- holds longer than this count as this long
	SweetSpotCenter = 0.86, -- where the gold zone sits before a lane's first throw (0 = empty, 1 = full)
	SweetSpotSize = 0.08, -- how wide the gold zone is (share of the bar). Narrow on purpose: a PERFECT should feel earned
	SweetSpotMax = 0.14, -- ball bonuses never make the gold zone wider than this
	-- After every throw the gold jumps to a new spot on the arc, so you can't just repeat the same timing
	GoldSpotLowest = 0.45, -- lowest spot the gold can jump to (centre of the zone)
	GoldSpotHighest = 0.92, -- highest
	GoldSpotMinJump = 0.15, -- it always moves at least this far from where it was
	-- Every strike in a row makes the gold this much narrower (0.05 = 5%), but never below GoldSmallestShare
	-- of its normal size (0.75 = 75%). Was 10% down to 0.04 of the bar until 2026-10-19 (too hard to streak).
	GoldShrinkPerStrike = 0.05,
	GoldSmallestShare = 0.75,
	-- The throw animation: the arm swings back as the meter fills
	ReleaseDelay = 0.1, -- seconds from letting go until the ball leaves the hand (the down-swing)
	DownSwingTime = 0.13,
	FollowThroughTime = 0.2,
	PoseHoldTime = 0.35, -- holds the follow-through pose this long, then relaxes
	PoseRelaxTime = 0.35,
	PoseExaggeration = 1.3, -- every bend of the throw animation is this much bigger (1 = the original pose)
	-- Low Power Levels throw worse: level 1 is stiff, wobbly and flailing, and it gets cleaner every level
	PoseCleanLevel = 9, -- from this Power Level the throw is fully clean
	PoseWobble = 14, -- how far (degrees) a level 1 throw shakes; none at PoseCleanLevel
	PoseWobbleSpeed = 4, -- how fast the shaking is
	PoseFlairPerLevel = 0.06, -- each level above PoseCleanLevel swings this much bigger (level 12 = +18%)
	MeterStyle = "Side", -- "Side" = half circle standing up right of your bowler; "Arc" = lying flat
	HandBlendDistance = 10, -- the rolling ball drops from the hand onto the lane over this many studs
	ForgivenessScale = 6, -- a ball's Forgiveness 0.05 = gold zone 30% wider
	HitStop = 0.05, -- a PERFECT freezes the crash for this many seconds before the pins explode (makes it feel heavy)
	PerfectPowerBonus = 1.5, -- a PERFECT release is this much stronger than a full bar
	WeakestThrow = 0.35, -- strength of a quick tap (0 to 1)

	-- What gets knocked down. A PERFECT release is always a strike, and only a PERFECT can strike.
	StrikeChanceWithoutPerfect = 0, -- strike chance with a full bar outside the gold (0 = strikes only in the gold)
	-- also counts as PERFECT ("HOOK!"). Mythic Curve 0.6 = 6% of the bar on each side.
	FewestPinsKnocked = 3, -- fewest pins any throw knocks down
	GoodShare = 0.7, -- knocking down at least this share of the rack reads as a "Good" throw (7 of 10)

	-- The ball (studs per second at full strength). Higher = less waiting before the crash.
	BallSpeed = 80,

	-- Pin explosion (Throw Lab numbers)
	PinLaunchForce = 55, -- backwards and sideways
	PinLaunchUpward = 42, -- up into the air
	PinSpin = 30,
	PinSpreadTime = 0.05, -- seconds between the first and last pin taking off
	PinGravity = 90, -- pull on flying pins (normal is 196); characters keep normal gravity
	LabPinSpacing = 2.9, -- pin spacing in the Lab, used to scale the numbers above to this alley

	-- Power Levels 1-12 (bought with coins, see Config.Economy.PowerLevels): how the equipped ball looks,
	-- sounds and hits at each level. Every level adds something you can see on the very next throw.
	-- Size = rolling ball size (1 = normal; trimmed about 10% on 2026-10-18, owner: a tiny bit too big), Force = how hard pins fly, New = what the shop says this level adds
	Levels = {
		{ Size = 0.8, Force = 0.6, New = "" },
		{ Size = 0.95, Force = 0.8, New = "POWER TRAIL" },
		{ Size = 1.1, Force = 0.95, New = "SPARKS" },
		{ Size = 1.25, Force = 1.1, New = "BIGGER BALL" },
		{ Size = 1.4, Force = 1.3, New = "ON FIRE" },
		{ Size = 1.5, Force = 1.5, New = "HUGE TRAIL" },
		{ Size = 1.65, Force = 1.7, New = "MEGA CRASH" },
		{ Size = 1.8, Force = 1.9, New = "POWER AURA" },
		{ Size = 1.95, Force = 2.1, New = "CLEAN THROW" },
		{ Size = 2.15, Force = 2.3, New = "GIANT BALL" },
		{ Size = 2.35, Force = 2.5, New = "RAINBOW FIRE" },
		{ Size = 2.6, Force = 2.8, New = "MAXIMUM POWER" },
	},
	-- How loud the level effects are (owner 2026-10-18: "exaggerate them a bit more"). Bigger = stronger.
	LevelFx = {
		-- 2026-10-25 owner: ball light too bright (was range 8 + 2/level, brightness 1 + 0.45/level = 6.4 at level 12)
		GlowRange = 8, -- the ball's light: range in studs...
		GlowRangePerLevel = 1.5,
		GlowBrightness = 0.7, -- ...and brightness
		GlowBrightnessPerLevel = 0.2,
		TrailWidth = 0.5, -- power trail: half its width, as a share of the ball (+ per level)...
		TrailWidthPerLevel = 0.05,
		TrailMaxWidth = 3.2, -- studs, half width; never wider than the lane (Config.Lane.LaneHalfWidth = 4)
		TrailLife = 0.35, -- ...and how long it hangs in the air (seconds, + per level)
		TrailLifePerLevel = 0.04,
		SparkRate = 35, -- sparks per second at SparklesFromLevel (+ per level)
		SparkRatePerLevel = 25,
		SparkSize = 0.5, -- spark size in studs, plus this share of the ball
		FireSize = 1.5, -- flames, times the ball size
		AuraFill = 0.6, -- 0 = solid glow, 1 = no glow (was 0.45 before 2026-10-25)
		ReleaseBurst = 12, -- burst of the level's colour from the hand on release: sparks per level...
		ReleaseRingFromLevel = 4, -- ...plus a shockwave ring from this level
		LevelSoundDrop = 0.05, -- every level the ball sounds this much deeper...
		LevelSoundLoud = 0.08, -- ...and this much louder
	},
	PowerTrailFromLevel = 2, -- a bright streak behind the rolling ball, wider every level
	SparklesFromLevel = 3, -- sparks pour off the rolling ball
	FireFromLevel = 5, -- the ball is on fire
	MegaCrashFromLevel = 7, -- double shockwave, big flash, deep extra boom
	AuraFromLevel = 8, -- the ball glows with an outline in its own colour
	RainbowFromLevel = 11, -- rainbow flames and sparks
	CrashGrowthPerLevel = 0.25, -- each level makes the crash 25% bigger

	-- Camera
	CameraShakeStrength = 0.5,
	CameraShakeTime = 0.25,
	CameraPunch = 4, -- how far the camera jolts toward the pins on impact

	-- Strike slow motion
	SlowMotionStartsAfter = 0.12, -- full-speed explosion first, so the hit feels instant
	SlowMotionLength = 0.2, -- Addendum 2: at most 0.2 seconds, so the next throw comes quickly
	SlowMotionSpeed = 0.3,

	-- Number pops out of each pin (coins earned); better balls make them bigger (owner's design: SM 32, MD 52, CRIT 92)
	NumberPopSize = 22, -- 2026-10-22 owner: smaller so the pin numbers don't pile up (design was 32)
	NumberPopTime = 1.4, -- design: gone at 1.4 s
	NumberPopRise = 60, -- pixels it floats up (design 130; 2026-10-22 owner: less, so it stays out of the strike text)
	-- The "+480 COINS" payout pop (owner's design UI 1.4): fixed on the screen above the lane
	PayoutPopPosition = UDim2.fromScale(0.5, 0.56), -- under the result text and the XP line, above the throw button
	PayoutPopScale = 0.75, -- 2026-10-22 owner: smaller than the design so it doesn't overlap the strike text
	PayoutPopTime = 2.3, -- design: idle until 2.0 s, exit by 2.3 s
	-- Throw result text (owner's design UI 1.3): text sizes in pixels at 720 px screen height
	-- 2026-10-22 owner: all smaller so they don't overlap (design was Strike 92, Perfect 50, Overcooked 44, Pins 40)
	ResultSizes = { Strike = 62, Perfect = 36, Overcooked = 32, Pins = 28 },
	StreakGrowCap = 1.2, -- streak text never grows past this (was 1.35)

	-- Strike streak text on screen: "STRIKE!", then each Config.Streaks tier name the moment you reach it
	-- (DOUBLE! TURKEY! HAMBONE! WILD TURKEY! STREAK MASTER! PERFECT RUN!), "6 IN A ROW!" and so on in between
	SpecialStreaks = { 3, 5, 7, 10 }, -- extra-special celebration
	StreakGrowth = 0.15, -- each strike in a row celebrates 15% bigger...
	StreakGrowthStopsAt = 8, -- ...up to this many
	CelebrationTime = 0.8,

	-- Server waits this long after a roll before the lane takes another throw
	CooldownBuffer = 0.3,

	-- Overcharge: the greedy release. The top of the power bar is a red cap (the gold never goes there).
	-- Let go in the red and it's a gamble: either a huge OVERCHARGE strike that pays extra,
	-- or the ball overcooks into the gutter (0 pins, streak over). Safe gold or greedy red, every throw.
	Overcharge = {
		Enabled = true, -- false = no red cap, the bar works like before
		From = 0.94, -- the red cap starts here (0 = empty bar, 1 = full)
		SuccessChance = 0.5, -- chance a red release pays off
		CoinMultiplier = 2, -- an OVERCHARGE strike pays this many times a PERFECT
		PowerMultiplier = 1.5, -- and hits this much harder (pins fly further, bigger crash)
		GoldGap = 0.01, -- the gold zone always ends at least this far below the red cap
	},
}

-- What a player starts with the first time they join
Config.StartingData = {
	Coins = 0,
	Gems = 0,
	XP = 0,
	Rank = 1, -- index into Config.Ranks (1 = Rookie); raised by passing Rank Trials
	RankLevel = 1, -- highest rank level (1-60) whose level-up reward was given
	BestStreak = 0,
	EquippedBall = "Rookie",
	OwnedBalls = { Rookie = true }, -- set of ball Ids
	CratesSinceRare = 0, -- old shared pity counters (before v10), no longer used; kept so old saves stay valid
	CratesSinceEpic = 0,
	CratePity = {}, -- pity per crate (Config.Economy.CratePity): { ["Basic_Rare"] = pulls in a row without Rare+ }
	Polish = {}, -- Polish Points per ball from duplicates (Config.Economy.Polish): { Galaxy = 3 }
	CratesOpened = 0, -- crates opened ever (the first one is Config.Economy.FirstCrateMin or better)
	CratesBought = 0, -- crates bought with coins (not gift, free or daily crates); v11
	LifetimePins = 0, -- leaderboard: Most Pins
	WeeklyCoins = 0, -- leaderboard: coins earned from throws this week...
	WeeklyCoinsWeek = 0, -- ...and which week that was (see Calendar.Week)
	DailyDay = 0, -- last daily reward day claimed (1-7), 0 = never
	DailyLastClaim = 0, -- the day number (see Calendar.Day) it was claimed on
	CrateStrikes = 0, -- throws toward the next free crate (see Config.FreeCrates; was strikes before 2026-10-21)
	FreeCrates = 0, -- free crates waiting to be opened in the shop
	PlayTime = 0, -- total seconds played, for analytics ("bought ball tier 3 after 12 minutes")
	PowerLevel = 1, -- Power Level bought so far (Config.Economy.PowerLevels)
	SessionLog = {}, -- the last few play sessions (see Config.SessionLog), newest last
	Onboarding = 0, -- first 3 minutes (Config.Onboarding): 0 = first throw next, 1 = before the gift, 2 = gift given, 3 = done
	OnboardThrows = 0, -- throws counted toward the first-3-minutes moments
	Mascots = {}, -- mascots owned, by Id: { Pinny = 2 } (v13)
	EquippedMascots = {}, -- Ids following the player, one per slot (the same Id can fill two slots if owned twice)
	EggsHatched = 0, -- eggs hatched ever
	ZoneSeen = 1, -- highest zone whose "ZONE UNLOCKED" window was shown (v14)
	Potions = {}, -- potions waiting to be drunk, by Id: { CoinSmall = 2 } (Config.Potions; v15)
	Boosts = {}, -- seconds left on each drunk potion, by Id: { CoinSmall = 840 } (only ticks while playing; v15)
	FreeEggs = {}, -- free hatches waiting at the egg stand, by egg Id: { Alley = 1 } (Config.Playtime; v16)
	SpinDay = 0, -- the day number (see Calendar.Day) of the last free spin on the daily spin wheel (Config.Spin; v17)
	BossNextAt = 0, -- os.time() when the zone 4 helicopter can fly you to the boss again (Config.Boss; v18)
	Rebirths = 0, -- rebirths done (Config.Economy.Rebirth; v18)
}

-- Saving (DataStore)
Config.Data = {
	StoreName = "PlayerData",
	SchemaVersion = 18, -- v18 BossNextAt + Rebirths (Phase X). v2 added balls and crates, v3 daily reward and leaderboard stats, v4 saved Rank (Rank Trials), v5 free crates, v6 PlayTime, v7 SessionLog, v8 PowerLevel, v9 Onboarding, v10 5 crates (CratePity, Polish, CratesOpened), v11 CratesBought, v12 RankLevel (60 levels), v13 Mascots/EquippedMascots/EggsHatched, v14 ZoneSeen, v15 Potions/Boosts, v16 FreeEggs, v17 SpinDay. Bump when the save format changes, and add an upgrade step in SaveStore
	AutosaveInterval = 60, -- seconds between automatic saves
	MaxRetries = 5, -- attempts per load/save before giving up
	RetryDelay = 2, -- seconds; waits longer after each failed attempt
	LockTimeout = 300, -- a session lock older than this belongs to a crashed server and can be taken
	LockWaitTries = 6, -- if another server still holds the lock, wait and retry this many times...
	LockWaitDelay = 5, -- ...this many seconds apart, then take over
}

-- The first 3 minutes (Addendum 2 section 6): one scripted path for brand new players.
-- 1. The first throw is an assisted PERFECT strike (the whole arc turns gold).
-- 2. A big "BUY" callout points at the Power Level button the moment Level 2 is affordable.
-- 3. The first crate bought with coins (FirstCrateGoal) costs FirstCratePrice, so it's affordable inside the first
--    minute, and gives exactly a FirstBoughtRarity ball. Only that one purchase; crate odds and prices stay the same otherwise.
-- 4. After GiftAfterThrows throws (about 4 minutes): a free gift crate, opened right there (GiftRarity nil = normal odds),
--    with an EQUIP button.
-- 5. LegendsAfterThrows throws later: the camera swings to a locked ball in the lobby showcase (the chase).
-- The "next goal" bar on the HUD always shows the closest goal (next Power Level, the gift, the next free crate,
-- and the FirstCrateGoal crate until the player has bought a crate; when that crate is the goal and affordable,
-- a beam leads to its kiosk station).
Config.Onboarding = {
	Enabled = true,
	GiftAfterThrows = 65, -- about 4:00 (measured ~3.6 seconds a throw with buying and crates), after the first bought crate
	GiftCrateId = "Basic", -- the gift opens as this crate
	GiftRarity = nil, -- nil = the gift crate rolls normal odds (owner 2026-10-21: only the first crate is guaranteed)
	FirstCrateGoal = "Basic", -- this crate is a "next goal" until the first crate bought with coins (CratesBought)
	FirstCratePrice = 1000, -- the first FirstCrateGoal crate a player buys costs this (normal price after), ~0:45
	FirstBoughtRarity = "Uncommon", -- the first crate a player buys with coins always gives this rarity
	LegendsAfterThrows = 3, -- throws after the gift: the camera shows a locked showcase ball, then the daily unlocks
	LegendsPanTime = 3.5, -- seconds the camera looks at the locked ball
	-- Studio testing: every play test starts as a brand new player and nothing is saved (your real save is untouched).
	-- Never affects the live game. Set to false to test with your saved progress.
	StudioNewPlayer = false,
	-- Studio testing with your saved progress (StudioNewPlayer = false): every built zone is open (rank level raised
	-- to the last built zone's level, its popups marked seen, first-3-minutes done) for the test only. Nothing from
	-- the test is saved: your real save is handed back exactly as it was loaded. Never affects the live game.
	StudioUnlockAll = true,
}

-- Session log: one line per play session (join, leave, throws, crates, level), printed in Output
-- when the player leaves and saved with the player (only the newest Keep sessions).
-- Also counts PERFECT throws (the assisted first throw is counted apart), and for a brand new player's first
-- session writes a timeline of every reward moment in the first First5Seconds seconds.
-- Read it after a playtest: the Output window prints it at 5:00 and when you leave; in Studio the
-- TEST: REPORT button (under the Power Level button) prints it any time.
Config.SessionLog = {
	Keep = 10,
	Print = true,
	First5Seconds = 300,
}

-- Requests a player can't send faster than this (seconds). Extra ones are ignored by the server.
Config.RateLimits = {
	Throw = 2, -- the fastest real throw cycle measured 2026-10-18 is 2.2s (lane free again after letting go)
	ThrowHold = 0.1, -- "started holding" messages
	EquipBall = 0.25,
	OpenCrate = 1,
	ClaimDaily = 1,
	StartTrial = 1,
	BuyPowerLevel = 0.5,
	BuyPolish = 0.3,
	HatchEgg = 1,
	EquipMascot = 0.15,
	UsePotion = 0.3,
	ClaimPlaytime = 0.5,
	SpinWheel = 1,
	RideElevator = 2,
	RideHelicopter = 2,
	Rebirth = 3,
}

-- Gems on/off switch. Addendum 1 keeps gems (earned only, a gem sink comes later); set Enabled = false to hide them.
-- While off: no gem drops, the HUD hides the gem counter, and Gem Hunter pays bonus coins instead.
-- Saved gem balances are kept untouched either way, so switching loses nothing.
Config.Gems = {
	Enabled = true,
	HunterCoinBonus = 1, -- while gems are off, a Gem Hunter hit adds this share of the throw's coins (1 = +100%)
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

-- Pro Tiers. Each tier holds 6 of the 60 rank levels (Config.Economy.Ranks: levels 1-6 Rookie, 7-12 Amateur ...
-- 55-60 Hall of Famer). Levels inside a tier come straight from XP; a tier's first level needs its Rank Trial
-- (see Config.Trials) once the XP is there. Coin multiplier is permanent; gems are a one-time tier reward.
-- A tier's XP is the XP of its first level (Progression.TierXP), so it follows the level curve.
-- (Before step 7a the tiers had their own XP: 0, 300, 600, 2000, 6000, 18000, 50000, 140000, 400000, 1000000.)
Config.Ranks = {
	{ Name = "Rookie", Multiplier = 1.0, Gems = 0, Color = Color3.fromRGB(200, 200, 210) },
	{ Name = "Amateur", Multiplier = 1.25, Gems = 5, Color = Color3.fromRGB(120, 230, 120) },
	{ Name = "Regular", Multiplier = 1.5, Gems = 10, Color = Color3.fromRGB(80, 200, 255) },
	{ Name = "Club", Multiplier = 2.0, Gems = 15, Color = Color3.fromRGB(60, 120, 255) },
	{ Name = "Semi-Pro", Multiplier = 2.5, Gems = 20, Color = Color3.fromRGB(170, 90, 255) },
	{ Name = "Pro", Multiplier = 3.0, Gems = 30, Color = Color3.fromRGB(255, 60, 210) },
	{ Name = "Elite", Multiplier = 4.0, Gems = 40, Color = Color3.fromRGB(255, 70, 70) },
	{ Name = "Master", Multiplier = 5.0, Gems = 50, Color = Color3.fromRGB(255, 150, 30) },
	{ Name = "Legend", Multiplier = 7.0, Gems = 75, Color = Color3.fromRGB(255, 220, 60) },
	{ Name = "Hall of Famer", Multiplier = 10.0, Gems = 100, Color = Color3.fromRGB(255, 255, 255) },
}

-- Rank Trials: the test you pass to reach a rank once your XP bar is full.
-- Types: what a trial counts. Counts = which throws count ("Strike" includes Perfect Strikes, "Perfect" only those).
-- InARow = they must come one after another (a miss starts the count again).
-- Text: %d = Goal, then Throws.
-- Ranks: one trial per rank you are trying to reach. A rank with no row here is given straight away.
Config.Trials = {
	Cooldown = 60, -- seconds to wait after failing before you can try again (a rank row's own Cooldown wins)
	Types = {
		Strikes = { Counts = "Strike", InARow = false, Text = "Get %d strikes in %d throws" },
		Streak = { Counts = "Strike", InARow = true, Text = "Get %d strikes in a row within %d throws" },
		Perfects = { Counts = "Perfect", InARow = false, Text = "Hit %d Perfect Strikes in %d throws" },
		PerfectRow = { Counts = "Perfect", InARow = true, Text = "Hit %d Perfect Strikes in a row within %d throws" },
	},
	Ranks = {
		-- The first two ranks have no cooldown, and Amateur needs only 1 strike, so the first rank-up is reliable
		Amateur = { Type = "Strikes", Goal = 1, Throws = 6, Cooldown = 0 },
		Regular = { Type = "Strikes", Goal = 3, Throws = 8, Cooldown = 0 },
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
	PerfectStrikeBonus = 1, -- +100% coins on a Perfect Strike (Addendum 2: crit x2), instead of the Strike bonus

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

	ResultSlamScale = 1.5, -- STRIKE! text starts this much bigger and shrinks into place (kept small so the pins stay visible)
	ResultStrikeTime = 1.2, -- seconds a STRIKE! stays up (other results: ResultTime)
	ResultTime = 0.9,
}

-- Screen layout
Config.Ui = {
	CompactHeight = 500, -- screens shorter than this (phones held sideways) use the compact phone layout
	CountTime = 0.6, -- seconds for a HUD number to tick up to its new value
	RankUpShowTime = 4, -- seconds before the rank-up screen closes by itself
	RankUpConfetti = 40, -- confetti pieces on the rank-up screen
	-- Roblox's own player list sits in the top-right corner on computers, where the GIFTS button is now (owner 2026-10-22).
	-- The game shows no stats in it (no leaderstats), so it is hidden; set false to bring it back.
	HidePlayerList = true,
}

-- Big numbers (Phase X Part 8A). Every number on screen goes through Shared.Modules.Currency.Format and all coin
-- math through Currency (add, spend, boosts, compare, save/load), so the number type can change later.
Config.Numbers = {
	-- 1K = 1,000, 1M = 1,000,000 ... each suffix is 1,000 times the one before. Add more at the end for bigger numbers.
	Suffixes = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid" },
	ShortFrom = 1000, -- smaller numbers show whole, with commas ("950")
	Decimals = 2, -- "12.34M"; numbers of 100 or more in a unit get one less ("123.4M"); trailing zeros are trimmed
	Currencies = { "Coins", "Gems", "WeeklyCoins" }, -- saved values that are money: they go through Currency
	-- Precision guard: plain Roblox numbers stop counting whole coins exactly at about 9 quadrillion (9e15).
	-- Any coin value at WarnAt or above logs a warning (once per place in the code), long before that limit.
	SafeMax = 9e15,
	WarnAt = 1e15,
}

-- Sound effects: every sound slot and its asset ID lives in Shared.AssetSlots
-- (tools/EconomySim requires a parentless copy of this module, hence the fallback)
local shared = script.Parent or game:GetService("ReplicatedStorage"):WaitForChild("Shared")
Config.Sounds = require(shared:WaitForChild("AssetSlots") :: any).Sounds

-- Ball traits: special powers that change how a ball plays. Adding a trait = adding a row here
-- (and, for a brand-new kind of power, a few lines where the server applies it).
-- A ball's strength number means something different per trait, see Value below.
-- Text: full description (%s = the strength, already scaled by Display). Short: the tag on inventory tiles.
-- Popup: the text that flashes on screen when the trait kicks in (PopupColor if set, else Color).
-- Colours come from the design system. The effect itself lives in Config.TraitFx (client TraitFx module).
-- Sound: a name from Config.Sounds, played at Pitch.
Config.Traits = {
	{
		Id = "Curve", -- Value: how much wider the PERFECT window gets (0.25 = 25% wider), shown as magenta edges on the gold
		Name = "Curve",
		Text = "PERFECT window %s%% wider (the magenta edges count as PERFECT), and every throw hooks",
		Short = "CURVE %s%%",
		Display = 100,
		Popup = "HOOK!",
		Color = Color3.fromHex("FF2BD6"), -- magenta
		Sound = "Throw",
		Pitch = 1.5,
		HookSide = 1, -- 1 = aims right of centre hook back in, -1 = left
	},
	{
		Id = "Blast", -- Value: chance (0-1) per throw of a blast: ExtraPins more on a miss, a huge explosion on a strike
		Name = "Blast",
		Text = "%s%% chance per throw to BLAST: an extra pin, or a giant explosion on strikes",
		Short = "BLAST %s%%",
		Display = 100,
		ExtraPins = 1,
		Popup = "BLAST!",
		Color = Color3.fromHex("FFE600"), -- yellow
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
		Color = Color3.fromHex("19E3FF"), -- cyan (the shield bubble)
		PopupColor = Color3.fromHex("7CFF3A"), -- lime
		Sound = "StreakUp",
		Pitch = 1.3,
		MinStreak = 2, -- only saves streaks of at least this many strikes
	},
	{
		Id = "Lucky", -- Value: extra Golden Pin chance (1 = twice as likely)
		Name = "Lucky",
		Text = "+%s%% Golden Pin chance",
		Short = "LUCKY +%s%%",
		Display = 100,
		Popup = "LUCKY!",
		Color = Color3.fromHex("7CFF3A"), -- lime
		Sound = "Coin",
		Pitch = 1.2,
	},
	{
		Id = "GemHunter", -- Value: extra chance of a gem on a Perfect Strike (0.1 = +10%)
		Name = "Gem Hunter",
		Text = "+%s%% gem chance on Perfect Strikes",
		Short = "GEMS +%s%%",
		Display = 100,
		Popup = "+%d GEM", -- %d = gems paid
		-- Used while Config.Gems.Enabled is false: the same chance pays bonus coins
		NoGemsName = "Coin Hunter",
		NoGemsText = "+%s%% chance of bonus coins on Perfect Strikes",
		NoGemsShort = "COINS +%s%%",
		NoGemsPopup = "+%s COINS", -- %s = coins paid
		Color = Color3.fromHex("19E3C0"), -- gem
		Sound = "Coin",
		Pitch = 1.6,
	},
	{
		Id = "Heavy", -- Value: how much wider the gold zone on the charge bar gets (0.5 = 50% wider). Every strike hits HEAVY.
		Name = "Heavy",
		Text = "Gold zone %s%% wider, and every strike lands a HEAVY HIT",
		Short = "HEAVY +%s%%",
		Display = 100,
		Popup = "HEAVY HIT!",
		Color = Color3.fromHex("FF3B5C"), -- red
		Sound = "PinHit",
		Pitch = 0.6,
	},
}

-- Trait trigger effects, from the owner's "Trait Effects" handoff sheet (times in seconds).
-- Sizes on the sheet are drawn next to a 26px ball, so here they're in studs (ball = 1.8 studs).
local INK = Color3.fromHex("06060F")
Config.TraitFx = {
	Ink = INK,
	PixelsPerStud = 40, -- detail of the flat effects drawn on the lane (rings, cracks)
	Brightness = 2.5, -- how hard the flat effects glow
	FloorLift = 0.04, -- flat effects sit this far above the lane so they don't flicker
	-- Popup text for every trait: Luckiest Guy, ink drop shadow, a glow in the trait colour
	Popup = {
		TextSize = 30, -- pixels on a 1080p screen, scaled with the screen (was 40 before 2026-10-22)
		MinTextSize = 20,
		Shadow = 4, -- ink drop shadow, pixels down
		GlowTransparency = 0.6,
		PopFrom = 0.6, -- pops in from this size (ease-pop overshoots to ~1.08)
		PopTime = 0.36,
		HoldTime = 0.9,
		ExitTime = 0.14,
		Rise = 12, -- pixels it rises while fading out
		StackGap = 48, -- each extra popup sits this far above the last
		Margin = 64, -- keep out of the screen corners...
		BottomMargin = 180, -- ...and the thumb area at the bottom
	},
	Curve = {
		Core = Color3.fromHex("FFFFFF"),
		Glow = Color3.fromHex("FF2BD6"),
		Tail = Color3.fromHex("B3109A"),
		Width = 1.25, -- glow ribbon width at the ball (tapers to 0 at the tail)
		CoreWidth = 0.28,
		Lifetime = 0.6, -- each piece of ribbon fades over this
		MaxLength = 1 / 3, -- share of the lane
		FadeOut = 0.3, -- whole trail fades after the ball hits the pins
		Brightness = 3,
	},
	Blast = {
		Flash = Color3.fromHex("FFFFFF"),
		Ring1 = Color3.fromHex("FFE600"),
		Ring2 = Color3.fromHex("FF2BD6"),
		FlashSize = 2.2, -- 1.2x the ball
		FlashTime = 0.12,
		RingRadius = 3, -- in pin spacings
		RingTime = 0.5,
		Ring2Delay = 0.08,
		StrokeStart = 0.42, -- ring line thickness in studs, thinning as it grows
		StrokeEnd = 0.07,
		Shake = 0.35,
	},
	StreakSaver = {
		Bubble = Color3.fromHex("19E3FF"),
		Rim = Color3.fromHex("0A8FB8"),
		Size = 1.4, -- bubble width vs the streak counter
		Tint = 0.8, -- how clear the middle of the bubble is
		PopFrom = 0.4,
		PopTime = 0.36,
		JoltAt = 0.24, -- the counter gets knocked sideways near the end of the pop
		Jolt = 6, -- pixels
		JoltTime = 0.12,
		WobbleTime = 0.2, -- 0.94 -> 1.03 -> 1
		HoldTime = 0.6,
		ExitTime = 0.24, -- grows to ExitScale and fades, bursting into sparkles
		ExitScale = 1.25,
		Sparkles = 10,
	},
	Lucky = {
		Clover = Color3.fromHex("7CFF3A"),
		Shade = Color3.fromHex("3DAA10"),
		Sparkles = { Color3.fromHex("FFE600"), Color3.fromHex("FFFFFF") },
		CloverSize = 64, -- pixels
		Ledge = 4, -- ink ledge under the clover, pixels
		Tilt = 15, -- degrees it settles at (spins in from -30)
		PopTime = 0.36,
		HoldTime = 0.6,
		ExitTime = 0.14,
		SparkleCount = 6,
		SparkleSize = { 16, 24 }, -- pixels
		SparkleTime = 0.45,
		SparkleStagger = 0.14,
		RingScale = 1.2, -- sparkle ring vs the rack's width
	},
	GemHunter = {
		Sparkle = Color3.fromHex("19E3FF"),
		Gem = Color3.fromHex("19E3C0"),
		Interval = 0.06, -- one sparkle this often behind the ball
		Jitter = 0.55, -- studs either side
		Size = 0.7, -- studs, +-SizeRange
		SizeRange = 0.27,
		Lifetime = 0.5,
		GemSize = 48, -- payout gem, pixels
		PopTime = 0.36,
		FlyTime = 0.24,
		Bump = 1.15, -- the HUD gem counter bumps to this
	},
	Heavy = {
		Ink = INK,
		Glow = Color3.fromHex("FF3B5C"),
		Deep = Color3.fromHex("B3132F"),
		Dust = Color3.fromHex("A9A3D6"),
		FlashTime = 0.1,
		Shake = 0.55,
		Branches = { 5, 7 },
		Length = { 4.2, 8.3 }, -- studs per crack branch
		InkWidth = 0.21,
		GlowWidth = 0.62,
		DrawTime = 0.2,
		HoldTime = 1.5,
		FadeTime = 0.4, -- glow cools to Deep and fades
		DustTime = 0.5,
		DustGrow = 1.6,
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
	CrateChance = 0, -- ...and chance of a free crate (owner 2026-10-21: no random free crates; see Config.FreeCrates)
	Color = Color3.fromRGB(255, 200, 40),
}

-- Free crates: one every ThrowsPerCrate throws (owner 2026-10-21: rare, so they feel valuable; no random ones).
-- They wait at Rizzo's cart / the Crate Shop until the player opens them.
-- The count is saved in the old CrateStrikes field (now counts throws, not strikes).
Config.FreeCrates = {
	CrateId = "Basic", -- which crate a free crate is
	ThrowsPerCrate = 250, -- about 12-15 minutes of play
}

-- The "almost there" bar above the throw meter: always shows the nearest reward.
Config.AlmostThere = {
	PulseAt = 0.8, -- the bar pulses once you are this far (80%) toward the reward
}

-- Lane modifiers: every Interval seconds the server picks a new one for the whole alley.
-- Adding a modifier = adding a row. Each row can use any of these (leave out what it doesn't need):
--   CoinMultiplier  coins on every throw are multiplied by this
--   StrikeGemChance / StrikeGemAmount  every strike has this chance of gems
--   SweetSway / SwayPeriod  the gold zone slides down the charge bar by up to this much and back, every SwayPeriod seconds
--   PinScale / SweetBonus  bigger pins (looks), and the gold zone gets this share wider (0.5 = 50%)
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
			Name = "MOVING GOLD",
			Text = "The gold zone slides! Let go when the bar meets it",
			Color = Color3.fromRGB(60, 230, 255),
			Weight = 1,
			SweetSway = 0.25,
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
			NeedsGems = true, -- left out of the rotation while Config.Gems.Enabled is false
		},
		{
			Id = "GiantPins",
			Name = "GIANT PINS",
			Text = "Huge pins are easier to hit, but pay x0.6 coins",
			Color = Color3.fromRGB(120, 255, 120),
			Weight = 1,
			PinScale = 1.4,
			SweetBonus = 0.5,
			CoinMultiplier = 0.6,
		},
	},
}

-- Display cases (Phase X Part 7): one data-driven case set per zone. Each set shows every ball that drops in its zone
-- (Config.Balls Zone, not Retired) on its Slots (parts under Workspace, ordered by their Order attribute, best ball
-- first) and its egg's pets on its Shelf. Not owned = dark silhouette, no glow; owned = lit up.
-- A case = three layers: Base structure (Themes: the zone's look, colours + materials), rarity Accent (Styles
-- Accent: bands, padlock, sign border) and rarity FX (Styles: rings, halo, dots, beam, aura, motes). Styles are
-- shared by every zone and keyed by rarity, so a new zone or a new rarity only needs a Themes or Styles row.
-- Legendary and Mythic also change the structure a little (gold posts and diamonds on the roof: Posts, Gems).
-- Zone 3 and 4 themes are PLACEHOLDERS (the zone 2 base recoloured) until their hero case designs arrive.
Config.Showcase = {
	Sets = {
		{ Zone = 2, Slots = { "Showcase", "Slots" }, Shelf = { "Showcase", "MascotShelf" }, Egg = "Alley", Theme = "Neon" },
		{
			Zone = 3,
			Slots = { "MainStreetLanes", "Showcase", "Slots" },
			Shelf = { "MainStreetLanes", "Showcase", "MascotShelf" },
			Egg = "Arcade",
			Theme = "MainStreet",
		},
		{
			Zone = 4,
			Slots = { "SkylineLanes", "Showcase", "Slots" },
			Shelf = { "SkylineLanes", "Showcase", "MascotShelf" },
			Egg = "Skyline",
			Theme = "Skyline",
		},
	},
	-- Base structure colours per zone (Navy = the case body, NavyTop = roof, BlueCap = base top, Pedestal = the
	-- ball's stand, SignBg = the sign, CaseLight = the light inside). Materials: optional, per colour name.
	Themes = {
		Neon = { -- the owner's display_case design
			Ink = Color3.fromRGB(14, 13, 26),
			Navy = Color3.fromRGB(26, 28, 82),
			NavyTop = Color3.fromRGB(30, 34, 118),
			BlueCap = Color3.fromRGB(58, 48, 176),
			Pedestal = Color3.fromRGB(24, 24, 66),
			Glass = Color3.fromRGB(191, 232, 255),
			SignBg = Color3.fromRGB(22, 20, 62),
			SignTop = Color3.fromRGB(58, 48, 128),
			CaseLight = Color3.fromRGB(190, 205, 255),
		},
		MainStreet = { -- PLACEHOLDER: wood, chrome, warm light
			Ink = Color3.fromRGB(34, 22, 14),
			Navy = Color3.fromRGB(110, 70, 40),
			NavyTop = Color3.fromRGB(84, 52, 30),
			BlueCap = Color3.fromRGB(196, 198, 206),
			Pedestal = Color3.fromRGB(150, 152, 160),
			Glass = Color3.fromRGB(255, 240, 220),
			SignBg = Color3.fromRGB(46, 30, 20),
			SignTop = Color3.fromRGB(120, 80, 46),
			CaseLight = Color3.fromRGB(255, 220, 170),
			Materials = { Navy = Enum.Material.Wood, NavyTop = Enum.Material.Wood, BlueCap = Enum.Material.Metal, Pedestal = Enum.Material.Metal },
		},
		Skyline = { -- PLACEHOLDER: clean, bright, sky tones
			Ink = Color3.fromRGB(40, 50, 84),
			Navy = Color3.fromRGB(232, 240, 255),
			NavyTop = Color3.fromRGB(205, 222, 250),
			BlueCap = Color3.fromRGB(120, 182, 255),
			Pedestal = Color3.fromRGB(196, 212, 240),
			Glass = Color3.fromRGB(220, 240, 255),
			SignBg = Color3.fromRGB(34, 46, 90),
			SignTop = Color3.fromRGB(90, 140, 220),
			CaseLight = Color3.fromRGB(235, 242, 255),
		},
	},
	SparkleRate = 4, -- trait sparkles per second, per trait
	AnimateDistance = 110, -- only animate while your camera is this close (saves phone battery)

	-- Every case uses the owner's display case design (navy case, glass, pedestal, sign).
	Case = {
		CaseScale = 4.5, -- studs per unit of the display_case design (4.5 = 5.6 studs wide, 11 tall)
		SpinSpeed = 0.35, -- ball turns per second
		BobHeight = 0.25, -- studs the ball floats up and down (it never dips into its pedestal)
		RingSpeed = 0.4, -- turns per second for the rings around the ball
		RingRadius = 0.38, -- ring size, in case design units (the glass is 0.47 from the middle)
		RingWidth = 0.14, -- studs
		GemSpinSpeed = 0.25, -- turns per second for the diamond on top
		MoteSpeed = 0.12, -- turns per second for the specks circling the case
		BeamHeight = 9, -- studs above the case where the light beam starts
		GlowTexture = "rbxassetid://123280301429602", -- soft round glow dot (sl_glow_dot.png)
	},

	-- Rarity accent + FX layers, from the owner's renders (shared by every zone). Leave a line out to turn that effect off.
	-- A new rarity tier needs a row here (missing rows fall back to Common).
	-- Accent: glowing bands, padlock, sign border. Posts: "Gold" or "Black". Gems: diamonds on top (colour).
	-- Beam: light from above (colour). Light: how bright the case lights are (1 = normal, lower = moodier).
	-- Rings: rings orbiting the ball. Halo: soft glow sphere around the ball. InnerGlow: light behind the ball.
	-- Dots: floating glow dots { colours, per second, size, spread in case units }. Motes: specks circling the case.
	-- Aura: a faint glow around the whole case (colour). Shade: darkens the whole case (1 = normal).
	Styles = {
		Common = { Accent = Color3.fromRGB(225, 228, 240), Posts = "Black" },
		Uncommon = { Accent = Color3.fromRGB(120, 235, 165), Posts = "Black" },
		Rare = { Accent = Color3.fromRGB(105, 175, 255), Posts = "Black" },
		Epic = {
			Accent = Color3.fromRGB(170, 100, 255),
			Posts = "Black",
			Rings = 1,
			Halo = true,
			InnerGlow = Color3.fromRGB(170, 90, 255),
			Dots = { Colors = { Color3.fromRGB(210, 160, 255) }, Rate = 3, Size = 0.15, Spread = 0.8 },
		},
		Legendary = {
			Accent = Color3.fromRGB(255, 222, 140),
			Posts = "Gold",
			Gems = Color3.fromRGB(255, 180, 50),
			Beam = Color3.fromRGB(255, 170, 80),
			Light = 0.8,
			Rings = 2,
			Halo = true,
			InnerGlow = Color3.fromRGB(255, 170, 60),
			Dots = { Colors = { Color3.fromRGB(255, 200, 90) }, Rate = 8, Size = 0.2, Spread = 2.2 },
			Aura = Color3.fromRGB(255, 180, 60),
		},
		Mythic = {
			Accent = Color3.fromRGB(235, 240, 255),
			Posts = "Gold",
			Gems = Color3.fromRGB(235, 240, 255),
			Beam = Color3.fromRGB(190, 205, 255),
			Light = 0.4, -- more shadowy than the others (owner's request)
			Shade = 0.7, -- darker case and bands too
			Rings = 3,
			RingColors = { Color3.fromRGB(235, 240, 255), Color3.fromRGB(70, 230, 255), Color3.fromRGB(255, 70, 190) },
			Halo = true,
			InnerGlow = Color3.fromRGB(150, 120, 255),
			Dots = {
				Colors = { Color3.fromRGB(70, 230, 255), Color3.fromRGB(255, 70, 190) },
				Rate = 9,
				Size = 0.4,
				Spread = 1.8,
			},
			Motes = 16,
			Aura = Color3.fromRGB(255, 50, 120),
			SignGradient = true, -- pink-to-cyan sign border and name, like the render
		},
	},
}

-- Your equipped ball, shown on your character so everyone can see it
Config.BallFx = {
	HeldSize = 1.1, -- the ball in your right hand (studs)
	TrailLifetime = 0.35, -- the ball's trail behind you while you move
	AuraFromRarity = "Rare", -- this rarity and better also get a sparkle aura...
	AuraRatePerRarity = 3, -- ...with this many sparkles per second for every rarity step above Uncommon
}

-- Ball effects (trail, sparkles, orbit rings, glow) copied from the owner's ball renders and videos.
-- Played on the lane ball, the ball in your hand and the Vault cases (BallFx module on the client).
-- Every size is in ball widths (1 = the ball's diameter), so one look fits every place the ball shows up.
--   Trails:    comet streaks behind a rolling ball. Colors run from the ball back to the tail.
--              Glow (0-1): how additive the body is; lower keeps strong colours from washing out to white.
--              BodyTexture: an image name whose own colours replace the body's (Supernova's rainbow).
--              Each row is drawn in the layers of TrailLayers below.
--   Particles: Image, Colors, Rate (per second), Size, Life, Speed, Rise (pull upward),
--              Radius (spawn on a shell this far out), Twinkle (grow then shrink), Spin (degrees/second)
--   Rings:     thin glowing orbit rings. Tilt = { x, z } degrees, Spin = turns per second around the ball
--   Disk:      a flat glowing disk around the ball. Spin in degrees per second
--   Pieces:    the ball's own model pieces that float around it without rolling (ReplicatedStorage.BallFxPieces.<Id>,
--              built in Studio from the owner's files). { PieceName = degrees per second it turns round the up axis }
--   Halos:     camera-facing glows around the ball. Ground: glowing rings on the floor under the ball
--   Badge:     the trait icon floating above Rare balls. Light: the glow the ball throws around it
-- A ball without a row gets a simple trail in its Trail colour.
local WHITE = Color3.fromRGB(255, 255, 255)
Config.BallVfx = {
	Dim = 0.8, -- every ball effect's glow (lights, trails, sparkles) is this bright; lower = dimmer (owner 2026-10-22: a tad too bright)
	LightDim = 0.6, -- the ball's own lights on top of Dim (owner 2026-10-25: light from the ball too bright)
	HeldRate = 0.5, -- the ball in your hand uses this share of the sparkles (no trail, floor rings or badge)
	Images = {
		Ring = "rbxassetid://132592068787018",
		Disk = "rbxassetid://108350014126813",
		Star = "rbxassetid://77287225484408",
		Diamond = "rbxassetid://113877677543813",
		Bolt = "rbxassetid://95198117224211",
		Flame = "rbxassetid://92245452670752",
		Dot = "rbxassetid://123280301429602",
		Shield = "rbxassetid://124964835477907",
		Spiral = "rbxassetid://135987951766702",
		Clover = "rbxassetid://78517109940877",
		Burst = "rbxassetid://71546142790002",
		TrailSoft = "rbxassetid://109547705047240", -- soft falloff across the width (SL_Trail_Soft)
		TrailCore = "rbxassetid://135350987657237", -- tight bright line (SL_Trail_Core)
		TrailWisp = "rbxassetid://124462490268355", -- flowing vapour strands, tiles along the trail (SL_Trail_Wisp)
		TrailRainbow = "rbxassetid://109513255032556", -- rainbow bands across the width + vapour (SL_Trail_Rainbow)
	},
	-- Every trail row is drawn as these layers so it reads as real light: a wide soft glow, a wispy body
	-- that spreads out and thins as it ages, and a short hot core in the row's colours (lightened).
	-- Width/Lifetime multiply the row's. Fade = extra see-through on top of the row's Transparency.
	-- Spread = width at the ball -> width at the tail. Emission = how additive (1 = pure glow); the body
	-- uses the row's Glow if set. Repeat = ball widths per repeat of a tiling texture (it stays put in the
	-- world as the ball rolls on, like vapour left behind). Rows with their own Texture (Bolt) stay one layer.
	-- Motion (keeps a trail alive instead of a fixed shape behind the ball): Twist = turns per second the
	-- ribbon spirals around the ball's path (+/- = direction, Phase = its starting angle), Wobble = how far
	-- it sways (ball widths), Shimmer = how much its brightness flickers.
	TrailLayers = {
		{
			Texture = "TrailSoft",
			Width = 1.5,
			Lifetime = 1.2,
			Fade = 0.8,
			Spread = { 1, 1.25 },
			Emission = 0.8,
			Wobble = 0.12,
			Shimmer = 0.25,
		},
		{
			Texture = "TrailWisp",
			Body = true, -- a row's BodyTexture replaces this layer's texture, and its Glow its Emission
			Width = 1.1,
			Lifetime = 1,
			Fade = 0.15,
			Spread = { 0.85, 1.3 },
			Emission = 0.55,
			Repeat = 2.5,
			Wobble = 0.08,
		},
		-- two streamers spiralling around each other
		{
			Texture = "TrailWisp",
			Body = true,
			Width = 0.8,
			Lifetime = 0.9,
			Fade = 0.3,
			Spread = { 0.7, 1.4 },
			Emission = 0.7,
			Repeat = 3,
			Twist = 3,
		},
		{
			Texture = "TrailWisp",
			Body = true,
			Width = 0.8,
			Lifetime = 0.9,
			Fade = 0.3,
			Spread = { 0.7, 1.4 },
			Emission = 0.7,
			Repeat = 3,
			Twist = -2.2,
			Phase = 90,
		},
		{
			Texture = "TrailCore",
			Width = 0.25,
			Lifetime = 0.35,
			Fade = 0.3,
			Spread = { 1, 0.15 },
			Emission = 0.5,
			Lighten = 0.1,
			Wobble = 0.04,
			Shimmer = 0.4,
		},
	},
	-- Soft puffs in the trail's colours that peel off behind the ball, drift up, grow, turn and fade.
	-- Size = ball widths at birth -> at death (times the row's Width). Rise = upward pull. Spin = degrees/second
	TrailWisps = {
		Image = "Dot",
		Rate = 40,
		Size = { 0.4, 1.6 },
		Life = { 0.5, 0.9 },
		Speed = { 0.3, 1 },
		Rise = 0.8,
		Transparency = 0.4,
		Spin = 40,
		Emission = 0.6,
	},
	Balls = {
		-- Back Alley balls: effects from the design notes (tape scraps, rust sparks, chrome glint, crystal shards)
		DuctTape = {
			Particles = {
				{
					Image = "Diamond",
					Colors = { Color3.fromHex("C0C4C9"), Color3.fromHex("E2579B") },
					Rate = 6,
					Size = 0.08,
					Life = { 0.3, 0.6 },
					Speed = { 0.3, 0.8 },
					Radius = 0.45,
				},
			},
		},
		RustBucket = {
			Particles = {
				{
					Image = "Star",
					Colors = { Color3.fromHex("FFB060"), Color3.fromHex("D2692A") },
					Rate = 10,
					Size = 0.07,
					Life = { 0.2, 0.5 },
					Speed = { 0.6, 1.4 },
					Radius = 0.45,
				},
			},
		},
		Hubcap = {
			Trails = {
				{
					Colors = { Color3.fromHex("E9EEF3"), Color3.fromHex("7DF0A6") },
					Width = 0.8,
					Lifetime = 0.25,
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { WHITE, Color3.fromHex("7DF0A6") },
					Rate = 4,
					Size = 0.2,
					Life = { 0.2, 0.35 },
					Speed = { 0, 0.1 },
					Radius = 0.5,
				},
			},
		},
		DumpsterDiamond = {
			Trails = {
				{
					Colors = { Color3.fromHex("9FE6FF"), Color3.fromHex("38C6FF"), Color3.fromHex("1565C0") },
					Width = 1,
					Lifetime = 0.35,
				},
			},
			Particles = {
				{
					Image = "Diamond",
					Colors = { Color3.fromHex("E8FCFF"), Color3.fromHex("3CC8FF") },
					Rate = 25,
					Size = 0.1,
					Life = { 0.4, 0.8 },
					Speed = { 0.2, 0.6 },
					Radius = 0.45,
				},
			},
			Badge = { Image = "Burst", Size = 0.5, Height = 0.95 },
			Light = { Color = Color3.fromHex("3CC8FF"), Brightness = 2, Range = 4 },
		},
		-- Uncommon: a soft streak in the ball's colour
		Electric = {
			Trails = {
				{
					Colors = { Color3.fromRGB(138, 222, 255), Color3.fromRGB(60, 200, 255) },
					Width = 0.8,
					Lifetime = 0.25,
				},
			},
		},
		Toxic = {
			Trails = {
				{
					Colors = { Color3.fromRGB(174, 255, 138), Color3.fromRGB(120, 255, 60) },
					Width = 0.8,
					Lifetime = 0.25,
				},
			},
		},
		Sunset = {
			Trails = {
				{
					Colors = { Color3.fromRGB(255, 240, 80), Color3.fromRGB(255, 80, 200) },
					Width = 0.8,
					Lifetime = 0.25,
				},
			},
		},
		Frostbite = {
			Trails = {
				{
					Colors = { Color3.fromRGB(192, 234, 255), Color3.fromRGB(150, 220, 255) },
					Width = 0.8,
					Lifetime = 0.25,
				},
			},
		},

		-- Rare: blue comet trail with sparkles, plus the trait icon floating above
		Magma = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(150, 204, 255),
						Color3.fromRGB(80, 170, 255),
						Color3.fromRGB(40, 80, 255),
					},
					Width = 1,
					Lifetime = 0.35,
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { WHITE, Color3.fromRGB(255, 150, 50) },
					Rate = 30,
					Size = 0.12,
					Life = { 0.4, 0.8 },
					Speed = { 0.2, 0.6 },
					Radius = 0.45,
				},
			},
			Badge = { Image = "Burst", Size = 0.5, Height = 0.95 },
			Light = { Color = Color3.fromRGB(255, 120, 40), Brightness = 2, Range = 4 },
		},
		Galaxy = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(192, 186, 255),
						Color3.fromRGB(150, 140, 255),
						Color3.fromRGB(60, 70, 255),
					},
					Width = 1,
					Lifetime = 0.35,
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { WHITE, Color3.fromRGB(200, 180, 255) },
					Rate = 30,
					Size = 0.12,
					Life = { 0.4, 0.8 },
					Speed = { 0.2, 0.6 },
					Radius = 0.45,
				},
			},
			Badge = { Image = "Clover", Size = 0.45, Height = 0.95 },
			Light = { Color = Color3.fromRGB(140, 120, 255), Brightness = 2, Range = 4 },
		},
		Thunder = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(126, 228, 255),
						Color3.fromRGB(40, 210, 255),
						Color3.fromRGB(30, 110, 255),
					},
					Width = 1,
					Lifetime = 0.35,
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { WHITE, Color3.fromRGB(255, 230, 60) },
					Rate = 30,
					Size = 0.12,
					Life = { 0.4, 0.8 },
					Speed = { 0.2, 0.6 },
					Radius = 0.45,
				},
			},
			Badge = { Image = "Shield", Size = 0.55, Height = 1 },
			Light = { Color = Color3.fromRGB(60, 200, 255), Brightness = 2, Range = 4 },
		},
		Phantom = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(192, 228, 255),
						Color3.fromRGB(150, 210, 255),
						Color3.fromRGB(70, 130, 255),
					},
					Width = 1,
					Lifetime = 0.35,
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { WHITE, Color3.fromRGB(210, 230, 255) },
					Rate = 30,
					Size = 0.12,
					Life = { 0.4, 0.8 },
					Speed = { 0.2, 0.6 },
					Radius = 0.45,
				},
			},
			Badge = { Image = "Spiral", Size = 0.45, Height = 0.95 },
			Light = { Color = Color3.fromRGB(150, 200, 255), Brightness = 2, Range = 4 },
		},

		-- Epic: a column of glowing dots rising off the ball
		Plasma = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(150, 234, 255),
						Color3.fromRGB(80, 220, 255),
						Color3.fromRGB(140, 60, 255),
					},
					Width = 0.9,
					Lifetime = 0.3,
				},
			},
			Particles = {
				{
					Image = "Dot",
					Colors = { Color3.fromRGB(90, 230, 255), Color3.fromRGB(200, 160, 255), WHITE },
					Rate = 40,
					Size = 0.14,
					Life = { 1, 1.8 },
					Speed = { 0.2, 0.5 },
					Rise = 0.8,
					Radius = 0.4,
					Twinkle = true,
				},
			},
			Halos = { { Image = "Dot", Color = Color3.fromRGB(140, 90, 255), Size = 2.2, Transparency = 0.6 } },
			Light = { Color = Color3.fromRGB(150, 90, 255), Brightness = 3, Range = 5 },
		},
		Nebula = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(255, 156, 228),
						Color3.fromRGB(255, 90, 210),
						Color3.fromRGB(90, 130, 255),
					},
					Width = 0.9,
					Lifetime = 0.3,
				},
			},
			Particles = {
				{
					Image = "Dot",
					Colors = {
						Color3.fromRGB(255, 90, 210),
						Color3.fromRGB(80, 200, 255),
						Color3.fromRGB(120, 110, 255),
					},
					Rate = 40,
					Size = 0.14,
					Life = { 1, 1.8 },
					Speed = { 0.2, 0.5 },
					Rise = 0.8,
					Radius = 0.4,
					Twinkle = true,
				},
				{
					Image = "Star",
					Colors = { Color3.fromRGB(255, 220, 90) },
					Rate = 14,
					Size = 0.14,
					Life = { 0.4, 0.8 },
					Speed = { 0.1, 0.4 },
					Radius = 0.5,
					Twinkle = true,
				},
			},
			Halos = { { Image = "Dot", Color = Color3.fromRGB(220, 80, 255), Size = 2.2, Transparency = 0.6 } },
			Light = { Color = Color3.fromRGB(220, 80, 255), Brightness = 3, Range = 5 },
		},
		Inferno = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(255, 156, 234),
						Color3.fromRGB(255, 90, 220),
						Color3.fromRGB(255, 200, 60),
					},
					Width = 0.9,
					Lifetime = 0.3,
				},
			},
			Particles = {
				{
					Image = "Dot",
					Colors = {
						Color3.fromRGB(255, 80, 220),
						Color3.fromRGB(255, 200, 60),
						Color3.fromRGB(190, 90, 255),
					},
					Rate = 40,
					Size = 0.14,
					Life = { 1, 1.8 },
					Speed = { 0.2, 0.5 },
					Rise = 0.8,
					Radius = 0.4,
					Twinkle = true,
				},
			},
			Halos = { { Image = "Dot", Color = Color3.fromRGB(255, 70, 220), Size = 2.2, Transparency = 0.6 } },
			Light = { Color = Color3.fromRGB(255, 80, 220), Brightness = 3, Range = 5 },
		},

		-- Legendary
		Golden = {
			Trails = {
				{
					Colors = { Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 190, 40) },
					Width = 0.6,
					Lifetime = 0.45,
					Texture = "Bolt",
				},
				{
					Colors = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 150, 30) },
					Width = 1,
					Lifetime = 0.2,
					Transparency = 0.6,
				},
			},
			Particles = {
				{
					Image = "Diamond",
					Colors = { Color3.fromRGB(190, 255, 245), Color3.fromRGB(120, 240, 230) },
					Rate = 6,
					Size = 0.16,
					Life = { 1.2, 2 },
					Speed = { 0.05, 0.2 },
					Radius = 0.85,
					Twinkle = true,
				},
				{
					Image = "Dot",
					Colors = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 170, 60) },
					Rate = 35,
					Size = 0.07,
					Life = { 0.8, 1.6 },
					Speed = { 0.1, 0.4 },
					Rise = 0.3,
					Radius = 0.7,
					Twinkle = true,
				},
			},
			Halos = { { Image = "Dot", Color = Color3.fromRGB(255, 190, 60), Size = 2.4, Transparency = 0.55 } },
			Ground = {
				{ Color = Color3.fromRGB(255, 235, 30), Radius = 0.9, Transparency = 0 },
				{ Color = Color3.fromRGB(255, 170, 40), Radius = 1.15, Transparency = 0.6 },
			},
			Light = { Color = Color3.fromRGB(255, 190, 60), Brightness = 3, Range = 6 },
		},
		Dragon = {
			Trails = {
				{
					Colors = { Color3.fromRGB(255, 230, 150), Color3.fromRGB(255, 140, 40) },
					Width = 0.5,
					Lifetime = 0.4,
					Texture = "Bolt",
				},
				{
					Colors = {
						Color3.fromRGB(255, 220, 120),
						Color3.fromRGB(255, 110, 20),
						Color3.fromRGB(200, 40, 10),
					},
					Width = 1.1,
					Lifetime = 0.3,
					Transparency = 0.2,
				},
			},
			Particles = {
				{
					Image = "Flame",
					Colors = {
						Color3.fromRGB(255, 220, 110),
						Color3.fromRGB(255, 120, 30),
						Color3.fromRGB(200, 40, 20),
					},
					Rate = 60,
					Size = 0.5,
					Life = { 0.35, 0.7 },
					Speed = { 0.3, 0.8 },
					Rise = 3,
					Radius = 0.4,
					Spin = 60,
				},
				{
					Image = "Dot",
					Colors = { Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 120, 30) },
					Rate = 25,
					Size = 0.06,
					Life = { 0.8, 1.6 },
					Speed = { 0.4, 1 },
					Rise = 1.2,
					Radius = 0.5,
					Twinkle = true,
				},
			},
			Ground = {
				{ Color = Color3.fromRGB(255, 130, 20), Radius = 0.85, Transparency = 0 },
				{ Color = Color3.fromRGB(255, 80, 20), Radius = 1.2, Transparency = 0.5 },
			},
			Light = { Color = Color3.fromRGB(255, 120, 30), Brightness = 4, Range = 6 },
		},

		-- Mythic
		Void = {
			Trails = {
				{
					Colors = {
						Color3.fromRGB(255, 120, 240),
						Color3.fromRGB(200, 40, 220),
						Color3.fromRGB(90, 20, 160),
					},
					Width = 1.2,
					Lifetime = 0.45,
				},
				{
					Colors = { Color3.fromRGB(255, 156, 240), Color3.fromRGB(255, 90, 230) },
					Width = 0.35,
					Lifetime = 0.3,
				},
			},
			Particles = {
				{
					Image = "Diamond",
					Colors = { Color3.fromRGB(255, 90, 220), Color3.fromRGB(255, 160, 240) },
					Rate = 14,
					Size = 0.1,
					Life = { 0.8, 1.5 },
					Speed = { 0.2, 0.6 },
					Radius = 0.9,
					Twinkle = true,
					Spin = 90,
				},
			},
			-- the owner's accretion disk, photon ring and shards (the-void-ball.obj)
			Pieces = { Disk = 25, PhotonRing = -40, Shards = 15 },
			Halos = {
				{ Image = "Dot", Color = Color3.fromRGB(190, 40, 255), Size = 2.6, Transparency = 0.45 },
			},
			Light = { Color = Color3.fromRGB(230, 60, 255), Brightness = 4, Range = 7 },
		},
		Supernova = {
			Trails = {
				{
					-- full-strength rainbow from the ball to the tail; no white, and a low Glow so the
					-- colours don't add up to white under bloom
					Colors = {
						Color3.fromRGB(255, 40, 60),
						Color3.fromRGB(255, 140, 0),
						Color3.fromRGB(255, 230, 0),
						Color3.fromRGB(40, 230, 60),
						Color3.fromRGB(0, 180, 255),
						Color3.fromRGB(90, 60, 255),
						Color3.fromRGB(200, 40, 255),
					},
					Width = 1.3,
					Lifetime = 0.5,
					Transparency = 0.15,
					Glow = 0.25,
					-- the body carries the rainbow as bands across its width, so the follow camera (which only
					-- sees the front of the trail) still sees every colour
					BodyTexture = "TrailRainbow",
				},
			},
			Particles = {
				{
					Image = "Star",
					Colors = { Color3.fromRGB(255, 220, 40), Color3.fromRGB(255, 120, 30) },
					Rate = 16,
					Size = 0.2,
					Life = { 0.6, 1.2 },
					Speed = { 0.05, 0.2 },
					Radius = 0.95,
					Twinkle = true,
					Spin = 45,
				},
				{
					Image = "Dot",
					Colors = {
						Color3.fromRGB(255, 60, 120),
						Color3.fromRGB(60, 200, 255),
						Color3.fromRGB(120, 255, 90),
						Color3.fromRGB(190, 80, 255),
					},
					Rate = 40,
					Size = 0.05,
					Life = { 0.5, 1 },
					Speed = { 0.2, 0.6 },
					Radius = 0.5,
					Twinkle = true,
				},
			},
			-- the owner's three rings and mini stars (supernova-ball.obj)
			Pieces = { RingMagenta1 = 60, RingCyan = -45, RingMagenta2 = 35, Stars = 12 },
			-- tinted glow and light: a white glow reflects off the shiny lane as a white streak behind the ball
			Halos = { { Image = "Dot", Color = Color3.fromRGB(150, 70, 255), Size = 2.4, Transparency = 0.6 } },
			Light = { Color = Color3.fromRGB(255, 70, 190), Brightness = 2.5, Range = 6 },
		},
	},
}

-- THE RARITY LADDER (Phase X Part 2), lowest first: zone ranges, crate odds, case accents and pets all read it.
-- SellCoins = coins paid when a crate gives a ball you already own.
-- To add a tier above Mythic: add a row at the end (and a Config.Showcase.Styles accent, a Config.Economy.Polish
-- GemPrice, a Config.Economy.Mascots Odds/Bonus and a Config.RarityPower row); nothing else needs code changes.
Config.Rarities = {
	{ Name = "Common", Color = Color3.fromRGB(200, 200, 210), SellCoins = 100 },
	{ Name = "Uncommon", Color = Color3.fromRGB(90, 230, 110), SellCoins = 250 },
	{ Name = "Rare", Color = Color3.fromRGB(60, 160, 255), SellCoins = 750 },
	{ Name = "Epic", Color = Color3.fromRGB(180, 80, 255), SellCoins = 2500 },
	{ Name = "Legendary", Color = Color3.fromRGB(255, 190, 40), SellCoins = 10000 },
	{ Name = "Mythic", Color = Color3.fromRGB(255, 50, 120), SellCoins = 50000 },
}
-- Reserved names for future tiers above Mythic (Phase X Part 8B). Names only: no content, art or odds yet.
-- Move one into Config.Rarities (with a colour and SellCoins) to switch it on.
Config.ReservedRarities = { "Cosmic", "Celestial", "Eternal" }

-- Power per rarity (Phase X Part 8B), the one table to tune rarity strength:
--   Ball = a typical ball's coin multiplier at that rarity (the zone 2 averages from the audit). Balls keep their own
--          Multiplier (small differences inside a rarity); a new ball row can leave Multiplier out to get this one.
--   Pet  = a pet's coin AND XP bonus before its egg's BonusScale (Config.Economy.Mascots.Bonus fills from this).
-- Step = how much stronger each rarity is than the one below, measured from Common to Mythic (balls x1.82, pets
-- x2.37 per tier); reserved tiers (Config.ReservedRarities) get Mythic x Step, x Step^2 ... automatically.
Config.RarityPower = {
	Step = { Ball = 1.82, Pet = 2.37 },
	Common = { Ball = 1.13, Pet = 0.2 },
	Uncommon = { Ball = 1.45, Pet = 0.5 },
	Rare = { Ball = 2.13, Pet = 1.0 },
	Epic = { Ball = 4.0, Pet = 2.5 },
	Legendary = { Ball = 8.5, Pet = 6 },
	Mythic = { Ball = 22.5, Pet = 15 },
}
do
	-- Reserved tiers above the last real one: the previous tier x Step (Cosmic 41 / 35.6, Celestial 74.6 / 84.4,
	-- Eternal 135.8 / 200)
	local last = Config.RarityPower[Config.Rarities[#Config.Rarities].Name]
	for _, name in Config.ReservedRarities do
		if not Config.RarityPower[name] then
			last = { Ball = last.Ball * Config.RarityPower.Step.Ball, Pet = last.Pet * Config.RarityPower.Step.Pet }
			Config.RarityPower[name] = last
		end
	end
end

-- Which rarities each zone's balls and pets can be (Phase X Part 2). Zone crates and eggs only hold items in their
-- zone's range; crate odds below are built from it (Config.CrateTiers). Zones 5+ are not built (launch = zones 1-4).
Config.ZoneRarity = {
	[1] = { Min = "Common", Max = "Rare" }, -- Back Alley: junk balls, low rarities
	[2] = { Min = "Uncommon", Max = "Epic" }, -- Neon Lanes
	[3] = { Min = "Rare", Max = "Legendary" }, -- Main Street Lanes
	[4] = { Min = "Epic", Max = "Mythic" }, -- Skyline Lanes
}

-- Every ball in the game. Adding a ball = adding a row.
-- Multiplier: coin multiplier while equipped. Forgiveness: widens the gold zone (x Config.Throw.ForgivenessScale, 0.05 = 50%).
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
-- Zone = the zone's own crate (Config.Crates ZoneBallsOnly) gives only that zone's balls (owner 2026-10-21: every
-- crate is zone-only now). Zone 1 (Back Alley) balls have weaker traits than zone 2 (Neon Lanes) balls of the same
-- rarity, about half (owner 2026-10-21): Common Lucky 5% / Heavy 3%, Uncommon Curve 6%, Rare Blast 20%.
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
		Zone = 1, -- moved from Neon Lanes to the Back Alley (Phase X: zone 2 starts at Uncommon), numbers unchanged
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
		Zone = 1, -- moved from Neon Lanes to the Back Alley (Phase X: zone 2 starts at Uncommon), numbers unchanged
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
		Zone = 1, -- moved from Neon Lanes to the Back Alley (Phase X: zone 2 starts at Uncommon), numbers unchanged
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
		Zone = 1, -- moved from Neon Lanes to the Back Alley (Phase X: zone 2 starts at Uncommon), numbers unchanged
		Name = "Deep Ocean",
		Rarity = "Common",
		Multiplier = 1.2,
		Forgiveness = 0.005,
		Color = Color3.fromRGB(30, 90, 200),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(60, 140, 255),
		Traits = { GemHunter = 0.01 },
	}, -- Back Alley balls (owner's "Back Alley Bowling Assets" design, 2026-10-20): junk turned into prizes
	{
		Id = "DuctTape",
		Zone = 1, -- a Back Alley ball: the Alley Crate only gives these
		Name = "Duct Tape",
		Rarity = "Common",
		Multiplier = 1.1,
		Forgiveness = 0,
		Color = Color3.fromHex("C0C4C9"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("C7CCD2"),
		Traits = { Lucky = 0.05 },
	},
	{
		Id = "RustBucket",
		Zone = 1, -- a Back Alley ball: the Alley Crate only gives these
		Name = "Rust Bucket",
		Rarity = "Common",
		Multiplier = 1.15,
		Forgiveness = 0,
		Color = Color3.fromHex("D2692A"),
		Material = Enum.Material.Metal,
		Trail = Color3.fromHex("D2692A"),
		Traits = { Heavy = 0.03 },
	},

	-- Uncommon
	{
		Id = "Electric",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
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
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
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
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
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
		Zone = 2,
		Retired = true, -- Phase X: cut from Neon Lanes to bring it to 9 balls. Out of every crate; owners keep it
		Name = "Frostbite",
		Rarity = "Uncommon",
		Multiplier = 1.6,
		Forgiveness = 0.015,
		Color = Color3.fromRGB(180, 240, 255),
		Material = Enum.Material.Ice,
		Trail = Color3.fromRGB(200, 250, 255),
		Traits = { Heavy = 0.15 },
	},
	{
		Id = "Hubcap",
		Zone = 1, -- a Back Alley ball: the Alley Crate only gives these
		Name = "Hubcap",
		Rarity = "Uncommon",
		Multiplier = 1.4,
		Forgiveness = 0.01,
		Color = Color3.fromHex("E9EEF3"),
		Material = Enum.Material.Metal,
		Trail = Color3.fromHex("7DF0A6"),
		Traits = { Curve = 0.06 },
	},

	-- Rare
	{
		Id = "Magma",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
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
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
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
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
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
		Zone = 2,
		Retired = true, -- Phase X: cut from Neon Lanes to bring it to 9 balls. Out of every crate; owners keep it
		Name = "Phantom",
		Rarity = "Rare",
		Multiplier = 2.5,
		Forgiveness = 0.025,
		Color = Color3.fromRGB(220, 220, 255),
		Material = Enum.Material.ForceField,
		Trail = Color3.fromRGB(180, 180, 255),
		Traits = { Curve = 0.25 },
	},
	{
		Id = "DumpsterDiamond",
		Zone = 1, -- a Back Alley ball: the Alley Crate only gives these
		Name = "Dumpster Diamond",
		Rarity = "Rare",
		Multiplier = 2.0,
		Forgiveness = 0.02,
		Color = Color3.fromHex("3CC8FF"),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromHex("38C6FF"),
		Traits = { Blast = 0.2 },
	},

	-- Epic
	{
		Id = "Plasma",
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
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
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
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
		Zone = 2, -- a Neon Lanes ball: the zone 2 crates only give these
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
		Zone = 2,
		Retired = true, -- Phase X: too rare for Neon Lanes; zone 4's Sunburst reuses its model. Out of every crate; owners keep it
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
		Zone = 2,
		Retired = true, -- Phase X: too rare for Neon Lanes; zone 4's Solid Gold reuses its model. Out of every crate; owners keep it
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
		Zone = 2,
		Retired = true, -- Phase X: too rare for Neon Lanes; zone 4's Lightning reuses its model. Out of every crate; owners keep it
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
		Zone = 2,
		Retired = true, -- Phase X: too rare for Neon Lanes; zone 4's Daybreak reuses its model. Out of every crate; owners keep it
		Name = "Supernova",
		Rarity = "Mythic",
		Multiplier = 25.0,
		Forgiveness = 0.05,
		Color = Color3.fromRGB(255, 255, 255),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 220, 120),
		Traits = { Blast = 1, Heavy = 0.8 },
	},
	-- Main Street Lanes (zone 3, Phase X): classic league balls (marble, swirl, league). Placeholders: they reuse other
	-- balls' models painted one plain colour until real art exists. Numbers follow the Neon Lanes ladder.
	{
		Id = "LeagueBlack",
		Zone = 3,
		Name = "League Black",
		Rarity = "Rare",
		Multiplier = 2.0,
		Forgiveness = 0.02,
		Color = Color3.fromRGB(35, 35, 42),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(35, 35, 42),
		Traits = { Curve = 0.25 },
		Model = "Rookie", -- PLACEHOLDER look: reuses Rookie's model, plain paint
		Tint = Color3.fromRGB(35, 35, 42),
		PlainModel = true, -- one plain colour and material, no glow
	},
	{
		Id = "CherrySwirl",
		Zone = 3,
		Name = "Cherry Swirl",
		Rarity = "Rare",
		Multiplier = 2.2,
		Forgiveness = 0.02,
		Color = Color3.fromRGB(190, 30, 55),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(190, 30, 55),
		Traits = { Lucky = 0.75 },
		Model = "Bubblegum", -- PLACEHOLDER look: reuses Bubblegum's model, plain paint
		Tint = Color3.fromRGB(190, 30, 55),
		PlainModel = true, -- one plain colour and material, no glow
	},
	{
		Id = "BlueMarble",
		Zone = 3,
		Name = "Blue Marble",
		Rarity = "Rare",
		Multiplier = 2.4,
		Forgiveness = 0.025,
		Color = Color3.fromRGB(40, 95, 205),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(40, 95, 205),
		Traits = { Blast = 0.35 },
		Model = "Ocean", -- PLACEHOLDER look: reuses Ocean's model, plain paint
		Tint = Color3.fromRGB(40, 95, 205),
		PlainModel = true, -- one plain colour and material, no glow
	},
	{
		Id = "PearlPro",
		Zone = 3,
		Name = "Pearl Pro",
		Rarity = "Epic",
		Multiplier = 3.5,
		Forgiveness = 0.03,
		Color = Color3.fromRGB(235, 228, 215),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(235, 228, 215),
		Traits = { Curve = 0.35, GemHunter = 0.06 },
		Model = "Frostbite", -- PLACEHOLDER look: reuses Frostbite's model, plain paint
		Tint = Color3.fromRGB(235, 228, 215),
		PlainModel = true, -- one plain colour and material, no glow
	},
	{
		Id = "TigerSwirl",
		Zone = 3,
		Name = "Tiger Swirl",
		Rarity = "Epic",
		Multiplier = 4.5,
		Forgiveness = 0.035,
		Color = Color3.fromRGB(230, 120, 30),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(230, 120, 30),
		Traits = { Blast = 0.5, Lucky = 1.25 },
		Model = "Tangerine", -- PLACEHOLDER look: reuses Tangerine's model, plain paint
		Tint = Color3.fromRGB(230, 120, 30),
		PlainModel = true, -- one plain colour and material, no glow
	},
	{
		Id = "Championship",
		Zone = 3,
		Name = "Championship",
		Rarity = "Legendary",
		Multiplier = 8.0,
		Forgiveness = 0.04,
		Color = Color3.fromRGB(200, 160, 60),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(200, 160, 60),
		Traits = { Lucky = 2, GemHunter = 0.15 },
		Model = "Golden", -- PLACEHOLDER look: reuses Golden's model, plain paint
		Tint = Color3.fromRGB(200, 160, 60),
		PlainModel = true, -- one plain colour and material, no glow
	},
	{
		Id = "Perfect300",
		Zone = 3,
		Name = "Perfect 300",
		Rarity = "Legendary",
		Multiplier = 9.0,
		Forgiveness = 0.045,
		Color = Color3.fromRGB(150, 20, 35),
		Material = Enum.Material.SmoothPlastic,
		Trail = Color3.fromRGB(150, 20, 35),
		Traits = { Blast = 0.75, StreakSaver = 45 },
		Model = "Dragon", -- PLACEHOLDER look: reuses Dragon's model, plain paint
		Tint = Color3.fromRGB(150, 20, 35),
		PlainModel = true, -- one plain colour and material, no glow
	},
	-- Skyline Lanes (zone 4, Phase X): the moved top Neon balls as new zone 4 entries (same numbers as the ball whose
	-- model they reuse), plus two Epics from the Neon Epic models. Placeholder colour + effect until Claude Design re-skins.
	{
		Id = "CloudSwirl",
		Zone = 4,
		Name = "Cloud Swirl",
		Rarity = "Epic",
		Multiplier = 4.0,
		Forgiveness = 0.035,
		Color = Color3.fromRGB(225, 240, 255),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(225, 240, 255),
		Traits = { Lucky = 1.25, GemHunter = 0.08 },
		Model = "Nebula", -- PLACEHOLDER look: reuses Nebula's model and effect, recoloured
		Tint = Color3.fromRGB(225, 240, 255),
	},
	{
		Id = "Crystal",
		Zone = 4,
		Name = "Crystal",
		Rarity = "Epic",
		Multiplier = 3.0,
		Forgiveness = 0.03,
		Color = Color3.fromRGB(120, 230, 255),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(120, 230, 255),
		Traits = { Heavy = 0.4, GemHunter = 0.06 },
		Model = "Plasma", -- PLACEHOLDER look: reuses Plasma's model and effect, recoloured
		Tint = Color3.fromRGB(120, 230, 255),
	},
	{
		Id = "Sunburst",
		Zone = 4,
		Name = "Sunburst",
		Rarity = "Legendary",
		Multiplier = 7.0,
		Forgiveness = 0.04,
		Color = Color3.fromRGB(255, 170, 40),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 170, 40),
		Traits = { Lucky = 2, GemHunter = 0.15 },
		Model = "Golden", -- PLACEHOLDER look: reuses Golden's model and effect, recoloured
		Tint = Color3.fromRGB(255, 170, 40),
	},
	{
		Id = "SolidGold",
		Zone = 4,
		Name = "Solid Gold",
		Rarity = "Legendary",
		Multiplier = 10.0,
		Forgiveness = 0.045,
		Color = Color3.fromRGB(255, 205, 60),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 205, 60),
		Traits = { Blast = 0.75, StreakSaver = 45 },
		Model = "Dragon", -- PLACEHOLDER look: reuses Dragon's model and effect, recoloured
		Tint = Color3.fromRGB(255, 205, 60),
	},
	{
		Id = "Lightning",
		Zone = 4,
		Name = "Lightning",
		Rarity = "Mythic",
		Multiplier = 20.0,
		Forgiveness = 0.05,
		Color = Color3.fromRGB(255, 245, 90),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 245, 90),
		Traits = { Curve = 0.6, StreakSaver = 30 },
		Model = "Void", -- PLACEHOLDER look: reuses Void's model and effect, recoloured
		Tint = Color3.fromRGB(255, 245, 90),
	},
	{
		Id = "Daybreak",
		Zone = 4,
		Name = "Daybreak",
		Rarity = "Mythic",
		Multiplier = 25.0,
		Forgiveness = 0.05,
		Color = Color3.fromRGB(255, 150, 120),
		Material = Enum.Material.Neon,
		Trail = Color3.fromRGB(255, 150, 120),
		Traits = { Blast = 1, Heavy = 0.8 },
		Model = "Supernova", -- PLACEHOLDER look: reuses Supernova's model and effect, recoloured
		Tint = Color3.fromRGB(255, 150, 120),
	},
}

-- Crates, bought with coins: name and colour here, cheapest first. Price and Odds come from Config.Economy.Crates
-- (filled in below it), pity from Config.Economy.CratePity, duplicates from Config.Economy.Polish.
-- Looks: ReplicatedStorage.CrateModels has one model per Id (Bronze, Silver and Gold are recoloured copies for now).
-- Zone = the zone that must be unlocked to open it (locked crates show blacked out: "UNLOCKS IN <zone>").
-- ZoneBallsOnly = gives only balls with that Zone (Config.Balls). Owner 2026-10-21: zone 1 = the Alley Crate with
-- the Back Alley balls only; the zone 2 crates (Bronze, Silver, Gold) give only the Neon Lanes balls.
Config.Crates = {
	{ Id = "Basic", Name = "Alley Crate", Color = Color3.fromRGB(60, 200, 255), Zone = 1, ZoneBallsOnly = true },
	{
		Id = "Bronze",
		Name = "Bronze Crate",
		Color = Color3.fromRGB(215, 135, 70),
		Zone = 2,
		ZoneBallsOnly = true,
		Tier = "Bronze",
	},
	{
		Id = "Silver",
		Name = "Silver Crate",
		Color = Color3.fromRGB(200, 215, 235),
		Zone = 2,
		ZoneBallsOnly = true,
		Tier = "Silver",
	},
	{
		Id = "Gold",
		Name = "Gold Crate",
		Color = Color3.fromRGB(255, 200, 40),
		Zone = 2,
		ZoneBallsOnly = true,
		Tier = "Gold",
	},
	-- Phase X: zone 3 has 2 crates, zone 4 has 3. Model = the CrateModels look they borrow until real art exists.
	{
		Id = "League",
		Name = "League Crate",
		Color = Color3.fromRGB(176, 112, 60),
		Zone = 3,
		ZoneBallsOnly = true,
		Tier = "Bronze",
		Model = "Bronze",
	},
	{
		Id = "Champion",
		Name = "Champion Crate",
		Color = Color3.fromRGB(224, 165, 38),
		Zone = 3,
		ZoneBallsOnly = true,
		Tier = "Gold",
		Model = "Gold",
	},
	{
		Id = "SkyBronze",
		Name = "Sky Bronze Crate",
		Color = Color3.fromRGB(240, 160, 110),
		Zone = 4,
		ZoneBallsOnly = true,
		Tier = "Bronze",
		Model = "Bronze",
	},
	{
		Id = "SkySilver",
		Name = "Sky Silver Crate",
		Color = Color3.fromRGB(190, 220, 255),
		Zone = 4,
		ZoneBallsOnly = true,
		Tier = "Silver",
		Model = "Silver",
	},
	{
		Id = "SkyGold",
		Name = "Sky Gold Crate",
		Color = Color3.fromRGB(255, 79, 139),
		Zone = 4,
		ZoneBallsOnly = true,
		Tier = "Gold",
		Model = "Gold",
	},
	-- The Neon Crate (5.9B) is out of the game for now (owner 2026-10-21): it gets a new name and a later zone once
	-- the new economy is in. Its Config.Economy.Crates row stays for the simulator; old saves keep its pity.
}

-- Pet fusion station in zone 3 (Phase X Part 6). PLACEHOLDER: no fusion design exists yet, so the station is the
-- walk-up home of the existing Shiny merge (3 copies of a pet = its Shiny). Its prompt opens the PETS panel, where
-- MERGE works as before. Swap in the real fusion rules here when they are decided.
Config.Fusion = {
	Enabled = true,
	Zone = 3,
	Path = { "MainStreetLanes", "FusionStation" }, -- placeholder booth built in Studio
}

-- Zone 4 boss loop (Phase X Part 6). The helicopter on the Skyline roof flies you to the boss arena once every
-- CooldownMinutes (per player, saved as BossNextAt). PLACEHOLDER fight: the boss logic is not designed yet
-- (server/Modules/BossStub: stay in the arena FightSeconds = win). Replace BossStub to change the fight; the
-- helicopter, cooldown, arena trip and reward stay. Reward = like Config.Milestones rewards.
Config.Boss = {
	Enabled = true,
	Zone = 4,
	CooldownMinutes = 45,
	Helipad = { "SkylineLanes", "Helipad" }, -- the pad (with its placeholder helicopter) on the roof
	Arena = { "BossArena" }, -- the stub arena, far above the city (Workspace.BossArena: Floor, Spawn, Boss)
	UseRange = 18, -- studs from the helipad the server accepts a ride from
	FightSeconds = 20, -- PLACEHOLDER fight length
	ReturnDelay = 3, -- seconds after the fight before the helicopter brings you back
	Reward = { Coins = 1000000000, LevelShare = 0.25, Crate = "SkyBronze" }, -- PLACEHOLDER reward
	RewardText = "BOSS REWARD",
}

-- Crate counters in zones 3 and 4 (Phase X; placeholder booths built in Studio): walk up and the prompt opens the crate
-- shop screen, which lists every crate (each zone's crates unlock with the zone). Path = the booth under Workspace.
Config.ZoneShops = {
	{ Path = { "MainStreetLanes", "CrateShop" }, Zone = 3 },
	{ Path = { "SkylineLanes", "CrateShop" }, Zone = 4 },
}

-- Rizzo, the Back Alley crate dealer (owner's "Rizzo's Crate Cart" design), at Workspace.BackAlley.RizzoStand.
-- His cart's pink BuyPad sells the zone's crate; his lines come from the design.
Config.Rizzo = {
	CrateId = "Basic", -- the Alley Crate
	GreetDistance = 16, -- studs from the buy pad: Rizzo says hi
	ByeDistance = 24, -- walk this far away again: goodbye
	BubbleTime = 3.5, -- seconds a line stays up
	TypeSpeed = 45, -- letters per second
	TurntableSpin = 0.15, -- turns per second
	AnimateDistance = 90, -- only animate while your camera is this close
	Bob = 0.06, -- studs he bobs while idle
	WaveTime = 1.4, -- seconds a wave lasts
	RareFrom = "Rare", -- pulls of this rarity or better get the "something rare" line
	Lines = {
		Greeting = "Psst, kid, over here! Rizzo's got crates full of surprises.",
		Opening = "Luck's a lane, kid. Let's see where yours rolls!",
		Rare = "Whoa, a rare one! Shh, don't tell anyone where you got it.",
		CantAfford = "Aw, not enough coins yet? Knock down some pins and come right back!",
		Goodbye = "See ya, kid! Keep it out of the gutter.",
		CallOver = "Psst! You got the coins now, kid. Your first crate's on discount, come get it!", -- your first crate is affordable
	},
	FirstCrateMarker = true, -- a bouncing "!" over Rizzo (seen through walls) while your first crate waits for you
}

-- The crate shop kiosk in the lobby (Workspace.Hub.CrateShop, built in Studio). Crate looks live in
-- ReplicatedStorage.CrateModels, one model per crate Id.
Config.CrateShop = {
	PromptDistance = 10, -- studs from the buy button where "Open" shows up
	HoldDuration = 0.4, -- seconds to hold the buy button, so nobody spends coins by accident
	CrateSpin = 0.12, -- turns per second for the crates on display
	CrateBob = 0.25, -- studs the display crates float up and down
	SparkleOrbit = 0.08, -- turns per second the gold sparkles drift around the crate
	SparkleRadius = 1.7, -- studs from the crate centre (more would poke into the kiosk's back wall)
	SparkleDrift = 0.2, -- studs the sparkles drift in and out
	SparkleFloat = 0.35, -- studs the sparkles float up and down
	OpenSign = { -- the flickering "OPEN" neon on top of the kiosk
		Color = Color3.fromRGB(255, 70, 150), -- tube colour when lit
		OnText = Color3.fromRGB(255, 225, 235),
		OffText = Color3.fromRGB(70, 60, 72), -- dead tube: grey glass
		OffGlow = Color3.fromRGB(80, 30, 55),
		LightRange = 9,
		LightBrightness = 1.2,
		CalmMin = 1.5, -- seconds it stays steady between flickers
		CalmMax = 5,
		DropoutChance = 0.35, -- chance a flicker ends with the sign going dark for a moment
	},
	AnimateDistance = 90, -- only animate while your camera is this close (saves phone battery)
	Intro = { -- the crate on screen before the reel: slams down, hops to the beat, lid blasts off (about 2 s)
		CrateSize = 4.3, -- studs wide on screen (every crate model is fitted to this)
		FaceAngle = -25, -- degrees the crate is turned from facing you straight on
		CameraDistance = 13,
		Kick = 0.12, -- camera punches in by this share on every landing
		DropTime = 0.35, -- seconds to slam down from above
		DropHeight = 7, -- studs it falls
		DropSpin = 1, -- turns while falling
		Hops = 3,
		HopTime = 0.3, -- seconds per hop
		HopHeight = 0.6, -- studs of the first hop
		HopGrow = 0.45, -- each next hop this much higher
		HopTurn = 90, -- degrees turned per hop
		HopWiggle = 10, -- degrees of side wiggle in the air
		LidPeek = 9, -- degrees the lid rests more open after each hop
		BlastTime = 0.6, -- seconds of crouch + lid blast
		CrouchShare = 0.3, -- share of BlastTime spent crouching and rattling
		LidFly = 9, -- studs the lid rockets up
		LidSpin = 1.5, -- turns the lid tumbles while flying off
		BeamHeight = 14, -- studs of the light beam out of the crate
		Rays = 8, -- light spokes behind the crate (each = 2 rays)
		RayWidth = 0.06, -- spoke width (share of the stage)
		RaySpin = 0.1, -- turns per second when calm
		RaySpinHot = 0.6, -- extra turns per second when it's about to blow
		Confetti = 35, -- pieces at the blast
	},
	SpinTime = 4.5, -- seconds the crate reel spins before it stops on the result
	ScreenBrightness = 1.15, -- glow of the kiosk screens (marquee, odds, prices); higher = more vibrant
	-- The owner's Crate Kiosk design (2026-10-21): Bronze, Silver, Gold stations
	PriceShineEvery = 3, -- seconds between shine sweeps across a price plate
	RingSpin = 0.15, -- turns per second of Silver's light ring
	ButtonPulse = 1.6, -- BUY button glow pulses per second
	Hover = { -- while you stand close enough to buy
		Lift = 0.5, -- studs the crate rises
		Tilt = 14, -- degrees the crate leans toward you
		ButtonSwell = 1.12, -- BUY button grows to this size
		LightBoost = 1.8, -- station lights get this much brighter
		Speed = 8, -- how fast it eases in and out
	},
	Purchase = { -- plays on the kiosk when you buy, before the crate screen opens
		ShakeTime = 0.45, -- seconds the crate shakes before the lid flashes
		ShakeAngle = 9, -- degrees
		FlashTime = 0.15, -- seconds the lid stays white
		Rays = 10, -- light rays out of the crate
		Coins = 18, -- coins sprayed out
		CoinSpeed = 16, -- studs per second
		CoinLife = 2.2, -- seconds before the coins fade
		RingGrow = 5, -- studs the light ring grows to
		BurstTime = 0.7, -- seconds the rays and ring take to fade
	},
}

-- Mascots (pets, Addendum 2 Phase 3 step 8): small buddies that follow you and add to your coins.
-- Hatched from eggs (Config.Economy.Eggs: price, unlock, BonusScale). A mascot's bonus =
-- Config.Economy.Mascots.Bonus[its rarity] x its egg's BonusScale; equipped bonuses add up: coins x (1 + total).
-- Placeholder looks (Addendum 2 section 9.7): a coloured ball with eyes. Color = body, Accent = tuft and cheeks.
-- Egg = which egg hatches it. Only the Neon Egg (Id "Alley", sold in zone 2) has mascots so far; the others come with zones 2 to 5.
-- Adding a mascot = adding a row. Each egg needs at least one mascot per rarity in Config.Economy.Mascots.Odds.
Config.Mascots = {
	{
		Id = "Pinny",
		Name = "Pinny",
		Egg = "Alley",
		Rarity = "Uncommon", -- Phase X: was Common (zone 2 starts at Uncommon); BaseBonus keeps its old +2%
		BaseBonus = 0.2,
		Color = Color3.fromRGB(245, 245, 250),
		Accent = Color3.fromRGB(230, 50, 60),
		Reaction = "Hop",
	},
	{
		Id = "Gus",
		Name = "Gutter Gus",
		Egg = nil, -- Phase X holding list: cut from the Neon Egg (6 pets now); owners keep it. Was Egg = "Alley"
		BonusEgg = "Alley", -- its bonus stays the Neon Egg's (owners' pets don't change)
		Rarity = "Common",
		Color = Color3.fromRGB(140, 140, 155),
		Accent = Color3.fromRGB(90, 200, 255),
		Reaction = "Wiggle",
	},
	{
		Id = "LanePup",
		Name = "Lane Pup",
		Egg = "Alley",
		Rarity = "Uncommon",
		Color = Color3.fromRGB(110, 220, 120),
		Accent = Color3.fromRGB(255, 240, 120),
		Reaction = "Hop",
	},
	{
		Id = "Bumper",
		Name = "Bumper",
		Egg = nil, -- Phase X holding list: cut from the Neon Egg (6 pets now); owners keep it. Was Egg = "Alley"
		BonusEgg = "Alley", -- its bonus stays the Neon Egg's (owners' pets don't change)
		Rarity = "Uncommon",
		Color = Color3.fromRGB(190, 255, 70),
		Accent = Color3.fromRGB(255, 90, 200),
		Reaction = "Spin",
	},
	{
		Id = "Strikey",
		Name = "Strikey",
		Egg = "Alley",
		Rarity = "Rare",
		Color = Color3.fromRGB(60, 140, 255),
		Accent = Color3.fromRGB(255, 255, 255),
		Reaction = "Flip",
	},
	{
		Id = "Splitz",
		Name = "Splitz",
		Egg = "Alley",
		Rarity = "Rare",
		Color = Color3.fromRGB(60, 230, 230),
		Accent = Color3.fromRGB(255, 120, 40),
		Reaction = "Wiggle",
	},
	{
		Id = "Hambone",
		Name = "Hambone",
		Egg = "Alley",
		Rarity = "Epic",
		Color = Color3.fromRGB(170, 70, 255),
		Accent = Color3.fromRGB(255, 200, 40),
		Reaction = "Hop",
	},
	{
		Id = "NeonBat",
		Name = "Neon Bat",
		Egg = "Alley",
		Rarity = "Epic",
		Color = Color3.fromRGB(110, 40, 200),
		Accent = Color3.fromRGB(60, 255, 220),
		Reaction = "Flip",
	},
	{
		Id = "Kingpin",
		Name = "Kingpin",
		Egg = "Arcade", -- Phase X: moved from the Neon Egg to zone 3's Main Street Egg
		Rarity = "Legendary",
		Color = Color3.fromRGB(255, 195, 40),
		Accent = Color3.fromRGB(255, 255, 255),
		Reaction = "Spin",
	},
	{
		Id = "Blaze",
		Name = "Blaze",
		Egg = "Arcade", -- Phase X: moved from the Neon Egg to zone 3's Main Street Egg
		Rarity = "Legendary",
		Color = Color3.fromRGB(255, 110, 30),
		Accent = Color3.fromRGB(255, 230, 60),
		Reaction = "Flip",
	},
	{
		Id = "Cosmo",
		Name = "Cosmo",
		Egg = "Skyline", -- Phase X: moved from the Neon Egg to zone 4's Skyline Egg
		Rarity = "Mythic",
		Color = Color3.fromRGB(255, 60, 150),
		Accent = Color3.fromRGB(120, 220, 255),
		Reaction = "Spin",
	},
	{
		Id = "Perfecto",
		Name = "Perfecto",
		Egg = "Skyline", -- Phase X: moved from the Neon Egg to zone 4's Skyline Egg
		Rarity = "Mythic",
		Color = Color3.fromRGB(255, 245, 200),
		Accent = Color3.fromRGB(255, 60, 210),
		Reaction = "Flip",
	},
	-- Phase X placeholders: zone 3 (Main Street Egg) and zone 4 (Skyline Egg) pets that borrow a model
	{
		Id = "WoodPup",
		Name = "Wood Pup",
		Egg = "Arcade",
		Rarity = "Rare",
		Color = Color3.fromRGB(170, 112, 64),
		Accent = Color3.fromRGB(255, 230, 190),
		Reaction = "Hop",
		Model = "LanePup", -- PLACEHOLDER look: LanePup's model repainted (Tint) until real art exists
		Tint = Color3.fromRGB(170, 112, 64),
	},
	{
		Id = "ChromeBat",
		Name = "Chrome Bat",
		Egg = "Arcade",
		Rarity = "Epic",
		Color = Color3.fromRGB(200, 206, 218),
		Accent = Color3.fromRGB(224, 165, 38),
		Reaction = "Flip",
		Model = "NeonBat", -- PLACEHOLDER look: NeonBat's model repainted (Tint) until real art exists
		Tint = Color3.fromRGB(200, 206, 218),
	},
	{
		Id = "CloudBumper",
		Name = "Cloud Bumper",
		Egg = "Skyline",
		Rarity = "Epic",
		Color = Color3.fromRGB(225, 238, 255),
		Accent = Color3.fromRGB(120, 190, 255),
		Reaction = "Spin",
		Model = "Bumper", -- PLACEHOLDER look: Bumper's model repainted (Tint) until real art exists
		Tint = Color3.fromRGB(225, 238, 255),
	},
	{
		Id = "SunnyHam",
		Name = "Sunny",
		Egg = "Skyline",
		Rarity = "Legendary",
		Color = Color3.fromRGB(255, 180, 60),
		Accent = Color3.fromRGB(255, 79, 139),
		Reaction = "Hop",
		Model = "Hambone", -- PLACEHOLDER look: Hambone's model repainted (Tint) until real art exists
		Tint = Color3.fromRGB(255, 180, 60),
	},
}

-- Auto Bowl (master plan step 14.8, the plan's AUTO_BOWL_ENABLED): the game throws for you, slower than manual and
-- never a PERFECT (so no strikes past your Power Level's pin cap, no x2). Reserved for the monetization phase
-- (Addendum 2 section 7: an Auto Bowl gamepass). OFF: nothing is shown and the server ignores it. When on, an AUTO
-- button appears on the HUD for everyone (the gamepass check comes with monetization).
Config.AutoBowl = {
	Enabled = false,
	Interval = 4.5, -- seconds between auto throws (a manual throw takes about 3)
	ChargeMin = 0.4, -- each auto throw's power is picked between these (0 to 1 of the bar, never the red)
	ChargeMax = 0.85,
}

-- Egg names and colours (prices, unlocks and odds: Config.Economy.Eggs / Config.Economy.Mascots)
Config.EggLooks = {
	Alley = { Name = "Neon Egg", Color = Color3.fromRGB(255, 58, 208), Spots = Color3.fromRGB(63, 240, 255) }, -- design: #ff3ad0 / #3ff0ff
	Neon = { Name = "Neon Egg", Color = Color3.fromRGB(80, 230, 255), Spots = Color3.fromRGB(255, 60, 210) },
	Arcade = { Name = "Main Street Egg", Color = Color3.fromRGB(224, 165, 38), Spots = Color3.fromRGB(150, 30, 40) }, -- Phase X: zone 3's egg (Id kept)
	Skyline = { Name = "Skyline Egg", Color = Color3.fromRGB(255, 79, 139), Spots = Color3.fromRGB(245, 184, 46) }, -- zone 4's egg
	Volcano = { Name = "Volcano Egg", Color = Color3.fromRGB(255, 100, 40), Spots = Color3.fromRGB(60, 20, 20) },
}

-- Where each egg is hatched (Phase X: one stand per zone). Path = the stand's folder under Workspace; it holds a
-- NeonStand model with an EggSpot part (the lobby's stand is the owner's design; zone 3 and 4 stands are copies of
-- it, repainted, until their own designs exist). You hatch an egg only within Config.MascotFx.HatchRange of its stand.
Config.EggStands = {
	{ Egg = "Alley", Path = { "Hub", "EggPad" } },
	{ Egg = "Arcade", Path = { "MainStreetLanes", "EggPad" } },
	{ Egg = "Skyline", Path = { "SkylineLanes", "EggPad" } },
}

-- How mascots look and move, and the hatching moment
Config.MascotFx = {
	Size = 1.6, -- studs across
	-- Pets out in the world (following you, on the shelf, hatching) glow less (owner 2026-10-25: too bright):
	-- their Neon parts' colour times NeonDim (Neon glows as bright as its colour), their lights times LightDim
	NeonDim = 0.7,
	LightDim = 0.5,
	FollowDistance = 4.5, -- studs behind the player (the first row; more mascots fan out to the sides)
	Spacing = 2.6, -- studs between mascots side by side
	FollowSpeed = 8, -- how fast they catch up (higher = snappier)
	Hover = 2.2, -- studs above the ground
	BobHeight = 0.35, -- studs they bob up and down
	BobSpeed = 2.4, -- bobs per second (each mascot is a little out of step)
	ShowDistance = 120, -- mascots of players further away than this aren't drawn (saves phone battery)
	-- The egg stand in the lobby (Workspace.Hub.EggPad, the old daily-reward pad)
	PromptDistance = 10,
	HoldDuration = 0.4, -- seconds to hold "Hatch", so nobody spends coins by accident
	HatchRange = 18, -- eggs only hatch at the stand: the server refuses players further than this (studs, flat)
	-- Hatching away from the stand (fallback when the stand model is missing): the egg shakes harder and harder
	-- while its glow flicks through rarity colours, then cracks
	ShakeTime = 2.4,
	RevealTime = 2.6, -- seconds the new mascot stays on screen before the panel can be closed
	TeaseChance = 0.35, -- chance the glow flashes a rarer colour near the end before settling (odds are shown honestly)
	MergeTime = 1.6, -- seconds the copies shake together before the Shiny pops out (step 8b)
	-- The hatch on the real Neon stand (owner's Hatch Storyboard, about 3s; Client Modules/HatchScene).
	-- Frames: Idle 0.30 · Activation 0.40 · Shake 0.75 · Crack 0.40 (incl. the hold) · Burst 0.35 · Reveal 0.80
	Hatch = {
		CameraFov = 50,
		CameraFill = 0.62, -- egg + stand fill this much of the screen's height (sign kept on screen)
		CameraHeight = 1.2, -- studs the camera sits above the stand's middle
		CameraIn = 0.35, -- seconds the camera takes to swing in
		Idle = 0.3,
		Activation = 0.4,
		Wobbles = { -- each hit: tilt (degrees), seconds, core brightness
			{ Angle = 10, Time = 0.28, Core = 1.2 },
			{ Angle = 12, Time = 0.25, Core = 1.5 },
			{ Angle = 15, Time = 0.22, Core = 2 },
		},
		CrackTime = 0.4, -- cracks + overload + arch flash, the last Hold seconds stand still
		Hold = 0.1,
		BeamLength = 3.5, -- studs the light beams out of each crack
		PillarHeight = 40,
		BurstTime = 0.35,
		ShardDistance = 6, -- studs the shell shards fly
		RingTime = 0.45,
		RingWidth = 1.6, -- the energy ring spreads to 1.6x the platform's width
		RevealTime = 0.8,
		PetSize = 0.85, -- the pet's size compared to the egg
		PetLift = 0.6, -- studs above the egg's middle where the pet settles
		PetRise = 0.4, -- studs it rises out of the light
		PetSettle = 0.45, -- seconds to settle (with a little overshoot)
		CardAt = 0.3, -- seconds into the reveal the name card pops in
		SkipFrom = 0.7, -- tap to skip from this many seconds in
		AutoSkipAfter = 5, -- after this many hatches in one session, it skips straight to the reveal
		-- Burst grows with rarity, colours stay cyan/magenta. Extra = added seconds (pillar beat), Hold = stand-still
		TierOf = { Epic = "Epic", Legendary = "Legendary", Mythic = "Mythic" }, -- everything else = Base
		Tiers = {
			Base = { Shards = 10, Sparks = 24, Rings = 1, Flash = 1, Sparkles = 16, SparksPerHit = 4 },
			Epic = {
				Shards = 14,
				Sparks = 36,
				Rings = 2,
				Flash = 1.25,
				Sparkles = 24,
				SparksPerHit = 6,
				DoubleFlash = true,
			},
			Legendary = {
				Shards = 18,
				Sparks = 50,
				Rings = 2,
				Flash = 1.5,
				Sparkles = 36,
				SparksPerHit = 9,
				CrackSteps = 3,
				Pillar = true,
				CamShake = 0.1,
				Extra = 0.15,
			},
			Mythic = {
				Shards = 24,
				Sparks = 72,
				Rings = 3,
				Flash = 1.8,
				Sparkles = 48,
				SparksPerHit = 12,
				CrackSteps = 3,
				Pillar = true,
				CamShake = 0.1,
				EdgePulse = true,
				Extra = 0.3,
				Hold = 0.25,
			},
		},
	},
	-- Strike reactions (step 8b): when their owner strikes, each mascot does its Reaction (Config.Mascots row):
	-- Hop (jump), Spin (twirl), Flip (somersault) or Wiggle (shake side to side). Shiny ones also burst gold sparkles.
	ReactDelay = 0.25, -- seconds after the pins are hit
	ReactTime = 0.7, -- seconds a reaction lasts
	ReactHeight = 2.2, -- studs a reaction lifts the mascot at its top
	ReactStagger = 0.08, -- seconds between each mascot starting, so they go one after another
	ReactRepeats = 2, -- how many times each mascot does its reaction per strike
	-- On a strike the thrower's camera rides down the lane, so mascots dash down to cheer where it's looking:
	CheerBeforePins = 15, -- studs in front of the head pin (more mascots line up further back)
	CheerSide = 4.5, -- studs either side of the lane's middle (just inside the gutters)
	CheerHeight = 3, -- studs above the lane
	CheerLead = 0.5, -- they set off this many seconds before the ball reaches the pins
	-- The mascot shelf in the lobby Vault (step 8b): every mascot on a glowing stand, yours lit, missing ones dark.
	-- It sits along Workspace.Showcase.MascotShelf (a part you can move in Studio; the mascots face its front).
	ShelfSize = 2.2, -- studs across each mascot on the shelf
	ShelfHover = 1.6, -- studs above the shelf
}

-- Real pet models (the owner's Claude Design pets, 2026-10-21): ReplicatedStorage.PetModels.<mascot Id> (and Egg_<egg Id>),
-- built in Studio from the imported .glb files and repainted from their colours. Sized for Config.MascotFx.Size; a
-- mascot without a model falls back to the placeholder ball. Each pet's idle motion follows its design's idle pose.
-- Body = the whole pet: Bob (studs) at BobSpeed (per second), Sway (degrees of side-to-side roll) at SwaySpeed,
-- Hop = { Every = seconds, Height = studs, Time = seconds in the air }. Floats = hovers at Config.MascotFx.Hover;
-- otherwise it walks on the ground.
-- Moves = parts moving on their own (Parts = name patterns). Kinds:
--   Swing (rock Angle degrees around Axis, Speed per second), Spin (Speed turns per second around Axis),
--   Lift (feet stepping up Height studs), Slide (move Outward studs away from the middle and back), Blink (eyes shut
--   every Every seconds), Pulse (glow dims to Min and back to Max), Twinkle (Pulse, each part out of step),
--   Rainbow (colours cycle Speed times per second).
--   Pivot: "Inner" (default) = the end nearest the pet's middle (wing roots, tail bases, necks), "Center", or "Root"
--   (the pet's middle). Mirror = true: parts on the pet's left and right swing opposite ways (two wings).
-- Hide = static sparkle shapes from the design files, replaced by real particles (Particles: At = a part name
-- pattern, or "Root"; Colors; Rate per second; Size, Life, Speed; Up = how fast they rise; Back = drift backwards).
local PET_CYAN = Color3.fromRGB(40, 230, 255)
local PET_VIOLET = Color3.fromRGB(170, 60, 255)
Config.PetIdle = {
	ShowDistance = 60, -- studs: pets further from your camera than this keep still (saves phone battery)
	Pinny = {
		Body = { Bob = 0.08, BobSpeed = 1.4, Sway = 6, SwaySpeed = 0.7 },
		Moves = {
			{ Kind = "Lift", Parts = { "^foot_right" }, Height = 0.12, Speed = 1.4 },
			{ Kind = "Lift", Parts = { "^foot_left" }, Height = 0.12, Speed = 1.4, Phase = 0.5 },
			{ Kind = "Blink", Parts = { "^eye_" }, Every = 3.2 },
			{ Kind = "Pulse", Parts = { "^neck_" }, Speed = 0.6, Min = 0.6, Max = 1 },
		},
	},
	Gus = {
		Body = { Bob = 0.05, BobSpeed = 0.5, Sway = 4, SwaySpeed = 0.4 },
		Moves = {
			{ Kind = "Swing", Parts = { "^arm_" }, Axis = Vector3.xAxis, Angle = 10, Speed = 0.8, Mirror = true },
			{ Kind = "Blink", Parts = { "^eye_l_glow", "^eye_r_glow" }, Every = 4 },
			{ Kind = "Pulse", Parts = { "^neon_" }, Speed = 0.5, Min = 0.6, Max = 1 },
		},
	},
	LanePup = {
		Body = { Bob = 0.04, BobSpeed = 0.6, Hop = { Every = 3, Height = 0.6, Time = 0.45 } },
		Moves = {
			{
				Kind = "Swing",
				Parts = {
					"^skull",
					"^snout",
					"^nose",
					"^eye_",
					"^pupil_",
					"^ear_",
					"^cheeks",
					"^tongue",
					"^lane_arrow",
				},
				Axis = Vector3.zAxis,
				Angle = 8,
				Speed = 0.35,
			},
			{ Kind = "Swing", Parts = { "^ear_" }, Axis = Vector3.zAxis, Angle = 12, Speed = 1.5, Mirror = true },
			{ Kind = "Swing", Parts = { "^tail_" }, Axis = Vector3.yAxis, Angle = 30, Speed = 4 },
			{ Kind = "Blink", Parts = { "^eye_", "^pupil_" }, Every = 3.5 },
		},
	},
	Bumper = {
		Body = { Sway = 4, SwaySpeed = 0.5, Hop = { Every = 1.1, Height = 0.35, Time = 0.4 } },
		Moves = {
			{ Kind = "Blink", Parts = { "^eye_" }, Every = 3 },
			{ Kind = "Pulse", Parts = { "^stripe_", "^lane_arrow", "^end_" }, Speed = 0.8, Min = 0.7, Max = 1 },
		},
	},
	Strikey = {
		Body = { Bob = 0.1, BobSpeed = 0.8 },
		Moves = {
			{ Kind = "Blink", Parts = { "^eye_white", "^pupil", "^iris_ring", "^eye_highlight" }, Every = 3.4 },
			{ Kind = "Swing", Parts = { "^tail_bolt" }, Axis = Vector3.yAxis, Angle = 20, Speed = 1 },
			{ Kind = "Swing", Parts = { "^ear" }, Axis = Vector3.zAxis, Angle = 10, Speed = 0.4, Mirror = true },
			{ Kind = "Pulse", Parts = { "^x_mark" }, Speed = 0.7, Min = 0.7, Max = 1 },
		},
	},
	Splitz = {
		Body = { Bob = 0.08, BobSpeed = 0.8, Sway = 5, SwaySpeed = 0.5 },
		Moves = {
			{ Kind = "Swing", Parts = { "^arm_" }, Axis = Vector3.xAxis, Angle = 20, Speed = 0.8, Mirror = true },
			-- The two halves open and close (everything named _L / _R except the arms)
			{
				Kind = "Slide",
				Parts = { "^shell_", "^stripe_", "^ear_", "^finger_", "^grin_", "^eye_", "^brow_" },
				Outward = 0.06,
				Speed = 0.5,
			},
			{ Kind = "Pulse", Parts = { "^split_" }, Speed = 1, Min = 0.5, Max = 1 },
			{ Kind = "Blink", Parts = { "^eye_R_" }, Every = 3 },
		},
	},
	Hambone = {
		Body = { Bob = 0.04, BobSpeed = 0.6, Hop = { Every = 1.4, Height = 0.2, Time = 0.45 } },
		Moves = {
			{
				Kind = "Swing",
				Parts = { "^head", "^snout", "^nostril_", "^eye", "^pupil", "^cheek", "^brow", "^ear" },
				Axis = Vector3.zAxis,
				Angle = 7,
				Speed = 0.4,
			},
			{ Kind = "Swing", Parts = { "^ear" }, Axis = Vector3.xAxis, Angle = 15, Speed = 0.9, Mirror = true },
			{ Kind = "Swing", Parts = { "^tail" }, Axis = Vector3.yAxis, Angle = 25, Speed = 3 },
			{ Kind = "Swing", Parts = { "^tag_loop", "^bone_" }, Axis = Vector3.xAxis, Angle = 15, Speed = 1.2 },
		},
		Hide = { "^sparkle" },
		Particles = {
			{
				At = "^tail$",
				Colors = { Color3.fromRGB(255, 80, 190), Color3.fromRGB(255, 150, 40) },
				Rate = 8,
				Size = 0.18,
				Life = 1,
				Speed = 0.5,
				Up = 1.2,
			},
		},
	},
	NeonBat = {
		Floats = true,
		Body = { Bob = 0.25, BobSpeed = 0.6, Sway = 4, SwaySpeed = 0.4 },
		Moves = {
			{ Kind = "Swing", Parts = { "^wing_" }, Axis = Vector3.zAxis, Angle = 28, Speed = 2.2, Mirror = true },
			{
				Kind = "Swing",
				Parts = { "^head", "^snout", "^eye_", "^fang_", "^ear_" },
				Axis = Vector3.zAxis,
				Angle = 6,
				Speed = 0.3,
			},
		},
		Hide = { "^spark" },
		Particles = {
			{
				At = "^wing_edge_trail_4_L$",
				Colors = { PET_VIOLET, PET_CYAN },
				Rate = 10,
				Size = 0.14,
				Life = 0.8,
				Speed = 0.3,
				Back = 2,
			},
			{
				At = "^wing_edge_trail_4_R$",
				Colors = { PET_VIOLET, PET_CYAN },
				Rate = 10,
				Size = 0.14,
				Life = 0.8,
				Speed = 0.3,
				Back = 2,
			},
		},
	},
	Kingpin = {
		Body = { Bob = 0.05, BobSpeed = 0.5, Sway = 3, SwaySpeed = 0.35 },
		Moves = {
			{ Kind = "Spin", Parts = { "^halo" }, Axis = Vector3.zAxis, Speed = 0.12, Pivot = "Center" },
			{ Kind = "Swing", Parts = { "^scepter_", "^ball_" }, Axis = Vector3.zAxis, Angle = 8, Speed = 0.4 },
			{ Kind = "Pulse", Parts = { "^aura" }, Speed = 0.5, Min = 0.5, Max = 1 },
			{ Kind = "Spin", Parts = { "^spark" }, Axis = Vector3.yAxis, Speed = 0.15, Pivot = "Root" },
		},
	},
	Blaze = {
		Floats = true,
		Body = { Bob = 0.2, BobSpeed = 0.55 },
		Moves = {
			{ Kind = "Swing", Parts = { "^wing_" }, Axis = Vector3.zAxis, Angle = 22, Speed = 1.6, Mirror = true },
			{ Kind = "Swing", Parts = { "^tail_" }, Axis = Vector3.yAxis, Angle = 15, Speed = 0.8 },
			{
				Kind = "Swing",
				Parts = {
					"^skull",
					"^snout",
					"^nose",
					"^eye_",
					"^pupil_",
					"^ear_",
					"^horn_",
					"^cheek_",
					"^brow_",
					"^head_flame",
				},
				Axis = Vector3.yAxis,
				Angle = 18,
				Speed = 0.25,
			},
			{
				Kind = "Twinkle",
				Parts = { "^tail_flame", "^tail_lick", "^head_flame", "^crest_flame" },
				Speed = 3,
				Min = 0.7,
				Max = 1,
			},
			{ Kind = "Pulse", Parts = { "^aura" }, Speed = 0.6, Min = 0.5, Max = 1 },
		},
		Hide = { "^ember" },
		Particles = {
			{
				At = "Root",
				Colors = { Color3.fromRGB(255, 120, 20), Color3.fromRGB(255, 220, 60) },
				Rate = 10,
				Size = 0.15,
				Life = 1.3,
				Speed = 0.45,
				Up = 1,
			},
		},
	},
	Cosmo = {
		Floats = true,
		Body = { Bob = 0.2, BobSpeed = 0.5, Sway = 3, SwaySpeed = 0.35 },
		Moves = {
			-- The two tilted orbit rings (their tilt measured from the design file)
			{
				Kind = "Spin",
				Parts = { "^planet_ringed", "^planet_violet" },
				Axis = Vector3.new(0.18, 0.926, -0.331),
				Speed = 0.12,
				Pivot = "Root",
			},
			{
				Kind = "Spin",
				Parts = { "^planet_pink", "^pin_moon" },
				Axis = Vector3.new(-0.311, 0.928, 0.207),
				Speed = -0.08,
				Pivot = "Root",
			},
			{ Kind = "Spin", Parts = { "^crown_star" }, Axis = Vector3.yAxis, Speed = 0.3, Pivot = "Center" },
			{ Kind = "Swing", Parts = { "^tail_" }, Axis = Vector3.zAxis, Angle = 12, Speed = 0.6 },
			{ Kind = "Twinkle", Parts = { "^surface_star" }, Speed = 1.5, Min = 0.2, Max = 1 },
			{ Kind = "Spin", Parts = { "^mote" }, Axis = Vector3.yAxis, Speed = 0.05, Pivot = "Root" },
		},
	},
	Perfecto = {
		Floats = true,
		Body = { Bob = 0.2, BobSpeed = 0.45, Sway = 3, SwaySpeed = 0.3 },
		Moves = {
			{
				Kind = "Spin",
				Parts = { "^halo_", "^perfect_gem" },
				Axis = Vector3.new(-0.026, 0.976, -0.217),
				Speed = 0.25,
				Pivot = "Center",
			},
			{
				Kind = "Rainbow",
				Parts = { "^neon_line_", "^neck_stripe_", "^plinth_neon_", "^halo_ring_", "^hover_ring_" },
				Speed = 0.1,
			},
			{ Kind = "Spin", Parts = { "^sparkle_" }, Axis = Vector3.yAxis, Speed = -0.2, Pivot = "Root" },
			{ Kind = "Twinkle", Parts = { "^sparkle_" }, Speed = 1.2, Min = 0.2, Max = 1 },
		},
	},
	-- The Neon Egg on its stand: the core pulses on a 1.6s beat (glow 60 to 100%), the lines breathe 15%
	-- (hatch storyboard frame 1, Idle)
	Egg_Alley = {
		Moves = {
			{ Kind = "Pulse", Parts = { "^core" }, Speed = 1 / 1.6, Min = 0.6, Max = 1 },
			{ Kind = "Pulse", Parts = { "^circuit_" }, Speed = 1 / 1.6, Min = 0.85, Max = 1 },
		},
	},
}

-- Daily reward: a 7-day calendar. Claim once per day (days change at midnight UTC).
-- Missing a whole day starts you back at day 1. After day 7 it loops back to day 1.
-- Each day can give Coins, Gems, Potions ({ Id, Count } from Config.Potions), a free Egg hatch (an egg Id, hatched at the
-- egg stand) and/or a free Crate (a crate Id from Config.Crates).
-- Owner 2026-10-22: make them very valuable (day 1 15K, day 2 three x2 potions, day 3 500K...). Coin income grows
-- thousands of times over the first hour (sim: ~4K a minute at 4 min, ~100M at 40 min, ~2.5B at 60 min), so a fixed
-- number stops mattering fast: Coins is the least you get, LevelShare = or that share of your next Power Level's
-- price if it's more (PowerLevels.DailyCoins). Sim with ~30 min of play a day: day 1 = ~4 min of bowling, day 3 =
-- ~11 min, day 6 = ~35 min.
Config.Daily = {
	Rewards = {
		{ Coins = 15000, LevelShare = 0.25 },
		{ Potions = { { Id = "CoinSmall", Count = 3 } } },
		{ Coins = 500000, LevelShare = 0.5, Gems = 5 },
		{ Egg = "Alley", Gems = 10 }, -- a free Neon Egg hatch at the egg stand
		{ Potions = { { Id = "CoinBig", Count = 1 }, { Id = "XpBig", Count = 1 } } },
		{ Coins = 5000000, LevelShare = 0.5, Gems = 15 },
		-- an Alley Crate until Neon Lanes opens (Zones.RewardCrateId)
		{ Crate = "Gold", Potions = { { Id = "CoinBig", Count = 2 } }, Gems = 25 },
	},
	CheckInterval = 30, -- seconds between checks for a new day while playing
}

-- Zone milestones (Phase X Part 1): beats between the zone 2 (level 5) and zone 3 (level 12) unlocks.
-- LevelRewards: reaching Level pays its reward once, with a popup (players already past it get nothing back-dated).
--   Coins is the least you get; LevelShare = or that share of your next Power Level's price if it's more (like the
--   daily rewards). Potions = { { Id, Count } } (Config.Potions), Crate = a Config.Crates Id (opened right away).
-- Challenges: repeatable goals shown in a small HUD tracker while you bowl in that Zone (nil Zone = any zone).
--   Kind "StrikeStreak" = Goal strikes in a row (a miss starts it over). Cooldown = seconds before it can be done
--   again after a win (0 = straight away). Reward = like LevelRewards. Add rows to add challenges.
-- Preview: the tracker also shows the next level reward (Phase X Part 1.3).
Config.Milestones = {
	Enabled = true,
	LevelRewards = {
		{ Level = 7, Coins = 50000, LevelShare = 0.1, Crate = "Bronze" },
		{ Level = 9, Coins = 150000, LevelShare = 0.15, Potions = { { Id = "CoinSmall", Count = 2 } } },
	},
	Challenges = {
		{
			Id = "NeonStreak3",
			Zone = 2,
			Kind = "StrikeStreak",
			Goal = 3,
			Text = "GET %d STRIKES IN A ROW", -- %d = Goal
			Cooldown = 180,
			Reward = { Crate = "Bronze" },
			RewardText = "FREE BRONZE CRATE",
		},
	},
	Preview = true, -- show "NEXT: LV 9 REWARD" under the challenge (false = hide it)
	PopupTime = 3.5, -- seconds a level reward popup stays up
}

-- Potions (owner 2026-10-22): drink one for a 15 minute boost. Coin potions multiply coins, XP potions multiply XP.
-- Small = x2 and common, Big (MEGA) = x4 and rarer (playtime rewards hand them out; Studio: TEST: POTIONS button).
-- Timers only run while you play (they pause when you leave). Drinking another of the same potion adds its time.
-- Coin and XP boosts multiply together. Within one kind only the strongest running potion counts (x4 beats x2,
-- they never make x8); the weaker one's timer waits until the stronger one runs out, so no minutes are wasted.
Config.Potions = {
	List = {
		{
			Id = "CoinSmall",
			Name = "COIN POTION",
			Boost = "Coins",
			Multiplier = 2,
			Minutes = 15,
			Big = false,
			Color = Color3.fromRGB(255, 200, 40),
		},
		{
			Id = "CoinBig",
			Name = "MEGA COIN POTION",
			Boost = "Coins",
			Multiplier = 4,
			Minutes = 15,
			Big = true,
			Color = Color3.fromRGB(255, 140, 20),
		},
		{
			Id = "XpSmall",
			Name = "XP POTION",
			Boost = "XP",
			Multiplier = 2,
			Minutes = 15,
			Big = false,
			Color = Color3.fromRGB(70, 230, 255),
		},
		{
			Id = "XpBig",
			Name = "MEGA XP POTION",
			Boost = "XP",
			Multiplier = 4,
			Minutes = 15,
			Big = true,
			Color = Color3.fromRGB(190, 90, 255),
		},
	},
	MaxMinutes = 600, -- one potion's timer never stacks past this many minutes
	Tick = 1, -- seconds between timer updates
}

-- Playtime rewards (owner 2026-10-22): a free gift every 15 minutes of play, 12 of them (3 hours). They start over
-- on every visit (not daily). Tap the GIFTS button and CLAIM a gift once its timer is done; unclaimed gifts stay
-- claimable until you leave. A gift is one of: Potion (a Config.Potions Id, goes to the POTIONS stash), Egg (a
-- free hatch of that egg at the egg stand, kept until used) or Crate (opened right away). A Crate from a zone you
-- haven't reached comes as your zone's crate, unless Exact = true (the 3-hour Gold Crate: exactly a Gold Crate).
Config.Playtime = {
	Enabled = true,
	Rewards = {
		{ Minutes = 15, Potion = "CoinSmall" },
		{ Minutes = 30, Egg = "Alley" }, -- the Neon Egg (owner: zone 2 is open by then)
		{ Minutes = 45, Potion = "XpSmall" },
		{ Minutes = 60, Crate = "Bronze" },
		{ Minutes = 75, Potion = "CoinSmall" },
		{ Minutes = 90, Potion = "XpBig" },
		{ Minutes = 105, Crate = "Bronze" },
		{ Minutes = 120, Potion = "CoinBig" },
		{ Minutes = 135, Potion = "XpSmall" },
		{ Minutes = 150, Crate = "Silver" },
		{ Minutes = 165, Potion = "CoinBig" },
		{ Minutes = 180, Crate = "Gold", Exact = true }, -- owner: players are in zone 3 by 3 hours
	},
}

-- Daily spin wheel (owner 2026-10-22): a big wheel you walk up to in Neon Lanes (zone 2), at the far end of the east
-- walkway beside the lanes (the back wall leaves no room behind the pins). One free spin a day (days change at
-- midnight UTC, like the daily reward). Built in code on each player's screen (SpinController); the server
-- (SpinService) checks you stand by it, rolls the slice and hands out the prize before the wheel even turns.
-- Slices: Potion (a Config.Potions Id), Egg (a free hatch at the egg stand), Crate (opened right away; a crate from a
-- zone you haven't reached comes as your zone's), Ball = a ball of that rarity from that crate (shown as SECRET
-- BALL), Pet = a pet of that rarity from that egg (shown as SECRET PET). Chance = % (adds up to 100); the slices are
-- drawn the same size whatever their chance, like every simulator wheel.
-- Phase X: SECRET BALL and SECRET PET give an Epic now (was Legendary), the best rarity zone 2 has (Config.ZoneRarity).
Config.Spin = {
	Enabled = true,
	Zone = 2, -- you need this zone open to use it (it stands inside the zone 2 building anyway)
	Center = Vector3.new(51, 10.5, -73.5), -- the middle of the wheel
	Facing = Vector3.new(0, 0, 1), -- the wheel's face looks this way (south, back toward the lobby)
	Radius = 6.5,
	UseRange = 16, -- studs (flat) from the middle of the wheel the server accepts a spin from
	PromptRange = 12,
	SpinSeconds = 5.5,
	Turns = 6, -- whole turns before it slows onto the prize
	CheckInterval = 30, -- seconds between "is it a new day?" checks while playing
	Slices = {
		{ Label = "COIN POTION", Potion = "CoinSmall", Chance = 24, Color = Color3.fromRGB(255, 190, 40) },
		{ Label = "NEON EGG", Egg = "Alley", Chance = 10, Color = Color3.fromRGB(255, 70, 200) },
		{ Label = "XP POTION", Potion = "XpSmall", Chance = 22, Color = Color3.fromRGB(60, 220, 255) },
		{ Label = "BRONZE CRATE", Crate = "Bronze", Chance = 16, Color = Color3.fromRGB(205, 125, 60) },
		{ Label = "MEGA COIN", Potion = "CoinBig", Chance = 10, Color = Color3.fromRGB(255, 130, 20) },
		{
			Label = "SECRET BALL",
			Ball = "Epic",
			Crate = "Gold",
			Chance = 0.5,
			Secret = true,
			Color = Color3.fromRGB(255, 215, 60),
		},
		{ Label = "MEGA XP", Potion = "XpBig", Chance = 8, Color = Color3.fromRGB(170, 80, 255) },
		{ Label = "SILVER CRATE", Crate = "Silver", Chance = 8.5, Color = Color3.fromRGB(190, 200, 225) },
		{
			Label = "SECRET PET",
			Pet = "Epic",
			Egg = "Alley",
			Chance = 1,
			Secret = true,
			Color = Color3.fromRGB(255, 215, 60),
		},
	},
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
		{
			Id = "Pins",
			Title = "MOST LIFETIME PINS",
			Column = "PINS",
			Stat = "LifetimePins",
			Store = "LB_LifetimePins",
		},
		{
			Id = "Streak",
			Title = "BEST STRIKE STREAK",
			Column = "STREAK",
			Stat = "BestStreak",
			Store = "LB_BestStreak",
		},
		{
			Id = "Weekly",
			Title = "WEEKLY COINS",
			Column = "COINS",
			ShowCoin = true, -- coin icon next to the top 3 scores and your own
			Stat = "WeeklyCoins",
			Store = "LB_WeeklyCoins",
			Weekly = true,
		},
	},
}

-- Playtest analytics (Roblox AnalyticsService, results in the Creator Dashboard → Analytics).
-- OnboardingSteps is the first-session funnel, in order; Roblox counts each step once per player.
Config.Analytics = {
	Enabled = true,
	OnboardingSteps = {
		"Joined",
		"First Throw",
		"First Strike",
		"Double Strike",
		"Opened Crate",
		"Equipped Ball",
		"Ranked Up",
		"Bought Power Level",
		"Gift Crate",
		"Saw Legends",
	},
	PlayTimeInterval = 30, -- seconds between adding play time to the save
	-- Every custom event name the game logs (MASTER_PLAN.md section 7). A name not on this list prints a warning in
	-- Studio, so typos get caught. Rows marked "later" are stubs: the milestone that adds the system starts logging them.
	Events = {
		"SessionStart",
		"SessionEnd", -- value = session minutes; labels = last action before leaving, minutes played in total
		"Throw", -- value = pins; labels = tier, ball
		"FirstCoins",
		"StreakRecord", -- value = new best strike streak
		"RankUp", -- value = new rank; labels = rank name
		"LevelUp", -- value = new rank level (1-60)
		"CrateOpened", -- labels = crate, rarity, New/Duplicate
		"DailyClaimed", -- value = day
		"TrialFinished",
		"Purchase", -- value = minutes played in total; labels = kind (Crate/Ball/Egg), item  (balls and eggs: later)
		"ZoneUnlocked", -- later (Milestone 12)
		"LuckyThrow", -- later (Milestone 13)
		"MascotHatched", -- value = eggs hatched so far; labels = egg, rarity, mascot
		"BossDefeated", -- later (Milestone 15)
		"PityHit", -- labels = crate, rarity
		"PerfectRate", -- value = PERFECT % of the session's throws (assisted first throw left out); labels = throws, perfects
		"PolishLevel", -- value = new Polish level; labels = ball
		"PotionUsed", -- value = minutes left on that potion after drinking; labels = potion
		"PlaytimeClaimed", -- value = the gift's minute mark; labels = Potion/Egg/Crate, item
		"SpinWheel", -- value = the slice number; labels = Potion/Egg/Crate/Ball/Pet, item
		"Rebirth", -- later (Milestone 17)
		"QuestCompleted", -- later (Milestone 18)
	},
}

-- ================================================================================================
-- SIMULATOR ECONOMY (MASTER_PLAN.md section 3, with STRIKE_LEGENDS_ADDENDUM_1.md on top). The economy simulator (ServerStorage.Tools.EconomySim)
-- runs on these numbers today. The live game moves onto them one milestone at a time: zones, Power Levels
-- and ranks in Milestone 12, streak/lucky in 13, mascots in 14, bosses in 15, crate tiers in 16 and
-- rebirth in 17. When a table goes live, the old table it replaces (Config.Ranks, Config.Crates, ...) goes.
-- Tuning: change a number here, re-run the simulator, compare with Economy.Timeline (MASTER_PLAN.md section 8).
-- ================================================================================================
-- Zone worlds (step 9a). Each zone is its own 6-lane area in Workspace (Folder = its Model).
-- Zone 1 Back Alley (Workspace.BackAlley, outside behind the lobby) is where everyone bowls for now;
-- Neon Lanes (the old alley inside the building) opens in the next part of step 9a.
-- Look = the lighting your screen uses while your character is inside the zone's Area box
-- (centre + size in studs); anywhere else (the lobby, Neon Lanes) keeps the normal Lighting.
Config.Zones = {
	LaneFolders = { "BackAlley", "NeonAlley", "MainStreetLanes", "SkylineLanes" }, -- every Workspace model that holds lanes, in zone order
	AssignFolder = "BackAlley", -- new lanes are handed out here
	BuiltZones = 4, -- zones that exist in the world so far (crates of later zones stay locked)
	-- Zones you walk into and claim a lane in (zone 2+). Locked (rank level < Config.Economy.Zones Rank): a glowing
	-- wall (Wall boxes, only on your screen) keeps you out, and the server walks you back out to KickTo.
	-- Unlocked: step onto any OPEN lane in the Area to claim it; it's yours until you leave the Area for LeaveGrace
	-- seconds (or leave the game). Your Back Alley lane stays yours the whole time.
	-- Owner 2026-10-21: zone 2 = the whole building (lobby too, with the kiosk, egg stand, leaderboards and vault):
	-- below level 5 you can't even walk in, the wall plugs the Back Alley door.
	Gated = {
		{
			Zone = 2,
			Folder = "NeonAlley",
			Area = { Center = Vector3.new(0, 12, -11.5), Size = Vector3.new(120, 30, 135) }, -- inside the building walls
			Walls = { -- centre + size in studs: the door from the Back Alley into the lobby
				{ Center = Vector3.new(54, 7, 56), Size = Vector3.new(8, 12, 2) },
			},
			WallColor = Color3.fromRGB(255, 60, 210),
			KickTo = Vector3.new(54, 4, 63), -- Back Alley, just outside the door
			Arrival = Vector3.new(0, 5, 36), -- "TAKE ME THERE" puts you here: on the lobby spawn circle (Hub.SpawnPad), facing the lanes
			LeaveGrace = 2,
		},
		-- Zone 3 (2026-10-22): Main Street Lanes, the owner's design built beside the lobby's east wall
		-- (Workspace.MainStreetLanes, same length as the lobby). A door in the lobby's east wall (between the
		-- leaderboards and the crate kiosk) leads down a short hallway into the bowler end.
		{
			Zone = 3,
			Folder = "MainStreetLanes",
			Area = { Center = Vector3.new(120, 12, -11.5), Size = Vector3.new(95, 30, 139) }, -- inside its walls
			Walls = { -- the lobby's east door (just in front of the doorway, on the lobby side)
				{ Center = Vector3.new(59.8, 7, 12), Size = Vector3.new(0.4, 12, 8) },
			},
			SignFace = Enum.NormalId.Left, -- the lock sign faces west, into the lobby
			WallColor = Color3.fromRGB(224, 165, 38),
			KickTo = Vector3.new(52, 4, 12), -- back in the lobby, in front of the door
			Arrival = Vector3.new(120, 4, 42.8), -- behind the bowler seats, facing the lanes
			LeaveGrace = 2,
		},
		-- Zone 4 (2026-10-22): Skyline Lanes, the owner's rooftop design built big (x7 the design's meters) on top of a
		-- tower far north of the lobby (Workspace.SkylineLanes, roof top at y 848). The only way up is the elevator at
		-- the east end of Main Street Lanes' back walkway (Config.Elevators); the wall covers its doors while locked.
		{
			Zone = 4,
			Folder = "SkylineLanes",
			Area = { Center = Vector3.new(0, 870, -3500), Size = Vector3.new(220, 60, 236) }, -- the whole roof
			Walls = { -- in front of the Main Street Lanes elevator doors
				{ Center = Vector3.new(165, 7.5, 46), Size = Vector3.new(0.4, 13, 17) },
			},
			SignFace = Enum.NormalId.Left, -- the lock sign faces west, down the walkway
			WallColor = Color3.fromRGB(255, 79, 139),
			KickTo = Vector3.new(158, 4, 46), -- Main Street Lanes, in front of the elevator
			Arrival = Vector3.new(81, 852, -3412), -- just out of the rooftop elevator, facing the pins
			LeaveGrace = 2,
		},
	},
	ClaimCheck = 0.25, -- seconds between the server's "who stands where" checks
	LookBlend = 0.6, -- seconds to fade between looks
	Worlds = {
		{
			Id = "StarterAlley",
			Folder = "BackAlley",
			Area = { Center = Vector3.new(0, 20, 152), Size = Vector3.new(132, 60, 190) },
			Look = {
				Ambient = Color3.fromRGB(18, 18, 26),
				OutdoorAmbient = Color3.fromRGB(22, 22, 32),
				Exposure = -0.2, -- Lighting.ExposureCompensation here (place default 0, was 0.15 before 2026-10-22); lower = darker
				Saturation = -0.22,
				Contrast = 0.06,
				Tint = Color3.fromRGB(214, 218, 240),
				HazeColor = Color3.fromHex("4b4a5c"),
				HazeDecay = Color3.fromHex("3a3936"),
				HazeDensity = 0.32,
				Haze = 1.2,
				Bloom = 0.12,
			},
			Flicker = {
				Path = { "NeonSign", "Letter_N_broken" },
				Color = Color3.fromHex("ff4fb0"),
				Dim = Color3.fromHex("7a3a5e"),
			},
		},
		{
			-- The design's mood: bright, warm and clean indoors, a light warm haze (#FFE9C7), no neon
			Id = "MainStreetLanes",
			Folder = "MainStreetLanes",
			Area = { Center = Vector3.new(120, 12, -11.5), Size = Vector3.new(95, 30, 139) },
			Look = {
				-- 2026-10-25 lighting pass: ceiling was glaring (was Ambient 70,58,46 / Outdoor 60,52,44 / Exposure -0.1;
				-- the 12 ceiling Lamp lights went 0.9 -> 0.65 in Studio, Old_Brightness_20261025 attr)
				Ambient = Color3.fromRGB(56, 46, 37),
				OutdoorAmbient = Color3.fromRGB(48, 42, 35),
				Exposure = -0.25,
				Saturation = 0.1,
				Contrast = 0.1,
				Tint = Color3.fromRGB(255, 246, 232),
				HazeColor = Color3.fromHex("FFE9C7"),
				HazeDecay = Color3.fromHex("E8C9A0"),
				HazeDensity = 0.03,
				Haze = 0.1,
				Bloom = 0.12,
			},
		},
		{
			-- The design's mood: a night rooftop over a purple city, warm gold lights, light violet haze
			Id = "SkylineLanes",
			Folder = "SkylineLanes",
			Area = { Center = Vector3.new(0, 870, -3500), Size = Vector3.new(220, 60, 236) },
			Look = {
				-- 2026-10-25 owner: "too bright" (was Ambient 100,90,135 / Outdoor 115,105,155 / Exposure 0.35 / Bloom 0.25)
				Ambient = Color3.fromRGB(62, 56, 88),
				OutdoorAmbient = Color3.fromRGB(72, 66, 102),
				Exposure = -0.05,
				Saturation = 0.12,
				Contrast = 0.1,
				Tint = Color3.fromRGB(236, 228, 255),
				HazeColor = Color3.fromHex("5B4A8A"),
				HazeDecay = Color3.fromHex("FF9F6B"),
				HazeDensity = 0.25,
				Haze = 0.5,
				Bloom = 0.15,
			},
		},
	},
}

-- Elevators (owner 2026-10-22): Skyline Lanes is a rooftop, so you ride up to it. One car at the east end of
-- Main Street Lanes' back walkway, one on the roof. Built in code on each screen (ElevatorController); the server
-- (ElevatorService) checks you have zone 4 open and stand by the car, then moves you while the screen is black.
-- Door = bottom middle of the doorway, looking out (the way you face when you step out).
Config.Elevators = {
	Zone = 4, -- you need this zone open to ride
	UseRange = 16, -- studs (flat) from the doorway the server accepts a ride from
	PromptRange = 10,
	RideSeconds = 1.6, -- how long the screen stays dark (you move halfway through)
	Cars = {
		{
			Id = "MainStreet",
			Door = CFrame.lookAt(Vector3.new(166.5, 1, 46), Vector3.new(160, 1, 46)),
			Arrive = Vector3.new(158, 4, 46),
			To = "Roof",
			Action = "RIDE UP",
			Sign = "SKYLINE LANES",
			Arrow = "▲",
			RideText = "GOING UP...",
		},
		{
			Id = "Roof",
			Door = CFrame.lookAt(Vector3.new(81, 848, -3401.5), Vector3.new(81, 848, -3410)),
			Arrive = Vector3.new(81, 852, -3412),
			To = "MainStreet",
			Action = "RIDE DOWN",
			Sign = "MAIN STREET LANES",
			Arrow = "▼",
			RideText = "GOING DOWN...",
			Housing = true, -- stands on the open roof: build the little elevator house around it
		},
	},
}

-- The "ZONE UNLOCKED" window (ZoneGateController): pops up once when your rank level opens a zone (save ZoneSeen),
-- with what's waiting there in 3D. Crates = Config.Crates Ids, Balls = Config.Balls Ids (best first).
Config.ZoneUnlock = {
	[2] = {
		Title = "ZONE 2 UNLOCKED!",
		Name = "NEON LANES",
		Tagline = "The bouncer just waved you in. Glowing lanes, pets to hatch, three new crates and the rarest balls in town are waiting inside.",
		Eggs = { "Alley" }, -- Config.EggLooks Ids: shown in 3D on the pets row (pets open with this zone)
		PetsLine = "PETS UNLOCKED: HATCH THEM IN THE LOBBY",
		MysteryPets = 3, -- "?" cards beside the egg (its pets stay a surprise)
		Crates = { "Bronze", "Silver", "Gold" },
		CratesLine = "3 NEW CRATES",
		Balls = { "Inferno", "Nebula", "Plasma", "Galaxy", "Magma", "Electric" }, -- Phase X: zone 2 tops out at Epic
		BallsLine = "%d NEW BALLS TO WIN", -- %d = how many balls those crates can give that you don't own
		Button = "TAKE ME THERE!",
		Hint = "Step onto any OPEN lane to claim it.",
		Color = Color3.fromRGB(255, 60, 210),
		Accent = Color3.fromRGB(70, 230, 255),
	},
	[3] = {
		Title = "ZONE 3 UNLOCKED!",
		Name = "MAIN STREET LANES",
		Tagline = "You're a local name now. A real bowling centre with polished wood lanes is open to you, through the new door in the lobby.",
		Eggs = { "Arcade" }, -- Phase X: the Main Street Egg
		PetsLine = "NEW EGG: HATCH IT IN MAIN STREET LANES",
		MysteryPets = 3,
		Crates = { "League", "Champion" },
		CratesLine = "2 NEW CRATES",
		Balls = { "Perfect300", "Championship", "TigerSwirl", "PearlPro", "BlueMarble", "LeagueBlack" },
		BallsLine = "%d NEW BALLS TO WIN",
		Button = "TAKE ME THERE!",
		Hint = "Step onto any OPEN lane to claim it.",
		Color = Color3.fromRGB(224, 165, 38),
		Accent = Color3.fromRGB(255, 120, 110),
	},
	[4] = {
		Title = "ZONE 4 UNLOCKED!",
		Name = "SKYLINE LANES",
		Tagline = "The big time. Take the elevator at the end of Main Street Lanes' back walkway up to the rooftop lanes above the city.",
		Eggs = { "Skyline" }, -- Phase X: the Skyline Egg
		PetsLine = "NEW EGG: HATCH IT ON THE ROOF",
		MysteryPets = 3,
		Crates = { "SkyBronze", "SkySilver", "SkyGold" },
		CratesLine = "3 NEW CRATES",
		Balls = { "Daybreak", "Lightning", "SolidGold", "Sunburst", "CloudSwirl", "Crystal" },
		BallsLine = "%d NEW BALLS TO WIN",
		Button = "TAKE ME THERE!",
		Hint = "Step onto any OPEN lane to claim it.",
		Color = Color3.fromRGB(255, 79, 139),
		Accent = Color3.fromRGB(245, 184, 46),
	},
}

Config.Economy = {}

-- One throw:
--   pinsHit = min(zone pins, ball power * throw quality)
--   coins   = pinsHit * zone pin value * Power Level value * ball Multiplier (with Polish)
--             * (1 + mascot bonuses) * (1 + RankBonus * rank)
--             * (1 + RebirthBonus * rebirths) * streak tier * crit (Perfect) * lane modifier * Golden Pin
--   xp      = pinsHit * zone XP per pin
Config.Economy.Formula = {
	QualityMin = 0.6, -- the worst timing still knocks down this share of the ball's power
	QualityMax = 1.0,
	PerfectCrit = 2.0, -- a Perfect throw (quality 1.0, sweet spot) pays this much more
	RankBonus = 0.03, -- +3% coins per rank
	RebirthBonus = 0.5, -- +50% coins per rebirth
	-- Streak, lane modifier and Golden Pin multipliers come from the live tables (Config.Streaks,
	-- Config.LaneModifiers, Config.GoldenPin); the plan's StreakPerStrike/StreakMax and Lucky Throw were replaced (step 7c).
}

-- Zones. Rank = rank level needed to enter (Shared.Modules.Zones).
-- CoinPay / XpPay = how much more a throw in this zone pays than the same throw in zone 1 (coins / XP), shown as
-- ZONE in the multiplier panel. Economy pass E2 (owner 2026-10-25: later zones pay more per pin): tuned with the
-- simulator so zone 3 opens at about 40 min and zone 4 at about 2.5 hours (were 46 min and ~10 hours at x1).
-- Pins / PinValue / XpPerPin are the old simulator's numbers (10-3,000 pin racks); nothing reads them since E1.
Config.Economy.Zones = {
	{ Id = "StarterAlley", Name = "Back Alley", Pins = 10, PinValue = 10, XpPerPin = 1, Rank = 1, CoinPay = 1, XpPay = 1 },
	{ Id = "NeonLanes", Name = "Neon Lanes", Pins = 30, PinValue = 50, XpPerPin = 2, Rank = 5, CoinPay = 4, XpPay = 1.2 },
	{ Id = "MainStreetLanes", Name = "Main Street Lanes", Pins = 100, PinValue = 250, XpPerPin = 4, Rank = 12, CoinPay = 16, XpPay = 2.5 }, -- was Arcade Arena (owner 2026-10-22)
	{ Id = "SkylineLanes", Name = "Skyline Lanes", Pins = 300, PinValue = 1250, XpPerPin = 8, Rank = 22, CoinPay = 64, XpPay = 6 },
	{ Id = "VolcanoStrike", Name = "Volcano Strike", Pins = 1000, PinValue = 6000, XpPerPin = 16, Rank = 35, CoinPay = 1, XpPay = 1 },
	{ Id = "CosmicAlley", Name = "Cosmic Alley", Pins = 3000, PinValue = 30000, XpPerPin = 32, Rank = 50, CoinPay = 1, XpPay = 1 },
}

-- Power Levels (LIVE since Addendum 2 Phase 1 step 3; the plan's "Ball Shop"): upgrades bought with coins, in order.
-- Power = pins knocked per throw at quality 1.0 (in the live game: the most pins a non-PERFECT throw can knock down;
-- a PERFECT always strikes the 10-pin Starter Alley). Value = payout multiplier, which multiplies with the equipped
-- ball's own Multiplier (Config.Balls). How each level looks and sounds: Config.Throw.Levels.
-- Tuned with the simulator. Plan prices: 0, 100, 500, 2.5K, 12K, 60K, 300K, 1.5M, 7M, 35M, 175M, 1B; plan values went
-- up to x75, lowered to x12 because ball multipliers (up to x25) stack on top. Prices jump right after each new
-- zone opens (levels 5 and 7), because a new zone pays far more per throw.
-- 2026-10-18: every simulator price and pin value went x10 so they are in real game coins (the live game pays
-- Config.Rewards.BaseCoinsPerPin = 10 per pin in zone 1). Levels 2 and 3 cheaper for Addendum 2's first 3 minutes.
Config.Economy.PowerLevels = {
	{ Level = 1, Price = 0, Power = 6, Value = 1.0 },
	{ Level = 2, Price = 400, Power = 10, Value = 1.25 },
	{ Level = 3, Price = 3000, Power = 16, Value = 1.5 },
	{ Level = 4, Price = 27000, Power = 30, Value = 2 },
	{ Level = 5, Price = 840000, Power = 50, Value = 2.5 },
	{ Level = 6, Price = 4200000, Power = 100, Value = 3 },
	{ Level = 7, Price = 100000000, Power = 180, Value = 4 },
	{ Level = 8, Price = 1500000000, Power = 350, Value = 5 },
	{ Level = 9, Price = 8200000000, Power = 700, Value = 6 },
	{ Level = 10, Price = 41000000000, Power = 1400, Value = 8 },
	{ Level = 11, Price = 210000000000, Power = 2800, Value = 10 },
	{ Level = 12, Price = 1200000000000, Power = 5000, Value = 12 },
}

-- Crate tiers (Addendum 1). Crates drop only the balls in Config.Balls: roll a rarity with these odds, then every
-- ball of that rarity is equally likely. Every row adds up to 100.
-- Prices move with the Power Level they sit next to (plan: 100, 1K, 15K, 250K, 5M).
-- Owner 2026-10-22: Alley Crate 1.6K -> 15K, Bronze 9.2K -> 75K, Silver 1M -> 750K, Gold 87M -> 65M. The very first Alley Crate
-- still costs Config.Onboarding.FirstCratePrice.
Config.Economy.Crates = {
	{ Id = "Basic", Price = 15000, Odds = { Common = 70, Uncommon = 25, Rare = 5 } },
	-- Zone 2 odds come from Config.CrateTiers since Phase X (were: Bronze C45 U35 R17 E3, Silver C20 U35 R32 E11
	-- L2, Gold U20 R45 E28 L6.5 M0.5)
	{ Id = "Bronze", Price = 75000 },
	{ Id = "Silver", Price = 750000 },
	{ Id = "Gold", Price = 65000000 },
	-- Phase X: zone 3 and 4 crates. PLACEHOLDER prices (about a quarter of the Power Level players are saving for
	-- when they reach that zone) until the 4-zone economy pass. Odds come from Config.CrateTiers.
	{ Id = "League", Price = 25000000 },
	{ Id = "Champion", Price = 1000000000 },
	{ Id = "SkyBronze", Price = 5000000000 },
	{ Id = "SkySilver", Price = 50000000000 },
	{ Id = "SkyGold", Price = 500000000000 },
	{ Id = "Neon", Price = 5900000000, Odds = { Rare = 40, Epic = 38, Legendary = 18, Mythic = 4 } }, -- simulator only (not in Config.Crates)
}
-- Crate tiers (Phase X Part 4): a crate with a Tier gets its odds from its zone's rarity range (Config.ZoneRarity).
-- Keys are steps up from the zone's lowest rarity (0 = lowest), values = percent. Zone 2 (Uncommon to Epic):
-- Bronze = Uncommon 75 / Rare 25, Silver = Uncommon 35 / Rare 55 / Epic 10, Gold = Rare 70 / Epic 30.
-- Zones 3 and 4 shift the same shape up one rarity per zone. A rarity a crate's zone has no balls of gives its
-- share to the nearest rarity that has some (Shared.Modules.Balls).
Config.CrateTiers = {
	Bronze = { [0] = 75, [1] = 25 },
	Silver = { [0] = 35, [1] = 55, [2] = 10 },
	Gold = { [1] = 70, [2] = 30 },
}
-- Pity: a pull of one of these Crates is at least Rarity once that many pulls in a row (of that crate) missed it
Config.Economy.CratePity = {
	{ Crates = { Basic = true, Bronze = true }, Rarity = "Rare", After = 10 },
	{ Crates = { Silver = true, Gold = true }, Rarity = "Epic", After = 20 },
	{ Crates = { Neon = true }, Rarity = "Legendary", After = 80 }, -- Gold left this row in Phase X (no Legendary in zone 2)
	-- Phase X zone 3 and 4 crates: the same idea one and two rarities up
	{ Crates = { League = true }, Rarity = "Epic", After = 10 },
	{ Crates = { Champion = true }, Rarity = "Legendary", After = 20 },
	{ Crates = { SkyBronze = true }, Rarity = "Legendary", After = 10 },
	{ Crates = { SkySilver = true }, Rarity = "Mythic", After = 40 },
	{ Crates = { SkyGold = true }, Rarity = "Mythic", After = 20 },
}
Config.Economy.FirstCrateMin = "Uncommon" -- the very first crate a player opens gives at least this (unless it's the
-- first bought crate or the gift crate, which use Config.Onboarding.FirstBoughtRarity / GiftRarity)
-- Duplicates become Polish Points; Polish levels raise one ball's Multiplier. A maxed ball's duplicates pay coins.
Config.Economy.Polish = {
	ValuePerLevel = 0.05, -- each level adds +5% of that ball's Multiplier
	MaxLevel = 10,
	PointsPerDuplicate = 1, -- starting guess (Milestone 16)...
	PointsPerLevel = 1, -- ...so one duplicate = one level for now
	-- Gem sink (step 7b, owner's choice): gems buy the next Polish level of a ball you own, one level at a time.
	-- Price = GemPrice[rarity] x the level you're buying (Common: 4 for level 1, 8 for level 2 ... 40 for level 10).
	-- Starting guess from gem income (~1 gem/min early: PERFECT drops, 2 per rank level, daily): first Common level
	-- in about 4 minutes of gems, a full Common ball about 220 gems.
	GemPrice = { Common = 4, Uncommon = 6, Rare = 10, Epic = 16, Legendary = 25, Mythic = 40 },
}

-- LIVE since Addendum 2 Phase 2 step 6: the shop crates (Config.Crates) take their price and odds from Economy.Crates
-- (a crate with a Tier and no Odds of its own gets them from Config.CrateTiers + its zone's Config.ZoneRarity)
local function tierOdds(tier: string, zone: number)
	local range = Config.ZoneRarity[zone]
	local shape = Config.CrateTiers[tier]
	if not range or not shape then
		return nil
	end
	local low = 1
	for index, rarity in Config.Rarities do
		if rarity.Name == range.Min then
			low = index
		end
	end
	local odds = {}
	for step, percent in shape do
		local rarity = Config.Rarities[math.min(low + step, #Config.Rarities)]
		odds[rarity.Name] = (odds[rarity.Name] or 0) + percent
	end
	return odds
end
for _, crate in Config.Crates do
	for _, row in Config.Economy.Crates do
		if row.Id == crate.Id then
			crate.Price = row.Price
			crate.Odds = row.Odds or (crate.Tier and tierOdds(crate.Tier, crate.Zone or 1))
			row.Odds = crate.Odds -- the simulator reads Economy.Crates
		end
	end
	assert(crate.Odds, "Config.Crates." .. crate.Id .. " has no row (or odds) in Config.Economy.Crates")
end
-- Phase X 8B: a ball row without its own Multiplier uses its rarity's (Config.RarityPower)
for _, ball in Config.Balls do
	if ball.Multiplier == nil then
		local power = Config.RarityPower[ball.Rarity]
		ball.Multiplier = if power then power.Ball else 1
	end
end

-- Mascots (Milestone 14). Unlock: Rank = rank needed, or Zone = zone number that must be unlocked.
-- BonusScale: this egg's mascots get Mascots.Bonus times this (not in the plan, where every egg gave the same
-- bonuses: cheap eggs made coins explode and expensive eggs were pointless). Plan prices: 400, 6K, 90K, 1.5M, 30M.
Config.Economy.Eggs = {
	{ Id = "Alley", Price = 50000, Zone = 2, BonusScale = 0.1 }, -- owner 2026-10-21: pets open with Neon Lanes; 3,700 -> 50K (owner 2026-10-22)
	{ Id = "Neon", Price = 420000, Zone = 2, BonusScale = 0.2 },
	{ Id = "Arcade", Price = 6300000, Zone = 3, BonusScale = 0.4 }, -- Main Street Egg (Phase X). PLACEHOLDER price
	{ Id = "Skyline", Price = 1500000000, Zone = 4, BonusScale = 0.7 }, -- Skyline Egg (Phase X). PLACEHOLDER price
	{ Id = "Volcano", Price = 35000000000, Zone = 5, BonusScale = 1 },
}
Config.Economy.Mascots = {
	Odds = { Common = 60, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 0.9, Mythic = 0.1 },
	Bonus = {}, -- per rarity, from Config.RarityPower Pet (Common 0.2 ... Mythic 15); added together
	ShinyMerge = 3, -- this many of the same mascot make a Shiny...
	ShinyMultiplier = 2, -- ...with this much more bonus
	StartSlots = 3,
	MaxSlots = 6,
	SlotRanks = { 15, 30 }, -- each of these ranks adds a slot
	SlotRebirths = { 1 }, -- each of these rebirth counts adds a slot
}
for name, power in Config.RarityPower do
	if name ~= "Step" then
		Config.Economy.Mascots.Bonus[name] = power.Pet
	end
end

-- Ranks: XP to go from rank r to r+1 = Base * Growth^(r-1) up to rank LateFrom,
-- then it grows by LateGrowth per rank so ranks LateFrom..MaxRank feel steady.
Config.Economy.Ranks = {
	MaxRank = 60,
	Base = 180, -- plan: 50 (far too fast, see the changelog)
	Growth = 1.42, -- plan: 1.35
	LateFrom = 30,
	LateGrowth = 1.06,
	-- Live since step 7a (rank levels 1-60; XP per throw is still zone 1's, so later levels wait for zones 2-6)
	LevelsPerTier = 6, -- levels per Pro Tier (Config.Ranks)
	LevelGems = 2, -- gems for a level-up inside a tier (a new tier gives its own Gems instead)
	FreeCrateEvery = nil, -- nil = levels give no free crate (owner 2026-10-21); a number = every Nth level does
}

-- Rebirth ("Go Pro Tour", Milestone 17)
-- Rebirth = back to level 1, Power Level 1 and 0 coins (balls, pets, gems and potions stay; zones lock again, owner
-- 2026-10-25) for a permanent coin and XP boost, from the REBIRTH button on the HUD (owner 2026-10-25: no station;
-- RebirthController). OFF until the owner turns Enabled on.
-- Economy pass E3a (owner 2026-10-25: rebirth should be fast, not a long grind, and open at zone 3). Simulated: first
-- rebirth about 1 hour in, then one every 10-35 minutes (zone 3 is back 4 min after rebirth 1, 30 s by rebirth 10),
-- about 20 rebirths in 20 hours. Was: zone 4, 4B coins x1.6, +3 levels each.
Config.Economy.Rebirth = {
	Enabled = false, -- the owner flips this
	Zone = 3, -- the first rebirth needs this zone's level (Config.Economy.Zones Rank, 12)...
	RankStep = 1, -- ...and this many more levels for each one after
	FirstCost = 20000000, -- coins needed for the first rebirth (20M, about 20 min of zone 3 coins)...
	CostGrowth = 2, -- ...times this for each one after
	DiscountLevels = 5, -- NOT BUILT (old plan, nothing reads it): after a rebirth, Power Levels up to this one...
	DiscountPrice = 0.1, -- ...cost this share of their price
	XpBonus = 1, -- +100% XP per rebirth (owner approved). Not in the plan's formula: without it a second run is barely faster
}

-- The timeline the simulator checks (MASTER_PLAN.md section 2), in minutes from a brand new player's first join
Config.Economy.Timeline = {
	{ Goal = "Level2", Text = "Buy Power Level 2", From = 0.3, To = 1 }, -- Addendum 2: about 6 throws
	{ Goal = "FirstCrateOpened", Text = "Open first crate (1,000 sale)", From = 0.5, To = 1.5 }, -- E2: was "afford" at 15K
	{ Goal = "Rank3", Text = "Reach rank 3", From = 4, To = 5 },
	{ Goal = "FirstEgg", Text = "Afford first pet egg", From = 9, To = 14 }, -- E2: pets open with zone 2 (was 4-5)
	{ Goal = "Zone2", Text = "Unlock Zone 2 (rank 5)", From = 8, To = 10 },
	{ Goal = "Zone3", Text = "Unlock Zone 3", From = 30, To = 45 },
	{ Goal = "Zone4", Text = "Unlock Zone 4 (total play)", From = 120, To = 180, Ever = true }, -- E2; Ever = rebirths included (E3a)
	{ Goal = "RebirthReady", Text = "First rebirth available", From = 60, To = 90, Rebirth = true }, -- skipped while rebirth is off
}

-- The pretend player the simulator plays as (MASTER_PLAN.md Milestone 10 step 4)
Config.Economy.Sim = {
	Runs = 40, -- players simulated; the report shows the median
	-- One throw this often. Measured in Studio 2026-10-18 with the new throw: the lane is free again 2.2s after
	-- letting go (2.45s after a strike), plus about 0.5s holding and a moment to react = about 3s.
	ThrowSeconds = 3,
	GoodShare = 0.7, -- share of throws with good timing...
	GoodQuality = { 0.9, 1.0 }, -- ...and their quality
	BadQuality = { 0.6, 0.85 }, -- the rest
	PerfectShare = 0.15, -- share of all throws that are Perfect (counted inside the good ones)
	SpendShare = 0.25, -- buys an egg or crate only when it costs at most this share of the next Power Level
	MaxEggs = 8, -- stops hatching an egg type after this many
	MaxCrates = 10, -- stops buying a crate type after this many
	Minutes = 600, -- how long each pretend player plays (one long session: playtime gifts restart each visit)
	Rebirths = 10, -- rebirths as soon as it can, up to this many times (the report shows each run)
	-- Economy pass E1: the simulator plays the live rules (10 pins everywhere, Config.Rewards pay, rank tier
	-- multipliers, zone-only crates and eggs, level rewards, challenge, boss, playtime gifts, free crates)
	BossTripSeconds = 40, -- a boss trip (helicopter, fight, ride back) costs this much throwing time
	SpinAtZone = 2, -- the one daily spin of the session happens when this zone opens
	ToleranceShare = 0.2, -- a result more than 20% outside a timeline window counts as a mismatch
}

return Config
