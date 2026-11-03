-- UI overhaul V6 (UI_OVERHAUL_PLAN.md): the egg odds board over every egg stand and the FUSE PETS window, in the
-- owner's new look ('Strike Legends Pets UI.html' D4 egg board, D5 / D6 fuse ready / need 1 more). Config.Ui.EggV2.
-- Board (a BillboardGui pinned to the stand, 720 x 440 design pixels scaled to Config.EggBoard.Width studs): gold
-- plate with the egg (3D) + its name, the price button (green, red when you can't pay, FREE when a free egg waits),
-- one round slot per pet (rarity colour, the pet turning in 3D, its chance under it; 1% or less in the rarity colour),
-- tap a slot = auto-delete X (red X tile, slot 70% dark), then HATCH (key E on a computer) / AUTO / x3 (TRIPLE HATCH
-- pass: Robux badge, tick once owned). Shows when you walk near (scale 0.7 -> 1 overshoot), hides fast.
-- FUSE PETS (1100 wide): count chip "2/3", three slots filling with your copies (the PETS window's cards), arrow,
-- the Shiny it makes (bigger card, dim until ready), PICK A PET row, FUSE (green, bouncing) / NEED 1 MORE (red).
-- MascotController owns the hatch, auto hatch, merge and the remotes; this only draws and calls back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Mascots = require(Shared.Modules.Mascots)
local MascotView = require(script.Parent.MascotView)
local PetsV2 = require(script.Parent.PetsV2)
local SlKit = require(script.Parent.SlKit)
local Sfx = require(script.Parent.Sfx)
local Motion = require(script.Parent.Motion)

local player = Players.LocalPlayer
local make = SlKit.Make
local text = SlKit.Text
local hex = Color3.fromHex
local C = SlKit.C
local INK = C.Ink
local WHITE = C.White
local NIGHT = hex("0B1A33")
local ROBUX_GLYPH = utf8.char(0xE002)
local BOARD = Config.EggBoard
local PET_MOTION = Config.PetMotion

local EggV2 = {}

-- Paints { face, lip, top strip } (design Btn palette; the design's "purple" x3 is the pink one)
local PAINT = {
	Green = { hex("3CCB3F"), hex("1F8F27"), hex("7BE07D") },
	Blue = { hex("2E9BFF"), hex("1666C4"), hex("8CCBFF") },
	Pink = { hex("FF4FA3"), hex("C42A78"), hex("FF9BCB") },
	Red = { hex("FF3B4E"), hex("B81E30"), hex("FF8A96") },
	Locked = { hex("5B6478"), hex("353C4D"), hex("7A8396") },
	Panel = { hex("17345C"), INK, hex("2A5590") },
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

local function textWidth(words: string, size: number): number
	return TextService:GetTextSize(words, size, Enum.Font.FredokaOne, Vector2.new(4000, 200)).X
end

-- A design button: block + row (icon, label, keycap), states normal / pressed / locked / ready (white ring + bounce)
local function button(parent: Instance, opts: { [string]: any }): { [string]: any }
	local paint = opts.Paint
	local b = SlKit.Block(parent, {
		Name = opts.Name,
		Button = true,
		Size = UDim2.fromOffset(opts.W, opts.H or 72),
		Radius = 16,
		Paint = paint,
		ZIndex = opts.ZIndex,
	}) :: any
	local row =
		make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8 }, b.Content)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)
	local icon: ImageLabel? = nil
	if opts.Icon then
		icon = SlKit.Image(row, opts.Icon, opts.IconSize or 40, { LayoutOrder = 1, ZIndex = 9 })
	end
	local lock = SlKit.Image(row, "ui_lock", 34, { LayoutOrder = 0, ZIndex = 9, Visible = false, Name = "Lock" })
	local label = text(row, opts.Text or "", opts.TextSize or 28, WHITE, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		ZIndex = 9,
	});
	(label:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3
	-- keycap "E": dark rounded square after the label (computers only)
	local keycap: Frame? = nil
	if opts.Key then
		keycap = make("Frame", {
			Name = "Key",
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(34, 34),
			LayoutOrder = 3,
			ZIndex = 9,
		}, row)
		corner(keycap :: Frame, 9)
		text(keycap, opts.Key, 18, WHITE, { ZIndex = 10 })
	end
	-- READY: white ring, a ring in the button's colour, the ink outline; the button bounces
	local ready = make("Frame", {
		Name = "Ready",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-9, -9),
		Size = UDim2.new(1, 18, 1, 12),
		Visible = false,
		ZIndex = 1,
	}, b.Holder)
	corner(ready, 22)
	stroke(ready, WHITE, 4)
	local colourRing = make("Frame", {
		Name = "Colour",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-4, -4),
		Size = UDim2.new(1, 8, 1, 8),
		ZIndex = 1,
	}, ready)
	corner(colourRing, 26)
	local colourStroke = stroke(colourRing, paint[1], 4)
	local inkRing = make("Frame", {
		Name = "Ink",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-4, -4),
		Size = UDim2.new(1, 8, 1, 8),
		ZIndex = 1,
	}, colourRing)
	corner(inkRing, 30)
	stroke(inkRing, INK, 3)

	local state = "normal"
	local stopBob: (() -> ())? = nil
	function b.SetState(_self, newState: string)
		if newState == state then
			return
		end
		state = newState
		b.Holder:SetAttribute("KitDisabled", newState == "locked")
		b:Paint(if newState == "locked" then PAINT.Locked else paint)
		lock.Visible = newState == "locked"
		if icon then
			icon.Visible = newState ~= "locked"
		end
		ready.Visible = newState == "ready"
		if stopBob then
			stopBob()
			stopBob = nil
		end
		if newState == "ready" then
			stopBob = SlKit.Bob(b.Holder, 6, 1)
		end
	end
	function b.Repaint(_self, newPaint)
		paint = newPaint
		colourStroke.Color = newPaint[1]
		if state ~= "locked" then
			b:Paint(newPaint)
		end
	end
	function b.SetText(_self, words: string)
		label.Text = words
	end
	b.Label = label
	b.Icon = icon
	b.Keycap = keycap
	b.State = function()
		return state
	end
	b.Holder.Parent = parent
	return b
end

-- "40%", "2.5%", "0.25%", "0.01%"
local function percentText(chance: number): string
	local value = chance * 100
	local shown = if value >= 10
		then ("%d"):format(math.floor(value + 0.5))
		elseif value >= 1 then ("%.1f"):format(value)
		elseif value >= 0.01 then ("%.2f"):format(value)
		else ("%.3f"):format(value)
	shown = shown:gsub("(%.%d-)0+$", "%1"):gsub("%.$", "")
	return shown .. "%"
end

