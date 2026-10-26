-- Plays every throw on this player's screen: the ball roll, the pins the server says fall (the Throw Lab explosion),
-- and the effects (sounds, lane lights, sparks, shockwaves, number pops, plus slow motion, camera punch and shake
-- on your own throws).
-- Pins live only on this client, so they never lag and always match the server's result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PinRack = require(Shared.Modules.PinRack)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Balls = require(Shared.Modules.Balls)
local BallLook = require(Shared.Modules.BallLook)
local Modifiers = require(Shared.Modules.Modifiers)
local Progression = require(Shared.Modules.Progression)
local Cosmetics = require(Shared.Modules.Cosmetics)
local ThrowRules = require(Shared.Modules.ThrowRules)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local CameraShake = require(Modules.CameraShake)
local LaneFx = require(Modules.LaneFx)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local BallFx = require(Modules.BallFx)
local TraitFx = require(Modules.TraitFx)
local ThrowFx = require(Modules.ThrowFx)
local ThrowPose = require(Modules.ThrowPose)

local LANE = Config.Lane
local CAMERA = Config.Camera
local JUICE = Config.Juice
local THROW = Config.Throw
local LEVEL_FX = THROW.LevelFx
-- Throw Lab distances were tuned on bigger pins; effect sizes scale by this
local PIN_SCALE = LANE.PinSpacing / THROW.LabPinSpacing

local GOLD = Color3.fromRGB(255, 200, 40)
local PINK = Color3.fromRGB(255, 43, 214)
local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 59, 92) -- overcharge

local normalFov = Workspace.CurrentCamera.FieldOfView

local LaneVisuals = {}
LaneVisuals.CameraHeld = false -- true while the Studio-only Day 1 video intro holds your camera (its pin camera)

local racks: { [Model]: any } = {}
local busy: { [Model]: boolean } = {} -- a throw is playing on this lane; rack changes wait for the reset

-- Pin size and the Golden Pin come from the lane modifier and lane attributes; applied when the rack is standing
local function refreshRack(lane: Model)
	local rack = racks[lane]
	if not rack or busy[lane] then
		return
	end
	local modifier = Modifiers.Current()
	local scale = modifier and modifier.PinScale or 1
	local golden = lane:GetAttribute("GoldenPin") or 0
	if rack.Scale ~= scale or rack.Golden ~= golden then
		rack.Scale = scale
		rack.Golden = golden
		rack:Reset()
	end
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 43, 214)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 200, 40)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(70, 230, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 255, 90)),
})
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

