-- Builds a ball's effects from Config.BallVfx: comet trails, sparkles, orbit rings, glowing disk, floating
-- model pieces, halos, floor rings, the floating trait badge and the glow light.
-- Everything hangs off an invisible upright "rig" that follows the ball without spinning,
-- so rings and badges stay steady while the ball rolls.
-- SETTINGS: EFFECTS off hides every ball's effects (the ball itself stays); switching it back on brings them back.
-- OTHER PLAYERS' EFFECTS off hides them on balls made with options.Others = true (another player's ball).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Settings = require(script.Parent:WaitForChild("Settings"))

local VFX = Config.BallVfx
local IMAGES = VFX.Images
local RING_SEGMENTS = 6
-- Bezier handle length that bends one segment into an arc of a circle (per stud of radius)
local ARC = 4 / 3 * math.tan(math.pi / (2 * RING_SEGMENTS))

local BallFx = {}

export type Mode = "Lane" | "Held" | "Display"

local active = {}

-- Turns every glow under root down to Config.BallVfx.Dim (lights, trails, beams, sparkles, glowing labels)
function BallFx.Dim(root: Instance)
	for _, item in root:GetDescendants() do
		if
			item:IsA("Light")
			or item:IsA("Trail")
			or item:IsA("Beam")
			or item:IsA("ParticleEmitter")
			or item:IsA("BillboardGui")
			or item:IsA("SurfaceGui")
		then
			item.Brightness *= VFX.Dim * (if item:IsA("Light") then VFX.LightDim else 1)
		end
	end
end

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
-- Placeholder balls (Phase X) that borrow a model also borrow its effect, every colour moved toward their Tint
local function recolor(value, tint: Color3)
	if typeof(value) == "Color3" then
		return value:Lerp(tint, 0.75)
	elseif type(value) == "table" then
		local copy = {}
		for key, item in value do
			copy[key] = recolor(item, tint)
		end
		return copy
	end
	return value
end
local borrowed = {}

local function lookFor(ball)
	local own = VFX.Balls[ball.Id]
	if own then
		return own
	end
	if ball.Model and ball.Tint and not ball.PlainModel and VFX.Balls[ball.Model] then
		borrowed[ball.Id] = borrowed[ball.Id] or recolor(VFX.Balls[ball.Model], ball.Tint)
		return borrowed[ball.Id]
	end
	return {
		Trails = { { Colors = { ball.Trail }, Width = 0.7, Lifetime = 0.3 } },
	}
end

-- One trail ribbon. Spans the ball top to bottom, so the follow camera sees it streaming down the lane.
-- layer: see Config.BallVfx.TrailLayers. Returns its motion (twist/wobble/shimmer) for the frame loop, if any.
local function addTrailLayer(rig: BasePart, row, layer, size: number)
	local width = row.Width * layer.Width * size
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, width / 2, 0)
	top.Parent = rig
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -width / 2, 0)
	bottom.Parent = rig
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom

	local texture = if layer.Body and row.BodyTexture then row.BodyTexture else layer.Texture
	local colors = row.Colors
	if texture ~= layer.Texture then
		colors = { Color3.new(1, 1, 1) } -- the row's own texture carries the colours
	elseif layer.Lighten then
		colors = {}
		for i, color in row.Colors do
			colors[i] = color:Lerp(Color3.new(1, 1, 1), layer.Lighten)
		end
	end
	trail.Color = colorSequence(colors)

	-- Stays strong behind the ball, then dies away toward the tail (so every colour in the row shows)
	local start = 1 - (1 - (row.Transparency or 0)) * (1 - layer.Fade)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, start),
		NumberSequenceKeypoint.new(0.3, start + (1 - start) * 0.15),
		NumberSequenceKeypoint.new(0.7, start + (1 - start) * 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(layer.Spread[1], layer.Spread[2])
	trail.Lifetime = row.Lifetime * layer.Lifetime
	trail.LightEmission = if layer.Body and row.Glow then row.Glow else layer.Emission
	trail.Brightness = row.Bright or 1
	trail.LightInfluence = 0
	trail.FaceCamera = layer.Twist == nil -- twisting ribbons turn in 3D, so they spiral instead
	trail.MinLength = 0.05
	trail.Texture = IMAGES[texture]
	if layer.Repeat then
		trail.TextureMode = Enum.TextureMode.Wrap
		trail.TextureLength = layer.Repeat * size
	else
		trail.TextureMode = Enum.TextureMode.Stretch
	end
	trail.Parent = rig

	if not (layer.Twist or layer.Wobble or layer.Shimmer) then
		return nil
	end
	return {
		Trail = trail,
		Top = top,
		Bottom = bottom,
		Half = width / 2,
		Twist = layer.Twist or 0,
		Phase = math.rad(layer.Phase or 0),
		Wobble = (layer.Wobble or 0) * size,
		Shimmer = layer.Shimmer or 0,
		Seed = math.random() * 100,
	}
end

-- Wisps of the trail's colour peeling off behind the ball, drifting up and curling away
local function addWisps(rig: BasePart, row, size: number)
	local wisps = VFX.TrailWisps
	local holder = weldedPart(rig, "Wisps", Vector3.one * size * 0.7, CFrame.identity)
	holder.Shape = Enum.PartType.Ball
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = IMAGES[wisps.Image]
	emitter.Color = colorSequence(row.Colors)
	emitter.LightEmission = wisps.Emission
	emitter.LightInfluence = 0
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Size = NumberSequence.new(wisps.Size[1] * size * row.Width, wisps.Size[2] * size * row.Width)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, wisps.Transparency),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(wisps.Life[1], wisps.Life[2])
	emitter.Speed = NumberRange.new(wisps.Speed[1] * size, wisps.Speed[2] * size)
	emitter.Acceleration = Vector3.new(0, wisps.Rise * size, 0)
	emitter.Drag = 2
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-wisps.Spin, wisps.Spin)
	emitter.Rate = wisps.Rate
	emitter.Parent = holder
	return emitter
