-- The owner's HUD Kit (claude.ai/design 'Strike Legends HUD Kit', 2026-10-26): colours, fonts, icons, the chunky
-- lip-and-face button every HUD button uses, and where each HUD piece sits on a computer and on a phone.
-- Positions are the design's own pixels: x, y from the top-left of a 1920x1080 computer screen or an 844x390 phone
-- (y includes Roblox's top bar, 56 px on the computer mockup and 36 px on the phone one). Each piece also says which
-- screen edge it hangs from, so it stays in its corner on other screen sizes.
-- Roblox has no Gotham Black; Gotham SSm Black stands in. Text outlines are UIStrokes at half the design's CSS
-- stroke (CSS strokes are centred on the letter edge).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetSlots = require(Shared.AssetSlots)
local Sfx = require(script.Parent:WaitForChild("Sfx"))

local player = Players.LocalPlayer

local HudKit = {}

-- UI overhaul V2 (UI_OVERHAUL_PLAN.md step V2, Config.Ui.HudV2): the owner's new HUD ('Strike Legends UI.html' B1 +
-- B2): new spots (V2_LAYOUT below) and navy tile buttons with the new icons (HudKit.Square). Other screens keep
-- the kit as it was.
local V2 = Config.Ui.HudV2 == true
HudKit.V2 = V2
local SlKit = if V2 then require(script.Parent:WaitForChild("SlKit")) else nil

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

-- Every colour in the kit. Button colours come in pairs: the face and the darker lip under it.
HudKit.C = {
	Panel = hex("070B1E"),
	Card = hex("1E143C"),
	CardLip = hex("120B26"),
	Ink = hex("04061A"),
	Divider = hex("2C2154"),
	Gold = hex("FFC93A"),
	GoldLip = hex("C98A00"),
	Cyan = hex("2BE4FF"),
	CyanLip = hex("0A9BC2"),
	Pink = hex("FF4FB0"),
	PinkLip = hex("C21F7A"),
	Lime = hex("7DFF3C"),
	LimeLip = hex("3DB80F"),
	Red = hex("FF2D4A"),
	RedLip = hex("B3122A"),
	Grey = hex("6B6F86"),
	GreyLip = hex("44475A"),
	Purple = hex("A855F7"),
	PurpleLip = hex("7A2FD0"),
	White = Color3.new(1, 1, 1),
}
local C = HudKit.C

-- Face/lip pairs by name
HudKit.Paints = {
	Cyan = { C.Cyan, C.CyanLip },
	Pink = { C.Pink, C.PinkLip },
	Gold = { C.Gold, C.GoldLip },
	Lime = { C.Lime, C.LimeLip },
	Red = { C.Red, C.RedLip },
	Grey = { C.Grey, C.GreyLip },
	Card = { C.Card, C.CardLip },
	Purple = { C.Purple, C.PurpleLip },
}

HudKit.Head = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
HudKit.Num = Font.new("rbxasset://fonts/families/FredokaOne.json")
HudKit.Body = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

-- Addendum 4 Stage 3d (Config.Ui.Sunny): the sunny palette and two fonts replace the night kit. Same names, so every
-- screen built with the kit follows. Buttons: sky / coral / green / yellow; panels and cards cream / sand; no white
-- shine band.
local SUNNY = Config.Ui.Sunny == true
HudKit.Sunny = SUNNY
if SUNNY then
	local SunKit = require(script.Parent:WaitForChild("SunKit"))
	local S = SunKit.C
	C.Panel = S.Cream -- (3d-2: windows cream with dark text, SunKit.Daylight)
	C.Card = S.Sand
	C.CardLip = S.CreamLip
	C.Ink = S.Ink
	C.Divider = S.CreamLip
	C.Gold, C.GoldLip = S.Sun, S.SunLip
	C.Cyan, C.CyanLip = S.Sky, S.SkyLip
	C.Pink, C.PinkLip = S.Coral, S.CoralLip
	C.Lime, C.LimeLip = S.Green, S.GreenLip
	C.Red, C.RedLip = S.Red, S.RedLip
	C.Grey, C.GreyLip = S.Grey, S.GreyLip
	C.Purple, C.PurpleLip = S.Purple, S.PurpleLip
	C.Cream, C.CreamLip = S.Cream, S.CreamLip
	for name, pair in HudKit.Paints do
		pair[1], pair[2] = C[name], C[if name == "Card" then "CardLip" else name .. "Lip"]
	end
	HudKit.Paints.Cream = { C.Cream, C.CreamLip }
	HudKit.Head = SunKit.Display
	HudKit.Num = SunKit.Display
	HudKit.Body = SunKit.Body
end

-- "Coin" -> the HudCoin image (AssetSlots.Images)
function HudKit.Icon(name: string): string
	return AssetSlots.Image("Hud" .. name)
end

