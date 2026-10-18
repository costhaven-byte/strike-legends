-- THROW LAB: one lane, one ball, ten pins. Hold to charge, let go to throw.
-- All the numbers that change the feel are in ReplicatedStorage > ThrowLab > ThrowSettings.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Settings = require(ReplicatedStorage:WaitForChild("ThrowLab"):WaitForChild("ThrowSettings"))
local World = require(script:WaitForChild("World"))
local Juice = require(script:WaitForChild("Juice"))
local Hud = require(script:WaitForChild("Hud"))

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
end)
pcall(function()
	GuiService.TouchControlsEnabled = false
end)

local GOLD = Color3.fromRGB(255, 200, 40)
local PINK = Color3.fromRGB(255, 43, 214)
local CYAN = Color3.fromRGB(70, 230, 255)
local WHITE = Color3.new(1, 1, 1)

World.Build()
Juice.SetGravity()
local powerLevel = math.clamp(Settings.StartingPowerLevel, 1, #Settings.PowerLevels)
local ball = World.BuildBall(powerLevel)
local ballLevel = powerLevel -- the level the ball on screen was built for
local ballRadius = World.BallSize(powerLevel) / 2
local pinRadius = World.PinWidth / 2

---------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------
type Pin = {
	model: Model,
	root: Part,
	row: number,
	x: number,
	index: number,
	willFall: boolean,
	launched: boolean,
	wobbling: boolean,
}

local state = "ready" -- ready, charging, rolling
local rack: { Pin } = {}
local throwRun = 0 -- goes up on every throw and reset; old timers check it and stop
local streak = 0
local held: InputObject? = nil
local charge, chargeClock = 0, 0
local throwInfo = {
	strength = 1,
	perfect = false,
	strike = false,
	force = 1,
	popScale = 1,
	crash = 1,
	color = WHITE,
	impacted = false,
}
local ballZ = World.BallStartZ
local ballSpin = 0
local rollSound: Sound? = nil

local function flyingRoots(): { BasePart }
	local roots = {}
	for _, pin in rack do
		if pin.launched then
			table.insert(roots, pin.root)
		end
	end
	return roots
end

local function inSweetSpot(value: number): boolean
	return math.abs(value - Settings.SweetSpotCenter) <= Settings.SweetSpotSize / 2
end

---------------------------------------------------------------------------
-- Pins flying
---------------------------------------------------------------------------
local function popNumber(pin: Pin, force: number)
	local base = Settings.PowerLevels[powerLevel].Points * throwInfo.strength
	local value = math.max(1, math.floor(base * (0.85 + math.random() * 0.3) + 0.5))
	local size = Settings.NumberPopSize * throwInfo.popScale * (0.9 + math.min(force, 2) * 0.1)
	local color = throwInfo.perfect and GOLD or (throwInfo.strike and PINK or WHITE)
	Juice.NumberPop(pin.root.Position + Vector3.new(0, 1, 0), value, size, color)
end

-- Sends one pin flying. from = where the hit came from; speedScale lets chain hits be softer or harder.
local function launch(pin: Pin, from: Vector3, speedScale: number)
	if pin.launched or not pin.willFall then
		return
	end
	pin.launched = true
	local root = pin.root
	local position = root.Position
	local away = Vector3.new(position.X - from.X, 0, position.Z - from.Z)
	if away.Magnitude < 0.05 then
		away = Vector3.new(0, 0, -1)
	end
	-- Mostly backwards, partly sideways, with a bit of randomness so no two crashes look the same
	local direction = (away.Unit + Vector3.new(0, 0, -0.6) + Vector3.new((math.random() - 0.5) * 0.8, 0, 0)).Unit
	local force = throwInfo.force * speedScale * (0.85 + math.random() * 0.3)
	local velocity = direction * Settings.PinLaunchForce * force
		-- (upward grows a bit slower than sideways, so pins from top levels still come back into view)
		+ Vector3.new(0, Settings.PinLaunchUpward * force ^ 0.7 * (0.8 + math.random() * 0.4), 0)
	local spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
		* Settings.PinSpin
		* math.sqrt(force)
		* (0.7 + math.random() * 0.6)

	root.Anchored = false
	root.AssemblyLinearVelocity = velocity * Juice.TimeScale
	root.AssemblyAngularVelocity = spin * Juice.TimeScale
	local trail = root:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = true
	end

	popNumber(pin, force)
	Juice.PinHitSound(force)
	Juice.Burst(
		position + Vector3.new(0, 1.2, 0),
		throwInfo.perfect and GOLD or throwInfo.color,
		10 + 6 * force,
		22 * force,
		0.5 * throwInfo.crash
	)
	Juice.Shake(Settings.CameraShakeStrength * 0.25 * throwInfo.crash, Settings.CameraShakeTime * 0.6)
end

-- A pin that stays standing gives a little wobble when something bumps it
local function wobble(pin: Pin)
	if pin.wobbling or pin.launched then
		return
	end
	pin.wobbling = true
	local root = pin.root
	local start = root.CFrame
	task.spawn(function()
		for i = 1, 6 do
			if not root.Parent then
				return
			end
			local tilt = math.rad(9) * (1 - i / 6) * (i % 2 == 0 and 1 or -1)
			root.CFrame = start * CFrame.Angles(0, tilt, 0) -- (the root is lying on its side, so Y tilts it)
			task.wait(0.04)
		end
		if root.Parent then
			root.CFrame = start
		end
		pin.wobbling = false
	end)
end

-- Flying pins knock over the pins they touch: the chain reaction.
local function hookChainReaction(pin: Pin)
	for _, part in pin.model:GetChildren() do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(other)
				if pin.launched then
					return
				end
				local otherModel = other.Parent
				if not otherModel or otherModel == pin.model or otherModel.Name ~= "Pin" then
					return
				end
				local otherRoot = (otherModel :: Model).PrimaryPart
				if not otherRoot or otherRoot.Anchored then
					return
				end
				if not pin.willFall then
					wobble(pin)
					return
				end
				local hitSpeed = otherRoot.AssemblyLinearVelocity.Magnitude / math.max(Juice.TimeScale, 0.05)
				local normalSpeed = Settings.PinLaunchForce * throwInfo.force
				local scale = math.clamp(hitSpeed / math.max(normalSpeed, 1), 0.6, 1.4) * Settings.ChainReactionForce
				launch(pin, otherRoot.Position, scale)
			end)
		end
	end
