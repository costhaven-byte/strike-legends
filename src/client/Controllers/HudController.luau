-- Shows coins, gems, the rank/XP bar and the streak panel, and a "+XP +gems" line after each throw.
-- After a throw, coin (and gem) icons fly from the pins into the counters with a rising "ding".
-- The frames are StarterGui.HUD (built in Studio); since the owner's HUD Kit (2026-10-26) this script draws their
-- look in code (Modules/HudKit) and keeps the names other scripts use (Bar.Coins/Gems with Icon + Amount, RankBar,
-- Streak).
-- Values come from Player attributes, which only the server sets.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Progression = require(Shared.Modules.Progression)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local HudKit = require(Modules.HudKit)
local K = HudKit.C

local player = Players.LocalPlayer

local STATS = { "Coins", "Gems" }
local COUNT_TIME = Config.Ui.CountTime

local JUICE = Config.Juice
local NO_STREAK_COLOR = Color3.fromRGB(150, 140, 180)
local BROKEN_COLOR = K.Red

-- Coin and gem counters: icon overlapping the left end of a dark pill. Sizes from the HUD Kit (computer / phone).
local COUNTERS = {
	Coins = {
		Icon = "Coin",
		Pc = { Icon = 68, Pill = { 22, 6, 218, 56 }, Lip = 5, Pad = 50, Text = 36, Stroke = 3 },
		Phone = { Icon = 40, Pill = { 16, 3, 102, 34 }, Lip = 3, Pad = 24, Text = 19, Stroke = 2 },
	},
	Gems = {
		Icon = "Gem",
		Pc = { Icon = 58, Pill = { 20, 4, 150, 50 }, Lip = 5, Pad = 50, Text = 32, Stroke = 3 },
		Phone = { Icon = 36, Pill = { 14, 1, 56, 34 }, Lip = 3, Pad = 22, Text = 19, Stroke = 2 },
	},
}

local HudController = {}

-- 1234567 -> "1,234,567"; anything a million or more -> "1.23M"
-- Every number on screen uses the shared formatter (Config.Numbers)
local formatNumber = Currency.Format

local function bump(scale: UIScale)
	scale.Scale = 1.15
	TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
end

-- V2 counter pill (board A "Counter pills", HUD B1/B2): navy pill with the ink outline, lip and top strip, the big
-- coin / gem icon hanging off its left end, the number in white. The coins/min line sits inside the coin pill
-- (Income spot). Gems are earned only, so the design's green + is left out.
local function buildCounterV2(pill: Frame, key: string)
	local SlKit = require(Modules.SlKit)
	for _, child in pill:GetChildren() do
		if child.Name ~= "Amount" and not child:IsA("UIScale") then
			child:Destroy()
		end
	end
	pill.BackgroundTransparency = 1
	pill.LayoutOrder = 0
	local block = HudKit.Block(pill, {
		Name = "Pill",
		Paint = { SlKit.C.Window, SlKit.C.Ink, SlKit.C.WindowStrip },
		Ink = SlKit.C.Ink,
		Strip = 3,
		Shine = 0,
	})
	local icon = SlKit.Image(pill, if key == "Coins" then "cur_coin" else "cur_gem", 64, { ZIndex = 6 })
	icon.AnchorPoint = Vector2.new(0, 0.5)
	local label = pill:WaitForChild("Amount") :: TextLabel
	label.BackgroundTransparency = 1
	label.FontFace = SlKit.Font
	label.TextScaled = false
	label.TextColor3 = K.White
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.AnchorPoint = Vector2.zero
	label.ZIndex = 6
	for _, child in label:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UITextSizeConstraint") then
			child:Destroy()
		end
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = SlKit.C.Ink
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	HudKit.OnLayout(function(phone)
		local _, size = HudKit.Spot(key, phone)
		local w, h = (size :: UDim2).X.Offset, (size :: UDim2).Y.Offset
		local iconSize = h
		local bodyH = math.floor(h * 0.86)
		local left = math.floor(iconSize * 0.42)
		block.Holder.Position = UDim2.fromOffset(left, math.floor((h - bodyH) / 2))
		block.Holder.Size = UDim2.fromOffset(w - left, bodyH)
		block:SetRadius(bodyH / 2)
		block:SetLip(if phone then 4 else 6)
		icon.Size = UDim2.fromOffset(iconSize, iconSize)
		icon.Position = UDim2.new(0, 0, 0.5, -1)
		-- coins: the number rides high, the coins/min line under it
		local textSize = if phone then (if key == "Coins" then 20 else 19) else (if key == "Coins" then 32 else 30)
		local textLeft = iconSize + (if phone then 4 else 10)
		label.TextSize = textSize
		label.Position = UDim2.fromOffset(textLeft, if key == "Coins" then (if phone then 2 else 6) else 0)
		label.Size = UDim2.new(1, -textLeft - 8, 0, if key == "Coins" then textSize + 4 else h - (if phone then 4 else 6))
		stroke.Thickness = if phone then 2 else 3
	end)
	HudKit.Place(pill, key)