-- ===== Where everything goes =====
local SCREENS = {
	Pc = { W = 1920, H = 1080, Bar = 56 },
	Phone = { W = 844, H = 390, Bar = 36 },
}
-- Key -> { Pc = { x, y, w, h, edgeX, edgeY }, Phone = { ... } }. edgeX: "L" left, "R" right, "C" centre;
-- edgeY: "T" top, "B" bottom, "M" = the right-hand column (streak, lane event, goal): at its design spot on a
-- 1080-tall screen, moved up as much as a shorter screen needs, but never above MinTop (under SETTINGS).
-- w/h nil = the piece sizes itself.
HudKit.Layout = {
	Boosts = { Pc = { 32, 72, nil, nil, "L", "T" }, Phone = { 12, 42, nil, nil, "L", "T" } },
	Coins = { Pc = { 22, 124, 240, 68, "L", "T" }, Phone = { 8, 89, 118, 40, "L", "T" } },
	-- The xN badge is hidden (Config.Ui.MultiplierBadge, owner 2026-10-28); its spot still places AUTO under it
	Multiplier = { Pc = { 272, 136, 96, 44, "L", "T" }, Phone = { 132, 92, 60, 34, "L", "T" } },
	-- Coins per minute (polish P1, not in the kit): a green line under the coin pill; the column under it moved
	-- down to make room (computer +24, phone +14)
	Income = { Pc = { 40, 186, 220, 26, "L", "T" }, Phone = { 14, 126, 120, 16, "L", "T" } },
	-- Phones: GEMS sits right next to the coins (owner 2026-10-28, took the xN badge's place)
	Gems = { Pc = { 24, 220, 170, 58, "L", "T" }, Phone = { 132, 91, 70, 36, "L", "T" } },
	Balls = { Pc = { 32, 290, 56, 56, "L", "T" }, Phone = { 12, 148, 44, 46, "L", "T" } },
	Pets = { Pc = { 100, 290, 56, 56, "L", "T" }, Phone = { 62, 148, 44, 46, "L", "T" } },
	Store = { Pc = { 168, 290, 56, 56, "L", "T" }, Phone = { 112, 148, 44, 46, "L", "T" } },
	-- Phones: POWER under BALLS/PETS/STORE, as wide as that row (owner 2026-10-28; PROFILE lives in MORE there)
	Power = { Pc = { 32, 362, 176, 66, "L", "T" }, Phone = { 12, 200, 144, 46, "L", "T" } },
	Daily = { Pc = { 32, 444, 56, 56, "L", "T" }, Phone = { 736, 40, 44, 46, "R", "T" } },
	-- PROFILE (polish P5, not in the kit): right of DAILY on computers, under BALLS on phones
	Profile = { Pc = { 100, 444, 56, 56, "L", "T" }, Phone = { 12, 200, 44, 46, "L", "T" } },
	-- PASSES (Addendum 6 Stage 8, not in the kit): right of PROFILE on computers, right of STORE on phones
	Passes = { Pc = { 168, 444, 56, 56, "L", "T" }, Phone = { 162, 148, 44, 46, "L", "T" } },
	Breakdown = { Pc = { 272, 190, 330, nil, "L", "T" }, Phone = { 272, 50, 300, nil, "C", "T" } },
	-- Level bar + REBIRTH sit in the strip at the very top (next to Roblox's own buttons), so the boss pill fits under them
	LevelBar = { Pc = { 650, 14, 620, 52, "C", "T" }, Phone = { 262, 6, 320, 34, "C", "T" } },
	Rebirth = { Pc = { 1290, 12, 56, 56, "C", "T" }, Phone = { 592, 2, 44, 46, "C", "T" } },
	-- Addendum 5 step C: the core loop's big gold REBIRTH button takes the hidden POWER LV's spot
	CoreRebirth = { Pc = { 32, 362, 176, 66, "L", "T" }, Phone = { 12, 200, 144, 52, "L", "T" } }, -- (phone 52 tall: the x1 > x2 line clears the bar)
	AfterThrow = { Pc = { 660, 140, 600, 30, "C", "T" }, Phone = { 272, 84, 300, 18, "C", "T" } },
	Gifts = { Pc = { 1832, 72, 56, 56, "R", "T" }, Phone = { 788, 40, 44, 46, "R", "T" } },
	-- SETTINGS (grey, owner 2026-10-29) under GIFTS; TELEPORT moved to the left column under DAILY + PROFILE
	Settings = { Pc = { 1832, 146, 56, 56, "R", "T" }, Phone = { 788, 94, 44, 46, "R", "T" } },
	Teleport = { Pc = { 32, 516, 56, 56, "L", "T" }, Phone = { 788, 94, 44, 46, "R", "T" } },
	-- MORE (phones only, Config.Ui.PhoneMenu): DAILY, GIFTS, TELEPORT, PROFILE and SETTINGS fold into it; they open in a column under it
	More = { Pc = { 1832, 72, 56, 56, "R", "T" }, Phone = { 788, 40, 44, 46, "R", "T" } },
	-- Rank Trial (not in the kit): right of the multiplier badge on computers, under the goal bar on phones
	Trial = { Pc = { 380, 136, 300, 38, "L", "T" }, Phone = { 640, 224, 140, 40, "R", "T" } },
	TrialTracker = { Pc = { 380, 136, 260, 116, "L", "T" }, Phone = { 640, 224, 140, 40, "R", "T" } },
	Streak = { Pc = { 1768, 400, 120, 120, "R", "M" }, Phone = { 640, 94, 140, 46, "R", "T" } },
	Modifier = { Pc = { 1658, 538, 230, 42, "R", "M" }, Phone = { 656, 148, 176, 30, "R", "T" } },
	Goal = { Pc = { 1640, 594, 248, 54, "R", "M" }, Phone = { 662, 184, 170, 36, "R", "T" } },
	MinTop = 218, -- (computer) the right-hand column never goes above this (under SETTINGS)
	Potions = { Pc = { 32, 996, nil, 52, "L", "B" }, Phone = { 500, 340, nil, 38, "C", "B" } },
	Hold = { Pc = { 880, 984, 160, 50, "C", "B" }, Phone = { 356, 332, 132, 46, "C", "B" } },
	-- Addendum 4 core loop (CoreHudController): pin counter under the level bar, bag bar + SELL bottom-left,
	-- the BAG FULL prompt over the middle
	PinCounter = { Pc = { 830, 76, 260, 64, "C", "T" }, Phone = { 377, 44, 90, 34, "C", "T" } },
	Bag = { Pc = { 32, 896, 300, 64, "L", "B" }, Phone = { 12, 294, 168, 40, "L", "B" } },
	Sell = { Pc = { 344, 896, 132, 64, "L", "B" }, Phone = { 186, 294, 74, 40, "L", "B" } },
	BagFull = { Pc = { 700, 160, 520, 66, "C", "T" }, Phone = { 297, 84, 250, 40, "C", "T" } },
}

-- V2 spots, measured off the owner's B1 (computer 1920x1080) and B2 (phone 844x390) mockups. Coins + gems
-- top-left with the xN chip on the coin pill's corner; a 2-wide button grid (3-wide on phones) with REBIRTH under
-- it; GIFTS / SETTINGS / PASSES top-right; PINS DOWN top-centre; NEXT GOAL card on the right; potions, bag + SELL
-- bottom-left; THROW bottom-centre (bottom-right on phones). Phones show every button (no MORE menu).
local V2_LAYOUT = {
	Boosts = { Pc = { 372, 82, nil, nil, "L", "T" }, Phone = { 222, 92, nil, nil, "L", "T" } }, -- (quick-buy pills, not in the design: right of the coins)
	Coins = { Pc = { 28, 72, 320, 70, "L", "T" }, Phone = { 40, 44, 166, 44, "L", "T" } },
	Multiplier = { Pc = { 256, 56, 100, 46, "L", "T" }, Phone = { 148, 33, 64, 28, "L", "T" } },
	Income = { Pc = { 106, 112, 200, 22, "L", "T" }, Phone = { 82, 70, 110, 14, "L", "T" } },
	Gems = { Pc = { 28, 156, 270, 60, "L", "T" }, Phone = { 218, 46, 112, 40, "L", "T" } },
	Balls = { Pc = { 24, 244, 96, 96, "L", "T" }, Phone = { 40, 104, 46, 46, "L", "T" } },
	Pets = { Pc = { 140, 244, 96, 96, "L", "T" }, Phone = { 100, 104, 46, 46, "L", "T" } },
	Store = { Pc = { 24, 364, 96, 96, "L", "T" }, Phone = { 160, 104, 46, 46, "L", "T" } },
	Daily = { Pc = { 140, 364, 96, 96, "L", "T" }, Phone = { 40, 166, 46, 46, "L", "T" } },
	Profile = { Pc = { 24, 484, 96, 96, "L", "T" }, Phone = { 100, 166, 46, 46, "L", "T" } },
	Teleport = { Pc = { 140, 484, 96, 96, "L", "T" }, Phone = { 160, 166, 46, 46, "L", "T" } },
	Power = { Pc = { 24, 620, 212, 88, "L", "T" }, Phone = { 40, 228, 166, 46, "L", "T" } },
	CoreRebirth = { Pc = { 24, 620, 212, 88, "L", "T" }, Phone = { 40, 228, 166, 46, "L", "T" } },
	Gifts = { Pc = { 1616, 24, 80, 80, "R", "T" }, Phone = { 672, 40, 44, 44, "R", "T" } },
	Settings = { Pc = { 1716, 24, 80, 80, "R", "T" }, Phone = { 728, 40, 44, 44, "R", "T" } },
	Passes = { Pc = { 1816, 24, 80, 80, "R", "T" }, Phone = { 784, 40, 44, 44, "R", "T" } },
	More = { Pc = { 1816, 24, 80, 80, "R", "T" }, Phone = { 784, 40, 44, 44, "R", "T" } },
	PinCounter = { Pc = { 840, 14, 240, 80, "C", "T" }, Phone = { 372, 38, 100, 46, "C", "T" } },
	Goal = { Pc = { 1610, 300, 286, 320, "R", "T" }, Phone = { 672, 100, 156, 136, "R", "T" } },
	Modifier = { Pc = { 1650, 236, 246, 42, "R", "T" }, Phone = { 652, 242, 176, 30, "R", "T" } },
	Streak = { Pc = { 1776, 640, 120, 120, "R", "T" }, Phone = { 688, 242, 140, 46, "R", "T" } },
	Potions = { Pc = { 24, 864, nil, 80, "L", "B" }, Phone = { 218, 276, nil, 48, "L", "B" } },
	Bag = { Pc = { 28, 956, 440, 96, "L", "B" }, Phone = { 218, 330, 212, 46, "L", "B" } },
	Sell = { Pc = { 474, 956, 200, 96, "L", "B" }, Phone = { 436, 326, 108, 50, "L", "B" } },
	Hold = { Pc = { 790, 928, 340, 120, "C", "B" }, Phone = { 676, 310, 152, 66, "R", "B" } },
}
-- Polish v2 U1 (Config.Ui.ShopButton = false): no SHOP button, so the grid closes up from the top-left and the
-- PASSES button joins the grid (TELEPORT last, as it hides until zone 2); GIFTS + SETTINGS slide right into the corner it left
local NO_SHOP_LAYOUT = {
	Pets = { Pc = { 24, 244, 96, 96, "L", "T" }, Phone = { 40, 104, 46, 46, "L", "T" } },
	Store = { Pc = { 140, 244, 96, 96, "L", "T" }, Phone = { 100, 104, 46, 46, "L", "T" } },
	Daily = { Pc = { 24, 364, 96, 96, "L", "T" }, Phone = { 160, 104, 46, 46, "L", "T" } },
	Profile = { Pc = { 140, 364, 96, 96, "L", "T" }, Phone = { 40, 166, 46, 46, "L", "T" } },
	Passes = { Pc = { 24, 484, 96, 96, "L", "T" }, Phone = { 100, 166, 46, 46, "L", "T" } },
	Teleport = { Pc = { 140, 484, 96, 96, "L", "T" }, Phone = { 160, 166, 46, 46, "L", "T" } }, -- (last: hidden until zone 2)
	Gifts = { Pc = { 1716, 24, 80, 80, "R", "T" }, Phone = { 728, 40, 44, 44, "R", "T" } },
	Settings = { Pc = { 1816, 24, 80, 80, "R", "T" }, Phone = { 784, 40, 44, 44, "R", "T" } },
}
if V2 then
	for key, row in V2_LAYOUT do
		HudKit.Layout[key] = row
	end
	if Config.Ui.ShopButton == false and Config.CoreLoop.Enabled then
		for key, row in NO_SHOP_LAYOUT do
			HudKit.Layout[key] = row
		end
	end
end

-- Phones held sideways (short screens) get the phone layout
local hudGui: ScreenGui? = nil
local function hud(): ScreenGui
	if not hudGui then
		hudGui = player:WaitForChild("PlayerGui"):WaitForChild("HUD") :: ScreenGui
	end
	return hudGui :: ScreenGui
end

function HudKit.Phone(): boolean
	local size = hud().AbsoluteSize
	return size.Y > 0 and size.Y < Config.Ui.CompactHeight
end

-- ===== V2: shorter computer screens =====
-- The V2 computer HUD is drawn for a 1080-tall screen. On a shorter one (a laptop, a small window) every HUD layer
-- shrinks by the same amount (a UIScale "HudFit" on the ScreenGui), so it all still fits and keeps to its corners.
-- Phones have their own layout (scale 1). Layers that also hold big windows (pets, profile, gifts) don't shrink:
-- their HUD buttons live in the shared HudV2Layer instead, and the SHOP button frame scales on its own.
local FIT_GUIS = {
	HUD = true,
	CoreHUD = true,
	StoreUI = true,
	DailyUI = true,
	SettingsUI = true,
	PassesButtonUI = true,
	RebirthUI = true,
	PotionUI = true,
	ThrowUI = true,
	EventUI = true,
	TeleportUI = true,
	HudV2Layer = true,
}
local FIT_MIN = 0.5

-- How much the HUD is shrunk right now (1 = the design's size)
function HudKit.HudScale(): number
	if not V2 or HudKit.Phone() then
		return 1
	end
	local height = hud().AbsoluteSize.Y
	local designHeight = SCREENS.Pc.H - SCREENS.Pc.Bar
	return if height > 0 then math.clamp(height / designHeight, FIT_MIN, 1) else 1
end

local fitScales: { UIScale } = {}
local function fitGui(gui: Instance)
	if not (gui:IsA("ScreenGui") and FIT_GUIS[gui.Name]) or gui:FindFirstChild("HudFit") then
		return
	end
	local scale = Instance.new("UIScale")
	scale.Name = "HudFit"
	scale.Scale = HudKit.HudScale()
	scale.Parent = gui
	table.insert(fitScales, scale)
end
local fitStarted = false
local function startFit()
	if fitStarted or not V2 then
		return
	end
	fitStarted = true
	task.spawn(function()
		local playerGui = player:WaitForChild("PlayerGui")
		for _, gui in playerGui:GetChildren() do
			fitGui(gui)
		end
		playerGui.ChildAdded:Connect(fitGui)
		hud():GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			task.defer(function()
				local value = HudKit.HudScale()
				for _, scale in fitScales do
					scale.Scale = value
				end
			end)
		end)
	end)
end

-- The shrink a HUD piece's own layer has (to turn screen pixels into that layer's pixels)
function HudKit.LayerScale(object: Instance): number
	local gui = object:FindFirstAncestorOfClass("ScreenGui")
	local scale = gui and gui:FindFirstChild("HudFit") :: UIScale?
	return if scale then scale.Scale else 1
end

-- The shared layer for V2 HUD buttons whose own ScreenGui also holds a window
local layerGui: ScreenGui? = nil
function HudKit.Layer(): ScreenGui
	if not layerGui then
		local gui = Instance.new("ScreenGui")
		gui.Name = "HudV2Layer"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 5
		gui.IgnoreGuiInset = hud().IgnoreGuiInset
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.Parent = player:WaitForChild("PlayerGui")
		layerGui = gui
		startFit()
	end
	return layerGui :: ScreenGui
end

-- A HUD piece in a layer that doesn't shrink (the SHOP button frame): it shrinks itself, from its corner spot
function HudKit.FitFrame(object: GuiObject, key: string)
	if not V2 then
		return
	end
	local scale = (object:FindFirstChild("HudFit") or Instance.new("UIScale")) :: UIScale
	scale.Name = "HudFit"
	scale.Parent = object
	local function place()
		local fit = HudKit.HudScale()
		local position = HudKit.Spot(key)
		object.Position =
			UDim2.new(position.X.Scale, position.X.Offset * fit, position.Y.Scale, position.Y.Offset * fit)
		scale.Scale = fit
	end
	place()
	hud():GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(place)
	end)
