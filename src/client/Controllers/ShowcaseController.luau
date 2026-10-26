-- Display cases, one set per zone (Phase X Part 7, Config.Showcase.Sets): the lobby "Vault" shows the Neon Lanes
-- balls (Workspace.Showcase.Slots), Main Street Lanes and Skyline Lanes have their own sets. Each case = the zone's
-- base structure (Config.Showcase.Themes) + the rarity's accent and FX (Config.Showcase.Styles).
-- Every case uses the owner's display_case design (navy case, glass, pedestal, sign). Its look comes from
-- Config.Showcase.Styles for the ball's rarity: coloured bands, gold or black posts, diamonds, a light beam,
-- rings around the ball, glow dots, circling specks and a faint aura, building up from Common to Mythic.
-- Locked = dark silhouette, padlock and "???". Owned = the real ball, its name and stats.
-- Built on each player's own screen, so the animation costs the server nothing.
-- Step 8b: the pet shelf (Workspace.Showcase.MascotShelf; one per set): the zone egg's pets on glowing stands, yours in
-- colour (your Shiny if you made one), missing ones as dark silhouettes, with a "PETS n / N" sign.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local BallLook = require(Shared.Modules.BallLook)
local Mascots = require(Shared.Modules.Mascots)
local BallFx = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("BallFx"))
local MascotView = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("MascotView"))

local SHOW = Config.Showcase
local CASE = SHOW.Case
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FONT = "rbxasset://fonts/families/GothamSSm.json"

local player = Players.LocalPlayer

local ShowcaseController = {}

