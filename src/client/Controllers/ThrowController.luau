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
local CoreLadder = require(Shared.Modules.CoreLadder)
local Balls = require(Shared.Modules.Balls)
local Modifiers = require(Shared.Modules.Modifiers)
local LaneUtil = require(Shared.Modules.LaneUtil)
local ThrowRules = require(Shared.Modules.ThrowRules)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local ThrowPose = require(Modules.ThrowPose)
local SlUi = require(Modules.SlUi)
local HudKit = require(Modules.HudKit)
local ResultText = require(Modules.ResultText)
local CameraShake = require(Modules.CameraShake)
local ThrowFx = require(Modules.ThrowFx)
local HeroShot = require(Modules.HeroShot)

local THROW = Config.Throw
local player = Players.LocalPlayer

local GOLD = Color3.fromRGB(255, 200, 40)
local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(255, 59, 92) -- the overcharge cap
local C = SlUi.Colors
local OUTLINE_IDLE = SlUi.Hex("1C5872")
local FLOW_MID = SlUi.Hex("1FE6FF")
local OVER = THROW.Overcharge
-- Addendum 4 core loop (Config.CoreLoop): hold the button to keep throwing, no meter, no PERFECT
local CORE = Config.CoreLoop
local CORE_ON = CORE.Enabled
local READY_HINT = if CORE_ON
	then "HOLD TO KEEP THROWING"
	elseif OVER.Enabled then "HOLD - LET GO IN THE GOLD, OR GAMBLE ON RED"
	else "HOLD TO CHARGE - LET GO IN THE GOLD"

-- The arc: a half circle like the top of a bowling ball. Empty on the left, full on the right.
-- Looks like the owner's "Power Meter" (HUD 1.1) + "Charge Meter Zones" (1.2) designs: a cyan outline, a navy
-- track with the gold PERFECT and red OVERCHARGE zones on it, a narrower fill on top and a white head.
local ARC_SEGMENTS = 100
local ARC_RADIUS = 112 -- pixels to the middle of the ring
local ARC_TRACK = 22 -- the zone band
local ARC_FILL = 12 -- the fill riding on the band
local ARC_NAVY = 34 -- dark ring around the band
local ARC_OUTLINE = 42 -- coloured outline around that
local ARC_HEAD = 20 -- the white dot at the tip of the fill
local ARC_HEIGHT = ARC_RADIUS + ARC_OUTLINE / 2
local ARC_SIDE = 250 -- pixels right of the screen centre, so the arc sits beside your bowler, not over them
local PLATE_ROOM = 70 -- the readout plate under the arc
local ARC_LIFT = 20 + PLATE_ROOM -- pixels above the panel, clear of the hint text
-- Or the same half circle standing up, curving around your bowler's right side like ")":
-- empty at the bottom, full at the top (Config.Throw.MeterStyle picks)
local IS_SIDE = THROW.MeterStyle == "Side"
local SIDE_SIDE = 250 -- pixels right of the screen centre to the middle of the standing arc
local METER_WIDTH = if IS_SIDE then ARC_HEIGHT else ARC_HEIGHT * 2
local METER_HEIGHT = if IS_SIDE then ARC_HEIGHT * 2 else ARC_HEIGHT
local METER_SIDE = if IS_SIDE then SIDE_SIDE else ARC_SIDE
local PHONE_DROP = 50 -- screen pixels lower on phones, so the top stays clear of the XP bar
local PHONE_LEFT = 24 -- and a little to the left, clear of the REBIRTH NOW pill on the right

-- Popups that must be closed before you can throw (ScreenGui, frame), so a tap meant for one never rolls the
-- ball by accident and costs a streak
local POPUPS = {
	{ "RankUpKitUI", "Screen" },
	{ "BallsUI", "Inventory" },
	{ "BallsUI", "Book" },
	{ "BallsUI", "Shop" },
	{ "BallsUI", "Opening" },
	{ "DailyCalendarUI", "Screen" },
	{ "PlaytimeUI", "Screen" },
	{ "TrialKitUI", "Screen" },
	{ "ZoneUnlockUI", "Screen" },
	{ "MascotUI", "Screen" }, -- pets + potions (ITEMS tab)
	{ "FusionUI", "Screen" }, -- zone 3 pet fusion
}

local ThrowController = {}
-- True while something holds the screen (the join intro): presses don't start a throw
ThrowController.Blocked = false

local state = "Hidden" -- Hidden, Ready, Charging, Waiting
local charge = 0
local holdStartedAt = 0 -- os.clock() when this charge began
local currentLane: Model? = nil
local sentAt = 0
local held: InputObject? = nil
local lastStreak = 0 -- your streak before the latest throw, to say when it ends
local savedWalkSpeed: number? = nil -- you stand still while you charge and throw
local releasedAt = 0 -- os.clock() of the last release (the fill flashes white, then drains)
local releasedValue = 0
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

-- A brand new player's first throw is assisted (Config.Onboarding): the server makes it a PERFECT.
-- A Pin Titan giant ball (BossService) works the same way: any release throws it. So does the Studio-only Day 1 video
-- intro's throw (IntroAssist).
local function assisted(): boolean
	return (Config.Onboarding.Enabled and player:GetAttribute("Onboarding") == 0)
		or player:GetAttribute("BossGiant") == true
		or player:GetAttribute("IntroAssist") == true
end

