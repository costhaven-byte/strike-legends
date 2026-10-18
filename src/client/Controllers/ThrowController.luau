-- The throw from the Throw Lab: hold to charge, let go in the gold. Sends the release to the server.
-- The UI itself (StarterGui.ThrowUI) is built in Studio; this script hides its old AimBar and builds the
-- half-circle power arc above the panel. The character's throw animation follows the meter (ThrowPose).
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
local ThrowPose = require(Modules.ThrowPose)

local THROW = Config.Throw
local player = Players.LocalPlayer

local PINK = Color3.fromRGB(255, 43, 214)
local GOLD = Color3.fromRGB(255, 200, 40)
local CYAN = Color3.fromRGB(70, 230, 255)
local DARK = Color3.fromRGB(28, 16, 52)
local INK = Color3.fromRGB(40, 10, 60)
local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 59, 92) -- the overcharge cap
local OVER = THROW.Overcharge
local READY_HINT = if OVER.Enabled
	then "HOLD - LET GO IN THE GOLD, OR GAMBLE ON RED"
	else "HOLD TO CHARGE - LET GO IN THE GOLD"

-- The arc: a half circle like the top of a bowling ball. Empty on the left, full on the right.
local ARC_SEGMENTS = 100
local ARC_RADIUS = 112 -- pixels to the middle of the ring
local ARC_THICKNESS = 22
local ARC_RIDER = 30 -- the little ball that rides the arc
local ARC_HEIGHT = ARC_RADIUS + ARC_THICKNESS
local ARC_SIDE = 250 -- pixels right of the screen centre, so the arc sits beside your bowler, not over them
local ARC_LIFT = 20 -- pixels above the panel, clear of the hint text
-- Or the same half circle standing up, curving around your bowler's right side like ")":
-- empty at the bottom, full at the top (Config.Throw.MeterStyle picks)
local IS_SIDE = THROW.MeterStyle == "Side"
local SIDE_SIDE = 250 -- pixels right of the screen centre to the middle of the standing arc
local METER_WIDTH = if IS_SIDE then ARC_HEIGHT else ARC_HEIGHT * 2
local METER_HEIGHT = if IS_SIDE then ARC_HEIGHT * 2 else ARC_HEIGHT
local METER_SIDE = if IS_SIDE then SIDE_SIDE else ARC_SIDE
local LABEL_ROOM = if IS_SIDE then 32 else 0 -- the standing arc's label sits on top of it, not inside

local ThrowController = {}

local state = "Hidden" -- Hidden, Ready, Charging, Waiting
local charge = 0
local holdStartedAt = 0 -- os.clock() when this charge began
local currentLane: Model? = nil
local sentAt = 0
local held: InputObject? = nil
local lastStreak = 0 -- your streak before the latest throw, to say when it ends
local savedWalkSpeed: number? = nil -- you stand still while you charge and throw
local releasedPerfect = false -- the arc stays lit gold after a PERFECT release
local wasInRed = false -- the bar was in the overcharge cap last frame (to play the warning once per visit)

-- Where the bar is now (the server works out the same thing from its own timing of the hold)
local function chargeNow(): number
	return ThrowRules.ChargeAt(os.clock() - holdStartedAt, player:GetAttribute("Rank") or 1)
end

local function laneReady(lane: Model): boolean
	return Workspace:GetServerTimeNow() >= (lane:GetAttribute("ReadyAt") or 0)
end

local function equippedBall()
	return Balls.Get(player:GetAttribute("EquippedBall")) or Config.Balls[1]
end

-- A brand new player's first throw is assisted (Config.Onboarding): the server makes it a PERFECT
local function assisted(): boolean
	return Config.Onboarding.Enabled and player:GetAttribute("Onboarding") == 0
end

local function readyHint(): string
	return if assisted() then "HOLD... THEN LET GO!" else READY_HINT
end

local function sweetSpot(): (number, number)
	if assisted() then
		-- The whole arc is gold: any release is a PERFECT
		local ceiling = ThrowRules.GoldCeiling()
		return ceiling / 2, ceiling
	end
	return ThrowRules.SweetSpot(
		equippedBall(),
		Modifiers.Current(),
		Workspace:GetServerTimeNow(),
		currentLane and currentLane:GetAttribute("GoldCenter"),
		player:GetAttribute("Streak") or 0
	)
end

