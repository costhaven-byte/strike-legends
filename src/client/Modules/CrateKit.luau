-- The owner's Crate Kit (claude.ai/design 'Strike Legends Crate Design', 2026-10-26: 'Crate Kit Specs' + 'Crate
-- Screens'): colours, rarity colours, crate metals, the chunky lip button with its states and press feel, and the
-- full-screen stage every crate screen is laid out on. Sizes are the design's pixels: computer 1920x1080, phone held
-- sideways 844x390. The stage scales to fit the screen and stretches to its edges, so design x/y are measured from
-- the design frame's top-left, centred on the screen. Text outlines are the kit's UIStroke thicknesses.
-- Roblox has no Gotham Black (Gotham SSm Heavy stands in) and Fredoka One has one weight.
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CrateKitAssets = require(Shared.CrateKitAssets)
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local CrateKit = {}

local hex = Color3.fromHex
local make = UiKit.Make
CrateKit.Make = make

CrateKit.C = {
	Ink = hex("04061A"),
	Panel = hex("070B1E"),
	PanelLine = hex("1E2A5A"),
	Card = hex("1E143C"),
	CardLip = hex("150E2C"),
	CardLine = hex("33285E"),
	Zebra = hex("251A4A"),
	Muted = hex("9C93CC"),
	Label = hex("B9B2E0"),
	Faint = hex("8E86B8"),
	Grey = hex("4A4F68"),
	GreyLip = hex("30344A"),
	GreyText = hex("D5D8E6"),
	Gold = hex("FFC93A"),
	GoldLip = hex("C98A00"),
	Cyan = hex("2BE4FF"),
	CyanLip = hex("0B9DBF"),
	Pink = hex("FF4FB0"),
	PinkLip = hex("C21F7C"),
	Lime = hex("7DFF3C"),
	LimeLip = hex("3FAE14"),
	Red = hex("FF2D4A"),
	RedLip = hex("A8102A"),
	Navy = hex("3A2E72"),
	NavyLip = hex("251C4E"),
	LuckyBg = hex("16301A"),
	LuckyText = hex("C8F5B0"),
	White = Color3.new(1, 1, 1),
}
local C = CrateKit.C

-- Rarity colour and its dark shade, by Config.Rarities name
CrateKit.Rarity = {
	Common = { hex("A7B0C2"), hex("5E6680") },
	Uncommon = { hex("5BE04A"), hex("2A8A22") },
	Rare = { hex("3D8BFF"), hex("1B4BB0") },
	Epic = { hex("B14DFF"), hex("6A1FB0") },
	Legendary = { hex("FFC93A"), hex("C98A00") },
	Mythic = { hex("FF3D7F"), hex("A8104A") },
}

function CrateKit.RarityColor(name: string): Color3
	local row = CrateKit.Rarity[name]
	return if row then row[1] else C.White
end

-- Crate name colour: the kit's metal for Bronze/Silver/Gold tier crates, the crate's own colour otherwise
local METALS = { Bronze = hex("F29A5A"), Silver = hex("DDE7F7"), Gold = hex("FFC93A") }
function CrateKit.Metal(crate): Color3
	return METALS[crate.Tier or crate.Id] or crate.Color
end

CrateKit.Head = UiKit.Head -- Luckiest Guy
CrateKit.Num = UiKit.Num -- Fredoka One
CrateKit.Body = UiKit.Body -- Gotham stand-in

function CrateKit.Image(name: string): string
	return CrateKitAssets.Image(name)
end

function CrateKit.Phone(gui: GuiBase2d): boolean
	local size = gui.AbsoluteSize
	return size.Y > 0 and size.Y < Config.Ui.CompactHeight
end

function CrateKit.Corner(parent: Instance, radius: number): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, math.max(radius, 0)) }, parent)
end

function CrateKit.Stroke(parent: Instance, color: Color3?, thickness: number?, border: boolean?): UIStroke
	return make("UIStroke", {
		Color = color or C.Ink,
		Thickness = thickness or 3,
		ApplyStrokeMode = if border == false then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

-- A text label with the ink outline (stroke 0 = none). Fills its parent unless placed.
function CrateKit.Text(
	parent: Instance?,
	text: string,
	font: Font,
	size: number,
	color: Color3?,
	stroke: number?
): TextLabel
	local label = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = font,
		Text = text,
		TextSize = size,
		TextColor3 = color or C.White,
		RichText = true,
	}, parent)
	if (stroke or 0) > 0 then
		make("UIStroke", { Color = C.Ink, Thickness = stroke, LineJoinMode = Enum.LineJoinMode.Round }, label)
	end
	return label
