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
local UiKit = require(Modules.UiKit)
local CrateKit = require(Modules.CrateKit)
local HudKit = require(Modules.HudKit)
local RewardKit = require(Modules.RewardKit)
local ThrowController = require(script.Parent.ThrowController)

local FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local INK = Color3.fromHex("06060F")

local player = Players.LocalPlayer
local C = UiKit.C
local make = UiKit.Make

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
-- (switched off in the Addendum 4 core loop: the rooftop is the only zone)
	if Config.CoreLoop.Enabled then
		return
	end
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

	-- The "ZONE UNLOCKED" window (UI pass batch 2: the owner's kit look, RewardKit window + cover)
	local showing = false
	local W, H = 800, 764
	local function slot(parent: Instance, x: number, w: number, view: GuiObject?, label: string, color: Color3)
		local cell = UiKit.Block(parent, {
			Name = "Slot",
			Size = Vector2.new(w, 128),
			Fill = C.Slot,
			Lip = C.Ink,
			LipPx = 4,
			Radius = 14,
			Outline = 3,
		})
		cell.Holder.Position = UDim2.fromOffset(x, 40)
		if view then
			view.AnchorPoint = Vector2.zero
			view.Position = UDim2.fromOffset(4, 2)
			view.Size = UDim2.new(1, -8, 1, -28)
			view.ZIndex = 4
			view.Parent = cell.Face
		end
		local name = RewardKit.Label(cell.Face, label, UiKit.Body, 12, color, 0, 4, 98, w - 14, 18)
		name.ZIndex = 5
		return cell.Holder
	end
	local function card(parent: Instance, x: number, y: number, w: number, heading: string, color: Color3)
		local block = UiKit.Block(parent, {
			Name = "Card",
			Size = Vector2.new(w, 184),
			Fill = C.Page,
			Lip = C.Ink,
			LipPx = 5,
			Radius = 18,
			Outline = 3,
		})
		block.Holder.Position = UDim2.fromOffset(x, y)
		local head = RewardKit.Label(block.Face, heading, UiKit.Head, 20, color, 2, 16, 8, w - 32, 28)
		head.TextXAlignment = Enum.TextXAlignment.Left
		return block.Face, block.Holder
	end
	-- a row of slots spread across a card's width
	local function fillCard(face: Frame, w: number, items: { { any } })
		local count = #items
		if count == 0 then
			return
		end
		local gap = 8
		local cellW = math.min(120, math.floor((w - 24 - gap * (count - 1)) / count))
		local x = math.floor((w - (cellW * count + gap * (count - 1))) / 2)
		for _, item in items do
			slot(face, x, cellW, item[1], item[2], item[3])
			x += cellW + gap
		end
	end

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
		gui.Parent = player:WaitForChild("PlayerGui")
		local win = RewardKit.Window(gui, W, H)
		local cover, closeX = RewardKit.Cover(win.Panel, W, H, "ZONE UNLOCKED!", nil, C.Gold)
		local titleBox = cover:FindFirstChild("TitleBox") :: Frame
		titleBox.Size = UDim2.fromOffset(W - 52, 54)
		for _, child in titleBox:GetDescendants() do
			if child:IsA("TextLabel") then
				child.TextXAlignment = Enum.TextXAlignment.Center
			end
		end

		-- the zone's name big in its colour, what it pays, the tagline
		local nameBox = make("Frame", {
			Name = "NameBox",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(20, 70),
			Size = UDim2.fromOffset(W - 40, 72),
		}, cover)
		local zoneName = CrateKit.Title(nameBox, info.Name, 64, info.Color, 4, 6)
		RewardKit.Fit(zoneName, 64, W - 60, 72)
		local chips = make("Frame", {
			Name = "Chips",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 148),
			Size = UDim2.fromOffset(W, 44),
		}, cover)
		make("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 12),
		}, chips)
		for order, chip in
			{
				{ ("x%s COINS"):format(Zones.CoinPay(gate.Zone)), C.Gold, "Coins2" },
				{ ("x%s XP"):format(Zones.XpPay(gate.Zone)), C.Cyan, nil },
			}
		do
			local width = CrateKit.TextWidth(chip[1], UiKit.Head, 22) + (if chip[3] then 66 else 40)
			local block = UiKit.Block(chips, {
				Name = "Chip",
				Size = Vector2.new(width, 44),
				Fill = C.Card,
				Lip = C.Ink,
				LipPx = 4,
				Radius = 22,
				Outline = 3,
			})
			block.Holder.LayoutOrder = order
			local x = 20
			if chip[3] then
				HudKit.Image(block.Face, chip[3], 28, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 14, 0.5, 0),
				})
				x = 48
			end
			local label = UiKit.Text(block.Face, chip[1], UiKit.Head, 22, chip[2], 2)
			label.Position = UDim2.fromOffset(x, 3)
			label.Size = UDim2.new(1, -x - 14, 1, 0)
		end
		local tagline = RewardKit.Label(cover, info.Tagline, UiKit.Body, 15, C.Label, 0, 60, 198, W - 120, 40)
		tagline.TextWrapped = true
		RewardKit.Fit(tagline, 15, W - 120, 40)

		-- The pets waiting there: their egg turning in 3D, its pets a surprise ("?" slots)
		local pets = {}
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
				table.insert(pets, { view, look.Name:upper(), look.Color })
			end
		end
		for _ = 1, #pets > 0 and (info.MysteryPets or 0) or 0 do
			local mystery = UiKit.Text(nil :: any, "?", UiKit.Head, 54, info.Accent, 3)
			table.insert(pets, { mystery, "NEW PET", C.Muted })
		end
		-- The crates waiting there
		local crates = {}
		for _, crateId in info.Crates do
			local crate = Balls.GetCrate(crateId)
			local view = crateView(crateId)
			if crate and view then
				table.insert(crates, { view, crate.Name:upper(), crate.Color })
			end
		end
		-- Its best balls, and how many new ones those crates can give you
		local owned = Balls.DecodeOwned(player:GetAttribute("OwnedBalls"))
		local count = 0
		for _, ball in Config.Balls do
			if ball.InCrates ~= false and not ball.Retired and ball.Zone == gate.Zone and not owned[ball.Id] then
				count += 1
			end
		end
		local balls = {}
		for _, ballId in info.Balls do
			local ball = Balls.Get(ballId)
			if ball then
				table.insert(balls, {
					BallView.New(ball, { Spin = true, Margin = 1.1 }),
					ball.Name:upper(),
					Balls.GetRarity(ball.Rarity).Color,
				})
			end
		end

		local cards: { GuiObject } = {}
		local y = 248
		if #pets > 0 and #crates > 0 then
			local leftW = math.floor((W - 56) * #pets / (#pets + #crates))
			local face, holder = card(cover, 20, y, leftW, info.PetsLine, info.Accent)
			fillCard(face, leftW, pets)
			table.insert(cards, holder)
			face, holder = card(cover, 36 + leftW, y, W - 56 - leftW, info.CratesLine, info.Accent)
			fillCard(face, W - 56 - leftW, crates)
			table.insert(cards, holder)
			y += 196
		else
			for _, row in { { pets, info.PetsLine }, { crates, info.CratesLine } } do
				if #row[1] > 0 then
					local face, holder = card(cover, 20, y, W - 40, row[2], info.Accent)
					fillCard(face, W - 40, row[1])
					table.insert(cards, holder)
					y += 196
				end
			end
		end
		if #balls > 0 then
			local face, holder = card(cover, 20, y, W - 40, info.BallsLine:format(count), C.Gold)
			fillCard(face, W - 40, balls)
			table.insert(cards, holder)
		end

		local hint = RewardKit.Label(cover, info.Hint:upper(), UiKit.Body, 14, info.Accent, 0, 40, H - 128, W - 80, 20)
		hint.Name = "Hint"
		local go = RewardKit.Button(cover, info.Button, "Lime", 340, 68, 30)
		go.Holder.Position = UDim2.fromOffset(W / 2 - 270, H - 68 - 20)
		local later = RewardKit.Button(cover, "CLOSE", "Grey", 180, 68, 28)
		later.Holder.Position = UDim2.fromOffset(W / 2 + 90, H - 68 - 20)
		win.Screen.Name = "Screen"

		win:Open()
		RewardKit.Stagger(cards, 0.08, 0.2)
		RewardKit.Stamp(nameBox)
		UiFx.Flash(info.Color, 0.45, 0.6)
		CrateKit.Confetti(cover, 0, -200, 44, 420, 1)
		Sfx.Play("RevealBig", 1)
		local stopTwinkle = RewardKit.Twinkle(nameBox, 6, info.Accent)

		local closing = false
		local function close()
			if closing then
				return
			end
			closing = true
			zoneSeen:FireServer(gate.Zone)
			stopTwinkle()
			task.delay(0.4, gui.Destroy, gui)
			showing = false
		end
		win.Closed.Event:Connect(close)
		for _, b in { go, later } do
			b.Activated:Connect(function()
				win:Close()
			end)
		end
		closeX.Activated:Connect(function()
			win:Close()
		end)
	end

	local function refresh()
		refreshWalls()
		-- a REBIRTH! moment on screen goes first (RebirthController); this follows when it closes
		if showing or player:GetAttribute("RebirthParty") then
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
	player:GetAttributeChangedSignal("RebirthParty"):Connect(refresh)
	refresh()
end

return ZoneGateController