end

-- Draws a counter (HudKit look) into the Studio frame, keeping its Icon, Amount and UIScale
local function buildCounter(pill: Frame, key: string)
	if HudKit.V2 then
		buildCounterV2(pill, key)
		return
	end
	local spec = COUNTERS[key]
	for _, child in pill:GetChildren() do
		if child.Name ~= "Amount" and not child:IsA("UIScale") then
			child:Destroy()
		end
	end
	pill.BackgroundTransparency = 1
	pill.LayoutOrder = 0
	-- Sunny look (Config.Ui.Sunny): a light pill with a dark number
	local block = HudKit.Block(pill, { Name = "Pill", Paint = if HudKit.Sunny then "Cream" else "Card", Shine = 0 })
	local icon = HudKit.Image(pill, spec.Icon, 68)
	icon.ZIndex = 6
	local label = pill:WaitForChild("Amount") :: TextLabel
	label.BackgroundTransparency = 1
	label.FontFace = HudKit.Num
	label.TextScaled = false
	label.TextColor3 = if HudKit.Sunny then K.Ink else K.White
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.AnchorPoint = Vector2.zero
	label.ZIndex = 6
	for _, child in label:GetChildren() do
		if child:IsA("UIStroke") or child:IsA("UITextSizeConstraint") then
			child:Destroy()
		end
	end
	local stroke = Instance.new("UIStroke")
	stroke.Color = K.Ink
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Enabled = not HudKit.Sunny
	stroke.Parent = label
	HudKit.OnLayout(function(phone)
		local s = if phone then spec.Phone else spec.Pc
		local x, y, w, h = s.Pill[1], s.Pill[2], s.Pill[3], s.Pill[4]
		block.Holder.Position = UDim2.fromOffset(x, y)
		block.Holder.Size = UDim2.fromOffset(w, h)
		block:SetRadius(h / 2)
		block:SetLip(s.Lip)
		icon.Size = UDim2.fromOffset(s.Icon, s.Icon)
		label.Position = UDim2.fromOffset(x + s.Pad, y)
		label.Size = UDim2.fromOffset(w - s.Pad - 6, h - s.Lip)
		label.TextSize = s.Text
		stroke.Thickness = s.Stroke
	end)
	HudKit.Place(pill, key)
end

local startedAt = os.clock()

local function bindStat(pill: Frame, key: string)
	local label = pill:WaitForChild("Amount") :: TextLabel
	local scale = pill:WaitForChild("UIScale") :: UIScale
	local shown = Instance.new("NumberValue")
	shown.Value = player:GetAttribute(key) or 0
	label.Text = formatNumber(shown.Value)

	shown.Changed:Connect(function(value)
		label.Text = formatNumber(value)
	end)

	player:GetAttributeChangedSignal(key):Connect(function()
		local target = player:GetAttribute(key) or 0
		if target > shown.Value then
			bump(scale)
			-- Gems get their own chime (not while the save is loading in)
			if key == "Gems" and os.clock() - startedAt > 5 then
				Sfx.Play("Gem")
			end
		end
		TweenService:Create(shown, TweenInfo.new(COUNT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Value = target,
		}):Play()
	end)
end

