-- The daily reward calendar popup. Opens by itself on join when a reward is waiting,
-- and from the DAILY button any time. The server decides the day and gives the reward.
-- The UI itself (StarterGui.DailyUI) is built in Studio; this script fills it in and animates it.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Calendar = require(Shared.Modules.Calendar)
local Balls = require(Shared.Modules.Balls)
local Zones = require(Shared.Modules.Zones)
local PowerLevels = require(Shared.Modules.PowerLevels)
local CrateController = require(script.Parent.CrateController)
local OnboardingController = require(script.Parent.OnboardingController)
local PlaytimeController = require(script.Parent.PlaytimeController)
local PotionController = require(script.Parent.PotionController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local HudKit = require(Modules.HudKit)

local player = Players.LocalPlayer

local READY_COLOR = Color3.fromRGB(90, 230, 110)
local WAIT_COLOR = Color3.fromRGB(110, 100, 130)
local TODAY_STROKE = Color3.fromRGB(255, 200, 40)
local CLAIMED_STROKE = Color3.fromRGB(90, 230, 110)
local LOCKED_STROKE = Color3.fromRGB(80, 70, 110)

local DailyRewardController = {}

-- Every number on screen uses the shared formatter (Config.Numbers)
local formatNumber = Currency.Format

-- 15,000 / 4.1B / 500K: big numbers get a letter so they fit the tile
local shortNumber = Currency.Format

local function potionById(id: string)
	for _, potion in Config.Potions.List do
		if potion.Id == id then
			return potion
		end
	end
	return nil
end

-- "15,000 COINS" / "3x COIN POTION" / "GOLD CRATE\n+2x MEGA COIN POTION\n+25 GEMS"
local function rewardText(reward): string
	local parts = {}
	-- A crate from a zone you haven't unlocked yet comes as your zone's crate (same rule as the server)
	local crate = Balls.GetCrate(Zones.RewardCrateId(reward.Crate, player:GetAttribute("RankLevel")))
	if crate then
		table.insert(parts, crate.Name:upper())
	end
	if reward.Egg then
		local look = Config.EggLooks[reward.Egg]
		table.insert(parts, "FREE " .. string.upper(if look then look.Name else "EGG"))
	end
	for _, item in reward.Potions or {} do
		local potion = potionById(item.Id)
		local name = if potion then potion.Name else item.Id
		table.insert(parts, if item.Count > 1 then ("%dx %s"):format(item.Count, name) else name)
	end
	if reward.Coins then
		-- Grows with your Power Level (same rule as the server)
		local coins = PowerLevels.DailyCoins(reward, player:GetAttribute("PowerLevel"))
		table.insert(parts, shortNumber(coins) .. " COINS")
	end
	if reward.Gems then
		table.insert(parts, formatNumber(reward.Gems) .. " GEMS")
	end
	return table.concat(parts, "\n+")
end

function DailyRewardController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("DailyUI")
	local openButton = gui:WaitForChild("DailyButton") :: TextButton
	-- Owner's HUD Kit look: red gift (READY, red dot), grey lock + throws left (LOCKED), dark with a tick (DONE).
	-- Under the POWER LV button on computers, top-right left of GIFTS on phones.
	local dailyKit = HudKit.Adopt(openButton, {
		Paint = "Red",
		Icon = "GiftDaily",
		Caption = "DAILY",
		Key = "Daily",
		Drop = { "Caption", "Icon", "Dot" },
	})
	if Config.Ui.HidePlayerList then
		pcall(function()
			game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
	end
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
	local dailyLook = ""
	local function setLook(newLook: string, throwsLeft: number?)
		if newLook ~= dailyLook then
			dailyLook = newLook
			if newLook == "Locked" then
				dailyKit:Paint("Grey")
				dailyKit:SetIcon("Lock", 30)
			elseif newLook == "Done" then
				dailyKit:Paint("Card")
				dailyKit:SetIcon("Check", 30)
				dailyKit:SetCaption("DONE", HudKit.C.Lime)
			else
				dailyKit:Paint("Red")
				dailyKit:SetIcon("GiftDaily")
				dailyKit:SetCaption("DAILY")
			end
			dailyKit:SetDot(newLook == "Ready")
		end
		if newLook == "Locked" then
			local left = throwsLeft or 0
			dailyKit:SetCaption(
				if left > 1 then left .. " THROWS" elseif left == 1 then "1 THROW" else "SOON",
				nil,
				nil,
				9
			)
		end
	end
	local function updateLook()
		if locked then
			local unlockAt = onboard.GiftAfterThrows + onboard.LegendsAfterThrows
			setLook("Locked", math.max(unlockAt - (player:GetAttribute("OnboardThrows") or 0), 0))
		else
			setLook(if player:GetAttribute("DailyClaimable") == true then "Ready" else "Done")
		end
	end
	local function updateLock()
		updateLook()
	end
	-- READY: the gift wiggles (-8/8 degrees, 4 times), rests 2 s, again
	task.spawn(function()
		while true do
			task.wait(2)
			if dailyLook == "Ready" and openButton.Visible then
				for _, angle in { -8, 8, -8, 0 } do
					dailyKit.Slot.Rotation = angle
					task.wait(0.1)
				end
			end
		end
	end)
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
		-- One big icon per tile: crate, else egg, else potion, else coins, else gems
		local firstPotion = reward.Potions and reward.Potions[1] and potionById(reward.Potions[1].Id)
		local showEgg = reward.Egg ~= nil and reward.Crate == nil
		local showPotion = firstPotion ~= nil and reward.Crate == nil and not showEgg
		local plain = reward.Crate == nil and not showEgg and not showPotion
		tile.Icons.Coin.Visible = reward.Coins ~= nil and plain
		tile.Icons.Gem.Visible = reward.Gems ~= nil and reward.Coins == nil and plain
		tile.Icons.Crate.Visible = reward.Crate ~= nil
		if showEgg then
			local look = Config.EggLooks[reward.Egg]
			if look then
				local egg = PlaytimeController.EggIcon(tile.Icons, look, UDim2.fromScale(0.5, 0.5), 10)
				egg.Size = UDim2.fromScale(0.62, 0.9)
				egg.SizeConstraint = Enum.SizeConstraint.RelativeYY
			end
		elseif showPotion and firstPotion then
			local flask =
				PotionController.Flask(tile.Icons, firstPotion.Color, firstPotion.Big, UDim2.fromScale(0.5, 0.5), 10)
			flask.Size = UDim2.fromScale(1, 1)
			flask.SizeConstraint = Enum.SizeConstraint.RelativeYY
		end
		local function paint()
			tile.Amount.Text = rewardText(reward)
			local crate = Balls.GetCrate(Zones.RewardCrateId(reward.Crate, player:GetAttribute("RankLevel")))
			if crate then
				tile.Icons.Crate.BackgroundColor3 = crate.Color
			end
		end
		paint()
		player:GetAttributeChangedSignal("RankLevel"):Connect(paint)
		player:GetAttributeChangedSignal("PowerLevel"):Connect(paint)
		tile.Parent = days
		tiles[day] = tile
	end
	tileTemplate.Visible = false

	local function refresh()
		local nextDay = player:GetAttribute("DailyNext") or 1
		local claimable = player:GetAttribute("DailyClaimable") == true
		updateLook()

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
			if result.Egg then
				claimLabel.Text = "HATCH IT AT THE EGG STAND!"
				task.wait(1.4)
			end
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
