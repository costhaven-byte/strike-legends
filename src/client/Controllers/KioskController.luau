-- The crate shop kiosk in the lobby (Workspace.Hub.CrateShop, built in Studio from the owner's "Crate Kiosk" design,
-- 2026-10-21): Bronze, Silver and Gold stations in a row. Each has a floating crate, a price plate and a lime BUY button.
-- Fills the price plates from Config, makes the crates float and turn (Silver's light ring spins, Gold's sparkles
-- orbit), pulses the BUY buttons, plays the hover look while you're close (glow up, crate leans to you, BUY swells)
-- and the purchase burst (shake, lid flash, rays, ring, coins). The odds point opens the shop screen.
-- Buying still goes through CrateController and the server; the kiosk is just another way in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Currency = require(Shared.Modules.Currency)
local CrateController = require(script.Parent.CrateController)

local SHOP = Config.CrateShop
local FONT = "rbxasset://fonts/families/GothamSSm.json"
local COIN_COLOR = Color3.fromRGB(255, 200, 40)
local FREE_COLOR = Color3.fromRGB(125, 255, 60)
local BUTTON_BRIGHT = Color3.fromRGB(96, 214, 100) -- the BUY cap pulses toward this (batch A2: soft, so the BUY text stays readable)
local PPS = 50 -- SurfaceGui pixels per stud

local player = Players.LocalPlayer

local KioskController = {}

-- Every number on screen uses the shared formatter (Config.Numbers)
local formatNumber = Currency.Format

-- The screens face the front of the kiosk, which is each part's Back face
local function surface(screen: BasePart): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.Brightness = SHOP.ScreenBrightness
	gui.Parent = screen
	return gui
