-- The daily reward calendar popup. Opens by itself on join when a reward is waiting,
-- and from the DAILY button any time. The server decides the day and gives the reward.
-- The UI itself (StarterGui.DailyUI) is built in Studio; this script fills it in and animates it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Calendar = require(Shared.Modules.Calendar)
local Balls = require(Shared.Modules.Balls)
local Zones = require(Shared.Modules.Zones)
local CrateController = require(script.Parent.CrateController)
local OnboardingController = require(script.Parent.OnboardingController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)

local player = Players.LocalPlayer

local READY_COLOR = Color3.fromRGB(90, 230, 110)
local WAIT_COLOR = Color3.fromRGB(110, 100, 130)
local TODAY_STROKE = Color3.fromRGB(255, 200, 40)
local CLAIMED_STROKE = Color3.fromRGB(90, 230, 110)
local LOCKED_STROKE = Color3.fromRGB(80, 70, 110)

local DailyRewardController = {}

local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end

-- "1,000 coins" / "5 gems" / "Gold Crate + 15 gems"
local function rewardText(reward): string
	local parts = {}
	-- A crate from a zone you haven't unlocked yet comes as your zone's crate (same rule as the server)
	local crate = Balls.GetCrate(Zones.RewardCrateId(reward.Crate, player:GetAttribute("RankLevel")))
	if crate then
		table.insert(parts, crate.Name:upper())
	end
	if reward.Coins then
		table.insert(parts, formatNumber(reward.Coins))
	end
	if reward.Gems then
		table.insert(parts, formatNumber(reward.Gems) .. (if crate then " GEMS" else ""))
	end
	return table.concat(parts, "\n+")
end

