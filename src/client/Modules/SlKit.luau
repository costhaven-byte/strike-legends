-- UI overhaul v2, step V1 (UI_OVERHAUL_PLAN.md): the owner's UI system kit ('Strike Legends UI.html', board A, 2026-11-02).
-- Every new screen builds from these pieces: the chunky block (outline, darker lip, lighter top strip), buttons in
-- 5 action colours x sizes, price buttons, counter pills, the progress bar, the window shell with header plate,
-- close X, tabs and well, the item card (6 rarities, 6 states), badges, toast and tooltip bubble, plus the motion
-- notes (board M). Sizes are the design's pixels at 1920x1080; Kit.AutoScale shrinks a whole window on small screens.
-- Flat solid colours only: no gradients, no glows (the Mythic edge is hard stripes, as designed).
-- Old kits (HudKit, UiKit, SunKit, CrateKit...) keep working; screens move over to this one step by step.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetSlots = require(Shared.AssetSlots)
local Currency = require(Shared.Modules.Currency)
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local SlKit = {}

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

-- ===== Colours (board A "Colour") =====
SlKit.C = {
	Ink = hex("10172E"), -- every outline
	Window = hex("17345C"),
	WindowStrip = hex("2D5A92"),
	Tile = hex("22477A"), -- cards, idle tabs
	TileStrip = hex("2F5B96"),
	TileLip = hex("10294A"), -- wells, idle tab lips
	Header = hex("FFC93A"),
	HeaderLip = hex("E59A00"),
	HeaderStrip = hex("FFE48A"),
	Value = hex("4BE07A"), -- "+5 PINS" lines
	Warn = hex("FFA41C"), -- bag 80%
	Tick = hex("3FD24A"),
	Padlock = hex("2B3A55"),
	Gem = hex("A15CFF"),
	White = Color3.new(1, 1, 1),
}
local C = SlKit.C

-- Action paints: { face, lip, top strip }
SlKit.Paints = {
	Green = { hex("3CCB3F"), hex("1F8F27"), hex("7BE07D") }, -- buy / claim / go / Robux
	Blue = { hex("2E9BFF"), hex("1666C4"), hex("8CCBFF") }, -- info / secondary
	Pink = { hex("FF4FA3"), hex("C42A78"), hex("FF9BCB") }, -- gems / premium
	Red = { hex("FF3B4E"), hex("B81E30"), hex("FF8A96") }, -- close / not enough
	Gold = { hex("FFC93A"), hex("E59A00"), hex("FFE680") }, -- rewards / rebirth
	Purple = { C.Gem, hex("7234C9"), hex("C69BFF") }, -- gem prices
	Disabled = { hex("6B7A90"), hex("4A5568"), hex("8C99AD") },
	Locked = { hex("5B6478"), hex("353C4D"), hex("737D92") }, -- locked tabs
	Tile = { C.Tile, C.TileLip, C.TileStrip }, -- idle tabs, cards
	Window = { C.Window, C.Ink, C.WindowStrip },
	Header = { C.Header, C.HeaderLip, C.HeaderStrip },
	Dark = { hex("10294A"), C.Ink, hex("17345C") }, -- "EQUIPPED" / owned chips
}

-- Rarity colours (Mythic also gets the striped edge)
SlKit.Rarity = {
	Common = hex("B8C2CC"),
	Uncommon = hex("4BE07A"),
	Rare = hex("3AA8FF"),
	Epic = hex("B45CFF"),
	Legendary = hex("FFC93A"),
	Mythic = hex("FF4F8B"),
}
SlKit.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
local MYTHIC_STRIPES = { hex("FF4F8B"), hex("FFC93A"), hex("4BE07A"), hex("3AA8FF"), hex("B45CFF") }

-- ===== Type (4 sizes; Fredoka One for all, Builder Sans Bold only for 13 px labels) =====
SlKit.Font = Font.new("rbxasset://fonts/families/FredokaOne.json")
SlKit.LabelFont = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
SlKit.T = { Display = 44, Title = 28, Body = 20, Label = 13 }

-- Button sizes { width, height, radius, text }
SlKit.Sizes = {
	XS = { 96, 40, 12, 20 },
	S = { 120, 48, 12, 20 },
	M = { 176, 64, 16, 28 },
	L = { 240, 88, 20, 28 },
	XL = { 280, 96, 24, 44 }, -- SELL / THROW
}

-- "V2_hud_shop" style names, or a short name from the icon sheet ("hud_shop")
function SlKit.Icon(name: string): string
	return AssetSlots.Image(if string.sub(name, 1, 3) == "V2_" then name else "V2_" .. name)
end

-- ===== Motion (board M): snap, overshoot, soft =====
SlKit.Ease = {
	Snap = { Enum.EasingStyle.Quint, Enum.EasingDirection.Out },
	Over = { Enum.EasingStyle.Back, Enum.EasingDirection.Out },
	Soft = { Enum.EasingStyle.Sine, Enum.EasingDirection.InOut },
	Linear = { Enum.EasingStyle.Linear, Enum.EasingDirection.InOut },
}

function SlKit.Tween(object: Instance, time: number, ease: string?, props: { [string]: any }): Tween
	local e = SlKit.Ease[ease or "Soft"]
	local tween = TweenService:Create(object, TweenInfo.new(time, e[1], e[2]), props)
	tween:Play()
	return tween
end

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end
SlKit.Make = make

local function scaleOf(object: GuiObject): UIScale
	local scale = object:FindFirstChild("KitScale") :: UIScale?
	if not scale then
		scale = make("UIScale", { Name = "KitScale" }, object)
	end
	return scale :: UIScale
end
SlKit.ScaleOf = scaleOf

-- Scale 1 -> to -> 1 (coin icon pulse 1.25, red dot re-pop 1.2)
function SlKit.Pulse(object: GuiObject, to: number?, time: number?)
	local scale = scaleOf(object)
	local half = (time or 0.24) / 2
	SlKit.Tween(scale, half, "Snap", { Scale = to or 1.25 })
	task.delay(half, function()
		SlKit.Tween(scale, half, "Over", { Scale = 1 })
	end)
