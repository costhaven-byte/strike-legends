-- Builds the test lane on the player's screen: lighting, lane, walls, lights, the ball and the pins.
-- Nothing here comes from the main game; it is all made from plain parts.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Settings = require(ReplicatedStorage:WaitForChild("ThrowLab"):WaitForChild("ThrowSettings"))

local World = {}

World.LaneLength = 36 -- foul line to the head pin
World.HeadPinZ = -36
World.PinSpacing = 2.9
World.PinHeight = 3.6
World.PinWidth = 1.15
World.BallDiameter = 2.3
World.BallStartZ = 3
World.LaneHalfWidth = 5

World.BallEffects = {} -- sparkles and fire on the current ball
World.Lights = {} -- neon strips that flash during celebrations: { part, baseColor }

local folder = Instance.new("Folder")
folder.Name = "ThrowLabWorld"
folder.Parent = workspace

local pinFolder = Instance.new("Folder")
pinFolder.Name = "Pins"
pinFolder.Parent = folder

World.Folder = folder

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders lie along X; this stands them up

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = props.Parent or folder
	return p
end

local function light(cf: CFrame, size: Vector3, color: Color3)
	local p = part({
		Name = "Light",
		CFrame = cf,
		Size = size,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	table.insert(World.Lights, { part = p, color = color })
end

local function buildLighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 1
	Lighting.Ambient = Color3.fromRGB(70, 55, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(50, 40, 90)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.GlobalShadows = true
	for _, child in Lighting:GetChildren() do
		if child:IsA("PostEffect") or child:IsA("Sky") or child:IsA("Atmosphere") then
			child:Destroy()
		end
	end
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.8
	bloom.Size = 30
	bloom.Threshold = 0.9
	bloom.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.2
	cc.Contrast = 0.1
	cc.Parent = Lighting
	World.ColorCorrection = cc
end

local function buildLane()
	local L = World.LaneLength
	local half = World.LaneHalfWidth
	local farZ = -(L + 14)
	local nearZ = 10
	local length = nearZ - farZ
	local midZ = (nearZ + farZ) / 2

	-- Floor of the whole room
	part({
		Name = "Floor",
		Size = Vector3.new(80, 1, length + 30),
		CFrame = CFrame.new(0, -2.5, midZ),
		Color = Color3.fromRGB(30, 22, 52),
	})

	-- The lane itself (top surface at height 0)
	part({
		Name = "Lane",
		Size = Vector3.new(half * 2, 1, L + 8 + 4),
		CFrame = CFrame.new(0, -0.5, (8 + -(L + 4)) / 2),
		Color = Color3.fromRGB(196, 140, 86),
		Material = Enum.Material.WoodPlanks,
		Reflectance = 0.08,
	})
	-- Approach area behind the foul line
	part({
		Name = "Approach",
		Size = Vector3.new(half * 2 + 4, 1, 6),
		CFrame = CFrame.new(0, -0.5, 11),
		Color = Color3.fromRGB(60, 44, 96),
	})

	-- Gutters and side rails
	for _, side in { -1, 1 } do
		part({
			Name = "Gutter",
			Size = Vector3.new(1.4, 1, L + 12),
			CFrame = CFrame.new(side * (half + 0.7), -1.1, (8 - (L + 4)) / 2),
			Color = Color3.fromRGB(40, 30, 70),
		})
		part({
			Name = "Rail",
			Size = Vector3.new(0.6, 1.2, L + 12),
			CFrame = CFrame.new(side * (half + 1.7), -0.2, (8 - (L + 4)) / 2),
			Color = Color3.fromRGB(50, 36, 88),
		})
		light(
			CFrame.new(side * (half + 1.7), 0.45, (8 - (L + 4)) / 2),
			Vector3.new(0.25, 0.15, L + 12),
			Color3.fromRGB(255, 43, 214)
		)
	end

	-- Foul line
	light(CFrame.new(0, 0.01, 0), Vector3.new(half * 2, 0.04, 0.25), Color3.fromRGB(70, 230, 255))

	-- Aiming arrows on the lane (just decoration)
	for i = -2, 2 do
		local arrow = part({
			Name = "Arrow",
			Size = Vector3.new(0.35, 0.04, 1.2),
			CFrame = CFrame.new(i * 1.2, 0.01, -14 - math.abs(i) * 1.2),
			Color = Color3.fromRGB(70, 230, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		arrow.Transparency = 0.3
	end

	-- Pin deck: pit behind the pins, a back wall and kickback walls on the sides
	local deckZ = World.HeadPinZ - 3
	part({
		Name = "Pit",
		Size = Vector3.new(half * 2 + 6, 1, 10),
		CFrame = CFrame.new(0, -2, -(L + 9)),
		Color = Color3.fromRGB(20, 14, 36),
	})
	part({
		Name = "BackWall",
		Size = Vector3.new(half * 2 + 8, 16, 1),
		CFrame = CFrame.new(0, 6, farZ),
		Color = Color3.fromRGB(24, 16, 44),
	})
	light(CFrame.new(0, 12, farZ + 0.55), Vector3.new(half * 2 + 6, 0.4, 0.1), Color3.fromRGB(255, 200, 40))
	light(CFrame.new(0, 13.2, farZ + 0.55), Vector3.new(half * 2 + 6, 0.4, 0.1), Color3.fromRGB(255, 43, 214))
	for _, side in { -1, 1 } do
		part({
			Name = "Kickback",
			Size = Vector3.new(1, 7, 18),
			CFrame = CFrame.new(side * (half + 2.5), 3, deckZ - 3),
			Color = Color3.fromRGB(36, 24, 66),
		})
		light(CFrame.new(side * (half + 1.95), 6.4, deckZ - 3), Vector3.new(0.1, 0.3, 18), Color3.fromRGB(70, 230, 255))
		-- Invisible tall walls keep flying pins bouncing around the deck instead of leaving the map
		part({
			Name = "PinFence",
			Size = Vector3.new(1, 40, 24),
			CFrame = CFrame.new(side * (half + 2.5), 23, deckZ - 3),
			Transparency = 1,
		})
	end
	part({
		Name = "PinFenceBack",
		Size = Vector3.new(half * 2 + 8, 40, 1),
		CFrame = CFrame.new(0, 23, farZ),
		Transparency = 1,
	})

	-- A few lamps so the pins pop out of the dark
	for _, z in { 4, -16, -34, World.HeadPinZ - 2 } do
		local lamp = part({
			Name = "Lamp",
			Size = Vector3.new(1, 1, 1),
			CFrame = CFrame.new(0, 14, z),
			Transparency = 1,
			CanCollide = false,
		})
		local pl = Instance.new("PointLight")
		pl.Range = 26
		pl.Brightness = 1.6
		pl.Color = Color3.fromRGB(255, 235, 220)
		pl.Shadows = true
		pl.Parent = lamp
	end
	local deckLamp = part({
		Name = "DeckLamp",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(0, 9, World.HeadPinZ + 6),
		Transparency = 1,
		CanCollide = false,
	})
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Angle = 70
	spot.Range = 30
	spot.Brightness = 4
	spot.Parent = deckLamp
	deckLamp.CFrame = CFrame.lookAt(deckLamp.Position, Vector3.new(0, 0, World.HeadPinZ - 3))
end

-- Where each of the 10 pins stands, plus its row (0 = head pin)
function World.PinSpots(): { { position: Vector3, row: number, x: number } }
	local spots = {}
	local s = World.PinSpacing
	for row = 0, 3 do
		for j = 0, row do
			local x = (j - row / 2) * s
			local z = World.HeadPinZ - row * s * 0.866
			table.insert(spots, { position = Vector3.new(x, 0, z), row = row, x = x })
		end
	end
	return spots
end

local function pinPart(name: string, shape: Enum.PartType, size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.55, 1, 1)
	return p
end

-- One pin: wide body (the root, anchored until it gets hit), neon neck stripe, round head.
function World.BuildPin(base: CFrame): (Model, Part)
	local h, w = World.PinHeight, World.PinWidth
	local bodyH, neckH = h * 0.58, h * 0.2
	local headD = w * 0.7
	local white = Color3.fromRGB(245, 245, 250)

	local pin = Instance.new("Model")
	pin.Name = "Pin"
	local body = pinPart("Body", Enum.PartType.Cylinder, Vector3.new(bodyH, w, w), white, Enum.Material.SmoothPlastic)
	body.CFrame = base * CFrame.new(0, bodyH / 2, 0) * UPRIGHT
	body.Anchored = true
	body.Parent = pin
	local neck = pinPart(
		"Neck",
		Enum.PartType.Cylinder,
		Vector3.new(neckH, w * 0.5, w * 0.5),
		Color3.fromRGB(255, 40, 120),
		Enum.Material.Neon
	)
	neck.CFrame = base * CFrame.new(0, bodyH + neckH / 2, 0) * UPRIGHT
	neck.Parent = pin
	local head =
		pinPart("Head", Enum.PartType.Ball, Vector3.new(headD, headD, headD), white, Enum.Material.SmoothPlastic)
	head.CFrame = base * CFrame.new(0, bodyH + neckH + headD / 2 - 0.05, 0)
	head.Parent = pin
	for _, p in { neck, head } do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = p
		weld.Parent = body
	end

	-- Trail points (the trail itself is switched on when the pin goes flying)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(bodyH / 2, 0, 0)
	a0.Parent = body
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-bodyH / 2, 0, 0)
	a1.Parent = body
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.22
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 43, 214))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Enabled = false
	trail.Parent = body

	pin.PrimaryPart = body
	pin.Parent = pinFolder
	return pin, body
end

-- Removes every pin (flying or standing)
function World.ClearPins()
	pinFolder:ClearAllChildren()
end

-- Builds a fresh rack. Pins drop in from just above, quickly.
function World.BuildRack(): { { model: Model, root: Part, row: number, x: number, index: number } }
	World.ClearPins()
	local rack = {}
	for i, spot in World.PinSpots() do
		local final = CFrame.new(spot.position)
		local model, root = World.BuildPin(final * CFrame.new(0, 1.2, 0))
		local target = root.CFrame - Vector3.new(0, 1.2, 0)
		TweenService
			:Create(root, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = target })
			:Play()
		table.insert(rack, { model = model, root = root, row = spot.row, x = spot.x, index = i })
	end
	return rack
end

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 43, 214)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 255, 90)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 230, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 70, 255)),
})

