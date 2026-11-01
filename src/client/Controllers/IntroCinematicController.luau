-- Day 1 video intro (Studio only, Config.IntroCinematic). Press the key in Play mode: the HUD hides, your character
-- stands on a Back Alley lane and the camera plays the shots (hard cuts) with big captions, Rizzo's line and wave,
-- and the first crate deal sign. Then you throw for real (only the throw bar on, any release is a PERFECT strike),
-- the camera cuts behind the pins for the hit and the screen cuts to black. Everything goes back the way it was at
-- the end (you stay on the intro's lane). Never runs in the live game.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local SunKit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("SunKit"))

local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local LaneVisuals = require(script.Parent.LaneVisuals)
local RizzoController = require(script.Parent.RizzoController)

local INTRO = Config.IntroCinematic
local player = Players.LocalPlayer

local IntroCinematicController = {}

local function ease(t: number): number
	return t * t * (3 - 2 * t) -- smoothstep: soft start and stop
end

-- The big caption: white, thick black outline, pops in
local function buildCaption()
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroCinematic"
	gui.DisplayOrder = 1000
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.3)
	label.Size = UDim2.fromScale(0.9, 0.16)
	label.BackgroundTransparency = 1
	label.FontFace = SunKit.Swap(Font.new("rbxasset://fonts/families/LuckiestGuy.json"))
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.TextWrapped = true
	label.Text = ""
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 72
	limit.Parent = label
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("06060F")
	stroke.Thickness = 4
	stroke.Parent = label
	local scale = Instance.new("UIScale")
	scale.Parent = label
	label.Parent = gui
	-- The cut to black at the very end
	local black = Instance.new("Frame")
	black.Size = UDim2.fromScale(1, 1)
	black.BackgroundColor3 = Color3.new(0, 0, 0)
	black.BorderSizePixel = 0
	black.ZIndex = 10
	black.Visible = false
	black.Parent = gui
	gui.Parent = player:WaitForChild("PlayerGui")
	local pop = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local function show(text: string?)
		label.Text = text or ""
		label.Visible = text ~= nil and text ~= ""
		scale.Scale = 1.35
		TweenService:Create(scale, pop, { Scale = 1 }):Play()
	end
	return gui, show, black
end