function DailyRewardController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("DailyUI")
	local openButton = gui:WaitForChild("DailyButton") :: TextButton
	-- Top-right corner (owner 2026-10-22); ScreenLayout moves it on phones
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(1, -16, 0, 10)
	if Config.Ui.HidePlayerList then
		pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
	end
	local dot = openButton:WaitForChild("Dot") :: Frame
	local popup = gui:WaitForChild("Popup") :: Frame
	local days = popup:WaitForChild("Days") :: Frame
	local tileTemplate = popup:WaitForChild("TileTemplate") :: Frame
	local claimButton = popup:WaitForChild("Claim") :: TextButton
	local claimLabel = claimButton:WaitForChild("Label") :: TextLabel
	local closeButton = popup:WaitForChild("Close") :: TextButton

	local claimDaily = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimDaily") :: RemoteFunction

	local busy = false
	local errorText: string? = nil

	-- Brand new players can't open the calendar during their first 3 minutes (Config.Onboarding):
	-- the button stays grey with a throw countdown until the daily popup opens by itself
	local onboard = Config.Onboarding
	local function onboarding(): boolean
		return onboard.Enabled and (player:GetAttribute("Onboarding") or 3) < 3
	end
	local locked = onboarding()
	local shaking = false
	local caption = openButton:WaitForChild("Caption") :: TextLabel
	local icon = openButton:WaitForChild("Icon") :: Frame
	local litColors = {}
	for _, part in { openButton, icon, icon:WaitForChild("Ribbon"), icon:WaitForChild("Band") } do
		litColors[part] = (part :: GuiObject).BackgroundColor3
	end
	local outline = openButton:FindFirstChildOfClass("UIStroke")
	local litOutline = outline and outline.Color
	local shade = Instance.new("Frame")
	shade.Name = "Lock"
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.ZIndex = 5
	local shadeCorner = openButton:FindFirstChildOfClass("UICorner")
	if shadeCorner then
		shadeCorner:Clone().Parent = shade
	end
	local lockIcon = Instance.new("TextLabel")
	lockIcon.Name = "Icon"
	lockIcon.BackgroundTransparency = 1
	lockIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	lockIcon.Position = UDim2.fromScale(0.5, 0.4)
	lockIcon.Size = UDim2.fromScale(0.5, 0.5)
	lockIcon.Text = "🔒"
	lockIcon.TextScaled = true
	lockIcon.ZIndex = 6
	lockIcon.Parent = shade
	shade.Parent = openButton

	local function updateLock()
		shade.Visible = locked
		caption.ZIndex = 7 -- the countdown sits above the shade
		for part, color in litColors do
			local h, s, v = color:ToHSV()
			part.BackgroundColor3 = if locked then Color3.fromHSV(h, s * 0.1, v * 0.6) else color
		end
		if outline and litOutline then
			outline.Color = if locked then Color3.fromRGB(90, 85, 100) else litOutline
		end
		if locked then
			local unlockAt = onboard.GiftAfterThrows + onboard.LegendsAfterThrows
			local left = math.max(unlockAt - (player:GetAttribute("OnboardThrows") or 0), 0)
			caption.Text = if left > 1 then left .. " THROWS" elseif left == 1 then "1 THROW" else "SOON"
		else
			caption.Text = "DAILY"
		end
	end
	updateLock()
	player:GetAttributeChangedSignal("OnboardThrows"):Connect(updateLock)

	-- One tile per day, straight from Config.Daily
	local tiles = {}
	for day, reward in Config.Daily.Rewards do
		local tile = tileTemplate:Clone()
		tile.Name = "Day" .. day
		tile.LayoutOrder = day
		tile.Visible = true
		tile.DayLabel.Text = "DAY " .. day
		tile.Icons.Coin.Visible = reward.Coins ~= nil and reward.Crate == nil
		tile.Icons.Gem.Visible = reward.Gems ~= nil and reward.Crate == nil
		tile.Icons.Crate.Visible = reward.Crate ~= nil
		local function paint()
			tile.Amount.Text = rewardText(reward)
			local crate = Balls.GetCrate(Zones.RewardCrateId(reward.Crate, player:GetAttribute("RankLevel")))
			if crate then
				tile.Icons.Crate.BackgroundColor3 = crate.Color
			end
		end
		paint()
		player:GetAttributeChangedSignal("RankLevel"):Connect(paint)
		tile.Parent = days
		tiles[day] = tile
	end
	tileTemplate.Visible = false

	local function refresh()
		local nextDay = player:GetAttribute("DailyNext") or 1
		local claimable = player:GetAttribute("DailyClaimable") == true
		dot.Visible = claimable and not locked

		for day, tile in tiles do
			local claimed = day < nextDay or (day == nextDay and not claimable)
			local isToday = day == nextDay
			tile.Check.Visible = claimed
			tile.UIStroke.Color = if isToday and claimable
				then TODAY_STROKE
				elseif claimed then CLAIMED_STROKE
				else LOCKED_STROKE
			tile.UIStroke.Thickness = if isToday then 4 else 2
			tile.BackgroundTransparency = if claimed then 0.4 else 0
		end

		if errorText then
			claimLabel.Text = errorText:upper()
			claimButton.BackgroundColor3 = WAIT_COLOR
		elseif claimable then
			claimLabel.Text = "CLAIM DAY " .. nextDay .. "!"
			claimButton.BackgroundColor3 = READY_COLOR
		else
			local wait = Calendar.SecondsUntilNextDay(Workspace:GetServerTimeNow())
			claimLabel.Text = "NEXT REWARD IN " .. Calendar.FormatCountdown(wait):upper()
			claimButton.BackgroundColor3 = WAIT_COLOR
		end
	end

	local function setOpen(open: boolean)
		if open then
			refresh()
			UiFx.Open(popup)
		else
			UiFx.Close(popup)
		end
	end

	-- Today's tile does a little hop when you claim it
	local function celebrate(day: number)
		local tile = tiles[day]
		if not tile then
			return
		end
		local scale = tile:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale = 1.3
			TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = 1,
			}):Play()
		end
	end

	local function claim()
		if busy or player:GetAttribute("DailyClaimable") ~= true then
			return
		end
		busy = true
		local ok, result = pcall(claimDaily.InvokeServer, claimDaily)
		if not ok or not result or not result.Ok then
			errorText = if ok and result and result.Error then result.Error else "Try again"
			refresh()
			task.delay(1.5, function()
				errorText = nil
				refresh()
			end)
			busy = false
			return
		end

		refresh()
		celebrate(result.Day)
		Sfx.Play("Reveal")
		UiFx.Confetti(nil, 30)
		local crate = Balls.GetCrate(result.CrateId)
		if crate and result.Crate and CrateController.PlayOpening then
			task.wait(0.8)
			UiFx.Close(popup)
			CrateController.PlayOpening(crate, result.Crate)
		else
			task.wait(1.2)
			UiFx.Close(popup)
		end
		busy = false
	end

	openButton.Activated:Connect(function()
		if locked then
			-- A little "no" shake; the countdown on the button says when it opens
			if shaking then
				return
			end
			shaking = true
			local start = openButton.Position
			for _, dx in { -6, 6, -4, 4, 0 } do
				openButton.Position = start + UDim2.fromOffset(dx, 0)
				if dx == -6 then
					Sfx.Play("Error")
				end
				task.wait(0.04)
			end
			openButton.Position = start
			shaking = false
			return
		end
		setOpen(not popup.Visible)
	end)
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	claimButton.Activated:Connect(claim)
	popup.Active = true -- taps on the popup don't fall through to the throw meter

	-- Hide the DAILY button while the book, crates or crate-opening screens are up
	-- (on phones those fill the screen and the button would sit on top of them)
	local ballsUi = player.PlayerGui:WaitForChild("BallsUI")
	local covers = {
		ballsUi:WaitForChild("Inventory"),
		ballsUi:WaitForChild("Book"),
		ballsUi:WaitForChild("Shop"),
		ballsUi:WaitForChild("Opening"),
	}
	local function updateButton()
		local covered = false
		for _, screen in covers do
			covered = covered or screen.Visible
		end
		openButton.Visible = not covered
		if covered and popup.Visible and not busy then
			UiFx.Close(popup)
		end
	end
	for _, screen in covers do
		screen:GetPropertyChangedSignal("Visible"):Connect(updateButton)
	end
	updateButton()

	player:GetAttributeChangedSignal("DailyNext"):Connect(refresh)
	player:GetAttributeChangedSignal("DailyClaimable"):Connect(refresh)
	popup.Visible = false
	refresh()

	-- Keep the countdown ticking while the popup is open
	task.spawn(function()
		while true do
			task.wait(1)
			if popup.Visible and not busy then
				refresh()
			end
		end
	end)

	-- Login popup: open once on join if a reward is waiting
	local waited = 0
	while player:GetAttribute("DailyClaimable") == nil and waited < 30 do
		waited += task.wait(0.5)
	end
	-- Brand new players see no menus in their first 3 minutes (Config.Onboarding): it waits until that path is done
	if onboarding() then
		locked = true
		updateLock()
		while onboarding() do
			player:GetAttributeChangedSignal("Onboarding"):Wait()
		end
		-- After the showcase camera moment: it waits for the lane to clear first, so its start time varies
		local waitedForShow = 0
		while not OnboardingController.LegendsDone and waitedForShow < 90 do
			waitedForShow += task.wait(0.25)
		end
		task.wait(1.5)
	end
	locked = false
	updateLock()
	refresh()
	if player:GetAttribute("DailyClaimable") == true then
		task.wait(1.5) -- let the game load in first
		-- Never on top of a crate opening (it waits for that to close)
		local opening = ballsUi:FindFirstChild("Opening") :: GuiObject?
		local waitedForCrate = 0
		while opening and opening.Visible and waitedForCrate < 120 do
			waitedForCrate += task.wait(0.25)
		end
		setOpen(true)
	end
end

return DailyRewardController
