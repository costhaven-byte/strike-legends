-- The "juice": sounds, camera (follow, punch, shake), slow motion, sparks, shockwaves, fireworks,
-- flashing lane lights and the number pops that jump out of pins.
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Settings = require(ReplicatedStorage:WaitForChild("ThrowLab"):WaitForChild("ThrowSettings"))
local World = require(script.Parent.World)

local Juice = {}

-- 1 = normal speed. Drops during strike slow motion; anything that moves pins multiplies by it.
Juice.TimeScale = 1

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

---------------------------------------------------------------------------
-- Sounds
---------------------------------------------------------------------------
local soundFolder = Instance.new("Folder")
soundFolder.Name = "ThrowLabSounds"
soundFolder.Parent = SoundService

local templates: { [string]: Sound } = {}
for name, info in Settings.Sounds do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. info.Id
	sound.Volume = info.Volume
	sound.Parent = soundFolder
	templates[name] = sound
end
task.spawn(function()
	ContentProvider:PreloadAsync(soundFolder:GetChildren())
end)

function Juice.Sound(name: string, pitch: number?, volumeScale: number?): Sound?
	local template = templates[name]
	if not template then
		return nil
	end
	local sound = template:Clone()
	sound.PlaybackSpeed = pitch or 1
	sound.Volume = template.Volume * (volumeScale or 1)
	sound.Parent = soundFolder
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	return sound
end

-- Pin hit sounds can come 10 at once; space them out a tiny bit so they don't turn into one blob.
local lastPinSound = 0
function Juice.PinHitSound(strength: number)
	local now = os.clock()
	if now - lastPinSound < 0.035 then
		return
	end
	lastPinSound = now
	Juice.Sound(
		"PinHit",
		(0.9 + math.random() * 0.35) * (Juice.TimeScale < 1 and 0.75 or 1),
		math.clamp(0.6 + strength * 0.4, 0.5, 1.4)
	)
end

---------------------------------------------------------------------------
-- Camera
---------------------------------------------------------------------------
local camera = workspace.CurrentCamera
local BASE_POSITION = Vector3.new(0, 7, 13)
local LOOK_AT = Vector3.new(0, 0.5, -30)

local followZ, followTarget = 0, 0
local punch = 0
local shakeLeft, shakeTotal, shakeStrength = 0, 0, 0
local shakeClock = 0
local slowZoom = 0

-- How far the ball has rolled; the camera follows part of the way.
function Juice.Follow(distance: number)
	followTarget = -distance * Settings.CameraFollow
end

function Juice.Punch(amount: number)
	punch = math.max(punch, amount)
end

function Juice.Shake(strength: number, time: number)
	if strength <= 0 or time <= 0 then
		return
	end
	if strength >= shakeStrength * (shakeLeft / math.max(shakeTotal, 0.001)) then
		shakeStrength, shakeLeft, shakeTotal = strength, time, time
	end
end

function Juice.UpdateCamera(dt: number)
	camera.CameraType = Enum.CameraType.Scriptable
	followZ += (followTarget - followZ) * math.min(1, dt * 9)
	punch -= punch * math.min(1, dt * 14)

	local position = BASE_POSITION + Vector3.new(0, 0, followZ)
	local cf = CFrame.lookAt(position, LOOK_AT + Vector3.new(0, 0, followZ * 0.3)) * CFrame.new(0, 0, -punch)

	if shakeLeft > 0 then
		shakeLeft -= dt
		shakeClock += dt
		local s = shakeStrength * math.max(0, shakeLeft / shakeTotal)
		local x = math.noise(shakeClock * 32, 0.5) * s * 1.6
		local y = math.noise(shakeClock * 32, 10.5) * s * 1.6
		local roll = math.noise(shakeClock * 26, 20.5) * s * 5
		cf *= CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(roll))
	end

	camera.CFrame = cf
	camera.FieldOfView = 70 - punch * 2.5 - slowZoom
end

---------------------------------------------------------------------------
-- Slow motion (strikes). Roblox can't slow down time, so we fake it:
-- pins are slowed, gravity is weakened to match, then everything is sped back up.
---------------------------------------------------------------------------
local slowRun = 0

local function scaleRoots(roots: { BasePart }, factor: number)
	for _, root in roots do
		if root.Parent and not root.Anchored then
			root.AssemblyLinearVelocity *= factor
			root.AssemblyAngularVelocity *= factor
		end
	end
end

function Juice.SetGravity()
	workspace.Gravity = Settings.PinGravity * Juice.TimeScale * Juice.TimeScale
end

function Juice.EndSlowMotion(getRoots: () -> { BasePart })
	slowRun += 1
	if Juice.TimeScale >= 1 then
		return
	end
	scaleRoots(getRoots(), 1 / Juice.TimeScale)
	Juice.TimeScale = 1
	Juice.SetGravity()
	TweenService:Create(World.ColorCorrection, TweenInfo.new(0.15), { Contrast = 0.1, TintColor = Color3.new(1, 1, 1) })
		:Play()
	slowZoom = 0