end

-- Draws one Trails row; motions and emitters go into the handle so the frame loop can animate them.
-- tier: the ball's rarity (1 Common .. 6 Mythic) picks which layers show. Only the first row gets them all;
-- extra rows add just their core, so a ball never draws a pile of trails at once.
local function addTrail(rig: BasePart, row, size: number, handle, tier: number, first: boolean)
	if row.Texture then
		-- A special streak (lightning bolts): drawn as-is, one layer
		addTrailLayer(rig, row, {
			Texture = row.Texture,
			Width = 1,
			Lifetime = 1,
			Fade = 0,
			Spread = { 1, 0.05 },
			Emission = row.Glow or 1,
		}, size)
		return
	end
	for _, layer in VFX.TrailLayers do
		if tier < (layer.FromRarity or 1) or not (first or layer.Core) then
			continue
		end
		local motion = addTrailLayer(rig, row, layer, size)
		if motion then
			table.insert(handle.Motions, motion)
		end
	end
	if first and VFX.TrailWisps and tier >= (VFX.TrailWisps.FromRarity or 1) then
		table.insert(handle.Emitters, addWisps(rig, row, size))
	end
end

-- One Bits row of a trail style (Config.BallVfx.TrailStyles): particles left hanging in the world behind the ball.
-- colors = the trail's own colours, for rows without their own. power = Config.BallVfx.StylePower for the tier.
local function addBits(rig: BasePart, row, size: number, colors: { Color3 }, power: number)
	local radius = (row.Radius or 0.5) * size
	local holder = weldedPart(rig, "TrailBits", Vector3.one * radius * 2, CFrame.identity)
	holder.Shape = Enum.PartType.Ball
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = IMAGES[row.Image] or row.Image
	emitter.Color = colorSequence(row.Colors or colors)
	emitter.LightEmission = row.Emission or 0.5
	emitter.LightInfluence = if (row.Emission or 0.5) > 0 then 0 else 1
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	local grow = (0.85 + power * 0.15) * size
	local s = row.Size
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, s[1] * grow),
		NumberSequenceKeypoint.new(0.3, s[2] * grow),
		NumberSequenceKeypoint.new(1, s[3] * grow),
	})
	local solid = row.Transparency or 0
	if row.Twinkle then
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.15, solid),
			NumberSequenceKeypoint.new(0.35, 0.6 + solid * 0.4),
			NumberSequenceKeypoint.new(0.55, solid),
			NumberSequenceKeypoint.new(1, 1),
		})
	else
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.1, solid),
			NumberSequenceKeypoint.new(0.6, solid + (1 - solid) * 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	emitter.Lifetime = NumberRange.new(row.Life[1], row.Life[2])
	emitter.Speed = NumberRange.new(row.Speed[1] * size, row.Speed[2] * size)
	emitter.Acceleration = Vector3.new(0, (row.Rise or 0) * size, 0)
	emitter.Drag = row.Drag or 1
	if not row.Upright then
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-(row.Spin or 0), row.Spin or 0)
	end
	emitter.Brightness = row.Bright or 1
	emitter.Rate = row.Rate * power
	emitter.Parent = holder
	return emitter