end

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	l.FontFace = Font.new(FONT, Enum.FontWeight.Heavy)
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function glow(textLabel: TextLabel, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = textLabel
end

local function crateById(id: string)
	for _, crate in Config.Crates do
		if crate.Id == id then
			return crate
		end
	end
	return nil
end

local function buildMarquee(screen: BasePart)
	local gui = surface(screen)
	local text = label(gui, {
		Size = UDim2.new(1, -40, 1, -16),
		Position = UDim2.fromOffset(20, 8),
		Text = "CRATE SHOP",
		TextColor3 = Color3.fromRGB(255, 230, 0),
	})
	glow(text, Color3.fromRGB(255, 43, 214), 4)
end

-- "OPEN" is an old neon tube sign: it buzzes, stutters and now and then drops out for a moment,
-- and the little light it throws on the kiosk flickers with it
local function buildOpenSign(screen: BasePart)
	local sign = SHOP.OpenSign
	local gui = surface(screen)
	local box = Instance.new("Frame")
	box.BackgroundTransparency = 1
	box.Size = UDim2.new(1, -14, 1, -14)
	box.Position = UDim2.fromOffset(7, 7)
	box.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = box
	local tube = Instance.new("UIStroke")
	tube.Thickness = 3
	tube.Parent = box
	local text = label(box, {
		Size = UDim2.new(1, -24, 1, -14),
		Position = UDim2.fromOffset(12, 7),
		Text = "OPEN",
	})
	local halo = Instance.new("UIStroke")
	halo.Thickness = 3
	halo.Parent = text

	local light = Instance.new("PointLight")
	light.Color = sign.Color
	light.Range = sign.LightRange
	light.Shadows = false
	light.Parent = screen

	local function set(level: number) -- 1 = fully lit, 0 = off
		text.TextColor3 = sign.OffText:Lerp(sign.OnText, level)
		halo.Color = sign.OffGlow:Lerp(sign.Color, level)
		tube.Color = sign.OffGlow:Lerp(sign.Color, level)
		light.Brightness = sign.LightBrightness * level
	end
	set(1)

	task.spawn(function()
		while text.Parent do
			task.wait(sign.CalmMin + math.random() * (sign.CalmMax - sign.CalmMin))
			for _ = 1, math.random(2, 6) do
				set(math.random() * 0.25)
				task.wait(0.03 + math.random() * 0.09)
				set(0.7 + math.random() * 0.3)
				task.wait(0.03 + math.random() * 0.12)
			end
			if math.random() < sign.DropoutChance then
				set(0)
				task.wait(0.4 + math.random() * 1.2)
				set(0.5)
				task.wait(0.06)
				set(0)
				task.wait(0.1)
			end
			set(1)
		end
	end)
end

-- Odds board: one column per crate, one row per rarity, the pity guarantee at the bottom
local function buildOdds(screen: BasePart)
	local gui = surface(screen)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = gui

	local rows = #Config.Rarities + 3 -- title, crate names, rarities, pity line
	local rowHeight = 1 / rows
	local title =
		label(gui, { Size = UDim2.fromScale(1, rowHeight), Text = "ODDS", TextColor3 = Color3.fromRGB(255, 230, 0) })
	glow(title, Color3.fromRGB(120, 80, 0), 1)

	local columns = #Config.Crates
	local nameWidth = 0.4
	local columnWidth = (1 - nameWidth) / columns
	for c, crate in Config.Crates do
		label(gui, {
			Position = UDim2.fromScale(nameWidth + (c - 1) * columnWidth, rowHeight),
			Size = UDim2.fromScale(columnWidth, rowHeight * 0.85),
			Text = (crate.Name:upper():gsub(" CRATE", "")),
			TextColor3 = crate.Color,
		})
	end
	for r, rarity in Config.Rarities do
		local y = (r + 1) * rowHeight
		label(gui, {
			Position = UDim2.fromScale(0, y),
			Size = UDim2.fromScale(nameWidth, rowHeight * 0.8),
			Text = rarity.Name,
			TextColor3 = rarity.Color,
			TextXAlignment = Enum.TextXAlignment.Left,
			FontFace = Font.new(FONT, Enum.FontWeight.Bold),
		})
		for c, crate in Config.Crates do
			label(gui, {
				Position = UDim2.fromScale(nameWidth + (c - 1) * columnWidth, y),
				Size = UDim2.fromScale(columnWidth, rowHeight * 0.8),
				Text = ("%g%%"):format(crate.Odds[rarity.Name] or 0),
				TextColor3 = rarity.Color,
				FontFace = Font.new(FONT, Enum.FontWeight.Bold),
			})
		end
	end
	local parts = {}
	for _, row in Config.Economy.CratePity do
		local names = {}
		for _, crate in Config.Crates do
			if row.Crates[crate.Id] then
				table.insert(names, (crate.Name:gsub(" Crate", "")))
			end
		end
		table.insert(parts, ("%s %s+ in %d"):format(table.concat(names, "/"), row.Rarity, row.After))
	end
	label(gui, {
		Position = UDim2.fromScale(0, (rows - 1) * rowHeight),
		Size = UDim2.fromScale(1, rowHeight * 0.8),
		Text = "GUARANTEED: " .. table.concat(parts, " · "),
		TextColor3 = Color3.fromRGB(200, 190, 230),
		FontFace = Font.new(FONT, Enum.FontWeight.Bold),
	})
end

-- Price plaque under each crate: the price, or the free crates you have waiting
local function buildPrice(screen: BasePart, crate)
	local gui = surface(screen)
	-- The 3D coin sits on the left third of the plate, so the number fills the rest
	local text = label(gui, {
		Size = UDim2.new(0.66, -8, 1, -8),
		Position = UDim2.new(0.33, 0, 0, 4),
		RichText = true,
	})
	-- Shine sweep: a soft white band slides across the plate now and then
	local shine = Instance.new("Frame")
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BorderSizePixel = 0
	shine.Size = UDim2.fromScale(1, 1)
	shine.Parent = gui
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 20
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = shine
	task.spawn(function()
		while gui.Parent do
			task.wait(SHOP.PriceShineEvery + math.random())
			gradient.Offset = Vector2.new(-1, 0)
			TweenService:Create(gradient, TweenInfo.new(0.7, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) })
				:Play()
		end
	end)
	local function refresh()
		if CrateController.Locked(crate) then
			text.Text = ("🔒 ZONE %d"):format(crate.Zone or 1)
			text.TextColor3 = Color3.fromRGB(150, 140, 175)
		elseif CrateController.HasFree and CrateController.HasFree(crate) then
			text.Text = ("FREE x%d"):format(player:GetAttribute("FreeCrates") or 0)
			text.TextColor3 = FREE_COLOR
		else
			text.Text = formatNumber(CrateController.Price(crate))
			text.TextColor3 = Color3.new(1, 1, 1)
		end
	end
	player:GetAttributeChangedSignal("FreeCrates"):Connect(refresh)
	player:GetAttributeChangedSignal("CratesBought"):Connect(refresh)
	player:GetAttributeChangedSignal("RankLevel"):Connect(refresh)
	return refresh