local function part(props: { [string]: any }, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanQuery = false
	p.CanTouch = false
	p.CanCollide = false
	p.Material = Enum.Material.SmoothPlastic
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

local function gradient(parent: Instance, from: Color3, to: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(from, to)
	g.Parent = parent
	return g
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
-- The case design, from the owner's display_case render
--------------------------------------------------------------------------------------------------
-- Colours picked from the renders
-- The zone theme (base structure colours, Config.Showcase.Themes) of the case being built; buildCase sets it
local T = SHOW.Themes.Neon
local GOLD = Color3.fromRGB(214, 164, 52)
local PINK = Color3.fromRGB(255, 70, 190)
local CYAN = Color3.fromRGB(70, 230, 255)
local SILHOUETTE = Color3.fromRGB(44, 44, 78)
local BLACKOUT = Color3.new(0, 0, 0) -- locked balls: solid black, like a fighter you haven't unlocked yet

local S = CASE.CaseScale -- the design is 1.24 x 2.47 units; this turns it into studs
local BALL_SIZE = 0.512 * S
local BALL_Y = 1.39 -- ball centre height in design units
-- Colour markers resolved per rarity style
local ACCENT = "Accent" -- glowing bands in the rarity's accent colour
local POST = "Post" -- gold or black, from the style

-- Every box and disc of the case in design units: { name, centre, size, colour, round }.
-- The design's front is +Z; at() turns it to face out of the slot.
local PIECES = {
	{ "Plinth", Vector3.new(0, 0.05, 0), Vector3.new(1.24, 0.1, 1.24), "Ink" },
	{ "Base", Vector3.new(0, 0.36, 0), Vector3.new(1.1, 0.52, 1.1), "Navy" },
	{ "BaseBand", Vector3.new(0, 0.64, 0), Vector3.new(1.13, 0.04, 1.13), ACCENT },
	{ "BaseTop", Vector3.new(0, 0.695, 0), Vector3.new(1.16, 0.07, 1.16), "BlueCap" },
	{ "SignFrame", Vector3.new(0, 0.37, 0.565), Vector3.new(1.0, 0.46, 0.04), "Ink" },
	{ "Post", Vector3.new(0.47, 1.33, 0.47), Vector3.new(0.045, 1.2, 0.045), POST },
	{ "Post", Vector3.new(0.47, 1.33, -0.47), Vector3.new(0.045, 1.2, 0.045), POST },
	{ "Post", Vector3.new(-0.47, 1.33, 0.47), Vector3.new(0.045, 1.2, 0.045), POST },
	{ "Post", Vector3.new(-0.47, 1.33, -0.47), Vector3.new(0.045, 1.2, 0.045), POST },
	{ "TopBand", Vector3.new(0, 1.95, 0), Vector3.new(1.04, 0.04, 1.04), ACCENT },
	{ "Ceiling", Vector3.new(0, 1.928, 0), Vector3.new(1.0, 0.004, 1.0), "NavyTop" }, -- so only the band's edge glows
	{ "TopCap", Vector3.new(0, 2.03, 0), Vector3.new(1.12, 0.12, 1.12), "NavyTop" },
	{ "TopTrim", Vector3.new(0, 2.105, 0), Vector3.new(0.9, 0.03, 0.9), "Ink" },
	{ "PedestalDisc", Vector3.new(0, 0.765, 0), Vector3.new(0.697, 0.07, 0.697), "Pedestal", true },
	{ "PedestalColumn", Vector3.new(0, 0.94, 0), Vector3.new(0.25, 0.28, 0.25), "Pedestal", true },
	{ "PedestalDish", Vector3.new(0, 1.115, 0), Vector3.new(0.465, 0.07, 0.465), "Pedestal", true },
	{ "PedestalRim", Vector3.new(0, 1.153, 0), Vector3.new(0.43, 0.012, 0.43), ACCENT, true },
}
-- Diamonds on the corners and their gold stand on the roof: centres in design units
local CORNER_GEMS = {
	Vector3.new(0.48, 2.25, 0.48),
	Vector3.new(0.48, 2.25, -0.48),
	Vector3.new(-0.48, 2.25, 0.48),
	Vector3.new(-0.48, 2.25, -0.48),
}
local GEM_BASE = { "GemBase", Vector3.new(0, 2.14, 0), Vector3.new(0.26, 0.05, 0.26), GOLD, true }
-- The bowling ball's three finger holes, from the ball centre (design units)
local HOLES = {
	Vector3.new(-0.186, 0.17, 0.028),
	Vector3.new(-0.114, 0.17, 0.15),
	Vector3.new(-0.207, 0.084, 0.122),
}
-- The padlock on a ball you don't own yet (in front of the ball, facing out), in the accent colour
local LOCK = {
	{ "LockBody", Vector3.new(0, 1.37, 0.3), Vector3.new(0.19, 0.15, 0.06), ACCENT },
	{ "LockTop", Vector3.new(0, 1.497, 0.3), Vector3.new(0.15, 0.028, 0.035), ACCENT },
	{ "LockLeg", Vector3.new(-0.061, 1.465, 0.3), Vector3.new(0.028, 0.06, 0.035), ACCENT },
	{ "LockLeg", Vector3.new(0.061, 1.465, 0.3), Vector3.new(0.028, 0.06, 0.035), ACCENT },
	{ "Keyhole", Vector3.new(0, 1.36, 0.331), Vector3.new(0.035, 0.06, 0.005), SILHOUETTE },
}

-- Design units (front = +Z) to a spot on the slot (front = the way the slot faces)
local function at(base: CFrame, pos: Vector3): CFrame
	return base * CFrame.new(-pos.X * S, pos.Y * S, -pos.Z * S)
end

-- One piece from a PIECES or LOCK row. Bands glow in the accent colour; the padlock is solid accent.
local function piece(base: CFrame, row, parent: Instance, style, glowBands: boolean): Part
	local name, pos, size, color, round = row[1], row[2], row[3], row[4], row[5]
	local cf = at(base, pos)
	if round then
		-- Roblox cylinders lie along X, so stand them up
		size = Vector3.new(size.Y, size.X, size.Z)
		cf *= CFrame.Angles(0, 0, math.pi / 2)
	end
	local gold = color == GOLD or (color == POST and style.Posts == "Gold")
	local material = Enum.Material.SmoothPlastic
	if color == ACCENT then
		color = style.Accent
	elseif color == POST then
		color = if gold then GOLD else T.Ink
	elseif type(color) == "string" then
		-- A base structure colour from the zone theme (and its material, if the theme gives one)
		material = T.Materials and T.Materials[color] or material
		color = T[color]
	end
	-- Shade darkens the whole case for a moodier look (Mythic)
	color = color:Lerp(Color3.new(), 1 - (style.Shade or 1))
	return part({
		Name = name,
		Shape = if round then Enum.PartType.Cylinder else Enum.PartType.Block,
		Size = size * S,
		CFrame = cf,
		Color = color,
		Material = if glowBands and row[4] == ACCENT then Enum.Material.Neon else material,
		Reflectance = if gold then 0.25 else 0,
	}, parent)
end

local function diamond(template: BasePart?, cf: CFrame, width: number, height: number, color: Color3, parent: Instance)
	local gem: BasePart = if template then template:Clone() else part({})
	gem.Name = "Diamond"
	gem.Size = Vector3.new(width, height, width) * S
	gem.CFrame = cf * CFrame.Angles(0, math.rad(45), 0)
	gem.Color = color
	gem.Material = Enum.Material.Neon
	gem.Parent = parent
	return gem
end

-- Case lights: a soft light inside the roof for every case; Beam styles also get a light beam onto the
-- roof with a spotlight from the same spot; InnerGlow puts a coloured light behind the ball.
-- style.Light scales all of them (Mythic is moodier).
local function addLights(base: CFrame, model: Model, plinth: BasePart, style)
	local power = style.Light or 1
	local inner = Instance.new("SurfaceLight")
	inner.Face = Enum.NormalId.Bottom
	inner.Angle = 90
	inner.Range = 1.3 * S
	inner.Brightness = 2 * power * (if style.Beam then 1 else 0.5)
	inner.Color = style.Beam or T.CaseLight
	inner.Parent = model:FindFirstChild("Ceiling")

	if style.Beam then
		local top = at(base, Vector3.new(0, 2.15, 0))
		local beamTop = Instance.new("Attachment")
		beamTop.Parent = plinth
		beamTop.WorldCFrame = top * CFrame.new(0, CASE.BeamHeight, 0)
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
			beam.Color = ColorSequence.new(style.Beam)
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 1 - (1 - look[3]) * power),
				NumberSequenceKeypoint.new(1, 1 - (1 - look[4]) * power),
			})
			beam.LightEmission = 1
			beam.Brightness = 2 * power
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Parent = plinth
		end
		local lamp = part({ Name = "Lamp", Size = Vector3.one * 0.2, Transparency = 1, CastShadow = false }, model)
		lamp.CFrame = beamTop.WorldCFrame
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Bottom
		spot.Angle = 40 -- onto the case, not the carpet around it
		spot.Range = CASE.BeamHeight + 3 * S
		spot.Brightness = 5 * power
		spot.Color = style.Beam
		spot.Shadows = true
		spot.Parent = lamp
	end

	if style.InnerGlow then
		local glowSpot =
			part({ Name = "BackGlow", Size = Vector3.one * 0.2, Transparency = 1, CastShadow = false }, model)
		glowSpot.CFrame = at(base, Vector3.new(0, 1.4, -0.55))
		local backGlow = Instance.new("PointLight")
		backGlow.Color = style.InnerGlow
		backGlow.Range = 3 * S
		backGlow.Brightness = 1.5 * power
		backGlow.Parent = glowSpot
	end
