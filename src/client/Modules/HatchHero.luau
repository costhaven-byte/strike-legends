-- The thumbnail hatch (owner 2026-11-05, Config.Ui.HatchHero): the egg really breaks in two on a full-screen sunburst.
-- HatchV2 keeps the timing rules, cards and buttons; this module is the stage they play on. One full-screen ViewportFrame
-- holds the egg halves (PetModels.EggSplit_<egg Id>, built from tools/cut_eggs.py) and the pets, so the shell's front
-- wall really hides the pet as it climbs out. An egg with no EggSplit model plays the older HatchV2 hatch.
-- From the owner's references: glow that builds until it blows out, a one-frame takeover flash, hard-edged shapes,
-- beams of light, a held pose after the hit. The glow only ever climbs to the real rarity (honest teases).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Mascots = require(Shared.Modules.Mascots)
local SlKit = require(script.Parent.SlKit)
local Sfx = require(script.Parent.Sfx)

local make = SlKit.Make
local WHITE = Color3.new(1, 1, 1)

local HatchHero = {}

local function petModels(): Instance?
	return ReplicatedStorage:FindFirstChild("PetModels")
end

local function ease(u: number, style: Enum.EasingStyle, direction: Enum.EasingDirection?): number
	return TweenService:GetValue(u, style, direction or Enum.EasingDirection.Out)
end

function HatchHero.Available(eggId: string): boolean
	local models = petModels()
	return Config.Ui.HatchHero == true and models ~= nil and models:FindFirstChild("EggSplit_" .. eggId) ~= nil
end

