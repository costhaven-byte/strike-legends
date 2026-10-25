-- TELEPORT button (owner 2026-10-25): jump straight to any zone you have unlocked. Kept apart from the other HUD
-- buttons (owner: don't put them all next to each other): top-right corner, right under the GIFTS button (owner
-- 2026-10-25), on computers and phones. It shows once zone 2 is
-- open (or after a rebirth). Tapping it opens a card per built zone: GO, or the level that opens it.
-- Arrival spots: Back Alley = behind your own Back Alley lane; zones 2-4 = their Config.Zones.Gated Arrival (the same
-- spots as the "TAKE ME THERE" button). The server still keeps players out of zones they haven't unlocked (LaneService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))

local player = Players.LocalPlayer

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local CAPTION_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("06060F")
local CARD = Color3.fromRGB(30, 20, 60)
local PANEL = Color3.fromRGB(18, 12, 38)
local CYAN = Color3.fromRGB(60, 220, 255)
local LIME = Color3.fromRGB(125, 255, 60)
local GREY = Color3.fromRGB(120, 110, 150)
local SOFT = Color3.fromRGB(200, 190, 230)
local GAP = 10 -- pixels between the GIFTS button and this one
local COOLDOWN = 2 -- seconds between teleports

-- Each zone's colour on its card (zones 2-4 use their lock wall colour)
local ZONE_COLORS = { [1] = Color3.fromRGB(60, 200, 255) }
for _, gate in Config.Zones.Gated do
	ZONE_COLORS[gate.Zone] = gate.WallColor
end

local TeleportController = {}

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

-- The icon: a portal (rings inside a ring)
local function portalIcon(parent: Instance, position: UDim2, size: number)
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = position
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent
	for i, scale in { 1, 0.62, 0.26 } do
		local ring = Instance.new("Frame")
		ring.Name = "Ring" .. i
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(scale, scale)
		ring.BackgroundColor3 = CYAN
		ring.BackgroundTransparency = if i == 3 then 0 else 1
		ring.Parent = holder
		corner(ring)
		if i < 3 then
			stroke(ring, CYAN, if i == 1 then 3 else 2, true)
		end
	end
end

-- Where a zone's teleport lands, facing the pins
local function arrival(zone: number): CFrame?
	if zone == 1 then
		-- Behind your own Back Alley lane
		for _, lane in LaneUtil.GetLanes() do
			local start = lane:FindFirstChild("BallStart") :: BasePart?
			if start and lane:GetAttribute("OwnerId") == player.UserId and LaneUtil.ZoneOf(lane) == 1 then
				local forward = start.CFrame.LookVector
				local spot = start.Position - forward * 4 + Vector3.new(0, 3, 0)
				return CFrame.lookAt(spot, spot + forward)
			end
		end
		local gate = Config.Zones.Gated[1]
		return gate and CFrame.new(gate.KickTo) -- just outside the lobby door
	end
	for _, gate in Config.Zones.Gated do
		if gate.Zone == zone then
			return CFrame.lookAt(gate.Arrival, gate.Arrival - Vector3.zAxis)
		end
	end
	return nil
end

