-- Mascots on screen (Addendum 2 Phase 3 step 8): the PETS button, the mascot panel, the hatching moment and the
-- egg stand in the lobby (Workspace.Hub.EggPad, the old daily-reward pad).
-- Hatching happens only at the egg stand (owner's call, 2026-10-19): the panel shows your equipped slots with
-- EQUIP BEST and only the pets you own, with EQUIP buttons (owner 2026-10-21: no egg card, no silhouettes). Step 8b: a MERGE button when you own
-- Config.Economy.Mascots.ShinyMerge of one mascot, and gold Shiny cards once you own a Shiny.
-- Owner 2026-10-22: the panel has two tabs, PETS and ITEMS (the potions, PotionController.BuildItems). The button is
-- always open; before the pets' zone the PETS tab shows where pets unlock and the button opens on ITEMS.
-- Built in code (not in Studio), so it lives in git. The server rolls every hatch (MascotService); this only shows it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Mascots = require(Shared.Modules.Mascots)
local Zones = require(Shared.Modules.Zones)
local PotionController = require(script.Parent.PotionController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local HatchScene = require(Modules:WaitForChild("HatchScene"))
local MascotView = require(Modules:WaitForChild("MascotView"))
local PetIdle = require(Modules:WaitForChild("PetIdle"))
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))
local HudKit = require(Modules:WaitForChild("HudKit"))

local player = Players.LocalPlayer

local FX = Config.MascotFx
local ECONOMY = Config.Economy.Mascots
local EGG = Config.Economy.Eggs[1] -- the Neon Egg (Id "Alley"); zone 3 and 4 eggs hatch at their own stands (Phase X)

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local INK = Color3.fromHex("06060F")
local CARD = Color3.fromRGB(30, 20, 60)
local SLOT = Color3.fromRGB(22, 14, 44)
local PINK = Color3.fromRGB(255, 60, 210)
local GOLD = Color3.fromRGB(255, 200, 40)
local LIME = Color3.fromRGB(125, 255, 60)
local GREY = Color3.fromRGB(120, 110, 150)

