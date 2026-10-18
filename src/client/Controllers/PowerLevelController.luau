-- The Power Level button on the left of the screen: your level, what the next one adds, and how close you are.
-- It fills up as coins come in and glows "BUY!" once you can afford it. Buying plays a power-up moment;
-- the bigger ball shows in your hand right away and on the lane from the very next throw.
-- Built in code (not in Studio), so it lives in git. Prices: Config.Economy.PowerLevels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PowerLevels = require(Shared.Modules.PowerLevels)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local player = Players.LocalPlayer

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local INK = Color3.fromHex("06060F")
local GOLD = Color3.fromRGB(255, 200, 40)
local PINK = Color3.fromRGB(255, 43, 214)
local CYAN = Color3.fromRGB(70, 230, 255)
local GREY = Color3.fromRGB(120, 110, 150)

-- Where the button sits: under the ball menu, or (short phone screens) under the free-crate bar
local NORMAL = { Position = UDim2.fromOffset(16, 372), Size = UDim2.fromOffset(176, 66) }
local COMPACT = { Position = UDim2.fromOffset(12, 196), Size = UDim2.fromOffset(150, 50) }

local PowerLevelController = {}

local function short(n: number): string
	if n >= 1e12 then
		return ("%.3gT"):format(n / 1e12)
	elseif n >= 1e9 then
		return ("%.3gB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.3gM"):format(n / 1e6)
	elseif n >= 1e4 then
		return ("%.3gK"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end

local function label(parent: Instance, name: string, position: UDim2, size: UDim2, color: Color3): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.BackgroundTransparency = 1
	text.Position = position
	text.Size = size
	text.FontFace = FONT
	text.TextScaled = true
	text.TextColor3 = color
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.ZIndex = 3
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 1.5
	stroke.Parent = text
	text.Parent = parent
	return text
end

-- The big "POWER LEVEL 3!" moment in the middle of the screen
local function celebrate(level: number)
	local layer = UiFx.Layer()
	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.38)
	banner.Size = UDim2.new(0.6, 0, 0, 70)
	banner.BackgroundTransparency = 1
	banner.FontFace = FONT
	banner.TextScaled = true
	banner.TextColor3 = GOLD
	banner.Text = ("POWER LEVEL %d!"):format(level)
	banner.ZIndex = 40
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = banner
	local sub = banner:Clone()
	sub.Position = UDim2.new(0.5, 0, 0.38, 56)
	sub.Size = UDim2.new(0.5, 0, 0, 30)
	sub.TextColor3 = CYAN
	local new = PowerLevels.NewText(level)
	sub.Text = if new ~= "" then new .. " - THROW TO SEE IT!" else "THROW TO SEE IT!"
	banner.Parent = layer
	sub.Parent = layer
	UiFx.Pop(banner, 1.8, 0.45)
	UiFx.Pop(sub, 0.4, 0.45)
	UiFx.Flash(GOLD, 0.45, 0.4)
	UiFx.Confetti(nil, 50)
	Sfx.Play("PowerUp")
	task.delay(1.8, function()
		for _, object in { banner, sub } do
			TweenService:Create(object, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TweenService:Create(object:FindFirstChildOfClass("UIStroke") :: UIStroke, TweenInfo.new(0.3), {
				Transparency = 1,
			}):Play()
			task.delay(0.35, object.Destroy, object)
		end
	end)
end

function PowerLevelController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buyRemote = remotes:WaitForChild("BuyPowerLevel") :: RemoteFunction
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "PowerUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = (hud.DisplayOrder or 0)
	gui.IgnoreGuiInset = hud.IgnoreGuiInset

	local button = Instance.new("TextButton")
	button.Name = "PowerButton"
	button.Text = ""
	button.AutoButtonColor = false
	button.BackgroundColor3 = INK
	button.BackgroundTransparency = 0.15
	button.Position = NORMAL.Position
	button.Size = NORMAL.Size
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	local outline = Instance.new("UIStroke")
	outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outline.Thickness = 2
	outline.Color = GREY
	outline.Parent = button

	-- The goal bar: fills with your coins toward the next level's price
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = PINK
	fill.BackgroundTransparency = 0.55
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 2
	fill.Parent = button
	local fillCorner = corner:Clone()
	fillCorner.Parent = fill

	local title = label(button, "Title", UDim2.new(0, 10, 0.08, 0), UDim2.new(1, -20, 0.4, 0), Color3.new(1, 1, 1))
	local detail = label(button, "Detail", UDim2.new(0, 10, 0.52, 0), UDim2.new(1, -20, 0.36, 0), GOLD)

	local pulse: Tween? = nil
	local function setPulse(on: boolean)
		if on and not pulse then
			outline.Thickness = 2
			pulse = TweenService:Create(
				outline,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Thickness = 5 }
			)
			pulse:Play()
		elseif not on and pulse then
			pulse:Cancel()
			pulse = nil
			outline.Thickness = 2
		end
	end

	local wasAffordable = false
	local function refresh()
		local level = math.clamp(player:GetAttribute("PowerLevel") or 1, 1, PowerLevels.Max)
		local nextRow = PowerLevels.Next(level)
		if not nextRow then
			title.Text = ("POWER LV %d"):format(level)
			detail.Text = "MAX POWER!"
			fill.Size = UDim2.fromScale(1, 1)
			fill.BackgroundColor3 = GOLD
			outline.Color = GOLD
			setPulse(false)
			return
		end
		local coins = player:GetAttribute("Coins") or 0
		local affordable = coins >= nextRow.Price
		local new = PowerLevels.NewText(nextRow.Level)
		title.Text = ("POWER LV %d"):format(level)
		detail.Text = if affordable
			then ("BUY LV %d! %s"):format(nextRow.Level, short(nextRow.Price))
			else ("LV %d: %s / %s"):format(nextRow.Level, short(coins), short(nextRow.Price))
		if new ~= "" and affordable then
			title.Text = ("+ %s"):format(new)
		end
		fill.BackgroundColor3 = if affordable then GOLD else PINK
		TweenService:Create(fill, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(math.clamp(coins / math.max(nextRow.Price, 1), 0, 1), 1),
		}):Play()
		outline.Color = if affordable then GOLD else GREY
		setPulse(affordable)
		if affordable and not wasAffordable then
			UiFx.Pop(button, 1.2)
		end
		wasAffordable = affordable
	end

	UiFx.Press(button)
	local buying = false
	button.Activated:Connect(function()
		if buying then
			return
		end
		buying = true
		local ok, result = pcall(buyRemote.InvokeServer, buyRemote)
		buying = false
		if ok and result and result.Ok then
			celebrate(result.Level)
		else
			UiFx.Pop(button, 0.85)
		end
	end)

	-- Studio only: a test button that gives the coins for the next level (the server ignores it in the live game)
	local testRemote = remotes:FindFirstChild("TestCoins") :: RemoteEvent?
	if testRemote then
		local test = Instance.new("TextButton")
		test.Name = "TestCoins"
		test.Text = "TEST: +COINS"
		test.FontFace = FONT
		test.TextScaled = true
		test.TextColor3 = Color3.new(1, 1, 1)
		test.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		test.AnchorPoint = Vector2.new(0, 0)
		test.Position = UDim2.new(0, 0, 1, 4)
		test.Size = UDim2.new(1, 0, 0, 20)
		test.Parent = button
		local testCorner = Instance.new("UICorner")
		testCorner.Parent = test
		test.Activated:Connect(function()
			testRemote:FireServer()
		end)
	end

	-- Compact layout on short screens (phones held sideways), like ScreenLayout does for the Studio-built UI
	local function layout()
		local compact = hud.AbsoluteSize.Y > 0 and hud.AbsoluteSize.Y < Config.Ui.CompactHeight
		local spot = if compact then COMPACT else NORMAL
		button.Position = spot.Position
		button.Size = spot.Size
	end
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()

	player:GetAttributeChangedSignal("Coins"):Connect(refresh)
	player:GetAttributeChangedSignal("PowerLevel"):Connect(refresh)
	refresh()
	gui.Parent = playerGui
end

return PowerLevelController