-- ctx: EggId, Rarity, Mythic, Canvas, Width, Height, Phone, EggCentre, EggPx, Dim, Flash,
-- Bright (the rarity's light colour), Anim, SpawnAnim, Wait, Alive(), ShowBolts(on, colour)
function HatchHero.New(ctx: { [string]: any })
	local FX = Config.HatchHero
	local canvas: Frame = ctx.Canvas
	local cw, ch = ctx.Width, ctx.Height
	local centre: Vector2 = ctx.EggCentre
	local anim, spawnAnim, wait = ctx.Anim, ctx.SpawnAnim, ctx.Wait
	local mythic = ctx.Mythic == true
	local tier = Mascots.RarityIndex(ctx.Rarity)
	local stage = {}

	-- ===== Backdrop: flat two-tone sunburst =====
	local diagonal = math.sqrt(cw * cw + ch * ch) * 1.25
	local pre = FX.Colors.Build
	ctx.Dim.BackgroundColor3 = if mythic then FX.Colors.Mythic[1] else pre[1]
	local rays = make("ImageLabel", {
		Name = "Sunburst",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(centre.X, centre.Y),
		Size = UDim2.fromOffset(0, 0),
		Image = SlKit.Icon(if mythic then "hatch_rays_mythic" else "hatch_rays_disc"),
		ImageColor3 = if mythic then WHITE else pre[2],
		ImageTransparency = if mythic then 1 else 0,
		ZIndex = 2,
	}, canvas)
	local spinRate = FX.SpinRate

	-- ===== The 3D scene =====
	local view = make("ViewportFrame", {
		Name = "Scene",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = FX.Ambient,
		LightColor = WHITE,
		LightDirection = Vector3.new(-0.6, -1.5, 1),
		ZIndex = 5,
		Active = false,
	}, canvas) :: ViewportFrame
	local camera = make("Camera", { FieldOfView = FX.FieldOfView }, view) :: Camera
	view.CurrentCamera = camera
	local LOOK = Vector3.new(0, FX.CameraTilt, -1).Unit
	local DISTANCE = FX.CameraDistance
	local perPixel = 2 * DISTANCE * math.tan(math.rad(FX.FieldOfView / 2)) / ch
	local function setCamera(zoom: number)
		camera.CFrame = CFrame.lookAt(LOOK * (DISTANCE / zoom), Vector3.zero)
	end
	setCamera(1)
	local baseCamera = CFrame.lookAt(LOOK * DISTANCE, Vector3.zero)
	local function worldAt(at: Vector2): Vector3
		return baseCamera.RightVector * ((at.X - cw / 2) * perPixel)
			+ baseCamera.UpVector * ((ch / 2 - at.Y) * perPixel)
	end

	-- The split egg, sized by its pixels on the design canvas
	local eggHeight = ctx.EggPx * perPixel
	local split = (petModels() :: Instance):FindFirstChild("EggSplit_" .. ctx.EggId):Clone() :: Model
	local _, box = split:GetBoundingBox()
	split:ScaleTo(split:GetScale() * eggHeight / box.Y)
	split:PivotTo(CFrame.new())
	local cutY = (split:GetAttribute("CutShare") or 0.1) * eggHeight
	local top = split:WaitForChild("Top") :: Model
	local bottom = split:WaitForChild("Bottom") :: Model
	top.WorldPivot = CFrame.new()
	bottom.WorldPivot = CFrame.new()
	local inners = {}
	for _, piece in split:GetDescendants() do
		if piece:IsA("BasePart") and string.find(piece.Name, "Inner") then
			piece.Material = Enum.Material.Neon
			piece.Color = FX.Colors.Crack
			table.insert(inners, piece)
		end
	end
	split.Parent = view
	local core = make("Part", {
		Name = "Core",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * eggHeight * FX.CoreSize,
		Material = Enum.Material.Neon,
		Color = FX.Colors.Crack,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		CastShadow = false,
		Transparency = 1,
	}, split) :: Part

	local egg = { Drop = 0, Zoom = 1, Angle = 0, Gap = 0 }
	local topFree = false
	local bottomFree = false
	local function drawEgg()
		local foot = CFrame.new(0, -eggHeight / 2 + egg.Drop, 0)
		local root = foot * CFrame.Angles(0, 0, math.rad(egg.Angle)) * CFrame.new(0, eggHeight / 2, 0)
		if not bottomFree then
			bottom:PivotTo(root)
		end
		if not topFree then
			top:PivotTo(root * CFrame.new(0, egg.Gap * eggHeight, 0))
		end
		core.CFrame = root * CFrame.new(0, cutY, 0)
		setCamera(egg.Zoom)
	end
	egg.Drop = ch * perPixel
	drawEgg()

	-- ===== Flat shapes =====
	-- Beams: tip at the crack, wide end outwards
	local beams = {}
	local crackAt = centre - Vector2.new(0, cutY / perPixel)
	for i = 1, FX.Beams do
		local angle = (i - 1) / FX.Beams * math.pi * 2 + math.random() * 0.35
		table.insert(beams, {
			Angle = angle,
			Reach = 0.75 + math.random() * 0.5,
			Label = make("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = SlKit.Icon("hatch_beam"),
				ImageColor3 = FX.Colors.Crack,
				ImageTransparency = FX.BeamFade,
				Visible = false,
				ZIndex = 7,
			}, canvas),
		})
	end
	local function setBeams(length: number, width: number, color: Color3?)
		for _, beam in beams do
			local dir = Vector2.new(math.cos(beam.Angle), math.sin(beam.Angle))
			local reach = length * beam.Reach
			local label = beam.Label
			label.Visible = reach > 1
			label.Position = UDim2.fromOffset(crackAt.X + dir.X * reach / 2, crackAt.Y + dir.Y * reach / 2)
			label.Size = UDim2.fromOffset(width, reach)
			label.Rotation = math.deg(math.atan2(-dir.X, dir.Y))
			if color then
				label.ImageColor3 = color
			end
		end
	end

	local function glint(at: Vector2, size: number, color: Color3?)
		local star = make("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = SlKit.Icon("hatch_star"),
			ImageColor3 = color or WHITE,
			Position = UDim2.fromOffset(at.X, at.Y),
			Size = UDim2.fromOffset(0, 0),
			ZIndex = 9,
		}, canvas)
		spawnAnim(FX.GlintTime, function(u)
			local k = math.sin(math.pi * u) ^ 0.6
			star.Size = UDim2.fromOffset(size * k, size * k)
			star.Rotation = 25 * u
			if u >= 1 then
				star:Destroy()
			end
		end)
	end

	-- Whole-picture shake: decays by itself
	local kick = 0
	local function addKick(amount: number)
		kick = math.max(kick, amount)
	end

	-- Pets standing in the scene
	local pets: { any } = {}
	local spin = 0
	local running = RunService.Heartbeat:Connect(function(dt)
		rays.Rotation += spinRate * dt
		spin += dt * math.pi * 2 / 6
		if kick > 0.2 then
			canvas.Position = UDim2.new(0.5, (math.random() - 0.5) * kick, 0.5, (math.random() - 0.5) * kick)
			kick *= math.exp(-dt * FX.KickDecay)
		elseif kick > 0 then
			kick = 0
			canvas.Position = UDim2.fromScale(0.5, 0.5)
		end
		for _, pet in pets do
			if pet.Shown then
				pet.Model:PivotTo(CFrame.new(pet.At) * CFrame.Angles(0, math.sin(spin) * pet.Sway, 0))
			end
		end
	end)

	-- ===== Prelude =====
	local function bigText(words: string, size: number, color: Color3, y: number)
		local text = SlKit.Text(canvas, words, size, color, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(cw / 2, y),
			Size = UDim2.fromOffset(cw, size * 1.3),
			ZIndex = 16,
		});
		(text:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = math.max(4, size * 0.07)
		local scale = make("UIScale", { Scale = 2.2 }, text) :: UIScale
		spawnAnim(0.22, function(u)
			scale.Scale = 2.2 - 1.2 * ease(u, Enum.EasingStyle.Back)
		end)
		return text
	end

	local function rock(peak: number, seconds: number)
		Sfx.Play("ReelTick", 0.9 + math.abs(peak) / 30)
		anim(seconds, function(u)
			egg.Angle = peak * math.sin(math.pi * u)
			drawEgg()
		end, true)
	end

	local function crack(index: number, color: Color3)
		Sfx.Play("HatchCrack", 0.95 + index * 0.15)
		core.Transparency = 0
		core.Color = color
		for _, piece in inners do
			piece.Color = color
		end
		local from = egg.Gap
		local to = FX.Gaps[index]
		addKick(FX.CrackKick * index)
		local side = if index % 2 == 0 then 1 else -1
		glint(crackAt + Vector2.new(side * ctx.EggPx * 0.26, 0), FX.GlintSize * (0.8 + index * 0.2), color)
		anim(0.07, function(u)
			egg.Gap = from + (to - from) * ease(u, Enum.EasingStyle.Quint)
			drawEgg()
		end, true)
	end

	local tease: TextLabel? = nil
	local function buildUp(seconds: number, color: Color3)
		local gapFrom = egg.Gap
		local ambientFrom = view.Ambient
		spawnAnim(seconds, function(u)
			if tease == nil and u > 0.05 and tier >= Mascots.RarityIndex("Epic") then
				tease = bigText(FX.TeaseText, if ctx.Phone then 40 else 54, WHITE, ch * 0.13)
			end
		end, true)
		local t = 0
		anim(seconds, function(u)
			t = u * seconds
			local rate = 18 + 42 * u
			local peak = 2 + 5 * u
			egg.Angle = math.sin(t * rate) * peak
			egg.Gap = gapFrom + (FX.Gaps[3] - gapFrom) * u
			-- the last stretch pulls in before the hit
			egg.Zoom = 1
				+ FX.Swell * math.sin(math.min(u / 0.8, 1) * math.pi * 0.5)
				- FX.Pull * math.max(0, (u - 0.8) / 0.2)
			view.Ambient = ambientFrom:Lerp(WHITE, u * u)
			spinRate = FX.SpinRate + FX.SpinRush * u
			setBeams(ctx.EggPx * (0.6 + 1.3 * u * u), (if ctx.Phone then 44 else 64) * (0.5 + u), color)
			addKick(FX.BuildKick * u)
			drawEgg()
		end, true)
	end

	function stage.Prelude()
		Sfx.Play("HatchCharge", if mythic then 0.8 else 1, if mythic then 0.8 else 0.6)
		spawnAnim(0.16, function(u)
			ctx.Dim.BackgroundTransparency = 1 - u
		end, true)
		if not mythic then
			spawnAnim(0.32, function(u)
				local size = diagonal * ease(u, Enum.EasingStyle.Back)
				rays.Size = UDim2.fromOffset(size, size)
			end, true)
		end
		-- the egg drops in and lands with weight
		local dropFrom = egg.Drop
		anim(FX.DropTime, function(u)
			egg.Drop = dropFrom * (1 - ease(u, Enum.EasingStyle.Bounce))
			drawEgg()
		end, true)
		addKick(FX.LandKick)
		wait(0.1)
		if mythic then
			for i = 1, 3 do
				Sfx.Play("OverchargeBlast", 1.2 + i * 0.1, 0.5)
				ctx.ShowBolts(true, ctx.BoltRed)
				wait(0.06)
				ctx.ShowBolts(true, ctx.BoltPink)
				wait(0.06)
				ctx.ShowBolts(false)
				rock(if i % 2 == 1 then -10 else 10, 0.12)
				wait(0.06)
			end
		end
		rock(-8, 0.12)
		wait(0.14)
		rock(14, 0.12)
		crack(1, FX.Colors.Crack)
		wait(0.14)
		rock(-22, 0.14)
		-- from the second crack on, the light is the real rarity
		crack(2, ctx.Bright)
		wait(0.04)
		buildUp(if mythic then FX.BuildTime * 2.4 else FX.BuildTime, ctx.Bright)
		Sfx.Play("HatchBurst", if mythic then 0.9 else 1.1, if mythic then 1 else 0.8)
		wait(FX.HitStop)
	end

	-- ===== Pets =====
	function stage.AddPet(col: { [string]: any }, model: Model)
		local cf, size = model:GetBoundingBox()
		model.WorldPivot = cf
		local target = (col.PetPx * col.Zoom * perPixel * FX.PetFill) / math.max(size.Y, size.X)
		local pet = {
			Model = model,
			Column = col,
			Base = model:GetScale() * target,
			Height = size.Y * target,
			At = worldAt(col.PetAt),
			ShellScale = ctx.EggPx * FX.ShellFill * perPixel / (size.Y * target),
			Sway = 0,
			Shown = false,
		}
		model:ScaleTo(pet.Base * 0.01)
		model:PivotTo(CFrame.new(0, -1000, 0))
		model.Parent = view
		table.insert(pets, pet)
		col.Hero = pet
	end

	local function popPet(pet: { [string]: any }, fromShell: boolean)
		pet.Shown = true
		local finish = pet.At
		local height = pet.Height * pet.ShellScale
		local inShell = Vector3.new(0, cutY + height * FX.ShellSit, 0)
		local start = Vector3.new(0, cutY - height * 0.6, 0)
		if fromShell then
			spawnAnim(FX.PopTime, function(u)
				local k = ease(u, Enum.EasingStyle.Back)
				pet.At = start:Lerp(inShell, k)
				pet.Model:ScaleTo(
					pet.Base * math.max(0.05, pet.ShellScale * (0.55 + 0.45 * ease(u, Enum.EasingStyle.Quint)))
				)
			end)
		else
			pet.At = finish
			spawnAnim(FX.PopTime, function(u)
				pet.Model:ScaleTo(pet.Base * math.max(0.05, ease(u, Enum.EasingStyle.Back)))
			end)
		end
		pet.Final = finish
	end

	-- ===== The hit =====
	local function shards(color: Color3)
		for i = 1, (if ctx.Phone then FX.Shards // 2 else FX.Shards) do
			local angle = -math.pi * (0.05 + 0.9 * math.random())
			local speed = (0.6 + math.random()) * ch * 0.75
			local size = (18 + math.random() * 34) * (if ctx.Phone then 0.8 else 1)
			local chip = make("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = SlKit.Icon("hatch_beam"),
				ImageColor3 = if i % 3 == 0 then WHITE else color,
				Size = UDim2.fromOffset(size, size * 1.25),
				Rotation = math.random(0, 360),
				ZIndex = 10,
			}, canvas)
			local turn = math.random(-720, 720)
			local vx, vy = math.cos(angle) * speed, math.sin(angle) * speed
			spawnAnim(0.7 + math.random() * 0.3, function(u)
				local t = u
				chip.Position = UDim2.fromOffset(crackAt.X + vx * t, crackAt.Y + vy * t + ch * 0.9 * t * t)
				chip.Rotation += turn / 60
				chip.ImageTransparency = math.max(0, (u - 0.8) / 0.2)
				if u >= 1 then
					chip:Destroy()
				end
			end)
		end
	end

	local function confetti(colors: { Color3 })
		for i = 1, (if ctx.Phone then FX.Confetti * 2 // 3 else FX.Confetti) do
			local depth = 0.6 + math.random() * 0.9 -- bigger = nearer, moves further
			local bit = make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = colors[i % #colors + 1],
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(22 * depth, 30 * depth),
				Rotation = math.random(0, 360),
				ZIndex = 18,
			}, canvas)
			local angle = math.random() * math.pi * 2
			local throw = (0.35 + math.random() * 0.75) * cw * 0.55 * depth
			local turn = math.random(-300, 300)
			local life = 1.3 + math.random() * 0.8
			spawnAnim(life, function(u)
				local out = ease(u, Enum.EasingStyle.Quint)
				bit.Position = UDim2.fromOffset(
					centre.X + math.cos(angle) * throw * out + math.sin(u * 7 + i) * 14,
					centre.Y + math.sin(angle) * throw * 0.7 * out + ch * 0.55 * u * u * depth
				)
				bit.Rotation += turn / 60
				bit.BackgroundTransparency = math.max(0, (u - 0.8) / 0.2)
				if u >= 1 then
					bit:Destroy()
				end
			end)
		end
	end

	local function shockwave(color: Color3)
		local wave = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(crackAt.X, crackAt.Y),
			ZIndex = 6,
		}, canvas)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, wave)
		local stroke = make("UIStroke", { Color = color, Thickness = 44 }, wave) :: UIStroke
		spawnAnim(0.42, function(u)
			local size = diagonal * ease(u, Enum.EasingStyle.Quint)
			wave.Size = UDim2.fromOffset(size, size)
			stroke.Thickness = 44 * (1 - u) + 2
			stroke.Transparency = u * u
			if u >= 1 then
				wave:Destroy()
			end
		end)
	end

	local function speedLines()
		for i = 1, FX.SpeedLines do
			local angle = (i - 1) / FX.SpeedLines * math.pi * 2 + math.random() * 0.2
			local dir = Vector2.new(math.cos(angle), math.sin(angle))
			local line = make("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = SlKit.Icon("hatch_beam"),
				ImageColor3 = WHITE,
				Rotation = math.deg(math.atan2(-dir.X, dir.Y)),
				ZIndex = 8,
			}, canvas)
			local length = diagonal * (0.35 + math.random() * 0.3)
			spawnAnim(0.3, function(u)
				local k = ease(u, Enum.EasingStyle.Quint)
				local reach = diagonal * 0.1 + diagonal * 0.35 * k
				line.Position = UDim2.fromOffset(crackAt.X + dir.X * reach, crackAt.Y + dir.Y * reach)
				line.Size = UDim2.fromOffset(36 * (1 - u) + 2, length * (1 - 0.4 * u))
				line.ImageTransparency = u * u
				if u >= 1 then
					line:Destroy()
				end
			end)
		end
	end

	-- Plays the hit. `shellPet` climbs out of the bottom half; the others pop where they stand, sides first.
	function stage.Burst(order: { any }, shellColumn: any)
		local flash: Frame = ctx.Flash
		flash.BackgroundColor3 = WHITE
		flash.BackgroundTransparency = 0
		spawnAnim(FX.FlashOut, function(u)
			flash.BackgroundTransparency = ease(u, Enum.EasingStyle.Quad)
		end)
		-- the backdrop snaps to the rarity's own colours under the flash
		local colors = FX.Colors[ctx.Rarity] or FX.Colors.Common
		ctx.Dim.BackgroundColor3 = colors[1]
		rays.Size = UDim2.fromOffset(diagonal, diagonal)
		if mythic then
			rays.ImageTransparency = 0 -- the striped disc, kept hidden until now
		else
			rays.ImageColor3 = colors[2]
		end
		ctx.Dim.BackgroundTransparency = 0
		spinRate = FX.SpinRate
		setBeams(0, 1)
		view.Ambient = FX.Ambient
		core.Transparency = 1
		for _, piece in inners do
			piece.Material = Enum.Material.SmoothPlastic
			piece.Color = ctx.Bright:Lerp(WHITE, FX.InsideFade)
		end
		egg.Angle, egg.Zoom, egg.Drop = 0, 1, 0
		drawEgg()
		spawnAnim(FX.PunchTime, function(u)
			setCamera(1 + FX.Punch * (1 - ease(u, Enum.EasingStyle.Quint)))
		end)
		addKick(FX.HitKick * (1 + tier * 0.12))
		shockwave(ctx.Bright)
		speedLines()
		shards(split:GetAttribute("ShellColor") or WHITE)
		confetti(FX.ConfettiColors)
		glint(crackAt, FX.GlintSize * 2.4)

		-- the top flies up and hangs, turning slowly (the thumbnail pose)
		topFree = true
		local fromTop = top:GetPivot()
		local hang = worldAt(Vector2.new(cw * FX.TopHang[1], ch * FX.TopHang[2]))
		stage.TopSpin = true
		task.spawn(function()
			local started = os.clock()
			while stage.TopSpin and ctx.Alive() do
				local u = math.min((os.clock() - started) / FX.TopFly * (ctx.Speed or 1), 1)
				local k = ease(u, Enum.EasingStyle.Quint)
				local drift = (os.clock() - started) * 0.18
				top:PivotTo(
					CFrame.new(fromTop.Position:Lerp(hang, k))
						* CFrame.Angles(FX.TopLean * k, 0.4 * k + drift, math.rad(FX.TopTurn) * k)
				)
				RunService.Heartbeat:Wait()
			end
		end)

		for i, col in order do
			task.delay((i - 1) * 0.15 / (ctx.Speed or 1), function()
				if ctx.Alive() then
					popPet(col.Hero, col == shellColumn)
				end
			end)
		end
		-- huge rarity word on big pulls
		if tier >= Mascots.RarityIndex("Legendary") then
			bigText(string.upper(ctx.Rarity) .. "!", if ctx.Phone then 72 else 112, WHITE, ch * 0.1)
		end
		if tease then
			tease:Destroy()
		end
	end

	-- After the held pose: the shell leaves, the pet floats up to its card
	function stage.Settle()
		local fromBottom = bottom:GetPivot()
		bottomFree = true
		spawnAnim(FX.SettleTime, function(u)
			bottom:PivotTo(
				fromBottom * CFrame.new(0, -ch * perPixel * ease(u, Enum.EasingStyle.Quad, Enum.EasingDirection.In), 0)
			)
		end)
		for _, pet in pets do
			if pet.Final and pet.At ~= pet.Final then
				local from = pet.At
				spawnAnim(FX.SettleTime, function(u)
					local k = ease(u, Enum.EasingStyle.Back)
					pet.At = from:Lerp(pet.Final, k)
					pet.Model:ScaleTo(pet.Base * math.max(0.05, pet.ShellScale + (1 - pet.ShellScale) * k))
				end)
			end
			pet.Sway = 0.7
		end
		-- the top half drifts away too
		stage.TopSpin = false
		local fromTop = top:GetPivot()
		spawnAnim(FX.SettleTime, function(u)
			top:PivotTo(
				fromTop
					+ Vector3.new(0, ch * perPixel * 0.8 * ease(u, Enum.EasingStyle.Quad, Enum.EasingDirection.In), 0)
			)
		end)
	end

	function stage.Close()
		stage.TopSpin = false
		running:Disconnect()
	end

	return stage
end

-- Loaded ahead so the first hatch doesn't play on blank images and untextured eggs
task.spawn(function()
	if Config.Ui.HatchHero ~= true then
		return
	end
	local models = ReplicatedStorage:WaitForChild("PetModels", 30)
	local list: { any } = {
		SlKit.Icon("hatch_rays_disc"),
		SlKit.Icon("hatch_rays_mythic"),
		SlKit.Icon("hatch_beam"),
		SlKit.Icon("hatch_star"),
	}
	if models then
		for _, child in models:GetChildren() do
			if string.sub(child.Name, 1, 9) == "EggSplit_" then
				table.insert(list, child)
			end
		end
	end
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(list)
	end)
end)

return HatchHero
