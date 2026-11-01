-- Ball trait trigger effects, built from the owner's "Trait Effects" handoff sheet:
-- Curve (glowing hook ribbon), Blast (flash + two shockwave rings), Streak Saver (shield bubble on the
-- HUD streak counter), Lucky (clover over the rack), Gem Hunter (diamond sparkle trail + gem payout)
-- and Heavy (lane cracks, dust, camera shake), each with its popup text. Numbers live in Config.TraitFx.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local SunKit = require(script.Parent:WaitForChild("SunKit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local CameraShake = require(script.Parent.CameraShake)
local Sfx = require(script.Parent.Sfx)
local UiFx = require(script.Parent.UiFx)

local FX = Config.TraitFx
local LANE = Config.Lane
local IMAGES = Config.BallVfx.Images
local FONT = SunKit.Swap(Font.new("rbxasset://fonts/families/LuckiestGuy.json"))
local WHITE = Color3.new(1, 1, 1)

local player = Players.LocalPlayer

local TraitFx = {}

-- The design system's two curves: ease-pop overshoots, ease-snap is a fast settle
local function pop(time: number): TweenInfo
	return TweenInfo.new(time, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end
local function snap(time: number): TweenInfo
	return TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
end

local function tween(object: Instance, info: TweenInfo, goals: { [string]: any }): Tween
	local t = TweenService:Create(object, info, goals)
	t:Play()
	return t
end

local function between(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

-- Screen size is measured against a 1080p screen
local function screenScale(): number
	return Workspace.CurrentCamera.ViewportSize.Y / 1080
end

-- Where a world point is in overlay coordinates
local function toScreen(position: Vector3): Vector2
	local point = Workspace.CurrentCamera:WorldToViewportPoint(position)
	return Vector2.new(point.X, point.Y) - GuiService:GetGuiInset()
end

-- An invisible anchored part to hang effects on; removed after `life` seconds
local function fxPart(cframe: CFrame, size: Vector3, life: number?): Part
	local part = Instance.new("Part")
	part.Name = "TraitFx"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = cframe
	part.Parent = Workspace
	if life then
		task.delay(life, part.Destroy, part)
	end
	return part
end

-- A spot flat on the lane surface under `position`, facing down the lane (X = across the lane)
local function laneFloor(lane: Model, position: Vector3): CFrame
	local pinSpot = lane:FindFirstChild("PinSpot") :: BasePart
	local forward = (lane:FindFirstChild("BallStart") :: BasePart).CFrame.LookVector
	local at = Vector3.new(position.X, pinSpot.Position.Y - pinSpot.Size.Y / 2 + FX.FloorLift, position.Z)
	return CFrame.lookAt(at, at + Vector3.new(forward.X, 0, forward.Z))
end

-- A point on the rack: `depth` studs behind the head pin, `up` studs above the lane
local function rackPoint(lane: Model, depth: number, up: number): Vector3
	local pinSpot = lane:FindFirstChild("PinSpot") :: BasePart
	return (laneFloor(lane, pinSpot.Position) * CFrame.new(0, up, -depth)).Position
end

local RACK_DEPTH = LANE.PinSpacing * math.sqrt(3) / 2 * 1.5 -- head pin to the middle of the rack

-- A flat see-through square on the lane with a SurfaceGui on top to draw on
local function flatCanvas(cframe: CFrame, studs: number, life: number): SurfaceGui
	local part = fxPart(cframe, Vector3.new(studs, 0.05, studs), life)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = FX.PixelsPerStud
	gui.LightInfluence = 0
	gui.Brightness = FX.Brightness
	gui.Parent = part
	return gui
end

-- A soft round glow sprite facing the camera, `studs` wide
local function glowSprite(
	parent: BasePart,
	color: Color3,
	studs: number,
	transparency: number?
): (BillboardGui, ImageLabel)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(studs, studs)
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = parent
	local image = Instance.new("ImageLabel")
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = IMAGES.Dot
	image.ImageColor3 = color
	image.ImageTransparency = transparency or 0
	image.Parent = gui
	return gui, image
end

-- White impact flash: a quick glow plus a burst of light
local function flash(position: Vector3, studs: number, time: number)
	local part = fxPart(CFrame.new(position), Vector3.one * 0.2, time * 3)
	local gui, image = glowSprite(part, WHITE, studs * 0.2)
	tween(gui, snap(time), { Size = UDim2.fromScale(studs * 1.3, studs * 1.3) })
	tween(image, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { ImageTransparency = 1 })
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 5
	light.Parent = part
	tween(light, TweenInfo.new(time * 2), { Brightness = 0 })
	return part
end

local function playSound(traitId: string, at: Instance?)
	local trait = Balls.GetTrait(traitId)
	if not trait or not trait.Sound then
		return
	elseif at then
		Sfx.PlayAt(trait.Sound, at, trait.Pitch)
	else
		Sfx.Play(trait.Sound, trait.Pitch)
	end
end

-- Popup text ------------------------------------------------------------------------------------

local active = {} -- popups on screen; each takes the lowest free stacking slot

local function freeSlot(): number
	local used = {}
	for _, entry in active do
		used[entry.Slot] = true
	end
	local slot = 0
	while used[slot] do
		slot += 1
	end
	return slot
end

-- Popup text centred over an event. target: a world position, or a function giving an overlay point.
function TraitFx.Popup(text: string, color: Color3, target: Vector3 | () -> Vector2)
	local P = FX.Popup
	local layer = UiFx.Layer()
	local scale = screenScale()
	local textSize = math.max(P.MinTextSize, math.floor(P.TextSize * scale + 0.5))

	local holder = Instance.new("Frame")
	holder.Name = "TraitPopup"
	holder.AnchorPoint = Vector2.new(0.5, 1) -- sits on top of the point it's over
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(math.floor(textSize * 0.72 * #text + 24), textSize + 8)
	holder.ZIndex = 20

	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.BackgroundTransparency = 1
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromScale(1.15, 2.4)
	glow.Image = IMAGES.Dot
	glow.ImageColor3 = color
	glow.ImageTransparency = P.GlowTransparency
	glow.ZIndex = 20
	glow.Parent = holder

	local labels, strokes = {}, {}
	for _, layerInfo in { { P.Shadow * scale, FX.Ink, 21 }, { 0, color, 22 } } do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Position = UDim2.fromOffset(0, layerInfo[1])
		label.FontFace = FONT
		label.TextSize = textSize
		label.Text = text
		label.TextColor3 = layerInfo[2]
		label.ZIndex = layerInfo[3]
		label.Parent = holder
		local stroke = Instance.new("UIStroke")
		stroke.Color = FX.Ink
		stroke.Thickness = math.max(1.5, 2 * scale)
		stroke.Parent = label
		table.insert(labels, label)
		table.insert(strokes, stroke)
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = P.PopFrom
	uiScale.Parent = holder

	local entry = { Slot = freeSlot(), Rise = 0 }
	table.insert(active, entry)

	local function place()
		local point = if typeof(target) == "Vector3" then toScreen(target) else (target :: () -> Vector2)()
		local screen = Workspace.CurrentCamera.ViewportSize - GuiService:GetGuiInset()
		local half = holder.AbsoluteSize.X / 2
		local x = math.min(math.max(point.X, P.Margin + half), screen.X - P.Margin - half)
		-- keep it on screen first, then stack, so popups pushed in from an edge still sit apart
		local stack = entry.Slot * P.StackGap * scale
		local y =
			math.min(math.max(point.Y, P.Margin + holder.AbsoluteSize.Y + stack), screen.Y - P.BottomMargin * scale)
		holder.Position = UDim2.fromOffset(x, y - stack - entry.Rise * scale)
	end
	place()
	holder.Parent = layer
	local connection = RunService.RenderStepped:Connect(place)

	tween(uiScale, pop(P.PopTime), { Scale = 1 })
	task.delay(P.PopTime + P.HoldTime, function()
		local exit = snap(P.ExitTime)
		local rise = Instance.new("NumberValue")
		rise.Changed:Connect(function(value)
			entry.Rise = value
		end)
		tween(rise, exit, { Value = P.Rise })
		for _, label in labels do
			tween(label, exit, { TextTransparency = 1 })
		end
		for _, stroke in strokes do
			tween(stroke, exit, { Transparency = 1 })
		end
		tween(glow, exit, { ImageTransparency = 1 })
		task.wait(P.ExitTime)
		connection:Disconnect()
		holder:Destroy()
		rise:Destroy()
		table.remove(active, table.find(active, entry))
	end)
end

-- The trait's own popup text and colour; `...` fills its text (e.g. the gem amount)
local function traitPopup(traitId: string, target: Vector3 | () -> Vector2, ...)
	local trait = Balls.GetTrait(traitId)
	if trait then
		TraitFx.Popup(trait.Popup:format(...), trait.PopupColor or trait.Color, target)
	end
end

-- Curve -----------------------------------------------------------------------------------------

-- A glowing ribbon flat on the lane behind the ball: white-hot core inside a magenta glow, tapering
-- to nothing at the tail. Call Move(ballPosition) every frame and Stop() when the ball reaches the pins.
function TraitFx.CurveTrail(lane: Model, laneLength: number)
	local C = FX.Curve
	local carrier = fxPart(CFrame.identity, Vector3.one * 0.2)

	local trails = {}
	local function ribbon(width: number, colors: ColorSequence, lift: number)
		local left = Instance.new("Attachment")
		left.Position = Vector3.new(-width / 2, lift, 0)
		left.Parent = carrier
		local right = Instance.new("Attachment")
		right.Position = Vector3.new(width / 2, lift, 0)
		right.Parent = carrier
		local trail = Instance.new("Trail")
		trail.Attachment0 = left
		trail.Attachment1 = right
		trail.FaceCamera = false -- lies flat on the lane
		trail.Lifetime = C.Lifetime
		trail.MaxLength = laneLength * C.MaxLength
		trail.MinLength = 0.05
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Transparency = NumberSequence.new(0, 1)
		trail.Color = colors
		trail.LightEmission = 1
		trail.Brightness = C.Brightness
		trail.Parent = carrier
		table.insert(trails, trail)
	end
	ribbon(C.Width, ColorSequence.new(C.Glow, C.Tail), 0)
	ribbon(C.CoreWidth, ColorSequence.new(C.Core), 0.02)

	local handle = {}
	local stopped = false
	function handle.Move(position: Vector3)
		if not stopped then
			carrier.CFrame = laneFloor(lane, position)
		end
	end
	function handle.Stop()
		if stopped then
			return
		end
		stopped = true
		task.spawn(function()
			local start = os.clock()
			while carrier.Parent do
				local fade = math.min((os.clock() - start) / C.FadeOut, 1)
				for _, trail in trails do
					trail.Transparency = NumberSequence.new(fade, 1)
				end
				if fade >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
			carrier:Destroy()
		end)
	end
	return handle
end

-- The ball starts to break toward the pocket
function TraitFx.Hooked(lane: Model, ball: BasePart, isOwn: boolean)
	playSound("Curve", ball)
	if isOwn then
		traitPopup("Curve", rackPoint(lane, 0, LANE.PinHeight + 1.5))
	end
end

-- Blast -----------------------------------------------------------------------------------------

-- White flash where the ball hits, then a yellow and a magenta shockwave ring across the lane
function TraitFx.Blast(lane: Model, position: Vector3, isOwn: boolean)
	local B = FX.Blast
	local diameter = B.RingRadius * LANE.PinSpacing * 2
	local canvasSize = diameter + 1
	local gui = flatCanvas(laneFloor(lane, position), canvasSize, B.Ring2Delay + B.RingTime + 0.2)
	local ppsu = FX.PixelsPerStud
	local share = diameter / canvasSize

	local function ring(color: Color3, delay: number)
		task.delay(delay, function()
			-- a soft wide glow under a crisp line
			for _, layer in { { 3, 0.65 }, { 1, 0 } } do
				local frame = Instance.new("Frame")
				frame.AnchorPoint = Vector2.new(0.5, 0.5)
				frame.Position = UDim2.fromScale(0.5, 0.5)
				frame.Size = UDim2.fromScale(0.02, 0.02)
				frame.BackgroundTransparency = 1
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = frame
				local stroke = Instance.new("UIStroke")
				stroke.Color = color
				stroke.Thickness = B.StrokeStart * ppsu * layer[1]
				stroke.Transparency = layer[2]
				stroke.Parent = frame
				frame.Parent = gui
				local info = snap(B.RingTime)
				tween(frame, info, { Size = UDim2.fromScale(share, share) })
				tween(stroke, info, { Thickness = B.StrokeEnd * ppsu * layer[1], Transparency = 1 })
			end
		end)
	end
	ring(B.Ring1, 0)
	ring(B.Ring2, B.Ring2Delay)

	local spot = flash(position, B.FlashSize, B.FlashTime)
	playSound("Blast", spot)
	if isOwn then
		CameraShake.Add(B.Shake)
		traitPopup("Blast", rackPoint(lane, RACK_DEPTH, LANE.PinHeight + 2))
	end
end

-- Streak Saver ----------------------------------------------------------------------------------

-- A glossy shield bubble pops up around the HUD streak counter, takes the hit, then bursts into sparkles
function TraitFx.StreakSaved()
	local S = FX.StreakSaver
	local hud = player:WaitForChild("PlayerGui"):FindFirstChild("HUD")
	local panel = hud and hud:FindFirstChild("Streak") :: GuiObject?
	if not panel then
		return
	end
	local layer = UiFx.Layer()
	local center = panel.AbsolutePosition + panel.AbsoluteSize / 2
	local diameter = math.max(panel.AbsoluteSize.X, panel.AbsoluteSize.Y) * S.Size

	local bubble = Instance.new("Frame")
	bubble.Name = "StreakShield"
	bubble.AnchorPoint = Vector2.new(0.5, 0.5)
	bubble.Position = UDim2.fromOffset(center.X, center.Y)
	bubble.Size = UDim2.fromOffset(diameter, diameter)
	bubble.BackgroundColor3 = S.Bubble
	bubble.BackgroundTransparency = S.Tint
	bubble.ZIndex = 15
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = bubble
	local rim = Instance.new("UIStroke")
	rim.Color = S.Bubble
	rim.Thickness = 3
	rim.Parent = bubble

	-- 2px cyan-deep line just outside the rim
	local outer = Instance.new("Frame")
	outer.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.Position = UDim2.fromScale(0.5, 0.5)
	outer.Size = UDim2.new(1, 8, 1, 8)
	outer.BackgroundTransparency = 1
	outer.ZIndex = 15
	corner:Clone().Parent = outer
	local outerLine = Instance.new("UIStroke")
	outerLine.Color = S.Rim
	outerLine.Thickness = 2
	outerLine.Parent = outer
	outer.Parent = bubble

	-- Hard-edged gloss across the top
	local gloss = Instance.new("Frame")
	gloss.AnchorPoint = Vector2.new(0.5, 0)
	gloss.Position = UDim2.fromScale(0.5, 0.07)
	gloss.Size = UDim2.fromScale(0.64, 0.33)
	gloss.BackgroundColor3 = WHITE
	gloss.BackgroundTransparency = 0.6
	gloss.ZIndex = 16
	corner:Clone().Parent = gloss
	gloss.Parent = bubble

	local scale = Instance.new("UIScale")
	scale.Scale = S.PopFrom
	scale.Parent = bubble
	bubble.Parent = layer

	playSound("StreakSaver")
	traitPopup("StreakSaver", function()
		return center - Vector2.new(0, diameter / 2 + 6)
	end)

	-- Pop in, the counter gets knocked sideways, the bubble wobbles from the hit
	tween(scale, pop(S.PopTime), { Scale = 1 })
	task.delay(S.JoltAt, function()
		local base = panel.Position
		panel.Position = base + UDim2.fromOffset(S.Jolt, 0)
		tween(panel, snap(S.JoltTime), { Position = base })
	end)
	task.delay(S.PopTime, function()
		local step = S.WobbleTime / 3
		for _, size in { 0.94, 1.03, 1 } do
			tween(scale, TweenInfo.new(step, Enum.EasingStyle.Sine), { Scale = size })
			task.wait(step)
		end
		task.wait(S.HoldTime)

		-- Pop: grow and fade, bursting into cyan sparkles
		local exit = TweenInfo.new(S.ExitTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		tween(scale, exit, { Scale = S.ExitScale })
		tween(bubble, exit, { BackgroundTransparency = 1 })
		tween(rim, exit, { Transparency = 1 })
		tween(outerLine, exit, { Transparency = 1 })
		tween(gloss, exit, { BackgroundTransparency = 1 })
		for i = 1, S.Sparkles do
			local angle = (i / S.Sparkles) * math.pi * 2 + math.random() * 0.4
			local sparkle = Instance.new("ImageLabel")
			sparkle.BackgroundTransparency = 1
			sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
			sparkle.Image = IMAGES.Diamond
			sparkle.ImageColor3 = if i % 3 == 0 then WHITE else S.Bubble
			local size = math.random(10, 18)
			sparkle.Size = UDim2.fromOffset(size, size)
			local from = center + Vector2.new(math.cos(angle), math.sin(angle)) * diameter * 0.45
			local to = center + Vector2.new(math.cos(angle), math.sin(angle)) * diameter * 0.8
			sparkle.Position = UDim2.fromOffset(from.X, from.Y)
			sparkle.ZIndex = 17
			sparkle.Parent = layer
			local fly = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tween(
				sparkle,
				fly,
				{ Position = UDim2.fromOffset(to.X, to.Y), Size = UDim2.fromOffset(0, 0), Rotation = 90 }
			)
			task.delay(0.35, sparkle.Destroy, sparkle)
		end
		task.wait(S.ExitTime)
		bubble:Destroy()
	end)
end

-- Lucky -----------------------------------------------------------------------------------------

-- A chunky clover spins up over the rack while four-point sparkles flash around the pins
function TraitFx.Lucky(lane: Model)
	local L = FX.Lucky
	local total = L.PopTime + L.HoldTime + L.ExitTime
	local cloverAt = rackPoint(lane, 0, LANE.PinHeight * 2) -- one pin-height above the head pin
	local part = fxPart(CFrame.new(cloverAt), Vector3.one * 0.2, total + 0.3)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(L.CloverSize + L.Ledge, L.CloverSize + L.Ledge)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.Parent = part

	local clover = Instance.new("Frame")
	clover.BackgroundTransparency = 1
	clover.AnchorPoint = Vector2.new(0.5, 0.5)
	clover.Position = UDim2.fromScale(0.5, 0.5)
	clover.Size = UDim2.fromOffset(L.CloverSize, L.CloverSize)
	clover.Rotation = -30
	clover.Parent = gui
	local images = {}
	-- ink ledge, then the darker lime shade, then the clover
	for i, layer in { { L.Ledge, FX.Ink }, { L.Ledge / 2, L.Shade }, { 0, L.Clover } } do
		local image = Instance.new("ImageLabel")
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Position = UDim2.fromOffset(0, layer[1])
		image.Image = IMAGES.Clover
		image.ImageColor3 = layer[2]
		image.ZIndex = i
		image.Parent = clover
		table.insert(images, image)
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = clover

	tween(scale, pop(L.PopTime), { Scale = 1 })
	tween(clover, pop(L.PopTime), { Rotation = L.Tilt })
	task.delay(L.PopTime + L.HoldTime, function()
		local exit = snap(L.ExitTime)
		tween(gui, exit, { StudsOffsetWorldSpace = Vector3.new(0, 0.6, 0) })
		for _, image in images do
			tween(image, exit, { ImageTransparency = 1 })
		end
	end)

	-- Six sparkles in a ring around the rack, slightly staggered
	local center = rackPoint(lane, RACK_DEPTH, LANE.PinHeight * 0.6)
	local radius = LANE.PinSpacing * 3 / 2 * L.RingScale
	local floor = laneFloor(lane, center)
	for i = 1, L.SparkleCount do
		task.delay(math.random() * L.SparkleStagger, function()
			local angle = (i / L.SparkleCount) * math.pi * 2 + (math.random() - 0.5) * 0.5
			local offset = floor:VectorToWorldSpace(Vector3.new(math.cos(angle), 0, math.sin(angle))) * radius
			local spot = fxPart(
				CFrame.new(center + offset + Vector3.new(0, math.random() * 1.5, 0)),
				Vector3.one * 0.2,
				L.SparkleTime + 0.1
			)
			local size = math.floor(between(L.SparkleSize))
			local sparkleGui = Instance.new("BillboardGui")
			sparkleGui.Size = UDim2.fromOffset(size, size)
			sparkleGui.LightInfluence = 0
			sparkleGui.AlwaysOnTop = true
			sparkleGui.Parent = spot
			local star = Instance.new("ImageLabel")
			star.BackgroundTransparency = 1
			star.AnchorPoint = Vector2.new(0.5, 0.5)
			star.Position = UDim2.fromScale(0.5, 0.5)
			star.Size = UDim2.fromScale(0, 0)
			star.Image = IMAGES.Star
			star.ImageColor3 = L.Sparkles[(i % #L.Sparkles) + 1]
			star.Parent = sparkleGui
			local grow = L.SparkleTime * 0.27
			tween(star, TweenInfo.new(grow, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1.2, 1.2), Rotation = 45 })
			task.wait(grow)
			tween(star, TweenInfo.new(L.SparkleTime - grow, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = UDim2.fromScale(0, 0),
				Rotation = 90,
			})
		end)
	end

	playSound("Lucky", part)
	traitPopup("Lucky", cloverAt + Vector3.new(0, 1.8, 0))
end

-- Gem Hunter ------------------------------------------------------------------------------------

-- Tiny diamond sparkles dropped behind the ball that twinkle once and fade, a glittering wake.
-- Call Move(ballPosition) every frame and Stop() when the ball reaches the pins.
function TraitFx.GemTrail(lane: Model)
	local G = FX.GemHunter
	local carrier = fxPart(CFrame.identity, Vector3.new(G.Jitter * 2, 0.3, 0.3))
	local emitters = {}
	for _, color in { G.Sparkle, G.Gem } do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = IMAGES.Diamond
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.Brightness = 2
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.08, G.Size, G.SizeRange),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(G.Lifetime)
		emitter.Speed = NumberRange.new(0)
		emitter.Rate = 1 / G.Interval / 2 -- the two colours share the sparkles
		emitter.Parent = carrier
		table.insert(emitters, emitter)
	end

	local handle = {}
	function handle.Move(position: Vector3)
		carrier.CFrame = laneFloor(lane, position) + Vector3.new(0, LANE.BallDiameter * 0.3, 0)
	end
	function handle.Stop()
		for _, emitter in emitters do
			emitter.Enabled = false
		end
		task.delay(G.Lifetime + 0.1, carrier.Destroy, carrier)
	end
	return handle
end

-- The gem pops up at the pins, then flies into the HUD gem counter, which bumps.
-- While gems are off (Config.Gems) amount is bonus coins, and a coin flies into the coin counter instead.
function TraitFx.GemPayout(lane: Model, amount: number)
	local G = FX.GemHunter
	local above = rackPoint(lane, RACK_DEPTH, LANE.PinHeight + 1)
	traitPopup("GemHunter", above + Vector3.new(0, 1.5, 0), if Config.Gems.Enabled then amount else tostring(amount))
	playSound("GemHunter")

	local hud = player:WaitForChild("PlayerGui"):FindFirstChild("HUD")
	local counter = if Config.Gems.Enabled then "Gems" else "Coins"
	local pill = hud and hud:FindFirstChild("Bar") and hud.Bar:FindFirstChild(counter) :: GuiObject?
	local icon = pill and pill:FindFirstChild("Icon") :: GuiObject?
	if not icon then
		return
	end
	local size = G.GemSize * screenScale()
	local from = toScreen(above)
	local gem = icon:Clone()
	gem.AnchorPoint = Vector2.new(0.5, 0.5)
	gem.Position = UDim2.fromOffset(from.X, from.Y)
	gem.Size = UDim2.fromOffset(size, size)
	gem.ZIndex = 30
	local scale = gem:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = gem
	gem.Parent = UiFx.Layer()
	tween(scale, pop(G.PopTime), { Scale = 1 })

	task.delay(G.PopTime, function()
		local target = icon.AbsolutePosition + icon.AbsoluteSize / 2
		tween(gem, snap(G.FlyTime), {
			Position = UDim2.fromOffset(target.X, target.Y),
			Size = UDim2.fromOffset(icon.AbsoluteSize.X, icon.AbsoluteSize.Y),
		})
		task.wait(G.FlyTime)
		gem:Destroy()
		local pillScale = pill:FindFirstChildOfClass("UIScale")
		if pillScale then
			pillScale.Scale = G.Bump
			tween(pillScale, pop(0.25), { Scale = 1 })
		end
	end)
end

-- Heavy -----------------------------------------------------------------------------------------

-- The ball slams in: white flash, camera shake, jagged red-hot cracks splitting the lane and two dust puffs
function TraitFx.Heavy(lane: Model, position: Vector3, isOwn: boolean)
	local H = FX.Heavy
	local floor = laneFloor(lane, position)
	local spot = flash(position, LANE.BallDiameter * 1.2, H.FlashTime)
	playSound("Heavy", spot)
	if isOwn then
		CameraShake.Add(H.Shake)
		traitPopup("Heavy", position + Vector3.new(0, LANE.PinHeight + 1.5, 0))
	end

	-- Cracks: each branch is three jagged segments drawn outward, red glow under an ink line
	local ppsu = FX.PixelsPerStud
	local canvasSize = H.Length[2] * 2 + 1
	local gui = flatCanvas(floor, canvasSize, H.DrawTime + H.HoldTime + H.FadeTime + 0.1)
	local center = Vector2.one * canvasSize * ppsu / 2
	local glows, inks = {}, {}
	local branches = math.random(H.Branches[1], H.Branches[2])
	local segments = 3
	for b = 1, branches do
		local heading = (b / branches) * math.pi * 2 + (math.random() - 0.5) * 0.6
		local step = between(H.Length) * ppsu / segments
		local point = center
		for s = 1, segments do
			local angle = heading + (math.random() - 0.5) * 0.9
			local nextPoint = point + Vector2.new(math.cos(angle), math.sin(angle)) * step
			local middle = (point + nextPoint) / 2
			for _, layer in { { H.Glow, H.GlowWidth, 1, glows }, { H.Ink, H.InkWidth, 2, inks } } do
				local width = layer[2] * ppsu
				local line = Instance.new("Frame")
				line.BorderSizePixel = 0
				line.BackgroundColor3 = layer[1]
				line.BackgroundTransparency = if layer[3] == 1 then 0.2 else 0
				line.AnchorPoint = Vector2.new(0.5, 0.5)
				line.Position = UDim2.fromOffset(point.X, point.Y)
				line.Size = UDim2.fromOffset(0, width)
				line.Rotation = math.deg(angle)
				line.ZIndex = layer[3]
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = line
				line.Parent = gui
				task.delay(H.DrawTime * (s - 1) / segments, tween, line, TweenInfo.new(H.DrawTime / segments), {
					Position = UDim2.fromOffset(middle.X, middle.Y),
					Size = UDim2.fromOffset(step + width, width),
				})
				table.insert(layer[4], line)
			end
			point = nextPoint
		end
	end
	task.delay(H.DrawTime + H.HoldTime, function()
		local fade = TweenInfo.new(H.FadeTime)
		for _, line in glows do
			tween(line, fade, { BackgroundColor3 = H.Deep, BackgroundTransparency = 1 })
		end
		for _, line in inks do
			tween(line, fade, { BackgroundTransparency = 1 })
		end
	end)

	-- Two dust puffs kick up either side
	for _, side in { -1, 1 } do
		local at = floor * CFrame.new(side * LANE.BallDiameter * 0.8, LANE.BallDiameter * 0.5, 0)
		local puff = fxPart(at, Vector3.one * 0.2, H.DustTime + 0.1)
		local dust, image = glowSprite(puff, H.Dust, LANE.BallDiameter, 0.3)
		local info = TweenInfo.new(H.DustTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local grown = LANE.BallDiameter * H.DustGrow
		tween(dust, info, { Size = UDim2.fromScale(grown, grown), StudsOffsetWorldSpace = Vector3.new(0, 0.6, 0) })
		tween(image, info, { ImageTransparency = 1 })
	end
end

return TraitFx
