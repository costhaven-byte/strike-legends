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
	elseif name == "Vine" or name == "LeafStorm" or name == "JungleKing" then
		-- green leaves tumble off the ball (Jungle King: gold sparkles too)
		trailEmitter(ball, {
			Image = IMAGES.Diamond,
			Colors = { Color3.fromHex("3CB44A"), Color3.fromHex("A8E85A") },
			Rate = (10 + 20 * t) * (if name == "LeafStorm" then 1.6 else 1),
			Size = 0.4,
			EndSize = 0.25,
			Life = { 0.5, 0.9 },
			Speed = { 1, 4 },
			Accel = Vector3.new(0, -4, 0),
			Emission = 0.1,
			Spin = 260,
			Fade = 0,
		})
		if name == "JungleKing" then
			trailEmitter(ball, {
				Image = SPARKLE,
				Colors = { WHITE, Color3.fromHex("FFC83C") },
				Rate = 16 + 30 * t,
				Size = 0.5,
				Life = { 0.3, 0.6 },
				Speed = { 1, 3 },
				Emission = 0.8,
			})
		end
	elseif name == "Toucan" then
		trailEmitter(ball, {
			Image = IMAGES.Diamond,
			Colors = { Color3.fromHex("FF9A2E"), Color3.fromHex("FFE45A"), Color3.fromHex("4AB8FF") },
			Rate = 12 + 24 * t,
			Size = 0.35,
			EndSize = 0.15,
			Life = { 0.5, 0.9 },
			Speed = { 1, 3 },
			Accel = Vector3.new(0, 4, 0),
			Emission = 0.3,
			Spin = 200,
		})
	elseif name == "Waterfall" or name == "Monsoon" then
		trailEmitter(ball, {
			Image = IMAGES.Smoke,
			Colors = { WHITE, Color3.fromHex("DDF8FF") },
			Rate = 10 + 24 * t,
			Size = d * 0.5,
			EndSize = d * 1.2,
			Life = { 0.25, 0.5 },
			Speed = { 1, 3 },
			Emission = 0.1,
			Fade = 0.35,
		})
		trailEmitter(ball, {
			Image = IMAGES.Dot,
			Colors = { WHITE, Color3.fromHex("9BE9FF") },
			Rate = 14 + 30 * t,
			Size = 0.25,
			EndSize = 0.08,
			Life = { 0.4, 0.8 },
			Speed = { 3, 6 },
			Accel = Vector3.new(0, -18, 0),
			Emission = 0.5,
		})
	elseif name == "Jaguar" or name == "Temple" or name == "Coconut" or name == "Bridge" then
		-- dust kicked up behind the ball (Jaguar: orange speed flecks, Temple: gold dust)
		local tint = if name == "Jaguar" then { Color3.fromHex("FFB020"), Color3.fromHex("FF6A1E") }
			elseif name == "Temple" then { Color3.fromHex("FFE27A"), Color3.fromHex("FFC83C") }
			else { Color3.fromHex("E8CFA8"), Color3.fromHex("B8925E") }
		trailEmitter(ball, {
			Image = IMAGES.Smoke,
			Colors = { Color3.fromHex("E8D8B8"), Color3.fromHex("B8A078") },
			Rate = 10 + 20 * t,
			Size = d * 0.6,
			EndSize = d * 1.4,
			Life = { 0.3, 0.6 },
			Speed = { 0.5, 2 },
			Emission = 0,
			Fade = 0.45,
		})
		trailEmitter(ball, {
			Image = if name == "Temple" then SPARKLE else IMAGES.Dot,
			Colors = tint,
			Rate = 12 + 26 * t,
			Size = 0.3,
			EndSize = 0.05,
			Life = { 0.3, 0.6 },
			Speed = { 2, 5 },
			Emission = if name == "Temple" then 0.8 else 0.3,
		})
	elseif name == "DustDevil" or name == "Cactus" or name == "Mesa" or name == "Sandstorm" or name == "Scorpion" then
		-- zone 4: desert sand kicked up behind the ball (Sandstorm thicker, Scorpion with orange flecks)
		local big = if name == "Sandstorm" then 1.6 else 1
		trailEmitter(ball, {
			Image = IMAGES.Smoke,
			Colors = { Color3.fromHex("F7DCA8"), Color3.fromHex("E2B26A") },
			Rate = (12 + 26 * t) * big,
			Size = d * 0.6 * big,
			EndSize = d * 1.4 * big,
			Life = { 0.3, 0.6 },
			Speed = { 0.5, 2 },
			Emission = 0,
			Fade = 0.35,
		})
		trailEmitter(ball, {
			Image = IMAGES.Dot,
			Colors = if name == "Scorpion" then { Color3.fromHex("FF7A3C"), Color3.fromHex("FFB43C") } elseif name == "Cactus" then { Color3.fromHex("6CD65C"), Color3.fromHex("FF6EAA") } else { Color3.fromHex("D2964E"), Color3.fromHex("B87A3C") },
			Rate = 12 + 26 * t,
			Size = 0.28,
			EndSize = 0.06,
			Life = { 0.3, 0.6 },
			Speed = { 2, 5 },
			Accel = Vector3.new(0, -16, 0),
			Emission = if name == "Scorpion" then 0.6 else 0.1,
		})
	elseif name == "Oasis" or name == "Mirage" then
		-- zone 4: turquoise droplets (Oasis) or a shimmer of turquoise sparkles (Mirage)
		trailEmitter(ball, {
			Image = if name == "Mirage" then SPARKLE else IMAGES.Dot,
			Colors = { WHITE, Color3.fromHex("7AF0E6") },
			Rate = 14 + 30 * t,
			Size = if name == "Mirage" then 0.5 else 0.25,
			EndSize = 0.08,
			Life = { 0.4, 0.8 },
			Speed = { 2, 5 },
			Accel = Vector3.new(0, if name == "Oasis" then -18 else 3, 0),
			Emission = 0.6,
		})
	elseif name == "SunDisc" or name == "Sphinx" then
		-- zone 4: gold sparkles and a warm glow following the ball
		trailEmitter(ball, {
			Image = SPARKLE,
			Colors = { WHITE, Color3.fromHex("FFC83C") },
			Rate = 16 + 30 * t,
			Size = 0.5,
			Life = { 0.3, 0.6 },
			Speed = { 1, 3 },
			Emission = 0.8,
		})
		local gap = 0.08
		local last = 0
		function handle.Step(position: Vector3)
			local now = os.clock()
			if now - last < gap then
				return
			end
			last = now
			glow(position, Color3.fromHex("FFD23C"), d * (2 + 1.5 * t), 0.3)
		end
	elseif name == "Echo" then
		-- Canyon Echo: terracotta sound rings peel off the ball
		local gap = 0.09
		local last = 0
		function handle.Step(position: Vector3)
			local now = os.clock()
			if now - last < gap then
				return
			end
			last = now
			sprite(position, IMAGES.Ring, Color3.fromHex("FF9A5A"), d * 1.2, d * (2.5 + 2 * t), 0.3)
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

---------------------------------------------------------------------------------------------------------------
-- Zone 3, Jungle Falls (Addendum 6 Stage 5): jungle effects, one per ball
---------------------------------------------------------------------------------------------------------------
local LEAVES = { Color3.fromHex("3CB44A"), Color3.fromHex("6CD65C"), Color3.fromHex("2E8F3E"), Color3.fromHex("A8E85A") }
local GOLD = Color3.fromHex("FFC83C")

-- A few parts that move as one: pieces = { { Size, Offset (CFrame from the pivot), Color, Shape?, Material? } }.
-- Returns the parts and move(cframe) (sets every part from the pivot).
local function rig(pivot: CFrame, pieces, life: number): ({ Part }, (CFrame) -> ())
	local parts = {}
	for _, piece in pieces do
		local p = solid(pivot * piece[2], piece[1], piece[3], life, piece[5])
		if piece[4] then
			p.Shape = piece[4]
		end
		table.insert(parts, p)
	end
	local function move(cf: CFrame)
		for i, p in parts do
			p.CFrame = cf * pieces[i][2]
		end
	end
	return parts, move
end

-- Runs step(k) every frame for `time` seconds (k goes 0 -> 1), then done() if given
local function animate(time: number, step: (number) -> (), done: (() -> ())?)
	task.spawn(function()
		local start = os.clock()
		while true do
			local k = math.min((os.clock() - start) / time, 1)
			step(k)
			if k >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		if done then
			done()
		end
	end)
end

local function fadeParts(parts: { Part }, time: number)
	for _, p in parts do
		tween(p, time, { Transparency = 1 })
	end
end

