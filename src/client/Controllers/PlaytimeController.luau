-- Playtime gifts on screen (owner 2026-10-22, Config.Playtime): the GIFTS button (right of PETS) with the time
-- to the next gift, and the gifts panel (12 gifts, one every 15 minutes) with a CLAIM button on each ready gift.
-- Built in code (not in Studio), so it lives in git. The server runs the clock and hands out gifts (PlaytimeService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Mascots = require(Shared.Modules.Mascots)
local Zones = require(Shared.Modules.Zones)
local CrateController = require(script.Parent.CrateController)
local PotionController = require(script.Parent.PotionController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))

local player = Players.LocalPlayer

local PLAYTIME = Config.Playtime

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local CAPTION_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("06060F")
local CARD = Color3.fromRGB(30, 20, 60)
local PANEL = Color3.fromRGB(18, 12, 38)
local PINK = Color3.fromRGB(255, 70, 170)
local LIME = Color3.fromRGB(125, 255, 60)
local GOLD = Color3.fromRGB(255, 200, 40)
local GREY = Color3.fromRGB(120, 110, 150)

-- The GIFTS button sits right of BALLS and PETS (and the same on short phone screens)
local BUTTON_NORMAL = UDim2.fromOffset(142, 304)
local BUTTON_COMPACT = UDim2.fromOffset(138, 76)
local PANEL_SIZE = UDim2.fromOffset(640, 380)

local PlaytimeController = {}

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