-- The thrower's equipped ball: its 3D model plus its effects (trail, sparkles, rings) from Config.BallVfx.
-- Higher Power Levels roll bigger, glow brighter, pour sparks, catch fire, glow with an aura and finally burn in
-- rainbow (Config.Throw.Levels).
local function makeBall(ballId: string?, level: number): Part
	local info = Balls.Get(ballId) or Config.Balls[1]
	local d = LANE.BallDiameter * THROW.Levels[level].Size
	local color = info.Trail or info.Color
	local rainbow = level >= THROW.RainbowFromLevel

	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * d
	ball.Color = info.Color
	ball.Material = info.Material
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	BallLook.Apply(ball, info.Id)

	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = LEVEL_FX.GlowRange + level * LEVEL_FX.GlowRangePerLevel
	glow.Brightness = LEVEL_FX.GlowBrightness + level * LEVEL_FX.GlowBrightnessPerLevel
	glow.Parent = ball
	if level >= THROW.SparklesFromLevel then
		local e = Instance.new("ParticleEmitter")
		e.Name = "PowerSparkles"
		e.Texture = SPARKLE
		e.Color = if rainbow then RAINBOW else ColorSequence.new(color, Color3.new(1, 1, 1))
		e.LightEmission = 1
		e.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, LEVEL_FX.SparkSize + d * 0.2),
			NumberSequenceKeypoint.new(1, 0),
		})
		e.Lifetime = NumberRange.new(0.3, 0.6)
		e.Speed = NumberRange.new(1, 2 + level * 0.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = LEVEL_FX.SparkRate + (level - THROW.SparklesFromLevel) * LEVEL_FX.SparkRatePerLevel
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.Parent = ball
	end
	if level >= THROW.FireFromLevel then
		local fire = Instance.new("Fire")
		fire.Name = "PowerFire"
		-- Kept low and coloured (never white) so the flames don't hide the pins
		fire.Size = d * LEVEL_FX.FireSize
		fire.Heat = 2 + level * 0.4
		fire.Color = if rainbow then Color3.fromRGB(255, 43, 214) else color
		fire.SecondaryColor = if rainbow then Color3.fromRGB(70, 230, 255) else color:Lerp(Color3.new(0, 0, 0), 0.3)
		fire.Parent = ball
	end
	if level >= THROW.AuraFromLevel then
		local aura = Instance.new("Highlight")
		aura.Name = "PowerAura"
		aura.FillColor = if rainbow then PINK else color
		aura.OutlineColor = if rainbow then GOLD else color:Lerp(WHITE, 0.5)
		aura.FillTransparency = LEVEL_FX.AuraFill
		aura.DepthMode = Enum.HighlightDepthMode.Occluded
		aura.Parent = ball
	end
	return ball
end

-- Strike slow motion: the ball and the flying pins run at a fraction of normal speed for a moment.
-- (Roblox can't slow down time itself, so we slow down everything this player sees in the alley.)
local function slowMotion(rack, setTimeScale: (number) -> ())
	local speed = math.max(THROW.SlowMotionSpeed, 0.05)
	setTimeScale(speed)
	rack:SetTimeScale(speed)
	ThrowFx.SlowMoLook(true)
	task.delay(THROW.SlowMotionLength, function()
		setTimeScale(1)
		rack:SetTimeScale(1)
		ThrowFx.SlowMoLook(false)
	end)
end

-- How hard this throw hits and how big its crash is (from the Throw Lab's Power Levels)
local function throwFeel(data, ballInfo)
	local level = ThrowRules.Level(data.PowerLevel)
	local strength = data.Power or 1
	return {
		Level = level,
		Strength = strength,
		Force = THROW.Levels[level].Force * strength,
		Crash = (1 + THROW.CrashGrowthPerLevel * (level - 1)) * math.sqrt(strength),
		PopScale = 1 + (level - 1) * 0.12,
		RarityColor = (Balls.GetRarity(ballInfo.Rarity) or {}).Color,
		Rarity = Balls.RarityIndex(ballInfo.Rarity),
		HitStop = if data.Perfect then THROW.HitStop else 0,
		Color = if data.Overcharge == "Blast"
			then RED
			elseif data.Perfect then GOLD
			else ballInfo.Trail or ballInfo.Color,
	}
end

-- Everything that happens the moment the ball reaches the pins
-- A cosmetic pin blast (Config.Cosmetics PinFx): a burst and a ring per colour, on top of the normal crash
local function pinBlast(item, crashPoint: Vector3, ringPoint: Vector3, strength: number)
	local size = Config.Cosmetics.BlastSize * strength
	for index, color in item.Colors do
		task.delay((index - 1) * 0.05, function()
			ThrowFx.Burst(crashPoint + Vector3.new(0, index * 0.5, 0), color, 30 * size, 40 * size * PIN_SCALE, 1.1)
			ThrowFx.Shockwave(ringPoint + Vector3.new(0, 0.15 * index, 0), color, (9 + 4 * index) * size * PIN_SCALE, 0.4)
		end)
	end
end

-- A cosmetic strike banner (Config.Cosmetics Banner): a flag with its word that pops up over the pins
local function strikeBanner(lane: Model, item, headPin: Vector3)
	local looks = Config.Cosmetics
	local spot = Instance.new("Part")
	spot.Name = "StrikeBanner"
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.CanTouch = false
	spot.Transparency = 1
	spot.Size = Vector3.one * 0.2
	spot.Position = headPin + Vector3.new(0, looks.BannerHeight, 0)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(14, 3.6)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.MaxDistance = 220
	gui.Parent = spot
	local flag = Instance.new("Frame")
	flag.AnchorPoint = Vector2.new(0.5, 0.5)
	flag.Position = UDim2.fromScale(0.5, 0.5)
	flag.Size = UDim2.fromScale(0, 0.85)
	flag.BackgroundColor3 = item.Colors[1]
	flag.ClipsDescendants = true
	flag.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = flag
	local edge = Instance.new("UIStroke")
	edge.Color = item.Colors[2] or WHITE
	edge.Thickness = 4
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = flag
	local word = Instance.new("TextLabel")
	word.BackgroundTransparency = 1
	word.Size = UDim2.fromScale(1, 1)
	word.Font = Enum.Font.LuckiestGuy
	word.Text = item.Word or "STRIKE!"
	word.TextScaled = true
	word.TextColor3 = item.Colors[2] or WHITE
	word.Parent = flag
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.new(0, 0, 0)
	outline.Thickness = 3
	outline.Parent = word
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.1, 0)
	padding.PaddingBottom = UDim.new(0.08, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = word
	spot.Parent = lane
	-- Unrolls from the middle, bobs while it's up, then rolls back up
	TweenService:Create(flag, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1, 0.85),
	}):Play()
	local started = os.clock()
	local bob = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		spot.Position = headPin + Vector3.new(0, looks.BannerHeight + math.sin(t * 4) * 0.3, 0)
		flag.Rotation = math.sin(t * 3) * 3
	end)
	task.delay(looks.BannerTime, function()
		TweenService:Create(flag, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.fromScale(0, 0.85),
		}):Play()
		task.delay(0.3, function()
			bob:Disconnect()
			spot:Destroy()
		end)
	end)
