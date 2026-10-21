-- Potions on screen (owner 2026-10-22, Config.Potions): the POTIONS button (right of PETS), the potion panel with a
-- DRINK button per potion, and the running timers on the right under the lane event pill.
-- Built in code (not in Studio), so it lives in git. The server runs every timer (PotionService); this only shows it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))

local player = Players.LocalPlayer

local POTIONS = Config.Potions

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local CAPTION_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("06060F")
local CARD = Color3.fromRGB(30, 20, 60)
local PANEL = Color3.fromRGB(18, 12, 38)
local PURPLE = Color3.fromRGB(190, 90, 255)
local LIME = Color3.fromRGB(125, 255, 60)
local GREY = Color3.fromRGB(120, 110, 150)

-- The POTIONS button sits right of BALLS, DAILY and PETS (and the same on short phone screens)
local BUTTON_NORMAL = UDim2.fromOffset(205, 304)
local BUTTON_COMPACT = UDim2.fromOffset(201, 76)
-- Running timers: right side under the lane event pill and next-goal bar; on phones left, under the next-goal bar
local TIMERS_NORMAL = { Anchor = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0.42, 130), Width = 220 }
local TIMERS_COMPACT = { Anchor = Vector2.new(0, 0), Position = UDim2.fromOffset(12, 196), Width = 150 }
local PANEL_SIZE = UDim2.fromOffset(560, 340)

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

local function boostText(potion): string
	return ("x%d %s"):format(potion.Multiplier, if potion.Boost == "Coins" then "COINS" else "XP")
end

