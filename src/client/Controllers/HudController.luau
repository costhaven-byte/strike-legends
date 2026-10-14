-- Shows coins, gems, the rank/XP bar and the streak panel, and a "+coins +XP" popup after each throw.
-- The UI itself (StarterGui.HUD) is built in Studio; this script only fills it in.
-- Values come from Player attributes, which only the server sets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Progression = require(Shared.Modules.Progression)

local player = Players.LocalPlayer

local STATS = { "Coins", "Gems" }
local COUNT_TIME = 0.6 -- seconds for a number to tick up to its new value

-- Streak panel colour for each streak tier (same order as Config.Streaks)
local NO_STREAK_COLOR = Color3.fromRGB(120, 110, 150)
local STREAK_COLORS = {
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(60, 230, 255),
	Color3.fromRGB(120, 255, 120),
	Color3.fromRGB(255, 200, 40),
	Color3.fromRGB(255, 130, 30),
	Color3.fromRGB(255, 60, 210),
	Color3.fromRGB(255, 240, 90),
}
local BROKEN_COLOR = Color3.fromRGB(255, 60, 70)

local HudController = {}

-- 1234567 -> "1,234,567"; anything a million or more -> "1.23M"
local function formatNumber(n: number): string
	n = math.floor(n + 0.5)
	if n >= 1e9 then
		return ("%.2fB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.2fM"):format(n / 1e6)
	end
	local text = tostring(n)
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end

local function bump(scale: UIScale)
	scale.Scale = 1.15
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

local function bindStat(pill: Frame, key: string)
	local label = pill:WaitForChild("Amount") :: TextLabel
	local scale = pill:WaitForChild("UIScale") :: UIScale
	local shown = Instance.new("NumberValue")
	shown.Value = player:GetAttribute(key) or 0
	label.Text = formatNumber(shown.Value)

	shown.Changed:Connect(function(value)
		label.Text = formatNumber(value)
	end)

	player:GetAttributeChangedSignal(key):Connect(function()
		local target = player:GetAttribute(key) or 0
		if target > shown.Value then
			bump(scale)
		end
		TweenService:Create(shown, TweenInfo.new(COUNT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Value = target,
		}):Play()
	end)
end

local function bindRankBar(rankBar: Frame)
	local fill = rankBar:WaitForChild("Fill") :: Frame
	local label = rankBar:WaitForChild("Label") :: TextLabel
	local outline = rankBar:WaitForChild("UIStroke") :: UIStroke

	local function refresh()
		local xp = player:GetAttribute("XP") or 0
		local index = Progression.GetRankIndex(xp)
		local rank = Progression.GetRank(index)
		local nextRank = Config.Ranks[index + 1]

		local progress = 1
		if nextRank then
			progress = (xp - rank.XP) / (nextRank.XP - rank.XP)
			label.Text = ("%s  ·  %s / %s XP"):format(rank.Name:upper(), formatNumber(xp), formatNumber(nextRank.XP))
		else
			label.Text = ("%s  ·  %s XP"):format(rank.Name:upper(), formatNumber(xp))
		end
		fill.BackgroundColor3 = rank.Color
		outline.Color = rank.Color
		TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1),
		}):Play()
	end

	player:GetAttributeChangedSignal("XP"):Connect(refresh)
	refresh()
end

local function tierIndex(streak: number): number
	local index = 0
	for i, entry in Config.Streaks do
		if streak >= entry.Streak then
			index = i
		end
	end
	return index
end

local function bindStreak(panel: Frame)
	local count = panel:WaitForChild("Count") :: TextLabel
	local tierName = panel:WaitForChild("TierName") :: TextLabel
	local multiplier = panel:WaitForChild("Multiplier") :: TextLabel
	local outline = panel:WaitForChild("UIStroke") :: UIStroke
	local scale = panel:WaitForChild("UIScale") :: UIScale
	local previous = player:GetAttribute("Streak") or 0

	local function show(streak: number)
		local index = tierIndex(streak)
		local tier = Config.Streaks[index]
		local color = if index == 0 then NO_STREAK_COLOR else STREAK_COLORS[math.min(index, #STREAK_COLORS)]
		count.Text = tostring(streak)
		count.TextColor3 = color
		tierName.Text = if tier and tier.Name ~= "" then tier.Name elseif streak == 0 then "STRIKE TO START" else ""
		tierName.TextColor3 = color
		multiplier.Text = ("x%g COINS"):format(Progression.GetStreakMultiplier(streak))
		outline.Color = color
		outline.Thickness = 3 + index * 0.5
	end

	player:GetAttributeChangedSignal("Streak"):Connect(function()
		local streak = player:GetAttribute("Streak") or 0
		local newTier = tierIndex(streak) > tierIndex(previous)
		local broken = streak == 0 and previous >= 2
		previous = streak
		show(streak)

		if broken then
			-- Short, noticeable shake in red, then back to normal
			tierName.Text = "STREAK LOST"
			tierName.TextColor3 = BROKEN_COLOR
			outline.Color = BROKEN_COLOR
			for _, angle in { -8, 8, -5, 5, 0 } do
				TweenService:Create(panel, TweenInfo.new(0.05), { Rotation = angle }):Play()
				task.wait(0.05)
			end
			task.delay(1.2, function()
				if (player:GetAttribute("Streak") or 0) == 0 then
					show(0)
				end
			end)
		elseif streak > 0 then
			-- Bigger pop the higher the tier, and an extra-big one when you reach a new tier
			local index = tierIndex(streak)
			scale.Scale = if newTier then 1.35 + index * 0.05 else 1.15
			TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end)
	show(previous)
end

function HudController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
	local bar = gui:WaitForChild("Bar")
	for _, key in STATS do
		bindStat(bar:WaitForChild(key), key)
	end
	bindRankBar(gui:WaitForChild("RankBar"))
	bindStreak(gui:WaitForChild("Streak"))

	local popup = gui:WaitForChild("RewardPopup") :: TextLabel
	local popupScale = popup:WaitForChild("UIScale") :: UIScale
	local popupToken = 0

	local function showReward(reward)
		if reward.Coins <= 0 and reward.XP <= 0 and reward.Gems <= 0 then
			return
		end
		local parts = {}
		if reward.Coins > 0 then
			table.insert(parts, ('<font color="#FFC828">+%s coins</font>'):format(formatNumber(reward.Coins)))
		end
		if reward.Gems > 0 then
			local gemWord = if reward.Gems == 1 then "gem" else "gems"
			table.insert(parts, ('<font color="#3CE6FF">+%d %s</font>'):format(reward.Gems, gemWord))
		end
		if reward.XP > 0 then
			table.insert(parts, ('<font color="#C85AFF">+%d XP</font>'):format(reward.XP))
		end
		popup.Text = table.concat(parts, "   ")
		popup.Visible = true
		popupScale.Scale = 0.4
		TweenService:Create(popupScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()

		popupToken += 1
		local token = popupToken
		task.delay(1.4, function()
			if token == popupToken then
				popup.Visible = false
			end
		end)
	end

	local throwResult = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ThrowResult")
	throwResult.OnClientEvent:Connect(function(data)
		if data.UserId == player.UserId and data.Reward then
			task.delay(data.RollTime, showReward, data.Reward)
		end
	end)
end

return HudController