end

-- Calls fn(phone) now and every time the screen switches between the computer and phone layouts
function HudKit.OnLayout(fn: (boolean) -> ())
	startFit()
	local last = HudKit.Phone()
	fn(last)
	hud():GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local phone = HudKit.Phone()
		if phone ~= last then
			last = phone
			task.defer(fn, phone) -- not inside the size event, so the resizes it makes don't nest
		end
	end)
end

-- The right-hand column: the design's y, less what a shorter screen lacks, but not above MinTop
local function columnTop(y: number, screen): number
	local designHeight = screen.H - screen.Bar
	local height = hud().AbsoluteSize.Y
	local short = if height > 0 then math.max(designHeight - height, 0) else 0
	local lift = math.min(short, HudKit.Layout.Streak.Pc[2] - HudKit.Layout.MinTop)
	return y - screen.Bar - lift
end

-- The spot for a key on this screen: (position, size or nil, raw row). Positions are for a ScreenGui that keeps
-- Roblox's top-bar inset (IgnoreGuiInset = false), like the HUD.
function HudKit.Spot(key: string, phone: boolean?): (UDim2, UDim2?, { any })
	if phone == nil then
		phone = HudKit.Phone()
	end
	local screen = if phone then SCREENS.Phone else SCREENS.Pc
	local row = HudKit.Layout[key][if phone then "Phone" else "Pc"]
	if phone and HudKit.InMenu(key) then
		-- Folded into MORE: waits just past the right edge, on the MORE button's line, until the menu opens
		local more = HudKit.Layout.More.Phone
		return UDim2.new(1, 30, 0, more[2] - screen.Bar), UDim2.fromOffset(row[3], row[4]), row
	end
	local x, y, w, h, edgeX, edgeY = row[1], row[2], row[3], row[4], row[5], row[6]
	local px = if edgeX == "R"
		then UDim.new(1, x - screen.W)
		elseif edgeX == "C" then UDim.new(0.5, x - screen.W / 2)
		else UDim.new(0, x)
	local py = if edgeY == "B"
		then UDim.new(1, y - screen.H)
		elseif edgeY == "M" then UDim.new(0, columnTop(y, screen))
		else UDim.new(0, y - screen.Bar)
	local size = if w and h then UDim2.fromOffset(w, h) else nil
	return UDim2.new(px, py), size, row
