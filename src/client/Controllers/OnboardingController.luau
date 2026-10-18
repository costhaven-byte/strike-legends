-- The first 3 minutes on screen (Addendum 2 section 6, settings in Config.Onboarding). The server decides every step
-- (OnboardingService); this script only shows them:
--   the big "HOLD... THEN LET GO!" callout on the assisted first throw,
--   a bouncing "BUY POWER LV 2!" callout next to the Power Level button once Level 2 is affordable,
--   the gift crate opening (with an EQUIP button), and the camera swing to a locked ball in the lobby showcase.
-- Built in code (not in Studio), so it lives in git.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local PowerLevels = require(Shared.Modules.PowerLevels)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local CrateController = require(script.Parent.CrateController)
local ShowcaseController = require(script.Parent.ShowcaseController)
local ThrowController = require(script.Parent.ThrowController)

local SETTINGS = Config.Onboarding
local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local INK = Color3.fromHex("06060F")
local GOLD = Color3.fromRGB(255, 200, 40)
local CYAN = Color3.fromRGB(70, 230, 255)

local player = Players.LocalPlayer

local OnboardingController = {}
-- True once the showcase camera moment is over (or was skipped); the daily popup waits for it
OnboardingController.LegendsDone = false

local screen: ScreenGui -- this script's own screen (OnboardingUI)
local panning = false -- the camera is away at the showcase

local function bigLabel(parent: Instance, text: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.FontFace = FONT
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.ZIndex = 30
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function fadeOut(label: TextLabel, time: number)
	TweenService:Create(label, TweenInfo.new(time), { TextTransparency = 1 }):Play()
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(time), { Transparency = 1 }):Play()
	end
	task.delay(time + 0.05, label.Destroy, label)
end

-- Waits until the player isn't in the middle of a throw (and the throw camera has handed back),
-- and no crate opening is on screen (like the gift crate still waiting for EQUIP)
local function waitForCalm()
	local camera = Workspace.CurrentCamera
	local ballsUi = player.PlayerGui:FindFirstChild("BallsUI")
	local opening = ballsUi and ballsUi:FindFirstChild("Opening") :: GuiObject?
	local waited = 0
	while
		waited < 120
		and (
			(opening ~= nil and opening.Visible)
			or ThrowController.State() == "Charging"
			or ThrowController.State() == "Waiting"
			or camera.CameraType ~= Enum.CameraType.Custom
		)
	do
		waited += task.wait(0.1)
	end
end

-- The gift crate: a short banner, then the crate opening with an EQUIP button
local function showGift(data)
	local crate = Balls.GetCrate(data.CrateId)
	if not crate or type(data.Result) ~= "table" then
		return
	end
	waitForCalm()
	local layer = UiFx.Layer()
	local banner = bigLabel(layer, "A GIFT FOR YOU!", GOLD)
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.4)
	banner.Size = UDim2.new(0.7, 0, 0, 80)
	UiFx.Pop(banner, 2, 0.45)
	UiFx.Flash(GOLD, 0.35, 0.4)
	Sfx.Play("RevealBig", 1.1)
	task.wait(1.4)
	fadeOut(banner, 0.25)
	task.wait(0.25)
	CrateController.PlayOpening(crate, data.Result, true)
end

-- The chase: the camera swings to the best ball you don't own in the lobby showcase, then back
local function showLegends()
	local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
	local target = nil
	for _, entry in ShowcaseController.Shown do
		if not owned[entry.Ball.Id] then
			target = entry
			break
		end
	end
	if not target then
		OnboardingController.LegendsDone = true
		return
	end
	waitForCalm()
	local camera = Workspace.CurrentCamera
	local slot = target.Slot :: BasePart
	local look = slot.Position + Vector3.new(0, 5.5, 0)
	local view = CFrame.lookAt(slot.Position + slot.CFrame.LookVector * 15 + Vector3.new(0, 7, 0), look)
	local back = camera.CFrame

	-- A clean shot: every other screen hides while the camera is away
	local hidden = {}
	for _, other in player.PlayerGui:GetChildren() do
		if other:IsA("ScreenGui") and other ~= screen and other.Enabled then
			other.Enabled = false
			table.insert(hidden, other)
		end
	end

	panning = true
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		CFrame = view,
	}):Play()
	task.wait(1)

	local rarity = Balls.GetRarity(target.Ball.Rarity)
	local title = bigLabel(screen, ("A LOCKED %s BALL!"):format(target.Ball.Rarity:upper()), rarity.Color)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.18)
	title.Size = UDim2.new(0.7, 0, 0, 64)
	local sub = bigLabel(screen, "OPEN CRATES IN THE LOBBY TO UNLOCK IT!", CYAN)
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.new(0.5, 0, 0.18, 52)
	sub.Size = UDim2.new(0.6, 0, 0, 30)
	UiFx.Pop(title, 1.8, 0.45)
	UiFx.Pop(sub, 0.4, 0.45)
	Sfx.Play("RevealBig", 0.8)
	-- Slowly drift closer while it shows
	TweenService:Create(camera, TweenInfo.new(SETTINGS.LegendsPanTime, Enum.EasingStyle.Linear), {
		CFrame = view * CFrame.new(0, -1, -3),
	}):Play()
	task.wait(SETTINGS.LegendsPanTime)

	fadeOut(title, 0.3)
	fadeOut(sub, 0.3)
	local home = TweenService:Create(camera, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		CFrame = back,
	})
	home:Play()
	home.Completed:Wait()
	camera.CameraType = Enum.CameraType.Custom
	for _, other in hidden do
		other.Enabled = true
	end
	panning = false
	OnboardingController.LegendsDone = true