-- A burst of green leaves (diamond sparks that tumble and drift down)
local function leafBurst(at: Vector3, count: number, speed: number)
	puff(at, {
		Image = IMAGES.Diamond,
		Colors = { LEAVES[math.random(#LEAVES)] },
		Count = count * 0.5,
		Size = 0.7,
		EndSize = 0.5,
		Life = { 0.8, 1.3 },
		Speed = { speed * 0.5, speed },
		Spread = 80,
		Accel = Vector3.new(0, -10, 0),
		Drag = 2,
		Emission = 0.1,
		Spin = 300,
		Fade = 0,
	})
	puff(at, {
		Image = IMAGES.Diamond,
		Colors = { LEAVES[math.random(#LEAVES)] },
		Count = count * 0.5,
		Size = 0.5,
		EndSize = 0.4,
		Life = { 0.8, 1.3 },
		Speed = { speed * 0.4, speed * 0.9 },
		Spread = 80,
		Accel = Vector3.new(0, -8, 0),
		Drag = 2,
		Emission = 0.1,
		Spin = 300,
		Fade = 0,
	})
end

-- A big flat leaf part (squashed sphere)
local function leafPart(cframe: CFrame, length: number, color: Color3, life: number): Part
	local p = solid(cframe, Vector3.new(length * 0.45, 0.2, length), color, life)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- 21 Vine Swinger: green vines whip down from above and lash across the rack, leaves fly
function impacts.Vine(c)
	local t = c.T
	local count = math.floor(3 + 3 * t)
	for i = 1, count do
		task.delay((i - 1) * 0.05, function()
			local x = (i - (count + 1) / 2) * 3
			local top = c.Center + c.Right * (x - 8) + Vector3.new(0, 18, 0) + c.Forward * ((i % 2) * 3)
			local beam, _, a1 = ribbon(top, top - Vector3.new(0, 4, 0), {
				Texture = IMAGES.TrailCore,
				Colors = { Color3.fromHex("2E8F3E"), Color3.fromHex("6CD65C") },
				Emission = 0.2,
				Width = 1.6 + 0.8 * t,
				Width1 = 0.9,
				Curve0 = -4,
				Segments = 14,
				Life = 1,
			})
			tween(a1, 0.16, { Position = c.Center + c.Right * (x + 6) + Vector3.new(0, 1, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			fadeRibbon(beam, 0.45, 0.45)
			task.delay(0.16, function()
				leafBurst(c.Center + c.Right * (x + 4) + Vector3.new(0, 1, 0), 14 + 16 * t, 14)
			end)
		end)
	end
	floorRing(c.Floor, Color3.fromHex("6CD65C"), 5 + 9 * t, 0.45)
	ThrowFx.Shockwave(c.Floor, c.Color, 4 + 8 * t, 0.3)
	Sfx.PlayAt("Throw", c.Lane.PinSpot, 1.4, 0.5 + 0.3 * t)
end

-- 22 Coconut: coconuts rain down onto the rack, bounce and crack open (milk splashes)
function impacts.Coconut(c)
	local t = c.T
	local count = math.floor(4 + 6 * t)
	for i = 1, count do
		task.delay((i - 1) * 0.04, function()
			local land = c.Floor + c.Right * ((math.random() - 0.5) * 16) + c.Forward * ((math.random() - 0.5) * 8) + Vector3.new(0, 0.9, 0)
			local nut = solid(CFrame.new(land + Vector3.new(0, 24, 0)), Vector3.one * 1.8, Color3.fromHex("7A4E2A"), 1.3)
			nut.Shape = Enum.PartType.Ball
			tween(nut, 0.18, { CFrame = CFrame.new(land) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.18, function()
				-- crack: two white-inside halves fly apart
				nut.Transparency = 1
				for _, s in { -1, 1 } do
					local half = solid(CFrame.new(land) * CFrame.Angles(0, 0, math.rad(90 * s)), Vector3.new(0.9, 1.8, 1.8), Color3.fromHex("FFF8EC"), 0.9)
					local shell = solid(CFrame.new(land + c.Right * s * 0.3), Vector3.new(0.6, 1.8, 1.8), Color3.fromHex("7A4E2A"), 0.9)
					local away = land + c.Right * s * (2.5 + math.random() * 2) + Vector3.new(0, 2 + math.random() * 2, 0)
					tween(half, 0.5, { CFrame = CFrame.new(away) * CFrame.Angles(math.random() * 3, 0, math.random() * 3), Transparency = 1 })
					tween(shell, 0.5, { CFrame = CFrame.new(away + c.Right * s * 0.4) * CFrame.Angles(math.random() * 3, 0, math.random() * 3), Transparency = 1 })
				end
				splash(land, t, 0.45, { WHITE, Color3.fromHex("FFF4DC") })
			end)
		end)
	end
	task.delay(0.2, function()
		ThrowFx.Shockwave(c.Floor, c.Color, 5 + 8 * t, 0.35)
		Sfx.PlayAt("CrateLand", c.Lane.PinSpot, 1.7, 0.5 + 0.3 * t)
	end)
	leafBurst(c.Center + Vector3.new(0, 12, 0), 10 + 10 * t, 6)
end

-- 23 Toucan Roll: a big toucan swoops down through the rack and flies off, rainbow feathers burst behind it
function impacts.Toucan(c)
	local t = c.T
	local s = 1.6 + 1.2 * t
	local black, orange = Color3.fromHex("1E1E28"), Color3.fromHex("FF9A2E")
	local pieces = {
		{ Vector3.new(1.6, 1.6, 2.6) * s, CFrame.new(), black, Enum.PartType.Ball },
		{ Vector3.new(1.1, 1.0, 0.9) * s, CFrame.new(0, 0.1 * s, -1.1 * s), WHITE, Enum.PartType.Ball },
		{ Vector3.new(1.0, 1.0, 1.0) * s, CFrame.new(0, 0.5 * s, -1.4 * s), black, Enum.PartType.Ball },
		{ Vector3.new(0.6, 0.7, 2.2) * s, CFrame.new(0, 0.45 * s, -2.7 * s), orange, Enum.PartType.Ball },
		{ Vector3.new(0.3, 0.3, 0.6) * s, CFrame.new(0, 0.45 * s, -3.7 * s), Color3.fromHex("FF4D4D"), Enum.PartType.Ball },
		{ Vector3.new(0.25, 0.25, 0.25) * s, CFrame.new(0.42 * s, 0.7 * s, -1.6 * s), Color3.fromHex("4AB8FF"), Enum.PartType.Ball },
		{ Vector3.new(2.6, 0.2, 1.4) * s, CFrame.new(-1.4 * s, 0.3 * s, 0.1 * s), black },
		{ Vector3.new(2.6, 0.2, 1.4) * s, CFrame.new(1.4 * s, 0.3 * s, 0.1 * s), black },
		{ Vector3.new(0.9, 0.2, 1.4) * s, CFrame.new(0, 0, 1.8 * s), black },
	}
	local from = c.Center - c.Right * 22 + c.Forward * 4 + Vector3.new(0, 12, 0)
	local mid = c.Center + Vector3.new(0, 1.5 * s, 0)
	local to = c.Center + c.Right * 24 - c.Forward * 2 + Vector3.new(0, 16, 0)
	local parts, move = rig(CFrame.new(from), pieces, 1.2)
	local wings = { parts[7], parts[8] }
	local last = from
	animate(0.45, function(k)
		local a = from:Lerp(mid, k)
		local b = mid:Lerp(to, k)
		local p = a:Lerp(b, k) -- (a curve down through the rack and back up)
		local dir = (p - last).Magnitude > 0.01 and (p - last).Unit or c.Right
		last = p
		move(CFrame.lookAt(p, p + dir))
		local flap = math.sin(k * 20) * 0.6
		wings[1].CFrame *= CFrame.Angles(0, 0, flap)
		wings[2].CFrame *= CFrame.Angles(0, 0, -flap)
	end, function()
		fadeParts(parts, 0.2)
	end)
	task.delay(0.2, function()
		for _, color in { RAINBOW[1], RAINBOW[2], RAINBOW[3], RAINBOW[4], RAINBOW[5] } do
			puff(mid, {
				Image = IMAGES.Diamond,
				Colors = { color },
				Count = 4 + 8 * t,
				Size = 0.6,
				EndSize = 0.4,
				Life = { 0.7, 1.2 },
				Speed = { 8, 16 + 8 * t },
				Spread = 90,
				Accel = Vector3.new(0, -8, 0),
				Drag = 2,
				Emission = 0.3,
				Spin = 260,
				Fade = 0,
			})
		end
		floorRing(c.Floor, orange, 5 + 9 * t, 0.45)
		ThrowFx.Shockwave(c.Floor, c.Color, 4 + 8 * t, 0.3)
		Sfx.PlayAt("Tap", c.Lane.PinSpot, 1.9, 0.6)
	end)
	Sfx.PlayAt("Throw", c.Lane.PinSpot, 1.6, 0.6)
end

-- 24 Leaf Storm: a whirl of giant leaves spins up round the rack, then blows outward
function impacts.LeafStorm(c)
	local t = c.T
	local count = math.floor(10 + 10 * t)
	local radius = 5 + 3 * t
	local leaves = {}
	for i = 1, count do
		local p = leafPart(CFrame.new(c.Center), 2.2 + math.random() * 1.5, LEAVES[i % #LEAVES + 1], 1.4)
		table.insert(leaves, { p, (i / count) * math.pi * 2, 0.5 + math.random() * 4 })
	end
	animate(0.55, function(k)
		for _, l in leaves do
			local a = l[2] + k * math.pi * 3
			local r = radius * (0.4 + k * 0.6)
			local at = c.Center + c.Right * math.cos(a) * r + c.Forward * math.sin(a) * r + Vector3.new(0, l[3] + k * 4, 0)
			l[1].CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(a), 0.4, math.cos(a))) * CFrame.Angles(0, 0, a)
		end
	end, function()
		for _, l in leaves do
			local out = (l[1].Position - c.Center) * Vector3.new(1, 0, 1)
			out = if out.Magnitude > 0.1 then out.Unit else c.Right
			tween(l[1], 0.5, { CFrame = l[1].CFrame + out * (10 + 8 * t) + Vector3.new(0, 4, 0), Transparency = 1 })
		end
		leafBurst(c.Center + Vector3.new(0, 2, 0), 16 + 20 * t, 18)
		floorRing(c.Floor, Color3.fromHex("A8E85A"), 7 + 10 * t, 0.45)
		ThrowFx.Shockwave(c.Floor, c.Color, 6 + 10 * t, 0.35)
		Sfx.PlayAt("Teleport", c.Lane.PinSpot, 1.1, 0.5 + 0.3 * t)
	end)
	sprite(c.Center + Vector3.new(0, 3, 0), IMAGES.Spiral, Color3.fromHex("6CD65C"), 4, 12 + 6 * t, 0.6, 720)
	Sfx.PlayAt("Throw", c.Lane.PinSpot, 0.8, 0.6)
end

-- 25 Waterfall: a waterfall pours out of the sky onto the rack, a big splash, mist and a rainbow
function impacts.Waterfall(c)
	local t = c.T
	local width = 6 + 5 * t
	local top = c.Center + Vector3.new(0, 34, 0)
	local beam, _, a1 = ribbon(top, top - Vector3.new(0, 2, 0), {
		Texture = IMAGES.TrailWisp,
		Mode = Enum.TextureMode.Wrap,
		Length = 6,
		Speed = -3,
		Colors = { WHITE, Color3.fromHex("9BE9FF"), Color3.fromHex("3CC8E6") },
		Emission = 0.35,
		Width = width,
		Width1 = width * 1.2,
		Life = 1.1,
	})
	tween(a1, 0.15, { Position = c.Floor + Vector3.new(0, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	fadeRibbon(beam, 0.55, 0.5)
	task.delay(0.15, function()
		for k = 0, 4 do
			task.delay(k * 0.08, function()
				splash(c.Center + c.Right * ((math.random() - 0.5) * width), t, 0.9 + 0.3 * t)
			end)
		end
		floorRing(c.Floor, WHITE, 8 + 10 * t, 0.5)
		floorRing(c.Floor + Vector3.new(0, 0.03, 0), Color3.fromHex("3CC8E6"), 6 + 8 * t, 0.45)
		ThrowFx.Shockwave(c.Floor, Color3.fromHex("9BE9FF"), 6 + 10 * t, 0.4)
		Sfx.PlayAt("Teleport", c.Lane.PinSpot, 0.6, 0.5 + 0.3 * t)
		if c.Big then
			local bow = ribbon(c.Center - c.Right * (7 + 3 * t) - c.Forward * 2, c.Center + c.Right * (7 + 3 * t) - c.Forward * 2, {
				Texture = IMAGES.TrailRainbow,
				Colors = { WHITE },
				Emission = 0.5,
				Width = 1.4 + t,
				Axis0 = Vector3.yAxis,
				Axis1 = -Vector3.yAxis,
				Curve0 = 9 + 4 * t,
				Curve1 = 9 + 4 * t,
				Transparency = 0.3,
				Life = 1.2,
			})
			fadeRibbon(bow, 0.6, 0.6)
		end
	end)
end

-- 26 Jaguar: glowing eyes flash over the rack, then three huge claw slashes rip across it
function impacts.Jaguar(c)
	local t = c.T
	local eyes = c.Center + Vector3.new(0, 6 + 2 * t, 0) + c.Forward * 3
	for _, s in { -1, 1 } do
		glow(eyes + c.Right * s * (1.4 + t), Color3.fromHex("FFE45A"), 2.5 + 2 * t, 0.35, 2)
	end
	task.delay(0.08, function()
		for i = -1, 1 do
			task.delay((i + 1) * 0.04, function()
				-- one claw mark: a glowing bar that rips diagonally across the rack, then lingers and fades
				local mid = c.Center + c.Right * (i * 3) - c.Forward * 4 + Vector3.new(0, 3.5 + t, 0)
				local tilt = CFrame.lookAt(mid, mid + c.Forward) * CFrame.Angles(0, 0, math.rad(-28))
				local long = 16 + 6 * t
				local claw = solid(tilt * CFrame.new(-long / 2, 0, 0), Vector3.new(0.2, 0.9 + 0.5 * t, 0.3), Color3.fromHex("FFB020"), 1, Enum.Material.Neon)
				local core = solid(tilt * CFrame.new(-long / 2, 0, -0.1), Vector3.new(0.2, 0.35, 0.32), WHITE, 1, Enum.Material.Neon)
				tween(claw, 0.12, { Size = Vector3.new(long, 0.9 + 0.5 * t, 0.3), CFrame = tilt }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				tween(core, 0.12, { Size = Vector3.new(long * 0.9, 0.35, 0.32), CFrame = tilt * CFrame.new(0, 0, -0.1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				task.delay(0.45, function()
					tween(claw, 0.35, { Transparency = 1, Size = Vector3.new(long, 0.1, 0.3) })
					tween(core, 0.35, { Transparency = 1 })
				end)
			end)
		end
		-- jaguar spots burst (orange flecks + black spots, one burst each)
		glow(c.Center + Vector3.new(0, 2, 0), Color3.fromHex("FFB020"), 10 + 8 * t, 0.4, 5)
		puff(c.Center + Vector3.new(0, 1, 0), { Image = IMAGES.Dot, Colors = { Color3.fromHex("FFB020") }, Count = 14 + 26 * t, Size = 1.2, EndSize = 0.4, Life = { 0.5, 0.9 }, Speed = { 10, 20 + 8 * t }, Spread = 80, Accel = Vector3.new(0, -26, 0), Emission = 0.4 })
		puff(c.Center + Vector3.new(0, 1, 0), { Image = IMAGES.Dot, Colors = { Color3.fromHex("2A1A10") }, Count = 8 + 16 * t, Size = 1, EndSize = 0.4, Life = { 0.5, 0.9 }, Speed = { 8, 16 + 8 * t }, Spread = 80, Accel = Vector3.new(0, -26, 0), Emission = 0 })
		floorRing(c.Floor, Color3.fromHex("FFB020"), 5 + 9 * t, 0.4)
		ThrowFx.Shockwave(c.Floor, c.Color, 5 + 9 * t, 0.35)
		Sfx.PlayAt("BossPlate", c.Lane.PinSpot, 1.3, 0.5 + 0.3 * t)
	end)
end

-- 27 Rope Bridge: a rope bridge swings in over the rack, its ropes snap and the planks crash down
function impacts.Bridge(c)
	local t = c.T
	local half = 8 + 4 * t
	local y = 7 + 2 * t
	local count = math.floor(10 + 6 * t)
	local planks = {}
	local wood = { Color3.fromHex("C08A50"), Color3.fromHex("A8743E") }
	for i = 0, count - 1 do
		local k = i / (count - 1)
		local at = c.Center - c.Right * half + c.Right * (2 * half * k) + Vector3.new(0, y - math.sin(k * math.pi) * 1.5, 0)
		local p = solid(CFrame.lookAt(at, at + c.Right) * CFrame.new(0, 14, 0), Vector3.new(4.5, 0.45, 1.3), wood[i % 2 + 1], 1.7, Enum.Material.WoodPlanks)
		table.insert(planks, { p, at })
		tween(p, 0.08 + k * 0.04, { CFrame = CFrame.lookAt(at, at + c.Right) }, Enum.EasingStyle.Quad)
	end
	local ropes = {}
	for _, s in { -1, 1 } do
		local beam = ribbon(c.Center - c.Right * half + c.Forward * s * 2 + Vector3.new(0, y + 1, 0), c.Center + c.Right * half + c.Forward * s * 2 + Vector3.new(0, y + 1, 0), {
			Texture = IMAGES.TrailCore,
			Colors = { Color3.fromHex("E2C48A") },
			Emission = 0,
			Width = 0.3,
			Curve0 = -2,
			Curve1 = 2,
			Life = 0.5,
		})
		table.insert(ropes, beam)
	end
	task.delay(0.13, function()
		-- snap! the planks drop onto the rack, tumbling
		for _, r in ropes do
			r:Destroy()
		end
		puff(c.Center + Vector3.new(0, y, 0), { Image = SQUARE, Colors = { Color3.fromHex("E2C48A") }, Count = 10, Size = 0.3, Life = { 0.3, 0.6 }, Speed = { 8, 14 }, Emission = 0 })
		for _, p in planks do
			local land = p[2] - Vector3.new(0, y - 0.6, 0) + c.Forward * ((math.random() - 0.5) * 6)
			tween(p[1], 0.12, { CFrame = CFrame.new(land) * CFrame.Angles(math.random() * 2, math.random() * 6, math.random() * 2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.delay(0.12, function()
			puff(c.Floor + Vector3.new(0, 0.5, 0), { Image = SQUARE, Colors = { Color3.fromHex("C8945A") }, Count = 14 + 30 * t, Size = 0.4, EndSize = 0.3, Life = { 0.5, 0.9 }, Speed = { 12, 22 }, Spread = 75, Accel = Vector3.new(0, -40, 0), Emission = 0, Spin = 400, Fade = 0 })
			ThrowFx.Shockwave(c.Floor, Color3.fromHex("E8CFA8"), 7 + 10 * t, 0.4)
			floorRing(c.Floor, Color3.fromHex("FFE0B0"), 8 + 10 * t, 0.45)
			CameraShake.Add(0.2 + 0.3 * t)
			Sfx.PlayAt("CrateLand", c.Lane.PinSpot, 0.9, 0.6 + 0.3 * t)
			task.delay(0.5, function()
				for _, p in planks do
					tween(p[1], 0.4, { Transparency = 1 })
				end
			end)
		end)
	end)
	Sfx.PlayAt("Roll", c.Lane.PinSpot, 1.5, 0.4)
end

-- 28 Temple Stone: carved stones with gold glyphs circle the rack, slam into the middle, a golden sunburst
function impacts.Temple(c)
	local t = c.T
	local count = math.floor(6 + 4 * t)
	local radius = 9 + 3 * t
	local stones = {}
	for i = 1, count do
		local size = 2 + t
		local p = solid(CFrame.new(c.Center), Vector3.one * size, Color3.fromHex("9C9C88"), 1.3, Enum.Material.Slate)
		local glyph = solid(CFrame.new(c.Center), Vector3.new(size * 0.6, size * 0.6, 0.15), GOLD, 1.3, Enum.Material.Neon)
		table.insert(stones, { p, glyph, (i / count) * math.pi * 2, size })
	end
	animate(0.25, function(k)
		for _, st in stones do
			local a = st[3] + k * math.pi * 1.5
			local r = radius * (1 - k * k * 0.85)
			local at = c.Center + c.Right * math.cos(a) * r + c.Forward * math.sin(a) * r + Vector3.new(0, 2 + (1 - k) * 4, 0)
			local face = CFrame.lookAt(at, Vector3.new(c.Center.X, at.Y, c.Center.Z))
			st[1].CFrame = face
			st[2].CFrame = face * CFrame.new(0, 0, -st[4] / 2 - 0.05)
		end
	end, function()
		task.delay(0.25, function()
			for _, st in stones do
				fadeParts({ st[1], st[2] }, 0.3)
			end
		end)
		sprite(c.Center + Vector3.new(0, 2, 0), IMAGES.Burst, GOLD, 4, 16 + 8 * t, 0.45, 90)
		glow(c.Center + Vector3.new(0, 2, 0), GOLD, 10 + 10 * t, 0.45, 6)
		for i = 1, 2 do
			task.delay((i - 1) * 0.07, function()
				floorRing(c.Floor + Vector3.new(0, i * 0.03, 0), GOLD, (7 + i * 4) * (1 + t * 0.6), 0.5)
			end)
		end
		puff(c.Center + Vector3.new(0, 1, 0), { Image = SQUARE, Colors = { Color3.fromHex("B8B8A0") }, Count = 12 + 20 * t, Size = 0.6, EndSize = 0.4, Life = { 0.5, 0.9 }, Speed = { 10, 20 }, Spread = 80, Accel = Vector3.new(0, -36, 0), Emission = 0, Spin = 300, Fade = 0 })
		puff(c.Center + Vector3.new(0, 1, 0), { Image = IMAGES.Star, Colors = { WHITE, GOLD }, Count = 14 + 30 * t, Size = 0.5, Life = { 0.4, 0.8 }, Speed = { 10, 22 }, Spin = 200 })
		CameraShake.Add(0.25 + 0.35 * t)
		Sfx.PlayAt("BossHit", c.Lane.PinSpot, 0.9, 0.5 + 0.3 * t)
	end)
	Sfx.PlayAt("PowerUp", c.Lane.PinSpot, 0.8, 0.4)
end

-- 29 Monsoon: a storm cloud rolls over the rack, heavy rain pours, then one huge lightning strike
function impacts.Monsoon(c)
	local t = c.T
	local sky = c.Center + Vector3.new(0, 11, 0)
	-- the storm cloud: dark puffs that swell in over the rack, then drift apart and fade
	local puffs = {}
	for i = 1, 8 do
		local at = sky + c.Right * ((i - 4.5) * 2.6) + c.Forward * (((i * 5) % 3) - 1) * 2 + Vector3.new(0, (i % 3) * 0.8, 0)
		local size = 5 + (i * 7) % 4 + 2 * t
		local cloud = solid(CFrame.new(at), Vector3.one * 0.5, Color3.fromHex("6E7890"):Lerp(Color3.fromHex("454E62"), (i % 3) / 2), 1.5)
		cloud.Shape = Enum.PartType.Ball
		cloud.Transparency = 0.1
		tween(cloud, 0.18, { Size = Vector3.one * size }, Enum.EasingStyle.Back)
		table.insert(puffs, cloud)
	end
	task.delay(0.9, function()
		for _, cloud in puffs do
			tween(cloud, 0.45, { Transparency = 1, Size = cloud.Size * 1.3 })
		end
	end)
	puff(sky + Vector3.new(0, 1, 0), { Image = IMAGES.Smoke, Colors = { Color3.fromHex("8C96AA") }, Count = 8 + 6 * t, Size = 5, EndSize = 7, Life = { 1.1, 1.5 }, Speed = { 1, 4 }, Spread = 90, Emission = 0, Fade = 0.15, Drag = 2 })
	-- rain: fast streaks from the cloud (a short rain emitter)
	local rain = holder(sky - Vector3.new(0, 1, 0), 1.6, Vector3.new(18 + 6 * t, 0.2, 10))
	local e = Instance.new("ParticleEmitter")
	e.Texture = IMAGES.TrailCore
	e.Color = ColorSequence.new(Color3.fromHex("CFE6FF"))
	e.LightEmission = 0.4
	e.Size = NumberSequence.new(0.3)
	e.Squash = NumberSequence.new(-3)
	e.Transparency = NumberSequence.new(0.05, 0.4)
	e.Lifetime = NumberRange.new(0.3, 0.4)
	e.Speed = NumberRange.new(36, 44)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(4, 4)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = 300 + 400 * t
	e.Parent = rain
	task.delay(0.9, function()
		e.Enabled = false
	end)
	for k = 1, 6 do
		task.delay(0.2 + k * 0.1, function()
			floorRing(c.Floor + c.Right * ((math.random() - 0.5) * 14) + c.Forward * ((math.random() - 0.5) * 8), Color3.fromHex("CFE6FF"), 2 + t * 2, 0.35)
		end)
	end
	task.delay(0.18, function()
		-- the strike: a jagged bolt from the cloud to the middle of the rack
		local points = { sky }
		for i = 1, 4 do
			table.insert(points, sky:Lerp(c.Center, i / 5) + c.Right * ((math.random() - 0.5) * 4) + c.Forward * ((math.random() - 0.5) * 3))
		end
		table.insert(points, c.Center)
		for i = 1, #points - 1 do
			local bolt = ribbon(points[i], points[i + 1], { Texture = IMAGES.TrailCore, Colors = { WHITE, Color3.fromHex("BFE0FF") }, Emission = 1, Width = 1.2 + t, Life = 0.35 })
			fadeRibbon(bolt, 0.1, 0.25)
		end
		glow(c.Center + Vector3.new(0, 1, 0), Color3.fromHex("BFE0FF"), 12 + 10 * t, 0.4, 10)
		floorRing(c.Floor, WHITE, 9 + 12 * t, 0.45)
		ThrowFx.Shockwave(c.Floor, c.Color, 8 + 12 * t, 0.4)
		splash(c.Center, t, 1.1)
		if c.Big and t > 0.3 then
			UiFx.Flash(Color3.fromHex("E6F2FF"), 0.2 + 0.25 * t, 0.2)
		end
		CameraShake.Add(0.3 + 0.4 * t)
		Sfx.PlayAt("OverchargeBlast", c.Lane.PinSpot, 1.2, 0.5 + 0.3 * t)
	end)
	Sfx.PlayAt("Teleport", c.Lane.PinSpot, 0.4, 0.5)
end

-- 30 Jungle King: a giant gold crown slams onto the rack, a roar shockwave blasts leaves and flowers everywhere
function impacts.JungleKing(c)
	local t = c.T
	local s = 1.4 + 1.2 * t
	local pieces = {
		{ Vector3.new(1.4, 7, 7) * s, CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.PartType.Cylinder, Enum.Material.Metal },
		{ Vector3.new(1.45, 6, 6) * s, CFrame.Angles(0, 0, math.rad(90)), Color3.fromHex("8A1E2E"), Enum.PartType.Cylinder },
	}
	for i = 0, 5 do
		local a = math.rad(i * 60)
		local at = Vector3.new(math.cos(a) * 3.2, 1.6, math.sin(a) * 3.2) * s
		table.insert(pieces, { Vector3.new(1.3, 2.4, 0.5) * s, CFrame.new(at) * CFrame.Angles(0, -a + math.pi / 2, 0), GOLD, nil, Enum.Material.Metal })
		table.insert(pieces, { Vector3.one * 0.7 * s, CFrame.new(at + Vector3.new(0, 1.5 * s, 0)), GOLD, Enum.PartType.Ball, Enum.Material.Metal })
		table.insert(pieces, { Vector3.one * 0.55 * s, CFrame.new(Vector3.new(math.cos(a) * 3.55, 0, math.sin(a) * 3.55) * s), if i % 2 == 0 then Color3.fromHex("FF3C5A") else Color3.fromHex("3CE6A0"), Enum.PartType.Ball, Enum.Material.Neon })
	end
	local land = c.Floor + Vector3.new(0, 0.7 * s, 0)
	local high = land + Vector3.new(0, 30, 0)
	local parts, move = rig(CFrame.new(high), pieces, 1.8)
	animate(0.2, function(k)
		move(CFrame.new(high:Lerp(land, k * k)) * CFrame.Angles(0, k * math.pi, 0))
	end, function()
		sprite(c.Center + Vector3.new(0, 3, 0), IMAGES.Burst, GOLD, 5, 20 + 10 * t, 0.5, 60)
		glow(c.Center + Vector3.new(0, 3, 0), GOLD, 14 + 12 * t, 0.5, 10)
		for i = 1, 3 do
			task.delay((i - 1) * 0.08, function()
				floorRing(c.Floor + Vector3.new(0, i * 0.03, 0), if i == 2 then Color3.fromHex("6CD65C") else GOLD, (8 + i * 5) * (1 + t * 0.6), 0.55)
			end)
		end
		ThrowFx.Shockwave(c.Floor, GOLD, 12 + 14 * t, 0.5)
		leafBurst(c.Center + Vector3.new(0, 2, 0), 24 + 30 * t, 26)
		for _, color in { Color3.fromHex("FF9A2E"), Color3.fromHex("FF5AA8"), Color3.fromHex("FFE45A") } do
			puff(c.Center + Vector3.new(0, 2, 0), { Image = IMAGES.Clover, Colors = { color }, Count = 6 + 10 * t, Size = 0.8, EndSize = 0.5, Life = { 0.8, 1.3 }, Speed = { 14, 26 }, Spread = 85, Accel = Vector3.new(0, -10, 0), Drag = 2, Emission = 0.3, Spin = 200, Fade = 0 })
		end
		puff(c.Center + Vector3.new(0, 1, 0), { Image = IMAGES.Star, Colors = { WHITE, GOLD }, Count = 20 + 40 * t, Size = 0.6, Life = { 0.5, 1 }, Speed = { 14, 30 }, Spin = 200 })
		if c.Big then
			UiFx.Flash(Color3.fromHex("FFF0B0"), 0.2 + 0.3 * t, 0.3)
		end
		CameraShake.Add(0.35 + 0.45 * t)
		Sfx.PlayAt("BossHit", c.Lane.PinSpot, 0.7, 0.7 + 0.3 * t)
		Sfx.PlayAt("Firework", c.Lane.PinSpot, 1, 0.4)
		task.delay(0.8, function()
			fadeParts(parts, 0.4)
		end)
	end)
end

---------------------------------------------------------------------------------------------------------------
-- Zone 4, Canyon Oasis (Addendum 6 Stage 6): desert effects, one per ball
---------------------------------------------------------------------------------------------------------------
local SAND = { Color3.fromHex("F7DCA8"), Color3.fromHex("E8B878"), Color3.fromHex("D2964E") }
local TERRACOTTA = Color3.fromHex("D2643C")
local TURQUOISE = Color3.fromHex("3CDCD2")

-- A cloud of sand thrown up at one point (scale 1 = a normal puff)
local function sandBurst(at: Vector3, t: number, scale: number)
	puff(at, { Image = IMAGES.Smoke, Colors = { SAND[1], SAND[2] }, Count = (6 + 10 * t) * scale, Size = 2.6 * scale, EndSize = 5 * scale, Life = { 0.6, 1 }, Speed = { 4, 10 * scale }, Spread = 70, Emission = 0, Fade = 0.15, Drag = 2 })
	puff(at, { Image = IMAGES.Dot, Colors = { SAND[3] }, Count = (12 + 26 * t) * scale, Size = 0.35, EndSize = 0.2, Life = { 0.5, 0.9 }, Speed = { 10, 20 * scale }, Spread = 75, Accel = Vector3.new(0, -40, 0), Drag = 0.5, Emission = 0 })
end

-- 31 Dust Devil: a whirling column of dust sweeps across the rack, tumbleweeds roll out of it
function impacts.DustDevil(c)
	local t = c.T
	local from = c.Center - c.Right * 14
	local to = c.Center + c.Right * 12
	local height = 12 + 6 * t
	local rings = 12
	local bits = {}
	for i = 1, rings do
		local k = i / rings
		local cloud = solid(CFrame.new(from), Vector3.one * (1.8 + k * 4.4 * (1 + t * 0.5)), SAND[(i % 3) + 1], 1.4)
		cloud.Shape = Enum.PartType.Ball
		cloud.Transparency = 0.35
		table.insert(bits, { cloud, k })
	end
	animate(0.6, function(k)
		local base = from:Lerp(to, k)
		for _, b in bits do
			local a = os.clock() * 14 + b[2] * 9
			local r = 0.8 + b[2] * 3.2 * (1 + t * 0.4)
			b[1].CFrame = CFrame.new(base + Vector3.new(math.cos(a) * r, b[2] * height, math.sin(a) * r))
		end
		if math.random() < 0.35 then
			puff(base + Vector3.new(0, 1, 0), { Image = IMAGES.Smoke, Colors = { SAND[1] }, Count = 2, Size = 3, EndSize = 5, Life = { 0.4, 0.7 }, Speed = { 3, 6 }, Emission = 0, Fade = 0.3 })
		end
	end, function()
		for _, b in bits do
			tween(b[1], 0.35, { Transparency = 1, Size = b[1].Size * 1.6 })
		end
	end)
	sprite(c.Center + Vector3.new(0, 4, 0), IMAGES.Spiral, Color3.fromHex("E8B878"), 4, 12 + 6 * t, 0.6, 900)
	task.delay(0.25, function()
		-- tumbleweeds bounce out
		for i = 1, math.floor(2 + 2 * t) do
			local start = c.Center + c.Right * ((i - 1.5) * 3) + Vector3.new(0, 1.2, 0)
			local weed = solid(CFrame.new(start), Vector3.one * (1.6 + t), Color3.fromHex("B48C50"), 1.3, Enum.Material.Grass)
			weed.Shape = Enum.PartType.Ball
			weed.Transparency = 0.15
			local dir = (c.Right * (if i % 2 == 0 then 1 else -1) - c.Forward * 0.6).Unit
			animate(0.8, function(k)
				local hop = math.abs(math.sin(k * math.pi * 3)) * 2.4 * (1 - k)
				weed.CFrame = CFrame.new(start + dir * k * 16 + Vector3.new(0, hop, 0)) * CFrame.Angles(k * 12, 0, k * 8)
			end, function()
				tween(weed, 0.3, { Transparency = 1 })
			end)
		end
		sandBurst(c.Center, t, 1)
		floorRing(c.Floor, Color3.fromHex("E8B878"), 6 + 9 * t, 0.45)
		ThrowFx.Shockwave(c.Floor, c.Color, 5 + 9 * t, 0.35)
		Sfx.PlayAt("Tap", c.Lane.PinSpot, 0.9, 0.6)
	end)
	Sfx.PlayAt("Throw", c.Lane.PinSpot, 0.7, 0.6 + 0.2 * t)
end

-- 32 Cactus Roller: saguaros burst up through the rack, spines fly, pink flowers pop on top
function impacts.Cactus(c)
	local t = c.T
	local count = math.floor(3 + 3 * t)
	local green = Color3.fromHex("4CB04C")
	for i = 1, count do
		task.delay((i - 1) * 0.04, function()
			local x = (i - (count + 1) / 2) * (14 / count) * 1.6
			local foot = c.Floor + c.Right * x + c.Forward * (((i * 7) % 5) - 2)
			local h = 7 + 3 * t + (i % 2) * 2
			local side = if i % 2 == 0 then 1 else -1
			local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- (cylinders run along X)
			local hidden = CFrame.new(foot - Vector3.new(0, h, 0))
			local trunk = solid(hidden * UPRIGHT, Vector3.new(h, 1.8, 1.8), green, 1.5, Enum.Material.Grass)
			trunk.Shape = Enum.PartType.Cylinder
			local elbow = solid(hidden, Vector3.new(1.1, 1.1, 1.8), green, 1.5, Enum.Material.Grass)
			local arm = solid(hidden * UPRIGHT, Vector3.new(h * 0.32, 1.2, 1.2), green, 1.5, Enum.Material.Grass)
			arm.Shape = Enum.PartType.Cylinder
			tween(trunk, 0.14, { CFrame = CFrame.new(foot + Vector3.new(0, h / 2, 0)) * UPRIGHT }, Enum.EasingStyle.Back)
			tween(elbow, 0.14, { CFrame = CFrame.lookAt(foot + c.Right * side * 1.2 + Vector3.new(0, h * 0.45, 0), foot + c.Right * side * 5 + Vector3.new(0, h * 0.45, 0)) }, Enum.EasingStyle.Back)
			tween(arm, 0.14, { CFrame = CFrame.new(foot + c.Right * side * 2.1 + Vector3.new(0, h * 0.45 + h * 0.16, 0)) * UPRIGHT }, Enum.EasingStyle.Back)
			task.delay(0.14, function()
				puff(foot + Vector3.new(0, h * 0.5, 0), { Image = IMAGES.TrailCore, Colors = { Color3.fromHex("FFF6D8") }, Count = 10 + 14 * t, Size = 0.25, EndSize = 0.1, Life = { 0.3, 0.6 }, Speed = { 14, 24 }, Spread = 180, Emission = 0.4 })
				puff(foot + Vector3.new(0, h + 0.6, 0), { Image = IMAGES.Clover, Colors = { Color3.fromHex("FF6EAA") }, Count = 4 + 4 * t, Size = 0.9, EndSize = 0.5, Life = { 0.6, 1 }, Speed = { 4, 9 }, Spread = 60, Accel = Vector3.new(0, -10, 0), Emission = 0.3, Spin = 200, Fade = 0 })
				local bloom = solid(CFrame.new(foot + Vector3.new(0, h + 0.4, 0)), Vector3.one * 0.3, Color3.fromHex("FF6EAA"), 1.3)
				bloom.Shape = Enum.PartType.Ball
				tween(bloom, 0.2, { Size = Vector3.one * (1.4 + t) }, Enum.EasingStyle.Back)
				sandBurst(foot, t, 0.5)
			end)
			task.delay(0.75, function()
				for _, p in { trunk, elbow, arm } do
					tween(p, 0.3, { CFrame = p.CFrame - Vector3.new(0, h, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end)
		end)
	end
	floorRing(c.Floor, green, 6 + 9 * t, 0.45)
	ThrowFx.Shockwave(c.Floor, c.Color, 5 + 9 * t, 0.35)
	Sfx.PlayAt("CrateLand", c.Lane.PinSpot, 1.4, 0.5 + 0.3 * t)
end

-- 33 Mesa Smash: a flat-topped red mesa drops out of the sky onto the rack, rock chunks and a sand blast
function impacts.Mesa(c)
	local t = c.T
	local w = 9 + 5 * t
	local pieces = {}
	local bands = 4
	for i = 0, bands - 1 do
		table.insert(pieces, { Vector3.new(w * (1 - i * 0.08), 1.6, w * 0.8 * (1 - i * 0.08)), CFrame.new(0, i * 1.6, 0), if i % 2 == 0 then TERRACOTTA else Color3.fromHex("F0A878"), nil, Enum.Material.Sandstone })
	end
	table.insert(pieces, { Vector3.new(w * 0.78, 0.6, w * 0.6), CFrame.new(0, bands * 1.6 - 0.5, 0), Color3.fromHex("8CB45A"), nil, Enum.Material.Grass })
	local land = c.Floor + Vector3.new(0, 0.8, 0)
	local high = land + Vector3.new(0, 34, 0)
	local parts, move = rig(CFrame.new(high), pieces, 1.6)
	animate(0.2, function(k)
		move(CFrame.new(high:Lerp(land, k * k)) * CFrame.Angles(0, (1 - k) * 0.6, 0))
	end, function()
		sandBurst(c.Center, t, 1.5)
		puff(c.Floor + Vector3.new(0, 1, 0), { Image = SQUARE, Colors = { TERRACOTTA }, Count = 16 + 30 * t, Size = 0.8, EndSize = 0.5, Life = { 0.5, 0.9 }, Speed = { 14, 26 }, Spread = 70, Accel = Vector3.new(0, -50, 0), Emission = 0, Spin = 400, Fade = 0 })
		for i = 1, 2 do
			task.delay((i - 1) * 0.08, function()
				floorRing(c.Floor + Vector3.new(0, i * 0.03, 0), if i == 1 then Color3.fromHex("F0A878") else TERRACOTTA, (8 + i * 4) * (1 + t * 0.6), 0.5)
			end)
		end
		ThrowFx.Shockwave(c.Floor, Color3.fromHex("F0C890"), 10 + 12 * t, 0.45)
		CameraShake.Add(0.3 + 0.4 * t)
		Sfx.PlayAt("BossHit", c.Lane.PinSpot, 0.8, 0.6 + 0.3 * t)
		task.delay(0.45, function()
			move(CFrame.new(land - Vector3.new(0, 0.4, 0)))
			fadeParts(parts, 0.4)
		end)
	end)
	Sfx.PlayAt("Throw", c.Lane.PinSpot, 0.5, 0.5)
end

-- 34 Sandstorm: a towering wall of sand sweeps across the rack from the side, the sky goes orange for a moment
function impacts.Sandstorm(c)
	local t = c.T
	local width = 10
	local from = c.Center - c.Right * 18 + Vector3.new(0, 5, 0)
	local to = c.Center + c.Right * 18 + Vector3.new(0, 5, 0)
	local front = holder(from, 1.6, Vector3.new(2, 12 + 4 * t, width + 6))
	front.CFrame = CFrame.lookAt(from, from + c.Right)
	local e = Instance.new("ParticleEmitter")
	e.Texture = IMAGES.Smoke
	e.Color = colors({ SAND[1], SAND[2] })
	e.LightEmission = 0
	e.Size = NumberSequence.new(7, 11)
	e.Transparency = NumberSequence.new(0.05, 1)
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(6, 12)
	e.EmissionDirection = Enum.NormalId.Front
	e.SpreadAngle = Vector2.new(25, 25)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Rate = 220 + 200 * t
	e.Parent = front
	local grit = e:Clone()
	grit.Texture = IMAGES.Dot
	grit.Color = ColorSequence.new(SAND[3])
	grit.Size = NumberSequence.new(0.3, 0.15)
	grit.Speed = NumberRange.new(20, 30)
	grit.Rate = 200 + 200 * t
	grit.Parent = front
	tween(front, 0.6, { CFrame = CFrame.lookAt(to, to + c.Right) }, Enum.EasingStyle.Linear)
	task.delay(0.6, function()
		e.Enabled = false
		grit.Enabled = false
	end)
	if c.Big then
		UiFx.Flash(Color3.fromHex("FFC88C"), 0.15 + 0.2 * t, 0.4)
	end
	task.delay(0.25, function()
		sandBurst(c.Center, t, 1.2)
		floorRing(c.Floor, Color3.fromHex("F0B464"), 7 + 10 * t, 0.5)
		ThrowFx.Shockwave(c.Floor, c.Color, 6 + 10 * t, 0.4)
		Sfx.PlayAt("Teleport", c.Lane.PinSpot, 0.7, 0.6 + 0.3 * t)
	end)
	Sfx.PlayAt("Throw", c.Lane.PinSpot, 0.6, 0.7)
end

-- 35 Oasis Spring: a turquoise spring bursts up out of the rack, palm fronds fan open round it, droplets rain down
function impacts.Oasis(c)
	local t = c.T
	local width = 3 + 3 * t
	local foot = c.Floor + Vector3.new(0, 0.3, 0)
	local beam, _, a1 = ribbon(foot, foot + Vector3.new(0, 1, 0), {
		Texture = IMAGES.TrailWisp,
		Mode = Enum.TextureMode.Wrap,
		Length = 5,
		Speed = 3,
		Colors = { WHITE, Color3.fromHex("9BF5EE"), TURQUOISE },
		Emission = 0.4,
		Width = width,
		Width1 = width * 1.8,
		Life = 1.1,
	})
	tween(a1, 0.18, { Position = foot + Vector3.new(0, 16 + 6 * t, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	fadeRibbon(beam, 0.5, 0.5)
	splash(c.Center, t, 1, { WHITE, Color3.fromHex("9BF5EE"), TURQUOISE })
	task.delay(0.18, function()
		local top = foot + Vector3.new(0, 16 + 6 * t, 0)
		puff(top, { Image = IMAGES.Dot, Colors = { Color3.fromHex("9BF5EE") }, Count = 24 + 30 * t, Size = 0.6, EndSize = 0.3, Life = { 0.8, 1.2 }, Speed = { 8, 16 }, Spread = 100, Accel = Vector3.new(0, -40, 0), Drag = 0.5, Emission = 0.4 })
		-- palm fronds fan out round the spring
		local fronds = math.floor(6 + 4 * t)
		for i = 1, fronds do
			local a = i / fronds * math.pi * 2
			local dir = (c.Right * math.cos(a) + c.Forward * math.sin(a))
			local base = foot + Vector3.new(0, 0.4, 0)
			local p = leafPart(CFrame.lookAt(base, base + dir) * CFrame.Angles(math.rad(80), 0, 0), 1, LEAVES[i % #LEAVES + 1], 1.3)
			tween(p, 0.25, { Size = Vector3.new(2.6 + t, 0.2, 7 + 3 * t), CFrame = CFrame.lookAt(base + dir * (3.5 + 1.5 * t), base + dir * 10 + Vector3.new(0, 1.5, 0)) }, Enum.EasingStyle.Back)
			task.delay(0.8, function()
				tween(p, 0.35, { Transparency = 1 })
			end)
		end
		floorRing(c.Floor, TURQUOISE, 7 + 10 * t, 0.5)
		floorRing(c.Floor + Vector3.new(0, 0.03, 0), WHITE, 5 + 7 * t, 0.45)
		glow(c.Center + Vector3.new(0, 2, 0), TURQUOISE, 10 + 8 * t, 0.45, 4)
		ThrowFx.Shockwave(c.Floor, TURQUOISE, 6 + 10 * t, 0.4)
		Sfx.PlayAt("Teleport", c.Lane.PinSpot, 1.3, 0.5 + 0.3 * t)
	end)
	Sfx.PlayAt("PowerUp", c.Lane.PinSpot, 1.2, 0.4)
end

-- 36 Scorpion: a giant scorpion tail curls over from behind the rack and stings it, a burst of hot venom
function impacts.Scorpion(c)
	local t = c.T
	local s = 1.3 + 0.9 * t
	local segs = 7
	local shell = { Color3.fromHex("C8461E"), Color3.fromHex("8C2A14") }
	local parts = {}
	for i = 1, segs do
		local p = solid(CFrame.new(c.Center), Vector3.one * (2.6 - i * 0.18) * s, shell[i % 2 + 1], 1.4)
		p.Shape = Enum.PartType.Ball
		table.insert(parts, p)
	end
	local stinger = solid(CFrame.new(c.Center), Vector3.new(0.5, 0.5, 2.4) * s, Color3.fromHex("FFB43C"), 1.4, Enum.Material.Neon)
	local root = c.Center + c.Right * (11 + 3 * t) + c.Forward * 2
	-- the tail: a curve from its root beside the rack, up high and over; the tip moves from raised (k = 0) to
	-- stabbing the middle of the rack (k = 1)
	local height = 12 + 4 * t
	local toward = -c.Right
	local control = root + Vector3.new(0, height * 1.3, 0) + toward * 3
	local restTip = root + Vector3.new(0, height, 0) + toward * 7
	local strikeTip = c.Center + Vector3.new(0, 1.5, 0)
	local function pose(k: number)
		local tip = restTip:Lerp(strikeTip, k)
		local function at(u: number): Vector3
			return root:Lerp(control, u):Lerp(control:Lerp(tip, u), u)
		end
		for i = 1, segs do
			parts[i].CFrame = CFrame.new(at(i / (segs + 1)))
		end
		local before = at(segs / (segs + 1))
		stinger.CFrame = CFrame.lookAt(tip, tip + (tip - before).Unit)
	end
	pose(0)
	animate(0.18, function(k)
		pose(k * k)
	end, function()
		local tip = stinger.Position
		glow(tip, Color3.fromHex("FFB43C"), 8 + 8 * t, 0.4, 6)
		sprite(c.Center + Vector3.new(0, 2, 0), IMAGES.Burst, Color3.fromHex("FF7A3C"), 4, 14 + 8 * t, 0.45, 120)
		puff(c.Center + Vector3.new(0, 1, 0), { Image = IMAGES.Dot, Colors = { Color3.fromHex("FFE45A") }, Count = 16 + 30 * t, Size = 0.7, EndSize = 0.2, Life = { 0.5, 0.9 }, Speed = { 12, 24 }, Spread = 80, Accel = Vector3.new(0, -30, 0), Emission = 0.8 })
		puff(c.Center + Vector3.new(0, 1, 0), { Image = IMAGES.Dot, Colors = { Color3.fromHex("FF5A1E") }, Count = 10 + 20 * t, Size = 0.9, EndSize = 0.3, Life = { 0.5, 0.9 }, Speed = { 10, 20 }, Spread = 80, Accel = Vector3.new(0, -30, 0), Emission = 0.6 })
		floorRing(c.Floor, Color3.fromHex("FF7A3C"), 7 + 10 * t, 0.45)
		ThrowFx.Shockwave(c.Floor, c.Color, 7 + 10 * t, 0.4)
		CameraShake.Add(0.2 + 0.3 * t)
		Sfx.PlayAt("BossPlate", c.Lane.PinSpot, 1.1, 0.6 + 0.3 * t)
		task.delay(0.5, function()
			animate(0.3, function(k)
				pose(1 - k)
			end)
			task.delay(0.15, function()
				fadeParts(parts, 0.25)
				fadeParts({ stinger }, 0.25)
			end)
		end)
	end)
	sandBurst(root, t, 0.7)
	Sfx.PlayAt("Throw", c.Lane.PinSpot, 1.2, 0.5)
end

-- 37 Sun Disc: a gold sun disc blazes over the rack and burns rays down into it, heat ripples and a gold flare
function impacts.SunDisc(c)
	local t = c.T
	local sky = c.Center + Vector3.new(0, 8 + 2 * t, 0) + c.Forward * 2
	local disc = solid(CFrame.lookAt(sky, sky - c.Forward) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(0.6, 1, 1), Color3.fromHex("FFD23C"), 1.4, Enum.Material.Neon)
	disc.Shape = Enum.PartType.Cylinder
	tween(disc, 0.15, { Size = Vector3.new(0.6, 6 + 3 * t, 6 + 3 * t) }, Enum.EasingStyle.Back)
	local rim = solid(disc.CFrame * CFrame.new(-0.2, 0, 0), Vector3.new(0.5, 1, 1), Color3.fromHex("FF8A2E"), 1.4, Enum.Material.Neon)
	rim.Shape = Enum.PartType.Cylinder
	tween(rim, 0.15, { Size = Vector3.new(0.5, 7.6 + 3.6 * t, 7.6 + 3.6 * t) }, Enum.EasingStyle.Back)
	sprite(sky, IMAGES.Burst, GOLD, 4, 18 + 8 * t, 0.9, 120)
	glow(sky, Color3.fromHex("FFE27A"), 14 + 8 * t, 0.9, 6)
	task.delay(0.1, function()
		local rays = math.floor(5 + 4 * t)
		for i = 1, rays do
			local a = i / rays * math.pi * 2
			local land = c.Floor + c.Right * math.cos(a) * (3 + 2 * t) + c.Forward * math.sin(a) * (3 + 2 * t)
			local beam = ribbon(sky, land, { Texture = IMAGES.TrailCore, Colors = { WHITE, Color3.fromHex("FFD23C") }, Emission = 1, Width = 0.8 + 0.6 * t, Width1 = 1.6 + t, Life = 0.7 })
			fadeRibbon(beam, 0.3, 0.35)
			floorRing(land + Vector3.new(0, 0.02, 0), Color3.fromHex("FFE27A"), 2 + 2 * t, 0.4)
		end
		floorRing(c.Floor, GOLD, 8 + 10 * t, 0.5)
		sprite(c.Center + Vector3.new(0, 1, 0), IMAGES.Ring, Color3.fromHex("FFF0B0"), 4, 14 + 8 * t, 0.4)
		puff(c.Center + Vector3.new(0, 1, 0), { Image = SPARKLE, Colors = { WHITE, GOLD }, Count = 20 + 30 * t, Size = 0.8, Life = { 0.4, 0.8 }, Speed = { 10, 20 }, Spin = 200 })
		ThrowFx.Shockwave(c.Floor, GOLD, 8 + 10 * t, 0.4)
		if c.Big then
			UiFx.Flash(Color3.fromHex("FFF0B0"), 0.15 + 0.25 * t, 0.25)
		end
		Sfx.PlayAt("PowerUp", c.Lane.PinSpot, 0.7, 0.6 + 0.3 * t)
	end)
	task.delay(0.8, function()
		tween(disc, 0.35, { Transparency = 1, Size = Vector3.new(0.6, 1, 1) })
		tween(rim, 0.35, { Transparency = 1, Size = Vector3.new(0.5, 1, 1) })
	end)
end

-- 38 Canyon Echo: two red rock walls burst up beside the rack and the hit bounces between them three times
function impacts.Echo(c)
	local t = c.T
	local gap = 10 + 3 * t
	local h = 7 + 3 * t
	local walls = {}
	for _, s in { -1, 1 } do
		local at = c.Floor + c.Right * s * gap
		local w = solid(CFrame.lookAt(at - Vector3.new(0, h / 2, 0), at - Vector3.new(0, h / 2, 0) + c.Forward), Vector3.new(2.4, h, 9), TERRACOTTA, 1.6, Enum.Material.Sandstone)
		local band = solid(w.CFrame, Vector3.new(2.5, h * 0.25, 9.1), Color3.fromHex("F0A878"), 1.6, Enum.Material.Sandstone)
		tween(w, 0.12, { CFrame = w.CFrame + Vector3.new(0, h, 0) }, Enum.EasingStyle.Back)
		tween(band, 0.12, { CFrame = band.CFrame + Vector3.new(0, h * 1.1, 0) }, Enum.EasingStyle.Back)
		sandBurst(at, t, 0.5)
		table.insert(walls, { w, band })
	end
	for k = 0, 2 do
		task.delay(0.1 + k * 0.16, function()
			local scale = 1 - k * 0.25
			local side = if k % 2 == 0 then 1 else -1
			sprite(c.Center + Vector3.new(0, 2, 0), IMAGES.Ring, Color3.fromHex("FF9A5A"):Lerp(WHITE, k * 0.3), 3, (gap * 2.2) * scale, 0.3)
			floorRing(c.Floor + Vector3.new(0, k * 0.02, 0), Color3.fromHex("FF9A5A"), gap * scale, 0.35)
			ThrowFx.Shockwave(c.Floor, c.Color, (6 + 8 * t) * scale, 0.3)
			glow(c.Floor + c.Right * side * (gap - 1.5) + Vector3.new(0, h * 0.5, 0), Color3.fromHex("FFC88C"), 6 * scale, 0.3, 3)
			-- the echo: a glowing wave crosses from one wall to the other
			local fromAt = c.Floor + c.Right * side * (gap - 1.5) + Vector3.new(0, h * 0.45, 0)
			local toAt = c.Floor - c.Right * side * (gap - 1.5) + Vector3.new(0, h * 0.45, 0)
			local wave = solid(CFrame.lookAt(fromAt, fromAt + c.Forward), Vector3.new(1.2, h * 0.9 * scale, 8), Color3.fromHex("FFB878"), 0.7, Enum.Material.Neon)
			wave.Transparency = 0.1
			tween(wave, 0.2, { CFrame = CFrame.lookAt(toAt, toAt + c.Forward), Transparency = 0.6 }, Enum.EasingStyle.Linear)
			task.delay(0.2, function()
				tween(wave, 0.15, { Transparency = 1 })
			end)
			CameraShake.Add((0.15 + 0.2 * t) * scale)
			Sfx.PlayAt("BossHit", c.Lane.PinSpot, 1 + k * 0.15, (0.5 + 0.3 * t) * scale)
		end)
	end
	task.delay(0.85, function()
		for _, w in walls do
			for _, p in w do
				tween(p, 0.3, { CFrame = p.CFrame - Vector3.new(0, h, 0), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end
	end)
end

-- 39 Mirage: shimmering see-through copies of the ball close in from all round, merge, and the air ripples turquoise
function impacts.Mirage(c)
	local t = c.T
	local count = math.floor(5 + 3 * t)
	local radius = 12 + 4 * t
	local ghosts = {}
	for i = 1, count do
		local a = i / count * math.pi * 2
		local at = c.Center + c.Right * math.cos(a) * radius + c.Forward * math.sin(a) * radius + Vector3.new(0, 1.5, 0)
		local g = solid(CFrame.new(at), Vector3.one * (2 + t), Color3.fromHex("9BF5EE"), 1, Enum.Material.Glass)
		g.Shape = Enum.PartType.Ball
		g.Transparency = 0.55
		table.insert(ghosts, { g, at })
	end
	animate(0.22, function(k)
		for i, g in ghosts do
			local wob = math.sin(k * 20 + i) * 0.6
			g[1].CFrame = CFrame.new(g[2]:Lerp(c.Center + Vector3.new(0, 1.5, 0), k * k) + c.Right * wob)
			g[1].Transparency = 0.55 + math.sin(k * 30 + i) * 0.2
		end
	end, function()
		for _, g in ghosts do
			g[1]:Destroy()
		end
		for i = 0, 3 do
			task.delay(i * 0.07, function()
				sprite(c.Center + Vector3.new(0, 1.5, 0), IMAGES.Ring, if i % 2 == 0 then TURQUOISE else Color3.fromHex("FFE6C4"), 2, (10 + 8 * t) * (1 + i * 0.3), 0.4)
				floorRing(c.Floor + Vector3.new(0, i * 0.02, 0), if i % 2 == 0 then TURQUOISE else Color3.fromHex("FFE6C4"), (5 + 6 * t) * (1 + i * 0.35), 0.45)
			end)
		end
		glow(c.Center + Vector3.new(0, 2, 0), Color3.fromHex("BFFFF8"), 12 + 10 * t, 0.5, 6)
		puff(c.Center + Vector3.new(0, 1.5, 0), { Image = SPARKLE, Colors = { WHITE, TURQUOISE }, Count = 20 + 30 * t, Size = 0.7, Life = { 0.4, 0.8 }, Speed = { 10, 22 }, Spin = 200 })
		puff(c.Center + Vector3.new(0, 1.5, 0), { Image = IMAGES.Smoke, Colors = { Color3.fromHex("CFFFFA") }, Count = 8 + 8 * t, Size = 3, EndSize = 6, Life = { 0.5, 0.8 }, Speed = { 4, 8 }, Emission = 0.2, Fade = 0.4 })
		ThrowFx.Shockwave(c.Floor, TURQUOISE, 8 + 10 * t, 0.4)
		Sfx.PlayAt("Teleport", c.Lane.PinSpot, 1.6, 0.6 + 0.3 * t)
	end)
	Sfx.PlayAt("PowerUp", c.Lane.PinSpot, 1.5, 0.4)
end

-- 40 Golden Sphinx: a giant golden sphinx head rises out of the sand behind the rack, its eyes blast beams into it
function impacts.Sphinx(c)
	local t = c.T
	local s = 1.6 + 1.2 * t
	local gold, deep = Color3.fromHex("FFC83C"), Color3.fromHex("D29632")
	local pieces = {
		{ Vector3.new(3.4, 3.8, 3.2) * s, CFrame.new(), gold, nil, Enum.Material.Metal },
		{ Vector3.new(4.8, 0.8, 3.6) * s, CFrame.new(0, 2.2 * s, 0.2 * s), TURQUOISE, nil, Enum.Material.Metal },
		{ Vector3.new(0.8, 1.8, 0.6) * s, CFrame.new(0, -2.6 * s, -1.4 * s), TURQUOISE, nil, Enum.Material.Metal },
	}
	for k = 0, 4 do
		for _, sd in { -1, 1 } do
			table.insert(pieces, { Vector3.new(0.7, 1, 3) * s, CFrame.new(sd * 2.1 * s, (1.4 - k) * s, 0.3 * s), if k % 2 == 0 then TURQUOISE else deep, nil, Enum.Material.Metal })
		end
	end
	local eyes = {}
	for _, sd in { -1, 1 } do
		table.insert(pieces, { Vector3.new(0.8, 0.45, 0.2) * s, CFrame.new(sd * 0.8 * s, 0.5 * s, -1.65 * s), Color3.fromHex("1E5A5A"), nil, Enum.Material.Neon })
		table.insert(eyes, #pieces)
	end
	local rise = c.Center + c.Forward * (9 + 3 * t)
	local low = rise - Vector3.new(0, 6 * s, 0)
	local high = rise + Vector3.new(0, 2.6 * s, 0)
	local face = CFrame.lookAt(Vector3.zero, -c.Forward) -- (looks back at the rack)
	local parts, move = rig(CFrame.new(low) * face, pieces, 2)
	sandBurst(rise, t, 1.3)
	animate(0.18, function(k)
		move(CFrame.new(low:Lerp(high, math.sin(k * math.pi / 2))) * face)
	end, function()
		for _, i in eyes do
			parts[i].Color = Color3.fromHex("7AFFF4")
		end
		for _, i in eyes do
			local from = parts[i].Position
			local beam = ribbon(from, c.Center + Vector3.new(0, 0.6, 0), { Texture = IMAGES.TrailCore, Colors = { WHITE, TURQUOISE }, Emission = 1, Width = 0.8 + 0.6 * t, Width1 = 1.4 + t, Life = 0.6 })
			fadeRibbon(beam, 0.25, 0.3)
		end
		task.delay(0.04, function()
			sprite(c.Center + Vector3.new(0, 3, 0), IMAGES.Burst, gold, 5, 20 + 10 * t, 0.5, 60)
			glow(c.Center + Vector3.new(0, 3, 0), gold, 14 + 12 * t, 0.5, 10)
			for i = 1, 3 do
				task.delay((i - 1) * 0.08, function()
					floorRing(c.Floor + Vector3.new(0, i * 0.03, 0), if i == 2 then TURQUOISE else gold, (8 + i * 5) * (1 + t * 0.6), 0.55)
				end)
			end
			-- a glowing pyramid outline over the rack
			local apex = c.Center + Vector3.new(0, 9 + 3 * t, 0)
			local r = 7 + 3 * t
			for _, a in { 0, 1, 2, 3 } do
				local ang = a * math.pi / 2 + math.pi / 4
				local corner = c.Floor + c.Right * math.cos(ang) * r + c.Forward * math.sin(ang) * r
				local edge = ribbon(corner, apex, { Texture = IMAGES.TrailCore, Colors = { gold }, Emission = 1, Width = 0.5, Life = 0.8 })
				fadeRibbon(edge, 0.4, 0.4)
			end
			ThrowFx.Shockwave(c.Floor, gold, 12 + 14 * t, 0.5)
			sandBurst(c.Center, t, 1.5)
			puff(c.Center + Vector3.new(0, 1, 0), { Image = IMAGES.Star, Colors = { WHITE, gold }, Count = 20 + 40 * t, Size = 0.6, Life = { 0.5, 1 }, Speed = { 14, 30 }, Spin = 200 })
			if c.Big then
				UiFx.Flash(Color3.fromHex("FFF0B0"), 0.2 + 0.3 * t, 0.3)
			end
			CameraShake.Add(0.35 + 0.45 * t)
			Sfx.PlayAt("BossHit", c.Lane.PinSpot, 0.6, 0.7 + 0.3 * t)
			Sfx.PlayAt("Firework", c.Lane.PinSpot, 0.9, 0.4)
		end)
		task.delay(0.9, function()
			animate(0.4, function(k)
				move(CFrame.new(high:Lerp(low, k * k)) * face)
			end)
		end)
	end)
	Sfx.PlayAt("PowerUp", c.Lane.PinSpot, 0.6, 0.5)
end

-- Seconds the pins wait for an effect's falling part (keep at or under 0.2: the next rack stands soon after)
local HOLD = {
	Coconut = 0.18, Toucan = 0.15, Waterfall = 0.15, Bridge = 0.2, Temple = 0.2, Monsoon = 0.18, JungleKing = 0.2,
	Mesa = 0.2, Cactus = 0.14, Scorpion = 0.18, SunDisc = 0.1, Mirage = 0.2, Sphinx = 0.2, Oasis = 0.1,
}

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
	local wait = HOLD[name] -- (zone 3: the pins wait for the falling bit to land)
	if wait then
		return wait
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
