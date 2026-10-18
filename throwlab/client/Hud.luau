-- On-screen parts of the test lane: the charge bar, PERFECT pop, STRIKE text, streak counter,
-- screen flash, and the Power and Reset buttons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Settings = require(ReplicatedStorage:WaitForChild("ThrowLab"):WaitForChild("ThrowSettings"))

local Hud = {}

local PINK = Color3.fromRGB(255, 43, 214)
local GOLD = Color3.fromRGB(255, 200, 40)
local CYAN = Color3.fromRGB(70, 230, 255)
local DARK = Color3.fromRGB(28, 16, 52)
local INK = Color3.fromRGB(40, 10, 60)

local gui = Instance.new("ScreenGui")
gui.Name = "ThrowLabHud"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
end

local function stroke(parent: Instance, thickness: number, color: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or INK
	s.Parent = parent
	return s
end

local function text(name: string, props: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = props.Parent or gui
	return label
end

---------------------------------------------------------------------------
-- Screen flash
---------------------------------------------------------------------------
local flash = Instance.new("Frame")
flash.Name = "Flash"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.new(1, 1, 1)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.ZIndex = 1
flash.Parent = gui

function Hud.Flash(color: Color3, strength: number, time: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
	TweenService
		:Create(
			flash,
			TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		:Play()
end

---------------------------------------------------------------------------
-- Charge bar
---------------------------------------------------------------------------
local barHolder = Instance.new("Frame")
barHolder.Name = "ChargeBar"
barHolder.AnchorPoint = Vector2.new(0.5, 1)
barHolder.Position = UDim2.new(0.5, 0, 1, -70)
barHolder.Size = UDim2.new(0.62, 0, 0, 30)
barHolder.BackgroundColor3 = DARK
barHolder.BackgroundTransparency = 0.15
barHolder.ZIndex = 5
barHolder.Parent = gui
corner(barHolder, 15)
local barStroke = stroke(barHolder, 3, Color3.fromRGB(120, 80, 200))
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(460, 30)
limit.Parent = barHolder
local barScale = Instance.new("UIScale")
barScale.Parent = barHolder

local sweet = Instance.new("Frame")
sweet.Name = "SweetSpot"
sweet.AnchorPoint = Vector2.new(0.5, 0.5)
sweet.Position = UDim2.fromScale(Settings.SweetSpotCenter, 0.5)
sweet.Size = UDim2.new(Settings.SweetSpotSize, 0, 1, 8)
sweet.BackgroundColor3 = GOLD
sweet.BackgroundTransparency = 0.45
sweet.ZIndex = 6
sweet.Parent = barHolder
corner(sweet, 6)
stroke(sweet, 2, GOLD)

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = PINK
fill.ZIndex = 7
fill.Parent = barHolder
corner(fill, 15)

local needle = Instance.new("Frame")
needle.Name = "Needle"
needle.AnchorPoint = Vector2.new(0.5, 0.5)
needle.Position = UDim2.fromScale(0, 0.5)
needle.Size = UDim2.new(0, 6, 1, 14)
needle.BackgroundColor3 = Color3.new(1, 1, 1)
needle.ZIndex = 8
needle.Parent = barHolder
corner(needle, 3)

local hint = text("Hint", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -108),
	Size = UDim2.new(0.8, 0, 0, 26),
	Text = "HOLD TO CHARGE  -  LET GO IN THE GOLD",
	ZIndex = 5,
})
stroke(hint, 2)
local hintLimit = Instance.new("UITextSizeConstraint")
hintLimit.MaxTextSize = 24
hintLimit.Parent = hint

function Hud.SetCharge(value: number, inSweetSpot: boolean, charging: boolean)
	fill.Size = UDim2.fromScale(value, 1)
	needle.Position = UDim2.fromScale(value, 0.5)
	fill.BackgroundColor3 = inSweetSpot and GOLD or PINK
	barStroke.Color = inSweetSpot and GOLD or (charging and PINK or Color3.fromRGB(120, 80, 200))
	barScale.Scale = inSweetSpot and 1.06 or 1
	barHolder.BackgroundTransparency = charging and 0.05 or 0.35
end

function Hud.ShowHint(visible: boolean)
	hint.Visible = visible
end

---------------------------------------------------------------------------
-- Popping text: PERFECT, STRIKE / streak names, pin counts
---------------------------------------------------------------------------
local function popLabel(name: string, position: UDim2, size: UDim2): (TextLabel, UIScale, UIStroke)
	local label = text(name, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = size,
		Text = "",
		Visible = false,
		ZIndex = 10,
	})
	local s = stroke(label, 4)
	local scale = Instance.new("UIScale")
	scale.Parent = label
	return label, scale, s
end

local perfectLabel, perfectScale, perfectStroke =
	popLabel("Perfect", UDim2.fromScale(0.5, 0.68), UDim2.new(0.6, 0, 0, 64))
local bigLabel, bigScale, bigStroke = popLabel("Big", UDim2.fromScale(0.5, 0.33), UDim2.fromScale(0.5, 0.11))
local smallLabel, smallScale, smallStroke = popLabel("Small", UDim2.fromScale(0.5, 0.36), UDim2.new(0.5, 0, 0, 56))

local popRuns: { [TextLabel]: number } = {}
local function pop(
	label: TextLabel,
	scale: UIScale,
	s: UIStroke,
	message: string,
	color: Color3,
	size: number,
	time: number
)
	popRuns[label] = (popRuns[label] or 0) + 1
	local run = popRuns[label]
	label.Text = message
	label.TextColor3 = color
	label.TextTransparency = 0
	s.Transparency = 0
	label.Rotation = (math.random() - 0.5) * 8
	label.Visible = true
	scale.Scale = size * 0.3
	TweenService
		:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = size * 1.12 })
		:Play()
	task.delay(0.14, function()
		if run == popRuns[label] then
			TweenService:Create(scale, TweenInfo.new(0.1), { Scale = size }):Play()
		end
	end)
	task.delay(time * 0.65, function()
		if run ~= popRuns[label] then
			return
		end
		local fade = TweenInfo.new(time * 0.35)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(s, fade, { Transparency = 1 }):Play()
		TweenService:Create(scale, fade, { Scale = size * 1.1 }):Play()
	end)
	task.delay(time, function()
		if run == popRuns[label] then
			label.Visible = false
		end
	end)
