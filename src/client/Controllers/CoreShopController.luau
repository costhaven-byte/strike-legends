-- Addendum 4 Stage 2: the ball and bag shop (Config.CoreLoop Balls / BagSizes / BagPrices, Shared.Modules.CoreLadder).
-- Balls and bags are bought in a fixed order, alternating ball, bag, ball, bag. Opens from the BALLS button or by
-- standing on the blue circle at the plaza's shop booth. Same look as CoreHudController (the owner's simulator refs):
-- flat fills, thick dark outlines, one hard shadow, rounded Fredoka text with a thin outline.
-- The server (CoreLoopService, CoreBuy remote) checks the order and the coins; this only shows them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetSlots = require(Shared.AssetSlots)
local Balls = require(Shared.Modules.Balls)
local CoreLadder = require(Shared.Modules.CoreLadder)
local Currency = require(Shared.Modules.Currency)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local CORE = Config.CoreLoop
local player = Players.LocalPlayer

local CoreShopController = {}

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local INK = Color3.fromRGB(24, 28, 36)
local PANEL = Color3.fromRGB(46, 51, 60)
local CARD = Color3.fromRGB(62, 68, 80)
local GREEN = Color3.fromRGB(76, 209, 55)
local GREY = Color3.fromRGB(110, 116, 128)
local GOLD = Color3.fromRGB(255, 205, 60)
local CORAL = Color3.fromRGB(255, 99, 72)
local SOFT = Color3.fromRGB(196, 204, 214)
local WHITE = Color3.new(1, 1, 1)

local W, H = 720, 430 -- window size at 1080p (UIScale shrinks it on small screens)

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(class)
	for key, value in props do
		(object :: any)[key] = value
	end
	object.Parent = parent
	return object
end

local function text(parent: Instance, value: string, props: { [string]: any }?): TextLabel
	local label = new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = value,
		TextColor3 = WHITE,
		TextScaled = true,
		Size = UDim2.fromScale(1, 1),
	}, parent)
	new("UIStroke", { Color = INK, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round }, label)
	for key, v in props or {} do
		(label :: any)[key] = v
	end
	return label
end

-- A flat plate with a thick dark outline and one hard shadow straight below. Returns (holder, face).
local function plate(parent: Instance, name: string, color: Color3, radius: number, shadow: number?): (Frame, Frame)
	local holder = new("Frame", { Name = name, BackgroundTransparency = 1 }, parent)
	local under = new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.25,
		Position = UDim2.fromOffset(0, shadow or 4),
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, under)
	local face = new("Frame", {
		Name = "Face",
		BackgroundColor3 = color,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, holder)
	new("UICorner", { CornerRadius = UDim.new(0, radius) }, face)
	new("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
	return holder, face
end

-- A ball drawn as a flat circle in its colour with a small shine
local function ballDot(parent: Instance, ballId: string, size: UDim2, position: UDim2): Frame
	local ball = Balls.Get(ballId)
	local dot = new("Frame", {
		Name = "Ball",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = if ball then ball.Color else WHITE,
		BorderSizePixel = 0,
		Size = size,
		Position = position,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
	}, parent)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, dot)
	new("UIStroke", { Color = INK, Thickness = 3 }, dot)
	local shine = new("Frame", {
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0.28, 0.28),
		Position = UDim2.fromScale(0.2, 0.16),
	}, dot)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shine)
	return dot
end

