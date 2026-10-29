-- The crate shop (cards with price, guarantee bar, BUY and ODDS), the odds view, and the crate opening (intro, reel,
-- reveal). Looks = the owner's Crate Kit (claude.ai/design 'Strike Legends Crate Design', 2026-10-26; Modules/CrateKit).
-- The shop opens from the lobby kiosk (zone 2 crates) and the zone 3/4 crate counters (that zone's crates); Rizzo and
-- the kiosk stations buy straight away. Everything is built in code; the Studio frames BallsUI.Shop and
-- BallsUI.Opening are kept as empty full-screen holders because other screens check whether they're visible.
-- The server picks the ball; the reel only shows what the server already decided.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local Balls = require(Shared.Modules.Balls)
local Store = require(Shared.Modules.Store)
local Zones = require(Shared.Modules.Zones)
local CollectionBookController = require(script.Parent.CollectionBookController)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local UiKit = require(Modules.UiKit)
local BallView = require(Modules.BallView)
local CrateKit = require(Modules.CrateKit)
local RewardKit = require(Modules.RewardKit)

local player = Players.LocalPlayer

local C = CrateKit.C
local make = CrateKit.Make
local tween = CrateKit.Tween
local Head, Num, Body = CrateKit.Head, CrateKit.Num, CrateKit.Body
local SHOP = Config.CrateShop

local REEL_TILES = 36 -- tiles on the reel
local REEL_WIN_INDEX = 30 -- the tile that holds the real result
local LEGENDARY_INDEX = 5 -- Legendary and better get the big reveal (2nd ray layer, confetti, longer reel)

local CrateController = {}
-- Fires (crate, result) after a bought crate finished its opening (Rizzo reacts to rare pulls)
CrateController.Opened = Instance.new("BindableEvent")

-- What this crate costs you right now (the first crate you buy is cheaper: Balls.CratePrice)
function CrateController.Price(crate): number
	return Balls.CratePrice(crate, player:GetAttribute("CratesBought"))
end

-- How much off this crate is for you right now (93 = 93% off: your first crate), or nil at the normal price
function CrateController.Discount(crate): number?
	local price = CrateController.Price(crate)
	if price >= crate.Price or crate.Price <= 0 then
		return nil
	end
	return math.floor((1 - price / crate.Price) * 100 + 0.5)
end

-- Every number on screen uses the shared formatter (Config.Numbers)
local formatNumber = Currency.Format

-- Locked crates (their zone isn't open yet) can't be opened
function CrateController.Locked(crate): boolean
	return not Zones.CrateUnlocked(crate, player:GetAttribute("ZonesOpen"))
end

-- "UNLOCKS IN NEON LANES" + the rebirths it opens at
function CrateController.LockText(crate): (string, string)
	local zone = crate.Zone or 1
	return ("UNLOCKS IN %s"):format(Zones.Name(zone):upper()),
		("ZONE %d  ·  NEEDS %s"):format(zone, Zones.NeedText(zone))
end

-- A random ball using the crate's odds, for the filler tiles on the reel
local function randomBall(crate)
	local roll = math.random() * 100
	local rarityName = Config.Rarities[1].Name
	for _, rarity in Config.Rarities do
		roll -= crate.Odds[rarity.Name] or 0
		if roll <= 0 then
			rarityName = rarity.Name
			break
		end
	end
	local pool = {}
	for _, ball in Config.Balls do
		if ball.Rarity == rarityName and Zones.BallInCrate(ball, crate) then
			table.insert(pool, ball)
		end
	end
	if #pool == 0 then
		for _, ball in Config.Balls do
			if Zones.BallInCrate(ball, crate) then
				table.insert(pool, ball)
			end
		end
	end
	return pool[math.random(#pool)]
end

-- The crate's strongest guarantee (the pity row with the best rarity), or nil
local function bestPity(crate)
	local best = nil
	for _, row in Balls.PityRows(crate.Id) do
		if not best or Balls.RarityIndex(row.Rarity) > Balls.RarityIndex(best.Rarity) then
			best = row
		end
	end
	return best
end

-- Pulls left (this one included) until a pity row of a crate guarantees its rarity
local function pullsLeft(row): number
	return math.max(row.After - (player:GetAttribute("Pity_" .. row.Key) or 0), 1)
end

local function hexOf(color: Color3): string
	return "#" .. color:ToHex()
end

-- "BRONZE CRATE" -> "BRONZE" (phone headers)
local function shortName(crate): string
	return (crate.Name:upper():gsub("%s*CRATE$", ""))
end

function CrateController:Start()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("BallsUI") :: ScreenGui
	local shop = gui:WaitForChild("Shop") :: Frame
	local opening = gui:WaitForChild("Opening") :: Frame
	local toast = gui:WaitForChild("Toast") :: TextLabel
	local openCrate = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("OpenCrate") :: RemoteFunction
	local equipRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EquipBall") :: RemoteEvent
	local crateModels = ReplicatedStorage:WaitForChild("CrateModels", 10)
	local INTRO = SHOP.Intro

	-- The old Studio-built shop and opening screens become empty full-screen holders
	for _, holder in { shop, opening } do
		for _, child in holder:GetChildren() do
			if child:IsA("GuiObject") or child:IsA("UIComponent") then
				child:Destroy()
			end
		end
		holder.AnchorPoint = Vector2.zero
		holder.Position = UDim2.new()
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundTransparency = 1
		holder.Visible = false
	end
	shop.Active = true -- taps on the shop don't fall through to the throw meter
	opening.ZIndex = 30

	local busy = false
	-- Messages ("NOT ENOUGH COINS", "ALSO GOT: ..."): the kit's navy toast at the top centre (UI pass batch 3); the
	-- old Studio toast label stays hidden
	toast.Visible = false
	local kitToast = RewardKit.Toast(gui)
	local function showToast(text: string)
		local message = text:upper()
		local problem = message:find("NOT ENOUGH") or message:find("TRY AGAIN") or message:find("LOCK")
		kitToast(
			message,
			if message:find("COINS") then "Coins" else nil,
			nil,
			if problem then UiKit.C.Price else UiKit.C.White,
			2
		)
	end

	-- Free crates (from strikes and Golden Pins) are used before coins on their crate type
	local function hasFree(crate): boolean
		return crate.Id == Config.FreeCrates.CrateId and (player:GetAttribute("FreeCrates") or 0) > 0
	end
	CrateController.HasFree = hasFree

	-- The crate's 3D model (ReplicatedStorage.CrateModels, the kiosk designs) standing in a viewport
	local function crateView(crate, parent: GuiObject): ViewportFrame
		local view = make("ViewportFrame", {
			Name = "CrateArt",
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Ambient = Color3.fromRGB(200, 200, 220),
			LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-1, -1.5, -1),
			ZIndex = parent.ZIndex,
		}, parent)
		local camera = make("Camera", { FieldOfView = 30 }, view)
		view.CurrentCamera = camera
		local template = crateModels
			and (crateModels:FindFirstChild(crate.Id) or (crate.Model and crateModels:FindFirstChild(crate.Model)))
		if template then
			local model = template:Clone() :: Model
			model:PivotTo(CFrame.Angles(0, math.rad(INTRO.FaceAngle), 0))
			local box, size = model:GetBoundingBox()
			model.Parent = view
			local radius = math.max(size.X, size.Y, size.Z) * 0.62
			local distance = radius / math.tan(math.rad(15))
			camera.CFrame = CFrame.lookAt(box.Position + Vector3.new(0, 0.35, 1).Unit * distance, box.Position)
		end
		return view
	end

	-- A Block sized to its words (tags, badges, chips)
	local function tag(parent: Instance, text: string, opts): CrateKit.Block
		local width = CrateKit.TextWidth(text, Head, opts.Size) + opts.PadX * 2 + opts.Outline * 2
		local block = CrateKit.Block(parent, {
			W = width,
			H = opts.H,
			Fill = opts.Fill,
			Lip = opts.Lip,
			LipPx = opts.LipPx,
			Radius = opts.Radius,
			Outline = opts.Outline,
		})
		local label = CrateKit.Text(block.Face, text, Head, opts.Size, C.White, opts.Stroke)
		make("UIPadding", { PaddingTop = UDim.new(0, math.floor(opts.Size * 0.1)) }, label)
		return block
	end

	-- Paints a BUY button for this crate: lime BUY / OPEN FREE, grey NEED X MORE, grey locked ZONE n.
	-- Returns true when tapping it should open the crate.
	local function paintBuy(button: CrateKit.Button, crate, phone: boolean): boolean
		local big = if phone then 22 else 32
		if CrateController.Locked(crate) then
			button:Paint(C.Grey, C.GreyLip, C.GreyText)
			button:SetIcon("Lock")
			button.Label.TextSize = if phone then 18 else 26
			button:SetText(("ZONE %d"):format(crate.Zone or 1))
			button:SetPressable(false)
			return false
		end
		button:SetIcon(nil)
		if hasFree(crate) then
			button:Paint(C.Lime, C.LimeLip, C.White)
			button.Label.TextSize = if phone then 15 else 26
			button:SetText(("OPEN FREE (%d)"):format(player:GetAttribute("FreeCrates") or 0))
			button:SetPressable(true)
			return true
		end
		local need = CrateController.Price(crate) - (player:GetAttribute("Coins") or 0)
		if need > 0 then
			button:Paint(C.Grey, C.GreyLip, C.GreyText)
			if phone then
				button.Label.TextSize = 14
				button:SetText(('<font size="11">NEED</font>\n%s MORE'):format(formatNumber(need)))
			else
				button.Label.TextSize = 22
				button:SetText(("NEED %s MORE"):format(formatNumber(need)))
			end
			button:SetPressable(false)
			return false
		end
		button:Paint(C.Lime, C.LimeLip, C.White)
		button.Label.TextSize = big
		button:SetText("BUY")
		button:SetPressable(true)
		return true
	end

	-- Price row: coin, the crossed-out old price on the first-crate deal, the price
	local function priceRow(parent: Instance, coinSize: number, size: number, stroke: number, oldSize: number)
		local row = make("Frame", { Name = "Price", BackgroundTransparency = 1, ZIndex = 2 }, parent)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, math.floor(coinSize * 0.22)),
		}, row)
		local coin = CrateKit.Icon(row, "Coin", coinSize)
		local old = CrateKit.Text(row, "", Num, oldSize, C.Muted, 0)
		old.Name = "Old"
		old.LayoutOrder = 2
		old.AutomaticSize = Enum.AutomaticSize.X
		old.Size = UDim2.new(0, 0, 1, 0)
		make("Frame", {
			Name = "Strike",
			BackgroundColor3 = C.Red,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, 8, 0, math.max(math.floor(oldSize / 5.5), 2)),
			Rotation = -14,
		}, old)
		local price = CrateKit.Text(row, "", Num, size, C.White, stroke)
		price.LayoutOrder = 3
		price.AutomaticSize = Enum.AutomaticSize.X
		price.Size = UDim2.new(0, 0, 1, 0)
		return row, coin, old, price
	end

	-- ================= SHOP =================
	local shopStage = CrateKit.Stage(shop, gui, "Screen")
	local shopBackdrop = make("TextButton", {
		Name = "Backdrop",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, shopStage.Screen)

	local shopZone = 2
	local panel: Frame? = nil
	local panelScale: UIScale? = nil
	local header: { [string]: any } = {}
	local cardArea: Frame? = nil
	local refreshers: { () -> () } = {}
	local loops: { Tween } = {}
	local oddsCrate = nil
	local showOdds: (crate: any, from: GuiObject?) -> ()
	local showCards: (animate: boolean) -> ()
	local buy: (crate: any, backToShop: boolean?) -> ()
	local setOpen: (open: boolean) -> ()

	local function stopLoops()
		for _, t in loops do
			t:Cancel()
		end
		table.clear(loops)
	end

	-- The panel: dark box with the header (title, coin balance) and the red close X
	local function buildPanel()
		if panel then
			panel:Destroy()
		end
		stopLoops()
		table.clear(refreshers)
		shopStage:Fit()
		local phone = shopStage.Phone
		local w, h = if phone then 600 else 900, if phone then 336 else 560
		local o = if phone then 3 else 5
		local p = make("Frame", { Name = "Panel", BackgroundTransparency = 1, Active = true }, shopStage.Stage) :: Frame
		CrateKit.Place(shopStage, p, if phone then 236 else 510, if phone then 46 else 260, w, h)
		local shadow = make("Frame", {
			Name = "Shadow",
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, if phone then 5 else 10),
			Size = UDim2.fromScale(1, 1),
		}, p)
		CrateKit.Corner(shadow, if phone then 20 else 32)
		CrateKit.Block(p, {
			W = w,
			H = h,
			Fill = C.Panel,
			Lip = C.Panel,
			LipPx = 0,
			Radius = if phone then 20 else 32,
			Outline = o,
			Ring = C.PanelLine,
			RingPx = if phone then 2 else 3,
		})
		panel = p
		panelScale = CrateKit.ScaleOf(p)

		-- Title
		local titleBox = make("Frame", { Name = "TitleBox", BackgroundTransparency = 1, ZIndex = 2 }, p)
		if phone then
			titleBox.Position = UDim2.fromOffset(o + 12 + 4, o + 4)
			titleBox.Size = UDim2.fromOffset(360, 48)
		else
			titleBox.Position = UDim2.fromOffset(o + 23 + 6, o + 8)
			titleBox.Size = UDim2.fromOffset(640, 88)
		end
		local title = CrateKit.Title(
			titleBox,
			"CRATES",
			if phone then 30 else 60,
			C.Gold,
			if phone then 2.5 else 4,
			if phone then 3 else 5
		)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.Parent.ZIndex = 2

		-- Coin balance pill
		local pill = make("Frame", {
			Name = "Coins",
			BackgroundColor3 = C.Card,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(1, 0.5),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 2,
		}, p)
		local pillH = if phone then 34 else 54
		local po = if phone then 3 else 4
		pill.Size = UDim2.fromOffset(0, pillH - po * 2)
		pill.Position = if phone
			then UDim2.fromOffset(w - o - 12 - 44 - 10 - po, o + 26)
			else UDim2.fromOffset(w - o - 23 - 36 - po, o + 48)
		CrateKit.Corner(pill, pillH / 2)
		CrateKit.Stroke(pill, C.Ink, po)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, if phone then 6 else 10),
		}, pill)
		make("UIPadding", {
			PaddingLeft = UDim.new(0, if phone then 4 else 8),
			PaddingRight = UDim.new(0, if phone then 14 else 22),
		}, pill)
		CrateKit.Icon(pill, "Coin", if phone then 24 else 40)
		local balance = CrateKit.Text(pill, "", Num, if phone then 18 else 30, C.White, if phone then 2 else 3)
		balance.LayoutOrder = 2
		balance.AutomaticSize = Enum.AutomaticSize.X
		balance.Size = UDim2.new(0, 0, 1, 0)

		-- Close X: off the corner on computers, inside the header on phones
		local close = CrateKit.Button(p, {
			Name = "Close",
			W = if phone then 44 else 68,
			H = if phone then 44 else 68,
			Radius = if phone then 14 else 20,
			Outline = if phone then 3 else 5,
			LipPx = if phone then 5 else 8,
			Fill = C.Red,
			Lip = C.RedLip,
			Icon = "Close",
			IconSize = if phone then 24 else 40,
			Press = if phone then 3 else 4,
		})
		close.Holder.ZIndex = 4
		close.Holder.Position = if phone
			then UDim2.fromOffset(w - o - 12 - 44, o + 4)
			else UDim2.fromOffset(w - 46, -22)
		close.Activated:Connect(function()
			setOpen(false)
		end)

		local area = make("Frame", { Name = "Area", BackgroundTransparency = 1, ZIndex = 2 }, p) :: Frame
		if phone then
			area.Position = UDim2.fromOffset(o + 12, o + 52)
			area.Size = UDim2.fromOffset(w - o * 2 - 24, h - o * 2 - 52 - 12)
		else
			area.Position = UDim2.fromOffset(o + 23, o + 96)
			area.Size = UDim2.fromOffset(w - o * 2 - 46, h - o * 2 - 96 - 23)
		end
		cardArea = area

		local function refreshBalance()
			balance.Text = formatNumber(player:GetAttribute("Coins") or 0)
		end
		refreshBalance()
		table.insert(refreshers, refreshBalance)
		header = { Title = title, Pill = pill, Phone = phone }
	end

	-- One crate card (the kit's CRATE CARD, all its states)
	local function makeCard(crate, phone: boolean): (Frame, () -> ())
		local M = if phone
			then {
				W = 184,
				H = 268,
				O = 3,
				R = 14,
				Lip = 5,
				Pad = 8,
				NameY = 11,
				NameH = 19,
				NameSize = 17,
				NameStroke = 2,
				NameDrop = 2,
				ArtY = 36,
				ArtH = 88,
				ArtR = 10,
				Lock = 40,
				PriceY = 130,
				PriceH = 24,
				Coin = 22,
				PriceSize = 22,
				PriceStroke = 2,
				OldSize = 14,
				PityY = 158,
				PityH = 12,
				PitySize = 10,
				PityStroke = 1,
				BarY = 173,
				BarH = 6,
				BarBorder = 1,
				BtnY = 209,
				BtnH = 44,
			}
			else {
				W = 268,
				H = 431,
				O = 4,
				R = 22,
				Lip = 8,
				Pad = 14,
				NameY = 18,
				NameH = 32,
				NameSize = 28,
				NameStroke = 3,
				NameDrop = 4,
				ArtY = 60,
				ArtH = 128,
				ArtR = 14,
				Lock = 64,
				PriceY = 198,
				PriceH = 40,
				Coin = 36,
				PriceSize = 36,
				PriceStroke = 3,
				OldSize = 22,
				PityY = 246,
				PityH = 16,
				PitySize = 12,
				PityStroke = 1.5,
				BarY = 266,
				BarH = 10,
				BarBorder = 2,
				BtnY = 284,
				BtnH = 60,
			}
		local inner = M.W - (M.O + M.Pad) * 2
		local holder =
			make("Frame", { Name = crate.Id, BackgroundTransparency = 1, Size = UDim2.fromOffset(M.W, M.H) }) :: Frame
		CrateKit.Block(holder, {
			W = M.W,
			H = M.H,
			Fill = C.Card,
			Lip = C.CardLip,
			LipPx = M.Lip,
			Radius = M.R,
			Outline = M.O,
			Ring = C.CardLine,
			RingPx = 2,
		})
		local function at(object: GuiObject, x: number, y: number, w: number, h: number)
			object.Position = UDim2.fromOffset(x, y)
			object.Size = UDim2.fromOffset(w, h)
			object.ZIndex = 2
			object.Parent = holder
		end

		local nameBox = make("Frame", { Name = "NameBox", BackgroundTransparency = 1 })
		at(nameBox, 0, M.NameY, M.W, M.NameH)
		-- Long names ("SKY SILVER CRATE") shrink to fit the card
		local name =
			CrateKit.Title(nameBox, crate.Name:upper(), M.NameSize, CrateKit.Metal(crate), M.NameStroke, M.NameDrop)
		name.TextScaled = true
		name.Parent.Size = UDim2.new(1, -16, 1, 0)
		name.Parent.Position = UDim2.fromOffset(8, 0)

		local art = make("Frame", { Name = "Art", BackgroundColor3 = C.Zebra, BorderSizePixel = 0 })
		at(art, M.O + M.Pad, M.ArtY, inner, M.ArtH)
		CrateKit.Corner(art, M.ArtR)
		crateView(crate, art)
		local lockShade = make("Frame", {
			Name = "Locked",
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 0.4,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
		}, art)
		CrateKit.Corner(lockShade, M.ArtR)
		local lockIcon = CrateKit.Icon(lockShade, "Lock", M.Lock)
		lockIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		lockIcon.Position = UDim2.fromScale(0.5, 0.5)
		lockIcon.ZIndex = 4

		local row, coin, old, price = priceRow(holder, M.Coin, M.PriceSize, M.PriceStroke, M.OldSize)
		at(row, 0, M.PriceY, M.W, M.PriceH)

		local pityText = CrateKit.Text(nil, "", Body, M.PitySize, C.White, M.PityStroke)
		pityText.Name = "Pity"
		at(pityText, M.O + M.Pad - 4, M.PityY, inner + 8, M.PityH)
		local track = make("Frame", { Name = "Bar", BackgroundColor3 = C.Ink, BorderSizePixel = 0 })
		at(track, M.O + M.Pad, M.BarY, inner, M.BarH)
		CrateKit.Corner(track, M.BarH / 2)
		local fill = make("Frame", {
			Name = "Fill",
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(M.BarBorder, M.BarBorder),
			Size = UDim2.new(0, 0, 1, -M.BarBorder * 2),
		}, track)
		CrateKit.Corner(fill, (M.BarH - M.BarBorder * 2) / 2)

		local buyButton, oddsButton
		if phone then
			buyButton = CrateKit.Button(holder, {
				Name = "Buy",
				W = M.W - (M.O + M.Pad) * 2 - 50,
				H = 44,
				Radius = 12,
				Outline = 3,
				LipPx = 5,
				Fill = C.Lime,
				Lip = C.LimeLip,
				Text = "BUY",
				Size = 22,
				Stroke = 2,
				IconSize = 18,
				Gap = 4,
				Press = 3,
			})
			buyButton.Holder.Position = UDim2.fromOffset(M.O + M.Pad, M.BtnY)
			oddsButton = CrateKit.Button(holder, {
				Name = "Odds",
				W = 44,
				H = 44,
				Radius = 12,
				Outline = 3,
				LipPx = 5,
				Fill = C.Cyan,
				Lip = C.CyanLip,
				Icon = "Odds",
				IconSize = 24,
				Press = 3,
			})
			oddsButton.Holder.Position = UDim2.fromOffset(M.W - M.O - M.Pad - 44, M.BtnY)
			buyButton.Label.LineHeight = 0.9
		else
			buyButton = CrateKit.Button(holder, {
				Name = "Buy",
				W = 232,
				H = 60,
				Radius = 16,
				Outline = 4,
				LipPx = 8,
				Fill = C.Lime,
				Lip = C.LimeLip,
				Text = "BUY",
				Size = 32,
				Stroke = 3,
				IconSize = 28,
				Press = 4,
			})
			buyButton.Holder.Position = UDim2.fromOffset(M.O + M.Pad - 4 + 4, M.BtnY)
			oddsButton = CrateKit.Button(holder, {
				Name = "Odds",
				W = 232,
				H = 44,
				Radius = 14,
				Outline = 4,
				LipPx = 6,
				Fill = C.Cyan,
				Lip = C.CyanLip,
				Text = "ODDS",
				Size = 22,
				Stroke = 2.5,
				Icon = "Odds",
				IconSize = 24,
				Press = 3,
			})
			oddsButton.Holder.Position = UDim2.fromOffset(M.O + M.Pad, M.BtnY + 70)
		end
		buyButton.Holder.ZIndex = 2
		oddsButton.Holder.ZIndex = 2

		-- First-crate deal: pink ring around the card and a tilted "93% OFF" tag
		local ringOut = if phone then 8 else 12
		local ring = make("Frame", {
			Name = "DealRing",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(-ringOut + 2, -ringOut + 2),
			Size = UDim2.new(1, ringOut * 2 - 4, 1, ringOut * 2 - 4),
			ZIndex = 0,
		}, holder)
		CrateKit.Corner(ring, M.R + ringOut)
		CrateKit.Stroke(ring, C.Pink, if phone then 3 else 4)
		local dealTag: CrateKit.Block? = nil

		local canBuy = false
		local pulse: { Tween } = {}
		local function setPulse(on: boolean)
			if on and #pulse == 0 then
				table.insert(
					pulse,
					tween(
						fill,
						0.5,
						Enum.EasingStyle.Sine,
						{ BackgroundTransparency = 0.3 },
						Enum.EasingDirection.InOut,
						-1,
						true
					)
				)
				table.insert(
					pulse,
					tween(
						CrateKit.ScaleOf(pityText),
						0.5,
						Enum.EasingStyle.Sine,
						{ Scale = 1.04 },
						Enum.EasingDirection.InOut,
						-1,
						true
					)
				)
			elseif not on and #pulse > 0 then
				for _, t in pulse do
					t:Cancel()
				end
				table.clear(pulse)
				fill.BackgroundTransparency = 0
				CrateKit.ScaleOf(pityText).Scale = 1
			end
		end

		local function refresh()
			local locked = CrateController.Locked(crate)
			local free = hasFree(crate)
			local discount = not free and not locked and CrateController.Discount(crate)
			name.TextColor3 = if locked then C.Muted else CrateKit.Metal(crate)
			lockShade.Visible = locked
			price.Text = formatNumber(CrateController.Price(crate))
			price.TextColor3 = if locked then C.Muted else C.White
			coin.ImageTransparency = if locked then 0.6 else 0
			old.Visible = discount ~= nil and discount ~= false
			old.Text = formatNumber(crate.Price)
			ring.Visible = old.Visible
			if old.Visible and not dealTag then
				local tagSize = if phone then 16 else 24
				local tagH = if phone then 32 else 46
				dealTag = tag(holder, ("%d%% OFF"):format(discount :: number), {
					Size = tagSize,
					Stroke = if phone then 2 else 2.5,
					H = tagH,
					PadX = if phone then 8 else 12,
					Fill = C.Pink,
					Lip = C.PinkLip,
					LipPx = if phone then 3 else 5,
					Radius = if phone then 10 else 14,
					Outline = if phone then 3 else 4,
				})
				local t = (dealTag :: CrateKit.Block).Holder
				t.Name = "DealTag"
				t.AnchorPoint = Vector2.new(0.5, 0.5)
				t.Position = UDim2.fromOffset(
					M.W + (if phone then 10 else 16) - t.Size.X.Offset / 2,
					(if phone then 36 else 52) + tagH / 2
				)
				t.Rotation = 10
				t.ZIndex = 5
				-- Rotation 8 <-> 12 and UIScale 1 <-> 1.06, 1.6 Sine InOut
				t.Rotation = 8
				table.insert(
					loops,
					tween(t, 1.6, Enum.EasingStyle.Sine, { Rotation = 12 }, Enum.EasingDirection.InOut, -1, true)
				)
				table.insert(
					loops,
					tween(
						CrateKit.ScaleOf(t),
						1.6,
						Enum.EasingStyle.Sine,
						{ Scale = 1.06 },
						Enum.EasingDirection.InOut,
						-1,
						true
					)
				)
			elseif dealTag then
				dealTag.Holder.Visible = old.Visible
			end

			local row = bestPity(crate)
			pityText.Visible = row ~= nil
			track.Visible = row ~= nil
			if locked then
				pityText.Text = ("UNLOCKS IN ZONE %d"):format(crate.Zone or 1)
				pityText.TextColor3 = C.Muted
				fill.Size = UDim2.new(0, 0, 1, -M.BarBorder * 2)
				setPulse(false)
			elseif row then
				local left = pullsLeft(row)
				local rarity = row.Rarity:upper()
				local rc = hexOf(CrateKit.RarityColor(row.Rarity))
				local ready = left <= 1
				if ready then
					pityText.Text = if phone
						then ("%s NEXT OPEN!"):format(rarity)
						else ("%s GUARANTEED NEXT OPEN!"):format(rarity)
					pityText.TextColor3 = C.Gold
					fill.BackgroundColor3 = C.Gold
				else
					pityText.Text = if phone
						then ('<font color="%s">%s</font> IN %d OPENS'):format(rc, rarity, left)
						else ('<font color="%s">%s</font> GUARANTEED IN %d OPENS'):format(rc, rarity, left)
					pityText.TextColor3 = C.White
					fill.BackgroundColor3 = CrateKit.RarityColor(row.Rarity)
				end
				local done = if ready then 1 else math.clamp((row.After - left) / row.After, 0, 1)
				fill.Size = UDim2.new(done, -M.BarBorder * 2 * done, 1, -M.BarBorder * 2)
				setPulse(ready)
			end
			canBuy = paintBuy(buyButton, crate, phone)
		end

		buyButton.Activated:Connect(function()
			if canBuy then
				buy(crate)
			else
				buyButton:Shake()
			end
		end)
		oddsButton.Activated:Connect(function()
			showOdds(crate, holder)
		end)
		refresh()
		return holder, refresh
	end

	-- The cards for the shop's zone (each zone has 1-3 crates)
	local function zoneCrates()
		local list = {}
		for _, crate in Config.Crates do
			if (crate.Zone or 1) == shopZone then
				table.insert(list, crate)
			end
		end
		return list
	end

	showCards = function(animate: boolean)
		oddsCrate = nil
		local area = cardArea :: Frame
		for _, child in area:GetChildren() do
			child:Destroy()
		end
		table.clear(refreshers)
		local phone = header.Phone
		header.Title.TextSize = if phone then 30 else 60
		header.Title.Text = "CRATES"
		header.Pill.Visible = true
		local refreshBalance = function()
			local balance = header.Pill:FindFirstChild("Text")
			if balance then
				balance.Text = formatNumber(player:GetAttribute("Coins") or 0)
			end
		end
		refreshBalance()
		table.insert(refreshers, refreshBalance)
		local crates = zoneCrates()
		local cardW = if phone then 184 else 268
		local gap = if phone then 9 else 20
		local total = #crates * cardW + (#crates - 1) * gap
		for i, crate in crates do
			local card, refresh = makeCard(crate, phone)
			local x = (area.Size.X.Offset - total) / 2 + (i - 1) * (cardW + gap)
			card.Position = UDim2.fromOffset(x, 0)
			card.Parent = area
			table.insert(refreshers, refresh)
			if animate then
				-- Cards Position y +30 -> 0, stagger 0.05, 0.18 each, Quad Out
				card.Position = UDim2.fromOffset(x, 30)
				task.delay((i - 1) * 0.05, function()
					tween(card, 0.18, Enum.EasingStyle.Quad, { Position = UDim2.fromOffset(x, 0) })
				end)
			end
		end
	end

	-- ================= ODDS VIEW =================
	showOdds = function(crate, from: GuiObject?)
		local area = cardArea :: Frame
		local phone = header.Phone
		-- CARD -> ODDS: tapped card Size X 1 -> 0 (0.12 Quad In), others hidden, odds box opens 0 -> 1 (0.14 Quad Out)
		if from and from.Parent then
			for _, child in area:GetChildren() do
				if child ~= from and child:IsA("GuiObject") then
					child.Visible = false
				end
			end
			from.ClipsDescendants = true
			local w = from.Size.X.Offset
			tween(from, 0.12, Enum.EasingStyle.Quad, {
				Size = UDim2.fromOffset(0, from.Size.Y.Offset),
				Position = from.Position + UDim2.fromOffset(w / 2, 0),
			}, Enum.EasingDirection.In)
			task.wait(0.12)
		end
		oddsCrate = crate
		for _, child in area:GetChildren() do
			child:Destroy()
		end
		table.clear(refreshers)

		header.Title.TextSize = if phone then 26 else 52
		header.Title.Text = ('<font color="%s">%s</font> ODDS'):format(
			hexOf(CrateKit.Metal(crate)),
			if phone then shortName(crate) else crate.Name:upper()
		)
		header.Pill.Visible = not phone

		local o = if phone then 3 else 4
		local W, H = area.Size.X.Offset, area.Size.Y.Offset
		local box = make("Frame", {
			Name = "OddsBox",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromOffset(W / 2, 0),
			Size = UDim2.fromOffset(W, H),
			ClipsDescendants = true,
			ZIndex = 2,
		}, area)
		local inner = make("Frame", {
			Name = "Inner",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(W, H),
		}, box)
		CrateKit.Block(inner, {
			W = W,
			H = H,
			Fill = C.Card,
			Lip = C.CardLip,
			LipPx = if phone then 5 else 8,
			Radius = if phone then 14 else 22,
			Outline = o,
			Ring = C.CardLine,
			RingPx = 2,
		})
		local padX, padT = if phone then 10 else 18, if phone then 10 else 16
		local colW = if phone then 140 else 230
		local x0, y0 = o + padX, o + padT
		local function at(object: GuiObject, x: number, y: number, w: number, h: number)
			object.Position = UDim2.fromOffset(x, y)
			object.Size = UDim2.fromOffset(w, h)
			object.ZIndex = 2
			object.Parent = inner
		end

		-- Left column: art, price, BUY, BACK
		local artH = if phone then 72 else 150
		local art = make("Frame", { Name = "Art", BackgroundColor3 = C.Zebra, BorderSizePixel = 0 })
		at(art, x0, y0, colW, artH)
		CrateKit.Corner(art, if phone then 10 else 14)
		crateView(crate, art)
		local gap = if phone then 6 else 12
		local priceH = if phone then 24 else 40
		local row, _coin, _old, price = priceRow(
			inner,
			if phone then 22 else 36,
			if phone then 22 else 36,
			if phone then 2 else 3,
			if phone then 14 else 22
		)
		at(row, x0, y0 + artH + gap, colW, priceH)
		price.Text = formatNumber(CrateController.Price(crate))
		local buyY = y0 + artH + gap + priceH + gap
		local buyButton = CrateKit.Button(inner, {
			Name = "Buy",
			W = colW,
			H = if phone then 44 else 60,
			Radius = if phone then 12 else 16,
			Outline = o,
			LipPx = if phone then 5 else 8,
			Fill = C.Lime,
			Lip = C.LimeLip,
			Text = "BUY",
			Size = if phone then 22 else 32,
			Stroke = if phone then 2 else 3,
			IconSize = if phone then 18 else 28,
			Press = if phone then 3 else 4,
		})
		buyButton.Holder.Position = UDim2.fromOffset(x0, buyY)
		buyButton.Holder.ZIndex = 2
		buyButton.Label.LineHeight = 0.9
		local back = CrateKit.Button(inner, {
			Name = "Back",
			W = colW,
			H = if phone then 44 else 48,
			Radius = if phone then 12 else 14,
			Outline = o,
			LipPx = if phone then 5 else 6,
			Fill = C.Navy,
			Lip = C.NavyLip,
			Text = "BACK",
			Size = if phone then 20 else 24,
			Stroke = if phone then 2 else 2.5,
			Press = 3,
		})
		back.Holder.Position = UDim2.fromOffset(x0, buyY + (if phone then 44 else 60) + gap)
		back.Holder.ZIndex = 2
		local canBuy = false
		local function refresh()
			price.Text = formatNumber(CrateController.Price(crate))
			canBuy = paintBuy(buyButton, crate, phone)
		end
		refresh()
		table.insert(refreshers, refresh)
		buyButton.Activated:Connect(function()
			if canBuy then
				buy(crate)
			else
				buyButton:Shake()
			end
		end)
		back.Activated:Connect(function()
			showCards(true)
		end)

		-- Right column: LUCKY note (only with a LUCKY pass), column labels, one row per ball
		local rx = x0 + colW + (if phone then 12 else 22)
		local rw = W - o - padX - rx
		local ry = y0
		local luck = Store.Luck(player)
		local odds = Store.LuckyOdds(crate.Odds, luck)
		if luck > 1 then
			local luckyH = if phone then 26 else 44
			local lucky = make("Frame", { Name = "Lucky", BackgroundColor3 = C.LuckyBg, BorderSizePixel = 0 })
			at(
				lucky,
				rx + (if phone then 2 else 3),
				ry + (if phone then 2 else 3),
				rw - (if phone then 4 else 6),
				luckyH - (if phone then 4 else 6)
			)
			CrateKit.Corner(lucky, if phone then 9 else 14)
			CrateKit.Stroke(lucky, C.Ink, if phone then 2 else 3)
			local ringLine = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, lucky)
			CrateKit.Corner(ringLine, if phone then 9 else 14)
			make(
				"UIStroke",
				{ Color = C.LimeLip, Thickness = if phone then 1 else 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
				ringLine
			)
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, if phone then 6 else 10),
			}, lucky)
			make("UIPadding", { PaddingLeft = UDim.new(0, if phone then 6 else 11) }, lucky)
			CrateKit.Icon(lucky, "Clover", if phone then 18 else 30)
			local l1 = CrateKit.Text(
				lucky,
				("LUCKY x%g"):format(luck),
				Head,
				if phone then 14 else 22,
				C.Lime,
				if phone then 1.5 else 2.5
			)
			l1.LayoutOrder = 2
			l1.AutomaticSize = Enum.AutomaticSize.X
			l1.Size = UDim2.new(0, 0, 1, 0)
			make("UIPadding", { PaddingTop = UDim.new(0, if phone then 2 else 3) }, l1)
			local boosted = {}
			local on = false
			for _, rarity in Config.Rarities do
				on = on or rarity.Name == Config.Monetization.LuckFrom
				if on then
					table.insert(boosted, rarity.Name:upper())
				end
			end
			local sub = if phone
				then ("%s+ BOOSTED"):format(boosted[1] or "")
				else ("BOOSTS %s"):format(
					#boosted > 1 and (table.concat(boosted, ", ", 1, #boosted - 1) .. " + " .. boosted[#boosted])
						or (boosted[1] or "")
				)
			local l2 = CrateKit.Text(lucky, sub, Body, if phone then 9 else 12, C.LuckyText, 0)
			l2.LayoutOrder = 3
			l2.AutomaticSize = Enum.AutomaticSize.X
			l2.Size = UDim2.new(0, 0, 1, 0)
			ry += luckyH + (if phone then 4 else 6)
		end

		-- Grid: dot | name | rarity | chance
		local G = if phone
			then {
				Dot = 16,
				Rar = 76,
				Chance = 68,
				Gap = 6,
				Pad = 6,
				RowH = 21,
				RowGap = 2,
				R = 6,
				DotSize = 14,
				DotLine = 2,
				Name = 11,
				RarSize = 12,
				ChanceSize = 13,
				ChanceStroke = 1.5,
				BaseSize = 9,
			}
			else {
				Dot = 34,
				Rar = 128,
				Chance = 132,
				Gap = 10,
				Pad = 10,
				RowH = 30,
				RowGap = 6,
				R = 10,
				DotSize = 24,
				DotLine = 3,
				Name = 15,
				RarSize = 16,
				ChanceSize = 20,
				ChanceStroke = 2,
				BaseSize = 13,
			}
		local nameW = rw - G.Pad * 2 - G.Dot - G.Rar - G.Chance - G.Gap * 3
		if not phone then
			local labels = make("Frame", { Name = "Labels", BackgroundTransparency = 1 })
			at(labels, rx, ry, rw, 16)
			for _, def in
				{
					{ "BALL", G.Pad + G.Dot + G.Gap, nameW, Enum.TextXAlignment.Left },
					{ "RARITY", G.Pad + G.Dot + G.Gap * 2 + nameW, G.Rar, Enum.TextXAlignment.Left },
					{ "CHANCE", rw - G.Pad - G.Chance, G.Chance, Enum.TextXAlignment.Right },
				}
			do
				local l = CrateKit.Text(labels, def[1], Body, 11, C.Faint, 0)
				l.Position = UDim2.fromOffset(def[2], 0)
				l.Size = UDim2.new(0, def[3], 1, 0)
				l.TextXAlignment = def[4]
			end
			ry += 20
		end
		local list = make("ScrollingFrame", {
			Name = "List",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = if phone then 3 else 5,
			ScrollBarImageColor3 = C.Muted,
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			CanvasSize = UDim2.new(),
			ScrollingDirection = Enum.ScrollingDirection.Y,
		})
		at(list, rx, ry, rw, H - o - (if phone then 12 else 22) - (if phone then 5 else 8) - ry)
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, G.RowGap) }, list)
		make("UIPadding", {
			PaddingTop = UDim.new(0, 2),
			PaddingBottom = UDim.new(0, 2),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 2),
		}, list)
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local baseList = {}
		if luck > 1 then
			for _, entry in Balls.CrateBallOdds(crate) do
				baseList[entry.Ball.Id] = entry.Chance
			end
		end
		local function pct(chance: number): string
			return ("%.4g%%"):format(chance)
		end
		local rowW = rw - 4
		for i, entry in Balls.CrateBallOdds(crate, odds) do
			local ball = entry.Ball
			local rc = CrateKit.RarityColor(ball.Rarity)
			local mythic = ball.Rarity == "Mythic"
			local r = make("Frame", {
				Name = ball.Id,
				LayoutOrder = i,
				BackgroundColor3 = if mythic then rc else C.Zebra,
				BackgroundTransparency = if mythic then 0.84 elseif i % 2 == 1 then 0 else 1,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(rowW, G.RowH),
				ZIndex = 3,
			}, list)
			CrateKit.Corner(r, G.R)
			if mythic then
				CrateKit.Stroke(r, rc, if phone then 1 else 2)
			end
			local dot = make("Frame", {
				Name = "Dot",
				BackgroundColor3 = rc,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, G.Pad + G.DotLine, 0.5, 0),
				Size = UDim2.fromOffset(G.DotSize - G.DotLine * 2, G.DotSize - G.DotLine * 2),
				ZIndex = 3,
			}, r)
			CrateKit.Corner(dot, G.DotSize)
			CrateKit.Stroke(dot, C.Ink, G.DotLine)
			local nameRow = make("Frame", {
				Name = "Name",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(G.Pad + G.Dot + G.Gap, 0),
				Size = UDim2.new(0, nameW, 1, 0),
				ClipsDescendants = true,
				ZIndex = 3,
			}, r)
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}, nameRow)
			local n = CrateKit.Text(nameRow, ball.Name:upper(), Body, G.Name, C.White, if phone then 0 else 1.5)
			n.AutomaticSize = Enum.AutomaticSize.X
			n.Size = UDim2.new(0, 0, 1, 0)
			n.ZIndex = 3
			if owned[ball.Id] then
				local check = CrateKit.Icon(nameRow, "Check", if phone then 12 else 18)
				check.LayoutOrder = 2
				check.ZIndex = 3
			end
			if entry.Featured then
				-- This week's featured ball (Config.Featured): likelier inside its rarity
				local f = CrateKit.Text(nameRow, "FEATURED", Body, if phone then 8 else 10, C.Gold, 0)
				f.LayoutOrder = 3
				f.AutomaticSize = Enum.AutomaticSize.X
				f.Size = UDim2.new(0, 0, 1, 0)
				f.ZIndex = 3
			end
			local rarX = G.Pad + G.Dot + G.Gap * 2 + nameW
			if phone then
				local rt = CrateKit.Text(r, ball.Rarity:upper(), Head, G.RarSize, rc, 1)
				rt.Position = UDim2.fromOffset(rarX, 1)
				rt.Size = UDim2.new(0, G.Rar, 1, 0)
				rt.TextXAlignment = Enum.TextXAlignment.Left
				rt.ZIndex = 3
			else
				local chipW = CrateKit.TextWidth(ball.Rarity:upper(), Head, G.RarSize) + 16
				local chip = make("Frame", {
					Name = "Chip",
					BackgroundColor3 = rc,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, rarX + 3, 0.5, 0),
					Size = UDim2.fromOffset(chipW, 18),
					ZIndex = 3,
				}, r)
				CrateKit.Corner(chip, 6)
				CrateKit.Stroke(chip, C.Ink, 3)
				local ct = CrateKit.Text(chip, ball.Rarity:upper(), Head, G.RarSize, C.White, 1.5)
				ct.ZIndex = 3
				make("UIPadding", { PaddingTop = UDim.new(0, 2) }, ct)
			end
			local chanceRow = make("Frame", {
				Name = "Chance",
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -G.Pad - G.Chance, 0, 0),
				Size = UDim2.new(0, G.Chance, 1, 0),
				ZIndex = 3,
			}, r)
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 8),
			}, chanceRow)
			local base = baseList[ball.Id]
			local boostedRow = base ~= nil and math.abs(base - entry.Chance) > 1e-9
			if boostedRow and not phone then
				local b = CrateKit.Text(chanceRow, pct(base), Num, G.BaseSize, C.Faint, 0)
				b.AutomaticSize = Enum.AutomaticSize.X
				b.Size = UDim2.new(0, 0, 1, 0)
				b.ZIndex = 3
				make("Frame", {
					BackgroundColor3 = C.Red,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, 2, 0, 2),
					ZIndex = 4,
				}, b)
			end
			local c = CrateKit.Text(
				chanceRow,
				pct(entry.Chance),
				Num,
				G.ChanceSize,
				if boostedRow then C.Lime else C.White,
				G.ChanceStroke
			)
			c.LayoutOrder = 2
			c.AutomaticSize = Enum.AutomaticSize.X
			c.Size = UDim2.new(0, 0, 1, 0)
			c.ZIndex = 3
		end
		box.Size = UDim2.fromOffset(0, H)
		tween(box, 0.14, Enum.EasingStyle.Quad, { Size = UDim2.fromOffset(W, H) })
	end

	-- Opens / closes the shop. Opens: backdrop fades in, panel UIScale 0.85 -> 1 (0.22 Back Out), cards rise in.
	-- Closes: panel UIScale -> 0.9 (0.15 Quad In), then hidden. Closes on X, Esc / B, or walking away.
	local openToken = 0
	local openedAt: Vector3? = nil
	setOpen = function(open: boolean)
		openToken += 1
		local token = openToken
		if open then
			gui.Inventory.Visible = false
			local book = gui:FindFirstChild("Book")
			if book then
				book.Visible = false
			end
			buildPanel()
			showCards(true)
			shop.Visible = true
			shopBackdrop.BackgroundTransparency = 1
			tween(shopBackdrop, 0.15, Enum.EasingStyle.Linear, { BackgroundTransparency = 0.4 })
			local scale = panelScale :: UIScale
			scale.Scale = 0.85
			tween(scale, 0.22, Enum.EasingStyle.Back, { Scale = 1 })
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			openedAt = root and root.Position
		elseif shop.Visible then
			openedAt = nil
			stopLoops()
			tween(shopBackdrop, 0.15, Enum.EasingStyle.Linear, { BackgroundTransparency = 1 })
			if panelScale then
				tween(panelScale, 0.15, Enum.EasingStyle.Quad, { Scale = 0.9 }, Enum.EasingDirection.In)
			end
			task.delay(0.15, function()
				if token == openToken then
					shop.Visible = false
				end
			end)
		end
	end
	UiKit.CloseKeys(shop, function()
		setOpen(false)
	end)
	RunService.Heartbeat:Connect(function()
		if openedAt and shop.Visible then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - openedAt).Magnitude > SHOP.WalkAwayDistance then
				setOpen(false)
			end
		end
	end)
	local function refreshShop()
		if shop.Visible then
			for _, fn in refreshers do
				fn()
			end
		end
	end
	for _, attr in { "Coins", "FreeCrates", "CratesBought", "ZonesOpen", "Passes", "OwnedBalls" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshShop)
	end
	for _, crate in Config.Crates do
		for _, row in Balls.PityRows(crate.Id) do
			player:GetAttributeChangedSignal("Pity_" .. row.Key):Connect(refreshShop)
		end
	end
	-- Phone <-> computer layout while the shop is open: build it again in the new layout
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(function()
			if not shop.Visible then
				return
			end
			local wasPhone = shopStage.Phone
			shopStage:Fit()
			if wasPhone ~= shopStage.Phone then
				local crate = oddsCrate
				buildPanel()
				if crate then
					showOdds(crate)
				else
					showCards(false)
				end
			end
		end)
	end)

	-- ================= OPENING: INTRO, REEL, REVEAL =================
	local reelStage = CrateKit.Stage(opening, gui, "Reel")
	reelStage.Screen.ZIndex = 1
	local reelShade = make("Frame", {
		Name = "Shade",
		BackgroundColor3 = C.Ink,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, reelStage.Screen)
	local revealStage = CrateKit.Stage(opening, gui, "Reveal")
	revealStage.Screen.ZIndex = 3
	revealStage.Screen.Visible = false

	-- Intro (Config.CrateShop.Intro): the crate (ReplicatedStorage.CrateModels, the kiosk designs) slams down,
	-- does a few funky hops with the lid peeking open and light leaking out, then the lid blasts off
	-- with a beam of light. Spinning rays and a glow ring dance behind it to the beat.
	local introStage = Instance.new("Frame")
	introStage.Name = "CrateIntro"
	introStage.AnchorPoint = Vector2.new(0.5, 0.5)
	introStage.Position = UDim2.fromScale(0.5, 0.55)
	introStage.Size = UDim2.fromScale(0.6, 0.6)
	introStage.BackgroundTransparency = 1
	introStage.Visible = false
	introStage.ZIndex = 5
	local stageAspect = Instance.new("UIAspectRatioConstraint")
	stageAspect.Parent = introStage
	introStage.Parent = opening

	-- Glow ring behind the crate
	local introGlow = Instance.new("Frame")
	introGlow.Name = "Glow"
	introGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	introGlow.Position = UDim2.fromScale(0.5, 0.5)
	introGlow.Size = UDim2.fromScale(0.5, 0.5)
	introGlow.BorderSizePixel = 0
	introGlow.ZIndex = 5
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0.5, 0)
	glowCorner.Parent = introGlow
	local glowStroke = Instance.new("UIStroke")
	glowStroke.Thickness = 6
	glowStroke.Parent = introGlow
	introGlow.Parent = introStage

	-- Light rays: each spoke is a full-height bar (two rays, one each way) so it turns around the centre
	local introRays = Instance.new("Frame")
	introRays.Name = "Rays"
	introRays.AnchorPoint = Vector2.new(0.5, 0.5)
	introRays.Position = UDim2.fromScale(0.5, 0.5)
	introRays.Size = UDim2.fromScale(1, 1)
	introRays.BackgroundTransparency = 1
	introRays.ZIndex = 5
	introRays.Parent = introStage
	local rayBars = {}
	for i = 1, INTRO.Rays do
		local spoke = Instance.new("Frame")
		spoke.AnchorPoint = Vector2.new(0.5, 0.5)
		spoke.Position = UDim2.fromScale(0.5, 0.5)
		spoke.Size = UDim2.fromScale(INTRO.RayWidth, 1)
		spoke.Rotation = (i - 1) * 180 / INTRO.Rays
		spoke.BackgroundTransparency = 1
		spoke.ZIndex = 5
		spoke.Parent = introRays
		for _, top in { true, false } do
			local ray = Instance.new("Frame")
			ray.Size = UDim2.fromScale(1, 0.5)
			ray.Position = UDim2.fromScale(0, if top then 0 else 0.5)
			ray.BorderSizePixel = 0
			ray.ZIndex = 5
			local fade = Instance.new("UIGradient")
			fade.Rotation = if top then 90 else -90 -- bright at the centre, gone at the tip
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.6, 0.55),
				NumberSequenceKeypoint.new(1, 0.15),
			})
			fade.Parent = ray
			ray.Parent = spoke
			table.insert(rayBars, { Ray = ray, Even = i % 2 == 0 })
		end
	end
	local raysScale = Instance.new("UIScale")
	raysScale.Parent = introRays

	local introView = Instance.new("ViewportFrame")
	introView.Name = "Crate"
	introView.AnchorPoint = Vector2.new(0.5, 0.5)
	introView.Position = UDim2.fromScale(0.5, 0.5)
	introView.Size = UDim2.fromScale(1, 1)
	introView.BackgroundTransparency = 1
	introView.Ambient = Color3.fromRGB(200, 200, 220)
	introView.LightColor = Color3.new(1, 1, 1)
	introView.LightDirection = Vector3.new(-1, -1.5, -1)
	introView.ZIndex = 6
	local introCamera = Instance.new("Camera")
	introCamera.FieldOfView = 40
	introCamera.Parent = introView
	introView.CurrentCamera = introCamera
	introView.Parent = introStage

	local function easeOut(k: number): number
		return 1 - (1 - k) ^ 3
	end

	local CORNERS = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(CORNERS, Vector3.new(x, y, z))
			end
		end
	end

	-- The lid's bottom back edge (model space, front = +Z): it swings open around this line
	local function lidHinge(model: Model, lid: Model): CFrame
		local pivot = model:GetPivot()
		local lowY, backZ = math.huge, math.huge
		for _, part in lid:GetDescendants() do
			if part:IsA("BasePart") then
				for _, corner in CORNERS do
					local point = pivot:PointToObjectSpace(part.CFrame:PointToWorldSpace(part.Size / 2 * corner))
					lowY = math.min(lowY, point.Y)
					backZ = math.min(backZ, point.Z)
				end
			end
		end
		return CFrame.new(0, lowY, backZ)
	end

	-- A ring of light that spreads out of the stage centre and fades (a step up in the tease)
	local function introRing(color: Color3, size: number)
		local ring = make("Frame", {
			Name = "Ring",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.3, 0.3),
			ZIndex = 5,
		}, introStage)
		make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
		local stroke = make("UIStroke", { Color = color, Thickness = 10 }, ring)
		tween(ring, INTRO.RingTime, Enum.EasingStyle.Quad, { Size = UDim2.fromScale(size, size) })
		tween(stroke, INTRO.RingTime, Enum.EasingStyle.Quad, { Transparency = 1, Thickness = 2 })
		task.delay(INTRO.RingTime, ring.Destroy, ring)
	end

	-- title: the reel screen's crate name (pops when the crate lands)
	-- rarityIndex: the prize's rarity. A2: the light leaking out of the crate climbs one rarity colour per hop up to
	-- the real one (never past it), and rarer prizes hop more (Epic 4, Legendary 5, Mythic 6).
	local function playIntro(crate, title: GuiObject?, rarityIndex: number)
		local template = crateModels
			and (crateModels:FindFirstChild(crate.Id) or (crate.Model and crateModels:FindFirstChild(crate.Model)))
		if not template then
			return
		end
		local model = template:Clone() :: Model
		local _, size = model:GetBoundingBox()
		model:ScaleTo(model:GetScale() * INTRO.CrateSize / math.max(size.X, size.Z))
		model:PivotTo(CFrame.new())
		local _, scaled = model:GetBoundingBox()
		model.Parent = introView

		-- Hinged lid (every crate model has a Lid): peeks open on each hop, blasts off at the end
		local lid = model:FindFirstChild("Lid") :: Model?
		local hinge, lidHome
		if lid then
			hinge = lidHinge(model, lid)
			lidHome = hinge:Inverse() * lid:GetPivot()
		end
		local hingeY = if hinge then hinge.Y else scaled.Y * 0.2
		-- Light inside the crate, seen through the gap under the lid (the Alley Crate has its own Loot_Glow)
		local core = Instance.new("Part")
		core.Material = Enum.Material.Neon
		core.Color = crate.Color:Lerp(Color3.new(1, 1, 1), 0.35)
		core.Size = Vector3.new(scaled.X * 0.8, scaled.Y * 0.25, scaled.Z * 0.8)
		core.Transparency = 1
		core.Parent = model
		local beam = Instance.new("Part")
		beam.Shape = Enum.PartType.Cylinder
		beam.Material = Enum.Material.Neon
		beam.Color = crate.Color:Lerp(Color3.new(1, 1, 1), 0.5)
		beam.Transparency = 1
		beam.Parent = model
		local lootGlow = model:FindFirstChild("Loot_Glow", true)

		local white = Color3.new(1, 1, 1)
		local color = crate.Color
		local function paintTease(c: Color3)
			color = c
			introGlow.BackgroundColor3 = c
			glowStroke.Color = c:Lerp(white, 0.5)
			for _, bar in rayBars do
				bar.Ray.BackgroundColor3 = if bar.Even then c else c:Lerp(white, 0.6)
			end
			core.Color = c:Lerp(white, 0.35)
			beam.Color = c:Lerp(white, 0.5)
		end
		paintTease(color)
		local hops = math.clamp(rarityIndex, INTRO.Hops, INTRO.Hops + INTRO.ExtraHops)
		local lidPeek = INTRO.LidPeek * INTRO.Hops / hops -- the lid ends up just as open however many hops
		local shownRarity = 0
		introView.ImageColor3 = white
		introView.ImageTransparency = 1
		introRays.Visible = false
		introGlow.Visible = false
		introStage.Visible = true
		if title then
			UiFx.Pop(title, 1.4, 0.3)
		end

		local turn = math.rad(INTRO.HopTurn)
		local hopsEnd = INTRO.DropTime + hops * INTRO.HopTime
		local total = hopsEnd + INTRO.BlastTime
		local start = os.clock()
		local lastFrame = start
		local hop, landed, blasted = 0, false, false
		local kick = 0 -- camera punch-in on every landing, fades out
		local shake = 0
		local raysAngle = 0
		while true do
			local now = os.clock()
			local t = now - start
			local dt = now - lastFrame
			lastFrame = now
			if t >= total then
				break
			end
			local lift, spin, tilt, lidAngle, lidLift, lidSpin = 0, 0, 0, 0, 0, 0
			local heat = 0 -- 0..1 how worked up the crate is (ray speed, glow)
			if t < INTRO.DropTime then
				-- Slams down from above, spinning in
				local k = t / INTRO.DropTime
				lift = INTRO.DropHeight * (1 - k * k)
				spin = -INTRO.DropSpin * 2 * math.pi * (1 - easeOut(k))
				introView.ImageTransparency = 1 - math.min(k * 3, 1)
			elseif t < hopsEnd then
				introView.ImageTransparency = 0
				if not landed then
					landed = true
					kick, shake = 1, 1
					Sfx.Play("CrateLand")
					UiFx.Pop(introGlow, 1.6, 0.3)
				end
				-- Hops: each one higher, a quarter turn each, a little wiggle in the air
				local h = (t - INTRO.DropTime) / INTRO.HopTime
				local index = math.floor(h)
				local k = h - index
				if index + 1 ~= hop then
					hop = index + 1
					Sfx.Play("ReelTick", 0.9 + hop * 0.2)
					local shown = math.min(hop, rarityIndex)
					if shown ~= shownRarity then
						paintTease(CrateKit.RarityColor(Config.Rarities[shown].Name))
						if shownRarity > 0 then
							-- a step up: chime, flash and a ring in the new colour
							Sfx.Play("StreakUp", 0.8 + shown * 0.1, 0.7)
							UiFx.Flash(color, 0.12, 0.2)
							introRing(color, 1.1 + shown * 0.08)
							UiFx.Pop(introGlow, 1.8, 0.3)
						end
						shownRarity = shown
					end
					if index > 0 then
						-- landed the previous hop: thump
						kick, shake = 0.6 + index * 0.2, 0.5 + index * 0.25
						UiFx.Pop(introGlow, 1.3 + index * 0.15, 0.25)
						raysScale.Scale = 1.2 + index * 0.1
					end
				end
				heat = (index + k) / hops
				local height = INTRO.HopHeight * (1 + index * INTRO.HopGrow)
				lift = height * 4 * k * (1 - k)
				spin = (index + easeOut(k)) * turn
				tilt = math.sin(k * math.pi * 2) * math.rad(INTRO.HopWiggle) * (if index % 2 == 0 then 1 else -1)
				-- The lid flaps while airborne and rests a little more open after each hop
				lidAngle = lidPeek * (index + math.sin(k * math.pi) * 1.5)
			else
				-- Blast: crouch and rattle, then the lid rockets off and a beam of light shoots out
				local k = (t - hopsEnd) / INTRO.BlastTime
				spin = hops * turn
				heat = 1
				if k < INTRO.CrouchShare then
					local c = k / INTRO.CrouchShare
					lift = -0.15 * c
					shake = math.max(shake, 0.6 + c)
					tilt = (math.random() - 0.5) * 0.1 * c
					lidAngle = lidPeek * hops * (1 - c * 0.7)
				else
					local b = (k - INTRO.CrouchShare) / (1 - INTRO.CrouchShare)
					if not blasted then
						blasted = true
						kick, shake = 1.6, 1.4
						Sfx.Play("CrateOpen")
						Sfx.Play("Firework", 1.1, 0.7)
						UiFx.Flash(color, 0.5, 0.3)
						UiFx.Confetti(opening, INTRO.Confetti, { color, white, color:Lerp(white, 0.5) })
						UiFx.Pop(introGlow, 2.2, 0.4)
						introRing(color, 1.6)
					end
					lidLift = INTRO.LidFly * easeOut(b)
					lidSpin = INTRO.LidSpin * 2 * math.pi * b
					lidAngle = 70
					local beamHeight = INTRO.BeamHeight * easeOut(math.min(b * 2, 1))
					local beamWidth = scaled.X * 0.55 * (1 - b * 0.6)
					beam.Size = Vector3.new(math.max(beamHeight, 0.05), beamWidth, beamWidth)
					beam.Transparency = 0.25 + b * 0.75
					introView.ImageColor3 = white:Lerp(color:Lerp(white, 0.4), b)
				end
			end

			-- Beat-driven extras: the rays turn faster as it heats up, alternate colours swap on every beat
			raysAngle += dt * 360 * (INTRO.RaySpin + heat * INTRO.RaySpinHot)
			introRays.Rotation = raysAngle
			local rayTarget = if blasted then 1.9 else 1 + heat * 0.25
			raysScale.Scale += (rayTarget - raysScale.Scale) * math.min(dt * 8, 1)
			local beat = (hop + (if blasted then 1 else 0)) % 2 == 0
			for _, bar in rayBars do
				bar.Ray.BackgroundTransparency = 0.15 + (if bar.Even == beat then 0 else 0.4) * (1 - heat * 0.5)
			end
			introRays.Visible = landed
			introGlow.Visible = landed
			introGlow.BackgroundTransparency = 0.78 - heat * 0.25
			kick = math.max(kick - dt * 5, 0)
			shake = math.max(shake - dt * 4, 0)
			introStage.Position =
				UDim2.new(0.5, (math.random() - 0.5) * 16 * shake, 0.55, (math.random() - 0.5) * 16 * shake)

			local cf = CFrame.new(0, lift, 0) * CFrame.Angles(0, math.rad(INTRO.FaceAngle) + spin, tilt)
			model:PivotTo(cf)
			if lid and hinge and lidHome then
				lid:PivotTo(
					cf
						* CFrame.new(0, lidLift, -lidLift * 0.3)
						* hinge
						* CFrame.Angles(-math.rad(lidAngle) - lidSpin, 0, 0)
						* lidHome
				)
			end
			core.CFrame = cf * CFrame.new(0, hingeY - core.Size.Y / 2, 0)
			beam.CFrame = cf * CFrame.new(0, hingeY + beam.Size.X / 2, 0) * CFrame.Angles(0, 0, math.rad(90))
			local leak = math.clamp(lidAngle / 25, 0, 1)
			core.Transparency = 1 - leak * 0.9
			if lootGlow and lootGlow:IsA("BasePart") then
				lootGlow.Transparency = 1 - leak * 0.9
			end
			local distance = INTRO.CameraDistance * (1 - kick * INTRO.Kick)
			introCamera.CFrame =
				CFrame.lookAt(Vector3.new(0, distance * 0.3, distance), Vector3.new(0, scaled.Y * 0.35, 0))
			RunService.RenderStepped:Wait()
		end
		introStage.Visible = false
		introStage.Position = UDim2.fromScale(0.5, 0.55)
		introView.ImageColor3 = Color3.new(1, 1, 1)
		raysScale.Scale = 1
		model:Destroy()
	end

	-- One reel tile: rarity frame with the ink outline outside it, the ball, the rarity band at the bottom
	local function reelTile(ball, M): (Frame, Frame)
		local rc = CrateKit.RarityColor(ball.Rarity)
		local tile = make("Frame", {
			Name = "Tile",
			BackgroundColor3 = rc,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(M.TileW, M.TileH),
		})
		CrateKit.Corner(tile, M.TileR)
		CrateKit.Stroke(tile, C.Ink, M.Out)
		local fill = make("Frame", {
			Name = "Fill",
			BackgroundColor3 = C.Card,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(M.Frame, M.Frame),
			Size = UDim2.new(1, -M.Frame * 2, 1, -M.Frame * 2),
		}, tile)
		CrateKit.Corner(fill, M.TileR - M.Frame)
		local thumb = make("Frame", {
			Name = "Thumb",
			BackgroundColor3 = CrateKit.Rarity[ball.Rarity][2],
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, M.PadTop),
			Size = UDim2.fromOffset(M.Thumb - M.ThumbLine * 2, M.Thumb - M.ThumbLine * 2),
		}, fill)
		CrateKit.Corner(thumb, M.Thumb)
		CrateKit.Stroke(thumb, C.Ink, M.ThumbLine)
		local view = BallView.New(ball, { Margin = 1 })
		view.AnchorPoint = Vector2.new(0.5, 0.5)
		view.Position = UDim2.fromScale(0.5, 0.5)
		view.Size = UDim2.fromScale(1.15, 1.15)
		view.Parent = thumb
		local band = make("Frame", {
			Name = "Band",
			BackgroundColor3 = rc,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, M.Band),
		}, fill)
		CrateKit.Corner(band, M.TileR - M.Frame)
		make("Frame", { -- square off the band's top corners
			Name = "Top",
			BackgroundColor3 = rc,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0.5, 0),
		}, band)
		make("Frame", {
			Name = "Line",
			BackgroundColor3 = C.Ink,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, M.BandLine),
			ZIndex = 2,
		}, band)
		local label = CrateKit.Text(band, ball.Rarity:upper(), Head, M.BandFont, C.White, M.BandStroke)
		label.ZIndex = 2
		make("UIPadding", { PaddingTop = UDim.new(0, M.BandLine + 2) }, label)
		local dim = make("Frame", {
			Name = "Dim",
			BackgroundColor3 = C.Ink,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 3,
		}, tile)
		CrateKit.Corner(dim, M.TileR)
		return tile, dim
	end

	-- The reel screen for this crate (title + band + marker + SKIP), built fresh for each opening
	local function buildReel(crate)
		reelStage:Fit()
		local S = reelStage
		local phone = S.Phone
		local M = if phone
			then {
				TitleY = 52,
				TitleSize = 32,
				TitleStroke = 2.5,
				TitleDrop = 3,
				BandY = 118,
				BandH = 156,
				Border = 3,
				Line = 2,
				TileW = 100,
				TileH = 126,
				Gap = 10,
				Frame = 4,
				Out = 2,
				TileR = 12,
				Thumb = 62,
				ThumbLine = 3,
				PadTop = 8,
				Band = 26,
				BandLine = 2,
				BandFont = 11,
				BandStroke = 1.5,
				Fade = 170,
				MarkW = 4,
				MarkIcon = 32,
				MarkTop = 94,
				MarkBottom = 268,
				MarkLine = 2,
			}
			else {
				TitleY = 170,
				TitleSize = 72,
				TitleStroke = 4,
				TitleDrop = 6,
				BandY = 400,
				BandH = 280,
				Border = 5,
				Line = 3,
				TileW = 180,
				TileH = 220,
				Gap = 18,
				Frame = 6,
				Out = 4,
				TileR = 20,
				Thumb = 110,
				ThumbLine = 4,
				PadTop = 16,
				Band = 44,
				BandLine = 4,
				BandFont = 18,
				BandStroke = 2,
				Fade = 420,
				MarkW = 6,
				MarkIcon = 64,
				MarkTop = 354,
				MarkBottom = 674,
				MarkLine = 3,
			}
		local content = make("Frame", {
			Name = "Content",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5), -- centred so the A2 zoom scales around the middle
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
		}, S.Stage)
		local top = function(y: number): number
			return y - S.H / 2
		end

		local titleBox = make("Frame", {
			Name = "TitleBox",
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 0, 0.5, top(M.TitleY)),
			Size = UDim2.new(1, 0, 0, M.TitleSize),
		}, content)
		local title =
			CrateKit.Title(titleBox, crate.Name:upper(), M.TitleSize, CrateKit.Metal(crate), M.TitleStroke, M.TitleDrop)

		local band = make("Frame", {
			Name = "Band",
			BackgroundColor3 = C.Panel,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0.5, top(M.BandY)),
			Size = UDim2.new(1, 0, 0, M.BandH),
			ClipsDescendants = true,
			Visible = false,
		}, content)
		for _, edge in { 0, 1 } do
			make("Frame", {
				BackgroundColor3 = C.Ink,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, edge),
				Position = UDim2.fromScale(0, edge),
				Size = UDim2.new(1, 0, 0, M.Border),
				ZIndex = 4,
			}, band)
			make("Frame", {
				BackgroundColor3 = C.PanelLine,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, edge),
				Position = UDim2.new(0, 0, edge, if edge == 0 then M.Border else -M.Border),
				Size = UDim2.new(1, 0, 0, M.Line),
				ZIndex = 4,
			}, band)
		end
		local strip = make("Frame", {
			Name = "Strip",
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 2,
		}, band)
		-- A2: speed streaks over the tiles while the reel is fast (moved and faded every frame by playOpening)
		local streaks = {}
		for i = 1, SHOP.Juice.Streaks do
			table.insert(
				streaks,
				make("Frame", {
					Name = "Streak",
					BackgroundColor3 = C.White,
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(math.random(), (i - 0.5) / SHOP.Juice.Streaks),
					Size = UDim2.fromOffset(M.TileW * (0.6 + math.random() * 0.9), if phone then 2 else 3),
					ZIndex = 4,
				}, band)
			)
		end
		for side = 0, 1 do
			local fade = make("Frame", {
				Name = "Fade",
				BackgroundColor3 = C.Ink,
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(side, 0),
				Position = UDim2.fromScale(side, 0),
				Size = UDim2.new(0, M.Fade, 1, 0),
				ZIndex = 5,
			}, band)
			make("UIGradient", {
				Rotation = if side == 0 then 0 else 180,
				Transparency = NumberSequence.new(0, 1),
			}, fade)
		end
		local line = make("Frame", {
			Name = "Line",
			BackgroundColor3 = C.Gold,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0.5, top(M.BandY - M.MarkLine - 1)),
			Size = UDim2.fromOffset(M.MarkW, M.BandH + M.MarkLine * 2 + 2),
			ZIndex = 6,
		}, content)
		CrateKit.Stroke(line, C.Ink, M.MarkLine)
		line.Visible = false
		local icons = {}
		for i, y in { M.MarkTop, M.MarkBottom } do
			local icon = CrateKit.Icon(content, "ReelMarker", M.MarkIcon)
			icon.AnchorPoint = Vector2.new(0.5, 0)
			icon.Position = UDim2.new(0.5, 0, 0.5, top(y))
			icon.Rotation = if i == 2 then 180 else 0
			icon.ZIndex = 7
			icon.Visible = false
			table.insert(icons, icon)
		end

		local skip = CrateKit.Button(content, {
			Name = "Skip",
			W = if phone then 120 else 200,
			H = if phone then 48 else 64,
			Radius = if phone then 12 else 16,
			Outline = if phone then 3 else 4,
			LipPx = if phone then 5 else 7,
			Fill = C.Navy,
			Lip = C.NavyLip,
			Text = "SKIP",
			Size = if phone then 22 else 28,
			Stroke = if phone then 2 else 3,
			Press = 3,
		})
		local hint = CrateKit.Text(
			content,
			if phone then "JUMP TO PRIZE" else "SKIP JUMPS STRAIGHT TO YOUR PRIZE",
			Body,
			if phone then 10 else 14,
			C.Faint,
			0
		)
		if phone then
			skip.Holder.AnchorPoint = Vector2.new(1, 1)
			skip.Holder.Position = UDim2.new(1, -20, 1, -18)
			hint.AnchorPoint = Vector2.new(1, 0.5)
			hint.Position = UDim2.new(1, -150, 1, -42)
			hint.Size = UDim2.fromOffset(120, 14)
			hint.TextXAlignment = Enum.TextXAlignment.Right
		else
			skip.Holder.AnchorPoint = Vector2.new(0.5, 0)
			skip.Holder.Position = UDim2.new(0.5, 0, 0.5, top(800))
			hint.AnchorPoint = Vector2.new(0.5, 0)
			hint.Position = UDim2.new(0.5, 0, 0.5, top(878))
			hint.Size = UDim2.fromOffset(600, 18)
		end
		skip.Holder.Visible = false
		hint.Visible = false
		return {
			Content = content,
			Title = title,
			Band = band,
			Strip = strip,
			Line = line,
			Icons = icons,
			Skip = skip,
			Hint = hint,
			Streaks = streaks,
			Top = top,
			M = M,
		}
	end

	-- A trait chip: label + value (POWER +6 in the kit; here COINS x2.5 and the ball's traits)
	local function traitChip(
		parent: Instance,
		labelText: string,
		value: string,
		valueColor: Color3,
		phone: boolean,
		order: number
	)
		local L = if phone
			then { H = 30, R = 9, O = 2, Lip = 3, Pad = 9, Gap = 5, Label = 9, Value = 15, Stroke = 1.5 }
			else { H = 56, R = 16, O = 4, Lip = 5, Pad = 18, Gap = 10, Label = 14, Value = 26, Stroke = 2.5 }
		local width = L.Pad * 2
			+ L.O * 2
			+ L.Gap
			+ CrateKit.TextWidth(labelText, Body, L.Label)
			+ CrateKit.TextWidth(value, Num, L.Value)
		local chip = CrateKit.Block(parent, {
			Name = "Trait",
			W = width,
			H = L.H,
			Fill = C.Card,
			Lip = C.CardLip,
			LipPx = L.Lip,
			Radius = L.R,
			Outline = L.O,
		})
		chip.Holder.LayoutOrder = order
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, L.Gap),
		}, chip.Face)
		local a = CrateKit.Text(chip.Face, labelText, Body, L.Label, C.Label, 0)
		a.AutomaticSize = Enum.AutomaticSize.X
		a.Size = UDim2.new(0, 0, 1, 0)
		local b = CrateKit.Text(chip.Face, value, Num, L.Value, valueColor, L.Stroke)
		b.LayoutOrder = 2
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.new(0, 0, 1, 0)
		return chip.Holder, b
	end

	-- The reveal (the kit's D4/D5, P4/P5). Returns when it closes (OK, EQUIP, or a tap outside after 1 s).
	-- equipPrompt: the first-3-minutes gift crate, where EQUIP is the only way out
	local function showReveal(ball, result, equipPrompt: boolean?)
		local S = revealStage
		S:Fit()
		local phone = S.Phone
		local rarityIndex = Balls.RarityIndex(ball.Rarity)
		local big = rarityIndex >= LEGENDARY_INDEX
		local mythic = ball.Rarity == "Mythic"
		local rc = CrateKit.RarityColor(ball.Rarity)
		local screen = S.Screen
		local loopsHere: { Tween } = {}
		local function loop(t: Tween)
			table.insert(loopsHere, t)
			return t
		end
		local function top(y: number): number
			return y - S.H / 2
		end
		local function left(x: number): number
			return x - S.W / 2
		end

		local back = make(
			"Frame",
			{ Name = "Back", BackgroundColor3 = C.Ink, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) },
			screen
		)
		local catcher = make("TextButton", {
			Name = "TapOutside",
			Text = "",
			AutoButtonColor = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
		}, screen)
		local content =
			make("Frame", { Name = "Content", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, S.Stage)

		-- Layout numbers (design px)
		local dup = result.PolishLevel ~= nil or result.SellCoins ~= nil
		local cx, cy, slot
		if phone then
			cx, cy, slot = 360, 215, 220
		elseif big then
			cx, cy, slot = 960, 410, 380
		else
			cx, cy, slot = 960, 430, 400
		end

		-- Rays (rays.png tinted the rarity colour): UIScale 0 -> 1 (0.35 Back Out), then a turn every 12 s.
		-- Legendary/Mythic: a 2nd bigger layer turning the other way every 18 s.
		local function rays(size: number, transparency: number, period: number, reverse: boolean)
			local r = make("ImageLabel", {
				Name = "Rays",
				BackgroundTransparency = 1,
				Image = CrateKit.Image("Rays"),
				ImageColor3 = rc,
				ImageTransparency = transparency,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, left(cx), 0.5, top(cy)),
				Size = UDim2.fromOffset(size, size),
				Rotation = if reverse then 360 else 0,
			}, content)
			local scale = CrateKit.ScaleOf(r)
			scale.Scale = 0
			tween(scale, 0.35, Enum.EasingStyle.Back, { Scale = 1 })
			loop(
				tween(
					r,
					period,
					Enum.EasingStyle.Linear,
					{ Rotation = if reverse then 0 else 360 },
					Enum.EasingDirection.InOut,
					-1
				)
			)
		end
		if big then
			rays(if phone then 800 else 1600, 0.7, 18, true)
		end
		rays(if phone then 520 else 1100, 0.6, 12, false)

		local view = BallView.New(ball, { Spin = true })
		view.AnchorPoint = Vector2.new(0.5, 0.5)
		view.Position = UDim2.new(0.5, left(cx), 0.5, top(cy))
		view.Size = UDim2.fromOffset(slot, slot)
		view.ZIndex = 2
		view.Parent = content

		-- A2: confetti for every pull, more for rarer, in the prize's colours (the kit's mix for Legendary+)
		CrateKit.Confetti(
			content,
			left(cx),
			top(cy),
			SHOP.Juice.Confetti[ball.Rarity] or 20,
			if phone then 300 else 700,
			if phone then 0.5 else 1,
			if big then nil else { rc, rc:Lerp(C.White, 0.5), C.White, C.Gold }
		)

		-- Title, name, chips, duplicate line
		local titleText = ball.Rarity:upper() .. "!"
		local titleSize = if phone then 54 elseif mythic then 130 else 110
		local nameSize = if phone then 30 else 72
		local column: Frame? = nil
		local titleHolder, nameHolder, chips, dupRow
		if phone then
			column = make("Frame", {
				Name = "Column",
				BackgroundTransparency = 1,
				Position = UDim2.new(0.5, left(500), 0.5, top(if mythic then 50 else 58)),
				Size = UDim2.fromOffset(330, 240),
				ZIndex = 3,
			}, content)
			make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, column)
			titleHolder = make(
				"Frame",
				{ Name = "TitleBox", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = 1 },
				column
			)
			nameHolder = make(
				"Frame",
				{ Name = "NameBox", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 2 },
				column
			)
			chips = make("Frame", {
				Name = "Chips",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 3,
			}, column)
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Wraps = true,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 6),
			}, chips)
		else
			local nameY, chipY, dupY = 650, 750, 0
			if big then
				nameY, chipY, dupY = 620, 712, 792
			elseif dup then
				nameY, chipY, dupY = 630, 720, 800
			end
			titleHolder = make("Frame", {
				Name = "TitleBox",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0.5, top(if mythic then 66 else 80)),
				Size = UDim2.new(1, 0, 0, titleSize),
				ZIndex = 3,
			}, content)
			nameHolder = make("Frame", {
				Name = "NameBox",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0.5, top(nameY)),
				Size = UDim2.new(1, 0, 0, nameSize),
				ZIndex = 3,
			}, content)
			chips = make("Frame", {
				Name = "Chips",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 0, 0.5, top(chipY)),
				Size = UDim2.new(1, 0, 0, 56),
				ZIndex = 3,
			}, content)
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 14),
			}, chips)
			if dup then
				dupRow = make("Frame", {
					Name = "Duplicate",
					BackgroundTransparency = 1,
					Position = UDim2.new(0, 0, 0.5, top(dupY)),
					Size = UDim2.new(1, 0, 0, 32),
					ZIndex = 3,
				}, content)
			end
		end
		local title = CrateKit.Title(
			titleHolder,
			titleText,
			titleSize,
			rc,
			if phone then 3 else 5,
			if phone then 4 elseif mythic then 9 else 8
		)
		local nameLabel = CrateKit.Title(
			nameHolder,
			ball.Name:upper(),
			nameSize,
			C.White,
			if phone then 2.5 else 4,
			if phone then 3 else 6
		)
		if phone then
			title.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			make("UITextSizeConstraint", { MaxTextSize = nameSize }, nameLabel)
			nameLabel.TextScaled = true
		end

		-- Chips: the coin multiplier, then each trait in its own colour
		local order = 1
		local coinMult = math.floor(Balls.Multiplier(ball, result.PolishLevel) * 100 + 0.5) / 100
		local coinText = ("x%g"):format(coinMult)
		local coinChip, coinValue = traitChip(chips, "COINS", coinText, C.White, phone, order)
		local chipList = { coinChip }
		for _, entry in Balls.GetTraits(ball) do
			order += 1
			local shown = math.floor(entry.Value * entry.Trait.Display + 0.5)
			local value = if (entry.Trait.Short :: string):find("%%%%") then shown .. "%" else "+" .. shown
			table.insert(chipList, (traitChip(chips, entry.Trait.Name:upper(), value, entry.Trait.Color, phone, order)))
		end

		-- Duplicate: POLISH n/10 with pips, or POLISH MAXED! +coins with every pip lime
		local pips = {}
		local maxLevel = Config.Economy.Polish.MaxLevel
		if dup then
			if phone then
				dupRow = make(
					"Frame",
					{ Name = "Duplicate", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 4 },
					column
				)
			end
			local row = dupRow :: Frame
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = if phone then Enum.HorizontalAlignment.Left else Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, if phone then 8 else 18),
			}, row)
			local maxed = result.PolishLevel == nil
			local text = if maxed
				then ("POLISH MAXED! +%s COINS"):format(formatNumber(result.SellCoins or 0))
				else ("DUPLICATE: POLISH %d/%d"):format(result.PolishLevel, maxLevel)
			local dl = CrateKit.Text(
				row,
				text,
				Head,
				if phone then 15 else 28,
				if maxed then C.Lime else C.Gold,
				if phone then 1.5 else 3
			)
			dl.AutomaticSize = Enum.AutomaticSize.X
			dl.Size = UDim2.new(0, 0, 1, 0)
			make("UIPadding", { PaddingTop = UDim.new(0, if phone then 2 else 4) }, dl)
			local pipRow = make("Frame", {
				Name = "Pips",
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.new(0, 0, 1, 0),
				LayoutOrder = 2,
			}, row)
			make("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, if phone then 4 else 6),
			}, pipRow)
			local pipSize = if phone then 11 else 22
			local pipLine = if phone then 2 else 3
			for i = 1, maxLevel do
				local holder = make(
					"Frame",
					{ BackgroundTransparency = 1, Size = UDim2.fromOffset(pipSize + 2, pipSize + 2), LayoutOrder = i },
					pipRow
				)
				local pip = make("Frame", {
					Name = "Pip",
					BackgroundColor3 = if maxed
						then C.Lime
						elseif i <= (result.PolishLevel or 0) then C.Cyan
						else C.Card,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(pipSize - pipLine * 2, pipSize - pipLine * 2),
					Rotation = 45,
				}, holder)
				CrateKit.Corner(pip, if phone then 2 else 4)
				CrateKit.Stroke(pip, C.Ink, pipLine)
				table.insert(pips, pip)
			end
		end

		-- NEW badge
		local badge: GuiObject? = nil
		if result.IsNew then
			local b = tag(content, "NEW!", {
				Size = if phone then 20 else 40,
				Stroke = if phone then 2 else 3,
				H = if phone then 34 else 64,
				PadX = if phone then 10 else 18,
				Fill = C.Pink,
				Lip = C.PinkLip,
				LipPx = if phone then 4 else 6,
				Radius = if phone then 11 else 18,
				Outline = if phone then 3 else 5,
			})
			badge = b.Holder
			b.Holder.AnchorPoint = Vector2.new(0.5, 0.5)
			local bx, by = if phone then 410 else 1100, if phone then 96 else 250
			b.Holder.Position =
				UDim2.new(0.5, left(bx) + b.Holder.Size.X.Offset / 2, 0.5, top(by) + b.Holder.Size.Y.Offset / 2)
			b.Holder.Rotation = -8
			b.Holder.ZIndex = 4
		end

		-- Buttons: EQUIP (or grey EQUIPPED) and OK
		local equipped = player:GetAttribute("EquippedBall") == ball.Id
		local equip = CrateKit.Button(content, {
			Name = "Equip",
			W = if phone then 170 else 280,
			H = if phone then 56 else 84,
			Radius = if phone then 14 else 20,
			Outline = if phone then 3 else 5,
			LipPx = if phone then 6 else 9,
			Fill = if equipped then C.Grey else C.Lime,
			Lip = if equipped then C.GreyLip else C.LimeLip,
			Text = if equipped then "EQUIPPED" else "EQUIP",
			Size = if phone then (if equipped then 20 else 26) else (if equipped then 32 else 40),
			Stroke = if phone then 2.5 else 3.5,
			Icon = if equipped then "Check" else nil,
			IconSize = if phone then 20 else 32,
			Press = if phone then 3 else 4,
		})
		equip:SetPressable(not equipped)
		local ok = CrateKit.Button(content, {
			Name = "Ok",
			W = if phone then 120 else 220,
			H = if phone then 56 else 84,
			Radius = if phone then 14 else 20,
			Outline = if phone then 3 else 5,
			LipPx = if phone then 6 else 9,
			Fill = C.Cyan,
			Lip = C.CyanLip,
			Text = "OK",
			Size = if phone then 26 else 40,
			Stroke = if phone then 2.5 else 3.5,
			Press = if phone then 3 else 4,
		})
		local buttonY
		if phone then
			equip.Holder.Position = UDim2.new(0.5, left(500), 0.5, top(300))
			ok.Holder.Position = UDim2.new(0.5, left(682), 0.5, top(300))
			buttonY = top(300)
		else
			buttonY = top(if big then 880 elseif dup then 870 else 860)
			equip.Holder.Position = UDim2.new(0.5, -262, 0.5, buttonY)
			ok.Holder.Position = UDim2.new(0.5, 42, 0.5, buttonY)
		end
		equip.Holder.ZIndex = 4
		ok.Holder.ZIndex = 4
		if equipPrompt then
			-- The gift crate: EQUIP is the way out (it shows you how to equip), OK and tapping outside are off
			ok.Holder.Visible = false
			equip.Holder.Position = if phone
				then UDim2.new(0.5, left(500), 0.5, top(300))
				else UDim2.new(0.5, -140, 0.5, buttonY)
			loop(
				tween(
					CrateKit.ScaleOf(equip.Holder),
					0.5,
					Enum.EasingStyle.Sine,
					{ Scale = 1.08 },
					Enum.EasingDirection.InOut,
					-1,
					true
				)
			)
		end

		-- ===== Reveal animation =====
		screen.Visible = true
		local flash = make("Frame", {
			Name = "Flash",
			BackgroundColor3 = C.White,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 9,
		}, screen)
		tween(flash, 0.25, Enum.EasingStyle.Linear, { BackgroundTransparency = 1 })
		Sfx.Play(if rarityIndex >= 4 then "RevealBig" else "Reveal")
		if big then
			task.delay(0.4, function()
				Sfx.Play("Firework")
			end)
		end
		-- Title UIScale 2 -> 1 + Rotation -8 -> 0 (0.30 Back Out); Legendary/Mythic then pulse 1 <-> 1.05 (0.8)
		local titleScale = CrateKit.ScaleOf(titleHolder)
		titleScale.Scale = 2
		titleHolder.Rotation = -8
		tween(titleScale, 0.3, Enum.EasingStyle.Back, { Scale = 1 })
		tween(titleHolder, 0.3, Enum.EasingStyle.Back, { Rotation = 0 })
		if big then
			task.delay(0.3, function()
				if content.Parent then
					loop(
						tween(
							titleScale,
							0.8,
							Enum.EasingStyle.Sine,
							{ Scale = 1.05 },
							Enum.EasingDirection.InOut,
							-1,
							true
						)
					)
				end
			end)
		end
		-- Ball name rises 20 px and fades in, after 0.15
		if not phone then
			local rest = nameHolder.Position
			nameHolder.Position = rest + UDim2.fromOffset(0, 20)
			nameLabel.TextTransparency = 1
			task.delay(0.15, function()
				tween(nameHolder, 0.25, Enum.EasingStyle.Quad, { Position = rest })
				tween(nameLabel, 0.25, Enum.EasingStyle.Quad, { TextTransparency = 0 })
			end)
		else
			nameLabel.TextTransparency = 1
			task.delay(0.15, function()
				tween(nameLabel, 0.25, Enum.EasingStyle.Quad, { TextTransparency = 0 })
			end)
		end
		-- A2: the ball springs out of the flash
		local ballScale = CrateKit.ScaleOf(view)
		ballScale.Scale = 0.2
		tween(ballScale, 0.4, Enum.EasingStyle.Back, { Scale = 1 })
		-- A2: the COINS value counts up from x1 (same decimals as the final number, so the chip never grows)
		if coinMult > 1 then
			local decimals = #(coinText:match("%.(%d+)") or "")
			local format = "x%." .. decimals .. "f"
			task.delay(0.2, function()
				local start = os.clock()
				local lastShown = ""
				while content.Parent do
					local k = math.min((os.clock() - start) / SHOP.Juice.CountUp, 1)
					local shown = if k >= 1 then coinText else format:format(1 + (coinMult - 1) * easeOut(k))
					if shown ~= lastShown then
						lastShown = shown
						coinValue.Text = shown
						Sfx.Play("Coin", 1 + k * 0.5, 0.5)
					end
					if k >= 1 then
						UiFx.Pop(coinChip, 1.2, 0.25)
						break
					end
					task.wait(0.05)
				end
			end)
			coinValue.Text = format:format(1)
		end
		-- Trait chips pop in 0.06 apart
		for i, chip in chipList do
			local scale = CrateKit.ScaleOf(chip)
			scale.Scale = 0
			task.delay(0.2 + (i - 1) * 0.06, function()
				tween(scale, 0.2, Enum.EasingStyle.Back, { Scale = 1 })
			end)
		end
		-- Polish pips: the new pip pops 0 -> 1.3 -> 1 (0.25 Back Out); at 10/10 every pip pops 0.04 apart
		if #pips > 0 then
			local popping = if result.PolishLevel == nil then pips else { pips[result.PolishLevel] }
			for i, pip in popping do
				local scale = CrateKit.ScaleOf(pip)
				scale.Scale = 0
				task.delay(0.35 + (i - 1) * 0.04, function()
					tween(scale, 0.15, Enum.EasingStyle.Quad, { Scale = 1.3 })
					task.wait(0.15)
					tween(scale, 0.1, Enum.EasingStyle.Back, { Scale = 1 })
				end)
			end
		end
		-- NEW: UIScale 0 -> 1 Back Out, then wobbles -10 <-> -6 (1.2)
		if badge then
			local scale = CrateKit.ScaleOf(badge)
			scale.Scale = 0
			task.delay(0.2, function()
				tween(scale, 0.3, Enum.EasingStyle.Back, { Scale = 1 })
				task.wait(0.3)
				if content.Parent then
					badge.Rotation = -10
					loop(
						tween(
							badge,
							0.6,
							Enum.EasingStyle.Sine,
							{ Rotation = -6 },
							Enum.EasingDirection.InOut,
							-1,
							true
						)
					)
				end
			end)
		end
		-- Buttons rise 40 px, after 0.4
		for _, b in { equip, ok } do
			local rest = b.Holder.Position
			b.Holder.Position = rest + UDim2.fromOffset(0, 40)
			task.delay(0.4, function()
				tween(b.Holder, 0.25, Enum.EasingStyle.Back, { Position = rest })
			end)
		end

		-- Wait for a way out: OK, EQUIP, or tapping outside the buttons after 1 s
		local closed = Instance.new("BindableEvent")
		local done = false
		local function finish(doEquip: boolean)
			if done then
				return
			end
			done = true
			if doEquip then
				equipRemote:FireServer(ball.Id)
				Sfx.Play("StreakUp", 1.2)
			end
			closed:Fire()
		end
		local shownAt = os.clock()
		equip.Activated:Connect(function()
			if not equipped then
				finish(true)
			end
		end)
		ok.Activated:Connect(function()
			finish(false)
		end)
		catcher.Activated:Connect(function()
			if not equipPrompt and os.clock() - shownAt >= 1 then
				finish(false)
			end
		end)
		if not done then
			closed.Event:Wait()
		end
		closed:Destroy()
		for _, t in loopsHere do
			t:Cancel()
		end
		local scale = CrateKit.ScaleOf(content)
		tween(scale, 0.12, Enum.EasingStyle.Quad, { Scale = 0.85 }, Enum.EasingDirection.In)
		tween(back, 0.12, Enum.EasingStyle.Linear, { BackgroundTransparency = 1 })
		task.wait(0.12)
		content:Destroy()
		back:Destroy()
		catcher:Destroy()
		flash:Destroy()
		screen.Visible = false
	end

	-- Plays the crate intro, the reel, then the reveal. Returns when the reveal closes.
	-- equipPrompt: the reveal's EQUIP is the only way out (the first-3-minutes gift crate)
	local function playOpening(crate, result, equipPrompt: boolean?)
		local ball = Balls.Get(result.BallId)
		local rarityIndex = Balls.RarityIndex(ball.Rarity)
		opening.Visible = true
		reelStage.Screen.Visible = true
		revealStage.Screen.Visible = false
		-- Overlay transparency 1 -> 0.1 (0.2)
		reelShade.BackgroundTransparency = 1
		tween(reelShade, 0.2, Enum.EasingStyle.Linear, { BackgroundTransparency = 0.1 })
		local reel = buildReel(crate)
		playIntro(crate, reel.Title.Parent, rarityIndex)

		-- The strip: tile i's centre sits under the marker when the strip is at stripX(i)
		local M = reel.M
		local pitch = M.TileW + M.Gap
		local tiles = {}
		local winTile
		for i = 1, REEL_TILES do
			local shown = if i == REEL_WIN_INDEX then ball else randomBall(crate)
			local tile, dim = reelTile(shown, M)
			tile.Position = UDim2.fromOffset((i - 1) * pitch + M.TileW / 2, 0)
			tile.Parent = reel.Strip
			table.insert(tiles, { Tile = tile, Dim = dim })
			if i == REEL_WIN_INDEX then
				winTile = tile
			end
		end
		local function stripAt(index: number): UDim2
			return UDim2.new(0.5, -((index - 1) * pitch + M.TileW / 2), 0.5, 0)
		end
		reel.Band.Visible = true
		reel.Line.Visible = true
		for _, icon in reel.Icons do
			icon.Visible = true
		end
		reel.Skip.Holder.Visible = true
		reel.Hint.Visible = true

		-- Strip slides to the prize (4.5 s Quint Out; Legendary/Mythic 5.5), stopping up to ReelJitter px off centre,
		-- then nudges to the exact centre. SKIP jumps straight there (0.25 Quad Out).
		local final = stripAt(REEL_WIN_INDEX)
		local jitter = (math.random() * 2 - 1) * SHOP.ReelJitter * pitch / 198
		reel.Strip.Position = stripAt(3)
		local spinTime = if rarityIndex >= LEGENDARY_INDEX then SHOP.SpinTimeBig else SHOP.SpinTime
		local spin =
			tween(reel.Strip, spinTime, Enum.EasingStyle.Quint, { Position = final + UDim2.fromOffset(jitter, 0) })
		local skipped = false
		local stopped = false
		spin.Completed:Connect(function()
			stopped = true
		end)
		reel.Skip.Activated:Connect(function()
			if not stopped and not skipped then
				skipped = true
				stopped = true
				spin:Cancel()
			end
		end)
		-- A tick and a marker pop (1 -> 1.15 -> 1, 0.08) every time a tile passes.
		-- A2: speed streaks while it's fast; in the last stretch a heartbeat thumps and the reel slowly zooms in
		-- (honest: the reel just slows down to the real prize, no fake near-stops).
		local J = SHOP.Juice
		local zoom = CrateKit.ScaleOf(reel.Content)
		local spinStart = os.clock()
		local lastX = reel.Strip.Position.X.Offset
		local nextBeat = spinTime - J.HeartbeatFrom
		local zoomBase, punch = 1, 0
		local lastTile = nil
		local tick = RunService.RenderStepped:Connect(function(dt)
			local x = reel.Strip.Position.X.Offset
			local speed = math.abs(x - lastX) / math.max(dt, 1 / 240)
			lastX = x
			local fast = math.clamp((speed - J.StreakFrom) / (J.StreakFull - J.StreakFrom), 0, 1)
			local width = math.max(reel.Band.AbsoluteSize.X, 1)
			for i, streak in reel.Streaks do
				-- each streak drifts left a bit slower than the tiles and wraps round
				local px = streak.Position.X.Scale - speed * dt * (0.35 + (i % 3) * 0.15) / width
				if px < -0.15 then
					px += 1.3
				end
				streak.Position = UDim2.fromScale(px, streak.Position.Y.Scale)
				streak.BackgroundTransparency = 1 - fast * J.StreakAlpha
			end
			local t = os.clock() - spinStart
			if not stopped then
				local late = math.clamp((t - (spinTime - J.HeartbeatFrom)) / J.HeartbeatFrom, 0, 1)
				zoomBase = 1 + J.ZoomIn * late * late
				if t >= nextBeat then
					nextBeat += J.HeartbeatEvery * (1 - late * J.HeartbeatSpeedUp) -- the heart races at the end
					Sfx.Play("ReelHeartbeat", 1, 0.6 + late * 0.4)
					punch = J.BeatPunch
					for _, icon in reel.Icons do
						UiFx.Pop(icon, 1.35, 0.2)
					end
				end
			end
			punch = math.max(punch - dt * J.BeatPunch * 6, 0)
			zoom.Scale = zoomBase + punch
			local index = math.floor(-x / pitch) + 1
			if index ~= lastTile then
				lastTile = index
				Sfx.Play("ReelTick", 0.9 + math.clamp(index / REEL_WIN_INDEX, 0, 1) * 0.4)
				for _, icon in reel.Icons do
					local scale = CrateKit.ScaleOf(icon)
					scale.Scale = 1.15
					tween(scale, 0.08, Enum.EasingStyle.Quad, { Scale = 1 })
				end
			end
		end)
		while not stopped do
			task.wait()
		end
		local settle =
			tween(reel.Strip, if skipped then 0.25 else SHOP.ReelSettle, Enum.EasingStyle.Quad, { Position = final })
		settle.Completed:Wait()
		tick:Disconnect()
		reel.Skip.Holder.Visible = false
		reel.Hint.Visible = false
		-- A2 landing: a shockwave ring in the prize's colour out of the marker, the screen shakes (harder for rarer)
		local rc = CrateKit.RarityColor(ball.Rarity)
		local bandMiddle = reel.Top(M.BandY + M.BandH / 2)
		for i = 1, (if rarityIndex >= 4 then 2 else 1) do
			local ring = make("Frame", {
				Name = "Shockwave",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, bandMiddle),
				Size = UDim2.fromOffset(M.TileW, M.TileW),
				ZIndex = 8,
			}, reel.Content)
			make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, ring)
			local stroke = make("UIStroke", { Color = rc, Thickness = M.Out * 4 }, ring)
			local grow = M.TileW * (J.ShockwaveSize + rarityIndex * 0.6) * (if i == 2 then 1.5 else 1)
			task.delay((i - 1) * 0.12, function()
				tween(ring, J.ShockwaveTime, Enum.EasingStyle.Quad, { Size = UDim2.fromOffset(grow, grow) })
				tween(stroke, J.ShockwaveTime, Enum.EasingStyle.Quad, { Transparency = 1, Thickness = 1 })
			end)
			task.delay(J.ShockwaveTime + 0.2, ring.Destroy, ring)
		end
		Sfx.Play("PinHit", 0.9 + rarityIndex * 0.05, 0.8)
		if rarityIndex >= 3 then
			Sfx.Play("StreakUp", 0.8 + rarityIndex * 0.1, 0.6)
			UiFx.Flash(rc, 0.1 + rarityIndex * 0.03, 0.25)
		end
		task.spawn(function()
			local shakeEnd = os.clock() + J.ShakeTime
			local strength = J.Shake * (0.5 + rarityIndex / 6)
			while os.clock() < shakeEnd and reel.Content.Parent do
				local k = (shakeEnd - os.clock()) / J.ShakeTime
				reel.Content.Position = UDim2.new(
					0.5,
					(math.random() - 0.5) * 2 * strength * k,
					0.5,
					(math.random() - 0.5) * 2 * strength * k
				)
				RunService.RenderStepped:Wait()
			end
			reel.Content.Position = UDim2.fromScale(0.5, 0.5)
		end)
		-- Landed tile UIScale 1 -> 1.12 (0.2 Back Out), the others fade back, hold, then the reveal
		tween(CrateKit.ScaleOf(winTile), 0.2, Enum.EasingStyle.Back, { Scale = 1.12 })
		for _, t in tiles do
			if t.Tile ~= winTile then
				tween(t.Dim, 0.2, Enum.EasingStyle.Linear, { BackgroundTransparency = 0.4 })
			end
		end
		task.wait(0.2 + SHOP.ReelHold)

		reelStage.Screen.Visible = false
		showReveal(ball, result, equipPrompt)
		reel.Content:Destroy()
		opening.Visible = false
	end
	-- Lets other screens (like the daily reward) play a crate the server already opened
	CrateController.PlayOpening = function(crate, result, equipPrompt: boolean?)
		busy = true
		setOpen(false)
		playOpening(crate, result, equipPrompt)
		busy = false
	end

	-- backToShop: reopen the shop afterwards (when bought from the shop screen, not the kiosk)
	buy = function(crate, backToShop: boolean?)
		if busy then
			return
		end
		if CrateController.Locked(crate) then
			task.spawn(showToast, (CrateController.LockText(crate)))
			return
		end
		if not hasFree(crate) and (player:GetAttribute("Coins") or 0) < CrateController.Price(crate) then
			task.spawn(showToast, "Not enough coins")
			return
		end
		busy = true
		local firstBought = not hasFree(crate) and (player:GetAttribute("CratesBought") or 0) == 0
		local ok, result = pcall(openCrate.InvokeServer, openCrate, crate.Id)
		if not ok or not result or not result.Ok then
			busy = false
			task.spawn(showToast, if ok and result and result.Error then result.Error else "Try again")
			return
		end
		local wasZone = shopZone
		setOpen(false)
		playOpening(crate, result)
		busy = false
		CrateController.Opened:Fire(crate, result)
		if result.Extras then
			-- TRIPLE HATCH: the other balls from this open
			local names = {}
			for _, extra in result.Extras do
				local ball = Balls.Get(extra.BallId)
				table.insert(names, (if ball then ball.Name:upper() else "?") .. (if extra.IsNew then " (NEW)" else ""))
			end
			task.spawn(showToast, "ALSO GOT: " .. table.concat(names, ", "))
		end
		if firstBought and result.IsNew then
			-- The first crate bought with coins: arrows show how to equip its new ball (BALLS button, then EQUIP)
			CollectionBookController.GuideEquip(result.BallId)
			return
		end
		if backToShop ~= false then
			shopZone = wasZone
			setOpen(true) -- straight back to the shop for the next one
		end
	end
	-- For the lobby kiosk and Rizzo: their buy buttons open a crate right away
	CrateController.Buy = function(crate)
		buy(crate, false)
	end
	-- The shop screen with one zone's crates: the lobby kiosk = zone 2, the zone 3/4 counters pass their zone
	CrateController.OpenShop = function(zone: number?)
		shopZone = zone or 2
		setOpen(true)
	end
	CrateController.CloseShop = function()
		setOpen(false)
	end
	-- Studio only: lets a test script build the reel and the reveal without the intro (which needs rendered frames)
	if RunService:IsStudio() then
		CrateController.Test =
			{ BuildReel = buildReel, ReelTile = reelTile, ShowReveal = showReveal, Opening = opening }
	end
	-- The odds view of one crate (opens the shop on that crate's zone first)
	CrateController.ShowOdds = function(crate)
		shopZone = crate.Zone or 1
		setOpen(true)
		showOdds(crate)
	end
end

return CrateController
