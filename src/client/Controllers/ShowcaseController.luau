-- The ball showcase in the lobby ("The Vault"): a glowing display case for every ball of
-- Config.Showcase.MinRarity or better, built from Config.Balls on the slots in Workspace.Showcase.Slots.
-- Balls of Config.Showcase.PremiumRarity (Mythic) get the premium case from the owner's display_case
-- render: navy case, white glowing bands, white diamonds, a light beam from above, glow dots and specks
-- circling the case, rings around the ball. Locked = dark silhouette, white padlock, "???".
-- Every other ball gets the classic case: the ball spins with its trails and trait sparkles, and its
-- sign says LOCKED or OWNED for you.
-- Built on each player's own screen, so the animation costs the server nothing.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)

local SHOW = Config.Showcase
local PREMIUM = SHOW.Premium
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FONT = "rbxasset://fonts/families/GothamSSm.json"

local player = Players.LocalPlayer

local ShowcaseController = {}

local function part(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.FontFace = Font.new(FONT, Enum.FontWeight.Bold)
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

-- A glowing trail between two attachments `width` studs apart, on an invisible part that gets moved around
local function trail(orb: BasePart, color: ColorSequence, width: number, lifetime: number): Trail
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = orb
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = orb
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = color
	t.Transparency = NumberSequence.new(0, 1)
	t.LightEmission = 1
	t.Lifetime = lifetime
	t.FaceCamera = true
	t.Parent = orb
	return t
end

-- Trait sparkles around a ball
local function addTraitSparkles(ball, ballPart: BasePart, size: number)
	local emitters = {}
	for _, entry in Balls.GetTraits(ball) do
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = SPARKLE
		sparkles.Color = ColorSequence.new(entry.Trait.Color)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new(size, 0)
		sparkles.Lifetime = NumberRange.new(1, 1.6)
		sparkles.Speed = NumberRange.new(0.6, 1.4)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Rate = SHOW.SparkleRate
		sparkles.Parent = ballPart
		table.insert(emitters, sparkles)
	end
	return emitters
end

--------------------------------------------------------------------------------------------------
-- Classic case (every rarity except the premium one)
--------------------------------------------------------------------------------------------------
local DARK = Color3.fromRGB(28, 18, 48)
local LOCKED_COLOR = Color3.fromRGB(255, 90, 110)
local OWNED_COLOR = Color3.fromRGB(90, 230, 110)
local CLASSIC_PEDESTAL = Vector3.new(5, 3.2, 5)
local CLASSIC_GLASS = Vector3.new(4.4, 5, 4.4)
local CLASSIC_BALL_SIZE = 2.4
local CLASSIC_ORBIT_RADIUS = 1.75 -- studs from the ball centre

local function buildClassicCase(slot: BasePart, ball, parent: Instance)
	local rarity = Balls.GetRarity(ball.Rarity)
	local base = slot.CFrame * CFrame.new(0, -slot.Size.Y / 2, 0)
	local model = Instance.new("Model")
	model.Name = ball.Id

	-- Stand with a glowing edge, a glass case with glowing corner posts, and a cap
	local pedestal = part({
		Name = "Pedestal",
		Size = CLASSIC_PEDESTAL,
		CFrame = base * CFrame.new(0, CLASSIC_PEDESTAL.Y / 2, 0),
		Color = DARK,
		Material = Enum.Material.SmoothPlastic,
	})
	pedestal.Parent = model
	-- Neon bands just wider than the stand and the cap, so only a thin glowing edge shows
	for _, y in { CLASSIC_PEDESTAL.Y - 0.12, CLASSIC_PEDESTAL.Y + CLASSIC_GLASS.Y + 0.05 } do
		part({
			Name = "Rim",
			Size = Vector3.new(CLASSIC_PEDESTAL.X + 0.15, 0.14, CLASSIC_PEDESTAL.Z + 0.15),
			CFrame = base * CFrame.new(0, y, 0),
			Color = rarity.Color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, model)
	end
	local glass = part({
		Name = "Glass",
		Size = CLASSIC_GLASS,
		CFrame = base * CFrame.new(0, CLASSIC_PEDESTAL.Y + CLASSIC_GLASS.Y / 2, 0),
		Color = Color3.fromRGB(190, 210, 255),
		Material = Enum.Material.SmoothPlastic, -- not Glass: Glass hides the trails and sparkles behind it
		Reflectance = 0.15,
		Transparency = 0.88,
	})
	glass.Parent = model
	for _, corner in { Vector3.new(1, 0, 1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, -1) } do
		part({
			Name = "Post",
			Size = Vector3.new(0.18, CLASSIC_GLASS.Y, 0.18),
			CFrame = base * CFrame.new(
				corner * (CLASSIC_GLASS.X / 2) + Vector3.new(0, CLASSIC_PEDESTAL.Y + CLASSIC_GLASS.Y / 2, 0)
			),
			Color = rarity.Color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, model)
	end
	part({
		Name = "Cap",
		Size = Vector3.new(CLASSIC_PEDESTAL.X, 0.3, CLASSIC_PEDESTAL.Z),
		CFrame = base * CFrame.new(0, CLASSIC_PEDESTAL.Y + CLASSIC_GLASS.Y + 0.27, 0),
		Color = DARK,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	}, model)

	-- The ball itself, lit in its rarity colour, with sparkles for each of its traits
	local center = base * CFrame.new(0, CLASSIC_PEDESTAL.Y + CLASSIC_GLASS.Y / 2, 0)
	local ballPart = part({
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * CLASSIC_BALL_SIZE,
		CFrame = center,
		Color = ball.Color,
		Material = ball.Material,
		CanCollide = false,
	})
	ballPart.Parent = model
	local light = Instance.new("PointLight")
	light.Color = rarity.Color
	light.Range = 12
	light.Brightness = 2.5
	light.Parent = ballPart
	-- A glowing outline in the rarity colour, so even dark balls (like The Void) stand out
	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.OutlineColor = rarity.Color
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Adornee = ballPart
	outline.Parent = ballPart
	addTraitSparkles(ball, ballPart, 0.35)

	-- Glowing trails circling the ball: more for rarer balls
	local orbits = {}
	local orbitCount = math.max(1, Balls.RarityIndex(ball.Rarity) - SHOW.OrbitsFromRarity)
	for i = 1, orbitCount do
		local orb = part({
			Name = "Orbit",
			Size = Vector3.one * 0.2,
			Transparency = 1,
			CanCollide = false,
		})
		local t = trail(orb, ColorSequence.new(ball.Trail, rarity.Color), 0.6, 0.7)
		t.WidthScale = NumberSequence.new(1, 0.2)
		orb.Parent = model
		table.insert(orbits, { Part = orb, Offset = (i - 1) / orbitCount, Tilt = (i - 1) * 0.9 + 0.35 })
	end

	-- Sign on the front of the stand
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = pedestal
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = gui
	label(gui, {
		Name = "BallName",
		Size = UDim2.fromScale(1, 0.24),
		Text = ball.Name:upper(),
		TextColor3 = rarity.Color,
		FontFace = Font.new(FONT, Enum.FontWeight.Heavy),
	})
	label(gui, {
		Name = "Rarity",
		Position = UDim2.fromScale(0, 0.25),
		Size = UDim2.fromScale(1, 0.13),
		Text = ("%s  ·  x%g COINS"):format(ball.Rarity:upper(), ball.Multiplier),
	})
	local traits = Balls.DescribeTraits(ball, false, true)
	label(gui, {
		Name = "Traits",
		Position = UDim2.fromScale(0, 0.41),
		Size = UDim2.fromScale(1, 0.34),
		Text = if traits == "" then "No special trait" else traits,
		RichText = true,
		TextWrapped = true,
	})
	local status = label(gui, {
		Name = "Status",
		Position = UDim2.fromScale(0, 0.8),
		Size = UDim2.fromScale(1, 0.2),
		FontFace = Font.new(FONT, Enum.FontWeight.Heavy),
	})

	model.Parent = parent
	local phase = math.random() * math.pi * 2
	return {
		Id = ball.Id,
		Center = center,
		Refresh = function(isOwned: boolean)
			status.Text = if isOwned then "OWNED" else "LOCKED  ·  FIND IT IN CRATES"
			status.TextColor3 = if isOwned then OWNED_COLOR else LOCKED_COLOR
			glass.Transparency = if isOwned then 0.92 else 0.88
		end,
		-- Spin, float and orbit
		Animate = function(t: number)
			local float = center * CFrame.new(0, math.sin(t * 1.6 + phase) * SHOW.BobHeight, 0)
			ballPart.CFrame = float * CFrame.Angles(0.3, t * SHOW.SpinSpeed * math.pi * 2, 0)
			for _, orbit in orbits do
				local angle = (t * SHOW.OrbitSpeed + orbit.Offset) * math.pi * 2
				orbit.Part.CFrame = float * CFrame.Angles(orbit.Tilt, angle, 0) * CFrame.new(CLASSIC_ORBIT_RADIUS, 0, 0)
			end
		end,
	}
end

--------------------------------------------------------------------------------------------------
-- Premium case (Config.Showcase.PremiumRarity), from the owner's display_case render
--------------------------------------------------------------------------------------------------
-- Colours picked from the render
local INK = Color3.fromRGB(14, 13, 26)
local NAVY = Color3.fromRGB(26, 28, 82)
local NAVY_TOP = Color3.fromRGB(30, 34, 118)
local BLUE_CAP = Color3.fromRGB(58, 48, 176)
local PEDESTAL = Color3.fromRGB(24, 24, 66)
local GOLD = Color3.fromRGB(214, 164, 52)
local WHITE = Color3.fromRGB(235, 240, 255)
local GLASS = Color3.fromRGB(191, 232, 255)
local SIGN_BG = Color3.fromRGB(22, 20, 62)
local PINK = Color3.fromRGB(255, 70, 190)
local CYAN = Color3.fromRGB(70, 230, 255)
local SILHOUETTE = Color3.fromRGB(44, 44, 78)
local BEAM = Color3.fromRGB(190, 205, 255)
local RING_COLORS = { WHITE, CYAN, PINK }

local S = PREMIUM.CaseScale -- the design is 1.24 x 2.47 units; this turns it into studs
local BALL_SIZE = 0.512 * S
local BALL_Y = 1.39 -- ball centre height in design units
local NEON = "Neon" -- marks pieces that glow white

-- Every box and disc of the case in design units: { name, centre, size, colour, round }.
-- The design's front is +Z; at() turns it to face out of the slot.
local PIECES = {
	{ "Plinth", Vector3.new(0, 0.05, 0), Vector3.new(1.24, 0.1, 1.24), INK },
	{ "Base", Vector3.new(0, 0.36, 0), Vector3.new(1.1, 0.52, 1.1), NAVY },
	{ "BaseBand", Vector3.new(0, 0.64, 0), Vector3.new(1.13, 0.04, 1.13), NEON },
	{ "BaseTop", Vector3.new(0, 0.695, 0), Vector3.new(1.16, 0.07, 1.16), BLUE_CAP },
	{ "SignFrame", Vector3.new(0, 0.37, 0.565), Vector3.new(1.0, 0.46, 0.04), INK },
	{ "Post", Vector3.new(0.47, 1.33, 0.47), Vector3.new(0.045, 1.2, 0.045), GOLD },
	{ "Post", Vector3.new(0.47, 1.33, -0.47), Vector3.new(0.045, 1.2, 0.045), GOLD },
	{ "Post", Vector3.new(-0.47, 1.33, 0.47), Vector3.new(0.045, 1.2, 0.045), GOLD },
	{ "Post", Vector3.new(-0.47, 1.33, -0.47), Vector3.new(0.045, 1.2, 0.045), GOLD },
	{ "TopBand", Vector3.new(0, 1.95, 0), Vector3.new(1.04, 0.04, 1.04), NEON },
	{ "Ceiling", Vector3.new(0, 1.928, 0), Vector3.new(1.0, 0.004, 1.0), NAVY_TOP }, -- so only the band's edge glows
	{ "TopCap", Vector3.new(0, 2.03, 0), Vector3.new(1.12, 0.12, 1.12), NAVY_TOP },
	{ "TopTrim", Vector3.new(0, 2.105, 0), Vector3.new(0.9, 0.03, 0.9), INK },
	{ "GemBase", Vector3.new(0, 2.14, 0), Vector3.new(0.26, 0.05, 0.26), GOLD, true },
	{ "PedestalDisc", Vector3.new(0, 0.765, 0), Vector3.new(0.697, 0.07, 0.697), PEDESTAL, true },
	{ "PedestalColumn", Vector3.new(0, 0.94, 0), Vector3.new(0.25, 0.28, 0.25), PEDESTAL, true },
	{ "PedestalDish", Vector3.new(0, 1.115, 0), Vector3.new(0.465, 0.07, 0.465), PEDESTAL, true },
	{ "PedestalRim", Vector3.new(0, 1.153, 0), Vector3.new(0.43, 0.012, 0.43), NEON, true },
}
-- White diamonds on the corners: centres in design units
local CORNER_GEMS = {
	Vector3.new(0.48, 2.25, 0.48),
	Vector3.new(0.48, 2.25, -0.48),
	Vector3.new(-0.48, 2.25, 0.48),
	Vector3.new(-0.48, 2.25, -0.48),
}
-- The bowling ball's three finger holes, from the ball centre (design units)
local HOLES = {
	Vector3.new(-0.186, 0.17, 0.028),
	Vector3.new(-0.114, 0.17, 0.15),
	Vector3.new(-0.207, 0.084, 0.122),
}
-- The white padlock on a ball you don't own yet (in front of the ball, facing out)
local LOCK = {
	{ "LockBody", Vector3.new(0, 1.37, 0.3), Vector3.new(0.19, 0.15, 0.06), WHITE },
	{ "LockTop", Vector3.new(0, 1.497, 0.3), Vector3.new(0.15, 0.028, 0.035), WHITE },
	{ "LockLeg", Vector3.new(-0.061, 1.465, 0.3), Vector3.new(0.028, 0.06, 0.035), WHITE },
	{ "LockLeg", Vector3.new(0.061, 1.465, 0.3), Vector3.new(0.028, 0.06, 0.035), WHITE },
	{ "Keyhole", Vector3.new(0, 1.36, 0.331), Vector3.new(0.035, 0.06, 0.005), SILHOUETTE },
}

local function premiumPart(props: { [string]: any }, parent: Instance?): Part
	props.CanCollide = props.CanCollide or false
	props.Material = props.Material or Enum.Material.SmoothPlastic
	return part(props, parent)
end

local function gradient(parent: Instance, from: Color3, to: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(from, to)
	g.Parent = parent
	return g
end

-- Design units (front = +Z) to a spot on the slot (front = the way the slot faces)
local function at(base: CFrame, pos: Vector3): CFrame
	return base * CFrame.new(-pos.X * S, pos.Y * S, -pos.Z * S)
end

-- One piece from a PIECES or LOCK row
local function piece(base: CFrame, row, parent: Instance): Part
	local name, pos, size, color, round = row[1], row[2], row[3], row[4], row[5]
	local cf = at(base, pos)
	if round then
		-- Roblox cylinders lie along X, so stand them up
		size = Vector3.new(size.Y, size.X, size.Z)
		cf *= CFrame.Angles(0, 0, math.pi / 2)
	end
	return premiumPart({
		Name = name,
		Shape = if round then Enum.PartType.Cylinder else Enum.PartType.Block,
		Size = size * S,
		CFrame = cf,
		Color = if color == NEON then WHITE else color,
		Material = if color == NEON then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		Reflectance = if color == GOLD then 0.25 else 0,
	}, parent)
end

local function diamond(template: BasePart?, cf: CFrame, width: number, height: number, parent: Instance): BasePart
	local gem: BasePart = if template then template:Clone() else premiumPart({})
	gem.Name = "Diamond"
	gem.Size = Vector3.new(width, height, width) * S
	gem.CFrame = cf * CFrame.Angles(0, math.rad(45), 0)
	gem.Color = WHITE
	gem.Material = Enum.Material.Neon
	gem.Parent = parent
	return gem
end

-- The light from above: a bright beam onto the roof with a wider soft one around it, a spotlight
-- from the same spot, a light inside the case and a soft glow on the wall behind
local function addLights(base: CFrame, model: Model, plinth: BasePart)
	local top = at(base, Vector3.new(0, 2.15, 0))
	local beamTop = Instance.new("Attachment")
	beamTop.Parent = plinth
	beamTop.WorldCFrame = top * CFrame.new(0, PREMIUM.BeamHeight, 0)
	local beamBottom = Instance.new("Attachment")
	beamBottom.Parent = plinth
	beamBottom.WorldCFrame = top
	-- { top width, bottom width, transparency near the top, transparency at the roof }
	for _, look in { { 0.3, 1.0, 0.35, 0.55 }, { 0.6, 1.7, 0.75, 0.88 } } do
		local beam = Instance.new("Beam")
		beam.Attachment0 = beamTop
		beam.Attachment1 = beamBottom
		beam.Width0 = look[1] * S
		beam.Width1 = look[2] * S
		beam.Color = ColorSequence.new(BEAM)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, look[3]),
			NumberSequenceKeypoint.new(1, look[4]),
		})
		beam.LightEmission = 1
		beam.Brightness = 2
		beam.FaceCamera = true
		beam.Segments = 1
		beam.Parent = plinth
	end
	local lamp = premiumPart({ Name = "Lamp", Size = Vector3.one * 0.2, Transparency = 1, CastShadow = false }, model)
	lamp.CFrame = beamTop.WorldCFrame
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 60
	spot.Range = PREMIUM.BeamHeight + 3 * S
	spot.Brightness = 5
	spot.Color = BEAM
	spot.Shadows = true
	spot.Parent = lamp

	local inner = Instance.new("SurfaceLight")
	inner.Face = Enum.NormalId.Bottom
	inner.Angle = 90
	inner.Range = 1.3 * S
	inner.Brightness = 3
	inner.Color = BEAM
	inner.Parent = model:FindFirstChild("Ceiling")

	local glowSpot =
		premiumPart({ Name = "BackGlow", Size = Vector3.one * 0.2, Transparency = 1, CastShadow = false }, model)
	glowSpot.CFrame = at(base, Vector3.new(0, 1.4, -0.55))
	local backGlow = Instance.new("PointLight")
	backGlow.Color = Color3.fromRGB(150, 120, 255)
	backGlow.Range = 3 * S
	backGlow.Brightness = 1.5
	backGlow.Parent = glowSpot
end

-- Cyan and pink glow dots drifting around the case, and glowing specks circling it
local function addGlowFx(base: CFrame, model: Model)
	local cloud = premiumPart({
		Name = "GlowDots",
		Size = Vector3.new(1.8, 2.6, 1.8) * S,
		CFrame = at(base, Vector3.new(0, 1.4, 0)),
		Transparency = 1,
		CastShadow = false,
	}, model)
	for _, color in { CYAN, PINK } do
		local dots = Instance.new("ParticleEmitter")
		dots.Shape = Enum.ParticleEmitterShape.Box
		dots.Texture = PREMIUM.GlowTexture
		dots.Color = ColorSequence.new(color)
		dots.LightEmission = 1
		dots.Brightness = 3
		dots.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.2, 0.4),
			NumberSequenceKeypoint.new(0.8, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		})
		dots.Lifetime = NumberRange.new(3, 5)
		dots.Speed = NumberRange.new(0.1, 0.5)
		dots.SpreadAngle = Vector2.new(180, 180)
		dots.Rate = PREMIUM.FloatingDots
		dots.Parent = cloud
	end

	local motes = {}
	for i = 1, PREMIUM.Motes do
		local color = if i % 2 == 0 then CYAN else PINK
		local mote = premiumPart({
			Name = "Mote",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.18,
			Color = color,
			Material = Enum.Material.Neon,
			CastShadow = false,
		}, model)
		trail(mote, ColorSequence.new(color), 0.12, 0.5).Brightness = 2
		table.insert(motes, {
			Part = mote,
			Angle = math.random() * math.pi * 2,
			Radius = (0.64 + math.random() * 0.14) * S, -- outside the case, clear of the next one
			Height = (0.75 + math.random() * 1.5) * S,
			Speed = PREMIUM.MoteSpeed * (0.7 + math.random() * 0.6) * (if i % 3 == 0 then -1 else 1),
		})
	end
	return motes