end

-- Keeps an object on its spot (and at its size, when the layout gives one) on both layouts. The right-hand
-- column also follows every screen resize.
function HudKit.Place(object: GuiObject, key: string, keepSize: boolean?)
	local function place(phone: boolean)
		local position, size = HudKit.Spot(key, phone)
		object.AnchorPoint = Vector2.zero
		object.Position = position
		if size and not keepSize then
			object.Size = size
		end
	end
	HudKit.OnLayout(place)
	HudKit.Tuckable(object, key)
	if HudKit.Layout[key].Pc[6] == "M" then
		hud():GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			task.defer(place, HudKit.Phone())
		end)
	end
end

-- ===== Tuck while bowling (owner 2026-10-28: on phones the HUD hid the lane) =====
-- While you bowl, the HUD pieces named in Config.Ui.Tuck.Keys slide off the nearest screen edge (left, right or up);
-- IdleSeconds after your last throw they slide back. Coins, the level bar, POWER, the streak and the goal stay.
-- Only on the devices Config.Ui.Tuck allows, and never during the first 3 minutes (onboarding points at buttons).
local TUCK = Config.Ui.Tuck
local tuckables: { [GuiObject]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local tuckState: { [GuiObject]: { Home: UDim2, Away: UDim2, Tween: Tween? } } = setmetatable({}, { __mode = "k" }) :: any
local tucked = false
local lastBowl = -math.huge

local function moveTo(object: GuiObject, target: UDim2): Tween
	local tween =
		TweenService:Create(object, TweenInfo.new(TUCK.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = target,
		})
	tween:Play()
	return tween
end

local function tuckOne(object: GuiObject, on: boolean)
	local state = tuckState[object]
	if on and not state then
		local screen = hud().AbsoluteSize
		local position, size = object.AbsolutePosition, object.AbsoluteSize
		local middle = position.X + size.X / 2
		-- (screen pixels -> the piece's layer pixels when V2 shrinks that layer)
		local fit = HudKit.LayerScale(object)
		local offset = if middle < screen.X / 3
			then UDim2.fromOffset(-(position.X + size.X + 30) / fit, 0)
			elseif middle > screen.X * 2 / 3 then UDim2.fromOffset((screen.X - position.X + 30) / fit, 0)
			else UDim2.fromOffset(0, -(position.Y + size.Y + 80) / fit)
		local home = object.Position
		state = { Home = home, Away = home + offset }
		tuckState[object] = state
		state.Tween = moveTo(object, state.Away)
	elseif not on and state then
		tuckState[object] = nil
		local moving = state.Tween and state.Tween.PlaybackState == Enum.PlaybackState.Playing
		if state.Tween then
			state.Tween:Cancel()
		end
		-- Only slide back if nobody else moved it while it was away (a layout switch already put it home)
		if moving or object.Position == state.Away then
			moveTo(object, state.Home)
		end
	end
end

local function tuckAllowed(): boolean
	if not TUCK.Enabled then
		return false
	end
	if Config.Onboarding.Enabled and (player:GetAttribute("Onboarding") or 3) < 3 then
		return false
	end
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	return if touch or HudKit.Phone() then TUCK.Touch else TUCK.Computer
end

-- ===== Phone MORE menu (owner 2026-10-28: the phone HUD was still too busy) =====
-- On phones the buttons in Config.Ui.PhoneMenu.Keys wait off the right edge; MORE slides them out in a column.
local MENU = Config.Ui.PhoneMenu
local menuMembers: { { Key: string, Object: GuiObject } } = {}
local asideObjects: { GuiObject } = {}
local menuOpen = false
local moreKit: any = nil

function HudKit.InMenu(key: string): boolean
	return MENU.Enabled and table.find(MENU.Keys, key) ~= nil
end

local function menuActive(): boolean
	return MENU.Enabled and HudKit.Phone()
end

local function isMember(object: GuiObject): boolean
	for _, member in menuMembers do
		if member.Object == object then
			return true
		end
	end
	return false
end

local function setMenu(open: boolean)
	if open and not menuActive() then
		open = false
	end
	if open == menuOpen then
		return
	end
	menuOpen = open
	if moreKit then
		-- The three bars turn into an X while open
		local lines = moreKit.Lines
		local info = TweenInfo.new(TUCK.Time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(lines[1], info, {
			Position = UDim2.fromScale(0.5, if open then 0.5 else 0.2),
			Rotation = if open then 45 else 0,
		}):Play()
		TweenService:Create(lines[3], info, {
			Position = UDim2.fromScale(0.5, if open then 0.5 else 0.8),
			Rotation = if open then -45 else 0,
		}):Play()
		lines[2].Visible = not open
		moreKit:SetCaption(if open then "CLOSE" else "MORE")
	end
	local more = HudKit.Layout.More.Phone
	local bar = SCREENS.Phone.Bar
	local slot = 0
	for _, member in menuMembers do
		local object = member.Object
		if object.Parent then
			local away = HudKit.Spot(member.Key, true)
			if open and object.Visible then
				slot += 1
				local y = UDim.new(0, more[2] - bar + slot * MENU.Gap)
				object.Position = UDim2.new(away.X, y)
				moveTo(object, UDim2.new(UDim.new(1, more[1] - SCREENS.Phone.W), y))
			elseif not open then
				moveTo(object, UDim2.new(away.X, object.Position.Y))
			end
		end
	end
	for _, object in asideObjects do
		if object.Parent then
			tuckOne(object, open)
		end
	end
end

-- Red dot on MORE while any folded button shows its dot or count badge
local function menuNews(): boolean
	for _, member in menuMembers do
		local object = member.Object
		if object.Parent and object.Visible then
			for _, child in object:GetDescendants() do
				if (child.Name == "Dot" or child.Name == "Badge") and child:IsA("Frame") and child.Visible then
					return true
				end
			end
		end
	end
	return false
end

-- Builds the MORE button (HudController calls this once); hidden on computers
function HudKit.MoreButton(parent: Instance)
	if not MENU.Enabled or moreKit then
		return
	end
	local kit = HudKit.Square(
		parent,
		{ Name = "MoreButton", Paint = "Purple", Icon = "Close", Caption = "MORE", Key = "More" }
	) :: any
	kit.Icon.Visible = false
	-- Three white bars (the menu sign) in the icon's place
	local bars = Instance.new("Frame")
	bars.Name = "Bars"
	bars.BackgroundTransparency = 1
	bars.Size = UDim2.fromScale(1, 1)
	bars.ZIndex = 5
	bars.Parent = kit.Slot
	local lines = {}
	for i = 0, 2 do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.2 + i * 0.3)
		line.Size = UDim2.fromScale(0.85, 0.17)
		line.BackgroundColor3 = C.White
		line.ZIndex = 5
		line.Parent = bars
		HudKit.Corner(line, 4)
		HudKit.Outline(line, C.Ink, 1.5)
		table.insert(lines, line)
	end
	kit.Lines = lines
	moreKit = kit
	local button = if kit.Holder:IsA("GuiButton")
		then kit.Holder
		else kit.Holder:FindFirstChildWhichIsA("GuiButton", true)
	if button then
		(button :: GuiButton).Activated:Connect(function()
			setMenu(not menuOpen)
		end)
	end
	HudKit.OnLayout(function(phone)
		setMenu(false)
		kit.Holder.Visible = phone
	end)
	kit.Holder.Visible = menuActive()
	task.spawn(function()
		while kit.Holder.Parent do
			kit:SetDot(not menuOpen and menuActive() and menuNews())
			task.wait(0.5)
		end
	end)
end

local function setTucked(on: boolean)
	if on == tucked then
		return
	end
	tucked = on
	for object in tuckables do
		if object.Parent and not (menuActive() and isMember(object)) then
			tuckOne(object, on)
		end
	end
end

local tuckLoop = false
local function startTuckLoop()
	if tuckLoop then
		return
	end
	tuckLoop = true
	task.spawn(function()
		while true do
			task.wait(0.25)
			setTucked(tuckAllowed() and os.clock() - lastBowl < TUCK.IdleSeconds)
		end
	end)
end

-- A HUD piece that slides away while you bowl, if its key is in Config.Ui.Tuck.Keys
function HudKit.Tuckable(object: GuiObject, key: string)
	if HudKit.InMenu(key) then
		-- A MORE menu button: tapping it also folds the menu away
		table.insert(menuMembers, { Key = key, Object = object })
		table.sort(menuMembers, function(a, b) -- the column follows Config.Ui.PhoneMenu.Keys
			return (table.find(MENU.Keys, a.Key) :: number) < (table.find(MENU.Keys, b.Key) :: number)
		end)
		local button = if object:IsA("GuiButton") then object else object:FindFirstChildWhichIsA("GuiButton", true)
		if button then
			(button :: GuiButton).Activated:Connect(function()
				task.defer(setMenu, false)
			end)
		end
	elseif MENU.Enabled and table.find(MENU.Aside, key) then
		table.insert(asideObjects, object)
	end
	if not table.find(TUCK.Keys, key) then
		return
	end
	tuckables[object] = true
	startTuckLoop()
	if tucked and not (menuActive() and isMember(object)) then
		task.defer(tuckOne, object, true)
	end
end

-- Stops a HUD piece from tucking (and brings it home if it is away)
function HudKit.Untuckable(object: GuiObject)
	if not tuckables[object] then
		return
	end
	tuckables[object] = nil
	tuckOne(object, false)
end

-- ThrowController calls this when you start a throw (and the HUD tucks away until you stop bowling)
function HudKit.Bowled()
	lastBowl = os.clock()
	setMenu(false)
	if tuckAllowed() then
		setTucked(true)
	end
end

-- ===== Small builders =====
local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	if parent then
		object.Parent = parent
	end
	return object
end
HudKit.Make = make

function HudKit.Corner(parent: Instance, radius: number): UICorner
	return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

-- Outline on a frame's edge
function HudKit.Outline(parent: Instance, color: Color3?, thickness: number?): UIStroke
	return make("UIStroke", {
		Color = color or C.Ink,
		Thickness = thickness or 3,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

-- Text with the kit's ink outline. stroke = the UIStroke width (half the design's CSS stroke); 0 = none.
function HudKit.Text(
	parent: Instance,
	text: string,
	font: Font,
	size: number,
	color: Color3,
	stroke: number?
): TextLabel
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		FontFace = font,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		ZIndex = 4,
	}, parent)
	if (stroke or 2) > 0 then
		make("UIStroke", { Color = C.Ink, Thickness = stroke or 2, LineJoinMode = Enum.LineJoinMode.Round }, label)
	end
	return label
end

-- Text at most `size` px that shrinks to stay inside its box (for lines that can be longer than the design's)
-- (Measured by hand: TextScaled wraps to two lines and lets the outline and italic lean poke past the box.)
function HudKit.Fit(label: TextLabel, size: number)
	local old = label:FindFirstChildOfClass("UITextSizeConstraint")
	if old then
		old:Destroy()
	end
	label.TextScaled = false
	label.TextWrapped = false -- one line, smaller, never two lines
	label:SetAttribute("FitMax", size)
	local function fit()
		local max = label:GetAttribute("FitMax") :: number
		local stroke = label:FindFirstChildOfClass("UIStroke")
		-- room for the outline on both sides + the italic lean
		local room = label.AbsoluteSize.X - (if stroke then stroke.Thickness * 2 else 0) - max * 0.12
		if room <= 0 then
			return
		end
		local params = Instance.new("GetTextBoundsParams")
		params.Text = label.Text
		params.Font = label.FontFace
		params.Size = max
		params.Width = 1e5
		local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
		if not ok then
			return
		end
		local width = bounds.X
		label.TextSize = if width > room then math.max(8, math.floor(max * room / width)) else max
	end
	if not label:GetAttribute("FitHooked") then
		label:SetAttribute("FitHooked", true)
		label:GetPropertyChangedSignal("Text"):Connect(function()
			task.spawn(fit)
		end)
		label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			task.spawn(fit)
		end)
	end
	label.TextSize = size
	task.spawn(fit)
end

function HudKit.Image(parent: Instance, icon: string, size: number, props: { [string]: any }?): ImageLabel
	local image = make("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = HudKit.Icon(icon),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(size, size),
		ZIndex = 4,
	}, parent)
	for key, value in props or {} do
		(image :: any)[key] = value
	end
	return image