end

function Juice.SlowMotion(length: number, speed: number, getRoots: () -> { BasePart })
	if length <= 0 or speed >= 1 then
		return
	end
	speed = math.max(speed, 0.05)
	if Juice.TimeScale < 1 then
		Juice.EndSlowMotion(getRoots)
	end
	slowRun += 1
	local run = slowRun
	scaleRoots(getRoots(), speed)
	Juice.TimeScale = speed
	Juice.SetGravity()
	slowZoom = 9
	TweenService
		:Create(
			World.ColorCorrection,
			TweenInfo.new(0.08),
			{ Contrast = 0.3, TintColor = Color3.fromRGB(255, 235, 245) }
		)
		:Play()
	task.delay(length, function()
		if run == slowRun then
			Juice.EndSlowMotion(getRoots)
		end
	end)
end

---------------------------------------------------------------------------
-- Sparks, shockwaves, fireworks
---------------------------------------------------------------------------
local function holder(position: Vector3, life: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = position
	p.Parent = World.Folder
	Debris:AddItem(p, life)
	return p
end

-- A one-shot burst of glowing sparks
function Juice.Burst(
	position: Vector3,
	color: Color3 | ColorSequence,
	count: number,
	speed: number,
	size: number,
	life: number?
)
	local p = holder(position, 3)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = typeof(color) == "Color3" and ColorSequence.new(color) or color
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new((life or 0.4) * 0.6, life or 0.4)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.TimeScale = Juice.TimeScale
	e.Parent = p
	e:Emit(math.floor(count))
end

-- A flat glowing ring that rushes outward along the floor
function Juice.Shockwave(position: Vector3, color: Color3, radius: number, time: number?)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.12, 1, 1)
	ring.CFrame = CFrame.new(position) * UPRIGHT
	ring.Parent = World.Folder
	local t = time or 0.3
	TweenService:Create(ring, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.12, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, t + 0.05)
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 43, 214)),
	ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 200, 40)),
	ColorSequenceKeypoint.new(0.66, Color3.fromRGB(70, 230, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 255, 90)),
})

-- Confetti-style rain of colourful sparks over the pin deck
function Juice.Confetti(amount: number)
	local p = holder(Vector3.new(0, 12, World.HeadPinZ - 2), 4)
	p.Size = Vector3.new(12, 0.2, 8)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = RAINBOW
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(0.5, 0.2)
	e.Lifetime = NumberRange.new(1, 1.6)
	e.Speed = NumberRange.new(4, 12)
	e.SpreadAngle = Vector2.new(60, 60)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Acceleration = Vector3.new(0, -12, 0)
	e.RotSpeed = NumberRange.new(-300, 300)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = 0
	e.Parent = p
	e:Emit(math.floor(amount))
end

function Juice.Firework(position: Vector3, scale: number)
	Juice.Burst(position, RAINBOW, 70 * scale, 38 * scale, 0.9 * scale, 1.1)
	Juice.Burst(position, Color3.new(1, 1, 1), 20 * scale, 12, 1.6 * scale, 0.25)
	Juice.Sound("Firework", 0.9 + math.random() * 0.3, scale)
end

-- Makes the neon strips flash through colours, then puts them back
local lightRun = 0
function Juice.FlashLights(time: number)
	lightRun += 1
	local run = lightRun
	local colors = {
		Color3.fromRGB(255, 200, 40),
		Color3.new(1, 1, 1),
		Color3.fromRGB(70, 230, 255),
		Color3.fromRGB(255, 43, 214),
	}
	task.spawn(function()
		local step = 0
		local started = os.clock()
		while os.clock() - started < time and run == lightRun do
			step += 1
			for i, light in World.Lights do
				light.part.Color = colors[(step + i) % #colors + 1]
			end
			task.wait(0.06)
		end
		if run == lightRun then
			for _, light in World.Lights do
				light.part.Color = light.color
			end
		end
	end)
end

---------------------------------------------------------------------------
-- Number pops (the numbers that jump out of each pin)
---------------------------------------------------------------------------
function Juice.NumberPop(position: Vector3, value: number, size: number, color: Color3)
	local anchor = holder(position, Settings.NumberPopTime + 0.2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 120)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 500
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = tostring(value)
	label.TextSize = math.floor(size)
	label.TextColor3 = color
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = math.max(2, size / 12)
	stroke.Color = Color3.fromRGB(40, 10, 60)
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = label

	local t = Settings.NumberPopTime
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.15 })
		:Play()
	TweenService:Create(gui, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new((math.random() - 0.5) * 3, 5, 0),
	}):Play()
	task.delay(t * 0.55, function()
		local fade = TweenInfo.new(t * 0.45)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		TweenService:Create(scale, fade, { Scale = 0.8 }):Play()
	end)
end

return Juice
