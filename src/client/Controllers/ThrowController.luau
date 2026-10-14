-- Runs the aim and power meters and sends the locked values to the server.
-- The UI itself (StarterGui.ThrowUI) is built in Studio; this script only moves it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local THROW = Config.Throw
local player = Players.LocalPlayer

local RESULT_TEXT = {
	Gutter = { "GUTTER", Color3.fromRGB(255, 80, 90) },
	Weak = { "%d PINS", Color3.fromRGB(255, 255, 255) },
	Good = { "%d PINS!", Color3.fromRGB(120, 230, 255) },
	Nine = { "SO CLOSE! 9", Color3.fromRGB(255, 220, 80) },
	Strike = { "STRIKE!", Color3.fromRGB(255, 60, 210) },
	PerfectStrike = { "PERFECT STRIKE!", Color3.fromRGB(255, 240, 90) },
}

local ThrowController = {}

local state = "Hidden" -- Hidden, Aim, Power, Waiting
local phase = 0
local aimValue, powerValue = 0, 0
local currentLane: Model? = nil
local sentAt = 0

-- Triangle waves: aim sweeps -1..1, power goes 0..1..0
local function aimWave(p: number): number
	return 4 * math.abs(p - math.floor(p + 0.5)) - 1
end
local function powerWave(p: number): number
	return 1 - math.abs((p % 1) * 2 - 1)
end

-- Meters get a little faster at higher ranks
local function meterSpeedScale(): number
	return 1 + THROW.MeterSpeedPerRank * ((player:GetAttribute("Rank") or 1) - 1)
end

local function laneReady(lane: Model): boolean
	return Workspace:GetServerTimeNow() >= (lane:GetAttribute("ReadyAt") or 0)
end