end

-- Pop in from nothing: 0 -> 1.3 -> 1 (red dot, badges)
function SlKit.PopIn(object: GuiObject, time: number?)
	local scale = scaleOf(object)
	scale.Scale = 0
	local t = time or 0.25
	SlKit.Tween(scale, t * 0.6, "Snap", { Scale = 1.3 })
	task.delay(t * 0.6, function()
		SlKit.Tween(scale, t * 0.4, "Over", { Scale = 1 })
	end)
end

-- Up-and-down loop (hint bubble 8 px / 0.8 s, ready cards 6 px / 1.2 s). Returns stop().
function SlKit.Bob(object: GuiObject, px: number?, period: number?): () -> ()
	local base = object.Position
	local up = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset - (px or 8))
	local tween = TweenService:Create(
		object,
		TweenInfo.new((period or 0.8) / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = up }
	)
	tween:Play()
	return function()
		tween:Cancel()
		object.Position = base
	end
end

-- Side to side shake (locked tap: 8 px + rotation 12; FULL bag shake)
function SlKit.Shake(object: GuiObject, px: number?, rotation: number?, time: number?)
	local base, baseRotation = object.Position, object.Rotation
	local steps, t = 6, (time or 0.3) / 6
	task.spawn(function()
		for i = 1, steps do
			local side = if i % 2 == 1 then 1 else -1
			local fade = 1 - (i - 1) / steps
			object.Position = base + UDim2.fromOffset(side * (px or 8) * fade, 0)
			object.Rotation = baseRotation + side * (rotation or 0) * fade
			task.wait(t)
		end
		object.Position = base
		object.Rotation = baseRotation
	end)
end

-- Keeps an object turning (card rays 360 deg / 20 s). Returns stop().
function SlKit.Spin(object: GuiObject, seconds: number?): () -> ()
	local tween = TweenService:Create(
		object,
		TweenInfo.new(seconds or 20, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = object.Rotation + 360 }
	)
	tween:Play()
	return function()
		tween:Cancel()
	end
end

-- ===== Text =====
-- size: a number or "Display" / "Title" / "Body" / "Label"
function SlKit.Text(parent: Instance?, text: string, size: any, color: Color3?, props: { [string]: any }?): TextLabel
	local px = if type(size) == "string" then SlKit.T[size] else size or SlKit.T.Body
	local label = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = if px <= SlKit.T.Label then SlKit.LabelFont else SlKit.Font,
		Text = text,
		TextSize = px,
		TextColor3 = color or C.White,
		ZIndex = 6,
	})
	make("UIStroke", {
		Color = C.Ink,
		Thickness = if px <= SlKit.T.Label then 1.5 else 2.5,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, label)
	for key, value in props or {} do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

function SlKit.Image(parent: Instance?, icon: string, size: number, props: { [string]: any }?): ImageLabel
	local image = make("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = SlKit.Icon(icon),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(size, size),
		ZIndex = 6,
	})
	for key, value in props or {} do
		(image :: any)[key] = value
	end
	image.Parent = parent
	return image
end

local function corner(parent: Instance, radius: number): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, math.max(radius, 0)) }, parent)
end
SlKit.Corner = corner

-- ===== The block: holder (full design size = tap area) > lip (outline drawn inside the box) > face (top strip
-- colour) > fill (face colour, 3 px lower). Children go in block.Content (on the fill). =====
export type Block = {
	Holder: GuiObject,
	Lip: Frame,
	Face: Frame,
	Fill: Frame,
	Content: Frame,
	Stroke: UIStroke,
	LipHeight: number,
	Pressed: boolean,
	Paint: (Block, any) -> (),
	SetPressed: (Block, boolean) -> (),
}

local function paintOf(paint: any): { Color3 }
	if type(paint) == "string" then
		return SlKit.Paints[paint] or SlKit.Paints.Tile
	end
	return paint
end

-- opts: Name, Button (true = TextButton holder), Size, Radius, Lip (6), Strip (3), Outline (3), Paint, ZIndex
function SlKit.Block(parent: Instance?, opts: { [string]: any }?): Block
	local o = opts or {}
	local paint = paintOf(o.Paint or "Tile")
	local outline = o.Outline or 3
	local radius = o.Radius or 16
	local z = o.ZIndex or 1
	local holder = make(if o.Button then "TextButton" else "Frame", {
		Name = o.Name or "Block",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.fromOffset(176, 64),
		ZIndex = z,
	})
	if o.Button then
		local button = holder :: TextButton
		button.Text = ""
		button.AutoButtonColor = false
		button:SetAttribute("OwnPress", true) -- UiFx leaves it alone
	end
	local lip = make("Frame", {
		Name = "Lip",
		BackgroundColor3 = paint[2],
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(outline, outline),
		Size = UDim2.new(1, -2 * outline, 1, -2 * outline),
		ZIndex = z,
	}, holder)
	corner(lip, radius - outline)
	local stroke = make("UIStroke", {
		Color = C.Ink,
		Thickness = outline,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, lip)
	local face = make("Frame", {
		Name = "Face",
		BackgroundColor3 = paint[3] or paint[1],
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, lip)
	corner(face, radius - outline)
	local strip = o.Strip or 3
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = paint[1],
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, strip),
		Size = UDim2.new(1, 0, 1, -strip),
		ZIndex = z + 2,
	}, face)
	corner(fill, radius - outline)
	-- Content sits over the whole face (strip included) so text centres on the visible face
	local content = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, -strip),
		Size = UDim2.new(1, 0, 1, strip),
		ZIndex = z + 3,
	}, fill)

	local block = {
		Holder = holder,
		Lip = lip,
		Face = face,
		Fill = fill,
		Content = content,
		Stroke = stroke,
		LipHeight = o.Lip or 6,
		Pressed = false,
	} :: any

	local function layout()
		local drop = if block.Pressed then block.LipHeight - 2 else 0
		face.Position = UDim2.fromOffset(0, drop)
		face.Size = UDim2.new(1, 0, 1, -block.LipHeight)
	end
	layout()

	function block.Paint(_self, newPaint: any)
		local p = paintOf(newPaint)
		lip.BackgroundColor3 = p[2]
		face.BackgroundColor3 = p[3] or p[1]
		fill.BackgroundColor3 = p[1]
	end
	function block.SetPressed(self, down: boolean)
		self.Pressed = down
		local drop = if down then self.LipHeight - 2 else 0
		SlKit.Tween(face, if down then 0.06 else 0.22, if down then "Snap" else "Over", {
			Position = UDim2.fromOffset(0, drop),
		})
	end

	if o.Button then
		SlKit.Press(block)
	end
	holder.Parent = parent
	return block
