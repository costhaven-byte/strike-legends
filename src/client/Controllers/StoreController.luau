-- STORE (Addendum 2 section 7, step 12a): only while the store is on (Config.Monetization.Enabled, or Studio's free
-- preview). Looks: the owner's Store Kit (claude.ai/design 'Strike Legends Store', 2026-10-25), sizes and colours as
-- specced there (sizes include the outline, like the design); icons are AssetSlots.Images.
-- * STORE button (gold, bag icon; right of BALLS and PETS, where DAILY was (owner 2026-10-25)), with a
--   red "!" until the store is opened this session.
-- * Quick-buy pills on the HUD (owner 2026-10-25): each boost ladder's next step ("x1.25 COINS / R$ 19"), right of the
--   coin multiplier badge; a MAXED ladder's pill shrinks away and the other moves up.
-- * The window: BOOSTS / PASSES / GEMS tabs jump within one scrolling list (Starter Pack on top until bought).
-- * The one-time Starter Pack popup (the server says when; it waits for a quiet moment, never mid-throw), the THANK
--   YOU / VIP DAILY GIFT toast, and the gold [VIP] tag in chat for VIP owners.
-- BUY asks the server, which shows Roblox's own purchase window; nothing is given here. Built in code, so it's in git.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetSlots = require(Shared.AssetSlots)
local Store = require(Shared.Modules.Store)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules:WaitForChild("Sfx"))
local HudKit = require(Modules:WaitForChild("HudKit"))

local player = Players.LocalPlayer

local MONEY = Config.Monetization
-- Gotham isn't in Roblox's new font list as "Gotham": GothamSSm is the same family
local HEAD = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local NUM = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BLACK = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local function hex(value: string): Color3
	return Color3.fromHex(value)
end
local C = {
	Panel = hex("070B1E"),
	Card = hex("1E143C"),
	Ink = hex("04061A"),
	PanelRing = hex("2A1F57"),
	CardRing = hex("33255E"),
	Body = hex("CFC8EE"),
	White = Color3.new(1, 1, 1),
	Grey = hex("5C6078"),
	GreyLip = hex("3E4157"),
	GreyText = hex("D9DBE6"),
	Gold = hex("FFC93A"),
	GoldLip = hex("C98A12"),
	GoldDown = hex("E8AE1E"),
	Cyan = hex("2BE4FF"),
	Pink = hex("FF4FB0"),
	PinkLip = hex("B8287A"),
	PinkDown = hex("E23C98"),
	Lime = hex("7DFF3C"),
	LimeLip = hex("3FB51A"),
	LimeDown = hex("62E222"),
	Red = hex("FF2D4A"),
	RedLip = hex("B3132C"),
	Track = hex("0B0820"),
	PressRing = hex("5B47A8"),
}

-- Icon per pass / product Id (cards and the toast)
local ICONS = {
	DoubleCoins = "Pass2x",
	VIP = "PassVip",
	AutoBowl = "PassAuto",
	Lucky = "PassLucky",
	SuperLucky = "PassSuperLucky",
	TripleHatch = "PassTriple",
	PetSlots = "PassPets",
	CoinBoost = "Boost15",
	GemsSmall = "Gems60",
	GemsMedium = "Gems300",
	GemsLarge = "Gems1500",
	StarterPack = "BallDumpster",
}
local GEM_ICON_SIZE = { GemsSmall = 56, GemsMedium = 68, GemsLarge = 84 }

local StoreController = {}

-- ===== Small builders =====

local function make(class: string, props: { [string]: any }, parent: Instance?): any
	local object = Instance.new(class)
	for key, value in props do
		object[key] = value
	end
	if object:IsA("GuiButton") then
		object:SetAttribute("OwnPress", true) -- no global press effect (UiFxController): these press by themselves
	end
	if parent then
		object.Parent = parent
	end
	return object
end

local function corner(parent: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, math.max(0, radius)) }, parent)
end

-- UIStroke on a frame draws outside its edge
local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	return make("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	}, parent)
end

-- A ring drawn just inside `parent`'s edge, `inset` px in (like CSS inset box-shadow / border-box borders)
local function innerRing(parent: Instance, color: Color3, thickness: number, inset: number, radius: number, z: number?)
	local frame = make("Frame", {
		Name = "Ring",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(inset + thickness, inset + thickness),
		Size = UDim2.new(1, -2 * (inset + thickness), 1, -2 * (inset + thickness)),
		ZIndex = z or 6,
	}, parent)
	corner(frame, radius - inset - thickness)
	return frame, stroke(frame, color, thickness)
end

-- Text with the designs' ink outline. `outline` is the design's -webkit-text-stroke width: only half of it shows
-- outside the letters, so the UIStroke is half as thick.
local function label(
	parent: Instance,
	text: string,
	font: Font,
	size: number,
	color: Color3,
	outline: number?
): TextLabel
	local object = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = font,
		Text = text,
		TextSize = size,
		TextColor3 = color,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
	}, parent)
	if outline and outline > 0 then
		make("UIStroke", { Color = C.Ink, Thickness = outline / 2, LineJoinMode = Enum.LineJoinMode.Round }, object)
	end
	return object
end

local function image(parent: Instance, name: string, size: number, props: { [string]: any }?): ImageLabel
	local object = make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = AssetSlots.Image(name),
		Size = UDim2.fromOffset(size, size),
		ScaleType = Enum.ScaleType.Fit,
		ZIndex = 3,
	}, parent)
	for key, value in props or {} do
		object[key] = value
	end
	return object
end

local function list(parent: Instance, horizontal: boolean, gap: number, align: Enum.VerticalAlignment?)
	return make("UIListLayout", {
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap),
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = align or Enum.VerticalAlignment.Center,
	}, parent)
end

local function pad(parent: Instance, top: number, right: number, bottom: number, left: number)
	make("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
	}, parent)
end

-- Transparency along a gradient: { {position, transparency}, ... }
local function fade(parent: Instance, keys: { { number } }, rotation: number)
	local points = {}
	for _, key in keys do
		table.insert(points, NumberSequenceKeypoint.new(key[1], key[2]))
	end
	make("UIGradient", { Transparency = NumberSequence.new(points), Rotation = rotation }, parent)
end

