-- Mascots on screen (Addendum 2 Phase 3 step 8): the PETS button, the mascot panel, the hatching moment and the
-- egg stand in the lobby (Workspace.Hub.EggPad, the old daily-reward pad).
-- Hatching happens only at the egg stand (owner's call, 2026-10-19): the panel shows the egg's price, where to
-- hatch it and its ODDS, your equipped slots with EQUIP BEST, and every mascot the egg can hatch
-- (owned ones lit with EQUIP buttons, missing ones as dark silhouettes). Step 8b: a MERGE button when you own
-- Config.Economy.Mascots.ShinyMerge of one mascot, and gold Shiny cards once you own a Shiny.
-- Built in code (not in Studio), so it lives in git. The server rolls every hatch (MascotService); this only shows it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Mascots = require(Shared.Modules.Mascots)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local MascotView = require(Modules:WaitForChild("MascotView"))
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))

local player = Players.LocalPlayer

local FX = Config.MascotFx
local ECONOMY = Config.Economy.Mascots
local EGG = Config.Economy.Eggs[1] -- the Alley Egg: the only egg with mascots until zones 2 to 5 come
local EGG_LOOK = Config.EggLooks[EGG.Id]

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local INK = Color3.fromHex("06060F")
local CARD = Color3.fromRGB(30, 20, 60)
local SLOT = Color3.fromRGB(22, 14, 44)
local PINK = Color3.fromRGB(255, 60, 210)
local GOLD = Color3.fromRGB(255, 200, 40)
local LIME = Color3.fromRGB(125, 255, 60)
local GREY = Color3.fromRGB(120, 110, 150)
local SILHOUETTE = Color3.fromRGB(24, 16, 44)

-- The PETS button sits right of BALLS and DAILY (and the same on short phone screens)
local BUTTON_NORMAL = UDim2.fromOffset(142, 304)
local BUTTON_COMPACT = UDim2.fromOffset(138, 76)

local MascotController = {}

local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
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

