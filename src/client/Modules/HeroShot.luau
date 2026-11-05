-- Short low-camera shots on big moments only (owner 2026-11-05, numbers in Config.HeroShot). Two hard cuts:
-- RUSH: the camera sits on the lane looking back at your bowler and the ball rushes at it in slow motion.
-- HIT: the camera sits low beside the rack, the ball comes in, one flash, the pins burst in slow motion.
-- The HUD hides while it plays. Visual only: the server keeps counting your throws, this just skips drawing them.
-- ThrowController owns the camera and asks HeroShot.Camera each frame. SETTINGS: EFFECTS off = no hero shots.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local CameraShake = require(script.Parent.CameraShake)
local Settings = require(script.Parent.Settings)
local Sfx = require(script.Parent.Sfx)
local SlKit = require(script.Parent.SlKit)
local ThrowFx = require(script.Parent.ThrowFx)
local UiFx = require(script.Parent.UiFx)

local HERO = Config.HeroShot
local player = Players.LocalPlayer

local HeroShot = {
	Watching = false, -- ThrowController: you are holding THROW right now (auto throws never get a hero shot)
}

local current = nil
local joined = os.clock()
local lastShot = -math.huge
local lastBall: string? = nil

function HeroShot.Playing(): boolean
	return current ~= nil
end

-- ===== HUD =====
local function hideHud(): { any }
	local hidden = {}
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return hidden
	end
	local fx = UiFx.Layer()
	for _, gui in playerGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui ~= fx and gui.Enabled then
			if gui.Name == "ThrowUI" then
				-- ThrowUI stays enabled: a disabled one counts as a popup and drops your held press
				for _, child in gui:GetChildren() do
					if child:IsA("GuiObject") and child.Visible then
						child.Visible = false
						table.insert(hidden, child)
					end
				end
			else
				gui.Enabled = false
				table.insert(hidden, gui)
			end
		end
	end
	return hidden
end

local function showHud(hidden: { any })
	for _, item in hidden do
		if item.Parent then
			if item:IsA("ScreenGui") then
				item.Enabled = true
			else
				item.Visible = true
			end
		end
	end
end

-- ===== Speed lines: hard white wedges around the edge of the screen, pointing at the middle, redrawn many times a
-- second (a comic-book focus effect) =====
local function buildLines(color: Color3)
	local LINES = HERO.Lines
	local gui = Instance.new("ScreenGui")
	gui.Name = "HeroShotLines"
	gui.DisplayOrder = 2
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local image = SlKit.Icon("hatch_beam")
	local labels = {}
	for _ = 1, LINES.Count do
		local label = Instance.new("ImageLabel")
		label.BackgroundTransparency = 1
		label.Image = image
		label.ImageColor3 = color
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Parent = root
		table.insert(labels, label)
	end
	gui.Parent = player:FindFirstChildOfClass("PlayerGui")
	local clock = 0
	return {
		Gui = gui,
		Draw = function(dt: number)
			clock -= dt
			if clock > 0 then
				return
			end
			clock = 1 / LINES.PerSecond
			local view = Workspace.CurrentCamera.ViewportSize
			local reach = view.Magnitude / 2 -- middle of the screen to a corner
			for _, label in labels do
				local angle = math.random() * math.pi * 2
				local inner = reach * (LINES.Inner + math.random() * LINES.InnerRandom)
				local length = reach * 1.1 - inner
				local dirX, dirY = math.sin(angle), -math.cos(angle)
				local middle = inner + length / 2
				label.Position = UDim2.new(0.5, dirX * middle, 0.5, dirY * middle)
				label.Size = UDim2.fromOffset(reach * (LINES.Width + math.random() * LINES.Width), length)
				label.Rotation = math.deg(angle) + 180 -- the image's thin end points at the middle
				label.ImageTransparency = math.random() * LINES.Fade
			end
		end,
	}
end