end

-- Button press (board M): scale 1 -> 0.92 (0.06 s snap), on release 1.04 -> 1 (0.22 s overshoot); the face sinks
-- into the lip (lip 2, y + 4). Computers grow a little on hover. Plays the click.
function SlKit.Press(block: Block, silent: boolean?)
	local button = block.Holder :: GuiButton
	local scale = scaleOf(button)
	local function down()
		if block.Pressed or button:GetAttribute("KitDisabled") then
			return
		end
		block:SetPressed(true)
		SlKit.Tween(scale, 0.06, "Snap", { Scale = 0.92 })
	end
	local function up()
		if not block.Pressed then
			return
		end
		block:SetPressed(false)
		SlKit.Tween(scale, 0.08, "Snap", { Scale = 1.04 })
		task.delay(0.08, function()
			SlKit.Tween(scale, 0.14, "Over", { Scale = 1 })
		end)
	end
	button.MouseButton1Down:Connect(down)
	button.MouseButton1Up:Connect(up)
	button.MouseLeave:Connect(function()
		up()
		if not block.Pressed then
			SlKit.Tween(scale, 0.12, "Soft", { Scale = 1 })
		end
	end)
	button.MouseEnter:Connect(function()
		if not UserInputService.TouchEnabled and not button:GetAttribute("KitDisabled") then
			SlKit.Tween(scale, 0.12, "Soft", { Scale = 1.04 })
		end
	end)
	if not silent then
		button.Activated:Connect(function()
			if button:GetAttribute("KitDisabled") then
				Sfx.Play("Error")
			else
				Sfx.Play("Click", 0.95 + math.random() * 0.1)
			end
		end)
	end
end

-- ===== Buttons =====
export type Button = Block & {
	Label: TextLabel,
	Icon: ImageLabel?,
	SetText: (Button, string) -> (),
	SetDisabled: (Button, boolean, boolean?) -> (),
}

local function row(parent: Instance, gap: number): Frame
	local frame = make("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	return frame
end

-- opts: Text, Paint ("Green"...), Size ("XS" / "S" / "M" / "L" / "XL" or a UDim2), Icon (sheet name),
-- IconSize, TextSize, Name, Disabled
function SlKit.Button(parent: Instance?, opts: { [string]: any }): Button
	local sizeRow = SlKit.Sizes[if type(opts.Size) == "string" then opts.Size else "M"]
	local size = if typeof(opts.Size) == "UDim2" then opts.Size else UDim2.fromOffset(sizeRow[1], sizeRow[2])
	local block = SlKit.Block(nil, {
		Name = opts.Name or "Button",
		Button = true,
		Size = size,
		Radius = opts.Radius or sizeRow[3],
		Paint = opts.Paint or "Green",
		ZIndex = opts.ZIndex,
		Lip = if sizeRow[2] <= 48 then 5 else 6,
	}) :: any
	local line = row(block.Content, 8)
	local textSize = opts.TextSize or sizeRow[4]
	if opts.Icon then
		block.Icon = SlKit.Image(line, opts.Icon, opts.IconSize or math.floor(textSize * 1.45), { LayoutOrder = 1 })
	end
	local label = SlKit.Text(line, opts.Text or "", textSize, C.White, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
	})
	block.Label = label
	local lock: ImageLabel? = nil
	local paint = opts.Paint or "Green"

	function block.SetText(_self, text: string)
		label.Text = text
	end
	-- Disabled (board A): grey + padlock in front of the text; showLock false = grey only
	function block.SetDisabled(self, on: boolean, showLock: boolean?)
		self.Holder:SetAttribute("KitDisabled", on)
		self:Paint(if on then "Disabled" else paint)
		if on and showLock ~= false then
			if not lock then
				lock = SlKit.Image(line, "ui_lock", math.floor(textSize * 1.2), { LayoutOrder = 0, Name = "Lock" })
			end
		end
		if lock then
			lock.Visible = on and showLock ~= false
		end
		-- the padlock takes the icon's place ("[lock] 400K")
		if self.Icon then
			self.Icon.Visible = not (lock and lock.Visible)
		end
	end
	function block.Repaint(_self, newPaint: any)
		paint = newPaint
		block:Paint(newPaint)
	end
	if opts.Disabled then
		block:SetDisabled(true)
	end
	block.Holder.Parent = parent
	return block
end

-- Price button (board A "Price buttons"): coin = green + coin icon 40; gem = purple + gem; Robux = green + the
-- Robux glyph; not enough = red. opts: Currency ("Coin" / "Gem" / "Robux"), Amount (number or text), Affordable,
-- Size (default "S" wide 160)
local ROBUX_GLYPH = utf8.char(0xE002)
function SlKit.PriceButton(parent: Instance?, opts: { [string]: any }): Button
	local currency = opts.Currency or "Coin"
	local base = if currency == "Gem" then "Purple" else "Green"
	local icon = if currency == "Coin" then "cur_coin" elseif currency == "Gem" then "cur_gem" else nil
	local button = SlKit.Button(parent, {
		Name = opts.Name or "Price",
		Size = opts.Size or UDim2.fromOffset(160, 56),
		Radius = 14,
		Paint = base,
		Icon = icon,
		IconSize = opts.IconSize or 40,
		TextSize = opts.TextSize or 28,
	}) :: any
	function button.SetPrice(self, amount: any, affordable: boolean?)
		local text = if type(amount) == "number" then Currency.Format(amount) else tostring(amount)
		self.Label.Text = if currency == "Robux" then ROBUX_GLYPH .. " " .. text else text
		self:Repaint(if affordable == false then "Red" else base)
	end
	button:SetPrice(opts.Amount or 0, opts.Affordable)
	return button
