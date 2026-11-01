-- Addendum 5 D: every ladder ball's own signature effect (Config.CoreLoop.BallEffects, Fx on each ball row).
-- Visual and feel only: nothing here touches a number. Strength (0..1) grows with the real pin count of the throw,
-- so a stronger ball (or the same ball with pets and rebirths) looks and feels bigger although only 40 pins fall.
-- Roll() adds the ball's travel extra (fire, hops, dust, snow, sonic rings), Impact() plays its hit at the rack.
-- Built from the game's own images (Config.BallVfx.Images), Roblox particles and sounds already in Sfx: no new art.
-- SETTINGS: EFFECTS off = no signature visuals (the sounds stay); SCREEN SHAKE off = no shake (CameraShake/ThrowFx).
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Settings = require(script.Parent:WaitForChild("Settings"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local ThrowFx = require(script.Parent:WaitForChild("ThrowFx"))
local UiFx = require(script.Parent:WaitForChild("UiFx"))
local CameraShake = require(script.Parent:WaitForChild("CameraShake"))
local LaneFx = require(script.Parent:WaitForChild("LaneFx"))

local CORE = Config.CoreLoop
local FX = CORE.BallEffects
local IMAGES = Config.BallVfx.Images
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local WHITE = Color3.new(1, 1, 1)
local RAINBOW = {
	Color3.fromHex("FF4D6D"),
	Color3.fromHex("FF9A3C"),
	Color3.fromHex("FFE45A"),
	Color3.fromHex("6CF06C"),
	Color3.fromHex("4AB8FF"),
	Color3.fromHex("B48CFF"),
}
local CONFETTI =
	{ Color3.fromHex("FF5AD2"), Color3.fromHex("3CE6FF"), Color3.fromHex("FFF05A"), Color3.fromHex("78FF78") }

local BallSignature = {}

local folder = Instance.new("Folder")
folder.Name = "BallSignature"
folder.Parent = Workspace

local byBall = {}
for _, row in CORE.Balls do
	if row.Fx then
		byBall[row.Ball] = row.Fx
	end
end

-- 0 at From pins, 1 at Full pins (log scale)
function BallSignature.Strength(count: number): number
	local from = math.max(FX.From, 1)
	local full = math.max(FX.Full, from + 1)
	return math.clamp(math.log(math.max(count, 1) / from) / math.log(full / from), 0, 1)
end

-- The effect a ball plays: its name and Config row (nil for balls off the ladder or with the effects off)
function BallSignature.For(ballId: string?): (string?, any)
	local name = FX and FX.Enabled and ballId and byBall[ballId]
	if not name then
		return nil, nil
	end
	return name, FX.Effects[name]
end

local function vfx(): boolean
	return Settings.Get("Vfx")
end

local function tween(
	object: Instance,
	time: number,
	goals: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	TweenService
		:Create(
			object,
			TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
			goals
		)
		:Play()
end

local function holder(position: Vector3, life: number, size: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = "Signature"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.one * 0.2
	p.CFrame = CFrame.new(position)
	p.Parent = folder
	Debris:AddItem(p, life)
	return p
end

local function colors(list: { Color3 }): ColorSequence
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local keys = {}
	for i, color in list do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#list - 1), color))
	end
	return ColorSequence.new(keys)
end

-- One burst of particles. o: Image, Colors, Count, Size, EndSize, Life {a, b}, Speed {a, b}, Spread, Accel,
-- Drag, Emission, Spin, Direction (NormalId), Fade, Inward (radius: particles start on a sphere and rush in)
local function puff(position: Vector3, o)
	local life = o.Life or { 0.3, 0.6 }
	local p = holder(position, life[2] + 0.4, if o.Inward then Vector3.one * o.Inward * 2 else nil)
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.Image or SPARKLE
	e.Color = colors(o.Colors or { WHITE })
	e.LightEmission = o.Emission or 1
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.Size or 0.5),
		NumberSequenceKeypoint.new(1, o.EndSize or 0),
	})
	e.Transparency = NumberSequence.new(o.Fade or 0, 1)
	e.Lifetime = NumberRange.new(life[1], life[2])
	local speed = o.Speed or { 4, 8 }
	e.Speed = NumberRange.new(speed[1], speed[2])
	e.SpreadAngle = Vector2.new(o.Spread or 180, o.Spread or 180)
	e.Acceleration = o.Accel or Vector3.zero
	e.Drag = o.Drag or 3
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(o.Spin or 0), o.Spin or 0)
	e.EmissionDirection = o.Direction or Enum.NormalId.Top
	if o.Inward then
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	end
	e.Rate = 0
	e.Parent = p
	e:Emit(math.max(1, math.floor(o.Count or 10)))
end

