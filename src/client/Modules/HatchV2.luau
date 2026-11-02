-- UI overhaul V7 (UI_OVERHAUL_PLAN.md): the hatch sequence in the owner's new look ('Strike Legends Pets UI.html',
-- HatchStage frames F1-F9, T1 triple, M1-M5 mythic). A full-screen layer over the dimmed world; the egg and the pets
-- are 3D (ViewportFrames). Config.Ui.HatchV2 switches it on (MascotController calls Play instead of the stand scene).
-- Single 2.4 s: F1 egg pops in + world dims 90% · F2-F4 three shakes (-8, +14, -22 deg + scale 1.08) · F5 cracks ·
-- F6 cracks + wedge rays turn the rarity colour, egg swells · F7 white flash · F8 pet pops (1.15) + confetti ·
-- F9 pet rises, the card slides up, NEW! / x2 stamp drops on, OK + AUTO.
-- Triple 2.8 s: the same egg, then three pets with cards, rarest in the middle (bigger), sides pop 0.15 s apart.
-- Mythic 4.2 s: the screen goes dark, lightning flickers red / pink, 5 shakes up to 18 deg with pink light from the
-- cracks, a pink then white flash, striped rays turning (8 s loop) behind the pet.
-- Sizes are the design's pixels on a 1920 x 1080 canvas (phones: 1361 x 629, shown at ~0.62).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Mascots = require(Shared.Modules.Mascots)
local MascotView = require(script.Parent.MascotView)
local SlKit = require(script.Parent.SlKit)
local Sfx = require(script.Parent.Sfx)

local make = SlKit.Make
local hex = Color3.fromHex
local INK = SlKit.C.Ink
local WHITE = SlKit.C.White

local HatchV2 = {}

-- Rarity { colour, light, dark } (design R)
local R: { [string]: { Color3 } } = {
	Common = { hex("B8C2CC"), hex("E3E8EC"), hex("8A96A3") },
	Uncommon = { hex("4BE07A"), hex("A5F2B8"), hex("22A64A") },
	Rare = { hex("3AA8FF"), hex("8CCBFF"), hex("1666C4") },
	Epic = { hex("B45CFF"), hex("D9A8FF"), hex("7A2FC9") },
	Legendary = { hex("FFC93A"), hex("FFE680"), hex("E59A00") },
	Mythic = { hex("FF4F8B"), hex("FF9BBE"), hex("C42A5E") },
}
local STRIPES = { hex("FF4F8B"), hex("FFC93A"), hex("4BE07A"), hex("3AA8FF"), hex("B45CFF") }
local CONFETTI = { hex("FFC93A"), hex("FF4F8B"), hex("3AA8FF"), hex("4BE07A"), hex("FF8A3D"), WHITE }
local BG = hex("0F2442")
local BG_MYTHIC = hex("14060E")
local BOLT_RED, BOLT_PINK, BOLT_CORE = hex("FF3B4E"), hex("FF9BBE"), hex("FFD1E0")
local FLASH_PINK = hex("FF9BBE")

-- Crack lines on the egg (design svg, 256 x 256 box)
local CRACKS = {
	{ { 52, 128 }, { 78, 114 }, { 96, 134 }, { 118, 110 }, { 138, 132 }, { 160, 112 }, { 182, 130 }, { 206, 118 } },
	{ { 96, 134 }, { 92, 160 }, { 104, 176 } },
	{ { 160, 112 }, { 168, 90 }, { 160, 72 } },
}
-- One lightning bolt (100 x 300 box) and where the three sit (left %, top %, height px, rotation)
local BOLT = { { 60, 0 }, { 30, 120 }, { 62, 128 }, { 22, 300 } }
local BOLTS = { { 0.28, 0.14, 420, -12 }, { 0.66, 0.10, 460, 14 }, { 0.47, -0.04, 300, 4 } }

local function ease(u: number, style: Enum.EasingStyle, direction: Enum.EasingDirection?): number
	return TweenService:GetValue(math.clamp(u, 0, 1), style, direction or Enum.EasingDirection.Out)
end

local function rotate(v: Vector2, degrees: number): Vector2
	local a = math.rad(degrees)
	local c, s = math.cos(a), math.sin(a)
	return Vector2.new(v.X * c - v.Y * s, v.X * s + v.Y * c)
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function round(parent: Instance)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, parent)
end