end

local function onImpact(data, rack, feel, isOwn: boolean, setTimeScale: (number) -> ())
	local lane: Model = data.Lane
	local isStrike = data.Tier == "Strike" or data.Tier == "PerfectStrike"
	local isPerfect = data.Tier == "PerfectStrike"
	local count = #data.Pins
	local crash = feel.Crash
	local forward = rack.HeadPinCFrame.LookVector
	local headPin = rack.HeadPinCFrame.Position
	local crashPoint = headPin + Vector3.new(0, 1, 0)
	local ringColor = feel.Color

	-- Everyone nearby hears and sees the crash; strikes get the big one
	Sfx.PlayAt(
		if isStrike then "StrikeCrash" else "PinHit",
		lane.PinSpot,
		(if isStrike then 0.95 else 1.1) * (1.08 - feel.Level * 0.025),
		math.clamp(0.5 + count * 0.07, 0.5, 1.3) * math.min(crash, 1.6)
	)
	ThrowFx.Shockwave(headPin + forward * 2 + Vector3.new(0, 0.1, 0), ringColor, (6 + 5 * crash) * PIN_SCALE)
	ThrowFx.Burst(crashPoint, ringColor, 25 + 20 * crash, 35 * crash * PIN_SCALE, 0.9 * math.sqrt(crash))
	local mega = feel.Level >= THROW.MegaCrashFromLevel
	if mega then
		-- The strongest balls: a second, bigger shockwave, a white burst and a deep extra boom
		task.delay(0.07, function()
			ThrowFx.Shockwave(headPin + forward * 2 + Vector3.new(0, 0.2, 0), WHITE, (10 + 7 * crash) * PIN_SCALE, 0.45)
		end)
		ThrowFx.Burst(crashPoint + Vector3.new(0, 2, 0), WHITE, 15 * crash, 50 * crash * PIN_SCALE, 1.6)
		Sfx.PlayAt("StrikeCrash", lane.PinSpot, 0.55, 1.2)
	end
	local overcharged = data.Overcharge == "Blast"
	if overcharged then
		-- The gamble paid off: an extra red blast wave and a deep boom on top of the strike
		Sfx.PlayAt("OverchargeBlast", lane.PinSpot, 1, 1.2)
		task.delay(0.05, function()
			ThrowFx.Shockwave(headPin + forward * 2 + Vector3.new(0, 0.3, 0), RED, (14 + 8 * crash) * PIN_SCALE, 0.5)
		end)
		ThrowFx.Burst(crashPoint + Vector3.new(0, 1.5, 0), RED, 40 * crash, 60 * crash * PIN_SCALE, 1.8)
	end
	if isStrike then
		LaneFx.Confetti(lane, JUICE.ConfettiAmount)
	end
	if isPerfect then
		LaneFx.Fireworks(lane, JUICE.PerfectFireworks)
	end
	-- The thrower's looks (Config.Cosmetics): a pin blast on every hit, a banner over the pins on a strike
	local thrower = Players:GetPlayerByUserId(data.UserId)
	local blast = thrower and Cosmetics.Worn(thrower, "PinFx")
	if blast then
		pinBlast(blast, crashPoint, headPin + forward * 2, if isStrike then 1.4 else 0.8)
	end
	local banner = thrower and Cosmetics.Worn(thrower, "Banner")
	if banner and isStrike then
		strikeBanner(lane, banner, headPin)
	end
	local golden = data.Golden
	if golden and golden.Hit then
		local pin = rack.Pins[golden.Pin]
		LaneFx.GoldenBurst(lane, if pin and pin.PrimaryPart then pin.PrimaryPart.Position else crashPoint)
		if isOwn then
			UiFx.Flash(Config.GoldenPin.Color, 0.7, 0.6)
			CameraShake.Add(0.6)
		end
	end
	if not isOwn then
		return
	end

	if overcharged then
		UiFx.Flash(RED, 0.5, 0.35)
		CameraShake.Add(0.8)
	end
	ThrowFx.Punch(THROW.CameraPunch * crash)
	ThrowFx.Shake(THROW.CameraShakeStrength * crash * (0.4 + count * 0.06), THROW.CameraShakeTime)
	UiFx.Flash(WHITE, 0.08 + count * 0.012, 0.12)
	if mega then
		UiFx.Flash(ringColor, 0.25 + (feel.Level - THROW.MegaCrashFromLevel) * 0.06, 0.25)
	end
	if isStrike then
		-- The pins burst at full speed first (instant payoff), then slow motion kicks in mid-air
		task.delay(feel.HitStop + THROW.SlowMotionStartsAfter, slowMotion, rack, setTimeScale)
		local streak = data.Streak or 1
		local special = table.find(THROW.SpecialStreaks, streak) ~= nil
		local grow = 1 + THROW.StreakGrowth * (math.min(math.max(streak, 1), THROW.StreakGrowthStopsAt) - 1)
		UiFx.Flash(
			if special or isPerfect then GOLD else WHITE,
			if special then 0.55 else 0.3,
			if special then 0.4 else 0.2
		)
		ThrowFx.Shake(THROW.CameraShakeStrength * 0.5 * grow, THROW.CameraShakeTime)
		Sfx.Play("Cheer", 1, if isPerfect or special then 1.4 else 1)
		if isPerfect then
			Sfx.Play("PerfectSting")
		end
	end
