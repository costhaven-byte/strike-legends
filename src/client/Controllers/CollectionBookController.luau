-- The Ball Book: every ball in the game, one tab per rarity. Owned balls spin in 3D with EQUIP and POLISH; missing
-- balls show as black silhouettes with their traits and the crate they come from, so you know what to chase.
-- Look = the owner's UI Kit (claude.ai/design 'Strike Legends UI Kit', 2026-10-26; Modules/UiKit): on a computer a
-- two-page spread of 4 cards with page arrows on its sides; on a phone 3 cards, a rarity info column on the left (it
-- sits over the thumbstick, so it has no buttons) and the arrows stacked on the right.
-- Opened with the BALLS button. Built in code (not in Studio), so it lives in git. Ownership comes from the OwnedBalls
-- Player attribute the server sets. Also puts the equipped ball, spinning in 3D, on the BALLS button.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local UiFx = require(Modules:WaitForChild("UiFx"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local BallView = require(Modules:WaitForChild("BallView"))
local Sfx = require(Modules:WaitForChild("Sfx"))
local HudKit = require(Modules:WaitForChild("HudKit"))

local player = Players.LocalPlayer

local C = UiKit.C
local Head, Num, Body = UiKit.Head, UiKit.Num, UiKit.Body
local INK = C.Ink
local SPIN_SPEED = math.pi * 2 / 6 -- owned balls turn once every 6 seconds (kit animation notes)
local BUTTON_SPIN = 0.6 -- the equipped ball on the BALLS button
local MAX_POLISH = Config.Economy.Polish.MaxLevel

-- Computer and phone window sizes (design pixels) and cards per page
local PC = { W = 900, H = 600, PerSpread = 4 }
local PHONE = { W = 820, H = 340, PerSpread = 3 }

local CollectionBookController = {}

-- Equip guide: after the first crate bought with coins, arrows show how to equip its new ball
-- (BALLS button first, then that ball's EQUIP button in the book). Ends on any equip or when the book closes.
local guideBall: string? = nil

function CollectionBookController.GuideEquip(ballId: string)
	if Balls.Get(ballId) and player:GetAttribute("EquippedBall") ~= ballId then
		guideBall = ballId
	end
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

-- A label at design x, y, w, h
local function label(
	parent: Instance,
	value: string,
	font: Font,
	size: number,
	color: Color3,
	strokePx: number,
	x: number,
	y: number,
	w: number,
	h: number,
	align: Enum.TextXAlignment?
): TextLabel
	local l = UiKit.Text(parent, value, font, size, color, strokePx)
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	return l
end

-- A frame that lays its children out left to right (centred unless told otherwise)
local function row(parent: Instance, gap: number, align: Enum.HorizontalAlignment?): Frame
	local frame =
		UiKit.Make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	UiKit.Make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	return frame
end

-- Text that sizes its own width (for rows)
local function fitText(
	parent: Instance,
	value: string,
	font: Font,
	size: number,
	color: Color3,
	strokePx: number,
	order: number,
	height: number
): TextLabel
	local l = UiKit.Text(parent, value, font, size, color, strokePx)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, height)
	l.LayoutOrder = order
	return l
end

-- Where a ball you're missing comes from: the cheapest crate that can give it
local function findIn(ball): string
	for _, crate in Config.Crates do
		if Zones.BallInCrate(ball, crate) and (crate.Odds[ball.Rarity] or 0) > 0 then
			return crate.Name:upper()
		end
	end
	return "SPECIAL"
end

function CollectionBookController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BallsUI") :: ScreenGui
	local inventory = gui:WaitForChild("Inventory") :: Frame
	local rarities = Config.Rarities
	local ballsButton = gui:WaitForChild("Menu"):WaitForChild("BallsButton") :: TextButton
	local equipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipBall") :: RemoteEvent
	local polishRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyPolish") :: RemoteFunction

	-- Book = the whole screen (backdrop + window), so hiding it hides both (CrateController hides it directly)
	local book = UiKit.Make("Frame", {
		Name = "Book",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Active = true, -- taps on the book don't fall through to the throw meter
		ZIndex = 20,
	}, gui) :: Frame
	local backdrop = UiKit.Backdrop(book)
	local fit = UiKit.Make("Frame", {
		Name = "Fit",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 2,
	}, book) :: Frame
	local fitScale = UiKit.Make("UIScale", {}, fit) :: UIScale
	local panel = UiKit.Make("Frame", {
		Name = "Panel",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = true,
	}, fit) :: Frame
	local panelScale = UiKit.ScaleOf(panel)

	-- The BALLS button in the owner's HUD Kit look (cyan), with the equipped ball spinning in 3D in its icon slot
	-- (the kit's "3D SLOT"; it replaces the old colour dot)
	local swatch = ballsButton:WaitForChild("Swatch") :: Frame
	local menu = ballsButton.Parent :: Frame
	local ballsKit =
		HudKit.Adopt(ballsButton, { Paint = "Cyan", Icon = "Ball", Caption = "BALLS", Key = "Balls", Place = false })
	ballsKit.Icon.Visible = false
	swatch.Parent = ballsKit.Slot
	swatch.AnchorPoint = Vector2.zero
	swatch.Position = UDim2.fromOffset(0, 0)
	swatch.Size = UDim2.fromScale(1, 1)
	swatch.ZIndex = 5
	for _, child in swatch:GetChildren() do
		if child:IsA("UIStroke") then
			child.Enabled = false
		end
	end
	HudKit.OnLayout(function(phone)
		local position, size = HudKit.Spot("Balls", phone)
		menu.AnchorPoint = Vector2.zero
		menu.Position = position
		menu.Size = size :: UDim2
	end)
	swatch.BackgroundTransparency = 1
	local buttonView = Instance.new("ViewportFrame")
	buttonView.Name = "Ball3D"
	buttonView.AnchorPoint = Vector2.new(0.5, 0.5)
	buttonView.Position = UDim2.fromScale(0.5, 0.5)
	buttonView.Size = UDim2.fromScale(1.25, 1.25) -- a little bigger than the ring, so the ball reads at this size
	buttonView.BackgroundTransparency = 1
	buttonView.Ambient = Color3.fromRGB(190, 190, 210)
	buttonView.LightColor = Color3.new(1, 1, 1)
	buttonView.LightDirection = Vector3.new(-1, -1.5, -1)
	buttonView.Active = false
	local buttonCamera = Instance.new("Camera")
	buttonCamera.FieldOfView = 30
	buttonCamera.Parent = buttonView
	buttonView.CurrentCamera = buttonCamera
	buttonView.Parent = swatch
	local buttonModel: Instance? = nil
	local buttonBall: string? = nil

	local function updateButton(force: boolean?)
		local current = Balls.Get(player:GetAttribute("EquippedBall")) or Config.Balls[1]
		if current.Id == buttonBall and not force then
			return
		end
		buttonBall = current.Id
		if buttonModel then
			buttonModel:Destroy()
		end
		local model = BallView.Model(current)
		BallView.FrameCamera(buttonCamera, model, 1.05)
		model.Parent = buttonView
		buttonModel = model
	end
	updateButton()

	local page = 1 -- rarity tab
	local spread = 1 -- page inside the tab (computer: a two-page spread)
	local shownPage: number? = nil -- the tab drawn last time (to animate a newly selected tab)
	local spinning: { Instance } = {}
	local equipButtons: { [string]: GuiObject } = {}
	local polishFrom: { [string]: number } = {} -- ball id -> Polish level its bar slides up from on the next draw
	local slideFrom = 0 -- cards slide in from this many px on the next draw (tab switch / page arrow)
	local justEquipped: string? = nil

	-- New-ball dots: balls found since you last opened their tab (this session)
	local seen = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
	local dotShown: { [string]: boolean } = {}

	-- Balls Phase X took out of the game (Retired) only show to players who own one
	local function ballsOf(rarityName: string)
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local list = {}
		for _, ball in Config.Balls do
			if ball.Rarity == rarityName and (not ball.Retired or owned[ball.Id]) then
				table.insert(list, ball)
			end
		end
		table.sort(list, function(a, b)
			return a.Multiplier < b.Multiplier
		end)
		return list
	end

	local function polishLevelOf(ballId: string): number
		return Balls.PolishLevel(Balls.DecodePolish(player:GetAttribute("Polish"))[ballId])
	end

	local render: () -> ()

	-- A trait chip (CURVE 25%): the trait's own colour, or grey on a missing ball
	local function chip(parent: Instance, entry, owned: boolean, phone: boolean, order: number)
		local h = if phone then 20 else 24
		local box = UiKit.Box(parent, "Chip", C.Chip, h / 2, 2)
		box.AutomaticSize = Enum.AutomaticSize.X
		box.Size = UDim2.fromOffset(0, h - 4)
		box.LayoutOrder = order
		UiKit.Make("UIPadding", {
			PaddingLeft = UDim.new(0, if phone then 4 else 6),
			PaddingRight = UDim.new(0, if phone then 4 else 6),
		}, box)
		local t = UiKit.Text(
			box,
			Balls.FormatTrait(entry.Trait, entry.Value, true):upper(),
			Body,
			if phone then 9 else 11,
			if owned then entry.Trait.Color else C.MissingTrait,
			0
		)
		t.AutomaticSize = Enum.AutomaticSize.X
		t.Size = UDim2.fromScale(0, 1)
	end

	-- The 3D ball: spinning if owned; a black silhouette that bobs 3 px up and down if missing
	local function ballSlot(parent: Instance, ball, owned: boolean, x: number, y: number, w: number, h: number)
		local view = Instance.new("ViewportFrame")
		view.Name = "Ball"
		view.AnchorPoint = Vector2.new(0.5, 0.5)
		view.Position = UDim2.fromOffset(x + w / 2, y + h / 2)
		view.Size = UDim2.fromOffset(h, h)
		view.BackgroundTransparency = 1
		view.Ambient = Color3.fromRGB(190, 190, 210)
		view.LightColor = Color3.new(1, 1, 1)
		view.LightDirection = Vector3.new(-1, -1.5, -1)
		view.ImageColor3 = if owned then Color3.new(1, 1, 1) else INK
		view.ZIndex = 2
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.Parent = view
		view.CurrentCamera = camera
		local model = BallView.Model(ball)
		BallView.FrameCamera(camera, model, if owned then 1.05 else 1.25)
		model.Parent = view
		view.Parent = parent
		if owned then
			table.insert(spinning, model)
		else
			view.Position -= UDim2.fromOffset(0, 3)
			TweenService:Create(view, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Position = view.Position + UDim2.fromOffset(0, 6),
			}):Play()
		end
	end

	-- POLISH n/10 bar; the fill slides up from the old level right after you polish this ball
	local function polishBar(
		parent: Instance,
		ballId: string,
		level: number,
		x: number,
		y: number,
		w: number,
		h: number
	)
		local track = UiKit.Make("Frame", {
			Name = "PolishBar",
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
		}, parent)
		UiKit.Corner(track, h / 2)
		local fill = UiKit.Make("Frame", {
			Name = "Fill",
			BackgroundColor3 = if level >= MAX_POLISH then C.Gold else C.Cyan,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(2, 2),
		}, track)
		UiKit.Corner(fill, h / 2 - 2)
		local function width(lv: number): UDim2
			local share = lv / MAX_POLISH
			return UDim2.new(share, -4 * share, 1, -4)
		end
		local from = polishFrom[ballId]
		if from and from < level then
			fill.Size = width(from)
			UiKit.Tween(fill, 0.25, Enum.EasingStyle.Quad, { Size = width(level) })
			-- A sparkle at the end of the bar: grows to 1.3 and away, turning 90 degrees as it fades (0.4 s)
			local sparkle = UiKit.Icon(track, "Polish", h * 2.4)
			sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
			sparkle.Position = UDim2.new(level / MAX_POLISH, 0, 0.5, 0)
			sparkle.ZIndex = 3
			local scale = UiKit.ScaleOf(sparkle)
			scale.Scale = 0
			UiKit.Tween(scale, 0.2, Enum.EasingStyle.Quad, { Scale = 1.3 }).Completed:Once(function()
				UiKit.Tween(scale, 0.2, Enum.EasingStyle.Quad, { Scale = 0 }, Enum.EasingDirection.In)
			end)
			UiKit.Tween(sparkle, 0.4, Enum.EasingStyle.Linear, { Rotation = 90, ImageTransparency = 1 })
		else
			fill.Size = width(level)
		end
	end

	-- EQUIP (cyan) or EQUIPPED (lime + tick; phone = tick only)
	local function equipButton(
		parent: Instance,
		ball,
		equipped: boolean,
		phone: boolean,
		x: number,
		y: number,
		w: number,
		h: number
	)
		local block = UiKit.Block(parent, {
			Name = if equipped then "Equipped" else "Equip",
			Size = Vector2.new(w, h),
			Fill = if equipped then C.Lime else C.Cyan,
			Lip = if equipped then C.LimeLip else C.CyanLip,
			LipPx = if phone then 5 else 6,
			Radius = if phone then 12 else 14,
			Button = not equipped,
		})
		block.Holder.Position = UDim2.fromOffset(x, y)
		local line = row(block.Face, 6)
		if equipped then
			local tick = UiKit.Icon(line, "Tick", if phone then 28 else 24)
			tick.LayoutOrder = 1
			if not phone then
				fitText(line, "EQUIPPED", Head, 19, C.White, 2.5, 2, h)
			end
			if justEquipped == ball.Id then
				-- The button bounces and the tick spins in (0.2 Back Out)
				local tickScale = UiKit.ScaleOf(tick)
				tickScale.Scale = 0
				tick.Rotation = -30
				UiKit.Tween(tickScale, 0.2, Enum.EasingStyle.Back, { Scale = 1 })
				UiKit.Tween(tick, 0.2, Enum.EasingStyle.Back, { Rotation = 0 })
				UiFx.Pop(block.Holder, 1.15, 0.2)
			end
		else
			fitText(line, "EQUIP", Head, if phone then 16 else 20, C.White, if phone then 2 else 2.5, 1, h);
			(block.Holder :: TextButton).Activated:Connect(function()
				equipRemote:FireServer(ball.Id)
			end)
		end
		equipButtons[ball.Id] = block.Holder
	end

	-- POLISH + gem price: pink when you can pay (breathes gently, no flashing), grey with a red price when you
	-- can't, gold MAX POLISH when done. Phone: gem + number only, MAX when done.
	local function polishButton(
		parent: Instance,
		ball,
		level: number,
		phone: boolean,
		x: number,
		y: number,
		w: number,
		h: number
	)
		local price = Balls.PolishGemPrice(ball, level)
		if not price then
			local box = UiKit.Box(parent, "PolishMax", C.Card, 12)
			UiKit.Place(box, x, y, w, h)
			local ring = UiKit.Make("Frame", {
				Name = "Ring",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(2, 2),
				Size = UDim2.new(1, -4, 1, -4),
			}, box)
			UiKit.Corner(ring, 7)
			UiKit.Outline(ring, C.Gold, 2)
			local line = row(box, 6)
			if phone then
				fitText(line, "MAX", Head, 14, C.Gold, 2, 1, h)
			else
				UiKit.Icon(line, "Polish", 22).LayoutOrder = 1
				fitText(line, "MAX POLISH", Head, 16, C.Gold, 2, 2, h)
			end
			return
		end
		local canPay = (player:GetAttribute("Gems") or 0) >= price
		local block = UiKit.Block(parent, {
			Name = "Polish",
			Size = Vector2.new(w, h),
			Fill = if canPay then C.Pink else C.Grey,
			Lip = if canPay then C.PinkLip else C.GreyLip,
			LipPx = 5,
			Radius = 12,
			Button = canPay,
		})
		block.Holder.Position = UDim2.fromOffset(x, y)
		local line = row(block.Face, if phone then 2 else 6)
		if not phone then
			fitText(line, "POLISH", Head, 16, if canPay then C.White else C.LockedText, 2, 1, h)
		end
		local gem = UiKit.Icon(line, "Gem", if phone then 20 else 22)
		gem.LayoutOrder = 2
		gem.ImageTransparency = if canPay then 0 else 0.4
		fitText(line, tostring(price), Num, if phone then 16 else 18, if canPay then C.White else C.Price, 2, 3, h)
		if canPay then
			TweenService:Create(
				UiKit.ScaleOf(block.Face),
				TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.04 }
			):Play()
			local asking = false
			(block.Holder :: TextButton).Activated:Connect(function()
				if asking then
					return
				end
				asking = true
				local ok, result = pcall(polishRemote.InvokeServer, polishRemote, ball.Id)
				asking = false
				if ok and result and result.Ok then
					Sfx.Play("PowerUp") -- the Polish attribute changes and the book redraws with the bar sliding up
				else
					Sfx.Play("Error")
					UiFx.Pop(block.Holder, 0.85, 0.25)
				end
			end)
		else
			-- Not a button, but a tap says no
			local tap = UiKit.Make("TextButton", {
				Name = "Tap",
				Text = "",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 5,
			}, block.Holder)
			tap.Activated:Connect(function()
				Sfx.Play("Error")
				UiFx.Pop(block.Holder, 0.9, 0.25)
			end)
		end
	end

	-- One ball card at design x, y, w, h
	local function card(
		parent: Instance,
		ball,
		owned: boolean,
		equipped: boolean,
		phone: boolean,
		x: number,
		y: number,
		w: number,
		h: number
	)
		local rarityColor = (UiKit.Rarity[ball.Rarity] or UiKit.Rarity.Common)[1]
		local block = UiKit.Block(parent, {
			Name = ball.Id,
			Size = Vector2.new(w, h),
			Fill = if owned then C.Card else C.Missing,
			Lip = C.Page,
			LipPx = if phone then 5 else 6,
			Radius = if phone then 14 else 18,
		})
		local holder = block.Holder
		holder.Position = UDim2.fromOffset(x, y)
		if equipped and owned then
			(block.Body:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = C.Lime
		end
		local pad = if phone then 7 else 10
		local inner = w - pad * 2
		local level = if owned then polishLevelOf(ball.Id) else 0

		-- Top: rarity strip (phone: a small tag in the slot's corner), the ball, then its name and traits
		local slotY = if phone then pad else pad + 17
		local slotH = if phone then 56 else 110
		if not phone then
			UiKit.Place(UiKit.Box(holder, "Strip", rarityColor, 5, 2), pad, pad, inner, 10, 2)
		end
		if not owned then
			UiKit.Place(
				UiKit.Box(holder, "Slot", C.Slot, if phone then 10 else 12, 2, C.Dash),
				pad,
				slotY,
				inner,
				slotH,
				2
			)
		end
		ballSlot(holder, ball, owned, pad, slotY, inner, slotH)
		if phone then
			local tag = UiKit.Box(holder, "Tag", rarityColor, 3, 2)
			UiKit.Place(tag, pad + 6, slotY + 6, 20, 6, 2)
			tag.ZIndex = 3
		end

		-- Name and traits stack (a long name can take two lines on a computer and pushes the traits down)
		local info = UiKit.Make("Frame", {
			Name = "Info",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(pad, slotY + slotH + (if phone then 5 else 7)),
			Size = UDim2.fromOffset(inner, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, holder)
		UiKit.Make(
			"UIListLayout",
			{ Padding = UDim.new(0, if phone then 5 else 7), SortOrder = Enum.SortOrder.LayoutOrder },
			info
		)
		local name = UiKit.Text(
			info,
			ball.Name:upper(),
			Head,
			if phone then 15 else 20,
			if owned then rarityColor else C.Faded,
			2
		)
		name.Name = "BallName"
		name.LayoutOrder = 1
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Size = UDim2.new(1, 0, 0, if phone then 17 else 22)
		if phone then
			name.TextTruncate = Enum.TextTruncate.AtEnd
		else
			name.TextWrapped = true
			name.AutomaticSize = Enum.AutomaticSize.Y
		end
		local chips = UiKit.Make("Frame", {
			Name = "Traits",
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, if phone then 20 else 24),
			AutomaticSize = if phone then Enum.AutomaticSize.None else Enum.AutomaticSize.Y,
			ClipsDescendants = phone,
		}, info)
		UiKit.Make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = not phone,
			Padding = UDim.new(0, if phone then 3 else 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, chips)
		for order, entry in Balls.GetTraits(ball) do
			chip(chips, entry, owned, phone, order)
		end

		-- Bottom: what you can do with it, or where to find it
		local bottom = h - (if phone then 9 else 14)
		if owned then
			if phone then
				local buttonsY = bottom - 44
				local polishW = 64
				equipButton(holder, ball, equipped, true, pad, buttonsY, inner - polishW - 5, 44)
				polishButton(holder, ball, level, true, pad + inner - polishW, buttonsY, polishW, 44)
				local rowY = buttonsY - 6 - 14
				label(holder, "POLISH", Body, 9, C.Label, 0, pad, rowY, 40, 14, Enum.TextXAlignment.Left)
				polishBar(holder, ball.Id, level, pad + 42, rowY + 2, inner - 42 - 40, 10)
				label(
					holder,
					("%d/%d"):format(level, MAX_POLISH),
					Num,
					13,
					C.White,
					1.5,
					pad + inner - 36,
					rowY,
					36,
					14,
					Enum.TextXAlignment.Right
				)
			else
				local polishY = bottom - 38
				local equipY = polishY - 7 - 44
				local barY = equipY - 7 - 12
				local rowY = barY - 7 - 20
				label(holder, "POLISH", Body, 11, C.Label, 0, pad, rowY, 80, 20, Enum.TextXAlignment.Left)
				label(
					holder,
					("%d/%d"):format(level, MAX_POLISH),
					Num,
					16,
					C.White,
					2,
					pad + inner - 60,
					rowY,
					60,
					20,
					Enum.TextXAlignment.Right
				)
				polishBar(holder, ball.Id, level, pad, barY, inner, 12)
				equipButton(holder, ball, equipped, false, pad, equipY, inner, 44)
				polishButton(holder, ball, level, false, pad, polishY, inner, 38)
			end
		else
			local boxH = if phone then 60 else 96
			local box = UiKit.Box(holder, "FindIn", C.Missing, if phone then 12 else 14, 2, C.Dash)
			box.BackgroundTransparency = 1
			UiKit.Place(box, pad, bottom - boxH, inner, boxH, 2)
			local stack =
				UiKit.Make("Frame", { Name = "Stack", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, box)
			UiKit.Make("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, if phone then 2 else 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, stack)
			if not phone then
				UiKit.Icon(stack, "Lock", 28).LayoutOrder = 1
			end
			local findLabel = UiKit.Text(stack, "FIND IN:", Body, if phone then 9 else 11, C.Muted, 0)
			findLabel.Size = UDim2.new(1, 0, 0, if phone then 11 else 13)
			findLabel.LayoutOrder = 2
			local crate = UiKit.Text(stack, findIn(ball), Head, if phone then 14 else 18, C.LockedText, 2)
			crate.Size = UDim2.new(1, -8, 0, if phone then 16 else 20)
			crate.TextScaled = true -- long crate names shrink to fit
			UiKit.Make("UITextSizeConstraint", { MaxTextSize = if phone then 14 else 18 }, crate)
			crate.LayoutOrder = 3
		end
		return holder
	end

	-- Page arrow: gold, or grey with a faded arrow at the end
	local function arrow(parent: Instance, left: boolean, on: boolean, x: number, y: number, size: number, step: number)
		local big = size > 50
		local block = UiKit.Block(parent, {
			Name = if left then "Prev" else "Next",
			Size = Vector2.new(size, size),
			Fill = if on then C.Gold else C.Grey,
			Lip = if on then C.GoldLip else C.GreyLip,
			LipPx = if big then 6 else 5,
			Radius = if big then 16 else 12,
			Button = on,
		})
		block.Holder.Position = UDim2.fromOffset(x, y)
		block.Holder.ZIndex = 5
		local icon = UiKit.Icon(block.Face, "ArrowRight", if big then 30 else 22)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Rotation = if left then 180 else 0
		icon.ImageTransparency = if on then 0 else 0.55
		if on then
			(block.Holder :: TextButton).Activated:Connect(function()
				spread += step
				slideFrom = if step > 0 then 30 else -30
				render()
			end)
		end
	end

	-- A rarity tab. Computer: a folder tab on top of the book (selected = 10 px taller with a white ring, joins the
	-- cover); phone: a rounded button in a row (selected = white ring).
	local function tab(parent: Instance, index: number, rarity, phone: boolean, x: number, w: number, newDot: boolean)
		local colors = UiKit.Rarity[rarity.Name] or UiKit.Rarity.Common
		local selected = index == page
		local block = UiKit.Block(parent, {
			Name = rarity.Name,
			Size = Vector2.new(w, if phone then 44 elseif selected then 52 else 42),
			Fill = colors[1],
			Lip = colors[2],
			LipPx = if selected then 0 elseif phone then 5 else 6,
			Radius = if phone then 12 else 14,
			Ring = if selected then C.White else nil,
			-- Computer tabs run 16 px down behind the cover, so only their top corners show rounded
			Extend = if phone then 0 else 16,
			Button = true,
		})
		if phone then
			block.Holder.Position = UDim2.fromOffset(x, 0)
		else
			block.Holder.Position = UDim2.fromOffset(x, if selected then 0 else 10)
			if selected and shownPage ~= nil and shownPage ~= index then
				-- Newly selected: grows from 42 to 52 tall (0.12 Back Out)
				block.Holder.Size = UDim2.fromOffset(w, 42)
				block.Holder.Position = UDim2.fromOffset(x, 10)
				UiKit.Tween(block.Holder, 0.12, Enum.EasingStyle.Back, {
					Size = UDim2.fromOffset(w, 52),
					Position = UDim2.fromOffset(x, 0),
				})
			end
		end
		local caption = UiKit.Text(
			block.Face,
			rarity.Name:upper(),
			Head,
			if phone then 15 else 18,
			C.White,
			if phone then 2 else 2.5
		)
		caption.Position = UDim2.fromOffset(0, if selected then 3 else 2)
		if newDot then
			local d = if phone then 14 else 18
			local o = if phone then 2 else 3
			local dot = UiKit.Box(block.Holder, "NewDot", C.Red, d / 2, o)
			UiKit.Place(dot, w - d + (if phone then 4 else 6), if phone then -6 else -8, d, d, o)
			dot.ZIndex = 6
			if not dotShown[rarity.Name] then
				dotShown[rarity.Name] = true
				local s = UiKit.ScaleOf(dot)
				s.Scale = 0
				UiKit.Tween(s, 0.25, Enum.EasingStyle.Back, { Scale = 1 })
			end
		end
		(block.Holder :: TextButton).Activated:Connect(function()
			if page ~= index then
				page = index
				spread = 1
				slideFrom = 30
				render()
			end
		end)
	end

	-- Fits the window on this screen: design size, shrunk on small screens (phones fill the screen)
	local function fitScreen()
		local phone = UiKit.Phone(gui)
		local size = if phone then PHONE else PC
		local screen = gui.AbsoluteSize
		fit.Size = UDim2.fromOffset(size.W, size.H)
		local scale = if phone
			then math.min((screen.X - 16) / size.W, (screen.Y - 8) / size.H)
			else math.min(1, (screen.X - 64) / (size.W + 44), (screen.Y - 40) / (size.H + 22))
		fitScale.Scale = math.max(scale, 0.3)
	end

	render = function()
		local phone = UiKit.Phone(gui)
		local size = if phone then PHONE else PC
		fitScreen()
		for _, child in panel:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(spinning)
		table.clear(equipButtons)

		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local equipped = player:GetAttribute("EquippedBall")
		local total, have = 0, 0
		local counts = {}
		local newDots = {}
		for index, rarity in rarities do
			local got = 0
			local list = ballsOf(rarity.Name)
			for _, ball in list do
				if owned[ball.Id] then
					got += 1
					if not seen[ball.Id] then
						newDots[index] = true
					end
				end
			end
			counts[index] = { got, #list }
			total += #list
			have += got
		end
		local rarity = rarities[page]
		local colors = UiKit.Rarity[rarity.Name] or UiKit.Rarity.Common
		local list = ballsOf(rarity.Name)
		-- This tab is open now: its new balls count as seen
		for _, ball in list do
			if owned[ball.Id] then
				seen[ball.Id] = true
			end
		end
		newDots[page] = nil
		dotShown[rarity.Name] = nil
		local spreads = math.max(1, math.ceil(#list / size.PerSpread))
		spread = math.clamp(spread, 1, spreads)
		local shown = {}
		for i = (spread - 1) * size.PerSpread + 1, math.min(#list, spread * size.PerSpread) do
			table.insert(shown, list[i])
		end
		local cardHolders = {}
		local got, count = counts[page][1], counts[page][2]

		-- Found counter pill: "12 / 31  FOUND" (not tappable)
		local function counter(parent: Instance, small: boolean): Frame
			local h = if small then 34 else 44
			local pill = UiKit.Box(parent, "Found", C.Card, h / 2, 3)
			pill.AutomaticSize = Enum.AutomaticSize.X
			pill.Size = UDim2.fromOffset(0, h - 6)
			UiKit.Make("UIPadding", {
				PaddingLeft = UDim.new(0, if small then 9 else 15),
				PaddingRight = UDim.new(0, if small then 9 else 15),
			}, pill)
			local line = row(pill, if small then 6 else 10)
			line.AutomaticSize = Enum.AutomaticSize.X
			line.Size = UDim2.fromScale(0, 1)
			fitText(
				line,
				("%d / %d"):format(have, total),
				Num,
				if small then 17 else 24,
				C.White,
				if small then 2 else 2.5,
				1,
				h - 6
			)
			fitText(line, "FOUND", Head, if small then 14 else 20, C.Lime, if small then 2 else 2.5, 2, h - 6)
			return pill
		end

		local close: ImageButton
		if phone then
			-- Cover 820 x 340: header 48, tab row 44, then info column | 3 cards | arrows
			local root = UiKit.Block(panel, {
				Name = "Cover",
				Size = Vector2.new(size.W, size.H),
				Fill = C.Cover,
				Lip = INK,
				LipPx = 6,
				Radius = 22,
				Outline = 4,
			}).Holder
			local header = UiKit.Make("Frame", {
				Name = "Header",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.fromOffset(size.W - 84, 48),
			}, root)
			local line = row(header, 12, Enum.HorizontalAlignment.Left)
			fitText(line, "BALL BOOK", Head, 28, C.Gold, 3, 1, 48)
			counter(line, true).LayoutOrder = 2
			close = UiKit.CloseX(root, 48)
			close.Position = UDim2.fromOffset(size.W - 12 - 24, 6 + 24)

			local tabsRow = UiKit.Make("Frame", {
				Name = "Tabs",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 60),
				Size = UDim2.fromOffset(size.W - 24, 44),
			}, root)
			local tabW = (size.W - 24 - 6 * (#rarities - 1)) / #rarities
			for index, r in rarities do
				tab(tabsRow, index, r, true, (index - 1) * (tabW + 6), tabW, newDots[index] == true)
			end

			-- Info column (no buttons: it sits over the thumbstick): rarity, found count + bar, page number
			local bodyY, bodyH = 110, size.H - 110 - 12
			local info = UiKit.Box(root, "Info", C.Page, 14)
			UiKit.Place(info, 12, bodyY, 170, bodyH)
			label(info, rarity.Name:upper(), Head, 26, colors[1], 3, 9, 7, 146, 30, Enum.TextXAlignment.Left)
			local foundLine = UiKit.Make("Frame", {
				Name = "FoundLine",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(9, 40),
				Size = UDim2.fromOffset(146, 26),
			}, info)
			local fl = row(foundLine, 6, Enum.HorizontalAlignment.Left)
			fitText(fl, ("%d / %d"):format(got, count), Num, 22, C.White, 2, 1, 26)
			fitText(fl, "FOUND", Body, 11, C.Label, 0, 2, 26)
			local track = UiKit.Make("Frame", {
				Name = "Progress",
				BackgroundColor3 = INK,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(9, 72),
				Size = UDim2.fromOffset(146, 12),
			}, info)
			UiKit.Corner(track, 6)
			local share = if count > 0 then got / count else 0
			local fill = UiKit.Make("Frame", {
				BackgroundColor3 = colors[1],
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(2, 2),
				Size = UDim2.new(share, -4 * share, 1, -4),
			}, track)
			UiKit.Corner(fill, 4)
			label(
				info,
				("PAGE %d / %d"):format(spread, spreads),
				Body,
				11,
				C.Muted,
				0,
				9,
				bodyH - 6 - 30,
				146,
				20,
				Enum.TextXAlignment.Left
			)

			local arrowsX = size.W - 12 - 44
			local cardsX = 12 + 170 + 10
			local cardW = math.floor((arrowsX - 10 - cardsX - 8 * 2) / 3)
			for i, ball in shown do
				cardHolders[i] = card(
					root,
					ball,
					owned[ball.Id] == true,
					ball.Id == equipped,
					true,
					cardsX + (i - 1) * (cardW + 8),
					bodyY,
					cardW,
					bodyH
				)
			end
			local arrowsY = bodyY + (bodyH - 44 * 2 - 10) / 2
			arrow(root, true, spread > 1, arrowsX, arrowsY, 44, -1)
			arrow(root, false, spread < spreads, arrowsX, arrowsY + 54, 44, 1)
		else
			-- Tab strip 52 tall over a 900 x 548 cover; two pages of two cards; arrows on the cover's sides
			local tabsRow = UiKit.Make("Frame", {
				Name = "Tabs",
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(size.W, 52),
				ZIndex = 1,
			}, panel)
			for index, r in rarities do
				tab(tabsRow, index, r, false, 44 + (index - 1) * 136, 130, newDots[index] == true)
			end
			local root = UiKit.Block(panel, {
				Name = "Cover",
				Size = Vector2.new(size.W, 548),
				Fill = C.Cover,
				Lip = INK,
				LipPx = 8,
				Radius = 28,
				Outline = 4,
			}).Holder
			root.Position = UDim2.fromOffset(0, 52)
			root.ZIndex = 2
			label(root, "BALL BOOK", Head, 42, C.Gold, 4, 22, 22, 400, 48, Enum.TextXAlignment.Left)
			local pill = counter(root, false)
			pill.AnchorPoint = Vector2.new(1, 0)
			pill.Position = UDim2.fromOffset(size.W - 22 - 30 - 3, 16 + 2 + 3)
			close = UiKit.CloseX(root, 60)
			close.Position = UDim2.fromOffset(size.W + 22 - 30, -22 + 30)
			close.ZIndex = 6

			local pageTitles = {
				{ rarity.Name:upper() .. " BALLS", ("%d / %d"):format(got, count) },
				{ "PAGE", ("%d / %d"):format(spread, spreads) },
			}
			for side = 1, 2 do
				local sheet = UiKit.Box(root, "Page" .. side, C.Page, 18)
				UiKit.Place(sheet, 22 + (side - 1) * (420 + 16), 76, 420, 448)
				label(sheet, pageTitles[side][1], Head, 20, colors[1], 2.5, 11, 11, 250, 22, Enum.TextXAlignment.Left)
				label(
					sheet,
					pageTitles[side][2],
					Num,
					18,
					C.White,
					2,
					414 - 11 - 120,
					9,
					120,
					22,
					Enum.TextXAlignment.Right
				)
				for slot = 1, 2 do
					local i = (side - 1) * 2 + slot
					local ball = shown[i]
					if ball then
						cardHolders[i] = card(
							sheet,
							ball,
							owned[ball.Id] == true,
							ball.Id == equipped,
							false,
							11 + (slot - 1) * 202,
							41,
							190,
							390
						)
					end
				end
			end
			arrow(root, true, spread > 1, -30, 270, 56, -1)
			arrow(root, false, spread < spreads, size.W - 26, 270, 56, 1)
		end
		close.Activated:Connect(function()
			CollectionBookController.SetOpen(false)
		end)

		-- Cards slide in after a tab switch or a page turn (30 px, 0.15 Quad Out, 0.03 s apart)
		if slideFrom ~= 0 then
			for i, holder in cardHolders do
				local rest = holder.Position
				holder.Position = rest + UDim2.fromOffset(slideFrom, 0)
				task.delay((i - 1) * 0.03, function()
					UiKit.Tween(holder, 0.15, Enum.EasingStyle.Quad, { Position = rest })
				end)
			end
		end
		slideFrom = 0
		table.clear(polishFrom)
		justEquipped = nil
		shownPage = page
	end

	-- Opens on the page of the ball you're throwing (or the ball the equip guide points at)
	local function startAt()
		local current = Balls.Get(guideBall or player:GetAttribute("EquippedBall")) or Config.Balls[1]
		local perSpread = if UiKit.Phone(gui) then PHONE.PerSpread else PC.PerSpread
		page, spread = 1, 1
		for index, r in rarities do
			if r.Name == current.Rarity then
				page = index
				for i, ball in ballsOf(r.Name) do
					if ball.Id == current.Id then
						spread = math.ceil(i / perSpread)
					end
				end
			end
		end
	end

	function CollectionBookController.SetOpen(open: boolean)
		if open then
			startAt()
			shownPage = nil
			render()
			gui.Shop.Visible = false
			UiFx.Close(inventory)
			UiKit.Open(book, backdrop, panel, panelScale)
		else
			if guideBall and book.Visible then
				guideBall = nil -- the guide was shown in the book; don't keep nagging
			end
			UiKit.Close(book, backdrop, panelScale)
		end
	end
	local setOpen = CollectionBookController.SetOpen

	ballsButton.Activated:Connect(function()
		setOpen(not book.Visible)
	end)
	backdrop.Activated:Connect(function()
		setOpen(false)
	end)
	UiKit.CloseKeys(book, function()
		setOpen(false)
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if book.Visible then
			render()
		else
			fitScreen()
		end
	end)

	local polishShown = Balls.DecodePolish(player:GetAttribute("Polish"))
	player:GetAttributeChangedSignal("Polish"):Connect(function()
		local now = Balls.DecodePolish(player:GetAttribute("Polish"))
		for id, points in now do
			if points ~= polishShown[id] then
				polishFrom[id] = Balls.PolishLevel(polishShown[id])
			end
		end
		polishShown = now
		if book.Visible then
			render()
		end
	end)
	player:GetAttributeChangedSignal("Gems"):Connect(function()
		if book.Visible then
			render() -- POLISH buttons turn pink or grey
		end
	end)
	player:GetAttributeChangedSignal("OwnedBalls"):Connect(function()
		if book.Visible then
			render()
		end
	end)
	player:GetAttributeChangedSignal("EquippedBall"):Connect(function()
		guideBall = nil
		justEquipped = player:GetAttribute("EquippedBall")
		updateButton()
		if book.Visible then
			render()
		end
	end)

	-- Ball meshes download in the background; a ball drawn before its mesh arrived stayed blank
	-- (the Rookie, 2026-10-19), so once every ball has loaded the book and the button draw again
	task.spawn(function()
		local models = ReplicatedStorage:WaitForChild("BallModels", 30)
		if not models then
			return
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, { models })
		updateButton(true)
		if book.Visible then
			render()
		end
	end)

	-- Equip guide (see GuideEquip): the BALLS button glows gold, then an arrow points at the ball's EQUIP button
	local guideGui = Instance.new("ScreenGui")
	guideGui.Name = "EquipGuide"
	guideGui.ResetOnSpawn = false
	guideGui.DisplayOrder = 30
	guideGui.IgnoreGuiInset = gui.IgnoreGuiInset
	guideGui.Parent = player:WaitForChild("PlayerGui")
	local guideArrow = Instance.new("TextLabel")
	guideArrow.Name = "Arrow"
	guideArrow.BackgroundTransparency = 1
	guideArrow.FontFace = Head
	guideArrow.TextScaled = true
	guideArrow.TextColor3 = Color3.fromRGB(255, 200, 40)
	guideArrow.Text = "<"
	guideArrow.Rotation = -90 -- points down
	guideArrow.AnchorPoint = Vector2.new(0.5, 0.5)
	guideArrow.Size = UDim2.fromOffset(46, 46)
	guideArrow.ZIndex = 50
	guideArrow.Visible = false
	guideArrow.Parent = guideGui
	stroke(guideArrow, INK, 3)
	local arrowWasOn: GuiObject? = nil
	-- The BALLS button's own outline turns gold while it pulses
	local ballsGlow = ballsButton:FindFirstChildOfClass("UIStroke") or stroke(ballsButton, INK, 2)
	local glowColor, glowThickness = ballsGlow.Color, ballsGlow.Thickness
	local ballsScale = ballsButton:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	ballsScale.Parent = ballsButton
	local ballsPulsing = false

	RunService.RenderStepped:Connect(function(dt)
		-- Equip guide: the BALLS button glows and pulses; in the book an arrow points down at the ball's EQUIP
		local target: GuiObject? = nil
		local pulseBalls = false
		if guideBall then
			if book.Visible then
				target = equipButtons[guideBall]
				if target and not target.Parent then
					target = nil
				end
			elseif ballsButton.Visible and gui.Enabled then
				pulseBalls = true
			end
		end
		local wave = math.abs(math.sin(os.clock() * 6))
		if pulseBalls then
			ballsGlow.Color = Color3.fromRGB(255, 200, 40)
			ballsGlow.Thickness = glowThickness + 2 + 2 * wave
			ballsScale.Scale = 1 + 0.12 * wave
		elseif ballsPulsing then
			ballsGlow.Color = glowColor
			ballsGlow.Thickness = glowThickness
			ballsScale.Scale = 1
		end
		ballsPulsing = pulseBalls
		guideArrow.Visible = target ~= nil
		if target then
			local pos, size = target.AbsolutePosition, target.AbsoluteSize
			guideArrow.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y - 26 - wave * 12)
			if arrowWasOn ~= target then
				UiFx.Pop(guideArrow, 1.6, 0.4)
			end
		end
		arrowWasOn = target

		if buttonModel and buttonView.Visible then
			BallView.Turn(buttonModel, CFrame.Angles(0, dt * BUTTON_SPIN, 0))
		end
		if not book.Visible then
			return
		end
		local turn = CFrame.Angles(0, dt * SPIN_SPEED, 0)
		for _, model in spinning do
			BallView.Turn(model, turn)
		end
	end)
end

return CollectionBookController
