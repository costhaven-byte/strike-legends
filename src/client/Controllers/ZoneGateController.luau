-- Later zones on your screen (Config.Zones.Gated, Config.ZoneUnlock):
--   while a zone is locked, a glowing wall (only on your screen) keeps you out, with "NEEDS N REBIRTHS" on it
--   (zone 2: it plugs the Back Alley door into the building);
--   the moment a rebirth opens it, a "ZONE UNLOCKED" window shows what's waiting there in 3D
--   (its pets, crates and balls), once per zone (save ZoneSeen). "SHOW ME THE WAY" closes it and the walk guide
--   (EventController) draws a gold beam to the door: the first trip is on foot (owner 2026-10-27), TELEPORT after.
-- Claiming a lane there happens on the server (LaneService): step onto any OPEN lane.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Balls = require(Shared.Modules.Balls)
local Zones = require(Shared.Modules.Zones)
local Modules = script.Parent.Parent:WaitForChild("Modules")
local Sfx = require(Modules.Sfx)
local UiFx = require(Modules.UiFx)
local BallView = require(Modules.BallView)
local MascotView = require(Modules.MascotView)
local ThrowController = require(script.Parent.ThrowController)

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local INK = Color3.fromHex("06060F")
local GOLD = Color3.fromRGB(255, 200, 40)

local player = Players.LocalPlayer

local ZoneGateController = {}

local function text(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(l :: any)[key] = value
	end
	l.Parent = parent
	return l
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Parent = parent
	return s
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- The glowing wall around a locked zone: only on this screen, so it only stops you
local function buildWall(gate): Folder
	local folder = Instance.new("Folder")
	folder.Name = "ZoneGate" .. gate.Zone
	for index, box in gate.Walls do
		local wall = Instance.new("Part")
		wall.Name = "Wall" .. index
		wall.Anchored = true
		wall.CanCollide = true
		wall.CanQuery = false
		wall.CanTouch = false
		wall.CastShadow = false
		wall.Material = Enum.Material.ForceField
		wall.Color = gate.WallColor
		wall.Size = box.Size
		wall.CFrame = CFrame.new(box.Center)
		wall.Parent = folder
	end
	-- The sign faces the way you walk up to the door (gate.SignFace, default the first wall's +Z side: the Back Alley)
	-- and fills the wall's face, so it fits a narrow door too
	local front = folder:FindFirstChild("Wall1") :: BasePart?
	if front then
		local sign = Instance.new("SurfaceGui")
		sign.Name = "Sign"
		sign.Face = gate.SignFace or Enum.NormalId.Back
		sign.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sign.PixelsPerStud = 20
		sign.LightInfluence = 0
		sign.Brightness = 1.5
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.fromScale(0.5, 0.42)
		holder.Size = UDim2.fromScale(0.92, 0.6)
		holder.Parent = sign
		local lines = {
			{ Text = "🔒", Height = 0.3, Color = Color3.new(1, 1, 1) },
			{ Text = Zones.Name(gate.Zone):upper(), Height = 0.22, Color = gate.WallColor },
			{ Text = ("ZONE %d"):format(gate.Zone), Height = 0.14, Color = gate.WallColor },
			{
				Text = ("NEEDS %s"):format(Zones.NeedText(gate.Zone)),
				Height = 0.17,
				Color = Color3.new(1, 1, 1),
			},
			{ Text = "TO ENTER", Height = 0.13, Color = Color3.new(1, 1, 1) },
		}
		local y = 0
		for _, line in lines do
			local label = text(holder, {
				Position = UDim2.fromScale(0, y),
				Size = UDim2.fromScale(1, line.Height * 0.92),
				Text = line.Text,
				TextColor3 = line.Color,
			})
			stroke(label, INK, 3)
			y += line.Height
		end
		sign.Parent = front
	end
	return folder
end

-- A crate's model, turning slowly in its own little 3D window
local function crateView(crateId: string): ViewportFrame?
	local models = ReplicatedStorage:FindFirstChild("CrateModels")
	local crate = Balls.GetCrate(crateId)
	local template = models
		and (models:FindFirstChild(crateId) or (crate and crate.Model and models:FindFirstChild(crate.Model)))
	if not template then
		return nil
	end
	local view = Instance.new("ViewportFrame")
	view.BackgroundTransparency = 1
	view.Ambient = Color3.fromRGB(200, 200, 220)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -1.5, -1)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = view
	view.CurrentCamera = camera
	local model = template:Clone() :: Model
	model:PivotTo(CFrame.new())
	local box, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-box.Position))
	model.Parent = view
	local radius = size.Magnitude / 2
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.35, 1).Unit * radius / math.tan(math.rad(15)), Vector3.zero)
	local home = model:GetPivot()
	local spin = RunService.RenderStepped:Connect(function()
		if view.Parent and view.Visible then
			model:PivotTo(CFrame.Angles(0, os.clock() * 0.8, 0) * home)
		end
	end)
	view.Destroying:Connect(function()
		spin:Disconnect()
	end)
	return view