-- Coins per minute (polish P1): green "+12K/min" under the coin counter, from the CoinsPerMinute attribute
-- (server, Config.Income). It pops a little when it goes up (an upgrade, a pet, a potion).
local function bindIncome(bar: Frame)
	local holder = Instance.new("Frame")
	holder.Name = "Income"
	holder.BackgroundTransparency = 1
	holder.Parent = bar
	local label = HudKit.Text(holder, "", HudKit.Num, 24, K.Lime, 2)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.ZIndex = 6
	local stroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local v2Kit = if HudKit.V2 then require(Modules.SlKit) else nil
	if v2Kit then
		-- V2: "+95K/min" in the kit's value green, inside the coin pill
		label.FontFace = v2Kit.Font
		label.TextColor3 = v2Kit.C.Value
		stroke.Color = v2Kit.C.Ink
		label.ZIndex = 8
	end
	HudKit.OnLayout(function(phone)
		if v2Kit then
			label.TextSize = if phone then 12 else 18
			stroke.Thickness = if phone then 1.5 else 2
			return
		end
		label.TextSize = if phone then 15 else 24
		stroke.Thickness = if phone then 1.5 else 2.5
	end)
	HudKit.Place(holder, "Income")
	local last = 0
	local function refresh()
		local value = player:GetAttribute("CoinsPerMinute")
		holder.Visible = value ~= nil
		if value == nil then
			return
		end
		label.Text = "+" .. formatNumber(value) .. (if v2Kit then "/min" else " a min")
		if value > last and last > 0 then
			scale.Scale = 1.2
			TweenService
				:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
				:Play()
		end
		last = value
	end
	refresh()
	player:GetAttributeChangedSignal("CoinsPerMinute"):Connect(refresh)
end