end

-- A faint glow around the whole case in the rarity colour: a soft sprite behind the case and a
-- dim light on the floor and wall around it
local function addAura(base: CFrame, model: Model, color: Color3)
	local anchor = part({ Name = "Aura", Size = Vector3.one * 0.2, Transparency = 1, CastShadow = false }, model)
	anchor.CFrame = at(base, Vector3.new(0, 1.2, -0.25)) -- behind the ball, just in front of the wall
	local sprite = Instance.new("BillboardGui")
	sprite.Size = UDim2.fromScale(2.6 * S, 3.2 * S)
	sprite.LightInfluence = 0
	sprite.MaxDistance = 140
	sprite.Parent = anchor
	local glow = Instance.new("ImageLabel")
	glow.Size = UDim2.fromScale(1, 1)
	glow.BackgroundTransparency = 1
	glow.Image = CASE.GlowTexture
	glow.ImageColor3 = color
	glow.ImageTransparency = 0.75
	glow.Parent = sprite
	local floor = Instance.new("PointLight")
	floor.Color = color
	floor.Range = 2.2 * S
	floor.Brightness = 0.8
	floor.Parent = anchor
end

-- Floating glow dots (Dots) and glowing specks circling the case (Motes)
local function addGlowFx(base: CFrame, model: Model, style)
	if style.Dots then
		local spread = style.Dots.Spread
		local cloud = part({
			Name = "GlowDots",
			Size = Vector3.new(spread, spread * 1.45, spread) * S,
			CFrame = at(base, Vector3.new(0, 1.4, 0)),
			Transparency = 1,
			CastShadow = false,
		}, model)
		local size = style.Dots.Size
		for _, color in style.Dots.Colors do
			local dots = Instance.new("ParticleEmitter")
			dots.Shape = Enum.ParticleEmitterShape.Box
			dots.Texture = CASE.GlowTexture
			dots.Color = ColorSequence.new(color)
			dots.LightEmission = 1
			dots.Brightness = 3 * (style.Light or 1)
			dots.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.2, size),
				NumberSequenceKeypoint.new(0.8, size * 0.75),
				NumberSequenceKeypoint.new(1, 0),
			})
			dots.Lifetime = NumberRange.new(3, 5)
			dots.Speed = NumberRange.new(0.1, 0.5)
			dots.SpreadAngle = Vector2.new(180, 180)
			dots.Rate = style.Dots.Rate
			dots.Parent = cloud
		end
	end

	local motes = {}
	for i = 1, style.Motes or 0 do
		local color = if i % 2 == 0 then CYAN else PINK
		local mote = part({
			Name = "Mote",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.16,
			Color = color:Lerp(Color3.new(), 1 - (style.Light or 1) * 0.8 - 0.2),
			Material = Enum.Material.Neon,
			CastShadow = false,
		}, model)
		trail(mote, ColorSequence.new(color), 0.12, 0.5).Brightness = 2 * (style.Light or 1)
		table.insert(motes, {
			Part = mote,
			Angle = math.random() * math.pi * 2,
			Radius = (0.64 + math.random() * 0.14) * S, -- outside the case, clear of the next one
			Height = (0.75 + math.random() * 1.5) * S,
			Speed = CASE.MoteSpeed * (0.7 + math.random() * 0.6) * (if i % 3 == 0 then -1 else 1),
		})
	end
	return motes
