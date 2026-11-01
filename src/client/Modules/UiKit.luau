-- The owner's UI Kit (claude.ai/design 'Strike Legends UI Kit', 2026-10-26): the Ball Book and the Coin Multiplier
-- card. Colours, fonts, icons (Shared.UiKitAssets), the chunky lip button, the red close X, the dark backdrop and the
-- open/close tweens from the kit's animation notes. Sizes are the design's pixels (1920x1080 computer, 844x390 phone).
-- Text outlines are UIStrokes at half the design's CSS stroke (CSS strokes are centred on the letter edge).
-- Roblox has no Gotham Black; Gotham SSm Heavy stands in. Roblox strokes can't be dashed, so dashed boxes are solid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SunKit = require(script.Parent:WaitForChild("SunKit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UiKitAssets = require(Shared.UiKitAssets)
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local UiKit = {}

local function hex(value: string): Color3
	return Color3.fromHex(value)
end
UiKit.Hex = hex

UiKit.C = {
	Ink = hex("04061A"),
	Cover = hex("070B1E"), -- book / card fill
	Page = hex("120B28"), -- pages, list boxes, card lip
	Card = hex("1E143C"), -- owned card, total box, counter pill
	Missing = hex("150F2E"), -- missing card
	Chip = hex("2A1E55"),
	Slot = hex("0B0820"),
	Dash = hex("3A3F66"),
	Label = hex("C9D2F0"),
	Muted = hex("8C96C0"),
	Faded = hex("5E6488"),
	MissingTrait = hex("A7AFCF"),
	LockedText = hex("B8C0D4"),
	Gold = hex("FFC93A"),
	GoldLip = hex("C98A00"),
	Cyan = hex("2BE4FF"),
	CyanLip = hex("0A9DC0"),
	Pink = hex("FF4FB0"),
	PinkLip = hex("C21F7E"),
	Lime = hex("7DFF3C"),
	LimeLip = hex("4BBE14"),
	Red = hex("FF2D4A"),
	Grey = hex("4A4F68"),
	GreyLip = hex("30344A"),
	Price = hex("FF8A9B"),
	White = Color3.new(1, 1, 1),
}
local C = UiKit.C

-- Addendum 4 Stage 3d (Config.Ui.Sunny): windows turn cream with dark text (3d-2) and the neon buttons take the sunny
-- colours (Modules/SunKit), same names, so every screen built with the kit follows. White text left on the light
-- panels is turned dark by SunKit.Daylight.
if Config.Ui.Sunny == true then
	local S = SunKit.C
	C.Ink = S.Ink
	C.Cover = S.Cream
	C.Page = S.Sand
	C.Card = S.Paper
	C.Missing = S.Dim
	C.Chip = S.Dim
	C.Slot = S.Dim
	C.Dash = S.CreamLip
	C.Label = S.Ink
	C.Muted = S.Muted
	C.Faded = S.Faded
	C.MissingTrait = S.Muted
	C.LockedText = S.Muted
	C.Gold, C.GoldLip = S.Sun, S.SunLip
	C.Cyan, C.CyanLip = S.Sky, S.SkyLip
	C.Pink, C.PinkLip = S.Coral, S.CoralLip
	C.Lime, C.LimeLip = S.Green, S.GreenLip
	C.Red = S.Red
	C.Grey, C.GreyLip = S.Grey, S.GreyLip
end

-- Rarity tab colours (fill, lip), by Config.Rarities name
UiKit.Rarity = {
	Common = { hex("B8C0D4"), hex("7A839C") },
	Uncommon = { hex("3BE06B"), hex("1F9A43") },
	Rare = { hex("3A8BFF"), hex("1E56C4") },
	Epic = { hex("A44BFF"), hex("6D24C2") },
	Legendary = { hex("FFC93A"), hex("C98A00") },
	Mythic = { hex("FF3D7F"), hex("B81D52") },
}

UiKit.Head = SunKit.Swap(Font.new("rbxasset://fonts/families/LuckiestGuy.json"))
UiKit.Num = Font.new("rbxasset://fonts/families/FredokaOne.json")
UiKit.Body = SunKit.Swap(Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy))

-- Phones held sideways (short screens) get the phone layout
function UiKit.Phone(gui: ScreenGui): boolean
	local size = gui.AbsoluteSize
	return size.Y > 0 and size.Y < Config.Ui.CompactHeight
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
UiKit.Make = make

function UiKit.Corner(parent: Instance, radius: number): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, math.max(radius, 0)) }, parent)
end