end

local function newRack()
	rack = {}
	for _, info in World.BuildRack() do
		local pin: Pin = {
			model = info.model,
			root = info.root,
			row = info.row,
			x = info.x,
			index = info.index,
			willFall = false,
			launched = false,
			wobbling = false,
		}
		hookChainReaction(pin)
		table.insert(rack, pin)
	end
end

-- Decides which pins go down. A PERFECT release is always a strike.
-- Pins on the ball's path always fall; the rest are picked front-to-back with some luck.
local function choosePins(value: number, perfect: boolean): boolean
	local strike = perfect or math.random() < Settings.StrikeChanceWithoutPerfect * value ^ 3
	local count = 10
	if not strike then
		local wanted = Settings.FewestPinsKnocked + (9 - Settings.FewestPinsKnocked) * value + (math.random() * 2 - 1)
		count = math.clamp(math.floor(wanted + 0.5), math.max(Settings.FewestPinsKnocked, 2), 9)
	end
	local order = {}
	for _, pin in rack do
		local onPath = math.abs(pin.x) < 0.1
		table.insert(
			order,
			{ pin = pin, score = onPath and -100 or (math.abs(pin.x) * 0.7 + pin.row * 0.6 + math.random() * 2.2) }
		)
	end
	table.sort(order, function(a, b)
		return a.score < b.score
	end)
	for i, entry in order do
		entry.pin.willFall = i <= count
	end
	return strike
end

---------------------------------------------------------------------------
-- Celebrations
---------------------------------------------------------------------------
local function isSpecial(n: number): boolean
	return table.find(Settings.SpecialStreaks, n) ~= nil
end

