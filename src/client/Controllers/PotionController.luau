-- Potions on screen (owner 2026-10-22, Config.Potions): the potion cards with a DRINK button each (the ITEMS tab of
-- the PETS panel, built by MascotController through PotionController.BuildItems) and the running timers, bottom-left:
-- one potion each with its time left under it (owner 2026-10-22: no POTIONS button, no icon chips).
-- Built in code (not in Studio), so it lives in git. The server runs every timer (PotionService); this only shows it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))
local HudKit = require(Modules:WaitForChild("HudKit"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local RewardKit = require(Modules:WaitForChild("RewardKit"))
local TweenService = game:GetService("TweenService")
local SunKit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("SunKit"))
local K = HudKit.C

local player = Players.LocalPlayer

local POTIONS = Config.Potions

local FONT = SunKit.Swap(Font.new("rbxasset://fonts/families/LuckiestGuy.json"))
local INK = Color3.fromHex("06060F")
local GREY = Color3.fromRGB(120, 110, 150)

-- Running timers (owner's HUD Kit): one card per running potion, bottom-left on computers, bottom middle (right of
-- HOLD!) on phones, growing to the right. Name and bar colour per kind.
local KIND_LOOKS = {
	Coins = { Icon = "PotionCoin", Color = K.Gold },
	XP = { Icon = "PotionXp", Color = K.Lime },
}

local PotionController = {}

-- V2 HUD (Config.Ui.HudV2, board B1): each running potion is a round timer: the potion on a navy disc, a ring in
-- its colour that empties clockwise as the time runs out, the time under it.
local V2_KIT = if HudKit.V2 then require(Modules:WaitForChild("SlKit")) else nil
local V2_ICONS = { CoinSmall = "potion_coin", CoinBig = "potion_coin_mega", XpSmall = "potion_xp", XpBig = "potion_xp_mega" }

-- A pie in one half of the disc (side -1 = left, 1 = right) whose visible part turns with its gradient
local function pieHalf(parent: Frame, side: number, color: Color3): UIGradient
	local clip = Instance.new("Frame")
	clip.Name = if side < 0 then "Left" else "Right"
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Position = UDim2.fromScale(if side < 0 then 0 else 0.5, 0)
	clip.Size = UDim2.fromScale(0.5, 1)
	clip.ZIndex = 3
	clip.Parent = parent
	local disc = Instance.new("Frame")
	disc.BackgroundColor3 = color
	disc.BorderSizePixel = 0
	disc.Position = UDim2.fromScale(if side < 0 then 0 else -1, 0)
	disc.Size = UDim2.fromScale(2, 1)
	disc.ZIndex = 3
	disc.Parent = clip
	HudKit.Corner(disc, 999)
	local gradient = Instance.new("UIGradient")
	-- a hard half: the side the rotation points away from shows (no blend: it's a mask, not a colour fade)
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = disc
	return gradient
end

local function buildChipV2(potion, parent: Frame, index: number)
	local kit = V2_KIT :: any
	local color = if potion.Boost == "XP" then kit.C.Value else kit.C.Header
	local chip = Instance.new("Frame")
	chip.Name = potion.Id
	chip.LayoutOrder = index
	chip.BackgroundTransparency = 1
	chip.Visible = false
	chip.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = chip
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromScale(1, 1)
	inner.Parent = chip
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0)
	ring.Position = UDim2.fromScale(0.5, 0)
	ring.BackgroundColor3 = kit.C.TileLip
	ring.ZIndex = 2
	ring.Parent = inner
	HudKit.Corner(ring, 999)
	local outline = HudKit.Outline(ring, kit.C.Ink, 3)
	local ringScale = Instance.new("UIScale")
	ringScale.Parent = ring
	local right = pieHalf(ring, 1, color)
	local left = pieHalf(ring, -1, color)
	local hole = Instance.new("Frame")
	hole.Name = "Hole"
	hole.AnchorPoint = Vector2.new(0.5, 0.5)
	hole.Position = UDim2.fromScale(0.5, 0.5)
	hole.BackgroundColor3 = kit.C.Window
	hole.ZIndex = 4
	hole.Parent = ring
	HudKit.Corner(hole, 999)
	local icon = kit.Image(ring, V2_ICONS[potion.Id] or "potion_coin", 40, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 5,
	})
	local time = HudKit.Text(inner, "", kit.Font, 14, K.White, 2)
	time.Name = "Time"
	time.AnchorPoint = Vector2.new(0.5, 1)
	time.Position = UDim2.fromScale(0.5, 1)
	time.ZIndex = 6;
	(time:FindFirstChildOfClass("UIStroke") :: UIStroke).Color = kit.C.Ink
	local bar = Instance.new("Frame") -- (unused in V2; refresh still sizes it)
	bar.Name = "Bar"
	bar.Visible = false
	bar.Parent = inner
	local pulse = TweenService:Create(
		ringScale,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.06 }
	)
	local parts = {
		Chip = chip,
		Inner = inner,
		Scale = scale,
		-- the old card's handles that refresh uses: the outline (red in the last 10 s) and the breathing scale
		Block = { Outline = outline, Scale = ringScale },
		Icon = icon,
		Time = time,
		Bar = bar,
		Pulse = pulse,
		Ending = false,
		Ring = ring,
		Hole = hole,
	}
	-- share of the time left (1 = full ring), clockwise from the top
	function parts.SetProgress(share: number)
		local p = math.clamp(share, 0, 1)
		right.Rotation = math.min(p, 0.5) * 360
		left.Rotation = 180 + math.clamp(p - 0.5, 0, 0.5) * 360
	end
	parts.SetProgress(1)
	return parts
