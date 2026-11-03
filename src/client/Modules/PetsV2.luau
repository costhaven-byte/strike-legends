-- UI overhaul V5 (UI_OVERHAUL_PLAN.md): the PETS window in the owner's new look ('Strike Legends Pets UI.html' D1 pets,
-- D2 empty, D3 items; phone P1-P3), built on Modules/SlKit. Config.Ui.PetsV2 switches it on.
-- Gold PETS header with the paw, red X. Top row: PETS / ITEMS tabs (blue = open, ITEMS has the potion count dot), then
-- on PETS the pet count pill and the sort buttons BEST / RARITY / NEW (NEW has a dot with the new pets).
-- Strip: your equip slots as round coins (filled = rarity colour + the pet in 3D, tap = take it off; open = dashed +;
-- locked = dark + padlock + what opens it: coin price / ROBUX pass), the total boosts (x14.5 coins, x26 pins; bag and
-- speed too when a pet gives them) and EQUIP BEST.
-- Pet cards 180 x 232: rarity rays + the pet in 3D, name, coin / pin boost chips, "x3" copies, green tick = equipped,
-- red number = new copies, Shiny = star + sparkles + gold stripes round the edge, Mythic = sliding rainbow stripes.
-- Tap a card = equip / take off. FUSE! shows when you have enough copies for a Shiny (tap = where to fuse).
-- ITEMS: potion cards 200 x 324 (rays in the potion colour, x2 / 15:00 chips, MEGA tag, USE / time left / NONE).
-- MascotController owns the remotes, the hatch screens and the EQUIP BEST hand; the old window stays for PetsV2 = false.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Mascots = require(Shared.Modules.Mascots)
local HudKit = require(script.Parent.HudKit)
local MascotView = require(script.Parent.MascotView)
local SlKit = require(script.Parent.SlKit)
local Motion = require(script.Parent:WaitForChild("Motion"))
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer
local make = SlKit.Make
local text = SlKit.Text
local hex = Color3.fromHex
local C = SlKit.C
local INK = C.Ink
local WHITE = C.White
local NIGHT = hex("0B1A33")
local GOLD_TEXT = hex("FFC93A")
local ROBUX_GLYPH = utf8.char(0xE002)
local ECONOMY = Config.Economy.Mascots

local PetsV2 = {}

-- Sizes are the design's pixels: desktop window 1360 x 800 on 1920 x 1080, phone window 1071 x 520 (shown at ~0.62)
local DESK = Vector2.new(1360, 800)
local PHONE = Vector2.new(1071, 520)
local CARD_W, CARD_H = 180, 238 -- (232 + the 6 px lip)
local POT_W, POT_H = 200, 330
local STRIP_H = 118

local PAINT = {
	Blue = { hex("2E9BFF"), hex("1666C4"), hex("7CC0FF") },
	Dark = { hex("1C3557"), hex("10294A"), hex("2A4A75") },
	Green = { hex("3CCB3F"), hex("1F8F27"), hex("7BE37D") },
	Red = { hex("FF3B4E"), hex("B81E30"), hex("FF7A86") },
	Strip = { hex("22477A"), hex("0F2442"), hex("2F5B96") },
	Card = { hex("22477A"), hex("0F2442"), hex("22477A") },
}

-- Rarity { light rays, colour } (design R)
local RARITY: { [string]: { Color3 } } = {
	Common = { hex("E6EBF0"), hex("B8C2CC") },
	Uncommon = { hex("A8F5BE"), hex("4BE07A") },
	Rare = { hex("A6D8FF"), hex("3AA8FF") },
	Epic = { hex("DDB3FF"), hex("B45CFF") },
	Legendary = { hex("FFF0B3"), hex("FFC93A") },
	Mythic = { hex("FFB3CD"), hex("FF4F8B") },
}
local RAINBOW = { hex("FF4F8B"), hex("FFC93A"), hex("4BE07A"), hex("3AA8FF"), hex("B45CFF") }
local GOLD_BANDS = { hex("FFC93A"), hex("FFE680") }

-- Potion card colours by boost { rays, colour, icon name } (design C)
local POTION = {
	Coins = { hex("FFE680"), hex("FFC93A"), "coin" },
	Pins = { hex("FFC08A"), hex("FF8A3D"), "pins" },
	XP = { hex("8CCBFF"), hex("2E9BFF"), "xp" },
	Luck = { hex("A5F2B8"), hex("4BE07A"), "luck" },
}

-- Stat chips on the cards and the strip: icon + text colour
local STAT = {
	Coins = { "cur_coin", GOLD_TEXT },
	Pins = { "cur_pin", WHITE },
	Bag = { "bag_01", WHITE },
	Speed = { "hud_throw", WHITE },
}

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

