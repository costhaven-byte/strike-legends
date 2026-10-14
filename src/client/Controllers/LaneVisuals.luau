-- Plays every throw on this player's screen: the ball roll, the pins the server says fall,
-- and the effects (sounds, lane lights, sparks, confetti, plus slow-motion and camera shake on your own throws).
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
local Modules = script.Parent.Parent:WaitForChild("Modules")
local CameraShake = require(Modules.CameraShake)
local LaneFx = require(Modules.LaneFx)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local LANE = Config.Lane
local CAMERA = Config.Camera
local JUICE = Config.Juice

local normalGravity = Workspace.Gravity
local normalFov = Workspace.CurrentCamera.FieldOfView

local LaneVisuals = {}

local racks: { [Model]: any } = {}

-- The thrower's equipped ball, with its colour, material, trail and glow
-- The trail hangs off the spin axis so it stays steady while the ball rolls.
local function makeBall(ballId: string?, spinAxis: Vector3): Part
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

	local reach = LANE.BallDiameter * 0.35
	local top = Instance.new("Attachment")
	top.Position = spinAxis * reach
	top.Parent = ball
	local bottom = Instance.new("Attachment")
	bottom.Position = -spinAxis * reach
	bottom.Parent = ball

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = ColorSequence.new(info.Trail)
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.LightEmission = 0.25 -- low, so bright lanes don't wash every trail out to white
	trail.Lifetime = 0.35
	trail.FaceCamera = true
	trail.Parent = ball

	local glow = Instance.new("PointLight")
	glow.Color = info.Trail
	glow.Range = 8
	glow.Brightness = 2
	glow.Parent = ball
	return ball
end