end

local function decode(value: any): { [string]: number }
	local values = {}
	if type(value) == "string" then
		for id, number in value:gmatch("([^;=]+)=([^;]+)") do
			values[id] = tonumber(number) or 0
		end
	end
	return values
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return ("%d:%02d:%02d"):format(seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(1, 0)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, border: boolean?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = if border then Enum.ApplyStrokeMode.Border else Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

local function text(parent: Instance, name: string, font: Font, color: Color3, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextScaled = true
	label.TextColor3 = color
	label.Position = position
	label.Size = size
	label.Parent = parent
	stroke(label, INK, 1.5)
	return label
end

local function button(
	parent: Instance,
	name: string,
	label: string,
	color: Color3,
	position: UDim2,
	size: UDim2
): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = label
	b.FontFace = FONT
	b.TextScaled = true
	b.TextColor3 = INK
	b.BackgroundColor3 = color
	b.AutoButtonColor = false
	b.Position = position
	b.Size = size
	b.Parent = parent
	corner(b, 10)
	stroke(b, INK, 2, true)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	UiFx.Press(b)
	return b
end

-- A little potion bottle drawn with frames (round body, neck, cork, shine). MEGA potions get a star.
local function flask(parent: Instance, color: Color3, big: boolean, position: UDim2, size: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Flask"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = position
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent

	local neck = Instance.new("Frame")
	neck.Name = "Neck"
	neck.AnchorPoint = Vector2.new(0.5, 0)
	neck.Position = UDim2.fromScale(0.5, 0.12)
	neck.Size = UDim2.fromScale(0.3, 0.32)
	neck.BackgroundColor3 = Color3.fromRGB(220, 230, 255)
	neck.Parent = holder
	corner(neck, 3)
	stroke(neck, INK, 2)

	local cork = Instance.new("Frame")
	cork.Name = "Cork"
	cork.AnchorPoint = Vector2.new(0.5, 0)
	cork.Position = UDim2.fromScale(0.5, 0.02)
	cork.Size = UDim2.fromScale(0.36, 0.16)
	cork.BackgroundColor3 = Color3.fromRGB(160, 100, 55)
	cork.Parent = holder
	corner(cork, 3)
	stroke(cork, INK, 2)

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromScale(0.78, 0.66)
	body.BackgroundColor3 = color
	body.Parent = holder
	corner(body)
	stroke(body, INK, 2.5)

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Position = UDim2.fromScale(0.2, 0.18)
	shine.Size = UDim2.fromScale(0.22, 0.3)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.35
	shine.Parent = body
	corner(shine)

	if big then
		local star = text(
			holder,
			"Star",
			FONT,
			Color3.fromRGB(255, 240, 90),
			UDim2.fromScale(0.55, -0.1),
			UDim2.fromScale(0.5, 0.5)
		)
		star.Text = "★"
		star.ZIndex = 3
	end
	return holder
end

PotionController.Flask = flask -- the playtime gifts panel draws its potions with it too

local function boostText(potion): string
	return ("x%d %s"):format(potion.Multiplier, if potion.Boost == "Coins" then "COINS" else "XP")
end

-- What each potion card needs; filled by BuildItems
local cards = {}
local chips = {}
local showToast: (string) -> () = function(_message: string) end
local useRemote: RemoteFunction

-- The strongest potion of each kind with time left: the one whose timer runs (the server picks the same way)
local function running(boosts: { [string]: number }): { [string]: boolean }
	local best = {}
	for _, potion in POTIONS.List do
		if (boosts[potion.Id] or 0) > 0 then
			local current = best[potion.Boost]
			if not current or potion.Multiplier > current.Multiplier then
				best[potion.Boost] = potion
			end
		end
	end
	local ids = {}
	for _, potion in best do
		ids[potion.Id] = true
	end
	return ids
end

-- Potions waiting to be drunk (the PETS button shows this number)
function PotionController.Count(): number
	local total = 0
	for _, count in decode(player:GetAttribute("Potions")) do
		total += count
	end
	return total
end

-- For the V5 ITEMS tab (Modules/PetsV2): potions to drink and seconds left, by Id; which timers run; "15:00"
function PotionController.Owned(): { [string]: number }
	return decode(player:GetAttribute("Potions"))
end
function PotionController.Boosts(): { [string]: number }
	return decode(player:GetAttribute("Boosts"))
end
PotionController.Running = running
PotionController.Clock = clock

local function refresh()
	local owned = decode(player:GetAttribute("Potions"))
	local boosts = decode(player:GetAttribute("Boosts"))
	local active = running(boosts)
	for _, potion in POTIONS.List do
		local count = owned[potion.Id] or 0
		local left = boosts[potion.Id] or 0
		local card = cards[potion.Id]
		if card then
			-- UI pass batch 5: "x4" pill, a status line (ON / WAITING + time left), DRINK lime when you have one
			card.Count.Text = ("x%d"):format(count)
			card.Count.TextColor3 = if count > 0 then RewardKit.C.Gold else RewardKit.C.Faded
			card.Status.Text = if left > 0
				then ("%s  %s"):format(if active[potion.Id] then "ON" else "WAITING", clock(left))
				elseif count > 0 then "READY TO DRINK"
				else "NONE LEFT"
			card.Status.TextColor3 = if left > 0
				then RewardKit.C.Lime
				elseif count > 0 then RewardKit.C.White
				else RewardKit.C.Faded
			if count > 0 then
				card.Drink:Paint(RewardKit.C.Lime, RewardKit.C.LimeLip, RewardKit.C.White)
			else
				card.Drink:Paint(RewardKit.C.Grey, RewardKit.C.GreyLip, RewardKit.C.LockedText)
			end
			card.Drink:SetPressable(count > 0)
			card.Outline.Thickness = if left > 0 then 5 else 3
		end

		local chip = chips[potion.Id]
		if chip then
			local wasShown = chip.Chip.Visible
			if left > 0 and not wasShown then
				-- Start: slides in from the left (0.3 s Back Out)
				chip.Chip.Visible = true
				chip.Inner.Position = UDim2.fromOffset(-220, 0)
				TweenService:Create(chip.Inner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Position = UDim2.fromOffset(0, 0),
				}):Play()
			elseif left <= 0 and wasShown and not chip.Ending then
				-- End: shrinks away (0.15 s), then the others move along
				chip.Ending = true
				local shrink = TweenService:Create(
					chip.Scale,
					TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Scale = 0 }
				)
				shrink:Play()
				shrink.Completed:Once(function()
					chip.Chip.Visible = false
					chip.Scale.Scale = 1
					chip.Ending = false
				end)
			end
			if left > 0 then
				-- A weaker potion waits (paused, faded) while a stronger one of its kind runs
				local on = active[potion.Id] == true
				local ending = on and left <= 10
				chip.Time.Text = if on then clock(left) else "WAIT"
				chip.Time.TextColor3 = if ending then K.Red elseif on then K.White else GREY
				chip.Block.Outline.Color = if ending then K.Red elseif V2_KIT then V2_KIT.C.Ink else K.Ink
				chip.Icon.ImageTransparency = if on then 0 else 0.5
				chip.Bar.Size = UDim2.new(math.clamp(left / (potion.Minutes * 60), 0, 1), 0, 0, chip.Bar.Size.Y.Offset)
				if chip.SetProgress then
					chip.SetProgress(left / (potion.Minutes * 60))
				end
				-- Last 10 s: the card breathes (1 <-> 1.04, 0.5 s)
				if ending and chip.Pulse.PlaybackState ~= Enum.PlaybackState.Playing then
					chip.Pulse:Play()
				elseif not ending then
					chip.Pulse:Cancel()
					chip.Block.Scale.Scale = 1
				end
			end
		end
	end
end

function PotionController.Use(potion)
	local ok, result = pcall(useRemote.InvokeServer, useRemote, potion.Id)
	if not ok or type(result) ~= "table" or not result.Ok then
		showToast(if ok and type(result) == "table" and result.Error then result.Error else "That didn't work. Try again")
		return
	end
	Sfx.Play("PowerUp")
	UiFx.Flash(potion.Color, 0.35, 0.4)
	if cards[potion.Id] then
		UiFx.Pop(cards[potion.Id].Card, 1.06, 0.3)
	end
	task.defer(function()
		local chip = chips[potion.Id]
		if chip and chip.Chip.Visible then
			UiFx.Pop(chip.Chip, 1.4, 0.4)
		end
	end)
end

-- The ITEMS tab of the PETS panel: a hint, a 2 x 2 grid of potion cards with DRINK, and (Studio only) TEST: POTIONS.
-- UI pass batch 5 (2026-10-29): cards in the owner's kit look (lip block ringed in the potion colour, HUD Kit potion
-- icon, "x4" pill, lime DRINK). page = w x h design px. toast = the panel's own message line.
function PotionController.BuildItems(page: Frame, toast: (string) -> (), w: number, h: number)
	showToast = toast
	local C = RewardKit.C
	local hint = RewardKit.Label(
		page,
		"TIMERS ONLY RUN WHILE YOU PLAY",
		UiKit.Body,
		15,
		C.Label,
		0,
		2,
		0,
		w - 4,
		20
	)
	hint.Name = "Hint"
	hint.TextXAlignment = Enum.TextXAlignment.Left

	local GAP = 12
	local cardW = (w - GAP) / 2
	local cardH = math.min(180, (h - 30 - GAP - 30) / 2)
	for index, potion in POTIONS.List do
		local col, row = (index - 1) % 2, (index - 1) // 2
		local block = UiKit.Block(page, {
			Name = potion.Id,
			Size = Vector2.new(cardW, cardH),
			Fill = C.Card,
			Lip = C.Page,
			LipPx = 6,
			Radius = 18,
			Outline = 3,
			Ring = potion.Color,
		})
		block.Holder.Position = UDim2.fromOffset(col * (cardW + GAP), 30 + row * (cardH + GAP))
		local face = block.Face
		local ring = (face:FindFirstChild("Ring") :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke
		local faceH = cardH - 6 - 6
		local iconSize = math.min(104, faceH - 24)
		-- the icon on a dark round plate, so the potion colours pop
		local plate = UiKit.Box(face, "Plate", C.Cover, iconSize / 2, 3, potion.Color)
		UiKit.Place(plate, 16, (faceH - iconSize) / 2, iconSize, iconSize, 3)
		RewardKit.Icon(plate, "Potion", potion.Id, iconSize * 0.8)
		local x = 16 + iconSize + 16
		local name = RewardKit.Label(face, potion.Name, UiKit.Head, 24, potion.Color, 2.5, x, 12, cardW - x - 70, 30)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local info = RewardKit.Label(
			face,
			("%s FOR %s"):format(boostText(potion), clock(potion.Minutes * 60)),
			UiKit.Body,
			15,
			C.White,
			0,
			x,
			44,
			cardW - x - 14,
			20
		)
		info.TextXAlignment = Enum.TextXAlignment.Left
		local status = RewardKit.Label(face, "", UiKit.Head, 16, C.Faded, 2, x, 66, cardW - x - 14, 22)
		status.TextXAlignment = Enum.TextXAlignment.Left
		-- "x4" pill, top-right
		local pill = UiKit.Block(face, {
			Name = "Count",
			Size = Vector2.new(58, 32),
			Fill = C.Cover,
			Lip = C.Ink,
			LipPx = 4,
			Radius = 16,
			Outline = 2,
		})
		pill.Holder.Position = UDim2.fromOffset(cardW - 6 - 58 - 10, 10)
		local count = RewardKit.Label(pill.Face, "x0", UiKit.Num, 18, C.Gold, 2, 2, 1, 50, 24)
		local drink = RewardKit.Button(face, "DRINK", "Lime", cardW - x - 20, 48, 24)
		drink.Holder.Name = "Drink"
		drink.Holder.Position = UDim2.fromOffset(x, faceH - 48 - 12)
		drink.Activated:Connect(function()
			if (decode(player:GetAttribute("Potions"))[potion.Id] or 0) > 0 then
				PotionController.Use(potion)
			else
				drink:Shake()
			end
		end)
		cards[potion.Id] = { Card = block.Holder, Outline = ring, Count = count, Status = status, Drink = drink }
	end

	-- Studio only: one of every potion
	local testRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("TestPotions") :: RemoteEvent?
	if testRemote then
		local test = button(
			page,
			"TestPotions",
			"TEST: POTIONS",
			Color3.fromRGB(60, 60, 80),
			UDim2.new(1, -140, 1, -24),
			UDim2.fromOffset(140, 22)
		)
		test.TextColor3 = Color3.new(1, 1, 1)
		test.ZIndex = 4
		test.Activated:Connect(function()
			testRemote:FireServer()
		end)
	end
	refresh()
end

function PotionController:Start()
	useRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("UsePotion") :: RemoteFunction
	local playerGui = player:WaitForChild("PlayerGui")
	playerGui:WaitForChild("HUD") -- the HUD Kit lays the timers out against it
	local ballsUI = playerGui:WaitForChild("BallsUI") :: ScreenGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "PotionUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = ballsUI.DisplayOrder
	gui.IgnoreGuiInset = ballsUI.IgnoreGuiInset

	-- ===== Running timers: a row of cards, one per running potion =====
	local timers = Instance.new("Frame")
	timers.Name = "Timers"
	timers.BackgroundTransparency = 1
	timers.AutomaticSize = Enum.AutomaticSize.X
	timers.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = timers

	for index, potion in POTIONS.List do
		if V2_KIT then
			chips[potion.Id] = buildChipV2(potion, timers, index)
			continue
		end
		local look = KIND_LOOKS[potion.Boost] or KIND_LOOKS.Coins
		local chip = Instance.new("Frame")
		chip.Name = potion.Id
		chip.LayoutOrder = index
		chip.BackgroundTransparency = 1
		chip.Visible = false
		chip.Parent = timers
		local scale = Instance.new("UIScale")
		scale.Parent = chip
		local inner = Instance.new("Frame")
		inner.Name = "Inner"
		inner.BackgroundTransparency = 1
		inner.Size = UDim2.fromScale(1, 1)
		inner.Parent = chip
		local block = HudKit.Block(inner, { Name = "Card", Paint = "Card", Shine = 0, Lip = 5 })
		block.Holder.Size = UDim2.fromScale(1, 1)
		block.LipFrame.ClipsDescendants = true
		local icon = HudKit.Image(inner, look.Icon, 40)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.ZIndex = 5
		local name = HudKit.Text(inner, potion.Name, HudKit.Head, 14, look.Color, 2)
		name.Name = "PotionName"
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local time = HudKit.Text(inner, "", HudKit.Num, 18, K.White, 2)
		time.Name = "Time"
		-- The bottom bar: time left
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BackgroundColor3 = look.Color
		bar.BorderSizePixel = 0
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0, 1)
		bar.ZIndex = 4
		bar.Parent = block.LipFrame
		local pulse = TweenService:Create(
			block.Scale,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Scale = 1.04 }
		)
		chips[potion.Id] = {
			Chip = chip,
			Inner = inner,
			Scale = scale,
			Block = block,
			Icon = icon,
			Name = name,
			Time = time,
			Bar = bar,
			Pulse = pulse,
			Ending = false,
		}
	end

	-- Computer 200x52 (name and time side by side), phone 100x38 (name over time)
	local function arrange(phone: boolean)
		if V2_KIT then
			-- 60 px discs 16 apart, the time under (phone 34 / 9)
			local d = if phone then 34 else 60
			local textSize = if phone then 11 else 15
			list.Padding = UDim.new(0, if phone then 9 else 16)
			timers.Size = UDim2.fromOffset(0, d + textSize + 4)
			for _, chip in chips do
				chip.Chip.Size = UDim2.fromOffset(d, d + textSize + 4)
				chip.Ring.Size = UDim2.fromOffset(d, d)
				local band = if phone then 4 else 7
				chip.Hole.Size = UDim2.fromOffset(d - band * 2, d - band * 2)
				chip.Icon.Size = UDim2.fromOffset(math.floor(d * 0.6), math.floor(d * 0.6))
				chip.Block.Outline.Thickness = if phone then 2 else 3
				chip.Time.TextSize = textSize
				chip.Time.Size = UDim2.new(1, 16, 0, textSize + 2)
			end
			timers.AnchorPoint = Vector2.zero
			timers.Position = HudKit.Spot("Potions", phone)
			return
		end
		list.Padding = UDim.new(0, if phone then 6 else 12)
		timers.Size = UDim2.fromOffset(0, if phone then 38 else 52)
		for _, chip in chips do
			chip.Chip.Size = if phone then UDim2.fromOffset(100, 38) else UDim2.fromOffset(200, 52)
			chip.Block:SetRadius(if phone then 11 else 14)
			chip.Block:SetLip(if phone then 3 else 5)
			local iconSize = if phone then 26 else 40
			chip.Icon.Size = UDim2.fromOffset(iconSize, iconSize)
			chip.Icon.Position = UDim2.new(0, if phone then 4 else 6, 0.5, -2)
			local left = iconSize + (if phone then 6 else 12)
			if phone then
				chip.Name.TextSize = 8
				chip.Name.Position = UDim2.fromOffset(left, 7)
				chip.Name.Size = UDim2.new(1, -left - 4, 0, 9)
				chip.Time.TextSize = 13
				chip.Time.TextXAlignment = Enum.TextXAlignment.Left
				chip.Time.Position = UDim2.fromOffset(left, 18)
				chip.Time.Size = UDim2.new(1, -left - 4, 0, 13)
			else
				chip.Name.TextSize = 14
				chip.Name.Position = UDim2.fromOffset(left, 0)
				chip.Name.Size = UDim2.new(1, -left - 60, 1, -5)
				chip.Time.TextSize = 18
				chip.Time.TextXAlignment = Enum.TextXAlignment.Right
				chip.Time.Position = UDim2.new(1, -62, 0, 0)
				chip.Time.Size = UDim2.new(0, 52, 1, -5)
			end
			chip.Bar.Size = UDim2.new(chip.Bar.Size.X.Scale, 0, 0, if phone then 3 else 5)
		end
		local position = HudKit.Spot("Potions", phone)
		timers.AnchorPoint = Vector2.zero
		timers.Position = position
	end
	HudKit.OnLayout(arrange)
	HudKit.Tuckable(timers, "Potions")

	player:GetAttributeChangedSignal("Potions"):Connect(refresh)
	player:GetAttributeChangedSignal("Boosts"):Connect(refresh)
	refresh()
	gui.Parent = playerGui
end

return PotionController
