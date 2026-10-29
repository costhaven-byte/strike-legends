-- Reward windows in the owner's kit style (UI pass batch 1, 2026-10-28): the daily calendar, the free gifts panel and
-- the spin prize card. No design file of their own (owner: no more Claude Design for UI); built from the owner's
-- finished kits: UI Kit (navy cover, red X, dark backdrop, open pop 0.6 -> 1.05 -> 1, close shrink), Crate Kit (lip
-- button + press feel, titles with an ink drop, rays, sparkles, confetti) and HUD Kit (icons). Sizes are design px
-- on a 1920x1080 screen; a window shrinks to fit smaller screens (phones held sideways).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local CrateKit = require(script.Parent:WaitForChild("CrateKit"))
local HudKit = require(script.Parent:WaitForChild("HudKit"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local MascotView = require(script.Parent:WaitForChild("MascotView"))
local Balls = require(Shared.Modules.Balls)

local RewardKit = {}

local make = UiKit.Make
local tween = UiKit.Tween
local C = UiKit.C
RewardKit.C = C

-- Button paints (face, lip), from the kits
RewardKit.Paint = {
	Lime = { C.Lime, C.LimeLip },
	Gold = { C.Gold, C.GoldLip },
	Pink = { C.Pink, C.PinkLip },
	Cyan = { C.Cyan, C.CyanLip },
	Red = { CrateKit.C.Red, CrateKit.C.RedLip },
	Grey = { C.Grey, C.GreyLip },
	Fever = { UiKit.Hex("FF7A1A"), UiKit.Hex("C2410C") }, -- FEVER MODE (Config.Fever)
}

-- Largest text size (up to max) whose wrapped text fits w x h design px. Measured on the design size, so it is right
-- under any UIScale (HudKit.Fit measures on screen, which a shrunk window would shrink twice).
function RewardKit.Fit(label: TextLabel, max: number, w: number, h: number?)
	label.TextScaled = false
	local function fit()
		local size = max
		while size > 8 do
			local params = Instance.new("GetTextBoundsParams")
			params.Text = label.ContentText
			params.Font = label.FontFace
			params.Size = size
			params.Width = if label.TextWrapped then w else 1e5
			local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
			if not ok then
				break
			end
			if bounds.X <= w and bounds.Y <= (h or size * 1.3) then
				break
			end
			size -= 1
		end
		label.TextSize = size
	end
	if not label:GetAttribute("RewardFit") then
		label:SetAttribute("RewardFit", true)
		label:GetPropertyChangedSignal("Text"):Connect(function()
			task.spawn(fit)
		end)
	end
	task.spawn(fit)
end

-- A label at design x, y, w, h with the ink outline (stroke 0 = none), shrunk to fit
function RewardKit.Label(
	parent: Instance,
	text: string,
	font: Font,
	size: number,
	color: Color3,
	stroke: number,
	x: number,
	y: number,
	w: number,
	h: number
): TextLabel
	local label = UiKit.Text(parent, text, font, size, color, stroke)
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(w, h)
	RewardKit.Fit(label, size, w - stroke * 2, h)
	return label
end

-- ===== Window: full-screen backdrop + a design-sized panel that shrinks to fit the screen =====
export type Window = {
	Screen: Frame,
	Backdrop: TextButton,
	Panel: Frame,
	W: number,
	H: number,
	Open: (Window) -> (),
	Close: (Window) -> (),
	IsOpen: (Window) -> boolean,
	Closed: BindableEvent,
}

function RewardKit.Window(gui: ScreenGui, w: number, h: number): Window
	local screen = make("Frame", {
		Name = "Screen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Active = true, -- taps never fall through to the throw meter
	}, gui) :: Frame
	local backdrop = UiKit.Backdrop(screen)
	local fit = make("Frame", {
		Name = "Fit",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(w, h),
		ZIndex = 2,
	}, screen) :: Frame
	local fitScale = make("UIScale", {}, fit) :: UIScale
	local panel = make("Frame", {
		Name = "Panel",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = true,
	}, fit) :: Frame
	local panelScale = UiKit.ScaleOf(panel)
	local closed = Instance.new("BindableEvent")

	local function refit()
		local area = gui.AbsoluteSize
		if area.X > 0 then
			fitScale.Scale = math.max(0.3, math.min(1, (area.X - 24) / w, (area.Y - 16) / h))
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	refit()

	local win = { Screen = screen, Backdrop = backdrop, Panel = panel, W = w, H = h, Closed = closed } :: any
	function win.Open()
		refit()
		Sfx.Play("Click")
		UiKit.Open(screen, backdrop, panel, panelScale)
	end
	function win.Close()
		if screen.Visible then
			UiKit.Close(screen, backdrop, panelScale)
			closed:Fire()
		end
	end
	function win.IsOpen(): boolean
		return screen.Visible
	end
	backdrop.Activated:Connect(function()
		win:Close()
	end)
	UiKit.CloseKeys(screen, function()
		win:Close()
	end)
	return win :: Window
end

-- The window's cover: navy block with an ink lip, a title with the kit's ink drop, a sub line and the red X.
-- Returns the cover frame (design px from its top-left) and the X.
function RewardKit.Cover(panel: Frame, w: number, h: number, title: string, sub: string?, titleColor: Color3?): (Frame, ImageButton)
	local cover = UiKit.Block(panel, {
		Name = "Cover",
		Size = Vector2.new(w, h),
		Fill = C.Cover,
		Lip = C.Ink,
		LipPx = 6,
		Radius = 24,
		Outline = 4,
	}).Holder :: Frame
	local titleBox = make("Frame", {
		Name = "TitleBox",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(26, 14),
		Size = UDim2.fromOffset(w - 120, 54),
	}, cover)
	local front = CrateKit.Title(titleBox, title, 44, titleColor or C.Gold, 3.5, 4)
	front.TextXAlignment = Enum.TextXAlignment.Left
	if sub then
		local line = RewardKit.Label(cover, sub, UiKit.Body, 15, C.Label, 0, 28, 68, w - 130, 20)
		line.Name = "Sub"
		line.TextXAlignment = Enum.TextXAlignment.Left
	end
	local close = UiKit.CloseX(cover, 52)
	close.Position = UDim2.fromOffset(w - 36, 36)
	close.ZIndex = 5
	return cover, close
end

-- The kit's chunky lip button with a label (paint = a RewardKit.Paint name)
function RewardKit.Button(parent: Instance?, text: string, paint: string, w: number, h: number, size: number?)
	local colours = RewardKit.Paint[paint] or RewardKit.Paint.Lime
	local button = CrateKit.Button(parent, {
		Name = "Button",
		W = w,
		H = h,
		Fill = colours[1],
		Lip = colours[2],
		LipPx = 6,
		Radius = 14,
		Outline = 3,
		Text = text,
		Size = size or 28,
		Stroke = 3,
		Press = 4,
	})
	local function fitLabel()
		RewardKit.Fit(button.Label, size or 28, w - 28, h)
	end
	button.Label:GetPropertyChangedSignal("Text"):Connect(fitLabel)
	fitLabel()
	return button
end

-- ===== Reward icons (HUD Kit art; eggs are drawn) =====

-- The egg's real 3D model (PetModels.Egg_<id>, the one on the egg stand) in a viewport filling parent
function RewardKit.Egg(parent: Instance, eggId: string): ViewportFrame
	local view = MascotView.Viewport(parent, MascotView.Egg(eggId, 4), 1.45)
	view.Name = "Egg"
	view.ZIndex = 4
	-- lit brighter than the pets panel: icons sit on dark cards
	view.Ambient = Color3.fromRGB(235, 235, 245)
	view.LightDirection = Vector3.new(-0.6, -1, -1.2)
	return view
end

-- A cartoon egg drawn with frames (no longer used for icons: kept for screens that can't show 3D)
function RewardKit.DrawnEgg(parent: Instance, look, size: number): Frame
	local egg = make("Frame", {
		Name = "Egg",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(size * 0.74, size * 0.94),
		BackgroundColor3 = look.Color,
		ZIndex = 4,
	}, parent)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, egg)
	UiKit.Outline(egg, C.Ink, math.max(2, size / 22))
	-- darker bottom, like the kit's lit-from-above icons
	make("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.72, 0.72, 0.8)),
		Rotation = 90,
	}, egg)
	for _, spot in { { 0.3, 0.32, 0.24 }, { 0.68, 0.5, 0.2 }, { 0.38, 0.72, 0.16 }, { 0.7, 0.22, 0.12 } } do
		local dot = make("Frame", {
			Name = "Spot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(spot[1], spot[2]),
			Size = UDim2.fromScale(spot[3] * 1.25, spot[3]),
			BackgroundColor3 = look.Spots,
			ZIndex = 5,
		}, egg)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, dot)
	end
	local shine = make("Frame", {
		Name = "Shine",
		Position = UDim2.fromScale(0.2, 0.1),
		Size = UDim2.fromScale(0.16, 0.24),
		Rotation = -20,
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.25,
		ZIndex = 6,
	}, egg)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shine)
	return egg
