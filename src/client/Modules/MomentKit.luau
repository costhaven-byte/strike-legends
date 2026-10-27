-- Big moments in the owner's kit style (UI pass batch 2, 2026-10-28): the 10 rank badges, the LEVEL UP burst and
-- the big slam banners (TRIAL START / PASSED! / FAILED). Built from the kits like RewardKit: ink outlines, lip
-- blocks, Luckiest Guy titles with the ink drop, rays, sparkles, confetti. Sizes are design px on a 1920x1080 screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local UiKit = require(script.Parent:WaitForChild("UiKit"))
local CrateKit = require(script.Parent:WaitForChild("CrateKit"))
local HudKit = require(script.Parent:WaitForChild("HudKit"))
local RewardKit = require(script.Parent:WaitForChild("RewardKit"))

local MomentKit = {}

local make = UiKit.Make
local tween = UiKit.Tween
local C = UiKit.C

-- ===== Rank badges: one shape per tier (Config.Ranks order), drawn from frames so they stay crisp =====
-- A piece: { cx, cy, w, h, rotation, round (0..0.5 of the short side), tint? } in fractions of the badge size.
-- Pieces with a tint are trims (wings, crowns) painted that colour instead of the rank's.
local SILVER = Color3.fromRGB(215, 222, 240)
local GOLD = C.Gold
local PEARL = Color3.fromRGB(255, 244, 220)

local function burst(points: number, size: number, cy: number?): { any }
	local pieces = {}
	local squares = points // 4
	for i = 0, squares - 1 do
		table.insert(pieces, { 0.5, cy or 0.5, size, size, i * 90 / squares, 0.06 })
	end
	return pieces
end
local function add(list: { any }, more: { any }): { any }
	for _, piece in more do
		table.insert(list, piece)
	end
	return list
end
local function shield(cy: number?): { any }
	local y = cy or 0
	return { { 0.5, 0.42 + y, 0.7, 0.56, 0, 0.18 }, { 0.5, 0.6 + y, 0.5, 0.5, 45, 0.1 } }
end
local function wings(tint: Color3?): { any }
	return {
		{ 0.13, 0.4, 0.3, 0.15, -22, 0.5, tint or SILVER },
		{ 0.87, 0.4, 0.3, 0.15, 22, 0.5, tint or SILVER },
		{ 0.15, 0.56, 0.26, 0.13, -8, 0.5, tint or SILVER },
		{ 0.85, 0.56, 0.26, 0.13, 8, 0.5, tint or SILVER },
	}
end
local function crown(): { any }
	return {
		{ 0.5, 0.115, 0.4, 0.1, 0, 0.2, GOLD },
		{ 0.35, 0.06, 0.12, 0.12, 45, 0.15, GOLD },
		{ 0.5, 0.035, 0.14, 0.14, 45, 0.15, GOLD },
		{ 0.65, 0.06, 0.12, 0.12, 45, 0.15, GOLD },
	}
end

MomentKit.BadgeShapes = {
	{ { 0.5, 0.5, 0.8, 0.8, 0, 0.5 } }, -- Rookie: a plain coin
	{ { 0.5, 0.5, 0.76, 0.76, 0, 0.22 } }, -- Amateur: a rounded tile
	{ { 0.5, 0.5, 0.66, 0.66, 45, 0.14 } }, -- Regular: a diamond
	shield(), -- Club: a shield
	burst(8, 0.68), -- Semi-Pro: an 8-point star
	burst(12, 0.7), -- Pro: a 12-point burst
	add(wings(), shield(0.02)), -- Elite: a winged shield
	add(burst(16, 0.72, 0.53), crown()), -- Master: a crowned burst
	add(add(wings(), burst(12, 0.7, 0.52)), crown()), -- Legend: wings, burst, crown
	add(add(wings(GOLD), burst(16, 0.76, 0.52)), crown()), -- Hall of Famer: the biggest of everything, pearl + rainbow ring
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(70, 200, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)),
})

