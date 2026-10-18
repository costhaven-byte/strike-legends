-- Plays every throw on this player's screen: the ball roll, the pins the server says fall (the Throw Lab explosion),
-- and the effects (sounds, lane lights, sparks, shockwaves, number pops, plus slow motion, camera punch and shake
-- on your own throws).
-- Pins live only on this client, so they never lag and always match the server's result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PinRack = require(Shared.Modules.PinRack)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Balls = require(Shared.Modules.Balls)
local BallLook = require(Shared.Modules.BallLook)
local Modifiers = require(Shared.Modules.Modifiers)
local Progression = require(Shared.Modules.Progression)
local ThrowRules = require(Shared.Modules.ThrowRules)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local CameraShake = require(Modules.CameraShake)
local LaneFx = require(Modules.LaneFx)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local BallFx = require(Modules.BallFx)
local TraitFx = require(Modules.TraitFx)
local ThrowFx = require(Modules.ThrowFx)

local LANE = Config.Lane
local CAMERA = Config.Camera
local JUICE = Config.Juice
local THROW = Config.Throw
-- Throw Lab distances were tuned on bigger pins; effect sizes scale by this
local PIN_SCALE = LANE.PinSpacing / THROW.LabPinSpacing

local GOLD = Color3.fromRGB(255, 200, 40)
local PINK = Color3.fromRGB(255, 43, 214)
local WHITE = Color3.new(1, 1, 1)

local normalFov = Workspace.CurrentCamera.FieldOfView

local LaneVisuals = {}

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

-- The thrower's equipped ball: its 3D model plus its effects (trail, sparkles, rings) from Config.BallVfx
local function makeBall(ballId: string?): Part
	local info = Balls.Get(ballId) or Config.Balls[1]
	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * LANE.BallDiameter
	ball.Color = info.Color
	ball.Material = info.Material
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	BallLook.Apply(ball, info.Id)
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
	local level = ThrowRules.Level(ballInfo)
	local strength = data.Power or 1
	return {
		Level = level,
		Strength = strength,
		Force = THROW.Levels[level].Force * strength,
		Crash = (1 + THROW.CrashGrowthPerLevel * (level - 1)) * math.sqrt(strength),
		PopScale = 1 + (level - 1) * 0.08,
		Color = if data.Perfect then GOLD else ballInfo.Trail or ballInfo.Color,
	}
end

-- Everything that happens the moment the ball reaches the pins
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
	if isStrike then
		LaneFx.Confetti(lane, JUICE.ConfettiAmount)
	end
	if isPerfect then
		LaneFx.Fireworks(lane, JUICE.PerfectFireworks)
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

	ThrowFx.Punch(THROW.CameraPunch * crash)
	ThrowFx.Shake(THROW.CameraShakeStrength * crash * (0.4 + count * 0.06), THROW.CameraShakeTime)
	UiFx.Flash(WHITE, 0.08 + count * 0.012, 0.12)
	if mega then
		UiFx.Flash(ringColor, 0.25 + (feel.Level - THROW.MegaCrashFromLevel) * 0.06, 0.25)
	end
	if isStrike then
		-- The pins burst at full speed first (instant payoff), then slow motion kicks in mid-air
		task.delay(THROW.SlowMotionStartsAfter, slowMotion, rack, setTimeScale)
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
	local radius = LANE.BallDiameter / 2
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

	local ball = makeBall(data.BallId)
	ball.CFrame = ballStart.CFrame
	ball.Parent = lane
	local fx = BallFx.Attach(ball, data.BallId, "Lane", forward)
	local lights = LaneFx.FollowLights(lane, ballInfo.Trail)
	local fired = data.Traits or {}
	local curveTrail = if table.find(fired, "Curve") then TraitFx.CurveTrail(lane, headDistance) else nil
	local gemTrail = if table.find(fired, "GemHunter") then TraitFx.GemTrail(lane) else nil
	-- Stronger balls sound heavier (deeper)
	local heavy = 1.1 - feel.Level * 0.03
	local rollSound = Sfx.PlayAt("Roll", ball, (0.9 + feel.Strength * 0.2) * heavy, 0.8 + feel.Level * 0.05)
	if isOwn then
		Sfx.Play("Throw", (1 + (feel.Strength - 1) * 0.3) * heavy)
		if data.Perfect then
			Sfx.Play("PerfectSting")
			ThrowFx.Burst(ball.Position, GOLD, 30, 18 * PIN_SCALE, 0.7)
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
				local color = if data.Perfect then GOLD elseif isStrike then PINK else WHITE
				ThrowFx.NumberPop(spot, "+" .. coinsEach, size, color)
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
	local function impact()
		hit = true
		onImpact(data, rack, feel, isOwn, setTimeScale)
		local hitPoint = rack.HeadPinCFrame.Position - forward * 1.5 + Vector3.new(0, 0.5, 0)
		local farthest = LANE.PinSpacing * 3.5
		for index in falls do
			local pin = rack.Pins[index]
			local body = pin and pin.PrimaryPart
			if body then
				local distance = (body.Position - hitPoint).Magnitude
				task.delay(THROW.PinSpreadTime * math.clamp(distance / farthest, 0, 1), function()
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
			if not hooked and progress >= 0.55 then
				hooked = true
				TraitFx.Hooked(lane, ball, isOwn)
			end
		else
			x = data.HitX * progress
		end

		position = ballStart.Position + forward * travelled + right * x
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
		if run == rack.Throw then
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
		wall(Vector3.new(x, 20, -back / 2 + 3), Vector3.new(1, 40, back + 6))
	end
	wall(Vector3.new(0, 20, -back), Vector3.new(side * 2 + 1, 40, 1))
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
