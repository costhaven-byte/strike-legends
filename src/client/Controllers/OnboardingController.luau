-- The first 3 minutes on screen (Addendum 2 section 6, settings in Config.Onboarding). The server decides every step
-- (OnboardingService); this script only shows them:
--   the big "HOLD... THEN LET GO!" callout on the assisted first throw,
--   a bouncing "BUY POWER LV 2!" callout next to the Power Level button once Level 2 is affordable,
--   the gift crate opening (with an EQUIP button), and the camera swing to a locked ball in the lobby showcase.
-- Built in code (not in Studio), so it lives in git. Kit look since UI pass batch 3 (2026-10-28): titles with the
-- ink drop, navy chips, a gold callout bubble with the kit arrow, the slam banner for the gift.
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
local UiKit = require(Modules.UiKit)
local CrateKit = require(Modules.CrateKit)
local RewardKit = require(Modules.RewardKit)
local MomentKit = require(Modules.MomentKit)
local CrateController = require(script.Parent.CrateController)
local ShowcaseController = require(script.Parent.ShowcaseController)
local ThrowController = require(script.Parent.ThrowController)

local SETTINGS = Config.Onboarding
local GOLD = UiKit.C.Gold
local CYAN = UiKit.C.Cyan

local player = Players.LocalPlayer

local OnboardingController = {}
-- True once the showcase camera moment is over (or was skipped); the daily popup waits for it
OnboardingController.LegendsDone = false

local screen: ScreenGui -- this script's own screen (OnboardingUI)
local giftBanner: (string, string, string?, string?, number?) -> () -- the kit slam banner (made in Start)
local panning = false -- the camera is away at the showcase

-- A kit headline: the title with the ink drop and (optional) a navy chip under it, centred at (0.5, y) of the screen
-- in a w x 140 design box that shrinks on phones. Returns the holder, the title and the chip's label.
local function kitTitle(parent: ScreenGui, text: string, color: Color3, sub: string?, subColor: Color3?, y: number, w: number)
	local holder = UiKit.Make("Frame", {
		Name = "KitTitle",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.fromOffset(w, 140),
		ZIndex = 30,
	}, parent)
	local fit = UiKit.Make("UIScale", {}, holder) :: UIScale
	local function refit()
		local area = parent.AbsoluteSize
		if area.X > 0 then
			fit.Scale = math.max(0.4, math.min(1, (area.X - 24) / w, area.Y / 1080 * 1.4))
		end
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	refit()
	local titleBox = UiKit.Make("Frame", {
		Name = "TitleBox",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 84),
	}, holder)
	local title = CrateKit.Title(titleBox, text, 72, color, 4.5, 6)
	RewardKit.Fit(title, 72, w - 20, 84)
	local chipText: TextLabel? = nil
	if sub then
		local chipW = math.clamp(CrateKit.TextWidth(sub, UiKit.Head, 26) + 52, 240, w)
		local chip = UiKit.Block(holder, {
			Name = "Chip",
			Size = Vector2.new(chipW, 52),
			Fill = UiKit.C.Cover,
			Lip = UiKit.C.Ink,
			LipPx = 5,
			Radius = 26,
			Outline = 3,
		})
		chip.Holder.AnchorPoint = Vector2.new(0.5, 0)
		chip.Holder.Position = UDim2.new(0.5, 0, 0, 86)
		chipText = UiKit.Text(chip.Face, sub, UiKit.Head, 26, subColor or CYAN, 2.5)
		UiKit.Make("UIPadding", { PaddingTop = UDim.new(0, 3) }, chipText)
	end
	return holder, title, chipText
end

