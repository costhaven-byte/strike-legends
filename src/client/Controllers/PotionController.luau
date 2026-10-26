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
local TweenService = game:GetService("TweenService")
local K = HudKit.C

local player = Players.LocalPlayer

local POTIONS = Config.Potions

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local INK = Color3.fromHex("06060F")
local CARD = Color3.fromRGB(30, 20, 60)
local PANEL = Color3.fromRGB(18, 12, 38)
local PURPLE = Color3.fromRGB(190, 90, 255)
local LIME = Color3.fromRGB(125, 255, 60)
local GREY = Color3.fromRGB(120, 110, 150)

-- Running timers (owner's HUD Kit): one card per running potion, bottom-left on computers, bottom middle (right of
-- HOLD!) on phones, growing to the right. Name and bar colour per kind.
local KIND_LOOKS = {
	Coins = { Icon = "PotionCoin", Color = K.Gold },
	XP = { Icon = "PotionXp", Color = K.Lime },
}

local PotionController = {}

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

local function refresh()
	local owned = decode(player:GetAttribute("Potions"))
	local boosts = decode(player:GetAttribute("Boosts"))
	local active = running(boosts)
	for _, potion in POTIONS.List do
		local count = owned[potion.Id] or 0
		local left = boosts[potion.Id] or 0
		local card = cards[potion.Id]
		if card then
			card.Owned.Text = if left > 0
				then ("YOU HAVE %d  ·  %s %s"):format(
					count,
					if active[potion.Id] then "ON" else "WAITING",
					clock(left)
				)
				else ("YOU HAVE %d"):format(count)
			card.Owned.TextColor3 = if left > 0 then LIME elseif count > 0 then Color3.new(1, 1, 1) else GREY
			card.Drink.BackgroundColor3 = if count > 0 then LIME else Color3.fromRGB(70, 65, 90)
			card.Drink.TextColor3 = if count > 0 then INK else GREY
			card.Outline.Thickness = if left > 0 then 3 else 2
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
				chip.Block.Outline.Color = if ending then K.Red else K.Ink
				chip.Icon.ImageTransparency = if on then 0 else 0.5
				chip.Bar.Size = UDim2.new(math.clamp(left / (potion.Minutes * 60), 0, 1), 0, 0, chip.Bar.Size.Y.Offset)
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
		showToast(if ok and type(result) == "table" and result.Error then result.Error else "Something went wrong")
		return
	end
	Sfx.Play("PowerUp")
	UiFx.Flash(potion.Color, 0.35, 0.4)
	if cards[potion.Id] then
		UiFx.Pop(cards[potion.Id].Card, 1.08, 0.3)
	end
	task.defer(function()
		local chip = chips[potion.Id]
		if chip and chip.Chip.Visible then
			UiFx.Pop(chip.Chip, 1.4, 0.4)
		end
	end)
end

-- The ITEMS tab of the PETS panel: a hint, one card per potion with DRINK, and (Studio only) TEST: POTIONS.
-- toast = the panel's own message line.
function PotionController.BuildItems(page: Frame, toast: (string) -> ())
	showToast = toast
	local hint =
		text(page, "Hint", BODY_FONT, Color3.fromRGB(200, 190, 230), UDim2.fromOffset(4, 0), UDim2.new(1, -8, 0, 18))
	hint.Text = "POTIONS: drink one for 15 minutes of boost. Timers only run while you play."
	hint.TextXAlignment = Enum.TextXAlignment.Left

	local grid = Instance.new("Frame")
	grid.Name = "Cards"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 26)
	grid.Size = UDim2.new(1, 0, 1, -60)
	grid.Parent = page
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -6, 0.5, -6)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	for index, potion in POTIONS.List do
		local card = Instance.new("Frame")
		card.Name = potion.Id
		card.LayoutOrder = index
		card.BackgroundColor3 = CARD
		card.Parent = grid
		corner(card, 12)
		local outline = stroke(card, potion.Color, 2, true)
		flask(card, potion.Color, potion.Big, UDim2.new(0, 38, 0.5, 0), 52)
		local name = text(card, "PotionName", FONT, potion.Color, UDim2.new(0, 74, 0, 8), UDim2.new(1, -82, 0, 22))
		name.Text = potion.Name
		name.TextXAlignment = Enum.TextXAlignment.Left
		local info =
			text(card, "Info", BODY_FONT, Color3.new(1, 1, 1), UDim2.new(0, 74, 0, 32), UDim2.new(1, -82, 0, 16))
		info.Text = ("%s FOR %d MIN"):format(boostText(potion), potion.Minutes)
		info.TextXAlignment = Enum.TextXAlignment.Left
		local owned = text(card, "Owned", BODY_FONT, GREY, UDim2.new(0, 74, 0, 50), UDim2.new(1, -82, 0, 14))
		owned.TextXAlignment = Enum.TextXAlignment.Left
		local drink = button(card, "Drink", "DRINK", LIME, UDim2.new(0, 74, 1, -36), UDim2.new(1, -86, 0, 28))
		drink.Activated:Connect(function()
			PotionController.Use(potion)
		end)
		cards[potion.Id] = { Card = card, Outline = outline, Owned = owned, Drink = drink }
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

	player:GetAttributeChangedSignal("Potions"):Connect(refresh)
	player:GetAttributeChangedSignal("Boosts"):Connect(refresh)
	refresh()
	gui.Parent = playerGui
end

return PotionController
