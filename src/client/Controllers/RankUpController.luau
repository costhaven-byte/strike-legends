-- Plays the full-screen rank-up celebration and posts rank-ups from everyone in chat.
-- The UI itself (StarterGui.RankUpUI) is built in Studio; this script only animates it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Progression = require(Shared.Modules.Progression)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local LaneFx = require(Modules.LaneFx)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local player = Players.LocalPlayer

local SHOW_TIME = Config.Ui.RankUpShowTime
local CONFETTI_COUNT = Config.Ui.RankUpConfetti

local RankUpController = {}

local function announce(data)
	local rank = Progression.GetRank(data.Rank)
	local message = ("%s reached %s!"):format(data.DisplayName, rank.Name)

	-- This place still uses the older chat system, which has its own way to post a system message
	if TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService then
		pcall(function()
			StarterGui:SetCore("ChatMakeSystemMessage", {
				Text = message,
				Color = rank.Color,
				Font = Enum.Font.GothamBold,
			})
		end)
		return
	end

	local ok, channel = pcall(function()
		return TextChatService:WaitForChild("TextChannels", 5):WaitForChild("RBXGeneral", 5)
	end)
	if ok and channel then
		channel:DisplaySystemMessage(('<font color="#%s">%s</font>'):format(rank.Color:ToHex(), message))
	end
end

function RankUpController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("RankUpUI")
	local overlay = gui:WaitForChild("Overlay") :: Frame
	local flash = overlay:WaitForChild("Flash") :: Frame
	local confetti = overlay:WaitForChild("Confetti") :: Frame
	local content = overlay:WaitForChild("Content") :: Frame
	local contentScale = content:WaitForChild("UIScale") :: UIScale
	local glow = content:WaitForChild("Glow") :: Frame
	local rankName = content:WaitForChild("RankName") :: TextLabel
	local rewardText = content:WaitForChild("Reward") :: TextLabel
	local dismiss = overlay:WaitForChild("Dismiss") :: TextButton

	local showToken = 0
	local canDismiss = false

	local function hide()
		showToken += 1
		canDismiss = false
		local tween = TweenService:Create(
			contentScale,
			TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Scale = 0 }
		)
		tween:Play()
		tween.Completed:Wait()
		overlay.Visible = false
	end

	local function celebrate(data)
		showToken += 1
		local token = showToken
		local rank = Progression.GetRank(data.Rank)

		rankName.Text = rank.Name:upper()
		rankName.TextColor3 = rank.Color
		glow.BackgroundColor3 = rank.Color
		local parts = {}
		if data.Level then
			table.insert(parts, ("LEVEL %d"):format(data.Level))
		end
		if data.Gems > 0 then
			table.insert(parts, ('<font color="#3CE6FF">+%d gems</font>'):format(data.Gems))
		end
		table.insert(parts, ('<font color="#FFC828">x%g coin bonus</font>'):format(rank.Multiplier))
		rewardText.Text = table.concat(parts, "   ·   ")

		overlay.Visible = true
		flash.BackgroundTransparency = 0
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		contentScale.Scale = 0.2
		TweenService:Create(contentScale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		UiFx.Confetti(confetti, CONFETTI_COUNT)
		Sfx.Play("RankUp")
		Sfx.Play("Cheer", 1.1)
		local lane = LaneUtil.GetOwnedLane(player.UserId)
		if lane then
			LaneFx.Fireworks(lane, 4)
		end

		canDismiss = false
		task.delay(0.8, function()
			if token == showToken then
				canDismiss = true
			end
		end)
		task.delay(SHOW_TIME, function()
			if token == showToken then
				hide()
			end
		end)
	end

	dismiss.Activated:Connect(function()
		if canDismiss then
			hide()
		end
	end)

	local rankUp = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RankUp")
	rankUp.OnClientEvent:Connect(function(data)
		task.spawn(announce, data)
		if data.UserId == player.UserId then
			celebrate(data)
		end
	end)
	overlay.Visible = false
end

return RankUpController