end

-- A locked crate's station: its display crate goes black with an "UNLOCKS IN <ZONE>" sign over it
local function buildLock(station: Instance, crate): (boolean) -> ()
	local display = station:FindFirstChild("Display")
	local looks = {}
	if display then
		for _, part in display:GetDescendants() do
			if part:IsA("BasePart") then
				looks[part] = { Color = part.Color, Material = part.Material }
			end
		end
	end
	local sign = Instance.new("BillboardGui")
	sign.Name = "ZoneLockSign"
	sign.Size = UDim2.fromScale(7, 2.4)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
	sign.MaxDistance = 60
	sign.LightInfluence = 0
	local title, sub = CrateController.LockText(crate)
	local top = label(sign, { Size = UDim2.fromScale(1, 0.6), Text = "🔒 " .. title, TextColor3 = crate.Color })
	glow(top, Color3.new(0, 0, 0), 2)
	local bottom = label(sign, {
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.4),
		Text = sub,
		TextColor3 = Color3.new(1, 1, 1),
	})
	glow(bottom, Color3.new(0, 0, 0), 2)
	sign.Adornee = if display and display:IsA("Model")
		then display.PrimaryPart or display:FindFirstChildWhichIsA("BasePart", true)
		else nil
	sign.Parent = station
	return function(locked: boolean)
		sign.Enabled = locked and sign.Adornee ~= nil
		for part, look in looks do
			part.Color = if locked then Color3.fromRGB(8, 7, 14) else look.Color
			part.Material = if locked then Enum.Material.SmoothPlastic else look.Material
		end
	end
end

local function prompt(parent: Instance, props: { [string]: any }): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.MaxActivationDistance = SHOP.PromptDistance
	p.RequiresLineOfSight = false
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function partsOf(model: Instance): { BasePart }
	local list = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(list, part)
		end
	end
	return list
end

-- Every light in a station, with its normal brightness, so hover can turn them up
local function stationLights(station: Instance)
	local lights = {}
	for _, light in station:GetDescendants() do
		if light:IsA("Light") then
			table.insert(lights, { Light = light, Brightness = light.Brightness })
		end
	end
	return lights
end