-- The badge for a rank (1 = Rookie .. 10 = Hall of Famer) in a size x size frame, centred on position
function MomentKit.Badge(parent: Instance?, rankIndex: number, size: number, position: UDim2?): Frame
	local rank = Config.Ranks[rankIndex] or Config.Ranks[1]
	local shape = MomentKit.BadgeShapes[rankIndex] or MomentKit.BadgeShapes[1]
	local top = rankIndex == #Config.Ranks
	local holder = make("Frame", {
		Name = "Badge",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position or UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = 4,
	}, parent)
	local ink = math.max(2, math.floor(size * 0.045 + 0.5))
	local function piece(p, grow: number, color: Color3, z: number)
		local w, h = p[3] * size + grow * 2, p[4] * size + grow * 2
		local frame = make("Frame", {
			Name = "Piece",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(p[1], p[2]),
			Size = UDim2.fromOffset(w, h),
			Rotation = p[5],
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = z,
		}, holder)
		make("UICorner", { CornerRadius = UDim.new(0, math.min(w, h) * p[6]) }, frame)
		return frame
	end
	-- the ink silhouette first (every piece a little bigger), then the paint (flat, so overlaps leave no seams)
	for _, p in shape do
		piece(p, ink, C.Ink, 4)
	end
	for _, p in shape do
		piece(p, 0, if p[7] then p[7] elseif top then PEARL else rank.Color, 5)
	end
	-- the centre medallion: a darker coin with the tier number
	local cy = if #shape > 1 and shape[#shape][7] == GOLD then 0.55 else 0.5
	if rankIndex == 4 or rankIndex == 7 then
		cy = 0.47
	end
	local coin = make("Frame", {
		Name = "Coin",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, cy),
		Size = UDim2.fromOffset(size * 0.42, size * 0.42),
		BackgroundColor3 = if top then C.Cover else rank.Color:Lerp(C.Ink, 0.55),
		ZIndex = 6,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, coin)
	make("UIStroke", { Color = C.Ink, Thickness = ink }, coin)
	local ring = make("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -ink * 2, 1, -ink * 2),
		ZIndex = 6,
	}, coin)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
	local ringLine = make("UIStroke", {
		Color = if top then C.White else rank.Color:Lerp(C.White, 0.35),
		Thickness = math.max(1, ink * (if top then 1.2 else 0.6)),
	}, ring)
	if top then
		make("UIGradient", { Color = RAINBOW, Rotation = 30 }, ringLine)
	end
	local number =
		UiKit.Text(coin, tostring(rankIndex), UiKit.Head, math.floor(size * 0.26), C.White, math.max(1.5, ink * 0.7))
	number.ZIndex = 7
	make("UIPadding", { PaddingTop = UDim.new(0, math.floor(size * 0.03)) }, number)
	-- a white shine on the top left
	local shine = make("Frame", {
		Name = "Shine",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.34, if cy < 0.5 then 0.27 else 0.3),
		Size = UDim2.fromOffset(size * 0.08, size * 0.14),
		Rotation = 35,
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.35,
		ZIndex = 6,
	}, holder)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, shine)
	return holder
end

-- ===== Overlay layer: a ScreenGui over the HUD that never takes taps =====
function MomentKit.Layer(name: string, order: number): ScreenGui
	return make("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = order,
	}, Players.LocalPlayer:WaitForChild("PlayerGui"))
end

-- A frame centred on the screen at design size that shrinks with the screen (phones held sideways)
local function stageOf(gui: ScreenGui, w: number, h: number, y: number): Frame
	local stage = make("Frame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, y),
		Size = UDim2.fromOffset(w, h),
		Visible = false,
	}, gui)
	local scale = make("UIScale", {}, stage)
	local function refit()
		local area = gui.AbsoluteSize
		if area.X > 0 then
			scale.Scale = math.max(0.35, math.min(1, area.X / 1920 * 1.25, area.Y / 1080 * 1.25))
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	refit()
	return stage
end