local function eggState(): (boolean, string?, boolean)
	local level = player:GetAttribute("RankLevel") or 1
	local unlocked, why = Mascots.EggUnlocked(EGG, level, Zones.Highest(level))
	local affordable = (player:GetAttribute("Coins") or 0) >= EGG.Price
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

	-- PETS button (same look as BALLS and DAILY, in pink)
	local petsButton = Instance.new("TextButton")
	petsButton.Name = "PetsButton"
	petsButton.Text = ""
	petsButton.AutoButtonColor = false
	petsButton.BackgroundColor3 = Color3.fromRGB(30, 20, 60)
	petsButton.BackgroundTransparency = 0.1
	petsButton.Size = UDim2.fromOffset(55, 56)
	petsButton.Position = BUTTON_NORMAL
	petsButton.Visible = false
	petsButton.Parent = gui
	corner(petsButton, 12)
	stroke(petsButton, PINK, 3, true)
	local caption = text(
		petsButton,
		"Caption",
		Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy),
		PINK,
		UDim2.new(0, 3, 1, -17),
		UDim2.new(1, -6, 0, 13)
	)
	caption.Text = "PETS"
	-- Icon: a little pink mascot face
	local face = Instance.new("Frame")
	face.Name = "Icon"
	face.AnchorPoint = Vector2.new(0.5, 0)
	face.Position = UDim2.new(0.5, 0, 0, 7)
	face.Size = UDim2.fromOffset(28, 28)
	face.BackgroundColor3 = PINK
	face.Parent = petsButton
	corner(face)
	stroke(face, Color3.new(1, 1, 1), 2)
	for _, x in { 0.3, 0.7 } do
		local eye = Instance.new("Frame")
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Position = UDim2.fromScale(x, 0.42)
		eye.Size = UDim2.fromOffset(8, 8)
		eye.BackgroundColor3 = Color3.new(1, 1, 1)
		eye.Parent = face
		corner(eye)
		local pupil = Instance.new("Frame")
		pupil.AnchorPoint = Vector2.new(0.5, 0.5)
		pupil.Position = UDim2.fromScale(0.5, 0.6)
		pupil.Size = UDim2.fromOffset(4, 4)
		pupil.BackgroundColor3 = INK
		pupil.Parent = eye
		corner(pupil)
	end
	-- Red dot: an egg is ready to hatch
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.new(1, -4, 0, 4)
	dot.Size = UDim2.fromOffset(16, 16)
	dot.BackgroundColor3 = Color3.fromRGB(255, 50, 70)
	dot.Visible = false
	dot.ZIndex = 3
	dot.Parent = petsButton
	corner(dot)
	stroke(dot, Color3.new(1, 1, 1), 2)
	UiFx.Press(petsButton)

	-- Locked until the pets' zone opens (owner 2026-10-21: pets come with Neon Lanes): grey, a padlock and the level
	local lockShade = Instance.new("Frame")
	lockShade.Name = "Lock"
	lockShade.Size = UDim2.fromScale(1, 1)
	lockShade.BackgroundColor3 = Color3.new(0, 0, 0)
	lockShade.BackgroundTransparency = 0.45
	lockShade.ZIndex = 5
	lockShade.Visible = false
	corner(lockShade, 12)
	local lockIcon = text(
		lockShade,
		"Icon",
		FONT,
		Color3.new(1, 1, 1),
		UDim2.fromScale(0.25, 0.15),
		UDim2.fromScale(0.5, 0.5)
	)
	lockIcon.Text = "🔒"
	lockIcon.ZIndex = 6
	lockShade.Parent = petsButton
	local litColors = { [petsButton] = petsButton.BackgroundColor3, [face] = face.BackgroundColor3 }
	local petsOutline = petsButton:FindFirstChildOfClass("UIStroke")
	local litOutline = petsOutline and petsOutline.Color

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

	-- Left: the egg card
	local eggCard = Instance.new("Frame")
	eggCard.Name = "EggCard"
	eggCard.BackgroundColor3 = CARD
	eggCard.Position = UDim2.fromOffset(12, 66)
	eggCard.Size = UDim2.new(0.3, -18, 1, -78)
	eggCard.Parent = panel
	corner(eggCard, 12)
	stroke(eggCard, EGG_LOOK.Color, 2, true)
	local eggViewHolder = Instance.new("Frame")
	eggViewHolder.BackgroundTransparency = 1
	eggViewHolder.Position = UDim2.fromScale(0.1, 0.02)
	eggViewHolder.Size = UDim2.fromScale(0.8, 0.44)
	eggViewHolder.Parent = eggCard
	local eggModel = MascotView.Egg(EGG.Id, 4)
	MascotView.Viewport(eggViewHolder, eggModel, 0.85)
	local eggName =
		text(eggCard, "EggName", FONT, EGG_LOOK.Color, UDim2.fromScale(0.05, 0.47), UDim2.fromScale(0.9, 0.09))
	eggName.Text = string.upper(EGG_LOOK.Name)
	local eggPrice = text(eggCard, "Price", FONT, GOLD, UDim2.fromScale(0.05, 0.56), UDim2.fromScale(0.9, 0.08))
	-- Where to hatch (not a button: eggs hatch only at the egg stand in the lobby)
	local hatchHint = text(
		eggCard,
		"HatchHint",
		BODY_FONT,
		Color3.new(1, 1, 1),
		UDim2.fromScale(0.06, 0.67),
		UDim2.fromScale(0.88, 0.14)
	)
	local oddsButton =
		button(eggCard, "OddsButton", "ODDS", GREY, UDim2.fromScale(0.25, 0.84), UDim2.fromScale(0.5, 0.11))
	oddsButton.TextColor3 = Color3.new(1, 1, 1)

	-- The odds list (every rarity's chance and what each mascot gives), over the egg card
	local odds = Instance.new("TextButton")
	odds.Name = "Odds"
	odds.Text = ""
	odds.AutoButtonColor = false
	odds.BackgroundColor3 = INK
	odds.BackgroundTransparency = 0.04
	odds.Size = UDim2.fromScale(1, 1)
	odds.Visible = false
	odds.ZIndex = 5
	odds.Parent = eggCard
	corner(odds, 12)
	local oddsList = Instance.new("Frame")
	oddsList.BackgroundTransparency = 1
	oddsList.Position = UDim2.fromScale(0.06, 0.03)
	oddsList.Size = UDim2.fromScale(0.88, 0.94)
	oddsList.ZIndex = 5
	oddsList.Parent = odds
	local oddsLayout = Instance.new("UIListLayout")
	oddsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	oddsLayout.Padding = UDim.new(0.01, 0)
	oddsLayout.Parent = oddsList
	local oddsTitle = text(oddsList, "Title", FONT, Color3.new(1, 1, 1), UDim2.new(), UDim2.fromScale(1, 0.1))
	oddsTitle.Text = "ODDS (TAP TO CLOSE)"
	oddsTitle.ZIndex = 5
	for index, rarityName in Mascots.Rarities do
		local chance = ECONOMY.Odds[rarityName]
		if chance and chance > 0 then
			local row = text(
				oddsList,
				rarityName,
				BODY_FONT,
				Mascots.RarityColor(rarityName),
				UDim2.new(),
				UDim2.fromScale(1, 0.12)
			)
			row.LayoutOrder = index
			row.ZIndex = 5
			row.RichText = true
			local names = {}
			for _, mascot in Mascots.InEgg(EGG.Id) do
				if mascot.Rarity == rarityName then
					table.insert(names, mascot.Name)
				end
			end
			local bonus = (ECONOMY.Bonus[rarityName] or 0) * (EGG.BonusScale or 1)
			row.Text = ('%s %s%%  %s COINS\n<font color="#C8BEE6">%s</font>'):format(
				string.upper(rarityName),
				tostring(chance),
				Mascots.BonusText(bonus),
				table.concat(names, ", ")
			)
		end
	end
	oddsButton.Activated:Connect(function()
		odds.Visible = true
	end)
	odds.Activated:Connect(function()
		odds.Visible = false
	end)

	-- Right: equipped slots and EQUIP BEST
	local right = Instance.new("Frame")
	right.Name = "Right"
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(0.3, 0, 0, 66)
	right.Size = UDim2.new(0.7, -12, 1, -78)
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

	-- Every mascot this egg can hatch
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
	-- Each mascot's card, then its Shiny card right after it (shown only once owned)
	local cards = {}
	for index, mascot in Mascots.InEgg(EGG.Id) do
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
		for i = 1, ECONOMY.MaxSlots do
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
			box.Size = UDim2.fromOffset(66, 66)
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
			if mascot.Shiny then
				tile.Frame.Visible = have > 0 -- Shiny cards appear once you make one
			end
			if have > 0 then
				tile.View.ImageColor3 = Color3.new(1, 1, 1)
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
			else
				tile.View.ImageColor3 = SILHOUETTE
				tile.Name.Text = "???"
				tile.Count.Text = string.upper(mascot.Rarity)
				tile.Equip.Visible = false
				tile.Frame.BackgroundColor3 = CARD
				tile.Outline.Thickness = 2
			end
		end

		local unlocked, why, affordable = eggState()
		eggPrice.Text = formatNumber(EGG.Price) .. " COINS"
		if not unlocked then
			hatchHint.Text = "REACH " .. tostring(why)
			hatchHint.TextColor3 = GREY
		else
			hatchHint.Text = "HATCH IT AT THE\nEGG STAND IN THE LOBBY"
			hatchHint.TextColor3 = if affordable then LIME else Color3.new(1, 1, 1)
		end
		dot.Visible = unlocked and affordable
		refreshSlots()
	end

	-- The button is always there, locked (grey + padlock + "LEVEL 5") until the egg's zone opens; it pops when it unlocks
	local petsLocked: boolean? = nil
	local function refreshButton()
		local unlocked, why = eggState()
		local locked = not unlocked
		petsButton.Visible = true
		if locked == petsLocked then
			return
		end
		local wasLocked = petsLocked
		petsLocked = locked
		lockShade.Visible = locked
		caption.ZIndex = 7 -- the level sits above the shade
		caption.Text = if locked then tostring(why) else "PETS"
		for part, color in litColors do
			local h, sat, v = color:ToHSV()
			part.BackgroundColor3 = if locked then Color3.fromHSV(h, sat * 0.1, v * 0.6) else color
		end
		if petsOutline and litOutline then
			petsOutline.Color = if locked then Color3.fromRGB(90, 85, 100) else litOutline
		end
		caption.TextColor3 = if locked then Color3.new(1, 1, 1) else PINK
		if wasLocked and not locked then
			UiFx.Pop(petsButton, 1.6, 0.4)
		end
		if locked and panel.Visible then
			UiFx.Close(panel)
		end
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

	local function setGlow(color: Color3, strength: number)
		for i, ring in glowRings do
			ring.BackgroundColor3 = color
			ring.BackgroundTransparency = 1 - strength * (0.12 + 0.12 * i)
		end
	end

	local hatching = false
	local spinConnection: RBXScriptConnection? = nil
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

	local doHatch: () -> ()

	local function play(result)
		local mascot = Mascots.Get(result.MascotId)
		if not mascot then
			return
		end
		local rarity = Mascots.RarityIndex(mascot.Rarity)
		overlay.Visible = true
		doneButton.Visible = false
		revealNew.Text = ""
		revealName.Text = ""
		revealInfo.Text = ""
		setGlow(Mascots.RarityColor("Common"), 0.3)
		clearStage()

		-- The egg pops in and shakes harder and harder; the glow climbs through the rarities up to the result
		local egg = MascotView.Egg(EGG.Id, 4)
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

	doHatch = function()
		if hatching then
			return
		end
		local unlocked, why, affordable = eggState()
		if not unlocked then
			showToast("Unlocks at " .. tostring(why))
			return
		end
		if not affordable then
			showToast(("Need %s coins"):format(formatNumber(EGG.Price)))
			return
		end
		hatching = true
		local ok, result = pcall(hatchRemote.InvokeServer, hatchRemote, EGG.Id)
		if ok and result and result.Ok then
			play(result)
		else
			showToast(if ok and result and result.Error then result.Error else "Try again")
		end
		hatching = false
	end

	-- Merge: the copies shake together in a gold glow, squeeze into one, flash, and the Shiny pops out
	local merging = false
	doMerge = function(mascot)
		if merging or hatching then
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
	end
	doneButton.Activated:Connect(closeOverlay)
	bestButton.Activated:Connect(function()
		bestRemote:FireServer()
	end)

	local shaking = false
	petsButton.Activated:Connect(function()
		if petsLocked then
			-- A little "no" shake and where pets come from
			local _, why = eggState()
			showToast(("PETS UNLOCK IN %s (%s)"):format(Zones.Name(EGG.Zone or 1):upper(), tostring(why)))
			if shaking then
				return
			end
			shaking = true
			local start = petsButton.Position
			for _, dx in { -6, 6, -4, 4, 0 } do
				petsButton.Position = start + UDim2.fromOffset(dx, 0)
				task.wait(0.04)
			end
			petsButton.Position = start
			shaking = false
			return
		end
		if panel.Visible then
			UiFx.Close(panel)
		else
			odds.Visible = false
			refresh()
			UiFx.Open(panel)
		end
	end)
	close.Activated:Connect(function()
		UiFx.Close(panel)
	end)

	-- Studio only: get to the egg's level and its price in coins (the server ignores this in the live game)
	local testRemote = remotes:FindFirstChild("TestEgg") :: RemoteEvent?
	if testRemote then
		local test = button(
			eggCard,
			"TestEgg",
			"TEST: EGG",
			Color3.fromRGB(60, 60, 80),
			UDim2.fromScale(0.05, 0.01),
			UDim2.new(0.9, 0, 0, 22)
		)
		test.TextColor3 = Color3.new(1, 1, 1)
		test.ZIndex = 4
		test.Activated:Connect(function()
			testRemote:FireServer()
		end)
	end

	-- Compact layout on short screens (phones held sideways)
	local function layout()
		local compact = hud.AbsoluteSize.Y > 0 and hud.AbsoluteSize.Y < Config.Ui.CompactHeight
		petsButton.Position = if compact then BUTTON_COMPACT else BUTTON_NORMAL
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
				local unlocked, _, affordable = eggState()
				dot.Visible = unlocked and affordable
			end
		end)
	end
	refresh()
	refreshButton()
	gui.Parent = playerGui

	-- ===== The egg stand in the lobby =====
	task.spawn(function()
		local hub = Workspace:WaitForChild("Hub", 30)
		local pad = hub and hub:WaitForChild("EggPad", 30)
		local plinth = pad and pad:WaitForChild("Plinth", 10) :: BasePart?
		if not plinth then
			warn("[MascotController] Workspace.Hub.EggPad.Plinth not found: no egg stand in the lobby")
			return
		end
		local standEgg = MascotView.Egg(EGG.Id, 3.6)
		standEgg.Name = "StandEgg"
		-- The plinth is a cylinder lying on its side, so its height runs along whichever axis points up
		local half, frame = plinth.Size / 2, plinth.CFrame
		local top = frame.Position.Y
			+ math.abs(frame.RightVector.Y) * half.X
			+ math.abs(frame.UpVector.Y) * half.Y
			+ math.abs(frame.LookVector.Y) * half.Z
		local base = Vector3.new(plinth.Position.X, top + 2.4, plinth.Position.Z)
		standEgg:PivotTo(CFrame.new(base))
		local shell = standEgg.PrimaryPart :: BasePart
		local light = Instance.new("PointLight")
		light.Color = EGG_LOOK.Color
		light.Range = 12
		light.Brightness = 1.5
		light.Parent = shell
		standEgg.Parent = pad

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "HatchPrompt"
		prompt.ObjectText = EGG_LOOK.Name
		prompt.HoldDuration = FX.HoldDuration
		prompt.MaxActivationDistance = FX.PromptDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = shell
		prompt.Triggered:Connect(function()
			task.spawn(doHatch)
		end)

		-- Price and lock above the egg
		local board = Instance.new("BillboardGui")
		board.Name = "EggInfo"
		board.Size = UDim2.fromOffset(220, 64)
		board.StudsOffset = Vector3.new(0, 3.4, 0)
		board.MaxDistance = 70
		board.LightInfluence = 0
		board.Parent = shell
		local boardName = text(board, "Name", FONT, EGG_LOOK.Color, UDim2.new(), UDim2.new(1, 0, 0.5, 0))
		boardName.Text = string.upper(EGG_LOOK.Name)
		local boardPrice = text(board, "Price", FONT, GOLD, UDim2.fromScale(0, 0.5), UDim2.new(1, 0, 0.45, 0))

		local function refreshStand()
			local unlocked, why = eggState()
			boardPrice.Text = if unlocked then formatNumber(EGG.Price) .. " COINS" else "REACH " .. tostring(why)
			boardPrice.TextColor3 = if unlocked then GOLD else GREY
			prompt.ActionText = if unlocked then ("Hatch (%s)"):format(formatNumber(EGG.Price)) else "Locked"
		end
		player:GetAttributeChangedSignal("RankLevel"):Connect(refreshStand)
		refreshStand()

		-- Hover and turn while the camera is near
		RunService.RenderStepped:Connect(function()
			local camera = Workspace.CurrentCamera
			if camera and (camera.CFrame.Position - base).Magnitude > 90 then
				return
			end
			local t = os.clock()
			standEgg:PivotTo(
				CFrame.new(base + Vector3.new(0, math.sin(t * 1.6) * 0.3, 0))
					* CFrame.Angles(0, t * 0.6, math.sin(t * 2.3) * 0.06)
			)
		end)
	end)
end

return MascotController
