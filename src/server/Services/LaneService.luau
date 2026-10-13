-- Milestone 1: sets up the pins on each lane and adds a temporary "Roll test ball" button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PinRack = require(Shared.Modules.PinRack)

local LANE = Config.Lane

local LaneService = {}

local function setStatus(lane: Model, text: string)
	local board = lane:FindFirstChild("Scoreboard")
	local label = board and board:FindFirstChild("Status", true)
	if label then
		label.Text = text
	end
end

local function makeBall(): Part
	local ball = Instance.new("Part")
	ball.Name = "Ball"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * LANE.BallDiameter
	ball.Color = Color3.fromRGB(0, 220, 255)
	ball.Material = Enum.Material.Neon
	ball.CustomPhysicalProperties = PhysicalProperties.new(LANE.BallDensity, 0.2, 0.2)
	ball.TopSurface = Enum.SurfaceType.Smooth
	ball.BottomSurface = Enum.SurfaceType.Smooth
	return ball
end

local function rollTestBall(lane: Model, rack)
	local ballStart = lane.BallStart :: BasePart
	local pinSpot = lane.PinSpot :: BasePart
	local laneDir = ballStart.CFrame.LookVector
	local drift = (math.random() * 2 - 1) * Config.TestRoll.MaxSideDrift

	local ball = makeBall()
	ball.CFrame = ballStart.CFrame * CFrame.new(drift, 0, 0)
	ball.Parent = lane
	ball:SetNetworkOwner(nil)

	local velocity = laneDir * Config.TestRoll.Speed
	ball.AssemblyLinearVelocity = velocity
	-- Spin it so it rolls instead of sliding
	ball.AssemblyAngularVelocity = Vector3.yAxis:Cross(velocity) / (LANE.BallDiameter / 2)

	setStatus(lane, "ROLLING...")

	-- Wait until the ball reaches the pins (or gets lost), then let the pins settle.
	local started = os.clock()
	local pinDistance = (pinSpot.Position - ballStart.Position):Dot(laneDir)
	while os.clock() - started < LANE.MaxRollTime do
		if not ball.Parent then
			break
		end
		local travelled = (ball.Position - ballStart.Position):Dot(laneDir)
		if travelled >= pinDistance or ball.Position.Y < pinSpot.Position.Y - 10 then
			break
		end
		task.wait(0.05)
	end
	task.wait(LANE.SettleTime)

	local knocked = rack:CountFallen()
	local label = if knocked == 10
		then "STRIKE!"
		elseif knocked == 0 then "GUTTER"
		else knocked .. (knocked == 1 and " PIN" or " PINS")
	setStatus(lane, label)
	print(("[LaneService] %s knocked %d pins"):format(lane.Name, knocked))

	ball:Destroy()
	rack:Reset()
end

local function setupLane(lane: Model)
	local pinSpot = lane:WaitForChild("PinSpot") :: BasePart
	local rack = PinRack.new(pinSpot.CFrame * CFrame.new(0, -pinSpot.Size.Y / 2, 0), lane)

	local button = lane:WaitForChild("TestButton") :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Roll test ball"
	prompt.ObjectText = "Milestone 1 test"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = button

	local busy = false
	prompt.Triggered:Connect(function()
		if busy then
			return
		end
		busy = true
		prompt.Enabled = false
		local ok, err = pcall(rollTestBall, lane, rack)
		if not ok then
			warn("[LaneService] Test roll failed:", err)
			rack:Reset()
		end
		prompt.Enabled = true
		busy = false
	end)

	setStatus(lane, "READY")
end

function LaneService:Start()
	local alley = Workspace:WaitForChild("NeonAlley")
	for _, lane in alley:GetChildren() do
		if lane:IsA("Model") and lane:FindFirstChild("PinSpot") then
			task.spawn(setupLane, lane)
		end
	end
end

return LaneService