end

local function buildCase(slot: BasePart, ball, parent: Instance, diamondTemplate: BasePart?, theme: string?)
	T = SHOW.Themes[theme or "Neon"] or SHOW.Themes.Neon
	local rarity = Balls.GetRarity(ball.Rarity)
	local style = SHOW.Styles[ball.Rarity] or SHOW.Styles.Common
	local power = style.Light or 1
	local base = slot.CFrame * CFrame.new(0, slot.Size.Y / 2, 0)
	local model = Instance.new("Model")
	model.Name = ball.Id

	for _, row in PIECES do
		piece(base, row, model, style, true)
	end
	local plinth = model:FindFirstChild("Plinth") :: BasePart
	model.PrimaryPart = plinth
	part({
		Name = "Glass",
		Size = Vector3.new(0.94, 1.2, 0.94) * S,
		CFrame = at(base, Vector3.new(0, 1.33, 0)),
		Color = T.Glass,
		Reflectance = 0.1,
		Transparency = 0.9, -- SmoothPlastic, not Glass: Glass hides the rings and sparkles behind it
		CastShadow = false,
	}, model)
	for _, name in { "Plinth", "Base", "Glass" } do
		(model:FindFirstChild(name) :: BasePart).CanCollide = true
	end

	local crown, crownCenter
	if style.Gems then
		piece(base, GEM_BASE, model, style, false)
		for _, pos in CORNER_GEMS do
			diamond(diamondTemplate, at(base, pos), 0.13, 0.26, style.Gems, model)
		end
		crownCenter = at(base, Vector3.new(0, 2.33, 0))
		crown = diamond(diamondTemplate, crownCenter, 0.19, 0.34, style.Gems, model)
	end

	addLights(base, model, plinth, style)
	if style.Aura then
		addAura(base, model, style.Aura)
	end
	local motes = addGlowFx(base, model, style)

	-- The ball with its finger holes, in its own model so one outline covers the ball and the padlock
	local display = Instance.new("Model")
	display.Name = "Display"
	local center = at(base, Vector3.new(0, BALL_Y, 0)) * CFrame.new(0, CASE.BobHeight, 0)
	local ballPart = part({
		Name = "Ball",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * BALL_SIZE,
		CFrame = center,
	}, display)
	local holes = {}
	for _, offset in HOLES do
		local hole = part({
			Name = "FingerHole",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.07 * S,
			Color = T.Ink,
		}, display)
		table.insert(holes, { Part = hole, Offset = CFrame.new(-offset.X * S, offset.Y * S, -offset.Z * S) })
	end
	-- The ball's 3D model (if it has one). Locked, every piece turns solid black so you see its shape
	-- but not its colours; owned, each piece gets its real look back.
	local look = BallLook.Apply(ballPart, ball.Id) and ballPart:FindFirstChild("Look")
	local lookPieces = {}
	if look then
		for _, hole in holes do
			hole.Part.Transparency = 1 -- the model has its own finger holes
		end
		for _, p in look:GetDescendants() do
			if p:IsA("BasePart") then
				table.insert(lookPieces, {
					Part = p,
					Color = p.Color,
					Material = p.Material,
					Reflectance = p.Reflectance,
					Transparency = p.Transparency,
					Texture = if p:IsA("MeshPart") then p.TextureID else nil,
					Skin = p:FindFirstChildOfClass("SurfaceAppearance"),
				})
			end
		end
	end
	local ballFx -- the ball's own effects (rings, sparkles, glow), made once the case is in the world
	local lock = Instance.new("Model")
	lock.Name = "Padlock"
	for _, row in LOCK do
		piece(base, row, lock, style, false)
	end
	display.Parent = model

	-- A soft glow around the ball
	local halo
	if style.Halo then
		halo = part({
			Name = "Halo",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * BALL_SIZE * 1.18,
			CFrame = center,
			Color = style.Accent,
			Material = Enum.Material.Neon,
			Transparency = 1 - 0.035 * power, -- faint, so a locked ball still reads as a dark silhouette
			CastShadow = false,
		}, model)
	end

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
	local ringCount = style.Rings or 0
	for i = 1, ringCount do
		local orb = part({ Name = "Orbit", Size = Vector3.one * 0.2, Transparency = 1, CastShadow = false })
		local colors = style.RingColors or { style.Accent }
		local color = colors[(i - 1) % #colors + 1]
		trail(orb, ColorSequence.new(color), CASE.RingWidth, 0.9 / CASE.RingSpeed).Brightness = 2 * power
		orb.Parent = model
		table.insert(orbits, {
			Part = orb,
			Offset = (i - 1) / ringCount,
			Tilt = CFrame.Angles(0, (i - 1) * 1.1, 0) * CFrame.Angles(0.35 + (i - 1) * 0.55, 0, (i - 1) * 0.4),
		})
	end

	-- The sign on the front of the base: rarity badge, name (or ??? while locked) and one info line
	local sign = part({
		Name = "Sign",
		Size = Vector3.new(0.94, 0.41, 0.01) * S,
		CFrame = at(base, Vector3.new(0, 0.37, 0.59)),
		Color = T.Ink,
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
	panel.BackgroundColor3 = Color3.new(1, 1, 1)
	panel.Parent = gui
	gradient(panel, T.SignTop, T.SignBg).Rotation = 90 -- lighter at the top, like the renders
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local border = Instance.new("UIStroke")
	border.Thickness = 4
	border.Color = if style.SignGradient then Color3.new(1, 1, 1) else style.Accent
	border.Parent = panel
	if style.SignGradient then
		gradient(border, PINK, CYAN)
	end

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.fromScale(0.5, 0.08)
	badge.Size = UDim2.fromScale(0.36, 0.22)
	badge.BackgroundColor3 = if style.SignGradient then Color3.new(1, 1, 1) else style.Accent
	badge.Parent = panel
	local pill = Instance.new("UICorner")
	pill.CornerRadius = UDim.new(1, 0)
	pill.Parent = badge
	if style.SignGradient then
		gradient(badge, rarity.Color, CYAN)
	end
	label(badge, {
		Name = "Rarity",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.85, 0.75),
		Text = ball.Rarity:upper(),
		TextColor3 = if style.SignGradient then Color3.new(1, 1, 1) else T.Ink,
		FontFace = Font.new(FONT, Enum.FontWeight.Heavy),
	})
	local name = label(panel, {
		Name = "BallName",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromScale(0.92, 0.36),
		FontFace = Font.new(FONT, Enum.FontWeight.Heavy),
	})
	if style.SignGradient then
		gradient(name, Color3.fromRGB(255, 150, 220), Color3.new(1, 1, 1))
	end
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
	ballFx = BallFx.Attach(ballPart, ball.Id, "Display")
	local ringRadius = CASE.RingRadius * S
	local phase = math.random() * math.pi * 2
	return {
		Id = ball.Id,
		Center = center,
		-- Owned: the real ball, its name and stats. Locked: a dark silhouette, a padlock and ???
		Refresh = function(isOwned: boolean)
			ballPart.Color = if isOwned then ball.Color else BLACKOUT
			ballPart.Material = if isOwned then ball.Material else Enum.Material.Neon
			ballPart.Reflectance = 0
			for _, piece in lookPieces do
				local p = piece.Part
				p.Color = if isOwned then piece.Color else BLACKOUT
				-- Black Neon ignores the case lights, so the shape stays flat black with no grey shine
				p.Material = if isOwned then piece.Material else Enum.Material.Neon
				p.Reflectance = if isOwned then piece.Reflectance else 0
				-- See-through glow layers would blur the black shape, so they hide while locked
				p.Transparency = if isOwned then piece.Transparency elseif piece.Transparency > 0.5 then 1 else 0
				if piece.Texture then
					(p :: MeshPart).TextureID = if isOwned then piece.Texture else ""
				end
				if piece.Skin then
					piece.Skin.Parent = if isOwned then p else nil
				end
			end
			lock.Parent = if isOwned then nil else display
			ballFx:SetEnabled(isOwned)
			outline.OutlineColor = if isOwned then rarity.Color else style.Accent
			outline.OutlineTransparency = if isOwned then 0 else 0.25
			light.Color = if isOwned then rarity.Color else style.Accent
			light.Brightness = (if isOwned then 2.5 else 0.4) * power -- locked stays a dark silhouette
			for _, emitter in sparkles do
				emitter.Enabled = isOwned
			end
			name.Text = if isOwned then ball.Name:upper() else "???"
			info.Text = if isOwned then stats else "Unlock: find it in a crate"
		end,
		Animate = function(t: number)
			local float = center * CFrame.new(0, math.sin(t * 1.6 + phase) * CASE.BobHeight, 0)
			local ballCFrame = float * CFrame.Angles(0.3, t * CASE.SpinSpeed * math.pi * 2, 0)
			ballPart.CFrame = ballCFrame
			ballFx:Move(float.Position)
			if halo then
				halo.CFrame = float
			end
			for _, hole in holes do
				hole.Part.CFrame = ballCFrame * hole.Offset
			end
			if crown then
				crown.CFrame = crownCenter
					* CFrame.new(0, math.sin(t * 1.2 + phase) * 0.1, 0)
					* CFrame.Angles(0, t * CASE.GemSpinSpeed * math.pi * 2, 0)
			end
			for _, orbit in orbits do
				local angle = (t * CASE.RingSpeed + orbit.Offset) * math.pi * 2
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

-- The mascot shelf: mascots spread along the shelf part's length (its X side), facing its front, on stands.
-- Returns a function that animates them (bob and a slow sway).
local function buildMascotShelf(shelf: BasePart, parent: Instance, list: { any }, onFloor: boolean?): (number) -> ()
	local FX = Config.MascotFx
	local folder = Instance.new("Folder")
	folder.Name = "MascotShelf"
	folder.Parent = parent
	if onFloor then
		-- Rest the shelf on whatever is under it (the zone's floor)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { shelf, parent }
		local bottom = shelf.Position - Vector3.yAxis * shelf.Size.Y / 2
		local hit = workspace:Raycast(bottom, Vector3.yAxis * -60, params)
		if hit then
			shelf.CFrame -= Vector3.yAxis * (bottom.Y - hit.Position.Y)
		end
	end
	local spacing = shelf.Size.X / #list
	local top = shelf.CFrame * CFrame.new(0, shelf.Size.Y / 2, 0)

	type Spot = {
		Base: CFrame,
		Model: Model?,
		Id: string?,
		Lift: number?,
		Floats: boolean?,
		Phase: number,
		Mascot: any,
		Plate: Part,
	}
	local spots: { Spot } = {}
	for i, mascot in list do
		local base = top * CFrame.new(-shelf.Size.X / 2 + spacing * (i - 0.5), 0, 0)
		local plate = part({
			Name = "Stand",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.25, FX.ShelfSize * 1.1, FX.ShelfSize * 1.1),
			CFrame = base * CFrame.new(0, 0.125, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Material = Enum.Material.Neon,
			Color = Mascots.RarityColor(mascot.Rarity),
			Transparency = 0.6,
		}, folder)
		table.insert(spots, { Base = base, Phase = i * 0.9, Mascot = mascot, Plate = plate })
	end

	-- The sign above the middle of the shelf
	local signAnchor = part({
		Name = "SignAnchor",
		Size = Vector3.one * 0.2,
		Transparency = 1,
		CFrame = top * CFrame.new(0, FX.ShelfSize + FX.ShelfHover + 3.4, 0),
	}, folder)
	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromScale(14, 1.6)
	sign.LightInfluence = 0
	sign.MaxDistance = 140
	sign.Parent = signAnchor
	local signText = label(sign, {
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Color3.fromRGB(255, 60, 210),
		FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json"),
	})
	local signStroke = Instance.new("UIStroke")
	signStroke.Thickness = 2
	signStroke.Color = Color3.fromHex("06060F")
	signStroke.Parent = signText

	local function silhouette(model: Model)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Color3.fromRGB(14, 10, 26)
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
			elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
				d:Destroy()
			end
		end
	end

	local function refresh()
		local owned = Mascots.DecodeOwned(player:GetAttribute("Mascots"))
		local found = 0
		for _, spot in spots do
			local mascot = spot.Mascot
			local shinyId = Mascots.ShinyId(mascot.Id)
			-- What to show: your Shiny, else yours, else the silhouette
			local id = if (owned[shinyId] or 0) > 0
				then shinyId
				elseif (owned[mascot.Id] or 0) > 0 then mascot.Id
				else ""
			if id ~= "" then
				found += 1
			end
			if spot.Id ~= id then
				if spot.Model then
					spot.Model:Destroy()
				end
				local shown = Mascots.Get(id) or mascot
				local model = MascotView.Mascot(shown, FX.ShelfSize)
				MascotView.Soften(model)
				-- Real pets come in their own sizes: the wide ones (wings, orbit rings) shrink to fit their spot
				local _, box = model:GetBoundingBox()
				local widest = math.max(box.X, box.Z)
				if widest > FX.ShelfSize * 1.4 then
					model:ScaleTo(model:GetScale() * FX.ShelfSize * 1.4 / widest)
					box *= FX.ShelfSize * 1.4 / widest
				end
				-- Walkers stand on the stand (bottom of the model on its top); floaters and placeholders hover
				local idle = Config.PetIdle[mascot.Model or mascot.Id] -- placeholder pets borrow a real pet (Model)
				local real = model:FindFirstChild("Root") ~= nil
				spot.Floats = not real or (idle ~= nil and idle.Floats == true)
				local boxCFrame = model:GetBoundingBox()
				local bottom = model:GetPivot():PointToObjectSpace(boxCFrame.Position).Y - box.Y / 2
				spot.Lift = if spot.Floats
					then FX.ShelfHover + math.max(box.Y / 2, FX.ShelfSize / 2)
					else 0.25 - bottom
				if id == "" then
					silhouette(model)
				end
				model.Parent = folder
				spot.Model = model
				spot.Id = id
				spot.Plate.Transparency = if id == "" then 0.85 else 0.4
			end
		end
		signText.Text = ("PETS  %d / %d"):format(found, #spots)
	end
	player:GetAttributeChangedSignal("Mascots"):Connect(refresh)
	refresh()

	return function(t: number)
		for _, spot in spots do
			local model = spot.Model
			if model then
				local bob = if spot.Floats then math.sin((t + spot.Phase) * 2) * 0.2 else 0
				local lift = (spot.Lift or FX.ShelfHover + FX.ShelfSize / 2) + bob
				local sway = if spot.Id ~= "" then math.sin(t * 0.8 + spot.Phase) * 0.5 else 0
				-- The model's front is its -Z; the shelf's front is its -Z too
				model:PivotTo(spot.Base * CFrame.new(0, lift, 0) * CFrame.Angles(0, sway, 0))
			end
		end
	end
end

-- The slot each shown ball sits on, best balls first ({ Ball, Slot }), for the first-3-minutes camera moment
ShowcaseController.Shown = {}

-- One zone's case set (a Config.Showcase.Sets row). Returns its animate function, or nil when its slots aren't there.
local function buildSet(set, diamondTemplate: BasePart?): ((number) -> ())?
	local function find(path: { string }): Instance?
		local node: Instance? = Workspace
		for _, name in path do
			node = node and node:WaitForChild(name, 30)
		end
		return node
	end
	local slotFolder = find(set.Slots)
	if not slotFolder then
		warn(
			("[ShowcaseController] %s is missing, so zone %d's cases are off"):format(
				table.concat(set.Slots, "."),
				set.Zone
			)
		)
		return nil
	end
	local slots = slotFolder:GetChildren()
	table.sort(slots, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)

	-- Every ball that drops in this zone, best first
	local shown = {}
	for _, ball in Balls.Sorted() do
		if ball.Zone == set.Zone and not ball.Retired and ball.InCrates ~= false then
			table.insert(shown, ball)
		end
	end
	if #shown > #slots then
		warn(
			("[ShowcaseController] zone %d: %d balls to show but only %d slots: add slots in %s"):format(
				set.Zone,
				#shown,
				#slots,
				table.concat(set.Slots, ".")
			)
		)
	end

	local cases = Instance.new("Folder")
	cases.Name = "Cases"
	cases.Parent = slotFolder.Parent
	local built = {}
	for i, ball in shown do
		local slot = slots[i]
		if slot and slot:IsA("BasePart") then
			table.insert(built, buildCase(slot, ball, cases, diamondTemplate, set.Theme))
			if set.Zone == 2 then
				table.insert(ShowcaseController.Shown, { Ball = ball, Slot = slot })
			end
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

	-- The pet shelf: this zone egg's pets
	local shelf = set.Shelf and find(set.Shelf)
	local animateShelf = if shelf and shelf:IsA("BasePart")
		then buildMascotShelf(shelf, cases, Mascots.InEgg(set.Egg), set.ShelfOnFloor)
		else nil

	-- Animate only while you're close enough to see it
	local middle = Vector3.zero
	for _, case in built do
		middle += case.Center.Position / math.max(#built, 1)
	end
	if #built == 0 and shelf and shelf:IsA("BasePart") then
		middle = shelf.Position
	end
	return function(t: number)
		local camera = Workspace.CurrentCamera
		if not camera or (camera.CFrame.Position - middle).Magnitude > SHOW.AnimateDistance then
			return
		end
		for _, case in built do
			case.Animate(t)
		end
		if animateShelf then
			animateShelf(t)
		end
	end
end

function ShowcaseController:Start()
	local models = ReplicatedStorage:WaitForChild("ShowcaseModels", 10)
	local diamondTemplate = models and models:FindFirstChild("Diamond")
	if not diamondTemplate then
		warn("[ShowcaseController] ReplicatedStorage.ShowcaseModels.Diamond is missing, so the gems are blocks")
	end
	local animators = {}
	for _, set in SHOW.Sets do
		task.spawn(function()
			local animate = buildSet(set, diamondTemplate)
			if animate then
				table.insert(animators, animate)
			end
		end)
	end
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for _, animate in animators do
			animate(t)
		end
	end)
end

return ShowcaseController
