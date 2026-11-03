-- Addendum 4 core loop (Config.CoreLoop), the screen half: the live pin counter ("+1.2K" pins this throw, with a
-- LUCKY! badge on high rolls; Addendum 5 A1), the bag bar, the SELL
-- button (Addendum 5 A2: it teleports you onto the sell pad, where the bag sells: selling only happens there), the
-- BAG FULL, SELL prompt and the sold pop. Style from the owner's simulator refs (assets/ui_refs_addendum4): rounded bold Fredoka text with a thin
-- dark outline, flat fills, one hard offset shadow, thick dark outlines, corners that differ by element.
-- Everything here only shows numbers the server sends (Bag / BagSize attributes, ThrowResult, CoreSold).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetSlots = require(Shared.AssetSlots)
local Currency = require(Shared.Modules.Currency)
local CoreLadder = require(Shared.Modules.CoreLadder)
local Mascots = require(Shared.Modules.Mascots)
local Balls = require(Shared.Modules.Balls)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local HudKit = require(Modules.HudKit)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local BallView = require(Modules.BallView)

local CORE = Config.CoreLoop
local player = Players.LocalPlayer

local CoreHudController = {}

-- The sunny look (Modules/SunKit, Addendum 4 Stage 3d): light panels with dark text, colour buttons with white text
local SunKit = require(Modules.SunKit)
local BallSignature = require(Modules.BallSignature)
local ThrowPose = require(Modules.ThrowPose)
local K = SunKit.C
local INK = K.Ink
local PANEL = K.Cream -- light panels
local TRACK = K.Track
local GREEN = K.Green
local GOLD = K.Sun
local CORAL = K.Coral
local WHITE = K.White
local MUTED = K.Muted

local new = SunKit.New
local text = SunKit.Text

-- A plate whose hard shadow is its own darker colour (ink for light panels)
local function plate(parent: Instance, name: string, color: Color3, radius: number): (Frame, Frame)
	return SunKit.Plate(parent, name, color, radius, 4, if color == PANEL then K.CreamLip else SunKit.Lip(color))
end

local function place(object: GuiObject, key: string)
	HudKit.OnLayout(function(phone)
		local position, size = HudKit.Spot(key, phone)
		object.Position = position
		object.Size = size :: UDim2
	end)
end