-- Level bar (HUD Kit): dark track, lime fill with a lip and shine, XP star over the left end. A level-up turns the
-- fill gold and says "LEVEL UP! LV n" for 1.5 s.
local function bindRankBar(rankBar: Frame)
	for _, child in rankBar:GetChildren() do
		if child.Name ~= "Label" then
			child:Destroy()
		end
	end
	rankBar.BackgroundTransparency = 1
	local track = HudKit.Block(rankBar, { Name = "Track", Paint = { K.Panel, K.CardLip }, Shine = 0 })
	track.Holder.Size = UDim2.fromScale(1, 1)
	-- The fill lives in an area inset 3 px (8 px at the bottom) inside the track
	local area = Instance.new("Frame")
	area.Name = "FillArea"
	area.BackgroundTransparency = 1
	area.ZIndex = 4
	area.Parent = rankBar
	local fillBlock =
		HudKit.Block(area, { Name = "Fill", Paint = "Lime", Outline = 0.001, Shine = 3, ShineAlpha = 0.55 })
	local fill = fillBlock.Holder
	fill.Size = UDim2.fromScale(0.35, 1)
	fillBlock.Outline.Enabled = false
	local star = HudKit.Image(rankBar, "Xp", 68)
	star.ZIndex = 9
	local label = rankBar:WaitForChild("Label") :: TextLabel
	label.FontFace = HudKit.Head
	label.TextScaled = false
	label.TextColor3 = K.White
	label.AnchorPoint = Vector2.zero
	label.ZIndex = 10
	for _, child in label:GetChildren() do
		child:Destroy()
	end
	local labelStroke = Instance.new("UIStroke")
	labelStroke.Color = K.Ink
	labelStroke.LineJoinMode = Enum.LineJoinMode.Round
	labelStroke.Parent = label
	local barScale = Instance.new("UIScale")
	barScale.Parent = rankBar
	local textSize = 22
	local labelHome = UDim2.fromOffset(30, 5)
	HudKit.OnLayout(function(phone)
		local h = if phone then 34 else 52
		track:SetRadius(h / 2)
		track:SetLip(if phone then 3 else 5)
		area.Position = UDim2.fromOffset(if phone then 5 else 6, if phone then 5 else 6)
		area.Size = UDim2.new(1, if phone then -10 else -12, 1, if phone then -12 else -17)
		fillBlock:SetRadius(if phone then 13 else 20)
		fillBlock:SetLip(if phone then 3 else 5)
		local starSize = if phone then 44 else 68
		star.Size = UDim2.fromOffset(starSize, starSize)
		star.Position = UDim2.fromOffset(if phone then -16 else -28, if phone then -5 else -8)
		textSize = if phone then 13 else 22
		HudKit.Fit(label, textSize)
		labelStroke.Thickness = if phone then 2 else 2.5
		label.Size = UDim2.new(1, if phone then -28 else -46, 1, if phone then -9 else -14)
		labelHome = UDim2.fromOffset(if phone then 18 else 30, if phone then 3 else 5)
		label.Position = labelHome
	end)
	HudKit.Place(rankBar, "LevelBar")

	local shownLevel: number? = nil
	local celebrating = 0
	local showingLevelUp = false
	local function refresh()
		local xp = player:GetAttribute("XP") or 0
		local index = player:GetAttribute("Rank") or 1 -- saved rank; the next tier waits for the Rank Trial
		local rank = Progression.GetRank(index)
		local level = Progression.LevelFromXP(xp, index)
		local nextRank = Config.Ranks[index + 1]
		local maxLevel = Config.Economy.Ranks.MaxRank

		local progress = 1
		local text
		if nextRank and xp >= Progression.TierXP(index + 1) then
			local state = player:GetAttribute("TrialState")
			text = ("LV %d %s  ·  XP MAXED  ·  %s"):format(
				level,
				rank.Name:upper(),
				if state == "Active"
					then "TRIAL IN PROGRESS"
					elseif state == "Cooldown" then "TRY THE TRIAL AGAIN SOON"
					else "RANK TRIAL READY"
			)
		elseif level < maxLevel then
			local from, to = Progression.LevelXP(level), Progression.LevelXP(level + 1)
			progress = (xp - from) / (to - from)
			-- One bar for level progress: where you are and what's next
			text = ("LV %d %s · %s XP TO LV %d"):format(level, rank.Name:upper(), formatNumber(to - xp), level + 1)
		else
			text = ("LV %d %s · %s XP"):format(level, rank.Name:upper(), formatNumber(xp))
		end
		local leveledUp = shownLevel ~= nil and level > shownLevel
		shownLevel = level
		if leveledUp then
			-- LEVEL UP: gold full bar, big text, a bounce; back to normal after 1.5 s
			celebrating += 1
			local token = celebrating
			showingLevelUp = true
			fillBlock:Paint("Gold")
			fill.Size = UDim2.fromScale(1, 1)
			label.Text = ("LEVEL %d!"):format(level)
			HudKit.Fit(label, textSize + 2)
			label.Position = labelHome + UDim2.fromOffset(0, 10)
			label.TextTransparency = 1
			TweenService:Create(label, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = labelHome,
				TextTransparency = 0,
			}):Play()
			barScale.Scale = 1
			local grow = TweenService:Create(barScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Scale = 1.08 })
			grow:Play()
			grow.Completed:Once(function()
				TweenService:Create(barScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = 1,
				}):Play()
			end)
			task.delay(1.7, function()
				if token == celebrating then
					showingLevelUp = false
					fillBlock:Paint("Lime")
					HudKit.Fit(label, textSize)
					refresh()
				end
			end)
			return
		end
		if showingLevelUp then
			return -- still showing the level-up; the delay above refreshes after it
		end
		label.Text = text
		TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(math.clamp(progress, 0.06, 1), 1),
		}):Play()
	end

	player:GetAttributeChangedSignal("XP"):Connect(refresh)
	player:GetAttributeChangedSignal("Rank"):Connect(refresh)
	player:GetAttributeChangedSignal("TrialState"):Connect(refresh)
	refresh()
end

local tierIndex = Progression.GetStreakTierIndex

