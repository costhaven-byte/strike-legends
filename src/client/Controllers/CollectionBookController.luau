-- The collection book: every ball in the game, one page per rarity. Owned balls spin in 3D;
-- the ones you're missing show as dark silhouettes with their traits, so you know what to chase.
-- Opened with the BALLS button; owned balls have an EQUIP button (this replaced the old BALLS grid on 2026-10-19).
-- Built in code (not in Studio), so it lives in git. Ownership comes from the OwnedBalls Player attribute the server sets.
-- Also puts the equipped ball, spinning in 3D, on the BALLS button.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local UiFx = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UiFx"))
local BallView = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("BallView"))
local Sfx = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("Sfx"))

local player = Players.LocalPlayer

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local INK = Color3.fromHex("06060F")
local CARD = Color3.fromRGB(30, 20, 60)
local TAB = Color3.fromRGB(22, 14, 44)
local SILHOUETTE = Color3.fromRGB(28, 22, 48)
local GEM_BLUE = Color3.fromRGB(60, 230, 255) -- same blue as "+N GEMS" after a throw (HudController)
local SPIN_SPEED = 0.6 -- turns of the owned balls, radians per second

local CollectionBookController = {}

-- Equip guide: after the first crate bought with coins, arrows show how to equip its new ball
-- (BALLS button first, then that ball's EQUIP button in the book). Ends on any equip or when the book closes.
local guideBall: string? = nil

function CollectionBookController.GuideEquip(ballId: string)
	if Balls.Get(ballId) and player:GetAttribute("EquippedBall") ~= ballId then
		guideBall = ballId
	end
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = if parent:IsA("TextLabel") or parent:IsA("TextButton")
		then Enum.ApplyStrokeMode.Border
		else Enum.ApplyStrokeMode.Contextual
	s.Parent = parent
	return s
end

local function text(parent: Instance, name: string, font: Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = parent
	return label
end

local ballModel = BallView.Model
local frameBall = BallView.FrameCamera
local spin = BallView.Turn

function CollectionBookController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BallsUI")
	local inventory = gui:WaitForChild("Inventory") :: Frame
	local rarities = Config.Rarities

	-- The book borrows the inventory panel's look: a copy with the tiles and detail line taken out
	local book = inventory:Clone()
	book.Name = "Book"
	book.Visible = false
	for _, name in { "Grid", "TileTemplate", "Detail" } do
		local child = book:FindFirstChild(name)
		if child then
			child:Destroy()
		end
	end
	local title = book:WaitForChild("Title") :: TextLabel
	title.Text = "COLLECTION BOOK"
	local countLabel = book:WaitForChild("Count") :: TextLabel
	local close = book:WaitForChild("Close") :: TextButton
	local ballsButton = gui:WaitForChild("Menu"):WaitForChild("BallsButton") :: TextButton
	local equipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipBall") :: RemoteEvent
	local polishRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuyPolish") :: RemoteFunction

	-- One tab per rarity page
	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.fromOffset(12, 66)
	tabs.Size = UDim2.new(1, -24, 0, 34)
	tabs.Parent = book
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabLayout.Padding = UDim.new(0.008, 0)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs

	-- The page: rarity name, then that rarity's balls as cards
	local pageTitle = text(book, "PageTitle", FONT, Color3.new(1, 1, 1))
	pageTitle.Position = UDim2.fromOffset(12, 108)
	pageTitle.Size = UDim2.new(1, -24, 0, 30)
	stroke(pageTitle, INK, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

	local cards = Instance.new("Frame")
	cards.Name = "Cards"
	cards.BackgroundTransparency = 1
	cards.Position = UDim2.fromOffset(12, 146)
	cards.Size = UDim2.new(1, -24, 1, -196)
	cards.Parent = book
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Horizontal
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	cardLayout.Padding = UDim.new(0.012, 0)
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Parent = cards

	-- The full trait description of the card you point at (or tapped)
	local detail = text(book, "Detail", BODY_FONT, Color3.new(1, 1, 1))
	detail.AnchorPoint = Vector2.new(0, 1)
	detail.Position = UDim2.new(0, 18, 1, -8)
	detail.Size = UDim2.new(1, -36, 0, 30)
	detail.RichText = true
	local detailLimit = Instance.new("UITextSizeConstraint")
	detailLimit.MaxTextSize = 16
	detailLimit.Parent = detail

	book.Parent = gui

	-- The equipped ball, spinning in 3D on the BALLS button (it replaces the old colour dot)
	local swatch = ballsButton:WaitForChild("Swatch") :: Frame
	swatch.BackgroundTransparency = 1
	local buttonView = Instance.new("ViewportFrame")
	buttonView.Name = "Ball3D"
	buttonView.AnchorPoint = Vector2.new(0.5, 0.5)
	buttonView.Position = UDim2.fromScale(0.5, 0.5)
	buttonView.Size = UDim2.fromScale(1.25, 1.25) -- a little bigger than the ring, so the ball reads at this size
	buttonView.BackgroundTransparency = 1
	buttonView.Ambient = Color3.fromRGB(190, 190, 210)
	buttonView.LightColor = Color3.new(1, 1, 1)
	buttonView.LightDirection = Vector3.new(-1, -1.5, -1)
	buttonView.Active = false
	local buttonCamera = Instance.new("Camera")
	buttonCamera.FieldOfView = 30
	buttonCamera.Parent = buttonView
	buttonView.CurrentCamera = buttonCamera
	buttonView.Parent = swatch
	local buttonModel: Instance? = nil
	local buttonBall: string? = nil

	local function updateButton(force: boolean?)
		local current = Balls.Get(player:GetAttribute("EquippedBall")) or Config.Balls[1]
		if current.Id == buttonBall and not force then
			return
		end
		buttonBall = current.Id
		if buttonModel then
			buttonModel:Destroy()
		end
		local model = ballModel(current)
		frameBall(buttonCamera, model, 1.05)
		model.Parent = buttonView
		buttonModel = model
	end
	updateButton()

	local page = 1
	local spinning: { Instance } = {}
	-- POLISH buttons on this page and their gem price, so they light up or dim as gems come and go
	local polishButtons: { [TextButton]: number } = {}
	local function paintPolish(button: TextButton, price: number)
		local canPay = (player:GetAttribute("Gems") or 0) >= price
		button.BackgroundTransparency = if canPay then 0 else 0.45
		button.TextTransparency = if canPay then 0 else 0.35
		local outline = button:FindFirstChildOfClass("UIStroke")
		if outline then
			outline.Transparency = if canPay then 0 else 0.5
		end
	end
	local tabButtons: { TextButton } = {}

	local function ballsOf(rarityName: string)
		local list = {}
		for _, ball in Config.Balls do
			if ball.Rarity == rarityName then
				table.insert(list, ball)
			end
		end
		table.sort(list, function(a, b)
			return a.Multiplier < b.Multiplier
		end)
		return list
	end

	local function makeCard(ball, owned: boolean, order: number, equipped: boolean, count: number)
		local rarity = Balls.GetRarity(ball.Rarity)
		local card = Instance.new("TextButton")
		card.Name = ball.Id
		card.Text = ""
		card.AutoButtonColor = false
		card.LayoutOrder = order
		-- Five cards fill the page; more than five (Common has 7) narrow down so they all still fit
		local gap = cardLayout.Padding.Scale
		card.Size = UDim2.new(math.min(0.186, (1 - gap * (count - 1)) / count), 0, 1, 0)
		card.BackgroundColor3 = CARD
		card.BackgroundTransparency = if owned then 0 else 0.35
		corner(card, 12)
		stroke(card, rarity.Color, if owned then 2.5 else 1.5).Transparency = if owned then 0 else 0.5
		local fit = Instance.new("UISizeConstraint")
		fit.MaxSize = Vector2.new(220, math.huge)
		fit.Parent = card

		-- The ball: spinning in 3D if you own it, a dark silhouette if not
		local view = Instance.new("ViewportFrame")
		view.Name = "Ball"
		view.AnchorPoint = Vector2.new(0.5, 0)
		view.Position = UDim2.new(0.5, 0, 0, 8)
		view.Size = UDim2.new(1, -16, 0.4, 0)
		view.BackgroundTransparency = 1
		view.Ambient = Color3.fromRGB(190, 190, 210)
		view.LightColor = Color3.new(1, 1, 1)
		view.LightDirection = Vector3.new(-1, -1.5, -1)
		view.ImageColor3 = if owned then Color3.new(1, 1, 1) else SILHOUETTE
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.Parent = view
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.6, 2.4), Vector3.zero)
		camera.Parent = view
		view.CurrentCamera = camera
		local model = ballModel(ball)
		model.Parent = view
		if owned then
			table.insert(spinning, model)
		end
		view.Parent = card

		if not owned then
			local mark = text(view, "Unknown", FONT, rarity.Color)
			mark.AnchorPoint = Vector2.new(0.5, 0.5)
			mark.Position = UDim2.fromScale(0.5, 0.5)
			mark.Size = UDim2.fromScale(0.45, 0.45)
			mark.Text = "?"
			stroke(mark, INK, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		end
		local name = text(card, "BallName", FONT, if owned then Color3.new(1, 1, 1) else rarity.Color)
		name.Position = UDim2.new(0, 6, 0.44, 6)
		name.Size = UDim2.new(1, -12, 0.1, 0)
		name.Text = if owned then ball.Name:upper() else "???"
		stroke(name, INK, 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

		local stats = text(card, "Stats", BODY_FONT, Color3.fromRGB(200, 190, 230))
		stats.Position = UDim2.new(0, 6, 0.55, 4)
		stats.Size = UDim2.new(1, -12, 0.07, 0)
		-- Owned balls: the multiplier with Polish on top, and the Polish level (POLISH 3/10)
		local level = Balls.PolishLevel(Balls.DecodePolish(player:GetAttribute("Polish"))[ball.Id])
		local polishPrice = if owned then Balls.PolishGemPrice(ball, level) else nil
		if owned then
			local mult = math.floor(Balls.Multiplier(ball, level) * 100 + 0.5) / 100
			stats.RichText = true
			stats.Text = if level > 0
				then ('x%g COINS  <font color="#FFE15A">POLISH %d/%d</font>'):format(
					mult,
					level,
					Config.Economy.Polish.MaxLevel
				)
				else ("x%g COINS"):format(mult)
		else
			stats.Text = "FIND IT IN CRATES"
		end

		-- Traits show on missing balls too, so you know what you're chasing (short tags, one per line)
		local traits = text(card, "Traits", FONT, Color3.new(1, 1, 1))
		traits.Position = UDim2.new(0, 8, 0.64, 4)
		traits.Size = if not owned
			then UDim2.new(1, -16, 0.36, -12)
			elseif polishPrice then UDim2.new(1, -16, 0.15, -18) -- room for the POLISH button
			else UDim2.new(1, -16, 0.23, -4)
		traits.RichText = true
		traits.TextWrapped = false -- one tag per line; long tags shrink instead of breaking
		local short = Balls.DescribeTraits(ball, true, true):gsub(" · ", "\n")
		traits.Text = if short == "" then "NO TRAIT" else short
		traits.TextTransparency = if short == "" then 0.5 else 0
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 18
		limit.Parent = traits

		local function describe()
			local described = Balls.DescribeTraits(ball, false, true)
			detail.Text = ('<font color="#%s">%s</font>   %s'):format(
				rarity.Color:ToHex(),
				if owned then ball.Name:upper() else "??? " .. ball.Rarity:upper() .. " BALL",
				if described == "" then "No special trait" else (described:gsub("\n", "   "))
			)
		end
		card.MouseEnter:Connect(describe)
		card.Activated:Connect(describe)

		-- Owned balls: EQUIP (or a lit EQUIPPED bar on the one you're throwing)
		if owned then
			local equip = Instance.new("TextButton")
			equip.Name = "Equip"
			equip.AnchorPoint = Vector2.new(0.5, 1)
			equip.Position = UDim2.new(0.5, 0, 1, -8)
			equip.Size = UDim2.new(1, -16, 0.11, 0)
			equip.FontFace = FONT
			equip.TextScaled = true
			equip.Text = if equipped then "EQUIPPED" else "EQUIP"
			equip.TextColor3 = INK
			equip.BackgroundColor3 = if equipped then Color3.fromRGB(70, 230, 255) else Color3.fromRGB(90, 230, 110)
			equip.AutoButtonColor = not equipped
			corner(equip, 8)
			stroke(equip, INK, 2)
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0.18, 0)
			pad.PaddingBottom = UDim.new(0.1, 0)
			pad.Parent = equip
			equip.Parent = card
			equip.Activated:Connect(function()
				describe()
				if not equipped then
					equipRemote:FireServer(ball.Id)
				end
			end)
		end

		-- Owned balls that aren't fully polished: POLISH buys the next level with gems (step 7b gem sink)
		if owned and polishPrice then
			local price = polishPrice :: number
			local polish = Instance.new("TextButton")
			polish.Name = "Polish"
			polish.AnchorPoint = Vector2.new(0.5, 1)
			polish.Position = UDim2.new(0.5, 0, 0.89, -12)
			polish.Size = UDim2.new(1, -16, 0.1, 0)
			polish.FontFace = FONT
			polish.TextScaled = true
			polish.RichText = true
			polish.Text = ('POLISH  <font color="#FFFFFF">%d GEMS</font>'):format(price)
			-- Dark with a gem-blue outline, so it never looks like the solid blue EQUIPPED bar under it
			polish.TextColor3 = GEM_BLUE
			polish.BackgroundColor3 = Color3.fromRGB(12, 36, 58)
			polish.AutoButtonColor = true
			corner(polish, 8)
			stroke(polish, GEM_BLUE, 2)
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0.18, 0)
			pad.PaddingBottom = UDim.new(0.1, 0)
			pad.PaddingLeft = UDim.new(0, 4)
			pad.PaddingRight = UDim.new(0, 4)
			pad.Parent = polish
			polish.Parent = card
			polishButtons[polish] = price
			paintPolish(polish, price)
			local asking = false
			polish.Activated:Connect(function()
				if asking then
					return
				end
				local gems = player:GetAttribute("Gems") or 0
				if gems < price then
					Sfx.Play("Error")
					detail.Text = ('<font color="#3CE6FF">POLISH %s</font>   You need %d more gems. Gems come from PERFECT strikes, rank levels and the daily reward.'):format(
						ball.Name:upper(),
						price - gems
					)
					UiFx.Pop(polish, 0.85, 0.25)
					return
				end
				asking = true
				local ok, result = pcall(polishRemote.InvokeServer, polishRemote, ball.Id)
				asking = false
				if ok and result and result.Ok then
					-- The Polish attribute changes and the page redraws; this just adds the sound
					Sfx.Play("PowerUp")
				else
					Sfx.Play("Error")
					detail.Text = if ok and result and result.Error then result.Error else "Try again"
				end
			end)
		end

		card.Parent = cards
	end

	local function render()
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local equipped = player:GetAttribute("EquippedBall")

		local total, have = 0, 0
		for index, rarity in rarities do
			local list = ballsOf(rarity.Name)
			local got = 0
			for _, ball in list do
				if owned[ball.Id] then
					got += 1
				end
			end
			total += #list
			have += got
			local tab = tabButtons[index]
			local selected = index == page
			tab.Text = ("%s %d/%d"):format(rarity.Name:upper(), got, #list)
			tab.BackgroundColor3 = if selected then rarity.Color else TAB
			tab.TextColor3 = if selected then INK else rarity.Color
			local outline = tab:FindFirstChildOfClass("UIStroke")
			if outline then
				outline.Color = rarity.Color
			end
		end
		countLabel.Text = ("%d / %d BALLS COLLECTED"):format(have, total)

		for _, child in cards:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(spinning)
		table.clear(polishButtons)
		local rarity = rarities[page]
		local list = ballsOf(rarity.Name)
		local got = 0
		for order, ball in list do
			local isOwned = owned[ball.Id] == true
			if isOwned then
				got += 1
			end
			makeCard(ball, isOwned, order, ball.Id == equipped, #list)
		end
		pageTitle.Text = if got == #list
			then ("%s  ·  PAGE COMPLETE!"):format(rarity.Name:upper())
			else ("%s  ·  %d OF %d FOUND"):format(rarity.Name:upper(), got, #list)
		pageTitle.TextColor3 = rarity.Color
		detail.Text = "Point at or tap a ball to read its traits"
	end

	for index, rarity in rarities do
		local tab = Instance.new("TextButton")
		tab.Name = rarity.Name
		tab.LayoutOrder = index
		tab.Size = UDim2.new(0.158, 0, 1, 0)
		tab.FontFace = FONT
		tab.TextScaled = true
		tab.AutoButtonColor = true
		corner(tab, 8)
		stroke(tab, rarity.Color, 1.5)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 7)
		pad.PaddingBottom = UDim.new(0, 5)
		pad.PaddingLeft = UDim.new(0, 4)
		pad.PaddingRight = UDim.new(0, 4)
		pad.Parent = tab
		local limit = Instance.new("UITextSizeConstraint") -- keeps the tabs' text the same size
		limit.MaxTextSize = 14
		limit.Parent = tab
		tab.Parent = tabs
		tabButtons[index] = tab
		tab.Activated:Connect(function()
			page = index
			render()
		end)
	end

	-- Opens on the page of the ball you're throwing (or the ball the equip guide points at)
	local function equippedPage(): number
		local current = Balls.Get(guideBall or player:GetAttribute("EquippedBall")) or Config.Balls[1]
		for index, rarity in rarities do
			if rarity.Name == current.Rarity then
				return index
			end
		end
		return 1
	end

	local function setOpen(open: boolean)
		if open then
			-- Same spot and size as the BALLS panel (which already has the phone layout applied)
			book.Position = inventory.Position
			book.Size = inventory.Size
			page = equippedPage()
			render()
			gui.Shop.Visible = false
			UiFx.Close(inventory)
			UiFx.Open(book)
		else
			if guideBall and book.Visible then
				guideBall = nil -- the guide was shown in the book; don't keep nagging
			end
			UiFx.Close(book)
		end
	end

	ballsButton.Activated:Connect(function()
		setOpen(not book.Visible)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	local polishShown = Balls.DecodePolish(player:GetAttribute("Polish"))
	player:GetAttributeChangedSignal("Polish"):Connect(function()
		local now = Balls.DecodePolish(player:GetAttribute("Polish"))
		if book.Visible then
			render()
			-- The ball that just went up a Polish level gets a little bounce
			for id, points in now do
				local card = if points ~= polishShown[id] then cards:FindFirstChild(id) else nil
				if card then
					UiFx.Pop(card :: GuiObject, 1.08, 0.35)
				end
			end
		end
		polishShown = now
	end)
	player:GetAttributeChangedSignal("Gems"):Connect(function()
		for button, price in polishButtons do
			paintPolish(button, price)
		end
	end)
	player:GetAttributeChangedSignal("OwnedBalls"):Connect(function()
		if book.Visible then
			render()
		end
	end)
	player:GetAttributeChangedSignal("EquippedBall"):Connect(function()
		guideBall = nil
		updateButton()
		if book.Visible then
			render()
		end
	end)
	book.Active = true -- taps on the book don't fall through to the throw meter

	-- Ball meshes download in the background; a ball drawn before its mesh arrived stayed blank
	-- (the Rookie, 2026-10-19), so once every ball has loaded the book and the button draw again
	task.spawn(function()
		local models = ReplicatedStorage:WaitForChild("BallModels", 30)
		if not models then
			return
		end
		pcall(ContentProvider.PreloadAsync, ContentProvider, { models })
		updateButton(true)
		if book.Visible then
			render()
		end
	end)

	-- Equip guide (see GuideEquip): the BALLS button glows gold, then an arrow points at the ball's EQUIP button
	local guideGui = Instance.new("ScreenGui")
	guideGui.Name = "EquipGuide"
	guideGui.ResetOnSpawn = false
	guideGui.DisplayOrder = 30
	guideGui.IgnoreGuiInset = gui.IgnoreGuiInset
	guideGui.Parent = player:WaitForChild("PlayerGui")
	local arrow = text(guideGui, "Arrow", FONT, Color3.fromRGB(255, 200, 40))
	arrow.Text = "<"
	arrow.Rotation = -90 -- points down
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(46, 46)
	arrow.ZIndex = 50
	arrow.Visible = false
	stroke(arrow, INK, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	local arrowWasOn: GuiObject? = nil
	-- The BALLS button's own outline turns gold while it pulses
	local ballsGlow = ballsButton:FindFirstChildOfClass("UIStroke") or stroke(ballsButton, INK, 2)
	local glowColor, glowThickness = ballsGlow.Color, ballsGlow.Thickness
	local ballsScale = ballsButton:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	ballsScale.Parent = ballsButton
	local ballsPulsing = false

	RunService.RenderStepped:Connect(function(dt)
		-- Equip guide: the BALLS button glows and pulses; in the book an arrow points down at the ball's EQUIP
		local target: GuiObject? = nil
		local pulseBalls = false
		if guideBall then
			if book.Visible then
				local card = cards:FindFirstChild(guideBall)
				target = card and card:FindFirstChild("Equip") :: GuiObject?
			elseif ballsButton.Visible and gui.Enabled then
				pulseBalls = true
			end
		end
		local wave = math.abs(math.sin(os.clock() * 6))
		if pulseBalls then
			ballsGlow.Color = Color3.fromRGB(255, 200, 40)
			ballsGlow.Thickness = glowThickness + 2 + 2 * wave
			ballsScale.Scale = 1 + 0.12 * wave
		elseif ballsPulsing then
			ballsGlow.Color = glowColor
			ballsGlow.Thickness = glowThickness
			ballsScale.Scale = 1
		end
		ballsPulsing = pulseBalls
		arrow.Visible = target ~= nil
		if target then
			local pos, size = target.AbsolutePosition, target.AbsoluteSize
			arrow.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y - 26 - wave * 12)
			if arrowWasOn ~= target then
				UiFx.Pop(arrow, 1.6, 0.4)
			end
		end
		arrowWasOn = target

		local turn = CFrame.Angles(0, dt * SPIN_SPEED, 0)
		if buttonModel and buttonView.Visible then
			spin(buttonModel, turn)
		end
		if not book.Visible then
			return
		end
		for _, model in spinning do
			spin(model, turn)
		end
	end)
end

return CollectionBookController
