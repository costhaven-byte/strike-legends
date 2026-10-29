-- The loading screen (owner's design, claude.ai canvas "Strike Legends loading screen", 2026-10-29): a neon alley
-- background, turning light rays, a burst with 6 pins flying out, the gold STRIKE LEGENDS logo, a hero ball, sparkles,
-- the RIZZO'S sign, a loading bar that is a mini lane (gold fill, a ball riding its head toward 3 pins) and a tip pill.
-- Art = the design's layers as PNGs (assets/loading, rendered 1:1 from the canvas). Desktop numbers are for a 1920x1080
-- screen; screens under 500 px tall use the design's phone layout (844x390). Everything else scales with the screen.
--
-- local screen = LoadingScreen.Show(gui, tip)   -- builds it and plays the pop-in
-- screen.SetProgress(0..1)                      -- bar only moves forward
-- screen.Finish()                               -- STRIKE! at 100%, then fades out (yields ~0.4 s, fade runs on)
local TweenService = game:GetService("TweenService")

local Modules = script.Parent
local UiKit = require(Modules.UiKit)
local Sfx = require(Modules.Sfx)

local C = UiKit.C
local hex = UiKit.Hex
local Make = UiKit.Make

-- The rendered layers (uploaded 2026-10-29; files in assets/loading)
local IMG = {
	Alley = "rbxassetid://89321231528176",
	LaneGlow = "rbxassetid://79294510025989",
	Rays = "rbxassetid://128971488001438",
	Burst = "rbxassetid://73414175056896",
	Sign = "rbxassetid://106668453227399",
	Streak = "rbxassetid://138191857515366",
	Ball = "rbxassetid://92989712738387",
	Pin = "rbxassetid://109423494574337",
	Sparkle = "rbxassetid://118461517268178",
	Logo = "rbxassetid://106764692309080",
}

local GOLD = hex("FFC93A")
local CYAN = hex("2BE4FF")
local PINK = hex("FF4FB0")
local SHINE = hex("FFF6C2")
local NAVY = hex("070B1E")

-- Layout per screen kind: x, y = centre in % of the screen; w, h = design px (desktop 1920x1080 / phone 844x390)
local LAYOUT = {
	Desktop = {
		Design = Vector2.new(1920, 1080),
		Rays = { 50, 31, 1300 },
		Burst = { 50, 52, 620 },
		Sign = { 86, 17, 380, 190 },
		Streak = { 84, 74, 420, 84 }, -- x in px from the left edge
		Ball = { 13, 74, 300 },
		Logo = { 50, 31, 1038, 462 }, -- the PNG has 20 design px of room round the logo
		Pins = {
			{ 27, 47, 150, 390, -38 },
			{ 73, 45, 150, 390, 32 },
			{ 36, 64, 60, 156, -72 },
			{ 64, 66, 60, 156, 66 },
			{ 43, 58, 56, 146, -24 },
			{ 57, 59, 56, 146, 28 },
		},
		Sparks = {
			{ 22, 20, 56, SHINE },
			{ 79, 30, 44, CYAN },
			{ 31, 72, 36, GOLD },
			{ 68, 74, 48, SHINE },
			{ 12, 44, 40, PINK },
			{ 90, 58, 34, CYAN },
			{ 58, 9, 38, GOLD },
			{ 45, 69, 28, C.White },
		},
		Bar = { 50, 82, 1 }, -- the group is built at desktop size; 3rd = its scale
		Tip = { 50, 92.5, 1 },
	},
	Phone = {
		Design = Vector2.new(844, 390),
		Rays = { 50, 34, 700 },
		Burst = { 50, 58, 260 },
		Sign = { 90, 20, 150, 75 },
		Streak = { 38, 80, 190, 38 },
		Ball = { 10, 80, 130 },
		Logo = { 50, 34, 457, 203 },
		Pins = {
			{ 24, 52, 58, 150, -38 },
			{ 76, 50, 58, 150, 32 },
			{ 31, 61, 26, 68, -72 },
			{ 69, 62, 26, 68, 66 },
			{ 40, 57, 24, 62, -24 },
			{ 60, 57, 24, 62, 28 },
		},
		Sparks = {
			{ 22, 20, 24, SHINE },
			{ 80, 34, 20, CYAN },
			{ 30, 74, 16, GOLD },
			{ 70, 70, 20, SHINE },
			{ 14, 46, 18, PINK },
			{ 58, 13, 16, GOLD },
		},
		Bar = { 50, 76, 500 / 960 },
		Tip = { 50, 90.5, 14 / 26 },
	},
}

-- The bar, in desktop design px (the whole group gets one UIScale)
local BAR_W, BAR_H = 960, 92
local TRACK_X, TRACK_W, TRACK_H = 14, 804, 54
local ROW_H, ROW_GAP = 46, 10

local LoadingScreen = {}

local function tween(
	object: Instance,
	time: number,
	props: { [string]: any },
	style: Enum.EasingStyle?,
	dir: Enum.EasingDirection?,
	repeats: number?,
	reverses: boolean?
)
	local t = TweenService:Create(
		object,
		TweenInfo.new(
			time,
			style or Enum.EasingStyle.Quad,
			dir or Enum.EasingDirection.Out,
			repeats or 0,
			reverses or false
		),
		props
	)
	t:Play()
	return t
end

local function image(parent: Instance, name: string, id: string, z: number): ImageLabel
	return Make("ImageLabel", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		Image = id,
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = z,
	}, parent) :: ImageLabel
