-- REBIRTH button on the HUD (owner 2026-10-25: a button, not a station in the world), right of the level bar at the
-- top of the screen. It shows once zone 2 is open (or after a first rebirth) and stays locked (grey, "ZONE 3") until
-- the player reaches Main Street Lanes. Tapping it opens the rebirth window: what you go back to, what you keep, the
-- boost you get forever and what the next rebirth needs. REBIRTH needs a second tap to confirm.
-- Built in code (not in Studio), so it lives in git. The server decides everything (RebirthService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Rebirth = require(Shared.Modules.Rebirth)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))

local player = Players.LocalPlayer

local REBIRTH = Config.Economy.Rebirth
local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local CAPTION_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("06060F")
local CARD = Color3.fromRGB(30, 20, 60)
local PANEL = Color3.fromRGB(18, 12, 38)
local GOLD = Color3.fromRGB(255, 200, 40)
local LIME = Color3.fromRGB(125, 255, 60)
local RED = Color3.fromRGB(255, 90, 90)
local GREY = Color3.fromRGB(120, 110, 150)
local SOFT = Color3.fromRGB(200, 190, 230)
local GAP = 12 -- pixels between the level bar and the button
local CONFIRM_SECONDS = 3

local RebirthController = {}

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

-- The icon: two arrows chasing round a ring (start over)
local function rebirthIcon(parent: Instance, position: UDim2, size: number): (Frame, UIStroke, { TextLabel })
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = position
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromScale(1, 1)
	ring.Parent = holder
	corner(ring)
	local ringStroke = stroke(ring, GOLD, 4, true)
	local arrows = {}
	for i, spot in { UDim2.fromScale(0.5, 0), UDim2.fromScale(0.5, 1) } do
		local arrow = Instance.new("TextLabel")
		arrow.Name = "Arrow" .. i
		arrow.BackgroundTransparency = 1
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.Position = spot
		arrow.Size = UDim2.fromOffset(size * 0.5, size * 0.5)
		arrow.Rotation = if i == 1 then 90 else -90
		arrow.Text = "▲"
		arrow.TextScaled = true
		arrow.TextColor3 = GOLD
		arrow.Font = Enum.Font.GothamBlack
		arrow.Parent = holder
		table.insert(arrows, arrow)
	end
	return holder, ringStroke, arrows
end

