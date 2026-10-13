-- Plays every throw on this player's screen: the ball roll and the pins the server says fall.
-- Pins live only on this client, so they never lag and always match the server's result.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PinRack = require(Shared.Modules.PinRack)
local LaneUtil = require(Shared.Modules.LaneUtil)

local LANE = Config.Lane
local CAMERA = Config.Camera

local LaneVisuals = {}

local racks: { [Model]: any } = {}

local function makeBall(): Part
	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * LANE.BallDiameter
	ball.Color = Color3.fromRGB(0, 220, 255)
	ball.Material = Enum.Material.Neon
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	return ball
end

local function playThrow(data)
	local lane: Model = data.Lane
	local rack = racks[lane]
	if not rack then
		return
	end

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
	local offsets = PinRack.Offsets()
	for _, index in data.Pins do
		table.insert(pending, { Index = index, Distance = headDistance - offsets[index].Z - 0.8 })
	end

	-- Gutter balls slide off the lane partway down
	local gutterAt = if data.Gutter then 0.3 + math.random() * 0.3 else nil

	local ball = makeBall()
	ball.CFrame = ballStart.CFrame
	ball.Parent = lane

	-- The thrower's camera follows the ball down the lane, stopping short of the pins
	local camera = Workspace.CurrentCamera
	local follow = data.UserId == Players.LocalPlayer.UserId
	if follow then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local travelled = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		travelled += speed * dt
		local progress = math.min(travelled / headDistance, 1)

		local x, drop
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

		if follow then
			local camTravel = math.min(travelled, headDistance - CAMERA.StopBeforePins)
			local base = ballStart.Position + forward * camTravel + right * (x * 0.5)
			local target = CFrame.lookAt(
				base - forward * CAMERA.FollowDistance + Vector3.new(0, CAMERA.FollowHeight, 0),
				base + forward * CAMERA.LookAhead
			)
			camera.CFrame = camera.CFrame:Lerp(target, math.min(1, dt * CAMERA.Smoothness))
		end

		for i = #pending, 1, -1 do
			if travelled >= pending[i].Distance then
				rack:Knock(pending[i].Index, position, forward)
				table.remove(pending, i)
			end
		end

		if travelled >= endDistance then
			connection:Disconnect()
			ball:Destroy()
		end
	end)

	task.delay(data.RollTime + LANE.PinResetDelay, function()
		rack:Reset()
		if follow then
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
