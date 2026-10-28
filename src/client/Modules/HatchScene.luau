-- The Neon Egg hatching on its real stand in the lobby, following the owner's "Hatch Storyboard" (Claude Design,
-- Neon Lanes Pet Egg Design): 6 frames in about 3 seconds.
--   1 Idle 0.30s · 2 Activation 0.40s (stand flares, a charge climbs the circuit lines) · 3 Shake 0.75s (3 wobbles,
--   core flashes, sparks leak) · 4 Crack 0.40s (cracks snap open, light beams out, lines overload, arch flashes,
--   short hold) · 5 Burst 0.35s (flash, shards fly, energy rings) · 6 Reveal 0.80s (pet rises, sparkles fall).
-- Burst colours stay cyan/magenta for every pet; Epic, Legendary and Mythic only make it bigger (Config.MascotFx.Hatch
-- Tiers).
-- A1 upgrade (owner 2026-10-28, "more full of life"): the world dims, a spotlight shines on the egg and light specks
-- drift up around the stand; the glow climbs one rarity colour per wobble, honestly, up to the pet's real rarity
-- (rarer pets wobble more: Epic 4, Legendary 5, Mythic 6), with a chime and a ring on each step up; the camera creeps
-- in during the wobbles, snaps in at the crack and pulls back for the burst; the pet rises in front of turning rays in
-- its rarity colour and does its own reaction. The quick version (AUTO HATCH, after 5 hatches) plays the same at
-- double speed instead of jumping straight to the reveal.
-- Client only: the server already rolled the pet (MascotService). Every extra part lives in one folder that goes
-- when the scene ends, and the stand and egg get their own colours back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CrateKitAssets = require(Shared.CrateKitAssets)
local Mascots = require(Shared.Modules.Mascots)
local MascotView = require(script.Parent.MascotView)
local PetIdle = require(script.Parent.PetIdle)
local Sfx = require(script.Parent.Sfx)
local UiFx = require(script.Parent.UiFx)

local player = Players.LocalPlayer
local SETTINGS = Config.MascotFx.Hatch

local WHITE = Color3.new(1, 1, 1)
local CYAN = Color3.fromHex("3fefff")
local MAGENTA = Color3.fromHex("ff3ad0")
local SHELL = Color3.fromHex("7a4cff")
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SPARK = "rbxasset://textures/particles/fire_sparks_main.dds"

local HatchScene = {}

export type Context = {
	Stand: Model, -- Workspace.Hub.EggPad.NeonStand
	Spot: BasePart, -- where the egg sits (its centre)
	Egg: Model, -- the egg in the cradle (its idle pulse is paused while this plays)
	Mascot: any, -- the pet that hatched
	SkipAt: number?, -- os.clock() of the player's last tap (taps from SkipFrom on jump to the reveal)
	AutoSkip: boolean?, -- the quick version: no idle beat, the tease at QuickPace speed
	OnCard: (() -> ())?, -- the name card should pop in now
	EdgePulse: ((Color3) -> ())?, -- Mythic: pulse the screen edges in this colour
	Camera: any?, -- AUTO HATCH: the camera from before the first hatch of the run (Play fills it in when left out)
}

local function ease(u: number, style: Enum.EasingStyle, direction: Enum.EasingDirection?): number
	return TweenService:GetValue(math.clamp(u, 0, 1), style, direction or Enum.EasingDirection.Out)
end