local function effectPart(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- Purchase burst, all on this client: a flash, rays and a ring of light out of the crate, and a spray of coins
-- that bounce on the floor
local function burst(center: Vector3, color: Color3)
	local fx = SHOP.Purchase
	local folder = Instance.new("Folder")
	folder.Name = "KioskBurst"
	folder.Parent = Workspace
	local fade = TweenInfo.new(fx.BurstTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local core = effectPart({
		Shape = Enum.PartType.Ball,
		Color = Color3.new(1, 1, 1),
		Size = Vector3.one * 1.5,
		Position = center,
		Transparency = 0.1,
	})
	local flash = Instance.new("PointLight")
	flash.Color = color
	flash.Range = 18
	flash.Brightness = 6
	flash.Parent = core
	core.Parent = folder
	TweenService:Create(core, fade, { Size = Vector3.one * 4, Transparency = 1 }):Play()
	TweenService:Create(flash, fade, { Brightness = 0 }):Play()

	-- Rays fan out in a circle facing the camera, like the design's light burst
	local camera = Workspace.CurrentCamera
	local facing = if camera then CFrame.lookAt(center, camera.CFrame.Position) else CFrame.new(center)
	for i = 1, fx.Rays do
		local spin = facing * CFrame.Angles(0, 0, (i / fx.Rays) * math.pi * 2 + math.random() * 0.3)
		local ray = effectPart({
			Color = color:Lerp(Color3.new(1, 1, 1), 0.5),
			Size = Vector3.new(0.18, 1, 0.18),
			CFrame = spin * CFrame.new(0, 1.2, 0),
			Transparency = 0.15,
		})
		ray.Parent = folder
		TweenService:Create(ray, fade, {
			Size = Vector3.new(0.35, 6, 0.35),
			CFrame = spin * CFrame.new(0, 3.8, 0),
			Transparency = 1,
		}):Play()
	end

	local ring = effectPart({
		Shape = Enum.PartType.Cylinder,
		Color = color,
		Size = Vector3.new(0.1, 1, 1),
		CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		Transparency = 0.2,
	})
	ring.Parent = folder
	TweenService:Create(ring, fade, {
		Size = Vector3.new(0.05, fx.RingGrow * 2, fx.RingGrow * 2),
		Transparency = 1,
	}):Play()

	for _ = 1, fx.Coins do
		local coin = Instance.new("Part")
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.12, 0.55, 0.55)
		coin.Color = COIN_COLOR
		coin.Material = Enum.Material.SmoothPlastic
		coin.Reflectance = 0.2
		coin.CanQuery = false
		coin.CanTouch = false
		coin.Massless = true
		coin.CFrame = CFrame.new(center) * CFrame.Angles(math.random() * 6, math.random() * 6, 0)
		local angle = math.random() * math.pi * 2
		local out = fx.CoinSpeed * (0.25 + math.random() * 0.35)
		coin.AssemblyLinearVelocity =
			Vector3.new(math.cos(angle) * out, fx.CoinSpeed * (0.6 + math.random() * 0.5), math.sin(angle) * out)
		coin.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), 0)
		coin.Parent = folder
		task.delay(fx.CoinLife * (0.7 + math.random() * 0.3), function()
			TweenService:Create(coin, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		end)
	end
	task.delay(fx.CoinLife + 0.4, function()
		folder:Destroy()
	end)
end

function KioskController:Start()
	local hub = Workspace:WaitForChild("Hub", 30)
	local kiosk = hub and hub:WaitForChild("CrateShop", 10)
	local screens = kiosk and kiosk:WaitForChild("Screens", 10)
	local stations = kiosk and kiosk:WaitForChild("Stations", 10)
	if not (screens and stations) then
		warn("[KioskController] Workspace.Hub.CrateShop is missing its Screens or Stations, so the kiosk is off")
		return
	end
	-- CrateController hooks up its Buy/OpenShop functions when it starts
	while not CrateController.Buy do
		task.wait(0.1)
	end

	-- Older kiosk screens, only if they're there
	local marquee = screens:FindFirstChild("Marquee")
	if marquee then
		buildMarquee(marquee)
	end
	local openSign = screens:FindFirstChild("OpenSign")
	if openSign then
		buildOpenSign(openSign)
	end
	local odds = screens:FindFirstChild("Odds")
	if odds then
		buildOdds(odds)
	end

	local hover = SHOP.Hover
	local fx = SHOP.Purchase
	local displays = {}
	for _, station in stations:GetChildren() do
		local crate = crateById(station:GetAttribute("CrateId") or station.Name)
		if not crate then
			continue
		end
		local priceScreen = screens:FindFirstChild(crate.Id .. "Price")
		local refreshPrice = if priceScreen then buildPrice(priceScreen, crate) else function() end

		local d = {
			Hover = 0, -- 0 = normal look, 1 = full hover look
			Target = 0,
			Phase = math.random() * math.pi * 2,
			Sparkles = {},
			Lights = stationLights(station),
			Lid = {},
			Shake = 0, -- os.clock() when the purchase shake ends
		} :: any

		-- Hold the lime button to open this crate
		local button = station:WaitForChild("BuyButton") :: BasePart
		local buyPrompt = prompt(button:WaitForChild("PromptPoint"), {
			Name = "BuyPrompt",
			ObjectText = crate.Name,
			HoldDuration = SHOP.HoldDuration,
		})
		local setLocked = buildLock(station, crate)
		local function refreshPrompt()
			local locked = CrateController.Locked(crate)
			setLocked(locked)
			buyPrompt.Enabled = not locked
			local free = CrateController.HasFree(crate)
			buyPrompt.ActionText = if free
				then "Open FREE"
				else ("Open  (%s coins)"):format(formatNumber(CrateController.Price(crate)))
			refreshPrice()
		end
		player:GetAttributeChangedSignal("FreeCrates"):Connect(refreshPrompt)
		player:GetAttributeChangedSignal("CratesBought"):Connect(refreshPrompt)
		player:GetAttributeChangedSignal("RankLevel"):Connect(refreshPrompt)
		refreshPrompt()
		-- Hover = you're close enough to buy
		buyPrompt.PromptShown:Connect(function()
			d.Target = 1
		end)
		buyPrompt.PromptHidden:Connect(function()
			d.Target = 0
		end)

		local display = station:FindFirstChild("Display")
		if display and display:IsA("Model") then
			d.Model = display
			d.Home = display:GetPivot()
			-- Gold's sparkles leave the crate and orbit it on their own instead of turning with it
			for _, sparkle in display:GetDescendants() do
				if sparkle:IsA("Model") and sparkle.Name:match("^sparkle_") then
					local offset = d.Home:PointToObjectSpace(sparkle:GetPivot().Position)
					table.insert(d.Sparkles, {
						Model = sparkle,
						Parts = partsOf(sparkle),
						Angle = math.atan2(offset.Z, offset.X),
						Radius = Vector2.new(offset.X, offset.Z).Magnitude,
						Height = offset.Y,
					})
				end
			end
			if #d.Sparkles > 0 then
				local folder = Instance.new("Folder")
				folder.Name = "Sparkles"
				folder.Parent = station
				for _, sparkle in d.Sparkles do
					sparkle.Model.Parent = folder
				end
			end
			local lid = display:FindFirstChild("Lid", true)
			if lid then
				d.Lid = partsOf(lid)
			end
		end
		local ring = station:FindFirstChild("LightRing")
		if ring and ring:IsA("Model") then
			d.Ring = ring
			d.RingHome = ring:GetPivot()
		end
		local art = station:FindFirstChild("BuyButtonArt")
		if art and art:IsA("Model") then
			d.Button = art
			d.ButtonScale = art:GetScale()
			for _, part in partsOf(art) do
				-- the cap was Neon; batch A2 made it plain plastic (Neon washed out the BUY text)
				if part.Material == Enum.Material.Neon or part.Name:match("^buy_cap") then
					d.ButtonGlow = part
					d.ButtonColor = part.Color
				end
			end
		end
		table.insert(displays, d)

		buyPrompt.Triggered:Connect(function()
			-- The burst only plays when the buy will go through; otherwise CrateController says why
			local canBuy = not CrateController.Locked(crate)
				and (
					CrateController.HasFree(crate)
					or (player:GetAttribute("Coins") or 0) >= CrateController.Price(crate)
				)
			if not canBuy or not d.Model then
				task.spawn(CrateController.Buy, crate)
				return
			end
			d.Shake = os.clock() + fx.ShakeTime
			task.delay(fx.ShakeTime, function()
				local looks = {}
				for _, part in d.Lid do
					looks[part] = { part.Color, part.Material }
					part.Color = Color3.new(1, 1, 1)
					part.Material = Enum.Material.Neon
				end
				task.delay(fx.FlashTime, function()
					for part, look in looks do
						part.Color, part.Material = look[1], look[2]
					end
				end)
				burst(d.Model:GetPivot().Position, crate.Color)
				task.spawn(CrateController.Buy, crate)
			end)
		end)
	end

	-- Odds and the full shop screen: a prompt in the middle of the kiosk front
	local oddsPoint = kiosk:FindFirstChild("OddsPoint", true)
	if oddsPoint then
		local shopPrompt = prompt(oddsPoint, {
			Name = "ShopPrompt",
			ActionText = "See odds",
			ObjectText = "Crate Shop",
			KeyboardKeyCode = Enum.KeyCode.F,
			GamepadKeyCode = Enum.KeyCode.ButtonY,
		})
		shopPrompt.Triggered:Connect(function()
			CrateController.OpenShop()
		end)
	end

	-- Everything moves only while you're close enough to see it (saves phone battery)
	local middle = kiosk:GetPivot().Position
	RunService.Heartbeat:Connect(function(dt)
		local camera = Workspace.CurrentCamera
		if not camera or (camera.CFrame.Position - middle).Magnitude > SHOP.AnimateDistance then
			return
		end
		local t = os.clock()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		for _, d in displays do
			d.Hover += (d.Target - d.Hover) * math.min(dt * hover.Speed, 1)
			local h = d.Hover
			if d.Model then
				local bob = (math.sin(t * 1.5 + d.Phase) + 1) * 0.5 * SHOP.CrateBob + h * hover.Lift
				local lean = CFrame.identity
				if h > 0.01 and root then
					-- Tip the top of the crate toward you
					local toYou = (root.Position - d.Home.Position) * Vector3.new(1, 0, 1)
					if toYou.Magnitude > 0.1 then
						lean = CFrame.fromAxisAngle(Vector3.new(0, 1, 0):Cross(toYou.Unit), math.rad(hover.Tilt) * h)
					end
				end
				local shake = CFrame.identity
				if t < d.Shake then
					local a = math.rad(fx.ShakeAngle)
					shake = CFrame.Angles((math.random() - 0.5) * a, 0, (math.random() - 0.5) * a)
				end
				local spin = CFrame.Angles(0, t * SHOP.CrateSpin * math.pi * 2, 0)
				d.Model:PivotTo(
					CFrame.new(d.Home.Position + Vector3.new(0, bob, 0)) * lean * shake * spin * d.Home.Rotation
				)
			end
			for i, s in d.Sparkles do
				local angle = s.Angle + t * SHOP.SparkleOrbit * math.pi * 2
				local radius = s.Radius + math.sin(t * 0.9 + i * 1.7) * SHOP.SparkleDrift
				local height = s.Height + math.sin(t * 1.3 + i * 2.1) * SHOP.SparkleFloat
				local spot = d.Home * Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
				s.Model:PivotTo(CFrame.new(spot) * CFrame.Angles(0, t * 2 + i, 0))
				local twinkle = 0.5 - math.sin(t * 3.1 + i * 1.3) * 0.5
				for _, part in s.Parts do
					part.Transparency = twinkle
				end
			end
			if d.Ring then
				d.Ring:PivotTo(d.RingHome * CFrame.Angles(0, t * SHOP.RingSpin * math.pi * 2, 0))
			end
			if d.Button then
				local scale = d.ButtonScale * (1 + (hover.ButtonSwell - 1) * h)
				if math.abs(scale - d.Button:GetScale()) > 0.001 then
					d.Button:ScaleTo(scale)
				end
				if d.ButtonGlow then
					local pulse = (math.sin(t * SHOP.ButtonPulse * math.pi * 2) + 1) * 0.5
					d.ButtonGlow.Color = d.ButtonColor:Lerp(BUTTON_BRIGHT, 0.6 * pulse + 0.4 * h)
				end
			end
			for _, l in d.Lights do
				l.Light.Brightness = l.Brightness * (1 + (hover.LightBoost - 1) * h)
			end
		end
	end)
end

return KioskController