-- Streak panel (HUD Kit): STREAK, flame + number, tier name in the tier's colour, multiplier line.
-- Computer 120x120 stacked; phone 140x46 in one row.
local function bindStreak(panel: Frame)
	for _, child in panel:GetChildren() do
		if child:IsA("UICorner") or child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	panel.BackgroundTransparency = 1
	local card = HudKit.Block(panel, { Name = "Card", Paint = "Card", Shine = 3, ShineAlpha = 0.9 })
	card.Holder.Size = UDim2.fromScale(1, 1)
	card.Holder.ZIndex = 0
	local title = panel:WaitForChild("Title") :: TextLabel
	local count = panel:WaitForChild("Count") :: TextLabel
	local tierName = panel:WaitForChild("TierName") :: TextLabel
	local multiplier = panel:WaitForChild("Multiplier") :: TextLabel
	local scale = panel:WaitForChild("UIScale") :: UIScale
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.ZIndex = 5
	row.Parent = panel
	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Padding = UDim.new(0, 2)
	rowLayout.Parent = row
	local flame = HudKit.Image(row, "Flame", 30)
	flame.LayoutOrder = 1
	count.Parent = row
	count.LayoutOrder = 2
	count.AutomaticSize = Enum.AutomaticSize.X
	local countScale = Instance.new("UIScale")
	countScale.Parent = count
	local strokes = {}
	for _, label in { title, count, tierName, multiplier } do
		label.TextScaled = false
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.zero
		label.ZIndex = 6
		for _, child in label:GetChildren() do
			if child:IsA("UIStroke") or child:IsA("UITextSizeConstraint") then
				child:Destroy()
			end
		end
		local stroke = Instance.new("UIStroke")
		stroke.Color = K.Ink
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = label
		strokes[label] = stroke
	end
	title.Text = "STREAK"
	title.FontFace = HudKit.Head
	title.TextColor3 = K.Gold
	count.FontFace = HudKit.Num
	count.TextColor3 = K.White
	tierName.FontFace = HudKit.Head
	-- Long tier lines ("STRIKE TO START") shrink to fit the panel instead of being cut
	tierName.TextScaled = true
	local tierFit = Instance.new("UITextSizeConstraint")
	tierFit.Parent = tierName
	multiplier.FontFace = HudKit.Body
	multiplier.TextColor3 = K.White
	local function set(
		label: TextLabel,
		x: number,
		y: number,
		w: number,
		h: number,
		size: number,
		stroke: number,
		align
	)
		label.Position = UDim2.fromOffset(x, y)
		label.Size = if w > 0 then UDim2.fromOffset(w, h) else UDim2.fromOffset(0, h)
		label.TextSize = size
		if label == tierName then
			tierFit.MaxTextSize = size
		end
		label.TextXAlignment = align or Enum.TextXAlignment.Center
		strokes[label].Thickness = stroke
	end
	HudKit.OnLayout(function(phone)
		card:SetRadius(if phone then 12 else 20)
		card:SetLip(if phone then 4 else 6)
		if phone then
			-- flame 22 + number 24 on the left, then STREAK / tier / multiplier stacked
			row.Position = UDim2.fromOffset(6, 4)
			row.Size = UDim2.fromOffset(52, 34)
			rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
			flame.Size = UDim2.fromOffset(22, 22)
			set(count, 0, 0, 0, 34, 24, 2)
			count.Size = UDim2.fromOffset(0, 34)
			set(title, 60, 7, 76, 9, 9, 1.5, Enum.TextXAlignment.Left)
			set(tierName, 60, 18, 76, 11, 11, 1.5, Enum.TextXAlignment.Left)
			set(multiplier, 60, 31, 76, 8, 8, 0, Enum.TextXAlignment.Left)
		else
			set(title, 0, 13, 120, 15, 15, 2)
			row.Position = UDim2.fromOffset(0, 31)
			row.Size = UDim2.fromOffset(120, 40)
			rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			flame.Size = UDim2.fromOffset(30, 30)
			set(count, 0, 0, 0, 40, 40, 3)
			count.Size = UDim2.fromOffset(0, 40)
			set(tierName, 4, 74, 112, 14, 14, 2)
			set(multiplier, 0, 91, 120, 10, 10, 1.5)
		end
	end)
	HudKit.Place(panel, "Streak")

	local previous = player:GetAttribute("Streak") or 0
	-- Phones (Config.Ui.PhoneMenu.HideZeroStreak): no panel at 0 strikes, except while STREAK LOST shows
	local losing = false
	local function fit()
		local streak = player:GetAttribute("Streak") or 0
		panel.Visible = not Config.CoreLoop.Enabled -- (Addendum 4 core loop: no strike streaks)
			and not (Config.Ui.PhoneMenu.HideZeroStreak and HudKit.Phone() and streak == 0 and not losing)
	end
	HudKit.OnLayout(fit)
	local function show(streak: number)
		fit()
		local index = tierIndex(streak)
		local tier = Config.Streaks[index]
		local color = if tier and tier.Name ~= "" then tier.Color else NO_STREAK_COLOR
		count.Text = tostring(streak)
		tierName.Text = if tier and tier.Name ~= "" then tier.Name elseif streak == 0 then "STRIKE TO START" else ""
		tierName.TextColor3 = color
		local coinMultiplier = Progression.GetStreakMultiplier(streak)
		local xpMultiplier = Progression.GetStreakXpMultiplier(streak)
		multiplier.Text = if coinMultiplier == xpMultiplier
			then ("x%g COINS, x%g XP"):format(coinMultiplier, coinMultiplier)
			else ("x%g COINS · x%g XP"):format(coinMultiplier, xpMultiplier)
	end

	player:GetAttributeChangedSignal("Streak"):Connect(function()
		local streak = player:GetAttribute("Streak") or 0
		local newTier = tierIndex(streak) > tierIndex(previous)
		local broken = streak == 0 and previous >= 2
		previous = streak
		show(streak)

		if broken then
			-- STREAK LOST in red, the number shakes, then back to normal
			tierName.Text = "STREAK LOST"
			tierName.TextColor3 = BROKEN_COLOR
			losing = true
			fit()
			local home = count.Position
			for _, dx in { -4, 4, -4, 4, -4, 0 } do
				count.Position = home + UDim2.fromOffset(dx, 0)
				task.wait(0.04)
			end
			count.Position = home
			task.delay(1.2, function()
				losing = false
				if (player:GetAttribute("Streak") or 0) == 0 then
					show(0)
				end
			end)
		elseif streak > 0 then
			-- +1: the number pops. New tier: the panel tilts and grows
			countScale.Scale = 1
			local up = TweenService:Create(countScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 1.3 })
			up:Play()
			up.Completed:Once(function()
				TweenService:Create(countScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = 1,
				}):Play()
			end)
			if newTier then
				scale.Scale = 1.15
				TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = 1,
				}):Play()
				task.spawn(function()
					for _, angle in { -5, 5, 0 } do
						TweenService:Create(panel, TweenInfo.new(0.1), { Rotation = angle }):Play()
						task.wait(0.1)
					end
				end)
			end
		end
	end)
	show(previous)
