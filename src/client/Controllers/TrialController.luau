-- Rank Trial screens: the pulsing "RANK TRIAL READY" button, the intro popup with the goal,
-- the live tracker (progress dots and throws left) and the PASSED / FAILED banner.
-- The UI itself (StarterGui.TrialUI) is built in Studio; this script fills it in and animates it.
-- Everything shown comes from Player attributes the server sets (see TrialService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local TRIALS = Config.Trials
local READY_COLOR = Color3.fromRGB(255, 200, 40)
local COOLDOWN_COLOR = Color3.fromRGB(110, 100, 130)
local EMPTY_DOT = Color3.fromRGB(50, 40, 80)
local PASS_COLOR = Color3.fromRGB(90, 230, 110)
local FAIL_COLOR = Color3.fromRGB(255, 80, 90)

local player = Players.LocalPlayer

local TrialController = {}

-- The rank being worked toward and its trial row (both nil at the top rank)
local function currentTrial()
	local nextRank = Config.Ranks[(player:GetAttribute("Rank") or 1) + 1]
	return nextRank and TRIALS.Ranks[nextRank.Name], nextRank
end

local function goalText(trial): string
	local trialType = TRIALS.Types[trial.Type]
	return if trialType then trialType.Text:format(trial.Goal, trial.Throws) else ""
end

function TrialController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("TrialUI")
	local button = gui:WaitForChild("TrialButton") :: TextButton
	local buttonLabel = button:WaitForChild("Label") :: TextLabel
	local buttonScale = button:WaitForChild("UIScale") :: UIScale
	local intro = gui:WaitForChild("Intro") :: Frame
	local tracker = gui:WaitForChild("Tracker") :: Frame
	local dots = tracker:WaitForChild("Dots") :: Frame
	local dotTemplate = dots:WaitForChild("DotTemplate") :: Frame
	local banner = gui:WaitForChild("Banner") :: TextLabel
	local bannerScale = banner:WaitForChild("UIScale") :: UIScale

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local startTrial = remotes:WaitForChild("StartTrial") :: RemoteFunction
	local trialResult = remotes:WaitForChild("TrialResult") :: RemoteEvent

	local infoText = intro.Info.Text
	local starting = false
	local shownProgress = 0

	-- The ready button breathes so it's hard to miss
	local pulse = TweenService:Create(
		buttonScale,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.08 }
	)

	local function refreshButton()
		local state = player:GetAttribute("TrialState")
		button.Visible = (state == "Ready" or state == "Cooldown") and not intro.Visible
		if state == "Ready" then
			button.BackgroundColor3 = READY_COLOR
			buttonLabel.Text = "RANK TRIAL READY!  TAP TO START"
			pulse:Play()
		else
			pulse:Cancel()
			buttonScale.Scale = 1
			button.BackgroundColor3 = COOLDOWN_COLOR
		end
	end

	-- Cooldown countdown on the button
	RunService.Heartbeat:Connect(function()
		if player:GetAttribute("TrialState") == "Cooldown" then
			local left =
				math.ceil(math.max(0, (player:GetAttribute("TrialCooldownEnd") or 0) - Workspace:GetServerTimeNow()))
			buttonLabel.Text = ("NEXT TRIAL IN %d:%02d"):format(left // 60, left % 60)
		end
	end)

	local function openIntro()
		local trial, nextRank = currentTrial()
		if not trial or player:GetAttribute("TrialState") ~= "Ready" then
			return
		end
		intro.RankName.Text = nextRank.Name:upper()
		intro.RankName.TextColor3 = nextRank.Color
		intro.Goal.Text = goalText(trial)
		intro.Info.Text = infoText:gsub("60", tostring(TRIALS.Cooldown))
		intro.Info.TextColor3 = Color3.fromRGB(170, 160, 200)
		UiFx.Open(intro)
		refreshButton()
	end

	local function closeIntro()
		UiFx.Close(intro)
		task.delay(0.2, refreshButton)
	end

	-- Tracker: one dot per goal step, filled as the server counts them
	local function refreshTracker()
		local state = player:GetAttribute("TrialState")
		local trial, nextRank = currentTrial()
		if state ~= "Active" or not trial then
			tracker.Visible = false
			shownProgress = 0
			return
		end
		local progress = player:GetAttribute("TrialProgress") or 0
		local throwsLeft = player:GetAttribute("TrialThrowsLeft") or 0
		if not tracker.Visible then
			UiFx.Open(tracker)
		end
		tracker.Title.Text = ("RANK TRIAL  ›  %s"):format(nextRank.Name:upper())
		tracker.Title.TextColor3 = nextRank.Color
		tracker.UIStroke.Color = nextRank.Color
		tracker.Goal.Text = goalText(trial)
		tracker.ThrowsLeft.Text = if trial.Goal - progress == 1
			then ('<font color="#5AE66E">ONE MORE!</font>   %d THROW%s LEFT'):format(
				throwsLeft,
				if throwsLeft == 1 then "" else "S"
			)
			else ("%d THROW%s LEFT"):format(throwsLeft, if throwsLeft == 1 then "" else "S")

		for i = 1, trial.Goal do
			local dot = dots:FindFirstChild("Dot" .. i) :: Frame?
			if not dot then
				local new = dotTemplate:Clone()
				new.Name = "Dot" .. i
				new.LayoutOrder = i
				new.Visible = true
				new.Parent = dots
				dot = new
			end
			local filled = i <= progress
			local d = dot :: Frame
			d.BackgroundColor3 = if filled then nextRank.Color else EMPTY_DOT
			if filled and i > shownProgress then
				UiFx.Pop(d, 1.8, 0.35)
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
			UiFx.Pop(tracker, 1.08, 0.3)
		elseif progress < shownProgress then
			Sfx.Play("StreakLost") -- an "in a row" trial was reset by a miss
		end
		shownProgress = progress
	end

	local bannerToken = 0
	local function showBanner(text: string, color: Color3)
		bannerToken += 1
		local token = bannerToken
		banner.Text = text
		banner.TextColor3 = color
		banner.TextTransparency = 0
		banner.Visible = true
		bannerScale.Scale = 2.5
		TweenService:Create(bannerScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		task.delay(1.8, function()
			if token ~= bannerToken then
				return
			end
			TweenService:Create(banner, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			task.wait(0.3)
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	end

	button.Activated:Connect(openIntro)
	intro.Close.Activated:Connect(closeIntro)
	intro.Start.Activated:Connect(function()
		if starting then
			return
		end
		starting = true
		local ok, result = pcall(startTrial.InvokeServer, startTrial)
		starting = false
		if ok and result and result.Ok then
			closeIntro()
			Sfx.Play("StreakUp", 0.8, 1.2)
			showBanner("TRIAL START!", Color3.fromRGB(255, 240, 90))
		else
			intro.Info.Text = if ok and result and result.Error then result.Error else "Try again"
			intro.Info.TextColor3 = FAIL_COLOR
		end
	end)

	trialResult.OnClientEvent:Connect(function(data)
		if data.Passed then
			showBanner("TRIAL PASSED!", PASS_COLOR) -- the rank-up celebration follows straight away
		else
			Sfx.Play("StreakLost", 0.8, 1.3)
			UiFx.Flash(FAIL_COLOR, 0.35, 0.4)
			showBanner(("TRIAL FAILED  ·  RETRY IN %ds"):format(TRIALS.Cooldown), FAIL_COLOR)
		end
	end)

	for _, key in { "TrialState", "TrialProgress", "TrialThrowsLeft", "Rank" } do
		player:GetAttributeChangedSignal(key):Connect(function()
			refreshButton()
			refreshTracker()
			if key == "TrialState" and player:GetAttribute("TrialState") ~= "Ready" and intro.Visible then
				closeIntro()
			end
		end)
	end

	intro.Active = true -- taps on the popup don't fall through to the throw meter
	intro.Visible = false
	tracker.Visible = false
	banner.Visible = false
	refreshButton()
	refreshTracker()
end

return TrialController