end

-- ===== The chunky block: a lip (the darker colour, full size, ink outline) with the face on top of it =====
-- opts: Name, Button (true = a TextButton), Size, Radius, Lip (px), Paint ("Cyan"... or { face, lip }),
-- Shine (top highlight px, 0 = none), ShineAlpha (its transparency), Glow (ready glow colour or nil)
export type Block = {
	Holder: GuiObject, -- the lip (the TextButton when Button = true)
	Face: Frame,
	Shine: Frame,
	Glow: Frame,
	Scale: UIScale,
	Paint: (Block, any) -> (),
	SetLip: (Block, number) -> (),
	SetRadius: (Block, number) -> (),
	SetGlow: (Block, Color3?) -> (),
	LipHeight: number,
	Pressed: boolean,
}

local function paintColors(paint: any): (Color3, Color3)
	if type(paint) == "string" then
		local pair = HudKit.Paints[paint]
		return pair[1], pair[2]
	end
	return paint[1], paint[2]
end

function HudKit.Block(parent: Instance?, opts: { [string]: any }): Block
	local face, lip = paintColors(opts.Paint or "Card")
	-- The holder is the piece's full design size (the tap area); the lip sits inside it, inset by the outline,
	-- because a UIStroke draws outside its frame while the design's border is inside the box
	local holder = make(if opts.Button then "TextButton" else "Frame", {
		Name = opts.Name or "Block",
		BackgroundTransparency = 1,
		Size = opts.Size or UDim2.fromOffset(56, 56),
		ZIndex = opts.ZIndex or 1,
	})
	if opts.Button then
		local button = holder :: TextButton
		button.Text = ""
		button.AutoButtonColor = false
		button:SetAttribute("OwnPress", true) -- presses with its face, not UiFx's shrink
	end
	local o = opts.Outline or 3
	local radius = opts.Radius or 14
	local scale = make("UIScale", {}, holder)
	local lipFrame = make("Frame", {
		Name = "Lip",
		BackgroundColor3 = lip,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(o, o),
		Size = UDim2.new(1, -2 * o, 1, -2 * o),
		ZIndex = holder.ZIndex,
	}, holder)
	local corner = HudKit.Corner(lipFrame, radius - o)
	local outline = HudKit.Outline(lipFrame, opts.Ink or C.Ink, o)
	local faceFrame = make("Frame", {
		Name = "Face",
		BackgroundColor3 = face,
		BorderSizePixel = 0,
		ZIndex = holder.ZIndex + 1,
	}, lipFrame)
	local faceCorner = HudKit.Corner(faceFrame, radius - o)
	-- V2 top strip (opts.Strip px): the face shows its lighter third colour, a fill in the face colour sits under it
	local stripFill: Frame? = nil
	local stripCorner: UICorner? = nil
	local function stripColor(paint: any, faceColor: Color3): Color3
		return if type(paint) == "table" and paint[3] then paint[3] else faceColor:Lerp(C.White, 0.35)
	end
	if opts.Strip then
		faceFrame.BackgroundColor3 = stripColor(opts.Paint, face)
		stripFill = make("Frame", {
			Name = "StripFill",
			BackgroundColor3 = face,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, opts.Strip),
			Size = UDim2.new(1, 0, 1, -opts.Strip),
			ZIndex = holder.ZIndex + 1,
		}, faceFrame)
		stripCorner = HudKit.Corner(stripFill :: Frame, radius - o)
	end
	-- Top highlight: a white band at the top of the face
	local shine = make("Frame", {
		Name = "Shine",
		BackgroundColor3 = C.White,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = holder.ZIndex + 2,
		Visible = (opts.Shine or 3) > 0,
	}, faceFrame)
	local shineCorner = HudKit.Corner(shine, radius - o)
	local shineGradient = make("UIGradient", { Rotation = 90 }, shine)
	-- Ready glow: a soft ring just outside the ink outline
	local glow = make("Frame", {
		Name = "Glow",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = holder.ZIndex,
		Visible = false,
	}, holder)
	local glowCorner = HudKit.Corner(glow, radius)
	local glowRing = HudKit.Outline(glow, C.Lime, 9)
	glowRing.Transparency = 0.45
	if SUNNY then
		-- no soft glow (Addendum 4 UI rules): a solid second outline instead
		glowRing.Thickness = 4
		glowRing.Transparency = 0
	end

	local block = {
		Holder = holder,
		LipFrame = lipFrame,
		Face = faceFrame,
		Shine = shine,
		Glow = glow,
		Scale = scale,
		Outline = outline,
		GlowRing = glowRing,
		LipHeight = opts.Lip or 6,
		Pressed = false,
	} :: any

	local shinePx, shineAlpha = opts.Shine or 3, opts.ShineAlpha or 0.55
	if SUNNY then
		shinePx = 0 -- flat fills (Addendum 4 UI rules)
		shine.Visible = false
	end
	local function layoutFace()
		local drop = if block.Pressed then block.LipHeight - 2 else 0
		faceFrame.Position = UDim2.fromOffset(0, drop)
		faceFrame.Size = UDim2.new(1, 0, 1, -block.LipHeight)
		local height = math.max(lipFrame.AbsoluteSize.Y - block.LipHeight, 1)
		local cut = math.clamp(shinePx / height, 0.001, 0.98)
		shineGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, shineAlpha),
			NumberSequenceKeypoint.new(cut, shineAlpha),
			NumberSequenceKeypoint.new(math.min(cut + 0.001, 0.999), 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	block.Layout = layoutFace
	-- Only the height matters (the shine band); skip same-height updates so a resize can't feed back into itself
	local lastHeight = -1
	lipFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		local height = lipFrame.AbsoluteSize.Y
		if height ~= lastHeight then
			lastHeight = height
			task.defer(layoutFace)
		end
	end)
	layoutFace()

	function block.Paint(_self: Block, paint: any)
		local f, l = paintColors(paint)
		lipFrame.BackgroundColor3 = l
		if stripFill then
			stripFill.BackgroundColor3 = f
			faceFrame.BackgroundColor3 = stripColor(paint, f)
		else
			faceFrame.BackgroundColor3 = f
		end
	end
	function block.SetLip(self: Block, px: number)
		self.LipHeight = px
		layoutFace()
	end
	function block.SetRadius(_self: Block, r: number)
		for _, c in { corner, faceCorner, shineCorner, stripCorner } do
			c.CornerRadius = UDim.new(0, r - o)
		end
		glowCorner.CornerRadius = UDim.new(0, r)
	end
	function block.SetGlow(_self: Block, color: Color3?)
		glow.Visible = color ~= nil
		if color then
			glowRing.Color = color
		end
	end

	if opts.Button then
		HudKit.Press(block)
	end
	holder.Parent = parent
	return block