end

-- ===== Counter pill (board A): h56, r28, window navy, icon 64 hanging off the left, number 28 =====
-- opts: Icon, Text, Sub (small green line under the number), Width, Plus (true = green + button on the right)
function SlKit.Pill(parent: Instance?, opts: { [string]: any }): { [string]: any }
	local width = opts.Width or 240
	local holder = make("Frame", {
		Name = opts.Name or "Pill",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, 64),
	})
	local block = SlKit.Block(holder, {
		Name = "Body",
		Size = UDim2.new(1, -24, 0, 56 + 6),
		Position = UDim2.fromOffset(24, 0),
		Radius = 28,
		Paint = "Window",
	})
	block.Holder.Position = UDim2.fromOffset(24, 0)
	local icon = SlKit.Image(holder, opts.Icon or "cur_coin", 64, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -4, 0, 31),
		ZIndex = 10,
	})
	local textBox = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(1, if opts.Plus then -110 else -60, 1, 0),
		ZIndex = 6,
	}, block.Content)
	local number = SlKit.Text(textBox, opts.Text or "0", "Title", C.White, {
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.fromScale(1, if opts.Sub then 0.62 else 1),
	})
	local sub: TextLabel? = nil
	if opts.Sub then
		sub = SlKit.Text(textBox, opts.Sub, "Label", C.Value, {
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromScale(0, 0.56),
			Size = UDim2.fromScale(1, 0.34),
		})
	end
	local plus: Button? = nil
	if opts.Plus then
		plus = SlKit.Button(block.Content, {
			Name = "Plus",
			Text = "+",
			Size = UDim2.fromOffset(44, 44),
			Radius = 12,
			TextSize = 28,
			Paint = "Green",
		})
		local h = (plus :: Button).Holder
		h.AnchorPoint = Vector2.new(1, 0.5)
		h.Position = UDim2.new(1, -6, 0.5, 0)
	end
	holder.Parent = parent
	return {
		Holder = holder,
		Block = block,
		Icon = icon,
		Number = number,
		Sub = sub,
		Plus = plus,
		Set = function(_self, text: string)
			number.Text = text
		end,
	}
end

-- ===== Progress bar (board A): green under 80%, orange from 80%, red "FULL!" at 100% =====
function SlKit.ProgressBar(parent: Instance?, opts: { [string]: any }?): { [string]: any }
	local o = opts or {}
	local block = SlKit.Block(nil, {
		Name = o.Name or "Bar",
		Size = o.Size or UDim2.fromOffset(330, 46),
		Radius = 14,
		Paint = { C.TileLip, C.Ink, C.TileLip },
		Lip = 4,
		Strip = 0,
	})
	local fill = make("Frame", {
		Name = "BarFill",
		BackgroundColor3 = SlKit.Paints.Green[1],
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 5,
	}, block.Content)
	corner(fill, 11)
	local text = SlKit.Text(block.Content, "", "Body", C.White, { ZIndex = 7 })
	local bar = { Holder = block.Holder, Block = block, BarFill = fill, Label = text }
	-- value / max; label nil = "value/max"; animate = grow 0.3 s then bump (board M "bag bar fill")
	function bar.Set(_self, value: number, max: number, label: string?, animate: boolean?)
		local share = if max > 0 then math.clamp(value / max, 0, 1) else 0
		local color = if share >= 1
			then SlKit.Paints.Red[1]
			elseif share >= 0.8 then C.Warn
			else SlKit.Paints.Green[1]
		text.Text = if share >= 1 and not label then "FULL!" else label or (Currency.Format(value) .. "/" .. Currency.Format(max))
		if animate then
			SlKit.Tween(fill, 0.3, "Soft", { Size = UDim2.fromScale(share, 1), BackgroundColor3 = color })
			task.delay(0.3, function()
				SlKit.Pulse(block.Holder, 1.06, 0.2)
			end)
		else
			fill.Size = UDim2.fromScale(share, 1)
			fill.BackgroundColor3 = color
		end
		fill.Visible = share > 0
	end
	bar:Set(o.Value or 0, o.Max or 1, o.Text)
	block.Holder.Parent = parent
	return bar
end

-- ===== Badges =====
-- Red dot: 24 px (13 px number) or big 32 px (20 px, 99+). count nil/0 = plain dot.
function SlKit.Dot(parent: Instance?, count: number?, big: boolean?): Frame
	local size = if big then 32 else 24
	local dot = make("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = SlKit.Paints.Red[1],
		Size = UDim2.fromOffset(size, size),
		ZIndex = 20,
	})
	corner(dot, size)
	make("UIStroke", { Color = C.Ink, Thickness = 2.5 }, dot)
	local label = SlKit.Text(dot, "", if big then 20 else 13, C.White, { ZIndex = 21 })
	if not big then
		label.FontFace = SlKit.Font -- numbers stay round
	end
	local function set(n: number?)
		label.Text = if n and n > 0 then (if n > 99 then "99+" else tostring(n)) else ""
		dot.Size = UDim2.fromOffset(if n and n > 99 then size + 14 else size, size)
	end
	set(count)
	dot:SetAttribute("Count", count or 0)
	dot:GetAttributeChangedSignal("Count"):Connect(function()
		set(dot:GetAttribute("Count") :: number)
		SlKit.Pulse(dot, 1.2, 0.12) -- re-pop when the number changes
	end)
	dot.Parent = parent
	return dot
end

-- Green tick (44 px) for done / owned
function SlKit.Tick(parent: Instance?, size: number?): ImageLabel
	return SlKit.Image(parent, "ui_tick", size or 44, { Name = "Tick", ZIndex = 20 })
end

