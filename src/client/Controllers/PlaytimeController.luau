-- Playtime gifts on screen (owner 2026-10-22, Config.Playtime): the GIFTS button (top-right corner) with the time
-- to the next gift, and the gifts panel (12 gifts: one on joining, then one every 15 minutes, one set a day) with a
-- CLAIM button on each ready gift. What each gift gives follows your progress (Shared.Modules.PlaytimeRewards).
-- The panel is in the owner's kit style (RewardKit, UI pass batch 1, 2026-10-28).
-- Built in code (not in Studio), so it lives in git. The server runs the clock and hands out gifts (PlaytimeService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Mascots = require(Shared.Modules.Mascots)
local Zones = require(Shared.Modules.Zones)
local Currency = require(Shared.Modules.Currency)
local PlaytimeRewards = require(Shared.Modules.PlaytimeRewards)
local CrateController = require(script.Parent.CrateController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))
local HudKit = require(Modules:WaitForChild("HudKit"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local CrateKit = require(Modules:WaitForChild("CrateKit"))
local RewardKit = require(Modules:WaitForChild("RewardKit"))

local C = UiKit.C

local player = Players.LocalPlayer

local PLAYTIME = Config.Playtime

local PINK = Color3.fromRGB(255, 70, 170)
local GOLD = Color3.fromRGB(255, 200, 40)

local PlaytimeController = {}

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return ("%d:%02d:%02d"):format(seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

local function potionById(id: string)
	for _, potion in Config.Potions.List do
		if potion.Id == id then
			return potion
		end
	end
	return nil
end

-- What gift number index gives this player right now (it grows with zone, Power Level and income)
local function resolve(index: number)
	return PlaytimeRewards.Resolve(index, {
		PowerLevel = player:GetAttribute("PowerLevel"),
		ZonesOpen = player:GetAttribute("ZonesOpen"),
		AwayRate = player:GetAttribute("AwayRate"),
	}) or {}
end

-- Name and colour of a gift, as the player sees it now
local function describe(gift): (string, Color3)
	if gift.Coins then
		return ("%s COINS"):format(Currency.Format(gift.Coins)), GOLD
	elseif gift.Potion then
		local potion = potionById(gift.Potion)
		local name = if potion then potion.Name else gift.Potion
		return if (gift.Count or 1) > 1 then ("%dx %s"):format(gift.Count, name) else name,
			if potion then potion.Color else PINK
	elseif gift.Egg then
		local look = Config.EggLooks[gift.Egg]
		return string.upper(if look then look.Name else "EGG"), if look then look.Color else PINK
	end
	local crate = Balls.GetCrate(gift.Crate)
	return string.upper(if crate then crate.Name else "CRATE"), if crate then crate.Color else GOLD
end

function PlaytimeController:Start()
	if not PLAYTIME.Enabled then
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local claimRemote = remotes:WaitForChild("ClaimPlaytime") :: RemoteFunction
	local playerGui = player:WaitForChild("PlayerGui")
	local ballsUI = playerGui:WaitForChild("BallsUI") :: ScreenGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "PlaytimeUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = ballsUI.DisplayOrder
	gui.IgnoreGuiInset = ballsUI.IgnoreGuiInset

	-- ===== GIFTS button (owner's HUD Kit): pink gift; caption = time to the next gift, or GIFTS + a count badge when
	-- some are ready, or ALL! with a tick once every gift is claimed =====
	local giftsKit = HudKit.Square(gui, { Name = "GiftsButton", Paint = "Pink", Icon = "GiftPink", Key = "Gifts" })
	local openButton = giftsKit.Holder :: TextButton
	local buttonGift = giftsKit.Slot
	local giftsState = ""
	local stopBob: (() -> ())? = nil

	-- ===== The gifts window (760x500, owner's kit style): 12 gift tiles in a 4x3 grid. The gift boxes grow toward the
	-- last one, a big gold gift. States: READY (lime edge + rays, wiggling gift, CLAIM), NEXT (pink edge, live timer),
	-- LATER (darker card), CLAIMED (what it gave + a tick) =====
	local W, H = 760, 500
	local win = RewardKit.Window(gui, W, H)
	local panel = win.Screen
	local cover, close = RewardKit.Cover(
		win.Panel,
		W,
		H,
		"FREE GIFTS",
		("A GIFT WHEN YOU JOIN, THEN ONE EVERY %d MINUTES · NEW GIFTS EVERY DAY"):format(
			PLAYTIME.Rewards[2].Minutes - PLAYTIME.Rewards[1].Minutes
		),
		C.Pink
	)
	local COUNT = #PLAYTIME.Rewards
	local TILE_W, TILE_H = 169, 119
	local RIGHT_X, RIGHT_W = 84, TILE_W - 6 - 90 -- the text column right of the gift

	local function rewardIcon(gift): (string, any)
		if gift.Coins then
			return "Coins", nil
		elseif gift.Potion then
			return "Potion", gift.Potion
		elseif gift.Egg then
			return "Egg", gift.Egg
		end
		return "Crate", gift.Crate
	end

	local tiles = {}
	for index, reward in PLAYTIME.Rewards do
		local col, row = (index - 1) % 4, (index - 1) // 4
		local x, y = 24 + col * (TILE_W + 12), 100 + row * (TILE_H + 12)
		local last = index == COUNT
		local block = UiKit.Block(cover, {
			Name = "Gift" .. index,
			Size = Vector2.new(TILE_W, TILE_H),
			Fill = if last then C.Gold else C.Card,
			Lip = if last then C.GoldLip else C.Page,
			LipPx = 6,
			Radius = 16,
			Outline = 3,
		})
		block.Holder.Position = UDim2.fromOffset(x, y)
		local face = block.Face
		local edge = UiKit.Outline(face, C.Lime, 3)
		edge.Enabled = false
		local giftSpot = UiKit.Make("Frame", {
			Name = "GiftSpot",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(76, TILE_H - 20),
		}, face)
		local rays = RewardKit.Rays(giftSpot, UiKit.Hex("FF8A1F"), 104, 8)
		rays.Visible = last
		local giftSize = math.floor(44 + (index - 1) / math.max(COUNT - 1, 1) * 24)
		local gift = RewardKit.Icon(giftSpot, if last then "GiftGold" else "Gift", nil, giftSize)
		local kind, value = rewardIcon(resolve(index))
		local prize = RewardKit.Icon(giftSpot, kind, value, 58)
		prize.Visible = false
		local tick = CrateKit.Icon(giftSpot, "Check", 30)
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.new(0.5, 24, 0.5, 22)
		tick.ZIndex = 8
		tick.Visible = false
		if last then
			RewardKit.Twinkle(face, 3, C.White)
		end

		local mark = RewardKit.Label(
			face,
			if reward.Minutes == 0
				then "JOIN GIFT"
				elseif reward.Minutes >= 60 and reward.Minutes % 60 == 0 then ("%d HOUR%s"):format(
					reward.Minutes // 60,
					if reward.Minutes == 60 then "" else "S"
				)
				else ("%d MIN"):format(reward.Minutes),
			UiKit.Head,
			15,
			if last then C.White else C.Label,
			2,
			RIGHT_X,
			8,
			RIGHT_W,
			18
		)
		mark.TextXAlignment = Enum.TextXAlignment.Left
		local name = UiKit.Text(face, "", UiKit.Body, 12, C.White, if last then 2 else 0)
		name.Name = "GiftName"
		name.Position = UDim2.fromOffset(RIGHT_X, 29)
		name.Size = UDim2.fromOffset(RIGHT_W, 30)
		name.TextWrapped = true
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextYAlignment = Enum.TextYAlignment.Top
		RewardKit.Fit(name, 12, RIGHT_W, 30)
		local timer = RewardKit.Label(face, "", UiKit.Num, 22, C.White, 2, RIGHT_X, 62, RIGHT_W, 32)
		timer.TextXAlignment = Enum.TextXAlignment.Left
		local claim = RewardKit.Button(face, "CLAIM", "Lime", 76, 38, 18)
		claim.Holder.Position = UDim2.fromOffset(RIGHT_X - 4, 60)
		claim.Holder.Visible = false
		claim.Activated:Connect(function()
			PlaytimeController.Claim(index)
		end)
		tiles[index] = {
			Block = block,
			Edge = edge,
			Rays = rays,
			Gift = gift,
			Prize = prize,
			PrizeKind = kind,
			PrizeValue = value,
			Tick = tick,
			Name = name,
			Timer = timer,
			Claim = claim,
			Last = last,
			X = x,
			Y = y,
			State = "",
			StopPulse = nil :: (() -> ())?,
		}
	end

	-- Ready gifts wiggle (-12/10/-6 degrees) every 1.6 s while the window is open
	task.spawn(function()
		while true do
			task.wait(1.6)
			if panel.Visible then
				for _, t in tiles do
					if t.State == "Ready" then
						task.spawn(function()
							for _, angle in { -12, 10, -6, 0 } do
								UiKit.Tween(t.Gift, 0.08, Enum.EasingStyle.Quad, { Rotation = angle })
								task.wait(0.08)
							end
						end)
					end
				end
			end
		end
	end)

	-- Toast for messages ("Hatch it at the egg stand!")
	local toast = RewardKit.Toast(gui)
	local function showToast(message: string, seconds: number?)
		toast(message, nil, nil, nil, seconds)
	end

	local function claimedSet(): { [number]: boolean }
		local set = {}
		local value = player:GetAttribute("PlaytimeClaimed")
		if type(value) == "string" then
			for number in value:gmatch("%d+") do
				set[tonumber(number) :: number] = true
			end
		end
		return set
	end

	local function played(): number?
		local start = player:GetAttribute("PlaytimeStart")
		return if type(start) == "number" then Workspace:GetServerTimeNow() - start else nil
	end

	local lastReady = 0
	local function refresh()
		local seconds = played()
		local claimed = claimedSet()
		local ready = 0
		local nextLeft = nil
		for index, reward in PLAYTIME.Rewards do
			local t = tiles[index]
			local gift = resolve(index)
			t.Name.Text = (describe(gift))
			-- a gift's crate or egg can change when a new zone opens: redraw its prize then
			local kind, value = rewardIcon(gift)
			if kind ~= t.PrizeKind or value ~= t.PrizeValue then
				t.PrizeKind, t.PrizeValue = kind, value
				RewardKit.Fill(t.Prize, kind, value)
			end
			local left = if seconds then reward.Minutes * 60 - seconds else math.huge
			local state
			if claimed[index] then
				state = "Claimed"
			elseif left <= 0 then
				state = "Ready"
				ready += 1
			elseif nextLeft == nil then
				state = "Next"
				nextLeft = left
			else
				state = "Later"
			end
			if state == "Next" or state == "Later" then
				t.Timer.Text = if seconds then clock(left) else "--:--"
			end
			if state ~= t.State then
				t.State = state
				t.Gift.Visible = state ~= "Claimed"
				t.Prize.Visible = state == "Claimed"
				t.Tick.Visible = state == "Claimed"
				t.Claim.Holder.Visible = state == "Ready"
				t.Timer.Visible = state ~= "Ready"
				t.Edge.Enabled = state == "Ready" or state == "Next"
				t.Edge.Color = if state == "Ready" then C.Lime else C.Pink
				t.Rays.Visible = state == "Ready" or (t.Last and state ~= "Claimed")
				t.Rays.ImageColor3 = if state == "Ready" then C.Lime else UiKit.Hex("FF8A1F")
				if not t.Last then
					t.Block:Paint(if state == "Later" or state == "Claimed" then C.Page else C.Card, C.Page)
				end
				if state == "Claimed" then
					t.Timer.Text = "CLAIMED"
					t.Timer.TextColor3 = C.Lime
				else
					t.Timer.TextColor3 = if state == "Next" or t.Last then C.White else C.Muted
				end
				if state == "Ready" and not t.StopPulse then
					t.StopPulse = RewardKit.Pulse(t.Claim.Holder, 1.08, 0.45)
				elseif state ~= "Ready" and t.StopPulse then
					t.StopPulse()
					t.StopPulse = nil
				end
			end
		end
		giftsKit:SetBadge(if ready > 0 then ready else nil)
		local newState = if ready > 0 then "Ready" elseif nextLeft then "Counting" else "Done"
		if newState ~= giftsState then
			giftsState = newState
			giftsKit:Paint(if newState == "Done" then "Card" else "Pink")
			if newState == "Done" then
				giftsKit:SetIcon("Check", 30)
				giftsKit:SetCaption("ALL!", HudKit.C.Lime)
			else
				giftsKit:SetIcon("GiftPink")
			end
			-- Ready: the gift bobs up and down (0.5 s each way)
			if stopBob then
				stopBob()
				stopBob = nil
			end
			if newState == "Ready" then
				local running = true
				stopBob = function()
					running = false
				end
				task.spawn(function()
					while running and buttonGift.Parent do
						local home = buttonGift.Position
						local up = TweenService:Create(
							buttonGift,
							TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
							{ Position = home - UDim2.fromOffset(0, 4) }
						)
						up:Play()
						up.Completed:Wait()
						local down = TweenService:Create(
							buttonGift,
							TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
							{ Position = home }
						)
						down:Play()
						down.Completed:Wait()
					end
				end)
			end
		end
		if newState == "Ready" then
			giftsKit:SetCaption("GIFTS")
		elseif newState == "Counting" then
			giftsKit:SetCaption(clock(nextLeft :: number), HudKit.C.White, HudKit.Num, 13)
		end
		if ready > lastReady then
			-- A new gift is ready: the button bounces
			UiFx.Pop(openButton, 1.35, 0.4)
			UiFx.Pop(buttonGift, 1.5, 0.5)
			Sfx.Play("Reveal")
		end
		lastReady = ready
	end

	local claiming = false
	function PlaytimeController.Claim(index: number)
		if claiming then
			return
		end
		claiming = true
		local ok, result = pcall(claimRemote.InvokeServer, claimRemote, index)
		claiming = false
		if not ok or type(result) ~= "table" or not result.Ok then
			showToast(if ok and type(result) == "table" and result.Error then result.Error else "Something went wrong")
			return
		end
		refresh()
		local tile = tiles[index]
		local _, color = describe(resolve(index))
		Sfx.Play("Reveal")
		-- The tile jumps, the tick stamps down on what it gave and confetti bursts out of it
		local scale = UiKit.ScaleOf(tile.Block.Holder)
		scale.Scale = 1.2
		UiKit.Tween(scale, 0.4, Enum.EasingStyle.Back, { Scale = 1 })
		RewardKit.Stamp(tile.Tick)
		CrateKit.Confetti(cover, tile.X + TILE_W / 2 - W / 2, tile.Y + TILE_H / 2 - H / 2, 24, 180, 0.6)
		UiFx.Flash(color, 0.3, 0.4)
		if result.Coins then
			toast(("+%s COINS!"):format(Currency.Format(result.Coins)), "Coins", nil, nil, 2.6)
		elseif result.Potion then
			local potion = potionById(result.Potion)
			local name = if potion then potion.Name else "POTION"
			toast(
				if (result.Count or 1) > 1
					then ("%dx %s ADDED TO YOUR POTIONS!"):format(result.Count, name)
					else ("%s ADDED TO YOUR POTIONS!"):format(name),
				"Potion",
				result.Potion,
				nil,
				2.6
			)
		elseif result.Egg then
			local egg = Mascots.GetEgg(result.Egg)
			local level = player:GetAttribute("RankLevel") or 1
			local unlocked = egg ~= nil
				and Mascots.EggUnlocked(egg, level, Zones.Highest(player:GetAttribute("ZonesOpen")))
			local look = Config.EggLooks[result.Egg]
			local eggName = string.upper(if look then look.Name else "EGG")
			toast(
				if unlocked
					then ("FREE %s! HATCH IT AT THE EGG STAND"):format(eggName)
					else ("FREE %s! IT WAITS FOR YOU IN THE NEXT ZONE"):format(eggName),
				"Egg",
				result.Egg,
				nil,
				3
			)
		end
		local crate = Balls.GetCrate(result.CrateId)
		if crate and result.Crate and CrateController.PlayOpening then
			task.wait(0.8)
			win:Close()
			CrateController.PlayOpening(crate, result.Crate)
		end
	end

	openButton.Activated:Connect(function()
		if panel.Visible then
			win:Close()
		else
			refresh()
			win:Open()
			-- the gifts pop in one after another
			local gifts = {}
			for index = 1, COUNT do
				table.insert(gifts, tiles[index].Block.Holder)
			end
			RewardKit.Stagger(gifts, 0.03, 0.12)
		end
	end)
	close.Activated:Connect(function()
		win:Close()
	end)

	-- Studio only: jump the clock 15 minutes ahead
	local testRemote = remotes:FindFirstChild("TestPlaytime") :: RemoteEvent?
	if testRemote then
		local test = RewardKit.Button(cover, "TEST: +15 MIN", "Grey", 150, 34, 14)
		test.Holder.Position = UDim2.fromOffset(W - 240, 20)
		test.Activated:Connect(function()
			testRemote:FireServer()
		end)
	end

	-- Hide the button (and close the panel) while the book, crates or crate-opening screens are up
	local covers = {
		ballsUI:WaitForChild("Inventory"),
		ballsUI:WaitForChild("Book"),
		ballsUI:WaitForChild("Shop"),
		ballsUI:WaitForChild("Opening"),
	}
	local function updateButton()
		local covered = false
		for _, screen in covers do
			covered = covered or screen.Visible
		end
		openButton.Visible = not covered
		if covered then
			win:Close()
		end
	end
	for _, screen in covers do
		screen:GetPropertyChangedSignal("Visible"):Connect(updateButton)
	end
	updateButton()

	player:GetAttributeChangedSignal("PlaytimeStart"):Connect(refresh)
	player:GetAttributeChangedSignal("PlaytimeClaimed"):Connect(refresh)
	player:GetAttributeChangedSignal("RankLevel"):Connect(refresh)
	player:GetAttributeChangedSignal("ZonesOpen"):Connect(refresh)
	player:GetAttributeChangedSignal("PowerLevel"):Connect(refresh)
	refresh()
	gui.Parent = playerGui

	-- The timers count down every second
	task.spawn(function()
		while true do
			task.wait(1)
			refresh()
		end
	end)
end

return PlaytimeController
