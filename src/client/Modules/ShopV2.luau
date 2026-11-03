-- UI overhaul V3 (UI_OVERHAUL_PLAN.md): the SHOP window's BALLS and BAGS tabs in the owner's new look
-- ('Strike Legends Screens.html' 1a desktop / 1b phone, built on Modules/SlKit). Config.Ui.ShopV2 switches it on.
-- Gold SHOP header, red X, a tab column on the left (BALLS / BAGS / REBIRTH / PASSES with red dots), a dark well with a
-- zone switcher (zones 1-4, the zone's top ball in 3D) and a 4-wide card grid: 3D ball / bag art on rarity rays,
-- name, "+30 PINS" / "HOLDS 3.7K", one button (EQUIPPED / EQUIP / coin price, red when you can't pay).
-- Card states (design): owned = tick, BEST = gold ring + chip (the highest one you can pay for), NEXT = pulsing coral
-- ring + chip, SKIPPED = grey chip, Epic = purple ring, Mythic = sliding rainbow stripes, locked zone = dark + padlock
-- + "ZONE n", "???" = black silhouette past Config.Ui.ShopV2Ahead (only its stat and price show).
-- BUY BEST bottom right (green: what + price; grey: the next price / MAX). Away from the shop stall the window is a
-- price list: BUY BEST becomes GO TO SHOP and a buy tap nudges it (the server only sells at the stall).
-- Buying plays the reveal over the card (1.6 s): white flash, colour floods in, rays spin, ring burst, name drops in,
-- NEW! stamp. The PET SLOT card (Addendum 5 B1) sits after the bags of every zone.
-- V4: the REBIRTH tab (rank badge now > next, x COINS / x PINS, RESETS / KEEPS, coins bar, HOLD TO REBIRTH / GO TO
-- SHOP) and the PASSES tab (8 pass cards, Robux price or OWNED) live here too.
-- CoreShopController owns the stall check and the remotes (the old window stays for Config.Ui.ShopV2 = false).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local CoreLadder = require(Shared.Modules.CoreLadder)
local Currency = require(Shared.Modules.Currency)
local Mascots = require(Shared.Modules.Mascots)
local Rebirth = require(Shared.Modules.Rebirth)
local Store = require(Shared.Modules.Store)
local BallView = require(script.Parent.BallView)
local SlKit = require(script.Parent.SlKit)
local Motion = require(script.Parent:WaitForChild("Motion"))
local Sfx = require(script.Parent.Sfx)
local UiFx = require(script.Parent.UiFx)

local CORE = Config.CoreLoop
local SHOP = CORE.Shop
local player = Players.LocalPlayer
local make = SlKit.Make
local text = SlKit.Text
local hex = Color3.fromHex
local C = SlKit.C
local INK = C.Ink
local WHITE = C.White
local BLACK = Color3.new(0, 0, 0)
local NIGHT = hex("0B1A33")
local DEEP = hex("0F2747") -- the well
local GOLD_TEXT = hex("FFC93A")
local SOFT = hex("7C8AA8")
local ROBUX_GLYPH = utf8.char(0xE002)

local ShopV2 = {}

-- Sizes are the design's pixels (window 1300 x 760 on a 1920 x 1080 screen at scale 1.15)
local W, H = 1300, 760
local TAB_W, TAB_H = 210, 96
local CARD_W, CARD_H = 220, 379 -- (the design's card + its 6 px lip)
local ART_H = 204
local GRID_TOP, FOOT_H = 108, 112
local GAP_X, GAP_Y = 18, 24
local MAX_SCALE = 1.15

-- Button paints { face, lip, top strip } (design btn())
local PAINT = {
	Green = { hex("3CCB3F"), hex("1F8F27"), hex("7BE37D") },
	Red = { hex("FF3B4E"), hex("B81E30"), hex("FF7A86") },
	Blue = { hex("2E9BFF"), hex("1666C4"), hex("7CC0FF") },
	Navy = { hex("10294A"), NIGHT, hex("22477A") },
	Gold = { hex("FFC93A"), hex("E59A00"), hex("FFE07A") },
	Grey = { hex("7C869B"), hex("565F73"), hex("A3ABBC") },
	Dark = { hex("2A3550"), hex("161D30"), hex("3D4A6B") },
	Tile = { C.Tile, C.TileLip, C.TileStrip },
	Night = { NIGHT, hex("070F1F"), hex("10294A") },
}

-- Card colours per rarity (design RC): c = art, l = rays, chip = rarity chip, ring = extra edge
type Look = { c: Color3, l: Color3, chip: Color3, ring: Color3? }
local LOOK: { [string]: Look } = {
	Common = { c = hex("B8C2CC"), l = hex("D6DDE4"), chip = hex("B8C2CC") },
	Uncommon = { c = hex("4BE07A"), l = hex("8BF0A8"), chip = hex("4BE07A") },
	Rare = { c = hex("3AA8FF"), l = hex("7CC6FF"), chip = hex("3AA8FF") },
	Epic = { c = hex("2B5A96"), l = hex("22477A"), chip = hex("B45CFF"), ring = hex("B45CFF") },
	Legendary = { c = hex("FFC93A"), l = hex("FFE07A"), chip = hex("FFC93A") },
	Mythic = { c = hex("FF4F8B"), l = hex("FF8DB4"), chip = hex("FF4F8B") },
	PetSlot = { c = hex("FF4FA3"), l = hex("FF8CC4"), chip = hex("FF4FA3") },
	InfBag = { c = hex("3CCB3F"), l = hex("8BE68D"), chip = hex("3CCB3F") }, -- (launch changes: the INFINITE BAG pass card)
}
local DIM: Look = { c = hex("17345C"), l = hex("22477A"), chip = hex("17345C") }
local STRIPES = { hex("FF4F8B"), hex("FFC93A"), hex("4BE07A"), hex("3AA8FF"), hex("B45CFF") }

local function corner(parent: Instance, radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	return make("UIStroke", {
		Color = color,
		Thickness = thickness,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

-- A row of things side by side, centred
local function hrow(parent: Instance, gap: number, props: { [string]: any }?): Frame
	local frame = make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	for key, value in props or {} do
		(frame :: any)[key] = value
	end
	return frame
end

-- A label that sizes to its words (for rows)
local function word(parent: Instance, words: string, size: number, color: Color3?, order: number?): TextLabel
	return text(parent, words, size, color or WHITE, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = order or 2,
	})
end

-- A small word chip (NEXT / BEST / SKIPPED / rarity): coloured plate, ink outline
local function chip(parent: Instance, words: string, color: Color3, big: boolean): Frame
	local frame = make("Frame", {
		Name = "Chip",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, if big then 34 else 24),
		Visible = false,
	}, parent)
	corner(frame, if big then 10 else 8)
	stroke(frame, INK, if big then 3 else 2)
	make("UIPadding", {
		PaddingLeft = UDim.new(0, if big then 12 else 8),
		PaddingRight = UDim.new(0, if big then 12 else 8),
	}, frame)
	text(frame, words, if big then 20 else 12, WHITE, {
		Name = "Words",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
	})
	return frame
end

local function rarityOf(kind: string, step: number): string
	if kind == "PetSlot" then
		return "PetSlot"
	end
	local entry = CORE.Balls[math.clamp(step, 1, #CORE.Balls)]
	return entry.Rarity or "Common"
end

local function bagIcon(step: number): string
	return ("bag_%02d"):format((step - 1) % 10 + 1)
end

-- Stripes for the Mythic ring (design: hard 12 px bands sliding along). Returns stop().
local function slideStripes(target: UIStroke): () -> ()
	local keys = {}
	local n = #STRIPES * 2 -- (a ColorSequence holds at most 20 points = 10 bands)
	for i = 0, n - 1 do
		local color = STRIPES[(i % #STRIPES) + 1]
		table.insert(keys, ColorSequenceKeypoint.new(i / n, color))
		table.insert(keys, ColorSequenceKeypoint.new(math.min((i + 1) / n - 0.0001, 1), color))
	end
	keys[#keys] = ColorSequenceKeypoint.new(1, keys[#keys].Value)
	local gradient = make("UIGradient", { Color = ColorSequence.new(keys), Rotation = 45 }, target)
	local tween = TweenService:Create(
		gradient,
		TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Offset = Vector2.new(1 / 2, 0) }
	)
	tween:Play()
	return function()
		tween:Cancel()
		gradient:Destroy()
	end
end

type Card = {
	Index: number,
	Block: any,
	Holder: GuiButton,
	Art: CanvasGroup,
	Rays: ImageLabel,
	Model: Frame,
	Views: { [number]: ViewportFrame },
	BagImage: ImageLabel,
	Next: Frame,
	Best: Frame,
	Skipped: Frame,
	Rarity: Frame,
	Tick: ImageLabel,
	Name: TextLabel,
	StatIcon: ImageLabel,
	Stat: TextLabel,
	Button: any,
	ButtonIcon: ImageLabel,
	ButtonText: TextLabel,
	Lock: Frame,
	LockText: TextLabel,
	GoldRing: Frame,
	InkRing: Frame,
	ColorRing: UIStroke,
	NextRing: Frame,
	StopStripes: (() -> ())?,
	StopPulse: (() -> ())?,
	-- what it shows
	Kind: string?,
	Step: number?,
	State: string?,
	Owned: boolean?,
	Equipped: boolean?,
	Afford: boolean?,
	RevealUntil: number?,
}

-- ctx (from CoreShopController): Buy / Equip / Rebirth (RemoteFunctions), StoreBuy (RemoteEvent?), AtShop() -> bool,
-- GoToShop(), Party(rebirths) (the REBIRTH! moment), OnTab(tab) (keeps the controller's tab in step), Tabs (ids it has)
function ShopV2.Start(ctx: { [string]: any })
	local playerGui = player:WaitForChild("PlayerGui")
	local AHEAD = math.max(0, math.floor(tonumber(Config.Ui.ShopV2Ahead) or 3))

	local gui = make("ScreenGui", {
		Name = "ShopV2UI",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local backdrop = make("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = NIGHT,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, gui)
	local fit = make("Frame", {
		Name = "Shop",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(W, H),
	}, gui)
	local fitScale = make("UIScale", { Name = "Fit" }, fit)
	-- (1.15 on a 1080p screen, ~0.41 on a phone held sideways, like the design)
	local function refit()
		local view = gui.AbsoluteSize
		if view.X > 0 then
			fitScale.Scale = math.min((view.X - 40) / (W + 56), (view.Y - 40) / (H + 100), MAX_SCALE)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	local win = make("Frame", { Name = "Window", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, fit)
	local openScale = make("UIScale", { Name = "OpenScale" }, win)
	win.Visible = false

	SlKit.Block(win, { Name = "Body", Size = UDim2.fromScale(1, 1), Radius = 16, Paint = "Window", Lip = 8 })
	local header =
		SlKit.Block(win, { Name = "Header", Size = UDim2.fromOffset(340, 86), Radius = 16, Paint = "Header" })
	header.Holder.AnchorPoint = Vector2.new(0.5, 0)
	header.Holder.Position = UDim2.new(0.5, 0, 0, -36)
	header.Holder.ZIndex = 5
	local title = text(header.Content, "SHOP", 44, WHITE, { Name = "Title" })
	local titleStroke = title:FindFirstChildOfClass("UIStroke") :: UIStroke
	titleStroke.Thickness = 3
	local close = SlKit.Button(win, {
		Name = "Close",
		Text = "",
		Size = UDim2.fromOffset(88, 94),
		Radius = 18,
		Paint = PAINT.Red,
	})
	close.Holder.AnchorPoint = Vector2.new(1, 0)
	close.Holder.Position = UDim2.new(1, 26, 0, -26)
	close.Holder.ZIndex = 5
	-- the design's X: two white bars with an ink outline
	for _, angle in { 45, -45 } do
		local bar = make("Frame", {
			Name = "Bar",
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(14, 54),
			Rotation = angle,
			ZIndex = 8,
		}, close.Content)
		corner(bar, 6)
		stroke(bar, INK, 3)
	end

	-- ===== Tab column =====
	local tabCol = make("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 64),
		Size = UDim2.fromOffset(TAB_W, H - 96),
	}, win)
	make("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }, tabCol)
	local TAB_DEFS = {
		{ Id = "Balls", Text = "BALLS" },
		{ Id = "Bags", Text = "BAGS", Icon = "bag_01" },
		{ Id = "Rebirth", Text = "REBIRTH", Icon = "hud_rebirth" },
		{ Id = "Gamepasses", Text = "PASSES", Icon = "hud_passes" },
	}
	type Tab = { Block: any, Dot: Frame, Icon: Frame }
	local tabs: { [string]: Tab } = {}
	local currentTab = "Balls"
	local currentZone = 1
	local setTab: (string) -> ()
	for order, def in TAB_DEFS do
		if def.Id ~= "Balls" and def.Id ~= "Bags" and not table.find(ctx.Tabs or {}, def.Id) then
			continue
		end
		local block = SlKit.Block(tabCol, {
			Name = def.Id .. "Tab",
			Button = true,
			Size = UDim2.fromOffset(TAB_W, TAB_H + 6),
			Radius = 16,
			Paint = PAINT.Tile,
		})
		block.Holder.LayoutOrder = order
		local icon = make("Frame", {
			Name = "IconBox",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(64, 64),
		}, block.Content)
		if def.Icon then
			SlKit.Image(icon, def.Icon, 64, { Size = UDim2.fromScale(1, 1) })
		end
		text(block.Content, def.Text, 26, WHITE, {
			Name = "Label",
			Position = UDim2.fromOffset(84, 0),
			Size = UDim2.new(1, -90, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local dot = SlKit.Dot(block.Holder, 0, true)
		dot.Position = UDim2.new(1, -6, 0, 6)
		dot.Visible = false
		tabs[def.Id] = { Block = block, Dot = dot, Icon = icon }
		local id = def.Id
		block.Holder.Activated:Connect(function()
			setTab(id)
		end)
	end

	-- ===== The well: zone switcher, card grid, footer =====
	local well = make("Frame", {
		Name = "Well",
		BackgroundColor3 = DEEP,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(24 + TAB_W + 20, 64),
		Size = UDim2.fromOffset(W - (24 + TAB_W + 20) - 24, H - 64 - 32),
		ClipsDescendants = true,
	}, win)
	corner(well, 16)
	stroke(well, INK, 3)

	local zoneRow = make("Frame", {
		Name = "Zones",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(18, 14),
		Size = UDim2.new(1, -36, 0, 94),
	}, well)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, zoneRow)
	type ZoneTile = { Block: any, Lock: ImageLabel, View: ViewportFrame?, Ring: Frame }
	local zoneTiles: { ZoneTile } = {}
	local refresh: () -> ()
	local scrollToFocus: () -> ()
	for zone = 1, CoreLadder.ZoneCount() do
		local block = SlKit.Block(zoneRow, {
			Name = "Zone" .. zone,
			Button = true,
			Size = UDim2.fromOffset(96, 94),
			Radius = 16,
			Paint = PAINT.Tile,
		})
		block.Holder.LayoutOrder = zone
		-- white ring around the open zone (design: 4 px white + 3 px ink)
		local ring = make("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -6),
			ZIndex = 0,
			Visible = false,
		}, block.Holder)
		corner(ring, 16)
		stroke(ring, WHITE, 4)
		local inkRing = make("Frame", {
			Name = "Ink",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-4, -4),
			Size = UDim2.new(1, 8, 1, 8),
			ZIndex = 0,
		}, ring)
		corner(inkRing, 20)
		stroke(inkRing, INK, 3)
		-- the zone's top ball in 3D (no zone icons in the sheet; 3D on cards, as designed)
		local topStep = 1
		for step = 1, #CORE.Balls do
			if CoreLadder.Zone("Ball", step) == zone then
				topStep = step
			end
		end
		local ball = Balls.Get(CORE.Balls[topStep].Ball)
		local view: ViewportFrame? = nil
		if ball then
			view = BallView.New(ball, { Margin = 1.05 })
			local v = view :: ViewportFrame
			v.AnchorPoint = Vector2.new(0.5, 0.5)
			v.Position = UDim2.fromScale(0.5, 0.5)
			v.Size = UDim2.fromOffset(62, 62)
			v.Parent = block.Content
		end
		local lock = SlKit.Image(block.Content, "ui_lock", 48, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Visible = false,
		})
		-- the zone number badge, bottom right
		local badge = make("Frame", {
			Name = "Number",
			BackgroundColor3 = hex("17345C"),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 8, 1, 2),
			Size = UDim2.fromOffset(34, 34),
			ZIndex = 8,
		}, block.Holder)
		corner(badge, 10)
		stroke(badge, INK, 3)
		text(badge, tostring(zone), 18, WHITE)
		zoneTiles[zone] = { Block = block, Lock = lock, View = view, Ring = ring }
		block.Holder.Activated:Connect(function()
			if currentZone ~= zone then
				currentZone = zone
				refresh()
				scrollToFocus()
			end
		end)
	end
	local zoneName = text(zoneRow, "", 26, GOLD_TEXT, {
		Name = "ZoneName",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 40),
		LayoutOrder = 99,
	})
	make("UIPadding", { PaddingLeft = UDim.new(0, 6) }, zoneName)

	local grid = make("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, GRID_TOP),
		Size = UDim2.new(1, 0, 1, -GRID_TOP - FOOT_H),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.TileStrip,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
	}, well)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H),
		CellPadding = UDim2.fromOffset(GAP_X, GAP_Y),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 16),
		PaddingBottom = UDim.new(0, 24),
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
	}, grid)

	local footer = make("Frame", {
		Name = "Footer",
		BackgroundColor3 = DEEP,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FOOT_H),
		ZIndex = 3,
	}, well)
	make("Frame", {
		Name = "Line",
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 3),
		ZIndex = 3,
	}, footer)
	local hint = text(footer, "PRICE LIST · BUY AT THE SHOP", 20, SOFT, {
		Name = "Hint",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 24, 0.5, 2),
		Size = UDim2.new(1, -440, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = false,
		ZIndex = 3,
	})
	local buyBest = SlKit.Block(footer, {
		Name = "BuyBest",
		Button = true,
		Size = UDim2.fromOffset(370, 90),
		Radius = 18,
		Paint = PAINT.Green,
	})
	buyBest.Holder.AnchorPoint = Vector2.new(1, 1)
	buyBest.Holder.Position = UDim2.new(1, -20, 1, -16)
	buyBest.Holder.ZIndex = 3
	text(buyBest.Content, "BUY BEST", 32, WHITE, {
		Name = "Title",
		Position = UDim2.fromOffset(0, 6),
		Size = UDim2.new(1, 0, 0, 40),
	})
	local bestLine = hrow(buyBest.Content, 14, { Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 30) })
	local bestStat =
		hrow(bestLine, 4, { Name = "Stat", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1) })
	bestStat.LayoutOrder = 1
	local bestStatIcon = SlKit.Image(bestStat, "cur_pin", 30, { LayoutOrder = 1 })
	local bestStatText = word(bestStat, "", 22)
	local bestPrice =
		hrow(bestLine, 4, { Name = "Price", AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1) })
	bestPrice.LayoutOrder = 2
	local bestPriceIcon = SlKit.Image(bestPrice, "cur_coin", 30, { LayoutOrder = 1 })
	local bestPriceText = word(bestPrice, "", 22)
	local goShop = SlKit.Button(footer, {
		Name = "GoToShop",
		Text = "GO TO SHOP",
		Icon = "hud_shop",
		IconSize = 52,
		Size = UDim2.fromOffset(370, 90),
		Radius = 18,
		Paint = PAINT.Blue,
		TextSize = 32,
	})
	goShop.Holder.AnchorPoint = Vector2.new(1, 1)
	goShop.Holder.Position = UDim2.new(1, -20, 1, -16)
	goShop.Holder.ZIndex = 3
	goShop.Holder.Visible = false

	-- ===== Cards (11 slots: a zone's 10 + the PET SLOT card; re-filled when the zone or tab changes) =====
	local cards: { Card } = {}
	local function makeCard(index: number): Card
		local block = SlKit.Block(grid, {
			Name = "Card" .. index,
			Button = true,
			Size = UDim2.fromOffset(CARD_W, CARD_H),
			Radius = 16,
			Paint = PAINT.Tile,
		})
		local holder = block.Holder :: GuiButton
		holder.LayoutOrder = index
		-- Rings outside the card (under it): ink, then gold (BEST) / purple (Epic) / rainbow (Mythic)
		local inkRing = make("Frame", {
			Name = "InkRing",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-6, -6),
			Size = UDim2.new(1, 12, 1, 12),
			ZIndex = 0,
			Visible = false,
		}, holder)
		corner(inkRing, 22)
		stroke(inkRing, INK, 3)
		local goldRing = make("Frame", {
			Name = "ColorRing",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 0,
			Visible = false,
		}, holder)
		corner(goldRing, 16)
		local colorRing = stroke(goldRing, PAINT.Gold[1], 6)
		-- NEXT: a pulsing coral ring a little further out
		local nextRing = make("Frame", {
			Name = "NextRing",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-5, -5),
			Size = UDim2.new(1, 10, 1, 10),
			ZIndex = 0,
			Visible = false,
		}, holder)
		corner(nextRing, 22)
		stroke(nextRing, hex("FF7A59"), 6)

		local content = block.Content
		-- Art: rarity colour + lighter rays (a CanvasGroup so the rays keep the card's round top corners)
		local art = make("CanvasGroup", {
			Name = "Art",
			BackgroundColor3 = LOOK.Common.c,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, ART_H + 14),
			ZIndex = 1,
		}, content)
		corner(art, 13)
		local rays = SlKit.Image(art, "bg_rays", 0, {
			Name = "Rays",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, ART_H / 2),
			Size = UDim2.fromOffset(380, 380),
			ZIndex = 1,
		})
		-- (covers the art's round bottom corners, then the ink line under the art)
		make("Frame", {
			Name = "Under",
			BackgroundColor3 = C.Tile,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, ART_H),
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 2,
		}, content)
		make("Frame", {
			Name = "Line",
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, ART_H),
			Size = UDim2.new(1, 0, 0, 3),
			ZIndex = 3,
		}, content)
		local model = make("Frame", {
			Name = "Model",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, ART_H / 2 + 2),
			Size = UDim2.fromOffset(150, 150),
			ZIndex = 4,
		}, content)
		local bagImage = SlKit.Image(model, "bag_01", 0, {
			Name = "Bag",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.86),
			Visible = false,
		})
		-- Chips top left (NEXT / BEST / SKIPPED), tick top right, rarity bottom right
		local chips = make("Frame", {
			Name = "Chips",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(150, 80),
			ZIndex = 6,
		}, content)
		make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, chips)
		local nextChip = chip(chips, "NEXT", hex("FF7A59"), true)
		local bestChip = chip(chips, "BEST", PAINT.Gold[1], true)
		local skippedChip = chip(chips, "SKIPPED", PAINT.Grey[1], false)
		local tick = SlKit.Image(content, "ui_tick", 52, {
			Name = "Tick",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			ZIndex = 6,
			Visible = false,
		})
		local rarityChip = chip(content, "COMMON", LOOK.Common.chip, false)
		rarityChip.AnchorPoint = Vector2.new(1, 1)
		rarityChip.Position = UDim2.new(1, -8, 0, ART_H - 8)
		rarityChip.ZIndex = 6
		-- Bottom: name, stat, button
		local name = text(content, "", 26, WHITE, {
			Name = "ItemName",
			Position = UDim2.fromOffset(8, ART_H + 12),
			Size = UDim2.new(1, -16, 0, 32),
			ZIndex = 5,
		})
		local statRow = hrow(content, 6, { Position = UDim2.fromOffset(0, ART_H + 46), Size = UDim2.new(1, 0, 0, 30) })
		statRow.ZIndex = 5
		local statIcon = SlKit.Image(statRow, "cur_pin", 30, { LayoutOrder = 1 })
		local stat = word(statRow, "", 21, C.Value)
		local button = SlKit.Block(content, {
			Name = "Action",
			Size = UDim2.new(1, -20, 0, 62),
			Radius = 14,
			Paint = PAINT.Green,
		})
		button.Holder.Position = UDim2.fromOffset(10, ART_H + 84)
		button.Holder.ZIndex = 5
		local buttonRow = hrow(button.Content, 6)
		local buttonIcon = SlKit.Image(buttonRow, "cur_coin", 36, { LayoutOrder = 1 })
		local buttonText = word(buttonRow, "", 26)
		-- Locked zone: dark cover, padlock, ZONE n
		local lock = make("Frame", {
			Name = "Locked",
			BackgroundColor3 = NIGHT,
			BackgroundTransparency = 0.08,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 10,
			Visible = false,
		}, content)
		corner(lock, 13)
		SlKit.Image(lock, "ui_lock", 92, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 0.5, 4),
			ZIndex = 11,
		})
		local lockText = text(lock, "ZONE 2", 28, WHITE, {
			Position = UDim2.new(0, 0, 0.5, 12),
			Size = UDim2.new(1, 0, 0, 36),
			ZIndex = 11,
		})
		local card: Card = {
			Index = index,
			Block = block,
			Holder = holder,
			Art = art,
			Rays = rays,
			Model = model,
			Views = {},
			BagImage = bagImage,
			Next = nextChip,
			Best = bestChip,
			Skipped = skippedChip,
			Rarity = rarityChip,
			Tick = tick,
			Name = name,
			StatIcon = statIcon,
			Stat = stat,
			Button = button,
			ButtonIcon = buttonIcon,
			ButtonText = buttonText,
			Lock = lock,
			LockText = lockText,
			GoldRing = goldRing,
			InkRing = inkRing,
			ColorRing = colorRing,
			NextRing = nextRing,
		}
		return card
	end

	-- The ball's 3D view on a card (one per ball, made the first time that card shows it)
	local function ballView(card: Card, step: number): ViewportFrame?
		local view = card.Views[step]
		if not view then
			local ball = Balls.Get(CORE.Balls[step].Ball)
			if not ball then
				return nil
			end
			view = BallView.New(ball, { Margin = 1.0 })
			local v = view :: ViewportFrame
			v.AnchorPoint = Vector2.new(0.5, 0.5)
			v.Position = UDim2.fromScale(0.5, 0.5)
			v.Size = UDim2.fromScale(1, 1)
			v.Parent = card.Model
			card.Views[step] = v
		end
		return view
	end

	-- ===== Player info =====
	local function ladderInfo(kind: string)
		local best = if kind == "Ball"
			then CoreLadder.BallStep(player:GetAttribute("BallStep"))
			else CoreLadder.BagLevel(player:GetAttribute("BagLevel"))
		local mask = player:GetAttribute(if kind == "Ball" then "CoreBallsOwned" else "CoreBagsOwned") or 1
		return best, mask, player:GetAttribute("Rebirths"), player:GetAttribute("CoreZonesOpen")
	end
	-- The ball you throw for its look (CoreLook if owned, else your best)
	local function lookStep(): number
		local best, mask = ladderInfo("Ball")
		local look = math.floor(tonumber(player:GetAttribute("CoreLook")) or 0)
		return if look >= 1 and look <= #CORE.Balls and CoreLadder.Owns(mask, look) then look else best
	end
	local function petSlotInfo()
		local start = Config.Economy.Mascots.StartSlots
		local bought =
			math.max(player:GetAttribute("PetSlotsBought") or 0, (player:GetAttribute("PetSlotsKept") or 0) - start)
		return start + bought, Mascots.NextSlotPrice(bought)
	end
	local function kindOf(tab: string): string
		return if tab == "Bags" then "Bag" else "Ball"
	end

	-- ===== Fill one card =====
	local function setRing(card: Card, look: Look, isBest: boolean, rarity: string, dim: boolean)
		if card.StopStripes then
			card.StopStripes()
			card.StopStripes = nil
		end
		local mythic = rarity == "Mythic" and not dim
		local color: Color3? = if isBest then PAINT.Gold[1] elseif look.ring and not dim then look.ring else nil
		card.GoldRing.Visible = color ~= nil or mythic
		card.InkRing.Visible = card.GoldRing.Visible
		if mythic and not isBest then
			card.ColorRing.Color = WHITE
			card.StopStripes = slideStripes(card.ColorRing)
		elseif color then
			card.ColorRing.Color = color
		end
		card.ColorRing.Thickness = if isBest or mythic then 6 else 5
		local inkStroke = card.InkRing:FindFirstChildOfClass("UIStroke") :: UIStroke
		-- (the ink ring sits just outside the colour ring)
		local out = card.ColorRing.Thickness
		card.InkRing.Position = UDim2.fromOffset(-out, -out)
		card.InkRing.Size = UDim2.new(1, out * 2, 1, out * 2)
		inkStroke.Thickness = 3
	end

	local function setNext(card: Card, on: boolean)
		card.NextRing.Visible = on
		if on and not card.StopPulse then
			local s = card.NextRing:FindFirstChildOfClass("UIStroke") :: UIStroke
			s.Transparency = 0.75
			local tween = TweenService:Create(
				s,
				TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0 }
			)
			tween:Play()
			card.StopPulse = function()
				tween:Cancel()
			end
		elseif not on and card.StopPulse then
			card.StopPulse()
			card.StopPulse = nil
		end
	end

	local function paintButton(card: Card, paint: { Color3 }, words: string, icon: string?)
		card.Button:Paint(paint)
		card.ButtonText.Text = words
		-- (the Robux glyph only draws in Builder Sans)
		card.ButtonFont = card.ButtonFont or card.ButtonText.FontFace
		card.ButtonText.FontFace = if string.find(words, ROBUX_GLYPH, 1, true)
			then Font.fromEnum(Enum.Font.BuilderSansBold)
			else card.ButtonFont
		card.ButtonIcon.Visible = icon ~= nil
		if icon then
			card.ButtonIcon.Image = SlKit.Icon(icon)
		end
	end

	local function showModel(card: Card, kind: string, step: number, tint: Color3)
		for s, view in card.Views do
			view.Visible = kind == "Ball" and s == step
		end
		card.BagImage.Visible = kind ~= "Ball"
		if kind == "Ball" then
			local view = ballView(card, step)
			if view then
				view.ImageColor3 = tint
			end
		else
			card.BagImage.Image = SlKit.Icon(if kind == "PetSlot" then "hud_pets" else bagIcon(step)) -- (InfBag: step = the top bag)
			card.BagImage.ImageColor3 = tint
		end
	end

	local function setLook(card: Card, look: Look)
		card.Art.BackgroundColor3 = look.c
		card.Rays.ImageColor3 = look.l
	end

	local function setChip(frame: Frame, words: string?, color: Color3?)
		frame.Visible = words ~= nil
		if words then
			(frame:FindFirstChild("Words") :: TextLabel).Text = words
			if color then
				frame.BackgroundColor3 = color
			end
		end
	end

	local function fillLadder(card: Card, kind: string, step: number)
		local have, mask, rebirths, zones = ladderInfo(kind)
		local coins = player:GetAttribute("Coins") or 0
		local state = CoreLadder.State(kind, step, have, mask, zones)
		local owned = state == "Best" or state == "Owned"
		local locked = state == "Locked"
		local skipped = state == "Skipped"
		local bestStep = CoreLadder.BuyBest(kind, have, coins, rebirths, zones)
		local unknown = not owned and not locked and not skipped and step > have + 1 + AHEAD
		local isBest = not owned and not locked and not unknown and step == bestStep
		local isNext = state == "Next" and not isBest
		local equipped = if kind == "Ball" then step == lookStep() else state == "Best"
		local price = CoreLadder.PriceOf(kind, step, rebirths)
		local afford = Currency.CanAfford(coins, price)
		local rarity = rarityOf(kind, step)
		local dim = unknown or locked
		local look = if dim then DIM else LOOK[rarity] or LOOK.Common
		card.Kind, card.Step, card.State = kind, step, state
		card.Owned, card.Equipped, card.Afford = owned, equipped, afford
		setLook(card, look)
		setRing(card, look, isBest, rarity, dim)
		setNext(card, isNext)
		showModel(card, kind, step, if unknown then BLACK else WHITE)
		setChip(card.Next, if isNext then "NEXT" else nil)
		setChip(card.Best, if isBest then "BEST" else nil)
		setChip(card.Skipped, if skipped then "SKIPPED" else nil)
		setChip(card.Rarity, if dim then nil else string.upper(rarity), look.chip)
		card.Tick.Visible = owned
		card.Name.Text = if unknown then "???" else string.upper(CoreLadder.Name(kind, step))
		card.StatIcon.Image = SlKit.Icon(if kind == "Ball" then "cur_pin" else "bag_01")
		local amount = Currency.Format(CoreLadder.Stat(kind, step))
		card.Stat.Text = if kind == "Ball" then ("+%s PINS"):format(amount) else ("HOLDS %s"):format(amount)
		if equipped then
			paintButton(card, PAINT.Navy, "EQUIPPED", "ui_tick")
		elseif owned and kind == "Ball" then
			paintButton(card, PAINT.Blue, "EQUIP")
		elseif owned then
			paintButton(card, PAINT.Dark, "OWNED")
		else
			paintButton(
				card,
				if afford then PAINT.Green else PAINT.Red,
				if price <= 0 then "FREE" else Currency.Format(price),
				"cur_coin"
			)
		end
		card.Lock.Visible = locked
		card.LockText.Text = ("ZONE %d"):format(CoreLadder.Zone(kind, step))
	end

	local function fillPetSlot(card: Card)
		local have, price = petSlotInfo()
		local coins = player:GetAttribute("Coins") or 0
		local afford = price ~= nil and Currency.CanAfford(coins, price)
		card.Kind, card.Step, card.State = "PetSlot", 1, if price then "Next" else "Owned"
		card.Owned, card.Equipped, card.Afford = price == nil, false, afford
		local look = LOOK.PetSlot
		setLook(card, look)
		setRing(card, look, false, "PetSlot", false)
		setNext(card, false)
		showModel(card, "PetSlot", 1, WHITE)
		setChip(card.Next, nil)
		setChip(card.Best, nil)
		setChip(card.Skipped, nil)
		setChip(card.Rarity, nil)
		card.Tick.Visible = price == nil
		card.Name.Text = if price then ("PET SLOT %d"):format(have + 1) else "PET SLOTS"
		card.StatIcon.Image = SlKit.Icon("hud_pets")
		card.Stat.Text = if price then "+1 PET OUT" else ("%d PETS OUT"):format(have)
		if price then
			paintButton(card, if afford then PAINT.Green else PAINT.Red, Currency.Format(price), "cur_coin")
		else
			paintButton(card, PAINT.Navy, "ALL BOUGHT", "ui_tick")
		end
		card.Lock.Visible = false
	end

	-- Launch changes (owner 2026-11-03): the INFINITE BAG pass card at the end of the Bags tab (Robux, buys anywhere)
	local function fillInfBag(card: Card)
		local pass = Store.Pass("InfiniteBag")
		local owned = Store.Owns(player, "InfiniteBag")
		local excluded = Store.ExcludedBy(player, pass)
		card.Kind, card.Step, card.State = "InfBag", 1, if owned then "Owned" else "Next"
		card.Owned, card.Equipped, card.Afford = owned or excluded ~= nil, false, true
		local look = LOOK.InfBag
		setLook(card, look)
		setRing(card, look, false, "InfBag", false)
		setNext(card, false)
		showModel(card, "Bag", #CORE.BagSizes, WHITE)
		setChip(card.Next, nil)
		setChip(card.Best, nil)
		setChip(card.Skipped, nil)
		setChip(card.Rarity, nil)
		card.Tick.Visible = owned
		card.Name.Text = "INFINITE BAG"
		card.StatIcon.Image = SlKit.Icon("hud_sell")
		card.Stat.Text = "NO LIMIT, SELLS ITSELF"
		if owned then
			paintButton(card, PAINT.Navy, "OWNED", "ui_tick")
		elseif excluded then
			paintButton(card, PAINT.Navy, "NOT NEEDED", nil)
		else
			paintButton(card, PAINT.Green, ROBUX_GLYPH .. " " .. tostring(pass and pass.Robux or 0), nil)
		end
		card.Lock.Visible = false
	end

	-- What the current zone page shows: its steps (+ the PET SLOT card on the Bags tab)
	local function pageItems(): { { Kind: string, Step: number } }
		local kind = kindOf(currentTab)
		local items = {}
		for step = 1, CoreLadder.Count(kind) do
			if CoreLadder.Zone(kind, step) == currentZone then
				table.insert(items, { Kind = kind, Step = step })
			end
		end
		if kind == "Bag" and Mascots.StatsOn() and #Config.PetStats.SlotPrices > 0 then
			table.insert(items, { Kind = "PetSlot", Step = 1 })
		end
		if kind == "Bag" and Store.Active() and Store.Ready(Store.Pass("InfiniteBag")) then
			table.insert(items, { Kind = "InfBag", Step = 1 })
		end
		return items
	end

	local function fillFooter(kind: string)
		local here = ctx.AtShop()
		buyBest.Holder.Visible = here
		goShop.Holder.Visible = not here
		hint.Visible = not here
		local have, _, rebirths, zones = ladderInfo(kind)
		local step, price = CoreLadder.BuyBest(kind, have, player:GetAttribute("Coins"), rebirths, zones)
		bestStatIcon.Image = SlKit.Icon(if kind == "Ball" then "cur_pin" else "bag_01")
		if step then
			buyBest:Paint(PAINT.Green)
			bestStat.Visible = true
			bestPriceIcon.Visible = true
			local amount = Currency.Format(CoreLadder.Stat(kind, step))
			bestStatText.Text = if kind == "Ball" then "+" .. amount else amount
			bestPriceText.Text = Currency.Format(price)
		else
			buyBest:Paint(PAINT.Grey)
			bestStat.Visible = false
			local nextStep, nextPrice
			if kind == "Ball" then
				nextStep, nextPrice = CoreLadder.NextBall(have, rebirths)
			else
				nextStep, nextPrice = CoreLadder.NextBag(have, rebirths)
			end
			-- (Polish v2 T1: the next one is in a zone that isn't open: say so, not a price you may already have)
			local locked = nextStep ~= nil and not CoreLadder.ZoneOpen(kind, nextStep, zones)
			bestPriceIcon.Visible = not locked
			bestPriceText.Text = if not nextStep
				then "MAX"
				elseif locked then ("OPEN ZONE %d"):format(CoreLadder.Zone(kind, nextStep))
				else Currency.Format(nextPrice)
		end
	end

	-- Red dots: balls / bags you could buy now (open zones, above your best); PASSES until you look once
	local passesSeen = false
	local function ups(kind: string): number
		local have, mask, rebirths, zones = ladderInfo(kind)
		local coins = player:GetAttribute("Coins") or 0
		local n = 0
		for step = have + 1, CoreLadder.Count(kind) do
			if
				not CoreLadder.Owns(mask, step)
				and CoreLadder.ZoneOpen(kind, step, zones)
				and Currency.CanAfford(coins, CoreLadder.PriceOf(kind, step, rebirths))
			then
				n += 1
			end
		end
		return n
	end
	local function passesLeft(): number
		if passesSeen or not Store.Active() then
			return 0
		end
		local n = 0
		for _, id in SHOP.Gamepasses or {} do
			if Store.Ready(Store.Pass(id)) and not Store.Owns(player, id) then
				n += 1
			end
		end
		return n
	end
	local function setDot(id: string, n: number)
		local tab = tabs[id]
		if tab then
			local was = tab.Dot.Visible
			tab.Dot.Visible = n > 0
			if n > 0 and tab.Dot:GetAttribute("Count") ~= n then
				tab.Dot:SetAttribute("Count", n)
			end
			if n > 0 and not was then
				SlKit.PopIn(tab.Dot)
			end
		end
	end

	-- The BALLS tab icon: the ball you throw, in 3D
	local tabBallStep = 0
	local function fillTabBall()
		local step = lookStep()
		local tab = tabs.Balls
		if not tab or step == tabBallStep then
			return
		end
		tabBallStep = step
		local old = tab.Icon:FindFirstChild("Ball3D")
		if old then
			old:Destroy()
		end
		local ball = Balls.Get(CORE.Balls[step].Ball)
		if ball then
			local view = BallView.New(ball, { Margin = 1.0 })
			view.Size = UDim2.fromScale(1, 1)
			view.Parent = tab.Icon
		end
	end

	-- A panel of one colour with lighter rays behind its contents (CanvasGroup keeps the round corners), ink edge
	local function rayPanel(
		parent: Instance,
		name: string,
		size: UDim2,
		position: UDim2,
		raySize: number,
		centre: Vector2
	)
		local holder =
			make("Frame", { Name = name, BackgroundTransparency = 1, Size = size, Position = position }, parent)
		local art = make("CanvasGroup", {
			Name = "Art",
			BackgroundColor3 = PAINT.Gold[1],
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, holder)
		corner(art, 16)
		local rays = SlKit.Image(art, "bg_rays", 0, {
			Name = "Rays",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(centre.X, centre.Y),
			Size = UDim2.fromOffset(raySize, raySize),
			ImageColor3 = PAINT.Gold[3],
			ZIndex = 1,
		})
		local edge = make(
			"Frame",
			{ Name = "Edge", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8 },
			holder
		)
		corner(edge, 16)
		stroke(edge, INK, 3)
		return holder, art, rays
	end
	-- Text size that fits `words` in `width` (Fredoka One capitals are ~0.62 em wide)
	local function fitSize(words: string, width: number, biggest: number): number
		return math.clamp(math.floor(width / (math.max(#words, 1) * 0.62)), 14, biggest)
	end

	-- ===== V4: the REBIRTH tab (design 2a desktop / 2b phone / 2c away from the shop) =====
	-- Rank badge now > next (rank_01..17 = Config.CoreLoop.Rebirth.Ranks in order; past the list the last badge),
	-- the two boosts after this rebirth (x COINS / x PINS = 1 + Bonus / PinBonus x rebirths, the rebirth part of
	-- Boosts), RESETS / KEEPS rows, the coins bar and HOLD TO REBIRTH (gold, bouncing + pulse ring when you can pay at
	-- the shop; dark + padlock when not; blue GO TO SHOP away from the stall). Holding fills it in SHOP.HoldSeconds,
	-- then the server rebirths and RebirthController plays the REBIRTH! moment.
	local REBIRTH = CORE.Rebirth
	local PAD = 20
	local INNER_W = W - (24 + TAB_W + 20) - 24 - PAD * 2 -- 958
	local INNER_H = H - 96 - PAD * 2 -- 624
	local BOTTOM_H = 106
	local TOP_H = INNER_H - 22 - BOTTOM_H -- 496
	local RANK_W = 420
	local rebirthPage = make("Frame", {
		Name = "RebirthPage",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(PAD, PAD),
		Size = UDim2.fromOffset(INNER_W, INNER_H),
		Visible = false,
	}, well)

	-- rank now > next
	local rankPanel, rankArt, rankRays = rayPanel(
		rebirthPage,
		"Rank",
		UDim2.fromOffset(RANK_W, TOP_H),
		UDim2.fromOffset(0, 0),
		900,
		Vector2.new(0.42, 0.5)
	)
	local rankNowIcon = SlKit.Image(rankPanel, "rank_01", 200, {
		Name = "NowBadge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(122, TOP_H / 2 - 30),
		ZIndex = 4,
	})
	local rankNowName = text(rankPanel, "", 30, WHITE, {
		Name = "NowName",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(122, TOP_H / 2 + 76),
		Size = UDim2.fromOffset(236, 40),
		ZIndex = 4,
	})
	SlKit.Image(rankPanel, "ui_arrow", 62, {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(262, TOP_H / 2 - 30),
		ZIndex = 4,
	})
	local rankNextIcon = SlKit.Image(rankPanel, "rank_02", 118, {
		Name = "NextBadge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(345, TOP_H / 2 - 18),
		ZIndex = 4,
	})
	local rankNextName = text(rankPanel, "", 24, WHITE, {
		Name = "NextName",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(345, TOP_H / 2 + 46),
		Size = UDim2.fromOffset(140, 34),
		ZIndex = 4,
	})

	-- what you get: two gold tiles
	local RIGHT_X = RANK_W + 20
	local RIGHT_W = INNER_W - RIGHT_X
	local TILE_W = (RIGHT_W - 16) / 2
	local rewardText: { [string]: TextLabel } = {}
	for i, def in { { Id = "Coins", Icon = "cur_coin" }, { Id = "Pins", Icon = "cur_pin" } } do
		local tile = rayPanel(
			rebirthPage,
			"Get" .. def.Id,
			UDim2.fromOffset(TILE_W, 190),
			UDim2.fromOffset(RIGHT_X + (i - 1) * (TILE_W + 16), 0),
			520,
			Vector2.new(0.5, 0.42)
		)
		SlKit.Image(tile, def.Icon, 108, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 22),
			ZIndex = 4,
		})
		rewardText[def.Id] = text(tile, "", 34, WHITE, {
			Name = "Amount",
			Position = UDim2.fromOffset(0, 128),
			Size = UDim2.new(1, 0, 0, 44),
			ZIndex = 4,
		})
	end

	-- RESETS (red) / KEEPS (green): a word + the icons of what goes / stays
	local function iconRow(name: string, y: number, paint: { Color3 }, words: string): Frame
		local block = SlKit.Block(rebirthPage, {
			Name = name,
			Size = UDim2.fromOffset(RIGHT_W, 78),
			Radius = 16,
			Paint = paint,
			Lip = 0,
		})
		block.Holder.Position = UDim2.fromOffset(RIGHT_X, y)
		text(block.Content, words, 24, WHITE, {
			Name = "Word",
			Position = UDim2.fromOffset(16, 0),
			Size = UDim2.new(0, 116, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local icons = make("Frame", {
			Name = "Icons",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(16 + 116 + 12, 0),
			Size = UDim2.new(1, -150, 1, 0),
			ZIndex = 6,
		}, block.Content)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, icons)
		return icons
	end
	local resets = iconRow("Resets", 190 + 14, PAINT.Red, "RESETS")
	SlKit.Image(resets, "cur_coin", 56, { LayoutOrder = 1 })
	do -- (no ball icon in the sheet: the first ball in 3D, like the BALLS tab)
		local box = make(
			"Frame",
			{ Name = "Ball", BackgroundTransparency = 1, Size = UDim2.fromOffset(56, 56), LayoutOrder = 2 },
			resets
		)
		local ball = Balls.Get(CORE.Balls[1].Ball)
		if ball then
			local view = BallView.New(ball, { Margin = 1.0 })
			view.Size = UDim2.fromScale(1, 1)
			view.ZIndex = 6
			view.Parent = box
		end
	end
	SlKit.Image(resets, "bag_01", 56, { LayoutOrder = 3 })
	SlKit.Image(resets, "hud_teleport", 56, { LayoutOrder = 4 }) -- zones
	SlKit.Image(resets, "cur_pin", 56, { LayoutOrder = 5 })
	local keeps = iconRow("Keeps", 190 + 14 + 78 + 14, PAINT.Green, "KEEPS")
	SlKit.Image(keeps, "hud_pets", 56, { LayoutOrder = 1 })
	SlKit.Image(keeps, "hud_passes", 56, { LayoutOrder = 2 })
	local keepRank = SlKit.Image(keeps, "rank_01", 56, { LayoutOrder = 3 })

	-- the coins bar (coin hanging off its left end)
	local BTN_W = 420
	local barX = 30
	local barW = INNER_W - BTN_W - 24 - barX
	local bar = make("CanvasGroup", {
		Name = "CoinsBar",
		BackgroundColor3 = NIGHT,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(barX, TOP_H + 22 + BOTTOM_H / 2),
		Size = UDim2.fromOffset(barW, 64),
	}, rebirthPage)
	corner(bar, 32)
	local barFill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = PAINT.Gold[1],
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, bar)
	make("Frame", {
		Name = "Strip",
		BackgroundColor3 = PAINT.Gold[3],
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 3),
	}, barFill)
	local barText = text(bar, "", 30, WHITE, { Name = "Amount", ZIndex = 4 })
	local barEdge = make("Frame", {
		Name = "Edge",
		BackgroundTransparency = 1,
		AnchorPoint = bar.AnchorPoint,
		Position = bar.Position,
		Size = bar.Size,
		ZIndex = 2,
	}, rebirthPage)
	corner(barEdge, 32)
	stroke(barEdge, INK, 3)
	SlKit.Image(rebirthPage, "cur_coin", 84, {
		Name = "BarCoin",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(barX - 36, TOP_H + 22 + BOTTOM_H / 2),
		ZIndex = 9,
	})

	-- HOLD TO REBIRTH / GO TO SHOP (a wrapper bobs so shakes and the press don't fight it)
	local holdWrap = make("Frame", {
		Name = "HoldWrap",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromOffset(INNER_W, TOP_H + 22 + BOTTOM_H / 2),
		Size = UDim2.fromOffset(BTN_W, 106),
	}, rebirthPage)
	local holdRing = make("Frame", {
		Name = "ReadyRing",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-11, -11),
		Size = UDim2.new(1, 22, 1, 16),
		ZIndex = 0,
		Visible = false,
	}, holdWrap)
	corner(holdRing, 28)
	local holdRingStroke = stroke(holdRing, PAINT.Gold[3], 6)
	TweenService
		:Create(holdRingStroke, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Transparency = 0.8,
		})
		:Play()
	local hold = SlKit.Block(holdWrap, {
		Name = "HoldRebirth",
		Button = true,
		Size = UDim2.fromScale(1, 1),
		Radius = 18,
		Paint = PAINT.Gold,
	})
	local holdClip = make("CanvasGroup", {
		Name = "Clip",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
	}, hold.Content)
	corner(holdClip, 15)
	local holdFill = make("Frame", {
		Name = "HoldFill",
		BackgroundColor3 = hex("FFF1B0"),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, holdClip)
	make("Frame", {
		Name = "Edge",
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 3, 1, 0),
	}, holdFill)
	local holdRow = hrow(hold.Content, 10)
	holdRow.ZIndex = 6
	local holdIcon = SlKit.Image(holdRow, "hud_rebirth", 60, { LayoutOrder = 1 })
	local holdText = word(holdRow, "HOLD TO REBIRTH", 32)

	local holdFrom: number? = nil
	local holdState = "Locked" -- Ready / Locked / Away
	local errorUntil = 0
	local stopBob: (() -> ())? = nil
	local rebirthBusy = false

	local function rebirthInfo()
		local done = player:GetAttribute("Rebirths") or 0
		local price = Rebirth.CorePrice(done)
		return done, price, Currency.CanAfford(player:GetAttribute("Coins"), price)
	end
	local function rankIcon(index: number): string
		return ("rank_%02d"):format(math.clamp(index, 1, 17))
	end
	local function fillRebirth()
		local done, price, can = rebirthInfo()
		local now, after = Rebirth.Rank(done), Rebirth.Rank(done + 1)
		-- (near-white ranks like Rookie / Regular get the design's silver panel so the white words still read)
		local _, saturation = now.Color:ToHSV()
		local panel = if saturation < 0.25 then hex("B8C2CC") else now.Color
		rankArt.BackgroundColor3 = panel
		rankRays.ImageColor3 = if saturation < 0.25 then hex("D6DDE4") else panel:Lerp(WHITE, 0.4)
		rankNowIcon.Image = SlKit.Icon(rankIcon(now.Index))
		rankNextIcon.Image = SlKit.Icon(rankIcon(after.Index))
		keepRank.Image = rankNowIcon.Image
		local nowName, nextName = string.upper(now.Name), string.upper(after.Name)
		rankNowName.Text = nowName
		rankNowName.TextSize = fitSize(nowName, 236, 30)
		rankNextName.Text = nextName
		rankNextName.TextSize = fitSize(nextName, 150, 24)
		local function times(per: number): string
			return Currency.FormatMultiplier(1 + per * (done + 1))
		end
		rewardText.Coins.Text = times(REBIRTH.Bonus) .. " COINS"
		rewardText.Pins.Text = times(REBIRTH.PinBonus or REBIRTH.Bonus) .. " PINS"
		local coins = tonumber(player:GetAttribute("Coins")) or 0
		barFill.Size = UDim2.fromScale(math.clamp(coins / math.max(price, 1), 0, 1), 1)
		barText.Text = ("%s / %s"):format(Currency.Format(math.min(coins, price)), Currency.Format(price))
		local here = ctx.AtShop()
		holdState = if not here then "Away" elseif can then "Ready" else "Locked"
		if os.clock() < errorUntil then
			return
		end
		if holdState == "Away" then
			hold:Paint(PAINT.Blue)
			holdIcon.Image = SlKit.Icon("hud_shop")
			holdText.Text = "GO TO SHOP"
		elseif holdState == "Ready" then
			hold:Paint(PAINT.Gold)
			holdIcon.Image = SlKit.Icon("hud_rebirth")
			holdText.Text = "HOLD TO REBIRTH"
		else
			hold:Paint(PAINT.Dark)
			holdIcon.Image = SlKit.Icon("ui_lock")
			holdText.Text = "HOLD TO REBIRTH"
		end
		local ready = holdState == "Ready" and not holdFrom
		holdRing.Visible = ready
		if ready and not stopBob then
			stopBob = SlKit.Bob(holdWrap, 6, 1.0)
		elseif not ready and stopBob then
			stopBob()
			stopBob = nil
		end
	end

	local function endHold()
		holdFrom = nil
		SlKit.Tween(holdFill, 0.2, "Soft", { Size = UDim2.fromScale(0, 1) })
		fillRebirth()
	end
	local function rebirthNow()
		local done = rebirthInfo()
		rebirthBusy = true
		local ok, result = pcall(ctx.Rebirth.InvokeServer, ctx.Rebirth)
		rebirthBusy = false
		holdFrom = nil
		holdFill.Size = UDim2.fromScale(0, 1)
		if ok and type(result) == "table" and result.Ok then
			ShopV2.SetOpen(false)
			if ctx.Party then
				task.delay(0.25, ctx.Party, done + 1, nil)
			end
		else
			Sfx.Play("Error", 1, 0.6)
			SlKit.Shake(hold.Holder, 8, 0, 0.3)
			holdText.Text = if ok
					and type(result) == "table"
					and result.Error
				then string.upper(tostring(result.Error))
				else "TRY AGAIN"
			holdText.TextSize = fitSize(holdText.Text, BTN_W - 110, 32)
			errorUntil = os.clock() + 2
			task.delay(2, function()
				holdText.TextSize = 32
				fillRebirth()
			end)
		end
	end
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end
	hold.Holder.InputBegan:Connect(function(input)
		if not isPress(input) or rebirthBusy or holdState == "Away" then
			return
		end
		if holdState ~= "Ready" then
			Sfx.Play("Error", 1, 0.5)
			SlKit.Shake(hold.Holder, 8, 0, 0.3)
			return
		end
		holdFrom = os.clock()
		fillRebirth()
	end)
	hold.Holder.InputEnded:Connect(function(input)
		if holdFrom and isPress(input) then
			endHold()
		end
	end)
	hold.Holder.MouseLeave:Connect(function()
		if holdFrom then
			endHold()
		end
	end)
	local lastRebirthGo = 0
	hold.Holder.Activated:Connect(function()
		if holdState == "Away" and os.clock() - lastRebirthGo >= CORE.Teleport.Cooldown then
			lastRebirthGo = os.clock()
			ctx.GoToShop()
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not holdFrom then
			return
		end
		local t = (os.clock() - holdFrom) / (SHOP.HoldSeconds or 1.5)
		holdFill.Size = UDim2.fromScale(math.clamp(t, 0, 1), 1)
		if t >= 1 then
			holdFrom = nil
			task.spawn(rebirthNow)
		end
	end)

	-- ===== V4: the PASSES tab (design 3a / 3b): 4-wide cards, pass art on its colour + rays, name, Robux price
	-- (green) or OWNED (navy + tick). Tap a card = Roblox's buy prompt (StoreBuy). Passes without a Creator Hub ID
	-- only show in Studio (Store.Ready), with a NO ID YET chip.
	local PASS_ORDER =
		{ "DoubleCoins", "DoublePins", "VIP", "AutoBowl", "Lucky", "SuperLucky", "PetSlots", "TripleHatch" }
	local PASS_LOOK: { [string]: { string } } = {
		DoubleCoins = { "FFC93A", "FFE07A", "pass_2x_coins" },
		DoublePins = { "4BE07A", "8BF0A8", "pass_2x_pins" },
		VIP = { "FF4FA3", "FF8CC4", "pass_vip" },
		AutoBowl = { "3AA8FF", "7CC6FF", "pass_auto_bowl" },
		Lucky = { "4BE07A", "8BF0A8", "pass_lucky" },
		SuperLucky = { "FFC93A", "FFE07A", "pass_super_lucky" },
		PetSlots = { "FF4F8B", "FF8DB4", "pass_pet_slots" },
		TripleHatch = { "FF9F1C", "FFC46B", "pass_triple_hatch" },
	}
	local PASS_ART = 196
	local passPage = make("ScrollingFrame", {
		Name = "PassesPage",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.TileStrip,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, well)
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(220, PASS_ART + 3 + 10 + 30 + 8 + 62 + 16 + 6),
		CellPadding = UDim2.fromOffset(18, 24),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, passPage)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 22),
		PaddingBottom = UDim.new(0, 30),
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
	}, passPage)
	type PassCard = {
		Id: string,
		Block: any,
		Tick: ImageLabel,
		Button: any,
		Glyph: TextLabel,
		TickIcon: ImageLabel,
		Label: TextLabel,
	}
	local passCards: { PassCard } = {}
	local passIds = {}
	for _, id in PASS_ORDER do
		if table.find(SHOP.Gamepasses or {}, id) then
			table.insert(passIds, id)
		end
	end
	for _, id in SHOP.Gamepasses or {} do
		if not table.find(passIds, id) then
			table.insert(passIds, id)
		end
	end
	for order, id in passIds do
		local pass = Store.Pass(id)
		if not Store.Ready(pass) then
			continue -- (no Creator Hub ID yet: hidden in the live game)
		end
		local look = PASS_LOOK[id] or PASS_LOOK.DoubleCoins
		local block = SlKit.Block(passPage, {
			Name = "Pass_" .. id,
			Button = true,
			Size = UDim2.fromScale(1, 1),
			Radius = 16,
			Paint = PAINT.Tile,
		})
		block.Holder.LayoutOrder = order
		local content = block.Content
		local art = make("CanvasGroup", {
			Name = "Art",
			BackgroundColor3 = hex(look[1]),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, PASS_ART + 14),
			ZIndex = 1,
		}, content)
		corner(art, 13)
		SlKit.Image(art, "bg_rays", 0, {
			Name = "Rays",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, PASS_ART / 2),
			Size = UDim2.fromOffset(380, 380),
			ImageColor3 = hex(look[2]),
			ZIndex = 1,
		})
		make("Frame", {
			Name = "Under",
			BackgroundColor3 = C.Tile,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, PASS_ART),
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 2,
		}, content)
		make("Frame", {
			Name = "Line",
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, PASS_ART),
			Size = UDim2.new(1, 0, 0, 3),
			ZIndex = 3,
		}, content)
		SlKit.Image(content, look[3], 164, {
			Name = "PassArt",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, PASS_ART / 2),
			ZIndex = 4,
		})
		local tick = SlKit.Image(content, "ui_tick", 52, {
			Name = "Tick",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			ZIndex = 6,
			Visible = false,
		})
		if (tonumber(pass.PassId) or 0) <= 0 then
			local note = chip(content, "NO ID YET", PAINT.Red[1], false)
			note.Position = UDim2.fromOffset(8, 8)
			note.ZIndex = 6
			note.Visible = true
		end
		local name = string.upper(pass.Name or id)
		text(content, name, fitSize(name, 196, 24), WHITE, {
			Name = "PassName",
			Position = UDim2.fromOffset(8, PASS_ART + 13),
			Size = UDim2.new(1, -16, 0, 30),
			ZIndex = 5,
		})
		local button = SlKit.Block(content, {
			Name = "Buy",
			Size = UDim2.new(1, -24, 0, 62),
			Radius = 14,
			Paint = PAINT.Green,
		})
		button.Holder.Position = UDim2.fromOffset(12, PASS_ART + 13 + 38)
		button.Holder.ZIndex = 5
		local row = hrow(button.Content, 6)
		-- (the Robux glyph only draws in Builder Sans)
		local glyph = text(row, ROBUX_GLYPH, 30, WHITE, {
			Name = "Robux",
			FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = 1,
		})
		local tickIcon = SlKit.Image(row, "ui_tick", 36, { LayoutOrder = 1, Visible = false })
		local label = word(row, tostring(pass.Robux), 26)
		table.insert(passCards, {
			Id = id,
			Block = block,
			Tick = tick,
			Button = button,
			Glyph = glyph,
			TickIcon = tickIcon,
			Label = label,
		})
		block.Holder.Activated:Connect(function()
			if Store.Owns(player, id) then
				return
			end
			if not ctx.StoreBuy then
				Sfx.Play("Error", 1, 0.6)
				SlKit.Shake(block.Holder, 8, 0, 0.3)
				return
			end
			ctx.StoreBuy:FireServer(id)
		end)
	end
	local function fillPasses()
		for _, card in passCards do
			local owned = Store.Owns(player, card.Id)
			card.Tick.Visible = owned
			card.Button:Paint(if owned then PAINT.Navy else PAINT.Green)
			card.Glyph.Visible = not owned
			card.TickIcon.Visible = owned
			card.Label.Text = if owned then "OWNED" else tostring(Store.Pass(card.Id).Robux)
		end
	end

	function refresh()
		local kind = kindOf(currentTab)
		for id, tab in tabs do
			tab.Block:Paint(if id == currentTab then PAINT.Gold else PAINT.Tile)
		end
		-- (V4: REBIRTH / PASSES swap the zone row, grid and footer for their own page)
		local ladder = currentTab == "Balls" or currentTab == "Bags"
		zoneRow.Visible = ladder
		grid.Visible = ladder
		footer.Visible = ladder
		rebirthPage.Visible = currentTab == "Rebirth"
		passPage.Visible = currentTab == "Gamepasses"
		if currentTab == "Gamepasses" then
			passesSeen = true
		end
		if not ladder then
			if currentTab == "Rebirth" then
				fillRebirth()
			else
				fillPasses()
			end
			setDot("Balls", ups("Ball"))
			setDot("Bags", ups("Bag"))
			setDot("Gamepasses", passesLeft())
			fillTabBall()
			return
		end
		local zones = CoreLadder.ZonesOpen(player:GetAttribute("CoreZonesOpen"))
		for zone, tile in zoneTiles do
			local locked = zone > zones
			local active = zone == currentZone
			tile.Block:Paint(if active then PAINT.Gold elseif locked then PAINT.Night else PAINT.Tile)
			tile.Ring.Visible = active
			tile.Lock.Visible = locked
			if tile.View then
				tile.View.ImageColor3 = if locked then BLACK else WHITE
				tile.View.ImageTransparency = if locked then 0.65 else 0
			end
		end
		local info = CoreLadder.ZoneInfo(currentZone)
		zoneName.Text = string.upper(if info then info.Name else "")
		local items = pageItems()
		for index, item in items do
			local card = cards[index]
			if not card then
				card = makeCard(index)
				cards[index] = card
				local c = card
				c.Holder.Activated:Connect(function()
					ShopV2.Tap(c)
				end)
			end
			card.Holder.Visible = true
			if card.RevealUntil and os.clock() < card.RevealUntil then
				continue
			end
			if item.Kind == "PetSlot" then
				fillPetSlot(card)
			elseif item.Kind == "InfBag" then
				fillInfBag(card)
			else
				fillLadder(card, item.Kind, item.Step)
			end
		end
		for index = #items + 1, #cards do
			cards[index].Holder.Visible = false
			setNext(cards[index], false)
		end
		fillFooter(kind)
		setDot("Balls", ups("Ball"))
		setDot("Bags", ups("Bag"))
		setDot("Gamepasses", passesLeft())
		fillTabBall()
	end

	-- Opens a tab on the zone of your next ball / bag (or your best one's)
	local function focusZone(kind: string)
		local have, _, _, zones = ladderInfo(kind)
		local target = math.min(have + 1, CoreLadder.Count(kind))
		local zone = CoreLadder.Zone(kind, target)
		if not CoreLadder.ZoneOpen(kind, target, zones) then
			zone = CoreLadder.Zone(kind, have)
		end
		currentZone = zone
	end

	-- Scrolls the grid so a card's row is at the top (screen pixels, so it waits for the open motion to settle)
	local function scrollTo(card: Card?)
		if not card then
			grid.CanvasPosition = Vector2.zero
			return
		end
		local s = card.Holder.AbsoluteSize.X / CARD_W
		local y = card.Holder.AbsolutePosition.Y - grid.AbsolutePosition.Y + grid.CanvasPosition.Y - 16 * s
		grid.CanvasPosition = Vector2.new(0, math.max(y, 0))
	end
	-- Keeps the BEST / NEXT card's row in view
	function scrollToFocus()
		local focus: Card? = nil
		for _, card in cards do
			if card.Holder.Visible and (card.Best.Visible or card.Next.Visible) then
				focus = card
				break
			end
		end
		scrollTo(focus)
	end

	function setTab(id: string)
		if id ~= currentTab then
			if holdFrom then
				endHold()
			end
			currentTab = id
			local ladder = id == "Balls" or id == "Bags"
			if ladder then
				focusZone(kindOf(id))
			end
			if ctx.OnTab then
				ctx.OnTab(id)
			end
			refresh()
			UiFx.Pop(if ladder then grid elseif id == "Rebirth" then rebirthPage else passPage, 1.02, 0.15)
			if ladder then
				task.defer(scrollToFocus)
			end
		end
	end

	-- ===== The reveal (design): flash, colour floods in, rays spin, ring burst, name drops in, NEW! stamp =====
	local spinning: { ViewportFrame } = {}
	local function reveal(card: Card)
		local kind, step = card.Kind :: string, card.Step :: number
		local seconds = math.min(SHOP.RevealSeconds or 1.6, 1.9)
		card.RevealUntil = os.clock() + seconds
		local look = LOOK[rarityOf(kind, step)] or LOOK.Common
		local cover = make("Frame", {
			Name = "Reveal",
			BackgroundColor3 = C.Tile,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 20,
		}, card.Block.Content)
		corner(cover, 13)
		local top = make("CanvasGroup", {
			Name = "Top",
			BackgroundColor3 = NIGHT,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, ART_H + 14),
			ZIndex = 1,
		}, cover)
		corner(top, 13)
		local flood = make("Frame", {
			Name = "Flood",
			BackgroundColor3 = look.c,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, top)
		local rays = SlKit.Image(top, "bg_rays", 0, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, ART_H / 2),
			Size = UDim2.fromOffset(380, 380),
			ImageColor3 = look.l,
			ImageTransparency = 1,
			ZIndex = 2,
		})
		local stopSpin = SlKit.Spin(rays, 6)
		make("Frame", {
			BackgroundColor3 = C.Tile,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, ART_H),
			Size = UDim2.new(1, 0, 0, 16),
			ZIndex = 2,
		}, cover)
		make("Frame", {
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, ART_H),
			Size = UDim2.new(1, 0, 0, 3),
			ZIndex = 3,
		}, cover)
		local centre = UDim2.new(0.5, 0, 0, ART_H / 2 + 2)
		-- the ring burst
		local ring = make("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = centre,
			Size = UDim2.fromOffset(120, 120),
			ZIndex = 4,
			Visible = false,
		}, cover)
		corner(ring, 60)
		local ringStroke = stroke(ring, look.l, 10)
		local ringScale = make("UIScale", { Scale = 0.3 }, ring)
		-- the item: black silhouette that turns into its colours
		local holder = make("Frame", {
			Name = "Item",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = centre,
			Size = UDim2.fromOffset(150, 150),
			ZIndex = 5,
		}, cover)
		local itemScale = make("UIScale", { Scale = 0.85 }, holder)
		local view: GuiObject
		if kind == "Ball" then
			local ball = Balls.Get(CORE.Balls[step].Ball)
			local v = BallView.New(ball, { Margin = 1.0 })
			v.Size = UDim2.fromScale(1, 1)
			v.ImageColor3 = BLACK
			v.Parent = holder
			view = v
			table.insert(spinning, v)
		else
			view = SlKit.Image(
				holder,
				bagIcon(step),
				0,
				{ Size = UDim2.fromScale(0.86, 0.86), Position = UDim2.fromScale(0.07, 0.07), ImageColor3 = BLACK }
			)
		end
		local flash = make("Frame", {
			Name = "Flash",
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = centre,
			Size = UDim2.fromOffset(120, 120),
			ZIndex = 6,
		}, cover)
		corner(flash, 60)
		local name = text(cover, string.upper(CoreLadder.Name(kind, step)), 26, WHITE, {
			Name = "ItemName",
			Position = UDim2.fromOffset(8, ART_H + 12),
			Size = UDim2.new(1, -16, 0, 32),
			ZIndex = 5,
			Visible = false,
		})
		local stamp = make("Frame", {
			Name = "New",
			BackgroundColor3 = PAINT.Red[1],
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, 14),
			Size = UDim2.fromOffset(0, 46),
			AutomaticSize = Enum.AutomaticSize.X,
			Rotation = -12,
			ZIndex = 8,
			Visible = false,
		}, cover)
		corner(stamp, 12)
		stroke(stamp, INK, 3)
		make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, stamp)
		text(
			stamp,
			"NEW!",
			28,
			WHITE,
			{ AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), ZIndex = 9 }
		)
		local stampScale = make("UIScale", { Scale = 2.4 }, stamp)

		-- 0.0 white flash
		Sfx.Play("SpinWin", 1.1, 0.7)
		SlKit.Tween(flash, 0.3, "Snap", { BackgroundTransparency = 1 })
		-- 0.2 colour floods in, the item turns from black
		task.delay(0.2, function()
			SlKit.Tween(flood, 0.45, "Snap", { BackgroundTransparency = 0 })
			SlKit.Tween(rays, 0.45, "Snap", { ImageTransparency = 0 })
			SlKit.Tween(view, 0.35, "Snap", { ImageColor3 = WHITE })
			SlKit.Tween(itemScale, 0.35, "Over", { Scale = 1.1 })
			task.delay(0.35, function()
				SlKit.Tween(itemScale, 0.2, "Soft", { Scale = 1 })
			end)
		end)
		-- 0.45 ring burst
		task.delay(0.45, function()
			ring.Visible = true
			SlKit.Tween(ringScale, 0.55, "Snap", { Scale = 2.2 })
			SlKit.Tween(ringStroke, 0.55, "Snap", { Transparency = 1 })
		end)
		-- 0.6 the name drops in
		task.delay(0.6, function()
			name.Visible = true
			name.Position = UDim2.fromOffset(8, ART_H + 12 - 40)
			name.TextTransparency = 1
			SlKit.Tween(name, 0.35, "Over", { Position = UDim2.fromOffset(8, ART_H + 12), TextTransparency = 0 })
			Sfx.Play("Coin", 1, 1.2)
		end)
		-- 0.9 NEW! stamp
		task.delay(0.9, function()
			stamp.Visible = true
			SlKit.Tween(stampScale, 0.2, "Snap", { Scale = 1 })
			Sfx.Play("Click", 1.2)
		end)
		task.delay(seconds, function()
			stopSpin()
			local index = table.find(spinning, view :: any)
			if index then
				table.remove(spinning, index)
			end
			card.RevealUntil = nil
			refresh()
			SlKit.Tween(cover, 0.15, "Soft", { BackgroundTransparency = 1 })
			for _, child in cover:GetDescendants() do
				if child:IsA("GuiObject") then
					child.Visible = false
				end
			end
			task.delay(0.15, cover.Destroy, cover)
		end)
	end

	local function nudgeGoShop()
		Sfx.Play("Error", 1, 0.5)
		SlKit.Pulse(goShop.Holder, 1.12, 0.3)
	end

	local busy = false
	local function bought(card: Card?)
		UiFx.Flash(PAINT.Green[1], 0.12, 0.2)
		UiFx.Confetti(win, 26)
		refresh()
		if card and card.Kind ~= "PetSlot" then
			reveal(card)
		elseif card then
			Sfx.Play("Coin", 1, 1.2)
			UiFx.Pop(card.Holder, 1.12, 0.3)
		end
	end

	-- The card that shows (kind, step) on the open page, if any
	local function cardFor(kind: string, step: number): Card?
		for _, card in cards do
			if card.Holder.Visible and card.Kind == kind and card.Step == step then
				return card
			end
		end
		return nil
	end

	-- A card tap: EQUIP an owned ball (anywhere), buy one you can pay for (at the shop), else shake
	function ShopV2.Tap(card: Card)
		if busy or (card.RevealUntil and os.clock() < card.RevealUntil) then
			return
		end
		local kind = card.Kind
		if kind == "InfBag" then
			-- (launch changes: a Robux pass, bought anywhere through the STORE's purchase)
			if not card.Owned then
				local storeBuy = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("StoreBuy") :: RemoteEvent?
				if storeBuy then
					storeBuy:FireServer("InfiniteBag")
				end
			else
				SlKit.Shake(card.Holder, 8, 0, 0.3)
			end
			return
		end
		if card.State == "Locked" then
			Sfx.Play("Error", 1, 0.6)
			SlKit.Shake(card.Holder, 8, 0, 0.3)
			return
		end
		if card.Owned then
			if kind == "Ball" and not card.Equipped then
				busy = true
				local ok, result = pcall(ctx.Equip.InvokeServer, ctx.Equip, card.Step)
				busy = false
				if ok and type(result) == "table" and result.Ok then
					SlKit.Pulse(card.Button.Holder, 1.12, 0.2)
				else
					Sfx.Play("Error", 1, 0.6)
					SlKit.Shake(card.Holder, 8, 0, 0.3)
				end
			end
			return
		end
		if not ctx.AtShop() then
			SlKit.Shake(card.Holder, 8, 0, 0.3)
			nudgeGoShop()
			return
		end
		if not card.Afford then
			Sfx.Play("Error", 1, 0.6)
			SlKit.Shake(card.Holder, 8, 0, 0.3)
			return
		end
		busy = true
		local ok, result
		if kind == "PetSlot" then
			ok, result = pcall(ctx.Buy.InvokeServer, ctx.Buy, "PetSlot")
		else
			ok, result = pcall(ctx.Buy.InvokeServer, ctx.Buy, kind, card.Step)
		end
		busy = false
		if ok and type(result) == "table" and result.Ok then
			if kind ~= "PetSlot" and result.Step and result.Step ~= card.Step then
				card = cardFor(kind :: string, result.Step) or card
			end
			bought(card)
		else
			Sfx.Play("Error", 1, 0.6)
			SlKit.Shake(card.Holder, 8, 0, 0.3)
		end
	end

	buyBest.Holder.Activated:Connect(function()
		if busy then
			return
		end
		local kind = kindOf(currentTab)
		local have, _, rebirths, zones = ladderInfo(kind)
		local step = CoreLadder.BuyBest(kind, have, player:GetAttribute("Coins"), rebirths, zones)
		if not step then
			Sfx.Play("Error", 1, 0.6)
			SlKit.Shake(buyBest.Holder, 8, 0, 0.3)
			return
		end
		if not ctx.AtShop() then
			nudgeGoShop()
			return
		end
		busy = true
		local ok, result = pcall(ctx.Buy.InvokeServer, ctx.Buy, kind, "Best")
		busy = false
		if ok and type(result) == "table" and result.Ok then
			-- show the page the new one is on, then reveal it there
			currentZone = CoreLadder.Zone(kind, result.Step or step)
			refresh()
			local card = cardFor(kind, result.Step or step)
			scrollTo(card)
			bought(card)
		else
			Sfx.Play("Error", 1, 0.6)
			SlKit.Shake(buyBest.Holder, 8, 0, 0.3)
		end
	end)

	local lastGo = 0
	goShop.Holder.Activated:Connect(function()
		if os.clock() - lastGo < CORE.Teleport.Cooldown then
			return
		end
		lastGo = os.clock()
		ctx.GoToShop()
	end)

	-- Spin the NEXT / BEST ball and the one being revealed
	RunService.RenderStepped:Connect(function(dt)
		if not win.Visible or currentTab ~= "Balls" then
			return
		end
		for _, card in cards do
			if card.Holder.Visible and card.Kind == "Ball" and (card.Next.Visible or card.Best.Visible) then
				local view = card.Views[card.Step :: number]
				local model = view and view:FindFirstChildWhichIsA("PVInstance")
				if model then
					BallView.Turn(model, CFrame.Angles(0, dt * 1.2, 0))
				end
			end
		end
		for _, view in spinning do
			local model = view:FindFirstChildWhichIsA("PVInstance")
			if model then
				BallView.Turn(model, CFrame.Angles(0, dt * 4, 0))
			end
		end
	end)

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
			"Passes",
		}
	do
		player:GetAttributeChangedSignal(key):Connect(function()
			if win.Visible then
				refresh()
			end
		end)
	end

	-- ===== Open / close =====
	local open = false
	function ShopV2.SetOpen(on: boolean, tab: string?)
		if tab and tabs[tab] then
			if tab ~= currentTab or not open then
				currentTab = tab
				focusZone(kindOf(tab))
			end
		elseif on and not open then
			focusZone(kindOf(currentTab))
		end
		if not on and holdFrom then
			endHold()
		end
		if on == open then
			if on then
				refresh()
				task.defer(scrollToFocus)
			end
			return
		end
		open = on
		backdrop.Visible = on
		gui:SetAttribute("Open", on)
		if on then
			refit()
			refresh()
			Motion.WindowOpen(win, openScale) -- (Polish v2 D1: grows out of the button you pressed, or pops in place)
			Sfx.Play("Click", 1.1)
			-- (Polish v2 D3) the cards pop in one after another, top row first
			local shown = {}
			for _, card in cards do
				if card.Holder.Visible then
					table.insert(shown, card.Holder)
				end
			end
			table.sort(shown, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			for i = 1, math.min(12, #shown) do
				SlKit.ScaleOf(shown[i]).Scale = 0.2
			end
			Motion.Stagger({ table.unpack(shown, 1, math.min(12, #shown)) }, function(holder)
				SlKit.PopIn(holder)
			end, nil, 0.08)
			task.delay(0.3, scrollToFocus)
		else
			Motion.WindowClose(win, openScale, function() -- (Polish v2 D1: back into the button that opened it)
				if not open then
					win.Visible = false
				end
			end)
		end
	end
	function ShopV2.IsOpen(): boolean
		return open
	end
	function ShopV2.Tab(): string
		return currentTab
	end
	-- The stall check changed (CoreShopController): BUY BEST <-> GO TO SHOP
	function ShopV2.Refresh()
		if open then
			refresh()
			UiFx.Pop(win, 1.03, 0.2)
		end
	end

	close.Holder.Activated:Connect(function()
		ShopV2.SetOpen(false)
	end)
	backdrop.Activated:Connect(function()
		ShopV2.SetOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and open and input.KeyCode == Enum.KeyCode.Escape then
			ShopV2.SetOpen(false)
		end
	end)

	-- Studio only: TestReveal = a step on the open page plays the buy reveal on its card (no coins spent)
	if RunService:IsStudio() then
		gui:GetAttributeChangedSignal("TestReveal"):Connect(function()
			local step = tonumber(gui:GetAttribute("TestReveal"))
			local card = step and cardFor(kindOf(currentTab), step)
			if card then
				reveal(card)
			end
		end)
	end

	gui.Parent = playerGui
	refit()
end

return ShopV2
