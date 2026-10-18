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
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

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
			UiFx.Open(panel)
		else
			UiFx.Close(panel)
		end
	end

	-- Pity line: always shows how close the next guarantee is
	local function refreshPity()
		local parts = {}
		for _, pity in Config.Pity do
			local left = pity.Crates - (player:GetAttribute(pity.Counter) or 0)
			table.insert(parts, ("%s+ in %d"):format(pity.Rarity, math.max(left, 1)))
		end
		pityLabel.Text = "GUARANTEED:  " .. table.concat(parts, "   ·   ") .. " crates"
	end

	-- The "NEXT UNLOCK" card: the closest pity guarantee that can still give you a ball you don't own,
	-- how many crates and coins away it is, and which balls it could be. Display only; the server rolls crates.
	local goal = cards:WaitForChild("Goal") :: Frame
	local goalList = goal:WaitForChild("List") :: Frame
	local goalRow = goalList:WaitForChild("RowTemplate") :: Frame
	local cheapest = Config.Crates[1]
	for _, crate in Config.Crates do
		if crate.Price < cheapest.Price then
			cheapest = crate
		end
	end

	local function lockedBalls(minRarity: number, owned)
		local list = {}
		for _, ball in Balls.Sorted() do
			if ball.InCrates ~= false and not owned[ball.Id] and Balls.RarityIndex(ball.Rarity) >= minRarity then
				table.insert(list, ball)
			end
		end
		return list
	end

	local function refreshGoal()
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local coins = player:GetAttribute("Coins") or 0

		-- Closest guarantee that still has locked balls behind it
		local best, bestLeft, bestLocked = nil, math.huge, nil
		for _, pity in Config.Pity do
			local locked = lockedBalls(Balls.RarityIndex(pity.Rarity), owned)
			local left = math.max(pity.Crates - (player:GetAttribute(pity.Counter) or 0), 1)
			if #locked > 0 and left < bestLeft then
				best, bestLeft, bestLocked = pity, left, locked
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
			local done = best.Crates - bestLeft
			target.Text = best.Rarity:upper() .. "+"
			target.TextColor3 = rarity.Color
			sub.Text = ("guaranteed in %d crate%s"):format(bestLeft, if bestLeft == 1 then "" else "s")
			bar.Visible = true
			bar.Fill.BackgroundColor3 = rarity.Color
			bar.Fill.Size = UDim2.fromScale(math.clamp(done / best.Crates, 0.03, 1), 1)
			bar.Count.Text = ("%d / %d CRATES"):format(done, best.Crates)
			local cost = bestLeft * cheapest.Price
			coinsLabel.Text = if coins >= cost
				then "You can afford it now!"
				else ("%s coins to go"):format(formatNumber(cost - coins))
		end

		goal.CouldBe.Visible = #bestLocked > 0
		for i = 1, math.min(#bestLocked, 4) do
			local ball = bestLocked[#bestLocked - i + 1] -- the most likely ones (lowest rarity) first
			local row = goalRow:Clone()
			row.Name = ball.Id
			row.LayoutOrder = i
			row.Visible = true
			row.Dot.BackgroundColor3 = ball.Color
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

	for _, pity in Config.Pity do
		player:GetAttributeChangedSignal(pity.Counter):Connect(refreshGoal)
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
		reveal.Swatch.BackgroundColor3 = ball.Color
		reveal.Glow.BackgroundColor3 = rarity.Color
		reveal.Rarity.Text = ball.Rarity:upper()
		reveal.Rarity.TextColor3 = rarity.Color
		reveal.BallName.Text = ball.Name
		reveal.BallName.TextColor3 = if rarityIndex >= EPIC_INDEX then rarity.Color else Color3.new(1, 1, 1)
		if result.IsNew then
			reveal.Info.Text = ('<font color="#5AE66E">NEW!</font>   x%g coins'):format(ball.Multiplier)
		else
			reveal.Info.Text = ('Duplicate - sold for <font color="#FFC828">+%s coins</font>'):format(
				formatNumber(result.SellCoins)
			)
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
		local ok, result = pcall(openCrate.InvokeServer, openCrate, crate.Id)
		if not ok or not result or not result.Ok then
			busy = false
			task.spawn(showToast, if ok and result and result.Error then result.Error else "Try again")
			return
		end
		setOpen(false)
		playOpening(crate, result)
		busy = false
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

	for _, pity in Config.Pity do
		player:GetAttributeChangedSignal(pity.Counter):Connect(refreshPity)
	end
	refreshPity()

	panel:WaitForChild("Close").Activated:Connect(function()
		setOpen(false)
	end)
	panel.Active = true -- taps on the panel don't fall through to the throw meter
	panel.Visible = false
	opening.Visible = false
end

return CrateController
