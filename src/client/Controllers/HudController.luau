-- Shows coins, gems, the rank/XP bar and the streak panel, and a "+coins +XP" popup after each throw.
-- After a throw, coin (and gem) icons fly from the pins into the counters with a rising "ding".
-- The UI itself (StarterGui.HUD) is built in Studio; this script only fills it in.
-- Values come from Player attributes, which only the server sets.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Progression = require(Shared.Modules.Progression)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local player = Players.LocalPlayer

local STATS = { "Coins", "Gems" }
local COUNT_TIME = 0.6 -- seconds for a number to tick up to its new value

local JUICE = Config.Juice
local NO_STREAK_COLOR = Color3.fromRGB(120, 110, 150)
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
		local index = player:GetAttribute("Rank") or 1 -- saved rank; a full bar waits for the Rank Trial
		local rank = Progression.GetRank(index)
		local nextRank = Config.Ranks[index + 1]

		local progress = 1
		if nextRank and xp >= nextRank.XP then
			local state = player:GetAttribute("TrialState")
			label.Text = ("%s  ·  XP FULL  ·  %s"):format(
				rank.Name:upper(),
				if state == "Active"
					then "TRIAL IN PROGRESS"
					elseif state == "Cooldown" then "TRY THE TRIAL AGAIN SOON"
					else "RANK TRIAL READY"
			)
		elseif nextRank then
			progress = (xp - rank.XP) / (nextRank.XP - rank.XP)
			-- One bar for rank progress: where you are and what's next
			label.Text = ("%s  ·  %s XP TO %s"):format(
				rank.Name:upper(),
				formatNumber(nextRank.XP - xp),
				nextRank.Name:upper()
			)
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
	player:GetAttributeChangedSignal("Rank"):Connect(refresh)
	player:GetAttributeChangedSignal("TrialState"):Connect(refresh)
	refresh()
end

local tierIndex = Progression.GetStreakTierIndex

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
		local color = if tier then tier.Color else NO_STREAK_COLOR
		count.Text = tostring(streak)
		count.TextColor3 = color
		tierName.Text = if tier and tier.Name ~= "" then tier.Name elseif streak == 0 then "STRIKE TO START" else ""
		tierName.TextColor3 = color
		local coinMultiplier = Progression.GetStreakMultiplier(streak)
		local xpMultiplier = Progression.GetStreakXpMultiplier(streak)
		multiplier.Text = if coinMultiplier == xpMultiplier
			then ("x%g COINS & XP"):format(coinMultiplier)
			else ("x%g COINS · x%g XP"):format(coinMultiplier, xpMultiplier)
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

-- Icons copied from a counter's own icon fly from `from` (screen position) into that counter
local function flyIcons(pill: Frame, count: number, from: Vector2)
	local icon = pill:FindFirstChild("Icon") :: Frame?
	if not icon then
		return
	end
	local layer = UiFx.Layer()
	local target = icon.AbsolutePosition + icon.AbsoluteSize / 2
	for i = 1, count do
		task.delay((i - 1) * 0.05, function()
			local flyer = icon:Clone()
			flyer.AnchorPoint = Vector2.new(0.5, 0.5)
			flyer.Position = UDim2.fromOffset(from.X, from.Y)
			flyer.Size = UDim2.fromOffset(28, 28)
			flyer.ZIndex = 10
			flyer.Parent = layer

			-- Burst outward a little, then swoop into the counter
			local angle = math.random() * math.pi * 2
			local burst = from + Vector2.new(math.cos(angle), math.sin(angle)) * math.random(40, 110)
			local out = TweenService:Create(
				flyer,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.fromOffset(burst.X, burst.Y), Size = UDim2.fromOffset(34, 34) }
			)
			out:Play()
			out.Completed:Wait()
			local home = TweenService:Create(
				flyer,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(24, 24) }
			)
			home:Play()
			home.Completed:Wait()
			flyer:Destroy()
			Sfx.Play("Coin", 1 + (i - 1) * JUICE.CoinPitchStep)
			bump(pill:FindFirstChildOfClass("UIScale") :: UIScale)
		end)
	end
end

-- Where a lane's pins are on screen (in HUD coordinates); the middle of the screen if they're off-screen
local function pinsOnScreen(lane: Model): Vector2
	local camera = Workspace.CurrentCamera
	local inset = GuiService:GetGuiInset()
	local pinSpot = lane:FindFirstChild("PinSpot") :: BasePart?
	if pinSpot then
		local point, visible = camera:WorldToViewportPoint(pinSpot.Position + Vector3.new(0, 2, 0))
		if visible then
			return Vector2.new(point.X, point.Y) - inset
		end
	end
	return camera.ViewportSize / 2 - inset
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
		popup.TextTransparency = 0
		popupScale.Scale = 0.4
		TweenService:Create(popupScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()

		popupToken += 1
		local token = popupToken
		task.delay(1.4, function()
			if token ~= popupToken then
				return
			end
			TweenService:Create(popup, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
			task.wait(0.25)
			if token == popupToken then
				popup.Visible = false
			end
		end)
	end

	local throwResult = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ThrowResult")
	throwResult.OnClientEvent:Connect(function(data)
		if data.UserId == player.UserId and data.Reward then
			task.delay(data.RollTime, function()
				showReward(data.Reward)
				local from = pinsOnScreen(data.Lane)
				if data.Reward.Coins > 0 then
					local icons = math.floor(data.Reward.Coins / JUICE.CoinsPerIcon)
					flyIcons(bar.Coins, math.clamp(icons, JUICE.CoinIconsMin, JUICE.CoinIconsMax), from)
				end
				-- A Gem Hunter gem flies in on its own (TraitFx.GemPayout)
				local gems = data.Reward.Gems - (if data.Reward.GemHunter then Config.Rewards.PerfectGemAmount else 0)
				if gems > 0 then
					flyIcons(bar.Gems, math.min(gems, 5), from)
				end
			end)
		end
	end)
end

return HudController
