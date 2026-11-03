-- Addendum 4 Stage 2: the ball and bag shop (Config.CoreLoop Balls / BagSizes / BagPrices, Shared.Modules.CoreLadder).
-- Addendum 5 A2: two independent ladders and the shop only sells at the booth: standing on the blue circle opens it
-- with BUY buttons. The HUD BALLS button opens the same window as a price list (no buying) with a GO TO SHOP button
-- that teleports you onto the circle.
-- Simulator shop look on the sunny kit (Modules/SunKit): rarity-coloured rows, 3D balls, chunky buy buttons that
-- squash and bounce, a coin pill that counts up, confetti on a buy.
-- The server (CoreLoopService, CoreBuy / CoreEquip remotes; RebirthService, Rebirth remote) checks the booth
-- distance, the ladder and the coins; this only shows them.
-- Addendum 5 B1: a PET SLOTS row buys the next pet equip slot (Config.PetStats.SlotPrices); since Addendum 6 it sits
-- at the bottom of the Bags tab.
-- Addendum 6 Stage 2:
--   2.1 tabs (Config.CoreLoop.Shop.Tabs: Balls, Bags, Rebirth). A tab = one entry in PAGES below (Build + Refresh),
--       so Stage 8's Gamepasses tab is one more entry and one more Id in the Config list.
--   2.2 buy ANY ball / bag above your best you can pay for (Ladders.BuyAny); skipped ones say SKIPPED and are for
--       sale for the look; owned balls have EQUIP (look only, pins from the best ball); BUY BEST buys the highest
--       one you can pay for; the next one is highlighted (coral outline + NEXT chip, its silhouette turns).
--   2.3 every ball / bag you don't own is a black silhouette called "???" showing only what it adds and its price;
--       rows of zones you haven't opened are greyed with a lock. Buying plays a short reveal (RevealSeconds).
--   2.4 the Rebirth tab: rank now > next rank (Config.CoreLoop.Rebirth.Ranks), price, what resets / what you keep,
--       the boost, and a HOLD TO REBIRTH button (HoldSeconds). The HUD REBIRTH button opens this tab.
-- Addendum 6 Stage 8: the Gamepasses tab (Config.CoreLoop.Shop.Gamepasses = which Config.Monetization passes, in
--   order): a card per pass with its icon, words and a Robux BUY button (StoreBuy, works anywhere) or OWNED. A pass with
--   no Creator Hub ID yet is hidden in the live game. The small HUD PASSES button (HudKit spot "Passes") opens it.
-- UI overhaul V3 / V4 (Config.Ui.ShopV2): every tab opens the new window (Modules/ShopV2); this controller keeps the
--   stall check, GO TO SHOP and the remotes. The old window below is only used with ShopV2 = false.
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
local Rebirth = require(Shared.Modules.Rebirth)
local Store = require(Shared.Modules.Store)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local BallView = require(Modules.BallView)
local HudKit = require(Modules.HudKit)
local ShopV2 = require(Modules.ShopV2)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local Motion = require(Modules:WaitForChild("Motion"))

local CORE = Config.CoreLoop
local SHOP = CORE.Shop
local V2 = Config.Ui.ShopV2 == true
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
local BLACK = Color3.new(0, 0, 0)
local HIDDEN_STRIPE = Color3.fromRGB(58, 62, 76) -- an unowned row's stripe (its rarity colour pops in on the reveal)

local W, H = 820, 540 -- window size at 1080p (UIScale shrinks it on small screens)
local ROW = 70 -- list row height
local GAP = 8
local PAGE_TOP = 74 -- the pages start under the tabs
local FOOT = 78 -- footer height (Buy Best / Go to shop / hold to rebirth)

-- Gamepasses tab: the store kit icon per pass (AssetSlots.Images; same as StoreController's cards)
local PASS_ICONS = {
	DoubleCoins = "Pass2x",
	DoublePins = "Pass2xPins",
	VIP = "PassVip",
	AutoBowl = "PassAuto",
	Lucky = "PassLucky",
	SuperLucky = "PassSuperLucky",
	TripleHatch = "PassTriple",
	PetSlots = "PassPets",
}
local ROBUX_GLYPH = utf8.char(0xE002) -- Roblox's own Robux sign (every Roblox font has it)

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

-- A small rounded word tag ("BEST", "NEXT", "SKIPPED") that sizes to its text
local function chip(parent: Instance, name: string, order: number): (Frame, TextLabel)
	local frame = new("Frame", {
		Name = name,
		BackgroundColor3 = SKY,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		LayoutOrder = order,
		Visible = false,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0, 8) }, frame)
	new("UIStroke", { Color = INK, Thickness = 2 }, frame)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, frame)
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = SunKit.Display,
		TextSize = 15,
		TextColor3 = WHITE,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		Text = "",
	}, frame)
	new("UIStroke", { Color = INK, Thickness = 1.5 }, label)
	return frame, label
end

local function setChip(frame: Frame, label: TextLabel, words: string?, color: Color3?)
	frame.Visible = words ~= nil
	if words then
		label.Text = words
		frame.BackgroundColor3 = color or SKY
	end
end

