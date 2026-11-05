-- The thumbnail look on every one of your own throws (owner 2026-11-05, numbers in Config.HitHero): a hard-edged colour
-- streak on the lane behind the ball, then at the pins a sunburst BEHIND the rack (so the pins read as shapes against
-- it), a one-frame glint, long sparks, pin chips, a few coins and a burst of light. Short enough for a throw a second.
-- It sits under the ball's own signature effect (BallSignature). Visual only.
-- SETTINGS: EFFECTS off = none of this.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetSlots = require(Shared.AssetSlots)
local Settings = require(script.Parent.Settings)
local SlKit = require(script.Parent.SlKit)

local HERO = Config.HitHero
local SQUARE = "rbxasset://textures/particles/SquareParticle.png"
local WHITE = Color3.new(1, 1, 1)

local HitHero = {}

local folder = Instance.new("Folder")
folder.Name = "HitHero"
folder.Parent = Workspace

local function holder(position: Vector3, life: number): Part
	local p = Instance.new("Part")
	p.Name = "Hit"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.Position = position
	p.Parent = folder
	Debris:AddItem(p, life)
	return p
end

local function tween(object: Instance, time: number, goals, style: Enum.EasingStyle?, direction: Enum.EasingDirection?, delay: number?)
	TweenService:Create(
		object,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out, 0, false, delay or 0),
		goals
	):Play()
end

-- The colours of a throw: { Core (palest), Ray (main), Deep (outer) }. A ball with its own effect colour tints them;
-- a LUCKY throw is always gold.
local function palette(color: Color3?, lucky: boolean)
	local main = if lucky or not color then HERO.Gold else color:Lerp(HERO.Gold, HERO.GoldMix)
	return {
		Core = main:Lerp(WHITE, 0.65),
		Ray = main,
		Deep = (if lucky or not color then HERO.Orange else color:Lerp(HERO.Orange, HERO.GoldMix * 0.7)):Lerp(Color3.new(0, 0, 0), 0.08),
	}
end

HitHero.Palette = palette

-- ===== The roll: a flat streak on the lane, narrow and pale inside a wider, deeper one =====
local function floorTrail(carrier: BasePart, width: number, color: Color3, deep: Color3, life: number, alpha: number)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-width / 2, 0, 0)
	a0.Parent = carrier
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(width / 2, 0, 0)
	a1.Parent = carrier
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color, deep)
	trail.Transparency = NumberSequence.new(alpha, 1)
	trail.WidthScale = NumberSequence.new(1, 0.05)
	trail.Lifetime = life
	trail.LightInfluence = 0
	trail.LightEmission = 0.25
	trail.FaceCamera = false
	trail.MinLength = 0
	trail.Parent = carrier
end

-- Returns { Step(position), Stop() }. Step every frame with the ball's position; Stop at the hit (the streak fades out).
function HitHero.Roll(diameter: number, forward: Vector3, floorY: number, color: Color3?, strength: number, lucky: boolean, stretch: number?)
	if not Settings.Get("Vfx") then
		return { Step = function() end, Stop = function() end }
	end
	local look = palette(color, lucky)
	local roll = HERO.Roll
	local carrier = holder(Vector3.new(0, floorY, 0), 8)
	local life = roll.Life * (1 + strength * 0.5) * (stretch or 1) -- (stretch: a hero shot runs in slow motion)
	local width = diameter * roll.Width * (if lucky then 1.3 else 1)
	floorTrail(carrier, width, look.Ray, look.Deep, life, roll.OuterAlpha)
	floorTrail(carrier, width * 0.4, look.Core, look.Ray, life * 0.7, roll.InnerAlpha)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SQUARE
	sparks.Color = ColorSequence.new(look.Core, look.Deep)
	sparks.LightInfluence = 0
	sparks.LightEmission = 0.3
	sparks.Orientation = Enum.ParticleOrientation.VelocityParallel
	sparks.Squash = NumberSequence.new(-2.5)
	sparks.Size = NumberSequence.new(roll.SparkSize, 0)
	sparks.Lifetime = NumberRange.new(0.15, 0.3)
	sparks.Speed = NumberRange.new(6, 16)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Acceleration = Vector3.new(0, -40, 0)
	sparks.Rate = roll.SparkRate + roll.SparkRateGrow * strength
	sparks.Parent = carrier
	local stopped = false
	return {
		Step = function(position: Vector3)
			if not stopped then
				carrier.CFrame = CFrame.lookAt(Vector3.new(position.X, floorY + 0.09, position.Z), Vector3.new(position.X, floorY + 0.09, position.Z) + forward)
			end
		end,
		Stop = function()
			stopped = true
			sparks.Enabled = false
			for _, trail in carrier:GetChildren() do
				if trail:IsA("Trail") then
					trail.Enabled = false
				end
			end
			Debris:AddItem(carrier, life + 0.4)
		end,
	}
