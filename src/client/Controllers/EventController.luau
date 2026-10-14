-- The surprise layer on screen: the lane modifier banner and timer, the "almost there" bar,
-- and the big popups for Golden Pins, "LUCKY!", bonus gems and free crates.
-- The UI itself (StarterGui.EventUI) is built in Studio; this script fills it in and animates it.
-- Everything shown comes from attributes and throw results the server sends.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Modifiers = require(Shared.Modules.Modifiers)
local Progression = require(Shared.Modules.Progression)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local LaneFx = require(Modules.LaneFx)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local GOLD = Config.GoldenPin.Color
local CRATE_COLOR = Color3.fromRGB(60, 230, 255)
local GEM_COLOR = Color3.fromRGB(255, 90, 200)

local player = Players.LocalPlayer

local EventController = {}

-- 12345 -> "12,345"
local function withCommas(n: number): string
	local text = tostring(math.floor(n))
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end

function EventController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("EventUI")
	local pill = gui:WaitForChild("ModifierPill") :: Frame
	local banner = gui:WaitForChild("Banner") :: Frame
	local bannerScale = banner:WaitForChild("UIScale") :: UIScale
	local bar = gui:WaitForChild("AlmostBar") :: Frame
	local barScale = bar:WaitForChild("UIScale") :: UIScale
	local popup = gui:WaitForChild("Popup") :: TextLabel
	local popupScale = popup:WaitForChild("UIScale") :: UIScale

	-- Popups: one at a time, queued so two surprises on one throw both get their moment
	local queue = {}
	local showing = false
	local function runQueue()
		if showing then
			return
		end
		showing = true
		while #queue > 0 do
			local item = table.remove(queue, 1)
			popup.Text = item.Text
			popup.TextColor3 = item.Color
			popup.Sub.Text = item.Sub or ""
			popup.TextTransparency = 0
			popup.Sub.TextTransparency = 0
			popup.Visible = true
			popupScale.Scale = item.Big and 2.6 or 1.8
			popup.Rotation = if item.Big then -8 else 0
			local slam = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			TweenService:Create(popupScale, slam, { Scale = 1 }):Play()
			TweenService:Create(popup, slam, { Rotation = 0 }):Play()
			task.wait(item.Big and 2 or 1.3)
			local fade = TweenInfo.new(0.25)
			TweenService:Create(popup, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(popup.Sub, fade, { TextTransparency = 1 }):Play()
			task.wait(0.25)
		end
		popup.Visible = false
		showing = false
	end
	local function showPopup(text: string, color: Color3, sub: string?, big: boolean?)
		table.insert(queue, { Text = text, Color = color, Sub = sub, Big = big })
		task.spawn(runQueue)
	end

	-- Lane modifier: banner when it changes, pill with the time left
	local function onModifier(announce: boolean)
		local modifier = Modifiers.Current()
		pill.Visible = modifier ~= nil
		if not modifier then
			return
		end
		pill.ModName.Text = modifier.Name
		pill.ModName.TextColor3 = modifier.Color
		pill.UIStroke.Color = modifier.Color
		UiFx.Pop(pill, 1.2, 0.35)
		if not announce then
			return
		end
		banner.Title.Text = modifier.Name
		banner.Title.TextColor3 = modifier.Color
		banner.Sub.Text = modifier.Text
		banner.Visible = true
		bannerScale.Scale = 0.3
		TweenService:Create(bannerScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		Sfx.Play("StreakUp", 0.9, 1.2)
		task.delay(3, function()
			local shrink = TweenService:Create(
				bannerScale,
				TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In),
				{ Scale = 0 }
			)
			shrink:Play()
			shrink.Completed:Wait()
			banner.Visible = false
		end)
	end
	Workspace:GetAttributeChangedSignal("LaneModifier"):Connect(function()
		onModifier(true)
	end)
	onModifier(false)
	banner.Visible = false

	RunService.Heartbeat:Connect(function()
		if pill.Visible then
			local left =
				math.ceil(math.max(0, (Workspace:GetAttribute("LaneModifierEnds") or 0) - Workspace:GetServerTimeNow()))
			pill.Timer.Text = ("%d:%02d"):format(left // 60, left % 60)
		end
	end)

	-- "Almost there": whichever reward you are closest to (as a share of the way there)
	local pulse = TweenService:Create(
		barScale,
		TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.08 }
	)
	local pulsing = false
	local function refreshBar()
		local options = {}

		local per = Config.FreeCrates.StrikesPerCrate
		local strikes = player:GetAttribute("CrateStrikes") or 0
		local left = per - strikes
		table.insert(options, {
			Progress = strikes / per,
			Text = ("FREE CRATE IN %d STRIKE%s"):format(left, if left == 1 then "" else "S"),
			Color = CRATE_COLOR,
		})

		local rankIndex = player:GetAttribute("Rank") or 1
		local rank = Progression.GetRank(rankIndex)
		local nextRank = Config.Ranks[rankIndex + 1]
		local xp = player:GetAttribute("XP") or 0
		if nextRank and xp < nextRank.XP then
			table.insert(options, {
				Progress = math.max(0, (xp - rank.XP) / (nextRank.XP - rank.XP)),
				Text = ("%s IN %s XP"):format(nextRank.Name:upper(), withCommas(nextRank.XP - xp)),
				Color = nextRank.Color,
			})
		end

		local best = options[1]
		for _, option in options do
			if option.Progress > best.Progress then
				best = option
			end
		end
		bar.Label.Text = best.Text
		bar.UIStroke.Color = best.Color
		bar.Fill.BackgroundColor3 = best.Color
		TweenService:Create(bar.Fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(math.clamp(best.Progress, 0.04, 1), 1),
		}):Play()

		local close = best.Progress >= Config.AlmostThere.PulseAt
		if close and not pulsing then
			pulse:Play()
		elseif not close and pulsing then
			pulse:Cancel()
			barScale.Scale = 1
		end
		pulsing = close
	end
	for _, key in { "CrateStrikes", "XP", "Rank" } do
		player:GetAttributeChangedSignal(key):Connect(refreshBar)
	end
	refreshBar()

	-- Free crates: a popup when one is earned (they wait at the Crate Shop kiosk, whose price plaque shows FREE xN)
	local freeCrates = player:GetAttribute("FreeCrates") or 0
	local function refreshBadge()
		local count = player:GetAttribute("FreeCrates") or 0
		if count > freeCrates then
			showPopup("FREE CRATE!", CRATE_COLOR, "Open it at the Crate Shop", true)
			Sfx.Play("RevealBig", 1.1)
		end
		freeCrates = count
	end
	player:GetAttributeChangedSignal("FreeCrates"):Connect(refreshBadge)
	refreshBadge()

	-- Golden Pin on your lane: a heads-up when it appears ("LUCKY!" if your ball's trait made it happen)
	local function watchLane(lane: Model)
		lane:GetAttributeChangedSignal("GoldenPin"):Connect(function()
			if lane:GetAttribute("OwnerId") ~= player.UserId then
				return
			end
			local pin = lane:GetAttribute("GoldenPin") or 0
			if pin == 0 then
				return
			end
			local lucky = lane:GetAttribute("GoldenLucky") == true
			local luckyTrait = Balls.GetTrait("Lucky")
			if lucky and luckyTrait then
				showPopup(luckyTrait.Popup, luckyTrait.Color, "Your ball found a Golden Pin!")
				LaneFx.Trait(luckyTrait, lane.PinSpot.Position + Vector3.new(0, 2, 0))
			else
				showPopup("GOLDEN PIN!", GOLD, "Knock it down for a big bonus")
			end
			Sfx.Play("Coin", 0.8, 1.5)
		end)
	end
	for _, lane in LaneUtil.GetLanes() do
		watchLane(lane)
	end

	-- Your own throw: Golden Pin jackpot and bonus gems
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ThrowResult").OnClientEvent:Connect(function(data)
		if data.UserId ~= player.UserId then
			return
		end
		task.delay(data.RollTime + 0.6, function() -- just after the STRIKE text lands
			local golden = data.Golden
			if golden and golden.Hit then
				local extras = { ("x%g COINS"):format(Config.GoldenPin.CoinMultiplier) }
				if golden.Gems > 0 then
					table.insert(extras, ("+%d GEMS"):format(golden.Gems))
				end
				if golden.Crate then
					table.insert(extras, "+FREE CRATE")
				end
				showPopup("GOLDEN PIN!", GOLD, table.concat(extras, "   "), true)
				Sfx.Play("PerfectSting", 1.1)
				Sfx.Play("Cheer", 1.2)
			end
			if (data.ModifierGems or 0) > 0 then
				showPopup("BONUS GEM!", GEM_COLOR, ("+%d GEM"):format(data.ModifierGems))
				Sfx.Play("Coin", 1.5)
			end
		end)
	end)
end

return EventController