function RebirthController:Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local rankBar = hud:WaitForChild("RankBar") :: GuiObject
	local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Rebirth") :: RemoteFunction

	local gui = Instance.new("ScreenGui")
	gui.Name = "RebirthUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = hud.IgnoreGuiInset -- same coordinates as the level bar it sits beside
	gui.Parent = playerGui

	-- ===== The button =====
	local openButton = Instance.new("TextButton")
	openButton.Name = "RebirthButton"
	openButton.Text = ""
	openButton.AutoButtonColor = false
	openButton.BackgroundColor3 = CARD
	openButton.BackgroundTransparency = 0.1
	openButton.Size = UDim2.fromOffset(55, 56)
	openButton.Visible = false
	openButton.Parent = gui
	corner(openButton, 12)
	local buttonStroke = stroke(openButton, GOLD, 3, true)
	local caption = text(openButton, "Caption", CAPTION_FONT, GOLD, UDim2.new(0, 3, 1, -17), UDim2.new(1, -6, 0, 13))
	caption.Text = "REBIRTH"
	local _, iconStroke, iconArrows = rebirthIcon(openButton, UDim2.new(0.5, 0, 0, 21), 26)
	-- "!" when a rebirth is ready
	local badge = text(openButton, "Ready", FONT, Color3.new(1, 1, 1), UDim2.new(1, -12, 0, -6), UDim2.fromOffset(20, 20))
	badge.Text = "!"
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = Color3.fromRGB(255, 50, 70)
	badge.ZIndex = 4
	badge.Visible = false
	corner(badge)
	stroke(badge, Color3.new(1, 1, 1), 2, true)
	UiFx.Press(openButton)

	-- Right of the level bar, top edges lined up (the bar moves on phones, so follow it)
	local function place()
		local compact = hud.AbsoluteSize.Y > 0 and hud.AbsoluteSize.Y < Config.Ui.CompactHeight
		openButton.Size = if compact then UDim2.fromOffset(44, 46) else UDim2.fromOffset(55, 56)
		local barPos, barSize = rankBar.AbsolutePosition, rankBar.AbsoluteSize
		local guiTop = gui.AbsolutePosition
		openButton.Position = UDim2.fromOffset(barPos.X - guiTop.X + barSize.X + GAP, barPos.Y - guiTop.Y)
	end
	rankBar:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	rankBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	-- ===== The window =====
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.53)
	panel.Size = UDim2.fromOffset(460, 330)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Active = true -- taps on the panel don't fall through to the throw meter
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, GOLD, 4, true)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(460, 330)
	sizeLimit.Parent = panel

	local title = text(panel, "Title", FONT, GOLD, UDim2.new(0, 20, 0, 12), UDim2.new(1, -80, 0, 38))
	title.TextXAlignment = Enum.TextXAlignment.Left
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "X"
	close.FontFace = FONT
	close.TextScaled = true
	close.TextColor3 = Color3.new(1, 1, 1)
	close.BackgroundColor3 = Color3.fromRGB(255, 70, 90)
	close.AutoButtonColor = false
	close.Position = UDim2.new(1, -54, 0, 12)
	close.Size = UDim2.fromOffset(42, 42)
	close.Parent = panel
	corner(close, 10)
	stroke(close, INK, 2, true)
	UiFx.Press(close)

	-- Four rows: heading on the left, what it means on the right
	local rows = {}
	for i, heading in { "BACK TO", "YOU KEEP", "FOREVER", "NEEDS" } do
		local y = 62 + (i - 1) * 42
		local head = text(panel, "Head" .. i, FONT, SOFT, UDim2.new(0, 20, 0, y), UDim2.new(0, 110, 0, 22))
		head.Text = heading
		head.TextXAlignment = Enum.TextXAlignment.Left
		local body =
			text(panel, "Body" .. i, BODY_FONT, Color3.new(1, 1, 1), UDim2.new(0, 136, 0, y), UDim2.new(1, -156, 0, 22))
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.RichText = true
		rows[i] = body
	end
	rows[1].Text = "LEVEL 1, POWER LEVEL 1, 0 COINS (zones lock again)"
	rows[2].Text = "BALLS, PETS, GEMS AND POTIONS"

	local go = Instance.new("TextButton")
	go.Name = "Go"
	go.FontFace = FONT
	go.TextScaled = true
	go.TextColor3 = INK
	go.AutoButtonColor = false
	go.AnchorPoint = Vector2.new(0.5, 1)
	go.Position = UDim2.new(0.5, 0, 1, -18)
	go.Size = UDim2.new(0.62, 0, 0, 56)
	go.Parent = panel
	corner(go, 12)
	stroke(go, INK, 2, true)
	local goPad = Instance.new("UIPadding")
	goPad.PaddingTop = UDim.new(0, 8)
	goPad.PaddingBottom = UDim.new(0, 8)
	goPad.Parent = go
	UiFx.Press(go)

	local confirmUntil = 0
	local busy = false

	local function state()
		local done = player:GetAttribute("Rebirths") or 0
		local level = player:GetAttribute("RankLevel") or 1
		local needLevel, cost = Rebirth.Level(done), Rebirth.Cost(done)
		local zoneOpen = Zones.Unlocked(level, REBIRTH.Zone)
		local hasLevel = level >= needLevel
		local hasCoins = Currency.CanAfford(player:GetAttribute("Coins"), cost)
		return done, needLevel, cost, zoneOpen, hasLevel, hasCoins
	end

	local function hex(color: Color3): string
		return "#" .. color:ToHex()
	end

	local function refresh()
		local done, needLevel, cost, zoneOpen, hasLevel, hasCoins = state()
		openButton.Visible = done > 0 or Zones.Unlocked(player:GetAttribute("RankLevel"), 2)
		-- The button: grey and "ZONE 3" until Main Street Lanes is reached
		local color = if zoneOpen then GOLD else GREY
		buttonStroke.Color = color
		iconStroke.Color = color
		for _, arrow in iconArrows do
			arrow.TextColor3 = color
		end
		caption.Text = if zoneOpen then "REBIRTH" else ("ZONE %d"):format(REBIRTH.Zone)
		caption.TextColor3 = color
		local ready = REBIRTH.Enabled and zoneOpen and hasLevel and hasCoins
		badge.Visible = ready

		-- The window
		title.Text = if done > 0 then ("REBIRTH %d"):format(done + 1) else "REBIRTH"
		rows[3].Text = ("COINS %s  ->  %s,  XP %s  ->  %s"):format(
			Currency.FormatMultiplier(Rebirth.CoinMultiplier(done)),
			Currency.FormatMultiplier(Rebirth.CoinMultiplier(done + 1)),
			Currency.FormatMultiplier(Rebirth.XpMultiplier(done)),
			Currency.FormatMultiplier(Rebirth.XpMultiplier(done + 1))
		)
		rows[4].Text = ('<font color="%s">LEVEL %d</font>  +  <font color="%s">%s COINS</font>'):format(
			hex(if hasLevel then LIME else RED),
			needLevel,
			hex(if hasCoins then LIME else RED),
			Currency.Format(cost)
		)
		if not REBIRTH.Enabled then
			go.Text = "COMING SOON"
		elseif not zoneOpen then
			go.Text = ("REACH %s"):format(Zones.Name(REBIRTH.Zone):upper())
		elseif not hasLevel then
			go.Text = ("REACH LEVEL %d"):format(needLevel)
		elseif not hasCoins then
			go.Text = ("NEED %s COINS"):format(Currency.Format(cost))
		elseif os.clock() < confirmUntil then
			go.Text = "TAP AGAIN TO REBIRTH"
		else
			go.Text = "REBIRTH!"
		end
		go.BackgroundColor3 = if ready then GOLD else GREY
	end

	local function setOpen(open: boolean)
		if open then
			confirmUntil = 0
			refresh()
			UiFx.Open(panel)
		else
			UiFx.Close(panel)
		end
	end

	openButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	go.Activated:Connect(function()
		local _, _, _, zoneOpen, hasLevel, hasCoins = state()
		if busy or not (REBIRTH.Enabled and zoneOpen and hasLevel and hasCoins) then
			return
		end
		-- A rebirth can't be undone: the first tap asks, the second (within a few seconds) does it
		if os.clock() >= confirmUntil then
			confirmUntil = os.clock() + CONFIRM_SECONDS
			refresh()
			UiFx.Pop(go, 1.1, 0.25)
			task.delay(CONFIRM_SECONDS, refresh)
			return
		end
		busy = true
		local ok, result = pcall(remote.InvokeServer, remote)
		busy = false
		confirmUntil = 0
		if ok and result and result.Ok then
			setOpen(false)
			UiFx.Flash(GOLD, 0.7, 0.6)
			UiFx.Confetti(nil, 60, { GOLD, Color3.new(1, 1, 1), LIME })
			Sfx.Play("RankUp", 1)
		else
			go.Text = if ok and result and result.Error then result.Error:upper() else "TRY AGAIN"
			task.delay(2, refresh)
		end
	end)

	for _, key in { "RankLevel", "Coins", "Rebirths" } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	refresh()
end

return RebirthController
