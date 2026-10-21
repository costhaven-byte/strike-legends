-- The Throw Lab's "juice" for the alley: spark bursts, shockwave rings, number and payout pops, pin hit sounds,
-- and the camera punch, shake and slow-motion tint on your own throws. Numbers live in Config.Throw.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(script.Parent.Sfx)
local SlUi = require(script.Parent.SlUi)
local UiFx = require(script.Parent.UiFx)

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

-- The owner's "Floating numbers" design (UI 1.4 B): a number that jumps out of a pin, punches to 120%,
-- rises 130 px and fades by the end of NumberPopTime. No plate, the thick outline does the work.
-- tone = "white", "gold" or "pink"; tag = an optional small label above it ("BONUS")
local TONES = {
	white = { Color = SlUi.Colors.White, Glow = Color3.fromRGB(140, 230, 255), Tag = SlUi.Hex("35E8FF") },
	gold = { Color = SlUi.Colors.Gold, Glow = Color3.fromRGB(255, 186, 40), Tag = SlUi.Colors.Gold },
	pink = { Color = SlUi.Colors.Pink, Glow = Color3.fromRGB(255, 60, 170), Tag = SlUi.Colors.Pink },
}
function ThrowFx.NumberPop(position: Vector3, value: number, size: number, tone: string, tag: string?)
	local look = TONES[tone] or TONES.white
	local t = THROW.NumberPopTime
	local anchor = holder(position, t + 0.2)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size * 6, size * 2.4 + 140)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	gui.StudsOffset = Vector3.new(0, 1.5, 0)
	gui.Parent = anchor

	local group = Instance.new("CanvasGroup")
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(0.5, 1)
	group.Position = UDim2.fromScale(0.5, 1)
	group.Size = UDim2.fromOffset(size * 6, size * 2.4)
	group.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.5
	scale.Parent = group
	local wrap = Instance.new("Frame")
	wrap.BackgroundTransparency = 1
	wrap.AnchorPoint = Vector2.new(0.5, 1)
	wrap.Position = UDim2.fromScale(0.5, 1)
	wrap.Size = UDim2.new(1, 0, 0, size * 1.3)
	wrap.Parent = group
	local stroke = size * 0.11
	SlUi.Layered(wrap, "+" .. SlUi.Format(value), SlUi.Round, size, {
		{ Color = look.Glow, Width = stroke * 2.4, Stroke = look.Glow, Transparency = 0.6, StrokeTransparency = 0.7 },
		{ Color = SlUi.Colors.Ink, Width = stroke, Offset = Vector2.new(0, size * 0.07) },
		{ Color = look.Color, Width = stroke, Stroke = SlUi.Colors.Ink },
	})
	if tag then
		local pill = SlUi.Label(group, tag, SlUi.Heavy, math.max(11, size * 0.3), look.Tag)
		pill.AnchorPoint = Vector2.new(0.5, 1)
		pill.Position = UDim2.new(0.5, 0, 1, -size * 1.3)
		pill.Size = UDim2.fromOffset(0, size * 0.45)
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.BackgroundColor3 = SlUi.Colors.Ink
		pill.BackgroundTransparency = 0
		SlUi.Corner(pill)
		SlUi.Stroke(pill, look.Tag, 2, 0, true)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, size * 0.2)
		pad.PaddingRight = UDim.new(0, size * 0.2)
		pad.Parent = pill
	end

	-- Punch to 120% (first 10%), settle, rise 130 px; fades over the last third
	TweenService:Create(scale, TweenInfo.new(t * 0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.2 })
		:Play()
	task.delay(t * 0.1, function()
		TweenService:Create(scale, TweenInfo.new(t * 0.115), { Scale = 1 }):Play()
	end)
	TweenService:Create(group, TweenInfo.new(t, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, (math.random() - 0.5) * 40, 1, -130),
	}):Play()
	task.delay(t * 0.64, function()
		local fade = TweenInfo.new(t * 0.36)
		TweenService:Create(group, fade, { GroupTransparency = 1 }):Play()
		TweenService:Create(scale, fade, { Scale = 0.95 }):Play()
	end)
end