-- The Pin Titan fight (BossService): your throw spot in the sky arena, while you're on the platform, the fight takes
-- throws and you aren't DAZED by a Titan attack. You can throw from anywhere on the platform; the spot keeps your
-- ReadyAt and GoldCenter, so the throw treats it like a lane.
local BOSS_THROWS = { Armor = true, Core = true, Finale = true, Giant = true }
local function bossSpot(root: BasePart): Model?
	local name = player:GetAttribute("BossSpot")
	local bossState = ReplicatedStorage:FindFirstChild("BossEvent")
	local phase = bossState and bossState:GetAttribute("Phase")
	if not name or not BOSS_THROWS[phase] or (phase == "Giant" and not player:GetAttribute("BossGiant")) then
		return nil
	end
	local node: Instance? = Workspace
	for _, step in Config.Boss.Arena do
		node = node and node:FindFirstChild(step)
	end
	local spots = node and node:FindFirstChild("Spots")
	local spot = spots and spots:FindFirstChild(name) :: Model?
	local floor = node and node:FindFirstChild("Floor") :: BasePart?
	if not spot or not floor or Workspace:GetServerTimeNow() < (player:GetAttribute("BossDazedUntil") or 0) then
		return nil
	end
	local offset = root.Position - floor.Position
	local radius = math.max(floor.Size.X, floor.Size.Y, floor.Size.Z) / 2
	return if Vector2.new(offset.X, offset.Z).Magnitude <= radius + 2 then spot else nil
end