end

-- ===== The hit =====
-- A flat star of spikes facing the camera, parked in the rack: pins in front of it stand out against it
local function sunburst(position: Vector3, studs: number, look, big: boolean, stretch: number)
	local burst = HERO.Burst
	local hold, fade = burst.Hold * stretch, burst.Fade * stretch
	local p = holder(position, burst.Grow + hold + fade + 0.2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(studs, studs)
	gui.LightInfluence = 0
	gui.Brightness = burst.Brightness
	gui.MaxDistance = 400
	gui.ResetOnSpawn = false
	gui.Parent = p
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.Rotation = math.random() * 360
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = burst.From
	scale.Parent = root
	local labels = {}
	local beam = SlKit.Icon("hatch_beam")
	local function spike(angle: number, length: number, width: number, inner: number, color: Color3)
		local a = math.rad(angle)
		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.Image = beam
		label.ImageColor3 = color
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Size = UDim2.fromScale(width, length)
		label.Position = UDim2.fromScale(0.5 + math.sin(a) * (inner + length / 2), 0.5 - math.cos(a) * (inner + length / 2))
		label.Rotation = angle
		label.Parent = root
		table.insert(labels, label)
	end
	local count = if big then burst.RaysBig else burst.Rays
	for i = 1, count do
		-- long and short spikes in turn, none quite the same: drawn by hand, not by a compass
		local angle = (i - 1) * 360 / count + (math.random() - 0.5) * 8
		local long = i % 2 == 1
		spike(
			angle,
			(if long then 0.46 else 0.28) * (0.85 + math.random() * 0.3),
			if long then 0.1 else 0.075,
			0.02,
			if long then look.Deep else look.Ray
		)
	end
	for i = 1, math.floor(count / 2) do
		spike((i - 0.5) * 720 / count + (math.random() - 0.5) * 10, 0.2 + math.random() * 0.08, 0.06, 0.01, look.Core)
	end
	local core = Instance.new("ImageLabel")
	core.BackgroundTransparency = 1
	core.Image = Config.BallVfx.Images.Dot
	core.ImageColor3 = look.Core
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.5, 0.5)
	core.Parent = root
	table.insert(labels, core)

	tween(scale, burst.Grow, { Scale = 1 }, Enum.EasingStyle.Quint)
	tween(root, burst.Grow + hold + fade, { Rotation = root.Rotation + burst.Spin }, Enum.EasingStyle.Linear)
	tween(scale, fade, { Scale = 1.12 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, burst.Grow + hold)
	for _, label in labels do
		tween(label, fade, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, burst.Grow + hold)
	end
end

-- The one-frame takeover: a 4-point glint at the hit that is gone almost at once
local function glint(position: Vector3, studs: number, color: Color3)
	local p = holder(position, 0.4)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(studs * 0.5, studs * 0.5)
	gui.LightInfluence = 0
	gui.Brightness = HERO.Burst.Brightness
	gui.Parent = p
	local label = Instance.new("ImageLabel")
	label.BackgroundTransparency = 1
	label.Image = SlKit.Icon("hatch_star")
	label.ImageColor3 = color
	label.Size = UDim2.fromScale(1, 1)
	label.Rotation = math.random() * 40 - 20
	label.Parent = gui
	tween(gui, 0.06, { Size = UDim2.fromScale(studs, studs) }, Enum.EasingStyle.Quint)
	tween(label, HERO.GlintFade, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0.03)
end

local function emit(position: Vector3, count: number, life: number, stretch: number, setup: (ParticleEmitter) -> ())
	local p = holder(position, life * stretch + 0.4)
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Enabled = false
	setup(e)
	e.TimeScale = 1 / stretch
	e.Parent = p
	e:Emit(math.floor(count))
end

-- c: Hit, Center, Forward, FloorY, T (0..1 how strong), Lucky, Shown (rack pins falling), Color (the ball's, or nil),
-- Stretch (a hero shot: everything lasts this many times longer and the burst is the big one)
function HitHero.Impact(c)
	if not Settings.Get("Vfx") then
		return
	end
	local look = palette(c.Color, c.Lucky)
	local share = math.clamp(c.Shown / 40, 0, 1)
	local stretch = c.Stretch or 1
	local grand = c.Lucky or c.Stretch ~= nil
	local size = (HERO.BurstSize + HERO.BurstGrow * c.T) * (0.75 + 0.25 * share) * (if grand then HERO.LuckySize else 1)

	-- behind the first rows of pins, at about their height
	sunburst(c.Center + Vector3.new(0, HERO.BurstUp, 0), size, look, grand, stretch)
	glint(c.Hit + Vector3.new(0, 0.9, 0) + c.Forward * 0.6, size * HERO.GlintSize, look.Core)

	-- Long sparks: thin, straight, fast, flying up and out
	local sparks = HERO.Sparks
	emit(c.Hit + c.Forward * 2 + Vector3.new(0, 0.6, 0), (sparks.Count + sparks.Grow * c.T) * (if grand then 1.6 else 1), 0.6, stretch, function(e)
		e.Texture = SQUARE
		e.Color = ColorSequence.new(look.Core, look.Deep)
		e.LightInfluence = 0
		e.LightEmission = 0.3
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(-2.5)
		e.Size = NumberSequence.new(sparks.Size, 0)
		e.Lifetime = NumberRange.new(0.25, 0.5)
		e.Speed = NumberRange.new(sparks.Speed * 0.45, sparks.Speed)
		e.SpreadAngle = Vector2.new(55, 55)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -sparks.Gravity, 0)
		e.Drag = 2
	end)

	-- Chips off the pins: lit by the sun like the pins themselves, not glowing
	local chips = HERO.Chips
	emit(c.Center + Vector3.new(0, 1, 0), chips.Count + chips.PerPin * c.Shown, 1, stretch, function(e)
		e.Texture = SQUARE
		e.Color = ColorSequence.new(chips.Color)
		e.LightInfluence = 1
		e.LightEmission = 0
		e.Size = NumberSequence.new(chips.Size)
		e.Lifetime = NumberRange.new(0.4, 0.75)
		e.Speed = NumberRange.new(chips.Speed * 0.4, chips.Speed)
		e.SpreadAngle = Vector2.new(70, 70)
		e.EmissionDirection = Enum.NormalId.Top
		e.Acceleration = Vector3.new(0, -chips.Gravity, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-500, 500)
	end)

	-- Coins flung out of the pins
	local coins = HERO.Coins
	if c.Paid then
		emit(c.Center + Vector3.new(0, 1, 0), math.clamp(c.Shown * coins.PerPin, coins.Min, coins.Max) * (if grand then 2 else 1), 1.1, stretch, function(e)
			e.Texture = AssetSlots.Image("Coin")
			e.Color = ColorSequence.new(WHITE)
			e.LightInfluence = 0
			e.LightEmission = 0
			e.Size = NumberSequence.new(coins.Size)
			e.Lifetime = NumberRange.new(0.5, 0.9)
			e.Speed = NumberRange.new(coins.Speed * 0.5, coins.Speed)
			e.SpreadAngle = Vector2.new(60, 60)
			e.EmissionDirection = Enum.NormalId.Top
			e.Acceleration = Vector3.new(0, -coins.Gravity, 0)
			e.Rotation = NumberRange.new(-30, 30)
			e.RotSpeed = NumberRange.new(-200, 200)
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.75, 0),
				NumberSequenceKeypoint.new(1, 1),
			})
		end)
	end

	-- A burst of real light on the deck and the pins' fronts
	local lamp = holder(c.Hit + Vector3.new(0, HERO.Light.Up, 0) - c.Forward * HERO.Light.Back, HERO.Light.Time * stretch + 0.2)
	local light = Instance.new("PointLight")
	light.Color = look.Core
	light.Range = HERO.Light.Range
	light.Brightness = HERO.Light.Brightness * (if grand then 1.5 else 1)
	light.Shadows = false
	light.Parent = lamp
	tween(light, HERO.Light.Time * stretch, { Brightness = 0 }, Enum.EasingStyle.Quad)
end

return HitHero
