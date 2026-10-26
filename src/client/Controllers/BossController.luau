-- The Pin Titan boss event on screen (Config.Boss; the server runs it all in BossService):
--   Zone 4 lobby: the countdown (sign over the helipad + a pill on screen), the siren 30 s before boarding, the
--   BOARD prompt on the helipad while boarding is open.
--   The fight: health bar, team meter, phase name and timer at the top, balls flying from each spot to the Titan,
--   damage numbers, plates breaking, the GIANT BALL call, then the results screen.
-- The throw itself is the normal one (ThrowController treats your arena spot like a lane).
-- PLACEHOLDER looks: Claude's own design until the owner's boss UI exists.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Currency = require(Shared.Modules.Currency)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local BallView = require(Modules.BallView)
local HudKit = require(Modules.HudKit)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
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
}
local PHASE_CALLS = { -- the big text when a phase starts
	Intro = { "PIN TITAN!", "BREAK ITS ARMOR WITH STRIKES", C.Red },
	Core = { "CORE EXPOSED!", "PERFECTS DO BIG DAMAGE", C.Gold },
	Finale = { "FINALE!", "FILL THE TEAM METER", C.Cyan },
	Giant = { "GIANT BALLS!", "THROW YOURS TO FINISH IT", C.Pink },
	Defeated = { "PIN TITAN DEFEATED!", "", C.Lime },
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

local function bar(parent: Instance, name: string, color: Color3, height: number): (Frame, Frame, TextLabel)
	local back = new("Frame", {
		Name = name,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.15,
	}, parent)
	HudKit.Corner(back, height / 2)
	HudKit.Outline(back, C.Ink, 3)
	local fill = new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
	}, back)
	HudKit.Corner(fill, height / 2)
	local label = HudKit.Text(back, "", HudKit.Num, height - 6, C.White, 2)
	return back, fill, label
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

	-- ===== Lobby: the pill on screen =====
	local pill = new("Frame", {
		Name = "LobbyPill",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 96),
		Size = UDim2.fromOffset(440, 40),
		BackgroundColor3 = C.Panel,
		BackgroundTransparency = 0.1,
		Visible = false,
	}, gui)
	HudKit.Corner(pill, 20)
	local pillStroke = HudKit.Outline(pill, C.Pink, 3)
	local pillText = HudKit.Text(pill, "", HudKit.Head, 22, C.White, 2)
	HudKit.Fit(pillText, 22)
	new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, pill)

	-- ===== The fight HUD at the top =====
	local top = new("Frame", {
		Name = "FightHud",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8), -- where the level bar is (hidden during the fight)
		Size = UDim2.fromOffset(480, 120), -- narrow enough to stay clear of the power arc on the right
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	local titleRow = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 }, top)
	local titleLabel = HudKit.Text(titleRow, "PIN TITAN", HudKit.Head, 26, C.White, 2.5)
	titleLabel.Size = UDim2.fromScale(0.5, 1)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	local phaseLabel = HudKit.Text(titleRow, "", HudKit.Head, 22, C.Gold, 2)
	phaseLabel.AnchorPoint = Vector2.new(0.5, 0)
	phaseLabel.Position = UDim2.fromScale(0.5, 0)
	phaseLabel.Size = UDim2.fromScale(0.5, 1)
	local timerLabel = HudKit.Text(titleRow, "", HudKit.Num, 26, C.White, 2.5)
	timerLabel.AnchorPoint = Vector2.new(1, 0)
	timerLabel.Position = UDim2.fromScale(1, 0)
	timerLabel.Size = UDim2.fromScale(0.25, 1)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Right
	local healthBack, healthFill, healthText = bar(top, "Health", C.Red, 28)
	healthBack.Position = UDim2.fromOffset(0, 34)
	local meterBack, meterFill, meterText = bar(top, "Meter", C.Cyan, 20)
	meterBack.Position = UDim2.fromOffset(0, 68)
	local damageLabel = HudKit.Text(top, "", HudKit.Body, 15, C.White, 1.5)
	damageLabel.Position = UDim2.fromOffset(0, 94)
	damageLabel.Size = UDim2.new(1, 0, 0, 20)

	-- The big text in the middle (phase calls, GIANT BALL READY)
	local call = new("Frame", {
		Name = "Call",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.32),
		Size = UDim2.fromOffset(800, 110),
		BackgroundTransparency = 1,
		Visible = false,
	}, gui)
	local callBig = HudKit.Text(call, "", HudKit.Head, 64, C.Red, 4)
	callBig.Size = UDim2.new(1, 0, 0, 72)
	local callSmall = HudKit.Text(call, "", HudKit.Head, 26, C.White, 2.5)
	callSmall.Position = UDim2.fromOffset(0, 74)
	callSmall.Size = UDim2.new(1, 0, 0, 32)
	local callToken = 0
	local function showCall(big: string, small: string, color: Color3, seconds: number?)
		callToken += 1
		local token = callToken
		callBig.Text, callSmall.Text, callBig.TextColor3 = big, small, color
		call.Visible = true
		UiFx.Pop(call, 1.4, 0.3)
		task.delay(seconds or 2.4, function()
			if callToken == token then
				call.Visible = false
			end
		end)
	end

	local giantBanner = new("Frame", {
		Name = "Giant",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150), -- just above the hint line, under the power arc
		Size = UDim2.fromOffset(460, 46),
		BackgroundColor3 = C.Pink,
		Visible = false,
	}, gui)
	HudKit.Corner(giantBanner, 23)
	HudKit.Outline(giantBanner, C.Ink, 3)
	HudKit.Text(giantBanner, "GIANT BALL READY! HOLD + LET GO!", HudKit.Head, 24, C.White, 2.5)

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
		Sfx.Play("Helicopter")
		local half = TweenInfo.new(seconds * 0.45)
		TweenService:Create(fade, half, { BackgroundTransparency = 0 }):Play()
		TweenService:Create(fadeText, half, { TextTransparency = 0 }):Play()
		task.delay(seconds + 0.4, function()
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
		pill.Position = UDim2.new(0.5, 0, 0, if phone then 64 else 96)
	end)

	-- ===== The helipad: sign + BOARD prompt =====
	local function padPart(): BasePart?
		local pad = find(BOSS.Helipad)
		return pad and (pad:FindFirstChild("Pad") or pad:FindFirstChildWhichIsA("BasePart", true)) :: BasePart?
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
			StudsOffset = Vector3.new(0, 22, 0),
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
			MaxActivationDistance = 14,
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
		if not start or not aim then
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
		local from = start.Position
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

	-- ===== Results =====
	local results = new("Frame", {
		Name = "Results",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(560, 470),
		BackgroundColor3 = C.Panel,
		Visible = false,
		ZIndex = 20,
	}, gui)
	HudKit.Corner(results, 22)
	HudKit.Outline(results, C.Pink, 4)
	local resultsTitle = HudKit.Text(results, "PIN TITAN DEFEATED!", HudKit.Head, 38, C.Lime, 3)
	resultsTitle.Size = UDim2.new(1, 0, 0, 56)
	resultsTitle.ZIndex = 21
	local list = new("ScrollingFrame", {
		Position = UDim2.fromOffset(24, 60),
		Size = UDim2.new(1, -48, 0, 200),
		BackgroundColor3 = C.Card,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
	}, results)
	HudKit.Corner(list, 12)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 6),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
	}, list)
	local mineBox = new("Frame", {
		Position = UDim2.fromOffset(24, 270),
		Size = UDim2.new(1, -48, 0, 130),
		BackgroundTransparency = 1,
		ZIndex = 21,
	}, results)
	local mineText = HudKit.Text(mineBox, "", HudKit.Head, 22, C.White, 2)
	mineText.RichText = true
	mineText.TextWrapped = true
	mineText.TextYAlignment = Enum.TextYAlignment.Top
	mineText.ZIndex = 22
	local close = HudKit.Block(results, { Name = "Close", Button = true, Paint = "Lime", Radius = 14, Lip = 5 })
	close.Holder.AnchorPoint = Vector2.new(0.5, 1)
	close.Holder.Position = UDim2.new(0.5, 0, 1, -16)
	close.Holder.Size = UDim2.fromOffset(200, 50)
	close.Holder.ZIndex = 21
	HudKit.Press(close, false, close.Holder :: any)
	local closeText = HudKit.Text(close.Face, "AWESOME!", HudKit.Head, 26, C.White, 2.5)
	closeText.ZIndex = 25

	local TIER_COLORS = {
		BRONZE = Color3.fromRGB(230, 150, 90),
		SILVER = Color3.fromRGB(210, 225, 245),
		GOLD = C.Gold,
		TITAN = C.Pink,
	}
	local pendingCrate = nil
	local function closeResults()
		if not results.Visible then
			return
		end
		UiFx.Close(results)
		local crate = pendingCrate
		pendingCrate = nil
		if crate and CrateController.PlayOpening then
			task.delay(0.3, CrateController.PlayOpening, crate[1], crate[2])
		end
	end
	(close.Holder :: TextButton).Activated:Connect(closeResults)

	local function showResults(data)
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for _, row in data.Rows or {} do
			local line = new("Frame", {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundTransparency = 1,
				LayoutOrder = row.Rank,
				ZIndex = 22,
			}, list)
			local isMe = row.UserId == player.UserId
			local name = HudKit.Text(
				line,
				("%d. %s"):format(row.Rank, row.Name),
				HudKit.Body,
				18,
				if isMe then C.Gold else C.White,
				1.5
			)
			name.Size = UDim2.fromScale(0.5, 1)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.ZIndex = 23
			local tier = HudKit.Text(line, row.Tier or "-", HudKit.Head, 18, TIER_COLORS[row.Tier] or C.Grey, 1.5)
			tier.Position = UDim2.fromScale(0.5, 0)
			tier.Size = UDim2.fromScale(0.22, 1)
			tier.ZIndex = 23
			local damage = HudKit.Text(line, Currency.Format(row.Damage), HudKit.Num, 18, C.White, 1.5)
			damage.AnchorPoint = Vector2.new(1, 0)
			damage.Position = UDim2.fromScale(1, 0)
			damage.Size = UDim2.fromScale(0.28, 1)
			damage.TextXAlignment = Enum.TextXAlignment.Right
			damage.ZIndex = 23
		end
		local lines = {}
		if data.Tier then
			local color = (TIER_COLORS[data.Tier] or C.White):ToHex()
			table.insert(lines, ('YOUR TIER: <font color="#%s">%s</font>  (#%d)'):format(color, data.Tier, data.Rank))
			table.insert(lines, ('<font color="#FFC93A">+%s COINS</font>'):format(Currency.Format(data.Coins or 0)))
			if data.TopBonus and data.TopBonus > 0 then
				table.insert(lines, "TOP DAMAGE BONUS INCLUDED!")
			end
			local crate = Balls.GetCrate(data.CrateId)
			if crate then
				table.insert(lines, "+ " .. crate.Name:upper())
				pendingCrate = if data.Crate then { crate, data.Crate } else nil
			end
			for _, potion in data.Potions or {} do
				local row = nil
				for _, item in Config.Potions.List do
					if item.Id == potion.Id then
						row = item
					end
				end
				table.insert(lines, ("+ %d %s"):format(potion.Count, (row and row.Name or potion.Id):upper()))
			end
			if data.Drop then
				table.insert(lines, ('<font color="#FF4FB0">BOSS DROP: %s!</font>'):format(data.Drop.Name:upper()))
			end
		else
			table.insert(lines, "LAND A HIT TO EARN REWARDS NEXT TIME!")
		end
		mineText.Text = table.concat(lines, "\n")
		resultsTitle.Text = if data.Won == false then "THE TITAN GOT AWAY!" else "PIN TITAN DEFEATED!"
		UiFx.Open(results)
		UiFx.Confetti(nil, 40)
		Sfx.Play("RevealBig")
		if data.Drop then
			task.delay(0.6, function()
				showCall("BOSS DROP!", data.Drop.Name:upper(), C.Pink, 2.5)
			end)
		end
		task.delay(BOSS.ResultsSeconds - 1, closeResults)
	end

	eventRemote.OnClientEvent:Connect(function(kind: string, data)
		if kind == "Takeoff" then
			flight("TAKING OFF...", data.Seconds)
		elseif kind == "Return" then
			closeResults()
			flight("FLYING BACK...", data.Seconds)
		elseif kind == "Throw" then
			fly(data)
		elseif kind == "Hit" then
			damagePop(data)
		elseif kind == "Plate" then
			plateBreak(data.Position)
		elseif kind == "Results" then
			showResults(data)
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
		local unlocked = Zones.Unlocked(player:GetAttribute("RankLevel"), BOSS.Zone)
		local fighting = player:GetAttribute("BossFighting") == true
		local boarded = player:GetAttribute("BossBoarded") == true

		-- What the lobby says
		local text, color = "", C.White
		local siren = false
		if eventState == "Boarding" then
			if boarded then
				text, color = "ON BOARD! TAKEOFF IN " .. clock(boardingEnds - now), C.Lime
			else
				text, color = "HELICOPTER BOARDING! " .. clock(boardingEnds - now), C.Gold
			end
		elseif eventState == "Fight" or eventState == "Results" then
			text, color = "PIN TITAN FIGHT IN PROGRESS", C.Grey
		else
			local left = opensAt - now
			if left <= BOSS.SirenSeconds then
				text, color, siren = "BOSS INCOMING! BOARDING IN " .. clock(left), C.Red, true
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
		local showPill = unlocked and not fighting and inLobby()
		pill.Visible = showPill
		if showPill then
			pillText.Text = text
			pillText.TextColor3 = color
			pillStroke.Color = if siren then C.Red elseif eventState == "Boarding" then C.Gold else C.Pink
			if siren then
				-- flashing pill + siren every 2 seconds
				pill.BackgroundColor3 = if math.floor(now * 2) % 2 == 0 then C.RedLip else C.Panel
				if os.clock() - lastSiren >= 2 then
					lastSiren = os.clock()
					Sfx.Play("BossSiren")
					UiFx.Flash(C.Red, 0.15, 0.5)
				end
			else
				pill.BackgroundColor3 = C.Panel
			end
		end

		-- The fight HUD (it takes the level bar's place at the top; the bar comes back after the fight)
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
			healthFill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
			healthFill.Visible = hp > 0
			healthText.Text = Currency.Format(hp) .. " / " .. Currency.Format(maxHp)
			local plates = state:GetAttribute("Plates") or 0
			phaseLabel.Text = if phase == "Armor" then ("ARMOR: %d PLATES"):format(plates) else PHASE_NAMES[phase] or ""
			local showMeter = phase == "Finale" or phase == "Giant" or phase == "Defeated"
			meterBack.Visible = showMeter
			if showMeter then
				local goal = math.max(1, state:GetAttribute("MeterGoal") or 1)
				local fill = state:GetAttribute("Meter") or 0
				meterFill.Size = UDim2.fromScale(math.clamp(fill / goal, 0, 1), 1)
				meterText.Text = if fill >= goal
					then "TEAM METER FULL!"
					else ("TEAM METER %d%%"):format(fill / goal * 100)
			end
			local endsAt = if phase == "Giant"
				then state:GetAttribute("GiantEndsAt")
				else state:GetAttribute("FightEndsAt")
			timerLabel.Text = if endsAt and phase ~= "Defeated" then clock(endsAt - now) else ""
			timerLabel.TextColor3 = if endsAt and endsAt - now <= 20 then C.Red else C.White
			local streak = player:GetAttribute("BossStreak") or 0
			damageLabel.Text = ("YOUR DAMAGE %s%s"):format(
				Currency.Format(player:GetAttribute("BossDamage") or 0),
				if streak >= 2 then ("   PERFECT x%d"):format(streak) else ""
			)
			damageLabel.Position = UDim2.fromOffset(0, if showMeter then 94 else 66)
		end
		giantBanner.Visible = fighting and player:GetAttribute("BossGiant") == true
		task.wait(0.1)
	end
end

return BossController