function IntroCinematicController:Start()
	if not (RunService:IsStudio() and INTRO and INTRO.Enabled) then
		return
	end
	local captionGui, caption, black = buildCaption()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local introRemote = remotes:WaitForChild("IntroCinematic")
	local throwResult = remotes:WaitForChild("ThrowResult")
	local playing = false

	local function play()
		playing = true
		local camera = Workspace.CurrentCamera
		local rizzo = RizzoController.Cinematic

		-- Hide every other screen and Roblox's own menus, remember what was on
		local hidden = {}
		for _, gui in player.PlayerGui:GetChildren() do
			if gui:IsA("ScreenGui") and gui ~= captionGui and gui.Enabled then
				gui.Enabled = false
				table.insert(hidden, gui)
			end
		end
		local core = {}
		for _, kind in Enum.CoreGuiType:GetEnumItems() do
			if kind ~= Enum.CoreGuiType.All then
				core[kind] = StarterGui:GetCoreGuiEnabled(kind)
			end
		end
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)

		-- Stand the character on the lane's approach, facing the pins
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local homeCFrame, wasAnchored = root and root.CFrame, root and root.Anchored
		local lane = Workspace:FindFirstChild("BackAlley") and Workspace.BackAlley:FindFirstChild(INTRO.Lane)
		local approach = lane and lane:FindFirstChild("Approach") :: BasePart?
		-- The server hands you this lane and makes your next throw an assisted PERFECT (LaneService, ThrowService)
		local THROW = INTRO.Throw
		introRemote:FireServer(THROW ~= nil)
		if root and humanoid and approach then
			local spot = approach.Position + Vector3.new(0, approach.Size.Y / 2, 0)
			local up = humanoid.HipHeight + root.Size.Y / 2
			root.Anchored = true
			root.CFrame = CFrame.lookAt(spot + Vector3.new(0, up, 0), spot + Vector3.new(0, up, -10))
		end

		local oldType, oldFov = camera.CameraType, camera.FieldOfView
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = INTRO.FieldOfView
		captionGui.Enabled = true

		for _, shot in INTRO.Shots do
			caption(shot.Text)
			if rizzo then
				rizzo.ShowDeal(shot.Deal == true)
				if shot.Rizzo then
					rizzo.Say(shot.Rizzo)
					rizzo.Wave()
				else
					rizzo.Hush()
				end
			end
			local start = os.clock()
			repeat
				local t = ease(math.clamp((os.clock() - start) / shot.Time, 0, 1))
				local pos = shot.From.Pos:Lerp(shot.To.Pos, t)
				local look = shot.From.Look:Lerp(shot.To.Look, t)
				camera.CFrame = CFrame.lookAt(pos, look)
				RunService.RenderStepped:Wait()
			until os.clock() - start >= shot.Time
		end

		-- Your throw: the normal camera behind you, only the throw bar on
		local threw = false
		local throwGui = player.PlayerGui:FindFirstChild("ThrowUI") :: ScreenGui?
		if THROW and root and lane and throwGui then
			threw = true
			caption(THROW.Text)
			if rizzo then
				rizzo.Hush()
				rizzo.ShowDeal(false)
			end
			root.Anchored = wasAnchored
			camera.FieldOfView = oldFov
			camera.CFrame = CFrame.lookAt(
				(root.CFrame * CFrame.new(0, 4, 11)).Position,
				root.Position + root.CFrame.LookVector * 20
			)
			camera.CameraType = Enum.CameraType.Custom
			throwGui.Enabled = true

			local result = nil
			local listen = throwResult.OnClientEvent:Connect(function(data)
				if data.UserId == player.UserId then
					result = data
				end
			end)
			local waitStart = os.clock()
			repeat
				RunService.RenderStepped:Wait()
			until result or os.clock() - waitStart >= THROW.WaitLimit
			listen:Disconnect()

			if result then
				-- Cut behind the pins just before the ball gets there, and hold through the hit
				task.wait(math.max(0, result.RollTime - THROW.CutBefore))
				throwGui.Enabled = false
				LaneVisuals.CameraHeld = true
				local pinSpot = lane.PinSpot.Position
				local forward = lane.BallStart.CFrame.LookVector -- from the bowler towards the pins
				local right = forward:Cross(Vector3.yAxis)
				local cam = THROW.PinCam
				local from = pinSpot + forward * cam.Back + Vector3.yAxis * cam.Up + right * cam.Side
				local look = pinSpot - forward * cam.LookAt + Vector3.yAxis * cam.LookUp
				local length = THROW.CutBefore + THROW.Hold
				local start = os.clock()
				repeat
					-- a slow push in towards the pins
					local t = math.clamp((os.clock() - start) / length, 0, 1)
					camera.CameraType = Enum.CameraType.Scriptable
					camera.FieldOfView = INTRO.FieldOfView
					camera.CFrame = CFrame.lookAt(from - forward * t * 1.2, look)
					RunService.RenderStepped:Wait()
				until os.clock() - start >= length
			end
			caption(nil)
			black.Visible = true
			task.wait(THROW.Black)
		end

		-- Put everything back (behind the black screen)
		introRemote:FireServer(false)
		LaneVisuals.CameraHeld = false
		if rizzo then
			rizzo.Hush()
			rizzo.ShowDeal(false)
		end
		camera.CameraType = oldType
		camera.FieldOfView = oldFov
		if threw and root then
			root.Anchored = wasAnchored -- you stay on the intro's lane (it's yours now)
		elseif root and homeCFrame then
			root.CFrame = homeCFrame
			root.Anchored = wasAnchored
		end
		for kind, on in core do
			StarterGui:SetCoreGuiEnabled(kind, on)
		end
		for _, gui in hidden do
			gui.Enabled = true
		end
		captionGui.Enabled = false
		black.Visible = false
		playing = false
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and not playing and input.KeyCode == INTRO.Key then
			task.spawn(play)
		end
	end)
	print(("[IntroCinematic] Studio: press %s to play the Day 1 intro"):format(INTRO.Key.Name))
end

return IntroCinematicController
