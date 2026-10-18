-- The throw from the Throw Lab: hold to charge, let go in the gold. Sends the release to the server.
-- The UI itself (StarterGui.ThrowUI) is built in Studio; this script turns its AimBar into the charge bar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Modifiers = require(Shared.Modules.Modifiers)
local LaneUtil = require(Shared.Modules.LaneUtil)
local ThrowRules = require(Shared.Modules.ThrowRules)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local THROW = Config.Throw
local player = Players.LocalPlayer

local PINK = Color3.fromRGB(255, 43, 214)
local GOLD = Color3.fromRGB(255, 200, 40)
local CYAN = Color3.fromRGB(70, 230, 255)
local DARK = Color3.fromRGB(28, 16, 52)
local INK = Color3.fromRGB(40, 10, 60)

local ThrowController = {}

local state = "Hidden" -- Hidden, Ready, Charging, Waiting
local charge, chargeClock = 0, 0
local currentLane: Model? = nil
local sentAt = 0
local held: InputObject? = nil
local lastStreak = 0 -- your streak before the latest throw, to say when it ends

-- The bar gets a little faster at higher ranks
local function meterSpeedScale(): number
	return 1 + THROW.MeterSpeedPerRank * ((player:GetAttribute("Rank") or 1) - 1)
end

local function laneReady(lane: Model): boolean
	return Workspace:GetServerTimeNow() >= (lane:GetAttribute("ReadyAt") or 0)
end

local function sweetSpot(): (number, number)
	local ball = Balls.Get(player:GetAttribute("EquippedBall")) or Config.Balls[1]
	return ThrowRules.SweetSpot(ball, Modifiers.Current(), Workspace:GetServerTimeNow())
end

