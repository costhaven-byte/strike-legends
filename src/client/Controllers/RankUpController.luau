-- Plays the full-screen rank-up celebration and posts rank-ups from everyone in chat.
-- The screen is MomentKit.RankUp (UI pass batch 2: the new tier's badge, its name, what it gives, CONTINUE).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Modules.Progression)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local LaneFx = require(Modules.LaneFx)
local Sfx = require(Modules.Sfx)
local MomentKit = require(Modules.MomentKit)

local player = Players.LocalPlayer

local RankUpController = {}

local function announce(data)
	local rank = Progression.GetRank(data.Rank)
	local message = ("%s is now %s"):format(data.DisplayName, rank.Name)

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
	-- The old Studio-built screen (StarterGui.RankUpUI) stays in the place as a template but is never shown
	local old = player:WaitForChild("PlayerGui"):FindFirstChild("RankUpUI")
	if old and old:FindFirstChild("Overlay") then
		old.Overlay.Visible = false
	end
	local celebrate = MomentKit.RankUp()

	local rankUp = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RankUp")
	rankUp.OnClientEvent:Connect(function(data)
		task.spawn(announce, data)
		if data.UserId == player.UserId then
			celebrate(data.Rank, data.Level, data.Gems or 0)
			Sfx.Play("RankUp")
			Sfx.Play("Cheer", 1.1)
			local lane = LaneUtil.GetOwnedLane(player.UserId)
			if lane then
				LaneFx.Fireworks(lane, 4)
			end
		end
	end)
end

return RankUpController