end

-- The counter's icon bumps when a flying icon lands in it
local function bumpIcon(icon: GuiObject)
	local scale = icon:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = icon
	local up = TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 1.25,
	})
	up:Play()
	up.Completed:Once(function()
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)
end

-- Icons copied from a counter's own icon fly from `from` (screen position) into that counter (HUD Kit timings:
-- pop in 0.1 s, fly 0.45 s, 0.05 s apart)
local function flyIcons(pill: Frame, count: number, from: Vector2, startSize: number, endSize: number)
	local icon = pill:FindFirstChild("Icon") :: ImageLabel?
	if not icon then
		return
	end
	local layer = UiFx.Layer()
	local target = icon.AbsolutePosition + icon.AbsoluteSize / 2
	for i = 1, count do
		task.delay((i - 1) * 0.05, function()
			local flyer = icon:Clone()
			for _, child in flyer:GetChildren() do
				child:Destroy()
			end
			flyer.AnchorPoint = Vector2.new(0.5, 0.5)
			-- A little spread so they don't all start on one pixel
			local spot = from + Vector2.new(math.random(-30, 30), math.random(-20, 20))
			flyer.Position = UDim2.fromOffset(spot.X, spot.Y)
			flyer.Size = UDim2.fromOffset(startSize, startSize)
			flyer.ZIndex = 10
			local scale = Instance.new("UIScale")
			scale.Scale = 0
			scale.Parent = flyer
			flyer.Parent = layer
			local pop =
				TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Scale = 1,
				})
			pop:Play()
			pop.Completed:Wait()
			local home = TweenService:Create(
				flyer,
				TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(endSize, endSize) }
			)
			home:Play()
			home.Completed:Wait()
			Sfx.Play("Coin", 1 + (i - 1) * JUICE.CoinPitchStep)
			bumpIcon(icon)
			local fade = TweenService:Create(flyer, TweenInfo.new(0.08), { ImageTransparency = 1 })
			fade:Play()
			fade.Completed:Wait()
			flyer:Destroy()
		end)
	end