end

-- One row of 3D pictures under a heading
local function showcaseRow(
	parent: Instance,
	order: number,
	heading: string,
	color: Color3,
	views: { GuiObject },
	labels: { string },
	labelColors: { Color3 }
)
	local row = Instance.new("Frame")
	row.Name = "Row" .. order
	row.LayoutOrder = order
	row.BackgroundColor3 = Color3.fromRGB(18, 10, 34)
	row.Size = UDim2.new(1, 0, 0, 132)
	corner(row, 12)
	stroke(row, color, 2).Transparency = 0.4
	local head = text(row, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 22),
		Text = heading,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	stroke(head, INK, 2)
	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Position = UDim2.fromOffset(8, 30)
	strip.Size = UDim2.new(1, -16, 1, -34)
	strip.Parent = row
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = strip
	local width = 1 / math.max(#views, 4)
	for index, view in views do
		local cell = Instance.new("Frame")
		cell.BackgroundTransparency = 1
		cell.LayoutOrder = index
		cell.Size = UDim2.new(width, -6, 1, 0)
		view.Size = UDim2.new(1, 0, 1, -18)
		view.Parent = cell
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.FontFace = BODY_FONT
		name.TextScaled = true
		name.AnchorPoint = Vector2.new(0, 1)
		name.Position = UDim2.fromScale(0, 1)
		name.Size = UDim2.new(1, 0, 0, 16)
		name.Text = labels[index]
		name.TextColor3 = labelColors[index]
		name.Parent = cell
		cell.Parent = strip
	end
	row.Parent = parent
	return row
end

-- Waits until no throw is going on and the camera is back with the player
local function waitForCalm()
	local camera = Workspace.CurrentCamera
	local waited = 0
	while
		waited < 120
		and (
			ThrowController.State() == "Charging"
			or ThrowController.State() == "Waiting"
			or camera.CameraType ~= Enum.CameraType.Custom
		)
	do
		waited += task.wait(0.2)
	end
end

function ZoneGateController:Start()
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local zoneSeen = remotes:WaitForChild("ZoneSeen") :: RemoteEvent
	while not player:GetAttribute("DataLoaded") do
		player:GetAttributeChangedSignal("DataLoaded"):Wait()
	end

	-- Walls: up while locked, gone once unlocked
	local walls: { [number]: Folder } = {}
	local function refreshWalls()
		local zonesOpen = player:GetAttribute("ZonesOpen")
		for index, gate in Config.Zones.Gated do
			local locked = not Zones.Unlocked(zonesOpen, gate.Zone)
			if locked and not walls[index] then
				walls[index] = buildWall(gate)
				walls[index].Parent = Workspace
			elseif not locked and walls[index] then
				walls[index]:Destroy()
				walls[index] = nil
			end
		end
	end

	-- The "ZONE UNLOCKED" window
	local showing = false
	local function showUnlock(gate)
		local info = Config.ZoneUnlock[gate.Zone]
		if not info then
			zoneSeen:FireServer(gate.Zone)
			return
		end
		showing = true
		task.wait(2.5) -- let the level-up popup have its moment first
		waitForCalm()

		local gui = Instance.new("ScreenGui")
		gui.Name = "ZoneUnlockUI"
		gui.DisplayOrder = 40
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true

		local shade = Instance.new("TextButton") -- swallows taps so they don't throw a ball
		shade.Name = "Shade"
		shade.AutoButtonColor = false
		shade.Text = ""
		shade.Size = UDim2.fromScale(1, 1)
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BackgroundTransparency = 1
		shade.Parent = gui
		TweenService:Create(shade, TweenInfo.new(0.4), { BackgroundTransparency = 0.35 }):Play()

		local window = Instance.new("Frame")
		window.Name = "Window"
		window.AnchorPoint = Vector2.new(0.5, 0.5)
		window.Position = UDim2.fromScale(0.5, 0.5)
		window.Size = UDim2.fromScale(0.92, 0.9)
		window.BackgroundColor3 = Color3.fromRGB(14, 8, 28)
		window.Visible = false
		corner(window, 18)
		stroke(window, info.Color, 4)
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(560, 600)
		limit.Parent = window
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 90
		gradient.Color = ColorSequence.new(Color3.fromRGB(70, 20, 90), Color3.fromRGB(12, 8, 26))
		gradient.Parent = window
		window.Parent = gui

		local scroll = Instance.new("ScrollingFrame")
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.Position = UDim2.fromOffset(16, 12)
		scroll.Size = UDim2.new(1, -32, 1, -24)
		scroll.ScrollBarThickness = 4
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.CanvasSize = UDim2.new()
		scroll.Parent = window
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.Padding = UDim.new(0, 8)
		list.Parent = scroll

		local title =
			text(scroll, { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 34), Text = info.Title, TextColor3 = GOLD })
		stroke(title, INK, 3)
		local name =
			text(scroll, { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 62), Text = info.Name, TextColor3 = info.Color })
		stroke(name, Color3.new(1, 1, 1), 2)
		local nameGlow = stroke(name, info.Color, 6)
		nameGlow.Transparency = 0.5
		local tagline = text(scroll, {
			LayoutOrder = 3,
			Size = UDim2.new(1, -10, 0, 40),
			Text = info.Tagline,
			FontFace = BODY_FONT,
			TextWrapped = true,
			TextColor3 = Color3.fromRGB(225, 215, 245),
		})
		local taglineLimit = Instance.new("UITextSizeConstraint")
		taglineLimit.MaxTextSize = 17
		taglineLimit.Parent = tagline

		-- The pets waiting there: their egg, turning in 3D
		local eggViews, eggNames, eggColors = {}, {}, {}
		for _, eggId in info.Eggs or {} do
			local look = Config.EggLooks[eggId]
			if look then
				local egg = MascotView.Egg(eggId, 4)
				local view = MascotView.Viewport(nil :: any, egg, 1.7)
				local home = egg:GetPivot()
				local spin = RunService.RenderStepped:Connect(function()
					if view.Visible then
						egg:PivotTo(home * CFrame.Angles(0, os.clock() * 0.8, 0))
					end
				end)
				view.Destroying:Connect(function()
					spin:Disconnect()
				end)
				table.insert(eggViews, view)
				table.insert(eggNames, look.Name:upper())
				table.insert(eggColors, look.Color)
			end
		end
		-- Its pets are a surprise: mystery cards next to the egg
		for _ = 1, #eggViews > 0 and (info.MysteryPets or 0) or 0 do
			local card = Instance.new("Frame")
			card.BackgroundTransparency = 1
			local bubble = text(card, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.8, 0.8),
				BackgroundTransparency = 0,
				BackgroundColor3 = Color3.fromRGB(40, 24, 70),
				Text = "?",
				TextColor3 = info.Accent,
			})
			Instance.new("UIAspectRatioConstraint").Parent = bubble
			corner(bubble, 999)
			stroke(bubble, info.Accent, 2).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			table.insert(eggViews, card)
			table.insert(eggNames, "NEW PET")
			table.insert(eggColors, Color3.fromRGB(200, 190, 230))
		end
		if #eggViews > 0 then
			showcaseRow(scroll, 4, info.PetsLine, info.Accent, eggViews, eggNames, eggColors)
		end

		-- The crates waiting there
		local crateViews, crateNames, crateColors = {}, {}, {}
		for _, crateId in info.Crates do
			local crate = Balls.GetCrate(crateId)
			local view = crateView(crateId)
			if crate and view then
				table.insert(crateViews, view)
				table.insert(crateNames, crate.Name:upper())
				table.insert(crateColors, crate.Color)
			end
		end
		if #crateViews > 0 then
			showcaseRow(scroll, 5, info.CratesLine, info.Accent, crateViews, crateNames, crateColors)
		end

		-- Its best balls, and how many new ones those crates can give you
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local count = 0
		for _, ball in Config.Balls do
			if ball.InCrates ~= false and not ball.Retired and ball.Zone == gate.Zone and not owned[ball.Id] then
				count += 1
			end
		end
		local ballViews, ballNames, ballColors = {}, {}, {}
		for _, ballId in info.Balls do
			local ball = Balls.Get(ballId)
			if ball then
				table.insert(ballViews, BallView.New(ball, { Spin = true, Margin = 1.1 }))
				table.insert(ballNames, ball.Name:upper())
				table.insert(ballColors, Balls.GetRarity(ball.Rarity).Color)
			end
		end
		if #ballViews > 0 then
			showcaseRow(scroll, 6, info.BallsLine:format(count), GOLD, ballViews, ballNames, ballColors)
		end

		local hint = text(scroll, {
			LayoutOrder = 7,
			Size = UDim2.new(1, 0, 0, 20),
			Text = info.Hint,
			FontFace = BODY_FONT,
			TextColor3 = info.Accent,
		})
		hint.TextScaled = true

		local buttons = Instance.new("Frame")
		buttons.BackgroundTransparency = 1
		buttons.LayoutOrder = 8
		buttons.Size = UDim2.new(1, 0, 0, 56)
		buttons.Parent = scroll
		local go = Instance.new("TextButton")
		go.Name = "Go"
		go.AnchorPoint = Vector2.new(0.5, 0)
		go.Position = UDim2.fromScale(0.5, 0)
		go.Size = UDim2.new(0.62, 0, 0, 52)
		go.BackgroundColor3 = Color3.fromRGB(90, 230, 110)
		go.FontFace = FONT
		go.TextScaled = true
		go.Text = info.Button
		go.TextColor3 = Color3.new(1, 1, 1)
		corner(go, 12)
		stroke(go, INK, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		local goText = Instance.new("UIStroke")
		goText.Color = INK
		goText.Thickness = 2
		goText.Parent = go
		local goPad = Instance.new("UIPadding")
		goPad.PaddingTop = UDim.new(0, 8)
		goPad.PaddingBottom = UDim.new(0, 8)
		goPad.Parent = go
		go.Parent = buttons
		local later = Instance.new("TextButton")
		later.Name = "Later"
		later.AnchorPoint = Vector2.new(1, 0)
		later.Position = UDim2.new(1, 0, 0, 10)
		later.Size = UDim2.new(0.18, 0, 0, 32)
		later.BackgroundColor3 = Color3.fromRGB(60, 50, 80)
		later.FontFace = FONT
		later.TextScaled = true
		later.Text = "LATER"
		later.TextColor3 = Color3.fromRGB(200, 190, 230)
		corner(later, 10)
		later.Parent = buttons
		UiFx.Press(go)
		UiFx.Press(later)

		gui.Parent = player:WaitForChild("PlayerGui")
		UiFx.Open(window)
		UiFx.Flash(info.Color, 0.45, 0.6)
		UiFx.Confetti(window, 50, { info.Color, GOLD, info.Accent })
		Sfx.Play("RevealBig", 1)
		local pulse = TweenService:Create(
			nameGlow,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0 }
		)
		pulse:Play()

		local closing = false
		local function close()
			if closing then
				return
			end
			closing = true
			zoneSeen:FireServer(gate.Zone)
			pulse:Cancel()
			UiFx.Close(window)
			TweenService:Create(shade, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
			task.delay(0.4, gui.Destroy, gui)
			showing = false
		end
		go.Activated:Connect(function()
			close()
		end)
		later.Activated:Connect(function()
			close()
		end)
	end

	local function refresh()
		refreshWalls()
		if showing then
			return
		end
		local zonesOpen = player:GetAttribute("ZonesOpen")
		local seen = player:GetAttribute("ZoneSeen") or 1
		for _, gate in Config.Zones.Gated do
			if gate.Zone > seen and Zones.Unlocked(zonesOpen, gate.Zone) then
				task.spawn(showUnlock, gate)
				return
			end
		end
	end
	player:GetAttributeChangedSignal("ZonesOpen"):Connect(refresh)
	refresh()
end

return ZoneGateController