function PotionController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local useRemote = remotes:WaitForChild("UsePotion") :: RemoteFunction
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local ballsUI = playerGui:WaitForChild("BallsUI") :: ScreenGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "PotionUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = ballsUI.DisplayOrder
	gui.IgnoreGuiInset = ballsUI.IgnoreGuiInset

	-- ===== POTIONS button (same look as BALLS, DAILY and PETS, in purple) =====
	local openButton = Instance.new("TextButton")
	openButton.Name = "PotionsButton"
	openButton.Text = ""
	openButton.AutoButtonColor = false
	openButton.BackgroundColor3 = CARD
	openButton.BackgroundTransparency = 0.1
	openButton.Size = UDim2.fromOffset(55, 56)
	openButton.Position = BUTTON_NORMAL
	openButton.Parent = gui
	corner(openButton, 12)
	stroke(openButton, PURPLE, 3, true)
	local caption = text(openButton, "Caption", CAPTION_FONT, PURPLE, UDim2.new(0, 3, 1, -17), UDim2.new(1, -6, 0, 13))
	caption.Text = "POTIONS"
	flask(openButton, PURPLE, false, UDim2.new(0.5, 0, 0, 21), 30)
	-- How many potions are waiting to be drunk
	local badge =
		text(openButton, "Count", FONT, Color3.new(1, 1, 1), UDim2.new(1, -12, 0, -6), UDim2.fromOffset(20, 20))
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = Color3.fromRGB(255, 50, 70)
	badge.ZIndex = 3
	corner(badge)
	stroke(badge, Color3.new(1, 1, 1), 2, true)
	UiFx.Press(openButton)

	-- ===== The panel =====
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.53)
	panel.Size = PANEL_SIZE
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Active = true -- taps on the panel don't fall through to the throw meter
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, PURPLE, 4, true)

	local title = text(panel, "Title", FONT, Color3.new(1, 1, 1), UDim2.new(0, 20, 0, 12), UDim2.new(1, -80, 0, 38))
	title.Text = "POTIONS"
	title.TextXAlignment = Enum.TextXAlignment.Left
	local hint =
		text(panel, "Hint", BODY_FONT, Color3.fromRGB(200, 190, 230), UDim2.new(0, 20, 0, 52), UDim2.new(1, -40, 0, 18))
	hint.Text = "Drink one for 15 minutes of boost. Timers only run while you play."
	hint.TextXAlignment = Enum.TextXAlignment.Left

	local close =
		button(panel, "Close", "X", Color3.fromRGB(255, 70, 90), UDim2.new(1, -54, 0, 12), UDim2.fromOffset(42, 42))
	close.TextColor3 = Color3.new(1, 1, 1)

	local grid = Instance.new("Frame")
	grid.Name = "Cards"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.new(0, 16, 0, 80)
	grid.Size = UDim2.new(1, -32, 1, -120)
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -6, 0.5, -6)
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local cards = {}
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

	-- Toast for errors ("You don't have that potion")
	local toast = text(gui, "Toast", FONT, Color3.new(1, 1, 1), UDim2.fromScale(0.5, 0.2), UDim2.new(0.6, 0, 0, 34))
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.Visible = false
	toast.ZIndex = 20
	local toastToken = 0
	local function showToast(message: string)
		toastToken += 1
		local token = toastToken
		toast.Text = message
		toast.Visible = true
		UiFx.Pop(toast, 1.3, 0.25)
		task.delay(1.6, function()
			if toastToken == token then
				toast.Visible = false
			end
		end)
	end

	-- ===== Running timers =====
	local timers = Instance.new("Frame")
	timers.Name = "Timers"
	timers.BackgroundTransparency = 1
	timers.AutomaticSize = Enum.AutomaticSize.Y
	timers.Parent = gui
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = timers

	local chips = {}
	for index, potion in POTIONS.List do
		local chip = Instance.new("Frame")
		chip.Name = potion.Id
		chip.LayoutOrder = index
		chip.Size = UDim2.new(1, 0, 0, 26)
		chip.BackgroundColor3 = CARD
		chip.BackgroundTransparency = 0.1
		chip.Visible = false
		chip.Parent = timers
		corner(chip)
		stroke(chip, potion.Color, 2, true)
		flask(chip, potion.Color, potion.Big, UDim2.new(0, 15, 0.5, 0), 20)
		local label = text(chip, "Boost", FONT, potion.Color, UDim2.new(0, 30, 0, 4), UDim2.new(0.55, -30, 1, -8))
		label.Text = boostText(potion)
		label.TextXAlignment = Enum.TextXAlignment.Left
		local time =
			text(chip, "Time", FONT, Color3.new(1, 1, 1), UDim2.new(0.55, 0, 0, 4), UDim2.new(0.45, -12, 1, -8))
		time.TextXAlignment = Enum.TextXAlignment.Right
		chips[potion.Id] = { Chip = chip, Label = label, Time = time }
	end

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

	local function refresh()
		local owned = decode(player:GetAttribute("Potions"))
		local boosts = decode(player:GetAttribute("Boosts"))
		local active = running(boosts)
		local total = 0
		for _, potion in POTIONS.List do
			local count = owned[potion.Id] or 0
			total += count
			local left = boosts[potion.Id] or 0
			local card = cards[potion.Id]
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

			local chip = chips[potion.Id]
			chip.Chip.Visible = left > 0
			if left > 0 then
				-- A weaker potion waits (paused) while a stronger one of its kind runs
				chip.Time.Text = if active[potion.Id] then clock(left) else "WAIT " .. clock(left)
				chip.Chip.BackgroundTransparency = if active[potion.Id] then 0.1 else 0.5
				chip.Label.TextTransparency = if active[potion.Id] then 0 else 0.4
			end
		end
		badge.Text = tostring(total)
		badge.Visible = total > 0
	end

	function PotionController.Use(potion)
		local ok, result = pcall(useRemote.InvokeServer, useRemote, potion.Id)
		if not ok or type(result) ~= "table" or not result.Ok then
			showToast(if ok and type(result) == "table" and result.Error then result.Error else "Something went wrong")
			return
		end
		Sfx.Play("PowerUp")
		UiFx.Flash(potion.Color, 0.35, 0.4)
		UiFx.Pop(cards[potion.Id].Card, 1.08, 0.3)
		task.defer(function()
			local chip = chips[potion.Id]
			if chip.Chip.Visible then
				UiFx.Pop(chip.Chip, 1.4, 0.4)
			end
		end)
	end

	openButton.Activated:Connect(function()
		if panel.Visible then
			UiFx.Close(panel)
		else
			refresh()
			UiFx.Open(panel)
		end
	end)
	close.Activated:Connect(function()
		UiFx.Close(panel)
	end)

	-- Studio only: one of every potion
	local testRemote = remotes:FindFirstChild("TestPotions") :: RemoteEvent?
	if testRemote then
		local test = button(
			panel,
			"TestPotions",
			"TEST: POTIONS",
			Color3.fromRGB(60, 60, 80),
			UDim2.new(0, 16, 1, -32),
			UDim2.fromOffset(140, 22)
		)
		test.TextColor3 = Color3.new(1, 1, 1)
		test.Activated:Connect(function()
			testRemote:FireServer()
		end)
	end

	-- Hide the button (and close the panel) while the book, crates or crate-opening screens are up
	local covers = {
		ballsUI:WaitForChild("Inventory"),
		ballsUI:WaitForChild("Book"),
		ballsUI:WaitForChild("Shop"),
		ballsUI:WaitForChild("Opening"),
	}
	local function updateButton()
		local covered = false
		for _, screen in covers do
			covered = covered or screen.Visible
		end
		openButton.Visible = not covered
		if covered then
			UiFx.Close(panel)
		end
	end
	for _, screen in covers do
		screen:GetPropertyChangedSignal("Visible"):Connect(updateButton)
	end
	updateButton()

	-- Compact layout on short screens (phones held sideways)
	local function placeAll()
		local compact = hud.AbsoluteSize.Y > 0 and hud.AbsoluteSize.Y < Config.Ui.CompactHeight
		openButton.Position = if compact then BUTTON_COMPACT else BUTTON_NORMAL
		panel.Size = if compact then UDim2.fromScale(0.94, 0.94) else PANEL_SIZE
		panel.Position = UDim2.fromScale(0.5, if compact then 0.5 else 0.53)
		local spot = if compact then TIMERS_COMPACT else TIMERS_NORMAL
		timers.AnchorPoint = spot.Anchor
		timers.Position = spot.Position
		timers.Size = UDim2.fromOffset(spot.Width, 0)
	end
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeAll)
	placeAll()

	player:GetAttributeChangedSignal("Potions"):Connect(refresh)
	player:GetAttributeChangedSignal("Boosts"):Connect(refresh)
	refresh()
	gui.Parent = playerGui
end

return PotionController