end

-- Pressing: the face sinks into the lip (0.06 s) and springs back (0.12 s Back Out); computers also grow a little
-- on hover. Plays the click.
function HudKit.Press(block: Block, silent: boolean?, source: GuiButton?)
	local button = source or block.Holder :: GuiButton
	local function set(down: boolean)
		if block.Pressed == down then
			return
		end
		block.Pressed = down
		local drop = if down then block.LipHeight - 2 else 0
		local info = if down
			then TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			else TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(block.Face, info, { Position = UDim2.fromOffset(0, drop) }):Play()
	end
	button.MouseButton1Down:Connect(function()
		set(true)
	end)
	button.MouseButton1Up:Connect(function()
		set(false)
	end)
	button.MouseLeave:Connect(function()
		set(false)
		TweenService:Create(block.Scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end)
	button.MouseEnter:Connect(function()
		if not UserInputService.TouchEnabled then
			TweenService:Create(block.Scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1.06 }):Play()
		end
	end)
	if not silent then
		button.Activated:Connect(function()
			Sfx.Play("Click", 0.95 + math.random() * 0.1)
		end)
	end
end

-- ===== The square menu button (56x56 computer, 44x46 phone): icon, caption, red dot, count badge =====
export type Square = Block & {
	Icon: ImageLabel,
	Caption: TextLabel,
	CaptionStroke: UIStroke,
	Dot: Frame,
	Badge: Frame,
	BadgeText: TextLabel,
	Slot: Frame, -- holds the icon (a 3D view can go here instead)
	SetIcon: (Square, string, number?) -> (),
	SetCaption: (Square, string, Color3?, Font?, number?) -> (),
	SetDot: (Square, boolean) -> (),
	SetBadge: (Square, number?) -> (),
	Resize: (Square, boolean) -> (),
}