end

-- Effects for the ball traits that kicked in, the moment the ball reaches the pins
-- (Curve and the Gem Hunter trail play during the roll). Streak Saver and the gem payout are HUD effects.
local function playTraits(data, position: Vector3, isOwn: boolean)
	local lane: Model = data.Lane
	for _, traitId in data.Traits or {} do
		if traitId == "Blast" then
			TraitFx.Blast(lane, position, isOwn)
		elseif traitId == "Heavy" then
			TraitFx.Heavy(lane, position, isOwn)
		elseif traitId == "StreakSaver" and isOwn then
			TraitFx.StreakSaved()
		elseif traitId == "GemHunter" and isOwn then
			local reward = data.Reward or {}
			TraitFx.GemPayout(
				lane,
				if Config.Gems.Enabled then Config.Rewards.PerfectGemAmount else reward.HunterCoins or 0
			)
		end
	end
end

local function playThrow(data)
	local lane: Model = data.Lane
	local rack = racks[lane]
	if not rack then
		return
	end
	local isOwn = data.UserId == Players.LocalPlayer.UserId
	busy[lane] = true
	rack.Throw = (rack.Throw or 0) + 1
	local run = rack.Throw

	local ballStart = lane.BallStart :: BasePart
	local pinSpot = lane.PinSpot :: BasePart
	local forward = ballStart.CFrame.LookVector
	local right = ballStart.CFrame.RightVector
	local spinAxis = Vector3.new(0, 1, 0):Cross(forward).Unit
	local ball = makeBall(data.BallId, ThrowRules.Level(data.PowerLevel))
	local radius = ball.Size.X / 2
	-- Bigger balls sit higher, so they still roll on the lane
	local lift = Vector3.new(0, radius - LANE.BallDiameter / 2, 0)
	local touchDistance = radius + LANE.PinWidth * rack.Scale / 2 + 0.3

	local headDistance = (pinSpot.Position - ballStart.Position):Dot(forward)
	local endDistance = headDistance + LANE.PinSpacing * 3 + 8 -- past the last row, into the pit
	local speed = headDistance / data.RollTime

	local falls = {}
	for _, index in data.Pins do
		falls[index] = true
	end

	local ballInfo = Balls.Get(data.BallId) or Config.Balls[1]
	local feel = throwFeel(data, ballInfo)
	local isStrike = data.Tier == "Strike" or data.Tier == "PerfectStrike"
	local coins = if data.Reward then data.Reward.Coins else 0
	local coinsEach = if #data.Pins > 0 then math.max(1, math.floor(coins / #data.Pins + 0.5)) else 0

	-- The ball leaves from the thrower's hand and drops onto the lane over the first few studs
	local thrower = Players:GetPlayerByUserId(data.UserId)
	local character = thrower and thrower.Character
	if character and not isOwn then
		ThrowPose.Release(character, feel.Level) -- your own swing already started when you let go
	end
	local heldBall = character and character:FindFirstChild("HeldBall", true) :: BasePart?
	local handOffset = Vector3.zero
	if heldBall then
		handOffset = heldBall.Position - (ballStart.Position + lift)
		if handOffset.Magnitude > 25 then
			handOffset = Vector3.zero -- standing somewhere odd: just start on the lane
		end
	end

	ball.CFrame = ballStart.CFrame + lift + handOffset
	ball.Parent = lane
	-- One trail per ball: the ball's own, sized by its rarity and Power Level (Config.BallVfx.TrailTiers). A worn
	-- cosmetic trail (Config.Cosmetics; a VIP wearing none gets the VIP gold) recolours it, so everyone sees it
	local look = thrower and Cosmetics.Worn(thrower, "Trail")
	local fx = BallFx.Attach(ball, data.BallId, "Lane", forward, {
		Level = feel.Level,
		TrailColors = look and look.Colors,
		TrailStyle = look and look.Style,
		TrailTier = look and look.Tier,
	})
	local lights = LaneFx.FollowLights(lane, if look then look.Colors[#look.Colors] else ballInfo.Trail)
	BallFx.Dim(ball)
	local fired = data.Traits or {}
	local curveTrail = if table.find(fired, "Curve") then TraitFx.CurveTrail(lane, headDistance) else nil
	local gemTrail = if table.find(fired, "GemHunter") then TraitFx.GemTrail(lane) else nil
	-- Stronger balls sound heavier (deeper)
	local heavy = 1.1 - feel.Level * LEVEL_FX.LevelSoundDrop
	local rollSound =
		Sfx.PlayAt("Roll", ball, (0.9 + feel.Strength * 0.2) * heavy, 0.8 + feel.Level * LEVEL_FX.LevelSoundLoud)
	-- The release: a burst in the level's colour from the hand (and a ring from ReleaseRingFromLevel)
	local levelColor = if feel.Level >= THROW.RainbowFromLevel then PINK else ballInfo.Trail or ballInfo.Color
	ThrowFx.Burst(
		ball.Position,
		levelColor,
		LEVEL_FX.ReleaseBurst * feel.Level,
		10 + feel.Level * 2,
		0.4 + ball.Size.X * 0.15
	)
	if feel.Level >= LEVEL_FX.ReleaseRingFromLevel then
		ThrowFx.Shockwave(ballStart.Position + Vector3.new(0, 0.1, 0), levelColor, (3 + feel.Level) * PIN_SCALE, 0.35)
	end
	if isOwn then
		Sfx.Play("Throw", (1 + (feel.Strength - 1) * 0.3) * heavy)
		if data.Perfect then
			Sfx.Play("PerfectSting")
			ThrowFx.Burst(ball.Position, feel.Color, 30, 18 * PIN_SCALE, 0.7)
		end
		ThrowFx.Punch(0.8 * feel.Strength * math.sqrt(feel.Crash))
	end

	local timeScale = 1
	local function setTimeScale(scale: number)
		timeScale = scale
	end

	-- Sends one pin flying, with its number pop, sound and sparks
	local function launch(index: number, from: Vector3, scale: number)
		local pin = rack.Pins[index]
		local flew = rack:Knock(index, from, feel.Force * scale)
		if not flew or not pin then
			return
		end
		local body = pin.PrimaryPart :: BasePart
		local spot = body.Position + Vector3.new(0, 1, 0)
		ThrowFx.PinHitSound(body, flew, timeScale < 1)
		ThrowFx.Burst(spot, feel.Color, 10 + 6 * flew, 22 * flew * PIN_SCALE, 0.5 * feel.Crash, timeScale)
		if isOwn then
			if coinsEach > 0 then
				local size = THROW.NumberPopSize * feel.PopScale * (0.9 + math.min(flew, 2) * 0.1)
				-- The owner's tones: gold on a PERFECT, pink on a strike, white otherwise
				local tone = if data.Perfect then "gold" elseif isStrike then "pink" else "white"
				ThrowFx.NumberPop(spot, coinsEach, size, tone)
			end
			ThrowFx.Shake(THROW.CameraShakeStrength * 0.25 * feel.Crash, THROW.CameraShakeTime * 0.6)
		end
	end

	local travelled = 0
	local x = 0
	local hit = false
	local traitsPlayed = false
	local hooked = false
	local position = ballStart.Position

	-- The crash: effects, then every pin that should fall takes off within PinSpreadTime,
	-- a quick ripple from front to back, so no pin is left hanging
	local frozen = false
	local function impact()
		hit = true
		if data.Gutter then
			return -- an overcooked ball rolls past the pins in the gutter: no crash
		end
		onImpact(data, rack, feel, isOwn, setTimeScale)
		if isOwn and coins > 0 then
			local polish = Balls.DecodePolish(Players.LocalPlayer:GetAttribute("Polish"))[ballInfo.Id]
			local multiplier = math.floor(Balls.Multiplier(ballInfo, Balls.PolishLevel(polish)) * 100 + 0.5) / 100
			-- The owner's variants: pink for a strike streak, gold for a strike or PERFECT, cyan otherwise.
			-- The chip says the streak, else the ball's multiplier ("x2.5 RUBY"), else BONUS on gold.
			local strikeRun = data.Streak or 0
			local variant = if isStrike and strikeRun >= 2
				then "streak"
				elseif isStrike or data.Perfect then "bonus"
				else "coin"
			local tag = if variant == "streak"
				then "STREAK \u{00D7}" .. strikeRun
				elseif multiplier > 1 then ("x%g %s"):format(multiplier, string.upper(ballInfo.Name))
				elseif variant == "bonus" then "BONUS"
				else nil
			task.delay(feel.HitStop + 0.1, function()
				ThrowFx.PayoutPop(coins, variant, tag)
			end)
		end
		-- Hit-stop: a PERFECT freezes everything for a split second before the explosion
		local stop = feel.HitStop
		if stop > 0 then
			frozen = true
			setTimeScale(0)
			task.delay(stop, function()
				frozen = false
				setTimeScale(1)
			end)
		end
		local hitPoint = rack.HeadPinCFrame.Position - forward * 1.5 + Vector3.new(0, 0.5, 0)
		local farthest = LANE.PinSpacing * 3.5
		for index in falls do
			local pin = rack.Pins[index]
			local body = pin and pin.PrimaryPart
			if body then
				local distance = (body.Position - hitPoint).Magnitude
				task.delay(stop + THROW.PinSpreadTime * math.clamp(distance / farthest, 0, 1), function()
					if run == rack.Throw then
						launch(index, hitPoint, 1)
					end
				end)
			end
		end
	end

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		travelled += speed * dt * timeScale * (if hit then 0.6 else 1) -- the pins slow it down a bit
		local progress = math.min(travelled / headDistance, 1)

		if data.CurveFromX then
			-- Curve ball: heads out to the side, then hooks back into the pocket
			local hook = progress ^ 3
			x = data.CurveFromX * progress * (1 - hook) + data.HitX * hook
			if not hooked and progress >= 0.55 and curveTrail then
				hooked = true
				TraitFx.Hooked(lane, ball, isOwn)
			end
		elseif data.Gutter then
			-- Overcooked: it veers off early and drops into the gutter
			local veer = math.min(1, progress * 1.8)
			x = data.HitX * veer * veer * (3 - 2 * veer)
		else
			x = data.HitX * progress
		end

		position = ballStart.Position + lift + forward * travelled + right * x
		if data.Gutter then
			local over = math.clamp((math.abs(x) - LANE.LaneHalfWidth + radius) / radius, 0, 1)
			position -= Vector3.new(0, LANE.GutterDepth * over, 0)
		end
		if travelled < THROW.HandBlendDistance then
			local s = travelled / THROW.HandBlendDistance
			position += handOffset * (1 - s * s * (3 - 2 * s))
		end
		ball.CFrame = CFrame.new(position) * CFrame.fromAxisAngle(spinAxis, travelled / radius)
		fx:Move(position)
		lights.Update(position)
		if curveTrail then
			curveTrail.Move(position)
		end
		if gemTrail then
			gemTrail.Move(position)
		end

		-- Pins the ball rolls into: the ones the server knocked down fly, the others just wobble
		if run == rack.Throw and not frozen then
			for index, pin in rack.Pins do
				local body = pin.PrimaryPart
				if body and body.Anchored then
					local offset = body.Position - position
					if Vector2.new(offset.X, offset.Z).Magnitude < touchDistance then
						if falls[index] then
							if not hit then
								impact()
							end
							launch(index, position, 1)
						else
							rack:Wobble(index)
						end
					end
				end
			end
			if not hit and travelled >= headDistance then
				impact()
			end
		end

		if not traitsPlayed and (hit or travelled >= headDistance) then
			traitsPlayed = true
			if curveTrail then
				curveTrail.Stop()
			end
			if gemTrail then
				gemTrail.Stop()
			end
			playTraits(data, position, isOwn)
		end

		if travelled >= headDistance and rollSound then
			Sfx.FadeOut(rollSound, 0.3)
			rollSound = nil
		end
		if travelled >= endDistance then
			connection:Disconnect()
			ball:Destroy()
			lights.Destroy()
		end
	end)

	-- The thrower's camera follows the ball down the lane, stopping short of the pins,
	-- and punches and shakes on impact
	local camera = Workspace.CurrentCamera
	local cameraConnection
	if isOwn then
		camera.CameraType = Enum.CameraType.Scriptable
		local smooth = camera.CFrame
		cameraConnection = RunService.RenderStepped:Connect(function(dt)
			if LaneVisuals.CameraHeld then
				return -- the Studio-only Day 1 video intro has the camera (its pin camera)
			end
			local camTravel = math.min(travelled, headDistance - CAMERA.StopBeforePins)
			local base = ballStart.Position + forward * camTravel + right * (x * 0.5)
			local target = CFrame.lookAt(
				base - forward * CAMERA.FollowDistance + Vector3.new(0, CAMERA.FollowHeight, 0),
				base + forward * CAMERA.LookAhead
			)
			smooth = smooth:Lerp(target, math.min(1, dt * CAMERA.Smoothness))
			camera.CFrame = smooth * CameraShake.Offset(dt) * ThrowFx.CameraOffset(dt)
			camera.FieldOfView = normalFov - ThrowFx.FovOffset()
		end)
	end

	task.delay(data.RollTime + (data.ResetDelay or LANE.PinResetDelay), function()
		if cameraConnection then
			cameraConnection:Disconnect()
			camera.CameraType = Enum.CameraType.Custom
			camera.FieldOfView = normalFov
		end
		if run ~= rack.Throw then
			return
		end
		busy[lane] = false
		local modifier = Modifiers.Current()
		rack.Scale = modifier and modifier.PinScale or 1
		rack.Golden = lane:GetAttribute("GoldenPin") or 0
		rack:Reset()
	end)
end

-- Invisible walls around each pin deck (on this screen only), so flying pins bounce around the deck
-- instead of landing in the next lane
local function buildPinFence(lane: Model)
	local pinSpot = lane.PinSpot :: BasePart
	local head = pinSpot.CFrame * CFrame.new(0, -pinSpot.Size.Y / 2, 0)
	local folder = Instance.new("Folder")
	folder.Name = "PinFence"
	local function wall(offset: Vector3, size: Vector3)
		local part = Instance.new("Part")
		part.Name = "Wall"
		part.Anchored = true
		part.Transparency = 1
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Size = size
		part.CFrame = head * CFrame.new(offset)
		part.Parent = folder
	end
	local side = LANE.LaneHalfWidth + 2.3
	local back = LANE.PinSpacing * 3 + 12
	-- (the lane's forward is -Z in the head pin's frame)
	for _, x in { -side, side } do
		wall(Vector3.new(x, 40, -back / 2 + 3), Vector3.new(1, 80, back + 6))
	end
	wall(Vector3.new(0, 40, -back), Vector3.new(side * 2 + 1, 80, 1))
	folder.Parent = lane
end

-- The lane scoreboard's STREAK and RANK screens show the lane owner's numbers (Studio-built labels).
-- Only updates when the owner or their numbers change.
local function watchBoard(lane: Model)
	local board = lane:FindFirstChild("Scoreboard")
	local streakLabel = board and board:FindFirstChild("StreakValue", true) :: TextLabel?
	local rankLabel = board and board:FindFirstChild("RankValue", true) :: TextLabel?
	if not streakLabel or not rankLabel then
		return
	end
	local connections = {}
	local function refresh(owner: Player?)
		if not owner then
			streakLabel.Text = "-"
			rankLabel.Text = "-"
			rankLabel.TextColor3 = Color3.new(1, 1, 1)
			return
		end
		local streak = owner:GetAttribute("Streak") or 0
		local tier = Progression.GetStreakTier(streak)
		streakLabel.Text = tostring(streak)
		streakLabel.TextColor3 = if tier and streak >= 2 then tier.Color else Color3.new(1, 1, 1)
		local rank = Progression.GetRank(owner:GetAttribute("Rank") or 1)
		rankLabel.Text = string.upper(rank.Name)
		rankLabel.TextColor3 = rank.Color
	end
	local function onOwner()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
		local owner = Players:GetPlayerByUserId(lane:GetAttribute("OwnerId") or 0)
		if owner then
			for _, key in { "Streak", "Rank" } do
				table.insert(
					connections,
					owner:GetAttributeChangedSignal(key):Connect(function()
						refresh(owner)
					end)
				)
			end
		end
		refresh(owner)
	end
	lane:GetAttributeChangedSignal("OwnerId"):Connect(onOwner)
	onOwner()
end

function LaneVisuals:Start()
	for _, lane in LaneUtil.GetLanes() do
		watchBoard(lane)
		buildPinFence(lane)
	end

	for _, lane in LaneUtil.GetLanes() do
		local pinSpot = lane.PinSpot :: BasePart
		racks[lane] = PinRack.new(pinSpot.CFrame * CFrame.new(0, -pinSpot.Size.Y / 2, 0), lane)
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("ThrowResult").OnClientEvent:Connect(playThrow)

	-- Golden Pins and the lane modifier change the standing rack
	for lane in racks do
		lane:GetAttributeChangedSignal("GoldenPin"):Connect(function()
			refreshRack(lane)
		end)
		refreshRack(lane)
	end
	Workspace:GetAttributeChangedSignal("LaneModifier"):Connect(function()
		for lane in racks do
			refreshRack(lane)
		end
	end)
end

return LaneVisuals
