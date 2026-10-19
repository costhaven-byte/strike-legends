-- The crate shop (prices, visible odds, pity counter, the "next unlock" goal) and the crate opening reel.
-- The shop screen opens from the lobby kiosk (KioskController); there's no menu button for it.
-- The UI itself (StarterGui.BallsUI) is built in Studio; this script fills it in and animates it.
-- The server picks the ball; the reel only shows what the server already decided.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local BallInventoryController = require(script.Parent.BallInventoryController)
local CollectionBookController = require(script.Parent.CollectionBookController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local BallView = require(Modules.BallView)

local player = Players.LocalPlayer

local REEL_TILES = 42 -- tiles on the reel
local REEL_WIN_INDEX = 36 -- the tile that holds the real result
local TILE_WIDTH = 112
local TILE_GAP = 8
local SPIN_TIME = Config.CrateShop.SpinTime
local CAN_AFFORD = Color3.fromRGB(90, 230, 110)
local CANT_AFFORD = Color3.fromRGB(110, 100, 130)
local EPIC_INDEX = 4 -- Epic and better get the extra-special reveal
local LEGENDARY_INDEX = 5 -- Legendary and better get even more

local CrateController = {}

local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end

-- A random ball using the crate's odds, for the filler tiles on the reel
local function randomBall(crate)
	local roll = math.random() * 100
	local rarityName = Config.Rarities[1].Name
	for _, rarity in Config.Rarities do
		roll -= crate.Odds[rarity.Name] or 0
		if roll <= 0 then
			rarityName = rarity.Name
			break
		end
	end
	local pool = {}
	for _, ball in Config.Balls do
		if ball.Rarity == rarityName and ball.InCrates ~= false then
			table.insert(pool, ball)
		end
	end
	return pool[math.random(#pool)]
end

function CrateController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BallsUI")
	local panel = gui:WaitForChild("Shop") :: Frame
	local cards = panel:WaitForChild("Cards") :: ScrollingFrame
	local cardTemplate = panel:WaitForChild("CardTemplate") :: Frame
	local pityLabel = panel:WaitForChild("Pity") :: TextLabel
	local tileTemplate = gui:WaitForChild("Inventory"):WaitForChild("TileTemplate") :: TextButton
	local toast = gui:WaitForChild("Toast") :: TextLabel

	local opening = gui:WaitForChild("Opening") :: Frame
	local window = opening:WaitForChild("Window") :: Frame
	local strip = window:WaitForChild("Strip") :: Frame
	local status = opening:WaitForChild("Status") :: TextLabel
	local reveal = opening:WaitForChild("Reveal") :: Frame
	local revealScale = reveal:WaitForChild("UIScale") :: UIScale
	local flash = opening:WaitForChild("Flash") :: Frame
	local continueButton = reveal:WaitForChild("Continue") :: TextButton

	local openCrate = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OpenCrate") :: RemoteFunction
	local equipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipBall") :: RemoteEvent

	local busy = false
	local toastToken = 0
	local showOdds: (crate: any) -> () -- the odds screen, built further down

	local function showToast(text: string)
		toastToken += 1
		local token = toastToken
		toast.Text = text:upper()
		toast.Visible = true
		toast.Rotation = 0
		for _, angle in { -4, 4, -2, 2, 0 } do
			TweenService:Create(toast, TweenInfo.new(0.05), { Rotation = angle }):Play()
			task.wait(0.05)
		end
		task.delay(1.5, function()
			if token == toastToken then
				toast.Visible = false
			end
		end)
	end

	local function setOpen(open: boolean)
		if open then
			gui.Inventory.Visible = false
			local book = gui:FindFirstChild("Book")
			if book then
				book.Visible = false
			end
			UiFx.Open(panel)
		else
			UiFx.Close(panel)
		end
	end

	-- Top line: the first crate's promise, then how pity works (each crate counts its own pulls)
	local function refreshPity()
		pityLabel.Text = if (player:GetAttribute("CratesOpened") or 0) == 0
			then ("YOUR FIRST CRATE IS %s OR BETTER!"):format(Config.Economy.FirstCrateMin:upper())
			else "EVERY CRATE HAS A GUARANTEE  ·  TAP ODDS FOR EVERY BALL'S CHANCE"
	end

	-- Pulls left (this one included) until a pity row of a crate guarantees its rarity
	local function pullsLeft(row): number
		return math.max(row.After - (player:GetAttribute("Pity_" .. row.Key) or 0), 1)
	end

	-- The "NEXT UNLOCK" card: the cheapest pity guarantee (in coins) that can still give you a ball you don't own,
	-- how many crates and coins away it is, and which balls it could be. Display only; the server rolls crates.
	local goal = cards:WaitForChild("Goal") :: Frame
	local goalList = goal:WaitForChild("List") :: Frame
	local goalRow = goalList:WaitForChild("RowTemplate") :: Frame

	local function lockedBalls(minRarity: number, owned, crate)
		local list = {}
		for _, ball in Balls.Sorted() do
			if
				ball.InCrates ~= false
				and not owned[ball.Id]
				and Balls.RarityIndex(ball.Rarity) >= minRarity
				and (not crate or (crate.Odds[ball.Rarity] or 0) > 0)
			then
				table.insert(list, ball)
			end
		end
		return list
	end

	local function refreshGoal()
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local coins = player:GetAttribute("Coins") or 0

		-- Cheapest guarantee that still has locked balls behind it
		local best, bestCrate, bestLeft, bestCost, bestLocked = nil, nil, 0, math.huge, nil
		for _, crate in Config.Crates do
			for _, row in Balls.PityRows(crate.Id) do
				local locked = lockedBalls(Balls.RarityIndex(row.Rarity), owned, crate)
				local left = pullsLeft(row)
				local cost = left * crate.Price
				if #locked > 0 and cost < bestCost then
					best, bestCrate, bestLeft, bestCost, bestLocked = row, crate, left, cost, locked
				end
			end
		end

		for _, child in goalList:GetChildren() do
			if child:IsA("Frame") and child ~= goalRow then
				child:Destroy()
			end
		end

		local target, bar, sub, coinsLabel = goal.Target, goal.Bar, goal.Sub, goal.Coins
		if not best then
			local anyLocked = lockedBalls(1, owned)
			target.Text = if #anyLocked == 0 then "ALL BALLS!" else "NEW BALLS"
			target.TextColor3 = Color3.fromRGB(255, 240, 90)
			sub.Text = if #anyLocked == 0 then "You own every ball" else "Keep opening crates"
			bar.Visible = false
			coinsLabel.Text = ""
			bestLocked = anyLocked
		else
			local rarity = Balls.GetRarity(best.Rarity)
			local done = best.After - bestLeft
			target.Text = best.Rarity:upper() .. "+"
			target.TextColor3 = rarity.Color
			sub.Text = ("guaranteed in %d %s%s"):format(bestLeft, bestCrate.Name, if bestLeft == 1 then "" else "s")
			bar.Visible = true
			bar.Fill.BackgroundColor3 = rarity.Color
			bar.Fill.Size = UDim2.fromScale(math.clamp(done / best.After, 0.03, 1), 1)
			bar.Count.Text = ("%d / %d CRATES"):format(done, best.After)
			coinsLabel.Text = if coins >= bestCost
				then "You can afford it now!"
				else ("%s coins to go"):format(formatNumber(bestCost - coins))
		end

		goal.CouldBe.Visible = #bestLocked > 0
		for i = 1, math.min(#bestLocked, 4) do
			local ball = bestLocked[#bestLocked - i + 1] -- the most likely ones (lowest rarity) first
			local row = goalRow:Clone()
			row.Name = ball.Id
			row.LayoutOrder = i
			row.Visible = true
			BallView.Put(row.Dot, ball, { Margin = 0.95 })
			row.BallName.Text = ('%s  <font color="#%s">%s</font>'):format(
				ball.Name,
				Balls.GetRarity(ball.Rarity).Color:ToHex(),
				ball.Rarity:upper()
			)
			row.Parent = goalList
		end
	end
	-- Centre the cards when they fit; when they don't (phones), line them up from the left so you can scroll
	local cardLayout = cards:WaitForChild("UIListLayout") :: UIListLayout
	local function alignCards()
		local fits = cardLayout.AbsoluteContentSize.X <= cards.AbsoluteSize.X
		cardLayout.HorizontalAlignment = if fits then Enum.HorizontalAlignment.Center else Enum.HorizontalAlignment.Left
	end
	cardLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(alignCards)
	cards:GetPropertyChangedSignal("AbsoluteSize"):Connect(alignCards)
	alignCards()

	for _, crate in Config.Crates do
		for _, row in Balls.PityRows(crate.Id) do
			player:GetAttributeChangedSignal("Pity_" .. row.Key):Connect(refreshGoal)
		end
	end
	player:GetAttributeChangedSignal("OwnedBalls"):Connect(refreshGoal)
	player:GetAttributeChangedSignal("Coins"):Connect(refreshGoal)
	refreshGoal()

	-- Intro: the crate itself (ReplicatedStorage.CrateModels) shakes harder and harder, then bursts in a flash
	local crateModels = ReplicatedStorage:WaitForChild("CrateModels", 10)
	local introView = Instance.new("ViewportFrame")
	introView.Name = "CrateIntro"
	introView.AnchorPoint = Vector2.new(0.5, 0.5)
	introView.Position = UDim2.fromScale(0.5, 0.55)
	introView.Size = UDim2.fromScale(0.5, 0.5)
	introView.BackgroundTransparency = 1
	introView.Ambient = Color3.fromRGB(200, 200, 220)
	introView.LightColor = Color3.new(1, 1, 1)
	introView.LightDirection = Vector3.new(-1, -1.5, -1)
	introView.Visible = false
	introView.ZIndex = 5
	local introAspect = Instance.new("UIAspectRatioConstraint")
	introAspect.Parent = introView
	local introCamera = Instance.new("Camera")
	introCamera.FieldOfView = 40
	introCamera.Parent = introView
	introView.CurrentCamera = introCamera
	introView.Parent = opening

	local function playIntro(crate)
		local template = crateModels and crateModels:FindFirstChild(crate.Id)
		if not template then
			return
		end
		local model = template:Clone()
		model:ScaleTo(4)
		local base = CFrame.Angles(0, math.rad(-25), 0)
		model:PivotTo(base)
		model.Parent = introView
		introCamera.CFrame = CFrame.lookAt(Vector3.new(0, 2.6, 12), Vector3.new(0, 0.3, 0))
		introView.Visible = true
		status.Visible = true
		status.Text = crate.Name:upper()
		status.TextColor3 = crate.Color
		UiFx.Pop(introView, 0.4, 0.25)

		local length = Config.CrateShop.IntroTime
		local start = os.clock()
		local nextTick = 0
		while true do
			local t = (os.clock() - start) / length
			if t >= 1 then
				break
			end
			local shake = 0.04 + t * t * 0.3 -- gentle wobble that builds up
			model:PivotTo(
				base
					* CFrame.new(0, t * 0.4, 0)
					* CFrame.Angles(
						(math.random() - 0.5) * shake,
						(math.random() - 0.5) * shake,
						(math.random() - 0.5) * shake
					)
			)
			introView.ImageColor3 = Color3.new(1, 1, 1):Lerp(crate.Color, t * 0.5)
			if t >= nextTick then
				Sfx.Play("ReelTick", 0.8 + t * 0.6)
				nextTick += 0.25 - t * 0.15
			end
			RunService.RenderStepped:Wait()
		end
		UiFx.Flash(crate.Color, 0.6, 0.35)
		introView.Visible = false
		introView.ImageColor3 = Color3.new(1, 1, 1)
		model:Destroy()
	end

	-- Plays the crate intro, the reel, then the reveal. Returns when the player taps Continue.
	-- equipPrompt: the button says EQUIP! and equips the new ball (the first-3-minutes gift crate)
	local function playOpening(crate, result, equipPrompt: boolean?)
		local ball = Balls.Get(result.BallId)
		local rarity = Balls.GetRarity(ball.Rarity)
		local rarityIndex = Balls.RarityIndex(ball.Rarity)

		opening.Visible = true
		reveal.Visible = false
		window.Visible = false
		playIntro(crate)

		strip:ClearAllChildren()
		for i = 1, REEL_TILES do
			local tile = tileTemplate:Clone()
			tile.Visible = true
			tile.Active = false
			tile.Position = UDim2.fromOffset((i - 1) * (TILE_WIDTH + TILE_GAP), 12)
			tile.Tag.Visible = false
			local shown = if i == REEL_WIN_INDEX then ball else randomBall(crate)
			BallInventoryController.FillTile(tile, shown, true)
			tile.Parent = strip
		end

		opening.Visible = true
		reveal.Visible = false
		window.Visible = true
		status.Visible = true
		status.Text = crate.Name:upper()
		status.TextColor3 = crate.Color
		window.UIStroke.Color = crate.Color

		-- Line the winning tile up under the marker, landing a little off-centre so it feels natural.
		-- Measured before the pop-in below, which briefly shrinks the window and would throw this off.
		local center = window.AbsoluteSize.X / 2
		UiFx.Pop(window, 0.6, 0.3)
		local winCenter = (REEL_WIN_INDEX - 1) * (TILE_WIDTH + TILE_GAP) + TILE_WIDTH / 2
		local jitter = (math.random() - 0.5) * TILE_WIDTH * 0.7
		strip.Position = UDim2.fromOffset(center - TILE_WIDTH * 2, 0)
		local spin =
			TweenService:Create(strip, TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(center - winCenter + jitter, 0),
			})
		spin:Play()

		-- A tick every time a tile passes the marker, slightly higher as it slows down
		local lastTile = nil
		local tick = RunService.RenderStepped:Connect(function()
			local tile = math.floor((center - strip.Position.X.Offset) / (TILE_WIDTH + TILE_GAP))
			if tile ~= lastTile then
				lastTile = tile
				Sfx.Play("ReelTick", 0.9 + math.clamp(tile / REEL_WIN_INDEX, 0, 1) * 0.4)
			end
		end)

		-- Anticipation: the window shakes harder and glows brighter as the reel slows down
		local stroke = window.UIStroke :: UIStroke
		local normalThickness = stroke.Thickness
		task.delay(SPIN_TIME * 0.6, function()
			TweenService:Create(stroke, TweenInfo.new(SPIN_TIME * 0.4), { Thickness = normalThickness * 3 }):Play()
			for i = 1, 10 do
				window.Rotation = (if i % 2 == 0 then 1 else -1) * (0.4 + i * 0.08)
				task.wait(0.05)
			end
			window.Rotation = 0
		end)
		spin.Completed:Wait()
		tick:Disconnect()
		task.wait(0.35)
		stroke.Thickness = normalThickness

		-- Reveal
		window.Visible = false
		status.Text = if rarityIndex >= EPIC_INDEX then ball.Rarity:upper() .. "!!" else ""
		status.TextColor3 = rarity.Color
		BallView.Put(reveal.Swatch, ball, { Spin = true })
		reveal.Glow.BackgroundColor3 = rarity.Color
		reveal.Rarity.Text = ball.Rarity:upper()
		reveal.Rarity.TextColor3 = rarity.Color
		reveal.BallName.Text = ball.Name
		reveal.BallName.TextColor3 = if rarityIndex >= EPIC_INDEX then rarity.Color else Color3.new(1, 1, 1)
		if result.IsNew then
			reveal.Info.Text = ('<font color="#5AE66E">NEW!</font>   x%g coins'):format(ball.Multiplier)
		elseif result.PolishLevel then
			-- Duplicate: the ball got polished (+5% of its multiplier per level)
			reveal.Info.Text = ('Duplicate - <font color="#FFE15A">POLISH %d/%d</font>   x%g coins'):format(
				result.PolishLevel,
				Config.Economy.Polish.MaxLevel,
				math.floor(Balls.Multiplier(ball, result.PolishLevel) * 100 + 0.5) / 100
			)
		else
			reveal.Info.Text = ('Fully polished - sold for <font color="#FFC828">+%s coins</font>'):format(
				formatNumber(result.SellCoins)
			)
		end
		if result.FromPity then
			reveal.Info.Text ..= '   <font color="#5AE66E">GUARANTEED!</font>'
		end
		local traits = Balls.DescribeTraits(ball, false, true)
		reveal.Trait.Text = if traits == "" then "No special trait" else traits
		reveal.Visible = true
		continueButton.Visible = false

		local big = rarityIndex >= EPIC_INDEX
		Sfx.Play(if big then "RevealBig" else "Reveal")
		if big then
			UiFx.Confetti(
				opening,
				if rarityIndex >= LEGENDARY_INDEX then 80 else 40,
				{ rarity.Color, Color3.new(1, 1, 1) }
			)
		end
		if rarityIndex >= LEGENDARY_INDEX then
			-- Legendary and Mythic: a second flash and a firework bang
			task.delay(0.4, function()
				UiFx.Flash(rarity.Color, 0.5, 0.6)
				Sfx.Play("Firework")
			end)
		end
		flash.BackgroundColor3 = if big then rarity.Color else Color3.new(1, 1, 1)
		flash.BackgroundTransparency = if big then 0 else 0.5
		TweenService:Create(flash, TweenInfo.new(if big then 0.9 else 0.4), { BackgroundTransparency = 1 }):Play()
		revealScale.Scale = 0.2
		TweenService:Create(
			revealScale,
			TweenInfo.new(if big then 0.8 else 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
		reveal.Glow.Size = UDim2.fromOffset(120, 120)
		TweenService:Create(reveal.Glow, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {
			Size = UDim2.fromOffset(if big then 260 else 190, if big then 260 else 190),
		}):Play()

		-- Epic and up: the glow keeps pulsing until you continue
		local pulse
		if big then
			pulse = TweenService:Create(
				reveal.Glow,
				TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ BackgroundTransparency = 0.2 }
			)
			task.delay(0.6, function()
				pulse:Play()
			end)
		end

		task.wait(if big then 1.2 else 0.6)
		local continueText = continueButton.Text
		if equipPrompt then
			continueButton.Text = "EQUIP IT!"
			UiFx.Pop(continueButton, 1.25)
		end
		continueButton.Visible = true
		continueButton.Activated:Wait()
		continueButton.Text = continueText
		if equipPrompt then
			equipRemote:FireServer(ball.Id)
			Sfx.Play("StreakUp", 1.2)
		end
		if pulse then
			pulse:Cancel()
			reveal.Glow.BackgroundTransparency = 0.5
		end
		UiFx.Close(reveal)
		task.wait(0.15)
		opening.Visible = false
		strip:ClearAllChildren()
	end
	-- Lets other screens (like the daily reward) play a crate the server already opened
	CrateController.PlayOpening = function(crate, result, equipPrompt: boolean?)
		busy = true
		setOpen(false)
		playOpening(crate, result, equipPrompt)
		busy = false
	end

	-- Free crates (from strikes and Golden Pins) are used before coins on their crate type
	local function hasFree(crate): boolean
		return crate.Id == Config.FreeCrates.CrateId and (player:GetAttribute("FreeCrates") or 0) > 0
	end

	-- backToShop: reopen the shop afterwards (when bought from the shop screen, not the kiosk)
	local function buy(crate, backToShop: boolean?)
		if busy then
			return
		end
		if not hasFree(crate) and (player:GetAttribute("Coins") or 0) < crate.Price then
			task.spawn(showToast, "Not enough coins")
			return
		end
		busy = true
		local firstBought = not hasFree(crate) and (player:GetAttribute("CratesBought") or 0) == 0
		local ok, result = pcall(openCrate.InvokeServer, openCrate, crate.Id)
		if not ok or not result or not result.Ok then
			busy = false
			task.spawn(showToast, if ok and result and result.Error then result.Error else "Try again")
			return
		end
		setOpen(false)
		playOpening(crate, result)
		busy = false
		if firstBought and result.IsNew then
			-- The first crate bought with coins: arrows show how to equip its new ball (BALLS button, then EQUIP)
			CollectionBookController.GuideEquip(result.BallId)
			return
		end
		if backToShop ~= false then
			setOpen(true) -- straight back to the shop for the next one
		end
	end
	-- For the lobby kiosk: its buy buttons open a crate right away, its joystick opens the shop screen
	CrateController.Buy = function(crate)
		buy(crate, false)
	end
	CrateController.OpenShop = function()
		setOpen(true)
	end
	CrateController.HasFree = hasFree

	-- Odds screen: every ball a crate can give with its real chance, plus this crate's guarantees (Roblox wants
	-- every outcome and its numeric odds shown; built now so paid packs later are already covered)
	local oddsScreen = Instance.new("Frame")
	oddsScreen.Name = "OddsScreen"
	oddsScreen.AnchorPoint = Vector2.new(0.5, 0.5)
	oddsScreen.Position = UDim2.fromScale(0.5, 0.5)
	oddsScreen.Size = UDim2.new(0.9, 0, 1, -20)
	oddsScreen.BackgroundColor3 = Color3.fromRGB(28, 18, 48)
	oddsScreen.Active = true
	oddsScreen.Visible = false
	oddsScreen.ZIndex = 20
	local oddsSizeLimit = Instance.new("UISizeConstraint")
	oddsSizeLimit.MaxSize = Vector2.new(460, math.huge)
	oddsSizeLimit.Parent = oddsScreen
	local screenCorner = Instance.new("UICorner")
	screenCorner.CornerRadius = UDim.new(0, 14)
	screenCorner.Parent = oddsScreen
	local screenStroke = Instance.new("UIStroke")
	screenStroke.Thickness = 3
	screenStroke.Parent = oddsScreen
	local font = panel.Title.FontFace

	local function oddsText(name: string, props): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.FontFace = font
		l.TextScaled = true
		l.RichText = true
		l.TextColor3 = Color3.new(1, 1, 1)
		l.ZIndex = 21
		for key, value in props do
			(l :: any)[key] = value
		end
		return l
	end

	local oddsTitle = oddsText("Title", { Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -76, 0, 30) })
	oddsTitle.TextXAlignment = Enum.TextXAlignment.Left
	oddsTitle.Parent = oddsScreen
	local oddsClose = Instance.new("TextButton")
	oddsClose.Name = "Close"
	oddsClose.AnchorPoint = Vector2.new(1, 0)
	oddsClose.Position = UDim2.new(1, -10, 0, 8)
	oddsClose.Size = UDim2.fromOffset(40, 40)
	oddsClose.BackgroundColor3 = Color3.fromRGB(255, 70, 110)
	oddsClose.FontFace = font
	oddsClose.Text = "X"
	oddsClose.TextScaled = true
	oddsClose.TextColor3 = Color3.new(1, 1, 1)
	oddsClose.ZIndex = 21
	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 10)
	closeCorner.Parent = oddsClose
	oddsClose.Parent = oddsScreen
	local oddsPity = oddsText("Pity", { Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 40) })
	oddsPity.TextWrapped = true
	oddsPity.TextColor3 = Color3.fromRGB(200, 190, 230)
	oddsPity.Parent = oddsScreen
	local oddsList = Instance.new("ScrollingFrame")
	oddsList.Name = "List"
	oddsList.Position = UDim2.fromOffset(12, 92)
	oddsList.Size = UDim2.new(1, -24, 1, -102)
	oddsList.BackgroundTransparency = 1
	oddsList.BorderSizePixel = 0
	oddsList.ScrollBarThickness = 6
	oddsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	oddsList.CanvasSize = UDim2.new()
	oddsList.ZIndex = 21
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 2)
	listLayout.Parent = oddsList
	oddsList.Parent = oddsScreen
	oddsScreen.Parent = panel

	showOdds = function(crate)
		oddsTitle.Text = crate.Name:upper() .. "  ODDS"
		oddsTitle.TextColor3 = crate.Color
		screenStroke.Color = crate.Color
		local pityParts = {}
		for _, row in Balls.PityRows(crate.Id) do
			table.insert(
				pityParts,
				("%s or better guaranteed within %d pulls (%d to go)"):format(row.Rarity, row.After, pullsLeft(row))
			)
		end
		if (player:GetAttribute("CratesOpened") or 0) == 0 then
			table.insert(pityParts, ("Your first crate ever: %s or better"):format(Config.Economy.FirstCrateMin))
		end
		oddsPity.Text = table.concat(pityParts, "\n")

		for _, child in oddsList:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local order = 0
		local lastRarity = nil
		for _, entry in Balls.CrateBallOdds(crate) do
			local ball = entry.Ball
			local rarity = Balls.GetRarity(ball.Rarity)
			if ball.Rarity ~= lastRarity then
				-- Rarity header with that rarity's total chance
				lastRarity = ball.Rarity
				order += 1
				local header = oddsText(ball.Rarity, {
					LayoutOrder = order,
					Size = UDim2.new(1, -8, 0, 24),
					Text = ("%s  ·  %g%%"):format(ball.Rarity:upper(), crate.Odds[ball.Rarity]),
					TextColor3 = rarity.Color,
					TextXAlignment = Enum.TextXAlignment.Left,
				})
				header.Parent = oddsList
			end
			order += 1
			local row = oddsText(ball.Id, {
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 28),
				Text = ('%s%s  <font color="#%s">%.4g%%</font>'):format(
					ball.Name,
					if owned[ball.Id] then "" else '  <font color="#8C82A0">(new)</font>',
					rarity.Color:ToHex(),
					entry.Chance
				),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			-- The ball itself, in 3D, at the start of its row
			local rowPad = Instance.new("UIPadding")
			rowPad.PaddingLeft = UDim.new(0, 40)
			rowPad.PaddingTop = UDim.new(0, 4)
			rowPad.PaddingBottom = UDim.new(0, 4)
			rowPad.Parent = row
			local ballView = BallView.New(ball, { Margin = 0.95 })
			ballView.AnchorPoint = Vector2.new(0, 0.5)
			ballView.Position = UDim2.new(0, -32, 0.5, 0)
			ballView.Size = UDim2.fromOffset(28, 28)
			ballView.ZIndex = 22
			ballView.Parent = row
			row.Parent = oddsList
		end
		oddsList.CanvasPosition = Vector2.zero
		UiFx.Open(oddsScreen)
	end
	oddsClose.Activated:Connect(function()
		UiFx.Close(oddsScreen)
	end)

	-- One card per crate, odds shown straight from Config
	for order, crate in Config.Crates do
		local card = cardTemplate:Clone()
		card.Name = crate.Id
		card.LayoutOrder = order
		card.Visible = true
		card.CrateName.Text = crate.Name:upper()
		card.CrateName.TextColor3 = crate.Color
		card.UIStroke.Color = crate.Color

		-- Rows share the odds box evenly (20px tall at most) so every rarity fits on small screens too
		local rowTemplate = card.OddsRowTemplate
		rowTemplate.Size = UDim2.new(1, 0, 1 / #Config.Rarities, -2)
		local rowLimit = Instance.new("UISizeConstraint")
		rowLimit.MaxSize = Vector2.new(math.huge, 20)
		rowLimit.Parent = rowTemplate
		for _, label in { rowTemplate.Rarity, rowTemplate.Chance } do
			local textLimit = Instance.new("UITextSizeConstraint")
			textLimit.MaxTextSize = label.TextSize
			textLimit.Parent = label
			label.TextScaled = true
		end
		for index, rarity in Config.Rarities do
			local row = rowTemplate:Clone()
			row.Name = rarity.Name
			row.LayoutOrder = index
			row.Visible = true
			row.Rarity.Text = rarity.Name
			row.Rarity.TextColor3 = rarity.Color
			row.Chance.Text = ("%g%%"):format(crate.Odds[rarity.Name] or 0)
			row.Chance.TextColor3 = rarity.Color
			row.Parent = card.Odds
		end
		rowTemplate:Destroy()

		-- Room under the odds for this crate's guarantee line, and an ODDS button for every ball's chance
		card.Odds.Size = UDim2.new(1, -28, 1, -136)
		local pityLine = Instance.new("TextLabel")
		pityLine.Name = "PityLine"
		pityLine.BackgroundTransparency = 1
		pityLine.AnchorPoint = Vector2.new(0, 1)
		pityLine.Position = UDim2.new(0, 12, 1, -70)
		pityLine.Size = UDim2.new(1, -24, 0, 22)
		pityLine.FontFace = card.CrateName.FontFace
		pityLine.TextScaled = true
		pityLine.RichText = true
		pityLine.TextColor3 = Color3.fromRGB(200, 190, 230)
		pityLine.Parent = card
		local function refreshPityLine()
			local parts = {}
			for _, row in Balls.PityRows(crate.Id) do
				table.insert(
					parts,
					('<font color="#%s">%s+</font> in %d'):format(
						Balls.GetRarity(row.Rarity).Color:ToHex(),
						row.Rarity:upper(),
						pullsLeft(row)
					)
				)
			end
			pityLine.Text = table.concat(parts, "  ·  ")
		end
		for _, row in Balls.PityRows(crate.Id) do
			player:GetAttributeChangedSignal("Pity_" .. row.Key):Connect(refreshPityLine)
		end
		refreshPityLine()

		local oddsButton = Instance.new("TextButton")
		oddsButton.Name = "OddsButton"
		oddsButton.AnchorPoint = Vector2.new(1, 0)
		oddsButton.Position = UDim2.new(1, -8, 0, 8)
		oddsButton.Size = UDim2.fromOffset(52, 24)
		oddsButton.BackgroundColor3 = crate.Color
		oddsButton.FontFace = card.CrateName.FontFace
		oddsButton.Text = "ODDS"
		oddsButton.TextScaled = true
		oddsButton.TextColor3 = Color3.fromRGB(25, 15, 40)
		local oddsCorner = Instance.new("UICorner")
		oddsCorner.CornerRadius = UDim.new(0, 6)
		oddsCorner.Parent = oddsButton
		oddsButton.Parent = card
		card.CrateName.Size = UDim2.new(1, -76, 0, 26)
		oddsButton.Activated:Connect(function()
			showOdds(crate)
		end)

		local buyButton = card.Buy :: TextButton
		buyButton.Price.Text = formatNumber(crate.Price)
		buyButton.Activated:Connect(function()
			buy(crate)
		end)

		local coinIcon = buyButton:FindFirstChild("Coin") or buyButton:FindFirstChild("Icon")
		local function refreshAfford()
			local free = hasFree(crate)
			local canAfford = free or (player:GetAttribute("Coins") or 0) >= crate.Price
			buyButton.BackgroundColor3 = if canAfford then CAN_AFFORD else CANT_AFFORD
			buyButton.Price.Text = if free
				then ("OPEN FREE (%d)"):format(player:GetAttribute("FreeCrates"))
				else formatNumber(crate.Price)
			if coinIcon and coinIcon:IsA("GuiObject") then
				coinIcon.Visible = not free
			end
		end
		player:GetAttributeChangedSignal("Coins"):Connect(refreshAfford)
		player:GetAttributeChangedSignal("FreeCrates"):Connect(refreshAfford)
		refreshAfford()

		card.Parent = cards
	end

	player:GetAttributeChangedSignal("CratesOpened"):Connect(refreshPity)
	refreshPity()

	panel:WaitForChild("Close").Activated:Connect(function()
		setOpen(false)
	end)
	panel.Active = true -- taps on the panel don't fall through to the throw meter
	panel.Visible = false
	opening.Visible = false
end

return CrateController