-- Padlock badge: dark circle with the gold padlock (44 px)
function SlKit.Padlock(parent: Instance?, size: number?): Frame
	local s = size or 44
	local badge = make("Frame", {
		Name = "Padlock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Padlock,
		Size = UDim2.fromOffset(s, s),
		ZIndex = 20,
	})
	corner(badge, s)
	make("UIStroke", { Color = C.Ink, Thickness = 3 }, badge)
	SlKit.Image(badge, "ui_lock", math.floor(s * 0.66), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 21,
	})
	badge.Parent = parent
	return badge
end

-- ===== Window shell (board A "Window frame") =====
-- opts: Title, Icon (sheet name, optional), Size (720x480), HeaderHeight (56), TitleSize (28), CloseSize (64),
-- Close (false = no X), OnClose
export type Window = {
	Holder: Frame,
	Body: Block,
	Content: Frame, -- the area under the header plate, padded 24
	Header: Block,
	Title: TextLabel,
	Close: Button?,
	Scale: UIScale,
	Open: (Window) -> (),
	Hide: (Window) -> (),
}

function SlKit.Window(parent: Instance?, opts: { [string]: any }): Window
	local size = opts.Size or UDim2.fromOffset(720, 480)
	local holder = make("Frame", {
		Name = opts.Name or "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Size = size,
		ZIndex = opts.ZIndex or 10,
	})
	local scale = make("UIScale", { Name = "OpenScale" }, holder)
	local z = holder.ZIndex
	local body = SlKit.Block(holder, {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		Radius = 16,
		Paint = "Window",
		ZIndex = z,
	})
	local headerHeight = opts.HeaderHeight or 56
	local titleSize = opts.TitleSize or SlKit.T.Title
	local header = SlKit.Block(holder, {
		Name = "Header",
		Size = UDim2.fromOffset(240, headerHeight + 6),
		Radius = 14,
		Paint = "Header",
		ZIndex = z + 10,
	})
	header.Holder.AnchorPoint = Vector2.new(0.5, 0)
	header.Holder.Position = UDim2.new(0.5, 0, 0, -28) -- hangs 28 px over the top edge
	local line = row(header.Content, 10)
	if opts.Icon then
		SlKit.Image(line, opts.Icon, opts.IconSize or math.floor(titleSize * 1.3), { LayoutOrder = 1 })
	end
	local title = SlKit.Text(line, opts.Title or "", titleSize, C.White, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
	})
	-- The plate is as wide as its title + 48 px padding each side
	local function fitHeader()
		local width = 96 + title.TextBounds.X + (if opts.Icon then titleSize * 1.3 + 10 else 0)
		header.Holder.Size = UDim2.fromOffset(math.max(width, 200), headerHeight + 6)
	end
	title:GetPropertyChangedSignal("TextBounds"):Connect(fitHeader)
	fitHeader()

	local close: Button? = nil
	if opts.Close ~= false then
		local closeSize = opts.CloseSize or 64
		close = SlKit.Button(holder, {
			Name = "Close",
			Text = "X",
			Size = UDim2.fromOffset(closeSize, closeSize + 6),
			Radius = 16,
			Paint = "Red",
			TextSize = math.floor(closeSize * 0.62),
			ZIndex = z + 10,
		})
		local h = (close :: Button).Holder
		h.AnchorPoint = Vector2.new(1, 0)
		h.Position = UDim2.new(1, 18, 0, -18)
	end

	local content = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, headerHeight / 2 + 24),
		Size = UDim2.new(1, -48, 1, -(headerHeight / 2 + 24) - 30),
		ZIndex = z + 4,
	}, holder)

	local window = {
		Holder = holder,
		Body = body,
		Content = content,
		Header = header,
		Title = title,
		Close = close,
		Scale = scale,
	} :: any

	-- Open: scale 0.85 -> 1.03 -> 1 (0.28 s overshoot); close reverses fast (0.14 s)
	function window.Open(_self)
		holder.Visible = true
		scale.Scale = 0.85
		SlKit.Tween(scale, 0.28, "Over", { Scale = 1 })
		Sfx.Play("Click", 1.1)
	end
	function window.Hide(_self)
		SlKit.Tween(scale, 0.14, "Snap", { Scale = 0.85 })
		task.delay(0.14, function()
			holder.Visible = false
			scale.Scale = 1
		end)
	end
	if close then
		(close :: Button).Holder.Activated:Connect(function()
			if opts.OnClose then
				opts.OnClose()
			else
				window:Hide()
			end
		end)
	end
	holder.Parent = parent
	return window
end

-- The dark well inside a window that holds the cards (r12, #10294A, pad 20)
function SlKit.Well(parent: Instance?, props: { [string]: any }?): Frame
	local well = make("Frame", {
		Name = "Well",
		BackgroundColor3 = C.TileLip,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 12,
	})
	corner(well, 12)
	make("UIStroke", { Color = C.Ink, Thickness = 3 }, well)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 20),
		PaddingBottom = UDim.new(0, 20),
		PaddingLeft = UDim.new(0, 20),
		PaddingRight = UDim.new(0, 20),
	}, well)
	for key, value in props or {} do
		(well :: any)[key] = value
	end
	well.Parent = parent
	return well
end

