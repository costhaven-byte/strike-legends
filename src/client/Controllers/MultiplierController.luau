-- The Multiplier panel (master plan steps 13.1 and 14.6, built in Addendum 2 step 8b): a gold "x2.3" badge beside
-- the coin counter shows every coin multiplier added up; tapping it opens a card listing each source (Power Level,
-- ball, mascots, rank, streak, lane event). Badge look and spot from the owner's HUD Kit (2026-10-26); the card is
-- the owner's UI Kit COIN MULTIPLIER card (2026-10-26).
-- When anything changes, the badge pops and the total ticks to the new number.
-- Numbers come from the CoinMultipliers Player attribute (MultiplierService, the same numbers that pay throws).
-- Also: the AUTO button, only when Config.AutoBowl.Enabled (off until monetization).
-- Built in code (not in Studio), so it lives in git.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Store = require(Shared.Modules.Store)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local UiFx = require(Modules:WaitForChild("UiFx"))
local HudKit = require(Modules:WaitForChild("HudKit"))
local UiKit = require(Modules:WaitForChild("UiKit"))
local K = HudKit.C

local player = Players.LocalPlayer

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local CARD = Color3.fromRGB(30, 20, 60)
local INK = Color3.fromHex("06060F")
local LIME = Color3.fromRGB(125, 255, 60)

-- Each source in the card, in order: attribute key -> name on screen and its HUD Kit icon.
-- The card lists the sources that change your coins (x1 rows are left out), plus STREAK always.
local SOURCES = {
	{ Key = "Zone", Name = "ZONE", Icon = "Portal" },
	{ Key = "PowerLevel", Name = "POWER LV", Icon = "Bolt" },
	{ Key = "Ball", Name = "BALL", Icon = "Ball" },
	{ Key = "Mascots", Name = "PETS", Icon = "Paw" },
	{ Key = "Potion", Name = "COIN POTION", Icon = "PotionCoin" },
	{ Key = "Rank", Name = "RANK", Icon = "Xp" },
	{ Key = "Rebirth", Name = "REBIRTHS", Icon = "Rebirth" },
	{ Key = "Friends", Name = "FRIENDS", Icon = "GiftPink" },
	{ Key = "Passes", Name = "GAME PASSES", Icon = "Store" },
	{ Key = "RobuxBoost", Name = "COIN BOOST", Icon = "Coins2" },
	{ Key = "Streak", Name = "STREAK", Icon = "Flame", Always = true },
	{ Key = "Modifier", Name = "LANE EVENT", Icon = "Clover" },
	{ Key = "Fever", Name = "FEVER", Icon = "Flame" }, -- only while FEVER MODE runs (Config.Fever)
}

local MultiplierController = {}
-- The Profile panel's BOOSTS page lists the same sources (Polish P5)
MultiplierController.Sources = SOURCES

-- 2.345 -> "x2.35", 3 -> "x3", 1500 -> "x1,500"
local format = Currency.FormatMultiplier

local function decode(text: any): { [string]: number }
	local values = {}
	if type(text) == "string" then
		for key, value in text:gmatch("([^;=]+)=([^;]+)") do
			values[key] = tonumber(value) or 1
		end
	end
	return values
end
MultiplierController.Decode = decode -- "Zone=4;Ball=1.1" -> { Zone = 4, Ball = 1.1 } (also used by the Profile panel)

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = if radius then UDim.new(0, radius) else UDim.new(0.5, 0)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, border: boolean?)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	if border then
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	end
	s.Parent = parent
end

