-- The Pin Titan boss event on screen (Config.Boss; the server runs it all in BossService):
--   Zone 4 lobby: the countdown (sign over the helipad + a pill on screen), the siren 30 s before boarding, the
--   BOARD prompt on the helipad while boarding is open.
--   The fight: health bar, team meter, phase name and timer at the top, balls flying from each spot to the Titan,
--   damage numbers, plates breaking, the GIANT BALL call, then the results screen.
-- The throw itself is the normal one (ThrowController treats your arena spot like a lane).
-- Looks: UI pass batch 6 (2026-10-29), Claude's design in the owner's kits (UI Kit, Crate Kit, HUD Kit): the lobby
-- pill with the BOARD NOW! state, the fight plate (chunky health bar, 6 armour pips that break, timer chip), the
-- DODGE! / CORE OPEN! slams, the TITAN DOWN! / THE TITAN WON results window and the boss toasts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Currency = require(Shared.Modules.Currency)
local Mascots = require(Shared.Modules.Mascots)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local BallView = require(Modules.BallView)
local CrateKit = require(Modules.CrateKit)
local HudKit = require(Modules.HudKit)
local MascotView = require(Modules.MascotView)
local MomentKit = require(Modules.MomentKit)
local RewardKit = require(Modules.RewardKit)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local UiKit = require(Modules.UiKit)
local CrateController = require(script.Parent.CrateController)

local BOSS = Config.Boss
local C = HudKit.C
local player = Players.LocalPlayer

local PHASE_NAMES = {
	Intro = "GET READY!",
	Armor = "ARMOR",
	Core = "CORE EXPOSED",
	Finale = "FINALE",
	Giant = "GIANT BALLS!",
	Defeated = "DEFEATED!",
	Escaped = "ESCAPED!",
}
local PHASE_CALLS = { -- the big text when a phase starts
	Intro = { "PIN TITAN!", "DODGE THE RED - STRIKES BREAK ITS ARMOR", C.Red },
	Core = { "CORE OPEN!", "HIT IT! PERFECTS DO BIG DAMAGE", C.Gold },
	Finale = { "FINALE!", "FILL THE TEAM METER", C.Cyan },
	Giant = { "GIANT BALLS!", "THROW YOURS TO FINISH IT", C.Pink },
	Defeated = { "PIN TITAN DEFEATED!", "", C.Lime },
	Escaped = { "THE TITAN ESCAPED!", "OUT OF TIME", C.Red },
}
local HIT_COLORS = {
	Normal = C.White,
	Perfect = C.Gold,
	Blast = C.Red,
	Giant = C.Pink,
}

local BossController = {}

local function find(path: { string }): Instance?
	local node: Instance? = Workspace
	for _, name in path do
		node = node and node:FindFirstChild(name)
	end
	return node
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function new(className: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(className)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local K = UiKit.C

-- The next event's opening time on the EverySeconds clock (BossService nextSlot: the same on every server)
local function nextSlot(): number
	local every = BOSS.EverySeconds
	return math.ceil((Workspace:GetServerTimeNow() + 1) / every) * every
end

-- A chunky kit bar: dark slot with an ink outline, a coloured fill with its own darker lip and a shine strip, a
-- light "drain" ghost that catches up a moment after a hit, and the number in the middle. set(k) moves it (0..1).
local function kitBar(
	parent: Instance,
	name: string,
	color: Color3,
	lip: Color3,
	w: number,
	h: number
): (GuiObject, (number) -> (), TextLabel)
	local slot = UiKit.Block(parent, {
		Name = name,
		Size = Vector2.new(w, h),
		Fill = K.Slot,
		Lip = K.Ink,
		LipPx = 0,
		Radius = math.floor(h / 2.6),
		Outline = 3,
	})
	local inner = new("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		ClipsDescendants = true,
	}, slot.Face)
	UiKit.Corner(inner, math.floor(h / 2.6) - 5)
	local ghost = new("Frame", {
		Name = "Ghost",
		BackgroundColor3 = Color3.fromRGB(255, 236, 214),
		Size = UDim2.fromScale(1, 1),
	}, inner)
	UiKit.Corner(ghost, math.floor(h / 2.6) - 5)
	local fill = new("Frame", { Name = "Fill", BackgroundColor3 = lip, Size = UDim2.fromScale(1, 1) }, inner)
	UiKit.Corner(fill, math.floor(h / 2.6) - 5)
	local top = new("Frame", {
		Name = "Top",
		BackgroundColor3 = color,
		Size = UDim2.new(1, 0, 1, -math.max(4, math.floor(h * 0.18))),
	}, fill)
	UiKit.Corner(top, math.floor(h / 2.6) - 5)
	new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.7,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, math.max(3, math.floor(h * 0.16))),
	}, top)
	local label = UiKit.Text(slot.Face, "", UiKit.Num, h - 12, C.White, 2.5)
	label.ZIndex = 3
	local shown = 1
	local token = 0
	local function set(k: number)
		k = math.clamp(k, 0, 1)
		if math.abs(k - shown) < 1e-4 then
			return
		end
		fill.Visible = k > 0
		fill.Size = UDim2.fromScale(math.max(k, 0.001), 1)
		if k > shown then
			ghost.Size = fill.Size -- filling up: no ghost
		else
			token += 1
			local mine = token
			task.delay(0.3, function()
				if token == mine then
					UiKit.Tween(ghost, 0.35, Enum.EasingStyle.Quad, { Size = UDim2.fromScale(k, 1) })
				end
			end)
		end
		shown = k
	end
	return slot.Holder, set, label
end