-- Where a meter value sits on the arc or bar (a GUI position) and which way it runs there (degrees)
local function arcPoint(value: number, radius: number): (UDim2, number)
	if IS_SIDE then
		local angle = math.pi * (value - 0.5) -- -90 degrees (bottom) to 90 (top)
		return UDim2.new(0, math.cos(angle) * radius, 0.5, -math.sin(angle) * radius), 90 - math.deg(angle)
	end
	local angle = math.pi * (1 - value) -- 180 degrees (left) to 0 (right)
	return UDim2.new(0.5, math.cos(angle) * radius, 1, -math.sin(angle) * radius), 90 - math.deg(angle)
end

local function humanoid(): Humanoid?
	return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
end

-- Plant your feet facing the pins while you charge and throw; walk again once it's over
local function lockFeet(locked: boolean)
	local human = humanoid()
	if not human then
		return
	end
	if locked and not savedWalkSpeed then
		savedWalkSpeed = human.WalkSpeed
		human.WalkSpeed = 0
		human.AutoRotate = false
	elseif not locked and savedWalkSpeed then
		human.WalkSpeed = savedWalkSpeed
		human.AutoRotate = true
		savedWalkSpeed = nil
	end
end

local function faceLane(dt: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local start = currentLane and currentLane:FindFirstChild("BallStart") :: BasePart?
	if root and start then
		local forward = start.CFrame.LookVector
		local target = CFrame.lookAt(root.Position, root.Position + Vector3.new(forward.X, 0, forward.Z))
		root.CFrame = root.CFrame:Lerp(target, math.min(1, dt * 14))
	end
end

-- Hidden, Ready, Charging or Waiting (other screens wait for Ready before taking over the camera)
function ThrowController.State(): string
	return state
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
	local throwHold = remotes:WaitForChild("ThrowHold")
	local throwResult = remotes:WaitForChild("ThrowResult")

	-- The old straight bars are replaced by the half-circle arc
	powerBar.Visible = false
	bar.Visible = false
	local hookColor = (Balls.GetTrait("Curve") or {}).Color or PINK

	-- Holder (scaled to the screen) > arc (pops on release) > ring segments and the rider ball
	local holder = Instance.new("Frame")
	holder.Name = "PowerArc"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, METER_SIDE, 0, -ARC_LIFT)
	holder.Size = UDim2.fromOffset(METER_WIDTH, METER_HEIGHT)
	holder.BackgroundTransparency = 1
	holder.Parent = panel
	local holderScale = Instance.new("UIScale")
	holderScale.Parent = holder
	local arc = Instance.new("Frame")
	arc.Name = "Arc"
	arc.AnchorPoint = Vector2.new(0.5, 1)
	arc.Position = UDim2.fromScale(0.5, 1)
	arc.Size = UDim2.fromScale(1, 1)
	arc.BackgroundTransparency = 1
	arc.Parent = holder

	local function round(object: GuiObject)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = object
	end

	local segmentLength = math.pi * ARC_RADIUS / ARC_SEGMENTS + 1.5
	local function makeSegment(value: number, thickness: number, color: Color3, z: number): Frame
		local segment = Instance.new("Frame")
		segment.AnchorPoint = Vector2.new(0.5, 0.5)
		segment.BorderSizePixel = 0
		segment.BackgroundColor3 = color
		segment.Size = UDim2.fromOffset(segmentLength, thickness)
		segment.Position, segment.Rotation = arcPoint(value, ARC_RADIUS)
		segment.ZIndex = z
		segment.Parent = arc
		return segment
	end
	local segments = {}
	for i = 1, ARC_SEGMENTS do
		local value = (i - 0.5) / ARC_SEGMENTS
		makeSegment(value, ARC_THICKNESS + 8, INK, 1) -- dark outline behind the ring
		segments[i] = { Frame = makeSegment(value, ARC_THICKNESS, DARK, 2), Value = value, Key = "" }
	end
	-- Rounded ends
	for _, value in { 0, 1 } do
		local cap = Instance.new("Frame")
		cap.AnchorPoint = Vector2.new(0.5, 0.5)
		cap.Position = arcPoint(value, ARC_RADIUS)
		cap.Size = UDim2.fromOffset(ARC_THICKNESS + 8, ARC_THICKNESS + 8)
		cap.BackgroundColor3 = INK
		cap.ZIndex = 1
		round(cap)
		cap.Parent = arc
	end

	-- The rider: a little bowling ball in your ball's colour, with three finger holes
	local rider = Instance.new("Frame")
	rider.Name = "Rider"
	rider.AnchorPoint = Vector2.new(0.5, 0.5)
	rider.Size = UDim2.fromOffset(ARC_RIDER, ARC_RIDER)
	rider.ZIndex = 6
	round(rider)
	rider.Parent = arc
	local riderStroke = Instance.new("UIStroke")
	riderStroke.Thickness = 3
	riderStroke.Color = WHITE
	riderStroke.Parent = rider
	for _, hole in { Vector2.new(0.36, 0.3), Vector2.new(0.62, 0.3), Vector2.new(0.5, 0.62) } do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(hole.X, hole.Y)
		dot.Size = UDim2.fromScale(0.2, 0.2)
		dot.BackgroundColor3 = INK
		dot.ZIndex = 7
		round(dot)
		dot.Parent = rider
	end

	-- "POWER" inside the arc (on top of the bar); during a strike streak it warns that the gold is shrinking
	local arcLabel = Instance.new("TextLabel")
	arcLabel.AnchorPoint = Vector2.new(0.5, 1)
	arcLabel.Position = if IS_SIDE then UDim2.new(0, 0, 0, -4) else UDim2.new(0.5, 0, 1, -4)
	arcLabel.Size = UDim2.fromOffset(160, 26)
	arcLabel.BackgroundTransparency = 1
	arcLabel.Font = Enum.Font.FredokaOne
	arcLabel.TextScaled = true
	arcLabel.TextColor3 = WHITE
	arcLabel.ZIndex = 5
	arcLabel.Parent = arc
	local arcLabelStroke = Instance.new("UIStroke")
	arcLabelStroke.Thickness = 2
	arcLabelStroke.Color = INK
	arcLabelStroke.Parent = arcLabel

	-- PERFECT! pops above the arc the moment you let go in the gold
	local perfectLabel = Instance.new("TextLabel")
	perfectLabel.Name = "Perfect"
	perfectLabel.AnchorPoint = Vector2.new(0.5, 1)
	perfectLabel.Position = UDim2.new(0.5, 0, 0, -METER_HEIGHT - LABEL_ROOM - 8)
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

	local function showPerfect(text: string, color: Color3)
		perfectLabel.Text = text
		perfectLabel.TextColor3 = color
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

	-- After each throw the gold glides to its new spot. It only glides while you can't throw,
	-- so what you see while charging is always exactly what the server checks.
	local shownCenter: number? = nil
	local function drawBar(value: number, inGold: boolean, charging: boolean, dt: number?)
		local center, size = sweetSpot()
		if dt and shownCenter and not charging then
			shownCenter += (center - shownCenter) * math.min(1, dt * 8)
		else
			shownCenter = center
		end
		local shown = shownCenter :: number
		local hook = ThrowRules.HookWidth(equippedBall(), size)
		for _, segment in segments do
			local offset = math.abs(segment.Value - shown)
			local zone = if offset <= size / 2
				then "Gold"
				elseif hook > 0 and offset <= size / 2 + hook then "Hook"
				elseif ThrowRules.InOvercharge(segment.Value) then "Red"
				else ""
			local filled = segment.Value <= value
			local key = zone .. (if filled then "F" else "") .. (if filled and inGold then "G" else "")
			if key ~= segment.Key then
				segment.Key = key
				local frame = segment.Frame
				frame.Size = UDim2.fromOffset(segmentLength, ARC_THICKNESS + (if zone == "Gold" then 10 else 0))
				frame.ZIndex = if zone == "Gold" then 3 else 2
				frame.BackgroundColor3 = if zone == "Gold"
					then (if filled then Color3.new(1, 0.95, 0.6) else GOLD)
					elseif zone == "Hook" then (if filled then hookColor:Lerp(WHITE, 0.35) else hookColor)
					elseif zone == "Red" then (if filled then RED:Lerp(WHITE, 0.4) else RED:Lerp(DARK, 0.25))
					elseif filled then (if inGold then GOLD else PINK)
					else DARK
			end
		end
		rider.Position, rider.Rotation = arcPoint(math.clamp(value, 0, 1), ARC_RADIUS)
		rider.BackgroundColor3 = equippedBall().Color
		local inRed = charging and not inGold and ThrowRules.InOvercharge(value)
		riderStroke.Color = if inGold then GOLD elseif inRed then RED elseif charging then PINK else WHITE
		riderStroke.Thickness = if inGold or inRed then 5 else 3
		local streak = player:GetAttribute("Streak") or 0
		arcLabel.Text = if inRed then "RISKY!" elseif streak > 0 then "GOLD SHRINKS x" .. streak else "POWER"
		arcLabel.TextColor3 = if inRed then RED elseif streak > 0 then GOLD else WHITE
	end

	local function setState(newState: string)
		state = newState
		panel.Visible = newState ~= "Hidden"
		if newState == "Hidden" then
			ThrowPose.Stop(player.Character)
			lockFeet(false)
		elseif newState == "Ready" then
			charge = 0
			hint.Text = readyHint()
			button.Text = "HOLD!"
			drawBar(0, false, false)
			lockFeet(false)
		elseif newState == "Charging" then
			charge, holdStartedAt = 0, os.clock()
			wasInRed = false
			throwHold:FireServer() -- the server starts its own clock for this hold
			hint.Text = "LET GO IN THE GOLD!"
			button.Text = "LET GO!"
			Sfx.Play("Charge", 0.9)
			lockFeet(true)
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
		local holdTime = os.clock() - holdStartedAt
		charge = chargeNow()
		local center, size = sweetSpot()
		local gold = ThrowRules.InSpot(charge, center, size)
		local hooked = not gold and ThrowRules.InSpot(charge, center, size, ThrowRules.HookWidth(equippedBall(), size))
		local perfect = gold or hooked
		releasedPerfect = perfect
		drawBar(charge, perfect, false)
		if gold then
			showPerfect("PERFECT!", GOLD)
			UiFx.Flash(GOLD, 0.25, 0.2)
		elseif hooked then
			showPerfect("HOOK! PERFECT!", hookColor)
			UiFx.Flash(hookColor, 0.25, 0.2)
		elseif ThrowRules.InOvercharge(charge) and not assisted() then
			-- The gamble: the server says whether it pays off when the ball lands
			showPerfect("OVERCHARGE...?", RED)
			UiFx.Flash(RED, 0.25, 0.2)
		end
		UiFx.Pop(arc, if perfect then 1.15 else 1.08, 0.25)
		sentAt = os.clock()
		setState("Waiting")
		-- The arm swings down first; the ball leaves the hand (and the server hears about it) at the bottom
		ThrowPose.Release(player.Character, ThrowRules.Level(player:GetAttribute("PowerLevel")))
		-- Only how long you held; the server checks it against its own timing and waits out the down-swing
		throwRequest:FireServer(holdTime)
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
		if data.Overcharge == "Wasted" then
			Sfx.Play("Overcooked")
			showText(if previous >= 2 then "OVERCOOKED! STREAK OVER" else "OVERCOOKED! GUTTER", RED, false, 1.15)
		elseif data.Overcharge == "Blast" then
			local name = if streak >= 2 then "OVERCHARGE x" .. streak .. "!" else "OVERCHARGE!"
			showText(name, RED:Lerp(GOLD, 0.35), true, 1.4)
		elseif isStrike then
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
			showText(data.Count .. " PINS", WHITE, false, 1)
		elseif previous >= 2 then
			showText(data.Count .. " PINS - STREAK OVER", Color3.fromRGB(200, 190, 230), false, 1)
		else
			showText(if data.Count == 9 then "9 PINS! SO CLOSE" else data.Count .. " PINS", WHITE, false, 1)
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
		-- Smaller arc on short screens (phones held sideways)
		local screenScale = math.clamp(Workspace.CurrentCamera.ViewportSize.Y / 720, 0.6, 1)
		holderScale.Scale = screenScale
		holder.Position = UDim2.new(0.5, METER_SIDE * screenScale, 0, -ARC_LIFT * screenScale)
		perfectLabel.Position =
			UDim2.new(0.5, METER_SIDE * screenScale, 0, -(METER_HEIGHT + LABEL_ROOM + ARC_LIFT + 8) * screenScale)

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
				drawBar(0, false, false, dt) -- the gold zone glides to its new spot (and slides with Moving Gold)
				hint.Text = if laneReady(currentLane) then readyHint() else "WAIT..."
			end
		elseif state == "Charging" then
			-- Fills, then slides back down and up again while you keep holding; the arm swings with it
			charge = chargeNow()
			local center, size = sweetSpot()
			local hook = ThrowRules.HookWidth(equippedBall(), size)
			local inGold = ThrowRules.InSpot(charge, center, size, hook)
			drawBar(charge, inGold, true)
			-- A warning buzz each time the bar climbs into the red cap
			local inRed = not inGold and not assisted() and ThrowRules.InOvercharge(charge)
			if inRed and not wasInRed then
				Sfx.Play("OverchargeWarn")
			end
			wasInRed = inRed
			ThrowPose.Charge(player.Character, charge, ThrowRules.Level(player:GetAttribute("PowerLevel")))
			faceLane(dt)
		elseif state == "Waiting" then
			drawBar(charge, releasedPerfect, false, dt)
			if not ThrowPose.IsBusy(player.Character) then
				lockFeet(false)
			end
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