end

-- Text with the kit's hard ink drop shadow under it (titles): returns the front label
function CrateKit.Title(
	parent: Instance,
	text: string,
	size: number,
	color: Color3,
	stroke: number,
	drop: number
): TextLabel
	local holder = make("Frame", { Name = "Title", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	local shadow = CrateKit.Text(holder, text, CrateKit.Head, size, C.Ink, stroke)
	shadow.Name = "Shadow"
	shadow.Position = UDim2.fromOffset(0, drop)
	shadow.RichText = false -- the shadow stays ink even when the front has coloured words
	local front = CrateKit.Text(holder, text, CrateKit.Head, size, color, stroke)
	front.Name = "Front"
	shadow.Text = front.ContentText
	front:GetPropertyChangedSignal("Text"):Connect(function()
		shadow.Text = front.ContentText
	end)
	for _, prop in { "TextXAlignment", "TextYAlignment", "TextTransparency", "TextSize", "TextScaled" } do
		front:GetPropertyChangedSignal(prop):Connect(function()
			(shadow :: any)[prop] = (front :: any)[prop]
		end)
	end
	front:GetPropertyChangedSignal("TextTransparency"):Connect(function()
		for _, s in { shadow:FindFirstChildOfClass("UIStroke"), front:FindFirstChildOfClass("UIStroke") } do
			if s then
				s.Transparency = front.TextTransparency
			end
		end
	end)
	return front
end

-- Width of one line of text in px (for chips and tags sized to their words)
local TextService = game:GetService("TextService")
function CrateKit.TextWidth(text: string, font: Font, size: number): number
	local params = Instance.new("GetTextBoundsParams")
	params.Text = text
	params.Font = font
	params.Size = size
	params.Width = 10000
	local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
	return if ok then math.ceil(bounds.X) else math.ceil(#text * size * 0.62)
end

function CrateKit.Icon(parent: Instance?, name: string, size: number): ImageLabel
	return make("ImageLabel", {
		Name = name,
		BackgroundTransparency = 1,
		Image = CrateKit.Image(name),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(size, size),
	}, parent)
end

local function scaleOf(object: GuiObject): UIScale
	return (object:FindFirstChildOfClass("UIScale") or make("UIScale", {}, object)) :: UIScale
end
CrateKit.ScaleOf = scaleOf

function CrateKit.Tween(
	object: Instance,
	time: number,
	style: Enum.EasingStyle,
	props: { [string]: any },
	dir: Enum.EasingDirection?,
	repeats: number?,
	reverses: boolean?
): Tween
	local t = TweenService:Create(
		object,
		TweenInfo.new(time, style, dir or Enum.EasingDirection.Out, repeats or 0, reverses or false),
		props
	)
	t:Play()
	return t
end
local tween = CrateKit.Tween

-- ===== Block: ink outline, the lip strip under the face, the face on top =====
-- opts: Name, W, H, Fill, Lip, LipPx (8), Radius (16), Outline (4), Ring (inner line colour), RingPx (2),
-- Button (true = a TextButton holder)
export type Block = { Holder: GuiObject, Body: Frame, Face: Frame, LipPx: number }

function CrateKit.Block(parent: Instance?, opts: { [string]: any }): Block
	local o = opts.Outline or 4
	local lipPx = opts.LipPx or 8
	local radius = opts.Radius or 16
	local holder = make(if opts.Button then "TextButton" else "Frame", {
		Name = opts.Name or "Block",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(opts.W or 100, opts.H or 40),
	})
	if opts.Button then
		(holder :: TextButton).Text = ""
		(holder :: TextButton).AutoButtonColor = false
	end
	local body = make("Frame", {
		Name = "Body",
		BackgroundColor3 = opts.Lip or opts.Fill or C.Card,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(o, o),
		Size = UDim2.new(1, -o * 2, 1, -o * 2),
	}, holder)
	CrateKit.Corner(body, radius - o)
	if o > 0 then
		CrateKit.Stroke(body, C.Ink, o)
	end
	local face = make("Frame", {
		Name = "Face",
		BackgroundColor3 = opts.Fill or C.Card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -lipPx),
	}, body)
	CrateKit.Corner(face, radius - o)
	if opts.Ring then
		local ringPx = opts.RingPx or 2
		local ring = make("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(ringPx, ringPx),
			Size = UDim2.new(1, -ringPx * 2, 1, -ringPx * 2 + lipPx),
		}, body)
		CrateKit.Corner(ring, radius - o - ringPx)
		CrateKit.Stroke(ring, opts.Ring, ringPx)
	end
	if parent then
		holder.Parent = parent
	end
	return { Holder = holder, Body = body, Face = face, LipPx = lipPx } :: Block
end

-- ===== Button: a Block with a centred icon + label row, the kit's press feel and states =====
-- opts (on top of Block's): Text, Size (font px), Stroke, Color (text), Icon, IconSize, Press (px the face moves, 4),
-- Gap (icon-label gap, 8)
export type Button = {
	Holder: TextButton,
	Face: Frame,
	Body: Frame,
	Label: TextLabel,
	Icon: ImageLabel?,
	Row: Frame,
	Activated: RBXScriptSignal,
	Paint: (Button, Color3, Color3, Color3?) -> (),
	SetText: (Button, string) -> (),
	SetIcon: (Button, string?) -> (),
	SetPressable: (Button, boolean) -> (),
	Shake: (Button) -> (),
}

function CrateKit.Button(parent: Instance?, opts: { [string]: any }): Button
	opts.Button = true
	local block = CrateKit.Block(nil, opts)
	local holder = block.Holder :: TextButton
	local row = make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, block.Face)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, opts.Gap or 8),
	}, row)
	local iconSize = opts.IconSize or 26
	local icon = CrateKit.Icon(row, opts.Icon or "Check", iconSize)
	icon.Name = "Icon"
	icon.Visible = opts.Icon ~= nil
	local label = CrateKit.Text(row, opts.Text or "", CrateKit.Head, opts.Size or 32, opts.Color, opts.Stroke or 3)
	label.Name = "Label"
	label.LayoutOrder = 2
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Size = UDim2.new(0, 0, 1, 0)
	label.Visible = (opts.Text or "") ~= ""
	-- Luckiest Guy sits high in its line box: nudge it down a little so it looks centred
	make("UIPadding", { PaddingTop = UDim.new(0, math.floor((opts.Size or 32) * 0.1)) }, label)

	local button = {
		Holder = holder,
		Face = block.Face,
		Body = block.Body,
		Label = label,
		Icon = icon,
		Row = row,
		Activated = holder.Activated,
	} :: any
	local pressable = true
	local press = opts.Press or 4
	local scale = scaleOf(holder)
	local down = false

	function button.Paint(_, fill: Color3, lip: Color3, text: Color3?)
		block.Face.BackgroundColor3 = fill
		block.Body.BackgroundColor3 = lip
		if text then
			label.TextColor3 = text
		end
	end
	function button.SetText(_, text: string)
		label.Text = text
		label.Visible = text ~= ""
	end
	function button.SetIcon(_, name: string?)
		icon.Visible = name ~= nil
		if name then
			icon.Image = CrateKit.Image(name)
		end
	end
	function button.SetPressable(_, on: boolean)
		pressable = on
	end
	-- NEED MORE tap: Rotation 0 -> -4 -> 4 -> -2 -> 0 over 0.25, nothing else
	function button.Shake()
		task.spawn(function()
			for _, angle in { -4, 4, -2, 0 } do
				tween(holder, 0.0625, Enum.EasingStyle.Linear, { Rotation = angle })
				task.wait(0.0625)
			end
		end)
	end

	-- Down: face moves down (0.06 Linear). Up: back (0.10 Back Out). PC hover: UIScale 1.04 (0.10 Quad Out).
	holder.MouseButton1Down:Connect(function()
		if not pressable then
			return
		end
		down = true
		tween(block.Face, 0.06, Enum.EasingStyle.Linear, { Position = UDim2.fromOffset(0, press) })
	end)
	local function release()
		if down then
			down = false
			tween(block.Face, 0.1, Enum.EasingStyle.Back, { Position = UDim2.fromOffset(0, 0) })
		end
	end
	holder.MouseButton1Up:Connect(release)
	holder.MouseEnter:Connect(function()
		if pressable and UserInputService.MouseEnabled then
			tween(scale, 0.1, Enum.EasingStyle.Quad, { Scale = 1.04 })
		end
	end)
	holder.MouseLeave:Connect(function()
		release()
		tween(scale, 0.1, Enum.EasingStyle.Quad, { Scale = 1 })
	end)
	holder.Activated:Connect(function()
		if pressable then
			Sfx.Play("Click", 0.95 + math.random() * 0.1)
		end
	end)
	if parent then
		holder.Parent = parent
	end
	return button :: Button