function BossController:Start()
	if not BOSS.Enabled then
		return
	end
	local state = ReplicatedStorage:WaitForChild("BossEvent")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local eventRemote = remotes:WaitForChild("BossEvent") :: RemoteEvent
	local boardRemote = remotes:WaitForChild("BoardHelicopter") :: RemoteFunction

	local gui = new("ScreenGui", {
		Name = "BossUI",
		ResetOnSpawn = false,
		DisplayOrder = 7,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local screenScale = new("UIScale", {}, gui)

	-- ===== Lobby: the kit pill under the level bar (Titan pin on a disc; gold BOARD NOW! while boarding) =====
	local PILL_W, PILL_H = 480, 56
	local pill = new("Frame", {
		Name = "LobbyPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 20), -- just under the level bar, above the "+XP" line
		Size = UDim2.fromOffset(PILL_W, PILL_H),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	local pillBlock = UiKit.Block(pill, {
		Name = "Pill",
		Size = UDim2.fromScale(1, 1),
		Fill = K.Cover,
		Lip = K.Ink,
		LipPx = 5,
		Radius = 28,
		Outline = 3,
		Ring = C.Pink,
	})
	local pillRing = (pillBlock.Face:FindFirstChild("Ring") :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke
	local pillDisc = UiKit.Block(pill, {
		Name = "Disc",
		Size = Vector2.new(66, 66),
		Fill = K.Cover,
		Lip = K.Ink,
		LipPx = 4,
		Radius = 33,
		Outline = 3,
		Ring = C.Pink,
	})
	pillDisc.Holder.Position = UDim2.fromOffset(-20, -5)
	local discRing = (pillDisc.Face:FindFirstChild("Ring") :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke
	HudKit.Image(pillDisc.Face, "Pin", 40, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	local pillText = UiKit.Text(pillBlock.Face, "", UiKit.Head, 24, C.White, 2.5)
	pillText.Position = UDim2.fromOffset(52, 3)
	pillText.Size = UDim2.new(1, -64, 1, 0)
	RewardKit.Fit(pillText, 24, PILL_W - 80, PILL_H - 14)
	local pillMode = ""
	local stopPillPulse: (() -> ())? = nil
	-- mode: "Wait", "Siren", "Board", "OnBoard", "Busy"
	local function paintPill(mode: string, flashOn: boolean)
		local face, lip, ring = K.Cover, K.Ink, C.Pink
		if mode == "Siren" then
			face, lip, ring = if flashOn then C.Red else K.Cover, if flashOn then C.RedLip else K.Ink, C.Red
		elseif mode == "Board" then
			face, lip, ring = C.Gold, C.GoldLip, C.White
		elseif mode == "OnBoard" then
			face, lip, ring = C.Lime, C.LimeLip, C.White
		elseif mode == "Busy" then
			ring = C.Grey
		end
		pillBlock:Paint(face, lip)
		pillRing.Color = ring
		discRing.Color = if mode == "Busy" then C.Grey elseif mode == "Wait" then C.Pink else ring
		if mode ~= pillMode then
			pillMode = mode
			if stopPillPulse then
				stopPillPulse()
				stopPillPulse = nil
			end
			if mode == "Board" then
				stopPillPulse = RewardKit.Pulse(pill, 1.06, 0.45)
			end
		end
	end

	-- ===== The fight plate at the top (takes the level bar's place) =====
	local TOP_W, PLATE_H = 560, 134
	local FACE_W = TOP_W - 8 -- inside the 4 px outline
	local top = new("Frame", {
		Name = "FightHud",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -40), -- where the level bar is (hidden during the fight)
		Size = UDim2.fromOffset(TOP_W, PLATE_H + 44),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	local plate = UiKit.Block(top, {
		Name = "Plate",
		Size = Vector2.new(TOP_W, PLATE_H),
		Fill = K.Cover,
		Lip = K.Ink,
		LipPx = 6,
		Radius = 22,
		Outline = 4,
		Ring = C.Red,
	})
	local plateFace = plate.Face
	local titleBox = new("Frame", {
		Name = "TitleBox",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 6),
		Size = UDim2.fromOffset(210, 42),
	}, plateFace)
	local titleLabel = CrateKit.Title(titleBox, "PIN TITAN", 34, C.White, 3, 3)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	local phaseChip = UiKit.Block(plateFace, {
		Name = "Phase",
		Size = Vector2.new(190, 36),
		Fill = K.Chip,
		Lip = K.Ink,
		LipPx = 4,
		Radius = 18,
		Outline = 3,
	})
	phaseChip.Holder.Position = UDim2.fromOffset(226, 9)
	local phaseLabel = UiKit.Text(phaseChip.Face, "", UiKit.Head, 19, C.Gold, 2)
	phaseLabel.Position = UDim2.fromOffset(6, 2)
	phaseLabel.Size = UDim2.new(1, -12, 1, 0)
	RewardKit.Fit(phaseLabel, 19, 170, 28)
	local timerChip = UiKit.Block(plateFace, {
		Name = "Timer",
		Size = Vector2.new(112, 42),
		Fill = K.Card,
		Lip = K.Ink,
		LipPx = 4,
		Radius = 14,
		Outline = 3,
	})
	timerChip.Holder.Position = UDim2.fromOffset(FACE_W - 112 - 10, 6)
	local timerLabel = UiKit.Text(timerChip.Face, "", UiKit.Num, 28, C.White, 2.5)
	local stopTimerPulse: (() -> ())? = nil
	local healthHolder, setHealth, healthText = kitBar(plateFace, "Health", C.Red, C.RedLip, FACE_W - 24, 42)
	healthHolder.Position = UDim2.fromOffset(12, 54)
	-- 6 armour pips: steel shields that pop and go dark as plates break
	local pips = {}
	local pipRow = new("Frame", {
		Name = "Pips",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 95),
		Size = UDim2.fromOffset(BOSS.Plates * 38, 24),
	}, plateFace)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, pipRow)
	for i = 1, BOSS.Plates do
		local pip = UiKit.Block(pipRow, {
			Name = "Pip" .. i,
			Size = Vector2.new(32, 22),
			Fill = Color3.fromRGB(170, 178, 205),
			Lip = Color3.fromRGB(94, 100, 136),
			LipPx = 4,
			Radius = 7,
			Outline = 2,
		})
		pip.Holder.LayoutOrder = i
		local rivet = new("Frame", {
			Name = "Rivet",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			BackgroundColor3 = Color3.fromRGB(235, 240, 255),
		}, pip.Face)
		UiKit.Corner(rivet, 3)
		local crack = new("Frame", {
			Name = "Crack",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(26, 3),
			Rotation = -35,
			BackgroundColor3 = C.Red,
			Visible = false,
		}, pip.Face)
		table.insert(pips, { Block = pip, Rivet = rivet, Crack = crack, Broken = false })
	end
	local function setPips(left: number)
		for i, pip in pips do
			local broken = i > left
			if broken ~= pip.Broken then
				pip.Broken = broken
				if broken then
					pip.Block:Paint(K.Slot, K.Ink)
					pip.Rivet.Visible = false
					pip.Crack.Visible = true
					local scale = UiKit.ScaleOf(pip.Block.Holder)
					scale.Scale = 1.6
					UiKit.Tween(scale, 0.25, Enum.EasingStyle.Back, { Scale = 1 })
				else
					pip.Block:Paint(Color3.fromRGB(170, 178, 205), Color3.fromRGB(94, 100, 136))
					pip.Rivet.Visible = true
					pip.Crack.Visible = false
				end
			end
		end
	end
	local damageLabel = UiKit.Text(plateFace, "", UiKit.Head, 17, C.White, 2)
	damageLabel.TextXAlignment = Enum.TextXAlignment.Right
	damageLabel.Position = UDim2.fromOffset(BOSS.Plates * 38 + 20, 95)
	damageLabel.Size = UDim2.fromOffset(FACE_W - BOSS.Plates * 38 - 34, 24)
	RewardKit.Fit(damageLabel, 17, FACE_W - BOSS.Plates * 38 - 40, 24)
	-- Team meter (finale): its own cyan bar hanging under the plate
	local meterBack, setMeter, meterText = kitBar(top, "Meter", C.Cyan, C.CyanLip, 420, 36)
	meterBack.Position = UDim2.fromOffset((TOP_W - 420) / 2, PLATE_H + 4)

	-- The big calls (phase starts, OUCH, ON BOARD) are the kit slam banner; DODGE! is a quick red slam. Both live on
	-- their own layer (BossUI has a phone UIScale; the kit pieces fit the screen themselves).
	local moments = MomentKit.Layer("BossMoments", 8)
	local banner = MomentKit.Banner(moments, 0.36)
	local toast = RewardKit.Toast(gui)
	local PAINT_BY_COLOR = { -- by colour hex
		[C.Red:ToHex()] = "Red",
		[C.Gold:ToHex()] = "Gold",
		[C.Lime:ToHex()] = "Lime",
		[C.Cyan:ToHex()] = "Cyan",
		[C.Pink:ToHex()] = "Pink",
	}
	local function showCall(big: string, small: string, color: Color3, seconds: number?)
		if big == "" then
			toast(small, nil, nil, color, seconds)
			return
		end
		banner(big, PAINT_BY_COLOR[color:ToHex()] or "Grey", if small ~= "" then small else nil, nil, seconds or 2.4)
	end

	local dodge = new("Frame", {
		Name = "Dodge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3), -- under the fight plate
		Size = UDim2.fromOffset(340, 96),
		BackgroundTransparency = 1,
		Visible = false,
	}, moments)
	local dodgeFit = new("UIScale", {}, dodge)
	local dodgePop = new("Frame", { Name = "Pop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, dodge)
	local dodgeBlock = UiKit.Block(dodgePop, {
		Name = "Ribbon",
		Size = UDim2.fromScale(1, 1),
		Fill = C.Red,
		Lip = C.RedLip,
		LipPx = 8,
		Radius = 26,
		Outline = 5,
	})
	local dodgeTitle = CrateKit.Title(dodgeBlock.Face, "DODGE!", 64, C.White, 4, 5)
	new("UIPadding", { PaddingTop = UDim.new(0, 8) }, dodgeTitle)
	local dodgeToken = 0
	local function slamDodge(seconds: number)
		dodgeToken += 1
		local mine = dodgeToken
		local area = moments.AbsoluteSize
		dodgeFit.Scale = if area.X > 0 then math.max(0.45, math.min(1, area.X / 1920 * 1.25, area.Y / 1080 * 1.25)) else 1
		dodge.Visible = true
		local scale = UiKit.ScaleOf(dodgePop)
		scale.Scale = 2.2
		dodgePop.Rotation = -8
		UiKit.Tween(scale, 0.22, Enum.EasingStyle.Back, { Scale = 1 })
		UiKit.Tween(dodgePop, 0.22, Enum.EasingStyle.Back, { Rotation = 0 })
		Sfx.Play("OverchargeWarn", 1.1, 0.7)
		-- a little shake while it's up
		task.spawn(function()
			local began = os.clock()
			while dodgeToken == mine and os.clock() - began < seconds do
				dodgePop.Position = UDim2.fromOffset(math.random(-4, 4), math.random(-3, 3))
				task.wait(0.04)
			end
			dodgePop.Position = UDim2.new()
			if dodgeToken == mine then
				UiKit.Tween(scale, 0.15, Enum.EasingStyle.Back, { Scale = 0 }, Enum.EasingDirection.In).Completed:Wait()
				if dodgeToken == mine then
					dodge.Visible = false
				end
			end
		end)
	end
	-- Am I standing where this attack lands?
	local function myRoot(): BasePart?
		return player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	end
	local function flat(v: Vector3): Vector3
		return Vector3.new(v.X, 0, v.Z)
	end
	local function inDanger(data): boolean
		local root = myRoot()
		if not root or not player:GetAttribute("BossFighting") then
			return false
		end
		local at = flat(root.Position)
		if data.Kind == "Pins" then
			for _, spot in data.Spots do
				if (at - flat(spot)).Magnitude <= data.Radius + 6 then
					return true
				end
			end
		elseif data.Kind == "Roll" then
			local a, b = flat(data.From), flat(data.To)
			local ab = b - a
			local t = if ab.Magnitude > 0 then math.clamp((at - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
			return (at - (a + ab * t)).Magnitude <= data.Width / 2 + 6
		end
		return false
	end

	local giantBanner = new("Frame", {
		Name = "Giant",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150), -- just above the hint line, under the power arc
		Size = UDim2.fromOffset(500, 62),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	local giantBlock = UiKit.Block(giantBanner, {
		Name = "Ribbon",
		Size = UDim2.fromScale(1, 1),
		Fill = C.Pink,
		Lip = C.PinkLip,
		LipPx = 6,
		Radius = 24,
		Outline = 4,
	})
	local giantText = UiKit.Text(giantBlock.Face, "GIANT BALL READY! HOLD + LET GO!", UiKit.Head, 26, C.White, 3)
	giantText.Position = UDim2.fromOffset(12, 3)
	giantText.Size = UDim2.new(1, -24, 1, 0)
	RewardKit.Fit(giantText, 26, 470, 46)
	local stopGiantPulse: (() -> ())? = nil

	-- Black fade for the helicopter flights
	local fade = new("Frame", {
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Visible = false,
	}, gui)
	local fadeText = HudKit.Text(fade, "", HudKit.Head, 40, C.White, 3)
	fadeText.ZIndex = 51
	fadeText.TextTransparency = 1
	local function flight(text: string, seconds: number)
		fade.Visible = true
		fadeText.Text = text
		local rotor = Sfx.Play("Helicopter")
		local half = TweenInfo.new(seconds * 0.45)
		TweenService:Create(fade, half, { BackgroundTransparency = 0 }):Play()
		TweenService:Create(fadeText, half, { TextTransparency = 0 }):Play()
		task.delay(seconds + 0.4, function()
			Sfx.FadeOut(rotor, 0.8)
			local out = TweenInfo.new(0.6)
			TweenService:Create(fade, out, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(fadeText, out, { TextTransparency = 1 }):Play()
			task.delay(0.6, function()
				fade.Visible = false
			end)
		end)
	end

	HudKit.OnLayout(function(phone)
		screenScale.Scale = if phone then 0.7 else 1
		pill.Position = UDim2.new(0.5, 0, 0, if phone then 14 else 20)
	end)

	-- ===== The helicopter on the helipad: sign + hold-E BOARD prompt on its body =====
	local function padPart(): BasePart?
		local pad = find(BOSS.Helipad) or find({ "SkylineLanes", "Helipad" }) -- old code-built pad as a fallback
		if not pad then
			return nil
		end
		local heli = pad:FindFirstChild(BOSS.Helicopter) or pad:FindFirstChild("Helicopter")
		local body = heli and (heli:FindFirstChild("heli_body", true) or heli:FindFirstChild("Body", true))
		return (body or pad:FindFirstChild(BOSS.PadPart, true) or pad:FindFirstChild("Pad") or pad:FindFirstChildWhichIsA(
			"BasePart",
			true
		)) :: BasePart?
	end
	local sign: TextLabel? = nil
	local prompt: ProximityPrompt? = nil
	local function setUpPad()
		local part = padPart()
		if not part or sign then
			return
		end
		local board = new("BillboardGui", {
			Name = "BossSign",
			Size = UDim2.fromOffset(420, 90),
			StudsOffset = Vector3.new(0, 14, 0), -- above the rotor
			MaxDistance = 400,
			LightInfluence = 0,
		}, part)
		local label = HudKit.Text(board, "", HudKit.Head, 40, C.Gold, 3)
		label.TextScaled = true
		sign = label
		local p = new("ProximityPrompt", {
			ObjectText = "HELICOPTER",
			ActionText = "Board: fight the Pin Titan",
			HoldDuration = 0.5,
			MaxActivationDistance = 18, -- the helicopter is big: measured from the middle of its body
			RequiresLineOfSight = false,
			Enabled = false,
		}, part)
		p.Triggered:Connect(function()
			local ok, result = pcall(boardRemote.InvokeServer, boardRemote)
			if ok and result and result.Ok then
				Sfx.Play("Click")
				showCall("ON BOARD!", "STAY BY THE HELICOPTER", C.Lime, 1.8)
			else
				showCall("", if ok and result and result.Error then result.Error:upper() else "TRY AGAIN", C.White, 1.8)
			end
		end)
		prompt = p
	end

	-- ===== Balls flying at the Titan =====
	local function arena(): Instance?
		return find(BOSS.Arena)
	end
	local function target(): BasePart?
		local a = arena()
		local titan = a and a:FindFirstChild("Titan")
		return titan and (titan:FindFirstChild("Target") or titan:FindFirstChild("Core")) :: BasePart?
	end
	local function ballLook(ballId: string, size: number): BasePart | Model
		local ball = Balls.Get(ballId) or Config.Balls[1]
		local look = BallView.Model(ball)
		if look:IsA("Model") then
			local _, box = look:GetBoundingBox()
			local now = math.max(box.X, box.Y, box.Z)
			if now > 0 then
				look:ScaleTo(look:GetScale() * size / now)
			end
			for _, p in look:GetDescendants() do
				if p:IsA("BasePart") then
					p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
				end
			end
		else
			local part = look :: BasePart
			part.Size = Vector3.one * size
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		end
		return look :: any
	end

	local function fly(data)
		local a = arena()
		local spots = a and a:FindFirstChild("Spots")
		local spot = spots and spots:FindFirstChild(data.Spot)
		local start = spot and spot:FindFirstChild("BallStart") :: BasePart?
		local aim = target()
		if not (start or data.From) or not aim then
			return
		end
		local giant = data.Kind == "Giant"
		local size = if giant then 16 else 3
		local look = ballLook(data.BallId, size)
		local trailColor = HIT_COLORS[data.Kind] or C.White
		local glow = new("Part", {
			Name = "Glow",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * size * 1.25,
			Color = trailColor,
			Material = Enum.Material.Neon,
			Transparency = if data.Kind == "Normal" or data.Kind == "Wasted" then 1 else 0.6,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		look.Parent = Workspace
		glow.Parent = Workspace
		local from = data.From or (start :: BasePart).Position
		local to = aim.Position
		if data.Kind == "Wasted" then
			to = from + (to - from) * 0.45 - Vector3.new(0, 30, 0) -- overcooked: it drops off the platform
		end
		local mine = data.UserId == player.UserId
		Sfx.Play("Throw", if giant then 0.6 else 1, if mine then 1 else 0.4)
		local travel = data.Travel or BOSS.BallTravel
		local began = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = math.min(1, (os.clock() - began) / travel)
			local pos = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * (if giant then 30 else 14), 0)
			local cf = CFrame.new(pos) * CFrame.Angles(t * 20, 0, 0)
			if look:IsA("Model") then
				look:PivotTo(cf)
			else
				look.CFrame = cf
			end
			glow.CFrame = CFrame.new(pos)
			if t >= 1 then
				connection:Disconnect()
				look:Destroy()
				glow:Destroy()
			end
		end)
	end

	-- A damage number over the Titan
	local function damagePop(data)
		local aim = target()
		if not aim then
			return
		end
		local mine = data.UserId == player.UserId
		if data.Kind == "Wasted" then
			if mine then
				showCall("OVERCOOKED!", "STREAK OVER", C.Red, 1.2)
				Sfx.Play("Overcooked")
			end
			return
		end
		local spot = aim.Position + Vector3.new(math.random(-8, 8), math.random(-2, 10), math.random(-8, 8))
		local anchor = new("Part", {
			Size = Vector3.one,
			Transparency = 1,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CFrame = CFrame.new(spot),
		}, Workspace)
		local board = new("BillboardGui", {
			Size = UDim2.fromOffset(if mine then 220 else 140, if mine then 70 else 44),
			AlwaysOnTop = true,
			LightInfluence = 0,
			MaxDistance = 300,
		}, anchor)
		local word = if data.Kind == "Perfect"
			then "PERFECT "
			elseif data.Kind == "Blast" then "OVERCHARGE "
			elseif data.Kind == "Giant" then "GIANT "
			else ""
		local label = HudKit.Text(
			board,
			word .. "-" .. Currency.Format(data.Damage),
			HudKit.Head,
			if mine then 40 else 24,
			HIT_COLORS[data.Kind] or C.White,
			if mine then 3 else 2
		)
		label.TextScaled = true
		if not mine then
			label.TextTransparency = 0.25
		end
		TweenService:Create(
			anchor,
			TweenInfo.new(1.1, Enum.EasingStyle.Quad),
			{ CFrame = CFrame.new(spot + Vector3.new(0, 10, 0)) }
		):Play()
		TweenService
			:Create(label, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.7), {
				TextTransparency = 1,
			})
			:Play()
		task.delay(1.3, function()
			anchor:Destroy()
		end)
		Sfx.PlayAt("BossHit", aim, if data.Kind == "Giant" then 0.6 else 1, if mine then 1 else 0.5)
		if mine then
			if data.Kind == "Perfect" or data.Kind == "Blast" then
				Sfx.Play("PerfectSting", 1, 0.6)
				UiFx.Flash(HIT_COLORS[data.Kind], 0.2, 0.2)
			elseif data.Kind == "Giant" then
				Sfx.Play("StrikeCrash", 0.7)
				UiFx.Flash(C.Pink, 0.4, 0.4)
			end
		end
	end

	-- Plate debris
	local function plateBreak(position: Vector3)
		Sfx.Play("BossPlate", 1, 0.8)
		for _ = 1, 7 do
			local piece = new("Part", {
				Size = Vector3.new(math.random(2, 4), math.random(2, 4), 0.6),
				Color = Color3.fromRGB(110, 115, 135),
				Material = Enum.Material.DiamondPlate,
				Anchored = true,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
				CFrame = CFrame.new(position),
			}, Workspace)
			local away = Vector3.new(math.random() - 0.5, 0.2 + math.random() * 0.5, math.random() - 0.5).Unit * 25
			local spin = CFrame.Angles(math.random() * 6, math.random() * 6, 0)
			TweenService:Create(piece, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.new(position + away - Vector3.new(0, 18, 0)) * spin,
				Transparency = 1,
			}):Play()
			task.delay(1.3, function()
				piece:Destroy()
			end)
		end
	end

	-- ===== The Titan's attacks: red warnings on the floor, then pins or a giant ball =====
	local function plain(props: { [string]: any }): Part
		local p = new("Part", {
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
		})
		for key, value in props do
			(p :: any)[key] = value
		end
		p.Parent = Workspace
		return p
	end
	local DISC = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder part lying flat
	local WARN = C.Red

	-- A red circle whose inside fills up until the pin lands (so you can see how long you have)
	local function warningCircle(at: Vector3, radius: number, seconds: number)
		local ring = plain({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, radius * 2, radius * 2),
			CFrame = CFrame.new(at + Vector3.new(0, 0.12, 0)) * DISC,
			Color = WARN,
			Transparency = 0.7,
		})
		local fill = plain({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.2, 0.5, 0.5),
			CFrame = CFrame.new(at + Vector3.new(0, 0.16, 0)) * DISC,
			Color = WARN,
			Transparency = 0.5,
		})
		TweenService:Create(fill, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
			Size = Vector3.new(0.2, radius * 2, radius * 2),
		}):Play()
		task.delay(seconds, function()
			ring:Destroy()
			fill:Destroy()
		end)
	end

	-- The thrown pin: the owner's stone pin (ReplicatedStorage.BossModels.StonePin); a white pin with a red band if
	-- that is missing
	local function pinLook(): Model
		local models = ReplicatedStorage:FindFirstChild("BossModels")
		local design = models and models:FindFirstChild("StonePin")
		if design then
			local copy = design:Clone() :: Model
			copy.Parent = Workspace
			return copy
		end
		local model = Instance.new("Model")
		local body = plain({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(7, 3.4, 3.4),
			Color = Color3.fromRGB(245, 245, 250),
			Material = Enum.Material.SmoothPlastic,
		})
		body.Parent = model
		local band = plain({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.8, 3.6, 3.6),
			Color = C.Red,
			Material = Enum.Material.SmoothPlastic,
		})
		band.CFrame = body.CFrame * CFrame.new(1.6, 0, 0)
		band.Parent = model
		model.PrimaryPart = body
		model.Parent = Workspace
		return model
	end

	local function impact(at: Vector3, size: number)
		local burst = plain({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, size, size),
			CFrame = CFrame.new(at + Vector3.new(0, 0.3, 0)) * DISC,
			Color = Color3.fromRGB(255, 230, 200),
			Transparency = 0.2,
		})
		TweenService:Create(burst, TweenInfo.new(0.35), {
			Size = Vector3.new(0.3, size * 2, size * 2),
			Transparency = 1,
		}):Play()
		task.delay(0.4, function()
			burst:Destroy()
		end)
	end

	local function pinAttack(data)
		local left = math.max(0.2, data.ImpactAt - Workspace:GetServerTimeNow())
		local flightTime = math.min(0.7, left)
		Sfx.PlayAt("Throw", target() or Workspace, 0.5, 0.8)
		for _, spot in data.Spots do
			warningCircle(spot, data.Radius, left)
			-- the pin leaves the Titan so it lands exactly when the circle is full
			task.delay(left - flightTime, function()
				local pin = pinLook()
				local began = os.clock()
				local connection
				connection = RunService.RenderStepped:Connect(function()
					local t = math.min(1, (os.clock() - began) / flightTime)
					local pos = data.From:Lerp(spot, t) + Vector3.new(0, math.sin(t * math.pi) * 25, 0)
					pin:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 9, 0, t * 5))
					if t >= 1 then
						connection:Disconnect()
						pin:Destroy()
						impact(spot, data.Radius * 1.2)
						Sfx.PlayAt("BossPlate", target() or Workspace, 0.8, 0.6)
					end
				end)
			end)
		end
	end

	local function rollAttack(data)
		local from, to = data.From :: Vector3, data.To :: Vector3
		local length = (to - from).Magnitude
		local mid = from:Lerp(to, 0.5)
		local stripe = plain({
			Size = Vector3.new(data.Width, 0.15, length),
			CFrame = CFrame.lookAt(mid, to) + Vector3.new(0, 0.12, 0),
			Color = WARN,
			Transparency = 0.55,
		})
		local flash = TweenService:Create(
			stripe,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.2 }
		)
		flash:Play()
		local ball = plain({
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * data.Width,
			Color = Color3.fromRGB(60, 20, 40),
			Material = Enum.Material.SmoothPlastic,
			CFrame = CFrame.new(from + Vector3.new(0, data.Width / 2, 0)),
			Transparency = 1,
		})
		local glow = new("PointLight", { Color = C.Red, Range = 24, Brightness = 3, Enabled = false }, ball)
		local rolling = false
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local k = (Workspace:GetServerTimeNow() - data.StartsAt) / data.Duration
			if k < 0 then
				return
			end
			if not rolling then
				rolling = true
				ball.Transparency = 0
				glow.Enabled = true
				Sfx.PlayAt("Roll", ball, 0.6, 1)
			end
			local pos = from:Lerp(to, math.min(k, 1)) + Vector3.new(0, data.Width / 2, 0)
			ball.CFrame = CFrame.lookAt(pos, pos + (to - from)) * CFrame.Angles(-k * length / data.Width * 2, 0, 0)
			if k >= 1 then
				connection:Disconnect()
				flash:Cancel()
				stripe:Destroy()
				ball:Destroy()
			end
		end)
	end

	-- You got hit: shoved away, screen flash and shake, DAZED for a moment
	local function struck(data)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			local away = (root.Position - data.From) * Vector3.new(1, 0, 1)
			if away.Magnitude < 0.5 then
				away = -root.CFrame.LookVector
			end
			root.AssemblyLinearVelocity = away.Unit * data.Knockback + Vector3.new(0, 35, 0)
		end
		Sfx.Play("StreakLost", 0.8)
		UiFx.Flash(C.Red, 0.45, 0.4)
		showCall("OUCH!", "DAZED - STREAK LOST", C.Red, data.Seconds)
		local camera = Workspace.CurrentCamera
		local began = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local t = os.clock() - began
			if t > 0.35 then
				connection:Disconnect()
				return
			end
			local strength = (1 - t / 0.35) * 0.6
			camera.CFrame *= CFrame.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
		end)
	end

	-- ===== Results: kit window, TITAN DOWN! / THE TITAN WON =====
	local resultsGui = new("ScreenGui", {
		Name = "BossResultsUI",
		ResetOnSpawn = false,
		DisplayOrder = 9,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	local RW, RH = 620, 610
	local win = RewardKit.Window(resultsGui, RW, RH)
	local cover, closeX = RewardKit.Cover(win.Panel, RW, RH, "TITAN DOWN!", "THE PIN TITAN IS RUBBLE!", C.Lime)
	local coverTitle = (cover:FindFirstChild("TitleBox") :: Frame):FindFirstChild("Front", true) :: TextLabel
	local coverSub = cover:FindFirstChild("Sub") :: TextLabel
	-- Hero row: the coins on rays + the amount, tier chip and your rank
	local hero = new("Frame", {
		Name = "Hero",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(140, 168),
		Size = UDim2.fromOffset(140, 140),
	}, cover)
	local heroRays = RewardKit.Rays(hero, C.Gold, 250, 10)
	local heroIcon = RewardKit.Icon(hero, "Coins", nil, 120)
	local coinsLabel = RewardKit.Label(cover, "", UiKit.Head, 56, C.Gold, 4, 240, 102, 356, 66)
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	local function chip(parent: Instance, w: number, h: number, size: number)
		local block = UiKit.Block(parent, {
			Name = "Chip",
			Size = Vector2.new(w, h),
			Fill = K.Chip,
			Lip = K.Ink,
			LipPx = 4,
			Radius = math.floor(h / 2),
			Outline = 3,
		})
		local label = UiKit.Text(block.Face, "", UiKit.Head, size, C.White, 2)
		label.Position = UDim2.fromOffset(8, 2)
		label.Size = UDim2.new(1, -16, 1, 0)
		RewardKit.Fit(label, size, w - 22, h - 10)
		return block, label
	end
	local tierChip, tierText = chip(cover, 150, 42, 22)
	tierChip.Holder.Position = UDim2.fromOffset(240, 176)
	local rankChip, rankText = chip(cover, 206, 42, 20)
	rankChip.Holder.Position = UDim2.fromOffset(398, 176)
	-- Extras: crate, potions, NO HITS, TOP DAMAGE as small chips in a row
	local extras = new("Frame", {
		Name = "Extras",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 248),
		Size = UDim2.fromOffset(RW - 48, 50),
	}, cover)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, extras)
	local extrasScale = new("UIScale", {}, extras)
	local extrasWidth = 0
	local function extra(text: string, color: Color3, kind: string?, value: any?)
		local w = math.clamp(CrateKit.TextWidth(text, UiKit.Head, 18) + (if kind then 72 else 36), 120, RW - 48)
		local block, label = chip(extras, w, 46, 18)
		block.Holder.LayoutOrder = #extras:GetChildren()
		-- too many chips for one row: the whole row shrinks to fit
		extrasWidth += w + (if extrasWidth > 0 then 8 else 0)
		extrasScale.Scale = math.min(1, (RW - 48) / extrasWidth)
		label.Text = text
		label.TextColor3 = color
		if kind then
			label.Position = UDim2.fromOffset(46, 2)
			label.Size = UDim2.new(1, -54, 1, 0)
			RewardKit.Icon(block.Face, kind, value, 36, UDim2.fromOffset(24, 19))
		end
	end
	-- The drop line: a strip with the pet chance, the pet you got, or the next try after a loss
	local dropStrip = UiKit.Block(cover, {
		Name = "Drop",
		Size = Vector2.new(RW - 48, 52),
		Fill = K.Card,
		Lip = K.Ink,
		LipPx = 4,
		Radius = 18,
		Outline = 3,
	})
	dropStrip.Holder.Position = UDim2.fromOffset(24, 306)
	local dropSlot = new("Frame", {
		Name = "Pet",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, -12),
		Size = UDim2.fromOffset(62, 62),
		ZIndex = 4,
	}, dropStrip.Face)
	local dropText = UiKit.Text(dropStrip.Face, "", UiKit.Head, 20, K.Label, 2)
	RewardKit.Fit(dropText, 20, RW - 160, 40)
	-- Damage board: the top 5 (you take row 5 when you are further down)
	local board = UiKit.Block(cover, {
		Name = "Board",
		Size = Vector2.new(RW - 48, 162),
		Fill = K.Page,
		Lip = K.Ink,
		LipPx = 0,
		Radius = 16,
		Outline = 3,
	})
	board.Holder.Position = UDim2.fromOffset(24, 368)
	local boardList = new("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 1, -12),
	}, board.Face)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, boardList)
	local MEDALS = { C.Gold, Color3.fromRGB(210, 225, 245), Color3.fromRGB(230, 150, 90) }
	local ok = RewardKit.Button(cover, "AWESOME!", "Lime", 240, 62, 30)
	ok.Holder.Position = UDim2.fromOffset((RW - 240) / 2, RH - 62 - 16)

	local TIER_COLORS = {
		BRONZE = Color3.fromRGB(230, 150, 90),
		SILVER = Color3.fromRGB(210, 225, 245),
		GOLD = C.Gold,
		TITAN = C.Pink,
	}
	local pendingCrate = nil
	local stopTwinkle: (() -> ())? = nil
	local resultsToken = 0
	local function closeResults()
		win:Close()
	end
	ok.Activated:Connect(closeResults)
	closeX.Activated:Connect(closeResults)
	win.Closed.Event:Connect(function()
		resultsToken += 1
		if stopTwinkle then
			stopTwinkle()
			stopTwinkle = nil
		end
		local crate = pendingCrate
		pendingCrate = nil
		if crate and CrateController.PlayOpening then
			task.delay(0.3, CrateController.PlayOpening, crate[1], crate[2])
		end
	end)

	local function boardRow(row, order: number)
		local isMe = row.UserId == player.UserId
		local line = new("Frame", {
			Name = "Row",
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = K.Card,
			BackgroundTransparency = if isMe then 0 else 1,
			LayoutOrder = order,
		}, boardList)
		UiKit.Corner(line, 10)
		if isMe then
			UiKit.Outline(line, C.Gold, 2)
		end
		local disc = new("Frame", {
			Name = "Rank",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 4, 0.5, 0),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = MEDALS[row.Rank] or K.Chip,
		}, line)
		UiKit.Corner(disc, 12)
		UiKit.Outline(disc, K.Ink, 2)
		UiKit.Text(disc, tostring(row.Rank), UiKit.Num, 15, C.White, 1.5)
		local name = UiKit.Text(line, row.Name, UiKit.Head, 18, if isMe then C.Gold else C.White, 1.5)
		name.Position = UDim2.fromOffset(36, 2)
		name.Size = UDim2.new(0.5, -36, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local tier = UiKit.Text(line, row.Tier or "-", UiKit.Head, 17, TIER_COLORS[row.Tier] or C.Grey, 1.5)
		tier.Position = UDim2.new(0.5, 0, 0, 2)
		tier.Size = UDim2.fromScale(0.22, 1)
		local damage = UiKit.Text(line, Currency.Format(row.Damage), UiKit.Num, 18, C.White, 1.5)
		damage.AnchorPoint = Vector2.new(1, 0)
		damage.Position = UDim2.new(1, -8, 0, 0)
		damage.Size = UDim2.fromScale(0.28, 1)
		damage.TextXAlignment = Enum.TextXAlignment.Right
	end

	-- "TITAN JR. PET: 10% CHANCE, 25% FOR #1" from Config.Boss.Drop
	local function dropChanceText(): string
		local drop = BOSS.Drop
		if not drop then
			return ""
		end
		local name = drop.Id
		if drop.Kind == "Pet" then
			local mascot = Mascots.Get(drop.Id)
			name = (if mascot then mascot.Name else drop.Id) .. " PET"
		elseif drop.Kind == "Ball" then
			local ball = Balls.Get(drop.Id)
			name = if ball then ball.Name else drop.Id
		end
		local line = ("%s: %d%% CHANCE"):format(name:upper(), math.round(drop.Chance * 100))
		if drop.TopChance then
			line ..= (", %d%% FOR #1"):format(math.round(drop.TopChance * 100))
		end
		return line
	end

	local function showResults(data)
		resultsToken += 1
		local token = resultsToken
		local lost = data.Won == false
		local rewarded = data.Tier ~= nil
		coverTitle.Text = if lost then "THE TITAN WON" else "TITAN DOWN!"
		coverTitle.TextColor3 = if lost then C.Red else C.Lime
		coverSub.Text = if lost then "OUT OF TIME! IT GOT AWAY..." else "THE PIN TITAN IS RUBBLE!"
		-- hero: coins count up
		heroRays.ImageColor3 = if lost then C.Grey else C.Gold
		heroRays.Visible = rewarded
		RewardKit.Fill(heroIcon, "Coins", nil)
		local coins = data.Coins or 0
		if rewarded then
			coinsLabel.TextColor3 = C.Gold
			coinsLabel.Text = "+0 COINS"
			local counter = Instance.new("NumberValue")
			counter.Changed:Connect(function(v)
				if token == resultsToken then
					coinsLabel.Text = "+" .. Currency.Format(v) .. " COINS"
				end
			end)
			task.delay(0.35, function()
				UiKit.Tween(counter, 0.9, Enum.EasingStyle.Quad, { Value = coins }).Completed:Wait()
				counter:Destroy()
				if token == resultsToken then
					coinsLabel.Text = "+" .. Currency.Format(coins) .. " COINS"
				end
			end)
		else
			coinsLabel.Text = "NO REWARD"
			coinsLabel.TextColor3 = C.Grey
		end
		tierChip.Holder.Visible = rewarded
		tierText.Text = (data.Tier or "") .. " TIER"
		tierText.TextColor3 = TIER_COLORS[data.Tier] or C.White
		rankText.Text = ("YOU: #%d · %d HITS"):format(data.Rank or 0, data.Hits or 0)
		rankChip.Holder.Position = UDim2.fromOffset(if rewarded then 398 else 240, 176)
		-- extras
		for _, child in extras:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		extrasWidth = 0
		extrasScale.Scale = 1
		pendingCrate = nil
		if rewarded then
			local crate = Balls.GetCrate(data.CrateId)
			if crate then
				extra("+ " .. crate.Name:upper(), C.White, "Crate", crate.Id)
				pendingCrate = if data.Crate then { crate, data.Crate } else nil
			end
			for _, potion in data.Potions or {} do
				local row = RewardKit.PotionById(potion.Id)
				extra(
					("+%d %s"):format(potion.Count, (if row then row.Name else potion.Id):upper()),
					C.White,
					"Potion",
					potion.Id
				)
			end
			if data.TopBonus and data.TopBonus > 0 then
				extra("TOP DAMAGE BONUS!", C.Gold)
			end
			if (data.HitsTaken or 0) == 0 then
				extra("NO HITS TAKEN!", C.Lime)
			else
				extra(("GOT HIT %d TIMES"):format(data.HitsTaken), K.Label)
			end
		else
			extra("LAND A HIT TO EARN REWARDS NEXT TIME!", K.Label)
		end
		-- drop strip
		dropSlot:ClearAllChildren()
		dropText.Position = UDim2.fromOffset(16, 3)
		dropText.Size = UDim2.new(1, -32, 1, -4)
		dropText.TextColor3 = K.Label
		if lost then
			dropText.TextColor3 = C.Gold
			task.spawn(function()
				local at = nextSlot()
				while token == resultsToken do
					dropText.Text = "NEXT TRY IN " .. clock(at - Workspace:GetServerTimeNow())
					task.wait(0.5)
				end
			end)
		elseif data.Drop then
			dropText.Position = UDim2.fromOffset(76, 3)
			dropText.Size = UDim2.new(1, -92, 1, -4)
			dropText.Text = ("BOSS DROP: YOU GOT %s!"):format(data.Drop.Name:upper())
			dropText.TextColor3 = C.Pink
			local mascot = data.Drop.Kind == "Pet" and Mascots.Get(data.Drop.Id)
			local ball = data.Drop.Kind == "Ball" and Balls.Get(data.Drop.Id)
			if mascot then
				local view = MascotView.Viewport(dropSlot, MascotView.Mascot(mascot, 2, false), 0.95)
				view.ZIndex = 5
			elseif ball then
				local view = BallView.New(ball, { Spin = true })
				view.Size = UDim2.fromScale(1, 1)
				view.ZIndex = 5
				view.Parent = dropSlot
			else
				RewardKit.Icon(dropSlot, "Crate", data.Drop.Id, 56)
			end
			task.delay(0.7, RewardKit.Stamp, dropStrip.Holder)
		else
			dropText.Text = dropChanceText()
		end
		-- board
		for _, child in boardList:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local rows = data.Rows or {}
		for i = 1, math.min(5, #rows) do
			local row = rows[i]
			if i == 5 and (data.Rank or 0) > 5 and rows[data.Rank] then
				row = rows[data.Rank]
			end
			boardRow(row, i)
		end
		ok:SetText(if lost then "OK" else "AWESOME!")
		ok:Paint(if lost then C.Grey else C.Lime, if lost then C.GreyLip else C.LimeLip)
		win:Open()
		RewardKit.Stagger(
			{ hero, coinsLabel, tierChip.Holder, rankChip.Holder, dropStrip.Holder, board.Holder },
			0.06,
			0.15
		)
		if stopTwinkle then
			stopTwinkle()
			stopTwinkle = nil
		end
		if lost then
			Sfx.Play("StreakLost", 0.7)
		else
			stopTwinkle = RewardKit.Twinkle(hero, 5, C.Gold)
			CrateKit.Confetti(cover, 0, -60, 40, 300, 0.7)
			Sfx.Play("RevealBig")
		end
		if data.Drop then
			task.delay(0.9, function()
				showCall("BOSS DROP!", data.Drop.Name:upper(), C.Pink, 2.5)
			end)
		end
		task.delay(BOSS.ResultsSeconds - 1, function()
			if token == resultsToken then
				closeResults()
			end
		end)
	end

	eventRemote.OnClientEvent:Connect(function(kind: string, data)
		if kind == "Takeoff" then
			flight("TAKING OFF...", data.Seconds)
		elseif kind == "Return" then
			closeResults()
			flight("FLYING BACK...", data.Seconds)
			task.delay(data.Seconds + 1.5, function()
				toast("NEXT BOSS FLIGHT IN " .. clock(nextSlot() - Workspace:GetServerTimeNow()), nil, nil, C.Gold, 3.5)
			end)
		elseif kind == "Throw" then
			fly(data)
		elseif kind == "Hit" then
			damagePop(data)
		elseif kind == "Plate" then
			plateBreak(data.Position)
		elseif kind == "Results" then
			showResults(data)
		elseif kind == "Attack" then
			if inDanger(data) then
				slamDodge(math.clamp((data.ImpactAt or data.StartsAt or 0) - Workspace:GetServerTimeNow(), 0.6, 1.2))
			end
			if data.Kind == "Pins" then
				pinAttack(data)
			elseif data.Kind == "Roll" then
				rollAttack(data)
			end
		elseif kind == "Struck" then
			struck(data)
		end
	end)

	-- Phase calls
	local lastPhase = state:GetAttribute("Phase")
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = state:GetAttribute("Phase")
		if phase == lastPhase then
			return
		end
		lastPhase = phase
		if not player:GetAttribute("BossFighting") then
			return
		end
		local callRow = PHASE_CALLS[phase]
		if callRow then
			-- the intro waits for the fade back in
			task.delay(if phase == "Intro" then BOSS.FlightSeconds + 0.6 else 0, function()
				showCall(callRow[1], callRow[2], callRow[3], if phase == "Intro" then BOSS.IntroSeconds - 0.6 else 2.4)
			end)
			if phase ~= "Intro" then
				Sfx.Play("BossRoar")
			end
			if phase == "Defeated" then
				UiFx.Confetti(nil, 50)
			end
		end
	end)

	-- ===== Every frame-ish: lobby countdown, siren, HUD numbers =====
	local lastSiren = 0
	local lastToastMode = "Wait"
	local warnedAt = nil -- the FightEndsAt the 30-seconds-left call was shown for
	local function inLobby(): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and Zones.InArea(BOSS.LobbyArea, root.Position)
	end
	while true do
		setUpPad()
		local now = Workspace:GetServerTimeNow()
		local eventState = state:GetAttribute("State")
		local opensAt = state:GetAttribute("OpensAt") or 0
		local boardingEnds = state:GetAttribute("BoardingEndsAt") or 0
		local unlocked = Zones.Unlocked(player:GetAttribute("ZonesOpen"), BOSS.Zone)
		local fighting = player:GetAttribute("BossFighting") == true
		local boarded = player:GetAttribute("BossBoarded") == true

		-- What the lobby says (sign over the helipad + the pill)
		local text, color, mode = "", C.White, "Wait"
		if eventState == "Boarding" then
			if boarded then
				text, color, mode = "ON BOARD! TAKEOFF IN " .. clock(boardingEnds - now), C.Lime, "OnBoard"
			else
				text, color, mode = "BOARD NOW! HELIPAD " .. clock(boardingEnds - now), C.Gold, "Board"
			end
		elseif eventState == "Fight" or eventState == "Results" then
			text, color, mode = "PIN TITAN FIGHT IN PROGRESS", C.Grey, "Busy"
		else
			local left = opensAt - now
			if left <= BOSS.SirenSeconds then
				text, color, mode = "BOSS INCOMING! BOARDING IN " .. clock(left), C.Red, "Siren"
			else
				text, color = "PIN TITAN IN " .. clock(left), C.White
			end
		end
		if sign then
			sign.Text = if unlocked then text else "PIN TITAN: REACH " .. Zones.Name(BOSS.Zone):upper()
			sign.TextColor3 = if unlocked then color else C.Grey
		end
		if prompt then
			prompt.Enabled = unlocked and eventState == "Boarding" and not boarded and not fighting
		end
		local here = inLobby()
		local showPill = unlocked and not fighting and here
		pill.Visible = showPill
		if showPill then
			pillText.Text = text
			pillText.TextColor3 = if mode == "Busy" then C.Grey else C.White
			paintPill(mode, math.floor(now * 2) % 2 == 0)
			if mode == "Siren" and os.clock() - lastSiren >= 2 then
				-- siren every 2 seconds while the pill flashes
				lastSiren = os.clock()
				Sfx.Play("BossSiren")
				UiFx.Flash(C.Red, 0.15, 0.5)
			end
		end
		-- Boss toasts for players with the zone who are somewhere else: siren, then boarding
		if unlocked and not fighting and not here and mode ~= lastToastMode then
			if mode == "Siren" then
				toast("NEXT BOSS FLIGHT IN " .. clock(opensAt - now) .. "! GO TO THE SKYLINE HELIPAD", nil, nil, C.Red, 4)
			elseif mode == "Board" then
				toast("FLY TO THE BOSS! THE HELICOPTER IS BOARDING NOW", nil, nil, C.Gold, 4)
			end
		end
		lastToastMode = mode

		-- The fight plate (it takes the level bar's place at the top; the bar comes back after the fight)
		top.Visible = fighting
		local hud = player.PlayerGui:FindFirstChild("HUD")
		local rankBar = hud and hud:FindFirstChild("RankBar") :: GuiObject?
		if rankBar then
			rankBar.Visible = not fighting
		end
		if fighting then
			local phase = state:GetAttribute("Phase") or "Intro"
			local hp = state:GetAttribute("Health") or 0
			local maxHp = math.max(1, state:GetAttribute("MaxHealth") or 1)
			setHealth(hp / maxHp)
			healthText.Text = Currency.Format(hp) .. " / " .. Currency.Format(maxHp)
			local plates = if phase == "Intro" then BOSS.Plates else state:GetAttribute("Plates") or 0
			setPips(plates)
			phaseLabel.Text = if phase == "Armor" then ("ARMOR: %d LEFT"):format(plates) else PHASE_NAMES[phase] or ""
			phaseLabel.TextColor3 = if phase == "Core" then C.Gold elseif phase == "Giant" then C.Pink else C.Gold
			-- 30 seconds left before the Titan escapes
			local fightEnds = state:GetAttribute("FightEndsAt")
			if
				fightEnds
				and warnedAt ~= fightEnds
				and (phase == "Armor" or phase == "Core" or phase == "Finale")
				and fightEnds - now <= 30
			then
				warnedAt = fightEnds
				showCall("30 SECONDS LEFT!", "BEAT IT OR IT ESCAPES", C.Red, 2.4)
				Sfx.Play("BossSiren")
			end
			local showMeter = phase == "Finale" or phase == "Giant" or phase == "Defeated"
			meterBack.Visible = showMeter
			if showMeter then
				local goal = math.max(1, state:GetAttribute("MeterGoal") or 1)
				local fill = state:GetAttribute("Meter") or 0
				setMeter(fill / goal)
				meterText.Text = if fill >= goal
					then "TEAM METER FULL!"
					else ("TEAM METER %d%%"):format(fill / goal * 100)
			end
			local endsAt = if phase == "Giant"
				then state:GetAttribute("GiantEndsAt")
				else state:GetAttribute("FightEndsAt")
			timerLabel.Text = if endsAt and phase ~= "Defeated" then clock(endsAt - now) else "--"
			local urgent = endsAt ~= nil and phase ~= "Defeated" and endsAt - now <= 20
			timerLabel.TextColor3 = if urgent then C.Red else C.White
			if urgent and not stopTimerPulse then
				stopTimerPulse = RewardKit.Pulse(timerChip.Holder, 1.12, 0.25)
			elseif not urgent and stopTimerPulse then
				stopTimerPulse()
				stopTimerPulse = nil
			end
			local streak = player:GetAttribute("BossStreak") or 0
			local dazed = now < (player:GetAttribute("BossDazedUntil") or 0)
			damageLabel.Text = ("YOU: %s%s"):format(
				Currency.Format(player:GetAttribute("BossDamage") or 0),
				if dazed then "  ·  DAZED!" elseif streak >= 2 then ("  ·  PERFECT x%d"):format(streak) else ""
			)
			damageLabel.TextColor3 = if dazed then C.Red elseif streak >= 2 then C.Gold else C.White
		end
		local giant = fighting and player:GetAttribute("BossGiant") == true
		if giant ~= giantBanner.Visible then
			giantBanner.Visible = giant
			if giant then
				stopGiantPulse = RewardKit.Pulse(giantBanner, 1.07, 0.35)
			elseif stopGiantPulse then
				stopGiantPulse()
				stopGiantPulse = nil
			end
		end
		task.wait(0.1)
	end
end

return BossController