end

function Hud.Perfect()
	pop(perfectLabel, perfectScale, perfectStroke, "PERFECT!", GOLD, 1, 0.6)
end

-- The big celebration text. size 1 = normal; streaks make it bigger.
function Hud.Big(message: string, color: Color3, size: number)
	pop(bigLabel, bigScale, bigStroke, message, color, size, Settings.CelebrationTime)
end

-- Quick small text for throws that aren't strikes
function Hud.Small(message: string, color: Color3?)
	pop(smallLabel, smallScale, smallStroke, message, color or Color3.new(1, 1, 1), 1, 0.55)
end

---------------------------------------------------------------------------
-- Streak counter (top middle)
---------------------------------------------------------------------------
local streakLabel = text("Streak", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.new(0.4, 0, 0, 34),
	Text = "",
	TextColor3 = GOLD,
	ZIndex = 5,
})
stroke(streakLabel, 3)
local streakScale = Instance.new("UIScale")
streakScale.Parent = streakLabel

function Hud.SetStreak(streak: number)
	streakLabel.Text = streak > 0 and ("STRIKE STREAK  x" .. streak) or ""
	if streak > 0 then
		streakScale.Scale = 1.4
		TweenService
			:Create(streakScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end
end

---------------------------------------------------------------------------
-- Buttons (top right): ball Power - / +, and Reset
---------------------------------------------------------------------------
local panel = Instance.new("Frame")
panel.Name = "Buttons"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -16, 0, 56)
panel.Size = UDim2.fromOffset(330, 48)
panel.BackgroundTransparency = 1
panel.ZIndex = 5
panel.Parent = gui
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Horizontal
list.HorizontalAlignment = Enum.HorizontalAlignment.Right
list.VerticalAlignment = Enum.VerticalAlignment.Center
list.Padding = UDim.new(0, 8)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = panel

local function button(name: string, label: string, width: number, color: Color3, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = UDim2.fromOffset(width, 48)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.FredokaOne
	b.Text = label
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextSize = 22
	b.AutoButtonColor = true
	b.LayoutOrder = order
	b.ZIndex = 5
	b.Parent = panel
	corner(b, 12)
	stroke(b, 2.5)
	local textStroke = Instance.new("UIStroke")
	textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	textStroke.Thickness = 2
	textStroke.Color = INK
	textStroke.Parent = b
	return b
end

local minus = button("PowerDown", "-", 48, DARK, 1)
local powerLabel = text("Power", {
	Size = UDim2.fromOffset(120, 48),
	Text = "POWER 100",
	TextColor3 = CYAN,
	LayoutOrder = 2,
	ZIndex = 5,
	Parent = panel,
})
stroke(powerLabel, 2.5)
local plus = button("PowerUp", "+", 48, DARK, 3)
local reset = button("Reset", "RESET", 92, PINK, 4)

Hud.ResetPressed = reset.Activated
Hud.PowerDownPressed = minus.Activated
Hud.PowerUpPressed = plus.Activated

function Hud.SetPower(power: number)
	powerLabel.Text = "POWER " .. power
end

return Hud
