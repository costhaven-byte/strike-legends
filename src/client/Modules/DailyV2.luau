-- UI overhaul V8 (UI_OVERHAUL_PLAN.md): the DAILY REWARDS window in the owner's new look ('Strike Legends - Daily
-- Reward.html' 1A desktop, 1B phone, components, motion), built on Modules/SlKit. Config.Ui.DailyV2 switches it on.
-- Gold plate with the gift + DAILY REWARDS, red X. Days 1-6 in two rows of 3 tiles, day 7 the big gold tile on the
-- right, CLAIM under them. A tile: flat category colour (coin gold / gem pink / potion green) with hard white rays and
-- the reward icon, the amount on a navy foot, DAY chip on top. States: CLAIMED = faded + green tick, TODAY = green foot +
-- lime glow ring + bounce, LOCKED = dark art + padlock. Days that give more than one thing show the rest as small chips
-- (not in the design: the game's days mix coins + gems, potions + potions). Day 7: rays turning, two sparkles, the
-- reward in 3D (egg / crate) or the big coin pile (core loop: day 7 pays coins), its name, padlock + DAY 7 foot.
-- CLAIM turns into the blue countdown (clock + 18:22:05) once today's is claimed; the icon flies to the HUD counter.
-- DailyRewardController keeps the remote, the HUD button and the join popup; the old window stays for DailyV2 = false.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Calendar = require(Shared.Modules.Calendar)
local Balls = require(Shared.Modules.Balls)
local HudKit = require(script.Parent.HudKit)
local MascotView = require(script.Parent.MascotView)
local PetsV2 = require(script.Parent.PetsV2)
local RewardKit = require(script.Parent.RewardKit)
local SlKit = require(script.Parent.SlKit)
local Motion = require(script.Parent:WaitForChild("Motion"))
local Sfx = require(script.Parent.Sfx)

local player = Players.LocalPlayer
local make = SlKit.Make
local hex = Color3.fromHex
local INK = SlKit.C.Ink
local WHITE = SlKit.C.White
local NIGHT = hex("0A1A40")

local DailyV2 = {}

-- The design's numbers: desktop 1A (1920 x 1080) and phone 1B (844 x 390)
local DESK = {
	W = 1060, H = 742, Lip = 8, Strip = 4, Radius = 16,
	Plate = 68, PlateY = -37, Title = 44, PlateIcon = 60, Close = 64, CloseX = 18, CloseY = -22,
	GridX = 41, GridY = 76, TileW = 200, TileH = 230, Gap = 24, ArtH = 138, Icon = 104, IconDrop = 12,
	Amount = 32, Tick = 92, Lock = 72, ChipH = 36, Chip = 18, Extra = 30,
	Day7W = 300, Day7H = 484, Slot = 220, SlotX = 40, SlotY = 64, NameY = 308, Name = 32, FootH = 110, FootLock = 52,
	Sparkles = { { 12, 30, 56 }, { 242, 244, 44 } },
	BtnW = 420, BtnH = 100, BtnY = 604, BtnLip = 6, BtnText = 32, Clock = 52, Glow = 12, GlowPx = 6,
}
local PHONE = {
	W = 636, H = 306, Lip = 5, Strip = 3, Radius = 12,
	Plate = 40, PlateY = -22, Title = 26, PlateIcon = 0, Close = 44, CloseX = 12, CloseY = -16,
	GridX = 77, GridY = 30, TileW = 100, TileH = 96, Gap = 8, ArtH = 58, Icon = 46, IconDrop = 0,
	Amount = 18, Tick = 44, Lock = 36, ChipH = 0, Chip = 12, Extra = 15,
	Day7W = 150, Day7H = 200, Slot = 104, SlotX = 23, SlotY = 14, NameY = 122, Name = 18, FootH = 44, FootLock = 26,
	Sparkles = { { 4, 10, 28 }, { 118, 100, 22 } },
	BtnW = 240, BtnH = 50, BtnY = 240, BtnLip = 4, BtnText = 22, Clock = 30, Glow = 6, GlowPx = 4,
}

-- Category colours (design: coin #FFC93A, gem #FF4FA3, potion #4BE07A; egg / crate are not in the design)
local ART = {
	Coins = hex("FFC93A"),
	Gems = hex("FF4FA3"),
	Potion = hex("4BE07A"),
	Egg = hex("3AA8FF"),
	Crate = hex("3AA8FF"),
}
local FOOT = { Claimed = hex("22477A"), Today = hex("3CCB3F"), Locked = hex("0E2442") }
local GOLD = hex("FFC93A")
local GOLD_LIP = hex("E59A00")
local GOLD_STRIP = hex("FFE69A")
local GLOW = hex("B6FF7A")
local PAINT = {
	Window = { hex("17345C"), hex("0C2240"), hex("2B5A94") },
	Plate = { GOLD, GOLD_LIP, GOLD_STRIP },
	Claim = { hex("3CCB3F"), hex("1F8F27"), hex("8EEB90") },
	Wait = { hex("22477A"), hex("0E2442"), hex("3A66A3") },
	Red = { hex("FF3B4E"), hex("B81E30"), hex("FF8A95") },
	Pink = { hex("FF4FA3"), hex("C42A78"), hex("FF9BCB") },
}
local POTION_ICON = {
	CoinSmall = "potion_coin",
	CoinBig = "potion_coin_mega",
	XpSmall = "potion_xp",
	XpBig = "potion_xp_mega",
}

local function corner(parent: Instance, radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent: Instance, color: Color3, thickness: number): UIStroke
	return make("UIStroke", {
		Color = color,
		Thickness = thickness,
		LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function label(parent: Instance, words: string, size: number, props: { [string]: any }?): TextLabel
	local t = SlKit.Text(parent, words, size, WHITE, props)
	if size > SlKit.T.Label then
		-- (the design's 5 px ink stroke painted under the fill = ~2.5 px showing; big titles a bit more)
		(t:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = if size >= 40 then 3 else 2.5
	end
	return t
end

-- 18:22:05
local function clock(seconds: number): string
	seconds = math.max(math.floor(seconds), 0)
	return ("%02d:%02d:%02d"):format(seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

local function potionName(id: string): string
	for _, potion in Config.Potions.List do
		if potion.Id == id then
			return potion.Name
		end
	end
	return id
end

-- What a day shows: the main thing (category, icon, amount text) + the rest as small chips { icon, text }
type Shown = { Kind: string, Icon: string?, Value: any, Amount: string, Name: string, Extras: { { string } } }
local function describe(reward): Shown
	local items: { { any } } = {} -- { kind, icon, value, amount, name }
	if reward.Crate and Balls.GetCrate(reward.Crate) then
		local crate = Balls.GetCrate(reward.Crate)
		table.insert(items, { "Crate", "hud_gifts", reward.Crate, "x1", string.upper(crate.Name) })
	end
	if reward.Egg then
		local look = Config.EggLooks[reward.Egg]
		table.insert(items, { "Egg", "hud_pets", reward.Egg, "FREE", string.upper(if look then look.Name else "EGG") })
	end
	if reward.Coins then
		local amount = Currency.Format(reward.Coins)
		table.insert(items, { "Coins", "cur_coins_medium", nil, amount, amount .. " COINS" })
	end
	for _, item in reward.Potions or {} do
		table.insert(items, {
			"Potion",
			POTION_ICON[item.Id] or "potion_coin",
			item.Id,
			"x" .. item.Count,
			(if item.Count > 1 then item.Count .. "x " else "") .. string.upper(potionName(item.Id)),
		})
	end
	if reward.Gems then
		table.insert(items, { "Gems", "cur_gem", nil, Currency.Format(reward.Gems), reward.Gems .. " GEMS" })
	end
	local main = items[1] or { "Coins", "cur_coins_medium", nil, "?", "?" }
	local extras = {}
	for i = 2, #items do
		local item = items[i]
		table.insert(extras, { item[2], if item[1] == "Gems" then "+" .. item[4] else item[4] })
	end
	return { Kind = main[1], Icon = main[2], Value = main[3], Amount = main[4], Name = main[5], Extras = extras }
end

local function signature(shown: Shown): string
	local parts = { shown.Kind, tostring(shown.Value), shown.Amount, shown.Name }
	for _, extra in shown.Extras do
		table.insert(parts, extra[1] .. extra[2])
	end
	return table.concat(parts, "|")
end

-- ctx: Resolve(day) -> reward, Claim() (the controller asks the server), OnClose()
function DailyV2.Start(ctx: { [string]: any })
	local playerGui = player:WaitForChild("PlayerGui")
	local days = #Config.Daily.Rewards

	local gui = make("ScreenGui", {
		Name = "DailyV2UI",
		ResetOnSpawn = false,
		DisplayOrder = 21,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local backdrop = make("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = NIGHT,
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, gui)
	local fit = make("Frame", {
		Name = "Daily",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.fromOffset(DESK.W, DESK.H + DESK.Lip),
	}, gui)
	local fitScale = make("UIScale", { Name = "Fit" }, fit)
	local win = make("Frame", { Name = "Window", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, fit)
	local openScale = make("UIScale", { Name = "OpenScale" }, win)
	win.Visible = false

	local open = false
	local phone: boolean? = nil
	local L = DESK
	local gen = 0 -- bumps on every rebuild / close: running loops stop
	local errorText: string? = nil
	local noteText: string? = nil
	local celebrating = false
	local celebratingDay = 0
	local plateBase = UDim2.new()

	-- Built by build(); refresh() paints them
	type Tile = {
		Holder: Frame,
		Bob: Frame,
		Card: CanvasGroup,
		Art: Frame,
		Icon: GuiObject,
		Shade: Frame,
		Foot: Frame,
		Amount: TextLabel,
		Tick: ImageLabel,
		Lock: ImageLabel,
		Glow: Frame,
		Big: boolean,
		State: string,
		Shown: Shown?,
		Extras: Frame?,
		Name: TextLabel?,
		FootRow: Frame?,
		FootText: TextLabel?,
		FootLock: ImageLabel?,
		Slot: Frame?,
	}
	local tiles: { Tile } = {}
	local plate: SlKit.Block
	local button: SlKit.Button
	local buttonGlow: Frame
	local buttonClock: ImageLabel

	-- Lime ring round the TODAY tile and CLAIM: transparency 0.5 <-> 0 + scale 1 -> 1.04, 1 s
	local function glowRing(parent: Instance, w: number, h: number, radius: number): Frame
		local ring = make("Frame", {
			Name = "Glow",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(w / 2, h / 2),
			Size = UDim2.fromOffset(w + 2 * L.Glow - L.GlowPx, h + 2 * L.Glow - L.GlowPx),
			Visible = false,
			ZIndex = 1,
		}, parent)
		corner(ring, radius + L.Glow)
		local line = stroke(ring, GLOW, L.GlowPx)
		line.Transparency = 0.5
		local info = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		TweenService:Create(line, info, { Transparency = 0 }):Play()
		TweenService:Create(make("UIScale", {}, ring), info, { Scale = 1.04 }):Play()
		return ring
	end

	-- TODAY bounce: y 0 -> -8 -> 0 + scale 1 -> 1.04 -> 0.98 -> 1, 0.9 s loop (soft)
	local function bounce(object: GuiObject, isOn: () -> boolean)
		local myGen = gen
		local scale = SlKit.ScaleOf(object)
		task.spawn(function()
			while gen == myGen and object.Parent do
				if isOn() then
					SlKit.Tween(object, 0.36, "Soft", { Position = UDim2.fromOffset(0, -8) })
					SlKit.Tween(scale, 0.36, "Soft", { Scale = 1.04 })
					task.wait(0.36)
					SlKit.Tween(object, 0.18, "Soft", { Position = UDim2.fromOffset(0, 0) })
					SlKit.Tween(scale, 0.18, "Soft", { Scale = 0.98 })
					task.wait(0.18)
					SlKit.Tween(scale, 0.36, "Soft", { Scale = 1 })
					task.wait(0.36)
				else
					object.Position = UDim2.fromOffset(0, 0)
					scale.Scale = 1
					task.wait(0.25)
				end
			end
		end)
	end

	-- Small navy chips for a day's other rewards (icon + amount)
	local function extrasRow(parent: Instance, extras: { { string } }, height: number, align: Enum.HorizontalAlignment)
		local row = make("Frame", {
			Name = "Extras",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, height),
			ZIndex = 8,
		}, parent)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = align,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, row)
		for i, extra in extras do
			local chip = make("Frame", {
				Name = "Chip",
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = FOOT.Locked,
				BackgroundTransparency = 0.15,
				Size = UDim2.fromOffset(0, height),
				LayoutOrder = i,
				ZIndex = 8,
			}, row)
			corner(chip, height // 2)
			stroke(chip, INK, 2)
			make("UIPadding", {
				PaddingLeft = UDim.new(0, 2),
				PaddingRight = UDim.new(0, math.max(height // 4, 4)),
			}, chip)
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 2),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, chip)
			SlKit.Image(chip, extra[1], height - 2, { LayoutOrder = 1, ZIndex = 9 })
			label(chip, extra[2], math.max(math.floor(height * 0.6), 11), {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = 2,
				ZIndex = 9,
			})
		end
		return row
	end

	-- The art zone's picture: flat colour, white rays, icon
	local function paintArt(t: Tile, shown: Shown)
		t.Art.BackgroundColor3 = ART[shown.Kind] or ART.Coins
		local icon = t.Icon :: ImageLabel
		icon.Image = SlKit.Icon(shown.Icon or "cur_coins_medium")
		t.Amount.Text = shown.Amount
		if t.Extras then
			t.Extras:Destroy()
			t.Extras = nil
		end
		if #shown.Extras > 0 then
			local row = extrasRow(t.Art, shown.Extras, L.Extra, Enum.HorizontalAlignment.Right)
			row.AnchorPoint = Vector2.new(1, 1)
			row.Position = UDim2.new(1, -4, 1, -4)
			row.Size = UDim2.new(1, -8, 0, L.Extra)
			t.Extras = row
		end
	end

	-- Day 7's slot: the egg / crate in 3D, else the big coin pile (or the main icon)
	local function paintBig(t: Tile, shown: Shown)
		local slot = t.Slot :: Frame
		for _, child in slot:GetChildren() do
			child:Destroy()
		end
		if shown.Kind == "Egg" then
			MascotView.Viewport(slot, MascotView.Egg(shown.Value, 4), 0.9)
		elseif shown.Kind == "Crate" then
			RewardKit.Crate(slot, shown.Value)
		else
			local icon = if shown.Kind == "Coins" then "cur_coins_big" elseif shown.Kind == "Gems" then "cur_gem_pile" else shown.Icon
			SlKit.Image(slot, icon or "cur_coins_big", math.floor(L.Slot * 0.92), {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				ZIndex = 7,
			})
		end
		;(t.Name :: TextLabel).Text = shown.Name
		if t.Extras then
			t.Extras:Destroy()
			t.Extras = nil
		end
		if #shown.Extras > 0 then
			local row = extrasRow(t.Bob, shown.Extras, L.Extra, Enum.HorizontalAlignment.Center)
			row.Position = UDim2.fromOffset(0, L.NameY + L.Name + (if phone then 1 else 6))
			row.Size = UDim2.new(1, 0, 0, L.Extra)
			t.Extras = row
		end
	end

	local function makeTile(parent: Instance, day: number, x: number, y: number): Tile
		local big = day == days
		local w, h = if big then L.Day7W else L.TileW, if big then L.Day7H else L.TileH
		local holder = make("Frame", {
			Name = "Day" .. day,
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			ZIndex = 2,
		}, parent)
		local glow = glowRing(holder, w, h, L.Radius)
		local bob = make("Frame", { Name = "Bob", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, holder)
		-- The card fades as one piece when claimed (CanvasGroup also rounds the art's corners)
		local card = make("CanvasGroup", {
			Name = "Card",
			BackgroundColor3 = if big then GOLD_LIP else FOOT.Claimed,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
		}, bob)
		corner(card, L.Radius)
		local artH = if big then h - L.FootH else L.ArtH
		local art = make("Frame", {
			Name = "Art",
			BackgroundColor3 = GOLD,
			BorderSizePixel = 0,
			ClipsDescendants = true,
			Size = UDim2.new(1, 0, 0, artH),
			ZIndex = 3,
		}, card)
		-- hard white rays (design: rgba(255,255,255,.22) tiles, .3 on day 7, centre 55% / 36% down)
		local raySize = math.max(w, artH) * 2.2
		local rays = make("ImageLabel", {
			Name = "Rays",
			BackgroundTransparency = 1,
			Image = SlKit.Icon("bg_rays"),
			ImageColor3 = WHITE,
			ImageTransparency = if big then 0.7 else 0.78,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, if big then h * 0.36 else artH * 0.55),
			Size = UDim2.fromOffset(raySize, raySize),
			ZIndex = 3,
		}, art)
		if big then
			SlKit.Spin(rays, 12)
			-- top line #FFE69A
			make("Frame", {
				Name = "Strip",
				BackgroundColor3 = GOLD_STRIP,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, L.Strip),
				ZIndex = 4,
			}, art)
		end
		-- 3 px ink line over the foot
		make("Frame", {
			Name = "Line",
			BackgroundColor3 = INK,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, artH),
			Size = UDim2.new(1, 0, 0, 3),
			ZIndex = 4,
		}, card)
		local foot = make("Frame", {
			Name = "Foot",
			BackgroundColor3 = if big then GOLD_LIP else FOOT.Claimed,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, artH + 3),
			Size = UDim2.new(1, 0, 1, -artH - 3),
			ZIndex = 3,
		}, card)
		local amount = label(foot, "", L.Amount, { ZIndex = 5 })
		local icon = SlKit.Image(art, "cur_coins_medium", L.Icon, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, L.IconDrop / 2),
			ZIndex = 5,
		})
		-- LOCKED: art at 40% brightness
		local shade = make("Frame", {
			Name = "Shade",
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Visible = false,
			ZIndex = 10,
		}, art)
		-- the outline sits on top of the card (outside the CanvasGroup so it never fades)
		local edge = make("Frame", {
			Name = "Edge",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 9,
		}, bob)
		corner(edge, L.Radius)
		stroke(edge, INK, 3)
		local markY = (if big then L.SlotY + L.Slot / 2 else artH / 2 + L.IconDrop / 2)
		local tick = SlKit.Image(bob, "ui_tick", if big then L.Tick * 1.4 else L.Tick, {
			Name = "Tick",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, markY),
			Visible = false,
			ZIndex = 12,
		})
		local lock = SlKit.Image(bob, "ui_lock", L.Lock, {
			Name = "Lock",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0, markY),
			Visible = false,
			ZIndex = 12,
		})
		local t: Tile = {
			Holder = holder,
			Bob = bob,
			Card = card,
			Art = art,
			Icon = icon,
			Shade = shade,
			Foot = foot,
			Amount = amount,
			Tick = tick,
			Lock = lock,
			Glow = glow,
			Big = big,
			State = "",
		}
		if big then
			icon.Visible = false
			lock.Visible = false
			-- the 3D slot + sparkles + name; padlock + DAY 7 on the foot
			t.Slot = make("Frame", {
				Name = "Slot",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(L.SlotX, L.SlotY),
				Size = UDim2.fromOffset(L.Slot, L.Slot),
				ZIndex = 6,
			}, bob)
			for i, s in L.Sparkles do
				local sparkle = SlKit.Image(bob, "ui_sparkle", s[3], {
					Name = "Sparkle",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(s[1] + s[3] / 2, s[2] + s[3] / 2),
					ZIndex = 8,
				})
				-- scale 0.6 <-> 1 + transparency, 1.4 s, the second 0.7 s later
				local scale = SlKit.ScaleOf(sparkle)
				scale.Scale = 0.6
				sparkle.ImageTransparency = 0.4
				task.delay((i - 1) * 0.7, function()
					local info = TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
					TweenService:Create(scale, info, { Scale = 1 }):Play()
					TweenService:Create(sparkle, info, { ImageTransparency = 0 }):Play()
				end)
			end
			t.Name = label(bob, "", L.Name, {
				Name = "RewardName",
				Position = UDim2.fromOffset(6, L.NameY),
				Size = UDim2.new(1, -12, 0, L.Name + 4),
				TextScaled = true,
				ZIndex = 8,
			})
			make("UITextSizeConstraint", { MaxTextSize = L.Name }, t.Name)
			amount.Visible = false
			local row = make("Frame", { Name = "FootRow", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, foot)
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, if phone then 4 else 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}, row)
			t.FootLock = SlKit.Image(row, "ui_lock", L.FootLock, { LayoutOrder = 1, ZIndex = 6 })
			t.FootText = label(row, "DAY " .. day, L.Amount, {
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromScale(0, 1),
				LayoutOrder = 2,
				ZIndex = 6,
			})
			t.FootRow = row
		elseif L.ChipH > 0 then
			-- gold DAY chip hanging over the top edge (h36, r18, lip 3)
			local width = TextService:GetTextSize("DAY " .. day, L.Chip, Enum.Font.FredokaOne, Vector2.new(999, 99)).X + 28 + 6
			local chip = make("Frame", {
				Name = "DayChip",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = GOLD_LIP,
				Position = UDim2.new(0.5, 0, 0, -16),
				Size = UDim2.fromOffset(width, L.ChipH),
				ZIndex = 13,
			}, bob)
			corner(chip, L.ChipH / 2)
			stroke(chip, INK, 3)
			local face = make("Frame", {
				Name = "Face",
				BackgroundColor3 = GOLD,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 1, -3),
				ZIndex = 13,
			}, chip)
			corner(face, L.ChipH / 2 - 2)
			label(face, "DAY " .. day, L.Chip, { ZIndex = 14 })
		else
			-- phone: a small DAY n in the corner (12 px Builder Sans)
			SlKit.Text(bob, "DAY " .. day, L.Chip, WHITE, {
				Name = "DayText",
				Position = UDim2.fromOffset(5, 3),
				Size = UDim2.fromOffset(60, 14),
				TextXAlignment = Enum.TextXAlignment.Left,
				ZIndex = 13,
			})
		end
		bounce(bob, function()
			return t.State == "Today" and open
		end)
		return t
	end

	-- (Re)builds the whole window for the desktop or phone layout
	local function build()
		gen += 1
		for _, child in win:GetChildren() do
			if not child:IsA("UIScale") then
				child:Destroy()
			end
		end
		table.clear(tiles)
		L = if phone then PHONE else DESK
		fit.Size = UDim2.fromOffset(L.W, L.H + L.Lip)

		SlKit.Block(win, {
			Name = "Body",
			Size = UDim2.fromScale(1, 1),
			Radius = L.Radius,
			Paint = PAINT.Window,
			Lip = L.Lip,
			Strip = L.Strip,
		})
		-- Gold plate: gift + DAILY REWARDS (as wide as its title)
		local titleW = TextService:GetTextSize("DAILY REWARDS", L.Title, Enum.Font.FredokaOne, Vector2.new(9999, 99)).X
		local plateW = titleW + (if L.PlateIcon > 0 then 24 + L.PlateIcon + 14 + 48 else 48) + 6
		plate = SlKit.Block(win, {
			Name = "Plate",
			Size = UDim2.fromOffset(plateW, L.Plate + (if phone then 4 else 6)),
			Radius = L.Radius,
			Paint = PAINT.Plate,
			Lip = if phone then 4 else 6,
		})
		plate.Holder.AnchorPoint = Vector2.new(0.5, 0)
		plate.Holder.Position = UDim2.new(0.5, 0, 0, L.PlateY)
		plateBase = plate.Holder.Position
		plate.Holder.ZIndex = 20
		local plateRow = make("Frame", { Name = "Row", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, plate.Content)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, plateRow)
		if L.PlateIcon > 0 then
			SlKit.Image(plateRow, "hud_daily", L.PlateIcon, { LayoutOrder = 1, ZIndex = 9 })
		end
		label(plateRow, "DAILY REWARDS", L.Title, {
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			LayoutOrder = 2,
			ZIndex = 9,
		})
		local close = PetsV2.CloseButton(win, L.Close)
		close.Holder.AnchorPoint = Vector2.new(1, 0)
		close.Holder.Position = UDim2.new(1, L.CloseX, 0, L.CloseY)
		close.Holder.ZIndex = 20
		close.Holder.Activated:Connect(function()
			DailyV2.SetOpen(false)
		end)

		-- Days 1-6 in two rows of 3, day 7 on the right
		local area = make("Frame", { Name = "Days", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, win)
		local gapRight = if phone then 10 else L.Gap
		for day = 1, days do
			local x, y
			if day == days then
				x, y = L.GridX + 3 * L.TileW + 2 * L.Gap + gapRight, L.GridY
			else
				local col, row = (day - 1) % 3, (day - 1) // 3
				x, y = L.GridX + col * (L.TileW + L.Gap), L.GridY + row * (L.TileH + L.Gap)
			end
			tiles[day] = makeTile(area, day, x, y)
		end

		-- CLAIM (420 x 100, green, glow + bounce) -> countdown (blue, clock)
		local holder = make("Frame", {
			Name = "ClaimSpot",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset((L.W - L.BtnW) / 2, L.BtnY),
			Size = UDim2.fromOffset(L.BtnW, L.BtnH + L.BtnLip),
			ZIndex = 4,
		}, win)
		buttonGlow = glowRing(holder, L.BtnW, L.BtnH + L.BtnLip, L.Radius)
		button = SlKit.Button(holder, {
			Name = "Claim",
			Text = "CLAIM",
			Size = UDim2.fromOffset(L.BtnW, L.BtnH + L.BtnLip),
			Radius = if phone then 14 else 16,
			Paint = PAINT.Claim,
			Icon = "ui_clock",
			IconSize = L.Clock,
			TextSize = L.BtnText,
			ZIndex = 5,
		})
		button.Holder.ZIndex = 5
		buttonClock = button.Icon :: ImageLabel
		buttonClock.Visible = false
		button.Holder.Activated:Connect(function()
			if button.Holder:GetAttribute("Ready") then
				ctx.Claim()
			end
		end)
		local buttonGen = gen
		local buttonScale = SlKit.ScaleOf(holder)
		task.spawn(function()
			-- CLAIM bounces like the TODAY tile (0.9 s loop)
			while gen == buttonGen do
				if open and button.Holder:GetAttribute("Ready") and not celebrating then
					SlKit.Tween(buttonScale, 0.36, "Soft", { Scale = 1.04 })
					task.wait(0.36)
					SlKit.Tween(buttonScale, 0.18, "Soft", { Scale = 0.98 })
					task.wait(0.18)
					SlKit.Tween(buttonScale, 0.36, "Soft", { Scale = 1 })
					task.wait(0.36)
				else
					buttonScale.Scale = 1
					task.wait(0.25)
				end
			end
		end)
	end

	local buttonPaint = ""
	local function paintButton(paint: string, words: string)
		button.Label.Text = words
		buttonClock.Visible = paint == "Wait"
		button.Holder:SetAttribute("Ready", paint == "Claim")
		buttonGlow.Visible = paint == "Claim"
		if paint ~= buttonPaint then
			buttonPaint = paint
			local colours = PAINT[paint]
			-- colour change 0.2 s soft (design: CLAIM -> countdown)
			SlKit.Tween(button.Lip, 0.2, "Soft", { BackgroundColor3 = colours[2] })
			SlKit.Tween(button.Face, 0.2, "Soft", { BackgroundColor3 = colours[3] })
			SlKit.Tween(button.Fill, 0.2, "Soft", { BackgroundColor3 = colours[1] })
		end
	end

	local function refresh()
		if not tiles[1] then
			return
		end
		local nextDay = player:GetAttribute("DailyNext") or 1
		local claimable = player:GetAttribute("DailyClaimable") == true
		for day, t in tiles do
			local state = if day < nextDay or (day == nextDay and not claimable)
				then "Claimed"
				elseif day == nextDay then "Today"
				else "Locked"
			if celebrating and day == celebratingDay then
				state = "Claimed"
			end
			-- rewards follow your progress, so a tile repaints when what it gives changes
			local shown = describe(ctx.Resolve(day))
			if not t.Shown or signature(t.Shown) ~= signature(shown) then
				if t.Big then
					paintBig(t, shown)
				else
					paintArt(t, shown)
				end
			end
			t.Shown = shown
			if state ~= t.State then
				t.State = state
				t.Card.GroupTransparency = if state == "Claimed" then 0.45 else 0
				t.Shade.Visible = state == "Locked"
				t.Glow.Visible = state == "Today"
				t.Tick.Visible = state == "Claimed"
				if t.Big then
					t.Foot.BackgroundColor3 = if state == "Today" then FOOT.Today else GOLD_LIP
					t.Card.BackgroundColor3 = t.Foot.BackgroundColor3
					;(t.FootLock :: ImageLabel).Visible = state == "Locked"
				else
					t.Lock.Visible = state == "Locked"
					t.Icon.Visible = state ~= "Claimed"
					t.Foot.BackgroundColor3 = FOOT[state]
					t.Card.BackgroundColor3 = FOOT[state]
				end
			end
		end
		if errorText then
			paintButton("Red", string.upper(errorText))
		elseif noteText then
			paintButton("Pink", noteText)
		elseif claimable and not celebrating then
			paintButton("Claim", "CLAIM")
		else
			paintButton("Wait", clock(Calendar.SecondsUntilNextDay(Workspace:GetServerTimeNow())))
		end
	end
	DailyV2.Refresh = refresh

	local function refit()
		local view = gui.AbsoluteSize
		if view.X <= 0 then
			return
		end
		local nowPhone = view.Y < (Config.Ui.CompactHeight or 500)
		if nowPhone ~= phone then
			phone = nowPhone
			build()
			refresh()
		end
		fitScale.Scale = math.min((view.X - 40) / (L.W + 56), (view.Y - 40) / (L.H + L.Lip + 70), 1)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	function DailyV2.SetOpen(want: boolean)
		if want == open then
			return
		end
		open = want
		if want then
			errorText, noteText = nil, nil
			refresh()
			backdrop.Visible = true
			-- window grows out of the button you pressed (Polish v2 D1, Motion); plate y -24 -> 0, 0.22 s overshoot
			Motion.WindowOpen(win, openScale)
			plate.Holder.Position = plateBase + UDim2.fromOffset(0, -24)
			task.delay(0.06, function()
				SlKit.Tween(plate.Holder, 0.22, "Over", { Position = plateBase })
			end)
			Sfx.Play("Click", 1.1)
			-- tiles: scale 0.6 -> 1.08 -> 1, 0.25 s overshoot, 0.04 s stagger
			for day, t in tiles do
				local scale = SlKit.ScaleOf(t.Holder)
				scale.Scale = 0.6
				task.delay(0.04 * (day - 1), function()
					SlKit.Tween(scale, 0.15, "Snap", { Scale = 1.08 })
					task.delay(0.15, function()
						SlKit.Tween(scale, 0.1, "Over", { Scale = 1 })
					end)
				end)
			end
		else
			Motion.WindowClose(win, openScale, function()
				if not open then
					win.Visible = false
					backdrop.Visible = false
				end
			end)
			if ctx.OnClose then
				ctx.OnClose()
			end
		end
	end
	function DailyV2.IsOpen(): boolean
		return open
	end

	-- A red "no" line on the button for a moment
	function DailyV2.ShowError(message: string)
		errorText = message
		refresh()
		SlKit.Shake(button.Holder, 8, 0, 0.3)
		task.delay(1.5, function()
			errorText = nil
			refresh()
		end)
	end
	-- A pink note on the button (egg days: where to hatch it)
	function DailyV2.ShowNote(message: string?)
		noteText = message
		refresh()
	end

	-- Where a reward flies to on the HUD (screen pixels): coins / gems pills, potion timers
	local function hudTarget(kind: string): Vector2
		local key = if kind == "Gems" then "Gems" elseif kind == "Potion" then "Potions" else "Coins"
		local ok, position, size = pcall(HudKit.Spot, key)
		local view = gui.AbsoluteSize
		local inset = GuiService:GetGuiInset()
		if not ok or not position then
			return Vector2.new(120, 80)
		end
		local s = HudKit.HudScale()
		local w = if size then size.X.Offset else 80
		local h = if size then size.Y.Offset else 60
		return Vector2.new(
			position.X.Scale * view.X + (position.X.Offset + math.min(w, 120) * 0.3) * s,
			position.Y.Scale * (view.Y - inset.Y) + (position.Y.Offset + h / 2) * s + inset.Y
		)
	end

	-- Claim press: tile scale 1 -> 1.15 -> 1 (0.25 s overshoot), tick scale 2 -> 1 + fade in (0.2 s snap), the icon
	-- flies to the HUD counter (0.5 s soft, scale 1 -> 0.4); then CLAIM turns into the countdown
	function DailyV2.Celebrate(day: number)
		local t = tiles[day]
		if not t then
			refresh()
			return
		end
		celebrating = true
		celebratingDay = day
		refresh()
		local scale = SlKit.ScaleOf(t.Holder)
		SlKit.Tween(scale, 0.1, "Snap", { Scale = 1.15 })
		task.delay(0.1, function()
			SlKit.Tween(scale, 0.15, "Over", { Scale = 1 })
		end)
		local tick = t.Tick
		local tickScale = SlKit.ScaleOf(tick)
		tickScale.Scale = 2
		tick.ImageTransparency = 1
		SlKit.Tween(tickScale, 0.2, "Snap", { Scale = 1 })
		SlKit.Tween(tick, 0.2, "Snap", { ImageTransparency = 0 })
		-- the icon(s) fly
		local shown = t.Shown
		local source = if t.Big then t.Slot else t.Icon
		if shown and source then
			local inset = GuiService:GetGuiInset()
			local from = source.AbsolutePosition + source.AbsoluteSize / 2 + inset
			local px = source.AbsoluteSize.X * (if t.Big then 0.6 else 1)
			local flights = { { shown.Kind, if t.Big and shown.Kind == "Coins" then "cur_coins_big" else shown.Icon } }
			for _, extra in shown.Extras do
				table.insert(flights, { if extra[1] == "cur_gem" then "Gems" elseif string.find(extra[1], "potion") then "Potion" else "Coins", extra[1] })
			end
			for i, flight in flights do
				task.delay(0.12 * (i - 1), function()
					local fly = SlKit.Image(gui, flight[2] or "cur_coin", px, {
						Name = "Fly",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromOffset(from.X, from.Y),
						ZIndex = 50,
					})
					local to = hudTarget(flight[1])
					SlKit.Tween(fly, 0.5, "Soft", {
						Position = UDim2.fromOffset(to.X, to.Y),
						Size = UDim2.fromOffset(px * 0.4, px * 0.4),
					})
					task.delay(0.5, function()
						fly:Destroy()
					end)
				end)
			end
		end
		Sfx.Play("Reveal")
		task.delay(0.6, function()
			celebrating = false
			refresh()
		end)
	end

	function DailyV2.Gui(): ScreenGui
		return gui
	end

	backdrop.Activated:Connect(function()
		DailyV2.SetOpen(false)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and open and input.KeyCode == Enum.KeyCode.Escape then
			DailyV2.SetOpen(false)
		end
	end)
	for _, key in { "DailyNext", "DailyClaimable", "ZonesOpen", "PowerLevel", "AwayRate", "BallStep", "BagLevel", "Rebirths" } do
		player:GetAttributeChangedSignal(key):Connect(function()
			if open and not celebrating then
				refresh()
			end
		end)
	end
	-- the countdown ticks each second while open (no motion)
	task.spawn(function()
		while true do
			task.wait(1)
			if open and not celebrating then
				refresh()
			end
		end
	end)

	-- Studio: TestOpen = true / false opens / closes it (for checking from the Studio tools)
	if RunService:IsStudio() then
		gui:GetAttributeChangedSignal("TestOpen"):Connect(function()
			DailyV2.SetOpen(gui:GetAttribute("TestOpen") == true)
		end)
	end

	gui.Parent = playerGui
	refit()
	if phone == nil then
		phone = false
		build()
	end
	refresh()
end

return DailyV2
