-- Addendum 4 Stage 3d: the sunny look (Config.Ui.Sunny). One palette and two fonts for the rooftop UI, after the
-- owner's simulator refs (assets/ui_refs_addendum4) and the Addendum 4 UI rules: flat fills, one hard shadow straight
-- below (no blur), thick dark outlines, light panels with dark text, corners that differ by element.
-- HudKit takes its colours from here while Sunny is on; CoreHudController and CoreShopController build with it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local SunKit = {}

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

-- Colours. Paint pairs are { face, the darker shadow/lip under it }.
SunKit.C = {
	Ink = hex("1E2433"), -- outlines, hard shadows, dark text
	Muted = hex("6E6552"), -- second-line text on light panels
	Cream = hex("FFF6DF"), -- light panels
	CreamLip = hex("D9C9A0"),
	Sand = hex("F1E4C2"), -- cards and tracks inside a light panel
	Track = hex("3A4152"), -- dark bar tracks
	Sky = hex("38B6FF"),
	SkyLip = hex("1C82C4"),
	Sun = hex("FFD23F"),
	SunLip = hex("D49E0F"),
	Green = hex("5CD43A"),
	GreenLip = hex("369E1C"),
	Coral = hex("FF6F4F"),
	CoralLip = hex("CC4428"),
	Purple = hex("9D6BFF"),
	PurpleLip = hex("6B42CC"),
	Red = hex("F23A3A"),
	RedLip = hex("A81E1E"),
	Grey = hex("A9AEB8"),
	GreyLip = hex("767C88"),
	White = Color3.new(1, 1, 1),
}
local C = SunKit.C

-- Two fonts: Fredoka One for numbers, headers and buttons; Builder Sans for body lines
SunKit.Display = Font.new("rbxasset://fonts/families/FredokaOne.json")
SunKit.Body = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

-- Old kit fonts -> the two sunny fonts while Config.Ui.Sunny is on (Luckiest Guy / Montserrat -> Fredoka One,
-- Gotham / Roboto Mono -> Builder Sans). Anything else stays.
function SunKit.Swap(font: Font): Font
	if Config.Ui.Sunny ~= true then
		return font
	end
	local family = font.Family
	if family:find("LuckiestGuy") or family:find("Montserrat") then
		return SunKit.Display
	elseif family:find("GothamSSm") or family:find("RobotoMono") then
		local heavy = font.Weight == Enum.FontWeight.Heavy or font.Weight == Enum.FontWeight.ExtraBold
		return Font.new(SunKit.Body.Family, if heavy then Enum.FontWeight.ExtraBold else Enum.FontWeight.Bold)
	end
	return font
end

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end
SunKit.New = new

-- Text that fills its box. Light text gets the ink outline (on buttons and colour plates); dark text on a light
-- panel gets none. props.Body = the body font.
function SunKit.Text(parent: Instance, value: string, props: { [string]: any }?): TextLabel
	local p = props or {}
	local color = p.TextColor3 or C.White
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = if p.Body then SunKit.Body else SunKit.Display,
		Text = value,
		TextColor3 = color,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}, parent)
	local dark = (color.R + color.G + color.B) < 1.2
	if not dark and p.Stroke ~= 0 then
		new("UIStroke", {
			Name = "Stroke",
			Color = C.Ink,
			Thickness = p.Stroke or 2,
			LineJoinMode = Enum.LineJoinMode.Round,
		}, label)
	end
	for key, v in p do
		if key ~= "Body" and key ~= "Stroke" then
			(label :: any)[key] = v
		end
	end
	return label
end

-- Text colour that also adds or drops the outline (light text needs it, dark text doesn't)
function SunKit.Recolor(label: TextLabel, color: Color3)
	label.TextColor3 = color
	local stroke = label:FindFirstChild("Stroke") :: UIStroke?
	local dark = (color.R + color.G + color.B) < 1.2
	if dark and stroke then
		stroke.Enabled = false
	elseif not dark then
		if not stroke then
			stroke = new("UIStroke", {
				Name = "Stroke",
				Color = C.Ink,
				Thickness = 2,
				LineJoinMode = Enum.LineJoinMode.Round,
			}, label)
		end
		(stroke :: UIStroke).Enabled = true
	end
end

-- A flat plate: face colour, thick ink outline, and one hard shadow straight below (the lip colour, or ink).
-- Returns (holder, face). The holder is what you size and place.
function SunKit.Plate(
	parent: Instance,
	name: string,
	color: Color3,
	radius: number,
	drop: number?,
	lip: Color3?
): (Frame, Frame)
	local holder = new("Frame", { Name = name, BackgroundTransparency = 1 }, parent)
	local shadow = new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = lip or C.Ink,
		Position = UDim2.fromOffset(0, drop or 4),
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, shadow)
	new("UIStroke", { Color = C.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, shadow)
	local face = new("Frame", {
		Name = "Face",
		BackgroundColor3 = color,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, face)
	new("UIStroke", { Color = C.Ink, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
	return holder, face
end

-- Recolours a plate made by SunKit.Plate (face + its shadow)
function SunKit.Paint(holder: Frame, color: Color3, lip: Color3?)
	local face = holder:FindFirstChild("Face") :: Frame?
	local shadow = holder:FindFirstChild("Shadow") :: Frame?
	if face then
		face.BackgroundColor3 = color
	end
	if shadow then
		shadow.BackgroundColor3 = lip or C.Ink
	end
end

-- The button pairs by face colour, so a plate can find its own lip
local LIPS = {
	[C.Sky] = C.SkyLip,
	[C.Sun] = C.SunLip,
	[C.Green] = C.GreenLip,
	[C.Coral] = C.CoralLip,
	[C.Purple] = C.PurpleLip,
	[C.Red] = C.RedLip,
	[C.Grey] = C.GreyLip,
	[C.Cream] = C.CreamLip,
}
function SunKit.Lip(color: Color3): Color3
	return LIPS[color] or C.Ink
end

return SunKit