function CoreShopController:Start()
	if not CORE.Enabled then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buyRemote = remotes:WaitForChild("CoreBuy") :: RemoteFunction

	local gui = new("ScreenGui", {
		Name = "CoreShopUI",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)
	-- Tap outside the window = close
	local backdrop = new("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = INK,
		BackgroundTransparency = 0.55,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, gui)
	local window, face = plate(gui, "Window", PANEL, 10, 6)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Position = UDim2.fromScale(0.5, 0.52)
	window.Size = UDim2.fromOffset(W, H)
	window.Visible = false
	local scale = new("UIScale", {}, window)
	local function fit()
		local view = Workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(view.X / (W + 40), view.Y / (H + 60), 1.25)
	end
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	fit()

	-- Title strip: a gold tab, square on the bottom, tilted a hair
	local _, titleFace = plate(face, "Title", GOLD, 6, 3)
	local titleHolder = titleFace.Parent :: Frame
	titleHolder.Size = UDim2.fromOffset(220, 52)
	titleHolder.Position = UDim2.fromOffset(18, -26)
	titleHolder.Rotation = -2
	text(titleFace, "Shop", { Size = UDim2.new(1, -16, 0.8, 0), Position = UDim2.new(0, 8, 0.1, 0) })
	local closeHolder, closeFace = plate(face, "Close", CORAL, 8, 3)
	closeHolder.Size = UDim2.fromOffset(48, 48)
	closeHolder.Position = UDim2.new(1, -30, 0, -18)
	text(closeFace, "X", { Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15) })
	local closeButton = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, closeFace)

	-- The ladder: all 10 balls in a row, the ones you own in colour, the next one ringed
	local row = new("Frame", {
		Name = "Ladder",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -48, 0, 46),
		Position = UDim2.fromOffset(24, 40),
	}, face)
	local dots = {}
	for step, entry in CORE.Balls do
		local x = (step - 0.5) / #CORE.Balls
		local dot = ballDot(row, entry.Ball, UDim2.fromScale(0.86, 0.86), UDim2.fromScale(x, 0.5))
		local lock = text(dot, tostring(step), {
			Name = "Step",
			Size = UDim2.fromScale(0.7, 0.7),
			Position = UDim2.fromScale(0.15, 0.15),
		})
		dots[step] = { Dot = dot, Step = lock, Color = dot.BackgroundColor3 }
	end

	-- Two cards: the next ball and the next bag
	local function card(name: string, x: number)
		local holder, cardFace = plate(face, name, CARD, 6, 4)
		holder.Size = UDim2.new(0.5, -36, 0, 290)
		holder.Position = UDim2.new(x, if x == 0 then 24 else 12, 0, 108)
		local header = text(cardFace, "", {
			Name = "Header",
			Size = UDim2.new(1, -24, 0, 30),
			Position = UDim2.fromOffset(12, 10),
			TextColor3 = SOFT,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local title = text(cardFace, "", {
			Name = "Name",
			Size = UDim2.new(1, -24, 0, 40),
			Position = UDim2.fromOffset(12, 40),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local art = new("Frame", {
			Name = "Art",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -24, 0, 84),
			Position = UDim2.fromOffset(12, 86),
		}, cardFace)
		local line = text(cardFace, "", {
			Name = "Line",
			Size = UDim2.new(1, -24, 0, 26),
			Position = UDim2.fromOffset(12, 176),
			TextColor3 = SOFT,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local buttonHolder, buttonFace = plate(cardFace, "Buy", GREEN, 12, 4)
		buttonHolder.Size = UDim2.new(1, -24, 0, 58)
		buttonHolder.Position = UDim2.new(0, 12, 1, -72)
		new("ImageLabel", {
			Name = "Coin",
			BackgroundTransparency = 1,
			Image = AssetSlots.Image("HudCoin"),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(34, 34),
			Position = UDim2.new(0, 12, 0.5, -17),
		}, buttonFace)
		local buttonText = text(buttonFace, "", {
			Size = UDim2.new(1, -64, 0.62, 0),
			Position = UDim2.new(0, 52, 0.19, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		local button = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, buttonFace)
		return {
			Holder = holder,
			Header = header,
			Name = title,
			Art = art,
			Line = line,
			ButtonHolder = buttonHolder,
			ButtonFace = buttonFace,
			ButtonText = buttonText,
			Coin = buttonFace:FindFirstChild("Coin") :: ImageLabel,
			Button = button,
		}
	end
	local ballCard = card("BallCard", 0)
	local bagCard = card("BagCard", 0.5)
	local bagIcon = new("ImageLabel", {
		Name = "BagIcon",
		BackgroundTransparency = 1,
		Image = AssetSlots.Image("StoreBag"),
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
	}, bagCard.Art)

	local busy = false
	local function refresh()
		local ballStep = CoreLadder.BallStep(player:GetAttribute("BallStep"))
		local bagLevel = CoreLadder.BagLevel(player:GetAttribute("BagLevel"))
		local coins = player:GetAttribute("Coins") or 0
		local kind, _, price = CoreLadder.Next(ballStep, bagLevel)

		for step, entry in dots do
			local owned = step <= ballStep
			entry.Dot.BackgroundColor3 = if owned then entry.Color else GREY
			entry.Dot.BackgroundTransparency = if owned then 0 else 0.35
			entry.Step.Visible = not owned
			local ring = entry.Dot:FindFirstChildOfClass("UIStroke") :: UIStroke
			ring.Color = if step == ballStep + 1 then GOLD elseif step == ballStep then WHITE else INK
			ring.Thickness = if step == ballStep + 1 or step == ballStep then 4 else 3
		end

		-- Ball card
		local nextBall = ballStep + 1
		local ballArt = ballCard.Art:FindFirstChild("Ball")
		if ballArt then
			ballArt:Destroy()
		end
		if nextBall <= #CORE.Balls then
			local entry = CORE.Balls[nextBall]
			ballCard.Header.Text = ("Ball %d of %d"):format(nextBall, #CORE.Balls)
			ballCard.Name.Text = entry.Name
			ballDot(ballCard.Art, entry.Ball, UDim2.fromScale(0.95, 0.95), UDim2.fromScale(0.5, 0.5))
			ballCard.Line.Text = ("About %d pins a throw (now %d)"):format(entry.Pins, CORE.Balls[ballStep].Pins)
		else
			local entry = CORE.Balls[ballStep]
			ballCard.Header.Text = "Your ball"
			ballCard.Name.Text = entry.Name
			ballDot(ballCard.Art, entry.Ball, UDim2.fromScale(0.95, 0.95), UDim2.fromScale(0.5, 0.5))
			ballCard.Line.Text = ("About %d pins a throw"):format(entry.Pins)
		end

		-- Bag card
		local nextBag = bagLevel + 1
		if nextBag <= #CORE.BagSizes then
			bagCard.Header.Text = ("Bag %d of %d"):format(nextBag, #CORE.BagSizes)
			bagCard.Name.Text = ("Holds %s coins"):format(Currency.Format(CORE.BagSizes[nextBag]))
			bagCard.Line.Text = ("Yours holds %s"):format(Currency.Format(CORE.BagSizes[bagLevel]))
		else
			bagCard.Header.Text = "Your bag"
			bagCard.Name.Text = ("Holds %s coins"):format(Currency.Format(CORE.BagSizes[bagLevel]))
			bagCard.Line.Text = "Biggest bag"
		end

		-- Buttons: only the next step can be bought; the other card says what comes first
		for _, pair in { { ballCard, "Ball", nextBall <= #CORE.Balls }, { bagCard, "Bag", nextBag <= #CORE.BagSizes } } do
			local c, cardKind, left = pair[1], pair[2], pair[3]
			if not left then
				c.ButtonFace.BackgroundColor3 = GREY
				c.ButtonText.Text = "Got it all"
				c.Coin.Visible = false
			elseif kind == cardKind then
				local can = coins >= price
				c.ButtonFace.BackgroundColor3 = if can then GREEN else GREY
				c.ButtonText.Text = if can
					then ("Buy  %s"):format(Currency.Format(price))
					else ("%s / %s"):format(Currency.Format(coins), Currency.Format(price))
				c.Coin.Visible = true
			else
				c.ButtonFace.BackgroundColor3 = GREY
				c.ButtonText.Text = if cardKind == "Ball" then "Get the bag first" else "Get the ball first"
				c.Coin.Visible = false
			end
		end
	end
	for _, key in { "BallStep", "BagLevel", "Coins" } do
		player:GetAttributeChangedSignal(key):Connect(function()
			if window.Visible then
				refresh()
			end
		end)
	end

	local function shake(object: GuiObject)
		local x = object.Position
		for _, dx in { 8, -8, 5, -5, 0 } do
			object.Position = x + UDim2.fromOffset(dx, 0)
			task.wait(0.03)
		end
		object.Position = x
	end

	local function tryBuy(c, cardKind: string)
		if busy then
			return
		end
		local kind = CoreLadder.Next(player:GetAttribute("BallStep"), player:GetAttribute("BagLevel"))
		if kind ~= cardKind then
			Sfx.Play("Error", 1, 0.6)
			task.spawn(shake, c.ButtonHolder)
			return
		end
		busy = true
		local ok, result = pcall(buyRemote.InvokeServer, buyRemote, cardKind)
		busy = false
		if ok and type(result) == "table" and result.Ok then
			Sfx.Play("Coin", 1, 1.2)
			Sfx.Play("SpinWin", 1.1, 0.7)
			UiFx.Pop(c.Holder, 1.08, 0.2)
			UiFx.Flash(GREEN, 0.12, 0.2)
			refresh()
		else
			Sfx.Play("Error", 1, 0.6)
			task.spawn(shake, c.ButtonHolder)
			local message = if ok and type(result) == "table" then result.Error else nil
			if message then
				local old = c.ButtonText.Text
				c.ButtonText.Text = message
				task.delay(1.2, function()
					if c.ButtonText.Text == message then
						c.ButtonText.Text = old
						refresh()
					end
				end)
			end
		end
	end
	ballCard.Button.Activated:Connect(function()
		tryBuy(ballCard, "Ball")
	end)
	bagCard.Button.Activated:Connect(function()
		tryBuy(bagCard, "Bag")
	end)

	-- Open / close
	local open = false
	local function setOpen(on: boolean)
		if on == open then
			return
		end
		open = on
		backdrop.Visible = on
		if on then
			refresh()
			Sfx.Play("Click")
			UiFx.Open(window)
		else
			UiFx.Close(window)
		end
	end
	CoreShopController.SetOpen = setOpen
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	backdrop.Activated:Connect(function()
		setOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and open and input.KeyCode == Enum.KeyCode.Escape then
			setOpen(false)
		end
	end)

	-- The BALLS button opens the shop (the old Ball Book stays shut in the core loop)
	task.spawn(function()
		local ballsUi = playerGui:WaitForChild("BallsUI", 30)
		local button = ballsUi and ballsUi:WaitForChild("Menu", 10):WaitForChild("BallsButton", 10) :: GuiButton?
		if button then
			button.Activated:Connect(function()
				setOpen(not open)
			end)
		end
	end)

	-- Standing on the booth's blue circle opens it (once per visit; walking off closes it)
	local onPad = false
	task.spawn(function()
		while true do
			task.wait(0.2)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local here = false
			if root then
				local offset = root.Position - CORE.Shop.Position
				here = Vector2.new(offset.X, offset.Z).Magnitude <= CORE.Shop.Radius and offset.Y > -2 and offset.Y < 8
			end
			if here and not onPad then
				setOpen(true)
			elseif not here and onPad then
				setOpen(false)
			end
			onPad = here
		end
	end)

	gui.Parent = playerGui
end

return CoreShopController
