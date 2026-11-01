-- Addendum 4 core loop (Config.CoreLoop), the screen half: the live pin counter ("+1.2K" pins this throw, with a
-- LUCKY! badge on high rolls; Addendum 5 A1), the bag bar, the SELL
-- button (Addendum 5 A2: it teleports you onto the sell pad, where the bag sells: selling only happens there), the
-- BAG FULL, SELL prompt and the sold pop. Style from the owner's simulator refs (assets/ui_refs_addendum4): rounded bold Fredoka text with a thin
-- dark outline, flat fills, one hard offset shadow, thick dark outlines, corners that differ by element.
-- Everything here only shows numbers the server sends (Bag / BagSize attributes, ThrowResult, CoreSold).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetSlots = require(Shared.AssetSlots)
local Currency = require(Shared.Modules.Currency)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local HudKit = require(Modules.HudKit)
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local CORE = Config.CoreLoop
local player = Players.LocalPlayer

local CoreHudController = {}

-- The sunny look (Modules/SunKit, Addendum 4 Stage 3d): light panels with dark text, colour buttons with white text
local SunKit = require(Modules.SunKit)
local K = SunKit.C
local INK = K.Ink
local PANEL = K.Cream -- light panels
local TRACK = K.Track
local GREEN = K.Green
local GOLD = K.Sun
local CORAL = K.Coral
local WHITE = K.White
local MUTED = K.Muted

local new = SunKit.New
local text = SunKit.Text

-- A plate whose hard shadow is its own darker colour (ink for light panels)
local function plate(parent: Instance, name: string, color: Color3, radius: number): (Frame, Frame)
	return SunKit.Plate(parent, name, color, radius, 4, if color == PANEL then K.CreamLip else SunKit.Lip(color))
end

local function place(object: GuiObject, key: string)
	HudKit.OnLayout(function(phone)
		local position, size = HudKit.Spot(key, phone)
		object.Position = position
		object.Size = size :: UDim2
	end)
end

