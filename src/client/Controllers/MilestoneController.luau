-- Zone milestones on screen (Phase X Part 1, Config.Milestones): the challenge tracker (under the streak box on a
-- computer, under the Power Level button on a phone) while you bowl in the challenge's zone, the "next level reward"
-- card under it, and the payout popup when a level reward or a challenge pays out (then the crate opens). Built in
-- code in the owner's kit look (UI pass batch 3, 2026-10-28: navy lip cards, ink outlines, gold pips, real 3D crates).
-- The server decides everything (MilestoneService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local CoreLadder = require(Shared.Modules.CoreLadder)
local Currency = require(Shared.Modules.Currency)
local LaneUtil = require(Shared.Modules.LaneUtil)
local CrateController = require(script.Parent.CrateController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local CrateKit = require(Modules:WaitForChild("CrateKit"))
local RewardKit = require(Modules:WaitForChild("RewardKit"))

local player = Players.LocalPlayer

local MILESTONES = Config.Milestones
local C = UiKit.C
local make = UiKit.Make
local tween = UiKit.Tween

-- Design sizes (px on a 1920x1080 screen); phones shrink them with a UIScale
local TRACKER_W, TRACKER_H = 250, 104
local PREVIEW_H = 60
-- Computers: right side, under the streak box and the free-crate bar (the left column holds the Power Level button
-- and, in Studio, its TEST buttons). Phones: left column under the Power Level button (ScreenLayout's compact spots).
local TRACKER_NORMAL = { Anchor = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 378), Scale = 1 }
local TRACKER_COMPACT = { Anchor = Vector2.new(0, 0), Position = UDim2.fromOffset(12, 250), Scale = 0.62 }

local MilestoneController = {}

local function potionName(id: string): string
	local potion = RewardKit.PotionById(id)
	return if potion then potion.Name else "POTION"
end

-- What a reward gives, one item per thing: { Kind, Value, Text } ("+50K COINS", "2 COIN POTIONS", "BRONZE CRATE")
local function rewardItems(reward, coins: number?): { { Kind: string, Value: any, Text: string } }
	local items = {}
	local shownCoins = coins or reward.Coins
	local core = Config.CoreLoop.Enabled
	if core and not coins then
		-- (Addendum 4 core loop: rewards pay minutes of ladder income, a crate pays coins; same rule as the server)
		local ballStep, bagLevel = player:GetAttribute("BallStep"), player:GetAttribute("BagLevel")
		local gifts = Config.CoreLoop.Gifts
		shownCoins = (if reward.Coins then CoreLadder.GiftCoins(reward.CoreMinutes or gifts.RewardMinutes, ballStep, bagLevel) else 0)
			+ (if reward.Crate then CoreLadder.GiftCoins(gifts.CrateMinutes, ballStep, bagLevel) else 0)
	end
	if shownCoins and shownCoins > 0 then
		table.insert(items, { Kind = "Coins", Text = ("+%s COINS"):format(Currency.Format(shownCoins)) })
	end
	for _, potion in reward.Potions or {} do
		local count = potion.Count or 1
		table.insert(items, {
			Kind = "Potion",
			Value = potion.Id,
			Text = ("%d %s%s"):format(count, potionName(potion.Id), if count > 1 then "S" else ""):upper(),
		})
	end
	local crate = reward.CrateId or reward.Crate
	if type(crate) == "string" and not core then
		local row = Balls.GetCrate(crate)
		table.insert(items, { Kind = "Crate", Value = crate, Text = string.upper(if row then row.Name else crate) })
	end
	return items
end

-- The next level reward above this level, or nil
local function nextLevelReward(level: number)
	local best = nil
	for _, row in MILESTONES.LevelRewards do
		if row.Level > level and (best == nil or row.Level < best.Level) then
			best = row
		end
	end
	return best
end

local function clock(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- A left-aligned kit label at design x, y, w, h
local function label(parent: Instance, text: string, font: Font, size: number, color: Color3, stroke: number, x, y, w, h)
	local l = RewardKit.Label(parent, text, font, size, color, stroke, x, y, w, h)
	l.TextXAlignment = Enum.TextXAlignment.Left
	return l
end

function MilestoneController:Start()
	if not MILESTONES.Enabled then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MilestoneUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 4
	gui.Parent = player:WaitForChild("PlayerGui")

	-- ===== Challenge tracker: navy lip card with a pink ring, CHALLENGE + count, the goal, gold pips, the prize =====
	local tracker = UiKit.Block(gui, {
		Name = "Tracker",
		Size = Vector2.new(TRACKER_W, TRACKER_H),
		Fill = C.Cover,
		Lip = C.Ink,
		LipPx = 5,
		Radius = 16,
		Outline = 3,
		Ring = C.Pink,
	})
	local trackerScale = UiKit.ScaleOf(tracker.Holder)
	tracker.Holder.Visible = false
	local face = tracker.Face
	local title = label(face, "CHALLENGE", UiKit.Head, 20, C.Pink, 2, 12, 8, 150, 24)
	local count = RewardKit.Label(face, "0/3", UiKit.Num, 22, C.White, 2, TRACKER_W - 78, 6, 64, 26)
	count.TextXAlignment = Enum.TextXAlignment.Right
	local goal = label(face, "", UiKit.Body, 13, C.Label, 0, 12, 33, TRACKER_W - 26, 16)
	local dots = make("Frame", {
		Name = "Dots",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 52),
		Size = UDim2.fromOffset(TRACKER_W - 26, 20),
	}, face)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 6),
		VerticalAlignment = Enum.VerticalAlignment.Center,
	}, dots)
	local prize = label(face, "", UiKit.Head, 16, C.Gold, 2, 12, 74, TRACKER_W - 26, 20)

	-- ===== Next level reward card: the reward's icon (the real 3D crate), NEXT LEVEL REWARD, LV n + what it gives =====
	local preview = UiKit.Block(gui, {
		Name = "Preview",
		Size = Vector2.new(TRACKER_W, PREVIEW_H),
		Fill = C.Card,
		Lip = C.Ink,
		LipPx = 5,
		Radius = 14,
		Outline = 3,
		Ring = C.Cyan,
	})
	local previewScale = UiKit.ScaleOf(preview.Holder)
	preview.Holder.Visible = false
	local previewIcon = make("Frame", {
		Name = "IconSpot",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.fromOffset(46, 46),
	}, preview.Face)
	label(preview.Face, "NEXT LEVEL", UiKit.Head, 13, C.Cyan, 1.5, 60, 6, TRACKER_W - 72, 16)
	local previewText = label(preview.Face, "", UiKit.Head, 18, C.White, 2, 60, 24, TRACKER_W - 72, 24)

	-- ===== Payout popup (centre): rays, a gold title with the ink drop, one row per reward; taps pass through =====
	local POP_W = 460
	local stage = make("Frame", {
		Name = "Popup",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(POP_W, 300),
		Visible = false,
	}, gui)
	local stageFit = make("UIScale", {}, stage)
	local pop = make("Frame", { Name = "Pop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, stage)
	local popScale = UiKit.ScaleOf(pop)
	local rays = RewardKit.Rays(pop, C.Gold, 520, 9)
	rays.Position = UDim2.fromOffset(POP_W / 2, 60)
	rays.ZIndex = 0
	local card = UiKit.Block(pop, {
		Name = "Card",
		Size = Vector2.new(POP_W, 300),
		Fill = C.Cover,
		Lip = C.Ink,
		LipPx = 6,
		Radius = 22,
		Outline = 4,
		Ring = C.Gold,
	})
	local titleBox = make("Frame", {
		Name = "TitleBox",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(POP_W - 32, 58),
	}, card.Face)
	local popupTitle = CrateKit.Title(titleBox, "", 46, C.Gold, 3.5, 4)
	local rows = make("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(30, 86),
		Size = UDim2.new(1, -60, 1, -100),
	}, card.Face)
	make("UIListLayout", { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }, rows)

	local function layout()
		local camera = Workspace.CurrentCamera
		local compact = camera ~= nil and camera.ViewportSize.Y < Config.Ui.CompactHeight
		local spot = if compact then TRACKER_COMPACT else TRACKER_NORMAL
		for _, block in { tracker.Holder, preview.Holder } do
			block.AnchorPoint = spot.Anchor
		end
		trackerScale.Scale = spot.Scale
		previewScale.Scale = spot.Scale
		local position = spot.Position
		if not compact then
			-- computers: never under the next-goal bar on the right (it moves with the screen size)
			local eventUi = player.PlayerGui:FindFirstChild("EventUI")
			local goalBar = eventUi and eventUi:FindFirstChild("AlmostBar") :: GuiObject?
			if goalBar and goalBar.Visible then
				local bottom = goalBar.AbsolutePosition.Y + goalBar.AbsoluteSize.Y - gui.AbsolutePosition.Y
				position = UDim2.new(1, -16, 0, math.max(position.Y.Offset, math.ceil(bottom) + 12))
			end
		end
		tracker.Holder.Position = position
		local below = position + UDim2.fromOffset(0, math.floor((TRACKER_H + 8) * spot.Scale))
		if camera then
			local view = camera.ViewportSize
			stageFit.Scale = math.max(0.45, math.min(1, (view.X - 24) / POP_W, (view.Y - 60) / 320))
		end
		return position, below
	end

	local function currentZone(): number
		local lane = LaneUtil.GetOwnedLane(player.UserId)
		return if lane then LaneUtil.ZoneOf(lane) else 1
	end

	local shownDots = -1
	local function setDots(filled: number, goalCount: number)
		count.Text = ("%d/%d"):format(filled, goalCount)
		if shownDots == filled * 100 + goalCount then
			return
		end
		local grew = shownDots >= 0 and filled * 100 + goalCount > shownDots and shownDots // 100 < filled
		shownDots = filled * 100 + goalCount
		for _, child in dots:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for i = 1, goalCount do
			local on = i <= filled
			local pip = make("Frame", {
				Name = "Pip",
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = if on then C.Gold else C.Slot,
				LayoutOrder = i,
			}, dots)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, pip)
			UiKit.Outline(pip, if on then C.Ink else C.Dash, 2)
			if on and grew and i == filled then
				-- the pip you just earned pops
				local s = UiKit.ScaleOf(pip)
				s.Scale = 1.8
				tween(s, 0.3, Enum.EasingStyle.Back, { Scale = 1 })
			end
		end
	end

	local previewRow = nil
	local function refresh()
		local top, below = layout()
		local zone = currentZone()
		local now = Workspace:GetServerTimeNow()
		local active = nil
		for _, challenge in MILESTONES.Challenges do
			if challenge.Zone == nil or challenge.Zone == zone then
				active = challenge
				break
			end
		end
		tracker.Holder.Visible = active ~= nil
		if active then
			local readyAt = player:GetAttribute("ChallengeReady_" .. active.Id) or 0
			local done = player:GetAttribute("Challenge_" .. active.Id) or 0
			goal.Text = active.Text:format(active.Goal)
			if now < readyAt then
				setDots(active.Goal, active.Goal)
				title.Text = "CHALLENGE DONE!"
				title.TextColor3 = C.Lime
				prize.Text = "AGAIN IN " .. clock(readyAt - now)
				prize.TextColor3 = C.Muted
			else
				setDots(math.min(done, active.Goal), active.Goal)
				title.Text = "CHALLENGE"
				title.TextColor3 = C.Pink
				prize.Text = active.RewardText
				prize.TextColor3 = C.Gold
			end
		end

		local nextRow = if MILESTONES.Preview and not (Config.CoreLoop.Enabled and Config.CoreLoop.NoLevels)
			then nextLevelReward(player:GetAttribute("RankLevel") or 1)
			else nil -- (Addendum 5 A1: no levels, no level rewards)
		-- Only from zone 2 on: in the Back Alley the next goal bar already points the way
		preview.Holder.Visible = nextRow ~= nil and zone >= 2
		if nextRow then
			if nextRow ~= previewRow or Config.CoreLoop.Enabled then -- (core loop: the coins follow your ball + bag)
				previewRow = nextRow
				local items = rewardItems(nextRow)
				local texts = {}
				for _, item in items do
					table.insert(texts, item.Text)
				end
				previewText.Text = ("LV %d · %s"):format(nextRow.Level, table.concat(texts, " + "))
				-- the best thing it gives: a crate, else a potion, else coins
				previewIcon:ClearAllChildren()
				local show = items[#items]
				if show then
					RewardKit.Icon(previewIcon, show.Kind, show.Value, 46, UDim2.fromScale(0.5, 0.5))
				end
			end
			preview.Holder.Position = if active then below else top
		end
	end

	-- Popups play one after another
	local queue = {}
	local showing = false
	local function showNext()
		if showing or #queue == 0 then
			return
		end
		showing = true
		local data = table.remove(queue, 1)
		popupTitle.Text = if data.Kind == "Level"
			then ("LEVEL %d REWARD"):format(data.Level)
			elseif data.Kind == "Boss" then "BOSS DEFEATED!"
			elseif data.Kind == "Away" then "WELCOME BACK"
			else "CHALLENGE DONE!"
		RewardKit.Fit(popupTitle, 46, POP_W - 40, 56)
		for _, child in rows:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local items = rewardItems(data, data.Coins)
		local rowObjects = {}
		for i, item in items do
			local row = UiKit.Block(rows, {
				Name = "Row",
				Size = Vector2.new(POP_W - 60, 54),
				Fill = C.Card,
				Lip = C.Ink,
				LipPx = 5,
				Radius = 16,
				Outline = 3,
			})
			row.Holder.LayoutOrder = i
			RewardKit.Icon(row.Face, item.Kind, item.Value, 42, UDim2.fromOffset(32, 23))
			local text = label(row.Face, item.Text, UiKit.Head, 26, if item.Kind == "Coins" then C.Gold else C.White, 2.5, 62, 6, POP_W - 140, 34)
			text.Name = "Text"
			table.insert(rowObjects, row.Holder)
		end
		local height = 100 + #items * 64
		stage.Size = UDim2.fromOffset(POP_W, height)
		card.Holder.Size = UDim2.fromOffset(POP_W, height)
		rays.Position = UDim2.fromOffset(POP_W / 2, height / 2)
		layout()
		Sfx.Play("Reveal")
		stage.Visible = true
		popScale.Scale = 0.6
		tween(popScale, 0.22, Enum.EasingStyle.Back, { Scale = 1.05 }).Completed:Once(function()
			tween(popScale, 0.1, Enum.EasingStyle.Quad, { Scale = 1 })
		end)
		RewardKit.Stamp(titleBox)
		RewardKit.Stagger(rowObjects, 0.08, 0.2)
		CrateKit.Confetti(pop, 0, -40, 26, 260, 0.7)
		task.delay(MILESTONES.PopupTime, function()
			tween(popScale, 0.2, Enum.EasingStyle.Back, { Scale = 0 }, Enum.EasingDirection.In).Completed:Wait()
			stage.Visible = false
			local crate = Balls.GetCrate(data.CrateId)
			if crate and data.Crate and CrateController.PlayOpening then
				task.wait(0.3)
				CrateController.PlayOpening(crate, data.Crate)
			end
			showing = false
			showNext()
		end)
	end

	-- WELCOME BACK (away coins): no popup (owner 2026-10-28: too in your face), just one line of small white text that
	-- fades in near the top of the screen, stays a few seconds and fades out
	local toastGui = make("ScreenGui", {
		Name = "WelcomeBackUI",
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		DisplayOrder = 60, -- over popup backdrops (the daily calendar opens at the same moment)
	}, player:WaitForChild("PlayerGui"))
	local function welcomeBack(coins: number)
		local text = make("TextLabel", {
			Name = "WelcomeBack",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 14),
			Size = UDim2.new(0.9, 0, 0, 26),
			BackgroundTransparency = 1,
			FontFace = UiKit.Body,
			TextSize = 20,
			TextColor3 = C.White,
			TextTransparency = 1,
			TextStrokeTransparency = 1,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			Text = ("You made %s coins while you were gone"):format(Currency.Format(coins)),
			ZIndex = 50,
		}, toastGui)
		make("UITextSizeConstraint", { MaxTextSize = 20, MinTextSize = 12 }, text)
		text.TextScaled = true
		tween(text, 0.6, Enum.EasingStyle.Quad, { TextTransparency = 0, TextStrokeTransparency = 0.55 })
		task.delay(0.6 + MILESTONES.WelcomeBackSeconds, function()
			tween(text, 0.8, Enum.EasingStyle.Quad, { TextTransparency = 1, TextStrokeTransparency = 1 }).Completed:Wait()
			text:Destroy()
		end)
	end

	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("MilestoneReward").OnClientEvent:Connect(function(data)
		if data.Kind == "Away" then
			welcomeBack(data.Coins or 0)
			return
		end
		table.insert(queue, data)
		showNext()
		refresh()
	end)

	task.spawn(function()
		while true do
			refresh()
			task.wait(0.5)
		end
	end)
end

return MilestoneController