local function celebrateStrike()
	streak += 1
	Hud.SetStreak(streak)
	local level = math.min(streak, Settings.StreakGrowthStopsAt)
	local grow = 1 + Settings.StreakGrowth * (level - 1)
	local special = isSpecial(streak)
	if special then
		grow *= 1.3
	end

	local name = Settings.StreakNames[streak] or (streak .. " IN A ROW!")
	local color = special and GOLD or (streak == 1 and PINK or CYAN)
	Hud.Big(name, color, math.min(grow, 1.7)) -- capped so it always fits on screen
	Hud.Flash(special and GOLD or WHITE, special and 0.55 or 0.3, special and 0.4 or 0.2)
	Juice.Sound("StreakUp", 1 + 0.06 * (level - 1), math.min(grow, 1.8))
	Juice.Confetti(40 * grow)
	Juice.Shake(Settings.CameraShakeStrength * 0.5 * grow, Settings.CameraShakeTime)

	if streak >= 2 then
		Juice.FlashLights(0.35 * grow)
	end
	if special then
		Juice.Sound("Cheer", 1, grow)
		local fireworks = streak >= 5 and 5 or 3
		for i = 1, fireworks do
			task.delay((i - 1) * 0.08, function()
				local position = Vector3.new(
					(math.random() - 0.5) * 12,
					8 + math.random() * 5,
					World.HeadPinZ - 2 - math.random() * 6
				)
				Juice.Firework(position, 1 + (streak >= 5 and 0.4 or 0))
			end)
		end
	end
end

local function showResult(knocked: number)
	if throwInfo.strike then
		celebrateStrike()
		return
	end
	if streak >= 2 then
		Juice.Sound("StreakLost")
		Hud.Small(knocked .. " PINS  -  STREAK OVER", Color3.fromRGB(200, 190, 230))
	else
		Hud.Small(knocked == 9 and "9 PINS! SO CLOSE" or (knocked .. " PINS"))
	end
	streak = 0
	Hud.SetStreak(0)
end

---------------------------------------------------------------------------
-- Throw flow
---------------------------------------------------------------------------
local function placeBall()
	if ballLevel ~= powerLevel then
		ball:Destroy()
		ball = World.BuildBall(powerLevel)
		ballLevel = powerLevel
		ballRadius = World.BallSize(powerLevel) / 2
	end
	ballZ = World.BallStartZ
	ballSpin = 0
	ball.CFrame = CFrame.new(0, ballRadius, ballZ)
	World.SetBallVisible(ball, true)
	ball.Trail.Enabled = false
	ball.Glow.Brightness = World.BallGlow(powerLevel)
	ball.Glow.Color = Settings.PowerLevels[powerLevel].Color
end

local function getReady()
	state = "ready"
	placeBall()
	Juice.Follow(0)
	Hud.SetCharge(0, false, false)
	if held then
		-- Still holding from before: start charging straight away, no wasted time.
		state = "charging"
		charge, chargeClock = 0, 0
		Juice.Sound("Charge", 0.9)
	end
end

local function resetLane()
	throwRun += 1
	Juice.EndSlowMotion(flyingRoots)
	if rollSound then
		rollSound:Destroy()
		rollSound = nil
	end
	newRack()
	getReady()
end

local function startCharge()
	state = "charging"
	charge, chargeClock = 0, 0
	Hud.ShowHint(false)
	Juice.Sound("Charge", 0.9)
end

local function release()
	local value = charge
	local perfect = inSweetSpot(value)
	local strength = perfect and Settings.PerfectPowerBonus
		or (Settings.WeakestThrow + (1 - Settings.WeakestThrow) * value)
	local level = Settings.PowerLevels[powerLevel]
	local crash = (1 + Settings.CrashGrowthPerLevel * (powerLevel - 1)) * math.sqrt(strength)

	throwRun += 1
	state = "rolling"
	throwInfo = {
		strength = strength,
		perfect = perfect,
		strike = choosePins(value, perfect),
		force = level.Force * strength,
		popScale = 1 + (powerLevel - 1) * 0.08,
		crash = crash,
		color = level.Color,
		impacted = false,
	}

	Hud.SetCharge(value, perfect, false)
	-- Bigger balls sound heavier (deeper)
	local heavy = 1.1 - powerLevel * 0.03
	Juice.Sound("Throw", (1 + (strength - 1) * 0.3) * heavy)
	rollSound = Juice.Sound("Roll", (0.9 + strength * 0.2) * heavy, 0.8 + powerLevel * 0.05)
	ball.Trail.Enabled = true
	if perfect then
		Hud.Perfect()
		Juice.Sound("Perfect")
		Hud.Flash(GOLD, 0.25, 0.2)
		Juice.Burst(ball.Position, GOLD, 30, 18, 0.7)
	end
	Juice.Punch(0.8 * strength * math.sqrt(crash))