-- A polyline as rounded bars (round caps + joins). layers = { { width, colour, z } } drawn in order.
type Poly = { Set: (self: Poly, lines: { { Vector2 } }) -> (), Paint: (self: Poly, layer: number, Color3, number?) -> (), Show: (self: Poly, boolean, number?) -> () }
local function newPoly(parent: Instance, count: { number }, layers: { { any } }): Poly
	local bars: { { Frame } } = {}
	for index, layer in layers do
		bars[index] = {}
		for _, segments in count do
			for _ = 1, segments do
				local bar = make("Frame", {
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = layer[2],
					ZIndex = layer[3],
					Visible = false,
				}, parent)
				round(bar)
				table.insert(bars[index], bar)
			end
		end
	end
	local poly = {}
	function poly.Set(_self, lines: { { Vector2 } })
		for index, layer in layers do
			local i = 0
			for _, points in lines do
				for p = 1, #points - 1 do
					i += 1
					local a, b = points[p], points[p + 1]
					local d = b - a
					local bar = bars[index][i]
					bar.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
					bar.Size = UDim2.fromOffset(d.Magnitude + layer[1], layer[1])
					bar.Rotation = math.deg(math.atan2(d.Y, d.X))
				end
			end
		end
	end
	function poly.Paint(_self, layer: number, color: Color3, width: number?)
		if width then
			layers[layer][1] = width
		end
		for _, bar in bars[layer] do
			bar.BackgroundColor3 = color
		end
	end
	function poly.Show(_self, on: boolean, transparency: number?)
		for _, list in bars do
			for _, bar in list do
				bar.Visible = on
				bar.BackgroundTransparency = transparency or 0
			end
		end
	end
	return poly :: any
end

-- A round disc of wedge rays (tinted per rarity over its dark colour; Mythic = the striped disc)
local function rayDisc(parent: Instance, rarity: string, back: Color3, z: number): Frame
	local disc = make("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = if rarity == "Mythic" then back else R[rarity][3],
		BorderSizePixel = 0,
		ZIndex = z,
		Visible = false,
	}, parent)
	round(disc)
	make("ImageLabel", {
		Name = "Wedges",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Image = SlKit.Icon(if rarity == "Mythic" then "hatch_rays_mythic" else "hatch_rays_disc"),
		ImageColor3 = if rarity == "Mythic" then WHITE else R[rarity][1],
		ZIndex = z,
	}, disc)
	return disc
end