end

-- ===== Stage: a full-screen frame (top bar included) with a design-sized layout space inside =====
-- The stage is the design frame (1920x1080 / 844x390) scaled to fit, then stretched to the screen's edges in design
-- units, so CrateKit.Place keeps the design frame centred and full-width pieces can use scale 1.
export type Stage = {
	Screen: Frame,
	Stage: Frame,
	Scale: UIScale,
	Phone: boolean,
	W: number,
	H: number,
	Fit: (Stage) -> (),
}

function CrateKit.Stage(parent: GuiObject, gui: ScreenGui, name: string): Stage
	local inset = if gui.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
	local screen = make("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, -inset.Y),
		Size = UDim2.new(1, 0, 1, inset.Y),
		Active = true,
	}, parent)
	local stage = make("Frame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 2,
	}, screen)
	local scale = make("UIScale", {}, stage)
	local s = { Screen = screen, Stage = stage, Scale = scale, Phone = false, W = 1920, H = 1080 } :: any
	function s.Fit()
		local size = screen.AbsoluteSize
		s.Phone = CrateKit.Phone(gui)
		s.W, s.H = if s.Phone then 844 else 1920, if s.Phone then 390 else 1080
		local k = math.max(math.min(size.X / s.W, size.Y / s.H), 0.2)
		scale.Scale = k
		stage.Size = UDim2.fromOffset(math.max(size.X / k, s.W), math.max(size.Y / k, s.H))
	end
	s.Fit()
	return s :: Stage