-- ===== V2 tile button (board B1/B2): navy tile, 3 px ink outline, darker lip, lighter top strip, the new icon
-- on top and a white outlined caption across the bottom edge. Size = its layout spot (96 computer, 46 phone,
-- top-right 80 / 44). Same methods as the old square, so every caller keeps working. =====
local V2_TILE = if V2 then { SlKit.C.Tile, SlKit.C.TileLip, SlKit.C.TileStrip } else nil
local V2_GREY = if V2 then SlKit.Paints.Disabled else nil
-- the HUD's old icon names -> the new sheet; a button's own icon comes from its key
local V2_ICONS = {
	Ball = "hud_shop",
	Paw = "hud_pets",
	StoreBag = "hud_store",
	GiftDaily = "hud_daily",
	Xp = "hud_profile",
	Portal = "hud_teleport",
	GiftPink = "hud_gifts",
	Store = "hud_passes",
	Rebirth = "hud_rebirth",
	Lock = "ui_lock",
	Check = "ui_tick",
}
local V2_KEY_ICONS = {
	Balls = "hud_shop",
	Pets = "hud_pets",
	Store = "hud_store",
	Daily = "hud_daily",
	Profile = "hud_profile",
	Teleport = "hud_teleport",
	Gifts = "hud_gifts",
	Settings = "hud_settings",
	Passes = "hud_passes",
	Rebirth = "hud_rebirth",
}

local function v2Square(parent: Instance?, opts: { [string]: any }): Square
	local key = opts.Key or opts.SizeKey
	startFit()
	if parent and parent:IsA("ScreenGui") and not FIT_GUIS[parent.Name] then
		parent = HudKit.Layer() -- (its own layer also holds a window, which must not shrink)
	end
	local kitC = (SlKit :: any).C
	local block = HudKit.Block(nil, {
		Name = opts.Name,
		Button = opts.Button ~= false,
		Paint = V2_TILE,
		Ink = kitC.Ink,
		Strip = 3,
		Radius = 16,
		Lip = 6,
	}) :: any
	local face = block.Face
	local holder = block.Holder
	local slot = make("Frame", {
		Name = "Slot",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, face)
	local icon = make("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	}, slot)
	local caption = make("TextLabel", {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		FontFace = (SlKit :: any).Font,
		Text = opts.Caption or "",
		TextColor3 = C.White,
		ZIndex = 7,
	}, holder)
	local captionStroke = make("UIStroke", { Color = kitC.Ink, LineJoinMode = Enum.LineJoinMode.Round }, caption)
	-- red dot (news) and count badge (a number), past the top-right corner
	local dot = make("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = (SlKit :: any).Paints.Red[1],
		Visible = false,
		ZIndex = 8,
	}, holder)
	HudKit.Corner(dot, 40)
	local dotStroke = HudKit.Outline(dot, kitC.Ink, 3)
	local badge = make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = (SlKit :: any).Paints.Red[1],
		Visible = false,
		ZIndex = 8,
	}, holder)
	HudKit.Corner(badge, 40)
	local badgeStroke = HudKit.Outline(badge, kitC.Ink, 3)
	local badgeText = HudKit.Text(badge, "", (SlKit :: any).Font, 20, C.White, 0)
	badgeText.ZIndex = 9
	-- ready ring: solid gold, 4 px, standing 6 px off the button (board M "Ready (any)")
	local glow = block.Glow :: Frame
	local glowRing = block.GlowRing :: UIStroke

	block.Icon = icon
	block.Slot = slot
	block.Caption = caption
	block.CaptionStroke = captionStroke
	block.Dot = dot
	block.Badge = badge
	block.BadgeText = badgeText
	local iconName = V2_KEY_ICONS[key] or V2_ICONS[opts.Icon] or "hud_shop"

	function block.Resize(self: Square, phone: boolean)
		local row = key and HudKit.Layout[key] and HudKit.Layout[key][if phone then "Phone" else "Pc"]
		local w = if row and row[3] then row[3] else (if phone then 46 else 96)
		local h = if row and row[4] then row[4] else w
		holder.Size = UDim2.fromOffset(w, h)
		local small = h < 60
		self:SetRadius(if small then 11 else 16)
		self:SetLip(if small then 4 else 6)
		local iconSize = math.floor(h * (if small then 0.64 else 0.7))
		slot.Size = UDim2.fromOffset(iconSize, iconSize)
		slot.Position = UDim2.new(0.5, 0, 0, if small then 1 else 3)
		local textSize = if small then 11 else (if h < 90 then 18 else 20)
		caption.TextSize = textSize
		caption.Size = UDim2.new(1, 24, 0, textSize + 4)
		caption.Position = UDim2.new(0.5, 0, 1, if small then -3 else -6)
		captionStroke.Thickness = if small then 1.5 else 2.5
		local dotSize = if small then 14 else 26
		dot.Size = UDim2.fromOffset(dotSize, dotSize)
		dot.Position = UDim2.new(1, if small then -4 else -12, 0, if small then 4 else 10)
		dotStroke.Thickness = if small then 2 else 3
		local badgeSize = if small then 20 else 38
		badge.Size = UDim2.fromOffset(badgeSize, badgeSize)
		badge.Position = UDim2.new(1, if small then -4 else -14, 0, if small then 4 else 10)
		badgeStroke.Thickness = if small then 2 else 3
		badgeText.TextSize = if small then 12 else 22
		local ring = if small then 4 else 6
		glow.Position = UDim2.fromOffset(-ring, -ring)
		glow.Size = UDim2.new(1, ring * 2, 1, ring * 2)
		glowRing.Thickness = if small then 3 else 4
		glowRing.Transparency = 0
		local glowCorner = glow:FindFirstChildOfClass("UICorner")
		if glowCorner then
			glowCorner.CornerRadius = UDim.new(0, (if small then 11 else 16) + ring)
		end
	end
	function block.SetIcon(self: Square, name: string?, _size: number?)
		local v2 = if name == nil then V2_KEY_ICONS[key] else V2_ICONS[name :: string]
		if name == "Close" and key == "Settings" then
			v2 = "hud_settings"
		end
		-- (an old-kit icon with no new version shows as it is)
		icon.Image = if v2 then (SlKit :: any).Icon(v2) else HudKit.Icon(name :: string)
	end
	-- Callers' small caption sizes were for the old 56 px buttons; V2 keeps one size (only the colour carries)
	function block.SetCaption(self: Square, text: string, color: Color3?, _font: Font?, _size: number?)
		caption.Text = text
		caption.TextColor3 = color or C.White
		self:Resize(HudKit.Phone())
	end
	local basePaint = block.Paint
	function block.Paint(self: Square, paint: any)
		basePaint(self, if paint == "Grey" then V2_GREY else V2_TILE)
	end
	local baseGlow = block.SetGlow
	function block.SetGlow(self: Square, color: Color3?)
		baseGlow(self, if color then kitC.Header else nil)
	end
	function block.SetDot(_self: Square, on: boolean)
		if on and not dot.Visible then
			(SlKit :: any).PopIn(dot, 0.25)
		end
		dot.Visible = on
	end
	function block.SetBadge(_self: Square, count: number?)
		local on = count ~= nil and count > 0
		if on and not badge.Visible then
			(SlKit :: any).PopIn(badge, 0.25)
		elseif on and badgeText.Text ~= tostring(count) then
			(SlKit :: any).Pulse(badge, 1.2, 0.12)
		end
		badge.Visible = on
		badgeText.Text = if on then (if (count :: number) > 99 then "99+" else tostring(count)) else ""
	end
	icon.Image = (SlKit :: any).Icon(iconName)
	if opts.Icon == "Close" and key == "More" then
		icon.Image = ""
	end

	if opts.Key then
		HudKit.OnLayout(function(phone)
			block:Resize(phone)
			local position = HudKit.Spot(opts.Key, phone)
			holder.AnchorPoint = Vector2.zero
			holder.Position = position
		end)
		HudKit.Tuckable(holder, opts.Key)
	else
		HudKit.OnLayout(function(phone)
			block:Resize(phone)
		end)
	end
	holder.Parent = parent
	return block