function ThrowController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("ThrowUI")
	local panel = gui:WaitForChild("Panel")
	local hint = panel:WaitForChild("Hint")
	local bar = panel:WaitForChild("AimBar") :: Frame
	local button = panel:WaitForChild("ThrowButton") :: TextButton
	local powerBar = gui:WaitForChild("PowerBar")
	local resultText = gui:WaitForChild("ResultText")
	local resultScale = resultText:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	resultScale.Parent = resultText
	local resultStroke = resultText:FindFirstChildOfClass("UIStroke")
	local resultToken = 0

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local throwRequest = remotes:WaitForChild("ThrowRequest")
	local throwResult = remotes:WaitForChild("ThrowResult")

	-- The old aim bar becomes the charge bar: dark track, gold zone, pink fill, white needle
	powerBar.Visible = false
	bar.GutterLeft.Visible = false
	bar.GutterRight.Visible = false
	bar.BackgroundColor3 = DARK
	bar.ClipsDescendants = false
	local barStroke = bar:FindFirstChildOfClass("UIStroke")
	local barScale = bar:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	barScale.Parent = bar
	local sweet = bar.SweetZone :: Frame
	sweet.AnchorPoint = Vector2.new(0.5, 0.5)
	sweet.BackgroundColor3 = GOLD
	sweet.BackgroundTransparency = 0.35
	sweet.ZIndex = 2
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = PINK
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 2
	fill.Parent = bar
	local fillCorner = bar:FindFirstChildOfClass("UICorner")
	if fillCorner then
		fillCorner:Clone().Parent = fill
	end
	local needle = bar.Needle :: Frame
	needle.ZIndex = 3

	-- PERFECT! pops above the bar the moment you let go in the gold
	local perfectLabel = Instance.new("TextLabel")
	perfectLabel.Name = "Perfect"
	perfectLabel.AnchorPoint = Vector2.new(0.5, 1)
	perfectLabel.Position = UDim2.new(0.5, 0, 0, -6)
	perfectLabel.Size = UDim2.new(1, 0, 0, 52)
	perfectLabel.BackgroundTransparency = 1
	perfectLabel.Font = Enum.Font.FredokaOne
	perfectLabel.TextScaled = true
	perfectLabel.Text = "PERFECT!"
	perfectLabel.TextColor3 = GOLD
	perfectLabel.Visible = false
	perfectLabel.ZIndex = 5
	perfectLabel.Parent = panel
	local perfectStroke = Instance.new("UIStroke")
	perfectStroke.Thickness = 4
	perfectStroke.Color = INK
	perfectStroke.Parent = perfectLabel
	local perfectScale = Instance.new("UIScale")
	perfectScale.Parent = perfectLabel
	local perfectToken = 0

	local function showPerfect()
		perfectToken += 1
		local token = perfectToken
		perfectLabel.Visible = true
		perfectLabel.TextTransparency = 0
		perfectStroke.Transparency = 0
		perfectLabel.Rotation = (math.random() - 0.5) * 8
		perfectScale.Scale = 0.3
		TweenService:Create(perfectScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.12,
		}):Play()
		task.delay(0.4, function()
			if token ~= perfectToken then
				return
			end
			local fade = TweenInfo.new(0.2)
			TweenService:Create(perfectLabel, fade, { TextTransparency = 1 }):Play()
			TweenService:Create(perfectStroke, fade, { Transparency = 1 }):Play()
			task.wait(0.2)
			if token == perfectToken then
				perfectLabel.Visible = false
			end
		end)
	end

	local function drawBar(value: number, inGold: boolean, charging: boolean)
		local center, size = sweetSpot()
		sweet.Position = UDim2.fromScale(center, 0.5)
		sweet.Size = UDim2.new(size, 0, 1, 8)
		fill.Size = UDim2.fromScale(value, 1)
		needle.Position = UDim2.fromScale(value, 0.5)
		fill.BackgroundColor3 = if inGold then GOLD else PINK
		if barStroke then
			barStroke.Color = if inGold then GOLD elseif charging then PINK else Color3.new(1, 1, 1)
		end
		barScale.Scale = if inGold then 1.06 else 1
	end

	local function setState(newState: string)
		state = newState
		panel.Visible = newState ~= "Hidden"
		if newState == "Ready" then
			charge = 0
			hint.Text = "HOLD TO CHARGE - LET GO IN THE GOLD"
			button.Text = "HOLD!"
			drawBar(0, false, false)
		elseif newState == "Charging" then
			charge, chargeClock = 0, 0
			hint.Text = "LET GO IN THE GOLD!"
			button.Text = "LET GO!"
			Sfx.Play("Charge", 0.9)
		elseif newState == "Waiting" then
			hint.Text = "ROLLING..."
			button.Text = "..."
		end
	end

	-- Back to ready; still holding from before = start charging straight away, no wasted time
	local function getReady()
		setState("Ready")
		if held then
			setState("Charging")
		end
	end

	local function release()
		local center, size = sweetSpot()
		local perfect = ThrowRules.InSpot(charge, center, size)
		drawBar(charge, perfect, false)
		if perfect then
			showPerfect()
			UiFx.Flash(GOLD, 0.25, 0.2)
		end
		UiFx.Pop(bar, if perfect then 1.15 else 1.08, 0.25)
		sentAt = os.clock()
		setState("Waiting")
		throwRequest:FireServer(charge)
	end

	local function press(input: InputObject)
		if held then
			return
		end
		held = input
		if state == "Ready" and currentLane and laneReady(currentLane) then
			setState("Charging")
		end
	end

	-- Is this the same press that started the charge? (the same finger, mouse button or button)
	local function sameInput(a: InputObject, b: InputObject): boolean
		if a.UserInputType == Enum.UserInputType.Touch then
			return a == b
		end
		if a.UserInputType == Enum.UserInputType.MouseButton1 then
			return b.UserInputType == Enum.UserInputType.MouseButton1
		end
		return a.KeyCode == b.KeyCode
	end

	-- Hold the button (touch or mouse), the mouse anywhere on the lane, or R2 on a controller
	UiFx.Press(button, true)
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			press(input)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			press(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if not held or not sameInput(held, input) then
			return
		end
		held = nil
		if state == "Charging" then
			release()
		end
	end)
	-- Clicking off the game window counts as letting go
	UserInputService.WindowFocusReleased:Connect(function()
		held = nil
	end)

	local function showText(message: string, color: Color3, isStrike: boolean, size: number)
		resultText.Text = message
		resultText.TextColor3 = color
		resultText.TextTransparency = 0
		if resultStroke then
			resultStroke.Transparency = 0
		end
		resultText.Visible = true

		-- Quick pop (from the Throw Lab): in big, settle, out
		resultScale.Scale = size * 0.3
		resultText.Rotation = (math.random() - 0.5) * 8
		TweenService:Create(resultScale, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = size * 1.12,
		}):Play()

		resultToken += 1
		local token = resultToken
		local time = if isStrike then THROW.CelebrationTime else 0.55
		task.delay(0.14, function()
			if token == resultToken then
				TweenService:Create(resultScale, TweenInfo.new(0.1), { Scale = size }):Play()
			end
		end)
		task.delay(time * 0.65, function()
			if token ~= resultToken then
				return
			end
			local out = TweenInfo.new(time * 0.35)
			TweenService:Create(resultScale, out, { Scale = size * 1.1 }):Play()
			TweenService:Create(resultText, out, { TextTransparency = 1 }):Play()
			if resultStroke then
				TweenService:Create(resultStroke, out, { Transparency = 1 }):Play()
			end
			task.wait(time * 0.35)
			if token == resultToken then
				resultText.Visible = false
			end
		end)
	end

	local function showResult(data)
		local previous = lastStreak
		local streak = data.Streak or 0
		lastStreak = streak
		local isStrike = data.Tier == "Strike" or data.Tier == "PerfectStrike"
		if isStrike then
			local level = math.min(math.max(streak, 1), THROW.StreakGrowthStopsAt)
			local grow = 1 + THROW.StreakGrowth * (level - 1)
			local special = table.find(THROW.SpecialStreaks, streak) ~= nil
			if special then
				grow *= 1.3
			end
			local name = THROW.StreakNames[math.max(streak, 1)] or (streak .. " IN A ROW!")
			local color = if special then GOLD elseif streak <= 1 then PINK else CYAN
			showText(name, color, true, math.min(grow, 1.7)) -- capped so it always fits on screen
		elseif streak > 0 then
			-- Streak Saver kept the streak alive: just the pin count
			showText(data.Count .. " PINS", Color3.new(1, 1, 1), false, 1)
		elseif previous >= 2 then
			showText(data.Count .. " PINS - STREAK OVER", Color3.fromRGB(200, 190, 230), false, 1)
		else
			showText(
				if data.Count == 9 then "9 PINS! SO CLOSE" else data.Count .. " PINS",
				Color3.new(1, 1, 1),
				false,
				1
			)
		end
	end

	throwResult.OnClientEvent:Connect(function(data)
		if data.UserId == player.UserId then
			-- Strikes show the moment the ball hits; other results a beat later
			local isStrike = data.Tier == "Strike" or data.Tier == "PerfectStrike"
			task.delay(data.RollTime + (if isStrike then 0 else 0.25), showResult, data)
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local ownLane = LaneUtil.GetOwnedLane(player.UserId)
		currentLane = if root and ownLane and LaneUtil.IsInThrowZone(ownLane, root.Position) then ownLane else nil

		if not currentLane then
			if state ~= "Hidden" then
				setState("Hidden")
			end
			return
		end

		if state == "Hidden" then
			getReady()
		elseif state == "Ready" then
			if held and laneReady(currentLane) then
				setState("Charging") -- pressed while the lane was still busy
			else
				drawBar(0, false, false) -- the gold zone can slide (Moving Gold)
				hint.Text = if laneReady(currentLane) then "HOLD TO CHARGE - LET GO IN THE GOLD" else "WAIT..."
			end
		elseif state == "Charging" then
			-- Fills, then slides back down and up again while you keep holding
			chargeClock += dt / THROW.ChargeTime * meterSpeedScale()
			local t = chargeClock % 2
			charge = if t <= 1 then t else 2 - t
			local center, size = sweetSpot()
			drawBar(charge, ThrowRules.InSpot(charge, center, size), true)
		elseif state == "Waiting" then
			-- Ready again once the lane is free (or if the server ignored the throw)
			local waited = os.clock() - sentAt
			if (waited > 0.5 and laneReady(currentLane)) or waited > 6 then
				getReady()
			end
		end
	end)

	setState("Hidden")
end

return ThrowController
