-- Small helpers both server and client use to find lanes.
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Parent.Config)

local LaneUtil = {}

local sharedSpots: { Model }? = nil -- (the shared lane's spots never change once built: found once)

-- (Addendum 4 core loop: only the rooftop's lanes exist for the game; the switched-off zones' lanes are left alone)
function LaneUtil.GetLanes(): { Model }
	local lanes = {}
	-- Addendum 5 A3: one shared lane; every throw spot is a lane model in SharedLane.Spots (built at server start)
	local shared = Config.CoreLoop.SharedLane
	if Config.CoreLoop.Enabled and shared and shared.Enabled then
		if sharedSpots then
			return table.clone(sharedSpots)
		end
		-- Addendum 6 Stage 3: one shared lane per zone (Config.CoreLoop.Zones), zone 1's first, then zone 2's ...
		local zones = Config.CoreLoop.Zones
		local folders = { Config.CoreLoop.Folder }
		if zones and zones.Enabled then
			for zone = 2, #zones.List do
				table.insert(folders, zones.List[zone].Folder)
			end
		end
		for _, folderName in folders do
			local model = Workspace:WaitForChild(folderName):WaitForChild("SharedLane")
			while model:GetAttribute("Ready") ~= true do
				model:GetAttributeChangedSignal("Ready"):Wait()
			end
			local spots = model:WaitForChild("Spots")
			local want = model:GetAttribute("SpotCount") or 0
			while #spots:GetChildren() < want do
				spots.ChildAdded:Wait()
			end
			local found = {}
			for _, lane in spots:GetChildren() do
				if lane:IsA("Model") and lane:FindFirstChild("PinSpot") and lane:FindFirstChild("BallStart") then
					table.insert(found, lane)
				end
			end
			table.sort(found, function(a, b)
				return (tonumber(a.Name:match("%d+")) or 0) < (tonumber(b.Name:match("%d+")) or 0)
			end)
			table.move(found, 1, #found, #lanes + 1, lanes)
		end
		sharedSpots = table.clone(lanes)
		return lanes
	end

	local folders = if Config.CoreLoop.Enabled then { Config.CoreLoop.Folder } else Config.Zones.LaneFolders
	for _, folderName in folders do
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

-- Addendum 5 A3: true while the one shared rooftop lane is on (Config.CoreLoop.SharedLane)
function LaneUtil.Shared(): boolean
	local shared = Config.CoreLoop.SharedLane
	return Config.CoreLoop.Enabled and shared ~= nil and shared.Enabled == true
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
	if LaneUtil.Shared() then
		return lane:GetAttribute("Zone") or 1 -- (Addendum 6 Stage 3: the shared lane's spots know their zone)
	end
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
