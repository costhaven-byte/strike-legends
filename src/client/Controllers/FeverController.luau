-- FEVER MODE looks (final changes batch D4, Config.Fever; the server side is FeverService). While a player's
-- FeverEndsAt (server time) is ahead:
--   you:       a FEVER! slam banner when it starts (MomentKit, the owner's kit look), a draining bar over the power
--              meter ("FEVER x3" + seconds left; blinks in its last seconds, bumps when a strike adds time) and a
--              soft warm glow on the screen edges that breathes slowly. (The music speeds up: MusicController.)
--   everyone:  soft flame wisps on that bowler's lane light strips (the ball burns too: LaneVisuals).
-- SETTINGS: EFFECTS off = no edge glow and no flames (banner and bar stay); OTHER PLAYERS' EFFECTS off = no flames on
-- other bowlers' lanes; SCREEN SHAKE off = no kick when it starts (CameraShake checks that itself).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local CameraShake = require(Modules.CameraShake)
local HudKit = require(Modules.HudKit)
local LaneFx = require(Modules.LaneFx)
local MomentKit = require(Modules.MomentKit)
local Settings = require(Modules.Settings)
local Sfx = require(Modules.Sfx)
local UiKit = require(Modules.UiKit)

local FEVER = Config.Fever
local player = Players.LocalPlayer
local make = UiKit.Make
local tween = UiKit.Tween

local FeverController = {}

local function secondsLeft(who: Player): number
	return math.max(0, (who:GetAttribute("FeverEndsAt") or 0) - Workspace:GetServerTimeNow())
end

local function active(who: Player): boolean
	return FEVER.Enabled and secondsLeft(who) > 0
end

-- ===== Screen-edge glow: four edge strips fading inward, on a layer under the HUD =====
local function buildGlow(): (Frame, { Frame })
	local gui = MomentKit.Layer("FeverGlowUI", 0)
	local root = make("Frame", {
		Name = "Glow",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, gui)
	local strips = {}
	-- name, size, position, anchor, gradient rotation (0 = fades left to right)
	local edges = {
		{ "Top", UDim2.fromScale(1, FEVER.EdgeGlowSize), UDim2.fromScale(0, 0), Vector2.zero, 90 },
		{ "Bottom", UDim2.fromScale(1, FEVER.EdgeGlowSize), UDim2.fromScale(0, 1), Vector2.new(0, 1), -90 },
		{ "Left", UDim2.fromScale(FEVER.EdgeGlowSize * 0.6, 1), UDim2.fromScale(0, 0), Vector2.zero, 0 },
		{ "Right", UDim2.fromScale(FEVER.EdgeGlowSize * 0.6, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180 },
	}
	for _, edge in edges do
		local strip = make("Frame", {
			Name = edge[1],
			BackgroundColor3 = FEVER.Color,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = edge[2],
			Position = edge[3],
			AnchorPoint = edge[4],
		}, root)
		make("UIGradient", {
			Rotation = edge[5],
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.45, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, strip)
		table.insert(strips, strip)
	end
	return root, strips
end

-- ===== The draining bar over the power meter: navy pill, orange fill, flame icon, FEVER x3, seconds =====
type Bar = { Holder: Frame, Fill: Frame, Seconds: TextLabel, Scale: UIScale }

local function buildBar(meter: Frame): Bar
	local W, H = 210, 30
	local holder = make("Frame", {
		Name = "FeverBar",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -12),
		Size = UDim2.fromOffset(W, H),
		Visible = false,
		ZIndex = 10,
	}, meter)
	local scale = UiKit.ScaleOf(holder)
	local track = make("Frame", {
		Name = "Track",
		BackgroundColor3 = HudKit.C.Panel,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
	}, holder)
	HudKit.Corner(track, H / 2)
	HudKit.Outline(track, HudKit.C.Ink, 3)
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = FEVER.Color,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 11,
	}, track)
	HudKit.Corner(fill, H / 2)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(FEVER.Color:Lerp(Color3.fromRGB(255, 214, 90), 0.45), FEVER.Color),
	}, fill)
	local title = HudKit.Text(track, "FEVER x" .. FEVER.CoinMultiplier, HudKit.Head, 18, HudKit.C.White, 2)
	title.ZIndex = 13
	title.Position = UDim2.fromOffset(4, 1)
	local seconds = HudKit.Text(track, "", HudKit.Num, 15, HudKit.C.White, 2)
	seconds.ZIndex = 13
	seconds.TextXAlignment = Enum.TextXAlignment.Right
	seconds.Size = UDim2.new(1, -12, 1, 0)
	local icon = HudKit.Image(holder, "Flame", 38)
	icon.ZIndex = 14
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.new(0, 2, 0.5, -2)
	return { Holder = holder, Fill = fill, Seconds = seconds, Scale = scale }
