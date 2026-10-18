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
-- 3. BALL POWER (the ball's stat)
---------------------------------------------------------------------------

-- The ball's Power. 100 = a normal ball. 200 = twice as violent:
-- pins fly about twice as far and the number pops are twice as big.
-- Later, better balls and upgrades will simply raise this number.
-- (In the test lane you can also change it while playing with the - and + buttons.)
ThrowSettings.BallPower = 100

-- How much Power the - and + buttons add or remove per click.
ThrowSettings.PowerButtonStep = 50

-- Pins can't fly more than this many times harder than a normal ball,
-- so very high Power stays fun instead of launching pins off the map.
ThrowSettings.MostExtraForce = 4

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

-- Pull of gravity in the test lane. Normal Roblox is 196.
-- Lower = pins hang in the air longer (floaty, more dramatic).
ThrowSettings.PinGravity = 90

---------------------------------------------------------------------------
-- 5. NUMBER POPS (the numbers that jump out of each pin)
---------------------------------------------------------------------------

-- Points shown per pin with a normal ball at full strength.
-- Power and PERFECT multiply it.
ThrowSettings.PointsPerPin = 10

-- Text size of a number pop with a normal ball. Bigger Power = bigger numbers.
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