-- Pops a kit headline in (scale 2 -> 1, Back Out) and later shrinks it away and destroys it
local function popIn(holder: GuiObject)
	local scale = UiKit.ScaleOf(holder:FindFirstChild("TitleBox") :: GuiObject)
	scale.Scale = 2
	UiKit.Tween(scale, 0.4, Enum.EasingStyle.Back, { Scale = 1 })
	local chip = holder:FindFirstChild("Chip") :: GuiObject?
	if chip then
		local chipScale = UiKit.ScaleOf(chip)
		chipScale.Scale = 0.01
		task.delay(0.15, function()
			UiKit.Tween(chipScale, 0.25, Enum.EasingStyle.Back, { Scale = 1 })
		end)
	end
end
local function popOut(holder: GuiObject, time: number)
	for _, child in holder:GetChildren() do
		if child:IsA("GuiObject") then
			UiKit.Tween(UiKit.ScaleOf(child), time, Enum.EasingStyle.Back, { Scale = 0 }, Enum.EasingDirection.In)
		end
	end
	task.delay(time + 0.05, holder.Destroy, holder)
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
	giftBanner("A GIFT FOR YOU!", "Gold", "FROM THE BOWLING GODS", "Hud:GiftDaily", 1.4)
	UiFx.Flash(GOLD, 0.35, 0.4)
	Sfx.Play("RevealBig", 1.1)
	task.wait(1.65)
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
	local headline = kitTitle(
		screen,
		("A LOCKED %s BALL!"):format(target.Ball.Rarity:upper()),
		CrateKit.RarityColor(target.Ball.Rarity) or rarity.Color,
		"REACH THE NEXT ZONE TO WIN IT!",
		CYAN,
		0.17,
		900
	)
	popIn(headline)
	Sfx.Play("RevealBig", 0.8)
	-- Slowly drift closer while it shows
	TweenService:Create(camera, TweenInfo.new(SETTINGS.LegendsPanTime, Enum.EasingStyle.Linear), {
		CFrame = view * CFrame.new(0, -1, -3),
	}):Play()
	task.wait(SETTINGS.LegendsPanTime)

	popOut(headline, 0.25)
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

	-- First throw: a big kit headline above the bowler, the YOUR FIRST THROW chip under it
	local throwCall, throwTitle = kitTitle(gui, "HOLD... THEN LET GO!", GOLD, "YOUR FIRST THROW", CYAN, 0.22, 680)
	throwCall.Visible = false

	-- Level 2 affordable: a gold callout bubble with the kit arrow pointing at the Power Level button (kept small so
	-- it never covers the screen or the power arc; shrinks on phones)
	local buyCall = MomentKit.Callout(gui, "BUY POWER LV 2!", "NEW BALL LOOK!", "Left")
	buyCall.Visible = false
	local buyScale = UiKit.ScaleOf(buyCall)
	giftBanner = MomentKit.Banner(MomentKit.Layer("GiftBannerUI", 46), 0.4)

	local levelTwo = PowerLevels.Get(2)
	local buyShown = false
	RunService.RenderStepped:Connect(function()
		local t = os.clock()

		-- Assisted first throw
		local state = ThrowController.State()
		local firstThrow = player:GetAttribute("Onboarding") == 0 and (state == "Ready" or state == "Charging")
		if firstThrow and not throwCall.Visible then
			popIn(throwCall)
		end
		throwCall.Visible = firstThrow
		if firstThrow then
			local want = if state == "Charging" then "LET GO - ANY TIME!" else "HOLD... THEN LET GO!"
			if throwTitle.Text ~= want then
				throwTitle.Text = want
			end
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
			local compact = gui.AbsoluteSize.Y < Config.Ui.CompactHeight
			if not buyShown then
				buyScale.Scale = 0.3
				UiKit.Tween(buyScale, 0.35, Enum.EasingStyle.Back, { Scale = if compact then 0.62 else 1 })
				Sfx.Play("StreakUp", 1.3)
			end
			local bounce = math.abs(math.sin(t * 5)) * 10
			buyCall.Position = UDim2.fromOffset(
				button.AbsolutePosition.X + button.AbsoluteSize.X + 4 + bounce,
				button.AbsolutePosition.Y + button.AbsoluteSize.Y / 2
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