end

function OnboardingController:Start()
	if not SETTINGS.Enabled then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui

	local gui = Instance.new("ScreenGui")
	screen = gui
	gui.Name = "OnboardingUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.IgnoreGuiInset = hud.IgnoreGuiInset -- same as the Power Level button, so the BUY arrow lines up with it

	-- First throw: a big callout above the bowler
	local throwCall = bigLabel(gui, "HOLD... THEN LET GO!", GOLD)
	throwCall.AnchorPoint = Vector2.new(0.5, 0.5)
	throwCall.Position = UDim2.fromScale(0.5, 0.26)
	throwCall.Size = UDim2.new(0.6, 0, 0, 64)
	throwCall.Visible = false
	local throwSub = bigLabel(throwCall, "YOUR FIRST THROW", CYAN)
	throwSub.AnchorPoint = Vector2.new(0.5, 1)
	throwSub.Position = UDim2.fromScale(0.5, 0)
	throwSub.Size = UDim2.new(0.6, 0, 0, 26)

	-- Level 2 affordable: a bouncing arrow next to the Power Level button
	local buyCall = bigLabel(gui, "< BUY POWER LV 2!", GOLD)
	buyCall.AnchorPoint = Vector2.new(0, 0.5)
	buyCall.Size = UDim2.fromOffset(230, 38)
	buyCall.TextXAlignment = Enum.TextXAlignment.Left
	buyCall.Visible = false
	local buySub = bigLabel(buyCall, "  IT CHANGES YOUR BALL!", CYAN)
	buySub.Position = UDim2.fromScale(0, 1)
	buySub.Size = UDim2.new(1, 0, 0, 20)
	buySub.TextXAlignment = Enum.TextXAlignment.Left

	local levelTwo = PowerLevels.Get(2)
	local buyShown = false
	RunService.RenderStepped:Connect(function()
		local t = os.clock()

		-- Assisted first throw
		local state = ThrowController.State()
		local firstThrow = player:GetAttribute("Onboarding") == 0 and (state == "Ready" or state == "Charging")
		throwCall.Visible = firstThrow
		if firstThrow then
			throwCall.Text = if state == "Charging" then "LET GO - ANY TIME!" else "HOLD... THEN LET GO!"
			throwCall.Rotation = math.sin(t * 3) * 3
		end

		-- First Power Level
		local powerUi = playerGui:FindFirstChild("PowerUI")
		local button = powerUi and powerUi:FindFirstChild("PowerButton") :: GuiObject?
		local wantBuy = button ~= nil
			and not panning
			and (player:GetAttribute("PowerLevel") or 1) == 1
			and (player:GetAttribute("Coins") or 0) >= levelTwo.Price
		buyCall.Visible = wantBuy
		if wantBuy and button then
			if not buyShown then
				UiFx.Pop(buyCall, 1.6, 0.4)
				Sfx.Play("StreakUp", 1.3)
			end
			local bounce = math.abs(math.sin(t * 5)) * 14
			buyCall.Position = UDim2.fromOffset(
				button.AbsolutePosition.X + button.AbsoluteSize.X + 10 + bounce,
				button.AbsolutePosition.Y + button.AbsoluteSize.Y / 2 - 8
			)
		end
		buyShown = wantBuy
	end)

	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Onboarding").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if data.Kind == "Gift" then
			task.spawn(showGift, data)
		elseif data.Kind == "Legends" then
			task.spawn(showLegends)
		end
	end)

	gui.Parent = playerGui
end

return OnboardingController