-- ===== Tabs (h48, r14, 20 px): active gold raised 4 px, idle tile, locked grey =====
-- items: { { Id, Text, Icon?, Dot? } }; onPick(id). Returns { Holder, Select(id), SetDot(id, n), SetLocked(id, on) }
function SlKit.Tabs(parent: Instance?, items: { { [string]: any } }, onPick: ((string) -> ())?, opts: { [string]: any }?)
	local o = opts or {}
	local height = o.Height or 48
	local vertical = o.Vertical == true
	local holder = make("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = o.Size or UDim2.new(1, 0, 0, height + 6),
		ZIndex = 12,
	})
	make("UIListLayout", {
		FillDirection = if vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, o.Gap or 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, holder)
	local tabs = {}
	local current: string? = nil
	local locked = {}
	local api = { Holder = holder, Tabs = tabs }
	local function paintAll()
		for id, tab in tabs do
			local active = id == current
			tab.Block:Paint(if locked[id] then "Locked" elseif active then "Gold" else "Tile")
			-- raised 4 px when active (the slot keeps its height so the row doesn't jump)
			tab.Block.Lip.Position = UDim2.fromOffset(3, if active then -1 else 3)
		end
	end
	for index, item in items do
		local block = SlKit.Button(holder, {
			Name = "Tab_" .. item.Id,
			Text = item.Text,
			Icon = item.Icon,
			IconSize = o.IconSize or 34,
			Size = UDim2.fromOffset(item.Width or o.Width or 160, height + 6),
			Radius = 14,
			Paint = "Tile",
			TextSize = o.TextSize or 20,
		})
		block.Holder.LayoutOrder = index
		local dot = SlKit.Dot(block.Holder, item.Dot)
		dot.Position = UDim2.new(1, -4, 0, 4)
		dot.Visible = (item.Dot or 0) > 0
		tabs[item.Id] = { Block = block, Dot = dot }
		block.Holder.Activated:Connect(function()
			if locked[item.Id] then
				SlKit.Shake(block.Holder, 6, 8)
				return
			end
			api:Select(item.Id)
			if onPick then
				onPick(item.Id)
			end
		end)
	end
	function api.Select(_self, id: string)
		current = id
		paintAll()
	end
	function api.SetDot(_self, id: string, n: number?)
		local tab = tabs[id]
		if tab then
			local was = tab.Dot.Visible
			tab.Dot.Visible = (n or 0) > 0
			tab.Dot:SetAttribute("Count", n or 0)
			if tab.Dot.Visible and not was then
				SlKit.PopIn(tab.Dot)
			end
		end
	end
	function api.SetLocked(_self, id: string, on: boolean)
		locked[id] = on
		paintAll()
	end
	if items[1] then
		api:Select(o.Start or items[1].Id)
	end
	holder.Parent = parent
	return api
end

-- ===== Item card (board A): 200 x 264, rarity edge 4 px, art 64% on two-tone rays, name 20, value 20 green =====
-- opts: Rarity, Name, Value ("+5"), ValueIcon ("cur_pin"), Price (number/text), Currency, Button (text instead of a
-- price, e.g. "EQUIP"), ButtonPaint, Wide (true = value line, then a full-width button, like the shop design),
-- Size. card.Art = where a 3D view goes. card:SetState("Normal"/"Locked"/"Done"/"Ready"/"New"/"Unknown", n)
function SlKit.Card(parent: Instance?, opts: { [string]: any }): { [string]: any }
	local rarity = opts.Rarity or "Common"
	local edge = SlKit.Rarity[rarity] or SlKit.Rarity.Common
	local size = opts.Size or UDim2.fromOffset(200, 264)
	local block = SlKit.Block(nil, {
		Name = opts.Name or "Card",
		Button = opts.Clickable ~= false,
		Size = size,
		Radius = 16,
		Paint = "Tile",
	})
	local holder = block.Holder
	-- Rarity edge: a 4 px ring just inside the outline (stripes for Mythic). It lives on the fill (so it sinks with
	-- the face when pressed): the fill starts 3 px in and 3 px under the top strip, the ring 7 px in from the edge.
	local edgeFrame = make("Frame", {
		Name = "Edge",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 1),
		Size = UDim2.new(1, -8, 1, -5),
		ZIndex = holder.ZIndex + 8,
	}, block.Fill)
	corner(edgeFrame, 9)
	local edgeStroke = make("UIStroke", {
		Color = edge,
		Thickness = 4,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, edgeFrame)

	local stopStripes: (() -> ())? = nil
	local function stripes(on: boolean)
		local old = edgeStroke:FindFirstChildOfClass("UIGradient")
		if old then
			old:Destroy()
		end
		if stopStripes then
			stopStripes()
			stopStripes = nil
		end
		if not on then
			return
		end
		edgeStroke.Color = C.White
		local keys = {}
		local n = #MYTHIC_STRIPES * 2
		for i = 0, n - 1 do
			local color = MYTHIC_STRIPES[(i % #MYTHIC_STRIPES) + 1]
			table.insert(keys, ColorSequenceKeypoint.new(i / n, color))
			table.insert(keys, ColorSequenceKeypoint.new(math.min((i + 1) / n - 0.0001, 1), color))
		end
		keys[#keys] = ColorSequenceKeypoint.new(1, keys[#keys].Value)
		local stripe = make("UIGradient", { Color = ColorSequence.new(keys), Rotation = 35 }, edgeStroke)
		-- stripes slide along the edge (board M: 68 px per 1.2 s loop)
		local tween = TweenService:Create(
			stripe,
			TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Offset = Vector2.new(0.2, 0) }
		)
		stripe.Offset = Vector2.new(0, 0)
		tween:Play()
		stopStripes = function()
			tween:Cancel()
		end
	end

	-- Art: top 64% of the face, solid rarity colour + lighter rays. Same box as the ring's inside, so the ring's
	-- stroke covers the art's square corners.
	local artArea = make("Frame", {
		Name = "ArtArea",
		BackgroundColor3 = edge,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(4, 1),
		Size = UDim2.new(1, -8, 0.6, 0),
		ClipsDescendants = true,
		ZIndex = holder.ZIndex + 3,
	}, block.Fill)
	local rays = SlKit.Image(artArea, "bg_rays", 0, {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1.7, 1.7),
		SizeConstraint = Enum.SizeConstraint.RelativeXX,
		ImageColor3 = edge:Lerp(C.White, 0.4),
		ZIndex = holder.ZIndex + 3,
	})
	local art = make("Frame", {
		Name = "Art",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.78, 0.86),
		ZIndex = holder.ZIndex + 5,
	}, artArea)
	local rarityChip = SlKit.Text(artArea, string.upper(rarity), "Label", C.White, {
		Name = "RarityChip",
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = holder.ZIndex + 7,
	})

	-- Bottom: name, then value + button
	local bottom = make("Frame", {
		Name = "Bottom",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 4, 0.6, 1),
		Size = UDim2.new(1, -8, 0.4, -5),
		ZIndex = holder.ZIndex + 4,
	}, block.Fill)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
	}, bottom)
	local nameLabel = SlKit.Text(bottom, string.upper(opts.Title or opts.ItemName or ""), "Body", C.White, {
		Name = "ItemName",
		Size = UDim2.new(1, 0, 0, 26),
		ZIndex = holder.ZIndex + 6,
	})
	local valueRow = make("Frame", {
		Name = "ValueRow",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(if opts.Wide then 1 else 0.42, 0, 0, 28),
		ZIndex = holder.ZIndex + 6,
	}, bottom)
	local valueLine = row(valueRow, 4)
	valueLine:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = if opts.Wide
		then Enum.HorizontalAlignment.Center
		else Enum.HorizontalAlignment.Left
	local valueIcon = SlKit.Image(valueLine, opts.ValueIcon or "cur_pin", 24, { LayoutOrder = 1 })
	local valueText = SlKit.Text(valueLine, opts.Value or "", "Body", C.Value, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
	})

	local action: any
	if opts.Price ~= nil then
		action = SlKit.PriceButton(bottom, {
			Currency = opts.Currency or "Coin",
			Amount = opts.Price,
			Affordable = opts.Affordable,
			Size = UDim2.fromOffset(if opts.Wide then 0 else 104, 40 + 4),
			IconSize = 24,
			TextSize = 20,
		})
	else
		action = SlKit.Button(bottom, {
			Text = opts.Button or "EQUIP",
			Paint = opts.ButtonPaint or "Blue",
			Size = UDim2.fromOffset(if opts.Wide then 0 else 104, 40 + 4),
			Radius = 12,
			TextSize = 20,
		})
	end
	local actionPaint = if opts.Price ~= nil
		then (if opts.Affordable == false then "Red" elseif opts.Currency == "Gem" then "Purple" else "Green")
		else opts.ButtonPaint or "Blue"
	local actionText = action.Label.Text
	local actionHolder = action.Holder
	if opts.Wide then
		actionHolder.Size = UDim2.new(1, 0, 0, 44 + 4)
		actionHolder.Position = UDim2.new(0, 0, 1, -48)
	else
		actionHolder.AnchorPoint = Vector2.new(1, 0)
		actionHolder.Position = UDim2.new(1, 0, 0, 28)
	end

	-- State overlays
	local shade = make("Frame", {
		Name = "Shade",
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.3, -- dark 70%
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = holder.ZIndex + 6,
	}, artArea)
	local lockBig = SlKit.Image(artArea, "ui_lock", 56, {
		Name = "BigLock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Visible = false,
		ZIndex = holder.ZIndex + 7,
	})
	local tick = SlKit.Tick(holder, 44)
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.new(1, -8, 0, 8)
	tick.Visible = false
	local newDot = SlKit.Dot(holder, 0, true)
	newDot.Position = UDim2.new(1, -6, 0, 6)
	newDot.Visible = false
	-- Ready: a 4 px gold ring outside the outline
	local ring = make("Frame", {
		Name = "ReadyRing",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-2, -2),
		Size = UDim2.new(1, 4, 1, 4),
		Visible = false,
		ZIndex = holder.ZIndex,
	}, holder)
	corner(ring, 18)
	make("UIStroke", { Color = SlKit.Paints.Gold[1], Thickness = 4 }, ring)

	local card = {
		Holder = holder,
		Block = block,
		Art = art,
		ArtArea = artArea,
		Rays = rays,
		NameLabel = nameLabel,
		ValueText = valueText,
		ValueIcon = valueIcon,
		Action = action,
		RarityChip = rarityChip,
		State = "Normal",
	}
	local stopBob: (() -> ())? = nil
	local savedName, savedValue = nameLabel.Text, valueText.Text

	function card.SetRarity(_self, r: string)
		rarity = r
		edge = SlKit.Rarity[r] or SlKit.Rarity.Common
		edgeStroke.Color = edge
		artArea.BackgroundColor3 = edge
		rays.ImageColor3 = edge:Lerp(C.White, 0.4)
		rarityChip.Text = string.upper(r)
		stripes(r == "Mythic")
	end

	function card.SetState(self, state: string, n: number?)
		self.State = state
		if stopBob then
			stopBob()
			stopBob = nil
		end
		local locked, unknown = state == "Locked", state == "Unknown"
		shade.Visible = locked
		lockBig.Visible = locked or unknown
		tick.Visible = state == "Done"
		ring.Visible = state == "Ready"
		newDot.Visible = state == "New"
		newDot:SetAttribute("Count", n or 0)
		-- Unknown = black silhouette card: dark art, "???" name and value
		if unknown then
			artArea.BackgroundColor3 = hex("1A2440")
			rays.Visible = false
			rarityChip.Text = "???"
			nameLabel.Text = "???"
			valueText.Text = "???"
			edgeStroke.Color = hex("2B3A55")
		else
			artArea.BackgroundColor3 = edge
			rays.Visible = true
			rarityChip.Text = string.upper(rarity)
			nameLabel.Text = savedName
			valueText.Text = savedValue
			edgeStroke.Color = edge
		end
		art.Visible = not unknown
		if action.SetDisabled then
			action:SetDisabled(locked or unknown, true)
		end
		if unknown then
			action.Label.Text = "???"
		elseif locked then
			action.Label.Text = actionText
		end
		if state == "Done" then
			action.Label.Text = "EQUIPPED"
			action:Repaint("Dark")
		elseif not (locked or unknown) then
			action.Label.Text = actionText
			action:Repaint(actionPaint)
		end
		if state == "Ready" then
			stopBob = SlKit.Bob(holder, 6, 1.2)
		end
		if state == "New" then
			SlKit.PopIn(newDot)
		end
	end
	function card.SetName(_self, text: string)
		savedName = string.upper(text)
		nameLabel.Text = savedName
	end
	function card.SetValue(_self, text: string)
		savedValue = text
		valueText.Text = text
	end
	-- Locked tap (board M): card shakes, padlock wiggles
	if opts.Clickable ~= false then
		(holder :: GuiButton).Activated:Connect(function()
			if card.State == "Locked" or card.State == "Unknown" then
				SlKit.Shake(holder, 8, 0, 0.3)
				SlKit.Shake(lockBig, 0, 12, 0.3)
			end
		end)
	end

	card:SetRarity(rarity)
	card:SetState(opts.State or "Normal", opts.Count)
	holder.Parent = parent
	return card