end

-- Puts a stage piece at design x, y (top-left of the design frame) with size w, h
function CrateKit.Place(stage: Stage, object: GuiObject, x: number, y: number, w: number?, h: number?)
	object.Position = UDim2.new(0.5, x - stage.W / 2, 0.5, y - stage.H / 2)
	if w and h then
		object.Size = UDim2.fromOffset(w, h)
	end
end

-- Confetti (every crate reveal since A2, and reward pops): pieces start at (x, y), burst up 150-300 px (0.3 Quad Out), fall +700 px
-- (2.2 Quad In) spinning up to 540 degrees, and fade out over the last 0.5
local CONFETTI_COLORS = { C.Gold, C.Cyan, C.Pink, C.Lime, C.Red, C.White }
-- colors: optional palette (default = the kit's gold/cyan/pink/lime/red/white)
function CrateKit.Confetti(
	parent: GuiObject,
	x: number,
	y: number,
	count: number,
	spread: number,
	scale: number?,
	colors: { Color3 }?
)
	local k = scale or 1
	local palette = colors or CONFETTI_COLORS
	for i = 1, count do
		local dot = math.random() < 0.3
		local piece = make("ImageLabel", {
			Name = "Confetti",
			BackgroundTransparency = 1,
			Image = CrateKit.Image(if dot then "ConfettiDot" else "ConfettiRect"),
			ImageColor3 = palette[(i - 1) % #palette + 1],
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, x, 0.5, y),
			Size = UDim2.fromOffset((if dot then 22 else 30) * k, (if dot then 22 else 30) * k),
			Rotation = math.random(0, 360),
			ZIndex = 8,
		}, parent)
		local dx = (math.random() - 0.5) * 2 * spread
		local up = (150 + math.random() * 150) * k
		local spin = (math.random() < 0.5 and -1 or 1) * 540
		task.spawn(function()
			tween(piece, 0.3, Enum.EasingStyle.Quad, { Position = UDim2.new(0.5, x + dx * 0.6, 0.5, y - up) })
			task.wait(0.3)
			tween(piece, 2.2, Enum.EasingStyle.Quad, {
				Position = UDim2.new(0.5, x + dx, 0.5, y - up + 700 * k),
				Rotation = piece.Rotation + spin,
			}, Enum.EasingDirection.In)
			task.wait(1.7)
			tween(piece, 0.5, Enum.EasingStyle.Linear, { ImageTransparency = 1 })
			task.wait(0.5)
			piece:Destroy()
		end)
	end
end

return CrateKit