end

-- ===== Flames on every fevering bowler's lane =====
local flaming: { [Model]: boolean } = {}

local function updateLaneFlames()
	local want: { [Model]: boolean } = {}
	if Settings.Get("Vfx") then
		for _, other in Players:GetPlayers() do
			if active(other) and (other == player or Settings.Get("OthersVfx")) then
				local lane = LaneUtil.GetOwnedLane(other.UserId)
				if lane then
					want[lane] = true
				end
			end
		end
	end
	for lane in flaming do
		if not want[lane] then
			flaming[lane] = nil
			LaneFx.SetFever(lane, false)
		end
	end
	for lane in want do
		if not flaming[lane] then
			flaming[lane] = true
			LaneFx.SetFever(lane, true)
		end
	end
end

function FeverController:Start()
	if not FEVER.Enabled then
		return
	end
	local glowRoot, strips = buildGlow()
	local banner = MomentKit.Banner(MomentKit.Layer("FeverMomentUI", 44), 0.3)
	local bar: Bar? = nil
	task.spawn(function()
		local throwUi = player:WaitForChild("PlayerGui"):WaitForChild("ThrowUI")
		local meter = throwUi:WaitForChild("Panel"):WaitForChild("PowerArc", 60)
		if meter then
			bar = buildBar(meter :: Frame)
		end
	end)

	local glow = 0 -- 0..1, fades in when fever starts and out when it ends
	local clock = 0
	local wasActive = active(player)
	local lastLeft = secondsLeft(player)

	player:GetAttributeChangedSignal("FeverEndsAt"):Connect(function()
		local left = secondsLeft(player)
		if left > 0 and not wasActive then
			-- FEVER! starts
			banner("FEVER!", "Fever", ("x%d COINS · FASTER THROWS"):format(FEVER.CoinMultiplier), "Hud:Flame", 2)
			Sfx.Play("PowerUp", 1.15, 0.9)
			Sfx.Play("Cheer", 1.05, 0.7)
			CameraShake.Add(0.35)
			if bar then
				bar.Scale.Scale = 0.2
				tween(bar.Scale, 0.35, Enum.EasingStyle.Back, { Scale = 1 })
			end
		elseif left > lastLeft + 0.2 and bar then
			-- a strike added time: the bar bumps
			bar.Scale.Scale = 1.15
			tween(bar.Scale, 0.25, Enum.EasingStyle.Back, { Scale = 1 })
		end
		wasActive = left > 0
		lastLeft = left
	end)

	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		local left = secondsLeft(player)
		local on = FEVER.Enabled and left > 0
		if wasActive and not on then
			wasActive = false -- ran out (no attribute change happens then)
		end
		lastLeft = left

		-- Bar
		if bar then
			bar.Holder.Visible = on
			if on then
				bar.Fill.Size = UDim2.fromScale(math.clamp(left / FEVER.Seconds, 0.12, 1), 1)
				bar.Seconds.Text = ("%ds"):format(math.ceil(left))
				local blink = left <= FEVER.EndWarning and math.sin(clock * 14) > 0
				bar.Fill.BackgroundTransparency = if blink then 0.55 else 0
			end
		end

		-- Edge glow (EFFECTS switch): fades in over ~0.5 s, breathes slowly, fades out at the end
		local target = if on and Settings.Get("Vfx") then 1 else 0
		glow += (target - glow) * math.min(1, dt * 3)
		if glow < 0.01 and target == 0 then
			glowRoot.Visible = false
		else
			glowRoot.Visible = true
			local breathe = (math.sin(clock * 2.4) + 1) / 2
			local strongest = FEVER.EdgeGlow + (FEVER.EdgeGlowPulse - FEVER.EdgeGlow) * breathe
			local transparency = 1 - (1 - strongest) * glow
			for _, strip in strips do
				strip.BackgroundTransparency = transparency
			end
		end
	end)

	task.spawn(function()
		while true do
			updateLaneFlames()
			task.wait(0.25)
		end
	end)
end

return FeverController