local function newPart(
	folder: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	cf: CFrame,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = cf
	p.Parent = folder
	return p
end

local function newEmitter(folder: Instance, texture: string): (Attachment, ParticleEmitter)
	local holder = Workspace.Terrain
	local attachment = Instance.new("Attachment")
	attachment.Parent = holder
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = texture
	emitter.Rate = 0
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Parent = attachment
	-- The attachment lives on Terrain (emitters need a part or Terrain); the folder's ending removes it too
	folder.Destroying:Once(function()
		attachment:Destroy()
	end)
	return attachment, emitter
end

local function colors(...: Color3): ColorSequence
	local list = { ... }
	local keys = {}
	for i, c in list do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #list - 1), c))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, list[1]))
	end
	return ColorSequence.new(keys)
end

function HatchScene.TierOf(rarity: string)
	return SETTINGS.Tiers[SETTINGS.TierOf[rarity] or "Base"]
end

-- Plays the hatch up to the settled reveal. Returns the function that ends the scene (camera, stand and egg back
-- to normal) for when the player closes the card.
function HatchScene.Play(ctx: Context): (boolean?) -> ()
	local mascot = ctx.Mascot
	local tier = HatchScene.TierOf(mascot.Rarity)
	local rarityColor = Mascots.RarityColor(mascot.Rarity)
	local rarityIndex = Mascots.RarityIndex(mascot.Rarity)
	local quick = ctx.AutoSkip == true
	local pace = if quick then SETTINGS.QuickPace else 1
	local camera = Workspace.CurrentCamera
	local folder = Instance.new("Folder")
	folder.Name = "HatchFx"
	folder.Parent = Workspace

	-- The camera once the wobbles start: the close shot, pushed in by camPush (share of the way to the stand),
	-- shaken by camShake studs
	local shot = CFrame.identity
	local driveCamera = false
	local camPush, camShake = 0, 0
	local pushDistance = 0

	-- Running effects: each one is a function of how far through it is (0 to 1), stepped every frame
	local effects: { { Start: number, Time: number, Step: (number) -> () } } = {}
	local stepper = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for i = #effects, 1, -1 do
			local effect = effects[i]
			local u = (now - effect.Start) / effect.Time
			effect.Step(math.min(u, 1))
			if u >= 1 then
				table.remove(effects, i)
			end
		end
		if driveCamera then
			local cf = shot * CFrame.new(0, 0, -pushDistance * camPush)
			if camShake > 0 then
				cf *= CFrame.new((math.random() - 0.5) * camShake, (math.random() - 0.5) * camShake, 0)
			end
			camera.CFrame = cf
		end
	end)
	local function animate(time: number, step: (number) -> ())
		step(0)
		table.insert(effects, { Start = os.clock(), Time = time, Step = step })
	end

	-- ===== Stand and egg: remember their looks so they can glow and go back =====
	local standGlow: { [BasePart]: Color3 } = {}
	local arch: { BasePart } = {}
	for _, part in ctx.Stand:GetDescendants() do
		if part:IsA("BasePart") and part.Material == Enum.Material.Neon then
			standGlow[part] = part.Color
			if part.Name:match("^arch_") then
				table.insert(arch, part)
			end
		end
	end
	local sign = ctx.Stand:FindFirstChild("sign_face", true) :: BasePart?
	local underglow = ctx.Stand:FindFirstChild("sign_underglow", true) :: BasePart?

	local egg = ctx.Egg
	local eggParent = egg.Parent
	local eggPivot = egg:GetPivot()
	local eggLooks: { [BasePart]: { Color: Color3, Transparency: number, Size: Vector3 } } = {}
	local circuits: { { Part: BasePart, Height: number } } = {}
	local pads: { BasePart } = {}
	local core = egg:FindFirstChild("core", true) :: BasePart?
	local halo = egg:FindFirstChild("core_halo", true) :: BasePart?
	local shell = egg:FindFirstChild("shell", true) :: BasePart?
	local height = ctx.Spot.Size.Y
	local center = ctx.Spot.Position
	local bottom = center - Vector3.yAxis * height / 2
	for _, part in egg:GetDescendants() do
		if part:IsA("BasePart") then
			eggLooks[part] = { Color = part.Color, Transparency = part.Transparency, Size = part.Size }
			if part.Name:match("^circuit_") then
				table.insert(
					circuits,
					{ Part = part, Height = math.clamp((part.Position.Y - bottom.Y) / height, 0, 1) }
				)
				if part.Name:match("^circuit_pad") then
					table.insert(pads, part)
				end
			end
		end
	end
	local radius = if shell then math.max(shell.Size.X, shell.Size.Z) / 2 else height * 0.39
	local halfHeight = if shell then shell.Size.Y / 2 else height / 2

	-- How white the stand's tubes are (0 = their own colour)
	local standFlare = 0
	local archExtra = 0
	local function paintStand()
		for part, color in standGlow do
			local amount = standFlare
			if table.find(arch, part) then
				amount = math.max(amount, archExtra)
			end
			part.Color = color:Lerp(WHITE, math.clamp(amount, 0, 1))
		end
	end
	-- How white each circuit line is, on top of the charge front
	local overload = 0
	local charge = -1 -- height of the charge front climbing the lines (0 = bottom, 1 = top)
	local lit = 0 -- how lit the lines stay once the charge has passed
	local function paintCircuits()
		for _, line in circuits do
			local behind = charge - line.Height
			local front = if behind >= 0 and behind < 0.25 then 1 - behind / 0.25 else 0
			local amount = math.max(overload, front, if behind >= 0 then lit else 0)
			line.Part.Color = eggLooks[line.Part].Color:Lerp(WHITE, math.clamp(amount, 0, 1))
		end
	end
	-- The rarity colour the glow has climbed to (A1), and how much the core and halo take it on
	local teaseColor = Mascots.RarityColor(Mascots.Rarities[1])
	local teaseAmount = 0
	-- The core: 1 = its own glow, 2 = twice as bright and a bit bigger
	local function paintCore(level: number)
		local over = math.max(0, level - 1)
		if core then
			local look = eggLooks[core]
			core.Color = look.Color:Lerp(teaseColor, teaseAmount):Lerp(WHITE, math.clamp(over * 0.6, 0, 1))
			core.Transparency = 0
		end
		if halo then
			local look = eggLooks[halo]
			halo.Color = look.Color:Lerp(teaseColor, teaseAmount)
			halo.Transparency = math.clamp(look.Transparency - over * 0.35, 0.25, 1)
			halo.Size = look.Size * (1 + over * 0.25)
		end
	end

	local light = Instance.new("PointLight")
	light.Color = MAGENTA
	light.Range = 16
	light.Brightness = 0
	light.Shadows = false
	local lightPart = newPart(folder, "Light", Vector3.one * 0.1, WHITE, CFrame.new(center))
	lightPart.Transparency = 1
	light.Parent = lightPart

	-- ===== Camera: a close shot of egg and stand, sign on screen =====
	local savedCamera = ctx.Camera or { Type = camera.CameraType, CFrame = camera.CFrame, Fov = camera.FieldOfView }
	ctx.Camera = savedCamera
	local standCf, standSize = ctx.Stand:GetBoundingBox()
	local facing: Vector3
	local frame = ctx.Stand:FindFirstChild("sign_frame", true) :: BasePart?
	if sign and frame and (sign.Position - frame.Position).Magnitude > 0.01 then
		facing = (sign.Position - frame.Position) * Vector3.new(1, 0, 1)
	else
		facing = (camera.CFrame.Position - center) * Vector3.new(1, 0, 1)
	end
	facing = if facing.Magnitude > 0.01 then facing.Unit else Vector3.zAxis
	local lookAt = Vector3.new(center.X, standCf.Position.Y, center.Z)
	local fov = SETTINGS.CameraFov
	local distance = standSize.Y / SETTINGS.CameraFill / (2 * math.tan(math.rad(fov / 2)))
	shot = CFrame.lookAt(lookAt + facing * distance + Vector3.yAxis * SETTINGS.CameraHeight, lookAt)
	pushDistance = (shot.Position - lookAt).Magnitude
	local right = shot.RightVector
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(SETTINGS.CameraIn, Enum.EasingStyle.Sine), {
		CFrame = shot,
		FieldOfView = fov,
	}):Play()

	-- Your own character steps out of the shot (it stands right in front of the stand)
	local hiddenParts: { Instance } = {}
	local character = player.Character
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				d.LocalTransparencyModifier = 1
				table.insert(hiddenParts, d)
			end
		end
	end
	local controls = nil
	pcall(function()
		local module = player:WaitForChild("PlayerScripts"):FindFirstChild("PlayerModule")
		controls = module and (require(module :: any) :: any):GetControls()
		if controls then
			controls:Disable()
		end
	end)

	-- ===== Timing: phases wait frame by frame; a tap after SkipFrom (or AutoSkip) jumps to the reveal =====
	local started = os.clock()
	local function skipping(): boolean
		local tap = ctx.SkipAt
		return tap ~= nil and tap >= started + SETTINGS.SkipFrom
	end
	local function hold(time: number, step: ((number, number) -> ())?): boolean
		local from = os.clock()
		while true do
			local elapsed = os.clock() - from
			if skipping() then
				return false
			end
			if step then
				step(math.min(elapsed / time, 1), elapsed)
			end
			if elapsed >= time then
				return true
			end
			RunService.RenderStepped:Wait()
		end
	end

	-- ===== Little builders =====
	local sparkAttachment, sparks = newEmitter(folder, SPARK)
	sparks.Color = colors(WHITE, CYAN, MAGENTA)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.35, 0.7)
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Acceleration = Vector3.new(0, -28, 0)
	sparks.EmissionDirection = Enum.NormalId.Top

	local function leakSparks(count: number)
		for _ = 1, count do
			local pad = if #pads > 0 then pads[math.random(#pads)] else nil
			sparkAttachment.WorldPosition = if pad then pad.Position else center
			sparks:Emit(1)
		end
	end

	-- ===== Mood (A1): the world dims, a spotlight on the egg, light specks drifting up around the stand =====
	-- The dim lives on the camera (ZoneLookController owns Lighting's colour correction); AUTO HATCH keeps it
	-- between eggs in the saved camera so the world doesn't flash bright in between
	local dim = savedCamera.Dim
	if not dim or not dim.Parent then
		dim = Instance.new("ColorCorrectionEffect")
		dim.Name = "HatchDim"
		dim.Parent = camera
		savedCamera.Dim = dim
	end
	TweenService:Create(dim, TweenInfo.new(SETTINGS.DimTime * pace, Enum.EasingStyle.Sine), {
		Brightness = SETTINGS.DimBrightness,
		TintColor = SETTINGS.DimTint,
	}):Play()

	local spotPart = newPart(
		folder,
		"Spotlight",
		Vector3.one * 0.1,
		WHITE,
		CFrame.lookAt(center + Vector3.yAxis * height * 2.4 + facing * height * 0.6, center)
	)
	spotPart.Transparency = 1
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Angle = 50
	spot.Range = height * 4
	spot.Brightness = 0
	spot.Shadows = false
	spot.Color = teaseColor
	spot.Parent = spotPart
	animate(SETTINGS.DimTime * pace, function(u)
		spot.Brightness = SETTINGS.Spotlight * u
	end)

	local moteBox = newPart(
		folder,
		"Motes",
		Vector3.new(math.min(standSize.X, height * 2.6), height * 1.4, math.min(standSize.Z, height * 2.6)),
		WHITE,
		CFrame.new(center)
	)
	moteBox.Transparency = 1
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = SPARKLE
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Rate = SETTINGS.Motes
	motes.Lifetime = NumberRange.new(1.4, 2.4)
	motes.Speed = NumberRange.new(0.4, 1)
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Color = ColorSequence.new(WHITE)
	motes.Parent = moteBox

	-- The glow's rarity colour: core, halo, egg light, spotlight, specks and the leaking sparks
	local function setTease(color: Color3)
		teaseColor = color
		spot.Color = color:Lerp(WHITE, 0.35)
		motes.Color = ColorSequence.new(color:Lerp(WHITE, 0.3))
		sparks.Color = colors(WHITE, color)
		light.Color = color
	end

	-- A point on the egg's surface: `side` turns away from the camera's view (radians), `up` from -1 to 1
	local function onShell(side: number, up: number, lift: number?): (Vector3, Vector3)
		local ring = math.sqrt(math.max(0, 1 - up * up))
		local normal = (facing * math.cos(side) + right * math.sin(side)) * ring + Vector3.yAxis * up
		local point = center
			+ (facing * math.cos(side) + right * math.sin(side)) * ring * radius * (lift or 1.03)
			+ Vector3.yAxis * up * halfHeight * (lift or 1.03)
		return point, normal.Unit
	end

	-- One jagged crack across the shell, with light beaming out of it
	local crackCount = 0
	local function crack(fromSide: number, fromUp: number, toSide: number, toUp: number)
		crackCount += 1
		local steps = 6
		local points = {}
		for i = 0, steps do
			local t = i / steps
			local jitter = if i == 0 or i == steps then 0 else (math.random() - 0.5) * 0.35
			local side = fromSide + (toSide - fromSide) * t + jitter
			local up = math.clamp(fromUp + (toUp - fromUp) * t + jitter * 0.4, -0.95, 0.95)
			points[i + 1] = { onShell(side, up) }
		end
		for i = 1, steps do
			local a, b = points[i][1], points[i + 1][1]
			local segment = newPart(
				folder,
				"Crack",
				Vector3.new(0.09, 0.09, (b - a).Magnitude + 0.06),
				WHITE,
				CFrame.lookAt((a + b) / 2, b)
			)
			segment.Transparency = 0
		end
		-- Light shafts from the middle of the crack outward, white fading to the pet's rarity colour
		for _, index in { 3, 5 } do
			local point, normal = points[index][1], points[index][2]
			local a0 = Instance.new("Attachment")
			a0.WorldPosition = point
			a0.Parent = Workspace.Terrain
			local a1 = Instance.new("Attachment")
			a1.WorldPosition = point + normal * SETTINGS.BeamLength
			a1.Parent = Workspace.Terrain
			folder.Destroying:Once(function()
				a0:Destroy()
				a1:Destroy()
			end)
			local beam = Instance.new("Beam")
			beam.Attachment0 = a0
			beam.Attachment1 = a1
			beam.FaceCamera = true
			beam.LightEmission = 1
			beam.LightInfluence = 0
			beam.Width0 = 0.25
			beam.Width1 = 1.4
			beam.Color = colors(WHITE, rarityColor:Lerp(WHITE, 0.3))
			beam.Transparency =
				NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
			beam.Segments = 2
			beam.Parent = folder
			animate(0.12, function(u)
				beam.Width0 = 0.25 * u
				beam.Width1 = 1.4 * u
			end)
		end
		Sfx.Play("HatchCrack", 0.9 + crackCount * 0.12)
	end

	-- A ring of energy spreading across the platform
	local function energyRing(color: Color3)
		local segments = 28
		local pieces = {}
		for i = 1, segments do
			pieces[i] = newPart(folder, "Ring", Vector3.new(0.18, 0.12, 0.5), color, CFrame.new(bottom))
		end
		local floorY = bottom.Y - 0.1
		local widest = math.max(standSize.X, standSize.Z) * SETTINGS.RingWidth / 2
		animate(SETTINGS.RingTime, function(u)
			local r = 0.8 + (widest - 0.8) * ease(u, Enum.EasingStyle.Quart)
			local chord = 2 * r * math.sin(math.pi / segments) + 0.05
			for i, piece in pieces do
				local angle = (i - 0.5) / segments * math.pi * 2
				local at = Vector3.new(center.X + math.cos(angle) * r, floorY, center.Z + math.sin(angle) * r)
				piece.Size = Vector3.new(0.22 * (1 - u * 0.5), 0.12, chord)
				piece.CFrame = CFrame.lookAt(at, Vector3.new(center.X, floorY, center.Z))
					* CFrame.Angles(0, math.pi / 2, 0)
				piece.Transparency = ease(u, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
	end

	local function restoreEggLooks()
		for part, look in eggLooks do
			part.Color = look.Color
			part.Transparency = look.Transparency
			part.Size = look.Size
		end
	end

	local shimmer: Sound? = nil -- the charge's sparkling chimes (faded out at the burst)

	-- ===== The reveal: the pet rises out of the light and settles above the stand =====
	local pet: Model? = nil
	local petRig = nil
	local petLoop: RBXScriptConnection? = nil
	local function reveal(skipped: boolean)
		-- Skipped: whatever was still going (cracks, beams, pillar) clears. Either way the egg is gone
		if skipped then
			for _, child in folder:GetChildren() do
				local keep = child == lightPart or child == spotPart or child == moteBox
				if (not keep and child:IsA("BasePart")) or child:IsA("Beam") then
					child:Destroy()
				end
			end
			table.clear(effects)
			camera.CFrame = shot
		end
		overload = 0
		archExtra = 0
		egg.Parent = nil
		if skipped then
			UiFx.Flash(WHITE, 0.5, 0.25)
			Sfx.Play("HatchBurst", 1.1, 0.7)
			Sfx.FadeOut(shimmer, 0.25)
			energyRing(CYAN)
		end
		setTease(rarityColor)
		motes:Emit(24)

		local size = height * SETTINGS.PetSize
		local model = MascotView.Mascot(mascot, size)
		MascotView.Soften(model)
		local rest = center + Vector3.yAxis * SETTINGS.PetLift
		local toCamera = (shot.Position - rest) * Vector3.new(1, 0, 1)
		local face = if toCamera.Magnitude > 0.01 then toCamera.Unit else facing
		local function place(at: Vector3, extra: CFrame?)
			model:PivotTo(CFrame.lookAt(at, at + face) * (extra or CFrame.identity))
		end
		place(rest - Vector3.yAxis * SETTINGS.PetRise)
		model.Parent = folder
		pet = model
		petRig =
			PetIdle.Rig(model, (mascot.Base or mascot).Model or (mascot.Base or mascot).Id, size / Config.MascotFx.Size)

		-- Rays (A1): the Crate Kit's reveal rays in the rarity colour, turning behind the pet (Legendary and Mythic
		-- get a 2nd, bigger layer turning the other way). A BillboardGui in the world, so the pet stays in front.
		local raysAt = Instance.new("Attachment")
		raysAt.WorldPosition = rest + Vector3.yAxis * size * 0.1 - face * size * 0.9
		raysAt.Parent = Workspace.Terrain
		folder.Destroying:Once(function()
			raysAt:Destroy()
		end)
		local rays: { ImageLabel } = {}
		local layers = if rarityIndex >= Mascots.RarityIndex("Legendary") then 2 else 1
		for layer = 1, layers do
			local across = size * SETTINGS.RaysSize * (if layer == 2 then 1.35 else 1)
			local board = Instance.new("BillboardGui")
			board.Name = "HatchRays"
			board.Size = UDim2.fromScale(across, across) -- a BillboardGui's scale is studs
			board.LightInfluence = 0
			board.AlwaysOnTop = false
			board.Parent = raysAt
			local image = Instance.new("ImageLabel")
			image.BackgroundTransparency = 1
			image.Image = CrateKitAssets.Image("Rays")
			image.ImageColor3 = rarityColor:Lerp(WHITE, if layer == 2 then 0.3 else 0.1)
			image.ImageTransparency = if layer == 2 then 0.45 else 0.15
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.Position = UDim2.fromScale(0.5, 0.5)
			image.Size = UDim2.fromScale(1, 1)
			image.Parent = board
			local grow = Instance.new("UIScale")
			grow.Scale = 0
			grow.Parent = image
			TweenService:Create(grow, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			table.insert(rays, image)
		end

		-- The light it comes out of
		local orb = newPart(folder, "Orb", Vector3.one * height * 1.1, WHITE, CFrame.new(center), Enum.PartType.Ball)
		animate(0.45, function(u)
			orb.Size = Vector3.one * height * 1.1 * (1 + u * 0.4)
			orb.Transparency = ease(u, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		end)

		-- Sparkles drift down for 0.8s, in the pet's rarity colour
		local sparkleAttachment, sparkles = newEmitter(folder, SPARKLE)
		sparkleAttachment.WorldPosition = rest + Vector3.yAxis * size * 0.9
		sparkles.Color = colors(WHITE, rarityColor)
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.2, 0.45),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.Lifetime = NumberRange.new(0.9, 1.5)
		sparkles.Speed = NumberRange.new(3, 6)
		sparkles.SpreadAngle = Vector2.new(70, 70)
		sparkles.Acceleration = Vector3.new(0, -5, 0)
		sparkles.Drag = 2
		sparkles.RotSpeed = NumberRange.new(-180, 180)
		local sparkleBursts = 8
		for i = 0, sparkleBursts - 1 do
			task.delay(i * SETTINGS.RevealTime / sparkleBursts, function()
				if sparkles.Parent then
					sparkles:Emit(math.ceil(tier.Sparkles / sparkleBursts))
				end
			end)
		end

		-- The stand eases back to its idle glow
		local flareFrom = standFlare
		animate(SETTINGS.RevealTime, function(u)
			standFlare = flareFrom * (1 - u)
			paintStand()
			light.Brightness = 3 * (1 - u)
		end)

		-- Rise 0.4 studs out of the light, overshoot a little, settle by 0.45s; then it does its own reaction twice
		-- (Hop/Spin/Flip/Wiggle, Config.Mascots) and idles and slowly turns
		local riseStart = os.clock()
		local reaction = mascot.Reaction or (mascot.Base or mascot).Reaction
		local reactFrom = SETTINGS.PetSettle + SETTINGS.ReactDelay
		local reactTime = Config.MascotFx.ReactTime
		petLoop = RunService.RenderStepped:Connect(function()
			local t = os.clock() - riseStart
			local rise = ease(t / SETTINGS.PetSettle, Enum.EasingStyle.Back)
			local at = rest - Vector3.yAxis * SETTINGS.PetRise * (1 - rise)
			local lift, tilt = 0, CFrame.identity
			if petRig then
				petRig:Step(os.clock(), true)
				if t > SETTINGS.PetSettle then
					lift, tilt = petRig:Body(os.clock())
				end
			end
			if t > reactFrom and t < reactFrom + reactTime * 2 then
				local reactLift, pose =
					PetIdle.ReactionPose(reaction, ((t - reactFrom) / reactTime) % 1, size * SETTINGS.ReactLift)
				lift += reactLift
				tilt *= pose
			end
			for index, image in rays do
				image.Rotation = t * (if index == 1 then 30 else -20)
			end
			place(at + Vector3.yAxis * lift, CFrame.Angles(0, math.sin(t * 0.8) * 0.35, 0) * tilt)
		end)

		task.delay(SETTINGS.CardAt, function()
			if ctx.OnCard then
				ctx.OnCard()
			end
		end)
		local rarity = Mascots.RarityIndex(mascot.Rarity)
		if rarity >= Mascots.RarityIndex("Epic") then
			Sfx.Play("RevealBig")
		else
			Sfx.Play("Reveal")
		end
		if rarity >= Mascots.RarityIndex("Legendary") then
			Sfx.Play("Firework", 1, 0.8)
			Sfx.Play("HatchFanfare")
		end
		task.wait(SETTINGS.RevealTime)
	end

	-- ===== The sequence =====
	local function sequence(): boolean
		-- 1 · Idle (0.30s): the camera settles in, the core keeps its slow beat (the quick version skips it)
		if not quick then
			hold(SETTINGS.Idle, function(_, elapsed)
				paintCore(1 + 0.2 * math.sin(elapsed * math.pi * 2 / 1.6))
			end)
		end

		-- 2 · Activation (0.40s): stand flares and the sign flickers at 0.08s; a white charge climbs the lines
		shimmer = Sfx.Play("HatchCharge", 1)
		local flickered = false
		if
			not hold(SETTINGS.Activation * pace, function(_, elapsed)
				if elapsed >= 0.08 then
					-- Flare to "200%": jump bright, then hold a strong glow
					standFlare = math.max(0.35, 0.75 - (elapsed - 0.08) * 1.5)
					light.Brightness = 2.5
					if not flickered then
						flickered = true
						if sign then
							sign.Transparency = 0.75
						end
						if underglow then
							underglow.Transparency = 1
						end
						task.delay(0.06, function()
							if sign then
								sign.Transparency = 0
							end
							if underglow then
								underglow.Transparency = 0
							end
						end)
					end
				end
				paintStand()
				local u = math.clamp((elapsed - 0.08) / 0.32, 0, 1)
				charge = if elapsed >= 0.08 then u * u * 1.25 else -1
				lit = if elapsed >= 0.08 then 0.25 else 0
				paintCircuits()
			end)
		then
			return false
		end
		charge = 2
		paintCircuits()

		-- 3 · Shake (0.75s): 3 wobbles pivoting on the base, each harder and shorter; core flashes on each hit.
		-- A1: rarer pets wobble more (ExtraWobbles), and the glow climbs one rarity colour per wobble up to the
		-- pet's real rarity (never past it); each step up chimes, flashes and sends a ring across the platform.
		-- The camera creeps in as it goes.
		local wobbles = table.clone(SETTINGS.Wobbles)
		for i = 1, math.clamp(rarityIndex - #wobbles, 0, #SETTINGS.ExtraWobbles) do
			table.insert(wobbles, SETTINGS.ExtraWobbles[i])
		end
		driveCamera = true
		teaseAmount = 0.85
		local shownRarity = 0
		local axis = facing
		local base = bottom
		for index, wobble in wobbles do
			local shown = math.min(index, rarityIndex)
			local color = Mascots.RarityColor(Mascots.Rarities[shown])
			setTease(color)
			if shown > shownRarity and index > 1 then
				Sfx.Play("StreakUp", 0.8 + shown * 0.1, 0.7)
				UiFx.Flash(color, 0.12, 0.2)
				energyRing(color)
			end
			shownRarity = shown
			Sfx.Play("ReelTick", 0.85 + index * 0.15)
			leakSparks(tier.SparksPerHit)
			light.Brightness = 1.5 * wobble.Core
			if
				not hold(wobble.Time * pace, function(u)
					local angle = math.rad(wobble.Angle) * math.sin(u * math.pi * 2) * (1 - u * 0.25)
					egg:PivotTo(CFrame.new(base) * CFrame.fromAxisAngle(axis, angle) * CFrame.new(-base) * eggPivot)
					paintCore(1 + (wobble.Core - 1) * (1 - u) + 0.15)
					light.Brightness = 1.5 + 1.5 * wobble.Core * (1 - u)
					camPush = SETTINGS.Push * ((index - 1 + u) / #wobbles)
				end)
			then
				return false
			end
		end
		egg:PivotTo(eggPivot)

		-- 4 · Crack: the egg freezes, cracks snap open in steps, lines overload (3 blinks), the arch flashes, hold
		paintCore(2)
		light.Color = WHITE
		light.Brightness = 4
		local crackPlan = {
			{ -0.35, 0.75, 0.15, -0.2 },
			{ 0.55, 0.45, -0.25, 0.05 },
			{ -0.7, -0.1, 0.5, -0.55 },
		}
		local steps = tier.CrackSteps or 2
		local done = 0
		local flashes = { 0.20 }
		if tier.DoubleFlash then
			table.insert(flashes, 0.32)
		end
		local flashed = 0
		local pillarDone = false
		local crackTime = SETTINGS.CrackTime + (tier.Extra or 0) - (tier.Hold or SETTINGS.Hold)
		-- The camera snaps in (A1)
		animate(0.14, function(u)
			camPush = SETTINGS.Push + (SETTINGS.Punch - SETTINGS.Push) * ease(u, Enum.EasingStyle.Back)
		end)
		if
			not hold(crackTime, function(_, elapsed)
				while done < steps and elapsed >= done * 0.12 do
					done += 1
					local c = crackPlan[done]
					crack(c[1], c[2], c[3], c[4])
				end
				-- Overload: 3 white blinks over 0.30s
				overload = if elapsed < 0.3 and math.floor(elapsed / 0.05) % 2 == 0 then 1 else 0.3
				paintCircuits()
				while flashed < #flashes and elapsed >= flashes[flashed + 1] do
					flashed += 1
					archExtra = 1
					Sfx.Play("Tap", 1.6, 0.6)
					task.delay(0.07, function()
						archExtra = 0
					end)
				end
				paintStand()
				-- Legendary and Mythic: a light pillar from the top of the egg (and a short camera shake)
				if tier.Pillar and not pillarDone and elapsed >= 0.24 then
					pillarDone = true
					local top = center + Vector3.yAxis * halfHeight
					local tall = SETTINGS.PillarHeight
					local pillar = newPart(
						folder,
						"Pillar",
						Vector3.new(tall, 0.2, 0.2),
						rarityColor:Lerp(WHITE, 0.4),
						CFrame.new(top + Vector3.yAxis * tall / 2) * CFrame.Angles(0, 0, math.pi / 2),
						Enum.PartType.Cylinder
					)
					animate(0.6, function(u)
						local w = height * 0.55 * math.sin(math.min(u * 2, 1) * math.pi / 2)
						pillar.Size = Vector3.new(tall, w, w)
						pillar.Transparency = 0.15
							+ 0.85
								* ease(math.max(0, u - 0.4) / 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					end)
					Sfx.Play("StreakUp", 0.8, 0.8)
					animate(tier.CamShake or 0.1, function(u)
						camShake = (1 - u) * 0.18
					end)
					if tier.EdgePulse and ctx.EdgePulse then
						ctx.EdgePulse(rarityColor)
					end
				end
			end)
		then
			return false
		end
		camShake = 0
		-- The screen holds still for a moment (longer for Mythic)
		if not hold(tier.Hold or SETTINGS.Hold) then
			return false
		end

		-- 5 · Burst: white core flash, shards fly out spinning and fade, energy rings spread, sparks everywhere
		egg.Parent = nil
		overload = 0
		local flash = tier.Flash
		UiFx.Flash(WHITE, math.min(0.9, 0.5 * flash), 0.18)
		Sfx.Play("HatchBurst", 1)
		Sfx.FadeOut(shimmer, 0.3)
		-- The camera pulls back out to the close shot as the shell flies (A1)
		animate(SETTINGS.BurstTime, function(u)
			camPush = SETTINGS.Punch * (1 - ease(u, Enum.EasingStyle.Quad))
		end)
		light.Color = WHITE
		light.Range = 24
		animate(SETTINGS.BurstTime, function(u)
			-- Peaks at 0.06s, then a cyan to magenta falloff
			local peak = if u * SETTINGS.BurstTime < 0.06 then 1 else 1 - u
			light.Brightness = 6 * flash * peak
			light.Color = if u < 0.2 then WHITE elseif u < 0.6 then CYAN else MAGENTA
		end)
		task.delay(0.08, function()
			UiFx.Flash(CYAN, math.min(0.35, 0.18 * flash), 0.3)
		end)
		for _, child in folder:GetChildren() do
			if child.Name == "Crack" or child:IsA("Beam") then
				child:Destroy()
			end
		end
		for i = 1, tier.Shards do
			local side = (math.random() - 0.5) * math.pi * 2
			local up = math.random() * 1.8 - 0.9
			local from, normal = onShell(side, up, 1)
			local color = if i % 3 == 0 then CYAN elseif i % 3 == 1 then SHELL else MAGENTA
			local shard = Instance.new("WedgePart")
			shard.Size = Vector3.new(0.08, 0.5 + math.random() * 0.5, 0.4 + math.random() * 0.4) * (height / 3.5)
			shard.Color = color
			shard.Material = Enum.Material.Neon
			shard.Anchored = true
			shard.CanCollide = false
			shard.CanQuery = false
			shard.CanTouch = false
			shard.CastShadow = false
			shard.Parent = folder
			local velocity = (normal + facing * 0.35 + Vector3.yAxis * 0.25).Unit
				* (SETTINGS.ShardDistance * (0.7 + math.random() * 0.6))
			local spinAxis = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
			spinAxis = if spinAxis.Magnitude > 0.01 then spinAxis.Unit else Vector3.xAxis
			local spin = (math.random() * 2 + 2) * math.pi
			local tilt = CFrame.lookAt(Vector3.zero, normal)
			animate(SETTINGS.BurstTime, function(u)
				local travel = ease(u, Enum.EasingStyle.Quint)
				local at = from + velocity * travel - Vector3.yAxis * 1.5 * u * u
				shard.CFrame = CFrame.new(at) * tilt * CFrame.fromAxisAngle(spinAxis, spin * travel)
				shard.Transparency = ease(u, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end)
		end
		local burstAttachment, burst = newEmitter(folder, SPARK)
		burstAttachment.WorldPosition = center
		burst.Color = colors(WHITE, CYAN, MAGENTA)
		burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		burst.Lifetime = NumberRange.new(0.3, 0.65)
		burst.Speed = NumberRange.new(12, 24)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Drag = 5
		burst.Acceleration = Vector3.new(0, -10, 0)
		burst:Emit(tier.Sparks)
		for ring = 1, tier.Rings do
			task.delay((ring - 1) * 0.07, function()
				if folder.Parent then
					energyRing(if ring % 2 == 1 then CYAN else MAGENTA)
				end
			end)
		end
		restoreEggLooks()
		hold(SETTINGS.BurstTime)
		return true
	end

	local finished = sequence()
	driveCamera = false
	camPush, camShake = 0, 0
	camera.CFrame = shot
	egg:PivotTo(eggPivot)
	reveal(not finished)

	-- Ends the scene: pet gone, egg back in its cradle, stand back to normal, camera home
	-- (keepCamera = AUTO HATCH goes straight into the next egg, so the camera stays on the stand)
	local ended = false
	return function(keepCamera: boolean?)
		if ended then
			return
		end
		ended = true
		if petLoop then
			petLoop:Disconnect()
		end
		stepper:Disconnect()
		folder:Destroy()
		restoreEggLooks()
		egg:PivotTo(eggPivot)
		egg.Parent = eggParent
		for part, color in standGlow do
			part.Color = color
		end
		if sign then
			sign.Transparency = 0
		end
		if underglow then
			underglow.Transparency = 0
		end
		for _, d in hiddenParts do
			if d.Parent then
				(d :: any).LocalTransparencyModifier = 0
			end
		end
		if keepCamera then
			pet = nil
			return
		end
		-- The world brightens again
		local lastDim = savedCamera.Dim
		savedCamera.Dim = nil
		if lastDim then
			local undim = TweenService:Create(lastDim, TweenInfo.new(0.45, Enum.EasingStyle.Sine), {
				Brightness = 0,
				TintColor = WHITE,
			})
			undim.Completed:Once(function()
				lastDim:Destroy()
			end)
			undim:Play()
		end
		if controls then
			pcall(function()
				controls:Enable()
			end)
		end
		local home = TweenService:Create(camera, TweenInfo.new(0.45, Enum.EasingStyle.Sine), {
			CFrame = savedCamera.CFrame,
			FieldOfView = savedCamera.Fov,
		})
		home:Play()
		home.Completed:Once(function()
			camera.CameraType = savedCamera.Type
		end)
		pet = nil
	end
end

return HatchScene
