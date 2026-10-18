-- The Throw Lab's "juice" for the alley: spark bursts, shockwave rings, number pops, pin hit sounds,
-- and the camera punch, shake and slow-motion tint on your own throws. Numbers live in Config.Throw.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(script.Parent.Sfx)

local THROW = Config.Throw
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local ThrowFx = {}

local folder = Instance.new("Folder")
folder.Name = "ThrowFx"
folder.Parent = Workspace

local function holder(position: Vector3, life: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Position = position
	p.Parent = folder
	Debris:AddItem(p, life)
	return p
end

-- A one-shot burst of glowing sparks. timeScale slows it down during slow motion.
function ThrowFx.Burst(position: Vector3, color: Color3, count: number, speed: number, size: number, timeScale: number?)
	local p = holder(position, 3)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Color = ColorSequence.new(color)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.24, 0.4)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 4
	e.Rate = 0
	e.TimeScale = timeScale or 1
	e.Parent = p
	e:Emit(math.floor(count))
end

-- A flat glowing ring that rushes outward along the floor
function ThrowFx.Shockwave(position: Vector3, color: Color3, radius: number, time: number?)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.12, 1, 1)
	ring.CFrame = CFrame.new(position) * UPRIGHT
	ring.Parent = folder
	local t = time or 0.3
	TweenService:Create(ring, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.12, radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, t + 0.05)
end

-- A number that jumps out of a pin
function ThrowFx.NumberPop(position: Vector3, text: string, size: number, color: Color3)
	local anchor = holder(position, THROW.NumberPopTime + 0.2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 120)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
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

	local t = THROW.NumberPopTime
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

local function formatNumber(n: number): string
	n = math.floor(n + 0.5)
	if n >= 1e9 then
		return ("%.2fB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.2fM"):format(n / 1e6)
	end
	local text = tostring(n)
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end

-- The big total payout that slams in over the pins: "+12,500" with the multiplier under it ("x25 BALL").
-- Bigger for bigger payouts, so stronger balls look as strong as they pay.
function ThrowFx.PayoutPop(position: Vector3, coins: number, note: string?, color: Color3)
	local size = THROW.PayoutPopSize + THROW.PayoutPopGrowth * math.log10(math.max(coins, 1))
	local time = THROW.PayoutPopTime
	local anchor = holder(position, time + 0.2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(600, size * 2.4)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 300
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.Parent = anchor

	local function line(text: string, textSize: number, y: number, lineColor: Color3): (TextLabel, UIStroke)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.fromScale(0.5, y)
		label.Size = UDim2.new(1, 0, 0, textSize * 1.2)
		label.Font = Enum.Font.FredokaOne
		label.Text = text
		label.TextSize = math.floor(textSize)
		label.TextColor3 = lineColor
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = math.max(3, textSize / 10)
		stroke.Color = Color3.fromRGB(40, 10, 60)
		stroke.Parent = label
		return label, stroke
	end
	local labels = {}
	local main, mainStroke = line("+" .. formatNumber(coins), size, 0, color)
	table.insert(labels, { main, mainStroke })
	if note then
		local sub, subStroke = line(note, size * 0.45, 0.55, Color3.new(1, 1, 1))
		table.insert(labels, { sub, subStroke })
	end
	-- Slams in from huge
	for _, pair in labels do
		local slam = Instance.new("UIScale")
		slam.Scale = 2.2
		slam.Parent = pair[1]
		TweenService:Create(slam, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
	TweenService:Create(gui, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 6, 0),
	}):Play()
	task.delay(time * 0.6, function()
		local fade = TweenInfo.new(time * 0.4)
		for _, pair in labels do
			TweenService:Create(pair[1], fade, { TextTransparency = 1 }):Play()
			TweenService:Create(pair[2], fade, { Transparency = 1 }):Play()
		end
	end)
end

-- Pin hits can come 10 at once; space them out a tiny bit so they don't turn into one blob
local lastPinSound = 0
function ThrowFx.PinHitSound(at: Instance, force: number, slow: boolean)
	local now = os.clock()
	if now - lastPinSound < 0.035 then
		return
	end
	lastPinSound = now
	Sfx.PlayAt(
		"PinHit",
		at,
		(0.9 + math.random() * 0.35) * (if slow then 0.75 else 1),
		math.clamp(0.6 + force * 0.4, 0.5, 1.4)
	)
end

---------------------------------------------------------------------------
-- Camera punch (a jolt toward the pins), shake, and the slow-motion zoom and tint
---------------------------------------------------------------------------
local punch = 0
local shakeLeft, shakeTotal, shakeStrength = 0, 0, 0
local shakeClock = 0
local slowZoom = 0

local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "ThrowSlowMo"
tint.Parent = Lighting

function ThrowFx.Punch(amount: number)
	punch = math.max(punch, amount)
end

function ThrowFx.Shake(strength: number, time: number)
	if strength <= 0 or time <= 0 then
		return
	end
	if strength >= shakeStrength * (shakeLeft / math.max(shakeTotal, 0.001)) then
		shakeStrength, shakeLeft, shakeTotal = strength, time, time
	end
end

-- Multiply onto the camera CFrame every frame
function ThrowFx.CameraOffset(dt: number): CFrame
	punch -= punch * math.min(1, dt * 14)
	local cf = CFrame.new(0, 0, -punch)
	if shakeLeft > 0 then
		shakeLeft -= dt
		shakeClock += dt
		local s = shakeStrength * math.max(0, shakeLeft / shakeTotal)
		local x = math.noise(shakeClock * 32, 0.5) * s * 1.6
		local y = math.noise(shakeClock * 32, 10.5) * s * 1.6
		local roll = math.noise(shakeClock * 26, 20.5) * s * 5
		cf *= CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(roll))
	end
	return cf
end

-- Degrees to take off the normal field of view (punch and slow motion zoom in)
function ThrowFx.FovOffset(): number
	return punch * 2.5 + slowZoom
end

function ThrowFx.SlowMoLook(on: boolean)
	slowZoom = if on then 9 else 0
	TweenService:Create(tint, TweenInfo.new(if on then 0.08 else 0.15), {
		Contrast = if on then 0.2 else 0,
		TintColor = if on then Color3.fromRGB(255, 235, 245) else Color3.new(1, 1, 1),
	}):Play()
end

return ThrowFx