-- Strike slow-motion: the ball, flying pins and gravity all run at a fraction of normal speed.
-- (Roblox can't slow down time itself, so we slow down everything this player sees in the alley.)
local function slowMotion(rack, setTimeScale: (number) -> ())
	local scale = JUICE.SlowMoScale
	local camera = Workspace.CurrentCamera
	setTimeScale(scale)
	rack:ScaleMotion(scale)
	Workspace.Gravity = normalGravity * scale * scale
	TweenService:Create(camera, TweenInfo.new(0.1), { FieldOfView = JUICE.SlowMoFov }):Play()

	task.delay(JUICE.SlowMoTime, function()
		setTimeScale(1)
		rack:ScaleMotion(1 / scale)
		Workspace.Gravity = normalGravity
		TweenService:Create(camera, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { FieldOfView = normalFov }):Play()
	end)
end

-- Everything that happens the moment the ball reaches the pins
local function onImpact(data, rack, position: Vector3, isOwn: boolean, setTimeScale: (number) -> ())
	local lane: Model = data.Lane
	local isStrike = data.Tier == "Strike" or data.Tier == "PerfectStrike"
	local isPerfect = data.Tier == "PerfectStrike"
	local count = #data.Pins

	-- Everyone nearby hears the crash; strikes get the big one
	Sfx.PlayAt(if isStrike then "StrikeCrash" else "PinHit", lane.PinSpot, 0.95 + math.random() * 0.1)
	if isStrike then
		LaneFx.Confetti(lane, JUICE.ConfettiAmount)
	end
	if isPerfect then
		LaneFx.Fireworks(lane, JUICE.PerfectFireworks)
	end
	if not isOwn then
		return
	end

	CameraShake.Add(count * JUICE.ShakePerPin + (if isStrike then JUICE.ShakeStrikeBonus else 0))
	LaneFx.Sparks(position, count * 4)
	if isStrike then
		slowMotion(rack, setTimeScale)
		UiFx.Flash(if isPerfect then Color3.fromRGB(255, 230, 120) else nil, 0.55, 0.4)
		Sfx.Play("Cheer", 1, if isPerfect then 1.4 else 1)
		if isPerfect then
			Sfx.Play("PerfectSting")
		end
	end

	-- Coins pop out of each pin that went down
	local coins = if data.Reward then data.Reward.Coins else 0
	if coins > 0 and count > 0 then
		local each = math.max(1, math.floor(coins / count + 0.5))
		local offsets = PinRack.Offsets()
		for i, index in data.Pins do
			local spot = rack.HeadPinCFrame * CFrame.new(offsets[index] + Vector3.new(0, LANE.PinHeight + 0.5, 0))
			task.delay(i * 0.03, LaneFx.Number, spot.Position, "+" .. each, Color3.fromRGB(255, 200, 40))
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

	local ballStart = lane.BallStart :: BasePart
	local pinSpot = lane.PinSpot :: BasePart
	local forward = ballStart.CFrame.LookVector
	local right = ballStart.CFrame.RightVector
	local spinAxis = Vector3.new(0, 1, 0):Cross(forward).Unit
	local radius = LANE.BallDiameter / 2

	local headDistance = (pinSpot.Position - ballStart.Position):Dot(forward)
	local endDistance = headDistance + LANE.PinSpacing * 3 + 8 -- past the last row, into the pit
	local speed = headDistance / data.RollTime

	-- When (how far down the lane) each falling pin gets hit
	local pending = {}
	local firstHit = math.huge
	local offsets = PinRack.Offsets()
	for _, index in data.Pins do
		local distance = headDistance - offsets[index].Z - 0.8
		table.insert(pending, { Index = index, Distance = distance })
		firstHit = math.min(firstHit, distance)
	end

	-- Gutter balls slide off the lane partway down
	local gutterAt = if data.Gutter then 0.3 + math.random() * 0.3 else nil

	local ball = makeBall(data.BallId, spinAxis)
	ball.CFrame = ballStart.CFrame
	ball.Parent = lane
	local ballInfo = Balls.Get(data.BallId) or Config.Balls[1]
	local lights = LaneFx.FollowLights(lane, ballInfo.Trail)
	local rollSound = Sfx.PlayAt("Roll", ball, 1.1 + data.Power * 0.2)
	if isOwn then
		Sfx.Play("Throw", 0.9 + data.Power * 0.3)
	end

	local timeScale = 1
	local function setTimeScale(scale: number)
		timeScale = scale
	end

	local travelled = 0
	local x = 0
	local hit = false
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		travelled += speed * dt * timeScale
		local progress = math.min(travelled / headDistance, 1)

		local drop
		if gutterAt then
			local t = math.min(progress / gutterAt, 1)
			x = data.HitX * t * t
			drop = if t >= 1 then LANE.GutterDepth else 0
		else
			x = data.HitX * progress ^ 1.6 -- slight curve toward the aim point
			drop = 0
		end

		local position = ballStart.Position + forward * travelled + right * x - Vector3.new(0, drop, 0)
		ball.CFrame = CFrame.new(position) * CFrame.fromAxisAngle(spinAxis, travelled / radius)
		lights.Update(position)

		if not hit and travelled >= firstHit then
			hit = true
			onImpact(data, rack, position, isOwn, setTimeScale)
		end

		for i = #pending, 1, -1 do
			if travelled >= pending[i].Distance then
				rack:Knock(pending[i].Index, position, forward, timeScale)
				table.remove(pending, i)
			end
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

	-- The thrower's camera follows the ball down the lane, stopping short of the pins, and shakes on impact
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
			camera.CFrame = smooth * CameraShake.Offset(dt)
		end)
	end

	task.delay(data.RollTime + LANE.PinResetDelay, function()
		rack:Reset()
		if cameraConnection then
			cameraConnection:Disconnect()
			camera.CameraType = Enum.CameraType.Custom
		end
	end)
end

function LaneVisuals:Start()
	for _, lane in LaneUtil.GetLanes() do
		local pinSpot = lane.PinSpot :: BasePart
		racks[lane] = PinRack.new(pinSpot.CFrame * CFrame.new(0, -pinSpot.Size.Y / 2, 0), lane)
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	remotes:WaitForChild("ThrowResult").OnClientEvent:Connect(playThrow)
end

return LaneVisuals
