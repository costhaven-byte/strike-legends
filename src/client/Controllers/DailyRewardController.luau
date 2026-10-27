-- The daily reward calendar popup. Opens by itself on join when a reward is waiting,
-- and from the DAILY button any time. The server decides the day and gives the reward.
-- The DAILY button is in StarterGui.DailyUI (Studio); the calendar window is built here in the owner's kit style
-- (RewardKit, UI pass batch 1, 2026-10-28).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local HudKit = require(Modules.HudKit)
local UiKit = require(Modules.UiKit)
local CrateKit = require(Modules.CrateKit)
local RewardKit = require(Modules.RewardKit)

local C = UiKit.C

local player = Players.LocalPlayer

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
	local crate = Balls.GetCrate(Zones.RewardCrateId(reward.Crate, player:GetAttribute("ZonesOpen")))
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
	-- The old Studio-built calendar (StarterGui.DailyUI.Popup) stays in the place as a template but is never shown:
	-- the calendar is built in code in the owner's kit style (RewardKit, UI pass batch 1)
	local oldPopup = gui:WaitForChild("Popup") :: Frame
	oldPopup.Visible = false

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

	-- ===== The calendar window (760x500, owner's kit style): DAY 1-6 in two rows of 3, DAY 7 a big gold tile on the
	-- right, the CLAIM button under them and the grace-day line =====
	local calGui = Instance.new("ScreenGui")
	calGui.Name = "DailyCalendarUI"
	calGui.ResetOnSpawn = false
	calGui.DisplayOrder = gui.DisplayOrder + 5
	calGui.IgnoreGuiInset = gui.IgnoreGuiInset
	calGui.Parent = player.PlayerGui
	local W, H = 760, 500
	local win = RewardKit.Window(calGui, W, H)
	local popup = win.Screen
	local cover, closeButton =
		RewardKit.Cover(win.Panel, W, H, "DAILY REWARD", "COME BACK EVERY DAY FOR BIGGER REWARDS", C.Gold)

	-- Where each day's tile goes (design px on the cover)
	local function spot(day: number): (number, number, number, number)
		if day == #Config.Daily.Rewards then
			return 508, 104, 228, 280
		end
		local col, row = (day - 1) % 3, (day - 1) // 3
		return 24 + col * 160, 104 + row * 146, 148, 134
	end

	-- One big icon per tile: crate, else egg, else potion, else coins, else gems
	local function mainIcon(reward): (string, any)
		if reward.Crate then
			-- a crate from a zone you haven't unlocked yet comes as your zone's crate (same rule as the server)
			return "Crate", Zones.RewardCrateId(reward.Crate, player:GetAttribute("ZonesOpen"))
		elseif reward.Egg then
			return "Egg", reward.Egg
		elseif reward.Potions and reward.Potions[1] then
			return "Potion", reward.Potions[1].Id
		elseif reward.Coins then
			return "Coins", nil
		end
		return "Gems", nil
	end

	-- One tile per day, straight from Config.Daily. States: CLAIMED (dark cover + tick), TODAY (gold edge, rays,
	-- TODAY tag, breathing), LATER (darker card). The last day is the big gold tile with sparkles.
	local tiles = {}
	for day, reward in Config.Daily.Rewards do
		local x, y, w, h = spot(day)
		local big = day == #Config.Daily.Rewards
		local block = UiKit.Block(cover, {
			Name = "Day" .. day,
			Size = Vector2.new(w, h),
			Fill = if big then C.Gold else C.Card,
			Lip = if big then C.GoldLip else C.Page,
			LipPx = 6,
			Radius = 16,
			Outline = 3,
		})
		block.Holder.Position = UDim2.fromOffset(x, y)
		local face = block.Face
		local faceW, faceH = w - 6, h - 12
		local edge = UiKit.Outline(face, C.Gold, 3)
		edge.Enabled = false
		RewardKit.Label(
			face,
			"DAY " .. day,
			UiKit.Head,
			if big then 32 else 20,
			C.White,
			2.5,
			4,
			6,
			faceW - 8,
			if big then 38 else 24
		)
		local iconSize = if big then 116 else 56
		local iconY = if big then 0.42 else 0.46
		local rays = RewardKit.Rays(face, if big then UiKit.Hex("FF8A1F") else C.Gold, if big then 220 else 108, 9)
		rays.Position = UDim2.fromScale(0.5, iconY)
		local kind, value = mainIcon(reward)
		local icon = RewardKit.Icon(face, kind, value, iconSize, UDim2.fromScale(0.5, iconY))
		local amountH = if big then 72 else 34
		local amount = UiKit.Text(face, "", UiKit.Num, if big then 19 else 14, C.White, 2)
		amount.Name = "Amount"
		amount.Position = UDim2.fromOffset(4, faceH - amountH - 4)
		amount.Size = UDim2.fromOffset(faceW - 8, amountH)
		amount.TextWrapped = true
		amount.TextYAlignment = Enum.TextYAlignment.Bottom
		amount.ZIndex = 5
		RewardKit.Fit(amount, if big then 19 else 14, faceW - 12, amountH)
		if big then
			RewardKit.Twinkle(face, 4, C.White)
			-- a pink BIG ONE! tag on the corner
			local tag = UiKit.Block(cover, {
				Name = "BigTag",
				Size = Vector2.new(96, 30),
				Fill = C.Pink,
				Lip = C.PinkLip,
				LipPx = 4,
				Radius = 10,
				Outline = 3,
			})
			tag.Holder.Position = UDim2.fromOffset(x + w - 82, y - 10)
			tag.Holder.Rotation = 10
			tag.Holder.ZIndex = 6
			RewardKit.Label(tag.Face, "BIG ONE!", UiKit.Head, 15, C.White, 2, 4, 2, 82, 20)
		end
		local overlay = UiKit.Make("Frame", {
			Name = "Claimed",
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 8,
		}, face)
		UiKit.Corner(overlay, 13)
		local check = CrateKit.Icon(face, "Check", if big then 96 else 56)
		check.AnchorPoint = Vector2.new(0.5, 0.5)
		check.Position = UDim2.fromScale(0.5, iconY)
		check.Visible = false
		check.ZIndex = 9
		local chip = UiKit.Block(cover, {
			Name = "Today",
			Size = Vector2.new(86, 24),
			Fill = C.Gold,
			Lip = C.GoldLip,
			LipPx = 4,
			Radius = 10,
			Outline = 3,
		})
		chip.Holder.Position = UDim2.fromOffset(x + (w - 86) / 2, y - 16)
		chip.Holder.ZIndex = 6
		chip.Holder.Visible = false
		RewardKit.Label(chip.Face, "TODAY", UiKit.Head, 16, C.White, 2, 4, 2, 72, 16)

		local function paint()
			amount.Text = rewardText(reward)
			local newKind, newValue = mainIcon(reward)
			if newKind == "Crate" and newValue ~= value then
				value = newValue
				RewardKit.Fill(icon, newKind, newValue)
			end
		end
		paint()
		player:GetAttributeChangedSignal("ZonesOpen"):Connect(paint)
		player:GetAttributeChangedSignal("PowerLevel"):Connect(paint)
		tiles[day] = {
			Block = block,
			Edge = edge,
			Rays = rays,
			Icon = icon,
			Amount = amount,
			Overlay = overlay,
			Check = check,
			Chip = chip.Holder,
			Big = big,
			StopPulse = nil :: (() -> ())?,
		}
	end

	local claimButton = RewardKit.Button(cover, "CLAIM DAY 1!", "Lime", 400, 62, 30)
	claimButton.Holder.Position = UDim2.fromOffset((W - 400) / 2, 392)
	local graceDays = Config.Daily.GraceDays or 0
	local grace = RewardKit.Label(
		cover,
		("MISS A DAY? YOU GET %d GRACE DAY%s"):format(graceDays, if graceDays == 1 then "" else "S"),
		UiKit.Body,
		13,
		C.Muted,
		0,
		24,
		462,
		W - 48,
		18
	)
	grace.Visible = graceDays > 0

	-- The CLAIM button: lime and breathing when today's reward waits, grey countdown otherwise, red on an error
	local claimPaint = ""
	local stopClaimPulse: (() -> ())? = nil
	local function paintClaim(paint: string)
		if paint == claimPaint then
			return
		end
		claimPaint = paint
		local colours = RewardKit.Paint[paint]
		claimButton:Paint(colours[1], colours[2])
		claimButton:SetPressable(paint == "Lime")
		if stopClaimPulse then
			stopClaimPulse()
			stopClaimPulse = nil
		end
		if paint == "Lime" then
			stopClaimPulse = RewardKit.Pulse(claimButton.Holder, 1.04, 0.6)
		end
	end

	local function refresh()
		local nextDay = player:GetAttribute("DailyNext") or 1
		local claimable = player:GetAttribute("DailyClaimable") == true
		updateLook()

		for day, t in tiles do
			local claimed = day < nextDay or (day == nextDay and not claimable)
			local today = day == nextDay and claimable
			t.Overlay.Visible = claimed
			t.Check.Visible = claimed
			t.Chip.Visible = today
			t.Rays.Visible = (today or t.Big) and not claimed
			t.Edge.Enabled = today and not t.Big
			if not t.Big then
				t.Block:Paint(if claimed or today then C.Card else C.Page, C.Page)
				t.Amount.TextColor3 = if today or claimed then C.White else C.Label
			end
			if today and not t.StopPulse then
				t.StopPulse = RewardKit.Pulse(t.Block.Holder, 1.05, 0.55)
			elseif not today and t.StopPulse then
				t.StopPulse()
				t.StopPulse = nil
			end
		end

		if errorText then
			paintClaim("Red")
			claimButton:SetText(errorText:upper())
		elseif claimable then
			paintClaim("Lime")
			claimButton:SetText("CLAIM DAY " .. nextDay .. "!")
		else
			paintClaim("Grey")
			local wait = Calendar.SecondsUntilNextDay(Workspace:GetServerTimeNow())
			claimButton:SetText("COME BACK IN " .. Calendar.FormatCountdown(wait):upper())
		end
	end

	local function setOpen(open: boolean)
		if open then
			refresh()
			win:Open()
			-- the day icons pop in one after another
			local icons = {}
			for day = 1, #tiles do
				table.insert(icons, tiles[day].Icon)
			end
			RewardKit.Stagger(icons, 0.04, 0.15)
		else
			win:Close()
		end
	end

	-- Today's tile jumps, the tick stamps down and confetti bursts out of it
	local function celebrate(day: number)
		local t = tiles[day]
		if not t then
			return
		end
		local scale = UiKit.ScaleOf(t.Block.Holder)
		scale.Scale = 1.3
		UiKit.Tween(scale, 0.5, Enum.EasingStyle.Back, { Scale = 1 })
		t.Overlay.Visible = true
		t.Check.Visible = true
		RewardKit.Stamp(t.Check)
		local x, y, w, h = spot(day)
		CrateKit.Confetti(cover, x + w / 2 - W / 2, y + h / 2 - H / 2, 30, 220, 0.7)
		UiFx.Flash(C.Gold, 0.25, 0.35)
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
			claimButton:Shake()
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
		local crate = Balls.GetCrate(result.CrateId)
		if crate and result.Crate and CrateController.PlayOpening then
			task.wait(0.9)
			win:Close()
			CrateController.PlayOpening(crate, result.Crate)
		else
			if result.Egg then
				paintClaim("Pink")
				claimButton:SetText("HATCH IT AT THE EGG STAND!")
				task.wait(1.4)
			end
			task.wait(1.2)
			win:Close()
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
			win:Close()
		end
	end
	for _, screen in covers do
		screen:GetPropertyChangedSignal("Visible"):Connect(updateButton)
	end
	updateButton()

	player:GetAttributeChangedSignal("DailyNext"):Connect(refresh)
	player:GetAttributeChangedSignal("DailyClaimable"):Connect(refresh)
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