-- The halftone dot texture (one dot, tiled)
local function halftone(parent: Instance, color: Color3, transparency: number, tile: number): ImageLabel
	return make("ImageLabel", {
		Name = "Dots",
		BackgroundTransparency = 1,
		Image = AssetSlots.Image("Halftone"),
		ImageColor3 = color,
		ImageTransparency = transparency,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(tile, tile),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, parent)
end

local function formatRobux(robux: number): string
	local text = tostring(math.floor(robux))
	while true do
		local swapped, count = string.gsub(text, "^(%d+)(%d%d%d)", "%1,%2")
		text = swapped
		if count == 0 then
			return text
		end
	end
end

local function tween(object: Instance, time: number, style: Enum.EasingStyle, direction: Enum.EasingDirection, goal)
	local t = TweenService:Create(object, TweenInfo.new(time, style, direction), goal)
	t:Play()
	return t
end

local function scaleOf(object: GuiObject): UIScale
	return object:FindFirstChildOfClass("UIScale") or make("UIScale", {}, object)
end

local function textWidth(text: string, size: number, font: Enum.Font): number
	return math.ceil(TextService:GetTextSize(text, size, font, Vector2.new(2000, 200)).X)
end

-- Height of wrapped body text (Gotham Bold) at this width
local function textHeight(text: string, size: number, width: number): number
	local bounds = TextService:GetTextSize(text, size, Enum.Font.GothamBold, Vector2.new(width, 1000))
	return math.ceil(bounds.Y * 1.1)
end

-- The chunky button every design uses: ink outline, a darker lip inside the bottom edge, a white highlight along the
-- top, an ink drop below. Pressing moves it down onto the drop (Animation notes: BUTTON PRESS).
-- spec = { Size, Radius, Color, Down?, Lip, LipHeight, Drop, Outline, Highlight, HighlightAlpha, Clip?, Name?,
--          OnDown?, OnUp? }. Returns holder (place it), face (put content in it; covers the whole button),
-- body (the TextButton) and fill (the coloured part above the lip).
local function chunky(parent: Instance, spec)
	local o = spec.Outline
	local holder = make("Frame", { Name = spec.Name or "Button", BackgroundTransparency = 1, Size = spec.Size }, parent)
	local drop = make("Frame", {
		Name = "Drop",
		BackgroundColor3 = C.Ink,
		Position = UDim2.fromOffset(o, o + spec.Drop),
		Size = UDim2.new(1, -2 * o, 1, -2 * o),
		Visible = spec.Drop > 0,
	}, holder)
	corner(drop, spec.Radius - o)
	stroke(drop, C.Ink, o)
	local rest = UDim2.fromOffset(o, o)
	local body = make("TextButton", {
		Name = "Body",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = spec.Lip,
		Position = rest,
		Size = UDim2.new(1, -2 * o, 1, -2 * o),
		ZIndex = 2,
	}, holder)
	corner(body, spec.Radius - o)
	stroke(body, C.Ink, o)
	local face = make(if spec.Clip then "CanvasGroup" else "Frame", {
		Name = "Face",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
	}, body)
	corner(face, spec.Radius - o)
	local fill = make("Frame", {
		Name = "Fill",
		BackgroundColor3 = spec.Color,
		Size = UDim2.new(1, 0, 1, -spec.LipHeight),
		ZIndex = 1,
	}, face)
	corner(fill, spec.Radius - o)
	if spec.Highlight > 0 then
		local highlight = make("Frame", {
			Name = "Highlight",
			BackgroundColor3 = C.White,
			BackgroundTransparency = 1 - spec.HighlightAlpha,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(1, -(spec.Radius - o), 0, spec.Highlight),
			BorderSizePixel = 0,
			ZIndex = 2,
		}, fill)
		corner(highlight, spec.Highlight)
	end
	holder:SetAttribute("Color", spec.Color)
	local scale = scaleOf(holder)
	local held = false
	body.MouseButton1Down:Connect(function()
		if not body.Active then
			return
		end
		held = true
		local dropBy = drop.Position.Y.Offset - o
		body.Position = UDim2.fromOffset(o, o + dropBy)
		drop.Visible = false
		fill.BackgroundColor3 = spec.Down or holder:GetAttribute("Color")
		tween(scale, 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 0.94 })
		if spec.OnDown then
			spec.OnDown()
		end
	end)
	local function up()
		if not held then
			return
		end
		held = false
		body.Position = rest
		drop.Visible = drop.Position.Y.Offset > o
		fill.BackgroundColor3 = holder:GetAttribute("Color")
		tween(scale, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
		if spec.OnUp then
			spec.OnUp()
		end
	end
	body.MouseButton1Up:Connect(up)
	body.MouseLeave:Connect(up)
	body.Activated:Connect(function()
		if body.Active then
			Sfx.Play("Click", 0.95 + math.random() * 0.1)
		end
	end)
	return holder, face, body, fill
end

-- Recolour a chunky button (OWNED / MAXED grey and back); drop = the drop's new depth
local function recolor(holder: Frame, color: Color3, lip: Color3, active: boolean, drop: number)
	holder:SetAttribute("Color", color)
	local body = holder:FindFirstChild("Body") :: TextButton
	body.BackgroundColor3 = lip
	body.Active = active
	body.AutoButtonColor = false
	body.Face.Fill.BackgroundColor3 = color
	local dropFrame = holder:FindFirstChild("Drop") :: Frame
	dropFrame.Position = UDim2.fromOffset(body.Position.X.Offset, body.Position.X.Offset + drop)
	dropFrame.Visible = drop > 0
end

-- The idle shine stripe sliding across a CanvasGroup face every 4 s (skipped while `paused()`)
local function shine(face: GuiObject, height: number, width: number, delay: number, paused: () -> boolean)
	local stripe = image(face, "Shine", 0, {
		Name = "Shine",
		Size = UDim2.fromOffset(width, height),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.3, 0.5),
		Rotation = 20,
		ImageTransparency = 0.4,
		ScaleType = Enum.ScaleType.Stretch,
		ZIndex = 5,
	})
	task.spawn(function()
		task.wait(delay)
		while face.Parent do
			if not paused() then
				stripe.Position = UDim2.fromScale(-0.3, 0.5)
				tween(stripe, 0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, {
					Position = UDim2.fromScale(1.3, 0.5),
				})
			end
			task.wait(4)
		end
	end)
end

-- The R$ price on a buy button, plus the hidden OWNED / MAXED word
local function priceContent(face: GuiObject, iconSize: number, textSize: number, outline: number, lip: number)
	local row = make("Frame", {
		Name = "Price",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, -lip),
		ZIndex = 3,
	}, face)
	local layout = list(row, true, 5)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	image(row, "Robux", iconSize, { LayoutOrder = 1 })
	local amount = label(row, "", NUM, textSize, C.White, outline)
	amount.Name = "Amount"
	amount.LayoutOrder = 2
	amount.AutomaticSize = Enum.AutomaticSize.X
	amount.Size = UDim2.fromOffset(0, textSize + 4)
	local done = label(face, "", HEAD, 18, C.GreyText, 5)
	done.Name = "Done"
	done.Visible = false
	done.Position = UDim2.fromOffset(0, 2)
	done.Size = UDim2.new(1, 0, 1, -3)
	return row, amount, done
end

-- A panel with the designs' inside border (outline 4 + an inner ring), clipped to its corners, with an ink drop
-- below. Returns the holder (size/place it), the CanvasGroup (fade it) and the content frame (inside the border).
local function panelShell(
	parent: Instance,
	name: string,
	radius: number,
	outline: number,
	ringColor: Color3,
	ringWidth: number,
	dropBy: number
)
	local holder = make("Frame", { Name = name, BackgroundTransparency = 1, Visible = false }, parent)
	local drop = make("Frame", {
		Name = "Drop",
		BackgroundColor3 = C.Ink,
		Position = UDim2.fromOffset(0, dropBy),
		Size = UDim2.fromScale(1, 1),
	}, holder)
	local dropCorner = make("UICorner", { CornerRadius = UDim.new(0, radius) }, drop)
	local group = make("CanvasGroup", {
		Name = "Panel",
		BackgroundColor3 = C.Panel,
		Size = UDim2.fromScale(1, 1),
		Active = true,
	}, holder)
	local groupCorner = make("UICorner", { CornerRadius = UDim.new(0, radius) }, group)
	local outlineRing = innerRing(group, C.Ink, outline, 0, radius, 20)
	local colourRing = innerRing(group, ringColor, ringWidth, outline, radius, 20)
	local inside = make("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(outline, outline),
		Size = UDim2.new(1, -2 * outline, 1, -2 * outline),
	}, group)
	group:GetPropertyChangedSignal("GroupTransparency"):Connect(function()
		drop.BackgroundTransparency = group.GroupTransparency
	end)
	local function setRadius(r: number)
		dropCorner.CornerRadius = UDim.new(0, r)
		groupCorner.CornerRadius = UDim.new(0, r)
		outlineRing:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, r - outline)
		colourRing:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, r - outline - ringWidth)
	end
	return holder, group, inside, drop, setRadius
end

-- Gold [VIP] before VIP owners' names in chat (new chat only; the old chat has no hook for this)
local function chatTag()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	TextChatService.OnIncomingMessage = function(message: TextChatMessage)
		local source = message.TextSource
		local speaker = source and Players:GetPlayerByUserId(source.UserId)
		if speaker and Store.Owns(speaker, "VIP") then
			local properties = Instance.new("TextChatMessageProperties")
			properties.PrefixText = ('<font color="#FFC828">%s</font> %s'):format(MONEY.ChatTag, message.PrefixText)
			return properties
		end
		return nil
	end
end