-- A gift box drawn with frames: box, lid, ribbon both ways
local function giftBox(parent: Instance, color: Color3, position: UDim2, size: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Gift"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = position
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent

	local box = Instance.new("Frame")
	box.Name = "Box"
	box.AnchorPoint = Vector2.new(0.5, 1)
	box.Position = UDim2.fromScale(0.5, 1)
	box.Size = UDim2.fromScale(0.8, 0.62)
	box.BackgroundColor3 = color
	box.Parent = holder
	corner(box, 3)
	stroke(box, INK, 2)

	local lid = Instance.new("Frame")
	lid.Name = "Lid"
	lid.AnchorPoint = Vector2.new(0.5, 0)
	lid.Position = UDim2.fromScale(0.5, 0.2)
	lid.Size = UDim2.fromScale(0.96, 0.24)
	lid.BackgroundColor3 = color
	lid.ZIndex = 2
	lid.Parent = holder
	corner(lid, 3)
	stroke(lid, INK, 2)

	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.AnchorPoint = Vector2.new(0.5, 0)
	ribbon.Position = UDim2.fromScale(0.5, 0.2)
	ribbon.Size = UDim2.fromScale(0.18, 0.8)
	ribbon.BackgroundColor3 = GOLD
	ribbon.BorderSizePixel = 0
	ribbon.ZIndex = 3
	ribbon.Parent = holder
	for side = -1, 1, 2 do -- the bow
		local loop = Instance.new("Frame")
		loop.Name = "Bow"
		loop.AnchorPoint = Vector2.new(0.5, 1)
		loop.Position = UDim2.fromScale(0.5 + side * 0.13, 0.24)
		loop.Size = UDim2.fromScale(0.24, 0.2)
		loop.BackgroundColor3 = GOLD
		loop.Rotation = side * 25
		loop.ZIndex = 3
		loop.Parent = holder
		corner(loop)
		stroke(loop, INK, 1.5)
	end
	return holder
end

-- An egg drawn with frames (tall oval with spots)
local function eggIcon(parent: Instance, look, position: UDim2, size: number): Frame
	local egg = Instance.new("Frame")
	egg.Name = "Egg"
	egg.AnchorPoint = Vector2.new(0.5, 0.5)
	egg.Position = position
	egg.Size = UDim2.fromOffset(size * 0.72, size)
	egg.BackgroundColor3 = look.Color
	egg.Parent = parent
	corner(egg)
	stroke(egg, INK, 2.5)
	for _, spot in { { 0.3, 0.3, 0.22 }, { 0.62, 0.52, 0.18 }, { 0.36, 0.7, 0.14 } } do
		local dot = Instance.new("Frame")
		dot.Name = "Spot"
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(spot[1], spot[2])
		dot.Size = UDim2.fromScale(spot[3] * 1.3, spot[3])
		dot.BackgroundColor3 = look.Spots
		dot.Parent = egg
		corner(dot)
	end
	return egg
end

-- A crate drawn with frames (box with a lid band and a lock)
local function crateIcon(parent: Instance, color: Color3, position: UDim2, size: number): Frame
	local crate = Instance.new("Frame")
	crate.Name = "Crate"
	crate.AnchorPoint = Vector2.new(0.5, 0.5)
	crate.Position = position
	crate.Size = UDim2.fromOffset(size, size * 0.8)
	crate.BackgroundColor3 = color
	crate.Parent = parent
	corner(crate, 4)
	stroke(crate, INK, 2.5)
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.Position = UDim2.fromScale(0, 0.3)
	band.Size = UDim2.fromScale(1, 0.14)
	band.BackgroundColor3 = INK
	band.BackgroundTransparency = 0.4
	band.BorderSizePixel = 0
	band.Parent = crate
	local lock = Instance.new("Frame")
	lock.Name = "Lock"
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.fromScale(0.5, 0.42)
	lock.Size = UDim2.fromScale(0.22, 0.26)
	lock.BackgroundColor3 = GOLD
	lock.Parent = crate
	corner(lock, 3)
	stroke(lock, INK, 1.5)
	return crate
end

local function potionById(id: string)
	for _, potion in Config.Potions.List do
		if potion.Id == id then
			return potion
		end
	end
	return nil
end

-- The crate a Crate gift opens as for this player right now (a zone you haven't reached gives your zone's crate)
local function rewardCrate(reward)
	local id = if reward.Exact
		then reward.Crate
		else Zones.RewardCrateId(reward.Crate, player:GetAttribute("RankLevel"))
	return Balls.GetCrate(id)
end

-- Name and colour of a gift, as the player sees it now
local function describe(reward): (string, Color3)
	if reward.Potion then
		local potion = potionById(reward.Potion)
		return if potion then potion.Name else reward.Potion, if potion then potion.Color else PINK
	elseif reward.Egg then
		local look = Config.EggLooks[reward.Egg]
		return string.upper(if look then look.Name else "EGG"), if look then look.Color else PINK
	end
	local crate = rewardCrate(reward)
	return string.upper(if crate then crate.Name else "CRATE"), if crate then crate.Color else GOLD
end

function PlaytimeController:Start()
	if not PLAYTIME.Enabled then
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local claimRemote = remotes:WaitForChild("ClaimPlaytime") :: RemoteFunction
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local ballsUI = playerGui:WaitForChild("BallsUI") :: ScreenGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "PlaytimeUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = ballsUI.DisplayOrder
	gui.IgnoreGuiInset = ballsUI.IgnoreGuiInset

	-- ===== GIFTS button (same look as BALLS, DAILY, PETS and POTIONS, in pink) =====
	local openButton = Instance.new("TextButton")
	openButton.Name = "GiftsButton"
	openButton.Text = ""
	openButton.AutoButtonColor = false
	openButton.BackgroundColor3 = CARD
	openButton.BackgroundTransparency = 0.1
	openButton.Size = UDim2.fromOffset(55, 56)
	openButton.Position = BUTTON_NORMAL
	openButton.Parent = gui
	corner(openButton, 12)
	local buttonStroke = stroke(openButton, PINK, 3, true)
	-- Caption = time to the next gift ("12:34"), GIFTS when one is ready or all are claimed
	local caption = text(openButton, "Caption", CAPTION_FONT, PINK, UDim2.new(0, 3, 1, -17), UDim2.new(1, -6, 0, 13))
	caption.Text = "GIFTS"
	local buttonGift = giftBox(openButton, PINK, UDim2.new(0.5, 0, 0, 21), 28)
	-- How many gifts are ready to claim
	local badge =
		text(openButton, "Count", FONT, Color3.new(1, 1, 1), UDim2.new(1, -12, 0, -6), UDim2.fromOffset(20, 20))
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = Color3.fromRGB(255, 50, 70)
	badge.ZIndex = 4
	badge.Visible = false
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
	stroke(panel, PINK, 4, true)

	local title = text(panel, "Title", FONT, Color3.new(1, 1, 1), UDim2.new(0, 20, 0, 12), UDim2.new(1, -80, 0, 38))
	title.Text = "PLAYTIME GIFTS"
	title.TextXAlignment = Enum.TextXAlignment.Left
	local hint =
		text(panel, "Hint", BODY_FONT, Color3.fromRGB(200, 190, 230), UDim2.new(0, 20, 0, 52), UDim2.new(1, -40, 0, 18))
	hint.Text = "A free gift every 15 minutes you play. They start over every visit!"
	hint.TextXAlignment = Enum.TextXAlignment.Left

	local close =
		button(panel, "Close", "X", Color3.fromRGB(255, 70, 90), UDim2.new(1, -54, 0, 12), UDim2.fromOffset(42, 42))
	close.TextColor3 = Color3.new(1, 1, 1)

	local grid = Instance.new("Frame")
	grid.Name = "Gifts"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.new(0, 16, 0, 80)
	grid.Size = UDim2.new(1, -32, 1, -116)
	grid.Parent = panel
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 6, -7, 0.5, -5)
	layout.CellPadding = UDim2.fromOffset(8, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local tiles = {}
	for index, reward in PLAYTIME.Rewards do
		local tile = Instance.new("Frame")
		tile.Name = "Gift" .. index
		tile.LayoutOrder = index
		tile.BackgroundColor3 = CARD
		tile.Parent = grid
		corner(tile, 12)
		local outline = stroke(tile, GREY, 2, true)

		local mark = text(tile, "Minutes", FONT, Color3.new(1, 1, 1), UDim2.new(0, 4, 0, 4), UDim2.new(1, -8, 0, 16))
		mark.Text = if reward.Minutes >= 60 and reward.Minutes % 60 == 0
			then ("%d HOUR%s"):format(reward.Minutes // 60, if reward.Minutes == 60 then "" else "S")
			else ("%d MIN"):format(reward.Minutes)

		local iconSpot = UDim2.fromScale(0.5, 0.37)
		local icon
		if reward.Potion then
			local potion = potionById(reward.Potion)
			icon = PotionController.Flask(
				tile,
				if potion then potion.Color else PINK,
				potion ~= nil and potion.Big,
				iconSpot,
				40
			)
		elseif reward.Egg then
			icon = eggIcon(tile, Config.EggLooks[reward.Egg] or { Color = PINK, Spots = GOLD }, iconSpot, 40)
		else
			icon = crateIcon(tile, GOLD, iconSpot, 40)
		end

		local name =
			text(tile, "GiftName", BODY_FONT, Color3.new(1, 1, 1), UDim2.new(0, 4, 0.56, 0), UDim2.new(1, -8, 0, 26))
		name.TextWrapped = true

		local timer = text(tile, "Timer", FONT, GREY, UDim2.new(0, 6, 1, -30), UDim2.new(1, -12, 0, 24))
		local claim = button(tile, "Claim", "CLAIM", LIME, UDim2.new(0, 6, 1, -32), UDim2.new(1, -12, 0, 26))
		claim.Visible = false
		claim.Activated:Connect(function()
			PlaytimeController.Claim(index)
		end)
		tiles[index] = {
			Tile = tile,
			Outline = outline,
			Icon = icon,
			Name = name,
			Timer = timer,
			Claim = claim,
		}
	end

	-- Toast for messages ("Hatch it at the egg stand!")
	local toast = text(gui, "Toast", FONT, Color3.new(1, 1, 1), UDim2.fromScale(0.5, 0.2), UDim2.new(0.7, 0, 0, 34))
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.Visible = false
	toast.ZIndex = 20
	local toastToken = 0
	local function showToast(message: string, seconds: number?)
		toastToken += 1
		local token = toastToken
		toast.Text = message
		toast.Visible = true
		UiFx.Pop(toast, 1.3, 0.25)
		task.delay(seconds or 1.6, function()
			if toastToken == token then
				toast.Visible = false
			end
		end)
	end

	local function claimedSet(): { [number]: boolean }
		local set = {}
		local value = player:GetAttribute("PlaytimeClaimed")
		if type(value) == "string" then
			for number in value:gmatch("%d+") do
				set[tonumber(number) :: number] = true
			end
		end
		return set
	end

	local function played(): number?
		local start = player:GetAttribute("PlaytimeStart")
		return if type(start) == "number" then Workspace:GetServerTimeNow() - start else nil
	end

	local lastReady = 0
	local function refresh()
		local seconds = played()
		local claimed = claimedSet()
		local ready = 0
		local nextLeft = nil
		for index, reward in PLAYTIME.Rewards do
			local tile = tiles[index]
			local nameText, color = describe(reward)
			tile.Name.Text = nameText
			if reward.Crate then
				tile.Icon.BackgroundColor3 = color
			end
			local left = if seconds then reward.Minutes * 60 - seconds else math.huge
			if claimed[index] then
				tile.Claim.Visible = false
				tile.Timer.Visible = true
				tile.Timer.Text = "CLAIMED"
				tile.Timer.TextColor3 = LIME
				tile.Outline.Color = GREY
				tile.Tile.BackgroundTransparency = 0.5
			elseif left <= 0 then
				ready += 1
				tile.Claim.Visible = true
				tile.Timer.Visible = false
				tile.Outline.Color = LIME
				tile.Outline.Thickness = 3
				tile.Tile.BackgroundTransparency = 0
			else
				tile.Claim.Visible = false
				tile.Timer.Visible = true
				tile.Timer.Text = if seconds then clock(left) else "--:--"
				tile.Timer.TextColor3 = if nextLeft == nil then Color3.new(1, 1, 1) else GREY
				tile.Outline.Color = if nextLeft == nil then color else GREY
				tile.Outline.Thickness = 2
				tile.Tile.BackgroundTransparency = 0
				nextLeft = nextLeft or left
			end
		end
		badge.Text = tostring(ready)
		badge.Visible = ready > 0
		caption.Text = if ready > 0 or not nextLeft then "GIFTS" else clock(nextLeft)
		caption.TextColor3 = if ready > 0 then LIME else PINK
		buttonStroke.Color = if ready > 0 then LIME else PINK
		if ready > lastReady then
			-- A new gift is ready: the button bounces
			UiFx.Pop(openButton, 1.35, 0.4)
			UiFx.Pop(buttonGift, 1.5, 0.5)
			Sfx.Play("Reveal")
		end
		lastReady = ready
	end

	local claiming = false
	function PlaytimeController.Claim(index: number)
		if claiming then
			return
		end
		claiming = true
		local ok, result = pcall(claimRemote.InvokeServer, claimRemote, index)
		claiming = false
		if not ok or type(result) ~= "table" or not result.Ok then
			showToast(if ok and type(result) == "table" and result.Error then result.Error else "Something went wrong")
			return
		end
		refresh()
		local reward = PLAYTIME.Rewards[index]
		local tile = tiles[index]
		local _, color = describe(reward)
		Sfx.Play("Reveal")
		UiFx.Pop(tile.Tile, 1.15, 0.35)
		UiFx.Flash(color, 0.3, 0.4)
		if result.Potion then
			local potion = potionById(result.Potion)
			showToast(("%s ADDED TO YOUR POTIONS!"):format(if potion then potion.Name else "POTION"), 2.2)
		elseif result.Egg then
			local egg = Mascots.GetEgg(result.Egg)
			local level = player:GetAttribute("RankLevel") or 1
			local unlocked = egg ~= nil and Mascots.EggUnlocked(egg, level, Zones.Highest(level))
			local look = Config.EggLooks[result.Egg]
			local eggName = string.upper(if look then look.Name else "EGG")
			showToast(
				if unlocked
					then ("FREE %s! HATCH IT AT THE EGG STAND"):format(eggName)
					else ("FREE %s! IT WAITS FOR YOU IN THE NEXT ZONE"):format(eggName),
				3
			)
		end
		local crate = Balls.GetCrate(result.CrateId)
		if crate and result.Crate and CrateController.PlayOpening then
			UiFx.Confetti(nil, 30)
			task.wait(0.6)
			UiFx.Close(panel)
			CrateController.PlayOpening(crate, result.Crate)
		end
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

	-- Studio only: jump the clock 15 minutes ahead
	local testRemote = remotes:FindFirstChild("TestPlaytime") :: RemoteEvent?
	if testRemote then
		local test = button(
			panel,
			"TestPlaytime",
			"TEST: +15 MIN",
			Color3.fromRGB(60, 60, 80),
			UDim2.new(0, 16, 1, -30),
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
	end
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeAll)
	placeAll()

	player:GetAttributeChangedSignal("PlaytimeStart"):Connect(refresh)
	player:GetAttributeChangedSignal("PlaytimeClaimed"):Connect(refresh)
	player:GetAttributeChangedSignal("RankLevel"):Connect(refresh)
	refresh()
	gui.Parent = playerGui

	-- The timers count down every second
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
end

return PlaytimeController