local function label(parent: Instance, words: string, size: number, color: Color3, props: { [string]: any }?): TextLabel
	local text = SlKit.Text(parent, words, size, color, props)
	;(text:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = if size >= 30 then 3 else 2.5
	return text
end

-- Hard stripes across a chip (Mythic): 10 bands, 20 keypoints (the ColorSequence limit)
local function stripes(parent: GuiObject)
	local keys = {}
	for i = 0, 9 do
		local color = STRIPES[i % #STRIPES + 1]
		table.insert(keys, ColorSequenceKeypoint.new(i / 10, color))
		table.insert(keys, ColorSequenceKeypoint.new(if i == 9 then 1 else (i + 1) / 10 - 0.001, color))
	end
	parent.BackgroundColor3 = WHITE
	make("UIGradient", { Color = ColorSequence.new(keys) }, parent)
end

-- The result card under a pet: navy plate ringed in the rarity colour, rarity chip on top, name, coin / pin chips,
-- NEW! (red) or x2 (blue) stamp on the top-right corner
local function plateFor(parent: Instance, pet: { [string]: any }, width: number, z: number): (Frame, Frame?)
	local mascot = pet.Mascot
	local rr = R[mascot.Rarity] or R.Common
	local PH = 152
	local holder = make("Frame", {
		Name = "Plate",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, PH),
		ZIndex = z,
	}, parent)
	local lip = make("Frame", {
		Name = "Lip",
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
	}, holder)
	corner(lip, 16)
	local face = make("Frame", {
		Name = "Face",
		BackgroundColor3 = SlKit.C.Window,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
	}, holder)
	corner(face, 16)
	make("UIStroke", { Color = INK, Thickness = 3 }, face)
	local ring = make("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		ZIndex = z,
	}, face)
	corner(ring, 12)
	make("UIStroke", { Color = rr[1], Thickness = 4 }, ring)

	-- rarity chip on the top edge
	local chip = make("Frame", {
		Name = "Chip",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -20),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		BackgroundColor3 = rr[1],
		BorderSizePixel = 0,
		ZIndex = z + 2,
	}, holder)
	round(chip)
	make("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, chip)
	make("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18), PaddingTop = UDim.new(0, 3) }, chip)
	if mascot.Rarity == "Mythic" then
		stripes(chip)
	end
	label(chip, string.upper(mascot.Rarity), 22, WHITE, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		ZIndex = z + 3,
	})

	-- name
	local name = label(face, string.upper(mascot.Name), 36, WHITE, {
		Name = "PetName",
		Position = UDim2.fromOffset(12, 30),
		Size = UDim2.new(1, -24, 0, 40),
		ZIndex = z + 1,
	})
	name.TextScaled = false
	if name.TextBounds.X > width - 24 then
		name.TextSize = math.max(20, math.floor(36 * (width - 24) / name.TextBounds.X))
	end

	-- coin / pin chips
	local row = make("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 84),
		Size = UDim2.new(1, 0, 0, 46),
		ZIndex = z + 1,
	}, face)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
	}, row)
	local stats = Mascots.Stats(mascot)
	local shown = 0
	-- the pet's first two boosts (coins, pins, bag, speed), as on the PETS window cards
	local STAT = {
		Coins = { "cur_coin", hex("FFC93A") },
		Pins = { "cur_pin", WHITE },
		Bag = { "bag_01", WHITE },
		Speed = { "hud_throw", WHITE },
	}
	for _, statName in Config.PetStats.Order do
		local value = stats[statName] or 0
		local stat = { statName, (STAT[statName] or {})[1], (STAT[statName] or {})[2] }
		if value > 0 and stat[2] and shown < 2 then
			shown += 1
			local pill = make("Frame", {
				BackgroundColor3 = INK,
				BorderSizePixel = 0,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 46),
				LayoutOrder = shown,
				ZIndex = z + 1,
			}, row)
			round(pill)
			make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 16) }, pill)
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, pill)
			SlKit.Image(pill, stat[2], 34, { LayoutOrder = 1, ZIndex = z + 2 })
			label(pill, Mascots.PercentText(value), 24, stat[3], {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = 2,
				ZIndex = z + 2,
			})
		end
	end
	if shown == 0 then
		label(row, "NO BOOST", 22, hex("9FB3D1"), { Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
	end

	-- stamp: NEW! (red), x2 copies (blue), DELETED (red, the egg board's X)
	local word = if pet.Deleted
		then "DELETED"
		elseif pet.IsNew then "NEW!"
		elseif (pet.Copies or 0) > 1 then "x" .. pet.Copies
		else nil
	local stamp: Frame? = nil
	if word then
		local red = pet.Deleted or pet.IsNew
		local fill, dark = if red then hex("FF3B4E") else hex("2E9BFF"), if red then hex("B81E30") else hex("1666C4")
		stamp = make("Frame", {
			Name = "Stamp",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1, 0, 0, -6),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 50),
			BackgroundColor3 = dark,
			BorderSizePixel = 0,
			Rotation = 12,
			ZIndex = z + 4,
		}, holder)
		local s = stamp :: Frame
		corner(s, 14)
		make("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, s)
		make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, s)
		local top = make("Frame", {
			Name = "Face",
			BackgroundColor3 = fill,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-14, 0),
			Size = UDim2.new(1, 28, 1, -6),
			ZIndex = z + 4,
		}, s)
		corner(top, 14)
		label(s, word, 28, WHITE, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, -6),
			ZIndex = z + 5,
		})
		make("UIScale", { Name = "Pop" }, s)
	end
	return holder, stamp
end

