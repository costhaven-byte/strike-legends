-- The crate shop kiosk in the lobby (Workspace.Hub.CrateShop, built in Studio from the owner's design).
-- Fills its screens from Config (marquee, prices, odds board), makes the display crates hover and turn,
-- and runs its buttons: a lime buy button per crate opens that crate, the joystick opens the shop screen.
-- Buying still goes through CrateController and the server; the kiosk is just another way in.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CrateController = require(script.Parent.CrateController)

local SHOP = Config.CrateShop
local FONT = "rbxasset://fonts/families/GothamSSm.json"
local COIN_COLOR = Color3.fromRGB(255, 200, 40)
local FREE_COLOR = Color3.fromRGB(125, 255, 60)
local PPS = 50 -- SurfaceGui pixels per stud

local player = Players.LocalPlayer

local KioskController = {}

local function formatNumber(n: number): string
	local text = tostring(math.floor(n))
	repeat
		local count
		text, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return text
end

-- The screens face the front of the kiosk, which is each part's Back face
local function surface(screen: BasePart): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PPS
	gui.LightInfluence = 0
	gui.Brightness = 1.6
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

-- "OPEN" flickers now and then, like an old neon sign
local function buildOpenSign(screen: BasePart)
	local gui = surface(screen)
	local text = label(gui, {
		Size = UDim2.new(1, -16, 1, -10),
		Position = UDim2.fromOffset(8, 5),
		Text = "OPEN",
		TextColor3 = FREE_COLOR,
	})
	glow(text, Color3.fromRGB(40, 120, 20), 3)
	task.spawn(function()
		while text.Parent do
			task.wait(3 + math.random() * 5)
			for _ = 1, math.random(2, 4) do
				text.TextTransparency = 0.75
				task.wait(0.05 + math.random() * 0.06)
				text.TextTransparency = 0
				task.wait(0.05 + math.random() * 0.08)
			end
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
	for _, pity in Config.Pity do
		table.insert(parts, ("%s+ every %d"):format(pity.Rarity, pity.Crates))
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
	local text = label(gui, {
		Size = UDim2.new(1, -12, 1, -6),
		Position = UDim2.fromOffset(6, 3),
		RichText = true,
	})
	local function refresh()
		if CrateController.HasFree and CrateController.HasFree(crate) then
			text.Text = ("FREE  x%d"):format(player:GetAttribute("FreeCrates") or 0)
			text.TextColor3 = FREE_COLOR
		else
			text.Text = ('<font color="#%s">●</font> %s'):format(COIN_COLOR:ToHex(), formatNumber(crate.Price))
			text.TextColor3 = Color3.new(1, 1, 1)
		end
	end
	player:GetAttributeChangedSignal("FreeCrates"):Connect(refresh)
	return refresh
end

-- Pushes a button down for a moment
local function press(button: BasePart)
	local home = button:GetAttribute("Home") or button.CFrame
	button:SetAttribute("Home", home)
	button.CFrame = home * CFrame.new(-0.15, 0, 0) -- buttons are cylinders: their X axis points out of the panel
	TweenService:Create(button, TweenInfo.new(0.25, Enum.EasingStyle.Back), { CFrame = home }):Play()
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

	buildMarquee(screens:WaitForChild("Marquee"))
	buildOpenSign(screens:WaitForChild("OpenSign"))
	buildOdds(screens:WaitForChild("Odds"))

	local displays = {}
	for _, station in stations:GetChildren() do
		local crate = crateById(station:GetAttribute("CrateId") or station.Name)
		if not crate then
			continue
		end
		local priceScreen = screens:FindFirstChild(crate.Id .. "Price")
		local refreshPrice = if priceScreen then buildPrice(priceScreen, crate) else function() end

		-- Hold the lime button to open this crate
		local button = station:WaitForChild("BuyButton") :: BasePart
		local buyPrompt = prompt(button:WaitForChild("PromptPoint"), {
			Name = "BuyPrompt",
			ObjectText = crate.Name,
			HoldDuration = SHOP.HoldDuration,
		})
		local function refreshPrompt()
			local free = CrateController.HasFree(crate)
			buyPrompt.ActionText = if free then "Open FREE" else ("Open  (%s coins)"):format(formatNumber(crate.Price))
			refreshPrice()
		end
		player:GetAttributeChangedSignal("FreeCrates"):Connect(refreshPrompt)
		refreshPrompt()
		buyPrompt.Triggered:Connect(function()
			press(button)
			task.spawn(CrateController.Buy, crate)
		end)

		local display = station:FindFirstChild("Display")
		if display and display:IsA("Model") then
			table.insert(displays, { Model = display, Home = display:GetPivot(), Phase = math.random() * math.pi * 2 })
		end
	end

	-- The joystick opens the full shop screen (odds, pity and the next-unlock goal)
	local joystick = kiosk:FindFirstChild("JoystickBall", true)
	if joystick then
		local shopPrompt = prompt(joystick, {
			Name = "ShopPrompt",
			ActionText = "Browse",
			ObjectText = "Crate Shop",
			KeyboardKeyCode = Enum.KeyCode.F,
			GamepadKeyCode = Enum.KeyCode.ButtonY,
			UIOffset = Vector2.new(0, 60),
		})
		shopPrompt.Triggered:Connect(function()
			CrateController.OpenShop()
		end)
	end

	-- Display crates hover and turn, only while you're close enough to see them
	local middle = kiosk:GetPivot().Position
	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera or (camera.CFrame.Position - middle).Magnitude > SHOP.AnimateDistance then
			return
		end
		local t = os.clock()
		for _, d in displays do
			local bob = (math.sin(t * 1.5 + d.Phase) + 1) * 0.5 * SHOP.CrateBob
			d.Model:PivotTo(d.Home * CFrame.new(0, bob, 0) * CFrame.Angles(0, t * SHOP.CrateSpin * math.pi * 2, 0))
		end
	end)
end

return KioskController
