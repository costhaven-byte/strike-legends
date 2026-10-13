-- Small helpers both server and client use to find lanes.
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)

local LaneUtil = {}

function LaneUtil.GetLanes(): { Model }
	local alley = Workspace:WaitForChild("NeonAlley")
	local lanes = {}
	for _, lane in alley:GetChildren() do
		if lane:IsA("Model") and lane:FindFirstChild("PinSpot") and lane:FindFirstChild("BallStart") then
			table.insert(lanes, lane)
		end
	end
	return lanes
end

-- True if the position is standing on (or right next to) this lane's approach.
function LaneUtil.IsInThrowZone(lane: Model, position: Vector3): boolean
	local approach = lane:FindFirstChild("Approach") :: BasePart?
	if not approach then
		return false
	end
	local localPos = approach.CFrame:PointToObjectSpace(position)
	local half = approach.Size / 2
	local margin = Config.Lane.ThrowZoneMargin
	return math.abs(localPos.X) <= half.X + margin
		and math.abs(localPos.Z) <= half.Z + margin
		and localPos.Y > -2
		and localPos.Y < 12
end

function LaneUtil.GetLaneAt(position: Vector3): Model?
	for _, lane in LaneUtil.GetLanes() do
		if LaneUtil.IsInThrowZone(lane, position) then
			return lane
		end
	end
	return nil
end

return LaneUtil