function StoreController:Start()
	if not Store.Active() then
		return
	end
	chatTag()
	-- Load every store picture now: a CanvasGroup (the window, cards, pills) doesn't redraw when an image finishes
	-- loading later, so a late image would stay blank
	local preloaded = false
	local redraw: () -> () = function() end
	task.spawn(function()
		local images = {}
		for name in AssetSlots.Images do
			table.insert(images, AssetSlots.Image(name))
		end
		game:GetService("ContentProvider"):PreloadAsync(images)
		preloaded = true
		redraw()
	end)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local buyRemote = remotes:WaitForChild("StoreBuy") :: RemoteEvent
	local playerGui = player:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("HUD") :: ScreenGui
	local rankBar = hud:WaitForChild("RankBar") :: GuiObject
	local bar = hud:WaitForChild("Bar") :: Frame

	local function compact(): boolean
		return hud.AbsoluteSize.Y > 0 and hud.AbsoluteSize.Y < Config.Ui.CompactHeight
	end

	-- HUD pieces (same coordinates as the HUD)
	local gui = make("ScreenGui", {
		Name = "StoreUI",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		DisplayOrder = 6,
		IgnoreGuiInset = hud.IgnoreGuiInset,
	}, playerGui)
	-- Window, popup and backdrop (whole screen, over the Roblox bar too)
	local overlay = make("ScreenGui", {
		Name = "StoreWindowUI",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ResetOnSpawn = false,
		DisplayOrder = 7,
		IgnoreGuiInset = true,
	}, playerGui)

	local isOpen = false
	local function paused(): boolean
		return isOpen
	end

	-- ===== STORE button =====
	local buttonParts = {}
	local seenStore = false
	local function buildButton()
		if buttonParts.Holder then
			buttonParts.Holder:Destroy()
		end
		local phone = compact()
		local holder, face, body = chunky(gui, {
			Name = "StoreButton",
			Size = if phone then UDim2.fromOffset(44, 46) else UDim2.fromOffset(56, 56),
			Radius = if phone then 10 else 12,
			Color = C.Gold,
			Down = C.GoldDown,
			Lip = C.GoldLip,
			LipHeight = if phone then 3 else 4,
			Drop = if phone then 3 else 4,
			Outline = if phone then 2.5 else 3,
			Highlight = if phone then 2 else 3,
			HighlightAlpha = 0.5,
			Clip = true,
		})
		local iconSize = if phone then 27 else 34
		local icon = image(face, "StoreBag", iconSize, {
			Name = "Icon",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, if phone then 0 else 0),
		})
		local caption = label(face, "STORE", HEAD, if phone then 10 else 12, C.White, if phone then 3.5 else 4)
		caption.AnchorPoint = Vector2.new(0.5, 0)
		caption.Position = UDim2.new(0.5, 0, 0, iconSize - 1)
		caption.Size = UDim2.new(1, 0, 0, if phone then 10 else 12)
		shine(face, if phone then 80 else 90, if phone then 8 else 10, 0, paused)
		-- The red "!" dot, 7 px past the top-right corner
		local dotSize = if phone then 18 else 20
		local past = if phone then 6 else 7
		local dot = make("Frame", {
			Name = "NewDot",
			BackgroundColor3 = C.Red,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, past, 0, -past),
			Size = UDim2.fromOffset(dotSize, dotSize),
			ZIndex = 5,
			Visible = not seenStore,
		}, holder)
		corner(dot, dotSize)
		innerRing(dot, C.Ink, 2.5, 0, dotSize / 2, 6)
		local bang = label(dot, "!", HEAD, if phone then 12 else 13, C.White)
		bang.Position = UDim2.fromOffset(0, 2)
		bang.ZIndex = 7
		buttonParts = { Holder = holder, Icon = icon, Dot = dot }
		body.Activated:Connect(function()
			StoreController.Toggle()
		end)
	end

	local function placeButton()
		local holder = buttonParts.Holder
		-- Right of BALLS and PETS (HUD Kit spot)
		holder.AnchorPoint = Vector2.new(0, 0)
		holder.Position = HudKit.Spot("Store", compact())
	end

	-- Idle: the icon pops every 5 s, the "!" wiggles every 3 s (paused while the store is open)
	task.spawn(function()
		while true do
			task.wait(5)
			local icon = buttonParts.Icon
			if icon and icon.Parent and not isOpen then
				local scale = scaleOf(icon)
				tween(scale, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 1.08 }).Completed:Wait()
				tween(scale, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 0.97 }).Completed:Wait()
				tween(scale, 0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(3)
			local dot = buttonParts.Dot
			if dot and dot.Parent and dot.Visible and not isOpen then
				for _, angle in { -14, 14, -8, 6, 0 } do
					tween(dot, 0.12, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, { Rotation = angle }).Completed:Wait()
				end
			end
		end
	end)

	-- ===== Quick-buy pills =====
	local LADDERS = {
		{ Ladder = "Coins", What = "COINS", Color = C.Gold, Icon = "Coin", Delay = 0 },
		{ Ladder = "Xp", What = "XP", Color = C.Cyan, Icon = "XpStar", Delay = 2 },
	}
	local pills = {}
	local pillPhone = nil
	local function buildPills()
		for _, pill in pills do
			pill.Holder:Destroy()
		end
		table.clear(pills)
		local phone = compact()
		pillPhone = phone
		local w, h = if phone then 88 else 78, if phone then 44 else 30
		for _, ladder in LADDERS do
			local holder, face, body = chunky(hud, {
				Name = "Quick" .. ladder.Ladder,
				Size = UDim2.fromOffset(w, h),
				Radius = h / 2,
				Color = C.Pink,
				Down = C.PinkDown,
				Lip = C.PinkLip,
				LipHeight = 3,
				Drop = 3,
				Outline = if phone then 3 else 2.5,
				Highlight = 2,
				HighlightAlpha = 0.45,
				Clip = true,
			})
			holder.Visible = false
			-- Soft white glow at the top centre
			local glow = make("Frame", { BackgroundColor3 = C.White, Size = UDim2.fromScale(1, 1), ZIndex = 2 }, face)
			fade(glow, { { 0, 0.72 }, { 0.7, 1 }, { 1, 1 } }, 90)
			-- Halftone dots at both ends, faded out behind the text
			local dots = halftone(face, C.Ink, 0.78, if phone then 5 else 4)
			fade(dots, { { 0, 0 }, { 0.45, 1 }, { 0.55, 1 }, { 1, 0 } }, 0)
			-- Two faint tilted icons bleeding off the corners
			image(face, ladder.Icon, if phone then 40 else 30, {
				Position = UDim2.fromOffset(if phone then -10 else -9, if phone then -6 else -5),
				Rotation = -18,
				ImageTransparency = 0.6,
				ZIndex = 2,
			})
			image(face, ladder.Icon, if phone then 34 else 26, {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, if phone then 9 else 8, 1, if phone then 11 else 9),
				Rotation = 16,
				ImageTransparency = 0.6,
				ZIndex = 2,
			})
			-- Top highlight band
			local band = make("Frame", {
				BackgroundColor3 = C.White,
				BackgroundTransparency = 0.78,
				Position = UDim2.fromOffset(if phone then 3 else 2, 0),
				Size = UDim2.new(1, if phone then -6 else -4, 0, if phone then 12 else 8),
				ZIndex = 3,
			}, face)
			corner(band, 10)
			local top = label(face, "", HEAD, if phone then 16 else 13, ladder.Color, if phone then 5 else 4)
			top.Size = UDim2.new(1, 0, 0, if phone then 16 else 13)
			HudKit.Fit(top, if phone then 16 else 13) -- "x1.25 COINS" is longer than the old "x2 COINS"
			top.Position = UDim2.fromOffset(0, if phone then 4 else 3)
			local priceRow = make("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(0, if phone then 20 else 14),
				Size = UDim2.new(1, 0, 0, if phone then 15 else 12),
				ZIndex = 4,
			}, face)
			local layout = list(priceRow, true, if phone then 3 else 2)
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			image(priceRow, "Robux", if phone then 14 else 11, { LayoutOrder = 1, ZIndex = 4 })
			local price = label(priceRow, "", NUM, if phone then 15 else 12, C.White, if phone then 4 else 3.5)
			price.LayoutOrder = 2
			price.AutomaticSize = Enum.AutomaticSize.X
			price.Size = UDim2.fromScale(0, 1)
			shine(face, if phone then 76 else 56, if phone then 11 else 10, ladder.Delay, paused)
			body.Activated:Connect(function()
				local step = Store.NextStep(player, ladder.Ladder)
				if step then
					buyRemote:FireServer(step.Id)
				end
			end)
			table.insert(pills, { Holder = holder, Top = top, Price = price, Ladder = ladder, Shown = nil, Slot = nil })
		end
	end
	-- Side by side above the coin counter (owner 2026-10-25), on the HUD Kit's spot: 10 px apart (6 on phones)
	local function placePills(animate: boolean)
		if #pills == 0 then
			return
		end
		local w = pills[1].Holder.Size.X.Offset
		local spot = HudKit.Spot("Boosts", compact())
		local gap = if compact() then 6 else 10
		local slot = 0
		for _, pill in pills do
			if pill.Shown then
				local target = spot + UDim2.fromOffset(slot * (w + gap), 0)
				if animate and pill.Slot ~= nil and pill.Slot ~= slot then
					tween(pill.Holder, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Position = target })
				else
					pill.Holder.Position = target
				end
				pill.Slot = slot
				slot += 1
			end
		end
	end
	local function refreshPills(animate: boolean)
		local moved = false
		for _, pill in pills do
			local step = Store.NextStep(player, pill.Ladder.Ladder)
			if step then
				pill.Top.Text = Store.MultText(step.Mult or 1) .. " " .. pill.Ladder.What
				pill.Price.Text = formatRobux(step.Robux)
			end
			local show = step ~= nil
			if pill.Shown ~= show then
				moved = true
				local holder = pill.Holder
				if not show and animate and pill.Shown then
					-- PILL MAXED: shrink away, then the other pill moves up into its slot
					tween(scaleOf(holder), 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In, { Scale = 0 }).Completed:Once(
						function()
							holder.Visible = false
						end
					)
				else
					holder.Visible = show
				end
				pill.Shown = show
			end
		end
		if moved then
			if animate then
				task.delay(0.2, placePills, true)
			else
				placePills(false)
			end
		end
	end

	-- ===== The window =====
	local backdrop = make("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, overlay)

	local window, panel, content, _, setWindowRadius = panelShell(overlay, "Store", 26, 4, C.PanelRing, 3, 8)
	local windowDrop = window:FindFirstChild("Drop") :: Frame
	local windowScale = scaleOf(window)

	local chipValues = {}
	local tabButtons = {}
	local cardRefs = {}
	local sectionHeaders = {}
	local scroller: ScrollingFrame? = nil
	local activeTab = "boosts"
	local builtFor: boolean? = nil
	local builtWidth = 0

	local function setActiveTab(id: string)
		activeTab = id
		for tabId, tab in tabButtons do
			local on = tabId == id
			local color = if on then C.Gold else C.Card
			tab.Holder:SetAttribute("Color", color)
			tab.Fill.BackgroundColor3 = color
			tab.Body.BackgroundColor3 = color
			tab.Text.TextColor3 = if on then C.Ink else C.Body
		end
	end

	-- Canvas y of a section's header (0 for BOOSTS: the top, Starter Pack included)
	local function sectionTop(id: string): number
		local header = sectionHeaders[id]
		if id == "boosts" or not header or not scroller then
			return 0
		end
		local s = if windowScale.Scale > 0 then windowScale.Scale else 1
		return (header.AbsolutePosition.Y - scroller.AbsolutePosition.Y) / s + scroller.CanvasPosition.Y - 4
	end

	local jumping = false
	local function jump(id: string)
		if not scroller then
			return
		end
		setActiveTab(id)
		local maxY = math.max(0, scroller.AbsoluteCanvasSize.Y - scroller.AbsoluteWindowSize.Y)
		local y = math.clamp(sectionTop(id), 0, maxY)
		jumping = true
		tween(scroller, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
			CanvasPosition = Vector2.new(0, y),
		}).Completed:Once(function()
			jumping = false
		end)
	end

	local function onScroll()
		if jumping or not scroller then
			return
		end
		local y = scroller.CanvasPosition.Y
		local active = "boosts"
		for _, id in { "passes", "gems" } do
			if sectionHeaders[id] and sectionTop(id) - 36 <= y then
				active = id
			end
		end
		if y > 0 and y + scroller.AbsoluteWindowSize.Y >= scroller.AbsoluteCanvasSize.Y - 4 then
			active = "gems"
		end
		if active ~= activeTab then
			setActiveTab(active)
		end
	end

	-- Card background art (clipped to the rounded card): a tint of the label colour fading out, halftone dots
	-- toward the bottom-right and the card's own icon as a faint tilted watermark
	local function cardArt(card: Frame, radius: number, color: Color3, iconName: string)
		local art = make(
			"CanvasGroup",
			{ Name = "Art", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 },
			card
		)
		corner(art, radius)
		local tint = make("Frame", { BackgroundColor3 = color, Size = UDim2.fromScale(1, 1) }, art)
		fade(tint, { { 0, 0.7 }, { 0.6, 1 }, { 1, 1 } }, 75)
		local dots = halftone(art, color, 0.76, 8)
		fade(dots, { { 0, 1 }, { 0.4, 1 }, { 1, 0 } }, 30)
		image(art, iconName, 104, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 22, 0, -18),
			Rotation = 16,
			ImageTransparency = 0.87,
		})
		image(art, iconName, 58, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0.38, 0, 1, 20),
			Rotation = -20,
			ImageTransparency = 0.92,
		})
		return art
	end

	-- A card shell: outline 3 (inside the size), drop 4, inner ring. Returns holder, card (content goes in it,
	-- inside the outline), the ring's stroke, and the holder's scale.
	local function cardShell(parent: Instance, name: string, size: UDim2, radius: number, order: number)
		local holder =
			make("Frame", { Name = name, BackgroundTransparency = 1, Size = size, LayoutOrder = order }, parent)
		local drop = make("Frame", {
			BackgroundColor3 = C.Ink,
			Position = UDim2.fromOffset(3, 3 + 4),
			Size = UDim2.new(1, -6, 1, -6),
		}, holder)
		corner(drop, radius - 3)
		stroke(drop, C.Ink, 3)
		local card = make("Frame", {
			Name = "Card",
			BackgroundColor3 = C.Card,
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.new(1, -6, 1, -6),
		}, holder)
		corner(card, radius - 3)
		stroke(card, C.Ink, 3)
		return holder, card, scaleOf(holder)
	end

	-- --- One card ---
	-- kind: "Ladder" | "Pass" | "Product"; item: the Config row (a ladder card gets { Ladder = "Coins" })
	local function buildCard(parent: Instance, kind: string, item, size: UDim2, order: number)
		local accentColor, labelText, labelColor, name, iconName, iconSize
		if kind == "Ladder" then
			local coins = item.Ladder == "Coins"
			accentColor = if coins then C.Gold else C.Cyan
			labelText, labelColor = "FOREVER - DOUBLES EVERY BUY", C.Pink
			name = if coins then "COIN BOOST" else "XP BOOST"
			iconName, iconSize = if coins then "BoostCoin" else "BoostXp", 58
		elseif kind == "Pass" then
			labelText, labelColor = "GAME PASS", C.Gold
			name, iconName, iconSize = item.Name, ICONS[item.Id], 54
		else
			labelText, labelColor = if item.Gems then "GEMS" else "BOOST", C.Cyan
			name, iconName, iconSize = item.Name, ICONS[item.Id], GEM_ICON_SIZE[item.Id] or 54
		end

		local holder, card, scale = cardShell(parent, item.Id or ("Ladder_" .. item.Ladder), size, 18, order)
		cardArt(card, 15, labelColor, iconName)
		local _, ringStroke = innerRing(card, C.CardRing, 2, 0, 15, 3)

		local body =
			make("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, card)
		pad(body, 7, 9, 9, 9) -- the design's 10/12/12 padding, less the 3 px outline
		-- Label chip
		local chip = make("Frame", {
			BackgroundColor3 = labelColor,
			Size = UDim2.fromOffset(textWidth(labelText, 10, Enum.Font.GothamBlack) + 20, 18),
			ZIndex = 4,
		}, body)
		corner(chip, 8)
		innerRing(chip, C.Ink, 2, 0, 8, 5)
		local chipText = label(chip, labelText, BLACK, 10, C.Ink)
		chipText.Position = UDim2.fromOffset(0, 1)
		-- Icon + name (+ the ladder's "x4 > x8")
		local rowTop = 24
		image(body, iconName, iconSize, {
			Position = UDim2.fromOffset(0, rowTop + math.floor((58 - iconSize) / 2)),
			ZIndex = 4,
		})
		local textX = iconSize + 10
		local nameText = label(body, name, HEAD, 22, C.White, 6)
		nameText.TextXAlignment = Enum.TextXAlignment.Left
		nameText.TextWrapped = true
		local accent = nil
		if kind == "Ladder" then
			nameText.Position = UDim2.fromOffset(textX, rowTop + 6)
			nameText.Size = UDim2.new(1, -textX, 0, 23)
			accent = label(body, "", NUM, 24, accentColor, 6)
			accent.TextXAlignment = Enum.TextXAlignment.Left
			accent.Position = UDim2.fromOffset(textX, rowTop + 30)
			accent.Size = UDim2.new(1, -textX, 0, 25)
		else
			nameText.AnchorPoint = Vector2.new(0, 0.5)
			nameText.Position = UDim2.fromOffset(textX, rowTop + 31)
			nameText.Size = UDim2.new(1, -textX, 0, 50)
		end
		-- Description
		local desc = label(body, item.Text or "", BOLD, 12, C.Body)
		desc.TextWrapped = true
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.LineHeight = 1.1
		desc.Position = UDim2.fromOffset(0, rowTop + 58 + 6)
		desc.Size = UDim2.new(1, 0, 1, -(rowTop + 64 + 52))
		-- Bottom row: the ladder's 4 dots, then the price button
		local dotFrames = {}
		if kind == "Ladder" then
			local track = make("Frame", {
				BackgroundColor3 = C.Track,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, -13),
				Size = UDim2.fromOffset(4 * 14 + 3 * 6 + 18, 26),
				ZIndex = 4,
			}, body)
			corner(track, 12)
			stroke(track, C.Ink, 2)
			pad(track, 0, 9, 0, 9)
			list(track, true, 6)
			for i = 1, 4 do
				local dot = make("Frame", { Size = UDim2.fromOffset(14, 14), LayoutOrder = i, ZIndex = 5 }, track)
				corner(dot, 7)
				-- 1.5 px ink just outside, the coloured ring inside
				stroke(dot, C.Ink, 1.5)
				local _, dotRing = innerRing(dot, C.CardRing, 2.5, 0, 7, 6)
				dotFrames[i] = { Frame = dot, Ring = dotRing }
			end
		end
		local buyHolder, buyFace, buyBody = chunky(body, {
			Name = "Buy",
			Size = UDim2.fromOffset(104, 44),
			Radius = 14,
			Color = C.Lime,
			Down = C.LimeDown,
			Lip = C.LimeLip,
			LipHeight = 4,
			Drop = 4,
			Outline = 3,
			Highlight = 3,
			HighlightAlpha = 0.55,
			OnDown = function()
				tween(scale, 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 0.985 })
				ringStroke.Color = C.PressRing
			end,
			OnUp = function()
				tween(scale, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
				ringStroke.Color = C.CardRing
			end,
		})
		buyHolder.AnchorPoint = Vector2.new(1, 1)
		buyHolder.Position = UDim2.new(1, 0, 1, -4)
		buyHolder.ZIndex = 4
		local priceRow, amount, doneText = priceContent(buyFace, 20, 22, 6, 4)

		local flash = make("Frame", {
			Name = "Flash",
			BackgroundColor3 = C.White,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 8,
		}, card)
		corner(flash, 15)

		local ref =
			{ Holder = holder, Kind = kind, Item = item, BuyHolder = buyHolder, Dots = dotFrames, Flash = flash }
		function ref.Refresh()
			local robux, done = item.Robux, nil
			if kind == "Pass" then
				done = if Store.Owns(player, item.Id) then "OWNED" else nil
			elseif kind == "Ladder" then
				local level = Store.LadderLevel(player, item.Ladder)
				local step = Store.NextStep(player, item.Ladder)
				local what = if item.Ladder == "Coins" then "coins" else "XP"
				local now = Store.MultText(Store.LadderMult(item.Ladder, level))
				accent.Text = if step then now .. " > " .. Store.MultText(step.Mult or 1) else now
				desc.Text = if step
					then ("Boosts your %s forever. Step %d of 4."):format(what, step.Step)
					else ("Your %s boost is at the top: x2. All done!"):format(what)
				for i, dot in dotFrames do
					local bought, nextOne = i <= level, i == level + 1
					dot.Frame.BackgroundColor3 = if bought then accentColor else C.Card
					dot.Ring.Color = if bought then C.Ink else (if nextOne then accentColor else C.CardRing)
					dot.Ring.Transparency = if bought then 1 else 0
				end
				robux = step and step.Robux
				done = if step then nil else "MAXED"
				ref.Level = level
			end
			if done then
				recolor(buyHolder, C.Grey, C.GreyLip, false, 2)
				priceRow.Visible = false
				doneText.Text = done
				doneText.Visible = true
			else
				recolor(buyHolder, C.Lime, C.LimeLip, true, 4)
				priceRow.Visible = true
				doneText.Visible = false
				amount.Text = formatRobux(robux or 0)
			end
		end
		buyBody.Activated:Connect(function()
			if not buyBody.Active then
				return
			end
			local id = item.Id
			if kind == "Ladder" then
				local step = Store.NextStep(player, item.Ladder)
				if not step then
					return
				end
				id = step.Id
			end
			buyRemote:FireServer(id)
		end)
		ref.Refresh()
		return ref
	end

	-- --- The Starter Pack card (full width) ---
	local function buildStarter(parent: Instance, height: number, order: number)
		local item = Store.Product("StarterPack")
		local holder, card, scale = cardShell(parent, "StarterPack", UDim2.new(1, 0, 0, height), 20, order)
		local art = make(
			"CanvasGroup",
			{ Name = "Art", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 },
			card
		)
		corner(art, 17)
		local glow = make("Frame", { BackgroundColor3 = C.Lime, Size = UDim2.fromScale(1, 1) }, art)
		fade(glow, { { 0, 0.7 }, { 0.55, 1 }, { 1, 1 } }, 70)
		local dots = halftone(art, C.Lime, 0.72, 9)
		fade(dots, { { 0, 1 }, { 0.35, 1 }, { 1, 0 } }, 25)
		image(art, "Gem", 54, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -150, 0, -14),
			Rotation = 18,
			ImageTransparency = 0.84,
		})
		image(art, "Coin", 60, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -96, 1, 16),
			Rotation = -14,
			ImageTransparency = 0.86,
		})
		image(art, "BallDumpster", 130, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 28, 0, -30),
			Rotation = 22,
			ImageTransparency = 0.84,
		})
		-- Lime inner frame (3 px) with an ink line (2 px) inside it
		innerRing(card, C.Lime, 3, 0, 17, 3)
		innerRing(card, C.Ink, 2, 3, 17, 3)

		local body = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, card)
		pad(body, 11, 13, 11, 11)
		-- The ball disc with a cyan glow
		local glowDisc = make("Frame", {
			BackgroundColor3 = C.Cyan,
			BackgroundTransparency = 0.55,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, 56, 0.5, 0),
			Size = UDim2.fromOffset(150, 150),
			ZIndex = 3,
		}, body)
		corner(glowDisc, 75)
		make("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.4),
				NumberSequenceKeypoint.new(0.75, 0.85),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, glowDisc)
		local disc = make("Frame", {
			BackgroundColor3 = C.Track,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(112, 112),
			ZIndex = 4,
		}, body)
		corner(disc, 56)
		innerRing(disc, C.Ink, 3, 0, 56, 5)
		stroke(disc, C.Cyan, 3, 0.67)
		image(
			disc,
			"BallDumpster",
			96,
			{ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), ZIndex = 5 }
		)

		local right = make("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(126, 0),
			Size = UDim2.new(1, -126, 1, 0),
			ZIndex = 4,
		}, body)
		local chip = make("Frame", {
			BackgroundColor3 = C.Lime,
			Size = UDim2.fromOffset(textWidth("ONE TIME ONLY", 10, Enum.Font.GothamBlack) + 20, 18),
			ZIndex = 4,
		}, right)
		corner(chip, 8)
		innerRing(chip, C.Ink, 2, 0, 8, 5)
		local chipText = label(chip, "ONE TIME ONLY", BLACK, 10, C.Ink)
		chipText.Position = UDim2.fromOffset(0, 1)
		local title = label(right, item.Name, HEAD, 30, C.Lime, 7)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Position = UDim2.fromOffset(0, 24)
		title.Size = UDim2.new(1, 0, 0, 30)
		local desc = label(right, item.Text, BOLD, 12, C.Body)
		desc.TextWrapped = true
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.LineHeight = 1.1
		desc.Position = UDim2.fromOffset(0, 58)
		desc.Size = UDim2.new(1, 0, 0, 34)
		make("UISizeConstraint", { MaxSize = Vector2.new(330, 34) }, desc)
		local buyHolder, buyFace, buyBody = chunky(right, {
			Name = "Buy",
			Size = UDim2.fromOffset(124, 50),
			Radius = 16,
			Color = C.Lime,
			Down = C.LimeDown,
			Lip = C.LimeLip,
			LipHeight = 4,
			Drop = 4,
			Outline = 3,
			Highlight = 3,
			HighlightAlpha = 0.55,
			OnDown = function()
				tween(scale, 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 0.985 })
			end,
			OnUp = function()
				tween(scale, 0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
			end,
		})
		buyHolder.AnchorPoint = Vector2.new(1, 1)
		buyHolder.Position = UDim2.new(1, 0, 1, -4)
		local _, amount = priceContent(buyFace, 24, 26, 6, 4)
		amount.Text = formatRobux(item.Robux)
		buyBody.Activated:Connect(function()
			buyRemote:FireServer("StarterPack")
		end)
		local ref = { Holder = holder, Kind = "Starter", Item = item, BuyHolder = buyHolder }
		function ref.Refresh() end
		return ref
	end

	-- --- Header, tabs and the scrolling list, built for the current screen (computer or phone) ---
	local function buildWindow()
		local phone = compact()
		builtFor = phone
		builtWidth = window.Size.X.Offset
		content:ClearAllChildren()
		table.clear(chipValues)
		table.clear(tabButtons)
		table.clear(cardRefs)
		table.clear(sectionHeaders)
		setWindowRadius(if phone then 22 else 26)
		windowDrop.Position = UDim2.fromOffset(0, if phone then 6 else 8)

		local layout = list(content, false, 0, Enum.VerticalAlignment.Top)
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		local headerHeight = if phone then 56 else 64

		-- Header row: STORE (+ tabs on phones) on the left, the boosts chip and X on the right
		local header = make("Frame", {
			Name = "Header",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, headerHeight),
			LayoutOrder = 1,
		}, content)
		if phone then
			pad(header, 6, 8, 6, 16)
		else
			pad(header, 12, 14, 8, 20)
		end
		local left = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, header)
		list(left, true, 10)
		local rightSide = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, header)
		local rightLayout = list(rightSide, true, if phone then 10 else 12)
		rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

		local titleSize = if phone then 30 else 40
		local title = label(left, "STORE", HEAD, titleSize, C.Gold, if phone then 7 else 8)
		title.Size = UDim2.new(0, textWidth("STORE", titleSize, Enum.Font.LuckiestGuy) + 4, 1, 0)
		title.Position = UDim2.fromOffset(0, if phone then 5 else 6)
		title.LayoutOrder = 1

		local function makeTabs(parent: Instance, height: number, size: number, padX: number)
			for i, tab in { { "boosts", "BOOSTS" }, { "passes", "PASSES" }, { "gems", "GEMS" } } do
				local holder, face, body, fill = chunky(parent, {
					Name = "Tab_" .. tab[1],
					Size = UDim2.fromOffset(textWidth(tab[2], size, Enum.Font.LuckiestGuy) + padX * 2, height),
					Radius = 12,
					Color = C.Card,
					Lip = C.Card,
					LipHeight = 0,
					Drop = 3,
					Outline = 2.5,
					Highlight = 0,
					HighlightAlpha = 0,
				})
				holder.LayoutOrder = i
				local text = label(face, tab[2], HEAD, size, C.Body)
				text.Position = UDim2.fromOffset(0, 2)
				body.Activated:Connect(function()
					jump(tab[1])
				end)
				tabButtons[tab[1]] = { Holder = holder, Fill = fill, Body = body, Text = text }
			end
		end
		if phone then
			local tabs =
				make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(300, 44), LayoutOrder = 2 }, left)
			pad(tabs, 0, 0, 0, 6)
			list(tabs, true, 6)
			makeTabs(tabs, 44, 15, 14)
		end

		-- The current boosts chip: COINS x4  XP x2
		local chip = make("Frame", {
			Name = "Boosts",
			BackgroundColor3 = C.Card,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, if phone then 30 else 33),
			LayoutOrder = 1,
		}, rightSide)
		corner(chip, 12)
		stroke(chip, C.Ink, 2.5)
		pad(chip, 0, if phone then 10 else 12, 0, if phone then 10 else 12)
		list(chip, true, if phone then 5 else 6)
		local function chipPart(text: string, order: number, font: Font, size: number, color: Color3, outline: number?)
			local part = label(chip, text, font, size, color, outline)
			part.AutomaticSize = Enum.AutomaticSize.X
			part.Size = UDim2.fromScale(0, 1)
			part.LayoutOrder = order
			return part
		end
		chipPart("COINS", 1, BLACK, if phone then 10 else 11, C.Body)
		chipValues.Coins = chipPart("", 2, NUM, if phone then 16 else 18, C.Gold, 4)
		make(
			"Frame",
			{ BackgroundTransparency = 1, Size = UDim2.fromOffset(if phone then 1 else 2, 1), LayoutOrder = 3 },
			chip
		)
		chipPart("XP", 4, BLACK, if phone then 10 else 11, C.Body)
		chipValues.Xp = chipPart("", 5, NUM, if phone then 16 else 18, C.Cyan, 4)

		-- Close: red X
		local closeHolder, closeFace, closeBody = chunky(rightSide, {
			Name = "Close",
			Size = UDim2.fromOffset(44, 44),
			Radius = 12,
			Color = C.Red,
			Lip = C.RedLip,
			LipHeight = 4,
			Drop = if phone then 3 else 4,
			Outline = 3,
			Highlight = 3,
			HighlightAlpha = 0.4,
		})
		closeHolder.LayoutOrder = 2
		local x = label(closeFace, "X", HEAD, if phone then 24 else 26, C.White, 6)
		x.Position = UDim2.fromOffset(0, 1)
		closeBody.Activated:Connect(function()
			StoreController.Close()
		end)

		-- Studio line (test builds only)
		local studioHeight = 0
		if Store.IsPreview() then
			studioHeight = if phone then 18 else 22
			local line = make("Frame", {
				Name = "StudioLine",
				BackgroundColor3 = C.Lime,
				BorderSizePixel = 0,
				Size = UDim2.new(1, 0, 0, studioHeight),
				LayoutOrder = 2,
			}, content)
			make("Frame", { BackgroundColor3 = C.Ink, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2) }, line)
			make("Frame", {
				BackgroundColor3 = C.Ink,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 2),
			}, line)
			label(line, "STUDIO PREVIEW: buying is free and fake", BLACK, if phone then 10 else 11, C.Ink)
		end

		-- Tabs row (computers)
		local tabsHeight = 0
		if not phone then
			tabsHeight = 57
			local tabs = make(
				"Frame",
				{ Name = "Tabs", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, tabsHeight), LayoutOrder = 3 },
				content
			)
			pad(tabs, 10, 20, 8, 20)
			list(tabs, true, 8, Enum.VerticalAlignment.Top)
			makeTabs(tabs, 36, 16, 16)
		end

		-- The scrolling list
		local list_ = make("ScrollingFrame", {
			Name = "Items",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, -(headerHeight + studioHeight + tabsHeight)),
			LayoutOrder = 4,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 5,
			ScrollBarImageColor3 = C.CardRing,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			VerticalScrollBarInset = Enum.ScrollBarInset.Always,
		}, content)
		scroller = list_
		local padL, padR = if phone then 14 else 20, if phone then 7 else 11
		pad(list_, 4, padR, if phone then 14 else 18, padL)
		local gap = if phone then 10 else 12
		list(list_, false, gap, Enum.VerticalAlignment.Top)
		list_:GetPropertyChangedSignal("CanvasPosition"):Connect(onScroll)

		local innerWidth = builtWidth - 8 - padL - padR - 5
		local colWidth = math.floor((innerWidth - gap) / 2)
		local order = 0
		local function nextOrder()
			order += 1
			return order
		end
		local function sectionHeader(id: string, text: string)
			local size = if phone then 16 else 18
			local row = make("Frame", {
				Name = "Section_" .. id,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, size + 10),
				LayoutOrder = nextOrder(),
			}, list_)
			local wordWidth = textWidth(text, size, Enum.Font.LuckiestGuy)
			local word = label(row, text, HEAD, size, C.White, 5)
			word.Size = UDim2.new(0, wordWidth + 4, 1, 0)
			word.Position = UDim2.fromOffset(0, 5)
			word.TextXAlignment = Enum.TextXAlignment.Left
			local rule = make("Frame", {
				BackgroundColor3 = C.Card,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, 0, 0.5, 4),
				Size = UDim2.new(1, -(wordWidth + 14), 0, 3),
			}, row)
			corner(rule, 2)
			sectionHeaders[id] = row
		end
		-- Height a card needs for its description at this width
		local function cardHeight(kind: string, item, width: number): number
			local text = item.Text or ""
			if kind == "Ladder" then
				text = "Your coins boost is at the top: x2. All done!"
			end
			return math.max(150, 10 + 24 + 58 + 6 + textHeight(text, 12, width - 24) + 6 + 48 + 12)
		end
		local function cardRow(cards)
			local row = make("Frame", { BackgroundTransparency = 1, LayoutOrder = nextOrder() }, list_)
			list(row, true, gap, Enum.VerticalAlignment.Top)
			local full = #cards == 1
			local width = if full then innerWidth else colWidth
			local height = 0
			for _, c in cards do
				height = math.max(height, cardHeight(c[1], c[2], width))
			end
			row.Size = UDim2.new(1, 0, 0, height + 4)
			for i, c in cards do
				local size = if full then UDim2.new(1, 0, 0, height) else UDim2.fromOffset(width, height)
				table.insert(cardRefs, buildCard(row, c[1], c[2], size, i))
			end
		end

		if (player:GetAttribute("StarterPack") or 0) == 0 and Store.Product("StarterPack") then
			local row = make("Frame", {
				Name = "StarterRow",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 180),
				LayoutOrder = nextOrder(),
			}, list_)
			table.insert(cardRefs, buildStarter(row, 176, 1))
		end
		sectionHeader("boosts", "BOOSTS")
		cardRow({ { "Ladder", { Ladder = "Coins" } }, { "Ladder", { Ladder = "Xp" } } })
		sectionHeader("passes", "GAME PASSES")
		local passItems = {}
		for _, pass in MONEY.Passes do
			table.insert(passItems, { "Pass", pass })
		end
		-- 2X COINS 15 MIN ends the PASSES section (its cyan BOOST label sets it apart)
		local timed = Store.Product("CoinBoost")
		if timed then
			table.insert(passItems, { "Product", timed })
		end
		for i = 1, #passItems, 2 do
			cardRow(if passItems[i + 1] then { passItems[i], passItems[i + 1] } else { passItems[i] })
		end
		sectionHeader("gems", "GEMS")
		local gems = {}
		for _, product in MONEY.Products do
			if product.Gems and not product.Once then
				table.insert(gems, { "Product", product })
			end
		end
		-- Pairs; an odd last one goes full width to close the grid (the biggest chest)
		for i = 1, #gems, 2 do
			cardRow(if gems[i + 1] then { gems[i], gems[i + 1] } else { gems[i] })
		end
		setActiveTab("boosts")
	end

	local function refreshCards()
		for _, ref in cardRefs do
			ref.Refresh()
		end
		if chipValues.Coins then
			chipValues.Coins.Text = Store.MultText(Store.BoostMultiplier(player))
			chipValues.Xp.Text = Store.MultText(Store.XpBoostMultiplier(player))
		end
	end

	-- Size and place the window for this screen; rebuild its contents if it switched between computer and phone
	local function placeWindow()
		local screen = overlay.AbsoluteSize
		if screen.X <= 0 then
			return
		end
		local phone = compact()
		if phone then
			-- 16 px from the sides, just under the Roblox bar
			window.Size = UDim2.fromOffset(math.min(812, screen.X - 32), math.min(346, screen.Y - 50))
			window.AnchorPoint = Vector2.new(0.5, 0)
			window.Position = UDim2.new(0.5, 0, 0, 40)
		else
			window.Size = UDim2.fromOffset(640, 520)
			window.AnchorPoint = Vector2.new(0.5, 0.5)
			window.Position = UDim2.fromScale(0.5, 0.5)
		end
		if builtFor ~= phone or builtWidth ~= window.Size.X.Offset then
			buildWindow()
			refreshCards()
		end
	end

	-- ===== Open / close (Animation notes: STORE OPEN / CLOSE) =====
	local modalCount = 0
	local function showBackdrop()
		modalCount += 1
		backdrop.Visible = true
		tween(backdrop, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { BackgroundTransparency = 0.45 })
	end
	local function hideBackdrop()
		modalCount = math.max(0, modalCount - 1)
		if modalCount == 0 then
			tween(backdrop, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { BackgroundTransparency = 1 }).Completed:Once(
				function()
					if modalCount == 0 then
						backdrop.Visible = false
					end
				end
			)
		end
	end
	local function openPanel(frame: GuiObject, group: CanvasGroup)
		local scale = scaleOf(frame)
		scale.Scale = 0.8
		group.GroupTransparency = 1
		frame.Visible = true
		tween(scale, 0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
		tween(group, 0.12, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, { GroupTransparency = 0 })
	end
	local function closePanel(frame: GuiObject, group: CanvasGroup, stillClosed: () -> boolean)
		tween(scaleOf(frame), 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { Scale = 0.9 })
		tween(group, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In, { GroupTransparency = 1 }).Completed:Once(
			function()
				if stillClosed() then
					frame.Visible = false
				end
			end
		)
	end

	function StoreController.Open()
		if isOpen then
			return
		end
		isOpen = true
		seenStore = true
		if buttonParts.Dot then
			buttonParts.Dot.Visible = false
		end
		placeWindow()
		refreshCards()
		showBackdrop()
		openPanel(window, panel)
		if scroller then
			scroller.CanvasPosition = Vector2.new()
		end
		setActiveTab("boosts")
	end
	function StoreController.Close()
		if not isOpen then
			return
		end
		isOpen = false
		hideBackdrop()
		closePanel(window, panel, function()
			return not isOpen
		end)
	end
	function StoreController.Toggle()
		if isOpen then
			StoreController.Close()
		else
			StoreController.Open()
		end
	end

	-- ===== Starter Pack popup =====
	local starter = Store.Product("StarterPack")
	local popupOpen = false
	local popup, popupGroup, popupContent = panelShell(overlay, "StarterPopup", 24, 4, C.Lime, 3, 6)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.Position = UDim2.fromScale(0.5, 0.5)
	popup.Size = UDim2.fromOffset(360, 220)
	-- ...and an ink line inside the lime frame
	innerRing(popupGroup, C.Ink, 2, 7, 24, 20)
	local popupBody =
		make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6 }, popupContent)
	pad(popupBody, 8, 10, 10, 10) -- the design's 12/14/14 padding, less the 4 px outline
	local popupTitle = label(popupBody, "STARTER PACK", HEAD, 28, C.Lime, 7)
	popupTitle.TextXAlignment = Enum.TextXAlignment.Left
	popupTitle.Position = UDim2.fromOffset(4, 5)
	popupTitle.Size = UDim2.new(1, -50, 0, 40)
	local popupCloseHolder, popupCloseFace, popupCloseBody = chunky(popupBody, {
		Name = "Close",
		Size = UDim2.fromOffset(44, 44),
		Radius = 12,
		Color = C.Grey,
		Lip = C.GreyLip,
		LipHeight = 3,
		Drop = 3,
		Outline = 3,
		Highlight = 0,
		HighlightAlpha = 0,
	})
	popupCloseHolder.AnchorPoint = Vector2.new(1, 0)
	popupCloseHolder.Position = UDim2.new(1, 4, 0, -2)
	local popupX = label(popupCloseFace, "X", HEAD, 22, C.White, 5)
	popupX.Position = UDim2.fromOffset(0, 2)
	-- Three reward tiles
	local tiles = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 1, -48 - 8 - 52),
	}, popupBody)
	local tileRefs = {}
	for i, tile in
		{ { "BallDumpster", "DUMPSTER DIAMOND" }, { "Boost15", "30 MIN 2X COINS" }, { "Gems60", "100 GEMS" } }
	do
		local frame = make("Frame", {
			BackgroundColor3 = C.Card,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new((i - 1) / 3 + 1 / 6, 0, 0.5, 0),
			Size = UDim2.new(1 / 3, -6, 1, 0),
		}, tiles)
		corner(frame, 14)
		innerRing(frame, C.Ink, 2.5, 0, 14, 5)
		image(frame, tile[1], 44, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, -31) })
		local caption = label(frame, tile[2], BLACK, 10, C.White)
		caption.AnchorPoint = Vector2.new(0.5, 0)
		caption.Position = UDim2.new(0.5, 0, 0.5, 16)
		caption.Size = UDim2.new(1, -8, 0, 22)
		caption.TextWrapped = true
		caption.TextYAlignment = Enum.TextYAlignment.Top
		tileRefs[i] = frame
	end
	-- Buy + NO THANKS, same size
	local popupBuyHolder, popupBuyFace, popupBuyBody = chunky(popupBody, {
		Name = "Buy",
		Size = UDim2.new(0.5, -5, 0, 48),
		Radius = 14,
		Color = C.Lime,
		Down = C.LimeDown,
		Lip = C.LimeLip,
		LipHeight = 4,
		Drop = 4,
		Outline = 3,
		Highlight = 3,
		HighlightAlpha = 0.55,
	})
	popupBuyHolder.AnchorPoint = Vector2.new(0, 1)
	popupBuyHolder.Position = UDim2.new(0, 0, 1, -4)
	local _, popupAmount = priceContent(popupBuyFace, 22, 24, 6, 4)
	popupAmount.Text = if starter then formatRobux(starter.Robux) else ""
	local popupNoHolder, popupNoFace, popupNoBody = chunky(popupBody, {
		Name = "NoThanks",
		Size = UDim2.new(0.5, -5, 0, 48),
		Radius = 14,
		Color = C.Grey,
		Lip = C.GreyLip,
		LipHeight = 4,
		Drop = 4,
		Outline = 3,
		Highlight = 3,
		HighlightAlpha = 0.25,
	})
	popupNoHolder.AnchorPoint = Vector2.new(1, 1)
	popupNoHolder.Position = UDim2.new(1, 0, 1, -4)
	local noText = label(popupNoFace, "NO THANKS", HEAD, 19, C.White, 5)
	noText.Position = UDim2.fromOffset(0, 1)
	noText.Size = UDim2.new(1, 0, 1, -4)

	local function closePopup()
		if not popupOpen then
			return
		end
		popupOpen = false
		hideBackdrop()
		closePanel(popup, popupGroup, function()
			return not popupOpen
		end)
	end
	popupBuyBody.Activated:Connect(function()
		buyRemote:FireServer("StarterPack")
		closePopup()
	end)
	popupNoBody.Activated:Connect(closePopup)
	popupCloseBody.Activated:Connect(closePopup)

	-- Tapping the dark backdrop or gamepad B closes whatever is open
	local function closeTop()
		if popupOpen then
			closePopup()
		elseif isOpen then
			StoreController.Close()
		end
	end
	backdrop.Activated:Connect(closeTop)
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonB then
			closeTop()
		end
	end)

	local lastThrow = 0
	remotes:WaitForChild("ThrowResult").OnClientEvent:Connect(function(info)
		if type(info) == "table" and info.UserId == player.UserId then
			lastThrow = os.clock()
		end
	end)
	remotes:WaitForChild("StarterOffer").OnClientEvent:Connect(function()
		if not starter then
			return
		end
		-- A quiet moment: a few seconds after your last throw, not holding the throw button
		while
			os.clock() - lastThrow < MONEY.QuietSeconds
			or UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		do
			task.wait(0.5)
		end
		if (player:GetAttribute("StarterPack") or 0) == 0 and not popupOpen then
			popupOpen = true
			showBackdrop()
			openPanel(popup, popupGroup)
			for i, tile in tileRefs do
				local scale = scaleOf(tile)
				scale.Scale = 0
				task.delay(0.12 + 0.06 * (i - 1), function()
					tween(scale, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
				end)
			end
		end
	end)

	-- ===== THANK YOU / VIP DAILY GIFT toast =====
	local toast = make("CanvasGroup", {
		Name = "Toast",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(340, 68),
		Visible = false,
		ZIndex = 20,
	}, gui)
	local toastDrop = make(
		"Frame",
		{ BackgroundColor3 = C.Ink, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 64) },
		toast
	)
	corner(toastDrop, 18)
	local toastBody = make("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 64), ZIndex = 2 }, toast)
	corner(toastBody, 18)
	innerRing(toastBody, C.Ink, 3, 0, 18, 6)
	local _, toastRing = innerRing(toastBody, C.Lime, 2, 3, 18, 6)
	local iconTile = make("Frame", {
		BackgroundColor3 = C.Panel,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		ZIndex = 4,
	}, toastBody)
	corner(iconTile, 14)
	innerRing(iconTile, C.Ink, 2.5, 0, 14, 6)
	local toastIcon = image(iconTile, "Gift", 38, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 5,
	})
	local toastTitle = label(toastBody, "THANK YOU!", HEAD, 24, C.Lime, 6)
	toastTitle.TextXAlignment = Enum.TextXAlignment.Left
	toastTitle.Position = UDim2.fromOffset(66, 10)
	toastTitle.Size = UDim2.new(1, -80, 0, 24)
	local toastLine = label(toastBody, "", BLACK, 13, C.White)
	toastLine.TextXAlignment = Enum.TextXAlignment.Left
	toastLine.TextTruncate = Enum.TextTruncate.AtEnd
	toastLine.Position = UDim2.fromOffset(66, 36)
	toastLine.Size = UDim2.new(1, -80, 0, 16)
	local confettiLayer = make("Frame", {
		Name = "ToastConfetti",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 0),
		ZIndex = 21,
	}, gui)
	local CONFETTI = { C.Pink, C.Cyan, C.Lime, C.Gold, C.Red }

	-- Under the level bar, top centre
	local function toastTarget(): number
		return rankBar.AbsolutePosition.Y
			- gui.AbsolutePosition.Y
			+ rankBar.AbsoluteSize.Y
			+ (if compact() then 8 else 20)
	end

	local function confetti(y: number)
		confettiLayer.Position = UDim2.new(0.5, 0, 0, y + 32)
		for _ = 1, 12 do
			local w = math.random(7, 10)
			local bit = make("Frame", {
				BackgroundColor3 = CONFETTI[math.random(#CONFETTI)],
				AnchorPoint = Vector2.new(0.5, 0.5),
				Size = UDim2.fromOffset(w, if math.random() < 0.5 then w else w + 5),
				Rotation = math.random(0, 360),
				ZIndex = 21,
			}, confettiLayer)
			if math.random() < 0.4 then
				corner(bit, w)
			end
			local edge = stroke(bit, C.Ink, 2)
			tween(bit, 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
				Position = UDim2.fromOffset(math.random(-190, 190), math.random(-50, 110)),
			})
			tween(bit, 0.9, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, {
				Rotation = bit.Rotation + (if math.random() < 0.5 then -360 else 360),
			})
			task.delay(0.55, function()
				tween(bit, 0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, { BackgroundTransparency = 1 })
				tween(edge, 0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, { Transparency = 1 })
			end)
			task.delay(0.95, function()
				bit:Destroy()
			end)
		end
	end

	-- BUY SUCCESS on the card: the price button pops, a white flash, the new ladder dot pops, the Starter card goes
	local function celebrate(id: string)
		for _, ref in cardRefs do
			local item = ref.Item
			local match = item.Id == id
				or (ref.Kind == "Ladder" and string.sub(id, 1, #item.Ladder + 6) == item.Ladder .. "Ladder")
			if match and ref.Holder.Parent then
				local scale = scaleOf(ref.BuyHolder)
				tween(scale, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 1.15 }).Completed:Once(
					function()
						tween(scale, 0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1 })
					end
				)
				if ref.Flash then
					ref.Flash.BackgroundTransparency = 0.4
					tween(
						ref.Flash,
						0.3,
						Enum.EasingStyle.Linear,
						Enum.EasingDirection.Out,
						{ BackgroundTransparency = 1 }
					)
				end
				local level = ref.Level
				if ref.Kind == "Ladder" and level and ref.Dots[level] then
					local dotScale = scaleOf(ref.Dots[level].Frame)
					dotScale.Scale = 0
					tween(dotScale, 0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out, { Scale = 1.3 }).Completed:Once(
						function()
							tween(dotScale, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, { Scale = 1 })
						end
					)
				end
				if ref.Kind == "Starter" then
					local row = ref.Holder.Parent
					tween(scaleOf(ref.Holder), 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In, { Scale = 0 }).Completed:Once(
						function()
							row:Destroy()
						end
					)
				end
			end
		end
	end

	local toastId = 0
	remotes:WaitForChild("StoreResult").OnClientEvent:Connect(function(info)
		local vip = info.Title ~= nil
		local id = tostring(info.Id)
		local iconName = if vip
			then "Gem"
			elseif string.sub(id, 1, 10) == "CoinLadder" then "BoostCoin"
			elseif string.sub(id, 1, 8) == "XpLadder" then "BoostXp"
			else ICONS[id] or "Gift"
		toastIcon.Image = AssetSlots.Image(iconName)
		toastTitle.Text = if vip then tostring(info.Title) else "THANK YOU!"
		toastTitle.TextColor3 = if vip then C.Gold else C.Lime
		toastRing.Color = if vip then C.Gold else C.Lime
		toastLine.Text = tostring(info.Text or "")
		refreshCards()
		refreshPills(true)
		if not vip then
			celebrate(id)
		end
		-- In from above with a little tilt, hold 3 s, out
		local y = toastTarget()
		toast.Position = UDim2.new(0.5, 0, 0, -80)
		toast.Rotation = -4
		toast.GroupTransparency = 0
		toast.Visible = true
		tween(toast, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out, {
			Position = UDim2.new(0.5, 0, 0, y),
			Rotation = 0,
		})
		task.delay(0.15, confetti, y)
		Sfx.Play("Reveal", 1.1)
		toastId += 1
		local mine = toastId
		task.delay(3.3, function()
			if toastId == mine then
				tween(toast, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {
					Position = UDim2.new(0.5, 0, 0, -80),
					GroupTransparency = 1,
				}).Completed:Once(function()
					if toastId == mine then
						toast.Visible = false
					end
				end)
			end
		end)
	end)

	-- ===== Keep everything in step with the player's purchases and the screen =====
	player:GetAttributeChangedSignal("StarterPack"):Connect(function()
		if (player:GetAttribute("StarterPack") or 0) > 0 then
			closePopup()
		end
	end)
	player:GetAttributeChangedSignal("Passes"):Connect(refreshCards)
	for _, key in Store.LadderKeys do
		player:GetAttributeChangedSignal(key):Connect(function()
			refreshCards()
			refreshPills(true)
		end)
	end

	-- Once the pictures are loaded, nudge every CanvasGroup so it redraws with them
	redraw = function()
		local groups = {}
		for _, root in { gui, overlay } do
			for _, d in root:GetDescendants() do
				if d:IsA("CanvasGroup") then
					table.insert(groups, d)
				end
			end
		end
		for _, pill in pills do
			for _, d in pill.Holder:GetDescendants() do
				if d:IsA("CanvasGroup") then
					table.insert(groups, d)
				end
			end
		end
		for _, group in groups do
			local color = group.GroupColor3
			group.GroupColor3 = Color3.new(0.99, 0.99, 0.99)
			task.defer(function()
				group.GroupColor3 = color
			end)
		end
	end
	if preloaded then
		redraw()
	end

	local function layout()
		local phone = compact()
		if buttonParts.Holder == nil or (buttonParts.Holder.Size.X.Offset == 44) ~= phone then
			buildButton()
		end
		placeButton()
		if pillPhone ~= phone then
			buildPills()
			refreshPills(false)
		end
		placePills(false)
		if isOpen then
			placeWindow()
		end
	end
	rankBar:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout)
	rankBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	bar:GetPropertyChangedSignal("Position"):Connect(function()
		placePills(false)
	end)
	bar:GetPropertyChangedSignal("Size"):Connect(function()
		placePills(false)
	end)
	layout()
end

return StoreController
