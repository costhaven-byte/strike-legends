-- Profile panel (Polish P5, Config.Profile): a purple PROFILE button on the HUD (HudKit spot "Profile": right of DAILY
-- on computers, under BALLS on phones) opens a window with three pages:
--   BOOSTS        every coin and XP multiplier, read from the CoinMultipliers / XpMultipliers attributes that
--                 MultiplierService publishes (the same numbers that pay throws), + a button to the COIN MULTIPLIER card
--   STATS         lifetime numbers (ProfileStats attribute, AchievementService)
--   ACHIEVEMENTS  every Config.Profile achievement: tier, progress bar, gem reward, CLAIM (remote ClaimAchievement)
-- The button shows a red count badge while tiers are ready to claim (AchievementsReady). Kit look: RewardKit window +
-- cover, UiKit blocks, HUD Kit icons. Built in code, so it lives in git.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local UiKitAssets = require(Shared:WaitForChild("UiKitAssets"))
local Modules = script.Parent.Parent:WaitForChild("Modules")
local HudKit = require(Modules:WaitForChild("HudKit"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local RewardKit = require(Modules:WaitForChild("RewardKit"))
local CrateKit = require(Modules:WaitForChild("CrateKit"))
local Sfx = require(Modules:WaitForChild("Sfx"))
local UiFx = require(Modules:WaitForChild("UiFx"))
local MultiplierController = require(script.Parent:WaitForChild("MultiplierController"))

local PROFILE = Config.Profile
-- Addendum 4 core loop: stats and achievements for parts the rooftop doesn't have are left out (Config.CoreLoop.HideProfile)
if Config.CoreLoop.Enabled then
	local hide = {}
	for _, key in Config.CoreLoop.HideProfile do
		hide[key] = true
	end
	local function keep(list, field)
		local out = {}
		for _, row in list do
			if not hide[row[field]] then
				table.insert(out, row)
			end
		end
		return out
	end
	PROFILE = table.clone(PROFILE)
	PROFILE.Stats = keep(Config.Profile.Stats, "Key")
	PROFILE.Achievements = keep(Config.Profile.Achievements, "Stat")
end
local player = Players.LocalPlayer
local C = UiKit.C
local make = UiKit.Make

local ProfileController = {}

-- XP sources (MultiplierService.Xp keys), with their HUD Kit icons
local XP_SOURCES = {
	{ Key = "Zone", Name = "ZONE", Icon = "Portal" },
	{ Key = "Pets", Name = "PETS", Icon = "Paw" },
	{ Key = "Potion", Name = "XP POTION", Icon = "PotionXp" },
	{ Key = "Rebirth", Name = "REBIRTHS", Icon = "Rebirth" },
	{ Key = "Passes", Name = "GAME PASSES", Icon = "Store" },
	{ Key = "XpBoost", Name = "XP BOOST", Icon = "Xp" },
	{ Key = "Streak", Name = "STREAK", Icon = "Flame" },
}

local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

local W, H = 860, 548
local BODY_X, BODY_Y, BODY_W, BODY_H = 24, 158, 812, 366

local function decodeNumbers(text: any): { [string]: number }
	local values = {}
	if type(text) == "string" then
		for key, value in text:gmatch("([^;=]+)=([^;]+)") do
			values[key] = tonumber(value) or 0
		end
	end
	return values
end

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local hours = math.floor(minutes / 60)
	if hours >= 1 then
		return ("%dh %dm"):format(hours, minutes % 60)
	end
	return ("%dm"):format(minutes)
end

local function formatStat(value: number, format: string?): string
	if format == "Time" then
		return formatTime(value)
	end
	-- exact up to a million ("6,229"), short after ("12.5M")
	return if value < 1e6 then Currency.FormatFull(value) else Currency.Format(value)
end

local function statRow(key: string)
	for _, stat in PROFILE.Stats do
		if stat.Key == key then
			return stat
		end
	end
	return nil
end

function ProfileController:Start()
	if not PROFILE or not PROFILE.Enabled then
		return
	end
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local claimRemote = remotes:WaitForChild("ClaimAchievement") :: RemoteFunction
	local playerGui = player:WaitForChild("PlayerGui")
	local ballsUI = playerGui:WaitForChild("BallsUI") :: ScreenGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "ProfileUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = ballsUI.DisplayOrder
	gui.IgnoreGuiInset = ballsUI.IgnoreGuiInset

	-- ===== PROFILE button (HUD Kit square, purple, the UI Kit crown) =====
	local kit = HudKit.Square(gui, { Name = "ProfileButton", Paint = "Purple", Icon = "Xp", Key = "Profile" })
	kit.Icon.Image = UiKitAssets.Image("Rank")
	kit:SetCaption("PROFILE", nil, nil, 10)
	local openButton = kit.Holder :: TextButton

	-- ===== Window =====
	local win = RewardKit.Window(gui, W, H)
	local cover, close = RewardKit.Cover(win.Panel, W, H, "PROFILE", " ", C.Gold)
	local sub = cover:FindFirstChild("Sub") :: TextLabel
	local toast = RewardKit.Toast(gui)
	gui.Parent = playerGui

	-- Tabs
	local pages: { [string]: Frame } = {}
	local tabs = {}
	local current = "Boosts"
	local TABS = { { "Boosts", "BOOSTS" }, { "Stats", "STATS" }, { "Achievements", "ACHIEVEMENTS" } }
	local TAB_W = { 170, 150, 250 }
	local x = 26
	for index, info in TABS do
		local tab = RewardKit.Button(cover, info[2], "Grey", TAB_W[index], 46, 22)
		tab.Holder.Name = info[1] .. "Tab"
		tab.Holder.Position = UDim2.fromOffset(x, 98)
		x += TAB_W[index] + 10
		tabs[info[1]] = tab
		local page = make("Frame", {
			Name = info[1],
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(BODY_X, BODY_Y),
			Size = UDim2.fromOffset(BODY_W, BODY_H),
			Visible = false,
		}, cover)
		pages[info[1]] = page
	end
	-- Red count on the ACHIEVEMENTS tab
	local tabBadge = make("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = C.Red,
		Visible = false,
		ZIndex = 8,
	}, tabs.Achievements.Holder)
	UiKit.Corner(tabBadge, 14)
	UiKit.Outline(tabBadge, C.Ink, 3)
	local tabBadgeText = UiKit.Text(tabBadge, "", UiKit.Num, 16, C.White, 1.5)
	tabBadgeText.ZIndex = 9

	-- ===== BOOSTS page =====
	local boosts = pages.Boosts
	local function sourceList(name: string, title: string, color: Color3, x0: number, w: number, h: number)
		local box = UiKit.Box(boosts, name, C.Page, 16)
		UiKit.Place(box, x0, 0, w, h)
		local head = UiKit.Text(box, title, UiKit.Head, 24, color, 2.5)
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.Position = UDim2.fromOffset(14, 8)
		head.Size = UDim2.new(0.6, 0, 0, 32)
		local total = UiKit.Text(box, "x1", UiKit.Num, 30, C.Gold, 3)
		total.Name = "Total"
		total.TextXAlignment = Enum.TextXAlignment.Right
		total.AnchorPoint = Vector2.new(1, 0)
		total.Position = UDim2.new(1, -14, 0, 6)
		total.Size = UDim2.new(0.45, 0, 0, 36)
		local rule = make("Frame", {
			Name = "Rule",
			BackgroundColor3 = C.Chip,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 46),
			Size = UDim2.new(1, -24, 0, 2),
		}, box)
		local rows = make("Frame", {
			Name = "Rows",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(14, 54),
			Size = UDim2.new(1, -28, 1, -60),
		}, box)
		make("UIListLayout", { Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }, rows)
		return box, total, rows, rule
	end
	local _, coinTotal, coinRows = sourceList("Coins", "COINS", C.Gold, 0, 400, BODY_H)
	local _, xpTotal, xpRows = sourceList("Xp", "XP", C.Cyan, 412, 400, 54 + #XP_SOURCES * 25 + 12)
	local note = RewardKit.Label(
		boosts,
		"Every boost multiplies the others. Grey ones are still x1: pets, potions, rebirths and the STORE raise them.",
		UiKit.Body,
		14,
		C.Label,
		0,
		420,
		54 + #XP_SOURCES * 25 + 22,
		384,
		44
	)
	note.TextWrapped = true
	note.TextXAlignment = Enum.TextXAlignment.Left
	note.TextYAlignment = Enum.TextYAlignment.Top
	local cardButton = RewardKit.Button(boosts, "COIN BOOSTS", "Gold", 260, 52, 22)
	cardButton.Holder.Position = UDim2.fromOffset(412 + 70, BODY_H - 58)
	cardButton.Activated:Connect(function()
		if MultiplierController.SetOpen then
			win:Close()
			task.delay(0.15, MultiplierController.SetOpen, true)
		end
	end)

	local function row(parent: Instance, source, order: number)
		local frame = make("Frame", {
			Name = source.Key,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 24),
		}, parent)
		local icon = HudKit.Image(frame, source.Icon, 22)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.fromScale(0, 0.5)
		local name = UiKit.Text(frame, source.Name, UiKit.Body, 14, C.White, 0)
		name.Name = "Name"
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position = UDim2.fromOffset(30, 0)
		name.Size = UDim2.new(1, -130, 1, 0)
		local value = UiKit.Text(frame, "x1", UiKit.Num, 19, C.Gold, 2)
		value.Name = "Value"
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.fromScale(1, 0)
		value.Size = UDim2.new(0, 100, 1, 0)
		return { Icon = icon, Name = name, Value = value }
	end
	local coinRowsByKey = {}
	for i, source in MultiplierController.Sources do
		coinRowsByKey[source.Key] = row(coinRows, source, i)
	end
	local xpRowsByKey = {}
	for i, source in XP_SOURCES do
		xpRowsByKey[source.Key] = row(xpRows, source, i)
	end

	local function fillRows(values: { [string]: number }, sources, byKey, total: TextLabel)
		local product = 1
		for _, source in sources do
			local value = values[source.Key] or 1
			product *= value
			local r = byKey[source.Key]
			r.Value.Text = Currency.FormatMultiplier(value)
			local on = math.abs(value - 1) > 1e-6
			r.Value.TextColor3 = if value < 1 then C.Red elseif on then C.Gold else C.Faded
			r.Name.TextColor3 = if on then C.White else C.Muted
			r.Icon.ImageTransparency = if on then 0 else 0.55
		end
		total.Text = Currency.FormatMultiplier(product)
	end
	local function refreshBoosts()
		fillRows(
			MultiplierController.Decode(player:GetAttribute("CoinMultipliers")),
			MultiplierController.Sources,
			coinRowsByKey,
			coinTotal
		)
		fillRows(MultiplierController.Decode(player:GetAttribute("XpMultipliers")), XP_SOURCES, xpRowsByKey, xpTotal)
	end

	-- ===== STATS page: 5 x 3 tiles =====
	local statsPage = pages.Stats
	local COLS = 5
	local GAP = 10
	local TILE_W = (BODY_W - GAP * (COLS - 1)) / COLS
	local ROWS = math.ceil(#PROFILE.Stats / COLS)
	local TILE_H = math.min(116, (BODY_H - GAP * (ROWS - 1)) / ROWS)
	local statLabels = {}
	for index, stat in PROFILE.Stats do
		local col, line = (index - 1) % COLS, (index - 1) // COLS
		local block = UiKit.Block(statsPage, {
			Name = stat.Key,
			Size = Vector2.new(TILE_W, TILE_H),
			Fill = C.Card,
			Lip = C.Page,
			LipPx = 5,
			Radius = 14,
		})
		block.Holder.Position = UDim2.fromOffset(col * (TILE_W + GAP), line * (TILE_H + GAP))
		local icon = HudKit.Image(block.Face, stat.Icon, 34)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 8)
		local value = RewardKit.Label(block.Face, "0", UiKit.Num, 28, C.White, 2.5, 6, 44, TILE_W - 18, 32)
		value.Name = "Value"
		local name = RewardKit.Label(block.Face, stat.Name, UiKit.Body, 12, C.Label, 0, 6, 78, TILE_W - 18, 16)
		name.Name = "StatName"
		statLabels[stat.Key] = value
	end
	local function refreshStats()
		local values = decodeNumbers(player:GetAttribute("ProfileStats"))
		for _, stat in PROFILE.Stats do
			statLabels[stat.Key].Text = formatStat(values[stat.Key] or 0, stat.Format)
		end
	end

	-- ===== ACHIEVEMENTS page: a scrolling list, ready ones first =====
	local achPage = pages.Achievements
	local scroll = make("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = C.Gold,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, achPage)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	make(
		"UIPadding",
		{ PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4) },
		scroll
	)
	local ROW_W, ROW_H = BODY_W - 16, 76
	local claiming = false
	local claim: (string) -> ()

	local achRows = {}
	for index, ach in PROFILE.Achievements do
		local block = UiKit.Block(scroll, {
			Name = ach.Id,
			Size = Vector2.new(ROW_W, ROW_H),
			Fill = C.Card,
			Lip = C.Page,
			LipPx = 5,
			Radius = 16,
		})
		block.Holder.LayoutOrder = index
		local face = block.Face
		local edge = UiKit.Outline(face, C.Lime, 3)
		edge.Enabled = false
		local disc = UiKit.Box(face, "Disc", C.Page, 30, 3)
		UiKit.Place(disc, 10, 7, 54, 54)
		local stat = statRow(ach.Stat)
		local icon = HudKit.Image(disc, if stat then stat.Icon else "Xp", 36)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		local title = RewardKit.Label(face, ach.Name, UiKit.Head, 22, C.Gold, 2.5, 76, 4, 300, 28)
		title.TextXAlignment = Enum.TextXAlignment.Left
		local tierText = RewardKit.Label(face, "", UiKit.Head, 16, C.Cyan, 2, 380, 8, 150, 22)
		tierText.TextXAlignment = Enum.TextXAlignment.Left
		local text = RewardKit.Label(face, "", UiKit.Body, 13, C.Label, 0, 78, 30, 440, 16)
		text.TextXAlignment = Enum.TextXAlignment.Left
		-- Progress bar
		local bar = UiKit.Box(face, "Bar", C.Slot, 8, 2)
		UiKit.Place(bar, 76, 48, 360, 16, 2)
		local fill = make("Frame", {
			Name = "Fill",
			BackgroundColor3 = C.Lime,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(0, 1),
		}, bar)
		UiKit.Corner(fill, 6)
		local count = RewardKit.Label(face, "", UiKit.Num, 15, C.White, 2, 444, 46, 120, 20)
		count.TextXAlignment = Enum.TextXAlignment.Left
		-- Reward chip: gem + amount
		local gem = UiKit.Icon(face, "Gem", 30)
		gem.Position = UDim2.fromOffset(572, 18)
		local gemText = RewardKit.Label(face, "", UiKit.Num, 22, C.Cyan, 2.5, 604, 18, 50, 30)
		gemText.TextXAlignment = Enum.TextXAlignment.Left
		local button = RewardKit.Button(face, "CLAIM", "Lime", 124, 50, 22)
		button.Holder.Position = UDim2.fromOffset(ROW_W - 6 - 124 - 10, 8)
		button.Activated:Connect(function()
			claim(ach.Id)
		end)
		achRows[ach.Id] = {
			Ach = ach,
			Block = block,
			Edge = edge,
			Tier = tierText,
			Text = text,
			Fill = fill,
			Count = count,
			Gem = gem,
			GemText = gemText,
			Button = button,
			State = "",
		}
	end

	local function refreshAchievements()
		local stats = decodeNumbers(player:GetAttribute("ProfileStats"))
		local claimed = decodeNumbers(player:GetAttribute("AchievementTiers"))
		local list = {}
		for index, ach in PROFILE.Achievements do
			local r = achRows[ach.Id]
			local done = claimed[ach.Id] or 0
			local value = stats[ach.Stat] or 0
			local tier = ach.Tiers[done + 1]
			local maxed = tier == nil
			local shown = tier or ach.Tiers[#ach.Tiers]
			local ready = not maxed and value >= shown.Goal
			local share = if maxed then 1 else math.clamp(value / shown.Goal, 0, 1)
			local stat = statRow(ach.Stat)
			local goalText = formatStat(shown.Goal, stat and stat.Format)
			r.Tier.Text = if maxed
				then "ALL DONE"
				else ("TIER %s OF %s"):format(
					ROMAN[done + 1] or tostring(done + 1),
					ROMAN[#ach.Tiers] or tostring(#ach.Tiers)
				)
			r.Text.Text = if shown.Goal == 1 and ach.One then ach.One else ach.Text:format(goalText)
			r.Fill.Size = UDim2.fromScale(share, 1)
			r.Fill.BackgroundColor3 = if maxed then C.Gold elseif ready then C.Lime else C.Cyan
			r.Count.Text = if maxed
				then "DONE"
				else ("%s / %s"):format(formatStat(math.min(value, shown.Goal), stat and stat.Format), goalText)
			r.Gem.Visible = not maxed
			r.GemText.Visible = not maxed
			r.GemText.Text = ("+%d"):format(shown.Gems or 0)
			local state = if maxed then "Maxed" elseif ready then "Ready" else "Working"
			if state ~= r.State then
				r.State = state
				r.Edge.Enabled = state == "Ready"
				if state == "Ready" then
					local paint = RewardKit.Paint.Lime
					r.Button:Paint(paint[1], paint[2])
					r.Button:SetText("CLAIM")
					r.Button.Holder.Visible = true
					if not r.StopPulse then
						r.StopPulse = RewardKit.Pulse(r.Button.Holder, 1.06, 0.45)
					end
				else
					if r.StopPulse then
						r.StopPulse()
						r.StopPulse = nil
					end
					if state == "Maxed" then
						local paint = RewardKit.Paint.Gold
						r.Button:Paint(paint[1], paint[2])
						r.Button:SetText("DONE")
					else
						local paint = RewardKit.Paint.Grey
						r.Button:Paint(paint[1], paint[2])
						r.Button:SetText("CLAIM")
					end
				end
				r.Button.Holder.Active = state == "Ready"
			end
			table.insert(
				list,
				{ Id = ach.Id, Rank = if ready then 0 elseif maxed then 2 else 1, Share = share, Index = index }
			)
		end
		-- Ready first, then the closest to done, finished ones last
		table.sort(list, function(a, b)
			if a.Rank ~= b.Rank then
				return a.Rank < b.Rank
			end
			if a.Rank == 1 and math.abs(a.Share - b.Share) > 1e-6 then
				return a.Share > b.Share
			end
			return a.Index < b.Index
		end)
		for order, item in list do
			achRows[item.Id].Block.Holder.LayoutOrder = order
		end
	end

	claim = function(id: string)
		local r = achRows[id]
		if claiming or not r or r.State ~= "Ready" then
			if r and r.State == "Working" then
				Sfx.Play("Error")
			end
			return
		end
		claiming = true
		local ok, result = pcall(claimRemote.InvokeServer, claimRemote, id)
		claiming = false
		if not ok or type(result) ~= "table" or not result.Ok then
			toast(if ok and type(result) == "table" and result.Error then result.Error else "That didn't work. Try again")
			return
		end
		Sfx.Play("Reveal")
		local scale = UiKit.ScaleOf(r.Block.Holder)
		scale.Scale = 1.08
		UiKit.Tween(scale, 0.35, Enum.EasingStyle.Back, { Scale = 1 })
		UiFx.Flash(C.Lime, 0.2, 0.3)
		local pos = r.Block.Holder.AbsolutePosition + r.Block.Holder.AbsoluteSize / 2 - cover.AbsolutePosition
		local scaleNow = math.max(0.01, cover.AbsoluteSize.X / W)
		CrateKit.Confetti(cover, pos.X / scaleNow - W / 2, pos.Y / scaleNow - H / 2, 18, 140, 0.5)
		toast(
			if (result.Gems or 0) > 0
				then ("%s %s: +%d GEMS"):format(r.Ach.Name, ROMAN[result.Tier] or tostring(result.Tier), result.Gems)
				else ("%s %s!"):format(r.Ach.Name, ROMAN[result.Tier] or tostring(result.Tier)),
			if (result.Gems or 0) > 0 then "Gems" else nil,
			nil,
			C.Lime,
			2.4
		)
	end

	-- ===== Badges =====
	local lastReady = 0
	local function refreshBadge()
		local ready = player:GetAttribute("AchievementsReady") or 0
		kit:SetBadge(if ready > 0 then ready else nil)
		tabBadge.Visible = ready > 0
		tabBadgeText.Text = tostring(ready)
		if ready > lastReady and lastReady >= 0 then
			UiFx.Pop(openButton, 1.25, 0.35)
		end
		lastReady = ready
	end

	local function refreshSub()
		local level = player:GetAttribute("RankLevel") or 1
		local rebirths = player:GetAttribute("Rebirths") or 0
		sub.Text = ("%s  ·  LEVEL %d  ·  %d REBIRTH%s"):format(
			string.upper(player.DisplayName),
			level,
			rebirths,
			if rebirths == 1 then "" else "S"
		)
	end

	local function show(name: string)
		current = name
		for key, page in pages do
			page.Visible = key == name
			local paint = if key == name then RewardKit.Paint.Gold else RewardKit.Paint.Grey
			tabs[key]:Paint(paint[1], paint[2])
		end
		if name == "Boosts" then
			refreshBoosts()
		elseif name == "Stats" then
			refreshStats()
		else
			refreshAchievements()
			scroll.CanvasPosition = Vector2.zero
		end
	end
	for key, tab in tabs do
		tab.Activated:Connect(function()
			if current ~= key then
				Sfx.Play("Click")
				show(key)
			end
		end)
	end

	function ProfileController.SetOpen(open: boolean, page: string?)
		if open then
			refreshSub()
			-- Something to claim: open straight on the achievements
			show(page or (if (player:GetAttribute("AchievementsReady") or 0) > 0 then "Achievements" else current))
			win:Open()
		else
			win:Close()
		end
	end
	openButton.Activated:Connect(function()
		ProfileController.SetOpen(not win:IsOpen())
	end)
	close.Activated:Connect(function()
		win:Close()
	end)

	-- Live updates while open
	local function onChange()
		if not win:IsOpen() then
			return
		end
		if current == "Boosts" then
			refreshBoosts()
		elseif current == "Stats" then
			refreshStats()
		else
			refreshAchievements()
		end
	end
	for _, attribute in { "CoinMultipliers", "XpMultipliers", "ProfileStats", "AchievementTiers" } do
		player:GetAttributeChangedSignal(attribute):Connect(onChange)
	end
	player:GetAttributeChangedSignal("AchievementsReady"):Connect(function()
		refreshBadge()
		onChange()
	end)
	refreshBadge()

	-- Hide the button (and close the window) while the book, crates or crate-opening screens are up
	local covers = {}
	for _, name in { "Inventory", "Book", "Shop", "Opening" } do
		local screen = ballsUI:FindFirstChild(name) or ballsUI:WaitForChild(name, 10)
		if screen then
			table.insert(covers, screen)
		end
	end
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
end

return ProfileController