end

local function potionById(id: string?)
	for _, potion in Config.Potions.List do
		if potion.Id == id then
			return potion
		end
	end
	return nil
end
RewardKit.PotionById = potionById

-- The crate's real 3D model (ReplicatedStorage.CrateModels, the kiosk designs) turned like in the crate shop, in a
-- viewport filling parent. Falls back to the HUD Kit crate icon when the model is missing.
local crateModels = ReplicatedStorage:WaitForChild("CrateModels", 10)
function RewardKit.Crate(parent: Instance, crateId: string?): GuiObject
	local crate = Balls.GetCrate(crateId)
	local template = crate
		and crateModels
		and (crateModels:FindFirstChild(crate.Id) or (crate.Model and crateModels:FindFirstChild(crate.Model)))
	if not template then
		return HudKit.Image(parent, "Crate", 1, { Size = UDim2.fromScale(1, 1) })
	end
	local view = make("ViewportFrame", {
		Name = "Crate",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(225, 225, 240),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-0.6, -1, -1.2),
		ZIndex = 4,
	}, parent)
	local camera = make("Camera", { FieldOfView = 30 }, view)
	view.CurrentCamera = camera
	local model = template:Clone() :: Model
	model:PivotTo(CFrame.Angles(0, math.rad(Config.CrateShop.Intro.FaceAngle), 0))
	local box, size = model:GetBoundingBox()
	model.Parent = view
	local radius = math.max(size.X, size.Y, size.Z) * 0.55
	camera.CFrame = CFrame.lookAt(
		box.Position + Vector3.new(0, 0.35, 1).Unit * radius / math.tan(math.rad(15)),
		box.Position
	)
	return view