-- A soft glow that blooms and fades (plus a quick light)
local function glow(position: Vector3, color: Color3, studs: number, time: number, light: number?)
	local p = holder(position, time + 0.3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(studs * 0.3, studs * 0.3)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = p
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = IMAGES.Dot
	image.ImageColor3 = color
	image.ImageTransparency = 0.15
	image.Parent = gui
	tween(gui, time * 0.6, { Size = UDim2.fromScale(studs, studs) })
	tween(image, time, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	if light and light > 0 then
		local l = Instance.new("PointLight")
		l.Color = color
		l.Range = 10 + studs
		l.Brightness = light
		l.Parent = p
		tween(l, time * 1.5, { Brightness = 0 })
	end
end

-- An image (Ring, Spiral, Burst...) that faces the camera, grows from `from` to `to` studs and fades
local function sprite(
	position: Vector3,
	image: string,
	color: Color3,
	from: number,
	to: number,
	time: number,
	spin: number?
)
	local p = holder(position, time + 0.2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(from, from)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = p
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Image = image
	label.ImageColor3 = color
	label.Parent = gui
	tween(gui, time, { Size = UDim2.fromScale(to, to) })
	tween(label, time, { ImageTransparency = 1, Rotation = spin or 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

-- A flat ring image on the lane that rushes outward
local function floorRing(position: Vector3, color: Color3, radius: number, time: number, image: string?)
	local p = holder(position, time + 0.2, Vector3.new(1, 0.05, 1))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(256, 256)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = p
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Image = image or IMAGES.Ring
	label.ImageColor3 = color
	label.Parent = gui
	tween(p, time, { Size = Vector3.new(radius * 2, 0.05, radius * 2) })
	tween(label, time, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

local function point(position: Vector3, axis: Vector3?): Attachment
	local a = Instance.new("Attachment")
	if axis then
		a.CFrame = CFrame.fromMatrix(
			position,
			axis.Unit,
			Vector3.yAxis:Cross(axis.Unit).Magnitude > 0.1 and Vector3.yAxis or Vector3.xAxis
		)
	else
		a.Position = position
	end
	a.Parent = Workspace.Terrain
	return a
end

-- A glowing ribbon between two world points (Beam on two Terrain attachments), gone after `life`
local function ribbon(from: Vector3, to: Vector3, o): (Beam, Attachment, Attachment)
	local a0 = point(from, o.Axis0)
	local a1 = point(to, o.Axis1)
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Texture = o.Texture or IMAGES.TrailSoft
	beam.TextureMode = o.Mode or Enum.TextureMode.Stretch
	beam.TextureLength = o.Length or 1
	beam.TextureSpeed = o.Speed or 0
	beam.Color = colors(o.Colors or { WHITE })
	beam.LightEmission = o.Emission or 1
	beam.LightInfluence = 0
	beam.Brightness = 2
	beam.Width0 = o.Width or 1
	beam.Width1 = o.Width1 or o.Width or 1
	beam.CurveSize0 = o.Curve0 or 0
	beam.CurveSize1 = o.Curve1 or 0
	beam.Segments = o.Segments or 10
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new(o.Transparency or 0)
	beam.Parent = Workspace.Terrain
	Debris:AddItem(beam, o.Life)
	Debris:AddItem(a0, o.Life)
	Debris:AddItem(a1, o.Life)
	return beam, a0, a1
end

local function fadeRibbon(beam: Beam, delay: number, time: number)
	task.delay(delay, function()
		local start = os.clock()
		while beam.Parent and os.clock() - start < time do
			beam.Transparency = NumberSequence.new(math.clamp((os.clock() - start) / time, 0, 1))
			RunService.Heartbeat:Wait()
		end
	end)
end

---------------------------------------------------------------------------------------------------------------
-- Travel extras: Roll(ball, name, strength, forward) returns { Lift = fn(progress) -> studs up, Step = fn(pos) }
---------------------------------------------------------------------------------------------------------------
local function trailEmitter(ball: BasePart, o)
	local e = Instance.new("ParticleEmitter")
	e.Name = "SignatureRoll"
	e.Texture = o.Image
	e.Color = colors(o.Colors)
	e.LightEmission = o.Emission or 0.5
	e.Size = NumberSequence.new(o.Size, o.EndSize or 0)
	e.Transparency = NumberSequence.new(o.Fade or 0.2, 1)
	e.Lifetime = NumberRange.new(o.Life[1], o.Life[2])
	e.Speed = NumberRange.new(o.Speed[1], o.Speed[2])
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = o.Accel or Vector3.zero
	e.Drag = 2
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-(o.Spin or 0), o.Spin or 0)
	e.LockedToPart = false
	e.Rate = o.Rate
	e.Parent = ball
end

function BallSignature.Roll(ball: BasePart, name: string?, t: number, _forward: Vector3)
	local handle = {}
	local row = name and FX.Effects[name]
	if not row then
		return handle
	end
	local d = ball.Size.X
	if name == "Bounce" or name == "BeachBall" then
		-- Rubber Bouncer hops down the lane (lower and lower), landing on the head pin; the Beach Ball takes one big hop
		local hops = row.Hops or 3
		local height = (row.HopHeight or 1.4) * (1 + t)
		function handle.Lift(progress: number): number
			return math.abs(math.sin(math.clamp(progress, 0, 1) * math.pi * hops)) * height * (1 - progress * 0.6)
		end
	end
	if not vfx() then
		return handle
	end
	if name == "Sand" then
		trailEmitter(ball, {
			Image = IMAGES.Smoke,
			Colors = { Color3.fromHex("F7DCA8"), Color3.fromHex("E2B26A") },
			Rate = 12 + 30 * t,
			Size = d * 0.5,
			EndSize = d * 1.1,
			Life = { 0.3, 0.6 },
			Speed = { 0.5, 2 },
			Emission = 0,
			Fade = 0.35,
		})
	elseif name == "Confetti" then
		trailEmitter(ball, {
			Image = SQUARE,
			Colors = CONFETTI,
			Rate = 15 + 40 * t,
			Size = 0.18,
			EndSize = 0.18,
			Life = { 0.4, 0.8 },
			Speed = { 2, 5 },
			Accel = Vector3.new(0, -14, 0),
			Emission = 0.4,
			Spin = 300,
			Fade = 0,
		})
	elseif name == "Burn" then
		local fire = Instance.new("Fire")
		fire.Name = "SignatureFire"
		fire.Size = d * (1.6 + 2.4 * t)
		fire.Heat = 6 + 10 * t
		fire.Color = Color3.fromHex("FF9A2E")
		fire.SecondaryColor = Color3.fromHex("C8320A")
		fire.Parent = ball
	elseif name == "Frost" then
		trailEmitter(ball, {
			Image = IMAGES.Snowflake,
			Colors = { WHITE, Color3.fromHex("BFEFFF") },
			Rate = 14 + 40 * t,
			Size = 0.3,
			EndSize = 0.1,
			Life = { 0.4, 0.9 },
			Speed = { 1, 3 },
			Emission = 0.6,
			Spin = 180,
		})
	elseif name == "Shell" then
		trailEmitter(ball, {
			Image = IMAGES.Dot,
			Colors = { WHITE, Color3.fromHex("FFD6E8"), Color3.fromHex("CFF6FF") },
			Rate = 14 + 30 * t,
			Size = 0.22,
			EndSize = 0.05,
			Life = { 0.4, 0.8 },
			Speed = { 0.5, 2 },
			Emission = 0.8,
		})
	elseif name == "Kite" then
		trailEmitter(ball, {
			Image = IMAGES.Diamond,
			Colors = RAINBOW,
			Rate = 10 + 24 * t,
			Size = 0.35,
			EndSize = 0.1,
			Life = { 0.5, 1 },
			Speed = { 1, 3 },
			Accel = Vector3.new(0, 8, 0),
			Emission = 0.5,
			Spin = 200,
		})
	elseif name == "Tide" or name == "Coral" or name == "Surf" or name == "Tsunami" then
		-- sea spray: foam behind the ball and droplets (more, and bigger, the bigger the wave)
		local big = if name == "Tsunami" then 1.6 elseif name == "Surf" then 1.25 else 1
		local tint = if name == "Coral" then Color3.fromHex("FFB0A0") else Color3.fromHex("9BE9FF")
		trailEmitter(ball, {
			Image = IMAGES.Smoke,
			Colors = { WHITE, Color3.fromHex("DDF8FF") },
			Rate = (10 + 24 * t) * big,
			Size = d * 0.5 * big,
			EndSize = d * 1.2 * big,
			Life = { 0.25, 0.5 },
			Speed = { 1, 3 },
			Emission = 0.1,
			Fade = 0.35,
		})
		trailEmitter(ball, {
			Image = if name == "Coral" then IMAGES.Bubble else IMAGES.Dot,
			Colors = { WHITE, tint },
			Rate = (12 + 30 * t) * big,
			Size = 0.25,
			EndSize = 0.08,
			Life = { 0.4, 0.8 },
			Speed = { 3, 6 * big },
			Accel = Vector3.new(0, if name == "Coral" then 6 else -18, 0),
			Emission = 0.5,
		})
	elseif name == "Splash" then
		trailEmitter(ball, {
			Image = IMAGES.Dot,
			Colors = { Color3.fromHex("FFD45A"), Color3.fromHex("FF8A5A"), Color3.fromHex("FF5A8A") },
			Rate = 16 + 36 * t,
			Size = 0.28,
			EndSize = 0.06,
			Life = { 0.4, 0.7 },
			Speed = { 3, 7 },
			Accel = Vector3.new(0, -20, 0),
			Emission = 0.6,
		})
	elseif name == "Pound" then
		trailEmitter(ball, {
			Image = IMAGES.Smoke,
			Colors = { Color3.fromHex("E8CFA8"), Color3.fromHex("B8925E") },
			Rate = 10 + 20 * t,
			Size = d * 0.6,
			EndSize = d * 1.4,
			Life = { 0.3, 0.6 },
			Speed = { 0.5, 2 },
			Emission = 0,
			Fade = 0.4,
		})
	elseif name == "Lighthouse" then
		-- a golden spotlight follows the ball down the lane
		local gap = 0.06
		local last = 0
		function handle.Step(position: Vector3)
			local now = os.clock()
			if now - last < gap then
				return
			end
			last = now
			glow(position, Color3.fromHex("FFE27A"), d * (2.5 + 2 * t), 0.35)
		end
	elseif name == "BlackHole" then
		-- Sonic Boom: rings peel off the ball like it breaks the sound barrier
		local gap = 0.07 - 0.03 * t
		local last = 0
		function handle.Step(position: Vector3)
			local now = os.clock()
			if now - last < gap then
				return
			end
			last = now
			sprite(
				position,
				IMAGES.Ring,
				Color3.fromHex("FFD9F0"):Lerp(Color3.fromHex("B45CFF"), math.random()),
				d * 1.2,
				d * (3 + 3 * t),
				0.25
			)
		end
	end
	return handle
end

---------------------------------------------------------------------------------------------------------------
-- Impacts. ctx: Lane, Rack, Hit, Center, Forward, Right, T, Big, Pins (rack indices that fall), Color
---------------------------------------------------------------------------------------------------------------
local impacts = {}

-- 1 Beach Roller: a puff of sand and a small ring
function impacts.Sand(c)
	local t = c.T
	puff(c.Hit, {
		Image = IMAGES.Smoke,
		Colors = { Color3.fromHex("FBE3B4"), Color3.fromHex("E2B26A") },
		Count = 6 + 24 * t,
		Size = 1,
		EndSize = 2 + t,
		Life = { 0.4, 0.8 },
		Speed = { 4, 10 + 10 * t },
		Spread = 70,
		Accel = Vector3.new(0, -8, 0),
		Emission = 0,
		Fade = 0.3,
	})
	ThrowFx.Shockwave(c.Floor, c.Color, 3 + 7 * t, 0.3)
end

-- 2 Rubber Bouncer: a bubble-gum pop
function impacts.Bounce(c)
	local t = c.T
	puff(c.Hit, {
		Image = IMAGES.Bubble,
		Colors = { Color3.fromHex("FFC2E8"), Color3.fromHex("FF7AC8") },
		Count = 8 + 30 * t,
		Size = 0.6 + 0.4 * t,
		EndSize = 0.2,
		Life = { 0.4, 0.9 },
		Speed = { 8, 16 + 10 * t },
		Accel = Vector3.new(0, 6, 0),
		Emission = 0.3,
	})
	floorRing(c.Floor, c.Color, 4 + 8 * t, 0.35)
	glow(c.Hit, c.Color, 4 + 4 * t, 0.3)
	Sfx.PlayAt("Tap", c.Lane.PinSpot, 0.55 + math.random() * 0.1, 0.8)
end

-- 3 Confetti Popper: a confetti cannon over the pins
function impacts.Confetti(c)
	local t = c.T
	puff(c.Hit + Vector3.new(0, 1, 0), {
		Image = SQUARE,
		Colors = CONFETTI,
		Count = 14 + 40 * t,
		Size = 0.3,
		EndSize = 0.3,
		Life = { 0.8, 1.4 },
		Speed = { 14, 24 + 10 * t },
		Spread = 40,
		Accel = Vector3.new(0, -26, 0),
		Drag = 2,
		Emission = 0.4,
		Spin = 400,
		Fade = 0,
	})
	for i = 1, 2 do
		ThrowFx.Burst(c.Hit + c.Right * (i == 1 and -2 or 2), CONFETTI[i + 1], 10 + 20 * t, 16, 0.5)
	end
	if c.Big then
		LaneFx.Confetti(c.Lane, 20 + 60 * t)
	end
	Sfx.PlayAt("Firework", c.Lane.PinSpot, 1.4 + math.random() * 0.2, 0.3 + 0.4 * t)
end

-- 4 Sunspike: a burst of flames, an ember shower, and the pins it hits burn for a moment
function impacts.Burn(c)
	local t = c.T
	puff(c.Hit, {
		Image = IMAGES.FlameTongue,
		Colors = { Color3.fromHex("FFF0A0"), Color3.fromHex("FF9A2E"), Color3.fromHex("D8320A") },
		Count = 8 + 30 * t,
		Size = 1.2 + 1.2 * t,
		EndSize = 0.3,
		Life = { 0.3, 0.6 },
		Speed = { 6, 14 + 10 * t },
		Spread = 60,
		Accel = Vector3.new(0, 12, 0),
		Spin = 90,
	})
	puff(c.Hit, {
		Image = IMAGES.Ember,
		Colors = { Color3.fromHex("FFE9A0"), Color3.fromHex("FF7A1A") },
		Count = 15 + 60 * t,
		Size = 0.25,
		Life = { 0.5, 1 },
		Speed = { 8, 20 + 10 * t },
		Accel = Vector3.new(0, 6, 0),
		Drag = 2,
	})
	for i, index in c.Pins do
		if i > 3 + 6 * t then
			break
		end
		local pin = c.Rack.Pins[index]
		local body = pin and pin.PrimaryPart
		if body then
			puff(body.Position, {
				Image = IMAGES.Flame,
				Colors = { Color3.fromHex("FFE070"), Color3.fromHex("FF6A1A") },
				Count = 4,
				Size = 0.9,
				Life = { 0.3, 0.5 },
				Speed = { 1, 3 },
				Accel = Vector3.new(0, 10, 0),
			})
		end
	end
	ThrowFx.Shockwave(c.Floor, c.Color, 4 + 9 * t, 0.3)
	glow(c.Hit, c.Color, 6 + 6 * t, 0.35, 4 + 4 * t)
end

-- 5 Gust: an icy gust blows the rack sideways (snowflakes and frost streaks)
function impacts.Frost(c)
	local t = c.T
	local side = c.Right * (40 + 30 * t)
	puff(c.Center - c.Right * 5, {
		Image = IMAGES.Snowflake,
		Colors = { WHITE, Color3.fromHex("BFEFFF"), Color3.fromHex("6CCBFF") },
		Count = 12 + 40 * t,
		Size = 0.6 + 0.4 * t,
		EndSize = 0.2,
		Life = { 0.5, 1 },
		Speed = { 4, 10 },
		Accel = side,
		Drag = 1,
		Emission = 0.6,
		Spin = 240,
	})
	puff(c.Center - c.Right * 6, {
		Image = IMAGES.Smoke,
		Colors = { WHITE, Color3.fromHex("DDF4FF") },
		Count = 5 + 15 * t,
		Size = 1.6,
		EndSize = 2.5,
		Life = { 0.4, 0.7 },
		Speed = { 2, 4 },
		Accel = side * 0.8,
		Emission = 0.2,
		Fade = 0.4,
	})
	floorRing(c.Floor, Color3.fromHex("CFF4FF"), 5 + 8 * t, 0.4, IMAGES.Snowflake)
	ThrowFx.Shockwave(c.Floor, c.Color, 4 + 8 * t, 0.3)
	Sfx.PlayAt("Teleport", c.Lane.PinSpot, 1.3 + math.random() * 0.1, 0.3 + 0.3 * t)
end

-- 6 Cloud Roll: two cloud arms reach out of the ball and sweep round both sides of the rack
function impacts.Arms(c)
	local t = c.T
	local width = 1.2 + 1.8 * t
	local reach = 5 + 4 * t
	local from = c.Hit + Vector3.new(0, 1, 0)
	local back = c.Center + c.Forward * (4 + 2 * t) + Vector3.new(0, 1.2, 0)
	for _, s in { -1, 1 } do
		local beam, _, a1 = ribbon(from, from + c.Forward * 0.5, {
			Texture = IMAGES.TrailWisp,
			Mode = Enum.TextureMode.Wrap,
			Length = 3,
			Speed = 2,
			Colors = { WHITE, Color3.fromHex("CFEBFF"), Color3.fromHex("7CC4F5") },
			Emission = 0.6,
			Width = width * 0.6,
			Width1 = width,
			Axis0 = c.Right * s,
			Axis1 = -c.Right * s,
			Curve0 = reach,
			Curve1 = reach * 0.8,
			Life = 0.75,
		})
		tween(a1, 0.18, { Position = back + c.Right * s * 1.5 }, Enum.EasingStyle.Quart)
		fadeRibbon(beam, 0.3, 0.4)
		task.delay(0.16, function()
			puff(back + c.Right * s * 1.5, {
				Image = IMAGES.Smoke,
				Colors = { WHITE, Color3.fromHex("DDF0FF") },
				Count = 4 + 10 * t,
				Size = 1.4,
				EndSize = 2.4,
				Life = { 0.3, 0.6 },
				Speed = { 2, 5 },
				Emission = 0.2,
				Fade = 0.3,
			})
		end)
	end
	puff(c.Hit, {
		Image = IMAGES.Star,
		Colors = { WHITE, Color3.fromHex("8FD0FF") },
		Count = 8 + 24 * t,
		Size = 0.4,
		Life = { 0.3, 0.6 },
		Speed = { 6, 14 },
		Spin = 180,
	})
	ThrowFx.Shockwave(c.Floor, c.Color, 4 + 9 * t, 0.35)
end

-- 7 Rainbow Arc: rainbow rings ripple out, crystal shards fly, and a rainbow arcs over the rack
function impacts.Prism(c)
	local t = c.T
	for i, color in RAINBOW do
		task.delay((i - 1) * 0.04, function()
			floorRing(c.Floor + Vector3.new(0, i * 0.02, 0), color, (3 + i * 1.2) * (1 + t), 0.4)
		end)
	end
	puff(c.Hit, {
		Image = IMAGES.Diamond,
		Colors = RAINBOW,
		Count = 10 + 40 * t,
		Size = 0.45,
		Life = { 0.3, 0.7 },
		Speed = { 10, 20 + 10 * t },
		Spread = 90,
		Accel = Vector3.new(0, -10, 0),
		Spin = 300,
	})
	if c.Big then
		local half = 6 + 5 * t
		local beam = ribbon(c.Center - c.Right * half, c.Center + c.Right * half, {
			Texture = IMAGES.TrailRainbow,
			Colors = { WHITE },
			Emission = 0.5,
			Width = 1.6 + 1.6 * t,
			Axis0 = Vector3.yAxis,
			Axis1 = -Vector3.yAxis,
			Curve0 = 6 + 6 * t,
			Curve1 = 6 + 6 * t,
			Transparency = 0.1,
			Life = 0.9,
		})
		fadeRibbon(beam, 0.35, 0.5)
		Sfx.PlayAt("Reveal", c.Lane.PinSpot, 1.5, 0.35)
	end
	glow(c.Hit, WHITE, 5 + 5 * t, 0.3, 3)
end

-- 8 Sunbolt: lightning jumps from the ball to a pin, then pin to pin
function impacts.Bolt(c)
	local t = c.T
	local last = c.Hit + Vector3.new(0, 1.5, 0)
	local hops = math.floor(3 + 9 * t)
	for i, index in c.Pins do
		if i > hops then
			break
		end
		local pin = c.Rack.Pins[index]
		local body = pin and pin.PrimaryPart
		if body then
			local target = body.Position + Vector3.new(0, 0.5, 0)
			local from = last
			task.delay((i - 1) * 0.025, function()
				local beam = ribbon(from, target, {
					Texture = IMAGES.Bolt,
					Colors = { WHITE, Color3.fromHex("FFE45A") },
					Width = 0.9 + 0.6 * t,
					Segments = 1,
					Life = 0.22,
				})
				task.delay(0.07, function()
					beam.Width0 *= 0.5
					beam.Width1 *= 0.5
				end)
				ThrowFx.Burst(target, Color3.fromHex("FFF6B0"), 4 + 8 * t, 10, 0.35)
			end)
			last = target
		end
	end
	glow(c.Hit, c.Color, 6 + 6 * t, 0.25, 6 + 4 * t)
	ThrowFx.Shockwave(c.Floor, c.Color, 4 + 9 * t, 0.25)
	if c.Big and t > 0.25 then
		UiFx.Flash(Color3.fromHex("FFF6C8"), 0.12 + 0.2 * t, 0.2)
	end
	Sfx.PlayAt("OverchargeWarn", c.Lane.PinSpot, 1.8 + math.random() * 0.2, 0.25 + 0.3 * t)
end

-- 9 Tornado: a gold twister spins up from the middle of the rack and lifts the pins
function impacts.Tornado(c)
	local t = c.T
	local base = c.Floor + Vector3.new(0, 0.2, 0)
	local height = 8 + 10 * t
	local time = 0.7
	sprite(base + Vector3.new(0, 1, 0), IMAGES.Spiral, c.Color, 4, 8 + 8 * t, time, 720)
	local strands = {}
	for i = 1, 3 do
		local p = holder(base, time + 0.6)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.3, 0)
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.3, 0)
		a1.Parent = p
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Texture = IMAGES.TrailWisp
		trail.Color = colors({ Color3.fromHex("FFF0B0"), Color3.fromHex("FFD45A"), Color3.fromHex("C98A10") })
		trail.LightEmission = 0.7
		trail.Lifetime = 0.35
		trail.WidthScale = NumberSequence.new(1 + t, 0.2)
		trail.FaceCamera = true
		trail.Parent = p
		strands[i] = p
	end
	local start = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local k = (os.clock() - start) / time
		if k >= 1 then
			connection:Disconnect()
			return
		end
		for i, p in strands do
			local angle = k * math.pi * 6 + i * math.pi * 2 / 3
			local radius = 1 + k * (3 + 3 * t)
			p.CFrame = CFrame.new(base + Vector3.new(math.cos(angle) * radius, k * height, math.sin(angle) * radius))
		end
	end)
	puff(base, {
		Image = IMAGES.Dot,
		Colors = { Color3.fromHex("FFE9A0"), Color3.fromHex("FFC030") },
		Count = 15 + 50 * t,
		Size = 0.3,
		Life = { 0.5, 1 },
		Speed = { 3, 8 },
		Spread = 30,
		Accel = Vector3.new(0, 20 + 10 * t, 0),
		Spin = 200,
	})
	ThrowFx.Shockwave(c.Floor, c.Color, 5 + 9 * t, 0.35)
	Sfx.PlayAt("PowerUp", c.Lane.PinSpot, 1.3, 0.3 + 0.3 * t)
end

-- 10 Sonic Boom: a black hole opens in the rack and pulls everything in, then bursts in a sonic boom
local function boom(c, scale: number)
	local t = c.T
	ThrowFx.Shockwave(c.Floor, WHITE, (10 + 18 * t) * scale, 0.4)
	ThrowFx.Shockwave(c.Floor + Vector3.new(0, 0.05, 0), Color3.fromHex("FF7AB0"), (7 + 12 * t) * scale, 0.35)
	floorRing(c.Floor + Vector3.new(0, 0.1, 0), Color3.fromHex("FFE0B0"), (12 + 20 * t) * scale, 0.5)
	glow(c.Center + Vector3.new(0, 1.5, 0), WHITE, (8 + 14 * t) * scale, 0.35, 8)
	puff(c.Center + Vector3.new(0, 1.5, 0), {
		Colors = { Color3.fromHex("FFE9A0"), Color3.fromHex("FF7AB0"), Color3.fromHex("B45CFF") },
		Count = (30 + 80 * t) * scale,
		Size = 0.7,
		Life = { 0.3, 0.6 },
		Speed = { 20, 40 + 20 * t },
		Drag = 4,
	})
	sprite(
		c.Center + Vector3.new(0, 1.5, 0),
		IMAGES.Burst,
		Color3.fromHex("FFE0B0"),
		3,
		(14 + 14 * t) * scale,
		0.35,
		60
	)
end

function impacts.BlackHole(c)
	local t = c.T
	if not c.Big then
		boom(c, 0.6)
		return
	end
	local at = c.Center + Vector3.new(0, 1.5, 0)
	local hole = holder(at, 0.5, Vector3.one * 0.5)
	hole.Shape = Enum.PartType.Ball
	hole.Transparency = 0
	hole.Color = Color3.new(0, 0, 0)
	hole.Material = Enum.Material.SmoothPlastic
	local edge = Instance.new("Highlight")
	edge.FillTransparency = 1
	edge.OutlineColor = Color3.fromHex("D08CFF")
	edge.DepthMode = Enum.HighlightDepthMode.Occluded
	edge.Parent = hole
	local size = 2.5 + 2.5 * t
	tween(hole, 0.12, { Size = Vector3.one * size }, Enum.EasingStyle.Back)
	sprite(at, IMAGES.Spiral, Color3.fromHex("B45CFF"), size * 3, size * 1.2, 0.2, -540)
	puff(at, {
		Image = IMAGES.Star,
		Colors = { WHITE, Color3.fromHex("D08CFF"), Color3.fromHex("FF7AB0") },
		Count = 20 + 60 * t,
		Size = 0.35,
		Life = { 0.18, 0.25 },
		Speed = { 30, 40 },
		Drag = 0,
		Inward = 7 + 3 * t,
	})
	task.delay(0.16, function()
		tween(hole, 0.06, { Size = Vector3.one * 0.1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
	task.delay(0.22, function()
		hole:Destroy()
		boom(c, 1)
		UiFx.Flash(WHITE, 0.25 + 0.35 * t, 0.3)
		CameraShake.Add(0.3 + 0.5 * t)
		Sfx.PlayAt("OverchargeBlast", c.Lane.PinSpot, 1, 0.6 + 0.4 * t)
	end)
end

---------------------------------------------------------------------------------------------------------------
-- Zone 2, Sunset Boardwalk (Addendum 6 Stage 4): sea and beach effects, one per ball
---------------------------------------------------------------------------------------------------------------
local SEA = { WHITE, Color3.fromHex("9BE9FF"), Color3.fromHex("3CC8E6") }
local SUNSET = { Color3.fromHex("FFE27A"), Color3.fromHex("FF9A5A"), Color3.fromHex("FF5A8A") }
local BEACH = { Color3.fromHex("FF4D4D"), Color3.fromHex("FFE45A"), Color3.fromHex("3C9CFF"), WHITE }

-- A visible part that lives for `life`
local function solid(cframe: CFrame, size: Vector3, color: Color3, life: number, material: Enum.Material?): Part
	local p = holder(cframe.Position, life, size)
	p.CFrame = cframe
	p.Transparency = 0
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	return p
end

-- Water bursting up at one point: droplets and foam (scale 1 = a normal splash)
local function splash(at: Vector3, t: number, scale: number, tint: { Color3 }?)
	puff(at, {
		Image = IMAGES.Dot,
		Colors = tint or SEA,
		Count = (14 + 36 * t) * scale,
		Size = 0.8 * math.sqrt(scale),
		EndSize = 0.3,
		Life = { 0.6, 1 },
		Speed = { 12 * scale, (20 + 12 * t) * scale },
		Spread = 40,
		Accel = Vector3.new(0, -40, 0),
		Drag = 0.5,
		Emission = 0.3,
	})
	puff(at, {
		Image = IMAGES.Smoke,
		Colors = { WHITE, Color3.fromHex("E6FAFF") },
		Count = (6 + 12 * t) * scale,
		Size = 2.4 * scale,
		EndSize = 4.5 * scale,
		Life = { 0.45, 0.8 },
		Speed = { 4, 9 * scale },
		Spread = 60,
		Emission = 0.1,
		Fade = 0.05,
	})
end

-- 11 Seashell Spinner: a pearly shell spiral spins open and pearls scatter
function impacts.Shell(c)
	local t = c.T
	sprite(c.Hit + Vector3.new(0, 1, 0), IMAGES.Spiral, Color3.fromHex("FFC6DD"), 2, 7 + 6 * t, 0.5, 540)
	sprite(c.Hit + Vector3.new(0, 1, 0), IMAGES.Spiral, WHITE, 1, 5 + 4 * t, 0.4, -360)
	puff(c.Hit, {
		Image = IMAGES.Dot,
		Colors = { WHITE, Color3.fromHex("FFE6F0"), Color3.fromHex("DFF6FF") },
		Count = 14 + 40 * t,
		Size = 0.45,
		EndSize = 0.3,
		Life = { 0.5, 0.9 },
		Speed = { 8, 18 + 8 * t },
		Spread = 70,
		Accel = Vector3.new(0, -30, 0),
		Drag = 1,
		Emission = 0.9,
	})
	floorRing(c.Floor, Color3.fromHex("FFC6DD"), 4 + 8 * t, 0.4)
	glow(c.Hit, Color3.fromHex("FFE6F0"), 5 + 5 * t, 0.3, 3)
	Sfx.PlayAt("Tap", c.Lane.PinSpot, 1.6 + math.random() * 0.2, 0.7)
end

-- 12 Beach Ball: one big hop onto the rack, then a burst of beach-ball colour panels and bounce rings
function impacts.BeachBall(c)
	local t = c.T
	for _, color in BEACH do -- (one burst per colour: a particle's Colors run over its life)
		puff(c.Hit + Vector3.new(0, 1, 0), {
			Image = SQUARE,
			Colors = { color },
			Count = 4 + 10 * t,
			Size = 0.8,
			EndSize = 0.6,
			Life = { 0.6, 1.1 },
			Speed = { 12, 22 + 10 * t },
			Spread = 70,
			Accel = Vector3.new(0, -30, 0),
			Drag = 1.5,
			Emission = 0.2,
			Spin = 260,
			Fade = 0,
		})
	end
	for i, color in BEACH do
		task.delay((i - 1) * 0.05, function()
			floorRing(c.Floor + Vector3.new(0, i * 0.02, 0), color, (4 + i * 1.5) * (1 + t * 0.8), 0.4)
		end)
	end
	glow(c.Hit, Color3.fromHex("FFE45A"), 6 + 5 * t, 0.3, 3)
	Sfx.PlayAt("Tap", c.Lane.PinSpot, 0.42 + math.random() * 0.05, 1)
end

-- 13 Kite Flyer: kites with rainbow tails lift off the rack and sail up into the sky
function impacts.Kite(c)
	local t = c.T
	local count = math.floor(3 + 4 * t)
	for i = 1, count do
		local color = RAINBOW[(i - 1) % #RAINBOW + 1]
		local start = c.Center + c.Right * ((i - (count + 1) / 2) * 2.8) + Vector3.new(0, 1.5, 0)
		local kite = solid(
			CFrame.new(start) * CFrame.Angles(0, 0, math.rad(45)),
			Vector3.new(2.2, 2.2, 0.12),
			color,
			1.5,
			Enum.Material.Neon
		)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.4, 0)
		a0.Parent = kite
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.4, 0)
		a1.Parent = kite
		local tail = Instance.new("Trail")
		tail.Attachment0 = a0
		tail.Attachment1 = a1
		tail.Texture = IMAGES.TrailRainbow
		tail.LightEmission = 0.6
		tail.Lifetime = 0.45
		tail.FaceCamera = true
		tail.WidthScale = NumberSequence.new(1, 0)
		tail.Parent = kite
		local rise = 10 + 10 * t + math.random() * 4
		local drift = c.Right * ((math.random() - 0.5) * 10) + c.Forward * (2 + math.random() * 4)
		local tilt = math.rad(45 + (math.random() - 0.5) * 60)
		tween(kite, 1.2, { CFrame = CFrame.new(start + Vector3.new(0, rise, 0) + drift) * CFrame.Angles(0, math.rad(90), tilt) }, Enum.EasingStyle.Sine)
		task.delay(0.8, function()
			tween(kite, 0.4, { Transparency = 1 })
		end)
	end
	puff(c.Hit, {
		Image = IMAGES.Diamond,
		Colors = RAINBOW,
		Count = 10 + 26 * t,
		Size = 0.4,
		Life = { 0.5, 1 },
		Speed = { 6, 12 },
		Spread = 40,
		Accel = Vector3.new(0, 14, 0),
		Spin = 300,
	})
	ThrowFx.Shockwave(c.Floor, c.Color, 4 + 8 * t, 0.3)
	Sfx.PlayAt("Teleport", c.Lane.PinSpot, 1.5 + math.random() * 0.1, 0.35 + 0.3 * t)
end

-- 14 Tide Turner: a wave rolls across the rack from one side, splashing as it goes, and washes the pins away
function impacts.Tide(c)
	local t = c.T
	local steps = 6
	for k = 0, steps do
		task.delay(k * 0.045, function()
			splash(c.Center - c.Right * 9 + c.Right * (k * 18 / steps), t, 0.6 + 0.4 * t)
		end)
	end
	puff(c.Center - c.Right * 8, {
		Image = IMAGES.Smoke,
		Colors = SEA,
		Count = 8 + 20 * t,
		Size = 2,
		EndSize = 3.5,
		Life = { 0.4, 0.7 },
		Speed = { 2, 4 },
		Accel = c.Right * (50 + 30 * t),
		Emission = 0.2,
		Fade = 0.3,
	})
	floorRing(c.Floor, Color3.fromHex("9BE9FF"), 5 + 9 * t, 0.45)
	Sfx.PlayAt("Teleport", c.Lane.PinSpot, 0.8 + math.random() * 0.1, 0.4 + 0.3 * t)
end

-- 15 Coral Crusher: coral spikes burst up out of the deck round the rack, bubbles rise, then the coral sinks
function impacts.Coral(c)
	local t = c.T
	local count = math.floor(6 + 8 * t)
	local corals = { Color3.fromHex("FF7A60"), Color3.fromHex("FF5AA8"), Color3.fromHex("FFB347"), Color3.fromHex("B48CFF") }
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + math.random() * 0.4
		local r = 3 + math.random() * (3 + 2 * t)
		local base = c.Floor + c.Right * math.cos(a) * r + c.Forward * math.sin(a) * r
		local height = 2 + math.random() * (2 + 3 * t)
		local lean = CFrame.Angles(math.rad((math.random() - 0.5) * 40), 0, math.rad((math.random() - 0.5) * 40))
		local up = CFrame.Angles(0, 0, math.rad(90)) -- (cylinders run along X)
		local w = 0.8 + 0.5 * t
		local spike = solid(CFrame.new(base) * lean * up, Vector3.new(0.1, w, w), corals[i % #corals + 1], 1.1)
		spike.Shape = Enum.PartType.Cylinder
		local grown = CFrame.new(base) * lean * CFrame.new(0, height / 2, 0) * up
		task.delay(i * 0.012, function()
			tween(spike, 0.14, { Size = Vector3.new(height, w, w), CFrame = grown }, Enum.EasingStyle.Back)
		end)
		task.delay(0.65, function()
			tween(spike, 0.3, { Size = Vector3.new(0.1, w * 0.5, w * 0.5), CFrame = CFrame.new(base) * lean * up, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
	end
	puff(c.Center, {
		Image = IMAGES.Bubble,
		Colors = { WHITE, Color3.fromHex("CFF6FF") },
		Count = 12 + 30 * t,
		Size = 0.5,
		EndSize = 0.2,
		Life = { 0.7, 1.2 },
		Speed = { 3, 7 },
		Accel = Vector3.new(0, 10, 0),
		Emission = 0.3,
	})
	ThrowFx.Shockwave(c.Floor, c.Color, 5 + 9 * t, 0.35)
	Sfx.PlayAt("CrateLand", c.Lane.PinSpot, 1.4 + math.random() * 0.1, 0.4 + 0.3 * t)
end

-- 16 Surf Rider: a curling wave arches over the rack and crashes down in foam
function impacts.Surf(c)
	local t = c.T
	local half = 6 + 4 * t
	local beam = ribbon(c.Center - c.Right * half, c.Center + c.Right * half, {
		Texture = IMAGES.TrailWisp,
		Mode = Enum.TextureMode.Wrap,
		Length = 4,
		Speed = 3,
		Colors = { WHITE, Color3.fromHex("9BE9FF"), Color3.fromHex("2AA8E0") },
		Emission = 0.4,
		Width = 2.5 + 2 * t,
		Axis0 = Vector3.yAxis,
		Axis1 = -Vector3.yAxis,
		Curve0 = 5 + 5 * t,
		Curve1 = 5 + 5 * t,
		Life = 0.8,
	})
	fadeRibbon(beam, 0.25, 0.5)
	task.delay(0.12, function()
		splash(c.Center + c.Forward * 1.5, t, 1.2)
		splash(c.Center - c.Right * 4, t, 0.7)
		splash(c.Center + c.Right * 4, t, 0.7)
	end)
	floorRing(c.Floor, WHITE, 5 + 9 * t, 0.45)
	ThrowFx.Shockwave(c.Floor, c.Color, 4 + 9 * t, 0.35)
	Sfx.PlayAt("Teleport", c.Lane.PinSpot, 0.65, 0.5 + 0.3 * t)
end

-- 17 Sunset Splash: a tall column of sunset-coloured water shoots up and rains back down
function impacts.Splash(c)
	local t = c.T
	puff(c.Center, {
		Image = IMAGES.Dot,
		Colors = SUNSET,
		Count = 30 + 70 * t,
		Size = 0.85,
		EndSize = 0.1,
		Life = { 0.9, 1.4 },
		Speed = { 22, 34 + 14 * t },
		Spread = 14,
		Accel = Vector3.new(0, -45, 0),
		Drag = 0.4,
		Emission = 0.7,
	})
	splash(c.Center, t, 1.3, SUNSET)
	sprite(c.Center + Vector3.new(0, 2, 0), IMAGES.Burst, Color3.fromHex("FFB070"), 3, 10 + 8 * t, 0.35, 45)
	glow(c.Center + Vector3.new(0, 2, 0), Color3.fromHex("FF9A5A"), 8 + 8 * t, 0.4, 5)
	if c.Big then
		-- a rainbow in the mist
		local beam = ribbon(c.Center - c.Right * (5 + 3 * t), c.Center + c.Right * (5 + 3 * t), {
			Texture = IMAGES.TrailRainbow,
			Colors = { WHITE },
			Emission = 0.5,
			Width = 1.2 + 1.2 * t,
			Axis0 = Vector3.yAxis,
			Axis1 = -Vector3.yAxis,
			Curve0 = 8 + 4 * t,
			Curve1 = 8 + 4 * t,
			Transparency = 0.3,
			Life = 1.1,
		})
		fadeRibbon(beam, 0.5, 0.6)
	end
	floorRing(c.Floor, Color3.fromHex("FFB070"), 6 + 10 * t, 0.45)
	Sfx.PlayAt("Teleport", c.Lane.PinSpot, 0.55, 0.5 + 0.3 * t)
end

-- 18 Pier Pounder: a giant pier post drops out of the sky onto the rack (wood splinters, a dust ring)
function impacts.Pound(c)
	local t = c.T
	local height = 6 + 6 * t
	local radius = 1.2 + 1.2 * t
	local up = CFrame.Angles(0, 0, math.rad(90))
	local top = c.Floor + Vector3.new(0, 30, 0)
	local post = solid(CFrame.new(top) * up, Vector3.new(height, radius * 2, radius * 2), Color3.fromHex("A8743E"), 1.2, Enum.Material.Wood)
	post.Shape = Enum.PartType.Cylinder
	local cap = solid(CFrame.new(top + Vector3.new(0, height / 2, 0)) * up, Vector3.new(0.6, radius * 2.3, radius * 2.3), Color3.fromHex("FF7660"), 1.2)
	cap.Shape = Enum.PartType.Cylinder
	local landed = c.Floor + Vector3.new(0, height / 2, 0)
	tween(post, 0.16, { CFrame = CFrame.new(landed) * up }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(cap, 0.16, { CFrame = CFrame.new(landed + Vector3.new(0, height / 2, 0)) * up }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.16, function()
		ThrowFx.Shockwave(c.Floor, Color3.fromHex("E8CFA8"), 8 + 12 * t, 0.4)
		floorRing(c.Floor + Vector3.new(0, 0.05, 0), Color3.fromHex("FFE0B0"), 10 + 14 * t, 0.5)
		puff(c.Floor + Vector3.new(0, 0.5, 0), {
			Image = SQUARE,
			Colors = { Color3.fromHex("C8945A"), Color3.fromHex("8A5A2E"), Color3.fromHex("E8CFA8") },
			Count = 16 + 40 * t,
			Size = 0.4,
			EndSize = 0.3,
			Life = { 0.5, 0.9 },
			Speed = { 14, 26 + 10 * t },
			Spread = 75,
			Accel = Vector3.new(0, -40, 0),
			Emission = 0,
			Spin = 400,
			Fade = 0,
		})
		puff(c.Floor + Vector3.new(0, 0.5, 0), {
			Image = IMAGES.Smoke,
			Colors = { Color3.fromHex("F2DDB8"), Color3.fromHex("C8A070") },
			Count = 8 + 20 * t,
			Size = 2,
			EndSize = 4,
			Life = { 0.5, 0.9 },
			Speed = { 6, 12 },
			Spread = 85,
			Emission = 0,
			Fade = 0.35,
		})
		CameraShake.Add(0.25 + 0.4 * t)
		Sfx.PlayAt("CrateLand", c.Lane.PinSpot, 0.7, 0.8 + 0.2 * t)
		task.delay(0.45, function()
			tween(post, 0.4, { Transparency = 1, CFrame = post.CFrame - Vector3.new(0, height, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(cap, 0.4, { Transparency = 1, CFrame = cap.CFrame - Vector3.new(0, height, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
	end)
end

-- 19 Tsunami: a towering wave rises behind the rack, crashes forward over it and floods the deck in foam
function impacts.Tsunami(c)
	local t = c.T
	local function crash(scale: number)
		for _, side in { -1, 0, 1 } do
			splash(c.Center + c.Right * side * 5, t, 1.4 * scale)
		end
		floorRing(c.Floor, WHITE, (10 + 16 * t) * scale, 0.5)
		floorRing(c.Floor + Vector3.new(0, 0.04, 0), Color3.fromHex("3CC8E6"), (8 + 12 * t) * scale, 0.45)
		ThrowFx.Shockwave(c.Floor, Color3.fromHex("9BE9FF"), (8 + 12 * t) * scale, 0.4)
	end
	if not c.Big then
		crash(0.7)
		return
	end
	local half = 10 + 6 * t
	local back = c.Center + c.Forward * 6 + Vector3.new(0, 0.5, 0)
	local beam, a0, a1 = ribbon(back - c.Right * half, back + c.Right * half, {
		Texture = IMAGES.TrailWisp,
		Mode = Enum.TextureMode.Wrap,
		Length = 6,
		Speed = 4,
		Colors = { WHITE, Color3.fromHex("6CD8F0"), Color3.fromHex("1E8FC8") },
		Emission = 0.3,
		Width = 5 + 4 * t,
		Axis0 = Vector3.yAxis,
		Axis1 = -Vector3.yAxis,
		Curve0 = 10 + 8 * t,
		Curve1 = 10 + 8 * t,
		Life = 0.9,
	})
	tween(a0, 0.3, { Position = a0.Position - c.Forward * 10 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(a1, 0.3, { Position = a1.Position - c.Forward * 10 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(beam, 0.3, { CurveSize0 = 2, CurveSize1 = 2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	fadeRibbon(beam, 0.3, 0.4)
	task.delay(0.28, function()
		crash(1)
		UiFx.Flash(Color3.fromHex("CFF6FF"), 0.2 + 0.3 * t, 0.3)
		CameraShake.Add(0.3 + 0.4 * t)
		Sfx.PlayAt("BossHit", c.Lane.PinSpot, 1.2, 0.5 + 0.3 * t)
	end)
	Sfx.PlayAt("Teleport", c.Lane.PinSpot, 0.45, 0.6)
end

-- 20 Lighthouse Beam: a golden lighthouse beam sweeps across the rack, then a pillar of light blasts up from it
function impacts.Lighthouse(c)
	local t = c.T
	local gold = Color3.fromHex("FFE27A")
	local source = c.Center + c.Forward * 30 + Vector3.new(0, 26, 0)
	local beam, _, a1 = ribbon(source, c.Center - c.Right * 10, {
		Texture = IMAGES.TrailSoft,
		Colors = { WHITE, gold },
		Emission = 0.8,
		Width = 1,
		Width1 = 4 + 3 * t,
		Transparency = 0.25,
		Life = 0.7,
	})
	tween(a1, 0.3, { Position = c.Center + c.Right * 10 }, Enum.EasingStyle.Sine)
	fadeRibbon(beam, 0.3, 0.3)
	task.delay(0.22, function()
		local pillar = ribbon(c.Floor, c.Floor + Vector3.new(0, 24 + 16 * t, 0), {
			Texture = IMAGES.TrailCore,
			Colors = { WHITE, gold },
			Emission = 1,
			Width = 3 + 3 * t,
			Width1 = 0.5,
			Life = 0.6,
		})
		fadeRibbon(pillar, 0.15, 0.4)
		for i = 1, 3 do
			task.delay((i - 1) * 0.06, function()
				floorRing(c.Floor + Vector3.new(0, i * 0.03, 0), gold, (4 + i * 3) * (1 + t * 0.7), 0.45)
			end)
		end
		puff(c.Center + Vector3.new(0, 1, 0), {
			Image = IMAGES.Star,
			Colors = { WHITE, gold },
			Count = 16 + 40 * t,
			Size = 0.5,
			Life = { 0.4, 0.8 },
			Speed = { 10, 22 + 10 * t },
			Spin = 200,
		})
		glow(c.Center + Vector3.new(0, 2, 0), gold, 10 + 10 * t, 0.45, 8)
		if c.Big and t > 0.3 then
			UiFx.Flash(Color3.fromHex("FFF4C8"), 0.15 + 0.25 * t, 0.25)
		end
		Sfx.PlayAt("Reveal", c.Lane.PinSpot, 1.2, 0.4 + 0.3 * t)
	end)
end

local lastBig = -math.huge

-- Plays the ball's hit. Returns how long the pins should wait before flying (the black hole holds them a moment).
function BallSignature.Impact(name: string?, c): number
	local row = name and FX.Effects[name]
	if not row then
		return 0
	end
	local now = os.clock()
	c.Big = now - lastBig >= FX.BigGap * (if c.Lucky then 0.5 else 1) -- LUCKY rolls get theirs sooner
	if c.Big then
		lastBig = now
	end
	c.Color = row.Color
	c.Floor = Vector3.new(c.Center.X, c.FloorY + 0.08, c.Center.Z)
	-- Shake grows with the pin count (SCREEN SHAKE off = none)
	local THROW = Config.Throw
	ThrowFx.Shake(THROW.CameraShakeStrength * row.Shake * (0.4 + 0.6 * c.T), THROW.CameraShakeTime * (0.6 + 0.6 * c.T))
	if c.Big and c.T >= 0.5 and name ~= "BlackHole" then
		CameraShake.Add(row.Shake * c.T * 0.5)
	end
	if vfx() then
		impacts[name](c)
	elseif name == "BlackHole" then
		Sfx.PlayAt("OverchargeBlast", c.Lane.PinSpot, 1, 0.6 + 0.4 * c.T)
	end
	if name == "Pound" then
		return 0.16 -- (the pins wait for the post to land)
	end
	return if name == "BlackHole" and c.Big then 0.2 else 0
end

-- Where the drawn pins fly away from, and how hard (x the normal knock)
function BallSignature.Knock(name: string?, c): (Vector3, number)
	local row = name and FX.Effects[name]
	if not row then
		return c.Hit, 1
	end
	local from = c.Hit
	if row.KnockFrom == "Center" or row.KnockFrom == "Under" then
		from = c.Center - c.Forward * 0.5
	elseif row.KnockFrom == "Side" then
		from = c.Center - c.Right * 8
	end
	return from, row.Force or 1
end

return BallSignature