-- How big the ball is at a Power Level (diameter in studs)
function World.BallSize(level: number): number
	return World.BallDiameter * Settings.PowerLevels[level].Size
end

-- Builds the ball for a Power Level: bigger, brighter and wilder the higher the level.
-- Level 1 is plain; sparkles, fire and a rainbow trail switch on at the levels set in ThrowSettings.
function World.BuildBall(level: number): Part
	local look = Settings.PowerLevels[level]
	local color = look.Color
	local rainbow = level >= Settings.RainbowFromLevel
	local d = World.BallSize(level)
	local ball = part({
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(d, d, d),
		CFrame = CFrame.new(0, d / 2, World.BallStartZ),
		Color = color:Lerp(Color3.new(0.05, 0.02, 0.1), 0.55),
		Material = Enum.Material.Glass,
		Reflectance = 0.2,
		CanCollide = false,
	})
	local coreSize = d * (level == 1 and 0.5 or 0.7)
	local core = part({
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(coreSize, coreSize, coreSize),
		CFrame = ball.CFrame,
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = ball,
	})
	core.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = ball
	weld.Part1 = core
	weld.Parent = ball

	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = color
	glow.Range = 6 + level
	glow.Brightness = World.BallGlow(level)
	glow.Parent = ball

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, d * 0.35, 0)
	a0.Parent = ball
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -d * 0.35, 0)
	a1.Parent = ball
	local trail = Instance.new("Trail")
	trail.Name = "Trail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.12 + level * 0.04
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = rainbow and RAINBOW or ColorSequence.new(color, color:Lerp(Color3.new(1, 1, 1), 0.4))
	trail.Transparency = NumberSequence.new(level == 1 and 0.6 or 0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Enabled = false
	trail.Parent = ball

	-- Effects that are on all the time (sparkles, fire) go in here, so they can be hidden together
	local effects = {}
	if level >= Settings.SparklesFromLevel then
		local e = Instance.new("ParticleEmitter")
		e.Name = "Sparkles"
		e.Texture = SPARKLE
		e.Color = rainbow and RAINBOW or ColorSequence.new(color, Color3.new(1, 1, 1))
		e.LightEmission = 1
		e.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25 + d * 0.12), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.3, 0.6)
		e.Speed = NumberRange.new(1, 2 + level * 0.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 15 + (level - Settings.SparklesFromLevel) * 12
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.Parent = ball
		table.insert(effects, e)
	end
	if level >= Settings.FireFromLevel then
		local fire = Instance.new("Fire")
		fire.Name = "Fire"
		-- Kept low and coloured (never white) so the flames don't hide the pins behind the ball
		fire.Size = d * 0.9
		fire.Heat = 2 + level * 0.4
		fire.Color = level >= Settings.RainbowFromLevel and Color3.fromRGB(255, 43, 214) or color
		fire.SecondaryColor = level >= Settings.RainbowFromLevel and Color3.fromRGB(70, 230, 255)
			or color:Lerp(Color3.new(0, 0, 0), 0.3)
		fire.Parent = ball
		table.insert(effects, fire)
	end
	World.BallEffects = effects
	return ball
end

-- How bright the ball's light is while it sits still at a Power Level
function World.BallGlow(level: number): number
	return 0.3 + level * 0.1
end

-- Shows or hides the ball and everything glowing on it (used when it drops into the pit)
function World.SetBallVisible(ball: Part, visible: boolean)
	ball.Transparency = visible and 0 or 1
	ball.Core.Transparency = visible and 0 or 1
	ball.Glow.Enabled = visible
	if not visible then
		ball.Trail.Enabled = false
	end
	for _, effect in World.BallEffects do
		effect.Enabled = visible
	end
end

function World.Build()
	buildLighting()
	buildLane()
end

return World
