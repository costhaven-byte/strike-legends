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
local LaneUtil = require(Shared.Modules.LaneUtil)

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

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local throwRequest = remotes:WaitForChild("ThrowRequest")
	local throwResult = remotes:WaitForChild("ThrowResult")

	-- Size the coloured zones from Config so the UI always matches the rules
	aimBar.SweetZone.Size = UDim2.fromScale(THROW.AimSweetSpot, 1)
	aimBar.GutterLeft.Size = UDim2.fromScale((1 - THROW.GutterAim) / 2, 1)
	aimBar.GutterRight.Size = UDim2.fromScale((1 - THROW.GutterAim) / 2, 1)
	powerBar.SweetZone.Position = UDim2.fromScale(0, 1 - THROW.PowerSweetMin)
	powerBar.SweetZone.Size = UDim2.fromScale(1, THROW.PowerSweetMax - THROW.PowerSweetMin)

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
			setState("Power")
		elseif state == "Power" then
			sentAt = os.clock()
			setState("Waiting")
			throwRequest:FireServer(aimValue, powerValue)
		end
	end

	local function showResult(data)
		local entry = RESULT_TEXT[data.Tier]
		resultText.Text = if data.Count == 1 then "1 PIN" else entry[1]:format(data.Count)
		resultText.TextColor3 = entry[2]
		resultText.Visible = true
		resultScale.Scale = 0.3
		TweenService
			:Create(resultScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		task.delay(1.2, function()
			resultText.Visible = false
		end)
	end

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