function TeleportController:Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local rankBar = hud:WaitForChild("RankBar") :: GuiObject

	local gui = Instance.new("ScreenGui")
	gui.Name = "TeleportUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = hud.IgnoreGuiInset
	gui.Parent = playerGui

	-- ===== The button =====
	local openButton = Instance.new("TextButton")
	openButton.Name = "TeleportButton"
	openButton.Text = ""
	openButton.AutoButtonColor = false
	openButton.BackgroundColor3 = CARD
	openButton.BackgroundTransparency = 0.1
	openButton.Visible = false
	openButton.Parent = gui
	corner(openButton, 12)
	stroke(openButton, CYAN, 3, true)
	local caption = text(openButton, "Caption", CAPTION_FONT, CYAN, UDim2.new(0, 3, 1, -17), UDim2.new(1, -6, 0, 13))
	caption.Text = "TELEPORT"
	portalIcon(openButton, UDim2.new(0.5, 0, 0, 21), 26)
	UiFx.Press(openButton)

	local function place()
		local compact = hud.AbsoluteSize.Y > 0 and hud.AbsoluteSize.Y < Config.Ui.CompactHeight
		-- Under the GIFTS button in the top-right corner (owner 2026-10-25), right edges lined up
		openButton.AnchorPoint = Vector2.new(1, 0)
		if compact then
			-- Phones: GIFTS is at (right 8, top 4), 56 tall
			openButton.Size = UDim2.fromOffset(44, 46)
			openButton.Position = UDim2.new(1, -8, 0, 4 + 56 + GAP)
		else
			-- Computers: GIFTS is at (right 10, top 6), 56 tall
			openButton.Size = UDim2.fromOffset(55, 56)
			openButton.Position = UDim2.new(1, -10, 0, 6 + 56 + GAP)
		end
	end
	rankBar:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	-- ===== The window: one card per built zone =====
	local built = Config.Zones.BuiltZones
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.53)
	panel.Size = UDim2.fromOffset(32 + built * 148, 270)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Active = true
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, CYAN, 4, true)

	local title = text(panel, "Title", FONT, Color3.new(1, 1, 1), UDim2.new(0, 20, 0, 12), UDim2.new(1, -80, 0, 38))
	title.Text = "TELEPORT"
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

	local list = Instance.new("Frame")
	list.Name = "Zones"
	list.BackgroundTransparency = 1
	list.Position = UDim2.new(0, 16, 0, 64)
	list.Size = UDim2.new(1, -32, 1, -80)
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local lastTeleport = 0
	local cards = {}
	local function teleport(zone: number)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 or os.clock() - lastTeleport < COOLDOWN then
			return
		end
		if not Zones.Unlocked(player:GetAttribute("RankLevel"), zone) then
			return
		end
		local spot = arrival(zone)
		if not spot then
			return
		end
		lastTeleport = os.clock()
		if humanoid.Sit then
			humanoid.Sit = false
		end
		character:PivotTo(spot)
		root.AssemblyLinearVelocity = Vector3.zero
		UiFx.Close(panel)
		UiFx.Flash(ZONE_COLORS[zone] or CYAN, 0.6, 0.4)
		Sfx.Play("Reveal", 1)
	end

	for zone = 1, built do
		local color = ZONE_COLORS[zone] or CYAN
		local card = Instance.new("Frame")
		card.Name = "Zone" .. zone
		card.LayoutOrder = zone
		card.BackgroundColor3 = CARD
		card.Size = UDim2.new(1 / built, -8 * (built - 1) / built, 1, 0)
		card.Parent = list
		corner(card, 12)
		local cardStroke = stroke(card, color, 3, true)
		local strip = Instance.new("Frame")
		strip.Name = "Strip"
		strip.BackgroundColor3 = color
		strip.BorderSizePixel = 0
		strip.Size = UDim2.new(1, 0, 0, 10)
		strip.Parent = card
		corner(strip, 12)
		local number = text(card, "Number", FONT, color, UDim2.new(0, 8, 0, 18), UDim2.new(1, -16, 0, 26))
		number.Text = ("ZONE %d"):format(zone)
		local name = text(card, "ZoneName", FONT, Color3.new(1, 1, 1), UDim2.new(0, 8, 0, 48), UDim2.new(1, -16, 0, 44))
		name.Text = Zones.Name(zone):upper()
		local need = text(card, "Need", BODY_FONT, SOFT, UDim2.new(0, 8, 0, 98), UDim2.new(1, -16, 0, 16))
		local go = Instance.new("TextButton")
		go.Name = "Go"
		go.FontFace = FONT
		go.TextScaled = true
		go.TextColor3 = INK
		go.AutoButtonColor = false
		go.AnchorPoint = Vector2.new(0.5, 1)
		go.Position = UDim2.new(0.5, 0, 1, -10)
		go.Size = UDim2.new(1, -20, 0, 44)
		go.Parent = card
		corner(go, 10)
		stroke(go, INK, 2, true)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 6)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.Parent = go
		UiFx.Press(go)
		go.Activated:Connect(function()
			teleport(zone)
		end)
		cards[zone] = { Go = go, Need = need, Stroke = cardStroke, Color = color }
	end

	local function refresh()
		local level = player:GetAttribute("RankLevel") or 1
		openButton.Visible = (player:GetAttribute("Rebirths") or 0) > 0 or Zones.Unlocked(level, 2)
		for zone, card in cards do
			local open = Zones.Unlocked(level, zone)
			card.Go.Text = if open then "GO" else "LOCKED"
			card.Go.BackgroundColor3 = if open then LIME else GREY
			card.Need.Text = if zone == 1 then "YOUR LANE" else ("LEVEL %d"):format(Zones.UnlockLevel(zone))
			card.Stroke.Color = if open then card.Color else GREY
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
	for _, key in { "RankLevel", "Rebirths" } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	refresh()
end

return TeleportController