end

-- An icon in a size x size holder, centred on position (RewardKit.Fill draws it). kind: "Coins", "Gems", "Crate"
-- (value = crate Id: its 3D model), "Potion" (value = potion Id; MEGA potions get a gold star), "Egg" (value = egg
-- Id: its 3D model), "Gift", "GiftGold".
function RewardKit.Icon(parent: Instance, kind: string, value: any, size: number, position: UDim2?): Frame
	local holder = make("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 4,
	}, parent)
	RewardKit.Fill(holder, kind, value)
	return holder
end

-- (Re)draws an icon holder's picture (a crate reward changes when a new zone opens)
function RewardKit.Fill(holder: Frame, kind: string, value: any)
	for _, child in holder:GetChildren() do
		if not child:IsA("UIScale") then
			child:Destroy()
		end
	end
	local size = holder.Size.X.Offset
	local function image(name: string, scale: number?)
		local s = size * (scale or 1)
		return HudKit.Image(holder, name, s, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
	end
	if kind == "Coins" then
		image("Coins2")
	elseif kind == "Gems" then
		image("Gem", 0.9)
	elseif kind == "Crate" then
		RewardKit.Crate(holder, value)
	elseif kind == "Potion" then
		local potion = potionById(value)
		image(if potion and potion.Boost == "XP" then "PotionXp" else "PotionCoin", 0.95)
		if potion and potion.Big then
			local star = CrateKit.Icon(holder, "Star", size * 0.42)
			star.AnchorPoint = Vector2.new(0.5, 0.5)
			star.Position = UDim2.fromScale(0.82, 0.18)
			star.ZIndex = 6
		end
	elseif kind == "Egg" then
		RewardKit.Egg(holder, value)
	elseif kind == "GiftGold" then
		image("GiftDaily")
	else
		image("GiftPink")
	end
end

-- Spinning rays behind an icon (Crate Kit art), tinted. Returns the image and a stop function.
function RewardKit.Rays(parent: Instance, color: Color3, size: number, seconds: number?): (ImageLabel, () -> ())
	local rays = make("ImageLabel", {
		Name = "Rays",
		BackgroundTransparency = 1,
		Image = CrateKit.Image("Rays"),
		ImageColor3 = color,
		ImageTransparency = 0.25,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 2,
	}, parent)
	return rays, HudKit.Spin(rays, seconds or 8)
end

-- Gentle breathing on a UIScale (1 -> peak -> 1, period s each way) until the stop function runs
function RewardKit.Pulse(object: GuiObject, peak: number, period: number): () -> ()
	local scale = UiKit.ScaleOf(object)
	local running = true
	task.spawn(function()
		while running and object.Parent do
			tween(scale, period, Enum.EasingStyle.Sine, { Scale = peak }, Enum.EasingDirection.InOut).Completed:Wait()
			if not running then
				break
			end
			tween(scale, period, Enum.EasingStyle.Sine, { Scale = 1 }, Enum.EasingDirection.InOut).Completed:Wait()
		end
	end)
	return function()
		running = false
		tween(scale, 0.12, Enum.EasingStyle.Quad, { Scale = 1 })
	end
end

-- Little sparkles that blink on and off around a box (Crate Kit sparkle art)
function RewardKit.Twinkle(parent: GuiObject, count: number, color: Color3?): () -> ()
	local running = true
	for i = 1, count do
		local star = CrateKit.Icon(parent, "Sparkle", 22)
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.ImageColor3 = color or C.White
		star.ImageTransparency = 1
		star.ZIndex = 7
		task.spawn(function()
			task.wait(i * 0.37)
			while running and star.Parent do
				star.Position = UDim2.fromScale(math.random(5, 95) / 100, math.random(5, 95) / 100)
				local s = 12 + math.random() * 14
				star.Size = UDim2.fromOffset(s, s)
				star.Rotation = math.random(0, 90)
				tween(star, 0.35, Enum.EasingStyle.Quad, { ImageTransparency = 0, Rotation = star.Rotation + 45 })
				task.wait(0.5)
				tween(star, 0.35, Enum.EasingStyle.Quad, { ImageTransparency = 1 })
				task.wait(0.6 + math.random() * 1.2)
			end
		end)
	end
	return function()
		running = false
	end
end

-- Things in a window pop in one after another as it opens (UIScale 0.5 -> 1, 0.22 Back Out, gap s apart)
function RewardKit.Stagger(objects: { GuiObject }, gap: number?, delay: number?)
	for i, object in objects do
		local scale = UiKit.ScaleOf(object)
		scale.Scale = 0.01
		task.delay((delay or 0.12) + (i - 1) * (gap or 0.035), function()
			scale.Scale = 0.5
			tween(scale, 0.22, Enum.EasingStyle.Back, { Scale = 1 })
		end)
	end
end

-- A stamp: drops from big onto its spot (UIScale 2.2 -> 1, 0.25 Back Out), a little tilt
function RewardKit.Stamp(object: GuiObject)
	local scale = UiKit.ScaleOf(object)
	scale.Scale = 2.2
	object.Rotation = -18
	tween(scale, 0.25, Enum.EasingStyle.Back, { Scale = 1 })
	tween(object, 0.25, Enum.EasingStyle.Back, { Rotation = 0 })
end

-- ===== Toast: a navy pill that drops in at the top centre, then slides away =====
-- toast(text, icon kind?, icon value?, colour?, seconds?). It lives on its own layer over every window.
function RewardKit.Toast(owner: ScreenGui): (string, string?, any?, Color3?, number?) -> ()
	local W, H = 420, 60
	local gui = make("ScreenGui", {
		Name = owner.Name .. "Toast",
		ResetOnSpawn = false,
		IgnoreGuiInset = owner.IgnoreGuiInset,
		DisplayOrder = 60,
	}, game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
	local holder = make("Frame", {
		Name = "Toast",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -90),
		Size = UDim2.fromOffset(W, H),
		Visible = false,
		ZIndex = 40,
	}, gui)
	local block = UiKit.Block(holder, {
		Name = "Pill",
		Size = UDim2.fromScale(1, 1),
		Fill = C.Cover,
		Lip = C.Ink,
		LipPx = 5,
		Radius = 30,
		Outline = 3,
	})
	local face = block.Face
	local iconSpot = make("Frame", {
		Name = "IconSpot",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(0, 44, 1, 0),
	}, face)
	local label = UiKit.Text(face, "", UiKit.Head, 22, C.White, 2.5)
	local fitScale = make("UIScale", {}, holder)
	local token = 0
	return function(text: string, kind: string?, value: any?, color: Color3?, seconds: number?)
		token += 1
		local mine = token
		iconSpot:ClearAllChildren()
		local textX = 16
		if kind then
			RewardKit.Icon(iconSpot, kind, value, 40)
			textX = 58
		end
		label.Position = UDim2.fromOffset(textX, 2)
		label.Size = UDim2.new(1, -textX - 16, 1, 0)
		label.Text = text
		label.TextColor3 = color or C.White
		RewardKit.Fit(label, 22, W - textX - 22, H - 10)
		local area = gui.AbsoluteSize
		fitScale.Scale = math.min(1, math.max(0.5, (area.X - 24) / W))
		local top = if area.Y > 0 and area.Y < Config.Ui.CompactHeight then 52 else 110
		holder.Visible = true
		holder.Position = UDim2.new(0.5, 0, 0, -90)
		tween(holder, 0.28, Enum.EasingStyle.Back, { Position = UDim2.new(0.5, 0, 0, top) })
		task.delay(seconds or 2.4, function()
			if token == mine then
				tween(holder, 0.18, Enum.EasingStyle.Quad, { Position = UDim2.new(0.5, 0, 0, -90) }, Enum.EasingDirection.In)
				task.wait(0.2)
				if token == mine then
					holder.Visible = false
				end
			end
		end)
	end
end

-- ===== Prize card: YOU WON! with the prize on spinning rays, its name, a line and one button =====
export type PrizeCard = {
	Window: Window,
	Slot: Frame, -- 170x170 spot for the prize (icons, a pet viewport)
	Show: (PrizeCard, { [string]: any }) -> (),
}

-- opts for Show: Title ("YOU WON!"), Name, NameColor, Sub, SubColor, Kind + Value (an icon) or Fill (fn(slot)),
-- Button ("AWESOME!"), Big (true = gold flash, big confetti, sparkles)
function RewardKit.PrizeCard(gui: ScreenGui): PrizeCard
	local W, H = 420, 400
	local win = RewardKit.Window(gui, W, H)
	local cover, close = RewardKit.Cover(win.Panel, W, H, "YOU WON!", nil, C.Gold)
	local titleBox = cover:FindFirstChild("TitleBox") :: Frame
	titleBox.Size = UDim2.fromOffset(W - 52, 54)
	for _, child in titleBox:GetDescendants() do
		if child:IsA("TextLabel") then
			child.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
	local stage = make("Frame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(W / 2, 160),
		Size = UDim2.fromOffset(170, 170),
	}, cover)
	local rays = RewardKit.Rays(stage, C.Gold, 300, 10)
	local slot = make("Frame", {
		Name = "Slot",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	}, stage)
	local name = RewardKit.Label(cover, "", UiKit.Head, 32, C.White, 3, 20, 252, W - 40, 40)
	local sub = RewardKit.Label(cover, "", UiKit.Body, 15, C.Label, 0, 24, 292, W - 48, 22)
	local ok = RewardKit.Button(cover, "AWESOME!", "Lime", 230, 62, 30)
	ok.Holder.Position = UDim2.fromOffset((W - 230) / 2, H - 62 - 22)
	ok.Activated:Connect(function()
		win:Close()
	end)
	close.Activated:Connect(function()
		win:Close()
	end)
	local stopTwinkle: (() -> ())? = nil

	local card = { Window = win, Slot = slot } :: any
	function card.Show(_, opts: { [string]: any })
		slot:ClearAllChildren()
		for _, child in titleBox:GetDescendants() do
			if child:IsA("TextLabel") then
				child.Text = opts.Title or "YOU WON!"
			end
		end
		name.Text = opts.Name or ""
		name.TextColor3 = opts.NameColor or C.White
		sub.Text = opts.Sub or ""
		sub.TextColor3 = opts.SubColor or C.Label
		ok:SetText(opts.Button or "AWESOME!")
		rays.ImageColor3 = opts.NameColor or C.Gold
		if opts.Fill then
			opts.Fill(slot)
		elseif opts.Kind then
			RewardKit.Icon(slot, opts.Kind, opts.Value, 150)
		end
		if stopTwinkle then
			stopTwinkle()
			stopTwinkle = nil
		end
		if opts.Big then
			stopTwinkle = RewardKit.Twinkle(stage, 6, C.Gold)
		end
		win:Open()
		-- the prize pops after the window: 0 -> 1.15 -> 1
		local scale = UiKit.ScaleOf(slot)
		scale.Scale = 0.01
		task.delay(0.15, function()
			tween(scale, 0.22, Enum.EasingStyle.Back, { Scale = 1.15 }).Completed:Wait()
			tween(scale, 0.1, Enum.EasingStyle.Quad, { Scale = 1 })
		end)
		CrateKit.Confetti(cover, 0, -40, if opts.Big then 40 else 18, if opts.Big then 260 else 160, 0.6)
		Sfx.Play(if opts.Big then "RevealBig" else "Reveal")
	end
	win.Closed.Event:Connect(function()
		if stopTwinkle then
			stopTwinkle()
			stopTwinkle = nil
		end
	end)
	return card :: PrizeCard
end

return RewardKit