end

function LoadingScreen.Show(gui: ScreenGui, tipText: string)
	local alive = true
	local exiting = false
	local loops = {} -- repeating tweens, cancelled on exit

	local root = Make("Frame", {
		Name = "LoadingScreen",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 5,
	}, gui) :: Frame
	-- Everything sits in one layer above whatever else the screen holds (the intro's SKIP stays on top at 10). The
	-- navy backing is its own bottom layer so the art draws over it with Global ZIndex too.
	Make("Frame", {
		Name = "Backing",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = NAVY,
		BorderSizePixel = 0,
		ZIndex = 0,
	}, root)
	local layer =
		Make("Frame", { Name = "Layer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }, root)

	-- ===== Background =====
	local bgHolder = Make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, layer) :: Frame
	local alley = image(bgHolder, "BG_Alley", IMG.Alley, 1)
	alley.ScaleType = Enum.ScaleType.Crop
	alley.Position = UDim2.fromScale(0.5, 0.5)
	alley.Size = UDim2.fromScale(1, 1)
	alley.ImageTransparency = 1
	local laneGlow = image(bgHolder, "BG_LaneGlow", IMG.LaneGlow, 2)
	laneGlow.ScaleType = Enum.ScaleType.Crop
	laneGlow.Position = UDim2.fromScale(0.5, 0.5)
	laneGlow.Size = UDim2.fromScale(1, 1)
	laneGlow.ImageTransparency = 1

	local rays = image(layer, "FX_Rays", IMG.Rays, 3)
	rays.ImageTransparency = 1
	local burst = image(layer, "FX_Burst", IMG.Burst, 4)
	local burstScale = UiKit.ScaleOf(burst)
	burstScale.Scale = 0
	local sign = image(layer, "Sign_Rizzo", IMG.Sign, 4)
	local streak = image(layer, "FX_Streak", IMG.Streak, 5)
	streak.Rotation = -14
	streak.ImageTransparency = 0.2
	local heroBall = image(layer, "Ball_Hero", IMG.Ball, 6)

	local pins = {}
	for i = 1, 6 do
		local pin = image(layer, "Pin_Fly", IMG.Pin, 7)
		pin.ImageTransparency = 1
		pins[i] = pin
	end
	local sparks = {}
	for i = 1, 8 do
		local s = image(layer, "FX_Sparkle", IMG.Sparkle, 8)
		UiKit.ScaleOf(s).Scale = 0
		sparks[i] = s
	end

	local logo = image(layer, "Logo_Main", IMG.Logo, 10)
	local logoScale = UiKit.ScaleOf(logo)
	logo.ImageTransparency = 1

	-- ===== Loading group: LOADING... + percent over the mini lane =====
	local group = Make("Frame", {
		Name = "LoadingGroup",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(BAR_W, ROW_H + ROW_GAP + BAR_H),
		BackgroundTransparency = 1,
		ZIndex = 11,
	}, layer) :: Frame
	local groupScale = Make("UIScale", {}, group) :: UIScale
	local groupOffset =
		Make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 11 }, group) :: Frame

	local loadingText = UiKit.Text(groupOffset, "LOADING", UiKit.Head, 34, GOLD, 3)
	loadingText.RichText = true
	loadingText.Position = UDim2.fromOffset(12, 0)
	loadingText.Size = UDim2.new(0.6, 0, 0, ROW_H)
	loadingText.TextXAlignment = Enum.TextXAlignment.Left
	loadingText.TextYAlignment = Enum.TextYAlignment.Bottom
	loadingText.ZIndex = 11
	local pctText = UiKit.Text(groupOffset, "0%", UiKit.Num, 30, C.White, 3)
	pctText.AnchorPoint = Vector2.new(1, 0)
	pctText.Position = UDim2.new(1, -12, 0, 0)
	pctText.Size = UDim2.new(0.4, 0, 0, ROW_H)
	pctText.TextXAlignment = Enum.TextXAlignment.Right
	pctText.TextYAlignment = Enum.TextYAlignment.Bottom
	pctText.ZIndex = 11

	local bar = Make("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(0, ROW_H + ROW_GAP),
		Size = UDim2.fromOffset(BAR_W, BAR_H),
		BackgroundTransparency = 1,
		ZIndex = 11,
	}, groupOffset) :: Frame
	-- lip under the frame (8 px of card lip, ink round it)
	local lip = Make("Frame", {
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = hex("120B26"),
		BorderSizePixel = 0,
		ZIndex = 11,
	}, bar)
	UiKit.Corner(lip, 26)
	UiKit.Outline(lip, C.Ink, 5)
	local frame = Make("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 12,
	}, bar)
	UiKit.Corner(frame, 26)
	UiKit.Outline(frame, C.Ink, 5)
	Make("UIGradient", { Rotation = 90, Color = ColorSequence.new(hex("2C2154"), hex("1E143C")) }, frame)
	local frameShine = Make("Frame", {
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 0, 12),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.88,
		BorderSizePixel = 0,
		ZIndex = 13,
	}, frame)
	UiKit.Corner(frameShine, 10)
	-- soft gold glow round the pins at the end of the lane
	local pinGlow = image(frame, "PinGlow", IMG.Burst, 13)
	pinGlow.Position = UDim2.fromOffset(882, 41)
	pinGlow.Size = UDim2.fromOffset(140, 110)
	pinGlow.ScaleType = Enum.ScaleType.Stretch
	pinGlow.ImageTransparency = 0.55

	local track = Make("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(TRACK_X, 14),
		Size = UDim2.fromOffset(TRACK_W, TRACK_H),
		BackgroundColor3 = hex("0E1433"),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 13,
	}, frame) :: Frame
	UiKit.Corner(track, 16)
	UiKit.Outline(track, C.Ink, 3)
	for x = 38, TRACK_W, 41 do -- lane boards
		Make("Frame", {
			Position = UDim2.fromOffset(x, 0),
			Size = UDim2.new(0, 3, 1, 0),
			BackgroundColor3 = hex("17204A"),
			BorderSizePixel = 0,
			ZIndex = 13,
		}, track)
	end
	local fill = Make("Frame", {
		Name = "Fill",
		Size = UDim2.fromOffset(40, TRACK_H),
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		ZIndex = 14,
	}, track) :: Frame
	UiKit.Corner(fill, 12)
	Make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, hex("FFF0A0")),
			ColorSequenceKeypoint.new(0.5, GOLD),
			ColorSequenceKeypoint.new(1, hex("E39A00")),
		}),
	}, fill)
	local fillShine = Make("Frame", {
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.new(1, -16, 0, 10),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 15,
	}, fill)
	UiKit.Corner(fillShine, 8)

	local barPins = {}
	for i, x in { 840, 872, 904 } do
		local pin = image(frame, "Bar_Pin", IMG.Pin, 15)
		pin.Position = UDim2.fromOffset(x + 14, 6 + 36)
		pin.Size = UDim2.fromOffset(28, 72)
		barPins[i] = pin
	end
	local barBall = image(frame, "Bar_Ball", IMG.Ball, 16)
	barBall.Size = UDim2.fromOffset(64, 64)
	barBall.Position = UDim2.fromOffset(TRACK_X + 40 - 32 + 32, 9 + 32)

	local strikeText = UiKit.Text(frame, "STRIKE!", UiKit.Head, 64, GOLD, 4)
	strikeText.AnchorPoint = Vector2.new(0.5, 0.5)
	strikeText.Position = UDim2.new(1, -100, 0, -56)
	strikeText.Size = UDim2.fromOffset(300, 80)
	strikeText.Rotation = -8
	strikeText.ZIndex = 17
	strikeText.Visible = false
	local strikeScale = UiKit.ScaleOf(strikeText)

	-- ===== Tip pill =====
	local tip = Make("Frame", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = NAVY,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		ZIndex = 11,
	}, layer) :: Frame
	UiKit.Corner(tip, 999)
	local tipStroke = UiKit.Outline(tip, C.Ink, 3)
	local tipScale = Make("UIScale", {}, tip) :: UIScale
	Make("UIPadding", {
		PaddingLeft = UDim.new(0, 30),
		PaddingRight = UDim.new(0, 30),
		PaddingTop = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
	}, tip)
	Make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tip)
	local tipLabel = UiKit.Text(tip, "TIP:", UiKit.Head, 28, CYAN, 2)
	tipLabel.AutomaticSize = Enum.AutomaticSize.X
	tipLabel.Size = UDim2.fromOffset(0, 36)
	tipLabel.LayoutOrder = 1
	tipLabel.ZIndex = 12
	local tipBody = UiKit.Text(tip, (tipText:gsub("^TIP:%s*", "")), UiKit.Body, 26, C.White, 2)
	tipBody.AutomaticSize = Enum.AutomaticSize.X
	tipBody.Size = UDim2.fromOffset(0, 36)
	tipBody.LayoutOrder = 2
	tipBody.ZIndex = 12

	local flash = Make("Frame", {
		Name = "FX_Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 20,
	}, layer)

	-- ===== Layout: positions follow the screen kind; px sizes scale with the screen =====
	local L = LAYOUT.Desktop
	local k = 1
	local function at(object: GuiObject, x: number, y: number, w: number, h: number?)
		object.Position = UDim2.fromScale(x / 100, y / 100)
		object.Size = UDim2.fromOffset(w * k, (h or w) * k)
	end
	local pinHome = {} -- each flying pin's resting spot
	local sparkHome = {}
	local function layout()
		local area = gui.AbsoluteSize
		if area.X <= 0 then
			return
		end
		L = if area.Y < 500 then LAYOUT.Phone else LAYOUT.Desktop
		k = math.min(area.X / L.Design.X, area.Y / L.Design.Y)
		at(rays, L.Rays[1], L.Rays[2], L.Rays[3])
		at(burst, L.Burst[1], L.Burst[2], L.Burst[3])
		at(sign, L.Sign[1], L.Sign[2], L.Sign[3], L.Sign[4])
		sign.Rotation = 4
		streak.Position = UDim2.new(0, L.Streak[1] * k, L.Streak[2] / 100, 0)
		streak.Size = UDim2.fromOffset(L.Streak[3] * k, L.Streak[4] * k)
		at(heroBall, L.Ball[1], L.Ball[2], L.Ball[3])
		at(logo, L.Logo[1], L.Logo[2], L.Logo[3], L.Logo[4])
		for i, pin in pins do
			local p = L.Pins[i]
			pinHome[i] = p
			pin.Size = UDim2.fromOffset(p[3] * k, p[4] * k)
		end
		for i, s in sparks do
			local d = L.Sparks[i]
			s.Visible = d ~= nil
			if d then
				sparkHome[i] = d
				s.Size = UDim2.fromOffset(d[3] * k, d[3] * k)
				s.ImageColor3 = d[4]
			end
		end
		group.Position = UDim2.fromScale(L.Bar[1] / 100, L.Bar[2] / 100)
		groupScale.Scale = k * L.Bar[3]
		tip.Position = UDim2.fromScale(L.Tip[1] / 100, L.Tip[2] / 100)
		tipScale.Scale = k * L.Tip[3]
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()

	local function pinSpot(i: number, out: number): UDim2
		local p = pinHome[i]
		local c = L.Burst
		return UDim2.fromScale((c[1] + (p[1] - c[1]) * out) / 100, (c[2] + (p[2] - c[2]) * out) / 100)
	end

	-- ===== Pop in (storyboard frame 1) =====
	tween(alley, 0.25, { ImageTransparency = 0 })
	tween(laneGlow, 0.25, { ImageTransparency = 0.1 })
	bgHolder.Size = UDim2.fromScale(1, 1)
	tween(bgHolder, 9, { Size = UDim2.fromScale(1.04, 1.04) }, Enum.EasingStyle.Linear)
	group.Visible = false
	tip.Visible = false

	task.delay(0.1, function()
		burstScale.Scale = 0
		tween(burstScale, 0.22, { Scale = 1.25 }, Enum.EasingStyle.Back).Completed:Once(function()
			tween(burstScale, 0.13, { Scale = 1 }, Enum.EasingStyle.Quad)
		end)
		flash.BackgroundTransparency = 0.7
		tween(flash, 0.25, { BackgroundTransparency = 1 })
	end)
	task.delay(0.2, function()
		logo.ImageTransparency = 0
		logoScale.Scale = 1.6
		tween(logoScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		tween(rays, 0.4, { ImageTransparency = 0.4 })
	end)
	task.delay(0.45, function()
		for i, pin in pins do
			pin.Position = pinSpot(i, 0)
			pin.Rotation = 0
			pin.ImageTransparency = 0
			tween(pin, 0.4, { Position = pinSpot(i, 1), Rotation = pinHome[i][5] })
		end
	end)
	-- Loading group slides up 60 px and fades in; the tip rises 24 px
	local function rise(object: GuiObject, px: number, time: number)
		local home = object.Position
		object.Position = home + UDim2.fromOffset(0, px * k)
		object.Visible = true
		tween(object, time, { Position = home })
	end
	task.delay(0.6, function()
		rise(group, 60, 0.3)
	end)
	task.delay(0.8, function()
		rise(tip, 24, 0.3)
	end)

	-- ===== Loops (storyboard frame 2) =====
	local function loop(object: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?)
		table.insert(
			loops,
			tween(object, time, props, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		)
	end
	task.delay(0.7, function()
		if exiting then
			return
		end
		loop(logoScale, 1.4, { Scale = 1.03 })
		loop(burstScale, 1.1, { Scale = 1.05 })
		loop(laneGlow, 1.2, { ImageTransparency = 0.45 })
		loop(streak, 0.4, { ImageTransparency = 0.5 })
	end)
	-- Constant spins (rays, hero ball, bar ball, small pins) + pin bob, sparkles and the sign's flicker
	task.spawn(function()
		local start = os.clock()
		while alive and not exiting do
			local t = os.clock() - start
			rays.Rotation = (t / 24 * 360) % 360
			heroBall.Rotation = -18 + (t / 2.5 * 360) % 360
			barBall.Rotation = (t / 0.8 * 360) % 360
			if t > 0.9 then
				for i, pin in pins do
					local p = pinHome[i]
					local phase = if i % 2 == 0 then math.pi else 0
					local bob = math.sin(t / 1.8 * math.pi * 2 + phase)
					pin.Position = pinSpot(i, 1) + UDim2.fromOffset(0, bob * 10 * k)
					pin.Rotation = if i <= 2 then p[5] + bob * 6 else p[5] + (t - 0.9) / 6 * 360
				end
			end
			task.wait()
		end
	end)
	for i, s in sparks do
		task.spawn(function()
			task.wait(0.6 + i * 0.12)
			local sc = UiKit.ScaleOf(s)
			while alive and not exiting do
				local d = sparkHome[i]
				if d and s.Visible then
					s.Position = UDim2.fromScale(
						(d[1] + math.random(-30, 30) / 10) / 100,
						(d[2] + math.random(-30, 30) / 10) / 100
					)
					s.Rotation = 0
					sc.Scale = 0
					tween(s, 0.6, { Rotation = 90 }, Enum.EasingStyle.Linear)
					tween(sc, 0.3, { Scale = 1 }, Enum.EasingStyle.Quad).Completed:Wait()
					tween(sc, 0.3, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
				end
				task.wait(0.3 + math.random() * 0.9)
			end
		end)
	end
	task.spawn(function()
		while alive and not exiting do
			task.wait(3 + math.random() * 2)
			for _ = 1, 2 do
				if exiting then
					break
				end
				tween(sign, 0.06, { ImageTransparency = 0.7 }, Enum.EasingStyle.Linear).Completed:Wait()
				tween(sign, 0.06, { ImageTransparency = 0 }, Enum.EasingStyle.Linear).Completed:Wait()
			end
		end
	end)
	-- LOADING dots step every 0.35 s
	task.spawn(function()
		local n = 0
		while alive and not exiting do
			n = n % 3 + 1
			loadingText.Text = 'LOADING<font color="#2BE4FF">' .. string.rep(".", n) .. "</font>"
			task.wait(0.35)
		end
	end)

	-- ===== Progress =====
	local shown = 0
	local function setFill(p: number, time: number)
		local w = math.max(40, math.floor(TRACK_W * p + 0.5))
		tween(fill, time, { Size = UDim2.fromOffset(w, TRACK_H) })
		tween(barBall, time, { Position = UDim2.fromOffset(TRACK_X + w - 32 + 32, 9 + 32) })
		pctText.Text = math.floor(p * 100 + 0.5) .. "%"
	end
	setFill(0.04, 0)

	local screen = {}
	function screen.SetProgress(p: number)
		p = math.clamp(p, 0, 1)
		if exiting or p <= shown + 0.005 then
			return
		end
		shown = p
		setFill(p, 0.25)
	end

	-- ===== Exit (storyboard frame 3): strike, then fade =====
	function screen.Finish()
		if exiting then
			return
		end
		exiting = true
		for _, t in loops do
			t:Cancel()
		end
		shown = 1
		setFill(1, 0.2)
		task.wait(0.15)
		-- the bar's ball rolls into the 3 pins: they fly up and spin away; STRIKE! pops
		tween(barBall, 0.15, { Position = UDim2.fromOffset(800 + 32, 9 + 32) }, Enum.EasingStyle.Linear)
		for i, pin in barPins do
			local spin = ({ -50, 35, 82 })[i] * 3
			tween(pin, 0.35, {
				Position = pin.Position + UDim2.fromOffset((i - 1) * 25, -(40 + (i % 2) * 40)),
				Rotation = spin,
				ImageTransparency = 1,
			})
		end
		Sfx.Play("StrikeCrash")
		strikeText.Visible = true
		strikeScale.Scale = 0
		tween(strikeScale, 0.2, { Scale = 1.2 }, Enum.EasingStyle.Back).Completed:Once(function()
			tween(strikeScale, 0.1, { Scale = 1 })
		end)
		-- the logo grows and lifts, the pins drift further out, the tip goes
		tween(logoScale, 0.6, { Scale = 1.12 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(
			logo,
			0.6,
			{ Position = logo.Position - UDim2.fromOffset(0, 30 * k) },
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		)
		for i, pin in pins do
			tween(pin, 0.8, { Position = pinSpot(i, 1.25) })
		end
		tween(tip, 0.3, { BackgroundTransparency = 1 })
		tween(tipStroke, 0.3, { Transparency = 1 })
		for _, label in { tipLabel, tipBody } do
			tween(label, 0.3, { TextTransparency = 1 })
			tween(label:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.3, { Transparency = 1 })
		end
		task.wait(0.4)
		-- the whole screen fades over 0.6 s (the fly-over is already moving behind it)
		local fade = 0.6
		for _, d in root:GetDescendants() do
			local props = {}
			if d:IsA("ImageLabel") then
				props.ImageTransparency = 1
			end
			if d:IsA("TextLabel") then
				props.TextTransparency = 1
			end
			if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
				props.BackgroundTransparency = 1
			end
			if d:IsA("UIStroke") then
				props.Transparency = 1
			end
			if next(props) then
				tween(d, fade, props, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end
		task.delay(fade, function()
			alive = false
			root:Destroy()
		end)
	end

	function screen.Destroy()
		alive = false
		exiting = true
		root:Destroy()
	end

	return screen
end

-- Every image of the screen, to preload before it shows
function LoadingScreen.Images(): { string }
	local list = {}
	for _, id in IMG do
		table.insert(list, id)
	end
	return list
end

return LoadingScreen