function ThrowController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("ThrowUI")
	local panel = gui:WaitForChild("Panel")
	local hint = panel:WaitForChild("Hint")
	local aimBar = panel:WaitForChild("AimBar")
	local button = panel:WaitForChild("ThrowButton")
	local powerBar = gui:WaitForChild("PowerBar")
	local resultText = gui:WaitForChild("ResultText")
	local resultScale = resultText:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	resultScale.Parent = resultText
	local resultStroke = resultText:FindFirstChildOfClass("UIStroke")
	local resultToken = 0

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local throwRequest = remotes:WaitForChild("ThrowRequest")
	local throwResult = remotes:WaitForChild("ThrowResult")

	-- Size the coloured zones from Config and the equipped ball so the UI always matches the rules
	-- (the same maths as the server's ThrowResolver)
	local hookZone = Instance.new("Frame")
	hookZone.Name = "HookZone"
	hookZone.BorderSizePixel = 0
	hookZone.BackgroundTransparency = 0.1
	hookZone.ZIndex = aimBar.SweetZone.ZIndex
	hookZone.Parent = aimBar

	local function refreshZones()
		local ball = Balls.Get(player:GetAttribute("EquippedBall")) or Config.Balls[1]
		local sweet = THROW.AimSweetSpot + (ball.Forgiveness or 0)
		aimBar.SweetZone.Size = UDim2.fromScale(sweet, 1)
		aimBar.GutterLeft.Size = UDim2.fromScale((1 - THROW.GutterAim) / 2, 1)
		aimBar.GutterRight.Size = UDim2.fromScale((1 - THROW.GutterAim) / 2, 1)

		-- Curve: the hook side also counts as perfect aim further out
		local curve = Balls.TraitValue(ball, "Curve")
		local curveTrait = Balls.GetTrait("Curve")
		hookZone.Visible = curve > 0 and curveTrait ~= nil
		if hookZone.Visible then
			local edge = math.min(sweet / (1 - curve), THROW.GutterAim)
			local side = curveTrait.HookSide or 1
			hookZone.BackgroundColor3 = curveTrait.Color
			hookZone.AnchorPoint = Vector2.new(if side > 0 then 0 else 1, 0)
			hookZone.Position = UDim2.fromScale(0.5 + side * sweet / 2, 0)
			hookZone.Size = UDim2.fromScale((edge - sweet) / 2, 1)
		end

		-- Heavy: a wider power sweet zone
		local widen = (THROW.PowerSweetMax - THROW.PowerSweetMin) * Balls.TraitValue(ball, "Heavy") / 2
		local low, high = THROW.PowerSweetMin - widen, math.min(THROW.PowerSweetMax + widen, 1)
		powerBar.SweetZone.Position = UDim2.fromScale(0, 1 - low)
		powerBar.SweetZone.Size = UDim2.fromScale(1, high - low)
	end
	player:GetAttributeChangedSignal("EquippedBall"):Connect(refreshZones)
	refreshZones()

	-- Trait popups ("STREAK SAVED!") stack under the result text (the TraitPopups frame is built in Studio)
	local popups = gui:WaitForChild("TraitPopups") :: Frame
	local popupOrder = 0

	local function showTraitPopup(trait)
		popupOrder += 1
		local label = Instance.new("TextLabel")
		label.LayoutOrder = popupOrder
		label.Size = UDim2.new(1, 0, 0, 40)
		label.BackgroundTransparency = 1
		label.Text = trait.Popup
		label.TextColor3 = trait.Color
		label.TextScaled = true
		label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 10, 40)
		stroke.Thickness = 2.5
		stroke.Parent = label
		local scale = Instance.new("UIScale")
		scale.Scale = 2
		scale.Parent = label
		label.Parent = popups
		TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
		local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 1.4)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		task.delay(1.8, label.Destroy, label)
	end

	local function setState(newState: string)
		state = newState
		panel.Visible = newState ~= "Hidden"
		powerBar.Visible = newState == "Power"
		if newState == "Aim" then
			phase = math.random()
			hint.Text = "TAP TO LOCK AIM"
			button.Text = "TAP!"
		elseif newState == "Power" then
			phase = 0
			hint.Text = "TAP TO LOCK POWER"
		elseif newState == "Waiting" then
			hint.Text = "ROLLING..."
			button.Text = "..."
		end
	end

	local function press()
		if state == "Aim" then
			if currentLane and not laneReady(currentLane) then
				return
			end
			Sfx.Play("Tap", 1)
			UiFx.Pop(aimBar, 1.08, 0.25)
			setState("Power")
		elseif state == "Power" then
			Sfx.Play("Tap", 1.25)
			UiFx.Pop(powerBar, 1.12, 0.25)
			sentAt = os.clock()
			setState("Waiting")
			throwRequest:FireServer(aimValue, powerValue)
		end
	end

	local function showResult(data)
		local entry = RESULT_TEXT[data.Tier]
		resultText.Text = if data.Count == 1 then "1 PIN" else entry[1]:format(data.Count)
		resultText.TextColor3 = entry[2]
		resultText.TextTransparency = 0
		if resultStroke then
			resultStroke.Transparency = 0
		end
		resultText.Visible = true

		-- Strikes slam in from huge with a twist and stay up longer; everything else pops in
		local isStrike = data.Tier == "Strike" or data.Tier == "PerfectStrike"
		resultScale.Scale = if isStrike then 2.8 else 0.3
		resultText.Rotation = if isStrike then -12 else 0
		local slam = TweenInfo.new(if isStrike then 0.45 else 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(resultScale, slam, { Scale = 1 }):Play()
		TweenService:Create(resultText, slam, { Rotation = if isStrike then -3 else 0 }):Play()

		resultToken += 1
		local token = resultToken
		task.delay(if isStrike then 1.6 else 1.1, function()
			if token ~= resultToken then
				return
			end
			-- Grow and fade away
			local out = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(resultScale, out, { Scale = 1.4 }):Play()
			TweenService:Create(resultText, out, { TextTransparency = 1 }):Play()
			if resultStroke then
				TweenService:Create(resultStroke, out, { Transparency = 1 }):Play()
			end
			task.wait(0.25)
			if token == resultToken then
				resultText.Visible = false
			end
		end)
	end

	UiFx.Press(button, true) -- silent: press() plays its own tap sound
	button.Activated:Connect(press)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			press()
		end
	end)

	throwResult.OnClientEvent:Connect(function(data)
		if data.UserId == player.UserId then
			task.delay(data.RollTime, showResult, data)
			-- Curve shows as the ball hooks; the rest when it reaches the pins, one after another
			local delayAfter = 0.15
			for _, traitId in data.Traits or {} do
				local trait = Balls.GetTrait(traitId)
				if trait and traitId == "Curve" then
					task.delay(data.RollTime * 0.55, showTraitPopup, trait)
				elseif trait then
					task.delay(data.RollTime + delayAfter, showTraitPopup, trait)
					delayAfter += 0.3
				end
			end
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
			setState("Aim")
		elseif state == "Aim" then
			phase += dt * THROW.AimMeterSpeed * meterSpeedScale()
			aimValue = aimWave(phase)
			aimBar.Needle.Position = UDim2.fromScale((aimValue + 1) / 2, 0.5)
			local ready = laneReady(currentLane)
			hint.Text = if ready then "TAP TO LOCK AIM" else "WAIT..."
		elseif state == "Power" then
			phase += dt * THROW.PowerMeterSpeed * meterSpeedScale()
			powerValue = powerWave(phase)
			powerBar.Fill.Size = UDim2.fromScale(1, powerValue)
			powerBar.Needle.Position = UDim2.fromScale(0.5, 1 - powerValue)
		elseif state == "Waiting" then
			-- Back to aiming once the lane is free (or if the server ignored the throw)
			local waited = os.clock() - sentAt
			if (waited > 0.5 and laneReady(currentLane)) or waited > 6 then
				setState("Aim")
			end
		end
	end)

	setState("Hidden")
end

return ThrowController
