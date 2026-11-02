-- Studio only (TEST panel > UI KIT V2): a board that shows every piece of the new kit (Modules/SlKit) the way the
-- owner's 'Strike Legends UI.html' board A lays them out, so step V1 can be checked by eye. Tap things to see the
-- motion (button press, locked card shake, toast). Nothing here touches the game.
local SlKit = require(script.Parent:WaitForChild("SlKit"))

local C = SlKit.C
local make = SlKit.Make

local SlKitPreview = {}

local gui: ScreenGui? = nil

local function heading(parent: Instance, text: string, order: number)
	local label = SlKit.Text(parent, text, "Title", C.Ink, {
		Size = UDim2.new(1, 0, 0, 40),
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	})
	label:FindFirstChildOfClass("UIStroke").Enabled = false
end

local function strip(parent: Instance, height: number, order: number, gap: number?): Frame
	local frame = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
	}, parent)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, gap or 16),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, frame)
	return frame
end

local function slot(parent: Instance, w: number, h: number, order: number): Frame
	return make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(w, h),
		LayoutOrder = order,
	}, parent)
end

function SlKitPreview.Toggle()
	if gui then
		gui:Destroy()
		gui = nil
		return
	end
	local screen = make("ScreenGui", {
		Name = "SlKitPreview",
		ResetOnSpawn = false,
		DisplayOrder = 60,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, SlKit.PlayerGui())
	gui = screen
	make("Frame", {
		Name = "Backdrop",
		BackgroundColor3 = Color3.fromHex("EEF2F8"), -- the light page of the owner's kit board
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
	}, screen)
	local scroll = make("ScrollingFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.XY,
		ScrollBarThickness = 8,
		BorderSizePixel = 0,
	}, screen)
	local page = make("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(1500, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, scroll)
	make("UIListLayout", { Padding = UDim.new(0, 24), SortOrder = Enum.SortOrder.LayoutOrder }, page)
	make("UIPadding", {
		PaddingTop = UDim.new(0, 70),
		PaddingLeft = UDim.new(0, 60),
		PaddingBottom = UDim.new(0, 80),
	}, page)

	local closeAll = SlKit.Button(screen, { Text = "CLOSE PREVIEW", Paint = "Red", Size = "M" })
	closeAll.Holder.Size = UDim2.fromOffset(260, 70)
	closeAll.Holder.AnchorPoint = Vector2.new(1, 0)
	closeAll.Holder.Position = UDim2.new(1, -24, 0, 70)
	closeAll.Holder.ZIndex = 50
	closeAll.Holder.Activated:Connect(SlKitPreview.Toggle)

	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	heading(page, "UI KIT V2 - window frame", nextOrder())
	-- Window: SHOP plate, close X, tabs, well with 3 cards (board A top-left)
	local windowSlot = slot(page, 820, 560, nextOrder())
	local window = SlKit.Window(windowSlot, { Title = "SHOP", Size = UDim2.fromOffset(720, 480) })
	window.Holder.AnchorPoint = Vector2.new(0, 0)
	window.Holder.Position = UDim2.fromOffset(20, 50)
	window.Close.Holder.Activated:Connect(function()
		task.delay(0.6, function()
			if window.Holder.Parent then
				window:Open()
			end
		end)
	end)
	local tabs = SlKit.Tabs(window.Content, {
		{ Id = "Balls", Text = "BALLS" },
		{ Id = "Bags", Text = "BAGS" },
		{ Id = "Pets", Text = "PETS", Dot = 1 },
	}, nil, { Width = 120 })
	tabs.Holder.Position = UDim2.fromOffset(0, 0)
	local well = SlKit.Well(window.Content, {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 1, -66),
	})
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 20),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, well)
	local mint = SlKit.Card(well, { Rarity = "Uncommon", Title = "Mint", Value = "+5", Button = "EQUIP", State = "Done" })
	mint.Holder.LayoutOrder = 1
	local comet = SlKit.Card(well, { Rarity = "Rare", Title = "Comet", Value = "+12", Price = 25000 })
	comet.Holder.LayoutOrder = 2
	local nebula = SlKit.Card(well, { Rarity = "Epic", Title = "Nebula", Value = "+40", Price = 400000, State = "New", Count = 1 })
	nebula.Holder.LayoutOrder = 3
	for _, card in { mint, comet, nebula } do
		card.Holder.Size = UDim2.fromOffset(186, 250)
	end

	heading(page, "Buttons - 5 colours x S / M / L, pressed, disabled", nextOrder())
	for _, info in {
		{ "Green", "BUY" },
		{ "Blue", "INFO" },
		{ "Pink", "UNLOCK" },
		{ "Red", "CLOSE" },
		{ "Gold", "REBIRTH" },
	} do
		local line = strip(page, 100, nextOrder(), 24)
		for i, size in { "S", "M", "L" } do
			SlKit.Button(line, { Text = info[2], Paint = info[1], Size = size }).Holder.LayoutOrder = i
		end
		local pressed = SlKit.Button(line, { Text = info[2], Paint = info[1], Size = "M" })
		pressed.Holder.LayoutOrder = 4
		pressed:SetPressed(true)
		local off = SlKit.Button(line, { Text = info[2], Paint = info[1], Size = "M", Disabled = true })
		off.Holder.LayoutOrder = 5
	end

	heading(page, "Price buttons, counter pills, progress bars", nextOrder())
	local prices = strip(page, 70, nextOrder())
	SlKit.PriceButton(prices, { Currency = "Coin", Amount = 12500 }).Holder.LayoutOrder = 1
	SlKit.PriceButton(prices, { Currency = "Gem", Amount = 250 }).Holder.LayoutOrder = 2
	SlKit.PriceButton(prices, { Currency = "Robux", Amount = 99 }).Holder.LayoutOrder = 3
	SlKit.PriceButton(prices, { Currency = "Coin", Amount = 1200000, Affordable = false }).Holder.LayoutOrder = 4
	local pills = strip(page, 80, nextOrder(), 32)
	SlKit.Pill(pills, { Icon = "cur_coin", Text = "1.47M", Sub = "+95K/min", Width = 300 }).Holder.LayoutOrder = 1
	SlKit.Pill(pills, { Icon = "cur_gem", Text = "2.34K", Plus = true, Width = 260 }).Holder.LayoutOrder = 2
	SlKit.Pill(pills, { Icon = "cur_pin", Text = "540", Width = 200 }).Holder.LayoutOrder = 3
	local bars = strip(page, 60, nextOrder(), 24)
	SlKit.ProgressBar(bars, { Value = 350, Max = 700 }).Holder.LayoutOrder = 1
	SlKit.ProgressBar(bars, { Value = 590, Max = 700 }).Holder.LayoutOrder = 2
	local full = SlKit.ProgressBar(bars, { Value = 700, Max = 700 })
	full.Holder.LayoutOrder = 3
	local animated = SlKit.ProgressBar(bars, { Value = 0, Max = 700 })
	animated.Holder.LayoutOrder = 4
	task.spawn(function()
		local v = 0
		while screen.Parent do
			v = (v + 140) % 840
			animated:Set(math.min(v, 700), 700, nil, true)
			if v >= 700 then
				SlKit.Shake(full.Holder, 6, 0, 0.4)
			end
			task.wait(1.2)
		end
	end)

	heading(page, "Item card - 6 rarities", nextOrder())
	local rarities = strip(page, 280, nextOrder())
	local samples = {
		{ "Common", "Rubber", "+2", 250, "Coin" },
		{ "Uncommon", "Mint", "+5", 2500, "Coin" },
		{ "Rare", "Comet", "+12", 25000, "Coin" },
		{ "Epic", "Nebula", "+40", 400000, "Coin" },
		{ "Legendary", "Solar", "+120", 750, "Gem" },
		{ "Mythic", "Prism", "+400", 399, "Robux" },
	}
	for i, s in samples do
		SlKit.Card(rarities, { Rarity = s[1], Title = s[2], Value = s[3], Price = s[4], Currency = s[5] }).Holder.LayoutOrder =
			i
	end

	heading(page, "States - normal, locked, done, ready, new, ??? (tap locked / ??? to shake)", nextOrder())
	local states = strip(page, 290, nextOrder())
	for i, s in {
		{ "Rare", "Comet", "+12", 25000, "Normal" },
		{ "Epic", "Nebula", "+40", 400000, "Locked" },
		{ "Uncommon", "Mint", "+5", nil, "Done" },
		{ "Rare", "Comet", "+12", 25000, "Ready" },
		{ "Legendary", "Solar", "+120", 12000000, "New", 2 },
		{ "Common", "Rubber", "+2", 250, "Unknown" },
	} do
		local card = SlKit.Card(states, {
			Rarity = s[1],
			Title = s[2],
			Value = s[3],
			Price = s[4],
			Button = if s[4] then nil else "EQUIP",
			State = s[5],
			Count = s[6],
		})
		card.Holder.LayoutOrder = i
	end

	heading(page, "Badges, toast, tooltip bubbles (tap the toasts row to replay)", nextOrder())
	local badges = strip(page, 70, nextOrder(), 40)
	local dot = SlKit.Dot(slot(badges, 40, 40, 1), 3)
	dot.Position = UDim2.fromScale(0.5, 0.5)
	local bigDot = SlKit.Dot(slot(badges, 40, 40, 2), 12, true)
	bigDot.Position = UDim2.fromScale(0.5, 0.5)
	SlKit.Tick(badges).LayoutOrder = 3
	local lock = SlKit.Padlock(slot(badges, 44, 44, 4))
	lock.Position = UDim2.fromScale(0.5, 0.5)
	local hint = slot(badges, 260, 70, 5)
	SlKit.Bubble(hint, { Text = "SELL HERE!" })
	local infoSlot = slot(badges, 200, 70, 6)
	SlKit.Bubble(infoSlot, { Text = "x10 COINS", Info = true, Side = "Left" })

	local toastRow = make("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(1, 0, 0, 110),
		LayoutOrder = nextOrder(),
	}, page)
	local function toasts()
		SlKit.Toast(toastRow, { Icon = "cur_coin", Text = "+50.8K", Position = UDim2.new(0, 160, 0, 20) })
		SlKit.Toast(toastRow, { Icon = "cur_coin", Text = "NOT ENOUGH", Error = true, Position = UDim2.new(0, 520, 0, 20) })
		dot:SetAttribute("Count", math.random(1, 9))
	end
	toastRow.Activated:Connect(toasts)
	toasts()
end

return SlKitPreview