end

-- ===== Toast (h60, r30, navy, icon 44, 28 px): reward = gold text, error = red body =====
-- Drops in, holds 1.5 s, lifts out (board M). opts: Icon, Text, Error, Hold. Returns the frame.
function SlKit.Toast(parent: Instance?, opts: { [string]: any }): Frame
	local isError = opts.Error == true
	local block = SlKit.Block(nil, {
		Name = "Toast",
		Size = UDim2.fromOffset(opts.Width or 300, 60 + 6),
		Radius = 30,
		Paint = if isError then "Red" else "Window",
		ZIndex = 40,
	})
	local holder = block.Holder
	holder.AnchorPoint = Vector2.new(0.5, 0)
	local line = row(block.Content, 10)
	SlKit.Image(line, opts.Icon or "cur_coin", 44, { LayoutOrder = 1 })
	SlKit.Text(line, opts.Text or "", "Title", if isError then C.White else SlKit.Paints.Gold[1], {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
	})
	holder.Parent = parent
	if opts.Animate ~= false then
		local base = opts.Position or UDim2.new(0.5, 0, 0, 120)
		holder.Position = base - UDim2.fromOffset(0, 24)
		SlKit.Tween(holder, 0.25, "Over", { Position = base })
		task.delay(0.25 + (opts.Hold or 1.5), function()
			SlKit.Tween(holder, 0.2, "Snap", { Position = base - UDim2.fromOffset(0, 12) })
			for _, d in holder:GetDescendants() do
				if d:IsA("Frame") then
					SlKit.Tween(d, 0.2, "Snap", { BackgroundTransparency = 1 })
				elseif d:IsA("TextLabel") then
					SlKit.Tween(d, 0.2, "Snap", { TextTransparency = 1 })
				elseif d:IsA("ImageLabel") then
					SlKit.Tween(d, 0.2, "Snap", { ImageTransparency = 1 })
				elseif d:IsA("UIStroke") then
					SlKit.Tween(d, 0.2, "Snap", { Transparency = 1 })
				end
			end
			task.delay(0.22, function()
				holder:Destroy()
			end)
		end)
	end
	return holder :: Frame
