-- Builds a ball's effects from Config.BallVfx: comet trails, sparkles, orbit rings, glowing disk, halos,
-- floor rings, the floating trait badge and the glow light.
-- Everything hangs off an invisible upright "rig" that follows the ball without spinning,
-- so rings and badges stay steady while the ball rolls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)

local VFX = Config.BallVfx
local IMAGES = VFX.Images
local RING_SEGMENTS = 6
-- Bezier handle length that bends one segment into an arc of a circle (per stud of radius)
local ARC = 4 / 3 * math.tan(math.pi / (2 * RING_SEGMENTS))

local BallFx = {}

export type Mode = "Lane" | "Held" | "Display"

local active = {}

local function colorSequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keys = {}
	for i, color in colors do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keys)
end

local function invisiblePart(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Transparency = 1
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	return part
end

-- A part that rides along with the rig at a fixed offset
local function weldedPart(rig: BasePart, name: string, size: Vector3, offset: CFrame): Part
	local part = invisiblePart(name, size)
	part.CFrame = rig.CFrame * offset
	local weld = Instance.new("Weld")
	weld.Part0 = rig
	weld.Part1 = part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = rig
	return part
end

-- The look for a ball: its Config.BallVfx row, or a plain trail in the ball's Trail colour
local function lookFor(ball)
	return VFX.Balls[ball.Id] or {
		Trails = { { Colors = { ball.Trail }, Width = 0.7, Lifetime = 0.3 } },
	}
end

local function addTrail(rig: BasePart, row, size: number)
	-- Spans the ball top to bottom, so the follow camera sees it streaming down the lane
	local half = row.Width * size / 2
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, half, 0)
	top.Parent = rig
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -half, 0)
	bottom.Parent = rig
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = colorSequence(row.Colors)
	local start = row.Transparency or 0
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, start),
		NumberSequenceKeypoint.new(0.6, start + (1 - start) * 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0.05) -- comet: wide at the ball, a point at the tail
	trail.Lifetime = row.Lifetime
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.MinLength = 0.05
	if row.Texture then
		trail.Texture = IMAGES[row.Texture]
		trail.TextureMode = Enum.TextureMode.Stretch
	end
	trail.Parent = rig
end

local function addParticles(rig: BasePart, row, size: number, rateScale: number)
	-- Emitters spawn on the surface of their part, so each gets its own sphere of the right radius
	local radius = (row.Radius or 0.5) * size
	local holder = weldedPart(rig, "Particles", Vector3.one * radius * 2, CFrame.identity)
	holder.Shape = Enum.PartType.Ball
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = IMAGES[row.Image] or row.Image
	emitter.Color = colorSequence(row.Colors)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	local s = row.Size * size
	emitter.Size = if row.Twinkle
		then NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, s),
			NumberSequenceKeypoint.new(1, 0),
		})
		else NumberSequence.new(s, 0)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.7, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(row.Life[1], row.Life[2])
	emitter.Speed = NumberRange.new(row.Speed[1] * size, row.Speed[2] * size)
	emitter.Acceleration = Vector3.new(0, (row.Rise or 0) * size, 0)
	emitter.Drag = 1
	emitter.Rate = row.Rate * rateScale
	if row.Spin then
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-row.Spin, row.Spin)
	end
	emitter.Parent = holder
	return emitter
end

-- A thin glowing circle made of curved beams; its attachments get turned every frame
local function addRing(rig: BasePart, row, size: number)
	local radius = row.Radius * size
	local ring = { Row = row, Radius = radius, Points = {} }
	for _ = 1, RING_SEGMENTS do
		local attachment = Instance.new("Attachment")
		attachment.Parent = rig
		table.insert(ring.Points, attachment)
	end
	for i = 1, RING_SEGMENTS do
		local beam = Instance.new("Beam")
		beam.Attachment0 = ring.Points[i]
		beam.Attachment1 = ring.Points[i % RING_SEGMENTS + 1]
		beam.CurveSize0 = radius * ARC
		beam.CurveSize1 = radius * ARC -- Roblox measures this one backwards from Attachment1
		beam.Width0 = row.Width * size
		beam.Width1 = row.Width * size
		beam.Color = ColorSequence.new(row.Color)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Transparency = NumberSequence.new(0)
		beam.FaceCamera = true
		beam.Segments = 12
		beam.Parent = rig
	end
	return ring
end

local function placeRing(ring, t: number)
	local row = ring.Row
	local frame = CFrame.Angles(0, t * (row.Spin or 0) * math.pi * 2, 0)
		* CFrame.Angles(math.rad(row.Tilt[1]), 0, math.rad(row.Tilt[2]))
	for i, attachment in ring.Points do
		local angle = (i - 1) / RING_SEGMENTS * math.pi * 2
		local point = Vector3.new(math.cos(angle), 0, math.sin(angle)) * ring.Radius
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		-- The attachment's X axis points along the circle, which is the way the beam bends
		attachment.CFrame = frame * CFrame.fromMatrix(point, tangent, Vector3.yAxis)
	end
end

-- A flat image (disk or floor ring) on both faces of a thin part
local function flatImage(rig: BasePart, name: string, image: string, color: Color3, diameter: number, offset: CFrame)
	local plate = weldedPart(rig, name, Vector3.new(diameter, 0.02, diameter), offset)
	local labels = {}
	for _, face in { Enum.NormalId.Top, Enum.NormalId.Bottom } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.CanvasSize = Vector2.new(256, 256)
		gui.ClipsDescendants = false
		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Image = image
		label.ImageColor3 = color
		label.Parent = gui
		gui.Parent = plate
		table.insert(labels, label)
	end
	return labels
