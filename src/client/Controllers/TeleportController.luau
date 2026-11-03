-- TELEPORT button (owner 2026-10-25): jump straight to any zone you have unlocked. Kept apart from the other HUD
-- buttons (owner: don't put them all next to each other): top-right corner, right under the GIFTS button (owner
-- 2026-10-25), on computers and phones. It shows once zone 2 is
-- open (or after a rebirth). Tapping it opens a card per built zone: GO, or the rebirths that open it.
-- UI pass batch 4 (2026-10-29): the window is in the owner's kit look (RewardKit window + cover): a 2 x 2 grid of zone
-- cards, each with a little picture in its zone's two colours, the zone's coin pay, and GO / YOU ARE HERE / locked.
-- Arrival spots: Back Alley = behind your own Back Alley lane; zones 2-4 = their Config.Zones.Gated Arrival (the same
-- spots as the "TAKE ME THERE" button). The server still keeps players out of zones they haven't unlocked (LaneService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local LaneUtil = require(Shared.Modules.LaneUtil)
local Zones = require(Shared.Modules.Zones)
local CoreLadder = require(Shared.Modules.CoreLadder)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))
local HudKit = require(Modules:WaitForChild("HudKit"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local RewardKit = require(Modules:WaitForChild("RewardKit"))

local player = Players.LocalPlayer

local C = UiKit.C
local make = UiKit.Make
local COOLDOWN = 2 -- seconds between teleports
local HERE_RANGE = 140 -- studs: the zone of the nearest lane this close counts as "you are here"

-- Each zone's two colours (ASSET_PROMPTS 7D): alley grey + pink, neon pink + cyan, main street red + royal blue,
-- skyline navy + gold. The first colour rings the card, both paint its picture.
local ZONE_PAINT = {
	[1] = { Color3.fromHex("8C93AE"), Color3.fromHex("FF4FB0") },
	[2] = { Color3.fromHex("FF4FB0"), Color3.fromHex("2BE4FF") },
	[3] = { Color3.fromHex("FF3B3B"), Color3.fromHex("2F5BFF") },
	[4] = { Color3.fromHex("FFC93A"), Color3.fromHex("1A2260") },
}
local FALLBACK_PAINT = { C.Cyan, C.Pink }

local TeleportController = {}

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

-- The zone you're standing in: the zone of the nearest lane (nil in the lobby, far from every lane)
local function hereZone(): number?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end
	local best, bestDistance = nil, HERE_RANGE
	for _, lane in LaneUtil.GetLanes() do
		local start = lane:FindFirstChild("BallStart") :: BasePart?
		if start then
			local distance = (start.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = LaneUtil.ZoneOf(lane), distance
			end
		end
	end
	return best
end

-- The little zone picture: the zone's two colours corner to corner, a lane running up the middle, a pin at its end
local function picture(parent: Instance, zone: number, paint: { Color3 }): Frame
	local tile = make("Frame", {
		Name = "Picture",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(112, 124),
	}, parent) :: Frame
	UiKit.Corner(tile, 12)
	UiKit.Outline(tile, C.Ink, 3)
	make("UIGradient", {
		Color = ColorSequence.new(paint[1], paint[2]),
		Rotation = 55,
	}, tile)
	-- the lane: a dark strip with a lighter centre line, narrowing toward the pin
	local lane = make("Frame", {
		Name = "Lane",
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0, 46, 1, -14),
	}, tile)
	make("UIGradient", {
		Transparency = NumberSequence.new(0.6, 0),
		Rotation = 90,
	}, lane)
	make("Frame", {
		Name = "Line",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(0, 4, 0.7, 0),
	}, lane)
	HudKit.Image(tile, "Pin", 58, {
		Name = "Pin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 42),
		ZIndex = 3,
	})
	local tag = RewardKit.Label(tile, ("ZONE %d"):format(zone), UiKit.Head, 18, C.White, 2.5, 4, 92, 104, 26)
	tag.ZIndex = 4
	make("UIPadding", { PaddingTop = UDim.new(0, 2) }, tag)
	return tile
end

function TeleportController:Start()
	-- Core loop (owner 2026-11-03): back on for today's zones (CoreLadder): shows from Config.CoreLoop.Teleport
	-- ZonesAfterRebirths rebirths, jumps to any opened zone through the server (CoreGoTo "Zone")
	local CORE = Config.CoreLoop.Enabled
	local goRemote = if CORE then ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CoreGoTo") :: RemoteEvent else nil
	local function zonesOpen(): number
		return if CORE
			then CoreLadder.ZonesOpen(player:GetAttribute("CoreZonesOpen"))
			else player:GetAttribute("ZonesOpen") or 1
	end
	local function isOpen(zone: number): boolean
		return if CORE then zone <= zonesOpen() else Zones.Unlocked(zonesOpen(), zone)
	end
	local function zoneName(zone: number): string
		local info = CORE and CoreLadder.ZoneInfo(zone)
		return if info then info.Name else Zones.Name(zone)
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "TeleportUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = hud.IgnoreGuiInset
	gui.Parent = playerGui

	-- ===== The button =====
	-- Cyan portal in the left column under DAILY + PROFILE (owner 2026-10-29; was under GIFTS); the portal turns slowly
	local teleportKit = HudKit.Square(gui, {
		Name = "TeleportButton",
		Paint = "Cyan",
		Icon = "Portal",
		Caption = "TELEPORT",
		CaptionSize = 9,
		Key = "Teleport",
	})
	local openButton = teleportKit.Holder :: TextButton
	openButton.Visible = false
	teleportKit:SetCaption("TELEPORT", nil, nil, 9)
	HudKit.Spin(teleportKit.Slot, 4)

	-- ===== The window: a 2 x 2 grid of zone cards =====
	local W, H = 640, 460
	local CARD_W, CARD_H, GAP = 290, 162, 12
	local windowGui = make("ScreenGui", {
		Name = "TeleportWindowUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 12,
	}, playerGui) :: ScreenGui
	local win = RewardKit.Window(windowGui, W, H)
	local cover, closeX = RewardKit.Cover(win.Panel, W, H, "TELEPORT", "JUMP TO ANY ZONE YOU HAVE OPENED", if UiKit.V2 then C.Gold else C.Cyan)
	closeX.Activated:Connect(function()
		win:Close()
	end)

	local lastTeleport = 0
	local function teleport(zone: number)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 or os.clock() - lastTeleport < COOLDOWN then
			return
		end
		if not isOpen(zone) then
			return
		end
		-- No teleporting out of the Pin Titan fight (BossService brings you back to the roof after it)
		if player:GetAttribute("BossFighting") then
			return
		end
		if goRemote then
			lastTeleport = os.clock()
			goRemote:FireServer("Zone", zone)
			win:Close()
			UiFx.Flash((ZONE_PAINT[zone] or FALLBACK_PAINT)[1], 0.6, 0.4)
			Sfx.Play("Teleport")
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
		win:Close()
		UiFx.Flash((ZONE_PAINT[zone] or FALLBACK_PAINT)[1], 0.6, 0.4)
		Sfx.Play("Teleport")
	end

	local cards = {}
	local built = math.min(if CORE then CoreLadder.ZoneCount() else Config.Zones.BuiltZones, 4) -- the grid holds four
	for zone = 1, built do
		local paint = ZONE_PAINT[zone] or FALLBACK_PAINT
		local col, row = (zone - 1) % 2, (zone - 1) // 2
		local block = UiKit.Block(cover, {
			Name = "Zone" .. zone,
			Size = Vector2.new(CARD_W, CARD_H),
			Fill = C.Card,
			Lip = C.Page,
			LipPx = 6,
			Radius = 18,
			Outline = 3,
			Ring = paint[1],
		})
		block.Holder.Position = UDim2.fromOffset(24 + col * (CARD_W + GAP), 98 + row * (CARD_H + GAP))
		local face = block.Face
		local ring = face:FindFirstChild("Ring") :: Frame
		local ringStroke = ring:FindFirstChildOfClass("UIStroke") :: UIStroke
		local tile = picture(face, zone, paint)

		-- Locked: the picture goes dark under a lock
		local shade = make("Frame", {
			Name = "Shade",
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 5,
			Visible = false,
		}, tile)
		UiKit.Corner(shade, 12)
		HudKit.Image(shade, "Lock", 54, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.42),
			ZIndex = 6,
		})

		local name = RewardKit.Label(face, zoneName(zone):upper(), UiKit.Head, 24, C.White, 2.5, 132, 10, 146, 54)
		name.TextWrapped = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		RewardKit.Fit(name, 24, 140, 54)

		-- Coin pay chip: "x4 COINS" with a coin
		local chip = UiKit.Block(face, {
			Name = "Pay",
			Size = Vector2.new(146, 34),
			Fill = C.Cover,
			Lip = C.Ink,
			LipPx = 4,
			Radius = 17,
			Outline = 2,
		})
		chip.Holder.Position = UDim2.fromOffset(132, 64)
		HudKit.Image(chip.Face, "Coin", 22, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 8, 0.5, 0),
		})
		local pay = RewardKit.Label(
			chip.Face,
			("%s COINS"):format(
				Currency.FormatMultiplier(if CORE then CoreLadder.ZoneValue(zone) else Zones.CoinPay(zone))
			),
			UiKit.Head,
			18,
			C.Gold,
			2,
			34,
			2,
			106,
			26
		)
		pay.TextXAlignment = Enum.TextXAlignment.Left

		local go = RewardKit.Button(face, "GO", "Lime", 146, 46, 26)
		go.Holder.Position = UDim2.fromOffset(132, 102)
		go.Activated:Connect(function()
			local card = cards[zone]
			if card.State == "Open" then
				teleport(zone)
			elseif card.State == "Locked" then
				go:Shake()
			end
		end)
		cards[zone] = {
			Go = go,
			Shade = shade,
			Pin = tile:FindFirstChild("Pin") :: ImageLabel,
			Ring = ringStroke,
			Paint = paint,
			Name = name,
			State = "",
		}
	end

	local function refresh()
		openButton.Visible = if CORE
			then (player:GetAttribute("Rebirths") or 0) >= (Config.CoreLoop.Teleport.ZonesAfterRebirths or 1)
			else zonesOpen() >= 2
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local here = if CORE then (if root then CoreLadder.ZoneAt(root.Position) else nil) else hereZone()
		for zone, card in cards do
			local open = isOpen(zone)
			local state = if not open then "Locked" elseif zone == here then "Here" else "Open"
			card.State = state
			card.Shade.Visible = not open
			card.Pin.Visible = open -- the lock takes its place
			card.Ring.Color = if open then card.Paint[1] else C.Grey
			card.Name.TextColor3 = if open then C.White else C.LockedText
			local go = card.Go
			go:SetIcon(nil)
			if state == "Open" then
				go:Paint(C.Lime, C.LimeLip, C.White)
				go:SetText("GO!")
			elseif state == "Here" then
				go:Paint(C.Chip, C.Ink, C.Cyan)
				go:SetText("YOU ARE HERE")
			else
				go:Paint(C.Grey, C.GreyLip, C.LockedText)
				go:SetText(if CORE then "OPEN AT GATE" else Zones.NeedText(zone))
			end
			go:SetPressable(state ~= "Here")
		end
	end

	local function open()
		refresh()
		win:Open()
		local holders = {}
		for zone = 1, built do
			table.insert(holders, cover:FindFirstChild("Zone" .. zone) :: GuiObject)
		end
		RewardKit.Stagger(holders, 0.05, 0.1)
	end

	openButton.Activated:Connect(function()
		if win:IsOpen() then
			win:Close()
		else
			open()
		end
	end)
	for _, key in { "ZonesOpen", "CoreZonesOpen", "Rebirths" } do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	refresh()
end

return TeleportController