-- ===== The shot =====
-- c: Rack, Forward, Right, Start, Head, Center, FloorY, HeadDistance, Speed, BallId, Lucky, Color (the hit's colour)
-- Returns the shot if this throw gets one, else nil. Call it for every one of your own throws.
function HeroShot.Try(c)
	local forced = RunService:IsStudio() and player:GetAttribute("HeroShotNext") == true
	local newBall = false
	if lastBall == nil then
		lastBall = c.BallId
	elseif HeroShot.Watching or forced then
		newBall = c.BallId ~= lastBall
		lastBall = c.BallId
	end
	local now = os.clock()
	if forced then
		player:SetAttribute("HeroShotNext", nil)
	else
		if not HERO.Enabled or current or not HeroShot.Watching or not Settings.Get("Vfx") then
			return nil
		end
		if newBall then
			if now - lastShot < HERO.NewBallGap then
				return nil
			end
		elseif not c.Lucky or now - joined < HERO.FirstAfter or now - lastShot < HERO.Gap then
			return nil
		end
	end
	if current then
		return nil
	end

	local RUSH, HIT = HERO.Rush, HERO.Hit
	local camera = Workspace.CurrentCamera
	local shot = { Stop = HIT.Stop, Stretch = HERO.Stretch, Spread = HIT.Spread }
	local phase = "Rush"
	local phaseAt = now
	local passAt = RUSH.Ahead + RUSH.PassBy
	local hud = hideHud()
	local lines = buildLines(c.Color)
	local oldFov = camera.FieldOfView
	ThrowFx.SlowMoLook(true)

	-- A spot beside a wall (the lane's edge) films from the other side instead
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Exclude
	rays.FilterDescendantsInstances = { c.Rack.Folder, player.Character }
	local function eyeFor(base: Vector3, side: number, up: number, look: Vector3): Vector3
		local eye = base + c.Right * side
		eye = Vector3.new(eye.X, c.FloorY + up, eye.Z)
		if Workspace:Raycast(look, eye - look, rays) then
			local other = base - c.Right * side
			return Vector3.new(other.X, c.FloorY + up, other.Z)
		end
		return eye
	end
	local rushLook = Vector3.new(c.Start.X, c.FloorY + RUSH.LookUp, c.Start.Z)
	local rushEye = eyeFor(c.Start + c.Forward * RUSH.Ahead, RUSH.Side, RUSH.Up, rushLook)
	local hitLook = Vector3.new(c.Center.X, c.FloorY + HIT.LookUp, c.Center.Z)
	local hitEye = eyeFor(c.Head - c.Forward * HIT.Back, HIT.Side, HIT.Up, hitLook)

	local function finish()
		if current ~= shot then
			return
		end
		current = nil
		lastShot = os.clock()
		showHud(hud)
		lines.Gui:Destroy()
		ThrowFx.SlowMoLook(false)
		camera.FieldOfView = oldFov
		c.Rack:SetTimeScale(1)
	end

	-- How fast the ball runs right now (1 = normal)
	function shot.Rate(): number
		if current ~= shot then
			return 1
		elseif phase == "Rush" then
			return passAt / (RUSH.Time * c.Speed)
		elseif phase == "Run" then
			return HIT.RunIn / (HIT.RunTime * c.Speed)
		end
		return HIT.PinScale
	end

	-- The ball has moved: past the camera = cut to the rack, and the ball jumps to just before it
	function shot.Advance(travelled: number): number
		if current == shot and phase == "Rush" and travelled >= passAt then
			phase = "Run"
			phaseAt = os.clock()
			Sfx.Play("Throw", 0.85, 1)
			return math.max(travelled, c.HeadDistance - HIT.RunIn)
		end
		return travelled
	end

	-- The ball reached the pins. hold = seconds its signature effect holds them; stop = the freeze frame
	function shot.Hit(hold: number, stop: number)
		if current ~= shot then
			return
		end
		phase = "After"
		phaseAt = os.clock()
		c.Rack:SetTimeScale(HIT.PinScale)
		UiFx.Flash(c.Flash, HIT.FlashStrength, HIT.FlashTime)
		Sfx.Play("PerfectSting")
		CameraShake.Add(HIT.Shake)
		task.delay(hold + stop + HIT.Hold, finish)
	end

	-- Returns this frame's camera, or nil when no hero shot is playing
	function shot.View(dt: number): (CFrame, number)
		local t = os.clock() - phaseAt
		if phase == "Rush" then
			lines.Draw(dt)
			return CFrame.lookAt(rushEye + c.Forward * RUSH.Drift * t, rushLook), RUSH.Fov
		end
		if phase == "Run" or t < HIT.LinesAfter then
			lines.Draw(dt)
		else
			lines.Gui.Enabled = false
		end
		-- a slow push in with a little roll, from the cut to the end
		local total = if phase == "Run" then 0 else math.clamp(t / HIT.Hold, 0, 1)
		local eased = 1 - (1 - total) * (1 - total)
		local view = CFrame.lookAt(hitEye:Lerp(hitLook, HIT.PushIn * eased), hitLook)
		return view * CFrame.Angles(0, 0, math.rad(HIT.Roll * eased)), HIT.Fov
	end

	current = shot
	-- never stuck, whatever happens to the ball
	task.delay(HERO.MaxTime, finish)
	return shot
end

function HeroShot.Camera(dt: number): (CFrame?, number?)
	if not current then
		return nil, nil
	end
	return current.View(dt)
end

return HeroShot
