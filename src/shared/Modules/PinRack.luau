-- Builds a rack of 10 pins, knocks them flying and resets them. Used by the client for throw visuals.
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
-- Offsets are relative to the head pin; -Z points down the lane.
function PinRack.Offsets(): { Vector3 }
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

-- Puts all 10 pins back, standing and anchored (they only move when knocked).
function PinRack:Reset()
	self.Folder:ClearAllChildren()
	table.clear(self.Pins)

	for index, offset in PinRack.Offsets() do
		local spot = self.HeadPinCFrame * CFrame.new(offset)
		local pin = buildPin(spot)
		pin.Name = "Pin" .. index
		pin.PrimaryPart.Anchored = true
		pin.Parent = self.Folder
		self.Pins[index] = pin
	end
end

-- A short glowing streak behind a flying pin
local function addTrail(body: BasePart)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.3, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.3, 0)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 40, 120))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.LightEmission = 0.6
	trail.Lifetime = 0.25
	trail.FaceCamera = true
	trail.Parent = body
end

-- Sends one pin flying away from the ball's path.
-- timeScale below 1 starts it in slow motion (see ScaleMotion to speed it back up).
function PinRack:Knock(index: number, ballPosition: Vector3, laneDirection: Vector3, timeScale: number?)
	local pin = self.Pins[index]
	local body = pin and pin.PrimaryPart
	if not body or not body.Anchored then
		return
	end

	local away = body.Position - ballPosition
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.01 then
		away = laneDirection
	end
	local direction = (away.Unit + laneDirection * 1.5).Unit
	local speed = LANE.PinKnockSpeedMin + math.random() * (LANE.PinKnockSpeedMax - LANE.PinKnockSpeedMin)

	local scale = timeScale or 1
	addTrail(body)
	body.Anchored = false
	body.AssemblyLinearVelocity = (
		direction * speed + Vector3.new(0, LANE.PinKnockUpSpeed * (0.6 + math.random() * 0.8), 0)
	) * scale
	body.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
		* 30
		* scale
end

-- Speeds up (factor > 1) or slows down (factor < 1) every pin that is already flying
function PinRack:ScaleMotion(factor: number)
	for _, pin in self.Pins do
		local body = pin.PrimaryPart
		if body and not body.Anchored then
			body.AssemblyLinearVelocity *= factor
			body.AssemblyAngularVelocity *= factor
		end
	end
end

function PinRack:Destroy()
	self.Folder:Destroy()
end

return PinRack