end

local function impact()
	throwInfo.impacted = true
	local run = throwRun
	local crash = throwInfo.crash
	local knocked = 0
	for _, pin in rack do
		if pin.willFall then
			knocked += 1
		end
	end

	-- The crash itself: sound, ring, sparks, camera punch and shake
	local crashPoint = Vector3.new(0, 1, World.HeadPinZ)
	local ringColor = throwInfo.perfect and GOLD or throwInfo.color
	Juice.Sound(
		"Crash",
		(throwInfo.strike and 0.95 or 1.1) * (1.08 - powerLevel * 0.025),
		math.clamp(0.5 + knocked * 0.07, 0.5, 1.3) * math.min(crash, 1.6)
	)
	Juice.Shockwave(Vector3.new(0, 0.1, World.HeadPinZ - 2), ringColor, 6 + 5 * crash)
	Juice.Burst(crashPoint, ringColor, 25 + 20 * crash, 35 * crash, 0.9 * math.sqrt(crash))
	Juice.Punch(Settings.CameraPunch * crash)
	Juice.Shake(Settings.CameraShakeStrength * crash * (0.4 + knocked * 0.06), Settings.CameraShakeTime)
	Hud.Flash(WHITE, 0.08 + knocked * 0.012, 0.12)
	if powerLevel >= Settings.MegaCrashFromLevel then
		-- Top levels: a second, bigger shockwave, a white-out flash and a deep extra boom
		task.delay(0.07, function()
			Juice.Shockwave(Vector3.new(0, 0.2, World.HeadPinZ - 2), WHITE, 10 + 7 * crash, 0.45)
		end)
		Juice.Burst(crashPoint + Vector3.new(0, 2, 0), WHITE, 15 * crash, 50 * crash, 1.6, 0.3)
		Juice.Sound("Crash", 0.55, 1.2)
		Hud.Flash(ringColor, 0.25 + (powerLevel - Settings.MegaCrashFromLevel) * 0.06, 0.25)
	end
	if throwInfo.strike then
		-- The pins burst at full speed first (instant payoff), then slow motion kicks in mid-air
		task.delay(Settings.SlowMotionStartsAfter, function()
			if run == throwRun then
				Juice.SlowMotion(Settings.SlowMotionLength, Settings.SlowMotionSpeed, flyingRoots)
			end
		end)
		showResult(knocked)
	else
		task.delay(0.25, function()
			if run == throwRun then
				showResult(knocked)
			end
		end)
	end

	-- Every pin that should fall flies within PinSpreadTime of the hit: a quick ripple from front to back,
	-- so no pin is left hanging. (Pins knocked earlier by the ball or by flying pins are skipped.)
	local hitPoint = Vector3.new(0, 0.5, World.HeadPinZ + 1.5)
	local farthest = World.PinSpacing * 3.5
	for _, pin in rack do
		if pin.willFall then
			local distance = (pin.root.Position - hitPoint).Magnitude
			task.delay(Settings.PinSpreadTime * math.clamp(distance / farthest, 0, 1), function()
				if run == throwRun and not pin.launched then
					launch(pin, hitPoint, 1)
				end
			end)
		end
	end

	local wait = Settings.ResetDelay
		+ (throwInfo.strike and Settings.SlowMotionStartsAfter + Settings.SlowMotionLength or 0)
	task.delay(wait, function()
		if run == throwRun then
			resetLane()
		end
	end)
end

local function updateRoll(dt: number)
	local scaled = dt * Juice.TimeScale
	local speed = Settings.BallSpeed * (0.55 + 0.45 * throwInfo.strength)
	if throwInfo.impacted then
		speed *= 0.6 -- the pins slow it down a bit
	end
	local step = speed * scaled
	ballZ -= step
	ballSpin += step / ballRadius
	ball.CFrame = CFrame.new(0, ballRadius, ballZ) * CFrame.Angles(-ballSpin, 0, 0)
	Juice.Follow(World.BallStartZ - math.max(ballZ, World.HeadPinZ + 6))

	-- Pins the ball rolls into
	for _, pin in rack do
		if not pin.launched then
			local p = pin.root.Position
			local dist = Vector2.new(p.X - ball.Position.X, p.Z - ballZ).Magnitude
			if dist < ballRadius + pinRadius + 0.3 then
				if not pin.willFall then
					wobble(pin) -- grazed but stays up
				else
					if not throwInfo.impacted then
						impact()
					end
					launch(pin, ball.Position, 1)
				end
			end
		end
	end

	-- Into the pit: hide the ball
	if ballZ < World.HeadPinZ - 12 and ball.Transparency < 1 then
		World.SetBallVisible(ball, false)
		if rollSound then
			Juice.Sound("PinHit", 0.6, 0.5)
			rollSound:Destroy()
			rollSound = nil
		end
	end