end

-- A streak painted flat on the lane under the ball (frozen lane, goo, scorch)
local function addFloor(rig: BasePart, row, size: number, colors: { Color3 })
	local width = row.Width * size
	local height = -size / 2 + 0.04
	local left = Instance.new("Attachment")
	left.Position = Vector3.new(-width / 2, height, 0)
	left.Parent = rig
	local right = Instance.new("Attachment")
	right.Position = Vector3.new(width / 2, height, 0)
	right.Parent = rig
	local trail = Instance.new("Trail")
	trail.Name = "FloorTrail"
	trail.Attachment0 = left
	trail.Attachment1 = right
	trail.FaceCamera = false
	trail.Texture = IMAGES.TrailSoft
	trail.Color = colorSequence(row.Colors or colors)
	local solid = row.Transparency or 0.4
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, solid),
		NumberSequenceKeypoint.new(0.6, solid + (1 - solid) * 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = row.Lifetime
	trail.LightEmission = row.Emission or 0.5
	trail.LightInfluence = 0
	trail.MinLength = 0.05
	trail.Parent = rig
end

-- Mythic: flat glowing rings that spread out across the lane from under the ball
local function addShockwave(rig: BasePart, row, size: number, colors: { Color3 })
	local spot = Instance.new("Attachment")
	spot.Position = Vector3.new(0, -size / 2 + 0.06, 0)
	spot.Parent = rig
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = IMAGES.Ring
	emitter.Color = colorSequence(colors)
	emitter.LightEmission = row.Emission
	emitter.LightInfluence = 0
	-- Moving straight up (barely) and drawn flat across that motion = lying on the floor
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.SpreadAngle = Vector2.zero
	emitter.Speed = NumberRange.new(0.01)
	emitter.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	emitter.Size = NumberSequence.new(row.Size[1] * size, row.Size[2] * size)
	emitter.Transparency = NumberSequence.new(row.Transparency, 1)
	emitter.Lifetime = NumberRange.new(row.Life)
	emitter.Rate = row.Rate
	emitter.Parent = spot
	return emitter
end

-- Adds a trail style's bits, floor streak and light (Config.BallVfx.TrailStyles) for a ball of this tier
local function addStyle(rig: BasePart, style, size: number, handle, tier: number, colors: { Color3 }, hasLight: boolean)
	local power = VFX.StylePower[tier] or 1
	for _, row in style.Bits or {} do
		if tier >= (row.FromRarity or 1) then
			table.insert(handle.Emitters, addBits(rig, row, size, colors, power))
		end
	end
	local floor = style.Floor
	if floor and tier >= (floor.FromRarity or 1) then
		addFloor(rig, floor, size, colors)
	end
	if tier >= 6 and VFX.MythicShockwave then
		table.insert(handle.Emitters, addShockwave(rig, VFX.MythicShockwave, size, colors))
	end
	handle.Flicker = style.Flicker or 0
	local lightRow = style.Light
	if lightRow and tier >= 3 and not hasLight then -- a ball with its own glow keeps just that one
		local light = Instance.new("PointLight")
		light.Name = "StyleLight"
		light.Color = lightRow.Color
		light.Brightness = lightRow.Brightness * power
		light.Range = math.max(lightRow.Range * size, 4)
		light.Parent = rig
		if lightRow.Flicker then
			handle.FlickerLights = { { Light = light, Amount = lightRow.Flicker } }
		end
	end
end

-- Spins a twisting ribbon around the ball's path, sways it and flickers its brightness
local function moveTrail(motion, t: number)
	local angle = motion.Phase + t * motion.Twist * 2 * math.pi
	local half = Vector3.new(math.sin(angle), math.cos(angle), 0) * motion.Half
	local sway = Vector3.zero
	if motion.Wobble > 0 then
		sway = Vector3.new(math.noise(t * 3, motion.Seed), math.noise(t * 3, motion.Seed + 7), 0) * motion.Wobble * 2
	end
	motion.Top.Position = sway + half
	motion.Bottom.Position = sway - half
	if motion.Shimmer > 0 then
		motion.Trail.Brightness = math.max(0.2, 1 + motion.Shimmer * math.noise(t * 9, motion.Seed + 13) * 2) * VFX.Dim
	end
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
	return gui, label
end

-- A trail row sized for its tier (Config.BallVfx.TrailTiers) and Power Level, in the worn cosmetic's colours if any
local function tieredRow(row, tier: number, level: number, colors: { Color3 }?)
	local grow = VFX.TrailTiers[tier] or VFX.TrailTiers[1]
	local steps = math.max(level - Config.Throw.PowerTrailFromLevel + 1, 0)
	local copy = table.clone(row)
	copy.Width = row.Width * grow.Width * (1 + steps * VFX.TrailPerLevel.Width)
	copy.Lifetime = row.Lifetime * grow.Lifetime * (1 + steps * VFX.TrailPerLevel.Lifetime)
	copy.Bright = grow.Bright
	if colors then
		copy.Colors = colors
		copy.BodyTexture = nil -- a texture with its own colours (rainbow) would hide the cosmetic's
		copy.Glow = nil
	end
	return copy
end

-- Adds the effects for ballId to a ball part. Lane balls get moved with :Move() every frame;
-- held balls are followed automatically. Returns a handle with :Move, :SetEnabled and :Destroy.
-- options (lane balls): Level = the thrower's Power Level (grows the trail), TrailColors = a worn cosmetic
-- trail's colours, which replace the ball's own trail colours (one trail, never a second one on top),
-- TrailStyle + TrailTier = the cosmetic's style (Config.BallVfx.TrailStyles) and richness, replacing the ball's
function BallFx.Attach(
	ball: BasePart,
	ballId: string?,
	mode: Mode,
	forward: Vector3?,
	options: { Level: number?, TrailColors: { Color3 }?, TrailStyle: string?, TrailTier: number?, Others: boolean? }?
)
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
		Pieces = {},
		Halos = {}, -- halos that turn or pulse
		Badge = nil,
		BadgeHeight = 0,
		Emitters = {},
		Trails = {},
		Motions = {},
		Clock = 0,
		Flicker = 0, -- how much the trails flicker (fire, electric trail styles)
		FlickerLights = nil,
		TrailBright = {},
		MotionSpeed = 1, -- slow-motion can lower this so the trail's motion slows with the ball
		Enabled = true,
		Others = options ~= nil and options.Others == true, -- another player's ball
	}

	if isLane then
		local colors = options and options.TrailColors
		local tier = Balls.RarityIndex(info.Rarity)
		if colors then
			tier = math.max(tier, options.TrailTier or VFX.CosmeticTrailTier)
		end
		local level = options and options.Level or 1
		local main = nil -- the first plain row gets every layer (a bolt row with its own Texture doesn't count)
		for index, row in look.Trails or {} do
			if not row.Texture then
				main = main or index
			end
		end
		for index, row in look.Trails or {} do
			addTrail(rig, tieredRow(row, tier, level, colors), size, handle, tier, index == main)
		end
		-- The style: what the trail looks like it's made of (a worn cosmetic's, else the ball's own, else stardust)
		local styleName = (options and options.TrailStyle) or VFX.BallStyles[info.Id] or "Stardust"
		local style = VFX.TrailStyles[styleName] or VFX.TrailStyles.Stardust
		local mainRow = look.Trails and main and look.Trails[main]
		local trailColors = colors or (mainRow and mainRow.Colors) or { info.Trail }
		addStyle(rig, style, size, handle, tier, trailColors, look.Light ~= nil)
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
	local pieceFolder = look.Pieces and ReplicatedStorage:FindFirstChild("BallFxPieces")
	local pieceSource = pieceFolder and pieceFolder:FindFirstChild(info.Id)
	if pieceSource then
		-- Stored with a 1-stud ball and the pivot at its centre, like BallModels
		local pieces = pieceSource:Clone()
		pieces:ScaleTo(size)
		pieces:PivotTo(CFrame.new())
		for _, part in pieces:GetChildren() do
			if not part:IsA("BasePart") then
				continue
			end
			local offset = part.CFrame
			part.Anchored = false
			part.CFrame = rig.CFrame * offset
			local weld = Instance.new("Weld")
			weld.Part0 = rig
			weld.Part1 = part
			weld.C0 = offset
			weld.Parent = part
			part.Parent = rig
			table.insert(handle.Pieces, { Weld = weld, Offset = offset, Speed = look.Pieces[part.Name] or 0 })
		end
		pieces:Destroy()
	end
	for _, row in look.Halos or {} do
		local gui, label = addHalo(rig, row, size)
		if row.Spin or row.Pulse then
			-- turning rays and breathing glows (zone 4 balls)
			table.insert(handle.Halos, {
				Gui = gui,
				Label = label,
				Size = row.Size * size,
				Spin = row.Spin or 0,
				Pulse = row.Pulse,
				Seed = math.random() * 10,
			})
		end
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
		if lightRow.Flicker then
			handle.FlickerLights = handle.FlickerLights or {}
			table.insert(handle.FlickerLights, { Light = light, Amount = lightRow.Flicker })
		end
	end
	BallFx.Dim(rig)
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Trail") then
			table.insert(handle.Trails, descendant)
			handle.TrailBright[descendant] = descendant.Brightness
		end
	end

	function handle.Move(_, position: Vector3)
		rig.CFrame = CFrame.lookAt(position, position + direction)
	end

	function handle.SetEnabled(_, enabled: boolean)
		handle.Enabled = enabled
		local shown = enabled and Settings.Get("Vfx") and (not handle.Others or Settings.Get("OthersVfx"))
		rig.Parent = if shown then ball.Parent else nil
		for _, emitter in handle.Emitters do
			emitter.Enabled = shown
		end
	end

	function handle.Destroy()
		active[handle] = nil
		rig:Destroy()
	end

	for _, ring in handle.Rings do
		placeRing(ring, 0)
	end
	ball.Destroying:Connect(handle.Destroy)
	active[handle] = true
	handle:SetEnabled(true)
	return handle
end

-- SETTINGS: EFFECTS or OTHER PLAYERS' EFFECTS switched: hide or bring back the balls' effects
local function refreshAll()
	for handle in active do
		handle:SetEnabled(handle.Enabled)
	end
end
Settings.Changed("Vfx", refreshAll)
Settings.Changed("OthersVfx", refreshAll)

-- One loop turns every ring, spins the disks, bobs the badges and keeps held effects on their ball
RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local camera = workspace.CurrentCamera
	local cameraPosition = camera and camera.CFrame.Position or Vector3.zero
	for handle in active do
		if not handle.Enabled or not handle.Rig.Parent then -- off, or hidden by SETTINGS: EFFECTS
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
		handle.Clock += dt * handle.MotionSpeed
		for _, motion in handle.Motions do
			moveTrail(motion, handle.Clock)
		end
		if handle.Flicker > 0 then
			local flick = 1 + handle.Flicker * math.noise(handle.Clock * 11, 3.7)
			for trail, bright in handle.TrailBright do
				trail.Brightness = bright * flick
			end
		end
		for _, row in handle.FlickerLights or {} do
			row.Base = row.Base or row.Light.Brightness
			row.Light.Brightness = row.Base * math.max(0.2, 1 + row.Amount * math.noise(handle.Clock * 13, 9.1) * 1.5)
		end
		for _, ring in handle.Rings do
			placeRing(ring, t)
		end
		for _, spinner in handle.Spinners do
			spinner.Label.Rotation = (t * spinner.Speed) % 360
		end
		for _, halo in handle.Halos do
			halo.Label.Rotation = (t * halo.Spin) % 360
			if halo.Pulse then
				local grow = 1 + halo.Pulse[2] * math.sin((t + halo.Seed) * halo.Pulse[1] * math.pi * 2)
				halo.Gui.Size = UDim2.fromScale(halo.Size * grow, halo.Size * grow)
			end
		end
		for _, piece in handle.Pieces do
			piece.Weld.C0 = CFrame.Angles(0, math.rad(t * piece.Speed % 360), 0) * piece.Offset
		end
		if handle.Badge then
			handle.Badge.StudsOffsetWorldSpace = Vector3.new(0, handle.BadgeHeight + math.sin(t * 2.5) * 0.08, 0)
		end
	end
end)

return BallFx