-- ===== LEVEL UP burst: rays, "LEVEL UP!", the LV n plate and what it gave, for 2.6 s; taps pass through =====
-- show(level, gems, rankIndex)
function MomentKit.LevelUp(): (number, number?, number?) -> ()
	local gui = MomentKit.Layer("LevelUpUI", 45)
	local W, H = 520, 340
	local stage = stageOf(gui, W, H, 0.4)
	local pop = make("Frame", { Name = "Pop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, stage)
	local popScale = UiKit.ScaleOf(pop)
	local rays = RewardKit.Rays(pop, GOLD, 520, 6)
	rays.Position = UDim2.fromOffset(W / 2, 150)
	rays.ZIndex = 1
	local titleBox = make("Frame", {
		Name = "TitleBox",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.fromOffset(W, 80),
		ZIndex = 3,
	}, pop)
	local title = CrateKit.Title(titleBox, "LEVEL UP!", 76, GOLD, 4.5, 6)
	for _, label in titleBox:GetDescendants() do
		if label:IsA("TextLabel") then
			label.ZIndex = 3
		end
	end
	local plate = UiKit.Block(pop, {
		Name = "Plate",
		Size = Vector2.new(260, 112),
		Fill = C.Cover,
		Lip = C.Ink,
		LipPx = 7,
		Radius = 26,
		Outline = 4,
	})
	plate.Holder.Position = UDim2.fromOffset((W - 260) / 2, 104)
	local ringStroke =
		make("UIStroke", { Color = GOLD, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, plate.Face)
	local lv = UiKit.Text(plate.Face, "LV 1", UiKit.Num, 72, C.White, 4)
	lv.Name = "Level"
	make("UIPadding", { PaddingBottom = UDim.new(0, 4) }, lv)
	local reward = UiKit.Block(pop, {
		Name = "Reward",
		Size = Vector2.new(240, 52),
		Fill = C.Card,
		Lip = C.Ink,
		LipPx = 5,
		Radius = 26,
		Outline = 3,
	})
	reward.Holder.Position = UDim2.fromOffset((W - 240) / 2, 236)
	local gemIcon = HudKit.Image(reward.Face, "Gem", 34, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
	})
	local rewardText = UiKit.Text(reward.Face, "", UiKit.Head, 28, C.Cyan, 2.5)
	rewardText.Position = UDim2.fromOffset(56, 3)
	rewardText.Size = UDim2.new(1, -70, 1, 0)

	local token = 0
	return function(level: number, gems: number?, rankIndex: number?)
		token += 1
		local mine = token
		local rank = Config.Ranks[rankIndex or 1] or Config.Ranks[1]
		lv.Text = ("LV %d"):format(level)
		ringStroke.Color = rank.Color
		rays.ImageColor3 = rank.Color:Lerp(GOLD, 0.5)
		if (gems or 0) > 0 then
			gemIcon.Visible = true
			rewardText.Text = ("+%d GEMS"):format(gems :: number)
			rewardText.TextColor3 = C.Cyan
			rewardText.Position = UDim2.fromOffset(56, 3)
			rewardText.Size = UDim2.new(1, -70, 1, 0)
		else
			gemIcon.Visible = false
			rewardText.Text = rank.Name:upper()
			rewardText.TextColor3 = rank.Color
			rewardText.Position = UDim2.fromOffset(10, 3)
			rewardText.Size = UDim2.new(1, -20, 1, 0)
		end
		RewardKit.Fit(rewardText, 28, rewardText.Size.X.Offset + 240 - 24, 46)
		title.TextTransparency = 0
		stage.Visible = true
		popScale.Scale = 0.3
		tween(popScale, 0.3, Enum.EasingStyle.Back, { Scale = 1.08 }).Completed:Once(function()
			if token == mine then
				tween(popScale, 0.1, Enum.EasingStyle.Quad, { Scale = 1 })
			end
		end)
		RewardKit.Stagger({ plate.Holder, reward.Holder }, 0.08, 0.15)
		RewardKit.Stamp(titleBox)
		CrateKit.Confetti(pop, 0, -20, 22, 220, 0.7)
		task.delay(2.6, function()
			if token ~= mine then
				return
			end
			tween(popScale, 0.2, Enum.EasingStyle.Back, { Scale = 0 }, Enum.EasingDirection.In).Completed:Wait()
			if token == mine then
				stage.Visible = false
			end
		end)
	end
end

-- ===== Slam banner: a coloured lip ribbon with a big title and an optional navy chip under it, ~2 s =====
-- show(text, paint (RewardKit.Paint name), sub?)
function MomentKit.Banner(gui: ScreenGui): (string, string, string?) -> ()
	local W, H = 620, 190
	local stage = stageOf(gui, W, H, 0.34)
	local pop = make("Frame", { Name = "Pop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, stage)
	local popScale = UiKit.ScaleOf(pop)
	local ribbon = UiKit.Block(pop, {
		Name = "Ribbon",
		Size = Vector2.new(560, 116),
		Fill = C.Lime,
		Lip = C.LimeLip,
		LipPx = 9,
		Radius = 28,
		Outline = 5,
	})
	ribbon.Holder.Position = UDim2.fromOffset((W - 560) / 2, 0)
	local titleBox =
		make("Frame", { Name = "TitleBox", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, ribbon.Face)
	local title = CrateKit.Title(titleBox, "", 78, C.White, 5, 6)
	make("UIPadding", { PaddingTop = UDim.new(0, 10) }, title)
	local chip = UiKit.Block(pop, {
		Name = "Chip",
		Size = Vector2.new(380, 50),
		Fill = C.Cover,
		Lip = C.Ink,
		LipPx = 5,
		Radius = 25,
		Outline = 3,
	})
	chip.Holder.Position = UDim2.fromOffset((W - 380) / 2, 124)
	local chipText = UiKit.Text(chip.Face, "", UiKit.Head, 24, C.White, 2.5)
	make("UIPadding", { PaddingTop = UDim.new(0, 3) }, chipText)

	local token = 0
	return function(text: string, paint: string, sub: string?)
		token += 1
		local mine = token
		local colours = RewardKit.Paint[paint] or RewardKit.Paint.Lime
		ribbon.Face.BackgroundColor3 = colours[1]
		ribbon.Body.BackgroundColor3 = colours[2]
		title.Text = text
		RewardKit.Fit(title, 78, 520, 100)
		chip.Holder.Visible = sub ~= nil
		chipText.Text = sub or ""
		chipText.TextColor3 = colours[1]
		RewardKit.Fit(chipText, 24, 350, 44)
		stage.Visible = true
		pop.Rotation = -6
		popScale.Scale = 2.4
		tween(popScale, 0.35, Enum.EasingStyle.Back, { Scale = 1 })
		tween(pop, 0.35, Enum.EasingStyle.Back, { Rotation = 0 })
		if paint == "Lime" or paint == "Gold" then
			CrateKit.Confetti(pop, 0, 0, 26, 320, 0.8)
		end
		task.delay(2, function()
			if token ~= mine then
				return
			end
			tween(popScale, 0.2, Enum.EasingStyle.Back, { Scale = 0 }, Enum.EasingDirection.In).Completed:Wait()
			if token == mine then
				stage.Visible = false
			end
		end)
	end
end

-- ===== Rank up: full screen, the new badge on rays, its name, what it gives, confetti and CONTINUE =====
-- show(rankIndex, level?, gems)
function MomentKit.RankUp(): ((number, number?, number) -> (), Frame)
	local gui = MomentKit.Layer("RankUpKitUI", 50)
	local screen = make("Frame", {
		Name = "Screen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Active = true,
	}, gui) :: Frame
	local shade = make("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, screen)
	local flash = make("Frame", {
		Name = "Flash",
		BackgroundColor3 = C.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
	}, screen)
	local W, H = 900, 720
	local stage = make("Frame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H),
		ZIndex = 2,
	}, screen)
	local fit = make("UIScale", {}, stage)
	local function refit()
		local area = gui.AbsoluteSize
		if area.X > 0 then
			fit.Scale = math.max(0.3, math.min(1, (area.X - 24) / W, (area.Y - 16) / H))
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	local pop = make("Frame", { Name = "Pop", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, stage)
	local popScale = UiKit.ScaleOf(pop)

	local titleBox = make("Frame", {
		Name = "TitleBox",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 10),
		Size = UDim2.fromOffset(W, 100),
		ZIndex = 5,
	}, pop)
	CrateKit.Title(titleBox, "RANK UP!", 96, GOLD, 5, 8)
	local badgeSpot = make("Frame", {
		Name = "BadgeSpot",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(W / 2, 290),
		Size = UDim2.fromOffset(260, 260),
		ZIndex = 3,
	}, pop)
	local rays = RewardKit.Rays(badgeSpot, GOLD, 760, 9)
	rays.ZIndex = 1
	local nameBox = make("Frame", {
		Name = "NameBox",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 438),
		Size = UDim2.fromOffset(W, 84),
		ZIndex = 5,
	}, pop)
	local rankName = CrateKit.Title(nameBox, "", 76, C.White, 4.5, 7)
	local chips = make("Frame", {
		Name = "Chips",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 534),
		Size = UDim2.fromOffset(W, 54),
		ZIndex = 5,
	}, pop)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 14),
	}, chips)
	local continue = RewardKit.Button(pop, "CONTINUE", "Lime", 300, 72, 36)
	continue.Holder.Position = UDim2.fromOffset((W - 300) / 2, 616)

	local function chip(order: number, text: string, color: Color3, icon: string?)
		local width = CrateKit.TextWidth(text, UiKit.Head, 26) + (if icon then 76 else 44)
		local block = UiKit.Block(chips, {
			Name = "Chip",
			Size = Vector2.new(width, 54),
			Fill = C.Cover,
			Lip = C.Ink,
			LipPx = 5,
			Radius = 27,
			Outline = 3,
		})
		block.Holder.LayoutOrder = order
		local x = 22
		if icon then
			HudKit.Image(
				block.Face,
				icon,
				34,
				{ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0) }
			)
			x = 56
		end
		local label = UiKit.Text(block.Face, text, UiKit.Head, 26, color, 2.5)
		label.Position = UDim2.fromOffset(x, 3)
		label.Size = UDim2.new(1, -x - 18, 1, 0)
		return block.Holder
	end

	local stopTwinkle: (() -> ())? = nil
	local canClose = false
	local function close()
		if not screen.Visible or not canClose then
			return
		end
		canClose = false
		if stopTwinkle then
			stopTwinkle()
			stopTwinkle = nil
		end
		tween(shade, 0.2, Enum.EasingStyle.Linear, { BackgroundTransparency = 1 })
		tween(popScale, 0.22, Enum.EasingStyle.Back, { Scale = 0 }, Enum.EasingDirection.In).Completed:Wait()
		screen.Visible = false
	end
	continue.Activated:Connect(close)
	UiKit.CloseKeys(screen, close)

	local function show(rankIndex: number, level: number?, gems: number)
		local rank = Config.Ranks[rankIndex] or Config.Ranks[1]
		refit()
		badgeSpot:FindFirstChild("Badge"):Destroy()
		local badge = MomentKit.Badge(badgeSpot, rankIndex, 260)
		rays.ImageColor3 = rank.Color
		rankName.Text = rank.Name:upper()
		rankName.TextColor3 = rank.Color
		for _, child in chips:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if level then
			chip(1, ("LEVEL %d"):format(level), C.White)
		end
		if gems > 0 then
			chip(2, ("+%d GEMS"):format(gems), C.Cyan, "Gem")
		end
		chip(3, ("x%g COINS"):format(rank.Multiplier), GOLD, "Coins2")

		screen.Visible = true
		shade.BackgroundTransparency = 1
		tween(shade, 0.25, Enum.EasingStyle.Linear, { BackgroundTransparency = 0.12 })
		flash.BackgroundTransparency = 0
		tween(flash, 0.6, Enum.EasingStyle.Quad, { BackgroundTransparency = 1 })
		popScale.Scale = 0.6
		tween(popScale, 0.3, Enum.EasingStyle.Back, { Scale = 1 })
		RewardKit.Stamp(titleBox)
		local badgeScale = UiKit.ScaleOf(badge)
		badgeScale.Scale = 0.01
		task.delay(0.25, function()
			tween(badgeScale, 0.35, Enum.EasingStyle.Back, { Scale = 1.15 }).Completed:Wait()
			tween(badgeScale, 0.12, Enum.EasingStyle.Quad, { Scale = 1 })
		end)
		RewardKit.Stagger({ nameBox, chips, continue.Holder }, 0.12, 0.45)
		if stopTwinkle then
			stopTwinkle()
		end
		stopTwinkle = RewardKit.Twinkle(badgeSpot, 8, GOLD)
		CrateKit.Confetti(pop, 0, -120, 50, 480, 1)
		task.delay(0.5, function()
			CrateKit.Confetti(pop, -300, -60, 24, 260, 0.9)
			CrateKit.Confetti(pop, 300, -60, 24, 260, 0.9)
		end)
		canClose = false
		task.delay(0.8, function()
			canClose = true
		end)
	end
	MomentKit.Badge(badgeSpot, 1, 260) -- a placeholder the first show replaces
	return show, screen
end

return MomentKit