-- opts: EggId, Pets = { { Mascot, IsNew, Deleted, Copies } } (first = the rarest, it plays the hatch),
-- Quick (play at Config.Ui.HatchV2Quick speed), Auto (AUTO is on), SkipFrom (seconds before a tap skips),
-- OnRevealed(), OnOk(), OnAuto(). Returns { Close(), SetAuto(on), Revealed() }.
function HatchV2.Play(opts: { [string]: any })
	local player = Players.LocalPlayer
	local pets = opts.Pets
	local main = pets[1].Mascot
	local mythic = false
	for _, pet in pets do
		if pet.Mascot.Rarity == "Mythic" then
			mythic = true
		end
	end
	local triple = #pets >= 3
	local leakRarity = main.Rarity
	local speed = if opts.Quick and not mythic then (Config.Ui.HatchV2Quick or 2) else 1
	local skipFrom = opts.SkipFrom or 0.7

	local gui = make("ScreenGui", {
		Name = "HatchV2UI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local view = gui.AbsoluteSize
	if view.X <= 0 then
		view = workspace.CurrentCamera.ViewportSize
	end
	local phone = view.Y < (Config.Ui.CompactHeight or 500)
	local design = if phone then Vector2.new(1361, 629) else Vector2.new(1920, 1080)
	local scale = math.min(view.X / design.X, view.Y / design.Y)
	local cw, ch = view.X / scale, view.Y / scale

	-- dim layer (also catches taps: skip, then close)
	local dim = make("TextButton", {
		Name = "Dim",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if mythic then BG_MYTHIC else BG,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, gui)
	local canvas = make("Frame", {
		Name = "Canvas",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(cw, ch),
		ZIndex = 2,
	}, gui)
	make("UIScale", { Scale = scale }, canvas)
	local flash = make("Frame", {
		Name = "Flash",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 60,
	}, gui)

	local alive = true
	local revealed = false
	local started = os.clock()
	local preludeOn = true
	local cleanups: { () -> () } = {}

	local function wait(seconds: number)
		local until_ = os.clock() + seconds / speed
		while alive and os.clock() < until_ do
			RunService.Heartbeat:Wait()
		end
	end
	-- runs fn(u) for u 0 -> 1 over seconds (design time); stops early when the scene goes or the prelude is skipped
	local function anim(seconds: number, fn: (number) -> (), prelude: boolean?)
		local from = os.clock()
		local length = math.max(seconds / speed, 1e-3)
		while alive and not (prelude and not preludeOn) do
			local u = math.min((os.clock() - from) / length, 1)
			fn(u)
			if u >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end
	local function spawnAnim(seconds: number, fn: (number) -> (), prelude: boolean?)
		task.spawn(anim, seconds, fn, prelude)
	end

	-- ===== The egg =====
	local eggSize = if phone then 300 else 380
	local eggCentre = Vector2.new(cw / 2, ch * 0.48)
	local egg = { Angle = 0, Scale = 0, Fade = 0 }
	local eggHolder = make("Frame", {
		Name = "Egg",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(eggCentre.X, eggCentre.Y),
		ZIndex = 5,
	}, canvas)
	local eggModel = MascotView.Egg(opts.EggId or "Alley", 4)
	local eggView, eggCamera = MascotView.Viewport(eggHolder, eggModel, 1.5) -- (fill counts the box diagonal; 1.5 = the egg fills the slot)
	eggView.ZIndex = 5
	eggView.Ambient = Color3.fromRGB(210, 210, 225)
	local cameraBase = eggCamera.CFrame
	local eggRays = rayDisc(canvas, leakRarity, if mythic then BG_MYTHIC else BG, 4)
	eggRays.Position = UDim2.fromOffset(eggCentre.X, eggCentre.Y)
	local segCount = {}
	for i, line in CRACKS do
		segCount[i] = #line - 1
	end
	local cracks = newPoly(canvas, segCount, { { 0, R[leakRarity][1], 6 }, { 7, INK, 7 } })
	local cracksOn = false

	local function drawEgg()
		local size = eggSize * egg.Scale
		eggHolder.Size = UDim2.fromOffset(size, size)
		eggView.ImageTransparency = egg.Fade
		eggCamera.CFrame = cameraBase * CFrame.Angles(0, 0, -math.rad(egg.Angle))
		eggRays.Size = UDim2.fromOffset(eggSize * 2.6 * egg.Scale, eggSize * 2.6 * egg.Scale)
		if cracksOn then
			local lines = {}
			for i, line in CRACKS do
				local points = {}
				for p, point in line do
					local local_ = (Vector2.new(point[1], point[2]) / 256 - Vector2.new(0.5, 0.5)) * size
					points[p] = eggCentre + rotate(local_, egg.Angle)
				end
				lines[i] = points
			end
			cracks:Set(lines)
		end
	end
	drawEgg()

	local function shake(peak: number, seconds: number, swell: number?)
		Sfx.Play("ReelTick", 0.9 + math.abs(peak) / 30)
		local base = egg.Scale
		anim(seconds, function(u)
			local k = math.sin(math.pi * u)
			egg.Angle = peak * k
			egg.Scale = base * (1 + ((swell or 1) - 1) * k)
			drawEgg()
		end, true)
	end

	-- ===== Lightning (mythic) =====
	local bolts = {}
	for _, spot in BOLTS do
		local h = spot[3]
		local w = h / 3
		local origin = Vector2.new(cw * spot[1], ch * spot[2])
		local centre = origin + Vector2.new(w / 2, h / 2)
		local points = {}
		for i, point in BOLT do
			local local_ = Vector2.new(point[1] / 100 * w, point[2] / 300 * h) - Vector2.new(w / 2, h / 2)
			points[i] = centre + rotate(local_, spot[4])
		end
		local bolt = newPoly(canvas, { #BOLT - 1 }, { { 30, INK, 8 }, { 20, BOLT_RED, 9 }, { 7, BOLT_CORE, 10 } })
		bolt:Set({ points })
		table.insert(bolts, bolt)
	end
	local function showBolts(on: boolean, color: Color3?)
		for _, bolt in bolts do
			if color then
				bolt:Paint(2, color)
			end
			bolt:Show(on)
		end
	end

	-- ===== Pets + cards (built hidden, placed where they end) =====
	local petSize = if phone then (if triple then 150 else 210) else (if triple then 230 else 330)
	local plateW = if phone then (if triple then 330 else 400) else (if triple then 360 else 440)
	local gap = if phone then 14 else 26
	local colGap = if phone then 28 else 60
	local padB = if phone then 96 else 150
	local PH = 160 -- plate + its lip
	local order = if triple then { pets[2], pets[1], pets[3] } else { pets[1] }
	type Column = { Pet: { [string]: any }, Big: boolean, Zoom: number, PetPx: number, Centre: Vector2, PetAt: Vector2, PlateAt: Vector2, Root: Frame, PetFrame: Frame, Rays: Frame, Plate: Frame, Stamp: Frame?, Model: Model }
	local columns: { Column } = {}
	local total = 0
	for i, pet in order do
		local big = triple and i == 2
		local zoom = if big then 1.12 else 1
		local px = math.round(petSize * (if big then 1.3 else 1))
		local colW = math.max(px, plateW) * zoom
		total += colW
		columns[i] = { Pet = pet, Big = big, Zoom = zoom, PetPx = px, Width = colW } :: any
	end
	total += colGap * (#order - 1)
	local x = (cw - total) / 2
	for _, col in columns do
		local width = (col :: any).Width
		local colH = (col.PetPx + gap + PH) * col.Zoom
		local top = (ch - padB - colH) / 2
		local cx = x + width / 2
		col.PetAt = Vector2.new(cx, top + col.PetPx * col.Zoom / 2)
		col.PlateAt = Vector2.new(cx, top + (col.PetPx + gap) * col.Zoom)
		x += width + colGap
		local mascot = col.Pet.Mascot
		local rr = R[mascot.Rarity] or R.Common
		col.Rays = rayDisc(canvas, mascot.Rarity, if mythic then BG_MYTHIC else BG, 3)
		local raysPx = col.PetPx * col.Zoom * (if triple then 2.2 else 3)
		col.Rays.Size = UDim2.fromOffset(raysPx, raysPx)
		col.PetFrame = make("Frame", {
			Name = "Pet",
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = rr[2],
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(col.PetPx * col.Zoom, col.PetPx * col.Zoom),
			ZIndex = 11,
			Visible = false,
		}, canvas)
		round(col.PetFrame)
		make("UIStroke", { Color = INK, Thickness = 6 }, col.PetFrame)
		make("UIScale", { Name = "Pop" }, col.PetFrame)
		col.Model = MascotView.Mascot(mascot, 2, false)
		local petView = MascotView.Viewport(col.PetFrame, col.Model, 0.85)
		petView.AnchorPoint = Vector2.new(0.5, 0.5)
		petView.Position = UDim2.fromScale(0.5, 0.46)
		petView.Size = UDim2.fromScale(1.2, 1.2)
		petView.ZIndex = 12
		col.Root = make("Frame", {
			Name = "Card",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(plateW, PH),
			ZIndex = 14,
			Visible = false,
		}, canvas)
		make("UIScale", { Scale = col.Zoom }, col.Root)
		local plate, stamp = plateFor(col.Root, col.Pet, plateW, 14)
		col.Plate = plate
		col.Stamp = stamp
	end
	-- the pets turn slowly (design: 3D slot spin 6 s loop)
	local spin = 0
	local spinConnection = RunService.RenderStepped:Connect(function(dt)
		spin += dt * math.pi * 2 / 6
		for _, col in columns do
			if col.PetFrame.Visible then
				col.Model:PivotTo(CFrame.Angles(0, math.sin(spin) * 0.7, 0))
			end
		end
	end)
	table.insert(cleanups, function()
		spinConnection:Disconnect()
	end)
	local function placePet(col: Column, at: Vector2)
		col.PetFrame.Position = UDim2.fromOffset(at.X, at.Y)
		col.Rays.Position = UDim2.fromOffset(at.X, at.Y)
	end

	-- buttons
	local buttons = make("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -(if phone then 18 else 60)),
		Size = UDim2.fromOffset(460, 78),
		ZIndex = 20,
		Visible = false,
	}, canvas)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 20),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, buttons)
	local okButton = SlKit.Button(buttons, { Name = "Ok", Text = "OK", Paint = "Green", Size = UDim2.fromOffset(220, 72), TextSize = 30, ZIndex = 20 })
	okButton.Holder.LayoutOrder = 1
	local autoButton = SlKit.Button(buttons, { Name = "Auto", Text = "AUTO", Paint = "Blue", Size = UDim2.fromOffset(220, 72), TextSize = 30, ZIndex = 20 })
	autoButton.Holder.LayoutOrder = 2
	autoButton.Holder.Visible = opts.OnAuto ~= nil
	local autoOn = opts.Auto == true
	local function paintAuto()
		autoButton:SetText(if autoOn then "STOP AUTO" else "AUTO")
		autoButton:Repaint(if autoOn then "Red" else "Blue")
	end
	paintAuto()
	okButton.Holder.Activated:Connect(function()
		if opts.OnOk then
			opts.OnOk()
		end
	end)
	autoButton.Holder.Activated:Connect(function()
		if opts.OnAuto then
			opts.OnAuto()
		end
	end)
	-- during AUTO the button stays up so it can be stopped
	if autoOn then
		buttons.Visible = true
		okButton.Holder.Visible = false
	end

	-- confetti: 46 bits falling 300 px (design F8)
	local function confetti()
		local count = 46
		for i = 1, count do
			local bit = make("Frame", {
				BackgroundColor3 = CONFETTI[i % #CONFETTI + 1],
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(if phone then 12 else 16, if phone then 20 else 26),
				Rotation = math.random(0, 360),
				ZIndex = 18,
			}, canvas)
			corner(bit, 4)
			make("UIStroke", { Color = INK, Thickness = 2 }, bit)
			local x0 = (math.random() * 0.96 + 0.02) * cw
			local y0 = (math.random() * (if revealed then 0.4 else 0.5) + 0.03) * ch - 120
			local turn = math.random(-240, 240)
			local life = 1.2 + math.random() * 0.8
			spawnAnim(life, function(u)
				bit.Position = UDim2.fromOffset(x0 + math.sin(u * 6 + i) * 18, y0 + 300 * ease(u, Enum.EasingStyle.Quad))
				bit.Rotation += turn / 60
				bit.BackgroundTransparency = math.max(0, (u - 0.75) / 0.25)
				if u >= 1 then
					bit:Destroy()
				end
			end)
		end
	end

	-- ===== The reveal (F8 + F9 / T1 / M5) =====
	local function reveal()
		if revealed or not alive then
			return
		end
		revealed = true
		preludeOn = false
		eggHolder.Visible = false
		eggRays.Visible = false
		cracks:Show(false)
		showBolts(false)
		dim.BackgroundTransparency = if mythic then 0 else 0.1
		local tier = Mascots.RarityIndex(main.Rarity)
		Sfx.Play(if tier >= Mascots.RarityIndex("Epic") then "RevealBig" else "Reveal")
		if tier >= Mascots.RarityIndex("Legendary") then
			Sfx.Play("HatchFanfare")
		end
		if mythic then
			Sfx.Play("Firework", 1, 0.8)
		end
		-- pets pop (single: at the egg; triple: in place, sides 0.15 s apart, the middle last)
		local popOrder = if triple then { columns[1], columns[3], columns[2] } else { columns[1] }
		for i, col in popOrder do
			task.delay((i - 1) * 0.15 / speed, function()
				if not alive then
					return
				end
				local start = if triple then col.PetAt else eggCentre
				placePet(col, start)
				col.PetFrame.Visible = true
				col.Rays.Visible = true
				local pop = col.PetFrame:FindFirstChild("Pop") :: UIScale
				anim(0.3, function(u)
					local s = ease(u, Enum.EasingStyle.Back) * 1.15
					pop.Scale = s
					local rays = col.Rays
					rays.Size = UDim2.fromOffset(
						col.PetPx * col.Zoom * (if triple then 2.2 else 3) * math.min(s, 1),
						col.PetPx * col.Zoom * (if triple then 2.2 else 3) * math.min(s, 1)
					)
				end)
			end)
		end
		confetti()
		-- rays turn (Mythic striped: 8 s loop; the rest slower)
		for _, col in columns do
			table.insert(cleanups, SlKit.Spin(col.Rays, if col.Pet.Mascot.Rarity == "Mythic" then 8 else 20))
		end
		wait(if triple then 0.7 else 0.3)
		if not alive then
			return
		end
		-- F9: pet rises into place (scale back to 1), card slides up, stamp drops on, buttons
		for _, col in columns do
			local from = if triple then col.PetAt else eggCentre
			local pop = col.PetFrame:FindFirstChild("Pop") :: UIScale
			spawnAnim(0.25, function(u)
				local k = ease(u, Enum.EasingStyle.Back)
				placePet(col, from:Lerp(col.PetAt, k))
				pop.Scale = 1.15 - 0.15 * ease(u, Enum.EasingStyle.Quad)
			end)
			col.Root.Visible = true
			spawnAnim(0.25, function(u)
				local k = ease(u, Enum.EasingStyle.Back)
				col.Root.Position = UDim2.fromOffset(col.PlateAt.X, col.PlateAt.Y + 80 * (1 - k))
			end)
			local stamp = col.Stamp
			if stamp then
				local pop2 = stamp:FindFirstChild("Pop") :: UIScale
				pop2.Scale = 2
				stamp.Visible = false
				task.delay(0.15 / speed, function()
					if not alive then
						return
					end
					stamp.Visible = true
					Sfx.Play("Tap", 1.3, 0.7)
					anim(0.2, function(u)
						pop2.Scale = 2 - ease(u, Enum.EasingStyle.Quint)
						stamp.Rotation = 12 * ease(u, Enum.EasingStyle.Quint)
					end)
				end)
			end
		end
		buttons.Visible = true
		okButton.Holder.Visible = true
		for _, holder in { okButton.Holder, autoButton.Holder } do
			if holder.Visible and not autoOn then
				SlKit.PopIn(holder, 0.22)
			end
		end
		if opts.OnRevealed then
			task.delay(0.25 / speed, function()
				if alive then
					opts.OnRevealed()
				end
			end)
		end
	end

	local function doFlash(color: Color3, inTime: number, outTime: number, thenColor: Color3?)
		flash.BackgroundColor3 = color
		anim(inTime, function(u)
			flash.BackgroundTransparency = 1 - u
		end)
		if thenColor then
			flash.BackgroundColor3 = thenColor
		end
		spawnAnim(outTime, function(u)
			flash.BackgroundTransparency = ease(u, Enum.EasingStyle.Sine)
		end)
	end

	-- ===== The prelude (egg) =====
	local function leak(color: Color3)
		cracks:Paint(1, color, 16)
		cracks:Paint(2, WHITE)
		eggRays.Visible = true
		drawEgg()
		cracks:Show(true)
	end
	local function single()
		-- F1 0.00-0.35: egg pops in, world dims to 90%
		Sfx.Play("HatchCharge", 1, 0.6)
		spawnAnim(0.35, function(u)
			dim.BackgroundTransparency = 1 - 0.9 * u
		end, true)
		anim(0.35, function(u)
			egg.Scale = ease(u, Enum.EasingStyle.Back)
			drawEgg()
		end, true)
		-- F2-F4: shakes at 0.50, 0.80, 1.10
		wait(0.15)
		shake(-8, 0.12)
		wait(0.18)
		shake(14, 0.12)
		wait(0.18)
		shake(-22, 0.14, 1.08)
		-- F5 1.35: cracks
		wait(0.11)
		cracksOn = true
		drawEgg()
		Sfx.Play("HatchCrack", 1)
		anim(0.1, function(u)
			cracks:Show(true, 1 - u)
		end, true)
		-- F6 1.50-1.90: light leak, egg swells to 1.05
		wait(0.05)
		leak(R[leakRarity][1])
		Sfx.Play("HatchCrack", 1.25)
		anim(0.4, function(u)
			egg.Scale = 1 + 0.05 * ease(u, Enum.EasingStyle.Sine)
			drawEgg()
		end, true)
		-- F7 1.90: white flash
		Sfx.Play("HatchBurst", 1.1, 0.8)
		doFlash(WHITE, 0.08, 0.3)
		egg.Fade = 0.7
		drawEgg()
		wait(0.12)
	end
	local function mythicPrelude()
		-- M1 0.00-1.10: the screen goes dark, hold
		Sfx.Play("HatchCharge", 0.8, 0.8)
		spawnAnim(0.6, function(u)
			dim.BackgroundTransparency = 1 - ease(u, Enum.EasingStyle.Sine)
		end, true)
		anim(0.35, function(u)
			egg.Scale = ease(u, Enum.EasingStyle.Back)
			drawEgg()
		end, true)
		wait(0.75)
		-- M2 1.10-2.00: lightning flickers red <-> pink 3 times, the egg rocks +-10
		for i = 1, 3 do
			Sfx.Play("OverchargeBlast", 1.2 + i * 0.1, 0.5)
			showBolts(true, BOLT_RED)
			wait(0.06)
			showBolts(true, BOLT_PINK)
			wait(0.06)
			showBolts(false)
			shake(if i % 2 == 1 then -10 else 10, 0.12)
			wait(0.06)
		end
		-- M3 2.00-3.40: 5 shakes up to 18 deg, pink light from the cracks
		cracksOn = true
		for i, peak in { -8, 11, -13, 15, -18 } do
			if i == 1 then
				drawEgg()
				cracks:Show(true)
				Sfx.Play("HatchCrack", 0.9)
			elseif i == 2 then
				leak(R.Mythic[1])
				Sfx.Play("HatchCrack", 1.2)
			end
			shake(peak, 0.14, 1 + i * 0.02)
			wait(0.14)
		end
		-- M4 3.40-3.90: pink flash, then white
		Sfx.Play("HatchBurst", 0.9, 1)
		doFlash(FLASH_PINK, 0.1, 0.5, WHITE)
		egg.Fade = 1
		drawEgg()
		wait(0.3)
	end

	local prelude = task.spawn(function()
		if mythic then
			mythicPrelude()
		else
			single()
		end
		if alive and preludeOn then
			reveal()
		end
	end)

	dim.Activated:Connect(function()
		if not alive then
			return
		end
		if revealed then
			if not autoOn and opts.OnOk then
				opts.OnOk()
			end
		elseif os.clock() - started >= skipFrom then
			preludeOn = false
			pcall(task.cancel, prelude)
			flash.BackgroundTransparency = 1
			task.spawn(reveal)
		end
	end)

	local handle = {}
	function handle.Close()
		if not alive then
			return
		end
		alive = false
		pcall(task.cancel, prelude)
		for _, clean in cleanups do
			pcall(clean)
		end
		gui:Destroy()
	end
	function handle.SetAuto(on: boolean)
		autoOn = on
		paintAuto()
		if not on and revealed then
			okButton.Holder.Visible = true
		end
	end
	function handle.Revealed(): boolean
		return revealed
	end
	return handle
end

return HatchV2