-- The owner's "Payout pop" design (UI 1.4 A): a gold coin and a pill with the total ("+480 COINS"),
-- anchored to the screen above the lane. Spawn, burst (90 ms), overshoot (180 ms), idle, exit up and out.
-- variant = "coin" (cyan), "bonus" (gold, strikes) or "streak" (pink, strike streaks); tag = the small chip
local VARIANTS = {
	coin = { Color = SlUi.Hex("35E8FF"), Number = SlUi.Colors.White },
	bonus = { Color = SlUi.Colors.Gold, Number = SlUi.Colors.Gold },
	streak = { Color = SlUi.Colors.Pink, Number = SlUi.Colors.Pink },
}
local payoutRow: Frame? = nil
function ThrowFx.PayoutPop(coins: number, variant: string, tag: string?)
	local look = VARIANTS[variant] or VARIANTS.coin
	local ink = SlUi.Colors.Ink
	local time = THROW.PayoutPopTime
	if payoutRow then
		payoutRow:Destroy() -- the newest payout replaces the last one
	end

	local row = Instance.new("Frame")
	row.Name = "PayoutPop"
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = THROW.PayoutPopPosition
	row.Size = UDim2.fromOffset(0, 76)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.BackgroundTransparency = 1
	payoutRow = row
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = row
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, -26) -- the pill tucks under the coin
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row

	-- The coin, with the burst ring and 8 spikes behind it
	local coinSpot = Instance.new("Frame")
	coinSpot.Size = UDim2.fromOffset(76, 76)
	coinSpot.BackgroundTransparency = 1
	coinSpot.LayoutOrder = 1
	coinSpot.ZIndex = 3
	coinSpot.Parent = row
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(130, 130)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 1
	ring.Parent = coinSpot
	SlUi.Corner(ring)
	local ringStroke = SlUi.Stroke(ring, look.Color, 16, 0, true)
	local ringScale = Instance.new("UIScale")
	ringScale.Scale = 0.35
	ringScale.Parent = ring
	local spikes = Instance.new("Frame")
	spikes.AnchorPoint = Vector2.new(0.5, 0.5)
	spikes.Position = UDim2.fromScale(0.5, 0.5)
	spikes.Size = UDim2.fromOffset(0, 0)
	spikes.BackgroundTransparency = 1
	spikes.ZIndex = 1
	spikes.Parent = coinSpot
	local spikeScale = Instance.new("UIScale")
	spikeScale.Scale = 0.5
	spikeScale.Parent = spikes
	local spikeParts = {}
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local spike = Instance.new("Frame")
		spike.AnchorPoint = Vector2.new(0.5, 0.5)
		spike.Position = UDim2.fromOffset(math.sin(angle) * 62, -math.cos(angle) * 62)
		spike.Size = UDim2.fromOffset(8, if i % 2 == 0 then 22 else 14)
		spike.Rotation = i * 45
		spike.BackgroundColor3 = look.Color
		spike.ZIndex = 1
		spike.Parent = spikes
		SlUi.Corner(spike, UDim.new(0, 4))
		table.insert(spikeParts, { spike, SlUi.Stroke(spike, ink, 2, 0, true) })
	end
	local coin = Instance.new("Frame")
	coin.Size = UDim2.fromOffset(76, 76)
	coin.BackgroundColor3 = Color3.new(1, 1, 1)
	coin.ZIndex = 4
	coin.Parent = coinSpot
	SlUi.Corner(coin)
	SlUi.Stroke(coin, ink, 4, 0, true)
	SlUi.Gradient(coin, { { 0, SlUi.Hex("FFF2A8") }, { 0.45, SlUi.Colors.Gold }, { 1, SlUi.Hex("EE9410") } }, 60)
	local face = Instance.new("Frame")
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromOffset(46, 46)
	face.BackgroundTransparency = 1
	face.ZIndex = 5
	face.Parent = coin
	SlUi.Corner(face)
	SlUi.Stroke(face, SlUi.Hex("C46F00"), 3, 0, true)
	local letter = SlUi.Label(face, "S", SlUi.Round, 28, SlUi.Hex("A85A00"))
	letter.ZIndex = 6

	-- The pill: the amount, then the tag chip over "COINS"
	local pill = Instance.new("Frame")
	pill.Size = UDim2.fromOffset(0, 62)
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.LayoutOrder = 2
	pill.ZIndex = 2
	pill.Parent = row
	SlUi.Corner(pill)
	SlUi.Stroke(pill, look.Color, 4, 0, true)
	SlUi.Gradient(pill, { { 0, SlUi.Hex("151B4C") }, { 1, SlUi.Hex("080B26") } })
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 38)
	pad.PaddingRight = UDim.new(0, 24)
	pad.Parent = pill
	local inside = Instance.new("UIListLayout")
	inside.FillDirection = Enum.FillDirection.Horizontal
	inside.VerticalAlignment = Enum.VerticalAlignment.Center
	inside.Padding = UDim.new(0, 10)
	inside.SortOrder = Enum.SortOrder.LayoutOrder
	inside.Parent = pill
	local amount = SlUi.Label(pill, "+" .. SlUi.Format(coins), SlUi.Round, 42, look.Number)
	amount.AnchorPoint = Vector2.zero
	amount.Size = UDim2.fromOffset(0, 50)
	amount.AutomaticSize = Enum.AutomaticSize.X
	amount.LayoutOrder = 1
	amount.ZIndex = 3
	SlUi.Stroke(amount, ink, 4.5)
	local side = Instance.new("Frame")
	side.Size = UDim2.fromOffset(0, 40)
	side.AutomaticSize = Enum.AutomaticSize.X
	side.BackgroundTransparency = 1
	side.LayoutOrder = 2
	side.ZIndex = 3
	side.Parent = pill
	local stack = Instance.new("UIListLayout")
	stack.VerticalAlignment = Enum.VerticalAlignment.Center
	stack.Padding = UDim.new(0, 3)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = side
	if tag then
		local chip = SlUi.Label(side, tag, SlUi.Heavy, 13, ink)
		chip.AnchorPoint = Vector2.zero
		chip.Size = UDim2.fromOffset(0, 18)
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.BackgroundColor3 = look.Color
		chip.BackgroundTransparency = 0
		chip.LayoutOrder = 1
		chip.ZIndex = 4
		SlUi.Corner(chip)
		local chipPad = Instance.new("UIPadding")
		chipPad.PaddingLeft = UDim.new(0, 7)
		chipPad.PaddingRight = UDim.new(0, 7)
		chipPad.Parent = chip
	end
	local word = SlUi.Label(side, "COINS", SlUi.Heavy, 15, look.Color)
	word.AnchorPoint = Vector2.zero
	word.Size = UDim2.fromOffset(0, 16)
	word.AutomaticSize = Enum.AutomaticSize.X
	word.TextXAlignment = Enum.TextXAlignment.Left
	word.LayoutOrder = 2
	word.ZIndex = 4

	local screen = math.clamp(Workspace.CurrentCamera.ViewportSize.Y / 720, 0.6, 1)
	row.Parent = UiFx.Layer()

	-- Spawn -> burst (90 ms) -> overshoot (180 ms, 114%, tipped 2 degrees) -> idle (300 ms)
	TweenService:Create(scale, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 0.92 * screen,
	}):Play()
	task.delay(0.09, function()
		TweenService:Create(scale, TweenInfo.new(0.09, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.14 * screen,
		}):Play()
		TweenService:Create(row, TweenInfo.new(0.09), { Rotation = 2 }):Play()
	end)
	task.delay(0.18, function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = screen,
		}):Play()
		TweenService:Create(row, TweenInfo.new(0.12), { Rotation = 0 }):Play()
	end)
	local burst = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(ringScale, burst, { Scale = 1.6 }):Play()
	TweenService:Create(ringStroke, burst, { Thickness = 2, Transparency = 1 }):Play()
	TweenService:Create(spikeScale, burst, { Scale = 1.4 }):Play()
	for _, pair in spikeParts do
		TweenService:Create(pair[1], burst, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(pair[2], burst, { Transparency = 1 }):Play()
	end
	-- Exit: up 26 px, shrink to 90%, fade (the last 300 ms)
	task.delay(time - 0.3, function()
		if payoutRow ~= row then
			return
		end
		local out = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(row, out, { Position = row.Position + UDim2.fromOffset(0, -26) }):Play()
		TweenService:Create(scale, out, { Scale = 0.9 * screen }):Play()
		for _, object in row:GetDescendants() do
			if object:IsA("TextLabel") then
				TweenService:Create(object, out, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			elseif object:IsA("Frame") and object.BackgroundTransparency < 1 then
				TweenService:Create(object, out, { BackgroundTransparency = 1 }):Play()
			elseif object:IsA("UIStroke") then
				TweenService:Create(object, out, { Transparency = 1 }):Play()
			end
		end
		task.wait(0.32)
		row:Destroy()
		if payoutRow == row then
			payoutRow = nil
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
