--[[
	THROW LAB SETTINGS
	==================
	Every number that changes how the throw FEELS lives here.
	Change a number, save, press Play. Nothing else needs touching.

	Tip: change one thing at a time, by about 20-50%, then play a few throws.
]]

local ThrowSettings = {}

---------------------------------------------------------------------------
-- 1. CHARGING (hold to charge, let go to throw)
---------------------------------------------------------------------------

-- How many seconds the bar takes to fill from empty to full.
-- Lower = faster bar = harder to time. Higher = slower bar = easier.
ThrowSettings.ChargeTime = 0.75

-- After the bar is full, it slides back down (and up again) while you keep holding.
-- true = it bounces up and down. false = it stays full until you let go.
ThrowSettings.BarBouncesBack = true

-- Where the gold "sweet spot" sits on the bar. 0 = empty, 1 = full.
ThrowSettings.SweetSpotCenter = 0.86

-- How wide the gold sweet spot is (share of the bar). 0.14 = 14% of the bar.
-- Bigger = easier to get PERFECT.
ThrowSettings.SweetSpotSize = 0.14

-- How much stronger a PERFECT release is than a full-but-not-perfect one.
-- 1.5 = 50% more force, faster ball and bigger numbers.
ThrowSettings.PerfectPowerBonus = 1.5

-- How strong a throw is if you let go almost straight away (0 to 1).
-- 0.35 = a quick tap still throws at 35% strength.
ThrowSettings.WeakestThrow = 0.35

---------------------------------------------------------------------------
-- 2. WHAT GETS KNOCKED DOWN
---------------------------------------------------------------------------

-- A PERFECT release is always a strike.
-- Outside the sweet spot: chance of a strike anyway when the bar was full.
-- (It drops quickly for weaker throws.) 0.3 = 30%.
ThrowSettings.StrikeChanceWithoutPerfect = 0.3

-- Fewest pins a throw can knock down (even a tiny tap).
ThrowSettings.FewestPinsKnocked = 3

