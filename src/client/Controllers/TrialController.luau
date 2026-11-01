-- Rank Trial screens in the owner's kit style (UI pass batch 2, 2026-10-28): the pulsing "RANK TRIAL READY"
-- button, the intro window with the goal (START / LATER), the live tracker (one dot per strike needed, throws left)
-- and the big PASSED! / FAILED banners. All built in code; the old Studio-built StarterGui.TrialUI stays in the
-- place as a template but is switched off.
-- Everything shown comes from Player attributes the server sets (see TrialService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local HudKit = require(Modules.HudKit)
local UiKit = require(Modules.UiKit)
local CrateKit = require(Modules.CrateKit)
local RewardKit = require(Modules.RewardKit)
local MomentKit = require(Modules.MomentKit)

local TRIALS = Config.Trials
local C = UiKit.C
local make = UiKit.Make

local player = Players.LocalPlayer

local TrialController = {}

-- The rank being worked toward and its trial row (both nil at the top rank)
local function currentTrial()
	local index = (player:GetAttribute("Rank") or 1) + 1
	local nextRank = Config.Ranks[index]
	return nextRank and TRIALS.Ranks[nextRank.Name], nextRank, index
end

local function goalText(trial): string
	local trialType = TRIALS.Types[trial.Type]
	local text = if trialType then trialType.Text:format(trial.Goal, trial.Throws) else ""
	if trial.Goal == 1 then
		text = text:gsub("Strikes", "Strike"):gsub("strikes", "strike") -- "Get 1 strike in 6 throws"
	end
	return text
end

-- Seconds to wait after failing this trial (a rank's own Cooldown wins over the shared one)
local function cooldownOf(trial): number
	return if trial and trial.Cooldown then trial.Cooldown else TRIALS.Cooldown
end

local function clock(seconds: number): string
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

function TrialController:Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("TrialUI") :: ScreenGui?
	if old then
		old.Enabled = false
	end
	local gui = make("ScreenGui", {
		Name = "TrialKitUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false, -- HudKit spots are for a gui that keeps the top-bar inset
		DisplayOrder = if old then old.DisplayOrder else 8,
	}, playerGui) :: ScreenGui

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local startTrial = remotes:WaitForChild("StartTrial") :: RemoteFunction
	local trialResult = remotes:WaitForChild("TrialResult") :: RemoteEvent

	-- ===== The HUD button: gold and breathing when ready, grey with the countdown while you wait =====
	-- one button per layout (the phone spot is a different shape), the current one shown
	local buttons = {}
	for _, phone in { false, true } do
		local _, size = HudKit.Spot("Trial", phone)
		local b =
			RewardKit.Button(gui, "RANK TRIAL READY!", "Gold", size.X.Offset, size.Y.Offset, if phone then 14 else 22)
		b.Holder.Name = if phone then "TrialButtonPhone" else "TrialButton"
		b.Holder.Visible = false
		buttons[phone] = b
	end
	local button = buttons[HudKit.Phone()]
	local stopPulse: (() -> ())? = nil
	local refreshButton: () -> ()
	HudKit.OnLayout(function(phone)
		for _, b in buttons do
			b.Holder.Visible = false
		end
		if stopPulse then
			stopPulse()
			stopPulse = nil
		end
		button = buttons[phone]
		button.Holder.Position = HudKit.Spot("Trial", phone)
		if refreshButton then
			refreshButton()
		end
	end)

	-- ===== The intro window =====
	local W, H = 600, 400
	local intro = RewardKit.Window(gui, W, H)
	intro.Screen.Name = "Screen"
	local cover, close = RewardKit.Cover(intro.Panel, W, H, "RANK TRIAL", "PASS IT TO RANK UP")
	local titleFront = (cover:FindFirstChild("TitleBox") :: Frame):FindFirstChild("Front", true) :: TextLabel
	local badgeSpot = make("Frame", {
		Name = "BadgeSpot",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(140, 196),
		Size = UDim2.fromOffset(160, 160),
		ZIndex = 3,
	}, cover)
	local rays = RewardKit.Rays(badgeSpot, C.Gold, 300, 10)
	rays.ZIndex = 1
	local goalBox = make("Frame", {
		Name = "GoalBox",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(250, 104),
		Size = UDim2.fromOffset(320, 120),
		ZIndex = 4,
	}, cover)
	local goal = CrateKit.Title(goalBox, "", 40, C.White, 3, 4)
	goal.TextWrapped = true
	goal.TextXAlignment = Enum.TextXAlignment.Left
	local throwsChip = UiKit.Block(cover, {
		Name = "ThrowsChip",
		Size = Vector2.new(200, 46),
		Fill = C.Card,
		Lip = C.Ink,
		LipPx = 5,
		Radius = 23,
		Outline = 3,
	})
	throwsChip.Holder.Position = UDim2.fromOffset(250, 230)
	local throwsText = UiKit.Text(throwsChip.Face, "", UiKit.Head, 24, C.Gold, 2.5)
	make("UIPadding", { PaddingTop = UDim.new(0, 3) }, throwsText)
	local info = RewardKit.Label(cover, "", UiKit.Body, 15, C.Label, 0, 30, 286, W - 60, 22)
	local start = RewardKit.Button(cover, "START", "Lime", 240, 68, 34)
	start.Holder.Name = "Start"
	start.Holder.Position = UDim2.fromOffset(W / 2 - 250, H - 68 - 22)
	local later = RewardKit.Button(cover, "LATER", "Grey", 180, 68, 30)
	later.Holder.Name = "Later"
	later.Holder.Position = UDim2.fromOffset(W / 2 + 30, H - 68 - 22)

	-- ===== The live tracker =====
	local tracker = UiKit.Block(gui, {
		Name = "Tracker",
		Size = Vector2.new(260, 116),
		Fill = C.Cover,
		Lip = C.Ink,
		LipPx = 5,
		Radius = 18,
		Outline = 3,
	})
	tracker.Holder.Visible = false
	local trackerRing =
		make("UIStroke", { Color = C.Gold, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tracker.Face)
	local trackTitle = UiKit.Text(tracker.Face, "", UiKit.Head, 22, C.Gold, 2.5)
	trackTitle.TextXAlignment = Enum.TextXAlignment.Left
	local trackGoal = UiKit.Text(tracker.Face, "", UiKit.Body, 13, C.Label, 0)
	trackGoal.TextXAlignment = Enum.TextXAlignment.Left
	trackGoal.TextTruncate = Enum.TextTruncate.AtEnd
	local dots = make("Frame", { Name = "Dots", BackgroundTransparency = 1 }, tracker.Face)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
	}, dots)
	local throwsLeft = UiKit.Text(tracker.Face, "", UiKit.Num, 18, C.White, 2)
	throwsLeft.TextXAlignment = Enum.TextXAlignment.Left
	throwsLeft.RichText = true
	local dotSize = 22
	HudKit.OnLayout(function(phone)
		local position, size = HudKit.Spot("TrialTracker", phone)
		tracker.Holder.Position = position
		tracker.Holder.Size = size :: UDim2
		trackGoal.Visible = not phone
		dotSize = if phone then 11 else 22
		local rows = if phone
			then { { 0.02, 0.3, 11 }, nil, { 0.32, 0.3 }, { 0.64, 0.32, 10 } }
			else { { 0.04, 0.22, 22 }, { 0.27, 0.15, 13 }, { 0.45, 0.24 }, { 0.71, 0.22, 18 } }
		for i, label in { trackTitle, trackGoal, dots, throwsLeft } do
			local row = rows[i]
			if row then
				label.Position = UDim2.new(0, if phone then 6 else 14, row[1], 0)
				label.Size = UDim2.new(1, if phone then -12 else -28, row[2], 0)
				if row[3] then
					(label :: TextLabel).TextSize = row[3]
				end
			end
		end
		for _, dot in dots:GetChildren() do
			if dot:IsA("Frame") then
				dot.Size = UDim2.fromOffset(dotSize, dotSize)
			end
		end
	end)

	local showBanner = MomentKit.Banner(gui)

	local starting = false
	local shownProgress = 0

	function refreshButton()
		local state = player:GetAttribute("TrialState")
		button.Holder.Visible = (state == "Ready" or state == "Cooldown") and not intro:IsOpen()
		if state == "Ready" then
			local paint = RewardKit.Paint.Gold
			button:Paint(paint[1], paint[2], C.White)
			button:SetText("RANK TRIAL READY!")
			button:SetPressable(true)
			if not stopPulse then
				stopPulse = RewardKit.Pulse(button.Holder, 1.08, 0.6)
			end
		else
			if stopPulse then
				stopPulse()
				stopPulse = nil
			end
			local paint = RewardKit.Paint.Grey
			button:Paint(paint[1], paint[2], C.Label)
			button:SetPressable(false)
		end
	end

	-- Batch B3 (Config.TrialHint): players didn't see the gold button was something to press, so while a trial is
	-- ready its label flips between RANK TRIAL READY! and TAP TO START!, and a hand bobs on its left pointing at it
	local HINT = Config.TrialHint
	local hand = make("TextLabel", {
		Name = "TrialHand",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(40, 40),
		Text = HINT.Hand,
		TextScaled = true,
		Visible = false,
		ZIndex = 20,
	}, gui) :: TextLabel

	-- Cooldown countdown on the button (and the ready hint)
	RunService.Heartbeat:Connect(function()
		local ready = HINT.Enabled and button.Holder.Visible and player:GetAttribute("TrialState") == "Ready"
		hand.Visible = ready
		if ready then
			local flip = math.floor(os.clock() / HINT.FlipSeconds) % 2 == 1
			local text = if flip then HINT.TapText else "RANK TRIAL READY!"
			if button.Label.Text ~= text then
				button:SetText(text)
			end
			local holder = button.Holder
			local pos, size = holder.AbsolutePosition, holder.AbsoluteSize
			local push = math.abs(math.sin(os.clock() * 5)) * HINT.Bob
			local side = math.clamp(size.Y * 1.1, 26, 44)
			hand.Size = UDim2.fromOffset(side, side)
			hand.Position = UDim2.fromOffset(pos.X - 2 + push, pos.Y + size.Y / 2)
		end
		if button.Holder.Visible and player:GetAttribute("TrialState") == "Cooldown" then
			local left =
				math.ceil(math.max(0, (player:GetAttribute("TrialCooldownEnd") or 0) - Workspace:GetServerTimeNow()))
			local text = "NEXT TRIAL IN " .. clock(left)
			if button.Label.Text ~= text then
				button:SetText(text)
			end
		end
	end)

	local function openIntro()
		local trial, nextRank, index = currentTrial()
		if not trial or player:GetAttribute("TrialState") ~= "Ready" then
			return
		end
		titleFront.Text = nextRank.Name:upper() .. " TRIAL"
		titleFront.TextColor3 = nextRank.Color
		local badge = badgeSpot:FindFirstChild("Badge")
		if badge then
			badge:Destroy()
		end
		MomentKit.Badge(badgeSpot, index, 150)
		rays.ImageColor3 = nextRank.Color
		-- "Get 3 strikes in a row in 10 throws" -> the goal big, the throws on the chip
		local text = goalText(trial):upper()
		local head, throws = text:match("^(.-)%s+IN%s+(%d+ THROWS?)$")
		goal.Text = head or text
		throwsText.Text = if throws then "IN " .. throws else ""
		throwsChip.Holder.Visible = throws ~= nil
		RewardKit.Fit(goal, 40, 320, 120)
		local cooldown = cooldownOf(trial)
		info.Text = if cooldown > 0
			then ("FAIL AND YOU CAN TRY AGAIN IN %s"):format(clock(cooldown))
			else "FAIL AND YOU CAN TRY AGAIN STRAIGHT AWAY"
		info.TextColor3 = C.Label
		intro:Open()
		refreshButton()
	end

	local function closeIntro()
		intro:Close()
		task.delay(0.2, refreshButton)
	end

	local function newDot(i: number): Frame
		local dot = make("Frame", {
			Name = "Dot" .. i,
			LayoutOrder = i,
			Size = UDim2.fromOffset(dotSize, dotSize),
			BackgroundColor3 = C.Chip,
		}, dots)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, dot)
		make("UIStroke", { Color = C.Dash, Thickness = 2 }, dot)
		make("ImageLabel", {
			Name = "Tick",
			BackgroundTransparency = 1,
			Image = CrateKit.Image("Check"),
			ScaleType = Enum.ScaleType.Fit,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			Visible = false,
		}, dot)
		return dot
	end

	-- Tracker: one dot per goal step, filled as the server counts them
	local function refreshTracker()
		local state = player:GetAttribute("TrialState")
		local trial, nextRank = currentTrial()
		local holder = tracker.Holder
		if state ~= "Active" or not trial then
			holder.Visible = false
			shownProgress = 0
			return
		end
		local progress = player:GetAttribute("TrialProgress") or 0
		local left = player:GetAttribute("TrialThrowsLeft") or 0
		if not holder.Visible then
			UiFx.Open(holder)
		end
		trackTitle.Text = nextRank.Name:upper() .. " TRIAL"
		trackTitle.TextColor3 = nextRank.Color
		trackerRing.Color = nextRank.Color
		local full = goalText(trial):upper()
		trackGoal.Text = full:match("^(.-)%s+IN%s+%d+ THROWS?$") or full
		local throws = ("%d THROW%s LEFT"):format(left, if left == 1 then "" else "S")
		throwsLeft.Text = if trial.Goal - progress == 1
			then ('<font color="#%s">ONE MORE!</font>  %s'):format(C.Lime:ToHex(), throws)
			else throws

		for i = 1, trial.Goal do
			local dot = (dots:FindFirstChild("Dot" .. i) :: Frame?) or newDot(i)
			local filled = i <= progress
			dot.BackgroundColor3 = if filled then nextRank.Color else C.Chip
			local tick = dot:FindFirstChild("Tick") :: ImageLabel
			tick.Visible = filled
			if filled and i > shownProgress then
				UiFx.Pop(dot, 1.8, 0.35)
			end
		end
		for _, child in dots:GetChildren() do
			local index = tonumber(child.Name:match("^Dot(%d+)$"))
			if index and index > trial.Goal then
				child:Destroy()
			end
		end

		if progress > shownProgress then
			Sfx.Play("StreakUp", 1 + progress * 0.1)
			UiFx.Pop(holder, 1.08, 0.3)
		elseif progress < shownProgress then
			Sfx.Play("StreakLost") -- an "in a row" trial was reset by a miss
		end
		shownProgress = progress
	end

	for _, b in buttons do
		b.Activated:Connect(openIntro)
	end
	close.Activated:Connect(closeIntro)
	later.Activated:Connect(closeIntro)
	intro.Closed.Event:Connect(function()
		task.delay(0.2, refreshButton)
	end)
	start.Activated:Connect(function()
		if starting then
			return
		end
		starting = true
		local ok, result = pcall(startTrial.InvokeServer, startTrial)
		starting = false
		if ok and result and result.Ok then
			closeIntro()
			Sfx.Play("StreakUp", 0.8, 1.2)
			showBanner("TRIAL START!", "Gold", goal.Text)
		else
			info.Text = (if ok and result and result.Error then result.Error else "That didn't work. Try again"):upper()
			info.TextColor3 = C.Red
			start:Shake()
		end
	end)

	trialResult.OnClientEvent:Connect(function(data)
		if data.Passed then
			Sfx.Play("Cheer", 1.1)
			showBanner("PASSED!", "Lime", "RANK UP!") -- the rank-up screen follows straight away
		else
			Sfx.Play("StreakLost", 0.8, 1.3)
			UiFx.Flash(C.Red, 0.35, 0.4)
			local cooldown = cooldownOf(currentTrial())
			showBanner("FAILED", "Red", if cooldown > 0 then "TRY AGAIN IN " .. clock(cooldown) else "TRY AGAIN NOW!")
		end
	end)

	for _, key in { "TrialState", "TrialProgress", "TrialThrowsLeft", "Rank" } do
		player:GetAttributeChangedSignal(key):Connect(function()
			refreshButton()
			refreshTracker()
			if key == "TrialState" and player:GetAttribute("TrialState") ~= "Ready" and intro:IsOpen() then
				closeIntro()
			end
		end)
	end

	refreshButton()
	refreshTracker()
end

return TrialController