local function text(parent: Instance, name: string, font: Font, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.FontFace = font
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = parent
	stroke(label, INK, 2)
	return label
end

local function bounce(scale: UIScale, peak: number, up: number, down: number)
	scale.Scale = 1
	local grow = TweenService:Create(scale, TweenInfo.new(up, Enum.EasingStyle.Quad), { Scale = peak })
	grow:Play()
	grow.Completed:Once(function()
		TweenService:Create(scale, TweenInfo.new(down, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
	end)
end

function MultiplierController:Start()
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui

	-- ===== The badge: gold pill right of the coin counter =====
	-- Phones: the visible pill is 34 tall, the tap area 44 (HUD Kit)
	local badgeBlock = HudKit.Block(hud, { Name = "Multiplier", Button = true, Paint = "Gold", Radius = 22, Lip = 5 })
	local badge = badgeBlock.Holder :: TextButton
	local badgeText = HudKit.Text(badgeBlock.Face, "", HudKit.Num, 22, K.White, 2.5)
	badgeText.Name = "Total"
	local hit = Instance.new("TextButton")
	hit.Name = "HitArea"
	hit.Text = ""
	hit.BackgroundTransparency = 1
	hit.AnchorPoint = Vector2.new(0.5, 0.5)
	hit.Position = UDim2.fromScale(0.5, 0.5)
	hit.Size = UDim2.new(1, 0, 0, 44)
	hit:SetAttribute("OwnPress", true)
	hit.ZIndex = 10
	hit.Parent = badge
	HudKit.OnLayout(function(phone)
		local _, size = HudKit.Spot("Multiplier", phone)
		local h = (size :: UDim2).Y.Offset
		badgeBlock:SetRadius(h / 2)
		badgeBlock:SetLip(if phone then 4 else 5)
		badgeText.TextSize = if phone then 15 else 22
		badgeText.Size = UDim2.new(1, 0, 1, 0);
		(badgeText:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = if phone then 2 else 2.5
		hit.Visible = phone
	end)
	HudKit.Place(badge, "Multiplier")
	badge.Visible = Config.Ui.MultiplierBadge

	-- ===== The breakdown card =====
	-- The owner's UI Kit COIN MULTIPLIER card (claude.ai/design 'Strike Legends UI Kit', 2026-10-26; Modules/UiKit):
	-- computer 360 x 420 in the middle of the screen; phone 600 x 326, a bit right of centre (clear of the
	-- thumbstick) with the total and special throws on the left and the sources in a 2-column grid on the right.
	-- It grows out of the badge; the red X, the dark backdrop, Esc or B close it.
	local gui = Instance.new("ScreenGui")
	gui.Name = "MultiplierUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = hud.DisplayOrder + 5
	gui.IgnoreGuiInset = hud.IgnoreGuiInset
	gui.Parent = playerGui
	local screen = UiKit.Make("Frame", {
		Name = "Screen",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Active = true,
	}, gui) :: Frame
	local backdrop = UiKit.Backdrop(screen)
	local fitFrame = UiKit.Make("Frame", {
		Name = "Fit",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 2,
	}, screen) :: Frame
	local fitScale = UiKit.Make("UIScale", {}, fitFrame) :: UIScale
	local panel = UiKit.Make("Frame", {
		Name = "Panel",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Active = true, -- taps on the card don't fall through to the throw meter
	}, fitFrame) :: Frame
	local panelScale = UiKit.ScaleOf(panel)
	local bigTotal: TextLabel? = nil

	-- The 8 rows of the kit, in its order and colours. Sources the kit has no row for (coin potion, rebirths,
	-- friends) are added under them only while they count, so the total always matches the rows.
	local G = UiKit.Hex
	local CARD_ROWS = {
		{ Keys = { "PowerLevel" }, Name = "POWER LEVEL", Icon = "Power", Color = G("2BE4FF") },
		{ Keys = { "Ball" }, Name = "BALL", Icon = "Ball", Color = G("A98BFF") },
		{ Keys = { "Mascots" }, Name = "PETS", Icon = "Pets", Color = G("FF4FB0") },
		{ Keys = { "Rank" }, Name = "RANK", Icon = "Rank", Color = G("C58BFF") },
		{ Keys = { "Streak" }, Name = "STREAK", Icon = "Streak", Color = G("FF8A1F") },
		{ Keys = { "Zone" }, Name = "ZONE", Icon = "Zone", Color = G("7DFF3C") },
		{ Keys = { "Modifier" }, Name = "LANE EVENT", Icon = "LaneEvent", Color = G("FFFFFF") },
		{ Keys = { "Passes", "RobuxBoost" }, Name = "STORE BOOSTS", Icon = "StoreBoost", Color = G("FF4FB0") },
		{ Keys = { "Potion" }, Name = "COIN POTION", HudIcon = "PotionCoin", Color = G("FFC93A"), Extra = true },
		{ Keys = { "Rebirth" }, Name = "REBIRTHS", HudIcon = "Rebirth", Color = G("FFC93A"), Extra = true },
		{ Keys = { "Friends" }, Name = "FRIENDS", HudIcon = "GiftPink", Color = G("FFC93A"), Extra = true },
		{ Keys = { "Fever" }, Name = "FEVER", HudIcon = "Flame", Color = G("FF7A1A"), Extra = true },
	}
	local SPECIALS = {
		{ Name = "PERFECT", Icon = "Perfect", Value = 1 + Config.Rewards.PerfectStrikeBonus },
		{
			Name = "OVERCHARGE",
			Icon = "Overcharge",
			Value = if Config.Throw.Overcharge.Enabled then Config.Throw.Overcharge.CoinMultiplier else nil,
		},
		{ Name = "GOLDEN PIN", Icon = "GoldenPin", Value = Config.GoldenPin.CoinMultiplier },
	}

	local function rowIcon(parent: Instance, entry, size: number): ImageLabel
		if entry.HudIcon then
			return HudKit.Image(parent, entry.HudIcon, size)
		end
		return UiKit.Icon(parent, entry.Icon, size)
	end

	-- A frame laying its children out left to right
	local function line(parent: Instance, gap: number, align: Enum.HorizontalAlignment?): Frame
		local frame =
			UiKit.Make("Frame", { Name = "Line", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
		UiKit.Make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, gap),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, frame)
		return frame
	end

	-- One source row: icon, name, value (x40; pets too since batch C2: x2.2, not +120%)
	local function sourceRow(parent: Instance, entry, value: number, phone: boolean, order: number): Frame
		local frame = UiKit.Make("Frame", {
			Name = entry.Name,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 22),
		}, parent)
		local icon = rowIcon(frame, entry, if phone then 22 else 20)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.fromScale(0, 0.5)
		local name = UiKit.Text(frame, entry.Name, UiKit.Body, if phone then 11 else 13, UiKit.C.White, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Position = UDim2.fromOffset(if phone then 28 else 28, 0)
		name.Size = UDim2.new(1, -28 - (if phone then 52 else 70), 1, 0)
		-- Long names shrink to fit instead of being cut off
		name.TextScaled = true
		UiKit.Make("UITextSizeConstraint", { MaxTextSize = if phone then 11 else 13 }, name)
		local shown = format(value)
		local amount = UiKit.Text(
			frame,
			shown,
			UiKit.Num,
			if phone then 17 else 18,
			if value < 1 then UiKit.C.Red else entry.Color,
			2
		)
		amount.TextXAlignment = Enum.TextXAlignment.Right
		amount.AnchorPoint = Vector2.new(1, 0)
		amount.Position = UDim2.fromScale(1, 0)
		amount.Size = UDim2.new(0, if phone then 50 else 70, 1, 0)
		amount.TextScaled = true -- big values shrink to fit
		UiKit.Make("UITextSizeConstraint", { MaxTextSize = if phone then 17 else 18 }, amount)
		return frame
	end

	-- Rows fade in and slide 12 px from the left, 0.04 s apart (kit animation notes)
	local function revealRows(frames: { Frame })
		for i, frame in frames do
			local parts = frame:GetDescendants()
			for _, part in parts do
				if part:IsA("TextLabel") then
					part.TextTransparency = 1
				elseif part:IsA("ImageLabel") then
					part.ImageTransparency = 1
				elseif part:IsA("UIStroke") then
					part.Transparency = 1
				end
			end
			local inner = frame:GetChildren()
			for _, child in inner do
				if child:IsA("GuiObject") then
					child.Position -= UDim2.fromOffset(12, 0)
				end
			end
			task.delay((i - 1) * 0.04, function()
				for _, part in parts do
					local goal = if part:IsA("TextLabel")
						then { TextTransparency = 0 }
						elseif part:IsA("ImageLabel") then { ImageTransparency = 0 }
						elseif part:IsA("UIStroke") then { Transparency = 0 }
						else nil
					if goal then
						UiKit.Tween(part, 0.12, Enum.EasingStyle.Quad, goal)
					end
				end
				for _, child in inner do
					if child:IsA("GuiObject") then
						UiKit.Tween(
							child,
							0.12,
							Enum.EasingStyle.Quad,
							{ Position = child.Position + UDim2.fromOffset(12, 0) }
						)
					end
				end
			end)
		end
	end

	local currentTotal: number? = nil
	local function build(animate: boolean)
		for _, child in panel:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local phone = UiKit.Phone(gui)
		local K2 = UiKit.C
		local values = decode(player:GetAttribute("CoinMultipliers"))
		local entries = {}
		for _, entry in CARD_ROWS do
			local value = 1
			for _, key in entry.Keys do
				value *= values[key] or 1
			end
			if not entry.Extra or math.abs(value - 1) > 1e-6 then
				table.insert(entries, { Entry = entry, Value = value })
			end
		end
		local specials = {}
		for _, special in SPECIALS do
			if special.Value then
				table.insert(specials, special)
			end
		end
		local totalText = format(currentTotal or 1)
		local rowFrames = {}

		local w, h
		local cover, close
		if phone then
			w, h = 600, 326
			cover = UiKit.Block(panel, {
				Name = "Card",
				Size = Vector2.new(w, h),
				Fill = K2.Cover,
				Lip = K2.Ink,
				LipPx = 6,
				Radius = 22,
				Outline = 4,
			}).Holder
			local title = UiKit.Text(cover, "COIN MULTIPLIER", UiKit.Head, 26, K2.Gold, 3)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Position = UDim2.fromOffset(14, 12)
			title.Size = UDim2.fromOffset(w - 90, 44)
			close = UiKit.CloseX(cover, 48)
			close.Position = UDim2.fromOffset(w - 14 - 24, 10 + 22)
			local bodyY = 10 + 44 + 8
			local bodyH = h - bodyY - 14
			-- Left column: total, then the special throws
			local totalBox = UiKit.Block(
				cover,
				{ Name = "Total", Size = Vector2.new(200, 84), Fill = K2.Card, Lip = K2.Page, LipPx = 5, Radius = 14 }
			).Holder
			totalBox.Position = UDim2.fromOffset(14, bodyY)
			local word = UiKit.Text(totalBox, "TOTAL", UiKit.Head, 14, K2.White, 2)
			word.Position = UDim2.fromOffset(0, 12)
			word.Size = UDim2.new(1, 0, 0, 16)
			local value = UiKit.Text(totalBox, totalText, UiKit.Num, 42, K2.Gold, 4)
			value.Name = "Value"
			value.Position = UDim2.fromOffset(0, 30)
			value.Size = UDim2.new(1, 0, 0, 44)
			bigTotal = value
			local special = UiKit.Text(cover, "ON SPECIAL THROWS", UiKit.Head, 14, K2.Pink, 2)
			special.TextXAlignment = Enum.TextXAlignment.Left
			special.Position = UDim2.fromOffset(14, bodyY + 84 + 8)
			special.Size = UDim2.fromOffset(200, 16)
			for i, s in specials do
				local chipBox = UiKit.Box(cover, s.Name, K2.Card, 10)
				UiKit.Place(chipBox, 14, bodyY + 84 + 8 + 16 + 8 + (i - 1) * 42, 200, 34)
				local l = line(chipBox, 6)
				UiKit.Make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, l)
				UiKit.Icon(l, s.Icon, 22).LayoutOrder = 1
				local n = UiKit.Text(l, s.Name, UiKit.Body, 11, K2.White, 0)
				n.TextXAlignment = Enum.TextXAlignment.Left
				n.Size = UDim2.new(1, -28 - 50, 1, 0)
				n.LayoutOrder = 2
				local v = UiKit.Text(l, format(s.Value), UiKit.Num, 16, K2.Gold, 2)
				v.TextXAlignment = Enum.TextXAlignment.Right
				v.Size = UDim2.new(0, 44, 1, 0)
				v.LayoutOrder = 3
			end
			-- Right: the sources, two columns
			local listX = 14 + 200 + 10
			local list = UiKit.Box(cover, "Sources", K2.Page, 14)
			UiKit.Place(list, listX, bodyY, w - 14 - listX, bodyH)
			local grid = UiKit.Make("Frame", {
				Name = "Grid",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(9, 5),
				Size = UDim2.new(1, -18, 1, -10),
			}, list)
			local rowsTall = math.ceil(#entries / 2)
			local cellH = (bodyH - 6 - 10) / math.max(rowsTall, 4)
			UiKit.Make("UIGridLayout", {
				CellSize = UDim2.new(0.5, -7, 0, cellH),
				CellPadding = UDim2.fromOffset(14, 0),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, grid)
			for i, item in entries do
				local cell = sourceRow(grid, item.Entry, item.Value, true, i)
				local rule = UiKit.Make("Frame", {
					Name = "Rule",
					BackgroundColor3 = G("2A1E55"),
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 1),
				}, cell)
				rule.ZIndex = 0
				table.insert(rowFrames, cell)
			end
		else
			-- Computer: title, total box, the list, then ON SPECIAL THROWS chips in a row
			local listH = 6 * 2 + #entries * 22 + (#entries - 1) * 1 + 6
			w, h = 360, 14 + 29 + 8 + 62 + 8 + listH + 8 + 16 + 8 + 46 + 18
			cover = UiKit.Block(panel, {
				Name = "Card",
				Size = Vector2.new(w, h),
				Fill = K2.Cover,
				Lip = K2.Ink,
				LipPx = 8,
				Radius = 26,
				Outline = 4,
			}).Holder
			local title = UiKit.Text(cover, "COIN MULTIPLIER", UiKit.Head, 28, K2.Gold, 3.5)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.Position = UDim2.fromOffset(16, 14 + 4)
			title.Size = UDim2.fromOffset(w - 32, 29)
			close = UiKit.CloseX(cover, 52)
			close.Position = UDim2.fromOffset(w + 18 - 26, -18 + 26)
			close.ZIndex = 6
			local y = 14 + 29 + 8
			local totalBox = UiKit.Block(cover, {
				Name = "Total",
				Size = Vector2.new(w - 32, 62),
				Fill = K2.Card,
				Lip = K2.Page,
				LipPx = 5,
				Radius = 16,
			}).Holder
			totalBox.Position = UDim2.fromOffset(16, y)
			local word = UiKit.Text(totalBox, "TOTAL", UiKit.Head, 18, K2.White, 2)
			word.TextXAlignment = Enum.TextXAlignment.Left
			word.Position = UDim2.fromOffset(16, 3)
			word.Size = UDim2.new(0, 80, 1, -5)
			local value = UiKit.Text(totalBox, totalText, UiKit.Num, 46, K2.Gold, 4)
			value.Name = "Value"
			value.TextXAlignment = Enum.TextXAlignment.Right
			value.AnchorPoint = Vector2.new(1, 0)
			value.Position = UDim2.new(1, -16, 0, 0)
			value.Size = UDim2.new(0, 220, 1, -5)
			bigTotal = value
			y += 62 + 8
			local list = UiKit.Box(cover, "Sources", K2.Page, 14)
			UiKit.Place(list, 16, y, w - 32, listH)
			local stack = UiKit.Make("Frame", {
				Name = "Rows",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(9, 3),
				Size = UDim2.new(1, -18, 1, -6),
			}, list)
			UiKit.Make("UIListLayout", {
				Padding = UDim.new(0, 1),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}, stack)
			for i, item in entries do
				table.insert(rowFrames, sourceRow(stack, item.Entry, item.Value, false, i))
			end
			y += listH + 8
			local special = UiKit.Text(cover, "ON SPECIAL THROWS", UiKit.Head, 16, K2.Pink, 2)
			special.TextXAlignment = Enum.TextXAlignment.Left
			special.Position = UDim2.fromOffset(16, y + 2)
			special.Size = UDim2.fromOffset(w - 32, 16)
			y += 16 + 8
			local chipW = (w - 32 - 6 * (#specials - 1)) / #specials
			for i, s in specials do
				local chipBox = UiKit.Box(cover, s.Name, K2.Card, 12)
				UiKit.Place(chipBox, 16 + (i - 1) * (chipW + 6), y, chipW, 46)
				local icon = UiKit.Icon(chipBox, s.Icon, 26)
				icon.AnchorPoint = Vector2.new(0, 0.5)
				icon.Position = UDim2.new(0, 3, 0.5, 0)
				local n = UiKit.Text(chipBox, s.Name, UiKit.Body, 9, K2.Label, 0)
				n.TextXAlignment = Enum.TextXAlignment.Left
				n.Position = UDim2.fromOffset(34, 5)
				n.Size = UDim2.new(1, -36, 0, 12)
				n.TextScaled = true -- OVERCHARGE is a tight fit
				UiKit.Make("UITextSizeConstraint", { MaxTextSize = 9 }, n)
				local v = UiKit.Text(chipBox, format(s.Value), UiKit.Num, 17, K2.Gold, 2)
				v.TextXAlignment = Enum.TextXAlignment.Left
				v.Position = UDim2.fromOffset(34, 17)
				v.Size = UDim2.new(1, -36, 0, 18)
			end
		end
		close.Activated:Connect(function()
			MultiplierController.SetOpen(false)
		end)

		-- Size on this screen: design size, shrunk to fit; phones sit 78 px right of centre (thumbstick)
		fitFrame.Size = UDim2.fromOffset(w, h)
		local area = gui.AbsoluteSize
		fitScale.Scale = math.max(
			0.3,
			if phone
				then math.min(1, (area.X - 16) / w, (area.Y - 8) / h)
				else math.min(1, (area.X - 40) / (w + 36), (area.Y - 40) / (h + 18))
		)
		local nudge = if phone then math.min(78, math.max(0, (area.X - w * fitScale.Scale) / 2 - 8)) else 0
		fitFrame:SetAttribute("Rest", UDim2.new(0.5, nudge, 0.5, 0))
		if animate then
			revealRows(rowFrames)
			-- The total number pops in
			local s = UiKit.ScaleOf(bigTotal :: TextLabel)
			s.Scale = 1.25
			UiKit.Tween(s, 0.25, Enum.EasingStyle.Back, { Scale = 1 })
		end
	end

	-- Fill in, and tick the total when it changes
	local shownTotal = Instance.new("NumberValue")
	local badgeScale = badgeBlock.Scale
	shownTotal.Changed:Connect(function(value)
		badgeText.Text = format(value)
		if bigTotal and bigTotal.Parent then
			bigTotal.Text = format(value)
		end
	end)
	local function refresh()
		local values = decode(player:GetAttribute("CoinMultipliers"))
		local total = 1
		for _, source in SOURCES do
			total *= values[source.Key] or 1
		end
		if currentTotal == nil then
			currentTotal = total
			shownTotal.Value = total
			badgeText.Text = format(total)
		elseif math.abs(total - currentTotal) > 1e-6 then
			local before = currentTotal
			currentTotal = total
			if screen.Visible then
				build(false)
				if bigTotal then
					bigTotal.Text = format(before)
				end
			end
			TweenService:Create(shownTotal, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Value = total,
			}):Play()
			-- Value changes: UIScale 1 -> 1.15 (0.1 s) -> 1 (0.2 s Back Out)
			bounce(badgeScale, 1.15, 0.1, 0.2)
			if screen.Visible and bigTotal then
				UiFx.Pop(bigTotal, 1.3, 0.35)
			end
		elseif screen.Visible then
			build(false)
		end
	end
	player:GetAttributeChangedSignal("CoinMultipliers"):Connect(refresh)
	refresh()

	-- Opens out of the badge: starts on it at UIScale 0.3 and moves to its spot while growing to full size
	-- (0.2 Back Out / 0.2 Quad Out); the backdrop fades in. Closes like the book (UiKit.Close).
	function MultiplierController.SetOpen(open: boolean)
		if open then
			build(true)
			local rest = fitFrame:GetAttribute("Rest") :: UDim2
			local from = badge.AbsolutePosition + badge.AbsoluteSize / 2 - gui.AbsolutePosition
			screen.Visible = true
			backdrop.BackgroundTransparency = 1
			UiKit.Tween(backdrop, 0.15, Enum.EasingStyle.Linear, { BackgroundTransparency = 0.38 })
			fitFrame.Position = UDim2.fromOffset(from.X, from.Y)
			UiKit.Tween(fitFrame, 0.2, Enum.EasingStyle.Quad, { Position = rest })
			panelScale.Scale = 0.3
			UiKit.Tween(panelScale, 0.2, Enum.EasingStyle.Back, { Scale = 1 })
		else
			UiKit.Close(screen, backdrop, panelScale)
		end
	end
	local setOpen = MultiplierController.SetOpen
	local function toggle()
		setOpen(not screen.Visible)
	end
	badge.Activated:Connect(toggle)
	hit.Activated:Connect(toggle)
	backdrop.Activated:Connect(function()
		setOpen(false)
	end)
	UiKit.CloseKeys(screen, function()
		setOpen(false)
	end)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if screen.Visible then
			build(false)
			fitFrame.Position = fitFrame:GetAttribute("Rest") :: UDim2
		end
	end)

	-- Auto Bowl (Config.AutoBowl): for everyone when switched on, or with the AUTO BOWL game pass while the store is
	-- on (Config.Monetization); the server makes the remote only then. It sits under the badge.
	if Config.AutoBowl.Enabled or Store.Active() then
		local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("SetAutoBowl", 10) :: RemoteEvent?
		if remote then
			local auto = Instance.new("TextButton")
			auto.Name = "AutoBowl"
			auto.Text = ""
			auto.AutoButtonColor = false
			auto.BackgroundColor3 = CARD
			auto.Parent = hud
			corner(auto, 10)
			stroke(auto, LIME, 2, true)
			local label = text(auto, "Label", FONT, LIME)
			label.Position = UDim2.fromScale(0.08, 0.15)
			label.Size = UDim2.fromScale(0.84, 0.7)
			HudKit.OnLayout(function(phone)
				local position, size = HudKit.Spot("Multiplier", phone)
				local h = (size :: UDim2).Y.Offset
				auto.Position = position + UDim2.fromOffset(0, h + 6)
				auto.Size = UDim2.fromOffset((size :: UDim2).X.Offset, math.floor(h * 0.8))
			end)
			local function show()
				auto.Visible = Config.AutoBowl.Enabled or Store.Owns(player, "AutoBowl")
				local on = player:GetAttribute("AutoBowl") == true
				label.Text = if on then "AUTO ON" else "AUTO"
				auto.BackgroundColor3 = if on then Color3.fromRGB(40, 90, 30) else CARD
			end
			player:GetAttributeChangedSignal("AutoBowl"):Connect(show)
			player:GetAttributeChangedSignal("Passes"):Connect(show)
			show()
			auto.Activated:Connect(function()
				remote:FireServer(player:GetAttribute("AutoBowl") ~= true)
			end)
			UiFx.Press(auto)
		end
	end
end

return MultiplierController