local MascotController = {}

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
	local unlocked, why = Mascots.EggUnlocked(egg, level, Zones.Highest(level))
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
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local ballsUI = playerGui:WaitForChild("BallsUI") :: ScreenGui
	local inventory = ballsUI:WaitForChild("Inventory") :: Frame

	local gui = Instance.new("ScreenGui")
	gui.Name = "MascotUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = ballsUI.DisplayOrder
	gui.IgnoreGuiInset = ballsUI.IgnoreGuiInset

	-- PETS button (owner's HUD Kit: pink, paw icon). Count badge = potions to drink; red dot = an egg to hatch.
	local petsKit =
		HudKit.Square(gui, { Name = "PetsButton", Paint = "Pink", Icon = "Paw", Caption = "PETS", Key = "Pets" })
	local petsButton = petsKit.Holder :: TextButton
	petsButton.Visible = false

	-- The panel borrows the ball inventory's look (like the collection book does)
	local panel = inventory:Clone()
	panel.Name = "Panel"
	panel.Visible = false
	for _, name in { "Grid", "TileTemplate", "Detail" } do
		local child = panel:FindFirstChild(name)
		if child then
			child:Destroy()
		end
	end
	local outline = panel:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Color = PINK
	end
	local title = panel:WaitForChild("Title") :: TextLabel
	title.Text = "PETS"
	title.TextColor3 = PINK
	local countLabel = panel:WaitForChild("Count") :: TextLabel
	local close = panel:WaitForChild("Close") :: TextButton
	panel.Parent = gui

	-- Tabs: PETS and ITEMS (potions), top-right next to the close button
	local tabs = {}
	for index, info in { { "Pets", "PETS" }, { "Items", "ITEMS" } } do
		local tab = button(
			panel,
			info[1] .. "Tab",
			info[2],
			CARD,
			UDim2.new(1, -264 + (index - 1) * 102, 0, 10),
			UDim2.fromOffset(96, 32)
		)
		tab.ZIndex = 3
		tabs[info[1]] = tab
	end
	-- The ITEMS page (filled by PotionController.BuildItems once the toast exists)
	local itemsPage = Instance.new("Frame")
	itemsPage.Name = "Items"
	itemsPage.BackgroundTransparency = 1
	itemsPage.Position = UDim2.fromOffset(12, 66)
	itemsPage.Size = UDim2.new(1, -24, 1, -78)
	itemsPage.Visible = false
	itemsPage.Parent = panel
	-- PETS page before the pets' zone opens: where pets come from
	local lockedNote = text(panel, "PetsLocked", FONT, GREY, UDim2.new(0, 20, 0.3, 0), UDim2.new(1, -40, 0, 70))
	lockedNote.Visible = false

	-- Right: equipped slots and EQUIP BEST
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.BackgroundTransparency = 1
	right.Position = UDim2.fromOffset(12, 66)
	right.Size = UDim2.new(1, -24, 1, -78)
	right.Parent = panel
	local slotsTitle =
		text(right, "SlotsTitle", FONT, Color3.new(1, 1, 1), UDim2.fromOffset(4, 0), UDim2.new(0.6, 0, 0, 22))
	slotsTitle.TextXAlignment = Enum.TextXAlignment.Left
	slotsTitle.Text = "EQUIPPED"
	local bestButton =
		button(right, "EquipBest", "EQUIP BEST", LIME, UDim2.new(1, -150, 0, 0), UDim2.fromOffset(150, 30))
	local slotRow = Instance.new("Frame")
	slotRow.Name = "Slots"
	slotRow.BackgroundTransparency = 1
	slotRow.Position = UDim2.fromOffset(0, 34)
	slotRow.Size = UDim2.new(1, 0, 0, 66)
	slotRow.Parent = right
	local slotLayout = Instance.new("UIListLayout")
	slotLayout.FillDirection = Enum.FillDirection.Horizontal
	slotLayout.Padding = UDim.new(0, 8)
	slotLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slotLayout.Parent = slotRow

	-- The pets you own (the others stay hidden)
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(0, 108)
	grid.Size = UDim2.new(1, 0, 1, -108)
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = PINK
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = right
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(104, 138)
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid
	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingTop = UDim.new(0, 4)
	gridPad.PaddingLeft = UDim.new(0, 4)
	gridPad.Parent = grid
	local noPets = text(right, "NoPets", FONT, GREY, UDim2.fromOffset(0, 140), UDim2.new(1, 0, 0, 60))
	noPets.Text = "NO PETS YET\nHATCH THE NEON EGG AT THE EGG STAND"
	noPets.Visible = false

	type Tile = {
		Frame: Frame,
		View: ViewportFrame,
		Name: TextLabel,
		Count: TextLabel,
		Equip: TextButton,
		Outline: UIStroke,
		Merge: TextButton?,
		Mascot: any,
	}
	local tiles: { Tile } = {}
	local doMerge: (mascot: any) -> ()
	-- Each mascot's card, then its Shiny card right after it (each shown only once owned)
	local cards = {}
	for index, mascot in Config.Mascots do -- every egg's pets (Phase X: one egg per zone), shown once owned
		local order = Mascots.RarityIndex(mascot.Rarity) * 100 + index * 2
		table.insert(cards, { Mascot = mascot, Order = order })
		table.insert(cards, { Mascot = Mascots.Get(Mascots.ShinyId(mascot.Id)), Order = order + 1 })
	end
	for _, card in cards do
		local mascot = card.Mascot
		local frame = Instance.new("Frame")
		frame.Name = mascot.Id
		frame.BackgroundColor3 = CARD
		frame.LayoutOrder = card.Order
		frame.Parent = grid
		corner(frame, 10)
		local tileOutline = stroke(frame, if mascot.Shiny then GOLD else Mascots.RarityColor(mascot.Rarity), 2, true)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Position = UDim2.fromOffset(12, 4)
		holder.Size = UDim2.new(1, -24, 0, 66)
		holder.Parent = frame
		local view = MascotView.Viewport(holder, MascotView.Mascot(mascot, 2, false), 0.95)
		local name = text(frame, "Name", FONT, Color3.new(1, 1, 1), UDim2.fromOffset(4, 70), UDim2.new(1, -8, 0, 18))
		local count = text(
			frame,
			"Count",
			BODY_FONT,
			Mascots.RarityColor(mascot.Rarity),
			UDim2.fromOffset(4, 88),
			UDim2.new(1, -8, 0, 14)
		)
		local equip = button(frame, "Equip", "EQUIP", LIME, UDim2.new(0, 8, 1, -32), UDim2.new(1, -16, 0, 26))
		equip.Activated:Connect(function()
			local mine = owned()[mascot.Id] or 0
			local inUse = countIn(equipped(), mascot.Id)
			local slots = player:GetAttribute("MascotSlots") or ECONOMY.StartSlots
			if inUse < mine and #equipped() < slots then
				equipRemote:FireServer(mascot.Id, true)
			elseif inUse > 0 then
				equipRemote:FireServer(mascot.Id, false)
			end
		end)
		-- MERGE: three of a kind -> one Shiny (top of the card, over the mascot)
		local merge: TextButton? = nil
		local cost = Mascots.MergeCost(mascot)
		if cost then
			local mergeButton = button(
				frame,
				"Merge",
				("MERGE %d"):format(cost),
				GOLD,
				UDim2.fromOffset(6, 4),
				UDim2.new(1, -12, 0, 20)
			)
			mergeButton.ZIndex = 3
			mergeButton.Visible = false
			mergeButton.Activated:Connect(function()
				task.spawn(doMerge, mascot)
			end)
			merge = mergeButton
		end
		table.insert(tiles, {
			Frame = frame,
			View = view,
			Name = name,
			Count = count,
			Equip = equip,
			Outline = tileOutline,
			Merge = merge,
			Mascot = mascot,
		})
	end

	local function refreshSlots()
		for _, child in slotRow:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local list = equipped()
		local slots = player:GetAttribute("MascotSlots") or ECONOMY.StartSlots
		local level = player:GetAttribute("RankLevel") or 1
		local lockedShown = false
		-- The +2 PET SLOTS pass (Config.Monetization) can go past MaxSlots: smaller boxes so they all fit
		local shown = math.max(ECONOMY.MaxSlots, slots)
		local boxSize = math.min(66, math.floor((ECONOMY.MaxSlots * 74 - 8 - (shown - 1) * 8) / shown))
		for i = 1, shown do
			local open = i <= slots
			if not open and lockedShown then
				break -- show only the next locked slot, so it's clear what unlocks it
			end
			local box = Instance.new("TextButton")
			box.Name = "Slot" .. i
			box.Text = ""
			box.AutoButtonColor = false
			box.LayoutOrder = i
			box.BackgroundColor3 = SLOT
			box.Size = UDim2.fromOffset(boxSize, boxSize)
			box.Parent = slotRow
			corner(box, 10)
			local mascot = Mascots.Get(list[i])
			stroke(box, if mascot then Mascots.RarityColor(mascot.Rarity) else GREY, 2, true)
			if mascot then
				MascotView.Viewport(box, MascotView.Mascot(mascot, 2, false), 0.95)
				box.Activated:Connect(function()
					equipRemote:FireServer(mascot.Id, false)
				end)
				UiFx.Press(box)
			elseif open then
				local plus = text(box, "Empty", FONT, GREY, UDim2.fromScale(0.2, 0.2), UDim2.fromScale(0.6, 0.6))
				plus.Text = "+"
			else
				lockedShown = true
				box.BackgroundTransparency = 0.5
				local lock =
					text(box, "Locked", BODY_FONT, GREY, UDim2.fromScale(0.08, 0.2), UDim2.fromScale(0.84, 0.6))
				lock.Text = "LOCKED\n" .. (Mascots.NextSlotText(level) or "")
			end
		end
	end

	local refreshBadge: () -> () -- below, with the tabs
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
		countLabel.Text = ("%s COINS  -  %d / %d SLOTS  -  %d / %d FOUND"):format(
			Mascots.BonusText(bonus),
			#list,
			slots,
			kinds,
			kindsTotal
		)
		slotsTitle.Text = ("EQUIPPED  %s COINS"):format(Mascots.BonusText(bonus))

		for _, tile in tiles do
			local mascot = tile.Mascot
			local have = mine[mascot.Id] or 0
			local inUse = countIn(list, mascot.Id)
			if tile.Merge then
				tile.Merge.Visible = have >= (Mascots.MergeCost(mascot) or math.huge)
			end
			tile.Frame.Visible = have > 0
			if have > 0 then
				tile.Name.Text = string.upper(mascot.Name)
				tile.Count.Text = ("%s%s"):format(
					Mascots.BonusText(Mascots.Bonus(mascot)),
					if have > 1 then ("  x%d"):format(have) else ""
				)
				tile.Equip.Visible = true
				if inUse < have and #list < slots then
					tile.Equip.Text = "EQUIP"
					tile.Equip.BackgroundColor3 = LIME
				elseif inUse > 0 then
					tile.Equip.Text = "UNEQUIP"
					tile.Equip.BackgroundColor3 = GREY
				else
					tile.Equip.Text = "SLOTS FULL"
					tile.Equip.BackgroundColor3 = GREY
				end
				tile.Frame.BackgroundColor3 = if inUse > 0
					then Color3.fromRGB(40, 60, 40)
					elseif mascot.Shiny then Color3.fromRGB(60, 45, 20)
					else CARD
				tile.Outline.Thickness = if inUse > 0 then 3 else 2
			end
		end
		noPets.Visible = kinds == 0

		refreshBadge()
		refreshSlots()
	end

	-- Which tab is showing; before the pets' zone the PETS tab shows the lock note and the button opens on ITEMS
	local currentTab = "Pets"
	local petsLocked: boolean? = nil
	local testEgg: TextButton? = nil
	local function showTab(name: string)
		currentTab = name
		local pets = name == "Pets"
		for tabName, tab in tabs do
			local on = tabName == name
			tab.BackgroundColor3 = if on then PINK else CARD
			tab.TextColor3 = if on then INK else Color3.new(1, 1, 1)
		end
		right.Visible = pets and not petsLocked
		lockedNote.Visible = pets and petsLocked == true
		itemsPage.Visible = not pets
		if testEgg then
			testEgg.Visible = pets
		end
		title.Text = if pets then "PETS" else "ITEMS"
		if pets then
			refresh()
		else
			local potions = PotionController.Count()
			countLabel.Text = if potions == 1 then "1 POTION TO DRINK" else ("%d POTIONS TO DRINK"):format(potions)
		end
	end

	-- Badge on the button: potions to drink (their number), else "!" when an egg can be hatched
	function refreshBadge()
		local potions = PotionController.Count()
		local unlocked, _, affordable = eggState()
		petsKit:SetBadge(if potions > 0 then potions else nil)
		petsKit:SetDot(potions == 0 and unlocked and affordable)
	end

	local function refreshButton()
		local unlocked, why = eggState()
		local locked = not unlocked
		petsButton.Visible = true
		lockedNote.Text = ("PETS UNLOCK IN %s (%s)\nHATCH THE NEON EGG AT THE EGG STAND"):format(
			Zones.Name(EGG.Zone or 1):upper(),
			tostring(why)
		)
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

	PotionController.BuildItems(itemsPage, showToast)
	for name, tab in tabs do
		tab.Activated:Connect(function()
			showTab(name)
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
	local revealNew = text(overlay, "New", FONT, LIME, UDim2.fromScale(0.3, 0.13), UDim2.fromScale(0.4, 0.07))
	local revealName =
		text(overlay, "Name", FONT, Color3.new(1, 1, 1), UDim2.fromScale(0.25, 0.64), UDim2.fromScale(0.5, 0.08))
	local revealInfo = text(overlay, "Info", FONT, GOLD, UDim2.fromScale(0.25, 0.72), UDim2.fromScale(0.5, 0.05))
	for _, label in { revealNew, revealName, revealInfo } do
		label.ZIndex = 35
		local s = label:FindFirstChildOfClass("UIStroke")
		if s then
			s.Thickness = 3
		end
	end
	local doneButton = button(overlay, "Done", "CLOSE", GREY, UDim2.new(0.5, -65, 0.79, 0), UDim2.fromOffset(130, 46))
	doneButton.TextColor3 = Color3.new(1, 1, 1)
	doneButton.ZIndex = 36

	-- The name card sits lower on the stand hatch, so the pet above the stand stays clear
	local function cardLayout(onStand: boolean)
		revealNew.Position = UDim2.fromScale(0.3, if onStand then 0.08 else 0.13)
		revealName.Position = UDim2.fromScale(0.25, if onStand then 0.68 else 0.64)
		revealInfo.Position = UDim2.fromScale(0.25, if onStand then 0.755 else 0.72)
		doneButton.Position = UDim2.new(0.5, -65, if onStand then 0.81 else 0.79, 0) -- stays on short screens too
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

	local function showCard(result, mascot)
		local rarity = Mascots.RarityIndex(mascot.Rarity)
		revealNew.Text = if result.IsNew then "NEW PET!" else "ANOTHER ONE!"
		revealNew.TextColor3 = if result.IsNew then LIME else Color3.fromRGB(200, 190, 230)
		revealName.Text = string.upper(mascot.Name)
		revealName.TextColor3 = Mascots.RarityColor(mascot.Rarity)
		revealInfo.Text = ("%s  -  %s COINS%s"):format(
			string.upper(mascot.Rarity),
			Mascots.BonusText(Mascots.Bonus(mascot)),
			if result.Equipped then "  -  EQUIPPED!" else ""
		)
		for _, label in { revealNew, revealName, revealInfo } do
			UiFx.Pop(label, 1.5, 0.35)
		end
		if rarity >= Mascots.RarityIndex("Epic") then
			UiFx.Confetti(nil, 70)
		elseif rarity >= Mascots.RarityIndex("Rare") then
			UiFx.Confetti(nil, 35)
		end
		doneButton.Visible = true
		UiFx.Pop(doneButton, 0.6, 0.3)
	end

	-- The hatch on the real stand (owner's storyboard): the camera swings in, the egg activates, shakes, cracks,
	-- bursts and the pet rises above the stand. Tap to skip from 0.7s; tap again (or CLOSE) once the card is up.
	local function playOnStand(result, mascot, site)
		hatchesThisSession += 1
		standBusy = true
		site.Prompt.Enabled = false
		table.clear(hiddenGuis)
		for _, other in playerGui:GetChildren() do
			if other:IsA("ScreenGui") and other ~= gui and other.Name ~= "FxUI" and other.Enabled then
				other.Enabled = false
				table.insert(hiddenGuis, other)
			end
		end
		petsButton.Visible = false
		panel.Visible = false
		cardLayout(true)
		overlay.BackgroundTransparency = 1
		setGlow(GOLD, 0)
		overlay.Visible = true
		doneButton.Visible = false
		revealNew.Text = ""
		revealName.Text = ""
		revealInfo.Text = ""
		clearStage()
		sceneContext = {
			Stand = site.Stand,
			Spot = site.Spot,
			Egg = site.Egg,
			Mascot = mascot,
			AutoSkip = hatchesThisSession > FX.Hatch.AutoSkipAfter,
			EdgePulse = edgePulse,
			OnCard = function()
				showCard(result, mascot)
			end,
		}
		local ok, finish = pcall(HatchScene.Play, sceneContext)
		if ok then
			endScene = finish
		else
			warn("[MascotController] hatch scene failed: " .. tostring(finish))
			showCard(result, mascot)
		end
	end

	local function play(result)
		local mascot = Mascots.Get(result.MascotId)
		if not mascot then
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
		revealNew.Text = ""
		revealName.Text = ""
		revealInfo.Text = ""
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

		revealNew.Text = if result.IsNew then "NEW PET!" else "ANOTHER ONE!"
		revealNew.TextColor3 = if result.IsNew then LIME else Color3.fromRGB(200, 190, 230)
		revealName.Text = string.upper(mascot.Name)
		revealName.TextColor3 = Mascots.RarityColor(mascot.Rarity)
		revealInfo.Text = ("%s  -  %s COINS%s"):format(
			string.upper(mascot.Rarity),
			Mascots.BonusText(Mascots.Bonus(mascot)),
			if result.Equipped then "  -  EQUIPPED!" else ""
		)
		for _, label in { revealNew, revealName, revealInfo } do
			UiFx.Pop(label, 1.5, 0.35)
		end
		if rarity >= Mascots.RarityIndex("Epic") then
			Sfx.Play("RevealBig")
			UiFx.Confetti(nil, 70)
		else
			Sfx.Play("Reveal")
			if rarity >= Mascots.RarityIndex("Rare") then
				UiFx.Confetti(nil, 35)
			end
		end

		task.wait(0.6)
		doneButton.Visible = true
		UiFx.Pop(doneButton, 0.6, 0.3)
	end

	doHatch = function(egg)
		if hatching or overlay.Visible then
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
			if result.Extras then
				-- TRIPLE HATCH: the other pets from this hatch
				local names = {}
				for _, extra in result.Extras do
					local other = Mascots.Get(extra.MascotId)
					table.insert(
						names,
						(if other then other.Name:upper() else "?") .. (if extra.IsNew then " (NEW)" else "")
					)
				end
				task.spawn(showToast, "ALSO HATCHED: " .. table.concat(names, ", "))
			end
			play(result)
		else
			showToast(if ok and result and result.Error then result.Error else "Try again")
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
			showToast(if ok and result and result.Error then result.Error else "Try again")
			merging = false
			return
		end
		cardLayout(false)
		overlay.BackgroundTransparency = 0.25
		overlay.Visible = true
		doneButton.Visible = false
		revealNew.Text = ""
		revealName.Text = ""
		revealInfo.Text = ""
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
		revealNew.Text = "SHINY!"
		revealNew.TextColor3 = GOLD
		revealName.Text = string.upper(shiny.Name)
		revealName.TextColor3 = GOLD
		revealInfo.Text = ("x%d BONUS  -  %s COINS%s"):format(
			ECONOMY.ShinyMultiplier,
			Mascots.BonusText(Mascots.Bonus(shiny)),
			if result.Equipped then "  -  EQUIPPED!" else ""
		)
		for _, label in { revealNew, revealName, revealInfo } do
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
		clearStage()
		sceneContext = nil
		if endScene then
			local finish = endScene
			endScene = nil
			finish()
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
	end
	doneButton.Activated:Connect(closeOverlay)
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
	bestButton.Activated:Connect(function()
		bestRemote:FireServer()
	end)

	petsButton.Activated:Connect(function()
		if panel.Visible then
			UiFx.Close(panel)
		else
			showTab(if petsLocked then "Items" else currentTab)
			UiFx.Open(panel)
		end
	end)
	close.Activated:Connect(function()
		UiFx.Close(panel)
	end)
	-- The zone 3 fusion station opens the panel on the pets (where MERGE is)
	MascotController.OpenPets = function()
		showTab(if petsLocked then "Items" else "Pets")
		UiFx.Open(panel)
	end

	-- Studio only: get to the egg's level and its price in coins (the server ignores this in the live game)
	local testRemote = remotes:FindFirstChild("TestEgg") :: RemoteEvent?
	if testRemote then
		local test = button(
			panel,
			"TestEgg",
			"TEST: EGG",
			Color3.fromRGB(60, 60, 80),
			UDim2.new(0, 12, 1, -30),
			UDim2.fromOffset(120, 22)
		)
		test.TextColor3 = Color3.new(1, 1, 1)
		test.ZIndex = 4
		test.Activated:Connect(function()
			testRemote:FireServer()
		end)
		testEgg = test
	end

	-- Compact layout on short screens (phones held sideways)
	local function layout()
		local compact = hud.AbsoluteSize.Y > 0 and hud.AbsoluteSize.Y < Config.Ui.CompactHeight
		panel.Position = UDim2.fromScale(0.5, if compact then 0.5 else 0.53)
		panel.Size = if compact then UDim2.fromScale(0.94, 0.94) else UDim2.fromScale(0.88, 0.74)
	end
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	layout()

	for _, key in { "Mascots", "EquippedMascots", "MascotSlots", "MascotBonus", "Coins", "RankLevel" } do
		player:GetAttributeChangedSignal(key):Connect(function()
			refreshButton()
			if panel.Visible or key ~= "Coins" then
				refresh()
			else
				refreshBadge()
			end
		end)
	end
	player:GetAttributeChangedSignal("Potions"):Connect(function()
		refreshBadge()
		if panel.Visible and currentTab == "Items" then
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
		player:GetAttributeChangedSignal("FreeEgg_" .. egg.Id):Connect(refreshStand)
		refreshStand()

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