-- Hard colour bands sliding along a ring (Mythic rainbow / Shiny gold; the design's moving stripes)
local function slideStripes(target: UIStroke, colors: { Color3 }, seconds: number)
	local keys = {}
	local n = math.floor(10 / #colors) * #colors -- (a ColorSequence holds at most 20 points = 10 bands)
	for i = 0, n - 1 do
		local color = colors[(i % #colors) + 1]
		table.insert(keys, ColorSequenceKeypoint.new(i / n, color))
		table.insert(keys, ColorSequenceKeypoint.new(math.min((i + 1) / n - 0.0001, 1), color))
	end
	keys[#keys] = ColorSequenceKeypoint.new(1, keys[#keys].Value)
	local gradient = make("UIGradient", { Color = ColorSequence.new(keys), Rotation = 45 }, target)
	TweenService:Create(
		gradient,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Offset = Vector2.new(#colors / n, 0) }
	):Play()
end

-- A dark rounded chip (the cards' "+120%" and "x2" / "15:00" chips); returns the row inside it (the chip = its parent)
local function darkChip(parent: Instance, height: number): Frame
	local chip = make("Frame", {
		Name = "Chip",
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, height),
		ZIndex = 8,
	}, parent)
	corner(chip, height / 2)
	-- the design's 3 px lighter line along the top inside
	local shine = make("Frame", {
		Name = "Shine",
		BackgroundColor3 = C.Tile,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(height / 2, 1),
		Size = UDim2.new(1, -height, 0, 3),
		ZIndex = 8,
	}, chip)
	corner(shine, 2)
	local row = make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8 }, chip)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 3),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	return row
end

-- A word that sizes to itself (inside list rows)
local function word(parent: Instance, words: string, size: number, color: Color3?, order: number?): TextLabel
	return text(parent, words, size, color or WHITE, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = order or 2,
		ZIndex = 9,
	})
end

-- The design's red X (two white bars with an ink outline) on a red button
local function closeButton(parent: Instance, size: number)
	local close = SlKit.Button(parent, {
		Name = "Close",
		Text = "",
		Size = UDim2.fromOffset(size, size + 6),
		Radius = 16,
		Paint = PAINT.Red,
	})
	for _, angle in { 45, -45 } do
		local bar = make("Frame", {
			Name = "Bar",
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size * 0.16, size * 0.62),
			Rotation = angle,
			ZIndex = 8,
		}, close.Content)
		corner(bar, 5)
		stroke(bar, INK, 3)
	end
	return close
end
PetsV2.CloseButton = closeButton

local function owned(): { [string]: number }
	return Mascots.DecodeOwned(player:GetAttribute("Mascots"))
end

local function equipped(): { string }
	return Mascots.DecodeEquipped(player:GetAttribute("EquippedMascots"))
end

local function countIn(list: { string }, id: string): number
	local n = 0
	for _, other in list do
		if other == id then
			n += 1
		end
	end
	return n
end

type PetCard = {
	Mascot: any,
	Block: any,
	Holder: GuiButton,
	Count: TextLabel,
	Tick: ImageLabel,
	New: Frame,
	NewText: TextLabel,
	Fuse: GuiButton?,
	Score: number,
}

type PotCard = {
	Potion: any,
	Holder: GuiObject,
	Count: TextLabel,
	Button: any,
	ButtonIcon: ImageLabel,
	ButtonText: TextLabel,
	Glow: Frame,
}

-- One pet card (180 x 232): rarity rays + the pet in 3D, name, stat chips, "x3" copies, equipped tick, new number,
-- Shiny star + sparkles, Mythic / Shiny stripes round the edge. Also used by the FUSE PETS window (Modules/EggV2).
function PetsV2.Card(parent: Instance?, mascot): { [string]: any }
	local rarity = RARITY[mascot.Rarity] or RARITY.Common
	local block = SlKit.Block(parent, {
		Name = mascot.Id,
		Button = true,
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		Radius = 16,
		Paint = PAINT.Card,
	})
	local holder = block.Holder :: GuiButton
	local content = block.Content
	-- Mythic / Shiny: hard stripes sliding round the edge, outside the card
	if mascot.Shiny or mascot.Rarity == "Mythic" then
		local edge = make("Frame", {
			Name = "Edge",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-5, -5),
			Size = UDim2.new(1, 10, 1, 10),
			ZIndex = 0,
		}, holder)
		corner(edge, 21)
		slideStripes(
			stroke(edge, WHITE, 6),
			if mascot.Rarity == "Mythic" then RAINBOW else GOLD_BANDS,
			if mascot.Rarity == "Mythic" then 2 else 3
		)
		local inkEdge = make("Frame", {
			Name = "InkEdge",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-9, -9),
			Size = UDim2.new(1, 18, 1, 18),
			ZIndex = 0,
		}, holder)
		corner(inkEdge, 24)
		stroke(inkEdge, INK, 3)
	end
	-- the rarity colour as an inner ring
	local ring = make("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 7,
	}, content)
	corner(ring, 13)
	stroke(ring, rarity[2], 3)
	-- art: rarity colour + light rays (CanvasGroup keeps the round top corners)
	local art = make("CanvasGroup", {
		Name = "Art",
		BackgroundColor3 = rarity[2],
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 0, 137),
		ZIndex = 4,
	}, content)
	corner(art, 12)
	SlKit.Image(art, "bg_rays", 0, {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 300),
		ImageColor3 = rarity[1],
		ZIndex = 4,
	})
	local pet = make("Frame", {
		Name = "Pet",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(CARD_W / 2, 70),
		Size = UDim2.fromOffset(124, 124),
		ZIndex = 5,
	}, content)
	MascotView.Viewport(pet, MascotView.Mascot(mascot, 2, false), 0.95)
	-- name + stat chips
	local name = text(content, mascot.Name, 20, WHITE, {
		Name = "PetName",
		Position = UDim2.fromOffset(6, 146),
		Size = UDim2.new(1, -12, 0, 24),
		ZIndex = 8,
	})
	HudKit.Fit(name, 20)
	local chips = make("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 178),
		Size = UDim2.new(1, -16, 0, 32),
		ZIndex = 8,
	}, content)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, chips)
	local stats = Mascots.Stats(mascot)
	local shown = {}
	for _, stat in Config.PetStats.Order do
		if (stats[stat] or 0) > 0 and STAT[stat] and #shown < 2 then
			table.insert(shown, stat)
		end
	end
	for order, stat in shown do
		local chipRow = darkChip(chips, 32)
		local chip = chipRow.Parent :: Frame
		chip.LayoutOrder = order
		chip.Size = UDim2.new(if #shown == 1 then 1 else 0.5, if #shown == 1 then 0 else -3, 0, 32)
		SlKit.Image(chipRow, STAT[stat][1], 22, { LayoutOrder = 1, ZIndex = 9 })
		local value = word(chipRow, Mascots.PercentText(stats[stat]), 16, STAT[stat][2])
		;(value:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 1.5
	end
	if #shown == 0 then
		local chipRow = darkChip(chips, 32)
		;(chipRow.Parent :: Frame).Size = UDim2.fromScale(1, 1)
		word(chipRow, "NO BOOST", 16, hex("9FB3D1"))
	end
	-- "x3" copies, top left
	local count = text(content, "", 22, WHITE, {
		Name = "Count",
		Position = UDim2.fromOffset(10, 9),
		Size = UDim2.fromOffset(60, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
	})
	-- equipped tick, top right (half outside)
	local tick = SlKit.Image(holder, "ui_tick", 52, {
		Name = "Tick",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 14, 0, -14),
		ZIndex = 20,
		Visible = false,
	})
	-- (Polish v2 D4) equipping pops the tick on
	tick:GetPropertyChangedSignal("Visible"):Connect(function()
		if tick.Visible then
			SlKit.PopIn(tick)
		end
	end)
	-- new copies: red number, top right
	local new = make("Frame", {
		Name = "New",
		BackgroundColor3 = PAINT.Red[1],
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 10, 0, -10),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(32, 32),
		ZIndex = 20,
		Visible = false,
	}, holder)
	corner(new, 16)
	stroke(new, INK, 3)
	make("UISizeConstraint", { MinSize = Vector2.new(32, 32) }, new)
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, new)
	local newText = text(new, "1", 16, WHITE, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 21,
	})
	-- Shiny: a gold star on top + sparkles round the card (the crown is on the 3D pet)
	if mascot.Shiny then
		SlKit.Image(holder, "ui_star", 56, {
			Name = "Star",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, -30),
			Rotation = -8,
			ZIndex = 20,
		})
		for _, spot in { { -12, 96, 28 }, { CARD_W - 12, 30, 22 }, { CARD_W - 14, CARD_H - 70, 26 } } do
			SlKit.Image(holder, "ui_sparkle", spot[3], {
				Name = "Sparkle",
				Position = UDim2.fromOffset(spot[1], spot[2]),
				ZIndex = 20,
			})
		end
	end
	return {
		Block = block,
		Holder = holder,
		Content = content,
		Count = count,
		Tick = tick,
		New = new,
		NewText = newText,
	}