end

local function addHalo(rig: BasePart, row, size: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Halo"
	gui.Size = UDim2.fromScale(row.Size * size, row.Size * size)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Adornee = rig
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Image = IMAGES[row.Image] or row.Image
	label.ImageColor3 = row.Color
	label.ImageTransparency = row.Transparency or 0
	label.Parent = gui
	gui.Parent = rig
	return gui
end

-- Adds the effects for ballId to a ball part. Lane balls get moved with :Move() every frame;
-- held balls are followed automatically. Returns a handle with :Move, :SetEnabled and :Destroy.
function BallFx.Attach(ball: BasePart, ballId: string?, mode: Mode, forward: Vector3?)
	local info = Balls.Get(ballId) or Config.Balls[1]
	local look = lookFor(info)
	local size = ball.Size.X
	local isLane = mode == "Lane"
	local rateScale = if mode == "Held" then VFX.HeldRate else 1
	local direction = forward or Vector3.zAxis

	local rig = invisiblePart("BallFx", Vector3.one * 0.2)
	rig.Anchored = true
	rig.CFrame = CFrame.lookAt(ball.Position, ball.Position + direction)

	local handle = {
		Ball = ball,
		Rig = rig,
		Follow = mode ~= "Lane",
		Rings = {},
		Spinners = {},
		Badge = nil,
		BadgeHeight = 0,
		Emitters = {},
		Trails = {},
		Enabled = true,
	}

	if isLane then
		for _, row in look.Trails or {} do
			addTrail(rig, row, size)
		end
	end
	for _, row in look.Particles or {} do
		table.insert(handle.Emitters, addParticles(rig, row, size, rateScale))
	end
	for _, row in look.Rings or {} do
		table.insert(handle.Rings, addRing(rig, row, size))
	end
	local disk = look.Disk
	if disk then
		local tilt = CFrame.Angles(math.rad(disk.Tilt[1]), 0, math.rad(disk.Tilt[2]))
		local labels = flatImage(rig, "Disk", IMAGES.Disk, disk.Color, disk.Radius * 2 * size, tilt)
		for _, label in labels do
			label.ImageTransparency = disk.Transparency or 0
			table.insert(handle.Spinners, { Label = label, Speed = disk.Spin or 0 })
		end
	end
	for _, row in look.Halos or {} do
		addHalo(rig, row, size)
	end
	if isLane then
		for i, row in look.Ground or {} do
			-- Just above the floor under the ball
			local offset = CFrame.new(0, -size / 2 + 0.03 + i * 0.005, 0)
			local labels = flatImage(rig, "GroundRing", IMAGES.Ring, row.Color, row.Radius * 2 * size / 0.8, offset)
			for _, label in labels do
				label.ImageTransparency = row.Transparency or 0
			end
		end
	end
	local badge = look.Badge
	if badge and mode ~= "Held" then
		local gui = Instance.new("BillboardGui")
		gui.Name = "Badge"
		gui.Size = UDim2.fromScale(badge.Size * size, badge.Size * size)
		gui.LightInfluence = 0
		gui.Adornee = rig
		gui.StudsOffsetWorldSpace = Vector3.new(0, badge.Height * size, 0)
		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Image = IMAGES[badge.Image] or badge.Image
		label.Parent = gui
		gui.Parent = rig
		handle.Badge = gui
		handle.BadgeHeight = badge.Height * size
	end
	local lightRow = look.Light
	if lightRow then
		local light = Instance.new("PointLight")
		light.Color = lightRow.Color
		light.Brightness = lightRow.Brightness
		light.Range = math.max(lightRow.Range * size, 4)
		light.Parent = rig
	end
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Trail") then
			table.insert(handle.Trails, descendant)
		end
	end

	function handle.Move(_, position: Vector3)
		rig.CFrame = CFrame.lookAt(position, position + direction)
	end

	function handle.SetEnabled(_, enabled: boolean)
		handle.Enabled = enabled
		rig.Parent = if enabled then ball.Parent else nil
		for _, emitter in handle.Emitters do
			emitter.Enabled = enabled
		end
	end

	function handle.Destroy()
		active[handle] = nil
		rig:Destroy()
	end

	for _, ring in handle.Rings do
		placeRing(ring, 0)
	end
	rig.Parent = ball.Parent
	ball.Destroying:Connect(handle.Destroy)
	active[handle] = true
	return handle
end

-- One loop turns every ring, spins the disks, bobs the badges and keeps held effects on their ball
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local camera = workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position or Vector3.zero
	for handle in active do
		if not handle.Enabled then
			continue
		end
		local rig = handle.Rig
		if handle.Follow then
			if not handle.Ball.Parent then
				handle.Destroy()
				continue
			end
			rig.CFrame = CFrame.new(handle.Ball.Position)
		end
		-- Far-away effects keep their last pose (cheap for lots of players)
		if (rig.Position - cameraPosition).Magnitude > 150 then
			continue
		end
		for _, ring in handle.Rings do
			placeRing(ring, t)
		end
		for _, spinner in handle.Spinners do
			spinner.Label.Rotation = (t * spinner.Speed) % 360
		end
		if handle.Badge then
			handle.Badge.StudsOffsetWorldSpace = Vector3.new(0, handle.BadgeHeight + math.sin(t * 2.5) * 0.08, 0)
		end
	end
end)

return BallFx
