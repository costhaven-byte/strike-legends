-- The surprise layer on screen: the lane modifier banner and timer, the "next goal" bar,
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
local PowerLevels = require(Shared.Modules.PowerLevels)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local TraitFx = require(Modules.TraitFx)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local GOLD = Config.GoldenPin.Color
local CRATE_COLOR = Color3.fromRGB(60, 230, 255)
local GEM_COLOR = Color3.fromRGB(255, 90, 200)
local POWER_COLOR = Color3.fromRGB(255, 43, 214)

-- 1234 -> "1.23K" (the bar is small)
local function short(n: number): string
	if n >= 1e12 then
		return ("%.3gT"):format(n / 1e12)
	elseif n >= 1e9 then
		return ("%.3gB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.3gM"):format(n / 1e6)
	elseif n >= 1e3 then
		return ("%.3gK"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end

local player = Players.LocalPlayer

local EventController = {}

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

	-- First crate goal (Config.Onboarding.FirstCrateGoal): when it's the goal and affordable, a beam runs from the
	-- player to that crate's kiosk station
	local firstCrate = Balls.GetCrate(Config.Onboarding.FirstCrateGoal)
	local station = Workspace:FindFirstChild("Hub")
		and Workspace.Hub:FindFirstChild("CrateShop")
		and Workspace.Hub.CrateShop:FindFirstChild("Stations")
		and Workspace.Hub.CrateShop.Stations:FindFirstChild(Config.Onboarding.FirstCrateGoal)
	local stationButton = station and station:FindFirstChild("BuyButton") :: BasePart?
	local guide: { Beams: { Beam }, From: Attachment }? = nil
	local function setGuide(on: boolean)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not on or not stationButton or not root then
			if guide then
				for _, beam in guide.Beams do
					beam:Destroy()
				end
				guide.From:Destroy()
				guide = nil
			end
			return
		end
		if guide and guide.From.Parent == root then
			return
		end
		setGuide(false)
		local from = Instance.new("Attachment")
		from.Name = "CrateGuideFrom"
		from.Position = Vector3.new(0, -1.5, 0)
		from.Parent = root
		local to = stationButton:FindFirstChild("CrateGuideTo") :: Attachment?
		if not to then
			to = Instance.new("Attachment")
			to.Name = "CrateGuideTo"
			to.Parent = stationButton
		end
		-- A soft gold band with sparkles running along it toward the crate
		local beams = {}
		for i = 1, 2 do
			local beam = Instance.new("Beam")
			beam.Name = "CrateGuide"
			beam.Attachment0 = from
			beam.Attachment1 = to
			beam.Color = ColorSequence.new(GOLD)
			beam.LightEmission = 1
			beam.FaceCamera = true
			if i == 1 then
				beam.Width0 = 1.6
				beam.Width1 = 1.6
				beam.Brightness = 2
				beam.Transparency = NumberSequence.new(0.55)
			else
				beam.Width0 = 2.4
				beam.Width1 = 2.4
				beam.Brightness = 5
				beam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				beam.TextureMode = Enum.TextureMode.Wrap
				beam.TextureLength = 3
				beam.TextureSpeed = 2.5
			end
			beam.Parent = root
			table.insert(beams, beam)
		end
		guide = { Beams = beams, From = from }
	end
	local wantGuide = false
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		setGuide(wantGuide)
	end)

	-- "Next goal": always shows the closest goal (rank progress lives in the HUD rank bar):
	-- the next Power Level, the first-3-minutes gift crate, the first crate to buy (until one is bought),
	-- or the next free crate (ties go to the first one)
	local pulse = TweenService:Create(
		barScale,
		TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.08 }
	)
	local pulsing = false
	local function refreshBar()
		local options = {}

		local nextLevel = PowerLevels.Next(player:GetAttribute("PowerLevel") or 1)
		if nextLevel then
			local coins = player:GetAttribute("Coins") or 0
			table.insert(options, {
				Progress = math.min(coins / math.max(nextLevel.Price, 1), 1),
				Text = if coins >= nextLevel.Price
					then ("NEXT: BUY POWER LV %d NOW!"):format(nextLevel.Level)
					else ("NEXT: POWER LV %d  %s / %s"):format(
						nextLevel.Level,
						short(coins),
						short(nextLevel.Price)
					),
				Color = POWER_COLOR,
			})
		end

		local onboard = Config.Onboarding
		if onboard.Enabled and (player:GetAttribute("Onboarding") or 3) <= 1 then
			local throws = player:GetAttribute("OnboardThrows") or 0
			local giftLeft = math.max(onboard.GiftAfterThrows - throws, 1)
			table.insert(options, {
				Progress = throws / onboard.GiftAfterThrows,
				Text = ("FREE GIFT CRATE IN %d THROW%s"):format(giftLeft, if giftLeft == 1 then "" else "S"),
				Color = GOLD,
			})
		end

		if firstCrate and (player:GetAttribute("CratesBought") or 0) == 0 then
			local coins = player:GetAttribute("Coins") or 0
			table.insert(options, {
				Progress = math.min(coins / math.max(firstCrate.Price, 1), 1),
				Text = if coins >= firstCrate.Price
					then "NEW BALL! FOLLOW THE BEAM"
					else ("NEXT: NEW BALL (%s CRATE)  %s / %s"):format(
						firstCrate.Id:upper(),
						short(coins),
						short(firstCrate.Price)
					),
				Color = GOLD,
				Guide = coins >= firstCrate.Price,
			})
		end

		local per = Config.FreeCrates.StrikesPerCrate
		local strikes = player:GetAttribute("CrateStrikes") or 0
		local left = per - strikes
		table.insert(options, {
			Progress = strikes / per,
			Text = ("FREE CRATE IN %d STRIKE%s"):format(left, if left == 1 then "" else "S"),
			Color = CRATE_COLOR,
		})

		local best = options[1]
		for _, option in options do
			if option.Progress > best.Progress then
				best = option
			end
		end
		wantGuide = best.Guide == true
		setGuide(wantGuide)
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
	for _, key in { "CrateStrikes", "Coins", "PowerLevel", "Onboarding", "OnboardThrows", "CratesBought" } do
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
				TraitFx.Lucky(lane) -- clover, sparkles, sound and "LUCKY!"
			else
				showPopup("GOLDEN PIN!", GOLD, "Knock it down for a big bonus")
				Sfx.Play("Coin", 0.8, 1.5)
			end
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