-- Outline on a frame's edge (drawn outside the frame, so frames that need the design's inside border are inset)
function UiKit.Outline(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return make("UIStroke", {
		Color = color or C.Ink,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

-- A plain box with the design's inside border: fill, corner, outline (inset so the outline lands inside size)
function UiKit.Box(
	parent: Instance,
	name: string,
	fill: Color3,
	radius: number,
	outline: number?,
	color: Color3?
): Frame
	local o = outline or 3
	local box = make("Frame", { Name = name, BackgroundColor3 = fill, BorderSizePixel = 0 }, parent)
	UiKit.Corner(box, radius - o)
	if o > 0 then
		UiKit.Outline(box, color, o)
	end
	return box
end

-- Puts a Box at design x, y, w, h (the outer edge of its border)
function UiKit.Place(box: GuiObject, x: number, y: number, w: number, h: number, outline: number?)
	local o = outline or 3
	box.Position = UDim2.fromOffset(x + o, y + o)
	box.Size = UDim2.fromOffset(w - o * 2, h - o * 2)
end

-- Text with the ink outline. stroke = the UIStroke width (half the design's CSS stroke); 0 = none.
function UiKit.Text(parent: Instance, text: string, font: Font, size: number, color: Color3, stroke: number?): TextLabel
	local label = make("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = font,
		Text = text,
		TextSize = size,
		TextColor3 = color,
	}, parent)
	if (stroke or 2.5) > 0 then
		make("UIStroke", { Color = C.Ink, Thickness = stroke or 2.5, LineJoinMode = Enum.LineJoinMode.Round }, label)
	end
	return label
end

function UiKit.Icon(parent: Instance, icon: string, size: number): ImageLabel
	return make("ImageLabel", {
		Name = icon,
		BackgroundTransparency = 1,
		Image = UiKitAssets.Image(icon),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(size, size),
	}, parent)
end

local function scaleOf(object: GuiObject): UIScale
	local scale = object:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = make("UIScale", {}, object)
	end
	return scale :: UIScale
end
UiKit.ScaleOf = scaleOf

local function tween(
	object: Instance,
	time: number,
	style: Enum.EasingStyle,
	props: { [string]: any },
	dir: Enum.EasingDirection?
)
	local t = TweenService:Create(object, TweenInfo.new(time, style, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
UiKit.Tween = tween

-- ===== The chunky block: ink outline, the lip colour underneath, the face on top =====
-- opts: Name, Size (w, h as a Vector2 or UDim2), Fill, Lip, LipPx (6), Radius, Outline (3), Button (true = taps),
-- Ring (inner ring colour, 3 px), Extend (px of extra lip hidden under something else: the book's tabs)
export type Block = {
	Holder: GuiObject,
	Body: Frame,
	Face: Frame,
	Paint: (Block, Color3, Color3) -> (),
	LipPx: number,
}

function UiKit.Block(parent: Instance?, opts: { [string]: any }): Block
	local o = opts.Outline or 3
	local lipPx = opts.LipPx or 6
	local radius = opts.Radius or 14
	local extend = opts.Extend or 0
	local holder = make(if opts.Button then "TextButton" else "Frame", {
		Name = opts.Name or "Block",
		BackgroundTransparency = 1,
		Size = if typeof(opts.Size) == "Vector2" then UDim2.fromOffset(opts.Size.X, opts.Size.Y) else opts.Size,
	})
	if opts.Button then
		(holder :: TextButton).Text = ""
		(holder :: TextButton).AutoButtonColor = false
	end
	local body = make("Frame", {
		Name = "Body",
		BackgroundColor3 = opts.Lip or C.Ink,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(o, o),
		Size = UDim2.new(1, -o * 2, 1, -o * 2 + extend),
		ZIndex = 0, -- under anything else put in the holder
	}, holder)
	UiKit.Corner(body, radius - o)
	if o > 0 then
		UiKit.Outline(body, C.Ink, o)
	end
	local face = make("Frame", {
		Name = "Face",
		BackgroundColor3 = opts.Fill or C.Card,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -lipPx - extend),
	}, body)
	UiKit.Corner(face, radius - o)
	if opts.Ring then
		local ring = make("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
		}, face)
		UiKit.Corner(ring, radius - o - 3)
		UiKit.Outline(ring, opts.Ring, 3)
	end
	local block = { Holder = holder, Body = body, Face = face, LipPx = lipPx } :: any
	function block.Paint(self: Block, fill: Color3, lip: Color3)
		face.BackgroundColor3 = fill
		body.BackgroundColor3 = lip
	end
	if opts.Button then
		UiKit.Press(block)
	end
	if parent then
		holder.Parent = parent
	end
	return block :: Block
end

-- Press feel from the kit: down = move 3 px and the lip shrinks to 2 px (0.06 Quad Out); release = back in
-- 0.1 Back Out with a 1.06 bump; mouse over = 1.04
function UiKit.Press(block: Block)
	local holder = block.Holder :: TextButton
	local scale = scaleOf(holder)
	local restBody = block.Body.Position
	local restFace = block.Face.Size
	local pressedFace = restFace + UDim2.fromOffset(0, block.LipPx - 2)
	local down = false
	local hover = false
	holder.MouseButton1Down:Connect(function()
		down = true
		tween(block.Body, 0.06, Enum.EasingStyle.Quad, { Position = restBody + UDim2.fromOffset(0, 3) })
		tween(block.Face, 0.06, Enum.EasingStyle.Quad, { Size = pressedFace })
	end)
	local function release()
		if not down then
			return
		end
		down = false
		tween(block.Body, 0.1, Enum.EasingStyle.Back, { Position = restBody })
		tween(block.Face, 0.1, Enum.EasingStyle.Back, { Size = restFace })
		scale.Scale = 1.06
		tween(scale, 0.12, Enum.EasingStyle.Quad, { Scale = if hover then 1.04 else 1 })
	end
	holder.MouseButton1Up:Connect(release)
	holder.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled then
			hover = true
			tween(scale, 0.1, Enum.EasingStyle.Quad, { Scale = 1.04 })
		end
	end)
	holder.MouseLeave:Connect(function()
		hover = false
		release()
		tween(scale, 0.1, Enum.EasingStyle.Quad, { Scale = 1 })
	end)
	holder.Activated:Connect(function()
		Sfx.Play("Click", 0.95 + math.random() * 0.1)
	end)
end

-- The red close X (one PNG): mouse over tilts 8 degrees, press shrinks to 0.92
function UiKit.CloseX(parent: Instance, size: number): ImageButton
	local x = make("ImageButton", {
		Name = "Close",
		BackgroundTransparency = 1,
		Image = UiKitAssets.Image("Close"),
		ScaleType = Enum.ScaleType.Fit,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
	}, parent)
	local scale = scaleOf(x)
	x.MouseEnter:Connect(function()
		tween(x, 0.1, Enum.EasingStyle.Quad, { Rotation = 8 })
	end)
	x.MouseLeave:Connect(function()
		tween(x, 0.1, Enum.EasingStyle.Quad, { Rotation = 0 })
		tween(scale, 0.1, Enum.EasingStyle.Quad, { Scale = 1 })
	end)
	x.MouseButton1Down:Connect(function()
		tween(scale, 0.06, Enum.EasingStyle.Quad, { Scale = 0.92 })
	end)
	x.MouseButton1Up:Connect(function()
		tween(scale, 0.1, Enum.EasingStyle.Back, { Scale = 1 })
	end)
	x.Activated:Connect(function()
		Sfx.Play("Click")
	end)
	return x
end

-- Full-screen dark backdrop (#04061A at 62%) that closes the window when tapped. It covers Roblox's top bar too.
function UiKit.Backdrop(parent: Instance): TextButton
	local inset = game:GetService("GuiService"):GetGuiInset()
	return make("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.38,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, -inset.Y),
		Size = UDim2.new(1, 0, 1, inset.Y),
	}, parent)
end

-- Window opens: backdrop fades in (0.15 Linear); panel UIScale 0.6 -> 1.05 (0.18 Back Out) -> 1 (0.08 Quad Out)
-- while it rises 40 px into place (0.18 Quad Out). screen = the full-screen frame holding both.
local tokens: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
function UiKit.Open(screen: GuiObject, backdrop: GuiObject, panel: GuiObject, scale: UIScale)
	tokens[screen] = (tokens[screen] or 0) + 1
	local token = tokens[screen]
	screen.Visible = true
	backdrop.BackgroundTransparency = 1
	tween(backdrop, 0.15, Enum.EasingStyle.Linear, { BackgroundTransparency = 0.38 })
	local rest = panel:GetAttribute("RestPosition") or panel.Position
	panel:SetAttribute("RestPosition", rest)
	panel.Position = rest + UDim2.fromOffset(0, 40)
	tween(panel, 0.18, Enum.EasingStyle.Quad, { Position = rest })
	scale.Scale = 0.6
	tween(scale, 0.18, Enum.EasingStyle.Back, { Scale = 1.05 }).Completed:Once(function()
		if tokens[screen] == token then
			tween(scale, 0.08, Enum.EasingStyle.Quad, { Scale = 1 })
		end
	end)
end

-- Window closes: panel UIScale -> 0.85 (0.12 Quad In), backdrop fades out, then hidden.
-- (The kit also fades the panel's GroupTransparency; that needs a CanvasGroup, which blurs the 3D balls, so it shrinks only.)
function UiKit.Close(screen: GuiObject, backdrop: GuiObject, scale: UIScale)
	if not screen.Visible then
		return
	end
	tokens[screen] = (tokens[screen] or 0) + 1
	local token = tokens[screen]
	tween(backdrop, 0.12, Enum.EasingStyle.Linear, { BackgroundTransparency = 1 })
	local base = scale.Scale
	tween(scale, 0.12, Enum.EasingStyle.Quad, { Scale = base * 0.85 }, Enum.EasingDirection.In).Completed:Once(
		function()
			if tokens[screen] == token then
				screen.Visible = false
			end
		end
	)
end

-- Esc and the gamepad B button call fn while the screen is open
function UiKit.CloseKeys(screen: GuiObject, fn: () -> ())
	UserInputService.InputBegan:Connect(function(input, processed)
		if screen.Visible and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			if not processed or input.KeyCode == Enum.KeyCode.ButtonB then
				fn()
			end
		end
	end)
end

return UiKit
