-- The Power Level button on the left of the screen (owner's HUD Kit, 2026-10-26): your level and the next price,
-- with a bar that fills up as coins come in; it turns lime and glows "BUY!" once you can afford it, gold at MAX. Buying plays a power-up moment;
-- the bigger ball shows in your hand right away and on the lane from the very next throw.
-- Batch D2: a small pill under the button says what the next level pays ("x1.5 > x2 COINS"; at MAX "x12 COINS"),
-- and the power-up moment says it too.
-- Built in code (not in Studio), so it lives in git. Prices: Config.Economy.PowerLevels.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SunKit = require(script.Parent.Parent:WaitForChild("Modules"):WaitForChild("SunKit"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local PowerLevels = require(Shared.Modules.PowerLevels)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local HudKit = require(Modules.HudKit)
local K = HudKit.C

local player = Players.LocalPlayer

local FONT = SunKit.Swap(Font.new("rbxasset://fonts/families/LuckiestGuy.json"))
local INK = Color3.fromHex("06060F")
local GOLD = Color3.fromRGB(255, 200, 40)
local CYAN = Color3.fromRGB(70, 230, 255)
local LIME = Color3.fromRGB(125, 255, 60)

local PowerLevelController = {}

local short = Currency.Format -- Config.Numbers

-- The "POWER LEVEL 3!" moment in the middle of the screen (kept a size that doesn't swallow the screen)
local function celebrate(level: number)
	local layer = UiFx.Layer()
	local banner = Instance.new("TextLabel")
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.38)
	banner.Size = UDim2.new(0.4, 0, 0, 46)
	banner.BackgroundTransparency = 1
	banner.FontFace = FONT
	banner.TextScaled = true
	banner.TextColor3 = GOLD
	banner.Text = ("POWER LEVEL %d!"):format(level)
	banner.ZIndex = 40
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = banner
	local sub = banner:Clone()
	sub.Position = UDim2.new(0.5, 0, 0.38, 38)
	sub.Size = UDim2.new(0.35, 0, 0, 20)
	sub.TextColor3 = CYAN
	sub:FindFirstChildOfClass("UIStroke").Thickness = 2
	local new = PowerLevels.NewText(level)
	sub.Text = if new ~= "" then new .. " - THROW TO SEE IT!" else "THROW TO SEE IT!"
	-- the coin payoff: "COINS x1.5 > x2"
	local pay = sub:Clone()
	pay.Position = UDim2.new(0.5, 0, 0.38, 64)
	pay.Size = UDim2.new(0.35, 0, 0, 24)
	pay.TextColor3 = LIME
	local was = PowerLevels.Get(level - 1).Value
	pay.Text = ("COINS %s > %s"):format(
		Currency.FormatMultiplier(was),
		Currency.FormatMultiplier(PowerLevels.Get(level).Value)
	)
	banner.Parent = layer
	sub.Parent = layer
	pay.Parent = layer
	UiFx.Pop(banner, 1.8, 0.45)
	UiFx.Pop(sub, 0.4, 0.45)
	UiFx.Pop(pay, 0.6, 0.45)
	UiFx.Flash(GOLD, 0.45, 0.4)
	UiFx.Confetti(nil, 50)
	Sfx.Play("PowerUp")
	task.delay(1.8, function()
		for _, object in { banner, sub, pay } do
			TweenService:Create(object, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
			TweenService:Create(object:FindFirstChildOfClass("UIStroke") :: UIStroke, TweenInfo.new(0.3), {
				Transparency = 1,
			}):Play()
			task.delay(0.35, object.Destroy, object)
		end
	end)
end

function PowerLevelController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buyRemote = remotes:WaitForChild("BuyPowerLevel") :: RemoteFunction
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "PowerUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = (hud.DisplayOrder or 0)
	gui.IgnoreGuiInset = hud.IgnoreGuiInset

	-- HUD Kit POWER LV button: SAVING (dark, bar fills with your coins), BUY! (lime, glowing), MAX POWER! (gold)
	local block = HudKit.Block(gui, { Name = "PowerButton", Button = true, Paint = "Card", Radius = 16, Lip = 6 })
	local button = block.Holder :: TextButton
	local face = block.Face
	local bolt = HudKit.Image(face, "Bolt", 40)
	bolt.AnchorPoint = Vector2.new(0, 0.5)
	local title = HudKit.Text(face, "", HudKit.Head, 16, K.White, 2)
	title.Name = "Title"
	title.TextXAlignment = Enum.TextXAlignment.Left
	-- Saving: the price bar
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.BackgroundColor3 = K.Panel
	track.ZIndex = 4
	track.Parent = face
	local trackCorner = HudKit.Corner(track, 8)
	HudKit.Outline(track, K.Ink, 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = K.Lime
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 5
	fill.Parent = track
	local fillCorner = HudKit.Corner(fill, 8)
	local fillLip = Instance.new("UIGradient")
	fillLip.Rotation = 90
	fillLip.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, K.Lime),
		ColorSequenceKeypoint.new(0.8, K.Lime),
		ColorSequenceKeypoint.new(0.81, K.LimeLip),
		ColorSequenceKeypoint.new(1, K.LimeLip),
	})
	fillLip.Parent = fill
	local priceRow = Instance.new("Frame")
	priceRow.Name = "Price"
	priceRow.BackgroundTransparency = 1
	priceRow.Size = UDim2.fromScale(1, 1)
	priceRow.ZIndex = 6
	priceRow.Parent = track
	local priceLayout = Instance.new("UIListLayout")
	priceLayout.FillDirection = Enum.FillDirection.Horizontal
	priceLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	priceLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	priceLayout.Padding = UDim.new(0, 3)
	priceLayout.SortOrder = Enum.SortOrder.LayoutOrder
	priceLayout.Parent = priceRow
	local priceCoin = HudKit.Image(priceRow, "Coin", 14)
	priceCoin.LayoutOrder = 1
	priceCoin.ZIndex = 7
	local priceText = HudKit.Text(priceRow, "", HudKit.Num, 13, K.White, 1.5)
	priceText.LayoutOrder = 2
	priceText.AutomaticSize = Enum.AutomaticSize.X
	priceText.Size = UDim2.fromScale(0, 1)
	priceText.ZIndex = 7
	-- Buy: "BUY!" in gold + the price in white
	local buyRow = Instance.new("Frame")
	buyRow.Name = "Buy"
	buyRow.BackgroundTransparency = 1
	buyRow.ZIndex = 4
	buyRow.Parent = face
	local buyLayout = priceLayout:Clone()
	buyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	buyLayout.Padding = UDim.new(0, 4)
	buyLayout.Parent = buyRow
	local buyWord = HudKit.Text(buyRow, "BUY!", HudKit.Head, 22, K.Gold, 2.5)
	buyWord.LayoutOrder = 1
	buyWord.AutomaticSize = Enum.AutomaticSize.X
	buyWord.Size = UDim2.fromScale(0, 1)
	local buyPrice = HudKit.Text(buyRow, "", HudKit.Num, 15, K.White, 2.5)
	buyPrice.LayoutOrder = 2
	buyPrice.AutomaticSize = Enum.AutomaticSize.X
	buyPrice.Size = UDim2.fromScale(0, 1)
	-- Max: one big line
	local maxText = HudKit.Text(face, "MAX POWER!", HudKit.Head, 22, K.White, 2.5)
	maxText.Name = "Max"
	maxText.TextXAlignment = Enum.TextXAlignment.Left

	-- The coin payoff pill, sitting on the bottom edge of the button ("x1.5 > x2 COINS")
	local payPill = Instance.new("Frame")
	payPill.Name = "Payoff"
	payPill.AnchorPoint = Vector2.new(0.5, 0.5)
	payPill.AutomaticSize = Enum.AutomaticSize.X
	payPill.BackgroundColor3 = K.Ink
	payPill.ZIndex = 8
	payPill.Parent = button
	HudKit.Corner(payPill, 9)
	local payRing = HudKit.Outline(payPill, K.Gold, 1.5)
	local payPad = Instance.new("UIPadding")
	payPad.PaddingLeft = UDim.new(0, 7)
	payPad.PaddingRight = UDim.new(0, 7)
	payPad.Parent = payPill
	local payText = HudKit.Text(payPill, "", HudKit.Num, 12, K.Gold, 0)
	payText.AutomaticSize = Enum.AutomaticSize.X
	payText.Size = UDim2.fromScale(0, 1)
	payText.ZIndex = 9

	local mode = ""
	local phone = false
	local function arrange()
		local p = phone
		bolt.Size = UDim2.fromOffset(if p then 26 else 40, if p then 26 else 40)
		bolt.Position = UDim2.new(0, if p then 3 else 6, 0.5, 0)
		local left = if p then 32 else 52
		local width = UDim.new(1, -left - (if p then 6 else 10))
		local titleSize = if mode == "Buy" then (if p then 10 else 14) else (if p then 11 else 16)
		HudKit.Fit(title, titleSize)
		if mode == "Saving" then
			local barHeight = if p then 14 else 20
			local total = titleSize + (if p then 3 else 5) + barHeight
			local top = math.floor(((if p then 46 else 66) - 6 - (if p then 5 else 6) - total) / 2 + 1)
			title.Position = UDim2.fromOffset(left, top)
			title.Size = UDim2.new(width, UDim.new(0, titleSize))
			track.Position = UDim2.new(UDim.new(0, left), UDim.new(0, top + titleSize + (if p then 3 else 5)))
			track.Size = UDim2.new(width, UDim.new(0, barHeight - 4))
			trackCorner.CornerRadius = UDim.new(0, (barHeight - 4) / 2)
			fillCorner.CornerRadius = UDim.new(0, (barHeight - 4) / 2)
			priceCoin.Visible = not p
			priceText.TextSize = if p then 10 else 13
		elseif mode == "Buy" then
			local buyHeight = if p then 16 else 22
			local total = titleSize + 3 + buyHeight
			local top = math.floor(((if p then 46 else 66) - 6 - (if p then 5 else 6) - total) / 2 + 1)
			title.Position = UDim2.fromOffset(left, top)
			title.Size = UDim2.new(width, UDim.new(0, titleSize))
			buyRow.Position = UDim2.fromOffset(left, top + titleSize + 3)
			buyRow.Size = UDim2.new(width, UDim.new(0, buyHeight))
			buyWord.TextSize = if p then 16 else 22
			buyPrice.TextSize = if p then 11 else 15
		else
			maxText.Size = UDim2.new(width, UDim.new(1, if p then -6 else -8))
			maxText.Position = UDim2.fromOffset(left, if p then 3 else 4)
			HudKit.Fit(maxText, if p then 15 else 22)
		end
		-- pill: computer 18 px tall (DAILY is 16 px under the button), phone 14 px
		payPill.Size = UDim2.fromOffset(0, if p then 14 else 18)
		payPill.Position = UDim2.new(0.5, 0, 1, if p then -3 else -4)
		payText.TextSize = if p then 10 else 12
		payRing.Color = if mode == "Max" then K.White else K.Gold
		title.Visible = mode ~= "Max"
		track.Visible = mode == "Saving"
		buyRow.Visible = mode == "Buy"
		maxText.Visible = mode == "Max"
	end

	-- BUY!: the glow breathes (0.6 s) and the button grows a little (1.2 s), until it's bought
	local glowTween = TweenService:Create(
		block.GlowRing,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.7 }
	)
	local breatheTween = TweenService:Create(
		block.Scale,
		TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.05 }
	)
	local function setMode(newMode: string)
		if newMode == mode then
			return
		end
		local was = mode
		mode = newMode
		block:Paint(if newMode == "Buy" then "Lime" elseif newMode == "Max" then "Gold" else "Card")
		block:SetGlow(if newMode == "Buy" then K.Lime else nil)
		block.Shine.BackgroundTransparency = if newMode == "Saving" then 0.75 else 0
		if newMode == "Buy" then
			block.GlowRing.Transparency = 0.2
			glowTween:Play()
			breatheTween:Play()
		else
			glowTween:Cancel()
			breatheTween:Cancel()
			block.Scale.Scale = 1
		end
		if newMode == "Max" and was ~= "" then
			-- MAX: one big settle
			block.Scale.Scale = 1.2
			TweenService:Create(block.Scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
		-- MAX POWER! has nothing left to buy, so it tucks away with the rest of the HUD while you bowl
		if newMode == "Max" then
			HudKit.Tuckable(button, "PowerMax")
		else
			HudKit.Untuckable(button)
		end
		arrange()
	end

	local function refresh()
		local level = math.clamp(player:GetAttribute("PowerLevel") or 1, 1, PowerLevels.Max)
		local nextRow = PowerLevels.Next(level)
		title.Text = ("POWER LV %d"):format(level)
		payText.Text = PowerLevels.PayoffText(level)
		if not nextRow then
			setMode("Max")
			return
		end
		local coins = player:GetAttribute("Coins") or 0
		local affordable = coins >= nextRow.Price
		priceText.Text = short(nextRow.Price)
		buyPrice.Text = short(nextRow.Price)
		setMode(if affordable then "Buy" else "Saving")
		TweenService:Create(fill, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(math.clamp(coins / math.max(nextRow.Price, 1), 0, 1), 1),
		}):Play()
	end

	local buying = false
	button.Activated:Connect(function()
		if buying or mode == "Max" then
			return
		end
		buying = true
		local ok, result = pcall(buyRemote.InvokeServer, buyRemote)
		buying = false
		if ok and result and result.Ok then
			-- Buy: a quick wiggle (-6, 6, 0 degrees in 0.25 s)
			task.spawn(function()
				for _, angle in { -6, 6, 0 } do
					TweenService:Create(button, TweenInfo.new(0.08), { Rotation = angle }):Play()
					task.wait(0.08)
				end
			end)
			celebrate(result.Level)
		else
			UiFx.Pop(button, 0.85)
		end
	end)

	-- Studio only: a test button that gives the coins for the next level (the server ignores it in the live game)
	local testRemote = remotes:FindFirstChild("TestCoins") :: RemoteEvent?
	if testRemote then
		local test = Instance.new("TextButton")
		test.Name = "TestCoins"
		test.Text = "TEST: +COINS"
		test.FontFace = FONT
		test.TextScaled = true
		test.TextColor3 = Color3.new(1, 1, 1)
		test.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		test.AnchorPoint = Vector2.new(0, 0)
		-- Right of the button (DAILY sits right under it)
		test.Position = UDim2.new(1, 8, 0, 0)
		test.Size = UDim2.fromOffset(120, 20)
		test.ZIndex = 10
		test.Parent = button
		local testCorner = Instance.new("UICorner")
		testCorner.Parent = test
		test.Activated:Connect(function()
			testRemote:FireServer()
		end)
	end
	-- Studio only: prints the session report (PERFECT rate + first-5-minutes timeline) in the Output window
	local reportRemote = remotes:FindFirstChild("TestReport") :: RemoteEvent?
	if reportRemote then
		local report = Instance.new("TextButton")
		report.Name = "TestReport"
		report.Text = "TEST: REPORT"
		report.FontFace = FONT
		report.TextScaled = true
		report.TextColor3 = Color3.new(1, 1, 1)
		report.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		report.Position = UDim2.new(1, 8, 0, 24)
		report.Size = UDim2.fromOffset(120, 20)
		report.ZIndex = 10
		report.Parent = button
		local reportCorner = Instance.new("UICorner")
		reportCorner.Parent = report
		report.Activated:Connect(function()
			reportRemote:FireServer()
		end)
	end

	-- Computer 176x66, phone 118x46 (HUD Kit)
	HudKit.OnLayout(function(isPhone)
		phone = isPhone
		block:SetRadius(if isPhone then 12 else 16)
		block:SetLip(if isPhone then 5 else 6)
		arrange()
	end)
	HudKit.Place(button, "Power")

	player:GetAttributeChangedSignal("Coins"):Connect(refresh)
	player:GetAttributeChangedSignal("PowerLevel"):Connect(refresh)
	refresh()
	-- (Addendum 4 Stage 2: Power Levels pay nothing in the core loop, the ball ladder is the upgrade; kept, hidden)
	gui.Enabled = not Config.CoreLoop.Enabled
	gui.Parent = playerGui
end

return PowerLevelController
