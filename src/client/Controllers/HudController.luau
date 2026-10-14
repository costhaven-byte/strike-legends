-- Shows coins, gems and XP at the top of the screen, and a "+coins +XP" popup after each throw.
-- The UI itself (StarterGui.HUD) is built in Studio; this script only fills it in.
-- Values come from Player attributes, which only the server sets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local STATS = { "Coins", "Gems", "XP" }
local COUNT_TIME = 0.6 -- seconds for a number to tick up to its new value

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

function HudController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
	local bar = gui:WaitForChild("Bar")
	for _, key in STATS do
		bindStat(bar:WaitForChild(key), key)
	end

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
