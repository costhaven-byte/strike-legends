-- Addendum 4 Stage 2: the ball and bag shop (Config.CoreLoop Balls / BagSizes / BagPrices, Shared.Modules.CoreLadder).
-- Addendum 5 A2: two independent ladders (buy the next ball or the next bag in any order) and the shop only sells at
-- the booth: standing on the blue circle opens it with BUY buttons. The HUD BALLS button opens the same window as a
-- price list (what exists, what's next, no buying) with a GO TO SHOP button that teleports you onto the circle.
-- Simulator shop look on the sunny kit (Modules/SunKit): rarity-coloured rows, 3D balls, chunky buy buttons that
-- squash and bounce, a coin pill that counts up, confetti on a buy.
-- The server (CoreLoopService, CoreBuy remote) checks the booth distance, the ladder and the coins; this only shows them.
-- Addendum 5 B1: a PET SLOTS row under the two lists buys the next pet equip slot (Config.PetStats.SlotPrices).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetSlots = require(Shared.AssetSlots)
local Balls = require(Shared.Modules.Balls)
local CoreLadder = require(Shared.Modules.CoreLadder)
local Currency = require(Shared.Modules.Currency)
local Mascots = require(Shared.Modules.Mascots)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local BallView = require(Modules.BallView)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local CORE = Config.CoreLoop
local player = Players.LocalPlayer

local CoreShopController = {}

-- The sunny look (Modules/SunKit, Addendum 4 Stage 3d): light window and cards with dark text, colour buttons
local SunKit = require(Modules.SunKit)
local K = SunKit.C
local INK = K.Ink
local PANEL = K.Cream
local CARD = K.Sand
local PAPER = K.Paper
local GREEN = K.Green
local GREY = K.Grey
local GOLD = K.Sun
local SKY = K.Sky
local CORAL = K.Red
local SOFT = K.Muted
local WHITE = K.White

local W, H = 780, 500 -- window size at 1080p (UIScale shrinks it on small screens)
local ROW = 66 -- list row height
local GAP = 8

local new = SunKit.New
local text = SunKit.Text

-- Rarity colours (Config.Rarities); bags borrow the ball ladder's rarity at the same step
local RARITY: { [string]: Color3 } = {}
for _, row in Config.Rarities do
	RARITY[row.Name] = row.Color
end
local function rarityOf(kind: string, step: number): string
	if kind == "PetSlot" then
		return "Epic" -- (purple, like the PETS button)
	end
	local entry = CORE.Balls[math.clamp(step, 1, #CORE.Balls)]
	return entry.Rarity or "Common"
end

-- A plate whose hard shadow is its own darker colour (the light panels' is a darker sand)
local function plate(parent: Instance, name: string, color: Color3, radius: number, shadow: number?): (Frame, Frame)
	local lip = if color == PANEL or color == CARD or color == PAPER then K.CreamLip else SunKit.Lip(color)
	return SunKit.Plate(parent, name, color, radius, shadow, lip)
end

-- Lighter top, darker bottom on a button face
local function shine(face: Frame)
	new("UIGradient", {
		Name = "Shine",
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
	}, face)
end

-- Squash on press, bounce back (Back easing), grow a hair on hover
local function juicy(button: GuiButton, target: GuiObject)
	local scale = target:FindFirstChild("Juice") :: UIScale? or new("UIScale", { Name = "Juice" }, target)
	local hovered = false
	local function to(value: number, style: Enum.EasingStyle?)
		TweenService:Create(scale, TweenInfo.new(0.14, style or Enum.EasingStyle.Back), { Scale = value }):Play()
	end
	button.MouseEnter:Connect(function()
		hovered = true
		to(1.05)
	end)
	button.MouseLeave:Connect(function()
		hovered = false
		to(1)
	end)
	button.MouseButton1Down:Connect(function()
		to(0.92, Enum.EasingStyle.Quad)
	end)
	button.MouseButton1Up:Connect(function()
		to(if hovered then 1.05 else 1)
	end)
end

function CoreShopController:Start()
	if not CORE.Enabled then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buyRemote = remotes:WaitForChild("CoreBuy") :: RemoteFunction
	local goRemote = remotes:WaitForChild("CoreGoTo") :: RemoteEvent

	local gui = new("ScreenGui", {
		Name = "CoreShopUI",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)
	-- Tap outside the window = close (it dims the game behind)
	local backdrop = new("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, gui)
	-- (the screen-fit scale sits on a holder; UiFx.Open/Close scale the window inside it, so the two don't fight)
	local fitHolder = new("Frame", {
		Name = "Shop",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.fromOffset(W, H),
	}, gui)
	local fitScale = new("UIScale", { Name = "Fit" }, fitHolder)
	local function fit()
		local view = Workspace.CurrentCamera.ViewportSize
		fitScale.Scale = math.min(view.X / (W + 40), view.Y / (H + 70), 1.25)
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()
	local window, face = plate(fitHolder, "Window", PANEL, 12, 6)
	window.Size = UDim2.fromScale(1, 1)
	window.Visible = false
	local inner = new("Frame", { Name = "Inner", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, face)

	-- Title tab: gold, tilted, a dark copy behind the word
	local titleHolder, titleFace = plate(inner, "Title", GOLD, 8, 4)
	titleHolder.Size = UDim2.fromOffset(200, 58)
	titleHolder.Position = UDim2.fromOffset(18, -30)
	titleHolder.Rotation = -3
	shine(titleFace)
	text(titleFace, "Shop", {
		Size = UDim2.new(1, -16, 0.84, 0),
		Position = UDim2.new(0, 8, 0.08, 3),
		TextColor3 = INK,
		ZIndex = 1,
	})
	text(titleFace, "Shop", {
		Size = UDim2.new(1, -16, 0.84, 0),
		Position = UDim2.new(0, 8, 0.08, 0),
		Stroke = 3,
		ZIndex = 2,
	})
	local closeHolder, closeFace = plate(inner, "Close", CORAL, 10, 4)
	closeHolder.Size = UDim2.fromOffset(52, 52)
	closeHolder.Position = UDim2.new(1, -32, 0, -22)
	shine(closeFace)
	text(closeFace, "X", { Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.19), Stroke = 3 })
	local closeButton = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, closeFace)
	juicy(closeButton, closeHolder)

	-- Coins pill (top right, under the X): coin icon + a number that counts up
	local coinHolder, coinFace = plate(inner, "Coins", PAPER, 18, 3)
	coinHolder.Size = UDim2.fromOffset(210, 44)
	coinHolder.Position = UDim2.new(1, -300, 0, 14)
	new("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = AssetSlots.Image("HudCoin"),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(-10, -2),
	}, coinFace)
	local coinText = text(coinFace, "0", {
		Size = UDim2.new(1, -52, 0.72, 0),
		Position = UDim2.new(0, 42, 0.14, 0),
		TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local shownCoins = player:GetAttribute("Coins") or 0
	local coinRun = 0
	local function countCoins()
		coinRun += 1
		local run = coinRun
		local from, to = tonumber(shownCoins) or 0, tonumber(player:GetAttribute("Coins")) or 0
		local began = os.clock()
		task.spawn(function()
			while run == coinRun do
				local t = math.min((os.clock() - began) / 0.35, 1)
				local eased = 1 - (1 - t) ^ 3
				shownCoins = from + (to - from) * eased
				coinText.Text = Currency.Format(math.floor(shownCoins + 0.5))
				if t >= 1 then
					shownCoins = to
					break
				end
				RunService.Heartbeat:Wait()
			end
		end)
	end

	-- Mode strip under the title: at the booth = "Tap Buy", away = price list + GO TO SHOP
	local strip = new("Frame", {
		Name = "Strip",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -330, 0, 44),
		Position = UDim2.fromOffset(24, 14),
	}, inner)
	local stripText = text(strip, "", {
		Body = true,
		Size = UDim2.new(1, 0, 0.62, 0),
		Position = UDim2.fromScale(0, 0.5),
		AnchorPoint = Vector2.new(0, 0.5),
		TextColor3 = SOFT,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	stripText.Position = UDim2.new(0, 214, 0.5, 0)
	stripText.Size = UDim2.new(1, -214, 0.62, 0)

	-- Two columns: BALLS (pins a throw) and BAGS (how many coins fit). Each is its own ladder.
	local function column(name: string, title: string, sub: string, x: number)
		local holder, colFace = plate(inner, name, CARD, 10, 4)
		holder.Size = UDim2.new(0.5, -34, 1, if Mascots.StatsOn() then -222 else -150) -- (B1: room for PET SLOTS)
		holder.Position = UDim2.new(x, if x == 0 then 24 else 10, 0, 72)
		text(colFace, title, {
			Size = UDim2.new(0.5, 0, 0, 30),
			Position = UDim2.fromOffset(14, 8),
			TextColor3 = INK,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		text(colFace, sub, {
			Body = true,
			Size = UDim2.new(0.5, -20, 0, 20),
			Position = UDim2.new(0.5, 6, 0, 14),
			TextColor3 = SOFT,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local list = new("ScrollingFrame", {
			Name = "List",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -12, 1, -50),
			Position = UDim2.fromOffset(6, 44),
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = K.CreamLip,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ClipsDescendants = true,
		}, colFace)
		new("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }, list)
		new("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 12),
		}, list)
		return list
	end
	local ballList = column("BallsColumn", "Balls", "pins every throw", 0)
	local bagList = column("BagsColumn", "Bags", "coins it holds", 0.5)

	-- One row: rarity stripe + icon, name, stat line, and on the right the state (USING / OWNED / BUY / price)
	type Row = {
		Kind: string,
		Step: number,
		Holder: Frame,
		Face: Frame,
		Stripe: Frame,
		Name: TextLabel,
		Line: TextLabel,
		Icon: Frame,
		View: ViewportFrame?,
		Badge: Frame,
		BadgeFace: Frame,
		BadgeText: TextLabel,
		Coin: ImageLabel,
		Button: TextButton,
		Lock: Frame,
		State: string?,
	}
	local rows: { [string]: { Row } } = { Ball = {}, Bag = {} }

	local function makeRow(list: ScrollingFrame, kind: string, step: number): Row
		local holder, rowFace = plate(list, kind .. step, PAPER, 10, 3)
		holder.LayoutOrder = step
		holder.Size = UDim2.new(1, 0, 0, ROW - 4)
		local color = RARITY[rarityOf(kind, step)] or GREY
		local stripe = new("Frame", {
			Name = "Stripe",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 64, 1, 0),
		}, rowFace)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, stripe)
		-- (square right edge so the stripe meets the row face)
		new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Size = UDim2.new(0, 12, 1, 0),
			Position = UDim2.new(1, -12, 0, 0),
		}, stripe)
		if rarityOf(kind, step) == "Mythic" then
			new("UIGradient", {
				Name = "Rainbow",
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 140)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 200, 60)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 200, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 90, 255)),
				}),
			}, stripe)
		end
		local icon = new("Frame", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(32, (ROW - 4) / 2),
			Size = UDim2.fromOffset(50, 50),
			ZIndex = 2,
		}, rowFace)
		local view: ViewportFrame? = nil
		if kind == "Ball" then
			local ball = Balls.Get(CORE.Balls[step].Ball)
			if ball then
				view = BallView.New(ball, { Spin = false, Margin = 1.0 })
				local v = view :: ViewportFrame
				v.Size = UDim2.fromScale(1.1, 1.1)
				v.AnchorPoint = Vector2.new(0.5, 0.5)
				v.Position = UDim2.fromScale(0.5, 0.5)
				v.ZIndex = 2
				v.Parent = icon
			end
		else
			new("ImageLabel", {
				Name = "Bag",
				BackgroundTransparency = 1,
				Image = AssetSlots.Image(if kind == "PetSlot" then "HudPaw" else "StoreBag"),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.92, 0.92),
				Position = UDim2.fromScale(0.04, 0.02),
				ZIndex = 2,
			}, icon)
			text(icon, tostring(step), {
				Name = "Number",
				Size = UDim2.fromScale(0.5, 0.44),
				Position = UDim2.fromScale(0.5, 0.56),
				ZIndex = 3,
				Stroke = 3,
			})
		end
		local name = text(rowFace, "", {
			Name = "Name",
			Size = UDim2.new(1, -196, 0, 26),
			Position = UDim2.fromOffset(74, 7),
			TextColor3 = INK,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local line = text(rowFace, "", {
			Name = "Line",
			Body = true,
			Size = UDim2.new(1, -196, 0, 20),
			Position = UDim2.fromOffset(74, 35),
			TextColor3 = SOFT,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		-- Right side: one badge plate that is a BUY button, a price tag, USING or OWNED
		local badge, badgeFace = plate(rowFace, "Badge", GREEN, 10, 3)
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Size = UDim2.fromOffset(112, 42)
		badge.Position = UDim2.new(1, -8, 0.5, -1)
		shine(badgeFace)
		local coin = new("ImageLabel", {
			Name = "Coin",
			BackgroundTransparency = 1,
			Image = AssetSlots.Image("HudCoin"),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.new(0, 6, 0.5, -13),
		}, badgeFace)
		local badgeText = text(badgeFace, "", {
			Size = UDim2.new(1, -40, 0.62, 0),
			Position = UDim2.new(0, 34, 0.19, 0),
		})
		local button = new("TextButton", {
			Name = "Buy",
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, badgeFace)
		juicy(button, badge)
		-- Locked rows (two or more steps ahead) get a light veil
		local lock = new("Frame", {
			Name = "Veil",
			BackgroundColor3 = PANEL,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Visible = false,
		}, rowFace)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, lock)
		local row: Row = {
			Kind = kind,
			Step = step,
			Holder = holder,
			Face = rowFace,
			Stripe = stripe,
			Name = name,
			Line = line,
			Icon = icon,
			View = view,
			Badge = badge,
			BadgeFace = badgeFace,
			BadgeText = badgeText,
			Coin = coin,
			Button = button,
			Lock = lock,
		}
		return row
	end
	for step = 1, #CORE.Balls do
		rows.Ball[step] = makeRow(ballList, "Ball", step)
	end
	for step = 1, #CORE.BagSizes do
		rows.Bag[step] = makeRow(bagList, "Bag", step)
	end
	-- Addendum 5 B1: one PET SLOTS row across the window, under the two lists (it always shows the next slot)
	local petRow: Row? = nil
	if Mascots.StatsOn() then
		local petHolder = new("Frame", {
			Name = "PetSlots",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -60, 0, ROW - 4),
			Position = UDim2.new(0, 30, 1, -142),
		}, inner)
		petRow = makeRow(petHolder :: any, "PetSlot", 1)
		rows.PetSlot = { petRow :: Row }
	end

	-- Footer: GO TO SHOP (price-list mode) or a short hint (at the booth)
	local goHolder, goFace = plate(inner, "GoToShop", SKY, 14, 5)
	goHolder.AnchorPoint = Vector2.new(0.5, 1)
	goHolder.Size = UDim2.fromOffset(300, 56)
	goHolder.Position = UDim2.new(0.5, 0, 1, -12)
	shine(goFace)
	text(goFace, "Go to shop", {
		Size = UDim2.new(1, -24, 0.66, 0),
		Position = UDim2.new(0, 12, 0.17, 0),
		Stroke = 3,
	})
	local goButton = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, goFace)
	juicy(goButton, goHolder)
	local hint = text(inner, "Balls and bags are separate. Buy either one first", {
		Body = true,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.new(1, -60, 0, 24),
		Position = UDim2.new(0.5, 0, 1, -26),
		TextColor3 = SOFT,
	})

	-- ===== Refresh =====
	local atShop = false -- standing on the booth's blue circle (only then the BUY buttons work)
	local busy = false
	local function paintBadge(row: Row, color: Color3, words: string, showCoin: boolean)
		SunKit.Paint(row.Badge, color, SunKit.Lip(color))
		row.BadgeText.Text = words
		row.Coin.Visible = showCoin
		row.BadgeText.Position = if showCoin then UDim2.new(0, 34, 0.19, 0) else UDim2.new(0, 8, 0.19, 0)
		row.BadgeText.Size = if showCoin then UDim2.new(1, -40, 0.62, 0) else UDim2.new(1, -16, 0.62, 0)
		SunKit.Recolor(row.BadgeText, if color == PAPER or color == CARD then INK else WHITE)
	end

	local function refresh()
		local ballStep = CoreLadder.BallStep(player:GetAttribute("BallStep"))
		local bagLevel = CoreLadder.BagLevel(player:GetAttribute("BagLevel"))
		local coins = player:GetAttribute("Coins") or 0
		for _, kind in { "Ball", "Bag" } do
			local have = if kind == "Ball" then ballStep else bagLevel
			local rebirths = player:GetAttribute("Rebirths") -- (step C: prices rise each rebirth)
			local buyStep, price = CoreLadder.Buyable(kind, ballStep, bagLevel, rebirths)
			for step, row in rows[kind] do
				if kind == "Ball" then
					local entry = CORE.Balls[step]
					row.Name.Text = entry.Name
					row.Line.Text = ("%s pins a throw"):format(Currency.Format(entry.Pins))
				else
					row.Name.Text = ("Bag %d"):format(step)
					row.Line.Text = ("Holds %s pins"):format(Currency.Format(CORE.BagSizes[step]))
				end
				local fullPrice = if kind == "Ball" then CoreLadder.BallPrice(step, rebirths) else CoreLadder.BagPrice(step, rebirths)
				local state
				if step == have then
					state = "Using"
					paintBadge(row, SKY, if kind == "Ball" then "Using" else "Yours", false)
				elseif step < have then
					state = "Owned"
					paintBadge(row, CARD, "Owned", false)
				elseif step == buyStep then
					local can = coins >= price
					if atShop then
						state = if can then "Buy" else "Saving"
						paintBadge(row, if can then GREEN else GREY, Currency.Format(price), true)
					else
						state = "Next"
						paintBadge(row, GOLD, Currency.Format(price), true)
					end
				else
					state = "Locked"
					paintBadge(row, CARD, Currency.Format(fullPrice), true)
				end
				row.State = state
				row.Lock.Visible = state == "Locked"
				-- the next one stands out: a coral outline and its ball turns
				local stroke = row.Face:FindFirstChildOfClass("UIStroke") :: UIStroke
				local isNext = state == "Buy" or state == "Saving" or state == "Next"
				stroke.Color = if isNext then K.Coral elseif state == "Using" then K.SkyLip else INK
				stroke.Thickness = if isNext or state == "Using" then 4 else 3
				row.Face.BackgroundColor3 = if state == "Using" then Color3.fromRGB(226, 243, 255) else PAPER
			end
		end
		if petRow then
			-- pet slots: start slots + bought (old saves' kept slots count as bought)
			local start = Config.Economy.Mascots.StartSlots
			local bought = math.max(player:GetAttribute("PetSlotsBought") or 0, (player:GetAttribute("PetSlotsKept") or 0) - start)
			local price = Mascots.NextSlotPrice(bought)
			local have = start + bought
			local number = petRow.Icon:FindFirstChild("Number") :: TextLabel?
			if number then
				number.Text = tostring(if price then have + 1 else have)
			end
			local state
			if not price then
				state = "Owned"
				petRow.Name.Text = "Pet slots"
				petRow.Line.Text = ("All %d slots bought: %d pets out at once"):format(have, have)
				paintBadge(petRow, CARD, "All yours", false)
			else
				petRow.Name.Text = ("Pet slot %d"):format(have + 1)
				petRow.Line.Text = ("One more pet out at once (%d now)"):format(have)
				local can = coins >= price
				if atShop then
					state = if can then "Buy" else "Saving"
					paintBadge(petRow, if can then GREEN else GREY, Currency.Format(price), true)
				else
					state = "Next"
					paintBadge(petRow, GOLD, Currency.Format(price), true)
				end
			end
			petRow.State = state
			local stroke = petRow.Face:FindFirstChildOfClass("UIStroke") :: UIStroke
			stroke.Color = if state ~= "Owned" then K.Coral else INK
			stroke.Thickness = if state ~= "Owned" then 4 else 3
		end
		if atShop then
			stripText.Text = "You're at the shop. Tap a price to buy"
			goHolder.Visible = false
			hint.Visible = true
		else
			stripText.Text = "Price list. You can only buy at the shop"
			goHolder.Visible = true
			hint.Visible = false
		end
	end

	-- Keeps the next row of each list in view
	local function scrollToNext()
		for kind, list in { Ball = ballList, Bag = bagList } do
			local have = if kind == "Ball"
				then CoreLadder.BallStep(player:GetAttribute("BallStep"))
				else CoreLadder.BagLevel(player:GetAttribute("BagLevel"))
			local top = math.max(have - 2, 0) * (ROW - 4 + GAP)
			list.CanvasPosition = Vector2.new(0, top)
		end
	end

	for _, key in { "BallStep", "BagLevel", "Coins", "PetSlotsBought", "PetSlotsKept" } do
		player:GetAttributeChangedSignal(key):Connect(function()
			if key == "Coins" then
				countCoins()
			end
			if window.Visible then
				refresh()
			end
		end)
	end

	local function shake(object: GuiObject)
		local x = object.Position
		for _, dx in { 8, -8, 5, -5, 0 } do
			object.Position = x + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		object.Position = x
	end

	local function flashText(row: Row, message: string)
		local old = row.BadgeText.Text
		row.BadgeText.Text = message
		task.delay(1.2, function()
			if row.BadgeText.Text == message then
				row.BadgeText.Text = old
				refresh()
			end
		end)
	end

	local function tryBuy(row: Row)
		if busy then
			return
		end
		local state = row.State
		if state == "Using" or state == "Owned" then
			return
		end
		if not atShop then
			-- price list: no buying here, nudge the GO TO SHOP button
			Sfx.Play("Error", 1, 0.5)
			task.spawn(shake, row.Badge)
			UiFx.Pop(goHolder, 1.15, 0.25)
			return
		end
		if state ~= "Buy" then
			Sfx.Play("Error", 1, 0.6)
			task.spawn(shake, row.Badge)
			if state == "Locked" then
				flashText(row, "Next first")
			end
			return
		end
		busy = true
		local ok, result = pcall(buyRemote.InvokeServer, buyRemote, row.Kind)
		busy = false
		if ok and type(result) == "table" and result.Ok then
			Sfx.Play("Coin", 1, 1.2)
			Sfx.Play("SpinWin", 1.1, 0.7)
			UiFx.Flash(GREEN, 0.12, 0.2)
			UiFx.Confetti(face, 26)
			refresh()
			UiFx.Pop(row.Holder, 1.12, 0.3)
			local nextRow = rows[row.Kind][row.Step + 1]
			if nextRow then
				task.delay(0.12, UiFx.Pop, nextRow.Badge, 1.25, 0.3)
			end
		else
			Sfx.Play("Error", 1, 0.6)
			task.spawn(shake, row.Badge)
			local message = if ok and type(result) == "table" then result.Error else nil
			if message then
				flashText(row, message)
			end
		end
	end
	for _, list in rows do
		for _, row in list do
			row.Button.Activated:Connect(function()
				tryBuy(row)
			end)
		end
	end

	-- Spin the next ball and turn the Mythic rainbow while the window is open
	RunService.RenderStepped:Connect(function(dt)
		if not window.Visible then
			return
		end
		for _, row in rows.Ball do
			local view = row.View
			local isNext = row.State == "Buy" or row.State == "Saving" or row.State == "Next"
			if view and isNext then
				local model = view:FindFirstChildWhichIsA("PVInstance")
				if model then
					BallView.Turn(model, CFrame.Angles(0, dt * 1.2, 0))
				end
			end
		end
		local spin = (os.clock() * 90) % 360
		for _, list in rows do
			local top = list[#list]
			local rainbow = top and top.Stripe:FindFirstChild("Rainbow") :: UIGradient?
			if rainbow then
				rainbow.Rotation = spin
			end
		end
	end)

	-- Open / close
	local open = false
	local function setOpen(on: boolean)
		if on == open then
			if on then
				refresh()
			end
			return
		end
		open = on
		backdrop.Visible = on
		if on then
			shownCoins = player:GetAttribute("Coins") or 0
			coinText.Text = Currency.Format(shownCoins)
			refresh()
			task.defer(scrollToNext) -- (after the lists have measured their rows)
			Sfx.Play("Click")
			UiFx.Open(window)
		else
			UiFx.Close(window)
		end
	end
	CoreShopController.SetOpen = setOpen
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	backdrop.Activated:Connect(function()
		setOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and open and input.KeyCode == Enum.KeyCode.Escape then
			setOpen(false)
		end
	end)

	-- GO TO SHOP: the server teleports you onto the blue circle; standing there turns the BUY buttons on
	local lastGo = 0
	goButton.Activated:Connect(function()
		if os.clock() - lastGo < CORE.Teleport.Cooldown then
			return
		end
		lastGo = os.clock()
		Sfx.Play("Teleport", 1.1, 0.6)
		UiFx.Flash(WHITE, 0.25, 0.25)
		goRemote:FireServer("Shop")
	end)

	-- The BALLS button opens the price list (the old Ball Book stays shut in the core loop)
	task.spawn(function()
		local ballsUi = playerGui:WaitForChild("BallsUI", 30)
		local button = ballsUi and ballsUi:WaitForChild("Menu", 10):WaitForChild("BallsButton", 10) :: GuiButton?
		if button then
			button.Activated:Connect(function()
				setOpen(not open)
			end)
		end
	end)

	-- Studio only: the playtest opens / closes the price list by setting the TestOpen attribute on CoreShopUI
	if RunService:IsStudio() then
		gui:GetAttributeChangedSignal("TestOpen"):Connect(function()
			setOpen(gui:GetAttribute("TestOpen") == true)
		end)
	end

	-- Standing on the booth's blue circle opens it with BUY buttons (once per visit; walking off closes it).
	-- An open price list switches to buying when you arrive (GO TO SHOP).
	task.spawn(function()
		while true do
			task.wait(0.2)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local here = false
			if root then
				local offset = root.Position - CORE.Shop.Position
				here = Vector2.new(offset.X, offset.Z).Magnitude <= CORE.Shop.Radius and offset.Y > -2 and offset.Y < 8
			end
			if here ~= atShop then
				atShop = here
				-- (not over the REBIRTH window: its GO TO SHOP brings you here to rebirth, step C)
				local rebirthWindow = playerGui:FindFirstChild("RebirthWindowUI")
				if here and rebirthWindow and rebirthWindow:GetAttribute("Open") then
					continue
				elseif here then
					if open then
						refresh()
						UiFx.Pop(window, 1.04, 0.2)
					else
						setOpen(true)
					end
				elseif open then
					setOpen(false)
				end
			end
		end
	end)

	gui.Parent = playerGui
end

return CoreShopController