-- ===== UI overhaul V2 (Config.Ui.HudV2, owner's board B1/B2) =====
local V2 = HudKit.V2
local Kit = if V2 then require(Modules.SlKit) else nil

-- The NEXT GOAL card (right side): a gold header plate, the next ball spinning in 3D in a well (a dark silhouette
-- until bought, like the shop; the next bag or the rebirth shows its icon), what it gives, and coins / price.
local function buildGoalCard(gui: ScreenGui)
	local kit = Kit :: any
	local holder = new("Frame", { Name = "NextGoal", BackgroundTransparency = 1, ZIndex = 2 }, gui)
	local card = HudKit.Block(holder, {
		Name = "Card",
		Paint = { kit.C.Window, kit.C.Ink, kit.C.WindowStrip },
		Ink = kit.C.Ink,
		Strip = 3,
		Radius = 20,
		Lip = 6,
		Shine = 0,
	})
	card.Holder.Size = UDim2.fromScale(1, 1)
	local plate = HudKit.Block(holder, {
		Name = "Header",
		Paint = { kit.C.Header, kit.C.HeaderLip, kit.C.HeaderStrip },
		Ink = kit.C.Ink,
		Strip = 3,
		Radius = 14,
		Lip = 5,
		Shine = 0,
	})
	plate.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Holder.ZIndex = 8
	local title = kit.Text(plate.Face, "NEXT GOAL", 24, kit.C.White, { ZIndex = 12 })
	local well = new("Frame", {
		Name = "Well",
		BackgroundColor3 = kit.Paints.Blue[2],
		BorderSizePixel = 0,
		ZIndex = 6,
	}, card.Face)
	local wellCorner = new("UICorner", {}, well)
	local wellStroke = HudKit.Outline(well, kit.C.Ink, 3)
	local slot = new("Frame", {
		Name = "Slot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.86, 0.86),
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		BackgroundTransparency = 1,
		ZIndex = 7,
	}, well)
	local image = kit.Image(slot, "hud_rebirth", 10, { Size = UDim2.fromScale(1, 1), ZIndex = 7, Visible = false })
	local gainRow = new("Frame", { Name = "Gain", BackgroundTransparency = 1, ZIndex = 6 }, card.Face)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, gainRow)
	local gainIcon = kit.Image(gainRow, "cur_pin", 36, { LayoutOrder = 1, ZIndex = 7 })
	local gainText = kit.Text(gainRow, "", 28, kit.C.Value, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		ZIndex = 7,
	})
	local bar = kit.ProgressBar(card.Face, { Size = UDim2.fromOffset(250, 42) })
	bar.Holder.AnchorPoint = Vector2.new(0.5, 1)
	bar.Holder.ZIndex = 6

	HudKit.OnLayout(function(phone)
		local _, size = HudKit.Spot("Goal", phone)
		local h = (size :: UDim2).Y.Offset
		card:SetRadius(if phone then 12 else 20)
		card:SetLip(if phone then 4 else 6)
		plate.Holder.Size = UDim2.fromOffset(if phone then 96 else 160, if phone then 26 else 46)
		plate.Holder.Position = UDim2.new(0.5, 0, 0, if phone then 2 else 4)
		plate:SetRadius(if phone then 9 else 14)
		plate:SetLip(if phone then 3 else 5)
		title.TextSize = if phone then 13 else 24;
		(title:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = if phone then 1.5 else 2.5
		local pad = if phone then 8 else 14
		local top = if phone then 18 else 34
		local wellH = math.floor(h * (if phone then 0.4 else 0.48))
		well.Position = UDim2.fromOffset(pad, top)
		well.Size = UDim2.new(1, -pad * 2, 0, wellH)
		wellCorner.CornerRadius = UDim.new(0, if phone then 8 else 14)
		wellStroke.Thickness = if phone then 2 else 3
		local gainH = if phone then 18 else 36
		gainRow.Position = UDim2.fromOffset(0, top + wellH + (if phone then 3 else 8))
		gainRow.Size = UDim2.new(1, 0, 0, gainH)
		gainIcon.Size = UDim2.fromOffset(gainH, gainH)
		gainText.TextSize = if phone then 15 else 28
		local barH = if phone then 24 else 42
		bar.Holder.Size = UDim2.new(1, -pad * 2, 0, barH)
		bar.Holder.Position = UDim2.new(0.5, 0, 1, -(if phone then 10 else 16))
		bar.Label.TextSize = if phone then 12 else 20
	end)
	place(holder, "Goal")

	local Rebirth = require(Shared.Modules.Rebirth)
	local shownKey = ""
	local view: ViewportFrame? = nil
	local function refresh()
		local coins = tonumber(player:GetAttribute("Coins")) or 0
		local rebirths = player:GetAttribute("Rebirths")
		local kind, step, price =
			CoreLadder.Next(player:GetAttribute("BallStep"), player:GetAttribute("BagLevel"), rebirths)
		local key, gain = "Done", ""
		if kind then
			local have = if kind == "Ball"
				then CoreLadder.BallStep(player:GetAttribute("BallStep"))
				else CoreLadder.BagLevel(player:GetAttribute("BagLevel"))
			local more = Currency.Format(CoreLadder.Stat(kind, step) - CoreLadder.Stat(kind, have))
			key = kind .. step
			gain = if kind == "Ball" then "+" .. more .. " PINS" else "+" .. more .. " SPACE"
		elseif Rebirth.CoreOn() then
			key, gain, price = "Rebirth", "REBIRTH", Rebirth.CorePrice(rebirths)
		else
			price = 0
		end
		if key ~= shownKey then
			local first = shownKey == ""
			shownKey = key
			if view then
				view:Destroy()
				view = nil
			end
			image.Visible = false
			local ball = if kind == "Ball" then Balls.Get(CORE.Balls[step].Ball) else nil
			if ball then
				view = BallView.New(ball, { Spin = true, Locked = true, Margin = 1.05 })
				local v = view :: ViewportFrame
				v.Size = UDim2.fromScale(1, 1)
				v.ZIndex = 7
				v.Parent = slot
			elseif kind == "Bag" then
				image.Image = kit.Icon(("bag_%02d"):format(math.clamp(step, 1, 10)))
				image.ImageColor3 = Color3.fromRGB(28, 22, 48) -- (a silhouette until bought, like the shop)
				image.Visible = true
			else
				image.Image = kit.Icon(if key == "Rebirth" then "hud_rebirth" else "ui_tick")
				image.ImageColor3 = Color3.new(1, 1, 1)
				image.Visible = true
			end
			gainIcon.Visible = kind == "Ball"
			if not first then
				kit.Pulse(holder, 1.06, 0.24)
			end
		end
		gainText.Text = if key == "Done" then "ALL BOUGHT!" else gain
		gainText.TextColor3 = if key == "Rebirth" then kit.C.Header else kit.C.Value
		local ready = price > 0 and Currency.CanAfford(coins, price)
		bar:Set(
			math.min(coins, price),
			math.max(price, 1),
			if key == "Done"
				then "DONE!"
				elseif ready then "GO TO SHOP!"
				else Currency.Format(coins) .. "/" .. Currency.Format(price)
		)
		bar.BarFill.BackgroundColor3 = if ready then kit.C.Header else kit.Paints.Green[1]
		card:SetGlow(if ready then kit.C.Header else nil)
	end
	for _, attribute in { "Coins", "BallStep", "BagLevel", "Rebirths" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()

	-- Polish v2 U1: with no SHOP button on the HUD, tapping the card takes you to the BALLS & BAGS stall (the
	-- server moves you onto its pad, like the shop's GO TO SHOP), once there is something left to buy
	local tap = new("TextButton", {
		Name = "Tap",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, holder) :: TextButton
	local goRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CoreGoTo") :: RemoteEvent
	local lastGo = 0
	tap.Activated:Connect(function()
		if shownKey == "Done" or os.clock() - lastGo < CORE.Teleport.Cooldown then
			return
		end
		lastGo = os.clock()
		kit.Pulse(holder, 0.94, 0.15)
		Sfx.Play("Teleport", 1.1, 0.6)
		UiFx.Flash(WHITE, 0.25, 0.25)
		goRemote:FireServer("Shop")
	end)
end

function CoreHudController:Start()
	if not CORE.Enabled then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	local gui = new("ScreenGui", {
		Name = "CoreHUD",
		ResetOnSpawn = false,
		DisplayOrder = hud.DisplayOrder + 1,
		IgnoreGuiInset = hud.IgnoreGuiInset, -- same spots as the HUD (HudKit.Spot)
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)

	-- ===== Pin counter: the real pins of your last throw (big-number format), counts up as your pins fall =====
	local counter: Frame, counterText: TextLabel, counterNote: TextLabel
	if Kit then
		-- V2: no panel; the pin, a big white number and PINS DOWN under it, right on the sky (board B1)
		counter = new("Frame", { Name = "PinCounter", BackgroundTransparency = 1 }, gui)
		local pin = Kit.Image(counter, "cur_pin", 56, { AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
		counterText = Kit.Text(counter, "0", 48, WHITE, { TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
		counterNote = Kit.Text(counter, "PINS DOWN", 15, WHITE, { TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4 })
		counterNote.FontFace = Kit.Font
		HudKit.OnLayout(function(phone)
			local iconSize = if phone then 30 else 56
			pin.Size = UDim2.fromOffset(iconSize, iconSize)
			pin.Position = UDim2.new(0, if phone then 0 else 8, 0.5, 0)
			local left = iconSize + (if phone then 4 else 16)
			counterText.TextSize = if phone then 26 else 48
			counterText.Position = UDim2.fromOffset(left, if phone then 1 else 4)
			counterText.Size = UDim2.new(1, -left, 0, if phone then 28 else 50);
			(counterText:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = if phone then 2 else 3
			counterNote.TextSize = if phone then 9 else 15
			counterNote.Position = UDim2.fromOffset(left + 1, if phone then 29 else 54)
			counterNote.Size = UDim2.new(1, -left, 0, if phone then 11 else 18);
			(counterNote:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = if phone then 1.5 else 2
		end)
		place(counter, "PinCounter")
	else
		local counterFace
		counter, counterFace = plate(gui, "PinCounter", PANEL, 8)
		place(counter, "PinCounter")
		counterText = text(counterFace, "0", {
			Size = UDim2.new(1, -16, 0.68, 0),
			Position = UDim2.new(0, 8, 0.06, 0),
			TextColor3 = INK,
		})
		counterNote = text(counterFace, "Pins down", {
			Body = true,
			Size = UDim2.new(1, -16, 0.26, 0),
			Position = UDim2.new(0, 8, 0.7, 0),
			TextColor3 = MUTED,
		})
	end
	local NOTE_PINS = if Kit then "PINS DOWN" else "Pins down"
	local NOTE_FULL = if Kit then "BAG FULL!" else "Bag full, sell"
	local counterScale = new("UIScale", {}, counter)
	-- LUCKY! badge: a tilted gold tag on the counter's top-right corner, pops in on a high luck roll
	local lucky, luckyFace = plate(counter, "Lucky", GOLD, 8)
	lucky.AnchorPoint = Vector2.new(0.5, 0.5)
	lucky.Position = UDim2.fromScale(0.9, 0)
	lucky.Size = UDim2.new(0.42, 0, 0.5, 0)
	lucky.Rotation = 8
	lucky.ZIndex = 5
	lucky.Visible = false
	text(luckyFace, "LUCKY!", { Size = UDim2.new(1, -8, 0.84, 0), Position = UDim2.new(0, 4, 0.08, 0) })
	local luckyScale = new("UIScale", { Scale = 0 }, lucky)
	local luckyRun = 0
	local function popLucky()
		luckyRun += 1
		local run = luckyRun
		lucky.Visible = true
		luckyScale.Scale = 0
		TweenService:Create(luckyScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(0.75, function()
			if run == luckyRun then
				local out = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				TweenService:Create(luckyScale, out, { Scale = 0 }):Play()
			end
		end)
	end
	local counterRun = 0
	local function showCount(count: number, isLucky: boolean, full: boolean)
		counterRun += 1
		local run = counterRun
		counterNote.Text = if full then NOTE_FULL else NOTE_PINS
		if Kit then
			-- V2 (board M "Pins down"): pops 1 -> 1.35 -> 1 and flashes gold, 0.32 s overshoot
			counterText.TextColor3 = Kit.C.Header
			TweenService:Create(counterText, TweenInfo.new(0.32), { TextColor3 = WHITE }):Play()
			counterNote.TextColor3 = if full then Kit.Paints.Red[1] else WHITE
			counterScale.Scale = (if isLucky then 1.45 else 1.35)
				+ Config.CoreLoop.BallEffects.CounterGrow * BallSignature.Strength(count)
			TweenService:Create(counterScale, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		else
			SunKit.Recolor(counterText, if isLucky then K.SunLip else INK)
			counterNote.TextColor3 = if full then K.CoralLip else MUTED
			-- Addendum 5 D: bigger throws punch the counter harder
			counterScale.Scale = (if isLucky then 1.2 else 1.08)
				+ Config.CoreLoop.BallEffects.CounterGrow * BallSignature.Strength(count)
			TweenService:Create(counterScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		if isLucky then
			popLucky()
		end
		local began = os.clock()
		task.spawn(function()
			while run == counterRun do
				local t = math.min((os.clock() - began) / 0.15, 1)
				counterText.Text = Currency.Format(math.floor(count * t + 0.5))
				if t >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
		end)
	end

	-- ===== Bag bar + SELL =====
	local bag, bagFace, fill, bagText
	local bagBar: any = nil
	if Kit then
		-- V2: the bag (its look follows your bag level) over the left end of the kit's progress bar
		bag = new("Frame", { Name = "Bag", BackgroundTransparency = 1 }, gui)
		bagFace = bag
		bagBar = Kit.ProgressBar(bag, {})
		Kit.Image(bag, "bag_01", 92, { Name = "Icon", AnchorPoint = Vector2.new(0, 0.5), ZIndex = 10 })
		HudKit.OnLayout(function(phone)
			local _, size = HudKit.Spot("Bag", phone)
			local h = (size :: UDim2).Y.Offset
			local icon = bag:FindFirstChild("Icon") :: ImageLabel
			icon.Size = UDim2.fromOffset(math.floor(h * 1.3), math.floor(h * 1.3))
			icon.Position = UDim2.new(0, -math.floor(h * 0.2), 0.5, -math.floor(h * 0.08))
			local barH = math.floor(h * 0.62)
			local left = math.floor(h * 0.6)
			bagBar.Holder.AnchorPoint = Vector2.new(0, 0.5)
			bagBar.Holder.Position = UDim2.new(0, left, 0.5, 2)
			bagBar.Holder.Size = UDim2.new(1, -left, 0, barH)
			bagBar.Label.TextSize = if phone then 13 else 22
			bagBar.Label.Position = UDim2.fromOffset(math.floor(h * 0.2), 0)
			bagBar.Label.Size = UDim2.new(1, -math.floor(h * 0.2), 1, 0)
		end)
		place(bag, "Bag")
	else
		bag, bagFace = plate(gui, "Bag", PANEL, 6)
		place(bag, "Bag")
		new("ImageLabel", {
			Name = "Icon",
			BackgroundTransparency = 1,
			Image = AssetSlots.Image("StoreBag"),
			ScaleType = Enum.ScaleType.Fit,
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Size = UDim2.fromScale(0.9, 0.9),
			Position = UDim2.fromScale(0.02, 0.05),
		}, bagFace)
		local track = new("Frame", {
			Name = "Track",
			BackgroundColor3 = TRACK,
			BorderSizePixel = 0,
			Position = UDim2.new(0.26, 0, 0.22, 0),
			Size = UDim2.new(0.7, 0, 0.56, 0),
			ClipsDescendants = true,
		}, bagFace)
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, track)
		new("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, track)
		fill = new("Frame", {
			Name = "Fill",
			BackgroundColor3 = GREEN,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
		}, track)
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, fill)
		bagText = text(track, "0/0", { Size = UDim2.new(1, -8, 0.86, 0), Position = UDim2.new(0, 4, 0.07, 0) })
	end

	local sell, sellFace, sellButton
	if Kit then
		-- V2: a big green SELL with a coin (button XL, board B1); the face sinks on press
		sell = new("Frame", { Name = "Sell", BackgroundTransparency = 1 }, gui)
		sellFace = sell
		local block = HudKit.Block(sell, {
			Name = "Body",
			Paint = Kit.Paints.Green,
			Ink = Kit.C.Ink,
			Strip = 3,
			Radius = 22,
			Lip = 6,
			Shine = 0,
		})
		block.Holder.Size = UDim2.fromScale(1, 1)
		local row = new("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -6), ZIndex = 5 }, block.Face)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, row)
		local coin = Kit.Image(row, "cur_coin", 56, { LayoutOrder = 1, ZIndex = 6 })
		local word = Kit.Text(row, "SELL", 44, WHITE, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = 2,
			ZIndex = 6,
		})
		sellButton = new("TextButton", {
			Name = "Button",
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
			ZIndex = 9,
		}, sell)
		sellButton:SetAttribute("OwnPress", true)
		HudKit.Press(block, true, sellButton)
		HudKit.OnLayout(function(phone)
			block:SetRadius(if phone then 12 else 22)
			block:SetLip(if phone then 4 else 6)
			local iconSize = if phone then 28 else 56
			coin.Size = UDim2.fromOffset(iconSize, iconSize)
			word.TextSize = if phone then 24 else 44;
			(word:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = if phone then 2 else 3
		end)
		place(sell, "Sell")
	else
		sell, sellFace = plate(gui, "Sell", CORAL, 12)
		place(sell, "Sell")
		sellButton = new("TextButton", {
			Name = "Button",
			BackgroundTransparency = 1,
			Text = "",
			Size = UDim2.fromScale(1, 1),
		}, sellFace)
		text(sellFace, "Sell", { Size = UDim2.new(0.8, 0, 0.52, 0), Position = UDim2.new(0.1, 0, 0.24, 0) })
	end
	local sellScale = new("UIScale", {}, sell)

	-- V2: the one-time SELL HERE! bubble over SELL (board M "Hint bubble": a new player's bag at 80%+, bobs, gone
	-- after the first sell) and the NEXT GOAL card
	local hint: Frame? = nil
	local hintBubble: Frame? = nil
	local soldOnce = false
	if Kit then
		hint = new("Frame", { Name = "SellHint", BackgroundTransparency = 1, Visible = false, ZIndex = 20 }, gui)
		place(hint :: Frame, "Sell")
		local hintScale = new("UIScale", {}, hint)
		HudKit.OnLayout(function(phone)
			hintScale.Scale = if phone then 0.6 else 1
		end)
		hintBubble = Kit.Bubble(nil, { Text = "SELL HERE!", Side = "Bottom", Bob = false })
		local b = hintBubble :: Frame
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(0.5, 0, 0, -12)
		b.Parent = hint
		Kit.Bob(b, 8, 0.8)
		buildGoalCard(gui)
	end

	-- ===== BAG FULL, SELL prompt: a slightly tilted coral card =====
	local prompt, promptFace = plate(gui, "BagFull", CORAL, 4)
	place(prompt, "BagFull")
	prompt.Rotation = -2
	prompt.Visible = false
	text(promptFace, "Your bag is full", { Size = UDim2.new(1, -20, 0.6, 0), Position = UDim2.new(0, 10, 0.08, 0) })
	text(promptFace, "Tap Sell to cash it in", {
		Size = UDim2.new(1, -20, 0.26, 0),
		Position = UDim2.new(0, 10, 0.68, 0),
		Body = true,
		TextColor3 = Color3.fromRGB(255, 240, 214),
	})

	-- ===== Pointers: a beam from you to a pad and a bobbing marker over it (sell station, and the shop for the guide) =====
	-- Addendum 6 Stage 3: the zone you stand in (its own sell pad, shop and gates)
	local function zoneNow(): number
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return if root then CoreLadder.ZoneAt(root.Position) else 1
	end
	local function pointer(name: string, model: string, color: Color3, words: string): (boolean) -> ()
		-- (Addendum 6 Stage 3: the station in the zone you're in, looked up again when you change zone)
		local pad: BasePart? = nil
		local beacon: Attachment? = nil
		local beaconZone = 0
		local function find()
			local zone = zoneNow()
			if zone == beaconZone and beacon and beacon.Parent then
				return
			end
			local folder = Workspace:FindFirstChild(CoreLadder.ZoneFolder(zone))
			local station = folder and folder:FindFirstChild(model)
			pad = station and station:FindFirstChild("Pad") :: BasePart?
			beacon = pad and pad:FindFirstChild("Beacon") :: Attachment?
			if beacon then
				beaconZone = zone
			end
		end
		find()
		local beam: Beam? = nil
		local from: Attachment? = nil
		local marker = new("BillboardGui", {
			Name = name .. "Marker",
			Size = UDim2.fromOffset(150, 70),
			StudsOffset = Vector3.new(0, 14, 0),
			AlwaysOnTop = true,
			LightInfluence = 0,
			Enabled = false,
			Adornee = pad,
		}, gui)
		local markerPlate, markerFace = plate(marker, "Plate", color, 10)
		markerPlate.Size = UDim2.new(1, -8, 0, 44)
		markerPlate.Position = UDim2.fromOffset(4, 0)
		text(markerFace, words, { Size = UDim2.new(1, -12, 0.8, 0), Position = UDim2.new(0, 6, 0.1, 0) })
		text(marker, "▼", {
			Size = UDim2.fromOffset(30, 22),
			Position = UDim2.new(0.5, -15, 0, 46),
			TextColor3 = color,
		})
		return function(on: boolean)
			if on then
				find()
				marker.Adornee = pad
			end
			marker.Enabled = on
			marker.StudsOffset = Vector3.new(0, 14 + math.sin(os.clock() * 3) * 0.8, 0)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if on and root and beacon then
				if not from or from.Parent ~= root then
					from = new("Attachment", { Name = name, Position = Vector3.new(0, -2.4, 0) }, root)
				end
				if not beam then
					beam = new("Beam", {
						Name = name,
						Color = ColorSequence.new(color),
						Width0 = 0.9,
						Width1 = 0.9,
						FaceCamera = true,
						LightEmission = 0.2,
						Transparency = NumberSequence.new(0.15),
						Segments = 1,
					}, gui)
				end
				local b = beam :: Beam
				b.Attachment0 = from
				b.Attachment1 = beacon
				b.Parent = Workspace
				b.Enabled = true
			elseif beam then
				beam.Enabled = false
			end
		end
	end
	local sellGuide = pointer("SellGuide", "SellStation", GREEN, "Sell here")
	local shopGuide = pointer("ShopGuide", "BallShop", CORE.Shop.Color, "Shop")
	local guideUntil = 0 -- the SELL button turns the sell pointer on for a while

	-- ===== First 30 seconds (Stage 3): Throw > Sell > Buy until ball 2 is bought =====
	-- One card under the pin counter (in the BAG FULL spot; that card waits while this one is up). The step comes from
	-- what you have: not enough in the bag yet = throw, enough to buy once sold = sell, enough coins = buy.
	local GUIDE = CORE.Guide
	local firstBall = CORE.Balls[2]
	local tutor, tutorFace = plate(gui, "Guide", PANEL, 6)
	place(tutor, "BagFull")
	tutor.Visible = false
	local stepLabels = {}
	for i, word in { "Throw", "Sell", "Buy" } do
		stepLabels[i] = text(tutorFace, word, {
			Size = UDim2.new(0.28, 0, 0.5, 0),
			Position = UDim2.new(0.04 + (i - 1) * 0.32, 0, 0.05, 0),
		})
		if i < 3 then
			text(tutorFace, "›", {
				Size = UDim2.new(0.04, 0, 0.5, 0),
				Position = UDim2.new(0.32 + (i - 1) * 0.32, 0, 0.05, 0),
				TextColor3 = MUTED,
			})
		end
	end
	local tutorLine = text(tutorFace, "", {
		Body = true,
		Size = UDim2.new(1, -20, 0.32, 0),
		Position = UDim2.new(0, 10, 0.6, 0),
		TextColor3 = INK,
	})
	local ballsButton: GuiObject? = nil
	task.spawn(function()
		local ballsUi = playerGui:WaitForChild("BallsUI", 30)
		ballsButton = ballsUi and ballsUi:WaitForChild("Menu", 10):WaitForChild("BallsButton", 10) :: GuiObject?
	end)
	local ballsScale: UIScale? = nil
	local tutorStep = 0
	local tutorDoneAt: number? = nil
	local tutorWasOn = false
	local function guideStep(): number
		if
			not GUIDE.Enabled
			or (tonumber(player:GetAttribute("BallStep")) or 1) >= 2
			or (tonumber(player:GetAttribute("Rebirths")) or 0) > 0 -- (step C: a rebirthed player knows the way)
		then
			return 0
		end
		local coins = player:GetAttribute("Coins") or 0
		local amount = player:GetAttribute("Bag") or 0
		local size = player:GetAttribute("BagSize") or CORE.BagSizes[1]
		-- (Addendum 6: the bag holds pins; what they sell for = pins x PinValue x the coin multiplier)
		local worth = amount * CoreLadder.ZoneValue(zoneNow()) * (tonumber(player:GetAttribute("CoinMultiplier")) or 1)
		if coins >= firstBall.Price then
			return 3
		elseif amount > 0 and (amount >= size or coins + worth >= firstBall.Price) then
			return 2
		end
		return 1
	end
	local function showTutor(step: number)
		if step == tutorStep then
			return
		end
		tutorStep = step
		for i, label in stepLabels do
			SunKit.Recolor(label, if i == step then CORAL elseif i < step then GREEN else K.CreamLip)
		end
		tutorLine.Text = if step == 1
			then "Hold Throw to bowl"
			elseif step == 2 then "That's enough. Tap Sell"
			else ("%s coins. Buy a new ball at the shop"):format(Currency.Format(firstBall.Price)) -- (A6 2.3: its name stays hidden until bought)
		if step > 1 then
			Sfx.Play("Click")
			UiFx.Pop(tutor, 1.1, 0.18)
		end
	end

	-- SELL: teleports you onto the sell pad (the server moves you; the pad sells the bag)
	local goRemote = remotes:WaitForChild("CoreGoTo") :: RemoteEvent
	local lastGo = 0
	sellButton.Activated:Connect(function()
		Sfx.Play("Click")
		sellScale.Scale = 0.92
		TweenService:Create(sellScale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if os.clock() - lastGo < CORE.Teleport.Cooldown then
			return
		end
		lastGo = os.clock()
		goRemote:FireServer("Sell")
		Sfx.Play("Teleport", 1.1, 0.6)
		UiFx.Flash(WHITE, 0.25, 0.25)
		guideUntil = os.clock() + 4 -- (the beam shows for a moment in case the teleport was refused)
	end)

	-- Bag numbers from the server
	local lastBag = 0
	local function refreshBag()
		local amount = player:GetAttribute("Bag") or 0
		local size = math.max(player:GetAttribute("BagSize") or CORE.BagSizes[1], 1)
		local share = math.clamp(amount / size, 0, 1)
		if bagBar then
			-- V2: green, orange from 80%, red FULL! (board A progress bar); the bag icon follows your bag level
			bagBar:Set(amount, size, if share >= 1 then "FULL!" else Currency.Format(amount) .. "/" .. Currency.Format(size) .. " PINS", amount > lastBag)
			local icon = bag:FindFirstChild("Icon") :: ImageLabel
			icon.Image = (Kit :: any).Icon(("bag_%02d"):format(math.clamp(CoreLadder.BagLevel(player:GetAttribute("BagLevel")), 1, 10)))
		else
			TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(share, 1) }):Play()
			fill.BackgroundColor3 = if share >= 1 then CORAL else GREEN
			bagText.Text = Currency.Format(amount) .. "/" .. Currency.Format(size)
		end
		if amount > lastBag then
			UiFx.Pop(bag, 1.04, 0.12)
		end
		if share < 1 and counterNote.Text == NOTE_FULL then
			counterNote.Text = NOTE_PINS
			counterNote.TextColor3 = if Kit then WHITE else MUTED
		end
		lastBag = amount
	end
	for _, key in { "Bag", "BagSize", "BagLevel" } do
		player:GetAttributeChangedSignal(key):Connect(refreshBag)
	end
	refreshBag()

	-- Addendum 5 F: what a throw put in the bag flies as a gold "+25" from the pin counter down into the bag icon,
	-- and the bag pops when it lands (simulator gains). At most Config.CoreLoop.Gains.Max in the air at once.
	local GAINS = CORE.Gains
	local bagIcon = bagFace:FindFirstChild("Icon") :: ImageLabel
	local flying = 0
	local function flyGain(paid: number, isLucky: boolean)
		if not GAINS or not GAINS.Enabled or paid <= 0 or flying >= GAINS.Max then
			return
		end
		flying += 1
		local phone = HudKit.Phone()
		local base = gui.AbsolutePosition
		local fit = HudKit.LayerScale(gui) -- (screen pixels -> this layer's, when V2 shrinks it)
		local from = (counter.AbsolutePosition
			+ Vector2.new(counter.AbsoluteSize.X / 2, counter.AbsoluteSize.Y + 6)
			- base) / fit
		local to = (bagIcon.AbsolutePosition + bagIcon.AbsoluteSize / 2 - base) / fit
		local tag = text(gui, "+" .. Currency.Format(paid), {
			Name = "Gain",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = if phone then UDim2.fromOffset(70, 22) else UDim2.fromOffset(120, 36),
			Position = UDim2.fromOffset(from.X + math.random(-14, 14), from.Y),
			TextColor3 = if isLucky then GOLD else WHITE,
			Stroke = if phone then 2 else 3,
			ZIndex = 8,
		})
		local scale = new("UIScale", { Scale = 0 }, tag)
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = if isLucky then 1.25 else 1 })
			:Play()
		task.delay(0.22, function()
			-- (Polish v2 D2: into the bag on a curve bowed to a random side, GAINS.Bow; 0 = the old straight line)
			local start = Vector2.new(tag.Position.X.Offset, tag.Position.Y.Offset)
			local line = to - start
			local side = if line.Magnitude > 1 then Vector2.new(-line.Y, line.X).Unit else Vector2.zero
			local bend = start:Lerp(to, 0.45) + side * line.Magnitude * (GAINS.Bow or 0) * (if math.random() < 0.5 then -1 else 1)
			local spin = math.random(-12, 12)
			local progress = Instance.new("NumberValue")
			progress.Changed:Connect(function(a: number)
				local at = start:Lerp(bend, a):Lerp(bend:Lerp(to, a), a)
				tag.Position = UDim2.fromOffset(at.X, at.Y)
				tag.Rotation = spin * a
			end)
			tag.Destroying:Connect(function()
				progress:Destroy()
			end)
			local home =
				TweenService:Create(progress, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 })
			TweenService:Create(scale, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Scale = 0.45,
			}):Play()
			home:Play()
			home.Completed:Wait()
			flying -= 1
			tag:Destroy()
			UiFx.Pop(bag, 1.08, 0.12)
			UiFx.Pop(bagIcon, 1.3, 0.16)
		end)
	end

	-- Your own throws: the counter
	remotes:WaitForChild("ThrowResult").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or not data.Core or data.UserId ~= player.UserId then
			return
		end
		-- (+ the swing's Lead: the ball leaves your hand at the release, Polish v2 D2)
		task.delay((data.RollTime or 0) + ThrowPose.Lead(player.Character), function()
			showCount(data.Count or 0, data.Lucky == true, data.BagFull == true)
			flyGain(tonumber(data.Paid) or 0, data.Lucky == true)
		end)
	end)

	-- Sold at the station: coins fly up from the bag
	remotes:WaitForChild("CoreSold").OnClientEvent:Connect(function(amount, multiplier, _sources)
		guideUntil = 0
		soldOnce = true
		Sfx.Play("Coin", 1, 1.4)
		Sfx.Play("SpinWin", 1.2, 0.6)
		UiFx.Flash(GREEN, 0.15, 0.25)
		-- A green tag with the amount rises in the middle, above THROW (the left column is full of buttons)
		local phone = HudKit.Phone()
		local pop, popFace = plate(gui, "SoldPop", GREEN, 8)
		pop.AnchorPoint = Vector2.new(0.5, 1)
		pop.Size = if phone then UDim2.fromOffset(150, 40) else UDim2.fromOffset(230, 60)
		pop.Position = UDim2.new(0.5, 0, 1, if phone then -110 else -170)
		pop.Rotation = -3
		pop.ZIndex = 5
		new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = AssetSlots.Image("HudCoin"),
			ScaleType = Enum.ScaleType.Fit,
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.04, 0.1),
		}, popFace)
		text(popFace, "+" .. Currency.Format(amount), {
			Size = UDim2.new(0.66, 0, 0.7, 0),
			Position = UDim2.new(0.3, 0, 0.15, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		-- Addendum 6 1.1: the coin multiplier this sell used (every source, MultiplierService.GetCoinMultiplier), as a
		-- gold tag on the pop's corner, on every sell (x1 too, so it is clear nothing boosted it)
		if type(multiplier) == "number" then
			local tag, tagFace = plate(pop, "BoostTag", if multiplier > 1 then GOLD else K.CreamLip, 6)
			tag.AnchorPoint = Vector2.new(0.5, 0.5)
			tag.Position = UDim2.fromScale(0.92, 0.02)
			tag.Size = UDim2.fromScale(0.5, 0.52)
			tag.Rotation = 8
			tag.ZIndex = 6
			text(tagFace, Currency.FormatMultiplier(multiplier) .. " BOOST", {
				Size = UDim2.new(1, -8, 0.8, 0),
				Position = UDim2.new(0, 4, 0.1, 0),
			})
		end
		UiFx.Pop(pop, 1.2, 0.18)
		TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quint), {
			Position = pop.Position + UDim2.fromOffset(0, -60),
		}):Play()
		task.delay(0.8, function()
			for _, object in pop:GetDescendants() do
				local goal = if object:IsA("TextLabel")
					then { TextTransparency = 1 }
					elseif object:IsA("ImageLabel") then { ImageTransparency = 1, BackgroundTransparency = 1 }
					elseif object:IsA("Frame") then { BackgroundTransparency = 1 }
					elseif object:IsA("UIStroke") then { Transparency = 1 }
					else nil
				if goal then
					TweenService:Create(object, TweenInfo.new(0.35), goal):Play()
				end
			end
		end)
		task.delay(1.3, function()
			pop:Destroy()
		end)
	end)

	-- Every frame: the prompt and the guides
	local wasFull = false
	RunService.RenderStepped:Connect(function()
		local amount = player:GetAttribute("Bag") or 0
		local size = player:GetAttribute("BagSize") or CORE.BagSizes[1]
		local full = amount >= size
		if full and not wasFull then
			Sfx.Play("Error", 1, 0.6)
			UiFx.Pop(prompt, 1.15, 0.2)
		end
		wasFull = full
		local step = guideStep()
		if step > 0 then
			tutorWasOn = true
			tutorDoneAt = nil
			showTutor(step)
		elseif tutorWasOn and not tutorDoneAt then
			-- ball 2 bought: the card says so for a moment, then goes for good
			tutorDoneAt = os.clock()
			tutorStep = 4
			for _, label in stepLabels do
				SunKit.Recolor(label, GREEN)
			end
			tutorLine.Text = "That's it. Keep throwing for the next one"
			UiFx.Pop(tutor, 1.12, 0.2)
		end
		-- (V2: no banner; the SELL HERE! bubble, the bouncing SELL / SHOP and the beams do the guiding)
		tutor.Visible = not Kit and (step > 0 or (tutorDoneAt ~= nil and os.clock() - tutorDoneAt < GUIDE.DoneSeconds))
		if tutor.Visible then
			tutor.Rotation = -1.5
		end
		prompt.Visible = full and not tutor.Visible and not Kit
		if hint then
			-- a new player only (before ball 2, no rebirths), until they sell once
			local want = not soldOnce
				and amount / math.max(size, 1) >= 0.8
				and (tonumber(player:GetAttribute("BallStep")) or 1) < 2
				and (tonumber(player:GetAttribute("Rebirths")) or 0) == 0
			if want and not hint.Visible then
				hint.Visible = true
				local s = (Kit :: any).ScaleOf(hintBubble :: Frame)
				s.Scale = 0.6;
				(Kit :: any).Tween(s, 0.3, "Over", { Scale = 1 })
			elseif not want and hint.Visible then
				hint.Visible = false
			end
		end
		if full then
			prompt.Rotation = -2 + math.sin(os.clock() * 4) * 1.2
		end
		-- Addendum 5 F: a full bag shakes (red fill, SELL bouncing below) until you sell
		bag.Rotation = if full then math.sin(os.clock() * 28) * 2.2 else 0
		sellScale.Scale = if full or step == 2 then 1 + math.abs(math.sin(os.clock() * 5)) * 0.06 else sellScale.Scale
		sellGuide((full or step == 2 or os.clock() < guideUntil) and amount > 0)
		shopGuide(step == 3)
		-- the BALLS button (the price list with GO TO SHOP) bounces while it's time to buy
		if ballsButton and not ballsScale then
			ballsScale = (ballsButton :: GuiObject):FindFirstChild("GuideScale") :: UIScale?
				or new("UIScale", { Name = "GuideScale" }, ballsButton)
		end
		if ballsScale then
			ballsScale.Scale = if step == 3 then 1 + math.abs(math.sin(os.clock() * 5)) * 0.12 else 1
		end
	end)

	-- Addendum 5 F: a red dot on the BALLS button while the shop has something you can pay for (next ball, next bag
	-- or the next pet slot), like the PETS and REBIRTH dots
	local function canBuySomething(): boolean
		local coins = player:GetAttribute("Coins") or 0
		local rebirths = player:GetAttribute("Rebirths") or 0
		local _, ballPrice = CoreLadder.NextBall(player:GetAttribute("BallStep"), rebirths)
		local bagLevel, bagPrice = CoreLadder.NextBag(player:GetAttribute("BagLevel"), rebirths)
		local slotPrice = Mascots.StatsOn() and Mascots.NextSlotPrice(player:GetAttribute("PetSlotsBought"))
		return (ballPrice > 0 and Currency.CanAfford(coins, ballPrice))
			or (bagLevel ~= nil and Currency.CanAfford(coins, bagPrice))
			or (slotPrice ~= nil and slotPrice ~= false and Currency.CanAfford(coins, slotPrice))
	end
	local function refreshDot()
		local holder = ballsButton and (ballsButton :: GuiObject):FindFirstChild("Kit")
		local dot = holder and holder:FindFirstChild("Dot") :: GuiObject?
		if not dot then
			return
		end
		local on = canBuySomething() and guideStep() == 0 -- (the guide card bounces the button itself)
		if on and not dot.Visible then
			local scale = dot:FindFirstChildOfClass("UIScale") or new("UIScale", {}, dot)
			scale.Scale = 0
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		dot.Visible = on
	end
	for _, key in { "Coins", "BallStep", "BagLevel", "PetSlotsBought", "Rebirths" } do
		player:GetAttributeChangedSignal(key):Connect(refreshDot)
	end
	task.delay(3, refreshDot) -- (the BALLS button is found a moment after start)

	-- ===== Addendum 6 Stage 3: the zone gates. Each gate's gatePrompt and sign say what it costs you (shut: the price,
	-- coral when you can't pay yet; open: Go) and a hold asks the server (CoreGate). A short note says how it went. =====
	local note, noteFace = plate(gui, "ZoneNote", PANEL, 6)
	note.AnchorPoint = Vector2.new(0.5, 0)
	note.Position = UDim2.new(0.5, 0, 0.16, 0)
	note.Size = UDim2.fromOffset(340, 56)
	note.Visible = false
	local noteText = text(noteFace, "", { Size = UDim2.new(1, -20, 0.8, 0), Position = UDim2.new(0, 10, 0.1, 0), TextColor3 = INK })
	local noteToken = 0
	local function showNote(words: string, color: Color3?)
		noteToken += 1
		local token = noteToken
		noteText.Text = words
		SunKit.Recolor(noteText, color or INK)
		note.Visible = true
		UiFx.Pop(note, 1.08, 0.18)
		task.delay(2.4, function()
			if token == noteToken then
				note.Visible = false
			end
		end)
	end
	local gateRemote = remotes:WaitForChild("CoreGate", 10) :: RemoteFunction?
	local prompts: { ProximityPrompt } = {}
	local function paintGates()
		local open = CoreLadder.ZonesOpen(player:GetAttribute("CoreZonesOpen"))
		local coins = player:GetAttribute("Coins") or 0
		local rebirths = player:GetAttribute("Rebirths")
		for _, gatePrompt in prompts do
			local target = gatePrompt:GetAttribute("Target") or 1
			local gate = gatePrompt:FindFirstAncestorOfClass("Model")
			local sub = gate and gate:FindFirstChild("Sub", true) :: TextLabel?
			-- a designed gate's padlock, chains and barrier (parts with GateLock) go once you've opened it
			if gate then
				for _, p in gate:GetDescendants() do
					if p:IsA("BasePart") and p:GetAttribute("GateLock") then
						p.LocalTransparencyModifier = if target <= open then 1 else 0
						p.CanCollide = false
					end
				end
			end
			if target <= open then
				gatePrompt.ActionText = "Go"
				if sub then
					sub.Text = ("Zone %d · open"):format(target)
				end
			else
				local price = CoreLadder.GatePrice(target, rebirths)
				local shut = target > open + 1
				gatePrompt.ActionText = if shut
					then ("Open zone %d first"):format(open + 1)
					else ("Open for %s"):format(Currency.Format(price))
				if sub then
					sub.Text = if shut then ("Zone %d · locked"):format(target) else ("%s coins"):format(Currency.Format(price))
					sub.TextColor3 = if not shut and Currency.CanAfford(coins, price) then GREEN else CORAL
				end
			end
		end
	end
	local busy = false
	local function hookPrompt(gatePrompt: ProximityPrompt)
		if table.find(prompts, gatePrompt) then
			return
		end
		table.insert(prompts, gatePrompt)
		gatePrompt.Triggered:Connect(function()
			if busy or not gateRemote then
				return
			end
			busy = true
			local target = gatePrompt:GetAttribute("Target") or 1
			local ok, result = pcall(function()
				return (gateRemote :: RemoteFunction):InvokeServer(target)
			end)
			busy = false
			if ok and type(result) == "table" and result.Ok then
				local info = CoreLadder.ZoneInfo(target)
				Sfx.Play(if result.Opened then "Cheer" else "Teleport", 1, 0.7)
				showNote(
					(if result.Opened then "%s is open!" else "Welcome to %s"):format(if info then info.Name else "zone " .. target),
					if result.Opened then GREEN else INK
				)
			else
				Sfx.Play("Error", 1, 0.6)
				showNote(if ok and type(result) == "table" and result.Error then result.Error else "Try again", CORAL)
			end
		end)
		paintGates()
	end
	task.spawn(function()
		for zone = 1, CoreLadder.ZoneCount() do
			local folder = Workspace:WaitForChild(CoreLadder.ZoneFolder(zone), 30)
			if not folder then
				continue
			end
			for _, name in { "GateNext", "GateBack" } do
				local gate = folder:WaitForChild(name, if (name == "GateNext" and zone < CoreLadder.ZoneCount()) or (name == "GateBack" and zone > 1) then 30 else 0.01)
				local gatePrompt = gate and gate:FindFirstChild("GatePrompt", true)
				if gatePrompt and gatePrompt:IsA("ProximityPrompt") then
					hookPrompt(gatePrompt)
				end
			end
		end
	end)
	for _, key in { "CoreZonesOpen", "Coins", "Rebirths" } do
		player:GetAttributeChangedSignal(key):Connect(paintGates)
	end

	gui.Parent = playerGui
end

return CoreHudController
