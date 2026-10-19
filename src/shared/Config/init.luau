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
	-- Every strike in a row makes the gold this much narrower (0.1 = 10%), down to GoldSpotSmallest
	GoldShrinkPerStrike = 0.1,
	GoldSpotSmallest = 0.04,
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
		GlowRange = 8, -- the ball's light: range in studs...
		GlowRangePerLevel = 2,
		GlowBrightness = 1, -- ...and brightness
		GlowBrightnessPerLevel = 0.45,
		TrailWidth = 0.5, -- power trail: half its width, as a share of the ball (+ per level)...
		TrailWidthPerLevel = 0.05,
		TrailMaxWidth = 3.2, -- studs, half width; never wider than the lane (Config.Lane.LaneHalfWidth = 4)
		TrailLife = 0.35, -- ...and how long it hangs in the air (seconds, + per level)
		TrailLifePerLevel = 0.04,
		SparkRate = 35, -- sparks per second at SparklesFromLevel (+ per level)
		SparkRatePerLevel = 25,
		SparkSize = 0.5, -- spark size in studs, plus this share of the ball
		FireSize = 1.5, -- flames, times the ball size
		AuraFill = 0.45, -- 0 = solid glow, 1 = no glow
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

	-- Number pops out of each pin (coins earned); better balls make them bigger
	NumberPopSize = 34,
	NumberPopTime = 0.7,
	-- The big "+12.5K" total that slams in over the pins on your own throws
	PayoutPopSize = 46, -- text size for a small payout...
	PayoutPopGrowth = 10, -- ...plus this much for every x10 more coins
	PayoutPopTime = 1.1,

	-- Strike streak names on screen; after the last one it says "8 IN A ROW!" and so on
	StreakNames = { "STRIKE!", "DOUBLE!", "TURKEY!", "HAMBONE!", "WILD TURKEY!", "SIX PACK!", "SEVEN UP!" },
	SpecialStreaks = { 3, 5 }, -- extra-special celebration
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
	CrateStrikes = 0, -- strikes toward the next free crate (see Config.FreeCrates)
	FreeCrates = 0, -- free crates waiting to be opened in the shop
	PlayTime = 0, -- total seconds played, for analytics ("bought ball tier 3 after 12 minutes")
	PowerLevel = 1, -- Power Level bought so far (Config.Economy.PowerLevels)
	SessionLog = {}, -- the last few play sessions (see Config.SessionLog), newest last
	Onboarding = 0, -- first 3 minutes (Config.Onboarding): 0 = first throw next, 1 = before the gift, 2 = gift given, 3 = done
	OnboardThrows = 0, -- throws counted toward the first-3-minutes moments
}