function CoreShopController:Start()
	if not CORE.Enabled then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buyRemote = remotes:WaitForChild("CoreBuy") :: RemoteFunction
	local equipRemote = remotes:WaitForChild("CoreEquip") :: RemoteFunction
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
	titleHolder.Size = UDim2.fromOffset(170, 58)
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
	local closeButton =
		new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, closeFace)
	juicy(closeButton, closeHolder)

	-- Coins pill (top right, under the X): coin icon + a number that counts up
	local coinHolder, coinFace = plate(inner, "Coins", PAPER, 18, 3)
	coinHolder.Size = UDim2.fromOffset(190, 44)
	coinHolder.Position = UDim2.new(1, -244, 0, 16)
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

	-- ===== Tabs (2.1) =====
	local tabBar = new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -460, 0, 46),
		Position = UDim2.fromOffset(204, 14),
	}, inner)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, tabBar)
	local pagesFrame = new("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -48, 1, -PAGE_TOP - FOOT - 6),
		Position = UDim2.fromOffset(24, PAGE_TOP),
	}, inner)
	local footer = new("Frame", {
		Name = "Footer",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -48, 0, FOOT - 14),
		Position = UDim2.new(0, 24, 1, -FOOT + 2),
	}, inner)

	-- Footer pieces: a hint on the left, BUY BEST and GO TO SHOP on the right
	local hint = text(footer, "", {
		Body = true,
		Size = UDim2.new(1, -470, 0, 22),
		Position = UDim2.new(0, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		TextColor3 = SOFT,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local bestHolder, bestFace = plate(footer, "BuyBest", GREEN, 14, 5)
	bestHolder.AnchorPoint = Vector2.new(1, 0.5)
	bestHolder.Size = UDim2.fromOffset(250, 58)
	bestHolder.Position = UDim2.new(1, 0, 0.5, -2)
	shine(bestFace)
	local bestTitle = text(bestFace, "Buy best", {
		Size = UDim2.new(1, -20, 0.5, 0),
		Position = UDim2.new(0, 10, 0.06, 0),
		Stroke = 3,
	})
	local bestLine = text(bestFace, "", {
		Body = true,
		Size = UDim2.new(1, -20, 0.34, 0),
		Position = UDim2.new(0, 10, 0.58, 0),
		Stroke = 0,
	})
	local bestButton =
		new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, bestFace)
	juicy(bestButton, bestHolder)
	local goHolder, goFace = plate(footer, "GoToShop", SKY, 14, 5)
	goHolder.AnchorPoint = Vector2.new(1, 0.5)
	goHolder.Size = UDim2.fromOffset(200, 58)
	goHolder.Position = UDim2.new(1, -262, 0.5, -2)
	shine(goFace)
	text(goFace, "Go to shop", {
		Size = UDim2.new(1, -24, 0.62, 0),
		Position = UDim2.new(0, 12, 0.19, 0),
		Stroke = 3,
	})
	local goButton = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, goFace)
	juicy(goButton, goHolder)

	local atShop = false -- standing on the booth's blue circle (only then the BUY buttons work)
	local busy = false

	local function shake(object: GuiObject)
		local x = object.Position
		for _, dx in { 8, -8, 5, -5, 0 } do
			object.Position = x + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		object.Position = x
	end

	-- A page frame + a scrolling list (Balls / Bags)
	local function listPage(name: string): (Frame, ScrollingFrame, TextLabel)
		local page = new(
			"Frame",
			{ Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false },
			pagesFrame
		)
		local head = text(page, "", {
			Body = true,
			Size = UDim2.new(1, -8, 0, 22),
			Position = UDim2.fromOffset(4, 0),
			TextColor3 = INK,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local holder, colFace = plate(page, "ListCard", CARD, 10, 4)
		holder.Size = UDim2.new(1, 0, 1, -34)
		holder.Position = UDim2.fromOffset(0, 28)
		local list = new("ScrollingFrame", {
			Name = "List",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -12, 1, -12),
			Position = UDim2.fromOffset(6, 6),
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
		return page, list, head
	end

	-- ===== One ladder row: stripe + icon (a black silhouette until owned), name + chips, stat line, badge =====
	type Row = {
		Kind: string,
		Step: number,
		Holder: Frame,
		Face: Frame,
		Stripe: Frame,
		Name: TextLabel,
		ChipA: Frame,
		ChipAText: TextLabel,
		Line: TextLabel,
		Icon: Frame,
		View: ViewportFrame?,
		BagImage: ImageLabel?,
		Number: TextLabel?,
		Badge: Frame,
		BadgeFace: Frame,
		BadgeText: TextLabel,
		Coin: ImageLabel,
		Lock: ImageLabel,
		Button: TextButton,
		Veil: Frame,
		State: string?,
		Owned: boolean?,
		RevealUntil: number?,
	}
	local rows: { [string]: { Row } } = { Ball = {}, Bag = {} }

	local function makeRow(list: Instance, kind: string, step: number): Row
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
			Name = "Edge",
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
				Enabled = false,
			}, stripe)
		end
		local icon = new("Frame", {
			Name = "Icon",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(32, (ROW - 4) / 2),
			Size = UDim2.fromOffset(54, 54),
			ZIndex = 2,
		}, rowFace)
		new("UIScale", { Name = "Pop" }, icon)
		local view: ViewportFrame? = nil
		local bagImage: ImageLabel? = nil
		local number: TextLabel? = nil
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
			bagImage = new("ImageLabel", {
				Name = "Bag",
				BackgroundTransparency = 1,
				Image = AssetSlots.Image(if kind == "PetSlot" then "HudPaw" else "StoreBag"),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.92, 0.92),
				Position = UDim2.fromScale(0.04, 0.02),
				ZIndex = 2,
			}, icon)
			number = text(icon, tostring(step), {
				Name = "Number",
				Size = UDim2.fromScale(0.5, 0.44),
				Position = UDim2.fromScale(0.5, 0.56),
				ZIndex = 3,
				Stroke = 3,
			})
		end
		-- Name line: the name ("???" until owned), then a chip
		local nameLine = new("Frame", {
			Name = "NameLine",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -260, 0, 28),
			Position = UDim2.fromOffset(76, 7),
		}, rowFace)
		new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}, nameLine)
		local name = new("TextLabel", {
			Name = "Name",
			BackgroundTransparency = 1,
			FontFace = SunKit.Display,
			TextSize = 24,
			TextColor3 = INK,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 1,
			Text = "",
		}, nameLine)
		new("UIScale", { Name = "Pop" }, name)
		local chipA, chipAText = chip(nameLine, "ChipA", 2)
		local line = text(rowFace, "", {
			Name = "Line",
			Body = true,
			Size = UDim2.new(1, -260, 0, 20),
			Position = UDim2.fromOffset(76, 38),
			TextColor3 = SOFT,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		-- Right side: one badge plate (price to buy / EQUIP / EQUIPPED / BEST / OWNED)
		local badge, badgeFace = plate(rowFace, "Badge", GREEN, 10, 3)
		badge.AnchorPoint = Vector2.new(1, 0.5)
		badge.Size = UDim2.fromOffset(150, 46)
		badge.Position = UDim2.new(1, -8, 0.5, -1)
		shine(badgeFace)
		local coin = new("ImageLabel", {
			Name = "Coin",
			BackgroundTransparency = 1,
			Image = AssetSlots.Image("HudCoin"),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(0, 6, 0.5, -14),
		}, badgeFace)
		local lock = new("ImageLabel", {
			Name = "Lock",
			BackgroundTransparency = 1,
			Image = AssetSlots.Image("HudLock"),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.new(0, 7, 0.5, -13),
			Visible = false,
		}, badgeFace)
		local badgeText = text(badgeFace, "", {
			Size = UDim2.new(1, -44, 0.6, 0),
			Position = UDim2.new(0, 38, 0.2, 0),
		})
		local button = new("TextButton", {
			Name = "Buy",
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, badgeFace)
		juicy(button, badge)
		-- Locked zones get a light veil over the row
		local veil = new("Frame", {
			Name = "Veil",
			BackgroundColor3 = PANEL,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 4,
			Visible = false,
		}, rowFace)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, veil)
		return {
			Kind = kind,
			Step = step,
			Holder = holder,
			Face = rowFace,
			Stripe = stripe,
			Name = name,
			ChipA = chipA,
			ChipAText = chipAText,
			Line = line,
			Icon = icon,
			View = view,
			BagImage = bagImage,
			Number = number,
			Badge = badge,
			BadgeFace = badgeFace,
			BadgeText = badgeText,
			Coin = coin,
			Lock = lock,
			Button = button,
			Veil = veil,
		}
	end

	local function paintBadge(row: Row, color: Color3, words: string, mark: string?)
		SunKit.Paint(row.Badge, color, SunKit.Lip(color))
		row.BadgeText.Text = words
		row.Coin.Visible = mark == "Coin"
		row.Lock.Visible = mark == "Lock"
		row.BadgeText.Position = if mark then UDim2.new(0, 38, 0.2, 0) else UDim2.new(0, 8, 0.2, 0)
		row.BadgeText.Size = if mark then UDim2.new(1, -44, 0.6, 0) else UDim2.new(1, -16, 0.6, 0)
		SunKit.Recolor(row.BadgeText, if color == PAPER or color == CARD then INK else WHITE)
	end

	-- Silhouette (not owned) or the real colours (owned); skipped while a reveal plays on that row
	local function paintIcon(row: Row, owned: boolean)
		if row.RevealUntil and os.clock() < row.RevealUntil then
			return
		end
		local tint = if owned then WHITE else BLACK
		if row.View then
			row.View.ImageColor3 = tint
		end
		if row.BagImage then
			row.BagImage.ImageColor3 = tint
		end
		if row.Number then
			row.Number.Text = if owned then tostring(row.Step) else "?"
		end
		local color = if owned then RARITY[rarityOf(row.Kind, row.Step)] or GREY else HIDDEN_STRIPE
		row.Stripe.BackgroundColor3 = color
		local edge = row.Stripe:FindFirstChild("Edge") :: Frame?
		if edge then
			edge.BackgroundColor3 = color
		end
		local rainbow = row.Stripe:FindFirstChild("Rainbow") :: UIGradient?
		if rainbow then
			rainbow.Enabled = owned
		end
	end

	-- ===== Pages =====
	-- Each page: Build() once, Refresh() whenever something changes; Footer() sets the footer for it.
	type Page = { Id: string, Title: string, Color: Color3, Frame: Frame?, Refresh: () -> (), Footer: () -> () }
	local PAGES: { [string]: Page } = {}
	local currentTab = "Balls"

	local function ladderInfo(kind: string)
		local best = if kind == "Ball"
			then CoreLadder.BallStep(player:GetAttribute("BallStep"))
			else CoreLadder.BagLevel(player:GetAttribute("BagLevel"))
		local mask = player:GetAttribute(if kind == "Ball" then "CoreBallsOwned" else "CoreBagsOwned") or 1
		return best, mask, player:GetAttribute("Rebirths"), player:GetAttribute("CoreZonesOpen")
	end

	-- The ball step you throw for its look (CoreLook if owned, else your best)
	local function lookStep(): number
		local best, mask = ladderInfo("Ball")
		local look = math.floor(tonumber(player:GetAttribute("CoreLook")) or 0)
		return if look >= 1 and look <= #CORE.Balls and CoreLadder.Owns(mask, look) then look else best
	end

	local function refreshLadder(kind: string)
		local best, mask, rebirths, zones = ladderInfo(kind)
		local coins = player:GetAttribute("Coins") or 0
		local wearing = if kind == "Ball" then lookStep() else 0
		local bestStat = CoreLadder.Stat(kind, best)
		local unit = if kind == "Ball" then "pins a throw" else "pins room"
		for step, row in rows[kind] do
			local state = CoreLadder.State(kind, step, best, mask, zones)
			local owned = state == "Best" or state == "Owned"
			local price = CoreLadder.PriceOf(kind, step, rebirths)
			local can = Currency.CanAfford(coins, price)
			local stat = CoreLadder.Stat(kind, step)
			row.State = state
			row.Owned = owned
			paintIcon(row, owned)
			if not (row.RevealUntil and os.clock() < row.RevealUntil) then
				row.Name.Text = if owned then CoreLadder.Name(kind, step) else "???"
			end
			-- the stat line: what you have, or only what it would add
			if owned then
				row.Line.Text = if kind == "Ball"
					then ("%s pins a throw"):format(Currency.Format(stat))
					else ("Holds %s pins"):format(Currency.Format(stat))
				if state == "Owned" and kind == "Ball" then
					row.Line.Text ..= "  ·  look only"
				end
			elseif state == "Skipped" then
				row.Line.Text = if kind == "Ball"
					then "Look only. Your pins come from your best ball"
					else "For your collection. Your best bag stays"
			elseif state == "Locked" then
				row.Line.Text = ("Zone %d  ·  +%s %s"):format(
					CoreLadder.Zone(kind, step),
					Currency.Format(stat - bestStat),
					unit
				)
			else
				row.Line.Text = ("+%s %s"):format(Currency.Format(stat - bestStat), unit)
			end
			-- the chip after the name
			if state == "Best" then
				setChip(row.ChipA, row.ChipAText, "BEST", SKY)
			elseif state == "Next" then
				setChip(row.ChipA, row.ChipAText, "NEXT", K.Coral)
			elseif state == "Skipped" then
				setChip(row.ChipA, row.ChipAText, "SKIPPED", GREY)
			elseif state == "Locked" then
				setChip(row.ChipA, row.ChipAText, "LOCKED", GREY)
			else
				setChip(row.ChipA, row.ChipAText, nil)
			end
			-- the badge
			if owned and kind == "Ball" then
				if step == wearing then
					paintBadge(row, SKY, "Equipped")
				else
					paintBadge(row, PAPER, "Equip")
				end
			elseif owned then
				paintBadge(row, if state == "Best" then SKY else CARD, if state == "Best" then "Using" else "Owned")
			elseif state == "Locked" then
				paintBadge(row, CARD, Currency.Format(price), "Lock")
			elseif atShop then
				paintBadge(row, if can then GREEN else GREY, Currency.Format(price), "Coin")
			else
				paintBadge(row, if state == "Next" then GOLD else CARD, Currency.Format(price), "Coin")
			end
			row.Veil.Visible = state == "Locked"
			-- the next one stands out: a coral outline (its silhouette turns too)
			local stroke = row.Face:FindFirstChildOfClass("UIStroke") :: UIStroke
			stroke.Color = if state == "Next" then K.Coral elseif state == "Best" then K.SkyLip else INK
			stroke.Thickness = if state == "Next" or state == "Best" then 4 else 3
			row.Face.BackgroundColor3 = if state == "Best"
				then Color3.fromRGB(226, 243, 255)
				elseif state == "Next" then Color3.fromRGB(255, 240, 232)
				else PAPER
		end
	end

	-- Buy Best in the footer: what it would buy on this tab
	local function footerBuyBest(kind: string)
		local best, _, rebirths, zones = ladderInfo(kind)
		local coins = player:GetAttribute("Coins") or 0
		local step, price = CoreLadder.BuyBest(kind, best, coins, rebirths, zones)
		bestHolder.Visible = true
		bestTitle.Text = "Buy best"
		if step then
			local gain = CoreLadder.Stat(kind, step) - CoreLadder.Stat(kind, best)
			bestLine.Text = ("+%s pins%s  ·  %s"):format(
				Currency.Format(gain),
				if kind == "Ball" then " a throw" else " room",
				Currency.Format(price)
			)
			SunKit.Paint(bestHolder, if atShop then GREEN else GOLD, SunKit.Lip(if atShop then GREEN else GOLD))
		else
			local nextStep, nextPrice
			if kind == "Ball" then
				nextStep, nextPrice = CoreLadder.NextBall(best, rebirths)
			else
				nextStep, nextPrice = CoreLadder.NextBag(best, rebirths)
			end
			bestLine.Text = if nextStep
				then ("Next one: %s"):format(Currency.Format(nextPrice))
				else "You've got them all"
			SunKit.Paint(bestHolder, GREY, SunKit.Lip(GREY))
		end
		goHolder.Visible = not atShop
		hint.Text = if atShop then "Tap a price to buy any one you can pay for" else "Price list. Buy at the shop"
	end

	-- Balls
	do
		local page, list, head = listPage("BallsPage")
		for step = 1, #CORE.Balls do
			rows.Ball[step] = makeRow(list, "Ball", step)
		end
		PAGES.Balls = {
			Id = "Balls",
			Title = "Balls",
			Color = SKY,
			Frame = page,
			Refresh = function()
				refreshLadder("Ball")
				local best = ladderInfo("Ball")
				head.Text = ("Your best ball: %s pins a throw. Equip any ball you own for its look"):format(
					Currency.Format(CoreLadder.Stat("Ball", best))
				)
			end,
			Footer = function()
				footerBuyBest("Ball")
			end,
		}
	end

	-- Bags (+ the PET SLOTS row at the bottom)
	local petRow: Row? = nil
	do
		local page, list, head = listPage("BagsPage")
		for step = 1, #CORE.BagSizes do
			rows.Bag[step] = makeRow(list, "Bag", step)
		end
		if Mascots.StatsOn() then
			petRow = makeRow(list, "PetSlot", 1)
			local pr = petRow :: Row
			pr.Holder.LayoutOrder = 1000
			rows.PetSlot = { pr }
		end
		PAGES.Bags = {
			Id = "Bags",
			Title = "Bags",
			Color = GREEN,
			Frame = page,
			Refresh = function()
				refreshLadder("Bag")
				local best = ladderInfo("Bag")
				head.Text = ("Your best bag holds %s pins. Selling turns them into coins"):format(
					Currency.Format(CoreLadder.Stat("Bag", best))
				)
				if not petRow then
					return
				end
				local pr = petRow :: Row
				local coins = player:GetAttribute("Coins") or 0
				-- pet slots: start slots + bought (old saves' kept slots count as bought)
				local start = Config.Economy.Mascots.StartSlots
				local bought = math.max(
					player:GetAttribute("PetSlotsBought") or 0,
					(player:GetAttribute("PetSlotsKept") or 0) - start
				)
				local price = Mascots.NextSlotPrice(bought)
				local have = start + bought
				if pr.Number then
					pr.Number.Text = tostring(if price then have + 1 else have)
				end
				setChip(pr.ChipA, pr.ChipAText, nil)
				local state
				if not price then
					state = "Owned"
					pr.Name.Text = "Pet slots"
					pr.Line.Text = ("All %d slots bought: %d pets out at once"):format(have, have)
					paintBadge(pr, CARD, "All yours")
				else
					pr.Name.Text = ("Pet slot %d"):format(have + 1)
					pr.Line.Text = ("One more pet out at once (%d now)"):format(have)
					local can = coins >= price
					if atShop then
						state = if can then "Buy" else "Saving"
						paintBadge(pr, if can then GREEN else GREY, Currency.Format(price), "Coin")
					else
						state = "Next"
						paintBadge(pr, GOLD, Currency.Format(price), "Coin")
					end
				end
				pr.State = state
				local stroke = pr.Face:FindFirstChildOfClass("UIStroke") :: UIStroke
				stroke.Color = if state ~= "Owned" then K.Purple else INK
				stroke.Thickness = if state ~= "Owned" then 4 else 3
			end,
			Footer = function()
				footerBuyBest("Bag")
			end,
		}
	end

	-- Gamepasses (Stage 8): two cards to a row; BUY asks Roblox (StoreService), OWNED once you have it
	if Store.Active() and table.find(SHOP.Tabs or {}, "Gamepasses") then
		local page, list, head = listPage("GamepassesPage")
		local layout = list:FindFirstChildOfClass("UIListLayout") :: UIListLayout
		layout:Destroy()
		new("UIGridLayout", {
			CellSize = UDim2.new(0.5, -GAP / 2, 0, 112),
			CellPadding = UDim2.fromOffset(GAP, GAP),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, list)
		local storeBuy = remotes:WaitForChild("StoreBuy", 10) :: RemoteEvent?
		type PassCard = { Pass: any, Holder: Frame, Face: Frame, Badge: Frame, BadgeText: TextLabel, Note: TextLabel }
		local cards: { PassCard } = {}
		for index, id in SHOP.Gamepasses or {} do
			local pass = Store.Pass(id)
			if not Store.Ready(pass) then
				continue -- (no Creator Hub ID yet: hidden in the live game)
			end
			local holder, cardFace = plate(list, "Pass_" .. id, PAPER, 10, 3)
			holder.LayoutOrder = index
			local disc, discFace = plate(cardFace, "Icon", K.Sky, 12, 3)
			disc.Size = UDim2.fromOffset(78, 78)
			disc.Position = UDim2.fromOffset(10, 12)
			new("ImageLabel", {
				Name = "Image",
				BackgroundTransparency = 1,
				Image = AssetSlots.Image(PASS_ICONS[id] or "Pass2x"),
				ScaleType = Enum.ScaleType.Fit,
				Size = UDim2.fromScale(0.92, 0.92),
				Position = UDim2.fromScale(0.04, 0.04),
			}, discFace)
			text(cardFace, pass.Name, {
				Name = "PassName",
				Size = UDim2.new(1, -112, 0, 30),
				Position = UDim2.fromOffset(100, 8),
				TextColor3 = INK,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			text(cardFace, pass.Text, {
				Name = "Words",
				Body = true,
				TextScaled = false,
				TextSize = 15,
				TextWrapped = true,
				Size = UDim2.new(1, -112, 0, 36),
				Position = UDim2.fromOffset(100, 38),
				TextColor3 = SOFT,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			})
			-- Studio only: a pass not made in Creator Hub yet (BUY gives it free for the test)
			local note = text(cardFace, "NO ID YET", {
				Name = "Note",
				Size = UDim2.fromOffset(84, 18),
				Position = UDim2.new(1, -94, 0, 6),
				TextColor3 = CORAL,
				Stroke = 0,
				Visible = (tonumber(pass.PassId) or 0) <= 0,
			})
			local badge, badgeFace = plate(cardFace, "Buy", GREEN, 10, 4)
			badge.AnchorPoint = Vector2.new(1, 1)
			badge.Size = UDim2.fromOffset(120, 34)
			badge.Position = UDim2.new(1, -10, 1, -8)
			shine(badgeFace)
			local badgeText = text(badgeFace, "", {
				Size = UDim2.new(1, -16, 0.74, 0),
				Position = UDim2.new(0, 8, 0.13, 0),
				Stroke = 2,
			})
			local button =
				new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, badgeFace)
			juicy(button, badge)
			button.Activated:Connect(function()
				if Store.Owns(player, id) then
					return
				end
				if not storeBuy then
					Sfx.Play("Error", 1, 0.6)
					task.spawn(shake, badge)
					return
				end
				Sfx.Play("Click")
				storeBuy:FireServer(id)
			end)
			table.insert(cards, {
				Pass = pass,
				Holder = holder,
				Face = cardFace,
				Badge = badge,
				BadgeText = badgeText,
				Note = note,
			})
		end
		PAGES.Gamepasses = {
			Id = "Gamepasses",
			Title = "Passes",
			Color = K.Purple,
			Frame = page,
			Refresh = function()
				local have = 0
				for _, card in cards do
					local owned = Store.Owns(player, card.Pass.Id)
					if owned then
						have += 1
					end
					card.BadgeText.Text = if owned then "OWNED" else ROBUX_GLYPH .. " " .. tostring(card.Pass.Robux)
					card.BadgeText.FontFace = if owned then SunKit.Display else Font.fromEnum(Enum.Font.BuilderSansBold)
					SunKit.Paint(card.Badge, if owned then GREY else GREEN, SunKit.Lip(if owned then GREY else GREEN))
					local stroke = card.Face:FindFirstChildOfClass("UIStroke") :: UIStroke
					stroke.Color = if owned then K.Green else INK
				end
				head.Text = ("Game passes are yours forever, in every zone. You own %d of %d"):format(have, #cards)
			end,
			Footer = function()
				bestHolder.Visible = false
				goHolder.Visible = false
				hint.Text = "Buy passes with Robux from anywhere. Rebirths keep them"
			end,
		}
	end

	-- Rebirth (2.4)
	local rebirthRemote = remotes:WaitForChild("Rebirth") :: RemoteFunction
	local holdFrom: number? = nil
	do
		local page = new(
			"Frame",
			{ Name = "RebirthPage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false },
			pagesFrame
		)
		local function card(name: string, x: number, y: number, w: number, h: number, heading: string): Frame
			local holder, cardFace = plate(page, name, CARD, 12, 4)
			holder.Position = UDim2.new(x, if x == 0 then 0 else 6, 0, y)
			holder.Size = UDim2.new(w, -6, 0, h)
			text(cardFace, heading, {
				Name = "Heading",
				Body = true,
				Size = UDim2.new(1, -24, 0, 20),
				Position = UDim2.fromOffset(14, 8),
				TextColor3 = SOFT,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			return cardFace
		end
		-- rank now > next rank
		local rankCard = card("Rank", 0, 0, 0.5, 168, "YOUR RANK")
		local rankNow = text(rankCard, "", {
			Size = UDim2.new(1, -28, 0, 44),
			Position = UDim2.fromOffset(14, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			Stroke = 3,
		})
		text(rankCard, "NEXT RANK", {
			Body = true,
			Size = UDim2.new(1, -28, 0, 20),
			Position = UDim2.fromOffset(14, 82),
			TextColor3 = SOFT,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local rankNext = text(rankCard, "", {
			Size = UDim2.new(1, -28, 0, 40),
			Position = UDim2.fromOffset(14, 104),
			TextXAlignment = Enum.TextXAlignment.Left,
			Stroke = 3,
		})
		local rankDone = text(rankCard, "", {
			Body = true,
			Size = UDim2.new(1, -28, 0, 18),
			Position = UDim2.new(0, 14, 1, -24),
			TextColor3 = SOFT,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		-- the boost
		local boostCard = card("Boost", 0.5, 0, 0.5, 168, "YOU GET FOREVER")
		local boostCoins = text(boostCard, "", {
			Size = UDim2.new(1, -28, 0, 36),
			Position = UDim2.fromOffset(14, 32),
			TextColor3 = K.SunLip,
			TextXAlignment = Enum.TextXAlignment.Left,
			Stroke = 0,
		})
		local boostPins = text(boostCard, "", {
			Size = UDim2.new(1, -28, 0, 36),
			Position = UDim2.fromOffset(14, 72),
			TextColor3 = K.PurpleLip,
			TextXAlignment = Enum.TextXAlignment.Left,
			Stroke = 0,
		})
		local boostNow = text(boostCard, "", {
			Body = true,
			Size = UDim2.new(1, -28, 0, 40),
			Position = UDim2.fromOffset(14, 116),
			TextColor3 = SOFT,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
		})
		-- what goes, what stays
		local function wordRow(parent: Frame, words: { string }, color: Color3)
			local holder = new("Frame", {
				Name = "Words",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -28, 0, 26),
				Position = UDim2.fromOffset(14, 34),
			}, parent)
			new("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Wraps = true,
			}, holder)
			for i, word in words do
				local frame, label = chip(holder, word, i)
				setChip(frame, label, word, color)
				frame.Size = UDim2.fromOffset(0, 26)
				label.TextSize = 16
			end
		end
		local resetCard = card("Resets", 0, 178, 0.5, 74, "GOES BACK TO THE START")
		wordRow(resetCard, { "COINS", "BALLS", "BAGS", "ZONES", "PINS" }, CORAL)
		local keepCard = card("Keeps", 0.5, 178, 0.5, 74, "YOU KEEP")
		wordRow(keepCard, { "PETS", "GAMEPASSES", "RANK" }, GREEN)
		-- the price and a coins bar
		local priceCard = card("Price", 0, 262, 1, 80, "PRICE")
		local priceText = text(priceCard, "", {
			Size = UDim2.new(1, -28, 0, 28),
			Position = UDim2.fromOffset(14, 28),
			TextColor3 = INK,
			TextXAlignment = Enum.TextXAlignment.Left,
			RichText = true,
		})
		local track = new("Frame", {
			Name = "Track",
			BackgroundColor3 = K.Dim,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -28, 0, 10),
			Position = UDim2.new(0, 14, 1, -18),
		}, priceCard)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
		local fill = new("Frame", {
			Name = "Fill",
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
		}, track)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)

		-- Footer: the hold button (it fills while held) + GO TO SHOP away from the booth
		local holdHolder, holdFace = plate(footer, "HoldRebirth", GOLD, 14, 5)
		holdHolder.AnchorPoint = Vector2.new(1, 0.5)
		holdHolder.Size = UDim2.fromOffset(300, 58)
		holdHolder.Position = UDim2.new(1, 0, 0.5, -2)
		holdHolder.Visible = false
		shine(holdFace)
		local holdFill = new("Frame", {
			Name = "HoldFill",
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
			ZIndex = 2,
		}, holdFace)
		new("UICorner", { CornerRadius = UDim.new(0, 14) }, holdFill)
		local holdText = text(holdFace, "Hold to rebirth", {
			Size = UDim2.new(1, -24, 0.6, 0),
			Position = UDim2.new(0, 12, 0.2, 0),
			Stroke = 3,
			ZIndex = 3,
		})
		local holdButton = new(
			"TextButton",
			{ Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 },
			holdFace
		)

		local function info()
			local done = player:GetAttribute("Rebirths") or 0
			local price = Rebirth.CorePrice(done)
			return done, price, Currency.CanAfford(player:GetAttribute("Coins"), price)
		end
		local errorUntil = 0
		local function refreshRebirth()
			local done, price, can = info()
			local now, after = Rebirth.Rank(done), Rebirth.Rank(done + 1)
			rankNow.Text = now.Name
			SunKit.Recolor(rankNow, now.Color)
			rankNext.Text = after.Name
			SunKit.Recolor(rankNext, after.Color)
			rankDone.Text = ("Rebirths done: %d"):format(done)
			local coinsNow = Rebirth.CoreBonus(done, "Coins")
			local coinsAfter = Rebirth.CoreBonus(done + 1, "Coins")
			local pinsNow = Rebirth.CoreBonus(done, "Pins")
			local pinsAfter = Rebirth.CoreBonus(done + 1, "Pins")
			boostCoins.Text = ("+%d%% coins"):format(math.floor((coinsAfter - coinsNow) * 100 + 0.5))
			boostPins.Text = ("+%d%% pins a throw"):format(math.floor((pinsAfter - pinsNow) * 100 + 0.5))
			boostNow.Text = ("Rebirth boost now: coins +%d%% > +%d%%, pins +%d%% > +%d%%"):format(
				math.floor(coinsNow * 100 + 0.5),
				math.floor(coinsAfter * 100 + 0.5),
				math.floor(pinsNow * 100 + 0.5),
				math.floor(pinsAfter * 100 + 0.5)
			)
			local coins = tonumber(player:GetAttribute("Coins")) or 0
			priceText.Text = ('<font color="#%s">%s coins</font>  ·  you have %s%s'):format(
				(if can then K.GreenLip else K.Red):ToHex(),
				Currency.Format(price),
				Currency.Format(coins),
				if atShop then "" else "  ·  rebirth at the ball shop"
			)
			fill.Size = UDim2.fromScale(math.clamp(coins / math.max(price, 1), 0, 1), 1)
			if os.clock() < errorUntil then
				return
			end
			if not can then
				holdText.Text = ("Need %s"):format(Currency.Format(price))
				SunKit.Paint(holdHolder, GREY, SunKit.Lip(GREY))
			elseif not atShop then
				holdText.Text = "Rebirth at the shop"
				SunKit.Paint(holdHolder, GREY, SunKit.Lip(GREY))
			else
				holdText.Text = if holdFrom then "Keep holding..." else "Hold to rebirth"
				SunKit.Paint(holdHolder, GOLD, SunKit.Lip(GOLD))
			end
		end

		local function finishHold()
			holdFrom = nil
			TweenService:Create(holdFill, TweenInfo.new(0.2), { Size = UDim2.fromScale(0, 1) }):Play()
			refreshRebirth()
		end
		local function rebirthNow()
			local done = info()
			busy = true
			local ok, result = pcall(rebirthRemote.InvokeServer, rebirthRemote)
			busy = false
			holdFrom = nil
			holdFill.Size = UDim2.fromScale(0, 1)
			if ok and type(result) == "table" and result.Ok then
				CoreShopController.SetOpen(false)
				local party = (require(script.Parent.RebirthController) :: any).Party
				if party then
					task.delay(0.25, party, done + 1, nil)
				end
			else
				Sfx.Play("Error", 1, 0.6)
				task.spawn(shake, holdHolder)
				holdText.Text = if ok and type(result) == "table" and result.Error then result.Error else "Try again"
				errorUntil = os.clock() + 2
				task.delay(2, refreshRebirth)
			end
		end
		holdButton.InputBegan:Connect(function(input)
			if
				input.UserInputType ~= Enum.UserInputType.MouseButton1
				and input.UserInputType ~= Enum.UserInputType.Touch
			then
				return
			end
			local _, _, can = info()
			if busy or not can or not atShop then
				Sfx.Play("Error", 1, 0.5)
				task.spawn(shake, holdHolder)
				if not atShop and can then
					UiFx.Pop(goHolder, 1.15, 0.25)
				end
				return
			end
			holdFrom = os.clock()
			Sfx.Play("Click")
			refreshRebirth()
		end)
		holdButton.InputEnded:Connect(function(input)
			if
				holdFrom
				and (
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				finishHold()
			end
		end)
		holdButton.MouseLeave:Connect(function()
			if holdFrom then
				finishHold()
			end
		end)
		RunService.RenderStepped:Connect(function()
			if not holdFrom then
				return
			end
			local t = (os.clock() - holdFrom) / SHOP.HoldSeconds
			holdFill.Size = UDim2.fromScale(math.clamp(t, 0, 1), 1)
			if t >= 1 then
				holdFrom = nil
				task.spawn(rebirthNow)
			end
		end)

		PAGES.Rebirth = {
			Id = "Rebirth",
			Title = "Rebirth",
			Color = GOLD,
			Frame = page,
			Refresh = refreshRebirth,
			Footer = function()
				bestHolder.Visible = false
				holdHolder.Visible = true
				goHolder.Visible = not atShop
				goHolder.Position = UDim2.new(1, -312, 0.5, -2)
				hint.Text = if atShop then "Hold the button to rebirth" else "Rebirth is bought at the ball shop"
			end,
		}
		-- other tabs hide the hold button again
		for id, other in PAGES do
			if id ~= "Rebirth" then
				local footerOf = other.Footer
				other.Footer = function()
					holdHolder.Visible = false
					if holdFrom then
						finishHold()
					end
					goHolder.Position = UDim2.new(1, -262, 0.5, -2)
					footerOf()
				end
			end
		end
	end

	-- The tab buttons, in Config order (an Id with no page is skipped until it's built, e.g. "Gamepasses")
	local tabButtons: { [string]: Frame } = {}
	local order = 0
	-- (Stage 8: four tabs fit between the title and the coin pill, so each gets narrower than 110)
	local tabCount = 0
	for _, id in SHOP.Tabs or {} do
		if PAGES[id] then
			tabCount += 1
		end
	end
	local tabW = math.min(110, math.floor((W - 460 - GAP * math.max(tabCount - 1, 0)) / math.max(tabCount, 1)))
	for _, id in SHOP.Tabs or { "Balls", "Bags", "Rebirth" } do
		local page = PAGES[id]
		if page then
			order += 1
			local holder, tabFace = plate(tabBar, id .. "Tab", CARD, 10, 4)
			holder.LayoutOrder = order
			holder.Size = UDim2.fromOffset(tabW, 44)
			local label = text(tabFace, page.Title, {
				Name = "Label",
				Size = UDim2.new(1, -16, 0.62, 0),
				Position = UDim2.new(0, 8, 0.19, 0),
				TextColor3 = INK,
			})
			label:SetAttribute("Tab", id)
			local button =
				new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, tabFace)
			juicy(button, holder)
			tabButtons[id] = holder
			button.Activated:Connect(function()
				if currentTab ~= id then
					Sfx.Play("Click")
					CoreShopController.ShowTab(id)
				end
			end)
		end
	end
	if not PAGES[currentTab] or not tabButtons[currentTab] then
		currentTab = (SHOP.Tabs or {})[1] or "Balls"
	end

	-- ===== Refresh =====
	local function refresh()
		for id, holder in tabButtons do
			local active = id == currentTab
			local color = if active then PAGES[id].Color else CARD
			SunKit.Paint(holder, color, if active then SunKit.Lip(color) else K.CreamLip)
			local label = (holder :: any).Face.Label :: TextLabel
			SunKit.Recolor(label, if active then WHITE else INK)
			holder.Size = UDim2.fromOffset(tabW, if active then 46 else 42)
		end
		for id, page in PAGES do
			if page.Frame then
				page.Frame.Visible = id == currentTab
			end
		end
		local page = PAGES[currentTab]
		if page then
			page.Footer()
			page.Refresh()
		end
	end

	-- Keeps the next row of the list in view
	local function scrollToNext()
		for kind, list in rows do
			local first = list[1]
			local scroller = first and first.Holder.Parent
			if scroller and scroller:IsA("ScrollingFrame") and kind ~= "PetSlot" then
				local best = ladderInfo(kind)
				scroller.CanvasPosition = Vector2.new(0, math.max(best - 2, 0) * (ROW - 4 + GAP))
			end
		end
	end

	function CoreShopController.ShowTab(id: string)
		if V2 and CoreShopController.SetOpen then
			CoreShopController.SetOpen(true, id)
			return
		end
		if not PAGES[id] then
			return
		end
		currentTab = id
		refresh()
		local page = PAGES[id]
		if page.Frame then
			UiFx.Pop(page.Frame, 1.02, 0.15)
		end
		task.defer(scrollToNext)
	end

	for _, key in
		{
			"BallStep",
			"BagLevel",
			"Coins",
			"PetSlotsBought",
			"PetSlotsKept",
			"CoreBallsOwned",
			"CoreBagsOwned",
			"CoreLook",
			"Rebirths",
			"CoreZonesOpen",
			"Passes", -- (Stage 8: a bought pass turns its card OWNED)
		}
	do
		player:GetAttributeChangedSignal(key):Connect(function()
			if key == "Coins" then
				countCoins()
			end
			if window.Visible then
				refresh()
			end
		end)
	end

	local function flashText(row: Row, message: string)
		row.BadgeText.Text = message
		task.delay(1.2, function()
			if row.BadgeText.Text == message then
				refresh()
			end
		end)
	end

	-- ===== The reveal (2.3): flash, the silhouette's colour pops in, the name appears, the ball's effect bursts =====
	local function burst(row: Row, color: Color3)
		local layer = row.Face
		local centre = row.Icon.Position
		local ring = new("Frame", {
			Name = "RevealRing",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = centre,
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 1,
			ZIndex = 6,
		}, layer)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, ring)
		local ringStroke = new("UIStroke", { Color = color, Thickness = 5 }, ring)
		TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(150, 150) })
			:Play()
		TweenService:Create(ringStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
		task.delay(0.6, ring.Destroy, ring)
		for i = 1, 14 do
			local angle = (i / 14) * math.pi * 2 + math.random() * 0.3
			local spark = new("Frame", {
				Name = "Spark",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = centre,
				Size = UDim2.fromOffset(9, 9),
				Rotation = math.random(0, 90),
				BackgroundColor3 = if i % 3 == 0 then WHITE else color,
				BorderSizePixel = 0,
				ZIndex = 7,
			}, layer)
			new("UICorner", { CornerRadius = UDim.new(0, 2) }, spark)
			local reach = 45 + math.random() * 40
			TweenService:Create(spark, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {
				Position = centre + UDim2.fromOffset(math.cos(angle) * reach, math.sin(angle) * reach * 0.7),
				BackgroundTransparency = 1,
				Rotation = spark.Rotation + 180,
			}):Play()
			task.delay(0.65, spark.Destroy, spark)
		end
	end

	local function reveal(row: Row)
		local seconds = math.min(SHOP.RevealSeconds or 1.6, 1.9)
		row.RevealUntil = os.clock() + seconds
		local realName = CoreLadder.Name(row.Kind, row.Step)
		local color = RARITY[rarityOf(row.Kind, row.Step)] or GREY
		-- (start from the silhouette)
		if row.View then
			row.View.ImageColor3 = BLACK
		end
		if row.BagImage then
			row.BagImage.ImageColor3 = BLACK
		end
		row.Name.Text = "???"
		-- 1. flash
		local flash = new("Frame", {
			Name = "RevealFlash",
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 8,
		}, row.Face)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, flash)
		TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		task.delay(0.4, flash.Destroy, flash)
		Sfx.Play("SpinWin", 1.1, 0.7)
		-- 2. the colour pops in (silhouette > real look, stripe > rarity colour)
		task.delay(0.12, function()
			local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad)
			if row.View then
				TweenService:Create(row.View, info, { ImageColor3 = WHITE }):Play()
			end
			if row.BagImage then
				TweenService:Create(row.BagImage, info, { ImageColor3 = WHITE }):Play()
			end
			if row.Number then
				row.Number.Text = tostring(row.Step)
			end
			TweenService:Create(row.Stripe, info, { BackgroundColor3 = color }):Play()
			local edge = row.Stripe:FindFirstChild("Edge") :: Frame?
			if edge then
				TweenService:Create(edge, info, { BackgroundColor3 = color }):Play()
			end
			local pop = row.Icon:FindFirstChild("Pop") :: UIScale
			pop.Scale = 0.6
			TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1.15 }):Play()
			task.delay(0.35, function()
				TweenService:Create(pop, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
			end)
		end)
		-- 3. the name appears
		task.delay(0.45, function()
			row.Name.Text = realName
			local pop = row.Name:FindFirstChild("Pop") :: UIScale
			pop.Scale = 0.4
			TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			Sfx.Play("Coin", 1, 1.2)
		end)
		-- 4. the ball's effect, once (its signature colour, Config.CoreLoop.BallEffects)
		task.delay(0.5, function()
			local effects = CORE.BallEffects and CORE.BallEffects.Effects
			local fx = row.Kind == "Ball" and effects and effects[CORE.Balls[row.Step].Fx]
			burst(row, if fx then fx.Color else color)
			UiFx.Pop(row.Holder, 1.08, 0.25)
		end)
		task.delay(seconds, function()
			row.RevealUntil = nil
			refresh()
		end)
	end

	-- After a buy: confetti, refresh, the reveal on the bought row
	local function bought(kind: string, step: number)
		UiFx.Flash(GREEN, 0.12, 0.2)
		UiFx.Confetti(face, 26)
		local row = rows[kind] and rows[kind][step]
		refresh()
		if row and kind ~= "PetSlot" then
			reveal(row)
		elseif row then
			Sfx.Play("Coin", 1, 1.2)
			UiFx.Pop(row.Holder, 1.12, 0.3)
		end
	end

	local function tryBuy(row: Row)
		if busy then
			return
		end
		local state = row.State
		-- owned ball: EQUIP its look (anywhere, it isn't a buy)
		if row.Kind == "Ball" and row.Owned then
			if lookStep() == row.Step then
				return
			end
			busy = true
			local ok, result = pcall(equipRemote.InvokeServer, equipRemote, row.Step)
			busy = false
			if ok and type(result) == "table" and result.Ok then
				Sfx.Play("Click")
				UiFx.Pop(row.Badge, 1.15, 0.2)
			else
				Sfx.Play("Error", 1, 0.6)
				task.spawn(shake, row.Badge)
			end
			return
		end
		if row.Owned or state == "Owned" then
			return
		end
		if state == "Locked" then
			Sfx.Play("Error", 1, 0.6)
			task.spawn(shake, row.Badge)
			flashText(row, ("Zone %d"):format(CoreLadder.Zone(row.Kind, row.Step)))
			return
		end
		if not atShop then
			-- price list: no buying here, nudge the GO TO SHOP button
			Sfx.Play("Error", 1, 0.5)
			task.spawn(shake, row.Badge)
			UiFx.Pop(goHolder, 1.15, 0.25)
			return
		end
		if row.Kind == "PetSlot" and state ~= "Buy" then
			Sfx.Play("Error", 1, 0.6)
			task.spawn(shake, row.Badge)
			return
		end
		busy = true
		local ok, result
		if row.Kind == "PetSlot" then
			ok, result = pcall(buyRemote.InvokeServer, buyRemote, "PetSlot")
		else
			ok, result = pcall(buyRemote.InvokeServer, buyRemote, row.Kind, row.Step)
		end
		busy = false
		if ok and type(result) == "table" and result.Ok then
			bought(row.Kind, if row.Kind == "PetSlot" then 1 else result.Step or row.Step)
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

	-- BUY BEST: the highest ball / bag you can pay for on this tab
	bestButton.Activated:Connect(function()
		if busy then
			return
		end
		local kind = if currentTab == "Bags" then "Bag" else "Ball"
		local best, _, rebirths, zones = ladderInfo(kind)
		local step = CoreLadder.BuyBest(kind, best, player:GetAttribute("Coins"), rebirths, zones)
		if not step then
			Sfx.Play("Error", 1, 0.6)
			task.spawn(shake, bestHolder)
			return
		end
		if not atShop then
			Sfx.Play("Error", 1, 0.5)
			task.spawn(shake, bestHolder)
			UiFx.Pop(goHolder, 1.15, 0.25)
			return
		end
		busy = true
		local ok, result = pcall(buyRemote.InvokeServer, buyRemote, kind, "Best")
		busy = false
		if ok and type(result) == "table" and result.Ok then
			local list = rows[kind]
			local first = list[1]
			local scroller = first and first.Holder.Parent
			if scroller and scroller:IsA("ScrollingFrame") then
				scroller.CanvasPosition = Vector2.new(0, math.max(result.Step - 2, 0) * (ROW - 4 + GAP))
			end
			bought(kind, result.Step)
		else
			Sfx.Play("Error", 1, 0.6)
			task.spawn(shake, bestHolder)
			bestLine.Text = if ok and type(result) == "table" and result.Error then result.Error else "Try again"
			task.delay(1.5, refresh)
		end
	end)

	-- Spin the next ball's silhouette and turn the Mythic rainbow while the window is open
	RunService.RenderStepped:Connect(function(dt)
		if not window.Visible then
			return
		end
		if currentTab == "Balls" then
			for _, row in rows.Ball do
				local view = row.View
				if view and (row.State == "Next" or (row.RevealUntil and os.clock() < row.RevealUntil)) then
					local model = view:FindFirstChildWhichIsA("PVInstance")
					if model then
						BallView.Turn(model, CFrame.Angles(0, dt * (if row.RevealUntil then 4 else 1.2), 0))
					end
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

	-- Open / close (tab = open on that tab: "Balls", "Bags", "Rebirth")
	local open = false
	local function setOldOpen(on: boolean, tab: string?)
		if tab and PAGES[tab] then
			currentTab = tab
		end
		if on == open then
			if on then
				refresh()
				task.defer(scrollToNext)
			end
			return
		end
		open = on
		backdrop.Visible = on
		gui:SetAttribute("Open", on)
		if on then
			shownCoins = player:GetAttribute("Coins") or 0
			coinText.Text = Currency.Format(shownCoins)
			refresh()
			task.defer(scrollToNext) -- (after the lists have measured their rows)
			Sfx.Play("Click")
			UiFx.Open(window)
		else
			holdFrom = nil
			UiFx.Close(window)
		end
	end
	-- V3 / V4: with Config.Ui.ShopV2 every tab opens the new window (the old one stays shut)
	local function setOpen(on: boolean, tab: string?)
		if V2 then
			local want = tab or currentTab
			if PAGES[want] or want == "Balls" or want == "Bags" then
				currentTab = want
			end
			setOldOpen(false)
			ShopV2.SetOpen(on, if on then currentTab else nil)
			return
		end
		setOldOpen(on, tab)
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

	-- V3 / V4: the new window (BALLS, BAGS, REBIRTH, PASSES)
	if V2 then
		local tabIds = {}
		for id in PAGES do
			table.insert(tabIds, id)
		end
		ShopV2.Start({
			Buy = buyRemote,
			Equip = equipRemote,
			Rebirth = rebirthRemote,
			StoreBuy = remotes:WaitForChild("StoreBuy", 10),
			Party = function(rebirths: number)
				local party = (require(script.Parent.RebirthController) :: any).Party
				if party then
					party(rebirths, nil)
				end
			end,
			AtShop = function()
				return atShop
			end,
			GoToShop = function()
				Sfx.Play("Teleport", 1.1, 0.6)
				UiFx.Flash(WHITE, 0.25, 0.25)
				goRemote:FireServer("Shop")
			end,
			OnTab = function(tab: string)
				currentTab = tab
			end,
			Tabs = tabIds,
		})
	end

	-- The BALLS button opens the price list on the Balls tab (the old Ball Book stays shut in the core loop)
	task.spawn(function()
		local ballsUi = playerGui:WaitForChild("BallsUI", 30)
		local button = ballsUi and ballsUi:WaitForChild("Menu", 10):WaitForChild("BallsButton", 10) :: GuiButton?
		if button then
			button.Activated:Connect(function()
				if (open and currentTab == "Balls") or (V2 and ShopV2.IsOpen() and ShopV2.Tab() == "Balls") then
					setOpen(false)
				else
					setOpen(true, "Balls")
				end
			end)
		end
	end)

	-- Stage 8: the small gold PASSES button on the HUD (right of PROFILE; phones: right of STORE) opens the
	-- Gamepasses tab. Polish v2 U1: with that tab gone (passes only in the STORE), it opens the STORE on its passes.
	if PAGES.Gamepasses or Store.Active() then
		task.spawn(function()
			local ballsUi = playerGui:WaitForChild("BallsUI", 30) :: ScreenGui?
			local buttonGui = new("ScreenGui", {
				Name = "PassesButtonUI",
				ResetOnSpawn = false,
				DisplayOrder = if ballsUi then ballsUi.DisplayOrder else 5,
				IgnoreGuiInset = if ballsUi then ballsUi.IgnoreGuiInset else false,
			}, nil)
			local kit =
				HudKit.Square(buttonGui, { Name = "PassesButton", Paint = "Gold", Icon = "Store", Key = "Passes" })
			kit.Icon.Image = AssetSlots.Image("Pass2x")
			kit:SetCaption("PASSES", nil, nil, 10)
			local button = kit.Holder :: TextButton
			button.Activated:Connect(function()
				if not PAGES.Gamepasses then
					if open or (V2 and ShopV2.IsOpen()) then
						setOpen(false)
					end
					local StoreController = require(script.Parent.StoreController) :: any
					if StoreController.OpenOn then
						StoreController.OpenOn("passes")
					end
				elseif
					(open and currentTab == "Gamepasses") or (V2 and ShopV2.IsOpen() and ShopV2.Tab() == "Gamepasses")
				then
					setOpen(false)
				else
					setOpen(true, "Gamepasses")
				end
			end)
			buttonGui.Parent = playerGui
		end)
	end

	-- Studio only: the playtest opens / closes the shop by setting the TestOpen attribute on CoreShopUI (TestTab =
	-- the tab to open on)
	if RunService:IsStudio() then
		gui:GetAttributeChangedSignal("TestOpen"):Connect(function()
			setOpen(gui:GetAttribute("TestOpen") == true, gui:GetAttribute("TestTab"))
		end)
		gui:GetAttributeChangedSignal("TestTab"):Connect(function()
			if open or (V2 and ShopV2.IsOpen()) then
				CoreShopController.ShowTab(gui:GetAttribute("TestTab"))
			end
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
				-- (Addendum 6 Stage 3: the shop of the zone you're in)
				local offset = root.Position - (SHOP.Position + CoreLadder.ZoneOffset(CoreLadder.ZoneAt(root.Position)))
				here = Vector2.new(offset.X, offset.Z).Magnitude <= SHOP.Radius and offset.Y > -2 and offset.Y < 8
			end
			if here ~= atShop then
				atShop = here
				-- (not over the old REBIRTH window: its GO TO SHOP brings you here to rebirth, step C)
				local rebirthWindow = playerGui:FindFirstChild("RebirthWindowUI")
				if here and rebirthWindow and rebirthWindow:GetAttribute("Open") then
					continue
				elseif here then
					if V2 and ShopV2.IsOpen() then
						ShopV2.Refresh()
					elseif open then
						refresh()
						UiFx.Pop(window, 1.04, 0.2)
					else
						-- (Polish v2 D3: the window flies out of the stall you walked up to)
						Motion.NoteWorld(SHOP.Position + CoreLadder.ZoneOffset(CoreLadder.ZoneAt(root.Position)) + Vector3.new(0, 5, 0))
						setOpen(true)
					end
				elseif open or (V2 and ShopV2.IsOpen()) then
					setOpen(false)
				end
			end
		end
	end)

	gui.Parent = playerGui
end

return CoreShopController