end

function HudKit.Square(parent: Instance?, opts: { [string]: any }): Square
	if V2 then
		return v2Square(parent, opts)
	end
	local block = HudKit.Block(nil, {
		Name = opts.Name,
		Button = opts.Button ~= false,
		Paint = opts.Paint,
		Radius = 14,
		Lip = 6,
	}) :: any
	local face = block.Face
	local slot = make("Frame", {
		Name = "Slot",
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		ZIndex = 4,
	}, face)
	local icon = HudKit.Image(slot, opts.Icon or "Ball", 32, { Size = UDim2.fromScale(1, 1) })
	local caption = HudKit.Text(face, opts.Caption or "", HudKit.Head, 12, C.White, 2)
	caption.Name = "Caption"
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.TextYAlignment = Enum.TextYAlignment.Top
	-- Red dot past the top-right corner: red, a white ring, then the ink ring
	local dot = make("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Ink,
		Visible = false,
		ZIndex = 8,
	}, block.Holder)
	HudKit.Corner(dot, 20)
	local dotInner = make("Frame", {
		Name = "Inner",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = C.Red,
		ZIndex = 9,
	}, dot)
	HudKit.Corner(dotInner, 20)
	local dotRing = HudKit.Outline(dotInner, C.White, 3)
	-- Count badge (GIFTS ready): red circle with an ink ring and a number
	local badge = make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Red,
		Visible = false,
		ZIndex = 8,
	}, block.Holder)
	HudKit.Corner(badge, 20)
	HudKit.Outline(badge, C.Ink, 3)
	local badgeText = HudKit.Text(badge, "", HudKit.Num, 14, C.White, 1.5)
	badgeText.ZIndex = 9

	local captionSize = opts.CaptionSize -- nil = the kit's 12 (10 on phones)
	block.Icon = icon
	block.Slot = slot
	block.Caption = caption
	block.CaptionStroke = caption:FindFirstChildOfClass("UIStroke")
	block.Dot = dot
	block.Badge = badge
	block.BadgeText = badgeText
	block.CaptionSize = captionSize
	block.IconSize = nil

	function block.Resize(self: Square, phone: boolean)
		local s = self :: any
		local size = if s.IconSize
			then (if phone then math.floor(s.IconSize * 0.75 + 0.5) else s.IconSize)
			elseif phone then 24
			else 32
		self.Holder.Size = if phone then UDim2.fromOffset(44, 46) else UDim2.fromOffset(56, 56)
		self:SetRadius(if phone then 12 else 14)
		self:SetLip(if phone then 5 else 6)
		slot.Size = UDim2.fromOffset(size, size)
		slot.Position = UDim2.new(0.5, 0, 0, if s.IconSize then 3 else 2)
		local full = if phone then 10 else 12
		local textSize = math.floor((s.CaptionSize or full) * (if phone and s.CaptionSize then 0.8 else 1) + 0.5)
		caption.TextSize = textSize
		caption.Position = UDim2.new(0.5, 0, 0, size + (if s.IconSize then 5 else 3) - (if phone then 1 else 0))
		caption.Size = UDim2.new(1, 4, 0, textSize)
		local dotSize = if phone then 16 else 20
		dot.Size = UDim2.fromOffset(dotSize + 6, dotSize + 6)
		dot.Position = UDim2.new(1, 1, 0, -1)
		dotInner.Size = UDim2.fromOffset(dotSize - 6, dotSize - 6)
		dotRing.Thickness = if phone then 2 else 3
		local badgeSize = if phone then 22 else 26
		badge.Size = UDim2.fromOffset(badgeSize - 6, badgeSize - 6)
		badge.Position = UDim2.new(1, if phone then 0 else 2, 0, if phone then 0 else -2)
		badgeText.TextSize = if phone then 12 else 14
	end
	function block.SetIcon(self: Square, name: string, size: number?)
		icon.Image = HudKit.Icon(name);
		(self :: any).IconSize = size
		self:Resize(HudKit.Phone())
	end
	function block.SetCaption(self: Square, text: string, color: Color3?, font: Font?, size: number?)
		caption.Text = text
		caption.TextColor3 = color or C.White
		caption.FontFace = font or HudKit.Head;
		(self :: any).CaptionSize = size
		self.CaptionStroke.Thickness = if (size or 12) <= 9 then 1.5 else 2
		self:Resize(HudKit.Phone())
	end
	function block.SetDot(_self: Square, on: boolean)
		if on and not dot.Visible then
			local scale = dot:FindFirstChildOfClass("UIScale") or make("UIScale", {}, dot)
			scale.Scale = 0
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
		dot.Visible = on
	end
	function block.SetBadge(_self: Square, count: number?)
		local on = count ~= nil and count > 0
		if on and not badge.Visible then
			local scale = badge:FindFirstChildOfClass("UIScale") or make("UIScale", {}, badge)
			scale.Scale = 0
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
		badge.Visible = on
		badgeText.Text = if on then tostring(count) else ""
	end

	if opts.Key then
		HudKit.OnLayout(function(phone)
			block:Resize(phone)
			local position = HudKit.Spot(opts.Key, phone)
			block.Holder.AnchorPoint = Vector2.zero
			block.Holder.Position = position
		end)
		HudKit.Tuckable(block.Holder, opts.Key)
	else
		block:Resize(HudKit.Phone())
	end
	block.Holder.Parent = parent
	return block
end

-- Gives a button built in Studio the kit look: its own background, corner and outline go (plus the children named
-- in opts.Drop), a kit square fills it, and pressing it sinks the face. It is sized and placed on opts.Key's spot
-- unless opts.Place = false (then only sized).
function HudKit.Adopt(button: GuiButton, opts: { [string]: any }): Square
	for _, child in button:GetChildren() do
		if child:IsA("UICorner") or child:IsA("UIStroke") or table.find(opts.Drop or {}, child.Name) then
			child:Destroy()
		end
	end
	button.BackgroundTransparency = 1
	if button:IsA("TextButton") then
		button.Text = ""
	end
	local kit = HudKit.Square(button, {
		Name = "Kit",
		SizeKey = opts.Key,
		Button = false,
		Paint = opts.Paint,
		Icon = opts.Icon,
		Caption = opts.Caption,
		CaptionSize = opts.CaptionSize,
	})
	HudKit.Press(kit, true, button)
	HudKit.OnLayout(function(phone)
		kit:Resize(phone)
		kit.Holder.Position = UDim2.fromOffset(0, 0)
		button.Size = kit.Holder.Size
		if opts.Key and opts.Place ~= false then
			button.AnchorPoint = Vector2.zero
			button.Position = HudKit.Spot(opts.Key, phone)
		end
	end)
	if opts.Key and opts.Place ~= false then
		HudKit.Tuckable(button, opts.Key)
	end
	return kit
end

-- A spinning or bobbing icon loop (REBIRTH ready, TELEPORT always, GIFTS ready). Returns a stop function.
function HudKit.Spin(object: GuiObject, seconds: number): () -> ()
	local running = true
	task.spawn(function()
		while running and object.Parent do
			object.Rotation = 0
			local tween =
				TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Rotation = 360 })
			tween:Play()
			tween.Completed:Wait()
		end
		object.Rotation = 0
	end)
	return function()
		running = false
	end
end

-- The screen's top-bar inset for code that converts screen points into HUD coordinates
function HudKit.Inset(): Vector2
	return GuiService:GetGuiInset()
end

return HudKit
