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
	Paper = hex("FFFDF5"), -- cards on a sand page
	Dim = hex("E6D8B4"), -- empty slots, locked cards
	Faded = hex("A0957A"), -- third-line text, empty-slot marks
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

-- ===== Daylight (3d-2): white text left on a light panel turns dark =====
-- The windows were built for dark panels with white text. Their panels are cream now (HudKit/UiKit palettes), so
-- any light text whose backdrop (the nearest filled frame above it) is light turns ink, grey text turns muted, and
-- coloured text without an outline gets darker. Labels with the KeepColor attribute are left alone.
local function luma(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end
local function chroma(c: Color3): number
	return math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B)
end

-- The colour this label sits on: its own fill, or the nearest filled frame above it
local function backdrop(label: GuiObject): Color3?
	local node: Instance? = label
	while node and node:IsA("GuiObject") do
		local filled = node:IsA("Frame")
			or node:IsA("CanvasGroup")
			or node:IsA("TextLabel")
			or node:IsA("TextButton")
			or node:IsA("ScrollingFrame")
		if filled and (node :: GuiObject).BackgroundTransparency < 0.4 then
			return (node :: GuiObject).BackgroundColor3
		end
		node = node.Parent
	end
	return nil
end

local function outlined(label: Instance): boolean
	for _, child in label:GetChildren() do
		if child:IsA("UIStroke") and child.Enabled and child.Thickness >= 1 and luma(child.Color) < 0.3 then
			return true
		end
	end
	return false
end

local busy: { [Instance]: boolean } = {}
local function fix(label: TextLabel | TextButton | TextBox)
	if busy[label] or label:GetAttribute("KeepColor") then
		return
	end
	local under = backdrop(label)
	if not under or luma(under) < 0.75 or chroma(under) > 0.25 then
		return -- dark or coloured backdrop: light text stays
	end
	local color = label.TextColor3
	local new: Color3? = nil
	local dropStroke = false
	if chroma(color) < 0.2 then
		if luma(color) > 0.7 then
			new, dropStroke = C.Ink, true
		elseif luma(color) > 0.35 then
			new, dropStroke = C.Muted, true
		end
	elseif luma(color) > 0.45 and not outlined(label) then
		-- the same hue, deeper (yellows lean amber, a darker yellow reads olive)
		local h, s = color:ToHSV()
		if h > 0.09 and h < 0.2 then
			h = 0.11
		end
		new = Color3.fromHSV(h, math.max(s, 0.8), 0.7)
	end
	if not new then
		return
	end
	busy[label] = true
	label.TextColor3 = new
	if dropStroke then
		label.TextStrokeTransparency = 1
		for _, child in label:GetChildren() do
			if child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
				child.Enabled = false
			end
		end
	end
	busy[label] = nil
end

local watched = setmetatable({}, { __mode = "k" }) :: { [Instance]: boolean }
local function watch(object: Instance)
	if not (object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox")) then
		return
	end
	task.defer(fix, object)
	if not watched[object] then
		watched[object] = true
		object:GetPropertyChangedSignal("TextColor3"):Connect(function()
			task.defer(fix, object)
		end)
	end
end

-- Runs over a ScreenGui now and on everything added to it later
function SunKit.Daylight(gui: Instance)
	if Config.Ui.Sunny ~= true then
		return
	end
	for _, object in gui:GetDescendants() do
		watch(object)
	end
	gui.DescendantAdded:Connect(watch)
end

-- A night-look board in the world (lane scoreboards, the leaderboard wall), repainted on this screen: navy
-- screens turn cream (nested ones sand), the dark backdrop gradient turns flat sky, neon frame rings turn ink,
-- then Daylight darkens the text. Studio-built boards, so the place file keeps the night look (Sunny off = as is).
function SunKit.Board(gui: LayerCollector)
	if Config.Ui.Sunny ~= true then
		return
	end
	local painted: { [Instance]: boolean } = {}
	for _, object in gui:GetDescendants() do
		if object:IsA("Frame") and object.BackgroundTransparency < 0.4 then
			local color = object.BackgroundColor3
			if object.Name == "Background" then
				object.BackgroundColor3 = C.Sky
				painted[object] = true
			elseif luma(color) < 0.2 then
				local nested = false
				local node = object.Parent
				while node and node ~= gui do
					if painted[node] and node.Name ~= "Background" then
						nested = true
					end
					node = node.Parent
				end
				object.BackgroundColor3 = if object.Name == "AvatarFrame"
					then C.Dim
					elseif nested then C.Sand
					else C.Cream
				object.BackgroundTransparency = 0
				painted[object] = true
			end
			if painted[object] then
				for _, child in object:GetChildren() do
					if child:IsA("UIGradient") then
						child.Enabled = false
					elseif child:IsA("UIStroke") and child.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
						if chroma(child.Color) > 0.5 and child.Color.B > 0.6 then
							child.Color = C.Ink -- neon cyan / pink rings
						end
					end
				end
			end
		end
	end
	-- White text left on the sky backdrop gets the ink outline
	for _, object in gui:GetDescendants() do
		if object:IsA("TextLabel") and backdrop(object) == C.Sky and not object:FindFirstChildWhichIsA("UIStroke") then
			new("UIStroke", { Color = C.Ink, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round }, object)
		end
	end
	SunKit.Daylight(gui)
end

return SunKit
