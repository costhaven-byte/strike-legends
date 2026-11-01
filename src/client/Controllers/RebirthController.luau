-- REBIRTH button on the HUD (owner 2026-10-25: a button, not a station in the world), right of the level bar at the
-- top of the screen. Owner 2026-10-27: rebirths open the zones, so it shows from zone 1 once the first 3 minutes are
-- done (Onboarding 3). Tapping it opens the rebirth window: what you go back to, what you keep, the boost you get
-- forever (and the zone it opens) and what the next rebirth needs. REBIRTH needs a second tap to confirm.
-- UI pass batch 4 (2026-10-29): the window is in the owner's kit look (RewardKit window + cover, three blocks, lip
-- buttons) and a done rebirth gets a full-screen "REBIRTH!" moment. While it shows, the local attribute
-- RebirthParty holds back the ZONE UNLOCKED window (ZoneGateController), which follows when you tap CONTINUE.
-- Built in code (not in Studio), so it lives in git. The server decides everything (RebirthService).
-- Addendum 5 step C (core loop, Config.CoreLoop.Rebirth): a big gold REBIRTH button in the left column (the hidden
-- POWER LV's spot) shows the multiplier now > after ("x1 > x2") and a coins bar; its window shows what goes back to
-- the start, what you keep, the multiplier on coins AND pins, the tier colour and the price. Rebirth is bought only
-- standing at the ball shop: away from it the window's button says GO TO SHOP (teleports you there). Tap twice,
-- then the full-screen REBIRTH! moment with a flash.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CoreLadder = require(Shared.Modules.CoreLadder)
local Currency = require(Shared.Modules.Currency)
local Rebirth = require(Shared.Modules.Rebirth)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local HudKit = require(Modules:WaitForChild("HudKit"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local CrateKit = require(Modules:WaitForChild("CrateKit"))
local RewardKit = require(Modules:WaitForChild("RewardKit"))
local MomentKit = require(Modules:WaitForChild("MomentKit"))

local player = Players.LocalPlayer

local REBIRTH = Config.Economy.Rebirth
local C = UiKit.C
local make = UiKit.Make
local tween = UiKit.Tween
local CONFIRM_SECONDS = 3
local CORE = Config.CoreLoop

local RebirthController = {}

local function hex(color: Color3): string
	return "#" .. color:ToHex()
end

-- A navy pill with an icon and a word, sized to its words (rows in the window, chips on the REBIRTH! screen)
local function chip(parent: Instance, text: string, color: Color3, icon: string?, size: number, h: number): Frame
	local width = CrateKit.TextWidth(text, UiKit.Head, size) + (if icon then h + 26 else 36)
	local block = UiKit.Block(parent, {
		Name = "Chip",
		Size = Vector2.new(width, h),
		Fill = C.Cover,
		Lip = C.Ink,
		LipPx = 4,
		Radius = h / 2,
		Outline = 3,
	})
	local x = 18
	if icon then
		HudKit.Image(block.Face, icon, h - 18, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, -1),
		})
		x = h
	end
	local label = UiKit.Text(block.Face, text, UiKit.Head, size, color, 2.5)
	label.Position = UDim2.fromOffset(x, 2)
	label.Size = UDim2.new(1, -x - 14, 1, -2)
	return block.Holder :: Frame
end

-- ===== REBIRTH! moment: full screen, the rebirth arrows on rays, what you got, confetti and CONTINUE =====
-- show(rebirthsDone, zoneOpened?)
local function celebration(): (number, number?) -> ()
	local gui = MomentKit.Layer("RebirthPartyUI", 50)
	local screen = make("Frame", {
		Name = "Screen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Active = true,
	}, gui) :: Frame
	local shade = make("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, screen)
	local flash = make("Frame", {
		Name = "Flash",
		BackgroundColor3 = C.Lime,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, screen)
	local W, H = 900, 720
	local stage = make("Frame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		ZIndex = 2,
	}, screen)
	local fit = make("UIScale", {}, stage)
	local function refit()
		local area = gui.AbsoluteSize
		if area.X > 0 then
			fit.Scale = math.max(0.3, math.min(1, (area.X - 24) / W, (area.Y - 16) / H))
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	local pop = make("Frame", { Name = "Pop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, stage)
	local popScale = UiKit.ScaleOf(pop)

	local titleBox = make("Frame", {
		Name = "TitleBox",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.fromOffset(W, 110),
		ZIndex = 5,
	}, pop)
	CrateKit.Title(titleBox, "REBIRTH!", 110, C.Lime, 5, 8)
	local iconSpot = make("Frame", {
		Name = "IconSpot",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(W / 2, 290),
		Size = UDim2.fromOffset(240, 240),
		ZIndex = 3,
	}, pop)
	local rays = RewardKit.Rays(iconSpot, C.Lime, 760, 9)
	rays.ZIndex = 1
	local arrows = HudKit.Image(iconSpot, "Rebirth", 240, { ZIndex = 4 })
	local nameBox = make("Frame", {
		Name = "NameBox",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 432),
		Size = UDim2.fromOffset(W, 84),
		ZIndex = 5,
	}, pop)
	local count = CrateKit.Title(nameBox, "", 70, C.White, 4.5, 7)
	local chips = make("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 528),
		Size = UDim2.fromOffset(W, 56),
		ZIndex = 5,
	}, pop)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 14),
	}, chips)
	local continue = RewardKit.Button(pop, "CONTINUE", "Lime", 300, 72, 36)
	continue.Holder.Position = UDim2.fromOffset((W - 300) / 2, 616)

	local stopTwinkle: (() -> ())? = nil
	local stopSpin: (() -> ())? = nil
	local canClose = false
	local function close()
		if not screen.Visible or not canClose then
			return
		end
		canClose = false
		for _, stop in { stopTwinkle, stopSpin } do
			if stop then
				stop()
			end
		end
		stopTwinkle, stopSpin = nil, nil
		tween(shade, 0.2, Enum.EasingStyle.Linear, { BackgroundTransparency = 1 })
		tween(popScale, 0.22, Enum.EasingStyle.Back, { Scale = 0 }, Enum.EasingDirection.In).Completed:Wait()
		screen.Visible = false
		player:SetAttribute("RebirthParty", nil) -- the ZONE UNLOCKED window may show now
	end
	continue.Activated:Connect(close)
	UiKit.CloseKeys(screen, close)

	return function(done: number, zone: number?)
		player:SetAttribute("RebirthParty", true)
		refit()
		count.Text = ("REBIRTH %d"):format(done)
		for _, child in chips:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local coins = Currency.FormatMultiplier(Rebirth.CoinMultiplier(done))
		chip(chips, coins .. " COINS", C.Gold, "Coin", 28, 56).LayoutOrder = 1
		if Rebirth.CoreOn() then
			-- Addendum 5 step C: coins and pins, and the tier the rebirth reached
			chip(chips, coins .. " PINS", C.Pink, "Pin", 28, 56).LayoutOrder = 2
			-- (Addendum 6 2.4: the rank name the rebirth reached)
			local rank = Rebirth.Rank(done)
			chip(chips, rank.Name:upper(), rank.Color, "Rebirth", 28, 56).LayoutOrder = 3
		else
			local xp = Currency.FormatMultiplier(Rebirth.XpMultiplier(done))
			chip(chips, xp .. " XP", C.Cyan, "Xp", 28, 56).LayoutOrder = 2
		end
		if zone then
			chip(chips, Zones.Name(zone):upper() .. " OPEN!", C.Pink, "Portal", 28, 56).LayoutOrder = 3
		end

		screen.Visible = true
		shade.BackgroundTransparency = 1
		tween(shade, 0.25, Enum.EasingStyle.Linear, { BackgroundTransparency = 0.12 })
		flash.BackgroundTransparency = 0.2
		tween(flash, 0.7, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
		popScale.Scale = 0.6
		tween(popScale, 0.3, Enum.EasingStyle.Back, { Scale = 1 })
		RewardKit.Stamp(titleBox)
		-- the arrows spin in fast, then keep turning slowly
		local arrowScale = UiKit.ScaleOf(arrows)
		arrowScale.Scale = 0.01
		arrows.Rotation = -360
		task.delay(0.2, function()
			tween(arrows, 0.6, Enum.EasingStyle.Quint, { Rotation = 0 })
			tween(arrowScale, 0.35, Enum.EasingStyle.Back, { Scale = 1.15 }).Completed:Wait()
			tween(arrowScale, 0.12, Enum.EasingStyle.Quad, { Scale = 1 })
			task.wait(0.3)
			if screen.Visible and not stopSpin then
				stopSpin = HudKit.Spin(arrows, 6)
			end
		end)
		RewardKit.Stagger({ nameBox, chips, continue.Holder }, 0.12, 0.45)
		if stopTwinkle then
			stopTwinkle()
		end
		stopTwinkle = RewardKit.Twinkle(iconSpot, 8, C.Lime)
		CrateKit.Confetti(pop, 0, -120, 50, 480, 1)
		task.delay(0.5, function()
			CrateKit.Confetti(pop, -300, -60, 24, 260, 0.9)
			CrateKit.Confetti(pop, 300, -60, 24, 260, 0.9)
		end)
		Sfx.Play("RankUp", 1)
		canClose = false
		task.delay(0.8, function()
			canClose = true
		end)
	end
end


-- ===== Addendum 5 step C: the core loop rebirth (button, window, moment) =====
local function startCore()
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local remote = remotes:WaitForChild("Rebirth") :: RemoteFunction
	local goRemote = remotes:WaitForChild("CoreGoTo") :: RemoteEvent
	local K = HudKit.C

	local gui = Instance.new("ScreenGui")
	gui.Name = "RebirthUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = hud.IgnoreGuiInset
	gui.Parent = playerGui

	-- ===== The big gold button (left column, under BALLS / PETS / STORE) =====
	local block = HudKit.Block(gui, { Name = "RebirthButton", Paint = "Gold", Button = true, Radius = 16, Lip = 6 })
	local button = block.Holder :: TextButton
	local face = block.Face
	local icon = HudKit.Image(face, "Rebirth", 40, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		ZIndex = 5,
	})
	local title = HudKit.Text(face, "REBIRTH", HudKit.Head, 22, K.White, 2.5)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 5
	-- "x1 > x2" under the title: the multiplier now and after the next rebirth
	local preview = HudKit.Text(face, "", HudKit.Num, 15, K.White, 2)
	preview.TextXAlignment = Enum.TextXAlignment.Left
	preview.ZIndex = 5
	-- red dot (ready) on the top-right corner
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -4, 0, 4)
	dot.Size = UDim2.fromOffset(18, 18)
	dot.BackgroundColor3 = K.Red
	dot.ZIndex = 9
	dot.Visible = false
	dot.Parent = button
	HudKit.Corner(dot, 9)
	HudKit.Outline(dot, K.Ink, 2.5)
	-- progress strip along the bottom of the face: coins / price
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.BackgroundColor3 = K.Ink
	track.BackgroundTransparency = 0.55
	track.BorderSizePixel = 0
	track.ZIndex = 5
	track.Parent = face
	HudKit.Corner(track, 3)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = K.White
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 6
	fill.Parent = track
	HudKit.Corner(fill, 3)

	HudKit.OnLayout(function(isPhone)
		block:SetRadius(if isPhone then 12 else 16)
		block:SetLip(if isPhone then 5 else 6)
		icon.Size = UDim2.fromOffset(if isPhone then 28 else 42, if isPhone then 28 else 42)
		icon.Position = UDim2.new(0, if isPhone then 4 else 6, 0.5, -2)
		local left = if isPhone then 36 else 56
		title.Position = UDim2.fromOffset(left, if isPhone then 3 else 5)
		title.Size = UDim2.new(1, -left - 6, 0, if isPhone then 16 else 22)
		HudKit.Fit(title, if isPhone then 15 else 22)
		-- (the x1 > x2 line ends above the coins bar)
		preview.Position = UDim2.fromOffset(left, if isPhone then 19 else 27)
		preview.Size = UDim2.new(1, -left - 6, 0, if isPhone then 13 else 15)
		HudKit.Fit(preview, if isPhone then 11 else 14)
		track.Position = UDim2.new(0.5, 0, 1, if isPhone then -3 else -5)
		track.Size = UDim2.new(1, if isPhone then -12 else -20, 0, if isPhone then 4 else 5)
	end)
	HudKit.Place(button, "CoreRebirth")

	-- ready: the glow breathes, the button grows a little, the arrows turn, a red dot
	local glowTween = TweenService:Create(
		block.GlowRing,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.7 }
	)
	local breatheTween = TweenService:Create(
		block.Scale,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.06 }
	)
	local stopSpin: (() -> ())? = nil
	local readyShown = false
	local function setReady(ready: boolean)
		if ready == readyShown then
			return
		end
		readyShown = ready
		block:SetGlow(if ready then K.Lime else nil)
		dot.Visible = ready
		if ready then
			block.GlowRing.Transparency = 0.2
			glowTween:Play()
			breatheTween:Play()
			stopSpin = HudKit.Spin(icon, 3)
		else
			glowTween:Cancel()
			breatheTween:Cancel()
			block.Scale.Scale = 1
			if stopSpin then
				stopSpin()
				stopSpin = nil
			end
			icon.Rotation = 0
		end
	end

	-- ===== The window =====
	local W, H = 560, 568
	local IN_W = W - 48
	local windowGui = make("ScreenGui", {
		Name = "RebirthWindowUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 12,
	}, playerGui) :: ScreenGui
	local win = RewardKit.Window(windowGui, W, H)
	local cover, closeX = RewardKit.Cover(win.Panel, W, H, "REBIRTH", "START AGAIN, STRONGER FOREVER", C.Gold)
	local titleFront = (cover:FindFirstChild("TitleBox") :: Frame):FindFirstChild("Front", true) :: TextLabel

	local function section(name: string, heading: string, color: Color3, y: number, h: number, ring: Color3?): Frame
		local sectionBlock = UiKit.Block(cover, {
			Name = name,
			Size = Vector2.new(IN_W, h),
			Fill = C.Card,
			Lip = C.Page,
			LipPx = 5,
			Radius = 16,
			Outline = 3,
			Ring = ring,
		})
		sectionBlock.Holder.Position = UDim2.fromOffset(24, y)
		local head = RewardKit.Label(sectionBlock.Face, heading, UiKit.Head, 18, color, 2, 16, 8, IN_W - 32, 22)
		head.Name = "Heading"
		head.TextXAlignment = Enum.TextXAlignment.Left
		return sectionBlock.Face
	end

	-- 1. YOU GO BACK TO: ball 1, bag 1, 0 coins
	local back = section("Back", "YOU GO BACK TO", C.Price, 94, 80)
	local backRow = make("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -28, 0, 38),
	}, back)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, backRow)
	chip(backRow, "BALL 1", C.White, "Ball", 18, 38).LayoutOrder = 1
	chip(backRow, "BAG 1", C.White, nil, 18, 38).LayoutOrder = 2
	chip(backRow, "0 COINS", C.White, "Coin", 18, 38).LayoutOrder = 3

	-- 2. YOU KEEP: pets (all, equipped, Shiny), pet slots, rebirths
	local keep = section("Keep", "YOU KEEP", C.Lime, 184, 92)
	local KEEPS = {
		{ "Paw", "ALL PETS" },
		{ "Check", "EQUIPPED" },
		{ "Clover", "SHINY" },
		{ "Paw", "PET SLOTS" },
		{ "Rebirth", "REBIRTHS" },
	}
	local cellW = (IN_W - 28) / #KEEPS
	for i, item in KEEPS do
		local cell = make("Frame", {
			Name = item[2],
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14 + (i - 1) * cellW, 30),
			Size = UDim2.fromOffset(cellW, 56),
		}, keep)
		HudKit.Image(cell, item[1], 34, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
		})
		RewardKit.Label(cell, item[2], UiKit.Head, 14, C.White, 2, 0, 36, cellW, 18)
	end

	-- 3. YOU GET FOREVER: "x2 > x3" big, on coins AND pins, and the tier colour
	local forever = section("Forever", "YOU GET FOREVER", C.Gold, 286, 140, C.Gold)
	local multBig = RewardKit.Label(forever, "", UiKit.Head, 50, C.Gold, 3.5, 16, 30, 270, 58)
	multBig.TextXAlignment = Enum.TextXAlignment.Left
	make("UIPadding", { PaddingTop = UDim.new(0, 5) }, multBig)
	local multWhat = RewardKit.Label(forever, "COINS AND PINS", UiKit.Head, 20, C.White, 2.5, 18, 92, 270, 24)
	multWhat.TextXAlignment = Enum.TextXAlignment.Left
	local tierSwatch = make("Frame", {
		Name = "Swatch",
		Position = UDim2.fromOffset(292, 42),
		Size = UDim2.fromOffset(24, 24),
		BorderSizePixel = 0,
	}, forever)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, tierSwatch)
	make("UIStroke", { Color = C.Ink, Thickness = 2.5 }, tierSwatch)
	local tierLine = RewardKit.Label(forever, "", UiKit.Head, 20, C.White, 2.5, 324, 40, IN_W - 340, 26)
	tierLine.TextXAlignment = Enum.TextXAlignment.Left
	local tierNote = RewardKit.Label(forever, "", UiKit.Body, 13, C.Muted, 0, 292, 72, IN_W - 308, 54)
	tierNote.TextXAlignment = Enum.TextXAlignment.Left
	tierNote.TextYAlignment = Enum.TextYAlignment.Top
	tierNote.TextWrapped = true

	-- the price (green = you have it, red = not yet) + where it's bought
	local needs = RewardKit.Label(cover, "", UiKit.Head, 22, C.White, 2.5, 24, 438, IN_W, 28)
	needs.RichText = true

	local go = RewardKit.Button(cover, "REBIRTH!", "Gold", 300, 66, 30)
	go.Holder.Position = UDim2.fromOffset(24, H - 66 - 24)
	local notYet = RewardKit.Button(cover, "NOT YET", "Grey", IN_W - 300 - 12, 66, 28)
	notYet.Holder.Position = UDim2.fromOffset(24 + 300 + 12, H - 66 - 24)

	local party = celebration()
	RebirthController.Party = party -- (Addendum 6 2.4: the shop's Rebirth tab plays the same moment)
	local confirmUntil = 0
	local busy = false
	local stopConfirmPulse: (() -> ())? = nil

	-- Standing at the ball shop booth (the circle the server checks, CoreLoopService.AtShop; a little stricter here)
	local function atShop(): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return false
		end
		local offset = root.Position - (CORE.Shop.Position + CoreLadder.ZoneOffset(CoreLadder.ZoneAt(root.Position))) -- (A6 Stage 3)
		return Vector2.new(offset.X, offset.Z).Magnitude <= CORE.Shop.Radius + (CORE.Shop.BuySlack or 0) - 0.5
			and offset.Y > -4
			and offset.Y < 10
	end

	local function state()
		local done = player:GetAttribute("Rebirths") or 0
		local price = Rebirth.CorePrice(done)
		return done, price, Currency.CanAfford(player:GetAttribute("Coins"), price)
	end

	local lastShop: boolean? = nil
	local function refresh()
		local done, price, hasCoins = state()
		local nowText = Currency.FormatMultiplier(Rebirth.CoreMultiplier(done))
		local afterText = Currency.FormatMultiplier(Rebirth.CoreMultiplier(done + 1))
		-- the button
		preview.Text = ("%s  ›  %s"):format(nowText, afterText)
		local coins = tonumber(player:GetAttribute("Coins")) or 0
		TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(math.clamp(coins / math.max(price, 1), 0, 1), 1),
		}):Play()
		setReady(hasCoins)
		title.Text = if hasCoins then "REBIRTH!" else "REBIRTH"

		-- the window
		titleFront.Text = ("REBIRTH %d"):format(done + 1)
		multBig.Text = ("%s › %s"):format(nowText, afterText)
		local tier, nextTier = Rebirth.Tier(done), Rebirth.Tier(done + 1)
		local newTier = nextTier ~= nil and (tier == nil or tier.Name ~= nextTier.Name)
		local shown = nextTier or tier
		tierSwatch.Visible = shown ~= nil
		if shown then
			tierSwatch.BackgroundColor3 = shown.Color
			tierLine.Text = if newTier then ("%s!"):format(shown.Name:upper()) else shown.Name:upper()
			tierLine.TextColor3 = shown.Color
			tierNote.Text = if newTier
				then "New colour on your pins, your throw spot and the tag over your head"
				else "Your pins, throw spot and head tag keep this colour"
		end
		local here = atShop()
		lastShop = here
		needs.Text = ('PRICE  <font color="#%s">%s COINS</font>%s'):format(
			(if hasCoins then C.Lime else C.Red):ToHex(),
			Currency.Format(price),
			if here then "" else "  ·  AT THE BALL SHOP"
		)

		local confirming = hasCoins and here and os.clock() < confirmUntil
		if not hasCoins then
			go:SetText(("NEED %s"):format(Currency.Format(price)))
			go:Paint(C.Grey, C.GreyLip, C.LockedText)
		elseif not here then
			go:SetText("GO TO SHOP")
			go:Paint(C.Cyan, C.CyanLip, C.White)
		elseif confirming then
			go:SetText("TAP AGAIN TO REBIRTH")
			go:Paint(C.Pink, C.PinkLip, C.White)
		else
			go:SetText("REBIRTH!")
			go:Paint(C.Gold, C.GoldLip, C.White)
		end
		if not confirming and stopConfirmPulse then
			stopConfirmPulse()
			stopConfirmPulse = nil
		end
	end

	local function setOpen(open: boolean)
		windowGui:SetAttribute("Open", open) -- (the shop doesn't pop open over it, CoreShopController)
		if open then
			confirmUntil = 0
			refresh()
			win:Open()
			RewardKit.Stagger({
				cover:FindFirstChild("Back") :: GuiObject,
				cover:FindFirstChild("Keep") :: GuiObject,
				cover:FindFirstChild("Forever") :: GuiObject,
			}, 0.07, 0.1)
		else
			win:Close()
		end
	end

	button.Activated:Connect(function()
		if CORE.Shop.RebirthTab then
			-- Addendum 6 2.4: the REBIRTH button opens the shop's Rebirth tab (hold to rebirth there)
			local shop = require(script.Parent.CoreShopController) :: any
			if shop.SetOpen then
				shop.SetOpen(true, "Rebirth")
			end
			return
		end
		setOpen(not win:IsOpen())
	end)
	closeX.Activated:Connect(function()
		setOpen(false)
	end)
	notYet.Activated:Connect(function()
		setOpen(false)
	end)
	go.Activated:Connect(function()
		local done, _, hasCoins = state()
		if busy or not hasCoins then
			go:Shake()
			return
		end
		if not atShop() then
			-- rebirth is bought at the ball shop: take the player there (the window stays open)
			goRemote:FireServer("Shop")
			task.delay(0.6, refresh)
			return
		end
		-- A rebirth can't be undone: the first tap asks, the second (within a few seconds) does it
		if os.clock() >= confirmUntil then
			confirmUntil = os.clock() + CONFIRM_SECONDS
			refresh()
			if stopConfirmPulse then
				stopConfirmPulse()
			end
			stopConfirmPulse = RewardKit.Pulse(go.Holder, 1.06, 0.3)
			task.delay(CONFIRM_SECONDS, refresh)
			return
		end
		busy = true
		local ok, result = pcall(remote.InvokeServer, remote)
		busy = false
		confirmUntil = 0
		if ok and result and result.Ok then
			setOpen(false)
			task.delay(0.25, party, done + 1, nil)
		else
			go:SetText(if ok and result and result.Error then result.Error:upper() else "TRY AGAIN")
			go:Shake()
			task.delay(2, refresh)
		end
	end)

	for _, key in { "Coins", "Rebirths" } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	-- walking onto / off the shop circle changes the window's button
	task.spawn(function()
		while true do
			task.wait(0.3)
			if win:IsOpen() and atShop() ~= lastShop then
				refresh()
			end
		end
	end)
	refresh()
end

function RebirthController:Start()
	-- (switched off in the Addendum 4 core loop: the rooftop is the only zone; Addendum 5 step C: the core rebirth)
	if Config.CoreLoop.Enabled then
		if Rebirth.CoreOn() then
			startCore()
		end
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth") :: RemoteFunction

	local gui = Instance.new("ScreenGui")
	gui.Name = "RebirthUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = hud.IgnoreGuiInset -- same coordinates as the level bar it sits beside
	gui.Parent = playerGui

	-- ===== The button =====
	-- Right of the level bar (owner's HUD Kit): lime; ready = a glow, a red dot and the arrows turning
	local rebirthKit = HudKit.Square(gui, { Name = "RebirthButton", Paint = "Lime", Icon = "Rebirth", Key = "Rebirth" })
	local openButton = rebirthKit.Holder :: TextButton
	openButton.Visible = false
	local kitState = ""
	local stopSpin: (() -> ())? = nil
	local glowPulse = TweenService:Create(
		rebirthKit.GlowRing,
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.7 }
	)
	local function setLook(newState: string)
		if newState == kitState then
			return
		end
		kitState = newState
		rebirthKit:Paint("Lime")
		rebirthKit:SetIcon("Rebirth")
		rebirthKit:SetCaption("REBIRTH", nil, nil, 10)
		local ready = newState == "Ready"
		rebirthKit:SetGlow(if ready then HudKit.C.Lime else nil)
		rebirthKit:SetDot(ready)
		if ready then
			rebirthKit.GlowRing.Transparency = 0.3
			glowPulse:Play()
			stopSpin = HudKit.Spin(rebirthKit.Slot, 3)
		else
			glowPulse:Cancel()
			if stopSpin then
				stopSpin()
				stopSpin = nil
			end
		end
	end

	-- First rebirth ready (new-player guide): a bouncing "TAP!" arrow under the button
	local tapArrow = Instance.new("TextLabel")
	tapArrow.Name = "TapArrow"
	tapArrow.BackgroundTransparency = 1
	tapArrow.AnchorPoint = Vector2.new(0.5, 0)
	tapArrow.Position = UDim2.new(0.5, 0, 1, 18)
	tapArrow.Size = UDim2.fromOffset(140, 46) -- wide enough for "NEW ZONE!" (rebirth teaser)
	tapArrow.FontFace = UiKit.Head
	tapArrow.TextScaled = true
	tapArrow.TextColor3 = C.Lime
	tapArrow.Text = "▲\nTAP!"
	tapArrow.ZIndex = 20
	tapArrow.Visible = false
	tapArrow.Parent = openButton
	UiKit.Outline(tapArrow, C.Ink, 2.5)
	TweenService:Create(
		tapArrow,
		TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.new(0.5, 0, 1, 28) }
	):Play()

	-- ===== The window =====
	local W, H = 560, 516
	local IN_W = W - 48
	local windowGui = make("ScreenGui", {
		Name = "RebirthWindowUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 12,
	}, playerGui) :: ScreenGui
	local win = RewardKit.Window(windowGui, W, H)
	local cover, closeX = RewardKit.Cover(win.Panel, W, H, "REBIRTH", "START AGAIN, STRONGER FOREVER", C.Lime)
	local titleFront = (cover:FindFirstChild("TitleBox") :: Frame):FindFirstChild("Front", true) :: TextLabel

	-- A block: a card with a coloured heading in its top-left corner
	local function section(name: string, heading: string, color: Color3, y: number, h: number, ring: Color3?): Frame
		local block = UiKit.Block(cover, {
			Name = name,
			Size = Vector2.new(IN_W, h),
			Fill = C.Card,
			Lip = C.Page,
			LipPx = 5,
			Radius = 16,
			Outline = 3,
			Ring = ring,
		})
		block.Holder.Position = UDim2.fromOffset(24, y)
		local head = RewardKit.Label(block.Face, heading, UiKit.Head, 18, color, 2, 16, 8, IN_W - 32, 22)
		head.Name = "Heading"
		head.TextXAlignment = Enum.TextXAlignment.Left
		return block.Face
	end

	-- 1. YOU GO BACK TO: level 1, Power Level 1, 0 coins (batch D1: levels reset too)
	local back = section("Back", "YOU GO BACK TO", C.Price, 94, 80)
	local backRow = make("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 32),
		Size = UDim2.new(1, -28, 0, 38),
	}, back)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 10),
	}, backRow)
	chip(backRow, "LEVEL 1", C.White, "Xp", 18, 38).LayoutOrder = 1
	chip(backRow, "POWER LV 1", C.White, "Bolt", 18, 38).LayoutOrder = 2
	chip(backRow, "0 COINS", C.White, "Coin", 18, 38).LayoutOrder = 3

	-- 2. YOU KEEP: one icon per thing you keep
	local keep = section("Keep", "YOU KEEP", C.Lime, 184, 92)
	local KEEPS = {
		{ "Ball", "BALLS" },
		{ "Paw", "PETS" },
		{ "Gem", "GEMS" },
		{ "PotionCoin", "POTIONS" },
		{ "Portal", "ZONES" },
	}
	local cellW = (IN_W - 28) / #KEEPS
	for i, item in KEEPS do
		local cell = make("Frame", {
			Name = item[2],
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14 + (i - 1) * cellW, 30),
			Size = UDim2.fromOffset(cellW, 56),
		}, keep)
		HudKit.Image(cell, item[1], 34, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
		})
		RewardKit.Label(cell, item[2], UiKit.Head, 14, C.White, 2, 0, 36, cellW, 18)
	end

	-- 3. YOU GET FOREVER: the new coin boost big, the XP boost, the zone it opens
	local forever = section("Forever", "YOU GET FOREVER", C.Gold, 286, 112, C.Gold)
	local coinsBig = RewardKit.Label(forever, "", UiKit.Head, 46, C.Gold, 3.5, 16, 30, 240, 52)
	coinsBig.TextXAlignment = Enum.TextXAlignment.Left
	make("UIPadding", { PaddingTop = UDim.new(0, 5) }, coinsBig)
	local coinsWas = RewardKit.Label(forever, "", UiKit.Body, 13, C.Muted, 0, 18, 82, 240, 18)
	coinsWas.TextXAlignment = Enum.TextXAlignment.Left
	local xpBig = RewardKit.Label(forever, "", UiKit.Head, 32, C.Cyan, 3, 262, 34, 232, 38)
	xpBig.TextXAlignment = Enum.TextXAlignment.Left
	local opens = RewardKit.Label(forever, "", UiKit.Head, 20, C.Pink, 2.5, 262, 74, 232, 26)
	opens.TextXAlignment = Enum.TextXAlignment.Left

	-- What the next rebirth needs (green = you have it, red = not yet)
	local needs = RewardKit.Label(cover, "", UiKit.Head, 22, C.White, 2.5, 24, 408, IN_W, 28)
	needs.RichText = true

	local go = RewardKit.Button(cover, "REBIRTH!", "Gold", 300, 66, 32)
	go.Holder.Position = UDim2.fromOffset(24, H - 66 - 24)
	local notYet = RewardKit.Button(cover, "NOT YET", "Grey", IN_W - 300 - 12, 66, 28)
	notYet.Holder.Position = UDim2.fromOffset(24 + 300 + 12, H - 66 - 24)

	local party = celebration()
	local confirmUntil = 0
	local busy = false
	local stopConfirmPulse: (() -> ())? = nil

	local function state()
		local done = player:GetAttribute("Rebirths") or 0
		local level = player:GetAttribute("RankLevel") or 1
		local needLevel, cost = Rebirth.Level(done), Rebirth.Cost(done)
		local hasLevel = level >= needLevel
		local hasCoins = Currency.CanAfford(player:GetAttribute("Coins"), cost)
		return done, needLevel, cost, hasLevel, hasCoins
	end

	local function refresh()
		local done, needLevel, cost, hasLevel, hasCoins = state()
		openButton.Visible = done > 0 or (player:GetAttribute("Onboarding") or 0) >= 3
		local ready = REBIRTH.Enabled and hasLevel and hasCoins
		setLook(if ready then "Ready" else "Normal")
		-- also while the rebirth teaser points here (EventController, batch B2)
		local teaser = player:GetAttribute("RebirthTeaser") == true and done == 0
		tapArrow.Visible = (ready or teaser) and done == 0 and not win:IsOpen()
		tapArrow.Text = if ready then "▲\nTAP!" else "▲\nNEW ZONE!"

		-- The window
		titleFront.Text = if done > 0 then ("REBIRTH %d"):format(done + 1) else "REBIRTH"
		coinsBig.Text = ("%s COINS"):format(Currency.FormatMultiplier(Rebirth.CoinMultiplier(done + 1)))
		coinsWas.Text = ("NOW %s"):format(Currency.FormatMultiplier(Rebirth.CoinMultiplier(done)))
		xpBig.Text = ("%s XP"):format(Currency.FormatMultiplier(Rebirth.XpMultiplier(done + 1)))
		local zone = Rebirth.OpensZone(done)
		opens.Text = if zone then ("OPENS %s!"):format(Zones.Name(zone):upper()) else ""
		needs.Text = if needLevel <= 0 -- (Addendum 5 A1: no levels, coins only)
			then ('NEEDS  <font color="%s">%s COINS</font>'):format(
				hex(if hasCoins then C.Lime else C.Red),
				Currency.Format(cost)
			)
			else ('NEEDS  <font color="%s">LV %d</font>  ·  <font color="%s">%s COINS</font>'):format(
				hex(if hasLevel then C.Lime else C.Red),
				needLevel,
				hex(if hasCoins then C.Lime else C.Red),
				Currency.Format(cost)
			)

		local confirming = ready and os.clock() < confirmUntil
		if not REBIRTH.Enabled then
			go:SetText("COMING SOON")
		elseif not hasLevel then
			go:SetText(("REACH LV %d"):format(needLevel))
		elseif not hasCoins then
			go:SetText(("NEED %s"):format(Currency.Format(cost)))
		elseif confirming then
			go:SetText("TAP AGAIN TO REBIRTH")
		else
			go:SetText("REBIRTH!")
		end
		if confirming then
			go:Paint(C.Pink, C.PinkLip, C.White)
		elseif ready then
			go:Paint(C.Gold, C.GoldLip, C.White)
		else
			go:Paint(C.Grey, C.GreyLip, C.LockedText)
		end
		if not confirming and stopConfirmPulse then
			stopConfirmPulse()
			stopConfirmPulse = nil
		end
	end

	local function setOpen(open: boolean)
		if open then
			confirmUntil = 0
			refresh()
			win:Open()
			RewardKit.Stagger({
				cover:FindFirstChild("Back") :: GuiObject,
				cover:FindFirstChild("Keep") :: GuiObject,
				cover:FindFirstChild("Forever") :: GuiObject,
			}, 0.07, 0.1)
		else
			win:Close()
		end
		task.delay(0.4, refresh) -- after the open / close animation
	end
	win.Closed.Event:Connect(function()
		task.delay(0.4, refresh)
	end)

	openButton.Activated:Connect(function()
		setOpen(not win:IsOpen())
	end)
	closeX.Activated:Connect(function()
		setOpen(false)
	end)
	notYet.Activated:Connect(function()
		setOpen(false)
	end)
	go.Activated:Connect(function()
		local done, _, _, hasLevel, hasCoins = state()
		if busy or not (REBIRTH.Enabled and hasLevel and hasCoins) then
			go:Shake()
			return
		end
		-- A rebirth can't be undone: the first tap asks, the second (within a few seconds) does it
		if os.clock() >= confirmUntil then
			confirmUntil = os.clock() + CONFIRM_SECONDS
			refresh()
			if stopConfirmPulse then
				stopConfirmPulse()
			end
			stopConfirmPulse = RewardKit.Pulse(go.Holder, 1.06, 0.3)
			task.delay(CONFIRM_SECONDS, refresh)
			return
		end
		busy = true
		local zone = Rebirth.OpensZone(done)
		-- set before asking: the new ZonesOpen can arrive before the answer, and ZONE UNLOCKED must wait its turn
		player:SetAttribute("RebirthParty", true)
		local ok, result = pcall(remote.InvokeServer, remote)
		busy = false
		confirmUntil = 0
		if ok and result and result.Ok then
			setOpen(false)
			task.delay(0.25, party, done + 1, zone)
		else
			player:SetAttribute("RebirthParty", nil)
			go:SetText(if ok and result and result.Error then result.Error:upper() else "TRY AGAIN")
			go:Shake()
			task.delay(2, refresh)
		end
	end)

	for _, key in { "RankLevel", "Coins", "Rebirths", "Onboarding", "RebirthTeaser" } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	refresh()
end

return RebirthController