-- ===== The egg odds board =====
-- ctx: Egg, Shell (BasePart the board is pinned to), Base (Vector3: the stand, for the walk-near distance),
-- Pets ({ mascot } sorted), Prompt (the stand's ProximityPrompt: key E), State() -> (unlocked, why, free, affordable),
-- Odds() -> { [mascot]: chance }, LuckText() -> string, Busy() -> bool (a hatch is playing), Hatch(), Auto(),
-- AutoOn() -> bool, TripleOwned() -> bool, BuyTriple(), Toast(message), AutoDeleteRemote (RemoteEvent or nil).
-- Returns { Gui, Shown() -> bool }.
function EggV2.Board(ctx: { [string]: any }): { [string]: any }
	local W, H = 720, 440
	local studsW = BOARD.Width
	local studsH = studsW * H / W
	local gui = make("BillboardGui", {
		Name = "EggOdds", -- (AreaSignController finds the board by this name to sit above it)
		Size = UDim2.fromScale(studsW, studsH), -- scale = studs: the same size on every screen
		StudsOffset = Vector3.new(0, BOARD.Height + studsH / 2, 0),
		LightInfluence = 0,
		Active = true,
		Enabled = false,
		ResetOnSpawn = false,
		Adornee = ctx.Shell,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	-- Pet viewports on a billboard in the Workspace often don't draw: it lives in PlayerGui, pinned by Adornee
	local root = make("Frame", {
		Name = "Board",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(W, H),
	}, gui)
	local fit = make("UIScale", { Name = "Fit" }, root)
	local inner = make("Frame", { Name = "Inner", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	-- (the pop scales `inner` from its bottom middle, where the pointer is)
	inner.AnchorPoint = Vector2.new(0.5, 1)
	inner.Position = UDim2.fromScale(0.5, 1)
	local pop = make("UIScale", { Name = "Pop" }, inner)
	local function refit()
		fit.Scale = math.max(gui.AbsoluteSize.X, 1) / W
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	-- Panel 720 x 376 (+ 8 px lip) from y 30, the pointer under its middle
	local pointer = make("Frame", {
		Name = "Pointer",
		BackgroundColor3 = PAINT.Panel[1],
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(W / 2, 409),
		Size = UDim2.fromOffset(30, 30),
		Rotation = 45,
		ZIndex = 0,
	}, inner)
	stroke(pointer, INK, 3)
	local panel = SlKit.Block(
		inner,
		{ Name = "Panel", Size = UDim2.fromOffset(W, 384), Radius = 16, Paint = PAINT.Panel, Lip = 8 }
	)
	panel.Holder.Position = UDim2.fromOffset(0, 30)

	-- Plate: the egg in 3D + its name (h 64, title 36)
	local title = string.upper((Config.EggLooks[ctx.Egg.Id] or {}).Name or ctx.Egg.Name or "EGG")
	local plateW = 14 + 50 + 10 + textWidth(title, 36) + 28 + 6
	local plate = SlKit.Block(
		inner,
		{ Name = "Plate", Size = UDim2.fromOffset(plateW, 64), Radius = 16, Paint = "Header", ZIndex = 4 }
	)
	plate.Holder.Position = UDim2.fromOffset(24, 0)
	local eggSlot = make("Frame", {
		Name = "Egg",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, -2),
		Size = UDim2.fromOffset(50, 50),
		ZIndex = 9,
	}, plate.Content)
	MascotView.Viewport(eggSlot, MascotView.Egg(ctx.Egg.Id, 4), 0.95).ZIndex = 9
	local titleLabel = text(plate.Content, title, 36, WHITE, {
		Position = UDim2.fromOffset(74, 0),
		Size = UDim2.new(1, -74 - 28, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 9,
	});
	(titleLabel:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3

	-- Price 170 x 72, top right
	local price = button(
		inner,
		{ Name = "Price", Paint = PAINT.Green, W = 170, Icon = "cur_coin", IconSize = 42, TextSize = 28, ZIndex = 4 }
	)
	price.Holder.AnchorPoint = Vector2.new(1, 0)
	price.Holder.Position = UDim2.new(1, -24, 0, -4)

	-- Pet slots: 96 round, rarity colour, the pet turning in 3D, chance under it
	local pets = ctx.Pets
	local n = #pets
	local colW = 102
	local gap = if n > 1 then math.min(60, (W - 48 - n * colW) / (n - 1)) else 0
	local rowW = n * colW + (n - 1) * gap
	local slots = {}
	local foundViews = {}
	local deleteMode = false
	local spinners: { Model } = {}
	local marked: { [string]: boolean } = {}
	for index, mascot in pets do
		local color = SlKit.Rarity[mascot.Rarity] or Mascots.RarityColor(mascot.Rarity)
		local column = make("Frame", {
			Name = mascot.Id,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset((W - rowW) / 2 + (index - 1) * (colW + gap), 96),
			Size = UDim2.fromOffset(colW, 136),
			ZIndex = 4,
		}, inner)
		local drop = make("Frame", {
			Name = "Drop",
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(3, 6),
			Size = UDim2.fromOffset(96, 96),
			ZIndex = 4,
		}, column)
		corner(drop, 48)
		local circle = make("TextButton", {
			Name = "Slot",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(3, 0),
			Size = UDim2.fromOffset(96, 96),
			ZIndex = 5,
		}, column) :: TextButton
		corner(circle, 48)
		stroke(circle, INK, 3)
		-- the design's white shine along the top inside
		local shine = make("Frame", {
			Name = "Shine",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.fromOffset(90, 90),
			ZIndex = 5,
		}, circle)
		corner(shine, 45)
		local shineStroke = stroke(shine, WHITE, 3)
		shineStroke.Transparency = 0.45
		make("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.18, 0),
				NumberSequenceKeypoint.new(0.19, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, shineStroke)
		local petFrame = make("Frame", {
			Name = "Pet",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(104, 104),
			ZIndex = 6,
		}, circle)
		local model = MascotView.Mascot(mascot, 2, false)
		local view = MascotView.Viewport(petFrame, model, BOARD.PetFill)
		view.ZIndex = 6
		table.insert(spinners, model)
		-- Polish v2 U3: not found yet = a black silhouette; the rarest one not found also gets "???"
		local mystery = text(circle, "???", 30, WHITE, {
			Name = "Mystery",
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 8,
		})
		foundViews[mascot] = { View = view, Mystery = mystery, Column = column }
		local percent = text(column, "", 24, WHITE, {
			Name = "Chance",
			Position = UDim2.fromOffset(0, 104),
			Size = UDim2.new(1, 0, 0, 28),
			ZIndex = 7,
		});
		(percent:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3
		-- Polish v2 U3 (owner's reference): the rarity name under the chance, in its colour
		text(column, string.upper(mascot.Rarity), 17, color, {
			Name = "Rarity",
			Position = UDim2.fromOffset(-6, 130),
			Size = UDim2.new(1, 12, 0, 22),
			ZIndex = 7,
		})
		-- auto-delete: slot 70% dark + red X tile
		local dark = make("Frame", {
			Name = "Deleted",
			BackgroundColor3 = hex("0F2442"),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 8,
		}, circle)
		corner(dark, 48)
		local tile = SlKit.Block(
			dark,
			{ Name = "X", Size = UDim2.fromOffset(56, 56), Radius = 16, Paint = PAINT.Red, ZIndex = 9 }
		)
		tile.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
		tile.Holder.Position = UDim2.fromScale(0.5, 0.5)
		for _, angle in { 45, -45 } do
			local bar = make("Frame", {
				Name = "Bar",
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(8, 30),
				Rotation = angle,
				ZIndex = 13,
			}, tile.Content)
			corner(bar, 4)
			stroke(bar, INK, 2.5)
		end
		slots[mascot] = { Percent = percent, Dark = dark, Tile = tile.Holder, Color = color }
		if ctx.AutoDeleteRemote then
			circle.Activated:Connect(function()
				local AUTO_DELETE = Config.AutoDelete
				if not deleteMode then
					return -- (Polish v2 U3: tapping pets does nothing until the AUTO-DELETE gear is on)
				end
				if Mascots.RarityIndex(mascot.Rarity) > Mascots.RarityIndex(AUTO_DELETE.MaxRarity) then
					ctx.Toast(AUTO_DELETE.TooRare:format(string.upper(mascot.Rarity)))
					SlKit.Shake(column, 6, 0, 0.25)
					return
				end
				local on = not marked[mascot.Id]
				marked[mascot.Id] = if on then true else nil
				Sfx.Play("Click")
				ctx.AutoDeleteRemote:FireServer(mascot.Id, on)
				-- straight away; the server's AutoDelete attribute confirms it
				dark.Visible = on
				percent.TextTransparency = if on then 0.45 else 0
				if on then
					local scale = SlKit.ScaleOf(tile.Holder)
					scale.Scale = 0
					SlKit.Tween(scale, 0.1, "Snap", { Scale = 1.15 })
					task.delay(0.1, function()
						SlKit.Tween(scale, 0.08, "Over", { Scale = 1 })
					end)
				end
			end)
		end
	end

	-- One small line between the slots and the buttons: LUCKY odds and the auto-delete hint
	local note = text(inner, "", 20, hex("9FB3D1"), {
		Name = "Note",
		Position = UDim2.fromOffset(24 + 54, 254),
		Size = UDim2.new(1, -48 - 54, 0, 36),
		ZIndex = 6,
	})
	-- Polish v2 U3: AUTO-DELETE gear (owner's reference): on = tap pets to mark them X, off = taps do nothing
	local gear = button(inner, { Name = "AutoDeleteGear", Paint = PAINT.Blue, W = 48, H = 44, Icon = "hud_settings", IconSize = 30, ZIndex = 4 })
	gear.Holder.Position = UDim2.fromOffset(24, 250)
	gear.Holder.Visible = ctx.AutoDeleteRemote ~= nil

	-- HATCH 290 (key E) / AUTO 176 / x3 178 (+ Robux badge)
	local computer = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	local hatch = button(inner, {
		Name = "Hatch",
		Paint = PAINT.Green,
		W = 290,
		Text = "HATCH",
		TextSize = 30,
		Key = if computer and ctx.Prompt then "E" else nil,
		ZIndex = 4,
	})
	hatch.Holder.Position = UDim2.fromOffset(24, 300)
	local auto = button(inner, { Name = "Auto", Paint = PAINT.Blue, W = 176, Text = "AUTO", TextSize = 30, ZIndex = 4 })
	auto.Holder.Position = UDim2.fromOffset(24 + 290 + 14, 300)
	local triple =
		button(inner, { Name = "Triple", Paint = PAINT.Pink, W = 178, Text = "x3", TextSize = 30, ZIndex = 4 })
	triple.Holder.Position = UDim2.fromOffset(24 + 290 + 14 + 176 + 14, 300)
	local badge = make("Frame", {
		Name = "Badge",
		BackgroundColor3 = PAINT.Green[1],
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 10, 0, -14),
		Size = UDim2.fromOffset(38, 38),
		ZIndex = 20,
	}, triple.Holder)
	corner(badge, 19)
	stroke(badge, INK, 3)
	-- (the Robux glyph only draws in Builder Sans)
	local glyph = text(badge, ROBUX_GLYPH, 24, WHITE, {
		FontFace = Font.fromEnum(Enum.Font.BuilderSansBold),
		ZIndex = 21,
	})
	local badgeTick = SlKit.Image(badge, "ui_tick", 30, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 21,
		Visible = false,
	})

	local function refresh()
		local unlocked, why, free, affordable = ctx.State()
		-- price
		if not unlocked then
			price:SetState("locked")
			price:SetText(string.upper(tostring(why or "LOCKED")))
		else
			price:SetState("normal")
			price:Repaint(if affordable then PAINT.Green else PAINT.Red)
			price:SetText(if free > 0 then ("FREE x%d"):format(free) else Currency.Format(ctx.Egg.Price))
			if price.Icon then
				price.Icon.Visible = free <= 0
			end
		end
		price.Label.TextSize = if #price.Label.Text > 7 then 22 else 28
		-- buttons
		if hatch:State() ~= "pressed" then
			hatch:SetState(if unlocked and affordable then "normal" else "locked")
		end
		auto:SetState(if not (unlocked and affordable) then "locked" elseif ctx.AutoOn() then "ready" else "normal")
		local owns = ctx.TripleOwned()
		glyph.Visible = not owns
		badgeTick.Visible = owns
		badge.BackgroundColor3 = if owns then INK else PAINT.Green[1]
		-- odds
		local odds = ctx.Odds()
		for mascot, slot in slots do
			local chance = odds[mascot] or 0
			slot.Percent.Text = percentText(chance)
			slot.Percent.TextColor3 = if chance <= 0.01 then slot.Color else WHITE
		end
		local luck = ctx.LuckText()
		local hint = if not ctx.AutoDeleteRemote then ""
			elseif deleteMode then "TAP PETS TO AUTO-DELETE THEM"
			else "GEAR = AUTO-DELETE"
		note.Text = if luck ~= "" and hint ~= "" then luck .. "  ·  " .. hint else luck .. hint
	end

	gear.Holder.Activated:Connect(function()
		deleteMode = not deleteMode
		Sfx.Play("Click")
		gear:Paint(if deleteMode then PAINT.Red else PAINT.Blue)
		SlKit.Pulse(gear.Holder, 1.15, 0.2)
		refresh()
	end)

	local function refreshMarks()
		marked = {}
		for id in string.gmatch(player:GetAttribute("AutoDelete") or "", "[^,]+") do
			marked[id] = true
		end
		for mascot, slot in slots do
			slot.Dark.Visible = marked[mascot.Id] == true
			slot.Percent.TextTransparency = if marked[mascot.Id] then 0.45 else 0
		end
	end
	player:GetAttributeChangedSignal("AutoDelete"):Connect(refreshMarks)

	-- Polish v2 U3: pets you've never found are black (chance still shows: honest odds); the rarest unfound one says
	-- "???". A pet found just now pops back into colour.
	local wasFound: { [any]: boolean } = {}
	local function refreshFound()
		local found = {}
		for _, id in string.split(player:GetAttribute("PetsFound") or "", ",") do
			found[id] = true
		end
		local rarest, rarestRank = nil, -1
		for mascot, refs in foundViews do
			local isFound = found[mascot.Id] == true
			refs.View.ImageColor3 = if isFound then WHITE else Color3.new(0, 0, 0)
			refs.Mystery.Visible = false
			if not isFound and Mascots.RarityIndex(mascot.Rarity) > rarestRank then
				rarest, rarestRank = mascot, Mascots.RarityIndex(mascot.Rarity)
			end
			if isFound and wasFound[mascot] == false then
				SlKit.Pulse(refs.Column, 1.25, 0.4)
			end
			wasFound[mascot] = isFound
		end
		if rarest then
			foundViews[rarest].Mystery.Visible = true
		end
	end
	refreshFound()
	player:GetAttributeChangedSignal("PetsFound"):Connect(refreshFound)
	refreshMarks()

	hatch.Holder.Activated:Connect(function()
		if hatch.Holder:GetAttribute("KitDisabled") then
			SlKit.Shake(hatch.Holder, 8, 0, 0.3)
		end
		ctx.Hatch()
	end)
	auto.Holder.Activated:Connect(function()
		if auto.Holder:GetAttribute("KitDisabled") then
			SlKit.Shake(auto.Holder, 8, 0, 0.3)
			ctx.Hatch() -- (says why: locked / not enough coins)
			return
		end
		ctx.Auto()
		refresh()
	end)
	triple.Holder.Activated:Connect(function()
		if ctx.TripleOwned() then
			ctx.Hatch()
		else
			ctx.BuyTriple()
		end
	end)
	price.Holder.Activated:Connect(function()
		ctx.Hatch()
	end)
	-- holding E on a computer presses HATCH
	if ctx.Prompt then
		ctx.Prompt.PromptButtonHoldBegan:Connect(function()
			if hatch:State() == "normal" then
				hatch:SetState("pressed")
				hatch:SetPressed(true)
			end
		end)
		ctx.Prompt.PromptButtonHoldEnded:Connect(function()
			if hatch:State() == "pressed" then
				hatch:SetPressed(false)
				hatch:SetState("normal")
				refresh()
			end
		end)
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	refit()

	-- Walk near: show (scale 0.7 -> 1 overshoot, 0.2 s); walk away or a hatch starts: hide (0.12 s snap)
	local shown = false
	local spin = 0
	local sinceRefresh = math.huge
	local function show(on: boolean)
		if on == shown then
			return
		end
		shown = on
		if on then
			gui.Enabled = true
			refit()
			refresh()
			pop.Scale = 0.7
			SlKit.Tween(pop, 0.2, "Over", { Scale = 1 })
		else
			SlKit.Tween(pop, 0.12, "Snap", { Scale = 0.7 })
			task.delay(0.12, function()
				if not shown then
					gui.Enabled = false
				end
			end)
		end
	end
	local near = false
	RunService.RenderStepped:Connect(function(dt)
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local distance = if rootPart
			then ((rootPart.Position - ctx.Base) * Vector3.new(1, 0, 1)).Magnitude
			else math.huge
		if distance <= BOARD.ShowDistance then
			near = true
		elseif distance > BOARD.HideDistance then
			near = false
		end
		show(near and not ctx.Busy())
		if not shown then
			return
		end
		sinceRefresh += dt
		if sinceRefresh >= 0.25 then -- coins, free eggs and passes change often: a light poll while it's up
			sinceRefresh = 0
			refresh()
		end
		if BOARD.Spin ~= 0 then
			spin += math.rad(BOARD.Spin) * dt
			local turn = CFrame.Angles(0, spin, 0)
			for _, model in spinners do
				model:PivotTo(turn)
			end
		end
	end)

	return {
		Gui = gui,
		Shown = function()
			return shown
		end,
	}
end

-- ===== Polish v2 U3 part 2: the egg board in the owner's reference layout (Config.EggBoard.Grid) =====
-- Buff lines on top (x2 LUCK, TRIPLE HATCH), a white card with the pets 3 across (chance on top, the pet turning in
-- 3D on a tile in its rarity colour, rarity name under it; never found = black, the rarest unfound one "???"), the
-- egg's name on a gold tab over the card, the price pill right of the card (red = can't pay, FREE xN) and four round
-- buttons under it: AUTO-DELETE (gear: on = tap pets to X them, off = taps do nothing), AUTO (T), OPEN 3 (R: the
-- TRIPLE HATCH pass, Robux badge until owned) and OPEN 1 (E, the stand's hold prompt). Key letters on computers only.
-- Same ctx as EggV2.Board, plus Luck() -> number; Hatch(count) gets 1 or 3. Returns { Gui, Shown() -> bool }.
local CARD_PAINT = { hex("F4F7FC"), hex("BFCBDD"), WHITE }

-- A round button: circle block + a word, key letter or icon inside + a label under it
local function roundButton(parent: Instance, opts: { [string]: any }): { [string]: any }
	local size = opts.Size
	local b = SlKit.Block(parent, {
		Name = opts.Name,
		Button = true,
		Size = UDim2.fromOffset(size, size),
		Radius = size / 2,
		Paint = opts.Paint,
		Lip = 6,
		ZIndex = 4,
	}) :: any
	local inside = text(b.Content, opts.Inside or "", opts.InsideSize or 40, WHITE, { Name = "Inside", ZIndex = 9 });
	(inside:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3
	local icon: ImageLabel? = nil
	if opts.Icon then
		icon = SlKit.Image(b.Content, opts.Icon, math.floor(size * 0.55), {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 9,
		})
	end
	local lock = SlKit.Image(b.Content, "ui_lock", math.floor(size * 0.42), {
		Name = "Lock",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 10,
		Visible = false,
	})
	local label = text(b.Holder, opts.Label or "", 20, WHITE, {
		Name = "Label",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 2),
		Size = UDim2.fromOffset(150, 26),
		ZIndex = 9,
	});
	(label:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3
	-- READY (auto on): a white ring round the circle, the button bobs
	local ring = make("Frame", {
		Name = "Ready",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size + 14, size + 14),
		Visible = false,
		ZIndex = 3,
	}, b.Holder)
	corner(ring, (size + 14) / 2)
	stroke(ring, WHITE, 4)
	local paint = opts.Paint
	local state = "normal"
	local stopBob: (() -> ())? = nil
	function b.SetState(_self, newState: string)
		if newState == state then
			return
		end
		state = newState
		b.Holder:SetAttribute("KitDisabled", newState == "locked")
		b:Paint(if newState == "locked" then PAINT.Locked else paint)
		lock.Visible = newState == "locked"
		inside.Visible = newState ~= "locked"
		if icon then
			icon.Visible = newState ~= "locked"
		end
		ring.Visible = newState == "ready"
		if stopBob then
			stopBob()
			stopBob = nil
		end
		if newState == "ready" then
			stopBob = SlKit.Bob(b.Holder, 5, 1)
		end
	end
	function b.Repaint(_self, newPaint)
		paint = newPaint
		if state ~= "locked" then
			b:Paint(newPaint)
		end
	end
	b.Inside = inside
	b.Label = label
	b.State = function()
		return state
	end
	return b
end

function EggV2.GridBoard(ctx: { [string]: any }): { [string]: any }
	local pets = ctx.Pets
	local n = #pets
	local PER_ROW = 3
	local rows = math.max(1, math.ceil(n / PER_ROW))
	local TILE_W, TILE_H, SQUARE, GAP = 116, 146, 92, 10
	local PAD = 18
	local cardW = PER_ROW * TILE_W + (PER_ROW - 1) * GAP + PAD * 2
	local cardH = 34 + rows * TILE_H + (rows - 1) * GAP + 12 -- (34: under the name tab)
	local BUFF_H, BUFFS = 40, 2
	local BTN, BTN_STEP = 84, 126
	local W = 820
	local cardTop = BUFFS * BUFF_H + 30
	local buttonsTop = cardTop + cardH + 22
	local H = buttonsTop + BTN + 30
	local studsPerPixel = BOARD.Width / 720 -- (same pixel size as the V6 board)
	local studsW, studsH = W * studsPerPixel, H * studsPerPixel
	local gui = make("BillboardGui", {
		Name = "EggOdds", -- (AreaSignController finds the board by this name to sit above it)
		Size = UDim2.fromScale(studsW, studsH), -- scale = studs: the same size on every screen
		StudsOffset = Vector3.new(0, BOARD.GridHeight + studsH / 2, 0),
		LightInfluence = 0,
		Active = true,
		Enabled = false,
		ResetOnSpawn = false,
		Adornee = ctx.Shell,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	-- (pet viewports on a billboard in the Workspace often don't draw: it lives in PlayerGui, pinned by Adornee)
	local root = make("Frame", {
		Name = "Board",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(W, H),
	}, gui)
	local fit = make("UIScale", { Name = "Fit" }, root)
	local inner = make("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1, 1),
	}, root)
	local pop = make("UIScale", { Name = "Pop" }, inner) -- (scales from the bottom middle, over the egg)
	local function refit()
		fit.Scale = math.max(gui.AbsoluteSize.X, 1) / W
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	-- Buff lines (nearest the card first): x2 LUCK, TRIPLE HATCH
	local buffs = make("Frame", {
		Name = "Buffs",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(W, BUFFS * BUFF_H),
		ZIndex = 4,
	}, inner)
	make("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, buffs)
	local function buffLine(order: number, icon: string, color: Color3): TextLabel
		local line = make("Frame", {
			Name = "Buff" .. order,
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(W, BUFF_H),
			LayoutOrder = -order,
			Visible = false,
			ZIndex = 4,
		}, buffs)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, line)
		SlKit.Image(line, icon, 34, { LayoutOrder = 1, ZIndex = 5 })
		local words = text(line, "", 30, color, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, BUFF_H),
			LayoutOrder = 2,
			ZIndex = 5,
		});
		(words:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3
		return words
	end
	local luckLine = buffLine(1, "potion_luck", C.Value)
	local tripleLine = buffLine(2, "pass_triple_hatch", PAINT.Pink[3])
	tripleLine.Text = "TRIPLE HATCH"

	-- The card: white, ink outline, grey lip; the egg's name on a gold tab over its top edge
	local cardX = (W - cardW) / 2
	local card = SlKit.Block(
		inner,
		{ Name = "Card", Size = UDim2.fromOffset(cardW, cardH + 6), Radius = 20, Paint = CARD_PAINT }
	)
	card.Holder.Position = UDim2.fromOffset(cardX, cardTop)
	local title = string.upper((Config.EggLooks[ctx.Egg.Id] or {}).Name or ctx.Egg.Name or "EGG")
	local tabW = math.min(cardW + 40, 12 + 40 + 8 + textWidth(title, 28) + 20)
	local tab = SlKit.Block(
		inner,
		{ Name = "Plate", Size = UDim2.fromOffset(tabW, 48), Radius = 14, Paint = "Header", Lip = 5, ZIndex = 6 }
	)
	tab.Holder.Position = UDim2.fromOffset((W - tabW) / 2, cardTop - 26)
	local eggSlot = make("Frame", {
		Name = "Egg",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, -2),
		Size = UDim2.fromOffset(40, 40),
		ZIndex = 11,
	}, tab.Content)
	MascotView.Viewport(eggSlot, MascotView.Egg(ctx.Egg.Id, 4), 0.95).ZIndex = 11
	local titleLabel = text(tab.Content, title, 28, WHITE, {
		Position = UDim2.fromOffset(60, 0),
		Size = UDim2.new(1, -60 - 14, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
	});
	(titleLabel:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3

	-- Price pill right of the card (tap = OPEN 1)
	local price = button(
		inner,
		{ Name = "Price", Paint = PAINT.Green, W = 176, H = 64, Icon = "cur_coin", IconSize = 38, TextSize = 26, ZIndex = 4 }
	)
	price.Holder.AnchorPoint = Vector2.new(0, 0.5)
	price.Holder.Position = UDim2.fromOffset(cardX + cardW + 12, cardTop + (cardH + 6) / 2)

	-- Pet tiles, 3 across (a short last row is centred)
	local slots = {}
	local foundViews = {}
	local deleteMode = false
	local spinners: { Model } = {}
	local marked: { [string]: boolean } = {}
	for index, mascot in pets do
		local color = SlKit.Rarity[mascot.Rarity] or Mascots.RarityColor(mascot.Rarity)
		local row = math.ceil(index / PER_ROW)
		local inRow = if row < rows then PER_ROW else n - (rows - 1) * PER_ROW
		local col = (index - 1) % PER_ROW
		local rowW = inRow * TILE_W + (inRow - 1) * GAP
		local column = make("Frame", {
			Name = mascot.Id,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(
				cardX + (cardW - rowW) / 2 + col * (TILE_W + GAP),
				cardTop + 34 + (row - 1) * (TILE_H + GAP)
			),
			Size = UDim2.fromOffset(TILE_W, TILE_H),
			ZIndex = 4,
		}, inner)
		local percent = text(column, "", 24, WHITE, {
			Name = "Chance",
			Size = UDim2.new(1, 0, 0, 26),
			ZIndex = 7,
		});
		(percent:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3
		local tileButton = make("TextButton", {
			Name = "Slot",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset((TILE_W - SQUARE) / 2, 28),
			Size = UDim2.fromOffset(SQUARE, SQUARE),
			ZIndex = 5,
		}, column) :: TextButton
		corner(tileButton, 16)
		stroke(tileButton, INK, 3)
		local petFrame = make("Frame", {
			Name = "Pet",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(SQUARE + 8, SQUARE + 8),
			ZIndex = 6,
		}, tileButton)
		local model = MascotView.Mascot(mascot, 2, false)
		local view = MascotView.Viewport(petFrame, model, BOARD.PetFill)
		view.ZIndex = 6
		table.insert(spinners, model)
		local mystery = text(tileButton, "???", 32, WHITE, {
			Name = "Mystery",
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 8,
		});
		(mystery:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3
		foundViews[mascot] = { View = view, Mystery = mystery, Column = column }
		text(column, string.upper(mascot.Rarity), 20, color, {
			Name = "Rarity",
			Position = UDim2.fromOffset(-8, 28 + SQUARE + 1),
			Size = UDim2.new(1, 16, 0, 24),
			ZIndex = 7,
		})
		-- auto-delete: tile dark + red X
		local dark = make("Frame", {
			Name = "Deleted",
			BackgroundColor3 = hex("0F2442"),
			BackgroundTransparency = 0.3,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 8,
		}, tileButton)
		corner(dark, 16)
		local tile = SlKit.Block(
			dark,
			{ Name = "X", Size = UDim2.fromOffset(52, 52), Radius = 14, Paint = PAINT.Red, ZIndex = 9 }
		)
		tile.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
		tile.Holder.Position = UDim2.fromScale(0.5, 0.5)
		for _, angle in { 45, -45 } do
			local bar = make("Frame", {
				Name = "Bar",
				BackgroundColor3 = WHITE,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(8, 28),
				Rotation = angle,
				ZIndex = 13,
			}, tile.Content)
			corner(bar, 4)
			stroke(bar, INK, 2.5)
		end
		slots[mascot] = { Percent = percent, Dark = dark, Color = color }
		if ctx.AutoDeleteRemote then
			tileButton.Activated:Connect(function()
				local AUTO_DELETE = Config.AutoDelete
				if not deleteMode then
					return -- (tapping pets does nothing until the AUTO-DELETE gear is on)
				end
				if Mascots.RarityIndex(mascot.Rarity) > Mascots.RarityIndex(AUTO_DELETE.MaxRarity) then
					ctx.Toast(AUTO_DELETE.TooRare:format(string.upper(mascot.Rarity)))
					SlKit.Shake(column, 6, 0, 0.25)
					return
				end
				local on = not marked[mascot.Id]
				marked[mascot.Id] = if on then true else nil
				Sfx.Play("Click")
				ctx.AutoDeleteRemote:FireServer(mascot.Id, on)
				-- straight away; the server's AutoDelete attribute confirms it
				dark.Visible = on
				percent.TextTransparency = if on then 0.45 else 0
				if on then
					local scale = SlKit.ScaleOf(tile.Holder)
					scale.Scale = 0
					SlKit.Tween(scale, 0.1, "Snap", { Scale = 1.15 })
					task.delay(0.1, function()
						SlKit.Tween(scale, 0.08, "Over", { Scale = 1 })
					end)
				end
			end)
		end
	end

	-- Round buttons: AUTO-DELETE / AUTO (T) / OPEN 3 (R) / OPEN 1 (E)
	local computer = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	local order = {}
	local gear = roundButton(
		inner,
		{ Name = "AutoDeleteGear", Size = BTN, Paint = PAINT.Blue, Icon = "hud_settings", Label = "AUTO-DELETE" }
	)
	if ctx.AutoDeleteRemote then
		table.insert(order, gear)
	else
		gear.Holder.Visible = false
	end
	local auto = roundButton(inner, {
		Name = "Auto",
		Size = BTN,
		Paint = PAINT.Blue,
		Inside = if computer then "T" else "OFF",
		InsideSize = if computer then 40 else 26,
		Label = "AUTO",
	})
	local triple = roundButton(
		inner,
		{ Name = "Open3", Size = BTN, Paint = PAINT.Pink, Inside = if computer then "R" else "x3", Label = "OPEN 3" }
	)
	local single = roundButton(inner, {
		Name = "Open1",
		Size = BTN,
		Paint = PAINT.Green,
		Inside = if computer and ctx.Prompt then "E" else "x1",
		Label = "OPEN 1",
	})
	table.insert(order, auto)
	table.insert(order, triple)
	table.insert(order, single)
	local rowSpan = (#order - 1) * BTN_STEP
	for i, b in order do
		b.Holder.AnchorPoint = Vector2.new(0.5, 0)
		b.Holder.Position = UDim2.fromOffset(W / 2 - rowSpan / 2 + (i - 1) * BTN_STEP, buttonsTop)
	end
	-- Robux badge on OPEN 3 until the TRIPLE HATCH pass is owned
	local badge = make("Frame", {
		Name = "Badge",
		BackgroundColor3 = PAINT.Green[1],
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0, -8),
		Size = UDim2.fromOffset(34, 34),
		ZIndex = 20,
	}, triple.Holder)
	corner(badge, 17)
	stroke(badge, INK, 3)
	-- (the Robux glyph only draws in Builder Sans)
	text(badge, ROBUX_GLYPH, 22, WHITE, { FontFace = Font.fromEnum(Enum.Font.BuilderSansBold), ZIndex = 21 })

	local function refresh()
		local unlocked, why, free, affordable = ctx.State()
		-- price
		if not unlocked then
			price:SetState("locked")
			price:SetText(string.upper(tostring(why or "LOCKED")))
		else
			price:SetState("normal")
			price:Repaint(if affordable then PAINT.Green else PAINT.Red)
			price:SetText(if free > 0 then ("FREE x%d"):format(free) else Currency.Format(ctx.Egg.Price))
			if price.Icon then
				price.Icon.Visible = free <= 0
			end
		end
		price.Label.TextSize = if #price.Label.Text > 7 then 20 else 26
		-- buttons
		local ready = unlocked and affordable
		if single:State() ~= "pressed" then
			single:SetState(if ready then "normal" else "locked")
		end
		local autoOn = ctx.AutoOn()
		auto:SetState(if not ready then "locked" elseif autoOn then "ready" else "normal")
		if not computer then
			auto.Inside.Text = if autoOn then "ON" else "OFF"
		end
		local owns = ctx.TripleOwned()
		badge.Visible = not owns
		triple:SetState(if owns and not ready then "locked" else "normal")
		gear:Repaint(if deleteMode then PAINT.Red else PAINT.Blue)
		gear.Label.Text = if deleteMode then "TAP PETS!" else "AUTO-DELETE"
		gear.Label.TextColor3 = if deleteMode then PAINT.Red[3] else WHITE
		-- odds
		local odds = ctx.Odds()
		for mascot, slot in slots do
			local chance = odds[mascot] or 0
			slot.Percent.Text = percentText(chance)
			slot.Percent.TextColor3 = if chance <= 0.01 then slot.Color else WHITE
		end
		-- buffs
		local luck = ctx.Luck()
		luckLine.Parent.Visible = luck > 1
		luckLine.Text = ("x%s LUCK"):format((("%.1f"):format(luck):gsub("%.0$", "")))
		tripleLine.Parent.Visible = owns
	end

	gear.Holder.Activated:Connect(function()
		deleteMode = not deleteMode
		Sfx.Play("Click")
		SlKit.Pulse(gear.Holder, 1.15, 0.2)
		refresh()
	end)

	local function refreshMarks()
		marked = {}
		for id in string.gmatch(player:GetAttribute("AutoDelete") or "", "[^,]+") do
			marked[id] = true
		end
		for mascot, slot in slots do
			slot.Dark.Visible = marked[mascot.Id] == true
			slot.Percent.TextTransparency = if marked[mascot.Id] then 0.45 else 0
		end
	end
	player:GetAttributeChangedSignal("AutoDelete"):Connect(refreshMarks)

	-- Pets you've never found are black (chance still shows: honest odds); the rarest unfound one says "???".
	-- Polish v2 D4: a pet found just now flips over from black to colour (Config.PetMotion.BoardFlip). Found during a
	-- hatch (the board hides then), it flips the next time the board shows.
	local wasFound: { [any]: boolean } = {}
	local pendingFlips: { [any]: boolean } = {}
	local function flip(refs: { [string]: any })
		local frame = refs.View.Parent :: GuiObject
		refs.Base = refs.Base or frame.Size
		local base = refs.Base :: UDim2
		Motion.Drive(frame, "Flip", 1, -1, {
			Time = PET_MOTION.BoardFlip,
			Style = Enum.EasingStyle.Sine,
			Dir = Enum.EasingDirection.InOut,
		}, function(p)
			local w = math.max(math.abs(p), 0.03)
			frame.Size = UDim2.new(base.X.Scale * w, base.X.Offset * w, base.Y.Scale, base.Y.Offset)
			refs.View.ImageColor3 = if p < 0 then WHITE else Color3.new(0, 0, 0)
		end, function()
			frame.Size = base
			refs.View.ImageColor3 = WHITE
			SlKit.Pulse(refs.Column, 1.25, 0.4)
		end)
	end
	local function playFlips()
		local list = {}
		for mascot in pendingFlips do
			table.insert(list, mascot)
		end
		table.clear(pendingFlips)
		table.sort(list, function(a, b)
			return Mascots.RarityIndex(a.Rarity) < Mascots.RarityIndex(b.Rarity)
		end)
		Motion.Stagger(list, function(mascot)
			flip(foundViews[mascot])
			Sfx.Play("Reveal", 0.5)
		end, 0.2, 0.25)
	end
	local function refreshFound()
		local found = {}
		for _, id in string.split(player:GetAttribute("PetsFound") or "", ",") do
			found[id] = true
		end
		local rarest, rarestRank = nil, -1
		for mascot, refs in foundViews do
			local isFound = found[mascot.Id] == true
			if isFound and wasFound[mascot] == false then
				pendingFlips[mascot] = true
			end
			refs.View.ImageColor3 = if isFound and not pendingFlips[mascot] then WHITE else Color3.new(0, 0, 0)
			refs.Mystery.Visible = false
			if not isFound and Mascots.RarityIndex(mascot.Rarity) > rarestRank then
				rarest, rarestRank = mascot, Mascots.RarityIndex(mascot.Rarity)
			end
			wasFound[mascot] = isFound
		end
		if rarest then
			foundViews[rarest].Mystery.Visible = true
		end
		if next(pendingFlips) and gui.Enabled and not ctx.Busy() then
			playFlips()
		end
	end
	refreshFound()
	player:GetAttributeChangedSignal("PetsFound"):Connect(refreshFound)
	refreshMarks()

	local function openOne()
		if single.Holder:GetAttribute("KitDisabled") then
			SlKit.Shake(single.Holder, 8, 0, 0.3)
		end
		ctx.Hatch(1)
	end
	local function openThree()
		if not ctx.TripleOwned() then
			ctx.BuyTriple()
			return
		end
		if triple.Holder:GetAttribute("KitDisabled") then
			SlKit.Shake(triple.Holder, 8, 0, 0.3)
		end
		ctx.Hatch(3)
	end
	local function toggleAuto()
		if auto.Holder:GetAttribute("KitDisabled") then
			SlKit.Shake(auto.Holder, 8, 0, 0.3)
			ctx.Hatch(1) -- (says why: locked / not enough coins)
			return
		end
		ctx.Auto()
		refresh()
	end
	single.Holder.Activated:Connect(openOne)
	triple.Holder.Activated:Connect(openThree)
	auto.Holder.Activated:Connect(toggleAuto)
	price.Holder.Activated:Connect(openOne)
	-- holding E (the stand's prompt) presses OPEN 1
	if ctx.Prompt then
		ctx.Prompt.PromptButtonHoldBegan:Connect(function()
			if single:State() == "normal" then
				single:SetState("pressed")
				single:SetPressed(true)
			end
		end)
		ctx.Prompt.PromptButtonHoldEnded:Connect(function()
			if single:State() == "pressed" then
				single:SetPressed(false)
				single:SetState("normal")
				refresh()
			end
		end)
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	refit()

	-- Walk near: show (scale 0.7 -> 1 overshoot, 0.2 s); walk away or a hatch starts: hide (0.12 s snap)
	local shown = false
	local spin = 0
	local sinceRefresh = math.huge
	local function show(on: boolean)
		if on == shown then
			return
		end
		shown = on
		if on then
			gui.Enabled = true
			refit()
			refresh()
			pop.Scale = 0.7
			SlKit.Tween(pop, 0.2, "Over", { Scale = 1 })
			if next(pendingFlips) then
				playFlips() -- (pets found while it was hidden)
			end
		else
			SlKit.Tween(pop, 0.12, "Snap", { Scale = 0.7 })
			task.delay(0.12, function()
				if not shown then
					gui.Enabled = false
				end
			end)
		end
	end
	-- T = AUTO, R = OPEN 3 while the board is up (E is the stand's own prompt)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not shown then
			return
		end
		if input.KeyCode == Enum.KeyCode.T then
			SlKit.Pulse(auto.Holder, 0.9, 0.16)
			toggleAuto()
		elseif input.KeyCode == Enum.KeyCode.R then
			SlKit.Pulse(triple.Holder, 0.9, 0.16)
			openThree()
		end
	end)
	local near = false
	RunService.RenderStepped:Connect(function(dt)
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local distance = if rootPart
			then ((rootPart.Position - ctx.Base) * Vector3.new(1, 0, 1)).Magnitude
			else math.huge
		if distance <= BOARD.ShowDistance then
			near = true
		elseif distance > BOARD.HideDistance then
			near = false
		end
		show(near and not ctx.Busy())
		if not shown then
			return
		end
		sinceRefresh += dt
		if sinceRefresh >= 0.25 then -- coins, free eggs and passes change often: a light poll while it's up
			sinceRefresh = 0
			refresh()
		end
		if BOARD.Spin ~= 0 then
			spin += math.rad(BOARD.Spin) * dt
			local turn = CFrame.Angles(0, spin, 0)
			for _, model in spinners do
				model:PivotTo(turn)
			end
		end
	end)

	return {
		Gui = gui,
		Shown = function()
			return shown
		end,
	}
end

-- ===== FUSE PETS =====
-- ctx: Fusable() -> { mascot } (most copies first), Owned() -> { [id]: count }, Fuse(mascot) (closes this window and
-- plays the merge), OnOpen(), OnClose(). Returns { Open(), Close(), IsOpen() -> bool }.
function EggV2.Fusion(ctx: { [string]: any }): { [string]: any }
	local FW, FH = 1100, 720
	local CARD_W, CARD_H = 180, 238
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = make("ScreenGui", {
		Name = "FuseV2UI",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = false,
	}, playerGui)
	local backdrop = make("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = NIGHT,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, gui)
	local fit = make("Frame", {
		Name = "Fuse",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(FW, FH),
	}, gui)
	local fitScale = make("UIScale", { Name = "Fit" }, fit)
	local win = make("Frame", { Name = "Window", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, fit)
	local openScale = make("UIScale", { Name = "OpenScale" }, win)
	local function refit()
		local view = gui.AbsoluteSize
		if view.X > 0 then
			fitScale.Scale = math.min((view.X - 40) / (FW + 56), (view.Y - 40) / (FH + 90), 1)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	SlKit.Block(win, { Name = "Body", Size = UDim2.fromScale(1, 1), Radius = 16, Paint = "Window", Lip = 8 })
	-- Header plate: sparkle + FUSE PETS (h 68, title 40)
	local plateW = 40 + 42 + 12 + textWidth("FUSE PETS", 40) + 40
	local header =
		SlKit.Block(win, { Name = "Header", Size = UDim2.fromOffset(plateW, 74), Radius = 16, Paint = "Header" })
	header.Holder.AnchorPoint = Vector2.new(0.5, 0)
	header.Holder.Position = UDim2.new(0.5, 0, 0, -32)
	header.Holder.ZIndex = 5
	local headRow =
		make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, header.Content)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, headRow)
	SlKit.Image(headRow, "ui_sparkle", 42, { LayoutOrder = 1, ZIndex = 9 })
	local title = text(headRow, "FUSE PETS", 40, WHITE, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		ZIndex = 9,
	});
	(title:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 3
	local close = PetsV2.CloseButton(win, 72)
	close.Holder.AnchorPoint = Vector2.new(1, 0)
	close.Holder.Position = UDim2.new(1, 24, 0, -24)
	close.Holder.ZIndex = 5

	-- Count chip "2/3" (paw + number, green when ready)
	local chip = make("Frame", {
		Name = "Count",
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(120, 44),
		ZIndex = 5,
	}, win)
	corner(chip, 22)
	local chipRow =
		make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, chip)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, chipRow)
	SlKit.Image(chipRow, "hud_pets", 28, { LayoutOrder = 1, ZIndex = 6 })
	local countLabel = text(chipRow, "0/3", 24, WHITE, {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		ZIndex = 6,
	})

	-- Cards row: 3 slots, arrow, the Shiny (x1.12)
	local NEED = Config.Economy.Mascots.ShinyMerge
	local RESULT_ZOOM = 1.12
	local rowW = NEED * CARD_W + (NEED - 1) * 18 + 18 + 96 + 18 + CARD_W * RESULT_ZOOM
	local rowX, rowY = (FW - rowW) / 2, 124
	local slotFrames: { Frame } = {}
	for i = 1, NEED do
		local slot = make("Frame", {
			Name = "Slot" .. i,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(rowX + (i - 1) * (CARD_W + 18), rowY + 14),
			Size = UDim2.fromOffset(CARD_W, CARD_H),
			ZIndex = 4,
		}, win)
		slotFrames[i] = slot
	end
	local arrowX = rowX + NEED * (CARD_W + 18)
	local arrow = SlKit.Image(win, "ui_arrow", 96, {
		Name = "Arrow",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromOffset(arrowX, rowY + 14 + CARD_H / 2),
		ZIndex = 5,
	})
	local resultX = arrowX + 96 + 18
	local resultWrap = make("Frame", {
		Name = "Result",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(resultX + CARD_W * RESULT_ZOOM / 2, rowY + 14 + CARD_H / 2),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		ZIndex = 4,
	}, win)
	make("UIScale", { Name = "Zoom", Scale = RESULT_ZOOM }, resultWrap)

	-- PICK A PET: round coins (rarity colour, the pet in 3D, "x3")
	local pickLabel = text(win, "PICK A PET", 20, hex("9FB3D1"), {
		Name = "PickLabel",
		Position = UDim2.fromOffset(0, 420),
		Size = UDim2.new(1, 0, 0, 24),
		ZIndex = 5,
	})
	local picker = make("ScrollingFrame", {
		Name = "Picker",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(40, 450),
		Size = UDim2.new(1, -80, 0, 120),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = WHITE,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
		ZIndex = 5,
	}, win) :: ScrollingFrame
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, picker)

	-- FUSE 340 x 76 (green + ready bounce) / NEED 1 MORE (red)
	local fuse = button(
		win,
		{ Name = "FuseButton", Paint = PAINT.Green, W = 340, H = 76, Text = "FUSE", TextSize = 30, ZIndex = 4 }
	)
	fuse.Holder.AnchorPoint = Vector2.new(0.5, 1)
	fuse.Holder.Position = UDim2.new(0.5, 0, 1, -34)

	local picked: any = nil
	local ready = false
	local slotCards: { GuiObject } = {}
	local refreshAll: (animate: boolean?) -> ()

	local function coin(mascot, count: number, on: boolean, order: number)
		local color = SlKit.Rarity[mascot.Rarity] or Mascots.RarityColor(mascot.Rarity)
		local holder = make("TextButton", {
			Name = mascot.Id,
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.fromOffset(100, 104),
			ZIndex = 5,
		}, picker) :: TextButton
		local drop = make("Frame", {
			Name = "Drop",
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 14),
			Size = UDim2.fromOffset(84, 84),
			ZIndex = 5,
		}, holder)
		corner(drop, 42)
		local circle = make("Frame", {
			Name = "Coin",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(84, 84),
			ZIndex = 6,
		}, holder)
		corner(circle, 42)
		stroke(circle, INK, 3)
		if on then
			local ring = make("Frame", {
				Name = "Picked",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(-7, -7),
				Size = UDim2.new(1, 14, 1, 14),
				ZIndex = 6,
			}, circle)
			corner(ring, 50)
			stroke(ring, WHITE, 4)
		end
		local pet = make("Frame", {
			Name = "Pet",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(92, 92),
			ZIndex = 7,
		}, circle)
		MascotView.Viewport(pet, MascotView.Mascot(mascot, 2, false), 0.9).ZIndex = 7
		text(holder, ("x%d"):format(count), 20, if count >= NEED then C.Value else WHITE, {
			Name = "Count",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, 2, 1, 0),
			Size = UDim2.fromOffset(60, 24),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 9,
		})
		holder.Activated:Connect(function()
			if not picked or picked.Id ~= mascot.Id then
				Sfx.Play("Click")
				picked = mascot
				refreshAll(true)
			end
		end)
	end

	local function emptySlot(parent: Instance)
		local box = make("Frame", {
			Name = "Empty",
			BackgroundColor3 = hex("1C3D6A"),
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(CARD_W, CARD_H - 6),
			ZIndex = 4,
		}, parent)
		corner(box, 16)
		local edge = stroke(box, WHITE, 3)
		edge.Transparency = 0.7
		local plus = text(box, "+", 64, WHITE, { TextTransparency = 0.7, ZIndex = 5 });
		(plus:FindFirstChildOfClass("UIStroke") :: UIStroke):Destroy()
		return box
	end

	refreshAll = function(animate: boolean?)
		local list = ctx.Fusable()
		local mine = ctx.Owned()
		local still = false
		for _, mascot in list do
			if picked and mascot.Id == picked.Id then
				still = true
			end
		end
		if not still then
			picked = list[1]
		end
		for _, child in picker:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for order, mascot in list do
			coin(mascot, mine[mascot.Id] or 0, picked ~= nil and mascot.Id == picked.Id, order)
		end
		pickLabel.Visible = #list > 0
		-- slots
		local need = if picked then Mascots.MergeCost(picked) or NEED else NEED
		local have = if picked then math.min(mine[picked.Id] or 0, need) else 0
		ready = picked ~= nil and have >= need
		table.clear(slotCards)
		for i, slot in slotFrames do
			slot:ClearAllChildren()
			if picked and i <= have then
				local card = PetsV2.Card(slot, picked)
				card.Holder.Active = false
				table.insert(slotCards, card.Holder)
				if animate then
					local scale = SlKit.ScaleOf(card.Holder)
					scale.Scale = 0.01
					task.delay((i - 1) * 0.08, function()
						Sfx.Play("ReelTick", 1 + i * 0.12)
						SlKit.Tween(scale, 0.25, "Over", { Scale = 1 })
					end)
				end
			else
				emptySlot(slot)
			end
		end
		-- the Shiny it makes (dim until ready)
		resultWrap:ClearAllChildren()
		make("UIScale", { Name = "Zoom", Scale = RESULT_ZOOM }, resultWrap)
		if picked then
			local shiny = Mascots.Get(Mascots.ShinyId(picked.Id)) or picked
			local card = PetsV2.Card(resultWrap, shiny)
			card.Holder.Active = false
			if not ready then
				local dim = make("Frame", {
					Name = "Dim",
					BackgroundColor3 = INK,
					BackgroundTransparency = 0.4,
					BorderSizePixel = 0,
					Size = UDim2.new(1, 0, 1, -6),
					ZIndex = 30,
				}, card.Holder)
				corner(dim, 16)
			end
		else
			emptySlot(resultWrap)
		end
		arrow.ImageTransparency = if ready then 0 else 0.65
		countLabel.Text = ("%d/%d"):format(have, need)
		countLabel.TextColor3 = if ready then C.Value else WHITE
		chip.Size = UDim2.fromOffset(28 + 6 + textWidth(countLabel.Text, 24) + 32, 44)
		if ready then
			fuse:Repaint(PAINT.Green)
			fuse:SetText("FUSE")
			fuse:SetState("ready")
		else
			fuse:Repaint(PAINT.Red)
			fuse:SetText(if picked then ("NEED %d MORE"):format(need - have) else "NO PETS YET")
			fuse:SetState("normal")
		end
	end

	local isOpen = false
	local busy = false
	local function closeWindow()
		if not isOpen then
			return
		end
		isOpen = false
		fuse:SetState("normal") -- (stops the bounce)
		SlKit.Tween(openScale, 0.14, "Snap", { Scale = 0.85 })
		task.delay(0.14, function()
			if not isOpen then
				gui.Enabled = false
				if ctx.OnClose then
					ctx.OnClose()
				end
			end
		end)
	end
	close.Holder.Activated:Connect(closeWindow)
	backdrop.Activated:Connect(closeWindow)

	-- FUSE: the copies slide into the Shiny (0.35 s), then the merge plays
	fuse.Holder.Activated:Connect(function()
		if busy then
			return
		end
		if not ready or not picked then
			SlKit.Shake(fuse.Holder, 8, 0, 0.3)
			Sfx.Play("Error")
			return
		end
		busy = true
		local mascot = picked
		local target = resultWrap.Position
		for _, card in slotCards do
			local slot = card.Parent :: Frame
			local offset = UDim2.fromOffset(
				target.X.Offset - (slot.Position.X.Offset + CARD_W / 2),
				target.Y.Offset - (slot.Position.Y.Offset + CARD_H / 2)
			)
			SlKit.Tween(card, 0.35, "Snap", { Position = offset })
			SlKit.Tween(SlKit.ScaleOf(card), 0.35, "Snap", { Scale = 0.3 })
		end
		task.delay(0.38, function()
			busy = false
			isOpen = false
			gui.Enabled = false
			if ctx.OnClose then
				ctx.OnClose()
			end
			ctx.Fuse(mascot)
		end)
	end)

	player:GetAttributeChangedSignal("Mascots"):Connect(function()
		if isOpen and not busy then
			refreshAll(false)
		end
	end)

	local function open()
		if isOpen then
			return
		end
		isOpen = true
		gui.Enabled = true
		refit()
		refreshAll(true)
		openScale.Scale = 0.85
		SlKit.Tween(openScale, 0.28, "Over", { Scale = 1 })
		Sfx.Play("Click", 1.1)
		if ctx.OnOpen then
			ctx.OnOpen()
		end
	end
	-- Studio tests: FuseV2UI attribute TestOpen true / false
	if RunService:IsStudio() then
		gui:GetAttributeChangedSignal("TestOpen"):Connect(function()
			if gui:GetAttribute("TestOpen") then
				open()
			else
				closeWindow()
			end
		end)
	end

	return {
		Open = open,
		Close = closeWindow,
		IsOpen = function()
			return isOpen
		end,
		Gui = gui,
	}
end

return EggV2