-- Saving (DataStore)
Config.Data = {
	StoreName = "PlayerData",
	SchemaVersion = 11, -- v2 added balls and crates, v3 daily reward and leaderboard stats, v4 saved Rank (Rank Trials), v5 free crates, v6 PlayTime, v7 SessionLog, v8 PowerLevel, v9 Onboarding, v10 5 crates (CratePity, Polish, CratesOpened), v11 CratesBought. Bump when the save format changes, and add an upgrade step in SaveStore
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
-- 4. After GiftAfterThrows throws (about 4 minutes): a free gift crate, opened right there, exactly a GiftRarity ball,
--    with an EQUIP button.
-- 5. LegendsAfterThrows throws later: the camera swings to a locked ball in the lobby showcase (the chase).
-- The "next goal" bar on the HUD always shows the closest goal (next Power Level, the gift, the next free crate,
-- and the FirstCrateGoal crate until the player has bought a crate; when that crate is the goal and affordable,
-- a beam leads to its kiosk station).
Config.Onboarding = {
	Enabled = true,
	GiftAfterThrows = 65, -- about 4:00 (measured ~3.6 seconds a throw with buying and crates), after the first bought crate
	GiftCrateId = "Basic", -- the gift opens as this crate
	GiftRarity = "Rare", -- the gift crate's ball is always this rarity
	FirstCrateGoal = "Basic", -- this crate is a "next goal" until the first crate bought with coins (CratesBought)
	FirstCratePrice = 1000, -- the first FirstCrateGoal crate a player buys costs this (normal price after), ~0:45
	FirstBoughtRarity = "Uncommon", -- the first crate a player buys with coins always gives this rarity
	LegendsAfterThrows = 3, -- throws after the gift: the camera shows a locked showcase ball, then the daily unlocks
	LegendsPanTime = 3.5, -- seconds the camera looks at the locked ball
	-- Studio testing: every play test starts as a brand new player and nothing is saved (your real save is untouched).
	-- Never affects the live game. Set to false to test with your saved progress.
	StudioNewPlayer = true,
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

-- Pro Tiers. XP fills the bar; reaching the next rank's XP unlocks its Rank Trial (see Config.Trials),
-- and passing the trial gives the rank. Coin multiplier is permanent; gems are a one-time rank-up reward.
-- Tuned for roughly 180-390 XP a minute (more with strike streaks, see Config.Streaks XpMultiplier):
-- the XP bar for Amateur fills after ~1-1.5 minutes; the 1-strike trial (no cooldown, see Config.Trials) then
-- takes about 20-40 seconds more at a 15% PERFECT rate, so the first rank-up lands around 1:30-2:00.
-- Each rank after that takes much longer.
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
		Id = "Lucky", -- Value: extra Golden Pin chance (1 = twice as likely). Golden Pins arrive in 9.5d.
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
		TextSize = 40, -- pixels on a 1080p screen, scaled with the screen
		MinTextSize = 26,
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

-- Lobby showcase: display cases for the best balls, built from Config.Balls on the slots in Workspace.Showcase.Slots.
-- Every ball of MinRarity or better gets a case (best balls on the first slots). More balls than slots = add slots in Studio.
Config.Showcase = {
	MinRarity = "Rare", -- 11 balls on 11 slots (Rare, Epic, Legendary, Mythic)
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

	-- The look of each rarity's case, from the owner's renders. Leave a line out to turn that effect off.
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
--   Disk:      a flat glowing disk around the ball (The Void). Spin in degrees per second
--   Halos:     camera-facing glows around the ball. Ground: glowing rings on the floor under the ball
--   Badge:     the trait icon floating above Rare balls. Light: the glow the ball throws around it
-- A ball without a row gets a simple trail in its Trail colour.
local WHITE = Color3.fromRGB(255, 255, 255)
Config.BallVfx = {
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
			Disk = {
				Color = Color3.fromRGB(255, 70, 220),
				Radius = 1.25,
				Tilt = { 72, 8 },
				Spin = 70,
				Transparency = 0.05,
			},
			Halos = {
				{ Image = "Ring", Color = Color3.fromRGB(255, 120, 245), Size = 1.38, Transparency = 0 },
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
			Rings = {
				{ Color = Color3.fromRGB(70, 230, 255), Radius = 0.9, Width = 0.035, Tilt = { 70, 25 }, Spin = 0.25 },
				{ Color = Color3.fromRGB(255, 80, 230), Radius = 0.82, Width = 0.035, Tilt = { 75, -30 }, Spin = -0.2 },
				{ Color = Color3.fromRGB(60, 225, 255), Radius = 0.7, Width = 0.05, Tilt = { 8, -6 }, Spin = 0.1 },
			},
			-- tinted glow and light: a white glow reflects off the shiny lane as a white streak behind the ball
			Halos = { { Image = "Dot", Color = Color3.fromRGB(150, 70, 255), Size = 2.4, Transparency = 0.6 } },
			Light = { Color = Color3.fromRGB(255, 70, 190), Brightness = 2.5, Range = 6 },
		},
	},
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

-- Crates, bought with coins: name and colour here, cheapest first. Price and Odds come from Config.Economy.Crates
-- (filled in below it), pity from Config.Economy.CratePity, duplicates from Config.Economy.Polish.
-- Looks: ReplicatedStorage.CrateModels has one model per Id (Bronze, Silver and Gold are recoloured copies for now).
Config.Crates = {
	{ Id = "Basic", Name = "Basic Crate", Color = Color3.fromRGB(60, 200, 255) },
	{ Id = "Bronze", Name = "Bronze Crate", Color = Color3.fromRGB(215, 135, 70) },
	{ Id = "Silver", Name = "Silver Crate", Color = Color3.fromRGB(200, 215, 235) },
	{ Id = "Gold", Name = "Gold Crate", Color = Color3.fromRGB(255, 200, 40) },
	{ Id = "Neon", Name = "Neon Crate", Color = Color3.fromRGB(255, 60, 210) },
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
	IntroTime = 1.1, -- seconds the crate shakes on screen before the reel starts
	SpinTime = 4.5, -- seconds the crate reel spins before it stops on the result
	ScreenBrightness = 1.15, -- glow of the kiosk screens (marquee, odds, prices); higher = more vibrant
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
		"CrateOpened", -- labels = crate, rarity, New/Duplicate
		"DailyClaimed", -- value = day
		"TrialFinished",
		"Purchase", -- value = minutes played in total; labels = kind (Crate/Ball/Egg), item  (balls and eggs: later)
		"ZoneUnlocked", -- later (Milestone 12)
		"LuckyThrow", -- later (Milestone 13)
		"MascotHatched", -- later (Milestone 14)
		"BossDefeated", -- later (Milestone 15)
		"PityHit", -- labels = crate, rarity
		"PerfectRate", -- value = PERFECT % of the session's throws (assisted first throw left out); labels = throws, perfects
		"PolishLevel", -- value = new Polish level; labels = ball
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
Config.Economy = {}

-- One throw:
--   pinsHit = min(zone pins, ball power * throw quality)
--   coins   = pinsHit * zone pin value * Power Level value * ball Multiplier (with Polish)
--             * (1 + mascot bonuses) * (1 + RankBonus * rank)
--             * (1 + RebirthBonus * rebirths) * streak * boosts * crit (Perfect) * lucky
--   xp      = pinsHit * zone XP per pin
Config.Economy.Formula = {
	QualityMin = 0.6, -- the worst timing still knocks down this share of the ball's power
	QualityMax = 1.0,
	PerfectCrit = 2.0, -- a Perfect throw (quality 1.0, sweet spot) pays this much more
	RankBonus = 0.03, -- +3% coins per rank
	RebirthBonus = 0.5, -- +50% coins per rebirth
	StreakPerStrike = 0.1, -- streak multiplier = 1 + this * strikes in a row...
	StreakMax = 3.0, -- ...capped here. Any non-strike sets it back to 1
	LuckyChance = 0.03, -- Lucky Throw: chance on any throw (Milestone 13)...
	LuckyMultiplier = 5, -- ...and its payout multiplier
}

-- Zones: you need Power >= Pins to strike a zone's lane. Rank = rank needed to enter.
Config.Economy.Zones = {
	{ Id = "StarterAlley", Name = "Starter Alley", Pins = 10, PinValue = 10, XpPerPin = 1, Rank = 1 },
	{ Id = "NeonLanes", Name = "Neon Lanes", Pins = 30, PinValue = 50, XpPerPin = 2, Rank = 5 },
	{ Id = "ArcadeArena", Name = "Arcade Arena", Pins = 100, PinValue = 250, XpPerPin = 4, Rank = 12 },
	{ Id = "SkylineLanes", Name = "Skyline Lanes", Pins = 300, PinValue = 1250, XpPerPin = 8, Rank = 22 },
	{ Id = "VolcanoStrike", Name = "Volcano Strike", Pins = 1000, PinValue = 6000, XpPerPin = 16, Rank = 35 },
	{ Id = "CosmicAlley", Name = "Cosmic Alley", Pins = 3000, PinValue = 30000, XpPerPin = 32, Rank = 50 },
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
Config.Economy.Crates = {
	{ Id = "Basic", Price = 1600, Odds = { Common = 70, Uncommon = 25, Rare = 5 } },
	{ Id = "Bronze", Price = 9200, Odds = { Common = 45, Uncommon = 35, Rare = 17, Epic = 3 } },
	{ Id = "Silver", Price = 1000000, Odds = { Common = 20, Uncommon = 35, Rare = 32, Epic = 11, Legendary = 2 } },
	{ Id = "Gold", Price = 87000000, Odds = { Uncommon = 20, Rare = 45, Epic = 28, Legendary = 6.5, Mythic = 0.5 } },
	{ Id = "Neon", Price = 5900000000, Odds = { Rare = 40, Epic = 38, Legendary = 18, Mythic = 4 } },
}
-- Pity: a pull of one of these Crates is at least Rarity once that many pulls in a row (of that crate) missed it
Config.Economy.CratePity = {
	{ Crates = { Basic = true, Bronze = true }, Rarity = "Rare", After = 10 },
	{ Crates = { Silver = true, Gold = true }, Rarity = "Epic", After = 20 },
	{ Crates = { Gold = true, Neon = true }, Rarity = "Legendary", After = 80 },
}
Config.Economy.FirstCrateMin = "Rare" -- the very first crate a player opens gives at least this (unless it's the
-- first bought crate or the gift crate, which use Config.Onboarding.FirstBoughtRarity / GiftRarity)
-- Duplicates become Polish Points; Polish levels raise one ball's Multiplier. A maxed ball's duplicates pay coins.
Config.Economy.Polish = {
	ValuePerLevel = 0.05, -- each level adds +5% of that ball's Multiplier
	MaxLevel = 10,
	PointsPerDuplicate = 1, -- starting guess (Milestone 16)...
	PointsPerLevel = 1, -- ...so one duplicate = one level for now
}

-- LIVE since Addendum 2 Phase 2 step 6: the shop crates (Config.Crates) take their price and odds from Economy.Crates
for _, crate in Config.Crates do
	for _, row in Config.Economy.Crates do
		if row.Id == crate.Id then
			crate.Price = row.Price
			crate.Odds = row.Odds
		end
	end
	assert(crate.Odds, "Config.Crates." .. crate.Id .. " has no row in Config.Economy.Crates")
end

-- Mascots (Milestone 14). Unlock: Rank = rank needed, or Zone = zone number that must be unlocked.
-- BonusScale: this egg's mascots get Mascots.Bonus times this (not in the plan, where every egg gave the same
-- bonuses: cheap eggs made coins explode and expensive eggs were pointless). Plan prices: 400, 6K, 90K, 1.5M, 30M.
Config.Economy.Eggs = {
	{ Id = "Alley", Price = 3700, Rank = 3, BonusScale = 0.1 },
	{ Id = "Neon", Price = 420000, Zone = 2, BonusScale = 0.2 },
	{ Id = "Arcade", Price = 6300000, Zone = 3, BonusScale = 0.4 },
	{ Id = "Skyline", Price = 1500000000, Zone = 4, BonusScale = 0.7 },
	{ Id = "Volcano", Price = 35000000000, Zone = 5, BonusScale = 1 },
}
Config.Economy.Mascots = {
	Odds = { Common = 60, Uncommon = 25, Rare = 10, Epic = 4, Legendary = 0.9, Mythic = 0.1 },
	Bonus = { Common = 0.2, Uncommon = 0.5, Rare = 1.0, Epic = 2.5, Legendary = 6, Mythic = 15 }, -- added together
	ShinyMerge = 3, -- this many of the same mascot make a Shiny...
	ShinyMultiplier = 2, -- ...with this much more bonus
	StartSlots = 3,
	MaxSlots = 6,
	SlotRanks = { 15, 30 }, -- each of these ranks adds a slot
	SlotRebirths = { 1 }, -- each of these rebirth counts adds a slot
}

-- Ranks: XP to go from rank r to r+1 = Base * Growth^(r-1) up to rank LateFrom,
-- then it grows by LateGrowth per rank so ranks LateFrom..MaxRank feel steady.
Config.Economy.Ranks = {
	MaxRank = 60,
	Base = 180, -- plan: 50 (far too fast, see the changelog)
	Growth = 1.42, -- plan: 1.35
	LateFrom = 30,
	LateGrowth = 1.06,
}

-- Rebirth ("Go Pro Tour", Milestone 17)
Config.Economy.Rebirth = {
	FirstRank = 20, -- rank needed for the first rebirth...
	RankStep = 3, -- ...and this many more ranks for each one after
	FirstCost = 4000000000, -- coins needed for the first rebirth... (plan: none given)
	CostGrowth = 1.6, -- ...times this for each one after
	DiscountLevels = 5, -- after a rebirth, Power Levels up to this one...
	DiscountPrice = 0.1, -- ...cost this share of their price
	XpBonus = 1, -- +100% XP per rebirth (owner approved). Not in the plan's formula: without it a second run is barely faster
}

-- The timeline the simulator checks (MASTER_PLAN.md section 2), in minutes from a brand new player's first join
Config.Economy.Timeline = {
	{ Goal = "Level2", Text = "Buy Power Level 2", From = 0.3, To = 1 }, -- Addendum 2: about 6 throws
	{ Goal = "FirstCrate", Text = "Afford first crate", From = 1.5, To = 2 },
	{ Goal = "Rank3", Text = "Reach rank 3", From = 4, To = 5 },
	{ Goal = "FirstEgg", Text = "Afford first mascot egg", From = 4, To = 5 },
	{ Goal = "Zone2", Text = "Unlock Zone 2 (rank 5)", From = 8, To = 10 },
	{ Goal = "Zone3", Text = "Unlock Zone 3", From = 30, To = 45 },
	{ Goal = "RebirthReady", Text = "First rebirth available", From = 60, To = 90 },
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
	Minutes = 150, -- how long each pretend player plays
	Rebirths = 2, -- rebirths as soon as it can, up to this many times
	ToleranceShare = 0.2, -- a result more than 20% outside a timeline window counts as a mismatch
}

return Config
