-- The collection book: every ball in the game, one page per rarity. Owned balls spin in 3D;
-- the ones you're missing show as dark silhouettes with their traits, so you know what to chase.
-- Opened with the BOOK button in the BALLS panel. Built in code (not in Studio), so it lives in git.
-- Ownership comes from the OwnedBalls Player attribute the server sets.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local UiFx = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("UiFx"))

local player = Players.LocalPlayer

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local INK = Color3.fromHex("06060F")
local CARD = Color3.fromRGB(30, 20, 60)
local TAB = Color3.fromRGB(22, 14, 44)
local SILHOUETTE = Color3.fromRGB(28, 22, 48)
local GOLD = Color3.fromRGB(255, 200, 40)
local SPIN_SPEED = 0.6 -- turns of the owned balls, radians per second

local CollectionBookController = {}

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

-- The ball's 3D model, sitting at the origin and one stud wide (or a plain sphere if it has none)
local function ballModel(ball): Instance
	local models = ReplicatedStorage:FindFirstChild("BallModels")
	local source = models and models:FindFirstChild(ball.Id)
	if source then
		local model = source:Clone() :: Model
		model:PivotTo(CFrame.new())
		return model
	end
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one
	part.Color = ball.Color
	part.Material = ball.Material or Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new()
	return part
end

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

	-- BOOK in the BALLS panel, and BALLS in the book to go back
	local function headerButton(parent: Instance, label: string): TextButton
		local button = Instance.new("TextButton")
		button.Name = label .. "Button"
		button.AnchorPoint = Vector2.new(1, 0)
		button.Position = UDim2.new(1, -62, 0, 8)
		button.Size = UDim2.fromOffset(104, 44)
		button.BackgroundColor3 = GOLD
		button.FontFace = FONT
		button.Text = label
		button.TextScaled = true
		button.TextColor3 = INK
		button.AutoButtonColor = true
		corner(button, 10)
		stroke(button, INK, 2)
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 8)
		pad.PaddingBottom = UDim.new(0, 6)
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = button
		button.Parent = parent
		return button
	end
	local openButton = headerButton(inventory, "BOOK")
	local backButton = headerButton(book, "BALLS")

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

	local page = 1
	local spinning: { Instance } = {}
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

	local function makeCard(ball, owned: boolean, order: number, equipped: boolean)
		local rarity = Balls.GetRarity(ball.Rarity)
		local card = Instance.new("TextButton")
		card.Name = ball.Id
		card.Text = ""
		card.AutoButtonColor = false
		card.LayoutOrder = order
		card.Size = UDim2.new(0.186, 0, 1, 0)
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
		view.Size = UDim2.new(1, -16, 0.46, 0)
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
		if equipped then
			local tag = text(card, "Equipped", FONT, INK)
			tag.AnchorPoint = Vector2.new(0.5, 0)
			tag.Position = UDim2.new(0.5, 0, 0, -8)
			tag.Size = UDim2.new(0.8, 0, 0, 20)
			tag.BackgroundTransparency = 0
			tag.BackgroundColor3 = Color3.fromRGB(70, 230, 255)
			tag.Text = "EQUIPPED"
			tag.ZIndex = 3
			corner(tag, 8)
		end

		local name = text(card, "BallName", FONT, if owned then Color3.new(1, 1, 1) else rarity.Color)
		name.Position = UDim2.new(0, 6, 0.5, 6)
		name.Size = UDim2.new(1, -12, 0.1, 0)
		name.Text = if owned then ball.Name:upper() else "???"
		stroke(name, INK, 1.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

		local stats = text(card, "Stats", BODY_FONT, Color3.fromRGB(200, 190, 230))
		stats.Position = UDim2.new(0, 6, 0.61, 4)
		stats.Size = UDim2.new(1, -12, 0.07, 0)
		stats.Text = if owned then ("x%g COINS"):format(ball.Multiplier) else "FIND IT IN CRATES"

		-- Traits show on missing balls too, so you know what you're chasing (short tags, one per line)
		local traits = text(card, "Traits", FONT, Color3.new(1, 1, 1))
		traits.Position = UDim2.new(0, 8, 0.7, 4)
		traits.Size = UDim2.new(1, -16, 0.3, -12)
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
		local rarity = rarities[page]
		local list = ballsOf(rarity.Name)
		local got = 0
		for order, ball in list do
			local isOwned = owned[ball.Id] == true
			if isOwned then
				got += 1
			end
			makeCard(ball, isOwned, order, ball.Id == equipped)
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

	-- Opens on the first page you haven't finished
	local function firstUnfinishedPage(): number
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		for index, rarity in rarities do
			for _, ball in ballsOf(rarity.Name) do
				if not owned[ball.Id] then
					return index
				end
			end
		end
		return 1
	end

	local function setOpen(open: boolean)
		if open then
			-- Same spot and size as the BALLS panel (which already has the phone layout applied)
			book.Position = inventory.Position
			book.Size = inventory.Size
			page = firstUnfinishedPage()
			render()
			gui.Shop.Visible = false
			UiFx.Close(inventory)
			UiFx.Open(book)
		else
			UiFx.Close(book)
		end
	end

	openButton.Activated:Connect(function()
		setOpen(true)
	end)
	backButton.Activated:Connect(function()
		setOpen(false)
		UiFx.Open(inventory)
	end)
	close.Activated:Connect(function()
		setOpen(false)
	end)
	player:GetAttributeChangedSignal("OwnedBalls"):Connect(function()
		if book.Visible then
			render()
		end
	end)
	player:GetAttributeChangedSignal("EquippedBall"):Connect(function()
		if book.Visible then
			render()
		end
	end)
	book.Active = true -- taps on the book don't fall through to the throw meter

	RunService.RenderStepped:Connect(function(dt)
		if not book.Visible then
			return
		end
		local turn = CFrame.Angles(0, dt * SPIN_SPEED, 0)
		for _, model in spinning do
			if model:IsA("Model") then
				model:PivotTo(model:GetPivot() * turn)
			elseif model:IsA("BasePart") then
				model.CFrame *= turn
			end
		end
	end)
end

return CollectionBookController
