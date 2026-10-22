-- Small helpers both server and client use to find lanes.
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)

local LaneUtil = {}

function LaneUtil.GetLanes(): { Model }
	local lanes = {}
	for _, folderName in Config.Zones.LaneFolders do
		local alley = Workspace:WaitForChild(folderName)
		local found = {}
		for _, lane in alley:GetChildren() do
			if lane:IsA("Model") and lane:FindFirstChild("PinSpot") and lane:FindFirstChild("BallStart") then
				table.insert(found, lane)
			end
		end
		-- Lane1, Lane2, ... in number order, zone by zone
		table.sort(found, function(a, b)
			return (tonumber(a.Name:match("%d+")) or 0) < (tonumber(b.Name:match("%d+")) or 0)
		end)
		table.move(found, 1, #found, #lanes + 1, lanes)
	end
	return lanes
end

-- The lane this player owns (set by LaneService on the server), if any. A player owns their Back Alley lane and,
-- while inside a later zone, the lane they claimed there: that one (the later zone) wins.
function LaneUtil.GetOwnedLane(userId: number): Model?
	local owned = nil
	for _, lane in LaneUtil.GetLanes() do
		if lane:GetAttribute("OwnerId") == userId then
			owned = lane
		end
	end
	return owned
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

-- The zone number a lane belongs to (its model's place in Config.Zones.LaneFolders), 1 if unknown
function LaneUtil.ZoneOf(lane: Instance): number
	local node: Instance? = lane
	while node do
		local index = table.find(Config.Zones.LaneFolders, node.Name)
		if index and node.Parent == Workspace then
			return index
		end
		node = node.Parent
	end
	return 1
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