end

-- Where a lane's pins are on screen (in HUD coordinates); the middle of the screen if they're off-screen
local function pinsOnScreen(lane: Model): Vector2
	local camera = Workspace.CurrentCamera
	local inset = GuiService:GetGuiInset()
	local pinSpot = lane:FindFirstChild("PinSpot") :: BasePart?
	if pinSpot then
		local point, visible = camera:WorldToViewportPoint(pinSpot.Position + Vector3.new(0, 2, 0))
		if visible then
			return Vector2.new(point.X, point.Y) - inset
		end
	end
	return camera.ViewportSize / 2 - inset
end

-- The "+1.2K XP  +2 GEMS" line under the level bar after a throw (HUD Kit): icon + text per part
local function buildAfterThrow(gui: ScreenGui)
	local line = Instance.new("Frame")
	line.Name = "AfterThrow"
	line.BackgroundTransparency = 1
	line.Visible = false
	line.ZIndex = 8
	line.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = line
	local parts = {}
	for order, spec in { { "Xp", K.Lime }, { "Gem", K.Cyan } } do
		local part = Instance.new("Frame")
		part.Name = spec[1]
		part.BackgroundTransparency = 1
		part.AutomaticSize = Enum.AutomaticSize.X
		part.LayoutOrder = order
		part.Parent = line
		local partLayout = layout:Clone()
		partLayout.Parent = part
		local icon = HudKit.Image(part, spec[1], 30)
		icon.LayoutOrder = 1
		local text = HudKit.Text(part, "", HudKit.Head, 26, spec[2], 3)
		text.LayoutOrder = 2
		text.AutomaticSize = Enum.AutomaticSize.X
		parts[spec[1]] = { Frame = part, Icon = icon, Text = text, Layout = partLayout }
	end
	HudKit.OnLayout(function(phone)
		layout.Padding = UDim.new(0, if phone then 14 else 28)
		for _, part in parts do
			local iconSize = if phone then 18 else 30
			part.Icon.Size = UDim2.fromOffset(iconSize, iconSize)
			part.Layout.Padding = UDim.new(0, if phone then 3 else 6)
			part.Text.TextSize = if phone then 15 else 26
			part.Text.Size = UDim2.new(0, 0, 1, 0);
			(part.Text:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = if phone then 2 else 3
			part.Frame.Size = UDim2.new(0, 0, 1, 0)
		end
	end)
	HudKit.Place(line, "AfterThrow")
	return line, parts
end

function HudController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("HUD")
	local bar = gui:WaitForChild("Bar")
	-- The Studio bar stacked the counters; the HUD Kit places each one itself (the bar is just their folder)
	for _, child in bar:GetChildren() do
		if child:IsA("UIListLayout") or child:IsA("UISizeConstraint") then
			child:Destroy()
		end
	end
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.zero
	bar.Position = UDim2.fromOffset(0, 0)
	bar.Size = UDim2.fromOffset(0, 0)
	for _, key in STATS do
		if key == "Gems" and not Config.Gems.Enabled then
			bar:WaitForChild(key).Visible = false -- gems are switched off (Config.Gems)
		else
			buildCounter(bar:WaitForChild(key), key)
			bindStat(bar:WaitForChild(key), key)
		end
	end
	if Config.Income.Enabled then
		bindIncome(bar)
	end
	bindRankBar(gui:WaitForChild("RankBar"))
	if Config.CoreLoop.Enabled and Config.CoreLoop.NoLevels then
		-- (Addendum 5 A1: no levels, so no XP bar; it stays in place, hidden, for the screens that line up under it)
		local rankBar = gui:WaitForChild("RankBar") :: GuiObject
		rankBar.Visible = false
		rankBar:GetPropertyChangedSignal("Visible"):Connect(function()
			rankBar.Visible = false
		end)
	end
	bindStreak(gui:WaitForChild("Streak"))
	HudKit.MoreButton(gui)

	-- The old Studio "+XP" label is replaced by the HUD Kit line
	local oldPopup = gui:WaitForChild("RewardPopup") :: TextLabel
	oldPopup.Visible = false
	local line, parts = buildAfterThrow(gui)
	local lineToken = 0

	local function fadeTo(alpha: number, time: number)
		for _, part in parts do
			TweenService:Create(part.Text, TweenInfo.new(time), { TextTransparency = alpha }):Play()
			TweenService:Create(part.Text:FindFirstChildOfClass("UIStroke") :: UIStroke, TweenInfo.new(time), {
				Transparency = alpha,
			}):Play()
			TweenService:Create(part.Icon, TweenInfo.new(time), { ImageTransparency = alpha }):Play()
		end
	end

	local function showReward(reward)
		-- Coins show in the payout pop (ThrowFx.PayoutPop, the owner's design), so this line is only XP and gems
		if reward.XP <= 0 and reward.Gems <= 0 then
			return
		end
		parts.Xp.Frame.Visible = reward.XP > 0
		parts.Xp.Text.Text = ("+%s XP"):format(formatNumber(reward.XP))
		parts.Gem.Frame.Visible = reward.Gems > 0
		parts.Gem.Text.Text = if reward.Gems == 1 then "+1 GEM" else ("+%d GEMS"):format(reward.Gems)
		lineToken += 1
		local token = lineToken
		-- Rises 12 px into place while fading in (0.2 s), stays 1.2 s, fades out (0.3 s)
		local home = HudKit.Spot("AfterThrow")
		line.Position = home + UDim2.fromOffset(0, 12)
		line.Visible = true
		for _, part in parts do
			part.Text.TextTransparency = 1
			(part.Text:FindFirstChildOfClass("UIStroke") :: UIStroke).Transparency = 1
			part.Icon.ImageTransparency = 1
		end
		fadeTo(0, 0.2)
		TweenService:Create(line, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = home,
		}):Play()
		task.delay(1.4, function()
			if token ~= lineToken then
				return
			end
			fadeTo(1, 0.3)
			task.wait(0.3)
			if token == lineToken then
				line.Visible = false
			end
		end)
	end

	local throwResult = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ThrowResult")
	throwResult.OnClientEvent:Connect(function(data)
		if data.UserId == player.UserId and data.Reward then
			task.delay(data.RollTime, function()
				showReward(data.Reward)
				local from = pinsOnScreen(data.Lane)
				local phone = HudKit.Phone()
				if data.Reward.Coins > 0 then
					local icons = math.floor(data.Reward.Coins / JUICE.CoinsPerIcon)
					flyIcons(
						bar.Coins,
						math.clamp(icons, JUICE.CoinIconsMin, JUICE.CoinIconsMax),
						from,
						if phone then 28 else 40,
						if phone then 20 else 28
					)
				end
				-- A Gem Hunter gem flies in on its own (TraitFx.GemPayout)
				local hunterGem = data.Reward.GemHunter and Config.Gems.Enabled
				local gems = data.Reward.Gems - (if hunterGem then Config.Rewards.PerfectGemAmount else 0)
				if gems > 0 then
					flyIcons(bar.Gems, math.min(gems, 5), from, if phone then 26 else 36, if phone then 22 else 30)
				end
			end)
		end
	end)

	-- Addendum 5 F: a sell at the station (core loop) sends coins flying from the sold pop (bottom middle, where
	-- CoreHudController shows it) into the coin counter; more coins for bigger sells (log scale, Config.Juice)
	if Config.CoreLoop.Enabled then
		local sold = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CoreSold", 30) :: RemoteEvent?
		if sold then
			sold.OnClientEvent:Connect(function(amount)
				if type(amount) ~= "number" or amount <= 0 then
					return
				end
				local phone = HudKit.Phone()
				local screen = UiFx.Layer().AbsoluteSize
				local from = Vector2.new(screen.X / 2, screen.Y - (if phone then 130 else 200))
				local icons = math.clamp(
					math.floor(JUICE.CoinIconsMin + math.log10(math.max(amount, 1)) * JUICE.SellIconsPerTen),
					JUICE.CoinIconsMin,
					JUICE.CoinIconsMax
				)
				flyIcons(bar.Coins, icons, from, if phone then 28 else 40, if phone then 20 else 28)
			end)
		end
	end
end

return HudController
