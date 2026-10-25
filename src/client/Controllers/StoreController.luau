-- STORE (Addendum 2 section 7, step 12a): only while the store is on (Config.Monetization.Enabled, or Studio's free
-- preview). A gold STORE button (computers: bottom-left, right of TELEPORT; phones: right of the REBIRTH button) opens
-- the window: the Starter Pack (until bought), game passes (OWNED once yours) and boosts + gems. BUY asks the server,
-- which shows Roblox's own purchase window; nothing is given here.
-- Quick-buy boosts on the HUD (owner 2026-10-25): the COIN BOOST and XP BOOST ladders' next steps also sit right of
-- the coin multiplier badge and the AUTO spot ("x2 COINS / R$ 3"), gone once that ladder is MAXED.
-- Also: the one-time Starter Pack popup (the server says when; it waits for a quiet moment, never mid-throw), a THANK
-- YOU toast after a purchase, and the gold [VIP] tag in chat for VIP owners.
-- Built in code (not in Studio), so it lives in git.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Store = require(Shared.Modules.Store)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))

local player = Players.LocalPlayer

local MONEY = Config.Monetization
local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local CAPTION_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local INK = Color3.fromHex("06060F")
local CARD = Color3.fromRGB(30, 20, 60)
local PANEL = Color3.fromRGB(18, 12, 38)
local GOLD = Color3.fromRGB(255, 200, 40)
local LIME = Color3.fromRGB(125, 255, 60)
local GREY = Color3.fromRGB(120, 110, 150)
local SOFT = Color3.fromRGB(200, 190, 230)
local GAP = 12 -- pixels between the REBIRTH button and this one (phones)

local StoreController = {}

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

local function button(parent: Instance, name: string, label: string, color: Color3, position: UDim2, size: UDim2): TextButton
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
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 5)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = b
	UiFx.Press(b)
	return b
end

-- Gold [VIP] before VIP owners' names in chat (new chat only; the old chat has no hook for this)
local function chatTag()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		local speaker = source and Players:GetPlayerByUserId(source.UserId)
		if speaker and Store.Owns(speaker, "VIP") then
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = ('<font color="#FFC828">%s</font> %s'):format(MONEY.ChatTag, message.PrefixText)
			return properties
		end
		return nil
	end
end