-- In the boss fight you turn to face the Titan instead of down a lane
local function bossTarget(): BasePart?
	if not player:GetAttribute("BossSpot") then
		return nil
	end
	local node: Instance? = Workspace
	for _, step in Config.Boss.Arena do
		node = node and node:FindFirstChild(step)
	end
	local titan = node and node:FindFirstChild("Titan")
	return titan and (titan:FindFirstChild("Target") or titan:FindFirstChild("Core")) :: BasePart?
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
	local inBoss = player:GetAttribute("BossSpot") ~= nil -- the boss fight has no lane modifiers and its own streak
	return ThrowRules.SweetSpot(
		equippedBall(),
		if inBoss then nil else Modifiers.Current(),
		Workspace:GetServerTimeNow(),
		currentLane and currentLane:GetAttribute("GoldCenter"),
		(if inBoss then player:GetAttribute("BossStreak") else player:GetAttribute("Streak")) or 0
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

-- Is a popup open (or the throw UI switched off, as during the showcase camera swing)?
local function popupOpen(throwGui: ScreenGui): boolean
	if not throwGui.Enabled then
		return true
	end
	local playerGui = throwGui.Parent
	if not playerGui then
		return false
	end
	for _, path in POPUPS do
		local screen = playerGui:FindFirstChild(path[1])
		local frame = screen and screen:FindFirstChild(path[2])
		if
			screen
			and screen:IsA("ScreenGui")
			and screen.Enabled
			and frame
			and frame:IsA("GuiObject")
			and frame.Visible
		then
			return true
		end
	end
	return false
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
	local titan = bossTarget()
	if root and titan then
		local dir = (titan.Position - root.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.5 then
			root.CFrame = root.CFrame:Lerp(CFrame.lookAt(root.Position, root.Position + dir), math.min(1, dt * 14))
		end
	elseif root and start then
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
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("ThrowUI") :: ScreenGui
	local panel = gui:WaitForChild("Panel")
	local hint = panel:WaitForChild("Hint")
	local bar = panel:WaitForChild("AimBar") :: Frame
	local button = panel:WaitForChild("ThrowButton") :: TextButton
	local powerBar = gui:WaitForChild("PowerBar")
	local resultText = gui:WaitForChild("ResultText")
	local resultStroke = resultText:FindFirstChildOfClass("UIStroke")

	-- ===== HOLD! button and hint line (owner's HUD Kit) =====
	-- HOLD! is pink (breathing a little while it waits), sinks and glows while held, grey "ROLLING..." while the ball
	-- rolls. The hint shows for the first 3 throws of a session, then fades; it comes back after 20 s idle.
	for _, child in button:GetChildren() do
		if child:IsA("UICorner") or child:IsA("UIStroke") or child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	button.BackgroundTransparency = 1
	button.Text = ""
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.fromScale(0.5, 1)
	-- V2 HUD (Config.Ui.HudV2, board B1/B2): a big green THROW with HOLD under it (XL button); bottom-right on phones
	local v2Kit = if HudKit.V2 then require(Modules.SlKit) else nil
	local holdPaint: any = if v2Kit then v2Kit.Paints.Green else "Pink"
	local holdBlock = HudKit.Block(button, {
		Name = "Kit",
		Paint = holdPaint,
		Ink = if v2Kit then v2Kit.C.Ink else nil,
		Strip = if v2Kit then 3 else nil,
		Radius = 16,
		Lip = 6,
	})
	holdBlock.Holder.Size = UDim2.fromScale(1, 1)
	HudKit.Press(holdBlock, true, button)
	local holdLabel = HudKit.Text(holdBlock.Face, if CORE_ON then "THROW" else "HOLD!", HudKit.Head, 28, HudKit.C.White, 3)
	holdLabel.Position = UDim2.fromOffset(0, 2)
	local holdSub: TextLabel? = nil
	if v2Kit then
		holdLabel.FontFace = v2Kit.Font;
		(holdLabel:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = v2Kit.C.Ink
		holdSub = HudKit.Text(holdBlock.Face, if CORE_ON then "HOLD" else "", v2Kit.Font, 15, HudKit.C.White, 2);
		(holdSub :: TextLabel).ZIndex = 5;
		((holdSub :: TextLabel):FindFirstChildOfClass("UIStroke") :: UIStroke).Color = v2Kit.C.Ink
	end
	hint.FontFace = HudKit.Body
	hint.TextScaled = false
	hint.RichText = true
	hint.TextColor3 = HudKit.C.White
	local hintStroke = hint:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	hintStroke.Color = HudKit.C.Ink
	hintStroke.Thickness = 2
	hintStroke.Parent = hint
	local holdSize = 28
	local phoneLayout = false
	HudKit.OnLayout(function(phone)
		phoneLayout = phone
		panel.Position = UDim2.new(0.5, 0, 1, if phone then -12 else -46)
		local _, size = HudKit.Spot("Hold", phone)
		button.Size = size :: UDim2
		holdBlock:SetRadius(if phone then 14 else 16)
		holdBlock:SetLip(if phone then 5 else 6)
		holdSize = if phone then 22 else 28
		if v2Kit then
			-- the design's spot: centred 32 px off the bottom (computer), its centre 92 px from the right (phone)
			local h = (size :: UDim2).Y.Offset
			panel.Position = if phone then UDim2.new(1, -92, 1, -14) else UDim2.new(0.5, 0, 1, -32)
			holdBlock:SetRadius(if phone then 14 else 24)
			holdSize = if phone then 26 else 52
			holdLabel.Position = UDim2.fromOffset(0, if phone then -6 else -12)
			local sub = holdSub :: TextLabel
			sub.TextSize = if phone then 9 else 15
			sub.Position = UDim2.new(0, 0, 0, if phone then 13 else 26);
			(holdLabel:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = if phone then 2 else 3
			hint.AnchorPoint = Vector2.new(0.5, 1)
			hint.Position = UDim2.new(0.5, 0, 1, -(h + 8))
			hint.Size = UDim2.fromOffset(if phone then 420 else 700, if phone then 12 else 20)
			hint.TextSize = if phone then 10 else 17
			hintStroke.Thickness = if phone then 1.5 else 2
			holdLabel.TextSize = if holdLabel.Text == "ROLLING..." then holdSize - 6 else holdSize
			return
		end
		holdLabel.TextSize = if holdLabel.Text == "ROLLING..." then holdSize - 6 else holdSize
		-- wider than the panel, so the line never wraps
		hint.AnchorPoint = Vector2.new(0.5, 0)
		hint.Position = UDim2.new(0.5, 0, 0, if phone then 54 else 34)
		hint.Size = UDim2.fromOffset(if phone then 420 else 700, if phone then 12 else 20)
		hint.TextSize = if phone then 10 else 17
		hintStroke.Thickness = if phone then 1.5 else 2
	end)

	local holdScale = holdBlock.Scale
	local idlePulse = TweenService:Create(
		holdScale,
		TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.04 }
	)
	-- look: "Ready", "Held" or "Rolling"
	local function setButton(text: string, look: string)
		holdLabel.Text = text
		holdLabel.TextSize = if look == "Rolling" then holdSize - 6 else holdSize
		holdBlock:Paint(if look == "Rolling" then (if v2Kit then v2Kit.Paints.Disabled else "Grey") else holdPaint)
		holdBlock:SetGlow(if look == "Held" and not v2Kit then HudKit.C.Pink else nil)
		if holdSub then
			holdSub.Visible = look == "Ready"
		end
		if look == "Ready" then
			holdScale.Scale = 1
			idlePulse:Play()
		else
			idlePulse:Cancel()
			TweenService:Create(holdScale, TweenInfo.new(0.06), { Scale = if look == "Held" then 0.94 else 1 }):Play()
		end
		TweenService:Create(holdBlock.Face, TweenInfo.new(0.1), {
			BackgroundTransparency = if look == "Rolling" then 0.3 else 0,
		}):Play()
	end

	local hintThrows = 0 -- throws this session
	local lastAction = os.clock()
	local hintWanted = ""
	local hintShown = true
	local function colourHint(text: string): string
		if text == READY_HINT then
			text = text:gsub("GOLD", '<font color="#FFC93A">GOLD</font>')
				:gsub("RED", '<font color="#FF2D4A">RED</font>')
		end
		return text
	end
	local function showHint(on: boolean)
		if on == hintShown then
			return
		end
		hintShown = on
		local alpha = if on then 0 else 1
		TweenService:Create(hint, TweenInfo.new(0.4), { TextTransparency = alpha }):Play()
		TweenService:Create(hintStroke, TweenInfo.new(0.4), { Transparency = alpha }):Play()
	end
	local function setHint(text: string)
		if text ~= hintWanted then
			hintWanted = text
			hint.Text = colourHint(text)
		end
		local early = hintThrows < 3 or assisted()
		showHint(early or os.clock() - lastAction >= 20)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			if hintWanted ~= "" then
				setHint(hintWanted)
			end
		end
	end)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local throwRequest = remotes:WaitForChild("ThrowRequest")
	local throwHold = remotes:WaitForChild("ThrowHold")
	local throwResult = remotes:WaitForChild("ThrowResult")

	-- The old straight bars are replaced by the half-circle arc; the old result label only holds the new pieces
	powerBar.Visible = false
	bar.Visible = false
	resultText.Text = ""
	resultText.Visible = true
	if resultStroke then
		resultStroke.Transparency = 1
	end
	local hookColor = (Balls.GetTrait("Curve") or {}).Color or C.Hook

	-- Holder (scaled to the screen) > arc (pops on release) > the ring layers, head, labels and readout plate
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
		SlUi.Corner(object)
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
	local function dot(value: number, diameter: number, color: Color3, z: number): Frame
		local cap = Instance.new("Frame")
		cap.AnchorPoint = Vector2.new(0.5, 0.5)
		cap.Position = arcPoint(value, ARC_RADIUS)
		cap.Size = UDim2.fromOffset(diameter, diameter)
		cap.BackgroundColor3 = color
		cap.BorderSizePixel = 0
		cap.ZIndex = z
		round(cap)
		cap.Parent = arc
		return cap
	end

	-- Layers, back to front: glow (zones only), outline, navy ring, zone band, fill
	local segments = {}
	for i = 1, ARC_SEGMENTS do
		local value = (i - 0.5) / ARC_SEGMENTS
		local glow = makeSegment(value, ARC_OUTLINE + 18, C.Gold, 1)
		glow.BackgroundTransparency = 1
		local fill = makeSegment(value, ARC_FILL, C.Cyan, 6)
		fill.Visible = false
		segments[i] = {
			Value = value,
			Glow = glow,
			Outline = makeSegment(value, ARC_OUTLINE, OUTLINE_IDLE, 2),
			Zone = (function()
				makeSegment(value, ARC_NAVY, C.Navy, 3)
				return makeSegment(value, ARC_TRACK, C.Track, 4)
			end)(),
			Fill = fill,
			-- the charging fill runs deep blue at the bottom to pale cyan at the top
			Flow = if value < 0.55
				then C.CyanDeep:Lerp(FLOW_MID, value / 0.55)
				else FLOW_MID:Lerp(C.CyanPale, (value - 0.55) / 0.45),
			Key = "",
		}
	end
	-- Rounded ends
	local outlineCaps = {}
	for _, value in { 0, 1 } do
		table.insert(outlineCaps, dot(value, ARC_OUTLINE, OUTLINE_IDLE, 2))
		dot(value, ARC_NAVY, C.Navy, 3)
	end
	local bottomCap = dot(0, ARC_TRACK, C.Track, 4)
	local topCap = dot(1, ARC_TRACK, if OVER.Enabled then C.Red else C.Track, 4)
	local fillCap = dot(0, ARC_FILL, C.Cyan, 6)
	fillCap.Visible = false
	-- Notches at 25 / 50 / 75 so the fill level reads at a glance, and one where the red cap starts
	local function notch(value: number, length: number, width: number)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BorderSizePixel = 0
		line.BackgroundColor3 = C.Navy
		line.Size = UDim2.fromOffset(width, length)
		local position, rotation = arcPoint(value, ARC_RADIUS)
		line.Position, line.Rotation = position, rotation
		line.ZIndex = 7
		line.Parent = arc
	end
	for _, value in { 0.25, 0.5, 0.75 } do
		notch(value, ARC_TRACK + 14, 4)
	end
	local redStart = 1
	for _, segment in segments do
		if ThrowRules.InOvercharge(segment.Value) then
			redStart = math.min(redStart, segment.Value - 0.5 / ARC_SEGMENTS)
		end
	end
	if OVER.Enabled and redStart < 1 then
		notch(redStart, ARC_TRACK + 2, 3)
	end

	-- The head: a white dot with a coloured ring and a soft glow; a gold ring bursts out of it in the PERFECT zone
	local headGlow = Instance.new("Frame")
	headGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	headGlow.Size = UDim2.fromOffset(ARC_HEAD * 2, ARC_HEAD * 2)
	headGlow.BackgroundTransparency = 0.5
	headGlow.ZIndex = 8
	round(headGlow)
	headGlow.Parent = arc
	local burst = Instance.new("Frame")
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.BackgroundTransparency = 1
	burst.ZIndex = 8
	round(burst)
	burst.Parent = arc
	local burstStroke = SlUi.Stroke(burst, Color3.fromRGB(255, 226, 122), 4, 0, true)
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.AnchorPoint = Vector2.new(0.5, 0.5)
	head.Size = UDim2.fromOffset(ARC_HEAD, ARC_HEAD)
	head.BackgroundColor3 = WHITE
	head.ZIndex = 9
	round(head)
	head.Parent = arc
	local headStroke = SlUi.Stroke(head, C.Cyan, 4, 0, true)

	-- Zone names beside the arc: PERFECT follows the gold, OVERCHARGE sits by the red cap
	local function zoneTag(text: string, size: number, color: Color3): TextLabel
		local label = SlUi.Label(arc, text, SlUi.Heavy, size, color)
		label.AnchorPoint = if IS_SIDE then Vector2.new(0, 0.5) else Vector2.new(0.5, 1)
		label.Size = UDim2.fromOffset(0, size + 4)
		label.AutomaticSize = Enum.AutomaticSize.X
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.ZIndex = 10
		SlUi.Stroke(label, C.Ink, 2.5)
		return label
	end
	local perfectTag = zoneTag("PERFECT", 20, C.Gold)
	local overTag = zoneTag("OVERCHARGE", 16, C.Red)
	overTag.Position = arcPoint(0.97, ARC_RADIUS + ARC_OUTLINE / 2 + 6)
	overTag.Visible = OVER.Enabled
	local tagRadius = ARC_RADIUS + ARC_OUTLINE / 2 + 8

	-- MAX badge at the top of a full bar (only when there is no red cap up there)
	local maxBadge = SlUi.Label(arc, "MAX", SlUi.Heavy, 22, C.GoldBright)
	maxBadge.AnchorPoint = Vector2.new(0.5, 1)
	maxBadge.Position = arcPoint(1, ARC_RADIUS + ARC_OUTLINE / 2 + 22)
	maxBadge.Size = UDim2.fromOffset(74, 32)
	maxBadge.BackgroundColor3 = C.Navy
	maxBadge.BackgroundTransparency = 0
	maxBadge.ZIndex = 10
	maxBadge.Visible = false
	SlUi.Corner(maxBadge, UDim.new(0, 10))
	SlUi.Stroke(maxBadge, C.GoldBright, 4, 0, true)

	-- The value you let go at, popped beside the head for a moment ("94")
	local releaseValue = SlUi.Label(arc, "", SlUi.Heavy, 40, WHITE)
	releaseValue.AnchorPoint = if IS_SIDE then Vector2.new(0, 0.5) else Vector2.new(0.5, 1)
	releaseValue.Size = UDim2.fromOffset(0, 44)
	releaseValue.AutomaticSize = Enum.AutomaticSize.X
	releaseValue.ZIndex = 11
	releaseValue.Visible = false
	local releaseValueStroke = SlUi.Stroke(releaseValue, C.Navy, 5)

	-- The readout plate under the arc: a small caption over a big word ("POWER" / "52%")
	local plate = Instance.new("Frame")
	plate.Name = "Readout"
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = if IS_SIDE then UDim2.new(0, ARC_RADIUS * 0.45, 1, 12) else UDim2.new(0.5, 0, 1, 12)
	plate.Size = UDim2.fromOffset(0, 56)
	plate.AutomaticSize = Enum.AutomaticSize.X
	plate.BackgroundColor3 = SlUi.Hex("05060F")
	plate.ZIndex = 10
	plate.Parent = holder
	SlUi.Corner(plate, UDim.new(0, 16))
	local plateStroke = SlUi.Stroke(plate, C.Grey, 3, 0, true)
	local platePad = Instance.new("UIPadding")
	platePad.PaddingLeft = UDim.new(0, 20)
	platePad.PaddingRight = UDim.new(0, 20)
	platePad.Parent = plate
	local plateList = Instance.new("UIListLayout")
	plateList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	plateList.VerticalAlignment = Enum.VerticalAlignment.Center
	plateList.SortOrder = Enum.SortOrder.LayoutOrder
	plateList.Parent = plate
	local caption = SlUi.Label(plate, "", SlUi.Mono, 12, C.Muted)
	caption.AnchorPoint = Vector2.zero
	caption.Size = UDim2.fromOffset(0, 14)
	caption.AutomaticSize = Enum.AutomaticSize.X
	caption.LayoutOrder = 1
	caption.ZIndex = 11
	local readout = SlUi.Label(plate, "", SlUi.Heavy, 30, C.Grey)
	readout.AnchorPoint = Vector2.zero
	readout.Size = UDim2.fromOffset(0, 34)
	readout.AutomaticSize = Enum.AutomaticSize.X
	readout.LayoutOrder = 2
	readout.ZIndex = 11
	SlUi.Stroke(readout, SlUi.Hex("05060F"), 2)
	local function setPlate(top: string, word: string, color: Color3)
		caption.Text = top
		readout.Text = word
		readout.TextColor3 = color
		plateStroke.Color = color
	end

	-- Red glow around the screen edges while the bar is in the overcharge cap
	local vignette = Instance.new("Frame")
	vignette.Name = "OverchargeVignette"
	vignette.Size = UDim2.new(1, 0, 1, 80)
	vignette.Position = UDim2.fromOffset(0, -60)
	vignette.BackgroundTransparency = 1
	vignette.Visible = false
	vignette.ZIndex = 0
	vignette.Parent = gui
	local vignetteEdges = {}
	for _, edge in { { 0, 1, 0 }, { 0, 1, 180 }, { 1, 0, 90 }, { 1, 0, 270 } } do
		local side = Instance.new("Frame")
		side.BorderSizePixel = 0
		side.BackgroundColor3 = C.Red
		side.ZIndex = 0
		local depth = 110
		local rotation = edge[3]
		side.Size = if rotation == 0 or rotation == 180 then UDim2.new(1, 0, 0, depth) else UDim2.new(0, depth, 1, 0)
		side.AnchorPoint = if rotation == 0
			then Vector2.new(0, 0)
			elseif rotation == 180 then Vector2.new(0, 1)
			elseif rotation == 90 then Vector2.new(0, 0)
			else Vector2.new(1, 0)
		side.Position = if rotation == 0
			then UDim2.fromScale(0, 0)
			elseif rotation == 180 then UDim2.fromScale(0, 1)
			elseif rotation == 90 then UDim2.fromScale(0, 0)
			else UDim2.fromScale(1, 0)
		local fade = Instance.new("UIGradient")
		fade.Rotation = if rotation == 0 then 90 elseif rotation == 180 then 270 elseif rotation == 90 then 0 else 180
		fade.Transparency = NumberSequence.new(0.3, 1)
		fade.Parent = side
		side.Parent = vignette
		table.insert(vignetteEdges, side)
	end

	-- Tier 2 PERFECT pops above the arc the moment you let go in the gold
	local perfectSpot = Instance.new("Frame")
	perfectSpot.Name = "Perfect"
	perfectSpot.AnchorPoint = Vector2.new(0.5, 1)
	perfectSpot.Size = UDim2.fromOffset(0, 0)
	perfectSpot.BackgroundTransparency = 1
	perfectSpot.ZIndex = 5
	perfectSpot.Parent = panel
	local perfectSpotScale = Instance.new("UIScale")
	perfectSpotScale.Parent = perfectSpot
	local perfectHost = ResultText.Host(perfectSpot, "PerfectHost", Vector2.new(560, 130))

	local function showPerfect(text: string, border: Color3?)
		local frame = ResultText.Clear(perfectHost)
		ResultText.Perfect(frame, text, THROW.ResultSizes.Perfect, border)
		ResultText.Pop(perfectHost, 0.6)
	end

	-- After each throw the gold glides to its new spot. It only glides while you can't throw,
	-- so what you see while charging is always exactly what the server checks.
	-- mode: "Idle", "Charge", "Gold", "Red", "Full" or "Released" (the white flash)
	local shownCenter: number? = nil
	local glowSegments = {}
	local function drawBar(value: number, mode: string, charging: boolean, dt: number?)
		local center, size = sweetSpot()
		if dt and shownCenter and not charging then
			shownCenter += (center - shownCenter) * math.min(1, dt * 8)
		else
			shownCenter = center
		end
		local shown = shownCenter :: number
		local hook = ThrowRules.HookWidth(equippedBall(), size)
		local now = os.clock()
		local fillColor = if mode == "Gold"
			then C.Gold
			elseif mode == "Red" then C.Red
			elseif mode == "Released" then WHITE
			else nil -- the cyan flow
		local outlineColor = if mode == "Idle"
			then OUTLINE_IDLE
			elseif mode == "Full" then C.GoldBright
			elseif mode == "Released" then WHITE
			else C.Cyan
		table.clear(glowSegments)
		for _, segment in segments do
			local offset = math.abs(segment.Value - shown)
			local zone = if offset <= size / 2
				then "Gold"
				elseif hook > 0 and offset <= size / 2 + hook then "Hook"
				elseif ThrowRules.InOvercharge(segment.Value) then "Red"
				else ""
			local filled = value > 0.005 and segment.Value <= value
			local key = zone .. (if filled then "F" else "") .. mode
			if key ~= segment.Key then
				segment.Key = key
				segment.Zone.BackgroundColor3 = if zone == "Gold"
					then C.Gold
					elseif zone == "Hook" then C.Track:Lerp(hookColor, 0.55)
					elseif zone == "Red" then C.Red
					else C.Track
				segment.Fill.Visible = filled
				segment.Fill.BackgroundColor3 = fillColor or segment.Flow
				segment.Outline.BackgroundColor3 = outlineColor
				segment.Glow.BackgroundColor3 = if mode == "Released"
					then WHITE
					elseif zone == "Red" then C.Red
					else C.Gold
			end
			if mode == "Released" or zone == "Gold" or zone == "Red" then
				table.insert(glowSegments, { segment.Glow, zone })
			else
				segment.Glow.BackgroundTransparency = 1
			end
		end
		-- Glows: the gold zone always glows softly and pulses hard while you're in it; the red cap the same.
		-- On release the whole arc flashes white.
		local goldAlpha = if mode == "Gold" then 0.775 + 0.225 * math.cos(now * math.pi * 2 / 0.6) else 0.35
		local redAlpha = if mode == "Red" then 0.675 + 0.325 * math.cos(now * math.pi * 2 / 0.45) else 0.15
		for _, pair in glowSegments do
			local alpha = if mode == "Released" then 0.3 elseif pair[2] == "Red" then redAlpha else goldAlpha
			pair[1].BackgroundTransparency = 1 - alpha * 0.55
		end
		local fullPulse = 0.775 + 0.225 * math.cos(now * math.pi * 2 / 0.28)
		for _, cap in outlineCaps do
			cap.BackgroundColor3 = outlineColor
		end
		if mode == "Full" then
			for _, segment in segments do
				segment.Outline.BackgroundTransparency = 1 - fullPulse
			end
		elseif segments[1].Outline.BackgroundTransparency ~= 0 then
			for _, segment in segments do
				segment.Outline.BackgroundTransparency = 0
			end
		end
		bottomCap.BackgroundColor3 = C.Track
		topCap.BackgroundColor3 = if OVER.Enabled then C.Red else C.Track
		fillCap.Visible = value > 0.005
		fillCap.BackgroundColor3 = fillColor or segments[1].Flow

		-- The head, its glow and the gold burst ring
		local clamped = math.clamp(value, 0, 1)
		local headColor = if mode == "Gold" or mode == "Full" then C.Gold elseif mode == "Red" then C.Red else C.Cyan
		head.Visible = value > 0.005 and mode ~= "Released"
		head.Position = arcPoint(clamped, ARC_RADIUS)
		headStroke.Color = headColor
		headGlow.Visible = head.Visible
		headGlow.Position = head.Position
		headGlow.BackgroundColor3 = headColor
		burst.Visible = mode == "Gold"
		if burst.Visible then
			local t = (now % 0.7) / 0.7
			local diameter = 24 + 56 * t
			burst.Position = head.Position
			burst.Size = UDim2.fromOffset(diameter, diameter)
			burstStroke.Transparency = t
		end

		-- kept clear of the OVERCHARGE name at the top
		perfectTag.Position = arcPoint(math.clamp(shown, 0.04, if OVER.Enabled then 0.84 else 0.96), tagRadius)
		perfectTag.Visible = size > 0 and not assisted()
		maxBadge.Visible = mode == "Full"
		vignette.Visible = mode == "Red"
		if vignette.Visible then
			for _, side in vignetteEdges do
				side.BackgroundTransparency = 0.45 - 0.35 * math.cos(now * math.pi * 2 / 0.45)
			end
		end

		-- The readout plate
		local pct = math.floor(clamped * 100 + 0.5) .. "%"
		local streak = player:GetAttribute("Streak") or 0
		if mode == "Gold" then
			setPlate("RELEASE NOW", "PERFECT!", C.Gold)
		elseif mode == "Red" then
			setPlate("RISKY", "OVERCHARGE", C.Red)
		elseif mode == "Full" then
			setPlate("POWER", "MAX", C.GoldBright)
		elseif mode == "Charge" then
			setPlate("POWER", pct, C.Cyan)
		elseif mode == "Released" then
			setPlate("POWER", math.floor(releasedValue * 100 + 0.5) .. "%", WHITE)
		elseif state == "Waiting" then
			setPlate("LAST THROW", math.floor(releasedValue * 100 + 0.5) .. "%", C.Grey)
		else
			setPlate(if streak > 0 then "GOLD SHRINKS x" .. streak else "HOLD TO CHARGE", "READY", C.Grey)
		end
	end

	-- What the meter shows while you charge
	local function chargeMode(value: number, inGold: boolean): string
		if inGold then
			return "Gold"
		elseif not assisted() and ThrowRules.InOvercharge(value) then
			return "Red"
		elseif not OVER.Enabled and value >= 0.995 then
			return "Full"
		end
		return "Charge"
	end

	-- After a release: white for 140 ms, then the fill drains in 220 ms (and the value hangs by the arc)
	local function drawReleased(dt: number)
		local t = os.clock() - releasedAt
		if t < 0.14 then
			drawBar(releasedValue, "Released", false, dt)
		elseif t < 0.36 then
			local k = (t - 0.14) / 0.22
			drawBar(releasedValue * (1 - k) * (1 - k), "Charge", false, dt)
		else
			drawBar(0, "Idle", false, dt)
		end
		releaseValue.Visible = t < 0.75
		local fade = math.clamp((t - 0.5) / 0.25, 0, 1)
		releaseValue.TextTransparency = fade
		releaseValueStroke.Transparency = fade
	end

	local function setState(newState: string)
		state = newState
		panel.Visible = newState ~= "Hidden"
		if newState == "Hidden" then
			ThrowPose.Stop(player.Character)
			lockFeet(false)
		elseif newState == "Ready" then
			charge = 0
			setHint(readyHint())
			setButton(if CORE_ON then "THROW" else "HOLD!", "Ready")
			drawBar(0, "Idle", false)
			lockFeet(false)
		elseif newState == "Charging" then
			charge, holdStartedAt = 0, os.clock()
			wasInRed = false
			throwHold:FireServer() -- the server starts its own clock for this hold
			HudKit.Bowled()
			lastAction = os.clock()
			setHint("LET GO IN THE GOLD!")
			setButton("LET GO!", "Held")
			Sfx.Play("Charge", 0.9)
			lockFeet(true)
		elseif newState == "Waiting" then
			hintThrows += 1
			lastAction = os.clock()
			setHint("ROLLING...")
			setButton("ROLLING...", "Rolling")
		end
	end

	-- Back to ready; still holding from before = start charging straight away, no wasted time
	local function getReady()
		setState("Ready")
		if held and popupOpen(gui) then
			held = nil -- a press from before the popup opened doesn't count
		end
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
		releasedAt, releasedValue = os.clock(), charge
		releaseValue.Text = tostring(math.floor(charge * 100 + 0.5))
		releaseValue.Position = arcPoint(math.min(charge, 0.92), ARC_RADIUS + ARC_OUTLINE / 2 + 14)
		drawBar(charge, "Released", false)
		if gold then
			showPerfect("PERFECT!")
			UiFx.Flash(GOLD, 0.25, 0.2)
		elseif hooked then
			showPerfect("HOOK! PERFECT!", hookColor)
			UiFx.Flash(hookColor, 0.25, 0.2)
		elseif ThrowRules.InOvercharge(charge) and not assisted() then
			-- The gamble: the server says whether it pays off when the ball lands
			showPerfect("OVERCHARGE?", C.Red)
			UiFx.Flash(RED, 0.25, 0.2)
		end
		UiFx.Pop(arc, if perfect then 1.15 else 1.08, 0.25)
		sentAt = os.clock()
		setState("Waiting")
		-- The arm swings down first; the ball leaves the hand (and the server hears about it) at the bottom
		ThrowPose.Release(player.Character, ThrowRules.Style(player:GetAttribute("RankLevel")).Pose)
		-- Only how long you held; the server checks it against its own timing and waits out the down-swing
		throwRequest:FireServer(holdTime)
	end

	local function press(input: InputObject)
		if held or popupOpen(gui) or ThrowController.Blocked then
			return
		end
		held = input
		if CORE_ON then
			return -- (the core loop throws from RenderStepped while this is held)
		end
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

	-- The owner's result text (UI 1.3) lives in a host on the old ResultText label (it keeps its place on screen)
	local resultSpot = Instance.new("Frame")
	resultSpot.Name = "ResultSpot"
	resultSpot.AnchorPoint = Vector2.new(0.5, 0.5)
	resultSpot.Position = UDim2.fromScale(0.5, 0.5)
	resultSpot.Size = UDim2.fromOffset(0, 0)
	resultSpot.BackgroundTransparency = 1
	resultSpot.Parent = resultText
	local resultScreenScale = Instance.new("UIScale")
	resultScreenScale.Parent = resultSpot
	local resultHost = ResultText.Host(resultSpot, "ResultHost", Vector2.new(960, 380))
	local SIZES = THROW.ResultSizes

	-- kind: "Strike", "Overcharge", "Overcooked" or "Pins"
	local function showText(kind: string, text: string, isStrike: boolean, grow: number?, count: number?, note: string?)
		local frame = ResultText.Clear(resultHost)
		if kind == "Strike" or kind == "Overcharge" then
			-- capped so long streak names still fit
			local size = math.min(SIZES.Strike * (grow or 1), 840 / (#text * 0.74 + 1))
			ResultText.Strike(frame, text, size, if kind == "Overcharge" then "Red" else "Pink")
		elseif kind == "Overcooked" then
			ResultText.Overcooked(frame, text, SIZES.Overcooked, note)
		else
			ResultText.Pins(frame, count or 0, SIZES.Pins, note)
		end
		ResultText.Pop(resultHost, if isStrike then THROW.CelebrationTime else 0.55)
	end

	-- "STRIKE!", a Config.Streaks tier name when you reach that tier, otherwise "6 IN A ROW!"
	local function streakName(streak: number): string
		if streak <= 1 then
			return "STRIKE!"
		end
		for _, tier in Config.Streaks do
			if tier.Streak == streak and tier.Name ~= "" then
				return tier.Name .. "!"
			end
		end
		return streak .. " IN A ROW!"
	end

	local function showResult(data)
		local previous = lastStreak
		local streak = data.Streak or 0
		lastStreak = streak
		local isStrike = data.Tier == "Strike" or data.Tier == "PerfectStrike"
		if data.Overcharge == "Wasted" then
			Sfx.Play("Overcooked")
			showText("Overcooked", "OVERCOOKED", false, nil, nil, if previous >= 2 then "STREAK OVER" else "GUTTER")
		elseif data.Overcharge == "Blast" then
			local name = if streak >= 2 then "OVERCHARGE x" .. streak .. "!" else "OVERCHARGE!"
			showText("Overcharge", name, true, 1.15)
		elseif isStrike then
			local level = math.min(math.max(streak, 1), THROW.StreakGrowthStopsAt)
			local grow = 1 + THROW.StreakGrowth * (level - 1)
			if table.find(THROW.SpecialStreaks, streak) then
				grow *= 1.3
			end
			showText("Strike", streakName(streak), true, math.min(grow, THROW.StreakGrowCap)) -- capped so it always fits on screen
		elseif streak > 0 then
			-- Streak Saver kept the streak alive: just the pin count
			showText("Pins", "", false, nil, data.Count)
		elseif previous >= 2 then
			showText("Pins", "", false, nil, data.Count, "STREAK OVER")
		else
			showText("Pins", "", false, nil, data.Count, if data.Count == 9 then "SO CLOSE!" else nil)
		end
	end

	throwResult.OnClientEvent:Connect(function(data)
		if data.UserId == player.UserId and not data.Core then
			-- Strikes show the moment the ball hits; other results a beat later
			local isStrike = data.Tier == "Strike" or data.Tier == "PerfectStrike"
			task.delay(data.RollTime + (if isStrike then 0 else 0.25), showResult, data)
		end
	end)

	-- ===== Addendum 4 core loop: hold to keep throwing =====
	-- While the button is held on your lane, one CoreThrow goes to the server every time the lane is ready (the server
	-- checks the cooldown itself). The camera glides down to watch your pins and back when you let go.
	local coreThrowRemote = remotes:WaitForChild("CoreThrow") :: RemoteEvent
	local coreSentAt = 0
	local coreLastThrow = 0
	if CORE_ON then
		holder.Visible = false
		perfectSpot.Visible = false
	end
	local function coreStep(dt: number)
		if state == "Hidden" then
			setState("Ready")
		end
		local lane = currentLane :: Model
		if held and (popupOpen(gui) or ThrowController.Blocked) then
			held = nil -- a popup opened: the press doesn't count any more
		end
		if held then
			if state ~= "Throwing" then
				state = "Throwing"
				setButton("THROWING", "Held")
				setHint("KEEP HOLDING!")
				lockFeet(true)
				HudKit.Bowled()
			end
			faceLane(dt)
			local cooldown = player:GetAttribute("ThrowCooldown") or CORE.Cooldown
			if laneReady(lane) and os.clock() - coreSentAt >= cooldown - 0.05 then
				coreSentAt = os.clock()
				coreLastThrow = coreSentAt
				hintThrows += 1
				lastAction = coreSentAt
				coreThrowRemote:FireServer()
				-- (Addendum 5 A1: the pose follows your ball step; levels are gone. A hero shot holds the pose it caught.)
				if not HeroShot.Playing() then
					ThrowPose.Release(player.Character, CoreLadder.Pose(player:GetAttribute("BallStep")))
				end
			end
		elseif state == "Throwing" then
			setState("Ready")
		end
	end

	-- The throw camera: from behind your bowler to a spot just in front of your pins (and back)
	local camera = Workspace.CurrentCamera
	local camBlend = 0 -- 0 = the normal camera, 1 = the throw camera
	local camLane: Model? = nil
	local camHeld = false
	if CORE_ON then
		RunService.RenderStepped:Connect(function(dt)
			local want = currentLane ~= nil and (state == "Throwing" or os.clock() - coreLastThrow < 0.8)
			if want then
				camLane = currentLane
			end
			camBlend = math.clamp(camBlend + (if want then dt else -dt) / CORE.CameraBlend, 0, 1)
			HeroShot.Watching = currentLane ~= nil and state == "Throwing"
			-- Big moments: a short low-camera shot takes over (Modules/HeroShot)
			local heroView, heroFov = HeroShot.Camera(dt)
			if heroView then
				camHeld = true
				camera.CameraType = Enum.CameraType.Scriptable
				camera.CFrame = heroView * CameraShake.Offset(dt) * ThrowFx.CameraOffset(dt)
				camera.FieldOfView = heroFov :: number
				return
			end
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local lane = camLane
			if camBlend <= 0 or not root or not lane then
				if camHeld then
					camHeld = false
					camera.CameraType = Enum.CameraType.Custom
				end
				return
			end
			camHeld = true
			camera.CameraType = Enum.CameraType.Scriptable
			local forward = (lane:FindFirstChild("BallStart") :: BasePart).CFrame.LookVector
			local head = (lane:FindFirstChild("PinSpot") :: BasePart).Position - forward * CORE.Rack.HeadPinForward
			local eye = head - forward * CORE.CameraBack + Vector3.yAxis * CORE.CameraHeight
			local laneCam = CFrame.lookAt(eye, head + forward * CORE.CameraLook)
			local home = CFrame.lookAt(
				(root.CFrame * CFrame.new(0, 4, 11)).Position,
				root.Position + root.CFrame.LookVector * 20
			)
			local t = camBlend * camBlend * (3 - 2 * camBlend)
			camera.CFrame = home:Lerp(laneCam, t) * CameraShake.Offset(dt) * ThrowFx.CameraOffset(dt)
		end)
	end

	RunService.RenderStepped:Connect(function(dt)
		-- Smaller arc on short screens (phones held sideways)
		local screenScale = math.clamp(Workspace.CurrentCamera.ViewportSize.Y / 720, 0.6, 1)
		holderScale.Scale = screenScale
		local drop = if phoneLayout then PHONE_DROP else 0
		local side = METER_SIDE * screenScale - (if phoneLayout then PHONE_LEFT else 0)
		holder.Position = UDim2.new(0.5, side, 0, -ARC_LIFT * screenScale + drop)
		perfectSpot.Position = UDim2.new(0.5, side, 0, -(METER_HEIGHT + ARC_LIFT + 70) * screenScale + drop)
		perfectSpotScale.Scale = screenScale
		resultScreenScale.Scale = screenScale

		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local ownLane = LaneUtil.GetOwnedLane(player.UserId)
		currentLane = if root and ownLane and LaneUtil.IsInThrowZone(ownLane, root.Position) then ownLane else nil
		if root and player:GetAttribute("BossSpot") then
			currentLane = bossSpot(root :: BasePart)
		end

		if not currentLane then
			if state ~= "Hidden" then
				setState("Hidden")
			end
			return
		end

		if CORE_ON then
			coreStep(dt)
		elseif state == "Hidden" then
			getReady()
		elseif popupOpen(gui) and (state == "Ready" or state == "Charging") then
			-- A popup opened: no throw until it's closed (a charge in progress is called off, nothing is sent)
			held = nil
			if state == "Charging" then
				ThrowPose.Stop(player.Character)
				setState("Ready")
			end
			drawBar(0, "Idle", false, dt)
			setHint("WAIT...")
		elseif state == "Ready" then
			if held and laneReady(currentLane) then
				setState("Charging") -- pressed while the lane was still busy
			else
				drawBar(0, "Idle", false, dt) -- the gold zone glides to its new spot (and slides with Moving Gold)
				setHint(if laneReady(currentLane) then readyHint() else "WAIT...")
			end
		elseif state == "Charging" then
			-- Fills, then slides back down and up again while you keep holding; the arm swings with it
			charge = chargeNow()
			local center, size = sweetSpot()
			local hook = ThrowRules.HookWidth(equippedBall(), size)
			local inGold = ThrowRules.InSpot(charge, center, size, hook)
			drawBar(charge, chargeMode(charge, inGold), true)
			-- A warning buzz each time the bar climbs into the red cap
			local inRed = not inGold and not assisted() and ThrowRules.InOvercharge(charge)
			if inRed and not wasInRed then
				Sfx.Play("OverchargeWarn")
			end
			wasInRed = inRed
			-- The throw animation follows your current rank level (batch D1), not Power Level
			ThrowPose.Charge(player.Character, charge, ThrowRules.Style(player:GetAttribute("RankLevel")).Pose)
			faceLane(dt)
		elseif state == "Waiting" then
			drawReleased(dt)
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