end

-- ===== Tooltip bubble: hint = gold h56 arrow 22, info = blue h44 arrow 16; arrow on any side =====
-- opts: Text, Info (true = blue), Side ("Bottom" default / "Top" / "Left" / "Right"), Bob (default true for hints)
function SlKit.Bubble(parent: Instance?, opts: { [string]: any }): Frame
	local info = opts.Info == true
	local height = if info then 44 else 56
	local arrow = if info then 16 else 22
	local holder = make("Frame", {
		Name = "Bubble",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height + 6),
		ZIndex = 30,
	})
	local block = SlKit.Block(holder, {
		Name = "Body",
		Size = UDim2.new(1, 0, 1, 0),
		Radius = 14,
		Paint = if info then "Blue" else "Gold",
		ZIndex = 31,
	})
	local text = SlKit.Text(block.Content, opts.Text or "", if info then "Body" else "Title", C.White, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Position = UDim2.fromOffset(18, 0),
		ZIndex = 36,
	})
	local function fit()
		holder.AutomaticSize = Enum.AutomaticSize.None
		holder.Size = UDim2.fromOffset(text.TextBounds.X + 36 + 6, height + 6)
	end
	text:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	fit()
	-- Arrow: a turned square in the bubble's colour, half hidden behind it
	local side = opts.Side or "Bottom"
	local paint = SlKit.Paints[if info then "Blue" else "Gold"]
	local point = make("Frame", {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = paint[1],
		BorderSizePixel = 0,
		Rotation = 45,
		Size = UDim2.fromOffset(arrow, arrow),
		ZIndex = 30,
	}, holder)
	make("UIStroke", { Color = C.Ink, Thickness = 3 }, point)
	point.Position = if side == "Top"
		then UDim2.new(0.5, 0, 0, 2)
		elseif side == "Left" then UDim2.new(0, 2, 0.5, -3)
		elseif side == "Right" then UDim2.new(1, -2, 0.5, -3)
		else UDim2.new(0.5, 0, 1, -4)
	-- keeps the arrow's lower half the lip colour where it sits under the lip
	if side == "Bottom" then
		point.BackgroundColor3 = paint[2]
	end
	holder.Parent = parent
	if opts.Bob ~= false and not info then
		task.defer(function()
			if holder.Parent then
				SlKit.Bob(holder, 8, 0.8)
			end
		end)
	end
	return holder
end

-- ===== Fitting a window on small screens =====
-- Keeps a design-size object inside the screen (minus margin), never bigger than 1, never under minScale.
function SlKit.AutoScale(object: GuiObject, designW: number, designH: number, minScale: number?): UIScale
	local scale = object:FindFirstChild("FitScale") :: UIScale?
	if not scale then
		scale = make("UIScale", { Name = "FitScale" }, object)
	end
	local gui = object:FindFirstAncestorWhichIsA("LayerCollector") :: ScreenGui?
	local function update()
		if not gui then
			return
		end
		local size = gui.AbsoluteSize
		if size.X <= 0 then
			return
		end
		local s = math.min((size.X - 48) / designW, (size.Y - 48) / designH, 1)
		;(scale :: UIScale).Scale = math.max(s, minScale or 0.4)
	end
	if gui then
		gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			task.defer(update)
		end)
	end
	update()
	return scale :: UIScale
end

-- The local player's PlayerGui (for previews and new screens)
function SlKit.PlayerGui(): PlayerGui
	return Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
end

return SlKit
