-- Shared UI effects: button press feedback, panels that tween in and out, screen flash, confetti,
-- and an overlay layer for things like flying coins.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Sfx = require(script.Parent.Sfx)
local Motion = require(script.Parent.Motion)
local MOTION = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config")).Motion

local player = Players.LocalPlayer

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 60, 210),
	Color3.fromRGB(60, 230, 255),
	Color3.fromRGB(255, 240, 90),
	Color3.fromRGB(120, 255, 120),
	Color3.fromRGB(255, 255, 255),
}
local BACK_OUT = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BACK_IN = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.In)

local UiFx = {}

local layer: ScreenGui? = nil
local flash: Frame? = nil
local pressable = setmetatable({}, { __mode = "k" })
local closeTokens = setmetatable({}, { __mode = "k" })

-- Overlay above the HUD, same coordinates as the HUD (it doesn't ignore the top bar either)
function UiFx.Layer(): ScreenGui
	if layer and layer.Parent then
		return layer
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FxUI"
	gui.DisplayOrder = 3
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	local frame = Instance.new("Frame")
	frame.Name = "Flash"
	frame.Size = UDim2.new(1, 0, 1, 120)
	frame.Position = UDim2.fromOffset(0, -60)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
	layer = gui
	flash = frame
	return gui
end

function UiFx.Flash(color: Color3?, strength: number?, time: number?)
	UiFx.Layer()
	local frame = flash :: Frame
	frame.BackgroundColor3 = color or Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 1 - (strength or 0.6)
	TweenService:Create(frame, TweenInfo.new(time or 0.35), { BackgroundTransparency = 1 }):Play()
end

local function getScale(object: GuiObject): UIScale
	local scale = object:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = object
	end
	return scale :: UIScale
end

-- Quick "boing": jumps to `from` and springs back to normal size
function UiFx.Pop(object: GuiObject, from: number?, time: number?)
	local scale = getScale(object)
	scale.Scale = from or 1.2
	TweenService
		:Create(scale, TweenInfo.new(time or 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

-- Shrinks a little while held, springs back on release, clicks when activated
function UiFx.Press(button: GuiButton, silent: boolean?)
	if pressable[button] then
		return
	end
	pressable[button] = true
	-- (Polish v2 D1: springs, so fast taps never leave a button stuck half-pressed)
	local scale = getScale(button)
	local down = false
	button.MouseButton1Down:Connect(function()
		down = true
		Motion.Spring(scale, "Scale", MOTION.ButtonDown, "Snap")
	end)
	local function release()
		if down then
			down = false
			Motion.Spring(scale, "Scale", 1, "Pop", { Velocity = MOTION.ButtonKick })
		end
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	if not silent then
		button.Activated:Connect(function()
			Sfx.Play("Click", 0.95 + math.random() * 0.1)
		end)
	end
end

-- Panels grow in from small...
function UiFx.Open(panel: GuiObject)
	closeTokens[panel] = (closeTokens[panel] or 0) + 1
	local scale = getScale(panel)
	panel.Visible = true
	scale.Scale = 0.6
	TweenService:Create(scale, BACK_OUT, { Scale = 1 }):Play()
end

-- ...and shrink away when closed
function UiFx.Close(panel: GuiObject)
	if not panel.Visible then
		return
	end
	closeTokens[panel] = (closeTokens[panel] or 0) + 1
	local token = closeTokens[panel]
	local tween = TweenService:Create(getScale(panel), BACK_IN, { Scale = 0.5 })
	tween.Completed:Once(function()
		if closeTokens[panel] == token then
			panel.Visible = false
		end
	end)
	tween:Play()
end

-- Paper confetti falling over a frame (or the overlay layer if none given)
function UiFx.Confetti(container: GuiObject?, count: number?, colors: { Color3 }?)
	local parent = container or UiFx.Layer()
	local palette = colors or CONFETTI_COLORS
	for _ = 1, count or 40 do
		local piece = Instance.new("Frame")
		piece.BorderSizePixel = 0
		piece.BackgroundColor3 = palette[math.random(#palette)]
		piece.Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22))
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Position = UDim2.new(math.random(), 0, -0.05, -math.random(0, 200))
		piece.Rotation = math.random(0, 360)
		piece.ZIndex = 50
		piece.Parent = parent

		local fallTime = 1.8 + math.random() * 1.4
		TweenService:Create(piece, TweenInfo.new(fallTime, Enum.EasingStyle.Linear), {
			Position = UDim2.fromScale(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 1.1),
			Rotation = piece.Rotation + math.random(-540, 540),
		}):Play()
		task.delay(fallTime, piece.Destroy, piece)
	end
end

return UiFx