function CoreHudController:Start()
	if not CORE.Enabled then
		return
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	local gui = new("ScreenGui", {
		Name = "CoreHUD",
		ResetOnSpawn = false,
		DisplayOrder = hud.DisplayOrder + 1,
		IgnoreGuiInset = hud.IgnoreGuiInset, -- same spots as the HUD (HudKit.Spot)
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, nil)

	-- ===== Pin counter: the real pins of your last throw (big-number format), counts up as your pins fall =====
	local counter, counterFace = plate(gui, "PinCounter", PANEL, 8)
	place(counter, "PinCounter")
	local counterText = text(counterFace, "0", {
		Size = UDim2.new(1, -16, 0.68, 0),
		Position = UDim2.new(0, 8, 0.06, 0),
		TextColor3 = INK,
	})
	local counterNote = text(counterFace, "Pins down", {
		Body = true,
		Size = UDim2.new(1, -16, 0.26, 0),
		Position = UDim2.new(0, 8, 0.7, 0),
		TextColor3 = MUTED,
	})
	local counterScale = new("UIScale", {}, counter)
	-- LUCKY! badge: a tilted gold tag on the counter's top-right corner, pops in on a high luck roll
	local lucky, luckyFace = plate(counter, "Lucky", GOLD, 8)
	lucky.AnchorPoint = Vector2.new(0.5, 0.5)
	lucky.Position = UDim2.fromScale(0.9, 0)
	lucky.Size = UDim2.new(0.42, 0, 0.5, 0)
	lucky.Rotation = 8
	lucky.ZIndex = 5
	lucky.Visible = false
	text(luckyFace, "LUCKY!", { Size = UDim2.new(1, -8, 0.84, 0), Position = UDim2.new(0, 4, 0.08, 0) })
	local luckyScale = new("UIScale", { Scale = 0 }, lucky)
	local luckyRun = 0
	local function popLucky()
		luckyRun += 1
		local run = luckyRun
		lucky.Visible = true
		luckyScale.Scale = 0
		TweenService:Create(luckyScale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.delay(0.75, function()
			if run == luckyRun then
				local out = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				TweenService:Create(luckyScale, out, { Scale = 0 }):Play()
			end
		end)
	end
	local counterRun = 0
	local function showCount(count: number, isLucky: boolean, full: boolean)
		counterRun += 1
		local run = counterRun
		SunKit.Recolor(counterText, if isLucky then K.SunLip else INK)
		counterNote.Text = if full then "Bag full, sell" else "Pins down"
		counterNote.TextColor3 = if full then K.CoralLip else MUTED
		counterScale.Scale = if isLucky then 1.2 else 1.08
		TweenService:Create(counterScale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if isLucky then
			popLucky()
		end
		local began = os.clock()
		task.spawn(function()
			while run == counterRun do
				local t = math.min((os.clock() - began) / 0.15, 1)
				counterText.Text = Currency.Format(math.floor(count * t + 0.5))
				if t >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
		end)
	end

	-- ===== Bag bar + SELL =====
	local bag, bagFace = plate(gui, "Bag", PANEL, 6)
	place(bag, "Bag")
	new("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = AssetSlots.Image("StoreBag"),
		ScaleType = Enum.ScaleType.Fit,
		SizeConstraint = Enum.SizeConstraint.RelativeYY,
		Size = UDim2.fromScale(0.9, 0.9),
		Position = UDim2.fromScale(0.02, 0.05),
	}, bagFace)
	local track = new("Frame", {
		Name = "Track",
		BackgroundColor3 = TRACK,
		BorderSizePixel = 0,
		Position = UDim2.new(0.26, 0, 0.22, 0),
		Size = UDim2.new(0.7, 0, 0.56, 0),
		ClipsDescendants = true,
	}, bagFace)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, track)
	new("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, track)
	local fill = new("Frame", {
		Name = "Fill",
		BackgroundColor3 = GREEN,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
	}, track)
	new("UICorner", { CornerRadius = UDim.new(0, 4) }, fill)
	local bagText = text(track, "0/0", { Size = UDim2.new(1, -8, 0.86, 0), Position = UDim2.new(0, 4, 0.07, 0) })

	local sell, sellFace = plate(gui, "Sell", CORAL, 12)
	place(sell, "Sell")
	local sellButton = new("TextButton", {
		Name = "Button",
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
	}, sellFace)
	text(sellFace, "Sell", { Size = UDim2.new(0.8, 0, 0.52, 0), Position = UDim2.new(0.1, 0, 0.24, 0) })
	local sellScale = new("UIScale", {}, sell)

	-- ===== BAG FULL, SELL prompt: a slightly tilted coral card =====
	local prompt, promptFace = plate(gui, "BagFull", CORAL, 4)
	place(prompt, "BagFull")
	prompt.Rotation = -2
	prompt.Visible = false
	text(promptFace, "Your bag is full", { Size = UDim2.new(1, -20, 0.6, 0), Position = UDim2.new(0, 10, 0.08, 0) })
	text(promptFace, "Tap Sell to cash it in", {
		Size = UDim2.new(1, -20, 0.26, 0),
		Position = UDim2.new(0, 10, 0.68, 0),
		Body = true,
		TextColor3 = Color3.fromRGB(255, 240, 214),
	})

	-- ===== Pointers: a beam from you to a pad and a bobbing marker over it (sell station, and the shop for the guide) =====
	local roof = Workspace:WaitForChild(CORE.Folder)
	local function pointer(name: string, model: string, color: Color3, words: string): (boolean) -> ()
		local station = roof:WaitForChild(model, 30)
		local pad = station and station:WaitForChild("Pad", 10) :: BasePart?
		local beacon = pad and pad:WaitForChild("Beacon", 10) :: Attachment?
		local beam: Beam? = nil
		local from: Attachment? = nil
		local marker = new("BillboardGui", {
			Name = name .. "Marker",
			Size = UDim2.fromOffset(150, 70),
			StudsOffset = Vector3.new(0, 14, 0),
			AlwaysOnTop = true,
			LightInfluence = 0,
			Enabled = false,
			Adornee = pad,
		}, gui)
		local markerPlate, markerFace = plate(marker, "Plate", color, 10)
		markerPlate.Size = UDim2.new(1, -8, 0, 44)
		markerPlate.Position = UDim2.fromOffset(4, 0)
		text(markerFace, words, { Size = UDim2.new(1, -12, 0.8, 0), Position = UDim2.new(0, 6, 0.1, 0) })
		text(marker, "▼", {
			Size = UDim2.fromOffset(30, 22),
			Position = UDim2.new(0.5, -15, 0, 46),
			TextColor3 = color,
		})
		return function(on: boolean)
			marker.Enabled = on
			marker.StudsOffset = Vector3.new(0, 14 + math.sin(os.clock() * 3) * 0.8, 0)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if on and root and beacon then
				if not from or from.Parent ~= root then
					from = new("Attachment", { Name = name, Position = Vector3.new(0, -2.4, 0) }, root)
				end
				if not beam then
					beam = new("Beam", {
						Name = name,
						Color = ColorSequence.new(color),
						Width0 = 0.9,
						Width1 = 0.9,
						FaceCamera = true,
						LightEmission = 0.2,
						Transparency = NumberSequence.new(0.15),
						Segments = 1,
					}, gui)
				end
				local b = beam :: Beam
				b.Attachment0 = from
				b.Attachment1 = beacon
				b.Parent = Workspace
				b.Enabled = true
			elseif beam then
				beam.Enabled = false
			end
		end
	end
	local sellGuide = pointer("SellGuide", "SellStation", GREEN, "Sell here")
	local shopGuide = pointer("ShopGuide", "BallShop", CORE.Shop.Color, "Shop")
	local guideUntil = 0 -- the SELL button turns the sell pointer on for a while

	-- ===== First 30 seconds (Stage 3): Throw > Sell > Buy until ball 2 is bought =====
	-- One card under the pin counter (in the BAG FULL spot; that card waits while this one is up). The step comes from
	-- what you have: not enough in the bag yet = throw, enough to buy once sold = sell, enough coins = buy.
	local GUIDE = CORE.Guide
	local firstBall = CORE.Balls[2]
	local tutor, tutorFace = plate(gui, "Guide", PANEL, 6)
	place(tutor, "BagFull")
	tutor.Visible = false
	local stepLabels = {}
	for i, word in { "Throw", "Sell", "Buy" } do
		stepLabels[i] = text(tutorFace, word, {
			Size = UDim2.new(0.28, 0, 0.5, 0),
			Position = UDim2.new(0.04 + (i - 1) * 0.32, 0, 0.05, 0),
		})
		if i < 3 then
			text(tutorFace, "›", {
				Size = UDim2.new(0.04, 0, 0.5, 0),
				Position = UDim2.new(0.32 + (i - 1) * 0.32, 0, 0.05, 0),
				TextColor3 = MUTED,
			})
		end
	end
	local tutorLine = text(tutorFace, "", {
		Body = true,
		Size = UDim2.new(1, -20, 0.32, 0),
		Position = UDim2.new(0, 10, 0.6, 0),
		TextColor3 = INK,
	})
	local ballsButton: GuiObject? = nil
	task.spawn(function()
		local ballsUi = playerGui:WaitForChild("BallsUI", 30)
		ballsButton = ballsUi and ballsUi:WaitForChild("Menu", 10):WaitForChild("BallsButton", 10) :: GuiObject?
	end)
	local ballsScale: UIScale? = nil
	local tutorStep = 0
	local tutorDoneAt: number? = nil
	local tutorWasOn = false
	local function guideStep(): number
		if not GUIDE.Enabled or (tonumber(player:GetAttribute("BallStep")) or 1) >= 2 then
			return 0
		end
		local coins = player:GetAttribute("Coins") or 0
		local amount = player:GetAttribute("Bag") or 0
		local size = player:GetAttribute("BagSize") or CORE.BagSizes[1]
		if coins >= firstBall.Price then
			return 3
		elseif amount > 0 and (amount >= size or coins + amount >= firstBall.Price) then
			return 2
		end
		return 1
	end
	local function showTutor(step: number)
		if step == tutorStep then
			return
		end
		tutorStep = step
		for i, label in stepLabels do
			SunKit.Recolor(label, if i == step then CORAL elseif i < step then GREEN else K.CreamLip)
		end
		tutorLine.Text = if step == 1
			then "Hold Throw to bowl"
			elseif step == 2 then "That's enough. Tap Sell"
			else ("%d coins. Buy the %s at the shop"):format(firstBall.Price, firstBall.Name)
		if step > 1 then
			Sfx.Play("Click")
			UiFx.Pop(tutor, 1.1, 0.18)
		end
	end

	-- SELL: teleports you onto the sell pad (the server moves you; the pad sells the bag)
	local goRemote = remotes:WaitForChild("CoreGoTo") :: RemoteEvent
	local lastGo = 0
	sellButton.Activated:Connect(function()
		Sfx.Play("Click")
		sellScale.Scale = 0.92
		TweenService:Create(sellScale, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		if os.clock() - lastGo < CORE.Teleport.Cooldown then
			return
		end
		lastGo = os.clock()
		goRemote:FireServer("Sell")
		Sfx.Play("Teleport", 1.1, 0.6)
		UiFx.Flash(WHITE, 0.25, 0.25)
		guideUntil = os.clock() + 4 -- (the beam shows for a moment in case the teleport was refused)
	end)

	-- Bag numbers from the server
	local lastBag = 0
	local function refreshBag()
		local amount = player:GetAttribute("Bag") or 0
		local size = math.max(player:GetAttribute("BagSize") or CORE.BagSizes[1], 1)
		local share = math.clamp(amount / size, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.15), { Size = UDim2.fromScale(share, 1) }):Play()
		fill.BackgroundColor3 = if share >= 1 then CORAL else GREEN
		bagText.Text = Currency.Format(amount) .. "/" .. Currency.Format(size)
		if amount > lastBag then
			UiFx.Pop(bag, 1.04, 0.12)
		end
		if share < 1 and counterNote.Text == "Bag full, sell" then
			counterNote.Text = "Pins down"
			counterNote.TextColor3 = MUTED
		end
		lastBag = amount
	end
	for _, key in { "Bag", "BagSize" } do
		player:GetAttributeChangedSignal(key):Connect(refreshBag)
	end
	refreshBag()

	-- Your own throws: the counter
	remotes:WaitForChild("ThrowResult").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or not data.Core or data.UserId ~= player.UserId then
			return
		end
		task.delay(data.RollTime or 0, showCount, data.Count or 0, data.Lucky == true, data.BagFull == true)
	end)

	-- Sold at the station: coins fly up from the bag
	remotes:WaitForChild("CoreSold").OnClientEvent:Connect(function(amount)
		guideUntil = 0
		Sfx.Play("Coin", 1, 1.4)
		Sfx.Play("SpinWin", 1.2, 0.6)
		UiFx.Flash(GREEN, 0.15, 0.25)
		-- A green tag with the amount rises in the middle, above THROW (the left column is full of buttons)
		local phone = HudKit.Phone()
		local pop, popFace = plate(gui, "SoldPop", GREEN, 8)
		pop.AnchorPoint = Vector2.new(0.5, 1)
		pop.Size = if phone then UDim2.fromOffset(150, 40) else UDim2.fromOffset(230, 60)
		pop.Position = UDim2.new(0.5, 0, 1, if phone then -110 else -170)
		pop.Rotation = -3
		pop.ZIndex = 5
		new("ImageLabel", {
			BackgroundTransparency = 1,
			Image = AssetSlots.Image("HudCoin"),
			ScaleType = Enum.ScaleType.Fit,
			SizeConstraint = Enum.SizeConstraint.RelativeYY,
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.04, 0.1),
		}, popFace)
		text(popFace, "+" .. Currency.Format(amount), {
			Size = UDim2.new(0.66, 0, 0.7, 0),
			Position = UDim2.new(0.3, 0, 0.15, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		UiFx.Pop(pop, 1.2, 0.18)
		TweenService:Create(pop, TweenInfo.new(1.1, Enum.EasingStyle.Quint), {
			Position = pop.Position + UDim2.fromOffset(0, -60),
		}):Play()
		task.delay(0.8, function()
			for _, object in pop:GetDescendants() do
				local goal = if object:IsA("TextLabel")
					then { TextTransparency = 1 }
					elseif object:IsA("ImageLabel") then { ImageTransparency = 1, BackgroundTransparency = 1 }
					elseif object:IsA("Frame") then { BackgroundTransparency = 1 }
					elseif object:IsA("UIStroke") then { Transparency = 1 }
					else nil
				if goal then
					TweenService:Create(object, TweenInfo.new(0.35), goal):Play()
				end
			end
		end)
		task.delay(1.3, function()
			pop:Destroy()
		end)
	end)

	-- Every frame: the prompt and the guides
	local wasFull = false
	RunService.RenderStepped:Connect(function()
		local amount = player:GetAttribute("Bag") or 0
		local size = player:GetAttribute("BagSize") or CORE.BagSizes[1]
		local full = amount >= size
		if full and not wasFull then
			Sfx.Play("Error", 1, 0.6)
			UiFx.Pop(prompt, 1.15, 0.2)
		end
		wasFull = full
		local step = guideStep()
		if step > 0 then
			tutorWasOn = true
			tutorDoneAt = nil
			showTutor(step)
		elseif tutorWasOn and not tutorDoneAt then
			-- ball 2 bought: the card says so for a moment, then goes for good
			tutorDoneAt = os.clock()
			tutorStep = 4
			for _, label in stepLabels do
				SunKit.Recolor(label, GREEN)
			end
			tutorLine.Text = "That's it. Keep throwing for the next one"
			UiFx.Pop(tutor, 1.12, 0.2)
		end
		tutor.Visible = step > 0 or (tutorDoneAt ~= nil and os.clock() - tutorDoneAt < GUIDE.DoneSeconds)
		if tutor.Visible then
			tutor.Rotation = -1.5
		end
		prompt.Visible = full and not tutor.Visible
		if full then
			prompt.Rotation = -2 + math.sin(os.clock() * 4) * 1.2
		end
		sellScale.Scale = if full or step == 2 then 1 + math.abs(math.sin(os.clock() * 5)) * 0.06 else sellScale.Scale
		sellGuide((full or step == 2 or os.clock() < guideUntil) and amount > 0)
		shopGuide(step == 3)
		-- the BALLS button (the price list with GO TO SHOP) bounces while it's time to buy
		if ballsButton and not ballsScale then
			ballsScale = (ballsButton :: GuiObject):FindFirstChild("GuideScale") :: UIScale?
				or new("UIScale", { Name = "GuideScale" }, ballsButton)
		end
		if ballsScale then
			ballsScale.Scale = if step == 3 then 1 + math.abs(math.sin(os.clock() * 5)) * 0.12 else 1
		end
	end)

	gui.Parent = playerGui
end

return CoreHudController
