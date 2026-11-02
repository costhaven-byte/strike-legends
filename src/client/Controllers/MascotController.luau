-- Mascots on screen (Addendum 2 Phase 3 step 8): the PETS button, the mascot panel, the hatching moment and the
-- egg stand in the lobby (Workspace.Hub.EggPad, the old daily-reward pad).
-- Hatching happens only at the egg stand (owner's call, 2026-10-19): the panel shows your equipped slots with
-- EQUIP BEST and only the pets you own, with EQUIP buttons (owner 2026-10-21: no egg card, no silhouettes), and gold
-- Shiny cards once you own a Shiny. Batch C2 (owner 2026-10-29): no MERGE button here any more; Shinies are made only
-- at zone 3's PET FUSION machine (the fusion window below). Pet bonuses show as multipliers (x2.5, Mascots.BonusText).
-- Owner 2026-10-22: the panel has two tabs, PETS and ITEMS (the potions, PotionController.BuildItems). The button is
-- always open; before the pets' zone the PETS tab shows where pets unlock and the button opens on ITEMS.
-- Addendum 5 B1: pets show their stat boosts (Config.PetStats: "+50% COINS", "+20% PINS", one colour per stat) on
-- every card, the slot strip shows the equipped total of all four stats, and the panel is open in the core loop.
-- Built in code (not in Studio), so it lives in git. The server rolls every hatch (MascotService); this only shows it.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local SunKit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("SunKit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Mascots = require(Shared.Modules.Mascots)
local Store = require(Shared.Modules.Store)
local Zones = require(Shared.Modules.Zones)
local PotionController = require(script.Parent.PotionController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local HatchScene = require(Modules:WaitForChild("HatchScene"))
local MascotView = require(Modules:WaitForChild("MascotView"))
local PetIdle = require(Modules:WaitForChild("PetIdle"))
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))
local HudKit = require(Modules:WaitForChild("HudKit"))
local RewardKit = require(Modules:WaitForChild("RewardKit"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local CrateKit = require(Modules:WaitForChild("CrateKit"))
local PetsV2 = require(Modules:WaitForChild("PetsV2"))
local EggV2 = require(Modules:WaitForChild("EggV2"))
local HatchV2 = require(Modules:WaitForChild("HatchV2"))

local player = Players.LocalPlayer

local FX = Config.MascotFx
local ECONOMY = Config.Economy.Mascots
local PETS_V2 = Config.Ui.PetsV2 == true -- (UI overhaul V5: the new PETS window, Modules/PetsV2)
local EGG_V2 = Config.Ui.EggV2 == true -- (UI overhaul V6: the new egg boards + FUSE PETS window, Modules/EggV2)
local HATCH_V2 = Config.Ui.HatchV2 == true -- (UI overhaul V7: the new hatch sequence, Modules/HatchV2)
local EGG = Config.Economy.Eggs[1] -- the Neon Egg (Id "Alley"); zone 3 and 4 eggs hatch at their own stands (Phase X)
EGG = Mascots.GetEgg(EGG.Id) or EGG -- (Addendum 5 B2: on the roof, the egg ladder's first egg and its price)

local FONT = SunKit.Swap(Font.new("rbxasset://fonts/families/LuckiestGuy.json"))
local INK = Color3.fromHex("06060F")
local CARD = Color3.fromRGB(30, 20, 60)
local PINK = Color3.fromRGB(255, 60, 210)
local GOLD = Color3.fromRGB(255, 200, 40)
local LIME = Color3.fromRGB(125, 255, 60)
local GREY = Color3.fromRGB(120, 110, 150)

local MascotController = {}

local make = UiKit.Make

-- Every number on screen uses the shared formatter (Config.Numbers)
local formatNumber = Currency.Format

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

-- Free hatches of the egg waiting (playtime gifts); a hatch uses one before any coins
-- (egg = a Config.Economy.Eggs row; the Neon Egg when left out)
local function freeEggs(egg: any?): number
	return player:GetAttribute("FreeEgg_" .. (egg or EGG).Id) or 0
end

local function eggState(egg: any?): (boolean, string?, boolean)
	egg = egg or EGG
	local level = player:GetAttribute("RankLevel") or 1
	local unlocked, why = Mascots.EggUnlocked(
		egg,
		level,
		Mascots.EggZone(player:GetAttribute("ZonesOpen"), player:GetAttribute("CoreZonesOpen"))
	)
	local affordable = (player:GetAttribute("Coins") or 0) >= egg.Price or freeEggs(egg) > 0
	return unlocked, why, affordable
end

-- How many of each mascot the player owns / has equipped
local function owned(): { [string]: number }
	return Mascots.DecodeOwned(player:GetAttribute("Mascots"))
end

local function equipped(): { string }
	return Mascots.DecodeEquipped(player:GetAttribute("EquippedMascots"))
end

local function countIn(list: { string }, id: string): number
	local n = 0
	for _, other in list do
		if other == id then
			n += 1
		end
	end
	return n
end

function MascotController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local hatchRemote = remotes:WaitForChild("HatchEgg") :: RemoteFunction
	local equipRemote = remotes:WaitForChild("EquipMascot") :: RemoteEvent
	local bestRemote = remotes:WaitForChild("EquipBestMascots") :: RemoteEvent
	local mergeRemote = remotes:WaitForChild("MergeMascot") :: RemoteFunction
	local autoDeleteRemote = remotes:WaitForChild("SetAutoDelete") :: RemoteEvent
	local playerGui = player:WaitForChild("PlayerGui")
	local ballsUI = playerGui:WaitForChild("BallsUI") :: ScreenGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "MascotUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = ballsUI.DisplayOrder
	gui.IgnoreGuiInset = ballsUI.IgnoreGuiInset
	-- children draw over their parent (the kit pieces on the hatch screen sit above its tap-to-skip layer)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- PETS button (owner's HUD Kit: pink, paw icon). Count badge = potions to drink; red dot = an egg to hatch.
	local petsKit =
		HudKit.Square(gui, { Name = "PetsButton", Paint = "Pink", Icon = "Paw", Caption = "PETS", Key = "Pets" })
	local petsButton = petsKit.Holder :: TextButton
	petsButton.Visible = false

	-- UI pass batch 5 (2026-10-29): the panel is a kit window (navy cover, PETS / ITEMS lip tabs, red X). PETS page =
	-- a strip with the equipped slots, the total bonus and EQUIP BEST, then a grid of the pets you own.
	local K = RewardKit.C
	local W, H = 820, 560
	local PAGE_X, PAGE_Y = 24, 98
	local PAGE_W, PAGE_H = W - 48, H - PAGE_Y - 20
	local win = RewardKit.Window(gui, W, H)
	local cover, closeX = RewardKit.Cover(win.Panel, W, H, "PETS", "", K.Pink)
	local titleBox = cover:FindFirstChild("TitleBox") :: Frame
	local subLine = cover:FindFirstChild("Sub") :: TextLabel
	local titleFront = titleBox:FindFirstChild("Front", true) :: TextLabel -- its ink drop copies the text
	local function setTitle(value: string, color: Color3)
		titleFront.Text = value
		titleFront.TextColor3 = color
	end
	-- (V5: the new window closes too; set below once it's started)
	local closePanel = function()
		win:Close()
	end

	-- Tabs: PETS and ITEMS, left of the X (the open one pink, the other dark)
	local tabs = {}
	for index, info in { { "Pets", "PETS" }, { "Items", "ITEMS" } } do
		local tab = RewardKit.Button(cover, info[2], "Pink", 124, 46, 24)
		tab.Holder.Name = info[1] .. "Tab"
		tab.Holder.Position = UDim2.fromOffset(W - 334 + (index - 1) * 134, 16)
		tabs[info[1]] = tab
	end
	local function page(name: string): Frame
		return make("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(PAGE_X, PAGE_Y),
			Size = UDim2.fromOffset(PAGE_W, PAGE_H),
			Visible = false,
		}, cover)
	end
	-- The ITEMS page (filled by PotionController.BuildItems once the toast exists)
	local itemsPage = page("Items")
	local right = page("Right") -- the PETS page
	right.Visible = true

	-- A big icon with a title and a line, centred in a box (no pets yet / pets locked)
	local function emptyNote(parent: Instance, icon: string, y: number, h: number): (Frame, TextLabel, TextLabel)
		local box = make("Frame", {
			Name = "Note",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.fromOffset(PAGE_W, h),
			Visible = false,
		}, parent)
		HudKit.Image(box, icon, 96, {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, h / 2 - 104),
		})
		local head = RewardKit.Label(box, "", UiKit.Head, 34, K.White, 3, 20, h / 2, PAGE_W - 40, 42)
		local line = RewardKit.Label(box, "", UiKit.Body, 16, K.Label, 0, 20, h / 2 + 46, PAGE_W - 40, 22)
		return box, head, line
	end
	-- PETS page before the pets' zone opens: where pets come from
	local lockedPage = page("PetsLocked")
	local lockedBox, lockedHead, lockedLine = emptyNote(lockedPage, "Lock", 0, PAGE_H)
	lockedBox.Visible = true
	local lockedNote = lockedPage

	-- Top strip: equipped slots on the left, the total bonus and EQUIP BEST on the right
	local STRIP_H = 116
	local strip = UiKit.Block(right, {
		Name = "Strip",
		Size = Vector2.new(PAGE_W, STRIP_H),
		Fill = K.Page,
		Lip = K.Ink,
		LipPx = 6,
		Radius = 20,
		Outline = 3,
	})
	local stripFace = strip.Face
	local SIDE_W = 200
	local slotRow = make("Frame", {
		Name = "Slots",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -SIDE_W - 76, 1, 0), -- room on the right for the EQUIP BEST hand
	}, stripFace) :: Frame
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, slotRow)
	local sideX = PAGE_W - 6 - 12 - SIDE_W
	local totalCaption = RewardKit.Label(stripFace, "PET BONUS", UiKit.Body, 13, K.Muted, 0, sideX, 6, SIDE_W, 18)
	totalCaption.Name = "TotalCaption"
	local slotsTitle = RewardKit.Label(stripFace, "x1 COINS", UiKit.Head, 28, K.Gold, 2.5, sideX, 22, SIDE_W, 32)
	slotsTitle.Name = "Total"
	-- B1: the four stat totals in a 2 x 2 grid instead (+0% ones dim)
	local totalLabels: { [string]: TextLabel } = {}
	if Mascots.StatsOn() then
		totalCaption.Text = "PET BOOSTS"
		slotsTitle.Visible = false
		for i, name in Config.PetStats.Order do
			local col, rowIndex = (i - 1) % 2, math.floor((i - 1) / 2)
			local label = RewardKit.Label(
				stripFace,
				"",
				UiKit.Num,
				14,
				Config.PetStats.Types[name].Color,
				1.5,
				sideX + col * (SIDE_W / 2),
				22 + rowIndex * 16,
				SIDE_W / 2 - 4,
				16
			)
			label.Name = "Total" .. name
			totalLabels[name] = label
		end
	end
	local best = RewardKit.Button(stripFace, if Mascots.StatsOn() then "EQUIP BEST" else "BEST ONES OUT", "Lime", SIDE_W, 46, 22)
	best.Holder.Name = "EquipBest"
	best.Holder.Position = UDim2.fromOffset(sideX, 54)
	local bestButton = best.Holder

	-- The pets you own (the others stay hidden)
	local CARD_W, CARD_H, CARD_GAP = 142, if Mascots.StatsOn() then 214 else 196, 12 -- (B1: two stat lines)
	local GRID_Y = STRIP_H + 12
	local grid = make("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, GRID_Y),
		Size = UDim2.fromOffset(PAGE_W, PAGE_H - GRID_Y),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = K.Pink,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, right) :: ScrollingFrame
	make("UIGridLayout", {
		CellSize = UDim2.fromOffset(CARD_W, CARD_H),
		CellPadding = UDim2.fromOffset(CARD_GAP, CARD_GAP),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	make("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 2) }, grid)
	local noPets, noPetsHead, noPetsLine = emptyNote(right, "Paw", GRID_Y, PAGE_H - GRID_Y)
	noPetsHead.Text = "NO PETS YET"
	noPetsLine.Text = if Mascots.CoreEggsOn()
		then "PETS BOOST YOUR COINS, PINS, BAG AND SPEED. BUY EGGS AT THE EGG ROW NEXT TO THE SHOP"
		elseif Mascots.StatsOn()
		then "PETS BOOST YOUR COINS, PINS, BAG AND SPEED. EGGS ARE COMING TO THE SHOP"
		elseif
			Config.CoreLoop.Enabled
		then "PETS COME IN A LATER UPDATE" -- (Addendum 4: the rooftop egg stand waits for Stage 5)
		else "HATCH THE NEON EGG AT THE EGG STAND"

	-- Addendum 5 B2: GO TO EGGS (teleports you in front of the first egg, CoreGoTo "Eggs")
	local goRemote = remotes:FindFirstChild("CoreGoTo") :: RemoteEvent?
	if Mascots.CoreEggsOn() and goRemote then
		local go = RewardKit.Button(noPets, "GO TO EGGS", "Pink", 240, 50, 24)
		go.Holder.Name = "GoToEggs"
		go.Holder.AnchorPoint = Vector2.new(0.5, 0)
		go.Holder.Position = UDim2.new(0.5, 0, 0, (PAGE_H - GRID_Y) / 2 + 80)
		go.Activated:Connect(function()
			Sfx.Play("Click")
			goRemote:FireServer("Eggs")
			win:Close()
		end)
	end

	type Tile = {
		Frame: GuiObject,
		Name: TextLabel,
		Count: TextLabel,
		CountPill: GuiObject,
		Bonus: TextLabel,
		Equip: any,
		Outline: UIStroke,
		Tick: GuiObject,
		Fuse: GuiObject?,
		Mascot: any,
	}
	local tiles: { Tile } = {}
	local doMerge: (mascot: any) -> ()
	local showFuseHint: () -> () -- (B2, below with the toast)
	local FACE_W, FACE_H = CARD_W - 6, CARD_H - 12
	-- Each mascot's card, then its Shiny card right after it (each shown only once owned)
	local cards = {}
	for index, mascot in Config.Mascots do -- every egg's pets (Phase X: one egg per zone), shown once owned
		local order = Mascots.RarityIndex(mascot.Rarity) * 100 + index * 2
		table.insert(cards, { Mascot = mascot, Order = order })
		table.insert(cards, { Mascot = Mascots.Get(Mascots.ShinyId(mascot.Id)), Order = order + 1 })
	end
	-- B2: strongest first (like EQUIP BEST counts them), a Shiny before its pet
	if Mascots.StatsOn() then
		table.sort(cards, function(a, b)
			local sa, sb = Mascots.Score(a.Mascot), Mascots.Score(b.Mascot)
			if sa ~= sb then
				return sa > sb
			end
			return a.Order < b.Order
		end)
		for rank, card in cards do
			card.Order = rank
		end
	end
	-- B2: Mythic and Shiny cards get a turning gradient on their frame (rainbow / gold), turned while the panel is open
	local spinning: { UIGradient } = {}
	local MYTHIC_RAINBOW = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 160)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 255)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(180, 90, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 160)),
	})
	local SHINY_GOLD = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 40)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 230)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 40)),
	})
	for _, card in cards do
		local mascot = card.Mascot
		local color = if mascot.Shiny then K.Gold else Mascots.RarityColor(mascot.Rarity)
		local block = UiKit.Block(grid, {
			Name = mascot.Id,
			Size = Vector2.new(CARD_W, CARD_H),
			Fill = if mascot.Shiny then UiKit.Hex("2E2312") else K.Card,
			Lip = K.Page,
			LipPx = 6,
			Radius = 16,
			Outline = 3,
			Ring = color,
		})
		local frame = block.Holder
		frame.LayoutOrder = card.Order
		frame.Visible = false
		local face = block.Face
		local tileOutline = (face:FindFirstChild("Ring") :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke
		if Mascots.StatsOn() and (mascot.Shiny or mascot.Rarity == "Mythic") then
			tileOutline.Color = Color3.new(1, 1, 1)
			local gradient = Instance.new("UIGradient")
			gradient.Name = "Spin"
			gradient.Color = if mascot.Rarity == "Mythic" then MYTHIC_RAINBOW else SHINY_GOLD
			gradient.Parent = tileOutline
			table.insert(spinning, gradient)
		end
		local holder = make("Frame", {
			Name = "Pet",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.fromOffset(FACE_W - 16, 84),
		}, face)
		MascotView.Viewport(holder, MascotView.Mascot(mascot, 2, false), 0.95)
		-- Shiny: a gold star (the crown is on the 3D pet) and sparkles over the pet
		if mascot.Shiny then
			local star = CrateKit.Icon(face, "Star", 30)
			star.Position = UDim2.fromOffset(6, 62)
			star.ZIndex = 5
			RewardKit.Twinkle(holder, 3, K.Gold)
		end
		-- equipped: a lime tick, top-left
		local tick = UiKit.Icon(face, "Tick", 28)
		tick.Position = UDim2.fromOffset(6, 6)
		tick.ZIndex = 5
		tick.Visible = false
		-- "x3" pill, top-right
		local pill = UiKit.Block(face, {
			Name = "CountPill",
			Size = Vector2.new(44, 26),
			Fill = K.Cover,
			Lip = K.Ink,
			LipPx = 3,
			Radius = 13,
			Outline = 2,
		})
		pill.Holder.Position = UDim2.fromOffset(FACE_W - 50, 6)
		pill.Holder.ZIndex = 5
		local count = RewardKit.Label(pill.Face, "", UiKit.Num, 15, K.Gold, 1.5, 2, 1, 40, 20)
		-- B2: FUSE! under the count once you own enough copies for a Shiny (tap = where to fuse)
		local fuse: GuiObject? = nil
		if Mascots.CoreEggsOn() and Mascots.MergeCost(mascot) then
			local fuseButton = RewardKit.Button(face, "FUSE!", "Gold", 58, 26, 15)
			fuseButton.Holder.Name = "Fuse"
			fuseButton.Holder.Position = UDim2.fromOffset(FACE_W - 64, 36)
			fuseButton.Holder.ZIndex = 6
			fuseButton.Holder.Visible = false
			fuseButton.Activated:Connect(function()
				Sfx.Play("Click")
				showFuseHint()
			end)
			fuse = fuseButton.Holder
		end
		local name =
			RewardKit.Label(face, string.upper(mascot.Name), UiKit.Head, 17, K.White, 2, 6, 94, FACE_W - 12, 22)
		name.Name = "Name"
		local bonus =
			RewardKit.Label(face, Mascots.BoostText(mascot), UiKit.Num, 17, K.Lime, 1.5, 6, 116, FACE_W - 12, 20)
		bonus.Name = "Bonus"
		-- B1: one line per stat in its colour ("+50% COINS" gold, "+20% PINS" pink, bag blue, speed green)
		if Mascots.StatsOn() then
			local lines = Mascots.StatLines(Mascots.Stats(mascot))
			for i, line in lines do
				local label = if i == 1
					then bonus
					else RewardKit.Label(face, "", UiKit.Num, 16, K.Lime, 1.5, 6, 0, FACE_W - 12, 19)
				label.Name = if i == 1 then "Bonus" else "Bonus" .. i
				label.Text = string.upper(line.Text)
				label.TextColor3 = line.Color
				label.Position = UDim2.fromOffset(6, 115 + (i - 1) * 19)
				label.Size = UDim2.fromOffset(FACE_W - 12, 19)
			end
			if #lines == 0 then
				bonus.Text = "NO BOOST"
				bonus.TextColor3 = K.Muted
			end
		end
		local equip = RewardKit.Button(face, "USE", "Lime", FACE_W - 12, 40, 20)
		equip.Holder.Name = "Equip"
		equip.Holder.Position = UDim2.fromOffset(6, FACE_H - 40 - 8)
		equip.Activated:Connect(function()
			local mine = owned()[mascot.Id] or 0
			local inUse = countIn(equipped(), mascot.Id)
			local slots = player:GetAttribute("MascotSlots") or ECONOMY.StartSlots
			if inUse < mine and #equipped() < slots then
				Sfx.Play("PetEquip")
				equipRemote:FireServer(mascot.Id, true)
			elseif inUse > 0 then
				equipRemote:FireServer(mascot.Id, false)
			else
				equip:Shake()
			end
		end)
		table.insert(tiles, {
			Frame = frame,
			Name = name,
			Count = count,
			CountPill = pill.Holder,
			Bonus = bonus,
			Equip = equip,
			Outline = tileOutline,
			Tick = tick,
			Fuse = fuse,
			Mascot = mascot,
		})
	end

	-- What locks each slot past the open ones: rebirths (Mascots.SlotLocks), then (store on) the +2 PET SLOTS pass
	local function lockTexts(slots: number): { string }
		local extra = Store.PetSlots(player)
		local list = Mascots.SlotLocks(player:GetAttribute("Rebirths") or 0, slots - extra)
		if Store.Active() and extra == 0 then
			for _, pass in Config.Monetization.Passes do
				for _ = 1, pass.PetSlots or 0 do
					table.insert(list, "ROBUX PASS")
				end
			end
		end
		return list
	end

	local function refreshSlots()
		for _, child in slotRow:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local list = equipped()
		local slots = player:GetAttribute("MascotSlots") or ECONOMY.StartSlots
		local locks = lockTexts(slots)
		local shown = slots + #locks
		local rowW = PAGE_W - 6 - SIDE_W - 76
		local boxSize = math.min(84, math.floor((rowW - (shown - 1) * 10) / shown))
		for i = 1, shown do
			local open = i <= slots
			local mascot = Mascots.Get(list[i])
			local color = if mascot
				then (if mascot.Shiny then K.Gold else Mascots.RarityColor(mascot.Rarity))
				else K.Dash
			local box = make("TextButton", {
				Name = "Slot" .. i,
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Size = UDim2.fromOffset(boxSize, boxSize),
			}, slotRow) :: TextButton
			local fill = UiKit.Box(box, "Fill", if open then K.Slot else K.Missing, 16, 3, color)
			UiKit.Place(fill, 0, 0, boxSize, boxSize, 3)
			if mascot then
				MascotView.Viewport(fill, MascotView.Mascot(mascot, 2, false), 0.95)
				box.Activated:Connect(function()
					equipRemote:FireServer(mascot.Id, false)
				end)
				UiFx.Press(box)
			elseif open then
				local plus = RewardKit.Label(fill, "+", UiKit.Head, 36, K.Faded, 0, 0, 0, boxSize - 6, boxSize - 6)
				plus.Name = "Empty"
				make("UIPadding", { PaddingTop = UDim.new(0, 6) }, plus)
			else
				local size = boxSize - 6
				HudKit.Image(fill, "Lock", size * 0.42, {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, size * 0.12),
					ImageTransparency = 0.2,
				})
				local lock = RewardKit.Label(
					fill,
					locks[i - slots],
					UiKit.Head,
					15,
					K.LockedText,
					1.5,
					3,
					size * 0.6,
					size - 6,
					size * 0.3
				)
				lock.Name = "Locked"
			end
		end
	end

	local refreshBadge: () -> () -- below, with the tabs
	local currentTab = "Pets"
	local function refresh()
		local mine = owned()
		local list = equipped()
		local slots = player:GetAttribute("MascotSlots") or ECONOMY.StartSlots
		local bonus = player:GetAttribute("MascotBonus") or 0
		-- Found = kinds you have (a Shiny counts for its mascot)
		local kinds, kindsTotal = 0, 0
		for _, tile in tiles do
			local id = tile.Mascot.Id
			if not tile.Mascot.Shiny then
				kindsTotal += 1
				if (mine[id] or 0) > 0 or (mine[Mascots.ShinyId(id)] or 0) > 0 then
					kinds += 1
				end
			end
		end
		if currentTab == "Pets" then
			subLine.Text = ("%d / %d OUT  ·  %d / %d FOUND"):format(#list, slots, kinds, kindsTotal)
		end
		slotsTitle.Text = ("%s COINS"):format(Mascots.BonusText(bonus))
		if Mascots.StatsOn() then
			local totals = Mascots.TotalStats(list)
			for name, label in totalLabels do
				local value = totals[name] or 0
				label.Text = ("%s %s"):format(
					Mascots.PercentText(value),
					string.upper(Config.PetStats.Types[name].Label)
				)
				label.TextColor3 = if value > 0 then Config.PetStats.Types[name].Color else K.Muted
			end
		end

		for _, tile in tiles do
			local mascot = tile.Mascot
			local have = mine[mascot.Id] or 0
			local inUse = countIn(list, mascot.Id)
			tile.Frame.Visible = have > 0
			if have > 0 then
				tile.Count.Text = ("x%d"):format(have)
				tile.CountPill.Visible = have > 1
				tile.Tick.Visible = inUse > 0
				local equip = tile.Equip
				if inUse < have and #list < slots then
					equip:SetText("USE")
					equip:Paint(K.Lime, K.LimeLip, K.White)
				elseif inUse > 0 then
					equip:SetText("UNEQUIP")
					equip:Paint(K.Grey, K.GreyLip, K.White)
				else
					equip:SetText("SLOTS FULL")
					equip:Paint(K.Grey, K.GreyLip, K.LockedText)
				end
				tile.Outline.Thickness = if inUse > 0 then 5 else 3
				if tile.Fuse then
					tile.Fuse.Visible = have >= (Mascots.MergeCost(mascot) or math.huge)
				end
			end
		end
		noPets.Visible = kinds == 0

		refreshBadge()
		refreshSlots()
	end

	-- Which tab is showing; before the pets' zone the PETS tab shows the lock note and the button opens on ITEMS
	local petsLocked: boolean? = nil
	local testEgg: GuiObject? = nil
	local function showTab(name: string)
		currentTab = name
		local pets = name == "Pets"
		for tabName, tab in tabs do
			if tabName == name then
				tab:Paint(K.Pink, K.PinkLip, K.White)
			else
				tab:Paint(K.Chip, K.Ink, K.Muted)
			end
		end
		right.Visible = pets and not petsLocked
		lockedNote.Visible = pets and petsLocked == true
		itemsPage.Visible = not pets
		if testEgg then
			testEgg.Visible = pets
		end
		setTitle(if pets then "PETS" else "ITEMS", if pets then K.Pink else K.Cyan)
		if pets then
			subLine.Text = if petsLocked then "PETS FOLLOW YOU AND BOOST YOUR COINS" else ""
			if Mascots.StatsOn() then
				subLine.Text = "PETS FOLLOW YOU AND BOOST YOUR STATS"
			end
			refresh()
		else
			local potions = PotionController.Count()
			subLine.Text = if potions == 1 then "1 POTION TO DRINK" else ("%d POTIONS TO DRINK"):format(potions)
		end
	end

	-- Badge on the button: potions to drink (their number), else "!" when an egg can be hatched
	-- (B2, roof eggs: when the first egg is affordable and you have no pets yet, or 3 copies wait to be fused)
	function refreshBadge()
		local potions = PotionController.Count()
		local unlocked, _, affordable = eggState()
		petsKit:SetBadge(if potions > 0 then potions else nil)
		if Mascots.CoreEggsOn() then
			local mine = owned()
			local any, fuse = false, false
			for id, count in mine do
				local mascot = Mascots.Get(id)
				if mascot and count > 0 then
					any = true
					fuse = fuse or count >= (Mascots.MergeCost(mascot) or math.huge)
				end
			end
			petsKit:SetDot(potions == 0 and ((not any and affordable) or fuse))
			return
		end
		petsKit:SetDot(potions == 0 and unlocked and affordable)
	end

	local function refreshButton()
		local unlocked, why = eggState()
		local locked = not unlocked and not Mascots.StatsOn() -- (B1: open in the core loop; eggs come to the shop)
		petsButton.Visible = true
		lockedHead.Text = if Config.CoreLoop.Enabled
			then "NO PETS YET"
			else ("PETS UNLOCK IN %s"):format(Zones.Name(EGG.Zone or 1):upper())
		lockedLine.Text = if Config.CoreLoop.Enabled
			then "PETS COME IN A LATER UPDATE"
			else ("%s  ·  THEN HATCH THE NEON EGG AT THE EGG STAND"):format(tostring(why))
		if locked == petsLocked then
			return
		end
		local wasLocked = petsLocked
		petsLocked = locked
		if wasLocked and not locked then
			UiFx.Pop(petsButton, 1.6, 0.4)
		end
		showTab(currentTab)
	end

	-- Toast for errors ("Not enough coins")
	-- (the kit's navy toast at the top centre since UI pass batch 3)
	local kitToast = RewardKit.Toast(gui)
	local function showToast(message: string)
		local upper = message:upper()
		local problem = upper:find("NOT ENOUGH") or upper:find("WRONG") or upper:find("FULL")
		kitToast(upper, nil, nil, if problem then RewardKit.C.Price else RewardKit.C.White, 2)
	end
	showFuseHint = function()
		kitToast(
			("%d COPIES = 1 SHINY (x%s STATS) · FUSE THEM AT THE FUSION MACHINE BY THE EGGS"):format(
				ECONOMY.ShinyMerge,
				tostring(ECONOMY.ShinyMultiplier)
			),
			nil,
			nil,
			RewardKit.C.Gold,
			3
		)
	end

	PotionController.BuildItems(itemsPage, showToast, PAGE_W, PAGE_H)
	for name, tab in tabs do
		tab.Activated:Connect(function()
			if currentTab ~= name then
				showTab(name)
			end
		end)
	end

	-- ===== Hatching =====
	local overlay = Instance.new("TextButton")
	overlay.Name = "Hatching"
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.BackgroundColor3 = Color3.fromRGB(8, 4, 20)
	overlay.BackgroundTransparency = 0.25
	overlay.Size = UDim2.new(1, 0, 1, 120)
	overlay.Position = UDim2.fromOffset(0, -60)
	overlay.Visible = false
	overlay.ZIndex = 30
	overlay.Parent = gui
	-- Glow rings behind the egg, in the rarity colour the glow is showing
	local glowRings = {}
	for i, scale in { 1, 0.75, 0.5 } do
		local ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.45)
		ring.Size = UDim2.fromScale(0.5 * scale, 0.5 * scale)
		ring.BackgroundColor3 = Color3.new(1, 1, 1)
		ring.BackgroundTransparency = 1
		ring.ZIndex = 30 + i
		ring.Parent = overlay
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = ring
		corner(ring)
		glowRings[i] = ring
	end
	-- UI pass batch 5: the Crate Kit's rays turn behind the pet in its rarity colour (screen hatches and merges;
	-- the stand hatch has the 3D stand's own light show)
	local stageRays = make("ImageLabel", {
		Name = "Rays",
		BackgroundTransparency = 1,
		Image = CrateKit.Image("Rays"),
		ImageTransparency = 0.3,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromScale(0.62, 0.62),
		ZIndex = 33,
		Visible = false,
	}, overlay) :: ImageLabel
	make("UIAspectRatioConstraint", {}, stageRays)
	HudKit.Spin(stageRays, 10)
	local stage = Instance.new("Frame")
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.45)
	stage.Size = UDim2.fromScale(0.4, 0.4)
	stage.ZIndex = 34
	stage.Parent = overlay
	local stageAspect = Instance.new("UIAspectRatioConstraint")
	stageAspect.Parent = stage
	local stageScale = Instance.new("UIScale")
	stageScale.Parent = stage
	-- A1 (2026-10-28): the rarity slams in big over the pet on the stand hatch ("LEGENDARY!")
	-- (the overlay starts above the screen's top edge, so 0.11 keeps it clear of the top bar)
	local revealRarity = text(overlay, "Rarity", FONT, GOLD, UDim2.fromScale(0.2, 0.11), UDim2.fromScale(0.6, 0.1))
	revealRarity.Visible = false
	revealRarity.ZIndex = 35
	local rarityStroke = revealRarity:FindFirstChildOfClass("UIStroke")
	if rarityStroke then
		rarityStroke.Thickness = 4
	end

	-- The hatch card (UI pass batch 5): a navy plate ringed in the rarity colour with the rarity chip, the pet's
	-- name, "x1.12 COINS" counting up, the odds and a NEW! stamp; OK (and AUTO on the stand) under it. A triple hatch
	-- puts the other two pets on small cards either side. Design px; it shrinks to fit the screen's bottom part.
	local front = make("Frame", {
		Name = "Front",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 60), -- the real screen inside the taller overlay
		Size = UDim2.new(1, 0, 1, -120),
		ZIndex = 35,
	}, overlay) :: Frame
	local PLATE_W, PLATE_H, SIDE = 520, 150, 150
	local cardHolder = make("Frame", {
		Name = "Card",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(PLATE_W, PLATE_H),
		Visible = false,
	}, front) :: Frame
	local cardFit = make("UIScale", {}, cardHolder) :: UIScale
	local plateBlock = UiKit.Block(cardHolder, {
		Name = "Plate",
		Size = Vector2.new(PLATE_W, PLATE_H),
		Fill = K.Cover,
		Lip = K.Ink,
		LipPx = 6,
		Radius = 24,
		Outline = 4,
		Ring = GOLD,
	})
	local plate = plateBlock.Holder
	local plateFace = plateBlock.Face
	local plateRing = (plateFace:FindFirstChild("Ring") :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke
	-- rarity chip on the plate's top edge
	local chip = UiKit.Block(cardHolder, {
		Name = "RarityChip",
		Size = Vector2.new(190, 40),
		Fill = GOLD,
		Lip = K.GoldLip,
		LipPx = 4,
		Radius = 20,
		Outline = 3,
	})
	chip.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Holder.Position = UDim2.fromOffset(PLATE_W / 2, 2)
	chip.Holder.ZIndex = 3
	local chipText = RewardKit.Label(chip.Face, "", UiKit.Head, 22, K.White, 2.5, 8, 2, 174, 30)
	make("UIPadding", { PaddingTop = UDim.new(0, 3) }, chipText)
	local revealName = RewardKit.Label(plateFace, "", UiKit.Head, 40, K.White, 3, 20, 26, PLATE_W - 48, 48)
	revealName.Name = "Name"
	local revealInfo = RewardKit.Label(plateFace, "", UiKit.Num, 28, K.Lime, 2.5, 20, 74, PLATE_W - 48, 34)
	revealInfo.Name = "Info"
	-- Polish P2: "1 IN X" odds of this exact pet, under its name
	local revealOdds = RewardKit.Label(plateFace, "", UiKit.Body, 15, K.Label, 0, 20, 110, PLATE_W - 48, 20)
	revealOdds.Name = "Odds"
	-- NEW! stamp, tilted on the plate's top-right corner
	local stamp = UiKit.Block(cardHolder, {
		Name = "New",
		Size = Vector2.new(128, 48),
		Fill = K.Lime,
		Lip = K.LimeLip,
		LipPx = 5,
		Radius = 14,
		Outline = 3,
	})
	stamp.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Holder.Position = UDim2.fromOffset(PLATE_W - 40, 4)
	stamp.Holder.ZIndex = 4
	local revealNew = RewardKit.Label(stamp.Face, "NEW", UiKit.Head, 26, K.White, 2.5, 6, 2, 116, 36)
	make("UIPadding", { PaddingTop = UDim.new(0, 3) }, revealNew)
	HudKit.Fit(revealNew, 26) -- batch C3: "AUTO-DELETED" shrinks to fit the stamp

	local doneKit = RewardKit.Button(cardHolder, "OK", "Lime", 200, 62, 30)
	local doneButton = doneKit.Holder
	doneButton.Name = "Done"
	-- Polish P2: AUTO HATCH (stand hatches only): keeps hatching while you can pay; tap it again, CLOSE or the screen to stop
	local autoKit = RewardKit.Button(cardHolder, "AUTO: OFF", "Grey", 200, 62, 26)
	local autoButton = autoKit.Holder
	autoButton.Name = "Auto"
	autoButton.Visible = false
	-- the buttons live under the card, but AUTO also shows alone during AUTO (the card is hidden then)
	local buttonRow = make("Frame", {
		Name = "Buttons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(PLATE_W, 70),
	}, front) :: Frame
	local rowFit = make("UIScale", {}, buttonRow) :: UIScale
	doneButton.Parent = buttonRow
	autoButton.Parent = buttonRow
	local function placeButtons(withAuto: boolean)
		doneButton.Position = UDim2.fromOffset(if withAuto then 50 else (PLATE_W - 200) / 2, 0)
		autoButton.Position = UDim2.fromOffset(if withAuto then 270 else (PLATE_W - 200) / 2, 0)
	end

	-- Triple hatch: the other two pets on small cards left and right of the plate
	type Side = { Holder: GuiObject, Ring: UIStroke, Pet: Frame, Name: TextLabel, New: TextLabel }
	local sides: { Side } = {}
	for i = 1, 2 do
		local block = UiKit.Block(cardHolder, {
			Name = "Extra" .. i,
			Size = Vector2.new(SIDE, PLATE_H),
			Fill = K.Card,
			Lip = K.Page,
			LipPx = 6,
			Radius = 20,
			Outline = 3,
			Ring = GOLD,
		})
		block.Holder.Position = UDim2.fromOffset(if i == 1 then -SIDE - 14 else PLATE_W + 14, 0)
		block.Holder.Visible = false
		local pet = make("Frame", {
			Name = "Pet",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.fromOffset(SIDE - 26, 86),
		}, block.Face) :: Frame
		local name = RewardKit.Label(block.Face, "", UiKit.Head, 16, K.White, 2, 6, 96, SIDE - 18, 22)
		local new = RewardKit.Label(block.Face, "NEW!", UiKit.Head, 15, K.Lime, 2, 6, 116, SIDE - 18, 18)
		HudKit.Fit(new, 15)
		sides[i] = {
			Holder = block.Holder,
			Ring = (block.Face:FindFirstChild("Ring") :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke,
			Pet = pet,
			Name = name,
			New = new,
		}
	end

	local skipHint = RewardKit.Label(front, "TAP TO SKIP", UiKit.Head, 22, K.White, 2.5, 0, 0, 300, 30)
	skipHint.Name = "SkipHint"
	skipHint.AnchorPoint = Vector2.new(0.5, 1)
	skipHint.Position = UDim2.new(0.5, 0, 1, -28)
	skipHint.TextTransparency = 0.15
	skipHint.Visible = false

	-- Card and buttons shrink to fit: full width, and at most 40% of the screen's height
	local function fitCard(wide: number)
		local area = front.AbsoluteSize
		if area.X <= 0 then
			return
		end
		local scale = math.max(0.4, math.min(1, (area.X - 24) / wide, area.Y * 0.4 / (PLATE_H + 100)))
		cardFit.Scale = scale
		rowFit.Scale = scale
		cardHolder.Position = UDim2.new(0.5, 0, 1, -16 - 82 * scale)
	end

	-- Every hatch and merge uses the same card; onStand = AUTO sits next to OK
	local function cardLayout(onStand: boolean)
		revealRarity.Visible = onStand
		revealRarity.Text = ""
		stageRays.Visible = false
		cardHolder.Visible = false
		for _, side in sides do
			side.Holder.Visible = false
		end
		placeButtons(onStand)
		autoButton.Visible = false
		skipHint.Visible = false
	end

	-- Fills and pops the card in. look: Color, Rarity (chip), Name, Stamp ("NEW!" / "SHINY!" / nil), Extras
	local function popCard(look: { [string]: any })
		local color = look.Color
		plateRing.Color = color
		chip:Paint(color, color:Lerp(K.Ink, 0.35))
		chipText.Text = look.Rarity
		revealName.Text = look.Name
		revealName.TextColor3 = color
		stamp.Holder.Visible = look.Stamp ~= nil
		if look.Stamp then
			revealNew.Text = look.Stamp
			stamp:Paint(look.StampColor or K.Lime, (look.StampColor or K.Lime):Lerp(K.Ink, 0.3))
		end
		local wide = PLATE_W
		for i, side in sides do
			local extra = look.Extras and look.Extras[i]
			local other = extra and Mascots.Get(extra.MascotId)
			side.Holder.Visible = other ~= nil
			if other then
				wide = PLATE_W + 2 * (SIDE + 14)
				side.Pet:ClearAllChildren()
				MascotView.Viewport(side.Pet, MascotView.Mascot(other, 2, false), 0.95)
				side.Ring.Color = Mascots.RarityColor(other.Rarity)
				side.Name.Text = string.upper(other.Name)
				side.Name.TextColor3 = Mascots.RarityColor(other.Rarity)
				side.New.Text = if extra.Deleted
					then "AUTO-DELETED"
					elseif extra.IsNew then "NEW!"
					else string.upper(other.Rarity)
				side.New.TextColor3 = if extra.Deleted then CrateKit.C.Red elseif extra.IsNew then K.Lime else K.Muted
			end
		end
		fitCard(wide)
		cardHolder.Visible = true
		-- the plate pops 0.6 -> 1.05 -> 1 (the kit's open pop), the side cards a beat later, the stamp drops on last
		local scale = UiKit.ScaleOf(plate)
		scale.Scale = 0.6
		UiKit.Tween(scale, 0.18, Enum.EasingStyle.Back, { Scale = 1.05 }).Completed:Once(function()
			UiKit.Tween(scale, 0.08, Enum.EasingStyle.Quad, { Scale = 1 })
		end)
		UiFx.Pop(chip.Holder, 0.4, 0.3)
		local shownSides = {}
		for _, side in sides do
			if side.Holder.Visible then
				table.insert(shownSides, side.Holder)
			end
		end
		RewardKit.Stagger(shownSides, 0.08, 0.15)
		if look.Stamp then
			stamp.Holder.Visible = false
			task.delay(0.25, function()
				if cardHolder.Visible then
					stamp.Holder.Visible = true
					RewardKit.Stamp(stamp.Holder)
				end
			end)
		end
	end

	-- "1 IN 4", "1 IN 2.5", "1 IN 1.2K" (chance = 0..1 from the server)
	local function oddsText(chance: number?): string
		if not chance or chance <= 0 then
			return ""
		end
		local x = 1 / chance
		if x < 10 then
			return "1 IN " .. (("%.1f"):format(x):gsub("%.0$", ""))
		end
		return "1 IN " .. formatNumber(math.floor(x + 0.5))
	end

	local function setGlow(color: Color3, strength: number)
		for i, ring in glowRings do
			ring.BackgroundColor3 = color
			ring.BackgroundTransparency = 1 - strength * (0.12 + 0.12 * i)
		end
	end

	-- Mythic hatches pulse the screen edges in the pet's colour
	local edge = Instance.new("Frame")
	edge.Name = "EdgePulse"
	edge.BackgroundTransparency = 1
	edge.Size = UDim2.fromScale(1, 1)
	edge.ZIndex = 31
	edge.Visible = false
	edge.Parent = overlay
	local edgeStroke = stroke(edge, PINK, 28, true)
	local function edgePulse(color: Color3)
		edgeStroke.Color = color
		edge.Visible = true
		task.spawn(function()
			for _ = 1, 2 do
				edgeStroke.Transparency = 0.1
				TweenService:Create(edgeStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
				task.wait(0.3)
			end
			edge.Visible = false
		end)
	end

	local hatching = false
	local spinConnection: RBXScriptConnection? = nil
	-- The lobby's egg stand, once it's built (the hatch plays on it); hatches this session (for auto-skip)
	-- Phase X: one stand per egg (Config.EggStands); currentEgg = the egg being hatched right now
	type Site = { Stand: Model, Spot: BasePart, Egg: Model, Prompt: ProximityPrompt }
	local stands: { [string]: Site } = {}
	local currentEgg = EGG
	local standBusy = false
	local hatchesThisSession = 0
	local sceneContext: any = nil
	local endScene: (() -> ())? = nil
	local hiddenGuis: { ScreenGui } = {}
	local function clearStage()
		if spinConnection then
			spinConnection:Disconnect()
			spinConnection = nil
		end
		for _, child in stage:GetChildren() do
			if child:IsA("ViewportFrame") then
				child:Destroy()
			end
		end
	end

	local doHatch: (egg: any?) -> ()

	local autoHatch = false
	local autoNext: () -> ()
	local function paintAuto()
		autoKit:SetText(if autoHatch then "AUTO: ON" else "AUTO: OFF")
		if autoHatch then
			autoKit:Paint(K.Lime, K.LimeLip, K.White)
		else
			autoKit:Paint(K.Grey, K.GreyLip, K.White)
		end
	end

	local cardToken = nil
	local function showCard(result, mascot)
		local color = Mascots.RarityColor(mascot.Rarity)
		popCard({
			Color = color,
			Rarity = string.upper(mascot.Rarity),
			Name = string.upper(mascot.Name),
			-- batch C3: a pet X'd on the egg board is not kept, and the card says so
			Stamp = if result.Deleted then "AUTO-DELETED" elseif result.IsNew then "NEW!" else nil,
			StampColor = if result.Deleted then CrateKit.C.Red else nil,
			Extras = result.Extras, -- TRIPLE HATCH: the other two pets
		})
		local odds = oddsText(result.Chance)
		local note = if result.Deleted then "NOT KEPT" elseif result.Equipped then "EQUIPPED!" else nil
		revealOdds.Text = if note then (if odds ~= "" then odds .. "  ·  " .. note else note) else odds
		local function info(bonus: number): string
			return Mascots.BonusText(bonus) .. " COINS"
		end
		-- A1: the COINS bonus counts up from x1
		local bonus = Mascots.Bonus(mascot)
		if Mascots.StatsOn() then
			-- B1: every stat counts up from +0% (bonus = 0..1 of the way)
			local stats = Mascots.Stats(mascot)
			bonus = 1
			function info(u: number): string
				local scaled = {}
				for name, value in stats do
					scaled[name] = value * u
				end
				return string.upper(Mascots.StatText(scaled))
			end
		end
		local token = {}
		cardToken = token
		revealInfo.Text = info(0)
		task.spawn(function()
			local started = os.clock()
			while cardToken == token do
				local u = math.min((os.clock() - started) / FX.Hatch.CountUp, 1)
				revealInfo.Text = info(bonus * (1 - (1 - u) ^ 2))
				if u >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
		end)
		for _, label in { revealName, revealInfo } do
			UiFx.Pop(label, 1.5, 0.35)
		end
		-- The rarity title slams in tilted and straightens (the NEW! stamp drops on a beat later)
		if revealRarity.Visible then
			revealRarity.Text = string.upper(mascot.Rarity) .. "!"
			revealRarity.TextColor3 = color
			revealRarity.Rotation = -10
			UiFx.Pop(revealRarity, 2.2, 0.35)
			TweenService:Create(revealRarity, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Rotation = 0 }):Play()
		end
		-- Confetti in the rarity's colours, more the rarer it is
		UiFx.Confetti(
			nil,
			FX.Hatch.Confetti[mascot.Rarity] or 20,
			{ color, color:Lerp(Color3.new(1, 1, 1), 0.5), GOLD }
		)
		skipHint.Visible = false
		doneButton.Visible = true
		UiFx.Pop(doneButton, 0.6, 0.3)
		if sceneContext then
			paintAuto()
			autoButton.Visible = true
			if not autoHatch then
				UiFx.Pop(autoButton, 0.6, 0.3)
			end
		end
	end

	-- Ends a stand hatch: GUIs back, prompt back, camera home (keepCamera = AUTO goes straight into the next egg)
	local function finishStand(keepCamera: boolean?)
		local finish = endScene
		endScene = nil
		if finish then
			finish(keepCamera)
		end
		if keepCamera then
			return
		end
		for _, other in hiddenGuis do
			other.Enabled = true
		end
		table.clear(hiddenGuis)
		standBusy = false
		refreshButton()
		local stand = stands[currentEgg.Id]
		if stand then
			stand.Prompt.Enabled = true
		end
	end

	-- The hatch on the real stand (owner's storyboard): the camera swings in, the egg activates, shakes, cracks,
	-- bursts and the pet rises above the stand. Tap to skip from 0.7s; tap again (or CLOSE) once the card is up.
	-- camera = AUTO HATCH's next egg: the scene is already up (GUIs hidden, camera on the stand)
	local function playOnStand(result, mascot, site, camera: any?)
		hatchesThisSession += 1
		standBusy = true
		site.Prompt.Enabled = false
		if not camera then
			table.clear(hiddenGuis)
			for _, other in playerGui:GetChildren() do
				if other:IsA("ScreenGui") and other ~= gui and other.Name ~= "FxUI" and other.Enabled then
					other.Enabled = false
					table.insert(hiddenGuis, other)
				end
			end
		end
		petsButton.Visible = false
		closePanel()
		cardLayout(true)
		overlay.BackgroundTransparency = 1
		setGlow(GOLD, 0)
		overlay.Visible = true
		doneButton.Visible = false
		autoButton.Visible = autoHatch -- stays up during AUTO so it can be turned off
		skipHint.Visible = not autoHatch
		clearStage()
		local context = {
			Stand = site.Stand,
			Spot = site.Spot,
			Egg = site.Egg,
			Mascot = mascot,
			AutoSkip = autoHatch or hatchesThisSession > FX.Hatch.AutoSkipAfter,
			EdgePulse = edgePulse,
			Camera = camera,
			OnCard = function()
				showCard(result, mascot)
			end,
		}
		sceneContext = context
		local ok, finish = pcall(HatchScene.Play, context)
		if ok then
			endScene = finish
			if sceneContext ~= context then
				finishStand() -- closed while the reveal was still playing
				return
			end
			if autoHatch then
				task.delay(FX.Hatch.AutoNextDelay, function()
					if autoHatch and sceneContext == context then
						autoNext()
					end
				end)
			end
		else
			warn("[MascotController] hatch scene failed: " .. tostring(finish))
			showCard(result, mascot)
		end
	end

	-- AUTO HATCH: the next egg straight from the card. Stops when you can't pay or the server says no.
	local function stopAuto(message: string?)
		autoHatch = false
		paintAuto()
		if message then
			showToast(message)
		end
	end
	autoNext = function()
		local context = sceneContext
		local site = stands[currentEgg.Id]
		if hatching or not context or not site then
			return
		end
		local unlocked, _, affordable = eggState(currentEgg)
		if not unlocked or not affordable then
			stopAuto("AUTO HATCH STOPPED: NOT ENOUGH COINS")
			return
		end
		hatching = true
		local ok, result = pcall(hatchRemote.InvokeServer, hatchRemote, currentEgg.Id)
		hatching = false
		local mascot = ok and result and result.Ok and Mascots.Get(result.MascotId)
		if sceneContext ~= context then
			return -- closed while waiting (the pet is still yours)
		end
		if not mascot then
			stopAuto(if ok and result and result.Error then result.Error else "That didn't work. Try again")
			return
		end
		local camera = context.Camera
		finishStand(true)
		playOnStand(result, mascot, site, camera)
	end

	-- UI overhaul V7 (Config.Ui.HatchV2): every hatch plays the new screen sequence (Modules/HatchV2) instead of the
	-- stand scene. OK / a tap closes it; AUTO keeps hatching from the finished cards until it is stopped or coins run out.
	local hatchV2: any = nil
	local playV2: (result: any, mascot: any) -> ()
	local function closeV2(keepScene: boolean?)
		local current = hatchV2
		hatchV2 = nil
		if current then
			current.Close()
		end
		if keepScene then
			return
		end
		for _, other in hiddenGuis do
			other.Enabled = true
		end
		table.clear(hiddenGuis)
		standBusy = false
		refreshButton()
		local stand = stands[currentEgg.Id]
		if stand then
			stand.Prompt.Enabled = true
		end
	end
	local function autoNextV2()
		local current = hatchV2
		if hatching or not current then
			return
		end
		local unlocked, _, affordable = eggState(currentEgg)
		if not unlocked or not affordable then
			stopAuto("AUTO HATCH STOPPED: NOT ENOUGH COINS")
			current.SetAuto(false)
			return
		end
		hatching = true
		local ok, result = pcall(hatchRemote.InvokeServer, hatchRemote, currentEgg.Id)
		hatching = false
		local mascot = ok and result and result.Ok and Mascots.Get(result.MascotId)
		if hatchV2 ~= current then
			return -- closed while waiting (the pet is still yours)
		end
		if not mascot then
			stopAuto(if ok and result and result.Error then result.Error else "That didn't work. Try again")
			current.SetAuto(false)
			return
		end
		closeV2(true)
		playV2(result, mascot)
	end
	playV2 = function(result, mascot)
		hatchesThisSession += 1
		standBusy = true
		local stand = stands[currentEgg.Id]
		if stand then
			stand.Prompt.Enabled = false
		end
		if #hiddenGuis == 0 then
			for _, other in playerGui:GetChildren() do
				if other:IsA("ScreenGui") and other.Name ~= "FxUI" and other.Enabled then
					other.Enabled = false
					table.insert(hiddenGuis, other)
				end
			end
		end
		petsButton.Visible = false
		closePanel()
		local mine = owned()
		local list = { { Mascot = mascot, IsNew = result.IsNew, Deleted = result.Deleted, Copies = mine[mascot.Id] } }
		for _, extra in result.Extras or {} do
			local other = Mascots.Get(extra.MascotId)
			if other then
				table.insert(list, { Mascot = other, IsNew = extra.IsNew, Deleted = extra.Deleted, Copies = mine[other.Id] })
			end
		end
		local scene
		scene = HatchV2.Play({
			EggId = currentEgg.Id,
			Pets = list,
			Quick = autoHatch or hatchesThisSession > FX.Hatch.AutoSkipAfter,
			Auto = autoHatch,
			SkipFrom = FX.Hatch.SkipFrom,
			OnRevealed = function()
				if autoHatch then
					task.delay(FX.Hatch.AutoNextDelay, function()
						if autoHatch and hatchV2 == scene then
							autoNextV2()
						end
					end)
				end
			end,
			OnOk = function()
				if hatchV2 == scene then
					stopAuto()
					closeV2()
				end
			end,
			OnAuto = function()
				if hatchV2 ~= scene then
					return
				end
				if autoHatch then
					stopAuto()
					scene.SetAuto(false)
					return
				end
				local unlocked, _, affordable = eggState(currentEgg)
				if not unlocked or not affordable then
					showToast("NOT ENOUGH COINS")
					return
				end
				autoHatch = true
				paintAuto()
				scene.SetAuto(true)
				if scene.Revealed() then
					autoNextV2()
				end
			end,
		})
		hatchV2 = scene
	end

	local function play(result)
		local mascot = Mascots.Get(result.MascotId)
		if not mascot then
			return
		end
		if HATCH_V2 then
			playV2(result, mascot)
			return
		end
		local stand = stands[currentEgg.Id]
		if stand and stand.Egg.Parent then
			playOnStand(result, mascot, stand)
			return
		end
		local rarity = Mascots.RarityIndex(mascot.Rarity)
		cardLayout(false)
		overlay.BackgroundTransparency = 0.25
		overlay.Visible = true
		doneButton.Visible = false
		setGlow(Mascots.RarityColor("Common"), 0.3)
		clearStage()

		-- The egg pops in and shakes harder and harder; the glow climbs through the rarities up to the result
		local egg = MascotView.Egg(currentEgg.Id, 4)
		local view = MascotView.Viewport(stage, egg, 0.8)
		view.ZIndex = 34
		UiFx.Pop(stage, 0.4, 0.35)
		local tease = rarity < #Mascots.Rarities and math.random() < FX.TeaseChance
		local started = os.clock()
		local beat = 0
		while os.clock() - started < FX.ShakeTime do
			local t = (os.clock() - started) / FX.ShakeTime
			beat += 1
			local shown = math.max(1, math.ceil(t * rarity))
			local color = Mascots.RarityColor(Mascots.Rarities[shown])
			if tease and t > 0.78 and t < 0.9 then
				color = Mascots.RarityColor(Mascots.Rarities[rarity + 1]) -- a flash of something rarer...
			end
			setGlow(color, 0.3 + 0.6 * t)
			local angle = (if beat % 2 == 0 then 1 else -1) * (6 + 22 * t)
			egg:PivotTo(CFrame.Angles(0, 0, math.rad(angle)))
			Sfx.Play("ReelTick", 0.8 + 0.6 * t)
			task.wait(0.28 - 0.17 * t)
		end
		egg:PivotTo(CFrame.new())

		-- Crack: flash, the egg goes, the mascot pops out
		UiFx.Flash(Mascots.RarityColor(mascot.Rarity), 0.8, 0.5)
		setGlow(Mascots.RarityColor(mascot.Rarity), 1)
		view:Destroy()
		local model = MascotView.Mascot(mascot, 2)
		local mascotView = MascotView.Viewport(stage, model, 0.75)
		mascotView.ZIndex = 34
		UiFx.Pop(stage, 0.3, 0.5)
		local angle = 0
		spinConnection = RunService.RenderStepped:Connect(function(dt)
			angle += dt * 1.2
			model:PivotTo(CFrame.Angles(0, math.sin(angle) * 0.6, 0))
		end)

		stageRays.ImageColor3 = Mascots.RarityColor(mascot.Rarity)
		stageRays.Visible = true
		UiFx.Pop(stageRays, 0.3, 0.4)
		Sfx.Play(if rarity >= Mascots.RarityIndex("Epic") then "RevealBig" else "Reveal")
		showCard(result, mascot)
	end

	doHatch = function(egg)
		if hatching or overlay.Visible or hatchV2 then
			return
		end
		egg = egg or EGG
		currentEgg = egg
		local unlocked, why, affordable = eggState(egg)
		if not unlocked then
			showToast("Unlocks at " .. tostring(why))
			return
		end
		if not affordable then
			showToast(("Need %s coins"):format(formatNumber(egg.Price)))
			return
		end
		hatching = true
		local ok, result = pcall(hatchRemote.InvokeServer, hatchRemote, egg.Id)
		if ok and result and result.Ok then
			play(result)
		else
			showToast(if ok and result and result.Error then result.Error else "That didn't work. Try again")
		end
		hatching = false
	end

	-- Merge: the copies shake together in a gold glow, squeeze into one, flash, and the Shiny pops out
	local merging = false
	doMerge = function(mascot)
		if merging or hatching or overlay.Visible then
			return
		end
		merging = true
		local ok, result = pcall(mergeRemote.InvokeServer, mergeRemote, mascot.Id)
		local shiny = ok and result and result.Ok and Mascots.Get(result.MascotId)
		if not shiny then
			showToast(if ok and result and result.Error then result.Error else "That didn't work. Try again")
			merging = false
			return
		end
		cardLayout(false)
		overlay.BackgroundTransparency = 0.25
		overlay.Visible = true
		doneButton.Visible = false
		clearStage()
		local trio = Instance.new("Model")
		local copies = {}
		for i = 1, Mascots.MergeCost(mascot) or 3 do
			local copy = MascotView.Mascot(mascot, 2, false)
			copy.Parent = trio
			copies[i] = copy
		end
		local function placeCopies(spread: number, wobble: number)
			for i, copy in copies do
				local x = (i - (#copies + 1) / 2) * 2.3 * spread
				local tilt = wobble * (if i % 2 == 0 then 1 else -1)
				copy:PivotTo(CFrame.new(x, 0, 0) * CFrame.Angles(0, 0, math.rad(tilt)))
			end
		end
		placeCopies(1, 0)
		local view = MascotView.Viewport(stage, trio, 0.85)
		view.ZIndex = 34
		UiFx.Pop(stage, 0.4, 0.35)
		Sfx.Play("PetMerge")
		local started = os.clock()
		local beat = 0
		while os.clock() - started < FX.MergeTime do
			local t = (os.clock() - started) / FX.MergeTime
			beat += 1
			setGlow(GOLD, 0.3 + 0.6 * t)
			placeCopies(1 - 0.85 * t, (if beat % 2 == 0 then 1 else -1) * (5 + 15 * t))
			Sfx.Play("ReelTick", 0.9 + 0.6 * t)
			task.wait(0.22 - 0.12 * t)
		end
		UiFx.Flash(GOLD, 0.85, 0.5)
		view:Destroy()
		local model = MascotView.Mascot(shiny, 2)
		local shinyView = MascotView.Viewport(stage, model, 0.75)
		shinyView.ZIndex = 34
		UiFx.Pop(stage, 0.3, 0.5)
		local angle = 0
		spinConnection = RunService.RenderStepped:Connect(function(dt)
			angle += dt * 1.2
			model:PivotTo(CFrame.Angles(0, math.sin(angle) * 0.6, 0))
		end)
		stageRays.ImageColor3 = GOLD
		stageRays.Visible = true
		UiFx.Pop(stageRays, 0.3, 0.4)
		popCard({ Color = GOLD, Rarity = "SHINY", Name = string.upper(shiny.Name), Stamp = "SHINY!", StampColor = GOLD })
		revealInfo.Text = if Mascots.StatsOn()
			then Mascots.BoostText(shiny) -- (B1: stats; every one x ShinyMultiplier)
			else ("%s COINS  ·  WAS %s"):format(
				Mascots.BonusText(Mascots.Bonus(shiny)),
				Mascots.BonusText(Mascots.Bonus(mascot))
			)
		revealOdds.Text = if result.Equipped then "EQUIPPED!" else ""
		for _, label in { revealName, revealInfo } do
			UiFx.Pop(label, 1.5, 0.35)
		end
		Sfx.Play("RevealBig")
		UiFx.Confetti(nil, 60)
		task.wait(0.6)
		doneButton.Visible = true
		UiFx.Pop(doneButton, 0.6, 0.3)
		merging = false
	end

	local function closeOverlay()
		overlay.Visible = false
		cardHolder.Visible = false
		stageRays.Visible = false
		autoButton.Visible = false
		skipHint.Visible = false
		clearStage()
		sceneContext = nil
		if autoHatch then
			stopAuto()
		end
		if endScene then
			finishStand()
		end
	end
	doneButton.Activated:Connect(closeOverlay)
	autoButton.Activated:Connect(function()
		autoHatch = not autoHatch
		paintAuto()
		if autoHatch and doneButton.Visible and endScene then
			autoNext() -- the card is up: go now
		end
	end)
	-- During a stand hatch: a tap skips to the reveal (from 0.7s), and once the card is up a tap closes it
	overlay.Activated:Connect(function()
		if not sceneContext then
			return
		end
		if doneButton.Visible then
			closeOverlay()
		else
			sceneContext.SkipAt = os.clock()
		end
	end)
	-- ===== The fusion window (zone 3's PET FUSION machine; UI pass batch 5) =====
	-- Pick a pet at the bottom; its copies fill the 3 slots, the arrow points at the Shiny it makes (gold ring, star).
	-- FUSE runs the merge (the same server merge and animation as the MERGE button); short = NEED 1 MORE.
	local FW, FH = 640, 450
	local SLOT_SIZE, SLOT_GAP = 104, 12
	local fusionGui = make("ScreenGui", {
		Name = "FusionUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 12,
	}, playerGui) :: ScreenGui
	local fusionWin = RewardKit.Window(fusionGui, FW, FH)
	local fusionCover, fusionX = RewardKit.Cover(
		fusionWin.Panel,
		FW,
		FH,
		"PET FUSION",
		("%d OF THE SAME PET MAKE 1 SHINY: A BIGGER COIN BOOST AND A GOLD CROWN"):format(ECONOMY.ShinyMerge),
		K.Gold
	)
	fusionX.Activated:Connect(function()
		fusionWin:Close()
	end)
	local fusionSlots: { { Box: Frame, Ring: UIStroke, Pet: Frame } } = {}
	for i = 1, ECONOMY.ShinyMerge do
		local box = UiKit.Box(fusionCover, "Slot" .. i, K.Slot, 18, 3, K.Dash)
		UiKit.Place(box, 24 + (i - 1) * (SLOT_SIZE + SLOT_GAP), 124, SLOT_SIZE, SLOT_SIZE, 3)
		local pet = make("Frame", { Name = "Pet", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, box)
		fusionSlots[i] = { Box = box, Ring = box:FindFirstChildOfClass("UIStroke") :: UIStroke, Pet = pet }
	end
	local slotsEnd = 24 + ECONOMY.ShinyMerge * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
	local arrow = UiKit.Icon(fusionCover, "ArrowRight", 56)
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Position = UDim2.fromOffset(slotsEnd + 40, 176)
	-- the Shiny it makes: gold ring, gold star on top for the crown
	local resultX = slotsEnd + 80
	local resultBlock = UiKit.Block(fusionCover, {
		Name = "Result",
		Size = Vector2.new(FW - 24 - resultX, 150),
		Fill = UiKit.Hex("2E2312"),
		Lip = K.Page,
		LipPx = 6,
		Radius = 20,
		Outline = 3,
		Ring = K.Gold,
	})
	resultBlock.Holder.Position = UDim2.fromOffset(resultX, 104)
	local resultRing = (resultBlock.Face:FindFirstChild("Ring") :: Frame):FindFirstChildOfClass("UIStroke") :: UIStroke
	local resultPet = make("Frame", {
		Name = "Pet",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 8),
		Size = UDim2.new(1, -16, 1, -66),
	}, resultBlock.Face) :: Frame
	local crown = CrateKit.Icon(resultBlock.Holder, "Star", 36)
	crown.AnchorPoint = Vector2.new(0.5, 0.5)
	crown.Position = UDim2.fromScale(0.5, 0)
	crown.ZIndex = 6
	local resultName =
		RewardKit.Label(resultBlock.Face, "", UiKit.Head, 18, K.Gold, 2, 6, 88, FW - 24 - resultX - 18, 24)
	-- Batch C2: what the Shiny gives, as a multiplier ("x1.04 COINS")
	local resultBonus =
		RewardKit.Label(resultBlock.Face, "", UiKit.Num, 15, K.Lime, 1.5, 6, 112, FW - 24 - resultX - 18, 20)
	resultBonus.Name = "Bonus"
	local fusionStatus = RewardKit.Label(fusionCover, "", UiKit.Head, 22, K.Price, 2.5, 24, 236, slotsEnd - 24, 30)
	local pickLabel = RewardKit.Label(fusionCover, "PICK A PET", UiKit.Body, 14, K.Muted, 0, 24, 272, 300, 18)
	pickLabel.TextXAlignment = Enum.TextXAlignment.Left
	local picker = make("ScrollingFrame", {
		Name = "Picker",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(24, 292),
		Size = UDim2.fromOffset(FW - 48, 76),
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = K.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.X,
	}, fusionCover) :: ScrollingFrame
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, picker)
	make("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingTop = UDim.new(0, 3) }, picker)
	local fuse = RewardKit.Button(fusionCover, "FUSE!", "Gold", 300, 60, 30)
	fuse.Holder.Name = "Fuse"
	fuse.Holder.Position = UDim2.fromOffset((FW - 300) / 2, FH - 60 - 22)

	local picked: any = nil
	local stopResultTwinkle: (() -> ())? = nil
	local stopArrowPulse: (() -> ())? = nil
	-- Pets you could fuse: every non-Shiny pet you own, most copies first, rarer first on a tie
	local function fusable(): { any }
		local mine = owned()
		local list = {}
		for _, mascot in Config.Mascots do
			if (mine[mascot.Id] or 0) > 0 and Mascots.MergeCost(mascot) then
				table.insert(list, mascot)
			end
		end
		table.sort(list, function(a, b)
			local ca, cb = mine[a.Id] or 0, mine[b.Id] or 0
			if ca ~= cb then
				return ca > cb
			end
			return Mascots.RarityIndex(a.Rarity) > Mascots.RarityIndex(b.Rarity)
		end)
		return list
	end

	local refreshFusion: (animate: boolean?) -> ()
	refreshFusion = function(animate: boolean?)
		local list = fusable()
		local mine = owned()
		local still = false
		for _, mascot in list do
			if picked and mascot.Id == picked.Id then
				still = true
			end
		end
		if not still then
			picked = list[1]
		end
		-- the picker chips
		for _, child in picker:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for order, mascot in list do
			local on = picked ~= nil and mascot.Id == picked.Id
			local chipButton = make("TextButton", {
				Name = mascot.Id,
				Text = "",
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				LayoutOrder = order,
				Size = UDim2.fromOffset(68, 68),
			}, picker) :: TextButton
			local box = UiKit.Box(
				chipButton,
				"Fill",
				if on then UiKit.Hex("2E2312") else K.Card,
				14,
				if on then 4 else 3,
				if on then K.Gold else Mascots.RarityColor(mascot.Rarity)
			)
			UiKit.Place(box, 0, 0, 68, 68, if on then 4 else 3)
			MascotView.Viewport(box, MascotView.Mascot(mascot, 2, false), 0.9)
			local count =
				RewardKit.Label(box, ("x%d"):format(mine[mascot.Id] or 0), UiKit.Num, 15, K.Gold, 1.5, 22, 40, 40, 20)
			count.TextXAlignment = Enum.TextXAlignment.Right
			UiFx.Press(chipButton)
			chipButton.Activated:Connect(function()
				if not picked or picked.Id ~= mascot.Id then
					picked = mascot
					refreshFusion(true)
				end
			end)
		end
		-- the slots fill with your copies
		local need = if picked then Mascots.MergeCost(picked) or ECONOMY.ShinyMerge else ECONOMY.ShinyMerge
		local have = if picked then mine[picked.Id] or 0 else 0
		for i, slot in fusionSlots do
			slot.Pet:ClearAllChildren()
			local filled = picked ~= nil and i <= have
			slot.Ring.Color = if filled then Mascots.RarityColor(picked.Rarity) else K.Dash
			if filled then
				MascotView.Viewport(slot.Pet, MascotView.Mascot(picked, 2, false), 0.9)
			else
				local plus =
					RewardKit.Label(slot.Pet, "+", UiKit.Head, 40, K.Faded, 0, 0, 0, SLOT_SIZE - 6, SLOT_SIZE - 6)
				make("UIPadding", { PaddingTop = UDim.new(0, 8) }, plus)
			end
			if animate and filled then
				local scale = UiKit.ScaleOf(slot.Pet)
				scale.Scale = 0.01
				task.delay(0.05 + (i - 1) * 0.09, function()
					Sfx.Play("ReelTick", 1 + i * 0.12)
					UiKit.Tween(scale, 0.2, Enum.EasingStyle.Back, { Scale = 1 })
				end)
			end
		end
		-- the Shiny it makes
		resultPet:ClearAllChildren()
		local ready = picked ~= nil and have >= need
		if stopResultTwinkle then
			stopResultTwinkle()
			stopResultTwinkle = nil
		end
		if stopArrowPulse then
			stopArrowPulse()
			stopArrowPulse = nil
		end
		if picked then
			local shiny = Mascots.Get(Mascots.ShinyId(picked.Id))
			local view = MascotView.Viewport(resultPet, MascotView.Mascot(shiny or picked, 2, false), 0.95)
			view.ImageColor3 = if ready then Color3.new(1, 1, 1) else Color3.fromRGB(70, 70, 95) -- dark until ready
			resultName.Text = ("SHINY %s"):format(string.upper(picked.Name))
			resultBonus.Text = if shiny then Mascots.BoostText(shiny) else ""
		else
			resultName.Text = "SHINY ?"
			resultBonus.Text = ""
		end
		resultRing.Color = if ready then K.Gold else K.Grey
		crown.ImageTransparency = if ready then 0 else 0.55
		arrow.ImageTransparency = if ready then 0 else 0.5
		if ready then
			stopResultTwinkle = RewardKit.Twinkle(resultBlock.Holder, 4, K.Gold)
			stopArrowPulse = RewardKit.Pulse(arrow, 1.15, 0.4)
		end
		if not picked then
			fusionStatus.Text = "NO PETS YET: HATCH AN EGG"
			fusionStatus.TextColor3 = K.Price
			fuse:SetText("NEED 3 PETS")
		elseif ready then
			fusionStatus.Text = "READY TO FUSE!"
			fusionStatus.TextColor3 = K.Lime
			fuse:SetText("FUSE!")
		else
			fusionStatus.Text = ("NEED %d MORE"):format(need - have)
			fusionStatus.TextColor3 = K.Price
			fuse:SetText(("NEED %d MORE"):format(need - have))
		end
		if ready then
			fuse:Paint(K.Gold, K.GoldLip, K.White)
		else
			fuse:Paint(K.Grey, K.GreyLip, K.LockedText)
		end
	end

	fuse.Activated:Connect(function()
		local mascot = picked
		local need = mascot and Mascots.MergeCost(mascot)
		if not mascot or not need or (owned()[mascot.Id] or 0) < need then
			fuse:Shake()
			return
		end
		fusionWin:Close()
		task.spawn(doMerge, mascot)
	end)
	fusionWin.Closed.Event:Connect(function()
		if stopResultTwinkle then
			stopResultTwinkle()
			stopResultTwinkle = nil
		end
		if stopArrowPulse then
			stopArrowPulse()
			stopArrowPulse = nil
		end
	end)
	player:GetAttributeChangedSignal("Mascots"):Connect(function()
		if fusionWin:IsOpen() then
			refreshFusion(false)
		end
	end)
	-- UI overhaul V6: the FUSE PETS window in the new look (Modules/EggV2); the one above stays for EggV2 = false
	local fuseV2 = if EGG_V2
		then EggV2.Fusion({
			Fusable = fusable,
			Owned = owned,
			Fuse = function(mascot)
				task.spawn(doMerge, mascot)
			end,
		})
		else nil
	MascotController.OpenFusion = function()
		if fusionWin:IsOpen() or overlay.Visible or (fuseV2 and fuseV2.IsOpen()) then
			return
		end
		closePanel()
		if fuseV2 then
			fuseV2.Open()
			return
		end
		refreshFusion(true)
		fusionWin:Open()
	end

	-- Polish P4: a pointing hand on EQUIP BEST the first time it would change your pets (Config.EquipBestHint).
	-- It stays until EQUIP BEST is tapped once; the server remembers that in the save (EquipBestHinted).
	local HINT = Config.EquipBestHint
	local hintWanted = false
	local hand = Instance.new("TextLabel")
	hand.Name = "EquipBestHand"
	hand.BackgroundTransparency = 1
	hand.AnchorPoint = Vector2.new(1, 0.5)
	hand.Size = UDim2.fromOffset(46, 46)
	hand.Text = HINT.Hand
	hand.TextScaled = true
	hand.FontFace = FONT
	hand.TextColor3 = GOLD
	hand.ZIndex = 20
	hand.Visible = false
	hand.Parent = gui
	local function refreshHint()
		if not HINT.Enabled or player:GetAttribute("EquipBestHinted") ~= 0 then
			hintWanted = false -- used already (or the save hasn't loaded yet)
			return
		end
		-- would EQUIP BEST raise your pet bonus? (a swap between two equally good pets doesn't count)
		local slots = player:GetAttribute("MascotSlots") or ECONOMY.StartSlots
		local ctx = Mascots.BestContext(player) -- (A5 F: EQUIP BEST ranks by real income)
		local function total(list: { string }): number
			if ctx then
				return Mascots.Income(Mascots.TotalStats(list), ctx)
			end
			local sum = 0
			for _, id in list do
				local mascot = Mascots.Get(id)
				sum += if mascot then Mascots.Score(mascot) else 0 -- (B1: every stat counts)
			end
			return sum
		end
		hintWanted = total(Mascots.Best(owned(), slots, ctx)) > total(equipped()) * (1 + 1e-6) + 1e-6
	end
	for _, key in { "Mascots", "EquippedMascots", "MascotSlots", "EquipBestHinted", "BagLevel", "BallStep", "Rebirths" } do
		player:GetAttributeChangedSignal(key):Connect(refreshHint)
	end
	refreshHint()
	RunService.RenderStepped:Connect(function()
		local target = if PETS_V2 then PetsV2.BestButton() else bestButton
		local panelOpen = if PETS_V2
			then PetsV2.IsOpen() and PetsV2.Tab() == "Pets"
			else gui.Enabled and win:IsOpen() and right.Visible
		local show = hintWanted and panelOpen and target.Visible and not target:GetAttribute("KitDisabled")
		hand.Visible = show
		if show then
			local pos, size = target.AbsolutePosition, target.AbsoluteSize
			if PETS_V2 then
				pos += GuiService:GetGuiInset() -- (the new window's gui ignores the top bar inset; this hand's sits under it)
			end
			local push = math.abs(math.sin(os.clock() * 5)) * HINT.Bob
			hand.Position = UDim2.fromOffset(pos.X - 2 + push, pos.Y + size.Y / 2)
		end
	end)

	-- B2: the Mythic / Shiny card frames turn while the panel is open
	if #spinning > 0 then
		RunService.RenderStepped:Connect(function(dt)
			if win:IsOpen() and right.Visible then
				for _, gradient in spinning do
					gradient.Rotation = (gradient.Rotation + dt * 90) % 360
				end
			end
		end)
	end

	bestButton.Activated:Connect(function()
		hintWanted = false -- the server saves it; hide the hand right away
		Sfx.Play("PetEquip")
		bestRemote:FireServer()
	end)

	-- Pops the cards you can see in one after another (the first dozen)
	local function staggerCards()
		local shown = {}
		for _, tile in tiles do
			if tile.Frame.Visible then
				table.insert(shown, tile.Frame)
			end
		end
		table.sort(shown, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		while #shown > 12 do
			table.remove(shown)
		end
		RewardKit.Stagger(shown, 0.03, 0.12)
	end
	local function openPanel(tab: string)
		if PETS_V2 then
			PetsV2.SetOpen(true, if petsLocked then "Items" else tab)
			return
		end
		showTab(tab)
		win:Open()
		if tab == "Pets" and not petsLocked then
			staggerCards()
		end
	end
	petsButton.Activated:Connect(function()
		if win:IsOpen() or (PETS_V2 and PetsV2.IsOpen()) then
			closePanel()
		else
			openPanel(if petsLocked then "Items" else currentTab)
		end
	end)
	closeX.Activated:Connect(function()
		win:Close()
	end)
	-- Opens the panel on the pets
	MascotController.OpenPets = function()
		openPanel(if petsLocked then "Items" else "Pets")
	end

	-- UI overhaul V5 (Config.Ui.PetsV2): the PETS button opens the new window (Modules/PetsV2); this controller keeps
	-- the remotes, hatching, fusion and the EQUIP BEST hand. The old window above is only used with PetsV2 = false.
	if PETS_V2 then
		local testPotions = remotes:FindFirstChild("TestPotions") :: RemoteEvent?
		PetsV2.Start({
			Equip = function(id: string, on: boolean)
				equipRemote:FireServer(id, on)
			end,
			EquipBest = function()
				hintWanted = false -- the server saves it; hide the hand right away
				Sfx.Play("PetEquip")
				bestRemote:FireServer()
			end,
			FuseText = ("%d COPIES = 1 SHINY! FUSE THEM AT THE FUSION MACHINE"):format(ECONOMY.ShinyMerge),
			LockTexts = lockTexts,
			Locked = function(): (string?, string?)
				if petsLocked then
					return lockedHead.Text, lockedLine.Text
				end
				return nil, nil
			end,
			GoToEggs = if Mascots.CoreEggsOn() and goRemote
				then function()
					Sfx.Play("Click")
					goRemote:FireServer("Eggs")
				end
				else nil,
			Potions = PotionController,
			TestEgg = if remotes:FindFirstChild("TestEgg")
				then function()
					(remotes:FindFirstChild("TestEgg") :: RemoteEvent):FireServer()
				end
				else nil,
			TestPotions = if testPotions
				then function()
					testPotions:FireServer()
				end
				else nil,
		})
		hand.Parent = PetsV2.Gui()
		closePanel = function()
			win:Close()
			PetsV2.SetOpen(false)
		end
	end

	-- Studio only: get to the egg's level and its price in coins (the server ignores this in the live game)
	local testRemote = remotes:FindFirstChild("TestEgg") :: RemoteEvent?
	if testRemote then
		local test = button(
			cover,
			"TestEgg",
			"TEST: EGG",
			Color3.fromRGB(60, 60, 80),
			UDim2.new(0, 24, 1, -22),
			UDim2.fromOffset(120, 20)
		)
		test.TextColor3 = Color3.new(1, 1, 1)
		test.ZIndex = 6
		test.Activated:Connect(function()
			testRemote:FireServer()
		end)
		testEgg = test
	end

	for _, key in
		{ "Mascots", "EquippedMascots", "MascotSlots", "MascotBonus", "MascotStats", "Coins", "RankLevel", "ZonesOpen", "CoreZonesOpen" }
	do
		player:GetAttributeChangedSignal(key):Connect(function()
			refreshButton()
			if win:IsOpen() or key ~= "Coins" then
				refresh()
			else
				refreshBadge()
			end
		end)
	end
	player:GetAttributeChangedSignal("Potions"):Connect(function()
		refreshBadge()
		if win:IsOpen() and currentTab == "Items" then
			showTab("Items")
		end
	end)
	refresh()
	refreshButton()
	showTab(currentTab)
	gui.Parent = playerGui

	-- ===== The egg stands (Config.EggStands: the lobby's Neon Egg, zone 3's and zone 4's) =====
	local function buildStand(row)
		local egg = Mascots.GetEgg(row.Egg)
		local look = Config.EggLooks[row.Egg]
		if not egg or not look or not Mascots.EggReady(egg.Id) then
			return
		end
		-- The Neon stand (the owner's design, a Studio model): the egg sits in its cradle, at NeonStand.EggSpot
		local pad: Instance? = Workspace
		for _, name in row.Path do
			pad = pad and pad:WaitForChild(name, 30)
		end
		local standModel = pad and pad:WaitForChild("NeonStand", 10) :: Model?
		local spot = standModel and standModel:WaitForChild("EggSpot", 10) :: BasePart?
		if not spot or not pad then
			warn(
				("[MascotController] %s.NeonStand.EggSpot not found: no %s stand"):format(
					table.concat(row.Path, "."),
					look.Name
				)
			)
			return
		end
		local standEgg = MascotView.Egg(egg.Id, spot.Size.Y)
		standEgg.Name = "StandEgg"
		standEgg:PivotTo(spot.CFrame)
		local base = spot.Position
		local shell = standEgg.PrimaryPart :: BasePart
		local light = Instance.new("PointLight")
		light.Color = look.Color
		light.Range = 12
		light.Brightness = 1.5
		light.Parent = shell
		standEgg.Parent = pad

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HatchPrompt"
		prompt.ObjectText = look.Name
		prompt.HoldDuration = FX.HoldDuration
		prompt.MaxActivationDistance = FX.PromptDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = shell
		prompt.Triggered:Connect(function()
			task.spawn(doHatch, egg)
		end)

		-- Price and lock just above the stand's sign (the sign itself shows the name)
		local board = Instance.new("BillboardGui")
		board.Name = "EggInfo"
		board.Size = UDim2.fromOffset(220, 32)
		board.StudsOffset = Vector3.new(0, spot.Size.Y * 1.28, 0)
		board.MaxDistance = 70
		board.LightInfluence = 0
		board.Parent = shell
		local boardPrice = text(board, "Price", FONT, GOLD, UDim2.new(), UDim2.fromScale(1, 1))

		stands[egg.Id] = { Stand = standModel :: Model, Spot = spot, Egg = standEgg, Prompt = prompt }

		local function refreshStand()
			local unlocked, why = eggState(egg)
			local free = freeEggs(egg)
			boardPrice.Text = if not unlocked
				then "REACH " .. tostring(why)
				elseif free > 0 then ("FREE EGG x%d"):format(free)
				else formatNumber(egg.Price) .. " COINS"
			boardPrice.TextColor3 = if not unlocked then GREY elseif free > 0 then LIME else GOLD
			prompt.ActionText = if not unlocked
				then "Locked"
				elseif free > 0 then "Hatch (FREE)"
				else ("Hatch (%s)"):format(formatNumber(egg.Price))
		end
		player:GetAttributeChangedSignal("RankLevel"):Connect(refreshStand)
		player:GetAttributeChangedSignal("ZonesOpen"):Connect(refreshStand)
		player:GetAttributeChangedSignal("CoreZonesOpen"):Connect(refreshStand)
		player:GetAttributeChangedSignal("FreeEgg_" .. egg.Id):Connect(refreshStand)
		refreshStand()

		-- UI overhaul V6 (Config.Ui.EggV2): one board in the new look (Modules/EggV2) with the price, the odds, the
		-- auto-delete X's and HATCH / AUTO / x3. The hold-E prompt stays (no UI of its own): E presses HATCH.
		if EGG_V2 then
			prompt.Style = Enum.ProximityPromptStyle.Custom
			local storeBuy = remotes:FindFirstChild("StoreBuy") :: RemoteEvent?
			local boardV2 = EggV2.Board({
				Egg = egg,
				Shell = shell,
				Base = base,
				Pets = (function()
					local list = Mascots.InEgg(egg.Id)
					table.sort(list, function(first, second)
						local a, b = Mascots.RarityIndex(first.Rarity), Mascots.RarityIndex(second.Rarity)
						if a ~= b then
							return a < b
						end
						return first.Id < second.Id
					end)
					return list
				end)(),
				Prompt = prompt,
				State = function()
					local unlocked, why, affordable = eggState(egg)
					return unlocked, why, freeEggs(egg), affordable
				end,
				Odds = function()
					local luck = Store.Luck(player)
					local odds = Store.LuckyOdds(Mascots.EggOdds(egg.Id), luck, Mascots.LuckFrom(egg.Id))
					local chances = {}
					for _, mascot in Mascots.InEgg(egg.Id) do
						chances[mascot] = Mascots.Chance(egg.Id, mascot, odds)
					end
					return chances
				end,
				LuckText = function()
					local luck = Store.Luck(player)
					return if luck > 1 then ("LUCKY x%s ODDS"):format((("%.1f"):format(luck):gsub("%.0$", ""))) else ""
				end,
				Busy = function()
					return standBusy or overlay.Visible
				end,
				Hatch = function()
					task.spawn(doHatch, egg)
				end,
				Auto = function()
					if autoHatch then
						stopAuto()
						return
					end
					local unlocked, _, affordable = eggState(egg)
					if unlocked and affordable then
						autoHatch = true
						paintAuto()
					end
					task.spawn(doHatch, egg)
				end,
				AutoOn = function()
					return autoHatch
				end,
				TripleOwned = function()
					return Store.Owns(player, "TripleHatch")
				end,
				BuyTriple = function()
					if storeBuy then
						storeBuy:FireServer("TripleHatch")
					else
						showToast("THE STORE IS CLOSED")
					end
				end,
				Toast = showToast,
				AutoDeleteRemote = if Config.AutoDelete.Enabled then autoDeleteRemote else nil,
			})
			-- the little price line over the egg only shows while the board is away
			RunService.Heartbeat:Connect(function()
				board.Enabled = not boardV2.Shown()
			end)
		else
			-- Polish P3: odds bubbles over the stand (Config.EggOdds): each pet this egg hatches, turning in 3D, with its
			-- chance (same maths as the server's roll, LUCKY passes included). They fade in when you walk near.
			local ODDS_FX = Config.EggOdds
			local pets = Mascots.InEgg(egg.Id)
			local oddsBoard = Instance.new("BillboardGui")
			oddsBoard.Name = "EggOdds"
			local perRow = math.min(#pets, ODDS_FX.PerRow)
			local rows = math.ceil(#pets / ODDS_FX.PerRow)
			local cardW, cardH = ODDS_FX.CardSize, ODDS_FX.CardSize * 1.3
			local boardW = perRow * cardW + (perRow - 1) * ODDS_FX.Gap
			-- batch C3: tap a pet to X it out (Config.AutoDelete); a hint line goes under the bubbles
			local AUTO_DELETE = Config.AutoDelete
			local hintH = if AUTO_DELETE.Enabled then 0.5 else 0
			local boardH = rows * cardH + (rows - 1) * ODDS_FX.Gap + 0.8 + hintH -- + the LUCKY line on top
			oddsBoard.Size = UDim2.fromScale(boardW, boardH) -- scale = studs, so it is the same size on every screen
			oddsBoard.StudsOffset = Vector3.new(0, ODDS_FX.Height + boardH / 2, 0) -- bottom edge at Height
			oddsBoard.LightInfluence = 0
			oddsBoard.Active = true -- the pet bubbles take taps (batch C3)

			oddsBoard.Enabled = false
			-- Final changes 11a: pinned to the stand from PlayerGui. Pet viewports on a billboard parented in the Workspace
			-- often don't draw (Roblox bug), so players saw empty cards.
			oddsBoard.Adornee = shell
			oddsBoard.ResetOnSpawn = false
			oddsBoard.Parent = player:WaitForChild("PlayerGui")

			-- Everything that fades, with its fully-shown transparency
			local fading: { { any } } = {}
			local function fadeWith(instance: Instance, property: string)
				table.insert(fading, { instance, property, (instance :: any)[property] })
			end
			local luckLine = text(oddsBoard, "Luck", FONT, LIME, UDim2.new(), UDim2.fromScale(1, 0.8 / boardH))
			luckLine.TextScaled = true
			fadeWith(luckLine, "TextTransparency")
			local luckStroke = luckLine:FindFirstChildOfClass("UIStroke")
			if luckStroke then
				fadeWith(luckStroke, "Transparency")
			end

			table.sort(pets, function(first, second)
				local a, b = Mascots.RarityIndex(first.Rarity), Mascots.RarityIndex(second.Rarity)
				if a ~= b then
					return a < b
				end
				return first.Id < second.Id
			end)
			local percents: { [any]: TextLabel } = {}
			local spinners: { Model } = {}
			local crosses: { [string]: TextLabel } = {}
			local markedForDelete: { [string]: boolean } = {}
			for index, mascot in pets do
				local column = (index - 1) % ODDS_FX.PerRow
				local line = (index - 1) // ODDS_FX.PerRow
				local inRow = if line == rows - 1 then #pets - line * ODDS_FX.PerRow else perRow
				local rowStart = (boardW - (inRow * cardW + (inRow - 1) * ODDS_FX.Gap)) / 2 -- last row is centred
				local color = Mascots.RarityColor(mascot.Rarity)
				local card = Instance.new("Frame")
				card.Name = mascot.Id
				card.BackgroundColor3 = CARD
				card.BackgroundTransparency = 0.25
				card.Position = UDim2.fromScale(
					(rowStart + column * (cardW + ODDS_FX.Gap)) / boardW,
					(0.8 + line * (cardH + ODDS_FX.Gap)) / boardH
				)
				card.Size = UDim2.fromScale(cardW / boardW, cardH / boardH)
				card.Parent = oddsBoard
				fadeWith(card, "BackgroundTransparency")
				local round = Instance.new("UICorner")
				round.CornerRadius = UDim.new(0.18, 0)
				round.Parent = card
				local rim = Instance.new("UIStroke")
				rim.Color = color
				rim.Thickness = 3
				rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				rim.Parent = card
				fadeWith(rim, "Transparency")
				local holder = Instance.new("Frame")
				holder.Name = "Pet"
				holder.BackgroundTransparency = 1
				holder.Size = UDim2.fromScale(1, cardW / cardH)
				holder.Parent = card
				local model = MascotView.Mascot(mascot, 2, false)
				local view = MascotView.Viewport(holder, model, ODDS_FX.PetFill)
				fadeWith(view, "ImageTransparency")
				table.insert(spinners, model)
				local percent = text(
					card,
					"Chance",
					FONT,
					color,
					UDim2.fromScale(0.04, cardW / cardH - 0.06),
					UDim2.fromScale(0.92, 1 - cardW / cardH + 0.02)
				)
				percent.TextScaled = true
				fadeWith(percent, "TextTransparency")
				local percentStroke = percent:FindFirstChildOfClass("UIStroke")
				if percentStroke then
					fadeWith(percentStroke, "Transparency")
				end
				percents[mascot] = percent

				-- batch C3: a big red X over the bubble while this pet is X'd; tapping the bubble toggles it
				if AUTO_DELETE.Enabled then
					local cross = text(card, "AutoDeleteX", FONT, AUTO_DELETE.XColor, UDim2.new(), UDim2.fromScale(1, 1))
					cross.Text = "X"
					cross.ZIndex = 5
					cross.Visible = false
					local crossStroke = cross:FindFirstChildOfClass("UIStroke")
					if crossStroke then
						crossStroke.Thickness = 3
						fadeWith(crossStroke, "Transparency")
					end
					fadeWith(cross, "TextTransparency")
					crosses[mascot.Id] = cross
					local tap = Instance.new("TextButton")
					tap.Name = "Tap"
					tap.BackgroundTransparency = 1
					tap.Text = ""
					tap.Size = UDim2.fromScale(1, 1)
					tap.ZIndex = 6
					tap.Parent = card
					tap.Activated:Connect(function()
						if Mascots.RarityIndex(mascot.Rarity) > Mascots.RarityIndex(AUTO_DELETE.MaxRarity) then
							showToast(AUTO_DELETE.TooRare:format(string.upper(mascot.Rarity)))
							return
						end
						local on = not markedForDelete[mascot.Id]
						markedForDelete[mascot.Id] = if on then true else nil
						cross.Visible = on -- straight away; the server's AutoDelete attribute confirms it
						Sfx.Play("Click")
						autoDeleteRemote:FireServer(mascot.Id, on)
					end)
				end
			end
			if AUTO_DELETE.Enabled then
				local hint = text(
					oddsBoard,
					"AutoDeleteHint",
					FONT,
					Color3.new(1, 1, 1),
					UDim2.fromScale(0, 1 - hintH / boardH),
					UDim2.fromScale(1, hintH / boardH)
				)
				hint.Text = AUTO_DELETE.Hint
				fadeWith(hint, "TextTransparency")
				local hintStroke = hint:FindFirstChildOfClass("UIStroke")
				if hintStroke then
					fadeWith(hintStroke, "Transparency")
				end
				local function refreshCrosses()
					markedForDelete = {}
					for id in string.gmatch(player:GetAttribute("AutoDelete") or "", "[^,]+") do
						markedForDelete[id] = true
					end
					for id, cross in crosses do
						cross.Visible = markedForDelete[id] == true
					end
				end
				player:GetAttributeChangedSignal("AutoDelete"):Connect(refreshCrosses)
				refreshCrosses()
			end

			-- "40%", "2.5%", "0.25%", "0.01%": always short enough for a bubble
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
			local function refreshOdds()
				local luck = Store.Luck(player)
				local odds = Store.LuckyOdds(Mascots.EggOdds(egg.Id), luck, Mascots.LuckFrom(egg.Id)) -- (B2: each roof egg has its own odds)
				for mascot, label in percents do
					label.Text = percentText(Mascots.Chance(egg.Id, mascot, odds))
				end
				luckLine.Text = if luck > 1 then ("LUCKY x%s ODDS"):format((("%.1f"):format(luck):gsub("%.0$", ""))) else ""
			end
			player:GetAttributeChangedSignal("Passes"):Connect(refreshOdds)
			refreshOdds()

			local function setAlpha(alpha: number)
				for _, entry in fading do
					local shown = entry[3]
					entry[1][entry[2]] = shown + (1 - shown) * (1 - alpha)
				end
				oddsBoard.Enabled = alpha > 0.001
			end
			setAlpha(0)
			local alpha = 0
			local showing = false
			local spin = 0
			RunService.RenderStepped:Connect(function(dt)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local distance = if root then ((root.Position - base) * Vector3.new(1, 0, 1)).Magnitude else math.huge
				if distance <= ODDS_FX.ShowDistance then
					showing = true
				elseif distance > ODDS_FX.HideDistance then
					showing = false
				end
				local target = if showing and not standBusy then 1 else 0
				if alpha ~= target then
					local step = dt / math.max(ODDS_FX.FadeTime, 0.01)
					alpha = if target > alpha then math.min(target, alpha + step) else math.max(target, alpha - step)
					setAlpha(alpha)
				end
				if alpha > 0 and ODDS_FX.Spin ~= 0 then
					spin += math.rad(ODDS_FX.Spin) * dt
					local turn = CFrame.Angles(0, spin, 0)
					for _, model in spinners do
						model:PivotTo(turn)
					end
				end
			end)
		end

		-- Idle (hatch storyboard frame 1): the core pulses slowly while the camera is near
		local rig = PetIdle.Rig(standEgg, "Egg_" .. egg.Id, 1)
		if rig then
			RunService.RenderStepped:Connect(function()
				local camera = Workspace.CurrentCamera
				local near = camera ~= nil and (camera.CFrame.Position - base).Magnitude <= Config.PetIdle.ShowDistance
				rig:Step(os.clock(), near and not standBusy) -- the hatch drives the egg itself
			end)
		end
	end
	for _, row in Config.EggStands do
		task.spawn(buildStand, row)
	end
end

return MascotController