end
-- ctx (from MascotController): Equip(id, on), EquipBest(), FuseText, LockTexts(slots) -> { string },
-- Locked() -> (head, line)? (pets not open yet), GoToEggs (fn or nil), Potions (PotionController), TestEgg /
-- TestPotions (Studio fns or nil), OnClose()
function PetsV2.Start(ctx: { [string]: any })
	local playerGui = player:WaitForChild("PlayerGui")
	local Potions = ctx.Potions
	local toastNow: Frame? = nil

	local gui = make("ScreenGui", {
		Name = "PetsV2UI",
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
		Name = "Pets",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(DESK.X, DESK.Y),
	}, gui)
	local fitScale = make("UIScale", { Name = "Fit" }, fit)
	local win = make("Frame", { Name = "Window", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, fit)
	local openScale = make("UIScale", { Name = "OpenScale" }, win)
	win.Visible = false

	SlKit.Block(win, { Name = "Body", Size = UDim2.fromScale(1, 1), Radius = 16, Paint = "Window", Lip = 8 })
	-- Header plate: paw + PETS (design: h68, pad 40, title 40)
	local header = SlKit.Block(win, { Name = "Header", Size = UDim2.fromOffset(250, 74), Radius = 16, Paint = "Header" })
	header.Holder.AnchorPoint = Vector2.new(0.5, 0)
	header.Holder.Position = UDim2.new(0.5, 0, 0, -32)
	header.Holder.ZIndex = 5
	local headRow = make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, header.Content)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, headRow)
	SlKit.Image(headRow, "hud_pets", 46, { LayoutOrder = 1, ZIndex = 9 })
	local title = word(headRow, "PETS", 40)
	;(title:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3
	local close = closeButton(win, 72)
	close.Holder.AnchorPoint = Vector2.new(1, 0)
	close.Holder.Position = UDim2.new(1, 24, 0, -24)
	close.Holder.ZIndex = 5

	-- Toast over the window (its own, so the backdrop never hides it): navy pill, red for "no" messages
	local function toast(message: string)
		if toastNow then
			toastNow:Destroy()
		end
		local upper = string.upper(message)
		local problem = upper:find("FULL") or upper:find("NONE") or upper:find("NOT ENOUGH")
		local width = TextService:GetTextSize(upper, 24, Enum.Font.FredokaOne, Vector2.new(4000, 100)).X + 64
		local block = SlKit.Block(gui, {
			Name = "Toast",
			Size = UDim2.fromOffset(width, 58),
			Radius = 29,
			Paint = if problem then PAINT.Red else "Window",
			ZIndex = 40,
		})
		local holder = block.Holder
		holder.AnchorPoint = Vector2.new(0.5, 0)
		text(block.Content, upper, 24, if problem then WHITE else GOLD_TEXT, { ZIndex = 45 })
		toastNow = holder :: Frame
		local base = UDim2.new(0.5, 0, 0, 70)
		holder.Position = base - UDim2.fromOffset(0, 24)
		SlKit.Tween(holder, 0.25, "Over", { Position = base })
		if problem then
			Sfx.Play("Error")
		end
		task.delay(2.2, function()
			if toastNow == holder then
				toastNow = nil
				SlKit.Tween(holder, 0.18, "Snap", { Position = base - UDim2.fromOffset(0, 80) })
				task.delay(0.2, holder.Destroy, holder)
			end
		end)
	end
	ctx.Toast = toast

	-- Everything inside the window sits in `inner` (design: left/right 24, top 46, bottom 22)
	local inner = make("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(24, 46),
		Size = UDim2.new(1, -48, 1, -68),
	}, win)

	-- ===== Top row: tabs left, count + sort buttons right =====
	local topRow = make("Frame", {
		Name = "Top",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 78),
	}, inner)
	local currentTab = "Pets"
	local setTab: (string) -> ()
	local tabs = {}
	for index, def in { { "Pets", "PETS", "hud_pets", 170 }, { "Items", "ITEMS", "potion_coin", 180 } } do
		local tab = SlKit.Button(topRow, {
			Name = def[1] .. "Tab",
			Text = def[2],
			Icon = def[3],
			IconSize = 42,
			Size = UDim2.fromOffset(def[4], 78),
			Radius = 16,
			Paint = PAINT.Dark,
			TextSize = 26,
		})
		tab.Holder.Position = UDim2.fromOffset((index - 1) * (170 + 12), 0)
		local dot = SlKit.Dot(tab.Holder, 0, true)
		dot.Position = UDim2.new(1, -4, 0, 4)
		dot.Visible = false
		tabs[def[1]] = { Button = tab, Dot = dot }
		local id = def[1]
		tab.Holder.Activated:Connect(function()
			setTab(id)
		end)
	end

	local sortRow = make("Frame", {
		Name = "Sort",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
	}, topRow)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, sortRow)
	-- pet count pill (dark, paw + "42")
	local countPill = make("Frame", {
		Name = "CountPill",
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 48),
		LayoutOrder = 1,
	}, sortRow)
	corner(countPill, 24)
	make("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 16) }, countPill)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, countPill)
	SlKit.Image(countPill, "hud_pets", 30, { LayoutOrder = 1 })
	local countText = word(countPill, "0", 22)
	-- (ITEMS: the potion timer note sits where the sort buttons are)
	local itemsNote = text(topRow, "TIMERS ONLY RUN WHILE YOU PLAY", 20, hex("9FB3D1"), {
		Name = "ItemsNote",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 0),
		Size = UDim2.new(0, 420, 1, -6),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
	})
	local sortBy = "Best"
	local sortButtons = {}
	local refresh: () -> ()
	for index, def in { { "Best", "BEST", 110 }, { "Rarity", "RARITY", 130 }, { "New", "NEW", 100 } } do
		local button = SlKit.Button(sortRow, {
			Name = def[1] .. "Sort",
			Text = def[2],
			Size = UDim2.fromOffset(def[3], 72),
			Radius = 16,
			Paint = PAINT.Dark,
			TextSize = 22,
		})
		button.Holder.LayoutOrder = index + 1
		local id = def[1]
		button.Holder.Activated:Connect(function()
			sortBy = id
			refresh()
		end)
		sortButtons[id] = button
	end
	local newDot = SlKit.Dot(sortButtons.New.Holder, 0, true)
	newDot.Position = UDim2.new(0, 4, 0, 4) -- (top-left: the window's close X sits over the top-right corner)
	newDot.Visible = false

	-- ===== Strip: slots, boosts, EQUIP BEST =====
	local strip = SlKit.Block(inner, {
		Name = "Strip",
		Size = UDim2.new(1, 0, 0, STRIP_H),
		Radius = 16,
		Paint = PAINT.Strip,
	})
	strip.Holder.Position = UDim2.fromOffset(0, 92)
	local stripBox = strip.Content
	local slotRow = make("Frame", {
		Name = "Slots",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
	}, stripBox)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, slotRow)
	local divider = make("Frame", {
		Name = "Divider",
		BackgroundColor3 = hex("2F5B96"),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 3, 1, -28),
		Position = UDim2.fromOffset(0, 14),
		ZIndex = 8,
	}, stripBox)
	corner(divider, 2)
	local boostBox = make("Frame", {
		Name = "Boosts",
		BackgroundTransparency = 1,
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
	}, stripBox)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 18),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, boostBox)
	-- two columns of "[icon] x14.5": coins + pins always, bag + speed when a pet gives them
	local boostLines: { [string]: { Frame: Frame, Text: TextLabel } } = {}
	for col, pair in { { "Coins", "Pins" }, { "Bag", "Speed" } } do
		local column = make("Frame", {
			Name = "Column" .. col,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 84),
			LayoutOrder = col,
		}, boostBox)
		make("UIListLayout", {
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, column)
		for order, stat in pair do
			local line = make("Frame", {
				Name = stat,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 38),
				LayoutOrder = order,
			}, column)
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, line)
			SlKit.Image(line, STAT[stat][1], 38, { LayoutOrder = 1 })
			local label = word(line, "x1", 28, STAT[stat][2])
			boostLines[stat] = { Frame = line, Text = label }
		end
	end
	local best = SlKit.Button(stripBox, {
		Name = "EquipBest",
		Text = "EQUIP BEST",
		Size = UDim2.fromOffset(224, 72),
		Radius = 16,
		Paint = PAINT.Green,
		TextSize = 26,
	})
	best.Holder.AnchorPoint = Vector2.new(1, 0.5)
	best.Holder.Position = UDim2.new(1, -16, 0.5, 0)
	best.Holder.Activated:Connect(function()
		if best.Holder:GetAttribute("KitDisabled") then
			return
		end
		ctx.EquipBest()
	end)

	-- ===== Grid =====
	local grid = make("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 12,
		ScrollBarImageColor3 = hex("2E9BFF"),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		VerticalScrollBarInset = Enum.ScrollBarInset.Always,
	}, inner)
	local gridLayout = make("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 30), -- room for the ticks, dots and Shiny stars above the first row
		PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 14),
	}, grid)
	-- the items grid (own frame so each tab keeps its scroll)
	local itemGrid = grid:Clone()
	itemGrid.Name = "ItemGrid"
	itemGrid.Parent = inner
	local itemLayout = itemGrid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
	itemLayout.CellSize = UDim2.fromOffset(POT_W, POT_H)

	-- Empty state: the egg in 3D, NO PETS YET, a line, GO TO EGGS
	local empty = make("Frame", { Name = "Empty", BackgroundTransparency = 1, Visible = false }, inner)
	local eggHolder = make("Frame", {
		Name = "Egg",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.fromOffset(150, 150),
		Rotation = -8,
	}, empty)
	local firstEgg = Mascots.CoreEggsOn() and Mascots.CoreEggs()[1]
	local eggOk = false
	if firstEgg then
		eggOk = pcall(function()
			MascotView.Viewport(eggHolder, MascotView.Egg(firstEgg.Id, 4), 0.9)
		end)
	end
	if not eggOk then
		SlKit.Image(eggHolder, "hud_pets", 0, { Size = UDim2.fromScale(1, 1) })
	end
	local emptyHead = text(empty, "NO PETS YET", 36, WHITE, {
		Name = "Head",
		Position = UDim2.new(0, 0, 0.5, 22),
		Size = UDim2.new(1, 0, 0, 42),
	})
	local emptyLine = text(empty, "", 20, hex("9FB3D1"), {
		Name = "Line",
		Position = UDim2.new(0, 40, 0.5, 70),
		Size = UDim2.new(1, -80, 0, 26),
	})
	local goEggs: any = nil
	if ctx.GoToEggs then
		goEggs = SlKit.Button(empty, {
			Name = "GoToEggs",
			Text = "GO TO EGGS",
			Size = UDim2.fromOffset(240, 72),
			Radius = 16,
			Paint = "Pink",
			TextSize = 26,
		})
		goEggs.Holder.AnchorPoint = Vector2.new(0.5, 0)
		goEggs.Holder.Position = UDim2.new(0.5, 0, 0.5, 108)
		goEggs.Holder.Activated:Connect(function()
			ctx.GoToEggs()
			PetsV2.SetOpen(false)
		end)
	end

	-- ===== Layout: desktop or phone window, cards spread across the width =====
	local phone = false
	local function spread(layout: UIGridLayout, frame: ScrollingFrame, cellW: number, gapY: number)
		local width = frame.AbsoluteSize.X / math.max(fitScale.Scale * openScale.Scale, 0.01)
		if width <= 0 then
			return
		end
		local room = width - 12 - 14 - 10 -- scroll bar, left pad, a little right room
		local cols = math.max(1, math.floor((room + 12) / (cellW + 12)))
		local gap = if cols > 1 then math.min(40, (room - cols * cellW) / (cols - 1)) else 0
		layout.CellPadding = UDim2.fromOffset(gap, gapY)
	end
	local function layout()
		local size = if phone then PHONE else DESK
		fit.Size = UDim2.fromOffset(size.X, size.Y)
		local pets = currentTab == "Pets"
		local gridTop = 92 + STRIP_H + 4
		grid.Position = UDim2.fromOffset(0, gridTop)
		grid.Size = UDim2.new(1, 0, 1, -gridTop)
		itemGrid.Position = UDim2.fromOffset(0, 84)
		itemGrid.Size = UDim2.new(1, 0, 1, -84)
		empty.Position = UDim2.fromOffset(0, gridTop)
		empty.Size = UDim2.new(1, 0, 1, -gridTop)
		-- strip pieces: slots, divider, boosts left to right
		local slotsW = slotRow.AbsoluteSize.X / math.max(fitScale.Scale * openScale.Scale, 0.01)
		divider.Position = UDim2.fromOffset(16 + slotsW + 18, 14)
		boostBox.Position = UDim2.fromOffset(16 + slotsW + 18 + 3 + 18, 0)
		if pets then
			spread(gridLayout, grid, CARD_W, 20)
		else
			spread(itemLayout, itemGrid, POT_W, 22)
		end
	end
	local function refit()
		local view = gui.AbsoluteSize
		if view.X <= 0 then
			return
		end
		phone = view.Y < (Config.Ui.CompactHeight or 500)
		local size = if phone then PHONE else DESK
		fitScale.Scale = math.min((view.X - 40) / (size.X + 56), (view.Y - 40) / (size.Y + 90), 1)
		layout()
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	slotRow:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	-- (a grid shown for the first time only gets its size a frame later)
	grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	itemGrid:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)

	-- ===== Pet cards (made the first time you own that pet) =====
	local petCards: { [string]: PetCard } = {}
	local seen: { [string]: number } = owned() -- copies already seen; more than this = new (this session)
	local function makePetCard(mascot): PetCard
		local card = PetsV2.Card(grid, mascot)
		local block, holder, content, count = card.Block, card.Holder :: GuiButton, card.Content, card.Count
		local tick, new, newText = card.Tick, card.New, card.NewText
		-- FUSE! once you have enough copies for a Shiny (tap = where to fuse)
		local fuse: GuiButton? = nil
		if Mascots.CoreEggsOn() and Mascots.MergeCost(mascot) then
			local f = SlKit.Button(content, {
				Name = "Fuse",
				Text = "FUSE!",
				Size = UDim2.fromOffset(68, 36),
				Radius = 10,
				Paint = "Gold",
				TextSize = 16,
				ZIndex = 9,
			})
			f.Holder.Position = UDim2.fromOffset(8, 38)
			f.Holder.Visible = false
			f.Holder.Activated:Connect(function()
				toast(ctx.FuseText)
			end)
			fuse = f.Holder :: GuiButton
		end
		holder.Activated:Connect(function()
			local mine = owned()[mascot.Id] or 0
			local list = equipped()
			local inUse = countIn(list, mascot.Id)
			local slots = player:GetAttribute("MascotSlots") or ECONOMY.StartSlots
			if inUse > 0 then
				ctx.Equip(mascot.Id, false)
			elseif inUse < mine and #list < slots then
				Sfx.Play("PetEquip")
				ctx.Equip(mascot.Id, true)
			else
				SlKit.Shake(holder, 6, 6)
				ctx.Toast("SLOTS FULL! TAP A PET IN A SLOT TO TAKE IT OFF")
			end
		end)
		return {
			Mascot = mascot,
			Block = block,
			Holder = holder,
			Count = count,
			Tick = tick,
			New = new,
			NewText = newText,
			Fuse = fuse,
			Score = Mascots.Score(mascot),
		}
	end

	-- ===== Slots =====
	local function refreshSlots()
		for _, child in slotRow:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local list = equipped()
		local slots = player:GetAttribute("MascotSlots") or ECONOMY.StartSlots
		local locks = ctx.LockTexts(slots)
		local shown = slots + #locks
		-- slots shrink to leave room for the boosts and EQUIP BEST
		local stripW = (if phone then PHONE.X else DESK.X) - 48
		local room = stripW - 16 - 18 - 3 - 18 - 200 - 18 - 224 - 16
		local size = math.clamp(math.floor((room - (shown - 1) * 8) / shown), 48, 84)
		for i = 1, shown do
			local open = i <= slots
			local mascot = Mascots.Get(list[i])
			local box = make("TextButton", {
				Name = "Slot" .. i,
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Size = UDim2.fromOffset(size, size),
			}, slotRow) :: TextButton
			local circle = make("Frame", {
				Name = "Circle",
				BackgroundColor3 = if mascot
					then (RARITY[mascot.Rarity] or RARITY.Common)[2]
					elseif open then hex("1C3D6A")
					else hex("0F2442"),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 8,
			}, box)
			corner(circle, size)
			local edge = stroke(circle, if mascot or not open then INK else WHITE, 3)
			if open and not mascot then
				edge.Transparency = 0.7
			end
			if mascot then
				-- shine along the top inside
				local view = MascotView.Viewport(circle, MascotView.Mascot(mascot, 2, false), 0.95)
				view.ZIndex = 9
				if mascot.Shiny then
					SlKit.Image(box, "ui_star", size * 0.36, {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0),
						ZIndex = 12,
					})
				end
				box.Activated:Connect(function()
					ctx.Equip(mascot.Id, false)
				end)
			elseif open then
				text(circle, "+", math.floor(size * 0.43), WHITE, { TextTransparency = 0.65, ZIndex = 9 })
				box.Activated:Connect(function()
					ctx.Toast("TAP A PET BELOW TO PUT IT HERE")
				end)
			else
				SlKit.Image(circle, "ui_lock", math.floor(size * 0.55), {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(0.5, 0, 0.5, -size * 0.1),
					ZIndex = 9,
				})
				-- what opens it: a gold coin-price chip, or the green Robux pass chip
				local why = locks[i - slots] or ""
				local robux = why == "ROBUX PASS"
				local chip = make("Frame", {
					Name = "Why",
					BackgroundColor3 = if robux then hex("3CCB3F") else hex("FFC93A"),
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, 6),
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 26),
					ZIndex = 12,
				}, box)
				corner(chip, 13)
				stroke(chip, INK, 2)
				make("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 8) }, chip)
				make("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					Padding = UDim.new(0, 2),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}, chip)
				local isPrice = not robux and not string.find(why, "REBIRTH")
				local small = size < 70 -- (narrow strips: smaller chip, no coin, so the chips don't overlap)
				if small then
					chip.Size = UDim2.fromOffset(0, 22)
					local pad = chip:FindFirstChildOfClass("UIPadding") :: UIPadding
					pad.PaddingLeft = UDim.new(0, 4)
					pad.PaddingRight = UDim.new(0, 4)
				end
				if isPrice and not small then
					SlKit.Image(chip, "cur_coin", 20, { LayoutOrder = 1, ZIndex = 13 })
				end
				local label = word(chip, if robux then ROBUX_GLYPH .. " PASS" else why, if small then 12 else 15)
				label.ZIndex = 13
				box.Activated:Connect(function()
					SlKit.Shake(box, 5, 6)
					ctx.Toast(
						if robux
							then "GET 2 MORE PET SLOTS WITH THE +2 PET SLOTS PASS"
							elseif isPrice then "BUY MORE PET SLOTS AT THE SHOP"
							else ("THIS SLOT OPENS AT %s"):format(why)
					)
				end)
			end
		end
	end

	-- ===== Potion cards =====
	local potCards: { [string]: PotCard } = {}
	for index, potion in Config.Potions.List do
		local look = POTION[potion.Boost] or POTION.Coins
		local mega = potion.Big == true
		local block = SlKit.Block(itemGrid, {
			Name = potion.Id,
			Size = UDim2.fromOffset(POT_W, POT_H),
			Radius = 16,
			Paint = PAINT.Card,
		})
		local holder = block.Holder
		holder.LayoutOrder = index
		local content = block.Content
		-- running: white ring + the potion colour round it
		local glow = make("Frame", {
			Name = "Glow",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-8, -8),
			Size = UDim2.new(1, 16, 1, 16),
			ZIndex = 0,
			Visible = false,
		}, holder)
		corner(glow, 22)
		stroke(glow, WHITE, 4)
		local glowOut = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-4, -4),
			Size = UDim2.new(1, 8, 1, 8),
			ZIndex = 0,
		}, glow)
		corner(glowOut, 26)
		stroke(glowOut, look[2], 4)
		local ring = make("Frame", { Name = "Ring", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7 }, content)
		corner(ring, 13)
		stroke(ring, if mega then hex("FFC93A") else look[2], 3)
		local art = make("CanvasGroup", {
			Name = "Art",
			BackgroundColor3 = look[2],
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 0, 200),
			ZIndex = 4,
		}, content)
		corner(art, 12)
		SlKit.Image(art, "bg_rays", 0, {
			Name = "Rays",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.fromOffset(360, 360),
			ImageColor3 = look[1],
			ZIndex = 4,
		})
		local iconSize = if mega then 150 else 132
		SlKit.Image(content, (if mega then "potion_%s_mega" else "potion_%s"):format(look[3]), iconSize, {
			Name = "Potion",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, if mega then 20 else 30),
			ZIndex = 6,
		})
		if mega then
			local tag = make("Frame", {
				Name = "Mega",
				BackgroundColor3 = hex("FFC93A"),
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 10),
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 28),
				Rotation = -4,
				ZIndex = 8,
			}, content)
			corner(tag, 14)
			stroke(tag, INK, 3)
			make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, tag)
			word(tag, "MEGA", 16)
		end
		-- x2 and 15:00 chips along the art's bottom
		local chips = make("Frame", {
			Name = "Chips",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(11, 3 + 200 - 8 - 34),
			Size = UDim2.new(1, -22, 0, 34),
			ZIndex = 8,
		}, content)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, chips)
		local multChip = darkChip(chips, 34)
		;(multChip.Parent :: Frame).Size = UDim2.new(0.42, -3, 0, 34)
		word(multChip, "x" .. tostring(potion.Multiplier), 20, GOLD_TEXT)
		local timeChip = darkChip(chips, 34)
		;(timeChip.Parent :: Frame).LayoutOrder = 2
		;(timeChip.Parent :: Frame).Size = UDim2.new(0.58, -3, 0, 34)
		word(timeChip, Potions.Clock(potion.Minutes * 60), 18)
		local name = text(content, potion.Name, 20, WHITE, {
			Name = "PotionName",
			Position = UDim2.fromOffset(8, 212),
			Size = UDim2.new(1, -16, 0, 24),
			ZIndex = 8,
		})
		HudKit.Fit(name, 20)
		local button = SlKit.Block(content, {
			Name = "Use",
			Button = true,
			Size = UDim2.fromOffset(172, 72),
			Radius = 16,
			Paint = PAINT.Green,
			ZIndex = 8,
		})
		button.Holder.AnchorPoint = Vector2.new(0.5, 1)
		button.Holder.Position = UDim2.new(0.5, 0, 1, -16)
		local buttonRow = make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 12 }, button.Content)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, buttonRow)
		local buttonIcon = SlKit.Image(buttonRow, "ui_lock", 30, { LayoutOrder = 1, ZIndex = 13, Visible = false })
		local buttonText = word(buttonRow, "USE", 26)
		buttonText.ZIndex = 13
		local count = text(content, "", 22, WHITE, {
			Name = "Count",
			Position = UDim2.fromOffset(12, 11),
			Size = UDim2.fromOffset(60, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 9,
		})
		button.Holder.Activated:Connect(function()
			if (Potions.Owned()[potion.Id] or 0) > 0 then
				Potions.Use(potion)
			else
				SlKit.Shake(button.Holder, 6, 6)
				ctx.Toast("NONE LEFT! GET POTIONS FROM GIFTS AND REWARDS")
			end
		end)
		potCards[potion.Id] = {
			Potion = potion,
			Holder = holder,
			Count = count,
			Button = button,
			ButtonIcon = buttonIcon,
			ButtonText = buttonText,
			Glow = glow,
		}
	end

	local function refreshItems()
		local mine = Potions.Owned()
		local boosts = Potions.Boosts()
		local running = Potions.Running(boosts)
		for id, card in potCards do
			local have = mine[id] or 0
			local left = boosts[id] or 0
			card.Count.Text = if have > 0 then ("x%d"):format(have) else ""
			card.Glow.Visible = running[id] == true
			if left > 0 then
				-- running (or waiting behind a stronger one): blue with the time left
				card.Button:Paint(PAINT.Blue)
				card.ButtonText.Text = if running[id] then Potions.Clock(left) else "WAIT"
			elseif have > 0 then
				card.Button:Paint(PAINT.Green)
				card.ButtonText.Text = "USE"
			else
				card.Button:Paint("Disabled")
				card.ButtonText.Text = "NONE"
			end
			card.ButtonIcon.Visible = false
		end
	end

	-- ===== Refresh =====
	local function newCopies(mine: { [string]: number }): number
		local total = 0
		for id, count in mine do
			total += math.max(0, count - (seen[id] or 0))
		end
		return total
	end

	function refresh()
		local mine = owned()
		local list = equipped()
		local pets = currentTab == "Pets"
		local lockedHead, lockedLine = ctx.Locked()
		local locked = lockedHead ~= nil

		-- tabs + sort buttons
		for id, tab in tabs do
			tab.Button:Paint(if id == currentTab then PAINT.Blue else PAINT.Dark)
		end
		local potions = Potions.Count()
		tabs.Items.Dot.Visible = potions > 0
		tabs.Items.Dot:SetAttribute("Count", potions)
		for id, button in sortButtons do
			button:Paint(if id == sortBy then PAINT.Blue else PAINT.Dark)
		end
		local fresh = newCopies(mine)
		newDot.Visible = fresh > 0
		newDot:SetAttribute("Count", fresh)

		sortRow.Visible = pets and not locked
		itemsNote.Visible = not pets
		strip.Holder.Visible = pets and not locked
		itemGrid.Visible = not pets

		-- pet cards: one per pet you own, sorted
		local total = 0
		local order = {}
		for id, have in mine do
			local mascot = Mascots.Get(id)
			if mascot and have > 0 then
				total += have
				local card = petCards[id]
				if not card then
					card = makePetCard(mascot)
					petCards[id] = card
				end
				table.insert(order, card)
			end
		end
		for id, card in petCards do
			card.Holder.Visible = (mine[id] or 0) > 0
		end
		local function rank(card: PetCard): number
			return Mascots.RarityIndex(card.Mascot.Rarity)
		end
		table.sort(order, function(a, b)
			local ea, eb = countIn(list, a.Mascot.Id) > 0, countIn(list, b.Mascot.Id) > 0
			if sortBy == "New" then
				local na = (mine[a.Mascot.Id] or 0) - (seen[a.Mascot.Id] or 0)
				local nb = (mine[b.Mascot.Id] or 0) - (seen[b.Mascot.Id] or 0)
				if (na > 0) ~= (nb > 0) then
					return na > 0
				end
			elseif sortBy == "Rarity" then
				if rank(a) ~= rank(b) then
					return rank(a) > rank(b)
				end
			elseif ea ~= eb then
				return ea -- BEST: the pets you have out first (like the design), then the strongest
			end
			if a.Score ~= b.Score then
				return a.Score > b.Score
			end
			return a.Mascot.Id < b.Mascot.Id
		end)
		for index, card in order do
			local id = card.Mascot.Id
			local have = mine[id] or 0
			card.Holder.LayoutOrder = index
			card.Count.Text = if have > 1 then ("x%d"):format(have) else ""
			local inUse = countIn(list, id) > 0
			card.Tick.Visible = inUse
			local newOnes = math.max(0, have - (seen[id] or 0))
			card.New.Visible = newOnes > 0 and not inUse
			card.NewText.Text = tostring(newOnes)
			if card.Fuse then
				card.Fuse.Visible = have >= (Mascots.MergeCost(card.Mascot) or math.huge)
			end
		end
		countText.Text = tostring(total)
		grid.Visible = pets and not locked and #order > 0
		empty.Visible = pets and (locked or #order == 0)
		emptyHead.Text = lockedHead or "NO PETS YET"
		emptyLine.Text = lockedLine
			or (if goEggs then "PETS BOOST YOUR COINS, PINS, BAG AND SPEED" else "HATCH AN EGG TO GET YOUR FIRST PET")
		if goEggs then
			goEggs.Holder.Visible = not locked
		end

		-- boosts: x(1 + total) per stat; bag + speed only when a pet gives them
		local totals = Mascots.TotalStats(list)
		for stat, line in boostLines do
			local value = totals[stat] or 0
			line.Text.Text = Currency.FormatMultiplier(1 + value)
			line.Frame.Visible = stat == "Coins" or stat == "Pins" or value > 0
		end
		best:SetDisabled(#order == 0, true)

		refreshSlots()
		refreshItems()
		task.defer(layout)
	end

	function setTab(id: string)
		if currentTab == id then
			return
		end
		currentTab = id
		refresh()
	end

	-- ===== Studio test buttons (bottom left, under the grid) =====
	local testRow = make("Frame", {
		Name = "Test",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 24, 1, -4),
		Size = UDim2.fromOffset(300, 22),
		ZIndex = 20,
	}, win)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, testRow)
	for _, def in { { "TEST: EGG", ctx.TestEgg }, { "TEST: POTIONS", ctx.TestPotions } } do
		if def[2] then
			local b = make("TextButton", {
				Text = def[1],
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 22),
				BackgroundColor3 = Color3.fromRGB(60, 60, 80),
				TextColor3 = WHITE,
				FontFace = SlKit.LabelFont,
				TextSize = 14,
				ZIndex = 20,
			}, testRow)
			make("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
			b.Activated:Connect(def[2])
		end
	end

	-- ===== Open / close =====
	local open = false
	function PetsV2.SetOpen(on: boolean, tab: string?)
		if tab then
			currentTab = tab
		end
		if on == open then
			if on then
				refresh()
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
			-- cards pop in one after another (the first dozen)
			if currentTab == "Pets" then
				local shown = {}
				for _, card in petCards do
					if card.Holder.Visible then
						table.insert(shown, card.Holder)
					end
				end
				table.sort(shown, function(a, b)
					return a.LayoutOrder < b.LayoutOrder
				end)
				for i = 1, math.min(12, #shown) do
					task.delay(0.03 * i, SlKit.PopIn, shown[i], 0.18)
				end
			end
			task.delay(0.3, layout)
		else
			-- what you saw is no longer new
			if currentTab == "Pets" then
				seen = owned()
			end
			Motion.WindowClose(win, openScale, function() -- (Polish v2 D1: back into the button that opened it)
				if not open then
					win.Visible = false
				end
			end)
			if ctx.OnClose then
				ctx.OnClose()
			end
		end
	end
	function PetsV2.IsOpen(): boolean
		return open
	end
	function PetsV2.Tab(): string
		return currentTab
	end
	function PetsV2.Gui(): ScreenGui
		return gui
	end
	function PetsV2.BestButton(): GuiObject
		return best.Holder
	end
	-- pets you own that the window hasn't shown yet (for the PETS button)
	function PetsV2.NewCount(): number
		return newCopies(owned())
	end

	close.Holder.Activated:Connect(function()
		PetsV2.SetOpen(false)
	end)
	backdrop.Activated:Connect(function()
		PetsV2.SetOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and open and input.KeyCode == Enum.KeyCode.Escape then
			PetsV2.SetOpen(false)
		end
	end)

	for _, key in { "Mascots", "EquippedMascots", "MascotSlots", "MascotStats", "PetSlotsBought", "Potions" } do
		player:GetAttributeChangedSignal(key):Connect(function()
			if open then
				refresh()
			end
		end)
	end
	player:GetAttributeChangedSignal("Boosts"):Connect(function()
		if open and currentTab == "Items" then
			refreshItems()
		end
	end)

	-- Studio: TestTab = "Pets" / "Items" opens that tab, TestOpen = false closes (for checking from the Studio tools)
	if RunService:IsStudio() then
		gui:GetAttributeChangedSignal("TestTab"):Connect(function()
			PetsV2.SetOpen(true, gui:GetAttribute("TestTab") :: string)
		end)
		gui:GetAttributeChangedSignal("TestOpen"):Connect(function()
			PetsV2.SetOpen(gui:GetAttribute("TestOpen") == true)
		end)
	end

	gui.Parent = playerGui
	refit()
	refresh()
end

return PetsV2