end

local function buildPremiumCase(slot: BasePart, ball, parent: Instance, diamondTemplate: BasePart?)
	local rarity = Balls.GetRarity(ball.Rarity)
	local base = slot.CFrame * CFrame.new(0, slot.Size.Y / 2, 0)
	local model = Instance.new("Model")
	model.Name = ball.Id

	for _, row in PIECES do
		piece(base, row, model)
	end
	local plinth = model:FindFirstChild("Plinth") :: BasePart
	model.PrimaryPart = plinth
	premiumPart({
		Name = "Glass",
		Size = Vector3.new(0.94, 1.2, 0.94) * S,
		CFrame = at(base, Vector3.new(0, 1.33, 0)),
		Color = GLASS,
		Reflectance = 0.1,
		Transparency = 0.9, -- SmoothPlastic, not Glass: Glass hides the rings and sparkles behind it
		CastShadow = false,
	}, model)
	for _, name in { "Plinth", "Base", "Glass" } do
		(model:FindFirstChild(name) :: BasePart).CanCollide = true
	end

	for _, pos in CORNER_GEMS do
		diamond(diamondTemplate, at(base, pos), 0.13, 0.26, model)
	end
	local crownCenter = at(base, Vector3.new(0, 2.33, 0))
	local crown = diamond(diamondTemplate, crownCenter, 0.19, 0.34, model)

	addLights(base, model, plinth)
	local motes = addGlowFx(base, model)

	-- The ball with its finger holes, in its own model so one outline covers the ball and the padlock
	local display = Instance.new("Model")
	display.Name = "Display"
	local center = at(base, Vector3.new(0, BALL_Y, 0)) * CFrame.new(0, PREMIUM.BobHeight, 0)
	local ballPart = premiumPart({
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * BALL_SIZE,
		CFrame = center,
	}, display)
	local holes = {}
	for _, offset in HOLES do
		local hole = premiumPart({
			Name = "FingerHole",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.07 * S,
			Color = INK,
		}, display)
		table.insert(holes, { Part = hole, Offset = CFrame.new(-offset.X * S, offset.Y * S, -offset.Z * S) })
	end
	local lock = Instance.new("Model")
	lock.Name = "Padlock"
	for _, row in LOCK do
		piece(base, row, lock)
	end
	display.Parent = model

	-- A soft white halo around the ball, like the render
	local halo = premiumPart({
		Name = "Halo",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * BALL_SIZE * 1.18,
		CFrame = center,
		Color = WHITE,
		Material = Enum.Material.Neon,
		Transparency = 0.9,
		CastShadow = false,
	}, model)

	local light = Instance.new("PointLight")
	light.Range = 10
	light.Parent = ballPart
	local outline = Instance.new("Highlight")
	outline.FillTransparency = 1
	outline.DepthMode = Enum.HighlightDepthMode.Occluded
	outline.Adornee = display
	outline.Parent = display
	local sparkles = addTraitSparkles(ball, ballPart, 0.3)

	-- Thin bright rings orbiting the ball, each tilted its own way
	local orbits = {}
	for i = 1, PREMIUM.Rings do
		local orb = premiumPart({ Name = "Orbit", Size = Vector3.one * 0.2, Transparency = 1, CastShadow = false })
		local color = RING_COLORS[(i - 1) % #RING_COLORS + 1]
		trail(orb, ColorSequence.new(color), PREMIUM.RingWidth, 0.9 / PREMIUM.RingSpeed).Brightness = 2
		orb.Parent = model
		table.insert(orbits, {
			Part = orb,
			Offset = (i - 1) / PREMIUM.Rings,
			Tilt = CFrame.Angles(0, (i - 1) * 1.1, 0) * CFrame.Angles(0.35 + (i - 1) * 0.55, 0, (i - 1) * 0.4),
		})
	end

	-- The sign on the front of the base: rarity badge, name (or ??? while locked) and one info line
	local sign = premiumPart({
		Name = "Sign",
		Size = Vector3.new(0.94, 0.41, 0.01) * S,
		CFrame = at(base, Vector3.new(0, 0.37, 0.59)),
		Color = INK,
	}, model)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = sign
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -10, 1, -10)
	panel.BackgroundColor3 = SIGN_BG
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local border = Instance.new("UIStroke")
	border.Thickness = 4
	border.Color = Color3.new(1, 1, 1)
	border.Parent = panel
	gradient(border, PINK, CYAN)

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.fromScale(0.5, 0.08)
	badge.Size = UDim2.fromScale(0.36, 0.22)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.Parent = panel
	local pill = Instance.new("UICorner")
	pill.CornerRadius = UDim.new(1, 0)
	pill.Parent = badge
	gradient(badge, rarity.Color, CYAN)
	label(badge, {
		Name = "Rarity",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.85, 0.75),
		Text = ball.Rarity:upper(),
		FontFace = Font.new(FONT, Enum.FontWeight.Heavy),
	})
	local name = label(panel, {
		Name = "BallName",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromScale(0.92, 0.36),
		FontFace = Font.new(FONT, Enum.FontWeight.Heavy),
	})
	gradient(name, Color3.fromRGB(255, 150, 220), Color3.new(1, 1, 1))
	local info = label(panel, {
		Name = "Info",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromScale(0.92, 0.2),
		RichText = true,
	})
	local stats = ("x%g COINS"):format(ball.Multiplier)
	local traits = Balls.DescribeTraits(ball, true, true)
	if traits ~= "" then
		stats ..= "  ·  " .. traits
	end

	model.Parent = parent
	local ringRadius = PREMIUM.RingRadius * S
	local phase = math.random() * math.pi * 2
	return {
		Id = ball.Id,
		Center = center,
		-- Owned: the real ball, its name and stats. Locked: a dark silhouette, a padlock and ???
		Refresh = function(isOwned: boolean)
			ballPart.Color = if isOwned then ball.Color else SILHOUETTE
			ballPart.Material = if isOwned then ball.Material else Enum.Material.SmoothPlastic
			ballPart.Reflectance = if isOwned then 0 else 0.25 -- a little shine so the silhouette reads as a ball
			lock.Parent = if isOwned then nil else display
			outline.OutlineColor = if isOwned then rarity.Color else WHITE
			outline.OutlineTransparency = if isOwned then 0 else 0.25
			light.Color = if isOwned then rarity.Color else BEAM
			light.Brightness = if isOwned then 2.5 else 2
			for _, emitter in sparkles do
				emitter.Enabled = isOwned
			end
			name.Text = if isOwned then ball.Name:upper() else "???"
			info.Text = if isOwned then stats else "Unlock: find it in a crate"
		end,
		Animate = function(t: number)
			local float = center * CFrame.new(0, math.sin(t * 1.6 + phase) * PREMIUM.BobHeight, 0)
			local ballCFrame = float * CFrame.Angles(0.3, t * PREMIUM.SpinSpeed * math.pi * 2, 0)
			ballPart.CFrame = ballCFrame
			halo.CFrame = float
			for _, hole in holes do
				hole.Part.CFrame = ballCFrame * hole.Offset
			end
			crown.CFrame = crownCenter
				* CFrame.new(0, math.sin(t * 1.2 + phase) * 0.1, 0)
				* CFrame.Angles(0, t * PREMIUM.GemSpinSpeed * math.pi * 2, 0)
			for _, orbit in orbits do
				local angle = (t * PREMIUM.RingSpeed + orbit.Offset) * math.pi * 2
				-- A slightly flattened circle, tilted differently for each ring
				local point = Vector3.new(math.cos(angle) * ringRadius, 0, math.sin(angle) * ringRadius * 0.8)
				orbit.Part.CFrame = float * orbit.Tilt * CFrame.new(point)
			end
			for _, mote in motes do
				local angle = mote.Angle + t * mote.Speed * math.pi * 2
				local bob = math.sin(t * 0.9 + mote.Angle * 3) * 0.4
				mote.Part.Position = (base * CFrame.new(
					math.cos(angle) * mote.Radius,
					mote.Height + bob,
					math.sin(angle) * mote.Radius
				)).Position
			end
		end,
	}