function StoreController:Start()
	if not Store.Active() then
		return
	end
	chatTag()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buyRemote = remotes:WaitForChild("StoreBuy") :: RemoteEvent
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local rankBar = hud:WaitForChild("RankBar") :: GuiObject

	local gui = Instance.new("ScreenGui")
	gui.Name = "StoreUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.IgnoreGuiInset = hud.IgnoreGuiInset
	gui.Parent = playerGui

	-- ===== The button =====
	local openButton = Instance.new("TextButton")
	openButton.Name = "StoreButton"
	openButton.Text = ""
	openButton.AutoButtonColor = false
	openButton.BackgroundColor3 = CARD
	openButton.BackgroundTransparency = 0.1
	openButton.Parent = gui
	corner(openButton, 12)
	stroke(openButton, GOLD, 3, true)
	local caption = text(openButton, "Caption", CAPTION_FONT, GOLD, UDim2.new(0, 3, 1, -17), UDim2.new(1, -6, 0, 13))
	caption.Text = "STORE"
	local icon = text(openButton, "Icon", FONT, GOLD, UDim2.new(0, 6, 0, 6), UDim2.new(1, -12, 1, -26))
	icon.Text = "R$"
	UiFx.Press(openButton)

	local function place()
		local compact = hud.AbsoluteSize.Y > 0 and hud.AbsoluteSize.Y < Config.Ui.CompactHeight
		if compact then
			-- Phones: right of the REBIRTH button's spot (right of the level bar), top edges lined up
			openButton.AnchorPoint = Vector2.new(0, 0)
			openButton.Size = UDim2.fromOffset(44, 46)
			local barPos, barSize = rankBar.AbsolutePosition, rankBar.AbsoluteSize
			local guiTop = gui.AbsolutePosition
			openButton.Position =
				UDim2.fromOffset(barPos.X - guiTop.X + barSize.X + GAP + 44 + GAP, barPos.Y - guiTop.Y)
		else
			-- Computers: bottom-left, right of the TELEPORT button
			openButton.AnchorPoint = Vector2.new(0, 1)
			openButton.Size = UDim2.fromOffset(55, 56)
			openButton.Position = UDim2.new(0, 16 + 55 + 10, 1, -16)
		end
	end
	rankBar:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
	rankBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	-- ===== Quick-buy boosts on the HUD =====
	local bar = hud:WaitForChild("Bar") :: Frame
	local quick = {}
	for index, ladder in { { Ladder = "Coins", What = "COINS" }, { Ladder = "Xp", What = "XP" } } do
		local color = if ladder.Ladder == "Coins" then GOLD else Color3.fromRGB(80, 220, 255)
		local pill = Instance.new("TextButton")
		pill.Name = "Quick" .. ladder.Ladder
		pill.Text = ""
		pill.AutoButtonColor = false
		pill.BackgroundColor3 = Color3.fromRGB(255, 120, 200)
		pill.Parent = hud
		corner(pill, 10)
		stroke(pill, INK, 2, true)
		local top = text(pill, "Boost", FONT, color, UDim2.fromScale(0.06, 0.06), UDim2.fromScale(0.88, 0.5))
		local price = text(pill, "Price", CAPTION_FONT, Color3.new(1, 1, 1), UDim2.fromScale(0.06, 0.56), UDim2.fromScale(0.88, 0.38))
		UiFx.Press(pill)
		pill.Activated:Connect(function()
			local step = Store.NextStep(player, ladder.Ladder)
			if step then
				buyRemote:FireServer(step.Id)
			end
		end)
		quick[ladder.Ladder] = { Pill = pill, Top = top, Price = price, What = ladder.What, Row = index }
	end
	-- Right of the multiplier badge (coins row) and the AUTO spot (gems row): the same rows MultiplierController uses
	local function placeQuick()
		local height = math.floor(bar.Size.Y.Offset * 0.42)
		local x = bar.Position.X.Offset + bar.Size.X.Offset + 6 + 66 + 6
		for _, item in quick do
			local y = bar.Position.Y.Offset + 2 + (item.Row - 1) * (height + 6)
			item.Pill.Position = UDim2.new(bar.Position.X.Scale, x, bar.Position.Y.Scale, y)
			item.Pill.Size = UDim2.fromOffset(78, height)
		end
	end
	local function refreshQuick()
		for ladder, item in quick do
			local step = Store.NextStep(player, ladder)
			item.Pill.Visible = step ~= nil
			if step then
				item.Top.Text = ("x%d %s"):format(2 ^ step.Step, item.What)
				item.Price.Text = Store.PriceText(step.Robux)
			end
		end
	end
	bar:GetPropertyChangedSignal("Position"):Connect(placeQuick)
	bar:GetPropertyChangedSignal("Size"):Connect(placeQuick)
	for _, key in Store.LadderKeys do
		player:GetAttributeChangedSignal(key):Connect(refreshQuick)
	end
	placeQuick()
	refreshQuick()

	-- ===== The window =====
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.53)
	panel.Size = UDim2.fromScale(0.9, 0.84)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Active = true
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, GOLD, 4, true)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(640, 520)
	limit.Parent = panel

	local title = text(panel, "Title", FONT, Color3.new(1, 1, 1), UDim2.new(0, 20, 0, 12), UDim2.new(1, -80, 0, 36))
	title.Text = "STORE"
	title.TextXAlignment = Enum.TextXAlignment.Left
	if Store.IsPreview() then
		local note = text(panel, "Preview", BODY_FONT, LIME, UDim2.new(0, 130, 0, 20), UDim2.fromOffset(230, 16))
		note.Text = "STUDIO PREVIEW: buying is free and fake"
		note.TextXAlignment = Enum.TextXAlignment.Left
	end
	-- The ladder boosts bought so far, top right
	local boostLabel = text(panel, "Boost", FONT, GOLD, UDim2.new(1, -262, 0, 18), UDim2.fromOffset(196, 24))
	boostLabel.TextXAlignment = Enum.TextXAlignment.Right
	local function refreshBoost()
		boostLabel.Text =
			("COINS x%d  XP x%d"):format(Store.BoostMultiplier(player), Store.XpBoostMultiplier(player))
	end
	for _, key in Store.LadderKeys do
		player:GetAttributeChangedSignal(key):Connect(refreshBoost)
	end
	refreshBoost()
	local close = button(panel, "Close", "X", Color3.fromRGB(255, 70, 90), UDim2.new(1, -54, 0, 12), UDim2.fromOffset(42, 42))

	local list = Instance.new("ScrollingFrame")
	list.Name = "Items"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 16, 0, 62)
	list.Size = UDim2.new(1, -32, 1, -76)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = GOLD
	list.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -6, 0, 118)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list

	-- One card per pass and product
	local cards = {}
	local function addCard(item, kind: string, order: number)
		local color = if item.Id == "StarterPack"
			then LIME
			elseif kind == "Pass" then GOLD
			elseif kind == "Ladder" then Color3.fromRGB(255, 120, 200)
			else Color3.fromRGB(80, 220, 255)
		local card = Instance.new("Frame")
		card.Name = item.Id
		card.LayoutOrder = order
		card.BackgroundColor3 = CARD
		card.Parent = list
		corner(card, 12)
		stroke(card, color, 3, true)
		local kindLabel = text(card, "Kind", CAPTION_FONT, color, UDim2.new(0, 10, 0, 8), UDim2.new(0.5, 0, 0, 12))
		kindLabel.Text = if kind == "Pass"
			then "GAME PASS"
			elseif item.Once then "ONE TIME ONLY"
			elseif kind == "Ladder" then "FOREVER - DOUBLES EVERY BUY"
			elseif item.Gems then "GEMS"
			else "BOOST"
		kindLabel.TextXAlignment = Enum.TextXAlignment.Left
		local name = text(card, "ItemName", FONT, Color3.new(1, 1, 1), UDim2.new(0, 10, 0, 22), UDim2.new(1, -20, 0, 26))
		name.Text = item.Name
		name.TextXAlignment = Enum.TextXAlignment.Left
		local body = text(card, "Text", BODY_FONT, SOFT, UDim2.new(0, 10, 0, 50), UDim2.new(1, -120, 1, -58))
		body.Text = item.Text
		body.TextWrapped = true
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		local size = Instance.new("UITextSizeConstraint")
		size.MaxTextSize = 15
		size.Parent = body
		local buy = button(card, "Buy", Store.PriceText(item.Robux), color, UDim2.new(1, -106, 1, -48), UDim2.fromOffset(96, 38))
		buy.Activated:Connect(function()
			-- A ladder card buys that ladder's next step
			local id = item.Id
			if kind == "Ladder" then
				local step = Store.NextStep(player, item.Ladder)
				if not step then
					return
				end
				id = step.Id
			end
			buyRemote:FireServer(id)
		end)
		cards[item.Id] = { Card = card, Buy = buy, Kind = kind, Item = item, Color = color }
	end
	local order = 0
	for _, product in MONEY.Products do
		if product.Once then
			order += 1
			addCard(product, "Product", order)
		end
	end
	-- One card per doubling ladder (it shows the next step)
	for _, ladder in { { Ladder = "Coins", Name = "COIN BOOST" }, { Ladder = "Xp", Name = "XP BOOST" } } do
		order += 1
		addCard({ Id = "Ladder_" .. ladder.Ladder, Ladder = ladder.Ladder, Name = ladder.Name, Text = "", Robux = 0 }, "Ladder", order)
	end
	for _, pass in MONEY.Passes do
		order += 1
		addCard(pass, "Pass", order)
	end
	for _, product in MONEY.Products do
		if not product.Once and not product.Ladder then
			order += 1
			addCard(product, "Product", order)
		end
	end

	local function refresh()
		for id, card in cards do
			if card.Kind == "Pass" then
				local mine = Store.Owns(player, id)
				card.Buy.Text = if mine then "OWNED" else Store.PriceText(card.Item.Robux)
				card.Buy.BackgroundColor3 = if mine then GREY else card.Color
				card.Buy.Active = not mine
			elseif card.Item.Once then
				card.Card.Visible = (player:GetAttribute(id) or 0) == 0 -- StarterPack: gone once bought
			elseif card.Kind == "Ladder" then
				local ladder = card.Item.Ladder
				local level = Store.LadderLevel(player, ladder)
				local step = Store.NextStep(player, ladder)
				local what = if ladder == "Coins" then "coins" else "XP"
				card.Card.ItemName.Text = if step
					then ("%s x%d > x%d"):format(card.Item.Name, 2 ^ level, 2 ^ step.Step)
					else ("%s x%d"):format(card.Item.Name, 2 ^ level)
				card.Card.Text.Text = if step
					then ("Doubles your %s forever. Step %d of 4."):format(what, step.Step)
					else ("Your %s are doubled 4 times. All done!"):format(what)
				card.Buy.Text = if step then Store.PriceText(step.Robux) else "MAXED"
				card.Buy.BackgroundColor3 = if step then card.Color else GREY
				card.Buy.Active = step ~= nil
			end
		end
	end
	player:GetAttributeChangedSignal("Passes"):Connect(refresh)
	player:GetAttributeChangedSignal("StarterPack"):Connect(refresh)
	for _, key in Store.LadderKeys do
		player:GetAttributeChangedSignal(key):Connect(refresh)
	end
	refresh()

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

	-- ===== THANK YOU toast after a purchase =====
	local toast = Instance.new("Frame")
	toast.Name = "Thanks"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 70)
	toast.Size = UDim2.fromOffset(340, 64)
	toast.BackgroundColor3 = CARD
	toast.Visible = false
	toast.Parent = gui
	corner(toast, 14)
	stroke(toast, LIME, 3, true)
	local toastTitle = text(toast, "Title", FONT, LIME, UDim2.new(0, 10, 0, 6), UDim2.new(1, -20, 0, 28))
	toastTitle.Text = "THANK YOU!"
	local toastItem = text(toast, "Item", BODY_FONT, Color3.new(1, 1, 1), UDim2.new(0, 10, 0, 36), UDim2.new(1, -20, 0, 20))
	local toastId = 0
	remotes:WaitForChild("StoreResult").OnClientEvent:Connect(function(info)
		toastTitle.Text = if info.Title then tostring(info.Title) else "THANK YOU!"
		toastItem.Text = tostring(info.Text or "")
		toast.Visible = true
		UiFx.Pop(toast)
		UiFx.Confetti(toast)
		Sfx.Play("Reveal", 1.1)
		toastId += 1
		local mine = toastId
		task.delay(3, function()
			if toastId == mine then
				toast.Visible = false
			end
		end)
		refresh()
	end)

	-- ===== Starter Pack popup (once; the server decides when) =====
	local lastThrow = 0
	remotes:WaitForChild("ThrowResult").OnClientEvent:Connect(function(info)
		if type(info) == "table" and info.UserId == player.UserId then
			lastThrow = os.clock()
		end
	end)
	local starter = Store.Product("StarterPack")
	local popup = Instance.new("Frame")
	popup.Name = "StarterPopup"
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.5)
	popup.Size = UDim2.fromOffset(360, 220)
	popup.BackgroundColor3 = PANEL
	popup.Visible = false
	popup.Active = true
	popup.Parent = gui
	corner(popup, 18)
	stroke(popup, LIME, 4, true)
	local popupTitle = text(popup, "Title", FONT, LIME, UDim2.new(0, 16, 0, 14), UDim2.new(1, -32, 0, 38))
	popupTitle.Text = starter and starter.Name or "STARTER PACK"
	local popupBody = text(popup, "Body", BODY_FONT, Color3.new(1, 1, 1), UDim2.new(0, 20, 0, 60), UDim2.new(1, -40, 0, 74))
	popupBody.Text = starter and starter.Text or ""
	popupBody.TextWrapped = true
	local popupSize = Instance.new("UITextSizeConstraint")
	popupSize.MaxTextSize = 18
	popupSize.Parent = popupBody
	local popupBuy = button(
		popup,
		"Buy",
		if starter then Store.PriceText(starter.Robux) else "BUY",
		LIME,
		UDim2.new(0.5, 8, 1, -60),
		UDim2.new(0.5, -24, 0, 44)
	)
	local popupNo = button(popup, "NoThanks", "NO THANKS", GREY, UDim2.new(0, 16, 1, -60), UDim2.new(0.5, -24, 0, 44))
	popupBuy.Activated:Connect(function()
		buyRemote:FireServer("StarterPack")
		UiFx.Close(popup)
	end)
	popupNo.Activated:Connect(function()
		UiFx.Close(popup)
	end)
	player:GetAttributeChangedSignal("StarterPack"):Connect(function()
		if popup.Visible and (player:GetAttribute("StarterPack") or 0) > 0 then
			UiFx.Close(popup)
		end
	end)
	remotes:WaitForChild("StarterOffer").OnClientEvent:Connect(function()
		if not starter then
			return
		end
		-- A quiet moment: a few seconds after your last throw, not holding the throw button
		while
			os.clock() - lastThrow < MONEY.QuietSeconds
			or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		do
			task.wait(0.5)
		end
		if (player:GetAttribute("StarterPack") or 0) == 0 then
			UiFx.Open(popup)
		end
	end)
end

return StoreController