end

local function updateCharge(dt: number)
	chargeClock += dt / Settings.ChargeTime
	if Settings.BarBouncesBack then
		local t = chargeClock % 2
		charge = t <= 1 and t or 2 - t
	else
		charge = math.min(chargeClock, 1)
	end
	local sweetNow = inSweetSpot(charge)
	Hud.SetCharge(charge, sweetNow, true)

	-- The ball winds up: pulls back, shakes and glows more the fuller the bar
	local shake = charge * 0.08
	local offset = Vector3.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake * 0.5, charge * 1.2)
	ball.CFrame = CFrame.new(Vector3.new(0, ballRadius, World.BallStartZ) + offset)
	ball.Glow.Brightness = World.BallGlow(powerLevel) + charge * 4
	ball.Glow.Color = sweetNow and GOLD or Settings.PowerLevels[powerLevel].Color
end

RunService.RenderStepped:Connect(function(dt)
	if state == "charging" then
		updateCharge(dt)
	elseif state == "rolling" then
		updateRoll(dt)
	end
	Juice.UpdateCamera(dt)
end)

---------------------------------------------------------------------------
-- Input: press and hold anywhere (mouse, touch, or Space), let go to throw
---------------------------------------------------------------------------
local function isThrowInput(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space
		or input.KeyCode == Enum.KeyCode.ButtonA
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or held or not isThrowInput(input) then
		return
	end
	held = input
	if state == "ready" then
		startCharge()
	end
end)

-- Is this the same press that started the charge? (the same finger, mouse button or key)
local function sameInput(a: InputObject, b: InputObject): boolean
	if a.UserInputType == Enum.UserInputType.Touch then
		return a == b
	end
	if a.UserInputType == Enum.UserInputType.MouseButton1 then
		return b.UserInputType == Enum.UserInputType.MouseButton1
	end
	return a.KeyCode == b.KeyCode
end

UserInputService.InputEnded:Connect(function(input)
	if not held or not sameInput(held, input) then
		return
	end
	held = nil
	if state == "charging" then
		release()
	end
end)

-- Clicking off the game window counts as letting go
UserInputService.WindowFocusReleased:Connect(function()
	held = nil
end)

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
Hud.ResetPressed:Connect(function()
	Juice.Sound("Click")
	streak = 0
	Hud.SetStreak(0)
	held = nil
	resetLane()
end)

-- Power Level - / +: the new ball shows up straight away (or right after the current throw)
local function changePower(delta: number)
	local new = math.clamp(powerLevel + delta, 1, #Settings.PowerLevels)
	if new == powerLevel then
		Juice.Sound("Click")
		return
	end
	powerLevel = new
	Hud.SetPower(powerLevel, #Settings.PowerLevels)
	local color = Settings.PowerLevels[powerLevel].Color
	Hud.Small("POWER LEVEL " .. powerLevel, color)
	if state == "rolling" then
		Juice.Sound("Click")
		return
	end
	held = nil
	state = "ready"
	placeBall()
	Hud.SetCharge(0, false, false)
	if delta > 0 then
		Juice.Sound("StreakUp", 0.8 + powerLevel * 0.05, 0.7)
		Juice.Burst(ball.Position, color, 20 + powerLevel * 5, 12 + powerLevel, 0.6 + ballRadius * 0.3, 0.5)
		Juice.Shockwave(Vector3.new(0, 0.1, World.BallStartZ), color, 4 + powerLevel * 0.6)
	else
		Juice.Sound("Click")
	end
end
Hud.PowerDownPressed:Connect(function()
	changePower(-1)
end)
Hud.PowerUpPressed:Connect(function()
	changePower(1)
end)

Hud.SetPower(powerLevel, #Settings.PowerLevels)
Hud.SetStreak(0)
newRack()
getReady()
