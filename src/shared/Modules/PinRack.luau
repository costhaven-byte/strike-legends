-- Builds a rack of 10 pins, counts knocked-down pins, and resets them.
-- Used by the server for now; the client will reuse it for visuals in Milestone 2.
local Config = require(script.Parent.Parent.Config)

local LANE = Config.Lane

local PinRack = {}
PinRack.__index = PinRack

-- Cylinders in Roblox lie along their X axis; this stands them upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function makePart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Size = size
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CustomPhysicalProperties = PhysicalProperties.new(LANE.PinDensity, 0.4, 0.3)
	return part
end

-- One pin: wide body, thin neck with a neon stripe, round head. Base is the root part.
local function buildPin(baseCFrame: CFrame): Model
	local h, w = LANE.PinHeight, LANE.PinWidth
	local bodyH, neckH = h * 0.58, h * 0.2
	local headD = w * 0.7

	local pin = Instance.new("Model")
	pin.Name = "Pin"

	local white = Color3.fromRGB(245, 245, 250)
	local body = makePart("Body", Enum.PartType.Cylinder, Vector3.new(bodyH, w, w), white, Enum.Material.SmoothPlastic)
	body.CFrame = baseCFrame * CFrame.new(0, bodyH / 2, 0) * UPRIGHT
	body.Parent = pin

	local neck = makePart(
		"Neck",
		Enum.PartType.Cylinder,
		Vector3.new(neckH, w * 0.5, w * 0.5),
		Color3.fromRGB(255, 40, 120),
		Enum.Material.Neon
	)
	neck.CFrame = baseCFrame * CFrame.new(0, bodyH + neckH / 2, 0) * UPRIGHT
	neck.Parent = pin

	local head =
		makePart("Head", Enum.PartType.Ball, Vector3.new(headD, headD, headD), white, Enum.Material.SmoothPlastic)
	head.CFrame = baseCFrame * CFrame.new(0, bodyH + neckH + headD / 2 - 0.05, 0)
	head.Parent = pin

	for _, part in { neck, head } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = body
	end

	pin.PrimaryPart = body
	return pin
end

-- Standard triangle: row 0 has the head pin, row 3 has four pins.
local function pinOffsets(): { Vector3 }
	local offsets = {}
	local rowDepth = LANE.PinSpacing * math.sqrt(3) / 2
	for row = 0, 3 do
		for i = 0, row do
			local x = (i - row / 2) * LANE.PinSpacing
			table.insert(offsets, Vector3.new(x, 0, -row * rowDepth))
		end
	end
	return offsets
end

-- headPinCFrame: on the deck surface, facing down the lane (away from the bowler).
function PinRack.new(headPinCFrame: CFrame, parent: Instance)
	local self = setmetatable({}, PinRack)
	self.HeadPinCFrame = headPinCFrame
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "Pins"
	self.Folder.Parent = parent
	self.Pins = {}
	self:Reset()
	return self
end

function PinRack:Reset()
	self.Folder:ClearAllChildren()
	table.clear(self.Pins)

	for index, offset in pinOffsets() do
		local spot = self.HeadPinCFrame * CFrame.new(offset)
		local pin = buildPin(spot)
		pin.Name = "Pin" .. index
		pin.Parent = self.Folder
		if pin.PrimaryPart:CanSetNetworkOwnership() then
			pin.PrimaryPart:SetNetworkOwner(nil) -- server simulates, so everyone sees the same thing
		end
		table.insert(self.Pins, { Model = pin, Home = spot.Position })
	end
end

function PinRack:IsFallen(entry): boolean
	local body = entry.Model.PrimaryPart
	if not body or not body.Parent then
		return true
	end
	-- Body is rotated 90 degrees, so its RightVector is the pin's "up".
	local upright = body.CFrame.RightVector.Y
	local moved = (Vector3.new(body.Position.X, 0, body.Position.Z) - Vector3.new(entry.Home.X, 0, entry.Home.Z)).Magnitude
	return upright < LANE.FallenUprightThreshold or moved > LANE.FallenMoveDistance
end

function PinRack:CountFallen(): number
	local count = 0
	for _, entry in self.Pins do
		if self:IsFallen(entry) then
			count += 1
		end
	end
	return count
end

function PinRack:Destroy()
	self.Folder:Destroy()
end

return PinRack
