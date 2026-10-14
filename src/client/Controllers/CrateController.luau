-- The crate shop (prices, visible odds, pity counter) and the crate opening reel.
-- The UI itself (StarterGui.BallsUI) is built in Studio; this script fills it in and animates it.
-- The server picks the ball; the reel only shows what the server already decided.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local BallInventoryController = require(script.Parent.BallInventoryController)

local player = Players.LocalPlayer

local REEL_TILES = 42 -- tiles on the reel
local REEL_WIN_INDEX = 36 -- the tile that holds the real result
local TILE_WIDTH = 112
local TILE_GAP = 8
local SPIN_TIME = 4.5
local CAN_AFFORD = Color3.fromRGB(90, 230, 110)
local CANT_AFFORD = Color3.fromRGB(110, 100, 130)
local EPIC_INDEX = 4 -- Epic and better get the extra-special reveal

local CrateController = {}

local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end

local function pressFeedback(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale")
	if not scale then
		return
	end
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08), { Scale = 0.9 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
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
	local shopButton = gui:WaitForChild("Menu"):WaitForChild("ShopButton") :: TextButton
	local panel = gui:WaitForChild("Shop") :: Frame
	local panelScale = panel:WaitForChild("UIScale") :: UIScale
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
			panel.Visible = true
			panelScale.Scale = 0.6
			TweenService:Create(panelScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		else
			panel.Visible = false
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

	-- Plays the reel, then the reveal. Returns when the player taps Continue.
	local function playOpening(crate, result)
		local ball = Balls.Get(result.BallId)
		local rarity = Balls.GetRarity(ball.Rarity)
		local rarityIndex = Balls.RarityIndex(ball.Rarity)

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

		-- Line the winning tile up under the marker, landing a little off-centre so it feels natural
		local center = window.AbsoluteSize.X / 2
		local winCenter = (REEL_WIN_INDEX - 1) * (TILE_WIDTH + TILE_GAP) + TILE_WIDTH / 2
		local jitter = (math.random() - 0.5) * TILE_WIDTH * 0.7
		strip.Position = UDim2.fromOffset(center - TILE_WIDTH * 2, 0)
		local spin =
			TweenService:Create(strip, TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Position = UDim2.fromOffset(center - winCenter + jitter, 0),
			})
		spin:Play()

		-- Anticipation: the window shakes harder as the reel slows down
		task.delay(SPIN_TIME * 0.6, function()
			for i = 1, 10 do
				window.Rotation = (if i % 2 == 0 then 1 else -1) * (0.4 + i * 0.08)
				task.wait(0.05)
			end
			window.Rotation = 0
		end)
		spin.Completed:Wait()
		task.wait(0.35)

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
		reveal.Visible = true
		continueButton.Visible = false

		local big = rarityIndex >= EPIC_INDEX
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
		continueButton.Visible = true
		continueButton.Activated:Wait()
		if pulse then
			pulse:Cancel()
			reveal.Glow.BackgroundTransparency = 0.5
		end
		opening.Visible = false
		strip:ClearAllChildren()
	end

	local function buy(crate)
		if busy then
			return
		end
		if (player:GetAttribute("Coins") or 0) < crate.Price then
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
		setOpen(true) -- straight back to the shop for the next one
	end

	-- One card per crate, odds shown straight from Config
	for order, crate in Config.Crates do
		local card = cardTemplate:Clone()
		card.Name = crate.Id
		card.LayoutOrder = order
		card.Visible = true
		card.CrateName.Text = crate.Name:upper()
		card.CrateName.TextColor3 = crate.Color
		card.UIStroke.Color = crate.Color

		local rowTemplate = card.OddsRowTemplate
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
		pressFeedback(buyButton)
		buyButton.Activated:Connect(function()
			buy(crate)
		end)

		local function refreshAfford()
			local canAfford = (player:GetAttribute("Coins") or 0) >= crate.Price
			buyButton.BackgroundColor3 = if canAfford then CAN_AFFORD else CANT_AFFORD
		end
		player:GetAttributeChangedSignal("Coins"):Connect(refreshAfford)
		refreshAfford()

		card.Parent = cards
	end

	for _, pity in Config.Pity do
		player:GetAttributeChangedSignal(pity.Counter):Connect(refreshPity)
	end
	refreshPity()

	pressFeedback(shopButton)
	shopButton.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	panel:WaitForChild("Close").Activated:Connect(function()
		setOpen(false)
	end)
	panel.Active = true -- taps on the panel don't fall through to the throw meter
	panel.Visible = false
	opening.Visible = false
end

return CrateController
