-- The owner's Strike Legends UI look (first design batch, 2026-10-22): colours, fonts and small builders
-- for the layered, thick-outlined text the designs use. Roblox has no Rubik or Lilita One, so
-- Montserrat Heavy Italic stands in for Rubik 900 italic, Fredoka One for Lilita One, Roboto Mono for JetBrains Mono.
local Currency = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Modules.Currency)
local SunKit = require(script.Parent:WaitForChild("SunKit"))

local SlUi = {}

local function rgb(hex: string): Color3
	return Color3.fromHex(hex)
end
SlUi.Hex = rgb

SlUi.Colors = {
	Ink = rgb("04061A"), -- the outline under every number
	Navy = rgb("070B1E"),
	Track = rgb("141C3D"),
	Cyan = rgb("2BE4FF"),
	CyanDeep = rgb("0090FF"),
	CyanPale = rgb("E8FFFF"),
	Gold = rgb("FFC93A"),
	GoldBright = rgb("FFD23F"),
	Red = rgb("FF2D4A"),
	Pink = rgb("FF4FB0"),
	Hook = rgb("FF4FC8"),
	HotPink = rgb("FF2D95"),
	Muted = rgb("9AA3D6"),
	Grey = rgb("7B84B8"),
	White = Color3.new(1, 1, 1),
}

SlUi.Heavy = SunKit.Swap(Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic))
SlUi.Round = Font.new("rbxasset://fonts/families/FredokaOne.json")
SlUi.Mono = SunKit.Swap(Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Medium))

function SlUi.Corner(parent: GuiObject, radius: UDim?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UDim.new(0.5, 0)
	corner.Parent = parent
	return corner
end

function SlUi.Stroke(parent: GuiObject, color: Color3, thickness: number, transparency: number?, border: boolean?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	if border then
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	stroke.Parent = parent
	return stroke
end

-- Vertical colour gradient, top to bottom: { {0, color}, {0.5, color}, ... }
function SlUi.Gradient(parent: GuiObject, stops: { { any } }, rotation: number?)
	local keys = {}
	for _, stop in stops do
		table.insert(keys, ColorSequenceKeypoint.new(stop[1], stop[2]))
	end
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(keys)
	gradient.Rotation = rotation or 90
	gradient.Parent = parent
	return gradient
end

-- A plain text label filling its parent (no background)
function SlUi.Label(parent: Instance, text: string, font: Font, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = font
	label.Text = text
	label.TextSize = size
	label.TextColor3 = color
	label.Parent = parent
	return label
end

-- The designs' stacked text: each layer is the same word drawn again on top, widest outline first.
-- layers = { { Color = c, Stroke = c, Width = px, Gradient = stops?, Transparency = t? }, ... }
function SlUi.Layered(parent: Instance, text: string, font: Font, size: number, layers: { any }): { TextLabel }
	local labels = {}
	for i, layer in layers do
		local label = SlUi.Label(parent, text, font, size, layer.Color or SlUi.Colors.White)
		label.ZIndex = (layer.Z or 10) + i
		label.TextTransparency = layer.Transparency or 0
		if layer.Width and layer.Width > 0 then
			SlUi.Stroke(label, layer.Stroke or layer.Color, layer.Width, layer.StrokeTransparency)
		end
		if layer.Gradient then
			SlUi.Gradient(label, layer.Gradient)
		end
		if layer.Offset then
			label.Position = UDim2.new(0.5, layer.Offset.X, 0.5, layer.Offset.Y)
		end
		table.insert(labels, label)
	end
	return labels
end

function SlUi.Format(n: number): string
	return Currency.Format(n)
end

return SlUi