end

function ShowcaseController:Start()
	local showcase = Workspace:WaitForChild("Showcase", 30)
	local slotFolder = showcase and showcase:WaitForChild("Slots", 10)
	if not slotFolder then
		warn("[ShowcaseController] Workspace.Showcase.Slots is missing, so the lobby showcase is off")
		return
	end
	local models = ReplicatedStorage:WaitForChild("ShowcaseModels", 10)
	local diamondTemplate = models and models:FindFirstChild("Diamond")
	if not diamondTemplate then
		warn("[ShowcaseController] ReplicatedStorage.ShowcaseModels.Diamond is missing, so the premium gems are blocks")
	end

	local slots = slotFolder:GetChildren()
	table.sort(slots, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)

	-- Best balls first, so Mythics get the first slots
	local minRarity = Balls.RarityIndex(SHOW.MinRarity)
	local shown = {}
	for _, ball in Balls.Sorted() do
		if Balls.RarityIndex(ball.Rarity) >= minRarity then
			table.insert(shown, ball)
		end
	end
	if #shown > #slots then
		warn(
			("[ShowcaseController] %d balls to show but only %d slots: add slots in Workspace.Showcase.Slots"):format(
				#shown,
				#slots
			)
		)
	end

	local cases = Instance.new("Folder")
	cases.Name = "Cases"
	cases.Parent = showcase
	local built = {}
	for i, ball in shown do
		local slot = slots[i]
		if slot and slot:IsA("BasePart") then
			table.insert(
				built,
				if ball.Rarity == SHOW.PremiumRarity
					then buildPremiumCase(slot, ball, cases, diamondTemplate)
					else buildClassicCase(slot, ball, cases)
			)
		end
	end

	-- LOCKED / OWNED, from the balls the server says you own
	local function refreshOwned()
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		for _, case in built do
			case.Refresh(owned[case.Id] == true)
		end
	end
	player:GetAttributeChangedSignal("OwnedBalls"):Connect(refreshOwned)
	refreshOwned()

	-- Animate only while you're close enough to see it
	local middle = Vector3.zero
	for _, case in built do
		middle += case.Center.Position / math.max(#built, 1)
	end
	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if #built == 0 or not camera or (camera.CFrame.Position - middle).Magnitude > SHOW.AnimateDistance then
			return
		end
		local t = os.clock()
		for _, case in built do
			case.Animate(t)
		end
	end)
end

return ShowcaseController