---------------------------------------------------------------------------
-- 3. POWER LEVELS (the ball's upgrade ladder, 1 to 12)
---------------------------------------------------------------------------

-- The Power Level you start on. Change it while playing with the - and + buttons.
ThrowSettings.StartingPowerLevel = 1

-- One row per Power Level. Every level should look and hit clearly harder than the one before.
--   Size   = how big the ball is (1 = normal)
--   Force  = how hard the pins fly (1 = normal)
--   Points = the number that pops out of each pin (a PERFECT makes it bigger)
--   Color  = the ball's glow: core, light and trail
ThrowSettings.PowerLevels = {
	{ Size = 0.85, Force = 0.6, Points = 10, Color = Color3.fromRGB(190, 190, 210) }, -- 1  plain
	{ Size = 0.9, Force = 0.75, Points = 15, Color = Color3.fromRGB(90, 230, 120) }, -- 2  green
	{ Size = 0.95, Force = 0.9, Points = 20, Color = Color3.fromRGB(70, 230, 255) }, -- 3  cyan
	{ Size = 1.0, Force = 1.05, Points = 30, Color = Color3.fromRGB(60, 120, 255) }, -- 4  blue
	{ Size = 1.05, Force = 1.2, Points = 45, Color = Color3.fromRGB(150, 70, 255) }, -- 5  purple
	{ Size = 1.12, Force = 1.4, Points = 70, Color = Color3.fromRGB(255, 43, 214) }, -- 6  pink
	{ Size = 1.2, Force = 1.6, Points = 100, Color = Color3.fromRGB(255, 50, 50) }, -- 7  red
	{ Size = 1.3, Force = 1.8, Points = 150, Color = Color3.fromRGB(255, 130, 20) }, -- 8  orange
	{ Size = 1.4, Force = 2.0, Points = 220, Color = Color3.fromRGB(255, 200, 40) }, -- 9  gold
	{ Size = 1.5, Force = 2.2, Points = 330, Color = Color3.fromRGB(255, 245, 220) }, -- 10 white-hot
	{ Size = 1.6, Force = 2.45, Points = 500, Color = Color3.fromRGB(255, 80, 200) }, -- 11 rainbow
	{ Size = 1.7, Force = 2.7, Points = 750, Color = Color3.fromRGB(255, 255, 255) }, -- 12 absurd
}

-- Extra effects switch on at these levels and stay on for every level above.
ThrowSettings.SparklesFromLevel = 3 -- glittering sparks pour off the ball
ThrowSettings.FireFromLevel = 5 -- the ball is on fire
ThrowSettings.MegaCrashFromLevel = 8 -- double shockwave, big screen flash, deep extra boom
ThrowSettings.RainbowFromLevel = 11 -- rainbow trail and rainbow sparks

-- How much bigger the crash gets per level (shake, camera punch, sparks, shockwave).
-- 0.15 = each level adds 15%. Level 12 is then about 2.6 times level 1.
ThrowSettings.CrashGrowthPerLevel = 0.15

-- How fast the ball rolls at full strength (studs per second).
-- Higher = less waiting between letting go and the crash.
ThrowSettings.BallSpeed = 80

---------------------------------------------------------------------------
-- 4. PIN EXPLOSION
---------------------------------------------------------------------------

-- How hard pins are shot backwards and sideways when hit (normal ball, full strength).
ThrowSettings.PinLaunchForce = 55

-- How hard pins are shot UP into the air when hit.
ThrowSettings.PinLaunchUpward = 42

-- How fast pins spin while flying. Higher = wilder tumbling.
ThrowSettings.PinSpin = 30

-- When a flying pin hits a standing pin, how much of its speed it passes on.
-- 1 = full speed. Higher than 1 = the chain reaction gets MORE violent.
ThrowSettings.ChainReactionForce = 0.9

-- Seconds between the first and the last pin taking off. Small = all pins explode together.
-- 0 = every pin at the exact same moment. Bigger (like 0.3) = a visible ripple from front to back.
ThrowSettings.PinSpreadTime = 0.05

-- Pull of gravity in the test lane. Normal Roblox is 196.
-- Lower = pins hang in the air longer (floaty, more dramatic).
ThrowSettings.PinGravity = 90

---------------------------------------------------------------------------
-- 5. NUMBER POPS (the numbers that jump out of each pin)
---------------------------------------------------------------------------

-- (The points each pin shows are set per Power Level, in section 3.)

-- Text size of a number pop at Power Level 1. Higher levels make the numbers bigger.
ThrowSettings.NumberPopSize = 34

-- Seconds a number pop stays on screen.
ThrowSettings.NumberPopTime = 0.7

---------------------------------------------------------------------------
-- 6. CAMERA
---------------------------------------------------------------------------

-- How hard the screen shakes on impact. 0 = no shake. 1 = strong.
ThrowSettings.CameraShakeStrength = 0.5

-- How many seconds the shake lasts. Keep it short so it never slows the next throw.
ThrowSettings.CameraShakeTime = 0.25

-- How far the camera jolts toward the pins on impact (the "punch").
-- 0 = no punch.
ThrowSettings.CameraPunch = 4

-- How much the camera follows the ball down the lane. 0 = stays still, 1 = rides with it.
ThrowSettings.CameraFollow = 0.75

---------------------------------------------------------------------------
-- 7. SLOW MOTION (strikes only)
---------------------------------------------------------------------------

-- How many seconds slow motion lasts on a strike. 0 = no slow motion.
ThrowSettings.SlowMotionLength = 0.4

-- Seconds of full-speed explosion before slow motion kicks in, so the hit always feels instant.
-- 0 = slow motion starts the moment the ball touches the pins (feels like a delay).
ThrowSettings.SlowMotionStartsAfter = 0.12

-- How slow the slow motion is. 0.3 = pins move at 30% speed.
ThrowSettings.SlowMotionSpeed = 0.3

---------------------------------------------------------------------------
-- 8. SPEED OF THE LOOP
---------------------------------------------------------------------------

-- Seconds from the crash until fresh pins appear and you can throw again.
-- (A strike adds the slow-motion time on top.)
ThrowSettings.ResetDelay = 0.9

---------------------------------------------------------------------------
-- 9. STRIKE STREAKS (strikes in a row)
---------------------------------------------------------------------------

-- What the big text says for each strike in a row. After the last one,
-- it shows "8 IN A ROW!", "9 IN A ROW!" and so on.
ThrowSettings.StreakNames = {
	"STRIKE!",
	"DOUBLE!",
	"TURKEY!",
	"HAMBONE!",
	"WILD TURKEY!",
	"SIX PACK!",
	"SEVEN UP!",
}

-- Streaks that get the extra-special celebration (fireworks, cheering crowd,
-- flashing lane lights, a gold screen flash). 3 and 5 by default.
ThrowSettings.SpecialStreaks = { 3, 5 }

-- How much bigger each strike in a row celebrates. 0.15 = 15% bigger
-- text, effects and sound for every extra strike in the row.
ThrowSettings.StreakGrowth = 0.15

-- The celebration stops growing after this many strikes in a row.
ThrowSettings.StreakGrowthStopsAt = 8

-- Seconds the big STRIKE text stays on screen. Kept short so it never slows you down.
ThrowSettings.CelebrationTime = 0.8

---------------------------------------------------------------------------
-- 10. SOUNDS (rarely needs changing)
-- Each sound: Id = the Roblox sound asset number, Volume = 0 to 1.
---------------------------------------------------------------------------

ThrowSettings.Sounds = {
	Charge = { Id = 127036696152728, Volume = 0.5 }, -- when you start holding
	Perfect = { Id = 1840076509, Volume = 0.8 }, -- PERFECT release
	Throw = { Id = 9114156499, Volume = 0.6 }, -- ball let go
	Roll = { Id = 9118661490, Volume = 0.6 }, -- ball rolling
	PinHit = { Id = 9113559266, Volume = 0.9 }, -- every pin that gets hit
	Crash = { Id = 4692687595, Volume = 0.8 }, -- the ball reaching the pins
	StreakUp = { Id = 112485797063762, Volume = 0.6 }, -- every strike
	Cheer = { Id = 9120974378, Volume = 0.6 }, -- special streaks
	Firework = { Id = 134947109312227, Volume = 0.6 }, -- special streaks
	StreakLost = { Id = 97861773515321, Volume = 0.45 }, -- a streak of 2+ ends
	Click = { Id = 114782931135220, Volume = 0.4 }, -- buttons
}

return ThrowSettings
